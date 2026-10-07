# Occurrence consolidation — what was decided, and on what evidence

Everything here is applied by [`R/stages/000_occurrence_data_consolidate.R`](../../R/stages/000_occurrence_data_consolidate.R),
which reads the three cleaned occurrence tables and writes the single file the
ordination consumes:

```
output/MORA_occ.csv    000_MORA_cleaning.R
output/NOCA_occ.csv    000_NOCA_cleaning.R      ->  output/occ_consolidated.csv  ->  05_cca_model.R
output/paleo_occ.csv   000_PALEO_b_vegetation.R
```

No cleaning script is re-run. This is a pure transformation on their outputs, so
any decision below can be changed and re-applied in seconds.

Settled 2026-08-13.

---

## 1. Removing the understory stratum

### The problem

The study is about **overstory (tree-stratum) communities**. Both legacy surveys
recorded a tree stratum *and* a separate understory/shrub stratum, and both put a
group of tall shrubs and small trees in the **understory** one. Both resurveys then
measured that same group as **trees**. The result was large false colonisations —
species that appear to arrive between surveys only because the second survey
counted them and the first did not:

| species | MORA past | MORA present | NOCA past | NOCA present |
|---|---|---|---|---|
| *Acer circinatum* | **0** | 46 | 2 | 19 |
| *Taxus brevifolia* | **0** | 54 | 6 | 8 |

Both were among the 13 species entering the CCA, so this was not cosmetic.

### How the group was identified

**Not** from `MORA_spp_lib.csv`. That file's `canopy_type` calls `ACCI`, `ACGL`,
`ALSI`, `TABR`, `SOOC` and `PREM` `overstory_full`, which **contradicts the 1978
workbook's own metadata**. The raw survey records and the legacy publication
overrule it. Two independent criteria were used, one per site.

#### MORA 1978 — the workbook states the rule itself

`data/raw/MORA_Cascade Legacy Data_Original1978.xlsx`, sheet `Metadata`, verbatim:

> *"Four letter species codes. **For trees, these numbers represent stem counts;
> for understory plants these numbers represent percent cover**"*
>
> *"For trees; size class 1 (i.e. ABAM1) = established seedlings (trees between 10
> and 140cm), 2 = saplings (dbh 0–20cm), 3 = poles (dbh 20–50 cm) and 4 =
> standards (dbh >50cm)."*

So in sheet `Rainier Veg`, a column with a **trailing digit** (`ABAM1`…`ABAM4`) is a
tree measured in size classes, and a **bare** four-letter column (`ACCI`, `TABR`) is
an understory plant measured as percent cover. The operational test:

> MORA measured species X as a tree **⇔** X has size-class columns in `Rainier Veg`
> **or** X has >0 stems in `rawsizedata`.

| code | size-class cols | bare cover col | rawsizedata stems | verdict |
|---|---|---|---|---|
| ACCI | no | yes | – | **understory** |
| ACGL | no | yes | – | **understory** |
| ALSI | no | yes | – | **understory** |
| TABR | no | yes | **0** | **understory** — code exists, zero stems |
| SOOC | no | yes | – | **understory** |
| PREM | no | yes | – | **understory** |
| SASC | no | yes | – | **understory** |
| CONU | no | yes | – | **understory** |
| ALRU | no | yes | 108 | tree — cover *and* stems, a real tree |
| PIAL | no | yes | 2 | tree |
| POTR | yes | no | 6 | tree |
| PISI | yes | no | 2 | tree |
| ABPR | yes | no | 393 | tree |

#### NOCA 1983 — two strata in the workbook, and the paper says so

`AGEEDATA_NEW.xlsx` has separate **`TREE`** and **`SHRUB`** worksheets. Agee &
Kertis (1987), *Can. J. Bot.* 65:1520–1530, Methods, verbatim:

> *"A dimensioned plot of varying size was used to determine tree density of each
> species by height class (0–3, 3–10, and > 10 m)."*

so `DEN_0-3` / `DEN_3-10` / `DEN >10` are **height classes in metres** and the
`TREE` sheet is the tree stratum. The test is which sheet holds the species:

| code | legacy SHRUB plots | legacy TREE plots | verdict |
|---|---|---|---|
| ACCI | 87 | 2 | **understory** |
| SOSI | 58 | 1 | **understory** |
| ALSI | 28 | 1 | **understory** |
| ACGL | 18 | 5 | **understory** |
| COST | 13 | 0 | **understory** |
| PREM | 9 | 4 | **understory** |
| SARA | 8 | 0 | **understory** |
| ALRU | 2 | 23 | tree — the control |

