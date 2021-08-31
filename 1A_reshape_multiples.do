///////////////////////////////////////////
///////// 1A: Reshape Multiples// //////// 
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
else if "`c(username)'" == "jason" {
	global dir "/Users/jason/Dropbox/Research" 
}

    
cd "$dir/Equity vs. Enterprise"           
global datadir "Data"                       
global tabdir "Tables" 	
global originaldata "Data/Original Data"

/////////////////////////////////////////// 

import excel "$originaldata/SDC Multiples Types.xlsx", sheet("Request 3") firstrow clear 



drop if _n < 3             // Drop the bodge rows I made in excel to set up for reshape.
drop if sdc_deal_no == ""  // Drop excel row artefacts. 


// We want to preserve information about whether it is a deal multiple or trading multiple, 
// while also glomming them all together in one list. 
   // Inspecting: 
	 // val1 - val128 are trading comparables
     // val129 -val215 are deal/transaction comparables 

forvalues i = 1/128 {
	
	replace val`i' = "Trading " + val`i' if val`i' != ""
} 

forvalues i = 129/215 {
	
	replace val`i' = "Transaction " + val`i' if val`i' != ""
} 


// So, now, we have the information (trading vs. transaction multiple) preserved in the variable, 


//We can treat them all as one variable type for re-shape purposes. 
	reshape long val, i(sdc_deal_no) j(val_num)

	drop val_num  // get rid of this index variable for now--we'll drop dupes and missings, so will want different index later

	drop if val == "" // extra rows for the empty columns (different number of vals for diff transacts)
	duplicates drop 



// Standardize the strings
     // all lowercase, so case diffs don't throw us off
	replace val = lower(val)
	
	// delete slashes, etc. so 'pe' vs. 'p/e' etc. doesn't cause an issue
	replace val = subinstr(val,",","",.) // get rid of commans
	replace val = subinstr(val,"$","",.) // get rid of punctuation...
	replace val = subinstr(val,".","",.)
	replace val = subinstr(val,"/","",.)
	replace val = subinstr(val,"\","",.)
	replace val = subinstr(val,"&","",.)
	replace val = subinstr(val,"-","",.) 
	
	// MS: For now, I'm leaving in spaces and parentheses, since they can help us read it... 
	duplicates drop 
	
	
	
// Now, I'll save this file, which has original valuation methods, maped to sdc deal numbers. 
	rename val valuation_method
	save "$datadir/1A_deal_valuation_method_all", replace 
	// This is probaably the file we'll start with, once we start doing our analysis. 
	
	
	

	
