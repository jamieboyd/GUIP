#pragma rtGlobals=3		// Use modern global access method.
#pragma IgorVersion=6.1
#pragma Version=4.1
#pragma ModuleName=GUIPDSD
#include "GUIPControls"
#include "GUIPProtoFuncs"
#include "GUIPDirectoryLoad"
// Last modified: 2014/07/15 by Jamie Boyd

// DataSet Descriptors (DSD's) are waves used to store information about how certain types of data should be plotted in a graph.  If you have different types of
// data plotted on the same graph, with different styles, and have lots of similar experiments, you can write a procedure to automate plotting different types
// of data in different styles using DSD's.  Yes, I know we have graphstyles in Igor, but they depend on the order the data is plotted to control the style, limiting
// their usefulness, at least to me.

// Each DSD is a text wave, where each line describes 1 dataset using a string list. The first item is the dataset name. The second item is the datset Type, which is user defined (see below)
// The remaining items in the list are commands to modify the plotted trace. In each command, the name of the trace is replaced with %s, making it easy to generate modify graph commands

// To make use of DSD's, you need to write a plotting function for your data types that you feed a list of waves containing data to be plotted.  It must first match up the waves with the type of 
// datasets they correspond to, and then plot the waves using the information in the DSD.  The type of data in a wave can be encoded in the wavename, in the wavenote, or some other way.
//  The simplest way is probably string matching based on the wave nam, e.g., if a wave name contains the string "cel1", then it contains the locations of cell bodies of
// neurons of class 1. If a wave name ends in "y", it is a Y-wave, and if it ends in "x", it is an x-wave.


menu "Misc"
	submenu  "Packages"
		"Make and Edit DSD files",/Q, GUIP_DSDStart ()
	end
end

//******************************************************************************************************
//---------------------------------Useful functions for your own procedures using DSDs--------------------------------
//******************************************************************************************************
// get the dataType for a given dataset Name in the given DSDwave. This function  can be called from packages using DSDs
Function/s GUIP_GetDataTypeFromDSD (DSDWave, DsetName)
	wave/T DSDWave
	string DSetName
	
	variable iDSD, numDSDEntrys = numpnts (DsdWave)
	for (iDSD = 0; iDSD < numDSDEntrys; iDSD += 1)
		if ((cmpstr (stringfromlist (0, DSDWave [iDSD]), DsetName)) == 0)
			return stringfromlist (1, DSDWave [iDSD])
		endif
	endfor
	//if the data set is not in the DSDwave, return empty string
	return ""
end

//*************************************************************************************************
// Lists DSDs, both "real", i.e., present in the data browser, and "virtual", i.e., described in a loaded procedure file but not yet created
// Last Modified 2014/06/17 by Jamie Boyd
Function/S GUIP_DSDList ()
	
	// String to return
	string outStr = ""
	// List real DSDs in the DSDs folder
	DFREF dsdFolder = root:packages:GUIP:DSD:DSDWaves
	if (DataFolderRefStatus(dsdFolder) ==0)
		return  "\\M1( The folder \" root:Packages:GUIP:DSD:DSDWaves\" does not exist."
	endif
	// iterate through the waves in the folder
	string waveNameStr
	variable iW
	for (iW =0; ; iW += 1)
		waveNameStr = GetIndexedObjNameDFR(dsdFolder, 1, iw)
		if (cmpStr (waveNameStr, "") != 0)
			if (stringmatch(waveNameStr,  "*_DSD" ))
				outStr +=  RemoveEnding(waveNameStr, "_DSD") + ";"
			endif
		else // ran out of wave
			break
		endif
	endfor
	// List DSDs described in loaded procedure files	,if they have not already been listed
	string aFuncStr, funcList =  FunctionList ("*_DSDMaker", ";", "" )
	variable iFunc, nFuncs = itemsinList (funcList, ";")
	for (iFunc = 0; iFunc < nFuncs; iFunc += 1)
		aFuncStr = RemoveEnding (stringFromList (iFunc, funcList, ";"), "_DSDMaker")
		if (WhichListItem (aFuncStr, outStr, ";", 0) == -1)
			outStr += aFuncStr + ";"
		endif
	endfor
	return outStr
end	

//******************************************************************************************************
//Lists all the dataTypes that are provided by any packages that want to use DSDs
//Provide a function(takes no inputs and returns a string) that returns your list of datatypes. Name it so that it end with  "_ListDataTypes"
//  Last modified: 2014/06/17 by Jamie Boyd
Function/S GUIP_DSDListDataTypes()
	
	string funcList = FunctionList("*_ListDataTypes*", ";", "VALTYPE:4,NPARAMS:0" )
	variable ii, nFuncs = itemsinlist (funcList)
	string outStr = ""
	for (ii = 0; ii < nFuncs; ii+=1)
		funcref GUIPsProtoFunc listFunc = $stringfromlist (ii, funcList)
		outStr += listFunc () + ";"
	endfor
	return outStr
end

//******************************************************************************************************
// Example plotting function. Assumes all data are in a single folder, with the same base name given by the basePath parameter 
// and that the DSD dataSet names are suffixes on the base name
Function GUIP_DSDplot (DSDStr, GraphName, basePath)
	String DSDStr	// name of the DSD wave
	String graphName // the graph to append to
	String basePath // Path to dataFolder plus base name
	
	// DSD text waves are stored within an Igor experiment in the folder: root:Packages:GUIP:DSD:DSDWaves. 
	Wave/T DSD= $"root:packages:GUIP:DSD:DSDWaves:" + RemoveEnding (DSDStr, "_DSD") + "_DSD"
	variable iDatum, nData = numPnts (DSD), iDSD, nDSD
	string aLine, dsetName, theCommand, aCommandStr
	string traces= TraceNameList(GraphName, ";", 1 )
	string baseTraceName, traceName
	variable iTrace
	// iterate through each line in DSD wave, looking for waves from basePath whose name matches the dataSet name
	// it would also be possible to iterate through waves in a folder, seeing if any line in the DSD wave matched them
	for (iDatum = 0; iDatum < nData; iDatum+=1)
		aLine = DSD [iDatum]
		dsetName = StringFromList (0, aLine, ";")
		WAVE/Z dWave = $basePath + dsetName
		if (!(WaveExists (dWave)))
			continue
		endif
		// append the wave to the graph
		appendtograph/W=$GraphName dWave
		// look for previous conflicting trace names from trace list
		// else we would modify an existing trace
		baseTraceName = NameOfWave(dWave)
		traceName  = baseTraceName
		for (iTrace = 0;WhichListItem(traceName, traces, ";", 0) > -1;iTrace +=1, traceName = baseTraceName + "#" + num2str (iTrace))
		endFor
		// iterate through strings in this line of the DSD, calling modifyGraph command
		//start at 2, because 0 is dataSetName and 1 is DataSet Type, which not used in this function
		// use sprintf to replace %s with trace name
		// if there are 3 %s, as for f(z) modes, the needed wave is in same data folder, named with basePath plus whatever was 
		// entered in the "Wave" field
		for (iDSD =2, nDSD = itemsInList (aLine, ";") ; iDSD <nDSD; iDSD +=1)
			aCommandStr = StringFromList (iDSD, aLine)
			if (StringMatch(aCommandStr, "*%s*%s*%s*"))
				sprintf thecommand, "ModifyGraph/w= %s " + aCommandStr, graphName, traceName, basePath, "" 
				print theCommand
			else
				sprintf thecommand, "ModifyGraph/w= %s " + aCommandStr, graphName ,traceName
			endif
			execute thecommand
		endfor
	endfor	
end