Agee & Kertis's Table 3 (their published tree list) likewise omits *Acer
circinatum*, *Alnus sinuata* and *Sorbus sitchensis*, and names *Sorbus
sitchensis* among the **"dominant shrubs"**.

### The rule

> **Drop a species if *either* legacy survey positively recorded it in its
> understory/shrub stratum instead of its tree stratum.**

**Absence from one site's legacy is not evidence of understory status** — it is a
real absence. *Betula papyrifera*, *Acer macrophyllum*, *Pinus ponderosa*, *Larix
lyallii* and *Populus balsamifera* have no column at all at MORA and are
tree-stratum species at NOCA; they are **kept**. Conflating "not recorded" with
"recorded as understory" would delete genuine species.

The two criteria are independent — a workbook legend at one site, a separate
worksheet plus a published methods statement at the other — and they agree
wherever both have evidence. That is why this is a finding rather than a choice.

### Species removed, both sites, both eras

*Acer circinatum*, *Acer glabrum*, *Alnus alnobetula* subsp. *sinuata* (and its
synonyms *A. sinuata* / *A. viridis* / *A. crispa*), *Taxus brevifolia*, *Sorbus
sitchensis*, *Cornus nuttallii*, *Cornus sericea* (= *C. stolonifera*), *Sambucus
racemosa*, *Prunus emarginata*, *Salix* spp. (*S. scouleriana*, *S. barclayi*,
*Salix* sp.), *Corylus cornuta*.

**The Holocene arm is untouched** — all 12 macrofossil taxa are conifers plus
*Juniperus communis*, none of them in this group.

---

## 2. Taxonomic harmonisation

### *Populus* → *Populus trichocarpa* (both sites)

One taxon recorded under two names. Agee & Kertis Table 3 lists **"Populus
trichocarpa"** and the legacy code is `POTR`. The resurvey's `POAI` →
*Populus balsamifera* rests only on the Plant List note *"some unknown tree; from
Rachel: POPBAL most likely"*. Merging removes a false extinction (NOCA 8 → 0) and a
false colonisation (NOCA 0 → 2, MORA 0 → 3).

> ✅ **A MORA linkage bug was fixed to make this work (2026-08-13).**
> `MORA_spp_lib.csv`'s only *Populus* row is `past_code = "absent_past" /
> `prst_code = "POPBAL"`, asserting *Populus* was not recorded in 1978. It was:
> `rawsizedata` holds `POTR` in 4 plots (6 stems) and `Rainier Veg` has a `POTR2`
> column. With no `past_code == "POTR"` row the past join returned `NA` and those
> plots were silently discarded, so MORA read *Populus* **0 past / 3 present** — a
> false colonisation of exactly the kind this document exists to remove.
>
> `000_MORA_cleaning.R` now patches `past_code` **in memory**, the same way it
> already patches `TSH4 → TSHE`; **`MORA_spp_lib.csv` is not modified**, because
> the library is shared and this is a code-*linkage* fix, not a taxonomic one. The
> taxonomy stays here in the consolidation script.
>
> MORA now reads *Populus trichocarpa* **3 past / 3 present**. Three of the four
> legacy plots come through; the fourth is not in `MORA_plot_lib`, i.e. not a
> survey–resurvey plot, so dropping it is correct. The consolidation script warns
> if the legacy records ever disappear again.

### *Picea sitchensis* → *Picea engelmannii* (NOCA **present only**)

Sitka spruce was **not a recordable taxon in 1983**. The `AGEEDATA` `SPECIES`
codebook has 494 entries and exactly one *Picea*: `PIEN`. Agee & Kertis Table 3 has
no *P. sitchensis*. So `0 → 7` cannot be a colonisation — the crew had no code for
it.

Two further lines of evidence say these are misidentified Engelmann spruce:

- the 7 resurvey plots are at **966–1691 m, median 1569 m**, far above Sitka
  spruce's coastal, low-elevation range;
- **three of the seven recorded `PIEN` in 1983**, and NOCA's Engelmann plots span
  637–2051 m (median 1349) — exactly this band.

**NOCA present only.** At MORA, `PISI` has its own tree size classes (`PISI2`,
`PISI4`) and stems in `rawsizedata`, so it is a legitimate species there.

