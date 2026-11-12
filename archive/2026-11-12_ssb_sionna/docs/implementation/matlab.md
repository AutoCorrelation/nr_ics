# MATLAB SSB reference 및 BCH decoder

MATLAB R2026a와 5G Toolbox 26.1에서 `matlab/+ssb` package를 실행합니다. `load_profile`은 각 capture JSON과 SHA-256을 보존하고, `layout`은 Python 계약과 같은 0-based `[k,l]` 좌표를 제공합니다. `encode`는 24-bit transport payload, SFN, half-frame, `k_SSB`로 `nrBCH`, `nrPBCH`, `nrPBCHDMRS`, PSS/SSS를 호출하고 실제 BCH decoder로 roundtrip을 확인합니다.

```matlab
addpath('matlab');
ssb.export_reference('skt','data/generated/skt_reference.h5','NumBlocks',128,'Seed',20261112);
ssb.export_reference('kt','data/generated/kt_reference.h5','NumBlocks',128,'Seed',20261112);
ssb.export_reference('lgu','data/generated/lgu_reference.h5','NumBlocks',128,'Seed',20261112);
r = runtests('tests/matlab'); assertSuccess(r);
ssb.decode_batch_file('decode_input.h5','decode_output.h5');
```

MATLAB dimension reversal은 HDF5 writer에서 처리합니다. Python `h5py` 기준 grid shape은 `[B,240,4]`이고 coordinate는 int32 `[N,2]`의 `[k,l]`입니다. Synthetic metadata에는 `k_ssb`와 `msb_index_offset`을 block별로 저장합니다. Exporter는 기존 파일을 덮어쓰지 않으므로 다른 경로를 지정하거나 새 출력 경로를 사용해야 합니다.

`decode_batch_file`은 모든 method에 동일한 SISO MMSE equalizer, `nrPBCHDecode`, CSI weighting 및 `nrBCHDecode`를 사용합니다. Block별 numerical failure와 CRC failure를 출력 배열에 남기며 toolbox/process 설정 오류는 호출 실패로 반환합니다.

실제 capture 검사는 `recover_capture('skt'|'kt'|'lgu')` 경로를 사용했습니다. 세 capture 모두 PBCH CRC가 통과했지만 송신 ground truth, 실제 frame origin, CFO 보정 waveform과 Point A는 검증하지 않았습니다. capture 결과를 synthetic transmit/channel truth로 해석해서는 안 됩니다.
