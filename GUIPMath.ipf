#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion=5
#pragma version = 1	 // Last Modified: 2015/03/30 by Jamie Boyd
#pragma module = "GUIPMath"
//Some utility functions, probably more to follow


//******************************************************************************************************
// this function calculates a  a signed 32 bit integer fractional equivalent for a number (input) given in decimal format.
// Variables to get the numerator and denominator of the fraction are passed by reference
// The general principle is to start with input = numerator, denominator =1, multiply both by a big constant, round numerator to an integer, and reduce
// the biggest signed 32 bit integer is 2^31 -1 = approx 2.14748e+09, so make sure neither numerator nor denominator will be bigger than that
// the chosen constant is a multiple of some comon numbers so many fractions will reduce nicely, and is a little bit less than 2^31
// RatioFromNumber operation was introduced  In Igor 6, obsoleting this function
STATIC CONSTANT kdec2FracMult =  1297296000 // 5*8*9*10*11*12*13*14*15
STATIC CONSTANT kOverFlow64=3471528 // biggest 64 bit int, 2^52-1/kdec2FracMult
Function  GUIPdec2frac (inPut, numerator, denominator)
	variable input
	variable &numerator, &denominator
	
	if (input ==0)
		numerator =0
		denominator = 1
	else
		variable mult=kdec2FracMult
		// can't overflow bigggest 64 float int, 2^52-1
		if (abs(inPut) > kOverFlow64)
			mult = floor (input/kOverFlow64)
		endif
		numerator = round (input * mult)
		denominator = mult
		// use GCD function to reduce fraction
		variable GreatestCommonDivisor = gcd (numerator, denominator)
		numerator/= GreatestCommonDivisor
		denominator /= GreatestCommonDivisor
		// output can't be bigger than 32bit int
		if (abs (numerator) > 2^31)
			mult = floor (mult/input)
			numerator = round (input * mult)
			denominator = mult
			// use GCD function to reduce fraction
		 	GreatestCommonDivisor = gcd (numerator, denominator)
			numerator/= GreatestCommonDivisor
			denominator /= GreatestCommonDivisor
		endif
	endif
	return 0
end

//******************************************************************************************************
// Function to test the dec2frac function
Function GUIPtestdec2frac (input)
	variable input
	
	variable numerator, denominator
	 GUIPdec2frac (inPut,numerator, denominator)
	 printf  "numerator =%d, denominator = %d\r"numerator, denominator
	 printf "Division Result = %.12f\r" numerator/denominator
	 printf "Error = %.12f%\r", 100 * (input - (numerator/denominator))/input
end

//******************************************************************************************************
// Binary Searches for sorted text waves.
// THESE ASSUME THAT THE TEXT WAVE IS ALREADY ALPHABETICALLY SORTED
//******************************************************************************************************
// A utility function to calculate base 2 logarithms
STATIC CONSTANT log2 =  0.301029995664
Function GUIPlogBase2 (theValue)
	variable theValue
	
	return log (theValue)/log2
end

//******************************************************************************************************
// finds the first or Last occurrence of a text within a range of points in a SORTED text wave
// returns the point number of the last occurrence, or -1 times (1 + the position before which where thetext should be inserted) if the text was not found
// the +1 offfset for missing values is so that a value found at pos 0 can be discriminated from a missing value that needs to be inserted before pos 0 
// Last Modified 2014/08/19 by Jamie Boyd
function GUIPMathFindText (theWave, thetext, startPos, endPos, LastNotFirst)
	wave/T theWave // alpabetically sorted text wave. 
	string thetext // the text to find in this wave, matching the entire contents of the wave at the returned point
	variable startPos, endPos // range over which to search. Can pass INF to seach whole wave
	variable LastNotFirst // set to 1 to find last occurrence, not first occurrence
	
	// limit start and end positions to possible values
	startPos = max (0, startPos)
	endPos = min (numPnts (theWave)-1, endPos)
	if (endPos == -1)
		return -1
	endif
	variable iPos // the point to be compared
	variable  theCmp // the result of the comparison
	variable firstPt, lastPt// variables the define the range oer which comparisons will be made
	for (firstPt =startPos, lastPt = endPos; firstPt < lastPt; )
		iPos = trunc ((firstPt + lastPt)/2)			
		theCmp = cmpStr (thetext, theWave [iPos])
		if (theCmp == 1) //thetext is alphabetically after theWave [iPos]
			firstPt = min (lastPt, iPos +1)
		elseif (theCmp ==-1)// thetext is alphabetically before theWave [iPos]
			lastPt =max (firstPt, iPos -1)
		else //thetext is the same as theWave [iPos]
			if (LastNotFirst)
				if ((iPos ==endPos) || (cmpStr (theText, theWave [iPos +1]) == -1)) // then iPos is the last occurence of thetext in theWave from startPos to endPos
					return iPos
				else //  there are more copies of theText in theWave after iPos 
					firstPt = min (lastPt, iPos +1)
				endif
			else
				if ((iPos ==startPos) || (cmpStr (theText, theWave [iPos -1]) == 1)) // then iPos is the first occurence of thetext in theWave from startPos to endPos
					return iPos
				else //  there are more copies of theText in theWave before iPos 
					lastPt = max (firstPt, iPos-1)
				endif
			endif
		endif
	endfor
	// when we exit the loop, firstPt and lastPt are the same. Either we are at the correct point, or point is not in this wave
	theCmp = cmpStr (thetext, theWave [firstPt])
	if (theCmp == 0)
		return firstPt 
	else
		if (theCmp == 1)
			firstPt +=1
		endif
		return -(firstPt +1)
	endif
