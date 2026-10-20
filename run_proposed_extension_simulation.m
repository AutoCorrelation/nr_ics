function results = run_proposed_extension_simulation(varargin)
%RUN_PROPOSED_EXTENSION_SIMULATION Link-level benchmark runner for Proposed 5-Symbol SSB
%
%   RESULTS = RUN_PROPOSED_EXTENSION_SIMULATION('PropertyName', PropertyValue, ...)
%   evaluates and compares:
%     1. Legacy 5G NR (4-Symbol SSB)
%     2. Proposed 5-Symbol Extension (Equal EPRE: +0.97 dB Tx energy)
%     3. Proposed 5-Symbol Extension (Equal Total Energy: normalized burst energy)
%
%   Evaluated Mobility Scenarios (7 GHz FR3, TDL-C 100ns, 1T4R SIMO):
%     - Pedestrian: 3 km/h (Low fading rate, fd ~ 19.4 Hz)
%     - Vehicular: 120 km/h (High Doppler, fd ~ 777.8 Hz)
%
%   Evaluated Metrics:
%     - PBCH BLER across SNR [-16, 0] dB
%     - SSS Missed Detection Rate (MDR): Legacy single-shot vs Proposed Non-Coherent vs Coherent

    p = inputParser;
    addParameter(p, 'Mode', 'quick', @(x) ismember(x, {'quick', 'full'}));
    addParameter(p, 'NumRx', 1, @(x) ismember(x, [1, 2, 4]));
    addParameter(p, 'SNRdB', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'NumTrials', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
    addParameter(p, 'Scenario', 'All', @(x) ismember(x, {'All', 'pedestrian_3kmph', 'vehicular_120kmph'}));
    addParameter(p, 'Scheme', 'All', @(x) ismember(x, {'All', 'Legacy', 'Proposed'}));
    addParameter(p, 'AutoPlot', true, @(x) islogical(x) || isnumeric(x));
    parse(p, varargin{:});

    mode = p.Results.Mode;
    numRx = p.Results.NumRx;
    scenarioTarget = p.Results.Scenario;
    schemeTarget = p.Results.Scheme;
    autoPlot = logical(p.Results.AutoPlot);
    
    if ~isempty(p.Results.SNRdB)
        snr_vec = p.Results.SNRdB;
    elseif numRx == 1
        snr_vec = -10:2:8; % SISO waterfall SNR range
    else
        snr_vec = -16:2:0; % SIMO 1T4R waterfall SNR range
    end

    if ~isempty(p.Results.NumTrials)
        nTrials = p.Results.NumTrials;
    elseif strcmp(mode, 'quick')
        nTrials = 75; % Rapid verification profile
    else
        nTrials = 300; % Full publication-grade profile
    end

    matFile = 'results_proposed_5symbol_extension.mat';
    if exist(matFile, 'file')
        loaded = load(matFile, 'results');
        results = loaded.results;
    else
        results = struct();
    end

    pool = gcp('nocreate');
    nWorkers = 1;
    if ~isempty(pool), nWorkers = pool.NumWorkers; end

    antStr = sprintf('1T%dR %s', numRx, ternary(numRx == 1, 'SISO', 'SIMO'));
    fprintf('========================================================================\n');
    fprintf('  6G SSB PROPOSED 5-SYMBOL EXTENSION BENCHMARK (3GPP REL-20)            \n');
    fprintf('  Mode: %s | Trials/SNR: %d | Parallel Workers: %d\n', mode, nTrials, nWorkers);
    fprintf('  Carrier: 7 GHz | SCS: 30 kHz | Channel: TDL-C 100ns | Antennas: %s\n', antStr);
    fprintf('  Scenario: %s | Scheme: %s\n', scenarioTarget, schemeTarget);
    fprintf('  SNR Range: [%s] dB\n', num2str(snr_vec));
    fprintf('========================================================================\n\n');

    results.snr = snr_vec;
    results.nTrials = nTrials;
    results.numRx = numRx;
    results.carrierFreq = 7e9;
    results.channelProfile = 'TDL-C';
    results.delaySpread = 100e-9;

    speeds = [3, 120];
    speedNames = {'pedestrian_3kmph', 'vehicular_120kmph'};

    for spIdx = 1:length(speeds)
        speed = speeds(spIdx);
        spKey = speedNames{spIdx};
        if ~strcmp(scenarioTarget, 'All') && ~strcmp(scenarioTarget, spKey)
            continue;
        end
        if ~isfield(results, spKey)
            results.(spKey) = struct();
        end
        fprintf('>>> Evaluating Mobility Scenario: %d km/h (%s) <<<\n', speed, spKey);

        % Common simulator config
        cfg_leg = nr_sim.config.get_sim_config(...
            'CarrierFreq', 7e9, ...
            'SCS', 30e3, ...
            'ChannelProfile', 'TDL-C', ...
            'DelaySpread', 100e-9, ...
            'NumSymbols', 4, ...
            'NumTx', 1, ...
            'NumRx', numRx, ...
            'SpeedKmph', speed, ...
            'InitialCFO_ppm', 0, ...
            'ResidualCFO_ppm', 0);

        cfg_5sym = nr_sim.config.get_sim_config(...
            'CarrierFreq', 7e9, ...
            'SCS', 30e3, ...
            'ChannelProfile', 'TDL-C', ...
            'DelaySpread', 100e-9, ...
            'NumSymbols', 5, ...
            'NumTx', 1, ...
            'NumRx', numRx, ...
            'SpeedKmph', speed, ...
            'InitialCFO_ppm', 0, ...
            'ResidualCFO_ppm', 0);

        nSNR = length(snr_vec);

        % 1. Legacy 4-Symbol NR
        if strcmp(schemeTarget, 'All') || strcmp(schemeTarget, 'Legacy')
            fprintf('  [1/2] Running Legacy 4-Symbol NR (N=%d) ...\n', nTrials);
            bler_leg_acc = zeros(nSNR, 1);
            mdr_leg_acc  = zeros(nSNR, 1);

            parfor f = 1:nTrials
                cid = mod(f * 3 + 1, 1008);
                [txW, ~, txP, cBits, ~] = nr_sim.tx.tx_pbch_chain('Legacy', cid, cfg_leg);
                [rxW, ch] = nr_sim.channel.apply_channel(txW, cfg_leg);

                b_err = zeros(nSNR, 1);
                m_err = zeros(nSNR, 1);
                for s = 1:nSNR
                    snr = snr_vec(s);
                    [rxI, nVar] = nr_sim.channel.apply_rf_impairments(rxW, snr, 0, cfg_leg);
                    [rxS, ~, estN2, ~] = nr_sim.rx.rx_sync_pss(rxI, cfg_leg, 'ChannelInfo', ch);
                    gr = nr_sim.rx.rx_ofdm_demod(rxS, cfg_leg);
                    [estCellID, ~, ~, isM] = nr_sim.rx.rx_detect_sss(gr, estN2, 'Legacy', cfg_leg, 'TrueCellID', cid);
                    [~, Hp, ~] = nr_sim.rx.rx_channel_estimate(gr, 'Legacy', estCellID, cfg_leg);
                    [rp, ~, ~, ~] = nr_sim.grid.demap_ssb_grid(gr, 'Legacy', estCellID);
                    [llrs, ~] = nr_sim.rx.rx_equalize_demap(rp, Hp, nVar);
                    [~, isB, ~, ~] = nr_sim.rx.rx_pbch_chain(llrs, length(cBits), cfg_leg, 'TxPayload', txP);
                    b_err(s) = double(isB);
                    m_err(s) = double(isM);
                end
                bler_leg_acc = bler_leg_acc + b_err;
                mdr_leg_acc  = mdr_leg_acc + m_err;
            end
            bler_leg = bler_leg_acc / nTrials;
            mdr_leg  = mdr_leg_acc / nTrials;
            fprintf('    Legacy BLER: [%s]\n', num2str(bler_leg', ' %5.3f'));
            fprintf('    Legacy MDR : [%s]\n', num2str(mdr_leg', ' %5.3f'));
            results.(spKey).bler_legacy = bler_leg;
            results.(spKey).mdr_legacy = mdr_leg;
        end

        % 2. Proposed 5-Symbol (Joint Equal EPRE & Equal Total Energy)
        if strcmp(schemeTarget, 'All') || strcmp(schemeTarget, 'Proposed')
            fprintf('  [2/2] Running Proposed 5-Symbol (Equal EPRE & Equal Total Energy, N=%d) ...\n', nTrials);
        bler_prop_epre_acc   = zeros(nSNR, 1);
        bler_prop_energy_acc = zeros(nSNR, 1);
        mdr_prop_nc_acc      = zeros(nSNR, 1);
        mdr_prop_coh_acc     = zeros(nSNR, 1);
        power_scale_energy   = sqrt(830 / 1053);

        parfor f = 1:nTrials
            cid = mod(f * 3 + 1, 1008);
            [txW, ~, txP, cBits, ~] = nr_sim.tx.tx_pbch_chain('Proposed5Symbol', cid, cfg_5sym, 'PowerMode', 'EqualEPRE');
            [rxW, ch] = nr_sim.channel.apply_channel(txW, cfg_5sym);
            rxW_energy = power_scale_energy * rxW;

            b_err_epre   = zeros(nSNR, 1);
            b_err_energy = zeros(nSNR, 1);
            m_err_nc     = zeros(nSNR, 1);
            m_err_coh    = zeros(nSNR, 1);

            for s = 1:nSNR
                snr = snr_vec(s);

                % --- A. Equal EPRE (+0.97 dB Tx energy) ---
                [rxI, nVar] = nr_sim.channel.apply_rf_impairments(rxW, snr, 0, cfg_5sym);
                [rxS, ~, estN2, ~] = nr_sim.rx.rx_sync_pss(rxI, cfg_5sym, 'ChannelInfo', ch);
                gr = nr_sim.rx.rx_ofdm_demod(rxS, cfg_5sym);

                % Dual SSS detection
                [estCellID, ~, ~, isM_nc] = nr_sim.rx.rx_detect_sss(gr, estN2, 'Proposed5Symbol', cfg_5sym, ...
                    'TrueCellID', cid, 'SSSCombining', 'NonCoherent');
                [~, ~, ~, isM_coh] = nr_sim.rx.rx_detect_sss(gr, estN2, 'Proposed5Symbol', cfg_5sym, ...
                    'TrueCellID', cid, 'SSSCombining', 'Coherent');

                [~, Hp, ~] = nr_sim.rx.rx_channel_estimate(gr, 'Proposed5Symbol', estCellID, cfg_5sym);
                [rp, ~, ~, ~] = nr_sim.grid.demap_ssb_grid(gr, 'Proposed5Symbol', estCellID);
                [llrs, ~] = nr_sim.rx.rx_equalize_demap(rp, Hp, nVar);
                [~, isB_epre, ~, ~] = nr_sim.rx.rx_pbch_chain(llrs, length(cBits), cfg_5sym, 'TxPayload', txP);

                m_err_nc(s)     = double(isM_nc);
                m_err_coh(s)    = double(isM_coh);
                b_err_epre(s)   = double(isB_epre);

                % --- B. Equal Total Energy (Normalized burst energy) ---
                [rxI_en, nVar_en] = nr_sim.channel.apply_rf_impairments(rxW_energy, snr, 0, cfg_5sym);
                [rxS_en, ~, estN2_en, ~] = nr_sim.rx.rx_sync_pss(rxI_en, cfg_5sym, 'ChannelInfo', ch);
                gr_en = nr_sim.rx.rx_ofdm_demod(rxS_en, cfg_5sym);

                [estCellID_en, ~, ~, ~] = nr_sim.rx.rx_detect_sss(gr_en, estN2_en, 'Proposed5Symbol', cfg_5sym, ...
                    'TrueCellID', cid, 'SSSCombining', 'NonCoherent');
                [~, Hp_en, ~] = nr_sim.rx.rx_channel_estimate(gr_en, 'Proposed5Symbol', estCellID_en, cfg_5sym);
                [rp_en, ~, ~, ~] = nr_sim.grid.demap_ssb_grid(gr_en, 'Proposed5Symbol', estCellID_en);
                [llrs_en, ~] = nr_sim.rx.rx_equalize_demap(rp_en, Hp_en, nVar_en);
                [~, isB_en, ~, ~] = nr_sim.rx.rx_pbch_chain(llrs_en, length(cBits), cfg_5sym, 'TxPayload', txP);

                b_err_energy(s) = double(isB_en);
            end

            bler_prop_epre_acc   = bler_prop_epre_acc + b_err_epre;
            bler_prop_energy_acc = bler_prop_energy_acc + b_err_energy;
            mdr_prop_nc_acc      = mdr_prop_nc_acc + m_err_nc;
            mdr_prop_coh_acc     = mdr_prop_coh_acc + m_err_coh;
        end

        bler_prop_epre   = bler_prop_epre_acc / nTrials;
        bler_prop_energy = bler_prop_energy_acc / nTrials;
        mdr_prop_nc      = mdr_prop_nc_acc / nTrials;
        mdr_prop_coh     = mdr_prop_coh_acc / nTrials;

        fprintf('    Prop EPRE BLER: [%s]\n', num2str(bler_prop_epre', ' %5.3f'));
        fprintf('    Prop SSS NC   : [%s]\n', num2str(mdr_prop_nc', ' %5.3f'));
        fprintf('    Prop SSS Coh  : [%s]\n', num2str(mdr_prop_coh', ' %5.3f'));
        fprintf('    Prop Equal Energy BLER: [%s]\n\n', num2str(bler_prop_energy', ' %5.3f'));

            % Store results for this mobility
            results.(spKey).bler_prop_epre = bler_prop_epre;
            results.(spKey).bler_prop_energy = bler_prop_energy;
            results.(spKey).mdr_prop_nc = mdr_prop_nc;
            results.(spKey).mdr_prop_coh = mdr_prop_coh;
        end
    end

    % Save results to .mat
    save(matFile, 'results');
    fprintf('Master simulation results saved to %s\n\n', matFile);

    % Automatically generate figures
    if autoPlot && ~isempty(which('plot_proposed_extension_results'))
        plot_proposed_extension_results(results);
    end
end

function val = ternary(cond, a, b)
    if cond, val = a; else, val = b; end
end
