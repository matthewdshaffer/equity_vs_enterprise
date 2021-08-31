///////////////////////////////////////////
///// 1D: Create Labels and Variables ///// 
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
else if "`c(username)'" == "KSBruere" {
	global dir "C:\Users\KSBruere\Dropbox\Research\M&A with Matt"
}
else if "`c(username)'" == "willy" {
	global dir "C:\Users\willy\Dropbox"
}
else if "`c(username)'" == "jason" {
	global dir "/Users/jason/Dropbox/Research" 
}
    
cd "$dir/Equity vs. Enterprise"           
global datadir "Data"                       
global tabdir "Tables" 	
global originaldata "Data/Original_Data"	
global tempfiles "Data/tempfiles"	

//=============================================================================================
//============================================================================================= 

	/* MS, 12/11/2020:
     Goal: Start with output of 1C_Prep_Mere_Data file. 1C just prepped all of our 'supplemental' 
	 data / controls (extra deal-level SDC data, IBES (analysts), and CRSP (price for premium)), 
	 and merged back the bare minimum of 'raw' data. 
	 
	 This file does everything else to get us to our 'analysis dataset":
	 -Change the coded variables (past, current, future) to numerics for regression tests .
	 -Change the string-coded indicators from SDC ('Delaware'), etc. to numerics.
	 -Construct the control variables (NI/A, A/E, NI/S, log(AT), premium) sequentially 
		  (i.e. 'replace roa = ni/at if roa == . ', etc., to maximize N. 
		  
	 -Winsorize control variables /continuous variables once, and inspect for plausibility. 
	 -Label things nicely. 
	 
	 */ 
	 
//=============================================================================================
//============================================================================================= 	 
	 
// Start with raw 'merged' dataset from 1C. 

use "$datadir/1C_Prep_Merge_Data", clear

//=============================================================================================

		//Step 1: Create control variables
		
//=============================================================================================

	// One binary indicator, analyst data availability. 
		//create analyst indicator variable
		gen analyst_ind = analyst_per_year > 0 
	
	//ROA
		gen ROA=TargetNetIncomeOneYearPr/TargetTotalAssetsmil
		replace ROA = TargetNetIncomeOneYearPr/TargetNetAssetsmil if ROA == . 
		replace ROA = TargetReturnOnAssetsLTM/100 if ROA == . 
		//replace missing SDC ROA calculation wtih compustat calculation	
		replace ROA = ni/at if ROA == .

	//Leverage
		gen leverage=TargetTotalAssetsmil/TargetCommonEquitymil
		replace leverage = TargetTotalAssetsmil/TargetNetAssetsmil if leverage == .  // SDC is weird like this... 
		replace leverage = RatioofTotalDebttoSharehold + 1 if leverage == . 
		//replace missing SDC leverage calculation wtih compustat calculation
		replace leverage=at/ceq if leverage==.

	//NI Margin
		gen ni_margin=NetIncomeL/TargetNetSalesLTMmil
		replace ni_margin=TargetNetIncomeOneYearP/TargetNetSalesLTMmil if ni_margin == . 
		//replace missing SDC NI Margin calculation wtih compustat calculation
		replace ni_margin = ni/sale if ni_margin == . 	
	
	//Target Size
		//first replace missing SDC total assets calculation wtih compustat calculation	
		replace TargetTotalAssetsmil = at if TargetTotalAssetsmil == .
		gen target_size = ln(TargetTotalAssets)
		//also create control for market capitalization
		gen target_mktcap = ln(TgtMarketVal4WwksPriorto) 
	
	// Premium
		// first, scale the premium to decimal
		replace one_month_premium = one_month_premium / 100  
		replace one_month_premium = empirical_premium if one_month_premium == . 
		replace one_month_premium = PricePerShare/prc_tm30 -1 if one_month_premium == . 
		// use one month premium to generate the control var
		gen premium = one_month_premium
		// replace with other alternative premium if missing
		replace premium = EquityValuemil/TgtMarketVal4W - 1 if premium == . 
		// if missing construct from deal value and pre-deal mcap... 
		replace premium = one_week_premium/100 if premium == . 
		replace premium = one_day_premium/100 if premium == .  // replace sequentially if missing.
		
//=============================================================================================

		 //Step 2: Winsorize
		 
//=============================================================================================	

	//winsorize non-binary control variables
	global controls "ROA leverage ni_margin target_size premium"
	winsor2 $controls, replace cuts(1, 99)
	
	