end

//******************************************************************************************************
// searches through a specific row or a sepecific column in a 2D text wave SORTED on the specified row or column
// Last Modified 2014/08/20 by Jamie Boyd
function GUIPMathFindText2D (theWave, thetext, startPos, endPos, dimNumber, rowOrcol, LastNotFirst)
	wave/T theWave // alpabetically sorted text wave. 
	string thetext // the text to find in this wave, matching the entire contents of the wave at the returned point
	variable startPos, endPos // range over which to search. Can pass INF to seach whole wave
	variable dimNumber // the dimension over which to search (0 to search a particular row, 1 to search a particular column)
	variable  rowOrCol // the row or column to search
	variable LastNotFirst // non-zero to find last occurrence of theText, not first
	
	// limit start and end positions to possible values
	startPos = max (0, startPos)
	endPos = min (endPos, DimSize(theWave, dimNumber)-1)
	if (endPos == -1)
		return -1
	endif
	variable iPos // the point to be compared
	variable  theCmp // the result of the comparison
	variable firstPt, lastPt// variables the define the range oer which comparisons will be made
	for (firstPt =startPos, lastPt = endPos; firstPt < lastPt; )
		iPos = trunc ((firstPt + lastPt)/2)
		if (dimNumber == 0)
			theCmp = cmpStr (thetext, theWave [iPos] [roworCol])
		else
			theCmp = cmpStr (thetext, theWave [roworCol] [iPos] )
		endif
		if (theCmp == 1) //thetext is alphabetically after theWave [iPos]
			firstPt = min (lastPt, iPos +1)
		elseif (theCmp ==-1)// thetext is alphabetically before theWave [iPos]
			lastPt =max (firstPt, iPos -1)
		else //thetext is the same as theWave [iPos]
			if (LastNotFirst)
				if (iPos ==endPos)
					return iPos
				elseif (dimNumber ==0)
					if (cmpStr (theText, theWave [iPos +1] [rowOrCol]) == -1)
						return iPos
					endif
				elseif (cmpStr (theText, theWave  [rowOrCol] [iPos +1]) == -1)
					return iPos
				else
					firstPt =min (lastPt, iPos +1)
				endif
			else
				if (iPos ==startPos)
					return iPos
				elseif (dimNumber ==0)
					if (cmpStr (theText, theWave [iPos -1] [rowOrCol]) ==1)
						return iPos
					endif
				elseif (cmpStr (theText, theWave  [rowOrCol] [iPos -1]) == 1)
					return iPos
				else //  there are more copies of theText in theWave before iPos 
					lastPt = max (firstPt, iPos-1)
				endif
			endif
		endif
	endfor
	// when we exit the loop, firstPt and lastPt are the same. Either we are at the correct point, or point is not in this wave
	if (dimNumber ==0)
		theCmp = cmpStr (thetext, theWave [firstPt] [rowOrCol])
	else
		theCmp = cmpStr (theText, theWave [rowOrCol] [firstPt])
	endif
	if (theCmp == 0)
		return firstPt 
	else
		if (theCmp == 1)
			firstPt +=1
		endif
		return -(firstPt +1)
	endif
end


//******************************************************************************************************
// the text versions were so useful, I've expanded to numeric
// Note that the wave can not contain NaNs
// Lat Modified 2014/08/19 by Jamie Boyd
function GUIPMathFindNum (theWave, theNum, startPos, endPos, LastNotFirst)
	wave theWave // sorted wave. 
	variable theNum // the number to find in this wave
	variable startPos, endPos // range over which to search. Can pass INF to seach whole wave
	variable LastNotFirst
	
	// limit start and end positions to possible values
	startPos = max (0, startPos)
	endPos = min (numPnts (theWave)-1, endPos)
	if (endPos == -1)
		return -1
	endif
	variable iPos // the point to be compared
	variable firstPt, lastPt// variables the define the range oer which comparisons will be made
	for (firstPt =startPos, lastPt = endPos; firstPt < lastPt; )
		iPos = trunc ((firstPt + lastPt)/2)
		if (theNum > theWave [iPos] )
			firstPt = min (lastPt, iPos +1)
		elseif (theNum < theWave [iPos] )
			lastPt =max (firstPt, iPos -1)
		else //theNum is the same as theWave [iPos]
			if (LastNotFirst)
				if ((iPos ==endPos) || (theNum <  theWave [iPos +1])) // then iPos is the last occurence of theNum
			 		return iPos
			 	else // there are more copies of theNum after iPos
			 		firstPt = min (lastPt, iPos +1)
			 	endif
			 else
				if ((iPos ==startPos) || (theNum > theWave [iPos -1])) 
					return iPos
				else //  there are more copies of theNum in theWave before iPos 
					lastPt = max (firstPt, iPos-1)
				endif
			endif
		endif
	endfor
	// when we exit the loop, firstPt and lastPt are the same. Either we are at the correct point, or point is not in this wave
	if (theNum == theWave [firstPt]) 
		return firstPt 
	else
		if (theNum > theWave [firstPt])
			firstPt +=1
		endif
		return -(firstPt +1)
	endif
