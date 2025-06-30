#pragma rtGlobals=3
#pragma IgorVersion=5
#pragma version = 1	 // Last Modified: 2013/04/05 by Jamie Boyd

//******************************************************************************************************
//KillDisplayedWave kills a wave that might be displayed, by first removing it from any open graphs and tables
Function GUIPKillDisplayedWave (thewave)
	WAVE/Z thewave
	
	// try to Kill the wave
	killwaves/z thewave
	//is it dead?
	if (!(WaveExists(thewave)))
		return 0	// Mission accomplished without having to mess with graphs and tables. Return 0 for sucsess
	endif
	//Wave not dead. get rid of dependency fomula (not likely, but is easy to test for, so do first)
	SetFormula thewave, ""
	killwaves/z thewave
	if (!(WaveExists(thewave)))
		return 0	// Mission accomplished without having to mess with graphs and tables. Return 0 for sucsess
	endif
	// Wave Not dead. Look at all open windows and subwindows for instances of the wave and remove them, then kill the wave
	string WinListStr = winlist ("*", ";", "WIN:67" )
	variable ii, nWins = itemsinList (WinListStr, ";")
	string aWindow
	variable type
	for (ii = 0; ii < nWins; ii += 1)
		aWindow = stringfromList (ii, winListStr, ";")
		type = WinType(aWindow )
		switch (type)
			case 1:  //graph
				if (KillFromGraph (theWave, aWindow) == 0)
					return 0
				endif
				break
			case 2:  //Table
				if (KillFromTable (theWave, aWindow) == 0)
					return 0
				endif
				break
			case 7:  // Panel
				if (KillFromPanel (theWave, aWindow) == 0)
					return 0
				endif
				break
		endSwitch
	endfor	
	// return 1 if wave still exists despite our best efforts, could be in use by an XOP, e.g.
	return 1
end

//******************************************************************************************************
//Kill all waves (and strings and varibales, for good measure) in a particular folder, then kills thefolder
function GUIPkillWholeDatafolder(theFolder)
	string theFolder
	
	EmptyDatafolder (theFolder, 15)
	killdatafolder/z theFolder
	return (DataFolderExists (theFolder))
end

//******************************************************************************************************
//Kills all waves displayed on a graph, be it as X waves, yWaves, or images, and closes the graph window
// Last Modified 2013/10/16
function GUIPkillWholeGraph(GraphNameStr)
	string GraphNameStr
	
	// make sure window is open
	string superWindow =  stringfromlist (0, GraphNameStr, "#")
	if (cmpstr (GraphNameStr, "") == 0)	// "" means use top Table
		if (strlen (WinList("*", "", "WIN:1" )) ==0)
			Print "No Graphs are open."
			return 1
		endif
	elseif (cmpstr (superWindow, WinList(superWindow, "", "WIN:2")) != 0)
		Print superWindow + " is not open."
		return 1
	endif
	// First take care of any subwindows
	string subWinList = childwindowlist (GraphNameStr)
	variable iSubWin, nSubwins = itemsinList (subWinList, ";")
	string aSubWin
	variable type
	for (iSubWin = 0; iSubWin < nSubwins; iSubWin +=1)
		aSubWin = GraphNameStr + "#" + stringfromList (iSubWin, subWinList, ";")
		type = WinType(aSubWin )
		switch (type)
			case 1:  //graph
				GUIPKillWholeGraph (aSubWin)
				break
			case 2:  //Table
				GUIPKillWholeTable (aSubWin)
				break
			case 7:  // Panel
				GUIPKillWholePanel (aSubWin)
				break
		endSwitch
	endfor	
	// Do main graph
	string aTrace, tracesList = TraceNameList(GraphNameStr, ";", 1 )
	variable iTrace, nTraces = itemsinlist (tracesList)
	// make a list of waves to be killed
	string deadWaveStr, deathList = ""
	// traces
	for (iTrace = 0; iTrace < nTraces; iTrace += 1)
		aTrace = stringfromlist (iTrace, tracesList)
		WAVE aYwave = TraceNameToWaveRef(GraphNameStr, aTrace)
		deadWaveStr = GetWavesDataFolder(aYwave, 2)
		if (WhichListItem(deadWaveStr, deathList, ";") == -1)
			deathList += deadWaveStr + ";"
		endif
		Wave/z aXWave = XWaveRefFromTrace(GraphNameStr, aTrace)
		if (WaveExists (aXWave))
			deadWaveStr = GetWavesDataFolder(aXwave, 2)
			if (WhichListItem(deadWaveStr, deathList, ";") == -1)
				deathList += deadWaveStr + ";"
			endif
		endif
	endfor
	// images
	string anImage, ImageList = ImageNameList(GraphNameStr, ";" )
	variable iImage, nImages = itemsinList (ImageList)
	for (iImage =0; iImage < nImages; iImage +=1)
		anImage =  stringfromlist (iImage, ImageList)
		wave/Z imageWave = ImageNameToWaveRef(GraphNameStr,anImage)
		if (WaveExists (imageWave))
			deadWaveStr = GetWavesDataFolder(imageWave, 2)
			if (WhichListItem(deadWaveStr, deathList, ";") == -1)
				deathList += deadWaveStr + ";"
			endif
		endif
	endfor
	// close the Graph
	KillWindow $GraphNameStr
	// kill the waves
	variable iWave, nWaves = itemsInList (deathList, ";")
	for (iWave=0; iWave < nWaves; iWave +=1)
		WAVE/Z aWave = $stringFromList (iWave, deathList, ";")
		GUIPKillDisplayedWave (aWave)
	endfor
