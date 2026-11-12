import torch
from ssb.models import make_features, ResidualCNN
from test_estimators import mask_for


def test_features_and_gradient_batch_one():
    dm = mask_for(2); pb = ~dm
    x = torch.zeros((1,240,4),dtype=torch.complex64); x[:,dm] = 1
    y = x.clone()
    features, baseline = make_features(y,x,dm,pb,torch.tensor([.1]))
    assert features.shape == (1,8,240,4)
    assert torch.count_nonzero(features[:,2:4,:,0]) == 0
    net = ResidualCNN(8,1)
    result = net(features,baseline)
    result.abs().square().mean().backward()
    assert all(p.grad is not None and torch.isfinite(p.grad).all() for p in net.parameters())


def test_nonpilot_transmitted_values_cannot_change_features():
    dm = mask_for(3); pb = ~dm
    reference = torch.zeros((1, 240, 4), dtype=torch.complex64)
    reference[:, dm] = 1 + 1j
    y = reference.clone()
    first, baseline = make_features(y, reference, dm, pb, .1)
    reference[:, ~dm] = 1000 + 900j
    second, baseline2 = make_features(y, reference, dm, pb, .1)
    assert torch.equal(first, second)
    assert torch.equal(baseline, baseline2)
