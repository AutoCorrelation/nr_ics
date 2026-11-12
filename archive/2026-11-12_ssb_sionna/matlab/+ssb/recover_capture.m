function result = recover_capture(operator)
%RECOVER_CAPTURE Run observed capture acquisition and preserve BCH outputs.
% Timing is relative to a two-symbol reference with PSS in symbol two.
p=ssb.load_profile(operator); root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
path=fullfile(root,'NRdump',[p.operator_id '_40ms.dat']);
file=dir(path); assert(~isempty(file) && file.bytes==p.raw.file_size_bytes,'Invalid capture size.');
fid=fopen(path,'rb','ieee-le'); assert(fid>=0,'Cannot open IQ capture.');
cleanup=onCleanup(@() fclose(fid)); data=fread(fid,[2 Inf],'int16=>double');
assert(size(data,2)==p.raw.total_samples,'Invalid capture sample count.');
x=complex(data(1,:),data(2,:)).'/32768; fs=p.sample_rate_hz; scs=p.scs_hz/1000;
t=(0:numel(x)-1)'/fs; x=x.*exp(-1j*2*pi*(p.ssref_hz-p.capture_center_hz)*t);
best=-Inf;
for cfo=-15000:2500:15000
    y=x.*exp(-1j*2*pi*cfo*t);
    for nid2=0:2
        ref=zeros(240,2); ref(nrPSSIndices()+240)=nrPSS(nid2);
        [offset,mag]=nrTimingEstimate(y,20,scs,0,ref,'SampleRate',fs);
        score=max(mag(:));
        if score>best, best=score; timing=offset; coarse=cfo; foundNid2=nid2; end
    end
end
y=x.*exp(-1j*2*pi*coarse*t); info=nrOFDMInfo(20,scs,'SampleRate',fs);
cp=info.CyclicPrefixLengths(2); sample=timing+info.SymbolLengths(1)+(1:cp);
assert(sample(end)+info.Nfft<=numel(y),'Timing exceeds capture.');
fine=angle(sum(conj(y(sample)).*y(sample+info.Nfft)))*fs/(2*pi*info.Nfft);
cfo=coarse+fine; y=x.*exp(-1j*2*pi*cfo*t);
ref=zeros(240,2); ref(nrPSSIndices()+240)=nrPSS(foundNid2);
timing=nrTimingEstimate(y,20,scs,0,ref,'SampleRate',fs);
grid=nrOFDMDemodulate(y(timing+1:end),20,scs,0,'SampleRate',fs); ssbgrid=grid(:,2:5);
scores=zeros(336,1);
for nid1=0:335
    scores(nid1+1)=abs(nrSSS(3*nid1+foundNid2)'*ssbgrid(nrSSSIndices()))^2;
end
[~,idx]=max(scores); pci=3*(idx-1)+foundNid2;
result=struct('source_kind','capture_rx','profile',p,'pci',pci,'nid2',foundNid2, ...
    'cfo_hz',cfo,'timing_reference_offset_samples',timing,'timing_reference', ...
    'PSS in second symbol; SSB first CP and frame origin unverified', ...
    'grid',ssbgrid,'hypotheses',[],'crc',1,'full_state_available',false);
for ibar=0:7
    ref=zeros(240,4); ref(nrPBCHDMRSIndices(pci))=nrPBCHDMRS(pci,ibar);
    [h,nvar]=nrChannelEstimate(ssbgrid,ref,'AveragingWindow',[0 1]);
    d=ssb.decode_pbch(ssbgrid,h,max(nvar,1e-10),pci,ibar,8,8);
    hyp=struct('ibar_ssb',ibar,'noise_estimate',nvar,'crc',d.crc, ...
        'scrblk',d.scrblk,'trblk',d.trblk,'sfn_lsb',d.sfn_lsb, ...
        'half_frame',d.half_frame,'msb_index_offset',d.msb_index_offset);
    result.hypotheses=[result.hypotheses; hyp]; %#ok<AGROW>
    if d.crc==0
        result.crc=0; result.ssb_index=ibar; result.decoded=d;
        result.sfn=double(bi2de(d.trblk(2:7).','left-msb'))*16+double(bi2de(d.sfn_lsb.','left-msb'));
        result.k_ssb=16*double(d.msb_index_offset)+double(bi2de(d.trblk(9:12).','left-msb'));
        % Additional release-specific payload bits and timing origin remain unknown.
        break
    end
end
fprintf('%s: PCI=%d (metadata %d), CFO=%.2f Hz, timing=%d, CRC=%d, hypotheses=%d\n', ...
    p.operator_id,pci,p.pci,cfo,timing,result.crc,numel(result.hypotheses));
end
