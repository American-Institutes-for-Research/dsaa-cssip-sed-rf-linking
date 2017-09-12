clear
set more off

global data "X:\Rosa\data cj\"
global outreg "X:\Rosa\outreg\sed_funding_v3_2year_nostagger_wc 7-1-2016"

*******************************************************************************/*
*  SED Occupation Paper
 
* Created by: Rosa Castro Zarzur, rcastrozarzur@air.org ; February 3, 2016
 
* Modified by: Christina Jones, cjones@air.org & Wei Cheng; May-June 2016

*******************************************************************************/


********************************************************************************
/*           Funding Duration and Gaps - DATA PREPARATION                     */
********************************************************************************

clear
local db "DRIVER={MySQL ODBC 5.1 Driver};SERVER=172.30.66.22;DATABASE=weicheng;UID=wcheng;PWD=aA73176!NEYHDC2JxEp3"
local sql2 "SELECT * FROM sed_occ_link16_v3"
odbc load, exec("`sql2'") conn("`db'") clear

*keep if university=="Caltech" | university=="Umich" 
drop if university == "UChicago"|university == "UIndiana"|university == "UIowa"

drop if PHDFY<2011
/*
. tab university min_date

           |                                        min_date
university | 01oct1999  01jul2001  01jan2005  01jul2007  01jan2008  01jul2008  01jan2010  01jul2010 |     Total
-----------+----------------------------------------------------------------------------------------+----------
   Caltech |         1          0          0          0          0          0          0          0 |         1 
       OSU |         0          0          1          0          0          0          0          0 |         1 
       PSU |         0          0          0          1          0          0          0          0 |         1 
    Purdue |         0          0          0          0          1          0          0          0 |         1 
  UIndiana |         0          0          0          0          0          0          0          1 |         1 
     UIowa |         0          0          0          0          0          0          1          0 |         1 
       UMN |         0          0          0          0          0          1          0          0 |         1 
UWisconsin |         0          0          0          0          1          0          0          0 |         1 
     Umich |         0          1          0          0          0          0          0          0 |         1 
-----------+----------------------------------------------------------------------------------------+----------
     Total |         1          1          1          1          2          1          1          1 |         9 
*/
/*
drop if PHDCY < 2003 & university == "Caltech"
drop if PHDCY < 2004 & university == "Umich"
drop if PHDCY < 2008 & university == "OSU"
drop if PHDCY < 2010 & university == "PSU"
drop if PHDCY < 2011 & university == "Purdue"
drop if PHDCY < 2011 & university == "UWisconsin"
drop if PHDCY < 2011 & university == "UMN"
*/
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

*Edit these when you change school - not necessarily the same
rename (ind24 ind20 ind16 ind5)  (NIH_ind  DOE_ind  NSF_ind DOD_ind)

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

foreach x in 1 2 3 4 6 7 8 9 10 11 12 13 14 15 17 18 19 21 22 23 25 26 27 28{
sort employeeid university periodstart periodend aux
gen a`x'_payperiod=1 if ind`x'==1
bysort employeeid university periodstart periodend: replace a`x'_payperiod= a`x'_payperiod[_n-1] if  a`x'_payperiod==.
gsort employeeid university periodstart periodend -aux
bysort employeeid university periodstart periodend: replace a`x'_payperiod= a`x'_payperiod[_n-1] if  a`x'_payperiod==.

replace a`x'_payperiod=0 if a`x'_payperiod==.
}
/**/

** Number of awards worked on 2 years prior to PhD graduation

bysort employeeid university uniqueawardnumber rac: gen employeeid_uan_rac=_n
replace employeeid_uan_rac=. if  employeeid_uan_rac!=1

bysort employeeid university uniqueawardnumber rac: egen max_periodstart=max(periodstart)
bysort employeeid university uniqueawardnumber rac: egen min_periodstart=min(periodstart)

bysort employeeid university uniqueawardnumber rac: gen max_year=year(max_periodstart)
bysort employeeid university uniqueawardnumber rac: gen min_year=year(min_periodstart)
bysort employeeid university uniqueawardnumber rac: gen max_month=month(max_periodstart)
bysort employeeid university uniqueawardnumber rac: gen min_month=month(min_periodstart)

