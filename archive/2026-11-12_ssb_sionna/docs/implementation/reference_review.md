# 독립 검토 결과

2026-11-12에 검토자가 MATLAB SSB/PBCH 코드와 Python core의 경계 조건을 별도 targeted probe로 확인했습니다. 기존 네 가지 결함은 수정됐고, 추가로 발견된 label 및 HDF5 batch 메타데이터 불일치도 반영했습니다.

## 확인한 수정 사항

1. Python HDF5 reader/writer가 `/bits/k_ssb`와 선택적 `/diagnostic/pbch_llr`를 보존합니다. B=1 및 다중 block roundtrip에서 값과 shape를 확인했습니다.
2. PCI, SSB index, Lmax, `ibar_ssb`를 엄격히 검사하며 잘못된 값을 modulo로 조용히 보정하지 않습니다.
3. Lmax=4에서는 DM-RS sequence index에 `ssb_index + 4*half_frame`을 사용합니다. 모든 4개 index와 두 half-frame 조합을 직접 및 batch 경로에서 확인했습니다.
4. Synthetic manifest의 profile, source hash, seed, axis와 payload 출처를 검사합니다. PCI override는 관측 PCI와 생성 PCI를 별도로 기록합니다.
5. `k_ssb` 상위 bit와 `msb_index_offset`, `k_ssb` 하위 4 bits와 transport payload, SFN 상위 6 bits와 transport payload가 서로 일치해야 합니다. Synthetic manifest의 `num_blocks`도 실제 batch 크기와 같아야 합니다.

## 남은 검증 경계

검토자가 비교한 CSI-weighted LLR과 SISO matched-filter 결과는 수치 오차 범위에서 일치했습니다. 이는 equalizer 스케일 검증이며 채널 추정 LLR 전체를 독립적으로 검증한 것은 아닙니다. MATLAB encoder와 decoder가 같은 toolbox 구현을 사용하므로 독립적인 TS 38.212 known-answer payload vector는 여전히 추가하면 좋습니다. Sionna 채널은 reduced frequency-domain 모델이며 capture의 waveform timing, CFO/ICI, MIMO 또는 field calibration을 검증하지 않습니다.

검토 기록은 시험된 경로와 실제 capture 관측, synthetic benchmark의 증거 수준을 구분합니다. 전체 성능 결론은 [구현 및 검증 결과](../IMPLEMENTATION_RESULTS.md)를 참고하십시오.
