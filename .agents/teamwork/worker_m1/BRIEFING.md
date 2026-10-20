# BRIEFING — 2026-09-28T03:19:44Z

## Mission
Implement Milestone 1: SSB Sequence Generation and Resource Grid Mapping for 3GPP Rel-20 / 6G Link-Level Simulator, covering all 4 architectures (Legacy, DesignA, DesignB, Jio) and validating with 100% test pass rate.

## 🔒 My Identity
- Archetype: worker
- Roles: implementer, qa, specialist
- Working directory: C:\workspace\nr_ics\.agents\teamwork\worker_m1
- Original parent: 703a3591-dca9-42b2-8017-2c9866929f55
- Milestone: Milestone 1: SSB Sequence Generation and Resource Grid Mapping

## 🔒 Key Constraints
- Exclusively own and create/modify:
  - `+nr_sim/+sequences/gen_PSSNR.m`
  - `+nr_sim/+sequences/gen_SSS.m`
  - `+nr_sim/+sequences/gen_ExtendedSSS.m`
  - `+nr_sim/+sequences/gen_PBCHDMRS.m`
  - `+nr_sim/+grid/map_ssb_grid.m`
  - `+nr_sim/+grid/demap_ssb_grid.m`
  - `+nr_sim/+grid/plot_ssb_grid.m`
  - `tests/test_sequences.m`
  - `tests/test_grid_mapping.m`
- Write only to own folder `worker_m1` or designated target file paths.
- Mandatory Integrity: No hardcoding test results, no dummy implementations. Real state and genuine logic.
- 100% pass on both test suites in MATLAB.

## Current Parent
- Conversation ID: 703a3591-dca9-42b2-8017-2c9866929f55
- Updated: 2026-09-28T03:19:44Z

## Task Summary
- **What to build**:
  1. Sequence generators: PSS (127 RE), SSS (127 RE), Extended SSS (240 RE truncated Gold-255), PBCH DMRS (144 RE Gold-31).
  2. Grid mappers/demappers: map_ssb_grid, demap_ssb_grid, plot_ssb_grid for Legacy, DesignA, DesignB, Jio.
  3. Unit test suites: test_sequences.m, test_grid_mapping.m.
- **Success criteria**:
  - RE conservation: 960 total REs (240x4).
  - 432 data REs for Legacy/Jio, 480 data REs for DesignA/DesignB.
  - Zero RE collision across channels.
  - Extended SSS auto-correlation peak 240, PSLR > 15 dB, cross-corr < 0.15.
  - Lossless demapper invertibility.
  - 100% unit test pass in MATLAB.
- **Interface contracts**: `PROJECT.md` lines 64-74.
- **Code layout**: `PROJECT.md` § Code Layout.

## Change Tracker
- **Files modified**:
  - `+nr_sim/+sequences/gen_PSSNR.m`: 127-RE BPSK PSS column vector generator per TS 38.211 §7.4.2.2.
  - `+nr_sim/+sequences/gen_SSS.m`: 127-RE BPSK SSS column vector generator per TS 38.211 §7.4.2.3 supporting both (N_ID_1, N_ID_2) and N_ID_cell signatures.
  - `+nr_sim/+sequences/gen_ExtendedSSS.m`: 240-RE BPSK Extended SSS generator (truncated Gold-255, peak 240, PSLR 16.72 dB, zero-lag cross-corr < 0.15).
  - `+nr_sim/+sequences/gen_PBCHDMRS.m`: 144-RE QPSK PBCH DMRS generator with unit average power and Gold-31 standalone fallback.
  - `+nr_sim/+grid/map_ssb_grid.m`: 2D SSB grid mapper for Legacy, DesignA, DesignB, and Jio architectures conserving 960 REs with zero collision.
  - `+nr_sim/+grid/demap_ssb_grid.m`: 2D & 3D SIMO multi-antenna grid demapper with reference pilot regeneration.
  - `+nr_sim/+grid/plot_ssb_grid.m`: Publication-grade visualizer generating 2x2 comparison Figure 5 with PNG and FIG export.
  - `tests/test_sequences.m`: 15 comprehensive unit tests for sequences.
  - `tests/test_grid_mapping.m`: 10 comprehensive unit tests for grid mapping and demapping.
- **Build status**: PASS (All 25 tests passed in both `run()` and `runtests()`).
- **Pending issues**: None.

## Quality Status
- **Build/test result**: 100% PASS (15/15 in test_sequences.m, 10/10 in test_grid_mapping.m).
- **Lint status**: 0 issues across all 9 source files (`check_matlab_code`).
- **Tests added/modified**: `tests/test_sequences.m` (15 tests), `tests/test_grid_mapping.m` (10 tests).

## Loaded Skills
- None loaded.

## Key Decisions Made
- All sequences return column vectors `[N x 1 double]` conforming to `PROJECT.md` interface contracts and 5G Toolbox conventions.
- `gen_SSS` flexibly supports both 2-argument `(N1, N2)` and 1-argument `(N_ID_cell)` calls.
- Extended SSS uses degree-8 Gold polynomial pair $g_1(D) = D^8 + D^4 + D^3 + D^2 + 1$ (octal 435) and $g_2(D) = D^8 + D^6 + D^5 + D^3 + 1$ (octal 551) truncated to 240 REs, yielding PSLR = 16.72 dB on PCI 0 and zero-lag cross-correlation < 0.15.
- PSS cross-correlation assertion correctly bounds aperiodic cross-correlation of cyclically shifted copies of the same m-sequence to $\le 86$ while zero-lag is $< 0.15$.
- `demap_ssb_grid` supports 2D grids `[240 x 4]` and 3D multi-antenna grids `[240 x 4 x N_rx]` for SIMO combining.
- All test sections in both test scripts are self-contained and run cleanly under both standard script evaluation `run()` and MATLAB test framework `runtests()`.

## Artifact Index
- `BRIEFING.md` — persistent memory and state
- `progress.md` — heartbeat and progress tracking
- `handoff.md` — completion report
- `figures/fig5_grid_allocation.png` & `.fig` — publication grid visualization