//******************************************************************************************************
// --------------------------------Code for the graphical interface to make and edit DSDs--------------------------------
//******************************************************************************************************
// Makes global variables for the DSD panel
//  Last modified: 2014/06/17 by Jamie Boyd
Static Function MakeGlobals ()
	
	if (!(DataFolderexists ("root:Packages")))
		NewDataFolder root:Packages
	endif
	if (!(DataFolderexists ("root:Packages:GUIP")))
		NewDataFolder root:Packages:GUIP
	endif
	if (!(DataFolderexists ("root:Packages:GUIP:DSD")))
		NewDataFolder root:Packages:GUIP:DSD
		NewDataFolder root:Packages:GUIP:DSD:DSDWaves
		NewDataFolder root:Packages:GUIP:DSD:temp
		string/g root:packages:GUIP:DSD:CurDSDStr = "No DSD Selected"
		variable/g root:Packages:GUIP:DSD:lsize = 1
		variable/g root:packages:GUIP:DSD:marker =0
		variable/g root:packages:GUIP:DSD:msize =1
		variable/g root:packages:GUIP:DSD:mrkThick = 1
		string/g root:packages:GUIP:DSD:mSizezDset = ""
		string/g root:packages:GUIP:DSD:mrkzDset = ""
		string/g root:packages:GUIP:DSD:colorzDset = ""
		variable/g root:packages:GUIP:DSD:zModeFirstColor
		variable/g root:packages:GUIP:DSD:zModeLastColor
		variable/g root:packages:GUIP:DSD:zModeMarkerSizeMin
		variable/g root:packages:GUIP:DSD:zModeMarkerSizeMax
		variable/g root:packages:GUIP:DSD:zModeMarkerSizeMarkerMin
		variable/g root:packages:GUIP:DSD:zModeMarkerSizeMarkerMax
		variable/g root:packages:GUIP:DSD:TxtMrkrXoffset =0
		variable/g root:packages:GUIP:DSD:TxtMrkrYoffset = 0
		string/g root:packages:GUIP:DSD:TextStyleStr = ""
		string/g root:packages:GUIP:DSD:newdsetstr = ""
		string/g root:packages:GUIP:DSD:chartTypeStr
		string/g root:packages:GUIP:DSD:colorIwStr
		Make/n=0 root:Packages:GUIP:DSD:ListSelWave
	endif
end

