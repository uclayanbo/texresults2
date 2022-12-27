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
*Add backslash to macroname and issue warning if doesn't contain only alph.
local isalph = regexm("`texmacro'","^[a-zA-Z ]*$")
local texmacro = "\" + "`texmacro'"
if `isalph' == 0 di as text `""`texmacro'" may not be a valid LaTeX macro name"'

if !missing("`xspace'") local xspace = "\" + "`xspace'"

// display "opcion: `xspace'"


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
if (!missing("`unitzero'") & abs(`result') < 1) {
	if (`result' > 0) local result 0`result'
	else local result = "-0"+"`=abs(`result')'"
}

*Add the $ signs if math mode is on. Suppress the # signs if math mode is off.
if inlist("`mathmode'", "on", "ON", "On") local output "$`result'$"
else if inlist("`mathmode'", "off", "OFF", "Off") local output "`result'"


********************************************************************************
*Create or modify macros file.
tempfile tmptex

loc usingpath : word 2 of `using'
mac lis _usingpath
if "`action'"=="update"{
	copy `usingpath' `tmptex', public text replace
	loc length_todetect = strlen("\newcommand{`texmacro'}{") // to identify the line the macro is on
    file open texresultsfile `using', read text
    file read texresultsfile line
    while r(eof)==0 {
        if substr(`"`line'"',1,`length_todetect')=="\newcommand{`texmacro'}{" {
			loc linetoreplace `line'
			loc toreplace = substr("`linetoreplace'", 14, .) //extract the substring that starts with the macro (but not the part with backslashes)
        }
        file read texresultsfile line
        }
    file close texresultsfile
	loc outpt = substr("`texmacro'}{`output'`xspace'}", 2, .) //remove leading backslash
	filefilter `tmptex' `usingpath', from("`toreplace'") to(`outpt') replace	
}

else {
	file open texresultsfile `using', write `action'
	file write texresultsfile "\newcommand{`texmacro'}{`output'`xspace'}" _n
	file close texresultsfile
}

end


