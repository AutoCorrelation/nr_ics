import subprocess
import h5py
import numpy as np
import pytest
from ssb.matlab_bridge import decode_batch, export_reference

P={'pci':508,'ssb_index':1,'ibar_ssb':1,'lmax':8}

def test_missing_executable(tmp_path):
    with pytest.raises(FileNotFoundError): export_reference('skt',tmp_path/'x',matlab_executable=tmp_path/'missing')

def test_process_failure(tmp_path,monkeypatch):
    executable=tmp_path/'matlab'; executable.touch()
    monkeypatch.setattr(subprocess,'run',lambda *a,**k: subprocess.CompletedProcess(a,1,'out','license failure'))
    with pytest.raises(RuntimeError,match='license failure'): export_reference('skt',tmp_path/'x',matlab_executable=executable)

def test_decode_contract(tmp_path,monkeypatch):
    executable=tmp_path/'matlab'; executable.touch()
    def run(args,**kwargs):
        import re
        paths=re.findall(r"'([^']+\.h5)'",args[2]); inp,out=paths[-2:]
        with h5py.File(inp,'r') as f:
            assert f['rx/grid_real'].shape==(1,240,4) and f['noise/no'][0]==np.float32(.2)
            assert f['rx/grid_real'][0,7,2]==7
        with h5py.File(out,'w') as f:
            f.attrs['schema_version']='ssb-decode-result-v1'
            for k,shape in {'crc':(1,),'scrblk':(1,32),'trblk':(1,24),'sfn_lsb':(1,4),'half_frame':(1,),'msb_index_offset':(1,),'error_code':(1,)}.items(): f['decoded/'+k]=np.zeros(shape,np.uint8)
        return subprocess.CompletedProcess(args,0,'','')
    monkeypatch.setattr(subprocess,'run',run)
    x=np.zeros((1,240,4),np.complex64); x[0,7,2]=7+3j
    r=decode_batch(x,x,np.array([.2]),P,work_dir=tmp_path,matlab_executable=executable)
    assert r['scrblk'].shape==(1,32)

def test_timeout(tmp_path,monkeypatch):
    executable=tmp_path/'matlab'; executable.touch()
    def fail(*args,**kwargs):
        raise subprocess.TimeoutExpired(args[0],1)
    monkeypatch.setattr(subprocess,'run',fail)
    with pytest.raises(TimeoutError,match='timed out'):
        export_reference('skt',tmp_path/'x',matlab_executable=executable,timeout=1)

@pytest.mark.parametrize('key,value',[('pci',1.9),('pci',1008),('ssb_index',1.9),('ssb_index',9),('lmax',7),('ibar_ssb',2)])
def test_decode_rejects_invalid_profile_before_launch(tmp_path,key,value):
    p=dict(P); p[key]=value
    x=np.zeros((1,240,4),np.complex64)
    with pytest.raises(ValueError): decode_batch(x,x,np.ones(1),p,work_dir=tmp_path,matlab_executable=tmp_path/'missing')

def test_export_override_command(tmp_path,monkeypatch):
    import ssb.matlab_bridge as bridge
    out=tmp_path/'x.h5'
    def run(cmd,executable,timeout):
        assert "'PCI',326" in cmd
        out.touch()
    monkeypatch.setattr(bridge,'_run',run)
    assert export_reference('kt',out,pci=326)==out.resolve()
    for invalid in (1.9,1008,True,-1):
        with pytest.raises(ValueError): export_reference('kt',out,pci=invalid)