//******************************************************************************************************
// Makes the panel and global variables in a packages folder
//LastModified 2014/06/18 by jamie Boyd
Function GUIP_DSDStart ()

	DoWindow/F DSDPanel		// brings the DSD panel to the front of the desktop.
	if( V_Flag==1 )			// this flag is created by the dowindows operation. If it is 1, then the window was found O.K.
		return 0				// window was found O.K. so no need to recreate it. Remember that returning a value, any value, exits the function
	endif
	if (!(DataFolderexists ("root:Packages:GUIP:DSD")))
		GUIPDSD#MakeGlobals ()
	endif
	NewPanel/k=1/W=(2,44,322,710) as "DataSet Descriptions"
	DoWindow/C DSDPanel
	Modifypanel fixedSize=1
	// Controls to Select A DSD
	PopupMenu DSDPopup win=DSDPanel,pos={3,11},proc=GUIPDSD#SetDSDPopMenuProc,title="Set DataSet Descriptor:"
	PopupMenu DSDPopup win=DSDPanel,mode=0,value= #"GUIP_DSDList()"
	TitleBox DSDTitle win=DSDPanel,pos={169,15},frame=0
	TitleBox DSDTitle win=DSDPanel,variable= root:packages:GUIP:DSD:CurDSDStr
	// The DSD List Box
	ListBox DSDlistbox win=DSDPanel,pos={4,69},size={314,93},proc=GUIPDSD#DSDListboxProc
	ListBox DSDlistbox win=DSDPanel,selWave=root:packages:GUIP:DSD:ListSelWave,mode= 4
	ListBox DSDlistbox win=DSDPanel,editStyle= 1,widths={800},userColumnResize= 1
	//Buttons for creating and deleting DSDs
	Button NewDSDButton win=DSDPanel,pos={6,41},size={43,22},proc=GUIPDSD#NewDSDButtonProc
	Button RenameDSDButton win=DSDPanel,pos={203,41},size={63,22},proc=GUIPDSD#ReNameDSDProc,title="Rename"
	Button SaveDSDButton win=DSDPanel,pos={103,41},size={43,22},proc=GUIPDSD#SaveDSDButtonProc,title="Save"
	Button LoadDSDButton win=DSDPanel,pos={56,41},size={41,22},proc=GUIPDSD#LoadDSDButtonProc,title="Load"
	Button DeleteDSDButton win=DSDPanel,pos={154,41},size={43,22},proc=GUIPDSD#DeleteDSDButtonProc,title="Kill"
	Button DeleteSelectedButton win=DSDPanel,pos={57,167},size={145,24},proc=GUIPDSD#DeleteSelDsetProc,title="Delete Selected Lines"
	//Dataset and display mode stuff
	GroupBox DsetGrp win=DSDPanel,pos={2,195},size={316,81},frame=0
	//new dataset name setvariable
	SetVariable NewDsetStr win=DSDPanel,pos={6,199},size={221,18},title="DataSet Name:"
	SetVariable NewDsetStr win=DSDPanel,value= root:packages:GUIP:DSD:newdsetstr
	// controls for chart type
	PopupMenu ChartTypepopup win=DSDPanel,pos={6,225},size={91,20},proc=GUIPDSD#DSDChartTypePopMenuProc,title="Data Type"
	PopupMenu ChartTypepopup win=DSDPanel ,mode=0,value= #"GUIP_DSDListDataTypes()"
	SetVariable chartTypeSetVar win=DSDPanel,pos={100,226},size={127,18},title=" "
	SetVariable chartTypeSetVar win=DSDPanel,value= root:packages:GUIP:DSD:chartTypeStr
	//Display mode popup
	PopupMenu DisplayModePopup win=DSDPanel,pos={6,250},size={216,20},title="Display Mode:"
	PopupMenu DisplayModePopup win=DSDPanel,mode=5,popvalue="Lines and Markers",value= #"\"Lines Between Points;Sticks to Zero;Dots;Markers;Lines and Markers;Bars;CityScape;Fill to Zero;Sticks and Markers\""
	//Controls for Line setings
	GroupBox LinesGrp win=DSDPanel,pos={2,277},size={316,59},frame=0
	SetVariable LsizeSetVar win=DSDPanel,pos={6,283},size={134,18},title="Line/Dot Size"
	SetVariable LsizeSetVar win=DSDPanel,limits={0,inf,1},value= root:packages:GUIP:DSD:lsize
	PopupMenu LineStylesPopup win=DSDPanel,pos={6,309},size={210,20},title="Line Style"
	PopupMenu LineStylesPopup win=DSDPanel,mode=1,popvalue="",value= #"\"*LINESTYLEPOP*\""
	CheckBox GapsCheck win=DSDPanel,pos={219,311},size={96,15},title="Gaps at NaNs",value= 1
	//Controls for Markers
	GroupBox MarkerGrp win=DSDPanel,pos={2,335},size={316,99},frame=0
	SetVariable MsizeSetVar win=DSDPanel,pos={6,340},size={130,18},title="Marker Size "
	SetVariable MsizeSetVar win=DSDPanel,limits={0,inf,1},value= root:packages:GUIP:DSD:msize
	CheckBox fZmrkSizeCheck win=DSDPanel,pos={135,341},size={88,15},title="zMarkerSize",value= 0
	SetVariable zMarkerSizeParamSetVar win=DSDPanel,pos={225,339},size={90,18},title="Wave"
	SetVariable zMarkerSizeParamSetVar win=DSDPanel,value= root:packages:GUIP:DSD:mSizezDset
	SetVariable MthicknessSetVar win=DSDPanel,pos={6,365},size={130,18},title="Marker Thick"
	SetVariable MthicknessSetVar win=DSDPanel,limits={0,inf,1},value= root:packages:GUIP:DSD:mrkThick
	PopupMenu MarkerStylesPopup win=DSDPanel,pos={6,389},size={124,20},proc=GUIPDSD#MarkerStylesPopMenuProc,title="Marker Type"
	PopupMenu MarkerStylesPopup win=DSDPanel,mode=20,popvalue="",value= #"\"*MARKERPOP*\""
	CheckBox fZmrkTypeCheck win=DSDPanel,pos={136,392},size={93,15},proc=GUIPDSD#DSDmrkrCheckProc,title="zMarkerType"
	CheckBox fZmrkTypeCheck win=DSDPanel,userdata=  "TxtmrkTypeCheck;",value= 0,mode=1
	SetVariable zMarkerTypeParamSetVar win=DSDPanel,pos={231,398},size={85,18},title="Wave"
	SetVariable zMarkerTypeParamSetVar win=DSDPanel,value= root:packages:GUIP:DSD:mrkzDset
	CheckBox TxtmrkTypeCheck win=DSDPanel,pos={136,408},size={90,15},proc=GUIPDSD#DSDmrkrCheckProc,title="TextMarkers"
	CheckBox TxtmrkTypeCheck win=DSDPanel,userdata=  "fZmrkTypeCheck;",value= 0,mode=1
	CheckBox OpaqueCheck win=DSDPanel,pos={6,413},size={115,15},title="Opaque Symbols",value=0
	//Plot color controls
	GroupBox ColorGrp win=DSDPanel,pos={2,435},size={316,36},frame=0
	PopupMenu PlotColorPopup win=DSDPanel,pos={6,444},size={110,20},title="Plot Color"
	PopupMenu PlotColorPopup win=DSDPanel,mode=1,popColor= (65535,65535,65535),value= #"\"*COLORPOP*\""
	// use zcolor controls
	CheckBox fZcolorCheck win=DSDPanel,pos={121,447},size={55,15},title="zColor",value= 0
	SetVariable zColorParamSetVar win=DSDPanel,pos={179,445},size={137,18},title="Wave"
	SetVariable zColorParamSetVar win=DSDPanel,value= root:packages:GUIP:DSD:colorzDset
	//z mode Tab control
	TabControl zModeTabControl win=DSDPanel,pos={3,477},size={314,157},proc=GUIPTabProc
	TabControl zModeTabControl win=DSDPanel,tabLabel(0)="zColor",tabLabel(1)="zMarkerSize"
	TabControl zModeTabControl win=DSDPanel,tabLabel(2)="TextMarkers",value= 0
	GUIPTabNewTabCtrl ("DSDPanel", "zModeTabControl", TabList="zColor;zMarkerSize;TextMarkers;")
	// zColor tab controls
	// color table controls
	CheckBox zModeColorTableCheck win=DSDPanel,pos={6,504},size={16,14},proc=GUIPRadioButtonProc,title=""
	CheckBox zModeColorTableCheck win=DSDPanel,userdata=  "zColorIWCheck;",value= 1,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor","CheckBox zModeColorTableCheck 0;")
	PopupMenu zModeColorTablePopUp win=DSDPanel,pos={23,501},size={237,20},title="Color Table"
	PopupMenu zModeColorTablePopUp win=DSDPanel,mode=1,bodyWidth= 168,popvalue="",value= #"\"*COLORTABLEPOPNONAMES*\""
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor","PopupMenu zModeColorTablePopUp  0;")
	CheckBox zmodeColorInvertCheck win=DSDPanel,pos={262,504},size={52,15},title="Invert",value= 0
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor","CheckBox zmodeColorInvertCheck 0;")
	//Setting first and last color
	SetVariable zModeColorFirstSetVar win=DSDPanel,pos={30,524},size={196,18},title="First Color at Z="
	SetVariable zModeColorFirstSetVar win=DSDPanel,value= root:packages:GUIP:DSD:zModeFirstColor
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor","SetVariable zModeColorFirstSetVar 0;")
	CheckBox ZmodeColorAutoFirstCheck win=DSDPanel,pos={231,526},size={47,15},title="Auto",value= 1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor","CheckBox ZmodeColorAutoFirstCheck 0;")
	SetVariable zModeColorLastSetVar win=DSDPanel,pos={32,543},size={195,18},title="Last Color at Z="
	SetVariable zModeColorLastSetVar win=DSDPanel,value= root:packages:GUIP:DSD:zModeLastColor
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor","SetVariable zModeColorLastSetVar 0;")
	CheckBox ZmodeColorAutoLastCheck win=DSDPanel,pos={232,545},size={47,15},title="Auto",value= 1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor","CheckBox ZmodeColorAutoLastCheck 	0;")
	//Color Index wave controls
	CheckBox zColorIWCheck win=DSDPanel,pos={5,567},size={16,14},proc=GUIPRadioButtonProc,title=""
	CheckBox zColorIWCheck win=DSDPanel,userdata=  "zModeColorTableCheck;",value= 0,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "CheckBox zColorIWCheck 0;")
	PopupMenu zModeColorIWPopup win=DSDPanel,pos={26,564},size={97,20},proc=GUIPDSD#DSDzColorIWpopMenuProc,title="Index Wave:"
	PopupMenu zModeColorIWPopup win=DSDPanel, mode=0,value= #"DSDListCIMs (\"root:\")"
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "PopupMenu zModeColorIWPopup 0;")
	SetVariable zModeColorIWsetVar win=DSDPanel,pos={125,565},size={177,18},title=" "
	SetVariable zModeColorIWsetVar win=DSDPanel,value= root:packages:GUIP:DSD:colorIwStr
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "SetVariable zModeColorIWsetVar 0;")
	//before first color controls
	CheckBox zModeColorUseBeforeCheck win=DSDPanel,pos={6,591},size={16,14},proc=GUIPRadioButtonProc,title=""
	CheckBox zModeColorUseBeforeCheck win=DSDPanel,userdata=  "zModeColorUseFirstCheck;zModeColorTransFirstCheck;"
	CheckBox zModeColorUseBeforeCheck win=DSDPanel,value= 0,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "CheckBox zModeColorUseBeforeCheck 0;")
	PopupMenu zModeColorBeforePopUp win=DSDPanel,pos={22,588},size={146,20},title="Before First Use"
	PopupMenu zModeColorBeforePopUp win=DSDPanel,mode=1,popColor= (0,0,0),value= #"\"*COLORPOP*\""
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "PopupMenu zModeColorBeforePopUp 0;")
	CheckBox zModeColorUseFirstCheck win=DSDPanel,pos={172,591},size={44,15},proc=GUIPRadioButtonProc,title="First"
	CheckBox zModeColorUseFirstCheck win=DSDPanel,userdata=  "zModeColorUseBeforeCheck;zModeColorTransFirstCheck;"
	CheckBox zModeColorUseFirstCheck win=DSDPanel,value= 0,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "CheckBox zModeColorUseFirstCheck 0;")
	CheckBox zModeColorTransFirstCheck win=DSDPanel,pos={222,591},size={88,15},proc=GUIPRadioButtonProc,title="Transparent"
	CheckBox zModeColorTransFirstCheck win=DSDPanel,userdata=  "zModeColorUseFirstCheck;zModeColorUseBeforeCheck;"
	CheckBox zModeColorTransFirstCheck win=DSDPanel,value= 0,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "CheckBox zModeColorTransFirstCheck 0;")
	//after last color controls
	CheckBox zModeColorUseAfterCheck win=DSDPanel,pos={6,615},size={16,14},proc=GUIPRadioButtonProc,title=""
	CheckBox zModeColorUseAfterCheck win=DSDPanel,userdata=  "zModeColorUseLastCheck;zModeColorTransLastCheck;"
	CheckBox zModeColorUseAfterCheck win=DSDPanel,value= 0,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "CheckBox zModeColorUseAfterCheck 0;")
	PopupMenu zModeColorAfterPopUp win=DSDPanel,pos={22,612},size={146,20},title="After Last Use  "
	PopupMenu zModeColorAfterPopUp win=DSDPanel,mode=1,popColor= (0,0,0),value= #"\"*COLORPOP*\""
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "PopupMenu zModeColorAfterPopUp 0;")
	CheckBox zModeColorUseLastCheck win=DSDPanel,pos={172,615},size={44,15},proc=GUIPRadioButtonProc,title="Last"
	CheckBox zModeColorUseLastCheck win=DSDPanel,userdata=  "zModeColorUseAfterCheck;zModeColorTransLastCheck;"
	CheckBox zModeColorUseLastCheck win=DSDPanel, value= 0,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "CheckBox zModeColorUseLastCheck 0;")
	CheckBox zModeColorTransLastCheck win=DSDPanel,pos={222,615},size={88,15},proc=GUIPRadioButtonProc,title="Transparent"
	CheckBox zModeColorTransLastCheck win=DSDPanel,userdata=  "zModeColorUseLastCheck;zModeColorUseAfterCheck;"
	CheckBox zModeColorTransLastCheck win=DSDPanel,value= 0,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zColor", "CheckBox zModeColorTransLastCheck 0;")
	//zMarkerSize tab controls
	SetVariable zModeMarkerMinSetVar win=DSDPanel, disable=1, pos={27,509},size={165,18},title="z Minimum "
	SetVariable zModeMarkerMinSetVar win=DSDPanel,value= root:packages:GUIP:DSD:zModeMarkerSizeMin
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zMarkerSize", "SetVariable zModeMarkerMinSetVar 0;")
	SetVariable zModeMarkerMaxSetVar win=DSDPanel, disable=1,pos={27,533},size={165,18},title="z Maximum"
	SetVariable zModeMarkerMaxSetVar win=DSDPanel,value= root:packages:GUIP:DSD:zModeMarkerSizeMax
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zMarkerSize", "SetVariable zModeMarkerMaxSetVar 0;")
	CheckBox zModeMarkerMinAutoCheck win=DSDPanel, disable=1,pos={192,509},size={47,15},proc=GUIPRadioButtonProc,title="Auto"
	CheckBox zModeMarkerMinAutoCheck win=DSDPanel,userdata=  "zModeMarkerMinCheck;"
	CheckBox zModeMarkerMinAutoCheck win=DSDPanel,value= 1,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zMarkerSize", "CheckBox zModeMarkerMinAutoCheck 0;")
	CheckBox zModeMarkerMaxAutoCheck win=DSDPanel, disable=1, pos={192,534},size={47,15},proc=GUIPRadioButtonProc,title="Auto"
	CheckBox zModeMarkerMaxAutoCheck win=DSDPanel,userdata=  "zModeMarkerMaxCheck;"
	CheckBox zModeMarkerMaxAutoCheck win=DSDPanel,value= 1,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zMarkerSize", "CheckBox zModeMarkerMaxAutoCheck 0;")
	SetVariable zModeMarkerMinMarkerSetVar win=DSDPanel, disable=1,pos={10,561},size={165,18},title="Marker Minimum"
	SetVariable zModeMarkerMinMarkerSetVar win=DSDPanel,limits={0,inf,1},value= root:packages:GUIP:DSD:zModeMarkerSizeMarkerMin
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zMarkerSize", "SetVariable zModeMarkerMinMarkerSetVar 0;")
	SetVariable zModeMarkerMaxMarkerSetVar win=DSDPanel,disable=1,pos={10,585},size={165,18},title="Marker Maximum"
	SetVariable zModeMarkerMaxMarkerSetVar win=DSDPanel,value= root:packages:GUIP:DSD:zModeMarkerSizeMarkerMax
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zMarkerSize", "SetVariable zModeMarkerMaxMarkerSetVar 0;")
	CheckBox zModeMarkerMinCheck win=DSDPanel,disable=1,pos={9,512},size={16,14},proc=GUIPRadioButtonProc,title=""
	CheckBox zModeMarkerMinCheck win=DSDPanel,userdata=  "zModeMarkerMinAutoCheck;"
	CheckBox zModeMarkerMinCheck win=DSDPanel,value= 0,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zMarkerSize", "CheckBox zModeMarkerMinCheck 0;")
	CheckBox zModeMarkerMaxCheck win=DSDPanel,disable=1,pos={9,537},size={16,14},proc=GUIPRadioButtonProc,title=""
	CheckBox zModeMarkerMaxCheck win=DSDPanel,userdata=  "zModeMarkerMaxAutoCheck;"
	CheckBox zModeMarkerMaxCheck win=DSDPanel,value= 0,mode=1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "zMarkerSize", "CheckBox zModeMarkerMaxCheck 0;")
	//Text mode controls
	PopupMenu txtMrkrFontPopUp win=DSDPanel, disable = 1,pos={11,504},size={100,20},title="Font"
	PopupMenu txtMrkrFontPopUp win=DSDPanel,mode=57,popvalue="Geneva",value= #"fontlist (\";\",1)"
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "TextMarkers", "PopupMenu txtMrkrFontPopUp 0;")
	PopupMenu txtMrkrStylePopup win=DSDPanel,disable=1, pos={11,533},size={53,20},proc=GUIPDSD#txtMrkrStyleProc,title="Style"
	PopupMenu txtMrkrStylePopup win=DSDPanel,mode=0,value= #"GUIPDSD#DSDListTextStyles ()"
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "TextMarkers", "PopupMenu txtMrkrStylePopup 0;")
	SetVariable txtMrkrStyleSetvar win=DSDPanel, disable = 1,pos={68,533},size={213,18},title=" ",frame=0
	SetVariable txtMrkrStyleSetvar win=DSDPanel,value= root:packages:GUIP:DSD:TextStyleStr,noedit= 1
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "TextMarkers", "SetVariable txtMrkrStyleSetvar 0;")
	PopupMenu txtMrkrRotationPopup win=DSDPanel, disable = 1,pos={11,565},size={87,20},title="Rotation"
	PopupMenu txtMrkrRotationPopup win=DSDPanel,mode=3,popvalue="0",value= #"\"180;90;0;-90;\""
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "TextMarkers", "PopupMenu txtMrkrRotationPopup 0;")
	PopupMenu txtMrkrAnchorPopup win=DSDPanel, disable = 1,pos={116,565},size={138,20},title="Anchor"
	PopupMenu txtMrkrAnchorPopup win=DSDPanel,mode=4,popvalue="Middle Top",value= #"\"Left Top;Left Center;Left Bottom;Middle Top;Middle Center;Middle Bottom;Right Top;Right Center;Right Bottom\""
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "TextMarkers", "PopupMenu txtMrkrAnchorPopup 0;")
	SetVariable txtMrkrXOffsetSetVar win=DSDPanel, disable = 1,pos={11,597},size={105,18},title="X Offset"
	SetVariable txtMrkrXOffsetSetVar win=DSDPanel,value= root:packages:GUIP:DSD:TxtMrkrXoffset
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "TextMarkers", "SetVariable txtMrkrXOffsetSetVar 0;")
	SetVariable txtMrkrYOffsetSetVar win=DSDPanel, disable = 1,pos={129,597},size={105,18},title="Y Offset"
	SetVariable txtMrkrYOffsetSetVar win=DSDPanel,value= root:packages:GUIP:DSD:TxtMrkrYoffset
	GUIPTabAddCtrls ("DSDPanel", "zModeTabControl", "TextMarkers", "SetVariable txtMrkrYOffsetSetVar 0;")
	// add dataset button
	Button AddDataSetbutton win=DSDPanel,pos={67,641},size={143,22},proc=GUIPDSD#AddToDSDButtonProc,title="Add/Change DataSet"
	//Open Help Button
	Button ShowHelpButton win=DSDPanel,pos={274,641},size={42,20},proc=GUIPDSD#DSDHelpProc,title="Help"
	// open a DSD,if any
	string aDSD = stringFromList (0, GUIP_DSDList ())
	SVAR CurDSDStr = root:packages:GUIP:DSD:CurDSDStr
	CurDSDStr = aDSD
	STRUCT WMPopupAction pa
	pa.popStr = aDSD
	pa.eventcode=2
	SetDSDPopMenuProc(pa)
