"""Masked supervised training and reproducible checkpoint serialization."""
import copy
import hashlib
import json
from pathlib import Path
import torch
from .models import ResidualCNN, make_features


def config_hash(config):
    return hashlib.sha256(json.dumps(config, sort_keys=True, separators=(",", ":"), default=str).encode()).hexdigest()


def masked_mse(estimate, target, mask):
    mask = torch.as_tensor(mask, device=estimate.device, dtype=torch.bool)
    if not mask.any():
        raise ValueError("empty loss mask")
    return (estimate[:, mask] - target[:, mask]).abs().square().mean()


def train_model(train, validation, mask_dmrs, mask_pbch, *, config, device="cpu", checkpoint=None, provenance=None):
    """Datasets are dicts of y, reference, n0 and target tensors, not model features."""
    seed = int(config.get("seed", 1))
    torch.manual_seed(seed)
    model = ResidualCNN(int(config.get("width", 32)), int(config.get("blocks", 3))).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=float(config.get("lr", 1e-3)))
    batch_size = int(config.get("batch_size", 32))
    epochs = int(config.get("epochs", 30))
    patience = int(config.get("patience", 5))
    if min(batch_size, epochs, patience) <= 0:
        raise ValueError("batch_size, epochs and patience must be positive")
    generator = torch.Generator().manual_seed(seed)
    best, best_state, history, stale = float("inf"), None, [], 0
    def batches(data, indices, training):
        model.train(training)
        total, count = 0., 0
        with torch.set_grad_enabled(training):
            for ix in indices.split(batch_size):
                y = data["y"][ix].to(device)
                ref = data["reference"]
                if ref.ndim == 3 and ref.shape[0] != 1:
                    ref = ref[ix]
                ref = ref.to(device)
                n0 = data["n0"][ix].to(device)
                target = data["target"][ix].to(device)
                features, ls = make_features(y, ref, mask_dmrs, mask_pbch, n0)
                loss = masked_mse(model(features, ls), target, mask_pbch)
                if not torch.isfinite(loss):
                    raise ValueError("nonfinite training loss")
                if training:
                    optimizer.zero_grad(set_to_none=True)
                    loss.backward()
                    optimizer.step()
                total += loss.item() * len(ix)
                count += len(ix)
        if not count:
            raise ValueError("empty training or validation partition")
        return total / count
    for epoch in range(epochs):
        tr = batches(train, torch.randperm(len(train["y"]), generator=generator), True)
        val = batches(validation, torch.arange(len(validation["y"])), False)
        history.append({"epoch": epoch + 1, "train_mse": tr, "validation_mse": val})
        if val < best:
            best, best_state, stale = val, copy.deepcopy(model.state_dict()), 0
        else:
            stale += 1
            if stale >= patience:
                break
    model.load_state_dict(best_state)
    model.eval()
    artifact = {"model": model.state_dict(), "config": config, "config_sha256": config_hash(config), "provenance": provenance or {}, "history": history, "best_validation_mse": best, "architecture": {"width": model.width, "blocks": model.blocks}}
    if checkpoint:
        Path(checkpoint).parent.mkdir(parents=True, exist_ok=True)
        torch.save(artifact, checkpoint)
    return model, artifact


def load_checkpoint(path, device="cpu"):
    artifact = torch.load(path, map_location=device, weights_only=True)
    if artifact["config_sha256"] != config_hash(artifact["config"]):
        raise ValueError("checkpoint config hash mismatch")
    model = ResidualCNN(**artifact["architecture"]).to(device)
    model.load_state_dict(artifact["model"])
    model.eval()
    return model, artifact
