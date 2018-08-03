#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma IgorVersion= 6.1
#pragma version= 2.1		//last modified 2016/11/17 by Jamie Boyd

//Provides some tools to deal with fitting graph subwindows within the host window
// and making the content of each subwindow equivalent. 
// 1) Assumptions: all data is plotted on the left and bottom axes
// 2) Subwindows were added in order from left-to-right and top-to-bottom
// 3) number of columns and number of rows of subWindows are stored in key:value; format in window note,
// with the keys being nCols and nRows. AspRat= 0 if ignoring aspect ratio, else whatever you want it fixed to

// Code for a listing possible arrangements (as for a popupmenu) as well as the popUpmenu procedure to do the rearranging is also
// provided. Both function in the context of the top graph. Name the popupmenu GUIPSubWin_PopMenu. and have its proc and value as:
//	PopupMenu GUIPSubWin_PopMenu,proc=GUIPSubWin_ArrangePopMenuProc,title="Arrange "
//	PopupMenu GUIPSubWin_PopMenu,value= #"GUIPSubWin_ListArrangments ()"

//*************************************************************************************************
// Use these 2 graph marquee functions in place of normal shrink and expand when multiple subwindows exist in a single window
Menu "GraphMarquee"
	"Expand SubWindows", /Q, GUIPSubWin_Expand ()
	"Shrink SubWindows", /Q, GUIPSubWin_Shrink ()
end

//***********************************************************************************	
//Marquee function to expand the axes of multiple subwindow graphs -  This only works for  left and bottom axes
// Last Modified 2016/11/03 by Jamie Boyd
Function GUIPSubWin_Expand ()
	
	GetMarquee/K left, bottom
	string baseName = stringfromlist (0, S_marqueeWin, "#")
	string graphList = ChildWindowList(baseName)
	if (cmpstr (graphList, "") == 0)
		Setaxis bottom V_left, V_right
		Setaxis left V_bottom, V_top
	else
		variable ii, nGraphs = itemsinlist (graphList, ";")
		string subWinStr
		for (ii =0; ii < nGraphs;ii+=1)
			SubWinStr = baseName + "#" + stringfromlist (ii, graphList)
			Setaxis/W=$SubWinStr bottom V_left, V_right
			Setaxis /W=$SubWinStr left V_bottom, V_top
		endfor
		GUIPSubWin_FitSubWindows (baseName)
	endif
end

//***********************************************************************************	
//Marquee function to shrink the axes of all subwindows in a graph - just for left and bottom axes
// Last Modified 2016/11/03 by Jamie Boyd
Function GUIPSubWin_Shrink ()
	
	GetMarquee/K left, bottom
	string baseName = stringfromlist (0, S_marqueeWin, "#")
	string graphList = ChildWindowList(baseName)
	// get axis values for left and right axis from active subwindow only - We'll assume they are all the same
	GetAxis/q bottom
	variable axRange = (V_max - V_min)* ((V_max - V_min)/(V_right - V_left))/2
	variable axCenter= V_left +  (V_right-V_left)/2 
	Getaxis/q left
	variable ayRange = (V_max - V_min)* ((V_max - V_min)/(V_top- V_bottom))/2
	variable ayCenter = V_bottom + (V_top - V_bottom)/2
	if (cmpstr (graphList, "") == 0)
		Setaxis bottom axCenter-axRange , axCenter + axRange
		Setaxis left ayCenter-ayRange , ayCenter + ayRange
	else
		variable ii, nGraphs = itemsinlist (graphList, ";")
		string subWinStr
		for (ii = 0; ii < nGraphs;ii+=1)
			SubWinStr =  baseName +  "#" + stringfromlist (ii, graphList)
			Setaxis/W= $SubWinStr bottom axCenter-axRange , axCenter + axRange
			Setaxis /W= $SubWinStr left ayCenter-ayRange , ayCenter + ayRange
		endfor
		GUIPSubWin_FitSubWindows (baseName)
	endif
end

//***********************************************************************************	
// sets the aspect ratio stored in the window note
// Call GUIPSubWin_FitSubWindows (graphName) to apply new setting for Aspect Ratio
// Last Modified 2016/11/03 by Jamie Boyd
Function GUIPSubWin_SetAspRat (graphName, AspRat)
	String graphName
	variable AspRat
	
	Getwindow $graphName note
	S_Value = ReplaceNumberByKey("AspRat", S_Value, AspRat, ":", ";")
	SetWindow $graphName note = S_Value
end

