function decode_batch_file(inputPath,outputPath)
%DECODE_BATCH_FILE Decode a homogeneous batch from the frozen HDF5 contract.
inputPath=char(inputPath); outputPath=char(outputPath);
if isfile(outputPath), error('ssb:FileExists','Refusing to overwrite %s',outputPath); end
bytes=h5read(inputPath,'/meta/manifest_json');
if isnumeric(bytes), metadata=jsondecode(native2unicode(uint8(bytes(:).'),'UTF-8'));
else, metadata=jsondecode(char(bytes)); end
if ~isfield(metadata,'list_length'), metadata.list_length=8; end
assert(strcmp(metadata.noise_source,'known_simulation'),'ssb:InvalidInput','Expected known simulation noise.');
ssb.validate_metadata(metadata.pci,metadata.ssb_index,metadata.lmax,metadata.list_length,metadata.ibar_ssb);
yr=h5read(inputPath,'/rx/grid_real'); yi=h5read(inputPath,'/rx/grid_imag');
hr=h5read(inputPath,'/estimate/grid_real'); hi=h5read(inputPath,'/estimate/grid_imag');
n0=double(h5read(inputPath,'/noise/no')); B=numel(n0);
assert(isequal(size(yr,1),4) && size(yr,2)==240 && size(yr,3)==B);
assert(isequal(size(yr),size(yi),size(hr),size(hi)),'ssb:InvalidInput','Grid dimensions differ.');
% Resolve global setup/license errors before entering the per-block loop.
nrPBCHDMRS(metadata.pci,metadata.ibar_ssb);
testcw=nrBCH(zeros(24,1),0,0,metadata.lmax,0,metadata.pci);
nrBCHDecode((1-2*double(testcw))*100,metadata.list_length);
crc=ones(B,1,'uint8'); scr=zeros(32,B,'uint8'); tr=zeros(24,B,'uint8');
sfn=zeros(4,B,'uint8'); hf=zeros(B,1,'uint8'); off=zeros(B,1,'uint8'); err=zeros(B,1,'uint8');
for b=1:B
    y=complex(double(yr(:,:,b).'),double(yi(:,:,b).'));
    h=complex(double(hr(:,:,b).'),double(hi(:,:,b).'));
    if ~isfinite(n0(b)) || n0(b)<0 || any(~isfinite(y(:))) || any(~isfinite(h(:)))
        err(b)=1; fprintf(2,'Block %d numerical input failure: nonfinite grid or negative N0.\n',b); continue
    end
    try
        d=ssb.decode_pbch(y,h,n0(b),metadata.pci,metadata.ssb_index,metadata.lmax,metadata.list_length);
        crc(b)=d.crc; scr(:,b)=d.scrblk; tr(:,b)=d.trblk;
        sfn(:,b)=d.sfn_lsb; hf(b)=d.half_frame; off(b)=d.msb_index_offset;
    catch e
        if ~strcmp(e.identifier,'ssb:NumericalFailure'), rethrow(e); end
        err(b)=2; fprintf(2,'Block %d numerical decoder failure: %s\n',b,e.message);
    end
end
folder=fileparts(outputPath); if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
tmp=[tempname(folder) '.h5']; cleanup=onCleanup(@() cleanup_temp(tmp));
ssb.write_dataset(tmp,'/decoded/crc',crc,B); ssb.write_dataset(tmp,'/decoded/scrblk',scr,[32 B]);
ssb.write_dataset(tmp,'/decoded/trblk',tr,[24 B]); ssb.write_dataset(tmp,'/decoded/sfn_lsb',sfn,[4 B]);
ssb.write_dataset(tmp,'/decoded/half_frame',hf,B); ssb.write_dataset(tmp,'/decoded/msb_index_offset',off,B);
ssb.write_dataset(tmp,'/decoded/error_code',err,B);
metadata.schema_version='ssb-decode-result-v1'; metadata.matlab_release=version('-release');
metadata.error_codes='0=none, 1=invalid numerical input, 2=nonfinite decoder output';
bytes=uint8(unicode2native(jsonencode(metadata),'UTF-8'));
ssb.write_dataset(tmp,'/meta/manifest_json',bytes,numel(bytes));
h5writeatt(tmp,'/','schema_version','ssb-decode-result-v1');
movefile(tmp,outputPath);
fprintf('Decoded %d blocks: %d CRC failures, %d numerical failures, list=%d, MATLAB %s.\n', ...
    B,nnz(crc),nnz(err),metadata.list_length,version('-release'));
end

function cleanup_temp(path)
if isfile(path), delete(path); end
end
