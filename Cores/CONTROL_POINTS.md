# Age-model control points — master reference for all four cores

Every number entered into Bacon, what it is, where it came from, and how Bacon reads it.
Detail lives in `Cores/SOURCES_MORA.md` (MORA) and `data/NOCA/NOCA_paleo/SOURCES.md` (NOCA).
Code: `R/stages/000_PALEO_a_agedepth.R`; shared settings: `R/helpers/bacon_settings.R`.

---

## Glossary — what these things actually are

| term | meaning |
|---|---|
| **cal BP** | calendar years before **A.D. 1950**. Negative = *after* 1950 (so −49 cal BP = A.D. 1999). |
| **¹⁴C yr BP** | *uncalibrated* radiocarbon years. Not the same as calendar years — must be calibrated. |
| **AMS ¹⁴C** | accelerator mass spectrometry radiocarbon dating — works on tiny samples (a single seed or needle). |
| **²¹⁰Pb** | lead-210, a radioisotope with a **22.3 yr half-life**. Dates the last ~100–150 years only, i.e. the top of a core, where ¹⁴C is useless. |
| **CRS** | *Constant Rate of Supply* — the standard model for turning ²¹⁰Pb activity into ages. |
| **DPM/g** | disintegrations per minute per gram — the unit ²¹⁰Pb **activity** is measured in. **Not** a unit of time. |
| **tephra** | airfall volcanic ash/pumice. Deposited in days, so a tephra layer is an **instantaneous time marker** that can be matched between sites by its glass chemistry. |
| **slump** | in Bacon, a depth interval deposited instantaneously (a tephra, or redeposited material). Excised before age-modelling, then re-inserted at zero elapsed time. |
| **`cc`** | Bacon's calibration flag. **`cc = 1`** → the age you supply is *uncalibrated ¹⁴C* and Bacon calibrates it with IntCal20. **`cc = 0`** → the age is *already calendar years*, used as-is. |

### The individual tephras

| layer | volcano | age | why it's useful |
|---|---|---|---|
| **W** (Wn) | Mount St Helens | A.D. 1480 → **470 cal BP** | tree-ring dated **to the year**; the tightest marker in the MORA cores |
| **C** | **Mount Rainier** | ~2250 cal BP | local layer, Rainier's own lettering |
| **Y** (Yn) | Mount St Helens | ~3650 cal BP | thickest layer of set Y; the big regional marker — this is the one that **slumps** in the MORA cores |
| **P** (set P) | Mount St Helens | ~2620 cal BP | present at NOCA only |
| **F** | **Mount Rainier** | ~5740 cal BP | local layer; **least well constrained of the four** |
| **Mazama** | Crater Lake, Oregon | **7633 cal BP** | the single biggest Holocene marker bed in the Pacific Northwest |

Lab prefixes: **QL-** = Quaternary Isotope Lab, Univ. of Washington · **Beta-** = Beta Analytic · **W-** = U.S. Geological Survey.

### Source codes used below

`D86` Dunwiddie 1986 Table 1 · `M74` Mullineaux 1974 (Tables 1, 5) · `M96` Mullineaux 1996 Table 2 ·
`Y83` Yamaguchi 1983 · `C71` Crandell 1971, USGS Prof. Paper 677 (Tables 4, 6; pp. 11, 30, 63) · `P09` Prichard 2009 Tables 1a–c ·
`NEO` Neotoma chron controls / Gavin 2021 · `E15` Egan et al. 2015 ·
**`W17` Walsh et al. 2017**, *Quat. Sci. Rev.* 177:246–264, Table 2

### ✅ All four MORA tephra AGES are independently corroborated

**Walsh et al. 2017 Table 2 uses exactly our four values.** That paper is a Mount Rainier
study (Sunrise, Shadow and Little Sunrise Lakes — the same charcoal records in
`data/PALEO/char_*.xlsx`), its tephras were identified by James Vallance, and its
footnote *a* sources them to *"Mullineaux (1974, 1996), Clynne et al. (2004), Donoghue
et al. (2007) and Sisson and Vallance (2009)"*:

