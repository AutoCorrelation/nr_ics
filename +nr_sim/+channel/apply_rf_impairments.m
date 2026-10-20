function [rxWaveOut, noiseVarRE] = apply_rf_impairments(rxWave, snrdB, cfo_ppm, cfg)
%APPLY_RF_IMPAIRMENTS Injects CFO and calibrated AWGN noise for 1T4R SIMO.
%
%   [RXWAVEOUT, NOISEVARRE] = APPLY_RF_IMPAIRMENTS(RXWAVE, SNRDB, CFO_PPM, CFG)
%   applies carrier frequency offset (CFO) and adds complex additive white
%   Gaussian noise calibrated to SNRDB per resource element (RE).
%
%   Inputs:
%     RXWAVE    - Faded receive waveform [N_samples x NumRx]
%     SNRDB     - Signal-to-noise ratio in dB per RE
%     CFO_PPM   - Frequency offset in parts-per-million (ppm)
%     CFG       - Simulator configuration struct
%
%   Outputs:
%     RXWAVEOUT  - Impaired receive waveform [N_samples x NumRx]
%     NOISEVARRE - True noise variance per RE (10^(-SNRdB/10))

nSamples = size(rxWave, 1);
numRx = size(rxWave, 2);

% 1. Apply Carrier Frequency Offset (CFO)
if cfo_ppm ~= 0
    deltaF = cfo_ppm * 1e-6 * cfg.CarrierFreq;
    t = (0:nSamples - 1)' / cfg.SampleRate;
    cfoRamp = exp(1i * 2 * pi * deltaF * t);
    rxWaveCfo = rxWave .* cfoRamp;
else
    rxWaveCfo = rxWave;
end

% 2. Add Calibrated Complex Gaussian Noise
noiseVarRE = 10^(-snrdB / 10);
noiseVarTime = noiseVarRE / cfg.FFTSize;

noise = sqrt(noiseVarTime / 2) * (randn(nSamples, numRx) + 1i * randn(nSamples, numRx));
rxWaveOut = rxWaveCfo + noise;
end