//***********************************************************************************	
// a structure used to pass variables to the different functions
// Last Modified 2016/11/03 by Jamie Boyd
Structure GUIPSubWin_UtilStruct
	string graphName // name of graph to use, or to make. If making a graph, and name is taken, actual name will be placed back here
	string graphTitle // if making a new graph, title of graph
	variable killBehavior // if making a new graph, kill behavior when closed, as defined by Display/k=killBehavior
						//k =0:	Normal with dialog (default).
						//k =1:	Kills with no dialog.
						//k =2:	Disables killing.
						//k =3:	Hides the window.
	variable nSubWins // number of subwindows  being added, max is arbitrarily set at 32. Increase by increasing size of contentStructs array
	STRUCT GUIPSubWin_ContentStruct contentStructs [32] // content to pass to callback plotting function
	FUNCREF GUIPSubWin_AddProto addContent  // call back function to add content to each subwindow. 
	variable wLeft // if making a new graph, left position of main graph
	variable wTop // if making a new graph, top position of main graph
	variable wBottom // if making a new graph, right position of main graph
	variable wRight // if making a new graph, bottom position of main graph
	variable nCols // number of columns  to use when arranging subwindows - stored in window note
	variable nRows // number of rows to use when arranging subwindows - stored in wavenote
	variable prefMoreCols // 1 if prefer more columns when adding more rows or columns, 0 if prefer more rows
	variable aspectRatio // pass 1, e.g., to preserve 1:1 aspect ratio for left and bottom axes, pass 0 to not hold aspect constant
	variable maxWidth // maximum width you would like the grpah to be allowed to grow to, or 0 to not limit width, or -1 to limit monitor/Igor frame size
	variable maxHeight // maximum height you would like the graph to be able to expand to, or 0 to not limit height, or -1 to limit to monitor/Igor frame size
	variable yokedAxes // 1 to keep each subwindow with same horizontal and vertical range and scaling, 0 to set each subwindow independently
	variable marginL // graph margins (left, top, right, bottom) - default margins are difficult to deal with, a size changes so much
	variable marginT
	variable marginR
	variable marginB
endstructure

//***********************************************************************************	
// a structure to hold data used for callbacks to user's plotting functions
// Last Modified 2016/11/03 by Jamie Boyd
Structure GUIPSubWin_ContentStruct
	string subWin // name of subwindow
	variable iSubWin // plotting order of subwindow; will be filled in by GUIPSubWin when plotting. Probbaly not very useful
	variable nUserWaves // number of waves used, maximum is 32
	WAVE userWaves [32] // waves to do what you want with
	variable nUserStrings // number of strings used, maximum is 32
	string userStrings [32] // strings to do what you want with
	variable nUserVariables // number of variables used, maximum is 32
	variable userVariables [32] // variables to do waht you want with
endstructure

//***********************************************************************************	
// a function prototype for the plotting callback function
// Last Modified 2016/11/03 by Jamie Boyd
function GUIPSubWin_AddProto (s)
	STRUCT GUIPSubWin_ContentStruct &s
end

