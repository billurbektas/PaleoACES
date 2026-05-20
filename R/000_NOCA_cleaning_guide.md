---
output:
  pdf_document: default
  html_document: default
---
# NOCA Forest Survey Data Processing: Step-by-Step Guide

## Overview
This R script processes forest resurvey data from North Cascades National Park (NOCA), comparing historical (1980s) and present (2015) vegetation surveys. The script cleans, merges, and tracks changes in forest plots over time.

## Key Steps and Decision Points

### 1. Initial Data Loading and Plot Setup
**What happens:**
- Loads plot coordinate data from Wilson's dataset
- Renames columns for consistency (`2015.Plot.Name` → `plot_id`)
- Filters out specific problematic plots: "Supp2026", "ROSS4001REF", "Supp5127"
- Removes plots without GPS coordinates (missing Latitude)

**Key Decision:** Manual exclusion of 3 specific plots - likely based on data quality issues discovered in prior analysis.

### 2. Plot Tracking System Initialization
**What happens:**
- Creates empty dataframe to track all plot processing decisions
- Will record: plot_id, period (past/present/both), status (kept/removed), reason

**Key Decision:** Implementing comprehensive tracking to maintain data provenance and justify all exclusions.

### 3. Present Period Data Processing (2015 surveys)

#### Species Library Creation
**What happens:**
- Loads species abbreviation lookup table from Excel
- Maps legacy codes to present codes to species names
- Handles special cases with manual species name corrections for 9 species (ABPE, THSE, etc.)

**Key Decision:** Manual species name standardization ensures taxonomic consistency across time periods.

#### Tree Data Processing
**What happens:**
- Loads tree measurements (DBH = Diameter at Breast Height)
- Joins with species library to get full species names
- Identifies plots with no species data

#### Plot Quality Control
**What happens:**
- Finds plots where ALL records have missing species (100% NA)
- Removes these "empty" plots from analysis
- Tracks removal reason: "no species recorded"

**Key Decision:** Only removes plots with zero usable species data, not plots with partial missing data.

### 4. Present Period Summary Statistics
**What happens:**
- Creates occurrence matrix (plot × species)
- Groups by plot and species, counting occurrences
- Reports final plot count for present period

### 5. Historical Data Processing (1980s surveys)

#### Data Loading and Joining
**What happens:**
- Loads historical tree data, species library, and plot info from Excel sheets
- Joins historical species codes with present-day species library for consistency
- Links with GPS coordinates from plot data

#### GPS Coordinate Quality Control
**What happens:**
- Identifies plots missing Latitude OR Longitude
- Removes these plots from analysis
- Tracks removal reason: "missing GPS coordinates"

**Key Decision:** GPS coordinates essential for spatial analysis - plots without coordinates cannot be used.

#### Species Name Standardization
**What happens:**
- Additional manual correction for "ACCI" → "Acer circinatum"
- Handles tree density data across size classes (0-3cm, 3-10cm, >10cm DBH)
- Converts NA density values to 0 (assumes no trees if not recorded)

**Key Decision:** Treating missing density as zero rather than unknown maintains data completeness.

### 6. Plot Matching and Filtering

#### Temporal Matching
**What happens:**
- Finds intersection of plots surveyed in BOTH time periods
- Identifies three categories:
  1. Empty in past, trees present now (colonization)
  2. Trees in past, empty now (extirpation) 
  3. Trees in both periods (persistence)
  4. Empty in both periods (removed from analysis)

**Key Decision:** Only analyzes plots with data from both time periods to enable change detection.

#### Final Plot Selection
**What happens:**
- Keeps plots present in both datasets
- Removes plots empty in both periods (no ecological information)
- Tracks all decisions in plot_tracking dataframe

### 7. Data Harmonization for Empty Plots

#### Placeholder Species Addition
**What happens:**
- For plots empty in one period, adds dummy "Abies amabilis" record with count = 0
- Enables creation of complete species occurrence matrices

**Key Decision:** Technical necessity - creates consistent data structure while preserving information about plot emptiness.

### 8. Final Data Merging
**What happens:**
- Combines past and present occurrence data
- Adds period identifier ("past"/"present")
- Creates unified dataset for analysis

### 9. Tracking and Visualization

#### Summary Statistics Generation
**What happens:**
- Counts plots by status (kept/removed) and reason
- Identifies colonization vs extirpation events
- Creates detailed tracking summaries

#### Visualization Creation
**What happens:**
- Generates three plots:
  1. Overall plot status by removal reason
  2. Plot status breakdown by time period  
  3. Forest change events (colonization/extirpation)
- Saves to PDF for documentation

### 10. Data Export
**What happens:**
- Writes 5 CSV files:
  - Present period occurrences
  - Past period occurrences
  - Plot location information
  - Combined occurrence data
  - Complete plot tracking log

## Critical Decision Points Summary

1. **Manual Plot Exclusions:** Specific plots removed based on known data quality issues
2. **Species Standardization:** Manual corrections ensure taxonomic consistency across periods
3. **GPS Requirement:** Plots without coordinates excluded (spatial analysis requirement)
4. **Missing Data Handling:** NAs converted to zeros for density data
5. **Temporal Matching:** Only plots from both periods retained for change analysis
6. **Empty Plot Strategy:** Dummy records maintain data structure while preserving ecological information
7. **Comprehensive Tracking:** All decisions logged for reproducibility and transparency

## Key Variables Tracked
- **plot_id:** Present period plot identifier
- **plot_id_past:** Historical period plot identifier  
- **species:** Standardized taxonomic names
- **count/occurrence:** Tree abundance measures
- **period:** Temporal identifier (past/present)
- **Latitude/Longitude/elevation:** Spatial coordinates

## Output Deliverables
- Clean, standardized occurrence matrices for both time periods
- Comprehensive plot tracking with removal justifications
- Summary visualizations of data processing decisions
- Spatial plot information for mapping
- Combined dataset ready for change analysis