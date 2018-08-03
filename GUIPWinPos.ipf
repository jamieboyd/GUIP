#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName =GUIPWinPos
#pragma IgorVersion = 6
#pragma version = 1.6 // Last modified 2013/10/22 by Jamie Boyd

// Utility for arranging windows nicely on different screens (Macintosh)
// or within the Igor Application Frame (MS-Windows)

// Moving a window with the MoveWindow command moves the content area of the window
// to the requested coordinates, as returned with GetWindow wSize, but the outer frame of 
// the window will be bigger than the requested coordinates, because of the window's
// title bar and possibly the width of the border around each window.

// Under Igor 6, we find title bar height and border width by the difference between the values obtained with
//  getwindow wsizeOuter, which gets the size/location of a window on screen, including the height
//  of the window's title bar and  the width of the border around each window, and
// GetWindow wsize, which returns the size/location of just the content area of the window.
// MoveWindow commands are then adjusted for titlebar height and border width

//*****************************************************************************************************************************
// mnenomic constants used for accessing 2D wave of screen coordinates
STATIC CONSTANT kLeft =0
STATIC CONSTANT kTop=1
STATIC CONSTANT kRight =2
STATIC CONSTANT kBottom=3
// constants for window positioning horizontally and vertically 
CONSTANT kGUIPToLeft = 0
// absolute: window's left edge is positioned at left edge of screen/application frame
// relative: window's right edge is positioned at left side of anchor window
CONSTANT kGUIPToTop = 0
// absolute: window's top edge is positioned at top edge of screen/application frame
// relative: window's bottom edge is positioned at top of anchor window
CONSTANT kGUIPToCenter = 1
// absolute: window is positioned in center of screen/application frame
// relative: window''s center is aligned with center of  anchor window
CONSTANT kGUIPToRight =2
// absolute: window's right edge is positioned at right edge of screen/application frame
// relative: window's left edge is positioned ta right edge of anchor window
CONSTANT kGUIPToBottom =2
// absolute: window's bottom edge is positioned at bottom of screen/application frame
// relative: window's top edge is positioned at bottom edge of anchor window
// Additional constants for aligning with another window
CONSTANT kGUIPAlignLeft = 3
// relative only: aligns left edges of  window and anchor window
CONSTANT kGUIPAlignTop =3
// relative only: aligns top edges of window and anchor window
CONSTANT kGUIPAlignRight =4
// relative only: aligns right edges of window and anchor window
CONSTANT kGUIPAlignBottom=4
// relative only: aligns bottom edges of window and anchor window

// Constant for default screen to use on the Macintosh, if no screen is specified
// Note: Screens will be numbered starting from 1
// This will be read into global (root:packages:WinPos:MacDefaultScreen) during WinPosInit, so you can change the global on the fly
Static Constant kMacDefaultScreen = 0
// Screens can also be specified by negative numbers relative to the Main Screen  (the one with the Igor Menu Bar)
// Value of 0 for mac Screen means to use the mac Main Screen
// -1 means to use the next screen, assuming there is more than one screen, and so on. Values will "Wrap around"
// so if main screen is screen 2 of 3, requesting screen -2 will wrap around to screen 1

