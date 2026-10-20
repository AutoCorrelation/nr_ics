# Dispatch for Explorer M2-2: RF Impairments & Noise Calibration

## Milestone
Milestone 2: Physical Channel, Mobility, and RF Impairments

## Mission
Formulate the exact implementation blueprint for:
1. `+nr_sim/+channel/apply_rf_impairments.m`:
   - Carrier frequency offset injection: initial CFO ($\pm 5\text{ ppm}$ or $\pm 20\text{ ppm}$ at $7\text{ GHz} = \pm 35\text{ kHz}$ or $\pm 140\text{ kHz}$).
   - Residual CFO ($\pm 0.1\text{ ppm} = \pm 700\text{ Hz}$).
   - Time-domain exponential frequency rotation: $r_{cfo}(t) = r(t) e^{j 2\pi \Delta f t}$.
2. `+nr_sim/+channel/add_awgn.m`:
   - Calibrated complex circular Gaussian AWGN noise over SNR sweep $[-14, -2]\text{ dB}$.
   - Exact noise power per RE calculation: $\sigma^2 = 10^{-SNR_{dB}/10}$.
   - Returns noisy waveform and scalar noise variance $N_{var}$.

## Reference Files
- `C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md`
- `C:\workspace\nr_ics\PROJECT.md`
- `C:\workspace\nr_ics\.agents\teamwork\spec_miner_survey_2\handoff.md`
- `C:\workspace\nr_ics\.agents\teamwork\explorer_survey_3\handoff.md`

## Output
Write your findings and drop-in code blueprints to `C:\workspace\nr_ics\.agents\teamwork\explorer_m2_2\handoff.md`.

## 2026-09-28T03:38:21Z
Task:
Formulate the exact implementation blueprint for +nr_sim/+channel/apply_rf_impairments.m and +nr_sim/+channel/add_awgn.m (CFO injection +-5/+-20 ppm, residual CFO +-0.1 ppm, calibrated AWGN over [-14, -2] dB).
Deliver report to C:\workspace\nr_ics\.agents\teamwork\explorer_m2_2\handoff.md.
