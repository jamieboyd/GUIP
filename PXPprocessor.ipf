#pragma rtGlobals=1		// Use modern global access method.
#include "CustomFolderLoad", version >=1.1
#include "ListObjects", version >=1.0
#include "SIsetVarProc"
#include "protofuncs"
// Last Modified Sep 07 2011
Menu "Macros"
	"Process PXPs", /Q, PXPp_Main ()
end

Function PXPp_Main ()

	if (!(DataFolderExists ("root:packages")))
		newDataFolder root:packages
	endif
	
	if (!(DataFolderExists ("root:packages:PXPp")))
		newDataFolder root:packages:PXPp
		make/n=0/t root:packages:PXPp:pxp_List
		make/n=0 root:packages:PXPp:pxp_Sel
		String/G root:packages:PXPp:pxpFolderStr
		Variable/G root:packages:PXPp:recursFolders
		string/G root:packages:PXPp:funcStr
	endif
	doWindow/F PXPprocessor
	if (V_Flag == 1)
		return 0
	endif
	NewPanel /K=1 /W=(0,44,348,399) as "PXP Processor"
	DoWindow/C PXPprocessor
	Button SelectFolderButton,pos={3,2},size={97,22},proc=PXPp_SetFolder,title="Select Folder"
	Button SelectFolderButton,help={"Allows you to select a folder on disk from whence to select packed experiment files (.pxps)."}
	Button SelectFolderButton,font="Geneva",fSize=12
	TitleBox FolderTitle,pos={104,4},size={229,24}
	TitleBox FolderTitle,help={"Shows the path to the folder on disk containing the packed experiment files to be processed"}
	TitleBox FolderTitle,fSize=12,variable= root:packages:PXPp:pxpFolderStr
	CheckBox Recurscheck,pos={9,39},size={86,14},title="Recurse Folders"
	CheckBox Recurscheck,variable= root:packages:PXPp:recursFolders
	CheckBox Recurscheck, help = {"When checked, listing of files is done recursively through all subfolders in selected folder."}
	Button UpdateFolderListButton,pos={104,35},size={92,22},proc=PXPp_UpdateFolder,title="Update List"
	Button UpdateFolderListButton,help={"Updates the contents of the selected folder, without choosing a new folder."}
	Button SelectAllButton,pos={201,35},size={114,22},proc=PXPp_SelectAllProc,title="Select All in List"
	Button SelectAllButton,help={"Selects all the files from the list of files in the selected directory on disk."}
	ListBox FilesList,pos={2,62},size={341,237},proc=PXPp_ListBoxProc
	ListBox FilesList,help={"Shows all the packed experiment files in the selected folder. Change order by dragging with Command/Ctrl key pressed. Select files to be processed, then click \"Do Selected\""}
	ListBox FilesList,fSize=12,listWave=root:packages:PXPp:pxp_List
	ListBox FilesList,selWave=root:packages:PXPp:pxp_Sel,mode= 8,userColumnResize= 1
	PopupMenu ProcessPopUp,pos={6,304},size={151,20},proc=PXPp_FunctionPopMenuProc,title="pxp Process function"
	PopupMenu ProcessPopUp,mode=0,value= #"FunctionList(\"*PXPp\", \";\", \"\" )"
	PopupMenu ProcessPopUp, help = {"Choose a function with which to process packed experiment files"}
	SetVariable ProcessFuncSetVar,pos={161,306},size={182,15},title=" ",frame=0
	SetVariable ProcessFuncSetVar,value= root:packages:PXPp:funcStr,noedit= 1
	SetVariable ProcessFuncSetVar, help = {"Shows currently selected function to process packed experiment files."}
	Button DoSelectedButton,pos={4,329},size={97,22},proc=PXPp_doSelected,title="Do Selected"
	Button DoSelectedButton,help={"Processes selected packed experimentfiles."}
	// set resizing hook
	setWindow PXPProcessor hook(reSizeHook )=PXPpResizeHook
end

