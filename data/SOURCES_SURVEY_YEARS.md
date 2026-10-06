# Survey years and climate download windows

Provenance for the Anthropocene survey dates and the climate window each one gets.
The operative windows are summarized in `docs/SCIENTIFIC_DECISIONS.md`; **this file is the record of
where the numbers come from.** Paleo core chronologies are in `Cores/SOURCES_MORA.md`
and `data/NOCA/NOCA_paleo/SOURCES.md`.

Settled 2026-08-12.

## The rule — CURRENT, decided 2026-08-13

> **past** = the earliest year the data exist → **1989**
> **present** = **2010** → the last vegetation survey year at that site

| dataset | vegetation collected | source of that date | **climate window** | width |
|---|---|---|---|---|
| **MORA legacy** | 1975–1980 | Agostina Torres draft | **1979–1989** | 11 yr |
| **MORA present** | 2014–2019 | Agostina Torres draft | **2010–2019** | 10 yr |
| **NOCA legacy** | 1983 | Wilson et al. 2024 only | **1979–1989** | 11 yr |
| **NOCA present** | 2014–2015 | Wilson et al. 2024 | **2010–2015** | 6 yr |

### Why

The previous rule — the survey year and the five before it — left **MORA legacy with one
usable year**. V2.1 has no precipitation before 1979; month-level alignment therefore
pinned temperature to 1979 as well; and the missing Jan 1979 then killed winter 1979.

**One year is not a climate — it is a single draw from a distribution**, and 1980 was a
wet, cool one. Measured consequence (`R/diagnostics/test_climate_change_variables.R`): MORA winter
warming read **+0.84 °C** off that one year against **+0.28 °C** off five — overstated
threefold — and MAT read +1.26 against +2.03.

Running from the earliest available year to a common 1989 end gives **~10 usable years at
both sites**, so the legacy climate estimates a *climate* rather than a *year*, and
**interannual variability is actually sampled**. The assumption being bought is that
interannual variability in 1979–1989 resembles that of the years before 1978, which
cannot be measured — a far smaller assumption than characterising a site from one year.

The present window starts at a fixed 2010 for the same reason, and ends at the last
vegetation survey year so the climate never post-dates the vegetation it is paired with.

### Two trade-offs, both accepted

1. ⚠ **This abandons antecedent-only** (the 2026-08-12 rule, below). 1979–1989 runs 9 yr
   past MORA's 1980 survey and 6 yr past NOCA's 1983, so it includes years that cannot
   have influenced the vegetation recorded. Accepted: the alternative is a one-year climate.
2. ⚠ **The two present windows now differ in length** — MORA 10 yr, NOCA 6 yr — because
   each is anchored to its own last survey year. Against that, the **past window is now
   identical at both sites**, which is a gain: the legacy climate describes the same
   period at the two sites being differenced.

### Coverage

V2.1 monthly starts 1979-01 and there is no V2.1 precipitation at all before then, so the
window cannot start earlier while precipitation is a CCA constraint. The 1978 lead-in
December is fetched for temperature from the daily product but alignment drops it
(precipitation has no 1978), so **winter 1979 is lost and the winter record runs
1980–1989 — 10 complete winters at both sites**, against 1 at MORA before.

If a sensitivity drops precipitation, temperature alone could reach back to **1941** via the
daily product.

---

### Superseded rules, kept as the record

**2026-08-12 — "max survey year and the five years before it", antecedent-only.** All four
windows 6 yr: MORA 1975–1980 / 2014–2019, NOCA 1978–1983 / 2010–2015. Rationale was that
climate *after* a survey cannot have influenced the vegetation it recorded, and that a ±
window straddles each site's survey by a different amount. Sound in principle; it failed in
practice only because precipitation's 1979 start truncated MORA's legacy to a single year.

**Earlier — ±2 yr around the survey.** Superseded by the above.

## Were the survey windows climatically representative? — RECOMPUTED 2026-08-14

`R/diagnostics/test_survey_year_anomaly.R` locates each window in the full V2.1 record (1979–2021) at
all 638 current plots (331 MORA + 307 NOCA), three ways. The third is the one that counts: a naive comparison against the
whole-record mean confounds "unusual" with "early in a warming record", so the series is
**detrended** first.

