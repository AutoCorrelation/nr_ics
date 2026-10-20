# Handoff Report: Workspace, Baseline Assets & MATLAB Environment Survey

**Agent**: `explorer_survey_1` (Codebase & Environment Explorer)  
**Date**: 2026-09-28  
**Scope**: Workspace survey (`document/`, `dumpdataNR/`, legacy MATLAB files), MATLAB runtime environment verification, toolboxes verification, and PHY signal processing chain validation.

---

## 1. Observation

### 1.1 Workspace File Tree & Baseline Assets
A full scan of `C:\workspace\nr_ics` revealed the following non-agent files:

| File Path | Size (Bytes) | Category | Description |
|---|---|---|---|
| `document/cpLength.md` | 1,446 | Reference Spec | 3GPP TS 38.211 CP lengths for 30 kHz SCS, 512 FFT ($f_s = 15.36\text{ MHz}$). |
| `dumpdataNR/dump_kt_20260908_145721.dat` | 2,480,000 | Raw Baseband Capture | KT 5G NR baseband IQ recording (620,000 samples). |
| `dumpdataNR/dump_lgu_20260908_145721.dat` | 2,480,000 | Raw Baseband Capture | LGU+ 5G NR baseband IQ recording (620,000 samples). |
| `dumpdataNR/dump_skt_20260908_145721.dat` | 2,480,000 | Raw Baseband Capture | SKT 5G NR baseband IQ recording (620,000 samples). |
| `gen_PSSNR.m` | 711 | Baseline MATLAB Function | TS 38.211 m-sequence generator for NR PSS ($N_{ID}^{(2)} \in \{0, 1, 2\}$). |
| `loaddump.m` | 763 | Baseline MATLAB Utility | Binary int16 IQ dump reader with normalization by 32767. |
| `test.m` | 578 | Baseline Test Script | Skeleton script demonstrating dump load, instantaneous power plot, and PSS generation. |

### 1.2 Inspection of Existing Baseline Scripts
1. **`document/cpLength.md`**:
   - Subcarrier spacing: $30\text{ kHz}$, sampling rate: $15.36\text{ MHz}$, FFT size: $512$.
   - Normal CP: $36\text{ samples}$ ($512 \times 144 / 2048 = 36$). Total symbol duration: $548\text{ samples}$ ($\approx 35.68\,\mu\text{s}$).
   - First symbol CP: $44\sim 52\text{ samples}$ ($512 \times 208 / 2048 = 52$). Total symbol duration: $556\sim 564\text{ samples}$.
   - SSB block (4 symbols): $548 \times 4 = 2,192\text{ samples}$.
2. **`loaddump.m`**:
   - Reads binary interleaved 16-bit signed integers: `raw = fread(fid, [2, inf], 'int16');`
   - Maps row 1 to In-phase (I) and row 2 to Quadrature (Q): `x = complex(raw(1, :), raw(2, :)) / 32767;`
   - File size $2,480,000\text{ bytes} \div 4\text{ bytes/sample} = 620,000\text{ complex samples}$.
   - Duration: $620,000 / 15,360,000\text{ s} \approx 40.3646\text{ ms}$ (approx 4 complete $10\text{ ms}$ radio frames).
   - Mean power and peak amplitude verified:
     - `dump_kt_...`: Mean power $0.093449$, peak $1.3592$.
     - `dump_lgu_...`: Mean power $0.003885$, peak $0.9356$.
     - `dump_skt_...`: Mean power $0.004375$, peak $1.1056$.
3. **`gen_PSSNR.m`**:
   - Generates length-127 sequence via 7th-order primitive polynomial $x^7 + x^4 + 1$ with initial condition $x(0..6) = [0, 1, 1, 0, 1, 1, 1]$.
   - Generates $m = (n + 43 N_{ID}^{(2)}) \bmod 127$ and BPSK modulation $d_{PSS}(n) = 1 - 2x(m)$.
   - Verified against MATLAB 5G Toolbox `nrPSS(nid2)`: Maximum discrepancy is exactly `0.000000e+00` for all $N_{ID}^{(2)} \in \{0, 1, 2\}$.
4. **`test.m`**:
   - PSS cross-correlation on `dump_skt_...` reveals prominent correlation peaks:
     - $N_{ID}^{(2)} = 0$: Peak $19.5229$ at sample $112648$.
     - $N_{ID}^{(2)} = 1$: Peak $19.5594$ at sample $420075$.
     - $N_{ID}^{(2)} = 2$: Peak $20.3980$ at sample $113622$.

