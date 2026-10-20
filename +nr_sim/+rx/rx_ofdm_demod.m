function rxGrid = rx_ofdm_demod(rxWaveSynced, cfg)
%RX_OFDM_DEMOD Demodulates received waveform into 2D SSB frequency grid.
%
%   RXGRID = RX_OFDM_DEMOD(RXWAVESYNCED, CFG)
%   performs OFDM demodulation and extracts the 4 SSB OFDM symbols across
%   all receive antennas.
%
%   Output:
%     RXGRID - [240 x 4 x NumRx] complex array

nrb = cfg.NumSubcarriers / 12;
scs_khz = cfg.SCS / 1e3;

% Demodulate full slot
rxSlot = nrOFDMDemodulate(rxWaveSynced, nrb, scs_khz, 0, ...
    'Nfft', cfg.FFTSize, 'SampleRate', cfg.SampleRate, ...
    'CyclicPrefixFraction', 0.5);

% Extract first NumSymbols (4 symbols of SSB)
rxGrid = rxSlot(:, 1:cfg.NumSymbols, :);
end
