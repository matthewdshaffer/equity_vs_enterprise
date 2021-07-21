clear all
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
set matsize 10000

/////////////////////////////////////////// 
/////////////////////////////////////////// 

use "$datadir/1D_labeled_dataset", clear

/////////////////////////////////////////// 
/////////////////////////////////////////// 

 
global dv "num_enterprise_ind" 


//create accounting denominator dummies
 /* encode v_acct_denom, gen(v_acct_denom_num)
 global denom_fe "i.v_acct_denom" */  // MS, 12/21: Not clear this makes sense for this RQ. Archive for now. 
 
  	
// Set up controls/fe globals 
 // Controls
	 /* MS, 12/21: For exploratory regs, just control for size (other coviariates might end up being)
	  independent variables of interest. Archive above.
  global controls "wROE wleverage webit_marg premium target_size analyst_ind"  // other premium option... 
  global controls "ROA leverage ni_margin premium target_size analyst_ind"  
 */ 
 
 
 global controls "target_size" 
 
 // Fixed effects: 
  /* MS, 12/21: For exploratory regs, use the 'Alternative Industry cut' from 1D, from Katherine: SIC_Industry
  global fe "i.year i.target_sic_num i.advisor_num" 
  */ 
  
  global fe "i.year i.SIC_Industry i.advisor_num" 

  
  // Bodge: create extra numeric independent variables of interest for exploration...: 
   // put these into previous file eventually. 
  
  gen self_tender_ind = SelfTender != "No"
  gen high_tech_ind = HighTech != "" & HighTech != "Primary Business not Hi-Tech" 
  gen deal_began_rumor_ind = DealBeganasaRumor == "Yes"
  gen friendly_ind = Attitude == "Friendly"
  gen unsolicited_ind = Unsolicited == "Yes"
  gen financial_acquiror_ind = FinancialAcquiror == "Yes"
  replace heldpriorto = 0 if heldpriorto == .
  replace ofCash = 0 if ofCash == . 
  gen acq_blank_check = AcquirorBlank == "Y"
  gen acq_hedge_fund = BuysideHedgeFund == "Yes"
  gen private_negotiations = Privately == "Yes"
   
// Put independent variables of interest into a global so that all regs are the same for sure. 
global indvar_explore "ROA leverage ni_margin premium analyst_ind delaware rumored TargetTerm go_shop going_private analysts mgmt multiple_bidders challenged_deal competing_bidder cash_deal stock_deal hybrid_deal litigation rumored unsolicited NumberofBidders ExpectedSynergies self_tender_ind high_tech_ind deal_began_rumor_ind friendly_ind unsolicited_ind financial_acquiror_ind heldpriorto ofCash acq_blank_check acq_hedge_fund private_negotiations type_transaction_ind acq_public lbo TargetTerm TargetTermMcap" 


winsor2 $indvar_explore, cuts(2 98) replace  // MS: 12/21/. Bodge. RAs were supposed to winsorize cont variables in 1CD. 



foreach indvar in $indvar_explore  {

eststo clear 
	qui: eststo: reg num_enterprise_ind `indvar' $controls $fe , noconstant vce(cluster sdc)
		qui: estadd local fform "Linear", replace
		qui: estadd local obs "Valuation", replace 
		qui: estadd local yearfe "Yes", replace
		qui: estadd local indusfe "Yes", replace
		qui: estadd local advisorfe "Yes", replace

		
		preserve
		
			collapse (mean) num_enterprise_ind `indvar' $controls SIC_Industry year advisor_num, by (sdc_deal_no)
			qui: eststo: reg num_enterprise_ind `indvar' $controls $fe, noconstant 
				qui: estadd local fform "Linear", replace
				qui: estadd local obs "Deal", replace 
				qui: estadd local yearfe "Yes", replace
				qui: estadd local denomfe "No", replace
				qui: estadd local indusfe "Yes", replace
				qui: estadd local advisorfe "Yes", replace

		restore 
		
esttab , ///
		order(`indvar' $controls) ///
		keep(`indvar' $controls ) ///
		b(3) se(2) ar2 pr2 star(* 0.10 ** .05 *** 0.01) label nonotes  ///
		stats(fform obs N r2_a yearfe indusfe advisorfe, labels("Fx" "Observation Level" "Observations" "\$R^{2}$" "Year Fixed Effects" "Industry Fixed Effects" "Advisor Fixed Effects") fmt(%0s %0s %9.0gc %9.4f %9.4f %0s %0s %0s)) nogap cons substitute(\_ _) eqlabels(none) 
eststo clear 
}


/* MS: 12/21/2020: Variables that load...: 

ROA leverage going_private cash_deal stock_deal financial_acquiror_ind ofCash type_transaction_ind acq_public 
*/ 


global indvar_explore "ROA leverage premium going_private cash_deal stock_deal financial_acquiror_ind ofCash type_transaction_ind acq_public" 

su premium 
su premium, detail // MS: 12/21/20: The premium variable is messed up. Can't rely on this result now, need to fix. 
winsor2 premium, cuts(5 95) replace 

winsor2 leverage, cuts(5 95) replace 

foreach indvar in $indvar_explore  {

eststo clear 
	qui: eststo: reg num_enterprise_ind `indvar' $controls $fe , noconstant vce(cluster sdc)
		qui: estadd local fform "Linear", replace
		qui: estadd local obs "Valuation", replace 
		qui: estadd local yearfe "Yes", replace
		qui: estadd local indusfe "Yes", replace
		qui: estadd local advisorfe "Yes", replace
	
	qui: eststo: logit num_enterprise_ind `indvar' $controls $fe , noconstant vce(cluster sdc)
		qui: estadd local fform "Linear", replace
		qui: estadd local obs "Valuation", replace 
		qui: estadd local yearfe "Yes", replace
		qui: estadd local indusfe "Yes", replace
		qui: estadd local advisorfe "Yes", replace


		
		preserve
		
			collapse (mean) num_enterprise_ind `indvar' $controls SIC_Industry year advisor_num, by (sdc_deal_no)
			
			qui: eststo: reg num_enterprise_ind `indvar' $controls $fe, noconstant 
				qui: estadd local fform "Linear", replace
				qui: estadd local obs "Deal", replace 
				qui: estadd local yearfe "Yes", replace
				qui: estadd local denomfe "No", replace
				qui: estadd local indusfe "Yes", replace
				qui: estadd local advisorfe "Yes", replace
				
			qui: eststo: tobit num_enterprise_ind `indvar' $controls $fe, noconstant ll ul
				qui: estadd local fform "Linear", replace
				qui: estadd local obs "Deal", replace 
				qui: estadd local yearfe "Yes", replace
				qui: estadd local denomfe "No", replace
				qui: estadd local indusfe "Yes", replace
				qui: estadd local advisorfe "Yes", replace

		restore 
		
esttab , ///
		order(`indvar' $controls) ///
		keep(`indvar' $controls ) ///
		b(3) se(2) ar2 pr2 star(* 0.10 ** .05 *** 0.01) label nonotes  ///
		stats(fform obs N r2_a yearfe indusfe advisorfe, labels("Fx" "Observation Level" "Observations" "\$R^{2}$" "Year Fixed Effects" "Industry Fixed Effects" "Advisor Fixed Effects") fmt(%0s %0s %9.0gc %9.4f %9.4f %0s %0s %0s)) nogap cons substitute(\_ _) eqlabels(none) 
eststo clear 
}