//*****************************************************************************************************
// hook function that does control resizing/moving upon a resize event
// Do selected is at the bottom
// process function-added controls are above doSelected
// process popup/title is above 
// list box is above that taking up all avaiablbe space to buttons on top which never move
// Last Modified Sep 07 2011 by Jamie Boyd
Function PXPpResizeHook(s)
	STRUCT WMWinHookStruct &s

	if (s.eventCode ==6)
		variable curBottom = s.winRect.bottom-24
		// move DoSelected Button to Bottom
		Button DoSelectedButton  pos={4,(curBottom)}
		curBottom -= 24
		// find lowest control among func controls to get offset for them
		variable lowestFCpos = 0, highestFCpos = inf
		SVAR funcStr = root:packages:PXPp:funcStr
		string controlList = ControlNameList("PXPprocessor" , ";" , removeEnding (funcStr, "PXPp") + "*")
		variable iCtrl, nCtrls = itemsinList (controlList, ";")
		if (nCtrls  > 0)
			for (iCtrl = 0; iCtrl < nCtrls; iCtrl +=1)
				controlinfo/W=PXPprocessor $StringFromList(iCtrl,  controlList)
				if (V_top > lowestFCpos)
					lowestFCpos = V_top
				endif
				if (V_top < highestFCpos)
					highestFCpos = V_top
				endif
			endfor
			// move func controls to be just above DoSelected Button
			variable  FCadjust = curBottom - lowestFCpos
			for (iCtrl = 0; iCtrl < nCtrls; iCtrl +=1)
				PXPp_MoveControl (StringFromList(iCtrl,  controlList) , FCadjust)
			endfor
			curBottom -=  (lowestFCpos - highestFCpos)  +25
		endif
		// adjust PXP popup and title
		controlinfo /W=PXPprocessor ProcessPopUp
		PopupMenu ProcessPopUp win =PXPprocessor, pos = {V_left, curBottom}
		controlinfo /W=PXPprocessor ProcessFuncSetVar
		SetVariable ProcessFuncSetVar win =PXPprocessor, pos = {V_left, curBottom}
		// resize listBox
		controlinfo/W=PXPprocessor FilesList
		ListBox FilesList size = {s.winRect.right - V_left, curBottom - V_top}
		return 1
	endif
	return 0		// 0 if nothing done, else 1
End

//*****************************************************************************************************
// helper function for resizing/moving controls
// Last Modified Sep 07 2011 by Jamie Boyd
Function PXPp_MoveControl (name, moveAmount)
	string name
	variable moveAmount
	
	controlinfo/W=PXPprocessor $name
	variable xPos = V_left
	variable yPos = V_top + moveAmount
	switch (V_FLag)
		case  1:
			Button $name win = PXPprocessor, pos = {xPos, yPos}
			break
		case 2:
			CheckBox $name win = PXPprocessor,pos = {xPos, yPos}
			break
		case 3:
		case -3:
			PopupMenu $name win = PXPprocessor,pos = {xPos, yPos}
			break
		case 4:
		case -4:
			ValDisplay $name win = PXPprocessor, pos = {xPos, yPos}
			break
		case 5:
		case -5:
			SetVariable $name win = PXPprocessor, pos = {xPos, yPos}
			break
		case 6:
		case -6:
			Chart $name win = PXPprocessor,pos = {xPos, yPos}
			break
		case 7:
			Slider $name win = PXPprocessor, pos = {xPos, yPos}
			break
		case 8:
			TabControl $name win = PXPprocessor,  pos = {xPos, yPos}
			break
		case 9:
			GroupBox $name win = PXPprocessor, pos = {xPos, yPos}
			break
		case 10:
			TitleBox $name win = PXPprocessor, pos = {xPos, yPos}
			break
		case 11:
			ListBox $name win = PXPprocessor, pos = {xPos, yPos}
			break
	endswitch
end

