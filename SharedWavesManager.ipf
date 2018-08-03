#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion = 5.05

#include "CustomFolderLoad"
#include "ListObjects"
#include "killDisplayedWave"
//Last modified Oct 03 2012 by Jamie Boyd

//SharedWavesManager provides a simple interface to load, edit, and save waves that are shared with files on disk. 
//This provides an easy way to accumulate summary data from different experiments. 

//The left side of the SharedWavesManager control panel includes a listbox showing Igor Binary Waves in a chosen directory on the disk
// and controls to choose the directory and to load (as shared waves) Igor binary waves selected in the list box. 

// The left side of the  control panel has a list box for Igor waves in the chosen datafolder in the open Igor Experiment
// and controls to choose the datafolder and to save to the selected disk directory (as shared Igor Binary Waves) waves from this dataFolder

//The center of the control panel contains an embedded table showing the loaded waves, and  buttons to make new shared waves and to 
// save and unload from the experiment the shared waves selected in the embedded table.

menu "Macros"
	"Manage Shared Waves",/Q, SharedWaves_MenuStart ()
end

//*****************************************************************************************************
// when starting from menu, prompt for instance name, and don't wait for user to set datafolder and directory
Function SharedWaves_MenuStart ()

	string instanceName=""
	prompt instanceName, "Name for this Shared Waves Manager :"
	doPrompt "Shared Waves Manager", instanceName
	if (V_FLag)
		return 1
	else
		 SharedWaves_Init (instanceName,"","",0)
	endif
end

//*****************************************************************************************************
//Make some global values in a packages folder and make the sharedwavesmanager control panel
// a new folder will be made for each instance of shared waves manager. Each instance must have a unique name
// Last Modified Nov 16 2011 by Jamie Boyd
Function SharedWaves_Init (instanceName, inDirPathStr, inFldrStr, setDirAndFldr)
	string instanceName 
	string inDirPathStr
	string inFldrStr
	variable setDirAndFldr // if non-zero, set up pauseForUser until directory and datafolder are both valid
	
	string instanceClean =cleanupname (instanceName, 0)
	// initialize sharedwaves folder with list of instances, or add this instance to the list
	if (!(datafolderexists ("root:packages:")))
		newdatafolder root:packages
	endif
	if (!(datafolderexists ("root:packages:SharedWaves")))
		newdatafolder root:packages:sharedwaves
	endif
	// make dataFolder for this instance, if needed, and reference globals
	if (!(dataFolderExists ("root:packages:sharedWaves:" + instanceClean)))
		newDataFolder $"root:packages:sharedWaves:" + instanceClean
		//waves for the list box showing files in the selected directory
		make/t/n = 0 $"root:packages:sharedwaves:" + instanceClean + ":DirListWave"
		make/n = 0 $"root:packages:sharedwaves:" + instanceClean + ":DirListSelWave"
		//and in the selected data folder
		make/t/n = 0 $"root:packages:sharedwaves:" + instanceClean + ":FldrListWave"
		make/n = 0 $"root:packages:sharedwaves:" + instanceClean + ":FldrListSelWave"
		// the description of the path to the directory, written out in full for display on the control panel
		String/G $"root:packages:sharedWaves:" + instanceClean + ":dirPathDescStr" = ""
		// the name of the datafolder in the current Igor Experiment where shared waves will be loaded
		String/G $"root:packages:sharedWaves:" + instanceClean + ":fldrStr" = ""
	endif
	WAVE/T DirListWave = $"root:packages:sharedwaves:" + instanceClean + ":DirListWave"
	WAVE DirListSelWave = $"root:packages:sharedwaves:" + instanceClean + ":DirListSelWave"
	WAVE/T fldrListWave = $"root:packages:sharedwaves:" + instanceClean + ":FldrListWave"
	WAVE fldrListSelWave = $"root:packages:sharedwaves:" + instanceClean + ":FldrListSelWave"
	redimension/n = 0 DirListWave, DirListSelWave, fldrListWave, fldrListSelWave
	SVAR dirPathDescStr = $"root:packages:sharedWaves:" + instanceClean + ":dirPathDescStr"
	SVAR fldrStr = $"root:packages:sharedWaves:" + instanceClean + ":fldrStr"
	// Symbolic path - either passed as a an Igor Path or as a path description
	string dirPath =instanceClean + "_Path"
	if (cmpStr (inDirPathStr, "") != 0) // we were passed a string
		// check if inDirPath is the name of an existing Igor path and if so, use it.
		PathInfo/S $inDirPathStr
		if (V_flag ==1) // inDirPathStr is an existing Igor Path. Copy it to the path for this instance
			NewPath/O/Z $dirPath, S_path
			dirPathDescStr = S_path
		else // check if inDirPathStr is a description of a path to a directory
			GetFileFolderInfo/D/Q/Z=1 inDirPathStr
			if (V_Flag ==0) //  inDirPathStr is a valid path
				NewPath/O/Z $dirPath, S_path
				dirPathDescStr = S_path
			else // inDirPathStr is not valid.  Set it to ""
				inDirPathStr = ""
			endif
		endif
	endif
	if (cmpStr (inDirPathStr, "") == 0) // we were passed an empty string or a bad path...
		if (cmpStr (dirPathDescStr, "") != 0) // BUT we have existing path
			GetFileFolderInfo/D/Q/Z=1 dirPathDescStr
			if (V_Flag ==0) //  dirPathDescStr is a valid path
				NewPath/O/Z $dirPath, S_path
			else
				dirPathDescStr = "" // user will have to set it
			endif
		else
			dirPathDescStr = "" // user will have to set it
		endif
	endif
	// datafolder String
	if (cmpstr (inFldrStr, "") !=0)
		if (DataFolderExists (inFldrStr))
			fldrStr = inFldrStr
		else
			inFldrStr = ""
		endif
	endif
	if (cmpStr (inFldrStr, "") == 0) // passed empty string or a bad datafolder spec
		if (cmpStr (fldrStr, "") != 0) // but we have existing datafolder spec
			if (!(DataFolderExists (fldrStr)))
				fldrStr = ""
			endif
		endif
	endif
	// make control panel for this instance, if needed
	string panelName = instanceClean + "_SW"
	doWindow/F $panelName
	if (!(V_Flag ))
		NewPanel /K=1 /W=(2,44,971,521) as instanceName + " Shared Waves"
		DoWindow/C $panelName
		// Set/show directory on disk
		GroupBox SetDirGrp win=$panelName , pos={2,0},size={100,43},title="Set Me First",fSize=9,frame=0
		GroupBox SetDirGrp win=$panelName, fColor=(65535,0,0)
		Button SetPathButton win=$panelName ,pos={6,17},size={90,21},proc=SharedWaves_SetPathProc,title="Set Directory"
		Button SetPathButton win=$panelName,help={"Allows you to select the Shared Waves directory - where .ibw files for shared waves are located."}
		TitleBox SharedWavesPathTitle win=$panelName,pos={107,18}, size={394,16}
		TitleBox SharedWavesPathTitle win=$panelName, help={"Shows the path to the selected Shared Waves directory - where .ibw files for shared waves are locaed"}
		TitleBox SharedWavesPathTitle win=$panelName,fSize=12,frame=0
		TitleBox SharedWavesPathTitle win=$panelName,variable= dirPathDescStr
		// List box for files in directory
		ListBox SharedWavesList win=$panelName,pos={4,54},size={151,418}
		ListBox SharedWavesList win=$panelName,help={"Select waves to be be loaded from this list of all the .ibw files in the Shared Waves directory."}
		ListBox SharedWavesList win=$panelName,listWave=DirListWave
		ListBox SharedWavesList win=$panelName,selWave=DirListSelWave
		ListBox SharedWavesList win=$panelName,mode= 4
		// buttons managing directory list box
		Button UpdateDirButton win=$panelName,pos={159,58},size={84,22},proc=SharedWaves_UpdatePathListProc,title="Update Dir"
		Button UpdateDirButton win=$panelName,help={"Updates the list of .ibw files in the Shared Waves directory"}
		Button SelectAllDirButton win=$panelName,pos={160,88},size={84,22},proc=SharedWaves_SelectAllProc,title="Select All"
		Button SelectAllDirButton win=$panelName,help={"Selects all the files in the list of .ibw files in the Shared Waves directory"}
		Button LoadSelectedButton win=$panelName,pos={159,118},size={84,22},proc=SharedWaves_LoadSelectedProc,title="Share-->"
		Button LoadSelectedButton win=$panelName,help={"Loads shared  waves from .ibw files selected from the list of files in the Shared Waves directory."}
		// Set/Show Igor data folder
		GroupBox SetFldrGrp win=$panelName, pos={502,1},size={123,43}, title="Set Me First",fSize=9,frame=0
		GroupBox SetFldrGrp win=$panelName,fColor=(65535,0,0)
		PopupMenu DataFolderPopUp win=$panelName,pos={507,16},size={114,20},proc=SharedWaves_setDFProc,title="Set DataFolder"
		PopupMenu DataFolderPopUp win=$panelName,fSize=12
		PopupMenu DataFolderPopUp win=$panelName,mode=0,value= #"\"Current Folder-\" + getdatafolder(1)+ \";New Folder;\\\\M1-;\" + \"root:;\" +  ListObjectsRecursive(\"root:\", 4, \"*\") "
		PopupMenu DataFolderPopUp win=$panelName,help = {"Sets the Shared Waves data folder - from where waves to be shared will be selected, and to where waves loaded from .ibw files will be stored."}
		TitleBox DataFolderTitle win=$panelName,pos={629,18},size={338,16}, fSize=12,frame=0, variable= fldrStr
		TitleBox DataFolderTitle win=$panelName, help = {"Shows the Shared Waves data folder."}
		// List box for waves in data folder
		ListBox DataFolderWavesList win=$panelName,pos={814,54},size={151,418}
		ListBox DataFolderWavesList win=$panelName,help={"Select waves to be be saved to disk from this list of all the waves in the Shared Waves datafolder"}
		ListBox DataFolderWavesList win=$panelName,listWave=fldrListWave
		ListBox DataFolderWavesList win=$panelName,selWave=fldrListSelWave
		ListBox DataFolderWavesList win=$panelName,mode= 4
		// buttons for managing waves in data folder
		Button UpdateFldrButton win=$panelName,pos={725,58},size={84,22},proc=SharedWaves_UpdateFldrProc,title="Update Fldr"
		Button UpdateFldrButton win=$panelName, help = {"Updates the list of waves in the Shared Waves datafolder"}
		Button SelectAllFldrButton win=$panelName,pos={725,88},size={84,22},proc=SharedWaves_SelectAllProc,title="Select All"
		Button SelectAllFldrButton win=$panelName,help={"Selects all the waves in the list of  waves from the Shared Waves datafolder"}
		Button ShareWavesButton win=$panelName,pos={725,118},size={84,22},proc=SharedWaves_ShareDFProc,title="<--Share"
		Button ShareWavesButton win=$panelName, help = {"Saves selected waves as shared .ibw files in the Shared Waves directory"}
		//a table allowing editing and selecting of all the shared waves we are are managing
		Edit/W=(248,53,718,438)/HOST=# 
		RenameWindow #,SWT
		SetActiveSubwindow ##
		// Buttons for managing waves that are currently shared
		Button NewWaveButton win=$panelName,pos={192,446},size={122,22},proc=SharedWaves_NewWaveProc,title="New Shared Wave"
		Button NewWaveButton win=$panelName,help={"Makes a new Shared Wave in Shared Waves datafolder, shared with an .ibw file in the Shared Waves directory"}
		Button UnShareButton win=$panelName,pos={318,446},size={121,22},proc=SharedWaves_UnShareProc,title="Unshare Selected"
		Button UnShareButton win=$panelName,help={"adopts selected waves (or all shared waves, if shift key pressed) into the Experiment, breaking link with .ibw files in Shared Waves directory."}
		Button UpdateButton win=$panelName,pos={443,446},size={93,22},proc=SharedWaves_UpdateToDiskProc,title="Save Selected"
		Button UpdateButton win=$panelName,help={"Saves selected waves (or all shared waves if shift key pressed) to their shared .ibw files without having to save the entire Experiment"}
		Button KillButton win=$panelName,pos={541,446},size={86,22},proc=SharedWaves_KillSelectedProc,title="Kill Selected"
		Button KillButton win=$panelName,help={"Kills selected waves (or all shared waves if shift key pressed) including the shared .ibw files."}
		Button SortButton win=$panelName,pos={632,446},size={44,22},proc=SharedWaves_SortButtonProc,title="Sort"
		Button SortButton win=$panelName,help={"Sorts selected waves (or all shared waves if shift key pressed) by a key wave chosen from a menu"}
		Button SaveAsTextButton win=$panelName,pos={683,446},size={86,22},proc=SharedWaves_WriteDelimTextProc,title="Save as Text"
		Button SaveAsTextButton win=$panelName,help={"Saves selected waves (or all shared waves if shift key pressed) as a single tab-delimitted (or comma-delimitted if command/control key pressed) text file"}
		// fixed size option for title boxes not compatible with Igor 5
		if (NumberByKey("IGORVERS", IgorInfo(0), ":", ";") >= 6)
			Execute/Q "TitleBox SharedWavesPathTitle win=" + panelName + ", fixedSize =1"
			Execute/Q "TitleBox DataFolderTitle win=" + panelName + ", fixedSize =1"
			
		endif
		// set resizing hook
		setWindow $panelName hook(ReSizeHook )=SharedWaves_ResizeHook
	endif
	// check that symbolic path and Igor dataFolder are valid and return this info, bitwise bit 0 for directory and bit 1 for dataFolder
	variable returnVal = 0
	if (cmpstr (dirPathDescStr, "") !=0)
		returnVal +=1
		groupbox SetDirGrp  win=$panelName, disable =1
		STRUCT WMButtonAction ba
		ba.eventCode = 2
		ba.win = InstanceClean + "_SW"
		SharedWaves_UpdatePathListProc(ba)
	endif
	if ((dataFolderExists (fldrStr)) && (cmpstr (fldrStr, "") != 0)) // the data foler "" always exists; you're in it right now! (relative path to current datafolder)
		returnVal +=2 // datafolder found
		groupbox SetFldrGrp  win=$panelName, disable =1
		SharedWaves_UpdateFldr (instanceClean)
	endif
	// if both are valid, look for already shared waves
	if (returnVal == 3)
		SharedWaves_UpdateShared (instanceClean)
	else // ensure dhared waves table is blank
		SharedWaves_CleanShared (instanceClean)
	endif
	// if requested, make sure both directory and data folder are valid
	if ((setDirAndFldr ==1) && (returnVal < 3))
		newpanel/N=swmSetWarn/W=(150,50,462,154) as instanceName + " Shared Waves Warning"
		TitleBox WarningTitle,pos={42,8},size={218,38},title="Please set a Valid Disk Directory and\rIgor Pro DataFolder then click \"O.K.\"."
		TitleBox WarningTitle,fSize=14,frame=0
		Button okButton,pos={112,58},size={50,20},proc=SharedWaves_ValidButtonProc,title="O.K."
		string/G root:packages:sharedWaves:WarnInstance = instanceClean
		pauseForUser swmSetWarn, $panelName
	endif
	return returnVal
