# Dispatch for Explorer M2-3: Milestone 2 Test Suite Blueprint

## Milestone
Milestone 2: Physical Channel, Mobility, and RF Impairments

## Mission
Formulate the exact test plan and implementation blueprint for `tests/test_channel.m`:
1. Verify TDL-C constructor and parameters ($300\text{ ns}$ delay spread, $7\text{ GHz}$, $15.36\text{ MHz}$, 1T4R).
2. Verify output dimensions: input `[N x 1]` produces output `[N x 4]`.
3. Verify Doppler shifts: $19.4\text{ Hz}$ at $3\text{ km/h}$ and $777.8\text{ Hz}$ at $120\text{ km/h}$.
4. Verify CFO injection and frequency spectrum shift.
5. Verify AWGN noise variance calibration across $[-14, -2]\text{ dB}$.
6. Verify ideal channel frequency response extraction `H_ideal` has size `[240 x 4 x 4]`.
7. Programmatic section-based test script compatible with both `run()` and `runtests()`.

## Reference Files
- `C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md`
- `C:\workspace\nr_ics\PROJECT.md`
- `C:\workspace\nr_ics\TEST_INFRA.md`

## Output
Write your findings and test blueprint to `C:\workspace\nr_ics\.agents\teamwork\explorer_m2_3\handoff.md`.

## 2026-09-28T03:38:21Z
Task received from parent:
Formulate the exact test plan and implementation blueprint for tests/test_channel.m (TDL-C 1T4R, Doppler, CFO, AWGN, perfect CE).
Deliver report to C:\workspace\nr_ics\.agents\teamwork\explorer_m2_3\handoff.md.

