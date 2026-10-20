# Handoff Report: SSS Generator Hardening & Test 11 Refinement (Milestone 1 - Iteration 2)

**Agent**: `worker_m1_iter2` (implementer, qa, specialist)  
**Date**: 2026-09-28T03:36:30Z  
**Target Files Modified**:
- `+nr_sim/+sequences/gen_SSS.m`
- `tests/test_sequences.m`  
**Referenced Documents**:
- `C:\workspace\nr_ics\.agents\teamwork\worker_m1_iter2\DISPATCH.md`
- `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_1\handoff.md`
- `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_2\handoff.md`
- `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_3\handoff.md`
- `C:\workspace\nr_ics\.agents\teamwork\challenger_m1_1\handoff.md`
- `C:\workspace\nr_ics\.agents\teamwork\auditor_m1_1\handoff.md`  
**Handoff Type**: Hard (Task Complete)  
**Verdict**: **PASS (0 Errors, 0 Regressions, 100% Test Pass Across All Suites)**

---

## 1. Observation

### 1.1 Baseline Defects Observed Prior to Fix
Prior to applying modifications, dynamic evaluation in MATLAB R2026a revealed:
1. **Excess Arguments Vulnerability**:
   Calling `nr_sim.sequences.gen_SSS(1, 2, 3)` executed silently without throwing an error because `gen_SSS.m` did not enforce `narginchk(0, 2)` and parsed only the first two elements of `varargin` in an open `else` branch.
   In `tests/test_adversarial_sequences.m`:
   ```text
   [VULNERABILITY] gen_SSS(1, 2, 3) accepted malformed input without error!
   Adversarial Rejection Rate: 37 / 38 (97.37%)
   ```
2. **Empty Argument Crash**:
   Calling `nr_sim.sequences.gen_SSS([])` threw an unhandled exception:
   ```text
   gen_SSS([]) failed: N_ID_cell은(는) 스칼라이어야 합니다.
   ```
   This prevented graceful fallback to PCI 0, contrasting with `gen_PSSNR([])` and `gen_ExtendedSSS([])`.
3. **Fragile Assertion in Test 11**:
   `tests/test_sequences.m` asserted `max_all_cross < 0.3000` globally across an ad-hoc subset of cell IDs. For cell ID pairs sharing identical cyclic shift differential $\Delta = (m_0 - m_1) \pmod{255}$ (e.g. PCI 0 and PCI 319 where $\Delta = 0$), the true aperiodic peak cross-correlation reaches $\frac{240 - 64}{240} = 0.7333$, which is an inherent algebraic property of truncated Gold sequences.

### 1.2 Modifications Applied

#### A. `+nr_sim/+sequences/gen_SSS.m`
Modified lines 28–61 to incorporate `narginchk(0, 2)` and empty argument defaulting:
```matlab
    % Input argument parsing and validation
    narginchk(0, 2);

    if nargin == 0
        N_ID_1 = 0;
        N_ID_2 = 0;
    elseif nargin == 1
        if isempty(varargin{1})
            N_ID_1 = 0;
            N_ID_2 = 0;
        else
            N_ID_cell = varargin{1};
            validateattributes(N_ID_cell, {'numeric'}, ...
                {'scalar', 'integer', '>=', 0, '<=', 1007}, mfilename, 'N_ID_cell');
            N_ID_1 = floor(double(N_ID_cell) / 3);
            N_ID_2 = mod(double(N_ID_cell), 3);
        end
    else
        if isempty(varargin{1})
            N_ID_1 = 0;
        else
            N_ID_1 = varargin{1};
            validateattributes(N_ID_1, {'numeric'}, ...
                {'scalar', 'integer', '>=', 0, '<=', 335}, mfilename, 'N_ID_1');
        end

        if isempty(varargin{2})
            N_ID_2 = 0;
        else
            N_ID_2 = varargin{2};
            validateattributes(N_ID_2, {'numeric'}, ...
                {'scalar', 'integer', '>=', 0, '<=', 2}, mfilename, 'N_ID_2');
        end
    end
```

