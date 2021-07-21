///////////////////////////////////////////
///// 2B: Create Summary Statistics ///// 
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
global originaldata "Data/Original Data"
global tempfiles "Data/tempfiles"	

/////////////////////////////////////////// 
/////////////////////////////////////////// 

use "$datadir/1D_labeled_dataset", clear

/////////////////////////////////////////// 
/////////////////////////////////////////// 

//=============================================================================================
// Table 1: Industry Denom Frequency Table
//============================================================================================= 

eststo clear
	eststo I5: estpost tabulate v_numerator if SIC_Industry == 5
	eststo I1: estpost tabulate v_numerator if SIC_Industry == 1
	eststo I2: estpost tabulate v_numerator if SIC_Industry == 2
	eststo I3: estpost tabulate v_numerator if SIC_Industry == 3
	eststo I6: estpost tabulate v_numerator if SIC_Industry == 6
	eststo I7: estpost tabulate v_numerator if SIC_Industry == 7
	eststo I8: estpost tabulate v_numerator if SIC_Industry == 8
	eststo I9: estpost tabulate v_numerator if SIC_Industry == 9
	eststo I10: estpost tabulate v_numerator if SIC_Industry == 10
	eststo I11: estpost tabulate v_numerator if SIC_Industry == 11
	esttab I5 I1 I2 I3 I6 I7 I8 I9 I10 I11 using "${tabdir}/industry_valuation.tex", replace cells("b(label(freq)) pct(label(percent) fmt(%10.1f))") mtit("\textit{Manufacturing}" "\textit{Agriculture}" "\textit{Mining}" "\textit{Construction}" "\textit{Transportation}" "\textit{Wholesale}" "\textit{Retail}" "\textit{Finance}" "\textit{Services}" "\textit{Public Admin.}") nonumber label substitute(\_ _)
eststo clear


//=============================================================================================
// Table 3: Deal Characteristics
//=============================================================================================


gen financial_acquiror_ind = 0
replace financial_acquiror_ind = 1 if FinancialAcquiror == "Yes"
label var financial_acquiror_ind "\textit{Financial Acquiror}"

label var ofCash "\textit{\% of Cash}"

global deal_vars "going_private financial_acquiror_ind cash_deal stock_deal ofCash acq_public premium"

duplicates drop sdc_deal_no, force // so that the deal-level summary stats are based on unique deals. 
	eststo clear 	
	eststo target: estpost summarize $deal_vars
	esttab target using "${tabdir}/deal_summary_stats.tex", replace ///
	cell((mean(fmt(%9.2f)) sd(fmt(%9.2f)) min(fmt(%9.2f)) max(fmt(%9.2f)) )) nomtitle nonumber  label


//=============================================================================================
// Table 4: Target Characteristics
//=============================================================================================

global tar_vars "ROA leverage ni_margin analyst_ind analysts delaware target_size"

eststo clear 
eststo target: estpost summarize $tar_vars
esttab target using "${tabdir}/target_summary_stats.tex", replace ///
cell((mean(fmt(%9.2f)) sd(fmt(%9.2f)) min(fmt(%9.2f)) max(fmt(%9.2f)) )) nomtitle nonumber label substitute(\_ _)


//=============================================================================================
// Table 5: Correlation matrix
//=============================================================================================

global corr_vars "num_enterprise_ind going_private financial_acquiror_ind cash_deal stock_deal ofCash acq_public premium ROA leverage ni_margin analyst_ind analysts delaware target_size"

estpost correlate $corr_vars, matrix  // matrix option required to get all pairwise. 
	eststo correlation
	esttab correlation using "${tabdir}/correlation_matrix.tex", unstack compress b(2) replace label nonumber
	