end

//******************************************************************************************************
//------------------------------------Code to run controls on the DSD control Panel------------------------------------
//******************************************************************************************************


//******************************************************************************************************
// Changes the contents of the DSDlistbox to match the DSD selected in the popup menu
//LastModified 2014/06/18 by Jamie Boyd
Static Function SetDSDPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			string DSDName = "root:packages:GUIP:DSD:DSDWaves:" + pa.PopStr + "_DSD"
			if (!(WaveExists ($DSDName)))
				FUNCREF GUIPprotofunc DSDMaker=$pa.popStr + "_DSDMaker"
				variable isProto= NumberByKey("ISPROTO",  FuncRefInfo(DSDMaker ),":",";")
				if (!(isProto))
					DSDMaker ()
				endif
			endif
			WAVE/Z/T theDSD = $DSDName
			if (!(WaveExists (theDSD)))
				return 1
			endif
			WAVE/T theDSD = $DSDName
			WAVE /B/U ListSelwave = root:packages:GUIP:DSD:ListSelWave
			Redimension/N= (numpnts (theDSD)) ListSelWave
			ListSelWave = 6
			ListBox DSDlistbox, listwave= theDSD
			SVAR CurDSDStr = root:packages:GUIP:DSD:CurDSDStr
			CurDSDStr = pa.popstr + "_DSD"
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Makes a new DSD, i.e., a text wave, in the root:packages:GUIP:DSD:DSDWaves folder
//LastModified 2014/06/17 by Jamie Boyd
Static Function NewDSDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string newName = "New DSD"
			prompt newName, "New DSD Name:"
			doPrompt/HELP="DataSet Descriptors are text waves stored in the folder \"root:packages:GUIP:DSD:DSDWaves\". This dialog makes a new DSD." "Enter a name for the New DSD",NewName
			if (V_Flag == 1)
				return 1
			endif
			NewName =  CleanupName(NewName, 0 )
			if ((waveExists ($"root:packages:GUIP:DSD:DSDWaves:" + NewName + "_DSD")))
				DoAlert 1, "A DSD named \"" + NewName + "\" already exists. Overwrite it?"
				if (V_flag == 2) //No was clicked
					return 1
				endif
			endif
			make/o/t/n=0 $"root:packages:GUIP:DSD:DSDWaves:" + newname + "_DSD"
			SVAR CurDSDStr = root:packages:GUIP:DSD:CurDSDStr
			CurDSDStr = newname
			STRUCT WMPopupAction pa
			pa.popStr = newName
			pa.eventcode=2
			SetDSDPopMenuProc(pa)
			break
	endswitch
	return 0
End

