# NR ICS: SSB/PBCH 채널 추정 평가

MATLAB R2026a 5G Toolbox로 표준 5G NR SSB와 PBCH DM-RS를 생성하고, Python 0-based `[subcarrier, symbol]` grid로 교환해 Sionna/PyTorch 채널과 채널 추정기를 평가하는 프로젝트입니다. 구현 현황과 검증 범위는 [구현 및 검증 결과](docs/IMPLEMENTATION_RESULTS.md), 전체 단계는 [프로젝트 계획](docs/PROJECT_PLAN.md)에 기록했습니다.

## 환경

프로젝트 루트에서 `uv sync --locked`를 실행하면 Python 3.11과 잠금된 의존성을 설치합니다. CUDA 구성은 RTX 3060에서 확인했습니다. MATLAB bridge를 사용하려면 MATLAB R2026a와 5G Toolbox도 설치되어 있어야 합니다.

```powershell
uv sync --locked
uv run python scripts/check_pytorch_cuda.py --output docs/pytorch_cuda_check.json
```

현재 설치·검사 결과는 [환경 확인 기록](docs/ENVIRONMENT_CHECK.md)에서 확인할 수 있습니다.

## 주요 명령

```powershell
# MATLAB에서 128 block reference 생성
uv run python -c "from ssb.matlab_bridge import export_reference; export_reference('skt', 'data/generated/skt_reference.h5', num_blocks=128)"

# 작은 연결 smoke 및 3개 통신사 quick 평가
uv run ssb-benchmark run --config configs/experiments/smoke.json
uv run ssb-benchmark run --config configs/experiments/quick.json

# 고정 budget SNR sweep, PCI 326/327 OOD 평가
uv run ssb-benchmark run --config configs/experiments/validation.json
uv run ssb-benchmark plot --results artifacts/validation/<run-id>/results.json --output-dir artifacts/validation/<run-id>/plots

# Python 단위 및 통합 테스트
uv run pytest -q
```

평가 출력은 설정 hash별 `artifacts/` 하위에 저장됩니다. `results.json`에는 split 및 seed, source/config hash, 실행 환경, channel realization, estimator별 NMSE/EVM/BLER, 정확 이항 구간과 paired 차이가 기록됩니다. Plot에는 표본 수와 zero-error 상한이 표시됩니다.

## 모델 범위

기준 grid는 240 subcarrier × 4 symbol이며 HDF5에는 complex64 값을 실수부와 허수부 float32로 나누어 저장합니다. MATLAB은 BCH reference와 공통 decoder를 제공하고, Python은 LS, training covariance 기반 LMMSE, residual CNN 및 Sionna identity/TDL/CDL channel을 제공합니다. BLER의 `N0`는 simulation에서 알려진 값이며 평가는 synchronization이 알려진 주파수 영역 SISO 조건부 결과입니다. 시간 영역 acquisition, CFO/ICI, MIMO, Point A와 operator별 전체 waveform의 실측 보정은 별도 단계입니다.
