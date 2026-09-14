#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

#pragma version = 1	 // Last Modified: 2026/09/12 by Jamie Boyd

//******************************************************************************************************
//Grepish = Limited support of GREP-like features for use on Igor 5. Igor 6 has grep built in
//******************************************************************************************************

//	 special characters: 
// outside brackets
// 	^	Match start of string - must be first character in regEx
//	\	treat following character as not special
// 	(	opens a subpattern
// 	)	closes a subpattern -  quantifiers are  supported for subpatterns, but can be confusing when splitting a string
//	[	Start character class definition (for matching one of a set of characters)
//	]	End character class definition
//	.	match any character
//	?	0 or 1 quantifier (for matching 0 or 1 occurrence of a pattern)
//	*	0 or more quantifier (for matching 0 or more occurrence of a pattern)
//	+	1 or more quantifier (for matching 1 or more occurrence of a pattern)
//	{	start of quantifier {1,}, {1,3},{,2} 
//	}	end of quantifier -  comma is used to separate min and max
//	$	Match end of string  - must be last character in RegEx

//  inside brackets
//	 \	 General escape character; only thing to escape is -
//	 ^ 	Negate the class, but only if ^ is the first character
//	- 	Indicates character range


//******************************************************************************************************
// Last Modified 2014/07/10 by Jamie Boyd
// returns 1 if input string matches the regular expression, 0 if it does not, -1 if a parsing error occurred
function GUIPGrepishStr (inputStr, regExp)

	string inputStr
	string regExp
	
	return GUIPGrepish (inputStr, regExp)
end

//******************************************************************************************************
// splits a string into subpatterns indicated by (). puts sub-strings into a text wave, sWave. Make sure text wave is big enough.
// Last Modified 2014/07/10 by Jamie Boyd
Function GUIPSplitStringW (inputStr, regExp, sWave)
	string inputStr
	string regExp
	WAVE/T sWave
	
	return  GUIPGrepish (inputStr, regExp, sWave=sWave)
end

//******************************************************************************************************
// splits a string into subpatterns indicated by (). returns sub-strings as a separarated list.
// Last Modified 2014/07/10 by Jamie Boyd
Function/S GUIPSplitStringS (inputStr, regExp, [sepChar])
	string inputStr
	string	regExp
	string sepChar
	
	if(paramisDefault (sepChar))
		sepChar=";"
	endif
	
	string sString
	variable/G V_Flag=GUIPGrepish (inputStr, regExp, sString=sString, sepChar=sepChar)
	return sString
end

