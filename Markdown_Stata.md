# Code for Replication

## Currency Mismatches in Emerging Markets: Effects on Corporate Liquidity, Investment Dynamics and Performance

**Authors:** José De Gregorio, Luis P. de la Horra, Mauricio Jara

---

## Introduction

This appendix provides the Stata code to replicate all tables and figures in the paper *"Currency Mismatches in Emerging Markets: Effects on Corporate Liquidity, Investment Dynamics and Performance"*.

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
label variable sales2a "STA (Sales/Assets)"
```

#### Dependent Variables

```stata
*------------------------------------------------------------------------------
* 1.7 Dependent Variables
*------------------------------------------------------------------------------

* Delta Cash (Change in Cash Holdings) - Main dependent variable for Table 1
gen cash2al = cashst / assetsl
gen dcash = (cashst - cashstl) / assetsl
label variable dcash "ΔCash (Change in Cash Holdings)"

* Investment (Capital Expenditures) - Main dependent variable for Table 2
gen capex2al = abs(capex / assetsl)
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
gen spread2imp = spread2 / impliedvolatility
replace spread2imp = 0 if spread2imp == .

* Generate demeaned spread (sp4imp) - Main spread variable in paper
reghdfe dcash FXBHassl fxalspread2imp DCBassl cfo2al osources2al size qtob debt2a ltdtd sales2a, ///
    absorb(id yc) cluster(c)

egen sp_mean2 = mean(spread2imp) if e(sample)
gen sp4imp = spread2imp - sp_mean2 if e(sample)
replace sp4imp = 0 if sp4imp == . & e(sample)
drop sp_mean2
label variable sp4imp "Sp (Demeaned Risk-Adjusted Spread)"
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
* Column 1: Total sample - No interactions
*------------------------------------------------------------------------------
reghdfe capex2al FXBHassl l.FXBHassl DCBassl l.DCBassl cfo2al l.cfo2al ///
    osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al ///
    l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, ///
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
    l.gdpgrowth l.privcreditovgdp l.lngdp, ///
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
* Export Table 2
*------------------------------------------------------------------------------
esttab t2_m1 t2_m2 t2_m3 t2_m4 t2_m5 t2_m6 t2_m7 t2_m8 t2_m9 ///
    using "Tables/Table2_Investment.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))
```

---

### Table 3: Alternative Investment Definitions

#### Panel A: Total Investment

**Dependent variable**: T.Inv (Total Investment = Capex + R&D + Acquisitions - Sale of Fixed Assets)

Following Richardson (2006), we use a broader measure of investment that includes R&D expenditures and acquisitions.

```stata
********************************************************************************
* TABLE 3 PANEL A: Total Investment
********************************************************************************

* Total Investment Definition
gen rd2al = rdexp / assetsl
gen acqu2al = abs(acquisitionofbusiness) / assetsl
replace acqu2al = 0 if acqu2al == .
gen sfa2al = saleoffixedassets / assetsl
replace sfa2al = 0 if sfa2al == .

* T.Inv = Capex + R&D + Acquisitions - Sale of Fixed Assets
gen tinv2al = capex2al + rd2al + acqu2al - sfa2al
winsor2 tinv2al, replace cuts(1 99) trim
label variable tinv2al "T.Inv (Total Investment)"

*------------------------------------------------------------------------------
* Regressions for Panel A
*------------------------------------------------------------------------------
reghdfe tinv2al c.FXBHassl##c.dlndtcr##c.sp4imp ///
    c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp ///
    DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al ///
    forev2al l.forev2al netderiv2al l.netderiv2al ///
    l.size l.qtob l.debt2a l.ltdtd l.sales2a ///
    l.gdpgrowth l.privcreditovgdp l.lngdp, ///
    absorb(id year c) cluster(c) 
est sto t3a_m3

esttab t3a_m1 t3a_m2 t3a_m3 t3a_m4 t3a_m5 t3a_m6 t3a_m7 t3a_m8 t3a_m9 ///
    using "Tables/Table3_PanelA_TotalInvestment.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