//******************************************************************************************************
//Loads an igor text wave and puts it in the DSD folder. 
//LastModified 2014/06/18 by Jamie Boyd
Function LoadDSDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string dfldr = getdatafolder (1)
			setdatafolder root:Packages:GUIP:DSD:temp
			LoadWave/T/O ""
			variable iWave
			string aWaveName,proposedNameStr = ""
			for (iWave=0;iWave < V_Flag; iWave +=1)
				aWaveName = stringFromList (iWave, S_waveNames)
					if (CmpStr(aWaveName [strLen (S_waveNames)-5, strLen (aWaveName)-1],"_DSD")==0)
						WAVE theLoadedWave=$aWaveName
						proposedNameStr  = aWaveName
						GUIPDirectoryLoad#GUIPCheckAndMove (S_fileName, theloadedwave, 0, proposednameStr, "root:Packages:GUIP:DSD:DSDWaves:")							
				else
					doalert 0, "The wave \"" + aWaveName +  "\" loaded from \""+ S_fileName + "\" is not a DSD wave."
				endif
			endfor
			KillWaves/A/z
			Killvariables/A/Z
			killStrings/A/z
			setdatafolder dfldr
			//select new DSD as current DSD
			if (CmpStr (proposedNameStr,"") != 0)
				string newName= removeEnding (proposedNameStr, "_DSD")
				SVAR CurDSDStr = root:packages:GUIP:DSD:CurDSDStr
				CurDSDStr = newname
				STRUCT WMPopupAction pa
				pa.popStr = newName
				pa.eventcode=2
				SetDSDPopMenuProc(pa)
			endif
			break
	endswitch
	return 0
End

//******************************************************************************************************
//Deletes the current DSD
//LastModified 2014/06/18 by Jamie Boyd
Static Function DeleteDSDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR CurDSDStr = root:Packages:GUIP:DSD:CurDSDStr
			WAVE/T theDSDwave = $"root:packages:GUIP:DSD:DSDWaves:" + CurDSDStr
			Killwaves theDSDWave
			string aDSD = stringFromList (0, GUIP_DSDList ())
			SVAR CurDSDStr = root:packages:GUIP:DSD:CurDSDStr
			CurDSDStr = aDSD
			STRUCT WMPopupAction pa
			pa.popStr = aDSD
			pa.eventcode=2
			SetDSDPopMenuProc(pa)
	endswitch
	return 0
End

//******************************************************************************************************
//Deletes the currently selected datasets from the DSD
//LastModified 2014/06/18 by Jamie Boyd
Static Function DeleteSelDsetProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR CurDSDStr = root:Packages:GUIP:DSD:CurDSDStr
			WAVE/T theDSDwave = $"root:packages:GUIP:DSD:DSDWaves:" + CurDSDStr
			WAVE /B/U ListSelwave = root:packages:GUIP:DSD:ListSelWave
			variable ii, numlines = numpnts (theDSDWave)
			FOR (ii = 0; ii < numlines; ii += 1)
				if (listselwave [ii] & 1)
					Deletepoints ii, 1, theDSDwave, ListSelWave
					ii -= 1
					numlines -= 1
				endif
			ENDFOR
	endswitch
	return 0
End

//******************************************************************************************************
// Renames the current DSD
Static Function ReNameDSDProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SVAR CurDSDStr = root:Packages:GUIP:DSD:CurDSDStr
			WAVE/T theDSDwave = $"root:packages:GUIP:DSD:DSDWaves:" + CurDSDStr
			String NewProposedNameStr = ""
			prompt NewProposedNameStr, "New DSD Name:"
			doprompt "Rename the current DSD \"" + CurDSDStr + "\":" NewProposedNameStr
			if (V_Flag == 1)
				return 1
			endif
			NewProposedNameStr = cleanupname (NewProposedNameStr, 0)
			if ((cmpstr (Newproposednamestr [strlen (Newproposednamestr) -4, strlen (Newproposednamestr) -1], "_DSD" )) != 0)
				NewProposedNameStr += "_DSD"
			endif
			WAVE/Z checkWave = $"root:Packages:GUIP:DSD:DSDWaves:" + NewProposedNameStr
			if (waveexists (checkWave))
				do
					doprompt "A DSD named \"" + CurDSDStr + "\" already exists. Please Rename" NewProposedNameStr 
					NewProposedNameStr =RemoveEnding (cleanupname (NewProposedNameStr, 0), "_DSD") + "_DSD"
				while ((WaveExists($("root:Packages:GUIP:DSD:DSDWaves:" + NewProposedNameStr))) && (V_Flag == 0))
				if (V_Flag == 0)	// user continued till name did not conflict
					rename thedsdwave $NewProposedNameStr
					CurDSDStr = NewProposedNameStr
				endif
			else		// there was no conflict
				rename thedsdwave $NewProposedNameStr
				CurDSDStr = NewProposedNameStr
			endif
	endswitch
	return 0
End


//******************************************************************************************************
// Saves a DSD to disk, letting the user pick the folder
Static Function SaveDSDButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR CurDSDStr = root:Packages:GUIP:DSD:CurDSDStr
	WAVE theDSDwave = $"root:packages:GUIP:DSD:DSDWaves:" + CurDSDStr
	Save/T theDSDWave as CurDSDStr
End

//******************************************************************************************************
// sets the chart type to the selected value
Static Function DSDChartTypePopMenuProc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	SVAR chartType = root:packages:GUIP:DSD:chartTypeStr
	chartType = popStr
End

//******************************************************************************************************
//for marker mode radio buttons 
Static Function DSDmrkrCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			string ctrlName = cba.ctrlName
			if (cmpstr (ctrlName, "TxtmrkTypeCheck") == 0)
				checkbox fZmrkTypeCheck value = 0
			else
				checkbox TxtmrkTypeCheck value = 0
			endif
			popupmenu MarkerStylesPopup mode = 99 // there is no marker 99, effectively sets it to 0
			break
	endswitch

	return 0
End

//******************************************************************************************************
// Lists color index waves in popup menu  - lists all 3 column 16 bit unsigned waves in the experiment. Not all will be suitable color index waves, obviously
Static function/S DSDListCIMs (sourceFolderStr)
	string sourceFolderStr
	
	string waveNameStr = "", folderStr
	string listStr = ""
	variable nWaves, nFolders
	variable ii
	
	//make sure we have a trailing colon on folder path
	if ((Cmpstr (":", sourceFolderStr [strlen (sourceFolderStr)-1])) != 0)
		sourceFolderStr += ":"
	endif
	//iterate through waves in the folder
	nWaves =  CountObjects(sourceFolderStr, 1) 
	for (ii = 0; ii < nWaves; ii += 1)
		waveNameStr = GetIndexedObjName(sourceFolderStr, 1, ii)
		WAVE aWave = $sourceFolderStr + waveNameStr
		// check wave's info. needs to be 3 columns 16 bit unsigned
		if ((dimsize (aWAVE, 1) == 3) && (waveType (awave)&80))
			listStr += sourceFolderStr + waveNameStr + ";"
		endif
	endfor

	// now we look in all the folders in this folder
	nFolders = CountObjects(sourceFolderStr, 4)
	for (ii = 0; ii < nFolders; ii += 1)
		folderStr = (sourcefolderstr  + (GetIndexedObjName (sourceFolderStr, 4,  ii )))
		liststr += DSDListCIMs (folderStr)
	endfor
	return liststr
end

//******************************************************************************************************
// Set global string to name of chosen color index wave
Static Function DSDzColorIWpopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			String popStr = pa.popStr
			SVAR ColorIWStr = root:packages:GUIP:DSD:colorIwStr
			ColorIWStr = popStr
			break
	endswitch

	return 0
End

//******************************************************************************************************
// for text mode, edits list of styles, maintained in a global string, to apply to displayed text
Static Function txtMrkrStyleProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			SVAR TextStyleStr = root:packages:GUIP:DSD:TextStyleStr
			if ((cmpStr (popStr, "Plain")) == 0) // deselect all
				TextStyleStr = ""
			else
				variable theItem = whichListItem  (popStr, TextStyleStr, ";")
				if (theItem == -1) // not found, so add it
					TextStyleStr += popStr + ";"
				else // found, so remove it
					TextStyleStr = RemoveListItem(theItem, TextStyleStr, ";")
				endif
			endif
			break
	endswitch

	return 0
End

//******************************************************************************************************
// Choosing a marker style deselcts the other 2 mutually exclusive choices, for text marker waves  and zMarker waves
Static Function MarkerStylesPopMenuProc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	CheckBox fZmrkTypeCheck value = 0
	CheckBox TxtmrkTypeCheck value = 0
	
End

//******************************************************************************************************
// Manages the list of text styles, with checks beside selected styles
Static function/S DSDListTextStyles ()

	SVAR SelectedStylesStr = root:packages:GUIP:DSD:TextStyleStr
	string aStyle, AllStylesList = "Plain;\\M1-(;Bold;Italic;Outline;Underline;Shadow;"
	String outStr = "", checkedStr= "\\M0:!" + num2char(18) + ":" // checkmark code
	variable ii, numStyles = itemsinList (AllStylesList, ";")
	for (ii =0; ii < numStyles; ii += 1)
		aStyle = stringFromList (ii, AllStylesList, ";")
		if (whichListItem (aStyle, SelectedStylesStr) > -1) // selected
			outStr += checkedStr 
		endif
		outStr +=  aStyle + ";"
	endfor
	return outStr