//***********************************************************************************	
// User code calls this function to make a new host graph, providing a GUIPSubWin_UtilStruct
// containing a GUIPSubWin_ContentStruct for each subwindow to be added
// GUIPSubWin_Display makes a new host graph, and adds subwindows with user's content,
// by calling GUIPSubWin_Add which in turn calls the users plotting function, then
// sets window Note for Subwindow metadata, and setshook function for resizing
// Last Modified:
// 2016/11/15 by Jamie Bod - code to figure out size of Igor frame/monitor size
// 2016/11/07 by Jamie Boyd - put yokedAxes info in window note
function GUIPSubWin_Display (s)
	STRUCT GUIPSubWin_UtilStruct &s
	
	//display graph in given position, with given title and name (or incremented name, if name is already used)
	Display/N=$s.graphName/W=(s.wLeft,s.wTop, s.wRight,s.wBottom)/K=(s.killBehavior) as s.graphTitle
	// graph name may have needed to be incremented, so update graph name in struct
	s.graphName = S_Name
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
	// check for limiting to monitor/Igor frame
	if ((s.maxWidth == -1) || (s.maxHeight == -1))
		if( CmpStr(IgorInfo(2)[0,2],"Win")==0) // Application Frame on Windows
			getwindow kwFrameInner wsize
			s.maxWidth =( V_right - V_left)
			s.MaxHeight = V_bottom - V_top - 40
		else // need to do add flexibility for using more than one screen on a Mac. For now, just use bounds of biggest screen
			variable iScreen, nScreens = numberbykey ("NSCREENS", IgorInfo (0), ":", ";")
			s.maxHeight = 0
			s.maxWidth = 0
			string screenStr
			for (iScreen = 1; iScreen <= nScreens; iScreen +=1)
				// This is ugly. stringbykey ("SCREEN1", IgorInfo (0), ":", ";")  gives this string "DEPTH=32,RECT=0,0,1280,800" where the separator
				// between Key/Value pairs, ",",  is same as as that between items in the RECT list. StringByKey with "RECT" would thus truncate the list to 
				// its first element. So we replace the first "," we find with a space so that the Key/Value pair separator and the list separator are different.
				screenStr = StringByKey ("RECT", ReplaceString(",", stringbykey ("SCREEN" + num2str (iScreen), IgorInfo (0), ":", ";"), " ", 0,1), "=", " ")
				s.maxWidth  = max (s.maxWidth, (str2num (stringfromlist (2, screenStr, ",")) -  str2num (stringfromlist (0, screenStr, ","))))
				s.maxHeight = max (s.maxHeight, (str2num (stringfromlist (3, screenStr, ",")) -  str2num (stringfromlist (1, screenStr, ","))))
			endfor
			s.maxHeight -= 40
		endif
	endif
	// set window note for graph with meta-data used to fit subwindows
	SetWindow $s.graphName note = "nCols:" + num2str (s.nCols) + ";nRows:" + num2str (s.nRows) + ";yokedAxes:" + num2str (s.yokedAxes)
	SetWindow $s.graphName note += ";AspRat:" + num2str(s.aspectRatio) + ";maxHeight:" + num2str (s.maxHeight)
	SetWindow $s.graphName note += ";maxWidth:" + num2str (s.maxWidth) + ";NeedsResize:1;"
	// add subwindows and add content to each subwindow
	if (s.nSubWins > 0)
		GUIPSubWin_Add (s)
	endif
	// make sure packages folder exists, and add variable for this graph
	if (!(dataFolderExists ("root:packages:GUIPsubwin")))
		if (!(DataFolderExists ("root:packages")))
			NewDataFolder root:packages
		endif
		NewDataFolder root:packages:GUIPsubwin
	endif
	variable/G $"root:packages:GUIPsubwin:" + cleanUpName (s.graphName, 0) + "_lastResize" = -1 // code for never updated
	// set hook function to do resizing when graph is resized
	SetWindow $s.graphName hook (resiseSubWinsHook)= GUIPSubWin_ResizeHook
end

