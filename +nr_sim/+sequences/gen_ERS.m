function ers_seq = gen_ERS(N_ID_cell)
%GEN_ERS Extension Reference Signal (E-RS) Generator for 5-Symbol SSB
%
%   ers_seq = nr_sim.sequences.gen_ERS(N_ID_cell) generates the 96-element
%   complex reference signal sequence for the proposed 5-symbol SSB extension.
%   E-RS occupies 96 subcarriers (48 REs on each outer band: k=0..47 and k=192..239)
%   in the 5th OFDM symbol (l=4) to reinforce PBCH channel estimation.
%
%   Inputs:
%       N_ID_cell - Physical layer cell identity in [0, 1007]. Default: 0.
%
%   Outputs:
%       ers_seq   - [96 x 1 complex double] unit average power reference symbols:
%                   r(m) = 1/sqrt(2)*(1 - 2*c(2*m)) + 1j/sqrt(2)*(1 - 2*c(2*m+1)), m=0..95.
%
%   Standard Specification / Proposal Reference:
%       Gold-31 PRBS per TS 38.211 §5.2.1
%       c_init = mod(N_ID_cell + 1, 2^31)
%       Directly identifiable upon SSS detection with zero blind index search.

    % Input validation
    if nargin < 1 || isempty(N_ID_cell)
        N_ID_cell = 0;
    else
        validateattributes(N_ID_cell, {'numeric'}, ...
            {'scalar', 'integer', '>=', 0, '<=', 1007}, mfilename, 'N_ID_cell');
    end

    pci = double(N_ID_cell);
    cinit = mod(pci + 1, 2^31);

    numPilots = 96;
    N = 2 * numPilots; % 192 pseudo-random bits for QPSK
    Nc = 1600;        % 3GPP TS 38.211 standard displacement

    % Shift register 1: x1(n+31) = (x1(n+3) + x1(n)) mod 2, init: x1(0)=1, x1(1..30)=0
    x1 = zeros(1, Nc + N + 31);
    x1(1) = 1;
    for n = 0:(Nc + N - 1)
        x1(n + 32) = mod(x1(n + 4) + x1(n + 1), 2);
    end

    % Shift register 2: x2(n+31) = (x2(n+3) + x2(n+2) + x2(n+1) + x2(n)) mod 2
    x2 = zeros(1, Nc + N + 31);
    for b = 0:30
        x2(b + 1) = bitget(cinit, b + 1);
    end
    for n = 0:(Nc + N - 1)
        x2(n + 32) = mod(x2(n + 4) + x2(n + 3) + x2(n + 2) + x2(n + 1), 2);
    end

    % Gold sequence: c(n) = (x1(n + Nc) + x2(n + Nc)) mod 2
    c = mod(x1(Nc + (1:N)) + x2(Nc + (1:N)), 2);

    % QPSK symbol generation with unit average power
    m = 0:(numPilots - 1);
    ers_seq = complex(1 - 2 * c(2 * m + 1), 1 - 2 * c(2 * m + 2))' / sqrt(2);
end
