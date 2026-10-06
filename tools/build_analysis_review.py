#!/usr/bin/env python3
"""Build a staged, validated review from authoritative tables and selected PDFs.
No raw input or scientific result is modified. Python standard library only.
"""
from pathlib import Path
import argparse, csv, hashlib, json, os, re, shutil, subprocess, tempfile
from datetime import datetime, timezone
ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / 'docs/report/artifacts.json'
TEMPLATE = ROOT / 'docs/report/analysis_review_template.md'
ASSETS = Path('docs/assets/analysis')

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()

def rows(path):
    with Path(path).open(newline='', encoding='utf-8-sig') as f: return list(csv.DictReader(f))

def write_csv(path, data, fields=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    if fields is None: fields = list(data[0]) if data else []
    with path.open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=fields); w.writeheader(); w.writerows(data)

def relative(path): return path.relative_to(ROOT).as_posix()

def input_files():
    files = []
    for directory in ['R', 'tools', 'data', 'Cores']:
        for path in (ROOT / directory).rglob('*'):
            if not path.is_file() or path.name == '.DS_Store': continue
            if directory == 'R' and 'archive' in path.parts: continue
            if directory in ['R', 'tools'] and path.suffix not in ['.R', '.py']: continue
            if directory == 'Cores' and path.suffix not in ['.csv', '.out', '.txt']: continue
            files.append(path)
    for directory in ['mora_climate_parts', 'noca_climate_parts', 'chelsa_paleo', 'anomaly_parts', '_reference']:
        files.extend((ROOT / 'output' / directory).glob('*.csv'))
    files += [REGISTRY, TEMPLATE, ROOT / 'R/helpers/bacon_settings.R', ROOT / 'output/bacon_run_manifest.csv']
    files += [ROOT / 'docs/reorganization/chronology_relocation.json']
    files += list((ROOT / 'docs/reorganization/chronology_sources_before_move').glob('*.txt'))
    files += [ROOT/p for p in ['docs/SCIENTIFIC_DECISIONS.md', 'docs/FIGURE_CAPTIONS.md', 'docs/methods/000_NOCA_cleaning_guide.md', 'docs/methods/README_occurrence_consolidation.md']]
    return sorted(set(files))

def manifest(files): return [dict(path=relative(p), bytes=p.stat().st_size, sha256=sha(p)) for p in files]

def capture():
    write_csv(ROOT / 'output/report/input_start.csv', manifest(input_files()))
    print('Captured report code, source-data, chronology, and native-cache fingerprints.', flush=True)

def command(args): subprocess.run([str(x) for x in args], cwd=ROOT, check=True)

def num(value):
    if value in ['', 'NA', 'NaN', None]: return '—'
    try:
        f = float(value)
        if f.is_integer(): return str(int(f))
        return f'{f:.4g}'
    except (ValueError, TypeError): return str(value)

def mdtable(data, columns, maximum=None):
    if maximum is not None: data = data[:maximum]
    def escape(x): return num(x).replace('|', '\\|').replace('\n', ' ')
    return '\n| ' + ' | '.join(label for _, label in columns) + ' |\n| ' + ' | '.join('---' for _ in columns) + ' |\n' + ''.join('| ' + ' | '.join(escape(r.get(key, '')) for key, _ in columns) + ' |\n' for r in data) + '\n'

