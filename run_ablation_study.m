function results = run_ablation_study(varargin)
%%RUN_ABLATION_STUDY Ablation study separating SSS repetition and E-RS contributions.
%%
%%   Evaluates 4 conditions:
%%     1. Legacy 4-Symbol NR (baseline)
%%     2. Proposed5Symbol SSS-Only: Symbol 5 has SSS repetition but E-RS zeroed
%%     3. Proposed5Symbol ERS-Only: Symbol 5 has E-RS but SSS repetition zeroed
%%     4. Proposed5Symbol Full: SSS repetition + E-RS (original proposal)

    p = inputParser;
    addParameter(p, 'NumTrials', 350, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'SNRdB', -16:2:0, @isnumeric);
    parse(p, varargin{:});

    nTrials = p.Results.NumTrials;
    snr_vec = p.Results.SNRdB;
    matFile = 'results_ablation_study.mat';

    pool = gcp('nocreate');
    nWorkers = 1;
    if ~isempty(pool), nWorkers = pool.NumWorkers; end

    fprintf('==========================================================================\n');
    fprintf('  ABLATION STUDY: SSS-Only vs E-RS-Only vs Full Proposed 5-Symbol SSB   \n');
    fprintf('  Trials/SNR: %d | Workers: %d\n', nTrials, nWorkers);
    fprintf('==========================================================================\n\n');

    results = struct();
    results.snr = snr_vec;
    results.nTrials = nTrials;

    speeds = [3, 120];
    speedNames = {'pedestrian_3kmph', 'vehicular_120kmph'};

    for spIdx = 1:length(speeds)
        speed = speeds(spIdx);
        spKey = speedNames{spIdx};
        fprintf('>>> Mobility: %d km/h (%s) <<<\n', speed, spKey);

        cfg_leg = nr_sim.config.get_sim_config('CarrierFreq', 7e9, 'SCS', 30e3, ...
            'ChannelProfile', 'TDL-C', 'DelaySpread', 100e-9, ...
            'NumSymbols', 4, 'NumTx', 1, 'NumRx', 4, ...
            'SpeedKmph', speed, 'InitialCFO_ppm', 0, 'ResidualCFO_ppm', 0);

        cfg_5sym = nr_sim.config.get_sim_config('CarrierFreq', 7e9, 'SCS', 30e3, ...
            'ChannelProfile', 'TDL-C', 'DelaySpread', 100e-9, ...
            'NumSymbols', 5, 'NumTx', 1, 'NumRx', 4, ...
            'SpeedKmph', speed, 'InitialCFO_ppm', 0, 'ResidualCFO_ppm', 0);

        scs_khz = cfg_5sym.SCS / 1e3;

        %% 1. Legacy
        fprintf('  [1/4] Legacy 4-Symbol...\n');
        [bler_leg, mdr_leg, ~] = run_inner(snr_vec, nTrials, cfg_leg, 'Legacy', '', scs_khz);

        %% 2. SSS-Only
        fprintf('  [2/4] Proposed SSS-Only (E-RS zeroed)...\n');
        [bler_sss, mdr_sss_nc, mdr_sss_coh] = run_inner(snr_vec, nTrials, cfg_5sym, 'Proposed5Symbol', 'SSSOnly', scs_khz);

        %% 3. ERS-Only
        fprintf('  [3/4] Proposed ERS-Only (SSS-rep zeroed)...\n');
        [bler_ers, mdr_ers_nc, mdr_ers_coh] = run_inner(snr_vec, nTrials, cfg_5sym, 'Proposed5Symbol', 'ERSOnly', scs_khz);

        %% 4. Full Proposed
        fprintf('  [4/4] Proposed Full (SSS + E-RS)...\n');
        [bler_full, mdr_full_nc, mdr_full_coh] = run_inner(snr_vec, nTrials, cfg_5sym, 'Proposed5Symbol', 'Full', scs_khz);

        results.(spKey).bler_legacy      = bler_leg;
        results.(spKey).mdr_legacy       = mdr_leg;
        results.(spKey).bler_sss_only    = bler_sss;
        results.(spKey).mdr_sss_only_nc  = mdr_sss_nc;
        results.(spKey).mdr_sss_only_coh = mdr_sss_coh;
        results.(spKey).bler_ers_only    = bler_ers;
        results.(spKey).mdr_ers_only_nc  = mdr_ers_nc;
        results.(spKey).mdr_ers_only_coh = mdr_ers_coh;
        results.(spKey).bler_full        = bler_full;
        results.(spKey).mdr_full_nc      = mdr_full_nc;
        results.(spKey).mdr_full_coh     = mdr_full_coh;

        fprintf('  BLER:     Leg=[%s]\n', num2str(bler_leg', '%.3f '));
        fprintf('  BLER:     SSS=[%s]\n', num2str(bler_sss', '%.3f '));
        fprintf('  BLER:     ERS=[%s]\n', num2str(bler_ers', '%.3f '));
        fprintf('  BLER:     Full=[%s]\n', num2str(bler_full', '%.3f '));
        fprintf('  MDR(NC):  Leg=[%s]\n', num2str(mdr_leg', '%.3f '));
        fprintf('  MDR(NC):  SSS=[%s]\n', num2str(mdr_sss_nc', '%.3f '));
        fprintf('  MDR(NC):  ERS=[%s]\n', num2str(mdr_ers_nc', '%.3f '));
        fprintf('  MDR(NC):  Full=[%s]\n\n', num2str(mdr_full_nc', '%.3f '));
    end

    save(matFile, 'results');
    fprintf('Ablation results saved to %s\n', matFile);
end

function [bler, mdr_nc, mdr_coh] = run_inner(snr_vec, nTrials, cfg, arch, ablation, scs_khz)
    nSNR = length(snr_vec);
    bler = zeros(nSNR, 1);
    mdr_nc = zeros(nSNR, 1);
    mdr_coh = zeros(nSNR, 1);
    is5sym = strcmp(arch, 'Proposed5Symbol');

    for s = 1:nSNR
        snr = snr_vec(s);
        errB = 0; errM_nc = 0; errM_coh = 0;
        parfor f = 1:nTrials
            cid = mod(f * 3 + 1, 1008);

            %% TX
            [txW, grid_ssb, txP, cBits, ~] = nr_sim.tx.tx_pbch_chain(arch, cid, cfg, 'PowerMode', 'EqualEPRE');

            %% Ablation: modify grid and re-OFDM-modulate
            if is5sym && ~strcmp(ablation, 'Full') && ~isempty(ablation)
                modGrid = grid_ssb;
                switch ablation
                    case 'SSSOnly'
                        modGrid([1:48, 193:240], 5) = 0;
                    case 'ERSOnly'
                        modGrid(57:183, 5) = 0;
                end
                grid_slot = complex(zeros(cfg.NumSubcarriers, 14));
                grid_slot(:, 1:5) = modGrid;
                txW = nrOFDMModulate(grid_slot, scs_khz, 0, 'Nfft', cfg.FFTSize, ...
                    'SampleRate', cfg.SampleRate, 'Windowing', 0);
            end

            %% Channel + Noise
            [rxW, ch] = nr_sim.channel.apply_channel(txW, cfg);
            [rxI, nVar] = nr_sim.channel.apply_rf_impairments(rxW, snr, 0, cfg);
            [rxS, ~, estN2, ~] = nr_sim.rx.rx_sync_pss(rxI, cfg, 'ChannelInfo', ch);
            gr = nr_sim.rx.rx_ofdm_demod(rxS, cfg);

            %% RX
            if is5sym
                [estCellID, ~, ~, isM_nc] = nr_sim.rx.rx_detect_sss(gr, estN2, arch, cfg, ...
                    'TrueCellID', cid, 'SSSCombining', 'NonCoherent');
                [~, ~, ~, isM_coh] = nr_sim.rx.rx_detect_sss(gr, estN2, arch, cfg, ...
                    'TrueCellID', cid, 'SSSCombining', 'Coherent');
                errM_coh = errM_coh + double(isM_coh);
            else
                [estCellID, ~, ~, isM_nc] = nr_sim.rx.rx_detect_sss(gr, estN2, arch, cfg, 'TrueCellID', cid);
            end

            [~, Hp, ~] = nr_sim.rx.rx_channel_estimate(gr, arch, estCellID, cfg);
            [rp, ~, ~, ~] = nr_sim.grid.demap_ssb_grid(gr, arch, estCellID);
            [llrs, ~] = nr_sim.rx.rx_equalize_demap(rp, Hp, nVar);
            [~, isB, ~, ~] = nr_sim.rx.rx_pbch_chain(llrs, length(cBits), cfg, 'TxPayload', txP);
            errB = errB + double(isB);
            errM_nc = errM_nc + double(isM_nc);
        end
        bler(s) = errB / nTrials;
        mdr_nc(s) = errM_nc / nTrials;
        mdr_coh(s) = errM_coh / nTrials;
    end
end