end


//******************************************************************************************************
// searches through a specific row or a sepecific column in a 2D text wave SORTED on the specified row or column
// Last modified 2014/08/19
function GUIPMathFindNum2D (theWave, theNum, startPos, endPos, dimNumber, rowOrcol, LastNotFirst)
	wave theWave // sorted numeric wave. 
	variable theNum // the text to find in this wave, matching the entire contents of the wave at the returned point
	variable startPos, endPos // range over which to search. Can pass INF to seach whole wave
	variable dimNumber // the dimension over which to search (0 to search a particular row, 1 to search a particular column)
	variable  rowOrCol // the row or column to search
	variable LastNotFirst // non-zero to find last occurrence of theText, not first
	
	// limit start and end positions to possible values
	startPos = max (0, startPos)
	endPos = min (endPos, DimSize(theWave, dimNumber)-1)
	if (endPos == -1)
		return -1
	endif
	variable iPos // the point to be compared
	variable iNum // the number at iPos
	variable  theCmp // the result of the comparison
	variable firstPt, lastPt// variables the define the range oer which comparisons will be made
	for (firstPt =startPos, lastPt = endPos; firstPt < lastPt; )
		iPos = trunc ((firstPt + lastPt)/2)
		if (dimNumber == 0)
			iNum = theWave [iPos] [roworCol]
		else
			iNum = theWave [roworCol] [iPos]
		endif
		if (theNum < iNum)
			lastPt =max (firstPt, iPos -1)
		elseif (theNum > iNum)
			firstPt = min (lastPt, iPos +1)
		else //theNum is the same asiNum
			if (LastNotFirst)
				if (ipos ==endPos) 
					return iPos
				else
					if (dimNumber ==0)
						iNum =  theWave [iPos+1] [roworCol]
					else
						iNum =  theWave [roworCol] [iPos+1]
					endif
				endif
				if (theNum <  iNum)
					return iPos
				else
					firstPt = min (lastPt, iPos +1)
			 	endif
			else
				if (iPos ==startPos)
					return iPos
				elseif (dimNumber ==0)
					iNum =  theWave [iPos-1] [roworCol]
				else
					iNum =  theWave [roworCol] [iPos-1]
				endif
				if (theNum > iNum)
					return iPos
				else //  there are more copies of theNum in theWave before iPos 
					lastPt = max (firstPt, iPos-1)
				endif
			endif
		endif
	endfor
	// when we exit the loop, firstPt and lastPt are the same. Either we are at the correct point, or point is not in this wave
	if (dimNumber ==0)
		iNum = theWave [firstPt] [rowOrCol]
	else
		iNum =  theWave [rowOrCol] [firstPt]
	endif
	if (theNum == iNum)
		return firstPt 
	else
		if (theNum > iNum)
			firstPt +=1
		endif
		return -(firstPt +1)
	endif
end

//******************************************************************************************************
// expanded to dimension labels. Wave must be sorted by dimension labels
// Last Modified 2014/08/19 by Jamie Boyd
function GUIPMathFindDimLabelText (theWave, thetext, startPos, endPos, dimNumber, rowOrcol, LastNotFirst)
	wave theWave // alpabetically sorted  by dimension labels
	string thetext // the text to find in this wave's dimension labels
	variable startPos, endPos // range over which to search. Can pass INF to seach whole wave
	variable dimNumber // the dimension over which to search (0 to search a particular row, 1 to search a particular column)
	variable  rowOrCol // the row or column to search
	variable LastNotFirst // non-zero to find last occurrence of theText, not first
	
	// limit start and end positions to possible values
	startPos = max (0, startPos)
	endPos = min (endPos, DimSize(theWave, dimNumber)-1)
	if (endPos == -1)
		return -1
	endif
	variable iPos // the point to be compared
	variable  theCmp // the result of the comparison
	variable firstPt, lastPt// variables the define the range oer which comparisons will be made
	for (firstPt =startPos, lastPt = endPos; firstPt < lastPt; )
		iPos = trunc ((firstPt + lastPt)/2)
		theCmp = cmpStr (thetext, GetDimLabel(theWave, dimNumber, iPos))
		if (theCmp == 1) //thetext is alphabetically after theWave [iPos]
			firstPt = min (lastPt, iPos +1)
		elseif (theCmp ==-1)// thetext is alphabetically before theWave [iPos]
			lastPt =max (firstPt, iPos -1)
		else //thetext is the same as theWave [iPos]
			if (LastNotFirst)
				if ((iPos ==endPos) ||  (cmpStr (thetext, GetDimLabel(theWave, dimNumber, iPos +1))== -1)) // then iPos is the last occurence of thetext in theWave from startPos to endPos
					return iPos
				else //  there are more copies of theText in theWave after iPos 
					firstPt =min (lastPt, iPos +1)
				endif
			else
				if ((iPos ==startPos) ||  (cmpStr (thetext, GetDimLabel(theWave, dimNumber, iPos -1))== 1)) // then iPos is the first occurence of thetext in theWave from startPos to endPos
					return iPos
				else //  there are more copies of theText in theWave before iPos 
					lastPt = max (firstPt, iPos-1)
				endif
			endif
		endif
	endfor
	// when we exit the loop, firstPt and lastPt are the same. Either we are at the correct point, or point is not in this wave
	theCmp = cmpStr (thetext, GetDimLabel(theWave, dimNumber, firstPt))
	if (theCmp == 0)
		return firstPt 
	else
		if (theCmp == 1)
			firstPt +=1
		endif
		return -(firstPt +1)
	endif
