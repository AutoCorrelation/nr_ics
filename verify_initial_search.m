function result = verify_initial_search(operator)
% operator: 'lgu', 'skt', or 'kt'.
if nargin == 0, operator = 'lgu'; end
operator = validatestring(operator, {'lgu','skt','kt'});
%VERIFY_INITIAL_SEARCH Capture: PSS -> SSS -> PBCH CRC.
% Requires 5G Toolbox. SSB center/SCS are capture metadata, PCI is searched.
root = fileparts(mfilename('fullpath'));
meta = jsondecode(fileread(fullfile(root,'NRdump',[operator '_40ms.json'])));
fid = fopen(fullfile(root,'NRdump',[operator '_40ms.dat']),'rb','ieee-le');
assert(fid >= 0,'Cannot open IQ capture.');
cleanup = onCleanup(@() fclose(fid));
a = fread(fid,[2 Inf],'int16=>double');
x = complex(a(1,:),a(2,:)).'/32768;
fs = meta.sample_rate_hz; scs = meta.scs_khz;
t = (0:numel(x)-1)'/fs;
x = x.*exp(-1j*2*pi*(meta.sync_parameters.ssb_center_freq_hz-meta.center_freq_hz)*t);
% Coarse CFO search; timing reference places PSS in symbol 2 (normal CP).
best = -Inf;
for cfo = -15000:2500:15000
    y = x.*exp(-1j*2*pi*cfo*t);
    for nid2 = 0:2
        ref = zeros(240,2); ref(nrPSSIndices()+240) = nrPSS(nid2);
        [offset,mag] = nrTimingEstimate(y,20,scs,0,ref,'SampleRate',fs);
        score = max(mag(:));
        if score > best
            best = score; timing = offset; coarse = cfo; NID2 = nid2;
        end
    end
end
% Fine CFO from cyclic prefix correlation near the detected SSB.
y = x.*exp(-1j*2*pi*coarse*t);
info = nrOFDMInfo(20,scs,'SampleRate',fs);
nfft = info.Nfft; cp = info.CyclicPrefixLengths(2);
p = timing + info.SymbolLengths(1) + (1:cp);
fine = angle(sum(conj(y(p)).*y(p+nfft)))*fs/(2*pi*nfft);
cfo = coarse+fine;
y = x.*exp(-1j*2*pi*cfo*t);
ref = zeros(240,2); ref(nrPSSIndices()+240) = nrPSS(NID2);
timing = nrTimingEstimate(y,20,scs,0,ref,'SampleRate',fs);
grid = nrOFDMDemodulate(y(timing+1:end),20,scs,0,'SampleRate',fs);
ssb = grid(:,2:5);
scores = zeros(336,1);
for nid1 = 0:335
    scores(nid1+1) = abs(nrSSS(3*nid1+NID2)'*ssb(nrSSSIndices()))^2;
end
[~,idx] = max(scores); pci = 3*(idx-1)+NID2;
result = struct('Operator',meta.operator,'PCI',pci,'NID2',NID2,'CFOHz',cfo, ...
    'TimingOffsetSamples',timing,'SSBIndex',NaN,'CRC',1,'MIB',[]);
% Blind DM-RS/SSB-index hypotheses for Case C, Lmax=8.
for ibar = 0:7
    ref = zeros(240,4);
    ref(nrPBCHDMRSIndices(pci)) = nrPBCHDMRS(pci,ibar);
    [h,nvar] = nrChannelEstimate(ssb,ref,'AveragingWindow',[0 1]);
    ind = nrPBCHIndices(pci);
    [eq,csi] = nrEqualizeMMSE(ssb(ind),h(ind),max(nvar,1e-10));
    llr = nrPBCHDecode(eq,pci,ibar,max(nvar,1e-10));
    llr = llr.*reshape(repmat(csi.',2,1),[],1);
    [~,crc,mib] = nrBCHDecode(llr,8,8,pci);
    if crc == 0
        result.SSBIndex = ibar; result.CRC = crc; result.MIB = mib;
        break
    end
end
disp(result);
if result.CRC ~= 0
    warning('PBCH CRC failed for %s.',meta.operator);
    return
end
fprintf('PBCH CRC PASS: PCI=%d, SSB=%d, CFO=%.1f Hz\n',pci,result.SSBIndex,cfo);
end