#### Panel B: Change in Working Capital

**Dependent variable**: ΔWC (Change in Working Capital scaled by lagged assets)

```stata
********************************************************************************
* TABLE 3 PANEL B: Change in Working Capital
********************************************************************************

gen dwc2al = changesinworkingcapital / assetsl
label variable dwc2al "ΔWC (Change in Working Capital)"

reghdfe dwc2al c.FXBHassl##c.dlndtcr##c.sp4imp ///
    c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp ///
    DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al ///
    forev2al l.forev2al netderiv2al l.netderiv2al ///
    l.size l.qtob l.debt2a l.ltdtd l.sales2a ///
    l.gdpgrowth l.privcreditovgdp l.lngdp, ///
    absorb(id year c) cluster(c) 

esttab t3b_m1 t3b_m2 t3b_m3 t3b_m4 t3b_m5 t3b_m6 t3b_m7 t3b_m8 t3b_m9 ///
    using "Tables/Table3_PanelB_WorkingCapital.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

---

### Table 4: Operating Performance and Competitiveness

This table examines the effects on operating performance (Operating Income, Non-operating Income) and competitiveness (Sales measures).

```stata
********************************************************************************
* TABLE 4: USD-denominated bond issuance, currency depreciations, and 
*          competitiveness
********************************************************************************

* Operating ROA
gen operoa = operatingmargin * assetturnover
replace operoa = operoa * 100
winsor2 operoa, replace cuts(1 99) trim
label variable operoa "Operating Income"

* Log Sales
gen lnsales = ln(sales) if sales > 0
label variable lnsales "ln(Sales)"

*------------------------------------------------------------------------------
* Columns 1-2: Operating Income
*------------------------------------------------------------------------------
reghdfe operoa c.FXBHassl##c.dlndtcr##c.sp4imp ///
    c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp ///
    l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al ///
    l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, ///
    absorb(year c id) cluster(c)
est sto t4_m2

*------------------------------------------------------------------------------
* Columns 3-4: Non-operating Income
*------------------------------------------------------------------------------
reghdfe nonopincome c.FXBHassl##c.dlndtcr##c.sp4imp ///
    c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp ///
    l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al ///
    l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, ///
    absorb(year c id) cluster(c)
est sto t4_m4

*------------------------------------------------------------------------------
* Columns 5-6: Log Sales
*------------------------------------------------------------------------------
reghdfe lnsales c.FXBHassl##c.dlndtcr##c.sp4imp ///
    c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp ///
    l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al ///
    l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, ///
    absorb(year c id) cluster(c)
est sto t4_m6

*------------------------------------------------------------------------------
* Export Table 4
*------------------------------------------------------------------------------
esttab t4_m1 t4_m2 t4_m3 t4_m4 t4_m5 t4_m6 t4_m7 t4_m8 ///
    using "Tables/Table4_Competitiveness.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
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

The paper reports summary statistics in **two panels**: (1) **General** — full sample; (2) **By country** — mean, S.D., and N per country. The do-file writes each panel to a separate `.tex` file.

```stata
********************************************************************************
* APPENDIX A: Summary Statistics (Table A2)
* Panel 1: General (full sample). Panel 2: By country.
********************************************************************************

gen operoa_ratio = operoa / 100

* Panel 1 - General (full sample)
estpost summarize cash2al capex2al cfo2al operoa_ratio roal FXBHassl DCBassl ///
    osources2al size qtob debt2a ltdtd sales2a dlndtcr sp4imp, detail

esttab using "Tables/TableA2_SummaryStats_General.tex", replace ///
    cells("count mean sd min p25 p50 p75 max") noobs nomtitle nonumber

* Panel 2 - By country (mean, sd, N per country)
estpost tabstat cash2al capex2al cfo2al operoa_ratio roal FXBHassl DCBassl ///
    osources2al size qtob debt2a ltdtd sales2a, ///
    by(pais) stat(mean sd count) nototal columns(statistics)

esttab using "Tables/TableA2_SummaryStats_ByCountry.tex", replace ///
    cells("mean(fmt(3)) sd(fmt(3)) count(fmt(0))") noobs nomtitle nonumber

drop operoa_ratio
```

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
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

