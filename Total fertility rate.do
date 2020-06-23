***Setting up the repository, loading and formatting data***
global path "C:\Users\yoga-user\Desktop\licencjat\dane\"
cd $path 
import excel dane_bez_regionow.xlsx, firstrow
//import excel C:\Users\yoga-user\Desktop\licencjat\dane\dane_bez_regionow.xlsx, firstrow
des // description of variables
drop education
rename mortality inf_mortality

/// changing variables from string to numeric:
foreach var of varlist year-unemployment{
	destring `var', replace
	}
	
save helpfile, replace

clear
/// importing second dataset with data
import excel years_of_education.xlsx, firstrow 
/// merging two datasets together
merge 1:1 co year using helpfile 

/// formatting variables
drop _merge
destring school, replace
rename school education, replace
label variable co "Code of coutry"
label variable education "Years of education"
label variable fertility "Total fertility rate"
label variable gdp "GDP per capita based on purchasing power parity (PPP)"
label variable inf_mortality "Number of infants dying before 1st birthday, per 1,000 live births"
label variable gender "Female labor force as a percentage of the total labor force"
label variable unemployment "Share of the labor force that is without work"
label variable pollution "Population-weighted exposure to ambient PM2.5 pollution"
label variable country "Country"
label variable year "Year"
des

/// preparing data to panel analysis
encode co, g(co1)
xtset co1 year, yearly

***Presentind data on the graphs***
/// overall fertility data between 1960 and 2020
xtline fertility if year >=1960 & year <=2020, overlay legend(off) ///
		title("Total fertility rate") subtitle("for all analysed countries") ///
		xtitle("Year") ytitle("Total fertility rate") 
graph export graphs\fertility_rate_all_countries.png, as(png) replace

/// fertility data for chosen countries	
xtline fertility if year >=1960 & year <=2020 & (co == "POL" | ///
						co == "DEU" | co == "USA" ///
					| co == "MEX" | co == "BRA" | co == "HTI" ///
					| co == "CHN" | co == "IND" | co == "SAU" ///
					| co == "AUS" | co == "FJI" | co == "BFA" | co == "ZMB" ///
					| co == "EGY" ), overlay legend(col(4) size(small)) ///
					xtitle("Year") ytitle("Total fertility rate") ///
					title("Total fertility rate") ///
					subtitle("for chosen countries") 
graph export graphs\fertility_rate_few_countries.png, as(png) replace					

local variables gdp inf_mortality education gender unemployment pollution 					
foreach i of varlist `variables'{
		twoway (scatter fertility `i' if year ==1995) (lfit fertility `i' if year ==1995), ///
		xtitle("`i'") ytitle("") title(1995) saving(`i'1995)
		twoway (scatter fertility `i' if year ==2010) (lfit fertility `i' if year ==2010), ///
		xtitle("`i'") ytitle("") title(2010) saving(`i'2010) 
		graph combine `i'1995.gph `i'2010.gph, title("`: var label `i''")
		graph export graphs\fertility_`i'.png, as(png) replace	
}

***Building regression model***
global ind_variables "gdp inf_mortality education gender unemployment pollution" 	
global basic_model xtreg fertility $ind_variables
global model1 $basic_model ,fe
$model1
estimate store fe1
outreg2 using tables\table1.xls, replace seeo

predict yhat1
scatter yhat1 year if year > 1990
/* as we can see the intervals between available observations for all variables
are not equal, and we want it to be equal*/

global condition year == 1995 | year == 2000 | year == 2005  | year == 2010 | year == 2015

global model2 xtreg fertility $ind_variables if $condition, fe
$model2
estimate store fe2
outreg2 using tables\table2.xls, replace seeo

predict yhat2 
predict res2, residuals
scatter res2 year if $condition
graph export graphs\scatter_res_year.png, as(png) replace
// we see that there might be heteroscedasticity

$model2
xttest3
// Wald test for heroscedasticity confirm that there is a problem with heteroscedasticity

xtserial fertility $ind_variables
// there is also autocorrelation between variables

/* to deal with the problems above we are going to make another model that taking
into consideration heteroscedasticity and autocorrrelation using clustering option*/

global final_model $model2 cluster(co1)
$final_model
/* as while estimating the coefficients model taking into account our "problems",
we are not testing them again*/

$final_model
estimate store fe_final
outreg2 [fe1 fe2 fe_final] using tables\panel_comparison.xls, replace seeo

// we will see if indeed model with fixed effects is better choice than with random effect
global re_model $basic_model , re cluster(country)
$re_model
xtoverid
// Indeed model with fixed effects id better fit

***Building a regression model based on cross sectional data (the latest year data available)
global cs_model reg fertility $ind_variables if year == 2017
$cs_model
predict resid, residuals
predict yh

// checking assumptions
corr $variables

$cs_model
estat ovtest 

hist resid, normal
sktest resid

// graphical heteroscedasticity
foreach s of varlist $ind_variables {
	scatter resid `s', title("Residuals and `s'")
	graph export graphs\res_`s'.png, as(png) replace
}

$cs_model
estat hettest

global robust_cs_model $cs_model , robust
$robust_cs_model
estimate store cs_final

// comparing models based on different kinds of data
outreg2 [fe_final cs_final] using tables\panel-cs_comparison.xls, replace seeo

