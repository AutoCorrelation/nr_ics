# Handoff Report: Empirical Adversarial Challenge of SSB Sequences (M1-1)

**Agent**: `challenger_m1_1` (EMPIRICAL CHALLENGER: critic, specialist)  
**Date**: 2026-09-28T03:26:00Z  
**Milestone**: Milestone 1 (SSB Sequence Generation and Resource Grid Mapping)  
**Target Code**: `+nr_sim/+sequences/` (`gen_PSSNR.m`, `gen_SSS.m`, `gen_ExtendedSSS.m`, `gen_PBCHDMRS.m`) and `tests/test_sequences.m`  
**Harness Created**: `tests/test_adversarial_sequences.m`  
**Verdict**: `VERDICT: REQUEST_CHANGES`

---

## 1. Observation

### 1.1 Direct Inspection of Implementation Files
1. **PSS Generator (`+nr_sim/+sequences/gen_PSSNR.m`)**:
   - Lines 20-26:
     ```matlab
     if nargin < 1 || isempty(N_ID_2)
         N_ID_2 = 0;
     else
         validateattributes(N_ID_2, {'numeric'}, ...
             {'scalar', 'integer', '>=', 0, '<=', 2}, mfilename, 'N_ID_2');
     end
     ```
   - Uses recurrence $x(i+8) = \bmod(x(i+5) + x(i+1), 2)$ with seed $[0, 1, 1, 0, 1, 1, 1]$.
   - Cyclic shift: $m = (n + 43 \cdot N_{ID}^{(2)}) \bmod 127$.
   - Output: `d_pss = (1 - 2 * x(m + 1)).';` `[127 x 1 double]`.

2. **SSS Generator (`+nr_sim/+sequences/gen_SSS.m`)**:
   - Lines 23-40:
     ```matlab
     if nargin == 0
         N_ID_1 = 0;
         N_ID_2 = 0;
     elseif nargin == 1
         N_ID_cell = varargin{1};
         validateattributes(N_ID_cell, {'numeric'}, ...
             {'scalar', 'integer', '>=', 0, '<=', 1007}, mfilename, 'N_ID_cell');
         N_ID_1 = floor(double(N_ID_cell) / 3);
         N_ID_2 = mod(double(N_ID_cell), 3);
     else
         N_ID_1 = varargin{1};
         N_ID_2 = varargin{2};
         validateattributes(N_ID_1, {'numeric'}, ...
             {'scalar', 'integer', '>=', 0, '<=', 335}, mfilename, 'N_ID_1');
         validateattributes(N_ID_2, {'numeric'}, ...
             {'scalar', 'integer', '>=', 0, '<=', 2}, mfilename, 'N_ID_2');
     end
     ```
   - **Vulnerability Observation 1 (Missing `nargin` Upper Bound Check)**: Line 33 uses `else`. If `nargin >= 3` (e.g., `gen_SSS(1, 2, 3)` or `gen_SSS(0, 0, 'extra_arg')`), the function silently ignores all arguments beyond the first two without validation or error.
   - **Vulnerability Observation 2 (Empty Input Asymmetry)**: Calling `gen_SSS([])` fails with error:
     ```text
     N_ID_cell은(는) 스칼라이어야 합니다. (N_ID_cell must be scalar.)
     ```
     because `isempty(varargin{1})` is not handled, unlike `gen_PSSNR([])`, `gen_ExtendedSSS([])`, and `gen_PBCHDMRS([])` which gracefully default to 0.

3. **Extended SSS Generator (`+nr_sim/+sequences/gen_ExtendedSSS.m`)**:
   - Lines 60-63:
     ```matlab
     pci = double(N_ID_cell);
     m0 = mod(pci, 255);
     m1 = floor(pci / 255) * 64;
     ```
   - Length 240 truncated base-255 Gold sequence.
   - Distinct sequences: 1008 out of 1008 unique.

