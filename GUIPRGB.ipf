#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

#pragma version = 1	 // Last Modified: 2026/09/12 by Jamie Boyd

//*******************************************************************************************************************************************
// gets rgb values from a color table, used, e.g., to color traces in a logical order, with nColors spread evenly over the colorTable
// returns 1 if requested colorTable does not exist, else 0 for success
// Last Modified 2026/09/12 by Jamie Boyd
function GUIPcolorRamp (cTable, iColor, nColors, RGB)
	string cTable // name of an Igor color table. One with a regular progression of colors (Rainbow, Rainbow256, RainbowCycle, etc.) works well
	variable iColor // the number of the current trace to color
	variable nColors // the total number of traces to be colored (or the number at which the cycle of traces should repeat)
	STRUCT RGBColor &RGB
	
	//variable &rVal // pass-by-reference variable to hold red value of returned color
	//variable &gVal // pass-by-reference variable to hold green value of returned color
	//variable &bVal // pass-by-reference variable to hold blue value of returned color
	
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
	variable pos = mod (iColor, nColors) * dimsize (cTableWave, 0)/nColors
	// use mod so color table wraps around if iColor > nColors, as for circular data with a circular colorTable
	RGB.red = cTableWave [pos] [0]
	RGB.green = cTableWave [pos] [1]
	RGB.blue = cTableWave [pos] [2]
	return 0
end

//*******************************************************************************************************************************************
// prints rgb values for a particular color ramp, in case you use them over and over again
// last modified 2015/11/11 by Jamie Boyd
function GUIPprintColorRamp(ctable, nVals)
	string ctable
	variable nVals
	
	variable iVal, rval, gval, bval
	for (iVal =0; iVal < nVals; iVal +=1)
		//GUIPcolorRamp (cTable, ival, nvals, rVal, gVal, bVal)
		printf "for value %d, red, green, blue =( %d, %d, %d)\r", iVal, rVal, gVal, bVal
	endfor
end

//*******************************************************************************************************************************************
// gets rgb values from a color table, scaled from minVal to maxVal
// returns 1 if requested colorTable does not exist, else 0 for success
// Last Modified 2014/07/07 by Jamie Boyd
function GUIPcolorRampScal(cTable, iVal, minVal, maxVal, RGB)
	string cTable // name of an Igor color table. One with a regular progression of colors (Rainbow, Rainbow256, RainbowCycle, etc.) works well
	variable iVal // the Value associated with the current trace to color
	variable minVal // the starting value for the color range
	variable maxVal // the ending value for the color range
	STRUCT RGBColor &RGB
	
	//variable &rVal // pass-by-reference variable to hold red value of returned color
	//variable &gVal // pass-by-reference variable to hold green value of returned color
	//variable &bVal // pass-by-reference variable to hold blue value of returned color
	
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
	pos = round (((iVal - minVal)/(maxVal - minVal)) * dimsize (cTableWave, 0))
	RGB.red = cTableWave [pos] [0]
	RGB.green = cTableWave [pos] [1]
	RGB.blue = cTableWave [pos] [2]
	return 0
end


//******************************************************************************************************
// This function generates red, green, and blue values corresponding to colours that go in sequence around the colour wheel

// We use pass by reference (note the "&") for the colors, because there are three of them and IGOR only lets us
// return a single number to the calling function. 
// We go round the circle at increasingly finer steps to choose an angle which gets translated to a color
// from the color wheel red->purple->blue->cyan->green->chartreuse->yellow->orange->red
// start from a power of 2 to start on a cycle
// start at colourNum = 4 to start on a 4 point cycle aroud the colour wheel
// start at colourNum = 8 to start on an 8 point cycle around the colour wheel
// start at colourNum = 16 to start on an 16 point cycle around the colour wheel
// Last Modified 2026/09/12 by Jamie Boyd
 Function GUIPrgbGetter(colourNum, Red, Green, Blue)
 	variable colourNum
 	variable &Red, &Green, &Blue
 	
 	variable Value = 1
 	variable Saturation = 0.75
 	variable Hue = GUIPrgbGetterAngle (colourNum)
 	variable C = Value*65535
 	variable M = C*(1-Saturation)
 	variable X = (C-M)*(1-abs(mod(Hue/60,2)-1))
    
    if (Hue >= 0 && Hue < 60)
    	Red = C; Green = M; Blue = X+M;
    elseif (Hue >=  60 && Hue < 120)
		Red = X+M; Green = M; Blue = C;
	elseif (Hue >= 120 && Hue < 180)
		Red = M; Green = X+M; Blue = C;
    elseif (Hue >= 180 && Hue < 240)
        Red = M; Green = C; Blue = X+M;
    elseif (Hue >= 240 && Hue < 300)
        Red = X+M; Green = C; Blue = M;
    elseif (Hue >= 300 && Hue <= 360)
        Red = C; Green = X+M; Blue = M;
    endif
 end


//******************************************************************************************************
// returns an angle from 0 - 360. 
// Last Modified 2026/09/12 by Jamie Boyd
function GUIPrgbGetterAngle(nColour)
	variable nColour
	
	if (nColour ==0)
		return 0
	endif
	variable angle
	variable iColour
	variable angleIncr
	variable iCirc 
	for (iColour = 1, iCirc = 0; iColour <= nColour; iCirc +=1)
		for (angleIncr = 360/(2^iCirc), angle = angleIncr/2; angle < 360 ; iColour +=1, angle += angleIncr )
			if (iColour == nColour)
				return angle
			endif
		endfor
	endfor
	return angle
end


//******************************************************************************************************
// makes a graph showing GUIPrgbGetter in action
// Last Modified 2026/09/12 by Jamie Boyd
function GUIPrgbGetterTest(nColours)
	variable nColours
	
	make/o/n= (nColours) colourAngle
	setscale d 0, 0, "°", colourAngle
	make/o/n=((nColours), 3) colourWave
	variable iColour
	variable red, green, blue
	for (iColour = 0; iColour < nColours; iColour +=1 )
		colourAngle [iColour] = GUIPrgbGetterAngle(iColour)
		GUIPrgbGetter(iColour, Red, Green, Blue)
		colourWave [iColour] [0] = Red
		colourWave [iColour] [1] = green
		colourWave [iColour] [2] = blue
	endfor
	
	Display/N=GUIPrgbGetterTestGraph/W=(442,147,1326,516) colourAngle as "GUIP RGB Getter test"
	ModifyGraph gFont="Helvetica"
	ModifyGraph mode=4
	ModifyGraph marker=19
	ModifyGraph msize=5
	ModifyGraph zColor(colourAngle)={colourWave,*,*,directRGB}
	ModifyGraph font="Helvetica"
	ModifyGraph lblMargin(left)=6
	ModifyGraph lblLatPos(left)=-6
	Label left "Colour Angle (\\U)"
	Label bottom "Colour Number"
end