#### B. `tests/test_sequences.m`
1. **Test 8 Enhancement** (lines 127–140):
   Added unit test assertions for empty input defaulting and excess input trapping:
   ```matlab
   % Default parameter and empty input handling
   ref_sss0 = nrSSS(0);
   assert(isequal(nr_sim.sequences.gen_SSS(), ref_sss0), 'gen_SSS() must default to PCI 0');
   assert(isequal(nr_sim.sequences.gen_SSS([]), ref_sss0), 'gen_SSS([]) must default to PCI 0');
   assert(isequal(nr_sim.sequences.gen_SSS([], []), ref_sss0), 'gen_SSS([], []) must default to PCI 0');

   % Excess arguments handling
   err_caught = false;
   try
       nr_sim.sequences.gen_SSS(1, 2, 3);
   catch
       err_caught = true;
   end
   assert(err_caught, 'gen_SSS with 3 arguments must throw error');
   ```

2. **Test 11 Refinement** (lines 178–226):
   Replaced the cherry-picked assertion with physical OFDM zero-lag bounds and shift-collision stress testing:
   ```matlab
   %% Test 11: Extended SSS - Cross-Correlation Isolation Across Cell IDs
   % Evaluates synchronous zero-lag isolation (governing Cell-ID discrimination in
   % OFDM receivers after PSS synchronization) and verifies cross-correlation bounds.
   test_cells = [0, 1, 10, 100, 254, 255, 511, 700, 1007];
   num_pairs = length(test_cells) * (length(test_cells) - 1) / 2;
   zero_cross_vals = zeros(num_pairs, 1);
   pair_idx = 0;
   max_zero_cross = 0;
   max_all_cross = 0;

   for i = 1:length(test_cells)
       for j = (i+1):length(test_cells)
           s_i = double(nr_sim.sequences.gen_ExtendedSSS(test_cells(i)));
           s_j = double(nr_sim.sequences.gen_ExtendedSSS(test_cells(j)));
           
           % Normalized zero-lag cross-correlation (synchronous subcarrier isolation)
           c0 = abs(sum(s_i(:) .* s_j(:))) / 240;
           pair_idx = pair_idx + 1;
           zero_cross_vals(pair_idx) = c0;
           max_zero_cross = max(max_zero_cross, c0);
           
           c_all = max(abs(xcorr(s_i(:), s_j(:)))) / 240;
           max_all_cross = max(max_all_cross, c_all);
       end
   end

   % 1. Zero-lag cross-correlation governs synchronous Cell-ID detection in OFDM
   assert(max_zero_cross <= 0.1500, ...
       sprintf('Extended SSS maximum zero-lag cross-correlation %.4f exceeds 0.15 limit', max_zero_cross));
   assert(mean(zero_cross_vals) < 0.0800, ...
       sprintf('Extended SSS mean zero-lag cross-correlation %.4f exceeds 0.08 limit', mean(zero_cross_vals)));

   % 2. Distinct shift differential pairs have all-lag cross-correlation < 0.3000
   assert(max_all_cross < 0.3000, ...
       sprintf('Extended SSS maximum all-lag cross-correlation %.4f exceeds 0.30 limit', max_all_cross));

   % 3. Adversarial shift-collision stress test (PCIs sharing identical delta = (m0 - m1) mod 255)
   % PCI 0 (m0=0, m1=0) and PCI 319 (m0=64, m1=64) share delta=0.
   % At zero lag (synchronous grid), isolation is strictly preserved (<= 0.1500).
   % At lag 64, aperiodic overlap reaches (240 - 64)/240 = 0.7333 <= 0.7500.
   s0 = double(nr_sim.sequences.gen_ExtendedSSS(0));
   s319 = double(nr_sim.sequences.gen_ExtendedSSS(319));
   c0_collision = abs(sum(s0(:) .* s319(:))) / 240;
   call_collision = max(abs(xcorr(s0(:), s319(:)))) / 240;
   assert(c0_collision <= 0.1500, ...
       sprintf('Shift-collision zero-lag cross-correlation %.4f exceeds 0.15 limit', c0_collision));
   assert(call_collision <= 0.7500, ...
       sprintf('Shift-collision all-lag peak %.4f exceeds theoretical overlap bound 0.75', call_collision));
   ```

### 1.3 Post-Modification Execution Results

1. **Static Analysis (`check_matlab_code`)**:
   - `+nr_sim/+sequences/gen_SSS.m`: `{"code_issues":[]}` (0 issues)
   - `tests/test_sequences.m`: `{"code_issues":[]}` (0 issues)

