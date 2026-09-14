#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

#pragma version = 1	 			// Last Modified: 2026/09/12 by Jamie Boyd

//******************************************************************************************************
// Binary Searches for sorted waves, both text and numeric. 
// THESE ASSUME THAT THE TEXT WAVE IS ALREADY ALPHABETICALLY SORTED
// The versions for text waves assume that the text wave input is already alphabetically sorted. 
// Each function finds the First or Last occurrence of theText or theNumber within a range of points in
// a SORTED wave. If theText or theNumber is repeated, the LAstNotFirst argument determenes whether the
// function returns the point number of the first or last occurrence of theText or theNumber.


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
function GUIPBinarySearchText(theWave, thetext, startPos, endPos, LastNotFirst)
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
function GUIBinarySearchText2D(theWave, thetext, startPos, endPos, dimNumber, rowOrcol, LastNotFirst)
	wave/T theWave // alpabetically sorted text wave. 
	string thetext // the text to find in this wave, matching the entire contents of the wave at the returned point
	variable startPos, endPos // range over which to search. Can pass 0 and INF to seach whole wave
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
function GUIPBinarySearchNum(theWave, theNum, startPos, endPos, LastNotFirst)
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
function GUIPBinarySearchNum2D(theWave, theNum, startPos, endPos, dimNumber, rowOrcol, LastNotFirst)
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
// expanded to dimension labels. dimension labels of searched dimension must be ordered alpabetically
// Last Modified 2014/08/19 by Jamie Boyd
function GUIPBinarySearchDimLabelText(theWave, thetext, startPos, endPos, dimNumber, rowOrcol, LastNotFirst)
	wave theWave // alpabetically sorted by dimension labels
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
// expanded to dimension labels.  Labels must be numeric (return a value with str2num) and Wave must be sorted by dimension labels numerically, not alphabetically
// Last Modified 2015/02/03 by Jamie Boyd
Function GUIPBinarySearchDimLabelNum(theWave, theNum, startPos, endPos, dimNumber, LastNotFirst)
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
// When this function ends, root:testFindFirstText should contain howMany strings of random capital letters of length howLong, sorted alphabetically
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
		pos = GUIPBinarySearchText(test, entry, 0, inf, 1)
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
function GUIPBinarySearchNumTest (howMany, maxSize)
	variable howMany
	variable maxSize
	
	make /o/n = 0 root:testFindNum
	WAVE test = root:testFindNum
	variable iM, pos
	variable entry
	for (iM =0;iM < howMany; iM +=1)
		entry = round (maxSize/2 + enoise (maxSize/2))
		pos = GUIPBinarySearchNum(test, entry, 0, inf, 1)
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
// A test of the GUIPBinarySearchText function, using FindValue as a baseline
// both accuracy and speed are tested
// Last Modified 2012/03/02 by Jamie Boyd
function GUIPBinarySearchTester (maxN)
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
	// sort it, because CmpStr does not do alphanumeric comparison properly, 10 is before 9
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
		fPos = GUIPBinarySearchText(testTextWave, toFind, 0, maxN, 0)
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
		// with GUIPBinarySearchText
		myTimer = startmstimer
		fPos = GUIPBinarySearchText(testTextWave, toFind, 0, maxN, 1)
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

