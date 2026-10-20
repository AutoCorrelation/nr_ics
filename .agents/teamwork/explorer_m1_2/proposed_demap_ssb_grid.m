function [rx_pbch, rx_pilots, ref_pilots, info] = proposed_demap_ssb_grid(grid, arch, N_ID_cell, varargin)
% PROPOSED_DEMAP_SSB_GRID Demaps PBCH and pilot REs from 2D SSB received grid.
%
%   [RX_PBCH, RX_PILOTS, REF_PILOTS, INFO] = DEMAP_SSB_GRID(GRID, ARCH, N_ID_CELL)
%   extracts modulated PBCH data symbols and channel estimation reference
%   signals from a received 2D SSB resource grid across 1 or multiple receive
%   antennas (e.g. 1T4R SIMO).
%
%   Inputs:
%     GRID       - Received frequency grid:
%                  [240 x 4] for single antenna, or
%                  [240 x 4 x N_rx] for multi-antenna (e.g. N_rx=4)
%     ARCH       - Architecture identifier string:
%                  'Legacy', 'DesignA', 'DesignB', or 'Jio'
%     N_ID_CELL  - Physical Cell ID (integer in [0, 1007])
%
%   Optional Name-Value Pairs:
%     'ibar_SSB'   - SSB candidate index (0..7) for DMRS regeneration (default: 0)
%     'CombShift'  - Comb-3 subcarrier shift in {0, 1, 2} for Design B
%                    (default: mod(N_ID_CELL, 3))
%     'KnownDMRS'  - Precomputed PBCH DMRS sequence [144 x 1]
%     'KnownSSS'   - Precomputed SSS sequence [127 x 1] or [240 x 1]
%
%   Outputs:
%     RX_PBCH    - Extracted PBCH data symbols:
%                  [432 x N_rx] for Legacy / Jio
%                  [480 x N_rx] for DesignA / DesignB
%     RX_PILOTS  - Extracted pilot symbols:
%                  [144 x N_rx] for Legacy (DMRS)
%                  [240 x N_rx] for DesignA (Symbol 3 SSS)
%                  [240 x N_rx] for DesignB (Comb-3 SSS across Symbols 2..4)
%                  [271 x N_rx] for Jio (144 DMRS + 127 SSS)
%     REF_PILOTS - Transmitted reference pilot symbols [N_pilots x 1]:
%                  Enables immediate LS channel estimation via:
%                  H_LS = rx_pilots ./ ref_pilots;
%     INFO       - Struct containing indices and coordinates:
%                  .pbchInd, .dmrsInd, .sssInd, .pssInd, .pilotInd
%                  .subcarrierIndices, .symbolIndices per channel estimator.
%
%   Standard Reference:
%     - 3GPP TS 38.211 Section 7.4.2 & 7.4.3
%     - 3GPP R1-2606375 (Qualcomm Design A)
%     - 3GPP R1-2606847 (Qualcomm Design B / MediaTek Comb-SSS)
%     - 3GPP R1-2605419 (Jio Platforms SSS-Assisted Demodulation)

% --- Argument Validation ---
narginchk(3, inf);

sz = size(grid);
if sz(1) ~= 240 || sz(2) ~= 4
    error('nr_sim:grid:InvalidGridSize', ...
        'Input grid must have first two dimensions [240 x 4], but received [%s].', ...
        num2str(sz));
end

numRx = 1;
if numel(sz) >= 3
    numRx = prod(sz(3:end));
end

% Normalize architecture string
arch_str = validatestring(arch, {'Legacy', 'DesignA', 'DesignB', 'Jio'}, mfilename, 'arch', 2);

% Validate cell ID
validateattributes(N_ID_cell, {'numeric'}, {'scalar', 'integer', '>=', 0, '<=', 1007}, mfilename, 'N_ID_cell', 3);

