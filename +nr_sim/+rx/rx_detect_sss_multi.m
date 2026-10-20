function [estCellID, estN_ID_1, maxMetric, isMDR] = rx_detect_sss_multi(rxGrids, estN_ID_2, arch, cfg, varargin)
%RX_DETECT_SSS_MULTI Multi-repetition SSS detection with non-coherent combining.
%
%   [ESTCELLID, ESTN_ID_1, MAXMETRIC, ISMDR] = RX_DETECT_SSS_MULTI(RXGRIDS, ESTN_ID_2, ARCH, CFG)
%   performs non-coherent energy combining across M SSB repetitions and
%   receive antennas for joint PSS/SSS cell search evaluation (e.g. MediaTek Fig 10a).
%
%   Inputs:
%     RXGRIDS - Cell array of length M containing [240 x 4 x NumRx] received grids,
%               or a single [240 x 4 x NumRx] grid (M=1).
%     ESTN_ID_2 - Detected PSS sector ID (0, 1, or 2)
%     ARCH      - 'Legacy', 'DesignA', 'DesignB', or 'Jio'
%     CFG       - Simulator configuration struct
%
%   Optional Name-Value Pairs:
%     'TrueCellID' - Ground-truth Cell ID to evaluate Missed Detection (MDR)

persistent C_legacy C_ext
if isempty(C_legacy)
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
parse(p, varargin{:});
trueCellID = p.Results.TrueCellID;

if ~iscell(rxGrids)
    rxGrids = {rxGrids};
end
M = length(rxGrids);

arch_str = validatestring(arch, {'Legacy', 'DesignA', 'DesignB', 'Jio'});
secIdx = mod(estN_ID_2, 3) + 1;
metrics = zeros(336, 1);

for m = 1:M
    rxGrid_m = rxGrids{m};
    
    switch arch_str
        case {'Legacy', 'Jio'}
            rxSss = reshape(rxGrid_m(57:183, 3, :), 127, []); % [127 x NumRx]
            refMat = C_legacy{secIdx};                         % [127 x 336]
            corrMat = abs(refMat.' * rxSss).^2;                % [336 x NumRx]
            metrics = metrics + sum(corrMat, 2);
            
        case 'DesignA'
            rxSss = reshape(rxGrid_m(:, 3, :), 240, []);       % [240 x NumRx]
            refMat = C_ext{secIdx};                            % [240 x 336]
            corrMat = abs(refMat.' * rxSss).^2;                % [336 x NumRx]
            metrics = metrics + sum(corrMat, 2);
            
        case 'DesignB'
            v_shift = mod(estN_ID_2, 3);
            k_sss = (v_shift + 1 : 3 : 240)';
            refMat = C_ext{secIdx};                            % [240 x 336]
            for sIdx = 1:3
                sym = sIdx + 1;
                refSub = refMat((sIdx - 1)*80 + (1:80), :);   % [80 x 336]
                rxSub = reshape(rxGrid_m(k_sss, sym, :), 80, []); % [80 x NumRx]
                metrics = metrics + sum(abs(refSub.' * rxSub).^2, 2);
            end
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
