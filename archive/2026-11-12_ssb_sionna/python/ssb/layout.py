"""Standard SS/PBCH resource-element layout in canonical coordinates."""
import numpy as np


def standard_layout(pci):
    if not isinstance(pci, (int, np.integer)) or not 0 <= pci <= 1007:
        raise ValueError("pci must be an integer in 0..1007")
    classes = np.zeros((240, 4), dtype=np.uint8)
    classes[56:183, 0] = 1
    classes[56:183, 2] = 2
    for l in (1, 2, 3):
        for k in range(240):
            if l == 2 and 48 <= k < 192:
                continue
            classes[k, l] = 3 if k % 4 == pci % 4 else 4
    result = {"class_id": classes}
    for name, value in (("pss", 1), ("sss", 2), ("dmrs", 3), ("pbch", 4)):
        l, k = np.nonzero((classes == value).T)
        result[name + "_kl"] = np.stack((k, l), axis=1).astype(np.int32)
    result.update(mask_dmrs=classes == 3, mask_pbch=classes == 4, mask_active=classes != 0)
    return result


def pilot_pattern(mask_dmrs, dmrs, device=None):
    """Build a Sionna pattern without changing compact pilot order or energy."""
    from sionna.phy.ofdm import PilotPattern
    import torch
    mask = np.asarray(mask_dmrs)
    values = np.asarray(dmrs)
    if mask.shape != (240, 4) or mask.dtype != np.bool_ or mask.sum() != 144 or values.shape != (144,):
        raise ValueError("Invalid pilot mask or vector")
    return PilotPattern(torch.as_tensor(mask.T.copy()[None, None], device=device),
                        torch.as_tensor(values[None, None], dtype=torch.complex64, device=device),
                        normalize=False, device=device)
