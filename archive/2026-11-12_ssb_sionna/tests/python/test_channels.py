import numpy as np
import pytest
import torch
from ssb.channels import ChannelConfig, apply_channel

@pytest.mark.parametrize('device',['cpu']+(['cuda'] if torch.cuda.is_available() else []))
@pytest.mark.parametrize('family',['identity','flat','tdl','cdl'])
def test_channel(device,family):
    x=torch.ones((16,240,4),device=device,dtype=torch.complex64)
    a=apply_channel(x,ChannelConfig(family=family),float('inf'),123)
    b=apply_channel(x,ChannelConfig(family=family),float('inf'),123)
    assert a.rx.shape==a.h_true.shape==x.shape and a.rx.device==x.device
    assert torch.allclose(a.rx,a.h_true*x,atol=1e-6) and torch.equal(a.h_true,b.h_true)
    assert torch.any(a.h_true[0]!=a.h_true[1]) if family!='identity' else torch.all(a.h_true==1)

@pytest.mark.parametrize('device',['cpu']+(['cuda'] if torch.cuda.is_available() else []))
def test_noise_and_flat_power(device):
    x=torch.ones((2048,240,4),device=device,dtype=torch.complex64)
    a=apply_channel(x,ChannelConfig(),10,47); w=a.rx-x
    assert abs(w.abs().square().mean().item()-.1)<.002
    assert abs(w.real.var().item()-.05)<.001 and abs(w.imag.var().item()-.05)<.001
    b=apply_channel(x,ChannelConfig(family='flat'),float('inf'),55)
    assert abs(b.h_true.abs().square().mean().item()-1)<.08

@pytest.mark.parametrize('family',['tdl','cdl'])
def test_ensemble_power(family):
    x=torch.ones((512,240,4),dtype=torch.complex64)
    a=apply_channel(x,ChannelConfig(family=family),float('inf'),27)
    assert abs(a.h_true.abs().square().mean().item()-1)<.15

@pytest.mark.parametrize('key',['delay_spread_s','carrier_frequency_hz','speed_mps','scs_hz','ensemble_scale'])
@pytest.mark.parametrize('bad',[float('nan'),float('inf'),-float('inf')])
def test_invalid_channel_numbers(key,bad):
    cfg=ChannelConfig(**{key:bad})
    with pytest.raises(ValueError): apply_channel(torch.ones((1,240,4),dtype=torch.complex64),cfg,0,1)

@pytest.mark.parametrize('seed',[-1,1.0,1.5,True,2**64])
def test_bad_seed(seed):
    with pytest.raises(ValueError): apply_channel(torch.ones((1,240,4),dtype=torch.complex64),ChannelConfig(),0,seed)
