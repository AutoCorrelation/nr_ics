"""Validated HDF5 exchange for canonical SS/PBCH reference grids."""
from dataclasses import dataclass
import json
import math
import re
from numbers import Real
import h5py
import numpy as np
from .layout import standard_layout
from .profiles import _integer, validate_profile_indices


@dataclass
class SSBReference:
    tx: np.ndarray | None
    dmrs_kl: np.ndarray
    pbch_kl: np.ndarray
    pss_kl: np.ndarray
    sss_kl: np.ndarray
    dmrs: np.ndarray | None
    class_id: np.ndarray
    mask_dmrs: np.ndarray
    mask_pbch: np.ndarray
    mask_active: np.ndarray
    trblk: np.ndarray | None
    scrblk: np.ndarray | None
    codeword: np.ndarray | None
    sfn: np.ndarray | None
    half_frame: np.ndarray | None
    manifest: dict
    k_ssb: np.ndarray | None = None
    msb_index_offset: np.ndarray | None = None
    pbch_llr: np.ndarray | None = None
    rx: np.ndarray | None = None
    h_true: np.ndarray | None = None
    no: np.ndarray | None = None
    snr_db: np.ndarray | None = None

    def __post_init__(self):
        validate_reference(self)


def _array(x, shape, dtype, name):
    a = np.asarray(x)
    if a.shape != shape or a.dtype != np.dtype(dtype):
        raise ValueError(f"{name}: expected {dtype} {shape}, got {a.dtype} {a.shape}")
    if np.issubdtype(a.dtype, np.number) and not np.all(np.isfinite(a)):
        raise ValueError(f"{name} contains non-finite values")
    return a


def _validate_synthetic_manifest(m):
    validate_profile_indices(m)
    for key in ("operator_id", "operator", "source_json", "standard", "bit_stage", "power"):
        if not isinstance(m.get(key), str) or not m[key].strip():
            raise ValueError(f"manifest {key} must be a nonempty string")
    if m["operator_id"] not in {"skt", "kt", "lgu"}:
        raise ValueError("unknown operator_id")
    if not isinstance(m.get("raw"), dict) or not isinstance(m["raw"].get("sync_parameters"), dict):
        raise ValueError("manifest raw capture provenance is required")
    source_pci = _integer(m["raw"]["sync_parameters"].get("target_pci"), "raw target_pci", 0, 1007)
    if m.get("profile_kind") == "synthetic_pci_override":
        observed = _integer(m.get("observed_pci"), "observed_pci", 0, 1007)
        if observed != source_pci or _integer(m.get("nid1"), "nid1", 0, 335) != m["pci"] // 3 or _integer(m.get("nid2"), "nid2", 0, 2) != m["pci"] % 3:
            raise ValueError("synthetic override provenance or NID disagrees with PCI")
    elif m.get("profile_kind") not in (None, "observed") or m["pci"] != source_pci:
        raise ValueError("observed PCI differs from source provenance")
    digest = m.get("source_sha256")
    if not isinstance(digest, str) or re.fullmatch(r"[0-9a-fA-F]{64}", digest) is None:
        raise ValueError("manifest source_sha256 must be a SHA-256 hex digest")
    for key in ("scs_hz", "ssref_hz", "capture_center_hz", "sample_rate_hz"):
        value = m.get(key)
        if isinstance(value, bool) or not isinstance(value, Real) or not math.isfinite(value) or value <= 0:
            raise ValueError(f"manifest {key} must be positive and finite")
    _integer(m.get("seed"), "seed", 0, 2**32 - 1)
    if (m.get("schema_version") != "ssb-grid-v1" or m.get("axis_order") != ["batch", "subcarrier", "symbol"]
            or m.get("index_base") != 0 or m.get("re_order") != "symbol_then_subcarrier"
            or m.get("complex_storage") != "split_float32"):
        raise ValueError("invalid synthetic manifest axis or schema metadata")
    if m.get("k_ssb") != "per-block /bits/k_ssb":
        raise ValueError("manifest must identify the per-block k_ssb dataset")


