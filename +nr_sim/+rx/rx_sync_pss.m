function [rxWaveSynced, timingOffset, estN_ID_2, coarseCFO] = rx_sync_pss(rxWave, cfg, varargin)
%RX_SYNC_PSS PSS timing synchronization and coarse CFO estimation for 1T4R SIMO.
%
%   [RXWAVESYNCED, TIMINGOFFSET, ESTN_ID_2, COARSECFO] = RX_SYNC_PSS(RXWAVE, CFG)
%   detects PSS sector ID (N_ID_2 in {0, 1, 2}), symbol timing offset, and
%   compensates coarse CFO across receive antennas.
%
%   Optional Name-Value Pairs:
%     'ChannelInfo' - Channel info struct from apply_channel for perfect timing
%     'N_ID_2'      - Known sector ID (0..2) to bypass PSS search if desired

p = inputParser;
addParameter(p, 'ChannelInfo', [], @(x) isempty(x) || isstruct(x));
addParameter(p, 'N_ID_2', [], @(x) isempty(x) || ismember(x, [0, 1, 2]));
parse(p, varargin{:});

chInfo = p.Results.ChannelInfo;
knownN2 = p.Results.N_ID_2;
numRx = size(rxWave, 2);
nSamples = size(rxWave, 1);

persistent pss_templates
if isempty(pss_templates)
    scs_khz = cfg.SCS / 1e3;
    pss_templates = complex(zeros(556, 3));
    for n2 = 0:2
        grid_pss = complex(zeros(cfg.NumSubcarriers, 14));
        grid_pss(57:183, 1) = nr_sim.sequences.gen_PSSNR(n2);
        w = nrOFDMModulate(grid_pss, scs_khz, 0, 'Nfft', cfg.FFTSize, ...
            'SampleRate', cfg.SampleRate, 'Windowing', 0);
        pss_templates(:, n2 + 1) = w(1:556);
    end
end

% 1. Timing Estimation
if ~isempty(chInfo) && isfield(chInfo, 'pathGains') && isfield(chInfo, 'pathFilters')
    timingOffset = nrPerfectTimingEstimate(chInfo.pathGains, chInfo.pathFilters);
else
    % Practical PSS cross-correlation timing search
    maxSearch = min(128, nSamples - 556);
    corr_matrix = zeros(maxSearch + 1, 3);
    for n2 = 0:2
        ref = pss_templates(:, n2 + 1);
        for tau = 0:maxSearch
            segment = rxWave(tau + (1:556), :);
            corr_matrix(tau + 1, n2 + 1) = sum(abs(sum(segment .* conj(ref), 1)).^2);
        end
    end
    [~, maxIdx] = max(corr_matrix(:));
    [bestTauIdx, bestN2] = ind2sub(size(corr_matrix), maxIdx);
    timingOffset = bestTauIdx - 1;
    estN_ID_2 = bestN2 - 1;
end

% 2. Sector ID Estimation (if not determined above)
if isempty(knownN2)
    if ~exist('estN_ID_2', 'var')
        % Correlate at the estimated timing offset (fully vectorized across 3 sectors)
        pssSeg = rxWave(timingOffset + (1:556), :);
        corr_sec = sum(abs(pss_templates' * pssSeg).^2, 2);
        [~, bestN2] = max(corr_sec);
        estN_ID_2 = bestN2 - 1;
    end
else
    estN_ID_2 = knownN2;
end

% 3. Coarse CFO Estimation & Compensation
if (isfield(cfg, 'InitialCFO_ppm') && cfg.InitialCFO_ppm == 0) && ...
   (isfield(cfg, 'ResidualCFO_ppm') && cfg.ResidualCFO_ppm == 0)
    coarseCFO = 0;
else
    cpLen = 44;
    symLen = 512;
    optSample = timingOffset + 1;
    if optSample + cpLen + symLen <= nSamples
        cp_part = rxWave(optSample : optSample + cpLen - 1, :);
        tail_part = rxWave(optSample + symLen : optSample + symLen + cpLen - 1, :);
        cfoPhase = angle(sum(conj(cp_part) .* tail_part, 'all'));
        coarseCFO = cfoPhase / (2 * pi * (symLen / cfg.SampleRate));
    else
        coarseCFO = 0;
    end
end

t = (0:nSamples - 1)' / cfg.SampleRate;
cfoCorrection = exp(-1i * 2 * pi * coarseCFO * t);
rxWaveCorrected = rxWave .* cfoCorrection;

% 4. Timing Alignment with Zero-Padding
if timingOffset > 0 && timingOffset < nSamples
    rxWaveSynced = [rxWaveCorrected(timingOffset + 1 : end, :); zeros(timingOffset, numRx)];
else
    rxWaveSynced = rxWaveCorrected;
end

end
