function results = verify_all_initial_search()
%VERIFY_ALL_INITIAL_SEARCH Run all three captures independently.
operators = {'lgu','skt','kt'};
results = struct;
for k = 1:numel(operators)
    operator = operators{k};
    fprintf('\n=== %s ===\n',upper(operator));
    try
        results.(operator) = verify_initial_search(operator);
    catch exception
        results.(operator) = struct('CRC',NaN,'Error',exception.message);
        warning('Capture %s: %s',operator,exception.message);
    end
end
end
