#!/usr/bin/env python3
"""Compare a preserved analysis directory with its isolated corrected rebuild.

Only exact absolute checkout prefixes in documented path columns and the RDS
dependency_signature are accepted provenance differences. Every other changed
value fails. The original directory must still match the checkpoint manifest.
"""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline-root', type=Path, required=True)
parser.add_argument('--updated-root', type=Path, required=True)
parser.add_argument('--manifest', type=Path, required=True)
parser.add_argument('--destination', type=Path, required=True)
args = parser.parse_args()
baseline = args.baseline_root.resolve()
updated = args.updated_root.resolve()
manifest = list(csv.DictReader(args.manifest.open()))
allowed_paths = {
    'holocene_era_protected_hash_audit.csv': {'file'},
    'holocene_fire_tapas_manifest.csv': {'file'},
    'walsh_active_fire_hash_audit.csv': {'file'},
    'walsh_charanalysis_input_audit.csv': {'data_file', 'parameter_file'},
    'walsh_charanalysis_manifest.csv': {'file'},
    'walsh_charanalysis_settings.csv': {'input'},
}
results = []
for record in manifest:
    relative = record['path']
    path = Path(relative)
    if path.parent != Path('output'):
        continue
    a, b = baseline / path, updated / path
    if digest(a) != record['sha256']:
        raise AssertionError('Preserved baseline changed: ' + relative)
    before, after = digest(a), digest(b)
    status, fields, detail = 'byte-identical', '', 'Every value and byte unchanged'
    if before != after:
        if path.name == 'paleo_age_draws.rds':
            code = 'a=readRDS(commandArgs(TRUE)[1]); b=readRDS(commandArgs(TRUE)[2]); '
            code += 'stopifnot(identical(names(a),names(b)), '
            code += 'identical(a$draws,b$draws),identical(a$n_draws,b$n_draws), '
            code += 'identical(a$seed,b$seed)); a$dependency_signature=NULL; '
            code += 'b$dependency_signature=NULL;stopifnot(identical(a,b))'
            subprocess.run(['Rscript', '-e', code, str(a), str(b)], check=True)
            fields = 'dependency_signature'
            detail = 'All 96,300 sampled ages, draw count 100 and seed 42 identical; absolute-path dependency fingerprint changed'
        elif path.name in allowed_paths:
            ar = list(csv.DictReader(a.open()))
            br = list(csv.DictReader(b.open()))
            if len(ar) != len(br) or ar[0].keys() != br[0].keys():
                raise AssertionError('Changed CSV schema/count: ' + relative)
            changes = set()
            for x, y in zip(ar, br):
                for field in x:
                    if x[field] == y[field]:
                        continue
                    if field not in allowed_paths[path.name] or not x[field].startswith(str(baseline) + '/'):
                        raise AssertionError('Unexpected changed field: ' + relative + ' ' + field)
                    if y[field] != str(updated) + x[field][len(str(baseline)):]:
                        raise AssertionError('Path difference is not the checkout prefix: ' + relative)
                    changes.add(field)
            fields = ';'.join(sorted(changes))
            detail = 'Only exact checkout prefix in named path columns; all nonpath fields and recorded hashes unchanged'
        else:
            raise AssertionError('Unexpected scientific result change: ' + relative)
        status = 'provenance-only difference; scientific values identical'
    results.append(dict(path=relative, before_sha256=before, after_sha256=after,
                        status=status, changed_fields=fields, detail=detail))
protected = [r for r in manifest if r['path'].startswith(('data/', 'Cores/', 'output/mora_climate_parts/',
    'output/noca_climate_parts/', 'output/chelsa_paleo/', 'output/anomaly_parts/', 'output/_reference/'))]
allowed_document_changes = {'data/SOURCES_SURVEY_YEARS.md', 'data/SOURCES_SURVEY_YEARS.html'}
for record in protected:
    if record['path'] in allowed_document_changes:
        continue
    for root in [baseline, updated]:
        if digest(root / record['path']) != record['sha256']:
            raise AssertionError('Protected input/cache/posterior changed: ' + str(root / record['path']))
args.destination.mkdir(parents=True, exist_ok=True)
with (args.destination / 'RESULT_COMPARISON.csv').open('w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=list(results[0]))
    writer.writeheader()
    writer.writerows(results)
summary = dict(compared_results=len(results), byte_identical=sum(r['status']=='byte-identical' for r in results),
               provenance_only=sum(r['status']!='byte-identical' for r in results),
               changed_scientific_values=0,
               protected_input_cache_chronology_files=len(protected)-len(allowed_document_changes),
               protected_chronology_files=sum(r['path'].startswith('Cores/') for r in protected),
               documented_provenance_fields={k: sorted(v) for k, v in allowed_paths.items()},
               rds_provenance_field='dependency_signature')
(args.destination / 'comparison.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
