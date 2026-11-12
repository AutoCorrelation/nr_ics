function r = encode(p,tr,sfn,hf,kssb)
%ENCODE Generate a valid local SSB and verify its decoder state.
validateattributes(tr,{'numeric','logical'},{'column','numel',24,'binary'});
validateattributes(sfn,{'numeric'},{'scalar','integer','>=',0,'<=',1023});
validateattributes(hf,{'numeric'},{'scalar','integer','>=',0,'<=',1});
validateattributes(kssb,{'numeric'},{'scalar','integer','>=',0,'<=',31});
ssb.validate_metadata(p.pci,p.ssb_index,p.lmax,8,p.ibar_ssb);
tr=double(tr);
assert(isequal(tr(2:7),double(bitget(uint16(sfn),10:-1:5).')),'SFN MSBs differ from message.');
assert(isequal(tr(9:12),double(bitget(uint8(kssb),4:-1:1).')),'kSSB LSBs differ from message.');
a=ssb.layout(p.pci);
cw=nrBCH(tr,sfn,hf,p.lmax,kssb,p.pci);
grid=complex(zeros(240,4));
grid(a.pss_ind)=nrPSS(p.pci);
grid(a.sss_ind)=nrSSS(p.pci);
ibar=p.ssb_index;
if p.lmax==4, ibar=ibar+4*hf; end
grid(a.dmrs_ind)=nrPBCHDMRS(p.pci,ibar);
grid(a.pbch_ind)=nrPBCH(cw,p.pci,p.ssb_index);
d=ssb.decode_pbch(grid,ones(240,4),1e-10,p.pci,p.ssb_index,p.lmax,8);
assert(d.crc==0 && isequal(d.trblk,tr) && ...
    isequal(d.sfn_lsb,double(bitget(uint16(sfn),4:-1:1).')) && ...
    d.half_frame==hf && d.msb_index_offset==bitget(uint8(kssb),5), ...
    'ssb:Roundtrip','BCH state failed no-noise roundtrip.');
% Compare the 32-bit scrambled stage against the actual BCH decoder output
% obtained directly from the encoded codeword, independently of PBCH mapping.
[truth,crc] = nrBCHDecode((1-2*double(cw))*100,8);
assert(crc==0 && isequal(truth,d.scrblk),'ssb:PayloadMismatch','Scrambled payload mismatch.');
r=struct('grid',grid,'codeword',cw,'trblk',tr,'scrblk',truth, ...
    'sfn',sfn,'half_frame',hf,'kssb',kssb,'ibar_ssb',ibar,'decoded',d,'layout',a);
end
