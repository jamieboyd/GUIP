#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma IgorVersion= 6.1
#pragma version= 3.0		//last modified 2025/07/30 by Jamie Boyd

// Provides some tools to deal with fitting graph subwindows within a host window:
// in a matrix of a defined number of columns and rows
// keeping the size of each subwindow the same.
// making the x/y range of each subwindow equivalent. 
// optionaly keeping a fixed aspect ratio of 1 when resizing (good for images in graphs)
// with external control panel to manipulate subwindows

// Code for listing possible arrangements of columns and rows (as for a popupmenu) as well as a popUpmenu procedure to do the rearranging is also
// provided. Both function in the context of the top graph. 
//	PopupMenu GUIPSubWin_PopMenu,proc=GUIPSubWin_ArrangePopMenuProc,title="Arrange "
//	PopupMenu GUIPSubWin_PopMenu,value= #"GUIPSubWin_ListArrangments ()"

//*************************************************************************************************
// Use these 2 graph marquee functions in place of normal shrink and expand when multiple subwindows exist in a single window
Menu "GraphMarquee"
	"Expand SubWindows", /Q, GUIPSubWin_Expand ()
	"Shrink SubWindows", /Q, GUIPSubWin_Shrink ()
end

//***********************************************************************************	
// a structure used to pass arguments to the plotting function, just because there are potentially so many of them
// Last Modified 2025/07/29 by Jamie Boyd
Structure GUIPSubWin_UtilStruct
	string graphName 			// name of graph to use, or to make. If making a graph, and name is taken, actual name will be placed back here
	string graphTitle 			// title of graph
	variable killBehavior		// kill behavior when closed, as defined by Display/k=killBehavior
									//k =0:	Normal with dialog (default).
									//k =1:	Kills with no dialog.
									//k =2:	Disables killing.
									//k =3:	Hides the window.
	variable nSubWins			// number of subwindows being added, max is arbitrarily set at 32. Increase by increasing size of contentStructs array
	STRUCT GUIPSubWin_ContentStruct contentStructs [32]		// content to pass to callback plotting function
	variable nCols 				// number of columns  to use when arranging subwindows - stored in window note
	variable nRows 				// number of rows to use when arranging subwindows - stored in wavenote
	variable prefMoreCols 	// 1 to add another column when adding a subwindow over-flows into a new rows or columns, 0 if prefer more rows
	variable holdAspect 		// set to preserve 1:1 aspect ratio for left and bottom axes when resizing host window, clear to not hold aspect constant
	variable reSizeByWidth	// if holdAspect is on, set to 1 if you want to resize graph by width (dragging from left or right edge), 0 if resizing by height
	variable xStart 			// left point of bottom axis on graph space
	variable xEnd				// right point of bottom axis on graph space
	variable yStart				// bottom point of ledft axis on graph space
	variable yEnd				// top point of ledft axis on graph space
endstructure

//***********************************************************************************	
// a structure to hold data used for callbacks to user's plotting functions
// Last Modified 2025/07/29 by Jamie Boyd
Structure GUIPSubWin_ContentStruct
	string graphName					// name of window to add subwindow to
	string subWin 						// name of subwindow, must be unique
	variable nUserWaves 				// number of waves used, maximum is 32
	WAVE userWaves [32] 				// space for 32 waves to do what you want with
	variable nUserStrings 			// number of strings used, maximum is 32
	string userStrings [32] 			// strings to do what you want with
	variable nUserVariables 			// number of variables used, maximum is 32
	variable userVariables [32] 	// variables to do what you want with
	FUNCREF GUIPSubWin_AddProto addContent  // call back function to add content to this subwindow. 
endstructure

//***********************************************************************************	
// a function prototype for the plotting callback function
// Last Modified 2016/11/03 by Jamie Boyd
function GUIPSubWin_AddProto (s)
	STRUCT GUIPSubWin_ContentStruct &s
end

// ************************************************************************************
// A structure to hold information about the window, stored in named Window user data
// Last Modified 2025/07/29 by Jamie Boyd
Structure GUIPSubWin_WinInfoStruct
	uint16 nCols			// number of columns in the matrix of subwindows
	uint16 nRows			// number of rows in the matrix of subwindows
	float xStart				// X axis start, held the same for all graphs. often 0 for an image
	float xEnd				// X axis end, held the same for all graphs. often pixWidth * xPixSize
	float yStart				// Y axis start, held the same for all graphs.
	float yEnd				// for an image, height x yPixel Size
	uChar holdAspect		// set to hold x-y axes aspect ratio to 1, what you mostly want for images
	uChar prefMoreCols		// when adding subwindows, add a column if matrix is full
	uChar reSizeByWidth