*replace employeeid_uan_rac=0 if max_year<PHDENTRY
replace employeeid_uan_rac=0 if PHDCY<min_year
replace employeeid_uan_rac=0 if PHDCY==min_year & PHDMONTH<min_month
replace employeeid_uan_rac=0 if PHDCY-2>max_year
replace employeeid_uan_rac=0 if PHDCY-2==max_year & PHDMONTH>=max_month

bysort employeeid university: egen awards=total(employeeid_uan_rac)
*replace awards=. if PHDENTRY==.

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
*replace min_gap1=. if PHDENTRY==.

** years to complete PhD

gen yrs_complete_phd= PHDCY-PHDENTRY

** keep one observation per individual per transaction period

bysort employeeid university periodstart periodend: gen drop=_n
drop if drop!=1

bysort employeeid university: gen n1=_n
replace n1=. if n1!=1

** payperiods (months) worked before PhD graduation: various time periods 

** Important note: we can do this because pay periods for Caltech and UMich are of 1 month!  

*br employeeid transaction_period phd_date

gen months_yrs2_bphd = 1
*replace months_yrs2=0 if year<PHDENTRY 
replace months_yrs2=0 if PHDCY< year
replace months_yrs2=0 if PHDCY==year & PHDMONTH<month
replace months_yrs2=0 if PHDCY-2>year
replace months_yrs2=0 if PHDCY-2==year & PHDMONTH>=month

bysort employeeid university: egen months_years2_bphd=total(months_yrs2)
*replace months_years2_bphd=. if PHDENTRY==.

tab months_years2_bphd if n1==1

drop months_yrs2

/**/


** ever funded by federal agencies in the period of 2 years before their PhD graduation
*	2 years = median time to graduate from PhD 

