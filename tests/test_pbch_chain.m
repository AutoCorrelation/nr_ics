% TEST_PBCH_CHAIN Unit and integration tests for complete 6G SSB transceiver pipeline.
% Tests end-to-end PBCH transmission, channel estimation, equalization, and Polar SCL decoding.

clear; clc;
fprintf('========================================================================\n');
fprintf('  STARTING TEST_PBCH_CHAIN: End-to-End Transceiver Pipeline Validation  \n');
fprintf('========================================================================\n');

cfg = nr_sim.config.get_sim_config('CarrierFreq', 7e9, 'SpeedKmph', 3);
architectures = {'Legacy', 'DesignA', 'DesignB', 'Jio'};
cellID = 42;

for i = 1:length(architectures)
    arch = architectures{i};
    fprintf('\n--- Testing Architecture: %s ---\n', arch);
    
    % 1. Transmitter Chain
    [txWave, grid_ssb, txPayload, codedBits, txInfo] = nr_sim.tx.tx_pbch_chain(arch, cellID, cfg);
    
    % Verify bit and symbol counts
    if ismember(arch, {'Legacy', 'Jio'})
        assert(length(codedBits) == 864, 'Coded bits must be 864 for Legacy/Jio');
        assert(txInfo.numDataREs == 432, 'PBCH REs must be 432 for Legacy/Jio');
        E = 864;
    else
        assert(length(codedBits) == 960, 'Coded bits must be 960 for DesignA/DesignB');
        assert(txInfo.numDataREs == 480, 'PBCH REs must be 480 for DesignA/DesignB');
        E = 960;
    end
    fprintf('  [PASS] Tx bit allocation and grid mapping confirmed (E=%d, REs=%d).\n', E, txInfo.numDataREs);
    
    % 2. High SNR AWGN Channel (clean verification)
    snrdB = 15;
    [rxWaveImpaired, noiseVarRE] = nr_sim.channel.apply_rf_impairments(repmat(txWave, 1, 4), snrdB, 0, cfg);
    
    % 3. Receiver: PSS Sync
    [rxWaveSynced, timingOffset, estN_ID_2, coarseCFO] = nr_sim.rx.rx_sync_pss(rxWaveImpaired, cfg);
    assert(estN_ID_2 == txInfo.N_ID_2, 'PSS sector ID must be correctly detected');
    fprintf('  [PASS] PSS sector sync correct (Sector %d, TimingOffset %d).\n', estN_ID_2, timingOffset);
    
    % 4. Receiver: OFDM Demodulation
    rxGrid = nr_sim.rx.rx_ofdm_demod(rxWaveSynced, cfg);
    assert(isequal(size(rxGrid), [240, 4, 4]), 'rxGrid must be [240 x 4 x 4]');
    
    % 5. Receiver: SSS Detection & Cell ID
    [estCellID, estN_ID_1, ~, isMDR] = nr_sim.rx.rx_detect_sss(rxGrid, estN_ID_2, arch, cfg, 'TrueCellID', cellID);
    assert(estCellID == cellID, 'Cell ID must be correctly detected at high SNR');
    assert(~isMDR, 'Missed Detection must be false at high SNR');
    fprintf('  [PASS] SSS detection correct (Cell ID %d, N_ID_1 %d).\n', estCellID, estN_ID_1);
    
    % 6. Receiver: Channel Estimation
    [H_est, H_pbch, demapInfo] = nr_sim.rx.rx_channel_estimate(rxGrid, arch, estCellID, cfg);
    assert(isequal(size(H_est), [240, 4, 4]), 'H_est must be [240 x 4 x 4]');
    assert(size(H_pbch, 1) == txInfo.numDataREs, 'H_pbch rows must match numDataREs');
    
    % 7. Receiver: Equalization & LLR demapping
    [rx_pbch, ~, ~, ~] = nr_sim.grid.demap_ssb_grid(rxGrid, arch, estCellID);
    [llrs, eqSyms] = nr_sim.rx.rx_equalize_demap(rx_pbch, H_pbch, noiseVarRE);
    assert(length(llrs) == E, 'LLR length must equal E');
    
    % 8. Receiver: Polar Decoding and CRC
    [rxPayload, isBLER, crcErr, bitErrors] = nr_sim.rx.rx_pbch_chain(llrs, E, cfg, 'TxPayload', txPayload);
    assert(crcErr == 0, 'CRC error must be 0 at high SNR');
    assert(~isBLER, 'BLER must be 0 at high SNR');
    assert(bitErrors == 0, 'Bit errors must be 0 at high SNR');
    fprintf('  [PASS] End-to-end PBCH recovery verified (0 bit errors, 0 CRC error).\n');
end

fprintf('\n========================================================================\n');
fprintf('  [PASS] All 4 SSB Transceiver Pipeline Architectures Verified!        \n');
fprintf('========================================================================\n');
