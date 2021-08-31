  ///////////////////////////////////////////
//////// 1C: Prep and Merge Data/ ///////// 
/////////////////////////////////////////// 

clear all
di "current user: `c(username)'"
if "`c(username)'" == "matthewshaffer" {
	global dir "/Users/matthewshaffer/Dropbox" 
	disp 10
}
else if "`c(username)'" == "jackzhou" {
	global dir "/Users/jackzhou/Dropbox" 
}
else if "`c(username)'" == "davidcai" {
	global dir "/Users/davidcai/Dropbox" 
}
else if "`c(username)'" == "jason" {
	global dir "/Users/jason/Dropbox/Research" 
}

    
cd "$dir/Equity vs. Enterprise"           
global datadir "Data"                       
global tabdir "Tables" 	
global originaldata "Data/Original Data"


/* MS: New approach, 12/11/2020: 
	-Keep this super organized and structured.
		-Our 'main' dataset is just the valuations. 
		-We have to merge in a bunch of other data... after prepping it. 
		-So, instead of jumping back and forth... just *set up* all the 'using'
		datasets, and save them as frames, and then just merge them all in, one-by-one, after they are set up. 
		
		-So...: 
			-STEP 1 will be setting up all the 'using' datasets.
			-STEP 2 will be going back to valuations datasets, and merging them all in. 
	*/ 
	

	
//=============================================================================================
//Preamble: packages used in this dataset. 
//=============================================================================================

/*
ssc inst egenmore
ssc inst unique
ssc install estout
*/
	

	
//=============================================================================================
//=============================================================================================
// ***  STEP 1: SET UP USING DATASETS ** 
//=============================================================================================
//=============================================================================================
	
	

//=============================================================================================
//Deal-level dataset from SDC
//=============================================================================================

frame create SDC_deal_level
frame change SDC_deal_level

// Prep first SDC query data. 
import excel "$originaldata/multiples_deal_level_data.xlsx", sheet("Request 3") firstrow clear

//clean up variable names

	rename OfferPricetoTargetStockPric one_day_premium
	rename AM one_week_premium
	rename AN one_month_premium
	rename DealNumber sdc_deal_no

	
destring Enter* Equity* Ratio*, force replace 




//=============================================================================================
//Setting up the IBES dataset (for n analysts)
//=============================================================================================

// Note: We set up separate frames to eventually merge on CUSIP vs. Ticker. 
	 
	 

	// CUSIP IBES Frame
	//=============================================================================================
	
		frame create AnalystCount_CUSIP
		frame change AnalystCount_CUSIP

	// Use file imported fromm IBES with analyst IDs for CUSIP merge
		use "$originaldata/AnalystCount.dta", replace

	// Change the IDs to string
		tostring ANALYS, replace
	
	// Generate 6-digit CUSIP
		gen TargetCUSIP = substr(CUSIP, 1, 6)

	// Generate year variable to merge at yearly level
		gen year = year(ANNDATS)

	// Drop the redundant obs
		drop if mi(TargetCUSIP)

	// Indentify unique analysts by CUSIP and fyear
		qui: unique ANALYS, by (year TargetCUSIP) gen(analyst_per_year_CUSIP) //Rmb to ssc install

	// Drop redundant observations
		drop if mi(analyst_per_year_CUSIP)

	// Keep relevant variables
		keep analyst_per_year_CUSIP year TargetCUSIP

		

	// Ticker IBES Frame
	//=============================================================================================
	frame create AnalystCount_Ticker
	frame change AnalystCount_Ticker

	// Use file imported form IBES with analyst IDs for Ticker Merge
		use "$originaldata/AnalystCount.dta", replace

	// Same steps as CUSIP merge prep
		tostring ANALYS, replace
		gen year = year(ANNDATS)
		rename OFTIC TargetPrimaryTickerSymbol
		drop if mi(TargetPrimaryTickerSymbol)

	// Indentify unique analysts by Ticker and fyear
		qui: unique ANALYS, by (year TargetPrimaryTickerSymbol) gen(analyst_per_year_ticker)

	// Drop redundant observations
		drop if mi(analyst_per_year_ticker)

	// Keep relevant variables
		keep analyst_per_year_ticker year TargetPrimaryTickerSymbol





//=============================================================================================
//Compustat Frame for additional controls... (Ticker)
//=============================================================================================


	// MS, 12/11/2020:  We ultimately only require ROA, Leverage (A/E), Margin (NI/S), and size (log(A)).
	// so we just need Compustat: at, ceq, ni, sale

// Set up frame
	frame create Compustat_annual_ctrl
	frame change Compustat_annual_ctrl

	use "$originaldata/compustat_annual_ctrl", clear


// MS: 12/11: Keep things simple. Keep only requisite variables. 
	keep at ceq ni sale GVKEY datadate fyear tic LPERMNO
	rename GVKEY gvkey


// MS, 12/11: If athose variables are missing, regression won't run. 
// We won't get any information useful at any point from those. So drop now. 
	drop if at == . & ceq == . & ni == . & sale == . 


