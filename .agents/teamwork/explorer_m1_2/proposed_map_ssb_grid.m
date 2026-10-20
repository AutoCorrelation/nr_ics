function [grid, info] = proposed_map_ssb_grid(pbch_syms, arch, N_ID_cell, varargin)
% PROPOSED_MAP_SSB_GRID Maps PBCH symbols and reference signals to 2D SSB grid.
%
%   [GRID, INFO] = MAP_SSB_GRID(PBCH_SYMS, ARCH, N_ID_CELL) maps modulated PBCH
%   symbols into a 240 subcarrier by 4 OFDM symbol resource grid according to
%   the specified 3GPP Rel-15/16 Legacy, Rel-20 Qualcomm Design A, Qualcomm
%   Design B (Comb-SSS), or Jio Platforms SSS-Assisted architecture.
%
%   Inputs:
%     PBCH_SYMS - Modulated PBCH symbols (complex vector):
%                 [432 x 1] for 'Legacy' and 'Jio' (E=864 coded bits)
%                 [480 x 1] for 'DesignA' and 'DesignB' (E=960 coded bits)
%     ARCH      - Architecture identifier string:
%                 'Legacy'  : 3GPP TS 38.211 baseline (127 SSS, 144 DMRS, 432 PBCH, 130 Null)
%                 'DesignA' : Qualcomm R1-2606375 (240 SSS @ Sym 2, 0 DMRS, 480 PBCH, 113 Null)
%                 'DesignB' : Qualcomm R1-2606847 (240 Comb-3 SSS, 0 DMRS, 480 PBCH, 113 Null)
%                 'Jio'     : Jio Platforms R1-2605419 (Legacy grid + SSS joint CE, 271 Pilots)
%     N_ID_CELL - Physical Cell ID (integer in [0, 1007])
%
%   Optional Name-Value Pairs:
%     'PSS'        - Pre-generated PSS sequence [127 x 1]
%     'SSS'        - Pre-generated SSS sequence [127 x 1] or [240 x 1]
%     'DMRS'       - Pre-generated PBCH DMRS sequence [144 x 1]
%     'ibar_SSB'   - SSB candidate index (0..7) for DMRS init (default: 0)
%     'CombShift'  - Comb-3 subcarrier shift v_shift in {0, 1, 2} for Design B
%                    (default: mod(N_ID_CELL, 3))
%
%   Outputs:
%     GRID      - [240 x 4] complex double matrix representing the 2D SSB grid
%     INFO      - Struct containing linear indices and layout metadata:
%                 .arch            - Canonical architecture name
%                 .N_ID_cell       - Physical Cell ID (0..1007)
%                 .N_ID_1          - floor(N_ID_cell / 3) (0..335)
%                 .N_ID_2          - mod(N_ID_cell, 3) (0..2)
%                 .v_shift         - Subcarrier shift
%                 .pbchInd         - Linear indices of PBCH data REs (432 or 480)
%                 .dmrsInd         - Linear indices of DMRS REs (144 or 0)
%                 .sssInd          - Linear indices of SSS REs (127 or 240)
%                 .pssInd          - Linear indices of PSS REs (127)
%                 .nullInd         - Linear indices of null/guard REs (130 or 113)
%                 .pilotInd        - Linear indices of channel estimation pilots
%                 .numDataREs      - 432 or 480
%                 .numPilotREs     - 144, 240, or 271
%                 .numNullREs      - 130 or 113
%                 .polarCodedBits  - 864 or 960
%                 .polarRate       - Code rate for 56-bit MIB payload
%                 .isPhaseCoherent - True for Jio Platforms, false otherwise
%
%   Standard Reference:
%     - 3GPP TS 38.211 Section 7.4.2 & 7.4.3
%     - 3GPP R1-2606375 (Qualcomm Design A)
%     - 3GPP R1-2606847 (Qualcomm Design B / MediaTek Comb-SSS)
%     - 3GPP R1-2605419 (Jio Platforms SSS-Assisted Demodulation)

% --- Argument Validation ---
narginchk(3, inf);

% Validate pbch_syms
validateattributes(pbch_syms, {'numeric'}, {'vector'}, mfilename, 'pbch_syms', 1);
pbch_syms = pbch_syms(:);

