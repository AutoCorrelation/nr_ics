function cfg = get_sim_config(varargin)
%GET_SIM_CONFIG Returns standard simulation configuration struct for 6G SSB LLS.
%
%   CFG = GET_SIM_CONFIG('PropertyName', PropertyValue, ...)
%
%   Conforms to 3GPP RAN1#124bis, #125, #126 Common LLS Baseline parameters:
%     - Carrier: 7 GHz (TDD)
%     - SCS: 30 kHz
%     - Channel: 3GPP TDL-C (Delay spread: 300 ns)
%     - Antennas: 1T4R SIMO (Handheld UT Combination 2)
%     - Mobility: 3 km/h (pedestrian) and 120 km/h (vehicular)
%     - Polar Code: K=56, CRC-24C, SCL List Size L=8, Mother length N=512

p = inputParser;
addParameter(p, 'CarrierFreq', 7e9, @(x) isnumeric(x) && x > 0);
addParameter(p, 'SCS', 30e3, @(x) ismember(x, [15e3, 30e3, 60e3, 120e3]));
addParameter(p, 'FFTSize', 512, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'SampleRate', 15.36e6, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'NumSubcarriers', 240, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'NumSymbols', 4, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'ChannelProfile', 'TDL-C', @ischar);
addParameter(p, 'DelaySpread', 300e-9, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'NumTx', 1, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'NumRx', 4, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'SpeedKmph', 3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'InitialCFO_ppm', 5, @(x) isnumeric(x));
addParameter(p, 'ResidualCFO_ppm', 0.1, @(x) isnumeric(x));
addParameter(p, 'SNRdB', -14:2:-2, @isnumeric);
addParameter(p, 'NumFrames', 100, @(x) isnumeric(x) && x > 0);
addParameter(p, 'PolarK', 56, @(x) isnumeric(x));
addParameter(p, 'PolarN', 512, @(x) isnumeric(x));
addParameter(p, 'PolarListSize', 8, @(x) isnumeric(x));
addParameter(p, 'CRCPoly', '24C', @ischar);
addParameter(p, 'CellID', 1, @(x) isnumeric(x) && x >= 0 && x <= 1007);
addParameter(p, 'SSBCandidate', 0, @(x) isnumeric(x) && x >= 0 && x <= 7);
parse(p, varargin{:});

cfg = p.Results;

% Speed of light and Doppler calculation
c = 299792458;
speed_mps = cfg.SpeedKmph * (1000 / 3600);
cfg.MaxDoppler = (speed_mps / c) * cfg.CarrierFreq;

% Standard 5G normal CP lengths for 30 kHz SCS (FFT 512, fs 15.36 MHz)
% Symbol 0 has 52 CP samples, Symbols 1..3 have 36 CP samples
scale = cfg.FFTSize / 512;
cfg.CPLengths = [round(52 * scale), round(36 * scale) * ones(1, cfg.NumSymbols - 1)];

% Coding rates and bit allocations
cfg.BitsPerSymbol = 2; % QPSK
cfg.NumRE_Legacy = 432;
cfg.NumRE_DesignA = 480;
cfg.NumRE_DesignB = 480;
cfg.NumRE_Jio = 432;
cfg.NumRE_Proposed5Symbol = 432;

cfg.CodedBits_Legacy = cfg.NumRE_Legacy * cfg.BitsPerSymbol;   % 864
cfg.CodedBits_DesignA = cfg.NumRE_DesignA * cfg.BitsPerSymbol; % 960
cfg.CodedBits_DesignB = cfg.NumRE_DesignB * cfg.BitsPerSymbol; % 960
cfg.CodedBits_Jio = cfg.NumRE_Jio * cfg.BitsPerSymbol;         % 864
cfg.CodedBits_Proposed5Symbol = cfg.NumRE_Proposed5Symbol * cfg.BitsPerSymbol; % 864

cfg.CodeRate_Legacy = cfg.PolarK / cfg.CodedBits_Legacy;   % ~0.0648
cfg.CodeRate_DesignA = cfg.PolarK / cfg.CodedBits_DesignA; % ~0.0583
cfg.CodeRate_DesignB = cfg.PolarK / cfg.CodedBits_DesignB; % ~0.0583
cfg.CodeRate_Jio = cfg.PolarK / cfg.CodedBits_Jio;         % ~0.0648
cfg.CodeRate_Proposed5Symbol = cfg.PolarK / cfg.CodedBits_Proposed5Symbol; % ~0.0648
end
