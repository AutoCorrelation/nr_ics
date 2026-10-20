# Handoff Report: SSS Generator Input Hardening Formulation (M1-Iter2-1)

**Agent**: `explorer_m1_iter2_1` (Teamwork Explorer: investigator, synthesizer)  
**Date**: 2026-09-28T03:30:30Z  
**Target File**: `C:\workspace\nr_ics\+nr_sim\+sequences\gen_SSS.m`  
**Milestone**: Milestone 1 (Iteration 2)  
**Handoff Type**: Hard  

---

## 1. Observation

### 1.1 Direct File Inspection: `+nr_sim/+sequences/gen_SSS.m`
Inspection of `gen_SSS.m` (lines 23–40) reveals the input parsing logic:

```matlab
23:     % Input argument parsing
24:     if nargin == 0
25:         N_ID_1 = 0;
26:         N_ID_2 = 0;
27:     elseif nargin == 1
28:         N_ID_cell = varargin{1};
29:         validateattributes(N_ID_cell, {'numeric'}, ...
30:             {'scalar', 'integer', '>=', 0, '<=', 1007}, mfilename, 'N_ID_cell');
31:         N_ID_1 = floor(double(N_ID_cell) / 3);
32:         N_ID_2 = mod(double(N_ID_cell), 3);
33:     else
34:         N_ID_1 = varargin{1};
35:         N_ID_2 = varargin{2};
36:         validateattributes(N_ID_1, {'numeric'}, ...
37:             {'scalar', 'integer', '>=', 0, '<=', 335}, mfilename, 'N_ID_1');
38:         validateattributes(N_ID_2, {'numeric'}, ...
39:             {'scalar', 'integer', '>=', 0, '<=', 2}, mfilename, 'N_ID_2');
40:     end
```

### 1.2 Verbatim Defect Verification in MATLAB
Evaluation of `gen_SSS.m` with edge inputs produced the following behaviors:

1. **Defect 1 — Excess arguments silently accepted**:
   Command: `nr_sim.sequences.gen_SSS(1, 2, 3)`
   Result: Executes silently without error and returns `[127 x 1 double]`. Line 33 uses `else` without verifying `nargin <= 2`. Any argument at index 3 or higher is ignored without warning or validation.
2. **Defect 2 — Empty input unhandled crash**:
   Command: `nr_sim.sequences.gen_SSS([])`
   Verbatim error:
   ```text
   N_ID_cell은(는) 스칼라이어야 합니다. (N_ID_cell must be scalar.)
   ```
   Line 28 passes `varargin{1} = []` directly to `validateattributes(N_ID_cell, {'numeric'}, {'scalar', ...})`, which immediately throws because `[]` is 0x0 (not scalar).

### 1.3 Interface Asymmetry Across Sibling Generators
Inspection of sibling sequence generators reveals consistent empty input defaulting:
- `+nr_sim/+sequences/gen_PSSNR.m` (lines 21–23):
  ```matlab
  if nargin < 1 || isempty(N_ID_2)
      N_ID_2 = 0;
  ```
- `+nr_sim/+sequences/gen_ExtendedSSS.m` (lines 34–36):
  ```matlab
  if nargin < 1 || isempty(N_ID_cell)
      N_ID_cell = 0;
  ```
- `+nr_sim/+sequences/gen_PBCHDMRS.m` (lines 21–33):
  ```matlab
  if nargin < 1 || isempty(N_ID_cell)
      N_ID_cell = 0;
  ...
  if nargin < 2 || isempty(ibar_SSB)
      ibar_SSB = 0;
  ```
`gen_SSS` was the sole sequence generator failing when passed empty arguments.

---

## 2. Logic Chain

1. **Upper-Bound Argument Defense**:
   - *Observation 1.1 & 1.2.1*: `gen_SSS` accepts variable arguments (`varargin`). When `nargin >= 3`, the `else` branch extracts only `varargin{1}` and `varargin{2}`, discarding subsequent inputs without check.
   - *Inference*: Adding MATLAB built-in `narginchk(0, 2);` at the entry of `gen_SSS` restricts the argument count to the interval $[0, 2]$. If `nargin > 2`, MATLAB throws an immediate standard error (`MATLAB:narginchk:tooManyInputs`).
