# 구현 및 검증 결과

2026-11-12 기준 M0–M4의 주요 코드 경로가 구현됐습니다. MATLAB R2026a로 SSB/PBCH reference와 batch BCH decoder를 만들고, Python 0-based `[subcarrier,symbol]` grid 및 HDF5 bridge, Sionna channel, LS/LMMSE/residual CNN 평가, BLER plot을 연결했습니다. 전체 범위와 제한은 [프로젝트 계획](PROJECT_PLAN.md)과 [구현 계약](IMPLEMENTATION_CONTRACT.md)에 있습니다.

## 검증

- Python 전체 suite: **105 passed** (`.venv\Scripts\python.exe -m pytest -q`).
- MATLAB `tests/matlab`: **7 passed**. 실제 exporter에서 새 SSB reference를 생성하고 decoder bridge도 호출했습니다.
- MATLAB capture sanity: SKT PCI 508, KT PCI 325, LG U+ PCI 960 모두 검출된 PBCH CRC가 통과했습니다. 관측된 SFN은 각각 670, 278, 538이며 `k_SSB`는 각각 22, 18, 12입니다. 이는 capture decoder sanity이며 송신 truth, frame origin 또는 현장 채널 label의 검증은 아닙니다.
- MATLAB synthetic PCI override: PCI 326/327에서 comb 2/3을 생성하고 Python HDF5 roundtrip 및 공통 MATLAB decoder와 비교했습니다. 각 8-block golden 및 별도 2-block bridge 검사에서 CRC, 32-bit scrambled payload, 24-bit transport가 일치했습니다.
- Independent review에서 확인한 batch count 및 payload label 검사도 반영했습니다. `k_ssb` 상위 bit, 하위 4 bits, SFN 상위 6 bits와 `manifest.num_blocks`가 실제 label과 일치해야 합니다.

## CUDA 고정 budget validation

다음 설정을 RTX 3060에서 CUDA로 실행했습니다.

```powershell
uv run ssb-benchmark run --config configs/experiments/validation.json
uv run ssb-benchmark plot --results artifacts/validation/61f4339e368c921f/results.json --output-dir artifacts/validation/61f4339e368c921f/plots
```

세 observed profile에서 training 256 blocks, validation 64 blocks, condition별 test 40 blocks, CNN 초기화 seed 3개를 사용했습니다. Training은 identity와 TDL-C(100 ns, 0 m/s)에서 −10, 0, 5 dB 조건을 사용했고, test는 두 채널에서 −15, −10, −5, 0, 5 dB를 사용했습니다. SKT 모델을 다시 학습하지 않고 PCI 326/327을 identity 및 TDL-C test-only override로 평가했습니다. 실제 MATLAB decoder로 총 10개 condition/profile group과 두 OOD profile을 채점했습니다.

다음 표는 TDL-C에서 LS, LMMSE 및 각 세 CNN 초기화의 BLER error count를 보여줍니다. 각 수는 condition마다 40 trials입니다.

| Profile | SNR | LS | LMMSE | CNN 3회 초기화 |
| --- | ---: | ---: | ---: | ---: |
| SKT | −5 dB | 25/40 | 3/40 | 24, 27, 26/40 |
| SKT | 0 dB | 4/40 | 0/40 | 4, 4, 4/40 |
| KT | −5 dB | 25/40 | 5/40 | 23, 22, 24/40 |
| KT | 0 dB | 9/40 | 1/40 | 6, 7, 8/40 |
| LG U+ | −5 dB | 22/40 | 8/40 | 28, 25, 25/40 |
| LG U+ | 0 dB | 7/40 | 0/40 | 15, 6, 7/40 |

이 작은 budget에서는 CNN이 TDL-C 조건에서 LMMSE를 이기지 못했습니다. 따라서 CNN 성능 향상을 주장하지 않습니다. 관측 profile별 수치와 모든 SNR, identity 결과, PCI 326/327 결과, exact confidence interval, paired 비교, checkpoint/provenance hash 및 실행 환경은 [전체 결과 JSON](../artifacts/validation/61f4339e368c921f/results.json)에 있습니다. 0 errors/40의 단측 95% 상한은 약 0.072이며, 40 trials는 낮은 BLER 영역을 정밀하게 추정하기에 부족합니다.

## Plot

`results.json`에서 condition별로 생성한 PNG는 다음과 같습니다. 각 그림은 BLER와 exact interval, 0-error upper bound marker, PBCH-mask channel NMSE를 표시합니다.

- [SKT TDL-C](../artifacts/validation/61f4339e368c921f/plots/skt_tdl_f65a37e7.png)
- [KT TDL-C](../artifacts/validation/61f4339e368c921f/plots/kt_tdl_f65a37e7.png)
- [LG U+ TDL-C](../artifacts/validation/61f4339e368c921f/plots/lgu_tdl_f65a37e7.png)
- [PCI 326 unseen comb 2 TDL-C](../artifacts/validation/61f4339e368c921f/plots/skt_unseen_comb2_tdl_f65a37e7.png)
- [PCI 327 unseen comb 3 TDL-C](../artifacts/validation/61f4339e368c921f/plots/skt_unseen_comb3_tdl_f65a37e7.png)

## 남은 작업

