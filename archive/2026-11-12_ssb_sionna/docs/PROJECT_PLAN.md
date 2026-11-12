# NR SSB/PBCH 채널 추정 프로젝트 계획

## 목표

통신 3사 capture에서 관측한 동기화 파라미터를 기준으로 MATLAB에서 3GPP NR SSB와 PBCH DM-RS를 생성합니다. 표준 SSB를 Python 0-based `[subcarrier, symbol]` 좌표의 240×4 grid로 교환한 뒤 Sionna 채널과 PyTorch channel estimator를 적용하고, MATLAB BCH decoder로 paired PBCH BLER와 SNR을 측정합니다.

통신사 capture는 초기 동기화와 decoder sanity check에 사용합니다. 사업자별 설정이 전체 operator waveform을 대표한다고 가정하지 않으며, 실제 frame origin, Point A, release-specific MIB 필드와 propagation channel이 확인될 때까지 해당 항목은 미확정으로 둡니다.

## 단계와 산출물

| 단계 | 작업 | 산출물과 완료 조건 |
| --- | --- | --- |
| M0 환경 | 프로젝트 루트 `.venv`, uv lock, PyTorch CUDA smoke | 재현 가능한 dependency와 CUDA 연산 확인 |
| M1 MATLAB 기준 | SSB/PSS/SSS/PBCH/DM-RS grid, capture 입력, BCH encode/decode, HDF5 export | 3개 profile capture sanity, CRC 및 payload parity, 0-based 좌표 계약 |
| M2 Python/Sionna | profile/layout/HDF5 reader, Sionna identity/flat/TDL/CDL, MATLAB bridge | MATLAB golden roundtrip, complex64 `[B,240,4]`, channel과 N0 검증 |
| M3 추정기 | pilot LS 보간, training covariance LMMSE, residual CNN | training/validation/test split, seed·hash provenance, CUDA 학습과 checkpoint |
| M4 평가 | 동일 test realization의 estimator별 decoder 결과, BLER/NMSE/EVM, exact CI와 paired 비교, plot 및 test-only PCI/comb OOD | bounded SNR validation과 재현 가능한 report. full 규모 결과와 통계적 성능 결론은 별도 수행 |
| M5 선택 확장 | 독립 Python BCH decoder, waveform/time-domain acquisition, CFO/ICI, MIMO | 이 구현 범위에서는 완료 조건에 포함하지 않음 |

## 기준 신호 및 평가 계약

- 기준 SSB는 30 kHz SCS, Case C, 240 subcarrier × 4 symbols입니다. PSS와 SSS는 각 127 RE, PBCH DM-RS는 144 RE, PBCH는 432 QPSK RE입니다.
- PCI는 각 capture/profile 값으로 시작하며, unseen comb 검증을 위해 PCI 326/327을 test-only synthetic override로 지원합니다. Override는 training에 쓰지 않습니다.
- `ssb-grid-v1`의 Python grid는 complex64 `[B,240,4]`; ordered coordinate는 int32 `[k,l]`이고 0-based입니다. HDF5 complex 값을 float32 real/imag dataset으로 나눠 저장합니다.
- SNR은 PBCH RE 기준 Es/N0, Es=1입니다. 복소 잡음 분산은 `N0=10^(-SNR/10)`이며 실수부와 허수부 분산은 각각 `N0/2`입니다.
- 기본 평가는 알려진 synchronization, 알려진 simulation `N0`, SISO frequency-domain channel 조건입니다. 채널 추정기 네트워크는 true channel을 입력 feature로 사용하지 않습니다. Perfect CSI는 상한 기준으로 별도 표시합니다.
- BLER는 CRC 실패, 32-bit scrambled payload mismatch 또는 block numerical error로 판정합니다. Fixed-N exact binomial confidence interval과 같은 block에 대한 paired 차이를 기록합니다.

## 검증 상태

구현과 수행한 검증은 [구현 및 검증 결과](IMPLEMENTATION_RESULTS.md)에 기록합니다. Capture에서 CRC가 통과한 사실은 실제 transmit truth 또는 채널 label이 복원됐다는 뜻이 아닙니다. 전체 M4 규모 학습, capture에 대한 channel estimator 검증, 독립 standards known-answer BCH vector 및 M5는 후속 작업입니다.
