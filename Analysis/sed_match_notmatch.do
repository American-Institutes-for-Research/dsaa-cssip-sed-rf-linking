clear
set more off

global data "X:\Rosa\data cj"
global outreg "X:\Rosa\outreg\sed_match_notmatch_v1 cj"

*******************************************************************************/*
  SED Occupation Paper
 
 Created by: Rosa Castro Zarzur, rcastrozarzur@air.org ; December 20, 2015

********************************************************************************/

***************************************************************************

/*  COMPARING SED INDIVIDUALS THAT WERE MATCHED TO UMETRICS WITH THOSE THAT 
	WERE NOT MATCHED													      */
	
********************************************************************************

clear
local db "DRIVER={MySQL ODBC 5.1 Driver};SERVER=[server name];DATABASE=[database name];UID=[username];PWD=[password]"
local sql2 "SELECT * FROM sed_occ_match_notmatch_v1"
odbc load, exec("`sql2'") conn("`db'") clear

gen university = "Caltech" if PHDINST == "110404"
replace university = "Umich" if PHDINST == "170976" 
replace university = "OSU" if PHDINST == "204796"
replace university = "Purdue" if PHDINST == "243780"
replace university = "UWisconsin" if PHDINST == "240444"
replace university = "UMN" if PHDINST == "174066"
replace university = "UIowa" if PHDINST == "153658"
replace university = "UChicago" if PHDINST == "144050"
replace university = "UIndiana" if PHDINST == "151351"
replace university = "PSU" if PHDINST == "214777"

drop if university==""
drop if PHDCY< 2007

tostring __employee_id, replace

save "${data}\sed_occ_match_notmatch_v1", replace

merge m:1  __employee_id university using "${data}\umetrics_sed_matched_processed.dta"

gen match=1 if _merge==3
replace match=0 if _merge!=3
drop _merge

gen notmatch=1 if match==0
replace notmatch=0 if match==1 

foreach var of varlist ever2_* funded{
replace `var'=0 if match==0
}
/**/

* variable creation and data miscellaneous

/* labeling primary source of funding : Question A5 */

 replace SRCEPRIM =	"Fellowship, scholarship" if SRCEPRIM=="A"
 replace SRCEPRIM =	"Grant" if SRCEPRIM=="B"
 replace SRCEPRIM =	"Teaching assistantship" if SRCEPRIM=="C"
 replace SRCEPRIM =	"Research assistantship" if SRCEPRIM=="D"
 replace SRCEPRIM =	"Other assistantship" if SRCEPRIM=="E"
 replace SRCEPRIM =	"Traineeship" if SRCEPRIM=="F"
 replace SRCEPRIM =	"Internship, clinical residency" if SRCEPRIM=="G"
 replace SRCEPRIM =	"Loans (from any source)" if SRCEPRIM=="H"
 replace SRCEPRIM =	"Personal savings" if SRCEPRIM=="I"
 replace SRCEPRIM =	"Personal earnings during graduate school" if SRCEPRIM=="J"
 replace SRCEPRIM =	"Spouse’s, partner’s, or family’s earnings or savings" if SRCEPRIM=="K"
 replace SRCEPRIM =	"Employer reimbursement/assistance" if SRCEPRIM=="L"
 replace SRCEPRIM =	"Foreign (non-U.S.)" if SRCEPRIM=="M"
 replace SRCEPRIM =	"Other" if SRCEPRIM=="N"
 replace SRCEPRIM = "Missing" if SRCEPRIM==""
	   
label var SRCEA "Fellowship, scholarship"
label var SRCEB "Grant"
label var SRCEC "Teaching assistantship"
label var SRCED "Research assistantship"
label var SRCEE "Other assistantship"
label var SRCEF "Traineeship"
label var SRCEG "Internship, clinical residency"
label var SRCEH "Loans (from any source)"
label var SRCEI "Personal savings"
label var SRCEJ "Personal earnings during graduate school"
label var SRCEK "Spouse’s, partner’s, or family’s earnings or savings"
label var SRCEL "Employer reimbursement/assistance"
label var SRCEM "Foreign (non-U.S.) support"
label var SRCEN "Other – specify"

gen SRCEMISS = 1 if SRCEA==. & SRCEB==. & SRCEC==. & SRCED==. & SRCEE==. & SRCEF==. & SRCEG==. ///
					 & SRCEH==. & SRCEI==. & SRCEJ==. & SRCEK==. & SRCEL==. & SRCEM==. & SRCEN==.
					 
label var SRCEMISS "Missing"

/* Labeling sources of funding: Question A6 */

label define s_l 1 "Yes" 2 "No" 3 "Don't Know"
foreach dept in A B C D E F G H I J K L M N MISS{
label val SRCE`dept' s_l
}
/**/

