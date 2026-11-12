import numpy as np
from ssb.metrics import binomial_stats, block_failures, channel_metrics, paired_difference


def test_bler_counts_crc_payload_and_errors():
    decoded={"crc":[0,1,0,0],"scrblk":np.zeros((4,32),int),"error_code":[0,0,1,0],"trblk":np.zeros((4,24),int),"half_frame":[0,0,0,0],"sfn_lsb":np.zeros((4,4),int)}
    decoded["scrblk"][3,31]=1
    result=block_failures(decoded,np.zeros((4,32),int),np.zeros((4,24),int),np.zeros(4),np.zeros(4,dtype=int))
    assert result["failure"].tolist() == [False,True,True,True]
    assert result["crc_pass_payload_mismatch"] == 1
    stats=binomial_stats(0,100)
    assert np.isclose(stats["zero_error_upper_one_sided"],1-.05**.01)
    assert stats["ci_exact"][0] == 0
    assert paired_difference([1,0],[0,1])["difference"] == 0


def test_metrics_perfect_no_noise():
    shape=(2,240,4); h=np.ones(shape,dtype=np.complex64); m=np.ones((240,4),bool)
    result=channel_metrics(h,h,h,h,np.zeros(2),m)
    assert result["nmse"] == 0 and result["evm_rms"] == 0
