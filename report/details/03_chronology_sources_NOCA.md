# Panther Potholes (NOCA paleo) — provenance of every number

> **Documents:** Sources for the Panther Potholes data in data/NOCA/NOCA_paleo/ (chronology, macrofossils, charcoal).  
> **Used by:** `R/pipeline/05_age_depth_models.R`, `R/pipeline/09_fire_records.R`  
> **Originally:** `data/NOCA/NOCA_paleo/SOURCES.md` (moved into the report on 2026-11-09)

Site: **Panther Potholes**, Fourth of July Pass, North Cascades NP, 48°39'N 121°02'W,
1100 m (Prichard et al. 2009) / 1033 m (Neotoma `altitude`). One core, 978 cm,
1-cm contiguous sections, taken **1999** (see "Coring year" below).

## Files in this directory

| file | what it is | where it came from |
|---|---|---|
| `dataset52207_site13042.csv` | plant-macrofossil counts by taxon × sample, plus `Depth` and the `Gavin 2021` age column | Neotoma Explorer download of dataset 52207 (obtained before this repo; used by `R/pipeline/06_paleo_samples.R`) |
| `neotoma_chronology_52207_gavin2021.json` | the **complete** Gavin 2021 chronology record — Bacon settings string, contact, date prepared, all 15 chron controls, plus the site note | Neotoma API v2.0, retrieved **2026-08-07** (endpoints recorded in the file's `api` field) |
| `neotoma_chroncontrols_52207_gavin2021.csv` | the 15 chron controls, tidied from the JSON above | derived from the JSON, same retrieval |

Re-fetch with:

```bash
curl -s "https://api.neotomadb.org/v2.0/data/downloads/52207"   # chronology + controls
curl -s "https://api.neotomadb.org/v2.0/data/datasets/52207"    # site metadata + sitenotes
```

## Primary publication

**Prichard, S.J., Gedalof, Z., Oswald, W.W., Peterson, D.L. (2009)** *Holocene fire and
vegetation dynamics in a montane forest, North Cascade Range, Washington, USA.*
Quaternary Research 72:57–67. doi:10.1016/j.yqres.2009.03.008. PDF in repo root.

- Table 1a — three tephras (glass chemistry, F. Foit, WSU)
- Table 1b — six AMS ¹⁴C dates (Beta Analytic)
- Table 1c — ²¹⁰Pb, CRS model (Flett Research Ltd., Winnipeg)
- Fig. 2 — their published age model: a locally weighted regression,
  `age = 8.727x + 0.0047x² − 183.6`, r² = 0.9966

## ⚠ The published depths are wrong — do not use Table 1a/1b depths

Neotoma's site note states:

> *"See geochronology notes about errors in **sample depths and tephra depths** in
> publication and Neotoma, corrected November 2021."*

Prichard's own Results text contradicts their Table 1b: it reports the basal date
*"at **864** cm"* and the youngest *"at **214** cm"*, where Table 1b says 972 and 219.
**The Results text agrees with Neotoma; Table 1b does not.**

| lab no. | Table 1b depth | corrected depth | shift |
|---|---|---|---|
| Beta-172005 | 219 | **214** | −5 |
| Beta-169623 | 378 | **363** | −15 |
| Beta-169624 | 404 | **389** | −15 |
| Beta-169207 | 504 | **479** | −25 |
| Beta-169208 | 756 | **678** | −78 |
| Beta-169625 | 972 | **864** | −108 |

Tephras were corrected too: Mazama is **623–635** (12 cm), not Table 1a's 623–639.
MSH P (303–308) and MSH Y (396–406) are unchanged.

Two consequences worth knowing:

1. Evaluating the Gavin model at Table 1b's depths makes it look like it rejects
   Beta-169208 by ~880 yr. At the corrected depth it fits (−148 yr). There is no
   conflict; the depths were the problem.
2. Beta-169624 appears to sit *inside* the MSH Y tephra (404 vs 396–406). At its
   corrected depth of 389 cm it is 7 cm above the ash. Keep it.

## Ages: what each control is and where the number comes from

All from `neotoma_chroncontrols_52207_gavin2021.csv`. Ages are as Gavin entered
them for Bacon: **radiocarbon controls are uncalibrated ¹⁴C yr BP** (Bacon
calibrates them, `cc = 1`); everything else is **calendar cal yr BP** (`cc = 0`).

### Radiocarbon — Prichard Table 1b, corrected depths (cc = 1)

| depth | ¹⁴C yr BP | ± | lab no. | material (Table 1b) |
|---|---|---|---|---|
| 214 | 1950 | 50 | Beta-172005 | conifer seed |
| 363 | 3260 | 40 | Beta-169623 | seed |
| 389 | 3520 | 40 | Beta-169624 | pollen cone |
| 479 | 4500 | 40 | Beta-169207 | pollen cone |
| 678 | 7330 | 40 | Beta-169208 | seed |
| 864 | 9370 | 40 | Beta-169625 | needle fragments (*Pinus contorta*) |

Ages and errors match Table 1b exactly; only the depths differ.

### Tephra — identified by glass chemistry, dated from the literature (cc = 0)

| depth (mid) | thickness | cal yr BP | ± | tephra | note |
|---|---|---|---|---|---|
| 305.5 | 5 (303–308) | 2620 | 70 | Mount St Helens set P | Gavin's value. **Not** Prichard's 2590–3184 (mid 2887), which is the calibration of the broad 2500–3000 ¹⁴C literature range for set P. |
| 401 | 10 (396–406) | 3660 | 65 | Mount St Helens set Y | Same eruption as MORA's `Tephra_Y` (3650 ± 100 in `R/pipeline/05_age_depth_models.R`). The two sites agree to 10 yr independently. |
| 629 | 12 (623–635) | 7633 | 25 | Mazama climactic | Matches Egan et al. 2015 (7584–7682 cal BP, 2σ) and Zdanowicz et al. 1999 (7627 ± 150). Prichard's stated 7610–7690 also agrees. |

Similarity coefficients for the glass-chemistry correlations (Prichard Table 1a):
MSH P 0.99, MSH Y 0.97, Mazama 0.99.

### Core top and ²¹⁰Pb (cc = 0)

Prichard Table 1c reports ²¹⁰Pb ages as **years before coring**, not cal BP. The
conversion is `cal BP = yr_before_coring − 49`, i.e. coring in **1999**. Derived
two ways that agree: Gavin's core-top control is −49 cal BP (= 1999 CE), and a
1999 coring year reproduces all five of Gavin's ²¹⁰Pb controls to RMSE 1.0 yr
(1998 → 1.7, 2000 → 1.1, 2001 → 1.8).

| depth | Table 1c "modeled date" (yr before coring) | cal yr BP | error Gavin used |
|---|---|---|---|
| 0.5 (core top) | 0 | −49 | 1 |
| 7 | 12.3 | −36.7 | 3.47 |
| 14 | 40 | −9 | 1.15 |
| 21 | 61 | 12 | 0.72 |
| 28 | 70 | 21 | 0.74 |
| 35 | 85 | 36 | 0.77 |

#### ⚠ Those errors are Table 1c's **activity** errors, not age errors

Prichard Table 1c has no age-error column. Its `Error (1σ)` is on **total ²¹⁰Pb
activity in DPM/g**. Gavin's age errors are numerically identical to it:

```
depth        7     14     21     28     35
Gavin (yr)   3.47   1.15   0.72   0.74   0.77
T1c (DPM/g)  3.47   1.15   0.72   0.74   0.77
```

A DPM/g standard error is not a year. The effect is that the top 35 cm of the
published chronology has a 95% width of **8 yr** against **417 yr** (median) for
the core as a whole — precise by construction, not by evidence.

Two further reasons to distrust the deep end of that ²¹⁰Pb profile: total activity
runs 32.55 → 8.30 → **2.68 → 3.22 → 3.76** DPM/g at 7/14/21/28/35 cm, i.e. it stops
declining and drifts *up* below ~21 cm, so unsupported ²¹⁰Pb is exhausted and those
CRS ages are extrapolations past the method's limit. And Table 1c leaves the
topmost sample (3 cm) undated (`na`).

## 🔶 ASSUMED VALUES — the only numbers here that come from no source

Everything else in this file is traceable to Prichard 2009, Neotoma, or a tephra
reference. **The ²¹⁰Pb age errors in the sensitivity run are not.** They are our
assumption, and they are the one thing in the NOCA chronology a reviewer should be
told is invented.

**Why they cannot be sourced.** Proper CRS age-error propagation needs supported
²¹⁰Pb, dry bulk density and sample mass. None of the three is published — Table 1c
gives total activity and its counting error only. The Flett Research report or
Prichard's 2003 PhD thesis would have the real values; **asking for either would
retire this assumption entirely.**

**The value: one flat ±10 yr.** `PB210_ASSUMED_ERROR` in `R/pipeline/05_age_depth_models.R`.
That is the entire assumption — a single number, an order of magnitude above the
0.72–3.47 yr the published model used, and typical of CRS age uncertainty.

**Why a constant and not an age-proportional rule.** An earlier version used
`max(5, 0.25 × age)`, on the argument that CRS errors grow downcore as unsupported
²¹⁰Pb decays toward background. That argument is *correct* — it produces a widening
envelope where a constant produces a flat one:

| 95% width (yr) at | 7 cm | 14 cm | 21 cm | 28 cm | 35 cm |
|---|---|---|---|---|---|
| published | 12 | 6 | 5 | 4 | 12 |
| proportional 5/10/15/18/21 | 20 | 30 | 37 | 44 | 62 |
| constant ±10 | 28 | 32 | 30 | 30 | 36 |

— but it is **irrelevant to the only question this run exists to answer**, and it is
harder to defend. All four assumptions were run:

| assumption | 95% width, top 35 cm | 35–214 cm | below 214 cm |
|---|---|---|---|
| published (activity errors) | **7** | 436 | 417 |
| constant ±10 | **30** | 441 | 422 |
| proportional | **34** | 437 | 416 |
| constant ±15 | **39** | 439 | 419 |
| constant ±20 | **46** | 438 | 418 |

**The result is the range, not any single value: 7 → 30–46 yr in the ²¹⁰Pb section,
with similar deeper chronologies.** Earlier shape comparisons reported median differences of ≤11 yr; the stored primary versus ±10-year comparison finds a maximum deeper median difference of 15 yr and lower/upper-bound differences of 24/28 yr. That bounded statement is what should be reported — it does not
depend on choosing a number, which is exactly why the simplest assumption is the
right one to carry.

Reproduce the other rows by setting `PB210_ROBUSTNESS = c(15, 20)`; off by default
because each is a full MCMC. Runs are kept in `Cores/PantherPotholes_pbconst*/`.

**Where it is printed:** `R/pipeline/05_age_depth_models.R` prints published vs assumed errors
side by side on every run and labels the sensitivity-figure legend
*"assumed: flat ±10 yr age error"* — **not** *"corrected"*, which would claim a
knowledge of the true value that we do not have.

**Scope.** Only the `PantherPotholes_pb210err` run. The primary run keeps Gavin's
published values, so the reproduction claim is untouched.

The assumed-error sensitivity widens near-surface age uncertainty; the deeper
chronologies remain similar rather than identical. It does not recover the true
CRS age uncertainty. Figure:
`plot/test_figures/fig_bacon_pb210_sensitivity.pdf`.

## Figures

| figure | what it shows |
|---|---|
| `plot/test_figures/fig_bacon_agedepth_slump.pdf` | rbacon `agedepth()` output for all four cores (JayBath, LogWallow, ReflectionPond, PantherPotholes), 2 × 2 |
| `plot/test_figures/fig_bacon_pb210_sensitivity.pdf` | published vs **assumed** ²¹⁰Pb errors — whole core (similar deeper chronologies) and a top-40 cm zoom |

Both are produced by `R/pipeline/05_age_depth_models.R`. Its figure section redraws from
the **stored** runs and never
re-runs the MCMC. Note it snapshots and restores each `.out` first: `Bacon(run =
FALSE)` can thin a stored chain down to its own `ssize`, so drawing a figure would
otherwise silently destroy iterations (it cut 10000 → 4000 the first time).

## Why we re-run Bacon rather than use the published ages

Gavin 2021 **is** a Bacon run (`agemodel: "bacon"`, settings string in the JSON) and
its chronology is sound. But Neotoma publishes only three quantiles per level
(`older/median/younger`), and every metric in this project is measured **over an
interval** — Δclimate, Δvegetation, Δoffset from t₁ to t₂, with `dt` in the
denominator. Propagating age uncertainty through those needs whole coherent
chronologies, which is also what R-Ratepol's `age_uncertainty` argument requires:

> *"A matrix with one column per sample and one row per **age sequence drawn from a
> posterior age-depth model**. One row is randomly selected at the start of each
> randomisation run."*

Quantiles cannot be turned back into draws. Tested on JayBath, where both are
available: sampling each level independently from its own quantiles gives **0.000**
monotone chronologies (all 4000 contain an age reversal) against **1.000** for the
true posterior, and destroys the down-core error correlation that keeps `dt` stable
(r = 0.741 true, 0.003 rebuilt).




## Other data taken from this site

- **Plant-macrofossil counts** — `dataset52207_site13042.csv`, `group == "TRSH"`, reduced to
  presence/absence in `R/pipeline/06_paleo_samples.R`. Taxon harmonisation to the MORA/NOCA
  species list is in that script; `Cupressus nootkatensis` → `Callitropsis nootkatensis`.
- **Macrocharcoal** — Neotoma dataset 52210, joined by depth to the same Bacon
  chronology and converted to peaks by `R/pipeline/09_fire_records.R`; Panther Potholes
  contributes directly to `output/paleo_fire.csv`.
- **Lake climate** — CHELSA-TraCE21k at the pond coordinates,
  `output/chelsa_paleo_ponds.csv`, matched to sample ages in `R/pipeline/08_paleo_climate.R`.

---

## Macrocharcoal — Neotoma dataset 52210 (added 2026-08-12)

**Why it was thought missing.** `dataset52207_site13042.csv` contains only the `TRSH`
(trees/shrubs) and `LABO` (chronology) groups, so a grep for charcoal in that file returns
nothing. Charcoal is a **separate Neotoma dataset**, not a group inside the macrofossil one.
Site 13042 (Panther Potholes, handle `PANTHPOT`, collection unit 14577) has four:

| datasetid | type | constituent database | age range |
|---|---|---|---|
| 52207 | plant macrofossil | North American Plant Macrofossil Database | 10760 to -53 cal BP |
| 52208 | geochronologic | North American Pollen Database | — |
| 52209 | pollen | North American Pollen Database | 10744 to -51 cal BP |
| **52210** | **macrocharcoal** | **Neotoma Charcoal Data** | **10760 to -53 cal BP** |

Listed via `https://api.neotomadb.org/v2.0/data/sites/13042/datasets`.

**Retrieved** `https://api.neotomadb.org/v2.0/data/downloads/52210` on 2026-08-12.
Note the samples sit at `data[[1]]$site$collectionunit$dataset$samples`, **not** at
`data[[1]]$dataset$samples` — the latter path exists but is empty, which reads as "no data"
if you stop there.

Stored as:
- `neotoma_macrocharcoal_52210.json` — the API response verbatim
- `neotoma_macrocharcoal_52210.csv` — tidied: `sampleid, depth, thickness, age, ageolder,
  ageyounger, volume_ml, charcoal_150_1000_`

**Contents.** 870 samples, **no NA in any field**. Depths 0.5–869.5 cm, contiguous at 1 cm,
every depth on the 0.5 grid — so `000_PALEO_a`'s Bacon run (`d.by = 0.5`) gives an exact
lookup rather than an interpolation. The 870 depths are **identical to the 870 macrofossil
depths**, so fire and vegetation are measured on the same samples.

Measured variables: `Charcoal`, element `150-1000 µm`, units `number`; and
`Sample quantity`, element `volume`, units `ml`. Concentration = count / volume, ranging
0 to 133.7 pieces/ml.

**Ages: use ours, not Neotoma's.** The `age` column here is Neotoma's chronology (Gavin
2021). Match on **depth** to `000_PALEO_a`'s Bacon output instead, exactly as the
macrofossils do, so vegetation and fire share one chronology and one set of age draws.

**Source publication:** Prichard, S.J., Gedalof, Z., Oswald, W.W. & Peterson, D.L. —
*Holocene fire and vegetation dynamics in a montane forest, North Cascade Range,
Washington, USA*. PDF in `related_publications/`. Dataset PI: Susan J. Prichard.