// MS, 12/11. Set up as panel. Compustat annual is defined by gvkey and year. 
// But tsset requires numeric identifier. 
	encode(gvkey), gen(gvkey_numeric)
	sort gvkey_numeric fyear 
	duplicates drop gvkey_numeric fyear, force
	tsset gvkey_numeric fyear 
	tsfill, full 


// MS, 12/11: Now we have a full panel (gvkey x year) *set up*. But tsfill only fills in
// the panel variables. So, for our eventual merges, we need to also fill in ticker and gvkey. 
	global identifiers "tic gvkey"
	foreach var in $identifiers {
		replace `var' = `var'[_n - 1] if `var' == "" & gvkey_numeric == gvkey_numeric[_n - 1]
}
	
	replace LPERMNO = LPERMNO[_n - 1] if LPERMNO == . & gvkey_numeric == gvkey_numeric[_n - 1]
	drop if tic == "" & gvkey == ""
  
 
// MS, 12/11: Now we have a full panel (gvkey x year) *set up*. But tsfill only fills in
// the panel variables. So, now, get 'the most recently available data' for each fundamental.
	sort gvkey_numeric fyear  
	global fundamentals "ni at ceq sale" 
	foreach var in $fundamentals {
		replace `var' = l.`var' if `var' == . 
	}


// Prepare for merging. Change names to names in 'main' valuation/SDC datasets, drop duplicate (if any?)
	duplicates drop tic fyear, force // 0 observations are dupes even using the ticker with this process! Nice!
	rename tic TargetPrimaryTickerSymbol
	rename LPERMNO PERMNO
	rename fyear year


//=============================================================================================
//Compustat Frame for additional controls... (Permno)
//=============================================================================================

// We create another frame for merging in Compustat using permno to fill
// instances where ticker matching is unavailable
frame create Compustat_annual_ctrl_permno
frame copy Compustat_annual_ctrl Compustat_annual_ctrl_permno, replace
frame change Compustat_annual_ctrl_permno

duplicates drop PERMNO year, force

//=============================================================================================
//  CRSP Frame: 
//=============================================================================================


  // Goal: Take CRSP and, *within the dataset*, contruct security-day level variables
  // that will give us information required to construct premium, when it is missing in SDC.
  // e.g., merge in price_t-30, for observations where SDC has the deal price, but not the premium.
  // e.g., merge in price_t+1/price_t-30 ('empirical premium') for observations where it has neither.
  // Create full panel so that we can merge in on *announcement date* (day). 

	frame create CRSP
	frame change CRSP

	use "$originaldata/CRSP", clear


// MS: 12/11: Each and any row in which price (PRC) is missing provides zero useful information
// for our purposes. Will only lead to identifier-duplication issues later on. So, drop such rows now. 
	drop if PRC == . 


// MS: 12/11: CRSP daily is defined by permno x day. And, tsfill requires\
// firm identifer be numeric. Ticker is string. So, set up panel using permno. 
	tsset PERMNO date
	duplicates drop PERMNO date, force // (There shouldn't be, but just in case.)
	tsfill  


// MS, 12/11: Now we have a full panel (permno x date) *set up*. But tsfill only fills in
// the panel variables. So, for our eventual merges, we need to also fill in ticker. 

    // JACK / DAVID, YOU FORGOT THIS IN YOUR CODE! TICKER IS WHAT WE EVENTUALLY MERGE ON. 
	// SO IF YOU DON'T FILL OUT THAT IDENTIFIER, WE GET NOTHING FROM THE 'TSFILL' COMMAND!

	replace TICKER = TICKER[_n - 1] if TICKER == "" & PERMNO == PERMNO[_n - 1]

 
// MS, 12/11: Now we have a full panel (permno x date) *set up*. But tsfill only fills in
// the panel variables. So, now, get 'the most recently available PRICE DATA' for each date, 
//  when missing (eg., weekends, holidays)
	sort PERMNO date 
	replace PRC = l.PRC if PRC == . 


// MS, 12/11: Now, construct all information that could be useful in constructing 
// the premium, when it is missing from SDC. For this, we will *merge on the
// announcement day* itself. So, we need to construct the requisite variables
// at the permno x day observation level. 
    // E.g., get p_t-30 for observations where SDC has the deal price but not the
	// premium. e.g., get (p_t+1/p_t-30)-1 (``empirical premium'') for observations
	// where SDC has neither. (Latter *is done* in other published/peer-reviewed papers.)
	// (Assumes that market trades the target up to approximately the deal price after announcement,
	// since vast majority of announced acquisitions are approved.)

	replace PRC = l.PRC if PRC == .
	gen prc_tm30 = l30.PRC
	gen prc_tm07 = l7.PRC
	gen prc_tm01 = l.PRC
	gen prc_tp1 = f.PRC
	gen empirical_premium = (f.PRC/l30.PRC)-1
	replace empirical_premium = (f.PRC/l7.PRC)-1 if empirical_premium == . // Consistent with how we do with SDC. 


