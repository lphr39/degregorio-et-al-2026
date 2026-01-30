# Code for Replication

## Currency Mismatches in Emerging Markets: Effects on Corporate Liquidity, Investment Dynamics and Performance

**Authors:** José De Gregorio, Luis P. de la Horra, Mauricio Jara

---

## Introduction

This appendix provides the Stata code to replicate all tables and figures in the paper *"Currency Mismatches in Emerging Markets: Effects on Corporate Liquidity, Investment Dynamics and Performance"*.

### Outputs

The replication creates:

- `replication_log.txt` — log of the full run
- `Tables/` — LaTeX `.tex` tables (Table1–4, TableA2, TableB1–B5, TableC1–C5)
- `Figures/` — PDF and `.gph` local projection graphs (Appendix D)

### Required Files

The replication requires the following data files in the `data/` folder:

| File | Description |
|------|-------------|
| `data/dataset_jie.dta` | Main firm-level dataset |
| `data/Issuance Firm-Year.dta` | Bond issuance data by firm and year |
| `data/exrates.dta` | Exchange rate data by country and year |

### Required Stata Packages

The following user-written packages are required (automatically installed by the do-file):

- **reghdfe**: High-dimensional fixed effects regression
- **ftools**: Required by reghdfe
- **estout**: Table export commands (esttab, eststo, estadd)
- **winsor2**: Winsorization
- **locproj**: Local projections (for Appendix D)

---

## Data Loading and Variable Definitions

This section loads the raw data, merges auxiliary datasets, and constructs all variables used in the analysis.

### 1.1 Load and Merge Data

```stata
********************************************************************************
* SECTION 0: INSTALL REQUIRED PACKAGES (if not already installed)
********************************************************************************

capture ssc install reghdfe
capture ssc install ftools
capture ssc install estout
capture ssc install winsor2
capture ssc install locproj

********************************************************************************
* DATA LOADING AND VARIABLE DEFINITIONS
********************************************************************************

clear all
set more off

* Start log file
capture log close
log using "replication_log.txt", text replace

* Create output folders (Tables, Figures)
cap mkdir "Tables"
cap mkdir "Figures"

*------------------------------------------------------------------------------
* 1.1 Load main dataset and merge auxiliary data
*------------------------------------------------------------------------------

use "./data/dataset_jie.dta", clear
encode tick, gen(id)

* Merge issuance data
merge m:m key year using "./data/Issuance Firm-Year.dta" 
duplicates drop id year, force
drop _merge

* Merge exchange rate data
merge m:m isocode year using "./data/exrates.dta" 
drop if fy==""
drop _merge

* Set panel structure
xtset id year
sort id year
```

### 1.2 Key Variable Definitions

#### Foreign Currency Bond Issuance (FXBHA)

The key explanatory variable is **FXBHA** (Foreign Currency Bond Issuance scaled by lagged assets), which captures firms' exposure to currency mismatches through USD-denominated bond issuance.

```stata
*------------------------------------------------------------------------------
* 1.3 Foreign Currency Bond Issuance Variables (FXBHA)
*------------------------------------------------------------------------------

* Replace missing issuances with zero
replace issfor = 0 if issfor == .
replace isslocalcurr = 0 if isslocalcurr == .

* Total issuance
gen totiss = issfor + isslocalcurr

* Proportion of Foreign Issuance
gen propFX = issfor / totiss
gen propDC = isslocalcurr / totiss

* Classification by FX/LC issuance
gen FXLC = 3 if propFX > 0.1
replace FXLC = 2 if propDC > 0.49991
replace FXLC = 1 if propFX == .
replace propFX = 0 if propFX == .
drop totiss

* Hard currency and local currency issuance
gen isshard = issfor
gen isslocal = isslocalcurr

* FXBHA: Foreign Currency Bond Issuance scaled by lagged assets
* (Key explanatory variable - aggregate USD-denominated bond issuance)
gen FXBHass = isshard / assets
gen FXBHassl = isshard / assetsl
replace FXBHassl = . if FXBHassl > 1
replace FXBHassl = 0 if FXBHassl == . 
label variable FXBHassl "FXBHA (USD Bond Issuance / Lagged Assets)"

* DCBA: Domestic Currency Bond Issuance scaled by lagged assets
gen DCBass = isslocalcurr / assets
gen DCBassl = isslocalcurr / assetsl
replace DCBassl = . if DCBassl > 1
label variable DCBassl "DCBA (DC Bond Issuance / Lagged Assets)"
```

