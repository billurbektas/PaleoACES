

> **Documents:** The raw MORA vegetation files in data/MORA/.  
> **Used by:** `R/pipeline/01_clean_mora_vegetation.R`  
> **Originally:** `data/MORA/README_data_raw.md` (moved into the report on 2026-11-09)

# Upstream MORA raw-data reference (reference-only)

This document came from the upstream MORAcleaning package. It is retained for
provenance and is not the PaleoACES execution guide. Current inputs and commands
are defined in the root [workflow](11_outputs_and_workflow.md); do not infer active script
paths from the historical `scripts/` wording below.

# Raw Data (`data_raw/`)

This folder contains the original data used for processing and cleaning in the `MORAcleaning` subproject. The data come from vegetation monitoring conducted in Mount Rainier National Park (MORA).

**Contents:**
1. First level:  
   - MORA: Mount Rainier National Park

2. Second level:  
   - VegData: understory data  
   - TreeData: overstory data  
   - Plot: plot information and characteristics  
   - PlantList: list of all species names

3. Third level:  
   - Legacy: data from 1970s surveys  
   - Resurvey: data from 2010s surveys

4. [Other]:  
   - PA: presence–absence data (trees only)  
   - Org: original file  
   - Cleaned: cleaning process is described in GitHub scripts  
   - Cleaned_Consolidated: cleaning and consolidation process is described in GitHub scripts

**Important:**  
Do not modify these files! All cleaning and processing should be done using the scripts located in the `scripts/` folder.

**Data source:**  
Kavya Pradhan's GitHub repository: https://github.com/kavs-P/dissimilarityPNW

