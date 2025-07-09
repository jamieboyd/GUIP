#pragma rtGlobals=1		// Use modern global access method.
#pragma version = 1.0  	// last modified 2014/07/01 by Jamie Boyd
#pragma IgorVersion = 5
#include "GUIPDirectoryLoad", version >=1.1
#include "GUIPList", version >=1.0
#include "GUIPControls"

// Let's put the main function in the Load Waves menu
Menu "Load Waves"
	Submenu "Packages"
	"Load Tiffs", /Q, TSL_Main ()
	end
end

//constants for default Scaling - set these to whatever makes your life easiest
// jb says: remember all my code expects scaling and offset to be in metres, NOT microns or mm
static constant kXscal = 9.00901e-06 // 2x2 binning from xCap
static constant kYscal = 9.00901e-06
static constant kZscal = 1.5e-6
static constant kXoffset = 0
static constant kYoffset =0
static constant kZoffset = 0


//*****************************************************************************************************
// Calls GUIPDirPanel to make the control panel
// last modified 2014/01/09 by Jamie Boyd
Function TSL_Main ()
	
	GUIPDirPanel("TIFFs", ".tif","TSL_LoadATiff", ProcessFunc ="TSL_ProcessATif", extraVertPix =110)
end

//*****************************************************************************************************
// Makes global variables and adds extra controls for scaling and offsets to the control panel
// last modified 2014/10/30 by Jamie Boyd
Function TIFFs_drawControls (vStart)
	variable vStart // vertical start position for controls. Start here and work down
	
	// make some global variables in folder GUIPDirPanel made for us
	variable/G root:packages:GUIP:TIFFs:defaultXOffset = kXoffset
	variable/G root:packages:GUIP:TIFFs:defaultYOffset = kYoffset
	variable/G root:packages:GUIP:TIFFs:defaultZOffset = kZoffset
	variable/G root:packages:GUIP:TIFFs:defaultXScal = kXscal
	variable/G root:packages:GUIP:TIFFs:defaultYScal = kYscal
	variable/G root:packages:GUIP:TIFFs:defaultZScal = kZscal
	SVAR loadOptionStr = root:packages:GUIP:TIFFs:GUIPLoadOptionStr
	loadOptionStr = "3D=Single;"
	SVAR ProcessOptionStr =  root:packages:GUIP:TIFFs:GUIPprocessOptionStr
	ProcessOptionStr = "xScal=" + Num2str (kXscal) + ";xOff=" + Num2Str (kXoffset) + ";xUnit=m;yScal=" + Num2Str (kYscal) + ";"
	ProcessOptionStr += "yOff=" + Num2str (kYoffset) + ";yUnit=m;zScal=" + Num2Str (kZscal) + ";zOff=" + num2Str (kZoffset) + ";zUnit=m;"
	// add the controls
	SetVariable DefaultXScalSetvar win=TIFFsLoader, pos={7,vStart},size={150,16},proc=GUIPSIsetVarProc,title="X Scale"
	SetVariable DefaultXScalSetvar win=TIFFsLoader,help={"Sets the X scaling for loaded image stacks"}
	SetVariable DefaultXScalSetvar win=TIFFsLoader,userdata=  "TSL_SetScal;1e-24;1e24;autoInc;adjustUnits;",fSize=12, format="%.2W1Pm"
	SetVariable DefaultXScalSetvar win=TIFFsLoader,limits={-inf,inf,1e-06},value= root:packages:GUIP:TIFFs:defaultXScal
	GUIPControls#GUIPSIsetVarAdjustIncr ("TIFFsLoader", "DefaultXScalSetvar", kXscal, 1e-8)
	SetVariable DefaultXOffsetSetvar win=TIFFsLoader,pos={165,vStart},size={154,16},proc=GUIPSIsetVarProc,title="X Offset"
	SetVariable DefaultXOffsetSetvar win=TIFFsLoader,help={"Sets the X offset for loaded image stacks"}
	SetVariable DefaultXOffsetSetvar win=TIFFsLoader,userdata=  "TSL_SetScal;-1e24;1e24;;adjustUnits;",fSize=12, format="%.2W1Pm"
	SetVariable DefaultXOffsetSetvar win=TIFFsLoader,limits={-inf,inf,10*kXscal},value= root:packages:GUIP:TIFFs:defaultXOffset
	SetVariable DefaultYScalSetvar win=TIFFsLoader,pos={7,(vStart + 22)},size={150,16},proc=GUIPSIsetVarProc,title="Y Scale"
	SetVariable DefaultYScalSetvar win=TIFFsLoader,help={"Sets the Y scaling for loaded image stacks"}
	SetVariable DefaultYScalSetvar win=TIFFsLoader,userdata=  "TSL_SetScal;1e-24;1e24;autoInc;adjustUnits;",fSize=12,format="%.2W1Pm"
	SetVariable DefaultYScalSetvar win=TIFFsLoader,limits={-inf,inf,1e-06},value= root:packages:GUIP:TIFFs:defaultYScal
	GUIPControls#GUIPSIsetVarAdjustIncr ("TIFFsLoader", "DefaultYScalSetvar", kYScal, 1e-8)
	SetVariable DefaultYOffsetSetvar win=TIFFsLoader,pos={165,vStart + 22},size={153,16},proc=GUIPSIsetVarProc,title="Y Offset"
	SetVariable DefaultYOffsetSetvar win=TIFFsLoader,help={"Sets the Y offset for loaded image stacks"}
	SetVariable DefaultYOffsetSetvar win=TIFFsLoader,userdata=  "TSL_SetScal;-1e24;1e24;;adjustUnits;",fSize=12
	SetVariable DefaultYOffsetSetvar win=TIFFsLoader,format="%.2W1Pm"
	SetVariable DefaultYOffsetSetvar win=TIFFsLoader,limits={-inf,inf,10*kYscal},value= root:packages:GUIP:TIFFs:defaultYOffset
	SetVariable DefaultZScalSetvar win=TIFFsLoader,pos={7, (vStart + 44)},size={150,16},proc=GUIPSIsetVarProc,title="Z Scale"
	SetVariable DefaultZScalSetvar win=TIFFsLoader,help={"Sets the Z scaling for loaded image stacks"}
	SetVariable DefaultZScalSetvar win=TIFFsLoader,userdata=  "TSL_SetScal;1e-24;1e24;autoInc;adjustUnits",fSize=12, format="%.2W1Pm"
	SetVariable DefaultZScalSetvar win=TIFFsLoader,limits={-inf,inf,0.001},value= root:packages:GUIP:TIFFs:defaultZScal
	GUIPControls#GUIPSIsetVarAdjustIncr ("TIFFsLoader", "DefaultZScalSetvar", kZScal,1e-08)
	SetVariable DefaultZOffsetSetvar win=TIFFsLoader,pos={165,(vStart + 44)},size={153,16},proc=GUIPSIsetVarProc,title="Z Offset"
	SetVariable DefaultZOffsetSetvar win=TIFFsLoader,help={"Sets the Z offset for loaded image stacks"}
	SetVariable DefaultZOffsetSetvar win=TIFFsLoader,userdata=  "TSL_SetScal;-1e24;1e24;;adjustUnits;",fSize=12,format="%.2W1Pm"
	SetVariable DefaultZOffsetSetvar win=TIFFsLoader,limits={-inf,inf,10*kZscal},value= root:packages:GUIP:TIFFs:defaultZOffset
	PopupMenu StackModeSetvar win=TIFFsLoader,pos={8,122},size={203,21},proc=TSL_StackModePopMenuProc,title="Load TIff Stacks as"
	PopupMenu StackModeSetvar win=TIFFsLoader,mode=1,popvalue="Single 3D Wave",value= #"\"Single 3D Wave;Series of 2D Waves\"", fSize = 12
	PopupMenu StackModeSetvar win=TIFFsLoader, help = {"Sets option for loading 3D TIFF stacks as single 3D waves, or a series of 2D waves."}
	// disable options setvariables
	SetVariable GUIPLoadOptionsSetvar win=TIFFsLoader, disable=2
	SetVariable GUIPProcessOptionsSetvar win=TIFFsLoader, disable=2
