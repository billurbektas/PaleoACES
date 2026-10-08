#!/usr/bin/env python3
"""Build a staged, validated review from authoritative tables and selected PDFs.
No raw input or scientific result is modified. Python standard library only.
"""
from pathlib import Path
import argparse, csv, hashlib, json, os, re, shutil, subprocess, tempfile, textwrap
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
        w = csv.DictWriter(f, fieldnames=fields, lineterminator="\n"); w.writeheader(); w.writerows(data)

def relative(path): return path.relative_to(ROOT).as_posix()

def input_files():
    files = []
    for directory in ['R', 'tools', 'data', 'Cores', 'notes_from_Rachel']:
        for path in (ROOT / directory).rglob('*'):
            if not path.is_file() or path.name == '.DS_Store': continue
            if directory == 'R' and 'archive' in path.parts: continue
            if directory in ['R', 'tools'] and path.suffix not in ['.R', '.py']: continue
            if directory == 'Cores' and path.suffix not in ['.csv', '.out', '.txt']: continue
            files.append(path)
    for directory in ['mora_climate_parts', 'noca_climate_parts', 'chelsa_paleo', 'anomaly_parts', '_reference']:
        files.extend((ROOT / 'output' / directory).glob('*.csv'))
    files += list((ROOT / "docs/report").glob("*.csv"))
    files += list((ROOT / "docs/report").glob("*.json"))
    files += [REGISTRY, TEMPLATE, ROOT / 'R/helpers/bacon_settings.R', ROOT / 'output/bacon_run_manifest.csv']
    files += list((ROOT / 'Cores/provenance').glob('*.json'))
    files += list((ROOT / 'Cores/provenance/chronology_sources_before_move').glob('*.txt'))
    files += list((ROOT/'R/tests/fixtures').glob('*.csv'))
    files += [ROOT/p for p in ['docs/SCIENTIFIC_DECISIONS.md', 'docs/FIGURE_CAPTIONS.md', 'docs/methods/000_NOCA_cleaning_guide.md', 'docs/methods/README_occurrence_consolidation.md', 'docs/review/NOCA_GPS_EXCLUSION.md', 'docs/review/TRACKING_DATA_VALIDATION.md', 'docs/review/NOCA_TRACKING_MIGRATION_CHECK.csv', 'docs/review/TRACKING_COMPACT_PRESERVATION.csv', 'docs/review/TRACKING_INDEPENDENT_CHECKS.csv']]
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
 'cca_anova': [('component','Model / axis'),('df','df'),('pseudo_F','Pseudo-F'),('p_unrestricted','p: unrestricted'),('p_within_parks','p: within parks')],
 'cca_species_contributions': [('species','Species'),('legacy_plots','Legacy plots'),('percent_constrained_inertia','% climate-explained inertia'),('CCA1','CCA1 score'),('CCA2','CCA2 score')],
 'cca_climate_contributions': [('variable_label','Climate variable'),('unique_percent_constrained','Unique % climate-explained inertia'),('VIF','VIF'),('pseudo_F','Pseudo-F'),('p_unrestricted','p: unrestricted'),('p_within_parks','p: within parks')],
 'cca_counts': [('site','Site'),('period','Period'),('input_samples','Prepared climate samples'),('calibration_samples','Calibrated'),('positioned_samples','Positioned projection')],
 'cca_eligibility_counts': [('era','Era'),('site','Site'),('use','Use'),('input_units','Prepared plots/samples'),('excluded_units','Excluded'),('included_units','Included')],
 'cca_exclusion_summary': [('era','Era'),('site','Site'),('use','Use'),('exclusion_period','Excluded at'),('reason','Reason'),('excluded_units','Count')],
 'modern_centroids': [('site','Site'),('t','Survey'),('n','Same paired plots'),('o1','Observed CCA1'),('o2','Observed CCA2'),('p1','Predicted CCA1'),('p2','Predicted CCA2')],
 'cca_taxa': [('species','Taxon'),('MORA_past','MORA legacy'),('MORA_present','MORA resurvey'),('MORA_paleo','MORA paleo'),('NOCA_past','NOCA legacy'),('NOCA_present','NOCA resurvey'),('NOCA_paleo','NOCA paleo'),('retained','CCA retained')],
 'mora_repeat_visits': [('plot_id','Plot'),('adult_years','Adult visits'),('selected_year','Selected year'),('visit_date','Selected date'),('adults_kept','Adult records kept'),('adults_discarded','Earlier records removed')],
 'survey_climate_windows': [('site','Site'),('period','Survey'),('survey_year','Adult resurvey year'),('climate_start','First climate year'),('climate_end','Last climate year'),('analyzed_plots','Analyzed plots')],
 'survey_decision_effects': [('site','Site'),('metric','Quantity'),('changed_plots','Changed plots'),('before_median','Before median'),('after_median','After median')],
 'latest_visit_composition_effects': [('plot_id','Plot'),('species','Presence removed from pooled resurvey')],
 'climate_windows': [('site','Site'),('period','Period'),('plots','Plots'),('n_MSpT','Spring years'),('n_MWT','Winter years'),('n_SP','Summer years'),('n_WP','Winter precipitation years')],
 'bacon_manifest': [('model','Model'),('role','Role'),('seed','Seed'),('rbacon_version','rbacon'),('posterior_bytes','Posterior bytes'),('generated_at_utc','Chronology generation UTC')],
 'era_catalog': [('era_id','Era'),('era_class','Class'),('older_cal_bp','Older cal BP'),('younger_cal_bp','Younger cal BP'),('duration_years','Duration years')],
 'fire_settings': [('lake','Lake'),('engine','Engine'),('interpolation_years','Interpolation years'),('smoothing_years','Background years'),('threshold_probability','Local threshold')],
 'event_audit': [('lake','Lake'),('candidate_events','Candidates'),('rejected_by_count_screen','Count rejected'),('accepted_events','Accepted')],
 'walsh_audit': [('lake','Lake'),('official_r_episodes','Official R episodes'),('published_total_episodes','Published total'),('difference','Difference')],
 'raw_climate_rates': [('variable_label','Constraint'),('rate_unit','Units'),('holocene_max_signed_rate_per_century','Holocene regional signed maximum'),('holocene_peak_cal_bp','Peak cal BP'),('anthropocene_median_rate_per_century_MORA','MORA modern median'),('anthropocene_median_rate_per_century_NOCA','NOCA modern median')],
 'lake_support': [('lake','Lake'),('offset','Offset'),('n_eligible_samples','Samples'),('n_transitions','Transitions'),('present_draws_min','Minimum draws'),('n_nmin2_realizations','Two-sample realizations')],
 'era_centroids': [('site','Site'),('era_id','Era'),('n_dates','Positioned dates'),('observed_CCA1','Observed CCA1'),('observed_CCA2','Observed CCA2'),('predicted_CCA1','Predicted CCA1'),('predicted_CCA2','Predicted CCA2')],
}

