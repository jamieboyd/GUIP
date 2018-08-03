#pragma rtGlobals=1		// Use modern global access method.
#pragma version = 1		// Last Modified Aug 03 2010 by Jamie Boyd
#pragma IgorVersion = 5.0
#include "GUIPMath" 		// Used for the dec2frac function

// Two functions to write greyscale and color TIFF images. ExportGreyScaleTIFF makes:
// 1 - single greyscale image from a 2D wave
// 2 - a greyscale multiple image stack from a 3D wave
// ExportRGBcolorTIFF makes:
// 1- a single RGB image from a 3D wave with 3 planes specifying Red, Blue, and Green channels
// 2- a single RGB image from multiple 2D waves each specifying one of the Red, Blue, and Green channels. 
// All three waves are optional parameters, and missing channels are filled with 0 (black)
// 3 - a multiplane image stack from multiple 3D waves, each specifying one of the Red, Blue, and Green channnels

// Both functions handle input waves of different bit depths, signed or unsigned integers, and floating point waves, but 
// complex waves are not handled.
// For greyscale images, the type of data in the output image is controlled by the outPutType variable. If the outPut type is 0,
//  the outPut type is the same as the datatype of the input wave. If the output dataType is not 0, it is interpreted as for the 
// result of Igor's waveType function:
//	Type		Bit #	Hex Value
//	complex		0	1
//	32-bit float	1	2
//	64-bit float	2	4
//	8-bit integer	3	8
//	16-bit integer	4	10
//	32-bit integer	5	20
//	unsigned		6	40
// Bit 0 (complex) is always ignored for output. The TIFF tags for the data type are set appropriately so
// other apps will know how to open the images, if they support that data type, that is. I have tested
// 8 and 16 bit signed and unsigned integer and 32 bit floating point import into ImageJ, on both Mac and PC

// RGB color tiffs are always exported as 8 bit unsigned. 

// Scaling the data in the input wave(s) to the range of the output image is by one of three methods, selected by the Scaling variable.
// 1 = Full scaling: For integer wave type, the entire range of the data type of the input wave is mapped to the range of the
// data type of  the output tiff. This method is not applicable for floating point waves. If the data type of the input wave is the same as
//  that requested for the output tiff, the data can be copied directly to the tiff. This is the most accurate method.
//2 = Min and Max of the data. A wavestats operation is done on the  input wave (s) and the minimum and maximum of the data is mapped
// to the range of the datatype of the output tiff.
// 3 = Min and Max provided in optional parameters, and these are mapped to the minimum and maximum of the range of the dataType
// of the outPut Tiff. For RGB Tiffs, separate Min and Max values need to be provided for each channel.
// The mnemonic constants are provided for ease of programming.
CONSTANT kTiffExportFullScale =1
CONSTANT kTiffExportDataMinMax =2
CONSTANT kTiffExportProvidedMinMax =3

// The outPut tiff is written to the folder described in the Igor path named in the string ExportPath. If a valid path is not provided,
// the user is asked to select a folder in which to save the tiff. For greyscale images, the Tiff file itself is named from the name of the
// Igor wave with the addition of the .tif extension. For color images, where multiple waves may be specified, an additional string
// paramter is used to set the tiff file name.

// The only parameter I can think of that you may want to vary (other than the ones that are already passed to the functions) is Photometric
// Interpretation,  which indicates which end of the data range is white and which end is black for a greyscale image.  So I put it in a constant.
// When  Photometric Interpretation  = 1, min value is black  and max value is white. When Photometric interpretation = 0, min value is black
// and max value is white.
CONSTANT kTiffExportPhotoInt = 1 //min value is black and max value is white

