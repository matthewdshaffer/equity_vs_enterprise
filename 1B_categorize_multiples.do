///////////////////////////////////////////
//////// 1B: Categorize Multiples ///////// 
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


/////////////////////////////////////////// 


// load the reshaped list of all valuation_methods from before 
	use "$datadir/1A_deal_valuation_method_all", clear 


/////////////////////////////////////////// 
 
// Overview/ tasks/ structure: 
	// Step 0: First, only use *valuation* ratios. ROE is financial-analysis, not valuation ratio. 
		// So, drop those going forward. 
	// Branch #1: Valuation 'type': transaction vs trading
	// Branch #2: Value Numerator: enterprise vs. equity
	// Branch #3: Accounting Denominator: ni, ebit, ebitda, sales, cfo, book equity, assets... anything else? 
	   // subsidiary branch #3.i: is the accounting denominator adjusted or not? 
	// Branch 4: Time period / year: forward, current, lagged? 
		// For now, since we don't have announcement date, just preserve all year information. 

		
		
//////////////////////////////////////////////////////////////
/////// *** Step 0: Find/drop non-valuation ratio *** //////// 
///////////////////////////////////////////////////////////// 

 // Step 1: Only want *valuation* ratios. So, numerator has to be a *valuation*--either equity value/price or enterprise value/price
 // Problem is, they go by many different names... 
		// enterprise value
		// often shortened to 'ev'
		// equity value
		// price
		// pe (for price-to-earnings)
		// market price / market capitalizaiton
		// market value 
		// 'firm value' // anything else? 
		
		

gen v_ratio = 0 // indicator that this is a *valuation* ratio, not financial 

	replace v_ratio = 1 if substr(val, 1, 10) == "trading eq" // 'trading equity value' and misspellings..
	replace v_ratio = 1 if substr(val, 1, 14) == "transaction eq" 

	replace v_ratio = 1 if substr(val, 1, 10) == "trading en" // 'trading enterprise value'
	replace v_ratio = 1 if substr(val, 1, 14) == "transaction en"

	replace v_ratio = 1 if substr(val, 1, 10) == "trading ev" // for when enterprise value is shortened to 'ev'
	replace v_ratio = 1 if substr(val, 1, 14) == "transaction ev"

	replace v_ratio = 1 if substr(val, 1, 9) == "trading p" // when it's just 'pe', 'price' or p
	replace v_ratio = 1 if substr(val, 1, 13) == "transaction p"

	replace v_ratio = 1 if substr(val, 1, 10) == "trading pe" // when it's just 'pe'
	replace v_ratio = 1 if substr(val, 1, 14) == "transaction pe"

	replace v_ratio = 1 if substr(val, 1, 10) == "trading ma" // when it's 'market price/market cap/market val
	replace v_ratio = 1 if substr(val, 1, 14) == "transaction ma"

	replace v_ratio = 1 if substr(val, 1, 14) == "trading firm v" // when it's 'market price/market cap/market val
	replace v_ratio = 1 if substr(val, 1, 18) == "transaction firm v"

		
	// katherine/jack/david--inspect if you think anything i'm doing cuts it too far. 
	drop if v_ratio == 0 




/////////////////////////////////////////////////////////////////////////
/////// *** Branch 1: Valuation 'type': transaction vs trading *** //////// 
///////////////////////////////////////////////////////////////////////// 

 
gen v_type = ""
	replace v_type = "trading" if substr(val, 1, 7) == "trading"
	replace v_type = "transaction" if substr(val, 1, 7) == "transac" 

 // This one is easy, because it is an SDC category/fuly determined.  


/////////////////////////////////////////////////////////////////////////
/////// *** Branch 2: Value Numerator: enterprise vs. equity *** //////// 
///////////////////////////////////////////////////////////////////////// 

 
 // make this cleaner by getting rid of leading 'transaction' vs. 'trading', since info is preserved. 
	replace val = subinstr(val,"trading ","",.)  
	replace val = subinstr(val,"transaction ","",.) 


gen v_numerator = ""  // initiate variable

	replace v_numerator  = "equity" if substr(val, 1, 2) == "eq"
	replace v_numerator  = "enterprise" if substr(val, 1, 2) == "en"
	replace v_numerator  = "equity" if substr(val, 1, 1) == "p"
	replace v_numerator  = "enterprise" if substr(val, 1, 2) == "ev"

	// Those are the easy ones... now, inspect data to figure out what else...
