# PBCH 추정 및 평가 구현

## 실행

```powershell
uv run ssb-benchmark run --config configs/experiments/smoke.json
uv run ssb-benchmark run --config configs/experiments/quick.json
uv run ssb-benchmark run --config configs/experiments/validation.json
uv run ssb-benchmark run --config configs/experiments/classical_validation.json
uv run ssb-benchmark run --config configs/experiments/classical_1000.json
uv run ssb-benchmark plot --results artifacts/validation/<run-id>/results.json --output-dir artifacts/validation/<run-id>/plots
```

`smoke.json`은 SKT identity/AWGN 연결을 확인합니다. `quick.json`은 세 profile, identity와 TDL-C 및 CUDA CNN training을 작은 budget으로 실행합니다. `validation.json`은 256/64/40 train/validation/test, 세 CNN initialization seed, −15–5 dB SNR sweep 및 PCI 326/327 test-only override를 실행합니다. Full config의 20,000/4,000/10,000 budget은 제공하지만 자동 실행하지 않았습니다.

구성 hash와 reference schema revision을 이용해 output directory를 분리합니다. `results.json`은 training/test split, payload/channel/noise/model seed, source/config/reference/checkpoint hash, covariance 진단, 환경과 channel realization을 저장합니다. 조건별 method는 decoder failure count, fixed-N exact interval, zero-error one-sided bound, paired block 차이, PBCH-mask NMSE, EVM 및 timing을 기록합니다. MATLAB decoder batch는 설정된 상한으로 분할합니다.

## 추정기

- **LS:** PBCH DM-RS에서 LS 추정 후 symbols 1/3의 frequency 선형 보간과 가장자리 constant extrapolation을 적용합니다. 중앙 symbol은 양쪽 pilot symbol 사이의 시간 보간값을 사용합니다.
- **LMMSE:** training channel만으로 mean과 covariance를 계산하고 test DM-RS 위치에서 noise variance 및 diagonal loading을 포함한 선형 추정을 수행합니다. Test-only PCI override에서는 공분산을 다시 fit하지 않고 pilot selection만 변경합니다.
- **Residual CNN:** pilot LS, DM-RS/PBCH mask, valid mask, baseline LS channel, 공통 known `N0`를 feature로 사용합니다. BatchNorm 없이 PBCH RE channel을 학습하며 validation MSE로 checkpoint를 고릅니다.
- **Perfect CSI:** 실제 channel을 estimator 입력으로 쓰는 상한 참조입니다.

같은 block의 수신값을 모든 estimator에 사용합니다. Channel과 noise는 별도 seed domain으로 생성합니다. BLER는 CRC 실패, scrambled 32-bit payload mismatch, numerical block failure 가운데 하나라도 발생하면 오류로 셉니다. Exact binomial interval은 fixed trial count에 조건부이며 paired bootstrap은 동일 trial에서 발생한 estimator 간 차이를 비교합니다.

## 결과 해석

현재 CUDA validation의 정확한 설정, error count, SNR별 curves와 제한은 [구현 및 검증 결과](../IMPLEMENTATION_RESULTS.md)를 참고하십시오. 각 condition의 test 수는 40 block이므로 0 errors는 낮은 BLER을 입증하지 않습니다. 관측된 TDL-C 결과에서는 LMMSE가 작은 CNN보다 일관되게 좋거나 비슷했으며, 이 budget으로 CNN 우위를 주장할 수 없습니다.

평가 모델은 synchronization이 알려진 reduced frequency-domain SISO 설정입니다. 알려진 simulation `N0`를 사용하며 capture 수신기, CFO/ICI, 시간 영역 acquisition, MIMO 또는 실제 operator 채널 성능을 측정하지 않습니다.
