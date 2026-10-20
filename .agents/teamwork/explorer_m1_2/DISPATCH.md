# Dispatch for Explorer M1-2: 2D Resource Grid Mapping & Demapping

## Milestone
Milestone 1: SSB Sequence Generation and Resource Grid Mapping

## Mission
Investigate and formulate the detailed implementation plan for 2D resource grid mapping and demapping across all 4 architectures in `+nr_sim/+grid/`:
1. `map_ssb_grid.m`:
   - Architecture 1 (Legacy 5G NR): 127 PSS, 127 SSS, 144 Comb-4 DMRS, 432 PBCH Data REs, 130 Null REs ($E=864$ coded bits).
   - Architecture 2 (Qualcomm Design A): 127 PSS, 240 Concentrated Extended SSS at Symbol 2, 0 DMRS, 480 PBCH Data REs ($E=960$ coded bits).
   - Architecture 3 (Qualcomm Design B / Comb-SSS): 127 PSS, 240 Comb-3 SSS (80 REs/symbol across Symbols 1, 2, 3), 0 DMRS, 480 PBCH Data REs ($E=960$ coded bits).
   - Architecture 4 (Jio Platforms SSS-Assisted): 127 PSS, 127 SSS, 144 DMRS, 432 PBCH Data REs ($E=864$ coded bits) with SSS phase-coherence flag.
2. `demap_ssb_grid.m`: Extract data REs, pilot REs, and channel estimation references cleanly without overlap.
3. `plot_ssb_grid.m`: 2D subcarrier-by-symbol visualizer showing color-coded RE allocations for Figure 5.

## Files to Read
- C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\workspace\nr_ics\PROJECT.md
- C:\workspace\nr_ics\.agents\teamwork\spec_miner_survey_2\handoff.md
- C:\workspace\nr_ics\.agents\teamwork\explorer_survey_3\handoff.md

## Output
Write your findings and implementation blueprint to `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_2\handoff.md`.

## 2026-09-28T03:01:31Z
Task:
Formulate the exact implementation blueprint for 2D resource grid mapping and demapping across all 4 architectures (+nr_sim/+grid/):
1. map_ssb_grid.m for Legacy, DesignA, DesignB, Jio
2. demap_ssb_grid.m
3. plot_ssb_grid.m

Write your detailed findings to C:\workspace\nr_ics\.agents\teamwork\explorer_m1_2\handoff.md and report back.