foreach x in NIH NSF DOD DOE federal{
gen funded_`x'=1 if `x'_payperiod==1
*replace funded_`x'=0 if year<PHDENTRY
replace funded_`x'=0 if PHDCY< year
replace funded_`x'=0 if PHDCY==year & PHDMONTH<month
replace funded_`x'=0 if PHDCY-2>year
replace funded_`x'=0 if PHDCY-2==year & PHDMONTH>=month
replace funded_`x'=0 if funded_`x'==.

bysort employeeid university: egen ever2_`x'=max(funded_`x')
*replace ever2_`x'=. if PHDENTRY==.
}
/**/

foreach x in 1 2 3 4 6 7 8 9 10 11 12 13 14 15 17 18 19 21 22 23 25 26 27 28{
gen funded_`x'=1 if a`x'_payperiod==1
*replace funded_`x'=0 if year<PHDENTRY
replace funded_`x'=0 if PHDCY< year
replace funded_`x'=0 if PHDCY==year & PHDMONTH<month
replace funded_`x'=0 if PHDCY-2>year
replace funded_`x'=0 if PHDCY-2==year & PHDMONTH>=month
replace funded_`x'=0 if funded_`x'==.

bysort employeeid university: egen ever2_`x'=max(funded_`x')
*replace ever2_`x'=. if PHDENTRY==.
}
/**/

** only funded by a federal agency in the period of 2 years before their PhD graduation
order ever2_*, after(min_gap1)

local ever "ever2_NIH ever2_NSF ever2_DOD ever2_DOE ever2_1 ever2_2 ever2_3 ever2_4 ever2_6 ever2_7 ever2_8 ever2_9 ever2_10 ever2_11 ever2_12 ever2_13 ever2_14 ever2_15 ever2_17 ever2_18 ever2_19 ever2_21 ever2_22 ever2_23 ever2_25 ever2_26 ever2_26 ever2_27 ever2_28"

egen total_sources = rowtotal(`ever')
*replace total_sources=. if PHDENTRY==.

* the variable below is created for the purpose of generating frequencies of individuals that were funded by exactly 2 and 3 more agencies. 

local ever_other "ever2_1 ever2_2 ever2_3 ever2_4 ever2_6 ever2_7 ever2_8 ever2_9 ever2_10 ever2_11 ever2_12 ever2_13 ever2_14 ever2_15 ever2_17 ever2_18 ever2_19 ever2_21 ever2_22 ever2_23 ever2_25 ever2_26 ever2_26 ever2_27 ever2_28"

egen ever_other_sources = rowtotal(`ever_other')

gen ever_other = 1 if ever_other_sources > 0 & ever_other_sources!=.
replace ever_other = 0 if ever_other_sources ==0
replace ever_other = 0 if ever2_federal==0
*replace ever_other =. if PHDENTRY==.

* the variable below, ever6_federal_other is created for regressions purposes. It equal 1 when the individual was funded by a federal agency that is different to NSF, NIH, DOD, DOE and NOTTTTT funded by  NSF, NIH, DOD, DOE.

gen ever2_federal_other = 1 if ever2_federal==1
replace ever2_federal_other=0 if ever2_NSF==1 | ever2_NIH==1 | ever2_DOD==1 | ever2_DOE==1
replace ever2_federal_other=0 if ever2_federal==0
*replace ever2_federal_other=. if PHDENTRY==.

gen only2_NIH=1 if ever2_NIH==1 & total_sources==1
replace only2_NIH=0 if only2_NIH==.
*replace only2_NIH=. if PHDENTRY==.

gen only2_NSF=1 if ever2_NSF==1 & total_sources==1
replace only2_NSF=0 if only2_NSF==.
*replace only2_NSF=. if PHDENTRY==.

gen only2_DOE=1 if ever2_DOE==1 & total_sources==1
replace only2_DOE=0 if only2_DOE==.
*replace only2_DOE=. if PHDENTRY==.

gen only2_DOD=1 if ever2_DOD==1 & total_sources==1
replace only2_DOD=0 if only2_DOD==.
*replace only2_DOD=. if PHDENTRY==.

gen only2_federal_other=1 if total_sources==1 & only2_DOD==0 & only2_DOE==0 & only2_NSF==0 & only2_NIH==0
replace only2_federal_other=0 if only2_federal_other==.
*replace only2_federal_other=. if PHDENTRY==.

gen multiple_sources=1 if total_sources>1 & total_sources!=.
replace multiple_sources=0 if total_sources==1
*replace multiple_sources=. if PHDENTRY==.
replace multiple_sources=0 if ever2_federal==0

gen funded=1 if ever2_federal==1
replace funded=0 if ever2_federal==0

keep employeeid university months_years2_bphd min_gap1 yrs_complete_phd funded ever2_NIH ever2_NSF ever2_DOD ever2_DOE ever_other ever_other_sources ///
     __employee_id awards BIRTHPL TUITREMS PHDENTRY PHDCY PHDMONTH only2_NIH only2_NSF only2_DOE only2_DOD only2_federal_other total_sources multiple_sources 

ren ever_other ever2_federal_other
	 
duplicates drop

unique employeeid university

save "${data}\umetrics_sed_matched_processed.dta", replace

********************************************************************************
          /* now let's bring in the not-matched individuals */
********************************************************************************

preserve
clear
local db "DRIVER={MySQL ODBC 5.1 Driver};SERVER=172.30.66.22;DATABASE=weicheng;UID=wcheng;PWD=aA73176!NEYHDC2JxEp3"
local sql2 "SELECT * FROM sed_occ_match_notmatch_v2"
odbc load, exec("`sql2'") conn("`db'") clear

replace __employee_id = . if __link_type != 16
replace __link_type = . if __link_type != 16
gsort ID -__link_type_id
by ID: replace __link_type = __link_type[_n-1] if __link_type == .
by ID: replace __employee_id = __employee_id[_n-1] if __employee_id == .
duplicates drop

tostring __employee_id, replace
save "${data}\sed_occ_match_notmatch_v2", replace
restore

merge 1:m __employee_id using "${data}\sed_occ_match_notmatch_v2"

**have to limit the non-matched to the cohort years as well (CJ)

drop if PHDINST == "144050" /*uchicago*/
keep if inlist(PHDINST,"110404","170976","204796","214777","243780","240444","174066")

drop if PHDFY<2011
/*
drop if PHDCY < 2003 & PHDINST == "110404" /*caltech*/
drop if PHDCY < 2004 & PHDINST == "170976" /*umich*/
drop if PHDCY < 2008 & PHDINST == "204796" /*osu*/
drop if PHDCY < 2010 & PHDINST == "214777" /*psu*/
drop if PHDCY < 2011 & PHDINST == "243780" /*purdue*/
drop if PHDCY < 2011 & PHDINST == "240444" /*wisconins*/
drop if PHDCY < 2011 & PHDINST == "174066" /*umn*/
*/
replace university = "Caltech" if PHDINST == "110404"
replace university = "Umich" if PHDINST == "170976"
replace university = "OSU" if PHDINST == "204796"
replace university = "PSU" if PHDINST == "214777"
replace university = "Purdue" if PHDINST == "243780"
replace university = "UWisconsin" if PHDINST == "240444"
replace university = "UMN" if PHDINST == "174066"

gen match=1 if _merge==3
replace match=0 if _merge==2

gen notmatch=1 if match==0
replace notmatch=0 if match==1 

foreach var of varlist funded ever2_* only2_* awards months_years2_bphd total_sources multiple_sources{
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

//gen postdoc_b4a=1 if PDOCPLAN>=0 & PDOCPLAN<=5 & PDOCPLAN!=. 
//replace postdoc_b4a=0 if PDOCPLAN>5 & PDOCPLAN<=9 & PDOCPLAN!=. 
//replace postdoc_b4a=. if PDOCPLAN==99 
gen postdoc_b4a=1 if PDOCPLAN>=0 & PDOCPLAN<=1 & PDOCPLAN!=.
replace postdoc_b4a=0 if postdoc_b4a==.&PDOCPLAN!=99 & PDOCPLAN!=.

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

//gen RD_primwk=1 if PDWKPRIM==0
//replace RD_primw=0 if RD_primw==. & PDWKPRIM!=. & PDWKPRIM!=99
//replace RD_primw=. if PDWKPRIM==. & PDWKPRIM==99

gen RD_primwk=1 if PDWK1ED==0
replace RD_primwk=0 if RD_primwk==. & PDWK1ED!=. & PDWK1ED!=99

*year dummies
tab PHDFY, gen(y)
rename (y1 y2) (y2011 y2012)

* phd field dummies
/*
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
*/


* us citizen
gen uscitizen=1 if BIRTHPL>0 & BIRTHPL<=99 & BIRTHPL!=.
replace uscitizen=0 if BIRTHPL>99 & BIRTHPL<=555 & BIRTHPL!=.

*tuition remision

gen tui_rem=1 if TUITREMS==4
replace tui_rem=0 if tui_rem==. & TUITREMS!=.

* bringing in team size
	
merge m:1 __employee_id using "${data}\teamsize_v4.dta"
drop if _merge == 2
drop _merge
replace av_teamsize=0 if av_teamsize==. & funded==0
 
label var  postdoc_b2 "PDOCPlans"
label var  postdoc_b4a "PDOC/Tr"
label var private "PrivateWk"
label var RD_ "R&D"
  
gen teamsize = av_teamsize
replace teamsize=10 if av_teamsize>=10

rename av_teamsize orig_teamsize
rename teamsize av_teamsize

* university dummies

tab university, gen(dum)
rename (dum1 dum2 dum3 dum4 dum5 dum6 dum7) (caltech osu psu purdue umn wi umich) 

save "$outreg\SED_UMETRICS_workingdata.dta", replace

clear
import delimited "${data}\PHDFIELD.csv"
ren phdfield PHDFIELD
duplicates drop
sort PHDFIELD
save phdfield,replace

use "$outreg\SED_UMETRICS_workingdata.dta",clear
sort PHDFIELD
merge m:1 PHDFIELD using phdfield
drop if _merge==2
tab sed_field, gen(field)
save,replace