end
	
//******************************************************************************************************
// expanded to dimension labels.  Labels must be numeric (with str2num) and Wave must be sorted by dimension labels numerically, not alphabetically
// Last Modified 2015/02/03 by Jamie Boyd
Function GUIPMathFindDimLabelNum (theWave, theNum, startPos, endPos, dimNumber, LastNotFirst)
	wave theWave // alpabetically sorted  wave. 
	variable theNum // the value to find in this wave's dimensions labels
	variable startPos, endPos // range over which to search. 
	variable dimNumber // the dimension over which to search (0 to search a particular row, 1 to search a particular column)
	variable LastNotFirst // non-zero to find last occurrence of theText, not first
	
	// limit start and end positions to possible values
	startPos = max (0, startPos)
	endPos = min (DimSize (theWave, dimNumber)-1, endPos)
	if (endPos == -1)
		return -1
	endif
	variable iPos // the point to be compared
	variable iDimNum
	variable firstPt, lastPt// variables the define the range oer which comparisons will be made
	for (firstPt =startPos, lastPt = endPos; firstPt < lastPt; )
		iPos = trunc ((firstPt + lastPt)/2)			
		iDimNum = str2num (GetDimLabel(theWave, dimNumber, iPos))
		if (theNum >  iDimNum)
			firstPt = min (lastPt, iPos +1)
		elseif (theNum < iDimNum)
			lastPt =max (firstPt, iPos -1)
		else //the Num is the same as the dimlabel for theWave [iPos]
			if (LastNotFIrst)
				if ((iPos ==endPos) || (theNum  <  str2Num (GetDimLabel(theWave, dimNumber, iPos+1))))
					return iPos
				else
					firstPt = min (lastPt, iPos +1)
				endif
			else
				if ((iPos ==startPos) || (theNum  >  str2Num (GetDimLabel(theWave, dimNumber, iPos -1)))) // then iPos is the first occurence of thetext in theWave from startPos to endPos
					return iPos
				else //  there are more copies of theText in theWave before iPos 
					lastPt = max (firstPt, iPos-1)
				endif
			endif
		endif
	endfor
	// when we exit the loop, firstPt and lastPt are the same. Either we are at the correct point, or point is not in this wave
	iDimNum = str2num (GetDimLabel(theWave, dimNumber, firstPt))
	if (theNum == iDimNum)
		return firstPt 
	else
		if (theNum > iDimNum)
			firstPt +=1
		endif
		return -(firstPt +1)
	endif
end


//******************************************************************************************************
// test for the findText function's ability to return correct position for inserting a string that was not found in a text wave
//When this function ends, root:testFindFirstText should contain howMany strings of  random capital letters of length howLong, sorted alphabetically
// Last Modified 2014/08/19 by Jamie Boyd
function GUIPtestFindText (howMany, howLong)
	variable howMany
	variable howLong
	
	make/t/o/n = 0 root:testFindText
	WAVE/t test = root:testFindText
	variable iM, iL, pos
	string entry
	for (iM =0;iM < howMany; iM +=1)
		for (iL=0, entry=""; iL <  howLong; iL +=1)
			entry += num2Char (65 + floor (13 + enoise (13))) // the entry string will consist of random capital letters A-Z
		endfor
		pos = GUIPMathFindText (test, entry, 0, inf, 1)
		if (pos < 0) // text was not found
			// account for the 1 character offset in position used to disambiguate "-0 = not found, aphabetically before pos 0" and
			// "0 = found at position 0"
			pos = -(pos +1) 
		endif
		insertpoints pos, 1, test
		test [pos] = entry
	endfor
	edit root:testFIndText
end

//******************************************************************************************************
// Similar test for findNum function
// Last Modified 2014/08/19 by Jamie Boyd
function GUIPtestFindNum (howMany, maxSize)
	variable howMany
	variable maxSize
	
	make /o/n = 0 root:testFindNum
	WAVE test = root:testFindNum
	variable iM, pos
	variable entry
	for (iM =0;iM < howMany; iM +=1)
		entry = round (maxSize/2 + enoise (maxSize/2))
		pos = GUIPMathFindNum(test, entry, 0, inf, 1)
		if (pos < 0) // text was not found
			// account for the 1 character offset in position used to disambiguate "-0 = not found, aphabetically before pos 0" and
			// "0 = found at position 0"
			pos = -(pos +1) 
		endif
		insertpoints pos, 1, test
		test [pos] = entry
	endfor
	display root:testFindNum
