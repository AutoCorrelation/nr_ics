# MATLAB–Python 구현 계약

이 문서는 MATLAB reference, Python/Sionna channel, PyTorch estimator 및 MATLAB decoder bridge 사이의 stable interface를 정의합니다. 실행 절차와 검증 증거는 [구현 및 검증 결과](IMPLEMENTATION_RESULTS.md)에 기록합니다.

## Reference grid

- `ssb-grid-v1` Python 배열 축은 `[batch, subcarrier, symbol]`, grid shape은 complex64 `[B,240,4]`입니다.
- Coordinate dataset은 int32 `[N,2]`, 열 순서는 `[k,l]`, 인덱스는 0-based입니다. RE 순서는 symbol 우선, 그다음 subcarrier입니다.
- HDF5는 complex 값을 float32 `*_real` 및 `*_imag` dataset으로 나눕니다. h5py가 반환하는 최종 shape이 계약 기준이며 MATLAB dimension reversal은 exporter가 처리합니다.
- Synthetic reference에는 `/bits/bch_transport` `[B,24]`, `/bits/bch_payload_scrambled32` `[B,32]`, `/bits/bch_rate_matched` `[B,864]`, `/bits/sfn`, `/bits/half_frame`, `/bits/k_ssb`, `/bits/msb_index_offset` dataset이 포함됩니다. `k_ssb`는 0–31, `msb_index_offset`은 `k_ssb >> 4`와 같아야 합니다. Optional `/diagnostic/pbch_llr`는 float32 `[B,864]`입니다.
- `trblk[:,8:12]`은 `k_ssb` 하위 4 bits와 같고 `trblk[:,1:7]`은 SFN 상위 6 bits와 일치해야 합니다. `manifest.num_blocks`는 grid batch size와 일치해야 합니다.
- Synthetic manifest에는 source kind, canonical operator/profile, PCI provenance, input JSON SHA-256, seed, standard/bit stage, power, schema와 axis metadata가 필수입니다. PCI override는 `profile_kind=synthetic_pci_override`, `observed_pci`, 생성 PCI와 NID1/NID2를 보존합니다.
- Capture reference는 `source_kind=capture_rx`이며, 사용할 수 없는 transmit truth와 channel/noise truth를 synthetic reference처럼 채우지 않습니다.

## SSB metadata 및 DM-RS

PCI는 0–1007의 정수입니다. Lmax는 4 또는 8이며 index는 각각 0–3 또는 0–7입니다. Lmax=8이면 `ibar_ssb=index`; Lmax=4이면 `ibar_ssb` 하위 2 bits가 index입니다. Lmax=4 DM-RS 생성은 block half-frame을 반영하여 `index + 4*half_frame`을 사용합니다. 잘못된 metadata는 modulo 보정 없이 오류로 반환합니다.

## Decoder interface

Python `decode_batch(y,h_hat,n0,profile,...)`은 NumPy complex `[B,240,4]`의 관측 grid 및 channel estimate와 float `[B]` noise variance를 MATLAB `ssb-decode-v1` bridge로 전달합니다. MATLAB은 공통 SISO MMSE equalization, PBCH demodulation 및 BCH decode를 수행합니다. 결과에는 block별 CRC, 32-bit payload, 24-bit transport, SFN LSB, half-frame, `msb_index_offset` 및 error code가 포함됩니다. Block 오류를 전체 호출 실패로 숨기지 않습니다.

## Channel과 평가

Complex baseband tensor는 complex64 `[B,240,4]`이며 알려진 simulation noise 분산 `N0=10^(-Es/N0/10)`를 사용합니다. Channel은 block별 normalization을 하지 않습니다. Identity/flat와 Sionna TDL/CDL은 고정 seed와 기록된 ensemble scale을 사용합니다. TDL/CDL reduced frequency-domain 설정은 ICI/ISI, physical FFT 또는 waveform timing을 모델링하지 않습니다.

Estimator 비교는 같은 test payload, channel realization과 AWGN 관측값을 사용합니다. Covariance와 CNN training은 training partition만 사용하고 test-only PCI override에서 다시 학습하지 않습니다. BLER, exact binomial interval, zero-error one-sided upper bound, paired block 차이 및 channel NMSE/EVM을 보고합니다.
