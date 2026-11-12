import pytest
from ssb.benchmark import split_manifest, audit_splits, derive_seed


def test_splits_and_seed_domains():
    m=split_manifest(4,"skt",{"train":3,"validation":2,"test":4})
    assert audit_splits(m)["overlap"] == 0
    assert derive_seed(4,"skt","model",1) not in {v[k] for v in m.values() for k in ("payload_seed","channel_seed","noise_seed")}
    m["test"]["trajectory_ids"][0]=m["train"]["trajectory_ids"][0]
    with pytest.raises(ValueError): audit_splits(m)
import torch
from ssb.estimators import LMMSE
from ssb.benchmark import test_pilot_covariance as reselect
from test_estimators import mask_for


def test_override_changes_selection_without_refitting():
    torch.manual_seed(3)
    h = torch.randn(3,240,4,dtype=torch.complex64)
    original = LMMSE.fit(h,mask_for(0),partition="train")
    changed = reselect(original, mask_for(2))
    assert changed.covariance.data_ptr() == original.covariance.data_ptr()
    assert changed.mean.data_ptr() == original.mean.data_ptr()
    assert changed.sample_count == original.sample_count
    assert torch.equal(changed.pilot_mask, mask_for(2))
    assert not torch.equal(changed.pilot_mask, original.pilot_mask)


def test_decoder_batches_are_bounded_and_paired(monkeypatch, tmp_path):
    from types import SimpleNamespace
    import numpy as np
    import ssb.benchmark as benchmark
    import ssb.matlab_bridge as bridge
    dm = mask_for(2); pb = ~dm
    x = torch.zeros((3,240,4),dtype=torch.complex64); x[:,dm] = 1
    reference = SimpleNamespace(mask_dmrs=dm.numpy(),mask_pbch=pb.numpy(),scrblk=np.zeros((3,32),np.uint8),trblk=np.zeros((3,24),np.uint8),half_frame=np.zeros(3,np.uint8),sfn=np.zeros(3,np.uint16))
    channels=torch.ones((3,240,4),dtype=torch.complex64)
    cov=LMMSE.fit(channels,mask_for(0),partition="train")
    calls=[]
    def simulate(ref,profile,split,conditions,device,batch_size):
        return {"y":x,"target":channels,"n0":torch.ones(3),"reference":x,"channel_metadata":[]}
    def decode(y,h,n0,profile,**kwargs):
        calls.append((len(y),profile["pci"]))
        return {"crc":np.zeros(len(y),int),"error_code":np.zeros(len(y),int),"scrblk":np.zeros((len(y),32),int),"trblk":np.zeros((len(y),24),int),"half_frame":np.zeros(len(y),int),"sfn_lsb":np.zeros((len(y),4),int)}
    monkeypatch.setattr(benchmark,"_simulate",simulate); monkeypatch.setattr(bridge,"decode_batch",decode)
    conditions=[{"snr_db":s,"channel":{"family":"identity"}} for s in [-5,5]]
    split={"count":3,"channel_seed":4,"noise_seed":5,"payload_seed":6}
    results,info=benchmark._evaluate({"pci":326},reference,split,conditions,{"decoder_batch_size":2},cov,{},tmp_path,4)
    assert calls and all(n <= 2 and pci == 326 for n,pci in calls)
    assert info["calls"] == len(calls)
    assert all(r["methods"][m]["trials"]==3 and r["methods"][m]["errors"]==0 for r in results for m in ("perfect","ls","lmmse"))


@pytest.mark.parametrize("training_seeds", [[1, 2, 3], []])
def test_run_override_is_test_only(monkeypatch, tmp_path, training_seeds):
    from types import SimpleNamespace
    import ssb.benchmark as b
    import ssb.profiles as profiles
    base = {"operator_id":"skt","pci":508,"ssb_index":1,"ibar_ssb":1,"lmax":8,"source_sha256":"source","scs_hz":30000,"ssref_hz":3.5e9}
    monkeypatch.setattr(profiles,"load_profile",lambda name: dict(base))
    monkeypatch.setattr(profiles,"synthetic_profile",lambda p,pci: dict(p,pci=pci))
    monkeypatch.setattr(b,"source_fingerprints",lambda: {"source":"hash"})
    monkeypatch.setattr(b,"environment_info",lambda device: {"device":device})
    def ref(name,path,spec,profile,config,**kwargs):
        path.write_bytes((str(profile["pci"])+str(spec["payload_seed"])).encode())
        return SimpleNamespace(tx=torch.ones(spec["count"],240,4,dtype=torch.complex64).numpy(), mask_dmrs=mask_for(profile["pci"] % 4).numpy(), mask_pbch=(~mask_for(profile["pci"] % 4)).numpy(),manifest=dict(profile))
    monkeypatch.setattr(b,"_reference",ref)
    simulated=[]
    def sim(ref,profile,split,conditions,device,chunk):
        simulated.append((profile["pci"],split["count"]))
        target=torch.randn(split["count"],240,4,dtype=torch.complex64)
        return {"target":target,"channel_metadata":[]}
    monkeypatch.setattr(b,"_simulate",sim)
    train_calls=[]
    def train(*args,checkpoint,**kwargs):
        train_calls.append(kwargs["config"]["seed"]); checkpoint.write_bytes(b"checkpoint")
        return object(),{}
    monkeypatch.setattr(b,"train_model",train)
    fitted=[]; original=LMMSE.fit.__func__
    def fit(cls,*args,**kwargs):
        fitted.append(kwargs["partition"])
        return original(cls,*args,**kwargs)
    monkeypatch.setattr(LMMSE,"fit",classmethod(fit))
    evaluated=[]
    def evaluate(profile,ref,split,conditions,config,cov,models,directory,master):
        evaluated.append((profile["pci"],cov,tuple(models)))
        return [],{}
    monkeypatch.setattr(b,"_evaluate",evaluate)
    config={"profiles":["skt"],"train_count":3,"validation_count":2,"test_count":1,"training_conditions":[{}],"test_conditions":[{}],"training_seeds":training_seeds,"output_dir":str(tmp_path),"test_profile_overrides":{"skt":[{"label":"comb2","pci":326},{"label":"comb3","pci":327}]}}
    report,_=b.run(config)
    assert simulated == [(508,3),(508,2)]
    assert fitted == ["train"] and len(train_calls) == len(training_seeds)
    assert [p for p,_,_ in evaluated] == [508,326,327]
    assert all(cov is evaluated[0][1] and names == evaluated[0][2] for _,cov,names in evaluated)
    overrides=report["profiles"]["skt"]["overrides"]
    assert all(o["covariance_sha256"] == report["profiles"]["skt"]["covariance_sha256"] for o in overrides.values())
    monkeypatch.setattr(b,"source_fingerprints",lambda: {"source":"changed"})
    with pytest.raises(ValueError, match="covariance provenance mismatch"):
        b.run(config)
