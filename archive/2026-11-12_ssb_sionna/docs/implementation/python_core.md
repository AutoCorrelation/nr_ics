# Python core 구현 및 검증

`ssb.profiles.load_profile(operator_id, project_root=None)`은 `skt`, `kt`, `lgu`의 원본 JSON을 읽고 canonical dict와 SHA-256을 반환합니다. `lmax=8`과 `ibar_ssb=ssb_index`는 baseline 가정이며, 확인되지 않은 Point A를 확정하지 않습니다.

`ssb.layout.standard_layout(pci)`는 표준 class ID, mask와 symbol 우선 `[k,l]` 좌표를 반환합니다. `pilot_pattern(mask_dmrs, dmrs, device=None)`은 원래 pilot 순서와 크기를 보존하는 Sionna `PilotPattern`을 만듭니다. `ssb.io.SSBReference`, `read_reference(path)`, `write_reference(path, reference)`는 `ssb-grid-v1`의 축, 좌표, mask, bit 및 pilot 일관성을 검사합니다. Synthetic payload에서는 `/bits/k_ssb`, `/bits/msb_index_offset`, SFN payload bit와 `manifest.num_blocks`가 batch와 일치해야 합니다. Reader는 UTF-8 scalar와 MATLAB의 UTF-8 uint8 vector를 모두 허용합니다. Capture는 수신값만을 저장할 수 있으며 알려지지 않은 PCI와 pilot 값을 생략할 수 있습니다. Capture에 합성 transmit, channel 또는 noise 정답이 있으면 거부합니다.

`ssb.channels.ChannelConfig`와 `apply_channel(x, config, snr_db, seed)`는 복소수 `[B,240,4]` 입력과 같은 shape 및 device의 `rx`, `h_true`, 그리고 `[B]`의 알려진 `n0`를 반환합니다. `identity`, 복소 Gaussian `flat`, 실제 Sionna 2.2.0 `TDL`과 `CDL`을 지원합니다. Channel 응답은 `normalize_channel=False`로 생성하고 고정 `ensemble_scale`만 적용합니다. Noise는 Sionna `AWGN`으로 한 번 추가하며 복소 분산은 `N0=10^(-SNR/10)`입니다. `snr_db=inf`는 무잡음 검증에 사용할 수 있습니다. 각 호출에 seed를 전달해야 하며 train, validation, test의 seed와 realization 분리는 호출자의 책임입니다. 동일한 lock, device, seed와 호출 조건에서 재현하며 CPU와 GPU 사이의 bitwise 일치는 보장하지 않습니다.