### *Abies procera* → *Abies lasiocarpa* (NOCA only)

At MORA *A. procera* is real and abundant — **68 past / 50 present survey plots and
43 Holocene macrofossil samples** — so lumping it there would destroy a genuine
taxon. At NOCA it is 3 resurvey plots (1402–1564 m), absent from the legacy, and
outside the species' main range north of Snoqualmie Pass.

### Unsupported identifications

Records that do not resolve to a supported taxon are removed in the NOCA cleaner
before occurrence and stage construction. They are neither lumped into a named
species nor carried into this consolidation stage.

---

## 3. A code collision to know about

`ALVI` means two different things in the same workbook:

- the **`Plant List`** maps it to ***Allotropa virgata***, a mycoheterotrophic herb;
- the **`Seedlings`** sheet Notes say *"(EDIT: R changed from ALSI to ALVI to
  reflect current scientific name of Alnus viridis)"* — i.e. the **alder**.

Joining the Seedlings sheet to the Plant List would relabel 13 plots of Sitka alder
as a herb. It does not bite us now (the taxon is removed as understory either way),
but any future use of that sheet must hard-code the meaning per sheet.

Related: NOCA cover values include `0.1` and `0.2`, and many rows are annotated
*"all out"*, *"5 out"*, *"97 OUT"* — individuals **outside** the plot. MORA's
metadata defines `0.1 = species present near but not in plot`, `0.2 = trace
amount`. Any future use of the cover data must zero those the way MORA does.

---

## 4. The MORA size-class vs DBH discrepancy — recorded, not re-opened

Carried over from Agostina Torres's manuscript and the script on the PLEC server
(`PLEC/Research/Billur Bektas/PaleoACES/R/000_MORA_original_cleaning.R`); the
in-repo QC is `R/diagnostics/test_MORA_original_cleaning.R`.

Counts for size classes **2–4** in `Rainier Veg` should match the DBH counts in
`rawsizedata`, and they do not. Some of the mismatch was traced (rare species coded
`0.1`/`0.2` for individuals outside the plot), but residual discrepancies remain
with no obvious pattern. The decision:

- **seedlings** (size class 1, 10–140 cm) come from **`Rainier Veg`** — the only
  source for them;
- **adult trees** (height > 1.4 m) come from **`rawsizedata`** — because DBH is a
  secondary measurement and therefore the more reliable record: *you cannot measure
  something that is absent, and where no measurement was taken you cannot be sure
  the tree was present.*

`000_MORA_cleaning.R` already implements exactly this, and consolidation does not
change it.

> **This is what makes the `TABR` verdict above safe.** *Taxus brevifolia* has a
> bare (cover) column in `Rainier Veg` **and appears in `rawsizedata` with zero
> stems**. Under the rule that adults come from DBH, a species with no DBH
> measurement has no adult record — so the "0 → 54" pattern is the expected
> consequence of the source decision, not a separate bug.

---

## 5. Analysis exclusion — *Pinus ponderosa*

**A different kind of decision from everything above**, and kept separate in the
script for that reason. Sections 1–2 are *data quality*: the record is wrong or
unusable. This one is a *modelling choice* about a species whose record is fine.
Switch: `APPLY_ANALYSIS_EXCLUDE`.

*Pinus ponderosa* is a legitimate tree — it is in the NOCA legacy tree stratum and
in Agee & Kertis Table 3. It is excluded because:

- it is effectively **single-site**: 42 NOCA plots (26 past, 16 present) against
  **one** MORA plot, so it encodes site identity more than climate response;
- it is **absent from both Holocene records**, so no paleo sample can ever be
  projected onto the gradient it defines;
- it sat at the **extreme dry end of CCA1** (score 3.51; the next species was 1.31),
  stretching the axis along which every distance in this study is measured. Its
  plots are at 347–1320 m, median **669 m**, against 1037 m for NOCA overall — the
  low, dry east side.

This absorbs the last of the old `_subset` run. *Taxus brevifolia* and *Acer
circinatum*, the other two it excluded by hand, are now removed on evidence by the
understory rule, so **there is one model, not two**.

---

## 6. Historical consolidation diagnostic

The table below records the original consolidation experiment before the 2026
NOCA tree correction and before threshold 20 became the active configuration.
It is retained as provenance and used the former MWT/MST/WP/SpP constraint set;
current model totals are in Section 7.