endstructure

//***********************************************************************************	
//Marquee function to expand the axes of multiple subwindow graphs -  This assumes left and bottom axes
// Last Modified 2025/067/03 by Jamie Boyd
Function GUIPSubWin_Expand ()
	// get info from marquee
	GetMarquee/K left, bottom
	string hostWin = stringfromlist (0, S_marqueeWin, "#")
	string graphList =RemoveFromList("controlPanel", childwindowList (hostWin), ";", 0)
	variable nSubWins = itemsinList (graphList)
	// update axis range info in window user data
	STRUCT GUIPSubWin_WinInfoStruct info
	StructGet/S info, GetUserData (hostWin, "", "subwinUtil")
	info.xStart = V_left
	info.xEnd = V_Right
	info.yStart = V_Bottom
	info.yEnd = V_Top
	string infoStr
	StructPut/S info, infoStr
	SetWindow $hostWin userData (subwinUtil) = infoStr
	// update all the subwindows
	variable iSubWin
	string subWinStr
	for (iSubWin =0; iSubWin < nSubWins; iSubWin +=1)
		SubWinStr = hostWin + "#" + stringfromlist (iSubWin, graphList)
		Setaxis/W=$SubWinStr bottom V_left, V_right
		Setaxis /W=$SubWinStr left V_bottom, V_top
	endfor
	// adjust aspect ratio 
	if (info.holdAspect)
		if (info.reSizeByWidth)
			ModifyGraph/w=$hostWin width=0, height={Plan,(((info.yEnd - info.yStart) * info.nRows)/((info.xend - info.xStart) * info.nCols)),left,bottom}
		else
			ModifyGraph/w=$hostWin height=0, width={Plan,(((info.xend - info.xStart) * info.nCols)/((info.yEnd - info.yStart) * info.nRows)),bottom,left}
		endif
	endif
end

//***********************************************************************************	
//Marquee function to shrink the axes of all subwindows in a graph - just for left and bottom axes
// Last Modified 2025/07/29 by Jamie Boyd
Function GUIPSubWin_Shrink ()
	// get info from marquee
	GetMarquee/K left, bottom
	string hostWin = stringfromlist (0, S_marqueeWin, "#")
	string graphList =RemoveFromList("controlPanel", childwindowList (hostWin), ";", 0)	
	variable nSubWins = itemsinList(graphList)
	STRUCT GUIPSubWin_WinInfoStruct info
	StructGet/S info, GetUserData (hostWin, "", "subwinUtil")
	GetAxis/q bottom
	variable axRange = (V_max - V_min)* ((V_max - V_min)/(V_right - V_left))/2
	variable axCenter= V_left +  (V_right-V_left)/2 
	info.xStart = axCenter - axRange
	info.xEnd = axCenter + axRange
	Getaxis/q left
	variable ayRange = (V_max - V_min)* ((V_max - V_min)/(V_top- V_bottom))/2
	variable ayCenter = V_bottom + (V_top - V_bottom)/2
	info.yStart = ayCenter - ayRange
	info.yEnd = ayCenter + ayRange
	
	string infoStr
	StructPut/S info, infoStr
	SetWindow $hostWin userData (subwinUtil) = infoStr
	// update all the subwindows
	variable iSubWin
	string subWinStr
	for (iSubWin =0; iSubWin < nSubWins; iSubWin +=1)
		SubWinStr = hostWin + "#" + stringfromlist (iSubWin, graphList)
		Setaxis/W=$SubWinStr bottom info.xStart, info.xEnd
		Setaxis /W=$SubWinStr left info.yStart, info.yEnd
	endfor
	// adjust aspect ratio 
	if (info.holdAspect)
		if (info.reSizeByWidth)
			ModifyGraph/w=$hostWin width=0, height={Plan,(((info.yEnd - info.yStart) * info.nRows)/((info.xend - info.xStart) * info.nCols)),left,bottom}
		else
			ModifyGraph/w=$hostWin height=0, width={Plan,(((info.xend - info.xStart) * info.nCols)/((info.yEnd - info.yStart) * info.nRows)),bottom,left}
		endif
	endif
end