end


//******************************************************************************************************
// A test of the GUIPMathFindText function, using FindValue as a baseline
// both accuracy and speed are tested
// Last Modified Feb 03 2012 by Jamie Boyd

function GUIPtestFindFirstLastText (maxN)
	variable maxN
	
	variable iPt, nPts = floor (GUIPlogBase2 (maxN))
	// output waves
	make/o/n=(nPts) FindValueFirstTime_out, FindValueLastTime_out, FFTOtime_out, FLTOtime_out
	setScale d 0,0 ,"s" FindValueFirstTime_out, FindValueLastTime_out, FFTOtime_out, FLTOtime_out
	make/o/n=(nPts) FindValueFirstPos_out, FindValueLastPos_out, FFTOpos_out, FLTOpos_out
	// make data wave
	variable iN, iVal, valToN
	make/o/T/n =(maxN) testTextWave
	WAVE/T testTextWave
	for (iN =0, iVal =0;iN < maxN; iVal +=1)
		for (valToN = iN + ceil (GUIPlogBase2 (iVal +2)); iN < valToN;  iN +=1)
			testTextWave [iN] = num2str (iVal)
		endfor
	endfor
	// sort it, because CmpStr does not do alphanumeric comparison properly, 10 is befor 9
	Sort testTextWave, testTextWave
	// varables for finding and timing
	string toFind
	variable fPos, myTimer, elapsedTime
	for (iPt =0; iPt < nPts; ipt += 1)
		// find increasingly further values in the wave
		 toFind = testTextWave [2^ (iPt + 2)]
		// find first occurrence
		// use find value
		myTimer = startmstimer
		FindValue/S=0 /TEXT=toFind/TXOP=4  testTextWave
		elapsedTime = stopMSTimer(myTimer )/1e06
		FindValueFirstTime_out [iPt] = elapsedTime
		FindValueFirstPos_out [iPt] = V_Value
		// use GUIPMathFirstText
		myTimer = startmstimer
		fPos = GUIPMathFindText (testTextWave, toFind, 0, maxN, 0)
		elapsedTime = stopMSTimer(myTimer )
		FFTOtime_out [iPt] = elapsedTime/1e06
		FFTOpos_out  [iPt]  = fPos
		// find last occurrence
		// with findValue followed by a loop
		myTimer = startmstimer
		FindValue/S=0 /TEXT=toFind/TXOP=4  testTextWave
		for (iN= V_Value +1;cmpStr (testTextWave [iN], toFind) ==0 && iN < maxN; iN +=1)
		endfor
		elapsedTime = stopMSTimer(myTimer )/1e06
		FindValueLastTime_out [iPt] = elapsedTime
		FindValueLastPos_out [iPt] = iN-1
		// with GUIPMathLastText
		myTimer = startmstimer
		fPos = GUIPMathFindText (testTextWave, toFind, 0, maxN, 1)
		elapsedTime = stopMSTimer(myTimer )
		FLTOtime_out [iPt] = elapsedTime/1e06
		FLTOpos_out  [iPt]  = fPos
	endfor
	display FFTOtime_out, FLTOtime_out vs FindValueFirstPos_out
	modifygraph rgb = (0,0,0)
	appendtoGraph FindValueFirstTime_out, FindValueLastTime_out vs FindValueLastPos_out
	modifygraph mode =4
	label bottom "Points in Text Wave"
	label left "Time to Find Element (\\U)"
	Legend/C/N=text0/F=0/B=1/A=MT
	ModifyGraph log(bottom)=1
	edit FindValueFirstPos_out, FFTOpos_out, FindValueLastPos_out, FLTOpos_out
end


//*******************************************************************************************************************************************
//*************************************Two's Complement Byte-wise Conversions*************************************************************************
//*******************************************************************************************************************************************

//*******************************************************************************************************************************************
// If you have a device that sends/receives data as series of bytes in 2's complement format, these two functions may be of use.
// Given a wave containing a series of bytes comprising a single number in two's complement format, returns the corresponding integer value
// The wave byteWave must  contains only values from 0-255,  as each point in the wave is excpected to contain one byte
// Least significant byte must be at first point in the wave.
// Last Modified: 2014/05/27 by Jamie Boyd
Function GUIP2CBytesToVal (byteWave)
	wave byteWave 
	
	variable calcVal =0
	variable iByte, nBytes = numPnts (byteWave)
	// Multiply each byte by scaling factor
	for (iByte = 0; iByte < nBytes; iByte +=1)
		calcVal += byteWave [iByte] * 256^iByte
	endfor
	// if most significant bit is set, it's a negative number, so flip the bits and  add 1
	if (byteWave [nBytes -1] & 128)
		calcVal = ((~calcVal) & ((256^nBytes)-1)) + 1
		return -calcVal
	else
		return calcVal
	endif
end