sort v_n // put the missing ones up top 
 // I'm not sure about the firm-value/market value ones...
 // will depend on what hte numerator is (ebitda only makes sense as denominator)
 // if you're doing enterprise value. 
 // Inspecting: I think 'market' typically ndicates equity, 'firm value' indicates ev
 
	replace v_n  = "equity" if substr(val, 1, 6) == "market"
	replace v_n = "enterprise" if substr(val, 1, 4) == "firm"


sort v_n
  // Only two remaining: 'aggregate value' means enterprise value/market
 
	replace v_n = "enterprise" if strpos(val, "aggregate value") > 0 & v_n == ""

tab v_numerator  // Nice! A good, complete split! 




/////////////////////////////////////////////////////////////////////////
/////// *** Step 4: Accounting Denominator *** //////// 
///////////////////////////////////////////////////////////////////////// 


// Most of them are fairly regular. Since we have already dropped non-valuation ratios
// (i.e, financial-analysis ratios like ROE), assuming we have done that right, 
// we know that if the string 'ebit' appears, it must be in the denominator (since
// numerator is only enterprise value or equity value)... issue is bad spelling
// irregular representation (sometimes just use 'pe'), etc. 
 
gen v_acct_denom = "" 

	replace v_a = "ebitda" if strpos(val, "ebitda") > 0
	replace v_a = "ebit" if strpos(val, "ebit") > 0 & v_a == "" // (don't want to overwrite the ebitdas)
	replace v_a = "revenue" if strpos(val, "rev") > 0 & v_a == "" 
	replace v_a = "assets" if strpos(val, "asset") > 0 & v_a == "" 
	replace v_a = "earnings" if strpos(val, "earn") > 0 & v_a == "" 
	replace v_a = "book equity" if strpos(val, "book") > 0 & v_a == "" 
	replace v_a = "ffo" if strpos(val, "ffo") > 0 & v_a == "" 
	replace v_a = "ffo" if strpos(val, "funds from op") > 0 & v_a == "" 
	replace v_a = "ffo" if strpos(val, "fund from op") > 0 & v_a == "" 

sort v_a // Inspect what's not populated so far. 

	replace v_a = "earnings" if strpos(val, "eps") > 0 & v_a == "" 
	replace v_a = "earnings" if strpos(val, "pe") > 0 & v_a == ""
	replace v_a = "earnings" if strpos(val, "net in") > 0 & v_a == ""
	replace v_a = "revenue" if strpos(val, "sales") > 0 & v_a == ""  // Should we normalize revenue/sales to 'sales' or 'revenue'? I'm going with revenue for now. 
	replace v_a = "book equity" if strpos(val, "bv") > 0 & v_a == "" 
	replace v_a = "cash flow" if strpos(val, "cash f") > 0 & v_a == ""  // Glomming together all cash-flow-measure-- this okay, Katherine?
	replace v_a = "cash flow" if strpos(val, "cfo") > 0 & v_a == "" 
	replace v_a = "cash flow" if strpos(val, "fcf") > 0 & v_a == "" 
	sort v_a // Iterate: What are we still missing? 

	replace v_a = "book equity" if strpos(val, "to equity") > 0 & v_a == ""
	replace v_a = "book equity" if strpos(val, "common equity") > 0 & v_a == ""
	replace v_a = "book equity" if strpos(val, "tangible equity") > 0 & v_a == ""  // Okay with glomming 'tangible equity' together, Katherine? 
	replace v_a = "book equity" if strpos(val, "pb") > 0 & v_a == "" 
	replace v_a = "ebt" if strpos(val, "ebt") > 0 & v_a == "" 
	replace v_a = "gross profit" if strpos(val, "gross") > 0 & v_a == "" 

sort v_a // Iterate: What are we still missing?


// Deposits are frequenty enough, I might code it up for now... 
	replace v_a = "deposits" if strpos(val, "deposit") > 0 & v_a == "" 
	replace v_a = "reserves" if strpos(val, "reserves") > 0 & v_a == ""
	replace v_a = "book equity" if strpos(val, "equity") > 7 & v_a == ""
	replace v_a = "book equity" if strpos(val, "equity (") > 0 & v_a == ""
	replace v_a = "daily production" if strpos(val, "daily prod") > 0 & v_a == ""
	replace v_a = "ebt" if strpos(val, "pretax") > 0 & v_a == ""
	replace v_a = "ebt" if strpos(val, "pre tax") > 0 & v_a == ""
	replace v_a = "ebt" if strpos(val, "prettax") > 0 & v_a == ""

	replace v_a = "cash" if strpos(val, "net cash") > 0 & v_a == ""
	replace v_a = "cash" if strpos(val, "cash") > 0 & v_a == ""
	replace v_a = "receivables" if strpos(val, "receiv") > 0 & v_a == ""


