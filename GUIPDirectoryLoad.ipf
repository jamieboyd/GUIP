#pragma rtGlobals=3
#pragma IgorVersion = 5
#pragma version = 1.1		// Last Modified: 2014/12/17 by Jamie Boyd
#pragma ModuleName = GUIPDirectoryLoad
#include "GUIPKillDisplayedWave"
#include "GUIPList"
#include "GUIPprotoFuncs"

// GUIP Directory Load is designed to simplify loading Igor waves from files ina  Directory on disk.

// The programmer must supply a function that, given an Igor path to a directory and the name of a file in that directory, 
// will load the specified file into the current data folder. GUIPDirectory load provides functions for making a control panel
// to list files in a directory, and load selected files with provided function.
// The parameters for the user's loading function are:
// string ImportPathStr	// string containing the name of an Igor path to the Directory on disk from which to import files (ImportPath)
// string FileNameStr	// string containing the name of the selected file
// string OptionsStr	// Do what you want with this. Pass any other options to your loading function
// string fileDescStr // the string used when making the panel, descrining type of dat to be loaded
// The load function returns 0 for success and 1 for failure, and should also set a global variable V_Flag to the number of waves loaded, 
// and a global string, S_WaveNames, to a semicolon-separated list of names of loaded waves.
 
 // The user can also supply a function for post-processing of each loaded wave. There may be more than one wave loaded from each file, so it makes
// sense to have separate functions for loading and postprocessing.  The parameters for the processing function are:
// Wave LoadedWave	// A reference to the loaded wave
// string ImportPathStr	// string containing the name of an Igor path to the Directory on disk from which wave was imported
// string FileNameStr		// string containing the name of the file on disk from which the wave was loaded
// string OptionStr		// a string to do whatever you like with


Static Constant kMinDirPanelWidth =320
Static Constant kMinDirPanelHeight =364
Static Constant kDirPanelReservedBottom = 256
Static Constant kDirPanelReservedTop = 54

Static StrConstant skMDKeyValSep="="
Static StrConstant skMDPairSep=";"

//*****************************************************************************************************
//****************Code to easily make a simple loader panel for any file type using supplied file loader functions********************
//*****************************************************************************************************

// Makes a control panel and global variables to run it. Panel features:
// a button to select a directory on disk using GUIPDirectorySetImPathProc
// a list box showing files in a Directory on a drive using GUIPShowFilesinDirectory
// a button that uses GUIPDirectoryLoad to load files that are selected in the listbox.
// The user must specify a function to load each individual file, and to postprocess the resulting wave(s), if needed
// Returns bitwise value 1 if a dataFolder already exists plus 2 if the panel already existed
// Last modified 2014/12/16 by jamie Boyd
Function GUIPDirPanel (FileDescriptionStr, typelimitstr,LoadFunc, [processFunc, extraVertPix])
	string FileDescriptionStr //  description of the file type to be loaded, will be used in panel's window panel
	string  typelimitstr  // The 4 character file type string, used to limit the files listed in the list box
	string LoadFunc // name of the user-supplied function used to load an individual file
	string processFunc // name of the user-supplied processing string, used to process an individual loaded wave
	variable extraVertPix // amount of extra vertical space, in pixels, desired for this loader panel
	
	variable directoryPanelExisted
	// panel and datafolder for globals will named from File Description string, cleaned up
	string cleanFileDescStr = CleanUpName (FileDescriptionStr, 0)
	if (dataFolderExists ("root:packages:GUIP:" + cleanFileDescStr))
		directoryPanelExisted = 1
	else
		directoryPanelExisted = 0
		if (!(dataFolderExists ("root:packages:GUIP")))
			if (!(dataFolderExists ("root:packages")))
				newDataFolder root:packages
			endif
			newDataFolder root:packages:GUIP
		endif
		newDataFolder $"root:packages:GUIP:" + cleanFileDescStr
		string/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDiskDirStr"
		variable/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPRecurseDir"
		string/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPMatchStr" = "*"
		string/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPFileDescriptionStr"
		string/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPtypelimitstr" 
		string/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDataFolderStr"
		string/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPloadFuncStr"
		string/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPLoadOptionStr" = ""
		string/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPprocessFuncStr"
		string/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPProcessOptionStr" = ""
		variable/G $"root:packages:GUIP:" + cleanFileDescStr +":GUIPNewFolderEachFile"
		variable/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPextraVertPix" 
		make/t/n=(1,3) $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDirectoryListWave"
		Wave/T dirListWave = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDirectoryListWave"
		SetDimLabel 1,0, Name dirListWave
		SetDimLabel 1, 1, Created dirListWave
		SetDimLabel 1, 2, Modified dirListWave
		make/n=(1,3) $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDirectoryListSelWave"
		variable/G $"root:packages:GUIP:" + cleanFileDescStr +":GUIPGetMetaData"
		string/G $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPMetaDataSepStr" = "."
		make/t/n=0 $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPMetaDataWave"
	endif
	// set some globals
	SVAR GUIPFileDescriptionStrG = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPFileDescriptionStr"
	GUIPFileDescriptionStrG = FileDescriptionStr
	SVAR GUIPtypelimitstrG =  $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPtypelimitstr"
	GUIPtypelimitstrG = typelimitstr
	SVAR GUIPloadFuncStrG = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPloadFuncStr"
	GUIPloadFuncStrG = LoadFunc
	SVAR GUIPprocessFuncStrG = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPprocessFuncStr"
	if (ParamIsDefault(processFunc))
		GUIPprocessFuncStrG = ""
	else
		GUIPprocessFuncStrG=ProcessFunc
	endif
	NVAR extraVertPixG = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPextraVertPix" 
	if (ParamIsDefault (extraVertPix))
		extraVertPixG =0
	else
		extraVertPixG = extraVertPix
	endif
	NVAR GUIPNewFolderEachFile = $"root:packages:GUIP:" + cleanFileDescStr +":GUIPNewFolderEachFile" 
	NVAR getMataData= $"root:packages:GUIP:" + cleanFileDescStr +":GUIPGetMetaData"
	SVAR metaDataSepStr = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPMetaDataSepStr" 
	WAVE/T MetaDataWave=$"root:packages:GUIP:" + cleanFileDescStr + ":GUIPMetaDataWave"
	// make control panel
	doWindow/F $cleanFileDescStr + "Loader"
	if (V_Flag)
		directoryPanelExisted +=2
	else
		NewPanel/K=1/N= $cleanFileDescStr + "Loader"/W=(2,44,322,(466+ extraVertPix)) as  "Loader For " + FileDescriptionStr
		string panelName = S_Name
		//controls before extra controls
		CheckBox GUIPRecursCheck  win =$panelName,pos={4,7},size={52,15},title="Recurse", proc=GUIPDirectoryLoad#GUIPDirGUIPRecursCheckProc
		CheckBox GUIPRecursCheck win =$panelName,variable= $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPRecurseDir"
		CheckBox GUIPRecursCheck win =$panelName,help={"When checked, files in all subdirectories of selected directory will be listed."}
		Button GUIPSelectDirButton win =$panelName,pos={62,3},size={105,22},proc=GUIPDirectoryLoad#GUIPDirPanelSelDir,title="Select Directory"
		Button GUIPSelectDirButton win =$panelName, help={"Allows you to select a directory on disk from whence to load files."}
		TitleBox GUIPFolderTitle win =$panelName,pos={171,8},size={221,12},frame=0
		TitleBox GUIPFolderTitle win =$panelName,help={"Shows the path to the folder on disk containing the files to be loaded"}
		TitleBox GUIPFolderTitle win =$panelName,variable= $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDiskDirStr"
		SetVariable GUIPmatchSetvar win =$panelName,pos={4,33},size={103,15},title="Match string", proc=GUIPDirGUIPMatchStrProc
		SetVariable GUIPmatchSetvar win =$panelName,value=  $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPMatchStr"
		SetVariable GUIPmatchSetvar win =$panelName, help = {"List of files from directory will be limited to those whose names match this string."}
		Button GUIPUpdateDirListButton win =$panelName,pos={111,29},size={88,22},proc=GUIPDirectoryLoad#GUIPDirPanelSelDir,title="Update List"
		Button GUIPUpdateDirListButton win =$panelName,help={"Updates the list of files from the selected Directory, without choosing a new Directory"}
		Button GUIPSelectAllButton win =$panelName,pos={203,29},size={112,22},proc=GUIPDirectoryLoad#GUIPDirPanelSelectAll,title="Select All in List"
		Button GUIPSelectAllButton win =$panelName,help={"Selects all the files from the list of files in the selected directory on disk."}
		// Controls after extra controls
		//Because ListBox is resizable we will make a variable for height
		variable LBheight=114
		ListBox GUIPFilesList win =$panelName, pos={2, (kDirPanelReservedTop + extraVertPix)},size={315, LBheight},mode= 4,userColumnResize= 1
		ListBox GUIPFilesList win =$panelName, help={"Shows all the files in the selected directory. Select files to be loaded, then click \"load selected\""}
		ListBox GUIPFilesList win =$panelName, listWave=$"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDirectoryListWave"
		ListBox GUIPFilesList win =$panelName, selWave=$"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDirectoryListSelWave", proc = GUIPDirPanelSortList
		//Other, non-resizable controls
		CheckBox GUIPAddMetaDataCheck win =$panelName,pos={4,(kDirPanelReservedTop + extraVertPix + LBheight + 2)},size={128,16},title="MetaData from File Name"
		CheckBox GUIPAddMetaDataCheck win =$panelName, variable= $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPGetMetaData"
		SetVariable GUIPMetaDataSepSetVar win =$panelName,pos={144,(kDirPanelReservedTop + extraVertPix + LBheight + 2)},size={98,16},title="Separator"
		SetVariable GUIPMetaDataSepSetVar win =$panelName,value= $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPMetaDataSepStr"
		Edit/W=(3, ((kDirPanelReservedTop + extraVertPix + LBheight + 22)),316,(kDirPanelReservedTop	+ extraVertPix +LBheight + 142))/HOST=#  MetaDataWave
		ModifyTable width(Point)=30,alignment[1]=0,width[1]=264, title[1]="Meta data",showparts = 235
		RenameWindow #,T0
		SetActiveSubwindow ##
		PopupMenu GUIPLoadFolderPopmenu win =$panelName,pos={4,(kDirPanelReservedTop + extraVertPix + LBheight + 144)},size={99,20},proc=GUIPDirectoryLoad#GUIPDirPanelSetDestFolder,title="Destination:"
		PopupMenu GUIPLoadFolderPopmenu win =$panelName,help={"Allows you to select an Igor datafolder in which to place the loaded waves."}
		PopupMenu GUIPLoadFolderPopmenu win =$panelName,mode=0,value= #"\"New Datafolder;\\\\M1-;root:;\" + GUIPListObjs (\"root:\", 4, \"*\", 13, \"\\M1(No Folders\")"
		TitleBox GUIPLoadFolderTitle win =$panelName, pos={107,(kDirPanelReservedTop + extraVertPix + LBheight + 147)},size={21,12},frame=0
		TitleBox GUIPLoadFolderTitle win =$panelName, help={"Shows the selected Igor datafolder where the loaded waves will be placed."}
		TitleBox GUIPLoadFolderTitle win =$panelName, variable= $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDataFolderStr"
		CheckBox GUIPNewFolderCheck win =$panelName, pos={4,(kDirPanelReservedTop + extraVertPix + LBheight + 167)},size={124,16},title="New Folder For Each FIle", variable=GUIPNewFolderEachFile
		CheckBox GUIPNewFolderCheck win =$panelName, help={"When checked, a new folder named for the loaded file will be created inside the destination folder for each loaded file."}
		PopupMenu GUIPWaveNamepopup win =$panelName,pos={4,(kDirPanelReservedTop + extraVertPix + LBheight + 185)},size={257,20},title="Wave Names"
		PopupMenu GUIPWaveNamepopup win =$panelName,mode=3,popvalue="Rename and Strip Extensions",value= #"\"Leave as Loaded;Rename from File Name;Rename and Strip Extensions;Rename, Strip, and CleanUp\""
		PopupMenu GUIPWaveNamepopup win =$panelName, help = {"After the waves are loaded, they will be renamed according to selection in this menu."}
		PopupMenu GUIPoverwritepopup win =$panelName,pos={3,(kDirPanelReservedTop + extraVertPix + LBheight +208)},size={275,20},title="In Case of Conflict"
		PopupMenu GUIPoverwritepopup win =$panelName,mode=1,popvalue="Manually Resolve Conflict",value= #"\"Manually Resolve Conflict;Automatically Rename New Wave;Automatically Overwrite Old Wave\""
		PopupMenu GUIPoverwritepopup win =$panelName,help = {"Name conflicts arising when the loaded, renamed waves are moved to the target datafolder will be resolved according to selection in this menu."}
		SetVariable GUIPLoadOptionsSetvar win =$panelName,pos={3,(kDirPanelReservedTop + extraVertPix + LBheight + 235)},size={118,16},title="Options-Load"
		SetVariable GUIPLoadOptionsSetvar win =$panelName,value= $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPLoadOptionStr"
		SetVariable GUIPLoadOptionsSetvar win =$panelName,help = {"The string shown here will be passed to the user-supplied loading function. You may wish to change this help string to list supported options"}
		SetVariable GUIPProcessOptionsSetvar win =$panelName,pos={124,(kDirPanelReservedTop + extraVertPix + LBheight + 235)},size={95,16},title="Process"
		SetVariable GUIPProcessOptionsSetvar win =$panelName,value= $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPProcessOptionStr"
		SetVariable GUIPProcessOptionsSetvar win =$panelName,help = {"The string shown here will be passed to the user-supplied processing function (if present). You may wish to change this help string to list supported options"}
		Button GUIPLoadSelectedButton win =$panelName,pos={224, (kDirPanelReservedTop + extraVertPix + LBheight + 231)},size={95,22},proc=GUIPDirectoryLoad#GUIPDirPanelLoadSelected,title="Load Selected"
		Button GUIPLoadSelectedButton win =$panelName,help={"Loads files selected from the list into Igor waves and places them in the destination folder."}
		// if procedure requests extra space to draw its controls, invite it to do so
		if (!(ParamIsDefault (extraVertPix)))
			funcref GUIPProtoFuncV extraDraw = $cleanFileDescStr + "_drawControls" // variable is vertical position to start drawing controls
			extraDraw (kDirPanelReservedTop) 
		endif
		// set panel hook
		SetWindow $panelName hook(PanelHook)=GUIPDirectoryLoad#GUIPDirPanelHook
	endif
	return directoryPanelExisted