COLUMNS = {
 'cleaning_summary': [('source','Prepared input'),('rows','Rows'),('plot_or_sample_ids','Plot/sample IDs'),('taxa','Taxa')],
 'cca_summary': [('field','Fitted model quantity'),('value','Value')],
 'cca_axes': [('axis','Axis'),('eigenvalue','Eigenvalue'),('percent_total_inertia','% total inertia'),('percent_constrained_inertia','% constrained inertia')],
 'cca_counts': [('site','Site'),('period','Period'),('input_samples','Prepared climate samples'),('calibration_samples','Calibrated'),('positioned_samples','Positioned projection')],
 'cca_taxa': [('species','Taxon'),('MORA_past','MORA legacy'),('MORA_present','MORA resurvey'),('MORA_paleo','MORA paleo'),('NOCA_past','NOCA legacy'),('NOCA_present','NOCA resurvey'),('NOCA_paleo','NOCA paleo'),('retained','CCA retained')],
 'climate_windows': [('site','Site'),('period','Period'),('plots','Plots'),('n_MSpT','Spring years'),('n_MWT','Winter years'),('n_SP','Summer years'),('n_WP','Winter precipitation years')],
 'bacon_manifest': [('model','Model'),('role','Role'),('seed','Seed'),('rbacon_version','rbacon'),('posterior_bytes','Posterior bytes'),('generated_at_utc','Chronology generation UTC')],
 'era_catalog': [('era_id','Era'),('era_class','Class'),('older_cal_bp','Older cal BP'),('younger_cal_bp','Younger cal BP'),('duration_years','Duration years')],
 'fire_settings': [('lake','Lake'),('engine','Engine'),('interpolation_years','Interpolation years'),('smoothing_years','Background years'),('threshold_probability','Local threshold')],
 'event_audit': [('lake','Lake'),('candidate_events','Candidates'),('rejected_by_count_screen','Count rejected'),('accepted_events','Accepted')],
 'walsh_audit': [('lake','Lake'),('official_r_episodes','Official R episodes'),('published_total_episodes','Published total'),('difference','Difference')],
 'raw_climate_rates': [('variable_label','Constraint'),('rate_unit','Units'),('holocene_max_signed_rate_per_century','Holocene regional signed maximum'),('holocene_peak_cal_bp','Peak cal BP'),('anthropocene_median_rate_per_century_MORA','MORA modern median'),('anthropocene_median_rate_per_century_NOCA','NOCA modern median')],
 'era_centroids': [('site','Site'),('era_id','Era'),('n_dates','Positioned dates'),('observed_CCA1','Observed CCA1'),('observed_CCA2','Observed CCA2'),('predicted_CCA1','Predicted CCA1'),('predicted_CCA2','Predicted CCA2')],
 'resolution_audit': [('site','Site'),('metric','Metric'),('resolution','Resolution'),('n_dates','Dates'),('estimate_median','Median'),('n_per_bin_median','Median samples/bin')],
 'era_coverage': [('site','Site'),('climate_era_id','Era'),('n_site_dates','Supported dates'),('coverage_status','Coverage')],
 'tracking_summary': [('site','Site'),('macro_era','Era'),('fire_class','Fire'),('metric','Metric'),('n_total','Total'),('n_valid','Valid'),('median','Median'),('q25','Q25'),('q75','Q75')]
}

def combined_review():
    workflow = (ROOT / 'R/workflow.R').read_text()
    paths = re.findall(r'run_script\("(R/[^\"]+[.]R)"', workflow)
    paths = [p for p in paths if p.startswith('R/stages/')]
    if len(paths) != 25 or len(set(paths)) != 25: raise ValueError('Expected exactly 25 ordered workflow analysis stages.')
    text = '# GENERATED REVIEW COPY — DO NOT EXECUTE AS THE WORKFLOW\n# Rebuild: Rscript R/workflow.R --offline --report\n# Bodies are copied verbatim in workflow order; automatic and optional tests are excluded.\n# The driver provides conditional execution and isolated environments that concatenation does not preserve.\n# Retained helper sources refer to the actual shared definitions.\n# Historical chronology source hashes are preserved in docs/reorganization/chronology_relocation.json.\n#\n'
    text += ''.join(f'# {i:02d}. {p}\n' for i,p in enumerate(paths,1)) + '\n'
    for p in paths:
        text += '# ' + '='*76 + '\n# BEGIN '+p+'\n# '+ '='*76+'\n'
        text += (ROOT/p).read_text()
        if not text.endswith('\n'): text += '\n'
        text += '# END '+p+'\n\n'
    return text

def local_links(text):
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
        target = re.sub(r'\s+[\'\"].*$', '', target).strip('<>')
        if re.match(r'^(https?://|mailto:|#)', target): continue
        yield target.split('#',1)[0]