4. **Unit Test Suite (`tests/test_sequences.m`)**:
   - Lines 164-183:
     ```matlab
     test_cells = [0, 1, 10, 100, 254, 255, 511, 700, 1007];
     max_zero_cross = 0;
     max_all_cross = 0;
     for i = 1:length(test_cells)
         for j = (i+1):length(test_cells)
             ...
             c_all = max(abs(xcorr(s_i(:), s_j(:)))) / 240;
             max_all_cross = max(max_all_cross, c_all);
         end
     end
     assert(max_zero_cross <= 0.1500, ...);
     assert(max_all_cross < 0.3000, ...);
     ```
   - **Flawed Assertion Observation**: `test_sequences.m` tested only 9 cherry-picked cell IDs. If representative PCIs sharing identical shift differential $\Delta = (m_0 - m_1) \pmod{255}$ are included (e.g., PCI 0 and PCI 319, or PCI 0 and PCI 957), `max_all_cross` reaches $0.7333$ and $0.7375$, completely failing the `< 0.3000` assertion.

---

### 1.2 Quantitative Empirical Verification Results

Verification harness `tests/test_adversarial_sequences.m` was executed in MATLAB R2026a Update 5:

#### A. 3GPP TS 38.211 Oracle Conformance
- **PSS (`nrPSS`)**: All 3 sectors ($N_{ID}^{(2)} \in \{0, 1, 2\}$) match `nrPSS` bit-for-bit with 0 numerical difference. Auto-correlation peak is 127; off-peak sidelobes are bounded by 17.
- **SSS (`nrSSS`) Exhaustive Full-Space Check**:
  - Tested **ALL 1008 PCIs** ($0 \dots 1007$) in both 1-argument (`gen_SSS(pci)`) and 2-argument (`gen_SSS(n1, n2)`) formats against `nrSSS(pci)`.
  - Exactly **128,016 symbols** evaluated.
  - Mismatches: **0**.
  - Maximum numerical error: **0.000000000000000e+00**.
- **PBCH DMRS (`nrPBCHDMRS`)**:
  - Evaluated across boundary and internal PCIs with all 8 $\bar{i}_{SSB} \in [0, 7]$.
  - `gen_PBCHDMRS` matches `nrPBCHDMRS` identically (max diff $< 10^{-12}$).
  - Standalone TS 38.211 §5.2.1 fallback PRBS generator tested directly without toolbox: matches `nrPBCHDMRS` with maximum difference of $1.57009 \times 10^{-16}$.

#### B. Extended SSS Full Cell ID Space [0, 1007] Statistics
- **Auto-Correlation Peak**: Inner product $\sum_{n=0}^{239} d_{\text{ext}}(n)^2 = 240$ exactly for **1008 out of 1008 PCIs**.
- **Uniqueness**: Exactly 1008 unique sequences out of 1008 (no duplicate sequences).
- **Ensemble PSLR Distribution ($20 \log_{10}(240 / \text{max\_sidelobe})$)**:
  - Benchmark PCI 0: **16.72 dB** (max sidelobe = 35)
  - Benchmark PCI 1: **17.23 dB** (max sidelobe = 33)
  - Boundary PCI 335: **12.80 dB** (max sidelobe = 55)
  - Boundary PCI 1007: **14.93 dB** (max sidelobe = 43)
  - Mean PSLR across all 1008 PCIs: **15.83 dB**
  - Median PSLR across all 1008 PCIs: **16.24 dB**
  - Standard deviation: **1.76 dB**
  - Minimum PSLR: **10.70 dB** (PCI 348, max sidelobe = 70)
  - Maximum PSLR: **19.65 dB** (PCI 358, max sidelobe = 25)
  - **PCIs with PSLR $\ge 15.0$ dB**: **710 / 1008 (70.44%)**
  - **PCIs with PSLR $< 15.0$ dB**: **298 / 1008 (29.56%)**

#### C. Cross-Correlation Distribution Across Full Space (507,528 Pairs)
- **Zero-Lag Cross-Correlation ($C_0(i, j) = \frac{1}{240} |s_i^T s_j|$)**:
  - Mean: **0.0411**
  - Median: **0.0250**
  - Standard deviation: **0.0388**
  - 90th percentile: **0.0917**
  - 95th percentile: **0.1250**
  - 99th percentile: **0.1500**
  - Pairs with $C_0 \le 0.1500$: **505,048 / 507,528 (99.51%)**
  - Pairs with $C_0 > 0.1500$: **2,480 / 507,528 (0.49%)**
  - Worst-case pair: PCI 514 and PCI 765, $C_0 = 64/240 = 0.2667$.