✅ **The summer-temperature bias that the old windows carried is GONE.**

```
detrended z, MST      OLD windows (6 yr)          NEW windows (1979-1989 / 2010-)
MORA        past -0.88 -> present +1.31    past +0.76 -> present -0.26
NOCA        past -0.23 -> present -0.65    past +0.76 -> present -0.65
```

The old finding — *"MORA's legacy window was cool even for around 1980 and its present
window warm even for the 2010s, so MORA reads as warming twice as fast as NOCA"* — **no
longer holds**. The two legacy windows are now the same years, so they sit at the identical
point in each site's distribution (+0.76 at both), and MORA's present window is 10 yr rather
than 6, so the 2014–15 heat no longer dominates it. **Temperature is now unremarkable at
every window** (|z_detrend| ≤ 0.76 across all eight site × era combinations).

⚠ **Everything still flagged is precipitation.** Detrended |z| > 1:

```
NOCA present  SpP  +2.26  (97th)     <- the standout; survived the window change
MORA past     AP   -1.30  ( 6th)
NOCA past     AP   -1.24  ( 9th)     <- same years as MORA past, so this pair CANCELS
NOCA present  WP   -1.15  (16th)        in the site contrast
```

Four flags, four precipitation, zero temperature.

⚠ **A separate and more serious precipitation problem.** The MORA/NOCA annual-precipitation
ratio is stable at **1.43 ± 0.12** across six consecutive 5-yr blocks (1979–2009) and then
breaks to **1.10** (2010–2021); Welch t = 6.13, **p = 1.8e-05**. Over the same period the
sites' temperature offset is unchanged (+0.18 °C before and after, p = 0.99). Two sites
200 km apart do not decouple in precipitation while staying coupled in temperature — this
looks like an **inhomogeneity in CHELSA V2.1 precipitation around 2010**, and MORA's present
window (2010–2019) lies entirely after it. The decline is uniform across elevation bands
(−7.4 to −7.9%/decade in all four), so it is not an orographic-downscaling gradient.
**Treat MORA's Anthropocene `WP`/`SpP` change as suspect.**

Results: `output/test_survey_year_anomaly.csv`, figure in `plot/test_figures/`.

## MORA — Agostina Torres draft

📌 Both MORA rows come from the **Agostina Torres draft**. They were taken from that
draft, not derived in this repo. **The draft is not filed in `related_publications/` —
add it, and confirm both windows against it.**

Two things in this repo disagree with those windows and are recorded here so the
disagreement is not lost:

- **Legacy.** The Metadata sheet of `data/raw/MORA_Cascade Legacy Data_Original1978.xlsx`
  says *"These data were collected ~ 1975 by NPS (under the leadership of Jerry
  Franklin)"* — one hedged sentence, contradicted by the `1978` in its own filename and by
  the Cascade Legacy handbook's *"Original 1978–1983 Data"*. There is **no per-plot survey
  date anywhere** in the legacy data (the "Site info" sheet carries only Plotno, Lat/Lon,
  UTM, Elevation, Slope, Aspect, PRISM climate, Plotarea). The
  `Franklin_MORAplots_notes.doc` that the metadata points to is not in the repo, nor is
  the underlying publication, **Franklin et al. 1979**, *Forest ecosystems of Mount
  Rainier National Park*. The Torres window 1975–1980 spans both candidate dates, which
  is its virtue.
- **Present.** The files the pipeline actually reads
  (`data/MORA/MORA_TreeData_Resurvey_Cleaned.csv`,
  `MORA_Seedlings_Resurvey_Cleaned.csv`) have `Year` running to **2020**:

  ```
  2014(57)  2015(180)  2016(48)  2017(14)  2018(25)  2019(73)  2020(3)
  ```

  The three 2020 IDs (`MB-2007`, `MB-2013`, `RP-1010`) are not members of the
  paired `output/MORA_occ.csv` universe and therefore never enter the CCA or tracking
  tables. The 330 analyzed MORA resurvey pairs span 2014–2019, so the active
  2010–2019 climate window matches the analytical universe. This is enforced by
  `R/tests/test_cca_tracking_metrics.R`.

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