end

//*****************************************************************************************************
// hook function that does control resizing/moving upon a resize event
// Last Modified Dec 01 2011 by Jamie Boyd
function SharedWaves_ResizeHook(s)
	STRUCT WMWinHookStruct &s
	
	if (s.eventCode ==6)
		// test for minimum width,  height
		variable doMove=0
		if (s.winRect.right < 580)
			s.winRect.right  = 580
			doMove += 1
		endif
		if (s.winRect.bottom < 220)
			s.winRect.bottom = 220
			doMove +=2
		endif
		if (doMove > 0)
			GetWindow $s.winName wsize
			variable winFudge=(72/ScreenResolution)
			switch (doMove)
				case 1: // adjust length only
					movewindow /w=$s.winName ( winFudge * V_left), (winFudge * V_Top), (winFudge * (V_left + 580)), (winFudge* (V_bottom))
					break
				case 2: // adjust height only
					movewindow /w=$s.winName ( winFudge * V_left), (winFudge * V_Top), (winFudge * (V_Right)), (winFudge* (V_Top + 220))
					break
				case 3: // adjust both length and height
					movewindow /w=$s.winName ( winFudge * V_left), (winFudge * V_Top), (winFudge * (V_left + 580)), (winFudge* (V_Top + 220))
					break
			endswitch
		endif
		// adjust position of datafolder popup and title
		variable leftPos = s.winRect.right/2
		PopupMenu  DataFolderPopUp win= $s.winName,  pos={leftPos,16}
		TitleBox DataFolderTitle  win= $s.winName, pos={(leftPos + 120),17}, size = {(s.winRect.right - (leftPos + 120)), 16}
		// adjust length of pathTitle
		TitleBox SharedWavesPathTitle win= $s.winName, size={(leftPos - 112),16}
		// adjust "editing"  buttons at bottom of panel
		variable bottomPos = s.winRect.bottom-24
		variable buttonLeft = (s.winRect.right - 575)/2
		Button NewWaveButton win= $s.winName, pos={(buttonLeft),(bottomPos)}
		buttonLeft += 126
		Button UnShareButton win= $s.winName, pos={buttonLeft,(bottomPos)}
		buttonLeft += 125
		Button UpdateButton win= $s.winName, pos={buttonLeft,(bottomPos)}
		buttonLeft += 98
		Button KillButton win= $s.winName, pos={buttonLeft,(bottomPos)}
		buttonLeft += 90
		Button SortButton win= $s.winName, pos={buttonLeft,(bottomPos)}
		buttonLeft += 49
		Button SaveAsTextButton win= $s.winName, pos={buttonLeft,(bottomPos)}
		// adjust height of list boxes and position of datafolder list box
		variable listboxsize= s.winRect.bottom - 56
		if (((s.winRect.right - 575)/2) < 157)
			listboxsize -= 26
		endif
		leftPos = s.winRect.right - 153
		ListBox SharedWavesList win= $s.winName, size={151,listboxsize}
		ListBox DataFolderWavesList win= $s.winName, pos={leftPos,54}, size={151,listboxsize}
		// adjust positions of folder buttons
		leftPos -= 88
		Button UpdateFldrButton win= $s.winName, pos={leftPos,58}
		Button SelectAllFldrButton win= $s.winName, pos={leftPos,88}
		Button ShareWavesButton win= $s.winName, pos={leftPos,118}
		// resize table subwindow
		MoveSubwindow /W=$s.winName  + "#SWT" fnum=(248, 53, (leftPos -2), (bottomPos -2))
		return 1
	endif
	return 0		// 0 if nothing done, else 1
End