#### D. All-Lag Cross-Correlation Collision Stress Test
- For any two PCIs $A$ and $B$ where $(m_0(A) - m_1(A)) \equiv (m_0(B) - m_1(B)) \pmod{255}$, the sequences are circular shifts of the same base Gold code.
- Tested Pair (PCI 0, PCI 319):
  - $m_0(0)=0, m_1(0)=0 \implies \Delta = 0$
  - $m_0(319)=64, m_1(319)=64 \implies \Delta = 0$
  - Shift difference: 64 samples. Truncated overlap: $240 - 64 = 176$ samples.
  - Cross-correlation peak: **176 at lag 64** ($176/240 = \mathbf{0.7333}$).
- Tested Pair (PCI 0, PCI 957):
  - $m_0(957)=192, m_1(957)=192 \implies \Delta = 0$
  - Shift difference: $255 - 192 = 63$. Overlap: $240 - 63 = 177$ samples.
  - Cross-correlation peak: **177 at lag 63** ($177/240 = \mathbf{0.7375}$).
- Zero-lag cross-correlation for both pairs:
  - $(0, 319)$: $C_0 = 12/240 = 0.0500 \ll 0.1500$.
  - $(0, 957)$: $C_0 = 4/240 = 0.0167 \ll 0.1500$.

#### E. Adversarial Input Robustness (38 Test Cases)
- Out of 38 malformed/out-of-range inputs tested, 37 were correctly rejected via `validateattributes`.
- 1 unhandled failure: `gen_SSS(1, 2, 3)` executes silently without error.

---

## 2. Logic Chain

1. **PSS & SSS Implementation Correctness**:
   - *Observation 1.2.A*: Both `gen_PSSNR` and `gen_SSS` exhibit 100% bit-exact equivalence with MATLAB 5G Toolbox references (`nrPSS` for all 3 sectors, `nrSSS` across all 1008 PCIs).
   - *Inference*: The core mathematical recurrence and polynomial formulations in `gen_PSSNR.m` and `gen_SSS.m` strictly adhere to 3GPP TS 38.211 §7.4.2.2.1 and §7.4.2.3.1.

2. **Extended SSS Mathematical Realities vs. Project Assumptions**:
   - *Observation 1.2.B & 1.2.C*: Qualcomm Design A constructs Extended SSS by truncating length-255 Gold sequences to 240 subcarriers.
   - *Inference*:
     - In the frequency domain, SSS is detected synchronously on subcarriers $0 \dots 239$. Synchronous inter-cell isolation is determined by **zero-lag cross-correlation**, which averages $0.0411$ with $99.51\%$ of all 507,528 pairs $\le 0.1500$.
     - However, aperiodic auto-correlation sidelobes of truncated Gold codes are shift-dependent: while PCI 0 achieves $16.72\text{ dB}$ PSLR and the ensemble mean is $15.83\text{ dB}$, individual PCIs experience PSLR down to $10.70\text{ dB}$ (29.56% of PCIs have PSLR $< 15.0\text{ dB}$).
     - Furthermore, because $1008 > 255$, multiple PCIs share identical shift differentials $\Delta = (m_0 - m_1) \pmod{255}$. When two such PCIs are correlated across all time/frequency lags, an auto-correlation peak of the shared Gold code appears at the shift difference lag, reaching up to $0.7375$.
     - Therefore, asserting that *all* PCIs have all-lag cross-correlation $< 0.3000$ (as in `tests/test_sequences.m` line 181) is mathematically untenable for this sequence design. Test 11 passed only because the 9 cell IDs were cherry-picked to avoid shared $\Delta$ values.

3. **Software Vulnerability & Contract Violations**:
   - *Observation 1.1.2*: `gen_SSS(varargin)` does not check `nargin <= 2`. Invoking `gen_SSS(1, 2, 3)` silently ignores the 3rd argument.
   - *Observation 1.1.2*: `gen_SSS([])` fails with an unhandled exception instead of defaulting to 0, creating interface inconsistency with `gen_PSSNR([])`, `gen_ExtendedSSS([])`, and `gen_PBCHDMRS([])`.
   - *Inference*: In accordance with the EMPIRICAL CHALLENGER mandate, unhandled malformed inputs and invalid assertions require remediation before Milestone 1 sequence approval.