//***********************************************************************************	
// User code calls this function to make a new host graph, providing a GUIPSubWin_UtilStruct
// containing a GUIPSubWin_ContentStruct for each subwindow to be added
// Last Modified:
// 2025/07/29 by Jamie Boyd - using struct for info and masterX/Y for getting Igor to maintian proper aspect ratio
// 2016/11/15 by Jamie Bod - code to figure out size of Igor frame/monitor size
// 2016/11/07 by Jamie Boyd - put yokedAxes info in window note
function GUIPSubWin_Display (s)
	STRUCT GUIPSubWin_UtilStruct &s
	// make sure packages folder exists
	if (!(dataFolderExists ("root:packages:GUIPsubwin")))
		if (!(DataFolderExists ("root:packages")))
			NewDataFolder root:packages
		endif
		NewDataFolder root:packages:GUIPsubwin
		make root:packages:GUIPsubwin:masterX = {0, 0, 1, 1, 0}
		make root:packages:GUIPsubwin:masterY = {0, 1, 1, 0, 0}
	endif
	WAVE masterX = root:packages:GUIPsubwin:masterX
	WAVE masterY = root:packages:GUIPsubwin:masterY
	//display graph with given title and name (or incremented name, if name is already used)
	Display/N=$s.graphName/K=(s.killBehavior) masterY vs MasterX as s.graphTitle
	// graph name may have needed to be incremented, so update graph name in struct
	s.graphName = S_Name
	// hide master graph traces, these are just used to define a left and right axis for mainitaining aspect ratio when resizing
	ModifyGraph/w=$s.graphName lsize = 0
	ModifyGraph/w=$s.graphName nticks=0
	ModifyGraph/w=$s.graphName margin=1
	// check for consistency in nCols and nRows
	// if nCols and nRows are not set properly, set them to appropriate defaults
	if (s.nSubWins > 0)
		if (((s.nCols == 0) || (s.nRows == 0)) ||  (s.nSubWins > s.nCols * s.nRows))
			s.nCols = ceil (sqrt (s.nSubWins))
			s.nRows = ceil (s.nSubWins/s.nCols)
		endif
	else
		s.nCols =0
		s.nRows =0
	endif
	// set window note for graph with meta-data used to fit subwindows if we later add or remove a subwindow
	STRUCT GUIPSubWin_WinInfoStruct info
	info.nCols = s.nCols
	info.nRows = s.nRows
	info.xStart = s.xStart
	info.xEnd = s.xEnd
	info.yStart = s.yStart
	info.yEnd = s.yEnd
	info.holdAspect = s.holdAspect
	info.prefMoreCols = s.prefMoreCols
	info.reSizeByWidth = s.reSizeByWidth
	// save info in named user data for graph
	string infoStr
	StructPut/S info, infoStr
	SetWindow $s.graphName userdata (subwinUtil) = infoStr
	// add subwindows
	if (s.nSubWins > 0)
		if (s.holdAspect)
			// Set master aspect ratio
			if (s.reSizeByWidth)
				ModifyGraph/w=$s.graphName width=0, height={Plan,(((s.yEnd - s.yStart) * s.nRows)/((s.xend - s.xStart) * s.nCols)),left,bottom}
			else
				ModifyGraph/w=$s.graphName height=0, width={Plan,(((s.xend - s.xStart) * s.nCols)/((s.yEnd - s.yStart) * s.nRows)),bottom,left}
			endif
		else
			ModifyGraph/w=$s.graphName height=0, width=0
		endif
		// add subwindows and add content to each subwindow
		variable xProp = 1/s.nCols, yProp = 1/s.nRows
		variable iSubWin, iCol, iRow, xGraphStart, xgraphEnd, yGraphStart, yGraphEnd
		STRUCT GUIPSubWin_ContentStruct cs
		for (iSubWin =0; iSubWin < s.nSubWins; iSubWin +=1)
			iCol = mod (iSubWin, s.nCols)
			iRow = floor (iSubwin/s.nCols)
			xGraphStart = iCol * xProp
			xGraphEnd = min (0.999, (xGraphStart + xProp))  // because proportions need to be less than 1 or Igor might assume they are points
			yGraphStart = iRow * yProp
			ygraphEnd = min (0.999, (yGraphStart + yProp))
			cs = s.contentStructs [iSubwin]
			Display/N=$cs.subWin/W=(xGraphStart, yGraphStart ,xGraphEnd, ygraphEnd)/HOST=$s.graphName
			SetActiveSubwindow $s.graphName + "#" + cs.subWin
			cs.addContent(cs)
		endfor
	endif
	SetActiveSubwindow ##
	NewPanel/HOST=#/EXT=3/W=(0,50,400,0)  as "Controls"
	PopupMenu arrangePopup, pos={21.00,10.00},size={199.00,20.00},proc=GUIPSubWin_ArrangePopMenuProc
	PopupMenu arrangePopup,title="Arrrange ",fSize=12
	PopupMenu arrangePopup,mode=1,popvalue="1 Column x 3 Rows",value=#"GUIPSubWin_ListArrangments()"
	RenameWindow #,controlPanel
	SetActiveSubwindow ##