end

//******************************************************************************************************
//Shows the help file for the DSD package
Static Function DSDHelpProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			DisplayHelpTopic /K=1 "GUIPDSD"
			break
	endswitch

	return 0
End

//******************************************************************************************************
// adds a new row to the current DSD, with the new dataset name, and the slected plotting options. It reads the appropriate controls, 
// then puts the info, properly formatted, into the new row.
Static Function AddToDSDButtonProc(ctrlName) : ButtonControl
	String ctrlName
	
	//check that DSD exists and make refererences to DSD wave and selection wave
	SVAR CurDSDStr = root:Packages:GUIP:DSD:CurDSDStr
	WAVE/T/Z DSDList=$"root:packages:GUIP:DSD:DSDWaves:" + CurDSDStr
	if (!(waveexists (DSDList)))
		doalert 0, "You have to select a DSD first.\r\r---j.b.---"
		return 1
	endif
	WAVE ListSelWave = root:Packages:GUIP:DSD:ListSelWave
	//make entry for DSD in string theCommand
	//first entry in DSD is dataste name
	SVAR newDsetStr = root:Packages:GUIP:DSD:newdsetstr
	string TheCommand = newDsetStr + ";"
	//2nd entry is chart type
	SVAR chartType = root:packages:GUIP:DSD:chartTypeStr
	TheCommand +=  chartType + ";" 
	//do different things for different display modes 
	//0=Lines Between Points;1=Sticks to Zero;2=Dots;3=Markers;4=Lines and Markers;5=Bars;6=CityScape;7=Fill to Zero;8=Sticks and Markers
	controlinfo DisplayModePopup
	variable mode = V_Value -1
	TheCommand += "mode(%s)=" + num2str (mode) + ";"
	// if mode is not markers, set linesize (works for dot size as well)
	if (!(mode == 3))
		NVAR lsize = root:Packages:GUIP:DSD:lsize
		TheCommand += "lsize(%s)=" + num2str (lsize) + ";"
	endif	
	// Set Line Style and gaps if mode is 0, 4, or 6
	if ((((mode == 0) || (mode == 4)) || (mode ==6)))
		controlinfo LineStylesPopup
		TheCommand += "lstyle(%s)=" + num2str (V_Value-1) + ";"
		controlinfo GapsCheck
		TheCommand += "gaps(%s)=" + num2str (V_value) + ";"
	endif
	// Set markers options if mode is 3, 4, or 8
	if (((mode == 3) || (mode == 4)) || (mode == 8))
		//set marker size
		//check if marker size is controlled by a zWave ModifyGraph zmrkSize(ty)={tz,*,5,0.25,10}
		controlinfo fZmrkSizeCheck
		if (v_Value) // marker size controlled by a zwave
			// find z param name
			SVAR zParamName = root:packages:GUIP:DSD:mSizezDset
			theCommand += "zmrkSize(%s)={%s" + zParamName + "%s,"
			//get min value for zWave
			controlinfo zModeMarkerMinAutoCheck //if checked, use asterisk for auto
			if (V_value)
				theCommand += "*,"
			else //use supplied zMin
				NVAR zMin = root:packages:GUIP:DSD:zmodeMarkerSizeMin
				theCommand += num2str (zMin) + ","
			endif
			//get max value for zWave
			controlinfo zModeMarkerMaxAutoCheck
			if (V_Value) // use asterisk for auto max value
				theCommand += "*,"
			else
				NVAR zMax = root:packages:GUIP:DSD:zmodeMarkerSizeMax
				theCommand += num2str (zMax) + ","
			endif
			// get min and max marker sizes
			NVAR markerMin = root:packages:GUIP:DSD:zModeMarkerSizeMarkerMin
			NVAR markerMax = root:packages:GUIP:DSD:zModeMarkerSizeMarkerMax
			thecommand += num2str (markerMin) + "," + num2str (markerMax) + "};"
		else
			NVAR msize = root:Packages:GUIP:DSD:msize
			TheCommand += "msize(%s)=" + num2str (msize) + ";"
		endif
		// do marker type
		//check to see if using a text wave
		controlinfo TxtmrkTypeCheck
		if (V_Value) //using text wave ModifyGraph textMarker(atestedgy)={:Data:atestedgL,"default",0,0,1,2.00,4.00}
			SVAR zParamName = root:packages:GUIP:DSD:mrkzDset
			theCOmmand += "textMarker(%s)={%s" + zParamName + "%s,"
			// get font
			controlinfo txtMrkrFontPopUp
			theCommand += "\"" + S_Value + "\","
			//get style bitwise bold = 1, italic =2, underline =4, outline =8, shadow =16
			SVAR styleList = root:packages:GUIP:DSD:textStyleStr
			variable styleBIts = 0
			if (whichListItem ("Bold", styleList, ";") > -1)
				stylebits += 1
			endif
			if (whichListItem ("Italic", styleList, ";") > -1)
				stylebits += 2
			endif
			if (whichListItem ("Underline", styleList, ";") > -1)
				stylebits += 4
			endif
			if (whichListItem ("Outline", styleList, ";") > -1)
				stylebits += 8
			endif
			if (whichListItem ("Shadow", styleList, ";") > -1)
				stylebits += 16
			endif
			theCommand += num2str (stylebits) + ","
			//get rotation
			controlinfo txtMrkrRotationPopup
			theCommand += S_Value + ","
			//get anchor
			controlinfo txtMrkrAnchorPopup
			variable anchor = 0
			string position = stringfromList (0, S_Value, " ")
			if (cmpstr (position, "Middle") == 0)
				anchor += 1
			elseif (cmpstr (position, "Right") == 0)
				anchor += 2
			endif
			position = stringfromList (1, S_Value, " ")
			if (cmpstr (position, "Center") == 0)
				anchor += 4
			elseif (cmpstr (position, "Top") == 0)
				anchor += 8
			endif
			theCommand += num2str (anchor) + ","
			//get offsets
			NVAR xOffset = root:packages:GUIP:DSD:txtMrkrXOffset
			NVAR yOffset = root:packages:GUIP:DSD:txtMrkrYOffset
			theCommand += num2str (xOffset) + "," + num2str (yOffset) + "};"
		else
			//check to see if using a zWave	ModifyGraph zmrkNum(ty)={tx}
			controlinfo fZmrkTypeCheck
			if (V_Value)  //using a zWave
				SVAR zParamName = root:packages:GUIP:DSD:mrkzDset
				TheCommand += "zmrkNum(%s)={%s" + zParamName + "%s};"
			else // using a single marker style
				controlinfo MarkerStylesPopup
				TheCommand += "marker(%s)=" + num2str (V_Value-1) + ";"
			endif
			//set marker thickness
			NVAR mrkThick = root:Packages:GUIP:DSD:mrkThick
			TheCommand += "mrkThick(%s)=" + num2str (mrkThick) + ";"
			//set opacity
			controlinfo OpaqueCheck
			TheCommand += "opaque(%s)=" + num2str (V_value) + ";"
		endif
	endif
	// now set color
	// see if we are using a zWave
	controlinfo fZcolorCheck
	if (V_Value) // using a color zwave , either a colortable or colorindex wave 
		SVAR zParamName = root:packages:GUIP:DSD:colorzDset
		theCommand += "zColor(%s)={%s" +zParamName + "%s,"
		// Is it  a color Table?
		controlinfo zModeColorTableCheck 
		if (V_Value) // using a color table  ModifyGraph zColor(ty)={root:Data:tz,*,0,Rainbow,1}  
			//get min value
			controlinfo ZmodeColorAutoFirstCheck
			variable autoFirst = V_Value
			if (V_Value) // use * for auto
				theCommand += "*,"
			else //use min value
				NVAR minzVal = root:packages:GUIP:DSD:zModeFirstColor
				theCommand += num2str (minZVal) + ","
			endif
			//get max value
			controlinfo ZmodeColorAutoLastCheck
			variable autoLast = V_Value
			if (V_Value) // use * for auto
				theCommand += "*,"
			else
				NVAR maxZValue = root:packages:GUIP:DSD:zModeLastColor
				theCommand += num2str (maxZValue) + ","
			endif
			// get color table
			controlinfo zModeColorTablePopUp
			theCommand += S_Value + ","
			//check color table inversion
			controlinfo zmodeColorInvertCheck
			if (V_Value) // color inverted
				theCommand += "1};"
			else
				theCommand += "0};"
			endif
		else // using a color index wave   ModifyGraph zColor(ty) =  {root:Data:tz,*,*,cindexRGB,0,root:packages:zCIW:purple}
			SVAR CIwaveStr = root:packages:GUIP:DSD:colorIwStr
			theCommand +=  "*,*,cindexRGB,0," + CIwaveStr +  "};"// asterisks and 0 are options for subranging or something - not supported by DSD (yet)
		endif
		// get before and after color choices, if not autoscaling
		// check minimum  zColorMin(ty)=(0,0,0)
		if (!(autoFirst))
			// check for use first color, special color, or transparent
			controlInfo zModeColorUseFirstCheck
			if (V_Value) // use first color zColorMin(ty)=0
				theCommand += "zColorMin(%s)=0;"
			else // check for special color
				controlInfo zModeColorUseBeforeCheck
				if (V_Value) //check what special color is selcted
					controlinfo zModeColorBeforePopUp
					TheCommand += "zColorMin(%s)=(" + num2str (V_red) + "," + num2str (V_green) + "," + num2str (V_Blue) + ");"
				else // check for transparent
					controlinfo zModeColorTransFirstCheck
					if (V_Value)
						theCommand += "zColorMin(%s)=NaN;"
					else
						doalert 0,"One of the before color checkboxes needs to be checked."
					endif
				endif
			endif
		endif
		// check maximum  zColorMax(ty)=(0,0,0)
		if (!(autoLast))
			// check for use first color, special color, or transparent
			controlInfo zModeColorUseLastCheck
			if (V_Value) // use first color zColorMin(ty)=0
				theCommand += "zColorMax(%s)=0;"
			else // check for special color
				controlInfo zModeColorUseAfterCheck
				if (V_Value) //check what special color is selcted
					controlinfo zModeColorAfterPopUp
					TheCommand += "zColorMax(%s)=(" + num2str (V_red) + "," + num2str (V_green) + "," + num2str (V_Blue) + ");"
				else // check for transparent
					controlinfo zModeColorTransLastCheck
					if (V_Value)
						theCommand += "zColorMax(%s)=NaN;"
					else
						doalert 0,"One of the after color checkboxes needs to be checked."
					endif
				endif
			endif
		endif
	else // using a single color
		controlinfo PlotColorPopup
		TheCommand += "rgb(%s)=(" + num2str (V_red) + "," + num2str (V_green) + "," + num2str (V_Blue) + ");"
	endif
	variable ii, numels = numpnts (DSDList)
	//Replace line in DSD corresponding to this dataSet with theCommand, or add to end of DSD if not already present
	For (ii =0; (ii < numels) && ((cmpstr (newDsetStr, (stringfromlist (0, DSDlist [ii])))) != 0); ii += 1)
	ENDFOR
	if (ii == numels)
		insertpoints (numels), 1, DSDlist, ListSelWave
		DSDlist [numels] = thecommand
		ListSelWave [numels] = 6
	else
		DSDlist [ii] = thecommand
		ListSelWave [ii] = 6
	endif