#### Control Variables

```stata
*------------------------------------------------------------------------------
* 1.4 Control Variables
*------------------------------------------------------------------------------

* Leverage (Debt to total assets) - DTA
gen debt2a = debt / assets
label variable debt2a "DTA (Debt/Assets)"

* Size (log of assets) - TA
gen size = ln(assets)
label variable size "TA (Size - Log Assets)"
winsor2 size, replace cuts(1 99) trim

* Cash Flow from Operations - CFO
gen cfo2a = operatingcash / assets
gen cfo2al = operatingcash / assetsl
label variable cfo2al "CFO (Operating Cash Flow / Lagged Assets)"

* Tobin's Q - TQ
gen qtob = (marketcap + debt) / assets
winsor2 qtob, replace cuts(1 99) trim
label variable qtob "TQ (Tobin's Q)"

* Long term debt ratio - LTD
gen ltdtd = ltdebt / debt
label variable ltdtd "LTD (Long-Term Debt / Total Debt)"

* Sales to Assets ratio - STA
gen sales2a = sales / assets
gen sales2al = sales / assetsl
label variable sales2a "STA (Sales/Assets)"
winsor2 qtob sales2a sales2al, replace cuts(1 99) trim
```

#### Dependent Variables

```stata
*------------------------------------------------------------------------------
* 1.7 Dependent Variables
*------------------------------------------------------------------------------

* Delta Cash (Change in Cash Holdings) - Main dependent variable for Table 1
gen cash2a = cashst / assets
gen cash2al = cashst / assetsl
gen dcash = (cashst - cashstl) / assetsl
label variable dcash "ΔCash (Change in Cash Holdings)"

* Investment (Capital Expenditures) - Main dependent variable for Table 2
gen capex2a = abs(capex / assets)
gen capex2al = abs(capex / assetsl)
replace capex2a = 0 if capex2a == .
replace capex2al = 0 if capex2al == .
label variable capex2al "Inv (Investment / Lagged Assets)"
```

#### Exchange Rate Variables

```stata
*------------------------------------------------------------------------------
* 1.10 Exchange Rate Variables
*------------------------------------------------------------------------------

* Log changes in exchange rates
gen lndtcn = ln(tcn / tcnlag)
gen dtcn = (tcn / tcnlag) - 1
gen dtcr = (tcr / tcrlag) - 1
gen lndtcr = ln(tcr / tcrlag)
gen lndtcusd = ln(rateusd / rateusdlag)

winsor2 lndtcn lndtcr lndtcusd, replace cuts(1 99) trim
```

#### Risk-Adjusted Spread (Sp)

The **risk-adjusted spread** is a key moderating variable that captures the cost of borrowing relative to risk.

```stata
*------------------------------------------------------------------------------
* 1.12 Risk-Adjusted Spread (Sp) - Key moderating variable
*------------------------------------------------------------------------------

* Spread: Lending rate minus US BAA corporate bond yield
gen spread2 = (tasaborrow - baa) / 100

* Risk-adjusted spread: Spread / Implied Volatility
replace impliedvolatility = impliedvolatility / 100
gen spread2imp = spread2 / impliedvolatility
replace spread2imp = 0 if spread2imp == .

* Generate demeaned spread (sp4imp) - Main spread variable in paper
* First run a regression to define the sample; then country-level and global demeaning
reghdfe dcash FXBHassl fxalspread2imp DCBassl cfo2al osources2al size qtob debt2a ltdtd sales2a, absorb(id yc) cluster(c)
bys pais: egen sp_mean2 = mean(spread2imp) if e(sample)
* ... then global demeaning to create sp4imp
egen sp_mean2 = mean(spread2imp) if e(sample)
gen sp4imp = spread2imp - sp_mean2 if e(sample)
replace sp4imp = 0 if sp4imp == . & e(sample)
label variable sp4imp "Sp (Demeaned Risk-Adjusted Spread)"
```

#### Section 2: Additional Variables (for Tables 3, 4 and Appendices)

After saving the cleaned dataset and reloading, the do-file creates variables used in Tables 3–4 and appendices:

```stata
* FXDep: Demeaned log change in real exchange rate
egen mdepr = mean(lndtcr)
gen dlndtcr = lndtcr - mdepr

* operoa: Operating Income (before scaling to %)
gen operoa = operatingmargin * assetturnover
label variable operoa "Operating Income"
replace operoa = operoa * 100
winsor2 operoa, replace cuts(1 99) trim

* nonopincome: Non-operating Income = pretaxroa - operoa
gen nonopincome = (pretaxroa - operoa) if !missing(pretaxroa) & !missing(operoa)
winsor2 nonopincome, replace cuts(1 99) trim

* T.Inv, ΔWC, lnsales, cursdepre (depreciation dummy), cye (country-year-industry)
* Sample indicators: samp (cash), sampi (investment)
```