end


// *********************************************************************************************
// adds a subwindow to an existig graph
// last modified 2027/07/29 by Jamie Boyd
function GUIPSubWin_Add (cs)
	STRUCT GUIPSubWin_ContentStruct &cs
	// get named user data
	STRUCT GUIPSubWin_WinInfoStruct info
	StructGet/S info, GetUserData (cs.graphName, "", "subwinUtil")
	// list of subwindows, minus control panel
	string prevSubWins = RemoveFromList("controlPanel", childwindowList (cs.graphName), ";", 0)
	variable nSubwins = ItemsinList (prevSubWins)
	variable xGraphStart, xGraphEnd, yGraphStart, yGraphEnd

	
	if (whichListItem (cs.subWin, prevSubWins, ";", 0,0) > -1)
		print "Subwindow with the name \"" + cs.subWin + "\" already exists."
		getwindow $cs.graphName gsizeDC
		variable hostXsize = (V_Right - V_Left), hostYSize = (V_Bottom - V_Top)
		getwindow $cs.graphName + "#" + cs.subWin gsizeDC
		xGraphStart = V_Left/hostXsize
		xGraphEnd = min (0.999, V_Right/hostXsize)
		yGraphEnd = V_Bottom/hostYSize
		yGraphStart = min (0.999, V_Top/hostYSize)
		killWindow $cs.graphName + "#" + cs.subWin
		Display/N=$cs.subWin/W=(xGraphStart, yGraphStart ,xGraphEnd, ygraphEnd)/HOST=$cs.graphName
		SetActiveSubwindow $cs.graphName + "#" + cs.subWin
		cs.addContent(cs)
		SetAxis /W= $cs.graphName + "#" + cs.subWin bottom info.xStart, info.xEnd
		SetAxis /W= $cs.graphName + "#" + cs.subWin left info.yStart, info.yEnd
	else // figure out subwindow position
		variable xProp = 1/info.nCols, yProp = 1/info.nRows
		variable iSubWin, iCol, iRow
		variable colPos, rowPos
		if (nSubwins < (info.nRows * info.nCols))
			iCol = mod (nSubwins, info.nCols)
			iRow = floor (nSubwins/info.nCols)
			xGraphStart = iCol * xProp
			xGraphEnd = min (0.999, (xGraphStart + xProp))  // because proportions need to be less than 1 or Igor might assume they are points
			yGraphStart = iRow * yProp
			ygraphEnd = min (0.999, (yGraphStart + yProp))
			Display/N=$cs.subWin/W=(xGraphStart, yGraphStart ,xGraphEnd, ygraphEnd)/HOST=$cs.graphName
			SetActiveSubwindow $cs.graphName + "#" + cs.subWin
			cs.addContent(cs)
			SetAxis /W= $cs.graphName + "#" + cs.subWin bottom info.xStart, info.xEnd
			SetAxis /W= $cs.graphName + "#" + cs.subWin left info.yStart, info.yEnd
		else  // not enough room in matrix of rows and columns, add a row or column
			if (info.prefMoreCols)
				info.nCols += 1
				xProp = 1/info.nCols
			else
				info.nRows += 1
				yProp = 1/info.nRows
			endif
			string infoStr
			StructPut/S info, infoStr
			SetWindow $cs.graphName userdata (subwinUtil) = infoStr
			//
			if (info.holdAspect)
				if (info.reSizeByWidth)
					ModifyGraph/w=$cs.graphName width=0, height={Plan,(((info.yEnd - info.yStart) * info.nRows)/((info.xend - info.xStart) * info.nCols)),left,bottom}
				else
					ModifyGraph/w=$cs.graphName height=0, width={Plan,(((info.xend - info.xStart) * info.nCols)/((info.yEnd - info.yStart) * info.nRows)),bottom,left}
				endif
			endif
			// reposition  previous subwindows
			for (iSubWin =0; iSubWin < nSubWins; iSubWin +=1)
				iCol = mod (iSubWin, info.nCols)
				iRow = floor (iSubwin/info.nCols)
				xGraphStart = iCol * xProp
				xGraphEnd = min (0.999, (xGraphStart + xProp))  // because proportions need to be less than 1 or Igor might assume they are points
				yGraphStart = iRow * yProp
				ygraphEnd = min (0.999, (yGraphStart + yProp))
				MoveSubWindow /w=$cs.graphName + "#" +stringfromList (iSubWin, prevSubWins, ";"), fnum=(xGraphStart,yGraphStart, xGraphEnd, ygraphEnd)
			endfor
			// add new subwindow at end
			iCol = mod (iSubWin, info.nCols)
			iRow = floor (iSubwin/info.nCols)
			xGraphStart = iCol * xProp
			xGraphEnd = min (0.999, (xGraphStart + xProp))  // because proportions need to be less than 1 or Igor might assume they are points
			yGraphStart = iRow * yProp
			ygraphEnd = min (0.999, (yGraphStart + yProp))
			Display/N=$cs.subWin/W=(xGraphStart, yGraphStart ,xGraphEnd, ygraphEnd)/HOST=$cs.graphName
			SetActiveSubwindow $cs.graphName + "#" + cs.subWin
			cs.addContent(cs)
			SetAxis /W= $cs.graphName + "#" + cs.subWin bottom info.xStart, info.xEnd
			SetAxis /W= $cs.graphName + "#" + cs.subWin left info.yStart, info.yEnd
		endif
	endif
