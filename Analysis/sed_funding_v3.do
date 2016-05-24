clear
set more off

global data "X:\Rosa\data"
global outreg "X:\Rosa\outreg\sed_funding_v3"

*******************************************************************************/*
  SED Occupation Paper
 
 Created by: Rosa Castro Zarzur, rcastrozarzur@air.org ; February 3, 2016

********************************************************************************/


********************************************************************************
/*           Funding Duration and Gaps - DATA PREPARATION                     */
********************************************************************************

clear
local db "DRIVER={MySQL ODBC 5.1 Driver};SERVER=172.30.66.22;DATABASE=weicheng;UID=wcheng;PWD=aA73176!NEYHDC2JxEp3"
local sql2 "SELECT * FROM sed_occ_link16_v2"
odbc load, exec("`sql2'") conn("`db'") clear

keep if university=="Caltech" | university=="Umich" 

drop if PHDCY<2007

rename (x_employee_id x_cfda period_start_date period_end_date x_unique_award_number __award_id recipient_account_number) (employeeid cfda periodstart periodend uniqueawardnumber awardid rac)

* just keep the years while the individual is doing her PhD
gen year=year(periodstart)
gen month=month(periodstart)

** generate dummies indicating if an award is federal or non-federal

gen agency_code = substr(cfda,1,2)
destring agency_code, replace

gen federal=1 if agency_code!=0
replace federal=0 if agency_code==0

gen non_fed=1 if agency_code==0
replace non_fed=0 if agency_code!=0

** Drop everything that is non-fed
drop if non_fed==1

** generate agency dummies 

//NIH 93,NSF 47,Dept of Agriculture 10,Dept of Defense 12,Dept of Energy 81

tab agency_code, gen(ind)

rename (ind22 ind18 ind14 ind5)  (NIH_ind  DOE_ind  NSF_ind DOD_ind)

gen federal_ind=1 if federal==1

bysort employeeid university periodstart periodend: gen aux = _n

foreach x in NIH NSF DOD DOE federal{
sort employeeid university periodstart periodend aux
gen `x'_payperiod=1 if `x'_ind==1
bysort employeeid university periodstart periodend: replace `x'_payperiod= `x'_payperiod[_n-1] if  `x'_payperiod==.
gsort employeeid university periodstart periodend -aux
bysort employeeid university periodstart periodend: replace `x'_payperiod= `x'_payperiod[_n-1] if  `x'_payperiod==.

replace `x'_payperiod=0 if `x'_payperiod==.
}
/**/

foreach x in 1 2 3 4 6 7 8 9 10 11 12 13 15 16 17 19 20 21 23 24 25{
sort employeeid university periodstart periodend aux
gen a`x'_payperiod=1 if ind`x'==1
bysort employeeid university periodstart periodend: replace a`x'_payperiod= a`x'_payperiod[_n-1] if  a`x'_payperiod==.
gsort employeeid university periodstart periodend -aux
bysort employeeid university periodstart periodend: replace a`x'_payperiod= a`x'_payperiod[_n-1] if  a`x'_payperiod==.

replace a`x'_payperiod=0 if a`x'_payperiod==.
}
/**/

** Number of awards worked on 6 years prior to PhD graduation

bysort employeeid university uniqueawardnumber rac: gen employeeid_uan_rac=_n
replace employeeid_uan_rac=. if  employeeid_uan_rac!=1

bysort employeeid university uniqueawardnumber rac: egen max_periodstart=max(periodstart)
bysort employeeid university uniqueawardnumber rac: egen min_periodstart=min(periodstart)

bysort employeeid university uniqueawardnumber rac: gen max_year=year(max_periodstart)
bysort employeeid university uniqueawardnumber rac: gen min_year=year(min_periodstart)
bysort employeeid university uniqueawardnumber rac: gen max_month=month(max_periodstart)
bysort employeeid university uniqueawardnumber rac: gen min_month=month(min_periodstart)

replace employeeid_uan_rac=0 if max_year<PHDENTRY
replace employeeid_uan_rac=0 if PHDCY<min_year
replace employeeid_uan_rac=0 if PHDCY==min_year & PHDMONTH<min_month
replace employeeid_uan_rac=0 if PHDCY-6>max_year
replace employeeid_uan_rac=0 if PHDCY-6==max_year & PHDMONTH>=max_month


bysort employeeid university: egen awards=total(employeeid_uan_rac)
replace awards=. if PHDENTRY==.

** employment gaps

gen transaction_period= mofd(periodstart)

gen phd_date = mdy(PHDMONTH,1,PHDCY)
replace phd_date = mofd(phd_date)

format transaction_period phd_date %tm

** number of months not working before graduation: 

bysort employeeid university: gen gap1 = phd_date - transaction_period 
replace gap1=. if PHDCY<year
replace gap1=. if gap1<0
replace gap1=0 if phd_date==transaction_period

bysort employeeid university: egen min_gap1=min(gap1)
replace min_gap1=. if PHDENTRY==.

** years to complete PhD

gen yrs_complete_phd= PHDCY-PHDENTRY

** keep one observation per individual per transaction period

bysort employeeid university periodstart periodend: gen drop=_n
drop if drop!=1

bysort employeeid university: gen n1=_n
replace n1=. if n1!=1

** payperiods (months) worked before PhD graduation: various time periods 

** Important note: we can do this because pay periods for Caltech and UMich are of 1 month!  

br employeeid transaction_period phd_date

gen months_yrs6_bphd = 1
replace months_yrs6=0 if year<PHDENTRY 
replace months_yrs6=0 if PHDCY< year
replace months_yrs6=0 if PHDCY==year & PHDMONTH<month
replace months_yrs6=0 if PHDCY-6>year
replace months_yrs6=0 if PHDCY-6==year & PHDMONTH>=month

bysort employeeid university: egen months_years6_bphd=total(months_yrs6)
replace months_years6_bphd=. if PHDENTRY==.

tab months_years6_bphd if n1==1

drop months_yrs6

/**/


** ever funded by federal agencies in the period of 6 years before their PhD graduation
*	6 years = median time to graduate from PhD 