### 1.3 MATLAB Environment and Installed Toolboxes
MATLAB MCP detection (`detect_matlab_toolboxes`) and runtime check (`ver`) revealed:
```
MATLAB Version: 26.1.0.3346908 (R2026a) Update 5
License: 1091521
Operating System: Microsoft Windows 11 Pro Version 10.0 (Build 26200)

Installed Products:
----------------------------------------------------------
5G Toolbox                          Version: 26.1       Release: (R2026a)
Communications Toolbox              Version: 26.1       Release: (R2026a)
DSP System Toolbox                  Version: 26.1       Release: (R2026a)
MATLAB                              Version: 26.1       Release: (R2026a)
MATLAB MCP Server Toolbox           Version: 0.4.0      Release: (R2026a)
Parallel Computing Toolbox          Version: 26.1       Release: (R2026a)
Signal Processing Toolbox           Version: 26.1       Release: (R2026a)
----------------------------------------------------------
```

### 1.4 Hardware and Parallel Computing
- Physical hardware: 10 CPU cores detected (`feature('numCores') == 10`).
- Parallel pool: Successfully initialized `parpool('Processes')` with 10 workers.
- `parfor` loop execution verified across all 10 workers with zero latency or licensing issues.

### 1.5 Transceiver Chain APIs and Behavioral Nuances
The key functions mandated by `ORIGINAL_REQUEST.md` were directly exercised and verified in MATLAB R2026a:
1. **CRC-24C**:
   - `nrCRCEncode(payload, '24C')` turns 56-bit payload into 80-bit code block.
   - `nrCRCDecode(decBits, '24C')` successfully verifies checksum and outputs payload.
2. **Polar Encoding, Rate Matching & Decoding**:
   - For Legacy PBCH ($E=864$, 432 QPSK symbols) and DMRS-free PBCH ($E=960$, 480 QPSK symbols):
     - `encBits = nrPolarEncode(tbCrc, E)` produces mother code block of length $N = 512$ ($n_{max}=9$).
     - `rmBits = nrRateMatchPolar(encBits, K, E)` produces exact target rate-matched vector of length $E$ ($864$ or $960$).
     - **CRITICAL API NUANCE**: `nrRateRecoverPolar(llr, K, N)` requires the **mother code length $N=512$**, NOT $E$! Supplying $E$ produces runtime error `N must be a power of two.`
     - `decBits = nrPolarDecode(recLlr, K, E, L)` takes rate-matched length $E$ and list length $L=8$.
     - Test run with back-to-back AWGN: Decoded bit error $= 0$, CRC error $= 0$ for both $E=864$ and $E=960$.
3. **Modulation & LLR Demapping**:
   - `nrSymbolModulate(rmBits, 'QPSK')` maps $\{0, 1\}$ to standard Gray QPSK symbols.
   - `nrSymbolDemodulate(rxSyms, 'QPSK', noiseVar)` produces soft LLRs with convention:
     - Bit $0 \rightarrow$ positive LLR ($+2/\sigma^2$)
     - Bit $1 \rightarrow$ negative LLR ($-2/\sigma^2$)
     - Compatible directly with `nrRateRecoverPolar` and `nrPolarDecode`.
4. **Channel & Antenna Configuration**:
   - `nrTDLChannel` with `DelayProfile = 'TDL-C'`, `DelaySpread = 300e-9`, `SampleRate = 15.36e6`, `NumTransmitAntennas = 1`, `NumReceiveAntennas = 4` (1T4R SIMO) configured and executed cleanly.
   - Input shape `[1024 1]` passes through to output shape `[1024 4]`.
5. **Headless Figure Generation**:
   - Headless figures created with `figure('Visible', 'off')` and exported to `.png` and `.fig` using `saveas()`.
   - Both formats verified to write properly to disk.

---

## 2. Logic Chain

1. **Workspace Assessment**:
   - The workspace currently contains initial baseline helpers (`gen_PSSNR.m`, `loaddump.m`, `test.m`), reference timing documentation (`cpLength.md`), and real baseband captures (`dumpdataNR/`).
   - `gen_PSSNR.m` is functionally identical to `nrPSS`, confirming baseline PSS generation correctness.
   - The LLS codebase itself (R1 sequence generators for Extended SSS and Comb-SSS, R2 SIMO MRC channel simulator, R3 transceiver pipelines, R4 Monte-Carlo engine and test suites) does not yet exist and must be constructed modularly.