end


//***********************************************************************************	
// Removes a subwindow from an existing graph.
// Last Modified 2027/07/29 by Jamie Boyd
function GUIPSubWin_Remove (graphName, subWin)
	string graphName
	string subWin
	
	// how many subwindows do we already have?
	string graphList = removefromlist ("controlPanel", ChildWindowList(graphName), ";", 0)
	variable nSubwins = itemsinlist (graphList, ";")
	if (whichListItem (subWin, graphList, ";", 0, 0) == -1)
		print "Subwindow with the name \"" + subWin + "\" does not exist."
		return 1
	endif
	killWindow $graphName + "#" + subWin
	graphList = removeFromList(subWin, graphList, ";")
	nSubwins -= 1
	STRUCT GUIPSubWin_WinInfoStruct info
	StructGet/S info, GetUserData (graphName, "", "subwinUtil")
	
	variable matrixChanged =0
	if (info.prefMoreCols)
		if (nSubwins <= (info.nCols-1) * info.nRows)
			info.nCols -= 1
			matrixChanged = 1
		endif
		if (nSubwins <= (info.nCols * (info.nRows-1)))
			info.nRows -=1
			matrixChanged = 1
		endif
	else
		if (nSubwins <= (info.nCols * (info.nRows -1)))
			info.nRows -= 1
			matrixChanged = 1
		endif
		if (nSubwins <= ((info.nCols-1) * info.nRows))
			info.nCols -= 1
			matrixChanged =1
		endif
	endif
	if (matrixChanged)
		if (info.holdAspect)
			if (info.reSizeByWidth)
				ModifyGraph/w=$graphName width=0, height={Plan,(((info.yEnd - info.yStart) * info.nRows)/((info.xend - info.xStart) * info.nCols)),left,bottom}
			else
				ModifyGraph/w=$graphName height=0, width={Plan,(((info.xend - info.xStart) * info.nCols)/((info.yEnd - info.yStart) * info.nRows)),bottom,left}
			endif
		endif
		string infoStr
		StructPut/S info, infoStr
		SetWindow $graphName userdata (subwinUtil) = infoStr
	endif
	variable xProp = 1/info.nCols
	variable yProp = 1/info.nRows
	variable iSubWin, iCol, iRow
	variable xGraphStart, xGraphEnd, yGraphStart, ygraphEnd
	// reposition remaining subwindows
	for (iSubWin =0; iSubWin < nSubWins; iSubWin +=1)
		iCol = mod (iSubWin, info.nCols)
		iRow = floor (iSubwin/info.nCols)
		xGraphStart = iCol * xProp
		xGraphEnd = min (0.999, (xGraphStart + xProp))  // because proportions need to be less than 1 or Igor might assume they are points
		yGraphStart = iRow * yProp
		ygraphEnd = min (0.999, (yGraphStart + yProp))
		MoveSubWindow /w=$graphName + "#" +stringfromList (iSubWin, graphList, ";"), fnum=(xGraphStart,yGraphStart, xGraphEnd, ygraphEnd)
	endfor
End
	