//*****************************************************************************************************
// Makes sure that directory and datafolder are valid. If so, kill the window to exit pause for user.
// Last Modified Nov 2 2011 by Jamie Boyd
Function SharedWaves_ValidButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			variable Valid = 0
			SVAR warnInstance =  root:packages:sharedWaves:WarnInstance 
			string instanceClean = cleanupname (warnInstance, 0)
			string panelName = instanceClean +  "_SW"
			string dirPath =  instanceClean  + "_Path"
			SVAR dirPathDescStr = $"root:packages:sharedWaves:" + instanceClean + ":dirPathDescStr"
			GetFileFolderInfo/D/Q/Z=1 dirPathDescStr
			if (V_Flag ==0) // directory was found
				Valid +=1
			endif
			SVAR folderStr = $"root:packages:sharedWaves:" + instanceClean + ":fldrStr"
			if ((dataFolderExists (folderStr)) && (cmpstr (folderStr, "") != 0))
				Valid +=2
			endif
			if (Valid ==3)
				doWindow/K swmSetWarn
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
//  Looks if waves are already shared between the Shared Waves directory on disk and the Shared Waves Datafolder, and adds them to the Shared Waves Table
// Make sure the list boxes are updated before calling this function, or you may have waves in the table that don't appear in the lists of available waves
// Last modified Jan 13 2012 by Jamie Boyd
Function SharedWaves_UpdateShared (instanceClean)
	string instanceClean
	
	SharedWaves_CleanShared (instanceClean)
	SVAR fldrStr = $"root:packages:sharedWaves:" + instanceClean + ":fldrStr"
	string importPathStr = InstanceClean + "_Path"
	string fldrwaves = ListObjects(fldrStr, 1, "*", 0, "")
	variable iWave, nWaves = itemsinlist (fldrwaves, ";")
	string tableName = instanceClean + "_SW#SWT"
	string wavePath 
	for (iWave =0;iWave < nWaves; iWave +=1)
		WAVE aWave = $fldrStr + stringfromlist (iWave, fldrwaves, ";")
		wavePath = stringBYkey ("PATH", waveinfo (aWave, 0), ":", ";")
		if (cmpStr (wavePath, ImportPathStr) == 0) // the wave is loaded from the shared waves directory and has same name, it's probably the same wave, so add to the table
			AppendToTable /W=$tableName  aWave
			if (cmpstr (waveUnits(aWave, -1), "dat") ==0)
				ModifyTable/W=$tableName format(aWave)=8
			elseif (wavetype (aWave) == 4)
				ModifyTable /W= $tableName sigDigits(aWave)=16
			else
				ModifyTable /W= $tableName sigDigits(aWave)=8
			endif
		endif
	endfor
end

//*****************************************************************************************************
//  Removes all the waves from the shared waves table
// Last modified Nov 16 2011 by Jamie Boyd
Function SharedWaves_CleanShared (instanceClean)
	string instanceClean
	
	string info = TableInfo (instanceClean + "_SW#SWT", -2)
	variable iCol, lastCol =NumberByKey("COLUMNS", info , ":", ";") -2
	string colWaveStr
	for (iCol =lastCol; iCol >= 0; iCol -=1) 
		colWaveStr = stringbykey ("WAVE", TableInfo (instanceClean + "_SW#SWT", iCol), ":", ";")
		WAVE colwave = $colWaveStr
		RemoveFromTable/W= $instanceClean + "_SW#SWT" $colWaveStr
	endfor
end

//*****************************************************************************************************
//set the path to the directory on disk
// Last modified Nov 16 2011 by Jamie Boyd
Function SharedWaves_SetPathProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = stringfromlist (0, ba.win, "_")
			WAVE/T DirListWave = $"root:packages:sharedwaves:" + instanceClean + ":DirListWave"
			WAVE DirListSelWave = $"root:packages:sharedwaves:" + instanceClean + ":DirListSelWave"
			SVAR pathDescStr = $"root:packages:sharedWaves:" + instanceClean + ":dirPathDescStr"
			string newPathDesc =  CFL_SetImPathProc(instanceClean + "_Path", "Igor binary waves and saving them")
			if (cmpStr (newPathDesc, "") != 0)
				groupbox SetDirGrp  win=$ba.win, disable =1
				pathDescStr =newPathDesc
				CFL_ShowFilesinFolder (DirListWave, DirListSelWave, ".ibw", "", "", instanceClean + "_Path")
				// if we have a folder, update shared waves
				SVAR fldrStr = $"root:packages:sharedwaves:" + instanceClean + ":fldrStr"
				if ((cmpStr (fldrStr, "") != 0) && (dataFolderExists (fldrStr)))
					SharedWaves_UpdateShared (instanceClean)
				else
					 SharedWaves_CleanShared (instanceClean)
				endif
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
//Updates the listing of the contents of the disk directory pointed to by SharedWavesPath by calling SharedWaves_UpdatePathList
// Last modified Nov 18 2011 by Jamie Boyd
Function SharedWaves_UpdatePathListProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = stringfromlist (0, ba.win, "_")
			SharedWaves_UpdatePathList (instanceClean)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


//*****************************************************************************************************
//Updates the listing of the contents of the disk directory pointed to by SharedWavesPath
// Last modified Nov 18 2011 by Jamie Boyd
Function SharedWaves_UpdatePathList (instanceClean)
	string instanceClean
	
	WAVE/T DirListWave = $"root:packages:sharedwaves:" + instanceClean + ":DirListWave"
	WAVE DirListSelWave = $"root:packages:sharedwaves:" + instanceClean + ":DirListSelWave"
	CFL_ShowFilesinFolder (DirListWave, DirListSelWave, ".ibw", "", "", instanceClean + "_Path")
end

//*****************************************************************************************************
//Select all the files in the list of Igor Binary waves in the chosen directory, or all the waves in the chosen data folder
// Last modified Oct 21 2011 by Jamie Boyd
Function SharedWaves_SelectAllProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = stringfromlist (0, ba.win, "_")
			if (cmpStr (ba.ctrlName, "SelectAllDirButton") ==0)
				WAVE ListSelWave = $"root:packages:sharedwaves:" + instanceClean + ":DirListSelWave"
			else
				WAVE ListSelWave = $"root:packages:sharedwaves:" + instanceClean + ":FldrListSelWave"
			endif
			CFL_SelectAllProc(ListSelWave)
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// load (into the chosen folder) as shared waves  the files selected from the listbox showing files in the directoy
// Gives user option to rename or overwrite previously existing waves in the chosen folder with the same name
// Last modified Nov 2 2011 by Jamie Boyd
Function SharedWaves_LoadSelectedProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch(ba.eventCode)
		case 2: // mouse up
			string instanceClean = stringfromlist (0, ba.win, "_")

			STRUCT CFL_loadStruct s
			s.importPathStr = instanceClean + "_Path"
			SVAR TargetFolderStr = $"root:packages:sharedWaves:" + instanceClean + ":fldrStr"
			WAVE/T s.FolderListWave = $"root:packages:sharedwaves:" + instanceClean + ":DirListWave"
			WAVE s.FolderListSelWave = $"root:packages:sharedwaves:" + instanceClean + ":DirListSelWave"
			s.TargetFolderStr=TargetFolderStr
			funcref CFL_LoadProtoFunc s.LoadFunc = SharedWaves_LoadFunc
			funcref CFL_ProcessProtoFunc s.ProcessFunc = SharedWaves_ProcessFunc
			s.loadOptionStr =instanceClean
			s.processOptionStr = instanceClean
			s.overWrite = 2
			s.WaveRename =2
			CFL_CustomFolderLoad (s)
			SharedWaves_UpdateFldr (instanceClean)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// loads an individual .ibw as a shared wave, and tries to harmonize with waves already in dataFolder
// last modified Jan 13 2012 by Jamie Boyd
function SharedWaves_LoadFunc(ImportPathStr, FileNameStr, instanceClean)
	string ImportPathStr	// string containing the name of an Igor path to the folder on disk from which to import files (ImportPath)
	string FileNameStr	// string containing the name of the selected file
	string instanceClean	// option string used to pass name of instance of shared waves manager
	
	// does a wave with the same name as the .ibw file already exist in the dataFolder?
	SVAR fldrStr = $"root:packages:sharedWaves:" + instanceClean + ":fldrStr"
	String newWaveName = removeEnding (filenameStr, ".ibw") 
	WAVE/Z alreadyLoadedWave = $fldrStr + newWaveName
	SVAR pathDescStr = $"root:packages:sharedWaves:" + instanceClean + ":dirPathDescStr"
	string tableName = instanceClean + "_SW#SWT"
	if (WaveExists (alreadyLoadedWave))
		string wavePath = stringBYkey ("PATH", waveinfo (alreadyLoadedWave, 0), ":", ";")
		PathInfo $wavePath
		if ((V_Flag ==1) && (cmpStr (S_Path, pathDescStr) ==0))
			AppendToTable/W=$tableName  alreadyLoadedWave
			if (cmpstr (waveUnits(alreadyLoadedWave, -1), "dat") ==0)
				ModifyTable/W=$tableName format(alreadyLoadedWave)=8
			elseif (wavetype (alreadyLoadedWave) == 4)
				ModifyTable /W= $tableName sigDigits(alreadyLoadedWave)=16
			else
				ModifyTable /W= $tableName sigDigits(alreadyLoadedWave)=8
			endif
		else // alert the user to the conflict
			doAlert 2, "A Wave named  \"" + newWaveName + "\" already exists in the \"" + instanceClean +"\" datafolder. Press \"Yes\" to replace the existing wave. Press \"No\" to replace the .ibw file. Press \"Cancel\" to leave both file and wave unchanged"
			if (V_Flag == 1) // yes to overwriting existing wave,
				// Load the wave  - into the CFL "SandBox" folder
				LoadWave/O/P=$ImportPathStr FileNameStr
				// there is very slight possibility that wave name and .ibw file name may be out of synch
				if (cmpStr (newWaveName , stringfromlist (0, S_waveNames, ";")) != 0)
					doAlert 0, "FYI: the name of the wave loaded from the file did not match the file name. Shared Waves Manager frowns on this behaviour."
				endif
			elseif (V_Flag == 2) // no to overwriting wave, but go the other way, overwriting .ibw file with wave
				Save/O/P= $ImportPathStr alreadyLoadedWave as LowerStr(FileNameStr )
				AppendToTable /W=$tableName  alreadyLoadedWave
				if (cmpstr (waveUnits(alreadyLoadedWave, -1), "dat") ==0)
					ModifyTable/W=$tableName format(alreadyLoadedWave)=8
				elseif (wavetype (alreadyLoadedWave) == 4)
					ModifyTable /W= $tableName sigDigits(alreadyLoadedWave)=16
				else
					ModifyTable /W= $tableName sigDigits(alreadyLoadedWave)=8
				endif
			endif
		endif
	else // no conflicts, just load the file
		LoadWave/O/P=$ImportPathStr FileNameStr
	endif			
