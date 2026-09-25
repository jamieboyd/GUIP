#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#pragma IgorVersion = 6	

#pragma version = 1.0			// Last Modified: 2026/09/25 by Jamie Boyd


//*******************************************************************************************************************************************
//************************************* Two's Complement Byte-wise Conversions **************************************************************
//*******************************************************************************************************************************************

//*******************************************************************************************************************************************
// Constants for order in which bytes are arranged in multi-byte values
CONSTANT LSB_FIRST = 1		// Least Significant Byte First
CONSTANT MSB_FIRST = 0		// Most Significant Byte First

//*******************************************************************************************************************************************
// Given a signed integer value and a wave, fills the wave with byte representation of the value, using 2's complement
// The number of points in the wave determines the number of bytes to use.
// returns -1 if number is less than most negative integer possible with given number of bytes in wave and sets wave to most negative integer
// returns 1 if number is greater than most positive integer possible with given number of bytes in wave and sets wave to most positive integer
// returns 0 if the theVal is within the range of the given number of bytes
// Last Modified: 2026/09/25 by Jamie Boyd
Threadsafe Function GUIPValTo2CBytes(theVal, byteWave, [byteOrder])
	variable theVal
	WAVE byteWave
	variable byteOrder
	
	// round value to an integer
	theVal = round (theVal)
	variable iByte, nBytes = NumPnts (byteWave)
	// check byte order optional argument, default is LSB_FIRST
	variable byteOrderL = LSB_FIRST
	if (!(paramisDefault(byteOrder)))
		byteOrderL = byteOrder
	endif
	// check for overflow. Number must be between -(256^nBytes)/2 and (256^nBytes)/2 - 1 
	if (theVal < - (256^nBytes)/2)
		byteWave = 0
		if (byteOrderL == LSB_FIRST)
			byteWave [nBytes-1] = 128	// most negative number we can make
		else
			byteWave [0] = 128	// most negative number we can make
		endif
		return -1
	elseif (theVal > (256^nBytes)/2 -1)
		byteWave = 255
		if (byteOrderL == LSB_FIRST)
			byteWave [nBytes -1] = 127	// most positive number we can make
		else
			byteWave [0] = 127
		endif
		return 1
	endif
	// using 2's complement for negative numbers, so flip the bits and add 1 if negative
	if (theVal < 0)
		theVal = ((~-theVal) & ((256^nBytes)-1)) + 1
	endif
	if (byteOrderL == LSB_FIRST)
		// get each byte from modulus of the value divided by scaled byte and 256
		for (iByte =0; iByte < nBytes; iByte +=1)
			byteWave [iByte]= mod (floor (theVal/(256^iByte)), 256)
		endfor
	else
		// get each byte from modulus of the value divided by scaled byte and 256
		for (iByte =0; iByte < nBytes; iByte +=1)
			byteWave [iByte]= mod (floor (theVal/(256^(nBytes - iByte - 1))), 256)
		endfor
	endif
	return 0
end


//*******************************************************************************************************************************************
// Given a unsigned byte wave containing a  multi-byte representation of a signed integer, this function returns the signed integer
// Last Modified: 2026/09/25 by Jamie Boyd
Threadsafe Function GUIP2CBytesToVal(byteWave, [byteOrder])
	Wave byteWave 
	variable byteOrder
	
	// check byte order optional argument, default is LSB_FIRST
	variable byteOrderL = LSB_FIRST
	if (!(paramisDefault(byteOrder)))
		byteOrderL = byteOrder
	endif
	// init value to zero and init nBytes to number of points in the wave
	variable calcVal =0
	variable iByte, nBytes = numPnts (byteWave)
	
	if (byteOrderL == LSB_FIRST)
		if (byteWave [nBytes -1] & 128)	// most significant bit is set
			calcVal -= 256^(nBytes)
		endif
		for (iByte = 0; iByte < nBytes; iByte +=1)
			calcVal += byteWave [iByte] * 256^iByte
		endfor
	else // byteOrder is MSB first
		if (byteWave [0] & 128)	// most significant bit is set
			calcVal -= 256^(nBytes)
		endif
		for (iByte = 0 ; iByte < nBytes ; iByte +=1)
			calcVal += byteWave [iByte] * 256^(nBytes - iByte - 1)
		endfor
	endif
	return calcVal
end


//*******************************************************************************************************************************************
// Tests conversion between Integers and Two's complement byte sequences
// Prints sequence of nBytes bytes for the integer theVal using GUIPValTo2CBytes, 
// then prints Integer value calculated back from the bytes using GUIP2CBytesToVal
// Last Modified: 2013/12/18 by Jamie Boyd
function GUIP2Ctest(theVal, nBytes, byteOrderP)
	variable theVal // an integer value
	variable nBytes // number of bytes with which to represent it
	variable byteOrderP // byte order, MSB_FIRST or LSB_FIRST
	
	// make a free wave and set bytes with GUIPValTo2CBytes
	make/FREE/n=(nBytes) /b/u ByteWave
	GUIPValTo2CBytes (theVal, ByteWave, byteOrder = byteOrderP)
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
	printf  "Bytes to 2C:\t%-16d\r", GUIP2CBytesToVal (ByteWave, byteOrder = byteOrderP)
end

//*******************************************************************************************************************************************
// Utility function to make a string represenation (0s and 1s) of the  bits in a byte
// printf now supports the %b Conversion Character, a WaveMetrics extension that converts a numeric parameter to binary
// Last Modified: 2013/12/18 by Jamie Boyd
Function/S GUIPByte2Str (theByte)
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

