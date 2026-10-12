#!/usr/bin/env python3
"""Compare tracking products across fresh sessions and isolated R environments.
Run after a complete workflow, in the checkout holding the valid chronology cache.
The canonical stage reads that cache without regeneration; output hashes must match.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def state():
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / 'output').iterdir()
            if p.is_file() and p.suffix in ['.csv', '.gz', '.rds']}


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--isolated', action='store_true', required=True)
parser.parse_args()
primary = 'R/stages/07_tracking_metrics.R'
assembly = 'R/stages/11_tracking_model_data.R'
baseline = state()
checks = []
for label, stages in [('fresh tracking and assembly', [primary, assembly]),
                      ('repeated tracking and assembly', [primary, assembly, primary, assembly])]:
    code = 'options(paleoaces.render_figures=FALSE); '
    for stage in stages:
        code += f'sys.source("{stage}", envir=new.env(parent=globalenv())); '
    code += 'stopifnot(!exists("cca_model",globalenv(),inherits=FALSE), '
    code += '!exists("bin_width_years",globalenv(),inherits=FALSE))'
    result = subprocess.run(['Rscript', '-e', code], cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        raise AssertionError(label + '\n' + result.stdout + result.stderr)
    actual = state()
    changed = sorted(k for k in baseline if baseline[k] != actual.get(k))
    if changed:
        raise AssertionError(label + ': output hashes changed: ' + str(changed))
    checks.append({'check': label, 'status': 'passed', 'result_files_compared': len(baseline),
                   'changed_files': changed, 'no_global_model_or_suffix': True})
    print('PASS ' + label + ': unchanged scientific products; no global model/width', flush=True)
out = ROOT / 'output/review_audit/stage_isolation.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(checks, indent=2) + '\n')