End

//*****************************************************************************************************
// adds a loaded individual wave to the table for this instance of shared waves manager, after being moved by CFL into the dataFolder
// last modified Jan 13 2011 by Jamie Boyd
Function SharedWaves_ProcessFunc(LoadedWave, ImportPathStr, FileNameStr, instanceClean)
	Wave LoadedWave	// A reference to the loaded wave
	string ImportPathStr	// string containing the name of an Igor path to the folder on disk from which to import files (ImportPath)
	string FileNameStr		// string containing the name of the file on disk from where the wave was loaded
	string instanceClean  // option string used to pass name of instance of shared waves manager
	
	string tableName = instanceClean + "_SW#SWT"
	AppendToTable /W=$tableName  loadedWave
	if (cmpstr (waveUnits(LoadedWave, -1), "dat") ==0)
		ModifyTable/W=$tableName format(loadedWave)=8
	elseif (wavetype (loadedWave) == 4)
		ModifyTable /W= $tableName sigDigits(loadedWave)=16
	else
		ModifyTable /W= $tableName sigDigits(loadedWave)=8
	endif
End
	
//*****************************************************************************************************
//Selects datafolder to put shared waves in and to get shared waves from. Appends waves in datafolder to DataFolderWavesList
// Last modified Oct 21 2011 by Jamie Boyd
Function SharedWaves_setDFProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			string instanceClean = stringfromlist (0, pa.win, "_")
			SVAR DataFolderStr = $"root:packages:sharedwaves:" + instanceClean +":fldrStr"
			switch (pa.popnum)
				case 1: // current folder
					DataFolderStr = getdatafolder (1)
					break
				case 2: //new folder
					string folderHere = DataFolderStr
					string folderName = "New"
					Prompt FolderHere, "Make New DataFolder Here:" , popup,  "root:;" + ListObjectsRecursive("root:", 4, "*")
					Prompt folderName, "Name for new DataFolder:"
					DoPrompt "Make a new DataFolder", FolderHere, FolderName
					if (V_flag==1)
						DatafolderStr = getdatafolder (1)
					else
						foldername = cleanupname (foldername, 1)
						newdatafolder/o $folderhere  +  foldername
						DataFolderStr = folderhere  +  foldername + ":"
					endif
					break
				default:
					DatafolderStr = pa.popStr
					break
			endswitch
			groupbox SetFldrGrp  win=$pa.win, disable =1
			// update list box for waves in datafolder
			SharedWaves_UpdateFldr (instanceClean)
			// if we have a path, update the table
			PathInfo $instanceClean + "_Path"
			if (V_Flag ==1)
				SharedWaves_UpdateShared (instanceClean)
			else
				 SharedWaves_CleanShared (instanceClean)
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// Button function to update  the listbox that shows the contents of the dataFolder slected for sharing waves
// last modified Nov 2 2011 by Jamie Boyd
Function SharedWaves_UpdateFldrProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = StringFromList(0, ba.win , "_") 
			SharedWaves_UpdateFldr (instanceClean)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//*****************************************************************************************************
// Updates the listbox that shows the contents of the dataFolder slected for sharing waves
// last modified Oct 21 2011 by Jamie Boyd
function SharedWaves_UpdateFldr (instanceClean)
	string instanceClean // cleaned up name of this instance of shared waves manager
	
	SVAR DataFolderStr = $"root:packages:sharedwaves:" + instanceClean +":fldrStr"
	WAVE/T ListWave = $"root:packages:sharedwaves:" + instanceClean + ":FldrListWave"
	WAVE SelWave =$"root:packages:sharedwaves:" + instanceClean + ":FldrListSelWave"
	string waves = ListObjects(DataFolderStr, 1, "*", 0, "")
	variable ii, nWaves = itemsinlist (waves, ";")
	Redimension/N=(nWaves) ListWave, SelWave
	for (ii = 0; ii < nWaves; ii += 1)
		ListWave [ii] = stringfromlist (ii, waves, ";")
	endfor
	selWave =0 // make sure nothing is selected in the listbox			
end

//*****************************************************************************************************
// Shares Selected  waves by saving them to selected directory, trying to harmonize with existing .ibw files
// Last modified Nov 18 2011 by Jamie Boyd
Function SharedWaves_ShareDFProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = stringFromList (0, ba.win, "_")
			string sharedWavesPath = instanceClean + "_Path"
			SVAR dfStr = $"root:packages:SharedWaves:" + instanceClean +":fldrStr"
			SVAR dirPathDescStr = $"root:packages:SharedWaves:" + instanceClean +":dirPathDescStr"
			WAVE/T dfList = $"root:packages:SharedWaves:" + instanceClean +":fldrListWave"
			WAVE dfSelList = $"root:packages:SharedWaves:" + instanceClean +":fldrListSelWave"
			variable iPos, nPos = numpnts (dfList)
			string wavePath, savedFolder
			string tableName = instanceClean + "_SW#SWT"
			for (iPos= 0; iPos < nPos ;iPos +=1)
				if ((dfSelList [iPos] & 1))
					WAVE theWave = $dfStr + dfList [iPos]
					// does a file with the same name already exists in the directory?
					GetFileFolderInfo/Q/Z=1 dirPathDescStr + dfList [iPos] + ".ibw"
					if (V_Flag == 0) //such a file exists
						wavePath = stringBYkey ("PATH", waveinfo (theWave, 0), ":", ";")
						pathinfo $wavePath
						if ((V_Flag ==1) && (cmpStr (S_Path, dirPathDescStr)==0)) // it's the same wave, already shares
							AppendToTable /W=$tableName  theWave
						else // it's not the same wave
							doAlert 2, "A file named  \"" +  dfList [iPos] + ".ibw\" already exists in the \"" + instanceClean +"\" directory. Press \"Yes\" to replace the existing .ibw file. Press \"No\" to replace the wave. Press \"Cancel\" to leave both wave and .ibw file unchanged"
							if (V_Flag == 3) // Cancel
								continue
							elseif (V_Flag ==2) // overwrite the wave with the .ibw replacement
								// Load the wave
								savedFolder = getdatafolder (1)
								setdatafolder $dfStr
								LoadWave/O/P=$sharedWavesPath  dfList [iPos] + ".ibw"
								AppendToTable /W=$tableName theWave
								setdatafolder $savedFolder
							elseif (V_Flag ==1) // overwrite .ibw with wave
								Save/O/P= $SharedWavesPath theWave as LowerStr(dfList [iPos]) + ".ibw"
								AppendToTable /W=$tableName  theWave
							endif
						endif
					else // no matching .ibw file exists
						Save/O/P= $SharedWavesPath theWave as LowerStr(dfList [iPos]) + ".ibw"
						AppendToTable /W=$tableName  theWave
					endif
				endif
				if (cmpstr (waveUnits(theWave, -1), "dat") ==0)
					ModifyTable/W=$tableName format(theWave)=8
				elseif (wavetype (theWave) == 4)
					ModifyTable /W= $tableName sigDigits(theWave)=16
				else
					ModifyTable /W= $tableName sigDigits(theWave)=8
				endif
			endfor
			SharedWaves_UpdatePathListProc(ba) 
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
//Makes a new Igor Binary wave and saves it as a shared wave in the chosen directory and dataFolder.
// Overwrites files with same name that may be in the chosen directory or dataFolder
// Last modified Jan 13 2012 by Jamie Boyd
Function SharedWaves_NewWaveProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = stringfromlist (0, ba.win, "_")
			SVAR DataFolderStr = $"root:packages:sharedwaves:" + instanceClean +":fldrStr"
			string pathStr = instanceClean + "_Path"
			// prompt for new wave name and dataType
			string newWavename
			variable dType, isUnsigned
			Prompt newWavename, "Name for new wave:"
			Prompt dtype, "Data type of new wave:", popup, "32-bit float;64-bit float;8-bit int;16-bit int;32-bit int;text"
			Prompt isUnsigned, "Integer types are:", popup "signed;unsigned"
			DoPrompt "Make a new shared wave", newWaveName, dtYpe, isUnsigned
			if (V_flag==1)
				return 1
			endif
			// check for wave and .ibw file
			variable newFileExists = 0
			SVAR dirPathDescStr =  $"root:packages:sharedwaves:" + instanceClean +":dirPathDescStr"
			GetFileFolderInfo/Q/Z=1 dirPathDescStr +newwavename + ".ibw"
			if (V_Flag ==0) // file  was found
				newFileExists = 1
			endif
			newWaveName = cleanupname (newWaveName, 0)
			string newwavenameAndPath = DataFolderStr + newwavename
			variable newWaveExists = 0
			if (waveExists ($newwavenameAndPath))
				newWaveExists = 1 // file was found
				WAVE oldWave = $newwavenameAndPath
				// NOTE: overwriting will fail if overwriting a text wave with a numeric wave
				if  ((dtype == 6) && (wavetype (oldWave) != 0)) 
					doalert 0, "A numeric wave with the name \"" + newWaveName + "\" already exists and, sadly, you can't overwrite a numeric wave with a text wave."
					return 1
				elseif ((dtype != 6) && (wavetype (oldWave) == 0)) 
					doalert 0, "A text wave with the name \"" + newWaveName + "\" already exists and, sadly, you can't overwrite a text wave with a numeric wave."
					return 1
				endif
			endif
			if ((newWaveExists) || (newFileExists))
				if((newWaveExists) && (newFileExists))
					doalert 1, "Both a wave and an .ibw file with the name \"" + newWaveName + "\"  already exist. Overwrite them?"
				elseif (newWaveExists)
					doalert 1, "A wave with the name \"" + newWaveName + "\"  already exists. Overwrite it?"
				elseif (newFileExists)
					doalert 1, "An .ibw file with the name \"" + newWaveName + "\"  already exists. Overwrite it?"
				endif
			endif
			if (V_Flag == 2)
				return 1
			endif
			// array of dataTypes (WM format)
			//Type				Bit #
			//complex			0 =1  // not allowed for shared waves manager
			//32-bit float		1 =2
			//64-bit float		2 =4
			//8-bit integer		3 =8
			//16-bit integer	4 =16
			//32-bit integer	5 =32
			//unsigned			6 =64
			variable bitWiseType
			if (dtype == 6)
				bitWiseType =0
			else
				bitWiseType =2^dtype + (isUnsigned-1)*2^6
			endif
			make/o/Y=(bitWiseType)/n=0 $newwavenameAndPath
			WAVE newWave = $newwavenameAndPath
			Save/o/P= $pathStr newWave as LowerStr (newWaveName) + ".ibw"
			string tableName = instanceClean + "_SW#SWT"
			AppendToTable /W=$tableName newWave
			if (cmpstr (waveUnits(newWave, -1), "dat") ==0)
				ModifyTable/W=$tableName format(newWave)=8
			elseif (wavetype (newWave) == 4)
				ModifyTable /W= $tableName sigDigits(newWave)=16
			else
				ModifyTable /W= $tableName sigDigits(newWave)=8
			endif
			doUpdate
			WAVE/T FolderListWave = $"root:packages:sharedwaves:" + instanceClean + ":dirListWave"
			WAVE FolderListSelWave =  $"root:packages:sharedwaves:" + instanceClean + ":dirListSelWave"
			CFL_ShowFilesinFolder (FolderListWave, FolderListSelWave, ".ibw", "????", "*", pathStr) 
			SharedWaves_UpdateFldr (instanceClean)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// Unshares Selected waves by saving with/H option, breaking the link between files on disk and waves in datafolder