2. **Empty Argument Defaulting Semantics**:
   - *Observation 1.2.2 & 1.3*: `gen_PSSNR([])`, `gen_ExtendedSSS([])`, and `gen_PBCHDMRS([], [])` default missing or empty inputs to zero.
   - *Inference*: In `gen_SSS`:
     - When called with 1 argument (`nargin == 1`): If `isempty(varargin{1})`, assign `N_ID_1 = 0; N_ID_2 = 0;` (equivalent to $N_{ID}^{cell} = 0$). Otherwise, validate scalar range $[0, 1007]$.
     - When called with 2 arguments (`nargin == 2`): If `isempty(varargin{1})`, default `N_ID_1 = 0;` else validate $[0, 335]$. If `isempty(varargin{2})`, default `N_ID_2 = 0;` else validate $[0, 2]$.
3. **Downstream Call Site Compatibility**:
   - *Observation*: `map_ssb_grid.m` (line 138) and `demap_ssb_grid.m` (line 137) call `nr_sim.sequences.gen_SSS(N_ID_1, N_ID_2)` with two valid integer arguments. `test_adversarial_sequences.m` calls both `gen_SSS(pci)` and `gen_SSS(n1, n2)`.
   - *Inference*: The proposed modification is 100% backwards-compatible and strictly additive, preserving exact outputs for all valid inputs while eliminating the vulnerability and asymmetry.

---

## 3. Caveats

1. **Subagent Scope Constraint**: Per Teamwork explorer guidelines, this report provides the exact formulated modification, diff patch, and replacement file, but does not modify the production source file `+nr_sim/+sequences/gen_SSS.m` directly. Implementation is delegated to the designated implementer.
2. **`test_sequences.m` Test 11 Cross-Correlation Assertion**: Challenger `challenger_m1_1` also reported a fragile assertion in `tests/test_sequences.m` line 181 (`assert(max_all_cross < 0.3000)`). That test suite assertion is independent of `gen_SSS.m` and should be addressed in its own task.

---

## 4. Conclusion & Formulated Code Modification

### 4.1 Exact Code Modification

#### Target File: `C:\workspace\nr_ics\+nr_sim\+sequences\gen_SSS.m`

#### Modification 1: Help Docstring Clarification (Lines 3–13)

**Before**:
```matlab
%   d_sss = nr_sim.sequences.gen_SSS(N_ID_1, N_ID_2) generates length-127 SSS
%   from N_ID_1 in [0, 335] and N_ID_2 in [0, 2].
%
%   d_sss = nr_sim.sequences.gen_SSS(N_ID_cell) generates length-127 SSS
%   from physical layer cell ID N_ID_cell in [0, 1007], decomposing it as:
%       N_ID_1 = floor(N_ID_cell / 3)
%       N_ID_2 = mod(N_ID_cell, 3)
```

**After**:
```matlab
%   d_sss = nr_sim.sequences.gen_SSS() generates length-127 SSS for cell ID 0
%   (N_ID_1 = 0, N_ID_2 = 0). Default: 0.
%
%   d_sss = nr_sim.sequences.gen_SSS(N_ID_cell) generates length-127 SSS
%   from physical layer cell ID N_ID_cell in [0, 1007], decomposing it as:
%       N_ID_1 = floor(N_ID_cell / 3)
%       N_ID_2 = mod(N_ID_cell, 3)
%   If N_ID_cell is empty ([]), it defaults to 0.
%
%   d_sss = nr_sim.sequences.gen_SSS(N_ID_1, N_ID_2) generates length-127 SSS
%   from N_ID_1 in [0, 335] and N_ID_2 in [0, 2].
%   If either N_ID_1 or N_ID_2 is empty ([]), it defaults to 0.
```

---

#### Modification 2: Argument Parsing and Validation (Lines 23–40)