#### Table B2: Introducing Lags

Adds lags (and second lags) of FXBHA, DCBA, CFO, and other sources.

```stata
* Table B2: Cash holding (Introducing Lags)
reghdfe dcash FXBHassl l.FXBHassl l2.FXBHassl DCBassl l.DCBassl l2.DCBassl ///
    cfo2al l.cfo2al l2.cfo2al osources2al l.osources2al l2.osources2al ///
    forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, ///
    absorb(id year c) cluster(c)
est sto b2_m1

reghdfe dcash c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp ///
    l.(c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp) l2.(c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp) ///
    DCBassl l.DCBassl l2.DCBassl cfo2al l.cfo2al l2.cfo2al osources2al l.osources2al l2.osources2al ///
    forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, ///
    absorb(id year c) cluster(c)
est sto b2_m2

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp ///
    l.(c.FXBHassl##c.dlndtcr##c.sp4imp) l2.(c.FXBHassl##c.dlndtcr##c.sp4imp) ///
    DCBassl l.DCBassl l2.DCBassl cfo2al l.cfo2al l2.cfo2al osources2al l.osources2al l2.osources2al ///
    forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, ///
    absorb(id year c) cluster(c)
est sto b2_m3

esttab b2_m1 b2_m2 b2_m3 using "Tables/TableB2_Cash_Lags.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

#### Table B3: Country-Year-Industry Fixed Effects

```stata
*==============================================================================
* Table B3: Cash holding (Country-Year-Industry Fixed Effects)
*==============================================================================

egen cye = group(pais year economic)  

reghdfe dcash FXBHassl DCBassl cfo2al osources2al forev2al netderiv2al ///
    size qtob debt2a ltdtd sales2a, absorb(id cye) cluster(c) 
est sto b3_m1

reghdfe dcash c.FXBHassl##c.sp4imp c.FXBHassl##c.dlndtcr DCBassl cfo2al ///
    osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a, ///
    absorb(id cye) cluster(c) 
est sto b3_m2

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al forev2al ///
    netderiv2al osources2al size qtob debt2a ltdtd sales2a, ///
    absorb(id cye) cluster(c) 
est sto b3_m3

esttab b3_m1 b3_m2 b3_m3 using "Tables/TableB3_Cash_CYI_FE.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

#### Table B4: Alternative Depreciation (Dummy)

Uses a depreciation dummy instead of the continuous FXDep measure.

```stata
* Table B4: Cash holding (Alternative Depreciation Definition - Dummy)
reghdfe dcash FXBHassl DCBassl cfo2al osources2al forev2al sp4imp cursdepre ///
    netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, ///
    absorb(id year c) cluster(c)
est sto b4_m1

reghdfe dcash c.FXBHassl##c.cursdepre c.FXBHassl##c.sp4imp DCBassl cfo2al ///
    osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a ///
    gdpgrowth privcreditovgdp lngdp, absorb(id year c) cluster(c)
est sto b4_m2

reghdfe dcash c.FXBHassl##c.cursdepre##c.sp4imp DCBassl cfo2al osources2al ///
    forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, ///
    absorb(id year c) cluster(c)
est sto b4_m3

esttab b4_m1 b4_m2 b4_m3 using "Tables/TableB4_Cash_AltDepreciation.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

#### Table B5: Hedging Heterogeneity

```stata
*==============================================================================
* Table B5: Cash holding and hedging derivatives heterogeneity
*==============================================================================

* Define derivatives user indicator
gen deriv = 0
replace deriv = 1 if tliabderiv2al != 0
replace deriv = 1 if tassetderiv2al != 0
egen mderiv = mean(deriv), by(id)
gen fderiv = 0
replace fderiv = 1 if mderiv != 0
label variable fderiv "Uses Derivatives (1=Yes)"

