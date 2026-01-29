# Data and Code for "Currency Mismatches in Emerging Markets: Effects on Corporate Liquidity, Investment Dynamics and Performance"

**Published in:** *North American Journal of Economics and Finance* (2026)

The article will be **open access** under the agreement between the University of Valladolid and Elsevier.

**Link to paper:** See [PAPER.md](PAPER.md) — *(link will be added upon publication)*

## Authors

**José De Gregorio** (University of Chile)  
**Luis P. de la Horra** (University of Valladolid) — Corresponding author  
**Mauricio Jara** (University of Chile)

## Abstract

We examine how USD-denominated bond issuance by non-financial listed firms in emerging market economies affects cash holdings and real activity under currency depreciations and shifting external borrowing conditions. Using firm-year data for 1,655 listed firms in fifteen EMEs (2001–2016) and an issuance-based measure of offshore access, we find that issuing abroad raises cash holdings and increases investment with a lag, consistent with a *save-to-invest* motive. These effects are stronger when country-level risk-adjusted domestic–U.S. borrowing spreads are high. Depreciations dampen the contemporaneous cash buildup but do not systematically reduce investment or competitiveness. Instead, firms expand working capital and, when depreciations coincide with high spreads, increase sales and capacity utilization, indicating adjustment through liquidity and operational margins rather than sharp balance-sheet distress.

**Keywords:** USD bond issuance; emerging markets; liquidity buffers; save-to-invest; currency depreciation; risk-adjusted spreads

**JEL codes:** G32; G15; F31; E22; E44; F34

---

## Replication Instructions

### Overview

To replicate the analysis, users should use Stata. The replication package includes a single master do-file that executes all data preparation, variable construction, and estimation procedures sequentially.

### Required Files

| File | Description |
|------|-------------|
| `Replication_Stata.do` | Master do-file (runs entire analysis) |
| `data/dataset_jie.dta` | Main firm-level dataset |
| `data/Issuance Firm-Year.dta` | Bond issuance data by firm and year |
| `data/exrates.dta` | Exchange rate data by country and year |

### Step-by-Step Instructions

1. **Install Stata** (version 15 or higher; tested on Stata 17). Ensure internet connection for the first run.

2. **Obtain the data files** (see [Data Availability](#data-availability)) and place them in the `data/` folder.

3. **Set the working directory** to the replication folder:
   ```stata
   cd "C:\path\to\replication-folder"
   ```

4. **Run the master do-file:**
   ```stata
   do "Replication_Stata.do"
   ```

5. **The script will automatically:**
   - Create `Tables/` and `Figures/` folders (if missing)
   - Install required packages (`reghdfe`, `ftools`, `estout`, `winsor2`, `locproj`)
   - Load and merge raw datasets
   - Construct all variables
   - Run all regressions
   - Export LaTeX tables to `Tables/`, graphs to `Figures/`, and log to the repository root

6. **Check outputs:**
   - **Log:** `replication_log.txt` (repository root)
   - **Tables:** `Tables/` (all `.tex` files)
   - **Figures:** `Figures/` (local projection PDFs and `.gph` files).  
   `Tables/` and `Figures/` are not in the repository; they are created when you run the do-file.

### Efficient Re-runs

On subsequent runs, the do-file detects if `data/dataset_jie_reg.dta` exists and skips data construction, proceeding directly to estimation.

### Runtime

Approximately 15–20 minutes on a modern computer with at least 4 GB RAM.

---

## Data Availability

The datasets required for replication are not included in this repository due to licensing restrictions (firm-level data sourced from Refinitiv Eikon).

**Data available upon request.** Researchers interested in obtaining the data for replication purposes should contact the corresponding author:

**Luis P. de la Horra**  
Email: luispablo.horra@uva.es

See `data/DATA_README.md` for details.

---

## Software Requirements

- **Stata:** Version 15 or higher (tested on Stata 17)
- **Packages:** `reghdfe`, `ftools`, `estout`, `winsor2`, `locproj` (auto-installed)
- **Memory:** 4 GB RAM minimum

---

## Repository Structure

```
├── README.md                 # This document
├── LICENSE                   # MIT License
├── PAPER.md                  # Link to published article (added upon publication)
├── Replication_Stata.do      # Master do-file
├── Markdown_Stata.md         # Code appendix with detailed documentation
│
└── data/
    ├── DATA_README.md        # Data availability information
    ├── dataset_jie.dta       # (not included - available upon request)
    ├── Issuance Firm-Year.dta # (not included - available upon request)
    └── exrates.dta           # (not included - available upon request)
```

For detailed code documentation with variable definitions and table-by-table explanations, see `Markdown_Stata.md`.

---

## License

Code released under the **MIT License** (see `LICENSE` file).

---

## Contact

**Luis P. de la Horra** (Corresponding author)  
University of Valladolid  
Email: luispablo.horra@uva.es

---

## Citation

De Gregorio, J., De la Horra, L. P., & Jara, M. (2026). Currency Mismatches in Emerging Markets: Effects on Corporate Liquidity, Investment Dynamics and Performance. *North American Journal of Economics and Finance*.

---

## Acknowledgments

We thank Claudio Raddatz (Universidad de Chile) and Julio Riutort (Universidad Adolfo Ibáñez) for valuable comments. Luis P. de la Horra and Mauricio Jara acknowledge financial support from projects PID2023-150140NA-I00 and PID2024-155796NB-I00 (MCIU/AEI/ERDF).