//// order = 1 for most signigicant byte first, 0 for least significant byte first
//Function GUIP2CBytesToVal (byteWave, MSBfirst)
//	wave/b/u byteWave 
//	variable MSBfirst
//	
//	variable calcVal =0
//	variable iByte, nBytes = numPnts (byteWave)
//	variable byteMult
//	if (MSBfirst) // most significant byte, with sign bit, is first
//		for (byteMult = 256^(nBytes -iByte), iByte = nBytes-1;iByte > 0; iByte +=1)
//			calcVal += byteWave [iByte] * 
//		endfor
//		if (byteWave [0] & 128)
//			calcVal -= (byteWave [0] - 128)*256^(nBytes -iByte)
//		else
//			calcVal += byteWave [0] * 256^(nBytes -iByte)
//		endif
//	else	// least significant bit first
//		for (iByte = 0; iByte < nBytes-1; iByte +=1)
//			calcVal += byteWave [iByte] * 256^iByte
//		endfor
//			
//	// Multiply each byte by scaling factor
//	for (iByte = 0; iByte < nBytes; iByte +=1)
//		calcVal += byteWave [iByte] * 256^iByte
//	endfor
//	// if most significant bit is set, it's a negative number, so flip the bits and  add 1
//	if (byteWave [nBytes -1] & 128)
//		calcVal = ((~calcVal) & ((256^nBytes)-1)) + 1
//		return -calcVal
//	else
//		return calcVal
//	endif
//end


//*******************************************************************************************************************************************
// Given an integer value and a wave, fills the wave with byte representation of the value, using 2's complement
// First point in wave is least significant byte. The number of points in the wave determines the number of byes to use.
// returns -1 if number is less than most negative integer possible with given number of bytes in wave and sets wave to most negative integer
// returns 1 if number is greater than most positive integer possible with given number of bytes in wave and sets wave to most positive integer
// returns 0 if the theVal is within the range of the given number of bytes
// Last Modified: 2013/12/18 by Jamie Boyd
Function GUIPValTo2CBytes (theVal, byteWave)
	variable theVal
	WAVE byteWave
	
	// round value to an integer
	theVal = round (theVal)
	variable iByte, nBytes = NumPnts (byteWave)
	// check for overflow. Number must be between -(256^nBytes)/2 and  (256^nBytes)/2 -1
	if (theVal < -(256^nBytes)/2)
		byteWave = 0
		byteWave [nBytes-1] = 128
		return -1
	elseif (theVal > (256^nBytes)/2 -1)
		byteWave = 255
		byteWave [nBytes -1] = 127
		return 1
	endif
	// use 2's complement for negative numbers, so flip the bits and add 1
	if (theVal < 0)
		theVal = ((~-theVal) & (256^nBytes-1)) + 1
	endif
	// get each byte from modulus of the value divided by scaled byte and 256
	for (iByte =0; iByte < nBytes; iByte +=1)
		byteWave [iByte]= mod (floor (theVal/(256^iByte)), 256)
	endfor
	return 0
end

//*******************************************************************************************************************************************
// Tests conversion between Integers and Two's complement byte sequences
// Prints sequence of nBytes bytes for the integer theVal using GUIPValTo2CBytes, 
// then prints Integer value calculated back from the bytes using GUIP2CBytesToVal
// Last Modified: 2013/12/18 by Jamie Boyd
function GUIP2Ctest (theVal, nBytes)
	variable theVal // an integer value
	variable nBytes // number of bytes with which to represent it
	
	// make a free wave and set bytes with GUIPValTo2CBytes
	make/FREE/n=(nBytes) /b/u ByteWave
	GUIPValTo2CBytes (theVal, ByteWave)
	// print bytes and bits
	string outPutBytes, outPutBits
	sprintf outPutBytes, "2C Bytes for:\t%-16d", theVal
	sprintf outPutBits, "2C Bits for:\t%-16d", theVal
	variable iByte
	for (iByte =nBytes -1; iByte >=0; iByte -= 1)
		sprintf outPutBytes, outPutBytes + " %-8d ", ByteWave [iByte]
		sprintf outPutBits, outPutBits + " %s ", GUIPByte2Str (ByteWave [iByte])
	endfor
	outPutBytes += "\r"
	outPutBits += "\r"
	print outPutBytes
	print outPutBits
	// print 2CBytesToVal (should equal original Val)
	printf  "Bytes to 2C:\t%-16d\r", GUIP2CBytesToVal (ByteWave)
end

//*******************************************************************************************************************************************
// Utility function to make a string represenation (0s and 1s) of the  bits in a byte
// Last Modified: 2013/12/18 by Jamie Boyd
static function/S GUIPByte2Str (theByte)
	variable theByte
	
	string outStr = ""
	variable iBit
	for (iBit = 7; iBit >= 0; iBit -=1)
		if (theByte & 2^iBit)
			outStr += "1"
		else
			outStr += "0"
		endif
	endfor
	return outStr
end

