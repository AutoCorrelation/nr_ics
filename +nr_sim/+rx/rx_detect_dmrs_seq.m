function isMisdetect = rx_detect_dmrs_seq(rxGrid, patternType, trueCandidateIdx, numCandidates, cfg, varargin)
%RX_DETECT_DMRS_SEQ Blind detection of PBCH DMRS sequence candidate (LGE Fig 8).
%
%   ISMISDETECT = RX_DETECT_DMRS_SEQ(RXGRID, PATTERNTYPE, TRUECANDIDATEIDX, NUMCANDIDATES, CFG)
%   correlates received DMRS REs against NUMCANDIDATES Gold sequence hypotheses.
%
%   patternType:
%     'NR'           : 144 REs Comb-4 DMRS across 3 PBCH symbols (symbols 2, 3, 4)
%     '6GR_1Symbol'  : 240 REs concentrated in 1 symbol (symbol 2 or 3)
%     '6GR_4Symbol_1P': 240 REs distributed across 4 symbols (60 REs/symbol, 1 port)
%     '6GR_4Symbol_2P': 240 REs distributed across 4 symbols (2 ports)

p = inputParser;
addParameter(p, 'CellID', 0, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});
cellID = p.Results.CellID;

persistent cand_NR cand_1S cand_4S cached_cellID
if isempty(cand_NR) || size(cand_NR, 2) < numCandidates || isempty(cached_cellID) || cached_cellID ~= cellID
    % Generate candidate Gold sequences
    N_max = max(1000, numCandidates);
    cand_NR = zeros(144, N_max);
    cand_1S = zeros(240, N_max);
    cand_4S = zeros(240, N_max);
    for c = 1:N_max
        % NR Comb-4 DMRS (144 RE)
        cand_NR(:, c) = nr_sim.sequences.gen_PBCHDMRS(cellID, mod(c-1, 8));
        % 6GR 240 RE Gold sequence (using gen_ExtendedSSS with offset seeds)
        cand_1S(:, c) = nr_sim.sequences.gen_ExtendedSSS(mod(c-1, 1008));
        cand_4S(:, c) = nr_sim.sequences.gen_ExtendedSSS(mod(c + 100, 1008));
    end
    cached_cellID = cellID;
end

numRx = size(rxGrid, 3);
v_shift = mod(cellID, 4);

switch patternType
    case 'NR'
        % Extract 144 REs
        % Sym 2 (60 REs), Sym 3 (24 REs), Sym 4 (60 REs)
        k_full = (v_shift + 1 : 4 : 240)';
        k_sym3 = [ (v_shift + 1 : 4 : 48)'; (192 + v_shift + 1 : 4 : 240)' ];
        rx_dmrs = [ reshape(rxGrid(k_full, 2, :), 60, numRx); ...
                    reshape(rxGrid(k_sym3, 3, :), 24, numRx); ...
                    reshape(rxGrid(k_full, 4, :), 60, numRx) ]; % [144 x NumRx]
        refMat = cand_NR(:, 1:numCandidates); % [144 x numCandidates]
        corrMat = abs(refMat' * rx_dmrs).^2;  % [numCandidates x NumRx]
        metrics = sum(corrMat, 2);
        
    case '6GR_1Symbol'
        % Extract 240 REs from Symbol 3
        rx_dmrs = reshape(rxGrid(:, 3, :), 240, numRx); % [240 x NumRx]
        refMat = cand_1S(:, 1:numCandidates);
        corrMat = abs(refMat' * rx_dmrs).^2;
        metrics = sum(corrMat, 2);
        
    case '6GR_4Symbol_1P'
        % Extract 60 REs from each of symbols 1..4 (total 240 REs, 1 port)
        k_comb = (v_shift + 1 : 4 : 240)';
        rx_dmrs = [ reshape(rxGrid(k_comb, 1, :), 60, numRx); ...
                    reshape(rxGrid(k_comb, 2, :), 60, numRx); ...
                    reshape(rxGrid(k_comb, 3, :), 60, numRx); ...
                    reshape(rxGrid(k_comb, 4, :), 60, numRx) ]; % [240 x NumRx]
        refMat = cand_4S(:, 1:numCandidates);
        corrMat = abs(refMat' * rx_dmrs).^2;
        metrics = sum(corrMat, 2);

    case '6GR_4Symbol_2P'
        % 2 ports: Port 0 on symbols 1 & 2, Port 1 on symbols 3 & 4
        % Non-coherent combining across antenna ports prevents cancellation
        k_comb = (v_shift + 1 : 4 : 240)';
        rx_p0 = [ reshape(rxGrid(k_comb, 1, :), 60, numRx); ...
                  reshape(rxGrid(k_comb, 2, :), 60, numRx) ]; % [120 x NumRx]
        rx_p1 = [ reshape(rxGrid(k_comb, 3, :), 60, numRx); ...
                  reshape(rxGrid(k_comb, 4, :), 60, numRx) ]; % [120 x NumRx]
        ref_p0 = cand_4S(1:120, 1:numCandidates);
        ref_p1 = cand_4S(121:240, 1:numCandidates);
        corr_p0 = abs(ref_p0' * rx_p0).^2;
        corr_p1 = abs(ref_p1' * rx_p1).^2;
        metrics = sum(corr_p0 + corr_p1, 2);
end

[~, detectedIdx] = max(metrics);
isMisdetect = (detectedIdx ~= trueCandidateIdx);

end
