"""SISO reduced-grid channel simulation with a known complex noise variance."""
from dataclasses import dataclass, asdict
import math
import hashlib
import threading
from numbers import Integral
import torch
from .profiles import _integer

_LOCK = threading.Lock()


@dataclass(frozen=True)
class ChannelConfig:
    family: str = "identity"
    profile: str = "C"
    delay_spread_s: float = 100e-9
    carrier_frequency_hz: float = 3.5e9
    speed_mps: float = 0.0
    scs_hz: float = 30000.0
    ensemble_scale: float = 1.0


@dataclass
class ChannelBatch:
    rx: torch.Tensor
    h_true: torch.Tensor
    n0: torch.Tensor
    manifest: dict


def apply_channel(x, config, snr_db, seed):
    from sionna.phy import config as sionna_config
    from sionna.phy.channel import AWGN, OFDMChannel
    from sionna.phy.channel.tr38901 import TDL, CDL, Antenna
    from sionna.phy.ofdm import ResourceGrid
    if not isinstance(x, torch.Tensor) or x.dtype != torch.complex64 or x.ndim != 3 or tuple(x.shape[1:]) != (240, 4) or x.shape[0] < 1:
        raise ValueError("x must be torch complex64 [B,240,4]")
    if not torch.isfinite(x).all():
        raise ValueError("x contains non-finite values")
    if config.family not in {"identity", "flat", "tdl", "cdl"}:
        raise ValueError("unknown channel family")
    if not all(math.isfinite(v) for v in (config.delay_spread_s, config.carrier_frequency_hz, config.scs_hz, config.speed_mps, config.ensemble_scale)) or config.delay_spread_s <= 0 or config.carrier_frequency_hz <= 0 or config.scs_hz <= 0 or config.speed_mps < 0 or config.ensemble_scale <= 0:
        raise ValueError("invalid channel parameters")
    if isinstance(seed, bool) or not isinstance(seed, Integral):
        raise ValueError("seed must be an integer")
    seed = _integer(seed, "seed", 0, 2**64 - 1)
    snr = float(snr_db)
    if math.isnan(snr) or snr == -math.inf:
        raise ValueError("invalid snr_db")
    no = 0.0 if snr == math.inf else 10.0 ** (-snr / 10.0)
    if not math.isfinite(no):
        raise ValueError("invalid noise variance")
    device = str(x.device)
    with _LOCK:
        sionna_config.seed = int(seed)
        if config.family == "identity":
            h = torch.ones_like(x)
        elif config.family == "flat":
            flat_seed = int.from_bytes(hashlib.sha256(f"ssb-flat:{int(seed)}".encode()).digest()[:8], "big")
            generator = torch.Generator(device=x.device).manual_seed(flat_seed)
            real = torch.randn((x.shape[0], 1, 1), generator=generator, device=x.device)
            imag = torch.randn((x.shape[0], 1, 1), generator=generator, device=x.device)
            h = torch.complex(real, imag).expand_as(x) / math.sqrt(2)
        else:
            grid = ResourceGrid(4, 240, config.scs_hz, cyclic_prefix_length=0,
                                dc_null=False, device=device)
            if config.family == "tdl":
                model = TDL(config.profile, config.delay_spread_s, config.carrier_frequency_hz,
                            min_speed=config.speed_mps, max_speed=config.speed_mps,
                            spec_version="19.2", device=device)
            else:
                antenna = Antenna("single", "V", "omni", config.carrier_frequency_hz, device=device)
                model = CDL(config.profile, config.delay_spread_s, config.carrier_frequency_hz,
                            ut_array=antenna, bs_array=antenna, direction="downlink",
                            ut_orientation=torch.tensor([math.pi, 0., 0.], device=x.device),
                            bs_orientation=torch.zeros(3, device=x.device),
                            ut_velocity=torch.tensor([config.speed_mps, 0., 0.], device=x.device),
                            normalize_delays=True, spec_version="19.2", device=device)
            channel = OFDMChannel(model, grid, normalize_channel=False, return_channel=True, device=device)
            _, response = channel(x.transpose(1, 2)[:, None, None], None)
            h = response[:, 0, 0, 0, 0].transpose(1, 2)
        h = h * config.ensemble_scale
        signal = h * x
        rx = AWGN(device=device)(signal, no) if no else signal
    n0 = torch.full((x.shape[0],), no, device=x.device, dtype=torch.float32)
    manifest = {**asdict(config), "seed": int(seed), "device": device, "sionna_version": "2.2.0",
                "normalize_channel": False, "noise_source": "known_simulation", "es": 1.0,
                "snr_definition": "transmit_pbch_re_Es_N0", "dc_null": False,
                "timing": "idealized reduced grid; CP=0, symbol period=1/scs", "ici_isi": False}
    return ChannelBatch(rx, h, n0, manifest)
