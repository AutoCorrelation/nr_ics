function [h_ideal, toffset] = get_ideal_channel(chInfo, cfg, varargin)
%GET_IDEAL_CHANNEL Computes true channel frequency response for 2D SSB grid.
%
%   [H_IDEAL, TOFFSET] = GET_IDEAL_CHANNEL(CHINFO, CFG)
%   computes the ground-truth channel transfer function across the 240 subcarriers
%   and 4 SSB OFDM symbols for all receive antennas (1T4R SIMO).
%
%   Optional Name-Value Pairs:
%     'TimingOffset' - Timing offset in samples (default: nrPerfectTimingEstimate)

p = inputParser;
addParameter(p, 'TimingOffset', [], @(x) isempty(x) || isnumeric(x));
parse(p, varargin{:});

if isempty(p.Results.TimingOffset)
    toffset = nrPerfectTimingEstimate(chInfo.pathGains, chInfo.pathFilters);
else
    toffset = p.Results.TimingOffset;
end

nrb = cfg.NumSubcarriers / 12;
scs_khz = cfg.SCS / 1e3;

h_all = nrPerfectChannelEstimate(chInfo.pathGains, chInfo.pathFilters, ...
    nrb, scs_khz, 0, toffset, 'Nfft', cfg.FFTSize, 'SampleRate', cfg.SampleRate);

% Extract the first NumSymbols (4 symbols of SSB)
h_ideal = h_all(:, 1:cfg.NumSymbols, :);
end