---

## 3. Caveats

1. **Impact of All-Lag Cross-Correlation in OFDM Receivers**:
   - The high all-lag cross-correlation peak ($0.7375$) between delta-matched PCIs occurs at non-zero lags (e.g., lag 64). In the physical receiver pipeline (Milestone 3), coarse timing and frequency synchronization are already locked by PSS prior to SSS detection. Frequency-domain SSS correlation is evaluated at zero subcarrier lag, where cross-correlation is only $0.0500$. Thus, this is not a fatal flaw in the physical communication link, but it **is** an invalid specification/assertion in `tests/test_sequences.m`.
2. **Fallback PRBS Performance**:
   - The standalone fallback implementation in `gen_PBCHDMRS.m` lines 41-73 is verified bit-exact against `nrPBCHDMRS`, but is bypassed when 5G Toolbox is installed. Testing confirmed that even if 5G Toolbox is omitted, numerical equivalence is maintained to $< 1.6 \times 10^{-16}$.

---

## 4. Conclusion & Required Changes

**Verdict**: `VERDICT: REQUEST_CHANGES`

The core sequence generators (`gen_PSSNR`, `gen_SSS`, `gen_ExtendedSSS`, `gen_PBCHDMRS`) correctly generate all 3GPP and Rel-20 sequences with 100% bit-exactness to 5G Toolbox standards. However, changes are requested to resolve two input handling defects and one invalid test suite assertion:

### Requested Changes

1. **Add Input Argument Validation to `gen_SSS.m`**:
   - Enforce upper bound on `nargin`: if `nargin > 2`, throw an error (e.g., via `narginchk(0, 2);` or explicit check `if nargin > 2, error(...); end`).
   - Support empty input defaulting: allow `gen_SSS([])` to default to $N_{ID}^{cell} = 0$, matching `gen_PSSNR([])` and `gen_ExtendedSSS([])`.

2. **Fix Flawed Assertion in `tests/test_sequences.m`**:
   - Update Test 11 in `tests/test_sequences.m`: replace the invalid global assertion `assert(max_all_cross < 0.3000)` with:
     ```matlab
     % Zero-lag cross-correlation governs synchronous subcarrier isolation
     assert(max_zero_cross <= 0.1500, ...
         sprintf('Zero-lag cross-correlation %.4f exceeds 0.15', max_zero_cross));
     ```
   - If all-lag cross-correlation is tested, document that PCIs sharing identical $\Delta = (m_0 - m_1) \pmod{255}$ (e.g., PCI 0 and PCI 319) exhibit aperiodic cross-correlation peaks up to $0.7375$ at the cyclic shift difference lag, or restrict the all-lag assertion to distinct-$\Delta$ pairs.

3. **Clarify PSLR Specification in `PROJECT.md` / Documentation**:
   - Clarify that the requirement "PSLR $> 15\text{ dB}$" applies to benchmark PCI 0 ($16.72\text{ dB}$) and the ensemble mean ($15.83\text{ dB}$), and note that across the full 1008-PCI space, individual PCIs range from $10.70\text{ dB}$ to $19.65\text{ dB}$ due to base-255 truncation.

---

## 5. Verification Method

### 5.1 Test Commands
Execute the following verification scripts in MATLAB:
```matlab
% 1. Run standard sequence unit tests
run('C:\workspace\nr_ics\tests\test_sequences.m');

% 2. Run adversarial challenge test harness
run('C:\workspace\nr_ics\tests\test_adversarial_sequences.m');
```

### 5.2 Invalidation Conditions
This handoff report is invalidated if:
1. `gen_SSS(1, 2, 3)` throws an error in current code without modifications.
2. `test_sequences.m` line 181 passes when `319` is added to `test_cells`.
3. Extended SSS sequence generation produces duplicate sequences among the 1008 PCIs.
4. Numerical difference between `gen_SSS` and `nrSSS` exceeds 0 for any of the 1008 PCIs.

---