// If shift key pressed, unshares all waves
// Last modified Jan 24 2012 by Jamie Boyd
Function SharedWaves_UnShareProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = stringFromList (0, ba.win, "_")
			variable isValid
			string sharedWavesPath = SharedWaves_GetDirPath (instanceCLean, isValid)
			if(!(isValid))
				return 1
			endif
			string sharedWavesdf =SharedWaves_GetDataFolder(instanceCLean, isValid)
			if(!(isValid))
				return 1
			endif
			if (NumberByKey("IGORVERS", IgorInfo(0), ":", ";") < 6)
				string savedFolder = getdatafolder (1)
				setdatafolder (sharedWavesdf)
			endif
			string info = TableInfo (instanceClean + "_SW#SWT", -2)
			variable firstCol, lastCol
			if (ba.eventMod &2) // do All
				firstCol = 0
				lastCol = NumberByKey("COLUMNS", info , ":", ";") -2
			else
				string Selected = stringByKey ("SELECTION", info, ":", ";") //firstRow , firstCol , lastRow , lastCol
				firstCol = str2num (stringfromlist (1, Selected, ","))
				lastCol = str2num (stringfromlist (3, Selected, ","))
			endif
			variable iCol
			string colWaveStr
			for (iCol =lastCol; iCol >= firstCol; iCol -=1) 
				colWaveStr = stringfromlist (0, stringbykey ("COLUMNNAME", TableInfo (instanceClean + "_SW#SWT", iCol), ":", ";"), ".")
				if (NumberByKey("IGORVERS", IgorInfo(0), ":", ";") < 6)
					LoadWave/Q/H/O/P=$sharedWavesPath colWaveStr + ".ibw"
				else
					execute/Q "Save/H " + sharedWavesdf + colWaveStr
				endif
				RemoveFromTable/W= $instanceClean + "_SW#SWT" $sharedWavesdf + colWaveStr
			endfor
			if (NumberByKey("IGORVERS", IgorInfo(0), ":", ";") < 6)
				setdatafolder (savedFolder)
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// Updates the directory copy of selected waves
// if shift key pressed, updates all waves
// Last modified Nov 29 2011 by Jamie Boyd
Function SharedWaves_UpdateToDiskProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = stringFromList (0, ba.win, "_")
			string sharedWavesPath = instanceClean + "_Path"
			string info = TableInfo (instanceClean + "_SW#SWT", -2)
			variable firstCol, lastCol
			if (ba.eventMod &2) // do All
				firstCol = 0
				lastCol = NumberByKey("COLUMNS", info , ":", ";") -2
			else // do selected
				string Selected = stringByKey ("SELECTION", info, ":", ";") //firstRow , firstCol , lastRow , lastCol
				firstCol = str2num (stringfromlist (1, Selected, ","))
				lastCol = str2num (stringfromlist (3, Selected, ","))
			endif
			variable iCol
			string colWaveStr, colType
			for (iCol =lastCol; iCol >= firstCol; iCol -=1) 
				colWaveStr = stringbykey ("WAVE", TableInfo (instanceClean + "_SW#SWT", iCol), ":", ";")
				WAVE colwave = $colWaveStr
				Save/o/P= $SharedWavesPath colwave as LowerStr(nameofWave (colWave)) + ".ibw"
			endfor
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// Kills selected shared waves, and deletes the .ibw file in the directory
// if shift key pressed, kills all shared waves
// Last modified Nov 15 2011 by Jamie Boyd
Function SharedWaves_KillSelectedProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = stringFromList (0, ba.win, "_")
			string sharedWavesPath = instanceClean + "_Path"
			string info = TableInfo (instanceClean + "_SW#SWT", -2)
			variable firstCol, lastCol
			if (ba.eventMod &2) // do All
				doAlert 1, "This action will delete all waves in the Shared Waves table. Are you sure?"
				if (V_Flag == 2)
					return 1
				endif
				firstCol = 0
				lastCol = NumberByKey("COLUMNS", info , ":", ";") -2
			else // do selected
				string Selected = stringByKey ("SELECTION", info, ":", ";") //firstRow , firstCol , lastRow , lastCol
				firstCol = str2num (stringfromlist (1, Selected, ","))
				lastCol = str2num (stringfromlist (3, Selected, ","))
			endif
			variable iCol
			string colWaveStr, colNameStr
			for (iCol =lastCol; iCol >= firstCol; iCol -=1) 
				colWaveStr = stringbykey ("WAVE", TableInfo (instanceClean + "_SW#SWT", iCol), ":", ";")
				colNameStr = stringbykey ("COLUMNNAME", TableInfo (instanceClean + "_SW#SWT", iCol), ":", ";")
				colNameStr = removeEnding (colNameStr, ".d")
				WAVE colwave = $colWaveStr
				RemoveFromTable/W= $instanceClean + "_SW#SWT" colwave
				killDisplayedWave (colwave)
				DeleteFile/Z=1/P=$sharedWavesPath  colNameStr + ".ibw"
			endfor
			
			WAVE/T FolderListWave = $"root:packages:sharedwaves:" + instanceClean + ":DirListWave"
			WAVE FolderListSelWave =  $"root:packages:sharedwaves:" + instanceClean + ":DirListSelWave"
			CFL_ShowFilesinFolder (FolderListWave, FolderListSelWave, ".ibw", "????", "*", sharedWavesPath) 
			 SharedWaves_UpdateFldr (instanceClean)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// writes a file containing tab- or comma- delimitted (if command/ctrl key pressed) text of selected waves.
// The default file extension will be .txt for tab-sprated and .csv for comma-separated
// if shift key pressed, writes out all waves
// Last modified Jan 23 2012 by Jamie Boyd
Function SharedWaves_WriteDelimTextProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = stringFromList (0, ba.win, "_")
			variable isValid
			string sharedWavesPath = SharedWaves_GetDirPath (instanceClean, isValid)
			if (!(isValid))
				doAlert 0, "First set a path to a directory on disk this Shared Waves Manager."
				return 1
			endif
			string sharedWavesFolder = SharedWaves_GetDataFolder (instanceClean, isValid)
			if (!(isValid))
				doAlert 0, "First set a datafolder for this Shared Waves Manager."
				return 1
			endif
			string savedFolder = GetDataFolder (1)
			setDataFolder $sharedWavesFolder
			string info = TableInfo (instanceClean + "_SW#SWT", -2)
			variable firstCol, lastCol
			if (ba.eventMod &2) // do All
				firstCol = 0
				lastCol = NumberByKey("COLUMNS", info , ":", ";") -2
			else // do selected
				string Selected = stringByKey ("SELECTION", info, ":", ";") //firstRow , firstCol , lastRow , lastCol
				firstCol = str2num (stringfromlist (1, Selected, ","))
				lastCol = str2num (stringfromlist (3, Selected, ","))
			endif
			variable iCol
			string SaveList = ""
			for (iCol =lastCol; iCol >= firstCol; iCol -=1) 
				SaveList += StringFromList (0, stringbykey ("COLUMNNAME", TableInfo (instanceClean + "_SW#SWT", iCol), ":", ";"), ".")  + ";"
			endfor
			if (ba.eventMod &8) // command key to do csv
				edit/N=SaveCsvTable  as "Save csv Table"
				string tableName = S_name
				variable nCOls = itemsInList (saveList, ";")
				for (iCol = 0; iCol < nCols; iCol +=1)
					wave aWave = $StringFromList (iCol, SaveList, ";")
					appendToTable/W=$tableName aWave
					if (cmpstr (waveUnits(aWave, -1), "dat") ==0)
						ModifyTable/W=$tableName format(aWave)=8
					elseif (wavetype (aWave) == 4)
						ModifyTable /W= $tableName sigDigits(aWave)=16
					else
						ModifyTable /W= $tableName sigDigits(aWave)=8
					endif
				endfor
				doUpdate
				SaveTableCopy /I/M="\r\n"/N=1/O/P=$sharedWavesPath /S=0/T=2/W= $tableName as instanceClean + ".csv"
				killwindow $tableName
			else // standard tab delimitted file
				save/I/J/B/p=$sharedWavesPath/M="\r\n"/W SaveList as instanceClean +".txt"
			endif
			setdatafolder $savedFolder
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


