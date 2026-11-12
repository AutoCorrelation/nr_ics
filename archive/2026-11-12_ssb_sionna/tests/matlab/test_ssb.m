function tests = test_ssb
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'matlab')); t.TestData.root=root;
end

function testLayout(t)
for pci=[508 325 2 3]
    a=ssb.layout(pci); v=mod(pci,4);
    expected=[(v:4:239)' ones(60,1); ...
        [v+4*(0:11) v+4*(48:59)]' 2*ones(24,1); (v:4:239)' 3*ones(60,1)];
    verifyEqual(t,double(a.dmrs_kl),expected);
    verifyEqual(t,nnz(a.class_id==0),130);
    verifyEqual(t,[nnz(a.class_id==1) nnz(a.class_id==2) nnz(a.class_id==3) nnz(a.class_id==4)],[127 127 144 432]);
end
end

function testRoundtripAndPilots(t)
p=ssb.load_profile('kt');
for s=[0 15 16 1023]
    for h=0:1
        for k=[0 15 16 31]
            msg=zeros(24,1); msg(2:7)=bitget(uint16(s),10:-1:5); msg(9:12)=bitget(uint8(k),4:-1:1);
            r=ssb.encode(p,msg,s,h,k); H=0.6+0.3i; y=r.grid*H;
            d=ssb.decode_pbch(y,H*ones(240,4),1e-8,p.pci,p.ssb_index,8,8);
            verifyEqual(t,double(d.crc),0); verifyEqual(t,d.scrblk,r.scrblk);
            pilot=ssb.extract_pilots(r.grid,y,p.pci);
            verifyEqual(t,pilot.received,pilot.ideal*H,'AbsTol',1e-12);
            verifyEqual(t,pilot.ls,H*ones(144,1),'AbsTol',1e-12);
        end
    end
end
end

function testDmrsIndices(t)
p=ssb.load_profile('skt');
for idx=0:7
    p.ssb_index=idx; p.ibar_ssb=idx; msg=zeros(24,1);
    a=ssb.encode(p,msg,0,0,0); b=ssb.encode(p,msg,0,1,0);
    verifyEqual(t,a.grid(a.layout.dmrs_ind),b.grid(b.layout.dmrs_ind));
    verifyNotEqual(t,a.scrblk,b.scrblk);
end
end

