# Dispatch for Explorer Survey 3 (LLS System Architecture & Verification Explorer)

## Mission
Survey the system engineering requirements, end-to-end signal processing pipelines (Tx, Channel/Impairments, Rx), and verification deliverables:
1. Transmitter pipeline: 56-bit PBCH MIB payload -> CRC-24C (`nrCRCEncode`) -> Polar encode (`nrPolarEncode`) -> Rate match (`nrRateMatchPolar`) to 864 or 960 bits -> QPSK -> Grid mapping -> OFDM mod (`nrOFDMModulate`).
2. Physical channel & RF: 3GPP TDL-C (300 ns delay spread, `nrTDLChannel`), 1T4R SIMO with MRC, 3 km/h & 120 km/h mobility, initial CFO (+-5 or +-20 ppm), residual CFO (+-0.1 ppm), calibrated AWGN noise over [-14, -2] dB.
3. Receiver pipeline: PSS sync & coarse CFO acquisition -> OFDM demod (`nrOFDMDemodulate`) -> SSS detection & Cell-ID estimation -> Design-specific channel estimation (DMRS-only, SSS-as-DMRS zero-order hold/extrapolation, Comb-SSS 2D interpolation, joint SSS+DMRS MMSE) -> 2D MMSE equalization & soft LLR demapping -> Polar rate recovery (`nrRateRecoverPolar`) -> SCL polar decoding (L=8, `nrPolarDecode`) -> CRC-24C verification.
4. Monte-Carlo simulation runner & publication plotting: `main_run_simulation.m` (supporting 'quick_demo' and 'full_run' modes with parfor), generating 5 publication-grade figures (.png and .fig).
5. Automated programmatic tests: `tests/test_sequences.m`, `tests/test_pbch_chain.m`.

## Key Files to Read
- C:\workspace\nr_ics\.agents\teamwork\ORIGINAL_REQUEST.md
- Any existing scripts in workspace

## Output
Write your findings to `C:\workspace\nr_ics\.agents\teamwork\explorer_survey_3\handoff.md`.
Report back when complete.

## 2026-09-28T02:53:06Z
Received dispatch from parent orchestrator:
Task:
1. Investigate the Link-Level Simulator (LLS) system architecture requirements across all 4 requirements:
   - R1: Sequence generation & grid mapping for all 4 architectures
   - R2: Physical channel (3GPP TDL-C 300ns via nrTDLChannel, 1T4R SIMO MRC, 3 km/h & 120 km/h, CFO & residual CFO, AWGN noise)
   - R3: Complete Tx chain (56-bit MIB -> CRC-24C -> Polar -> Rate Match -> QPSK -> Grid -> OFDM) & Rx chain (PSS sync -> OFDM demod -> SSS detection & Cell-ID -> Channel Estimation: 4 estimators -> 2D MMSE eq -> LLR demapping -> Rate recovery -> SCL L=8 decoding -> CRC check)
   - R4: Parallel Monte-Carlo engine (main_run_simulation.m) with 'quick_demo' and 'full_run' modes, and 5 publication figures (.png and .fig).
   - Programmatic unit test requirements (tests/test_sequences.m, tests/test_pbch_chain.m).
2. Map out the recommended modular folder structure, function signatures, data flow contracts, and interface definitions.
3. Write your detailed handoff report to C:\workspace\nr_ics\.agents\teamwork\explorer_survey_3\handoff.md.
4. Send a brief completion message back to the orchestrator when finished.