def workflow_stages():
    workflow = (ROOT / 'R/workflow.R').read_text()
    paths = re.findall(r'run_script\("(R/[^\"]+[.]R)"', workflow)
    paths = [p for p in paths if p.startswith('R/stages/')]
    if len(paths) != 21 or len(set(paths)) != 21: raise ValueError('Expected exactly 21 ordered workflow analysis stages.')
    return paths

def tracking_calculation_sections():
    """Extract calculation statements from the maintained helper, without its setup."""
    helper = (ROOT/'R/helpers/tracking_metrics.R').read_text()
    def body(name):
        match = re.search(r'^'+re.escape(name)+r' = function\([^\n]*\) \{\n(.*?)^\}',
                          helper,re.M|re.S)
        if not match: raise ValueError('Missing tracking calculation function: '+name)
        return match.group(1)
    def excerpt(source,start,end):
        starts=list(re.finditer('^'+re.escape(start),source,re.M))
        ends=list(re.finditer('^'+re.escape(end),source,re.M))
        if len(starts)!=1 or len(ends)!=1 or ends[0].start()<=starts[0].start():
            raise ValueError('Ambiguous tracking calculation excerpt: '+start)
        lo=starts[0].start(); hi=ends[0].start()
        return textwrap.dedent(source[lo:hi]).strip()
    tracking=body('calculate_tracking_metrics')
    angle=body('safe_cosine_2d')
    climate=body('add_climate_change_metrics')
    return [
        ('Endpoint geometry and lag/turnover rates','\n'.join([
            excerpt(tracking,'  coords =','  need ='),
            excerpt(tracking,'  ox =','  x$small_observed_movement ='),
            excerpt(tracking,'  observed_direction =','  x$angle_valid ='),
            excerpt(tracking,'  x$observed_vegetation_displacement =','  x$magnitude_tracking_ratio ='),
            excerpt(tracking,'  x$lag_t1 =','  # Only divide')])),
        ('Tracking ratios and turnover angle',
            excerpt(tracking,'  x$magnitude_tracking_ratio =','  x$lag_t1 =')),
        ('Guarded cosine used internally for the angle',
            excerpt(angle,'  a = sqrt(ax^2','  result\n')),
        ('Pace and direction counterfactual effects',
            excerpt(tracking,'  # Only divide','  x\n')),
        ('Physical seasonal climate changes and standardized rate',
            excerpt(climate,'  z_change_cols =','  x\n'))]