## Challenge Report Summary

**Overall risk assessment**: MEDIUM

### Challenges

#### [Medium] Challenge 1: Unhandled Malformed Input in `gen_SSS`
- **Assumption challenged**: All sequence generators rigorously validate input argument counts.
- **Attack scenario**: Calling `gen_SSS(0, 0, 'malformed', [1 2 3])` silently executes without error because `varargin` uses `else` without `nargin` validation.
- **Blast radius**: Undetected developer typo or pipeline calling contract error propagating corrupted parameters into physical layer grid mapping.
- **Mitigation**: Add `narginchk(0, 2);` at the top of `gen_SSS.m`.

#### [Medium] Challenge 2: Fragile & Cherry-Picked Assertion in `test_sequences.m`
- **Assumption challenged**: Length-240 Extended SSS sequences have all-lag cross-correlation $< 0.3000$ across cell IDs.
- **Attack scenario**: Evaluating PCIs sharing $\Delta = (m_0 - m_1) \pmod{255}$ (e.g., PCI 0 and PCI 319) yields cross-correlation peak of $0.7333$, failing test suite.
- **Blast radius**: Test suite fails unpredictably whenever random PCIs are evaluated during Monte-Carlo regression runs.
- **Mitigation**: Update test suite to evaluate zero-lag cross-correlation ($< 0.15$) and document physical reason for all-lag peaks on shift-collision pairs.

#### [Low] Challenge 3: Inconsistent Empty Input Handling
- **Assumption challenged**: Sequence generators have uniform default calling semantics.
- **Attack scenario**: `gen_PSSNR([])` and `gen_ExtendedSSS([])` succeed, but `gen_SSS([])` crashes with `validateattributes` error.
- **Blast radius**: Pipeline wrapper code passing empty defaults fails on SSS while passing on PSS/Extended SSS.
- **Mitigation**: Add `isempty` check before scalar validation in `gen_SSS.m`.

### Stress Test Results

| Test Scenario | Expected Behavior | Actual Behavior | Result |
|---|---|---|---|
| PSS bit-matching (3 sectors) vs `nrPSS` | Identical bit-level match | 100% bit match, diff = 0 | **PASS** |
| SSS bit-matching (1008 PCIs) vs `nrSSS` | Identical bit-level match | 100% bit match, diff = 0 | **PASS** |
| Ext SSS Auto-corr peak (1008 PCIs) | Peak = 240 exactly | Peak = 240 for all 1008 PCIs | **PASS** |
| Ext SSS Uniqueness (1008 PCIs) | 1008 unique sequences | 1008 distinct sequences | **PASS** |
| Ext SSS Mean PSLR across 1008 PCIs | $> 15.0\text{ dB}$ | $15.83\text{ dB}$ (PCI 0: $16.72\text{ dB}$) | **PASS** |
| Ext SSS Min PSLR across 1008 PCIs | $> 15.0\text{ dB}$ | $10.70\text{ dB}$ (29.56% $< 15\text{ dB}$) | **FINDING** |
| Ext SSS Mean Zero-Lag Cross-Correlation | $< 0.05$ | $0.0411$ (99.51% $\le 0.15$) | **PASS** |
| Ext SSS All-Lag Cross-Correlation (0 vs 319) | $< 0.30$ (per `test_sequences.m`) | $0.7333$ (peak 176 at lag 64) | **FAIL** |
| PBCH DMRS vs `nrPBCHDMRS` | Identical match | 100% match, diff $< 10^{-12}$ | **PASS** |
| Standalone DMRS fallback vs `nrPBCHDMRS` | Identical match | 100% match, diff $= 1.57 \times 10^{-16}$ | **PASS** |
| Out-of-bounds input rejection (37 cases) | Error thrown | Error thrown | **PASS** |
| `gen_SSS(1, 2, 3)` excess argument | Error thrown | Ignored without error | **FAIL** |
| `gen_SSS([])` empty input default | Default to 0 | Throws scalar validation error | **FAIL** |

### Unchallenged Areas
- **RF impairments & channel fading**: Deferred to Milestone 2 (M2 scope).
- **Physical PBCH decoding chain**: Deferred to Milestone 3 (M3 scope).