---

## Main Body Tables

### Table 1: Cash Holdings, Foreign Bond Issuance, and Currency Depreciations

**Dependent variable**: ΔCash (change in cash holdings scaled by lagged assets)

This table examines how firms adjust their cash holdings in response to foreign currency bond issuance and currency depreciations. The key coefficient of interest is the triple interaction **FXBHA × FXDep × Sp**, which captures how firms with currency mismatches adjust cash holdings when currencies depreciate, conditional on the risk-adjusted spread.

```stata
********************************************************************************
* TABLE 1: Cash holdings, foreign bond issuance, and currency depreciations
* Dependent variable: ΔCash (dcash)
* Equation (1) in the paper
********************************************************************************

*------------------------------------------------------------------------------
* Column 1: Total sample - No interactions
*------------------------------------------------------------------------------
reghdfe dcash FXBHassl DCBassl cfo2al osources2al forev2al netderiv2al size qtob ///
    debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, ///
    absorb(id year c) cluster(c) 
est sto t1_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 2: Total sample - Two-way interactions
*------------------------------------------------------------------------------
reghdfe dcash c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp DCBassl cfo2al osources2al ///
    forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, ///
    absorb(id year c) cluster(c) 
est sto t1_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 3: Total sample - Triple interaction
*------------------------------------------------------------------------------
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al ///
    netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, ///
    absorb(id year c) cluster(c) 
est sto t1_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Columns 4-9: Heterogeneity Analysis
*------------------------------------------------------------------------------

* Column 4: Non-Investment Grade
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al ///
    netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp ///
    if crinv==0, absorb(id year) cluster(c) 
est sto t1_m4

* Column 5: Investment Grade
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al ///
    netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp ///
    if crinv==1, absorb(id year) cluster(c) 
est sto t1_m5

* Column 6: Small Firms
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al ///
    netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp ///
    if sizebi==0, absorb(id year) cluster(c) 
est sto t1_m6

* Column 7: Large Firms
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al ///
    netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp ///
    if sizebi==1, absorb(id year) cluster(c) 
est sto t1_m7

* Column 8: Low External Finance Dependence
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al ///
    netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp ///
    if exfinbi==1, absorb(id year) cluster(c) 
est sto t1_m8

* Column 9: High External Finance Dependence
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al ///
    netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp ///
    if exfinbi==2, absorb(id year) cluster(c) 
est sto t1_m9

*------------------------------------------------------------------------------
* Export Table 1
*------------------------------------------------------------------------------
esttab t1_m1 t1_m2 t1_m3 t1_m4 t1_m5 t1_m6 t1_m7 t1_m8 t1_m9 ///
    using "Tables/Table1_CashHoldings.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    keep(FXBHassl c.FXBHassl#c.dlndtcr c.FXBHassl#c.sp4imp ///
         c.FXBHassl#c.dlndtcr#c.sp4imp DCBassl cfo2al osources2al ///
         forev2al netderiv2al qtob size debt2a ltdtd sales2a ///
         gdpgrowth privcreditovgdp lngdp c.dlndtcr#c.sp4imp sp4imp dlndtcr) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))
```

---

### Table 2: Investment, Foreign Bond Issuance, and Currency Depreciations

**Dependent variable**: Inv (capital expenditures scaled by lagged assets)

This table examines how firms adjust investment in response to foreign currency bond issuance and currency depreciations. The specification includes both contemporaneous and lagged values of the key variables.

