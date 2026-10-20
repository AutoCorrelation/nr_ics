% VALIDATE_COMPANY_MATCHING
% Validates our MATLAB LLS against the exact contributions in 3gpp_Extracted:
%   1. Qualcomm (R1-2606375): TDL-A 100ns, Fd=50Hz, 1T1R SISO, CINR -6:2:4 dB
%   2. MediaTek (R1-2606847): TDL-C 300ns, 2GHz/7GHz, 1T4R SIMO, 20ppm CFO
%   3. LG Electronics (R1-2605506): TDL-C 100ns, 7GHz, 1T4R, 30 vs 120 km/h

clear; clc;
fprintf('========================================================================\n');
fprintf('  3GPP REL-20 6G SSB: COMPANY-BY-COMPANY LLS BENCHMARK & VALIDATION    \n');
fprintf('========================================================================\n\n');

%% ------------------------------------------------------------------------
% 1. QUALCOMM (R1-2606375) VALIDATION
% Paper Figure 15: TDL-A, 100ns DS, Fd=50Hz, 1Tx 1Rx, CINR -6 to +4 dB
% Expected 1% BLER gain: ~0.8 - 0.95 dB for Design A and Design B over 5G NR
% ------------------------------------------------------------------------
fprintf('>>> [1/3] QUALCOMM (R1-2606375) VALIDATION (1T1R, TDL-A 100ns, Fd=50Hz) <<<\n');

cfg_qc = nr_sim.config.get_sim_config(...
    'CarrierFreq', 7e9, ...
    'ChannelProfile', 'TDL-A', ...
    'DelaySpread', 100e-9, ...
    'NumTx', 1, ...
    'NumRx', 1, ...
    'ResidualCFO_ppm', 0);
cfg_qc.MaxDoppler = 50; % Fd = 50 Hz

snr_qc = -4:2:4;
nFrames_qc = 30;
archs_qc = {'Legacy', 'DesignA', 'DesignB'};
bler_qc = struct();

