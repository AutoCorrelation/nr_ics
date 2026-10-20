# Dispatch for Explorer M2-1: TDL-C 1T4R Channel & Ground Truth Modeling

## Milestone
Milestone 2: Physical Channel, Mobility, and RF Impairments

## Mission
Formulate the exact implementation blueprint for:
1. `+nr_sim/+config/channel_config.m`:
   - Carrier frequency $f_c = 7\text{ GHz}$, SCS $30\text{ kHz}$, FFT size 512, sample rate $f_s = 15.36\text{ MHz}$.
   - TDL-C profile with RMS delay spread $300\text{ ns}$ (`nrTDLChannel`).
   - 1T4R SIMO antenna setup.
   - Mobility configs: Pedestrian $3\text{ km/h}$ ($f_d \approx 19.4\text{ Hz}$) and Vehicular $120\text{ km/h}$ ($f_d \approx 777.8\text{ Hz}$).
2. `+nr_sim/+channel/apply_channel.m`:
   - Executes `nrTDLChannel` on transmitted waveform, returning 4-channel received waveform `[N_samples x 4]`, `pathGains`, and `sampleTimes`.
3. `+nr_sim/+channel/get_ideal_channel.m`:
   - Extracts ground-truth channel frequency response matrix `H_ideal` `[240 x 4 x 4]` using `nrPerfectChannelEstimate` for Figure 4 MSE evaluation.

## Reference Files
- `C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md`
- `C:\workspace\nr_ics\PROJECT.md`
- `C:\workspace\nr_ics\.agents\teamwork\spec_miner_survey_2\handoff.md`
- `C:\workspace\nr_ics\.agents\teamwork\explorer_survey_3\handoff.md`

## Output
Write your findings and drop-in code blueprints to `C:\workspace\nr_ics\.agents\teamwork\explorer_m2_1\handoff.md`.

## 2026-09-28T03:38:21Z
Task received from parent:
Formulate the exact implementation blueprint for +nr_sim/+config/channel_config.m, +nr_sim/+channel/apply_channel.m, and +nr_sim/+channel/get_ideal_channel.m (1T4R SIMO, 300ns TDL-C, 3 km/h & 120 km/h, perfect channel extraction).
Deliver report to C:\workspace\nr_ics\.agents\teamwork\explorer_m2_1\handoff.md.