```stata
********************************************************************************
* TABLE 2: Investment, foreign bond issuance, and currency depreciations
* Dependent variable: Inv (capex2al)
* Equation (2) in the paper
********************************************************************************

*------------------------------------------------------------------------------
* Column 1: Total sample - No interactions (samp for sample consistency)
*------------------------------------------------------------------------------
reghdfe capex2al FXBHassl l.FXBHassl DCBassl l.DCBassl cfo2al l.cfo2al ///
    osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al ///
    l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp samp, ///
    absorb(id year c) cluster(c) 
est sto t2_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 2: Total sample - Two-way interactions
*------------------------------------------------------------------------------
reghdfe capex2al c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp ///
    c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp ///
    DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al ///
    l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a ///
    l.gdpgrowth l.privcreditovgdp l.lngdp samp, ///
    absorb(id year c) cluster(c) 
est sto t2_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 3: Total sample - Triple interaction
*------------------------------------------------------------------------------
reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp ///
    c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp ///
    DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al ///
    forev2al l.forev2al netderiv2al l.netderiv2al ///
    l.size l.qtob l.debt2a l.ltdtd l.sales2a ///
    l.gdpgrowth l.privcreditovgdp l.lngdp, ///
    absorb(id year c) cluster(c) 
est sto t2_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Columns 4-9: Heterogeneity (crinv, sizebi, exfinbi) - use l.c.dlndtcr in lagged interactions
*------------------------------------------------------------------------------
* (Columns 4-9 omitted for brevity; same structure as Table 1 heterogeneity)

*------------------------------------------------------------------------------
* Export Table 2
*------------------------------------------------------------------------------
esttab t2_m1 t2_m2 t2_m3 t2_m4 t2_m5 t2_m6 t2_m7 t2_m8 t2_m9 ///
    using "Tables/Table2_Investment.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    keep(FXBHassl c.FXBHassl#c.dlndtcr c.FXBHassl#c.sp4imp c.FXBHassl#c.dlndtcr#c.sp4imp ///
         L.FXBHassl cL.FXBHassl#cL.dlndtcr cL.FXBHassl#cL.sp4imp cL.FXBHassl#cL.dlndtcr#cL.sp4imp ///
         DCBassl L.DCBassl cfo2al L.cfo2al osources2al L.osources2al L.forev2al L.netderiv2al ///
         L.qtob L.size L.debt2a L.ltdtd L.sales2a L.gdpgrowth L.privcreditovgdp L.lngdp) ///
    drop(oL.FXBHassl) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))
```

---

### Table 3: Alternative Investment Definitions

#### Panel A: Total Investment

**Dependent variable**: T.Inv (Total Investment = Capex + R&D + Acquisitions - Sale of Fixed Assets)

Following Richardson (2006). The variable `tinv2al` is created in Section 2 (with rd2al, acqu2al, sfa2al).

```stata
********************************************************************************
* TABLE 3 PANEL A: Total Investment (tinv2al)
********************************************************************************

*------------------------------------------------------------------------------
* Regressions for Panel A (9 columns; col 1 uses samp)
*------------------------------------------------------------------------------
reghdfe tinv2al FXBHassl l.FXBHassl DCBassl l.DCBassl ... samp, absorb(id year c) cluster(c)
est sto t3a_m1
* ... t3a_m2 (two-way), t3a_m3 (triple), t3a_m4-t3a_m9 (heterogeneity)

esttab t3a_m1 t3a_m2 t3a_m3 t3a_m4 t3a_m5 t3a_m6 t3a_m7 t3a_m8 t3a_m9 ///
    using "Tables/Table3_PanelA_TotalInvestment.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    keep(FXBHassl dlndtcr sp4imp c.FXBHassl#c.dlndtcr c.FXBHassl#c.sp4imp c.FXBHassl#c.dlndtcr#c.sp4imp ///
         L.FXBHassl L.dlndtcr L.sp4imp cL.FXBHassl#cL.dlndtcr cL.FXBHassl#cL.sp4imp cL.FXBHassl#cL.dlndtcr#cL.sp4imp) ///
    drop(oL.FXBHassl) stats(N r2 r2_a firm_fe year_fe, ...)
```

#### Panel B: Change in Working Capital

**Dependent variable**: ΔWC (Change in Working Capital scaled by lagged assets)

```stata
********************************************************************************
* TABLE 3 PANEL B: Change in Working Capital
********************************************************************************

* dwc2al created in Section 2. Panel B has 9 columns; col 1 uses samp.
reghdfe dwc2al FXBHassl l.FXBHassl DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp samp, absorb(id year c) cluster(c)
est sto t3b_m1
* ... t3b_m2 (two-way), t3b_m3 (triple), t3b_m4-t3b_m9 (heterogeneity)

esttab t3b_m1 t3b_m2 t3b_m3 t3b_m4 t3b_m5 t3b_m6 t3b_m7 t3b_m8 t3b_m9 ///
    using "Tables/Table3_PanelB_WorkingCapital.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    keep(FXBHassl dlndtcr sp4imp ...) drop(oL.FXBHassl) stats(N r2 r2_a firm_fe year_fe, ...)
```

---