//***********************************************************************************	
// Set Left and Right Axes to full scale for all graph subwindows
// sets min/max of each graph subwindow to min/max of all graphs
// Last Modified 2027/07/29 by Jamie Boyd
Function GUIPSubWin_FullScale(theGraph)
	string theGraph
	// how many subwindows do we have?
	string graphList = removefromlist ("controlPanel", ChildWindowList(theGraph), ";", 0)
	variable nSubwins = itemsinlist (graphList, ";")
	
	STRUCT GUIPSubWin_WinInfoStruct info
	StructGet/S info, GetUserData (theGraph, "", "subwinUtil")

	variable iGraph, nGraphs = itemsinlist (graphList, ";")
	string subWinStr
	//Find global mins and maxs across all the subwindows
	info.xStart = INF; info.xEnd = -INF;info.yStart = INF; info.yEnd = -INF 
	for (iGraph =0; iGraph < nGraphs; iGraph+=1)
		SubWinStr = theGraph +  "#" +  stringfromlist (iGraph, graphList)
		Setaxis/W= $SubWinStr /A left
		Setaxis/W= $SubWinStr /A bottom
		DoUpdate/W=$SubWinStr
		Getaxis/Q/W= $SubWinStr bottom
		info.xStart = min (V_min, info.xStart)
		info.xEnd = max (V_max, info.xEnd)
		Getaxis/Q/W= $SubWinStr left
		info.yStart = min (V_min, info.yStart)
		info.yEnd = max (V_max, info.yEnd)
	endfor
	string infoStr
	StructPut/S info, infoStr
	SetWindow $theGraph userdata (subwinUtil) = infoStr
	for (iGraph =0; iGraph < nGraphs; iGraph+=1)
		SubWinStr = theGraph +  "#" +  stringfromlist (iGraph, graphList)
		Setaxis/W=$SubWinStr bottom info.xStart, info.xEnd
		Setaxis /W=$SubWinStr left info.yStart, info.yEnd
	endfor
	// adjust aspect ratio 
	if (info.holdAspect)
		if (info.reSizeByWidth)
			ModifyGraph/w=$theGraph width=0, height={Plan,(((info.yEnd - info.yStart) * info.nRows)/((info.xend - info.xStart) * info.nCols)),left,bottom}
		else
			ModifyGraph/w=$theGraph height=0, width={Plan,(((info.xend - info.xStart) * info.nCols)/((info.yEnd - info.yStart) * info.nRows)),bottom,left}
		endif
	endif
	return 0
End


Function GUIPSubWin_setGrowMode (GraphName, growMode)
	String GraphName
	variable growMode
	
	
	STRUCT GUIPSubWin_WinInfoStruct info
	StructGet/S info, GetUserData (GraphName, "", "subwinUtil")
	if (growMode < 0)
		info.holdAspect =0
		ModifyGraph/w=$GraphName width=0, height=0
	else
		info.holdAspect =1
		info.reSizeByWidth = (growMode > 0)
		if (info.reSizeByWidth)
			ModifyGraph/w=$GraphName width=0, height={Plan,(((info.yEnd - info.yStart) * info.nRows)/((info.xend - info.xStart) * info.nCols)),left,bottom}
		else
			ModifyGraph/w=$GraphName height=0, width={Plan,(((info.xend - info.xStart) * info.nCols)/((info.yEnd - info.yStart) * info.nRows)),bottom,left}
		endif
	endif
	string infoStr
	structPut/S info, infoStr
	SetWindow SubWinDemoGraph userdata (subwinUtil) = infoStr
	
end




//***********************************************************************************	
// a button procedure to set Left and Right Axes to full scale for all graph subwindows in the top window
// to full range of all data
// Last Modified:
// 2016/11/08 by Jamie Boyd - Yoked scaling info now in window note 
Function GUIPSubWin_FullScaleButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			GUIPSubWin_FullScale(ba.win)
			break
	endswitch

	return 0
End

//*************************************************************************************************
//returns a list of possible arrangements of subwindows based on the number of subwindows
// Last Modified:
// 2016/11/17 by Jamie Boyd - made loop to list possible ways of arranging with no limit
Function/S  GUIPSubWin_ListArrangments ()
	
	string arrangeStr = ""
	variable nSubWins = itemsinlist (RemoveFromList("controlPanel", childwindowList (""), ";", 0), ";")
	if (nSubWins == 0)
		arrangeStr = "\\M1(No subWindows."
	elseif (nSubWins == 1)
		arrangeStr = "1 Column x 1 Row;"
	else
		variable iCols, iRows, halfWay = ceil(sqrt (nSubWins))
		string addStr
		for (iCols =1; iCols < halfWay; iCols +=1)
			iRows = ceil (nSubWIns/iCols)
			addStr= num2str (iCols) + SelectString((iCols == 1) , " Columns",  " Column") + " x "
			addStr += num2str (iRows) + SelectString((iRows == 1) , " Rows", " Row")
			arrangeStr += addStr + ";"
		endfor
		for (iRows = halfWay; iRows > 0; iRows -=1)
			iCols = ceil (nSubWIns/iRows)
			addStr= num2str (iCols) + SelectString((iCols == 1) , " Columns",  " Column") + " x "
			addStr += num2str (iRows) + SelectString((iRows == 1) , " Rows", " Row")
			if (WhichListItem(addStr, arrangeStr, ";", 0, 0) ==-1)
				arrangeStr += addStr + ";"
			endif	
		endfor
	endif
	return arrangeStr
