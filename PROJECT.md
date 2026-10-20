# Project: 3GPP Rel-20 / 6G Link-Level Simulator (LLS)

## Architecture
Modular, publication-grade MATLAB Link-Level Simulator for evaluating advanced 3GPP Rel-20 / 6G SSB architectures under agreed RAN1 #124bis/#125/#126 baseline conditions.

- **System Parameters**:
  - Carrier frequency: $7\text{ GHz}$, Subcarrier Spacing (SCS): $30\text{ kHz}$
  - FFT size: 512, Sampling rate: $f_s = 15.36\text{ MHz}$
  - Channel: 3GPP TDL-C, RMS delay spread $300\text{ ns}$ (`nrTDLChannel`)
  - Antenna setup: 1T4R SIMO (Handheld UT Combination 2) with 2D MMSE / MRC
  - Mobility: Pedestrian $3\text{ km/h}$ ($f_d \approx 19.4\text{ Hz}$), Vehicular $120\text{ km/h}$ ($f_d \approx 777.8\text{ Hz}$)
  - RF Impairments: Initial CFO ($\pm 5\text{ ppm}$ or $\pm 20\text{ ppm}$), residual CFO ($\pm 0.1\text{ ppm} = \pm 700\text{ Hz}$), calibrated AWGN over SNR $[-14, -2]\text{ dB}$

- **Architectures Evaluated**:
  1. **Legacy 5G NR Baseline**: 127 SSS + Comb-4 Dedicated PBCH DMRS (144 DMRS REs, 432 Data REs, $E=864$, Polar rate $R \approx 0.0648$).
  2. **Qualcomm Design A (R1-2606375)**: Concentrated 240 RE Extended SSS at Symbol #2 (truncated Gold-255) as DMRS, 0 dedicated DMRS, 480 Data REs, $E=960$, Polar rate $R \approx 0.0583$.
  3. **Qualcomm Design B / MediaTek Comb-SSS (R1-2606847)**: Distributed 240 RE SSS multiplexed across Symbols #1, #2, #3 in Comb-3 pattern, 0 dedicated DMRS, 480 Data REs, $E=960$, Polar rate $R \approx 0.0583$.
  4. **Jio Platforms SSS-Assisted (R1-2605419)**: Dedicated Comb-4 DMRS (144 REs) + SSS-assisted joint channel estimation (127 REs) within Phase-Coherence Window ($q_{CW}$), 432 Data REs, $E=864$.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | Legacy PSS & SSS Generation | TS 38.211 m-sequence ($L=127$) PSS & dual m-sequence SSS | M1 | TS 38.211 §7.4.2 |
