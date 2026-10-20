# Progress: Explorer M2-2

Last visited: 2026-09-28T03:39:50Z

## Status
Investigating RF impairments (CFO injection, residual CFO) and calibrated AWGN noise modeling for Milestone 2.

## Current Step
- [x] Received dispatch and initialized BRIEFING.md
- [ ] Investigate 5G Toolbox OFDM scaling & noise power per RE relations in MATLAB
- [ ] Investigate carrier frequency offset (CFO) formulation: ppm to Hz conversion, continuous phase exponential multiplication, vector/multichannel broadcasting
- [ ] Investigate calibrated AWGN: circular complex Gaussian noise generation, RNG seeding, SNR sweep [-14, -2] dB, exact per-RE noise variance return
- [ ] Synthesize findings and interface contracts with M2 (apply_channel, channel_config) and M3 (rx_equalize_demap, nrEqualizeMMSE)
- [ ] Draft drop-in MATLAB blueprints for `apply_rf_impairments.m` and `add_awgn.m`
- [ ] Produce complete 5-component handoff.md report
