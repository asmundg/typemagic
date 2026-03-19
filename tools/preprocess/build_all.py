#!/usr/bin/env python3
"""
build_all.py — Orchestrator for TypeMagic preprocessing pipelines.

Runs each sub-pipeline (dictionary, markov, …) in sequence and prints a
summary of all generated artefacts.

Usage:
  python3 build_all.py --data-dir /tmp --output-dir ../../assets
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def run_step(label: str, cmd: list[str]) -> bool:
    """Run a subprocess, streaming its output. Returns True on success."""
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}\n")

    start = time.monotonic()
    result = subprocess.run(cmd, cwd=SCRIPT_DIR)
    elapsed = time.monotonic() - start

    ok = result.returncode == 0
    status = "✓" if ok else "✗"
    print(f"\n  {status} {label} — {'OK' if ok else 'FAILED'} ({elapsed:.1f}s)")
    return ok


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run all TypeMagic preprocessing pipelines."
    )
    parser.add_argument(
        "--data-dir", default="/tmp",
        help="Directory containing raw data files (default: /tmp)."
    )
    parser.add_argument(
        "--output-dir",
        default=os.path.join(SCRIPT_DIR, "..", "..", "assets"),
        help="Root output directory (default: ../../assets)."
    )
    args = parser.parse_args()

    data_dir   = os.path.abspath(args.data_dir)
    output_dir = os.path.abspath(args.output_dir)

    ordbank_path = os.path.join(data_dir, "nob_wordlist.txt")
    freq_path    = os.path.join(data_dir, "no_freq_50k.txt")
    dict_out     = os.path.join(output_dir, "dictionaries")

    print("=== TypeMagic — Full Preprocessing Pipeline ===")
    print(f"  Data dir:   {data_dir}")
    print(f"  Output dir: {output_dir}")

    results: list[tuple[str, bool]] = []

    # --- Step 1: Dictionary builder ----------------------------------------
    dict_cmd = [
        sys.executable, os.path.join(SCRIPT_DIR, "build_dictionary.py"),
        "--ordbank", ordbank_path,
        "--freq",    freq_path,
        "--output",  dict_out,
    ]
    ok = run_step("Dictionary builder", dict_cmd)
    results.append(("Dictionary builder", ok))

    # --- Step 2: Markov chain builder (bootstrap) ---------------------------
    markov_out = os.path.join(output_dir, "markov")
    markov_cmd = [
        sys.executable, os.path.join(SCRIPT_DIR, "build_markov_model.py"),
        "--bootstrap",
        "--output", markov_out,
        "--assets-dir", output_dir,
    ]
    ok = run_step("Markov chain builder (bootstrap)", markov_cmd)
    results.append(("Markov chain builder", ok))

    # --- Summary -----------------------------------------------------------
    print(f"\n{'='*60}")
    print("  Summary")
    print(f"{'='*60}")
    all_ok = True
    for label, ok in results:
        status = "✓" if ok else "✗"
        print(f"  {status} {label}")
        if not ok:
            all_ok = False

    if all_ok:
        print("\nAll pipelines completed successfully.")
    else:
        print("\nSome pipelines failed — check output above.")
        sys.exit(1)


if __name__ == "__main__":
    main()
