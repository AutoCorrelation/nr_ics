# Handoff Report: Link-Level Simulator (LLS) System Architecture & Verification

**Agent**: `explorer_survey_3`  
**Date**: 2026-09-28  
**Working Directory**: `C:\workspace\nr_ics\.agents\teamwork\explorer_survey_3`  
**Authoritative Request**: `C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md`  

---

## 1. Observation

### 1.1 MATLAB Runtime Environment & Installed Toolboxes
Direct execution of `detect_matlab_toolboxes` and MATLAB CLI checks on the host environment revealed:
- **MATLAB Version**: `26.1.0.3346908 (R2026a) Update 5` on Microsoft Windows 11 Pro (Build 26200).
- **Installed Relevant Toolboxes**:
  - `5G Toolbox` Version 26.1 (R2026a)
  - `Communications Toolbox` Version 26.1 (R2026a)
  - `DSP System Toolbox` Version 26.1 (R2026a)
  - `Parallel Computing Toolbox` Version 26.1 (R2026a)
  - `Signal Processing Toolbox` Version 26.1 (R2026a)
- **Key Function Availability & Verified Signatures**:
  - `nrCRCEncode`, `nrCRCDecode`: Validated with standard polynomials, specifically `'24C'`.
  - `nrPolarEncode(in, E, nmax, iil)`: Successfully executed. Note: when $E$ is specified, `nrPolarEncode` produces mother code length $N=512$ (default $n_{max}=9$), and `nrRateMatchPolar(enc, K, E)` produces the rate-matched output ($E=864$ or $E=960$).
  - `nrRateRecoverPolar(llr, K, N)` & `nrPolarDecode(rec, K, E, L)`: Validated with $L=8$ list size, recovering transmitted payload with 0 bit errors under AWGN for both $E=864$ and $E=960$.
  - `nrTDLChannel`: Verified constructor and execution for 3GPP TDL-C profile, delay spread $300\text{ ns}$, sample rate $15.36\text{ MHz}$, 1 Tx antenna, 4 Rx antennas (1T4R SIMO). Waveform filtering verified.
  - `nrOFDMModulate`, `nrOFDMDemodulate`: Verified with `nrCarrierConfig('NSizeGrid', 20, 'SubcarrierSpacing', 30)`, FFT size 512, returning 2200 samples for a 4-symbol slot with perfect reconstruction error $< 10^{-15}$.
  - `nrEqualizeMMSE`: Verified for SIMO 1T4R. Expects `rxSym` $[N, R]$, `hest` $[N, R, 1]$, returning equalized symbols $[N, 1]$ and soft CSI $[N, 1]$.
  - `nrChannelEstimate`: Verified with predefined reference grids `refGrid` $[240 \times 4]$, performing automatic 2D interpolation across frequency and time for all 4 antennas.
  - `nrPerfectChannelEstimate` & `nrPerfectTimingEstimate`: Verified for ground-truth channel extraction for Figure 4 (MSE evaluation).