function testLmax4DmrsAndDecode(t)
p=ssb.load_profile('skt'); p.lmax=4;
for idx=0:3
    p.ssb_index=idx;
    for hf=0:1
        % Both metadata hypotheses are legal; the actual sequence follows hf.
        p.ibar_ssb=idx+4*(1-hf);
        r=ssb.encode(p,zeros(24,1),0,hf,0);
        verifyEqual(t,r.ibar_ssb,idx+4*hf);
        verifyEqual(t,r.grid(r.layout.dmrs_ind),nrPBCHDMRS(p.pci,idx+4*hf));
        d=ssb.decode_pbch(r.grid,ones(240,4),0,p.pci,idx,4,8);
        verifyEqual(t,double(d.crc),0);
        verifyEqual(t,d.scrblk,r.scrblk);
        verifyEqual(t,double(d.half_frame),hf);
        input=[tempname '.h5']; output=[tempname '.h5'];
        cleanup=onCleanup(@()removeFiles(input,output));
        y=single(r.grid.');
        ssb.write_dataset(input,'/rx/grid_real',real(y),[4 240 1]);
        ssb.write_dataset(input,'/rx/grid_imag',imag(y),[4 240 1]);
        ssb.write_dataset(input,'/estimate/grid_real',ones(4,240,'single'),[4 240 1]);
        ssb.write_dataset(input,'/estimate/grid_imag',zeros(4,240,'single'),[4 240 1]);
        ssb.write_dataset(input,'/noise/no',single(0),1);
        meta=struct('pci',p.pci,'ssb_index',idx,'ibar_ssb',r.ibar_ssb, ...
            'lmax',4,'list_length',8,'noise_source','known_simulation');
        bytes=uint8(unicode2native(jsonencode(meta),'UTF-8'));
        ssb.write_dataset(input,'/meta/manifest_json',bytes,numel(bytes));
        ssb.decode_batch_file(input,output);
        verifyEqual(t,h5read(output,'/decoded/crc'),uint8(0));
        verifyEqual(t,h5read(output,'/decoded/scrblk'),uint8(r.scrblk));
        verifyEqual(t,h5read(output,'/decoded/half_frame'),uint8(hf));
        clear cleanup
    end
end
end

function testInvalidMetadata(t)
p=ssb.load_profile('skt'); msg=zeros(24,1); r=ssb.encode(p,msg,0,0,0);
bad={struct('pci',-1),struct('pci',508.2),struct('pci',[1 2]), ...
    struct('lmax',3),struct('lmax',4.1),struct('lmax',[4 8]), ...
    struct('ssb_index',9),struct('ssb_index',1.5),struct('ssb_index',[1 2]), ...
    struct('ibar_ssb',2),struct('ibar_ssb',1.2),struct('ibar_ssb',[1 5])};
for i=1:numel(bad)
    changed=p; name=fieldnames(bad{i}); changed.(name{1})=bad{i}.(name{1});
    verifyError(t,@()ssb.encode(changed,msg,0,0,0),'ssb:InvalidMetadata');
end
invalidArgs={508,9,8,8; 508,1.5,8,8; [508 509],1,8,8; ...
    1008,1,8,8; 508,1,64,8; 508,4,4,8; 508,1,8,3; ...
    508,1,8,0; 508,1,8,[8 16]};
for i=1:size(invalidArgs,1)
    args=invalidArgs(i,:);
    verifyError(t,@()ssb.decode_pbch(r.grid,ones(240,4),0,args{:}),'ssb:InvalidMetadata');
end
meta=struct('pci',508,'ssb_index',1,'ibar_ssb',1,'lmax',8, ...
    'list_length',8,'noise_source','known_simulation');
badBatch=[bad {struct('list_length',3),struct('list_length',1.5), ...
    struct('list_length',[8 16]),struct('lmax',4,'ssb_index',4,'ibar_ssb',4), ...
    struct('lmax',4,'ssb_index',1,'ibar_ssb',2)}];
for i=1:numel(badBatch)
    changed=meta; fields=fieldnames(badBatch{i});
    for j=1:numel(fields), changed.(fields{j})=badBatch{i}.(fields{j}); end
    input=[tempname '.h5']; output=[tempname '.h5'];
    cleanup=onCleanup(@()removeFiles(input,output));
    bytes=uint8(unicode2native(jsonencode(changed),'UTF-8'));
    ssb.write_dataset(input,'/meta/manifest_json',bytes,numel(bytes));
    verifyError(t,@()ssb.decode_batch_file(input,output),'ssb:InvalidMetadata');
    verifyFalse(t,isfile(output)); clear cleanup
end
end

function testOverrideExport(t)
for pci=[326 327]
    path=[tempname '.h5']; cleanup=onCleanup(@()removeFiles(path));
    ssb.export_reference('kt',path,'NumBlocks',2,'Seed',42,'PCI',pci);
    meta=jsondecode(native2unicode(h5read(path,'/meta/manifest_json').','UTF-8'));
    verifyEqual(t,meta.profile_kind,'synthetic_pci_override');
    verifyEqual(t,[meta.observed_pci meta.pci meta.nid1 meta.nid2], ...
        [325 pci floor(pci/3) mod(pci,3)]);
    original=ssb.load_profile('kt');
    verifyEqual(t,meta.source_sha256,original.source_sha256);
    verifyEqual(t,meta.raw.sync_parameters.target_pci,325);
    coords=h5read(path,'/re/dmrs_kl').';
    verifyEqual(t,mod(double(coords(:,1)),4),repmat(mod(pci,4),144,1));
    dm=complex(h5read(path,'/tx/dmrs_real'),h5read(path,'/tx/dmrs_imag'));
    verifyEqual(t,dm,single(nrPBCHDMRS(pci,meta.ibar_ssb)));
    realGrid=h5read(path,'/tx/grid_real'); imagGrid=h5read(path,'/tx/grid_imag');
    scr=h5read(path,'/bits/bch_payload_scrambled32');
    for b=1:2
        y=complex(realGrid(:,:,b).',imagGrid(:,:,b).');
        d=ssb.decode_pbch(y,ones(240,4),0,pci,meta.ssb_index,8,8);
        verifyEqual(t,double(d.crc),0); verifyEqual(t,uint8(d.scrblk),scr(:,b));
    end
    clear cleanup
end
for pci={-1,1008,1.5,[326 327],NaN,[]}
    path=[tempname '.h5']; cleanup=onCleanup(@()removeFiles(path));
    verifyError(t,@()ssb.export_reference('kt',path,'NumBlocks',1,'PCI',pci{1}),'ssb:InvalidMetadata');
    verifyFalse(t,isfile(path)); clear cleanup
end
end

function testBatchFile(t)
p=ssb.load_profile('skt'); r=ssb.encode(p,zeros(24,1),0,0,0);
for B=[1 2]
    input=[tempname '.h5']; output=[tempname '.h5'];
    cleanup=onCleanup(@() removeFiles(input,output));
    grid=repmat(single(r.grid.'),1,1,B); h=ones(4,240,B,'single');
    if B==2, grid(1,1,2)=NaN; end
    ssb.write_dataset(input,'/rx/grid_real',real(grid),[4 240 B]);
    ssb.write_dataset(input,'/rx/grid_imag',imag(grid),[4 240 B]);
    ssb.write_dataset(input,'/estimate/grid_real',h,[4 240 B]);
    ssb.write_dataset(input,'/estimate/grid_imag',zeros(size(h),'single'),[4 240 B]);
    ssb.write_dataset(input,'/noise/no',zeros(B,1,'single'),B);
    meta=struct('pci',p.pci,'ssb_index',p.ssb_index,'ibar_ssb',p.ibar_ssb, ...
        'lmax',8,'noise_source','known_simulation');
    bytes=uint8(unicode2native(jsonencode(meta),'UTF-8'));
    ssb.write_dataset(input,'/meta/manifest_json',bytes,numel(bytes));
    ssb.decode_batch_file(input,output);
    scr=h5read(output,'/decoded/scrblk'); crc=h5read(output,'/decoded/crc');
    err=h5read(output,'/decoded/error_code');
    verifyEqual(t,scr(:,1),uint8(r.scrblk)); verifyEqual(t,crc(1),uint8(0));
    if B==2, verifyEqual(t,err(2),uint8(1)); verifyEqual(t,crc(2),uint8(1)); end
    clear cleanup
end
end

function removeFiles(varargin)
for i=1:nargin, if isfile(varargin{i}), delete(varargin{i}); end, end
end