end

//*************************************************************************************************
// re-arranges subwindows to the chosen format, and updates the values stored in the window note
//Last Modified May 10 2010 by Jamie Boyd
Function GUIPSubWin_ArrangePopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			// parse popstr to get chosen columns
			string graphName = stringfromlist (0, pa.win, "#")
			STRUCT GUIPSubWin_WinInfoStruct info
			StructGet/S info, GetUserData (graphName, "", "subwinUtil")
			info.nRows = str2num (stringfromlist (1, pa.popStr, "x"))
			info.nCols = str2num (stringfromlist (0, pa.popStr, "x"))

			string infoStr
			StructPut/S info, infoStr
			SetWindow $graphName userdata (subwinUtil) = infoStr

			variable xProp = 1/info.nCols
			variable yProp = 1/info.nRows
			variable iSubWin, iCol, iRow
			variable xGraphStart, xGraphEnd, yGraphStart, ygraphEnd
			string graphList = RemoveFromList ("controlPanel", ChildWindowList(graphName), ";", 0)
			variable nSubwins = itemsinlist (graphList, ";")
			// reposition remaining subwindows
			for (iSubWin =0; iSubWin < nSubWins; iSubWin +=1)
				iCol = mod (iSubWin, info.nCols)
				iRow = floor (iSubwin/info.nCols)
				xGraphStart = iCol * xProp
				xGraphEnd = min (0.999, (xGraphStart + xProp))  // because proportions need to be less than 1 or Igor might assume they are points
				yGraphStart = iRow * yProp
				ygraphEnd = min (0.999, (yGraphStart + yProp))
				MoveSubWindow /w=$graphName + "#" +stringfromList (iSubWin, graphList, ";"), fnum=(xGraphStart,yGraphStart, xGraphEnd, ygraphEnd)
			endfor
			if (info.holdAspect)
				if (info.reSizeByWidth)
					ModifyGraph/w=$graphName width=0, height={Plan,(((info.yEnd - info.yStart) * info.nRows)/((info.xend - info.xStart) * info.nCols)),left,bottom}
				else
					ModifyGraph/w=$graphName height=0, width={Plan,(((info.xend - info.xStart) * info.nCols)/((info.yEnd - info.yStart) * info.nRows)),bottom,left}
				endif
			endif

			break
	endswitch
	return 0
End


//*************************************************************************************************
//******************************* A simple subwindow example **************************************
//*************************************************************************************************
// Last Modified:
// 2016/11/17 by Jamie Boyd initial version
function GUIPSubWin_demoDisplaySubWins ()
	STRUCT GUIPSubWin_UtilStruct s
	STRUCT GUIPSubWin_ContentStruct cs
	s.graphName = "SubWinDemoGraph"
	s.graphTitle  = "SubWindows are Fun"
	s.killBehavior = 1
	s.nSubWins = 3
	s.nRows = 2
	s.nCols =2
	s.prefMoreCols = 1
	s.reSizeByWidth = 1
	s.holdAspect=1
	s.xStart = 0
	s.xEnd = 20e-05
	s.yStart = 0
	s.yend = 20e-5
	// constant cs values
	cs.graphName = "SubWinDemoGraph"
	funcref GUIPSubWin_AddProto cs.addContent = GUIPSubWin_demoDisplaySubWin
	cs.nUserWaves = 3
	make/o $"root:testSubWin_y"  = {6e-05, 14e-05, 14e-05, 6e-05, 6e-05}
	WAVE cs.userWaves [1] = $"root:testSubWin_y"
	make/o $"root:testSubWin_x"  = {6e-05, 6e-05, 14e-05, 14e-05, 6e-05}
	WAVE cs.userWaves [2] = $"root:testSubWin_x" 
	variable yEnd	
	variable iSubwin
	for (iSubwin =0; iSubWin < 3; iSubWin +=1)
		make/w/u/o/n =(20,20) $"root:testSubWin_Im" + num2str (iSubWin)
		WAVE subWinIm =  $"root:testSubWin_Im" + num2str (iSubWin)
		setscale/p x 0, 1e-05, "m", subWinIm
		setscale/p y 0, 1e-05, "m", subWinIm
		subWinIm = 200 + (1600 * (1 + sin ((p-q- iSubwin)/2) * (cos (q-p + iSubwin)/3))) + enoise (200)
		WAVE cs.userWaves [0] = subWinIm
		cs.subWin = "SubWin" + num2str (iSubWin)
		s.contentStructs [iSubWin] = cs
	endfor
	GUIPSubWin_Display (s)
