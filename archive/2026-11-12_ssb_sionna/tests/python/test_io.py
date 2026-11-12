import h5py
import numpy as np
import pytest
from ssb.layout import standard_layout
from ssb.io import SSBReference, read_reference, write_reference
from ssb.profiles import load_profile, synthetic_profile


def reference(b=1):
    a=standard_layout(508)
    pilots=np.exp(1j*np.arange(144)).astype(np.complex64)
    tx=np.zeros((b,240,4),np.complex64)
    tx[:,a['dmrs_kl'][:,0],a['dmrs_kl'][:,1]]=pilots
    tx[:,a['pbch_kl'][:,0],a['pbch_kl'][:,1]]=np.complex64(1+1j)
    m=load_profile('skt')
    m.update(source_kind='synthetic_tx',schema_version='ssb-grid-v1',seed=12,num_blocks=b,standard='38.212',bit_stage='nrBCH',power='EPRE=1',axis_order=['batch','subcarrier','symbol'],index_base=0,re_order='symbol_then_subcarrier',complex_storage='split_float32',k_ssb='per-block /bits/k_ssb')
    k=np.array(([0,15,16,31]*((b+3)//4))[:b],dtype=np.uint8)
    tr=np.zeros((b,24),np.uint8)
    tr[:,8:12]=(k[:,None] >> np.array([3,2,1,0])) & 1
    return SSBReference(tx=tx,dmrs=pilots,**a,trblk=tr,scrblk=np.zeros((b,32),np.uint8),codeword=np.zeros((b,864),np.uint8),sfn=np.arange(b,dtype=np.uint16),half_frame=np.zeros(b,np.uint8),k_ssb=k,msb_index_offset=(k >> 4),pbch_llr=np.arange(b*864,dtype=np.float32).reshape(b,864),manifest=m)

@pytest.mark.parametrize('b',[1,3])
def test_roundtrip(tmp_path,b):
    p=tmp_path/'a.h5'; r=reference(b); write_reference(p,r); got=read_reference(p)
    assert np.array_equal(got.tx,r.tx) and np.array_equal(got.dmrs,r.dmrs)
    assert got.tx.shape==(b,240,4)
    assert np.array_equal(got.k_ssb,r.k_ssb) and np.array_equal(got.pbch_llr,r.pbch_llr)
    with h5py.File(p,'r+') as f:
        raw=f['meta/manifest_json'][()]; del f['meta/manifest_json']; f['meta/manifest_json']=np.frombuffer(raw,dtype=np.uint8)
    assert read_reference(p).manifest==r.manifest

@pytest.mark.parametrize('damage',['mask','bits','order','transpose','pilot','missing'])
def test_reject_invalid(tmp_path,damage):
    p=tmp_path/'a.h5'; write_reference(p,reference())
    with h5py.File(p,'r+') as f:
        if damage=='mask': f['re/mask_dmrs'][0,0]=1
        if damage=='bits': f['bits/bch_transport'][0,0]=2
        if damage=='order': f['re/dmrs_kl'][0]=[4,1]
        if damage=='transpose':
            for name in ['real','imag']:
                d=f['tx/grid_'+name][()].transpose(0,2,1); del f['tx/grid_'+name]; f['tx/grid_'+name]=d
        if damage=='pilot': f['tx/dmrs_real'][0]=5
        if damage=='missing': del f['re/mask_active']
    with pytest.raises((ValueError,KeyError)): read_reference(p)

def test_zero_rx_and_capture_truth_rejected():
    r=reference(); r.rx=np.zeros_like(r.tx)
    from ssb.io import validate_reference
    validate_reference(r)
    r.manifest['source_kind']='capture_rx'
    with pytest.raises(ValueError): validate_reference(r)

def test_capture_unknown_metadata_roundtrip(tmp_path):
    r=reference(); r.rx=np.zeros_like(r.tx); r.tx=None; r.dmrs=None
    r.trblk=r.scrblk=r.codeword=r.sfn=r.half_frame=r.k_ssb=r.msb_index_offset=None
    r.manifest={'source_kind':'capture_rx','pci':None}
    p=tmp_path/'capture.h5'; write_reference(p,r); result=read_reference(p)
    assert result.tx is None and result.dmrs is None and np.all(result.rx==0)

@pytest.mark.parametrize('damage',['missing_k','shape_k','bad_k','bad_k_bits','llr_dtype','llr_shape','manifest','hash','seed','axis','source_pci'])
def test_contract_damage(tmp_path,damage):
    p=tmp_path/'a.h5'; write_reference(p,reference(4))
    with h5py.File(p,'r+') as f:
        if damage=='missing_k': del f['bits/k_ssb']
        if damage=='shape_k': del f['bits/k_ssb']; f['bits/k_ssb']=np.zeros(1,np.uint8)
        if damage=='bad_k': f['bits/k_ssb'][0]=32
        if damage=='bad_k_bits': f['bits/k_ssb'][0]=1
        if damage=='llr_dtype': del f['diagnostic/pbch_llr']; f['diagnostic/pbch_llr']=np.zeros((4,864),np.float64)
        if damage=='llr_shape': del f['diagnostic/pbch_llr']; f['diagnostic/pbch_llr']=np.zeros((1,864),np.float32)
        if damage in ('manifest','hash','seed','axis','source_pci'):
            import json
            m=json.loads(f['meta/manifest_json'][()])
            if damage=='manifest': del m['standard']
            if damage=='hash': m['source_sha256']='bad'
            if damage=='seed': m['seed']=1.5
            if damage=='axis': m['axis_order']=['symbol','subcarrier','batch']
            if damage=='source_pci': m['pci']=509
            del f['meta/manifest_json']; f['meta/manifest_json']=json.dumps(m)
    with pytest.raises((ValueError,KeyError)): read_reference(p)

@pytest.mark.parametrize('b',[1,16])
def test_matlab_reference_roundtrip(tmp_path,b):
    import pathlib
    golden=pathlib.Path('data/generated/skt_reference_v2.h5')
    if not golden.exists(): pytest.skip('MATLAB golden is unavailable')
    from dataclasses import replace
    r=read_reference(golden)
    arrays={k:getattr(r,k)[:b] for k in ('tx','rx','h_true','no','trblk','scrblk','codeword','sfn','half_frame','k_ssb','msb_index_offset','pbch_llr') if getattr(r,k) is not None}
    r=replace(r,**arrays,manifest={**r.manifest,'num_blocks':b})
    p=tmp_path/'golden.h5'; write_reference(p,r); o=read_reference(p)
    assert np.array_equal(o.k_ssb,r.k_ssb) and np.array_equal(o.pbch_llr,r.pbch_llr)
    assert np.array_equal(o.trblk,r.trblk) and np.array_equal(o.tx,r.tx)

@pytest.mark.parametrize('damage',['upper_k','sfn','block_count'])
def test_reject_inconsistent_labels(tmp_path,damage):
    r=reference(4)
    if damage=='upper_k': r.msb_index_offset[2] ^= 1
    elif damage=='sfn': r.sfn[2] = 16
    else: r.manifest['num_blocks'] = 128
    from ssb.io import validate_reference
    with pytest.raises(ValueError): validate_reference(r)

def test_override_manifest():
    from ssb.io import validate_reference
    r=reference(); r.manifest=synthetic_profile(r.manifest,508)
    validate_reference(r)
    r.manifest['observed_pci']=509
    with pytest.raises(ValueError): validate_reference(r)