end

//******************************************************************************************************
//GUIPDirectorySetImPathProc sets a new Igor symbolic path, by letting the user choose a Directory on the disk. Returns the full path to the Directory
Function/S GUIPDirectorySetImPathProc(ImportPathNameStr, FileDescriptionStr)
	String ImportPathNameStr	// a string containing the name of the Igor Symbolic path to be created
	String FileDescriptionStr	// a string containing a breif description of the type of files to be loaded, used in the choose file prompt

	NewPath /O/M= "Set Import Directory for loading " + FileDescriptionStr + "." $ImportPathNameStr
	if (V_Flag)
		return ""
	endif
	PathInfo $ImportPathNameStr
	if (V_Flag==0)
		return ""
	endif
	return S_path
End

//******************************************************************************************************
// This function makes a list of files in a Directory into a textwave, and redimensions a numeric wave to the same length, suitable for making a listbox
// Last Modified 2014/10/22 by Jamie Boyd
Function GUIPDirectoryShowFiles (ImportpathStr, DirListWave, DirListSelWave, typelimitstr, nameMatchStr, recurse)
	String  ImportPathStr		// a string containing the name of an Igor Path to the Directory on disk
	WAVE/T DirListWave		// a text wave to contain the list of files iin the Directory on disk
	WAVE DirListSelWave	// a wave to act as a selection wave for the Directorylist wave in a listbox
	String typelimitstr			// A 4 character string for limiting listed files to those with certain file extensions or file types, pass  "????" for no limit. Pass "dirs" to list Directorys instead of files
	String nameMatchStr		// For limiting files shown by other parts of the filename than the extension, it is wildcarable with asterisks and such
	variable recurse			// set to do a recursive call through all directories of the source directory
	
	recurse = (1 & recurse)
	// Get list of all files
	string fileList = GUIPListFiles (ImportpathStr,  typelimitstr, nameMatchStr, recurse + 48, "")
	if (cmpStr (fileList, "\\M1(Invalid Path") == 0)
		return 1
	else
		// make DirListWave and DirListSelWave match the files in the new Directory
		// these waves are used for the "files" listbox
		variable iFile, iPos, nFiles = itemsinList (fileList, ";")/3
		Redimension/N=(nFiles, 3) DirListWave, DirListSelWave
		for(ifile = 0, iPos=0; iFile < nFiles; iFile += 1)
			DirListWave [iFile] [0]= stringfromlist (iPos, fileList)
			iPos +=1
			DirListWave [iFile] [1]= stringfromlist (iPos, fileList)
			iPos +=1
			DirListWave [iFile] [2]= stringfromlist (iPos, fileList)
			iPos +=1
		endfor
		DirListSelWave = 0		// make sure nothing is selected in the listbox
		return 0
	endif
end


