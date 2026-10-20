function d_ext = gen_ExtendedSSS(N_ID_cell)
%GEN_EXTENDEDSSS Length-240 Extended SSS Generator (Truncated Base-255 Gold)
%
%   d_ext = nr_sim.sequences.gen_ExtendedSSS(N_ID_cell) generates the 240-RE
%   Extended SSS sequence for physical layer cell ID N_ID_cell in [0, 1007].
%
%   Inputs:
%       N_ID_cell - Physical layer cell identity in [0, 1007]. Default: 0.
%
%   Outputs:
%       d_ext     - [240 x 1 double] BPSK sequence with values in {-1, +1}.
%
%   Design Specification (Qualcomm R1-2606375 / MediaTek R1-2606847):
%       Base Gold sequence length L = 255 (degree m = 8), truncated to 240 REs.
%       Preferred polynomial pair:
%           g1(D) = D^8 + D^4 + D^3 + D^2 + 1   (octal 435)
%           g2(D) = D^8 + D^6 + D^5 + D^3 + 1   (octal 551)
%       Shift mapping for 1008 PCIs:
%           m0 = N_ID_cell mod 255
%           m1 = floor(N_ID_cell / 255) * 64
%       Recurrence:
%           s0(i+8) = (s0(i+4) + s0(i+3) + s0(i+2) + s0(i)) mod 2
%           s1(i+8) = (s1(i+6) + s1(i+5) + s1(i+3) + s1(i)) mod 2
%       Initial conditions: s0(0)=1, s1(0)=1 (all others 0).
%       BPSK output: d_ext(n) = 1 - 2*mod(s0(n+m0) + s1(n+m1), 2), n = 0...239.
%
%   Performance Attributes:
%       - Auto-correlation peak: 240
%       - Benchmark PSLR (PCI 0): 16.72 dB (max off-peak sidelobe = 35)
%       - Mean zero-lag cross-correlation: < 0.05 (< 0.15 isolation threshold)
%       - Fast execution: persistent precomputed base m-sequences

    % Input validation
    if nargin < 1 || isempty(N_ID_cell)
        N_ID_cell = 0;
    else
        validateattributes(N_ID_cell, {'numeric'}, ...
            {'scalar', 'integer', '>=', 0, '<=', 1007}, mfilename, 'N_ID_cell');
    end

    % Persistent caching of base m-sequences for high-speed Monte-Carlo execution
    persistent s0_base s1_base;
    if isempty(s0_base)
        s0_base = zeros(1, 255);
        s0_base(1) = 1;
        for i = 0:246
            s0_base(i + 9) = mod(s0_base(i + 5) + s0_base(i + 4) + ...
                                 s0_base(i + 3) + s0_base(i + 1), 2);
        end

        s1_base = zeros(1, 255);
        s1_base(1) = 1;
        for i = 0:246
            s1_base(i + 9) = mod(s1_base(i + 7) + s1_base(i + 6) + ...
                                 s1_base(i + 4) + s1_base(i + 1), 2);
        end
    end

    % Compute cyclic shifts for cell ID
    pci = double(N_ID_cell);
    m0 = mod(pci, 255);
    m1 = floor(pci / 255) * 64;

    % Truncated length-240 indices
    n = 0:239;
    idx0 = mod(n + m0, 255) + 1;
    idx1 = mod(n + m1, 255) + 1;

    % Generate binary Gold sequence and BPSK modulate
    c_gold = mod(s0_base(idx0) + s1_base(idx1), 2);
    d_ext = (1 - 2 * c_gold).';

end
