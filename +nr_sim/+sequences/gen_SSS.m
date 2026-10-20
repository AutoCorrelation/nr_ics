function d_sss = gen_SSS(varargin)
%GEN_SSS Secondary Synchronization Signal (SSS) Generator per 3GPP TS 38.211 §7.4.2.3.1
%
%   d_sss = nr_sim.sequences.gen_SSS() generates length-127 SSS for cell ID 0
%   (N_ID_1 = 0, N_ID_2 = 0). Default: 0.
%
%   d_sss = nr_sim.sequences.gen_SSS(N_ID_cell) generates length-127 SSS
%   from physical layer cell ID N_ID_cell in [0, 1007], decomposing it as:
%       N_ID_1 = floor(N_ID_cell / 3)
%       N_ID_2 = mod(N_ID_cell, 3)
%   If N_ID_cell is empty ([]), it defaults to 0.
%
%   d_sss = nr_sim.sequences.gen_SSS(N_ID_1, N_ID_2) generates length-127 SSS
%   from N_ID_1 in [0, 335] and N_ID_2 in [0, 2].
%   If either N_ID_1 or N_ID_2 is empty ([]), it defaults to 0.
%
%   Outputs:
%       d_sss - [127 x 1 double] BPSK sequence with values in {-1, +1}.
%
%   Standard Reference:
%       3GPP TS 38.211 Section 7.4.2.3.1
%       d_SSS(n) = [1 - 2*x0((n + m0) mod 127)] * [1 - 2*x1((n + m1) mod 127)]
%       m0 = 15*floor(N_ID_1 / 112) + 5*N_ID_2
%       m1 = N_ID_1 mod 112
%       x0 init: [1, 0, 0, 0, 0, 0, 0] with recurrence x0(i+7) = (x0(i+4) + x0(i)) mod 2
%       x1 init: [1, 0, 0, 0, 0, 0, 0] with recurrence x1(i+7) = (x1(i+1) + x1(i)) mod 2

    % Input argument parsing and validation
    narginchk(0, 2);

    if nargin == 0
        N_ID_1 = 0;
        N_ID_2 = 0;
    elseif nargin == 1
        if isempty(varargin{1})
            N_ID_1 = 0;
            N_ID_2 = 0;
        else
            N_ID_cell = varargin{1};
            validateattributes(N_ID_cell, {'numeric'}, ...
                {'scalar', 'integer', '>=', 0, '<=', 1007}, mfilename, 'N_ID_cell');
            N_ID_1 = floor(double(N_ID_cell) / 3);
            N_ID_2 = mod(double(N_ID_cell), 3);
        end
    else
        if isempty(varargin{1})
            N_ID_1 = 0;
        else
            N_ID_1 = varargin{1};
            validateattributes(N_ID_1, {'numeric'}, ...
                {'scalar', 'integer', '>=', 0, '<=', 335}, mfilename, 'N_ID_1');
        end

        if isempty(varargin{2})
            N_ID_2 = 0;
        else
            N_ID_2 = varargin{2};
            validateattributes(N_ID_2, {'numeric'}, ...
                {'scalar', 'integer', '>=', 0, '<=', 2}, mfilename, 'N_ID_2');
        end
    end

    % Shift register initialization (length 127)
    % Initial states: [x(0)...x(6)] = [1, 0, 0, 0, 0, 0, 0]
    x0 = zeros(1, 127);
    x0(1) = 1;
    for i = 0:119
        x0(i + 8) = mod(x0(i + 5) + x0(i + 1), 2);
    end

    x1 = zeros(1, 127);
    x1(1) = 1;
    for i = 0:119
        x1(i + 8) = mod(x1(i + 2) + x1(i + 1), 2);
    end

    % Shift offsets per TS 38.211 §7.4.2.3.1
    m0 = 15 * floor(double(N_ID_1) / 112) + 5 * double(N_ID_2);
    m1 = mod(double(N_ID_1), 112);

    n = 0:126;
    s0 = 1 - 2 * x0(mod(n + m0, 127) + 1);
    s1 = 1 - 2 * x1(mod(n + m1, 127) + 1);

    d_sss = (s0 .* s1).';

end