/* individuals race/ethnicity */

gen asian=1 if ASIAN==1
replace asian=0 if ASIAN!=1 & ASIAN!=.

gen black=1 if BLACK==1
replace black=0 if BLACK!=1 & BLACK!=.

gen white=1 if WHITE==1
replace white=0 if WHITE!=1 & WHITE!=.

gen hispanic=1 if HISPANIC>=1& HISPANIC<=5 & HISPANIC!=.
replace hispanic=0 if HISPANIC==0 & HISPANIC!=.

/* individuals birth place; foreign born */

destring BIRTHPL,replace
gen foreignborn=1 if BIRTHPL>=100 & BIRTHPL<=555 & BIRTHPL!=.
replace foreignborn=0 if BIRTHPL>=1 & BIRTHPL<=99 & BIRTHPL!=.

destring EDMOTHER,replace
destring EDFATHER,replace

gen motherba=1 if EDMOTHER>=4 & EDMOTHER<=7 & EDMOTHER!=.
replace motherba=0 if EDMOTHER<4 & EDMOTHER!=.
gen fatherba=1 if EDFATHER>=4 & EDFATHER<=7 & EDFATHER!=.
replace fatherba=0 if EDFATHER<4 & EDFATHER!=.

/* dummy indicating if both parents have a BA degree */

gen parentsba=1 if motherba==1 & fatherba==1
replace parentsba=0 if fatherba==0 | motherba==0
replace parentsba=. if motherba==. & fatherba==.

/* individual's gender */
gen female=1 if SEX=="2"
replace female=0 if SEX=="1"

/*Individuals' post graduate plans */

gen postdoc=1 if PDOCPLAN == 0 | PDOCPLAN == 1	
replace postdoc=0 if postdoc==. & PDOCPLAN!=.

gen Postdocfellowship = 1 if PDOCPLAN == 0
replace Postdocfellowship = 0 if PDOCPLAN != 0 & PDOCPLAN != .

gen Postdocresassociateship = 1 if PDOCPLAN == 1
replace Postdocresassociateship = 0 if PDOCPLAN != 1 & PDOCPLAN != .

gen Traineeship = 1 if PDOCPLAN == 2
replace Traineeship = 0 if PDOCPLAN != 2 & PDOCPLAN != .

gen Internship = 1 if PDOCPLAN == 3
replace Internship = 0 if PDOCPLAN != 3 & PDOCPLAN != .

gen Otherstudy = 1 if  PDOCPLAN == 4
replace Otherstudy = 0 if  PDOCPLAN != 4 & PDOCPLAN != .

gen Unspecifiedtraining = 1 if PDOCPLAN == 5
replace Unspecifiedtraining = 0 if PDOCPLAN != 5 & PDOCPLAN != .

gen Employmentotherthanabove = 1 if PDOCPLAN == 6
replace Employmentotherthanabove = 0 if PDOCPLAN != 6 & PDOCPLAN != .

gen Militaryservice = 1 if PDOCPLAN == 7
replace Militaryservice = 0 if PDOCPLAN != 7 & PDOCPLAN != .

gen Otheremployment = 1 if PDOCPLAN == 8
replace Otheremployment = 0 if PDOCPLAN != 8 & PDOCPLAN != .

gen Unspecifiedemployment = 1 if PDOCPLAN == 9
replace Unspecifiedemployment = 0 if PDOCPLAN != 9 & PDOCPLAN != .

gen Skippedquestion = 1 if PDOCPLAN == 99
replace Skippedquestion=0 if PDOCPLAN != 99 & PDOCPLAN != .

gen Missing = 1 if PDOCPLAN==.
replace Missing=0 if PDOCPLAN!=.


* post-graduation plans label variables
label def pdocplan 0 "PostDoc Fellowship" 1 "PostDoc Research Associateship" 2 "Traineeship" 3 "Internship" 4 "Other Study or Training" 5 "Unspecified Study or Training" ///
		  6 "Employment Other Than Above" 7 "Military Service" 8 "Other Employment" 9 "Unspecified Employment" 99 "Logical Skip"

label values PDOCPLAN pdocplan

* post graduation work activity 

label def pdwkprim 0 "Research and Development" 1 "Teaching" 2 "Management or Administration" 3 "Professional Services to Individuals" 5 "Other" 99 "Logical Skip"
label val PDWKPRIM pdwkprim

label def pdwksec 0"Research and Development" 1 "Teaching" 2 "Management or Administration" 3 "Professional Services to Individuals" 5 "Other" 99 "Logical Skip"
label val PDWKSEC pdwksec