### Table 4: Operating Performance and Competitiveness

Eight columns: Operating Income (1–2), Non-operating Income (3–4), Log Sales (5–6), Sales/Assets (7–8). Odd columns use double interactions; even columns use triple interaction. Variables `operoa`, `nonopincome`, `lnsales` are created in Section 2. Controls exclude TQ and sales2a.

```stata
********************************************************************************
* TABLE 4: USD-denominated bond issuance, currency depreciations, competitiveness
* Columns 1-2: operoa (double/triple) | 3-4: nonopincome | 5-6: lnsales | 7-8: sales2al
********************************************************************************

* Column 1: Operating Income - Double interactions
reghdfe operoa c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(year c id) cluster(c)
est sto t4_m1

* Column 2: Operating Income - Triple interaction
reghdfe operoa c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp ...
est sto t4_m2

* Columns 3-4: Non-operating Income (double/triple)
* Columns 5-6: Log Sales (double/triple)
* Columns 7-8: Sales to Assets (double/triple)

esttab t4_m1 t4_m2 t4_m3 t4_m4 t4_m5 t4_m6 t4_m7 t4_m8 ///
    using "Tables/Table4_Competitiveness.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    keep(FXBHassl sp4imp dlndtcr c.FXBHassl#c.dlndtcr c.FXBHassl#c.sp4imp c.FXBHassl#c.dlndtcr#c.sp4imp ///
         L.FXBHassl L.sp4imp L.dlndtcr cL.FXBHassl#cL.dlndtcr cL.FXBHassl#cL.sp4imp cL.FXBHassl#cL.dlndtcr#cL.sp4imp ///
         L.DCBassl L.cfo2al L.osources2al L.forev2al L.netderiv2al L.size L.debt2al L.ltdtd ...) ///
    drop(oL.FXBHassl) stats(N r2 r2_a firm_fe year_fe, ...)
```

---

## Appendix A: Variable Definitions and Summary Statistics

### Variable Definitions

| Variable | Definition |
|----------|------------|
| **FXBHA** | Foreign currency (USD) bond issuance scaled by lagged total assets |
| **DCBA** | Domestic currency bond issuance scaled by lagged total assets |
| **FXDep** | Demeaned log change in real exchange rate |
| **Sp** | Demeaned risk-adjusted spread (lending rate - US BAA yield) / implied volatility |
| **ΔCash** | Change in cash holdings scaled by lagged assets |
| **Inv** | Capital expenditures scaled by lagged assets |
| **T.Inv** | Total investment (Capex + R&D + Acquisitions - Asset Sales) / lagged assets |
| **ΔWC** | Change in working capital scaled by lagged assets |
| **CFO** | Cash flow from operations scaled by lagged assets |
| **Ofunds** | Other sources of funds scaled by lagged assets |
| **FRev** | Foreign revenue scaled by lagged assets |
| **NDer** | Net derivatives position scaled by lagged assets |
| **TQ** | Tobin's Q = (Market cap + Debt) / Assets |
| **TA** | Log of total assets |
| **DTA** | Debt to total assets ratio |
| **LTD** | Long-term debt to total debt ratio |
| **STA** | Sales to assets ratio |

### Table A2: Summary Statistics

The do-file writes **Table A2** to `Tables/TableA2_SummaryStats.tex` with **three panels** in the paper format: **Panel A** (Latin America, Europe, Africa — mean, S.D. by country), **Panel B** (Asia and total sample), **Panel C** (time-series: Sp, FXDep). Uses all variables from the paper (dcash, capex2al, tinv2al, dwc2al, operoa_ratio, nonopincome, lnsales, FXBHassl, DCBassl, cfo2al, osources2al, forev2al, netderiv2al, qtob, size, debt2a, ltdtd, sales2a, gdpgrowth, privcreditovgdp, lngdp). Custom file-writing with `file open/write/close`.

---

## Online Appendix

### Appendix B: Robustness Checks - Cash Holdings

#### Table B1: Sequential Covariates

This table shows how the main cash holdings results change as we sequentially add control variables.

