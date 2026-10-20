# Original User Request

## 2026-09-28T02:51:15Z

Build a modular, publication-grade 3GPP Rel-20 / 6G Link-Level Simulator (LLS) in MATLAB to evaluate advanced SSB architectures, focusing on SSS-as-DMRS and SSS-assisted PBCH demodulation under 3GPP RAN1#124bis/#125/#126 agreed baseline conditions.

Working directory: C:\workspace\nr_ics
Integrity mode: development

## Requirements

### R1. SSB Sequence Generation and Resource Grid Mapping
Implement sequence generation and 2D resource grid mapping ($240 \text{ RE} \times 4 \text{ OFDM symbols}$) for four distinct SSB architectures:
1. **Legacy 5G NR Baseline**: 127 RE SSS + Comb-4 Dedicated PBCH DMRS (144 DMRS REs, 432 PBCH data REs, polar rate $R \approx 0.0648$).
2. **Qualcomm Design A (R1-2606375)**: Concentrated 240 RE Extended SSS (truncated from base-255 Gold sequence) at Symbol #2 used directly as DMRS (0 dedicated DMRS, 480 PBCH data REs, polar rate $R \approx 0.0583$).
3. **Qualcomm Design B / MediaTek Comb-SSS (R1-2606847)**: Distributed 240 RE SSS multiplexed across Symbols #1, #2, #3 in Comb-3 pattern with 480 PBCH data REs.
4. **Jio Platforms SSS-Assisted (R1-2605419)**: Dedicated DMRS + SSS-assisted joint channel estimation within a Phase-Coherence Window ($q_{CW}$).

### R2. Physical Channel, Mobility, and RF Impairments
Implement the 3GPP simulation channel environment conforming to the agreed common LLS baseline:
- Carrier frequency: $7\text{ GHz}$, Subcarrier Spacing (SCS): $30\text{ kHz}$, FFT size: 512 ($f_s = 15.36\text{ MHz}$).
- Channel model: 3GPP TDL-C with delay spread $300\text{ ns}$ (via `nrTDLChannel`).
- Antenna configuration: 1T4R SIMO (Handheld UT model Combination 2) with MRC diversity combining.
- Mobility speeds: $3\text{ km/h}$ (pedestrian, $f_d \approx 19.4\text{ Hz}$) and $120\text{ km/h}$ (vehicular, $f_d \approx 777.8\text{ Hz}$).
- Impairments: Initial Carrier Frequency Offset ($\pm 5\text{ ppm}$ or $\pm 20\text{ ppm}$), residual CFO ($\pm 0.1\text{ ppm}$), and calibrated AWGN noise over an SNR sweep of $[-14, -2]\text{ dB}$.

### R3. Transceiver Signal Processing Pipeline
Implement complete end-to-end signal processing chains:
- **Tx Chain**: 56-bit PBCH MIB payload generation $\rightarrow$ CRC-24C encoding (`nrCRCEncode`) $\rightarrow$ Polar encoding (`nrPolarEncode`) $\rightarrow$ Rate matching (`nrRateMatchPolar`) to target RE counts ($864$ or $960$ coded bits) $\rightarrow$ QPSK modulation $\rightarrow$ Resource grid mapping $\rightarrow$ OFDM modulation with cyclic prefix (`nrOFDMModulate`).
- **Rx Chain**: PSS correlation & timing/coarse CFO acquisition $\rightarrow$ OFDM demodulation (`nrOFDMDemodulate`) $\rightarrow$ SSS detection & Cell-ID ($N_{ID}^{cell} \in [0, 1007]$) estimation $\rightarrow$ Design-specific channel estimation (DMRS-only, SSS-as-DMRS zero-order hold/extrapolation, Comb-SSS 2D interpolation, joint SSS+DMRS MMSE) $\rightarrow$ 2D MMSE equalization and soft LLR demapping $\rightarrow$ Polar rate recovery (`nrRateRecoverPolar`) $\rightarrow$ SCL polar decoding ($L=8$, `nrPolarDecode`) $\rightarrow$ CRC-24C verification.

### R4. Automated Monte-Carlo Execution and Publication-Grade Plotting
Implement a simulation engine supporting parallel execution (`parfor` via Parallel Computing Toolbox) and generate 5 clear, high-resolution figures saved in both `.png` and `.fig` formats:
1. **PBCH BLER vs. SNR at 3 km/h**: Demonstrating the $\sim 1.0 - 2.0\text{ dB}$ coding gain of DMRS-free designs (QC Design A, Comb-SSS) over Legacy NR.
2. **PBCH BLER vs. SNR at 120 km/h**: Demonstrating the Doppler aging breakdown of Concentrated SSS (Design A) versus the time-tracking resilience of Comb-SSS (Design B).
3. **Joint PSS/SSS MDR vs. SNR**: Comparing 127 RE SSS against 240 RE Extended SSS (verifying $>2\text{ dB}$ detection gain).
4. **Channel Estimation MSE vs. SNR**: Evaluating channel tracking fidelity across all four estimators.
5. **2D Resource Grid Layout Visualizer**: Visual comparison showing subcarrier-by-symbol allocation for all evaluated SSB designs.

---

## Verification Plan

### Automated Programmatic Tests
1. **Unit Test - Sequences & Gold Generator** (`tests/test_sequences.m`):
   - Verifies length-240 Extended SSS sequence generation, cross-correlation, and peak-to-sidelobe ratio.
2. **Unit Test - Transceiver Chain Back-to-Back** (`tests/test_pbch_chain.m`):
   - Verifies CRC-24C, Polar encoding, rate matching (432 RE vs 480 RE), QPSK modulation, rate recovery, and SCL decoding ($L=8$) under AWGN without channel fading. Expect 0 BLER at high SNR ($>0\text{ dB}$).
3. **Full Simulation Runner** (`main_run_simulation.m`):
   - Supports `'quick_demo'` mode ($\sim 50-100$ iterations/SNR point) for rapid verification in $<2$ minutes, and `'full_run'` mode for smooth publication curves.

---

## Acceptance Criteria

### Functionality & Robustness
- [ ] `tests/test_sequences.m` runs cleanly in MATLAB R2026a with all sequence properties passing assertions.
- [ ] `tests/test_pbch_chain.m` executes end-to-end and validates perfect PBCH recovery under AWGN for both $E=864$ and $E=960$ coded bit rates.
- [ ] `main_run_simulation.m` completes without unhandled errors in MATLAB, saving simulation results into structured `.mat` files.

### 3GPP Conformance & Key Technical Outcomes
- [ ] At $3\text{ km/h}$, Qualcomm Design A and Comb-SSS show improved PBCH BLER performance compared to Legacy NR due to increased PBCH data RE allocation (480 REs vs 432 REs).
- [ ] At $120\text{ km/h}$, Qualcomm Design A exhibits performance degradation compared to low-speed due to symbol-to-symbol Doppler variation, whereas Comb-SSS maintains channel tracking performance through time-distributed pilots.
- [ ] 240 RE Extended SSS demonstrates superior Missed Detection Rate (MDR) compared to 127 RE Legacy SSS at low SNRs (below $-8\text{ dB}$).
- [ ] All 5 figures (`fig1_bler_pedestrian.png`, `fig2_bler_vehicular.png`, `fig3_mdr_comparison.png`, `fig4_ch_est_mse.png`, `fig5_grid_allocation.png`) are generated, labeled with legends and axes, and saved to the workspace.
