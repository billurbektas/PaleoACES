# Survey years and climate windows

> **Documents:** Sources of every legacy and resurvey date (data/MORA/, data/NOCA/), which set the modern climate windows.  
> **Used by:** `R/helpers/survey_years.R`, `R/pipeline/01_clean_mora_vegetation.R`, `R/pipeline/02_clean_noca_vegetation.R`, `R/pipeline/04_modern_climate.R`  
> **Originally:** `data/SOURCES_SURVEY_YEARS.md` (moved into the report on 2026-11-09)

These notes identify the survey-date evidence and the climate years used for
modern forest plots. Paleo dating sources remain in [MORA chronology notes](03_chronology_sources_MORA.md)
and [NOCA paleo notes](03_chronology_sources_NOCA.md).

## Current decision — 2026-10-07

Historical climate remains **1979–1989 at both sites**. For each modern plot,
use the **adult resurvey year Y** and average **Y−5 through Y, inclusive**.
These six years represent the interannual climate dynamics experienced by the
community before and during its survey. A 2014 visit uses **2009–2014**, including
December 2008 for winter 2009. Every modern season must have six complete years.

| Site | Selected adult year | Climate years | Analyzed paired plots |
|---|---|---|---|
| MORA | 2014 | 2009–2014 | 50 |
| MORA | 2015 | 2010–2015 | 174 |
| MORA | 2016 | 2011–2016 | 47 |
| MORA | 2017 | 2012–2017 | 11 |
| MORA | 2018 | 2013–2018 | 7 |
| MORA | 2019 | 2014–2019 | 41 |
| NOCA | 2014 | 2009–2014 | 50 |
| NOCA | 2015 | 2010–2015 | 225 |

The 331 prepared MORA plots include one additional 2015 plot excluded from the
paired comparison by CCA eligibility. NOCA has 305 prepared pairs and 275 modeled
pairs. Counts above refer to the modeled comparison, not all supplied records.

Climate elapsed time is **(Y−2.5)−1984**: 27.5–32.5 years at MORA and
27.5–28.5 at NOCA. Vegetation elapsed time is Y−1977.5 at MORA and Y−1983 at NOCA.
Both denominators are calculated per plot before summarizing rates.

## Before and after

**Before this update:** every MORA modern plot used 2010–2019 (midpoint 2014.5),
and every NOCA modern plot used 2010–2015 (midpoint 2012.5). MORA pooled adult
and seedling presence across visits and assigned the minimum tree/seedling year.
Those choices could include climate after an individual survey and could merge
different vegetation visits.

**After this update:** adult dates determine modern climate and vegetation time.
MORA seedlings are matched to adult visits first; the latest adult year is then
selected at the 13 plots surveyed in multiple years. Earlier adult and seedling
records are discarded. Same-year visits remain pooled because the supplied tree
CSV does not consistently identify their individual dated visits.

[The 13 selected visits](../tables/mora_repeat_visits.csv),
[verified seedling visit mappings](../../data/MORA/resurvey_seedling_visit_mapping.csv) (and,
at the time of the decision, a measured before/after comparison, now retired; see git history)
make the treatment explicit. Received CSVs are unchanged. The active cleaner
exports every assigned year and discarded row to
`output/MORA_resurvey_record_audit.csv` and summarized visits to
`output/MORA_resurvey_visit_audit.csv`.

## MORA source-year discrepancies

The [curated 95-plot table](../../data/MORA/resurvey_year_source_discrepancies.csv) names all
affected supplied IDs/original plot names, flags the **48 baseline analyzed
pairs**, and gives conflicting years, source rows, adult dates and treatment.
There are **94 standardized IDs plus the unassigned practice plot PRAC-1**.
Seedling discrepancies occur at 85 supplied plot names (46 analyzed), understory
at 93 (46 analyzed); their overlap is 83 supplied names (44 analyzed).
Understory data provide independent date evidence but are not an input to this
analysis's tree presence.

The original CSVs in `Downloads/dissimilarityPNW-main` already contain these
conflicting years. Its `01_CleanMORA.R` reads the original CSVs and writes the
cleaned CSVs without changing their Year columns. Those cleaned CSVs are
byte-identical to the received PaleoACES copies. The earlier process that
exported those original CSVs is unavailable, so its cause is **unknown**.
`tools/audit_survey_year_sources.R` reproduces the comparison against the local
Master2019 workbook and dated plot-name notes; it distinguishes repeat visits
from demonstrated inconsistent labels.

For example, `ABOV-410` is labeled 2018 in the original/cleaned seedling CSV
(line 754) and understory CSV (first record line 10528). The adult records are
2019 (first record line 23080). Master2019's Seedlings sheet (row 743), Veg Data
sheet (first row 10277), and dated Plots record (2019-07-25) support 2019.
The cleaning code assigns the seedlings to the adult 2019 visit, giving climate
2014–2019. `RAMP-505` and `RAMP-506` require their original FIELD/FIELD-2 visit
names because the seedling year labels are swapped; date correction therefore
occurs **before** latest-visit filtering.

## Historical reference retained