//=============================================================================================

		 //Step 3: Generating numerical variables for categories
		 
//=============================================================================================	
		
		// Variables for time-dimensions
		// We still haven't 'verbally coded' certain 'denominator time'
		// Do the time-dimension variable construction for the ones that require the SDC data. 
		// variables, because those required merging to SDC (to know of the actual year,
		// relative to the year referenced in the valuatio). 
		// So, we need to loop back a bit, and code those ones first. 
	
//=============================================================================================

	gsort -time
	destring time, replace
	gen time_calc=year-time if v_denom_time == ""

	replace v_denom_time = "current" if time_calc==0 &  v_denom_time == ""
	replace v_denom_time = "past" if time_calc > 0   &  v_denom_time == ""
	replace v_denom_time = "future" if time_calc < 0 & v_denom_time == ""

	// Visually inspecting, we see a couple of issues here, 3 observations where 
	// '0000' was read as a year. So inspect and replace by hand: 
	tostring time_calc, replace
	replace v_denom_time = "past" if time_calc=="-20040000"
	replace v_denom_time = "future" if time_calc=="-20050000"
	replace v_denom_time = "past" if time_calc=="-20010000"

	tostring time, replace
	replace v_denom_time = "current" if v_denom_time == "" // without further information, assume current. 


//=============================================================================================
		
		 // CODE THE MAIN TIME-DIMENSION CATEGORIES LIKE WE DO FOR REGRESSIONS IN PAPER: 
		 
//=============================================================================================	

// binary forecasted vs. audited cut... 
	gen time_current_future_ind = v_denom_time == "current" | v_denom_time == "future"
	label var time_current_future_ind "\textit{I(Forecast Denom.)}"

// make time and stock dimensions into numeric/more continuous 
	gen time_num = 0 
	replace time_num = 1 if v_denom_time == "past"
	replace time_num = 2 if v_denom_time == "current"
	replace time_num = 3 if v_denom_time == "future"
	label var time_current_future_ind  "\textit{I(Forecast)}"
	label var time_num "\textit{Denom. Time}"
	
//=============================================================================================
		
		// Now doing the same for the independent variables  
		// MS, 12/11/2020: Now, using only the ones we use. 
		
//=============================================================================================	

	gen type_transaction_ind = (v_type == "transaction") 
	gen num_enterprise_ind = (v_numerator == "enterprise")
	gen type_stock_ind = (denom_type == "stock")
	gen time_current_ind = (v_denom_time == "current")
	gen time_future_ind = (v_denom_time == "future")
	gen time_past_ind = (v_denom_time == "past")
	
// Ones we use in the time graph, but not the regressions. (Needed for summstats/graph)
	gen denom_assets_ind = (v_acct_d == "assets")
	gen denom_bookequity_ind = (v_acct_d == "book equity")
	gen denom_cashflow_ind = (v_acct_d == "cash flow")
	gen denom_earnings_ind = (v_acct_d == "earnings")
	gen denom_ebit_ind = (v_acct_d == "ebit")
	gen denom_ebitda_ind = (v_acct_d == "ebitda")
	gen denom_ebt_ind = (v_acct_d == "ebt")
	gen denom_grossprofit_ind = (v_acct_d == "gross profit")
	gen denom_industryspecific_ind = (v_acct_d == "industry specific")
	gen denom_revenue_ind = (v_acct_d == "revenue")
	gen denom_profit_ind = (v_acct_d == "earnings") | (v_acct_d == "ebit") | (v_acct_d == "earnings") | (v_acct_d == "ebitda") 		| (v_acct_d == "ebt") | (v_acct_d == "gross profit")


// Deal types:  
	gen mgmt = AcquirorIncludes == "Yes" // THIS IS THE MBO ONE--NAMED WEIRD IN SDC 
	gen delaware = TargetStateofInc == "Delaware"
	gen multiple_bidders = (NumberofB > 1)
	gen acq_public = (AcqPublicStat == "Public")
	gen challenged_deal = (Challenged == "Yes")
	gen competing_bidder = strpos(CompetingBidder, "Yes") > 0
	gen cash_deal = ConsiderationStructure == "CASHO"
	gen stock_deal = ConsiderationStructure == "SHARES"
	gen hybrid_deal = ConsiderationStructure == "HYBRID"
	gen go_shop = (GoShopFlag == "Y")
	gen going_private = (GoingPrivate == "Yes")
	gen lbo = (LBO == "Yes")
	gen litigation = (Litigation == "Yes")
	gen rumored = (DealBegan == "Yes")
	gen unsolicited = (Unsolicited == "Yes")
	