def tracking_calculation_markdown():
    return '\n\n'.join('**'+title+'.**\n\n```r\n'+code+'\n```'
                       for title,code in tracking_calculation_sections())+'\n'

def combined_review():
    paths = workflow_stages()
    text = '# GENERATED REVIEW COPY — DO NOT EXECUTE AS THE WORKFLOW\n# Rebuild: Rscript R/workflow.R --offline --report\n# Bodies are copied verbatim in workflow order; automatic and optional tests are excluded.\n# The driver provides conditional execution and isolated environments that concatenation does not preserve.\n# Retained helper sources refer to the actual shared definitions.\n# Historical chronology source hashes are preserved in Cores/provenance/chronology_relocation.json.\n#\n'
    text += ''.join(f'# {i:02d}. {p}' + (' [OPTIONAL: --age-models; control generation and MCMC]' if p.endswith('/000_PALEO_a_agedepth.R') else '') + '\n' for i,p in enumerate(paths,1)) + '\n'
    for p in paths:
        text += '# ' + '='*76 + '\n# BEGIN '+p+'\n# '+ '='*76+'\n'
        if p.endswith('/000_PALEO_a_agedepth.R'):
            text += '# OPTIONAL WORKFLOW STAGE: runs only with --age-models.\n# Do not run this review copy to inspect stored chronology figures.\n'
        text += (ROOT/p).read_text()
        if not text.endswith('\n'): text += '\n'
        text += '# END '+p+'\n\n'
    helper = 'R/helpers/tracking_metrics.R'
    text += '# BEGIN '+helper+' — calculation excerpts; see helper for full functions\n'
    for title,code in tracking_calculation_sections():
        text += '# '+title+'\n'+code+'\n\n'
    text += '# END '+helper+'\n'
    return text

def script_map():
    groups = [
        ('Modern vegetation and fire', 3), ('Modern climate', 2),
        ('Chronology (optional refit)', 1), ('Paleo vegetation and fire', 3),
        ('Paleo climate', 2), ('Taxonomy consolidation', 1),
        ('CCA eligibility, calibration and reference', 1),
        ('Fire catalog and climate eras', 2), ('Canonical lake/plot tracking', 1), ('Community trajectories: Figure 3', 1),
        ('Tracking and fire-detection examples', 2), ('Climate/fire display: Figure 2 and example', 2)]
    paths = workflow_stages(); index = 0; data = []
    for part,count in groups:
        selected = paths[index:index+count]
        scripts = '; '.join(f'[{Path(p).name}](../{p})' for p in selected)
        data.append(dict(order=str(index+1) if count == 1 else f'{index+1}–{index+count}',part=part,scripts=scripts))
        index += count
    if index != len(paths): raise ValueError('Workflow script map is incomplete.')
    return mdtable(data,[('order','Order'),('part','Analysis step'),('scripts','Scripts')])

METRIC_LABELS = {'lag_rate_per_century': 'Δlag per century',
                 'rate_tracking_ratio': 'Tracking rate ratio', 'angle_degrees': 'Movement angle (°)'}
CCA_LABELS = {'calibration_plots': 'Legacy calibration plots', 'retained_species': 'Retained taxa',
              'count_threshold': 'Minimum occupancy in one site × period', 'scaling': 'CCA score scaling',
              'hill': 'Hill scaling', 'constraints': 'Climate variables', 'total_inertia': 'Total inertia',
              'constrained_inertia': 'Climate-constrained inertia', 'constrained_percent': 'Constrained inertia (%)',
              'projection_candidates': 'Modern plots and paleo samples before eligibility',
              'positioned_samples': 'Eligible modern pairs and paleo samples'}

def local_links(text):
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
        target = re.sub(r'\s+[\'\"].*$', '', target).strip('<>')
        if re.match(r'^(https?://|mailto:|#)', target): continue
        yield target.split('#',1)[0]