def validate(root=ROOT):
    doc = root/'docs/ANALYSIS_REVIEW.md'; html = root/'docs/ANALYSIS_REVIEW.html'
    text = doc.read_text(); h = html.read_text()
    md5 = hashlib.md5(doc.read_bytes()).hexdigest()
    if f'paleoaces-source-md5: {md5}' not in h: raise ValueError('Review HTML is not synchronized.')
    if re.search(r'(?:src|href)="assets/[^\"]+[.](?:png|jpg)"',h): raise ValueError('HTML preview is not self-contained.')
    if not re.search(r'data:image/png;base64,',h): raise ValueError('HTML lacks embedded figure previews.')
    for p in local_links(text):
        if not (doc.parent/p).exists(): raise ValueError('Broken report link: '+p)
        if p.startswith('../output/'): raise ValueError('Report depends on ignored local results: '+p)
    for n in range(2,6):
        if text.count(f'### Figure {n}.') != 1: raise ValueError('Manuscript numbering drift.')
    meta = json.loads((root/ASSETS/'build.json').read_text())
    expected = {a['artifact'] for a in rows(root/ASSETS/'artifacts.csv')}
    actual = {p.relative_to(root).as_posix() for p in (root/ASSETS).rglob('*') if p.is_file()}
    if not actual.issubset(expected | {str(ASSETS/'artifacts.csv'),str(ASSETS/'build.json')}): raise ValueError('Unregistered derived report product.')
    for record in rows(root/ASSETS/'artifacts.csv'):
        path = root/record['artifact']
        if not path.exists() or sha(path) != record['output_sha256']: raise ValueError('Missing/stale report artifact: '+record['artifact'])
        if record['producer_sha256'] and sha(root/record['producer']) != record['producer_sha256']: raise ValueError('Report producer code changed: '+record['producer'])
        if record['pdf_page']:
            data = path.read_bytes()
            if data[:8] != b'\x89PNG\r\n\x1a\n': raise ValueError('Invalid preview PNG.')
            width=int.from_bytes(data[16:20],'big'); height=int.from_bytes(data[20:24],'big')
            if min(width,height) < 500: raise ValueError('Preview resolution is too low.')
    if sha(root/ASSETS/'inputs.csv') != meta['input_manifest_sha256']: raise ValueError('Input manifest changed.')
    if sha(root/ASSETS/'sources.csv') != meta['source_manifest_sha256']: raise ValueError('Source manifest changed.')
    if sha(root/ASSETS/'results.csv') != meta['result_manifest_sha256']: raise ValueError('Result manifest changed.')
    print('Report integrity passed: links, hashes, synchronized self-contained HTML, figures 2–5, and readable previews.', flush=True)