**Before (Lines 23–40)**:
```matlab
    % Input argument parsing
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

**After (Drop-in Replacement Chunk)**:
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

---

### 4.2 Available Artifacts in Explorer Folder

1. **Unified Git Diff Patch**:
   `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_1\gen_SSS.patch`
2. **Complete Replacement File**:
   `C:\workspace\nr_ics\.agents\teamwork\explorer_m1_iter2_1\proposed_gen_SSS.m`

---

## 5. Verification Method

### 5.1 Sandbox Verification Executed
A 15-case test suite was executed in MATLAB against the proposed implementation. Results:

| # | Test Call | Expected Behavior | Actual Sandbox Result | Status |
|---|---|---|---|---|
| 1 | `gen_SSS()` | Returns $[0, 0]$ sequence | Returned $[0, 0]$ sequence | **PASS** |
| 2 | `gen_SSS([])` | Returns $[0, 0]$ sequence | Returned $[0, 0]$ sequence | **PASS** |
| 3 | `gen_SSS([], [])` | Returns $[0, 0]$ sequence | Returned $[0, 0]$ sequence | **PASS** |
| 4 | `gen_SSS(100)` | Returns $[33, 1]$ sequence | Returned $[33, 1]$ sequence | **PASS** |
| 5 | `gen_SSS(33, 1)` | Returns $[33, 1]$ sequence | Returned $[33, 1]$ sequence | **PASS** |
| 6 | `gen_SSS(50, [])` | Returns $[50, 0]$ sequence | Returned $[50, 0]$ sequence | **PASS** |
| 7 | `gen_SSS([], 2)` | Returns $[0, 2]$ sequence | Returned $[0, 2]$ sequence | **PASS** |
| 8 | `gen_SSS(1, 2, 3)` | Throws `narginchk` error | Threw `입력 인수가 너무 많습니다.` | **PASS** |
| 9 | `gen_SSS(-1)` | Throws validation error | Threw `N_ID_cell >= 0` error | **PASS** |
| 10 | `gen_SSS(1008)` | Throws validation error | Threw `N_ID_cell <= 1007` error | **PASS** |
| 11 | `gen_SSS(336, 0)` | Throws validation error | Threw `N_ID_1 <= 335` error | **PASS** |
| 12 | `gen_SSS(0, 3)` | Throws validation error | Threw `N_ID_2 <= 2` error | **PASS** |
| 13 | `gen_SSS("0")` | Throws validation error | Threw type error | **PASS** |
| 14 | `gen_SSS(NaN)` | Throws validation error | Threw integer error | **PASS** |
| 15 | `gen_SSS([0 1])` | Throws validation error | Threw scalar error | **PASS** |

### 5.2 Independent Verification Instructions for Implementer
After applying `gen_SSS.patch` or the replacement chunk, run the following verification in MATLAB:

```matlab
addpath('C:\workspace\nr_ics');

% 1. Verify excess argument rejection
try
    nr_sim.sequences.gen_SSS(1, 2, 3);
    error('FAILED: gen_SSS(1, 2, 3) must throw narginchk error');
catch ME
    assert(strcmp(ME.identifier, 'MATLAB:narginchk:tooManyInputs') || ...
           contains(ME.message, '너무 많습니다') || contains(ME.message, 'Too many'), ...
           'Expected narginchk too many inputs error');
end

% 2. Verify empty input defaulting
ref_sss0 = nrSSS(0);
assert(isequal(nr_sim.sequences.gen_SSS([]), ref_sss0), 'gen_SSS([]) must match nrSSS(0)');
assert(isequal(nr_sim.sequences.gen_SSS(), ref_sss0), 'gen_SSS() must match nrSSS(0)');
assert(isequal(nr_sim.sequences.gen_SSS([], []), ref_sss0), 'gen_SSS([], []) must match nrSSS(0)');

% 3. Run regression suites
run('C:\workspace\nr_ics\tests\test_sequences.m');
run('C:\workspace\nr_ics\tests\test_adversarial_sequences.m');
```

### 5.3 Invalidation Conditions
This handoff report is invalidated if:
1. `narginchk(0, 2)` causes unexpected errors for 0, 1, or 2 input arguments.
2. `gen_SSS([])` fails to match `nrSSS(0)` bit-for-bit.
3. Any of the 1008 valid PCIs fail in `test_adversarial_sequences.m`.