//*******************************************************************************************************************************************
// gets rgb values from a color table, used, e.g., to color traces in a logical order, with nColors spread evenly over the colorTable
// returns 1 if requested colorTable does not exist, else 0 for success
// Last Modified Jan 31 3012 by Jamie Boyd
function GUIPcolorRamp (cTable, iColor, nColors, rVal, gVal, bVal)
	string cTable // name of an Igor color table. One with a regular progression of colors (Rainbow, Rainbow256, RainbowCycle, etc.) works well
	variable iColor // the number of the current trace to color
	variable nColors // the total number of traces to be colored (or the number at which the cycle of traces should repeat)
	variable &rVal // pass-by-reference variable to hold red value of returned color
	variable &gVal // pass-by-reference variable to hold green value of returned color
	variable &bVal // pass-by-reference variable to hold blue value of returned color
	
	string cTableClean = cleanupName (cTable, 1) 
	wave/z cTableWave = $"root:packages:" + cTableClean
	if(!(waveExists (cTableWave)))
		if (WhichListItem(cTable, CTabList(), ";", 0,0) ==-1)
			print "An Igor color table names \"" + cTable + "\" does not exist."
			return 1
		endif
		if (!(dataFolderExists ("root:Packages")))
			newdatafolder root:packages
		endif
		string savedFldr = getdatafolder (1)
		setdatafolder root:packages
		ColorTab2Wave $cTable
		Rename M_Colors, $cTableClean
		setdatafolder $savedFldr
		wave cTableWave = $"root:packages:" + cTableClean
	endif
	variable pos = mod (iColor, nColors) * dimsize (cTableWave, 0)/(nColors -1)
	// use mod so color table wraps around if iColor > nColors, as for circular data with a circular colorTable
	rVal = cTableWave [pos] [0]
	gval = cTableWave [pos] [1]
	bval = cTableWave [pos] [2]
	return 0
end

//*******************************************************************************************************************************************
// prints rgb values for a particular color ramp, in case you use it over and over again
// last modified 2015/11/11 by Jamie Boyd
function GUIPprintColorRamp (ctable, nVals)
	string ctable
	variable nVals
	
	variable iVal, rval, gval, bval
	for (iVal =0; iVal < nVals; iVal +=1)
		GUIPcolorRamp (cTable, ival, nvals, rVal, gVal, bVal)
		printf "for value %d, red, green, blue =( %d, %d, %d)\r", iVal, rVal, gVal, bVal
	endfor
end

//*******************************************************************************************************************************************
// gets rgb values from a color table, scaled from minVal to maxVal
// returns 1 if requested colorTable does not exist, else 0 for success
// Last Modified 2014/07/07 by Jamie Boyd
function GUIPcolorRampScal (cTable, iVal, minVal, maxVal, rVal, gVal, bVal)
	string cTable // name of an Igor color table. One with a regular progression of colors (Rainbow, Rainbow256, RainbowCycle, etc.) works well
	variable iVal // the Value associated with the current trace to color
	variable minVal // the starting value for the color range
	variable maxVal // the ending value for the color range
	variable &rVal // pass-by-reference variable to hold red value of returned color
	variable &gVal // pass-by-reference variable to hold green value of returned color
	variable &bVal // pass-by-reference variable to hold blue value of returned color
	
	string cTableClean = cleanupName (cTable, 1) 
	wave/z cTableWave = $"root:packages:" + cTableClean
	if(!(waveExists (cTableWave)))
		if (WhichListItem(cTable, CTabList(), ";", 0,0) ==-1)
			print "An Igor color table names \"" + cTable + "\" does not exist."
			return 1
		endif
		if (!(dataFolderExists ("root:Packages")))
			newdatafolder root:packages
		endif
		string savedFldr = getdatafolder (1)
		setdatafolder root:packages
		ColorTab2Wave $cTable
		Rename M_Colors, $cTableClean
		setdatafolder $savedFldr
		wave cTableWave = $"root:packages:" + cTableClean
	endif
	variable pos = iVal < minVal ? minVal : iVal
	pos = iVal > maxVal ? maxVal : iVal
	pos = round (((iVal - minVal)/(maxVal - minVal)) * (dimsize (cTableWave, 0) -1))
	rVal = cTableWave [pos] [0]
	gval = cTableWave [pos] [1]
	bval = cTableWave [pos] [2]
	return 0
end


//******************************************************************************************************
//******************** *************Gaussian kernels*********************************************************
//******************************************************************************************************
// Returns a 1D Gaussian using Pascal's Triangle.  Using this method, the kernel sigma scales with the  log of nK
// Last Modified 2013/07/30
Function GUIPGaussianLinePT (nK)
	variable nK //kernel width
	
	make/o/n = (nK) kernelPT
	kernelPT = 0
	kernelPT [0] = 1/2^(nk -1)
	variable ii, ij
	for (ii =1; ii < nK; ii += 1)
		for (ij =nK-1 ; ij > 0; iJ -=1)
			kernelPT [ij] += kernelPT [ij-1]
		endfor
	endfor
	return nK
end