sort v_a 

 // none of the others look like v_ratios
 
	replace v_ratio = 0 if v_a == ""
drop if v_ratio == 0 
drop v_ratio

tab v_a

// I recommend glomming... cash, daily production, deposits, ffo, receivables, and reserves into 'industry specific'
 // But first, save a distinction between 'stock' vs. 'flow' measures
gen denom_type = "flow"
	replace denom_type = "stock" if v_a == "assets" | v_a == "book equity" | v_a == "cash" | v_a == "deposits" | v_a == "receivables" | v_a == "reserves"

	replace v_a = "industry specific" if v_a == "cash" | v_a == "daily production" | v_a == "deposits" | v_a == "ffo" | v_a == "reserves" | v_a == "receivables"



/////////////////////////////////////////////////////////////////////////
/////// *** Step 4: Is account denominator adjusted *** /////////////////
///////////////////////////////////////////////////////////////////////// 

gen adjusted_denom = 0 
	replace adjusted_denom = 1 if strpos(val, "adj") > 0 
 // Only 132. 
 // Katherine: Any other flags to look at? 


/////////////////////////////////////////////////////////////////////////
/////// *** Step 5: Time dimension *** /////////////////////////////////////
///////////////////////////////////////////////////////////////////////// 

gen v_denom_time = ""  // initiate 

	replace v_denom_time = "past" if strpos(val, "ltm") > 0 & v_d == ""
	replace v_denom_time = "future" if strpos(val, "ntm") > 0 & v_d == ""
	replace v_denom_time = "current" if strpos(val, "y0") > 0 & v_d == ""
	replace v_denom_time = "future" if strpos(val, "y1") > 0 & v_d == ""
	replace v_denom_time = "future" if strpos(val, "y2") > 0 & v_d == ""
	replace v_denom_time = "past" if strpos(val, "lqa") > 0 & v_d == ""
	replace v_denom_time = "future" if strpos(val, "next") > 0 & v_d == ""
	replace v_denom_time = "future" if strpos(val, "+") > 0 & v_d == ""
	replace v_denom_time = "future" if strpos(val, "last") > 0 & v_d == ""
	replace v_denom_time = "future" if strpos(val, "average") > 0 & v_d == ""


//first install egenmore command
//ssc install egenmore
//use the "sieve" command to tell stata to only keep numeric characters
//basic syntax: sieve(strvar) , { keep(classes) | char(chars) | omit(chars) }
egen time = sieve(valuation_method), keep(numeric) 
//delete new time variable if we have already determined the time
	replace time ="" if v_denom_time=="current"
	replace time ="" if v_denom_time=="past"
	replace time ="" if v_denom_time=="future"

gsort -time