```stata
*==============================================================================
* Table B1: Cash holdings (introducing covariates sequentially)
*==============================================================================

reghdfe dcash FXBHassl samp, absorb(id year) cluster(c) 
est sto b1_m1

reghdfe dcash c.FXBHassl##c.sp4imp, absorb(id year) cluster(c) 
est sto b1_m2

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp, absorb(id year) cluster(c) 
est sto b1_m3

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al, ///
    absorb(id year) cluster(c) 
est sto b1_m4

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al ///
    forev2al netderiv2al, absorb(id year) cluster(c) 
est sto b1_m5

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al ///
    forev2al netderiv2al qtob size debt2a ltdtd sales2a, ///
    absorb(id year) cluster(c) 
est sto b1_m6

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al ///
    forev2al netderiv2al qtob size debt2a ltdtd sales2a ///
    gdpgrowth privcreditovgdp lngdp, absorb(id year) cluster(c) 
est sto b1_m7

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al ///
    forev2al netderiv2al qtob size debt2a ltdtd sales2a, ///
    absorb(id yc) cluster(c) 
est sto b1_m8

esttab b1_m1 b1_m2 b1_m3 b1_m4 b1_m5 b1_m6 b1_m7 b1_m8 ///
    using "Tables/TableB1_Cash_Covariates.tex", replace ///
    fragment booktabs label nonotes noomit ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)") ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a firm_fe y_fe cy_fe, ...)
```

#### Table B2: Introducing Lags

Nine columns: Col 1–3 (total sample, L0–L2 lags, no/two-way/triple interactions); Col 4–9 (heterogeneity by crinv, sizebi, exfinbi). Uses `absorb(id year)` for heterogeneity columns.

```stata
* Table B2: Cash holding (Introducing Lags) - 9 columns
* Col 1: L0,L1,L2 no interactions | Col 2: two-way | Col 3: triple
* Col 4-9: heterogeneity (crinv, sizebi, exfinbi)
esttab b2_m1 b2_m2 b2_m3 b2_m4 b2_m5 b2_m6 b2_m7 b2_m8 b2_m9 ///
    using "Tables/TableB2_Cash_Lags.tex", replace ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)" "(9)") ///
    drop(oL.FXBHassl) stats(N r2 r2_a control firm_fe year_fe, ...)
```

#### Table B3: Country-Year-Industry Fixed Effects

Nine columns. `cye = group(pais year economic)`. Col 1–2 use `samp`; Col 3 omits netderiv2al; Col 4–9 heterogeneity; Col 8–9 use `[pw=w_c]` for exfinbi.

```stata
* Table B3: Cash holding (Country-Year-Industry Fixed Effects) - 9 columns
egen cye = group(pais year economic)
* Col 1: FXBHA + samp | Col 2: two-way + samp | Col 3: triple (no netderiv2al)
* Col 4-5: crinv | Col 6-7: sizebi | Col 8-9: exfinbi [pw=w_c]
esttab b3_m1 b3_m2 b3_m3 b3_m4 b3_m5 b3_m6 b3_m7 b3_m8 b3_m9 ///
    using "Tables/TableB3_Cash_CYI_FE.tex", replace ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)" "(9)") ///
    stats(N r2 r2_a firm_fe cyi_fe, ...)
```

#### Table B4: Alternative Depreciation (Dummy)

Uses `cursdepre` instead of continuous FXDep. Nine columns: Col 1–3 (total sample); Col 4–9 (heterogeneity).

```stata
* Table B4: Cash holding (Alternative Depreciation Definition - Dummy) - 9 columns
esttab b4_m1 b4_m2 b4_m3 b4_m4 b4_m5 b4_m6 b4_m7 b4_m8 b4_m9 ///
    using "Tables/TableB4_Cash_AltDepreciation.tex", replace ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)" "(9)") ///
    stats(N r2 r2_a firm_fe year_fe, ...)
```

#### Table B5: Hedging Heterogeneity

Four columns: Col 1–2 (fderiv==0, two-way/triple); Col 3–4 (fderiv==1). No `netderiv2al` in subsamples.

```stata
* Table B5: Cash holding and hedging derivatives heterogeneity - 4 columns
* fderiv: Uses Derivatives (1=Yes), defined from tliabderiv2al/tassetderiv2al
reghdfe dcash c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp ... if fderiv==0, absorb(id year c) cluster(c)
est sto b5_m1
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp ... if fderiv==0, absorb(id year c) cluster(c)
est sto b5_m2
reghdfe dcash c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp ... if fderiv==1, absorb(id year c) cluster(c)
est sto b5_m3
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp ... if fderiv==1, absorb(id year c) cluster(c)
est sto b5_m4

esttab b5_m1 b5_m2 b5_m3 b5_m4 using "Tables/TableB5_Cash_Hedging.tex", replace ///
    mtitles("(1)" "(2)" "(3)" "(4)") stats(N r2 r2_a firm_fe year_fe, ...)
```