2. **Unit Test Suite (`tests/test_sequences.m`)**:
   Command: `runtests('tests/test_sequences.m')`
   Result:
   ```text
   test_sequences 실행 중
   .......... .....
   [PASS] All 15 Sequence Generation unit tests completed successfully.
   .
   test_sequences 완료
   __________

     1×16 TestResult 배열 - 속성 있음:
       Name
       Passed
       Failed
       Incomplete
       Duration
       Details

   전체:
      16 Passed, 0 Failed, 0 Incomplete.
      테스트 시간은 0.14588초입니다.
   ```

3. **Grid Mapping Test Suite (`tests/test_grid_mapping.m`)**:
   Command: `runtests('tests/test_grid_mapping.m')`
   Result:
   ```text
   test_grid_mapping 실행 중
   .......... 
   [PASS] All 10 Grid Mapping unit tests completed successfully.
   .
   test_grid_mapping 완료
   __________

     1×11 TestResult 배열 - 속성 있음:
       Name
       Passed
       Failed
       Incomplete
       Duration
       Details

   전체:
      11 Passed, 0 Failed, 0 Incomplete.
      테스트 시간은 0.7621초입니다.
   ```

4. **Adversarial Challenge Battery (`tests/test_adversarial_sequences.m`)**:
   Command: `run('tests/test_adversarial_sequences.m')`
   Result:
   ```text
   --- 6. Adversarial Malformed Input Stress Testing ---

   Adversarial Rejection Rate: 38 / 38 (100.00%)

   ========================================================================
     ADVERSARIAL CHALLENGE COMPLETED                                       
   ========================================================================
   ```
   Zero unhandled adversarial cases. Rejection rate elevated from 97.37% (37/38) to **100.00% (38/38)**.

5. **Interface Semantics Sanity Check**:
   - `gen_SSS()` == `nrSSS(0)`: Bit-exact (127 symbols)
   - `gen_SSS([])` == `nrSSS(0)`: Bit-exact (127 symbols)
   - `gen_SSS([], [])` == `nrSSS(0)`: Bit-exact (127 symbols)
   - `gen_SSS(50, [])` == `nrSSS(150)`: Bit-exact (127 symbols)
   - `gen_SSS([], 2)` == `nrSSS(2)`: Bit-exact (127 symbols)
   - `gen_SSS(1, 2, 3)`: Throws `MATLAB:narginchk:tooManyInputs` ("입력 인수가 너무 많습니다.")

6. **Grid Demapper Invertibility Sweep**:
   Evaluated 124 round-trip map-demap operations across 4 architectures (`Legacy`, `DesignA`, `DesignB`, `Jio`) and 11 PCIs ($0, 1, 2, 10, 100, 319, 335, 511, 765, 957, 1007$):
   - PBCH symbol reconstruction error: `0.000000000000e+00`
   - Pilot symbol extraction error: `0.000000000000e+00`

---

## 2. Logic Chain

1. **Interface Hardening Rationale**:
   - *Observation 1.1* showed `gen_SSS(1, 2, 3)` was silently accepted because `varargin` did not check the upper bound on arguments, and `gen_SSS([])` crashed in `validateattributes`.
   - Adding `narginchk(0, 2)` directly causes MATLAB's engine to enforce `[0, 2]` arguments, preventing accidental or adversarial parameter injection.
   - Checking `isempty(varargin{k})` prior to `validateattributes` allows empty arguments to default gracefully to 0, matching the behavior of `gen_PSSNR`, `gen_ExtendedSSS`, and `gen_PBCHDMRS`.

2. **Downstream Non-Regression**:
   - Internal production callers in `+nr_sim/+grid/map_ssb_grid.m` (line 138) and `demap_ssb_grid.m` (line 137) call `gen_SSS(N_ID_1, N_ID_2)` with two valid numeric scalar integers.
   - Because valid 2-argument calls enter the non-empty branch of the 2-argument check, the mathematical LFSR generation is strictly identical.
   - *Observation 1.3* confirms that round-trip mapping/demapping has zero error across all architectures and PCIs.

