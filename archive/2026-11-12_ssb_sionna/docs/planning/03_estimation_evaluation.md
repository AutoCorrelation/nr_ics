# 단계 M3–M4: Channel estimator와 PBCH BLER 평가

## Estimator

- Pilot LS는 2개 DM-RS symbol 사이를 주파수 선형 보간하고 가장자리에서 constant extrapolation을 적용합니다. 중앙 PBCH symbol은 시간 보간으로 채웁니다.
- LMMSE의 mean과 covariance는 training channel에서만 추정하고, pilot observation에서는 noise variance와 diagonal loading을 포함한 선형계를 풉니다.
- Residual CNN은 pilot LS, pilot/data/valid masks와 known simulation `N0`를 사용합니다. Training은 PBCH RE의 complex channel target과 masked loss를 적용하고 validation MSE로 checkpoint를 선택합니다.
- Perfect CSI는 추정기 입력으로 실제 channel을 받는 성능 상한입니다.

## Split, seed 및 scoring

Payload, channel, noise 및 model initialization에 분리 seed를 사용하고 train/validation/test trajectory ID가 겹치지 않는지 검사합니다. 각 방법은 같은 test observation과 channel realization을 사용합니다. PCI override는 training에서 배제하고 기존 CNN과 covariance를 재사용합니다. LMMSE는 override PCI의 새 pilot position에 맞춰 selection mask만 바꿉니다.

MATLAB common decoder에서 CRC 실패, 32-bit scrambled payload 불일치 또는 numerical error가 생기면 해당 block을 BLER 오류로 셉니다. PBCH-mask NMSE, equalizer EVM, fixed-N exact binomial interval, 0-error one-sided bound와 paired block 차이를 기록합니다. Plots는 condition별 SNR 곡선을 분리합니다.

## Budget과 gate

`smoke.json`은 interface 확인, `quick.json`은 세 operator의 작은 연결 검증, `validation.json`은 SNR sweep와 SKT PCI 326/327 OOD test입니다. `full.json`은 대규모 학습/test 구성을 제공하지만 실행 환경과 시간 예산을 검토한 뒤 별도로 실행합니다. 작은 budget 결과만으로 estimator 우위를 결론짓지 않습니다.

현재 실행 결과와 재현 명령은 [평가 구현 기록](../implementation/evaluation.md)과 [구현 및 검증 결과](../IMPLEMENTATION_RESULTS.md)에 있습니다. Synchronization이 알려진 reduced frequency-domain SISO 성능과 실제 capture receiver 성능을 구분합니다.
