function export_reference(operator,path,varargin)
%EXPORT_REFERENCE Export synthetic SSB golden vectors in ssb-grid-v1 format.
mustBeTextScalar(operator); mustBeTextScalar(path);
parser=inputParser;
addParameter(parser,'NumBlocks',128); addParameter(parser,'Seed',20261112);
addParameter(parser,'PCI',[]); parse(parser,varargin{:}); options=parser.Results;
validateattributes(options.NumBlocks,{'numeric'},{'scalar','real','finite','integer','positive'});
validateattributes(options.Seed,{'numeric'},{'scalar','real','finite','integer','nonnegative'});
p=ssb.load_profile(char(operator));
if ~ismember('PCI',parser.UsingDefaults)
    ssb.validate_metadata(options.PCI,p.ssb_index,p.lmax,8,p.ibar_ssb);
    p.observed_pci=p.pci; p.pci=double(options.PCI);
    p.nid1=floor(p.pci/3); p.nid2=mod(p.pci,3);
    p.profile_kind='synthetic_pci_override';
end
a=ssb.layout(p.pci); B=options.NumBlocks;
stream=RandStream('mt19937ar','Seed',options.Seed);
tx=complex(zeros(240,4,B,'single')); tr=zeros(24,B,'uint8');
scr=zeros(32,B,'uint8'); cw=zeros(864,B,'uint8'); sf=zeros(B,1,'uint16');
hf=zeros(B,1,'uint8'); ks=zeros(B,1,'uint8'); off=zeros(B,1,'uint8'); llr=zeros(864,B,'single');
sfns=[0 15 16 1023]; offsets=[0 15 16 31];
for b=1:B
    s=sfns(mod(b-1,4)+1); h=mod(floor((b-1)/4),2);
    k=offsets(mod(floor((b-1)/8),4)+1);
    t=randi(stream,[0 1],24,1); t(1)=0; t(24)=0;
    t(2:7)=bitget(uint16(s),10:-1:5); t(9:12)=bitget(uint8(k),4:-1:1);
    r=ssb.encode(p,t,s,h,k);
    tx(:,:,b)=single(r.grid); tr(:,b)=uint8(t); scr(:,b)=uint8(r.scrblk);
    cw(:,b)=uint8(r.codeword); sf(b)=s; hf(b)=h; ks(b)=k; off(b)=r.decoded.msb_index_offset;
    llr(:,b)=single(r.decoded.llr);
end
folder=fileparts(char(path)); if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
path=char(path);
if isfile(path), error('ssb:FileExists','Refusing to overwrite existing file: %s',path); end
tmp=[tempname(folder) '.h5']; cleanup=onCleanup(@() cleanup_temp(tmp));
wr=@(n,v,sh) ssb.write_dataset(tmp,n,v,sh);
% MATLAB HDF5 dimension order is reversed by h5py.
wr('/tx/grid_real',permute(real(tx),[2 1 3]),[4 240 B]);
wr('/tx/grid_imag',permute(imag(tx),[2 1 3]),[4 240 B]);
% Noise-free identity channel observation. The LLR diagnostic uses 1e-10
% as a finite decoder variance, not as a claim of a sampled noise realization.
wr('/rx/grid_real',permute(real(tx),[2 1 3]),[4 240 B]);
wr('/rx/grid_imag',permute(imag(tx),[2 1 3]),[4 240 B]);
wr('/channel/h_true_real',ones(4,240,B,'single'),[4 240 B]);
wr('/channel/h_true_imag',zeros(4,240,B,'single'),[4 240 B]);
wr('/noise/no',zeros(B,1,'single'),B);
for name={'pss','sss','dmrs','pbch'}
    c=a.([name{1} '_kl']); wr(['/re/' name{1} '_kl'],c.',[2 size(c,1)]);
end
wr('/re/class_id',a.class_id.',[4 240]);
for name={'mask_dmrs','mask_pbch','mask_active'}
    wr(['/re/' name{1}],uint8(a.(name{1}).'),[4 240]);
end
dm=single(nrPBCHDMRS(p.pci,p.ibar_ssb));
wr('/tx/dmrs_real',real(dm),144); wr('/tx/dmrs_imag',imag(dm),144);
wr('/bits/bch_transport',tr,[24 B]); wr('/bits/bch_payload_scrambled32',scr,[32 B]);
wr('/bits/bch_rate_matched',cw,[864 B]); wr('/bits/sfn',sf,B);
wr('/bits/half_frame',hf,B); wr('/bits/k_ssb',ks,B);
wr('/bits/msb_index_offset',off,B);
wr('/diagnostic/pbch_llr',llr,[864 B]);
manifest=p; manifest.source_kind='synthetic_tx'; manifest.schema_version='ssb-grid-v1';
manifest.seed=options.Seed; manifest.num_blocks=B; manifest.matlab_release=version('-release');
v=ver('5g'); manifest.toolbox_version=v.Version;
manifest.standard='TS 38.212 V17.5.0; later repetition features disabled';
manifest.bit_stage='scrblk: nrBCHDecode first output; codeword: nrBCH output before PBCH scrambling';
manifest.axis_order={'batch','subcarrier','symbol'}; manifest.index_base=0;
manifest.re_order='symbol_then_subcarrier'; manifest.complex_storage='split_float32';
manifest.power='PSS, SSS, PBCH, DMRS EPRE=1'; manifest.placement_mode='local_240_bin';
manifest.point_a_status='unverified'; manifest.k_ssb='per-block /bits/k_ssb';
manifest.noise_source='known_simulation'; manifest.reference_n0=0; manifest.decoder_n0_floor=1e-10;
manifest.created_utc=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));
bytes=uint8(unicode2native(jsonencode(manifest),'UTF-8')); wr('/meta/manifest_json',bytes,numel(bytes));
h5writeatt(tmp,'/','schema_version','ssb-grid-v1');
h5writeatt(tmp,'/','axis_order','["batch","subcarrier","symbol"]');
h5writeatt(tmp,'/','index_columns','["k","l"]'); h5writeatt(tmp,'/','index_base',int32(0));
h5writeatt(tmp,'/','re_order','symbol_then_subcarrier'); h5writeatt(tmp,'/','complex_storage','split_float32');
movefile(tmp,path); fprintf('Exported %d verified blocks for %s to %s\n',B,p.operator_id,path);
end

function cleanup_temp(path)
if isfile(path), delete(path); end
end