| F2 | Extended SSS Generation | Length-240 truncated base-255 Gold sequence ($g_1, g_2$, PSLR $>15\text{ dB}$) | M1 | R1-2606375, R1-2606847 |
| F3 | PBCH DMRS Generation | 3GPP TS 38.211 Section 7.4.3 length-144 Gold-31 pseudorandom sequence | M1 | TS 38.211 §7.4.3 |
| F4 | Legacy Grid Mapping | 2D mapping: 127 SSS, 144 DMRS, 432 PBCH Data, 130 Null REs ($E=864$) | M1 | TS 38.211 §7.4.3 |
| F5 | Design A Grid Mapping | 2D mapping: 240 SSS at Sym 2, 0 DMRS, 480 Data REs ($E=960$) | M1 | R1-2606375 |
| F6 | Design B Comb-SSS Grid Mapping | 2D mapping: Comb-3 SSS (80 REs/sym, syms 1-3), 480 Data REs ($E=960$) | M1 | R1-2606847 |
| F7 | Jio Platforms Grid Mapping | 2D mapping: Legacy grid with phase-coherent SSS joint pilot support ($E=864$) | M1 | R1-2605419 |
| F8 | Grid Demapping & Pilot Masks | Extract data, pilot, and guard subcarriers per symbol for all 4 designs | M1 | Spec Survey |
| F9 | 3GPP TDL-C Channel | 1T4R SIMO TDL-C, delay spread $300\text{ ns}$ at $7\text{ GHz}$, $f_s = 15.36\text{ MHz}$ | M2 | TS 38.101-4, TR 38.901 |
| F10 | Mobility Models | Pedestrian $3\text{ km/h}$ ($f_d \approx 19.4\text{ Hz}$) & Vehicular $120\text{ km/h}$ ($f_d \approx 777.8\text{ Hz}$) | M2 | 3GPP RAN1 baseline |
| F11 | RF Impairments & AWGN | Initial CFO ($\pm 5/\pm 20\text{ ppm}$), residual CFO ($\pm 0.1\text{ ppm}$), calibrated AWGN | M2 | TS 38.101-4 |
| F12 | Ground-Truth Channel Benchmark | Ideal channel frequency response extraction (`nrPerfectChannelEstimate`) | M2 | Architecture Survey |
| F13 | Complete Tx PBCH Chain | 56-bit MIB -> CRC-24C -> Polar -> Rate Match ($E=864/960$) -> QPSK -> Grid -> OFDM | M3 | TS 38.212 §7.1 |
| F14 | Rx Sync & Coarse CFO | PSS correlation & timing/coarse CFO acquisition via CP correlation | M3 | TS 38.211 |
| F15 | OFDM Demodulation | CP removal & FFT demodulation producing $240 \times 4 \times 4$ frequency grid | M3 | 3GPP baseline |
| F16 | SSS Detection & Cell-ID | Cell-ID estimation ($N_{ID}^{cell} \in [0, 1007]$) for Legacy 127 and Extended 240 SSS | M3 | RAN1 #125/126 |
| F17 | 4 Channel Estimators | DMRS-only interp, Design A ZOH/extrap, Comb-3 2D interp, Jio joint MMSE | M3 | Rel-20 Proposals |
| F18 | 2D MMSE & 1T4R SIMO MRC | 1T4R SIMO MRC combining and MMSE equalization with soft CSI calculation | M3 | Standard SIMO MMSE |
| F19 | Rx PBCH Decoding Chain | Soft LLR -> Rate Recover ($N=512$) -> SCL Polar Decode ($L=8$) -> CRC-24C check | M3 | TS 38.212 |
| F20 | Monte-Carlo Parallel Engine | `main_run_simulation.m` with `'quick_demo'` ($<2$ min) and `'full_run'` (`parfor`) | M4 | System Survey |
| F21 | Publication Fig 1 | BLER vs SNR at $3\text{ km/h}$ ($1.0 - 2.0\text{ dB}$ coding gain of $E=960$) | M4 | Acceptance Criteria |
| F22 | Publication Fig 2 | BLER vs SNR at $120\text{ km/h}$ (Doppler breakdown of Design A vs Comb-SSS) | M4 | Acceptance Criteria |
| F23 | Publication Fig 3 | Joint PSS/SSS MDR vs SNR ($>2\text{ dB}$ gain of 240 Extended SSS over 127 SSS) | M4 | Acceptance Criteria |
| F24 | Publication Fig 4 | Channel Estimation MSE vs SNR across all 4 estimators | M4 | Acceptance Criteria |
| F25 | Publication Fig 5 | 2D Resource Grid Layout visualizer across all 4 architectures | M4 | Acceptance Criteria |
| F26 | Unit Test: Sequences | `tests/test_sequences.m`: length, auto-corr peak, PSLR $>15\text{ dB}$, cross-corr | E2E / M1 | Verification Plan |
| F27 | Unit Test: Transceiver Chain | `tests/test_pbch_chain.m`: back-to-back AWGN 0 BLER at high SNR for $E=864, 960$ | E2E / M3 | Verification Plan |
| F28 | End-to-End Validation & Hardening | Full E2E Test Suite Tiers 1-4 (100% pass) and Adversarial Hardening Tier 5 | Final (M5) | Dual Track Requirement |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| E2E | E2E Testing Track | Independent requirement-driven test suite (Tiers 1-4), harness, TEST_READY.md | none | IN_PROGRESS |
| M1 | SSB Sequences & Grid Mapping | F1-F8, `tests/test_sequences.m`, grid mappers & demappers for 4 designs | none | DONE |
| M2 | Channel, Mobility & Impairments | F9-F12, TDL-C 300ns 1T4R, 3 km/h & 120 km/h, CFO & AWGN, ideal channel | M1 interface | PLANNED |
| M3 | Transceiver Signal Processing Pipeline | F13-F19, Tx & Rx chains, 4 estimators, SIMO MRC, Polar SCL, `tests/test_pbch_chain.m` | M1, M2 | PLANNED |
| M4 | Monte-Carlo Engine & Publication Plots | F20-F25, `main_run_simulation.m`, publication plotting (`fig1`..`fig5` .png/.fig) | M1, M2, M3 | PLANNED |
| M5 | Final Milestone: E2E Validation & Adversarial Hardening | F28, Phase 1: 100% pass on E2E test suite (Tiers 1-4); Phase 2: Tier 5 adversarial hardening | E2E, M4 | PLANNED |

## Interface Contracts