//******************************************************************************************************************
//Exports a 2D or 3D wave as a greyscale TIFF file. 
Function ExportGreyScaleTIFF (datawave, ExportPath, outPutType, Scaling, [minVal, maxVal, TimeInSecs, FileNameStr])
	wave DataWave  //reference to a 2 or 3d wave with greyscale information
	String ExportPath //contains the name of an Igor Path where the file will be saved
	variable outPutType // pass 0 to use wave's own data Type for output, else this value is interpreted as for the value reported by WaveType function:
	variable Scaling  // three methods: 0 = Full Scale according to the input wave's type; 1 means use the Data Range of the input wave; 2 means use provided MinVal and MaxVal"	
	variable minVal, maxVal // the minimum and maximum values of the input data to be mapped to the minimum and maximum of the output dataType, if explicit scaling is used
	variable TimeInSecs // number of seconds from 1/1/1904 to the time stamp requested for the  tiff file. If no value passed, TIFF creation date is used
	string fileNameStr
	//make sure the wave exists
	if (!(WaveExists (dataWave)))
		doAlert 0, "Sorry, but the wave, " + nameofwave (datawave) + ", does not exist."
		return 1
	endif
	// Check that min and max have been provided if outPut scaling mode is kProvidedMinMax
	if ((Scaling == kTiffExportProvidedMinMax) && ((paramisDefault (minVal)) || (paramisDefault (maxVal))))
		doalert 0, "Sorry, but you need to provide a minimum value and a maximum value when the Scaling variable is 3."
		return 1
	endif
	//Check the path
	PathInfo $ExportPath
	if (V_Flag == 0)
		if ((cmpStr (ExportPath, "")) == 0)
			ExportPath = "ExportPath"
		endif
		NewPath /M="Where do you want to save the TIFF?" /O/Q ExportPath
		if (V_Flag) // User cancelled the dialog to make new path
			return 1
		endif
	endif
	// Get some info about the image
	if (paramISDefault (TimeInSecs))
		timeInSecs = dateTime
	endif
	variable imDims, inPutType, imWidth, imHeight, imDepth, ResolutionUnit, ResNumeratorX, ResDenominatorX, ResNumeratorY, ResDenominatorY
	string dateStr
	variable errvar
	errvar = TiffWriterGetVariables (datawave, timeinSecs, imDims, inPutType, imWidth, imHeight, imDepth, ResolutionUnit, ResNumeratorX, ResDenominatorX, ResNumeratorY, ResDenominatorY, dateStr)
	if (errvar == 1)
		return 1
	endif
	// More variables for info that will be filled out below
	variable sampleFormat  // Sample Format 1 = unsigned integer data ,2 = two's complement signed integer data ,3 = IEEE floating point data [IEEE] 
	variable outMin, outMax, rangeVar // variables for scaling input waves to outPut TIFF for interger types
	variable inPutIsSigned, outPutIsSigned // 1  for floats and signed signed integer, 0 for Unsigned integers
	variable outPutIsFloat // floating point outPut waves are NEVER scaled
	variable  sampleBits // number of bits/per sample (8, 16, or 32)
	// Check type of input wave
	if (inPutType & 0x06) // 32 or 64 bit floating point wave
		inPutIsSigned =1
		// You can't scale min and max of entire floating point range to fill an outPut range, it makes no sense
		if (Scaling == kTiffExportFullScale)
			print "Input wave is floating point. You can't scale min and max of entire floating point range to fill an outPut range, it makes no sense, so output will be scaled to inPut data range."
			Scaling = kTiffExportDataMinMax
		endif
	elseif (inPutType & 0x20)  // 32 bit integer
		if (inPutType & 0x40) // unsigned 32 bit integer
			inPutIsSigned =0
			if (Scaling == kTiffExportFullScale)
				minVal = 0
				maxVal =2^32-1
			endif
		else // signed 32 bit integer
			inPutIsSigned =1
			if (Scaling == kTiffExportFullScale)
				minVal = -2^31
				maxVal =2^31-1
			endif
		endif
	elseif (inPutType & 0x10)  // 16 bit integer
		if (inPutType & 0x40) // unsigned 16 bit integer
			inPutIsSigned =0
			if (Scaling == kTiffExportFullScale)
				minVal = 0
				maxVal =2^16-1
			endif
		else // signed 16 bit integer
			inPutIsSigned =1
			if (Scaling == kTiffExportFullScale)
				minVal = -2^15
				maxVal =2^15-1
			endif
		endif
	elseif (inPutType & 0x08) // 8 bit integer
		if (inPutType & 0x40) // unsigned 8 bit integer
			inPutIsSigned =0
			if (Scaling == kTiffExportFullScale)
				minVal = 0
				maxVal =2^8-1
			endif
		else // signed 8 bit integer
			inPutIsSigned =1
			if (Scaling == kTiffExportFullScale)
				minVal = -2^7
				maxVal =2^7-1
			endif
		endif		
	endif
	// If scaling from data range, we need to get minimum and  maximum from data
	if (Scaling == kTiffExportDataMinMax)
		WaveStats/Q/M=1 dataWave
		minVal = V_min
		maxVal = V_max
	endif
	// Ensure packages folder in which to make a wave to hold single frame
	if (!(datafolderExists ("root:packages:")))
		newdatafolder root:packages
	endif
	// Get data on OutPut Type
	if (outPutType == 0)
		outPutType = inPutType // outPut type equal to input type makes life easier, see below
	endif
	if (outPutType & 0x04) // 64 bit floating point
		outPutIsFloat = 1
		outPutisSigned = 0
		outMin  = -INF
		outMax = INF
		rangeVar =1
		SampleBits = 64
		make/o/D/n= ((imwidth), (imHeight)) root:Packages:aTIFFplane
	elseif (outPutType & 0x02) // 32 bit floating point
		outPutIsFloat = 1
		outPutisSigned = 0
		sampleBits = 32
		outMin  = -INF
		outMax = INF
		rangeVar =1
		make/o/s/n= ((imwidth), (imHeight)) root:Packages:aTIFFplane
	elseif (outPutType & 0x20)  // 32 bit integer
		outPutIsFloat = 0
		sampleBits = 32
		rangeVar =  2^32/(maxVal - minVal)
		if (outPutType & 0x40) // unsigned 32 bit integer
			outPutIsSigned = 0
			SampleFormat = 1
			make/I/u/o/n= ((imwidth), (imHeight)) root:Packages:aTIFFplane
			outMin = 0
			outMax = 2^32-1
		else
			outPutIsSigned = 1
			SampleFormat = 2 // signed 32 bit integer
			make/I/o/n= ((imwidth), (imHeight)) root:Packages:aTIFFplane
			outMin = -2^31
			outMax = 2^31-1
		endif
	elseif (outPutType & 0x10)  // 16 bit integer
		outPutIsFloat = 0
		sampleBits = 16
		rangeVar =  2^16/(maxVal - minVal)
		if (outPutType & 0x40) // unsigned 16 bit integer
			outPutIsSigned = 0
			SampleFormat = 1
			make/W/u/o/n= ((imwidth), (imHeight)) root:Packages:aTIFFplane
			outMin = 0
			outMax = 2^16-1
		else
			outPutIsSigned =1
			SampleFormat = 2 // signed 16 bit integer
			make/W/o/n= ((imwidth), (imHeight)) root:Packages:aTIFFplane
			outMin = -2^15
			outMax = 2^15-1
		endif
	elseif (outPutType & 0x08) // 8 bit integer
		outPutIsFloat = 0
		sampleBits = 8
		rangeVar =  2^8/(maxVal - minVal)
		if (outPutType & 0x40) // unsigned 8 bit integer
			outPutIsSigned = 0
			SampleFormat = 1
			make/B/u/o/n= ((imwidth), (imHeight)) root:Packages:aTIFFplane
			outMin = 0
			outMax = 2^8-1
		else
			outPutIsSigned =1
			SampleFormat = 2 // signed 8 bit integer
			make/B/o/n= ((imwidth), (imHeight)) root:Packages:aTIFFplane
			outMin = -2^7
			outMax = 2^7-1
		endif
	else
		doalert 0, "Sorry, but the data type for output,\"" + num2str (outPutType) + "\" was not recognized."
		return 1
	endif
	// reference wave we just made
	WAVE aplane =  root:Packages:aTIFFplane
	variable imBytes =  imwidth * imHeight * (sampleBits/8)	// the number of bytes in an individual image plane
	// If no fileName provided, make a name for the exported tiff from the wavename plus the tif extension
	if (paramisDefault (fileNameStr))
		FileNameStr = nameofwave (datawave) + ".TIF"
	else
		fileNameStr = removeending (fileNameStr, ".TIF") +   ".TIF"
	endif
	// Open a new file in the export path directory - file with same name will be overWritten, so test for this BEFORE calling this function
	variable daRefNum  // reference number of the file we will open
	Open/P=$ExportPath/T= "TIFF"  darefNum  as FileNameStr
	// first write the two byte order string "II" for Intel, we always write Intel order because IgorInfo on Igor 5 can't tell Mac PPC from mac Intel and we want to be compatible with 5
	string byteOrderStr = "II"
	FBinWrite/B=3 daRefNum, byteOrderStr 
	// write the magic number 42, in two bytes
	variable temp = 42 // we will use this variable used to hold various values temporarily while writing to the file
	FBinWrite/B=3/F=2/U darefNum, temp
	//write offset to the first IFD unsigned 4 bytes, it will be after this 8 bit header, so 8
	temp = 8
	FBinWrite/B=3/F=3/U darefNum, temp
	//Iterate through each plane in the image, making an image file directory and writing the plane
	// Thus, IFDs and images alternate in the file. One could make a TIFF file with the IFDs all at the start, or
	// any other way you like, this just seemed simplest to me.
	variable ii				// used for iterations through planes in the image
	For (ii = 0; ii < imdepth; ii += 1)
		//write the IFD - start with 2 byte count of number of directories - 14
		temp = 14
		FBinWrite/B=3/F=2/U darefNum, temp
		// now do the tags
		// #1 tag 256 = image width
		temp = 256		
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 4	// Field type 4byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		FBinWrite/B=3/F=3/U darefNum, imwidth
		// #2 tag 257 = image length
		temp = 257		
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 4 	// Field type 4byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1 // number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		FBinWrite/B=3/F=3/U darefNum, imHeight
		// #3 tag 258 = bits/sample
		temp = 258		
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3 	// Field type 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = sampleBits	// number of bits per sample
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #4 tag 259 = compression
		temp = 259		
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3  // Field type 2 byte unsigned integer
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 1 // number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = 1	// 1 = No compression
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #5 tag 262 = photometric interpretation
		temp = 262		
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3		// Field type 3 = 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	//number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = kTiffExportPhotoInt
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #6 tag 273 = strip offsets, we will only make 1 strip, so there is only one offset
		temp = 273		// tag 273 = strip offsets, we will only make 1 strip, so there is only one offset
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 4	// Field type 4 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	//number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		fstatus daRefNum
		temp = V_filePos + 140 // this 4 byte value +  8 more 12 byte tags, plus 4 byte offset to next IFD, plus 20 byte date string plus 8 bytes each of x and Y pixel scaling
		FBinWrite/B=3/F=3/U darefNum, temp
		// #7 tag 277 = samples/pixel
		temp = 277		// tag 277 = samples/pixel
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3	// Field type 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = 1	// 1 sample/pixel, i.e., greyscale image
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #8  tag 278 = rows/strip
		temp = 278		// tag278 = rows/strip we only make 1 strip/image, so this is the same as rows
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3	// Field type 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = imHeight	//1 strip/image, so this is the same as rows
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #9 tag 279 = strip bytecounts
		temp = 279		// tag279 = strip bytecounts (number of bytes in each strip, after compresion)
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 4	// Field type 4 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values  = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		FBinWrite/B=3/F=3/U darefNum, imBytes  // only 1 strip, so byte count is same as bytes in an image
		// #10 tag 282 X resolution
		temp = 282	// tag282 = xResolution, pixels/per res unit
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 5	// Field type 5 Rational - 2 long ints, numerator and denominator, already calculated
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		// 4 byte offset to the rational - this 4 byte value plus 4 more tags (12 bytes each) + 4 byte offset to next IFD + 20 byte date string
		FStatus daRefNum
		temp = V_filePos + 76
		FbinWrite/B=3/F=3/U daRefNum, temp
		// #11 tag 283  y resolution
		temp = 283	// tag283 = y Resolution, pixels/per res unit
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 5	// Field type 5 Rational - 2 long ints, numerator and denominator, already calculated
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		// 4 byte offset to the rational - this 4 byte value plus 3 more tags (12 bytes each) + 4 byte offset to next IFD + 20Byte date String plus X-scaling 8 byte rational
		FStatus daRefNum
		temp = V_filePos + 72
		FbinWrite/B=3/F=3/U daRefNum, temp
		// #12 tag 296 resolution unit - already calculated, 1 for unKnown, 2 for inches, 3 for cm
		temp = 296
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3	// Field type 3 short
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = ResolutionUnit
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #13 tag 306 Date and time of image creation.
		temp = 306
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 2 // Field type = ASCII
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 20	// number of samples = 20
		FBinWrite/B=3/F=3/U darefNum, temp
		// 4 byte offset to the date string - this 4 byte value plus one more tag (12 bytes) + 4 byte offset to next IFD 
		FStatus daRefNum
		temp = V_filePos +20
		FbinWrite/B=3/F=3/U daRefNum, temp
		// #14 tag 339 = Data Sample Format
		temp = 339		// tag339 = Data Sample Format
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3		// Field type 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of samples = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		FBinWrite/B=3/F=2 darefNum, sampleFormat
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// Last thing in the IFD is 4 bytes for offset to start of next IFD (it will be after the image plus date string and rationals for X- and Y-scaling), unless it's the last image plane, when 4 bytes of 0 suffice
		if (ii < imdepth-1)
			FStatus daRefNum
			temp = V_filePos + 40 + imBytes // this 4 byte value + 20 byte date String plus 8 byte rationals for X- and Y-scaling plus size of image
		else
			temp= 0 
		endif
		FBinWrite/B=3/F=3/U darefnum, temp
		// write the date time str
		fbinwrite darefNum, dateStr
		// write the X and Y image resolution
		FBinWrite/B=3/F=3 darefnum, ResNumeratorX
		FBinWrite/B=3/F=3 darefnum, ResDenominatorX
		FBinWrite/B=3/F=3 darefnum, ResNumeratorY
		FBinWrite/B=3/F=3 darefnum, ResDenominatorY
		// finally, write the image plane, frst copy the plane to temp wave aPlane, taking scaling into account
		if ((outPutType == inPutType) && ((Scaling == kTiffExportFullScale) || (outPutIsFloat)))// direct copy
			aplane = datawave [p] [q] [ii]
		else // have min, max and need to use them
			if (outPutisSigned)
				aPlane = max (outMin, min (outMax, (datawave [p] [q] [ii] - minVal) * rangeVar  + outMin))
			else
				aPlane =max (outMin, min (outMax, (datawave [p] [q] [ii] - minVal) * rangeVar))
			endif
		endif
		// write the plane
		FBinWrite/B=3/f =0 darefNum,aplane
	endfor
	//Clean up
	close darefnum
	killwaves/z aplane
	return 0