foreach x in NIH NSF DOD DOE federal{
gen funded_`x'=1 if `x'_payperiod==1
replace funded_`x'=0 if year<PHDENTRY
replace funded_`x'=0 if PHDCY< year
replace funded_`x'=0 if PHDCY==year & PHDMONTH<month
replace funded_`x'=0 if PHDCY-6>year
replace funded_`x'=0 if PHDCY-6==year & PHDMONTH>=month
replace funded_`x'=0 if funded_`x'==.

bysort employeeid university: egen ever6_`x'=max(funded_`x')
replace ever6_`x'=. if PHDENTRY==.
}
/**/

foreach x in 1 2 3 4 6 7 8 9 10 11 12 13 15 16 17 19 20 21 23 24 25{
gen funded_`x'=1 if a`x'_payperiod==1
replace funded_`x'=0 if year<PHDENTRY
replace funded_`x'=0 if PHDCY< year
replace funded_`x'=0 if PHDCY==year & PHDMONTH<month
replace funded_`x'=0 if PHDCY-6>year
replace funded_`x'=0 if PHDCY-6==year & PHDMONTH>=month
replace funded_`x'=0 if funded_`x'==.

bysort employeeid university: egen ever6_`x'=max(funded_`x')
replace ever6_`x'=. if PHDENTRY==.
}
/**/

** only funded by a federal agency in the period of 6 years before their PhD graduation
order ever6_*, after(min_gap1)

local ever "ever6_NIH ever6_NSF ever6_DOD ever6_DOE ever6_1 ever6_2 ever6_3 ever6_4 ever6_6 ever6_7 ever6_8 ever6_9 ever6_10 ever6_11 ever6_12 ever6_13 ever6_15 ever6_16 ever6_17 ever6_19 ever6_20 ever6_21 ever6_23 ever6_24 ever6_25"

egen total_sources = rowtotal(`ever')
replace total_sources=. if PHDENTRY==.

* the variable below is created for the purpose of generating frequencies of individuals that were funded by exactly 2 and 3 more agencies. 

local ever_other "ever6_1 ever6_2 ever6_3 ever6_4 ever6_6 ever6_7 ever6_8 ever6_9 ever6_10 ever6_11 ever6_12 ever6_13 ever6_15 ever6_16 ever6_17 ever6_19 ever6_20 ever6_21 ever6_23 ever6_24 ever6_25"

egen ever_other_sources = rowtotal(`ever_other')

gen ever_other = 1 if ever_other_sources > 0 & ever_other_sources!=.
replace ever_other = 0 if ever_other_sources ==0
replace ever_other = 0 if ever6_federal==0
replace ever_other =. if PHDENTRY==.

* the variable below, ever6_federal_other is created for regressions purposes. It equal 1 when the individual was funded by a federal agency that is different to NSF, NIH, DOD, DOE and NOTTTTT funded by  NSF, NIH, DOD, DOE.

gen ever6_federal_other = 1 if ever6_federal==1
replace ever6_federal_other=0 if ever6_NSF==1 | ever6_NIH==1 | ever6_DOD==1 | ever6_DOE==1
replace ever6_federal_other=0 if ever6_federal==0
replace ever6_federal_other=. if PHDENTRY==.

gen only6_NIH=1 if ever6_NIH==1 & total_sources==1
replace only6_NIH=0 if only6_NIH==.
replace only6_NIH=. if PHDENTRY==.

gen only6_NSF=1 if ever6_NSF==1 & total_sources==1
replace only6_NSF=0 if only6_NSF==.
replace only6_NSF=. if PHDENTRY==.

gen only6_DOE=1 if ever6_DOE==1 & total_sources==1
replace only6_DOE=0 if only6_DOE==.
replace only6_DOE=. if PHDENTRY==.

gen only6_DOD=1 if ever6_DOD==1 & total_sources==1
replace only6_DOD=0 if only6_DOD==.
replace only6_DOD=. if PHDENTRY==.

gen only6_federal_other=1 if total_sources==1 & only6_DOD==0 & only6_DOE==0 & only6_NSF==0 & only6_NIH==0
replace only6_federal_other=0 if only6_federal_other==.
replace only6_federal_other=. if PHDENTRY==.

gen multiple_sources=1 if total_sources>1 & total_sources!=.
replace multiple_sources=0 if total_sources==1
replace multiple_sources=. if PHDENTRY==.
replace multiple_sources=0 if ever6_federal==0

keep employeeid university months_years6_bphd min_gap1 yrs_complete_phd ever6_NIH ever6_NSF ever6_DOD ever6_DOE ever6_federal ever6_federal_other ever_other ever_other_sources ///
     __employee_id awards BIRTHPL TUITREMS PHDENTRY PHDCY PHDMONTH only6_NIH only6_NSF only6_DOE only6_DOD only6_federal_other total_sources multiple_sources 
	  
	
duplicates drop

gen funded=1 if ever6_federal==1
replace funded=0 if ever6_federal==0

unique employeeid university

save "${data}\umetrics_sed_matched_processed.dta", replace

********************************************************************************
          /* now let's bring in the not-matched individuals */
********************************************************************************

merge 1:m __employee_id university using "${data}\sed_occ_match_notmatch_v1"

gen match=1 if _merge==3
replace match=0 if _merge==2

gen notmatch=1 if match==0
replace notmatch=0 if match==1 

foreach var of varlist funded ever6_* only6_* awards months_years6_bphd total_sources multiple_sources{
replace `var'= 0 if _merge!=3
}
/**/

drop _merge

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

gen asian=1 if RACE==1 | RACE==3
replace asian=0 if RACE!=3 & RACE!=1 & RACE!=.

gen black=1 if RACE==5
replace black=0 if RACE!=5 & RACE!=.

gen white=1 if RACE==10
replace white=0 if RACE!=10 & RACE!=.

gen hispanic=1 if RACE>=6 & RACE<=9
replace hispanic=0 if (RACE<6 | RACE>9) & RACE!=.

gen other_race=1 if asian==0 & black==0 & white==0 & hispanic==0 
replace other_race =0 if other_race==. & RACE!=.
replace other_race=. if RACE==.

gen race = "Hispanic" if hispanic==1
replace race = "White" if white==1
replace race = "Black" if black==1
replace race = "Asian" if asian==1
replace race = "Other" if other_race==1
 

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

/* Individual's intention to take Post Doc Position : Question B2: "Do you intend to take a "postdoc" position?" */

gen postdoc_b2=1 if POSTDOC==1
replace postdoc_b2 = 0 if POSTDOC==2

/* Individual who have a definite Post Doc plan after graduation: Question B4a */

gen definite_plans=1 if (PDOCSTAT=="0" | PDOCSTAT=="1")
replace definite_plans=0 if definite_plans==. & PDOCSTAT!=""

* only individuals with definite plans answer PDOCPLAN. Create variable of DEFINITE postdoc position or further training.

gen postdoc_b4a=1 if PDOCPLAN>=0 & PDOCPLAN<=5 & PDOCPLAN!=. 
replace postdoc_b4a=0 if PDOCPLAN>5 & PDOCPLAN<=9 & PDOCPLAN!=. 
replace postdoc_b4a=. if PDOCPLAN==99 

* Create variable to flag individuals with definite plans that will work for the private sector */

gen private = 1 if PDEMPLOY=="K" | PDEMPLOY=="L"
replace private = 0 if private==. & PDEMPLOY!="" & PDEMPLOY!="99"
replace private = . if PDEMPLOY=="99" | PDEMPLOY==""	

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

gen RD_primwk=1 if PDWKPRIM==0
replace RD_primw=0 if RD_primw==. & PDWKPRIM!=. & PDWKPRIM!=99
replace RD_primw=. if PDWKPRIM==. & PDWKPRIM==99

*year dummies
tab PHDCY, gen(y)
rename (y1 y2 y3 y4 y5 y6) (y2007 y2008 y2009 y2010 y2011 y2012)

* phd field dummies
gen field_agri=1 if PHDDISS>=0 & PHDDISS<100
replace field_agri=0 if field_agri==. & PHDDISS!=.

gen field_bio=1 if PHDDISS<200 & PHDDISS>=100
replace field_bio=0 if field_bio==. & PHDDISS!=.

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

gen field_humanities=1 if field_agri==0 & field_bio==0 & field_health==0 & field_engineering==0 & field_compmath==0 ///
						& field_physical==0 & field_psychology==0 & field_social==0 & PHDDISS!=.
replace field_humanities=0 if field_humanities==. & PHDDISS!=.

gen sed_field="Agriculture" if PHDDISS>=0 & PHDDISS<100 & PHDDISS!=.
replace sed_field = "Biology" if PHDDISS<200 & PHDDISS>=100 & PHDDISS!=.
replace sed_field="Health Sciences" if PHDDISS<300 & PHDDISS>=200 & PHDDISS!=.
replace sed_field="Engineering" if PHDDISS<400 & PHDDISS>=300 & PHDDISS!=.
replace sed_field="Computer/Mathematical Sciences" if PHDDISS<500 & PHDDISS>=400 & PHDDISS!=.
replace sed_field="Physical Sciences" if PHDDISS<600 & PHDDISS>=500 & PHDDISS!=.
replace sed_field="Psychology" if PHDDISS<650 & PHDDISS>=600 & PHDDISS!=.
replace sed_field= "Social Sciences" if PHDDISS<700 & PHDDISS>=650 & PHDDISS!=.
replace sed_field="Humanities" if field_agri==0 & field_bio==0 & field_health==0 & field_engineering==0 & field_compmath==0 & field_physical==0 & field_psychology==0 & field_social==0 & PHDDISS!=.

* us citizen
gen uscitizen=1 if BIRTHPL>0 & BIRTHPL<=99 & BIRTHPL!=.
replace uscitizen=0 if BIRTHPL>99 & BIRTHPL<=555 & BIRTHPL!=.

*tuition remision

gen tui_rem=1 if TUITREMS==4
replace tui_rem=0 if tui_rem==. & TUITREMS!=.

* bringing in team size
	
merge m:1 __employee_id using "${data}\teamsize_v1.dta"
drop _merge
replace av_teamsize=0 if av_teamsize==. & funded==0
 
label var  postdoc_b2 "PDOCPlans"
label var  postdoc_b4a "PDOC/Tr"
label var private "PrivateWk"
label var RD_ "R&D"
  
save "X:\Rosa\outreg\sed_funding_v3\SED_UMETRICS_workingdata.dta", replace

gen teamsize = av_teamsize
replace teamsize=10 if av_teamsize>=10

rename av_teamsize orig_teamsize
rename teamsize av_teamsize

* university dummies

tab university, gen(dum)
rename (dum1 dum2) (caltech umich) 

*
/*                            GRAPHS & TABLES                                 */


* Individuals Funded 6 years before PhD graduation: Table by Year of graduation

tab PHDCY funded, miss matcell(cell) matrow(rows)
putexcel A1=("Federally Funded PhD Graduates 6 Years Before Graduation")using "${outreg}\t1", modify
putexcel A3=matrix(rows) B3=matrix(cell) using "${outreg}\t1", modify
putexcel A2=("Year of Graduation of PhD") B2=("Not Federally Funded") C2=("Federally Funded") using "${outreg}\t1", modify

				  
* Proportion funded, mean number of quarters funded, median number of quarters funded, mean number of awards worked on, median number of awards worked on				  
		  
putexcel A1=("SED Cohorts 2007-2012: Statistics 6 years before PhD Completion")using "${outreg}\t2", modify

sum funded, d
putexcel  A2=("Proportion of Federally Funded") B2=matrix(r(mean)) using "${outreg}\t2", modify
sum months_years6_bphd if funded==1,d 
putexcel  A3=("Mean number of months federally funded") B3=matrix(r(mean)) using "${outreg}\t2", modify
putexcel  A4=("Median number of months federally funded") B4=matrix(r(p50)) using "${outreg}\t2", modify
sum awards if funded==1,d 
putexcel  A5=("Mean number of awards worked on") B5=matrix(r(mean)) using "${outreg}\t2", modify
putexcel  A6=("Median number of awards worked on") B6=matrix(r(p50)) using "${outreg}\t2", modify

* Individuals funded by EXACLTY 1 agency

preserve
	
	keep if total_sources==1
	
	keep only6_NIH only6_NSF only6_DOE only6_DOD only6_federal_other 
	
	gen total_1agency=1
	
	collapse (sum) total_1agency only6_NIH only6_NSF only6_DOE only6_DOD only6_federal_other 
    export excel using "${outreg}\exactly1_agency.xls", replace firstrow(variables)
restore

* Individuals funded by EXACTLY 2 agencies

preserve

    keep if total_sources==2
	
	keep employeeid university ever6_NIH ever6_NSF ever6_DOE ever6_DOD ever_other ever_other_sources
	
	gen total_2agencies=1
	
	gen NIH_NSF =1 if  ever6_NIH==1 & ever6_NSF==1
	gen NIH_DOD =1 if  ever6_NIH==1 & ever6_DOD==1
	gen NIH_DOE =1 if  ever6_NIH==1 & ever6_DOE==1
	gen NIH_OTHER=1 if ever6_NIH==1 & ever_other==1
	
	gen NSF_DOD =1 if  ever6_NSF==1 & ever6_DOD==1
	gen NSF_DOE =1 if  ever6_NSF==1 & ever6_DOE==1
	gen NSF_OTHER=1 if ever6_NSF==1 & ever_other==1
	
	gen DOD_DOE =1 if  ever6_DOD==1 & ever6_DOE==1
	gen DOD_OTHER=1 if ever6_DOD==1 & ever_other==1
	
	gen DOE_OTHER=1 if ever6_DOE==1 & ever_other==1
	
	gen OTHER_OTHER = 1 if ever_other==1 & ever_other_sources==2
	
	collapse(sum) total_2agencies NIH_NSF NIH_DOD NIH_DOE NIH_OTHER NSF_DOD NSF_DOE NSF_OTHER DOD_DOE DOD_OTHER DOE_OTHER OTHER_OTHER
	
    export excel using "${outreg}\exactly2_agency.xls", replace firstrow(variables)
		
restore

* Individuals funded by EXACTLY 3 agencies


preserve

	keep if funded==1
    keep if total_sources==3
	
	keep employeeid university ever6_NIH ever6_NSF ever6_DOE ever6_DOD ever6_federal_other total_sources ever_other ever_other_sources
	
	gen total_3agencies=1
	
	gen NIH_NSF_DOD = 1 if ever6_NIH==1 & ever6_NSF==1 & ever6_DOD==1
	gen NIH_NSF_DOE = 1 if ever6_NIH==1 & ever6_NSF==1 & ever6_DOE==1
	gen NIH_DOD_DOE = 1 if ever6_NIH==1 & ever6_DOD==1 & ever6_DOE==1
	gen NIH_NSF_OTHER = 1 if ever6_NIH==1 & ever6_NSF==1 & ever_other==1
	gen NIH_DOD_OTHER = 1 if ever6_NIH==1 & ever6_DOD==1 & ever_other==1
	gen NIH_DOE_OTHER = 1 if ever6_NIH==1 & ever6_DOE==1 & ever_other==1
	
	gen NSF_DOD_DOE = 1 if ever6_NSF==1 & ever6_DOD==1 & ever6_DOE==1
	gen NSF_DOD_OTHER = 1 if ever6_NSF==1 & ever6_DOD==1 & ever_other==1
	gen NSF_DOE_OTHER = 1 if ever6_NSF==1 & ever6_DOE==1 & ever_other==1
	
	gen DOD_DOE_OTHER = 1 if ever6_DOD==1 & ever6_DOE==1 & ever_other==1
	
	gen NIH_OTHER_OTHER =1 if ever6_NIH==1 & ever_other==1 & ever6_NSF==0 & ever6_DOD==0 & ever6_DOE==0 &  total_sources==3
	gen NSF_OTHER_OTHER =1 if ever6_NSF==1 & ever_other==1 & ever6_NIH==0 & ever6_DOD==0 & ever6_DOE==0 &  total_sources==3
	gen DOD_OTHER_OTHER =1 if ever6_DOD==1 & ever_other==1 & ever6_NIH==0 & ever6_NSF==0 & ever6_DOE==0 &  total_sources==3
	gen DOE_OTHER_OTHER =1 if ever6_DOE==1 & ever_other==1 & ever6_NIH==0 & ever6_NSF==0 & ever6_DOD==0 &  total_sources==3
	gen OTHER_OTHER_OTHER =1 if ever_other==1 & ever_other_sources==3

	collapse(sum) total_3agencies NIH_NSF_DOD NIH_NSF_DOE NIH_DOD_DOE NIH_NSF_OTHER NIH_DOD_OTHER NIH_DOE_OTHER NSF_DOD_DOE ///
				  NSF_DOD_OTHER NSF_DOE_OTHER DOD_DOE_OTHER NIH_OTHER_OTHER NSF_OTHER_OTHER DOD_OTHER_OTHER DOE_OTHER_OTHER OTHER_OTHER_OTHER
	
    export excel using "${outreg}\exactly3_agency.xls", replace firstrow(variables)
		
restore

*Individuals funded by EXACTLY 4 agencies

preserve

	keep if funded==1
    keep if total_sources==4
	
	keep employeeid university ever6_NIH ever6_NSF ever6_DOE ever6_DOD ever6_federal_other total_sources ever_other ever_other_sources
	
	gen total_4agencies=1
	
	* I did these combinations by hand because all the possible cobinations are too many so I just did the table for the ones that have individuals
	
	gen NIH_NSF_DOD_DOE=1 if ever6_NIH==1 & ever6_NSF==1 & ever6_DOD==1 & ever6_DOE==1
	gen NIH_NSF_DOD_OTHER=1 if ever6_NIH==1 & ever6_NSF==1 & ever6_DOD==1 & ever_other==1
	gen NSF_DOD_DOE_OTHER=1 if ever6_DOE==1 & ever6_NSF==1 & ever6_DOD==1 & ever_other==1
	gen NSF_DOE_OTHER_OTHER =1 if ever6_DOE==1 & ever6_NSF==1 & ever_other==1 & ever_other_sources==2
	gen NSF_OTHER_OTHER_OTHER =1 if ever6_NSF==1 & ever_other==1 & ever_other_sources==3
	gen DOD_OTHER_OTHER_OTHER =1 if ever6_DOD==1 & ever_other==1 & ever_other_sources==3
	
	collapse(sum) total_4agencies NIH_NSF_DOD_DOE NIH_NSF_DOD_OTHER NSF_DOD_DOE_OTHER NSF_DOE_OTHER_OTHER ///
				  NSF_OTHER_OTHER_OTHER DOD_OTHER_OTHER_OTHER
	
    export excel using "${outreg}\exactly4_agency.xls", replace firstrow(variables)
	
restore


*individuals Funded by EXACTLY 5 agencies

preserve

	keep if funded==1
    keep if total_sources==5
	
	keep employeeid university ever6_NIH ever6_NSF ever6_DOE ever6_DOD ever6_federal_other total_sources ever_other ever_other_sources
	
	gen total_5agencies=1
	
	* I did these combinations by hand because all the possible cobinations are too many so I just did the table for the ones that have individuals
	
	gen NIH_NSF_DOD_DOE_OTHER =1 if ever6_NIH==1 & ever6_NSF==1 & ever6_DOD==1 & ever6_DOE==1 & ever_other==1
	gen NIH_DOD_DOE_OTHER_OTHER =1 if ever6_NIH==1 & ever6_DOD==1 & ever6_DOE==1 & ever_other==1 & ever_other_sources==2
	
	collapse(sum) total_5agencies NIH_NSF_DOD_DOE_OTHER NIH_DOD_DOE_OTHER_OTHER 
	
    export excel using "${outreg}\exactly5_agency.xls", replace firstrow(variables)
	
restore



* Funding gap - graph and table
	  		    
sum min_gap1 if funded==1, d
putexcel  B3=matrix(r(mean)) B4=matrix(r(p50)) B5=matrix(r(min)) B6=matrix(r(max)) B7=matrix(r(N)) using "${outreg}\t3", modify
putexcel  A2=("Number of months before graduation WITHOUT federal support") A3=("Mean") A4=("Median") A5=("Min") A6=("Max") using "${outreg}\t3", modify	


* Funding by agency 
preserve
	keep ever6_* funded
	gen sed=1
	collapse (sum) sed funded ever6_*
	export excel using "${outreg}\ag_allyrs.xls", replace firstrow(variables)
restore

* Funding by agency by year

foreach x in NIH NSF DOD DOE{
preserve
	keep PHDCY ever6_`x' only6_`x' funded
	gen sed=1
	collapse (sum) sed funded ever6_`x' only6_`x', by(PHDCY)
	export excel using "${outreg}\t`x'_year.xls", replace firstrow(variables)
restore
}
/**/


* Funding by agency by sex
preserve
	keep ever6_* funded female
	gen sed=1
	drop if female==.
	collapse (sum) sed funded ever6_*, by(female)
	export excel using "${outreg}\ag_allyrs_sex.xls", replace firstrow(variables)
restore

*Funding by agency by race 

preserve
	keep ever6_* funded race
	gen sed=1
	collapse (sum) sed funded ever6_*, by(race)
	export excel using "${outreg}\ag_allyrs_race.xls", replace firstrow(variables)
restore

*Funding by agency by foreign born 

preserve
	keep ever6_* funded uscitizen
	gen sed=1
	collapse (sum) sed funded ever6_*, by(uscitizen)
	export excel using "${outreg}\ag_allyrs_uscitizen.xls", replace firstrow(variables)
restore


* Funding by agency by year by sex

foreach x in NIH NSF DOD DOE{
preserve
	keep PHDCY ever6_`x' only6_`x' funded female
	gen sed=1
	drop if female==.
	collapse (sum) sed funded ever6_`x' only6_`x', by(PHDCY female)
	export excel using "${outreg}\t`x'_year_sex.xls", replace firstrow(variables)
restore
}
/**/

* Funding by agency by year by race

foreach x in NIH NSF DOD DOE{
preserve
	keep PHDCY ever6_`x' only6_`x' funded race
	gen sed=1
	collapse (sum) sed funded ever6_`x' only6_`x', by(PHDCY race)
	export excel using "${outreg}\t`x'_year_race.xls", replace firstrow(variables)
restore
}
/**/

* Funding by agency by year by uscitizen

foreach x in NIH NSF DOD DOE{
preserve
	keep PHDCY ever6_`x' only6_`x' funded uscitizen
	gen sed=1
	collapse (sum) sed funded ever6_`x' only6_`x', by(PHDCY uscitizen)
	export excel using "${outreg}\t`x'_year_uscitizen.xls", replace firstrow(variables)
restore
}
/**/


* Funding by SED Field

preserve
	keep sed_field funded only6_* ever6_*  multiple_sources
	gen sed=1
	collapse (sum) sed funded ever6_NIH only6_NIH ever6_NSF only6_NSF ever6_DOD only6_DOD ever6_DOE only6_DOE ever6_federal_other only6_federal_other multiple_sources, by(sed_field)
	export excel using "${outreg}\ag_allyrs_sedfield.xls", replace firstrow(variables)
restore
	
*Average Support by SED field	

preserve
	keep sed_field funded months_years6_bphd
	keep if funded==1
	collapse (mean) months_years6_bphd, by(sed_field)
	export excel using "${outreg}\av_support_sedfield.xls", replace firstrow(variables)
restore

*Average Support by SED field by agency - ONLY 

preserve  
	keep sed_field funded months_years6_bphd only6_*
	keep if funded==1
	foreach x in only6_NIH only6_NSF only6_DOE only6_DOD only6_federal_other{
	gen avsupport_`x'= months_years6_bphd if `x'==1
	}
	/**/
	collapse (mean) avsupport_*, by(sed_field)
	export excel using "${outreg}\av_support_sedfield_agencyONLY.xls", replace firstrow(variables)
restore	
	
*Average Support by SED field by agency - EVER

preserve  
	keep sed_field funded months_years6_bphd ever6_*
	keep if funded==1
	foreach x in ever6_NIH ever6_NSF ever6_DOE ever6_DOD ever6_federal_other {
	gen avsupport_`x'= months_years6_bphd if `x'==1
	}
	/**/
	collapse (mean) avsupport_*, by(sed_field)
	export excel using "${outreg}\av_support_sedfield_agencyEVER.xls", replace firstrow(variables)
restore	
	
*Mean team size by SED Field

preserve 
		keep sed_field av_teamsize funded
		keep if funded==1
		collapse (mean) av_teamsize, by(sed_field)
		export excel using "${outreg}\mean_teamsize_sedfield.xls", replace firstrow(variables)
restore
		
* matched & non-matched
preserve

keep match notmatch PHDCY university
gen total_sed=1
gen match_caltech=1 if match==1 & university=="Caltech"
gen match_umich=1 if match==1 & university=="Umich"
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
		putexcel C1=("Individuals in SED") using "${outreg}\t3", modify
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
		putexcel D1=("Individuals in the umetrics-SED sample") using "${outreg}\t3", modify
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
		putexcel E1=("Individuals in the umetrics-SED sample who were federally funded ") using "${outreg}\t3", modify
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


*table of ever funded by outcome

  
foreach var of varlist postdoc_b4a private RD_primwk {
	preserve
		keep `var' funded ever6*
		gen sed=1
		collapse (sum) sed funded ever6*, by(`var')
		export excel using "${outreg}\funded_ever_`var'.xls", replace firstrow(variables)
	restore
}
/**/	

* 

********************************************************************************
/*                         SOME REGRESSIONS                                   */
********************************************************************************

	global demo "asian black white hispanic uscitizen motherba fatherba parentsba female"
	global demo2 "asian black white hispanic uscitizen motherba fatherba parentsba"
	global demo3 "asian black white hispanic motherba fatherba parentsba female"
	global yrs "y2008 y2009 y2010 y2011 y2012"
	global agency_ever "ever6_NIH ever6_NSF ever6_DOD ever6_DOE ever6_federal_other"
	global agency_only "only6_NIH only6_NSF only6_DOD only6_DOE only6_federal_other multiple_sources"
	global field "field_bio field_health field_engineering field_compmath field_physical field_psychology field_social field_humanities"
	
	
********************************************************************************		
/*                     DEMOGRAPHICS AND FEDERAL FUNDING                       */
********************************************************************************
	*federally funded
	
	reg funded $demo caltech, robust
	outreg using "${outreg}\funded", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Federal Funding") ctitle("", Federally Funded) landscape
	
	reg funded $demo $yrs caltech, robust
	outreg using "${outreg}\funded", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Federal Funding") ctitle("", Federally Funded)  landscape
	
	
	reg funded $demo $yrs $field caltech, robust
	outreg using "${outreg}\funded", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Federal Funding") ctitle("", Federally Funded)  landscape
	
	* Ever
	
	reg ever6_NSF $demo $yrs $field caltech, robust
	outreg using "${outreg}\funded_ever", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Determinants of Federal Funding") ctitle("", Ever NSF Funded) landscape
				   
	reg ever6_NIH $demo $yrs $field caltech, robust
	outreg using "${outreg}\funded_ever", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Determinants of Federal Funding") ctitle("", Ever NIH Funded) landscape
	
	reg ever6_DOD $demo $yrs $field caltech, robust
	outreg using "${outreg}\funded_ever", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Federal Funding") ctitle("", Ever DOD Funded) landscape
		
	reg ever6_DOE $demo $yrs $field caltech, robust
	outreg using "${outreg}\funded_ever", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Federal Funding") ctitle("", Ever DOE Funded) landscape
	
	* Only
	
	reg only6_NSF $demo $yrs $field caltech, robust
	outreg using "${outreg}\funded_only",replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Federal Funding") ctitle("", Only NSF Funded) landscape
				   
	reg only6_NIH $demo $yrs $field caltech, robust
	outreg using "${outreg}\funded_only", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Federal Funding") ctitle("", Only NIH Funded) landscape
	
	reg only6_DOD $demo $yrs $field caltech, robust
	outreg using "${outreg}\funded_only", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Federal Funding") ctitle("", Only DOD Funded) landscape
		
	reg only6_DOE $demo $yrs $field caltech, robust
	outreg using "${outreg}\funded_only", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Federal Funding") ctitle("", Only DOE Funded) landscape
	
	
********************************************************************************	
/*                                POST DOC PLANS                              */
********************************************************************************

	* EVER all
	
	reg postdoc_b2 funded caltech, robust
	outreg using "${outreg}\postdoc_ever", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc Plans") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever caltech, robust
	outreg using "${outreg}\postdoc_ever", merge bdec(3) se starlevels(10 5 1)  ///
    ctitle("", PDOCPlans) landscape summstat(N \ r2_a) summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever months_years6_bphd caltech, robust
	outreg using "${outreg}\postdoc_ever", merge bdec(3) se starlevels(10 5 1) ///
	ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever $field months_years6_bphd caltech, robust
	outreg using "${outreg}\postdoc_ever", merge bdec(3) se starlevels(10 5 1) ///
	ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_ever $demo months_years6_bphd caltech, robust
	outreg using "${outreg}\postdoc_ever", merge bdec(3) se starlevels(10 5 1) ///
    ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_ever $demo $yrs months_years6_bphd caltech, robust
	outreg using "${outreg}\postdoc_ever", merge bdec(3) se starlevels(10 5 1) ///
	ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER female 
	
	reg postdoc_b2 funded caltech if female==1, robust
	outreg using "${outreg}\postdoc_ever_female", replace bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (FEMALES)") ctitle("", PDOCPlans) landscape ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever  caltech if female==1, robust
	outreg using "${outreg}\postdoc_ever_female", merge bdec(3) se starlevels(10 5 1) ///
    ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever caltech months_years6_bphd if female==1, robust
	outreg using "${outreg}\postdoc_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever $field months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\postdoc_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_ever $demo2 months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\postdoc_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_ever $demo2 $yrs months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\postdoc_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER male 
	
	reg postdoc_b2 funded caltech if female==0, robust
	outreg using "${outreg}\postdoc_ever_male", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc Plans (MALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever caltech if female==0, robust
	outreg using "${outreg}\postdoc_ever_male", merge bdec(3) se starlevels(10 5 1) ///
    ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\postdoc_ever_male", merge bdec(3) se starlevels(10 5 1) ///
    ctitle("", PDOCPlans) landscap summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever $field months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\postdoc_ever_male", merge bdec(3) se starlevels(10 5 1) ///
    ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_ever $demo2  months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\postdoc_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_ever $demo2 $yrs months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\postdoc_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER US citizen 
	
	reg postdoc_b2 funded caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_ever_uscitizen", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	ctitle("", PDOCPlans) landscape summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever  months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever $field months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_ever $demo3 months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_ever $demo3 $yrs months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
		
	*EVER Foreign Born 
	
	reg postdoc_b2 funded caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_ever_foreign", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_ever $field months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_ever $demo3 months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_ever $demo3 $yrs months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	* ONLY all
	
	reg postdoc_b2 funded caltech, robust
	outreg using "${outreg}\postdoc_only", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc Plans") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only caltech, robust
	outreg using "${outreg}\postdoc_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only months_years6_bphd caltech, robust
	outreg using "${outreg}\postdoc_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only $field months_years6_bphd caltech, robust
	outreg using "${outreg}\postdoc_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_only $demo months_years6_bphd caltech, robust
	outreg using "${outreg}\postdoc_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_only $demo $yrs months_years6_bphd caltech, robust
	outreg using "${outreg}\postdoc_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	* ONLY female 
	
	reg postdoc_b2 funded caltech if female==1, robust
	outreg using "${outreg}\postdoc_only_female", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc Plans (FEMALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only caltech if female==1, robust
	outreg using "${outreg}\postdoc_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (FEMALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\postdoc_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (FEMALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only $field months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\postdoc_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (FEMALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_only $demo2 months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\postdoc_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (FEMALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_only $demo2 $yrs months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\postdoc_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (FEMALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	* ONLY male 
	
	reg postdoc_b2 funded caltech if female==0, robust
	outreg using "${outreg}\postdoc_only_male", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc Plans (MALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only caltech if female==0, robust
	outreg using "${outreg}\postdoc_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (MALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\postdoc_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (MALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only $field months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\postdoc_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (MALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_only $demo2 months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\postdoc_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (MALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_only $demo2 $yrs months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\postdoc_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (MALES)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	* ONLY US citizen 
	
	reg postdoc_b2 funded caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_only_uscitizen", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_only_uscitizen", merge bdec(3) se  starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscap ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only $field months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_only $demo3 months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_only $demo3 $yrs months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\postdoc_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (US Citizens)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
		
	* ONLY Foreign Born 
	
	reg postdoc_b2 funded caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_only_foreign", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $agency_only $field months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_only $demo3 months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b2 $field $agency_only $demo3 $yrs  months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\postdoc_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc Plans (Foreign Born)") ctitle("", PDOCPlans) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
********************************************************************************	
/*                          DEFINITE POST DOC PLANS                            */ 
********************************************************************************
		
	* EVER all
	
	reg postdoc_b4a funded caltech, robust
	outreg using "${outreg}\definite_postdoc_ever", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_ever caltech, robust
	outreg using "${outreg}\definite_postdoc_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg  postdoc_b4a $agency_ever months_years6_bphd caltech, robust
	outreg using "${outreg}\definite_postdoc_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_ever $field months_years6_bphd caltech, robust
	outreg using "${outreg}\definite_postdoc_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg  postdoc_b4a $field $agency_ever $demo months_years6_bphd caltech, robust
	outreg using "${outreg}\definite_postdoc_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg  postdoc_b4a $field $agency_ever $demo $yrs months_years6_bphd caltech, robust
	outreg using "${outreg}\definite_postdoc_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER female 
	
	reg postdoc_b4a funded caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_ever_female", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_ever caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_ever months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_ever $field months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_ever $demo2 months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_ever $demo2 $yrs months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER male 
	
	reg postdoc_b4a  funded caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_ever_male", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_ever caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_ever months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_ever $field months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_ever $demo2 months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_ever $demo2 $yrs months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER US citizen
	
	reg postdoc_b4a funded caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_ever_uscitizen", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_ever caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_ever  months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_ever $field months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_ever $demo3 months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_ever $demo3 $yrs months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
		
	*EVER Foreign Born 
	
	reg postdoc_b4a funded caltech if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_ever_foreign", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_ever caltech if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_ever months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_ever $field months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_ever $demo3 months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_ever $demo3 $yrs months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	* ONLY all
	
	reg postdoc_b4a funded caltech, robust
	outreg using "${outreg}\definite_postdoc_only", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_only caltech, robust
	outreg using "${outreg}\definite_postdoc_only", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg  postdoc_b4a $agency_only months_years6_bphd caltech, robust
	outreg using "${outreg}\definite_postdoc_only", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_only $field months_years6_bphd caltech, robust
	outreg using "${outreg}\definite_postdoc_only", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg  postdoc_b4a $field $agency_only $demo months_years6_bphd caltech, robust
	outreg using "${outreg}\definite_postdoc_only", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg  postdoc_b4a $field $agency_only $demo $yrs months_years6_bphd caltech, robust
	outreg using "${outreg}\definite_postdoc_only", merge bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*ONLY female 
	
	reg postdoc_b4a funded caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_only_female", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_only caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_only months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_only $field months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_only $demo2 months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_only $demo2 $yrs months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\definite_postdoc_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (FEMALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*ONLY male 
	
	reg postdoc_b4a funded caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_only_male", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_only caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_only months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_only $field months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_only $demo2 months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_only $demo2 $yrs months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\definite_postdoc_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (MALES)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*ONLY US citizen 
	
	reg postdoc_b4a funded caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_only_uscitizen", replace bdec(3) se starlevels(10 5 1) ///
    note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("",PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_only caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_only months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_only $field months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_only $demo3 months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_only $demo3 $yrs months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\definite_postdoc_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (US Citizens)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
		
	*ONLY Foreign Born 
	
	reg postdoc_b4a funded caltech if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_only_foreign", replace bdec(3) se starlevels(10 5 1) ///
    note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_only caltech  if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a $agency_only months_years6_bphd caltech  if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $agency_only $field months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_only $demo3 months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg postdoc_b4a  $field $agency_only $demo3 $yrs months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\definite_postdoc_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of PostDoc (Definite Plans) (Foreign Born)") ctitle("", PDOC/Tr) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	
********************************************************************************	
/* 	  INDIVIDUALS WITH DEFINITE PLANS WHO TAKE POSITIONS IN PRIVATE SECTOR    */
********************************************************************************	
	* EVER all
	
	reg private funded caltech, robust
	outreg using "${outreg}\private_ever", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever caltech, robust
	outreg using "${outreg}\private_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever months_years6_bphd caltech, robust
	outreg using "${outreg}\private_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever $field months_years6_bphd caltech, robust
	outreg using "${outreg}\private_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg  private $field $agency_ever $demo months_years6_bphd caltech, robust
	outreg using "${outreg}\private_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg  private $field $agency_ever $demo $yrs months_years6_bphd caltech, robust
	outreg using "${outreg}\private_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER female 
	
	reg private funded caltech  if female==1, robust
	outreg using "${outreg}\private_ever_female", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever caltech if female==1, robust
	outreg using "${outreg}\private_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\private_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever $field months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\private_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_ever $demo2 months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\private_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_ever $demo2 $yrs months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\private_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER male 
	
	reg private funded caltech  if female==0, robust
	outreg using "${outreg}\private_ever_male", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever caltech if female==0, robust
	outreg using "${outreg}\private_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\private_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever $field months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\private_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_ever $demo2 months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\private_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_ever $demo2 $yrs months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\private_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER US citizen 
	
	reg private funded caltech if uscitizen==1, robust
	outreg using "${outreg}\private_ever_uscitizen", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever caltech  if uscitizen==1, robust
	outreg using "${outreg}\private_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}\private_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever $field months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\private_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_ever $demo3 months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\private_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_ever $demo3 $yrs months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\private_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
		
	*EVER Foreign Born 
	
	reg private funded caltech if uscitizen==0, robust
	outreg using "${outreg}\private_ever_foreign", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever caltech if uscitizen==0, robust
	outreg using "${outreg}\private_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\private_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_ever $field months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\private_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_ever $demo3 months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\private_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_ever $demo3 $yrs months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\private_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	* ONLY all
	
	reg private funded caltech, robust
	outreg using "${outreg}\private_only", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only caltech, robust
	outreg using "${outreg}\private_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only months_years6_bphd caltech, robust
	outreg using "${outreg}\private_only", merge bdec(3) se starlevels(10 5 1) ////
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only $field months_years6_bphd caltech, robust
	outreg using "${outreg}\private_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg  private $field $agency_only $demo months_years6_bphd caltech, robust
	outreg using "${outreg}\private_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg  private $field $agency_only $demo $yrs months_years6_bphd caltech, robust
	outreg using "${outreg}\private_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*ONLY female 
	
	reg private funded caltech if female==1, robust
	outreg using "${outreg}\private_only_female", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only caltech if female==1, robust
	outreg using "${outreg}\private_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\private_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only $field months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\private_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_only $demo2 months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\private_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_only $demo2 $yrs months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\private_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (FEMALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*ONLY male 
	
	reg private funded caltech  if female==0, robust
	outreg using "${outreg}\private_only_male", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only caltech  if female==0, robust
	outreg using "${outreg}\private_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\private_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only $field months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\private_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_only $demo2 months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\private_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_only $demo2 $yrs months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\private_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (MALES)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*ONLY US citizen 
	
	reg private funded caltech if uscitizen==1, robust
	outreg using "${outreg}\private_only_uscitizen", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only caltech  if uscitizen==1, robust
	outreg using "${outreg}\private_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}\private_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only $field months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}\private_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_only $demo3 months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}\private_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_only $demo3 $yrs months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}\private_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (US Citizens)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
		
	*ONLY Foreign Born 
	
	reg private funded caltech  if uscitizen==0, robust
	outreg using "${outreg}\private_only_foreign", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only  caltech if uscitizen==0, robust
	outreg using "${outreg}\private_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\private_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscap ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $agency_only $field months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\private_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_only $demo3 months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\private_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg private $field $agency_only $demo3 $yrs months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\private_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of Private Sector Work (Definite Plans) (Foreign Born)") ctitle("", PrivateWk) landscape ///
    summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)


********************************************************************************
/* 			                PRIMARY WORK ACTIVITY - R&D                       */
********************************************************************************	

	* EVER all
	
	reg RD_primwk funded caltech, robust
	outreg using "${outreg}\r&d_ever", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever caltech, robust
	outreg using "${outreg}\r&d_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever months_years6_bphd caltech, robust
	outreg using "${outreg}\r&d_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever $field months_years6_bphd caltech, robust
	outreg using "${outreg}\r&d_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_ever $demo months_years6_bphd caltech, robust
	outreg using "${outreg}\r&d_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_ever $demo $yrs months_years6_bphd caltech, robust
	outreg using "${outreg}\r&d_ever", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)

	*EVER female 
	
	reg RD_primwk funded caltech if female==1, robust
	outreg using "${outreg}\r&d_ever_female", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever caltech  if female==1, robust
	outreg using "${outreg}\r&d_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\r&d_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever $field months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\r&d_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_ever $demo2 months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\r&d_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_ever $demo2 $yrs months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\r&d_ever_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER male 
	
	reg RD_primwk funded caltech if female==0, robust
	outreg using "${outreg}\r&d_ever_male", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever caltech if female==0, robust
	outreg using "${outreg}\r&d_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\r&d_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever $field months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\r&d_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_ever $demo2 months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\r&d_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_ever $demo2 $yrs months_years6_bphd caltech if female==0, robust
	outreg using "${outreg}\r&d_ever_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*EVER US citizen 
	
	reg RD_primwk funded caltech  if uscitizen==1, robust
	outreg using "${outreg}\r&d_ever_uscitizen", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever caltech  if uscitizen==1, robust
	outreg using "${outreg}\r&d_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}\r&d_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever $field months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}\r&d_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_ever $demo3 months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}r&d_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_ever $demo3 $yrs months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\r&d_ever_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
		
	*EVER Foreign Born 
	
	reg RD_primwk funded caltech  if uscitizen==0, robust
	outreg using "${outreg}\r&d_ever_foreign", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of R&D Work (Definite Plans) (Foreign Born)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever caltech if uscitizen==0, robust
	outreg using "${outreg}\r&d_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (Foreign Born)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\r&d_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (Foreign Born)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_ever $field months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\r&d_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (Foreign Born)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_ever $demo3 months_years6_bphd caltech if uscitizen==0, robust
	outreg using "${outreg}\r&d_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (Foreign Born)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_ever $demo3 $yrs months_years6_bphd caltech  if uscitizen==0, robust
	outreg using "${outreg}\r&d_ever_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work(Definite Plans) (Foreign Born)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	* ONLY all
	
	reg RD_primwk funded caltech , robust
	outreg using "${outreg}\r&d_only", replace bdec(3) se starlevels(10 5 1) ///
    note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only caltech , robust
	outreg using "${outreg}\r&d_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only months_years6_bphd caltech , robust
	outreg using "${outreg}\r&d_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only $field months_years6_bphd caltech , robust
	outreg using "${outreg}\r&d_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_only $demo months_years6_bphd caltech , robust
	outreg using "${outreg}\r&d_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_only $demo $yrs months_years6_bphd caltech , robust
	outreg using "${outreg}\r&d_only", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)

	*ONLY female 
	
	reg RD_primwk funded caltech  if female==1, robust
	outreg using "${outreg}\r&d_only_female", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only caltech if female==1, robust
	outreg using "${outreg}\r&d_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only months_years6_bphd caltech  if female==1, robust
	outreg using "${outreg}\r&d_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only $field months_years6_bphd caltech  if female==1, robust
	outreg using "${outreg}\r&d_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_only $demo2 months_years6_bphd caltech  if female==1, robust
	outreg using "${outreg}\r&d_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_only $demo2 $yrs months_years6_bphd caltech if female==1, robust
	outreg using "${outreg}\r&d_only_female", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (FEMALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*ONLY male 
	
	reg RD_primwk funded caltech  if female==0, robust
	outreg using "${outreg}\r&d_only_male", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only caltech  if female==0, robust
	outreg using "${outreg}\r&d_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only  months_years6_bphd caltech  if female==0, robust
	outreg using "${outreg}\r&d_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only $field months_years6_bphd caltech  if female==0, robust
	outreg using "${outreg}\r&d_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_only $demo2  months_years6_bphd caltech  if female==0, robust
	outreg using "${outreg}\r&d_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_only $demo2 $yrs months_years6_bphd caltech  if female==0, robust
	outreg using "${outreg}\r&d_only_male", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (MALES)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	*ONLY US citizen 
	
	reg RD_primwk funded caltech if uscitizen==1, robust
	outreg using "${outreg}\r&d_only_uscitizen", replace bdec(3) se starlevels(10 5 1) ///
	note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only caltech  if uscitizen==1, robust
	outreg using "${outreg}\r&d_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}\r&d_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only $field months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}\r&d_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_only $demo3 months_years6_bphd caltech if uscitizen==1, robust
	outreg using "${outreg}\r&d_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_only $demo3 $yrs months_years6_bphd caltech  if uscitizen==1, robust
	outreg using "${outreg}\r&d_only_uscitizen", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (US Citizens)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
		
	*ONLY Foreign Born 
	
	reg RD_primwk funded caltech  if uscitizen==0, robust
	outreg using "${outreg}\r&d_only_foreign", replace bdec(3) se starlevels(10 5 1) ///
    note("OLS models with marginal effects. Robust standard errors in parentheses.") ///
	title("Correlates of R&D Work (Definite Plans) (Foreign Born)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only caltech  if uscitizen==0, robust
	outreg using "${outreg}\r&d_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (Foreign Born)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only months_years6_bphd caltech  if uscitizen==0, robust
	outreg using "${outreg}\r&d_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (Foreign Born)") ctitle("", R&D) landscap ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $agency_only $field months_years6_bphd caltech  if uscitizen==0, robust
	outreg using "${outreg}\r&d_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans)(Foreign Born)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_only $demo3  months_years6_bphd caltech  if uscitizen==0, robust
	outreg using "${outreg}\r&d_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (Foreign Born)") ctitle("", R&D) landscape ///
	summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
	
	reg RD_primwk $field $agency_only $demo3 $yrs months_years6_bphd caltech  if uscitizen==0, robust
	outreg using "${outreg}\r&d_only_foreign", merge bdec(3) se starlevels(10 5 1) ///
	title("Correlates of R&D Work (Definite Plans) (Foreign Born)") ctitle("", R&D) landscape ///
    summstat(N \ r2_a)  summtitle(N \ Adjusted R-squared) summdec(0 2)