//******************************************************************************************************
// ListBox procedure for files list. Sorts list of files with creation and modification dates by selected column (filename, creation date, or mod date)
// Sorting 2D wave by a selected column modified from code  by Andrew Nelson at http://www.igorexchange.com/node/599
// Last Modified 2014/10/22 by Jamie Boyd
Function GUIPDirPanelSortList(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 2: //mouse up
			break
		case 3: // double click
			if (lba.row == -1)  // sort list by selected column
				variable nRows =dimsize(lba.listWave,0)
				make/T/free/n=(nRows) key
				make/free/n=(nRows) valindex
				key[] = lba.listWave[p][lba.col]
				valindex=p
				sort/a key,key,valindex
				make/t/free/n=((nRows), 3), toBeSorted
				toBeSorted[][] = lba.listWave[valindex[p]][q]
				lba.listWave = toBeSorted
			endif
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

//******************************************************************************************************
// Selects all files in the list box showing files in the directory
// Last Modified 2013/05/16 by Jamie Boyd
Function GUIPDirectorySelectAll (DirectoryListSelWave)
	WAVE DirectoryListSelWave
	
	// Use bitwise or instead of just setting to 1, because user may be using higher bits for other purposes
	DirectoryListSelWave = DirectoryListSelWave[p]|1
end

//******************************************************************************************************
// Structure for parameters of GUIP Directory Load
// Last Modified 2013/06/26 by Jamie Boyd
Structure GUIPDirectoryLoadStruct
	String ImportPathStr // string containing the name of an Igor path to the Directory on disk from which to import files (ImportPath)
	String TargetDataFolderStr	// string containing the full path to the Igor DataFolder where you want the loaded waves to end up
	String typeString			// 4 character file type for loaded files
	String FIleDescStr			// User-supplied file description string, used for naming globals datafolder and panel
	Wave/T	DirectoryListWave		// a text wave containing a list of files in the Directory pointed to by ImportPath
	Wave DirectoryListSelWave	// a wave of same length as DirectoryList wave containing 1 for selected files and 0 for unselected files
	FUNCREF GUIPprotoFuncSSSS LoadFunc	// a reference to a function to run for loading each selected file
	FUNCREF  GUIPprotoFuncWSSSS ProcessFunc	// a reference to a function to run for post-processing each loaded wave.  If you don't post-process your waves, use  he protofunc explicitly or use $""  
	variable OverWrite			// a variable that is 0 if you want alerts upon minor errors and opportunities to manually rename waves incase of conflict, 1 if you want automatic renaming, 2 if you want automatic overwriting
	variable WaveRename		//  a variable that is 0 to leave wavenames as loaded (barring conflicts, which are handled according to "overwrite"), 1 to rename waves based on file they were loaded from,  2 to rename and strip extensions, 3 to cleanup
	string LoadOptionStr		// Will be passed to your loading function. You can use this to set options for loading, or any other purpose
	string ProcessOptionStr		// will be passed to the process string
	variable NewFolderEachFile  // set to 1 to make a new folder within the targetDataFolder for each loaded file
endstructure

//******************************************************************************************************
//  GUIP Directory Load loads the files seletced in GUIPDirectoryListWave/GUIPDirectoryListSelWave using User's load function and, optionally, post-processing function
// with options to prevent/manage overwriting of waves that already exist
// Last Modified 2014/10/22 by Jamie Boyd
Function GUIPDirectoryLoad (s)
	STRUCT GUIPDirectoryLoadStruct &S
	
	// check that the import path is valid
	PathInfo  $s.ImportPathStr
	if (V_Flag == 0)
		print "GUIP DirectoryLoad did not work because the Directory on disk from which to load the files was not specified properly."
		if (s.OverWrite == 0)
			doalert 0,"GUIP DirectoryLoad did not work because the Directory on disk from which to load the files was not specified properly.\r\r--j.b.--."
		endif
		return 1
	endif
	string pathStr = S_path
	// Make sure  that the TargetDirectory path ends in a colon
	if ((cmpstr (s.TargetDataFolderStr [strlen (s.TargetDataFolderStr) -1], ":")) != 0)
		s.TargetDataFolderStr += ":"
	endif
	// check that the Target Directory exists
	if ((DataFolderExists(s.TargetDataFolderStr)) == 0)
		print "GUIP Directory Load did not work because the DataFolder selected to put the loaded files in, \"" +  s.TargetDataFolderStr + "\", does not exist."
		if (s.OverWrite == 0)
			doalert 0,"GUIP Directory Load did not work because the DataFolder selected to put the loaded files in, \"" +  s.TargetDataFolderStr + "\", does not exist.\r\r--j.b.--."
		endif
		return 1
	endif
	//save the current DataFolder
	string oldDirectory = getDataFolder (1)
	// make a temporary Directory into which the waves will be loaded (the temp Directory acts as a namespace to prevent unintended overwriting of files in the target directory)
	if ((DataFolderExists("root:packages")) == 0)
		newDataFolder root:packages
	endif
	if ((DataFolderExists("root:packages:GUIP")) == 0)
		newDataFolder root:packages:GUIP
	endif
	newDataFolder/O/S root:packages:GUIP:dirLoadTemp
	killwaves/a/z
	KillStrings /a/z
	KillVariables/a/z
	//make some variables to iterate through files
	variable pathDepth //will be greater than 1 if we have subFolders when recursing
	variable iFile	// used to iterate through the list of files in the Directory on disk
	string fileName, pathName
	variable numFiles = dimsize (s.DirectoryListWave, 0)	//the number of files in the Directory on disk
	string loadedWaves // list of waves that were loaded
	variable NumWaves // the number of waves loaded from each file
	variable iWave	// used to iterate through the list of waves loaded from each single file on disk
	string BaseNameStr, renamedWavesList // used for renaming waves
	string proposedNameStr //name for wave to be moved to Directory, may be changed by CHL_checkAndMove
	string targetFolderStr = s.TargetDataFolderStr  //  where to move loaded files
	//metadata
	string cleanFileDescStr=CleanUpName(s.FileDescStr, 0)
	NVAR getMetaData=$"root:packages:GUIP:" + cleanFileDescStr + ":GUIPGetMetaData"
	SVAR metaDataSepStr = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPMetaDataSepStr"
	WAVE/T metaDataWave=$"root:packages:GUIP:" + cleanFileDescStr + ":GUIPMetaDataWave"
	variable iMD, nMDs=numPnts(metaDataWave)
	string MDnoteStr
				
	for(iFile = 0; iFile < numFiles; iFile += 1)
		if ((s.DirectoryListSelWave [iFile] [0]) == 1)	// then we have a selected file
			pathDepth = ItemsInList(s.DirectoryListWave [iFile] [0] , ":")
			// Call the user-supplied file-loading function
			if ( pathDepth== 1)
				fileName =  s.DirectoryListWave [iFile] [0]
				pathName = s.ImportPathStr
			else
				fileName = StringFromList(pathDepth-1, s.DirectoryListWave [iFile] [0], ":")
				NewPath /O/Q GUIPDirSubPath, pathStr + RemoveListItem(pathDepth-1,  s.DirectoryListWave [iFile] [0], ":")
				pathName = "GUIPDirSubPath"
			endif
			s.LoadFunc (pathName,fileName, s.LoadOptionStr, s.FIleDescStr)
			// make MDStr to get ready to add metadata to wavenote
			if (getMetaData)
				MDnoteStr=""
				BaseNameStr = RemoveEnding(fileName, s.typeString)
				for	(iMD=0; iMD < nMDs; iMD += 1)
					MDnoteStr += metaDataWave[iMD] +skMDKeyValSep + stringfromlist (iMD, baseNameStr, metaDataSepStr) + skMDPairSep
				endfor
			endif
			// see what was loaded
			SVAR/Z loadedWavesG = :S_waveNames
			NVAR/Z V_FlagG = :V_flag
			if ((SVAR_EXISTS(loadedWavesG)) && (NVAR_EXISTS (V_FlagG)))
				loadedWaves = loadedWavesG
				NumWaves = V_FlagG
			else
				loadedWaves =  WaveList("*", ";", "" )
				NumWaves = itemsinlist (loadedWaves)
			endif
			if ((numWaves ==0)  || (numWaves == -1))// set numWaves to -1 if you handled all the moving/renaming in the load function, and you don't want a warning
				if (numWaves ==0)
					print "No Waves were loaded from the file " + s.DirectoryListWave [iFile] + "."
				endif
				killwaves/a/z
				killstrings/a/z
				killvariables /a/z 
				continue
			endif
			// rename loaded waves : s.WaveRename = 0 to leave wavenames as loaded (barring conflicts, which are handled according to "overwrite")
			//  1 to rename waves based on file they were loaded from,  2 to rename and strip extensions, 3 to rename, strip, and clean up
			if (s.WaveRename ==0) // Loading function will have made good Igor names
				renamedWavesList = loadedWaves
			else
				if (s.WaveRename ==1)	 // rename waves based on file they were loaded from
					BaseNameStr = CleanupName(fileName, 1)
				elseif (s.WaveRename ==2)  // rename and strip extensions
					BaseNameStr = CleanUpName (RemoveEnding(fileName, s.typeString),1)
				elseif (s.WaveRename == 3) // strip,cleanup, and make name non-liberal
					BaseNameStr = CleanUpName (RemoveEnding(fileName, s.typeString),0)
				endif
				if (numWaves == 1)
					WAVE loadedWave = $stringFromlist (0, loadedWaves, ";")
					Rename loadedWave, $BaseNameStr
					renamedWavesList = BaseNameStr + ";"
				else // need to use baseName + number for the waves. May ned to truncate name to accomodate
					if (numWaves > 1000)
						BaseNameStr = BaseNameStr [0, max (31, strlen (baseNameStr)-6)]
					elseif  (numWaves > 100)
						BaseNameStr = BaseNameStr [0, max (31, strlen (baseNameStr)-5)]
					elseif  (numWaves > 10)
						BaseNameStr = BaseNameStr [0, max (31, strlen (baseNameStr)-4)]
					else
						BaseNameStr = BaseNameStr [0, max (31, strlen (baseNameStr)-3)]
					endif
					for (iWave = 0, renamedWavesList = "" ; iWave < NumWaves; iWave +=1)
						WAVE loadedWave = $stringFromlist (iWave, loadedWaves, ";")
						Rename loadedWave, $BaseNameStr + "_" + num2str (iWave)
						renamedWavesList += BaseNameStr + "_" + num2str (iWave) + ";"
					endfor
				endif
			endif
			// Move loaded wave(s) to requested Directory with checking
			if (s.NewFolderEachFile)
				// make a new directory based on cleaned up file name
				targetFolderStr = s.TargetDataFolderStr  + PossiblyQuoteName (cleanupName (RemoveEnding(fileName, s.typeString), 0)) 
				newdatafolder/o $targetFolderStr
				targetFolderStr += ":"
			endif
			for (iWave =0; iWave < NumWaves; iWave +=1)
				// add metadata to wavenote
				if (getMetaData)
					WAVE loadedWave = $stringFromlist (iWave, loadedWaves, ";")
					Note loadedwave MDnoteStr
				endif
				proposednameStr = stringFromList (iWave, renamedWavesList, ";")
				WAVE loadedWave = $proposednameStr
				if (GUIPCheckAndMove (fileName, loadedWave, s.OverWrite, proposednameStr, targetFolderStr) ==1) // moving cancelled
					continue
				endif
				// run users process function
				WAVE movedWave = $targetFolderStr + possiblyquotename (proposednameStr)
				setdatafolder $targetFolderStr
				s.ProcessFunc (movedWave, s.ImportPathStr, s.DirectoryListWave [iFile], s.ProcessOptionStr,  s.FIleDescStr)
				setdatafolder root:packages:GUIP:dirLoadTemp
			endfor
			// At the end of processing each loaded file, we clear out the temp Directory so we can start fresh with the next file.
			killwaves/a/z
			killstrings/a/z
			killvariables /a/z 
		endif
	endfor
	setDataFolder oldDirectory
	KillDataFolder root:packages:GUIP:dirLoadTemp
	return 0
End

//******************************************************************************************************
// This function checks for name conflicts with the waves in the target Directory, and either renames or  overwrites the wave, depending on the options specified, and
// moves the wave into the target Directory. It is called by GUIPDirectoryLoad, but can also be used in your own procedures.
// returns 0 if wave was moved to target folder, returns 1 if user cancelled
// Note that proposedNameString is passed by reference, so if user changes the name of the wave to avoid conflicts in target folder, this string will reflect the change 
// Last Modified: 2013/06/28 by Jamie Boyd
Static Function GUIPCheckAndMove (filename, theloadedwave, OverWrite, proposednameStr, TargetDataFolderStr)
	string filename
	WAVE theloadedwave		// A wave reference to the wave you want to move
	variable OverWrite		// a variable that is 0 if you want alerts upon minor errors and opportunities to manually rename waves incase of conflict, 1 if you want automatic renaming, 2 if you want automatic overwriting
	string &proposedNameStr	// A string containing the name you want to give to the new wave in the target Directory. It will be checked for name conflicts and possibly changed
	string TargetDataFolderStr	// The name of the Directory you want to move the wave into
	
	// Check that the loaded wave reference is valid
	if (!(waveexists (theloadedwave)))
		if (OverWrite == 0)
			doalert 0,"GUIP Directory Check and Move  did not work because the wave reference that was passed to it was not valid."
		endif
		return 1
	endif
	// Make sure  that the TargetDirectory path ends in a colon
	if ((cmpstr (TargetDataFolderStr [strlen (TargetDataFolderStr) -1], ":")) != 0)
		TargetDataFolderStr += ":"
	endif
	// check that the Target Directory exists
	if ((DataFolderExists(TargetDataFolderStr)) == 0)
		if (OverWrite == 0)
			doalert 0,"GUIP Directory Check and Move  did not work because the DataFolder selected to put the loaded files in, \"" +  TargetDataFolderStr + "\", does not exist.\r\r--j.b.--."
		endif
		return 1
	endif
	// check for a name conflict
	string oldDirectory
	string oldNameStr=proposedNameStr, promptNameStr
	variable ExitCond=0 // 1 = overwrite old wave, 2 = rename new wave, 3 = cancel loading. Set when we exit the loop
	WAVE/Z checkwave = $(TargetDataFolderStr + PossiblyQuoteName (proposedNameStr))
	for (; (ExitCond==0) && (WaveExists(checkwave));)
		switch (overwrite)
			case 0:	//user gets alerts and rename dialog
				doalert /T="Wave OverWrite Alert" 2, "From \"" + filename + "\": A wave named " + proposedNameStr + " already exists in " + stringfromlist (itemsinlist (TargetDataFolderStr, ":") -1, TargetDataFolderStr, ":")  + ". Overwrite it? Press yes to overwrite the old wave, no to rename the new wave, or cancel to abort loading the new wave."
				switch(V_Flag)	// numeric switch for result from the doalert. 1 =overwrite, 2 = rename new wave, 3 = cancel loading
					case 1:		// yes to overwrite
						ExitCond =1
						break
					case 2:		// no to overwrite. Prompt for  a new name
						promptNameStr = oldNameStr
						prompt promptNameStr, "New Wave Name:"
						doprompt "Rename the wave " + oldNameStr, promptNameStr
						if (V_Flag ==1) // cancel was clicked. Cancel loading
							ExitCond =3
						else // do prompt succeeded
							ProposedNameStr =cleanupname (promptNameStr, 1)
							WAVE/Z checkwave = $TargetDataFolderStr + possiblyQuoteName (ProposedNameStr)
						endif
						break
					case 3:  //cancel to stop loading this file
						ExitCond =3
						break
				endswitch
				break
			case 1:  // don't want alerts, but automatically rename. The new name will be the old name plus "_n" where n is a number starting from 1 to make the name unique
				// we have to change Directory to the target Directory because unique name only works in the context of the current Directory.
				oldDirectory = getDataFolder (1)
				setDataFolder TargetDataFolderStr
				ProposedNameStr = UniqueName(oldNameStr + "_", 1, 1)
				setDataFolder oldDirectory
				ExitCond = 2
				break
			case 2: //overwrite without asking user
				ExitCond = 1
				break
			default:		// a non-supported value for overwrite was passed
				doalert 0, "Canceling loading for the wave \"" + nameofWave (theLoadedWave) + "\ because a non-supported value for overwrite (" + num2str (overwrite) + ") was given."
				return 1
				break
		endswitch
	endfor
	// move/rename or overwrite as indicated 
	Switch (ExitCond)
		case 0: // there was no name conflict, or conflict was resolved by renaming new wave
		case 2:
			MoveWave TheLoadedWave, $TargetDataFolderStr + possiblyQuoteName (ProposedNameStr)
			return 0
			break
		case 1:  // overwrite old wave
			Duplicate/o TheLoadedWave $TargetDataFolderStr +  possiblyQuoteName (ProposedNameStr)
			return 0
			break
		case 3: // cancel loading this wave
			//doalert 0, "Canceling loading for the wave \"" + nameofWave (theLoadedWave) + "\"."
			GUIPKillDisplayedWave (TheLoadedWave)
			return 1
			break
	EndSwitch
end

//*****************************************************************************************************
// Resizes the controls (list box and setvariables) when the panel is resized
// Last modified 2015/06/17 by jamie Boyd
Static Function GUIPDirPanelHook(s)
	STRUCT WMWinHookStruct &s
	
	if (s.eventCode ==6)
		 string cleanFileDescStr = removeEnding (s.WInName, "Loader")
		 NVAR extraVertPix = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPextraVertPix" 
		// test for minimum width,  height
		variable doMove=0
		if (s.winRect.right < kMinDirPanelWidth)
			s.winRect.right  = kMinDirPanelWidth
			doMove += 1
		endif
		if (s.winRect.bottom < kMinDirPanelHeight + extraVertPix)
			s.winRect.bottom = kMinDirPanelHeight + extraVertPix
			doMove +=2
		endif
		if (doMove > 0)
			variable winFudge = 72/screenresolution
			GetWindow $s.WinName wsize
			if (doMove & 1)
				V_right=V_left + kMinDirPanelWidth * winFudge
			endif
			if (doMove & 2) 
				V_bottom = V_top + (kMinDirPanelHeight + extraVertPix) * winFudge
			endif
			movewindow /w=$s.winName V_left, V_top, V_right, V_bottom
		endif
		// adjust width of GUIPMatchStrSetvar, and move Update and SelectAll buttons to accomodate
		variable ctrlHpos, ctrlVpos, ctrlWidth, ctrlHeight, LBheight
		 ctrlHpos = s.winRect.right - 117
		Button GUIPSelectAllButton win =$s.winName, pos={(ctrlHpos),29}
		ctrlHpos -= 93
		Button GUIPUpdateDirListButton win =$s.winName,pos={(ctrlHpos),29}
		ctrlWidth =  ctrlHpos -9
		SetVariable GUIPmatchSetvar win =$s.winName, size={(ctrlWidth),16}
		// adjust size of listBox
		ctrlWidth= s.winRect.right -4
		LBheight = s.winRect.bottom -kDirPanelReservedBottom - extraVertPix - kDirPanelReservedTop
		ListBox GUIPFilesList win =$s.winName,  pos={2, (kDirPanelReservedTop + extraVertPix)},size={ctrlWidth, LBheight}
		// adjust vertical position of controls that need to go below listbox
		CheckBox GUIPAddMetaDataCheck win =$s.winName,pos={4,(kDirPanelReservedTop + extraVertPix + LBheight + 2)}
		SetVariable GUIPMetaDataSepSetVar win =$s.winName,pos={144,(kDirPanelReservedTop + extraVertPix + LBheight + 2)}
		moveSubWindow/w = $s.winName + "#T0" fnum = (3, ((kDirPanelReservedTop + extraVertPix + LBheight + 22)),(s.winRect.right-3),(kDirPanelReservedTop	+ extraVertPix +LBheight + 142))
		ModifyTable/w = $s.winName + "#T0" width[1]=(s.winRect.right-55)
		PopupMenu GUIPLoadFolderPopmenu win =$s.winName, pos={4,(kDirPanelReservedTop + extraVertPix + LBheight + 144)}
		TitleBox GUIPLoadFolderTitle win =$s.winName, pos={107,(kDirPanelReservedTop + extraVertPix + LBheight + 147)}
		CheckBox GUIPNewFolderCheck  win =$s.winName,  pos={4,(kDirPanelReservedTop + extraVertPix + LBheight + 167)}
		PopupMenu GUIPWaveNamepopup win =$s.winName,pos={4,(kDirPanelReservedTop + extraVertPix + LBheight + 185)}
		PopupMenu GUIPoverwritepopup win =$s.winName,pos={3,(kDirPanelReservedTop + extraVertPix + LBheight +208)}
		// also need to adjust horizontal positons/widths of options setvars
		ctrlHpos =  s.winRect.right - 97
		Button GUIPLoadSelectedButton win =$s.winName,pos={(ctrlHpos),(kDirPanelReservedTop + extraVertPix + LBheight + 231)},size={94,22},proc=GUIPDirectoryLoad#GUIPDirPanelLoadSelected,title="Load Selected"
		ctrlWidth = (ctrlHpos-32)/2
		ctrlHpos = 2
		SetVariable GUIPLoadOptionsSetvar win =$s.winName,pos={(ctrlHpos),(kDirPanelReservedTop + extraVertPix + LBheight + 235)},size={(ctrlWidth+24),15},title="Options-Load"
		ctrlHpos += ctrlWidth + 26
		SetVariable GUIPProcessOptionsSetvar win =$s.winName,pos={(ctrlHpos),(kDirPanelReservedTop + extraVertPix + LBheight + 235)},size={(ctrlWidth),15},title="Process"
		funcref GUIPProtoFuncWinHook extraResize = $cleanFileDescStr + "_ResizeHook"
		extraResize (s)
		return 1
	endif
	return 0
End

//*****************************************************************************************************
//Sets a global string to the directory on disk where the files are located and lists the contents of that folder in the listbox
// Last Modified 2013/05/21 by Jamie Boyd
Static Function GUIPDirPanelSelDir(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string cleanFileDescStr = RemoveEnding(ba.win, "Loader")
			SVAR GUIPFileDescriptionStr = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPFileDescriptionStr"
			SVAR GUIPtypelimitstr = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPtypelimitstr"
			SVAR dirStr = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDiskDirStr"
			SVAR GUIPMatchStr = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPMatchStr"
			NVAR recurse =  $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPRecurseDir"
			string importPathStr = cleanFileDescStr+ "LoadPath"
			if (cmpstr ("GUIPSelectDirButton", ba.ctrlName) ==0)
				dirStr = GUIPDirectorySetImPathProc(importPathStr, GUIPFileDescriptionStr)
			endif
			WAVE/T GUIPDirectoryListWave = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDirectoryListWave"
			WAVE/T GUIPDirectoryListSelWave = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDirectoryListSelWave"
			GUIPDirectoryShowFiles (ImportpathStr, GUIPDirectoryListWave, GUIPDirectoryListSelWave, GUIPtypelimitstr, GUIPMatchStr, recurse)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// Updates the list of contents of the folder in the listbox when recurse option changes
// Last Modified 2013/06/26 by Jamie Boyd
Function GUIPDirGUIPRecursCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			STRUCT WMButtonAction ba
			ba.eventCode = 2
			ba.win = cba.win
			ba.ctrlname = cba.ctrlname
			GUIPDirPanelSelDir(ba)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// Updates the list of contents of the folder in the listbox when match string option changes
// Last Modified 2013/06/26 by Jamie Boyd
Function GUIPDirGUIPMatchStrProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			STRUCT WMButtonAction ba
			ba.eventCode = 2
			ba.win = sva.win
			ba.ctrlname = sva.ctrlname
			GUIPDirPanelSelDir(ba)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//*****************************************************************************************************
//Selects all files shown in the listBox
// Last Modified 2013/05/21
Static Function GUIPDirPanelSelectAll(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string  cleanFileDescStr = RemoveEnding(ba.win, "Loader")
			WAVE GUIPDirectoryListSelWave = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDirectoryListSelWave"
			 GUIPDirectorySelectAll (GUIPDirectoryListSelWave)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
//Sets a global string containing the destination folder where the newly created Igor waves willl be placed
// Last Modified 2014/06/30
Static Function GUIPDirPanelSetDestFolder(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			string popStr = pa.popStr
			string  cleanFileDescStr = RemoveEnding(pa.win, "Loader")
			SVAR folderStr = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDataFolderStr"
			if (cmpstr (popStr, "New Datafolder") == 0)
				string newFolderName, enclosingFolder
				prompt newFolderName, "Name for New Folder:"
				prompt enclosingFolder, "Make New Folder Here:", popup, "root:;" +  GUIPListObjs ("root:", 4, "*", 13, "\\M1(No Folders")
				doPrompt "Make New Folder", newFolderName, enclosingFolder
				if (v_Flag)
					popstr =""
				else
					newFolderName = CleanupName(RemoveEnding (newFolderName, ":"), 1)
					popstr = enclosingFolder + PossiblyQuoteName (newFolderName)
					if (datafolderExists (popstr))
						doalert 0, "The datafolder, \"" + popStr + "\", already exists."
					else
						newdatafolder $popStr
					endif
					 popStr += ":"
				endif
			endif
			FolderStr = popStr
		case -1: // control being killed
			break
	endswitch

	return 0
End

//*****************************************************************************************************
//Loads the selected files with GUIPDirectoryLoad calling the user-supplied load function
// Last Modified 2014/06/17
Static Function GUIPDirPanelLoadSelected (ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string cleanFileDescStr = RemoveEnding(ba.win, "Loader")
			SVAR GUIPDataFolderStr =  $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDataFolderStr"
			if (!(DataFolderExists (GUIPDataFolderStr)))
				doalert 0, "Choose a target data folder where the loaded waves will be placed."
				return 1
			endif
			// Get info from popupmenus
			ControlInfo /W=$ba.win  GUIPoverwritepopup
			variable doOverWrite = V_Value -1
			ControlInfo /W=$ba.win  GUIPWaveNamepopup
			variable doRename = V_Value-1			
			// make and fill a file loading structure
			STRUCT GUIPDirectoryLoadStruct s
			s.ImportPathStr = cleanFileDescStr + "LoadPath"
			s.TargetDataFolderStr= GUIPDataFolderStr
			Wave/T s.DirectoryListWave=  $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDirectoryListWave"
			WAVE  s.DirectoryListSelWave = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPDirectoryListSelWave"
			SVAR GUIPloadFuncStr =  $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPloadFuncStr"
			SVAR GUIPLoadOptionStr = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPLoadOptionStr" 
			SVAR GUIPprocessFuncStr = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPprocessFuncStr"
			SVAR GUIPProcessOptionStr =$"root:packages:GUIP:" + cleanFileDescStr + ":GUIPProcessOptionStr" 
			NVAR GUIPNewFolderEachFile =$"root:packages:GUIP:" + cleanFileDescStr +":GUIPNewFolderEachFile" 
			SVAR GUIPtypelimitstr = $"root:packages:GUIP:" + cleanFileDescStr + ":GUIPtypelimitstr" 
			FUNCREF GUIPprotoFuncSSSS s.LoadFunc = $GUIPloadFuncStr
			FUNCREF  GUIPprotoFuncWSSSS s.ProcessFunc = $GUIPprocessFuncStr
			s.LoadOptionStr =GUIPLoadOptionStr
			s.ProcessOptionStr = GUIPProcessOptionStr
			s.OverWrite = doOverwrite
			s.WaveRename = doRename
			s.NewFolderEachFile = GUIPNewFolderEachFile
			s.typeString = GUIPtypelimitstr
			s.FileDescStr = cleanFileDescStr
			 GUIPDirectoryLoad (s)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
//**************************** Code to make a panel for loading binary data in various formats ****************************
//*****************************************************************************************************

Static Constant kSegmentSize = 250000 //how many bytes of the file we are going to load at one time

Menu "Load Waves"
	Submenu "Packages"
		"Binary File Reader", GUIPDirectoryLoad#BinaryFileReader ()
	end
end

//*****************************************************************************************************
//make the packages folder and the global variables and the control panel
// Last Modified 2013/07/02 by Jamie Boyd
Static Function BinaryFileReader ()
	
	if (!(datafolderexists ("root:packages:")))
		newdatafolder root:packages
	endif
	if (!(datafolderexists ("root:packages:GUIP")))
		newdatafolder root:packages:GUIP
	endif
	if (!(datafolderexists ("root:packages:GUIP:BinaryReader")))
		newdatafolder root:packages:GUIP:BinaryReader
		//make waves for the list box showing the first segment of data in the selected file as characters
		make/o/t/n =  (kSegmentSize,2) root:packages:GUIP:BinaryReader:FileListWave
		make/o/n =  (kSegmentSize,2, 2) root:packages:GUIP:BinaryReader:FileListSelWave
		WAVE selWave=root:packages:GUIP:BinaryReader:FileListSelWave
		setdimlabel 2,1, forecolors selWave
		//First row of FileListWave will show byte offset
		SetDimLabel 1,0,BytePos,root:packages:GUIP:BinaryReader:FileListWave
		//Second row will show the data as a character
		SetDimLabel 1,1,Char,root:packages:GUIP:BinaryReader:FileListWave
		 // make a color wave used to show ASCII control characters in red
		make/w/u/o root:packages:GUIP:BinaryReader:cWave= {{0,65535}, {0, 16384}, {0, 16384}}
		//make a temporary byte wave to read data into before displaying it in the listbox
		make/b/u/o/n = (kSegmentSize) root:packages:GUIP:BinaryReader:TempWave
		// make a numeric wave that we will redimension for display in table and graph
		make/o/n=2 root:packages:GUIP:BinaryReader:DataWave
		//a global string to contain a list of segments in the file for loading
		string/G root:packages:GUIP:BinaryReader:SegmentsList = ""
		//global variable to hold reference nmber to the open file
		variable/G root:packages:GUIP:BinaryReader:BRrefNum = nan
		//global string to display name of open file in a title box
		string/G root:packages:GUIP:BinaryReader:fileNameStr = ""
	endif
	//try to bring panel to the front
	doWindow/F Binary_Reader
	if (V_Flag)
		return 1
	endif
	//make the panel, as it was not already open
	NewPanel /K=1/N=Binary_Reader/W=(0,44,456,448) as "Binary Reader"	
	Button OpenFileButton win=Binary_Reader,pos={4,2},size={67,22},proc=GUIPDirectoryLoad#BRopenFIleProc,title="Open File"
	Button OpenFileButton win=Binary_Reader, help = {"Selects a file on disk to open for examining."}
	TitleBox FileNameTitle win=Binary_Reader,pos={75,7},size={332,12},frame=0
	TitleBox FileNameTitle win=Binary_Reader,variable= root:packages:GUIP:BinaryReader:fileNameStr
	TitleBox FileNameTitle win=Binary_Reader,help={"Shows name of file currently open for examining."}
	PopupMenu SegmentsPopup win=Binary_Reader,pos={4,28},size={103,20},proc=GUIPDirectoryLoad#BRLoadSegmentProc,title="Load Segment"
	PopupMenu SegmentsPopup win=Binary_Reader,mode=1,popvalue="0",value= #"root:packages:GUIP:BinaryReader:SegmentsList"
	PopupMenu SegmentsPopup win=Binary_Reader,help = {"Sets segment of file currently loaded. Segment size is set by constant kSegmentSize in GUIPDirectoryLoad.ipf."}
	PopupMenu DataFormatPopUp win=Binary_Reader,pos={4,54},size={142,20},title="Data Format"
	PopupMenu DataFormatPopUp win=Binary_Reader,mode=4,popvalue="4 byte float",value= #"\"1 byte int;2 byte int (word);4 byte int;4 byte float;8 byte float (double)\""
	PopupMenu DataFormatPopUp win=Binary_Reader, help = {"Show selection will load selected data in chosen format."}
	PopupMenu UnSignedPopup win=Binary_Reader,pos={4,79},size={135,20},title="Integer Data is"
	PopupMenu UnSignedPopup win=Binary_Reader,mode=1,popvalue="Signed",value= #"\"Signed;UnSigned\""
	PopupMenu UnSignedPopup win=Binary_Reader, help = {"If data format is an integer type, show selection will load selected data as signed or unsigned, according to selected choice."}
	PopupMenu EndianPopUp win=Binary_Reader,pos={4,105},size={191,20},title="Byte Order"
	PopupMenu EndianPopUp win=Binary_Reader,mode=2,popvalue="Little-endian (Intel)",value= #"\"Big-endian (PowerPC);Little-endian (Intel)\""
	PopupMenu EndianPopUp win=Binary_Reader, help = {"Multibyte data will be loaded with with the selected byte order. If data was generated on a PC or a Mac less than 10 years old, you probably want little-endian."}
	Button ShowSelectionButton win=Binary_Reader,pos={4,130},size={101,22},proc=GUIPDirectoryLoad#BRShowSelection,title="Show Selection"
	Button ShowSelectionButton win=Binary_Reader, help = {"Shows in the table and in the graph the values of the bytes that are selected in the BytePos listBox, using the format specified by the popup menus."}
	Button PrintButton win=Binary_Reader,pos={110, 130},size={79,22},proc=GUIPDirectoryLoad#BRprintChars,title="Print Chars"
	Button PrintButton win=Binary_Reader, help = {"Prints the selected characters from the listbox to the command history. shift-click to print only low order bytes (unicode kludge)."}
	Button SaveDataButton win=Binary_Reader,pos={4,159},size={79,22},proc=GUIPDirectoryLoad#BRsaveData,title="Save Data"
	Button SaveDataButton win=Binary_Reader, help = {"Saves data from the table/graph to a ne wave of user's choosing."}
	ListBox FileAsByteList win=Binary_Reader,pos={1,184},size={124,218}
	ListBox FileAsByteList win=Binary_Reader,listWave=root:packages:GUIP:BinaryReader:FileListWave
	ListBox FileAsByteList win=Binary_Reader,selWave=root:packages:GUIP:BinaryReader:FileListSelWave
	ListBox FileAsByteList win=Binary_Reader,colorWave=root:packages:GUIP:BinaryReader:cWave,mode= 3
	ListBox FileAsByteList win=Binary_Reader,editStyle= 1,widths={70,37},userColumnResize= 1
	ListBox FileAsByteList win=Binary_Reader,help={"Use to select the segment of data to show with the \"Show Selection\" button."}
	TitleBox dataTitle win=Binary_Reader,pos={125,170},size={98,12}, frame = 0, title="Byte Pos/Val"
	TitleBox dataTitle win=Binary_Reader, help = {"Shows values at selected byte positions in the selected file loaded according to choices in the popupmenus."}
	// Table of data wave
	WAVE dataWave = root:packages:GUIP:BinaryReader:DataWave
	Edit/W=(127,184,253,398)/FG=(,,,FB)/HOST=#  DataWave.xy
	ModifyTable width(Point)=0,alignment(DataWave.xy)=0,sigDigits(DataWave.x)=12
	ModifyTable width(DataWave.x)=40,format(DataWave.d)=5,width(DataWave.d)=68
	ModifyTable showParts=0xA0
	ModifyTable horizontalIndex=1
	RenameWindow #,T0
	SetActiveSubwindow ##
	// Graph of data Wave
	Display/W=(254,23,453,402)/HOST=#  DataWave
	ModifyGraph lblMargin(bottom)=2
	ModifyGraph axOffset(left)=-3.875
	Label bottom "File Position (\\U)"
	RenameWindow #,G0
	SetActiveSubwindow ##
	// set resize hook
	SetWindow Binary_Reader hook(PanelHook)=GUIPDirectoryLoad#BRPanelHook
end

//*****************************************************************************************************
// Resizes the ListBox control, the table subwindow, and the graph subwindow when the panel is resized
// Closes the open file and also kills the packages folder when the Binary_Reader panel is closed 
// Last modified 2013/06/14 by jamie Boyd
	Static Constant kMinBRPanelWidth =380
	Static Constant kMinBRPanelHeight =260
Static Function BRPanelHook(s)
	STRUCT WMWinHookStruct &s
	
	if (s.eventCode ==6)
		// test for minimum width,  height
		variable doMove=0
		if (s.winRect.right < kMinBRPanelWidth)
			s.winRect.right  = kMinBRPanelWidth
			doMove += 1
		endif
		if (s.winRect.bottom < kMinBRPanelHeight)
			s.winRect.bottom = kMinBRPanelHeight
			doMove +=2
		endif
		if (doMove > 0)
			variable winFudge = 72/screenresolution
			GetWindow $s.WinName wsize
			if (doMove & 1)
				V_right=V_left + kMinBRPanelWidth * winFudge
			endif
			if (doMove & 2)
				V_bottom = V_top + kMinBRPanelHeight * winFudge
			endif
			movewindow /w=$s.winName V_left, V_top, V_right, V_bottom
		endif
		// adjust height of FileAsByteList listBox
		variable ctrlWidth, ctrlHeight
		ctrlHeight = (s.winRect.bottom - s.winRect.Top - 184 -2)
		ListBox FileAsByteList win= $s.winName, size={124,(ctrlHeight)}
		// adjust size of graph and table subwindow
		variable  winRight, winBottom
		winRight = (s.winRect.Right - 2)
		winBottom = (s.winRect.Bottom - 2)
		moveSubWindow/w = $s.winName + "#T0" fnum = (127, 184, 253, winBottom - 4)
		moveSubWindow/w = $s.winName + "#G0" fnum = (254, 23, winRight, winBottom)
		return 1
	elseif (s.eventCode ==2) // Kill
		NVAR BRrefNum = root:packages:GUIP:BinaryReader:BRrefNum
		variable LocalRefNum = BRrefNum
		FStatus LocalRefNum
		if (V_Flag)
			Close LocalRefNum
		endif
		killdatafolder/Z root:packages:GUIP:BinaryReader
		return 1
	endif
	return 0
End


//*****************************************************************************************************
//Open a file on disk, save the refernce number in a global variable, and load the first segment of the file
// Last Modified 2013/07/02 by Jamie Boyd
Static Function BRopenFIleProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			//make reference to global variables
			SVAR fileNameStr =root:packages:GUIP:BinaryReader:fileNameStr
			NVAR BRrefNum = root:packages:GUIP:BinaryReader:BRrefNum
			variable localRefNum = BRrefNum
			SVAR segmentsList = root:packages:GUIP:BinaryReader:SegmentsList
			segmentsList = ""
			WAVE/T fileListWave = root:packages:GUIP:BinaryReader:FileListWave
			WAVE fileListSelWave = root:packages:GUIP:BinaryReader:FileListSelWave
			//close the file that was previously open, if any
			FStatus localRefNum
			if (V_Flag)
				Close localRefNum
				BRrefNum = Nan
			endif
			//Open a new file chosen by the user and save the refnum in the global variable
			Open/T="????" /M="Choose a file to examine"/R localRefNum
			fileNameStr = S_fileName
			if ((cmpstr (S_fileName, "")) == 0)
				BRrefNum = nan
				fileListWave [] [1] = ""
				return 0
			else
				BRrefNum = localRefNum
			endif
			//Find the number of segments in the file, and make the list of segments used in the popmenu
			FStatus localRefNum
			variable ii, numSegments = ceil (V_logEOF/kSegmentSize)
			for (ii = 0; ii < numSegments; ii += 1)
				segmentsList += num2str (ii + 1) + ";"
			endfor
			//Load the first Segment in the file
			STRUCT WMPopupAction pa
			pa.eventcode =2
			pa.popnum=1
			pa.popStr = "1"
			pa.win = "BInary_Reader"
			BRLoadSegmentProc(pa)
			PopupMenu SegmentsPopUp win = Binary_Reader, mode=1
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End
	
//*****************************************************************************************************
//Load the segment selected from the popup menu and show the character and byte pos
// Last Modified 2013/07/02 by Jamie Boyd
Static Function BRLoadSegmentProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			//References to globals
			SVAR fileNameStr =root:packages:GUIP:BinaryReader:fileNameStr
			NVAR BRrefNum = root:packages:GUIP:BinaryReader:BRrefNum
			variable localRefNum = BRrefNum
			WAVE/T fileListWave = root:packages:GUIP:BinaryReader:FileListWave
			WAVE FileListSelWave = root:packages:GUIP:BinaryReader:FileListSelWave
			WAVE tempwave = root:packages:GUIP:BinaryReader:tempwave
			//check that the file reference is valid
			fstatus localRefNum
			if (!(V_Flag))
				doAlert 0, "The file, " + fileNameStr + " is not open."
				FileNameStr = ""
			endif
			//load the segment into the temp wave. If it is last segment, only load to the end of the file
			if (V_logEOF < (pa.popNum * kSegmentSize))
				redimension/n = (V_logEOF-((pa.popNum -1) * kSegmentSize)) tempwave
				redimension/n = ((V_logEOF-((pa.popNum -1) * kSegmentSize)), 2) fileListWave
				redimension/n = ((V_logEOF-((pa.popNum -1) * kSegmentSize)), 2, 2) fileListSelWave
			else
				redimension/n = (kSegmentSize) tempwave
				redimension/n = ((kSegmentSize), 2) fileListWave
				redimension/n = ((kSegmentSize), 2,2) fileListSelWave
			endif
			FSetPos localRefNum, ((pa.popNum - 1) * kSegmentSize)
			FBinRead/f=1/u localRefNum, tempwave
			//show the loaded segment in the fileListBox in char format. Print out abreviatons for escape codes
			// Use 3rd dimension for color index,
			variable ii, points = numpnts (tempwave)
			string bytePosStr
			for (ii=0;ii< points;ii+=1)
				// escape codes are ASCII 31 or less
				if (tempWave [ii] > 31) // not an escape code
					fileListWave [ii] [1] =num2char ( tempwave [ii])
					fileListSelWave [ii] [] [1] = 0 // set layer 1 to 0, black
				else // an escape code
					switch (tempWave [ii])
						case 0:
							fileListWave [ii] [1] = "NUL" // null character
							break
						case 1:
							fileListWave [ii] [1] = "SOH" // start of heading
							break
						case 2:
							fileListWave [ii] [1] = "STX" // start of text
							break
						case 3:
							fileListWave [ii] [1] = "ETX" //end of text
							break	
						case 4:
							fileListWave [ii] [1] = "EOT" // end of transmission
							break
						case 5:
							fileListWave [ii] [1] = "ENQ" // enquiry
							break
						case 6:
							fileListWave [ii] [1] = "ACK" // acknowledge
							break
						case 7:
							fileListWave [ii] [1] = "BEL" // bell
							break	
						case 8:
							fileListWave [ii] [1] = "BS" // back space
							break
						case 9:
							fileListWave [ii] [1] = "TAB" // horizontal tab
							break
						case 10:
							fileListWave [ii] [1] = "LF" // line feed (new line)
							break
						case 11:
							fileListWave [ii] [1] = "VT" // verical tab
							break
						case 12:
							fileListWave [ii] [1] = "FF" // form feed (new page)
							break
						case 13:
							fileListWave [ii] [1] = "CR" // carriage return
							break
						case 14:
							fileListWave [ii] [1] = "SO" // shift out
							break
						case 15:
							fileListWave [ii] [1] = "SI" // shift in
							break
						case 16:
							fileListWave [ii] [1] = "DLE" // data link escape
							break
						case 17:
							fileListWave [ii] [1] = "DC1" // device control 1
							break
						case 18:
							fileListWave [ii] [1] = "DC2" // device control 2
							break
						case 19:
							fileListWave [ii] [1] = "DC3" // device control 3
							break
						case 20:
							fileListWave [ii] [1] = "DC4" // device control 4
							break
						case 21:
							fileListWave [ii] [1] = "NAK" // negative acknowledge
							break
						case 22:
							fileListWave [ii] [1] = "SYN" // synchronous idle
							break
						case 23:
							fileListWave [ii] [1] = "ETB" //end of transmission block
							break
						case 24:
							fileListWave [ii] [1] = "CAN" // cancel
							break
						case 25:
							fileListWave [ii] [1] = "EM" //end of medium
							break
						case 26:
							fileListWave [ii] [1] = "SUB" // substitute
							break
						case 27:
							fileListWave [ii] [1] = "ESC" // escape
							break
						case 28:
							fileListWave [ii] [1] = "FS" // file separator
							break
						case 29:
							fileListWave [ii] [1] = "GS" // group separator
							break
						case 30:
							fileListWave [ii] [1] = "RS" // record separator
							break
						case 31:
							fileListWave [ii] [1] = "US" // unit separator
							break
					endswitch
					fileListSelWave [ii] [] [1] = 1 // set layer 1 to 1 (red)
				endif
			// first column of file list wave is byte position in the file
			// use printf for precision
			sprintf bytePosStr, "%u", ((pa.popNum -1) * kSegmentSize)+ ii
			FileListWave [ii] [0] = bytePosStr
			endfor
			// blank the data wave
			wave dataWave = root:packages:GUIP:BinaryReader:DataWave
			redimension/n = (2) dataWave
			dataWave = 0
			// blank the title blox
			TitleBox dataTitle win= Binary_Reader,pos={125,170},size={98,12},title="Byte Pos/Val"
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End


//*****************************************************************************************************
//Show the data selected in the file listbox in the output list box by loading the data from the file with the selected options
// Last Modified 2013/07/02 by Jamie Boyd
Static Function BRShowSelection(ctrlName) : ButtonControl
	String ctrlName
	
	//Make references to globals
	NVAR BRrefNum = root:packages:GUIP:BinaryReader:BRrefNum
	variable localRefNum = BRrefNum
	WAVE/T fileListWave = root:packages:GUIP:BinaryReader:FileListWave
	WAVE fileListSelWave = root:packages:GUIP:BinaryReader:FileListSelWave
	WAVE dataWave = root:packages:GUIP:BinaryReader:dataWave
	//make sure file reference is valid
	FStatus localRefNum
	if (!(V_Flag))
		SVAR FileNameStr = root:packages:GUIP:BinaryReader:FileNameStr
		doalert 0, "The selected file, " + FileNameStr +", is not open."
		FileNameStr = ""
		return 1
	endif
	//find the start and end of the selection in the file listbox
	variable iPnt, nPnts, startpos =0,numBytes=0, selPnts
	for (iPnt = 0, nPnts =dimSize (fileListWave, 0); iPnt < nPnts; iPnt += 1)
		if (fileListSelWave [iPnt] [0] [0]== 1)
			break
		endif
	endfor
	StartPos = iPnt
	for (;iPnt < nPnts; iPnt += 1)
		if (fileListSelWave [iPnt] [0] [0]== 0)
			break
		endif
	endfor
	numBytes = (iPnt - StartPos)
		//check that data is selected
	if (numBytes == 0)
		doalert 0, "First select part of the file to show. For multibyte data formats, you need to select enough bytes to show at least one point"
		return 1
	endif
	//Read the selected bit of the file into the data wave according to the choices on these panel popups
	controlinfo/w=Binary_Reader DataFormatPopUp
	variable DataFormat = V_Value	//choices in menu listed in same order as for /F= option in FBinRead command
	controlinfo/w=Binary_Reader UnSignedPopup
	variable UnSigned = V_Value -1 //0 for Signed (default in FBInRead) 1 for unsigned (requires/U option)
	controlinfo/w=Binary_Reader EndianPopUp
	variable byteOrder = V_Value + 1 //byteorder will be 2 for bigendian, 3 for small endian to specify endian in FBinRead command
	//set the numtype variable according to Wavemetrics conventions 
	variable theNumType = 0 
	variable dataBytes //this variable will hold the number of bytes per data point
	if ((DataFormat < 4) && (UnSigned))
		theNumType += 64
	endif
	switch (DataFormat)
		case 1: //byte
			theNumType += 8
			dataBytes = 1
			selPnts = numBytes
			SetScale/P X (str2Num (fileListWave [StartPos] [0])), 1, "byte", dataWave
			if (UnSigned)
				TitleBox dataTitle win= Binary_Reader, title="Byte Pos/Val (Unsigned Byte)"
			else
				TitleBox dataTitle win= Binary_Reader, title="Byte Pos/Val (Signed Byte)"
			endif
			break
		case 2: // 2 byte word
			theNumtype += 16
			selPnts =floor(numBytes/2)
			dataBytes = 2
			SetScale/P X (str2Num (fileListWave [StartPos] [0])), 2, "byte", dataWave
			if (UnSigned)
				TitleBox dataTitle win= Binary_Reader, title="Byte Pos/Val (Unsigned Word)"
			else
				TitleBox dataTitle win= Binary_Reader, title="Byte Pos/Val (Signed Word)"
			endif
			break
		case 3: // 32 bit int
			theNumtype += 32
			selPnts = floor(numBytes/4)
			dataBytes = 4
			SetScale/P X (str2Num (fileListWave [StartPos] [0])), 4, "byte", dataWave
			if (UnSigned)
				TitleBox dataTitle win= Binary_Reader, title="Byte Pos/Val (Unsigned Long)"
			else
				TitleBox dataTitle win= Binary_Reader, title="Byte Pos/Val (Signed Long)"
			endif
			break
		case 4: //32 bit float
			theNumType += 2
			selPnts= floor(numBytes/4)
			dataBytes = 4
			SetScale/P X (str2Num (fileListWave [StartPos] [0])), 4, "byte", dataWave
			TitleBox dataTitle win= Binary_Reader, title="Byte Pos/Val (Float)"
			break
		case 5: //64 bit floating point
			theNumType += 4
			selPnts=floor(numBytes/8)
			databytes = 8
			SetScale/P X (str2Num (fileListWave [StartPos] [0])), 8, "byte", dataWave
			TitleBox dataTitle win= Binary_Reader, title="Byte Pos/Val (Double)"
			break
		default:
			doalert 0, "uh oh, the Numtype Switch did not recognize the value, " + num2str (DataFormat) + "."
			return 1
			break
	endswitch
	//Redimension  datawave for the amount and kind of data expected
	Redimension/N = (selPnts)/Y=(theNumType) DataWave
	//load the selected data into Datawave
	fsetpos localRefNum, (str2num (fileListWave [StartPos] [0]))
	if (UnSigned)
		FBinRead /B=(byteOrder)/F=(DataFormat) localRefNum, DataWave
	else
		FBinRead /B=(byteOrder)/F=(DataFormat)/U localRefNum, DataWave
	endif
End

//*****************************************************************************************************
// Prints a string of characters selected in the listbox. Control characters translated to escape sequences where supported, else octal is
// used to print them. 
// \t	represents tab character
// \r	represents return character
// \n	represents linefeed character
// \'	represents ' character
// \"	represents " character
// \\	represents \ character
// \ddd	represents arbitrary ASCII code (ddd is a 3 digit octal number)
// Null character ends one string and starts a new one. Will print like a return was entered
// If shift key is pressed, only low-order bytes are printed (a kludge for 2-byte unicode strings where low-order byte is ASCII)
// Last Modified 2013/07/04 by Jamie Boyd
Static Function BRprintChars(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			WAVE/T fileListWave = root:packages:GUIP:BinaryReader:FileListWave
			WAVE FileListSelWave = root:packages:GUIP:BinaryReader:FileListSelWave
			variable iPos, nPos = dimsize (fileListWave, 0)
			string printStr = ""
			// find first selected row
			for (iPos =0;  ((iPos < nPos) && (((FileListSelWave [iPos] [0] [0]) & 1) != 1)); iPos +=1)
			endfor
			if (iPos == nPos)
				doAlert 0, "No characters were selected."
				return 1
			endif
			// continue to unselected row, adding charcters to stirng
			if (ba.eventMod & 2)
				controlinfo/w=Binary_Reader EndianPopUp
				variable startPos =  iPos + V_Value -1
			endif
			for (; ((iPos < nPos) && (((FileListSelWave [iPos] [0] [0]) & 1) == 1)); iPos +=1)
				if ((ba.eventMod & 2) && (mod (iPos - startpos, 2)))
					continue
				endif
				StrSwitch (fileListWave [iPos] [1] [0])
					// print string and reset printStr when you reach a null character, as it would terminate the string
					case "NUL": 
						if ((cmpStr (printStr, "") != 0) && (!(ba.eventMod & 2)))
							print printStr
							printStr = ""
						endif
						break
						// escape sequences for otherwise difficult to print characters
					case "TAB":
						 if (!(ba.eventMod & 2))
							printStr +=  "\t"
						endif
						break
					case "CR":
						 if (!(ba.eventMod & 2))
							printStr += "\r"
						endif
						break
					case "LF":
						 if (!(ba.eventMod & 2))
							printStr += "\n"
						endif
						break
					case "\'":
						printStr += "\'"
						break
					case "\"":
						printStr += "\""
						break
					default: // use octal for other control characters
						if (strlen (fileListWave [iPos] [1] [0]) > 1)
							 if (!(ba.eventMod & 2))
								StrSwitch (fileListWave [iPos] [1])
									case "SOH": 
										printStr += "\001"
										break
									case  "STX": 
										printStr += "\002"
										break
									case  "ETX":
										printStr += "\003"
										break
									case  "EOT": 
										printStr += "\004"
										break
									case  "ENQ":
										printStr += "\005"
										break
									case  "ACK": 
										printStr += "\006"
										break
									case  "BEL": 
										printStr += "\007"
										break
									case  "BS": 
										printStr += "\010"
										break
									case  "VT": 
										printStr += "\013"
										break
									case  "FF": 
										printStr += "\014"
										break
									case  "SO":
										printStr += "\016"
										break
									case  "SI":
										printStr += "\017"
										break
									case  "DLE":
										printStr += "\020"
										break
									case  "DC1":
										printStr += "\021"
										break
									case  "DC2":
										printStr += "\022"
										break
									case  "DC3":
										printStr += "\023"
										break
									case  "DC4":
										printStr += "\024"
										break
									case  "NAK":
										printStr += "\025"
										break
									case  "SYN":
										printStr += "\026"
										break
									case  "ETB":
										printStr += "\027"
										break
	
									case  "EM":
										printStr += "\031"
										break
									case  "SUB":
										printStr += "\032"
										break
									case  "ESC":
										printStr += "\033"
										break
									case  "FS":
										printStr += "\034"
										break
									case  "GS":
										printStr += "\035"
										break
									case  "RS":
										printStr += "\036"
										break
									case  "US":
										printStr += "\037"
										break
								endSwitch
							endif
						else
							printStr +=fileListWave [iPos] [1] [0]
						endif
						break
				endswitch
			endfor
			print printStr
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//*****************************************************************************************************
// Saves data with a new name/location of user's choosing
// Last Modified 2013/07/04 by Jamie Boyd
Static Function BRsaveData(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// reference data wave to save
			WAVE DataWave = root:packages:GUIP:BinaryReader:Datawave
			// prompt for a name and a place
			string SavedWaveName, enclosingFolder
			prompt SavedWaveName, "Name for New Wave:"
			prompt enclosingFolder, "Save Wave Here:", popup, "root:;" +  GUIPListObjs ("root:", 4, "*", 5, "\\M1(No Folders")
			doPrompt "Save Wave", SavedWaveName, enclosingFolder
			if (v_Flag)
				return 1
			endif
			SavedWaveName = CleanupName(SavedWaveName, 0)
			// check for existing wave with same name
			WAVE/Z existingWave = $enclosingFolder + SavedWaveName
			if (WaveExists (existingWave))
				doAlert 1, "A Wave \"" + enclosingFolder + SavedWaveName + "\" already exists . OverWrite it?"
				if (V_Flag == 2)
					return 1
				endif
			endif
			// duplicate the wave and set to default scaling
			duplicate/o DataWave $enclosingFolder + SavedWaveName
			Wave savedWave = $enclosingFolder + SavedWaveName
			setscale/p x 0, 1, "", savedWave
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End
