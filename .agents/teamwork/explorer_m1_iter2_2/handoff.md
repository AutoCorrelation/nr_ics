# Handoff Report: Test Suite Refinement for Extended SSS Cross-Correlation Assertions

**Agent**: `explorer_m1_iter2_2` (EXPLORER & SYNTHESIZER)  
**Date**: 2026-09-28T03:32:00Z  
**Milestone**: Milestone 1 (SSB Sequence Generation and Resource Grid Mapping - Iteration 2)  
**Target Code**: `tests/test_sequences.m` (Lines 163-183)  
**Referenced Reports**:  
- `C:\workspace\nr_ics\.agents\teamwork\challenger_m1_1\handoff.md`  
- `C:\workspace\nr_ics\.agents\teamwork\auditor_m1_1\handoff.md`  
**Patch Artifact**: `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_2\proposed_test_sequences.patch`

---

## 1. Observation

### 1.1 Test Numbering Clarification (Dispatch "Test 9" vs Codebase "Test 11")
Direct inspection of `tests/test_sequences.m` reveals the layout of tests for Extended SSS:
1. **Lines 127-136 (`%% Test 9: Extended SSS - Length 240 and BPSK Constellation`)**:
   ```matlab
   test_cells = [0, 1, 10, 100, 254, 255, 511, 700, 1007];
   for idx = 1:length(test_cells)
       ncell = test_cells(idx);
       d_ext = nr_sim.sequences.gen_ExtendedSSS(ncell);
       assert(length(d_ext) == 240, 'Extended SSS length must be exactly 240');
       assert(iscolumn(d_ext), 'Extended SSS must be a column vector [240 x 1]');
       assert(all(d_ext == 1 | d_ext == -1), 'Extended SSS values must strictly be BPSK {-1, +1}');
       assert(isreal(d_ext), 'Extended SSS must be real-valued');
   end
   ```
   *Observation*: Test 9 tests solely dimensions, column shape, and BPSK modulation. It contains **no** cross-correlation assertions.

2. **Lines 138-162 (`%% Test 10: Extended SSS - Auto-Correlation Peak and PSLR > 15 dB`)**:
   Tests periodic auto-correlation peak (240) and PSLR $\ge 15.0\text{ dB}$ on PCI 0 and mean PSLR $\ge 15.5\text{ dB}$.

3. **Lines 163-183 (`%% Test 11: Extended SSS - Cross-Correlation Isolation Across Cell IDs`)**:
   ```matlab
   test_cells = [0, 1, 10, 100, 254, 255, 511, 700, 1007];
   max_zero_cross = 0;
   max_all_cross = 0;
   for i = 1:length(test_cells)
       for j = (i+1):length(test_cells)
           s_i = double(nr_sim.sequences.gen_ExtendedSSS(test_cells(i)));
           s_j = double(nr_sim.sequences.gen_ExtendedSSS(test_cells(j)));
           
           c0 = abs(sum(s_i(:) .* s_j(:))) / 240;
           max_zero_cross = max(max_zero_cross, c0);
           
           c_all = max(abs(xcorr(s_i(:), s_j(:)))) / 240;
           max_all_cross = max(max_all_cross, c_all);
       end
   end
   assert(max_zero_cross <= 0.1500, ...
       sprintf('Extended SSS normalized zero-lag cross-correlation %.4f exceeds 0.15 limit', max_zero_cross));
   assert(max_all_cross < 0.3000, ...
       sprintf('Extended SSS maximum all-lag cross-correlation %.4f exceeds 0.30 limit', max_all_cross));
   ```
   *Observation*: The assertion verbatim quoted in DISPATCH.md — `assert(max_all_cross < 0.3000)` — resides at line 181 in **Test 11**, not Test 9. The dispatch refers to Test 11 using the section's starting test index (Extended SSS spans Tests 9-12) or the fact that 9 cell IDs were tested. Test 9 is sound; the target of refinement is unequivocally lines 163-183 (Test 11).

---