Full 설정(20,000 training, 4,000 validation, 10,000 test, seed 3회)은 구현했으나 실행하지 않았습니다. 독립 3GPP known-answer BCH payload vector, 더 큰 고정-N BLER 평가, 실제 capture에 대한 estimator/channel 검증, frame timing/Point A 및 release-specific waveform calibration, CFO/ICI와 MIMO는 별도 후속 작업입니다. 현재 validation은 알려진 synchronization과 simulation `N0`를 사용하는 reduced frequency-domain SISO 모델입니다.

## CNN? ??? ??: ?10?15 dB

`configs/experiments/classical_validation.json`?? LS + interpolation, LMMSE? Perfect CSI? ??????. Perfect CSI? ?? channel? ???? ?? ????, ?? ??? ?? MMSE equalizer? ?????. ?? validation? ?? profile? training 256 blocks, validation 64 blocks, ?? ??? 40 blocks? ??????. Identity? TDL-C?? ?10, ?5, 0, 5, 10, 15 dB? ????, SKT? PCI 326/327 test-only override? ??????. CNN? ????? ???? ?????.

TDL-C ?? ?? ??? ????. ? ??? LS / LMMSE / Perfect CSI ???? ??? ?? 40???.

| Profile | ?10 dB | ?5 dB | 0 dB | 5 dB | 10 dB | 15 dB |
| --- | --- | --- | --- | --- | --- | --- |
| SKT | 39 / 27 / 21 | 25 / 3 / 2 | 4 / 0 / 0 | 2 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| KT | 40 / 30 / 26 | 25 / 5 / 4 | 9 / 1 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| LG U+ | 40 / 26 / 24 | 22 / 8 / 7 | 7 / 0 / 0 | 1 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |

40 blocks?? ??? 0??? ?? 95% ??? ? 0.072??? ? BLER? ???? ??? ? ????. ?? ??, identity? PCI override ??, NMSE ? ????? [?? JSON](../artifacts/classical_validation/d58229224231e844/results.json)? ??????. [SKT TDL-C](../artifacts/classical_validation/d58229224231e844/plots/skt_tdl_f65a37e7.png), [KT TDL-C](../artifacts/classical_validation/d58229224231e844/plots/kt_tdl_f65a37e7.png), [LG U+ TDL-C](../artifacts/classical_validation/d58229224231e844/plots/lgu_tdl_f65a37e7.png)?? ??? ??? ? ????. ? ??? synchronization? simulation N0? ?? reduced frequency-domain SISO ?????.

## ??? 1,000 blocks: ?15?10 dB

`configs/experiments/classical_1000.json`?? CNN ?? LS + interpolation, LMMSE ? Perfect CSI? ??????. Identity? TDL-C?? SNR ?15, ?10, ?5, 0, 5, 10 dB? ????, ? ?? profile? SKT? PCI 326/327 test-only override? ?? ??? 1,000 blocks? ??????. Training? validation? profile? ?? 256? 64 blocks???. ?? ??? ?? MMSE equalizer? MATLAB BCH decoder? ??????.

TDL-C BLER ?? ??? ??? ????. ? ??? LS / LMMSE / Perfect CSI ???? ??? 1,000???.

| Profile | ?15 dB | ?10 dB | ?5 dB | 0 dB | 5 dB | 10 dB |
| --- | --- | --- | --- | --- | --- | --- |
| SKT | 1000 / 982 / 966 | 985 / 684 / 600 | 646 / 232 / 167 | 175 / 33 / 10 | 14 / 0 / 0 | 0 / 0 / 0 |
| KT | 1000 / 976 / 960 | 977 / 667 / 586 | 637 / 234 / 158 | 161 / 21 / 8 | 11 / 2 / 0 | 0 / 0 / 0 |
| LGU | 1000 / 977 / 957 | 971 / 674 / 599 | 628 / 226 / 154 | 185 / 33 / 16 | 10 / 0 / 0 | 0 / 0 / 0 |

PBCH-mask aggregate channel NMSE? ??? ????. ? ??? LS / LMMSE ???? ??? dB???. Perfect CSI? NMSE? 0?? dB ???? ?120 dB floor? ?????.

| Profile | ?15 dB | ?10 dB | ?5 dB | 0 dB | 5 dB | 10 dB |
| --- | --- | --- | --- | --- | --- | --- |
| SKT | 12.69 / -3.83 | 7.87 / -7.01 | 2.81 / -10.35 | -2.13 / -13.79 | -7.22 / -17.81 | -12.29 / -22.23 |
| KT | 12.67 / -3.95 | 7.61 / -7.11 | 2.75 / -10.41 | -2.52 / -14.03 | -7.32 / -17.80 | -12.10 / -22.11 |
| LGU | 12.73 / -3.59 | 7.70 / -7.08 | 2.58 / -10.50 | -2.24 / -13.83 | -7.37 / -17.81 | -12.24 / -22.24 |

0/1,000 ??? ?? 95% ??? ? 0.003?? ??? ?? BLER? ???? ????? ? ?? ??? ?????. ?? ??? synchronization? simulation N0? ?? reduced frequency-domain SISO ??? ?????.

[?? JSON](../artifacts/classical_1000/4e977a49bf40f225/results.json)?? identity? PCI override ??, exact ????, paired ??? ?? ??? ????. TDL-C BLER ? NMSE ??? [SKT](../artifacts/classical_1000/4e977a49bf40f225/plots/skt_tdl_f65a37e7.png), [KT](../artifacts/classical_1000/4e977a49bf40f225/plots/kt_tdl_f65a37e7.png), [LG U+](../artifacts/classical_1000/4e977a49bf40f225/plots/lgu_tdl_f65a37e7.png)?? ??? ? ????.