//***********************************************************************************	
// Adds subwindows to an existing graph.
// Last Modified:
// 2016/11/14 by Jamie Boyd fixed problems with adding subwins to empty graphs
function GUIPSubWin_Add (s)
	STRUCT GUIPSubWin_UtilStruct &s
	
	// how many subwindows do we already have?
	string graphList = ChildWindowList(s.graphName)
	variable prevSubWins = itemsinlist (graphList, ";")
	// If scaling is to be same for all subwins, find out current axes ranges to apply to added subwindows
	// assume first subwindow has same scaling as all the rest
	variable Bmin, Bmax, Lmin, Lmax
	if ((s.yokedAxes) && (prevSubWins > 0))
		string SubWinStr = s.graphName +  "#" +  stringfromlist (0, graphList)
		DoUpdate/W=$SubWinStr
		Getaxis/Q/W= $SubWinStr bottom
		Bmin = V_min
		Bmax = V_max
		Getaxis/Q/W= $SubWinStr left
		Lmin = V_min
		Lmax = V_Max	
	endif
	// iterate through subwindows
	variable iSub
	for (iSub =0; iSub < s.nSubWins; iSub +=1)
		if (whichListItem (s.contentStructs [iSub].subWin, graphList, ";") > -1)
			print "Subwindow with the name \"" + s.contentStructs [iSub].subWin + "\" already exists."
			continue
		endif
		Display/N=$s.contentStructs[iSub].subWin/W=(0 ,0,1,1)/HOST=$s.graphName
		// tell user function the subwindow number
		s.contentStructs [iSub].iSubWin =prevSubWins +  iSub
		// run the user's function to add content
		SetActiveSubwindow $s.graphName + "#" + s.contentStructs[iSub].subWin
		s.addContent(s.contentStructs [iSub])
		if ((s.yokedAxes) && (prevSubWins > 0))// set axis to match current axes
			setaxis bottom, BMin, BMax
			setaxis left, Lmin, LMax
		endif
		// set margins
		modifygraph margin (left) = s.marginL, margin (top) = s.marginT, margin (right) = s.marginR, margin (bottom) = s.marginB
	endfor	
	// possibly change window title
	if (cmpstr (s.graphTitle, "") != 0)
		DoWindow /T$ s.graphName, s.graphTitle
	endif
	// change window note, adding the window may have changed the arrangement
	Getwindow $s.graphName note
	s.nSubWins = itemsinList (ChildWindowList(s.graphName), ";")
	variable nCols, nRows
	if ((s.nCols > 0) && (s.nRows > 0))
		nCols = s.nCols
		nRows = s.nRows
	else
		nCols = NumberByKey("nCols", S_Value, ":", ";")
		nRows = NumberByKey("nRows", S_Value, ":", ";")
	endif
	// If not enough rows and colmns, add another row, then another column, etc, till rows X cols is big enough
	if (nRows * nCols <   s.nSubWins)
		variable addCol =s.prefMoreCols
		do
			if (addCol == 0)
				nRows += 1
				addCol =1
			else
				nCols += 1
				addCol =0
			endif
		while (nCols * nRows <   s.nSubWins)
	endif
	s.nRows = nRows
	s.nCols = nCols
	S_Value = ReplaceNumberByKey("nCols", S_Value, s.nCols, ":", ";")
	S_Value = ReplaceNumberByKey("nRows", S_Value, s.nRows, ":", ";")
	// if new setting for aspect ratio is given, update info in window note
	if (numtype (s.aspectRatio) == 0)
		S_Value = ReplaceNumberByKey("AspRat", S_Value, s.aspectRatio, ":", ";")
	endif
	if ((s.maxHeight > 0) && (s.maxWidth > 0))
		S_Value = ReplaceNumberByKey("maxHeight", S_Value, s.maxHeight, ":", ";")
		S_Value = ReplaceNumberByKey("maxWidth", S_Value, s.maxWidth, ":", ";")
	endif
	SetWindow $s.graphName note = S_Value
	// do a resize
	if (prevSubWins == 0)
		// Set full scale if no previous content
		GUIPSubWin_FullScale(s.graphName)
	else
		GUIPSubWin_FitSubWindows (s.graphName )
	endif
	// Update popMenu, if it exists
	controlinfo/W=$s.graphName GUIPSubWin_PopMenu
	if (V_Flag != 0)
		if (s.nSubWins == 0)
			popupmenu GUIPSubWin_PopMenu win=$s.graphName, mode = 1
		else	
			string arrangeList =  GUIPSubWin_ListArrangments()
			string arrangeStr = num2str (nCols) +  SelectString((nCols==1) , " Columns x ", " Column x ")+ num2str (nRows) + SelectString ((nRows ==1),  " Rows", " Row")
			variable theItem = whichlistItem (arrangestr,arrangeList, ";")
			if (theItem > -1)
				popupmenu GUIPSubWin_PopMenu mode = 1 + whichlistItem (arrangestr, GUIPSubWin_ListArrangments())
			endif
		endif
	endif
end

//***********************************************************************************	
// Removes subwindows from an existing graph.
// Last Modified May 10 2010 by Jamie Boyd
function GUIPSubWin_Remove (s)
	STRUCT GUIPSubWin_UtilStruct &s
	
	// how many subwindows do we already have?
	string graphList = ChildWindowList(s.graphName)
	variable prevSubWins = itemsinlist (graphList, ";")
	// iterate through requested subwindows, killing them
	variable iSub
	for (iSub =0; iSub < s.nSubWins; iSub +=1)
		if (whichListItem (s.contentStructs [iSub].subWin, graphList, ";") == -1)
			print "Subwindow with the name \"" + s.contentStructs [iSub].subWin + "\" does not exist."
			continue
		endif
		killWindow $s.graphName + "#" + s.contentStructs [iSub].subWin
	endfor
	// do we need to adjust column and row numbers?
	// change window note, adding the window may have changed the arrangement
	Getwindow $s.graphName note
	s.nSubWins = itemsinList (ChildWindowList(s.graphName), ";")
	if (s.nSubWins > 0)
		variable nCols, nRows
		if ((s.nCols >0) && (s.nRows > 0))
			nCols = s.nCols
			nRows = s.nRows
		else
			nCols = NumberByKey("nCols", S_Value, ":", ";")
			nRows = NumberByKey("nRows", S_Value, ":", ";")
		endif
		for(;(nRows * (nCols -1) >=   s.nSubWins) || (((nRows-1) * nCols) >=  s.nSubWins);)
			if (s.prefMoreCols)
				if (((nRows-1) * nCols) >= s.nSubWins)
					nRows -=1
				endif
		
				if (nRows * (nCols -1) >= s.nSubWins)
					nCols-=1
				endif
			else
				if (nRows * (nCols -1) >= s.nSubWins)
					nCols-=1
				endif
				if (((nRows-1) * nCols) >= s.nSubWins)
					nRows -=1
				endif
			endif
		endfor
		s.nRows = nRows
		s.nCols = nCols
		S_Value = ReplaceNumberByKey("nCols", S_Value, s.nCols, ":", ";")
		S_Value = ReplaceNumberByKey("nRows", S_Value, s.nRows, ":", ";")
		SetWindow $s.graphName note = S_Value
	endif
	// Update popMenu, if it exists
	controlinfo/w=$s.graphName GUIPSubWin_PopMenu
	if (V_Flag != 0)
		if (s.nSubWins == 0)
			popupmenu GUIPSubWin_PopMenu win=$s.graphName, mode = 1
		else	
			string arrangeStr = num2str (nCols) +  SelectString((nCols==1) , " Columns x ", " Column x ")+ num2str (nRows) + SelectString ((nRows ==1),  " Rows", " Row")
			variable theItem = whichlistItem (arrangestr, GUIPSubWin_ListArrangments())
			if (theItem > -1)
				popupmenu GUIPSubWin_PopMenu win=$s.graphName, mode = 1 + whichlistItem (arrangestr, GUIPSubWin_ListArrangments())
			endif
		endif
	endif
	// do a resize
	if (s.nSubWins > 0)
		GUIPSubWin_FitSubWindows (s.graphName)
	endif
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