| layer | Walsh 2017 Table 2 | our code |
|---|---|---|
| MSH-W | **470** | 470 ✓ |
| MR-C | **2250** | 2250 ✓ |
| MSH-Yn | **3650** | 3650 ✓ |
| MR-F | **5740** | 5740 ✓ |
| Mazama-O | 7627 | (NOCA uses Gavin's 7633) |

So these are the **standard values in the current Mount Rainier literature**, not one-off
choices. Walsh also independently corroborates layer F with a dated twig: Shadow Lake
Beta-340098, 5000 ± 30 ¹⁴C → **5740 cal BP**, the same age Mullineaux assigned to F.

Walsh also **subtracts tephra thickness from core depth** before age-modelling —
*"the deposition of tephra is a rapid event (Mullineaux, 1974); therefore, the thickness
of individual tephra layers was subtracted from the true core depth"* — i.e. independent
validation of the `slump =` approach used here.

### The errors, though, are published nowhere

**No source gives an error on a tephra layer age** — not Mullineaux, not Yamaguchi, not
Walsh. Bacon needs an age-error input, so the current controls adopt bracket
half-widths or explicit assumptions. A bracket half-width is not a verified
statistical standard deviation. Historical labels used in the error column:

| label | meaning |
|---|---|
| **DERIVED** | calculated from a dating bracket; it remains an assumed statistical error |
| **PADDED** | wider than the source's dating precision; its probability interpretation is assumed |
| **UNPUBLISHED** | no source gives a ±, and no clean bracket is available to derive one |

```
layer Yn   W-2549 3350±50 14C -> 3575 cal BP  (min)     [M96 Table 2, revised errors]
           W-1752 3510±80 14C -> 3781 cal BP  (max)      beneath Yn
           => 3575-3781, midpoint 3678, half-width 103   coded 3650 ± 100   DERIVED

layer Wn   tree-ring. Yamaguchi 1983 dates it to A.D. 1480 from 14 cross-dated cores
           at Bear Meadow; his own caveat is that Douglas-fir grows May-Sept, so the
           eruption "could have occurred as early as the preceding October" - i.e. a
           HALF-YEAR uncertainty.                        coded  470 ± 10    PADDED

layer C    M74's bracket (W-1393 2040±200, W-1396 2340±200) gives half-width 190, but
           those are 1974-style errors, and M96 cut the equivalent MSH errors from
           ±250 to ±50-80. So 190 is very likely inflated and ±100 is defensible,
           especially as W17 adopts 2250 unchanged.      coded 2250 ± 100   UNPUBLISHED

layer F    ONE-SIDED bracket only. Crandell 1971 p.30: organic material BENEATH
           layer F at Cowlitz Park = 5,800 yr ago in 1970 = 5780 cal BP (W-2053).
           Material under a layer predates it, so this is a MAXIMUM age: F must be
           younger than ~5780. Coded 5740 satisfies it by 40 yr. But nothing dates
           material ABOVE F, so there is no minimum and hence no two-sided bracket
           to derive an error from.                      coded 5740 ± 100   UNPUBLISHED
```

Note for layer Yn the half-width barely moves whether you use M96's ±50/±80 or M74's
superseded ±250 (103 vs 102) — because it is set by the **separation between the two
limiting dates**, not by their individual errors.

---

## MORA — Jay Bath

`slump = c(87, 105)` · `d.max = 153` · `acc.mean = 50` · `thick = 5`

| ID | what it is | depth | age | err | cc | age source | error source |
|---|---|---|---|---|---|---|---|
| `Surface` | core top — **cored 1981–82** | 0 | −31.5 | 10 | 0 | **author confirmation** ✓ | recovery of the mud–water interface |
| `Tephra_W` | MSH layer Wn | 22 | 470 | 10 | 0 | Y83 + **W17** | **PADDED** — tree-ring, ~±1 yr |
| `QL-1729` | ¹⁴C, plant macrofossil | 39.5 | 1320 | 30 | 1 | D86 | **D86** ✓ |
| `Tephra_C` | Mt Rainier layer C | 62 | 2250 | 100 | 0 | M74 T5 + **W17** | **UNPUBLISHED** — no source gives ± |
| `QL-1730` | ¹⁴C | 70 | 2920 | 60 | 1 | D86 | **D86** ✓ |
| `Tephra_Y` | MSH layer Yn — **top of slump** | 87 | 3650 | 100 | 0 | M74 T5 + **W17** | **DERIVED** — M96 bracket ±103 |
| `Tephra_Y_alt` | same layer — **base of slump** | 105 | 3650 | 100 | 0 | M74 T5 + **W17** | **DERIVED** — M96 bracket ±103 |
| `Beta-6332` | ¹⁴C | 124.5 | 3740 | 80 | 1 | D86 | **D86** ✓ |
| `Tephra_F` | Mt Rainier layer F | 142 | 5740 | 100 | 0 | M74 T1 + **W17** | **UNPUBLISHED** — no source gives ± |
| `QL-1704` | ¹⁴C | 152.25 | 6050 | 110 | 1 | D86 | **D86** ✓ |

## MORA — Log Wallow

`slump = c(40, 98)` — 15 cm airfall **+ 43 cm of redeposited Y tephra** (D86 p.62, Fig. 4 caption)

| ID | what it is | depth | age | err | cc | age source | error source |
|---|---|---|---|---|---|---|---|
| `Surface` | core top — **cored 1981–82** | 0 | −31.5 | 10 | 0 | **author confirmation** ✓ | recovery of the mud–water interface |
| `Tephra_W` | MSH layer Wn | 22 | 470 | 10 | 0 | Y83 + **W17** | **PADDED** — tree-ring, ~±1 yr |
| `QL-1726` | ¹⁴C | 29 | 1650 | 80 | 1 | D86 | **D86** ✓ |
| `Tephra_Y` | MSH Yn — **top of slump** | 40 | 3650 | 100 | 0 | M74 T5 + **W17** | **DERIVED** — M96 bracket ±103 |
| `Tephra_Y_alt` | same layer — **base of slump** | 98 | 3650 | 100 | 0 | M74 T5 + **W17** | **DERIVED** — M96 bracket ±103 |
| `Tephra_F` | Mt Rainier layer F | 116 | 5740 | 100 | 0 | M74 T1 + **W17** | **UNPUBLISHED** — no source gives ± |
| `QL-1727` | ¹⁴C | 117 | 4900 | 80 | 1 | D86 | **D86** ✓ |
| `QL-1728` | ¹⁴C | 140 | 5980 | 60 | 1 | D86 | **D86** ✓ |

## MORA — Reflection Pond

`slump = c(45, 64)` · no radiocarbon at all — this core is dated **entirely** by tephra + the lahar

| ID | what it is | depth | age | err | cc | age source | error source |
|---|---|---|---|---|---|---|---|
| `Surface` | core top — **cored 1981–82** | 0 | −31.5 | 10 | 0 | **author confirmation** ✓ | recovery of the mud–water interface |
| `Tephra_W` | MSH layer Wn | 10 | 470 | 10 | 0 | Y83 + **W17** | **PADDED** — tree-ring, ~±1 yr |
| `Tephra_C` | Mt Rainier layer C | 26 | 2250 | 100 | 0 | M74 T5 + **W17** | **UNPUBLISHED** — no source gives ± |
| `Tephra_Y` | MSH Yn — **top of slump** | 45 | 3650 | 100 | 0 | M74 T5 + **W17** | **DERIVED** — M96 bracket ±103 |
| `Tephra_Y_alt` | same layer — **base of slump** | 64 | 3650 | 100 | 0 | M74 T5 + **W17** | **DERIVED** — M96 bracket ±103 |
| `Tephra_F` | Mt Rainier layer F | 82 | 5740 | 100 | 0 | M74 T1 + **W17** | **UNPUBLISHED** — no source gives ± |
| `Basal_lahar` | Paradise lahar — the mudflow the ponds sit **on** (max age) | 90 | 6180 | 400 | 0 | **C71 p.63** ✓ | **DERIVED** — half-range of 5800–6600 |

## NOCA — Panther Potholes

`slump = c(303,308, 396,406, 623,635)` · `acc.mean = 10` · `thick = 5` · `ssize = 10000` ·
Student-t outlier model (`normal = FALSE, t.a = 15, t.b = 16`). All settings are Gavin's,
read from the string Neotoma stores — our `_settings.txt` is **byte-identical** to his.

| ID | what it is | depth | age | err | cc | age source | error source |
|---|---|---|---|---|---|---|---|
| `CoreTop` | core top, cored **1999** | 0.5 | −49 | 1 | 0 | NEO (derived, RMSE 1.0 yr) | NEO |
| `Pb210_7` | ²¹⁰Pb CRS age | 7 | −36.7 | 3.47 | 0 | P09 T1c (12.3 yr before coring) | **⚠ DPM/g, not yr** |
| `Pb210_14` | ²¹⁰Pb CRS age | 14 | −9 | 1.15 | 0 | P09 T1c (40) | **⚠ DPM/g** |
| `Pb210_21` | ²¹⁰Pb CRS age | 21 | 12 | 0.72 | 0 | P09 T1c (61) | **⚠ DPM/g** |
| `Pb210_28` | ²¹⁰Pb CRS age | 28 | 21 | 0.74 | 0 | P09 T1c (70) | **⚠ DPM/g** |
| `Pb210_35` | ²¹⁰Pb CRS age | 35 | 36 | 0.77 | 0 | P09 T1c (85) | **⚠ DPM/g** |
| `Beta-172005` | AMS ¹⁴C, conifer seed | 214 | 1950 | 50 | 1 | P09 T1b | **P09** ✓ |
| `Tephra_MSH_P` | MSH set P | 305.5 | 2620 | 70 | 0 | NEO | NEO |
| `Beta-169623` | AMS ¹⁴C, seed | 363 | 3260 | 40 | 1 | P09 T1b | **P09** ✓ |
| `Beta-169624` | AMS ¹⁴C, pollen cone | 389 | 3520 | 40 | 1 | P09 T1b | **P09** ✓ |
| `Tephra_MSH_Y` | MSH set Y | 401 | 3660 | 65 | 0 | NEO | NEO |
| `Beta-169207` | AMS ¹⁴C, pollen cone | 479 | 4500 | 40 | 1 | P09 T1b | **P09** ✓ |
| `Tephra_Mazama` | Mazama climactic | 629 | 7633 | 25 | 0 | NEO / E15 (7584–7682) | NEO |
| `Beta-169208` | AMS ¹⁴C, seed | 678 | 7330 | 40 | 1 | P09 T1b | **P09** ✓ |
| `Beta-169625` | AMS ¹⁴C, *P. contorta* needles | 864 | 9370 | 40 | 1 | P09 T1b | **P09** ✓ |

**Depths are Neotoma's corrected values, NOT Prichard's published Table 1b** (which are wrong
by −5 to −108 cm; Prichard's own Results text agrees with the corrections). See the NOCA
SOURCES file.

### Sensitivity variant `PantherPotholes_pb210err`
Identical, except the five ²¹⁰Pb errors → a flat **±10 yr** (`PB210_ASSUMED_ERROR`). Because
Table 1c's `Error (1σ)` is on ²¹⁰Pb **activity in DPM/g**, and those numbers were entered as
if they were years. Result: top 35 cm widens 7 → 30 yr; deeper chronologies remain similar, with stored maximum median-age differences of 15 yr.

---

## Summary — what rests on what

**Fully sourced (age *and* error):** all 7 MORA radiocarbon dates (Dunwiddie Table 1, verified
verbatim, depths = midpoints of his ranges) and all 6 NOCA AMS dates (Prichard Table 1b).
That's 13 of 40 control points.

**Age sourced, error not published:** every tephra and the lahar — because tephra ages are
published as point estimates or ranges, never as `age ± 1σ`. Two of the four MORA tephra
errors turn out to be **recoverable** from bracketing dates rather than merely assumed:

- `Tephra_Y ±100` — **DERIVED, keep it.** The M96-revised bracket is 3575–3781 cal BP,
  half-width **103**. Note M96 revised the same lab numbers sharply downward from M74
  (W-2549 ±250→**±50**, W-1752 ±250→**±80**, W-2677 ±250→**±50**) — read only M74 and these
  tephras look far vaguer than they are. Do **not** widen.
- `Tephra_W ±10` — **PADDED, keep it.** Wn is tree-ring dated to the year, so the honest
  error is ~±2. The retained ±10 is assumed padding, not a verified statistical
  age error or evidence that uncertainty is complete.
- `Tephra_C ±100` and `Tephra_F ±100` — **UNPUBLISHED but defensible, leave them.**
  An earlier version of this file called C "too tight" (its M74 bracket implies ±190) and
  proposed re-centring it to 2190 ± 190. **That has been withdrawn**: Walsh et al. 2017
  adopts **2250** and **5740** unchanged, sourcing them to five references including
  Mullineaux 1996 and Sisson & Vallance 2009, so these are the current standard values —
  and the ±190 derives from 1974-era errors that M96 showed to be inflated by 3–5×.

**Bottom line on the tephras: the ages are solid and no value needs changing.** What is
genuinely absent is a published ± on any of them, which is a methods-section sentence, not
a defect.

**Still open:**

| # | issue | impact |
|---|---|---|
| 1 | ~~Paradise lahar~~ **RESOLVED AND APPLIED — 6180 ± 400.** Crandell p.11: ages under 6,000 yr *"have been corrected … take into account past variations in atmospheric C¹⁴"*; Table 4 calls them *"true dates"*. So `cc = 0` is right, and the earlier "~6845 cal BP" idea would have **double-calibrated**. ⚠ He reports **"Years ago in 1970"**, so `cal BP = yr_ago_in_1970 − 20`. p.63: *"between 5,800 and 6,600 years old"* → 5780–6580 → **6180 ± 400**. | applied; Reflection Pond basal 6086 → 6118, 95% width 1050 → 957. Elsewhere ≤8 yr |
| 2 | ~~`Surface, 0, ±5`~~ **RESOLVED.** Billur confirmed with Dunwiddie that the lakes were cored **1981–1982** → core top = **−31.5 cal BP**, entered with ±10 for interface recovery. Neither Dunwiddie paper states the year (1986 Methods gives the corer but no date; the published bound is only "manuscript received 17 April 1984"). | applied — tops move to ~−32, median change below 40 cm is 1–5 yr |
| 3 | ~~Layer F has no bracketing sample~~ **RESOLVED (one-sided).** Crandell p.30 dates organic material *beneath* F at 5780 cal BP (W-2053) — a **maximum** age, satisfied by the coded 5740. No date exists above F, so there is still no minimum and no two-sided bracket for an error. | age corroborated from a third direction; error still unpublished |
| 4 | `Tephra_MSH_P` 2620 ± 70 sits at the extreme young end of M96's set-P span (3,000–2,500 ¹⁴C = 3185–2579 cal BP) | low — bracketed by AMS dates at 214 and 363 cm |