//*****************************************************************************************************************************
// Positions window within Igor Application Frame (on MS Windows) or within the given screen (on Macintosh)
// Puts new coordinates of window in variables WinPos_Left, WinPos_Top, WinPos_Right, WinPos_Bottom
// returns 0 if window was moved, 1 if the window does not exist
// Last Modified 2014/10/17 by Jamie Boyd
Function GUIPWinPosAbs (theWindow, hWhere, vWhere, [theScreen, minWidth, minHeight, MaxWidth, maxHeight])
	string theWindow 
	// name of the window to be moved. Can use "" or kwTopWin for top window
	// Use kwCmdHist to move command window
	variable hWhere // 0 is left, 1 is center, 2 is right
	variable vWhere // 0 is top, 1 is center, 2 is bottom
	variable theScreen // only used on Macintosh.
	variable minWIdth, minHeight, maxWidth, maxHeight // can scrunch size of a window to a max width/height
	variable/G WinPos_Left = Nan,  WinPos_Top = Nan, WinPos_Right = Nan, WinPos_Bottom = Nan
	// Check for A) moving command window, B) a top window if moving top window, C) the given window exists
	variable isCommandWin = 0
	StrSwitch (theWindow)
		case "kwCmdHist":
			isCommandWin =1
			break
		case "":
		case  "kwTopWin":
			theWindow = winList ("*", ";", "WIN:87")
			if (cmpStr (theWindow, "") ==0)
				return 1
			endif
			break
		default:
			if (cmpStr (theWindow, stringFromList (0, winList (theWindow, ";", ""), ";")) != 0)
				return 1
			endif
			break
	endSwitch
	// Get window's Width and Height (minus the titlebar and frame)
	GetWindow $theWindow, wsize
	variable width =(V_right - V_left)
	variable height = (V_bottom - V_top)
	// Optionally scrunch window size
	if ((!(ParamIsDefault(minHeight))) && (height < minHeight))
		height = minHeight
	endif
	if ((!(ParamIsDefault(minWidth))) && (width < minWidth))
		width = minWidth
	endif
	if ((!(ParamIsDefault(maxHeight))) && (height > maxHeight))
		height = maxHeight
	endif
	if ((!(ParamIsDefault(maxWidth))) && (width> maxWidth))
		width = maxWidth
	endif
	// Package globals
	NVAR titleHt = root:packages:WinPos:titleHt 
	NVAR frameWid =root:packages:WinPos:frameWid
	WAVE Screens = root:packages:WinPos:Screens
	SVAR OS = root:packages:WinPos:OS
	// OS specific stuff
	StrSwitch  (OS)
		case "Windows":
			theScreen = 0
			break
		case "Macintosh": 
			if (ParamIsDefault(theScreen)) // use default screen if none given
				NVAR MacDefaultScreen = root:packages:WinPos:MacDefaultScreen
				theScreen = macDefaultScreen
			else
				variable nScreens = DimSize (Screens, 0) -1
				if (theScreen > 0) // screen specified by number
					theScreen = Min (theScreen, nScreens)
				else // screen specified relative to main screen
					NVAR MacMainScreen = root:packages:WinPos:MacMainScreen
					for (theScreen = MacMainScreen - theScreen;theScreen > nScreens;theScreen -= nScreens)
					endfor
				endif
			endif
			break
		default:
			return 1
			break
	endswitch
	// compute new location of window content wrt the rect
	variable newLeft, newTop
	// horizontal
	switch (hWhere)
		case kGUIPToLeft:
			newLeft = Screens [theScreen] [kLeft]  + frameWid
			break
		case kGUIPToCenter:
			newLeft = ( Screens [theScreen] [kLeft] + Screens [theScreen] [kRight])/2 - width/2
			break
		case kGUIPToRight:
			newLeft = Screens[theScreen] [kRight] - width - frameWid
			break
		default:
			return 1
			break
	endSwitch
	// vertical
	switch (vWhere)
		case kGUIPToTop:
			newTop = Screens[theScreen] [kTop] + titleHt
			break
		case kGUIPToCenter:
			newTop =  (Screens[theScreen] [kBottom] - Screens[theScreen] [kTop])/2 - (height + titleHt + frameWid)/2 + titleHt
			break
		case kGUIPToBottom:
			newTop =Screens[theScreen] [kBottom] - height - frameWid
			break
		default:
			return 1
			break
	endswitch
	// set global variables for new position
	WinPos_Left = newLeft
	WinPos_Top = newTop
	WinPos_Right = newLeft + width
	WinPos_Bottom = newTop + height
	// Move the window
	if (isCommandWin)
		movewindow/C WinPos_Left , winPos_top, WinPos_Right, WinPos_Bottom
	else
		movewindow/W=$theWindow WinPos_Left , winPos_top, WinPos_Right, WinPos_Bottom
	endif
	return 0
