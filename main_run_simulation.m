function simResults = main_run_simulation(varargin)
%MAIN_RUN_SIMULATION Master simulation runner for 6G SSB Link-Level Simulator.
%
%   SIMRESULTS = MAIN_RUN_SIMULATION('Mode', 'quick_demo')
%   runs Monte Carlo link-level simulation across 4 SSB architectures under
%   3GPP Rel-20 agreed baseline conditions:
%     - 7 GHz Carrier, 30 kHz SCS, 1T4R SIMO MRC
%     - TDL-C 300ns delay spread channel
%     - 3 km/h (Pedestrian) & 120 km/h (Vehicular Doppler Aging)
%     - 56-bit MIB, CRC-24C, SCL Polar Decoding (L=8)
%
%   Modes:
%     'quick_demo' : Fast execution (~50 frames/SNR point)
%     'full_run'   : Comprehensive execution (200 frames/SNR point) with parfor
%     'plot_only'  : Reloads results_simulation.mat and re-generates figures

p = inputParser;
addParameter(p, 'Mode', 'quick_demo', @(x) ismember(x, {'quick_demo', 'full_run', 'plot_only'}));
addParameter(p, 'SNRdB', -10:2:4, @isnumeric);
addParameter(p, 'NumFrames', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
parse(p, varargin{:});

mode = p.Results.Mode;
snrdB = p.Results.SNRdB;

if strcmp(mode, 'plot_only')
    if exist('results_simulation.mat', 'file')
        load('results_simulation.mat', 'simResults');
        nr_sim.plots.plot_simulation_results(simResults);
        fprintf('\n[SUCCESS] Reloaded results and plotted all figures.\n');
        return;
    else
        error('results_simulation.mat not found. Run simulation first.');
    end
end

if isempty(p.Results.NumFrames)
    if strcmp(mode, 'quick_demo')
        numFrames = 40;
    else
        numFrames = 200;
    end
else
    numFrames = p.Results.NumFrames;
end

fprintf('========================================================================\n');
fprintf('  6G (Rel-20) SSB Link-Level Simulator (LLS) Master Runner              \n');
fprintf('  Mode: %s | Frames/SNR: %d | SNRs: [%s] dB\n', mode, numFrames, num2str(snrdB));
fprintf('========================================================================\n\n');

architectures = {'Legacy', 'DesignA', 'DesignB', 'Jio'};
speeds = [3, 120]; % km/h

% Initialize result containers
simResults.snrdB = snrdB;
simResults.architectures = architectures;
simResults.numFrames = numFrames;
simResults.speeds = speeds;

simResults.codeRates.Legacy  = 56 / 864;
simResults.codeRates.DesignA = 56 / 960;
simResults.codeRates.DesignB = 56 / 960;
simResults.codeRates.Jio     = 56 / 864;

for a = 1:length(architectures)
    arch = architectures{a};
    simResults.bler_3kmph.(arch) = zeros(length(snrdB), 1);
    simResults.bler_120kmph.(arch) = zeros(length(snrdB), 1);
    simResults.mse_3kmph.(arch) = zeros(length(snrdB), 1);
    simResults.mse_120kmph.(arch) = zeros(length(snrdB), 1);
end

simResults.mdr_legacy = zeros(length(snrdB), 1);
simResults.mdr_extended = zeros(length(snrdB), 1);

t_start_total = tic;

for sIdx = 1:length(speeds)
    speed = speeds(sIdx);
    fprintf('\n>>> Running Mobility Scenario: %d km/h <<<\n', speed);
    
    cfg = nr_sim.config.get_sim_config('SpeedKmph', speed, 'SNRdB', snrdB, 'NumFrames', numFrames);
    
    for aIdx = 1:length(architectures)
        arch = architectures{aIdx};
        fprintf('  Simulating Architecture: %-8s ... ', arch);
        t_arch = tic;
        
        bler_vec = zeros(length(snrdB), 1);
        mse_vec = zeros(length(snrdB), 1);
        
        for snrIdx = 1:length(snrdB)
            snrVal = snrdB(snrIdx);
            numErrors = 0;
            totalMse = 0;
            
            % Monte-Carlo Loop over Frames
            for f = 1:numFrames
                cellID = randi([0, 1007]);
                
                % 1. Transmitter
                [txWave, ~, txPayload, codedBits, txInfo] = ...
                    nr_sim.tx.tx_pbch_chain(arch, cellID, cfg);
                
                % 2. Channel Fading
                [rxWave, chInfo] = nr_sim.channel.apply_channel(txWave, cfg);
                
                % 3. RF Impairments (Residual CFO + Calibrated AWGN)
                resCFO = (speed > 10) * cfg.ResidualCFO_ppm;
                [rxImpaired, noiseVarRE] = nr_sim.channel.apply_rf_impairments(...
                    rxWave, snrVal, resCFO, cfg);
                
                % 4. Receiver Sync & Demodulation
                [rxWaveSynced, toffset, estN_ID_2, ~] = nr_sim.rx.rx_sync_pss(...
                    rxImpaired, cfg, 'ChannelInfo', chInfo);
                
                % Ideal channel corresponding to synchronized sample timing
                h_ideal = nr_sim.channel.get_ideal_channel(chInfo, cfg, 'TimingOffset', toffset);
                rxGrid = nr_sim.rx.rx_ofdm_demod(rxWaveSynced, cfg);
                
                % 5. SSS Detection
                [estCellID, ~, ~, isMDR] = nr_sim.rx.rx_detect_sss(...
                    rxGrid, estN_ID_2, arch, cfg, 'TrueCellID', cellID);
                
                if speed == 3
                    if ismember(arch, {'Legacy', 'Jio'})
                        simResults.mdr_legacy(snrIdx) = simResults.mdr_legacy(snrIdx) + double(isMDR);
                    else
                        simResults.mdr_extended(snrIdx) = simResults.mdr_extended(snrIdx) + double(isMDR);
                    end
                end
                
                % 6. Channel Estimation
                [H_est, H_pbch, ~] = nr_sim.rx.rx_channel_estimate(...
                    rxGrid, arch, estCellID, cfg);
                
                % Compute Channel Estimation MSE over PBCH symbols (symbols 2..4)
                hErr = abs(H_est(:, 2:4, :) - h_ideal(:, 2:4, :)).^2;
                totalMse = totalMse + mean(hErr(:));
                
                % 7. Equalization & LLR Demapping
                [rx_pbch, ~, ~, ~] = nr_sim.grid.demap_ssb_grid(rxGrid, arch, estCellID);
                [llrs, ~] = nr_sim.rx.rx_equalize_demap(rx_pbch, H_pbch, noiseVarRE);
                
                % 8. Polar SCL Decoding
                [~, isBLER, ~, ~] = nr_sim.rx.rx_pbch_chain(...
                    llrs, length(codedBits), cfg, 'TxPayload', txPayload);
                
                numErrors = numErrors + double(isBLER);
            end
            
            bler_vec(snrIdx) = numErrors / numFrames;
            mse_vec(snrIdx) = totalMse / numFrames;
        end
        
        if speed == 3
            simResults.bler_3kmph.(arch) = bler_vec;
            simResults.mse_3kmph.(arch) = mse_vec;
        else
            simResults.bler_120kmph.(arch) = bler_vec;
            simResults.mse_120kmph.(arch) = mse_vec;
        end
        
        fprintf('Done (%.1f s)\n', toc(t_arch));
    end
end

% Normalize MDR counts
simResults.mdr_legacy = simResults.mdr_legacy / (2 * numFrames);
simResults.mdr_extended = simResults.mdr_extended / (2 * numFrames);

% Save results
save('results_simulation.mat', 'simResults');
fprintf('\n[SAVED] Simulation results archived to results_simulation.mat\n');

% Generate Figures 1 to 4
fprintf('\nGenerating Publication Figures...\n');
nr_sim.plots.plot_simulation_results(simResults);

totalTime = toc(t_start_total);
fprintf('\n========================================================================\n');
fprintf('  SIMULATION COMPLETED SUCCESSFULLY IN %.1f SECONDS                     \n', totalTime);
fprintf('========================================================================\n');

% Print Summary Comparison Table
printSummaryTable(simResults);

end

function printSummaryTable(res)
fprintf('\n%s\n', repmat('-', 1, 86));
fprintf('  SUMMARY PERFORMANCE COMPARISON (PBCH BLER at 3 km/h vs 120 km/h)\n');
fprintf('%s\n', repmat('-', 1, 86));
fprintf('%-10s | %-16s | %-16s | %-16s | %-16s\n', ...
    'SNR (dB)', 'Legacy NR', 'QC Design A', 'Comb-SSS (B)', 'Jio SSS-Assisted');
fprintf('%s\n', repmat('-', 1, 86));

for i = 1:length(res.snrdB)
    snr = res.snrdB(i);
    b_leg_3  = res.bler_3kmph.Legacy(i);
    b_dsgA_3 = res.bler_3kmph.DesignA(i);
    b_dsgB_3 = res.bler_3kmph.DesignB(i);
    b_jio_3  = res.bler_3kmph.Jio(i);
    
    b_leg_120  = res.bler_120kmph.Legacy(i);
    b_dsgA_120 = res.bler_120kmph.DesignA(i);
    b_dsgB_120 = res.bler_120kmph.DesignB(i);
    b_jio_120  = res.bler_120kmph.Jio(i);
    
    fprintf('  %+3d dB   | 3k:%.2f (120:%.2f) | 3k:%.2f (120:%.2f) | 3k:%.2f (120:%.2f) | 3k:%.2f (120:%.2f)\n', ...
        snr, b_leg_3, b_leg_120, b_dsgA_3, b_dsgA_120, b_dsgB_3, b_dsgB_120, b_jio_3, b_jio_120);
end
fprintf('%s\n\n', repmat('-', 1, 86));
end
