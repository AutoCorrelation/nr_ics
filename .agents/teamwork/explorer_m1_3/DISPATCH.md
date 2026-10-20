# Dispatch for Explorer M1-3: Verification Plan & Unit Testing for M1

## Milestone
Milestone 1: SSB Sequence Generation and Resource Grid Mapping

## Mission
Investigate and formulate the exact test suites and verification scripts for Milestone 1:
1. `tests/test_sequences.m`:
   - Verify lengths of PSS (127), SSS (127), Extended SSS (240), PBCH DMRS (144).
   - Verify auto-correlation peak of Extended SSS == 240, PSLR $>15\text{ dB}$, cross-correlation across different Cell IDs $<0.15$.
   - Verify legacy PSS matches `nrPSS` identically and legacy SSS matches `nrSSS` identically.
   - Verify sequence values are strictly BPSK/QPSK as specified.
2. `tests/test_grid_mapping.m`:
   - Verify RE conservation: total RE count per architecture == $240 \times 4 = 960\text{ REs}$.
   - Verify no collision between Data, DMRS, SSS, PSS, and Guard bands.
   - Verify PBCH Data RE count: 432 REs for Legacy and Jio ($E=864$ coded bits); 480 REs for Design A and Design B ($E=960$ coded bits).
   - Verify demapper reconstructs the exact original symbols.

## Files to Read
- C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\workspace\nr_ics\PROJECT.md
- C:\workspace\nr_ics\TEST_INFRA.md
- C:\workspace\nr_ics\.agents\teamwork\spec_miner_survey_2\handoff.md
- C:\workspace\nr_ics\.agents\teamwork\explorer_survey_3\handoff.md

## Output
Write your findings and test blueprint to `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_3\handoff.md`.

## 2026-09-28T03:01:31Z
You are explorer_m1_3.
Working directory: C:\workspace\nr_ics\.agents\teamwork\explorer_m1_3
Your dispatch instructions are at: C:\workspace\nr_ics\.agents\teamwork\explorer_m1_3\DISPATCH.md
Scope document: C:\workspace\nr_ics\PROJECT.md
Authoritative request: C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md

Task:
Formulate the exact test plan and implementation blueprint for Milestone 1 unit tests:
1. tests/test_sequences.m (automated programmatic verification of PSS, SSS, Extended SSS, DMRS, PSLR, cross-corr)
2. tests/test_grid_mapping.m (RE conservation 960 total REs, collision avoidance, correct 432 vs 480 PBCH Data REs)

Write your detailed findings to C:\workspace\nr_ics\.agents\teamwork\explorer_m1_3\handoff.md and report back.