end

//******************************************************************************************************************
//Exports either a single image in a 3D stack of exactly 3 frames (passed as dataWaveRGB), or members of a trio of 2D or 3D wave each containing either Red, Green, 
// or Blue ( datawaveR, dataWaveG, dataWaveB) as an RGB Color TIFF file. The  OutPut TIFF is always 8 bit unsigned
Function ExportRGBcolorTIFF (ExportPath, Scaling, fileNameStr, [dataWaveRGB, datawaveR, dataWaveG, dataWaveB, minValR, maxValR, minValG, maxValG, minValB, maxValB, timeInSecs])
	String ExportPath //contains the name of an Igor Path where the file will be saved
	variable Scaling  // three methods: 0 = Full Scale according to the input waves' type; 1 means use the Data Range of the input wave; 2 means use provided MinVal and MaxVal"	
	string fileNameStr // the name of the Tiff file that will be made. The extension .tif will be added.
	wave dataWaveRGB, DataWaveR, dataWaveG, dataWaveB //references to 2 or 3d waves with information for each color channel. Must be of same size and type
	variable minValR, maxValR,minValG, maxValG, minValB, maxValB // the minimum and maximum values of the input data to be mapped to the minimum and maximum of the output dataType, if explicit scaling is used
	variable timeInSecs // number of seconds from 1/1/1904 to the time stamp requested for the  tiff file. If no value passed, TIFF creation date is used
	
	// variables for info about the waves and to write to the TIFF
	variable hasRGB =0, hasRed =0, hasGreen=0, hasBlue=0
	variable inPutType, imWidth, imHeight, imDepth, imDims, ResolutionUnit, ResNumeratorX, ResDenominatorX, ResNumeratorY, ResDenominatorY, iW, iH, iByte
	// string for date and time the format in a TIFF file is  "YYYY:MM:DD HH:MM:SS" plus null termination = 20 bytes
	string dateStr
	if (paramISDefault (TimeInSecs))
		timeInSecs = dateTime
	endif
	//see which waves exist
	if ((!(paramisdefault (dataWaveRGB))) && (WaveExists (dataWaveRGB)))
		hasRGB = 1
		TiffWriterGetVariables (dataWaveRGB, timeinSecs, imDims, inPutType, imWidth, imHeight, imDepth, ResolutionUnit, ResNumeratorX, ResDenominatorX, ResNumeratorY, ResDenominatorY, dateStr)
		if ((imDims != 3) || (imDepth != 3))
			doAlert 0, "Only a 3D wave of exactly 3 planes containing Red Blue and Green channels can be used as an RGB wave."
			return 1
		endif
		// Check that min and max have been provided if outPut scaling mode is kProvidedMinMax
		if (Scaling == kTiffExportProvidedMinMax)
			if ((((paramisDefault (minValR)) || (paramisDefault (maxValR))) || ((paramisDefault (minValG)) || (paramisDefault (maxValG)))) ||  ((paramisDefault (minValB)) || (paramisDefault (maxValB))))
				doalert 0, "Sorry, but you need to provide a minimum value and a maximum value for all channels when the Scaling variable is 3."
				return 1
			endif
		endif
	else // not a single RGB wave, but three separate waves for R, G, and B
		if ((!(paramisdefault (datawaveR))) && (WaveExists (DataWaveR)))
			hasRed =1
			// Check that min and max have been provided if outPut scaling mode is kProvidedMinMax
			if ((Scaling == kTiffExportProvidedMinMax) && ((paramisDefault (minValR)) || (paramisDefault (maxValR))))
				doalert 0, "Sorry, but you need to provide a minimum value and a maximum value for all non-default channels when the Scaling variable is 3."
				return 1
			endif
		endif	
		if ((!(paramisdefault (datawaveG))) && (WaveExists (DataWaveG)))
			hasGreen=1
			// Check that min and max have been provided if outPut scaling mode is kProvidedMinMax
			if ((Scaling == kTiffExportProvidedMinMax) && ((paramisDefault (minValG)) || (paramisDefault (maxValG))))
				doalert 0, "Sorry, but you need to provide a minimum value and a maximum value for all non-default channels when the Scaling variable is 3."
				return 1
			endif
		endif
		if ((!(paramisdefault (datawaveB))) && (WaveExists (DataWaveB)))
			hasBlue=1
			// Check that min and max have been provided if outPut scaling mode is kProvidedMinMax
			if ((Scaling == kTiffExportProvidedMinMax) && ((paramisDefault (minValB)) || (paramisDefault (maxValB))))
				doalert 0, "Sorry, but you need to provide a minimum value and a maximum value for all non-default channels when the Scaling variable is 3."
				return 1
			endif
		endif
		if (hasRed + hasGreen + hasBlue < 2)
			doalert 0,  "Sorry, but at least 2 of Red, Green, and Blue channels need to be provided."
			return 1
		endif
		// types and sizes need to be the same for R, G, and B
		variable errVal
		if (hasRed)
			errVal = TiffWriterGetVariables (datawaveR, timeinSecs, imDims, inPutType,imWidth, imHeight, imDepth, ResolutionUnit, ResNumeratorX, ResDenominatorX, ResNumeratorY, ResDenominatorY,dateStr)
			if (ErrVal)
				return 1
			endif
			if (hasGreen)
				if (((((waveType (DataWaveG) != inputType) || (dimsize (DataWaveG, 0) != imWidth)) || (dimsize (DataWaveG, 1) != imHeight)) || (dimsize (DataWaveG, 2) != imDepth)) || (waveDims (DataWaveG) != imDims))
					doalert 0,  "Sorry, but the dimensions and wavetypes of all the input waves must be the same"
					return 1
				endif
			endif
			if (hasBlue)
				if (((((waveType (datawaveB) != inputType) || (dimsize (datawaveB, 0) != imWidth)) || (dimsize (datawaveB, 1) != imHeight)) || (dimsize (datawaveB, 2) != imDepth)) ||  (waveDims (datawaveB) != imDims))
					doalert 0,  "Sorry, but the dimensions and wavetypes of all the input waves must be the same"
					return 1
				endif
			endif
		else
			if (hasGreen)
				errVal = TiffWriterGetVariables (datawaveG, timeinSecs, imDims, inPutType,imWidth, imHeight, imDepth, ResolutionUnit, ResNumeratorX, ResDenominatorX, ResNumeratorY, ResDenominatorY, dateStr)
				if (ErrVal)
					return 1
				endif
				if (hasBlue)
					if (((((waveType (Bwave) != inputType) || (dimsize (datawaveB, 0) != imWidth)) || (dimsize (datawaveB, 1) != imHeight)) || (dimsize (datawaveB, 2) != imDepth)) ||  (waveDims (datawaveB) != imDims))
						doalert 0,  "Sorry, but the dimensions and wavetypes of all the input waves must be the same"
						return 1
					endif
				endif
			endif
		endif
	endif
	//Check the path
	PathInfo $ExportPath
	if (V_Flag == 0)
		if ((cmpStr (ExportPath, "")) == 0)
			ExportPath = "ExportPath"
		endif
		NewPath /M="Where do you want to save the TIFF?" /O/Q ExportPath
		if (V_Flag) // User cancelled the dialog to make new path
			return 1
		endif
	endif
	// More variables for info that will be filled out below
	variable inPutIsSigned // 1  for floats and signed signed integer, 0 for Unsigned integers
	variable  sampleBits // number of bits/per sample (8, 16, or 32)
	// Check type of input wave
	if (inPutType & 0x06) // 32 or 64 bit floating point wave
		inPutIsSigned =1
		// You can't scale min and max of entire floating point range to fill an outPut range, it makes no sense
		if (Scaling == kTiffExportFullScale)
			print "You can't scale min and max of entire input floating point range to fill an outPut range, it makes no sense, so output will be scaled to inPut data range."
			Scaling = kTiffExportDataMinMax
		endif
	elseif (inPutType & 0x20)  // 32 bit integer
		if (inPutType & 0x40) // unsigned 32 bit integer
			inPutIsSigned =0
			if (Scaling == kTiffExportFullScale)
				minValR = 0;minValG=0;minValB=0
				maxValR =2^32-1;maxValG =2^32-1;maxValB=2^32-1
			endif
		else // signed 32 bit integer
			inPutIsSigned =1
			if (Scaling == kTiffExportFullScale)
				minValR = -2^31;minValG = -2^31;minValB = -2^31
				maxValR =2^31-1;maxValG =2^31-1;maxValB =2^31-1
			endif
		endif
	elseif (inPutType & 0x10)  // 16 bit integer
		if (inPutType & 0x40) // unsigned 16 bit integer
			inPutIsSigned =0
			if (Scaling == kTiffExportFullScale)
				minValR = 0;minValG = 0;minValB = 0
				maxValR =2^16-1;maxValG =2^16-1;maxValB =2^16-1
			endif
		else // signed 16 bit integer
			inPutIsSigned =1
			if (Scaling == kTiffExportFullScale)
				minValR = -2^15;minValG = -2^15;minValB = -2^15
				maxValR =2^15-1;maxValG =2^15-1;maxValB =2^15-1
			endif
		endif
	elseif (inPutType & 0x08) // 8 bit integer
		if (inPutType & 0x40) // unsigned 8 bit integer
			inPutIsSigned =0
			if (Scaling == kTiffExportFullScale)
				minValR = 0;minValG = 0;minValB = 0
				maxValR =2^8-1;maxValG =2^8-1;maxValB =2^8-1
			endif
		else // signed 8 bit integer
			inPutIsSigned =1
			if (Scaling == kTiffExportFullScale)
				minValR = -2^7;minValG = -2^7;minValB = -2^7
				maxValR =2^7-1;maxValG =2^7-1;maxValB =2^7-1
			endif
		endif		
	endif
	// If scaling from data range, we need to get minimum and  maximum from data
	if (Scaling == kTiffExportDataMinMax)
		if (hasRGB) // 3 plane wave
			imagestats/Q/M=1/P =0 dataWaveRGB
			minValR = V_min
			maxValR = V_max
			imagestats/Q/M=1/P =1 dataWaveRGB
			minValG = V_min
			maxValG = V_max
			imagestats/Q/M=1/P =2 dataWaveRGB
			minValB = V_min
			maxValB = V_max
		else
			if (hasRed)
				WaveStats/Q/M=1 dataWaveR
				minValR = V_min
				maxValR = V_max
			endif
			if (hasGreen)
				WaveStats/Q/M=1 dataWaveG
				minValG = V_min
				maxValG = V_max
			endif
			if (hasBlue)
				WaveStats/Q/M=1 dataWaveB
				minValB = V_min
				maxValB = V_max
			endif
		endif
	endif
	// Set a rangeVar for each channel for 8 bit export
	variable rangeVarR =  2^8/(maxValR - minValR)
	if (numtype (rangeVarR) != 0)
		rangeVarR =0
	endif
	variable rangeVarG =  2^8/(maxValG - minValG)
	if (numtype (rangeVarG) != 0)
		rangeVarG=0
	endif
	variable rangeVarB =  2^8/(maxValB - minValB)
	if (numtype (rangeVarB) != 0)
		rangeVarB=0
	endif
	// Ensure packages folder in which to make a wave to hold single frame and make a single unsigned 8bit frame 
	if (!(datafolderExists ("root:packages:")))
		newdatafolder root:packages
	endif
	make/B/u/o/n= (imwidth * imheight * 3) root:Packages:aTIFFplane
	// reference wave we just made
	WAVE anRGB =  root:Packages:aTIFFplane
	variable imBytes =  imwidth * imHeight * 3 	// the number of bytes in an individual image plane tmes 3 channels
	//Make a name for the exported tiff from the wavename plus the tif extension
	FileNameStr += ".TIF"
	// Open a new file in the export path directory - file with same name will be overWritten, so test for this BEFORE calling this function
	variable daRefNum  // reference number of the file we will open
	Open/P=$ExportPath/T= "TIFF"  darefNum  as FileNameStr
	// first write the two byte order string "II" for Intel, we always write Intel order because Igor 5 can't tell Mac PPC from mac Intel
	string byteOrderStr = "II"
	FBinWrite/B=3 daRefNum, byteOrderStr 
	// write the magic number 42, in two bytes
	variable temp = 42 // we will use this variable used to hold various values temporarily while writing to the file
	FBinWrite/B=3/F=2/U darefNum, temp
	//write offset to the first IFD unsigned 4 bytes, it will be after this 8 bit header, so 8
	temp = 8
	FBinWrite/B=3/F=3/U darefNum, temp
	//Iterate through each plane in the image, making an image file directory and writing the plane
	// Thus, IFDs and images alternate in the file. One could make a TIFF file with the IFDs all at the start, or
	// any other way you like, this just seemed simplest to me.
	variable ii				// used for iterations through planes in the image
	For (ii = 0; ii < imdepth; ii += 1)
		//write the IFD - start with 2 byte count of number of directories, 15
		temp = 15
		FBinWrite/B=3/F=2/U darefNum, temp
		// #1 tag 256 = image width
		temp = 256		
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 4	// Field type 4byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		FBinWrite/B=3/F=3/U darefNum, imwidth
		// #2 tag 257 = image length
		temp = 257		
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 4 	// Field type 4byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1 // number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		FBinWrite/B=3/F=3/U darefNum, imHeight
		// #3  tag258 = bits/sample
		temp = 258		
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3 	// Field type 3 = 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 3	// number of values = 3, 
		FBinWrite/B=3/F=3/U darefNum, temp
		fstatus daRefNum // offset to number of bits per sample,  // this 4 byte value +  12 more 12 byte tags, plus 4 byte offset to next IFD
		temp = V_filePos + 152
		FBinWrite/B=3/F=3/U darefNum, temp
		// #4 tag 259 = compression
		temp = 259		
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3  // Field type 3 = 2 byte unsigned integer
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 1 // number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = 1	// No compression
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #5 tag 262 = photometric interpretation
		temp = 262		
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3		// Field type 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	//number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = 2	// RGB Color Image
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #6 tag 273 = strip offsets, we will only make 1 strip, so there is only one offset
		temp = 273		// tag 273 = strip offsets, we will only make 1 strip, so there is only one offset
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 4	// Field type 4 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	//number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		FStatus daRefNum // offset to the first and only strip
		temp = V_filePos  + 158 // this 4 byte value + 9 * 12 byte tags, plus 4 byte offset to next IFD, plus 20 byte date string plus 2 * 8 bytes for x and Y pixel scaling, plus 3 * 2 bytes for RGB bits per pixel
		FBinWrite/B=3/F=3/U darefNum, temp
		// # 7 tag 277 = samples/pixel
		temp = 277		// tag 277 = samples/pixel
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3	// Field type 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 3
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = 3	// 3 samples/pixel, i.e., RGB Color image
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// # 8 tag 278 = rows/strip we only make 1 strip/image, so this is the same as rows
		temp = 278		// tag278 = rows/strip we only make 1 strip/image, so this is the same as rows
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3	// Field type 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = imHeight	//1 strip/image, so this is the same as rows
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #9 tag 279 = strip bytecounts (number of bytes in each strip, after compresion)
		temp = 279		// tag279 = strip bytecounts (number of bytes in each strip, after compresion)
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 4	// Field type 4 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values  = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = imBytes * 3   // only 1 strip, so byte count is same as bytes in an image times 3 planes
		FBinWrite/B=3/F=3/U darefNum, temp
		// #10 tag 282 X resolution
		temp = 282	// tag282 = xResolution, pixels/per res unit
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 5	// Field type 5 Rational - 2 long ints, numerator and denominator, already calculated
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		// 4 byte offset to the rational - this 4 byte value plus 5 more tags (12 bytes each) + 4 byte offset to next IFD + 2*3 RGB bits/pixel + 20 byte date string
		FStatus daRefNum
		temp = V_filePos + 94
		FbinWrite/B=3/F=3/U daRefNum, temp
		// #11 tag 283  y resolution
		temp = 283	// tag283 = y Resolution, pixels/per res unit
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 5	// Field type 5 Rational - 2 long ints, numerator and denominator, already calculated
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		// 4 byte offset to the rational - this 4 byte value plus 4 more tags (12 bytes each) + 4 byte offset to next IFD +  2*3 RGB bits/pixel + 20 Byte date String plus X-scaling 8 byte rational
		FStatus daRefNum
		temp = V_filePos + 90
		FbinWrite/B=3/F=3/U daRefNum, temp
		// #12 Tag 284  - planar configuration
		temp = 284
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3		// Field type 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of samples = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = 1 // planar configuration is chunky, red pixel, then green pixel, then blue pixel
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 0  // need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #13 tag 296 resolution unit - already calculated, 1 for unKnown, 2 for inches, 3 for cm
		temp = 296
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3	// Field type 3 short
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of values = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = ResolutionUnit
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// #14 tag 306 Date and time of image creation.
		temp = 306
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 2 // Field type = ASCII
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 20	// number of samples = 20
		FBinWrite/B=3/F=3/U darefNum, temp
		// 4 byte offset to the date string - this 4 byte value plus one more tag (12 bytes) + 4 byte offset to next IFD + 3*2Byte RGB bits/pixel
		FStatus daRefNum
		temp = V_filePos +26
		FbinWrite/B=3/F=3/U daRefNum, temp
		// #15 tag 339 = Data Sample Format
		temp = 339		// tag339 = Data Sample Format
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 3		// Field type 2 byte unsigned integer
		FBinWrite/B=3/F=2/U darefNum, temp
		temp = 1	// number of samples = 1
		FBinWrite/B=3/F=3/U darefNum, temp
		temp = 1 // sample format is always integer for RGB images
		FBinWrite/B=3/F=2 darefNum, temp
		temp = 0	// need to pad with 0
		FBinWrite/B=3/F=2/U darefNum, temp
		// Last thing in the IFD is 4 bytes for offset to start of next IFD (it will be after the image plus 6 bytes for RGB bits/samlpe + date string and rationals for X- and Y-scaling), unless it's the last image plane, when 4 bytes of 0 suffice
		if (ii < imdepth-1)
			FStatus daRefNum
			temp = V_filePos + 46 + imBytes // this 4 byte value + 20 byte date String plus 8 byte rationals for X- and Y-scaling plus size of image
		else
			temp= 0 
		endif
		FBinWrite/B=3/F=3/U darefnum, temp
		// write the 3*2 bytes of bits per sample (always 8)
		temp = 8
		FBinWrite/B=3/F=2/U darefnum, temp
		FBinWrite/B=3/F=2/U darefnum, temp
		FBinWrite/B=3/F=2/U darefnum, temp
		// write the date time str
		fbinwrite darefNum, dateStr
		// write the X and Y image resolution
		FBinWrite/B=3/F=3 darefnum, ResNumeratorX
		FBinWrite/B=3/F=3 darefnum, ResDenominatorX
		FBinWrite/B=3/F=3 darefnum, ResNumeratorY
		FBinWrite/B=3/F=3 darefnum, ResDenominatorY
		// finally, write the image planes red, green, blue
		if ((inPutType == 72) && (Scaling == kTiffExportFullScale))// direct copy
			if (hasRGB)
				for (iH =0, iByte =0; iH < imHeight; iH += 1)
					for (iW = 0; iW < imWidth; iW += 1, iByte += 3)
						anRGB [iByte] = dataWaveRGB [iW] [iH] [0]
						anRGB [iByte + 1] = dataWaveRGB [iW] [iH] [1]
						anRGB [iByte + 2] = dataWaveRGB [iW] [iH] [2]
					endfor
				endfor
			elseif (((hasRed) && (hasGreen)) && (hasBlue))
				for (iH =0, iByte =0; iH < imHeight; iH += 1)
					for (iW = 0; iW < imWidth; iW += 1, iByte += 3)
						anRGB [iByte] = dataWaveR [iW] [iH] [ii]
						anRGB [iByte + 1] = dataWaveG [iW] [iH] [ii]
						anRGB [iByte + 2] = dataWaveB [iW] [iH] [ii]
					endfor
				endfor
			elseif ((hasRed) && (hasGreen))
				for (iH =0, iByte =0; iH < imHeight; iH += 1)
					for (iW = 0; iW < imWidth; iW += 1, iByte += 3)
						anRGB [iByte] = dataWaveR  [iW] [iH][ii]
						anRGB [iByte + 1] = dataWaveG [iW] [iH][ii]
						anRGB [iByte + 2] = 0
					endfor
				endfor
			elseif ((hasRed) && (hasBlue))
				for (iH =0, iByte =0; iH < imHeight; iH += 1)
					for (iW = 0; iW < imWidth; iW += 1, iByte += 3)
						anRGB [iByte] = dataWaveR  [iW] [iH][ii]
						anRGB [iByte + 1] = 0
						anRGB [iByte + 2] = dataWaveB [iW] [iH] [ii]
					endfor
				endfor
			elseif ((hasGreen) && (hasBlue))
				for (iH =0, iByte =0; iH < imHeight; iH += 1)
					for (iW = 0; iW < imWidth; iW += 1, iByte += 3)
						anRGB [iByte] = 0
						anRGB [iByte + 1] =dataWaveG  [iW] [iH][ii]
						anRGB [iByte + 2] = dataWaveB [iW] [iH] [ii]
					endfor
				endfor
			endif
		else // have min, max and need to use them
			if (hasRGB)
				for (iH =0, iByte =0; iH < imHeight; iH += 1)
					for (iW = 0; iW < imWidth; iW += 1, iByte += 3)
						anRGB [iByte] = max (0, min (255, (dataWaveRGB [iW] [iH] [0] - MinValR) * rangeVarR))
						anRGB [iByte + 1] = max (0, min (255, (dataWaveRGB [iW] [iH] [1] - MinValG) * rangeVarG))
						anRGB [iByte + 2] = max (0, min (255, (dataWaveRGB [iW] [iH] [2] - minValB) * rangeVarB))
					endfor
				endfor
			elseif (((hasRed) && (hasGreen)) && (hasBlue))
				for (iH =0, iByte =0; iH < imHeight; iH += 1)
					for (iW = 0; iW < imWidth; iW += 1, iByte += 3)
						anRGB [iByte] = max (0, min (255, (dataWaveR [iW] [iH] [ii]- minValR) * rangeVarR))
						anRGB [iByte + 1] = max (0, min (255, (dataWaveG [iW] [iH][ii] - minValG) * rangeVarG))
						anRGB [iByte + 2] = max (0, min (255, (dataWaveB [iW] [iH][ii] -minValB) * rangeVarB))
					endfor
				endfor
			elseif ((hasRed) && (hasGreen))
				for (iH =0, iByte =0; iH < imHeight; iH += 1)
					for (iW = 0; iW < imWidth; iW += 1, iByte += 3)
						anRGB [iByte] = max (0, min (255, (dataWaveR [iW] [iH][ii] - minValR) * rangeVarR))
						anRGB [iByte + 1] = max (0, min (255, (dataWaveG [iW] [iH] [ii]- minValG) * rangeVarG))
						anRGB [iByte + 2] = 0
					endfor
				endfor
			elseif ((hasRed) && (hasBlue))
				for (iH =0, iByte =0; iH < imHeight; iH += 1)
					for (iW = 0; iW < imWidth; iW += 1, iByte += 3)
						anRGB [iByte] = max (0, min (255, (dataWaveR [iW] [iH] [ii]- minValR) * rangeVarR))
						anRGB [iByte + 1] = 0
						anRGB [iByte + 2] = max (0, min (255, (dataWaveB [iW] [iH][ii] -minValB) * rangeVarB))
					endfor
				endfor
			elseif ((hasGreen) && (hasBlue))
				for (iH =0, iByte =0; iH < imHeight; iH += 1)
					for (iW = 0; iW < imWidth; iW += 1, iByte += 3)
						anRGB [iByte] = 0
						anRGB [iByte + 1] = max (0, min (255, (dataWaveG [iW] [iH] [ii]- minValG) * rangeVarG))
						anRGB [iByte + 2] = max (0, min (255, (dataWaveB [iW] [iH][ii] -minValB) * rangeVarB))
					endfor
				endfor
			endif
		endif
		FBinWrite/B=3/f =0 darefNum,anRGB
	endfor
	//Clean up
	close darefnum
	killwaves/z aplane
	return 0
