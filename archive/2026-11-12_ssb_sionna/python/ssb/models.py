"""Small residual estimator with only receiver-available inputs."""
import torch
from torch import nn
from .estimators import ls_interpolate, pilot_ls


def make_features(y, reference, mask_dmrs, mask_pbch, n0):
    dm = torch.as_tensor(mask_dmrs, dtype=torch.bool, device=y.device)
    pb = torch.as_tensor(mask_pbch, dtype=torch.bool, device=y.device)
    ls = ls_interpolate(y, reference, dm)
    pilots = pilot_ls(y, reference, dm)
    b = y.shape[0]
    n = torch.as_tensor(n0, dtype=y.real.dtype, device=y.device).reshape(-1)
    if n.numel() == 1:
        n = n.expand(b)
    if n.numel() != b or torch.any(n < 0):
        raise ValueError("n0 must be nonnegative and scalar or [B]")
    expand = lambda x: x.to(y.real.dtype).expand(b, -1, -1)
    features = torch.stack((ls.real, ls.imag, pilots.real, pilots.imag, expand(dm), expand(pb), torch.ones_like(ls.real), n.clamp_min(1e-12).log()[:, None, None].expand_as(ls.real)), dim=1)
    return features, ls


class ResidualBlock(nn.Module):
    def __init__(self, width):
        super().__init__()
        self.layers = nn.Sequential(nn.Conv2d(width, width, 3, padding=1), nn.ReLU(), nn.Conv2d(width, width, 3, padding=1))
    def forward(self, x):
        return torch.relu(x + self.layers(x))


class ResidualCNN(nn.Module):
    def __init__(self, width=32, blocks=3):
        super().__init__()
        self.width, self.blocks = width, blocks
        self.net = nn.Sequential(nn.Conv2d(8, width, 3, padding=1), nn.ReLU(), *(ResidualBlock(width) for _ in range(blocks)), nn.Conv2d(width, 2, 3, padding=1))
    def forward(self, features, baseline):
        delta = self.net(features)
        return baseline + torch.complex(delta[:, 0], delta[:, 1])