end


//*****************************************************************************************************
// Sets options for loading single 3D wave vs series of 2D waves
// Last Modified 2014/01/09 by Jamie Boyd
Function TSL_StackModePopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SVAR loadOptionStr = root:packages:GUIP:TIFFs:GUIPLoadOptionStr
			loadOptionStr = ReplaceStringByKey("3D", loadOptionStr, StringFromList(0, pa.popStr, " "), "=", ";")
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//*****************************************************************************************************
// changes increment in offset setvariable controls to 10 pixels (xy) or 1 zplane
// and updates options string
// Last Modified 2014/07/01 by Jamie Boyd
Function TSL_SetScal(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	if ((sva.eventCode ==1) || (sva.eventcode == 2)) // mouse up or enter key
		controlinfo/w =$sva.win $sva.ctrlName
		string formatStr, unitStr
		variable inc
		//GUIPControls#GUIPSIsetVarParseRecStr (S_recreation, formatStr, unitStr, inc)
		SVAR optionStr = root:packages:GUIP:TIFFs:GUIPprocessOptionStr
		strSwitch (sva.ctrlname)
			case "DefaultXScalSetvar":
				SetVariable DefaultXOffsetSetvar win=$sva.win, limits={-inf,inf,(10*sva.dval)}
				optionStr = ReplaceStringByKey("xScal", optionStr, num2str (sva.dval), "=", ";")
				optionStr = ReplaceStringByKey("xUnit", optionStr, unitStr, "=", ";")
				setVariable DefaultXOffsetSetvar win=$sva.win, format = formatStr
				break
			case "DefaultYScalSetvar":
				SetVariable DefaultYOffsetSetvar win=$sva.win, limits={-inf,inf,(10*sva.dval)}
				optionStr = ReplaceStringByKey("yScal", optionStr, num2str (sva.dval), "=", ";")
				optionStr = ReplaceStringByKey("yUnit", optionStr, unitStr, "=", ";")
				setVariable DefaultyOffsetSetvar win=$sva.win, format = formatStr
				break
			case "DefaultZScalSetvar":
				SetVariable DefaultZOffsetSetvar win=$sva.win, limits={-inf,inf,(sva.dval)}
				optionStr = ReplaceStringByKey("zScal", optionStr, num2str (sva.dval), "=", ";")
				optionStr = ReplaceStringByKey("zUnit", optionStr, unitStr, "=", ";")
				setVariable DefaultZOffsetSetvar win=$sva.win, format = formatStr
				break
			case "DefaultXOffsetSetvar":
				optionStr = ReplaceStringByKey("xOff", optionStr, num2str (sva.dval), "=", ";")
				optionStr = ReplaceStringByKey("xUnit", optionStr, unitStr, "=", ";")
				setVariable DefaultXScalSetvar win=$sva.win, format = formatStr
				break
			case "DefaultYOffsetSetvar":
				optionStr = ReplaceStringByKey("yOff", optionStr, num2str (sva.dval), "=", ";")
				optionStr = ReplaceStringByKey("yUnit", optionStr, unitStr, "=", ";")
				setVariable DefaultYScalSetvar win=$sva.win, format = formatStr
				break
			case "DefaultZOffsetSetvar":
				optionStr = ReplaceStringByKey("zOff", optionStr, num2str (sva.dval), "=", ";")
				optionStr = ReplaceStringByKey("zUnit", optionStr, unitStr, "=", ";")
				setVariable DefaultZScalSetvar win=$sva.win, format = formatStr
				break
			default:
				doAlert 0, "The TSL_SetScal function was not expecting a control named, \"" + sva.ctrlName + "\"."
		endswitch
		return 1
	endif
	return 0
end


// *****************************************************************************************************
// Loads a tiff Image into an Igor wave, or into multiple Igor Waves
// Last Modified 2014/01/09 by Jamie Boyd
Function TSL_LoadATiff (ImportPathStr, FileNameStr, OptionsStr, FileDescStr)
	String ImportPathStr	// String containing the name of an Igor path to the
						// directory on disk from which to import files.
	String FileNameStr	// String containing the name of the selected file
	String OptionsStr		// if  "3D" == 1, loads a multi-plane tiff into a 3d wave,
						// else makes a separate 2D wave for each plane.
	String FileDescStr	// not used here, but can be used to get name of control panel/path to globals
	
	// get info on file before loadng, to see if it is a stack
	ImageFileInfo/P=$ImportPathStr FileNameStr
	if (V_numimages == 1) // only 1 image
		ImageLoad/P=$ImportPathStr/T=tiff FileNameStr
	else // a Stack of images
		// use StringByKey to get value for 3D option;
		// Default (if 3D keyword not found), is zero, to load multiple waves
		variable do3D =0
		if (cmpStr (StringByKey("3D", OptionsStr, "=", ";"), "Single") ==0)
			do3D = 1
		endif
		if (do3D==0)
			// load stacks as multiple 2D waves
			ImageLoad/P=$ImportPathStr/T=tiff/C=(V_NumImages) FileNameStr
			variable/G :V_flag = V_numImages
		else // load stacks as 3D waves
			ImageLoad/P=$ImportPathStr/T=tiff/C=-1 FileNameStr
		endif
	endif
	// save S_waveNames (set by ImageLoad) as global string in current folder
	String/G :S_waveNames = S_WaveNames	
	// save number of waves loaded in V_flag; set it 1 if making a stack
	if ((do3D) && (V_numImages > 1))
		variable/G :V_flag = 1
	else
		variable/G :V_flag = V_numImages
	endif
	return 0
end


// *****************************************************************************************************
// Applies scaling and offset to a loaded wave
// Last Modified 2014/01/09 by Jamie Boyd
Function TSL_ProcessATif (LoadedWave, ImportPathStr, FileNameStr, optionStr, FileDescStr)
	Wave LoadedWave		// A reference to one of the waves loaded from the selected file
	String ImportPathStr	// String containing the name of an Igor path to the folder on disk
								// from which the file was imported
	String FileNameStr	// String containing the name of the file on disk from where the function was loaded
	String optionStr		// Contains scaling information, if present
	String FileDescStr	// not used here, but can be used to get name of control panel/path to globals

	//set scaling and offset based on key/value pairs in Options String
	// assumes all values are in meters
	variable xScaling = NumberByKey("xScal", optionStr, "=", ";")
	variable xOffset =  NumberByKey("xOff", optionStr, "=", ";")
	string xUnit = StringByKey("xUnit", optionStr, "=", ";")
	variable yScaling = NumberByKey("yScal", optionStr, "=", ";")
	variable yOffset =  NumberByKey("yOff", optionStr, "=", ";")
	string yUnit = StringByKey("yUnit", optionStr, "=", ";")
	variable zScaling = NumberByKey("zScal", optionStr, "=", ";")
	variable zOffset =  NumberByKey("zOff", optionStr, "=", ";")
	string zUnit = StringByKey("zUnit", optionStr, "=", ";")
	// Set Scaling for X and Y
	if (numtype (xScaling) == 0)
		if (numType (xOffset) != 0)
			xOffset =0
		endif
		SetScale/P x (xoffset),(xScaling), xUnit, LoadedWave
	endif
	if (numtype (yScaling) == 0)
		if (numType (yOffset) != 0)
			yOffset = 0
		endif
		SetScale/P y (yoffset),(yScaling),yUnit, LoadedWave
	endif
	// If multiple planes, set Z sclaing
	if ((DimSize(LoadedWave, 2) > 0) && (numtype (zScaling) == 0))
		if (numType (zOffset) != 0)
			zOffset =0
		endif
		SetScale/P z (zoffset),(zScaling),zUnit,LoadedWave
	endif
end
