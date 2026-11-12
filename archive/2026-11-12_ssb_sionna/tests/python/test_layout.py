import numpy as np
import pytest
import torch
from ssb.layout import standard_layout, pilot_pattern

@pytest.mark.parametrize('pci', [508,325,960,2,3])
def test_layout(pci):
    a=standard_layout(pci)
    assert [len(a[k+'_kl']) for k in ['pss','sss','dmrs','pbch']] == [127,127,144,432]
    assert [int((a['dmrs_kl'][:,1]==l).sum()) for l in (1,2,3)]==[60,24,60]
    assert a['mask_active'].sum()==830
    p=np.exp(1j*np.arange(144)).astype(np.complex64)
    pat=pilot_pattern(a['mask_dmrs'],p)
    assert torch.equal(pat.pilots.cpu().flatten(), torch.from_numpy(p))
    assert np.array_equal(np.argwhere(pat.mask.cpu().numpy()[0,0]).astype(np.int32)[:,::-1],a['dmrs_kl'])