end

//*****************************************************************************************************************************
// Positions window relative to an anchor window
// Puts new coordinates of window in variables WinPos_Left, WinPos_Top, WinPos_Right, WinPos_Bottom
// returns 0 if window was moved, 1 if the window does not exist
// Last Modified 2014/10/17 by Jamie Boyd 
Function GUIPWinPosRel (theWindow, anchorWindow, hWhere, vWhere,[minWidth, minHeight, maxWidth, maxHeight])
	string theWindow // name of the window to be moved. Can use "" or kwTopWin for top window
	string anchorWindow // name of anchor window - the window will be moved relative to this window
	variable hWhere // 0 is left, 1 is center, 2 is right
	variable vWhere // 0 is top, 1 is center, 2 is bottom
	variable minWidth, minHeight, maxWidth, maxHeight
	
	variable/G WinPos_Left = Nan,  WinPos_Top = Nan, WinPos_Right = Nan, WinPos_Bottom = Nan
	// Check for A) moving command window, B) a top window if moving top window, C) the given window exists
	variable isCommandWin = 0
	StrSwitch (theWindow)
		case "kwCmdHist":
			isCommandWin =1
			break
		case "":
		case  "kwTopWin":
			theWindow = winList ("*", ";", "WIN:87")
			if (cmpStr (theWindow, "") ==0)
				return 1
			endif
			break
		default:
			if (cmpStr (theWindow, stringFromList (0, winList (theWindow, ";", ""), ";")) != 0)
				return 1
			endif
			break
	endSwitch
	// make sure anchor window exists
	if (cmpStr (anchorWindow, stringFromList (0, winList (anchorWindow, ";", ""), ";")) != 0)
		return 2
	endif
	// make sure theWindow and anchorWindow are different
	if (cmpStr (anchorWindow, theWindow) ==0)
		return 3
	endif
	// Get window's Width and Height
	GetWindow $theWindow, wsize
	variable width =(V_right - V_left)
	variable height = (V_bottom - V_top)
	// Optionally scrunch window size
	if ((!(ParamIsDefault(minHeight))) && (height < minHeight))
		height = minHeight
	endif
	if ((!(ParamIsDefault(minWidth))) && (width < minWidth))
		width = minWidth
	endif
	if ((!(ParamIsDefault(maxHeight))) && (height > maxHeight))
		height = maxHeight
	endif
	if ((!(ParamIsDefault(maxWidth))) && (width> maxWidth))
		width = maxWidth
	endif
	// Fill a Rect struct with left, top, right, bottom values of anchor window
	STRUCT RECT ancRect
	GetWindow $anchorWindow, wsize
	ancRect.left = V_left
	ancRect.top = V_top
	ancRect.right = V_right
	ancRect.bottom = V_bottom
	// Package globals
	NVAR titleHt = root:packages:WinPos:titleHt 
	NVAR frameWid =root:packages:WinPos:frameWid
	// compute new location wrt the rect
	variable newLeft, newTop
	// horizontal
	switch (hWhere)
		case kGUIPToLeft: // right side of theWindow aligns with left side of anchorWindow
			newLeft = ancRect.left - width - frameWid
			break
		case kGUIPToCenter: // center of theWindow aligns with center of anchorWindow
			newLeft = (ancRect.left + ancRect.right)/2 - width/2
			break
		case kGUIPToRight: // left side of theWindow aligns with right side of anchorWindow
			newLeft = ancRect.right + frameWid
			break
		case kGUIPAlignLeft: // left side of theWindow aligns with left side of anchorWindow
			newLeft = ancRect.left + frameWid
			break
		case kGUIPAlignRight: // right side of theWindow aligns with right side of anchor window
			newLeft = ancRect.right - width - frameWid
			break
		default:
			return 4
			break
	endSwitch
	// vertical
	switch (vWhere)
		case kGUIPToTop: // bottom of theWindow aligns with top of anchorWIndow
			newTop = ancRect.top - height  - frameWid
			break
		case kGUIPToCenter: // center of theWindow aligns with center of anchor window
			newTop = (ancRect.bottom + ancRect.top)/2 - (height + titleHt + frameWid)/2 + titleHt
			break
		case kGUIPToBottom: // top of the window aligns with bottom of anchorWindow
			newTop = ancRect.bottom +  titleHt
			break
		case kGUIPAlignTop: // top of window aligns with top of anchor window
			newTop = ancRect.top + titleHt
			break
		case kGUIPAlignBottom: // bottom of  theWindow aligns with bottom of anchorWindow
			newTop = ancRect.bottom - height - frameWid
			break
		default:
			return 5
			break
	endswitch
	// set global variables for new position
	WinPos_Left = newLeft
	WinPos_Top = newTop
	WinPos_Right = newLeft + width
	WinPos_Bottom = newTop + height
	// Move the window
	if (isCommandWin)
		movewindow/C WinPos_Left , winPos_top, WinPos_Right, WinPos_Bottom
	else
		movewindow/W=$theWindow WinPos_Left , winPos_top, WinPos_Right, WinPos_Bottom
	endif
	return 0