3. **Physical OFDM Grounding of Test 11**:
   - *Observation 1.1* noted that a global assertion of `max_all_cross < 0.3000` is invalid for truncated Gold codes when cell pairs share identical cyclic shift difference $\Delta$.
   - In OFDM receivers, timing synchronization is achieved via PSS prior to SSS detection. Cell ID estimation on the SSS occurs on synchronized subcarriers where frequency lag is zero ($k = 0$).
   - The verified zero-lag cross-correlation across all test cells satisfies $C_0 \le 0.1417 \le 0.1500$, with mean $0.0491 < 0.0800$.
   - For distinct-$\Delta$ pairs, all-lag cross-correlation satisfies $C_{\text{all}} \le 0.2583 < 0.3000$.
   - For collision pairs (e.g. PCI 0 and PCI 319 sharing $\Delta = 0$), zero-lag isolation remains $0.0500 \le 0.1500$, while all-lag peak reaches $0.7333 \le 0.7500$ at lag 64 (matching theoretical aperiodic overlap bound $(240-64)/240 = 0.7333$).
   - Replacing the brittle assertion with this multi-tier validation aligns the test suite with physical receiver mechanics and 3GPP standards.

---

## 3. Caveats

1. **Shift-Collision Awareness in Cellular Planning**:
   While synchronous zero-lag isolation is strictly preserved ($C_0 \le 0.1500$), cells sharing $\Delta = (m_0 - m_1) \pmod{255}$ will produce cross-correlation peaks at lag $\delta$ during unsynchronized time/frequency search. Real-world network planning should avoid allocating shift-matched PCIs to co-channel neighboring cells.
2. **Scope Limitation**:
   Modifications were strictly confined to `+nr_sim/+sequences/gen_SSS.m` and `tests/test_sequences.m`. No other files were modified.

---

## 4. Conclusion

1. **All Dispatch Tasks Complete**:
   - `+nr_sim/+sequences/gen_SSS.m` is fully hardened with `narginchk(0, 2)` and empty argument defaulting.
   - `tests/test_sequences.m` Test 8 and Test 11 are updated and strengthened.
2. **100% Pass Rate**:
   - `tests/test_sequences.m`: 15/15 tests PASS (100%).
   - `tests/test_grid_mapping.m`: 10/10 tests PASS (100%).
   - `tests/test_adversarial_sequences.m`: 38/38 adversarial checks PASS (100.00% rejection rate).
3. **Zero Integrity Violations**:
   - No hardcoded test results, no dummy implementations, no lookup tables. All sequence values are computed via genuine LFSR state transitions and 3GPP m-sequence/Gold recurrences.

---

## 5. Verification Method

To independently verify the implementation, execute the following commands in MATLAB R2026a from `C:\workspace\nr_ics`:

```matlab
% Set project root and paths
cd('C:\workspace\nr_ics');
addpath('C:\workspace\nr_ics');

% 1. Run Sequence Unit Test Suite
res_seq = runtests('tests/test_sequences.m');
assert(all([res_seq.Passed]) && ~any([res_seq.Failed]), 'test_sequences FAILED');

% 2. Run Grid Mapping Test Suite
res_grid = runtests('tests/test_grid_mapping.m');
assert(all([res_grid.Passed]) && ~any([res_grid.Failed]), 'test_grid_mapping FAILED');

% 3. Run Adversarial Battery
run('tests/test_adversarial_sequences.m');
assert(results.adversarial_rejected == 38, 'Adversarial rejection must be 38/38');

% 4. Verify Static Code Analysis
assert(isempty(checkcode('+nr_sim/+sequences/gen_SSS.m')), 'gen_SSS has code issues');
assert(isempty(checkcode('tests/test_sequences.m')), 'test_sequences has code issues');
```

### Invalidation Conditions
This handoff report is invalidated if:
1. `runtests('tests/test_sequences.m')` reports any failure or unhandled exception.
2. `runtests('tests/test_grid_mapping.m')` reports any failure.
3. `tests/test_adversarial_sequences.m` reports rejection rate $< 100\%$ (fewer than 38 rejected).
4. `nr_sim.sequences.gen_SSS(1, 2, 3)` executes without throwing `MATLAB:narginchk:tooManyInputs`.
5. `nr_sim.sequences.gen_SSS([])` fails to default to `nrSSS(0)`.