### 1.2 Mathematical & Empirical Cross-Correlation Properties
1. **Shift Differential Collision (`Delta`)**:
   Extended SSS generates sequences via:
   $$m_0 = \text{PCI} \bmod 255, \quad m_1 = \lfloor \text{PCI} / 255 \rfloor \times 64, \quad \Delta = (m_0 - m_1) \bmod 255$$
   For the 9 cell IDs in `test_cells = [0, 1, 10, 100, 254, 255, 511, 700, 1007]`:
   $$\Delta \in \{0, 1, 10, 100, 254, 191, 128, 62, 50\}$$
   Because all 9 cells have mutually distinct $\Delta$, `max_all_cross` evaluates to `0.2583 < 0.3000`.

2. **Adversarial Collision Pair (PCI 0 vs PCI 319)**:
   - For PCI 0: $m_0 = 0, m_1 = 0 \implies \Delta = 0$.
   - For PCI 319: $m_0 = 64, m_1 = 64 \implies \Delta = 0$.
   - Relative shift: $\delta = 64$ chips. Truncation overlap across length 240: $240 - 64 = 176$ chips.
   - Evaluated in MATLAB R2026a:
     - Zero-lag cross-correlation: $C_0(0, 319) = 12 / 240 = \mathbf{0.0500} \ll 0.1500$.
     - All-lag cross-correlation: $C_{\text{all}}(0, 319) = 176 / 240 = \mathbf{0.7333}$ (at lag 64).
   - If PCI 319 is added to `test_cells`, `assert(max_all_cross < 0.3000)` fails immediately with error:
     ```text
     Extended SSS maximum all-lag cross-correlation 0.7333 exceeds 0.30 limit
     ```

3. **Full 1008-PCI Space Zero-Lag Isolation**:
   Evaluated across all 507,528 distinct PCI pairs:
   - Mean zero-lag cross-correlation: **0.0411**
   - Median zero-lag cross-correlation: **0.0250**
   - Pairs with $C_0 \le 0.1500$: **505,048 / 507,528 (99.51%)**
   - Worst-case pair across entire space: PCI 514 and PCI 765, $C_0 = 64 / 240 = 0.2667$.

---

## 2. Logic Chain

1. **Premise 1 (Physical Receiver Detection Model)**:
   In a 3GPP 5G NR receiver, symbol timing and fractional carrier frequency offset (CFO) are acquired by correlating against PSS in the time domain. After PSS synchronization, the receiver sets its FFT window and transforms the signal into the frequency domain. SSS detection is executed strictly across the 240 subcarriers of OFDM symbol 2 at **zero subcarrier lag** ($C_0$).
2. **Premise 2 (Physical Inter-Cell Isolation)**:
   In synchronous cellular networks, neighboring cells transmit SSBs aligned in time and frequency. Inter-cell interference and Cell-ID discrimination are dictated exclusively by **zero-lag cross-correlation** ($C_0$). A receiver never tests cross-correlation across 64 subcarriers of offset (which would represent $64 \times 30\text{ kHz} = 1.92\text{ MHz}$ frequency error).
3. **Premise 3 (Algebraic Limitation of Truncated Gold-255 Codes)**:
   Generating 1008 PCIs from length-255 Gold sequences requires each shift differential $\Delta \in [0, 254]$ to be shared by approximately 4 PCIs ($1008 / 255 \approx 3.95$). Any two PCIs sharing $\Delta$ are cyclic shifts of the same Gold code, producing a non-zero lag aperiodic correlation peak equal to the truncated overlap $(240 - \delta) / 240 \le 0.7500$.
4. **Inference**:
   Asserting `max_all_cross < 0.3000` globally across arbitrary PCIs is mathematically false and physically irrelevant for Extended SSS. The assertion only passed previously because the 9 cell IDs had distinct $\Delta$.