def validate_tracking_contracts(root):
    # Portable readers must see the same compact contracts as local model users.
    responses = ['lag_rate_per_century', 'observed_turnover_rate', 'magnitude_tracking_ratio',
                 'rate_tracking_ratio', 'angle_degrees', 'pace_effect_on_lag_per_century',
                 'direction_effect_on_lag_per_century']
    keys = ['site', 'lake', 'offset', 'age_hi', 'age_lo']
    contracts = {
        'lake_by_offset': keys + ['interval_mid_cal_bp', 'vegetation_dt_years', 'climate_dt_years',
            'standardized_climate_change_rate', 'fire_activity', 'fire_coverage_valid', 'high_fire'] +
            responses + ['n_draws_present', 'n_draws_nmin2', 'n_samples_t1_median', 'n_samples_t2_median'],
        'modern_model_input': ['site', 'plot_id', 'vegetation_t1_year', 'vegetation_t2_year',
            'climate_t1_midyear', 'climate_t2_midyear', 'vegetation_dt_years', 'climate_dt_years',
            'standardized_climate_change_rate', 'burned'] + responses + ['angle_valid',
            'pace_counterfactual_valid', 'direction_counterfactual_valid', 'tracking_ratio_valid'],
        'lake_uncertainty': keys + ['metric', 'sampling_rule', 'median', 'q025', 'q975',
            'n_expected_draws', 'n_present_draws', 'n_eligible_draws', 'n_valid_draws', 'n_undefined_draws']}
    for name, expected in contracts.items():
        with (root/ASSETS/'tables'/f'{name}.csv').open(newline='') as f:
            header = next(csv.reader(f))
        if header != expected: raise ValueError('Portable tracking contract differs: '+name)
    modern = rows(root/ASSETS/'tables/modern_model_input.csv')
    calculations = rows(root/ASSETS/'tables/modern_calculations.csv')
    indexed = {(r['site'], r['plot_id']): r for r in calculations}
    if len(indexed) != len(calculations) or len(modern) != len(calculations):
        raise ValueError('Modern model/calculation keys differ.')
    for r in modern:
        audit = indexed.get((r['site'], r['plot_id']), {})
        if any(value != audit.get(column) for column, value in r.items()):
            raise ValueError('Modern model differs from calculation record: '+r['plot_id'])

