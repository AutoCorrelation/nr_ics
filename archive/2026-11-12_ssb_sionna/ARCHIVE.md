# SSB Sionna 구현 archive

2026년 11월 12일에 구현한 SSB/PBCH 채널 추정 및 벤치마크 작업을 MATLAB 기반 재구현과 구분하여 보관했습니다. 기존 디렉터리 구조를 유지하여 코드와 결과를 함께 살펴볼 수 있습니다.

- `matlab/+ssb/`: 당시 구현한 SSB/PBCH reference, capture 복호와 MATLAB decoder bridge입니다.
- `python/ssb/`: Sionna channel, LS/LMMSE/CNN 추정기, 공통 decoder 연결 및 지표 계산 코드입니다.
- `configs/experiments/`, `tests/`, `scripts/`: 실험 설정, 테스트와 환경 확인 코드입니다.
- `artifacts/`, `data/generated/`, `results/`: 생성 reference, checkpoint, 벤치마크 결과 및 검증 산출물입니다. 중단된 실행에서 생성된 파일도 보존했습니다.
- `docs/`와 `README.md`: 당시 설계, 구현 및 검증 기록입니다. `.agents/ssb_implementation/`에는 구현 작업 기록을 보관했습니다.
- `pyproject.toml`, `uv.lock`, `.python-version`: 당시 Python 환경 설정입니다.

최종 1,000-block 비교는 [결과 요약](docs/IMPLEMENTATION_RESULTS.md)과 [결과 JSON](artifacts/classical_1000/4e977a49bf40f225/results.json)에 있습니다. SNR은 −15:5:10 dB이고 LS + interpolation, LMMSE와 Perfect CSI를 비교했습니다.

기존 `NRdump/` capture와 초기 검색 스크립트는 작업 공간 루트에 남겨 두었습니다. 보관된 구현은 원래 작업 공간 루트를 기준으로 `NRdump/`와 MATLAB bridge를 찾도록 작성되었으므로, archive로 이동한 상태에서는 기존 실행 명령이 그대로 동작한다고 보장할 수 없습니다. 결과 JSON의 경로와 source hash는 실행 당시 기록입니다. 루트의 `.venv/`와 `.gitignore`는 유지했으며, `.gitignore` 사본도 여기에 보관했습니다.