end

//******************************************************************************************************
//Kills all waves shown in a table, and closes the table window
// Last Modified 2013/10/16
function GUIPKillWholeTable (TableNameStr)
	string TableNameStr
		
	// make sure Table is open. use stringfromlist (0, TableNameStr, "#") to avoid problem of searching for subwindows in Winlist
	string superWindow =  stringfromlist (0, TableNameStr, "#")
	if (cmpstr (TableNameStr, "") == 0)	// "" means use top Table
		if (strlen (WinList("*", "", "WIN:2" )) ==0)
			Print "No Tables are open."
			return 1
		endif
	elseif (cmpstr (superWindow, WinList(superWindow, "", "WIN:2")) != 0)
		print superWindow + " is not open."
		return 1
	endif
	// Tables have no SubWIndows
	// make a list of waves to be killed
	string deathList = ""
	variable iWave
	For (iWave =0; ; iWave += 1)
		WAVE/z aWave = WaveRefIndexed(TableNameStr, iWave,1)
		if (!(WaveExists (aWave)))
			break
		endif
		deathList += GetWavesDataFolder(aWave, 2) + ";"
	EndFor
	// close the Table
	KillWindow $TableNameStr
	// kill the waves
	variable nWaves = itemsInList (deathList, ";")
	for (iWave=0; iWave < nWaves; iWave +=1)
		WAVE/Z aWave = $stringFromList (iWave, deathList, ";")
		GUIPKillDisplayedWave (aWave)
	endfor
end

//******************************************************************************************************
//Kills all waves shown on a panel, and closes the table window
// Last Modified 2013/10/16
function GUIPKillWholePanel (panelNameStr)
	string panelNameStr
	
	// make sure Panel is open
	string superWindow =  stringfromlist (0, panelNameStr, "#")
	if (cmpstr (panelNameStr, "") == 0)	// "" means use top Table
		if (strlen (WinList("*", "", "WIN:1" )) ==0)
			Print "No Panels are open."
			return 1
		endif
	elseif (cmpstr (superWindow, WinList(superWindow, "", "WIN:2")) != 0)
		Print superWindow + " is not open."
		return 1
	endif
	// Take care of any subwindows.
	string subWinList = childwindowlist (panelNameStr)
	variable iSubWin, nSubwins = itemsinList (subWinList, ";")
	string aSubWin
	variable type
	for (iSubWin = 0; iSubWin < nSubwins; iSubWin +=1)
		aSubWin = panelNameStr + "#" + stringfromList (iSubWin, subWinList, ";")
		type = WinType(aSubWin )
		switch (type)
			case 1:  //graph
				GUIPKillWholeGraph (aSubWin)
				break
			case 2:  //Table
				GUIPKillWholeTable (aSubWin)
				break
			case 7:  // Panel
				GUIPKillWholePanel (aSubWin)
				break
		endSwitch
	endfor
	// close the Panel
	KillWindow $panelNameStr
