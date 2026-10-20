function [llrs, eqSyms] = rx_equalize_demap(rx_pbch, H_pbch, noiseVarRE)
%RX_EQUALIZE_DEMAP SIMO 1T4R MRC equalization and soft QPSK LLR demapping.
%
%   [LLRS, EQSYMS] = RX_EQUALIZE_DEMAP(RX_PBCH, H_PBCH, NOISEVARRE)
%   computes the Maximum Ratio Combining (MRC) diversity statistic across
%   receive antennas and derives optimal max-log LLRs for QPSK demapping.
%
%   Inputs:
%     RX_PBCH    - Extracted PBCH received symbols [numDataREs x NumRx]
%     H_PBCH     - Channel frequency response at PBCH REs [numDataREs x NumRx]
%     NOISEVARRE - Noise variance per resource element (scalar)
%
%   Outputs:
%     LLRS       - Soft log-likelihood ratios [2*numDataREs x 1] (864 or 960)
%     EQSYMS     - Normalized equalized constellation symbols [numDataREs x 1]

numDataREs = size(rx_pbch, 1);

% 1. SIMO Maximum Ratio Combining (MRC)
z = sum(conj(H_pbch) .* rx_pbch, 2); % [numDataREs x 1]
hPower = sum(abs(H_pbch).^2, 2);     % [numDataREs x 1]

% Normalized equalized symbols (for constellation display or EVM)
eqSyms = z ./ max(hPower, 1e-12);

% 2. Exact Max-Log LLR Calculation for 3GPP QPSK:
% In 3GPP TS 38.211 QPSK: s = (1/sqrt(2)) * ((1 - 2*b0) + 1i*(1 - 2*b1))
% LLR = log(P(b=0)/P(b=1))
scale = sqrt(2) * (2 / noiseVarRE);
llr_0 = scale * real(z);
llr_1 = scale * imag(z);

llrs = zeros(2 * numDataREs, 1);
llrs(1:2:end) = llr_0;
llrs(2:2:end) = llr_1;

end