End

//******************************************************************************************************
// Copies the settings of the selected DSD dataset to the controls, good for editing existeng DSD's.
// Last Modified 2014/06/23 by jamie boyd
Static Function DSDListboxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
			if (lba.row >= numPnts (lba.listWave))
				return 0
			endif
			// Get description text of selected dataset
			String dSetStr = lba.listWave [lba.row]
			//set dataset name (0th item in desc)
			svar dsetname = root:Packages:GUIP:DSD:newdsetstr
			Dsetname = stringfromlist (0, dSetStr)
			//set chart type (1st item in desc)
			SVAR chartTypeStr = root:packages:GUIP:DSD:ChartTypeStr
			ChartTypeStr = stringfromlist (1, dSetStr) 
			//get plot mode
			variable Plotmode = numberbykey ("mode(%s)", dSetStr, "=", ";")
			popupmenu DisplayModePopup mode = PlotMode + 1
			// if mode is not markers, set line size
			if (!(Plotmode == 3))
				NVAR lsize = root:Packages:GUIP:DSD:lsize
				lsize = numberbykey ("lsize(%s)", dSetStr, "=", ";")
			endif
			// Set Line Style and gaps if mode is 0, 4, or 6
			if ((((PLotmode == 0) || (PLotmode == 4)) || (PLotmode ==6)))
				popupmenu LineStylesPopup mode = (numberbykey ("lstyle(%s)", dSetStr, "=", ";")) + 1
				checkbox GapsCheck, value = numberbykey ("gaps(%s)", dSetStr, "=", ";")
			else
				popupmenu LineStylesPopup mode = 0
				checkbox GapsCheck, value = 0
			endif
			// Set markers if mode is 3, 4, or 8
			if (((Plotmode == 3) || (Plotmode == 4)) || (Plotmode == 8))
				NVAR msizeG = root:Packages:GUIP:DSD:msize
				variable mSize = numberbykey ("msize(%s)", dSetStr, "=", ";")
				string zMrkrStr = stringbyKey ("zmrkSize(%s)", dSetStr, "=", ";")
				if (cmpstr (zMrkrStr, "") != 0) // zmode is  on
					checkbox fZmrkSizeCheck value = 1
					zMrkrStr = zMrkrStr [3, strlen (zMrkrStr) -2] //strips braces and leading %s
					//set zParam string
					SVAR mSizeZdset = root:packages:GUIP:DSD:mSizeZdset
					string theEntry = stringfromlist (0, zMrkrStr, ",")
					mSizeZdset = removeEnding (theEntry, "%s")
					//set min Z, or auto
					theEntry =  stringfromlist (1, zMrkrStr, ",")
					if ((cmpstr (theentry, "*")) ==0)  // auto min
						checkbox zModeMarkerMinAutoCheck value = 1
						checkbox zModeMarkerMinCheck value = 0 
					else //  set min Z
						checkbox zModeMarkerMinAutoCheck value = 0
						checkbox zModeMarkerMinCheck value = 01
						NVAR zModeMarkerSizeMin = root:packages:GUIP:DSD:zModeMarkerSizeMin
						zModeMarkerSizeMin = str2num (theEntry)
					endif
					// set max Z or auto
					theEntry =  stringfromlist (2, zMrkrStr, ",")
					if ((cmpstr (theentry, "*")) ==0)  // auto max
						checkbox zModeMarkerMaxAutoCheck value = 1
						checkbox zModeMarkerMaxCheck value = 0 
					else //  set min Z
						checkbox zModeMarkerMaxAutoCheck value = 0
						checkbox zModeMarkerMaxCheck value = 01
						NVAR zModeMarkerSizeMax = root:packages:GUIP:DSD:zModeMarkerSizeMax
						zModeMarkerSizeMax = str2num (theEntry)
					endif
					// set Marker Min
					theEntry = stringfromlist (3, zMrkrStr, ",")
					NVAR zModeMarkerSizeMarkerMin = root:packages:GUIP:DSD:zModeMarkerSizeMarkerMin
					zModeMarkerSizeMarkerMin = str2num (theEntry)
					// set marker max
					theEntry = stringfromlist (4, zMrkrStr, ",")
					NVAR zModeMarkerSizeMarkerMax = root:packages:GUIP:DSD:zModeMarkerSizeMarkerMax
					zModeMarkerSizeMarkerMax = str2num (theEntry)
				elseif (numtype (mSize) != 2)  //standard marker size
					msizeG = msize
					checkbox fZmrkSizeCheck value = 0
				else
					doalert 0, "Neither zMarker Size info nor marker size was found for this DSD entry."
				endif
				// Marker Types or text Markers
				variable markerType = numberbykey ("marker(%s)", dSetStr, "=", ";")
				string  zMarkerTypeStr = stringbyKey ("zmrkNum(%s)", dSetStr, "=", ";")
				string txtMarkerStr =  stringbyKey ("textMarker(%s)", dSetStr, "=", ";")
				if (cmpstr (txtMarkerStr, "") != 0) // has text marker data textMarker {%s,"Geneva",1,0,1,0,0};
					txtMarkerStr = txtMarkerStr [3, strlen (txtMarkerStr) -2]  //strip braces and leading %s
					// setmarker dset
					SVAR mrkZdset = root:packages:GUIP:DSD:mrkZdset
					mrkZdset = removeEnding (stringfromlist (0, txtMarkerStr, ","),"%s")
					//set font
					theEntry = stringfromlist (1, txtMarkerStr, ",")
					theEntry = theEntry [1, strlen (theEntry) -2]
					//popupmenu txtMrkrFontPopUp mode = whichListItem (theEntry, fontlist (";",1), ";")+1
					popupmenu txtMrkrFontPopUp mode = whichListItem (theEntry, fontlist (";"), ";")+1  // for Igor 5
					// set text style
					variable styleBits = str2num (stringfromlist (2, txtMarkerStr, ",")) // bold = 1, italic =2, underline =4, outline =8, shadow =16
					SVAR TextStyleStr = root:packages:GUIP:DSD:TextStyleStr
					TextStyleStr = ""
					if (styleBits&1)
						TextStyleStr += "Bold;"
					endif
					if (styleBits&2)
						TextStyleStr += "Italic;"
					endif
					if (styleBits&4)
						TextStyleStr += "Underline;"
					endif
					if (styleBits&8)
						TextStyleStr += "Outline;"
					endif
					if (styleBits&16)
						TextStyleStr += "Shadow;"
					endif
					//set rotation   "180;90;0;-90;"
					strSwitch (stringfromlist (3, txtMarkerStr, ","))
						case "180":
							popupmenu txtMrkrRotationPopup  mode = 1
							break
						case "90":
							popupmenu txtMrkrRotationPopup  mode = 2
							break
						case "0":
							popupmenu txtMrkrRotationPopup  mode = 3
							break
						case "-90":
							popupmenu txtMrkrRotationPopup  mode = 4
							break
					endswitch
					// set anchor
					strSwitch (stringfromlist (4, txtMarkerStr, ","))
						case "8":
							popupmenu txtMrkrAnchorPopup mode = 1
							break
						case "4":
							popupmenu txtMrkrAnchorPopup mode = 2
							break
						case "0":
							popupmenu txtMrkrAnchorPopup mode = 3
							break
						case "9":
							popupmenu txtMrkrAnchorPopup mode = 4
							break
						case "5":
							popupmenu txtMrkrAnchorPopup mode = 5
							break
						case "1":
							popupmenu txtMrkrAnchorPopup mode = 6
							break
						case "10":
							popupmenu txtMrkrAnchorPopup mode = 7
							break
						case "6":
							popupmenu txtMrkrAnchorPopup mode = 8
							break
						case "2":
							popupmenu txtMrkrAnchorPopup mode = 9
							break
					endswitch
					//set offsets
					NVAR TxtMrkrXoffset = root:Packages:GUIP:DSD:TxtMrkrXoffset
					NVAR TxtMrkrYoffset = root:Packages:GUIP:DSD:TxtMrkrYoffset
					TxtMrkrXoffset = str2Num (stringfromlist (5, txtMarkerStr, ","))
					TxtMrkrYoffset = str2Num (stringfromlist (6, txtMarkerStr, ","))
					//set checkboxes
					checkbox fZmrkTypeCheck value = 0
					checkbox TxtmrkTypeCheck value = 1
				else
					if (numtype (markerType) != 2)
						popupmenu MarkerStylesPopup mode = markerType + 1
						checkbox fZmrkTypeCheck value = 0
						checkbox TxtmrkTypeCheck value = 0
					elseif (cmpstr (zMarkerTypeStr, "") != 0) // has zMarker type wave  {%sd}
						SVAR mrkZdset = root:packages:GUIP:DSD:mrkZdset
						mrkZdset = zMarkerTypeStr [3, strlen ( zMarkerTypeStr) -2]
						checkbox fZmrkTypeCheck value = 1
						checkbox TxtmrkTypeCheck value = 0
					endif
					NVAR mrkThick = root:Packages:GUIP:DSD:mrkThick
					mrkThick = numberbykey ("mrkThick(%s)", dSetStr, "=", ";")
					checkbox OpaqueCheck value = numberbykey ("opaque(%s)", dSetStr, "=", ";")
				endif
			endif
			// do colors
			string colorstring = stringbykey ("rgb(%s)", dSetStr, "=", ";")
			string  zcolorStr = stringbyKey ("zColor(%s)", dSetStr, "=", ";")
			if (cmpstr (zcolorStr, "") != 0) // has zcolor  ;zColor(%s)={%sz, *, *,Rainbow,0};  or ={%sz,*,*,cindexRGB,0,:packages:zCIW:green} {%sz,0,100,Rainbow,0};zColorMax(%s)=(0,0,65535);
				zcolorStr = zcolorStr [3, strlen (zcolorStr) -2] //strips braces and  leading %s
				// set z param string
				SVAR colorzDset = root:packages:GUIP:DSD:colorzDset
				colorzDset = removeEnding(stringfromlist (0, zcolorStr, ","),"%s")
				checkbox fZcolorCheck value = 1
				// get first color
				if (cmpstr (stringfromlist (1, zcolorStr, ","), "*")  == 0) //autofirst color
					checkbox ZmodeColorAutoFirstCheck value = 1
					checkbox zModeColorUseBeforeCheck value = 0
					checkbox zModeColorUseFirstCheck value = 0
					checkbox zModeColorTransFirstCheck value = 0
				else //set global variable to first z
					NVAR zModeFirstColor = root:packages:GUIP:DSD:zModeFirstColor
					zModeFirstColor = str2num (stringfromlist (1, zcolorStr, ","))
					// not auto first z, so check for zcolor min   zColorMin(%s)=(32792,65535,1)
					checkbox ZmodeColorAutoFirstCheck value = 0
					checkbox zModeColorUseBeforeCheck value = 0
					checkbox zModeColorUseFirstCheck value = 0
					checkbox zModeColorTransFirstCheck value = 0
					string zMinStr = stringbyKey ("zColorMin(%s)", dSetStr, "=", ";")
					if ((cmpstr (zMinStr, "NaN")) == 0) // transparent first
						checkbox zModeColorTransFirstCheck value = 1
					elseif ((cmpstr (zMinStr, "0")) == 0) // use first color
						checkbox zModeColorUseFirstCheck value = 1
					else // using a special first color.
						checkbox zModeColorUseBeforeCheck value = 1
						zMinStr = zMinStr [1, strlen (zMinStr) -2] //strips braces
						popupmenu zModeColorBeforePopUp popColor= (str2num (stringfromlist (0, zMinStr, ",")), str2num (stringfromlist (1, zMinStr, ",")), str2num (stringfromlist (2, zMinStr, ",")))
					endif
				endif
				// get Last color
				if (cmpstr (stringfromlist (2, zcolorStr, ","), "*")  == 0) //auto last  color
					checkbox ZmodeColorAutoLastCheck value = 1
					checkbox zModeColorUseAfterCheck value = 0
					checkbox zModeColorUseLastCheck value = 0 
					checkbox zModeColorTransLastCheck value = 0
				else //set global variable to last z
					NVAR zModeLastColor = root:packages:GUIP:DSD:zModeLastColor
					zModeLastColor = str2num (stringfromlist (2, zcolorStr, ","))
					// not auto last z, so check for zcolor max   zColorMax(%s)=(32792,65535,1)
					checkbox ZmodeColorAutoLastCheck value = 0
					checkbox zModeColorUseAfterCheck  value = 0
					checkbox zModeColorUseLastCheck  value = 0
					string zMaxStr = stringbyKey ("zColorMax(%s)", dSetStr, "=", ";")
					if ((cmpstr (zMaxStr, "NaN")) == 0) // transparent Last
						checkbox zModeColorTransLastCheck value = 1
					elseif ((cmpstr (zMaxStr, "0")) == 0) // use Last color
						checkbox zModeColorUseLastCheck value = 1
					else // using a special Last color.
						zMaxStr = zMaxStr [1, strlen (zMaxStr) -2] //strips braces
						checkbox  zModeColorUseAfterCheck value = 1
						popupmenu zModeColorAfterPopUp popColor= (str2num (stringfromlist (0, zMaxStr, ",")), str2num (stringfromlist (1, zMaxStr, ",")), str2num (stringfromlist (2, zMaxStr, ",")))
					endif
				endif
				// color table or Color Index wave?
				string ColorTableOrIndexWave = stringfromlist (3, zcolorStr, ",")
				if (cmpstr (ColorTableOrIndexWave, "cindexRGB") == 0)
					// get color table
					SVAR colorIWstr = root:packages:GUIP:DSD:colorIwStr
					colorIWstr = ColorTableOrIndexWave
				else
					popupMenu zModeColorTablePopUp mode = 1 + WhichListItem(ColorTableOrIndexWave, CTabList())
					//set invert check
					checkbox zmodeColorInvertCheck value = str2num (stringfromlist (4, zcolorStr, ","))
				endif
			elseif (cmpstr (colorstring, "") != 0) // just using a single color, no z-stuff
				colorstring = colorstring [1, strlen (colorstring) -2]
				popupmenu PlotColorPopup popColor= (str2num (stringfromlist (0, colorstring, ",")), str2num (stringfromlist (1, colorstring, ",")), str2num (stringfromlist (2, colorstring, ",")))
				checkbox fZcolorCheck value = 0
			endif
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			// Apply edited settings
			lba.eventcode=4
			DSDListboxProc(lba)
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break

	endswitch

	return 0
End
