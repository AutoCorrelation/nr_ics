# 프로젝트 환경 확인

2026-11-12에 `C:\workspace\nr_ics` 안에 uv 환경을 만들고 CUDA 및 MATLAB 연동을 확인했습니다. 이전에 확인한 상위 폴더의 공유 환경은 사용하지 않습니다.

| 항목 | 확인 결과 |
| --- | --- |
| 가상환경 | `C:\workspace\nr_ics\.venv` |
| Python / uv | CPython 3.11.16 / uv 0.12.13 |
| PyTorch / CUDA runtime | torch 2.9.1+cu128 / CUDA 12.8 / cuDNN 91002 |
| GPU | NVIDIA GeForce RTX 3060 12 GiB, driver 581.80, compute capability 8.6 |
| Sionna | sionna-no-rt 2.2.0 |
| MATLAB | MATLAB R2026a, 5G Toolbox 26.1 |

Smoke check에서 GPU float64 matrix multiplication을 CPU와 비교한 최대 오차는 `2.84e-14`, complex64 `[2,240,4]` 곱의 최대 오차는 `2.67e-7`이었습니다. 작은 Conv2d 모델의 forward, backward 및 optimizer update도 CUDA에서 실행했습니다. 상세 결과는 [CUDA 확인 JSON](pytorch_cuda_check.json)에서 확인할 수 있습니다.

환경 재현 및 검사 명령은 다음과 같습니다.

```powershell
uv sync --locked
uv run python scripts/check_pytorch_cuda.py --output docs/pytorch_cuda_check.json
uv pip check --python .venv/Scripts/python.exe
```

Sionna TDL/CDL 및 MATLAB bridge 평가에는 GPU와 MATLAB 5G Toolbox가 필요합니다. MATLAB Engine for Python은 설치하지 않았으며, bridge는 MATLAB `-batch`를 호출합니다.
