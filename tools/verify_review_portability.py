#!/usr/bin/env python3
"""Validate the Git-eligible review in a clean temporary export without local data.
Does not stage, commit, or modify the real repository's Git metadata.
"""
from pathlib import Path
import subprocess, tempfile, shutil, json
ROOT=Path(__file__).resolve().parents[1]
listed=subprocess.check_output(['git','ls-files','-c','-o','--exclude-standard','-z'],cwd=ROOT).decode().split('\0')
paths=sorted(set(p for p in listed if p and (ROOT/p).is_file()))
with tempfile.TemporaryDirectory(prefix='paleoaces-git-export-') as tmp:
    dst=Path(tmp)
    for rel in paths:
        out=dst/rel; out.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/rel,out)
    assert not (dst/'output').exists(), 'Local results leaked into the portable export.'
    assert not (dst/'data/NOCA/AGEEDATA_NEW.xlsx').exists(), 'Raw workbook leaked into the export.'
    assert not list((dst/'Cores').glob('**/*.out')), 'Stored posteriors leaked into the export.'
    subprocess.run(['python3',dst/'tools/build_analysis_review.py','--validate'],cwd=dst,check=True)
    # Readability remains independent of where the repository is checked out.
    html=(dst/'docs/ANALYSIS_REVIEW.html').read_text()
    assert '/Users/bbektas/Desktop/PaleoACES/docs/.analysis-review-' not in html
    print(f'PASS: {len(paths)} Git-eligible files exported; report links, previews, tables, and self-contained HTML work without raw data/caches/results.')