// Termination Fee
	//clean target termination fee variable
	rename Targetsterminationfeemil TargetTerm
	replace TargetTerm = 0 if TargetTerm == . // SDC indicates this as 'no' for its own binary 'termination fee flag' variables
	replace TargetTerm = TargetTerm/1000 
	// scale by size. 
	gen TargetTermMCAP = TargetTerm / TgtMarketVal4
	// Scale Termination Fee by mcap...: 
	gen TargetTermMcap = (TargetTerm*1000) / (TgtMarketVal4WwksPriorto)
	sum TargetTermMcap, detail
	
//=============================================================================================
		
		//Step 4: Fixed Effects Variables
		
//=============================================================================================	
	
	// For all specs, just want year and industry FE, control for size (ln(TargetTotalAssets))
	
	rename TargetPrimarySICCode target_sic 
	encode(target_sic), gen(target_sic_num)
	
	/// ALTERNATIVE INDUSTRY CUT...: 

	//based on SIC code
	gen SIC=target_sic
	destring SIC, replace
	gen SIC_Industry = 0
	replace SIC_Industry = 1 if SIC > 1 & SIC < 1000
	replace SIC_Industry = 2 if SIC >= 1000 & SIC < 1500
	replace SIC_Industry = 3 if SIC >= 1500 & SIC < 1800
	replace SIC_Industry = 4 if SIC >= 1800 & SIC < 2000
	replace SIC_Industry = 5 if SIC >= 2000 & SIC < 4000
	replace SIC_Industry = 6 if SIC >= 4000 & SIC < 5000
	replace SIC_Industry = 7 if SIC >= 5000 & SIC < 5200
	replace SIC_Industry = 8 if SIC >= 5200 & SIC < 6000
	replace SIC_Industry = 9 if SIC >= 6000 & SIC < 7000
	replace SIC_Industry = 10 if SIC >= 7000 & SIC < 9100
	replace SIC_Industry = 11 if SIC >= 9100 & SIC < 9900
	replace SIC_Industry = 12 if SIC >= 9900 & SIC < 9999



	// STANDARDIZE ADVISOR NAME FOR FIXED-EFFECT...

	 foreach var in TargetAdvisors {   // (I put this in a for-loop with ‘var’ macro, so that it’s easier to copy and paste to other settings…
					replace `var' = lower(`var')                      // standardize all to lowercase
					replace `var' = subinstr(`var'," inc","",.)  // standardize ‘inc’ type stuff.
					replace `var' = subinstr(`var',"incorporated","",.)
					replace `var' = subinstr(`var'," corp","",.)
					replace `var' = subinstr(`var'," co.","",.)
					replace `var' = subinstr(`var'," ","",.) // get rid of spaces
					replace `var' = subinstr(`var',",","",.) // get rid of commas
					replace `var' = subinstr(`var',"$","",.) // get rid of punctuation...
					replace `var' = subinstr(`var',".","",.)
					replace `var' = subinstr(`var',"(","",.)
					replace `var' = subinstr(`var',")","",.)
					replace `var' = subinstr(`var'," ","",.)
					replace `var' = subinstr(`var',"/","",.)
					replace `var' = subinstr(`var',"\","",.)
					replace `var' = subinstr(`var',"&","",.)
					replace `var' = subinstr(`var',"-","",.)
	 
				   replace `var' = substr(`var', 1, 3)     // save just first 3 characters to deal with differences in shorthand (visual inspection)
					   
	}

	tab TargetAdvisors, sort 

	sort TargetAdvisors 
	by TargetAdvisors, sort: gen advisor_number_vals = _N 

	replace TargetAdvisor = "boutique" if advisor_number_vals < 136 | TargetAdvisor == ""  // glom the small ones together / all less than 1%. 
	encode TargetAdvisors, gen(advisor_num)  // now, encode it numerically to create fixed effect dummies….

//=============================================================================================
	
		// Step 5: Dropping not needed vars, renaming, and labeling
		 
//=============================================================================================		
drop at ceq ni sale
rename analyst_per_year analysts
	
label var RatioofTotalDebttoSharehold "\textit{Target Leverage}"
label var EBITMargin "\textit{Target EBIT Margin}"
label var TargetReturnOnEquityLTM "\textit{Target ROE}"