//fix all of the weird instances of time
tostring(time), replace
format time 
gen str v_den = substr(v_denom_time,1,8)
	replace time = "2008" if time=="12312008"
	replace time = "2006" if time=="9302006"
	replace time = "2006" if time=="302006"
	replace time = "2009" if time=="202009"
	replace time = "2009" if time=="200910"
	replace time = "2008" if time=="182008"
	replace time = "2009" if time=="92009"
	replace time = "2008" if time=="52008"
	replace time = "2012" if time=="22012"
	replace time = "2011" if time=="22011"
	replace time = "2020" if time=="20202"
	replace time = "2019" if time=="20192"
	replace time = "2017" if time=="20172"
	replace time = "2017" if time=="20171"
	replace time = "2014" if time=="20143"
	replace time = "2013" if time=="20133"
	replace time = "2001" if time=="20011"
	replace time = "1999" if time=="11999"
	replace time = "2002" if time=="202"
	replace time = "2013" if time=="013"
	replace v_denom_time = "current" if valuation_method=="p930 book value per share"
	replace v_denom_time = "current" if valuation_method=="enterprise value to revenue (y8)"
	replace v_denom_time = "current" if valuation_method=="price to 8% tg book"
	replace v_denom_time = "current" if valuation_method=="price8% tg book"
	replace v_denom_time = "future" if valuation_method=="price to estimated 5 year earnings per share compound annual growth rate"
	replace v_denom_time = "past" if valuation_method=="equtiy value to earnings growth rate (5 years)"
	replace v_denom_time = "past" if valuation_method=="enterprise value to  earnings per share (5 year growth rate)"
	replace v_denom_time = "past" if valuation_method=="priceearnings to earnings per share compounded annual growth rate(5year)"
	replace v_denom_time = "past" if valuation_method=="pbv to cagr eps(5 year)"
	replace v_denom_time = "past" if valuation_method=="enterprise value to rev (y5)"
	replace v_denom_time = "past" if valuation_method=="priceearnings5year eps compound"
	replace v_denom_time = "past" if valuation_method=="enterprise value to revenue (y5)"
	replace v_denom_time = "past" if valuation_method=="equity value to earnings to compounded annual growth rate(5 year)"
	replace v_denom_time = "future" if valuation_method=="price earningsearnings per share compound annual growth rate(5 year estimates)"
	replace v_denom_time = "past" if valuation_method=="equity value to compound earnings (cagr 5 years)"
	replace v_denom_time = "past" if valuation_method=="enterprise value to ebitda(5 year peak)"
	replace v_denom_time = "past" if valuation_method=="priceearnings to long term growth rate(5 year)"
	replace v_denom_time = "past" if valuation_method=="pe to eps growth (5yr cagr)"
	replace v_denom_time = "past" if valuation_method=="enterprise value to ebitda (5 year peak)"
	replace v_denom_time = "past" if valuation_method=="enterprise value to revenue (y4)"
	replace v_denom_time = "current" if valuation_method=="equity value to earnings(4qtr)"
	replace v_denom_time = "past" if valuation_method=="enterprise value to revenue (y4)"
	replace v_denom_time = "current" if valuation_method=="equity price percent to book value(4qtr)"
	replace v_denom_time = "current" if valuation_method=="equity price percent to book value(3qtr)"
	replace v_denom_time = "current" if valuation_method=="enterprise value to revenue (3 month)"
	replace v_denom_time = "past" if valuation_method=="enterprise value to ebitda (3 years cagr)"
	replace v_denom_time = "past" if valuation_method=="enterprise value3 yr avg ebitda"
	replace v_denom_time = "past" if valuation_method=="equity value to earnings (y3)"
	replace v_denom_time = "current" if valuation_method=="enterprise value to revenue (recent 3 month)"
	replace v_denom_time = "current" if valuation_method=="enterprise value to ebit (latest 3 month)"
	replace v_denom_time = "current" if valuation_method=="enterprise value to ebitda (3 month)"
	replace v_denom_time = "current" if valuation_method=="equity value to tangible book value(3 months)"
	replace v_denom_time = "current" if valuation_method=="enterprise value to ebitda (3rd quartile)"
	replace v_denom_time = "current" if valuation_method=="enterprise value to revenue (latest 3 month)"
	replace v_denom_time = "current" if valuation_method=="enterprise value to ebitda (recent 3 month)"
	replace v_denom_time = "current" if valuation_method=="equity value to earnings(3qtr)"
	replace v_denom_time = "current" if valuation_method=="enterprise value to ebitda (latest 3 month)"
	replace v_denom_time = "past" if valuation_method=="priceearnings multiple to earnings compound annual growth rate(3 years)"
	replace v_denom_time = "past" if valuation_method=="enterprise value to revenue (y3)"
	replace v_denom_time = "current" if valuation_method=="equity value to book value(3 months)"
	replace v_denom_time = "current" if valuation_method=="equity value to earnings(2qtr)"
	replace v_denom_time = "current" if valuation_method=="equity price percent to book value(2qtr)"
	replace v_denom_time = "future" if valuation_method=="equity value to ebitda(f2)"
	replace v_denom_time = "future" if valuation_method=="priceest eps(2)"
	replace v_denom_time = "current" if valuation_method=="enterprise value to ebitda (1st quartile)"
	replace v_denom_time = "future" if valuation_method=="priceeps year 1"
	replace v_denom_time = "future" if valuation_method=="equity value to ebitda(f1)"
	replace v_denom_time = "current" if valuation_method=="equity value to earnings(1qtr)"
	replace v_denom_time = "current" if valuation_method=="equity price percent to book value(1qtr)"
	replace v_denom_time = "current" if valuation_method=="price to tangible book value (l0)"
	replace time ="" if v_denom_time=="current"
	replace time ="" if v_denom_time=="past"
	replace time ="" if v_denom_time=="future"

drop v_den




gen synthetic_multiple = v_type + " " + v_numerator + " to " + v_denom_time 
	replace synthetic_multiple = synthetic_multiple + " adjusted" if adj == 1
	replace synthetic_multiple = synthetic_multiple + " " + v_acct_denom


save "$datadir/1B_valuations_categorized", replace 