MORA's legacy vegetation reference is **1975–1980**, represented by 1977.5,
from the previously adopted Torres draft; NOCA's is **1983**, from Wilson 2024.
The Torres draft and primary legacy-date records are not filed locally.
The legacy workbook metadata says approximately 1975, while its filename says
1978 and the handbook calls the files Original 1978–1983 Data. No per-plot
legacy dates are supplied. This is a source-verification limitation; the
adopted historical references are unchanged.

The common 1979–1989 climate window was adopted on 2026-08-13 because CHELSA V2.1
precipitation begins in 1979. The earlier six-year legacy rule left MORA with
one complete usable year. The retained window samples interannual variability,
while assuming that 1979–1989 represents the unavailable earlier climate. It
includes post-survey years, an explicitly accepted historical limitation.
Missing January 1979 temperature and absent December 1978 precipitation leave
**10 complete winters and 11 springs/summers**. Historical occurrence records,
climate summaries and their uncertainty are not changed by this update.

The earlier site-wide modern windows and their published 2026-08-14 anomaly
numbers are superseded. The current diagnostic evaluates each plot's actual
window against its own 1979–2021 series and then summarizes survey-year cohorts.
Detrending assesses unusual conditions relative to that recent record; it does
not establish CHELSA precipitation continuity. Possible post-2010 MORA
precipitation inhomogeneity still requires independent validation.

## NOCA — Wilson et al. 2024, and nothing else

**Legacy = 1983.** From `related_publications/Wilson_2024.pdf` — Wilson, Kopp, Hille Ris
Lambers & Angert (2024), *Fire sparks upslope range shifts of North Cascades plant
species*, **Ecology 105(3): e4242**. This is the team that relocated and resurveyed these
exact plots. It states 1983 four times:

- p.2 — *"These plots, originally surveyed in 1983, encompass a wide range of elevations (162–2122 m)"*
- p.3, Fig. 1 caption — *"between historical (1983) and contemporary (2014–2015) surveys"*
- p.3 — *"Since the original survey in 1983, annual area burned has greatly increased through time for the eastern Cascades"*
- p.4 — *"Sampling methods were designed to be analogous to the 1983 survey (Agee & Kertis, 1987; J. K. Agee, personal communication, July 20, 2014)"*

Internal consistency check: p.2 describes *"a 32-year period of warming and drying"*;
1983 + 32 = 2015 ✓

**Present = 2014–2015.** Wilson 2024 p.4 — *"We resurveyed 60 plots from July to August
2014 and resurveyed the remaining 314 plots from May to September 2015"* — corroborated
by `data/NOCA/NOCA_plots_fromWilson.csv`, column `Resurvey.Year`: 2014 (69), 2015 (309).
The paper's 60+314 = 374 and the CSV's 69+309 = 378 differ by 4 plots; immaterial for a
climate window.

### Conflicting evidence for the NOCA legacy year — decision is to use Wilson only

| source | says | note |
|---|---|---|
| **Wilson et al. 2024** (adopted) | **1983** | published text, ×4, from the resurvey team |
| `data/NOCA/NOCA_plots_fromWilson.csv` | 1980 | the legacy column is literally named `1980.Plot.Name` — Wilson's *own file* disagrees with her paper |
| `data/raw/AGEEDATA_NEW.xlsx`, MetaData sheet | "1986 (and before)" | *"These data were collected 1986 (and before) by NPS (Jim Agee)"*; the workbook has **no survey-year field in any sheet** |
| `data/NOCA/CascadeLegacyProjectHandbook_2019.docx` | 1978–1983 | folder described as *"Original 1978–1983 Data"* |
| Agee & Kertis 1987 (`related_publications/Agee_1987.pdf`) | — | describes the 425 reconnaissance plots but **never states field years**; received 1986-08-05 |

**Decision: 1983, on Wilson alone.** The active common legacy window is
**1979–1989**, so it includes both candidate years, 1980 and 1983. The
`1980.Plot.Name` conflict therefore does not change the climate window under the
current rule; the older antecedent-only alternatives are retained above only as
superseded history.

⚠ An earlier note in this project claimed *"NOCA 1983 was wrong — it came from the CHELSA
climate window centre (1983.5), not from any survey record"*. **That is superseded**;
1983 is Wilson's published figure.

## CHELSA units — checked against the official documentation, 2026-08-13