end

//*****************************************************************************************************************************
// resizes and moves windows to fit in a limited space
// All windows will be resized to the same size
// Last Modified 2013/10/22 by Jamie Boyd
Function GUIPWinPosTile (theWindows, reserveRect, [rows, cols, theScreen])
	string theWindows // semicolon-separated list of windows to tile, in column major order
	Struct Rect &reserveRect // number of pixels to the left, top, right, and bottom of the screen to reserve
	variable rows // specify number of rows of windows. Overrides columns
	variable cols // specify number of columns of windows. Ignored if rows is specified
	variable theScreen // On a mac, specifies which screen to use
	
	// Package globals
	NVAR titleHt = root:packages:WinPos:titleHt 
	NVAR frameWid =root:packages:WinPos:frameWid
	WAVE Screens = root:packages:WinPos:Screens
	SVAR OS = root:packages:WinPos:OS
	// OS specific stuff
	StrSwitch  (OS)
		case "Windows":
			theScreen = 0
			break
		case "Macintosh": 
			if (ParamIsDefault(theScreen)) // use default screen if none given
				NVAR macDefaultScreen = root:packages:WinPos:MacDefaultScreen
				theScreen = macDefaultScreen
			else
				variable nScreens = DimSize (Screens, 0) -1
				if (theScreen > 0)  //screen specified by number
					theScreen = Min (theScreen, nScreens)
				else  // screen specified relative to main screen
					NVAR MacMainScreen = root:packages:WinPos:MacMainScreen
					for (theScreen = MacMainScreen - theScreen;theScreen > nScreens;theScreen -= nScreens)
					endfor
				endif
			endif
			break
		default:
			return 1
			break
	endswitch
	// Make a rectangle within which to tile the windows, using reserveRect values
	STRUCT RECT tileRect
	tileRect.left = Screens [theScreen] [kLeft] + reserveRect.left
	tileRect.top = Screens [theScreen] [kTop] + reserveRect.top
	tileRect.right = Screens [theScreen] [kRight]  - reserveRect.right
	tileRect.bottom = Screens [theScreen] [kbottom] - reserveRect.bottom
	// calculate numer of rows and columns needed, depending on number of windows
	// Rows takes precedence
	variable iWin, nWins = itemsinlist (theWindows, ";")
	variable iRow, nRows, iCol, nCols
	if (ParamIsDefault(rows))
		// need to calculate rows
		if (ParamIsDefault(cols))
			// need to calculate both rows and cols
			nRows=ceil (sqrt (nWins))
			nCols = ceil (nWIns/nRows)
		else // we have cols but no rows
			if (nCols > nWins)
				return 2
			endif
			nCols = cols
			nRows = ceil (nWins/nCols)
		endif
	else
		// we have rows defined
		if (rows > nWins)
			return 2
		endif
		nRows = rows
		nCols = ceil (nWins/nRows)
	endif
	// calculate outer size of each window (this includes titleHt and FrameWid)
	variable width = (tileRect.right - tileRect.left)/nCols - 2*frameWid
	variable height = (tileRect.bottom - tileRect.top)/nRows - titleHt - frameWid
	// iterate through rows and cols, moving a window at each step
	string aWindow
	variable leftPos, topPos
	for (iWin =0, iRow =0; iRow < nRows; iRow +=1)
		for (iCol =0 ; iCol < nCols && iWin < nWins; iCol +=1, iWin +=1)
			aWindow = stringFromList (iWin, theWindows, ";")
			leftPos = tileRect.left + iCol * (width + 2*frameWid) + frameWid
			topPos = tileRect.top + iRow * (height + titleHt + frameWid) + titleHt
			movewindow/W=$aWindow leftPos , topPos, (leftPos + width), (topPos + height)
		endfor
	endfor
	return 0