def validate(root=ROOT):
    validate_tracking_contracts(root)
    doc = root/'docs/ANALYSIS_REVIEW.md'; html = root/'docs/ANALYSIS_REVIEW.html'
    text = doc.read_text(); h = html.read_text()
    md5 = hashlib.md5(doc.read_bytes()).hexdigest()
    if f'paleoaces-source-md5: {md5}' not in h: raise ValueError('Review HTML is not synchronized.')
    if re.search(r'(?:src|href)="assets/[^\"]+[.](?:png|jpg)"',h): raise ValueError('HTML preview is not self-contained.')
    if not re.search(r'data:image/png;base64,',h): raise ValueError('HTML lacks embedded figure previews.')
    for p in local_links(text):
        if not (doc.parent/p).exists(): raise ValueError('Broken report link: '+p)
        if p.startswith('../output/'): raise ValueError('Report depends on ignored local results: '+p)
    for n in [2,3]:
        if text.count(f'### Figure {n}.') != 1: raise ValueError('Manuscript numbering drift.')
    fitted = {r['field']: r['value'] for r in rows(root/ASSETS/'tables/cca_summary.csv')}
    if fitted.get('constraints') != 'MSpT;MWT;SP;WP':
        raise ValueError('Report is missing the current fitted CCA constraints.')
    species = rows(root/ASSETS/'tables/cca_species_contributions.csv')
    climate = rows(root/ASSETS/'tables/cca_climate_contributions.csv')
    anova = rows(root/ASSETS/'tables/cca_anova_full.csv')
    if len(species) != int(fitted['retained_species']) or len({r['species'] for r in species}) != len(species):
        raise ValueError('CCA species contributions do not match the fitted taxa.')
    if abs(sum(float(r['percent_constrained_inertia']) for r in species)-100) > 1e-8:
        raise ValueError('CCA species contributions do not sum to 100%.')
    constrained = float(fitted['constrained_inertia'])
    if abs(sum(float(r['constrained_inertia']) for r in species)-constrained) > 1e-10:
        raise ValueError('CCA species inertia does not reconcile with the model.')
    if {r['variable'] for r in climate} != set(fitted['constraints'].split(';')) or len(climate) != 4:
        raise ValueError('CCA climate contribution table omits a fitted constraint.')
    for r in climate:
        if abs(float(r['unique_percent_constrained'])-100*float(r['marginal_inertia'])/constrained) > 1e-8:
            raise ValueError('CCA climate contribution uses the wrong denominator.')
    axes = {r['axis']:float(r['eigenvalue']) for r in rows(root/ASSETS/'tables/cca_axes.csv')}
    for design in ['Unrestricted', 'Within parks']:
        valid = [r for r in anova if r['design']==design and r['p_value']!='NA']
        if len(valid) != 1+len(axes)+len(climate): raise ValueError('Incomplete CCA permutation tests: '+design)
        for r in valid:
            if int(r['permutations']) != 9999 or int(r['seed']) != 20261008 or not 0 < float(r['p_value']) <= 1:
                raise ValueError('Unexpected CCA permutation settings/results.')
            expected = constrained if r['test']=='Overall' else axes.get(r['component']) if r['test']=='Axis' else None
            if expected is not None and abs(float(r['inertia'])-expected) > 1e-10:
                raise ValueError('CCA permutation output differs from the fitted inertia.')
    if not (text.index('### CCA model, contributions and tests') < text.index('### Figure 3.')):
        raise ValueError('CCA model details must precede the main CCA figure.')
    eligibility = rows(root/ASSETS/'tables/cca_eligibility_counts.csv')
    exclusions = rows(root/ASSETS/'tables/cca_exclusion_summary.csv')
    for r in eligibility:
        key = (r['era'], r['site'], r['use'])
        excluded = sum(int(x['excluded_units']) for x in exclusions
                       if (x['era'], x['site'], x['use']) == key)
        if int(r['excluded_units']) != excluded or int(r['input_units']) != excluded + int(r['included_units']):
            raise ValueError('CCA exclusion counts do not reconcile: '+str(key))
    pairs = rows(root/ASSETS/'tables/cca_pair_eligibility.csv')
    samples = rows(root/ASSETS/'tables/cca_sample_eligibility.csv')
    true = lambda x: x.upper() == 'TRUE'
    for site in sorted({x['site'] for x in pairs}):
        valid = {x['plot_id'] for x in pairs if x['site'] == site and true(x['comparison_included'])}
        calibrated = {x['plot_id'] for x in pairs if x['site'] == site and true(x['calibration_included'])}
        calibrated_samples = {x['plot_id'] for x in samples if x['site'] == site and x['period'] == 'past' and true(x['calibration_included'])}
        if calibrated != valid or calibrated_samples != valid:
            raise ValueError('CCA calibration does not use exactly the matched plots: '+site)
        for period in ['past', 'present']:
            ids = {x['plot_id'] for x in samples if x['site'] == site and x['period'] == period and true(x['comparison_included'])}
            if ids != valid: raise ValueError('Unbalanced modern CCA membership: '+site+' '+period)
        centroids = [x for x in rows(root/ASSETS/'tables/modern_centroids.csv') if x['site'] == site]
        if len(centroids) != 2 or {x['t'] for x in centroids} != {'legacy','resurvey'} or any(int(x['n']) != len(valid) for x in centroids):
            raise ValueError('Figure 3 does not use the valid paired CCA set: '+site)
    if '## Plots and samples included in CCA' not in text or 'Loss of all recorded tree-taxon presence at resurvey' not in text:
        raise ValueError('Report omitted the CCA exclusion explanation/table.')
    calculations = tracking_calculation_markdown()
    if calculations.rstrip() not in text or any(name not in text for name in
            ['n_draws_present', 'n_draws_nmin2', 'undefined', 'nmin2']):
        raise ValueError('Review omitted maintained calculation code or support definitions.')
    if (ROOT/'R/helpers/tracking_metrics.R').read_text().rstrip() in text:
        raise ValueError('Review embeds the whole tracking helper instead of calculation excerpts.')
    if any(f'### Figure {n}.' in text for n in [4,5]):
        raise ValueError('Retired manuscript figure remains active.')
    stages = workflow_stages()
    if any(f'../{p})' not in text for p in stages): raise ValueError('Report script map omits an active workflow stage.')
    review = root/'docs/review/00_main_analysis_review.R'
    if review.read_text() != combined_review(): raise ValueError('Combined analysis review differs from current workflow sources.')
    headings = re.findall(r'^## (.+)$',text,re.M)
    eligibility_heading = headings.index('Plots and samples included in CCA')
    if headings[eligibility_heading+1] != 'CCA calibration and geometry':
        raise ValueError('CCA eligibility must immediately precede calibration.')
    selection = rows(root/ASSETS/'tables/sample_selection_counts.csv')
    plot_sizes = rows(root/ASSETS/'tables/sample_selection_plot_sizes.csv')
    if len({(r['site'], r['legacy_area_m2']) for r in plot_sizes}) != len(plot_sizes):
        raise ValueError('Repeated retained plot-area counts.')
    for site in ['MORA', 'NOCA']:
        areas = [r for r in plot_sizes if r['site'] == site]
        expected_count = sum(r['site'] == site and true(r['calibration_included']) for r in pairs)
        if sum(int(r['plots']) for r in areas) != expected_count or any(
                int(r['plots']) <= 0 or float(r['resurvey_area_m2']) != 500 or
                (r['legacy_area_m2'] != 'NA' and float(r['legacy_area_m2']) <= 0) for r in areas):
            raise ValueError('Retained plot areas do not match CCA membership/protocol: '+site)
    lookup = {(r['site'], r['period'], float(r['step'])): r for r in selection}
    if len(lookup) != len(selection): raise ValueError('Repeated plot-selection steps.')
    def selection_count(site, period, step):
        r = lookup[site, period, float(step)]
        if any(int(r[k]) < 0 for k in ['remaining', 'removed', 'combined']):
            raise ValueError('Negative plot/sample count.')
        return r
    for site in ['MORA', 'NOCA']:
        chain = [2,3,4,5,9,10] if site == 'MORA' else [2,3,4,5,6,7,8,9,10]
        for before_step, after_step in zip(chain, chain[1:]):
            before = selection_count(site, 'Modern', before_step)
            after = selection_count(site, 'Modern', after_step)
            if int(before['remaining']) != int(after['remaining']) + int(after['removed']):
                raise ValueError('Modern plot count does not reconcile: '+site+' '+str(after_step))
        before = selection_count(site, 'Modern', 1)
        after = selection_count(site, 'Modern', 2.5)
        if int(before['remaining']) != int(after['remaining']) + int(after['removed']):
            raise ValueError('Legacy starting counts do not reconcile: '+site)
        for use, step in [('Legacy calibration',10), ('Modern paired comparison',10)]:
            expected_count = next(int(r['included_units']) for r in eligibility if r['site']==site and r['use']==use)
            if int(selection_count(site,'Modern',step)['remaining']) != expected_count:
                raise ValueError('Plot-selection figure does not match CCA: '+site+' '+use)
        start = selection_count(site, 'Holocene', 1)
        dated = selection_count(site, 'Holocene', 2)
        if int(start['remaining']) != int(dated['remaining']) + int(dated['combined']) or int(dated['removed']) != 0:
            raise ValueError('Combined core depths were miscounted as exclusions: '+site)
        for step in range(3,9):
            before = selection_count(site,'Holocene',step-1)
            after = selection_count(site,'Holocene',step)
            if int(before['remaining']) != int(after['remaining']) + int(after['removed']):
                raise ValueError('Holocene sample counts do not reconcile: '+site)
        expected_count = next(int(r['included_units']) for r in eligibility if r['site']==site and r['use']=='Paleo projection')
        if int(selection_count(site,'Holocene',8)['remaining']) != expected_count:
            raise ValueError('Core sample diagram does not match CCA: '+site)
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
    print('Report integrity passed: links, hashes, synchronized self-contained HTML, figures 2 and 3, and readable previews.', flush=True)

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
        required += [x['source'] for x in registry.get('text_outputs', {}).values()]
        required += [x['source'] for x in registry.get('reference_bundles', {}).values()]
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
        for p in (ROOT/'docs/review').iterdir():
            if p.name != '00_main_analysis_review.R':
                (work/'docs/review'/p.name).symlink_to(p, target_is_directory=p.is_dir())
        review_path = work/'docs/review/00_main_analysis_review.R'
        review_path.write_text(combined_review())
        input_manifest=manifest(input_files()); write_csv(out/'inputs.csv',input_manifest)
        sources=manifest([p for p in input_files() if p.suffix in ['.R','.py','.md'] or p == REGISTRY or 'provenance' in p.parts])
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
        text_blocks = {}
        for x in registry.get('reference_bundles', {}).values():
            source = ROOT/x['source']
            if not source.is_file(): raise FileNotFoundError('Missing calibration reference: '+x['source'])
            dst = out/source.name
            shutil.copyfile(source,dst)
            record(dst,x['producer'],x['source'],status='unchanged calibration reference bundle')
        for name,x in registry.get('text_outputs', {}).items():
            source = ROOT/x['source']
            if not source.is_file(): raise FileNotFoundError('Missing CCA output: '+x['source'])
            dst = out/source.name
            dst.write_text('\n'.join(line.rstrip() for line in source.read_text().splitlines())+'\n')
            record(dst, x['producer'], x['source'], status='current fitted CCA output')
            if name != 'cca_anova_output':
                language = 'r' if name == 'cca_model_code' else 'text'
                text_blocks[name] = f'```{language}\n{dst.read_text().rstrip()}\n```\n'
        text_blocks['tracking_metrics_code'] = tracking_calculation_markdown()
        table_blocks={}
        for name,cols in COLUMNS.items():
            data=tables[name]
            if name=='survey_decision_effects':
                data=[r for r in data if r['metric'] in ['vegetation_t2_year','climate_dt_years','observed_vegetation_displacement','predicted_vegetation_displacement','rate_tracking_ratio','change_in_lag','lag_rate_per_century']]
                labels={'vegetation_t2_year':'Adult resurvey year','climate_dt_years':'Climate interval (years)','observed_vegetation_displacement':'Observed displacement (CCA units)','predicted_vegetation_displacement':'Predicted displacement (CCA units)','rate_tracking_ratio':'Rate tracking ratio','change_in_lag':'Change in lag (CCA units)','lag_rate_per_century':'Lag rate (CCA units/century)'}
                data=[dict(r,metric=labels[r['metric']]) for r in data]
            if name=='cca_summary':
                data=[dict(r,field=CCA_LABELS[r['field']],value={'sites':'Site scaling (1)','FALSE':'Off'}.get(r['value'],r['value'])) for r in data]
            if name=='cca_anova': data=[dict(r,component='Whole model' if r['component']=='Model' else r['component']) for r in data]
            if data and any(key not in data[0] for key,_ in cols):
                missing=[key for key,_ in cols if key not in data[0]]
                raise ValueError('Unexpected authoritative table schema '+name+': '+str(missing))
            table_blocks[name]=mdtable(data,cols) if data else ''
            label=name.replace('_',' ').replace('cca','CCA')
            table_blocks[name]+=f'[Full {label} table](assets/analysis/tables/{name}.csv).\n'
        def join_names(names):
            if len(names) < 2: return ''.join(names)
            return ', '.join(names[:-1])+' and '+names[-1]
        axes = tables['cca_anova']
        supported = [r['component'] for r in axes if r['test']=='Axis' and float(r['p_within_parks'])<.05]
        unsupported = [r['component'] for r in axes if r['test']=='Axis' and float(r['p_within_parks'])>=.05]
        interpretation = []
        if supported: interpretation.append(join_names(supported)+(' meets' if len(supported)==1 else ' meet')+' p < 0.05 when plots are shuffled within parks.')
        if unsupported: interpretation.append(join_names(unsupported)+(' does not' if len(unsupported)==1 else ' do not')+' meet that threshold.')
        text_blocks['cca_axis_interpretation'] = ' '.join(interpretation)+'\n'
        climate = tables['cca_climate_contributions']
        sensitive = [r['variable_label'].lower() for r in climate if float(r['p_unrestricted'])<.05<=float(r['p_within_parks'])]
        both = [r['variable_label'].lower() for r in climate if max(float(r['p_unrestricted']),float(r['p_within_parks']))<.05]
        interpretation = []
        if sensitive: interpretation.append((join_names(sensitive)+(' meets' if len(sensitive)==1 else ' meet')+' p < 0.05 with unrestricted permutations, but '+('does not' if len(sensitive)==1 else 'do not')+' meet that threshold when plots are shuffled within parks.').capitalize())
        if both: interpretation.append((join_names(both)+(' meets' if len(both)==1 else ' meet')+' p < 0.05 under both permutation designs.').capitalize())
        text_blocks['cca_climate_interpretation'] = ' '.join(interpretation)+'\n'
        corrections=tables['correction_audit']; statuses={}
        for r in corrections: statuses[r['final_status']]=statuses.get(r['final_status'],0)+1
        correction_rows=[dict(status=k,plots=v) for k,v in sorted(statuses.items())]
        table_blocks['correction_summary']=mdtable(correction_rows,[('status','Patch audit status'),('plots','Affected plot IDs')])+mdtable(tables['study_exclusions'],[('plot_id','Study-excluded plot'),('exclusion_reason','Reason')])+f'[Complete correction audit](assets/analysis/tables/correction_audit.csv), [study exclusions](assets/analysis/tables/study_exclusions.csv), and [excluded GPS-coordinate collision](assets/analysis/tables/coordinate_collision.csv).\n'
        diagnostic_blocks={}; inventory=[]
        for x in registry['diagnostics']:
            source=ROOT/x['pdf']
            info=subprocess.check_output(['pdfinfo',str(source)],text=True)
            page_count=int(re.search(r'^Pages:\s+(\d+)',info,re.M)[1])
            if not x['pages'] or max(x['pages'])<=page_count: pass
            else: raise ValueError('Requested PDF page is absent: '+x['pdf'])
            status=x['status']; section=x['section']
            qualifier=f' **{status[0].upper()+status[1:]}**.' if status != 'current' else ''
            block=f'### {x["purpose"].rstrip(".")}\n\n{x["interpretation"]}{qualifier}\n\nScript: [{Path(x["producer"]).name}](../{x["producer"]}). [Complete PDF](../{x["pdf"]}) ({page_count} {"page" if page_count == 1 else "pages"}).\n\n'
            record(source,x['producer'],x['pdf'],status=status,origin='historical reference' if section=='historical' else mode)
            for page in x['pages']:
                stem=x['id']+f'-p{page}'; dest=out/(stem+'.png')
                command(['pdftoppm','-f',page,'-l',page,'-singlefile','-png','-r','170',source,out/stem])
                record(dest,x['producer'],x['pdf'],page,status)
                block+=f'![{x["purpose"]} — PDF page {page}](assets/analysis/{stem}.png)\n\n'
            diagnostic_blocks[section]=diagnostic_blocks.get(section,'')+block
            inventory.append(dict(diagnostic=f'[{Path(x["pdf"]).name}](../{x["pdf"]})',purpose=x['purpose'],producer=f'[{Path(x["producer"]).name}](../{x["producer"]})',pages=', '.join(map(str,x['pages'])) or 'Full PDF only',interpretation=x['interpretation'],status=status))
        fig_blocks={}
        titles={2:'Climate eras, climate rates and high-fire periods',3:'Observed and climate-predicted community trajectories'}
        for x in registry['main_figures']:
            src=ROOT/'plot'/(x['stem']+'.png'); dest=out/f'figure-{x["number"]}.png'; shutil.copyfile(src,dest)
            record(dest,x['producer'],relative(src),status='manuscript figure')
            record(ROOT/'plot'/(x['stem']+'.pdf'),x['producer'],'plot/'+x['stem']+'.pdf',status='manuscript PDF')
            fig_blocks['figure_'+str(x['number'])]=f'### Figure {x["number"]}. {titles[x["number"]]}\n\n![Figure {x["number"]}. {x["stem"].replace("_"," ")}](assets/analysis/figure-{x["number"]}.png)\n\n[Full PDF](../plot/{x["stem"]}.pdf) · [Figure script](../{x["producer"]}) · [Publication captions](FIGURE_CAPTIONS.md).\n'
        command(['Rscript',ROOT/'tools/render_review_diagram.R',out/'dependencies.png'])
        record(out/'dependencies.png','tools/render_review_diagram.R',status='documentation diagram')
        decisions=(ROOT/'docs/SCIENTIFIC_DECISIONS.md').read_text()
        question_section=decisions.split('## Remaining scientific questions\n',1)[1].split('## Inference limits',1)[0]
        questions='\n'.join(line for line in question_section.splitlines() if line.startswith('|'))
        if not questions: raise ValueError('Scientific decision register has no remaining-question table.')
        write_csv(out/'artifacts.csv',artifacts)
        meta=dict(mode=mode,built_at_utc=stamp,run_id=run.get('run_id','snapshot-'+stamp),input_manifest_sha256=ih,source_manifest_sha256=sh,result_manifest_sha256=rh,
            publication='staged and validated before replacement',chronology='validated stored posteriors; no MCMC in reporting')
        (out/'build.json').write_text(json.dumps(meta,indent=2)+'\n')
        validation=('The analysis checks passed, including paired exclusions, chronology, climate matching, tracking arithmetic and figure outputs. Stored chronologies were unchanged.' if fresh else 'This snapshot uses verified existing analysis outputs, including stored CCA summaries and permutation tests. It does not represent a new full analysis run.')
        validation+=' [Checks and rebuilding instructions](WORKFLOW.md#tests-and-decisions).\n'
        status=f'**{"Rebuilt analysis" if fresh else "Snapshot of existing outputs"} · {stamp[:10]}.** '
        status+=('Current results and diagnostics were refreshed; chronology figures use the existing stored models.' if fresh else 'Figures and CCA summaries use verified existing analysis outputs.')
        values=dict(table_blocks,**fig_blocks,**text_blocks,build_status=status,questions=questions,validation=validation,workflow_scripts=script_map(),
            diagnostic_inventory=mdtable(inventory,[('diagnostic','Diagnostic PDF'),('purpose','Purpose'),('producer','Script'),('pages','Shown pages'),('status','Analysis or sensitivity')]))
        for sec,block in diagnostic_blocks.items(): values[sec+'_diagnostics']=block
        text=TEMPLATE.read_text()
        for key,val in values.items(): text=text.replace('{{'+key+'}}',val)
        unresolved=re.findall(r'{{[^}]+}}',text)
        if unresolved: raise ValueError('Unresolved narrative template fields: '+str(unresolved))
        text=re.sub(r'\n{3,}', '\n\n', text)
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