def validate_reference(r):
    if not isinstance(r.manifest, dict) or r.manifest.get("source_kind") not in {"synthetic_tx", "reconstructed_tx", "capture_rx"}:
        raise ValueError("manifest source_kind must identify synthetic_tx, reconstructed_tx, or capture_rx")
    capture = r.manifest["source_kind"] == "capture_rx"
    if not capture:
        _validate_synthetic_manifest(r.manifest)
    if capture and any(v is not None for v in (r.tx, r.trblk, r.scrblk, r.codeword, r.sfn, r.half_frame, r.k_ssb, r.msb_index_offset, r.h_true, r.no, r.snr_db)):
        raise ValueError("capture_rx cannot contain clean transmit truth or synthetic channel/noise truth")
    grid = r.rx if capture else r.tx
    if grid is None or np.asarray(grid).ndim != 3 or np.asarray(grid).shape[1:] != (240, 4) or len(grid) == 0:
        raise ValueError("grid must have shape [B,240,4]")
    b = len(grid)
    manifest_blocks = r.manifest.get("num_blocks")
    if manifest_blocks is not None:
        manifest_blocks = _integer(manifest_blocks, "manifest num_blocks", 1, 2**31 - 1)
        if manifest_blocks != b:
            raise ValueError("manifest num_blocks disagrees with grid batch size")
    elif not capture:
        raise ValueError("synthetic manifest num_blocks is required")
    _array(grid, (b, 240, 4), np.complex64, "grid")
    pci = r.manifest.get("pci")
    if pci is None and capture:
        candidates = [standard_layout(i) for i in range(4)]
        layout = next ( (a for a in candidates if np.array_equal(r.class_id, a["class_id"])), None)
        if layout is None:
            raise ValueError("capture class_id does not match a standard layout")
    else:
        if not isinstance(pci, (int, np.integer)):
            raise ValueError("manifest pci is required")
        layout = standard_layout(pci)
    for name in ("dmrs_kl", "pbch_kl", "pss_kl", "sss_kl"):
        expected = layout[name]
        if not np.array_equal(_array(getattr(r, name), expected.shape, np.int32, name), expected):
            raise ValueError(f"{name} differs from the standard ordered layout")
    for name in ("class_id", "mask_dmrs", "mask_pbch", "mask_active"):
        expected = layout[name]
        if not np.array_equal(_array(getattr(r, name), (240, 4), expected.dtype, name), expected):
            raise ValueError(f"{name} differs from the standard layout")
    pilots = None if r.dmrs is None and capture else _array(r.dmrs, (144,), np.complex64, "dmrs")
    if not capture and not np.allclose(r.tx[:, r.dmrs_kl[:, 0], r.dmrs_kl[:, 1]], pilots[None, :], atol=1e-6, rtol=1e-6):
        raise ValueError("DM-RS values and coordinates do not match tx")
    if not capture:
        for name, size in (("trblk", 24), ("scrblk", 32), ("codeword", 864)):
            a = _array(getattr(r, name), (b, size), np.uint8, name)
            if np.any(a > 1):
                raise ValueError(f"{name} must contain binary bits")
        for name in ("sfn", "half_frame"):
            a = np.asarray(getattr(r, name))
            if a.shape != (b,) or not np.issubdtype(a.dtype, np.integer):
                raise ValueError(f"{name} must be integer [B]")
        k_ssb = np.asarray(r.k_ssb)
        if k_ssb.shape != (b,) or not np.issubdtype(k_ssb.dtype, np.integer) or np.any((k_ssb < 0) | (k_ssb > 31)):
            raise ValueError("k_ssb must be integer [B] in 0..31")
        msb = np.asarray(r.msb_index_offset)
        if msb.shape != (b,) or not np.issubdtype(msb.dtype, np.integer) or np.any((msb < 0) | (msb > 1)):
            raise ValueError("msb_index_offset must be integer [B] in 0..1")
        if np.any(msb != (k_ssb >> 4)):
            raise ValueError("k_ssb upper bit disagrees with msb_index_offset")
        low_bits = (r.trblk[:, 8:12].astype(np.int64) * np.array([8, 4, 2, 1])).sum(axis=1)
        if np.any(low_bits != k_ssb % 16):
            raise ValueError("k_ssb low bits disagree with transport fields")
        if np.any((r.sfn < 0) | (r.sfn > 1023)) or np.any((r.half_frame < 0) | (r.half_frame > 1)):
            raise ValueError("invalid SFN or half frame")
        sfn_msb = (r.trblk[:, 1:7].astype(np.int64) * (1 << np.arange(5, -1, -1))).sum(axis=1)
        if np.any(sfn_msb != (r.sfn.astype(np.int64) >> 4)):
            raise ValueError("SFN labels disagree with transport fields")
    if r.pbch_llr is not None:
        _array(r.pbch_llr, (b, 864), np.float32, "pbch_llr")
    for name in ("rx", "h_true"):
        if getattr(r, name) is not None:
            _array(getattr(r, name), (b, 240, 4), np.complex64, name)
    for name in ("no", "snr_db"):
        if getattr(r, name) is not None:
            _array(getattr(r, name), (b,), np.float32, name)
    if r.no is not None and np.any(r.no < 0):
        raise ValueError("noise variance must be nonnegative")
    return r