//*****************************************************************************************************
// Sorts waves in the shared waves manager
// Only makes sense if waves are kept to the same length
// Last Modified Jan 23 2012 by Jamie Boys
Function SharedWaves_SortButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string instanceClean = stringFromList (0, ba.win, "_")
			string sharedWavesPath = instanceClean + "_Path"
			string info = TableInfo (instanceClean + "_SW#SWT", -2)
			variable firstCol, lastCol
			if (ba.eventMod &2) // do All
				firstCol = 0
				lastCol = NumberByKey("COLUMNS", info , ":", ";") -2
			else // do selected
				string Selected = stringByKey ("SELECTION", info, ":", ";") //firstRow , firstCol , lastRow , lastCol
				firstCol = str2num (stringfromlist (1, Selected, ","))
				lastCol = str2num (stringfromlist (3, Selected, ","))
			endif
			variable iCol
			string SortColList = ""
			for (iCol =lastCol; iCol >= firstCol; iCol -=1) 
				SortColList += stringfromlist (0, stringbykey ("COLUMNNAME", TableInfo (instanceClean + "_SW#SWT", iCol), ":", ";"), ".") + ";"
			endfor
			if (strlen (SortColList) < 2)
				doAlert 0, "First select some columns to be sorted, or hold down shift key to select all columns."
				return -1
			endif
			SortColList = SortList(SortColList , ";", 16)
			// ask user which wave(s) to sort by, and for forward or reverse order
			string sortKey, sortKey2, sortKey3
			variable invertSort
			Prompt sortKey, "First Sort by Wave:", popUp, SortColList
			Prompt sortKey2, "Then Sort by Wave:", popUp, "none;" + SortColList
			Prompt sortKey3, "Finally, Sort by Wave:" popup,  "none;" + SortColList
			Prompt invertSort, "Sort Order:", popUp, "ascending;descending"
			doPrompt "Sort Selected Waves", sortKey, sortKey2, sortKey3, invertSort
			if (V_Flag ==1)
				return 1
			endif
			// make sortKey List , semicolon seprated list of waves used as sort keys
			string sortKeyList = sortKey + ";"
			if (cmpstr (sortKey2, "none") != 0)
				sortKeyList += sortKey2 + ";"
			endif
			if (cmpstr (sortKey3, "none") != 0)
				sortKeyList += sortKey3
			endif
			// call functio that does the sorting
			SharedWaves_SortWaves (instanceClean, SortKeyList, SortColList, invertSort)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// Does the sorting. A separate function so user functions can call it
// Last modified Jan 23 2012 by Jamie Boyd
Function SharedWaves_SortWaves (instance, SortKeyList, SortColList, invertSort)
	string instance // name of Shared Waves Mangager
	string SortKeyList // List of wave names to sort by - just the names, not the full paths
	string SortColList	// list of waves to sort, or "" to sort all waves in shared wavs manager, just the names, not the full paths
	variable invertSort // 1 for ascending sort, 0 for descending order sort
	
	// get datafolder for this shared waves manager
	variable isValid
	string swdf =  SharedWaves_GetDataFolder (instance, isValid)
	if (!(isValid))
		return 1
	endif
	// get list of al waves in this shared waves manager
	string swmColList = SharedWaves_GetWaveList (instance)
	variable iCol, nCols
	if (cmpStr (SortColList, "") ==0) // select all columns
		SortColList = swmColList
		nCols = itemsinList (sortColList, ";")
	else // make sure waves in SortColList are in the SWM
		nCols = itemsinList (sortColList, ";")
		for (iCol = 0; iCol < nCols; iCol +=1)
			if (WhichListItem(stringFromList(iCol, sortColList, ";"), swmColList, ";") ==-1)
				return 1
			endif
		endfor
	endif
	// make sure waves in SortKeyList are in  the SWM, and not in sortColList (we will sort keys last)
	variable iSort, nSorts = itemsinlist (SortKeyList, ";")
	string aKey
	for (iSort = 0; iSort < nSorts; iSort +=1)
		aKey = stringFromList(iSort, SortKeyList, ";")
		if (WhichListItem(aKey, swmColList, ";") ==-1)
			return 1
		endif
		SortColList = RemoveFromList(aKey, SortColList, ";")
	endfor
	string savedFldr = getDataFolder (1)
	setDataFolder $swdf
	// we don't know how many waves to use as sort keys until funtion is called. Sort operation does not support this "run-time" behaviour
	// we can use execute operation, but need to work around 400 character limit
	sortKeyList =RemoveEnding (ReplaceString(";", SortKeyList, ","), ",")
	string  commandStr = "Sort/DIML" + SelectString (invertSort, "/R", "") + " {" + sortKeyList + "} "
	string aCol, tempStr
	nCols = itemsinlist (sortColList, ";")
	for (iCol =1, tempStr =  stringFromList (0, sortColList, ";"); iCol < nCols ; iCol +=1)
		aCol = stringFromList (iCol, sortColList, ";")
		if (strlen (commandStr + tempStr + aCol) > 399)
			Execute commandStr + tempStr
			tempStr = aCol
		else
			tempStr += "," + aCol
		endif
	endfor
	// sort left-overs
	Execute commandStr + tempStr
	// sort waves used for keys - want to do this last
	Execute commandStr + sortKeyList
	setDataFolder $savedFldr
	return 0
end

//******************************************************************************************************
// some code for maintaining a spreadsheet of columns where each row  corresponds to a single data point  and each column (i.e., each wave) corresponds to 
// a type of result for that entry.
// each wave needs to have the same length, if neccessary, with padding by a default value
// if desired, a particular value (e.g., a time-stamp or a case id number) can be used to maintain order, and to prevent multiple instances of the same
// data being entered.

//******************************************************************************************************
// a structure to hold numeric values or strings to add to shared waves of results 
// plus the names of waves (and their data types and data units) into which to insert them
// last modified Feb 07 2012 by Jamie Boyd
STRUCTURE SharedWavesStruct
string swmInstance					// name of instance of shared waves manager we are using
variable nResults					// number of variables and strings provided by analysis.
variable isUnique					// bitWise sum of numbers of result from 0 to nResults, a unique combination of which descibes a unique set of shared waves. or 0 if uniquity is not enforced
									// 2^0 =1, 2^1 =2, 2^2 =4, 2^3 =8, 2^4 =16 etc 
variable isSameLen					// non-zero to maintain same wavelengths for all waves with default value padding id needed. isUnique must be used in this case
string resultWaveNames [64]		// string array of wavenames to hold results
variable resultWaveTypes [64]		// numeric array of dataTypes for results (WM format)
string resultWaveUnits [64]		// string array containing data units, used if making new waves
variable resultVariables [64]		// variable array containing data to add to shared numeric waves
string resultStrings [64]			// string array containing data to add to text waves
string userStrings [64]				// strings to process however you like, editing waveNotes is a possibility
variable userVariables [64]				// variables to process however you like, setting scaling perhaps
funcref SharedWavesUFP userFuncs [64]	// function to process your notes, or whatever else you want to do			
ENDSTRUCTURE

//******************************************************************************************************
// This is the prototype for the UserFuncs functions. UserFuncs are called after adding data to a wave, so the wave will already be created, if needed
// UserFuncs are passed the SharedWavesStruct and the position of the data they are to work on
// This prototype shows how to access SWM waves and prints out the value of the last point of the wave
// last modified Feb 07 2012 by Jamie Boyd
function SharedWavesUFP (s, iPos)
	struct SharedWavesStruct &s
	variable iPos
	
	// get datafolder for this shared waves manager
	variable isValid
	string swdf =  SharedWaves_GetDataFolder (s.swmInstance, isValid)
	if (!(isValid))
		return 1
	endif
	// make wave reference to ith wave
	if (s.resultWaveTypes [iPos] == 0) // text wave
		WAVE/t theTextWave = $swdf + s.resultWaveNames [iPos]
		printf "the last point of the text wave %s is equal to%s.\r", s.resultWaveNames [0], theTextWave [numpnts (theTextwave0)-1]
	else
		WAVE theWave = $swdf + s.resultWaveNames [iPos]
		printf "the first point of the wave %s is equal to%6.6f.\r", s.resultWaveNames [0], theWave [numpnts (theWave)-1]
	endif
	return 0
