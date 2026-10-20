% TEST_CHANNEL Unit and validation tests for channel and RF impairments
% Tests TDL-C 300ns fading, Doppler shift, CFO, and noise calibration.

clear; clc;
fprintf('========================================================================\n');
fprintf('  STARTING TEST_CHANNEL: TDL-C, Mobility & RF Impairments Validation    \n');
fprintf('========================================================================\n');

cfg = nr_sim.config.get_sim_config('CarrierFreq', 7e9, 'SpeedKmph', 3);

% Test 1: Dimensions and basic execution
nSamples = 7680;
txWave = complex(randn(nSamples, 1), randn(nSamples, 1));
[rxWave, chInfo] = nr_sim.channel.apply_channel(txWave, cfg);

assert(isequal(size(rxWave), [nSamples, 4]), 'rxWave must be [7680 x 4]');
assert(chInfo.maxDoppler > 19 && chInfo.maxDoppler < 20, 'Max Doppler at 3 km/h must be ~19.4 Hz');
fprintf('  [PASS] Test 1: 1T4R TDL-C channel dimensions and Doppler correct.\n');

% Test 2: High mobility (120 km/h) Doppler check
cfgHigh = nr_sim.config.get_sim_config('CarrierFreq', 7e9, 'SpeedKmph', 120);
[~, chInfoHigh] = nr_sim.channel.apply_channel(txWave, cfgHigh);
assert(chInfoHigh.maxDoppler > 770 && chInfoHigh.maxDoppler < 780, 'Max Doppler at 120 km/h must be ~777.8 Hz');
fprintf('  [PASS] Test 2: 120 km/h vehicular Doppler verified (~777.8 Hz).\n');

% Test 3: Ideal channel response calculation
grid_slot = complex(zeros(240, 14));
grid_slot(:, 1:4) = complex(randn(240, 4), randn(240, 4));
txWaveSlot = nrOFDMModulate(grid_slot, 30, 0, 'Nfft', 512, 'SampleRate', 15.36e6, 'Windowing', 0);
[rxWaveSlot, chInfoSlot] = nr_sim.channel.apply_channel(txWaveSlot, cfg);
h_ideal = nr_sim.channel.get_ideal_channel(chInfoSlot, cfg);
assert(isequal(size(h_ideal), [240, 4, 4]), 'h_ideal must be [240 x 4 x 4]');
fprintf('  [PASS] Test 3: Ground-truth channel estimation dimensions [240 x 4 x 4] verified.\n');

% Test 4: Calibrated AWGN noise variance check
snrdB = 10;
[rxImpaired, noiseVarRE] = nr_sim.channel.apply_rf_impairments(zeros(nSamples, 4), snrdB, 0, cfg);
rxGrid = nrOFDMDemodulate(rxImpaired, 20, 30, 0, 'Nfft', 512, 'SampleRate', 15.36e6);
measuredNoise = mean(abs(rxGrid(:)).^2);
relError = abs(measuredNoise - noiseVarRE) / noiseVarRE;
assert(relError < 0.1, 'Calibrated noise variance must match within statistical tolerance');
fprintf('  [PASS] Test 4: Frequency-domain noise variance calibration accurate (error < 10%%).\n');

% Test 5: CFO injection check
cfo_ppm = 5;
[rxCfo, ~] = nr_sim.channel.apply_rf_impairments(ones(nSamples, 1), 100, cfo_ppm, cfg);
deltaF_expected = 5e-6 * 7e9; % 35 kHz
phaseDiff = angle(rxCfo(2:end) .* conj(rxCfo(1:end-1)));
measuredFreq = mean(phaseDiff) * 15.36e6 / (2*pi);
assert(abs(measuredFreq - deltaF_expected) < 10, 'Injected CFO frequency must match 35 kHz');
fprintf('  [PASS] Test 5: CFO injection frequency accurate.\n');

fprintf('\n[PASS] All 5 Channel & Impairment tests passed successfully.\n');
