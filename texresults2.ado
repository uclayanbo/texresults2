/*
This do-file defines "texresults2", a variant of "texresults" (Alvaro Carril) that
has an option to suppress the $ signs.
*/
program define texresults2
syntax [using], ///
	TEXmacro(string) ///
	[ ///
		replace Append Update ///
		Result(string) coef(varname) se(varname) tstat(varname) pvalue(varname) ///
		mathmode(string) /// Can be either "on" or "off".
		ROund(real 0.01) UNITzero XSpace ///
	]


********************************************************************************
*Initial checks and processing.

*Parse file action.
local action `replace' `append' `update'
local len_action : word count `action'
if `len_action'>1 {
	di as error "Specify only one of {bf:replace}, {bf:append}, and {bf:update}"
	exit 198
}

loc checkmacrostart= substr("`texmacro'",1,3)
if "`checkmacrostart'"=="end" di as text `"Macros may not start with "end""' //latex macros can't start with "end"
// TODO: check all the banned words

*Add backslash to macroname and issue warning if doesn't contain only alph.
local isalph = regexm("`texmacro'","^[a-zA-Z ]*$")
local texmacro = "\" + "`texmacro'"
if `isalph' == 0 di as text `""`texmacro'" may not be a valid LaTeX macro name"'

if !missing("`xspace'") local xspace = "\" + "`xspace'"

********************************************************************************
*Process and store [rounded] result.

// general result (scalar, local, etc.)
if !missing("`result'") {
	local result = round(`result', `round')
}
// coefficient
if !missing("`coef'") {
	local result = round(_b[`coef'], `round')
}
// standard error
if !missing("`se'") {
	local result = round(_se[`se'], `round')
}
// t-stat
if !missing("`tstat'") {
	local result = round(_b[`tstat']/_se[`tstat'], `round')
}
// p-value
if !missing("`pvalue'") {
	local result = round(2 * ttail(e(df_r), abs(_b[`pvalue']/_se[`pvalue'])), `round')
}

*Add unit zero if option is specified and result qualifies.
if !missing("`unitzero'") {
	di "Note: the unitzero option is automatically applied and may be deprecated in future versions."
}

*Make the result a formatted string to avoid precision issues with rounding floats.
if `round' <= 0.1{
	local roundto = round(-log10(`round'),1)
	if `roundto' == round(`roundto',1) {
		local result : display %9.`roundto'g `result'
	}
}

*Strip whitespace
loc result: subinstr loc result " " "", all

*Apply unitzero automatically 
* if it's positive...
if substr("`result'", 1, 1) == "."{
	loc result = "0" + "`result'" 
}
* ...and if it's negative
if substr("`result'", 1, 2) == "-."{
	loc resultsubstr = substr("`result'", 2, .)
	loc result = "-0" + "`resultsubstr'" 
}

*Add the $ signs if math mode is on. Suppress the # signs if math mode is off.
if inlist("`mathmode'", "on", "ON", "On") local output "$`result'$"
else if inlist("`mathmode'", "off", "OFF", "Off") local output "`result'"

********************************************************************************
*Create or modify macros file.

if "`action'"=="update"{
	loc usingpath : word 2 of `using'
	loc length_todetect = strlen("\newcommand{`texmacro'}{") // to identify the line the macro is on
	
	// if file doesn't exist, create it
	if !fileexists("`usingpath'") {
		di "Creating new file: `usingpath'"
		file open texresultsfile `using', write
		file close texresultsfile
	}
	file open texresultsfile `using', read text

	tempfile tmptex
	file open tmphandle using "`tmptex'", write text
    
	file read texresultsfile line
	while r(eof)==0 {
		if substr(`"`line'"',1,`length_todetect')=="\newcommand{`texmacro'}{" { //line contains the target macro
			loc linetoreplace `line'
			loc toreplace = substr("`linetoreplace'", 14, .) //extract the second half of the command (contains the macro but not the backslashes)
			if "`found'" == "" { //if we haven't yet found the target macro
				file write tmphandle "`line'" _n
			}
			loc found = "yes"
		}
		else {
			file write tmphandle "`line'" _n
		}
		file read texresultsfile line
	}
	file close texresultsfile
	file close tmphandle
	if "`linetoreplace'" != "" { //if the target macro was found
		loc outpt = substr("`texmacro'}{`output'`xspace'}", 2, .) //remove leading backslash
		
		// grab the permissions and group of `usingpath' so it's not overwritten
		shell stat -c '%a' "`usingpath'" > temp_permissions.txt
		file open fp using temp_permissions.txt, read text
		file read fp permissions
		file close fp
		shell stat -c '%G' "`usingpath'" > temp_groupname.txt
		file open fp using temp_groupname.txt, read text
		file read fp group
		file close fp

		filefilter `tmptex' "`usingpath'", from("`toreplace'") to(`outpt') replace
		shell chmod `permissions' "`usingpath'"
		shell chgrp `group' "`usingpath'"
		shell rm temp_permissions.txt temp_groupname.txt
	}
	else { //did not find the target macro -> append
		file open texresultsfile `using', write append
		file write texresultsfile "\newcommand{`texmacro'}{`output'`xspace'}" _n
		file close texresultsfile
	}
}
else if "`action'"=="replace"{
	loc usingpath : word 2 of `using'
	
	if fileexists("`usingpath'") loc fileexists "yes"
	else loc fileexists "no"
	
	if "`fileexists'"=="yes"{
		// instead of `file open ... replace`, keep the permissions if file exists
		// grab the permissions and group of `usingpath' so it's not overwritten
		shell stat -c '%a' "`usingpath'" > temp_permissions.txt
		file open fp using temp_permissions.txt, read text
		file read fp permissions
		file close fp
		shell stat -c '%G' "`usingpath'" > temp_groupname.txt
		file open fp using temp_groupname.txt, read text
		file read fp group
		file close fp
	}

	file open texresultsfile `using', write replace
	file write texresultsfile "\newcommand{`texmacro'}{`output'`xspace'}" _n
	file close texresultsfile
	
	if "`fileexists'"=="yes"{
		shell chmod `permissions' "`usingpath'"
		shell chgrp `group' "`usingpath'"
		shell rm temp_permissions.txt temp_groupname.txt
	}
}
else if "`action'"=="append"{
	file open texresultsfile `using', write append
	file write texresultsfile "\newcommand{`texmacro'}{`output'`xspace'}" _n
	file close texresultsfile
}

end