//***********************************************************************************	
// Set Left and Right Axes to full scale for all graph subwindows
// if scaling is "Yoked" set min/max of each graph subwindow to min/max of all graphs
// else set min/max for each graph subwindow separately
// Last Modified:
// 2016/11/07 by Jamie Boyd - yoked Scaling info now in window Note
Function GUIPSubWin_FullScale(theGraph)
	string theGraph
	
	if (strsearch(theGraph, "#", 0) > -1)
		theGraph = stringFromList (0, theGraph, "#")
	endif
	Getwindow $theGraph note
	variable yokedAxes = NumberByKey("yokedAxes", S_Value, ":", ";")
	
	string graphList = ChildWindowList(theGraph)
	if (cmpstr (graphList, "") == 0)
		return 1
	endif
	
	variable iGraph, nGraphs = itemsinlist (graphList, ";"), xMin = INF, xMax = -INF, yMin = INF, yMax = -INF
	string subWinStr
	//Find global mins and maxs across all the subwindows
	for (iGraph =0; iGraph < nGraphs; iGraph+=1)
		SubWinStr = theGraph +  "#" +  stringfromlist (iGraph, graphList)
		Setaxis/W= $SubWinStr /A left
		Setaxis/W= $SubWinStr /A bottom
		DoUpdate/W=$SubWinStr
		if (yokedAxes)
			Getaxis/Q/W= $SubWinStr bottom
			xMin = min (V_min, xMin)
			xMax = max (V_max, xmax)
			Getaxis/Q/W= $SubWinStr left
			yMin = min (V_min, yMin)
			yMax = max (V_max, ymax)
		endif
	endfor
	if (yokedAxes)
		for (iGraph =0; iGraph < nGraphs; iGraph += 1)
			SubWinStr = theGraph +  "#" +  stringfromlist (iGraph, graphList)
			Setaxis/W= $SubWinStr bottom, xMin, xMax
			Setaxis/W= $SubWinStr left, yMin, yMax
		endfor
	endif
	GUIPSubWin_FitSubWindows (theGraph)
	return 0
End

//***********************************************************************************	
// a Hook function that fires when a graph window has just been resized/modified
// initially sets a background task that calls ImageFitSubwindows when user is done resizing the graph
// then resets the global variable for time of last call to resize
// Last modified:
// 2016/11/17 by Jamie Boyd - modified global variable for each graph
Function GUIPSubWin_ResizeHook(s)
	STRUCT WMWinHookStruct &s
	
	if (s.eventCode == 6)
		string theGraph = s.winName
		if (strsearch(theGraph, "#", 0) > -1)
			theGraph = stringFromList (0, theGraph, "#")
		endif
		Getwindow $theGraph note
		NVAR lastResize =  $"root:packages:GUIPsubwin:" + cleanUpName (s.winName, 0) + "_lastResize"
		if (lastResize == -1)
			S_Value = ReplaceNumberByKey("NeedsResize", S_Value, 1, ":", ";") 
			SetWindow $theGraph note = S_Value
			// the background task is named for the window, so we can get the window name from within the task
			CtrlNamedBackground $theGraph, period = 10, proc= GUIPSubWin_RefitBKG, start
		endif
		lastResize = ticks
	endif
	return 0		// 0 if nothing done, else 1