---

### Appendix C: Robustness Checks - Investment

#### Table C1: Sequential Covariates

Eight columns: Col 1 (FXBHA + L.FXBHA + sampi); Col 2–3 (two-way/triple); Col 4–7 (add DCBA, CFO, Ofunds; FRev, NDer; firm controls; macro); Col 8 (Country-Year FE).

```stata
* Table C1: Investment (introducing covariates sequentially) - 8 columns
reghdfe capex2al FXBHassl l.FXBHassl sampi, absorb(id year) cluster(c)
est sto c1_m1
* Col 2: two-way | Col 3: triple | Col 4-7: sequential covariates | Col 8: absorb(id yc)
esttab c1_m1 c1_m2 c1_m3 c1_m4 c1_m5 c1_m6 c1_m7 c1_m8 ///
    using "Tables/TableC1_Investment_Covariates.tex", replace ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)") ///
    drop(oL.FXBHassl) stats(N r2 r2_a firm_fe y_fe cy_fe, ...)
```

#### Table C2: Introducing Additional Lags

Nine columns: L0–L3 lags. Col 1–3 (total sample); Col 4–9 (heterogeneity by crinv, sizebi, exfinbi).

```stata
* Table C2: Investment (Introducing Additional Lags) - 9 columns
esttab c2_m1 c2_m2 c2_m3 c2_m4 c2_m5 c2_m6 c2_m7 c2_m8 c2_m9 ///
    using "Tables/TableC2_Investment_Lags.tex", replace ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)" "(9)") ///
    drop(oL.FXBHassl) stats(N r2 r2_a control firm_fe year_fe, ...)
```

#### Table C3: Country-Year-Industry Fixed Effects

Nine columns. `cye = group(pais year economic)`. Col 1–2 use `samp`; Col 6–9 add `l.FXBHassl` for sizebi/exfinbi subsamples.

```stata
* Table C3: Investment (Country-Year-Industry Fixed Effects) - 9 columns
esttab c3_m1 c3_m2 c3_m3 c3_m4 c3_m5 c3_m6 c3_m7 c3_m8 c3_m9 ///
    using "Tables/TableC3_Investment_CYI_FE.tex", replace ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)" "(9)") ///
    drop(oL.FXBHassl) stats(N r2 r2_a firm_fe cyi_fe, ...)
```

#### Table C4: Alternative Depreciation (Dummy)

Nine columns. Uses `cursdepre` instead of FXDep. Col 1: baseline with `samp`; Col 2–3: double/triple; Col 4–9: heterogeneity. Col 6–9 add `l.FXBHassl`.

```stata
* Table C4: Investment (Alternative Depreciation Definition - Dummy) - 9 columns
esttab c4_m1 c4_m2 c4_m3 c4_m4 c4_m5 c4_m6 c4_m7 c4_m8 c4_m9 ///
    using "Tables/TableC4_Investment_AltDepreciation.tex", replace ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)" "(9)") ///
    drop(oL.FXBHassl) stats(N r2 r2_a firm_fe year_fe, ...)
```

#### Table C5: Hedging Heterogeneity

**Eight columns**: Col 1–4 (T.Inv, tinv2al) by fderiv and interaction type; Col 5–8 (ΔWC, dwc2al) by fderiv and interaction type. No `netderiv2al` in subsamples. Col 1, 2, 5, 7 use `samp` where applicable.

```stata
* Table C5: Investment and hedging derivatives heterogeneity - 8 columns
* Col 1-2: T.Inv, fderiv==0 (two-way/triple) | Col 3-4: T.Inv, fderiv==1
* Col 5-6: Delta WC, fderiv==0 | Col 7-8: Delta WC, fderiv==1
esttab c5_m1 c5_m2 c5_m3 c5_m4 c5_m5 c5_m6 c5_m7 c5_m8 ///
    using "Tables/TableC5_Investment_Hedging.tex", replace ///
    mtitles("(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)") ///
    drop(oL.FXBHassl) stats(N r2 r2_a firm_fe year_fe, ...)
```

---

### Appendix D: Local Projections

This section uses local projections to estimate impulse response functions for operating performance and competitiveness outcomes.