end

//******************************************************************************************************
// Kills a wave that may be displayed in a graph window, including any subwindows
Static function KillFromGraph (theWave, awindow)
	wave/Z theWave
	string aWindow
	
	CheckDisplayed/W= $awindow thewave
	if (V_Flag)
		RemoveFromGraph /W=$awindow/Z $(nameofwave (thewave))
		RemoveImage/W=$awindow /Z $(nameofwave (thewave))
		CheckDisplayed/W= $awindow thewave
		if (V_Flag)	// It's still here. maybe multiple copies or is diplayed as an x-wave 
			string tracesList = TraceNameList(awindow, ";", 1 )
			variable numtraces = itemsinlist (tracesList)
			variable ii
			for (ii = 0; ii < numtraces;ii += 1)
				if (waveExists (TraceNameToWaveRef(aWindow, stringfromlist (ii, tracesList))))
					WAVE aYwave = TraceNameToWaveRef(aWindow, stringfromlist (ii, tracesList))
					Wave aXWave = XWaveRefFromTrace(awindow, stringfromlist (ii, tracesList))
					if (((cmpstr (GetWavesDataFolder(theWave, 2 ),GetWavesDataFolder(aYWave, 2 ))) == 0) || ((cmpstr (GetWavesDataFolder(theWave, 2 ),GetWavesDataFolder(aXWave, 2 ))) == 0))
						RemoveFromGraph /W=$awindow/Z $stringfromlist (ii, tracesList)
					endif
				endif
			endfor
			CheckDisplayed/W= $awindow thewave
			if (V_Flag)	// Wave is STILL on this graph - multiple copies of an image?
				string ImageList = ImageNameList(awindow, ";" )
				variable numImages = itemsinList (ImageList)
				for (ii = 0; ii < numImages; ii += 1)
					if (WaveExists (ImageNameToWaveRef(aWindow, stringfromlist (ii, ImageList))))
						WAVE anImage = ImageNameToWaveRef(aWindow, stringfromlist (ii, ImageList))
						if ((cmpstr (GetWavesDataFolder(theWave, 2 ),GetWavesDataFolder(anImage, 2 ))) == 0) 
							RemoveImage/W=$awindow /Z $(nameofwave (thewave))
						endif
					endif
				endfor
			endif
		endif
		// try to Kill the wave
		killwaves/z thewave
		//is it dead?
		if (!(WaveExists(thewave)))
			return 0 // success
		endif
	endif
	//Now we get all recursive on subwindows
	string subWinList = childwindowlist (awindow)
	variable nSubwins = itemsinList (subWinList, ";")
	string aSubWin
	variable type
	for (ii = 0; ii < nSubwins; ii +=1)
		aSubWin = aWindow + "#" + stringfromList (ii, subWinList, ";")
		type = WinType(aSubWin )
		switch (type)
			case 1:  //graph
				if (KillFromGraph (theWave, aSubWin) == 0)
					return 0
				endif
				break
			case 2:  //Table
				if (KillFromTable (theWave, aSubWin) == 0)
					return 0
				endif
				break
			case 7:  // Panel
				if (KillFromPanel (theWave, aSubWin) == 0)
					return 0
				endif
				break
		endSwitch
	endfor	
	// return 1 if wave still exists
	return 1
end

//******************************************************************************************************
// Kills a wave that may be displayed on a table	
Static Function KillFromTable (theWave, aWindow)
	WAVE/Z theWave
	string aWindow
	
	CheckDisplayed/W= $awindow thewave
	if ((V_Flag))	// Wave is  on this table
		RemoveFromTable  /W=$aWindow theWave.ld
		// try to Kill the wave
		killwaves/z thewave
		//is it dead?
		if (!(WaveExists(thewave)))
			return 0 // success
		endif
	endif
	return 1
