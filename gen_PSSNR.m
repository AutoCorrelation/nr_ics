function d_pss = gen_PSSNR(N_ID_2)
    % 3GPP TS 38.211 Section 7.4.2.2.1 Primary synchronization signal
    % Input: N_ID_2 (0, 1, or 2)
    % Output: d_pss (1x127 sequence)
    
    if nargin < 1
        N_ID_2 = 0;
    end
    
    if ~ismember(N_ID_2, [0, 1, 2])
        error('N_ID_2 must be 0, 1, or 2.');
    end

    % 1. Initialization of x(0) to x(6)
    x = zeros(1, 127);
    x(1:7) = [0 1 1 0 1 1 1];
    
    % 2. M-sequence generation
    for i = 0:119
        % x(i+7) = (x(i+4) + x(i)) mod 2
        x(i+7+1) = mod(x(i+4+1) + x(i+1), 2);
    end
    
    % 3. PSS sequence generation
    n = 0:126;
    m = mod(n + 43 * N_ID_2, 127);
    d_pss = 1 - 2 * x(m + 1);
end