```stata
********************************************************************************
* APPENDIX D: Local Projections for Operating Performance and Competitiveness
********************************************************************************

* Note: This section requires the locproj package
* ssc install locproj

* Figures/ already created at start

* Generate interaction variables for local projections
gen FXBH_dlndtcr = FXBHassl * dlndtcr
gen FXBH_sp4imp = FXBHassl * sp4imp
gen L1_FXBH_dlndtcr = L1.FXBHassl * L1.dlndtcr
gen L1_FXBH_sp4imp = L1.FXBHassl * L1.sp4imp

local controls "L1.DCBassl L1.cfo2al L1.osources2al L1.forev2al L1.netderiv2al ///
    L1.size L1.debt2al L1.ltdtd L1.gdpgrowth L1.privcreditovgdp L1.lngdp"

*------------------------------------------------------------------------------
* Operating Income IRF
*------------------------------------------------------------------------------
locproj operoa FXBHassl FXBH_dlndtcr FXBH_sp4imp L1_FXBH_dlndtcr L1_FXBH_sp4imp ///
    dlndtcr sp4imp L1.dlndtcr L1.sp4imp `controls', ///
    met(reghdfe) absorb(id yc) vce(cluster c) ///
    yl(2) sl(2) h(0/8)
graph rename Graph operating_income_irf, replace
graph save "Figures/operating_income_irf.gph", replace
graph export "Figures/operating_income_irf.pdf", replace

*------------------------------------------------------------------------------
* Non-operating Income IRF
*------------------------------------------------------------------------------
locproj nonopincome FXBHassl FXBH_dlndtcr FXBH_sp4imp L1_FXBH_dlndtcr L1_FXBH_sp4imp ///
    dlndtcr sp4imp L1.dlndtcr L1.sp4imp `controls', ///
    met(reghdfe) absorb(id yc) vce(cluster c) ///
    yl(2) sl(2) h(0/8)
graph rename Graph nonoperating_income_irf, replace
graph save "Figures/nonoperating_income_irf.gph", replace
graph export "Figures/nonoperating_income_irf.pdf", replace

*------------------------------------------------------------------------------
* Log Sales IRF
*------------------------------------------------------------------------------
locproj lnsales FXBHassl FXBH_dlndtcr FXBH_sp4imp L1_FXBH_dlndtcr L1_FXBH_sp4imp ///
    dlndtcr sp4imp L1.dlndtcr L1.sp4imp `controls', ///
    met(reghdfe) absorb(id yc) vce(cluster c) ///
    yl(2) sl(2) h(0/8)
graph rename Graph log_sales_irf, replace
graph save "Figures/log_sales_irf.gph", replace
graph export "Figures/log_sales_irf.pdf", replace

*------------------------------------------------------------------------------
* Sales-to-Assets Ratio IRF (sales2al = sales/assetsl)
*------------------------------------------------------------------------------
locproj sales2al FXBHassl FXBH_dlndtcr FXBH_sp4imp L1_FXBH_dlndtcr L1_FXBH_sp4imp ///
    dlndtcr sp4imp L1.dlndtcr L1.sp4imp `controls', ///
    met(reghdfe) absorb(id yc) vce(cluster c) ///
    yl(2) sl(2) h(0/8)
graph rename Graph sales_assets_irf, replace
graph save "Figures/sales_assets_irf.gph", replace
graph export "Figures/sales_assets_irf.pdf", replace
```

---

## Software Requirements

- **Stata**: Version 17 or higher recommended
- **Required packages**: reghdfe, ftools, estout, winsor2, locproj

## Output Files

| Output | Description |
|--------|-------------|
| `replication_log.txt` | Full Stata log |
| `Tables/Table1_CashHoldings.tex` | Main Table 1 |
| `Tables/Table2_Investment.tex` | Main Table 2 |
| `Tables/Table3_PanelA_TotalInvestment.tex` | Main Table 3 Panel A |
| `Tables/Table3_PanelB_WorkingCapital.tex` | Main Table 3 Panel B |
| `Tables/Table4_Competitiveness.tex` | Main Table 4 |
| `Tables/TableA2_SummaryStats.tex` | Appendix A2 |
| `Tables/TableB1_Cash_Covariates.tex` through `TableB5_Cash_Hedging.tex` | Appendix B |
| `Tables/TableC1_Investment_Covariates.tex` through `TableC5_Investment_Hedging.tex` | Appendix C |
| `Figures/operating_income_irf.pdf`, `nonoperating_income_irf.pdf`, `log_sales_irf.pdf`, `sales_assets_irf.pdf` | Appendix D IRFs |

---

*This replication code was generated for the paper "Currency Mismatches in Emerging Markets: Effects on Corporate Liquidity, Investment Dynamics and Performance" by José De Gregorio, Luis P. de la Horra, and Mauricio Jara.*