End

//***********************************************************************************	
// This is the function that will be called periodically to see if the last resize event was
// more than 20 ticks ago, and calls ImageFitSubwindows and exits if that is the case
// Last modified:
// 2016/11/17 by Jamie Boyd - improved handling of gloval variable for the graph
Function GUIPSubWin_RefitBKG(s)
	STRUCT WMBackgroundStruct &s
	
	NVAR lastResize =  $"root:packages:GUIPsubwin:" + cleanUpName (s.name, 0) + "_lastResize"
	if ((lastResize > 0) && (s.curRunticks > lastResize + 20))
		Getwindow $s.name note
		if (NumberByKey("NeedsResize", S_Value, ":", ";") == 1)
			GUIPSubWin_FitSubWindows (s.name)
		endif
		lastResize = -1
		return 1
	endif
	return 0
end

//***********************************************************************************	
//Resizes the subwindows in a graph, assuming they should all be the same size and with same aspect ratio and neatly arranged in a grid.
// Get size of the graph, figure out the matrix, resize and move subwindows to best fill space, resize the graph window on the slack dimension
// Last modified:
// 2016/11/07 by Jamie Boyd - 
Function GUIPSubWin_FitSubWindows (theGraph)
	string theGraph
	
	DoUpdate /w= $theGraph
	// control bar heights and panel measures are in pixels wheras graph wsize is in points
	// on MacOS pixels and points are the same (72 per inch) but can vary on windows
	variable winFudge = (ScreenResolution/72) 
	// read info from window note
	Getwindow $theGraph note
	variable nCols = numberbykey ("nCols",  S_Value, ":",";")
	variable nRows =numberbykey ("nRows",  S_Value, ":",";")
	variable AspectRatio = numberbykey ("AspRat",  S_Value, ":",";") // vertical scaling/ horizontal sclaing
	variable maxWidth = numberbykey ("maxWidth",  S_Value, ":",";")
	variable maxHeight = numberbykey ("maxHeight",  S_Value, ":",";")
	variable yokedAxes = NumberByKey("yokedAxes", S_Value, ":", ";")
	// set NeedsResize code to 0 to prevent update recursion from hook function
	S_Value = ReplaceNumberByKey("NeedsResize", S_Value, 0, ":", ";")
	SetWindow $theGraph note = S_Value
	//get list of subwindows
	string graphList = ChildWindowList(theGraph)
	variable iGraph, nGraphs = itemsinList (graphList, ";")
	if (nGraphs == 0)
		return 1
	endif
	//get size of the main graph window - account for controlBar on top of graph
	GetWindow $theGraph wsize
	ControlInfo /W=$theGraph kwControlBar // maybe expand this to exclude control bars on other sides of graph
	variable sL = V_left
	variable sT = V_top + V_height/winFudge
	variable sR =  V_right
	variable sB = V_bottom
	// calculate main graph height and width
	variable graphHeight, graphWidth, maxSubGraphWidth, maxSubGraphHeight
	graphHeight = sB -sT
	graphWidth = sR - sL
	if (maxWidth == 0)
		maxSubGraphWidth = INF
	else
		maxSubGraphWidth = maxWidth/nCols
	endif
	if (maxHeight ==0)
		maxSubGraphHeight = INF
	else
		maxSubGraphHeight = maxHeight/nRows
	endif
	variable bottomRange, leftRange, newSubGraphWidth, newSubGraphHeight
	variable newSubGraphWidthByWidth, newSubGraphHeightByWidth, byWidthProp
	variable newSubGraphWidthByHeight, newSubGraphHeightByHeight, byHeightProp
	if (AspectRatio == 0) // ignoring aspect ratio, apportion space regardless of relative range of left and bottom axes
		newSubGraphWidth = min (graphWidth/nCols, maxSubGraphWidth)
		newSubGraphHeight = min (graphHeight/nRows, maxSubGraphHeight)
	else //get axes ranges and margins of the first subwindow - assume all subwindows have the same ranges and margins
		GetAxis/w= $theGraph + "#" + stringfromList (0, graphList)/q bottom
		bottomRange= abs ((V_max - V_min))
		GetAxis/w= $theGraph + "#" + stringfromList (0, graphList)/q left
		leftRange= abs ((V_max - V_min))
		// Get margins - similar ugly way to use stringbykey as used for IgorInfo above. If getting margins fails, use 28 as an average value
		string marginStr= ReplaceString(" ", WinRecreation(theGraph + "#" + stringfromList (0, graphList), 0), ",")
		marginStr = ReplaceString("\r", marginStr, ",")
		variable lostBottom = NumberByKey("margin(left)", marginStr, "=", ",") + NumberByKey("margin(right)", marginStr, "=", ",")
		variable lostLeft= NumberByKey("margin(top)", marginStr, "=", ",") + NumberByKey("margin(bottom)", marginStr, "=", ",")
		lostLeft = numtype (lostLeft) == 0 ? lostLeft : 28
		lostBottom = numtype (lostBottom) == 0 ? lostBottom : 28
		// Calculate new subgraph size when keeping current graph width and adjusting height
		newSubGraphWidthByWidth =  min (graphWidth/nCols, maxSubGraphWidth)
		newSubGraphHeightByWidth = (AspectRatio * (newSubGraphWidthByWidth -lostBottom) * (leftRange/bottomRange)) + lostLeft
		// calculate new subgraph size when keeping current graph height and adjusting width
		newSubGraphHeightByHeight =  min (graphHeight/nRows, maxSubGraphHeight)
		newSubGraphWidthByHeight = ((1/AspectRatio) * (newSubGraphHeightByHeight - lostLeft) * (bottomRange/leftRange)) + lostBottom
		if (newSubGraphHeightByWidth < maxSubGraphHeight)
			if (newSubGraphWidthByHeight < maxSubGraphWidth)
				// take whichever of byWidth or byHeight maximizes area
				if (newSubGraphWidthByWidth * newSubGraphHeightByWidth > newSubGraphWidthByHeight * newSubGraphHeightByHeight)
					newSubGraphWidth = newSubGraphWidthByWidth
					newSubGraphHeight = newSubGraphHeightByWidth
				else
					newSubGraphWidth = newSubGraphWidthByHeight
					newSubGraphHeight = newSubGraphHeightByHeight
				endif
			else //
				newSubGraphWidth = newSubGraphWidthByWidth
				newSubGraphHeight = newSubGraphHeightByWidth
			endif
		else
			newSubGraphWidth = newSubGraphWidthByHeight
			newSubGraphHeight = newSubGraphHeightByHeight
		endif
	endif	
	// Move graph window to new position. Leave left and top as previous, calculate new right and
	// bottom based on size and number of subwindows
	sR =  sL + max (newSubGraphWidth * nCols, GUIPSubWin_GetRightMostControl (theGraph))
	sB =  sT  + newSubGraphHeight * nRows
	movewindow/W = $theGraph V_Left, V_top, sR, sB
	// move each subwindow within the graoh to its new position
	for (iGraph = 0; iGraph < nGraphs; iGraph += 1)
		sL = mod (iGraph, nCols)* newSubGraphWidth
		sR = sL + newSubGraphWidth
		sT =  floor (iGraph/nCols) * newSubGraphHeight 
		sB = sT + newSubGraphHeight
		MoveSubWindow /w=$theGraph + "#" +stringfromList (iGraph, graphList, ";"), fnum=(sL,sT, sR, sB);
	endfor
