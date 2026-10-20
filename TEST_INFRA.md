# E2E Test Infra: 3GPP Rel-20 / 6G Link-Level Simulator (LLS)

## Test Philosophy
- Opaque-box, requirement-driven. Derived strictly from `ORIGINAL_REQUEST.md` and 3GPP standards without relying on internal private structures.
- Methodology: 4-tier systematic approach (Category-Partition, Boundary Value Analysis, Pairwise Combinatorial Testing, Real-World Workload Testing).

## Feature Inventory & Test Coverage
| # | Feature | Requirement Source | Tier 1 (Feature) | Tier 2 (Boundary) | Tier 3 (Pairwise) | Tier 4 (Scenario) |
|---|---------|-------------------|:----------------:|:-----------------:|:-----------------:|:-----------------:|
| 1 | Legacy PSS & SSS Generation | TS 38.211 §7.4.2 | 5 cases | 5 cases | ✓ | ✓ |
| 2 | Extended SSS Generation (240 RE) | R1-2606375 | 5 cases | 5 cases | ✓ | ✓ |
| 3 | PBCH DMRS Generation (144 RE) | TS 38.211 §7.4.3 | 5 cases | 5 cases | ✓ | ✓ |
| 4 | Legacy 5G NR Grid (432 Data RE, E=864) | TS 38.211 §7.4.3 | 5 cases | 5 cases | ✓ | ✓ |
| 5 | Design A Grid (480 Data RE, E=960) | R1-2606375 | 5 cases | 5 cases | ✓ | ✓ |
| 6 | Design B Comb-SSS Grid (480 Data RE, E=960) | R1-2606847 | 5 cases | 5 cases | ✓ | ✓ |
| 7 | Jio Platforms Grid (q_CW SSS-assisted) | R1-2605419 | 5 cases | 5 cases | ✓ | ✓ |
| 8 | 3GPP TDL-C 300ns 1T4R Channel | TS 38.101-4 | 5 cases | 5 cases | ✓ | ✓ |
| 9 | Pedestrian (3 km/h) & Vehicular (120 km/h) | RAN1 Baseline | 5 cases | 5 cases | ✓ | ✓ |
| 10 | RF CFO (Initial/Residual) & AWGN noise | TS 38.101-4 | 5 cases | 5 cases | ✓ | ✓ |
| 11 | PBCH Tx Chain (MIB -> Polar -> QPSK -> OFDM) | TS 38.212 | 5 cases | 5 cases | ✓ | ✓ |
| 12 | Rx PSS Timing & Coarse CFO Synchronization | TS 38.211 | 5 cases | 5 cases | ✓ | ✓ |
| 13 | Rx SSS Cell-ID Detection | RAN1 #125 | 5 cases | 5 cases | ✓ | ✓ |
| 14 | 4 Channel Estimators (DMRS, ZOH, Comb-3, Joint) | Rel-20 Proposals | 5 cases | 5 cases | ✓ | ✓ |
| 15 | 2D MMSE & 1T4R SIMO MRC Equalization | Baseline SIMO | 5 cases | 5 cases | ✓ | ✓ |
| 16 | Polar Rate Recovery (N=512) & SCL Decoding (L=8) | TS 38.212 | 5 cases | 5 cases | ✓ | ✓ |
| 17 | Monte-Carlo Execution & Results Caching | Acceptance Criteria | 5 cases | 5 cases | ✓ | ✓ |
| 18 | 5 Publication Figures (.png and .fig) | Acceptance Criteria | 5 cases | 5 cases | ✓ | ✓ |

## Test Architecture
- **Master Runner**: `tests/run_all_e2e_tests.m`
  - Runs all test tiers, collects results, prints structured pass/fail table.
  - Returns exit code 0 on all tests pass, non-zero on any failure.
- **Test Scripts**:
  - `tests/test_sequences.m`: Required Unit Test 1 (Sequence lengths, auto-corr peak, PSLR $>15\text{ dB}$, cross-corr).
  - `tests/test_pbch_chain.m`: Required Unit Test 2 (Back-to-back AWGN 0 BLER at high SNR for $E=864$ and $E=960$).
  - `tests/test_e2e_tier1.m`: Tier 1 Feature Coverage (happy path per feature in isolation).
  - `tests/test_e2e_tier2.m`: Tier 2 Boundary & Corner Cases (edge Cell IDs, extreme CFO $\pm 20\text{ ppm}$, low SNR $-14\text{ dB}$, high SNR $+10\text{ dB}$).
  - `tests/test_e2e_tier3.m`: Tier 3 Cross-Feature Combinations (pairwise interactions across 4 architectures $\times$ 2 mobility speeds $\times$ CFO $\times$ SNR).
  - `tests/test_e2e_tier4.m`: Tier 4 Real-World Application Scenarios (end-to-end simulation runs verifying 3GPP technical outcomes and figure generation).

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Verification Objective |
|---|----------|--------------------|------------------------|
| S1 | Pedestrian Handheld Reception ($3\text{ km/h}$) | F4-F7, F9, F10, F13-F19 | Verify $\sim 1.0 - 2.0\text{ dB}$ coding gain of Design A & Comb-SSS over Legacy NR |
| S2 | High-Speed Vehicular Mobility ($120\text{ km/h}$) | F4-F7, F9, F10, F11, F13-F19 | Verify Doppler aging breakdown of Design A vs Comb-SSS channel tracking resilience |
| S3 | Extreme Low-SNR Cell Search ($-14$ to $-8\text{ dB}$) | F1, F2, F12, F16 | Verify $>2\text{ dB}$ MDR detection gain of 240 RE Extended SSS over 127 RE SSS |
| S4 | Multipath Channel Tracking Fidelity | F9, F12, F14, F17, F18 | Verify NMSE curves of all 4 channel estimators against ground truth |
| S5 | Publication Asset Generation & Reproducibility | F20-F25, `main_run_simulation.m` | Verify all 5 figures (`fig1`..`fig5`) generated in `.png` & `.fig` without error |

## Coverage Thresholds
- **Tier 1**: $\ge 5$ test cases per feature area ($\ge 90$ assertions)
- **Tier 2**: $\ge 5$ boundary/corner cases per feature area ($\ge 90$ assertions)
- **Tier 3**: $\ge 25$ pairwise combination test cases
- **Tier 4**: $\ge 5$ realistic end-to-end scenarios
- **Acceptance Gate**: 100% test pass rate with exit code 0.
