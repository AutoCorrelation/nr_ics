function d = decode_pbch(y,h,n0,pci,index,lmax,listLength)
%DECODE_PBCH Shared SISO MMSE, soft PBCH and BCH decoding path.
if nargin<7, listLength=8; end
ssb.validate_metadata(pci,index,lmax,listLength);
validateattributes(y,{'numeric'},{'size',[240 4],'finite'});
validateattributes(h,{'numeric'},{'size',[240 4],'finite'});
validateattributes(n0,{'numeric'},{'scalar','real','finite','nonnegative'});
% The zero-noise limit needs a positive demodulator variance to keep LLRs finite.
if n0==0, n0=1e-10; end
a = ssb.layout(pci);
[eq,csi] = nrEqualizeMMSE(double(y(a.pbch_ind)),double(h(a.pbch_ind)),double(n0));
if any(~isfinite(eq)) || any(~isfinite(csi))
    error('ssb:NumericalFailure','Nonfinite MMSE output.');
end
llr = nrPBCHDecode(eq,pci,index,double(n0));
llr = llr.*reshape(repmat(csi.',2,1),[],1);
if any(~isfinite(llr)), error('ssb:NumericalFailure','Nonfinite PBCH LLR.'); end
[scr,crc,tr,sfn,hf,offset] = nrBCHDecode(llr,listLength,lmax,pci);
d = struct('crc',crc,'scrblk',scr,'trblk',tr,'sfn_lsb',sfn, ...
    'half_frame',hf,'msb_index_offset',offset,'llr',llr,'equalized',eq,'csi',csi);
end