// drop the duplicates // MS: 12/11/2020: How is this different from 'duplicates drop ticker date, force'??
	// MS: OG RA code I don't understand: 
	/* sort DateAnnounced TargetPrimaryTickerSymbol
	by DateAnnounced TargetPrimaryTickerSymbol: gen dup = cond(_N == 1, 0, _n)
	drop if dup > 1
	drop dup
	*/ 


// MS, 12/11: Now, prepare for ultimate merge to valuation/SDC dataset. 
// As always, that means drop duplicates in terms of the merge variable. 
// and get names consistent with 'main dataset.' For SDC, we have to merge on
// ticker x date. 
   
   // First do some work to get rid of the 'right' ticker x day duplicates.  
	duplicates tag TICKER date, gen(duped)
	drop if empirical_premium == . & duped > 0     // If we have ticker x date dupes, drop the one without requisite information
	drop duped  
	duplicates drop TICKER date, force 


	// Second, change names to be consistent with / ready for merging to 'main' valuation/SDC datasets. 
	rename TICKER TargetPrimaryTickerSymbol
	rename date DateAnnounced


	save "$datadir/1C_post_CRSP_temp", replace  // MS 12/11: Sorry, guys, broke my own rule. 



	
	
	
//=============================================================================================
//=============================================================================================
// ***  STEP 2: USE VALUATIONS AS BASE PANEL / MAIN FRAME, AND MERGE IN ALL OF THE ABOVE. 
//=============================================================================================
//=============================================================================================
	

   // MS, 12/11/20: Now that we have SET UP all the raw 'using' datasets. We can just go back to our
   // main valuation-level dataset, and merge everything back, one-by-one, just once. (Intead of jumping around.)

   // use "$datadir/1C_post_CRSP_temp", clear // MS: Bodge, since the CRSP frame takes so long. 
 
// Set up valuation-level data frame. 
	frame create valuations
	frame change valuations


// Get that dataset--remember, rows are at *valuation level*, so we'll do m:1 merges. 
   // These are our valuations. Our 'base' dataset. 
	use "$datadir/1B_valuations_categorized", clear
	destring sdc_deal_no, force replace // Prep SDC identifier for first merge. 

	
	
// Now, just merge in all the datsets we prepped above..: 

	// Merge #1: SDC Deal-Level Data. Link: sdc_deal_no
		frlink m:1 sdc_deal_no, frame(SDC_deal_level)
		frget _all, from(SDC_deal_level)
	
	// Merge #2: CRSP data for constructing premium. Link: TargetPrimaryTickerSymbol x DateAnnounced (already prepped)
		frlink m:1 TargetPrimaryTickerSymbol DateAnnounced, frame(CRSP)
		frget _all, from(CRSP)

	// Merge #3: Compustat fundamentals. Link: TargetPrimaryTickerSymbol x Year and Permno x Year.
	   // MS 12/11/2020: NB, given the way we *set up* the Compustat frame, each 
	   // ticker x year row *already has* most-recently-available data. So we can
	   // just merge on identifier x year, full stop. 
	   
	   gen year = year(DateAnnounced)
	      // (MS, 12/11: Checked that this is fully populated. ('order year ./ sort year .' (inspet)))
	   
		// Ticker merge
		frlink m:1 TargetPrimaryTickerSymbol year, frame(Compustat_annual_ctrl)
		frget _all, from(Compustat_annual_ctrl) exclude(PERMNO)
		drop Compustat_annual_ctrl
		
		// Permno merge for missing tickers
		frlink m:1 PERMNO year, frame(Compustat_annual_ctrl_permno)
		frget _all, from(Compustat_annual_ctrl_permno) suffix(_permno)
		replace at = at_permno if mi(at)
		replace ceq = ceq_permno if mi(ceq)
		replace ni = ni_permno if mi(ni)
		replace sale = sale_permno if mi(sale)
		

	// Merge #4: IBES number-of-analysts data/control. 
		// NB: Only difference here is, this time, we merge on *both* ticker and CUSIP...
		// ... Using clever bodge from RAs (different variable names so it works). 
		
		// Merge links 
		frlink m:1 TargetCUSIP year, frame(AnalystCount_CUSIP)
		frlink m:1 TargetPrimaryTickerSymbol year, frame(AnalystCount_Ticker)

		// Merge inclusion
		frget _all, from(AnalystCount_CUSIP)
		frget _all, from(AnalystCount_Ticker)

		// Combining
		rename analyst_per_year_ticker analyst_per_year
		replace analyst_per_year = analyst_per_year_CUSIP if mi(analyst_per_year)
		drop analyst_per_year_CUSIP
		replace analyst_per_year = 0 if analyst_per_year == . 
		
		 
		 
//=============================================================================================
// All done! Save. 
//=============================================================================================



save "$datadir/1C_Prep_Merge_Data", replace 

