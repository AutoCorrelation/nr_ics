# Dispatch for Spec Miner Survey 2 (3GPP Rel-20 & RAN1 Agreements Miner)

## Mission
Extract and formalize all 3GPP Rel-20 / RAN1#124bis/#125/#126 agreed baseline conditions and specifications for the 4 SSB architectures described in ORIGINAL_REQUEST.md:
1. Legacy 5G NR Baseline: 127 RE SSS + Comb-4 Dedicated PBCH DMRS (144 DMRS REs, 432 PBCH data REs, polar rate R approx 0.0648).
2. Qualcomm Design A (R1-2606375): Concentrated 240 RE Extended SSS (truncated base-255 Gold sequence) at Symbol #2 as DMRS (0 dedicated DMRS, 480 PBCH data REs, polar rate R approx 0.0583).
3. Qualcomm Design B / MediaTek Comb-SSS (R1-2606847): Distributed 240 RE SSS multiplexed across Symbols #1, #2, #3 in Comb-3 pattern with 480 PBCH data REs.
4. Jio Platforms SSS-Assisted (R1-2605419): Dedicated DMRS + SSS-assisted joint channel estimation within a Phase-Coherence Window (q_CW).

Also check all files in `C:\workspace\nr_ics\document\` (documents, specs, PDFs or text files if any) to extract exact equations, polynomials, RE indexes, Doppler aging behavior, and channel parameters.

## Key Files to Read
- C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\workspace\nr_ics\document\ (read everything relevant)

## Output
Write your findings to `C:\workspace\nr_ics\.agents\teamwork\spec_miner_survey_2\handoff.md`.
Report back when complete.

## 2026-09-28T02:53:06Z
Task:
1. Mine all 3GPP specifications, RAN1 agreements (#124bis, #125, #126), and technical proposals cited in ORIGINAL_REQUEST.md:
   - Legacy 5G NR (TS 38.211 / TS 38.212 / TS 38.101-4): 127 RE SSS, Comb-4 DMRS, 432 data REs, polar rate R ~ 0.0648.
   - Qualcomm Design A (R1-2606375): Concentrated 240 RE Extended SSS (truncated base-255 Gold sequence) at Symbol #2 as DMRS (0 dedicated DMRS, 480 PBCH data REs, polar rate R ~ 0.0583).
   - Qualcomm Design B / MediaTek Comb-SSS (R1-2606847): Distributed 240 RE SSS multiplexed across Symbols #1, #2, #3 in Comb-3 pattern with 480 PBCH data REs.
   - Jio Platforms SSS-Assisted (R1-2605419): Dedicated DMRS + SSS-assisted joint channel estimation within a Phase-Coherence Window (q_CW).
2. Search C:\workspace\nr_ics\document\ and reference materials for exact generator polynomials, initialization formulas, shift registers, subcarrier index mappings, phase offset handling, and channel estimation formulas.
3. Detail the exact mathematical specifications, equations, grid allocations, and theoretical gains expected.
4. Write your detailed handoff report to C:\workspace\nr_ics\.agents\teamwork\spec_miner_survey_2\handoff.md.
5. Send a brief completion message back to the orchestrator when finished.