end


//*************************************************************************************************
//returns the minumum x Size of the graph needed to show the controls, assuming they are all in the top control bar
// Last Modified May 06 2010 by Jamie Boyd
Function GUIPSubWin_GetRightMostControl (theGraph)
	string theGraph
	
	variable lastX = 0
	string controlList = ControlNameList(theGraph , ";")
	variable ii, nControls = itemsinlist (controlList, ";")
	for (ii =0; ii < nControls; ii += 1)
		controlinfo $stringFromlist (ii, controlList, ";")
		lastX = max (lastX,(V_left + V_Width))
	endfor
	return (lastX + 5) /(ScreenResolution/72)
end

//*************************************************************************************************
//returns a list of possible arrangements of subwindows based on the number of subwindows
// Last Modified:
// 2016/11/17 by Jamie Boyd - made loop to list possible ways of arranging with no limit
Function/S  GUIPSubWin_ListArrangments ()
	
	string arrangeStr = ""
	variable nSubWIns = itemsinlist(childwindowList (""), ";")
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
			if (WhichListItem(addStr, arrangeStr, ";") ==-1)
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
			Getwindow $pa.win note
			// parse popstr to get chosen columns
			variable arrangeCols = str2num (stringfromlist (0, pa.popStr, "x"))
			variable arrangeRows = str2num (stringfromlist (1, pa.popStr, "x"))
			// update info in WIndowNote
			S_Value = ReplaceNumberByKey("nCols", S_Value, arrangeCols, ":", ";")
			S_Value = ReplaceNumberByKey("nRows", S_Value, arrangeRows, ":", ";")
			SetWindow $pa.win note = S_Value
			// reposition subwindows
			GUIPSubWin_FitSubWindows (pa.win)
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
	s.nSubWins = 4
	s.nRows = 2
	s.nCols =2
	s.wLeft = 20
	s.wTop = 50
	s.wRight =800
	s.wBottom = 600
	s.prefMoreCols = 0
	s.maxWidth = -1 // limit sizes to display/application frame sizes
	s.maxHeight = -1
	s.aspectRatio = 0.5 // width to height scaling ratio
	s.yokedAxes = 1
	s.marginL  = 28
	s.marginT = 7
	s.marginR = 7
	s.marginB = 28
	funcref GUIPSubWin_AddProto s.addContent = GUIPSubWin_demoDisplaySubWin
	// constant cs values
	cs.nUserWaves =2
	variable iSubwin
	for (iSubwin =0; iSubWin < 4; iSubWin +=1)
		make/o/n =100 $"root:testSubWin_y" + num2str (iSubWin)
		make/o/n =100 $"root:testSubWin_x" + num2str (iSubWin) 
		WAVE cs.userWaves [0] = $"root:testSubWin_y" + num2str (iSubWin)
		WAVE cs.userWaves [1] = $"root:testSubWin_x" + num2str (iSubWin)
		// range of Y data roughly 2x that of X data. With aspectRatio 0.5, graphs should be close to square
		cs.userWaves [0] = enoise (12)
		cs.userWaves [1] = 10 + enoise (6)
		cs.subWin = "SubWin" + num2str (iSubWin)
		s.contentStructs [iSubWin] = cs
	endfor
	GUIPSubWin_Display (s)
	controlbar 40
	Button fullScaleButton,pos={1.00,1.00},size={76.00,20.00},proc=GUIPSubWin_FullScaleButtonProc,title="Full Scale"
	PopupMenu GUIPSubWin_PopMenu,pos={87.00,1.00},size={235.00,23.00},proc=GUIPSubWin_ArrangePopMenuProc,title="Arrange Subwindows"
	PopupMenu GUIPSubWin_PopMenu,mode=2,popvalue="2 columns x 2 rows",value= #"GUIPSubWin_ListArrangments()"
	Button AddSubWinButton,pos={1.00,19.00},size={76.00,21.00},proc=GUIPSubWin_DemoAddPro,title="Add SubWin"
	PopupMenu RemoveSubWinPopup,pos={87.00,18.00},size={112.00,19.00},proc=GUIPSubWin_DemoRemoveProc,title="Remove SubWin:"
	PopupMenu RemoveSubWinPopup,mode=0,value= #"ChildWindowList(\"\" )"