gen pd_rd=1 if PDWKPRIM==0
replace pd_rd=0 if pd_rd==. & PDWKPRIM!=.

*year dummies
tab PHDCY, gen(y)
rename (y1 y2 y3 y4 y5 y6) (y2007 y2008 y2009 y2010 y2011 y2012)

* phd field dummies
gen field_agribio=1 if PHDDISS<200
replace field_agribio=0 if field_agribio==. & PHDDISS!=.

gen field_health=1 if PHDDISS<300 & PHDDISS>=200
replace field_health=0 if field_health==. & PHDDISS!=.

gen field_engineering=1 if PHDDISS<400 & PHDDISS>=300
replace field_engineering=0 if field_engineering==. & PHDDISS!=.

gen field_compmath=1 if PHDDISS<500 & PHDDISS>=400
replace field_compmath=0 if field_compmath==. & PHDDISS!=.

gen field_physical=1 if PHDDISS<600 & PHDDISS>=500
replace field_physical=0 if field_physical==. & PHDDISS!=.

gen field_psychology=1 if PHDDISS<650 & PHDDISS>=600
replace field_psychology=0 if field_psychology==. & PHDDISS!=.

gen field_social=1 if PHDDISS<700 & PHDDISS>=650
replace field_social=0 if field_social==. & PHDDISS!=.

gen field_humanities=1 if field_agribio==0 & field_health==0 & field_engineering==0 & field_compmath==0 ///
						& field_physical==0 & field_psychology==0 & field_social==0 & PHDDISS!=.
replace field_humanities=0 if field_humanities==. & PHDDISS!=.

* us citizen
gen uscitizen=1 if BIRTHPL>0 & BIRTHPL<=99 & BIRTHPL!=.
replace uscitizen=0 if BIRTHPL>9 & BIRTHPL<=555 & BIRTHPL!=.

*tuition remision

gen tui_rem=1 if TUITREMS==4
replace tui_rem=0 if tui_rem==. & TUITREMS!=.


********************************************************************************
/*                                SOME TABLES                                 */  
********************************************************************************
* matched & non-matched
preserve

keep match notmatch PHDCY university
gen total_sed=1
gen match_caltech=1 if match==1 & university=="Caltech"
gen match_umich=1 if match==1 & university=="Umich"
gen match_osu=1 if match==1 & university =="OSU"
gen match_purdue=1 if match==1 & university == "Purdue"
gen match_wi=1 if match==1 & university == "UWisconsin"
gen match_umn=1 if match==1 & university =="UMN"
gen match_iowa=1 if match==1 & university =="UIowa"
gen match_indiana=1 if match ==1 & university == "UIndiana"
gen match_psu=1 if match==1 & university == "PSU"
collapse (sum) total_sed match match_caltech match_umich, by(PHDCY)
export excel using "${outreg}\t0", replace firstrow(variables)

restore

* Comparing demographics between SED matched and non-matched individuals *

 local _w1 asian black white hispanic foreignborn motherba fatherba parentsba female
 local _w2 2 3 4 5 6 7 8 9 10 11 12 13 14 

foreach x in asian black white hispanic foreignborn motherba fatherba parentsba female{

   gettoken w1 _w1: _w1
   gettoken w2 _w2: _w2
		
   reg  `w1' match notmatch, noconstant
   putexcel A1=("Demographic") B1=("Proportion in Match Sample") ///
			C1=("Proportion in Not-Matched Sample") D1=("P-value of Difference") ///
			using "${outreg}\t1", modify
   
   putexcel A`w2'=("`w1'") using "${outreg}\t1", modify
   putexcel B`w2'=matrix(e(b)) using "${outreg}\t1", modify
   
   test match==notmatch
   
   putexcel D`w2'=matrix(r(p)) using "${outreg}\t1", modify
}
/**/

* Comparing post-doctoral plans between SED matched and non-matched individuals *

local _w1 Postdocfellowship Postdocresassociateship Traineeship Internship Otherstudy Unspecifiedtraining Employmentotherthanabove Militaryservice Otheremployment Unspecifiedemployment Skippedquestion Missing
local _w2 2 3 4 5 6 7 8 9 10 11 12 13 14 

