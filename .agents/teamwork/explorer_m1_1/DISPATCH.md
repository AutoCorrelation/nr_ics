# Dispatch for Explorer M1-1: Sequence Generation Architecture

## Milestone
Milestone 1: SSB Sequence Generation and Resource Grid Mapping

## Mission
Investigate and formulate the detailed implementation plan for all 4 sequence generators in `+nr_sim/+sequences/`:
1. `gen_PSSNR.m`: 3GPP TS 38.211 §7.4.2.2.1 PSS m-sequence ($L=127$, $N_{ID}^{(2)} \in \{0, 1, 2\}$).
2. `gen_SSS.m`: 3GPP TS 38.211 §7.4.2.3.1 SSS dual m-sequence ($L=127$, $N_{ID}^{(1)} \in [0, 335]$, $N_{ID}^{(2)} \in [0, 2]$).
3. `gen_ExtendedSSS.m`: Length-240 Extended SSS truncated from base-255 Gold sequence ($g_1(D) = D^8 + D^4 + D^3 + D^2 + 1$, $g_2(D) = D^8 + D^6 + D^5 + D^3 + 1$) for $N_{ID}^{cell} \in [0, 1007]$. Must guarantee auto-correlation peak = 240, PSLR $>15\text{ dB}$, and cross-correlation $<0.15$.
4. `gen_PBCHDMRS.m`: 3GPP TS 38.211 §7.4.3.1 PBCH DMRS Gold-31 sequence of length 144.

## Files to Read
- C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\workspace\nr_ics\PROJECT.md
- C:\workspace\nr_ics\.agents\teamwork\spec_miner_survey_2\handoff.md
- C:\workspace\nr_ics\.agents\teamwork\explorer_survey_3\handoff.md
- C:\workspace\nr_ics\gen_PSSNR.m

## Output
Write your findings and implementation blueprint to `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_1\handoff.md`.

## 2026-09-28T03:01:31Z
Task:
Formulate the exact implementation blueprint for all 4 sequence generators (+nr_sim/+sequences/):
1. gen_PSSNR.m (127 RE PSS, TS 38.211)
2. gen_SSS.m (127 RE SSS, TS 38.211)
3. gen_ExtendedSSS.m (240 RE Extended SSS, truncated Gold-255 with g1, g2, shift mapping for 1008 PCIs, PSLR > 15 dB)
4. gen_PBCHDMRS.m (144 RE PBCH DMRS Gold-31 per TS 38.211 §7.4.3)

Write your detailed findings to C:\workspace\nr_ics\.agents\teamwork\explorer_m1_1\handoff.md and report back.