end

//*****************************************************************************************************************************
// gets some OS info and measures some window properties and sets global variables
// User Programmer should not have to call this directly, if using hook functions 
// Last Modified 2013/10/22 by Jamie Boyd
function GUIPWinPosInit ()

	if (!(dataFolderExists ("root:packages")))
		newDataFolder root:packages
	endif
	if (!(dataFolderExists ("root:packages:WinPos")))
		newDataFolder root:packages:WinPos
	endif
	// which OS platform, Macintosh or MS-windows
	string/G root:packages:WinPos:OS = IgorInfo (2)
	SVAR OS = root:packages:WinPos:OS
	// Height of title for each window
	Variable/G root:packages:WinPos:titleHt
	NVAR titleHt =  root:packages:WinPos:titleHt
	// width of the frame around each window
	Variable/G root:packages:WinPos:frameWid
	NVAR frameWid =  root:packages:WinPos:frameWid
	// display a window to measure titleBar height and windowFrame width 
	doWindow/K WinPosInit0
	display/N=WinPosInit0/w= (100,100,200,200)
	getwindow WinPosInit0 wsizeOuter
	variable outerTop = V_top
	variable outerLeft = V_left
	getwindow WinPosInit0 wsize
	titleHt = V_top - outerTop
	frameWid = V_left - outerLeft
	// make wave for screens coordinates
	// One virtual screen (application frame) on MS-windows, multiple screens on Mac
	if (cmpStr (OS, "Windows") ==0)
		// Screen 0 will be used for Windows application frame, so make wave with 1 row
		// and fill it with dimensions of Igor Application Frame
		make/o/n=(1, 4) root:packages:WinPos:Screens
		AfterMDIFrameSizedHook(0)
	elseif (cmpStr (OS, "Macintosh") ==0)
		//  make a wave to hold coordinates of each screen
		variable/G root:packages:WinPos:nScreens = numberbykey ("NSCREENS", IgorInfo(0), ":", ";")
		NVAR nScreens = root:packages:WinPos:nScreens
		Variable/G root:packages:WinPos:MacMainScreen
		NVAR MacMainScreen = root:packages:WinPos:MacMainScreen
		NVAR MacDefaultScreen = root:packages:WinPos:MacDefaultScreen
		// Because screen naming is one-based, make wave with extra row, and leave row 0 blank
		make/o/n=((nScreens +1), 4) root:packages:WinPos:Screens
		WAVE macScreens = root:packages:WinPos:Screens
		macScreens [0] [] = NaN
		variable iScreen
		string screenStr
		variable left, top, right, bottom
		for (iScreen =1; iScreen <= nScreens; iScreen +=1)
			GetScreenRect (iScreen, left, top, right, bottom)
			macScreens [iScreen] [kLeft] = left
			macScreens [iScreen] [kTop] = top
			macScreens [iScreen] [kRight] = right
			macScreens [iScreen] [kBottom] = bottom
		endfor
		// now look for menubar
		// try to position a window at top of screen, and if you can't, it is the main screen
		for (iScreen =1; iScreen <= nScreens; iScreen +=1)
			moveWindow/w=WinPosInit0 macScreens [iScreen] [kLeft]  +100,macScreens [iScreen] [kTop] ,macScreens [iScreen] [kLeft] + 200,macScreens [iScreen] [kTop] +100
			getwindow WinPosInit0 wsizeOuter
			if (V_top > macScreens [iScreen] [1])
				macScreens [iScreen] [kTop] = V_top
				variable/G root:packages:WinPos:macMainScreen = iScreen
				break
			endif
		endfor
		// I beleive that if a 2nd screen is logically above the main screen, it is possible to move a window over the menubar
		// In that case, the above loop through the screens will not find the main screen
		// If not found, there is no need to distinguish the main screen, or the menu height, so set both variables to zero
		if (iScreen > nScreens)
			string MenuString = ""
			for (iScreen =1; iScreen <= nScreens; iScreen +=1)
				MenuString += "Screen " + num2str (iScreen) + "(" + num2str (macScreens [iScreen] [kRIght] - macScreens [iScreen] [kLeft]) + " x "
				MenuString += num2str (macScreens [iScreen] [kBottom] - macScreens [iScreen] [kTop]) + " ); "
			endfor
			variable mainScreenLocal
			Prompt mainScreenLocal, "Main Screen:" , popup, MenuString
			DoPrompt "Please Identify the Main Screen (with the Menu Bar)", mainScreenLocal
			macMainScreen = mainScreenLocal
		endif
		// initialize global for deafult screen to use from constant
		if (kMacDefaultScreen > 0) // default specified absolute
			MacDefaultScreen =min (kMacDefaultScreen, nScreens)
		else // specified relative to main screen
			for (MacDefaultScreen = MacMainScreen - kMacDefaultScreen;MacDefaultScreen > nScreens;MacDefaultScreen -= nScreens)
			endfor
		endif
	endif
	doWIndow/K WinPosInit0