| | before | understory + taxonomy | + *P. ponderosa* |
|---|---|---|---|
| species in the CCA | 13 | 11 | **10** |
| calibration plots | 623 | 622 | **621** |
| CCA1 / CCA2 share of total inertia | 8.1% / 3.6% | 10.6% / 4.7% | **10.8% / 5.1%** |
| total constrained inertia | 12.7% | 16.6% | **17.3%** |
| paleo samples projected | 963/963 | 963/963 | **963/963** |

Removing the two artefact species **raised the climate-explained fraction by about
4 percentage points**, which is the expected direction: a species whose occurrence
is set by *which survey counted it* cannot be explained by climate, so it was pure
unconstrained noise. Dropping *P. ponderosa* adds a further 0.7.

The old CCA1 description and loadings belong only to that historical run and are
not interpretations of the active ordination.

---

## 7. Choosing `count.thr` — set to 20 (2026-08-13)

The consolidation script now prints the species × site × period count table and a
threshold sweep, and writes `plot/test_figures/species_counts_consolidated.pdf`.
This replaces a removed historical species-count diagnostic, which counted the
**unconsolidated** tables — so it listed species that no longer exist and split taxa
that are now merged.

**Nothing is filtered or decided by this block** — it reports the raw evidence only.
**The threshold default lives in `R/helpers/config.R`** and is consumed by
`05_cca_model.R`; a caller can override it explicitly for a sweep:

```r
for (thr in c(10, 15, 20, 25, 30)) { count.thr = thr; source(here("R/stages/05_cca_model.R")) }
```

The rule there: a species is dropped only if it is below the threshold in **every**
site × period group, so the comparison is against each species' **largest** group
count (`max_group` in the printed table).

The table below records the historical sweep before the 2026-10-06 GPS
exclusion of CARI449/CARI450; alternative thresholds have not been rerun.
The current threshold-20 model has 618 calibration plots and 1,512 positioned
samples. See the [analysis review](../ANALYSIS_REVIEW.md) for its current fit.

| `count.thr` | species | calib plots | positioned | CCA1 | CCA2 | constrained |
|---|---|---|---|---|---|---|
| 10 | 15 | 629 | 1522 | 7.6% | 5.0% | 13.6% |
| 15 | 15 | 629 | 1522 | 7.6% | 5.0% | 13.6% |
| **20** | **13** | **620** | **1514** | **9.3%** | **6.0%** | **16.5%** |
| 25 | 11 | 619 | 1513 | 10.9% | 6.0% | 18.2% |
| 30 | 10 | 619 | 1513 | 12.0% | 6.0% | 19.5% |

Three things worth noting when choosing:

- ⚠ **Do not select on constrained inertia.** It rises mechanically as species are
  removed, because there is less total inertia left to explain. It is not a model-fit
  criterion here.
- **10 and 15 give the identical 15 species** — the distribution is lumpy, so
  only a few values are real decisions. Relative to 20, 10/15 adds nine
  calibration plots and eight positioned samples, because rarer species keep otherwise
  empty plots in the model.
- The 2026 NOCA tree correction raised *Abies grandis* from 19 to 22
  NOCA-present plots before the GPS exclusions. It crossed the threshold of 20, increasing the then-active
  model from 12 to 13 species and from 619 to 620 calibration plots after the
  `BAK487`/`BEAV6061` study exclusions.
- **30 drops *Picea engelmannii***, present in both sites, both eras and both paleo
  records. That is a genuine cross-site species and losing it costs more than it saves.

### *Tsuga heterophylla* — the old hand-exclusion is reversed

It was dropped by hand in `05_cca_model.R` at every threshold from the first version
of this analysis. **It is now kept** (2026-08-13), on three grounds:

1. **It was never justified.** The original model, preserved in Git history, carries the bare line with
   no comment; the former species-count diagnostic also recorded that the
   exclusion was undocumented. The "range truncation, HilleRisLambers et al.
   2015 Appendix B" note previously in `05_cca_model.R` was reconstructed after the
   fact, not inherited from the original author.
2. **The citation does not single it out.** HilleRisLambers et al. 2015: range limits
   were estimated *"for three species (Abies amabilis, Callitropsis nootkatensis,
   Tsuga mertensiana), but not for the three species whose ranges extend to
   elevations below the lowest elevation of the park (Pseudotsuga menziesii, Thuja
   plicata, Tsuga heterophylla)"*. Three truncated species — the script dropped one
   and kept the other two, which are among the most abundant in the dataset.