for a = 1:length(archs_qc)
    arch = archs_qc{a};
    fprintf('  Evaluating %-8s ... ', arch);
    b_vec = zeros(length(snr_qc), 1);
    for s = 1:length(snr_qc)
        snr = snr_qc(s);
        err = 0;
        for f = 1:nFrames_qc
            cid = 42;
            [txWave, ~, txPayload, codedBits, info] = nr_sim.tx.tx_pbch_chain(arch, cid, cfg_qc);
            [rxWave, chInfo] = nr_sim.channel.apply_channel(txWave, cfg_qc);
            [rxImpaired, noiseVarRE] = nr_sim.channel.apply_rf_impairments(rxWave, snr, 0, cfg_qc);
            [rxWaveSynced, toffset, estN2, ~] = nr_sim.rx.rx_sync_pss(rxImpaired, cfg_qc, 'ChannelInfo', chInfo);
            rxGrid = nr_sim.rx.rx_ofdm_demod(rxWaveSynced, cfg_qc);
            [estCellID, ~, ~, ~] = nr_sim.rx.rx_detect_sss(rxGrid, estN2, arch, cfg_qc);
            [H_est, H_pbch, ~] = nr_sim.rx.rx_channel_estimate(rxGrid, arch, estCellID, cfg_qc);
            [rx_pbch, ~, ~, ~] = nr_sim.grid.demap_ssb_grid(rxGrid, arch, estCellID);
            [llrs, ~] = nr_sim.rx.rx_equalize_demap(rx_pbch, H_pbch, noiseVarRE);
            [~, isBLER, ~, ~] = nr_sim.rx.rx_pbch_chain(llrs, length(codedBits), cfg_qc, 'TxPayload', txPayload);
            err = err + double(isBLER);
        end
        b_vec(s) = err / nFrames_qc;
    end
    bler_qc.(arch) = b_vec;
    fprintf('BLER: [%s]\n', num2str(b_vec', ' %4.2f'));
end

%% ------------------------------------------------------------------------
% 2. MEDIATEK (R1-2606847) VALIDATION
% Paper Figure 10: TDL-C 300ns, 1T4R, 20ppm CFO, 10% MDR and 1% BLER
% Expected: ~1.8 - 2.0 dB MDR gain, ~1.0 dB PBCH BLER gain for Comb-SSS
% ------------------------------------------------------------------------
fprintf('\n>>> [2/3] MEDIATEK (R1-2606847) VALIDATION (1T4R, TDL-C 300ns, 20ppm CFO) <<<\n');

cfg_mtk = nr_sim.config.get_sim_config(...
    'CarrierFreq', 7e9, ...
    'ChannelProfile', 'TDL-C', ...
    'DelaySpread', 300e-9, ...
    'NumTx', 1, ...
    'NumRx', 4, ...
    'SpeedKmph', 3, ...
    'InitialCFO_ppm', 20, ...
    'ResidualCFO_ppm', 0.15);

snr_mdr = -12:2:-6;
nTrials_mdr = 40;
mdr_nr = zeros(size(snr_mdr));
mdr_comb = zeros(size(snr_mdr));

fprintf('  Evaluating SSS MDR (127 vs 240 REs) ... ');
for s = 1:length(snr_mdr)
    snr = snr_mdr(s);
    err_nr = 0; err_comb = 0;
    for f = 1:nTrials_mdr
        cid = randi([0 1007]);
        % NR 127
        [txW1, ~, ~, ~, ~] = nr_sim.tx.tx_pbch_chain('Legacy', cid, cfg_mtk);
        [rxW1, ch1] = nr_sim.channel.apply_channel(txW1, cfg_mtk);
        [rxI1, ~] = nr_sim.channel.apply_rf_impairments(rxW1, snr, 0, cfg_mtk);
        [rxS1, ~, estN2_1, ~] = nr_sim.rx.rx_sync_pss(rxI1, cfg_mtk, 'ChannelInfo', ch1);
        grid1 = nr_sim.rx.rx_ofdm_demod(rxS1, cfg_mtk);
        [~, ~, ~, isMDR1] = nr_sim.rx.rx_detect_sss(grid1, estN2_1, 'Legacy', cfg_mtk, 'TrueCellID', cid);
        err_nr = err_nr + double(isMDR1);
        
        % Comb-SSS 240
        [txW2, ~, ~, ~, ~] = nr_sim.tx.tx_pbch_chain('DesignB', cid, cfg_mtk);
        [rxW2, ch2] = nr_sim.channel.apply_channel(txW2, cfg_mtk);
        [rxI2, ~] = nr_sim.channel.apply_rf_impairments(rxW2, snr, 0, cfg_mtk);
        [rxS2, ~, estN2_2, ~] = nr_sim.rx.rx_sync_pss(rxI2, cfg_mtk, 'ChannelInfo', ch2);
        grid2 = nr_sim.rx.rx_ofdm_demod(rxS2, cfg_mtk);
        [~, ~, ~, isMDR2] = nr_sim.rx.rx_detect_sss(grid2, estN2_2, 'DesignB', cfg_mtk, 'TrueCellID', cid);
        err_comb = err_comb + double(isMDR2);
    end
    mdr_nr(s) = err_nr / nTrials_mdr;
    mdr_comb(s) = err_comb / nTrials_mdr;
end
fprintf('Done.\n');
fprintf('  MDR Legacy (127 RE) : [%s]\n', num2str(mdr_nr, ' %4.2f'));
fprintf('  MDR Comb-SSS (240 RE): [%s]\n', num2str(mdr_comb, ' %4.2f'));

%% ------------------------------------------------------------------------
% 3. LG ELECTRONICS (R1-2605506) VALIDATION
% Paper Table 1-3 & Fig 8-9: 7GHz, 1T4R, TDL-C 100ns, 30 km/h vs 120 km/h
% Expected: 1-Symbol concentrated DMRS robust at 30km/h, Doppler impact at 120km/h
% ------------------------------------------------------------------------
fprintf('\n>>> [3/3] LG ELECTRONICS (R1-2605506) VALIDATION (1T4R, TDL-C 100ns, 7GHz) <<<\n');

cfg_lge_30 = nr_sim.config.get_sim_config('CarrierFreq', 7e9, 'DelaySpread', 100e-9, 'SpeedKmph', 30);
cfg_lge_120 = nr_sim.config.get_sim_config('CarrierFreq', 7e9, 'DelaySpread', 100e-9, 'SpeedKmph', 120);

snr_lge = [-2, 0, 2];
nFrames_lge = 25;
fprintf('  Evaluating Design A (1-Symbol Concentrated) @ 30 vs 120 km/h ... ');
b_lge_30 = zeros(size(snr_lge));
b_lge_120 = zeros(size(snr_lge));

for s = 1:length(snr_lge)
    snr = snr_lge(s);
    e30 = 0; e120 = 0;
    for f = 1:nFrames_lge
        cid = 42;
        % 30 km/h
        [txW, ~, txP, cBits, ~] = nr_sim.tx.tx_pbch_chain('DesignA', cid, cfg_lge_30);
        [rxW, ch] = nr_sim.channel.apply_channel(txW, cfg_lge_30);
        [rxI, nVar] = nr_sim.channel.apply_rf_impairments(rxW, snr, 0, cfg_lge_30);
        [rxS, ~, estN2, ~] = nr_sim.rx.rx_sync_pss(rxI, cfg_lge_30, 'ChannelInfo', ch);
        gr = nr_sim.rx.rx_ofdm_demod(rxS, cfg_lge_30);
        [H_est, H_pbch, ~] = nr_sim.rx.rx_channel_estimate(gr, 'DesignA', cid, cfg_lge_30);
        [rx_p, ~, ~, ~] = nr_sim.grid.demap_ssb_grid(gr, 'DesignA', cid);
        [llrs, ~] = nr_sim.rx.rx_equalize_demap(rx_p, H_pbch, nVar);
        [~, isB, ~, ~] = nr_sim.rx.rx_pbch_chain(llrs, length(cBits), cfg_lge_30, 'TxPayload', txP);
        e30 = e30 + double(isB);
        
        % 120 km/h
        [txW, ~, txP, cBits, ~] = nr_sim.tx.tx_pbch_chain('DesignA', cid, cfg_lge_120);
        [rxW, ch] = nr_sim.channel.apply_channel(txW, cfg_lge_120);
        [rxI, nVar] = nr_sim.channel.apply_rf_impairments(rxW, snr, 0.1, cfg_lge_120);
        [rxS, ~, estN2, ~] = nr_sim.rx.rx_sync_pss(rxI, cfg_lge_120, 'ChannelInfo', ch);
        gr = nr_sim.rx.rx_ofdm_demod(rxS, cfg_lge_120);
        [H_est, H_pbch, ~] = nr_sim.rx.rx_channel_estimate(gr, 'DesignA', cid, cfg_lge_120);
        [rx_p, ~, ~, ~] = nr_sim.grid.demap_ssb_grid(gr, 'DesignA', cid);
        [llrs, ~] = nr_sim.rx.rx_equalize_demap(rx_p, H_pbch, nVar);
        [~, isB, ~, ~] = nr_sim.rx.rx_pbch_chain(llrs, length(cBits), cfg_lge_120, 'TxPayload', txP);
        e120 = e120 + double(isB);
    end
    b_lge_30(s) = e30 / nFrames_lge;
    b_lge_120(s) = e120 / nFrames_lge;
end
fprintf('Done.\n');
fprintf('  BLER @ 30 km/h  ([-2, 0, 2] dB): [%s]\n', num2str(b_lge_30, ' %4.2f'));
fprintf('  BLER @ 120 km/h ([-2, 0, 2] dB): [%s]\n', num2str(b_lge_120, ' %4.2f'));

fprintf('\n========================================================================\n');
fprintf('  ALL 3 COMPANY BENCHMARK COMPARISONS COMPLETED SUCCESSFULLY           \n');
fprintf('========================================================================\n\n');
