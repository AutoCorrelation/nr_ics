# 단계 M2: Python grid와 Sionna channel

## 입력 및 grid 계약

Python API는 canonical `skt`, `kt`, `lgu` profile을 사용합니다. 각 profile은 source JSON hash를 보존합니다. Grid는 complex64 `[B,240,4]`, ordered coordinate는 int32 `[N,2]`의 0-based `[k,l]`입니다. `ssb-grid-v1` HDF5는 복소값의 real/imag를 각각 float32로 저장하며 Python/h5py에서 관찰한 dimension을 기준으로 검사합니다.

Synthetic BCH reference에는 24-bit transport, 32-bit scrambled payload, rate-matched 864 bits, SFN, half-frame, `k_SSB` 및 MSB offset이 필요합니다. Manifest는 actual block count와 profile/source/seed/axis/standard provenance를 포함합니다. Capture 수신 grid는 `capture_rx` provenance로 저장하고 없는 transmit truth나 channel label을 만들지 않습니다.

## Channel 설계

`ssb.channels.ChannelConfig`와 `apply_channel`은 identity, flat fading, Sionna 2.2.0 TDL/CDL을 제공합니다. 입력과 output channel은 동일 shape/device를 갖습니다. Per-block power normalization을 사용하지 않고 고정 ensemble scale을 유지합니다. PBCH RE Es/N0를 `E_s=1`로 정의하고 복소 잡음 variance `N0=10^(-SNR/10)`를 사용합니다. `h_true`와 `N0`는 benchmark label 또는 known simulation noise input이며 수신 payload로부터 추정됐다고 해석하지 않습니다.

## Decoder bridge

Python `export_reference`와 `decode_batch`가 MATLAB R2026a `-batch`를 호출합니다. Decode result는 block별 CRC, 32-bit payload, 24-bit transport, SFN LSB, half-frame, `msb_index_offset`, error code를 반환합니다. MATLAB Engine for Python은 요구되지 않습니다.

## 제한

TDL/CDL 입력은 local 240-bin reduced frequency-domain model이며 OFDM symbol 간 ICI/ISI, physical FFT placement, CP timing이나 acquisition을 포함하지 않습니다. SISO 단일 stream/channel을 사용합니다. 재현 seed와 environment/source hash는 benchmark result에 기록합니다.

구현 API 및 검증은 [Python core 기록](../implementation/python_core.md)과 [구현 계약](../IMPLEMENTATION_CONTRACT.md)을 참고하십시오.