label var premium "\textit{Premium}"
label var ROA "\textit{ROA}"
label var ni_margin "\textit{Margin}"

label var RatioofDealValuetoSales "\textit{Deal Value to Sales}"
label var RatioofDealValuetoEBITDA"\textit{Deal Value to EBITDA}"
label var RatioofDealValuetoNetIncom "\textit{Deal Value to NI}"
label var NumberofBidders "\textit{Number of Bidders}"

label var EquityValuemil "\textit{Book Equity (mm USD)}"
label var TargetNetSalesLTMmil "\textit{Sales (mm USD)}"
label var TargetTotalAssetsmil  "\textit{Total Assets (mm USD)}"
label var TgtMarketVal4WwksPriorto "\textit{Pre-Deal MCAP (mm USD)}"
label var TargetTermMCAP "\textit{Target Termination Fee (Scaled)}"

label var one_month_premium "\textit{1-month Premium}"
label var delaware "\textit{Delaware}"
label var multiple_bidders "\textit{Multiple Bidders}"
label var acq_public "\textit{Acq. Public}"
label var challenged_deal "\textit{Challenged Deal}"
label var go_shop "\textit{Go Shop}"
label var going_private "\textit{Going Private}"
label var rumored "\textit{Rumored}"
label var unsolicited "\textit{Unsolicited}"
label var hybrid_deal "\textit{Hybrid Deal}"
label var stock_deal "\textit{Stock Deal}"
label var cash_deal "\textit{Cash Deal}"
label var competing_bidder "\textit{Competing Bidders}"
label var target_size "\textit{Target Size}"
label var target_mktcap "\textit{Target Market Cap}"
label var lbo "\textit{LBO}"

label var type_transaction_ind "\textit{Transaction Multiple}"
label var num_enterprise_ind "\textit{Enterprise Value}"
label var type_stock_ind "\textit{Stock}"
label var time_current_ind "\textit{Current}"
label var time_future_ind "\textit{Future}"
label var time_past_ind "\textit{Past}"
label var denom_assets_ind "\textit{Assets}"
label var denom_bookequity_ind "\textit{Book Equity}"
label var denom_cashflow_ind "\textit{Cash Flow}"
label var denom_earnings_ind "\textit{Earnings}"
label var denom_ebit_ind "\textit{EBIT}"
label var denom_ebitda_ind "\textit{EBITDA}"
label var denom_ebt_ind "\textit{EBT}"
label var denom_grossprofit_ind "\textit{Gross Profit}"
label var denom_industryspecific_ind "\textit{Industry Specific}"
label var denom_revenue_ind "\textit{Revenue}"
label var denom_profit_ind "\textit{Profit}"
label var time_future_ind "\textit{I(Forecast Denom.)}"
label var leverage "\textit{Leverage}"
label var analyst_ind "\textit{I(Analyst Coverage)}"
label var analysts "\textit{Analysts (n)}"
label var litigation "\textit{I(Litigation)}"
label var TargetTermMcap "\textit{Target Termination Fee (Scaled)}"
label var mgmt "\textit{MBO}"
label var TargetTerm "\textit{Target Termination Fee}"


//=============================================================================================
	
		// Step 6: Misc additions in re-draft
		 
//=============================================================================================	

// June 15, 2021. "No Market Exception"-state test, following this: https://corpgov.law.harvard.edu/2020/03/30/the-market-exception-in-appraisal-statues/

gen no_market_exception_state = 0
replace no_market_exception = 1 if TargetStateo == "Alabama"
replace no_market_exception = 1 if TargetStateo == "Arkansas"
replace no_market_exception = 1 if TargetStateo == "Hawaii"
replace no_market_exception = 1 if TargetStateo == "Illinois"
replace no_market_exception = 1 if TargetStateo == "Kentucky"
replace no_market_exception = 1 if TargetStateo == "Missouri"
replace no_market_exception = 1 if TargetStateo == "Montana"
replace no_market_exception = 1 if TargetStateo == "Nebraska"
replace no_market_exception = 1 if TargetStateo == "New Mexico"
replace no_market_exception = 1 if TargetStateo == "Ohio"
replace no_market_exception = 1 if TargetStateo == "Vermont"
replace no_market_exception = 1 if TargetStateo == "Washington"

label var no_market_exception "\textit{Non-Market Exception State}" 

save "$datadir/1D_labeled_dataset", replace