//******************************************************************************************************
// method to make a 1D Gaussian kernel where kernel width and cut-off factor for kernel truncation are both specified. 
// Gaussian width of the filter (in pixels)  is specified as the sigma of the Guassian distriution.
// Sigma is equal to full width at half height / sqrt(2)
// Cut Off Factor defines how many sigmas of the Gaussian to clip the kernel size to. This is converted to a decimal value
// for the cut off using the erf function:
// x Sigma = erf (x/sqrt(2))			cutoff = 1-  erf (x/sqrt(2))
// 
// 1 sigma= 0.682689492137086		cutoff= 0.3173105078629140
//1.5 sigma=0.866385597462284	cutoff=0.1336144025377159
// 2 sigma= 0.954499736103642		cutoff=0.0455002638963580
// 2.5 sigma = 0.987580669348448	cutoff=0.0124193306515520
// 3 sigma = 0.997300203936740	cutoff=0.0026997960632600
// 3.5 sigma =0.999534741841929	cutoff=0.0004652581580710
// 4 sigma = 0.999936657516334	cutoff=0.0000633424836660
// 4.5 sigma =0.999993204653751	cutoff=0.0000067953462490
// 5 sigma = 0.999999426696856	cutoff=0.0000005733031440
// 5.5 sigma = 0.999999962020875	cutoff=0.0000000379791250
// 6 sigma = 0.999999998026825	cutoff=0.0000000019731750
// 6.5 sigma = 0.999999999919680	cutoff=0.0000000000803200
// 7 sigma = 0.999999999997440	cutoff=0.0000000000025600

// The number of pixels in the kernel is 1 + (1+ 2 * cutOffFactSigma) * Gaussian sigma (in pixels)
// Last Modified 2016/10/28
Function/WAVE GUIPGaussianLine2 (kernelSigma, cutOffFactSigma)
	variable kernelSigma		// sigma of the Gaussian, in pixels
	variable cutOffFactSigma  //  How many sigmas of the kernel to show. 1.5 to 3 is a reasonable range
	
	// calculate pixel width of the kernel with given Gaussian width and cutoff
	variable nk = (1 + (1+ 2 * cutOffFactSigma) * kernelSigma)
	//  round kernel width to a whole number
	// if width is even, make it odd by adding 1 if rounding down
	// subtracting 1 if rounding up
	if (mod (round (nk), 2) == 0) 
		if (round (nK) < nk) // fractional part of nK is less than 0.5
			nk = round (nk) + 1
		else //  fractional part of nK is greater than 0.5
			nk = round (nk) - 1
		endif
	else
		nk = round (nk)
	endif
	// calculate cutoff factor (proportion) from cutOff factor (sigmas) using error function
	variable cutOffFact = 1 -  erf (cutOffFactSigma/sqrt(2))
	// make and fill the kernel
	make/FREE/n = (nK) Gkernel
	Gkernel = e^((ln(cutOffFact) * (2*p - (nK-1))^2)/(nK-1)^2)
	// return kernel
	return Gkernel
end


//******************************************************************************************************
//Grepish = Limited support of GREP-like features for use on Igor 5. Igor 6 has grep built in
//******************************************************************************************************

//	 special characters: 
//outside brackets
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
// Gets quantifiers for character repitions( minMatch and maxMatch)
// moves ir to end of quantifier
// returns 0 if min, max set, else 1 for formatting error
// Last Modified 2014/07/07 by Jamie Boyd
Static Function GUIPGrepSetMinMax (regExp, ir, minMatch, maxMatch)

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

//******************************************************************************************************
// lists all permutations of a semicolon-separated string list
// Last modified 2015/01/15 by Jamie Boyd
//print GuipListPerm ("a;b;c", "\r")
// a;b;c
// a;c;b
// b;a;c
// b;c;a
// c;a;b
// c;b;a
function/S GUIPlistPerm (pList, sepChar)
	string pList // a semicolon separated list, e.g. "a;b;c;"
	string sepChar // the chracter used to separate the list of permutations, must not be a semicolon
	
	variable nList = itemsinlist (pList, ";")
	// a list of 1 item has only 1 permutation
	if (nList ==1)
		return removeEnding (pList, ";")  + sepChar
	else
		variable iList
		string rStr = ""
		string startStr, subPerm
		variable iSub, nSub
		// break down problem into all permutations starting with first item, all permutations starting with second item, etc.
		// To get all the permutations that start with the ith item, prepend the ith item to each  permutation of the original list with the ith item removed
		for (iList =0; iList < nList; iList +=1)
			startStr = stringFromList (iList, pList, ";")
			subPerm = GUIPlistPerm (RemoveFromList(startStr, pList, ";"), sepChar)
			nSub = itemsInList (subPerm, sepChar)
			for (iSub =0; iSub < nSub; iSub +=1)
				rStr += startStr + ";" +stringFromList (iSub, subPerm, sepChar) + sepChar
			endfor
		endfor
		return rStr
	endif
end

//******************************************************************************************************
//******************************** Some utilitites for dealing with UNIX Time ********************************
//******************************************************************************************************
// Igor uses UNIX time format, where a date and time is stored as a single 64 bit float as the difference in  seconds since midnight Jan 1 1904

// constant for the number of seconds in a day
STATIC CONSTANT kSECSPERDAY =86400

//******************************************************************************************************
// rounds down a UNIX time to the beginning of the day
Function GUIPUtime_RoundDownDay (secs)
	variable secs
	
	return floor (secs/kSECSPERDAY) * kSECSPERDAY
end

//******************************************************************************************************
// rounds up a UNIX time to the end of the day
Function GUIPUtime_RoundUpDay (secs)
	variable secs
	
	return ceil (secs/kSECSPERDAY) * kSECSPERDAY
end
