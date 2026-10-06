#!/usr/bin/env python3
"""Destructive, restored failure probes. Run only in an isolated audit copy.

The --isolated flag acknowledges the copied inputs requirement; every altered
file is restored in finally, and published evidence is compared byte for byte.
"""
from pathlib import Path
import argparse
import csv
import hashlib
import io
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def protected():
    paths = list((ROOT / 'Cores').rglob('*.csv'))
    paths += list((ROOT / 'Cores').rglob('*.out'))
    paths += list((ROOT / 'Cores').rglob('*.txt'))
    paths += list((ROOT / 'Cores').rglob('*.bacon'))
    paths += list((ROOT / 'docs/assets/analysis').rglob('*'))
    paths += [ROOT / 'docs/ANALYSIS_REVIEW.md', ROOT / 'docs/ANALYSIS_REVIEW.html',
              ROOT / 'output/bacon_run_manifest.csv', ROOT / 'output/paleo_age_draws.rds']
    return {str(p.relative_to(ROOT)): digest(p) for p in paths if p.is_file()}


def rejected(name, path, replacement, command, expected):
    before = protected()
    original = path.read_bytes()
    try:
        path.write_bytes(replacement)
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
        if result.returncode == 0 or expected not in result.stdout + result.stderr:
            raise AssertionError(name + ': unexpected result\n' + result.stdout + result.stderr)
        if path.read_bytes() != replacement:
            raise AssertionError(name + ': invalid input was changed during rejection')
    finally:
        path.write_bytes(original)
    if protected() != before:
        raise AssertionError(name + ': rejection changed protected/published products')
    print('PASS ' + name, flush=True)
    return {'check': name, 'status': 'passed', 'expected_rejection': expected,
            'protected_products_unchanged': True}


def csv_mutation(path, edit):
    data = list(csv.DictReader(io.StringIO(path.read_text())))
    edit(data)
    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=list(data[0]))
    writer.writeheader()
    writer.writerows(data)
    return out.getvalue().encode()


def posterior_read_failure():
    before = protected()
    serialized = {p: p.read_bytes() for p in (ROOT / 'Cores').rglob('*.bacon')}
    code = r'''
suppressPackageStartupMessages(library(here))
e = new.env(parent = globalenv())
sys.source(here("R/helpers/paleo_runs.R"), envir = e)
files = list.files(here("Cores"), pattern = "[.](csv|out|txt|bacon)$",
                   recursive = TRUE, full.names = TRUE)
files = c(files, here("output/paleo_age_draws.rds"))
before = tools::md5sum(files)
serialized = list.files(here("Cores"), pattern = "[.]bacon$",
                        recursive = TRUE, full.names = TRUE)
e$bacon_draws = function(...) {
  writeLines("injected serialized configuration mutation", serialized[1])
  stop("injected posterior-read failure")
}
error = tryCatch(e$paleo_age_draws(cache = FALSE), error = identity)
stopifnot(inherits(error, "error"),
          grepl("injected posterior-read failure", conditionMessage(error), fixed = TRUE),
          identical(before, tools::md5sum(files)))
'''
    try:
        result = subprocess.run(['Rscript', '-e', code], cwd=ROOT,
                                text=True, capture_output=True)
        if result.returncode or protected() != before:
            raise AssertionError('posterior-read failure restoration\n' +
                                 result.stdout + result.stderr)
    finally:
        for path, original in serialized.items():
            path.write_bytes(original)
    print('PASS posterior-read failure restores serialized configurations and age cache', flush=True)
    return {'check': 'posterior-read failure restores serialized configurations and age cache',
            'status': 'passed', 'protected_products_unchanged': True,
            'mcmc_executed': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--isolated', action='store_true', required=True)
    parser.parse_args()
    results = [posterior_read_failure()]
    stage = 'R/stages/000_MORA_climate.R'
    execute = ['Rscript', '-e', 'options(paleoaces.offline=TRUE); '
               f'sys.source("{stage}", envir=new.env(parent=globalenv()))']
    cache = sorted((ROOT / 'output/mora_climate_parts').glob('*.csv'))[0]
    for field, value in [('value', 'Inf'), ('source', 'NA'), ('lon', '-120')]:
        replacement = csv_mutation(cache, lambda data: data[0].update({field: value}))
        results.append(rejected('actual modern consumer rejects ' + field + '=' + value,
                                cache, replacement, execute, 'Offline MORA climate'))
    paleo = next(p for p in sorted((ROOT / 'output/chelsa_paleo').glob('*.csv'))
                 if not p.name.startswith('v21_'))
    execute = ['Rscript', '-e', 'options(paleoaces.offline=TRUE); sys.source('
               '"R/stages/000_PALEO_d_climate_download.R", envir=new.env(parent=globalenv()))']
    results.append(rejected('actual native paleo consumer rejects Inf', paleo,
        csv_mutation(paleo, lambda data: data[0].update(value='Inf')),
        execute, 'Offline TraCE21k climate'))

    fresh = ['python3', 'tools/build_analysis_review.py', '--fresh']
    ledger = ROOT / 'output/report/run.json'
    run = json.loads(ledger.read_text())
    removed = run['records'].pop(0)['path']
    results.append(rejected('producer ledger cannot borrow an existing unrecorded output',
        ledger, json.dumps(run).encode(), fresh,
        'Fresh report lacks a regenerated, unchanged producer output: ' + removed))
    results.append(rejected('changed captured cache rejects report publication', cache,
        csv_mutation(cache, lambda data: data[0].update(value=str(float(data[0]['value']) + 1))),
        fresh, 'Report inputs or code changed during the run'))
    preview = sorted((ROOT / 'docs/assets/analysis').glob('*-p*.png'))[0]
    results.append(rejected('corrupt preview is rejected', preview, b'invalid PNG',
        ['python3', 'tools/build_analysis_review.py', '--validate'],
        'Missing/stale report artifact'))
    output = ROOT / 'output/review_audit/failure_checks.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(results, indent=2) + '\n')
    print('All failure probes passed; altered files restored.', flush=True)


if __name__ == '__main__':
    main()
