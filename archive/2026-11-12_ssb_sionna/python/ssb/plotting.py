"""Render fixed-N PBCH benchmark curves as standalone figures."""
import json
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def group_curves(report):
    groups = {}
    for name, base in report["profiles"].items():
        entries = [(name, base)] + [(f"{name}:{label}", value) for label, value in base.get("overrides", {}).items()]
        for label, entry in entries:
            for result in entry["conditions"]:
                condition = result["condition"]
                key = (label, json.dumps(condition["channel"], sort_keys=True))
                for method, metric in result["methods"].items():
                    n, e = metric["trials"], metric["errors"]
                    if n <= 0 or not 0 <= e <= n or abs(metric["bler"] - e / n) > 1e-12:
                        raise ValueError("inconsistent error and trial counts")
                    groups.setdefault(key, {}).setdefault(method, []).append((float(condition["snr_db"]), metric))
    for methods in groups.values():
        for points in methods.values():
            points.sort(key=lambda item: item[0])
            if len({p[0] for p in points}) != len(points):
                raise ValueError("duplicate SNR for profile, channel and method")
    return groups


def plot_results(results, output_dir):
    if not isinstance(results, dict):
        results = json.loads(Path(results).read_text(encoding="utf-8-sig"))
    output = Path(output_dir); output.mkdir(parents=True, exist_ok=True)
    paths = []
    for (label, channel_json), methods in group_curves(results).items():
        channel = json.loads(channel_json)
        if channel.get("family") == "tdl":
            channel_label = f"TDL-{channel.get('profile', '?')} | delay={channel.get('delay_spread_s', 0)*1e9:g} ns | speed={channel.get('speed_mps', 0):g} m/s"
        elif channel.get("family") == "cdl":
            channel_label = f"CDL-{channel.get('profile', '?')} | delay={channel.get('delay_spread_s', 0)*1e9:g} ns | speed={channel.get('speed_mps', 0):g} m/s"
        else:
            channel_label = channel.get("family", "channel").upper()
        fig, axes = plt.subplots(1, 2, figsize=(12, 5), constrained_layout=True)
        for method, points in methods.items():
            snr = [p[0] for p in points]
            nonzero = [(x, m) for x, m in points if m["errors"] > 0]
            zeros = [(x, m) for x, m in points if m["errors"] == 0]
            counts = {m["trials"] for _, m in points}
            count_label = str(next(iter(counts))) if len(counts) == 1 else "variable"
            color = axes[0].plot([], [], marker="o", label=f"{method} (N={count_label})")[0].get_color()
            axes[0].plot(snr, [m["bler"] if m["errors"] else float("nan") for _, m in points], color=color, alpha=.8)
            if nonzero:
                x = [p[0] for p in nonzero]; y = [p[1]["bler"] for p in nonzero]
                lo = [p[1]["ci_exact"][0] for p in nonzero]; hi = [p[1]["ci_exact"][1] for p in nonzero]
                axes[0].errorbar(x, y, yerr=[[a-b for a,b in zip(y,lo)],[a-b for a,b in zip(hi,y)]], marker="o", color=color, capsize=3)
            if zeros:
                axes[0].scatter([p[0] for p in zeros], [p[1]["zero_error_upper_one_sided"] for p in zeros], color=color, marker="v", facecolors="none")
            axes[1].plot(snr, [max(p[1]["nmse"], 1e-12) for p in points], marker="o", label=method)
        axes[0].set_yscale("log"); axes[0].set_ylabel("BLER (95% exact CI; open triangle: 95% zero-error upper limit)")
        axes[1].set_yscale("log"); axes[1].set_ylabel("PBCH-mask aggregate channel NMSE (floor 1e-12)")
        for ax in axes:
            ax.set_xlabel("Transmit PBCH RE Es/N0 (dB)"); ax.grid(True, which="both", alpha=.3); ax.legend(fontsize="small")
        fig.suptitle(f"{label} | {channel_label}\nKnown simulation N0; conditional on known synchronization; Perfect CSI uses true H", fontsize=10)
        import hashlib
        digest = hashlib.sha256(channel_json.encode()).hexdigest()[:8]
        stem = label.replace(":", "_") + "_" + channel.get("family", "channel") + "_" + digest
        path = output / f"{stem}.png"
        fig.savefig(path, dpi=150); plt.close(fig); paths.append(path)
    if not paths: raise ValueError("no benchmark curves to plot")
    return paths
