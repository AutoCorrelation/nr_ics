function p = load_profile(operator)
%LOAD_PROFILE Load observed metadata, preserving unverified capture values.
operator = validatestring(operator,{'skt','kt','lgu'});
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
path = fullfile(root,'NRdump',[operator '_40ms.json']);
raw = jsondecode(fileread(path));
bytes = uint8(fileread(path));
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
hash = lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
p = struct('operator_id',operator,'operator',raw.operator, ...
    'pci',raw.sync_parameters.target_pci,'ssb_index',raw.sync_parameters.ssb_index, ...
    'ibar_ssb',raw.sync_parameters.ssb_index,'lmax',8, ...
    'scs_hz',raw.scs_khz*1000,'ssref_hz',raw.sync_parameters.ssb_center_freq_hz, ...
    'capture_center_hz',raw.center_freq_hz,'sample_rate_hz',raw.sample_rate_hz, ...
    'raw',raw,'source_json',['NRdump/' operator '_40ms.json'],'source_sha256',hash);
end
