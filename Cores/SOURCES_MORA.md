# MORA cores (Jay Bath, Log Wallow, Reflection Pond) — provenance of every number

Companion to `data/NOCA/NOCA_paleo/SOURCES.md`, which covers Panther Potholes.
Control points are entered in `R/stages/000_PALEO_a_agedepth.R`, sections 1–3.

## Publications (all in `related_publications/`)

| ref | what it supplies |
|---|---|
| **Dunwiddie, P.W. (1986)** *A 6000-year record of forest history on Mount Rainier, Washington.* Ecology 67:58–68 | the cores, the macrofossils, Table 1's seven ¹⁴C dates, the Y-tephra slump evidence |
| **Mullineaux, D.R. (1974)** *Pumice and other pyroclastic deposits in Mount Rainier National Park, Washington.* USGS Bulletin 1326 | tephra layer ages (Table 1 p.3, Table 5 p.25) |
| **Yamaguchi, D.K. (1983)** *New tree-ring dates for recent eruptions of Mount St. Helens.* Quat. Res. | layer Wn = A.D. 1480 |
| **Crandell, D.R. (1971)** *Postglacial Lahars from Mount Rainier Volcano, Washington.* USGS Prof. Paper 677 | the Paradise lahar age (p.63), the age convention (p.11, Table 4), layer F's limiting date (p.30) |

## ✅ Fully sourced — the seven radiocarbon dates

Dunwiddie 1986 Table 1, verified verbatim. Ages **and** errors match the code
exactly; code depths are the midpoints of his reported ranges. Entered `cc = 1`
(uncalibrated — his "Date BP" are conventional ¹⁴C ages; Fig. 2's axis reads
¹⁴C YR BP).

| core | lab no. | age ± err | Dunwiddie depth | code depth |
|---|---|---|---|---|
| Jay Bath | QL-1729 | 1320 ± 30 | 38–41 | 39.5 ✓ |
| Jay Bath | QL-1730 | 2920 ± 60 | 68–72 | 70 ✓ |
| Jay Bath | Beta-6332 | 3740 ± 80 | 123–126 | 124.5 ✓ |
| Jay Bath | QL-1704 | 6050 ± 110 | 149.5–155 | 152.25 ✓ |
| Log Wallow | QL-1726 | 1650 ± 80 | 28–30 | 29 ✓ |
| Log Wallow | QL-1727 | 4900 ± 80 | 116–118 | 117 ✓ |
| Log Wallow | QL-1728 | 5980 ± 60 | 138–142 | 140 ✓ |

## ✅ Tephra ages — traced to Mullineaux 1974 / Yamaguchi 1983

Mullineaux Table 1 (p.3) gives layer ages in **radiocarbon years**; Table 5 (p.25)
adds bracketing ¹⁴C samples and an "approximate calendar date" from bristlecone-pine
calibration. The code enters calendar ages (`cc = 0`):

| code | value | Mullineaux ¹⁴C | Table 5 calendar → cal BP | IntCal20 median | matches |
|---|---|---|---|---|---|
| `Tephra_W` | 470 | 450 (tree-ring) | A.D. 1500 → 450 | — | **Yamaguchi 1983**: A.D. 1480 → **470** ✓ exact |
| `Tephra_C` | 2250 | 2,200 | 300 B.C. → **2250** | 2190 | **Table 5** ✓ exact |
| `Tephra_Y` | 3650 | 3,400 (Yn) | 1700 B.C. → **3650** | 3647 | both ✓ |
| `Tephra_F` | 5740 | 5,000 | 3800 B.C. → 5750 | **5741** | **IntCal20** ✓ (Table 5 off by 10) |

Every tephra age is therefore traceable. `Tephra_W` correctly prefers Yamaguchi's
tree-ring refinement (A.D. 1480) over Mullineaux's coarser 450.

## ✅ All four tephra AGES independently corroborated — Walsh et al. 2017

**Walsh et al. (2017)** *Quat. Sci. Rev.* 177:246–264 (in `related_publications/`) is a
Mount Rainier study of Sunrise, Shadow and Little Sunrise Lakes — the same charcoal
records as `data/PALEO/char_*.xlsx`. Its tephras were identified by James Vallance, and
Table 2 sources them to *"Mullineaux (1974, 1996), Clynne et al. (2004), Donoghue et al.
(2007) and Sisson and Vallance (2009)"*. Its values are **exactly ours**: MSH-W **470**,
MR-C **2250**, MSH-Yn **3650**, MR-F **5740**. So these are the current standard values
for Mount Rainier, not one-off choices.

