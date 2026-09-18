#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later


//*******************************************************************************************************************************************
//************************************* Two's Complement Byte-wise Conversions *************************************************************************
//*******************************************************************************************************************************************

//*******************************************************************************************************************************************
// If you have a device that sends/receives data as series of bytes in 2's complement format, these two functions may be of use.
// Given a wave containing a series of bytes comprising a single number in two's complement format, returns the corresponding integer value
// The wave byteWave must  contains only values from 0-255, as each point in the wave is excpected to contain one byte
// Least significant byte must be at first point in the wave.
// Last Modified: 2014/05/27 by Jamie Boyd
Threadsafe Function GUIP2CBytesToVal(byteWave)
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


//*******************************************************************************************************************************************
// Given an integer value and a wave, fills the wave with byte representation of the value, using 2's complement
// First point in wave is least significant byte. The number of points in the wave determines the number of byes to use.
// returns -1 if number is less than most negative integer possible with given number of bytes in wave and sets wave to most negative integer
// returns 1 if number is greater than most positive integer possible with given number of bytes in wave and sets wave to most positive integer
// returns 0 if the theVal is within the range of the given number of bytes
// Last Modified: 2013/12/18 by Jamie Boyd
Threadsafe Function GUIPValTo2CBytes(theVal, byteWave)
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
function GUIP2Ctest(theVal, nBytes)
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
// printf now supports the %b Conversion Character, a	WaveMetrics extension that converts a numeric parameter to binary
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