Sources: [chelsa-climate.org/datasets](https://www.chelsa-climate.org/datasets) ·
[CHELSA V2.1 technical specification](https://os.zhdk.cloud.switch.ch/envidat-doi/10.16904_envidat.228/chelsa_file_specification.pdf) ·
[CHELSA-TraCE21k model page](https://www.chelsa-climate.org/models/chelsa-trace21k)

| product | variable | documented unit | scale | offset |
|---|---|---|---|---|
| V2.1 | `pr` | `kg m-2` (= mm) | 0.1 | 0 |
| V2.1 | `tasmax` / `tasmin` | °C | 0.1 | −273.15 |
| TraCE21k | `pr` | `kg m-2 month-1` (= mm/month) | — | — |
| TraCE21k | `tasmax` / `tasmin` | **K** | — | — |

The spec warns that the embedded scale/offset are stated *"(only for climatologies)"* and
that *"GDAL 2.2 or higher is required to read the offset and scale correctly … In that
case it has to be applied manually."* **Both were verified empirically** rather than
assumed: Jay Bath `AP` = 2936 mm/yr and V2.1 `pr` ≈ 221 mm/month at the ponds are correct
for the Cascades at ~1500 m (a missed ×0.1 would read 29,360 mm/yr), and TraCE21k returns
°C, so `to_celsius = TRUE` is converting from Kelvin as documented.

⚠ The TraCE21k page numbers time steps from *"t=0 being the LGM"*, whereas `get_chelsa()`
uses signed ids −200…20 with **20 = present**. The two schemes are not reconciled
term-by-term; instead slice 20 was verified directly — it reconciles to the V2.1
1979–2021 mean at the same pixels, and slices 21/22 are 404 for every variable.

Reproducible check: `R/diagnostics/test_paleo_anthro_climate_match.R`.

## Historical product-coverage comparison

The table below refers to the superseded six-year windows and is retained only to
explain why the current common V2.1 windows were adopted. It is not an active
download specification.

Coverage verified 2026-08-12 by HTTP HEAD against the server, not from documentation —
the two CHELSA V2.1 variable groups have **different ranges**:

```
CHELSAcruts   (monthly)       1901        - 2016
V2.1 tasmin/tasmax (daily)    1941-01-01  - 2025-09-30
V2.1 pr            (daily)    1979-01-01  - 2019-12-31
```

| window | tasmin / tasmax | pr |
|---|---|---|
| MORA legacy 1975–1980 | ✅ V2.1 (1975–78 daily) | ⚠️ 1979–1980 only, 2 of 6 yr |
| MORA present 2014–2019 | ✅ V2.1 monthly | ✅ V2.1 monthly |
| NOCA legacy 1978–1983 | ✅ V2.1 (1978 daily) | ⚠️ 1979–1983, 5 of 6 yr |
| NOCA present 2010–2015 | ✅ V2.1 monthly | ✅ V2.1 monthly |

**Temperature is V2.1 throughout — no splice.** Precipitation is V2.1 everywhere it
exists; both historical legacy windows lose their pre-1979 year(s). The active
1979–1989 window avoids a product splice; the two products are **not** interchangeable for precipitation
(V2.1 is +69–74% wetter in July and correlates with cruts at only r = 0.59–0.81 across
plots, versus 0.96–0.99 for temperature — see `R/diagnostics/test_chelsa_cruts_vs_present.R`).


---

## Pond coordinates — audited and corrected 2026-08-13

The four coring ponds are the Holocene arm's entire climate signal, so their coordinates
were traced to source. CHELSA is 30 arcsec (~700 m E–W here), so precision below ~1 km
changes the grid cell.

| pond | coordinate in use | source |
|---|---|---|
| Jay Bath | 46.770463, −121.768404 | **located on satellite imagery** by Billur |
| Log Wallow | 46.775068, −121.753865 | same |
| Reflection Pond 1 | 46.769559, −121.724790 | same |
| Panther Potholes | 48.6588, −121.0395 | **Neotoma site 13042 polygon** (dataset PI's own footprint) |

**All four were wrong before.** The MORA three came from Dunwiddie (1986), who published
only to the **arcminute** — ±928 m in latitude, ±635 m in longitude, i.e. more than one
CHELSA cell — which also placed all three at the *identical* latitude, a rounding artefact.
⚠ **There was no pond at the old Jay Bath coordinate at all** (confirmed on imagery).
Panther Potholes came from Prichard (2009)'s arcminute-rounded `48°39′N, 121°02′W`, 1.1 km
from the true site and in a different cell in both axes; it ran **0.85 °C too cool in every
month**, a constant displacement of 0.171 CCA units.

The MORA ponds are **not** in GNIS, Neotoma or NOAA WDS-Paleo — "Jay Bath" and "Log Wallow"
are Dunwiddie's own informal names — so imagery was the only route. The located coordinates
are corroborated three ways: they reproduce his published arcminutes, they reproduce his
stated inter-pond distances (1.22 / 2.30 / 3.32 km against his 1.2 / 2.4 / 3.5 km), and
they **resolve a contradiction his rounded coordinates carried** — his text says Log Wallow
is NORTHEAST of Jay Bath while the rounded values put it due EAST; the located ponds give a
bearing of 65°, north of east. His prose was right; the rounding was the artefact.

⚠ GNIS **"Reflection Lakes"** (46.7695, −121.7300, 1481 m) is NOT the coring pond — it is
the group centroid, and Dunwiddie specifies the EASTERNMOST pond of that group. Do not
substitute it.

**CRS**: all coordinates are WGS 84 decimal degrees (EPSG:4326), verified directly from a
CHELSA GeoTIFF header (EPSG:4326, 0.008333°). Google Maps reports the same. **No
reprojection is needed or applied anywhere in this pipeline.**

The full pond series was re-downloaded on the corrected coordinates (462 chunks); the
pre-correction cache is archived as `output/archive/chelsa_paleo_OLDCOORD_20260813/`.
