# BRIEFING — 2026-09-28T03:10:00Z

## Mission
Formulate the exact implementation blueprint for 2D resource grid mapping and demapping across all 4 architectures (+nr_sim/+grid/): map_ssb_grid.m, demap_ssb_grid.m, plot_ssb_grid.m.

## 🔒 My Identity
- Archetype: explorer
- Roles: Investigation, Synthesis
- Working directory: C:\workspace\nr_ics\.agents\teamwork\explorer_m1_2
- Original parent: 703a3591-dca9-42b2-8017-2c9866929f55
- Milestone: Milestone 1: SSB Sequence Generation and Resource Grid Mapping

## 🔒 Key Constraints
- Read-only investigation — do NOT implement production source code directly
- Must support all 4 SSB architectures: Legacy 5G NR, Qualcomm Design A, Qualcomm Design B, Jio Platforms
- Grid dimensions: 240 subcarriers x 4 OFDM symbols (1-indexed in MATLAB, 0-indexed in 3GPP specs)
- Clean demapping of Data, DMRS/Pilots, and SSS reference signals without overlaps
- Adhere strictly to 3GPP TS 38.211 Section 7.4.3.1 for Legacy & Jio, and 3GPP R1-2309852 / R1-2309853 / R1-2309854 / R1-2309855 / R1-2309856 for Designs A and B

## Current Parent
- Conversation ID: 703a3591-dca9-42b2-8017-2c9866929f55
- Updated: 2026-09-28T03:10:00Z

## Investigation State
- **Explored paths**:
  - `detect_matlab_toolboxes`, `nrPBCHIndices`, `nrPBCHDMRSIndices`, `nrPSSIndices`, `nrSSSIndices` in 5G Toolbox.
  - Mathematical formulas vs 5G Toolbox indices across 8 PCIs.
  - Comb-3 shift indexing for aligned comb $v_{\text{shift}} = \bmod(N_{\text{ID}}^{\text{cell}}, 3)$.
  - 1T4R SIMO 3D grid vectorized demapping (`reshape(grid, 960, N_rx)`).
  - Multi-panel publication plotting for Figure 5 (`fig5_grid_allocation.png` / `.fig`).
- **Key findings**:
  - All 4 architectures conserve exactly 960 REs with zero collisions.
  - Legacy/Jio: 432 PBCH Data, 144 DMRS, 127 SSS, 127 PSS, 130 Null. Polar rate $R = 56/864 \approx 0.0648$.
  - Design A: 480 PBCH Data, 240 Extended SSS (as DMRS), 0 DMRS, 127 PSS, 113 Null. Polar rate $R = 56/960 \approx 0.0583$.
  - Design B: 480 PBCH Data (160/sym), 240 Comb-3 SSS (80/sym), 0 DMRS, 127 PSS, 113 Null. Polar rate $R = 56/960 \approx 0.0583$.
  - Jio: Same physical grid as Legacy with 271 joint pilots (144 DMRS + 127 SSS) bridging the Symbol 2 pilot gap.
  - Proposed code achieves 0 static analysis issues and passes 100% of self-verification unit tests.
- **Unexplored areas**: None for M1-2 scope; ready for implementation handoff.

## Key Decisions Made
- Implemented robust fallback generators (`internal_gen_ExtendedSSS`) to ensure grid mapper and demapper function independently during development before M1-1 sequence generators are integrated.
- Vectorized 3D array extraction for SIMO 1T4R using single-operation reshaping.
- Standardized 5-color IEEE-publication discrete palette for Figure 5 with dummy plot markers to avoid MATLAB legend warnings.

## Artifact Index
- proposed_map_ssb_grid.m — Complete implementation candidate for map_ssb_grid.m
- proposed_demap_ssb_grid.m — Complete implementation candidate for demap_ssb_grid.m
- proposed_plot_ssb_grid.m — Complete implementation candidate for plot_ssb_grid.m
- test_proposed_grid.m — Comprehensive self-verification test suite (100% pass)
- handoff.md — Authoritative 5-component handoff report for M1 implementer
- progress.md — Liveness heartbeat and milestone tracker
