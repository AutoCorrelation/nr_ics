function x = loaddump(target_file)
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end

candidate_paths = {
    fullfile(script_dir, 'dumpdataNR', target_file);
    fullfile('dumpdataNR', target_file);
    fullfile('nr_ics', 'dumpdataNR', target_file)
    };

filepath = '';
for k = 1:length(candidate_paths)
    if exist(candidate_paths{k}, 'file')
        filepath = candidate_paths{k};
        break;
    end
end

if isempty(filepath)
    error('덤프 파일을 찾을 수 없습니다: %s', target_file);
end

% 복소수 데이터 읽기 (1행: I, 2행: Q)
fid = fopen(filepath, 'rb');
raw = fread(fid, [2, inf], 'int16');
fclose(fid);
x = complex(raw(1, :), raw(2, :)) / 32767;
end