end

//******************************************************************************************************
// Gets information about the data wave and calculates some variables for the TIFF file
Function TiffWriterGetVariables (datawave, timeinSecs, imDims, inPutType, imWidth, imHeight, imDepth, ResolutionUnit, ResNumeratorX, ResDenominatorX, ResNumeratorY, ResDenominatorY, dateStr)
	WAVE datawave
	variable timeinSecs
	variable &imDims, &inPutType, &imWidth, &imHeight, &imDepth, &ResolutionUnit, &ResNumeratorX, &ResDenominatorX, &ResNumeratorY, &ResDenominatorY
	string &dateStr
	
	// Number of Dimensions
	imdims = waveDims (datawave)
	if (imdims == 1)		
		doalert 0, "Sorry, but you need an image or an image stack to write a tiff file."
		return 1
	else
		if (imdims == 4)
			doalert 0, "Sorry, but this procedure hasn't been extended to 4 dimensions yet"
			return 1
		endif
	endif
	// Input Wave Data Type
	inPutType = waveType (datawave)
	// No Complex waves
	if (inPutType & 0x01)
		doalert 0, "Sorry, but this procedure doesn't do complex waves."
		return 1
	endif
	// dimension sizes
	imwidth = dimsize (datawave, 0)  // the width of the image, in pixels
	imHeight=dimsize (datawave, 1) // the length of the image, in pixels
	imdepth  = max (1, dimsize (datawave, 2))// the image depth, i.e., number of planes
	string imUnits = WaveUnits(datawave, 0 ) // resolution units for TIFF can be 1 no absolute units, 2=inch or 3=cm 
	// Instead of pixel size, image scaling is reported in pixels/ resolution unit, in a special format called RATIONAL, which
	// consists of  2 4 byte integers, used as the numerator and denominator of a fraction. The dec2frac function is in the mathUtil.ipf file
	variable xPixSIze = dimdelta (dataWave, 0)
	variable yPixSize = dimdelta (dataWave, 1)
	ResolutionUnit =1
	ResNumeratorX=1
	ResDenominatorX=1
	ResNumeratorY=1
	ResDenominatorY=1
	if (cmpStr (imUnits, "Inch") == 0)
		ResolutionUnit = 2
		GUIPdec2frac ((1/xPixSIze), ResNumeratorX,ResDenominatorX)
		GUIPdec2frac ((1/yPixSIze), ResNumeratorY, ResDenominatorY)
	elseif ((((cmpStr (imUnits, "m") == 0) || (cmpStr (imUnits, "cm") == 0)) || (cmpStr (imUnits, "mm") == 0)) || (cmpStr (imUnits, num2char (-75) + "m") == 0))
		ResolutionUnit = 3
		if (cmpStr (imUnits, "m") == 0)
			xPixSIze *= 100;yPixSize *= 100
		elseif (cmpStr (imUnits, "mm") == 0)
			xPixSIze /= 10;yPixSize /= 10
		 elseif (cmpStr (imUnits, num2char (-75) + "m") == 0) // um
		 	xPixSIze /= 10000;yPixSize /= 10000
		 endif
		GUIPdec2frac ((1/xPixSIze), ResNumeratorX,ResDenominatorX)
		GUIPdec2frac ((1/yPixSIze), ResNumeratorY, ResDenominatorY)
	endif
	// string for date and time the format in a TIFF file is  "YYYY:MM:DD HH:MM:SS" plus null termination = 20 bytes
	dateStr = Secs2Date(TimeInSecs,-2) [0,9]
	if (Cmpstr (dateStr [4], "-") == 0)
		dateStr = dateStr [0,3] + ":" + dateStr [5,6] + ":" + dateStr [8,9]  + ":" + Secs2Time(dateTime, 3) + num2char (0)
	else
		dateStr = dateStr [6,9] + ":" + dateStr [3,4] + ":" + dateStr [0,1]  + ":" + Secs2Time(dateTime, 3) + num2char (0)
	endif
	return 0
end