//	controlbar 40
//	Button fullScaleButton,pos={1.00,1.00},size={76.00,20.00},proc=GUIPSubWin_FullScaleButtonProc,title="Full Scale"
//	PopupMenu GUIPSubWin_PopMenu,pos={87.00,1.00},size={235.00,23.00},proc=GUIPSubWin_ArrangePopMenuProc,title="Arrange Subwindows"
//	PopupMenu GUIPSubWin_PopMenu,mode=2,popvalue="2 columns x 2 rows",value= #"GUIPSubWin_ListArrangments()"
//	Button AddSubWinButton,pos={1.00,19.00},size={76.00,21.00},proc=GUIPSubWin_DemoAddPro,title="Add SubWin"
//	PopupMenu RemoveSubWinPopup,pos={87.00,18.00},size={112.00,19.00},proc=GUIPSubWin_DemoRemoveProc,title="Remove SubWin:"
//	PopupMenu RemoveSubWinPopup,mode=0,value= #"ChildWindowList(\"\" )"
end

// ********************************************************************************************************	
// simple display function. Display functions run with
// proper subwindow already created and brought to front
// so use appendToGraph instead of display
// Last Modified:
// 2016/11/17 by Jamie Boyd - initial version
function GUIPSubWin_demoDisplaySubWin (cs)
	STRUCT GUIPSubWin_ContentStruct &cs

	appendimage cs.userWaves [0]
	appendToGraph cs.userWaves [1] vs cs.userWaves [2]
	modifygraph mode ($nameofWave(cs.userWaves [1])) = 4, marker = 19
	modifygraph margin = 1
end


function GUIPSubWin_demoAddSubWin (subwinName)
	string subwinName
	
	STRUCT GUIPSubWin_ContentStruct cs
	cs.graphName = "SubWinDemoGraph"
	cs.subWin = subwinName
	funcref GUIPSubWin_AddProto cs.addContent = GUIPSubWin_demoDisplaySubWin
	cs.nUserWaves = 3
	make/w/u/o/n =(20,20) $"root:testSubWin_Im" + subwinName
	WAVE subWinIm =  $"root:testSubWin_Im" + subwinName
	setscale/p x 0, 1e-05, "m", subWinIm
	setscale/p y 0, 1e-05, "m", subWinIm
	subWinIm = 200 + (1600 * (1 + sin ((p-q)/2) * (cos (q-p)/3))) + enoise (200)
	WAVE cs.userWaves [0] = subWinIm
	WAVE cs.userWaves [1] = $"root:testSubWin_y"
	WAVE cs.userWaves [2] = $"root:testSubWin_x" 
	GUIPSubWin_Add (cs)
end


function GUIPSubWin_demoRemoveSubWin (subwinName)
	string subwinName
	GUIPSubWin_Remove ("SubWinDemoGraph", subwinName)
end
	


Function GUIPSubWin_DemoRemoveProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			
			GUIPSubWin_Remove ("SubWinDemoGraph", pa.popStr)
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function GUIPSubWin_DemoAddPro(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// Find first free name for child window
			string children = ChildWIndowList ("SubWinDemoGraph")
			variable iChild
			string firstFree = "SubWin0"
			for (iChild =0;whichListItem (firstFree,children, ";", 0,0) > -1 ;iCHild +=1,firstFree ="SubWin" + num2str (iCHild))
			endfor
			
			STRUCT GUIPSubWin_UtilStruct s
			STRUCT GUIPSubWin_ContentStruct cs
			s.graphName = "SubWinDemoGraph"
			s.graphTitle = ""
			s.nSubWins = 1
//			s.aspectRatio = 0.5 // width to height scaling ratio
//			s.yokedAxes = 1
//			s.marginL  = 28
//			s.marginT = 7
//			s.marginR = 7
//			s.marginB = 28
			funcref GUIPSubWin_AddProto cs.addContent = GUIPSubWin_demoDisplaySubWin
			cs.nUserWaves =2
			make/o/n =100 $"root:testSubWin_y" + num2str (iChild)
			make/o/n =100 $"root:testSubWin_x" + num2str (iChild) 
			WAVE cs.userWaves [0] = $"root:testSubWin_y" + num2str (iChild)
			WAVE cs.userWaves [1] = $"root:testSubWin_x" + num2str (iChild)
			// range of Y data roughly 2x that of X data. With aspectRatio 0.5, graphs should be close to square
			cs.userWaves [0] = enoise (12)
			cs.userWaves [1] = 10 + enoise (6)
			cs.subWin = "SubWin" + num2str (iChild)
			s.contentStructs [0] = cs
			GUIPSubWin_Add (cs)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


