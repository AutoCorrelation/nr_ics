"""MATLAB exporter and common PBCH decoder subprocess bridge."""
import json
import os
from pathlib import Path
from numbers import Integral
import subprocess
import tempfile
import h5py
import numpy as np
from .profiles import _integer, validate_profile_indices

DEFAULT_MATLAB = Path(r"C:\Program Files\MATLAB\R2026a\bin\matlab.exe")
PROJECT_ROOT = Path(__file__).resolve().parents[2]


def _quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def _run(command, executable, timeout):
    exe = Path(executable) if executable else DEFAULT_MATLAB
    if not exe.is_file():
        raise FileNotFoundError(f"MATLAB executable not found: {exe}")
    script = f"addpath({_quote(PROJECT_ROOT / 'matlab')}); {command}"
    kwargs = {"capture_output": True, "text": True, "timeout": timeout, "cwd": str(PROJECT_ROOT)}
    if os.name == "nt":
        kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
    try:
        result = subprocess.run([str(exe), "-batch", script], **kwargs)
    except subprocess.TimeoutExpired as exc:
        raise TimeoutError(f"MATLAB timed out after {timeout}s: {exc}") from exc
    if result.returncode:
        raise RuntimeError(f"MATLAB failed ({result.returncode}):\n{result.stdout}\n{result.stderr}")


def export_reference(operator_id, output_path, num_blocks=128, seed=20261112, matlab_executable=None, *, timeout=600, pci=None):
    if operator_id not in {"skt", "kt", "lgu"} or isinstance(num_blocks, bool) or not isinstance(num_blocks, Integral) or num_blocks <= 0 or isinstance(seed, bool) or not isinstance(seed, Integral) or not 0 <= seed < 2**32:
        raise ValueError("invalid exporter arguments")
    if pci is not None:
        pci = _integer(pci, "pci", 0, 1007)
    out = Path(output_path).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    command = f"ssb.export_reference({_quote(operator_id)},{_quote(out)},'NumBlocks',{num_blocks},'Seed',{seed});"
    if pci is not None:
        command = command[:-2] + f",'PCI',{pci});"
    _run(command, matlab_executable, timeout)
    if not out.is_file():
        raise RuntimeError("MATLAB reported success but did not create reference")
    return out


def decode_batch(y, h_hat, n0, profile, *, work_dir, matlab_executable=None, list_length=8, timeout=600):
    y, h, n = np.asarray(y), np.asarray(h_hat), np.asarray(n0)
    if y.ndim != 3 or y.shape[1:] != (240, 4) or y.shape[0] == 0 or not np.iscomplexobj(y) or h.shape != y.shape or not np.iscomplexobj(h):
        raise ValueError("y and h_hat must be complex [B,240,4]")
    if n.shape != (y.shape[0],) or not np.issubdtype(n.dtype, np.number) or np.iscomplexobj(n):
        raise ValueError("n0 must be real [B]")
    if not isinstance(list_length, int) or list_length <= 0 or list_length & (list_length - 1):
        raise ValueError("list_length must be a positive power of two")
    manifest = validate_profile_indices(profile)
    manifest.update(list_length=list_length, noise_source="known_simulation", schema_version="ssb-decode-v1")
    root = Path(work_dir).resolve()
    root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ssb_decode_", dir=root) as tmp:
        inp, out = Path(tmp) / "input.h5", Path(tmp) / "output.h5"
        with h5py.File(inp, "w") as f:
            f.attrs["schema_version"] = "ssb-decode-v1"
            for key, a in (("rx/grid", y), ("estimate/grid", h)):
                f.create_dataset(key + "_real", data=a.real.astype(np.float32))
                f.create_dataset(key + "_imag", data=a.imag.astype(np.float32))
            f.create_dataset("noise/no", data=n.astype(np.float32))
            f.create_dataset("meta/manifest_json", data=np.frombuffer(json.dumps(manifest).encode("utf8"), dtype=np.uint8))
        _run(f"ssb.decode_batch_file({_quote(inp)},{_quote(out)});", matlab_executable, timeout)
        if not out.exists():
            raise RuntimeError("MATLAB reported success but did not create decoder output")
        with h5py.File(out, "r") as f:
            version = f.attrs.get("schema_version")
            if isinstance(version, bytes):
                version = version.decode()
            if version != "ssb-decode-result-v1":
                raise ValueError("invalid decoder result schema")
            shapes = {"crc": (len(y),), "scrblk": (len(y), 32), "trblk": (len(y), 24),
                      "sfn_lsb": (len(y), 4), "half_frame": (len(y),),
                      "msb_index_offset": (len(y),), "error_code": (len(y),)}
            result = {key: f["decoded/" + key][()] for key in shapes}
            for key, shape in shapes.items():
                if result[key].shape != shape or not np.issubdtype(result[key].dtype, np.integer):
                    raise ValueError(f"invalid decoder result {key}")
            return result