* No derivatives
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al ///
    size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp ///
    if fderiv==0, absorb(id year c) cluster(c) 
est sto b5_m2

* Uses derivatives
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al ///
    size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp ///
    if fderiv==1, absorb(id year c) cluster(c) 
est sto b5_m4

esttab b5_m1 b5_m2 b5_m3 b5_m4 using "Tables/TableB5_Cash_Hedging.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

---

### Appendix C: Robustness Checks - Investment

#### Table C1: Sequential Covariates

```stata
*==============================================================================
* Table C1: Investment (introducing covariates sequentially)
*==============================================================================

reghdfe capex2al FXBHassl l.FXBHassl sampi, absorb(id year) cluster(c) 
est sto c1_m1

reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp ///
    c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp, absorb(id year) cluster(c) 
est sto c1_m3

reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp ///
    c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp ///
    DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al ///
    l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a ///
    gdpgrowth privcreditovgdp lngdp, absorb(id year) cluster(c) 
est sto c1_m7

esttab c1_m1 c1_m2 c1_m3 c1_m4 c1_m5 c1_m6 c1_m7 c1_m8 ///
    using "Tables/TableC1_Investment_Covariates.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

#### Table C2: Introducing Additional Lags

Adds second and third lags of FXBHA, DCBA, CFO, and other sources (investment sample).

```stata
* Table C2: Investment (Introducing Additional Lags)
reghdfe capex2al FXBHassl l.FXBHassl l2.FXBHassl l3.FXBHassl DCBassl l.DCBassl l2.DCBassl l3.DCBassl ///
    cfo2al l.cfo2al l2.cfo2al l3.cfo2al osources2al l.osources2al l2.osources2al l3.osources2al ///
    l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, ///
    absorb(id year c) cluster(c)
est sto c2_m1
* ... c2_m2, c2_m3 (two- and three-way interactions with lags)
esttab c2_m1 c2_m2 c2_m3 using "Tables/TableC2_Investment_Lags.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

#### Table C3: Country-Year-Industry Fixed Effects

Investment regressions with country–year–industry FE instead of year FE.

```stata
* Table C3: Investment (Country-Year-Industry Fixed Effects)
reghdfe capex2al FXBHassl l.FXBHassl DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al ///
    forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a, ///
    absorb(id cye) cluster(c)
est sto c3_m1
* ... c3_m2, c3_m3 (interactions; absorb id cye)
esttab c3_m1 c3_m2 c3_m3 using "Tables/TableC3_Investment_CYI_FE.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

#### Table C4: Alternative Depreciation (Dummy)

Investment regressions using a depreciation dummy instead of continuous FXDep.

```stata
* Table C4: Investment (Alternative Depreciation Definition - Dummy)
reghdfe capex2al c.FXBHassl##c.cursdepre c.FXBHassl##c.sp4imp ///
    c.l.FXBHassl##c.l.cursdepre c.l.FXBHassl##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al ///
    osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a ///
    l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c)
est sto c4_m1
* ... c4_m2 (triple interaction with cursdepre)
esttab c4_m1 c4_m2 using "Tables/TableC4_Investment_AltDepreciation.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
```

#### Table C5: Hedging Heterogeneity

Investment (total investment) regressions by derivatives use: no derivatives vs. uses derivatives.

```stata
* Table C5: Investment and hedging derivatives heterogeneity
* No derivatives: tinv2al, fderiv==0 → c5_m1, c5_m2
* Uses derivatives: tinv2al, fderiv==1 → c5_m3, c5_m4
esttab c5_m1 c5_m2 c5_m3 c5_m4 using "Tables/TableC5_Investment_Hedging.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f)
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
* Sales-to-Assets Ratio IRF
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

---

*This replication code was generated for the paper "Currency Mismatches in Emerging Markets: Effects on Corporate Liquidity, Investment Dynamics and Performance" by José De Gregorio, Luis P. de la Horra, and Mauricio Jara.*