end

//******************************************************************************************************
// Kills a wave that may be displayed in the subwindows of a panel
Static function KillFromPanel (theWave, aWindow)
	WAVE theWave
	string aWindow
	
	//Panels have nothing but subwindows for wave display
	string subWinList = childwindowlist (awindow)
	variable nSubwins = itemsinList (subWinList, ";"), ii
	string aSubWin
	variable type
	for (ii = 0; ii < nSubwins; ii +=1)
		aSubWin = aWindow + "#" + stringfromList (ii, subWinList, ";")
		type = WinType(aSubWin )
		switch (type)
			case 1:  //graph
				if (KillFromGraph (theWave, aSubWin) == 0)
					return 0
				endif
				break
			case 2:  //Table
				if (KillFromTable (theWave, aSubWin) == 0)
					return 0
				endif
				break
			case 7:  // Panel
				if (KillFromPanel (theWave, aSubWin) == 0)
					return 0
				endif
				break
		endSwitch
	endfor	
	// return 1 if wave still exists
	return 1
end

//******************************************************************************************************
// Removes a wave from all graphs, tables, etc, without killing it
Static Function FreeDisplayedWave (thewave)
	WAVE thewave
	
	//fet rid of any dependency fomula
	SetFormula thewave, ""
	// Look at all open windows and subwindows for instances of the wave and remove them
	string WinListStr = winlist ("*", ";", "WIN:67" )
	variable ii, nWins = itemsinList (WinListStr, ";")
	string aWindow
	variable type
	for (ii = 0; ii < nWins; ii += 1)
		aWindow = stringfromList (ii, winListStr, ";")
		type = WinType(aWindow )
		switch (type)
			case 1:  //graph
				FreeFromGraph (theWave, aWindow)
				break
			case 2:  //Table
				FreeFromTable (theWave, aWindow)
				break
			case 7:  // Panel
				FreeFromPanel (theWave, aWindow)
				break
		endSwitch
	endfor
end


//******************************************************************************************************
// Removes a wave that may be displayed in a graph window, including any subwindows
static function FreeFromGraph (theWave, awindow)
	wave theWave
	string aWindow
	
	CheckDisplayed/W= $awindow thewave
	if (V_Flag)
		RemoveFromGraph /W=$awindow/Z $(nameofwave (thewave))
		RemoveImage/W=$awindow /Z $(nameofwave (thewave))
		CheckDisplayed/W= $awindow thewave
		if (V_Flag)	// It's still here. maybe multiple copies or is diplayed as an x-wave 
			string tracesList = TraceNameList(awindow, ";", 1 )
			variable numtraces = itemsinlist (tracesList)
			variable ii
			for (ii = 0; ii < numtraces;ii += 1)
				if (waveExists (TraceNameToWaveRef(aWindow, stringfromlist (ii, tracesList))))
					WAVE aYwave = TraceNameToWaveRef(aWindow, stringfromlist (ii, tracesList))
					Wave aXWave = XWaveRefFromTrace(awindow, stringfromlist (ii, tracesList))
					if (((cmpstr (GetWavesDataFolder(theWave, 2 ),GetWavesDataFolder(aYWave, 2 ))) == 0) || ((cmpstr (GetWavesDataFolder(theWave, 2 ),GetWavesDataFolder(aXWave, 2 ))) == 0))
						RemoveFromGraph /W=$awindow/Z $stringfromlist (ii, tracesList)
					endif
				endif
			endfor
			CheckDisplayed/W= $awindow thewave
			if (V_Flag)	// Wave is STILL on this graph - multiple copies of an image?
				string ImageList = ImageNameList(awindow, ";" )
				variable numImages = itemsinList (ImageList)
				for (ii = 0; ii < numImages; ii += 1)
					if (WaveExists (ImageNameToWaveRef(aWindow, stringfromlist (ii, ImageList))))
						WAVE anImage = ImageNameToWaveRef(aWindow, stringfromlist (ii, ImageList))
						if ((cmpstr (GetWavesDataFolder(theWave, 2 ),GetWavesDataFolder(anImage, 2 ))) == 0) 
							RemoveImage/W=$awindow /Z $(nameofwave (thewave))
						endif
					endif
				endfor
			endif
		endif
	endif
	//Now we get all recursive on subwindows
	string subWinList = childwindowlist (awindow)
	variable nSubwins = itemsinList (subWinList, ";")
	string aSubWin
	variable type
	for (ii = 0; ii < nSubwins; ii +=1)
		aSubWin = aWindow + "#" + stringfromList (ii, subWinList, ";")
		type = WinType(aSubWin )
		switch (type)
			case 1:  //graph
				FreeFromGraph (theWave, aSubWin)
				break
			case 2:  //Table
				FreeFromTable (theWave, aSubWin)
				break
			case 7:  // Panel
				FreeFromPanel (theWave, aSubWin)
				break
		endSwitch
	endfor	
