"""Command-line entry point for reproducible SSB benchmark runs."""
import argparse
import json
from pathlib import Path


def main(argv=None):
    parser = argparse.ArgumentParser(prog="ssb-benchmark", description="Run paired real-decoder PBCH BLER experiments")
    commands = parser.add_subparsers(dest="command", required=True)
    run_parser = commands.add_parser("run", help="generate, train, and evaluate a JSON experiment")
    run_parser.add_argument("--config", required=True, type=Path)
    plot_parser = commands.add_parser("plot", help="render BLER and NMSE curves from results JSON")
    plot_parser.add_argument("--results", required=True, type=Path)
    plot_parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args(argv)
    if args.command == "run":
        from .benchmark import run
        config = json.loads(args.config.read_text(encoding="utf-8-sig"))
        _, result = run(config)
        print(f"Results: {result}")
    elif args.command == "plot":
        from .plotting import plot_results
        for path in plot_results(args.results, args.output_dir):
            print(path)

if __name__ == "__main__":
    main()

