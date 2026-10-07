#!/usr/bin/env python3
"""Exercise the actual offline consumers and restore every deliberately altered file.
Run after a normal cached rebuild, outside a concurrently running workflow.
"""
from pathlib import Path
import hashlib, subprocess
ROOT=Path(__file__).resolve().parents[1]
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def rejected(stage, expected, mutate, restore):
    manifest=ROOT/'output/bacon_run_manifest.csv'; before=digest(manifest)
    report=ROOT/'docs/ANALYSIS_REVIEW.md'; report_before=digest(report)
    mutate()
    try:
        code=f'options(paleoaces.offline=TRUE); source("{stage}", local=new.env(parent=globalenv()))'
        result=subprocess.run(['Rscript','-e',code],cwd=ROOT,text=True,capture_output=True)
        if result.returncode==0 or expected not in result.stdout+result.stderr:
            raise AssertionError('Expected offline cache rejection: '+stage+'\n'+result.stdout+result.stderr)
        if digest(manifest)!=before or digest(report)!=report_before: raise AssertionError('Failure changed protected/published products.')
        print('PASS '+stage+': '+expected,flush=True)
    finally: restore()
# Missing native chunks must fail before any download/removal.
for stage,directory,label in [
 ('R/stages/000_MORA_climate.R','mora_climate_parts','Offline MORA climate'),
 ('R/stages/000_NOCA_climate.R','noca_climate_parts','Offline NOCA climate'),
 ('R/stages/000_PALEO_d_climate_download.R','chelsa_paleo','Offline TraCE21k climate'),
 ('R/diagnostics/test_survey_year_anomaly.R','anomaly_parts','Offline survey-window climate')]:
    files=sorted((ROOT/'output'/directory).glob('*.csv'))
    if directory=='chelsa_paleo': files=[p for p in files if not p.name.startswith('v21_')]
    p=files[0]; original=p.read_bytes()
    # Modern consumers can restore absent chunks from the validated diagnostic
    # cache. Absence from BOTH caches must still fail before any download.
    alternate=None
    if directory in ['mora_climate_parts','noca_climate_parts']:
        parts=p.stem.split('_'); alternate=ROOT/'output/anomaly_parts'/('_'.join(parts[-2:])+'.csv')
    alternate_bytes=alternate.read_bytes() if alternate and alternate.exists() else None
    def remove():
        p.unlink()
        if alternate_bytes is not None: alternate.unlink()
    def replace():
        p.write_bytes(original)
        if alternate_bytes is not None: alternate.write_bytes(alternate_bytes)
    rejected(stage,label,remove,replace)
# Invalid values must not be removed to make room for a download.
p=sorted((ROOT/'output/mora_climate_parts').glob('*.csv'))[0]; original=p.read_bytes()
import csv,io
records=list(csv.DictReader(io.StringIO(original.decode()))); records[0]['value']='NA'
s=io.StringIO(); w=csv.DictWriter(s,fieldnames=list(records[0])); w.writeheader(); w.writerows(records)
def invalid(): p.write_text(s.getvalue())
def restore():
    unchanged = p.exists() and p.read_bytes() == s.getvalue().encode()
    p.write_bytes(original)
    if not unchanged: raise AssertionError('Invalid chunk was modified before offline failure.')
rejected('R/stages/000_MORA_climate.R','Offline MORA climate',invalid,restore)
# Changed authoritative coordinates make existing chunks invalid.
p=ROOT/'output/MORA_plot_info.csv'; original=p.read_bytes(); records=list(csv.DictReader(io.StringIO(original.decode())))
lon=next(k for k in records[0] if k.lower() in ['lon','longitude']); records[0][lon]=str(float(records[0][lon])+.01)
s=io.StringIO(); w=csv.DictWriter(s,fieldnames=list(records[0])); w.writeheader(); w.writerows(records)
rejected('R/stages/000_MORA_climate.R','Offline MORA climate',lambda:p.write_text(s.getvalue()),lambda:p.write_bytes(original))
print('Offline missing/invalid-cache and changed-coordinate checks passed; files restored.',flush=True)
