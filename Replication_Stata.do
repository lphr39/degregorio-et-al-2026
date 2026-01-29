********************************************************************************
* REPLICATION FILE
* Currency Mismatches in Emerging Markets:
* Effects on Corporate Liquidity, Investment Dynamics and Performance
*
* Authors: José De Gregorio, Luis P. de la Horra, Mauricio Jara
*
* This file replicates all tables in the paper following the same structure
* and order as in main.tex
*
* REQUIRED FILES IN FOLDER:
*   - data/dataset_jie.dta (main dataset)
*   - data/Issuance Firm-Year.dta (bond issuance data)
*   - data/exrates.dta (exchange rate data)
*
* OUTPUTS (created automatically):
*   - replication_log.txt (root)
*   - Tables/*.tex (LaTeX tables)
*   - Figures/*.pdf, *.gph (local projection graphs)
*
* REQUIRED STATA PACKAGES (install via ssc install):
*   - reghdfe (high-dimensional fixed effects regression)
*   - estout (esttab, eststo, estadd commands for table export)
*   - winsor2 (winsorization)
*   - locproj (local projections - for Appendix D only)
*   - ftools (required by reghdfe)
********************************************************************************

********************************************************************************
* SECTION 0: INSTALL REQUIRED PACKAGES (if not already installed)
********************************************************************************

* These packages are required. The capture prefix ensures no error if already installed.
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

* Create output folders (Tables, Figures) if they do not exist
cap mkdir "Tables"
cap mkdir "Figures"

*------------------------------------------------------------------------------
* Check if processed dataset already exists with required variables
* If so, skip to Section 2 to save time and avoid needing exrates.dta
*------------------------------------------------------------------------------

capture confirm file "./data/dataset_jie_reg.dta"
if !_rc {
    * File exists - check if it has the key variables
    use "./data/dataset_jie_reg.dta", clear
    capture confirm variable lndtcr sp4imp FXBHassl
    if !_rc {
        di as text "==> dataset_jie_reg.dta found with all required variables."
        di as text "==> Skipping data creation and going to Section 2."
        goto section2
    }
}

di as text "==> Building dataset from raw files..."

*------------------------------------------------------------------------------
* 1.1 Load main dataset and merge auxiliary data
*------------------------------------------------------------------------------

use "./data/dataset_jie.dta", clear
encode tick, gen(id)

* Merge issuance data
merge m:m key year using "./data/Issuance Firm-Year.dta" 
duplicates drop id year, force
drop _merge

* Merge exchange rate data (REQUIRED - obtain from original data source)
merge m:m isocode year using "./data/exrates.dta" 
drop if fy==""
drop _merge

* Set panel structure
xtset id year
sort id year

*------------------------------------------------------------------------------
* 1.2 Equity and Sample Cleaning
*------------------------------------------------------------------------------

* Equity = Assets - Liabilities
gen equity = assets - liabilities 
drop if equity < 0

*------------------------------------------------------------------------------
* 1.3 Foreign Currency Bond Issuance Variables (FXBHA)
*------------------------------------------------------------------------------

* Label lagged assets
label variable assetsl "Lagged total Assets"

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

*------------------------------------------------------------------------------
* 1.4 Control Variables
*------------------------------------------------------------------------------

* Leverage (Debt to total assets) - DTA
gen debt2a = debt / assets
label variable debt2a "DTA (Debt/Assets)"

gen debt2al = debt / assetsl

* Size (log of assets) - TA
gen size = ln(assets)
gen lnsales = ln(sales)
label variable size "TA (Size - Log Assets)"
winsor2 size, replace cuts(1 99) trim

*------------------------------------------------------------------------------
* 1.5 Sources of Funds Variables
*------------------------------------------------------------------------------

* Cash Flow from Operations - CFO
gen cfo2a = operatingcash / assets
gen cfo2al = operatingcash / assetsl
label variable cfo2al "CFO (Operating Cash Flow / Lagged Assets)"

* Components of total sources
gen salefa2a = salefixasset / assets
gen salefa2al = salefixasset / assetsl
gen stdebtiss2a = stdebtissued / assets
gen stdebtiss2al = stdebtissued / assetsl
gen ltdebtiss2a = ltdebtissued / assets
gen ltdebtiss2al = ltdebtissued / assetsl
gen stockiss2a = stockissued / assets
gen stockiss2al = stockissued / assetsl

winsor2 stdebtiss2a stdebtiss2al ltdebtiss2a ltdebtiss2al stockiss2a stockiss2al salefa2a salefa2al, replace cuts(1 99)

* Total sources
gen totsources = cfo2a + salefa2a + stdebtiss2a + ltdebtiss2a + stockiss2a
gen totsourcesl = cfo2al + salefa2al + stdebtiss2al + ltdebtiss2al + stockiss2al

winsor2 totsources totsourcesl, replace cuts(1 99)

* Other sources of funds - Ofunds
gen osources2a = totsources - FXBHass - DCBass - cfo2a
gen osources2al = totsourcesl - FXBHassl - DCBassl - cfo2al
label variable osources2al "Ofunds (Other Sources of Funds)"

winsor2 osources2a osources2al, replace cuts(1 99)

* Long term debt ratio - LTD
gen ltdtd = ltdebt / debt
label variable ltdtd "LTD (Long-Term Debt / Total Debt)"

* Sales to Assets ratio - STA
gen sales2a = sales / assets
gen sales2al = sales / assetsl
label variable sales2a "STA (Sales/Assets)"

* Tobin's Q - TQ
gen qtob = (marketcap + debt) / assets
winsor2 qtob sales2a sales2al, replace cuts(1 99) trim
label variable qtob "TQ (Tobin's Q)"

*------------------------------------------------------------------------------
* 1.6 Fixed Effects Variables
*------------------------------------------------------------------------------

* Country-year fixed effects
egen yc = group(pais year)

* Country fixed effects
egen c = group(pais)

* Short-term debt
gen stdebt = abs(debt - ltdebt)
gen stdebtl = abs(debtl - ltdebtl)
gen stchg2a = (stdebt - stdebtl) / assets
gen stchg2al = (stdebt - stdebtl) / assetsl

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

* ROA and related
gen roa = netincome / assets
gen roal = netincome / assetsl
gen ebit2a = ebit / assets
gen ebit2al = ebit / l.assets
gen tat = roal - cfo2al
gen ebitda2a = ebitda / assets

*------------------------------------------------------------------------------
* 1.8 Derivatives Variables (for hedging analysis)
*------------------------------------------------------------------------------

* Derivatives Assets
gen stassetderiv2al = derivcassets / assetsl
gen ltassetderiv2al = derivncassets / assetsl
gen tassetderiv2al = stassetderiv2al + ltassetderiv2al
replace tassetderiv2al = 0 if tassetderiv2al < 0

* Derivatives Liabilities
gen stliabderiv2al = derivcliab / assetsl
gen ltliabderiv2al = derivncliab / assetsl
gen tliabderiv2al = stliabderiv2al + ltliabderiv2al
replace tliabderiv2al = 0 if tliabderiv2al < 0

* Net Derivatives Position - NDer
gen netderiv2al = tassetderiv2al - tliabderiv2al
label variable netderiv2al "NDer (Net Derivatives Position)"

* Foreign Revenue Exposure - FRev
gen forev2al = forrev / assetsl
label variable forev2al "FRev (Foreign Revenue / Lagged Assets)"

*------------------------------------------------------------------------------
* 1.9 Winsorization of Key Variables
*------------------------------------------------------------------------------

winsor2 roal, replace cuts(1 99) trim
winsor2 capex2al cash2al cash2a dcash, replace cuts(1 99) trim
winsor2 cfo2al, replace cuts(1 99) trim
winsor2 debt2a, replace cuts(1 99) trim
winsor2 ebit2a ebit2al tat, replace cuts(1 99) trim
winsor2 ebitda2a, replace cuts(1 99) trim
winsor2 stassetderiv2al ltassetderiv2al tassetderiv2al stliabderiv2al ltliabderiv2al tliabderiv2al netderiv2al, replace cuts(1 99) trim
winsor2 forev2al, replace cuts(1 99) trim

replace forev2al = 0 if forev2al < 0

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

* Cash flow income
gen depre = ebitda - ebit
gen cfinc2a = (netincome + depre) / assets
winsor2 cfinc2a, replace cuts(1 99)

* Fixed Effects only for 2009-2015
egen ycqe = group(year pais) if year > 2008 & year < 2015

*------------------------------------------------------------------------------
* 1.11 Macroeconomic Variables
*------------------------------------------------------------------------------

* GDP per capita (log)
gen lngdp = ln(gdppc)
label variable lngdp "ln(GDP) per capita"

* Private credit to GDP
sum privcreditovgdp marketcapovgdp 
replace privcreditovgdp = privcreditovgdp / 100
replace marketcapovgdp = marketcapovgdp / 100
label variable privcreditovgdp "PrivCredit/GDP"

* Gross capital formation
replace gcf = gcf / 1000000000
gen lngcf = ln(gcf)
gen lngcf1 = ln(1 + gcf)

* Inflation
gen infl = inflation / 100

* Dummy variables for year and country
tab year, gen(year_)
tab pais, gen(p_)
tab business, gen(bus_)

*------------------------------------------------------------------------------
* 1.12 Risk-Adjusted Spread (Sp) - Key moderating variable
*------------------------------------------------------------------------------

* Implied volatility adjustment
replace impliedvolatility = impliedvolatility / 100

* Spread: Lending rate minus US BAA corporate bond yield
gen spread2 = (tasaborrow - baa) / 100

* Country-year means
egen impliedvolatilitym = mean(impliedvolatility), by(pais year)
egen spread2m = mean(spread2), by(pais year)

replace impliedvolatility = impliedvolatilitym
replace spread2 = spread2m

* Risk-adjusted spread: Spread / Implied Volatility
gen spread2imp = spread2 / impliedvolatility
replace spread2imp = 0 if spread2imp == .
label variable spread2imp "Raw Spread (unadjusted)"

gen fxalspread2imp = FXBHassl * spread2imp

* Generate demeaned spread (sp4imp) - Main spread variable in paper
* First run a regression to define the sample
reghdfe dcash FXBHassl fxalspread2imp DCBassl cfo2al osources2al size qtob debt2a ltdtd sales2a, absorb(id yc) cluster(c)

* Country-level demeaning
bys pais: egen sp_mean2 = mean(spread2imp) if e(sample)
replace sp_mean2 = 0 if sp_mean2 == . & e(sample)
gen sp3imp = spread2imp - sp_mean2 if e(sample)
replace sp3imp = 0 if sp3imp == . & e(sample)
drop sp_mean2 

gen fxalspc3 = FXBHassl * sp3imp

* Global demeaning for sp4imp (main variable)
egen sp_mean2 = mean(spread2imp) if e(sample)
replace sp_mean2 = 0 if sp_mean2 == . & e(sample)
gen sp4imp = spread2imp - sp_mean2 if e(sample)
replace sp4imp = 0 if sp4imp == . & e(sample)
drop sp_mean2
label variable sp4imp "Sp (Demeaned Risk-Adjusted Spread)"

* Interactions with spread
gen fxalspc4imp = FXBHassl * sp4imp 
gen fxalndcr = FXBHassl * lndtcr
gen fxalndcrspc4imp = fxalspc4imp * lndtcr

*------------------------------------------------------------------------------
* 1.13 Heterogeneity Variables
*------------------------------------------------------------------------------

* Credit Rating Heterogeneity (1: Investment Grade; 0: Non-Investment Grade)
gen crinv = 0
replace crinv = 1 if cratsc < 11
label variable crinv "Investment Grade (1=Yes)"

* Size Heterogeneity (Firm Average based) by Country
egen sizem = mean(size), by(id)
egen sizec = mean(size), by(c)
egen sizeb = mean(size), by(c eco)
gen sizeci = 0
replace sizeci = 1 if sizem > sizec
gen sizebi = 0
replace sizebi = 1 if sizem > sizeb
xtile dsize = sizem, nq(2)
label variable sizebi "Large Firm (1=Above median size)"

* Industry-level External Finance Dependence
* (Capital expenditures - CFO) / Lagged total assets
* (1: lower External finance dependence; 2: higher external finance dependence)
gen exfin = capex2al - cfo2al
egen exfinind = mean(exfin), by(c eco)
xtile exfinbi = exfinind, nq(2)
egen econ = group(economic)
label variable exfinbi "External Finance Dependence (1=Low, 2=High)"

*------------------------------------------------------------------------------
* 1.14 Sample Definition
*------------------------------------------------------------------------------

* Cash holding sample
sort id year
reghdfe dcash FXBHassl fxalspc4imp DCBassl cfo2al osources2al size qtob debt2a ltdtd sales2a, absorb(id yc) cluster(c)
gen samp = 1 if e(sample)

* Investment sample
sort id year
reghdfe capex2al FXBHassl l.FXBHassl l.fxalspc4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.size l.qtob l.debt2a l.ltdtd l.sales2a, absorb(id yc) cluster(c)
gen sampi = 1 if e(sample)

*------------------------------------------------------------------------------
* 1.15 Save cleaned dataset
*------------------------------------------------------------------------------

save "./data/dataset_jie_reg.dta", replace


********************************************************************************
* SECTION 2: ADDITIONAL VARIABLE DEFINITIONS (for Tables 3 and 4)
* These variables are defined in the estimates file
********************************************************************************

section2:

clear all
use "./data/dataset_jie_reg.dta", clear
xtset id year
sort id year
drop lnsales

*------------------------------------------------------------------------------
* 2.1 FX Depreciation Variable (demeaned) - FXDep
*------------------------------------------------------------------------------

* Generate demeaned log change in real exchange rate
egen mdepr = mean(lndtcr)
gen dlndtcr = lndtcr - mdepr
label variable dlndtcr "FXDep (Demeaned Log Change in Real Exchange Rate)"

*------------------------------------------------------------------------------
* 2.2 Weighting Variables
*------------------------------------------------------------------------------

gen aux1 = 1

* Country-Year weights
egen cy_freq = sum(aux1), by(c year) 
gen w_cy = 1 / cy_freq
gen w_rcy = 1 / ((cy_freq)^(1/2))

* Country weights
egen c_freq = sum(aux1), by(c) 
gen w_c = 1 / c_freq
gen w_rc = 1 / ((c_freq)^(1/2))

*------------------------------------------------------------------------------
* 2.3 Foreign Revenue and Derivatives Cleaning
*------------------------------------------------------------------------------

replace forev2al = 0 if forev2al > 0.99
replace forev2al = 0 if forev2al == .
replace netderiv2al = 0 if netderiv2al == .

* Derivatives at firm level (for hedging heterogeneity analysis)
gen deriv = 0
replace deriv = 1 if tliabderiv2al != 0
replace deriv = 1 if tassetderiv2al != 0
egen mderiv = mean(deriv), by(id)
gen fderiv = 0
replace fderiv = 1 if mderiv != 0
label variable fderiv "Uses Derivatives (1=Yes)"

* Foreign revenue indicator
egen mforev = mean(forev2al), by(id)
gen fforev = 0
replace fforev = 1 if mforev != 0
label variable fforev "Has Foreign Revenue (1=Yes)"

*------------------------------------------------------------------------------
* 2.4 Total Investment Definition (for Table 3, Panel A)
* Following Richardson (2006): Capex + R&D + Acquisitions - Sales of Fixed Assets
*------------------------------------------------------------------------------

gen rd2al = rdexp / assetsl
label variable rd2al "R&D / Lagged Assets"

gen acqu2al = abs(acquisitionofbusiness) / assetsl
replace acqu2al = 0 if acqu2al == .
label variable acqu2al "Acquisitions / Lagged Assets"

gen sfa2al = saleoffixedassets / assetsl
replace sfa2al = 0 if sfa2al == .
label variable sfa2al "Sale of Fixed Assets / Lagged Assets"

gen chginv2al = chginventories / assetsl

* Operating ROA
gen operoa = operatingmargin * assetturnover
label variable operoa "Operating Income"

* Change in inventories
gen dinvent2al = (totalinventory - lagtotalinventory) / assetsl

* Change in working capital (for Table 3, Panel B)
gen dwc2al = changesinworkingcapital / assetsl
label variable dwc2al "ΔWC (Change in Working Capital)"

winsor2 rd2al acqu2al sfa2al roaref chginv2al operoa pretaxroa dinvent2al dwc2al, replace cuts(1 99) trim

* Total Investment (T.Inv) = Capex + R&D + Acquisitions - Sale of Fixed Assets
gen inv2al = capex2al + rd2al + acqu2al - sfa2al
gen tinv2al = inv2al
winsor2 tinv2al, replace cuts(1 99) trim
label variable tinv2al "T.Inv (Total Investment)"

*------------------------------------------------------------------------------
* 2.5 Currency Depreciation Dummy (Alternative specification)
*------------------------------------------------------------------------------

gen cursdepre = 1 if lndtcusd > 0
replace cursdepre = 0 if cursdepre == .
label variable cursdepre "Depreciation Dummy (1=Depreciation)"

winsor2 debt2al, replace cuts(1 99) trim

*------------------------------------------------------------------------------
* 2.6 Country-Year-Industry Fixed Effects
*------------------------------------------------------------------------------

egen cyi = group(pais year business)  
egen cye = group(pais year economic)  
egen cy = group(pais year)

*------------------------------------------------------------------------------
* 2.7 Additional Performance Variables (for Table 4)
*------------------------------------------------------------------------------

* Non-operating income
* Note: This may need to be constructed if not in the dataset
capture confirm variable nonopincome
if _rc {
    capture confirm variable pretaxroa operoa
    if !_rc {
        gen nonopincome = (pretaxroa - operoa/100) if !missing(pretaxroa) & !missing(operoa)
    }
}
label variable nonopincome "Non-operating Income"

* Log Sales
gen lnsales = ln(sales) if sales > 0
label variable lnsales "ln(Sales)"

* Operating income adjustment
replace operoa = operoa * 100
winsor2 operoa, replace cuts(1 99) trim

replace chginv2al = 0 if chginv2al == .

*------------------------------------------------------------------------------
* 2.8 Save final dataset
*------------------------------------------------------------------------------

save "./data/dataset_jie_reg.dta", replace

********************************************************************************
* END OF VARIABLE DEFINITIONS
********************************************************************************


********************************************************************************
********************************************************************************
*                         MAIN BODY TABLES
********************************************************************************
********************************************************************************

********************************************************************************
* TABLE 1: Cash holdings, foreign bond issuance, and currency depreciations
* Dependent variable: ΔCash (dcash)
* Equation (1) in the paper
********************************************************************************

*------------------------------------------------------------------------------
* Column 1: Total sample - No interactions
*------------------------------------------------------------------------------
reghdfe dcash FXBHassl DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year c) cluster(c) 
est sto t1_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 2: Total sample - Two-way interactions
*------------------------------------------------------------------------------
reghdfe dcash c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year c) cluster(c) 
est sto t1_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 3: Total sample - Triple interaction
*------------------------------------------------------------------------------
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year c) cluster(c) 
est sto t1_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 4: Non-Investment Grade
*------------------------------------------------------------------------------
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp if crinv==0, absorb(id year) cluster(c) 
est sto t1_m4
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 5: Investment Grade
*------------------------------------------------------------------------------
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp if crinv==1, absorb(id year) cluster(c) 
est sto t1_m5
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 6: Small Firms (Size below median)
*------------------------------------------------------------------------------
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp if sizebi==0, absorb(id year) cluster(c) 
est sto t1_m6
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 7: Large Firms (Size above median)
*------------------------------------------------------------------------------
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp if sizebi==1, absorb(id year) cluster(c) 
est sto t1_m7
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 8: Low External Finance Dependence
*------------------------------------------------------------------------------
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp if exfinbi==1, absorb(id year) cluster(c) 
est sto t1_m8
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 9: High External Finance Dependence
*------------------------------------------------------------------------------
reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp if exfinbi==2, absorb(id year) cluster(c) 
est sto t1_m9
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Export Table 1
*------------------------------------------------------------------------------
esttab t1_m1 t1_m2 t1_m3 t1_m4 t1_m5 t1_m6 t1_m7 t1_m8 t1_m9 using "Tables/Table1_CashHoldings.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    keep(FXBHassl c.FXBHassl#c.dlndtcr c.FXBHassl#c.sp4imp c.FXBHassl#c.dlndtcr#c.sp4imp ///
         DCBassl cfo2al osources2al forev2al netderiv2al qtob size debt2a ltdtd sales2a ///
         gdpgrowth privcreditovgdp lngdp c.dlndtcr#c.sp4imp sp4imp dlndtcr) ///
    order(FXBHassl c.FXBHassl#c.dlndtcr c.FXBHassl#c.sp4imp c.FXBHassl#c.dlndtcr#c.sp4imp ///
         DCBassl cfo2al osources2al forev2al netderiv2al qtob size debt2a ltdtd sales2a ///
         gdpgrowth privcreditovgdp lngdp c.dlndtcr#c.sp4imp sp4imp dlndtcr) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))


********************************************************************************
* TABLE 2: Investment, foreign bond issuance, and currency depreciations
* Dependent variable: Inv (capex2al)
* Equation (2) in the paper
********************************************************************************

*------------------------------------------------------------------------------
* Column 1: Total sample - No interactions
*------------------------------------------------------------------------------
reghdfe capex2al FXBHassl l.FXBHassl DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto t2_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 2: Total sample - Two-way interactions
*------------------------------------------------------------------------------
reghdfe capex2al c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto t2_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 3: Total sample - Triple interaction
*------------------------------------------------------------------------------
reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto t2_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 4: Non-Investment Grade
*------------------------------------------------------------------------------
reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if crinv==0, absorb(id year c) cluster(c) 
est sto t2_m4
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 5: Investment Grade
*------------------------------------------------------------------------------
reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if crinv==1, absorb(id year c) cluster(c) 
est sto t2_m5
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 6: Small Firms
*------------------------------------------------------------------------------
reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if sizebi==0, absorb(id year c) cluster(c) 
est sto t2_m6
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 7: Large Firms
*------------------------------------------------------------------------------
reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if sizebi==1, absorb(id year c) cluster(c) 
est sto t2_m7
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 8: Low External Finance Dependence
*------------------------------------------------------------------------------
reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if exfinbi==1, absorb(id year c) cluster(c) 
est sto t2_m8
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 9: High External Finance Dependence
*------------------------------------------------------------------------------
reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if exfinbi==2, absorb(id year c) cluster(c) 
est sto t2_m9
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Export Table 2
*------------------------------------------------------------------------------
esttab t2_m1 t2_m2 t2_m3 t2_m4 t2_m5 t2_m6 t2_m7 t2_m8 t2_m9 using "Tables/Table2_Investment.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    keep(FXBHassl c.FXBHassl#c.dlndtcr c.FXBHassl#c.sp4imp c.FXBHassl#c.dlndtcr#c.sp4imp ///
         L.FXBHassl cL.FXBHassl#cL.dlndtcr cL.FXBHassl#cL.sp4imp cL.FXBHassl#cL.dlndtcr#cL.sp4imp ///
         DCBassl L.DCBassl cfo2al L.cfo2al osources2al L.osources2al L.forev2al L.netderiv2al ///
         L.qtob L.size L.debt2a L.ltdtd L.sales2a L.gdpgrowth L.privcreditovgdp L.lngdp) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))


********************************************************************************
* TABLE 3: Alternative investment definition, working capital, and currency 
*          depreciations
* Panel A: Total Investment (tinv2al)
* Panel B: Change in Working Capital (dwc2al)
* Equation (3) in the paper
********************************************************************************

*==============================================================================
* PANEL A: Total Investment (T.Inv)
*==============================================================================

*------------------------------------------------------------------------------
* Column 1: Total sample - No interactions
*------------------------------------------------------------------------------
reghdfe tinv2al FXBHassl l.FXBHassl DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto t3a_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 2: Total sample - Two-way interactions
*------------------------------------------------------------------------------
reghdfe tinv2al c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto t3a_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 3: Total sample - Triple interaction
*------------------------------------------------------------------------------
reghdfe tinv2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto t3a_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 4: Non-Investment Grade
*------------------------------------------------------------------------------
reghdfe tinv2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if crinv==0, absorb(id year c) cluster(c) 
est sto t3a_m4
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 5: Investment Grade
*------------------------------------------------------------------------------
reghdfe tinv2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if crinv==1, absorb(id year c) cluster(c) 
est sto t3a_m5
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 6: Small Firms
*------------------------------------------------------------------------------
reghdfe tinv2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if sizebi==0, absorb(id year c) cluster(c) 
est sto t3a_m6
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 7: Large Firms
*------------------------------------------------------------------------------
reghdfe tinv2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if sizebi==1, absorb(id year c) cluster(c) 
est sto t3a_m7
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 8: Low External Finance Dependence
*------------------------------------------------------------------------------
reghdfe tinv2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if exfinbi==1, absorb(id year c) cluster(c) 
est sto t3a_m8
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 9: High External Finance Dependence
*------------------------------------------------------------------------------
reghdfe tinv2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if exfinbi==2, absorb(id year c) cluster(c) 
est sto t3a_m9
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Export Table 3 Panel A
*------------------------------------------------------------------------------
esttab t3a_m1 t3a_m2 t3a_m3 t3a_m4 t3a_m5 t3a_m6 t3a_m7 t3a_m8 t3a_m9 using "Tables/Table3_PanelA_TotalInvestment.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    keep(FXBHassl dlndtcr sp4imp c.FXBHassl#c.dlndtcr c.FXBHassl#c.sp4imp c.FXBHassl#c.dlndtcr#c.sp4imp ///
         L.FXBHassl L.dlndtcr L.sp4imp cL.FXBHassl#cL.dlndtcr cL.FXBHassl#cL.sp4imp cL.FXBHassl#cL.dlndtcr#cL.sp4imp) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))

*==============================================================================
* PANEL B: Change in Working Capital (ΔWC)
*==============================================================================

*------------------------------------------------------------------------------
* Column 1: Total sample - No interactions
*------------------------------------------------------------------------------
reghdfe dwc2al FXBHassl l.FXBHassl DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto t3b_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 2: Total sample - Two-way interactions
*------------------------------------------------------------------------------
reghdfe dwc2al c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto t3b_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 3: Total sample - Triple interaction
*------------------------------------------------------------------------------
reghdfe dwc2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto t3b_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 4: Non-Investment Grade
*------------------------------------------------------------------------------
reghdfe dwc2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if crinv==0, absorb(id year c) cluster(c) 
est sto t3b_m4
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 5: Investment Grade
*------------------------------------------------------------------------------
reghdfe dwc2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if crinv==1, absorb(id year c) cluster(c) 
est sto t3b_m5
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 6: Small Firms
*------------------------------------------------------------------------------
reghdfe dwc2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if sizebi==0, absorb(id year c) cluster(c) 
est sto t3b_m6
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 7: Large Firms
*------------------------------------------------------------------------------
reghdfe dwc2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if sizebi==1, absorb(id year c) cluster(c) 
est sto t3b_m7
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 8: Low External Finance Dependence
*------------------------------------------------------------------------------
reghdfe dwc2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if exfinbi==1, absorb(id year c) cluster(c) 
est sto t3b_m8
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Column 9: High External Finance Dependence
*------------------------------------------------------------------------------
reghdfe dwc2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if exfinbi==2, absorb(id year c) cluster(c) 
est sto t3b_m9
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Export Table 3 Panel B
*------------------------------------------------------------------------------
esttab t3b_m1 t3b_m2 t3b_m3 t3b_m4 t3b_m5 t3b_m6 t3b_m7 t3b_m8 t3b_m9 using "Tables/Table3_PanelB_WorkingCapital.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    keep(FXBHassl dlndtcr sp4imp c.FXBHassl#c.dlndtcr c.FXBHassl#c.sp4imp c.FXBHassl#c.dlndtcr#c.sp4imp ///
         L.FXBHassl L.dlndtcr L.sp4imp cL.FXBHassl#cL.dlndtcr cL.FXBHassl#cL.sp4imp cL.FXBHassl#cL.dlndtcr#cL.sp4imp) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))


********************************************************************************
* TABLE 4: USD-denominated bond issuance, currency depreciations, and 
*          competitiveness
* Dependent variables: Operating Income, Non-operating Income, ln(Sales), 
*                      Sales/Assets
* Equation (3) in the paper
********************************************************************************

*------------------------------------------------------------------------------
* Columns 1-2: Operating Income (operoa)
*------------------------------------------------------------------------------
reghdfe operoa c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(year c id) cluster(c)
est sto t4_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe operoa c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(year c id) cluster(c)
est sto t4_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Columns 3-4: Non-operating Income (nonopincome)
*------------------------------------------------------------------------------
reghdfe nonopincome c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(year c id) cluster(c)
est sto t4_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe nonopincome c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(year c id) cluster(c)
est sto t4_m4
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Columns 5-6: Log Sales (lnsales)
*------------------------------------------------------------------------------
reghdfe lnsales c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(year c id) cluster(c)
est sto t4_m5
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe lnsales c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(year c id) cluster(c)
est sto t4_m6
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Columns 7-8: Sales to Assets ratio (sales2al)
*------------------------------------------------------------------------------
reghdfe sales2al c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(year c id) cluster(c)
est sto t4_m7
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe sales2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp l.DCBassl l.cfo2al l.osources2al l.forev2al l.netderiv2al l.size l.debt2al l.ltdtd l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(year c id) cluster(c)
est sto t4_m8
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

*------------------------------------------------------------------------------
* Export Table 4
*------------------------------------------------------------------------------
esttab t4_m1 t4_m2 t4_m3 t4_m4 t4_m5 t4_m6 t4_m7 t4_m8 using "Tables/Table4_Competitiveness.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    keep(FXBHassl sp4imp dlndtcr c.FXBHassl#c.dlndtcr c.FXBHassl#c.sp4imp c.FXBHassl#c.dlndtcr#c.sp4imp ///
         L.FXBHassl L.sp4imp L.dlndtcr cL.FXBHassl#cL.dlndtcr cL.FXBHassl#cL.sp4imp cL.FXBHassl#cL.dlndtcr#cL.sp4imp ///
         L.DCBassl L.cfo2al L.osources2al L.forev2al L.netderiv2al L.size L.debt2al L.ltdtd ///
         L.gdpgrowth L.privcreditovgdp L.lngdp) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))


********************************************************************************
********************************************************************************
*                         APPENDIX A
*              Variable Definitions and Summary Statistics
********************************************************************************
********************************************************************************

* Note: Appendix A contains variable definitions (Table A1) and summary 
* statistics (Table A2). These are descriptive tables generated from the 
* variable definitions above.

*------------------------------------------------------------------------------
* Summary Statistics (Table A2)
* Paper has two panels: (1) General (full sample), (2) By country.
*------------------------------------------------------------------------------

* Operating ROA as ratio for summary (paper uses 0.xx); operoa is stored as %.
gen operoa_ratio = operoa / 100

* Panel 1 - General (full sample)
estpost summarize cash2al capex2al cfo2al operoa_ratio roal FXBHassl DCBassl ///
    osources2al size qtob debt2a ltdtd sales2a dlndtcr sp4imp, detail

esttab using "Tables/TableA2_SummaryStats_General.tex", replace ///
    cells("count mean sd min p25 p50 p75 max") ///
    noobs nomtitle nonumber

* Panel 2 - By country (mean, sd, N per country)
estpost tabstat cash2al capex2al cfo2al operoa_ratio roal FXBHassl DCBassl ///
    osources2al size qtob debt2a ltdtd sales2a, ///
    by(pais) stat(mean sd count) nototal columns(statistics)

esttab using "Tables/TableA2_SummaryStats_ByCountry.tex", replace ///
    cells("mean(fmt(3)) sd(fmt(3)) count(fmt(0))") ///
    noobs nomtitle nonumber

drop operoa_ratio


********************************************************************************
********************************************************************************
*                         ONLINE APPENDIX
********************************************************************************
********************************************************************************

********************************************************************************
* APPENDIX B: Robustness Checks - Cash Holdings Regressions
********************************************************************************

*==============================================================================
* Table B1: Cash holdings (introducing covariates sequentially)
*==============================================================================

reghdfe dcash FXBHassl samp, absorb(id year) cluster(c) 
est sto b1_m1
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe dcash c.FXBHassl##c.sp4imp, absorb(id year) cluster(c) 
est sto b1_m2
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp, absorb(id year) cluster(c) 
est sto b1_m3
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al, absorb(id year) cluster(c) 
est sto b1_m4
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al, absorb(id year) cluster(c) 
est sto b1_m5
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al qtob size debt2a ltdtd sales2a, absorb(id year) cluster(c) 
est sto b1_m6
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al qtob size debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year) cluster(c) 
est sto b1_m7
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al qtob size debt2a ltdtd sales2a, absorb(id yc) cluster(c) 
est sto b1_m8
estadd loc firm_fe "Yes"
estadd loc y_fe "No"	
estadd loc cy_fe "Yes"	

esttab b1_m1 b1_m2 b1_m3 b1_m4 b1_m5 b1_m6 b1_m7 b1_m8 using "Tables/TableB1_Cash_Covariates.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a firm_fe y_fe cy_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
    label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE" "Country-Year FE"))

*==============================================================================
* Table B2: Cash holding (Introducing Lags)
*==============================================================================

reghdfe dcash FXBHassl l.FXBHassl l2.FXBHassl DCBassl l.DCBassl l2.DCBassl cfo2al l.cfo2al l2.cfo2al osources2al l.osources2al l2.osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year c) cluster(c) 
est sto b2_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"
estadd loc control "Yes"

reghdfe dcash c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp l.(c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp) l2.(c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp) DCBassl l.DCBassl l2.DCBassl cfo2al l.cfo2al l2.cfo2al osources2al l.osources2al l2.osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year c) cluster(c) 
est sto b2_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"
estadd loc control "Yes"

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp l.(c.FXBHassl##c.dlndtcr##c.sp4imp) l2.(c.FXBHassl##c.dlndtcr##c.sp4imp) DCBassl l.DCBassl l2.DCBassl cfo2al l.cfo2al l2.cfo2al osources2al l.osources2al l2.osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year c) cluster(c) 
est sto b2_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"
estadd loc control "Yes"

esttab b2_m1 b2_m2 b2_m3 using "Tables/TableB2_Cash_Lags.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a control firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Control Var." "Firm FE" "Year FE"))

*==============================================================================
* Table B3: Cash holding (Country-Year-Industry Fixed Effects)
*==============================================================================

reghdfe dcash FXBHassl DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a, absorb(id cye) cluster(c) 
est sto b3_m1
estadd loc firm_fe "Yes"
estadd loc cyi_fe "Yes"	

reghdfe dcash c.FXBHassl##c.sp4imp c.FXBHassl##c.dlndtcr DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a, absorb(id cye) cluster(c) 
est sto b3_m2
estadd loc firm_fe "Yes"
estadd loc cyi_fe "Yes"	

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al forev2al netderiv2al osources2al size qtob debt2a ltdtd sales2a, absorb(id cye) cluster(c) 
est sto b3_m3
estadd loc firm_fe "Yes"
estadd loc cyi_fe "Yes"	

esttab b3_m1 b3_m2 b3_m3 using "Tables/TableB3_Cash_CYI_FE.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a firm_fe cyi_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Country-Year-Industry FE"))

*==============================================================================
* Table B4: Cash holding (Alternative Depreciation Definition - Dummy)
*==============================================================================

reghdfe dcash FXBHassl DCBassl cfo2al osources2al forev2al sp4imp cursdepre netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year c) cluster(c) 
est sto b4_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe dcash c.FXBHassl##c.cursdepre c.FXBHassl##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year c) cluster(c) 
est sto b4_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe dcash c.FXBHassl##c.cursdepre##c.sp4imp DCBassl cfo2al osources2al forev2al netderiv2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year c) cluster(c) 
est sto b4_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

esttab b4_m1 b4_m2 b4_m3 using "Tables/TableB4_Cash_AltDepreciation.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))

*==============================================================================
* Table B5: Cash holding and hedging derivatives heterogeneity
*==============================================================================

* No derivatives
reghdfe dcash c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp DCBassl cfo2al osources2al forev2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp if fderiv==0, absorb(id year c) cluster(c) 
est sto b5_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp if fderiv==0, absorb(id year c) cluster(c) 
est sto b5_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

* Uses derivatives
reghdfe dcash c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp DCBassl cfo2al osources2al forev2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp if fderiv==1, absorb(id year c) cluster(c) 
est sto b5_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe dcash c.FXBHassl##c.dlndtcr##c.sp4imp DCBassl cfo2al osources2al forev2al size qtob debt2a ltdtd sales2a gdpgrowth privcreditovgdp lngdp if fderiv==1, absorb(id year c) cluster(c) 
est sto b5_m4
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

esttab b5_m1 b5_m2 b5_m3 b5_m4 using "Tables/TableB5_Cash_Hedging.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))


********************************************************************************
* APPENDIX C: Robustness Checks - Investment Regressions
********************************************************************************

*==============================================================================
* Table C1: Investment (introducing covariates sequentially)
*==============================================================================

reghdfe capex2al FXBHassl l.FXBHassl sampi, absorb(id year) cluster(c) 
est sto c1_m1
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe capex2al c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp, absorb(id year) cluster(c) 
est sto c1_m2
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp, absorb(id year) cluster(c) 
est sto c1_m3
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al, absorb(id year) cluster(c) 
est sto c1_m4
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al, absorb(id year) cluster(c) 
est sto c1_m5
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a, absorb(id year) cluster(c) 
est sto c1_m6
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a gdpgrowth privcreditovgdp lngdp, absorb(id year) cluster(c) 
est sto c1_m7
estadd loc firm_fe "Yes"
estadd loc y_fe "Yes"	
estadd loc cy_fe "No"	

reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##l.c.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a, absorb(id yc) cluster(c) 
est sto c1_m8
estadd loc firm_fe "Yes"
estadd loc y_fe "No"	
estadd loc cy_fe "Yes"	

esttab c1_m1 c1_m2 c1_m3 c1_m4 c1_m5 c1_m6 c1_m7 c1_m8 using "Tables/TableC1_Investment_Covariates.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a firm_fe y_fe cy_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE" "Country-Year FE"))

*==============================================================================
* Table C2: Investment (Introducing Additional Lags)
*==============================================================================

reghdfe capex2al FXBHassl l.FXBHassl l2.FXBHassl l3.FXBHassl DCBassl l.DCBassl l2.DCBassl l3.DCBassl cfo2al l.cfo2al l2.cfo2al l3.cfo2al osources2al l.osources2al l2.osources2al l3.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto c2_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"
estadd loc control "Yes"

reghdfe capex2al c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp l.(c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp) l2.(c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp) l3.(c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp) DCBassl l.DCBassl l2.DCBassl l3.DCBassl cfo2al l.cfo2al l2.cfo2al l3.cfo2al osources2al l.osources2al l2.osources2al l3.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto c2_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"
estadd loc control "Yes"

reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp l.(c.FXBHassl##c.dlndtcr##c.sp4imp) l2.(c.FXBHassl##c.dlndtcr##c.sp4imp) l3.(c.FXBHassl##c.dlndtcr##c.sp4imp) DCBassl l.DCBassl l2.DCBassl l3.DCBassl cfo2al l.cfo2al l2.cfo2al l3.cfo2al osources2al l.osources2al l2.osources2al l3.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto c2_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"
estadd loc control "Yes"

esttab c2_m1 c2_m2 c2_m3 using "Tables/TableC2_Investment_Lags.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a control firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Control Var." "Firm FE" "Year FE"))

*==============================================================================
* Table C3: Investment (Country-Year-Industry Fixed Effects)
*==============================================================================

reghdfe capex2al FXBHassl l.FXBHassl DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a, absorb(id cye) cluster(c) 
est sto c3_m1
estadd loc firm_fe "Yes"
estadd loc cyi_fe "Yes"

reghdfe capex2al c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a, absorb(id cye) cluster(c) 
est sto c3_m2
estadd loc firm_fe "Yes"
estadd loc cyi_fe "Yes"

reghdfe capex2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a, absorb(id cye) cluster(c) 
est sto c3_m3
estadd loc firm_fe "Yes"
estadd loc cyi_fe "Yes"

esttab c3_m1 c3_m2 c3_m3 using "Tables/TableC3_Investment_CYI_FE.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a firm_fe cyi_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Country-Year-Industry FE"))

*==============================================================================
* Table C4: Investment (Alternative Depreciation Definition - Dummy)
*==============================================================================

reghdfe capex2al c.FXBHassl##c.cursdepre c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.cursdepre c.l.FXBHassl##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto c4_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe capex2al c.FXBHassl##c.cursdepre##c.sp4imp c.l.FXBHassl##c.l.cursdepre##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al forev2al l.forev2al netderiv2al l.netderiv2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp, absorb(id year c) cluster(c) 
est sto c4_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

esttab c4_m1 c4_m2 using "Tables/TableC4_Investment_AltDepreciation.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))

*==============================================================================
* Table C5: Investment and hedging derivatives heterogeneity
*==============================================================================

* No derivatives - Total Investment
reghdfe tinv2al c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if fderiv==0, absorb(id year c) cluster(c) 
est sto c5_m1
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe tinv2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if fderiv==0, absorb(id year c) cluster(c) 
est sto c5_m2
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

* Uses derivatives - Total Investment
reghdfe tinv2al c.FXBHassl##c.dlndtcr c.FXBHassl##c.sp4imp c.l.FXBHassl##c.l.dlndtcr c.l.FXBHassl##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if fderiv==1, absorb(id year c) cluster(c) 
est sto c5_m3
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

reghdfe tinv2al c.FXBHassl##c.dlndtcr##c.sp4imp c.l.FXBHassl##c.l.dlndtcr##c.l.sp4imp DCBassl l.DCBassl cfo2al l.cfo2al osources2al l.osources2al l.forev2al l.size l.qtob l.debt2a l.ltdtd l.sales2a l.gdpgrowth l.privcreditovgdp l.lngdp if fderiv==1, absorb(id year c) cluster(c) 
est sto c5_m4
estadd loc firm_fe "Yes"
estadd loc year_fe "Yes"

esttab c5_m1 c5_m2 c5_m3 c5_m4 using "Tables/TableC5_Investment_Hedging.tex", replace ///
    fragment booktabs label nonotes noomit nomtitles collabels(none) ///
    star(* 0.1 ** 0.05 *** 0.01) b(%9.3f) se(%9.3f) ///
    stats(N r2 r2_a firm_fe year_fe, fmt(%9.0fc %9.3f %9.3f %9s %9s) ///
          label("Observations" "R-squared" "Adj. R-squared" "Firm FE" "Year FE"))


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

local controls "L1.DCBassl L1.cfo2al L1.osources2al L1.forev2al L1.netderiv2al L1.size L1.debt2al L1.ltdtd L1.gdpgrowth L1.privcreditovgdp L1.lngdp"

*------------------------------------------------------------------------------
* Operating Income IRF
*------------------------------------------------------------------------------
locproj operoa FXBHassl FXBH_dlndtcr FXBH_sp4imp L1_FXBH_dlndtcr L1_FXBH_sp4imp dlndtcr sp4imp L1.dlndtcr L1.sp4imp `controls', ///
    met(reghdfe) absorb(id yc) vce(cluster c) ///
    yl(2) sl(2) h(0/8)
graph rename Graph operating_income_irf, replace
graph save "Figures/operating_income_irf.gph", replace
graph export "Figures/operating_income_irf.pdf", replace

*------------------------------------------------------------------------------
* Non-operating Income IRF
*------------------------------------------------------------------------------
locproj nonopincome FXBHassl FXBH_dlndtcr FXBH_sp4imp L1_FXBH_dlndtcr L1_FXBH_sp4imp dlndtcr sp4imp L1.dlndtcr L1.sp4imp `controls', ///
    met(reghdfe) absorb(id yc) vce(cluster c) ///
    yl(2) sl(2) h(0/8)
graph rename Graph nonoperating_income_irf, replace
graph save "Figures/nonoperating_income_irf.gph", replace
graph export "Figures/nonoperating_income_irf.pdf", replace

*------------------------------------------------------------------------------
* Log Sales IRF
*------------------------------------------------------------------------------
locproj lnsales FXBHassl FXBH_dlndtcr FXBH_sp4imp L1_FXBH_dlndtcr L1_FXBH_sp4imp dlndtcr sp4imp L1.dlndtcr L1.sp4imp `controls', ///
    met(reghdfe) absorb(id yc) vce(cluster c) ///
    yl(2) sl(2) h(0/8)
graph rename Graph log_sales_irf, replace
graph save "Figures/log_sales_irf.gph", replace
graph export "Figures/log_sales_irf.pdf", replace

*------------------------------------------------------------------------------
* Sales-to-Assets Ratio IRF
*------------------------------------------------------------------------------
locproj sales2al FXBHassl FXBH_dlndtcr FXBH_sp4imp L1_FXBH_dlndtcr L1_FXBH_sp4imp dlndtcr sp4imp L1.dlndtcr L1.sp4imp `controls', ///
    met(reghdfe) absorb(id yc) vce(cluster c) ///
    yl(2) sl(2) h(0/8)
graph rename Graph sales_assets_irf, replace
graph save "Figures/sales_assets_irf.gph", replace
graph export "Figures/sales_assets_irf.pdf", replace


********************************************************************************
* END OF REPLICATION FILE
********************************************************************************

log close

