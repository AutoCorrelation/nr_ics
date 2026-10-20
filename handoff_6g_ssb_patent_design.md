# Handoff: 6G (Rel-20) SSB Architecture Ideation & Standard-Essential Patent (SEP) Proposal

> **Target Session Purpose**: Formulating novel, patentable 6G (Rel-20) SSB (Synchronization Signal Block) design options with mathematical formalisms, 2D resource grid allocations, standard-essential patent (SEP) claims, and link-level validation using the verified MATLAB LLS codebase.

---

## 1. Suggested Skills for the Next Session

When initiating the new session, the agent should prioritize calling the following skills:
1. **`deep-research-consortium`** (Path: `C:\Users\i2coinslab\.gemini\config\skills\deep-research-consortium\SKILL.md`):
   - Use to orchestrate a 5-phase multi-agent research consortium (Problem Formulation -> Concurrency Divergence -> Validation & Semantic Clustering -> Blind Review & Patent Defense Consortium -> Final Curation).
   - Essential for generating defensible patent claims, identifying non-obvious technical distinctions over 3GPP RAN1 contributions, and conducting adversarial prior-art stress tests.
2. **`3gpp-tdoc-downloader`** (Path: `C:\Users\i2coinslab\.gemini\config\skills\3gpp-tdoc-downloader\SKILL.md`):
   - Use if additional RAN1 #124bis, #125, #126bis contributions (e.g. Ericsson, Samsung, Huawei, Apple) are needed for expanded prior-art benchmarking.
3. **`generative_ui`** (Path: `C:\Users\i2coinslab\.gemini\antigravity\builtin\skills\generative_ui\SKILL.md`):
   - Use for inline interactive visualization of proposed 2D time-frequency pilot grids, ambiguity functions, and patent claim hierarchy trees.

---

## 2. Executive Context & Verified Baseline

### 2.1 Standard Reference Baseline (3GPP RAN1 Agreed Common LLS Baseline)
- **Carrier Frequency**: $7\text{ GHz}$ (Primary 6G FR1-extension/FR3 anchor) & $2\text{ GHz}$ (TN/NTN)
- **Subcarrier Spacing (SCS)**: $30\text{ kHz}$ (Slot duration $0.5\text{ ms}$, FFT size 512, $f_s = 15.36\text{ MHz}$, 20 PRBs = 240 subcarriers)
- **Channel Model**: 3GPP TDL-C / CDL-C (RMS Delay Spread: $300\text{ ns}$ or $100\text{ ns}$)
- **Antenna Configuration**: 1T4R SIMO (Handheld UT Combination 2) with MRC combining (Optionally 2T4R precoder cycling)
- **Mobility Environments**: Pedestrian ($3\text{ km/h}$, $f_d \approx 19.4\text{ Hz}$) vs. High Vehicular ($120\text{ km/h}$, $f_d \approx 777.8\text{ Hz}$) vs. Extreme/NTN ($500 - 1000\text{ km/h}$)
- **Frequency Offsets**: Initial CFO $\pm 5\text{ ppm}$ or $\pm 20\text{ ppm}$ ($\pm 35 - 140\text{ kHz}$), Residual CFO $\pm 0.1\text{ ppm}$ ($\pm 700\text{ Hz}$)
- **PBCH Coding**: 56-bit payload ($K=56$: 32-bit MIB + 24-bit CRC-24C), 5G NR Polar Code, SCL List Decoding ($L=8$), mother code $N=512$.