Layer F gets independent support there too — Shadow Lake Beta-340098, 5000 ± 30 ¹⁴C →
**5740 cal BP**, the age Mullineaux assigned to F. Walsh also **subtracts tephra thickness
from core depth** before age-modelling, validating the `slump =` approach used here.

## 🔶 The error values — no source publishes one

**No tephra source gives an error on a layer age** — not Mullineaux, not Yamaguchi, not
Walsh. Bacon needs `age ± σ`, so σ must be derived from bracketing dates or assumed. This
is the same class of gap as the NOCA ²¹⁰Pb errors and belongs in the methods.

| control | error | assessment |
|---|---|---|
| `Tephra_W` | ±10 | **Right.** Tree-ring dated to the year — see below. |
| `Tephra_Y` | ±100 | **Right.** Matches the 1996-revised bracket almost exactly — see below. |
| `Tephra_C` | ±100 | Fine. W17 adopts 2250 unchanged; the ±190 its M74 bracket implies rests on errors M96 showed to be inflated 3–5×. |
| `Tephra_F` | ±100 | One-sided bracket only (C71 gives a maximum age, no minimum), so no ± can be derived. Age corroborated by W17. |
| `Basal_lahar` | ±400 | **Derived** — half-range of Crandell p.63's 5,800–6,600. Applied. |
| `Surface` | ±10 | **Resolved** — cored 1981–82, so −31.5 cal BP; ±10 covers interface recovery. See below. |

### ⚠ Use Mullineaux **1996** errors, not 1974 — they were revised sharply downward

**Mullineaux 1996 (Prof. Paper 1563) Table 2 reports the same lab numbers with much
smaller errors than the 1974 bulletin.** Anyone reading only the 1974 tables will
conclude these tephra ages are far vaguer than they are:

| sample | Mullineaux **1974** Table 5 | Mullineaux **1996** Table 2 |
|---|---|---|
| W-2549 (within set Y) | 3,350 ± **250** | 3,350 ± **50** |
| W-1752 (beneath layer Yn) | 3,510 ± **250** | 3,510 ± **80** |
| W-2677 (below set Y) | 3,900 ± **250** | 3,900 ± **50** |

With the 1996 errors, layer Yn is closely bracketed:

```
W-1752  beneath Yn   3510±80 14C  ->  3781 cal BP  = maximum age
W-2549  within set Y 3350±50 14C  ->  3575 cal BP  = minimum age
   => layer Yn lies between ~3575 and ~3781 cal BP
   => code Tephra_Y = 3650 ± 100 spans 3550-3750, INSIDE that bracket
```

So **±100 on `Tephra_Y` is correct, not too tight** — it reproduces the bracketing
evidence almost exactly. An earlier version of this file argued for ±200 on the
basis of the 1974 errors; that was wrong, because those errors are superseded.

`Tephra_W ±10` is likewise well supported. Mullineaux 1996 states the eruption
*"occurred after the growing season of A.D. 1479"* and *"for simplicity, A.D. 1480 has
been used as the date"*; Yamaguchi's tree-ring dating fixes it to the year, so ±10 is
already generous.

**Caveat for layers C and F.** Mullineaux 1996 covers **Mount St Helens only**, so it
revises nothing for the two *Mount Rainier* layers — their bracketing samples
(W1393, W1396) do not appear in it. C and F still rest on 1974's "approximate" ages:

```
layer C   W1393 2,040±200   W1396 2,340±200   (1974 errors, possibly also superseded)
layer F   no bracketing sample in M74 Table 5 -- footnote 4 points onward:
          "Based on several radiocarbon dates. See Crandell, 1971, p. 24."
```

Given the systematic pattern above, C's 1974 ±200 is likely conservative too, so
±100 is probably reasonable.

