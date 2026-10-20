function dmrs_seq = gen_PBCHDMRS(N_ID_cell, ibar_SSB)
%GEN_PBCHDMRS PBCH Demodulation Reference Signal (DMRS) Generator per 3GPP TS 38.211 §7.4.3.1
%
%   dmrs_seq = nr_sim.sequences.gen_PBCHDMRS(N_ID_cell, ibar_SSB) generates the
%   144-element complex PBCH DMRS sequence for cell ID N_ID_cell in [0, 1007]
%   and time index ibar_SSB in [0, 7].
%
%   Inputs:
%       N_ID_cell - Physical layer cell identity in [0, 1007]. Default: 0.
%       ibar_SSB  - Time-dependent scrambling parameter in [0, 7]. Default: 0.
%
%   Outputs:
%       dmrs_seq  - [144 x 1 complex double] unit average power reference symbols:
%                   r(m) = 1/sqrt(2)*(1 - 2*c(2*m)) + 1j/sqrt(2)*(1 - 2*c(2*m+1)), m=0..143.
%
%   Standard Reference:
%       3GPP TS 38.211 Section 7.4.3.1 & Section 5.2.1 (Gold-31 PRBS)
%       c_init = 2^11*(ibar_SSB + 1)*(floor(N_ID_cell/4) + 1) + 2^6*(ibar_SSB + 1) + mod(N_ID_cell, 4)

    % Input validation
    if nargin < 1 || isempty(N_ID_cell)
        N_ID_cell = 0;
    else
        validateattributes(N_ID_cell, {'numeric'}, ...
            {'scalar', 'integer', '>=', 0, '<=', 1007}, mfilename, 'N_ID_cell');
    end

    if nargin < 2 || isempty(ibar_SSB)
        ibar_SSB = 0;
    else
        validateattributes(ibar_SSB, {'numeric'}, ...
            {'scalar', 'integer', '>=', 0, '<=', 7}, mfilename, 'ibar_SSB');
    end

    % 5G Toolbox fast path if available
    if ~isempty(which('nrPBCHDMRS'))
        dmrs_seq = nrPBCHDMRS(double(N_ID_cell), double(ibar_SSB));
        return;
    end

    % Standalone TS 38.211 §5.2.1 Gold-31 PRBS fallback
    pci = double(N_ID_cell);
    ibar = double(ibar_SSB);
    cinit = 2^11 * (ibar + 1) * (floor(pci / 4) + 1) + 2^6 * (ibar + 1) + mod(pci, 4);

    N = 288;      % 2 * 144 bits for QPSK
    Nc = 1600;    % 3GPP TS 38.211 initial displacement

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

    % Gold-31 output
    c = mod(x1(Nc + 1 : Nc + N) + x2(Nc + 1 : Nc + N), 2);

    % QPSK symbol modulation per TS 38.211 §7.4.3.1
    m = 0:143;
    r_real = (1 - 2 * c(2 * m + 1)) / sqrt(2);
    r_imag = (1 - 2 * c(2 * m + 2)) / sqrt(2);
    dmrs_seq = (r_real + 1j * r_imag).';

end