### 2.2 Operational MATLAB Simulator in Workspace
A modular, publication-ready MATLAB simulator is fully implemented and verified in `C:\workspace\nr_ics\`:
- Core Package: `+nr_sim/` (`+config/`, `+sequences/`, `+grid/`, `+channel/`, `+rx/`, `+plots/`)
- Verification Suite: `tests/run_all_tests.m` (100% PASS across sequence, grid, channel, and transceiver chains)
- Company Benchmark Runner: `validate_company_matching.m`
- Master Monte-Carlo Runner: `main_run_simulation.m` (supports `'quick_demo'` and `'full_run'`)
- Generated Figures: `figures/` (`fig1_bler_pedestrian.png`, `fig2_bler_vehicular.png`, `fig3_mdr_comparison.png`, `fig4_ch_est_mse.png`, `fig5_grid_allocation.png`)

---

## 3. Prior-Art Landscape & Critical Technical Gaps

Based on extracted 3GPP RAN1#126 documents located in `c:\workspace\nr_ics\3gpp_Extracted\`:

| Company & TDoc | Proposed Architecture | Key Claimed Benefit | Unresolved Technical Bottleneck (Patent Opportunity) |
| :--- | :--- | :--- | :--- |
| **Qualcomm**<br>(R1-2606375) | **Design A**: 240 RE SSS @ Sym #2 (Concentrated). Zero dedicated DMRS.<br>**Design B**: Comb-3 SSS across Sym #1, 2, 3.<br>**Design C**: Comb-2 SSS across 2 symbols. | PBCH REs increase from 432 to 480 ($E=960$). Polar code rate drops from $R=0.0648$ to $R=0.0583$. Gives $\sim 0.8 - 0.95\text{ dB}$ gain at 1% BLER. | **Doppler Aging Breakdown**: Design A assumes Zero-Order Hold across time, which collapses at $120\text{ km/h}$ ($f_d \approx 778\text{ Hz}$). Design B incurs frequency-domain interpolation error in delay-dispersive channels due to $\Delta k = 3$ ($90\text{ kHz}$) spacing. |
| **MediaTek**<br>(R1-2606847) | **Comb-SSS wrap-240**: Interleaved Comb-SSS/PBCH multiplexing in 20 PRB / 22 PRB. | Single-shot MDR gain $\sim 2\text{ dB}$ at 10% MDR; $\sim 1\text{ dB}$ PBCH BLER gain. | Uniform comb subcarrier allocation lacks time-varying Doppler/CFO tracking and creates PAPR/cubic metric peaks when multiplexed with PBCH data. |
| **LG Electronics**<br>(R1-2605506) | **Extended SSS (240 RE Gold-255)** with 1-symbol concentrated DMRS vs. 4-symbol distributed DMRS (1/2 port TDM). | 240 RE SSS yields $>2\text{ dB}$ MDR gain; 1-symbol DMRS achieves $3.2 - 3.5\text{ dB}$ sequence detection gain. | High pilot overhead remains if dedicated DMRS is retained; 1-symbol DMRS cannot track channel aging across 4 symbols at 120–500 km/h. |
| **Jio Platforms**<br>(R1-2605419) | **SSS-Assisted Demodulation**: Combines Comb-4 DMRS with 127 RE SSS inside Phase-Coherence Window ($q_{CW}$). | Improves channel estimation SNR via pilot observation combining. | Still constrained by legacy 144 RE DMRS overhead; SSS pilots only cover the central 12 RBs, leaving outer RBs reliant on sparse DMRS. |
| **Huawei**<br>(R1-2605291 / R1-2606725) | **10-symbol Option 2 SSB**: PSS 4 symbols (144 RE), SSS 4 symbols (576 RE), PBCH with Comb-4 DMRS. | Ultra-high coverage for wide areas; memory-first buffer reduction. | Occupies 10 OFDM symbols (huge resource overhead, unsuitable for low-latency TDD slot formats or short transmission bursts). |

---

## 4. White-Space Patent Ideation Vectors for the Next Model

The successor reasoning model should focus on proposing novel SSB architectures that resolve the **triangular trade-off**:
$$\text{Maximal PBCH Data Capacity } (E \ge 480\text{ REs}) \iff \text{Time Tracking at Vehicular/NTN Speeds } (120-1000\text{ km/h}) \iff \text{Delay Spread Resilience } (\text{DS } \ge 300\text{ ns})$$

### Vector 1: Asymmetric Hexagonal-Staggered SSS Lattice with Phase-Tracking Pinhole Pilots
- **Concept**: Instead of uniform Comb-3 or single-symbol concentration, deploy an **asymmetric hexagonal pilot lattice** across the 3 PBCH symbols.
- **Mechanism**:
  - Symbol 1: Comb-4 SSS pilots at subcarriers $4m + 0$ (60 REs)
  - Symbol 2: Dense SSS core on center 12 RBs (120 REs) + Comb-4 SSS on outer RBs (24 REs) = 144 REs
  - Symbol 3: Comb-4 SSS pilots at subcarriers $4m + 2$ (60 REs)
  - Total SSS REs = $60 + 144 + 60 = 264\text{ REs}$ (or truncated to 240 REs).
- **Patent Claim Angle**: Diamond/hexagonal 2D interpolation minimizes the maximum 2D distance from any PBCH data RE to a pilot RE, delivering both time-tracking and frequency-delay resilience while maintaining $E \ge 480$ data REs.

### Vector 2: Dual-Polarized / Multi-Port Orthogonal SSS Reused as SFBC/Alamouti DMRS
- **Concept**: Qualcomm and MediaTek's SSS-as-DMRS only supports single-antenna (1Tx) transmission because standard SSS is a single scalar sequence.
- **Mechanism**:
  - Construct a dual-sequence orthogonal SSS pair $\{S_1(k), S_2(k)\}$ generated via complementary Gold sequences or orthogonal cyclic shifts ($\Delta \theta = \pi/2$ or orthogonal polyphase codes).
  - Port 0 transmits $S_1(k)$, Port 1 transmits $S_2(k)$ on Symbol 2 (or Comb-SSS).
  - During PSS/SSS cell search, UE non-coherently combines energy from both ports to detect Cell ID with full 2Tx spatial diversity gain.
  - During PBCH demodulation, the UE separates Port 0 and Port 1 channel responses $\hat{H}_0(k), \hat{H}_1(k)$ to perform 2Tx Space-Frequency Block Coding (SFBC / Alamouti) decoding without any dedicated DMRS!
- **Patent Claim Angle**: First SSS-as-DMRS structure that simultaneously enables 2Tx transmit diversity for both initial synchronization acquisition and PBCH SFBC decoding.

### Vector 3: Decoupled Hierarchical PBCH (Chase-Combinable Invariant Core + SSS-Phase-Modulated SFN)
- **Concept**: In 5G NR, SFN changes every 10 ms, preventing inter-period soft combining across 40–160 ms bursts for energy-saving IoT/coverage-limited UEs.
- **Mechanism**:
  - Decouple PBCH into a static 48-bit core (MIB) and an 8-bit dynamic timing state (SFN).
  - The 48-bit core is static across multi-second windows, rate-matched into 480 REs, enabling cross-burst Chase combining (up to 4–6 dB gain for coverage enhancement).
  - The dynamic SFN / SSB-index is modulated onto the **global phase rotation or cyclic shift of the 240 RE Extended SSS sequence** ($\tilde{S}(k) = S(k) e^{j \frac{2\pi}{M} m \cdot k}$).
- **Patent Claim Angle**: Method and apparatus for conveying timing parameters via SSS sequence phase modulation to enable infinite-horizon Chase combining of PBCH data payloads.

### Vector 4: Superimposed Low-Power Complex-Scrambled Pilot Overlay (Zero-Overhead PBCH)
- **Concept**: Eliminating pilot subcarriers entirely by superimposing a low-power pseudo-random sequence across 100% of the PBCH data REs (analogous to spread-spectrum overlay).
- **Mechanism**:
  - PBCH data occupies all $3 \times 240 = 720\text{ REs}$ (Polar rate drops to $R \approx 0.0388$).
  - A known pseudo-random sequence is superimposed with power ratio $\alpha \approx -10\text{ dB}$ to $-14\text{ dB}$.
  - Receiver performs iterative 2D channel estimation and soft interference cancellation (SIC).

---

## 5. Instructions for the Next Agent

1. **Review Reference Files in Workspace**:
   - `C:\workspace\nr_ics\3gpp_Extracted\R1-2606375_Synchronization acquisition and beam measurement_Qualcomm Incorporated.docx`
   - `C:\workspace\nr_ics\3gpp_Extracted\R1-2606847_Views on synchronization acquisition and beam measurement_MediaTek Inc.docx`
   - `C:\workspace\nr_ics\3gpp_Extracted\R1-2605506_Discussion on Synchronization acquisition and beam measurement for 6GR_LG Electronics.docx`
   - `C:\workspace\nr_ics\+nr_sim\+grid\map_ssb_grid.m` (2D grid mapping interfaces)
   - `C:\workspace\nr_ics\+nr_sim\+rx\rx_channel_estimate.m` (Channel estimation interfaces)
   - `C:\workspace\nr_ics\main_run_simulation.m` (Monte-Carlo runner)

2. **Formulate Novel Architecture**:
   - Select 1 or 2 high-potential design vectors from Section 4.
   - Formulate exact mathematical expressions: sequence polynomials, subcarrier index formulas $k(m, l)$, power allocation $\beta$, and 2D interpolation equations.

3. **Implement & Validate in MATLAB**:
   - Add new architecture identifiers (e.g., `'NovelDesignHex'`, `'NovelDesignAlamouti'`) into `map_ssb_grid.m` and `rx_channel_estimate.m`.
   - Run `main_run_simulation.m` to generate comparative BLER and MSE curves against Qualcomm Design A and MediaTek Comb-SSS.
   - Confirm that the proposed design achieves lower BLER at $120\text{ km/h}$ than Design A while outperforming Legacy NR at $3\text{ km/h}$.

4. **Draft Patent Proposal Artifact**:
   - Title of Invention
   - Technical Field & Background Art
   - Deficiencies of Existing 3GPP Rel-20 Proposals (Qualcomm, MediaTek, LGE)
   - Detailed Technical Description with Math & Diagrams
   - Independent and Dependent Patent Claims (Method claim, Apparatus claim, UE claim, Base Station claim).