end

//******************************************************************************************************
// Frees a wave that may be displayed in a table
static Function FreeFromTable (theWave, aWindow)
	WAVE theWave
	string aWindow
	
	CheckDisplayed/W= $awindow thewave
	if ((V_Flag))	// Wave is on this table
		RemoveFromTable /W=$aWindow theWave.ld
	endif
end

//******************************************************************************************************
// frees a wave that may be displayed in the subwindows of a panel
static function FreeFromPanel (theWave, aWindow)
	WAVE theWave
	string aWindow
	
	//Panels have nothing but subwindows for wave display
	string subWinList = childwindowlist (awindow)
	variable nSubwins = itemsinList (subWinList, ";"), ii
	string aSubWin
	variable type
	for (ii = 0; ii < nSubwins; ii +=1)
		aSubWin = aWindow + "#" + stringfromList (ii, subWinList, ";")
		type = WinType(aSubWin )
		switch (type)
			case 1:  //graph
				FreeFromGraph (theWave, aSubWin)
				break
			case 2:  //Table
				FreeFromTable (theWave, aSubWin)
				break
			case 7:  // Panel
				FreeFromPanel (theWave, aSubWin)
				break
		endSwitch
	endfor	
end

//******************************************************************************************************
// Empties a datafolder of the different types of Igor objects
// Last Modified 2013/01/28 by Jamie Boyd
Static Function EmptyDatafolder (theFolder, types)
	string theFolder
	variable types // 2^0 = 1=waves, 2^1= 2=numeric variables, 2^2= 4=string variables, 2^3 = 8=data folders
	
	theFolder = removeEnding (theFolder, ":") + ":"
	string objName
	variable iObj
	// waves
	if (types & 1)
		for (iObj = 0, objName = GetIndexedObjName(theFolder, 1,0); strlen (objName) > 0; iObj += 1, objName = GetIndexedObjName(theFolder, 1, iObj))
			WAVE/Z aWave = $theFolder + objName
			GUIPKillDisplayedWave (aWave)
		endfor
	endif
	// numeric variables
	if (types & 2)
		for (iObj = 0, objName = GetIndexedObjName(theFolder, 2, iObj); strlen (objName) > 0; iObj += 1, objName = GetIndexedObjName(theFolder, 2, iObj))
			NVAR aVar =  $theFolder +objName
			SetFormula aVar, ""
			Killvariables/z aVar
		endfor
	endif
	// string variables
	if (types & 4)
		for (iObj = 0, objName = GetIndexedObjName(theFolder, 3, iObj); strlen (objName) > 0; iObj += 1, objName = GetIndexedObjName(theFolder, 3, iObj))
			SVAR aStrVar =  $theFolder +objName
			SetFormula aStrVar, ""
			Killstrings/z aStrVar
		endfor
	endif
	// data folders
	if (types & 8)
		for (iObj = 0, objName = GetIndexedObjName(theFolder, 4, iObj); strlen (objName) > 0; iObj += 1, objName = GetIndexedObjName(theFolder, 4, iObj))
			GUIPkillWholeDatafolder (theFolder + objName)
		endfor
	endif
end