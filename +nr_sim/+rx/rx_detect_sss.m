function [estCellID, estN_ID_1, maxMetric, isMDR] = rx_detect_sss(rxGrid, estN_ID_2, arch, cfg, varargin)
%RX_DETECT_SSS Fast vectorized SSS detection to identify Physical Cell ID and compute MDR.
%
%   [ESTCELLID, ESTN_ID_1, MAXMETRIC, ISMDR] = RX_DETECT_SSS(RXGRID, ESTN_ID_2, ARCH, CFG)
%   correlates received SSS REs against candidate sequences given the
%   estimated PSS sector ID ESTN_ID_2 using vectorized matrix operations.
%
%   Optional Name-Value Pairs:
%     'TrueCellID' - Ground-truth Cell ID to evaluate Missed Detection (MDR)

persistent C_legacy C_ext
if isempty(C_legacy)
    % Precompute candidate tables for fast vector correlation
    C_legacy = cell(3, 1);
    for n2 = 0:2
        mat_leg = zeros(127, 336);
        for n1 = 0:335
            mat_leg(:, n1 + 1) = nr_sim.sequences.gen_SSS(n1, n2);
        end
        C_legacy{n2 + 1} = mat_leg;
    end
    
    C_ext = cell(3, 1);
    for n2 = 0:2
        mat_ext = zeros(240, 336);
        for n1 = 0:335
            cid = 3 * n1 + n2;
            mat_ext(:, n1 + 1) = nr_sim.sequences.gen_ExtendedSSS(cid);
        end
        C_ext{n2 + 1} = mat_ext;
    end
end

p = inputParser;
addParameter(p, 'TrueCellID', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'SSSCombining', 'NonCoherent', @(x) ischar(x) && ismember(x, {'NonCoherent', 'Coherent'}));
parse(p, varargin{:});
trueCellID = p.Results.TrueCellID;
sssCombining = p.Results.SSSCombining;

arch_str = validatestring(arch, {'Legacy', 'DesignA', 'DesignB', 'Jio', 'Proposed5Symbol'});
secIdx = mod(estN_ID_2, 3) + 1;

switch arch_str
    case {'Legacy', 'Jio'}
        % Symbol index 3 (0-indexed symbol 2), subcarriers 57..183 (127 REs)
        rxSss = reshape(rxGrid(57:183, 3, :), 127, []); % [127 x NumRx]
        refMat = C_legacy{secIdx}; % [127 x 336]
        % Non-coherent combining across Rx antennas
        corrMat = abs(refMat.' * rxSss).^2; % [336 x NumRx]
        metrics = sum(corrMat, 2);

    case 'Proposed5Symbol'
        % Symbols 3 and 5 (0-indexed symbols 2 and 4), subcarriers 57..183 (127 REs)
        rxSss3 = reshape(rxGrid(57:183, 3, :), 127, []); % [127 x NumRx]
        rxSss5 = reshape(rxGrid(57:183, 5, :), 127, []); % [127 x NumRx]
        refMat = C_legacy{secIdx}; % [127 x 336]

        if strcmp(sssCombining, 'NonCoherent')
            % Non-coherent energy combining across symbols and antennas
            corrMat3 = abs(refMat.' * rxSss3).^2; % [336 x NumRx]
            corrMat5 = abs(refMat.' * rxSss5).^2; % [336 x NumRx]
            metrics = sum(corrMat3 + corrMat5, 2);
        else
            % Coherent complex combining across symbols 3 and 5
            corrMat = abs(refMat.' * (rxSss3 + rxSss5)).^2;
            metrics = sum(corrMat, 2);
        end
        
    case 'DesignA'
        % Symbol index 3 (0-indexed symbol 2), all 240 subcarriers
        rxSss = reshape(rxGrid(:, 3, :), 240, []); % [240 x NumRx]
        refMat = C_ext{secIdx}; % [240 x 336]
        corrMat = abs(refMat.' * rxSss).^2; % [336 x NumRx]
        metrics = sum(corrMat, 2);
        
    case 'DesignB'
        % Comb-3 SSS across Symbols 2, 3, 4
        v_shift = mod(estN_ID_2, 3);
        k_sss = (v_shift + 1 : 3 : 240)';
        refMat = C_ext{secIdx}; % [240 x 336]
        metrics = zeros(336, 1);
        for sIdx = 1:3
            sym = sIdx + 1;
            refSub = refMat((sIdx - 1)*80 + (1:80), :); % [80 x 336]
            rxSub = reshape(rxGrid(k_sss, sym, :), 80, []); % [80 x NumRx]
            metrics = metrics + sum(abs(refSub.' * rxSub).^2, 2);
        end
end

[maxMetric, bestIdx] = max(metrics);
estN_ID_1 = bestIdx - 1;
estCellID = 3 * estN_ID_1 + estN_ID_2;

if ~isempty(trueCellID)
    isMDR = (estCellID ~= trueCellID);
else
    isMDR = false;
end

end
