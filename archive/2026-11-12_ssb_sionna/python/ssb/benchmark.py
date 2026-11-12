"""Fixed-budget paired PBCH benchmark with the common MATLAB BCH decoder."""
import hashlib
import json
import importlib.metadata
import platform
import time
from pathlib import Path
import numpy as np
import torch
from .estimators import LMMSE, ls_interpolate, perfect_csi
from .metrics import binomial_stats, block_failures, channel_metrics, paired_difference
from .models import make_features
from .training import config_hash, train_model, load_checkpoint


def derive_seed(master, *parts):
    raw = json.dumps([master, *parts], separators=(",", ":")).encode()
    return int.from_bytes(hashlib.sha256(raw).digest()[:4], "big")


def split_manifest(master, profile, counts):
    manifest = {}
    for part, n in counts.items():
        if n <= 0:
            raise ValueError("all split counts must be positive")
        manifest[part] = {"count": n, "trajectory_ids": [f"{profile}:{part}:{i}" for i in range(n)], "payload_seed": derive_seed(master, profile, part, "payload"), "channel_seed": derive_seed(master, profile, part, "channel"), "noise_seed": derive_seed(master, profile, part, "noise")}
    audit_splits(manifest)
    return manifest


def audit_splits(manifest):
    ids, seeds = set(), set()
    for split, item in manifest.items():
        trajectories = item["trajectory_ids"]
        if len(trajectories) != item["count"] or len(set(trajectories)) != len(trajectories) or ids.intersection(trajectories):
            raise ValueError(f"overlapping or invalid trajectories in {split}")
        ids.update(trajectories)
        for key in ("payload_seed", "channel_seed", "noise_seed"):
            if item[key] in seeds:
                raise ValueError("split or random-domain seeds collide")
            seeds.add(item[key])
    return {"trajectories": len(ids), "overlap": 0, "random_domain_seeds": len(seeds)}


def _sync(device):
    if torch.device(device).type == "cuda":
        torch.cuda.synchronize(device)