3. **The data contradict it.** At MORA (lowest plot 541 m):

   | species | min | median | max |
   |---|---|---|---|
   | *Abies amabilis* | 541 | 1189 | 1753 |
   | *Tsuga heterophylla* | 541 | **1091** | 1685 |
   | *Pseudotsuga menziesii* | 541 | 1040 | 1609 |
   | *Thuja plicata* | 541 | 907 | 1430 |

   Four species sit on the lower bound — truncation is a property of where the plots
   stop, not of this species — and *T. heterophylla*'s median is **higher** than two
   of the species that were kept.

The paper's concern is locating a range **edge**, which requires the whole range
sampled. This analysis ordinates **composition**, where a species whose range
continues past the sampled window is ordinary rather than disqualifying.

| threshold 20, corrected data | drop (sensitivity) | keep (active) |
|---|---|---|
| species in the CCA | 12 | **13** |
| total constrained inertia | 16.3% | **16.5%** |
| samples positioned | 1500 | **1514** |

Keeping *Tsuga heterophylla* positions 14 additional samples under the corrected
threshold-20 model. Its position remains mid-cloud rather than an outlier.

> ⚠ Axis sign is arbitrary in ordination. Under the active MSpT/MWT/SP/WP model,
> CCA1 loadings are MSpT −0.53, MWT −0.51, SP +0.17, and WP +0.21: negative
> CCA1 is the warmer/drier end. CCA2 is dominated by the two precipitation
> constraints (SP −0.35; WP −0.38), while its temperature loadings are small.

---

## 8. Adults vs regeneration

The consolidation script also writes
`plot/test_figures/stage_adult_seedling_past_present.{pdf,png}`, absorbed from the
removed historical stage diagnostic. Presence-based — the number of plots a
species occupies at each stage — because the raw counts are in incompatible units
across the four datasets.

This needed the cleaning scripts' **in-memory raw objects**, which is why the old
script `source()`d both of them and rewrote `MORA_occ.csv`, `NOCA_occ.csv` and two
PDFs as a side effect. Fixed: the cleaning scripts now write stage-resolved
companions, one row per plot × species × stage, carrying the same plots and species
as the main tables.

```
000_MORA_cleaning.R  ->  output/MORA_occ_stage.csv
000_NOCA_cleaning.R  ->  output/NOCA_occ_stage.csv
```

Both go through the **same `apply_decisions()`** as the main table, so the stage
figure can never show a species the ordination has dropped (asserted in the script).

### ⚠ Regeneration is not measured the same way in all four panels

| | regeneration | adult |
|---|---|---|
| MORA past | `Rainier Veg` size class 1, **10–140 cm** | `rawsizedata` DBH |
| MORA present | resurvey tallies, **10–140 cm** | resurvey tree records |
| NOCA present | JHRL `Seedlings` tallies, **10–140 cm** | `Tree Data` stems (DBH, >1.4 m) |
| **NOCA past** | legacy **0–3 m height class** | 3–10 m and >10 m height classes |

**Adults are comparable across all four.** Regeneration is not: NOCA's legacy band
runs to 3 m, more than twice the height of every other regeneration cell. So the NOCA
past-vs-present regeneration contrast is confounded by band width, and the drop it
shows (569 → 165 plot occurrences) cannot be read as a decline in recruitment. This
is printed on the figure caption, not left to the reader.


---

## 9. ⚠ The Anthropocene part is presence-only

The current `output/occ_consolidated.csv` has 13,672 rows because it combines two
representations: the Holocene input is a complete 9,590-row sample × species grid,
whereas the Anthropocene part has **4,082 rows against 25,520 possible plot ×
species × period combinations**. In the Anthropocene part an absence is normally a
**missing row**, not a zero; its 18 `occurrence == 0` rows are synthetic markers
for plots empty in one period.

**Any occupancy or prevalence calculation must complete the grid first:**

```r
expand_grid(plots, species) %>% left_join(presences) %>% mutate(x = replace_na(x, 0))
```

Taking `mean(occurrence == 1)` over the modern rows that exist returns **~1 for every species**.
`05_cca_model.R` does this correctly (`all_combinations` + `replace_na`); an earlier figure
did not, and reported every species at ~100% occupancy until it was caught.