% Normalize and validate architecture
arch_str = validatestring(arch, {'Legacy', 'DesignA', 'DesignB', 'Jio'}, mfilename, 'arch', 2);

% Validate cell ID
validateattributes(N_ID_cell, {'numeric'}, {'scalar', 'integer', '>=', 0, '<=', 1007}, mfilename, 'N_ID_cell', 3);

% Parse optional parameters
p = inputParser;
addParameter(p, 'PSS', []);
addParameter(p, 'SSS', []);
addParameter(p, 'DMRS', []);
addParameter(p, 'ibar_SSB', 0, @(x) isscalar(x) && isnumeric(x) && x >= 0 && x <= 7);
addParameter(p, 'CombShift', mod(N_ID_cell, 3), @(x) isscalar(x) && ismember(x, [0, 1, 2]));
parse(p, varargin{:});

opt = p.Results;
ibar_SSB = opt.ibar_SSB;

% Cell ID components
N_ID_1 = floor(N_ID_cell / 3);
N_ID_2 = mod(N_ID_cell, 3);

% Expected PBCH symbol counts
switch arch_str
    case {'Legacy', 'Jio'}
        expectedPbch = 432;
    case {'DesignA', 'DesignB'}
        expectedPbch = 480;
end

if length(pbch_syms) ~= expectedPbch
    error('nr_sim:grid:InvalidSymbolCount', ...
        'Architecture "%s" expects %d PBCH symbols, but received %d.', ...
        arch_str, expectedPbch, length(pbch_syms));
end

% Initialize grid
grid = zeros(240, 4);

% --- PSS Generation and Mapping (Identical for all 4 architectures) ---
% PSS is centered on Symbol 1 (0-based symbol 0), subcarriers 57..183 (0-based 56..182)
pss_k = (57:183)';
pss_l = ones(127, 1);
pssInd = sub2ind([240, 4], pss_k, pss_l);

if isempty(opt.PSS)
    if ~isempty(which('nr_sim.sequences.gen_PSSNR'))
        pssSeq = nr_sim.sequences.gen_PSSNR(N_ID_2);
    elseif ~isempty(which('gen_PSSNR'))
        pssSeq = gen_PSSNR(N_ID_2);
    elseif ~isempty(which('nrPSS'))
        pssSeq = nrPSS(N_ID_2);
    else
        error('nr_sim:grid:MissingPSSGenerator', 'No PSS generator found on MATLAB path.');
    end
else
    pssSeq = opt.PSS(:);
    if length(pssSeq) ~= 127
        error('nr_sim:grid:InvalidPSSLength', 'PSS must be of length 127.');
    end
end
grid(pssInd) = pssSeq;