% Parse optional parameters
p = inputParser;
addParameter(p, 'ibar_SSB', 0, @(x) isscalar(x) && isnumeric(x) && x >= 0 && x <= 7);
addParameter(p, 'CombShift', mod(N_ID_cell, 3), @(x) isscalar(x) && ismember(x, [0, 1, 2]));
addParameter(p, 'KnownDMRS', []);
addParameter(p, 'KnownSSS', []);
parse(p, varargin{:});

opt = p.Results;
ibar_SSB = opt.ibar_SSB;

% Cell ID components
N_ID_1 = floor(N_ID_cell / 3);
N_ID_2 = mod(N_ID_cell, 3);

% PSS indices (common to all architectures)
pss_k = (57:183)';
pss_l = ones(127, 1);
pssInd = sub2ind([240, 4], pss_k, pss_l);

% Reshape received grid to [960 x numRx] for fast vectorized linear indexing
grid2D = reshape(grid, 240 * 4, numRx);

% --- Architecture-Specific Demapping ---
switch arch_str
    case {'Legacy', 'Jio'}
        v_shift = mod(N_ID_cell, 4);
        
        % SSS indices
        sss_k = (57:183)';
        sss_l = 3 * ones(127, 1);
        sssInd = sub2ind([240, 4], sss_k, sss_l);
        
        % DMRS indices (144 REs)
        dmrs_k_sym2 = (4*(0:59) + v_shift + 1)';
        dmrs_k_sym3 = [4*(0:11) + v_shift + 1, 4*(48:59) + v_shift + 1]';
        dmrs_k_sym4 = (4*(0:59) + v_shift + 1)';
        
        dmrsInd = [sub2ind([240, 4], dmrs_k_sym2, 2*ones(60, 1)); ...
                   sub2ind([240, 4], dmrs_k_sym3, 3*ones(24, 1)); ...
                   sub2ind([240, 4], dmrs_k_sym4, 4*ones(60, 1))];
               
        % PBCH Data indices (432 REs)
        pbch_k_sym2 = setdiff((1:240)', dmrs_k_sym2);
        pbch_k_sym3 = [setdiff((1:48)', 4*(0:11)' + v_shift + 1); ...
                       setdiff((193:240)', 4*(48:59)' + v_shift + 1)];
        pbch_k_sym4 = setdiff((1:240)', dmrs_k_sym4);
        
        pbchInd = [sub2ind([240, 4], pbch_k_sym2, 2*ones(180, 1)); ...
                   sub2ind([240, 4], pbch_k_sym3, 3*ones(72, 1)); ...
                   sub2ind([240, 4], pbch_k_sym4, 4*ones(180, 1))];
               
        % Generate or retrieve reference DMRS sequence
        if isempty(opt.KnownDMRS)
            if ~isempty(which('nr_sim.sequences.gen_PBCHDMRS'))
                dmrsSeq = nr_sim.sequences.gen_PBCHDMRS(N_ID_cell, ibar_SSB);
            elseif ~isempty(which('gen_PBCHDMRS'))
                dmrsSeq = gen_PBCHDMRS(N_ID_cell, ibar_SSB);
            elseif ~isempty(which('nrPBCHDMRS'))
                dmrsSeq = nrPBCHDMRS(N_ID_cell, ibar_SSB);
            else
                error('nr_sim:grid:MissingDMRSGenerator', 'PBCH DMRS generator not found.');
            end
        else
            dmrsSeq = opt.KnownDMRS(:);
        end
        
        % Generate or retrieve reference SSS sequence
        if isempty(opt.KnownSSS)
            if ~isempty(which('nr_sim.sequences.gen_SSS'))
                sssSeq = nr_sim.sequences.gen_SSS(N_ID_1, N_ID_2);
            elseif ~isempty(which('gen_SSS'))
                sssSeq = gen_SSS(N_ID_1, N_ID_2);
            elseif ~isempty(which('nrSSS'))
                sssSeq = nrSSS(N_ID_cell);
            else
                error('nr_sim:grid:MissingSSSGenerator', 'SSS generator not found.');
            end
        else
            sssSeq = opt.KnownSSS(:);
        end
        
        if strcmp(arch_str, 'Legacy')
            pilotInd = dmrsInd;
            ref_pilots = dmrsSeq;
            isPhaseCoherent = false;
        else
            % Jio Platforms: 271 joint pilots
            pilotInd = [dmrsInd; sssInd];
            ref_pilots = [dmrsSeq; sssSeq];
            isPhaseCoherent = true;
        end
        
    case 'DesignA'
        v_shift = 0;
        
        % Concentrated Extended SSS on Symbol 3 (all 240 subcarriers)
        sss_k = (1:240)';
        sss_l = 3 * ones(240, 1);
        sssInd = sub2ind([240, 4], sss_k, sss_l);
        
        % DMRS: 0 REs
        dmrsInd = zeros(0, 1);
        
        % PBCH Data: 480 REs (240 on Symbol 2, 240 on Symbol 4)
        pbchInd = [sub2ind([240, 4], (1:240)', 2*ones(240, 1)); ...
                   sub2ind([240, 4], (1:240)', 4*ones(240, 1))];
               
        % Pilot is SSS on Symbol 3
        pilotInd = sssInd;
        
        if isempty(opt.KnownSSS)
            if ~isempty(which('nr_sim.sequences.gen_ExtendedSSS'))
                extSssSeq = nr_sim.sequences.gen_ExtendedSSS(N_ID_cell);
            elseif ~isempty(which('gen_ExtendedSSS'))
                extSssSeq = gen_ExtendedSSS(N_ID_cell);
            else
                extSssSeq = internal_gen_ExtendedSSS(N_ID_cell);
            end
        else
            extSssSeq = opt.KnownSSS(:);
        end
        ref_pilots = extSssSeq;
        isPhaseCoherent = false;
        
    case 'DesignB'
        v_shift = opt.CombShift;
        
        % Comb-3 SSS: 80 REs per symbol on Symbols 2, 3, 4
        k_sss_sym = (3*(0:79) + v_shift + 1)';
        k_pbch_sym = setdiff((1:240)', k_sss_sym);
        
        sssInd = zeros(240, 1);
        pbchInd = zeros(480, 1);
        for sIdx = 1:3
            sym = sIdx + 1;
            sssInd((sIdx-1)*80 + (1:80)) = sub2ind([240, 4], k_sss_sym, sym*ones(80, 1));
            pbchInd((sIdx-1)*160 + (1:160)) = sub2ind([240, 4], k_pbch_sym, sym*ones(160, 1));
        end
        
        dmrsInd = zeros(0, 1);
        pilotInd = sssInd;
        
        if isempty(opt.KnownSSS)
            if ~isempty(which('nr_sim.sequences.gen_ExtendedSSS'))
                extSssSeq = nr_sim.sequences.gen_ExtendedSSS(N_ID_cell);
            elseif ~isempty(which('gen_ExtendedSSS'))
                extSssSeq = gen_ExtendedSSS(N_ID_cell);
            else
                extSssSeq = internal_gen_ExtendedSSS(N_ID_cell);
            end
        else
            extSssSeq = opt.KnownSSS(:);
        end
        ref_pilots = extSssSeq;
        isPhaseCoherent = false;
end

% --- Extract REs across all receive antennas ---
rx_pbch   = grid2D(pbchInd, :);
rx_pilots = grid2D(pilotInd, :);

% Compute null indices
allOccupied = [pssInd; sssInd; dmrsInd; pbchInd];
nullInd = setdiff((1:960)', allOccupied);

% Subcarrier and symbol coordinates of pilots (useful for 2D interpolation)
[pilot_k, pilot_l] = ind2sub([240, 4], pilotInd);

% Build info struct
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
info.pilotSubcarriers= pilot_k;
info.pilotSymbols    = pilot_l;
info.numDataREs      = length(pbchInd);
info.numPilotREs     = length(pilotInd);
info.numNullREs      = length(nullInd);
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

