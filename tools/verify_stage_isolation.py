#!/usr/bin/env python3
"""Compare tracking products across fresh sessions and both sequential orders.
Run only in the copied audit checkout, after a complete workflow.
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
primary = 'R/stages/09_tracking_metrics.R'
sensitivity = 'R/stages/09_tracking_metrics_500yr_sensitivity.R'
baseline = state()
checks = []
for label, stages in [('fresh primary', [primary]), ('fresh existing sensitivity', [sensitivity]),
                       ('primary then sensitivity', [primary, sensitivity]),
                       ('sensitivity then primary', [sensitivity, primary])]:
    code = 'options(paleoaces.render_figures=FALSE); '
    for stage in stages:
        code += f'sys.source("{stage}", envir=new.env(parent=globalenv())); '
    code += 'stopifnot(!exists("cca_model",globalenv(),inherits=FALSE), '
    code += '!exists("TRACKING_OUTPUT_SUFFIX",globalenv(),inherits=FALSE))'
    result = subprocess.run(['Rscript', '-e', code], cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        raise AssertionError(label + '\n' + result.stdout + result.stderr)
    actual = state()
    changed = sorted(k for k in baseline if baseline[k] != actual.get(k))
    if changed:
        raise AssertionError(label + ': output hashes changed: ' + str(changed))
    checks.append({'check': label, 'status': 'passed', 'result_files_compared': len(baseline),
                   'changed_files': changed, 'no_global_model_or_suffix': True})
    print('PASS ' + label + ': unchanged scientific products; no global model/suffix', flush=True)
out = ROOT / 'output/review_audit/stage_isolation.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(checks, indent=2) + '\n')
