# 단계 M1: MATLAB SSB/PBCH 기준 신호

## 목표

관측 capture의 profile별 PCI, SSB index와 주파수 설정을 입력으로 사용해 MATLAB 5G Toolbox의 standard PSS, SSS, PBCH DM-RS, PBCH grid를 생성합니다. Python에서 같은 값과 좌표를 읽을 수 있는 HDF5 golden reference를 만듭니다.

## 구현 단위

- `ssb.load_profile`: 원본 JSON, 표준화한 Hz 단위 값, raw fields와 source SHA-256을 보존합니다.
- `ssb.layout`: 240×4 local grid의 PSS/SSS/DM-RS/PBCH RE와 0-based `[k,l]` ordered coordinate를 정의합니다.
- `ssb.encode`: 24-bit BCCH-BCH message와 SFN, half-frame, `k_SSB`로 MATLAB BCH/PBCH 함수를 호출하고 같은 MATLAB decoder로 roundtrip을 확인합니다.
- `ssb.extract_pilots`, `ssb.decode_pbch`, `ssb.decode_batch_file`: ideal 또는 수신 DM-RS 추출과 같은 SISO PBCH/BCH decode chain을 제공합니다.
- `ssb.export_reference`, `ssb.write_dataset`: standard grid, payload stages, bit labels, diagnostic LLR와 provenance manifest를 `ssb-grid-v1`에 저장합니다.
- `ssb.recover_capture`: 세 관측 capture의 PSS/SSS/PBCH CRC sanity를 synthetic transmit reference와 구분해 저장합니다.

## 검증 기준

1. PCI comb 0–3의 layout 좌표, mask 및 ordered DM-RS 일치
2. SFN, half-frame, kSSB 조합의 BCH roundtrip 및 scrambled 32-bit payload 일치
3. Lmax=4의 모든 SSB index와 두 half-frame에서 DM-RS sequence를 직접 비교
4. batch decoder의 clean channel CRC/parity와 block별 numerical error 처리
5. capture 수신 grid를 synthetic truth로 오인하지 않도록 provenance 검사

## 상태

M1 MATLAB package, batch decoder와 capture sanity가 구현됐습니다. 현재 MATLAB suite는 7 tests가 통과합니다. 세 capture CRC는 통과했지만 frame origin, Point A, 전체 operator waveform과 전송 경로 ground truth는 확인되지 않았습니다. 실행 명령 및 결과는 [MATLAB 구현 기록](../implementation/matlab.md)에 있습니다.