Reduced channel은 `dc_null=False`, CP 0, symbol 간격 `1/SCS`인 이상화된 240-bin 주파수 영역 모델입니다. 이 모델에는 ICI와 ISI가 없고 실제 NR symbol timing 또는 물리 FFT 배치를 재현했다는 뜻이 아닙니다. CDL은 단일 omni V antenna와 고정 orientation을 사용합니다. 개별 block power를 정규화하지 않으며 `ensemble_scale`은 별도 training ensemble 근거 없이 변경하지 않아야 합니다. [Sionna 2.2.0 OFDMChannel 소스](https://github.com/NVlabs/sionna/blob/v2.2.0/src/sionna/phy/channel/ofdm_channel.py), [TDL 소스](https://github.com/NVlabs/sionna/blob/v2.2.0/src/sionna/phy/channel/tr38901/tdl.py), [CDL 소스](https://github.com/NVlabs/sionna/blob/v2.2.0/src/sionna/phy/channel/tr38901/cdl.py)를 확인했습니다.

`ssb.matlab_bridge.export_reference(operator_id, output_path, num_blocks=128, seed=20261112, matlab_executable=None, *, timeout=600)`은 MATLAB R2026a exporter를 실행하고 Path를 반환합니다. `decode_batch(y, h_hat, n0, profile, *, work_dir, matlab_executable=None, list_length=8, timeout=600)`은 임시 HDF5 파일을 사용하여 공통 decoder를 실행하고 계약에 명시된 일곱 출력 배열을 반환합니다. MATLAB process 및 timeout 오류는 호출 전체의 오류로 전달하고, block별 numerical 오류는 반환된 `error_code`와 CRC에 보존합니다.

검증 명령은 다음과 같습니다.

```powershell
.venv/Scripts/python.exe -m pytest tests/python/test_profiles.py tests/python/test_layout.py tests/python/test_io.py tests/python/test_channels.py tests/python/test_matlab_bridge.py -q
```

Python 테스트 35개가 통과했습니다. 실제 PyTorch 2.9.1+cu128과 Sionna 2.2.0에서 CPU 및 CUDA로 네 channel family의 shape, label, 재현성을 검사했습니다. 별도로 noise 실수부와 허수부 분산, flat/TDL/CDL ensemble power, pilot 순서, B=1과 B=3 HDF5 roundtrip 및 손상된 데이터 거부를 검사했습니다. MATLAB worker가 생성한 세 사업자 reference를 읽고 표준 좌표와 DM-RS 순서를 검증했습니다. 실제 SKT 무잡음 1 block의 MATLAB decoder 결과는 CRC 0, 32-bit scrambled payload와 24-bit transport 일치, error code 0이었습니다.

MATLAB R2026a를 실제 subprocess로 실행하여 임시 SKT reference를 새로 export하고 B=1 shape를 확인했습니다. MATLAB worker가 생성한 SKT, KT, LG U+ reference에서 각각 B=1 및 B=4를 선택하여 `H_hat=1`, `N0=1e-10`으로 실제 decoder에 전달했습니다. 여섯 호출 모두 CRC와 error code가 0이었고, scrambled 32-bit payload와 24-bit transport가 reference와 일치했습니다. 이 확인은 무잡음에 가까운 identity 경로의 통합 검증이며 fading BLER 또는 학습 결과를 의미하지 않습니다.


## 검토 후 보완한 계약

`SSBReference.k_ssb`는 synthetic reference에 필수인 정수 `[B]` 배열이며 `/bits/k_ssb`에서 읽고 같은 경로에 저장합니다. 값의 범위는 0–31이며, 하위 4 bits가 24-bit transport의 `trblk[:,8:12]`와 일치해야 합니다. 선택적 `pbch_llr`는 float32 `[B,864]`이며 `/diagnostic/pbch_llr`로 보존합니다. 실제 MATLAB golden의 B=1과 B=16을 Python으로 roundtrip하여 두 dataset이 유지되는지 확인했습니다.

Synthetic manifest는 canonical profile, 원본 JSON 및 SHA-256, seed, 표준과 bit stage, power 및 축과 정렬 정보를 포함해야 합니다. 명시된 PCI override는 원본 JSON의 PCI를 `observed_pci`로 보존하고 `pci`, `nid1`, `nid2`와 `profile_kind=synthetic_pci_override`를 기록해야 합니다. Capture는 별도 provenance로 처리하며 알 수 없는 PCI와 pilot을 허용하고 synthetic truth는 거부합니다.

`ssb.profiles.synthetic_profile(profile, pci)`는 입력 profile과 raw JSON을 변경하지 않고 synthetic override 사본을 반환합니다. `ssb.matlab_bridge.export_reference(..., *, timeout=600, pci=None)`의 `pci`를 지정하면 MATLAB exporter에 같은 override를 전달합니다. Profile 및 decoder bridge는 정수가 아닌 PCI/index, 범위를 벗어난 index와 Lmax, 일치하지 않는 `ibar_ssb`를 사전에 거부합니다. Lmax=4에서는 `ibar_ssb`의 하위 2 bits가 SSB index와 같아야 합니다. Channel 설정의 모든 수치 필드는 유한해야 하며 seed는 0–2^64−1 범위의 정수여야 합니다.

이번 보완 후 Python core 대상 테스트는 89개, 전체 `tests/python`은 105개가 통과했습니다. 실제 MATLAB R2026a subprocess에서 KT 기준 synthetic PCI 326과 327을 각각 2 block씩 export하고 Python reference reader와 writer를 거쳐 `k_ssb` 및 `pbch_llr`를 비교했습니다. 이어서 각 grid를 공통 MATLAB decoder에 전달한 결과 네 block 모두 CRC와 error code가 0이었으며 32-bit scrambled payload 및 24-bit transport가 일치했습니다. 이 검증은 identity channel의 연동을 확인하며 unseen PCI에 대한 학습 모델 성능은 별도 평가가 필요합니다.