//******************************************************************************************************
// GUIPGrepish greps a string, possibly grabbing subpatterns and puting them into a text wave or a string list
// if you want subpatterns in a text wave, you need to make it and pass it to GUIPGrep and make sure it is big enough for all subpatterns
// if you want subpatterns in a string list, they are put in sString, passed by reference and separated by sepChar, which defualts to ";"
// returns 1 if input string matches regular expression, 0 if it does not match, -1 if formatting error in regular expression
// Last Modified 2014/07/10 by Jamie Boyd
Function GUIPGrepish (inputStr, regExp, [sWave, sString, sepChar])
	string inputStr
	string  regExp
	wave/t sWave
	string &sString
	string sepChar
	
	// Check default params and set a flag for them
	// 0 for not saving subpatterns, 1 for putting them in a wave, and 2 for putting them in a string list
	variable saveSubs=0 
	if (!(ParamIsDefault (sWave)))
		saveSubs +=1
		sWAve = ""
	endif
	if (!(ParamIsDefault (sString)))
		sString = ""
		saveSubs +=2
		if (ParamIsDefault (sepChar))
			sepChar = ";"
		endif
	endif
	
	variable ii=0, ni = strlen (inputStr), ir, nr = strlen (regExp)
	string rChar, iChar
	variable escaped
	variable invert
	variable doSkip, skipping, lastSkipStart, matchLast=0
	variable subPatternStart, iSWave =0,inSubPattern =0
	variable subPatternStartR, subPatternEndR, iSubPattern=0, subPatternMin, subPatternMax
	string charClass
	variable isCharClass
	variable minMatch, maxMatch,iMatch
	
	// first char of regExp can be ^ to match start of string, or ( to open a subpattern,or stuff to match but not subpattern
	if (cmpStr (regExp[0], "^") ==0)
		doSkip =0
		ir = 1
	else
		doSkip=1
		lastSkipStart = 0
		ir=0
	endif
	skipping = doSkip
	// last char of regExp can be $ to match end of string
	if ((CmpStr (regExp[nr-1], "$") ==0) && (cmpStr (regExp[nr-2], "\\") != 0))
		nr -= 1
		matchLast =1
	endif
	// loop through each char or charClass in regex, and try to match it to inputStr
	for (;ir < nr;ir +=1)
		rChar = regExp [ir]
		// deal with special cases
		if (cmpStr (rChar, "\\") ==0)// next character is  escaped.
			escaped =1
			ir +=1
			rChar = regExp [ir]
		else
			escaped =0
		endif
		if ((!(escaped)) &&((cmpStr(rChar,  "(")==0)  && (!(inSubPattern))))// start of a subPattern.  Save inputString position
			subPatternStart = ii
			inSubPattern=1
			if (iSubPattern == 0) // first time through this subpattern
				subPatternStartR = ir
				subPatternEndR = iR
				do
					subPatternEndR=strsearch(regExp, ")", subPatternEndR +1 , 0)
				while (CmpStr (regExp [subPatternEndR-1], "\\") == 0)
				GUIPgrepSetMinMax (regExp, subPatternEndR, subPatternMin, subPatternMax)
			endif
			continue
		elseif ((!(Escaped)) && ((cmpStr(rChar,  ")")==0) && (inSubPattern))) //end of a subpattern
			if (saveSubs & 1)
				sWave [iSWave] = inputStr [subPatternStart, ii-1]
				iSwave +=1
			endif
			if (saveSubs & 2)
				sString +=  inputStr [subPatternStart, ii-1] + sepChar
			endif
			iSubPattern +=1
			if (iSubPattern == subPatternMax)
				ir = subPatternEndR
				iSubPattern = 0
			else
				ir = subPatternStartR
			endif
			inSubPattern =0
			continue
		elseif ((!(Escaped)) && (cmpStr (rChar,".")==0)) // . matches 1 character, any character,  in the input string
			GUIPgrepSetMinMax (regExp, ir, minMatch, maxMatch)
			if (skipping)
				lastSkipStart = ii
				skipping =0
			endif
			ii += maxMatch
			continue
		elseif ((!(Escaped)) && (cmpStr(rChar,  "[")==0)) // start of a character class
			charClass =GUIPgrepGetCharacterClass (regExp, ir, invert)
			isCharClass = 1
		else // a normal character.
			isCharClass = 0
		endif
		// check for number matching, for classes or for single characters
		GUIPgrepSetMinMax (regExp, ir, minMatch, maxMatch)
		// try to match with a character in input str
		if (skipping) // skip through input string til we first find rChar, or first find character in charClass
			if (isCharClass)
				if (invert)
					for (; ((ii < ni) && (strsearch(charClass, inPutStr [ii], 0) != -1)); ii+=1)
					endfor
				else
					for (; ((ii < ni) && (strsearch(charClass, inPutStr [ii], 0) == -1)); ii+=1)
					endfor
				endif
			else
				for (; ((ii < ni) && (CmpStr (rChar, inPutStr [ii]) != 0)); ii+=1)
				endfor
			endif	
			if (ii == ni)
				return 0
			endif
			if (inSubPattern)
				subPatternStart = ii
			endif
			lastSkipStart = ii
			skipping = 0
		endif
		// match character or class
		if (isCharClass)
			if (invert)
				for (iMatch=0;iMatch < maxMatch; iMatch +=1)
					if (strsearch(charClass, inPutStr [ii], 0) == -1)
						ii +=1
					else
						break
					endif
				endfor
			else
				for (iMatch=0; imatch < maxMatch; iMatch +=1)
					if  (strsearch(charClass, inPutStr [ii], 0) != -1)
						ii += 1
					else
						break
					endif
				endfor
			endif
		else // one character
			for (iMatch=0; imatch < maxMatch; iMatch +=1)
				if (CmpStr (rChar, inPutStr [ii]) ==0)
					ii += 1
				else
					break
				endif
			endfor
		endif
		if (imatch < minMatch)
			// if we are in a subpattern with a min and a max, maybe we should not have been so greedy?
			if ((inSubPattern) && (iSubPattern >= subPatternMin))
				ir = subPatternEndR
				ii = subPatternStart
				inSubPattern = 0
			elseif (doSkip)
				skipping =1
				ir = -1
				ii = lastSkipStart +1
				inSubPattern=0
				iSwave = 0
			else
				return 0
			endif
		endif
	endfor
	// if matching last part of input string, we need to be at the end of the input string
	if ((matchLast) && (ii < ni))
		return 0
	else
		return 1
	endif
	// if matching last part of input string, we need to be at the end of the input string
	if ((matchLast) && (ii < ni))
		return 0
	else
		return 1
	endif