5. **Deduction & Refinement Strategy**:
   The unit test must:
   - Assert `max_zero_cross <= 0.1500` across representative cell IDs (governing synchronous detection).
   - Assert ensemble average `mean(zero_cross_vals) < 0.0800` (validating low inter-cell interference, actual $\approx 0.045$).
   - For distinct-$\Delta$ pairs, assert `max_all_cross < 0.3000` (confirming pseudo-random isolation when sequences do not collide).
   - Explicitly include an adversarial shift-collision stress test (PCI 0 vs PCI 319):
     - Assert $C_0(0, 319) \le 0.1500$ (verifying that synchronous zero-lag isolation remains intact despite shift collision).
     - Assert $C_{\text{all}}(0, 319) \le 0.7500$ (verifying that the non-zero lag peak respects the theoretical Gold code truncation bound $\frac{240 - 64}{240} \approx 0.7333$).

---

## 3. Caveats

1. **Test Numbering in External References**:
   External dispatches and user messages may refer to this test as "Test 9" (due to Extended SSS starting at Test 9 or the 9 test cells). The exact code location in `tests/test_sequences.m` is lines 163-183, headed `%% Test 11: Extended SSS - Cross-Correlation Isolation Across Cell IDs`. Test 9 (lines 127-136) is verified and must remain untouched.
2. **Worst-Case 0.49% Zero-Lag Tail**:
   In the exhaustive 507,528-pair ensemble, 2,480 pairs (0.49%) have $C_0 > 0.1500$ (up to $64/240 = 0.2667$). Network planning algorithms avoid allocating these rare paired PCIs to adjacent co-channel cells. For unit testing, representative subsets satisfy $C_0 \le 0.1500$.

---

## 4. Conclusion & Proposed Code Modification

### 4.1 Summary of Changes
Replace lines 163-183 in `tests/test_sequences.m` with code that:
1. Retains the baseline representative cell IDs `[0, 1, 10, 100, 254, 255, 511, 700, 1007]`.
2. Preallocates `zero_cross_vals` to prevent MATLAB code analyzer array growth warnings.
3. Tests maximum zero-lag cross-correlation (`max_zero_cross <= 0.1500`).
4. Tests mean zero-lag cross-correlation (`mean(zero_cross_vals) < 0.0800`).
5. Tests all-lag cross-correlation for distinct-$\Delta$ pairs (`max_all_cross < 0.3000`).
6. Adds an explicit adversarial shift-collision test for pair (PCI 0, PCI 319) asserting $C_0 \le 0.1500$ and $C_{\text{all}} \le 0.7500$.

### 4.2 Exact Replacement Code Block (for `tests/test_sequences.m` lines 163-183)

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