end
//******************************************************************************************************
// Ensures all results wave names in struct are loaded as shared waves
// Last Modified Jan 13 2012 by Jamie Boyd
Function SharedWaves_EnsureLoaded (s)
	struct SharedWavesStruct &s
	
	//Waves in data folder
	wave/T fldrListWave = $"root:packages:sharedWaves:" + s.swmInstance + ":fldrListWave"
	WAVE fldrListSelWave = $"root:packages:sharedWaves:" + s.swmInstance + ":fldrListSelWave"
	SVAR dataFolderStr = $"root:packages:sharedWaves:" + s.swmInstance + ":fldrStr"
	// Files in directory
	wave/T dirListWave = $"root:packages:sharedWaves:" + s.swmInstance + ":DirListWave"
	WAVE dirListSelWave = $"root:packages:sharedWaves:" + s.swmInstance + ":DirListSelWave"
	SVAR dirPathDescStr =  $"root:packages:sharedwaves:" + s.swmInstance +":dirPathDescStr"
	string SharedWavesPath = s.swmInstance + "_Path"
	// set dataFolder to dharedWaves folder if we need to load wave
	string savedFolder = getDataFolder (1)
	setDataFolder $dataFolderStr
	string tableName = s.swmInstance + "_SW#SWT"
	// iterate through results in the structure
	string dataUnits, wavePath, aWaveName, loadList = ""
	variable iR, returnVal =0, doDir =0, dofldr = 0
	for (iR =0; iR <  s.nResults; iR += 1)
		aWaveName =  s.resultWaveNames [iR]
		WAVE/z rWave = $dataFolderStr + aWaveName // the wave to insert the result into
		if (!(waveExists (rWave)))
			// is missing wave in dir?
			GetFileFolderInfo/P=$sharedWavesPath/Q/Z=1  aWaveName + ".ibw"
			if (V_Flag ==0) //  inDirPathStr is a valid path, so file exists
				LoadWave/P=$SharedWavesPath aWaveName + ".ibw" 
				WAVE rWave = $dataFolderStr + aWaveName 
				dofldr =1
			else // make the wave
				make/Y=(s.resultWaveTypes [iR])/n=0 $dataFolderStr + aWaveName
				WAVE rWave = $dataFolderStr +  aWaveName
				dataUnits = s.resultWaveUnits [iR]
				SetScale d 0,0,dataUnits, rWave
				Save/P= $SharedWavesPath  rWave as lowerStr (aWaveName) + ".ibw"
				doFldr =1
				doDir =1
			endif
		else // the wave exists in the data folder - does it exist in the directory?
			wavePath = stringBykey ("PATH", waveinfo (rWave, 0), ":", ";")
			PAthInfo $wavePath
			if ((V_Flag ==0) || (cmpStr (S_Path, dirPathDescStr) !=0))// the wave was not loaded from the shared waves data folder
				// is a copy of the wave in directory?
				GetFileFolderInfo/Q/P=$sharedWavesPath/Z=1  LowerStr (aWaveName) + ".ibw"
				if (V_Flag ==0) //  inDirPathStr is a valid path, so file exists. uh oh, which one do we want?
					doAlert 2, "Both a wave and an .ibw file named  \"" +  aWaveName + "\" already exists for \"" + s.swmInstance +"\". Press \"Yes\" to replace the .ibw file with the wave. Press \"No\" to replace the wave with the file."
					if (V_Flag ==3) // cancel
						returnVal = 1
						break
					elseif (V_Flag ==2) // replace wave with file
						LoadWave/O/P=$SharedWavesPath aWaveName + ".ibw" 
						WAVE rWave = $dataFolderStr + aWaveName 
						//AppendToTable/W=$s.swmInstance + "_SW#SWT" rWave 
					elseif (V_Flag == 1) // replace file with wave
						Save/O/P= $SharedWavesPath rWave as LowerStr (aWaveName) + ".ibw"
						//AppendToTable/W=$s.swmInstance + "_SW#SWT" rWave
					endif
				else // save wave to the directory
					Save/P= $SharedWavesPath rWave as LowerStr (aWaveName) + ".ibw"
					//AppendToTable/W=$s.swmInstance + "_SW#SWT" rWave
					doDir =1
				endif
			endif
		endif
		AppendToTable/W=$tableName rWave
		if (cmpstr (waveUnits(rWave, -1), "dat") ==0)
			ModifyTable/W=$tableName format(rWave)=8
		elseif (wavetype (rWave) == 4)
			ModifyTable /W= $tableName sigDigits(rWave)=16
		else
			ModifyTable /W= $tableName sigDigits(rWave)=8
		endif
	endfor
	if (doFldr)
		SharedWaves_UpdateFldr (s.swmInstance)
	endif
	if (doDir)
		SharedWaves_UpdatePathList (s.swmInstance)
	endif
	setdatafolder $savedFolder
	return returnVal
end

//******************************************************************************************************
// Adds an entry to an instance of SharedWaves (possibly enforcing "spreadsheet style" if iuniqueVal and isSameLen are set
// last modified Jan 13 2012 by Jamie Boyd
Function SharedWaves_AddResults (s)
	struct SharedWavesStruct &s
	
	// Check Shared Waves Path
	string SharedWavesPath = s.swmInstance + "_Path"
	PathInfo /S $SharedWavesPath
	variable hasPath = V_Flag
	//Check Shared Waves datafolder
	string dataFolderStrL = ""
	SVAR/Z dataFolderStr = $"root:packages:sharedWaves:" + s.swmInstance + ":fldrStr"
	variable hasfldr =  (SVAR_EXISTS (dataFolderStr) && ((datafolderExists (dataFolderStr) && (cmpStr (dataFolderStr, "") != 0))))
	if (hasfldr)
		dataFolderStrL = dataFolderStr
	endif
	// check that panel is created
	variable hasPanel = 0
	if (cmpStr (s.swmInstance + "_SW", WinList(s.swmInstance + "_SW", "", "WIN:64")) == 0)
		hasPanel =1
	endif
	if (!((hasPath & hasfldr) & hasPanel))
		SharedWaves_Init (s.swmInstance, SharedWavesPath, dataFolderStrL, 1) // both path to directory and datafolder in experiment should now exist
		doUpdate
	endif
	// NOW we can reference globals with confidence
	SVAR dataFolderStr = $"root:packages:sharedWaves:" + s.swmInstance + ":fldrStr"
	// Ensure all results waves exist and are loaded and added to the shared waves table
	SharedWaves_EnsureLoaded (s)
	//get a list of all waves in this shared waves manager - this may be more waves than are actually having data appened to them right now
	string colList = "", info = TableInfo (s.swmInstance + "_SW#SWT", -2)
	variable iCol, nCols =  NumberByKey("COLUMNS", info , ":", ";") -1
	for (iCol = 0; iCol < nCols; iCol +=1)
		colList += stringfromlist (0, stringbykey ("COLUMNNAME", TableInfo (s.swmInstance + "_SW#SWT", iCol), ":", ";"), ".") + ";"
	endfor
	variable iR, waveN, matchPos, insertPos
	string resultStr
	variable resultVar
	if (s.isUnique > 0)
		s.isSameLen = 1 // need to ensure same length with unique values, no matter what the calling function requested
	endif
	if (s.isSameLen)
		waveN= SharedWaves_SameLength (s.swmInstance, colList)
		if (s.isUnique > 0)
			matchPos = SharedWaves_CheckUnique (s)
		else
			matchPos = -1
		endif
		// if no match found, or not looking for matches, insert a row at end of data
		// Need to insert a point in ALL waves in this shared waves manager, not just waves we are adding data to
		if (matchPos == -1)
			SharedWaves_InsertPt (s.swmInstance, colList)
			insertPos = waveN
		else
			insertPos = matchPos
		endif
		//now insert the data into the waves and run the UserFunc, if any
		for (iR =0; iR <  s.nResults; iR += 1)
			if (s.resultWaveTypes [iR] == 0) // textwave
				WAVE/T TdataWave = $dataFolderStr +  s.resultWaveNames [iR]
				resultStr = s.resultStrings [iR]
				TdataWave [insertPos] = resultStr
			else // numeric wave
				resultVar = s.resultVariables [iR]
				WAVE dataWave = $dataFolderStr +  s.resultWaveNames [iR]
				dataWave [insertPos] = resultVar
			endif
			// run userfunction, if Present
			if (Str2Num (StringByKey("ISPROTO", FuncRefInfo(s.UserFuncs[iR]), ":", ";")) == 0)
				s.UserFuncs[iR] (s, iR)
			endif
		endfor
	else // waves might not all be the same size if not keeping same lenght - also, no need to resize waves not having data added
		for (iR =0; iR <  s.nResults; iR += 1)
			if (s.resultWaveTypes [iR] == 0) // textwave
				WAVE/T TdataWave = $dataFolderStr +  s.resultWaveNames [iR]
				resultStr = s.resultStrings [iR]
				insertPos = numPnts (TdataWave)
				InsertPoints /M=0  (insertPos), 1, TdataWave
				TdataWave [insertPos] = resultStr
			else // numeric wave
				resultVar = s.resultVariables [iR]
				WAVE dataWave = $dataFolderStr +  s.resultWaveNames [iR]
				insertPos = numPnts (dataWave)
				InsertPoints /M=0  (insertPos), 1, dataWave
				dataWave [insertPos] = resultVar
			endif
			// run userfunction, if Present
			if (Str2Num (StringByKey("ISPROTO", FuncRefInfo(s.UserFuncs[iR]), ":", ";")) == 0)
				s.UserFuncs[iR] (s, iR)
			endif
		endfor
	endif
end

