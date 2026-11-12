"""Fixed-budget BLER and channel diagnostics."""
import numpy as np
from scipy.stats import beta


def block_failures(decoded, scrblk, trblk=None, half_frame=None, sfn=None):
    crc = np.asarray(decoded["crc"]).reshape(-1) != 0
    mismatch = np.any(np.asarray(decoded["scrblk"]) != np.asarray(scrblk), axis=1)
    error = np.asarray(decoded["error_code"]).reshape(-1) != 0
    if crc.shape != mismatch.shape or error.shape != mismatch.shape:
        raise ValueError("decoder block counts disagree")
    failure = crc | mismatch | error
    result = {"failure": failure, "crc_fail": int(crc.sum()), "payload_mismatch": int(mismatch.sum()), "crc_pass_payload_mismatch": int((~crc & mismatch).sum()), "crc_fail_payload_match": int((crc & ~mismatch).sum()), "decoder_error": int(error.sum())}
    if "msb_index_offset" in decoded:
        values, counts = np.unique(np.asarray(decoded["msb_index_offset"]), return_counts=True)
        result["msb_index_offset_counts"] = {str(int(v)): int(c) for v, c in zip(values, counts)}
    values, counts = np.unique(np.asarray(decoded["error_code"]), return_counts=True)
    result["error_code_counts"] = {str(int(v)): int(c) for v, c in zip(values, counts)}
    if trblk is not None:
        result["trblk24_mismatch"] = int(np.any(np.asarray(decoded["trblk"]) != np.asarray(trblk), axis=1).sum())
    if half_frame is not None:
        result["half_frame_mismatch"] = int((np.asarray(decoded["half_frame"]).reshape(-1) != np.asarray(half_frame).reshape(-1)).sum())
    if sfn is not None:
        bits = np.asarray(decoded["sfn_lsb"])
        expected = ((np.asarray(sfn).reshape(-1, 1) >> np.arange(3, -1, -1)) & 1)
        result["sfn_lsb_mismatch"] = int(np.any(bits != expected, axis=1).sum())
    return result


def binomial_stats(errors, trials, alpha=0.05):
    if trials <= 0 or errors < 0 or errors > trials or not 0 < alpha < 1:
        raise ValueError("invalid fixed-N binomial arguments")
    lo = 0.0 if errors == 0 else float(beta.ppf(alpha / 2, errors, trials - errors + 1))
    hi = 1.0 if errors == trials else float(beta.ppf(1 - alpha / 2, errors + 1, trials - errors))
    return {"errors": int(errors), "trials": int(trials), "bler": errors / trials, "ci_exact": [lo, hi], "zero_error_upper_one_sided": float(-np.expm1(np.log(alpha) / trials)) if errors == 0 else None}


def channel_metrics(h_hat, h_true, y, tx, n0, mask):
    mask = np.asarray(mask, dtype=bool)
    h, truth, rx, x = (np.asarray(a)[:, mask] for a in (h_hat, h_true, y, tx))
    denom = np.maximum(np.sum(np.abs(truth)**2), 1e-12)
    per_denom = np.maximum(np.sum(np.abs(truth)**2, axis=1), 1e-12)
    nmse = np.sum(np.abs(h - truth)**2) / denom
    per = np.sum(np.abs(h - truth)**2, axis=1) / per_denom
    n = np.asarray(n0).reshape(-1, 1)
    eq = np.conj(h) * rx / np.maximum(np.abs(h)**2 + n, 1e-12)
    evm = np.sqrt(np.sum(np.abs(eq - x)**2) / np.maximum(np.sum(np.abs(x)**2), 1e-12))
    return {"nmse": float(nmse), "nmse_db": float(10 * np.log10(max(nmse, 1e-12))), "nmse_per_block": per.tolist(), "evm_rms": float(evm), "evm_equalizer": "SISO MMSE without gain correction", "denominator_floor": 1e-12}


def paired_difference(a, b, seed=0, resamples=2000):
    a, b = np.asarray(a, dtype=float), np.asarray(b, dtype=float)
    if a.shape != b.shape or a.ndim != 1 or not a.size:
        raise ValueError("paired arrays must be nonempty and equally sized")
    d = a - b
    rng = np.random.default_rng(seed)
    means = np.empty(resamples)
    for i in range(resamples):
        means[i] = rng.choice(d, size=d.size, replace=True).mean()
    return {"difference": float(d.mean()), "bootstrap_95_ci": np.quantile(means, [0.025, 0.975]).tolist(), "resamples": resamples}