% --- Architecture-Specific Mapping ---
switch arch_str
    case {'Legacy', 'Jio'}
        v_shift = mod(N_ID_cell, 4);
        
        % 1. SSS on Symbol 3, subcarriers 57..183 (0-based symbol 2, subcarriers 56..182)
        sss_k = (57:183)';
        sss_l = 3 * ones(127, 1);
        sssInd = sub2ind([240, 4], sss_k, sss_l);
        
        if isempty(opt.SSS)
            if ~isempty(which('nr_sim.sequences.gen_SSS'))
                sssSeq = nr_sim.sequences.gen_SSS(N_ID_1, N_ID_2);
            elseif ~isempty(which('gen_SSS'))
                sssSeq = gen_SSS(N_ID_1, N_ID_2);
            elseif ~isempty(which('nrSSS'))
                sssSeq = nrSSS(N_ID_cell);
            else
                error('nr_sim:grid:MissingSSSGenerator', 'No SSS generator found on MATLAB path.');
            end
        else
            sssSeq = opt.SSS(:);
            if length(sssSeq) ~= 127
                error('nr_sim:grid:InvalidSSSLength', 'Legacy/Jio SSS must have length 127.');
            end
        end
        grid(sssInd) = sssSeq;
        
        % 2. PBCH DMRS (TS 38.211 §7.4.3.1)
        % Symbol 2: 60 REs, m=0..59, k_0based = 4*m + v_shift
        dmrs_k_sym2 = (4*(0:59) + v_shift + 1)';
        dmrs_l_sym2 = 2 * ones(60, 1);
        
        % Symbol 3: 24 REs, lower m=0..11, upper m=48..59
        dmrs_k_sym3 = [4*(0:11) + v_shift + 1, 4*(48:59) + v_shift + 1]';
        dmrs_l_sym3 = 3 * ones(24, 1);
        
        % Symbol 4: 60 REs, m=0..59
        dmrs_k_sym4 = (4*(0:59) + v_shift + 1)';
        dmrs_l_sym4 = 4 * ones(60, 1);
        
        dmrsInd = [sub2ind([240, 4], dmrs_k_sym2, dmrs_l_sym2); ...
                   sub2ind([240, 4], dmrs_k_sym3, dmrs_l_sym3); ...
                   sub2ind([240, 4], dmrs_k_sym4, dmrs_l_sym4)];
               
        if isempty(opt.DMRS)
            if ~isempty(which('nr_sim.sequences.gen_PBCHDMRS'))
                dmrsSeq = nr_sim.sequences.gen_PBCHDMRS(N_ID_cell, ibar_SSB);
            elseif ~isempty(which('gen_PBCHDMRS'))
                dmrsSeq = gen_PBCHDMRS(N_ID_cell, ibar_SSB);
            elseif ~isempty(which('nrPBCHDMRS'))
                dmrsSeq = nrPBCHDMRS(N_ID_cell, ibar_SSB);
            else
                error('nr_sim:grid:MissingDMRSGenerator', 'No PBCH DMRS generator found on MATLAB path.');
            end
        else
            dmrsSeq = opt.DMRS(:);
            if length(dmrsSeq) ~= 144
                error('nr_sim:grid:InvalidDMRSLength', 'PBCH DMRS must have length 144.');
            end
        end
        grid(dmrsInd) = dmrsSeq;
        
        % 3. PBCH Data (432 REs)
        pbch_k_sym2 = setdiff((1:240)', dmrs_k_sym2);
        pbch_k_sym3 = [setdiff((1:48)', 4*(0:11)' + v_shift + 1); ...
                       setdiff((193:240)', 4*(48:59)' + v_shift + 1)];
        pbch_k_sym4 = setdiff((1:240)', dmrs_k_sym4);
        
        pbchInd = [sub2ind([240, 4], pbch_k_sym2, 2*ones(180, 1)); ...
                   sub2ind([240, 4], pbch_k_sym3, 3*ones(72, 1)); ...
                   sub2ind([240, 4], pbch_k_sym4, 4*ones(180, 1))];
        grid(pbchInd) = pbch_syms;
        
        if strcmp(arch_str, 'Legacy')
            pilotInd = dmrsInd;
            isPhaseCoherent = false;
        else
            % Jio Platforms: DMRS (144) + SSS (127) form 271 joint pilots
            pilotInd = [dmrsInd; sssInd];
            isPhaseCoherent = true;
        end
        
    case 'DesignA'
        v_shift = 0;
        
        % Concentrated Extended SSS on Symbol 3 (all 240 subcarriers)
        sss_k = (1:240)';
        sss_l = 3 * ones(240, 1);
        sssInd = sub2ind([240, 4], sss_k, sss_l);
        
        if isempty(opt.SSS)
            if ~isempty(which('nr_sim.sequences.gen_ExtendedSSS'))
                extSssSeq = nr_sim.sequences.gen_ExtendedSSS(N_ID_cell);
            elseif ~isempty(which('gen_ExtendedSSS'))
                extSssSeq = gen_ExtendedSSS(N_ID_cell);
            else
                extSssSeq = internal_gen_ExtendedSSS(N_ID_cell);
            end
        else
            extSssSeq = opt.SSS(:);
            if length(extSssSeq) ~= 240
                error('nr_sim:grid:InvalidExtSSSLength', 'Extended SSS must have length 240.');
            end
        end
        grid(sssInd) = extSssSeq;
        
        % DMRS: 0 REs
        dmrsInd = zeros(0, 1);
        
        % PBCH Data: 240 REs on Symbol 2, 240 REs on Symbol 4
        pbchInd = [sub2ind([240, 4], (1:240)', 2*ones(240, 1)); ...
                   sub2ind([240, 4], (1:240)', 4*ones(240, 1))];
        grid(pbchInd) = pbch_syms;
        
        % Channel estimation pilot is SSS at Symbol 3
        pilotInd = sssInd;
        isPhaseCoherent = false;
        
    case 'DesignB'
        v_shift = opt.CombShift;
        
        % Distributed Comb-3 SSS: 80 REs per symbol on Symbols 2, 3, 4
        k_sss_sym = (3*(0:79) + v_shift + 1)';
        k_pbch_sym = setdiff((1:240)', k_sss_sym);
        
        sssInd = zeros(240, 1);
        pbchInd = zeros(480, 1);
        for sIdx = 1:3
            sym = sIdx + 1;
            sssInd((sIdx-1)*80 + (1:80)) = sub2ind([240, 4], k_sss_sym, sym*ones(80, 1));
            pbchInd((sIdx-1)*160 + (1:160)) = sub2ind([240, 4], k_pbch_sym, sym*ones(160, 1));
        end
        
        if isempty(opt.SSS)
            if ~isempty(which('nr_sim.sequences.gen_ExtendedSSS'))
                extSssSeq = nr_sim.sequences.gen_ExtendedSSS(N_ID_cell);
            elseif ~isempty(which('gen_ExtendedSSS'))
                extSssSeq = gen_ExtendedSSS(N_ID_cell);
            else
                extSssSeq = internal_gen_ExtendedSSS(N_ID_cell);
            end
        else
            extSssSeq = opt.SSS(:);
            if length(extSssSeq) ~= 240
                error('nr_sim:grid:InvalidExtSSSLength', 'Comb-SSS must have total length 240.');
            end
        end
        grid(sssInd) = extSssSeq;
        
        % DMRS: 0 REs
        dmrsInd = zeros(0, 1);
        
        % PBCH Data: 480 REs
        grid(pbchInd) = pbch_syms;
        
        % Pilots are distributed Comb-3 SSS
        pilotInd = sssInd;
        isPhaseCoherent = false;
end

% --- Compute Null Indices and Metadata ---
allOccupied = [pssInd; sssInd; dmrsInd; pbchInd];
nullInd = setdiff((1:960)', allOccupied);

% Populate info struct
info.arch            = arch_str;
info.N_ID_cell       = N_ID_cell;
info.N_ID_1          = N_ID_1;
info.N_ID_2          = N_ID_2;
info.v_shift         = v_shift;
info.pbchInd         = pbchInd;
info.dmrsInd         = dmrsInd;
info.sssInd          = sssInd;
info.pssInd          = pssInd;
info.nullInd         = nullInd;
info.pilotInd        = pilotInd;
info.numDataREs      = length(pbchInd);
info.numPilotREs     = length(pilotInd);
info.numNullREs      = length(nullInd);
info.polarCodedBits  = 2 * length(pbchInd);
info.polarRate       = 56 / info.polarCodedBits;
info.isPhaseCoherent = isPhaseCoherent;

end

% --- Fallback Generator for Extended SSS (Base-255 Gold truncated to 240) ---
function d_ext = internal_gen_ExtendedSSS(N_ID_cell)
    % Shift register generator:
    % s0: D^8 + D^4 + D^3 + D^2 + 1
    % s1: D^8 + D^6 + D^5 + D^3 + 1
    s0 = zeros(1, 512);
    s1 = zeros(1, 512);
    s0(1) = 1;
    s1(1) = 1;
    for i = 1:500
        s0(i+8) = mod(s0(i+4) + s0(i+3) + s0(i+2) + s0(i), 2);
        s1(i+8) = mod(s1(i+6) + s1(i+5) + s1(i+3) + s1(i), 2);
    end
    m0 = mod(N_ID_cell, 255);
    m1 = floor(N_ID_cell / 255) * 64;
    c = mod(s0(m0 + (1:240)) + s1(m1 + (1:240)), 2);
    d_ext = 1 - 2*double(c(:));
end