//******************************************************************************************************
// This UserFunction Does a key by value replacement on the waveNote of the wave at the iPos position
// assumes the note string contains key:value; pairs with semicolons and colons as key:value  and list separarators
function SharedWavesKV (s, iPos)
	struct SharedWavesStruct &s
	variable iPos
	
	// get datafolder for this shared waves manager
	variable isValid
	string swdf =  SharedWaves_GetDataFolder (s.swmInstance, isValid)
	if (!(isValid))
		return 1
	endif
	variable ipair, nPairs = itemsinList (s.userStrings [iPos], ";")
	string theNote, aPair, aKey, aValue
	// make wave reference to ith wave
	if (s.resultWaveTypes [iPos] == 0) // text wave
		WAVE/t theTextWave = $swdf + s.resultWaveNames [iPos]
		theNote = note (theTextWave)
	else
		WAVE theWave = $swdf + s.resultWaveNames [iPos]
		theNote = note (theWave)
	endif
	// replace the value of the keys currently in the waveNote with the new values
	for (iPair = 0; iPair < nPairs; iPair += 1)
		aPair = stringFromList (iPair, s.userStrings [iPos])
		aKey = stringFromlist (0, aPair, ":")
		aValue = stringFromList (1, aPair)
		theNote = ReplaceStringByKey(aKey, theNote, aValue, ":", ";")
	endfor
	// replace the modified note 
	if (s.resultWaveTypes [iPos] == 0)
		Note/K theTextWave, theNote
	else
		Note/K theWave, theNote
	endif
	return 0
end

//******************************************************************************************************
// make all shared waves in this shared waves manager the same length
// by appending to the end of "short" waves points set to default values (Nan for floating point, 0 for integer, "" for text)
// returns length of waves
// appending points to a wave used for uniquity will make for not-unique values. So make sure all waves are
// kept to same length when using uniquity
// Last Modified Jan 23 2012 by Jamie Boyd
Function SharedWaves_SameLength (instance, colList)
	string instance // name of the shared waves manager
	string colList // list of all waves in this shared waves manager
	
	string instanceClean = cleanUpName (instance, 0)
	variable isValid
	string df = sharedWaves_GetDataFolder (instanceClean, isValid)
	if (!(isValid))
		return -1
	endif
	// append points as needed and fill with appropriate default value
	variable dwPnts, insertPnts, maxPnts
	variable iCol, nCols = itemsinList (colList, ";")
	for (maxPnts = 0, iCol = 0; iCol < nCols; iCol +=1)
		WAVE colwave = $df + StringFromList(iCol, ColList, ";")
		maxPnts = max (maxPnts, numPnts (colWave))
	endfor
	string aWaveName
	for (iCol = 0; iCol < nCols; iCol +=1)
		 aWaveName=StringFromList(iCol, ColList, ";")
		WAVE colwave = $df + aWaveName
		dwPnts = numPnts (colWave)
		// How many points do we need to insert?
		insertPnts = maxPnts - dwPnts
		if (insertPnts > 0)
			insertpoints (dwPnts), (insertPnts), colwave
			// text or numeric?
			if (waveType (colWave) == 0) // text wave
				WAVE/T colwaveT = $df + aWaveName
				colWaveT [dwPnts, maxPnts-1] = ""
			else
				if ((waveType (colWave) && 4) || (waveType (colWave) && 8)) // floating point wave
					colWave [dwPnts, maxPnts-1]= NaN
				else		// integer wave
					colWave [dwPnts, maxPnts-1]= 0
				endif
			endif
		endif
	endfor
	return maxPnts
end

//******************************************************************************************************
// inserts a point to end of all waves in this shared waves manager and fills new points with default values
// assumed all waves have the same length
// last modified Jan 31 2012 by Jamie Boyd
Function SharedWaves_InsertPt (instance, colList)
	string instance // instance of shared waves manager to use
	string colList // list of all waves in this shared waves manager
	
	variable isValid
	string df = sharedWaves_getDataFolder (cleanupname (instance, 0), isValid)
	if (!(isValid))
		return 1
	endif
	// append points as needed and fill with appropriate default value
	variable iCol, nCols = itemsinList (colList, ";")
	WAVE aWave = $df + StringFromList(0, ColList, ";")
	variable dwPnts = numpnts (aWave)
	string aWaveName
	for (iCol = 0; iCol < nCols; iCol +=1)
		 aWaveName=StringFromList(iCol, ColList, ";")
		WAVE colwave = $df + aWaveName
		insertpoints (dwPnts), 1, colwave
		// text or numeric?
		if (waveType (colWave) == 0) // text wave
			wave/T colwaveT = $df + aWaveName
			colWaveT [dwPnts] = ""
		else
			if ((waveType (colWave) && 4) || (waveType (colWave) && 8)) // floating point wave
				colWave [dwPnts]= NaN
			else	 // integer wave
				colWave [dwPnts]= 0
			endif
		endif
	endfor
	return 0
end

//******************************************************************************************************
// checks if data to be added is already present in a shared waves manager, by searching waves that need to contain unique combinations of values
// Returns point number of the matching data, or returns -1 if there was no match
// assumes all waves have the same number of points
// Last Modified Oct 03 2012 by Jamie Boyd
Function SharedWaves_CheckUnique (s)
	struct SharedWavesStruct &s

	SVAR dataFolderStr = $"root:packages:sharedWaves:" + s.swmInstance + ":fldrStr"
	// find first wave used for uniqueness
	variable firstUniq, iUniq, uniqueVal, startP, matchFound
	string uniqueTxt 
	for (firstUniq=0, iUniq =0; iUniq < s.nResults; iUniq +=1)
		if (2^iUniq & s.isUnique) // search this wave first 
			firstUniq = iUniq
			break
		endif
	endfor
	if (iUniq == s.nResults)
		return -1
	endif
	variable pnts = numpnts ($dataFolderStr + s.resultWaveNames [0])
	// For all matching positions of first unique wave, check other unique waves at that position
	for (startP=0; startP < pnts ;startP +=1 )
		if (s.resultWaveTypes [firstUniq] == 0) // text wave
			uniqueTxt = s.resultStrings [firstUniq]
			wave/T uniqueTwave = $dataFolderStr + s.resultWaveNames [firstUniq]
			FindValue/TEXT=(uniqueTxt)/TXOP=4/S=(startP) uniqueTwave
		else // numeric wave 
			uniqueVal = s.resultVariables [firstUniq]  
			WAVE uniqueWave =  $dataFolderStr + s.resultWaveNames [firstUniq]
			if (wavetype (uniqueWave) & (56)) // integer wave
				if (wavetype (uniqueWave) == 96) // unsigned long
					FindValue/U=(uniqueVal)/S=(startP) uniqueWave
				else // regular integer value
					FindValue/I=(uniqueVal)/S=(startP) uniqueWave
				endif
			else // floating point value
				FindValue/V=(uniqueVal)/T=0/S=(startP) uniqueWave
			endif
		endif
		if (V_Value ==-1) // no match found for first unique wave
			return -1
		else // match found for first unique wave. Check all other unique waves at this point
			for (matchFound = 1, iUniq =firstUniq+1; iUniq < s.nResults; iUniq +=1)
				if (2^iUniq & s.isUnique) // check this data 
					if (s.resultWaveTypes [iUniq] == 0) // text wave
						uniqueTxt = s.resultStrings [iUniq]
						wave/T uniqueTwave = $dataFolderStr + s.resultWaveNames [iUniq]
						if (cmpStr (uniqueTxt, uniqueTwave [V_value]) != 0)
							matchFound =0
							break
						endif
					else // numeric wave 
						uniqueVal = s.resultVariables [iUniq]  
						WAVE uniqueWave =  $dataFolderStr + s.resultWaveNames [iUniq]
						if (uniqueWave [V_Value] != uniqueVal)
							matchFound=0
							break
						endif
					endif
				endif
			endfor
			if (matchFound) // a match was found for all unique waves at this position
				return V_Value
			endif
			startP = V_value // start search from last match 
		endif
	endfor
	return -1
end


//*****************************************************************************************************
// code for getting dataFolder and directory for a shared waves manager - "Data Hiding" is good practice

//*****************************************************************************************************
// Returns the datafolder string used by the instance of shared waves manager.
// Sets the pass-by-reference isValid variable to 1 if the data folder string points to an existing Igor datafolder
// Last Modified Jan 23 2012 by Jamie Boyd
Function/S SharedWaves_GetDataFolder (instance, isValid)
	string instance
	variable &isValid
	
	string instanceClean = cleanupname (instance, 0)
	SVAR folderStr = $"root:packages:sharedWaves:" + instanceClean + ":fldrStr"
	if ((dataFolderExists (folderStr)) && (cmpstr (folderStr, "") != 0))
		isValid =1
	else
		isValid =0
	endif
	return folderStr
end

//*****************************************************************************************************
// Returns the name of the path to the directory used by the instance of shared waves manager.
// Sets the pass-by-reference isValid variable to 1 if the directory path points to an existing directory on disk
// Last Modified Jan 23 2012 by Jamie Boyd
Function/S SharedWaves_GetDirPath (instance, isValid)
	string instance
	variable &isValid
	
	string instanceClean = cleanupname (instance, 0)
	string dirPath =  instanceClean  + "_Path"
	SVAR/Z dirPathDescStr = $"root:packages:sharedWaves:" + instanceClean + ":dirPathDescStr"
	if (!(SVAR_EXISTS (dirPathDescStr)))
		isValid = 0
		return ""
	endif
	GetFileFolderInfo/D/Q/Z=1 dirPathDescStr
	if (V_Flag ==0) // directory was found
		isValid =1
	else
		isValid=0
	endif
	return dirPath
end	

//*****************************************************************************************************
// Returns a semi-colon separated list of all the waves being shared by a Shared Waves Manager
// Last Modified Jan 23 2012 by Jamie Boyd	
Function/S SharedWaves_GetWaveList (instance)
	string instance
	
	string instanceClean = cleanupname (instance, 0)
	string colList = "", info = TableInfo (instanceClean + "_SW#SWT", -2)
	variable iCol, nCols =  NumberByKey("COLUMNS", info , ":", ";") -1
	for (iCol = 0; iCol < nCols; iCol +=1)
		colList += stringfromlist (0, stringbykey ("COLUMNNAME", TableInfo (instanceClean + "_SW#SWT", iCol), ":", ";"), ".") + ";"
	endfor
	return colList
end