2. **Toolbox & Environment Readiness**:
   - All 5 required toolboxes (5G Toolbox, Communications Toolbox, DSP System Toolbox, Parallel Computing Toolbox, Signal Processing Toolbox) are present in the latest R2026a Update 5 release.
   - 10 CPU worker processes are immediately available, satisfying R4 parallel simulation execution speed requirements.
3. **Implementation Guidance from Direct API Validation**:
   - In the Polar decoding chain, implementers must pass $N=512$ (the mother polar length) to `nrRateRecoverPolar` and $E \in \{864, 960\}$ to `nrPolarDecode`. Passing $E$ to rate recovery will trigger assertion failures.
   - The LLR sign from `nrSymbolDemodulate` matches `nrPolarDecode` natively without sign inversion.
   - OFDM parameters in `nrCarrierConfig` with 20 PRBs at 30 kHz SCS naturally produce $240\text{ subcarriers}$ and $f_s = 15.36\text{ MHz}$, exactly conforming to R2.

---

## 3. Caveats

- **No Caveats on Environment**: All required toolboxes, licenses, and functions are confirmed present and operational.
- **Dump Data Scope**: The files in `dumpdataNR/` are 15.36 MHz captures from live commercial networks (KT, LGU+, SKT). They provide an optional real-world signal verification asset for PSS/SSB detection, but synthetic TDL-C channel simulations remain the primary baseline required by R1-R4.
- **Path Preconditioning**: Scripts running outside root `C:\workspace\nr_ics` need `addpath('C:\workspace\nr_ics')` or relative paths to locate root modules.

---

## 4. Conclusion

The MATLAB R2026a environment and workspace are **100% verified and fully equipped** for immediate development of the 3GPP Rel-20 / 6G Link-Level Simulator:
- Toolboxes (5G, Comms, DSP, Parallel, Signal Processing) are active and verified.
- 10 parallel workers are available for fast Monte-Carlo simulations.
- Key PHY transceiver functions (`nrCRCEncode`, `nrPolarEncode`, `nrRateMatchPolar`, `nrRateRecoverPolar`, `nrPolarDecode`, `nrSymbolModulate`, `nrSymbolDemodulate`, `nrTDLChannel`) have been verified back-to-back with 0 errors.
- Baseline scripts and CP timing parameters are validated.

---

## 5. Verification Method

To independently reproduce and verify this assessment in MATLAB:
```matlab
% 1. Verify Toolboxes
verNames = {ver().Name};
required = {'MATLAB', '5G Toolbox', 'Communications Toolbox', 'Parallel Computing Toolbox', 'Signal Processing Toolbox'};
assert(all(ismember(required, verNames)));

% 2. Verify Parallel Pool
p = gcp();
assert(~isempty(p) && p.NumWorkers >= 4);

% 3. Verify End-to-End Polar Transceiver Back-to-Back (E=864 and E=960)
payload = randi([0 1], 56, 1);
tbCrc = nrCRCEncode(payload, '24C');
K = 80; N = 512;
for E = [864, 960]
    encBits = nrPolarEncode(tbCrc, E);
    rmBits = nrRateMatchPolar(encBits, K, E);
    modSyms = nrSymbolModulate(rmBits, 'QPSK');
    llrs = nrSymbolDemodulate(modSyms, 'QPSK', 1e-4);
    recLlr = nrRateRecoverPolar(llrs, K, N);
    decBits = nrPolarDecode(recLlr, K, E, 8);
    [rxPayload, err] = nrCRCDecode(decBits, '24C');
    assert(err == 0 && isequal(rxPayload, payload));
end

% 4. Verify gen_PSSNR vs nrPSS
for nid2 = 0:2
    assert(isequal(gen_PSSNR(nid2), nrPSS(nid2).'));
end

% 5. Verify TDL-C 1T4R SIMO
tdl = nrTDLChannel('DelayProfile', 'TDL-C', 'DelaySpread', 300e-9, ...
                   'SampleRate', 15.36e6, 'NumTransmitAntennas', 1, ...
                   'NumReceiveAntennas', 4, 'MaximumDopplerShift', 19.4);
out = tdl(complex(randn(1024,1), randn(1024,1)));
assert(isequal(size(out), [1024, 4]));
```
