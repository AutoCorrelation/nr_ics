function [H_est, H_pbch, demapInfo] = rx_channel_estimate(rxGrid, arch, N_ID_cell, cfg, varargin)
%RX_CHANNEL_ESTIMATE 2D channel estimation across 4 6G SSB architectures.
%
%   [H_EST, H_PBCH, DEMAPINFO] = RX_CHANNEL_ESTIMATE(RXGRID, ARCH, N_ID_CELL, CFG)
%   computes the 2D channel transfer function [240 x 4 x NumRx] across the
%   SSB burst for:
%     - 'Legacy'  : Comb-4 DMRS frequency & time interpolation
%     - 'DesignA' : Concentrated SSS-as-DMRS on Symbol 3 with time-hold
%     - 'DesignB' : Comb-3 SSS across Symbols 2, 3, 4 with 2D time-frequency interpolation
%     - 'Jio'     : Joint SSS + DMRS assisted channel estimation
%
%   Outputs:
%     H_EST     - [240 x 4 x NumRx] estimated channel across full SSB grid
%     H_PBCH    - [numDataREs x NumRx] estimated channel at PBCH RE positions
%     DEMAPINFO - Metadata struct from demap_ssb_grid

p = inputParser;
addParameter(p, 'ibar_SSB', cfg.SSBCandidate, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});
ibar_SSB = p.Results.ibar_SSB;

numRx = size(rxGrid, 3);
numSymbols = size(rxGrid, 2);
H_est = complex(zeros(cfg.NumSubcarriers, numSymbols, numRx));

% Extract pilots and reference sequences
[~, rx_pilots, ref_pilots, demapInfo] = nr_sim.grid.demap_ssb_grid(rxGrid, arch, N_ID_cell, 'ibar_SSB', ibar_SSB);

% Least-Squares (LS) estimate at pilot locations: [numPilots x NumRx]
H_LS = rx_pilots ./ ref_pilots;

k_all = (1:cfg.NumSubcarriers)';