end

//******************************************************************************************************
// Gets quantifiers for character repitions(minMatch and maxMatch)
// moves ir to end of quantifier
// returns 0 if min, max set, else 1 for formatting error
// Last Modified 2014/07/07 by Jamie Boyd
Static Function GUIPGrepSetMinMax(regExp, ir, minMatch, maxMatch)

	string &regExp
	variable &ir
	variable &minMatch
	variable &maxMatch
	
	// look for escape character
	if (cmpStr ( regExp [ir+1], "\\")==0)
		minMatch = 1
		maxMatch =1
		return 0
		// look for number modifiers
	elseif (cmpStr ( regExp [ir+1], "?")==0) // 0 or 1
		minMatch=0
		maxMatch =1
		ir +=1
		return 0
	elseif (cmpStr ( regExp [ir+1], "*")==0) //0 or more
		minMatch=0
		maxMatch =inf
		ir +=1
		return 0
	elseif (cmpStr (regExp [ir + 1], "+")==0) // 1 or more
		minMatch=1
		maxMatch =inf
		ir +=1
		return 0
		// look for defined range
	elseif (Cmpstr (regExp [ir + 1], "{")==0) // defined range {3} {,3} {3,} {1,3} are all valid
		variable endPos= strsearch(regExp, "}", ir)
		if (endPos > -1) //  found 
			string minMaxStr = regExp [ir +2, endPos -1]
			ir = endPos
			variable nMinMax = itemsinlist (minMaxStr, ",") // 1 or 2 are acceptable
			if (nMinMax ==1) // min set, but max not set
				minMatch =  str2num (StringFromList(0, minMaxStr , ","))
				if (numType (minMatch) != 0)
					return 1
				else
					if (cmpStr (",", minMaxStr [ strLen (minMaxStr) -1]) ==0)
						maxMatch = INF
					else
						maxMatch = minMatch
					endif
					return 0
				endif
			elseif (nMinMax ==2) // max is set. min might not be set
				maxMatch = str2num (StringFromList(1, minMaxStr , ","))
				if (numType (maxMatch) != 0)
					return 1
				else
					if (cmpStr (",", minMaxStr [0]) ==0)
						minMatch = 0
					else
						minMatch = str2num (StringFromList(0, minMaxStr , ","))
						if (numType (minMatch) != 0)
							return 1
						else
							return 0
						endif
					endif
				endif
			else
				return 1	// other than 1 or 2 items in defined range
			endif
		else // bad format
			return 1
		endif
	else
		minMatch = 1
		maxMatch =1
		return 1 // no min/max code found
	endif
end

//******************************************************************************************************
// returns a string corresponding to a character class
// sets invert variable if class is inverted
// moves ir to end of character class
// Last Modified 2014/07/07 by Jamie Boyd
Static Function/S GUIPGrepGetCharacterClass (regExp, ir, invert)
	string &regExp
	variable &ir
	variable &invert
	
	string returnStr = ""
	variable endPos= strsearch(regExp, "]", ir)
	variable escaped
	variable irange, rangeEnd
	if (endPos  > -1)
		if (cmpStr(regExp [ir+1], "^") == 0)
			invert = 1
			ir +=1
		else
			invert=0
		endif
		for (ir +=1; ir < endPos; ir +=1)
			if (cmpStr (regExp [ir], "\\") ==0) 
				escaped =1
				ir +=1
			else
				escaped =0
			endif
			if ((!(escaped)) && (cmpStr (regExp [ir+1], "-") ==0)) // a range
				irange = char2num(regExp [ir])
				ir +=2
				rangeEnd = char2num (regExp [ir])
				for (;iRange <= rangeEnd; iRange +=1)
					returnStr += num2char (iRange)
				endfor
			else // not a range
				returnStr += regExp [ir]
			endif
		endfor
	endif
	return returnStr
end
