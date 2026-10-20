# Dispatch for Worker M1 Iteration 2: Sequence Hardening & Test Refinement

## Milestone
Milestone 1 (Iteration 2): Implement fixes formulated by Explorers

## Exclusive Write Ownership
You exclusively own and will modify:
- `+nr_sim/+sequences/gen_SSS.m`
- `tests/test_sequences.m`

## Reference Documents
- `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_1\handoff.md` and `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_1\proposed_gen_SSS.m`
- `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_2\handoff.md` and `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_2\proposed_test_sequences.patch`
- `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_3\handoff.md`

## Tasks
1. Update `+nr_sim/+sequences/gen_SSS.m`:
   - Add `narginchk(0, 2);`
   - Handle empty input defaulting cleanly:
     ```matlab
     if nargin == 0 || (nargin >= 1 && isempty(varargin{1}))
         N_ID_1 = 0;
         N_ID_2 = 0;
     ```
2. Update `tests/test_sequences.m`:
   - Refine Test 11 (lines 163-183) per `explorer_m1_iter2_2/proposed_test_sequences.patch`:
     - Assert zero-lag cross-correlation $\le 0.1500$, mean $< 0.0800$.
     - Assert all-lag cross-correlation $< 0.3000$ for distinct-$\Delta$ pairs.
     - Add explicit shift-collision stress test between PCI 0 and PCI 319 ($C_0 \le 0.1500$, $C_{\text{all}} \le 0.7500$).
3. Verification:
   - Run `tests/test_sequences.m` in MATLAB.
   - Run `tests/test_grid_mapping.m` in MATLAB.
   - Run `tests/test_adversarial_sequences.m` in MATLAB.
   - Verify 100% test pass with 0 errors.

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Output
Write your handoff report to `C:\workspace\nr_ics\.agents\teamwork\worker_m1_iter2\handoff.md`.

## 2026-09-28T03:32:57Z
Received dispatch task:
Apply the hardened SSS generator and test_sequences Test 11 modifications:
- Update +nr_sim/+sequences/gen_SSS.m with narginchk(0,2) and empty argument defaulting.
- Update tests/test_sequences.m Test 11 per explorer_m1_iter2_2 blueprint.
- Run tests/test_sequences.m, tests/test_grid_mapping.m, and tests/test_adversarial_sequences.m in MATLAB. Verify 100% pass.
- Write your handoff report to C:\workspace\nr_ics\.agents\teamwork\worker_m1_iter2\handoff.md.