end

// ********************************************************************************************************	
// simple display function. Display functions run with
// proper subwindow already created and brought to front
// so use appendToGraph instead of display
// Last Modified:
// 2016/11/17 by Jamie Boyd - initial version
function GUIPSubWin_demoDisplaySubWin (cs)
	STRUCT GUIPSubWin_ContentStruct &cs
	
	// display waves Y vs X
	appendToGraph cs.userWaves [0] vs cs.userWaves [1]
	modifygraph mode ($nameofWave(cs.userWaves [0])) = 3
	// draw a rectangle 2x as high as it is wide, rougly over the data
	// With aspectRatio 0.5, the rectangle should display as a square
	SetDrawEnv xcoord= bottom,ycoord= left, fillpat= 0
	DrawRRect 5,-10,15,10
end


Function GUIPSubWin_DemoRemoveProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			
			STRUCT GUIPSubWin_UtilStruct s
			STRUCT GUIPSubWin_ContentStruct cs
			s.graphName = "SubWinDemoGraph"
			s.nSubWins = 1
			s.contentStructs [0].subWin = pa.popStr
			GUIPSubWin_Remove (s)
			
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
			for (iChild =0;whichListItem (firstFree,children) > -1 ;iCHild +=1,firstFree ="SubWin" + num2str (iCHild))
			endfor
			
			STRUCT GUIPSubWin_UtilStruct s
			STRUCT GUIPSubWin_ContentStruct cs
			s.graphName = "SubWinDemoGraph"
			s.graphTitle = ""
			s.nSubWins = 1
			s.aspectRatio = 0.5 // width to height scaling ratio
			s.yokedAxes = 1
			s.marginL  = 28
			s.marginT = 7
			s.marginR = 7
			s.marginB = 28
			funcref GUIPSubWin_AddProto s.addContent = GUIPSubWin_demoDisplaySubWin
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
			GUIPSubWin_Add (s)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