end

//*****************************************************************************************************************************
// ****************************************** Static Utility Functions ******************************************************
//*****************************************************************************************************************************
// Hook function to initialize WinPos globals whenever a new experiment is started
// Place an alias to WinPos into Igor Procedures folder to ensure WinPos is properly initialized at startup
static function IgorStartOrNewHook(igorApplicationNameStr )
	string igorApplicationNameStr
	
	GUIPwinPosInit ()
end

//*****************************************************************************************************************************
// Hook function to initialize WinPos globals whenever an old experiment is opened
Static function AfterFileOpenHook(refNum, fileNameStr, pathNameStr, fileTypeStr, fileCreatorStr, fileKind )
	variable refNum
	string fileNameStr
	string pathNameStr
	string fileTypeStr
	string fileCreatorStr
	variable fileKind 
	
	if ((filekind == 1) || (fileKind == 2))
		GUIPwinPosInit ()
	endif
	return 0
end

//*****************************************************************************************************************************
//  Hook function called when the Windows-only "MDI frame" (main application window) has been resized.
// Update the contents of row 0 of the wave of screens info
// Last modified 2014/10/20 by Jamie Boyd
static function AfterMDIFrameSizedHook(param)
	variable param
	
	Switch (param)
		case 0: // Normal resize
		case 2:// maximized
			WAVE/Z Screens =  root:packages:WinPos:Screens
			if (!(WaveExists (Screens)))
				GUIPwinPosInit ()
				WAVE/Z Screens =  root:packages:WinPos:Screens
			endif
			GetWindow kwFrameInner wsize
			Screens [0] [kLeft] = V_left
			Screens [0] [kTop] = V_top
			Screens [0] [kRight]= V_right
			Screens [0] [kBottom] = V_bottom
			break
		case 1: // Minimized
		case 3: // Moved
			break
	EndSwitch
	return 0
