"""Canonical operator profiles derived from capture metadata."""
import copy
import hashlib
import json
import math
from numbers import Real
from pathlib import Path


def _integer(value, name, lower, upper):
    if isinstance(value, bool) or not isinstance(value, Real) or not math.isfinite(value) or value != math.floor(value) or not lower <= value <= upper:
        raise ValueError(f"{name} must be an integer in {lower}..{upper}")
    return int(value)


def validate_profile_indices(profile):
    try:
        pci = _integer(profile["pci"], "pci", 0, 1007)
        lmax = _integer(profile["lmax"], "lmax", 4, 8)
        if lmax not in (4, 8):
            raise ValueError("lmax must be 4 or 8")
        index = _integer(profile["ssb_index"], "ssb_index", 0, lmax - 1)
        ibar = _integer(profile["ibar_ssb"], "ibar_ssb", 0, 7)
        if (lmax == 8 and ibar != index) or (lmax == 4 and ibar % 4 != index):
            raise ValueError("ibar_ssb is inconsistent with ssb_index and lmax")
        return {"pci": pci, "lmax": lmax, "ssb_index": index, "ibar_ssb": ibar}
    except KeyError as exc:
        raise ValueError(f"missing profile field {exc.args[0]}") from exc


def load_profile(operator_id, project_root=None):
    if operator_id not in {"skt", "kt", "lgu"}:
        raise ValueError(f"Unknown operator: {operator_id}")
    root = Path(project_root) if project_root is not None else Path(__file__).resolve().parents[2]
    path = root / "NRdump" / f"{operator_id}_40ms.json"
    data = path.read_bytes()
    raw = json.loads(data.decode("utf-8-sig"))
    sync = raw["sync_parameters"]
    index = _integer(sync["ssb_index"], "ssb_index", 0, 7)
    profile = {"operator_id": operator_id, "operator": raw["operator"],
            "pci": _integer(sync["target_pci"], "pci", 0, 1007), "ssb_index": index,
            "ibar_ssb": index, "lmax": 8, "scs_hz": float(raw["scs_khz"]) * 1000,
            "ssref_hz": float(sync["ssb_center_freq_hz"]),
            "capture_center_hz": float(raw["center_freq_hz"]),
            "sample_rate_hz": float(raw["sample_rate_hz"]), "raw": raw,
            "source_json": str(path), "source_sha256": hashlib.sha256(data).hexdigest()}
    validate_profile_indices(profile)
    return profile


def synthetic_profile(profile, pci):
    """Return a synthetic PCI override while preserving original provenance."""
    validate_profile_indices(profile)
    target = _integer(pci, "pci", 0, 1007)
    result = copy.deepcopy(profile)
    result["observed_pci"] = _integer(profile.get("observed_pci", profile["pci"]), "observed_pci", 0, 1007)
    result.update(profile_kind="synthetic_pci_override", pci=target, nid1=target // 3, nid2=target % 3)
    return result