def build(mode):
    for name in ['pdfinfo','pdftoppm','Rscript']:
        if not shutil.which(name): raise RuntimeError('Report rebuilding requires '+name)
    registry=json.loads(REGISTRY.read_text())
    stamp=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    fresh=mode=='fresh'; run=json.loads((ROOT/'output/report/run.json').read_text()) if fresh else {}
    if fresh:
        start={r['path']:r['sha256'] for r in rows(ROOT/'output/report/input_start.csv')}
        current={r['path']:r['sha256'] for r in manifest(input_files())}
        if current != start: raise ValueError('Report inputs or code changed during the run; start a new validated workflow.')
        recorded={r['path']:r for r in run['records']}
        required=[x['pdf'] for x in registry['diagnostics'] if x['status']!='historical reference']
        required += ['plot/'+x['stem']+'.'+ext for x in registry['main_figures'] for ext in ['pdf','png']]
        required += [x['source'] for x in registry['tables'].values() if not x['source'].endswith('bacon_run_manifest.csv')]
        for p in required:
            if p not in recorded or sha(ROOT/p)!=recorded[p]['sha256']: raise ValueError('Fresh report lacks a regenerated, unchanged producer output: '+p)
    with tempfile.TemporaryDirectory(prefix='.analysis-review-',dir=ROOT/'docs') as tmp:
        work=Path(tmp); out=work/ASSETS; out.mkdir(parents=True)
        (work/'docs/report').mkdir(parents=True)
        # Mirror portable links while the report is rendered and validated in isolation.
        for p in ROOT.iterdir():
            if p.name in ['docs','.git','.Rproj.user']: continue
            (work/p.name).symlink_to(p, target_is_directory=p.is_dir())
        for p in (ROOT/'docs').iterdir():
            if p.name in ['assets','ANALYSIS_REVIEW.md','ANALYSIS_REVIEW.html','report','review'] or p.name.startswith('.analysis-review-'): continue
            (work/'docs'/p.name).symlink_to(p, target_is_directory=p.is_dir())
        for p in (ROOT/'docs/report').iterdir(): (work/'docs/report'/p.name).symlink_to(p)
        (work/'docs/review').mkdir()
        review_path = work/'docs/review/00_main_analysis_review.R'
        review_path.write_text(combined_review())
        input_manifest=manifest(input_files()); write_csv(out/'inputs.csv',input_manifest)
        sources=manifest([p for p in input_files() if p.suffix in ['.R','.py','.md'] or p == REGISTRY or 'reorganization' in p.parts])
        write_csv(out/'sources.csv',sources)
        result_files=[p for p in (ROOT/'output').iterdir() if p.is_file() and p.suffix in ['.csv','.gz','.rds']]
        result_files += [ROOT/x['pdf'] for x in registry['diagnostics']] + [ROOT/'plot'/(x['stem']+'.'+e) for x in registry['main_figures'] for e in ['pdf','png']]
        write_csv(out/'results.csv',manifest(sorted(set(result_files))))
        ih=sha(out/'inputs.csv'); sh=sha(out/'sources.csv'); rh=sha(out/'results.csv')
        artifacts=[]
        def record(path,producer,source='',page='',status='current',origin=None):
            # Source paths identify local evidence but aren't dependencies for portable reading.
            artifact=path.relative_to(work).as_posix() if path.is_relative_to(work) else relative(path)
            artifacts.append(dict(artifact=artifact,producer=producer,producer_sha256=sha(ROOT/producer) if producer else '',source=source,
                source_sha256=sha(ROOT/source) if source else '',pdf_page=page,output_sha256=sha(path),input_manifest_sha256=ih,
                source_manifest_sha256=sh,result_manifest_sha256=rh,provenance_status=status,
                build_mode=origin or mode,run_id=run.get('run_id','snapshot-'+stamp),built_at_utc=stamp))
        record(review_path, 'tools/build_analysis_review.py', 'R/workflow.R', status='generated verbatim reading copy')
        for name in ['inputs','sources','results']: record(out/(name+'.csv'),'tools/build_analysis_review.py',status='fingerprint manifest')
        tables={}
        for name,x in registry['tables'].items():
            source=ROOT/x['source']
            if not source.exists(): raise FileNotFoundError('Missing report evidence: '+x['source'])
            dst=out/'tables'/(name+'.csv'); dst.parent.mkdir(exist_ok=True); shutil.copyfile(source,dst)
            tables[name]=rows(dst); record(dst,x['producer'],x['source'],status='validated stored chronology' if name=='bacon_manifest' else 'current result table')
        table_blocks={}
        for name,cols in COLUMNS.items():
            data=tables[name]
            if name=='resolution_audit': data=[r for r in data if r['record_type']=='timeseries summary' and r['metric'] in ['lag_per_century','tracking_ratio','angle_degrees']]
            if name=='tracking_summary': data=[r for r in data if r['summary_level']=='macro era x fire' and r['metric'] in ['lag_per_century','tracking_ratio','angle_degrees']]
            if data and any(key not in data[0] for key,_ in cols):
                missing=[key for key,_ in cols if key not in data[0]]
                raise ValueError('Unexpected authoritative table schema '+name+': '+str(missing))
            table_blocks[name]=mdtable(data,cols) if data else ''
            table_blocks[name]+=f'[Full curated {name.replace("_"," ")} table](assets/analysis/tables/{name}.csv).\n'
        corrections=tables['correction_audit']; statuses={}
        for r in corrections: statuses[r['final_status']]=statuses.get(r['final_status'],0)+1
        correction_rows=[dict(status=k,plots=v) for k,v in sorted(statuses.items())]
        table_blocks['correction_summary']=mdtable(correction_rows,[('status','Patch audit status'),('plots','Affected plot IDs')])+f'[Complete correction audit](assets/analysis/tables/correction_audit.csv), [study exclusions](assets/analysis/tables/study_exclusions.csv), and [unresolved coordinate collision](assets/analysis/tables/coordinate_collision.csv).\n'
        groups={}
        for r in tables['direction_summary']:
            key=tuple(r[k] for k in ['period','site','climate_state','high_fire','burned'])
            if key not in groups: groups[key]=dict(zip(['period','site','climate_state','high_fire','burned'],key),n_units=r['n_units'],valid=[])
            groups[key]['valid'].append(int(r['n_valid']))
        support=[dict(period=g['period'],site=g['site'],climate_state=g['climate_state'],fire=g['burned'] if g['period']=='Anthropocene' else g['high_fire'],n_units=g['n_units'],valid_min=min(g['valid']),valid_max=max(g['valid'])) for g in groups.values()]
        write_csv(out/'tables/direction_support.csv',support); record(out/'tables/direction_support.csv','tools/build_analysis_review.py','output/cca_direction_group_summaries.csv',status='generated support summary')
        table_blocks['direction_support']=mdtable(support,[('period','Period'),('site','Site'),('climate_state','Climate state'),('fire','Burned/high fire'),('n_units','Units'),('valid_min','Min valid targets'),('valid_max','Max valid targets')])+'[Full direction summaries](assets/analysis/tables/direction_summary.csv) and [group support](assets/analysis/tables/direction_support.csv).\n'
        diagnostic_blocks={}; inventory=[]
        for x in registry['diagnostics']:
            source=ROOT/x['pdf']
            info=subprocess.check_output(['pdfinfo',str(source)],text=True)
            page_count=int(re.search(r'^Pages:\s+(\d+)',info,re.M)[1])
            if not x['pages'] or max(x['pages'])<=page_count: pass
            else: raise ValueError('Requested PDF page is absent: '+x['pdf'])
            status=x['status']; section=x['section']
            block=f'### {x["purpose"]}\n\n{x["interpretation"]}\n\nProducer: [{Path(x["producer"]).name}](../{x["producer"]}). [Complete PDF](../{x["pdf"]}); {page_count} page(s). Evidence status: **{status}**.\n\n'
            record(source,x['producer'],x['pdf'],status=status,origin='historical reference' if section=='historical' else mode)
            for page in x['pages']:
                stem=x['id']+f'-p{page}'; dest=out/(stem+'.png')
                command(['pdftoppm','-f',page,'-l',page,'-singlefile','-png','-r','170',source,out/stem])
                record(dest,x['producer'],x['pdf'],page,status)
                block+=f'![{x["purpose"]} — PDF page {page}](assets/analysis/{stem}.png)\n\n'
            diagnostic_blocks[section]=diagnostic_blocks.get(section,'')+block
            inventory.append(dict(diagnostic=f'[{Path(x["pdf"]).name}](../{x["pdf"]})',purpose=x['purpose'],producer=f'[{Path(x["producer"]).name}](../{x["producer"]})',pages=', '.join(map(str,x['pages'])) or 'Full PDF only',interpretation=x['interpretation'],status=status))
        fig_blocks={}
        titles={2:'Climate eras, climate rates and high-fire periods',3:'Observed and climate-predicted community trajectories',4:'Vegetation tracking across eras and fire contexts',5:'Predicted-minus-observed target-alignment discrepancies'}
        for x in registry['main_figures']:
            src=ROOT/'plot'/(x['stem']+'.png'); dest=out/f'figure-{x["number"]}.png'; shutil.copyfile(src,dest)
            record(dest,x['producer'],relative(src),status='manuscript figure')
            record(ROOT/'plot'/(x['stem']+'.pdf'),x['producer'],'plot/'+x['stem']+'.pdf',status='manuscript PDF')
            fig_blocks['figure_'+str(x['number'])]=f'### Figure {x["number"]}. {titles[x["number"]]}\n\n![Figure {x["number"]}. {x["stem"].replace("_"," ")}](assets/analysis/figure-{x["number"]}.png)\n\n[Full PDF](../plot/{x["stem"]}.pdf). Producer: [{Path(x["producer"]).name}](../{x["producer"]}). [Authoritative method and publication caption](FIGURE_CAPTIONS.md).\n'
        command(['Rscript',ROOT/'tools/render_review_diagram.R',out/'dependencies.png'])
        record(out/'dependencies.png','tools/render_review_diagram.R',status='documentation diagram')
        decisions=(ROOT/'docs/SCIENTIFIC_DECISIONS.md').read_text()
        questions=decisions.split('## Remaining scientific questions\n',1)[1].split('## Inference limits',1)[0].strip()
        write_csv(out/'artifacts.csv',artifacts)
        meta=dict(mode=mode,built_at_utc=stamp,run_id=run.get('run_id','snapshot-'+stamp),input_manifest_sha256=ih,source_manifest_sha256=sh,result_manifest_sha256=rh,
            publication='staged and validated before replacement',chronology='validated stored posteriors; no MCMC in reporting')
        (out/'build.json').write_text(json.dumps(meta,indent=2)+'\n')
        validation=run.get('validation','The initial snapshot uses verified existing outputs. All 16 existing automatic gates passed before relocation; this snapshot does not assert that its existing figures were regenerated in a fresh analysis run.')
        validation+=' The report builder checked source availability, PDF page selections, artifact hashes and local links. The chronology manifest was validated, and the four main stems/PDF-only diagnostic contract were checked.\n'
        validation+='\nFor validation commands and contracts, see [workflow checks](WORKFLOW.md#tests-and-decisions) and the [baseline log](reorganization/baseline-gates.log).\n'
        status=f'**{"Fresh validated analysis run" if fresh else "Snapshot of verified existing outputs"}. Report built {stamp}. '
        status+=f'Run identifier: `{meta["run_id"]}`. '+('All included current figures and tables were regenerated in this run; chronology was redrawn from protected stored posteriors.' if fresh else 'Existing figures/tables are a review snapshot; only current-model reporting summaries were exported for this build. These outputs are not claimed to come from a fresh run.')
        values=dict(table_blocks,**fig_blocks,build_status=status,questions=questions,validation=validation,
            diagnostic_inventory=mdtable(inventory,[('diagnostic','Full diagnostic PDF'),('purpose','Purpose'),('producer','Producer'),('pages','Inline PDF pages'),('interpretation','Interpretation'),('status','Status')]),
            provenance='[Artifact ledger](assets/analysis/artifacts.csv) records producer/source/output SHA-256 hashes, selected PDF pages, build mode and provenance status. [Input fingerprints](assets/analysis/inputs.csv), [source fingerprints](assets/analysis/sources.csv), [result fingerprints](assets/analysis/results.csv), and [build metadata](assets/analysis/build.json) preserve the evidence snapshot without publishing raw research files. Original paths and relocation hashes are in the [relocation map](reorganization/relocation_map.csv). Each fresh producer output is checked against this workflow run; the builder accepts no missing or stale current output. The historical CHELSA comparison is separately labeled and stored chronology provenance remains unchanged.\n')
        for sec in ['vegetation','taxonomy','chronology','climate','cca','fire','tracking','direction']: values[sec+'_diagnostics']=diagnostic_blocks[sec]
        text=TEMPLATE.read_text()
        for key,val in values.items(): text=text.replace('{{'+key+'}}',val)
        unresolved=re.findall(r'{{[^}]+}}',text)
        if unresolved: raise ValueError('Unresolved narrative template fields: '+str(unresolved))
        md=work/'docs/ANALYSIS_REVIEW.md'; md.write_text(text)
        command(['Rscript',ROOT/'R/render_docs.R',md])
        validate(work)
        # Transaction with rollback: install only completely generated, validated products.
        targets=[(out,ROOT/ASSETS),(md,ROOT/'docs/ANALYSIS_REVIEW.md'),(md.with_suffix('.html'),ROOT/'docs/ANALYSIS_REVIEW.html'),(review_path,ROOT/'docs/review/00_main_analysis_review.R')]
        backups=[]; installed=[]
        try:
            for i,(src,dst) in enumerate(targets):
                dst.parent.mkdir(parents=True,exist_ok=True)
                backup=work/('previous-'+str(i))
                if dst.exists(): os.replace(dst,backup); backups.append((backup,dst))
                os.replace(src,dst); installed.append(dst)
            validate(ROOT)
        except BaseException:
            for dst in reversed(installed):
                if dst.is_dir(): shutil.rmtree(dst)
                elif dst.exists(): dst.unlink()
            for src,dst in backups: os.replace(src,dst)
            raise
    print('Published '+mode+' analysis review and regenerated all derived documentation assets.',flush=True)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    group=parser.add_mutually_exclusive_group(required=True)
    for name in ['capture','snapshot','fresh','validate']: group.add_argument('--'+name,action='store_true')
    args=parser.parse_args()
    if args.capture: capture()
    elif args.validate: validate()
    else: build('fresh' if args.fresh else 'snapshot')
if __name__=='__main__': main()