end

//*****************************************************************************************************************************
// Gets the coordinates of the requested screen and places in  pass-by-reference parameters
// A simple stringbykey can not be used to get screen coordiantes from IgorInfo(0) because the
// same character "," is used as the list separator for the screen coordinates and the key=value
// pair separator for the string containing info for each screen DEPTH=32,RECT=0,0,1400,1050
// Works on either platform, but not much use on MS-Windows
// returns 0 if OK, else 1
// Last Modified 2013/10/21 by Jamie Boyd
static function GetScreenRect (theScreen, left, top, right, bottom)
	variable theScreen
	variable &left
	variable &top
	variable &right
	variable &bottom
	
	// Get info on screens. Make sure requested screen exists, else return error
	string infoStr = IgorInfo(0)
	variable nScreens = numberbykey ("NSCREENS", infoStr, ":", ";")
	if (theScreen > nScreens)
		left= NaN
		top = Nan
		right = NaN
		bottom = NaN
		return 1
	endif
	// get string for requested screen
	string screenStr = stringByKey ("SCREEN" + num2str (theScreen), infoStr, ":", ";")
	// trim string to the 4 RECT coordinates, or return error  if not found
	variable startPos = strsearch(screenStr, "RECT=", 0)
	if (startPos ==-1)
		left= NaN
		top = Nan
		right = NaN
		bottom = NaN
		return 1
	endif
	screenStr = screenStr [startPos + 5, strlen (screenStr) -1]
	// fill rect struct with values from the trimmed string
	left = str2num (stringFromList (kLeft, screenStr, ","))
	top =  str2num (stringFromList (kTop, screenStr, ","))
	right =  str2num (stringFromList (kRight, screenStr, ","))
	bottom =  str2num (stringFromList (3, screenStr, ","))
	return 0
end

//*****************************************************************************************************************************
// Gets height of given screen on Mac, or current height of Igor Application frame on Windows
// Last Modified 2013/10/21 by Jamie Boyd
Static Function ScreenHeight ([theScreen])
	variable theScreen
	
	// Package globals
	WAVE/Z Screens = root:packages:WinPos:Screens
	if (!(WAveExists (Screens)))
		GUIPWInPosInit()
	endif
	NVAR titleHt = root:packages:WinPos:titleHt 
	NVAR frameWid =root:packages:WinPos:frameWid
	
	
	SVAR OS = root:packages:WinPos:OS
	// OS specific stuff
	StrSwitch  (OS)
		case "Windows":
			theScreen = 0
			break
		case "Macintosh": 
			if (ParamIsDefault(theScreen)) // use default screen if none given
				NVAR macDefaultScreen = root:packages:WinPos:MacDefaultScreen
				theScreen = MacDefaultScreen
			endif
			break
		default:
			return 1
			break
	endswitch
	return Screens [theScreen] [kBottom] - Screens [theScreen] [kTop]
end


//*****************************************************************************************************************************
//  Gets width of given screen on Mac, or current width of Igor Application frame on Windows
// Last Modified 2013/10/21 by Jamie Boyd
Static Function ScreenWidth ([theScreen])
	variable theScreen
	
	// Package globals
	NVAR titleHt = root:packages:WinPos:titleHt 
	NVAR frameWid =root:packages:WinPos:frameWid
	WAVE Screens = root:packages:WinPos:Screens
	SVAR OS = root:packages:WinPos:OS
	// OS specific stuff
	StrSwitch  (OS)
		case "Windows":
			theScreen = 0
			break
		case "Macintosh": 
			if (ParamIsDefault(theScreen)) // use default screen if none given
				NVAR MacDefaultScreen = root:packages:WinPos:MacDefaultScreen
				theScreen = MacDefaultScreen
			endif
			break
		default:
			return 1
			break
	endswitch
	return Screens [theScreen] [kRight] - Screens [theScreen] [kLeft]
end