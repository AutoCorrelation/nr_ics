function [rxWave, chInfo, tdlObj] = apply_channel(txWave, cfg, varargin)
%APPLY_CHANNEL Applies 3GPP TDL-C fading channel for 1T4R SIMO.
%
%   [RXWAVE, CHINFO, TDLOBJ] = APPLY_CHANNEL(TXWAVE, CFG)
%   passes the input time-domain waveform TXWAVE through a 3GPP TDL-C channel
%   model configured with 1 Tx antenna and 4 Rx antennas, parameterized by
%   CFG (carrier frequency, SCS, sample rate, delay spread, mobility speed).
%
%   Optional Name-Value Pairs:
%     'ChannelObject' - Pre-existing nrTDLChannel object to maintain state/fading
%     'SpeedKmph'     - Override mobility speed in km/h (default: cfg.SpeedKmph)

p = inputParser;
addParameter(p, 'ChannelObject', [], @(x) isempty(x) || isa(x, 'nrTDLChannel'));
addParameter(p, 'SpeedKmph', cfg.SpeedKmph, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});

speedKmph = p.Results.SpeedKmph;
tdlObj = p.Results.ChannelObject;

c = 299792458;
if isfield(cfg, 'MaxDoppler') && ~isempty(cfg.MaxDoppler)
    maxDoppler = cfg.MaxDoppler;
else
    speed_mps = speedKmph * (1000 / 3600);
    maxDoppler = (speed_mps / c) * cfg.CarrierFreq;
end

persistent tdlCache
if isempty(tdlObj)
    cacheKey = sprintf('%s_%.1e_%.2f_%d_%d_%d', cfg.ChannelProfile, cfg.DelaySpread, maxDoppler, cfg.SampleRate, cfg.NumTx, cfg.NumRx);
    if isempty(tdlCache) || ~isfield(tdlCache, 'key') || ~strcmp(tdlCache.key, cacheKey)
        tdlObj = nrTDLChannel;
        tdlObj.DelayProfile = cfg.ChannelProfile;
        tdlObj.DelaySpread = cfg.DelaySpread;
        tdlObj.MaximumDopplerShift = maxDoppler;
        tdlObj.SampleRate = cfg.SampleRate;
        tdlObj.NumTransmitAntennas = cfg.NumTx;
        tdlObj.NumReceiveAntennas = cfg.NumRx;
        tdlObj.NormalizePathGains = true;
        tdlObj.NormalizeChannelOutputs = false; % Conforms to 3GPP SNR per Rx antenna baseline
        tdlObj.RandomStream = 'Global stream';
        
        tdlCache.key = cacheKey;
        tdlCache.obj = tdlObj;
        tdlCache.pathFilters = getPathFilters(tdlObj);
    else
        tdlObj = tdlCache.obj;
    end
else
    if tdlObj.MaximumDopplerShift ~= maxDoppler
        tdlObj.MaximumDopplerShift = maxDoppler;
    end
end

[rxWave, pathGains, sampleTimes] = tdlObj(txWave);
if isempty(p.Results.ChannelObject) && ~isempty(tdlCache) && isfield(tdlCache, 'pathFilters')
    pathFilters = tdlCache.pathFilters;
else
    pathFilters = getPathFilters(tdlObj);
end

chInfo.pathGains = pathGains;
chInfo.sampleTimes = sampleTimes;
chInfo.pathFilters = pathFilters;
chInfo.maxDoppler = maxDoppler;
chInfo.speedKmph = speedKmph;
end
