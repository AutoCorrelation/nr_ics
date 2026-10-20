function [txWave, grid_ssb, txPayload, codedBits, info] = tx_pbch_chain(arch, N_ID_cell, cfg, varargin)
%TX_PBCH_CHAIN Complete transmitter chain for 6G SSB.
%
%   [TXWAVE, GRID_SSB, TXPAYLOAD, CODEDBITS, INFO] = TX_PBCH_CHAIN(ARCH, N_ID_CELL, CFG)
%   generates 56-bit PBCH payload, attaches CRC-24C, performs Polar encoding,
%   rate matching, QPSK modulation, 2D resource grid mapping, and OFDM modulation.
%
%   Inputs:
%     ARCH      - Architecture identifier ('Legacy', 'DesignA', 'DesignB', 'Jio')
%     N_ID_CELL - Physical Cell ID (0..1007)
%     CFG       - Simulator configuration struct
%
%   Optional Name-Value Pairs:
%     'Payload'   - Predefined 56-bit payload (default: random 56 bits)
%     'ibar_SSB'  - SSB candidate index (0..7, default: 0)

p = inputParser;
addParameter(p, 'Payload', [], @(x) isempty(x) || (isvector(x) && length(x) == cfg.PolarK));
addParameter(p, 'ibar_SSB', cfg.SSBCandidate, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'PowerMode', 'EqualEPRE', @(x) ischar(x) && ismember(x, {'EqualEPRE', 'EqualTotalEnergy'}));
parse(p, varargin{:});

if isempty(p.Results.Payload)
    txPayload = randi([0 1], cfg.PolarK, 1);
else
    txPayload = double(p.Results.Payload(:));
end
ibar_SSB = p.Results.ibar_SSB;
powerMode = p.Results.PowerMode;

% 1. Determine rate-matched length E
arch_str = validatestring(arch, {'Legacy', 'DesignA', 'DesignB', 'Jio', 'Proposed5Symbol'});
switch arch_str
    case {'Legacy', 'Jio', 'Proposed5Symbol'}
        E = cfg.CodedBits_Legacy; % 864
    case {'DesignA', 'DesignB'}
        E = cfg.CodedBits_DesignA; % 960
end

% 2. CRC-24C Attachment (K + 24 = 80 bits)
crcBits = nrCRCEncode(txPayload, cfg.CRCPoly);

% 3. Polar Encode (outputs mother polar code N=512)
encBits = nrPolarEncode(crcBits, E);

% 4. Rate Matching (to length E)
codedBits = nrRateMatchPolar(encBits, length(crcBits), E);

% 5. QPSK Modulation
pbch_syms = nrSymbolModulate(codedBits, 'QPSK');

% 6. Map to 2D SSB Grid
[grid_ssb, info] = nr_sim.grid.map_ssb_grid(pbch_syms, arch_str, N_ID_cell, ...
    'ibar_SSB', ibar_SSB, 'PowerMode', powerMode);

% 7. Slot Placement and OFDM Modulation
grid_slot = complex(zeros(cfg.NumSubcarriers, 14));
numSyms = size(grid_ssb, 2);
grid_slot(:, 1:numSyms) = grid_ssb;

scs_khz = cfg.SCS / 1e3;
txWave = nrOFDMModulate(grid_slot, scs_khz, 0, 'Nfft', cfg.FFTSize, ...
    'SampleRate', cfg.SampleRate, 'Windowing', 0);
end
