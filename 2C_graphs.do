///////////////////////////////////////////
//////////////// 2C: GRAPHS ///////////////
/////////////////////////////////////////// 
clear 
di "current user: `c(username)'"
if "`c(username)'" == "matthewshaffer" {
	global dir "/Users/matthewshaffer/Dropbox" 
}
else if "`c(username)'" == "jackzhou" {
	global dir "/Users/jackzhou/Dropbox" 
}
else if "`c(username)'" == "davidcai" {
	global dir "/Users/davidcai/Dropbox" 
}

    
cd "$dir/Equity vs. Enterprise"
global datadir "Data"                       
global tabdir "Tables" 	
global graphdir "Graphs"	
global originaldata "Data/Original Data"
global tempfiles "Data/tempfiles"

/////////////////////////////////////////// 
/////////////////////////////////////////// 

use "$datadir/1D_labeled_dataset", clear

drop if year == 2020 //because there's not enough obs 

// generating the binary variables for the categories
gen equity = 0
replace equity = 1 if v_numerator == "equity"
gen enterprise = 0
replace enterprise = 1 if v_numerator == "enterprise"

// generating the proportions by year
bys year: gen equityProportion = sum(equity) / _N
bys year: replace equityProportion = equityProportion[_N]
bys year: gen enterpriseProportion = sum(enterprise) / _N
bys year: replace enterpriseProportion = enterpriseProportion[_N] + equityProportion

// labeling
label var equityProportion "Equity Value"
label var enterpriseProportion "Enterprise Value"

// export
twoway (area enterpriseProportion year, color(gs13)) (area equityProportion year, color(gs4)), xlabel(2000 (3) 2019) ylabel(0 (.2) 1) yscale(r(0 1))
graph export "$graphdir/enterprise_vs_equity.jpg", as(jpg) name("Graph") quality(100) replace