### 4.3 Git Diff Patch
The exact unified diff is saved at `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_2\proposed_test_sequences.patch`:
```diff
--- a/tests/test_sequences.m
+++ b/tests/test_sequences.m
@@ -163,22 +163,40 @@
 %% Test 11: Extended SSS - Cross-Correlation Isolation Across Cell IDs
+% Evaluates synchronous zero-lag isolation (governing Cell-ID discrimination in
+% OFDM receivers after PSS synchronization) and verifies cross-correlation bounds.
 test_cells = [0, 1, 10, 100, 254, 255, 511, 700, 1007];
+num_pairs = length(test_cells) * (length(test_cells) - 1) / 2;
+zero_cross_vals = zeros(num_pairs, 1);
+pair_idx = 0;
 max_zero_cross = 0;
 max_all_cross = 0;
+
 for i = 1:length(test_cells)
     for j = (i+1):length(test_cells)
         s_i = double(nr_sim.sequences.gen_ExtendedSSS(test_cells(i)));
         s_j = double(nr_sim.sequences.gen_ExtendedSSS(test_cells(j)));
         
+        % Normalized zero-lag cross-correlation (synchronous subcarrier isolation)
         c0 = abs(sum(s_i(:) .* s_j(:))) / 240;
+        pair_idx = pair_idx + 1;
+        zero_cross_vals(pair_idx) = c0;
         max_zero_cross = max(max_zero_cross, c0);
         
         c_all = max(abs(xcorr(s_i(:), s_j(:)))) / 240;
         max_all_cross = max(max_all_cross, c_all);
     end
 end
+
+% 1. Zero-lag cross-correlation governs synchronous Cell-ID detection in OFDM
 assert(max_zero_cross <= 0.1500, ...
     sprintf('Extended SSS maximum zero-lag cross-correlation %.4f exceeds 0.15 limit', max_zero_cross));
+assert(mean(zero_cross_vals) < 0.0800, ...
+    sprintf('Extended SSS mean zero-lag cross-correlation %.4f exceeds 0.08 limit', mean(zero_cross_vals)));
+
+% 2. Distinct shift differential pairs have all-lag cross-correlation < 0.3000
 assert(max_all_cross < 0.3000, ...
     sprintf('Extended SSS maximum all-lag cross-correlation %.4f exceeds 0.30 limit', max_all_cross));
+
+% 3. Adversarial shift-collision stress test (PCIs sharing identical delta = (m0 - m1) mod 255)
+% PCI 0 (m0=0, m1=0) and PCI 319 (m0=64, m1=64) share delta=0.
+% At zero lag (synchronous grid), isolation is strictly preserved (<= 0.1500).
+% At lag 64, aperiodic overlap reaches (240 - 64)/240 = 0.7333 <= 0.7500.
+s0 = double(nr_sim.sequences.gen_ExtendedSSS(0));
+s319 = double(nr_sim.sequences.gen_ExtendedSSS(319));
+c0_collision = abs(sum(s0(:) .* s319(:))) / 240;
+call_collision = max(abs(xcorr(s0(:), s319(:)))) / 240;
+assert(c0_collision <= 0.1500, ...
+    sprintf('Shift-collision zero-lag cross-correlation %.4f exceeds 0.15 limit', c0_collision));
+assert(call_collision <= 0.7500, ...
+    sprintf('Shift-collision all-lag peak %.4f exceeds theoretical overlap bound 0.75', call_collision));
```

---

## 5. Verification Method

### 5.1 Verification Commands in MATLAB
Execute the following verification block in MATLAB:
```matlab
% 1. Verify candidate test logic in MATLAB session
addpath('C:\workspace\nr_ics');
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
        c0 = abs(sum(s_i(:) .* s_j(:))) / 240;
        pair_idx = pair_idx + 1;
        zero_cross_vals(pair_idx) = c0;
        max_zero_cross = max(max_zero_cross, c0);
        c_all = max(abs(xcorr(s_i(:), s_j(:)))) / 240;
        max_all_cross = max(max_all_cross, c_all);
    end
end

assert(max_zero_cross <= 0.1500);
assert(mean(zero_cross_vals) < 0.0800);
assert(max_all_cross < 0.3000);

s0 = double(nr_sim.sequences.gen_ExtendedSSS(0));
s319 = double(nr_sim.sequences.gen_ExtendedSSS(319));
assert(abs(sum(s0(:) .* s319(:))) / 240 <= 0.1500);
assert(max(abs(xcorr(s0(:), s319(:)))) / 240 <= 0.7500);
fprintf('Test 11 replacement logic verified successfully.\n');
```

### 5.2 Independent Verification Metrics
- `max_zero_cross`: Expected `0.1417` (must be $\le 0.1500$)
- `mean(zero_cross_vals)`: Expected `0.0454` (must be $< 0.0800$)
- `max_all_cross`: Expected `0.2583` (must be $< 0.3000$)
- `c0_collision` (PCI 0 vs 319): Expected `0.0500` (must be $\le 0.1500$)
- `call_collision` (PCI 0 vs 319): Expected `0.7333` (must be $\le 0.7500$)

### 5.3 Invalidation Conditions
This report is invalidated if:
1. `max_zero_cross` on the baseline 9 test cells exceeds 0.1500.
2. The shift-collision pair (PCI 0, PCI 319) exhibits zero-lag cross-correlation $> 0.1500$.
3. The shift-collision pair (PCI 0, PCI 319) exhibits all-lag peak $> 0.7500$.
4. Test 9 (lines 127-136) contains any cross-correlation logic.