def _file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _simulate(reference, config, split, conditions, device, batch_size):
    from .channels import ChannelConfig, apply_channel
    x = torch.as_tensor(reference.tx, dtype=torch.complex64)
    if len(x) != split["count"]:
        raise ValueError("reference block count disagrees with split")
    ys, hs, ns, metadata = [], [], [], []
    noise_generator = torch.Generator(device=device).manual_seed(split["noise_seed"])
    for start in range(0, len(x), batch_size):
        end = min(start + batch_size, len(x))
        condition = conditions[(start // batch_size) % len(conditions)]
        params = dict(condition["channel"])
        params.setdefault("scs_hz", config["scs_hz"])
        params.setdefault("carrier_frequency_hz", config["ssref_hz"])
        ch = ChannelConfig(**params)
        snr = float(condition["snr_db"])
        xx = x[start:end].to(device)
        # apply_channel owns a channel RNG; its generated noise is discarded.
        # Independent noise is generated from the separate noise-domain seed.
        sample = apply_channel(xx, ch, snr, derive_seed(split["channel_seed"], start))
        metadata.append({"start": start, "end": end, "channel_seed": derive_seed(split["channel_seed"], start), "noise_seed": split["noise_seed"], "channel_manifest": sample.manifest})
        h = sample.h_true
        n0 = torch.full((len(xx),), 10 ** (-snr / 10), dtype=torch.float32, device=device)
        noise = torch.complex(torch.randn(xx.shape, generator=noise_generator, device=device), torch.randn(xx.shape, generator=noise_generator, device=device)) * torch.sqrt(n0[:, None, None] / 2)
        ys.append((h * xx + noise).cpu()); hs.append(h.cpu()); ns.append(n0.cpu())
    return {"y": torch.cat(ys), "target": torch.cat(hs), "n0": torch.cat(ns), "reference": x, "channel_metadata": metadata}


def source_fingerprints():
    root = Path(__file__).resolve().parents[2]
    modules = ["benchmark.py", "estimators.py", "models.py", "training.py", "metrics.py", "channels.py", "profiles.py", "layout.py", "io.py", "matlab_bridge.py"]
    files = [root / "python" / "ssb" / name for name in modules]
    files.extend(sorted((root / "matlab" / "+ssb").glob("*.m")))
    return {str(p.relative_to(root)).replace("\\", "/"): _file_hash(p) for p in files}


def environment_info(device):
    versions = {}
    for package in ("numpy", "scipy", "sionna-no-rt", "h5py", "matplotlib"):
        try:
            versions[package] = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:
            versions[package] = None
    versions.update(torch=str(torch.__version__), cuda=torch.version.cuda, device=str(device),
                    gpu=torch.cuda.get_device_name(torch.device(device)) if torch.device(device).type == "cuda" else None,
                    platform=platform.platform())
    return versions


def test_pilot_covariance(covariance, pilot_mask):
    """Reuse whole-grid training covariance; select the test geometry only."""
    mask = torch.as_tensor(pilot_mask, dtype=torch.bool, device=covariance.pilot_mask.device)
    if mask.shape != (240, 4) or int(mask.sum()) != 144:
        raise ValueError("invalid test pilot mask")
    return LMMSE(covariance.mean, covariance.covariance, mask, covariance.sample_count, covariance.loading)


def _reference(name, path, spec, profile, config, *, pci=None):
    from .io import read_reference
    from .matlab_bridge import export_reference
    if not path.exists():
        kwargs = {} if pci is None else {"pci": pci}
        export_reference(name, path, num_blocks=spec["count"], seed=spec["payload_seed"],
                         matlab_executable=config.get("matlab_executable"), **kwargs)
    ref = read_reference(path)
    for key in ("operator_id", "pci", "ssb_index", "ibar_ssb", "lmax", "source_sha256"):
        if ref.manifest.get(key) != profile[key]:
            raise ValueError(f"cached reference profile mismatch: {key}")
    if int(ref.manifest.get("seed", -1)) != spec["payload_seed"] or len(ref.tx) != spec["count"]:
        raise ValueError("cached reference seed or count mismatch")
    return ref


def _evaluate(profile, ref, split, conditions, config, cov, models, directory, master):
    from .matlab_bridge import decode_batch
    device = config.get("device", "cpu")
    chunk = int(config.get("generation_batch_size", 32))
    eval_batch = int(config.get("evaluation_batch_size", 32))
    decode_limit = int(config.get("decoder_batch_size", 1024))
    if min(chunk, eval_batch, decode_limit) < 1:
        raise ValueError("batch sizes must be positive")
    dm, pb = ref.mask_dmrs, ref.mask_pbch
    test_cov = test_pilot_covariance(cov, dm)
    results = [{"condition": c, "methods": {}, "paired_differences": {}} for c in conditions]
    failure_sets = [{} for _ in conditions]
    pending_y, pending_h, pending_n, pending_info = [], [], [], []
    pending_count = 0
    decoder_seconds = 0.
    decoder_calls = 0
    def flush():
        nonlocal pending_count, decoder_seconds, decoder_calls
        if not pending_count:
            return
        start = time.perf_counter()
        decoded = decode_batch(np.concatenate(pending_y), np.concatenate(pending_h), np.concatenate(pending_n), profile,
                               work_dir=directory / "decode", matlab_executable=config.get("matlab_executable"))
        decoder_seconds += time.perf_counter() - start
        decoder_calls += 1
        offset = 0
        for ci, method, begin, end in pending_info:
            size = end - begin
            d = {key: np.asarray(value)[offset:offset+size] for key, value in decoded.items()}
            diag = block_failures(d, ref.scrblk[begin:end], ref.trblk[begin:end], ref.half_frame[begin:end], ref.sfn[begin:end])
            fails = diag.pop("failure")
            failure_sets[ci][method][begin:end] = fails
            aggregate = results[ci]["methods"][method]
            for key, value in diag.items():
                if isinstance(value, dict):
                    dst = aggregate.setdefault(key, {})
                    for k, v in value.items(): dst[k] = dst.get(k, 0) + v
                else:
                    aggregate[key] = aggregate.get(key, 0) + value
            offset += size
        pending_y.clear(); pending_h.clear(); pending_n.clear(); pending_info.clear()
        pending_count = 0
    for ci, condition in enumerate(conditions):
        spec = dict(split, channel_seed=derive_seed(split["channel_seed"], ci), noise_seed=derive_seed(split["noise_seed"], ci))
        data = _simulate(ref, profile, spec, [condition], device, chunk)
        results[ci]["simulation"] = {"channel_seed": spec["channel_seed"], "noise_seed": spec["noise_seed"],
                                     "payload_seed": split["payload_seed"], "batches": data["channel_metadata"]}
        y, true, n, tx = (data[k].to(device) for k in ("y", "target", "n0", "reference"))
        methods = [("perfect", lambda sl: perfect_csi(true[sl])),
                   ("ls", lambda sl: ls_interpolate(y[sl], tx[sl], dm)),
                   ("lmmse", lambda sl: test_cov.estimate(y[sl], tx[sl], n[sl]))]
        for key, model in models.items():
            def infer(sl, model=model):
                f, ls = make_features(y[sl], tx[sl], dm, pb, n[sl])
                return model(f, ls)
            methods.append((f"cnn_{key}", infer))
        for method, fn in methods:
            _sync(device); start = time.perf_counter()
            with torch.no_grad():
                estimate = torch.cat([fn(slice(i, min(i + eval_batch, len(y)))) for i in range(0, len(y), eval_batch)])
            _sync(device); elapsed = time.perf_counter() - start
            if not torch.isfinite(estimate).all():
                raise ValueError(f"nonfinite estimate: {method}")
            yh, th, yh_rx, xh, no = (a.cpu().numpy() for a in (estimate, true, y, tx, n))
            metric = channel_metrics(yh, th, yh_rx, xh, no, pb)
            results[ci]["methods"][method] = {**metric, "estimator_wall_seconds": elapsed}
            failure_sets[ci][method] = np.empty(len(y), dtype=bool)
            begin = 0
            while begin < len(y):
                size = min(len(y)-begin, decode_limit-pending_count)
                end = begin + size
                pending_y.append(yh_rx[begin:end]); pending_h.append(yh[begin:end]); pending_n.append(no[begin:end])
                pending_info.append((ci, method, begin, end))
                begin = end; pending_count += size
                if pending_count == decode_limit: flush()
    flush()
    for ci, result in enumerate(results):
        for method, fail in failure_sets[ci].items():
            result["methods"][method].update(binomial_stats(int(fail.sum()), len(fail)))
        result["paired_differences"] = {name + "_minus_ls": paired_difference(f, failure_sets[ci]["ls"], seed=derive_seed(master, name, ci)) for name, f in failure_sets[ci].items() if name != "ls"}
    return results, {"wall_seconds": decoder_seconds, "calls": decoder_calls, "max_blocks_per_call": decode_limit}


def run(config):
    from .profiles import load_profile
    required = ("profiles", "train_count", "validation_count", "test_count", "training_conditions", "test_conditions", "training_seeds")
    if any(not config.get(k) for k in required if k != "training_seeds") or "training_seeds" not in config:
        raise ValueError("missing or empty benchmark configuration")
    device = config.get("device", "cpu")
    if device.startswith("cuda") and not torch.cuda.is_available(): raise RuntimeError("CUDA requested but unavailable")
    output = Path(config.get("output_dir", "artifacts/benchmark")) / config_hash(config)[:16]
    output.mkdir(parents=True, exist_ok=True)
    fingerprints = source_fingerprints()
    report = {"config": config, "config_sha256": config_hash(config), "noise_source": "known_simulation",
              "statistics": "fixed-N, conditional on known synchronization", "environment": environment_info(device),
              "source_sha256": fingerprints, "profiles": {}}
    master = int(config.get("seed", 20261112))
    chunk = int(config.get("generation_batch_size", 32))
    if chunk < 1: raise ValueError("generation_batch_size must be positive")
    overrides = config.get("test_profile_overrides", {})
    if set(overrides) - set(config["profiles"]): raise ValueError("override must name a configured base profile")
    for name in config["profiles"]:
        profile = load_profile(name)
        directory = output / name; directory.mkdir(parents=True, exist_ok=True)
        counts = {"train": int(config["train_count"]), "validation": int(config["validation_count"]), "test": int(config["test_count"])}
        splits = split_manifest(master, name, counts)
        paths = {part: directory / f"{part}_{spec['payload_seed']}_{spec['count']}.h5" for part, spec in splits.items()}
        refs = {part: _reference(name, paths[part], spec, profile, config) for part, spec in splits.items()}
        provenance = {"split_sha256": config_hash(splits), "reference_sha256": {p: _file_hash(path) for p, path in paths.items()},
                      "source_sha256": fingerprints, "environment": report["environment"]}
        train = _simulate(refs["train"], profile, splits["train"], config["training_conditions"], device, chunk)
        val = _simulate(refs["validation"], profile, splits["validation"], config["training_conditions"], device, chunk)
        dm, pb = refs["train"].mask_dmrs, refs["train"].mask_pbch
        cov_path = directory / "covariance.pt"
        if cov_path.exists():
            saved = torch.load(cov_path, map_location="cpu", weights_only=True)
            if saved["config_sha256"] != report["config_sha256"] or saved["provenance"] != provenance: raise ValueError("covariance provenance mismatch")
            cov = LMMSE.from_state_dict(saved["state"])
        else:
            cov = LMMSE.fit(train["target"], dm, partition="train", loading=float(config.get("diagonal_loading", 1e-4)))
            torch.save({"state": cov.state_dict(), "config_sha256": report["config_sha256"], "provenance": provenance}, cov_path)
        models = {}
        model_seeds = [derive_seed(master, name, "model", int(s)) for s in config["training_seeds"]]
        used_seeds = {item[k] for item in splits.values() for k in ("payload_seed", "channel_seed", "noise_seed")}
        if len(set(model_seeds)) != len(model_seeds) or used_seeds.intersection(model_seeds): raise ValueError("model seed collision")
        for label, model_seed in zip(config["training_seeds"], model_seeds):
            tc = dict(config.get("training", {}), seed=model_seed)
            path = directory / f"cnn_{label}.pt"
            if path.exists():
                models[str(label)], saved = load_checkpoint(path, device)
                if saved["config"] != tc or saved["provenance"] != provenance: raise ValueError("checkpoint provenance mismatch")
            else:
                models[str(label)], _ = train_model(train, val, dm, pb, config=tc, device=device, checkpoint=path, provenance=provenance)
        pilot_index = torch.where(cov.pilot_mask.reshape(-1))[0]
        eigenvalues = torch.linalg.eigvalsh(cov.covariance[pilot_index][:, pilot_index]).real
        loaded = eigenvalues + cov.loading
        entry = {"profile_kind": "observed", "profile": profile, "profile_source_sha256": profile["source_sha256"],
                 "reference_manifests": {key: value.manifest for key, value in refs.items()},
                 "covariance_diagnostics": {"sample_count": cov.sample_count, "diagonal_loading": cov.loading,
                    "pilot_min_eigenvalue": float(eigenvalues.min()), "loaded_condition_number": float(loaded.max()/loaded.min())},
                 "split_manifest": splits, "split_audit": audit_splits(splits), "provenance": provenance,
                 "training_channel_metadata": train["channel_metadata"], "validation_channel_metadata": val["channel_metadata"],
                 "covariance_sha256": _file_hash(cov_path), "checkpoints": {key: _file_hash(directory / f"cnn_{key}.pt") for key in models},
                 "model_seeds": model_seeds, "overrides": {}}
        entry["conditions"], entry["decoder"] = _evaluate(profile, refs["test"], splits["test"], config["test_conditions"], config, cov, models, directory, master)
        for override in overrides.get(name, []):
            from .profiles import synthetic_profile
            label = override["label"]; pci = override["pci"]
            if not isinstance(label, str) or not label or label in entry["overrides"] or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in label):
                raise ValueError("override labels must be unique safe identifiers")
            synthetic = synthetic_profile(profile, pci)
            override_split = split_manifest(derive_seed(master, name, label, pci), f"{name}:{label}", {"test": counts["test"]})["test"]
            path = directory / f"test_{label}_{pci}_{override_split['payload_seed']}_{override_split['count']}.h5"
            ref = _reference(name, path, override_split, synthetic, config, pci=pci)
            conditions, decoder = _evaluate(synthetic, ref, override_split, config["test_conditions"], config, cov, models, directory / label, master)
            entry["overrides"][label] = {"profile_kind": "synthetic_pci_override", "profile": synthetic,
                "reference_manifest": ref.manifest, "reference_sha256": _file_hash(path), "split": override_split,
                "training_profile": name, "covariance_sha256": entry["covariance_sha256"], "checkpoints": entry["checkpoints"],
                "conditions": conditions, "decoder": decoder}
        report["profiles"][name] = entry
        (output / "results.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    return report, output / "results.json"
