import numpy as np
import pytest
import torch
from ssb.estimators import ls_interpolate, LMMSE


def mask_for(shift=0):
    m = torch.zeros((240, 4), dtype=torch.bool)
    for l in (1, 3): m[shift::4, l] = True
    m[shift:48:4, 2] = True
    m[192+shift:240:4, 2] = True
    return m


@pytest.mark.parametrize("shift", range(4))
def test_ls_comb_edges_split_and_batch_one(shift):
    m = mask_for(shift)
    x = torch.zeros((1,240,4), dtype=torch.complex64); x[:,m] = 1+1j
    h = torch.ones_like(x) * (2+3j)
    h[:,192:,2] = 7+2j
    y = h*x
    out = ls_interpolate(y,x,m)
    assert out.dtype == torch.complex64
    assert torch.allclose(out[:, :48, 2], torch.full((1,48),2+3j))
    assert torch.allclose(out[:, 192:, 2], torch.full((1,48),7+2j))
    assert torch.allclose(out[:, 48:192, 2], torch.full((1,144),2+3j))
    assert torch.allclose(out[:,m], h[:,m])


def test_lmmse_covariance_and_validation_guard():
    torch.manual_seed(4)
    m = mask_for(1)
    h = torch.complex(torch.randn(20,1,1), torch.randn(20,1,1)).expand(-1,240,4).clone()
    with pytest.raises(ValueError): LMMSE.fit(h,m,partition="test")
    fit = LMMSE.fit(h,m,partition="train",loading=1e-5)
    x = torch.zeros((1,240,4),dtype=torch.complex64); x[:,m]=1
    out = fit.estimate(x*(1+2j),x,torch.tensor([0.]))
    assert torch.isfinite(out).all()
    assert torch.allclose(out, torch.full_like(out, 1+2j), atol=2e-3)


def test_lmmse_complex_cross_covariance():
    torch.manual_seed(41)
    mask = mask_for(0)
    a = torch.complex(torch.randn(100, 1), torch.randn(100, 1))
    channels = (a * (2 + 3j)).reshape(100, 1, 1).expand(-1, 240, 4).clone()
    channels[:, mask] = a
    estimator = LMMSE.fit(channels, mask, partition="train", loading=1e-5)
    reference = torch.zeros((1, 240, 4), dtype=torch.complex64)
    reference[:, mask] = 1
    estimate = estimator.estimate(reference * (0.7 - 1.2j), reference, 0)
    assert torch.allclose(estimate[0, 1, 1], torch.tensor((0.7 - 1.2j) * (2 + 3j)), atol=2e-3)
