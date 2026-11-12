"""Pilot-only channel estimators for synchronized SSB grids."""
from dataclasses import dataclass
import torch


def pilot_ls(y, reference, mask):
    mask = torch.as_tensor(mask, dtype=torch.bool, device=y.device)
    reference = torch.as_tensor(reference, device=y.device)
    if y.ndim != 3 or y.shape[1:] != (240, 4) or mask.shape != (240, 4):
        raise ValueError("expected y [B,240,4] and mask [240,4]")
    ref = reference.expand_as(y)
    if torch.any(ref[:, mask].abs() == 0):
        raise ValueError("pilot reference must be nonzero")
    result = torch.zeros_like(y)
    result[:, mask] = y[:, mask] / ref[:, mask]
    return result


def _interp(values, positions, start, end):
    x = torch.arange(start, end, device=values.device)
    if positions.numel() == 0:
        raise ValueError("missing pilots in interpolation band")
    right = torch.searchsorted(positions, x).clamp(0, positions.numel() - 1)
    left = (right - 1).clamp(0, positions.numel() - 1)
    p0, p1 = positions[left], positions[right]
    weight = (x - p0).to(values.real.dtype) / (p1 - p0).clamp_min(1)
    weight = weight.clamp(0, 1)
    return values[:, left] * (1 - weight) + values[:, right] * weight


def ls_interpolate(y, reference, mask):
    mask = torch.as_tensor(mask, dtype=torch.bool, device=y.device)
    z = pilot_ls(y, reference, mask)
    out = torch.zeros_like(y)
    for symbol in (1, 3):
        pos = torch.where(mask[:, symbol])[0]
        out[:, :, symbol] = _interp(z[:, pos, symbol], pos, 0, 240)
    out[:, :, 0] = out[:, :, 1]
    out[:, :, 2] = (out[:, :, 1] + out[:, :, 3]) / 2
    for start, end in ((0, 48), (192, 240)):
        pos = torch.where(mask[start:end, 2])[0] + start
        out[:, start:end, 2] = _interp(z[:, pos, 2], pos, start, end)
    return out


def perfect_csi(h_true):
    return h_true.clone()


@dataclass
class LMMSE:
    mean: torch.Tensor
    covariance: torch.Tensor
    pilot_mask: torch.Tensor
    sample_count: int
    loading: float = 1e-4

    @classmethod
    def fit(cls, channels, pilot_mask, *, partition, loading=1e-4):
        if partition != "train":
            raise ValueError("covariance must be fitted on the training partition")
        if channels.ndim != 3 or channels.shape[1:] != (240, 4) or channels.shape[0] < 2:
            raise ValueError("at least two training channels [B,240,4] are required")
        if loading <= 0:
            raise ValueError("loading must be positive")
        flat = channels.reshape(channels.shape[0], -1)
        mean = flat.mean(0)
        centered = flat - mean
        covariance = centered.T @ centered.conj() / (channels.shape[0] - 1)
        return cls(mean.detach(), covariance.detach(), torch.as_tensor(pilot_mask, dtype=torch.bool, device=channels.device).clone(), channels.shape[0], loading)

    def estimate(self, y, reference, n0):
        device = y.device
        mask = self.pilot_mask.to(device)
        z = pilot_ls(y, reference, mask)[:, mask]
        cov = self.covariance.to(device)
        mean = self.mean.to(device)
        idx = torch.where(mask.reshape(-1))[0]
        cpp = cov[idx][:, idx]
        cfp = cov[:, idx]
        ref = torch.as_tensor(reference, device=device).expand_as(y)[:, mask]
        noise = torch.as_tensor(n0, device=device, dtype=y.real.dtype).reshape(-1)
        if noise.numel() == 1:
            noise = noise.expand(y.shape[0])
        if noise.numel() != y.shape[0] or torch.any(noise < 0):
            raise ValueError("n0 must be nonnegative and scalar or [B]")
        diagonal = noise[:, None] / ref.abs().square() + self.loading
        system = cpp.unsqueeze(0) + torch.diag_embed(diagonal.to(cpp.dtype))
        weights = torch.linalg.solve(system, (z - mean[idx]).unsqueeze(-1))
        return (mean + (cfp.unsqueeze(0) @ weights).squeeze(-1)).reshape_as(y)

    def state_dict(self):
        return {"mean": self.mean.cpu(), "covariance": self.covariance.cpu(), "pilot_mask": self.pilot_mask.cpu(), "sample_count": self.sample_count, "loading": self.loading}

    @classmethod
    def from_state_dict(cls, state):
        return cls(**state)
