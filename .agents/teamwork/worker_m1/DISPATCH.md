# Dispatch for Worker M1: Implementation of Sequences & 2D Grid Mapping

## Milestone
Milestone 1: SSB Sequence Generation and Resource Grid Mapping

## Exclusive Write Ownership
You exclusively own and will create/modify the following files:
- `+nr_sim/+sequences/gen_PSSNR.m`
- `+nr_sim/+sequences/gen_SSS.m`
- `+nr_sim/+sequences/gen_ExtendedSSS.m`
- `+nr_sim/+sequences/gen_PBCHDMRS.m`
- `+nr_sim/+grid/map_ssb_grid.m`
- `+nr_sim/+grid/demap_ssb_grid.m`
- `+nr_sim/+grid/plot_ssb_grid.m`
- `tests/test_sequences.m`
- `tests/test_grid_mapping.m`

## Mandatory Reference Documents
Carefully read the handoff blueprints produced by the Explorers before implementing:
- `C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md`
- `C:\workspace\nr_ics\PROJECT.md`
- `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_1\handoff.md` (exact sequence code and formulas)
- `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_2\handoff.md` (exact grid mapping, demapping, and plotting code)
- `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_3\handoff.md` (exact unit test code and assertions)

## Requirements & Implementation Details
1. Implement the package directory structure:
   - Create directories `+nr_sim/+sequences/` and `+nr_sim/+grid/` and `tests/`.
2. Implement sequence generators:
   - `+nr_sim/+sequences/gen_PSSNR.m`: 127 RE PSS column vector `[127 x 1]`, matching `nrPSS`.
   - `+nr_sim/+sequences/gen_SSS.m`: 127 RE SSS column vector `[127 x 1]`, matching `nrSSS(3*N1+N2)`.
   - `+nr_sim/+sequences/gen_ExtendedSSS.m`: 240 RE Extended SSS column vector `[240 x 1]`, truncated Gold-255 with $g_1, g_2$, shift mapping for all 1008 PCIs, auto-corr peak 240, PSLR $>15\text{ dB}$, cross-corr $<0.15$.
   - `+nr_sim/+sequences/gen_PBCHDMRS.m`: 144 RE Gold-31 PBCH DMRS `[144 x 1]`, matching `nrPBCHDMRS(N_ID_cell, ibar_SSB)`.
3. Implement grid mappers:
   - `+nr_sim/+grid/map_ssb_grid.m`: 2D resource grid mapper for 'Legacy', 'DesignA', 'DesignB', 'Jio', conserving 960 REs ($240 \times 4$), 432 data REs for Legacy/Jio, 480 data REs for DesignA/DesignB, zero collision.
   - `+nr_sim/+grid/demap_ssb_grid.m`: Demapper supporting 2D (1 Rx) and 3D (4 Rx SIMO).
   - `+nr_sim/+grid/plot_ssb_grid.m`: 2D subcarrier-by-symbol visualizer for Figure 5.
4. Implement unit tests:
   - `tests/test_sequences.m`: Full programmatic test suite verifying sequence properties.
   - `tests/test_grid_mapping.m`: Full programmatic test suite verifying grid layouts and demapping.
5. Verification:
   - Run both `tests/test_sequences.m` and `tests/test_grid_mapping.m` via MATLAB tools or command line.
   - Ensure all tests pass with 0 errors.

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Handoff Report
Write your completion report to `C:\workspace\nr_ics\.agents\teamwork\worker_m1\handoff.md`. Include test commands and verified test execution outputs.

## 2026-09-28T03:10:44Z
Task:
Implement Milestone 1: SSB Sequence Generation and Resource Grid Mapping.
Create and test:
- +nr_sim/+sequences/gen_PSSNR.m
- +nr_sim/+sequences/gen_SSS.m
- +nr_sim/+sequences/gen_ExtendedSSS.m
- +nr_sim/+sequences/gen_PBCHDMRS.m
- +nr_sim/+grid/map_ssb_grid.m
- +nr_sim/+grid/demap_ssb_grid.m
- +nr_sim/+grid/plot_ssb_grid.m
- tests/test_sequences.m
- tests/test_grid_mapping.m

Read the blueprints in explorer_m1_1, explorer_m1_2, and explorer_m1_3 handoffs.
Run both test suites in MATLAB, verify 100% pass, and write your report to C:\workspace\nr_ics\.agents\teamwork\worker_m1\handoff.md.