foreach x in Postdocfellowship Postdocresassociateship Traineeship Internship Otherstudy Unspecifiedtraining Employmentotherthanabove Militaryservice Otheremployment Unspecifiedemployment Skippedquestion Missing{

   gettoken w1 _w1: _w1
   gettoken w2 _w2: _w2
		
   reg  `w1' match notmatch, noconstant
   putexcel A1=("PostgradutePlans") B1=("Proportion in Match") ///
			C1=("Proportion in Not-Matched") D1=("P-value of Difference") ///
			using "${outreg}\t2", modify
   
   putexcel A`w2'=("`w1'") using "${outreg}\t2", modify
   putexcel B`w2'=matrix(e(b)) using "${outreg}\t2", modify
   
   test match==notmatch
   
   putexcel D`w2'=matrix(r(p)) using "${outreg}\t2", modify
}
/**/


	  
*"Question A5: Which of the following were sources of financial support during graduate school?"*

preserve 
		
		keep SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL  SRCEMISS
		recode SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS (2=0)
		collapse (sum)SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS
		
		local _w1 `" "Research assistantship" "Teaching assistantship" "Fellowship, scholarship" "Grant"  "Personal savings" "Spouse/partner/family’s earnings/savings" "Loans"  "Personal earnings during graduate school" "Traineeship" "Internship, clinical residency" "Other assistantship" "Foreign (non-U.S.) support" "Employer reimbursement/assistance" "Missing" "'
		local _w2 2 3 4 5 6 7 8 9 10 11 12 13 14 15
		
		foreach var in SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS{
		gettoken w1 _w1: _w1
		gettoken w2 _w2: _w2
		dis in red "`w1' and `w2'"
		
		putexcel A1=("Question A5: Which of the following were sources of financial support during graduate school?") using "${outreg}\t3", modify
		putexcel B`w2'=("`w1'") using "${outreg}\t3", modify
		
		sum `var'
		putexcel C1=("Individuals in SED (4,765)") using "${outreg}\t3", modify
		putexcel C`w2'=matrix(r(mean))using "${outreg}\t3", modify
		}
		/**/
restore	
		
preserve 
		keep SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS match
		recode SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS (2=0) 
		keep if match==1
		collapse (sum)SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS
		
	    local _w1 SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS
		local _w2 2 3 4 5 6 7 8 9 10 11 12 13 14 15
		
		foreach var in SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS{
		
		gettoken w1 _w1: _w1
		gettoken w2 _w2: _w2
		
		dis in red "`w1' and `w2'"
	
		sum `var'
		putexcel D1=("Individuals in the umetrics-sed sample") using "${outreg}\t3", modify
		putexcel D`w2'=(r(mean))using "${outreg}\t3", modify
		}
		/**/
restore		   
		
		
preserve 
		keep SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS funded
		recode SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS (2=0) 
		keep if funded==1
		collapse (sum) SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS
		
	    local _w1 SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS
		local _w2 2 3 4 5 6 7 8 9 10 11 12 13 14 15
		
		foreach var in SRCED SRCEC SRCEA SRCEB SRCEI SRCEK SRCEH SRCEJ SRCEF SRCEG SRCEE SRCEM SRCEL SRCEMISS{
		
		gettoken w1 _w1: _w1
		gettoken w2 _w2: _w2
		
		dis in red "`w1' and `w2'"
	
		sum `var'
		putexcel E1=("Individuals in the umetrics-sed sample who were federally funded") using "${outreg}\t3", modify
		putexcel E`w2'=(r(mean))using "${outreg}\t3", modify
		}
		/**/
restore	

*"Question A6: Which of the following were sources of financial support during graduate school?" (PRIMARY)*

preserve

	keep SRCEPRIM match funded
	gen sed=1
	collapse (sum) sed match funded, by(SRCEPRIM)
	gsort -match
	gen prop=match/sed
	export excel  "${outreg}\t4", replace firstrow(variables)
	
restore
			   
* Frequency of Post-Graduation plans including the missings

tab PDOCPLAN PHDCY, missing matcell(cell) matrow(rows)
putexcel A3=matrix(rows) B3=matrix(cell) using "${outreg}\t5", modify
putexcel A3=("PostDoc Fellowship") A4=("PostDoc Research Associateship") A5=("Traineeship")  A6=("Internship") A7=("Other Study or Training") ///
		 A8=("Unspecified Study or Training") A9=("Employment Other Than Above") A10=("Military Service") A11=("Other Employment") ///
		 A12=("Unspecified Employment") A13=("Logical Skip") A14=("Missing") using "${outreg}\t5", modify	   
putexcel A2=("Post-Graduation Plans") B2=("2007") C2=("2008") D2=("2009") E2=("2010") F2=("2011") G2=("2012") using "${outreg}\t5", modify		   
				 