**Layer F now has a one-sided bracket.** Crandell 1971 p.30: *"organic material beneath
layer F at Cowlitz Park has an age of 5,800 years (table 4, sample W-2053)"* = **5780 cal
BP**. Material buried *under* a layer predates it, so this is a **maximum** age — F must be
younger than ~5780, and the coded 5740 satisfies it by 40 yr, implying F formed soon after.
Nothing dates material *above* F, so there is still no minimum and hence no two-sided
bracket from which to derive an error. F's **age** is now corroborated from three
directions (M74's 5,000 ¹⁴C, W17's adoption of 5740, Crandell's underlying date); its
**error** remains unpublished.

## Questions raised during the audit — both now resolved

**1. ✅ RESOLVED — Crandell's ages are already calibrated, and the lahar is 6180 ± 400.**

I previously suspected Dunwiddie's *"6000-yr-old Paradise lahar"* was a raw ¹⁴C age, which
would have made it ~6845 cal BP. **That was wrong.** Crandell 1971 p.11:

> *"Age determinations cited here (table 4) of less than 6,000 years **have been corrected**
> by Meyer Rubin … based on a C¹⁴ half life of 5,730 years and also **take into account past
> variations in atmospheric C¹⁴**. Ages of less than 6,000 years given in the following text
> will be the **corrected ages**."*

Table 4's header calls them *"true dates … corrected for C14 variations in the atmosphere"* —
i.e. calibrated. So `cc = 0` is correct and re-calibrating would have **double-counted**.

⚠ **But Crandell reports "Years ago in 1970", not BP.** Verified on his own row: W-1120,
290 ¹⁴C → *"1525 A.D."* → *"450 years ago in 1970"* (1970 − 1525 = 445 ✓). So
**cal BP = years_ago_in_1970 − 20**.

His actual figure, p.63:

> *"The Paradise lahar is between **5,800 and 6,600 years old**"*

→ **5780–6580 cal BP**, i.e. midpoint **6180**, half-range **400**.

**APPLIED.** The old `6000 ± 600` (Dunwiddie's rounded "6000-yr-old") spanned 5400–6600 and
so covered the truth, but sat ~180 yr low with a wider error than the source needs. Now
`6180 ± 400`. Reflection Pond is the only core affected — and the only one with no
radiocarbon at all, so it leans hardest on this control.

Measured effect (with the surface fix, against the pre-change run):

```
  depth      age                95% width
   0.0 cm :     0 ->  -30        30 ->   60     <- surface fix
  10.0 cm :   460 ->  460       176 ->  155
  45.0 cm :  3640 -> 3641       396 ->  387
  82.0 cm :  5666 -> 5674       658 ->  600
  90.0 cm :  6086 -> 6118      1050 ->  957     <- lahar fix
  median |age change| 7 yr, max 42 yr
```

i.e. the top is corrected, the base moves 32 yr toward the sourced age and tightens, and
the middle of the core is untouched.

**2. ✅ RESOLVED — the cores were taken in 1981–1982.**
Confirmed with Dunwiddie directly. Neither published paper states it: the 1986 Methods
say only *"Cores were collected with a modified 5 cm diameter Livingstone piston corer
from a floating platform near the center of each pond"*, and the 1987 paper just refers
back to *"another study (Dunwiddie 1986)"*. The only published bound is *"Manuscript
received 17 April 1984"*.

So the core top is **1950 − 1981.5 = −31.5 cal BP**, not 0. The entry was
`Surface, 0, ±5` — asserting A.D. 1950 ± 5, about 32 yr too old — and is now
`Surface, −31.5, ±10`.

The error is 10, not 5, because the coring year is now known to ~1 yr and the residual
uncertainty is whether the sediment–water interface survived extrusion. At these cores'
accumulation rates (~23–50 yr/cm) even 0.5 cm of lost floc is 15–25 yr, so ±10 is the
honest floor; it spans A.D. 1972–1992.

Measured effect: core tops move to −32 / −33 / −32 as intended, and the median absolute
change **below 40 cm is 3 / 5 / 1 yr** — i.e. nothing. The value matters for consistency
with NOCA (core top derived as −49 cal BP = A.D. 1999), not because it moves a result.

**3. `Tephra_C` and `Tephra_F` were calibrated by different methods.**
C follows Mullineaux's 1974 bristlecone calendar column (2250, exact); F follows a
modern IntCal-style calibration (5740, exact). Individually defensible, but mixed.
Using IntCal20 throughout would move C from 2250 to ~2190 — a 60 yr shift, well
inside any sensible error, so this is tidiness rather than a correction.

## Not an issue

The Y-tephra **slump** (`slump = c(87,105) / c(40,98) / c(45,64)`) is fully sourced
to Dunwiddie 1986 — p.62, Fig. 4's caption, and p.59's 15 cm airfall thickness. See
the note at the Bacon call in `R/stages/000_PALEO_a_agedepth.R` and the age-control
authority, `Cores/CONTROL_POINTS.md`.
