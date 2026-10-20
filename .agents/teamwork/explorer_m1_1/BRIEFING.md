# BRIEFING — 2026-09-28T03:01:31Z

## Mission
Formulate exact implementation blueprint for all 4 sequence generators in +nr_sim/+sequences/ (gen_PSSNR, gen_SSS, gen_ExtendedSSS, gen_PBCHDMRS).

## 🔒 My Identity
- Archetype: explorer
- Roles: investigator, analyzer, synthesizer
- Working directory: C:\workspace\nr_ics\.agents\teamwork\explorer_m1_1
- Original parent: 703a3591-dca9-42b2-8017-2c9866929f55
- Milestone: Milestone 1 - SSB Sequence Generation and Resource Grid Mapping

## 🔒 Key Constraints
- Read-only investigation — do NOT implement production source code directly.
- Formulate concrete blueprints, mathematical specifications, pseudocode, bit-exact verification vectors.
- Target directory for production code will be +nr_sim/+sequences/.
- Must support 1008 PCIs, verify PSLR > 15 dB for Extended SSS, and exact 3GPP TS 38.211 compliance.

## Current Parent
- Conversation ID: 703a3591-dca9-42b2-8017-2c9866929f55
- Updated: not yet

## Investigation State
- **Explored paths**: `C:\workspace\nr_ics\gen_PSSNR.m`, `PROJECT.md`, `ORIGINAL_REQUEST.md`, `spec_miner_survey_2\handoff.md`, `explorer_survey_3\handoff.md`, `TEST_INFRA.md`, MATLAB 5G Toolbox (`nrPSS`, `nrSSS`, `nrPBCHDMRS`).
- **Key findings**:
  1. `gen_PSSNR`: TS 38.211 m-sequence L=127. Must return `[127 x 1 double]` column vector to match standard contract (root `gen_PSSNR.m` currently returned row `[1 x 127]`). Bit-exact with `nrPSS(N_ID_2)`.
  2. `gen_SSS`: TS 38.211 dual m-sequence L=127. Discovered exact initial conditions $[1, 0, 0, 0, 0, 0, 0]$ for both shift registers matching `nrSSS(ncellid)` 100% bit-exact across ALL 1008 PCIs. Designed dual call signature: `(N_ID_1, N_ID_2)` and `(N_ID_cell)`.
  3. `gen_ExtendedSSS`: Truncated Gold-255 (degree 8, polynomials $g_1, g_2$, octal 435, 551). Shift mapping $m_0 = \text{mod}(pci, 255)$, $m_1 = \text{floor}(pci/255) \times 64$ produces 1008 distinct sequences. Benchmark $N_{ID}^{cell}=0$ achieves Peak=240, PSLR=16.72 dB (>15 dB), max off-peak sidelobe=35 ($0.1458 < 0.15$), and mean zero-lag cross-correlation 0.0410. Benchmarked pure vector indexing with persistent caching: >600x faster than `comm.GoldSequence` (10.7 us vs 14 ms).
  4. `gen_PBCHDMRS`: TS 38.211 §7.4.3.1 Gold-31 length 144. Returns unit power `[144 x 1 complex double]`. Bit-exact with `nrPBCHDMRS(ncellid, ibar_SSB)`.
- **Unexplored areas**: None for sequence generation. All mathematical models, properties, and edge cases fully verified in MATLAB.

## Key Decisions Made
- Confirmed output format for all 4 generators must be column vectors (`[L x 1 double]` or `[L x 1 complex double]`).
- Selected direct m-sequence vector indexing with persistent state over System objects for maximum Monte-Carlo performance and codegen support.
- Fully formulated production-ready source code templates for implementer agents.

## Artifact Index
- C:\workspace\nr_ics\.agents\teamwork\explorer_m1_1\BRIEFING.md — Persistent context
- C:\workspace\nr_ics\.agents\teamwork\explorer_m1_1\progress.md — Heartbeat and status
- C:\workspace\nr_ics\.agents\teamwork\explorer_m1_1\handoff.md — Final handoff report

