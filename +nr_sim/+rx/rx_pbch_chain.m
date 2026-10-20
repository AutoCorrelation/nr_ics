function [rxPayload, isBLER, crcErr, bitErrors] = rx_pbch_chain(llrs, E, cfg, varargin)
%RX_PBCH_CHAIN Polar rate recovery, SCL decoding, and CRC-24C verification.
%
%   [RXPAYLOAD, ISBLER, CRCERR, BITERRORS] = RX_PBCH_CHAIN(LLRS, E, CFG)
%   performs 3GPP Rel-15/20 Polar rate recovery, Successive Cancellation List
%   (SCL) decoding (List size L=8), and CRC-24C check.
%
%   Inputs:
%     LLRS - Soft LLR vector [E x 1] (864 for Legacy/Jio, 960 for DesignA/DesignB)
%     E    - Rate-matched coded bit length (864 or 960)
%     CFG  - Simulator configuration struct
%
%   Optional Name-Value Pairs:
%     'TxPayload' - Transmitted 56-bit payload for Bit Error Rate (BER) evaluation

p = inputParser;
addParameter(p, 'TxPayload', [], @(x) isempty(x) || isvector(x));
parse(p, varargin{:});
txPayload = p.Results.TxPayload;

K_crc = cfg.PolarK + 24; % 56 + 24 = 80 bits

% 1. Polar Rate Recovery (Recovers mother code length N=512)
rec = nrRateRecoverPolar(llrs, K_crc, cfg.PolarN);

% 2. Successive Cancellation List (SCL) Polar Decoding (List size L=8)
decBits = nrPolarDecode(rec, K_crc, E, cfg.PolarListSize);

% 3. CRC-24C Decoding & Error Detection
[rxPayload, crcErr] = nrCRCDecode(decBits, cfg.CRCPoly);

% BLER is 1 if CRC check fails
isBLER = (crcErr ~= 0);

% Compute bit errors if ground truth is supplied
if ~isempty(txPayload) && length(rxPayload) == length(txPayload)
    bitErrors = sum(txPayload(:) ~= rxPayload(:));
else
    bitErrors = NaN;
end

end