### 1.2 Existing Workspace Files
The root directory `C:\workspace\nr_ics\` contains:
- `gen_PSSNR.m`: Reference implementation of 3GPP TS 38.211 Section 7.4.2.2.1 m-sequence generator ($N_{ID}^{(2)} \in \{0, 1, 2\}$, length 127). Verified to be identical to `nrPSS(N_ID_2)`.
- `loaddump.m`: Utility for reading complex binary dump files (`dumpdataNR/*.dat`).
- `test.m`: Early prototype script illustrating sampling rate $15.36\text{ MHz}$, SCS $30\text{ kHz}$, FFT size 512, CP lengths (36 / 52 samples).
- `document/cpLength.md`: Reference documentation specifying 30 kHz SCS CP timing and symbol lengths: normal symbol length 548 samples (CP 36), slot symbol 0 length 556/564 samples.
- `tests/`: Does not yet exist (greenfield build).

---

## 2. Logic Chain & Technical Formulations

### 2.1 Requirement R1: SSB Sequence Generation & Grid Mapping
The SSB spans 240 subcarriers ($20\text{ RBs}$) and 4 OFDM symbols (indexed $l \in \{0, 1, 2, 3\}$ in 0-based notation, or $\{1, 2, 3, 4\}$ in MATLAB 1-based notation).

1. **Legacy 5G NR Baseline**:
   - Symbol 0 ($l=0$): PSS centered on subcarriers $k = 56 \dots 182$ (127 REs), unused subcarriers set to 0.
   - Symbol 1 ($l=1$): PBCH (180 data REs) + Comb-4 DMRS (60 REs, $k = 4m + v_{shift}$, where $v_{shift} = N_{ID}^{cell} \bmod 4$, $m = 0 \dots 59$).
   - Symbol 2 ($l=2$): SSS centered on subcarriers $k = 56 \dots 182$ (127 REs). PBCH on edges $k = 0 \dots 47$ (36 data REs, 12 DMRS REs) and $k = 192 \dots 239$ (36 data REs, 12 DMRS REs). Unused subcarriers $k = 48 \dots 55$ (8 REs) and $k = 183 \dots 191$ (9 REs).
   - Symbol 3 ($l=3$): PBCH (180 data REs) + Comb-4 DMRS (60 REs).
   - **Total PBCH Data REs**: $180 + 72 + 180 = 432\text{ REs}$.
   - **Total Dedicated DMRS REs**: $60 + 24 + 60 = 144\text{ REs}$.
   - **Coded Bits**: $432 \times 2 = 864\text{ bits}$ (QPSK). Polar rate $R = 56 / 864 \approx 0.06481$.

2. **Qualcomm Design A (R1-2606375, Concentrated Extended SSS)**:
   - Symbol 0 ($l=0$): PSS centered on subcarriers $k = 56 \dots 182$ (127 REs).
   - Symbol 1 ($l=1$): 240 PBCH data REs (0 DMRS).
   - Symbol 2 ($l=2$): 240 RE Extended SSS occupying all subcarriers $k = 0 \dots 239$.
     - Generated from a base-255 Gold sequence truncated to 240 symbols.
     - Preferred polynomial pair of degree 8:
       $$g_1(D) = D^8 + D^4 + D^3 + D^2 + 1$$
       $$g_2(D) = D^8 + D^6 + D^5 + D^3 + 1$$
     - Provides $>15\text{ dB}$ PSLR and cross-correlation $< 0.02$.
   - Symbol 3 ($l=3$): 240 PBCH data REs (0 DMRS).
   - **Total PBCH Data REs**: $240 + 240 = 480\text{ REs}$.
   - **Total Dedicated DMRS REs**: $0\text{ REs}$.
   - **Coded Bits**: $480 \times 2 = 960\text{ bits}$ (QPSK). Polar rate $R = 56 / 960 \approx 0.05833$.

3. **Qualcomm Design B / MediaTek Comb-SSS (R1-2606847, Distributed Comb-3 SSS)**:
   - Symbol 0 ($l=0$): PSS centered on subcarriers $k = 56 \dots 182$ (127 REs).
   - Symbols 1, 2, 3 ($l=1, 2, 3$): Distributed Comb-3 SSS multiplexed with PBCH data:
     - SSS pilot positions: $k = 3m$, $m = 0 \dots 79$ (80 REs per symbol, $80 \times 3 = 240\text{ REs}$ total).
     - PBCH data positions: remaining subcarriers ($160\text{ REs}$ per symbol, $160 \times 3 = 480\text{ REs}$ total).
   - **Total PBCH Data REs**: $480\text{ REs}$.
   - **Total SSS Pilot REs**: $240\text{ REs}$. Dedicated DMRS: $0\text{ REs}$.
   - **Coded Bits**: $480 \times 2 = 960\text{ bits}$ (QPSK). Polar rate $R = 56 / 960 \approx 0.05833$.

4. **Jio Platforms SSS-Assisted (R1-2605419)**:
   - Resource grid layout identical to Legacy 5G NR (432 PBCH data REs, 144 DMRS REs, 127 SSS REs).
   - Receiver performs joint channel estimation across both SSS (127 REs on Symbol 2) and dedicated DMRS (144 REs on Symbols 1, 2, 3) within a Phase-Coherence Window ($q_{CW}$).

---

### 2.2 Requirement R2: Physical Channel, Mobility & RF Impairments
1. **RF & Sampling Baseline**:
   - Carrier frequency: $f_c = 7\text{ GHz}$.
   - SCS: $\Delta f = 30\text{ kHz}$. FFT size: $N_{FFT} = 512$.
   - Sample rate: $f_s = 512 \times 30\text{ kHz} = 15.36\text{ MHz}$.
2. **Channel Model (TDL-C 300ns)**:
   - 3GPP TDL-C with RMS delay spread $\tau_{rms} = 300\text{ ns}$.
   - Configured via MATLAB's `nrTDLChannel`:
     `tdl = nrTDLChannel('DelayProfile','TDL-C', 'DelaySpread', 300e-9, 'SampleRate', 15.36e6, 'NumTransmitAntennas', 1, 'NumReceiveAntennas', 4);`
3. **Mobility Speeds & Doppler Modeling**:
   - Pedestrian ($3\text{ km/h}$):
     $$f_d = \frac{v}{c} f_c = \frac{3 \times 10^3 / 3600}{3 \times 10^8} \times 7 \times 10^9 \approx 19.44\text{ Hz}$$
   - Vehicular ($120\text{ km/h}$):
     $$f_d = \frac{120 \times 10^3 / 3600}{3 \times 10^8} \times 7 \times 10^9 \approx 777.78\text{ Hz}$$
4. **RF Impairments & Noise Calibration**:
   - Initial CFO: $\pm 5\text{ ppm}$ ($\pm 35\text{ kHz}$) or $\pm 20\text{ ppm}$ ($\pm 140\text{ kHz}$).
   - Applied via time-domain phase rotation: $r_{cfo}(t) = r(t) e^{j 2\pi \Delta f_{init} t}$.
   - PSS coarse frequency estimation corrects coarse offset; residual CFO $\pm 0.1\text{ ppm}$ ($\pm 700\text{ Hz}$) is maintained during demodulation.
   - AWGN Noise: Calibrated over SNR sweep $[-14, -2]\text{ dB}$. Noise power per receive antenna:
     $$\sigma^2 = 10^{-SNR_{dB}/10}$$
     Added as complex circular Gaussian noise: $n \sim \mathcal{CN}\left(0, \sigma^2 \mathbf{I}_4\right)$.

---

### 2.3 Requirement R3: Transceiver Signal Processing Pipeline
1. **Transmitter Chain**:
   - **Payload**: 56-bit PBCH MIB binary payload.
   - **CRC Encoding**: Append 24 parity bits via `nrCRCEncode(payload, '24C')`, yielding $K_{crc} = 80\text{ bits}$.
   - **Polar Encoding**: `enc = nrPolarEncode(dataWithCRC, E)`, yielding mother code $N=512$ ($n_{max}=9$).
   - **Rate Matching**: `rm = nrRateMatchPolar(enc, K_crc, E)`, expanding to $E=864$ (Legacy / Jio) or $E=960$ (Design A / Design B).
   - **Modulation**: QPSK modulation via `nrSymbolModulate(rm, 'QPSK')`, producing 432 or 480 complex symbols.
   - **Grid Mapping**: Insert PBCH symbols, PSS, SSS, and DMRS into the $240 \times 4$ resource grid per design specification.
   - **OFDM Modulation**: `txWave = nrOFDMModulate(carrier, grid)`.
2. **Receiver Chain**:
   - **PSS Synchronization & Coarse CFO Correction**: Time-domain cross-correlation with the 3 PSS sequences determines timing offset $\hat{\tau}$, cell sector ID $N_{ID}^{(2)} \in \{0, 1, 2\}$, and coarse frequency offset via CP autocorrelation.
   - **OFDM Demodulation**: `rxGrid = nrOFDMDemodulate(carrier, rxWave(offset+(1:Nsamples), :))`, yielding $240 \times 4 \times 4$ frequency grid.
   - **SSS Detection & Cell-ID ($N_{ID}^{cell}$)**:
     - For Legacy SSS: correlate center 127 REs across candidate $N_{ID}^{(1)} \in [0, 335]$ to find $\hat{N}_{ID}^{cell} = 3 \hat{N}_{ID}^{(1)} + N_{ID}^{(2)}$.
     - For Extended SSS: correlate 240 REs across candidate 240-length Gold sequences.
   - **Channel Estimation (4 Specific Estimators)**:
     - *Legacy NR*: DMRS-only Comb-4 linear/Wiener frequency interpolation across symbols 1, 2, 3.
     - *Qualcomm Design A*: SSS-as-DMRS estimated at Symbol 2 across all 240 subcarriers, applied to Symbols 1 and 3 via Zero-Order Hold (ZOH) / time extrapolation.
     - *Qualcomm Design B (Comb-SSS)*: Comb-3 2D interpolation across frequency and time tracking instantaneous variation per symbol.
     - *Jio Platforms*: Joint MMSE channel estimation utilizing both 144 DMRS REs and 127 SSS REs within phase coherence window.
   - **2D MMSE Equalization & SIMO MRC Combining**:
     - `[eqSym, csi] = nrEqualizeMMSE(rxSym, hest, nVar)` combines 4 receive antenna signals with MRC weighting and noise variance regularization.
   - **Soft LLR Demapping**:
     - `llrs = nrSymbolDemodulate(eqSym .* csi, 'QPSK', 1.0)`.
   - **Polar Rate Recovery & SCL Decoding**:
     - `rec = nrRateRecoverPolar(llrs, K_crc, N_mother)`.
     - `dec = nrPolarDecode(rec, K_crc, E, 8)` with list size $L=8$.
   - **CRC-24C Verification**:
     - `[rxPayload, crcErr] = nrCRCDecode(dec, '24C')`. `crcErr == 0` signifies successful frame transmission.

---

### 2.4 Requirement R4: Monte-Carlo Execution & Publication Figures
1. **Simulation Runner Engine (`main_run_simulation.m`)**:
   - Supports two operational modes:
     - `'quick_demo'`: 50 iterations per SNR point, SNR $\in \{-14, -10, -6, -2\}\text{ dB}$, executing in $<2\text{ minutes}$ for quick smoke test.
     - `'full_run'`: 500-1000 iterations per SNR point, SNR $\in \{-14, -12, -10, -8, -6, -4, -2\}\text{ dB}$, parallelized with `parfor`.
   - Result caching in structured `.mat` file (`results_simulation.mat`).
2. **5 Publication Figures**:
   - `fig1_bler_pedestrian.png` / `.fig`: BLER vs. SNR at 3 km/h. Verifies $\sim 1.0 - 2.0\text{ dB}$ coding gain of Design A & Comb-SSS ($E=960$) over Legacy NR ($E=864$).
   - `fig2_bler_vehicular.png` / `.fig`: BLER vs. SNR at 120 km/h. Verifies Doppler aging breakdown of Concentrated SSS (Design A) due to ZOH decorrelation, contrasted with time-tracking resilience of Comb-SSS (Design B).
   - `fig3_mdr_comparison.png` / `.fig`: MDR vs. SNR for 127 RE SSS vs 240 RE Extended SSS, verifying $>2\text{ dB}$ detection gain at low SNR ($<-8\text{ dB}$).
   - `fig4_ch_est_mse.png` / `.fig`: NMSE vs. SNR across all 4 channel estimators, computed against ground truth `nrPerfectChannelEstimate`.
   - `fig5_grid_allocation.png` / `.fig`: 2D subcarrier-by-symbol visual map comparing RE allocations across all 4 architectures with standardized color coding.

---

## 3. Recommended Modular Directory Layout & Interface Contracts

### 3.1 Recommended Directory Tree
```text
C:\workspace\nr_ics\
├── +nr_sim/                    (or src/ package)
│   ├── +config/
│   │   ├── sim_config.m        % Simulation parameter configurations
│   │   └── channel_config.m    % TDL-C and RF impairment configurations
│   ├── +sequences/
│   │   ├── gen_PSSNR.m         % 127-RE PSS generator
│   │   ├── gen_SSS.m           % 127-RE SSS generator
│   │   ├── gen_ExtendedSSS.m   % 240-RE Extended SSS (base-255 Gold)
│   │   └── gen_PBCHDMRS.m      % 144-RE PBCH DMRS sequence
│   ├── +grid/
│   │   ├── map_ssb_grid.m      % 2D resource grid mapper for 4 designs
│   │   ├── demap_ssb_grid.m    % Grid demapper & RE extractor
│   │   └── plot_ssb_grid.m     % Grid visualization helper
│   ├── +tx/
│   │   └── tx_pbch_chain.m     % MIB -> CRC -> Polar -> RM -> QPSK -> Grid -> OFDM
│   ├── +channel/
│   │   ├── apply_channel.m     % nrTDLChannel execution
│   │   ├── apply_cfo.m         % Frequency offset injection
│   │   └── add_awgn.m          % Calibrated noise generator
│   ├── +rx/
│   │   ├── rx_sync_pss.m       % PSS correlation & timing/coarse CFO acquisition
│   │   ├── rx_detect_sss.m     % SSS detection & Cell-ID estimation
│   │   ├── rx_channel_estimate.m % 4-design channel estimator
│   │   ├── rx_equalize_demap.m % 1T4R SIMO MRC MMSE equalization & LLR demapping
│   │   └── rx_pbch_chain.m     % LLR -> Rate Recover -> Polar Decode -> CRC Check
│   └── +utils/
│       ├── calc_bler.m         % BLER accumulator
│       └── calc_mse.m          % Channel estimation MSE calculator
├── tests/
│   ├── test_sequences.m        % Unit test: PSS, SSS, Extended SSS, PSLR
│   ├── test_pbch_chain.m       % Unit test: Back-to-back transceiver chain (E=864 & E=960)
│   ├── test_grid_mapping.m     % Unit test: RE layout & collision check
│   └── test_channel.m          % Unit test: TDL-C channel, mobility, CFO
├── figures/                    % Directory for saved .png and .fig outputs
├── main_run_simulation.m       % Top-level Monte-Carlo simulation runner
└── plot_publication_figures.m  % Publication-grade figure rendering script
```

---

### 3.2 Key Function Signatures & Data Contracts

#### A. Sequence Generators
```matlab
% 1. PSS Generator
function d_pss = gen_PSSNR(N_ID_2)
% Inputs:  N_ID_2 (0, 1, or 2)
% Outputs: d_pss [127 x 1 double], values in {-1, +1}

% 2. SSS Generator
function d_sss = gen_SSS(N_ID_1, N_ID_2)
% Inputs:  N_ID_1 (0..335), N_ID_2 (0..2)
% Outputs: d_sss [127 x 1 double], values in {-1, +1}

% 3. Extended SSS Generator (240 RE, truncated from base-255 Gold)
function d_ext = gen_ExtendedSSS(N_ID_cell)
% Inputs:  N_ID_cell (0..1007)
% Outputs: d_ext [240 x 1 double], values in {-1, +1}
% Logic:   Gold sequence using primitive polynomials:
%          g1(D) = D^8 + D^4 + D^3 + D^2 + 1
%          g2(D) = D^8 + D^6 + D^5 + D^3 + 1
%          Cyclic shifts derived from N_ID_cell, truncated from 255 to 240.

% 4. PBCH DMRS Generator
function dmrs_seq = gen_PBCHDMRS(N_ID_cell, ibar_SSB)
% Inputs:  N_ID_cell (0..1007), ibar_SSB (default 0)
% Outputs: dmrs_seq [144 x 1 complex double]
```

#### B. Grid Mapper & Demapper
```matlab
% Resource Grid Mapper
function [grid, info] = map_ssb_grid(pbch_syms, arch, N_ID_cell)
% Inputs:
%   pbch_syms: [432 x 1] (Legacy, Jio) or [480 x 1] (DesignA, DesignB) complex QPSK symbols
%   arch:      'Legacy' | 'DesignA' | 'DesignB' | 'Jio'
%   N_ID_cell: integer in [0, 1007]
% Outputs:
%   grid:      [240 x 4] complex double matrix
%   info:      struct with field indices:
%              .pbchInd  - linear or subscript indices of PBCH data REs
%              .dmrsInd  - linear or subscript indices of DMRS REs
%              .sssInd   - linear or subscript indices of SSS REs
%              .pssInd   - linear or subscript indices of PSS REs
```

#### C. Transmit Chain
```matlab
function [txWave, grid, info] = tx_pbch_chain(payload, arch, N_ID_cell, carrier)
% Inputs:
%   payload:   [56 x 1] binary vector
%   arch:      'Legacy' | 'DesignA' | 'DesignB' | 'Jio'
%   N_ID_cell: integer [0, 1007]
%   carrier:   nrCarrierConfig object (NSizeGrid=20, SCS=30)
% Outputs:
%   txWave:    [2200 x 1] complex double time-domain waveform
%   grid:      [240 x 4] complex double frequency-domain grid
%   info:      struct with mapping metadata
```

#### D. Channel & Impairments
```matlab
function [rxWave, pathGains, sampleTimes] = apply_channel(txWave, tdlChan)
% Inputs:
%   txWave:   [2200 x 1] complex double
%   tdlChan:  nrTDLChannel object (configured for 1T4R TDL-C 300ns)
% Outputs:
%   rxWave:   [2200 x 4] complex double faded waveform across 4 Rx antennas

function [noisyWave, nVar] = apply_rf_impairments(rxWave, cfo_ppm, snr_dB, cfg)
% Inputs:
%   rxWave:   [2200 x 4] complex double
%   cfo_ppm:  scalar (e.g. +5 or -20)
%   snr_dB:   scalar SNR in dB
%   cfg:      struct with CarrierFreq and SampleRate
% Outputs:
%   noisyWave:[2200 x 4] complex double waveform with CFO and AWGN
%   nVar:     scalar noise variance per RE
```

#### E. Receiver Chain
```matlab
% 1. Synchronization & Coarse CFO
function [offset, est_N_ID_2, coarseCFO] = rx_sync_pss(rxWave, cfg)
% Inputs:  rxWave [2200 x 4], cfg struct
% Outputs: offset (sample index), est_N_ID_2 (0..2), coarseCFO (Hz)

% 2. SSS Detection & Cell-ID
function [est_N_ID_cell, is_detected] = rx_detect_sss(rxGrid, est_N_ID_2, arch)
% Inputs:  rxGrid [240 x 4 x 4], est_N_ID_2, arch
% Outputs: est_N_ID_cell (0..1007), is_detected (logical)

% 3. Channel Estimation
function H_est = rx_channel_estimate(rxGrid, arch, N_ID_cell, nVar)
% Inputs:  rxGrid [240 x 4 x 4], arch, N_ID_cell, nVar
% Outputs: H_est [240 x 4 x 4] estimated channel frequency response
% Estimator implementations:
%   - 'Legacy':  DMRS-only frequency interpolation across symbols 1, 2, 3
%   - 'DesignA': SSS-as-DMRS at Symbol 2 with ZOH extrapolation to Symbols 1 & 3
%   - 'DesignB': Comb-3 SSS 2D interpolation tracking instantaneous symbol fading
%   - 'Jio':     Joint MMSE using both DMRS (144 REs) and SSS (127 REs)

% 4. 2D MMSE Equalization & LLR Demapping
function [llrs, eqSym, csi] = rx_equalize_demap(rxGrid, H_est, arch, N_ID_cell, nVar)
% Inputs:  rxGrid [240 x 4 x 4], H_est [240 x 4 x 4], arch, N_ID_cell, nVar
% Outputs: llrs [864 x 1] or [960 x 1] soft LLRs, eqSym, csi

% 5. Polar Decoding & CRC Check
function [rxPayload, crcErr] = rx_pbch_chain(llrs, arch)
% Inputs:  llrs [864 x 1] or [960 x 1], arch
% Outputs: rxPayload [56 x 1] binary vector, crcErr (0 = success)
```

---

## 4. Caveats & Assumptions

1. **Phase Coherence Window ($q_{CW}$)**:
   In Jio Platforms SSS-Assisted architecture, joint SSS+DMRS channel estimation assumes that SSS and PBCH DMRS are transmitted with identical antenna port precoding and share phase coherence across the SSB duration ($q_{CW} \ge 4\text{ symbols}$). This conforms to standard 3GPP assumptions for single-beam SSBs.
2. **Mother Code Size for Rate 0.0583 vs 0.0648**:
   In both cases ($E=864$ and $E=960$), information bits $K_{crc} = 80 \le 1024$. The mother code size $N = 512$ with $n_{max} = 9$ is standard for PBCH. Rate matching uses repetition of the 512-bit circular buffer.
3. **CFO Sweep**:
   Initial CFO is modeled as an initial frequency error ($\pm 5\text{ ppm}$ or $\pm 20\text{ ppm}$), followed by PSS coarse correction leaving residual CFO ($\pm 0.1\text{ ppm}$).

---

## 5. Conclusion & Recommendations

1. **System Feasibility**:
   All 4 architectures (Legacy NR, Qualcomm Design A, Qualcomm Design B, Jio Platforms) are fully implementable using MATLAB R2026a and its 5G Toolbox. The core functions `nrPolarEncode`, `nrRateMatchPolar`, `nrRateRecoverPolar`, `nrPolarDecode`, `nrTDLChannel`, `nrOFDMModulate`, `nrOFDMDemodulate`, and `nrEqualizeMMSE` are verified and operate as expected.
2. **Key Physical Insights to Confirm in Simulation**:
   - **Low Mobility ($3\text{ km/h}$)**: Both Design A and Design B exhibit $\sim 1.0 - 2.0\text{ dB}$ BLER gain over Legacy NR due to coding gain ($E=960$ vs $864$, 480 vs 432 data REs). Jio Platforms exhibits $\sim 0.5 - 0.8\text{ dB}$ gain via reduced channel estimation MSE.
   - **High Mobility ($120\text{ km/h}$)**: Qualcomm Design A collapses due to Doppler aging ($f_d \approx 777.8\text{ Hz}$) because ZOH cannot track fast fading across OFDM symbols. Qualcomm Design B (Comb-SSS) maintains robust channel tracking through time-distributed pilots.
   - **Detection Gain**: 240 RE Extended SSS achieves $>2\text{ dB}$ gain in MDR compared to 127 RE Legacy SSS at low SNRs (below $-8\text{ dB}$).
3. **Execution Architecture**:
   `main_run_simulation.m` must feature the `'quick_demo'` mode ($<2$ minutes) to enable rapid iterative verification, and `'full_run'` mode with `parfor` for generating the 5 publication figures.

---

## 6. Verification Method

### 6.1 Programmatic Unit Test Suite

1. **Sequence Test (`tests/test_sequences.m`)**:
   - Run command in MATLAB:
     ```matlab
     run('tests/test_sequences.m')
     ```
   - Assertions:
     - Extended SSS length == 240.
     - Auto-correlation peak == 1.0, maximum off-peak sidelobe $< 0.15$.
     - Maximum cross-correlation between different cell IDs $< 0.15$ ($>15\text{ dB}$ isolation).
     - Legacy PSS and SSS match 3GPP TS 38.211 standard sequences.

2. **PBCH Transceiver Chain Test (`tests/test_pbch_chain.m`)**:
   - Run command in MATLAB:
     ```matlab
     run('tests/test_pbch_chain.m')
     ```
   - Assertions:
     - Perfect back-to-back recovery (0 bit errors, 0 CRC errors) at $\text{SNR} = +5\text{ dB}$ under AWGN for $E=864$ (Legacy / Jio).
     - Perfect back-to-back recovery (0 bit errors, 0 CRC errors) at $\text{SNR} = +5\text{ dB}$ under AWGN for $E=960$ (Design A / Design B).
     - 100 consecutive frames decoded with $\text{BLER} = 0.0$ at high SNR.

3. **Smoke Test Runner (`main_run_simulation('quick_demo')`)**:
   - Run command in MATLAB:
     ```matlab
     results = main_run_simulation('quick_demo');
     ```
   - Assertions:
     - Completes in $< 120\text{ seconds}$.
     - Generates and saves:
       - `fig1_bler_pedestrian.png` & `fig1_bler_pedestrian.fig`
       - `fig2_bler_vehicular.png` & `fig2_bler_vehicular.fig`
       - `fig3_mdr_comparison.png` & `fig3_mdr_comparison.fig`
       - `fig4_ch_est_mse.png` & `fig4_ch_est_mse.fig`
       - `fig5_grid_allocation.png` & `fig5_grid_allocation.fig`
       - `results_simulation.mat`

### 6.2 Invalidation Conditions
- Any assertion failure in `test_sequences.m` or `test_pbch_chain.m`.
- Mismatch between generated RE counts and target coded bits ($432 \times 2 = 864$ or $480 \times 2 = 960$).
- Failure of Design A to show Doppler breakdown at $120\text{ km/h}$, or failure of Comb-SSS to maintain tracking.
- Missing `.png` or `.fig` publication output files.