def _manifest(dataset):
    value = dataset[()]
    if isinstance(value, np.ndarray) and value.dtype == np.uint8:
        value = value.tobytes()
    if isinstance(value, bytes):
        value = value.decode("utf-8")
    return json.loads(value)


def _complex(f, prefix):
    real, imag = f[prefix + "_real"][()], f[prefix + "_imag"][()]
    if real.dtype != np.float32 or imag.dtype != np.float32 or real.shape != imag.shape:
        raise ValueError(f"{prefix}: invalid complex storage")
    return (real + 1j * imag).astype(np.complex64)


def read_reference(path):
    with h5py.File(path, "r") as f:
        def attr(name):
            v = f.attrs[name]
            return v.decode() if isinstance(v, bytes) else v
        if attr("schema_version") != "ssb-grid-v1" or attr("index_base") != 0 or attr("re_order") != "symbol_then_subcarrier" or attr("complex_storage") != "split_float32":
            raise ValueError("invalid reference schema metadata")
        for name, expected in (("axis_order", ["batch", "subcarrier", "symbol"]), ("index_columns", ["k", "l"])):
            v = attr(name)
            if isinstance(v, str):
                v = json.loads(v)
            else:
                v = [x.decode() if isinstance(x, bytes) else str(x) for x in v]
            if v != expected:
                raise ValueError(f"invalid {name}")
        manifest = _manifest(f["meta/manifest_json"])
        def optional(key):
            return f[key][()] if key in f else None
        def complex_optional(key):
            return _complex(f, key) if key + "_real" in f or key + "_imag" in f else None
        masks = {}
        for name in ("mask_dmrs", "mask_pbch", "mask_active"):
            a = f["re/" + name][()]
            if a.dtype != np.uint8 or np.any(a > 1):
                raise ValueError(f"invalid {name}")
            masks[name] = a.astype(bool)
        return SSBReference(tx=complex_optional("tx/grid"), dmrs=complex_optional("tx/dmrs"),
            **{name: f["re/" + name][()] for name in ("dmrs_kl", "pbch_kl", "pss_kl", "sss_kl", "class_id")},
            **masks, trblk=optional("bits/bch_transport"), scrblk=optional("bits/bch_payload_scrambled32"),
            codeword=optional("bits/bch_rate_matched"), sfn=optional("bits/sfn"), half_frame=optional("bits/half_frame"),
            manifest=manifest, k_ssb=optional("bits/k_ssb"), msb_index_offset=optional("bits/msb_index_offset"), pbch_llr=optional("diagnostic/pbch_llr"), rx=complex_optional("rx/grid"), h_true=complex_optional("channel/h_true"),
            no=optional("noise/no"), snr_db=optional("noise/snr_db"))


def write_reference(path, reference):
    r = validate_reference(reference)
    with h5py.File(path, "w") as f:
        f.attrs.update(schema_version="ssb-grid-v1", axis_order=json.dumps(["batch", "subcarrier", "symbol"]),
                       index_columns=json.dumps(["k", "l"]), index_base=0,
                       re_order="symbol_then_subcarrier", complex_storage="split_float32")
        def put(key, value):
            if value is not None:
                f.create_dataset(key, data=value)
        def complex_put(key, value):
            if value is not None:
                put(key + "_real", value.real.astype(np.float32))
                put(key + "_imag", value.imag.astype(np.float32))
        for name in ("dmrs_kl", "pbch_kl", "pss_kl", "sss_kl", "class_id", "mask_dmrs", "mask_pbch", "mask_active"):
            a = getattr(r, name)
            put("re/" + name, a.astype(np.uint8) if name.startswith("mask_") else a)
        for key, value in (("tx/grid", r.tx), ("tx/dmrs", r.dmrs), ("rx/grid", r.rx), ("channel/h_true", r.h_true)):
            complex_put(key, value)
        for key, value in (("bch_transport", r.trblk), ("bch_payload_scrambled32", r.scrblk), ("bch_rate_matched", r.codeword), ("sfn", r.sfn), ("half_frame", r.half_frame)):
            put("bits/" + key, value)
        put("bits/k_ssb", r.k_ssb)
        put("bits/msb_index_offset", r.msb_index_offset)
        put("diagnostic/pbch_llr", r.pbch_llr)
        put("noise/no", r.no)
        put("noise/snr_db", r.snr_db)
        f.create_dataset("meta/manifest_json", data=json.dumps(r.manifest, ensure_ascii=False), dtype=h5py.string_dtype("utf-8"))