//*****************************************************************************************************
//Sets a global string to the folder on disk where the files are located and lists the contents of that folder in the listbox
Function PXPp_SetFolder(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR folderStr = root:packages:PXPp:pxpFolderStr
	folderStr = CFL_SetImPathProc("PXPpimpPath", "Igor Experiments")
	WAVE/T pxpList = root:packages:PXPp:pxp_List
	WAVE pxpSel = root:packages:PXPp:pxp_Sel
	NVAR beRecursive =  root:packages:PXPp:recursFolders
	if (beRecursive)
		CFL_ShowFilesinFolderRecurs (pxpList, pxpSel, ".pxp", "????", "*", "PXPpimpPath")
	else
		CFL_ShowFilesinFolder (pxpList, pxpSel, ".pxp", "????", "*", "PXPpimpPath")
	endif
End

//*****************************************************************************************************
//Updates the list of files in the selected folder, without having to choose a new folder
Function PXPp_UpdateFolder(ctrlName) : ButtonControl
	String ctrlName

	WAVE/T pxpList = root:packages:PXPp:pxp_List
	WAVE pxpSel = root:packages:PXPp:pxp_Sel
	NVAR beRecursive =  root:packages:PXPp:recursFolders
	if (beRecursive)
		CFL_ShowFilesinFolderRecurs (pxpList, pxpSel, ".pxp", "????", "*", "PXPpimpPath")
	else
		CFL_ShowFilesinFolder (pxpList, pxpSel, ".pxp", "????", "*", "PXPpimpPath")
	endif
End

//*****************************************************************************************************
//Selects all files in the list
Function PXPp_SelectAllProc(ctrlName) : ButtonControl
	String ctrlName
	
	WAVE FolderListSelWave = root:packages:PXPp:pxp_Sel
	CFL_SelectAllProc(FolderListSelWave)
End

//*****************************************************************************************************
// Adds ability to drag-and-drop selected rows into new locations if Command key is held down 
// Last Modified Sep 02 2011 by Jamie Boyd
Function PXPp_ListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			// if command/ctrl key is down, make temp wave with selected rows
			if (lba.eventMod & 8) 
				variable nPnts = numpnts (selWave)
				variable nSelPnts = sum (selWave)
				make/w/u/o/n = (nSelPnts)root:packages:PXPp:SelRows
				make/t/o/n = (nSelPnts) root:packages:PXPp:SelText
				WAVE selRows = root:packages:PXPp:SelRows
				WAVE/T selText = root:packages:PXPp:SelText
				variable iSel, iPnt
				for (iSel=0, iPnt =0; iPnt < nPnts; iPnt +=1)
					if (selWave [iPnt] ==1)
						selRows [iSel] = iPnt
						SelText [iSel] = listWave [iPnt]
						iSel += 1
					endif
				endfor
			endif
			break
		case 2: // mouse up
			if (lba.eventMod & 8)
				// if command/ctrl key is down, remove seletced rows and reinsert them in new location
				WAVE/T/Z seltext =  root:packages:PXPp:selText
				WAVE/Z selRows = root:packages:PXPp:selRows
				if (WAVEexists (selRows))
					FindValue /I=(row) selRows
					if (V_Value > -1)
						DoAlert 0, "Can't move seleted rows to a selected row."
					else
						PXPp_Insert (listWave, selWave, row)
					endif
					killwaves/z selRows, seltext
				endif
			endif
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// helper function for listBox procedure
// Last Modified Sep 02 2011 by Jamie Boyd
function PXPp_Insert (listwave, selwave, insertHere)
	WAVE/T listWave
	WAVE selWave
	variable insertHere
	
	// selected rows and row numbers are already saved in global waves
	WAVE selRows = root:packages:PXPp:selRows
	WAVE/T seltext =  root:packages:PXPp:selText
	// Delete selected rows from ListBox waves
	variable iSel, nSelPnts = numPnts (selRows)
	for (iSel = nSelPnts-1; iSel >= 0; iSel -=1)
		DeletePoints selRows [iSel], 1, listwave, selWave//; doupdate
		if (selRows [iSel] < insertHere)
			insertHere -= 1
		endif
	endfor
	// add them back at selected location
	selWave =0
	insertpoints insertHere , nSelPnts, listWave, selWave//;doUpdate
	listWave [insertHere, insertHere + nSelPnts-1] = seltext [p - insertHere ]//;doupdate
	selWave [insertHere , insertHere + nSelPnts-1]  = 1
end

//*****************************************************************************************************
// sets the global string for the pxp processor function and invites any ancillary controls to be added to the panel
// function to add ancillary controls named same as processor function, but ending in PXPadd
// Controls should be named starting with name of processing function, - PXPp
// Last Modified Sep 07 2011 by Jamie Boyd
Function PXPp_FunctionPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			// reference function string
			SVAR funcStr = root:packages:PXPp:funcStr
			// try to remove old controls
			string controlList = ControlNameList("PXPprocessor" , ";" , removeEnding (funcStr, "PXPp") + "*")
			variable iCtrl, nCtrls = itemsinList (controlList, ";")
			for (iCtrl = 0; iCtrl < nCtrls; iCtrl +=1)
				KillControl /W=PXPprocessor $StringFromList(iCtrl,  controlList)
			endfor
			// set global string for process function
			funcStr = pa.popStr
			// add new controls below process popup
			ControlInfo /W=PXPprocessor  ProcessPopUp
			funcRef ProtoFuncV AddFunc = $removeEnding (funcStr, "PXPp") + "PXPadd"
			addFunc (V_top + V_Height + 1)
			// resize/move controls to accomodate new controls by calling resize hook function
			getwindow PXPprocessor wsize
			STRUCT WMWinHookStruct s
			s.eventCode=6
			s. winRect.bottom = V_bottom - V_top
			s.winRect.right = V_right - V_left
			PXPpResizeHook(s)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
//Processes all selected files with chosen function
function PXPp_doSelected(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR funcStr = root:packages:PXPp:funcStr
	funcRef ProtoFuncSS processFunc = $funcStr
	WAVE/T pxpList = root:packages:PXPp:pxp_List
	WAVE pxpSel = root:packages:PXPp:pxp_Sel
	variable ip, nP = numpnts (pxpList)
	pathInfo PXPpimpPath
	string impStr = S_Path
	for (ip = 0; ip < nP; iP +=1)
		if (pxpSel [iP] &1)
			processFunc (impStr, pxpList [ip])
		endif
	endfor
end