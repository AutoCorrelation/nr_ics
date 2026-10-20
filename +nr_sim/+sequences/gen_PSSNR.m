function d_pss = gen_PSSNR(N_ID_2)
%GEN_PSSNR Primary Synchronization Signal (PSS) Generator per 3GPP TS 38.211 §7.4.2.2.1
%
%   d_pss = nr_sim.sequences.gen_PSSNR(N_ID_2) generates the length-127 BPSK
%   PSS sequence for sector ID N_ID_2 in {0, 1, 2}.
%
%   Inputs:
%       N_ID_2 - Physical layer cell sector identity (0, 1, or 2). Default: 0.
%
%   Outputs:
%       d_pss  - [127 x 1 double] BPSK sequence with values in {-1, +1}.
%
%   Standard Reference:
%       3GPP TS 38.211 Section 7.4.2.2.1
%       Recurrence: x(i+7) = (x(i+4) + x(i)) mod 2
%       Initial state: [x(0)...x(6)] = [0, 1, 1, 0, 1, 1, 1]
%       Shift: m = (n + 43*N_ID_2) mod 127, 0 <= n < 127
%       BPSK modulation: d_pss(n) = 1 - 2*x(m)

    % Input validation and default handling
    if nargin < 1 || isempty(N_ID_2)
        N_ID_2 = 0;
    else
        validateattributes(N_ID_2, {'numeric'}, ...
            {'scalar', 'integer', '>=', 0, '<=', 2}, mfilename, 'N_ID_2');
    end

    % Shift register initialization (length 127)
    x = zeros(1, 127);
    x(1:7) = [0, 1, 1, 0, 1, 1, 1];

    % Generate m-sequence using primitive polynomial D^7 + D^4 + 1
    for i = 0:119
        x(i + 8) = mod(x(i + 5) + x(i + 1), 2);
    end

    % Apply cyclic shift 43 * N_ID_2 and BPSK modulation
    n = 0:126;
    m = mod(n + 43 * N_ID_2, 127);
    d_pss = (1 - 2 * x(m + 1)).';

end
