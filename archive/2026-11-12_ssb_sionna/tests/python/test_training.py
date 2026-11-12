import pytest
import torch
from ssb.training import train_model, load_checkpoint
from test_estimators import mask_for


def test_cuda_training_checkpoint(tmp_path):
    if not torch.cuda.is_available(): pytest.skip("CUDA unavailable")
    dm = mask_for(); pb = ~dm
    torch.manual_seed(3)
    x = torch.zeros((8,240,4),dtype=torch.complex64); x[:,dm]=1
    target = torch.ones_like(x)
    noise = torch.complex(torch.randn_like(x.real),torch.randn_like(x.real))*.15
    y = x + noise
    data = {"y":y,"reference":x,"n0":torch.full((8,),.045),"target":target}
    path = tmp_path / "model.pt"
    train = {k: v[:6] for k, v in data.items()}
    validation = {k: v[6:] for k, v in data.items()}
    model, artifact = train_model(train,validation,dm,pb,config={"seed":2,"width":8,"blocks":1,"epochs":8,"batch_size":4,"lr":.001,"patience":8},device="cuda",checkpoint=path)
    assert artifact["history"][-1]["train_mse"] < artifact["history"][0]["train_mse"]
    loaded, loaded_artifact = load_checkpoint(path, "cuda")
    assert loaded_artifact["config_sha256"] == artifact["config_sha256"]
    assert all(torch.equal(a,b) for a,b in zip(model.parameters(),loaded.parameters()))
