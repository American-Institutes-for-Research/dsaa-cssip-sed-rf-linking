clear
set more off

global data "X:\Rosa\data cj"
global outreg_fa "X:\Rosa\outreg\for_Ahmad cj"

*******************************************************************************/*
  SED Occupation Paper
  
  Creating data set for Ahmad who is going to help me create team size variables
 
 Created by: Rosa Castro Zarzur, rcastrozarzur@air.org ; December 20, 2015

********************************************************************************/

clear
local db "DRIVER={MySQL ODBC 5.1 Driver};SERVER=[server name];DATABASE=[database table];UID=[username];PWD=[password]"
local sql2 "SELECT * FROM sed_occ_link16_all_v4"
odbc load, exec("`sql2'") conn("`db'") clear

rename (var1 var2 x_employee_id x_unique_award_number x_cfda recipient_account_number occupationalclassification) (start_year start_month employeeid uniqueawardnumber cfda rac occ1)

* Let's check that we have all the sed matched individuals here

merge m:1 employeeid university using "${data}\umetrics_sed_matched_processed.dta", keepus(employeeid university PHDCY PHDENTRY PHDMONTH funded)
gen umetrics_sed=1 if _merge==3
replace umetrics_sed=0 if _merge!=3
drop _merge


/* just keeping the people and awards we need! */
bysort uniqueawardnumber rac: egen award_with_funded_indiv=max(funded)
replace award_with_funded_indiv=0 if award_with_funded_indiv==.
drop if award_with_funded_indiv==0
drop award_with_funded_indiv
keep if funded==1

keep __employee_id employeeid uniqueawardnumber rac university PHDCY PHDMONTH PHDENTRY funded
duplicates drop

order __employee_id employeeid university uniqueawardnumber rac PHDENTRY PHDMONTH PHDCY funded

rename PHDCY end_year
rename PHDMONTH end_month

gen start_year=end_year-2
gen start_month=end_month

gen mark=1 if PHDENTRY>start_year

replace start_year=PHDENTRY if mark==1
replace start_month=1 if mark==1
drop mark funded PHDENTRY

export delimited using "X:\Rosa\outreg\for_Ahmad cj\for_Ahmad_v4.csv", replace
clear