### M1 ↔ M3: Sequence & Grid Interfaces
- `gen_PSSNR(N_ID_2)`: returns `[127 x 1 double]` in `{-1, +1}`.
- `gen_SSS(N_ID_1, N_ID_2)`: returns `[127 x 1 double]` in `{-1, +1}`.
- `gen_ExtendedSSS(N_ID_cell)`: returns `[240 x 1 double]` in `{-1, +1}`, base-255 Gold truncated.
- `gen_PBCHDMRS(N_ID_cell, ibar_SSB)`: returns `[144 x 1 complex double]`, unit power.
- `map_ssb_grid(pbch_syms, arch, N_ID_cell)`:
  - `pbch_syms`: `[432 x 1]` (Legacy, Jio) or `[480 x 1]` (DesignA, DesignB) complex QPSK symbols.
  - `arch`: `'Legacy' | 'DesignA' | 'DesignB' | 'Jio'`.
  - Returns `grid` `[240 x 4 complex double]`, and `info` struct with `.pbchInd`, `.dmrsInd`, `.sssInd`, `.pssInd`.
- `demap_ssb_grid(grid, arch, N_ID_cell)`: extracts REs according to `arch`.

### M2 ↔ M3: Channel & Impairments Interface
- `apply_channel(txWave, tdlChan)`:
  - Input: `txWave` `[2200 x 1]`.
  - Output: `rxWave` `[2200 x 4]`, `pathGains`, `sampleTimes`.
- `apply_rf_impairments(rxWave, cfo_ppm, snr_dB, cfg)`:
  - Outputs: `noisyWave` `[2200 x 4]`, `nVar` (scalar noise variance per RE).
- `get_ideal_channel(tdlChan, pathGains, sampleTimes, carrier)`:
  - Output: `H_ideal` `[240 x 4 x 4]`.

### M3 ↔ M4: Transceiver Pipeline Interface
- `tx_pbch_chain(payload, arch, N_ID_cell, carrier)`:
  - Input: `payload` `[56 x 1 binary]`, `arch`, `N_ID_cell`, `carrier`.
  - Output: `txWave` `[2200 x 1]`, `grid` `[240 x 4]`, `info`.
- `rx_pbch_chain_full(rxWave, arch, tx_N_ID_cell, nVar, carrier)`:
  - Runs full Rx chain: PSS sync -> Demod -> SSS detect -> Channel Est -> MMSE MRC -> LLR Demap -> Polar Decode -> CRC Check.
  - Returns: `rxPayload` `[56 x 1]`, `crcErr` (0 or 1), `cellIdErr` (0 or 1), `H_est` `[240 x 4 x 4]`.

## Code Layout
```text
C:\workspace\nr_ics\
├── +nr_sim/
│   ├── +config/
│   │   ├── sim_config.m
│   │   └── channel_config.m
│   ├── +sequences/
│   │   ├── gen_PSSNR.m
│   │   ├── gen_SSS.m
│   │   ├── gen_ExtendedSSS.m
│   │   └── gen_PBCHDMRS.m
│   ├── +grid/
│   │   ├── map_ssb_grid.m
│   │   ├── demap_ssb_grid.m
│   │   └── plot_ssb_grid.m
│   ├── +tx/
│   │   └── tx_pbch_chain.m
│   ├── +channel/
│   │   ├── apply_channel.m
│   │   ├── apply_rf_impairments.m
│   │   ├── add_awgn.m
│   │   └── get_ideal_channel.m
│   ├── +rx/
│   │   ├── rx_sync_pss.m
│   │   ├── rx_detect_sss.m
│   │   ├── rx_channel_estimate.m
│   │   ├── rx_equalize_demap.m
│   │   └── rx_pbch_chain.m
│   └── +utils/
│       ├── calc_bler.m
│       └── calc_mse.m
├── tests/
│   ├── test_sequences.m
│   ├── test_pbch_chain.m
│   ├── test_grid_mapping.m
│   ├── test_channel.m
│   ├── test_e2e_tier1.m
│   ├── test_e2e_tier2.m
│   ├── test_e2e_tier3.m
│   ├── test_e2e_tier4.m
│   └── run_all_e2e_tests.m
├── figures/
│   ├── fig1_bler_pedestrian.png / .fig
│   ├── fig2_bler_vehicular.png / .fig
│   ├── fig3_mdr_comparison.png / .fig
│   ├── fig4_ch_est_mse.png / .fig
│   └── fig5_grid_allocation.png / .fig
├── main_run_simulation.m
└── plot_publication_figures.m
```
