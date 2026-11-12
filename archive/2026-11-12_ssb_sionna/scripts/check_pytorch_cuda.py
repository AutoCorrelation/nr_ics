"""Check the project environment, CUDA operations, and a small CNN backward pass."""

import argparse
import json
from pathlib import Path
import sys

import torch
from torch import nn


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parents[1]
    expected_prefix = project_root / ".venv"
    if Path(sys.prefix).resolve() != expected_prefix.resolve():
        raise RuntimeError(f"Expected project environment: {expected_prefix}; got {sys.prefix}")
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is unavailable in the project PyTorch environment.")

    torch.manual_seed(20261112)
    device = torch.device("cuda:0")
    properties = torch.cuda.get_device_properties(device)

    # Float64 keeps this correctness comparison independent of TF32 settings.
    left = torch.randn(128, 128, dtype=torch.float64)
    right = torch.randn(128, 128, dtype=torch.float64)
    expected = left @ right
    actual = left.to(device) @ right.to(device)
    torch.testing.assert_close(actual.cpu(), expected, rtol=1e-10, atol=1e-10)
    matmul_error = (actual.cpu() - expected).abs().max().item()

    # Exercise the complex dtype and canonical grid shape required by this project.
    grid = torch.randn(2, 240, 4, dtype=torch.complex64)
    channel = torch.randn(2, 240, 4, dtype=torch.complex64)
    received = grid.to(device) * channel.to(device)
    torch.testing.assert_close(received.cpu(), grid * channel, rtol=1e-6, atol=1e-6)
    complex_error = (received.cpu() - grid * channel).abs().max().item()

    model = nn.Sequential(
        nn.Conv2d(2, 8, kernel_size=3, padding=1),
        nn.ReLU(),
        nn.Conv2d(8, 2, kernel_size=3, padding=1),
    ).to(device)
    features = torch.randn(4, 2, 240, 4, device=device)
    target = torch.randn_like(features)
    optimizer = torch.optim.SGD(model.parameters(), lr=0.01)
    previous_weight = model[0].weight.detach().clone()
    optimizer.zero_grad(set_to_none=True)
    loss = (model(features) - target).square().mean()
    loss.backward()
    finite_gradients = all(
        parameter.grad is not None and torch.isfinite(parameter.grad).all().item()
        for parameter in model.parameters()
    )
    if not torch.isfinite(loss).item() or not finite_gradients:
        raise RuntimeError("CNN loss or gradients are non-finite.")
    optimizer.step()
    weight_changed = not torch.equal(previous_weight, model[0].weight.detach())
    if not weight_changed:
        raise RuntimeError("The CUDA optimizer step did not update the CNN weights.")
    torch.cuda.synchronize(device)

    result = {
        "status": "passed",
        "executable": sys.executable,
        "environment": sys.prefix,
        "python": sys.version.split()[0],
        "torch": torch.__version__,
        "cuda_runtime": torch.version.cuda,
        "cudnn": torch.backends.cudnn.version(),
        "cuda_available": torch.cuda.is_available(),
        "gpu": properties.name,
        "gpu_memory_bytes": properties.total_memory,
        "compute_capability": list(torch.cuda.get_device_capability(device)),
        "matmul_max_abs_error": matmul_error,
        "complex_grid_shape": list(received.shape),
        "complex_grid_max_abs_error": complex_error,
        "cnn_loss": loss.item(),
        "cnn_finite_gradients": finite_gradients,
        "cnn_weights_updated": weight_changed,
    }
    output = json.dumps(result, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
