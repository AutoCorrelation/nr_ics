import pytest
from ssb.plotting import group_curves, plot_results


def metric(e,n,nmse):
    return {"errors": e, "trials": n, "bler": e/n, "ci_exact": [0.,1.], "zero_error_upper_one_sided": .95 if not e else None, "nmse": nmse}


def test_grouping_and_zero_error_plot(tmp_path):
    conditions = [{"condition":{"snr_db":s,"channel":{"family":family}},"methods":{"ls":metric(e,1,.2)}} for family in ("identity","tdl") for s,e in ((5,0),(-5,1))]
    report={"profiles":{"skt":{"conditions":conditions,"overrides":{"comb2":{"conditions":conditions}}}}}
    groups=group_curves(report)
    assert len(groups)==4
    assert [x for x,_ in next(iter(groups.values()))["ls"]] == [-5,5]
    files=plot_results(report,tmp_path)
    assert len(files)==4 and all(p.stat().st_size > 1000 for p in files)
    conditions[0]["methods"]["ls"]["bler"] = .4
    with pytest.raises(ValueError): group_curves(report)