* Primary and secondary post-graduation activities
tab PDWKPRIM PHDCY, missing matcell(cell1) matrow(rows1)
putexcel A3=matrix(rows1) B3=matrix(cell1) using "${outreg}\t6", modify
putexcel A3=("Research and Development") A4=("Teaching") A5=("Management or Administration")  A6=("Professional Services to Individuals") A7=("Other") ///
		 A8=("Logical Skip") A9=("Missing") using "${outreg}\t6", modify	   
putexcel A2=(" PRIMARY Post-Graduation Work Activity") B2=("2007") C2=("2008") D2=("2009") E2=("2010") F2=("2011") G2=("2012") using "${outreg}\t6", modify		   

		 
tab PDWKSEC PHDCY, missing matcell(cell2) matrow(rows2)
putexcel A3=matrix(rows1) B3=matrix(cell2) using "${outreg}\t7", modify
putexcel A3=("Research and Development") A4=("Teaching") A5=("Management or Administration")  A6=("Professional Services to Individuals") A7=("Other") ///
		 A8=("Logical Skip") A9=("Missing") using "${outreg}\t7", modify	   
putexcel A2=("SECONDARY Post-Graduation Work Activity") B2=("2007") C2=("2008") D2=("2009") E2=("2010") F2=("2011") G2=("2012") using "${outreg}\t7", modify		   

********************************************************************************
/*                         SOME REGRESSIONS                                   */
********************************************************************************

	global demo "asian black white hispanic uscitizen motherba fatherba parentsba female"
	global yrs "y2008 y2009 y2010 y2011 y2012"
	global agency "ever2_NIH ever2_NSF ever2_DOD ever2_DOE"
	global field "field_health field_engineering field_compmath field_physical field_psychology field_social field_humanities"
	
	* funding

	reg funded $demo $yrs, robust
	outreg using "${outreg}\funded", replace bdec(3) tdec(2) starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust t-statistics in parentheses. * p<01 **p<0.05 ***p<0.01") ///
	title("Determinants of Federal Funding") ctitle("", Federally Funded)
	
	reg ever2_NSF $demo $yrs, robust
	outreg using "${outreg}\funded", merge bdec(3) tdec(2) starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust t-statistics in parentheses. * p<01 **p<0.05 ***p<0.01") ///
	title("Determinants of Federal Funding") ctitle("", NSF Funded)
				   
	reg ever2_NIH $demo $yrs, robust
	outreg using "${outreg}\funded", merge bdec(3) tdec(2) starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust t-statistics in parentheses. * p<01 **p<0.05 ***p<0.01") ///
	title("Determinants of Federal Funding") ctitle("", NIH Funded)
	
	reg ever2_DOD $demo $yrs, robust
	outreg using "${outreg}\funded", merge bdec(3) tdec(2) starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust t-statistics in parentheses. * p<01 **p<0.05 ***p<0.01") ///
	title("Determinants of Federal Funding") ctitle("", DOD Funded)
		
	reg ever2_DOE $demo $yrs, robust
	outreg using "${outreg}\funded", merge bdec(3) tdec(2) starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust t-statistics in parentheses. * p<01 **p<0.05 ***p<0.01") ///
	title("Determinants of Federal Funding") ctitle("", DOE Funded)
	
	* Post Doc Plans
	
	reg postdoc funded, robust
	outreg using "${outreg}\postdoc", replace bdec(3) tdec(2) starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust t-statistics in parentheses. * p<01 **p<0.05 ***p<0.01") ///
	title("Determinants of PostDoc Experience") ctitle("", Reg1)
	
	reg postdoc funded $agency, robust
	outreg using "${outreg}\postdoc", merge bdec(3) tdec(2) starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust t-statistics in parentheses. * p<01 **p<0.05 ***p<0.01") ///
	title("Determinants of PostDoc Experience") ctitle("", Reg2)
	
	reg postdoc funded $field $agency, robust
	outreg using "${outreg}\postdoc", merge bdec(3) tdec(2) starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust t-statistics in parentheses. * p<01 **p<0.05 ***p<0.01") ///
	title("Determinants of PostDoc Experience") ctitle("", Reg3)
	
	reg postdoc funded $field $agency $demo, robust
	outreg using "${outreg}\postdoc", merge bdec(3) tdec(2) starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust t-statistics in parentheses. * p<01 **p<0.05 ***p<0.01") ///
	title("Determinants of PostDoc Experience") ctitle("", Reg4)
	
	reg postdoc funded $field $agency $demo $yrs, robust
	outreg using "${outreg}\postdoc", merge bdec(3) tdec(2) starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust t-statistics in parentheses. * p<01 **p<0.05 ***p<0.01") ///
	title("Determinants of PostDoc Experience") ctitle("", Reg5)
	
	
	
	
	
	
