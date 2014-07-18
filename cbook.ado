*! version 1.2.1 Joe Long 04mar2014
*Adapted from the do-file written by Richard McDowell and modified by Jeff Guo, JPAL. 
cap pr drop cbook
pr cbook
	vers 10
	syntax [varlist] [using/] [, to(string asis) fname(string asis)]
	qui{
		preserve
		if "`varlist'" != ""{
			keep `varlist'
		}
		if `"`using'"' != `""'{
			use `"`using'"', clear
		}
		qui d
		if `r(N)' < 17{
			set obs 17
		}
		ds _all
		loc allvars `r(varlist)'
		di "`allvars'"
		
		loc newvars 
		foreach var of varlist `allvars' {
			tempvar `var' 
			local name: var lab `var'
			if regexm("`name'", "________") {
				drop `var'
			}
			if regexm("`name'", "=====") {
				drop `var'
			}		
			
			* Row 1: Variable Name.
			gen ``var'' = "`var'" if _n == 1
			
			* Row 2: Variable label
			loc lbl: var la `var'
			replace ``var'' = "`lbl'" if _n == 2
			
			* Row 6: Type
			loc type: type `var'
			di "`type'"
			replace ``var'' = "`type'" if _n == 6
			
			* Row 7: Total number of valid, nonmissing obs.
			qui desc `var'
			loc totalN = `r(N)'
			qui tab `var' if mi(`var'), m
			loc nonmiss = `totalN' - `r(N)'
			replace ``var'' = string(`nonmiss') if _n == 7

			* Row 13: Imputed? No by default [] JJL: Maybe should change this to be just blank, to avoid confusion. 
			replace ``var'' = "no" if _n==13

			*Rows 10-11, 15-17: Summary stats
			qui cap su `var', d
			if _rc == 0{
				replace ``var'' = string(r(min)) 	if _n==10 
				replace ``var'' = string(r(max)) 	if _n==11 
				replace ``var'' = string(r(mean)) if _n==15
				replace ``var'' = string(r(p50)) 	if _n==16 
				replace ``var'' = string(r(sd))	if _n==17 
			}

			* Row 12: Value labels
			if "`:val la `var''" != ""{
				tempfile vallabel
				if `c(stata_version)' < 11 {  
					saveold `vallabel', replace
				}
				else {
					save `vallabel', replace
				}
				uselabel `:val la `var'', clear var
				loc vallab
				forv i = 1/`=_N' {
					//loc vallab `vallab' `=value[`i']' `=label[`i']'`=char(10)'
					loc value = value[`i']
					loc label = label[`i']
					loc labelq "`"`label'"'"
					loc labelq : list clean labelq
					if `i' != _N {
						loc vallab `vallab' `value' = `labelq',
					}
					else {
						loc vallab `vallab' `value' = `labelq'
					}
				}
				use `vallabel', clear
				replace ``var'' = `"`vallab'"' if _n == 12
			}
			loc newvars `newvars' ``var''
		}

		*Prepare the first column for the codebook, which gives the category names.
		#d ;
			loc fcol 
				"Variable Name" 
				"Variable Label" 
				"Question Information" 
				"Ques. ID" 
				"Ques. Text" 
				"Format Type" 
				"Total Responses" 
				"Table"
				"Survey"	
				"Min" 
				"Max" 
				"Codes" 
				"Imputed?" 
				"Key" 
				"Mean" 
				"Median"
				"Stdev." 
			;
		#d cr;
		
		loc n = 0
		foreach col in "`fcol'"{
			loc ++n
			if `n' == 1{
				gen fcol = "`col'" if _n == `n'
			}
			else {
				replace fcol = "`col'" if _n == `n' 
			}
		}
		
		keep fcol `newvars'
		order fcol

		qui ds
		loc stub `r(varlist)'
		loc n = 0
		foreach var of varlist _all {
			loc ++n
			rename `var' stub`n'
		}
		gen i = _n
		drop if _n > 17
		reshape long stub, i(i) j(j)
		reshape wide stub, i(j) j(i)
		drop j
		
		mata: st_local("fn", pathbasename(st_local("using")))
		mata: st_local("excel", pathrmsuffix(st_local("fn")) + "_codebook")
		loc direc = subinstr("`using'", "`fn'", "", .)
	}
	
	if "`to'" != ""{
		loc to = subinstr("`to'", `"""', "", .)
		if inlist("`=substr(`"`to'"', -1, 1)'", "/", "\") {
			loc to `=substr(`"`to'"', 1, length(`"`to'"')-1)'
		}
	}
	else {
		if "`direc'" != ""{
			loc to "`direc'"
			loc to = subinstr("`to'", `"""', "", .)
			if inlist("`=substr(`"`to'"', -1, 1)'", "/", "\") {
				loc to `=substr(`"`to'"', 1, length(`"`to'"')-1)'
			}
		}
		else {
			loc to `c(pwd)'
		}
	}
	if `"`fname'"' != ""{
		loc fname = subinstr(`fname', `"""', "", .)
		loc fname = subinstr("`fname'", ".dta", "", .)
		loc filename `fname'.xls
	}
	else {
		loc filename `excel'.xls
	}
	outsheet using `"`to'/`filename'"', replace non 
	di "file `filename' saved"
	restore
end
