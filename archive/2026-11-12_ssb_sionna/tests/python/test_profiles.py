import pytest
from ssb.profiles import load_profile

@pytest.mark.parametrize('name,pci,index', [('skt',508,1),('kt',325,1),('lgu',960,4)])
def test_profile(name,pci,index):
    p=load_profile(name)
    assert (p['pci'],p['ssb_index'],p['ibar_ssb'],p['lmax']) == (pci,index,index,8)
    assert p['scs_hz']==30000 and len(p['source_sha256'])==64
    assert 'point_a_hz' not in p

def test_bad_profile():
    with pytest.raises(ValueError): load_profile('bad')

@pytest.mark.parametrize('pci',[326,327])
def test_synthetic_profile(pci):
    from ssb.profiles import synthetic_profile
    original=load_profile('kt'); other=synthetic_profile(original,pci)
    assert other['profile_kind']=='synthetic_pci_override' and other['observed_pci']==325
    assert other['pci']==pci and (other['nid1'],other['nid2'])==(pci//3,pci%3)
    assert other['source_sha256']==original['source_sha256'] and other['raw']==original['raw']
    other['raw']['operator']='modified'; assert original['raw']['operator']=='KT'

@pytest.mark.parametrize('key,value',[('pci',1.9),('pci',1008),('pci',True),('ssb_index',1.9),('ssb_index',9),('lmax',7),('ibar_ssb',2)])
def test_reject_profile_index(key,value):
    from ssb.profiles import validate_profile_indices
    p=load_profile('skt'); p[key]=value
    with pytest.raises(ValueError): validate_profile_indices(p)

def test_lmax4():
    from ssb.profiles import validate_profile_indices
    p=load_profile('skt'); p.update(lmax=4,ssb_index=1,ibar_ssb=5)
    assert validate_profile_indices(p)['ibar_ssb']==5
    p['ssb_index']=4
    with pytest.raises(ValueError): validate_profile_indices(p)