arch_str = validatestring(arch, {'Legacy', 'DesignA', 'DesignB', 'Jio', 'Proposed5Symbol'});
switch arch_str
    case 'Legacy'
        % DMRS pilots: 60 pilots on sym 2, 24 on sym 3, 60 on sym 4
        v_shift = demapInfo.v_shift;
        k_dmrs_full = (v_shift + 1 : 4 : 240)';
        k_dmrs_sym3 = [ (v_shift + 1 : 4 : 48)'; (192 + v_shift + 1 : 4 : 240)' ];
        
        for r = 1:numRx
            h_ls_sym2 = H_LS(1:60, r);
            h_ls_sym3 = H_LS(61:84, r);
            h_ls_sym4 = H_LS(85:144, r);
            
            % 1D frequency interpolation for symbol 2 and symbol 4
            H_est(:, 2, r) = interp1(k_dmrs_full, h_ls_sym2, k_all, 'linear', 'extrap');
            H_est(:, 4, r) = interp1(k_dmrs_full, h_ls_sym4, k_all, 'linear', 'extrap');
            
            % For symbol 3: outer bands interpolated from h_ls_sym3, center band from average of sym 2 and sym 4
            h_sym3_interp = interp1(k_dmrs_sym3, h_ls_sym3, k_all, 'linear', 'extrap');
            h_center_avg = 0.5 * (H_est(49:192, 2, r) + H_est(49:192, 4, r));
            H_est(:, 3, r) = h_sym3_interp;
            H_est(49:192, 3, r) = h_center_avg;
            
            % Symbol 1 (PSS symbol) extrapolation
            H_est(:, 1, r) = H_est(:, 2, r);
        end
        
    case 'DesignA'
        % Qualcomm Design A: 240 SSS pilots occupy ALL subcarriers of Symbol 3 (sym index 3)
        % Apply frequency-domain noise reduction filter across contiguous pilots
        for r = 1:numRx
            h_smooth = movmean(H_LS(:, r), 7);
            H_est(:, 3, r) = h_smooth;
            % Time domain zero-order hold / extrapolation to symbols 1, 2, and 4
            H_est(:, 2, r) = h_smooth;
            H_est(:, 4, r) = h_smooth;
            H_est(:, 1, r) = h_smooth;
        end
        
    case 'DesignB'
        % Comb-3 SSS: 80 pilots on each of symbols 2, 3, 4
        v_shift = mod(N_ID_cell, 3);
        k_sss_comb = (v_shift + 1 : 3 : 240)';
        
        for r = 1:numRx
            for sIdx = 1:3
                sym = sIdx + 1;
                h_ls_sym = H_LS((sIdx - 1)*80 + (1:80), r);
                H_est(:, sym, r) = interp1(k_sss_comb, h_ls_sym, k_all, 'linear', 'extrap');
            end
            % Symbol 1 extrapolation
            H_est(:, 1, r) = H_est(:, 2, r);
        end
        
    case 'Jio'
        % Jio Platforms SSS-Assisted: 144 DMRS + 127 SSS pilots
        v_shift = demapInfo.v_shift;
        k_dmrs_full = (v_shift + 1 : 4 : 240)';
        k_sss_sym3  = (57:183)';
        
        for r = 1:numRx
            h_dmrs_sym2 = H_LS(1:60, r);
            h_dmrs_sym3 = H_LS(61:84, r);
            h_dmrs_sym4 = H_LS(85:144, r);
            h_sss_sym3  = H_LS(145:271, r);
            
            H_est(:, 2, r) = interp1(k_dmrs_full, h_dmrs_sym2, k_all, 'linear', 'extrap');
            H_est(:, 4, r) = interp1(k_dmrs_full, h_dmrs_sym4, k_all, 'linear', 'extrap');
            
            % Symbol 3: Combine DMRS (outer) and SSS (center)
            k_combined = [ (v_shift + 1 : 4 : 48)'; k_sss_sym3; (192 + v_shift + 1 : 4 : 240)' ];
            h_combined = [ h_dmrs_sym3(1:12); h_sss_sym3; h_dmrs_sym3(13:24) ];
            [k_uniq, uIdx] = unique(k_combined);
            h_uniq = h_combined(uIdx);
            
            H_est(:, 3, r) = interp1(k_uniq, h_uniq, k_all, 'linear', 'extrap');
            H_est(:, 1, r) = H_est(:, 2, r);
        end

    case 'Proposed5Symbol'
        % Proposed 5-Symbol: 494 Pilots total
        % DMRS: 1:60 (sym2), 61:84 (sym3), 85:144 (sym4)
        % SSS: 145:271 (sym3)
        % SSS-rep: 272:398 (sym5)
        % E-RS: 399:494 (sym5, 48 outer-lower + 48 outer-upper)
        v_shift = demapInfo.v_shift;
        k_dmrs_full = (v_shift + 1 : 4 : 240)';
        k_sss_sym3  = (57:183)';
        k_ers_sym5  = [ (1:48)'; (193:240)' ];

        for r = 1:numRx
            h_dmrs_sym2 = H_LS(1:60, r);
            h_dmrs_sym3 = H_LS(61:84, r);
            h_dmrs_sym4 = H_LS(85:144, r);
            h_sss_sym3  = H_LS(145:271, r);
            h_sss_sym5  = H_LS(272:398, r);
            h_ers_sym5  = H_LS(399:494, r);

            % 1. Symbol 2: DMRS frequency interpolation
            H_est(:, 2, r) = interp1(k_dmrs_full, h_dmrs_sym2, k_all, 'linear', 'extrap');

            % 2. Symbol 3: Combined DMRS (outer) + SSS (center)
            k_comb3 = [ (v_shift + 1 : 4 : 48)'; k_sss_sym3; (192 + v_shift + 1 : 4 : 240)' ];
            h_comb3 = [ h_dmrs_sym3(1:12); h_sss_sym3; h_dmrs_sym3(13:24) ];
            [k_u3, u3] = unique(k_comb3);
            H_est(:, 3, r) = interp1(k_u3, h_comb3(u3), k_all, 'linear', 'extrap');

            % 3. Symbol 5: Combined E-RS (outer 96) + SSS-rep (center 127)
            k_comb5 = [ (1:48)'; (57:183)'; (193:240)' ];
            h_comb5 = [ h_ers_sym5(1:48); h_sss_sym5; h_ers_sym5(49:96) ];
            H_est(:, 5, r) = interp1(k_comb5, h_comb5, k_all, 'linear', 'extrap');

            % 4. Symbol 4: Direct DMRS estimate + Temporal Bracket between Sym 3 and Sym 5
            h_dmrs_freq4 = interp1(k_dmrs_full, h_dmrs_sym4, k_all, 'linear', 'extrap');
            h_bracket_time4 = 0.5 * (H_est(:, 3, r) + H_est(:, 5, r));

            % Weighted MMSE-style noise suppression combining frequency and time estimates
            H_est(:, 4, r) = 0.5 * h_dmrs_freq4 + 0.5 * h_bracket_time4;

            % Symbol 1 (PSS) extrapolation
            H_est(:, 1, r) = H_est(:, 2, r);
        end
end

% Extract channel frequency response at PBCH data RE positions
numDataREs = length(demapInfo.pbchInd);
H_pbch = complex(zeros(numDataREs, numRx));
for r = 1:numRx
    H_r = H_est(:, :, r);
    H_pbch(:, r) = H_r(demapInfo.pbchInd);
end

end
