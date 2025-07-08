#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method.
#pragma IgorVersion=6.1
#pragma version = 1	 // Last Modified: 2025/07/08 by Jamie Boyd
#pragma ModuleName= GUIPControls

#include "GUIPList"
#include "GUIPprotoFuncs"
#include "GUIPMath"

//********************************************************************************************************
//**********************************************GUIPSetVar**************************************************
// GUIPSIsetVarProc is a SetVariable Proc for SI Prefixes with Wavemetrics' %w Conversion Specifier
// The %w formatting specifier prints very large or small numbers in an easily readable manner using an SI prefix such as µ, m, k, M, etc
// It would be nice to use this in a setvariable control, especially if a large range of numbers might be displayed. Unfortunately, the manual says:
// "Never use leading text or the "%W" format for numbers, because Igor reads the value back without interpreting the extra text."
// This procedure provides a work-around for that behaviour

// Igor's usual handling variable minimum and maximum can cause problems when users enter values in the setvariable, so leave them
// as  default values of -INF and +INF.


//		pressing command/ctrl when clicking on the setvariable means multiply the current setvariable increment by 10
//		option/Alt means divide the increment by10 
//		shift-command/ctrl means multiply by 100
// 		shift-option/alt means divide by 100

// To Summarize

// Set formatting string to something like "%.0W1Ps".
// Set setvariable procedure to SIformattedSetVarProc
// 
// If desired, put name of another function to run in the userdata for the setvariable 
// Put Min and Max values for the setvariable in the user data separated by semicolons from each other and the additional procedure


function GUIPSIsetVarEnable (panelName, setVariableName, addFuncStr, MinVal, maxVal, increment, doAutoIncr, MinIncr, nDisplayDigits, unitStr)
	string panelName
	string setVariableName
	string addFuncStr
	variable minVal
	variable maxVal
	variable increment
	variable doAutoIncr
	variable minIncr
	variable nDisplayDigits
	string UnitStr
	
	string formatStr
	sprintf formatStr, "%%.%dW1P%s", nDisplayDigits, unitStr
	SetVariable $setVariableName win=$panelName,limits={-inf,inf,increment}, format=formatStr
	
	controlinfo/W=$panelName $setVariableName
	s_UserData = ReplaceStringByKey("addFuncStr", s_UserData, addFuncStr,":",";")
	s_UserData = ReplaceNumberByKey("ValMin",  s_UserData, MinVal, ":", ";")
	s_UserData = ReplaceNumberByKey("ValMax",  s_UserData, MaxVal, ":", ";")
	s_UserData = ReplaceNumberByKey("AutoIncr", s_UserData, doAutoIncr, ":", ";")
	if (doAutoIncr)
		s_UserData = ReplaceNumberByKey("MinIncr", s_UserData, MinIncr, ":", ";")
	endif
	SetVariable $setVariableName win=$panelName, userdata=s_UserData
end




//*****************************************************************************************************
//  The Setvariable procedure  reads and interprets the SI prefix

Function GUIPSIsetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	if (sva.eventCode ==8 ||sva.eventCode == 1)  // mouse up or finish edit
		// aditonal function
		variable hasFunc =0
		string addFuncStr = StringByKey("addFuncStr", sva.userdata, ":",";")
		if (cmpstr (addFuncStr, "") != 0)
			hasFunc =1
		endif
		// minimum value
		variable valMin = NumberByKey("ValMin", sva.userdata, ":",";")
		if (numtype (ValMin) == 2)
			ValMin = -inf
		endif
		// maximum value
		variable valMax = NumberByKey("ValMax", sva.userdata, ":",";")
		if (numtype (valMax) == 2)
			valMax = -inf
		endif
		// automatically adjust increment or not
		variable autoIncr = 0, minIncr =0
		if (numberByKey ("AutoIncr", sva.userdata, ":",";"))
			autoIncr = 1
		endif
		if (autoIncr)
			minIncr = NumberByKey ("MinIncr", ":", ";")
			if (numtype (minIncr) == 2)
				minIncr = 0
			endif
		endif
		// Parse data from controlinfo for unit string and increment
		variable startPos, endPos
		variable increment
		string unitStr
		variable mult
		controlinfo/w=$sva.win $sva.ctrlName
		startPos = strsearch(S_recreation, "limits={", 0)
		if (startPos > -1)
			endPos = strsearch(S_recreation, "}", startPos + 9)
			sscanf  S_recreation [startPos, endPos], "limits={%*f,%*f,%f}", increment
		else
			increment = 1
		endif
		startPos= strsearch(S_recreation, "format=\"", 0)
		endPos = strsearch(S_recreation, "\"", startPos) + 9
		sscanf (S_Recreation [startPos, endPos]), "format=\"%%%*f%*[W]%*d%*[P]%[^\"]*[\"]",  unitStr
		// parse data from val string to get value and multiplier
		variable controlValue
		string prefList = "yzafpnuμmkMGTPEZY"
		string SIprefixStr, SIprefix=""
		sscanf sva.sval ,"%f%s", controlValue, SIprefixStr
		sscanf SIprefixStr ,"%[yzafpnuμµmkMGTPEZY]" + unitStr, SIprefix
		if (numtype (controlValue) != 0) 
			doalert 0, "trouble"
			return 0
		endif
		//
		if (sva.eventCode  == 8)		// finish edit
			mult = GUIPSISetvarSetMult (SIprefix)
			sva.dVal = controlValue * mult
		elseif (sva.eventCode  == 1)		// click
			//do modifier keys for mouse up
			//		shift = 2
			//		command/ctrl = 8  and means x10
			//		option/Alt = 4 and means /10
			//		shift-command/ctrl = 10 and means *100
			// 		shift-option/alt = 6 and means /100
			if ((sva.eventMod & 8) || (sva.eventMod & 4))// modifiers
				variable HalfWay = sva.ctrlRect.top + (sva.ctrlRect.bottom - sva.ctrlRect.top)/2
				if (sva.mouseLoc.v > HalfWay) // Down  was clicked
					increment *= -1
				endif
				// we've already moved by increment
				sva.dVal -= increment
				if ((sva.eventMod & 10) == 10)  //mult by 100
					sva.dVal += (increment*100)
				elseif ((sva.eventMod & 6) == 6) // divide by 100
					sva.dVal += (increment/100)
				elseif  (sva.eventMod & 8)  //mult by 10
					sva.dVal += (increment*10)
				elseif  (sva.eventMod & 4)// divide by 10
					sva.dVal += (increment/10)
				endif
			endif
			controlValue = sva.dVal/mult
		endif
		// Check  max and min
		if (sva.dVal < ValMin)
			sva.dVal = valMin
		elseif  (sva.dVal > ValMax)
			sva.dVal = valMax
		endif
		// scrunch min values to 0
		if (abs (sva.dVal) < minIncr)
			sva.dVal = 0
		endif
		// write the value back to the global variable/setvariable
		if (cmpStr (sva.vName, "") ==0) // no variable, so must be internal value
			SetVariable $sva.ctrlName win=$sva.win, value=_NUM:sva.dVal
		else
			NVAR gVal = $(S_DataFolder +  S_Value)
			gval = sva.dVal
		endif
		// Adjust increment, if requested
		if (autoIncr)
			GUIPSIsetVarAdjustIncr (sva.win, sva.ctrlName, sva.dVal, minIncr)
		endif
		if (hasFunc)
			string newSvalStr
			Sprintf newSvalStr, "%f %s%s", controlValue, SIprefix, unitStr // update sval before calling additional function
			sva.sval = newSvalStr
			FUNCREF  GUIPProtoFuncSetVariable extraFunc = $addFuncStr //reference to additional function to run, if any
			extraFunc (sva)
		endif
	endif
	return 0
End


function GUIPSISetvarSetMult (SIprefix)
	string SIprefix
	
	variable mult
	if (cmpStr (SIprefix, "") ==0)
		mult = 1
	else
		switch (char2num(SIprefix))
			case 121:  //yokto
				mult = 1e-24
				break
			case 122:  //z zepto
				mult = 1e-21
				break
			case 97: //a  atto
				mult = 1e-19
				break
			case 102:  //f  femto
				mult = 1e-15
				break
			case 112: //p   pico
				mult = 1e-12
				break
			case 110: //n  nano
				mult = 1e-9
				break
			case 181: //µ  micro	greek "mu"
			case 956:	// because this μ is different from this µ
			case 117: // u - easier to type, so we let it pass
				mult = 1e-6
				break
			case 109: // m	milli
				mult = 1e-3
				break
			case 107: //k kilo
				mult = 1e3
				break
			case 77: //M Mega
				mult = 1e6
				break
			case 71: //G Giga
				mult = 1e9
				break
			case 84:  //T Tera
				mult = 1e12
				break
			case 80: //P Peta
				mult = 1e15
				break
			case 69: //E Exa
				mult = 1e18
				break
			case 90: //Z Zeta
				mult = 1e21
				break
			case 89: // Y Yotta
				mult = 1e24
				break
		endSwitch
	endif
	return mult
end

//*****************************************************************************************************
//  Adjusts the increment of the setvariable to 1% of current order of magnitude.
//  You need to set uservalue for min and max with this procedure
static Function GUIPSIsetVarAdjustIncr (windowName, ctrlName, theVal, minIncr)
	string windowName
	string ctrlName
	variable theVal
	variable minIncr

		variable absGval = abs (theVal)

		if (absGval< 10.0001^-24)
			SetVariable $ctrlname win = $windowName, limits={(-INF),(INF), (max (minIncr, 10^-26))}
		elseif (absGval< 10.0001^-23)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-25))}
		elseif (absGval< 10.0001^-22)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^-24))}
		elseif (absGval< 10.0001^-21)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-23))}
		elseif (absGval< 10.0001^-20)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-22))}
		elseif (absGval< 10.0001^-19)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-21))}
		elseif (absGval< 10.0001^-18)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-20))}
		elseif (absGval< 10.0001^-17)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-19))}
		elseif (absGval< 10.0001^-16)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-18))}
		elseif (absGval< 10.0001^-15)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-17))}
		elseif (absGval< 10.0001^-14)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-16))}
		elseif (absGval< 10.0001^-13)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-15))}
		elseif (absGval< 10.0001^-12)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-14))}
		elseif (absGval< 10.0001^-11)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-13))}
		elseif (absGval< 10.0001^-10)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-12))}
		elseif (absGval< 10.0001^-9)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-11))}
		elseif (absGval< 10.0001^-8)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-10))}
		elseif (absGval< 10.0001^-7)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-9))}
		elseif (absGval < 10.0001^-6)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-8))}
		elseif (absGval < 10.0001^-5)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-7))}
		elseif (absGval< 10.0001^-4)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF), (max (minIncr, 10^-6))}
		elseif (absGval< 10.0001^-3)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^-5))}
		elseif (absGval< 10.0001^-2)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^-4))}
		elseif (absGval< 10.0001^-1)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^-3))}
		elseif (absGval< 10.0001^0)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^-2))}
		elseif (absGval< 9.9999^1)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^-1))}
		elseif (absGval< 9.9999^2)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^0))}
		elseif (absGval< 9.9999^3)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^1))}
		elseif (absGval< 9.9999^4)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^2))}
		elseif (absGval< 9.9999^5)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^3))}
		elseif (absGval< 9.9999^6)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^4))}
		elseif (absGval< 9.9999^7)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^5))}
		elseif (absGval< 9.9999^8)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^6))}
		elseif (absGval< 9.9999^9)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^7))}
		elseif (absGval< 9.9999^10)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^8))}
		elseif (absGval< 9.9999^11)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^9))}
		elseif (absGval< 9.9999^12)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^10))}
		elseif (absGval< 9.9999^13)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^11))}
		elseif (absGval< 9.9999^14)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^12))}
		elseif (absGval< 9.9999^15)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^13))}
		elseif (absGval< 9.9999^16)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^14))}
		elseif (absGval< 9.9999^17)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^15))}
		elseif (absGval< 9.9999^18)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^16))}
		elseif (absGval< 9.9999^19)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^17))}
		elseif (absGval< 9.9999^20)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^18))}
		elseif (absGval< 9.9999^21)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^19))}
		elseif (absGval< 9.9999^22)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^20))}
		elseif (absGval< 9.9999^23)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^21))}
		elseif (absGval< 9.9999^24)
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^22))}
		else
			SetVariable $ctrlname win=$windowName, limits={(-INF),(INF),(max (minIncr, 10^23))}
		endif
	end
end

//*****************************************************************************************************
//  Sets user data for name of additional funtion to run when setvariable is activated
// Last modified 2025/07/07 by Jamie Boyd
Function GUIPSISetVarSetFunc (panelName, setVariableName, funcName)
	String PanelName
	String setVariableName
	String funcName
	
	controlinfo/W=$panelName $setVariableName
	s_UserData = ReplaceStringByKey("addFuncStr", s_UserData, funcName,":",";")
	SetVariable $setVariableName win=$panelName, userdata=s_UserData
end

//*****************************************************************************************************
//  Sets user data for minimum value for the setvariable
// Last modified 2015/07/07 by Jamie Boyd
Function GUIPSISetVarSetMin (panelName, setVariableName, minVal)
	String PanelName
	String setVariableName
	variable minVal
	
	controlinfo/W=$panelName $setVariableName
	s_UserData = ReplaceNumberByKey("ValMin", s_UserData, minVal, ":",";")
	SetVariable $setVariableName win=$panelName, userdata=s_UserData
end

//*****************************************************************************************************
//  Sets user data for maximum value for the setvariable
// Last modified 2025/07/07 by Jamie Boyd
Function GUIPSISetVarSetMax (panelName, setVariableName, maxVal)
	String PanelName
	String setVariableName
	variable maxVal
	
	controlinfo/W=$panelName $setVariableName
	s_UserData = ReplaceNumberByKey("ValMax", s_UserData, maxVal, ":",";")
	SetVariable $setVariableName win=$panelName, userdata=s_UserData
end


//*****************************************************************************************************
//  toggles user data for automatically adjusting increment for the setvariable
// Last modified 2025/07/07 by Jamie Boyd
Function GUIPSISetVarSetAutoIncr (panelName, setVariableName, autoIncrOn)
	String PanelName
	String setVariableName
	variable autoIncrOn
	
	controlinfo/W=$panelName $setVariableName
	s_UserData = ReplaceNumberByKey("AutoIncr", s_UserData, autoIncrOn,":",";")
	SetVariable $setVariableName win=$panelName, userdata=s_UserData
end



Function GUIPSISetVarSetMinIncr(panelName, setVariableName, minIncr)
	String PanelName
	String setVariableName
	variable minIncr
	
	controlinfo/W=$panelName $setVariableName
	s_UserData = ReplaceNumberByKey("MinIncr", s_UserData, minIncr,":",";")
	SetVariable $setVariableName win=$panelName, userdata=s_UserData
end
	
//**********************************************GUIPTabControl***********************************************
// The programmer is responsible  for showing the controls for the selected tab, and hiding controls for other tabs.  This can get out of hand quickly if your
// tab controls are complicated. These procedures provide a way to automate the process of hiding and showing controls. They do no other tab-related
// processing, but include the option of calling an extra function to do so.  This tab control procedure puts the database of which controls belong to
// which tabs in a set of waves in a packages folder.
//******************************************************************************************************
// The Tab Control procedure
// Last Modified 2013/04/26 by Jamie Boyd

//******************************************************************************************************
//**********************************************GUIPTab Database Creation *************************************
//******************************************************************************************************
//Makes a new database for a tab control
// last modified 2013/04/25 by Jamie Boyd
Function GUIPTabNewTabCtrl (tabWinStr, tabControlStr, [TabList, UserFunc, curTab])
	string tabWinStr // name of panel window containing the tabcontrol 
	string tabControlStr // name of the tabControl
	string TabList // semicolon separated list of tabs on the tabControl. First item in list must be current tab (if not given, reads it from the tabcontrol)
	string UserFunc // optional user-provided function
	variable curTab // optional number of currently-selected tab on tabcontrol
	
	// make sure packages sub-folder exists for tabcontols (root:packages:GUIP:TCD)
	if (!(dataFolderExists ("root:packages")))
		newDataFolder root:packages
	endif
	if (!(dataFolderExists ("root:packages:GUIP")))
		newDataFolder root:packages:GUIP
	endif
	if (!(datafolderexists ("root:packages:GUIP:TCD")))
		newDataFolder root:packages:GUIP:TCD
	endif
	// make a datafolder for this control panel in the tabControls datafolder
	if (!(dataFolderExists ("root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr))))
		newDataFolder/o $"root:packages:GUIP:TCD:" + tabWinStr
	endif
	// make a datafolder for this tab control in the control panels's data folder
	newDataFolder/o $"root:packages:GUIP:TCD:" +  possiblyquotename (tabWinStr) + ":" + tabControlStr
	string folderPath = "root:packages:GUIP:TCD:" + PossiblyQuoteName (tabWinStr) + ":" + tabControlStr + ":"
	// make global strings in the tab control's folder for the list of tabs, and for the current tab
	// if TabList is defaut, read tablist  and current tab from the controlinfo of the tabControl
	if (ParamIsDefault (TabList))
		controlinfo /W=$tabWinStr $tabControlStr
		if (V_Flag == 0) // the control does not exist, so return 1, for error
			return 1
		endif
		string/g $folderPath + "tabList" = GUIPTabListFromRecStr (S_recreation)
		string/g $folderPath + "currentTab" = S_Value
	else
		string/g $folderPath + "tabList" = TabList
		if (ParamisDefault (curTab))
			curTab =0
		endif
		string/g $folderPath + "currentTab" = stringFromList (curTab, tabList, ";")
	endif
	SVAR tabListG = $folderPath + "tabList" 
	// if provided, make global string for user function
	if (!(ParamIsDefault (UserFunc)))
		string/G $folderPath + "UserUpdateFunc" = UserFunc
	endif
	// for each tab, make textwaves for control names on that tab, and the type of each control
	// plus a numeric wave for the able state of the control when the tab is selected
	variable iTab, nTabs = itemsinlist (TabListG, ";")
	string aTab
	for (iTab=0;iTab < nTabs; iTab +=1)
		aTab = stringFromList (iTab, TabListG, ";")
		make/o/t/n=0 $folderPath + PossiblyQuoteName (aTab) + "_ctrlNames"
		make/o/t/n=0 $folderPath + PossiblyQuoteName (aTab) + "_ctrlTypes"
		make/o/n=0 $folderPath + PossiblyQuoteName (aTab) + "_ctrlAbles"
	endfor
	return 0
end

//******************************************************************************************************
// adds a tab to the tab control database, adds its name to the tablist,  and makes an empty set of waves for it in the database
// last modified 2012/06/30 by Jamie Boyd
Function GUIPTabAddTab (tabWinStr, tabControlStr, tabStr, ModTabControl)
	string tabWinStr	// Name of the controlpanel/graph to modify
	string tabControlStr // name of the tab control to modify
	string tabStr // name of the new tab to add to the control panel
	variable modTabControl // Set bit 0 to add the tab to the tab control, and bit 1 to bring new tab to front
	
	// database for each tabcontrol is stored in a set of waves in a datafolder within the packages folder 
	string folderPath = "root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr) + ":" + tabControlStr + ":"
	SVAR tabList = $folderPath + "tabList"
	if (WhichListItem(tabStr, tabList, ";") > -1) // tab is already there
		return 1
	endif
	// add new tab to end of tab list
	variable nTabs = itemsinList (tabList, ";")
	tabList += tabStr + ";"
	// make waves for this tab
	make/o/t/n=0 $folderPath + PossiblyQuoteName (tabStr) + "_ctrlNames"
	make/o/t/n=0 $folderPath + PossiblyQuoteName (tabStr) + "_ctrlTypes"
	make/o/n=0 $folderPath + PossiblyQuoteName (tabStr) + "_ctrlAbles"
	// if requested, add tab to tab control and bring tab to front
	if (modTabControl & 1)
		TabControl $tabControlStr, win = $tabWinStr, tabLabel (nTabs)= tabStr
		if (modTabControl & 2)
			GUIPTabClick (tabWinStr, tabControlStr, tabStr)
		endif
	endif
	return 0
end

//******************************************************************************************************
//Adds controls to the database for a tab control
// last modified 2015/04/30 by Jamie Boyd
Function GUIPTabAddCtrls (tabWinStr, tabControlStr, tabStr, ctrlList, [applyAbleState])
	string tabWinStr //name of the window or subwindow containing the tabcontrol
	string  tabControlStr //name of the tabControl
	string tabStr // name of the tab to add the controls to
	string ctrlList // list of entries to database in triplet format ControlType controlName ableState;
	variable applyAbleState // if set, apply show/hide to the controls as appropriate
	
	if (paramisDefault (applyAbleState))
		applyAbleState = 0
	endif
	// get path to folder for this tabcontrol and to waves for this tab of the tabcontrol
	// if folder does not exist, exit with an error
	string folderPath = "root:packages:GUIP:TCD:" + PossiblyQuoteName (tabWinStr) + ":" + tabControlStr + ":"
	WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlNames"
	WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlTypes"
	WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlAbles"
	// if waves do not exist, exit
	if (!((waveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles)))
		return 1
	endif
	// if Applyging able state, only hide controls if tabWinStr is NOT showing tab, but always change disable state
	variable isCurrentTab = 0
	if (applyAbleState)
		ControlInfo/W = $tabWinStr $tabControlStr
		if (cmpStr (tabStr, S_Value) ==0)
			isCurrentTab =1
		endif
	endif
	// insert controls into the database
	// keep them sorted alphabetically 
	// check values of control type and able state
	variable returnVal = 0
	variable iControl, nControls = itemsinlist (ctrlList, ";")
	string aControlTriplet, aControl, aCtrlType
	variable insertPos, aCtrlAble
	for (iControl =0; iControl < nControls; iControl +=1)
		aControlTriplet = stringFromList (iControl, ctrlList, ";")
		aCtrlType =  stringFromList (0, aControlTriplet, " ")
		aControl = stringFromList (1, aControlTriplet, " ")
		aCtrlAble = str2num (stringFromList (2, aControlTriplet, " "))
		if (GUIPTabCheckControlType (aCtrlType))
			printf "Control Type for %s was an invalid value, %s.\r", aControl, aCtrlType
			returnVal +=1
			continue
		endif
		if (numtype (aCtrlAble) != 0)
			aCtrlAble = 0
		endif
		insertPos = GUIPMathFindText (ctrlNames, aControl, 0, inf, 0)
		if (insertPos < 0) // control not already added
			insertPos = -(insertPos +1) 
			insertpoints insertPos, 1, ctrlNames, ctrlTypes, ctrlAbles
		endif
		ctrlNames [insertPos] =  aControl
		ctrlTypes [insertPos] = aCtrltype
		ctrlAbles [insertPos] =  ~4 & aCtrlAble
		if (ApplyAbleState)
			if (isCurrentTab==0) // hide controls not on the current tab
				aCtrlAble = 1 | aCtrlable
			endif
			GUIPTabShowHide (aControl, aCtrltype, 4 + aCtrlAble, tabWinStr)
		endif
	endfor
	return returnVal
end

//******************************************************************************************************
//**********************************************GUIPTab Dynamic Stuff******* ********************************
//******************************************************************************************************
//Removes controls from the database for a tab control
// last modified 2014/08/19 by Jamie Boyd
Function GUIPTabRemoveControls (tabWinStr, tabControlStr, tabList, ctrlList, ModTabControl)
	string tabWinStr //name of the window or subwindow containing the tabcontrol
	string  tabControlStr //name of the tabControl
	string tabList // list of the tabs to remove the controls from. Pass "" to remove control from all tabs
	string ctrlList // list of entries of controls to remove from the database
	variable modTabControl // set to 1 to delete control from panel as well
	
	// get path to folder for this tabcontrol and to waves for this tab of the tabcontrol
	string folderPath = "root:packages:GUIP:TCD:" + PossiblyQuoteName (tabWinStr) + ":" + tabControlStr + ":"
	string toDoList
	if (cmpStr (tabList, "") ==0)
		SVAR tabListAll =  $folderPath + "tabList"  
		toDoList = tabListAll
	else
		toDoList = tabList 
	endif
	// Variables to Iterate through controls
	variable iControl, nControls = itemsinlist (ctrlList, ";")
	string aControl
	variable controlPos
	//Variables to iterate through tabList
	variable iTab, nTabs = itemsinList (tabList, ";")
	string tabStr
	for (iTab =0; iTab < nTabs; iTab +=1)
		tabStr = stringFromList (iTab, tabList, ";")
		// reference list of dbase waves for this tab
		WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlNames"
		WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlTypes"
		WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlAbles"
		// if waves do not exist, exit with error
		if (!((waveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles)))
			return 1
		endif
		// remove controls from the database for this  tab
		for (iControl =0; iControl < nControls; iControl +=1)
			aControl = stringFromList (iControl, ctrlList, ";")
			// find control
			controlPos = GUIPMathFindText (ctrlNames, aControl, 0, inf, 0)
			if (controlPos >= 0) // control is in database for this tab
				// first time through, delete control from control panel, if requested
				if ((itab ==0) && (modTabControl))
					if (CmpStr (ctrlTypes [controlPos], "SubWindow") ==0)
						killwindow $tabWinStr#$aControl
					elseif (cmpStr (ctrlTypes [iControl], "TabControl") ==0)
						GUIPTabKillTabControl (tabWinStr, aControl, 1)
					else
						KillControl/W=$tabWinStr  $aControl
					endif
				endif
				deletepoints controlPos, 1, ctrlNames, ctrlTypes, ctrlAbles
			endif
		endfor
	endFor
	return 0
end

//******************************************************************************************************
// sets the  able state for when a control's tab is shown as recorded in the database for a list of controls
//  (0 = enabled and shown, 1 = hidden,  2 = disabled but shown, 3 = hidden and disabled); set bit 2 (add 4)  for subWindow re-enabling
// Last Modified 2015/04/30 by Jamie Boyd
Function GUIPTabSetAbleState (tabWinStr, tabControlStr, tabList, ctrlList, ableState, modTabControl)
	string tabWinStr //name of the window or subwindow of tabcontrol
	string tabControlStr // name of the tabcontrol
	string tabList  // list of tabs for which to change controls state. Pass "" for all tabs
	string ctrlList // list of controls to set ablestate 
	variable ableState
	variable modTabControl
	
	// get path to folder for this tabcontrol
	string folderPath = "root:packages:GUIP:TCD:" + PossiblyQuoteName (tabWinStr) + ":" + tabControlStr + ":"
	// variables to iterate through controls
	variable iControl, nControls = itemsInlist (ctrlList, ";")
	string aControl
	// variables to iterate through list of tabs for this tabcontrol
	if (cmpStr (tabList, "") ==0)
		SVAR tabListG = $folderPath + "tabList"
		tabList= tabListG
	endif
	variable iTab, nTabs = itemsinList (tabList, ";")
	string aTab
	// position of control in list of control
	variable ctrlPos
	string curTab = GUIPTabGetCurrentTab (tabWinStr, tabControlStr), commadStr
	for (iTab =0 ; iTab < nTabs; iTab +=1)
		aTab = stringFromList (iTab, tabList, ";") 
		WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (aTab) + "_ctrlNames"
		WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (aTab) + "_ctrlAbles"
		WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (aTab) + "_ctrlTypes"
		if (!((WaveExists (ctrlNames) && (waveExists (ctrlAbles))) && waveExists (ctrlTypes)))
			printf "Could not find database for tab %s of tabcontrol %s on window %s.", aTab, tabControlStr, tabWinStr
			continue
		endif
		for (iControl =0; iControl < nControls; iControl +=1)
			aControl = stringFromList (iControl, ctrlList, ";")
			ctrlPos = GUIPMathFindText (ctrlNames, aControl, 0, inf, 0)
			if (ctrlPos  >= 0) // control is shown for this tab
				ctrlAbles [ctrlPos] = ableState
				if  (modTabControl)
					if ((ableState & 4) || (cmpStr (aTab, curTab) ==0))
						GUIPTabShowHide (aControl,  ctrlTypes [ctrlPos], ableState, tabWinStr)
					endif
				endif
			endif
		endfor
	endfor
end

//******************************************************************************************************
// Renames a control in the tab control database, and (optionally) renames the control on the control panel
// Last Modified 2015/04/29 by Jamie Boyd
Function GUIPTabRenameControl (tabWinStr, tabControlStr, oldControlName, newControlName, modControl)
	String tabWinStr
	String tabControlStr
	String oldControlName // original control name
	String newControlName // what the control will be renamed to in the dataBase
	Variable modControl // if set, the control will be renamed on the control panel, as well as in the database
	
	// database for each tabcontrol is stored in a set of waves in a datafolder within the packages folder 
	string folderPath = "root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr) + ":" + tabControlStr + ":"
	SVAR/Z tabList = $folderPath + "tabList"
	if (!(SVAR_EXISTS (tabList))) // tab is not there
		return 1
	endif
	// iterate through list of tabs on the tabcontrol
	variable iTab, nTabs = ItemsInList(tabList, ";"), tabPos
	string tabStr, selectedCtrlType
	for (iTab = 0; iTab < nTabs; iTab +=1)
		tabStr = StringFromList(iTab, tabList, ";")
		// waves for this tabControl
		WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlNames"
		WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlTypes"
		WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlAbles"
		// if waves do not exist, exit
		if (!((waveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles)))
			return 1
		endif
		// look for control name on this tab
		tabPos = GUIPMathFindText (ctrlNames, oldControlName, 0, inf, 0)
		// if we found it, rename it, and re-sort the database waves
		if (tabPos >= 0)
			ctrlNames [tabPos] = newControlName
			selectedCtrlType = ctrlTypes [tabPos]
			sort ctrlNames ctrlNames, ctrlTypes, ctrlAbles
		endif
	endfor
	if (modControl)
		string executeStr
		Sprintf executeStr "%s %s win =%s, rename = %s", selectedCtrlType, oldControlName, tabWinStr, newControlName
		Execute executeStr
	endif
	
end

//******************************************************************************************************
// Removes a tab info from a tab control database, and (optionally) modifies the tab control and removes from the panel controls belonging only to the removed tab
// Last Modified 2014/08/19 by Jamie Boyd
Function GUIPTabRemoveTab(tabWinStr, tabControlStr, tabStr, ModTabControl)
	string tabWinStr	// Name of the controlpanel/graph to modify
	string tabControlStr // name of the tab control to modify
	string tabStr // name of the tab to remove from the control panel
	variable modTabControl // Set bit 0=1 to modifiy the tab control to remove the tab. Set bit1=2  to remove controls present only on this tab
	
	// database for each tabcontrol is stored in a set of waves in a datafolder within the packages folder 
	string folderPath = "root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr) + ":" + tabControlStr + ":"
	SVAR/Z tabList = $folderPath + "tabList"
	if ((!(SVAR_EXISTS (tabList))) || (WhichListItem(tabStr, tabList, ";") == -1)) // tab is not there
		return 1
	endif
	// waves for this tabControl
	WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlNames"
	WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlTypes"
	WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlAbles"
	// if waves do not exist, exit
	if (!((waveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles)))
		return 1
	endif
	// get position of tab in database and on the tabCOntrol
	variable iTab, nTabs = itemsinList (tabList, ";")
	variable removeTabPos = WhichListItem(tabStr, tabList, ";")
	if (removeTabPos == -1)
		return 1
	endif
	tabList = RemoveListItem(removeTabPos, tabList, ";")
	nTabs -=1
	SVAR curTab = $folderPath + "currentTab"
	if (ModTabControl & 2)
		// remove controls present on this tab, but not other tabs
		variable iControl, nControls = numPnts (ctrlNames)
		string aControl
		variable otherTabPos
		for (iControl =0 ;iControl < nControls; iControl +=1)
			aControl = ctrlNames [iControl]
			for (iTab =0; iTab < nTabs; iTab +=1)
				wave otherTabControlNames = $folderPath + PossiblyQuoteName (stringFromList (iTab, tabStr)) + "_ctrlNames"
				otherTabPos =  GUIPMathFindText (otherTabControlNames, aControl, 0, inf, 0)
				if (otherTabPos > -1) // control is on another tab
					break
				endif
			endfor
			if (iTab == nTabs) // we checked all other tabs without finding this control, so kill it
				// is control a subWIndow?
				if (cmpStr (ctrlTypes [iControl], "SubWindow") ==0)
					killwindow $tabWinStr#$aControl
				elseif (cmpStr (ctrlTypes [iControl], "TabControl") ==0)
					GUIPTabKillTabControl (tabWinStr, tabControlStr, 1)
				else
					KillControl /W=$tabWinStr $aControl
				endif
			endif
		endfor
	endif
	// remove tab from tabcontrol, moving tab names to fill blank spave and preserve order
	if (ModTabControl)
		for (iTab = removeTabPos; iTab < nTabs; iTab+= 1)
			TabControl $tabControlStr win = $tabWinStr,  tablabel (iTab) = stringfromlist (iTab, tabList, ";")
		endfor
		TabControl $tabControlStr win = $tabWinStr,  tablabel (nTabs) = ""
		// if removed tab was current tab, click on another tab, so a tab is showing
		if (cmpstr (tabStr, curTab) ==0)
			STRUCT WMTabControlAction tc
			tc.win = tabWinStr
			tc.ctrlname = TabControlStr
			tc.eventCode =2
			SVAR curTab = $folderPath + curTab
			if (removeTabPos == 0)
				tabcontrol $tabcontrolStr, win = $tabWinStr, value = 0
				tc.tab = 0
			else
				tabcontrol $tabControlStr, win = $tabWinStr, value = removeTabPos-1
				tc.tab =  removeTabPos-1
			endif
			GUIPTabProc (tc)
		endif
	endif
	// kill waves for this tab
	killwaves/z ctrlNames, ctrlTypes, ctrlAbles
	return 0
end

//******************************************************************************************************
// Simulates a click on a tab, so you can easily adjust tabs from a procedure
// Last Modified 2012/06/30 by Jamie Boyd
Function GUIPTabClick (tabWinStr, tabControlStr, tabStr)
	STRING tabWinStr //name of the window containing the TabControl
	STRING tabControlStr // name of the TabControl 
	STRING tabStr  // Name (not number) of the tab to be selected
	
	// get path to folder for this tabcontrol
	string folderPath = "root:packages:GUIP:TCD:" + PossiblyQuoteName (tabWinStr) + ":" + tabControlStr + ":"
	SVAR tabList = $folderPath + "tabList"
	VARIABLE tabNum = whichlistitem (tabStr, tabList)
	if (TabNum == -1)
		return 1
	endif
	// Set selected tab to theTab
	tabcontrol $tabControlStr win= $tabWinStr, value = tabNum
	// make a WMTabControlAction structure with given values and call GUIPTabProc
	STRUCT WMTabControlAction tca
	tca.win = tabWinStr
	tca.ctrlName = tabControlStr
	tca.tab = tabNum
	tca.eventCode=2
	return GUIPTabProc (tca)
end

//******************************************************************************************************
//****************************************** GUIPTab Sub-Packages  *******************************************
//******************************************************************************************************
// Each procedure file is expected to have an addTab function
// Last Modified 2013/04/26 by Jamie Boyd
Function GUIPTabLoadTab (tabWinStr, tabControlStr, ImportpathStr, InitStr, loadParamStr)
	string tabWinStr 		// name of the control panel containing the tabControl
	string tabControlStr 	// name of the tabControl
	string ImportpathStr 	// name of the IgorPath in which to search (recursivly) for .ipf files to add. If it doesn't exist, User will be asked to create it
	string InitStr 			// Tab procedures are identified as beginning with this string. 
	string loadParamStr	// the parameters that the load function is expecting. Load function must be named for the name of the added tab + "_addTab"
	
	// make sure panel is open
	if ((cmpstr(tabWinStr, WinList (tabWinStr, "", "WIN:65"))) != 0)
		return 1
	endif
	//List of tabs/files already loaded
	string loadedTabs =  GUIPTabGetTabList (tabWinStr, tabControlStr)
	// List of procedure files
	string AllFilesList = GUIPListFiles (ImportpathStr,  ".ipf", InitStr + "*", 13, "")
	// make a list of tabs that have not ben loaded yet, skipping the inital identifying bit
	variable nameStart= strlen (InitStr) -1
	variable iFile, nFiles = itemsinList (AllFilesList, ";")
	string procList = "", aproc
	for (iFile =0;iFile < nFiles;iFile+=1)
		aproc =(stringFromList (iFile, AllFilesList, ";"))[nameStart, INF]
		if (WhichListItem(aProc, loadedTabs, ";") == -1)
			procList = AddListItem(aproc, procList , ";")
		endif
	endfor
	// if nothing left to load, say so and exit
	if (cmpstr (procList, "") == 0)
		doalert 0, "There are no available \"" + ImportpathStr + "\" tab procedures to load."
		return 1
	endif
	//put  up a dialog to choose a tab to add and add it
	string AddTab
	Prompt addTab, "Tab to add:" , popup, procList
	doPrompt "Add a Tab to the\"" + tabControlStr + "\" tab control", addTab
	if (V_Flag) //cancel was clicked on the dialog, so exit
		return 1
	endif
	GUIPTabAddTab (tabWinStr, tabControlStr, addTab, 3)
	//Make sure the tab's procedure file is loaded and execute the Add tab procedure
	Execute/P/Q "INSERTINCLUDE \"" +  InitStr + addTab + "\""
	Execute/P/Q "COMPILEPROCEDURES "
	Execute/P/Q  addTab + "_addTab(" + loadParamStr + ")"
end

//******************************************************************************************************
// Removes a tab from a tabControl and unincludes the file
// Last Modified 2013/04/26 by Jamie Boyd
Function GUIPTabUnLoadTab (tabWinStr, tabControlStr, InitStr, [tab])
	string tabWinStr
	string tabControlStr
	string InitStr
	string tab
	
	//if thePanel window does not exist, exit with error
	if ((cmpstr(tabWinStr, WinList (tabWinStr, "", "WIN:65"))) != 0)
		doAlert 0, "The \"" + tabWinStr + "\" window is not open."
		return 1
	endif
	// if no tab given, put up a dialog to choose a tab to remove
	if (paramisDefault (tab))
		string loadedTabs =  GUIPTabGetTabList (tabWinStr, tabControlStr)
		// if only 1 tab, exit with error
		if (itemsinlist (loadedTabs, ";") == 1)
			doalert 0, "You must have at least one tab on the tab control."
			return 1
		endif
		Prompt tab, "Tab to remove:" , popup, loadedTabs
		doPrompt "Remove a tab from the  \"" + tabControlStr + "\" tabcontrol on the \"" + tabWinStr + "\" window.", tab 
		if (V_Flag) //cancel was clicked on the dialog, so exit
			return 1
		endif
	endif
	// Remove the tab and its controls from the tabcontrol
	GUIPTabRemoveTab (tabWinStr, tabControlStr, tab, 1)
	// Call the procedure's remove function , if it exists, to do extra things like kill globals
	if ((Exists (tab + "_removeTab")) == 6) // then the procedure exists
		funcref GUIPprotofunc RemoveFunc = $tab + "_removeTab"
		removeFunc ()
	endif
	//Add a deleteinclude of the tabs procedure file to the operations que
	Execute/P/Q "DELETEINCLUDE \"" + InitStr + tab + "\""
	Execute/P/Q "COMPILEPROCEDURES "
end

//******************************************************************************************************
//**************************************** GUIPTab MultiRow TabControl ******* ********************************
//******************************************************************************************************
// TabControl Function to simulate a muti-rowed tabcontrol from a group of sibling tabcontrols
// the userdata for all the sibling tabControls points to a global string for the group of tabs, which is  located in the database folder for the panel. 
// The name of the global string need only be unique for other multi-rowed tabs on that control panel. This global string contains a list of the tabs, 
// in the order in which they are arranged from "front" to "back"
// Last Modified 2013/04/26 by Jamie Boyd
Function GUIPTabMultiProc(tca) : TabControl
	STRUCT WMTabControlAction &tca
	
	switch( tca.eventCode )
		case 2: // mouse up
			// show controls for selected tab of this tabcontrol, as normal
			GUIPTabProc (tca)
			// Check if If this tabcontrol is already "in front" of sibling tabcontrols
			string folderPath = "root:packages:GUIP:TCD:" + possiblyquotename (tca.win) + ":"
			SVAR sibTabs = $folderPath  + tca.userdata
			string frontTabCtrl = stringFromList (0, sibTabs)
			string thisTabCtrl = tca.ctrlName
			if (cmpStr (tca.ctrlName, frontTabCtrl) !=0)
				// hide the controls of the selected tab of the front tabControl by calling GUIPTabProc with non-existing tab
				tca.ctrlname = frontTabCtrl
				tca.tab = 99
				GUIPTabProc (tca)
				TabControl $frontTabCtrl win = $tca.win, value=99
				// swap the sizes/postions of the two tabControls
				controlinfo/w = $tca.win $frontTabCtrl
				variable frontTop = V_top
				variable frontHeight = V_Height
				variable frontWidth = V_Width
				variable frontLeft = V_Left
				controlinfo/w = $tca.win $thisTabCtrl
				tabcontrol $thisTabCtrl, win = $tca.win, pos={frontleft,fronttop }, size={frontwidth,frontheight}
				tabcontrol $frontTabCtrl, win = $tca.win, pos={v_left,v_top }, size={v_width,v_height}
				// swap the positions of the two tabsControls in the sibTabs string
				variable thisTabCtrlPos = WhichListItem(thisTabCtrl, sibTabs, ";")
				sibTabs = removeListItem (thisTabCtrlPos, sibTabs, ";")
				sibTabs = AddListItem(frontTabCtrl, sibTabs, ";" , thisTabCtrlPos)
				sibTabs = removeListItem (0, sibTabs, ";")
				sibTabs = AddListItem(thisTabCtrl, sibTabs, ";" , 0)
			endif
			break
	endswitch
	return 0
end

//******************************************************************************************************
// Groups sibling tabs into a multrow tabControl
Function GUIPTabMultiMake (tabWinStr, multiName, sibTabList)
	string tabWinStr
	string multiName
	string sibTabList // list of tabs (in order of appearance)
	
	// save list of sibling tabs in global string
	if (!(dataFolderExists ("root:packages")))
		newDataFolder root:packages:
	endif
	if (!(dataFolderExists ("root:packages:GUIP")))
		newdatafolder root:packages:GUIP
	endif
	if (!(dataFolderExists ("root:packages:GUIP:TCD")))
		newDataFolder root:packages:GUIP:TCD
	endif
	if (!(DataFolderExists ("root:packages:GUIP:TCD:"  + tabWinStr)))
		newDataFOlder $"root:packages:GUIP:TCD:"  + tabWinStr
	endif
	string/G $"root:packages:GUIP:TCD:"  + tabWinStr  + ":" + multiName = sibTabList
	// reposition tabcontrols relative to front tabcontrol, and set userdata and tabProc for all sibling tabs
	string frontTabCtrl = stringFromList (0, sibTabList, ";")
	controlinfo/w = $tabWinStr $frontTabCtrl
	variable frontTop = V_top
	variable frontHeight = V_Height
	variable frontWidth = V_Width
	variable frontLeft = V_Left
	variable iTabCtrl, nTabCtrls = itemsinlist (sibTabList, ";")
	string aTabCtrl
	for (iTabCtrl = 1; iTabCtrl <  nTabCtrls; iTabCtrl += 1)
		aTabCtrl = stringfromlist (iTabCtrl, sibTabList, ";")
		tabcontrol $aTabCtrl win= $tabWinStr , UserData = multiName, proc = GUIPTabMultiProc
		tabcontrol $aTabCtrl  win= $tabWinStr, pos={frontleft,fronttop-(iTabCtrl * 20)}, size={frontwidth,18}, value=99
	endfor
	tabcontrol $frontTabCtrl win= $tabWinStr, UserData = multiName, proc = GUIPTabMultiProc
end


//******************************************************************************************************
//*******************************GUIPTab User Interface for DataBase *********************************************
//******************************************************************************************************
// Menu item in the "Misc" menu
Menu "Misc"
	SubMenu "Packages"
		"Manage GUIP TabControls",  GUIPControls#GUIPTabManage()
	end
end

//******************************************************************************************************
//Makes a control panel to help manage tab controls
// Last modified 2015/05/29 by Jamie Boyd
Static Function GUIPTabManage()

	// make sure packages folder and global variables exist
	if (!DatafolderExists ("root:packages"))
		newdatafolder root:packages
	endif
	if (!DatafolderExists ("root:packages:GUIP"))
		newdatafolder root:packages:GUIP
	endif
	if (!DatafolderExists ("root:packages:GUIP:TCU"))
		newdatafolder root:packages:GUIP:TCU
		// Wave for list of controls on the selected panel
		make/t/n= (1,3) root:packages:GUIP:TCU:control_list
		make/n= (1,3) root:packages:GUIP:TCU:controlSel_list
		WAVE Control_List = root:packages:GUIP:TCU:control_list
		SetDimLabel 1,0,Name,control_list
		SetDimLabel 1,1,Type,control_list
		SetDimLabel 1,2,Assigned_To,control_list
		//waves for the list of tabs on the selected tabControl
		make/o/t/n= (1,2)  root:packages:GUIP:TCU:Tab_list
		make/o/n = (1,2) root:packages:GUIP:TCU:tab_listSelWave
		WAVE/T tab_List =  root:packages:GUIP:TCU:Tab_list
		SetDimLabel 1,0, tab, tab_list
		SetDimLabel 1,1, ableState, tab_list
		tab_List = ""
		// wave for the database list
		make/o/T/n = 0 root:packages:GUIP:TCU:DataBase
		make/o/n = 0 root:packages:GUIP:TCU:DataBaseSel
		// wave for the list of tabcontrols to make multirow tabcontrol
		make/o/T/n = (1, 2) root:packages:GUIP:TCU:TabControlList
		WAVE TabControlList = root:packages:GUIP:TCU:TabControlList
		SetDimLabel 1,0,TabControl,TabControlList
		SetDimLabel 1,1,Row,TabControlList
		//strings for the title boxes
		String/G root:packages:GUIP:TCU:thePanel
		String/G root:packages:GUIP:TCU:theTabControl
		// string to hold nam eof control that is about to be edited
		String/G root:packages:GUIP:TCU:tempEditStr
		// variable for how controls are currently sorted
		variable/G root:packages:GUIP:TCU:CntrlSortCol = 0
	endif
	// Try to Bring Panel to front - exit if panel already exists
	DoWindow/F GUIPTab_Manager
	if (V_Flag == 1)
		return -1
	endif
	// Make the panel
	NewPanel /K=1 /W=(0,44,1009,322) as "GUIP TabControl Manager"
	dowindow/C GUIPTab_Manager
	ModifyPanel fixedSize=1
	//Choose a panel
	GroupBox PanelGrp win=GUIPTab_Manager,pos={1,0},size={311,275},title="Panel",fSize=9,frame=0
	ListBox controlList win=GUIPTab_Manager,pos={5,22},size={302,222},proc= GUIPControls#TabManControlListProc
	ListBox controlList win=GUIPTab_Manager,help={"Lists all the controls on the selected control panel, and the tabControls to which they are currently assigned."}
	ListBox controlList win=GUIPTab_Manager,listWave=root:packages:GUIP:TCU:control_list
	ListBox controlList win=GUIPTab_Manager,selWave=root:packages:GUIP:TCU:controlSel_list,mode= 4
	ListBox controlList win=GUIPTab_Manager,widths={120,80,105}
	PopupMenu PanelPopup win=GUIPTab_Manager,pos={5,250},size={105,20},proc=GUIPControls#TabManPanelPopUpProc,title="Choose Panel"
	PopupMenu PanelPopup win=GUIPTab_Manager,help={"Select a control panel whose tabControls you wish to manage."}
	PopupMenu PanelPopup win=GUIPTab_Manager,fSize=12, mode=0,value= #"WinList(\"*\", \";\", \"WIN:64\")"
	PopupMenu PrintCommandsPopup win=GUIPTab_Manager,pos={155,250},size={127,20},proc=GUIPControls#TabManPrintCommands,title="Print Commands:"
	PopupMenu PrintCommandsPopup win=GUIPTab_Manager,help={"Prints the commands for all the controls on the panel, nicely sorted with tab controls drawn first."}
	PopupMenu PrintCommandsPopup win=GUIPTab_Manager,mode=0,value= #"\"ClipBoard;History Window;\" + WinList(\"*\", \";\", \"WIN:16\" )"
	// Assign controls to TabControls
	GroupBox AddtoDBaseGrp win=GUIPTab_Manager,pos={311,0},size={191,274},title="Control"
	GroupBox AddtoDBaseGrp win=GUIPTab_Manager,fSize=9,frame=0
	PopupMenu TabControlPopup win=GUIPTab_Manager,pos={318,28},size={82,20},proc=GUIPControls#TabManTabControlPopUpProc,title="TabControl"
	PopupMenu TabControlPopup win=GUIPTab_Manager,help={"Shows which tabControl the selected control is assigned to, and allows you to assign it to a new tabControl."}
	PopupMenu TabControlPopup win=GUIPTab_Manager,fSize=12
	PopupMenu TabControlPopup win=GUIPTab_Manager,mode=0,value= #"GUIPControls#TabManListTabControls()"
	TitleBox TabControlTitle win=GUIPTab_Manager,pos={414,31},size={50,16}, fSize=12, frame=0
	TitleBox TabControlTitle win=GUIPTab_Manager,variable= root:packages:GUIP:TCU:theTabControl
	Button NewTabButton win=GUIPTab_Manager,pos={355,60},size={93,20},proc=GUIPControls#TabManNewTabProc,title="Add New Tab"
	Button NewTabButton win=GUIPTab_Manager,help={"Adds a new tab to the selected tab control, with a name of your chosing."}
	ListBox TabList win=GUIPTab_Manager,pos={316,84},size={184,142}, mode=0
	ListBox TabList win=GUIPTab_Manager,help={"Shows names of all tabs on the seletced tabControl.Sets visibity for selected controls for each tab on the TabControl."}
	ListBox TabList win=GUIPTab_Manager,listWave=root:packages:GUIP:TCU:Tab_list
	ListBox TabList win=GUIPTab_Manager,selWave=root:packages:GUIP:TCU:tab_listSelWave, proc=GUIPControls#TabManTabsListBoxProc
	Button ApplyTabSettingsButton  win=GUIPTab_Manager, pos={344,231},size={114,20},proc=GUIPControls#TabApplySettingsButtonProc,title="Apply Settings"
	// Show dataBase for selected tabControl
	GroupBox DataBaseGrp win=GUIPTab_Manager, pos={504,0},size={311,275},title="Database"
	GroupBox DataBaseGrp win=GUIPTab_Manager,fSize=9,frame=0
	ListBox DBaseList win=GUIPTab_Manager,pos={508,21},size={300,226}
	ListBox DBaseList win=GUIPTab_Manager,listWave=root:packages:GUIP:TCU:DataBase,widths={116,164}
	ListBox DBaseList win=GUIPTab_Manager,selWave=root:packages:GUIP:TCU:DataBaseSel, mode =0
	ListBox DBaseList win=GUIPTab_Manager,userColumnResize= 1, proc = GUIPControls#TabManDBListBoxProc
	PopupMenu PrintDBasePopup win=GUIPTab_Manager,pos={524,251},size={115,20},proc=GUIPControls#ManPrintDBaseProc,title="Print DataBase:"
	PopupMenu PrintDBasePopup win=GUIPTab_Manager,help={"Prints the database for the selected tabControl as Igor commands that will run in a procedure or from command line."}
	PopupMenu PrintDBasePopup win=GUIPTab_Manager,mode=0,value= #"\"ClipBoard;History Window;\" + WinList(\"*\", \";\", \"WIN:16\" )"
	Button ClearDataBaseButton win=GUIPTab_Manager,pos={658,251},size={102,20},proc=GUIPControls#TabManClearDataBaseProc,title="Clear DataBase"
	Button ClearDataBaseButton win=GUIPTab_Manager,help={"Clears the database for the selected tabControl."}
	//MultiRow tabControl
	GroupBox MultiRowGrp win=GUIPTab_Manager,pos={814,0},size={191,275},title="MultiRow TabControl Centre"
	GroupBox MultiRowGrp win=GUIPTab_Manager,fSize=9,frame=0
	ListBox TabControlList win=GUIPTab_Manager,pos={819,21},size={182,205},proc=GUIPControls#TabManMultiListBoxProc
	ListBox TabControlList win=GUIPTab_Manager,help={"Shows names of all tabs on the seletced tabControl. Check tabs you want control to belong to, and Assign Control to TabControl."}
	ListBox TabControlList win=GUIPTab_Manager,listWave=root:packages:GUIP:TCU:TabControlList
	ListBox TabControlList win=GUIPTab_Manager,widths={130,64},userColumnResize= 1, mode = 1
	Button MakeMultiRowButton win=GUIPTab_Manager,pos={843,235},size={107,21},proc=GUIPControlsTabManMakeMultiRow,title="Make MultiRow"
	Button MakeMultiRowButton win=GUIPTab_Manager,fSize=12
end

//******************************************************************************************************
// Runs when a new panel is chosen from the popupmenu. Sets global string and updates control list
// Last modified 2015/04/29 by Jamie Boyd
Static Function TabManPanelPopUpProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			//set global string and panel group name to chosen panel
			SVAR  thePanel = root:packages:GUIP:TCU:thePanel
			thePanel = pa.popstr
			groupbox PanelGrp, win = GUIPTab_Manager, title = thePanel
			// Zero waves for list of tabs
			wave/T tabListWave = root:packages:GUIP:TCU:Tab_list
			Wave tabSelListWave = root:packages:GUIP:TCU:tab_listSelWave
			redimension/n = (1,2) tabListWave, tabSelListWave
			tabListWave = ""
			tabSelListWave = 0
			//Set info for add to datbase group to default values
			GroupBox AddtoDBaseGrp, win = GUIPTab_Manager,  title="Choose a Control"
			// Zero out the database waves
			make/o/T/n = (1,1) root:packages:GUIP:TCU:DataBase
			make/o/n = (1,1) root:packages:GUIP:TCU:DataBaseSel
			//Make a list of controls on the panel, initially sorted by name, plus all sub-windows (which we will treat as controls)
			NVAR CntrlSortCol = root:packages:GUIP:TCU:CntrlSortCol
			CntrlSortCol =0
			string aControl, AllControls = SortList (ControlNameList(pa.popstr) + ChildWindowList (pa.popStr), ";",4)
			//Update the listbox of controls fromt he list of controls, getting name and type of control. At the same time, make a separate list of tabControls
			string TabControlList = ""
			variable iControl, nControls = itemsinlist (AllControls), ctrltype
			WAVE/T control_list =  root:packages:GUIP:TCU:control_list
			WAVE controlSel_list = root:packages:GUIP:TCU:controlSel_list
			redimension/N = (max(1, nControls), 3) control_List, controlSel_list
			if (nControls ==0)
				control_list [0] [] = ""
			endif
			control_List [] [2] = "not assigned"
			controlSel_list [*] [0] = 6
			controlSel_list [*] [1,2] = 0
			for (iControl = 0; iControl < nControls; iControl += 1)
				aControl = stringfromlist (iControl, AllControls)
				control_List [iControl] [0]= acontrol
				controlinfo /W=$pa.popStr $aControl
				ctrltype = abs (V_FLag)
				switch (ctrltype)
					case 0:
						control_List [iControl] [1] = "SubWindow" // treated as a control for our purposes
						break
					case 1:
						control_List [iControl] [1] = "Button"
						break
					case 2:
						control_List [iControl] [1] = "CheckBox"
						break
					case 3:
						control_List [iControl] [1] = "PopupMenu"
						break
					case 4:
						control_List [iControl] [1] = "ValDisplay"
						break
					case 5:
						control_List [iControl] [1] = "SetVariable"
						break
					case 6:
						control_List [iControl] [1] = "Chart"
						break
					case 7:
						control_List [iControl] [1] = "Slider"
						break
					case 8:
						control_List [iControl] [1] = "TabControl"
						TabControlList += aControl + ";"
						break
					case 9:
						control_List [iControl] [1] = "GroupBox"
						break
					case 10:
						control_List [iControl] [1] = "TitleBox"
						break
					case 11:
						control_List [iControl] [1] = "ListBox"
						break
					default:
						print "The control type, " + num2str ( ctrlType) + ", is unknown to me."
						control_List [iControl] [1] = ""
				endswitch
			endfor
			// Do we have GUIPTabDatabase for tabControls on this panel?
			string dbTabCtrlList= GUIPTabGetTabControlList (pa.popStr), dbCtrlList
			string aTabControl, tabList
			variable  nDBcontrols, ctrlPos
			// Update list of tabControls in Multi-Row tabControl Wave, and start dbase for any tabControls lacking it
			variable iTabControl, nTabControls =itemsinList (TabControlList, ";")
			WAVE/T tabControlListWave = root:packages:GUIP:TCU:TabControlList
			redimension/n = (max (1, nTabControls), 2) tabControlListWave
			if (nTabControls ==0)
				tabControlListWave [0] [] = ""
			endif
			tabControlListWave [] [1] = ""
			for (iTabControl=0; iTabControl < nTabControls; iTabControl += 1)
				aTabControl =  stringfromlist (iTabControl, TabControlList)
				tabControlListWave [iTabControl] [0] =aTabControl
				if (WhichListItem(aTabControl, dbTabCtrlList, ";") ==-1) // no database present
					ControlInfo /W=$pa.popStr aTabControl
					tabList =GUIPTabListFromRecStr (S_recreation)
					GUIPTabNewTabCtrl (pa.popStr, aTabControl, tabList = tabList)
				else  // database present -  set assigned_to for controls in database for this tabControl
					dbCtrlList = GUIPTabGetControlList (pa.popStr, aTabControl)
					for (iControl =0, nDBcontrols = itemsInList (dbCtrlList, ";"); iControl < nDBcontrols; iControl +=1)
						aControl = stringFromList (iControl, dbCtrlList, ";")
						ctrlPos = GUIPMathFindText (control_list, aControl, 0, nControls-1, 0)
						if (ctrlPos >= 0)
							control_list [ctrlPos] [2] = aTabControl
						else
							printf "The database for tabControl %s contains a control, %s, that was not found on the control panel %s.\r", aTabControl, aControl, pa.popStr
						endif
					endfor
				endif
			endfor
	endswitch
	return 0
End

//******************************************************************************************************
// when a control is selected, show the tab control (if any) that it is assigned to.
// Last Modified 2015/04/20 by Jamie Boyd
Static Function TabManControlListProc (lba) : ListBoxControl
	STRUCT WMListboxAction &lba
	
	//reference global waves for tab list
	SVAR thePanel = root:packages:GUIP:TCU:thePanel
	SVAR theTabControl = root:packages:GUIP:TCU:theTabControl
	lba.row = min (dimsize (lba.selwave, 0) -1, lba.row)
	switch (lba.eventCode)
		case -1: // control being killed
			break
		case 3: // double click
			if (lba.row ==-1)
				SortTextByColumn (lba.listWave, lba.col)
				lba.selwave =0
			endif
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			// check to see if multiple selections
			variable iControl, nControls = dimsize (lba.listWave, 0), nSelected=0
			for (iControl =0;iControl < nControls; iControl += 1)
				if ((lba.selWave [iControl] [0]) & 1)
					nSelected  += 1
					if (nSelected > 1)
						break
					endif
				endif
			endfor
			if (nSelected > 1) // multiple controls selected
				// retitle group box
				GroupBox AddtoDBaseGrp, win = GUIPTab_Manager,  title="Multiple Controls Selected"
			else // single control selected
				//get info on chosen control
				string theControl =  lba.listWave [lba.row] [0]
				string AssignedTo = lba.listWave [lba.row] [2]
				//Set "assign to" title box to assigned tab control
				// retitle group box with selected control name
				if (cmpstr (AssignedTo, "not assigned") == 0)
					GroupBox AddtoDBaseGrp, win = GUIPTab_Manager,  title=  theControl + " not Assigned"
				else
					GroupBox AddtoDBaseGrp, win = GUIPTab_Manager,  title=  " Tab Assignment for " + theControl
					string aTab, tabs = GUIPTabGetTabList (thePanel, AssignedTo)
					// call popup menu procedure with selcted tabControl
					STRUCT WMPopupAction pa
					pa.eventCode = 2
					pa.win="GUIPTab_Manager"
					pa.popStr = assignedTo
					pa.ctrlName = "TabControlPopup"
					TabManTabControlPopUpProc(pa)
				endif
			endif
			break
		case 6: // begin edit - save name of control about to be edited
			SVAR tempEditStr = root:packages:GUIP:TCU:tempEditStr
			tempEditStr =  lba.listWave [lba.row] [0]
			break
		case 7: // finish edit - rename the control, if name has changed
			SVAR tempEditStr = root:packages:GUIP:TCU:tempEditStr
			string reEditStr =   lba.listWave [lba.row] [0]
			if (CmpStr (tempEditStr, reEditStr) != 0)
			 	GUIPTabRenameControl (thePanel, theTabControl, tempEditStr, reEditStr, 1)
			 	TabManShowDataBase (thePanel, theTabControl)
			 endif
			break
	endswitch
	return 0
End


//******************************************************************************************************
//Sets other controls to dislay correct info on chosen tabcontrol
// Last Modified 2015/04/29 by Jamie Boyd
Static Function TabManTabControlPopUpProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			string popStr = pa.popStr
			//Get global strings
			SVAR theTabControlG = root:packages:GUIP:TCU:theTabControl
			SVAR thePanel = root:packages:GUIP:TCU:thePanel
			// Controls listbox waves
			WAVE/T ControlList = root:packages:GUIP:TCU:Control_List
			WAVE ControlSel = root:packages:GUIP:TCU:ControlSel_List
			// Tabcontrol listbox waves
			WAVE/T TabList = root:packages:GUIP:TCU:Tab_list
			WAVE TabListSel = root:packages:GUIP:TCU:tab_listSelWave
			// Is it an un-assignment request?
			if (cmpStr (popStr [0,14] , "Un-assign from ") == 0)
				string unAssignList = ""
				string unAssignTabControl = popStr[15, strlen (popStr) -1]
				variable iControl, nControls = dimsize (controlList, 0)
				for (iControl = 0; iControl < nControls; iControl+=1)
					if (ControlSel [iControl] [0] > 0)
						unAssignList += ControlList [iControl] [0] + ";"
						ControlList [iControl] [2] = "not assigned"
					endif
				endfor
				GUIPTabRemoveControls (thePanel, unAssignTabControl, "", unAssignList, 1)
				theTabControlG = "not assigned"
				redimension/n = (1,2) TabList, TablistSel
				TabList = ""
				// Add a new tabControl?
			elseif (cmpStr (popStr, "Add a New Tab Control") == 0)
				string newTabcontrolName, NewTabName, userProcName
				Prompt newTabName, "Name for First Tab:" 
				Prompt newTabcontrolName, "New TabControl:" 
				Prompt userProcName, "Name of extra User Proc (or \"\" if none)."
				DoPrompt "Give the New TabControl a Name", newTabcontrolName, newTabName, userProcName
				if (V_Flag == 1)
					return -1
				endif
				newTabcontrolName = CleanupName(newTabcontrolName, 0 )
				newTabName = CleanupName(newTabName, 0 )
				// Make the new tabControl, and start a database for it
				TabControl $newTabcontrolName , proc=GUIPTabProc, win= $thePanel, tabLabel(0)= newTabName
				if (cmpStr (userProcName, "") == 0)
					GUIPTabNewTabCtrl (thePanel, newTabcontrolName, tabList=newTabName + ";")
				else
					GUIPTabNewTabCtrl (thePanel, newTabcontrolName, tabList=newTabName + ";", UserFunc=userProcName)
				endif
				theTabControlG=newTabcontrolName
				redimension/n=(1,2) tabList, tabListSel
				TabList [0][0] = newTabName
				TabList [0][1] = "disable"
				TabListSel = 32
				// add new tabControl to Controls list box
				variable insertPt = dimsize (controlList, 0)
				InsertPoints /M=0 insertPt, 1, controlList , ControlSel
				controlList [insertPt] [0] = newTabcontrolName
				controlList [insertPt] [1] = "TabControl"
				controlList [insertPt] [2] = "not assigned"
			else // selecting an existing tabControl, perhaps one for which the control is already registered
				theTabControlG = popStr
				string aTab, tabs = GUIPTabGetTabList (thePanel, popStr)
				if (cmpStr (tabs, "") == 0) // tabCOntrol does not have a database yet
					controlinfo /W=$thePanel $popStr
					if (V_Flag == 0) // the control does not exist, so return 1, for error
						return 1
					else
						tabs = GUIPTabListFromRecStr (S_recreation)
						GUIPTabNewTabCtrl (thePanel, popStr, TabList=tabs)
					endif
				endif
				variable iTab, nTabs = itemsinList (tabs)
				redimension/n=(2,nTabs) Tablist, tablistsel
				controlinfo/w= GUIPTab_Manager AddtoDBaseGrp
				// if multiple controls selected, just show checks uncheked
				if (cmpStr (S_value, "Multiple Controls Selected") == 0)
					for (iTab = 0; iTab < nTabs; iTab += 1)
						aTab = stringfromList (iTab, tabs)
						TabList [iTab] [0]= aTab
						TabList [iTab] [1]= "disable"
					endfor
				else // only 1 control selected. show checked status
					string theCtrl = S_Value [20, strlen (S_Value)-1]
					string tabsAndAbleStr =  GUIPTabCheckDataBase (thePanel, popStr, theCtrl, 1)
					string onTabs = StringFromList(0, tabsAndAbleStr, " ")
					string ableStates = StringFromList(1, tabsAndAbleStr, " ")
					variable whichTab
					for (iTab = 0; iTab < nTabs; iTab += 1)
						aTab = stringfromList (iTab, tabs)
						TabList [iTab] [0] = aTab
						TabList [iTab] [1] = "disable"
						whichTab = WhichListItem(aTab, onTabs, ";")
						if (whichTab > -1)
							TabListSel [iTab] [0]= 0x30
							if (str2num (StringFromList(whichTab, ableStates, ";")) == 2)
								TabListSel [iTab] [1]= 0x30
							else
								TabListSel [iTab] [1]= 0x20
							endif
						else
							TabListSel [iTab][0] = 0x20
							TabListSel [iTab] [1]= 0x20
						endif
					endfor
				endif
			endif
			// Update titlebox and dataBase for the selected tabControl 
			TabManShowDataBase (thePanel, theTabControlG)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
// Modifies the dataBase by removing a tabControl following a right click, or modifies the database and removes the controls as well
// Last Modified 2015/04/29 by Jamie Boyd
Static Function TabManTabsListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			lba.row = min (dimsize (lba.listWave, 0) -1, lba.row)
			string theTab = lba.listWave [lba.row]
			if (lba.eventMod & 16)
				if (lba.col ==0)
					PopupContextualMenu  "delete " + lba.listWave[lba.row] + ";delete " + lba.listWave[lba.row] + " and associated controls;cancel"
					if (!((V_Flag ==1) || (V_Flag ==2)))
						return 1
					else
						SVAR tabWinStr = root:packages:GUIP:TCU:thePanel
						SVAR tabControlStr = root:packages:GUIP:TCU:theTabControl
						if (V_Flag ==1) // delete tab from tabControl
							GUIPTabRemoveTab(tabWinStr, tabControlStr,  lba.listWave[lba.row], 1)
							DeletePoints lba.row, 1,lba.listWave, lba.selWave
						elseif (V_Flag ==2) // delete tab from tabControl, and also delete controls associated with this tab
							GUIPTabRemoveTab(tabWinStr, tabControlStr,  lba.listWave[lba.row], 3)
							DeletePoints lba.row, 1,lba.listWave, lba.selWave
						endif					
						// Update titlebox and dataBase for the selected tabControl 
						TabManShowDataBase (tabWinStr, tabControlStr)
						// update ctrl list
						STRUCT WMPopupAction pa
						pa.eventCode = 2
						pa.win="GUIPTab_Manager"
						pa.popStr = tabWinStr
						pa.ctrlName = "PanelPopUp"
						TabManPanelPopUpProc(pa)
					endif
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

//******************************************************************************************************
// Modifies the dataBase by adding/removing the selected controls for the checked/unchecked tab
// Last Modified 2015/04/29 by Jamie Boyd
STATIC Function TabApplySettingsButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			variable applyShowHide = SelectNumber ((ba.eventMod & 2), 0, 1)
			// Globals for control panel and tab control under consideration on the manager panel
			SVAR  tabWinStr = root:packages:GUIP:TCU:thePanel
			SVAR tabControlStr =  root:packages:GUIP:TCU:thetabControl
			// List of controls on the selected tab control, as displayed on the manager
			WAVE/T controlList =  root:packages:GUIP:TCU:control_list
			WAVE controlSelList = root:packages:GUIP:TCU:controlSel_list
			// List of tabs on the selected tab control
			WAVE/T tabList =  root:packages:GUIP:TCU:tab_list
			WAVE tabSelList =  root:packages:GUIP:TCU:tab_listSelWave
			variable iTab, nTabs= dimSize (tabList, 0)
			// set a variable if all tabs are unselected
			variable noTabsSelcted = 1
			for (iTab =0; iTab < ntabs; iTab +=1)
				if  (tabSelList [iTab] [0] & 0x10) // the checkbox for this tab is set
					noTabsSelcted =0
					break
				endif
			endfor
			// make a list of selected controls and, if tabs are selected, a matching list of 
			// control types
			string selectedControls ="", controlTypes = ""
			variable iCtrl, nCtrls = dimsize (controllist, 0)
			for (iCtrl =0 ; iCtrl < nCtrls; iCtrl +=1)
				if (controlSelList [iCtrl] & 1) // this control is selected
					selectedControls += controlList [iCtrl] [0]  + ";"
					if  (noTabsSelcted)
						controlList [iCtrl] [2] = "not assigned"
					else
						controlList [iCtrl] [2] = tabControlStr
						controlTypes +=  controlList [iCtrl] [1] + ";"
					endif
				endif
			endfor 
			// process lists of selected controls and control types
			nCtrls = itemsInList (selectedControls)
			string tabStr, ctrlList
			variable onTab
			string ableStateStr
			for (iTab =0; iTab < nTabs; iTab +=1)
				tabStr = tabList [iTab] [0]
				onTab = (tabSelList [iTab] [0] & 0x10) / 0x10
				ableStateStr = " " + num2str ((tabSelList [iTab] [1] & 0x10) / 0x8) + ";"
				ctrlList = ""
				if (onTab)
					for (iCtrl =0; iCtrl < nCtrls; iCtrl +=1)
						ctrlList += stringfromlist (iCtrl, controlTypes, ";")   + " " + stringfromlist (iCtrl, selectedControls, ";")   + ableStateStr
					endfor
					GUIPTabAddCtrls (tabWinStr, tabControlStr, tabStr, ctrlList,applyAbleState=applyShowHide)
				else
					for (iCtrl =0; iCtrl < nCtrls; iCtrl +=1)
						ctrlList += stringfromlist (iCtrl, selectedControls, ";")
					endfor
					GUIPTabRemoveControls (tabWinStr, tabControlStr, tabStr, ctrlList, 0)
				endif
			endfor
			TabManShowDataBase (tabWinStr, tabControlStr)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//******************************************************************************************************
//Show the database for a chosen TabControl
// Last Modified 2015/04/30 by Jamie Boyd
Static Function TabManShowDataBase (tabWinStr, tabControlStr)
	string tabWinStr, tabControlStr
	
	GroupBox DataBaseGrp win = GUIPTab_Manager, title="DataBase for " + tabControlStr
	//Reference to DBase wave
	WAVE/T DBListWave = root:packages:GUIP:TCU:DataBase
	WAVE DBSelWave =root:packages:GUIP:TCU:DataBaseSel
	//Get list of tabs for the tabcontrol, find out how long waves need to be
	string folderPath = "root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr) + ":" + tabControlStr + ":"
	SVAR/Z tabListG = $folderpath + "tabList"
	string tabList
	if (!(SVAR_EXISTS (tabListG)))
		controlinfo /W=$tabWinStr $tabControlStr
		if (V_Flag == 0) // the control does not exist, so return 1, for error
			tabLIst = ""
		else
			tabList = GUIPTabListFromRecStr (S_recreation)
		endif
	else
		tabList = tabListG
	endif
	variable iTab, nTabs = itemsinList (tabList, ";"), iCtrl, nCtrls
	string tabStr
	for (iTab =0; iTab < nTabs; iTab += 1)
		tabStr = stringfromlist (iTab, tabList, ";")
		// waves for this tabControl
		WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlNames"
		WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlTypes"
		WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlAbles"
		// if waves do not exist,  skip
		if (!((waveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles)))
			nCtrls =0
		else
			nCtrls= dimSize (ctrlNames, 0)
		endif
		redimension/n = (max (1, nCtrls), nTabs) DBListWave, DBSelWave
		if (nCtrls ==0)
			DBListWave = ""
			DBSelWave = 0
		endif
		SetDimLabel 1,(iTab),$tabStr,DBListWave
		for (iCtrl =0; iCtrl < nCtrls; iCtrl +=1)
			DBListWave [iCtrl] [iTab] =ctrlTypes  [iCtrl] + " " +  ctrlNames [iCtrl] + " " + num2str (ctrlAbles [iCtrl])
		endfor
	endfor
end


//******************************************************************************************************
// Sorts a 2D text wave.  All of the columns in the wave are sorted using  the chosen column
Static Function SortTextByColumn (thewave, theColumn)
	Wave/T thewave	// A 2D text wave we want to sort
	variable thecolumn	// The column we want to sort all the columns by
	
	variable numcolumns = (dimsize (thewave, 1)), ii
	string Tempwavelist = ""
	for (ii = 0; ii < numcolumns; ii += 1)
		make/T/o/N = (dimsize (thewave, 0)) $"tempwave_" + num2str (ii)
		WAVE/T tempwave = $"tempwave_" + num2str (ii)
		tempwave = thewave [p] [ii]
		Tempwavelist += ", tempwave_" + num2str (ii) 
	endfor
	string TempSortwaveName = "tempwave_" + num2str (theColumn)
	execute "sort " +  TempSortwaveName + Tempwavelist
	for (ii = 0; ii < numcolumns; ii += 1)
		WAVE/T tempwave = $"tempwave_" + num2str (ii)
		theWave [] [ii] = tempwave [p]
		Killwaves/z tempwave
	endfor
end

//******************************************************************************************************
// Returns a list of tab controls on the current panel, for use in the Tabcontrol popup menu
// Last Modified 2015/04/29 by Jamie Boyd
Static Function/S TabManListTabControls ()
	
	WAVE/T ControlList = root:packages:GUIP:TCU:control_List
	WAVE controlSelList = root:packages:GUIP:TCU:controlSel_list
	VARIABLE ii, numcntrls = dimsize (ControlList, 0)
	STRING UnAssign ="" // leave blank if control is currently not assigned
	string TabList = ""
	For (ii = 0; ii < numcntrls; ii += 1)
		if (ControlSelList [ii] [0]   & 1) // control is selected - check to see if assigned
			if  (cmpstr (ControlList [ii] [2], "not assigned")  != 0) // it is assigned
				UnAssign =  "Un-assign from " + ControlList [ii] [2]
			endif
		endif
		if  (cmpstr (ControlList [ii] [1], "TabControl")  == 0) // its a tab control
		 	if ((ControlSelList [ii] [0]  & 1) == 0) // don't add selected tabcontrols to tabcontrol list
				TabList +=  ControlList [ii] [0] + ";"
			endif
		endif
	endfor
	return TabList + "\\M1-;Add a New Tab Control;" + UnAssign
end

//******************************************************************************************************
// Adds a tab to the tabControl selected in the popMenu
// Last Modified 2013/04/30 by Jamie Boyd
Static Function TabManNewTabProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			//Find out what panel we are working with
			controlinfo /w= GUIPTab_Manager PanelGrp
			string tabWinStr = S_Value
			// Find out what tabControl is selected
			SVAR thetabControl = root:packages:GUIP:TCU:theTabControl
			// Prompt for new tab name
			string newTabName
			Prompt newTabName, "New Tab:" 
			DoPrompt "Give the New Tab a Name", newTabName
			if (V_Flag == 1)
				return -1
			endif
			//Add the new tab to the dataBase, and to the tabControl
			GUIPTabAddTab (tabWinStr, thetabControl, newTabName, 3)
			// adjust the controls to reflect new tab
			// call popup menu procedure with selcted tabControl
			STRUCT WMPopupAction pa
			pa.eventCode = 2
			pa.win="GUIPTab_Manager"
			pa.popStr = theTabControl
			pa.ctrlName = "TabControlPopup"
			TabManTabControlPopUpProc(pa)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

//******************************************************************************************************
// Makes edits to the database based on edits in the list box of the database. It is not a good idea to do more than change
// the able state here, as the old databse items will not be overwritten, new ones will be added.
// This could be added
// Last modified 2013/05/01 by Jamie Boyd
Static Function TabManDBListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			SVAR tempEditStr = root:packages:GUIP:TCU:tempEditStr
			tempEditStr =  lba.listWave [lba.row] [lba.col]
			break
		case 7: // finish edit
			SVAR tabWinStr = root:packages:GUIP:TCU:thePanel
			SVAR tabControlStr = root:packages:GUIP:TCU:theTabControl
			string tabStr = GetDimLabel(lba.listWave, 1, lba.col) //&&&&
			//GUIPTabAddCtrls (tabWinStr, tabControlStr, tabStr, listWave[lba.row] [lba.col])
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch
	return 0
End

			 
//******************************************************************************************************
// Prints the recreation code for selected controls in the listbox.
// Last modified 2013/05/02 by Jamie Boyd
Static Function TabManPrintCommands(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	
	switch( pa.eventCode )
		case 2: // mouse up
			// Make a list of selected controls
			controlinfo /w= GUIPTab_Manager PanelGrp
			string thepanel = S_Value
			WAVE/T controlListWave= root:packages:GUIP:TCU:Control_List
			WAVE controlSelList = root:packages:GUIP:TCU:ControlSel_List
			variable iControl, nControls = dimsize (controlListWave, 0)
			string printList = ""
			for (iControl=0; iControl < nControls; iControl +=1)
				if (controlSelList [iControl] [0])
					if (cmpStr (controlListWave [iControl] [1], "SubWindow") == 0)
						printList += TabManSubMenuCommands (thepanel, controlListWave [iControl] [0])
					else
						ControlInfo/W=$(thepanel) $(controlListWave [iControl] [0])
						printList += S_recreation
					endif
				endif
			endfor
			// add window info to commands
			thepanel = " win = " + thePanel
			variable insertPos
			string aCommand, printListPanel = ""
			for (iControl =0, nControls = itemsinList (printList, "\r"); iControl < nControls; iControl +=1)
				aCommand = stringFromList (iControl, printList, "\r")
				insertPos = strsearch (aCommand, ",", 0)
				aCommand [insertPos] = thePanel
				printListPanel += aCommand + "\r"
			endfor
			// Print the big string to the required place
			strswitch (pa.popStr)
				case "History Window":
					print printListPanel
					break
				case  "ClipBoard":
					PutScrapText printListPanel
					break
				default:
					Notebook $pa.popStr, text = printListPanel
			endswitch
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
// returns the recreation code for a subwindow of an existing control panel
// returns empty string if  subwindow code not found
// Last modified 2013/05/02 by Jamie Boyd
Static Function/S TabManSubMenuCommands (thePanel, theSubWindow)
	string thePanel
	string theSubWindow
	
	string aLine, returnStr = ""
	string recStr = WinRecreation(thePanel, 0)
	variable iLine, nLines = itemsinList (recStr, "\r")
	// start at end of recreation macro and look for end of code for the subwindow
	for (iLine = nLines -1; iLine > -1; iLine -=1)
		if (StringMatch (stringfromlist (iLine, recStr, "\r"), "*RenameWindow #," + theSubwindow))
			// found end of code for the subwindow. 
			// start building output string and looking for start of code for this subwindow
			for (iLine += 1;iLine > -1; iLine -=1)
				aLine = stringfromlist (iLine, recStr, "\r")
				returnStr = AddListItem(aLine, returnStr, "\r", 0)
				// if this is the first line of the subwindow code, return 
				if (StringMatch (aLine, "*/HOST=# "))
					return returnStr
				endif
			endfor
		endif
	endfor
	return ""
end

//******************************************************************************************************
// Prints the commands to make the DataBase for the current tabControl
// Last Modified 2013/05/01 by Jamie Boyd
Static Function ManPrintDBaseProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	
	switch( pa.eventCode )
		case 2: // mouse up
			SVAR thePanel =root:packages:GUIP:TCU:thePanel
			SVAR theTabCtrl =  root:packages:GUIP:TCU:theTabControl
			string folderPath = "root:packages:GUIP:TCD:" + PossiblyQuoteName (thePanel) + ":" +  theTabCtrl + ":"
			SVAR tabList = $folderPath + "tabList"
			SVAR/Z userFuncStr = $folderPath + "UserUpdateFunc"
			// strings for making list of commands
			string returnStr = ""
			string commandStr
			// initialize the database
			if (SVAR_EXISTS (userFuncStr))
				sprintf commandStr, "GUIPTabNewTabCtrl (\"%s\", \"%s\", tabList=\"%s\", UserFunc=\"%s\")\r" ,thePanel, theTabCtrl, tabList, userFuncStr
			else
				sprintf commandStr, "GUIPTabNewTabCtrl (\"%s\", \"%s\", tabList=\"%s\")\r" ,thePanel, theTabCtrl, tabList
			endif
			returnStr += commandStr
			// add controls for each tab
			variable iTab, nTabs = itemsinlist (tabList, ";")
			string aTab
			variable iCntrl, nCntrls
			for (iTab =0; iTab < nTabs; iTab +=1)
				aTab = stringfromlist (iTab, tabList, ";")
				WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (aTab) + "_ctrlNames"
				WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (aTab) + "_ctrlTypes"
				WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (aTab) + "_ctrlAbles"
				if (!(((waveExists (ctrlNames)) && waveExists (ctrlTypes)) && waveExists (ctrlables)))
					continue
				endif
				for (iCntrl =0, nCntrls = numpnts (ctrlNames); iCntrl < nCntrls; iCntrl +=1)
					sprintf commandStr "GUIPTabAddCtrls (\"%s\", \"%s\",  \"%s\", \"%s %s %d;\")\r", thePanel, theTabCtrl, aTab, ctrlTypes [iCntrl], ctrlNames [iCntrl], ctrlAbles [iCntrl]
					returnStr += commandStr
				endfor
			endfor
			// Print the big string to the required place
			strswitch (pa.popStr)
				case "History Window":
					print returnStr
					break
				case  "ClipBoard":
					PutScrapText returnStr
					break
				default:
					Notebook $pa.popStr, text = returnStr
			endswitch
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
//Clears the database for the currently selected tabControl
// Last Modified 2013/05/01 by Jamie Boyd
Static Function TabManClearDataBaseProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			SVAR tabWinStr =root:packages:GUIP:TCU:thePanel
			SVAR tabControlStr =  root:packages:GUIP:TCU:theTabControl
			string folderPath = "root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr) + ":" + tabControlStr + ":"
			//make sure tabcontrol and databse exists
			SVAR tabList = $folderPath + "tabList"
			variable iTab, nTabs = itemsInList (tabList, ";")
			string tabStr
			for (iTab =0; iTab < nTabs; iTab += 1)
				tabStr = stringfromlist (iTab, tabList, ";")
				// waves for this tab on the tabControl
				WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlNames"
				WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlTypes"
				WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlAbles"
				// if waves do not exist, return error
				if (!((waveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles)))
					continue
				endif
				redimension/n = 0 ctrlNames, ctrlTypes, ctrlAbles
			endfor
			// update ctrl list
			STRUCT WMPopupAction pa
			pa.eventCode = 2
			pa.win="GUIPTab_Manager"
			pa.popStr = tabWinStr
			pa.ctrlName = "PanelPopUp"
			TabManPanelPopUpProc(pa)
			// call popup menu procedure with selcted tabControl
			pa.popStr = tabControlStr
			pa.ctrlName = "TabControlPopup"
			TabManTabControlPopUpProc(pa)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
//Sets order for making multi-row tabControls
// Last Modified 2013/05/01 by Jamie Boyd
Static Function TabManMultiListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case 1: // clicked on
			if (col ==1) // setting row position
				variable ii, nRows = dimsize (listWave, 0)
				string popupStr = "Deselect;\\M1-;"
				for (ii = 0; ii < nRows; ii += 1)
					popupStr += num2str (ii + 1) + ";"
				endfor
				PopupContextualMenu /C=(lba.mouseLoc.h, lba.mouseLoc.v) popupStr
				if (V_Flag > 0) // no error
					if (cmpstr (S_Selection, "Deselect") == 0)
						listWave [row] [1] = ""
					else
						listWave [row] [1] = S_selection
					endif
				endif
			endif
			break
		case -1: // control being killed
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
	endswitch

	return 0
End

//******************************************************************************************************
// Makes a multi-row tabCOntrol from existing tabControls
// Last Modified 2013/05/01 by Jamie Boyd
Static Function TabManMakeMultiRow(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			
			SVAR tabWinStr =root:packages:GUIP:TCU:thePanel
			string multiName
			Prompt multiName, "Group Name :"
			doPrompt "Give a name for this \"Family\" group of tabs",  multiName
			if (V_Flag) //cancel was clicked on the dialog, so exit
				return 1
			endif
			WAVE/T TabControlList = root:packages:GUIP:TCU:TabControlList
			variable iTC, nTCs = dimSize (TabControlList, 0), nSelTC
			string aTabControl
			variable aTabPos
			string sibTabsList =""
			for (iTC =0, nSelTC=0; iTC < nTCs; iTC +=1)
				aTabPos =  str2num (TabControlList [iTC] [1])
				if (numType(aTabPos) == 0)
					sibTabsList += " ;"
					nSelTC = max (aTabPos, nSelTC)
				endif
			endfor
			for (iTC =0; iTC < nTCs; iTC +=1)
				aTabControl = TabControlList [iTC] [0]
				aTabPos =  str2num (TabControlList [iTC] [1])-1
				if (numType(aTabPos) == 0)
					sibTabsList = RemoveListItem(aTabPos, sibTabsList , ";" )
					sibTabsList = AddListItem(aTabControl, sibTabsList, ";" , aTabPos)
				endif
			endfor
			GUIPTabMultiMake (tabWinStr, multiName, sibTabsList)
			break
	endswitch
	return 0
End

//******************************************************************************************************
//******************************* GUIPTab Static Utility Functions ***********************************************
//******************************************************************************************************
// Removes a tabcontrol and all of its associated controls
// Last modified 2014/08/19 by Jamie Boyd
STATIC Function GUIPTabKillTabControl (tabWinStr, tabControlStr, ModTabControl)
	string tabWinStr, tabControlStr
	variable ModTabControl
	
	// database for each tabcontrol is stored in a set of waves in a datafolder within the packages folder 
	string folderPath = "root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr) + ":" + tabControlStr + ":"
	if (ModTabControl)
		//make sure tabcontrol and databse exists
		SVAR/Z tabList = $folderPath + "tabList"
		ControlInfo /W=$tabWinStr  $tabControlStr
		if ((V_Flag == 8) && (SVAR_EXISTS (tabList)))
			variable iTab, nTabs = itemsInList (tabList, ";")
			variable iControl, nControls
			string tabStr, aControl
			variable iOtherTab, OtherPos
			string otherTabStr
			for (iTab =0; iTab < nTabs; iTab += 1)
				tabStr = stringfromlist (iTab, tabList, ";")
				// waves for this tab on the tabControl
				WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlNames"
				WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlTypes"
				WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlAbles"
				// if waves do not exist, return error
				if (!((waveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles)))
					return 1
				endif
				nControls = numPnts (ctrlNames)
				for (iControl =0; iControl < nControls; iControl +=1)
					aControl = ctrlNames [iControl]
					if (cmpStr (ctrlTypes [iControl], "SubWindow") ==0)
						killwindow $tabWinStr#$aControl
					elseif (cmpStr (ctrlTypes [iControl], "TabControl") ==0)
						GUIPTabKillTabControl (tabWinStr, tabControlStr, 1)
					else
						KillControl /W=$tabWinStr $aControl
					endif
					// remove controls from tab list for other tabs on this control, so we don't try to remove them again
					for (iOtherTab =iTab +1; iOtherTab < nTabs; iOtherTab += 1)
						otherTabStr =  stringfromlist (iOtherTab, tabList, ";")
						WAVE/z/T OtherCtrlNames = $folderPath + PossiblyQuoteName (otherTabStr) + "_ctrlNames"
						OtherPos = GUIPMathFindText (OtherCtrlNames, aControl, 0, INF, 0)
						if (otherPos > -1)
							WAVE/z/T otherCtrlTypes = $folderPath + PossiblyQuoteName (otherTabStr) + "_ctrlTypes"
							WAVE/z OtherCtrlAbles = $folderPath + PossiblyQuoteName (otherTabStr) + "_ctrlAbles"
							deletepoints otherPos, 1, OtherCtrlNames, otherCtrlTypes, OtherCtrlAbles
						endif
					endfor
				endfor
			endfor
		endif
	endif
	KillControl/w = $tabWinStr $tabControlStr
	KillDataFolder /Z folderPath
end

//******************************************************************************************************
// Utility function that returns a list of tabs by parsing a TabControl re-creation string. Don't use on any other kind of string.
// Last modified 2013/04/25 by Jamie Boyd
Static Function/S GUIPTabListFromRecStr (S_recreation)
	string &S_recreation
	
	string theTabList = ""
	variable iTab, iPos, iEnd
	for (itab = 0; ; iTab += 1, iPos = iEnd)
		iPos = strsearch(S_recreation, "tabLabel(" + num2str (iTab) + ")", iPos) + 13
		if (iPos < 14)
			break
		endif
		iEnd = strsearch(S_recreation, "\"", iPos + 2) -1
		theTabList += S_recreation [iPos, iEnd] + ";"
	endfor
	return theTabList
end

//******************************************************************************************************
// shows or hides a control, or a subwindow
// Last Modified 2015/04/30 by Jamie Boyd
Static Function GUIPTabShowHide (ctrlName, ctrlType, ctrlState, tabWindow)
	string ctrlName
	string ctrlType
	variable ctrlState // bit 0 is hide, bit 1 is disable. 0 means showing and enabled, 1 means hidden, 2 means showing and disabled, 4 is special code for  re-enabling
	string tabWindow
	
	strSwitch (ctrlType)
		case "SubWindow": // special code for hiding/showing subwindows with same functions used for tab controls
			if (WhichListItem(ctrlName, ChildWindowList(tabWindow), ";", 0) > -1) // then it is a subwindow
				SetWindow $tabwindow#$ctrlName, hide =(ctrlState & 1)
				// Hide/Show any SubWindows of this SubWindow
				STRING subWinList = ChildWindowList(tabWindow + "#" + ctrlName)
				VARIABLE iWin, nWins = itemsinList (subWinList, ";")
				for (iWin =0; iWin < nWins; iWin += 1)
					GUIPTabShowHide (stringfromlist (iWin, subWinList), ctrlType, ctrlState, tabWindow + "#" + ctrlName)
				endfor
				// if disabling or re-enabling with bit 2, disable controls in the subwindow
				if ((ctrlState & 4) || (ctrlState & 2))
					string ctrlList = ControlNameList(tabwindow + "#" + ctrlName)
					variable iCtrl, nCtrls = itemsinlist (ctrlList, ";"), subWinCtrlType
					string aControl, controlSubWin = tabWindow + "#" + ctrlName
					for (iCtrl =0; iCtrl < nCtrls; iCtrl +=1)
						aControl = stringFromList (iCtrl, ctrlList, ";")
						ControlInfo/W=$controlSubWin $aControl
						subWinCtrlType = abs (V_Flag)
						switch (subWinCtrlType)
							case 1:
								Button/Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 6:
								Chart/Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 2:
								CheckBox /Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 12:
								CustomControl /Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 9:
								GroupBox /Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 11:
								ListBox /Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 3:
								PopUpMenu  /Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 5:
								SetVariable /Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 7:
								Slider /Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 8:
								TabControl /Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 10:
								TitleBox/Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
							case 4:
								ValDisplay/Z $aControl win = $controlSubWin, disable = ~4 & ctrlState
								break
						endswitch
					endfor
				endif
			endif
			break
		case  "Button":
			Button/Z $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
		case "CheckBox":
			CheckBox/Z $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
		case "PopupMenu":
			PopupMenu/Z $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
		case "ValDisplay":
			ValDisplay/Z $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
		case "SetVariable":
			SetVariable/Z $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
		case "Chart":
			Chart/Z $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
		case "Slider":
			Slider/Z $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
		case "TabControl":	// This one is special, as we want hiding to cascade through nested TabControls
			// hide or show the TabControl
			GUIPTabShowHideTabControl (ctrlName, ctrlState, tabWindow)
			break
		case "GroupBox":
			GroupBox/Z $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
		case "TitleBox":
			TitleBox/Z $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
		case "ListBox":
			ListBox/Z $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
		case "CustomControl":
			CustomControl/Z  $ctrlName win = $tabwindow, disable=~4 & ctrlState
			break
	endswitch
end

//******************************************************************************************************
// Shows or hides a tab control including all its associated controls
// Last Modified 2012/06/29 by Jamie Boyd
Static Function GUIPTabShowHideTabControl (ctrlName, hideBit, tabWindow)
	string ctrlName
	variable hideBit
	string tabWindow
	
	// hide this tab control
	TabControl $ctrlName win = $tabwindow, disable= ~4 & hideBit
	// database for each tabcontrol is stored in a set of waves in a datafolder within the packages folder 
	string folderPath = "root:packages:GUIP:TCD:" + PossiblyQuoteName (tabWindow) + ":" + ctrlName + ":"
	variable iControl, nControls
	// get list of controls for showing tab and hide them
	SVAR curTab = $folderPath + "currentTab"
	WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (curTab) + "_ctrlNames"
	WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (curTab) + "_ctrlTypes"
	WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (curTab) + "_ctrlAbles"
	if ((WaveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles))
		nControls = numPnts (ctrlNames)
		for (iControl =0; iControl < nControls; iControl +=1)
			GUIPTabShowHide (ctrlNames [iControl], ctrlTypes [iControl], ctrlAbles [iControl] | hideBit, tabWindow)
		endfor
	endif
end

//******************************************************************************************************
// returns the list of tabControls for the given  panel
// Last Modfied 2013/04/29
Static Function/S GUIPTabGetTabControlList (tabWinStr)
	string tabWinStr	// Name of the conrolpanel/graph
	
	string folderPath = "root:packages:GUIP:TCD:" + PossiblyQuoteName (tabWinStr)
	if (DataFOlderExists (folderPath))
		return GUIPListObjs (folderPath, 4, "*", 0, "")
	else
		return ""
	endif
end


//******************************************************************************************************
// returns the list of controls controlled by the given tabControl for the  given panel
// Last Modfied 2013/04/29
Static Function/S GUIPTabGetControlList (tabWinStr, tabControlStr)
	string tabWinStr
	string tabControlStr
	
	string folderPath = "root:packages:GUIP:TCD:" + PossiblyQuoteName (tabWinStr) + ":" + tabControlStr + ":"
	variable iControl, nControls
	// get list of controls by looking at all tabs
	SVAR/Z tabList =$"root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr) + ":" + tabControlStr + ":tabList"
	string returnList = ""
	variable iPnt, nPnts
	if (SVAR_EXISTS (tabList))
		variable iTab, nTabs = itemsinlist (tabList, ";")
		for (iTab =0; iTab < nTabs; iTab +=1)
			WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (stringFromList (iTab, tabList, ";")) + "_ctrlNames"
			if (WaveExists (ctrlNames))
				for (iPnt =0; iPnt < numpnts (ctrlNames); iPnt +=1)
					if (whichListItem (ctrlNames [iPnt], returnList, ";") == -1)
						returnList += ctrlNames [iPnt] + ";"
					endif
				endfor
			endif
		endfor
	endif
	return returnList
end

//******************************************************************************************************
// returns the list of tabs for the given tab control on the given panel
// Last Modfied 2012/07/03
Function/S GUIPTabGetTabList (tabWinStr, tabControlStr)
	string tabWinStr	// Name of the conrolpanel/graph containing tabcontrol
	string tabControlStr // name of the tab control to get the tabs for
	
	SVAR/Z tabList =$"root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr) + ":" + tabControlStr + ":tabList"
	if (SVAR_EXISTS (tabList))
		return tabList
	else
		return ""
	endif
end

//******************************************************************************************************
// returns the name of the user function (if any) for  the given tab control on the given panel
// Last Modfied 2012/07/03
Static Function/S GUIPTabGetUserFunc (tabWinStr, tabControlStr)
	string tabWinStr	// Name of the conrolpanel/graph containing tabcontrol
	string tabControlStr // name of the tab control to get the tabs for
	
	SVAR/Z userFunc =$"root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr) + ":" + tabControlStr + ":userUpdateFunc"
	if (SVAR_EXISTS (userFunc))
		return userFunc
	else
		return ""
	endif
end

//******************************************************************************************************
// returns the name of the current tab for the given tab control on the given panel
// Last Modfied 2012/07/03
Function/S GUIPTabGetCurrentTab (tabWinStr, tabControlStr)
	string tabWinStr	// Name of the conrolpanel/graph containing tabcontrol
	string tabControlStr // name of the tab control to get the tabs for
	
	SVAR/Z curTab =$"root:packages:GUIP:TCD:" + possiblyquotename (tabWinStr) + ":" + tabControlStr + ":currentTab"
	if (SVAR_EXISTS (curTab))
		return curTab
	else
		return ""
	endif
end

//******************************************************************************************************
//Checks if a control is present in the database for a tab control
// returns a string list of tabs for which the control is present
// last modified 2014/08/19 by Jamie Boyd
Static Function/S GUIPTabCheckDataBase (tabWinStr, tabControlStr, theCtrl, addAbleState)
	string tabWinStr //name of the window or subwindow containing the tabcontrol
	string  tabControlStr //name of the tabControl
	string theCtrl // name of control to check
	variable addAbleState // if set, adds able state
	// get path to folder for this tabcontrol and to waves for this tab of the tabcontrol
	// if folder does not exist, exit with an error
	string folderPath = "root:packages:GUIP:TCD:" + PossiblyQuoteName (tabWinStr) + ":" + tabControlStr + ":"
	string tabListR = "", ableListR = ""
	SVAR/Z tabList = $folderPath + "tabList"
	if (!(SVAR_EXISTS (tabList)))
		return ""
	endif
	variable iTab, nTabs = itemsinlist (tabList, ";"), ctrlNum
	string tabStr
	for (iTab =0; iTab < nTabs; iTab +=1)
		tabStr = stringFromlist (iTab, tabList, ";")
		WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlNames"
		WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlTypes"
		WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (tabStr) + "_ctrlAbles"
		// if waves do not exist, exit
		if (!((waveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles)))
			continue
		endif
		ctrlNum = GUIPMathFindText (ctrlNames, theCtrl, 0, inf, 0)
		if (ctrlNum > -1)
			tabListR += tabStr + ";"
			if (addAbleState)
				ableListR +=  num2str (ctrlAbles [ctrlNum]) + ";"
			endif
		endif
	endfor
	return tabListR + SelectString(addAbleState , "",  " " + ableListR)
end

//******************************************************************************************************
// Checks the control type. Returns 1 if control type is not one of the recognized types
// Last Modified 2012/06/30 by Jamie Boyd
Static Function GUIPTabCheckControlType (aCtrlType)
	string aCtrlType
	
	strswitch (aCtrlType)
		case "SubWindow":
		case "Button":
		case "CheckBox":
		case "PopupMenu":
		case "ValDisplay":
		case "SetVariable":
		case "Chart": 
		case "Slider":
		case "TabControl":
		case "GroupBox":
		case "TitleBox":
		case "ListBox":
		case "CustomControl":
			return 0
			break
		default:
			return 1
			break
	endSwitch
end


//******************************************************************************************************
//****************************** Radio Button Procedures ***************************************************
//******************************************************************************************************
// A procedure to toggle radio buttons, making use of the control's userdata. The user data for each radio button in a group must contain the names
// of the other buttons in the group, and this procedure will make sure that they are turned off 
// last modified Mar 19 2012 by Jamie Boyd
Function GUIPRadioButtonProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			string sibStr = cba.userData
			string winStr = cba.win
			variable ii, numSibs = itemsinList (sibStr, ";")
			for (ii = 0; ii < numSibs; ii += 1)
				checkBox $stringfromList (ii, sibStr, ";"), win = $winStr, value = 0
			endfor
			break
			
	endswitch
	return 0
End

//******************************************************************************************************
//This procedure also sets a global variable  to a value (from 1st user data element, separated by =)
// last modified Mar 19 2012 by Jamie Boyd
Function GUIPRadioButtonProcSetGlobal(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			string sibStr = cba.userData
			string winStr = cba.win
			NVAR gVar = $stringFromList (0, stringfromList (0, sibStr, ";"), "=")
			variable value = str2num (stringFromList (1, stringfromList (0, sibStr, ";"), "="))
			gVar = value
			variable ii, numSibs = itemsinList (sibStr, ";")
			for (ii = 1; ii < numSibs; ii += 1)
				checkBox $stringfromList (ii, sibStr, ";") win = $winStr, value = 0
			endfor
			break
	endswitch
	return 0
End

//******************************************************************************************************
//****************************** Procedure Pics ***************************************************
//******************************************************************************************************

//Procedure Pics for jazzing up common interface items. First of many?

// Light Switch shaped checkbox, size small
// PNG: width= 114, height= 35
static Picture LightSwitchShort
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!">!!!!D#Qau+!68ruGQ7^D&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U#Q%(\5u_NKh-/'<<'M']\bFCVo?hOlPZ_ZO8jV7BW@e;q5k#p2?br;:i(e57#X3qM[fm?N>mW-Zj
	$jC$e:-&q]lVZ`k.g]ikEngrR8PP7cXKG/qod)A3B80Q`TPR>l0g!0N"EiC;cOS3":66-W)fsi3RFA
	6Bb4/8HfCP3JniZ`>2*d)6:A2%C7n:gi?)#L>FF'RW[aj0ef+L$Rf3U99l%)8.TWS]ipTq6X]r:4cA
	demV3FlXW[]/[:ck4CLQqpn'gc_TDpJTqgMO]HIt+*"L].=^k'?B=*`!'qag-GUH(Nbo+<k=>8V"$V
	LYt5O4m66Q/']mh*OOtUBJe^,#H3gdB;q.T#rJL0(GB(t@5oTJRQc)l/1BASJQl>_p1bS?&E;isRh:
	\,T0N(*?G:f$N-Y?r1!D":&g-o0aV4+$"h]0S.K[Od='&IONaKPM-),2,Y(`Esf)!RV00;6W]RfEq/
	ml=4SC%Oiq!`j9bm3(>Im3uk`f*A3.A]7.YLd!\<h*Z&Q95Zgp&"^Lj^lAl1ef"X!%=[c_RC(#%`D9
	@Ut_-sH)&ck?-8C8V3JmVnA0_^5&u("I<g*`QB2+?H9Hak3#kD<<E2U>03u0M&+/fQ2B%Q77gNg5!.
	_ah%n]EV`/-SVg1Q=<-P!5XW[pf`*MXdS>Zb*9@g`"^Q'IWdY?sA/`>J49iPV=lZ%6iM]YU&:WoD%I
	Vbc?g7\atdc5j\"j2[2m'KECC/1M6;]m;P-OsEU1c2G_iZEcetHGlfK>[Xnk%!$/@)JJa2'J`D3DRZ
	[Sp=7maFsD8PJ5XN88Q_lY<)lp<Lm1!b?>HrPA3[lW#-t1u:'X9K8WkXJ*:>`3nH3d(^XQV^1s9R,;
	s]CBer(=t8h##fd=>DQ*mb*4*?Ef?Ko4nUX>T4GB(amuK0r:)9A&/Z9mrc=0Y!6b@&3#/ZAdTOaCX%
	B[gru[*LICIBk_:2Im5,f]A<JcrO^kl'utmXC8FmKXiJK&EK4S?3?DqC>*r+l!RhDX6$@d<"!+GL3M
	pM*]7kcR29$&[6\cshaq6DKCi+#$Ocu?["VME:Zct4<:_$"m<&"`R*;qj[5*2Z?UKrDiJO,;QSPbJu
	-SQU&#D7TfP)V3Vn^o9`Hsj_HG>of?Qj_DIF.Qpkh#/(Na#&3GK)(>!nDubG+J3c=)^f8/=K@\Wa,_
	=fSe)JZLW9hg84r^Lk>*J[AUbBp,0077g,DTp9)n(AAXP+n-=N6m*p5'VLi?m7:BErWjbr%=/6ArB;
	&gVug>@HmT',cm*QKFM5`2:D+)7]VX]?q^7*.t@Brs,9/Bnr!_(jdFTIe94]aeAb)RLoM:8d-u4;V+
	"'dj+W.'&gp(9lA:p[1&4`gCu=hUUq7(0,Sq4As<lNuluELaYiXp[@"[JQ5_G1#3[&(_#'4H+=DT:*
	a\L;JL2k&K-aME<%m8%8:ZOXLZ-HWe/?%<E31fnU?R0Xi;1l$pHGmo4G<XV8RO;ZND&G2<-s-C'TO$
	enLRBcCL3J:U,aI.>@Dm<i`'2)?ebaSgJ%g#L`7@W\Z%"%9KYK_bSXe@j[qU/<s-&Yh0g8Gi?LCT4J
	/HCLolA3C3pse4,!61,.lB@mB8OH9.`U!FeX:5`0i'n*s&Q*7ULB"]8\H78Xn3lLd2@mlV"HC%#^_!
	p'.te$.:A"Bg[EEb__;NfKX6K6ED'[9>/MOJ;u]2==[s"iZ$p:QQeq!Zg!tD_9.QEH0Bt#bU7)/u@X
	Y`35NNZG`$?SID"k36Pah'a3)"r1GUa_-l3f8!5-rPd2hJ7WSQRGB`Eq5&bKaDHiW++U$]Kc;^iB$9
	%"M`;ORN'WCD^,]TCtPZ#=&M7Gn8_WQ`"'!YK6eBZ>L=]U.Z_BZ\'T_%!ogB1g6a@UpObJ&olD5r.\
	!<0s`BqV$&/E,)!eH>#ZnpPifBIC@'/=JOR(-?c,@<>7bA!_JWbY2f#E,aaVGS6Z(-<O(@.9GYj.A_
	XiO/E7Gok:Iu0M7Q(l_)Z_N<!UnamS?D3o:Z%V;PPu\"f/pAt:i!1`Dndki<9";JcboXPf&i8XPS+[
	XSNACJB7BQbPFmXZ&0tB5rllf)!jn:T"12@h&tYi_'FYS3SbGjAM/eAe=1$joXq?4LjCD:;Lp[@j?e
	ePLfSPs3"o2M;6,(jJm?>D/F30O/ti4LkPLN4uL'ECMR_aI\3gKq0+Hqg[,1c(5`K#[h$,up[1Tuo]
	al@DRXu00*Ug6R9X]JDf=*HGU9)5^Q6aPYcuJh[9B]`p$:3Mi7k_Zan(duX/iRW9Luo<6>D?bKl@iR
	g,a05qGq+Mk2rQ.c7sG&b*D#I@gM=hAc?^uIGI-5[r:/q"_=q!13;NH_=%>-aE7PNLjm,-A3<90lh0
	V2*+)5[`4'[BHj6NR,![=jNCH+Pi75d'6Gda!Lb8B4YHf_"j)Ip178]_<7]o[jeQT*+N>jh%"@uQui
	e.=Y(0`Eh5dT/Ae*8nCEc81D\04Z/QSL[SRE954n65$t5`f7W0YqJMN6M3iPP_l2%9?E0<^XTh,RJK
	E0n%%142;ut-BoSdi[Oa"UqdWe)Rslc8tk64J\`-K_:tO0!L\1*pp4*@lhRIY!:&QQCD`Y@l2Uea!(
	fUS7'8jaJc
	ASCII85End
End

// Light Switch shaped checkbox, size medium
// PNG: width= 144, height= 51
static Picture LightSwitchMedium
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"\!!!!T#Qau+!;EQ1Y5eP&&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U#dm5l5u`*!m9IhleP$e8\X]FC;3-Uo^e:F.il"FS5k"dW+%#K4SG<MP*=.7<k74!h+pa2s"jrG<g
	>96^8NN.5#O@o1];q)e^9@Fs,>HbIOJFD-G$XgE]m!I;HN!]JltW%PG:m.Yq=Ebn;O/VXX/Zep.#O0
	5&Wstd&#7eVrVK%%>)QTi6rCm\NupT0iE9Jn%a4J(`t.`FCKY-]73WBEPI;"smudV$!rUsGp[@!YJW
	5WurCbC+dk.*m*^/Ur53qaO,EFQ+/._OG3du3W_goum`A_?J$t+L3h1+$[b@2K;3Y%PVeJLthcOepF
	GuHa44',K7TsnpqEXLU4F(\!fhS"7`FYg(T#P7]6R57S.gqJ1u9SEOU]70]>XjC`<&s7q[++i[qN>q
	l/>0aa(mfn$0H.L]UB?u=oH1U/-Y>:ZJ_(+G((6K;:r:]O4042H7<ZTf$f%M?=Neg5)IH5\MoVl_e@
	h;&ho&\$q*k\np^0VLB\7+Ff=@AI@QGW4RH1(9>]RTrf6r'=9.3_blEB^(Ka9-]-09M'b.*TSPl"-h
	0Yi,rt$b@*sj'WLHL(k;6D/J[_Pq1gf:S'\2q$cg[Sn#g$KmD8#ecIt$J43<T3cldooBk9kRErg%4I
	jg,Q@h:2)qofM(iAin>'k+;_E8AScZ<H-*-kB@SiqFj1.*&49?c2fQ'IV]p[1W/Oong%Y?nm\-pXC$
	p[=$/@[L<p(2cm7B456-_M&A+d@WRK(+oT4FK!.@](Y1)O&NnTNq'"m8Tam;ZEiJO315ee4H#,UXn'
	8>n;24K6=D7*#uj)B@$A]#k2)X>nj&u13-L#`W2_>k!s(ld;6-Gtn#K#fb#?KYm1OG7-m-M"bSa&d4
	lc-I6@Bm:$+ERNUBc%mf9jm7_'J^_Zgg8)n/sPTlaX[*L,F82jSAE1O45ToSl!=nGW6@@h-Xht;_cE
	.-4uAgqt<l.q?SohjD!0>0Fupg.M'Z`^(N4KZN49:?N0p#GCUus+p`j,Z4HMRqXgbq!/E8P1D;95&S
	\[3%(X!#4IT=9i\3c@XDVWqju1KC+oE`EbenV3b(CU\B6#\_]u4a&XgJFq#\O?ECKkWiMBTGS>E+oV
	OBm+LZ^JNiXYre[`^tF79Pq5]8[`Z%f7a;hCf`,_X#plo;f'gbSmeL)e*6MrkKd$bnpn,k3h;-e&Y*
	=ZknGR(WRD1/G2Y0q3&s5G>r3:=M<@Rs)RD!Dc1DD1+HL[lRWt86kZdbuMPBnBorCla/(6XPYKs2U.
	#MBHIS&?TnNqRp9fuEU20l<Qj2K2ECO*/0qn5AGjENWUb-W$>MLpChD+Ag2WN++%L`M.CrEp7bL7*d
	-=U)@l+(!58V#@Qt_<h>;;9cDjn^m^Z(#7\#:K:DsDEUYuq.k1qZ7JAqf495>DE/gM`Gg!XZReHfUT
	'uJ4B5Ct^]``W<jhPS22RYP?)m9.9)7\u,77t?@8CV&U+!0M]B6k'o+f=9j2[3bH)dkOa1Tu,/@r5)
	<Qh_Y\0sZ?K:/ugmp8kZ,U`(7M?56@30*[sX"Af;SuSfZEcSaMbTf#/nG)<W&po?I1SlK,Cqp/RPDB
	NL'EqK@8*36;1i38;j8nJ'"9=Y,h'QbhV``q6[`ie+i(;B3ng$fdnDM/Be5Wh0&)5VQ5&/oMcU*d/=
	&aIC_&BQ*&;qT>R\lOY.#J*3%YOumo<;Y`WV#<"JZ<(Knh>:<[.`^7+-4Id!U;65p3A'-CG_d]rO$S
	uM*8c#kqL+6/^Bm?#`LHuZ7Nn7p^Vs3L0OOLRaHhE(,@"neh@;tIK5Da"$_$NSj5S3UCh\m[Dj.qG`
	YmV#kM/6+_n&?I."@Td'0*MVI=bA_]O#o1C0@Wcju\Id6".LT(A_.g8&@OShBFaVQ+^5fm,*oF*R^Z
	RMs4$GHaI\9iEYc%M-k;pu%=aKr:rNE69bi+ruI7)E-oVZ7I#kj9rmna<HdY)7PO29P%A8I\"l?a'.
	6Y,s&T>YXpCh''Cjc1XWkc!P"0I2-!eFhnOZmJiP3`47ZKh>L-O=\+I:be'Ug)3ZSX,RR.dl)0qf0i
	6\K<N+p^>J2sM]O5;g9jPd4!L5a$?A?.G>VQ@431dOBDg''T'J,ZO7k9'6Hq+!%<1aTbb9p=3JW1o1
	nf#G]6.Q5<1=L'L$nCj'O8Jds`Wi`^<*3^\[o^f@>kp86iWMnE-5u-2)ou]1<r1neO>s8IVfJ@?4`7
	CYdjVb<BA+Y`4.@uRSs0W@XH!\..d9W=j(h6mdI(=YHCFr4q\4khaK80%-Ri9kH,^"9T\_?B4j9^oi
	iLutKjO%@\B6kJ+nBLbe@>rm%YP50,:$;C7@Q%VpX/h%4A8AiP;^V@!0"hdkqe1+p'k]RtUY>PeBc!
	A_ACBa;l"pIA&`E?$M\j8V*O/O*fM103#*[[q7'Bq1&eSn2rlp*QA-?HBV'7]VfKWSD>/EtRpKlG)#
	7hlKHrE-.%;Xr`Fm9Zu0l,;BSW.4U`M:gThi7:L.>J/bPTOPr,)W+i7utgjBJ_f,CCb^[h-V9)5C`Z
	[J;:'4<4+h`KW_HC^Zp]*?ndF#_rfX"=M/>5fD-?[(t:S<,G+/snDQaE9(!N"G\$f'0`ppQSnZiB(c
	8=,L_*lH*\,>GJJ>P0VUHth+D4i3I0$K6a;L"-,<-(/:S6K0*`6R\H"mGrTJaaQ*G86)+@(_lo\G:e
	#00<,3o?^/C$KdO]eUsQgEmG.HV8hTXjiZoXVa`@c]Iu:=`4is8HS@2a]\Um(`'/p$N;nY.sTQFB2[
	slms7.Or1K+3GUc!Ib-Jt)GWaP).J<KEB5;ueGVo%`E'0X8ot*<ZdMPYecgX0keAeoB'Z0bJ!!!!j7
	8?7R6=>B
	ASCII85End
End

// Light Switch shaped checkbox, size medium with red OFF and green ON positions
// PNG: width= 144, height= 51
static Picture LightSwitchGreenOnRedOffMedium
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"\!!!!T#Qau+!;EQ1Y5eP&&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U&ID#s5u`*!]j/gC*Cg_AFjI^+Y;]eVH@Z2Mfl8oJOp`'93"cHA/mJj0KOQ)*(G=bZ5iNQ;>L&b\!
	=gLj-b(95+;,e?iXdOK198@eP"h&4]f.%h`M'0peb$oKgJ(5\>0kK9f@3;leZV2Lc/$!UE>C=L&CHo
	WS=;^-G<P]UF41TTI.L'B9\4CeqS)^\"0g?[CB<ejmi,a:i(F%mnp#C'W_DO5!Ee!ps*RL.IGYDSmT
	<I(o,0T<aV,7NdMF)<h&ieV8FB,D/+!PG'W$!tee?<R8'FRBl?Af`/a!d=H:?X=&--kaPQfZaF\/1g
	NQ)gk;LHTik,5U&.q6!Mkl)7uN`fp2Ad:rh;*>u^rl<j8njngW\^U:97g9QJ?,m/TeoG:,rO;e[pD'
	;$Y[PIsG\RP8E8sIm:tN,;e,(0dZ8Np-0XUBa1L[Q%pI&!DqL-pOSbc6*oDPU\M$"]#)FWP"N+#(q>
	pmp-LIHSSC-P=YHhb`_b\EWU!AL.KlSp1/@j4qoFX9bMAi'V*Y*'AJ7^2YeF4rI9?8N[tg-\`\FX5R
	"CHcRZP\5jK7)Fo87`0$$($h()Df4IH%DXt_h*L,[7.Kik01QK>gpod?T:F6>n%O^"i^U(YLokt#54
	cuS&YE-2H%kqfiQls4/^g3YhiTk3o[6Bqb%@stJCe+SNVRt^-f;/43Zg\JI:LL)?iIHhIJ`_Tk8Z]q
	4q'm\m!X"p>+VKR*/T<O?+VHA`EGo&24OC/h7F1>5"n\G@Eap25&#ttJhBeFbiasEhO#)Bk09@qSq$
	b8lr05Cn`.Z,gM6_6n1niuDA(@jp3&@>=Kf3kIXC#h\lWE^!:RSl%Y1ILIMs\@WiG&%-2./'q\g]s;
	?@XuS7\0.UJ4LH`gDsRP9&AF[a0=b-_cM80-VZ2D4*@^B.;"#kCtA$:$Z',0H)Z8Am.ES8*Qt*Ha=V
	Zg!%>A`%]38j#oO)e&&!k.0n`X-sNhLB&,9QJ-QT+r-3F0R`h6,%fkCpE?k?]%Yt?#*aIOTRca4X#9
	P(IBJ#3Wlb2bum]6B`&&tc0bl,T\I;(nhO!D->64fYfdi*RTF9LOeeZ/t.M31,1f*k,NAk1._&WsmP
	O+S+miSYb?H6dm<Wff-ZOil%JBc?NE/OW7d[RA(06NE$H^dct+*@b(LZ^0/J#Xj`JT4na!7krU=_Ui
	LVe4;t0NG)^jeS*sWlr,K*Uq7CSR"l:$_83quIe0%f*7c=0j'R6+S(Um.9Qb;nnB9Ej#@OQHGf2Cp0
	W4Ghs6Up,#YEN9FReA0-bo5;XNpD&ej'-g_1<[kqs:YSW=Tgl**1H62S+A9\q"^Z"qD#(%m)a1&:qA
	:q*>ifNkl"a$lu+eE&O2BjBGhmHKqpoZ\gZD?4pIi+_oRZes.aeW9XF[1B/34qn9[+$1O0=$1.'H\]
	"W#W@Doub#O'+SX\cZ,-mBr,COVkRn\iEeoPbJO&KM%S/Gfh?bQs1.PWd;&c8eBFC,X"_(d#Uib>^"
	Ct3[QTL09c:5R\;ZGa^%U4=##fb?qih6]UG/c-jhO>`TLB#ViT6H'`am^#++J0c^>V!kZO&bLmNMDH
	T(VWq^*V;%=reEkL3=0B'1JbS(.A##u<,21l/29%IIP;P9hf`(l!qr*=O"dYS$i'$Zt!!T*'1_aQ.)
	5U7m\`4Z[NK&o'aD(<8YF%neYd1UAK2CiY77pIPA:j49D98a9+`1KH_tHBP0Omd^f6(BB!9-!V<'7!
	GPeiAdP`dj28Vrcd?##F\8502]JcTY2G'5:87]41PSp97OPC*&pd*>fl%)DE'Z*pjE-@jcck*8HC,U
	b:N?mLeFS%d(_DJsG<X8tpdFr1grgFcdCA/(&h'$*Y-n+4.n*jM<t=NQYWGc!eN$0e1\JYJ!%ldKr7
	b*G'OS0b:;,ZC.\Ze`q1s&*d#Wg\B*KHTp38D96Z(=oL>]kmPnn\Ih/dqi'[oHmoR%eng5mb]+kcrl
	K8XPkrZ3r\`C\KdjdjtP4rB4o('@XSG6OZ]M@A,qI%-Yd9NDR-\^]m-Qq!n`SF1`p>hiBa[b)DE"j,
	c8V_"K4d$d<$Q6N@DRXZ\8$^1I]<SYXNOS>Dj-D%$)_TG&$rGH;h_4M3_!?88D,30<]SU[oP-*[83n
	PD^ir"UQuOf/'u-4/Ja8.HhRLGmYH`<&M4b+W"B`1-ih&'\bu3ZruS^8.VXeoIp"aq7Yu33SX]\\M-
	rqNeVQh$\QCBu_h^2g-JWT)T52&LrOl;aL57RLK[`ic9I4P]12+9qA1;M,htK0QMGs]Ai!4,R/e/EN
	r@i`,ET@H*@Ii:0>c]bVo?YI<M5W2L!uAf,isWRSI'eGK52LY<pFCO-`*kiIN1mhS%LZc?gU=Lq9l&
	h((s'TVkL(j!?pT%GD-ND8"orm"C(T7)?HR4S\dMY@'XXAF.MRE-*o[dNJXM3/Vj?kOAYr5`cj.]B0
	'4io;UZEqZDGdOK4?+Ml:6"gkbF<2"XXhQ/;_DH8uJNZX-D7!HDK2p-=fK7pO5;u"5)8Y5cE!/U>e;
	-ci6/#ld2n&4i]@%@tY@/lBDgW%_l8c>4='e5sV[*=f]q92FYsTo;=3'K`DCTp1V'W`3WdU.Np)2g#
	(RT#RJ_8@WD)co@_pS"Me,,%ps>8"a^7RcnP[:pCtuejtKDa:"*@\F\=R5`2!(M='nBu&<^<VN1j>-
	[bpoWf@/D33QG/Y`r,JmL^fU>Oe:M-XfGO$!/UCKUQ67HTfaUT[b[p,OKA/]h(>]Qa"to@XXt`cc"9
	)OMqBp^_gLO4<&?ceS-lfGi<"P@*[\DnHiVc1:=0_#%b$%W7Z#i0'D`pk_ATGO]qpSE_`51q8OFkhB
	t,QJh/"nRe5TLZBV!E/^"IXaEr>Rqdd@u?Pr6uE&5b#nTtYbk6?<,S-RT18a\C6':;_<ghR;h<nmsC
	[M@peeo(iE[;I]WOmtZ]mH$'r(W_1X&pHFR9dAs%f;LFp/)jDS+PLs\0A%d-7<rCRX/UOu"m0F<NC)
	eqkhuKnFRTH1n?&D3G!6RLS#X#sf!![UPf@;s`Xm8hV$t6t4Rai(I8)_Yno4aZU_Ga74H::%!DF7iB
	OKUM`KGl0Ib9@*j?BV>_^'\prSOo9IBmm#kP`@"Q"MfcKf[u:N,[Ejm[VafmZ4n6pa.@T@`5.j\@q.
	l(,'2nUHgbN5[6tW3\jD<E1&;g1Ode2/Nu1q);"Aju3(G9#b?Ar4"Jq)V6qXbGV35[pWmaq5XV"h<N
	*;o."\f]UCRU8fQ4W1nBhG;/ptadOXClU-/J\`V(sN2spKM#&+ttS@P"ZK6_Q;:8k4:TS?uQ;21FqW
	AfuJu2`.tDua_@kJ8alUtGFUO%FGJmj2Od:Gf=AtLcfZ6Y="LJ0.3AOi<CQ'`*BD--'Cq5g'@<M0Lf
	B''\,m18fhBt/I3&ifiN7E$XanEi:$=4(AG?/"^>j?Oh)uAt)KobN=6(PPifHp,;C%E"'bk6rlc>1]
	Knf7f%?lSSE-tL==p?"[O4?(H$js[lgbd:<k<G"1romcc:/6a&*,!IV;Ujb']W*\dQ!]^`YN$J]1+n
	,1gEIif^J=c^>k[2[&P6O1@u0UDX.,tH>TE$6.XF[bZ"5+C=r;-An)l-`Q#`ab2/)%`l/8eKl`/4SG
	lHbo'+R$UN3Kb12--W8Y3S!cH\Q6>ZD!\IXQ/Pno\jGu+An(-A&s](b"F1gn,)kAn&_X=A&uH6=WYB
	tB`V^X%i:!`DrW:QS32VY!$a[iqVM+'>6o_`X[\m#FQgF`d'5?#ZkG[DPXp1n5/im]Q$0_?O0ZTHYc
	e[^G(Q?*f&"9RlBndd\L&:ecNhOp!^kPeBZrd?PV3C(?:0B+hSMd[jIiN?NI:Oi6qu-$ljFfrVcEOt
	,$.D4&rVS"[Zq/\SkEKs"%EJ%.?O\rH'fJ!I*hWdrPa3YR9m8>C;=#4RqttL`BK?O7o5j'ZK#=[=cY
	!#!O24>.,mn^MRp.T[4!rWHcjf;Fr2U!Y3U>AgGu1@"1kWkb'tZ,hN[j.I4oti9e*_kr-aA"H;7P1^
	@+:&5Eln&Z'>/S(ci748TeZ0Na*8'>'Jq%io@^":D:SFY[k*:%]M4%gbgK03HA%dM`V?*h6rOf[&U*
	&;UAEYT,)L&d8=Ff>^iQ7-u8Nja#3J$cHk3WWP0g`,4'DkeZt),SjS/iPN;_#:MJ9\7>'_9V)=gpN<
	9'iP&ktJCDIaW-]@`N5Q,_Q]h6fKrSd2TLM]3M3MsqpY,)<8*]=P(!/dGi(\!+adq^gVS8f15jcW&5
	^pkScePUJ:9VaY5fOeXZXHTcL?;oq&:YD.!$PP\i8e^C/:V,Y&*_*e"T[(blRHe_*HoR>MSC8(VihO
	*LCN;'(KZ8f-1ifjahRWE/A)YLg%*;'&^@1r#:JW%0P&h,J-pD4A3_Xs*.HBu?J,3DnOKC8@]XTFkC
	.O1?Dr+a3s1Se\A0@J'!I3RW(GK0\LlB<#NrSYd!2cdKF$0Jf#rjrcI'g=!V_TIMh;.a4:7[i.YBdf
	gVjB5B?[VC_#pUWQ0!fXLT2UU(E]L6$BcBMa+<?]87f*[!F<-47q[l4;aSXM8Ne)oh+QJ<L$)Eub.6
	7QG`Y:_%p![D#s17Ib'2SuradpN8R`nuS]u;NTr;QH.X`,UpoIKE8!!,bp<Q3.hgY:J1N;;28CCC@&
	q;1kQ=C.O2@!_V(mg<U0f(.Cun@=#H3]GfAn%EGCmp3Z/9:[WBo!/hqr/Ob$/ad1$;NA:F_f:,(=bb
	CDWC;g@?[j(nOg(/$P#$MlQ8(kS`,d_cH.)$Ap[018UBXS5D/<$.@Z<'_&jAX0`[!lI_hg!0D%OEH9
	[Q@2iAGJCD,qSJlaX0`\kpJ'dgXDI4oslDLTgcN%H6q?NV`:E<3MPLWc@TlDu-NQRAL:]cTr4N6nYU
	4g,Jmc4!:7Z[6/^"n?>lX(rU<jF_D]>HZ\;_IJbf,'om3]/,@X/'M.-JNfQ'q0ks'9$T+TMT)hA,o6
	g(`a]ojc%&dZC<*8sX.>Nje;D`q+ACQs/8TZ\P%;^L$7fPLYY"jClWPN44Vl%:-B&Z#b7KHN\g*"7m
	f4)#CSWrqthR5#f0Qr(bXn$*_2f@EtI,o5?/=0">b]:8TPK`XoSCcQ-0O<`+[+T98J&$X25Rgp\I_!
	s*=Rak@8i#JXjK6nFNW4+bHr),8Zqa$?3r9#XWeq6;VggZ2au?Elhta3dN8mJs#np&GnQ?RqLL9#m%
	!Q5GCh52E,cF+u4Q;CK19k`ps!DU?Z[+,o4R7WgeR!]n8^gi]-0l8:7ILm5U,"Xs\d9[hRUhWCq%DC
	Bl1(kQZO.n]<FjNU1GGo^mYr?THlpXrJWR\Nb"LXU:&67G7i:i[__rjc$?WpU<,[2%_C&TQ^uA-fHe
	+%s:P*K8kFW5e\ML<5l?;`</pKahWY#/)&Agmr-TW,_Bom>#UN#@`q<3s74X<_L^S-Ab%E\t'^dlR4
	*MB<bDq^jp`;^ojEtr%mp3!)aM^/gH1JR(pI2%Bt/ph4T>rA>2H"tAugQWUM<%4=`8X;?;g#dc4CaB
	hnr,7>j!!!!j78?7R6=>B
	ASCII85End
End

// Courtesy of Jon Weeks at Wavemetrics
// PNG: width= 150, height= 60
static Picture RockerRedOnGreenOffMedium
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"b!!!!]#Qau+!"7l;4TGH^&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U&d:ip5u`*!bro?n>X`i!<7Us6l1sT^O$+gr#(OHuB3B'e"VIJ'2CfIe9*eWDq1T&(b"?qE6<`meO
	Ea&80>+!kj97d=^_.iC+Mj)$?"/aD]T-'$K*RIX1HdlWh=pWV<H[k/4jBPP4`g(okuMh8=ZnWjcTP:
	kqp_S`I."Q.cC?oDCc6tY:`9mB.<YXfq,=1do`oEj\FJ^NDk9(:1.`*H,bjk^M!0O/?9!E3\/C.`q#
	:6h@2LJj&@"?+!2-`;1`Dm*oA_q$]^simYBc^@SfRumYp;mn?G+p_j2Hom^\HfHHG*W"'d?CK:LCVN
	Thj4mg=k)X=0(=80L%dOk007mZA9m#I.EP(?Fb4EelQ4,<JcW%e7uC/hRn-n`!J4DV0r!iB4$&V`D8
	\nV!>N);%uGr'Epd1I[m%&?W^FoG.VIW<lLr#dTW-dE?(T3Fm@Va@oCHA86jdFm'G$D:She%lDq,>C
	:1*DY;4*I@FJCe]6<ScR5<tk,'$tULb';k2^4D1!J&/.`K*4ZBR+m6&f1S!0rD?:Ef,ZM'EQ#2bEq\
	Q\Pj4X,+^l?m]jeR1I!@c!.].)Z*@^bX^N&]XVkVA91rpDSi&=+o_@7SGI'r$M!]A4C23%IpYP4Z]2
	cBI!0'J.kg?.*@&U*J5KGBr+*t!S3)66rpu$c8N"QsU8Ko>s(37^F=t_EXXK8M5Y$71*5nH@:`\ob7
	/S==[/n<+-Bd+0VPS=6'e66Rg#=V-u?*Dk>/Zm/^+[fA4NHeHl([]!j[/EdAF*!r9ER$(32H2mPd</
	a@o;WE^oF\3J]A9W)j8koSWu6T1F'nh8HB]o;#l?.k!@T(iNuXTKIf,nQ^1AYDGAJQsigf1DTsa;VO
	X;Qq7KNiXDbr1&a1/Ob77;[Y<N6TT!?cnXjIB"?:%bLPUI'KSP/qYJO<Xt",GOZ(K>0:X:b&;7Ro@-
	?+rUJ@rar4[rU577V[H/&o/4;fTEJ'o$31&;J0T%6(MFlB&mLc%s74pb:S'[+L`$f6\$q@#m?Vgr"M
	bUT+W+^s>-0_SKS]"jBB@-m8^7\kL&`5Cj.f*T0.uB7gL'\eZ`*sh]6$X$^FtJ+,![WSHfW8?4RkhQ
	?LO*.-[KW>j7g=abn0q]K"*\7*r,QWQQCHdW*CjLPh(%rhK2Dp&-3E?r40AWUIVXK.b4$@3rJq-_%h
	Jp!8@8#H].q*(r.E4JmS=aq"QK+4l.N^'LM`DN>pJ&>m_UMO<bt6E;oJ_Ii3uLc>4-@,j1)WVi#FIJ
	/2U@fWR[bl/q-*dTWcVT1DnXpS,D-#geUl<NWeC=Y2J_3h=Q>VfR#kj"EMJ/gARCq"J\#T%7/&X=*G
	r9VkFZFHbdHb"["W8i,#!7mI2/;18bE\Z],;"0>>^4ojNf'juu;Df7/.[p#p0c-<dQ/<j!tFBp>pFf
	e[`PYhKY!/:$=]rCF6U"4O"@m^o,OpK)W`/"CBU)SiWZ&+;DK;?g[,*GM1E3;g##QT[7nAETU#^o\7
	='BC9PY>!\&K$-5MC9(UNl1YK0G&1(U&e'qfJZ*"/_p.\!AKG>RIB$r%3Nds9q%1kM8M>m?KcKq;Vo
	?F,=I$$Z@j+W0:WaZa@7T2&>\IsV3J)_.npYM2(N,6(dNuBLER6%m5k:j@^k+B>0Cg8-Scq_U.PEQ&
	3Su&qB2U[U)j\8\:'+!'"O$4M!9s^$uW5Ert'_H"!mpcYV5n[^jlQ<!(()Ncq57O=:JgO,'H#<,Y<*
	Hne0=qR[7uRLg_._Zk*i(;VjnpZf(4-'uO(Fa23#3h2.k$]</^$%T/o8Ee(8;=U5)K=Pjo5RZ\p>U*
	PV,'X[oJ4amaBY1-nl%#qL?1aSllg\%@9(b;++#Df4X\ZV.d;FE>R\>PsDm[qrBO.(lHE%.a[T)p&!
	ZY(*J=pCgf<3"^;@(4=!\@q83!d)mj:JM6?"s%.1qbp-\Kp)Q<%1j*$C:/N4U(9C&[TY8NVR7OS%mG
	4S&IQL8#S:W]B0#-8eVW<gVWlUsm!h1haL)Y[(_UtEW!a1?_4[ij;NfV6kA<pe7-0#FXOV^=aU/._$
	-rS;aX7)^bpZu?U*8_oI4#D]Z$*a]de(nkA#kRQ&gSp.&'`FAJ1qB:Z-CS>QC1^5\q-XgqCHG@RrKF
	oc-7:*g!<:R^Hbsu:/5DB*CPkH\D-Bl5B5]Xl-j3?&HE%Y.>O?<.A`97d:bB!jsgt/(O:P,gF\2R#L
	9PePDGAId9?S6a$7S9r1kl86qXGP$277^falWK.V5t`9$XtJKgrESLAH50Sn"JaKj&7m_@_B&E<$']
	\I(]>R\jK*GNkpMI'6H)>nTg^'1J$4.q34U9L_+BKd20*l>LNV8LZ1?;[d1W+m`1t[+:Lc.LZ_#;Mu
	If51g>T>3g(8RuK$"cUmCFD)Rl,0,S5nYqm/oL'jp8_n[&)pfJBRKt6Vj(sI:r!^315C:-OJ68QLk/
	pc%gUA_>;*3raM'rl0-P_@mU2`<Q``Brl.k-P[39jVah$5(=YKm"+L=ogfHoX)u*Knq]C0p*J2hVO9
	WTc&P*Lb2742ND_\%`ZA*Bq]5o0Wbs'2"_6P##*6(.P3KR)%0DDpYj8I[@(H^NQW+n`_8j16'g\Z\\
	)5te`h2BN7af[R*posW\IXR!,/jrG/;o-$j/l8NK"CZW1dP$kK"hklMtHl8?K:=9T+U\Bq!b\O>/XG
	?YGm,m&](e$^FUo>?c8COF,,@K:P.F'+4i6h/6FRe\TO#s#<O^>3jGX9tQ1%i@+&1*NK<qY(DJr_GM
	/>+Z0]KG(q.GJhafKQDWoFP![e5;@?H[37q;A?()Y'(7I"E`Ik$(CZP,<@A.gXAo_oI2duiMWp=P;3
	iuF54%Mc:5\^>[A"h;eWY8p%FZLO)odrY9Pd8U#Vl-G6,>f.XBVEQ-]=W8"XCIZIj3u)coT@j%d(1c
	0#f9,f"Ug<`b70nWMQ3W!r^Le]mGo:2SES>%U'$"T@2Q$\MTsC?+iMa@`-oE\p;&`0RYA9dE,_U8=9
	h-G5X_/<a1;G$>V+[ag,aWVE330A6lG1#eS5O3LH(;g8ZWQ5_'X4':eD0T/!N=W<YhQHg@*E=%n6rI
	7$ZE]hO^:/XdXA>+bj#N*QOS:R]<sfkdp3Il=t3u0kPhR.AtN'4Rg/YoQ4(Pkkk@aA&iVB@2PHD=$d
	W)6-c^(^1Y&`eXVSUd;!k:"Kq&k9a49%ebEU8l07H+NB-lgkBZ[jo/Tc>WiCd`N3QVB)#tYsWTq5,W
	gko)\9@:cSqU]hXiFD[#65t=IG_p<8L\`HNeft4[+ds;WqQUlPZaD*.aGRnE+I8gA4K+ZCt^2>[(@2
	ujC#Q>Wj7_B"tPLQ)5fJ*Pqt4dQYAi.6<,X+(blECfdMa`).R/S6m;uUcpFt$;ILCp/1b<:/I\qY+V
	u4/EhY\WSf0<k*QPE-95Ep??DGmb/MV\CIG[#UWXijHEsGA*<+dj9XGY$u&S:"%&[O.s!Xl16HSi9n
	$973W(u!rper5R(\$3t.X9lsC)IQsT7a/`L-VXDVONt's3!]n5<*?E:ad@.Jm%aZ*2\;%;L#s*1s0o
	"cfuZ:b(4rYAKOLA/#MI->,7=r`,E_^4K$cosNQ`qR6tGKI@Ai?:4#4=\<Z]7r8?M"0DMcPenR6V,Q
	)eaC`7YZ9TrCdk:c2Q2[#=k_^q+lt&?N3b!/TYp=0AmqT,?'E3*9#2s#bTZZu5FP?USX,6bE"`e$NI
	L0r6acb,p4\B5\e1NAm@^QPs!h4'!r?XuYRMk9)>"C#M@`q_;jE6"W)W/Hc&8_?O.V/YdsDrZJ1K+5
	;TS84;$W53(Bp1GG!YhT2W9!J;Q)@Gq5;+X8U4Am&5-^;a?I1!gGrWtL_(qQ(Hua()iUo7^dQ#[s&2
	O,J\l?t)>g'Wa-3KN+eFIPHjX4kdHmbA@#o/=!ai+p"MqmBb/m1VW<nXZ>F#b*#AeUln(Y?fRgt1+L
	#KA;;j(9fgTec3;,6"RUW:M+N.Zchl^[0<Y<RWpiG#@2cMJSS.reRA#Mj45a"KG$'i/RdK<3QS2XVG
	tiP&ih_m.$"qQ^osnn8gLO$;Z-0nqr,q=@i>,3c8pM[Eo$gI-)CdZm28&nTmALth&RV[56nkmU\@@H
	NLq(*FB76o(36U,4J,n8l:2$Qh^9mOjcki)%cOnIfg?S.<^C)B@_ANt6\k0YmIUTT;)`JC+F1k_^/Y
	=kR[;`?3\IZ)O/b"C2QbWKDj5]u`^$p%_NS=?ZIJV9^c8N]U;%Nj_F8rK7LFYU&&kiH4GS$$UdepT:
	;s@4J6Z110&8ZR!E>lC2$^M/$'K"F1LXkA>>"JSR=.c(4k!,&4mlo)Zl6_-!dh*2npk4hLB*`-,Rj5
	")l0%N,3kG*q6^Q?u6:@mY[EoH_\mK\@'a^$:Z5p>cBf;;GCT26#GKZCr=CKj9d#GZ$mE*2qeij4&J
	.)t5*ND'a@6H/P+`UDRg?rd$j).o+39S-jF^Ff05F;cb-A^Sn8,?+1_qSW\k?Mt-\0S"HbY18.99`D
	f=K"+,-K4K-pspU;MtFI[#^$:"!n%'+J4[Po`#_bA(pSc)h7eh?%=_;@fC;!G(%/XYCG4$7*)`1;;%
	uIPg'83M^/Jt"Mf+FR7!'UX>PiinpO*17W_[WVc!hCF,h.ilD75Ta1"UuD:juk__JpS$*0O99Jd@5_
	dPTJ,RgW;O&9/Ue:`Rq=c8942Q16qlfQ.?e(r[=^(^%bt,E?W$l^SZ>Wut:W.uG([KUiC60!K,Ikdd
	9WPpBKp6\9uSXmI\C*9,0Jp:QQ-f.2co('FZuChdu_GBHM,l=/cn6bL"E$3Wq`oQ(>6NkXPS84b.dc
	&>.Eh(kn^#!'U^7mP[KgTh7gKg?.K!JBa0'Km3U;QWF"7QsYa-ib7f9`o'ZRXdYb%i>i\6o@I2e/E[
	*[-p`=-g'DKqM)6<hD@R!75`,.PZC.\2?`)CL]eS>/,0V;h"/1HR@,:A7,F&[RLKNg-NF,Jl?9eZbF
	2TT0USic2#a9/>^)'r4X73]fON-1kE7>.#pB9l%)R@8mVTt_8'DN@a'+\pT90ce^_gmsf_b]ij><q?
	DBdhC(c-$]RfKU*9F7.+^EEkm>l0P<I",]K)KUmFrQVO'n)N/r96_XTdp.W\$tU\ghmEg/)+70XAD5
	ee&].<A[T9U1qX8l-P"OPG"Me="m<5hh^$.Y+oS8Jko$AU--\suRiJXBWpP`C[fB\KhI'dErN/3G!h
	-,X"lm%"jEU-DkgMe#!#S9mPc$EGIopcp4J0apK8P_>Ce\fV6Y8:0:@Mj];>n3Cr'0eHR2Bi=qI=M8
	RfbA,tTL'gY\=>`k>&1J%`#*R\'om-u)mQ+caq]-EQ;a6L_Prirmg<]`BXTYEQtqqt,Ra?VT)"Z33*
	!#/`k2]eksTr/f[okFqu21pqtBEhGOH#"<YqLtrrEQ2T''*:(N!>R"t)r0X/i;3;aD_q)dsSpXt0A'
	s$Yt-!qcg;>51%/[r:/A[9=>-"527-F*C<SWge9EE+R;8X]r7ur:!(35>L.Jm^[E%b\+t9g?nUVb"@
	gBFrdnLWg9!<Q^=%[VbkO[g@p$%M(Mb0=0GuG5.DQB5B+nL='$Jnr:(bTNoOBTEokbG5IJ#8Ir9.A0
	lqR6SND&^Wi!<G,.6"9n#rgo]_0i[lg*l%2Jc*aiq_c02r19aSp0(?p[c]q2sG6,<"D4kE%Z"@GOOD
	=X&gmK_>!o)V'Y_t=C#3\s8D[DY#J*Do_eOVfg-e"gMahIa)N*><G=e<$PtF+B5!&jCRr)Vh"Ub+hK
	YgGC:.4sM[fF4?[ochf2$eOJ,/2mn)(lU'b<JPikiRL9/!uC[7jqVq.6nc*5'Y+&7!gMIJS&80)l;j
	@(FA86i^Hl!!!!j78?7R6=>B
	ASCII85End
End


// PNG: width= 150, height= 60
static Picture RockerGreenOnMedium
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"b!!!!]#Qau+!"7l;4TGH^&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U#pi/25u`*!m@E!M'?_9/^V0CXa-Qp=P6ApZ85Or31.e;`;#uQ1KIYj+3C6aB:[jNs!/,S_3_p%S"
	oa*G3Ci'4$0t!R&rhDi$'bcCM.72H^;WipgZcV1A_G`^lYgC)D:>*gfi`[9bkdfsmkQ\ZE:rMH.p&l
	q3Z[FU]6E]jP=_m$qtBDF+u(c*J.SPL4*0PCH<mXRX4=5njhck3`F=_!W7U9UH>73;m<0`8Ci=6Arq
	onLVUOdO3o+\_ENP\$Se_Gp]j>&QT:_arab`K^QS2^sMXoihjRi*:ldr=5V,Fe.MT+T'daIs_kLJSQ
	jQ-""f1/>$hnFMsBNZsSMoB-hT2.$K%Lr\q_0WeTk[&oR6AY>\?+bFPjN3UA-7pc")"-1oIt)?RDJa
	5"+mmOD2e-?->1)C#+G9`F,Y@j,$imRaO,o>dH1GKiG8DF->-3gGO))^Z4T>-G@pJ&_c/uELf<h8#M
	I*Kq:ak7t\_V.#'EK>E9V+Co(*TALWR*S6Z.S[2cZ)[:6m@IU6G:Ar#lq?8W?SB-ghq<]&pa$,"[ZZ
	NQd_uH!)fd1h1)OLb;+L$&;'4Pm<6+N[hhp3?j6f>_Vm2O8SXUObI<N`PtJ`;q%=hp&-s-@i#Zf$A6
	H(el\LE>O%6CjNupSiYM7[\f@SW`hl@_=YZrebJ$\&$2sKGXe`uELXq@,q@OE4Xdl29L('#1VQu)#*
	f7&ql,2!Zq/Wg`9;A%$25Qh'/&OMB%V[36YGX;udMX]rX=)Zs.M>Osk5X42LQ^(B(A>O1=ec:4saS=
	n9.br_1!J&jQba(=kqaF$_rU>Ra9RCQc>b:cSN7_WShGEL[6ujIeMj_;ZG57ta/\/Mp*RnCkD_r@ig
	l)[M^\a5%-7NgELnsB.Ub'?B!$Zqh!M:S.GJq=X37JOq3o[>-+7^p;RETTm^KGs":8.:.T78VEalR[
	<KR0^*foL&$gt^ZfJ1pRKasG#9jksSZ!5d^!iVrE=EiE$lqW!n=S0_7Nq4Y?g5AY**67?`N\$d3Wp1
	>6lQVRYG!-A4p!ji)D#Z)2UVPo:N*[3LmZinem84Oe[5Rrmj]Y"XQR7q5i0ABO]!s#aDf.=WLJPh,$
	Z0DS/`QII>jn3p+3TukAV,QT&]jCIP$lE<QeS;Kqc/l2k"C&L?TKfAHdf^!XU@+XI^eLJg#U4d<";s
	HK+;,4lkV];W&,J#G\mgc:pke79J#C.qZY<];F/'V06i[3-bA/Mq9'l:,fZ+a/5eGj\Y!St[J-5j[a
	:.,oPD++V+H]Aq.>hY+"@7PZ5nF#%J[toPKKr%A-r<s35$sa%Ba=]4A(0"HX'W6qX>O`%e%t^J$4DQ
	>/)!EY`&-SLR]_$%03s\'=1b;0X/Z+l+fj%7CV/krC[g8;_LMOZ$NP\bi"Wu+IB&V68cW@2qmrOPQ)
	7-oGVJDV@iugMn$OM;_='>1iLUBV?R?<iN+PSRC/nkR0E>(.]"Ylg!3oYm_Cl_,$9AU1hd>':e@."%
	efO#U.YRm3TsTAHT0<:kE-+)7/829qm4N)!*bMnJWGlE["TSUTJ0@HRP=Qt+1^"3OQk"g:h**;/5Oh
	17V*%rTVAaRk,%*?_)Q&6cb>rhF+UdB7E-^/)fi''7\/pbb56,f_6EbDL$G&gm]_91GVX3MDaB+)Z;
	.q&^>jeP[n/Zj*r:&YIY.gm%`K@=_*'Le8_Z*)-8)XKZi,17[Rp%CMnrFc;D'=3>ddFCZ<$7i."ZjJ
	:.ZG7`@M)\hTsg&+B/hN^n6NE\"^bccNX-']-u]VFB[FJPII=$9&HMm@TZS;/<1laT*K/tEYU<mR@2
	ais.4]Nm"p%4m6"eeoJ[Y1N&.D`:aE<1B%'chgW&\_up8QDik#mA@.tn7F22!M?F!A!u-5FsK4\I0I
	kOXEikYZ#;NZ18cgRPj,ado+q+\VCJJTDNb]$c8I^/0L)SZt&a`aYY/MsDC>a:_?LX5C#ho*nG7R,E
	-7E]0Ce\%j+?W%a^cSiX::IYL4_%:Q$Z^c@^hVH)#bK711)cKFec/m[H\/"b/">V9:RZb:52d+;qfE
	"b+B3UGP3F1>8I;CTL(O2lkd7;!gl]D;t,X#PHDiG]Vm#_n+iq6i[e-ksOpguu'KVH`&^5YlNO^E9q
	LB'@pg,(;j#Nj6!%TeSsKs&\0AJbJ79CN,eDaKhhfnT^#oe*WJ;1#tJmT0A6u__D-I(jjOXA-p>3L5
	%[r`5%N(_k<W^V+LN>lW?iV!79W\O/n(#@sf[UM;7-i6=,ScI.KPcJZ,26q5Y'D/^U!;XFM@GL?%tY
	`h%WEoK^oQ1_(FX>?b<%h#nBNk'H4rjKbN>+;NT;3qI"MH8p4sf-b8,X71UTQ%709F50"=cr!=UEd%
	R9>F#_>.9_G4/OZYdTsi>!ZO/6LR->Cm+eWZqg7>M#,BYPNVpmn43gMZ8q5_l>X`j'(5;,BGDq!*iD
	UA[J0iB/fVGn'egM%T$U8;Q1)@'!4G+[MVY?.B@p_i!/pc;9+G2pdm-hR7oN>&9Y9Ebl/Ka*SPSO)=
	pNUDa86[No)KNF2Ye/#?nJiRTj[FH8&";P28=.7i0FD.W7fUSd)]0UXdIAYL;lV/;+W6c^=Jd+@Lol
	DQhA'_IMX.$rd2%%a`[uhID18V!Ll7<\(*?+A?XgS0`9HT?NfknnU0#p#LF)uCA)]OTj#2OVgSjoKk
	V+L&t4.FLSlCKtT_W11=U;HZnhr?3?H5pC&@H#b;=1GgT',0)B/seqt1o&CnXKAV`Z8RjkWF&UQQV+
	)J-A-)qr_LMKf->An1GcO*2<+6'mbG@J'fS$/E*n;h#bfl6kND"M5(&/JF#l092)6q]'q[X9L3p^\4
	?b_aW5#[M])(jN4+o"bQ:FD6e71l:io20YI,V23\+IYY`Pm2um\,^(5'ZQ^mkGT97GOQ36[4nt4am0
	+qf=^sE9"qIgf+[^NugI4(M@An/!UGciS\mkPKBV4Xo8db2P3*83$jRb!!!!j78?7R6=>B
	ASCII85End
End

// PNG: width= 150, height= 40
static Picture RockerGreenOnShort
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"b!!!!I#Qau+!0a1BYQ+Y'&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U#HLEa5u`*!c!9"='NZ.Ok-C2a,h_O%ZH6q,ekORt:b`eo'UkA?Krodo+W(8QrrCr(&:BX)Ljt!E(
	9+ZZ@LAEq:oL%<5U3\I5a&;<k$m+^p6rO_5"ls*kNp@X2`%[&!h",Lq)i;=kI[<AiTB=d042Fu/si8
	SS3;3WO[oTV!OI(3`f2KMXrJH&+[cbK%?6F0o/pqLMoB-J&C>P?+j0!>$%bDJ0q5MUZ^[GR#WVm(o&
	Rn_NuhHKgUD+!e*0c0KFl\ih*!VQjnJYsk2tggldr=[UQT26H@":[MPHrAZa7!kCj'5qTiG5g91qoN
	92ebfUSFRa0JYDH:8]0rG`^87>8<FFA29RsV+[0!AfqZKmHrGH4eL&)ACuR<laj6?*%-Uf!;,sWSNh
	V<ea]$Zg=iQF7O!t:3k_c%nE.t7KX@#0Q##!SRFf8_E+38X2_%C^lC4OD/!3BDZMaLf@t_e>`PoH5n
	!_ilT.cI%D/=#2jE,Ne;*BLR"G=Nq/r,Mm!9%m!'Lb;!_Vm1DJfk>8kN(^bM\e$c!p_.:euMei**;#
	3XfH+l9&6f[b;blf<i``mF`_`0SV3).XbIK+M+"H2Cc;1:`e"m/K`d#2"c1$H#/oGM-QiKR,9R$=5s
	QWe'OW,M:*^I^s49HWj`5N'.u4WM$4C.g'CeI='VbFg;>BkP>6&p=qie['f*k-5aL>N+920PUHQ)tQ
	rHqBZPF=U(j':Qubfiaf?QXVf<E0$$>?`o]L.uBYrR1>f1sbcZB*EfhXnL$6fn$?:GCo?[0X?:mj2n
	H3PW0:">[6H&K-/V=K[(+nr6?D(b-+OkNB+h1$P.FdGARg=r[pC$T'Ph4VYW/Eo1/bqE6sW,8thtn)
	V\%d\BjPdSY?Qs1PG`;!C/-"@W+hJ;Wp2g]em]h:%+H!./8M[:t2?r+8>iOkOVRL"Gd)K!FPok!%LK
	R*%>kq!)P[N#LEL1O$B8QnW8&#q\'Zm&HDfJcTdId'P9+g@^.<aD(.=Bk[cmmNktb_'`d<8\ZMtcEC
	ap:*"?IZl0n(r-8RL9f9+WVPcFgAU@>Xae?2$H6_9N%;WLE;"-nKKi&#uYKN*fBD&B=,lS>uu^Z:=8
	DqjmuLWZ=h&c#&k?n<"8$^JVe*?f/lm>fYA$l4QIC:.6I.Z+j9,5`q:r]:mM@O+\pJ>'2JX82_nfO$
	@^h4C-od50GX!3D_GV.lC<CO@:(YTjSW3^]IR:cLR"4:FI,PQ7u7h)#RTkV-Q4Q5tqXNWMI.*iJkPi
	NRCR4JjfraT+RW(/)uL>8<8mV6%2a<1<gcri?!!>EqP]Z/h8gApPSWiqSl#X\.W!^=@%qfr,fqc_]f
	.'dZEa2*k;5Ff[!,CMPn4X;+/7Md<.B=;74B\#o]o7urCH9]?!M543]R676/R=K0qn&hFs`F)D#lYS
	r8OcJb!S.NC>E"9K$6W1k\"BkCYj$TKjL*oWL'e^[[To<Kq!2pjElXXJQj$5&q':bKVAVsl+6i8J08
	L]_3ZdA<7c^_PbC@mc,C_iWV5G]7%ZJ^Hfk+_@S7`+6,ETj'cXcoX586AduT?n"KJ;=KacG)KqIUsM
	dB&R`LR-a&%&qIOrm+#ra(e7O5hE*3RrmsSh]L[%1?/5I90g5pUsau]*I'SV@6?46*.gJ\L-@+V>]&
	D,OcH[C*Z&(g:4!5QFe!P<3,L1(oYI;68:itbnl'Q-4lg"AB,jp^\:p[@"k2cWjHa3@TQEc?!U<]Oo
	.BIFe,]2;"*A7VLM=f^*4nMi/cV#5hABg"UB3(lWh=5Bre,a1fA=Tj-[_%)XM,gM0B@AMfLQXq$N3`
	$U80FY_RO"3Fl0A4p*OA.\@\icf#?-#_ePAZA24iW'Hfp&CRP<s4bN#s#ZFE]#'kj7ZS4a;3Bn*?^s
	4*HTEW<+!XViq9:;s7KglNCm.W2_>T>N0+<k<tPi'V^.??Y^<MG/U=5"Dq`h3b*9q:iB"]7128T:m*
	*2/Z#1ZGKgPb64^KN]/#O:TIFu&mtG&EkTJ/<$IO%Z_hScjNeE"08.G[C(HTr1Q9o[]duK.s]g6QMk
	_Otn5.Z+?`Q@?Gl^OSk$"q%`(>3cqp-C.%MjDAJ]V8]=&3RCtBIs?64*9*&TNUnZ$b\Xuk8\.N$O+/
	?O:c.f$Gcb$T&pdG+?O[<$QGstkVAW/L(r?!2$=/0Km*\=-dp^'SFIL"!s?%<.4oYnbW$,*gIM^c:(
	<`sV=cCNCM#t3V"UMK_mH9.T6`t2#-UtCHp5mE4P3'0>4q(nkg@dTYun*2[b-?`ME[Y."QnHU-`Buo
	c^m;;KlB1<4k;J6"?.iE17c+l^&.Qmj*#2k>e!U;gj/bg.IJ;e>>A*sF`DC5(BfCX+`e/l>[CangY5
	)O!.[.TmaO1f5C`\'j\+A@m*hk.>CZ&B!-5X*m]PBlTIGhZNDX'9hn47+eZ2aW;6hb!cd,t2GgR.Hr
	VCZlT0SNMq:;ZPof^LAbM1e+Lm(#c,b6o7_YSrE5IGl#Em3T*m/R+d!(fUS7'8jaJc
	ASCII85End
End

// PNG: width= 150, height= 40
static Picture RockerRedOnGreenOffShort
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"b!!!!I#Qau+!0a1BYQ+Y'&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U$"cas5u`*!c!4Ih'A49&kMl$a:?"nZ-[&sWi"Q5%,$Jl9NG,.W8-Dn'i?8IqJsTd1'2i%3'aaPa-
	\U!94s=e#W/u7;?P$(gW1Zq&+_l\I/dl+(=m&D5mDQ8>cgC@5P/5Apl1$to;Ee7+S26bokKH0Rqep,
	aN/ipi3HM'"/4/CL^OL_q*r#JXHLp^hbNI0AX&LPS;2I\Mp[6igbNd>=U#>P<<)lACnp!8:`t:Z1k/
	bV73h8a]!Iu1PG20cXf4\L&G&:o+BPhSq+f_B8ARJn2'Lf^':8_I3G_$f6//C<di.059H[C*07RlP&
	k/PE\)O3070ekC;0eb<.gY3)9WDmVGB^#0WgUURl;,N`T-BlQA4F'hCqL$#c[Ph,cF1Ig7$qdIuWi@
	Pd0KdY`5^RkT_1Mt3*KQ6Fl07JF3#itX)B'P6Hhm4Y6JAJAY:a.oW#tp8rk?*1go*=V:N_lQs2<sf=
	=eXahE?P1naZ,g2f9J\H[:"p]mGNre(i_plJX_Jn+Y/ScQf4d5VO&9H(O'+?ndD#^i>mPF3gF@:S'\
	b$*9G/YZIT-(oFmd)b6#]`,q"P#!(mL?XLj5bj4q*3sd(lEZ$5Y*"Eq.%j*u?I.8nd!)j$I!&O`[5[
	W@V!5edE^]OlC"<bA^VnW(TkK]X.hk`iJ=F?a_n8u-F+XELI"9JU&s$mgLbfg(&^[C"R:t)'W%Y&Kp
	F?CVJmT`jr!._iA]\+Y<P]E'Sqs=+Jj6c7$21@lX!FTYW8u/oHbE^5cOWuF#)O=CDT+A88][iH4!=]
	#eor!EcTE-`3\q(i4s"qW@W%VMMi'6YbJbSU^LBQ#gfaAU">$=VUMP<L<2>AUTf#*B>.#ML$2ldLqf
	tA.fX+qddRK0"YVoO+`:Ct6VC8-safD;E;,q*M3_XFCe#!O,2$jH]^"s="]S'&'@=;;YVLdHW.[4Lq
	nq)N<to`W_`#68F$h\mS:R)rkGKn@&Tqq"5-<J-D>I*,Lj0L%cd4[#@3Ha3Y07nN"0k^Y]MeF/`%/-
	>MC;E,/$WUTXX[BKel@6c'1!OG@nKE5H](^;sM)'Js4FAY,B[]Y#6;Nt3`J_KOjp$]otEd:ZNBnV^N
	2-R&Q2hn`S^+N!?*"GclND(\[Qgm%;<*1c>78`u$C[3K33CQ:266Q?5nr,1q;%uG51XpkfTVVfC.Qh
	_1"IqG;.:I#U6jeK1Reh#"o_&>O1hp&W0Gk4!Ka0SRW%aFW!'k=8lg[oO)AUZKdpr1OqP*6<kib!U^
	/6nD&4;J,TSEb7ci7JChF=?H/DFhp;K#MlO3_.Bd&8?Y&53aZA5jKPIqi^*-d0Z,k[@U9;RA(aFo5H
	6J=`N/6eYAqo("R(HBS^'^cKA2WItpb1S/XpkQe/cbAA>E<G6DC2s`rmW;2*=P(]$rk@NG!*F`so)_
	-76qDI^;==dM/7*j6&U9GLL+s9^;UlE6OV/Rl^@)7X);(rS23]0hL\E#`]9Vc@OFLgdk"WK!"Q;r_f
	;X<uA:f`RchBAO>kT4QB6BhE8^oB^XMh7EJghsh7kUP)763OCXW#\fF!r?N>Va%Co.87\\#N>/%7,R
	aX`C3]9qI[9Q#gl'*Sh"U"(7J3YW:V"4c>\-568YdiW)MX3]QquWeqUfh<6`PJo@C3!)OdP^el0hNN
	)O]B;E+i/EH-!U^4!ML5CE7%X<u+Gg2Al00DU"PWH;)`ObcCL\8,$B<->NP/k;[6>gR2j$]:[366R>
	tR.@:QAhfIj,W[N/hM"4IA29"J@4!p2'ZF0*L3"A/N2:6W.#PP,PNaF#otH33*N.(\'quAPa^ii!0p
	qYmJ.7ubZ4p'6&8WWP]=PSD*D&,WW6<.,XKJ^pHI1WAobk0$"k5BR3-JDXmKKh<J@:0;/=WXc%Yf1N
	7(K6_1iW>-.:K+uAo^8c1fMj?UKrXi0&8.\crCefJq2u]PLo1Qc(J)#i[T%'NFW]9'foHDYs,$u-dG
	-qU3S)TbrRp!'D,">#afG%SQ0?'+ki^EN^SaWcr1#5d?q5#cL-1eZb+"tB5"oe1Z5PSXo$c8@9SHs1
	6!Mu`HGC<i%gXn=!:\?6YDekX[Q_73kS0XImRd\BCGlt53&?j$;=uNqH'S#%IJ:+,*?\"Hh/mL\H$L
	?r5e:NK7ee,.k@0]SYf>pmbZr,C#oa+#7_b8<:c=s#a-IHq<<m7d?9U,$GEEFZO6/\I@E9f.BoV`O>
	VcoZ)#<'"UJPP6blJ75@Kuee"e_CKUMg8i\s53eb]BNf39ko(VC.4/h4`#QD@b<f@AD_[J"Or^0Qk&
	-mr&!.=H[?o.@Zf%YqCDCgP46S[>5Pmj>dg*#u>g_O6g[6D0t\C\9;:iJ0KZ*.gO86UO#]-HT/,P.&
	H<S6gq",2H((B9GFX#Oa4Al(9t2RqK,TNlV2$NTnsF\B8u3IfB&qXm!7-]fhWQ.?>39'aj?Fm-JP<I
	t,_iYUr.F#l=U+]T!&u)-=a\i]k?,PVTT2=g6OF4`CabTe+PG^Z;T1_K9Ldcp09S3)].+IO%fhp!Ea
	r"r%'*!L;>_)9DSL%=1Ttn#6QB:&Rd*kj7Y`rqq%c>PH>0C#@='Q6`]e6JYbBbA-Pgm0:2\EY.N306
	F,!WMq=0Q1g#5M/TpU(CGk8339,0a)N%J/7puXr>eiS+otX[+u-k5Bk)YnDua[,Gt26X(bYnC@4Ks4
	@P"'_DZ'#/jn&s`h&0'(o<W_bb?=Z@\7W<N3]oMe%)\'bD0:!O.#$sSbVpd(1b,;m$<`[S7\_hbdV]
	N-.__Un?QVM]kk4V!:=*)`[WjnU#BPk/NEe)KXZTEhI=9qJ?(dHTV,/R>B3XT9o=W-(iPG*Q[N1T)V
	+6RfXfTnG+OpaO6H1`'"?.j01S(A=V-CEHiMs:UNukDumQ>a`!4NQ[RSK&XH$juZQQH\?!dY<=T:DE
	V>$=7K!.aCeY?*Y)5CWP&ku6@Qm/I!5j54,B_#4-.Hhu?e5K0d2];eL;F)uD(Y$?8Glkr,h//B0F*B
	eT4Qm(bCV+\=JJJ*m[Y$SeFh(q&O\Zi;gf]aUd6?dX_6+m4"#VGFSN3X?:z8OZBBY!QNJ
	ASCII85End
End

//Vertically oriented 3 position toggle switch. 3 positions plus mouse-down and disabled for each position = 9 pictures
// pictures 0,3,6 are the three toggle positions in normal state: top, middle, bottom
// pictures 1,4,7 are the  three positions with mouse depressed
// pictures 2,5,8 are the three positions with control is disabled state
// PNG: width= 432, height= 43
static Picture Toggle3PosVertTall
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!&(!!!!L#Qau+!1*IR8H8_j&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U+94u$5u`*!mChbJ?!!12QHM:4HgfL>Wksc#a_%kNF4d8PBi!K#96ODNe"[4"oKVOir[<Odq268%K
	l)N[3@&r6P1?k,h(`^Ud6r%HJ0:.]hgY#S-StGShH)*V,cV2"G0s5Q]I3c6L\lOcH#K9:\K1V/P>C*
	Vk;^LBINK],h`$7ei4aok+9\FS\5/P1J1-J_/B1!F>PRjRJI%DcZcRVhM8;/%ZXO#BWT\h=HiOQu+r
	C@]OF]2Q[GM@_F.D:Z/l(4F19%U.C%e;J:Zu)L;oj70JB6h#ACD[!c/CA'dVO#D2L2ANSr$ap1:OJ\
	!Bh5uDD_'h/m4!\&5A@>!<OGY.\Isc+=BT<[u9E/a1$b$1l+hkiDdZh'BZ<gb'fCn=^[AYLa^ZGeJE
	Pa,YEB//=sX6L?YJtn3Ml<B]p16m]F^8-uq`)j;8h1gWj^_rAIn^6m*&IW%)2t7"e)>9FLo5#UUF1D
	.)NRnJp`e<cEp#Z)%?oCbIVD6Lejl7Za=h1Tg_PcPVn1VWH7p9YV#=1`q01*c6[El;05@Wf!+3bSa'
	J#bFRY/0WRNb&;hA6P>BU!apfaTE'WlL^[Ys#`**T$,9afqAe\n]8P9Z&?1YFl$,=<Qt"=)L]@aEfR
	+\0Ic&ohf`TNNqF%<Tn[R`1HfbXN9^CrohY)@h2.9AfC8dlu;98T^jV^$RUrn+mW:eLR76J!Q-FO`!
	PYu"g#hj_t%7$/nJI!A"(na5Q-7"<:IIfJEnL`[%KD;YLofp'5nKK1Fmd=t2Di7.hopg(fqVY0?4C;
	5tqr[8b&[9NeILr!:8cXcY8^0qb.<Bdn&5oN*Q&rdC+@d7R"n#&k*4^Db4pX1gDsojg1c9>KNBn1LB
	P'e/).bgtVDLeC_FV3^EeG$H&n1:H$h!FHcLW"U@Z2H51LOf_*"8-iaF!q"4pVF/;Oa\;Jsi=$!?*.
	+&efe`G&IKa,Qr6X?ajFUU3p9/c5N<VeCSKV=d.07j7@WL(Z2fHlejGrn%\\]K;I\kjlP0/D`/J)%*
	O;&T\l(Qmbb^e]D[!GdP^K#S;K`<O-/IgbdLH?Lt##],`RXG!],Vi!M-3?,m,hH68Qp*&g7H&GqO.3
	.XV4=f&OH!^E)cl.Es\@*MnnJW$I0N+(rZp@NkdP875ns,tj\[Z^s@I>oE'K46N,T,"X)KR<S"bc*X
	Y>(djT*6n`^8&V8;*UId-Q1Grrb,(K[o!`8%sK!kS$+rI&*+bCUrIj_n'HsSn[)P:*Yf4j0Ealb5E6
	$smVZ_4M"%-$.3"4+WbIUVF0=+lkb%>Xfk+$\K5HCRmUF+<Z%0<STmiS:ap@YBoA&@S(]IZ/?u(o9,
	&NG;'nh#?6M"pAI/7*#kb'M/as.f4T7T)DM^bQgH"rVPWGcg/\ZMKP'n;lrVh&l8X>1I)(R"TS`m6t
	1oW#,m'HMW>6<B.fZ_6\nn-@qZFhb[QH(#U'C.,GMc@(Ie/4cJ&1&C/@K6$D;!GAmhaO_epi]m<bOL
	(BM_[!EtPMoXWK#M</eN3,<n:XKPR>=d.07i,dNnScsO*EJ"2?s7nm]XfXVHniSRR/ku9/m_)C[qT\
	ubmqNM9Fanm*K^eI1rVr'Z3d_6'E%k(oa7IDL<E)=af@#IC&HNJB'@iJGNj/m^U4IjqM\&=V)j)PnF
	;CHVG%*W@)Q)9LSM0-cTo(+06JY0D#pK[b[%pPUUf>CGBd<j>_dj`#@ZVqT'N5J9CbT:AkE5K[&W)=
	+9XUk_e+'6%f:Zkd0h#(]%eo=([skSV%O)4p!)urmc-4DI!6bkQrKaIO!Z2cI).NI`1DP2d*1g7rVh
	DCrkJ[3X-(HjgS2EKC6snb[s&]6sIiS*-NuicCe,ScI%j+!:S(VG(Hfr4t#Cl4Jn+V/,q0]o*l0?jN
	<g#p(md9DEYA^efh18DVQY%Tk<L"Ea1"<30&QM\.&-WURa:]^A1Bk`+'J6Si)QEq&SCugsR-_b=[$a
	XCpF!k6.3qasELrUg/-18>QjQ)NMI^6i5erL#`lo,c4fBK\"LTG..HT(\TDdS9c>h;i.k<,EBN/P$T
	@HXl(^ud77'aH2+W./G`YcD8?kEYIMl+nO^e@J7kTM&c(]^!C[_$'("f*MH'#>"'9[0Nj9Y[$D:@C)
	%COAmSYLCBlPL!ClF*@3+H&0[<7"`=KY3VXLSVI^t5'ZSTB0Z:HPq,q+F/u@BT7-FdlK[YLJ&qfk]7
	9]2@l&7<Q*7a/+(s=WM8U_uFUE8,^Ju"6%?bB=BgZJV&lXZBV-,$c,LJ%Ccg"Z[R+*5KSWD#C1fG`b
	H@,CeO%-`g8VefQZ)K$-WX8q[$E@^4RO!`XW(BZ3V6o0E)V&@TXlm)Kkc2OJ&.no5@o\L32GIkRAp%
	ZBcZ;MHhTt@@n%E@(JG]4*VLf),MHZJP;ZgeU6abLLFfSd1.!@K[3[[c=6sE_)77GH^Rs6.Qr7f!_5
	A&C7.G[7%PL&dk[C;oO\k^UTPL!ClF*@3;!8q5^ZiBIAV+]ZXf.LDrd+NLLKKoIX+917(mt;7dpu;=
	#r:ogDX&n0QhUSFki5#MXaA?ptNJ8)L5RAbd1ej-&<<,E'8V;1d0iKkr,QsA*JJX^!6R1&,(f1`W,m
	k`53WU=ZU[>0FPM$cQ+9n%VKTKZ<g4h!l)%6[+,83Kg:M::kZ+?;rjrqf&,XCd7CqP>S4)iEQ+5bE9
	S-Y%c!&0N<#g:E7]j=K7LSJ9k6=(@;=dVM(e7OH.BM"?e!18>jJqF(@F;F?L2hh>UJ/LniUo48KU,u
	V'F'SO.V=A*KlOV37AW]2mI#b<^YTtZAmZb.hB2(R&NR+$@(BM>6k%<r1Xfeg]&8&7OOn[`3rXZ=d]
	6E`#LED!?d75:XC9Q6qR"d]7)f&)RhYh<?bRoA!;[g"cW!QDMTFaMdC,0Q48Uq)7Lld]0(sT8oj;GP
	%@-"Y'7I@(Qm0WQ8Fna?3e-J;`.>;J!$"5/!`I^W99;[RNLqn[\9*c[XUD[fuPY?WI"[fc)G):Y90V
	:Jrr,_=tRY`F)=&k<;lFJ$t`fnLIba98A;iI.-\t5pFf$IAbP%laSUf.b-_`"?sW)'eGIMr3T!?`"8
	K;\:ra-Fu)Q2[['s1?rpGa'-KZ"$+6\J%c\;=Y\hfA=ccO3]cFT,o)\K<Qgr$I*[rRI>iUeBE.&l.1
	7]3/!trHmYe6Cje=8:53er8D/QA&:rQX!Am+f<'hldI*QDqWkM5YZc;0-olXNLQI'.tnTh!t[^NVfG
	'6&os#j5%55u/.r7111J%N.tp:pPZs6F?JGj3XF,.`/AI:I-9J^n`e<nGSa'F`F+]aK?Yd)JS\Et&_
	D&KGirS42Ah,l5q"qYb*(kYi#FEVXFPY83_^1o=E?\djoLAgXP+nM*F25U9qATWWI.#m_tYnn)c'8Q
	k-[K3ls[1ulK$LaXQ863@T=`#&^W^&]A9BJc/QVr%<QXf[gcSnA%jB3F@;[f.;GC?d_!LS!8<3TW]3
	G+2eb5V`<O,9h<VN1X5ZO"6hqS!uK$41@HN2h1TMs/7`cG!M^KWYJ4D'Yk8Jbm]\VC2)P-D#anK7-I
	mAnT"_aF@]uH_IjGu7C0/r80piD<0F6uW*)GPkC'H+6Tm8![]%qk-LWb3<\<'6?QS8YO/oH8cXM^Za
	kgENj*CGOIW'KMFQ$Ln95VW-+T)6G"GG\IT5n7E9g5a&B8t6<kj,X?E<i#"Q^:]p3#jhNF)ged?.Zj
	ec#7'MDnYh0L^a%Os7.iCo$@@6k<Jq0:KIe_Ge!2o:+,(r@M+SS&E.'$YVh-QKZ&ZP7S&QP2fam#Om
	D];=g8[C0B1s$rSt0XXRs]^IWoG8T2-f_]HBe3@KQn5#)HrI"GdJB7#8q6<jn)[G/1g(FMLnk=&l<_
	i0($gh?cLOkI_\.QrGrd$Pf('-E:*HQ'oT.p\+=3f@O))<kP2l&ct]u`7X4;]<')j\N'A9LTM^CF@0
	r%R>IFO)pg+XB4H&j;R80L!'nPeECrhQC6ARU+ct!DLnq2Sg+]KlUTGOn+s[<SS9H#3Oc9^VR[+J.I
	%Qc:C2Ir?i)0j7`gUJ9@2q]]-Ii62L/A]8$jg*$9^&$ghP65kqZrj>OaV4)I:_8dC/!'UJPZf\.uFB
	n:]P4I*pn/T#@A"c@&HpK6ngu!N$(pN`"U>WP]54KS60.%*=`&rUN&o*.#PU=6O<X>s5&B`CMR^pn,
	2U+^\:7aX"1s]eZY:*H67Y7nRO\L9SWFK?X:9gZ**6o8JSSUR>IqemU0f>R1Q>TO3F"8!I4]X)H=DH
	13^hE[<QAC:7fIFq)nTGMrgt=6NBb'S9n:J;'A7+K[)W&DCY^Lo>"np'R8!ZkV$:Vk0p0WlZp$-`6Z
	UTV.==7e@M0oY&50HrH'q:/1kGiO2`F-GWM7K,a"IGjE[mPXW\oW5jX6Y^nUB,&b+]te.0&E5X]4-K
	Ohk*o]l!=&p?dW2f@F'qtQB)lkcOoi?!Sr-B/>YU7&$5WI^E`"]\*$L&ac[N]]BKbWM.N3gUH@U?XU
	0P7Ku-k-Os4a4&FGB=$"b@fZ*g&u1jEQm=O&!&52h2,'s'LgWK.4StF?OeHuj.9B0*L-Q$7+'2f])H
	/311/0*m$-?)&Xk!up^Wm6?K"namUka-VK*Z=T((h_l&:gIR!4@sHPK@J#Y<RJA&,C"OInl'Nan-=g
	Vdc;>!'GT"86)k>Djjf7TdU7()ir#]I.4u,Dnius1mlVP[m0[_YLi[Le'HILIf'"\?Fm@17NmIBMe5
	kO3MFEhEK7<s.$+uOJ<?@r2tVXWjm0Y51r-Z/ad*_J7?>aWGFs8os(MGPpTD1#ekI9%1kp9DZn0PI1
	c>e!)'H:@6NI9UC3MMk\bu$kGEu9JFD2/1W^cV765'd/:pC;+b"Q1c.1HK6Wp4lm6tJEI0_9ZM1XW3
	P1[b?A9hiFIQjEdf'sW1A@'Le@!&Qr+!^NOi.I/mjY:Q<BV56sPre)$;<X8Zo:]ILtk&GcE#!J4W5T
	1SXF55IbMMeF4,t%o91IV:Q6sq<N,Y\K"bDNVg&!<>b#\dt:oRqU^j5Io1]j<-#!D#NdD,$1]W/)d#
	mJ)24-ibrrn+a+T"/_gXQUTbe&+a<m'lo1Z7"%)YVNWG1Gip]\Y;;A6D89N`J821g@dU@"(M7OEq*H
	ge/U)^N#%1'I7&5^5J7qg-m"FpiknF#9S2EJXe(6%2E<*4lnNr2>..Z&-]!o.)(^u/:8'\Y<S!uYAH
	[da))\mY4^UsO8_1T/'2+.dCG4p-HQNh_4WASf=6;4p[T4NfaKEq_EJ/HZO0i:\p`>9>Q]&^slQW>/
	]cgK*8(SBSh?<o>5.(VLq*t3J+09S4:,W:FT^9pRdW!LK&)3'TC.)1$&NO=a)OUeCZ^<RPs!;P?=)A
	/r>N6sX\WBnHRbEnM!.4-B60fDbTp,T*T9[Pjj_uOXtfr0%bi?3O##3XaEK]J6cK;d>$bNJKC4titZ
	qg>n<b$B2ZmbQ$4<ger%!9u=s+c%N`R$rT+WBQ`^e$`:$.&im?;!&a;NoU5f1h3Bk]jUs\ep9_JH(H
	8WSXj$fqVCUhk5eCj2Aqo0QVhGlW/6soMJ>'T#Wb/bLe;,I!/)pGp4-P>PB-'o,[tM=O.riRI,:0\`
	0^h0T$J8\bp9.ZB5^Lcqr+YMfR</"`PkQH@+9IZ"PC^t#Q^nNND]%une%!WRhlC8="ONio;25c$YPI
	F&bT^IH'SI2Z\+T-,:A3JJFRkhfCd%:%qi6%hVOj(`gq)5d\R<f/qD9lN1%"'Hga1E5K8MTG<W]')X
	cIlEUi012iAl(hBAhJ+IYe*^d*kF%EZ]S`L8H`5*Io#AfQM#Olu2Js5%j$1W/CJrU"9Js6A,Bf</C2
	o%^Q-8-o:C*',i3AgF:)5d'#!\GkV4&f33tE<&QS.\R.m&n>_cXRePih7tp*Ld_4@5YV8e2OgQXb9A
	U?P)()%/Ab6h.HO",&rA_kE@g2m76[31S'*=_^Us)O9G1giIe;k$Dr-GH:3#]CDIQ::g):([igR!EN
	3.4*0EsE\<AJ-=bVNg(W!X[jP@oZNJ-(6kjAYdKGCFmc3X\A?rUTQl2fE#`@@grqEXJ!IA'uuVJW$<
	.[&NbZ&$Z/8Or:#Ta6X[8c'j0S1=!fpU4=7U?Wi\?k@_-#RAjp,Tdi]82%q05dBCs=PPg<sU,p($O?
	.e.J1;\L)uTE38!K)/5%hNSodTr(I'e<\)rd5ECOD/@01$k9+tiqhBqB0XHX1Rji4X&tAicL.B!W=a
	N,^Zm(O8"^O.48dp?fWJg3Q^ueagl2K<H=A^n':e"5UVsg4[KAJfPI#)!8N;Dc$tsOH$QI>g(;"^uD
	jsb7XP$/MHQ'58V/lrETT;YVCqgYfkB:;\?pK/:&5bJ.0QH&!f-*2K&6bCIHM2D8-sELk$[@Ut]CVP
	_^_Z;N^3c)FD?ccF]rk$m<Oq!."!4[0rcSROWNRgDV1Yo#M]aYm5@m76Y9c<`OG4g3"_mMJQjHR2sP
	A.C2(-2,+`o@"'G1g-n!5dX!V4`'aSsKUQSid5`>lJ\'[tdJ9#<ETP>#6nRtGBm%3bFdNeuF&ed"Qi
	[mfgLT.UWZP2OG"E)tf<$GH.M*esMjXZjVUTee/2C3YeJBqp'h*sm`8nU!!nDr0Lh,6%_4KOAfKmPS
	k=Hcdl*]>)[gG:j?]QD'U*tnn)!sJ(_E?/eEP;,%:"Xp=EGq-Zi3i&7/;@6EdI]jqS5Q+36nB7K]*Q
	4<OH0Ko_-h6/?@mtf7d&RXf%,TuIQ/;WJ+^tq+$=d%RnNj&4IqF$_pt%/p$Z2BfY$Q+57]fr4;c+@:
	E(2DQXV2R=O!lUU.Q,l+%bs"*0F$\ibUdrO%2kAlMC1slPgYHZ4N\Q)&T2<o;G[BO%np6f2pS=2cs6
	Rp1APSWB&SliYS(27DobTBJ`=9NCK\?Bg`((OsEW@GqOt:bAnk-"a4bN=@%q;1Bf$oS0>,-8;/^^cd
	pZJk5ETNG)?ptl#a;I[aqW3hs9AJBel)1"#G(bOp>Y0[:,Oc5]qg["q%;je6&!!#U6$B!'PQD?HVI$
	j2Zg4ICp;)$I*BF)Qg)AA`9XE99Q1$.A9WY;hqg#ZBMb?%]gNJWDaL>A3^5o"#CQaU.fE4d"9S:obB
	e9U)9Z)WCfe)HR;5&A>VrH_VMQ]j`>+Ugfj#eQEPl`(q*./$U`Y$bG3k=PL8$0+6K=OmX6rp=rqJg(
	*_*BVHH+Hq7;\Nl*9^6'APg-q:tf4Ml#Oc_0WlVUGAI&Wnsc*gFchfFPdXW59c-[I&2Ka.VXo;Q=is
	bXQ?=2`/L]cJ?N]$]A5FYV3FkM+b]Z=^9MZt4<@;<Zb>2RF?0jSA@VdF<F&a1lLk$c51gl6DnZ2.lt
	tQM#"r_jMm[rFo4u/'rlQ.iSg_RAVT"V5a(66CW9I\Dkk1s`[1/JqhtbYaHMl=6?ukf&&!?Ftq=VM$
	Wm1O^c,&rT\blT-Yi>fi>lqmm<294>Q]rb0N(KhgY]g0Ac7q,cR'c-cLgam"S<]M?'ZL-ESO[4CPL"
	W)WI0N#$$#;$,?&0Z?Bl$kqb:a)f*4q_lFQ6Qb)E<6RMXi'LWkh]:g5B/Lr;i;JCr-uCB`.P&:QDW1
	RL)FcJusBMPO77O2dq+Ram\;2BgSTXR_m[DY^YK;)9IQ1L0".ci=MLgKJgn%LJ!=&/C/X.a!CLQuCI
	j,.?6:0LGtT8h$_hH=ptBb"P4%?alCEG_M&E"CP(bd"Pl^Q*-V/G*Mka`-G&LNU'YhG,C>0G.&GUfX
	uInVuK"p_Zu9H#&\999'j&;08,S58XIjMhEM6mY$S[2i5,Ek#?tQl]m&T'Q(S$Xh0o4sA9`$8Gr<T0
	mU!)H&U<6>&rH*H'cKU%F+i^L9gQ-;ndm++VtFktjZ*<3C;>EK0<)WR1BUg:r?Pnn!/Lmm0lp2+hYY
	E*ZEgdA^:o'hdcG]1I<T1LmEV7aTE":!a7ti?s(H=hpT:oR0\Y>="*VZ[jnIL;+i)N[+!HdibH"VK*
	L2]/Idm<.m-a8To7J-Fp\)kIq;TQkroi9$n,;4;+]:D2k*=L,>=?_m#UuWQ3L>"uj@-90b;);Oc/u>
	M+tPAV@Z4=;9/2k9+Si["E#FuOg?-%L>f9quTA-hnmqcnSfl2FZF_,Ojg>tsD2l_<Q-I04)gX:$3rl
	+KW>=6b<4tdsr!s8)tSeP!q9p97'J6pC]DuSm_7h6[q_Jm#s4;_>:ZFRMcU$VLVe9M9%aGOGpGBQd_
	h<p_9(TaaA7q=ZFQQj5(^l]ce:f-E==5qEr24[KP#`'%%o\L=.T'$tI>A*\E@H,#Hn`b4TfM1hud/L
	E\IkGR/;<2f]cCG1NmX(RWlKW,5EK_un[H56&^\FES?G="Z[a`MJ9b_%a:!H5SpGqP"c].^1m^RJj;
	>AqYpB?Zm9hWY[)].'_28(R<`W,qpY@"rT[aK*VP9qP_Q^YMhk_c4<>]L+e4jGOt*Y008Ne/K<?VOJ
	."7\JbAI)o)\_6ILQ5AC>'i?hV,cqXZd314WWhI8fZ@J::o+7>#WiCN_5FpEtq0[U5^#/9c\T6rsgM
	^/)(1[.)roYJ64Pft>ro%5.L:^SW_nG3#CE4[_?P,fj'BdX0:OiA)B>`Q<a"QHDH:D?\=B?Tc:..Mr
	o,0@I7:'"X-;r=(SqC1/GkoLiflTOh0g>&5]S:qE*)/V$O7*VU<E8i*55=/EiRfFYLa$EhI)[>[Wke
	&A900u-1f/OW,+pAO66mfV;\^$(j=Vg."?tRE?`gF?Q3R0>5Buq>b*#j9?r8f-fGTB>,FW]/e^l@`(
	Dg!ofsGNOC)I&O+XBHF2Dc(%9nm238(:TG2)>p)lKSO/6+"TAd`+6,)g?mlN6e2@(@08-`C7<]*9=/
	,.\G+%Gk^X^qtIiZd>a-F^"qMFQS77/H0sV23hl%[5B8ql>$4Hh,t91Mfo,GbG)i*aPcJ"D.LkTt_>
	9Mhg#(]%IJ``uX_g^W@K"("rnaK0S(GE!H2YSuK'[AnZ1in4IL78n<2:5;ld62h-?eGW0%]Z7KjDto
	)l37,IAN1jo6CU_0['#L`_b`A=lsSL3JN';cFLB.h@(!k8He>46i\68HZ7`_aZ'9V0d<?5Xt7b&YEr
	g'T'%<']tHSah@:]fa5\hfr3C#TrtX>(J,dO]c$Eu'DnL-:nK/icNK7fNCa'O6pIp_N`"5iQW[]IJF
	`"/2^uq?I.EbBgntPm,/"[5?OjDjqGFPK")2q%s2m.'kijZZ%p>nptm..$A!BQi5GgQVH8-#;4X[-d
	dkRtEOcie<Z%4EP:'*YMU;>K"ZfC>9R7lRShVEe4c?!kdFGPSn>"$=O5U*=^H0=Gg6OU(q$'bQiGOF
	W_FMdQgPASf.2JUjt7CC_sYK"gC=g/O2BC[5D3AnG.F]f^@dD.jZ@k\D64NaVToCcBOS2B8*r*C.5P
	D?]r9q4s7DHJ7\M>E9kSH%2,7c<$@WRLj7sH!(j*EBJ[QlBlVT4<O`hBS$5?';Qd3`b^WZ\ZHC'6Ji
	?9Gpsh8;2Mudg=h!ts/T9l=>(3/RMb@Tk%.R)`US0l";u9$%ZgZ^\g5p]B)B!rXEUqaH4@]"#VN0l_
	)T/.?Y6;fbT&rJf5h'+mf;&RU;Fj)-5+**O9i,Y.Tl<U$"-(f+HPI78rmo[WVP,I>@G8%n+Z^3V4[\
	H-i`.l*tlu@L!@f-0CS>sr:62h*0'Y65CSQ%5Q9[bIs(eJ?i7lMgqWaU]cV[Le8kNM]3d)]=27u!@i
	CnZm+fbSb%NUu`6;j_T#V[;j,p,O63)]#je]Pk2`E[b\li0A91b#Hs7334+"*/r&)Vkd3_e5`Gi*'_
	Zaq<g4>0D;aW^4R04H1sm"mi'7dPpo+<rsY$IS,MP5o"@8/]C;N6eo$f2V>\DgmdLla(jj84?RJ[-)
	0a7#!U-q1OghQB1da*f,Y9HO^+"8>:W:JQi/X:8k@][2;h>%?S6&+oi4_I7B-PUo3OTg(sXi:SmC-D
	bisSY)&Rt\/c*$'_t.2QC!m<i542UH+?0'QYUB;91s]/6qlJ/A27(>OdK$E8Lj,W&ckP'8YidOe$t;
	sAXI'L&=ij:E8PsU5"V5m^SdfAX+S6]Wqti"noB6,6VKo/*)7h:0hiZ1&W%]'/Kp!b'PSgdVP=C@Hs
	:/mE<Jftm\$iJ!/Pk6I2Su-%KJ9Q]P$E[HgfZ?%K[f^PGP@gJmH[Z\d!F9!sKFDLaIpEGdp3%.IaHD
	\$d@W/qbpH9K+jfL8.TO6,h]-n%FtFLECuT\%AuX\geWehS%[EH@s')>Aq:@R&ADP8d=L\nHmIabXB
	B^=\@*P=R>eZAhY9c@LV+?0WXN.ffA5q?=d^mH:eD3AF^V!_](i8.Ck"tTEQNPk^]7Q)0s+.f`QLe#
	%0kp$:_,40nDWaZlGbmg7A"[!^9W7RnUQEBmKaZ%&QTa5ucjun,4dj=%.b[.AAV/A-^>o%ZhKk4=p7
	-0q^=EU1crLS.lPCQX/PI!clu*[jTX+8m:ph&04"T$)@[XpY:Z:rj?k\gR'KVl^JHY1Z3mhb+m$*V6
	IS@RsG"l47@Rc`m)\nf2pR)MiqNX0h.:]\-OI4[aj[n,,n.2%&6*d8YDf@@]2X$BOagoA0CU>o]\V2
	iZhkg*YsHZkFK(8?bURVip-*W8l8ED+iTfo!ZH0E>Z=-c9f7dG(t:5?LhQo*9ejU68kdLDKtRU$d1N
	nk;hTrsd8rCGQ3_j9?<L<SSpBd]Yo>LO's;^G$X5GmRV=j:H/Z0#!A$k2"[Uj?i5903M]mE8lXgoBI
	.uH@kOU\a&,5du1;A#*njaf#oe1daMnT'@,5N\ej<&;WD^3Y;0^'&F6-\,'n]h+(XRU#^+KB&)lh<d
	M!E2V7R-49U1)URW0a9nU\@L:=+-)n5F>i5ZP\XA0S7AeuFBHul]niQ<!2>lBk8bk4H(,%Lccut6H:
	aYQH?DF=Iin;AbIimd.F,&rG3SS)cBUp7@uZ!Cl<GqsMtO$^mjW<hZ,1r)WH]arr$qPPo$CFd^L1Y"
	g-Ln"c)RFf8[j0rD#LYPl5>U.TAAJ12lM'$JTG@f$k/Qp4E$Zl6iaU;4eNuQ!gk;@AkYbCS7>6Q4b?
	6N8\sMJcR-qCCsnMU'?B)gX6WCp#C4<bpisr0<nDCm;,At5p_Y4UB[UQ:U_KA@9TILFQmA+nn<P2V\
	@N/fl*,MXFFD,qR$kKBWEl0bLpT<\UH>7<8[?OTTH3TTf(R"*PlM/GMPPn,Qmm,,Er`GZ^V@=i=dEW
	)f9`[GXfCZE4*P1nDn^ASNAo_hm;Hq#]mKLre]j`dr9((6*Y4e\V$(1RihE&`2A9__:J<LdEX#@f]Z
	?Ld5+A$F=VXq:c">H#]ZuFO@t!/A6o;no#%2[bK6XEe@Fk_a6QgdAM+;7J*&sI97T,Rg>?sU,;-]8s
	/'1T2V`cgZ03@^b"jGI!T/&`faG<W?S>:E]Ar't%84pVjI+-KDl3k4`f[o)]I298n.c$`i7AX;1Q-\
	%T0[!^%+Si[e;C*_:!$uC)Z)J)!+>BNW6kp7JAcRbVB$`O<i66I6dEo*>0eK<B%-HU@ag0%R8sNs[5
	-LWDeF>gk&5rR-0bX[:F?jLGP_9n#,*=(D@m[EDHc2k6'('_ua`S9ONiT>p'+nj+V:cV!$$Hm92)I#
	QCA@>@La#6&gF<fC$PS/\.7++"Q=mpSldfGAhuA(<BaKV`#jWG!UX?$.cUXbhCc9PDm)"Ga2f@D!X6
	Rk]mq5dhj`su[0kW`Ij8V0dbL]TOs")G6TDcH?k8XQ'BpRj)8QA\]D>?Maq6DQ-\Sg[j*_bo+Bs<!D
	P`>uq?1K^sp@UPl:mBI#Psne^1c+sGI#=YEnsNc_mdQ.,O7<d,k:>^gk=atfU)-c=IEVJm[R.:S0>@
	M-PttC4Q)26AC#'I+U0'_c->FJ$%pC_&e4cPVEsG7sQlH,>!])l-7?Q]BG>th)$$s1Mnp(:bq2@5`<
	l@ZTMC'%6NfURSH>*,I!J!e3h/H&jI2<Q-Sr:IP7H(1UCQ+UBZSnV(>^\>R-7la5Z=[L8ja4EG$K0i
	1hp.dj0$M`"@79MX&d1)MFq*M:[r/nZU]:8D^\l9LXN';jqSl!-Q4L`V0UYW"HJT](igf<FqC='HhA
	;M2?$9Hso$',NKp.g3IP]7fTDi504Plk,Ya[0gk0Pq/m/U<g2+2JFSbG[>kBT.9Yq#XSX3TiFS2L,4
	2*To?I1[2gTPHLdBK@633%^%$iCO@]]5V<t0l)DTM`L9#ka4.rSddelY8S*DJ`t<_=NmU+/g'6(/:6
	uZ5FG3#9g(+d&qR";R6I#=D6W5D1/MRN66^#^bdhedbreq.l5+"tkZ&M1Ck&JFl\j8s/=/b'QXtV$;
	t'PQ:h\&@nHmq/#s^o!NgSPMR<@Vn!!)M$s6W$fRO6%a[C%;)91qoh=TX,RMTB<`REt%r<>@s]S5Xr
	^5PS$8=CcM/S2ELr)qWfM6eh;=k8a*0YX0!pU;G]g3!]N__=H2ZZ+U@32>Nb"56!joQck`F[-TG%j_
	,.O+VT37n(9X4Ao>*Qf(k4PLdI'G\]bkj]lL+='j4]#0$C9CA'XWpI#;Z5<6F&1Tgp=Qhkn01[FI%V
	%Zpe'dioMuBYc'?`G/O.=1p@BbM;8`PrU.;18*SOqBBPPbRUnY"Mf1>N/1##1<<8b+LW[!-RAE0DGe
	tW`/L69I'Ve"c";6m5Bu[j-jiATI/3?"?f(bSYCA^+:AXp<eaMtnm.[Mk8Qb[eHG../CebN$XRU!Fp
	nhb7+oo^U]WUSjGUt&_b`61(bRP&;*OGXT-D.WakI[lMOh+m0!,Bo;4uX3U!K_I+&M'!DL`i^#G:Ef
	i+XrKb6j2\D7o:u1PUDFXl+GJbq1LFPI3iV8$U-mbig>B5PfQfl%FkH8BsER"?mCVd/n5Ed#0Ba15`
	FXjKSJOQ9:<;*IE/d0[#G2AqTIV;q8K!UJ1$WQ#hijV])m;o[KG?9Dr&"T&pj0H++/,+(E7/U0f2Up
	1i_Zj>?P8"o`rE'c<%\cfcQ%'ci3p9Q/u^[*?X4@nYrP)Cc]dfB%GNr-mF!+fQ"MO[@IC"Ye%:5g`W
	$:O0^1*Zc;1?XtN3+o(BZ*@$XcgD5G0oH=gr.Llg?JM7J$pn%EpMO?&pFH9skL#`6n7A@#qsk!SJ?/
	(][D6>.:FA:R2Z87:iO1E[l0"$gI-6:\tSI@b#o"bFu_;9k!9Ac(pg7=lo[2ojMd,%\\qkP@=ZW<WZ
	Z_Y2--@L\!KhCE@$e,Y$ToaOG#n<6X33NT[hlX0W%S"#nc3giYgj&o!r$rp<D'9N=qm(`JI6%A"'Qd
	[b6B5csAQ=YRn,*E^Oo@aloU&h?uY.N/,2\'fXjE&oII+S$[#Xj3oKP%]]m?f^9!\.SMW$4f-]!2kP
	cM=Q_X3C;omsMr(pK9t7)&6o0*f[-oc\;U`b=>Q+@r/$kaeS*2b<gh(@&`7O7+?lNf+>Xe^<Cn+2TW
	T'Kl_so]usHtYd&QW9?A/:I=T^bonD4D%98B;YoW@SOAkS%%m>1o&J5[s3u8$VL]AG4-r<GWLHWQk2
	rB#_Dt!Vs`qh_5G,7@SQ'`c4J+<:5Hn\[2dtp6&&8-tu=nUtLEL(1?Qt:<JZZUD5_ms^Sl%65hT<lQ
	#]<3gQp4U`e6!gX5<f0G[8OPs77d*T&+suKDGHNECSpPK<1Qs>>I57=N+3n49p>b^0,U18]cc_TZ>i
	i%X)V#7(EKh)Xa!rgMbFEdj.Xf_7EU6;>R2Q5[)CsdW#oY2@(F#S`p.0SpN8K91H!%S5D8`Y1jJ55O
	OUOJagXu\THAL`Da#VElYk8bt;JPLe?-n>Qck;_5$5<3Yjgjgp^+;pqJcNnG+[V?>C[,Nj26TAZWZ!
	/e8R_A`VikXD+#GheG2P/XjM!*KYNc4%Ss]Eg&ut"k>DeM.gEQH^E*uko<7;hu^A+jXYH,*G4[^Us"
	otI-1PLEggN`_W!Dqr=a#VE`bWl:2(pM-f5L;A^c&TkuLqQ:[AR\M:F:&m((p]U16;71.XW]r6(S*A
	FOMg2KXj!]tUV6OZlk=*!AH_.O`=s_!oE^h7)9g%;\@%'p(P`?3M-LQBW<TSM<!TdqpMJX'(5HNB,j
	>j%S=CP:F.D:&#=RQfKsMN@g<r_PgEctFlt*#F'?j.5!homnEZ/8R(\VtoiniU&Df@Fca`RRNA@+cR
	aP=rG"0[rW#Uj*e7&A6b:,G!lck/>>"cFiB!>L+>Zb:qD###.%+?=P\ppi[Qa#UlWTVC^W-o.7;VZL
	QJ'gnA6p@G$J/k5tnlru0"#Okm2kcHnSq0XM;F3u=g=YhPuh"u[C)ANju'nb.iQouV"LJ"RtMP3E^7
	O/'9,WQR(4?&)Z36-4^o2IJVje+mY!\/a;K`hZX`0`FR;_3HK*bOR*%HJg:9I0!Z!CEXjjsX^,BLuV
	$D=R]-0h*GJ[V'k?r<<g`<9]fge8p7eNcTTg@4"HY'm#'?lf=F4KZHj[gIpb>5XacT1TM9:99,6AcS
	QbU@+#M0pm0<%?Y9I1B[7Rs2*cCPs8IKN0"CHUIJ(>Iz8OZBBY!QNJ
	ASCII85End
End


// PNG: width= 324, height= 32
static Picture Toggle3PosVertMedium
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!$f!!!!A#Qau+!9KZ8B`J,5&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U++[!O5u`*!m<r-$?!2@%)YS-)463>69f7#e?*8&b@'C_H"9^VB%/^0Y!#+j(IO9<tJ([)?_dJ;gF
	uSf3e*cLa]1So_PY1&-G<"dP@4`PG9dr`39VkW:2:u)P+)WKLms!BmLGeLJn<6X3JX7]S'MpRc._)R
	UWe<%olV@O)@a9tqJ;D,iTG:F(r?f;[!'pY^0;ng*2knl=q3rd#oP/p#9DT]?;Utr3!t2(b:2-e+[d
	*#^iME\36jAY<m/DD3^dtJbj'n!AX`ff*d$MG;&HO&U"pQA!5Qa7h36O7gEP.UhE]JCOMjXhkc8G%.
	E9K7t<ACF%@ha!^T_E&I*Y;\=+[\YWoBlADQd'p0)D16K.SF8Ub_]7SG8gS<M$\TM1a!@V+;,OlR@+
	Wn5h0UeJ[2p.SCd=8?A^jOb_X3]WeuU#":CldF#qq(+WqXcaPHgE*>9rr@TGu&)@+J/H)8T!1f&M<-
	*Rr;R+nCJ#<SQRmat]3+@otW4#Tb8&tMcAY(#b"&.s9@\DL4a61n@g&Wnr%[%\F(Od&*;&WmV)&05F
	/:Ms$rip`-%.^:VJi?aUmF*L8Z/7rLc:+$PnhPodTG!)>?An6-?(i=0G.!u&G:JhXZ0i6Y$mDBX!Ln
	YOCa9mT;"+icE9Kd?#j_,DNLCMRjKg[1pHG"TCG'Gr&HYP;A5bKYLls(6T':@LLWO6jKJ""-:;[b5i
	kF>E_6o9Xh/'a)a&-u5m8.I*e:_6V0)3hFW-9qc'7UX*^`q_A0?<1AYen$hRXM!]bKhsu/jHG%fprQ
	n@&*;"Xp[?r(\umUMP]T_TJ,!f/GOt+m(t7_F0r`8.kT5J_(LrZ*,7m?19iY34fSaqWfb43Zcq_2nC
	Z6FMoitUTW03Y1#IB';h/k%+2G4/eK@\bN.Z:R`_A:-mjQj`Z@&Z"&VgmuREW@Kfd'^!S&s3MVS&'(
	)]pGpW^5,%C<J!gWaU5`O73Z=f91$RQ"De6,KY#*J.D9&$b[)Gn&,9BL?686I.#14_C,k:85Q9:P]>
	)*D3Sn(H?GR=C1I'OH^OQ:_n^12M\tdBpE&\mK7jf5j>*:)u9!]8d_\ejWK7p=o5m\*e<)kIM=egdM
	0S)p0ZH%;E/0m[kZ\P/JG!GGaK._:$Ftk=7UriZ].%k$?fruY(`<<2QV8kou'YBT]FV[qF,f\KE+m5
	L*.7IaJ0rG*_@-ocUOeeFG"]Rc"!<N(V2A-'8",[-]JEUGs5:;4>,d.jHGr^6aq4#MM&Z=9Xe:#dc&
	f\HlHgg-Iq.GD*/$#]nl/(gR[dW)oH@KLKAQ[PS8%YDLr^@)!OV#o-B>R]:Do[#B66"[@UZAL:V^u+
	Io?]@#Q4@s[8Xd7*\r_9C$Y)UL-6d/b-4bS\3VY@OZd<j"D'`dc&p$[U$)*2]gEd/f,Nbr8Md6aba$
	R]]gZe?\#d&6Jg,AQ*CRMtAb=jA)VO9#Z%0T!Dkp/c\Uln/777BLB77BU4ZDn7fU*u[jLhQhY$gJI:
	HLX\eX2G'iMf\[nO^>dH%bY%_LdSN,&76W:7RVF/mi^aY<TTHpH2Eq`PG<WsS%n3h4$9)?nB1%=oP"
	!jc[PTDO8]Wd,AhX&R,nmkDO,;jRR'4rW?a_u1b$Brd56rPaO\\l2P(&V(WZC9_sbeZ[jDX#Lts>p(
	qMWF+<mPQRT6Zq"&Os/)PVakP&Yd("noh@!!#tAF=dMI)c^U@GtMd5*YVr*)$$d[.E;123Z&8j,>+1
	OW04Ima@T!/HBJk3<CAPL!s0*kL]SfqlG`BVgq37D:I"^$DrdF\BB8p2[.sZWq!t[bk%c&84HYf;&;
	RS`4a9gKp.]T&X2G'id'X/+BA2Lm4Jt"WNtF&t34(>s6TWl1p[IUQQ1=/%`l;P0OJDg+DuKCAn%ADj
	B:o.a?i9]Q[Is:OI2cYI*,eJkVjhRXDAq8TgE)'uA-lC*Oqo/B!2q"iJ>OkPkbLq"P=ZE^-fZ976<L
	4V*^A;hqgWdtDRJjg['R2$%\^uW7&*;RP#YJf!+6"*3JU?W:"Yq/K,2Gq7ZS9o)qp^f[e)JSU^Baf9
	6F7\gLbbZm(KI#!]B'R1q/X#A-'e4B7UI6TW7KLVNCjD'r"5i.4Yam516ut?7=Xt__:0DA&P8l4Rhk
	KOU)8U#`+.)*j%A5qdNY5Lkl1i!8.<O;GtW*;beLuTT;#A!e=p(#`qDe7Iim+(]lm%orJ,kAT2lkH"
	C*=3-6MfK#2bHBi*@)AN;kCN;'J'$IESt4l"ms?X&$?Xgc%BipM<nP<\:u[ru?C_[eq=dZq'Fc%Ipn
	E83=WU^80##kX=4qV478&[4QC>p="4<o2JoR!`gV/qRXH7Kp6,6dRH_C"#dsc6>h[5QOi@=:#fV#`q
	U-`(Wn#[cEFElc'G2>QPKT-<4'a&;%<u.''djp@n8\`-OYLCIGN65n^2tj=D0J:<dAS+@&1g`'-X[;
	2#G"KOj[GC$Hmg3<mh"p8@rfrU9YO,Z<$=?=X$6.KC>_7"I3.b]Col)*l7SiM_rk.&tE9YX"o>nl8+
	Vd%%ELBHf@'RVoj;-ia;kAD#XJp?TYTErGeR%dJoP&7dsdXp7UUTR*nM+,_=n.Nf'`##te&:]s1n!n
	?i?I!U55gIQF#48'#dT&e7gE-SUrT20G4-QHGfUL"?Q,!n#_g<f9S4FHUgpHZtN^\DnbGr:9;ci3g6
	k1KXhn,;[I0QB:-gh$s<2na)s8;'Z)beSm&L^r)boKYk(7`6f3%j1=\!Nc(n^].(U2"Ts_j=&a%(p`
	:Q.3TiX!L#r=,Tn=F,5\IEoLkt,%<bfJ-Ns[h1?Ya4$[#_Ud!R`qer%Q-r]Z.>YH8Cfj:!L<Wfg/,-
	m0ullrZJ,#n[:HJ<126'BR^"mk[!%(]X&u)p"Z/H&uJoW^njX#0fIO8`u7Gb"4H?k*-#l.&nFuCFqQ
	%_33)SUsF[9qp&6$XhucGTNQ;1.S]=X.7Hg*1]c_i=WnrG+gTr[Ga&tD[G40Y!;]A!f@JOc[;@s)0o
	1Dg!2td:ToVW-T\i=+qE^g/!?_LgZj@3*oB:=@/#MN8ETuna=,GJ.Cqe'NCc8cRZH0l]^5?/u?\b4?
	&L>(I(B;!2pc!^$ZQH;U\O+Np%sQ3;1_6hth=(?,h\jt^U2]`"XE:m[.\,b?$rIW6_#Ru4%$P*B-Lt
	[SAIit''K<(-*R/>\lL^B#Ri\2S<L0eU:K`6XZA`X:&/5GXc]U)H+_"ng6n?7bfm8&+b3"KPG[n,YF
	uA(=qm.%Hjuf+R3TgAcKLfWREu&%c>pX!J.HcYC#)ERSo8/6\Ns6PZnAH>I,"5.(0RH3g5Sqsd0J#j
	]T2.tpH?FKACk`*TS;-h\VF0\[;E0R$1j?8CNanO?0Ze%3g+eLsn.nJn25k8&Lm8VLj.h6>@u]c]jX
	!nn$+\`W*^.ThDOU!HjrcS2cqS#;`&*<Z.]EH)Cr@/=%#deCX9X[iU1t#8S/h!ic_3/]X@4C%LmU"h
	PQVn4O[RDC=WshX:]V:X78tP?Cm^Us#r!knPJc($1)s7D9-[Fu=MA[3^%A+MAQ\naS5'Ph3(ua&1l$
	f7kKJ[OYlMkRGS*a+!,-tS-1:0fM549qi4T)&^[mM)?G!rC@-]Iqr505c00d"T<0_UnJ8*jtCeWdrL
	nJ0C<[9p\jFE$Her<m&/ir7C,<QQ]SqD1c7mB%JB2ac[h=#f>__!Cu4ET/Z-`\F`Ukf:%_Et+N='!n
	e2-P:C\/J=7"J4%8K;tAM"Ak3d5c^q9V(]E_S&V7eS*A^gLtO;QjG\bFaIl-*^jt'!K0kO\&M5,r=F
	RrN?8o=\hDm\\MTu(Fs6P)sjneYNf^/erMV=o*=[5tdEXl5.U&kUp+qjq`12!^cWN\9"LPZ.WcGqt*
	m,mp.rTX@12Qg:f$ci"[&u]t&9$WMEC<ei?-L=5-JX$Y:,&l*?YpsQ(8mU1;f0F<kLMbd>@hOpAK0r
	He$BGg"&J.>6<)GqH'gPb1HbUI1:_3o#'GqOP<09FuSB'T@]3k!oloN!jr8_KlQBmWU92G:pNn64?"
	fF>E-TF3uJH=qtWAb"s_)YhJP;3-"6&lEcVpk@tn6e;Lgq7Y*b-gPG]o%ch.n*;\#s\EIT?Q'!hLGR
	mZDpo7,.5E7YbG.+BP[&q^odcA5Qo>EiLPZ+Wlq/W*\N;&TDn3?Zf^C3DdThNOX2;M@Rao0<3fWUCW
	gXtD15l@XeM!==]c$";Nd8SN%([Q(I_1$U8f,AR%1/t:SsksXt)g@.LMie-SZ\l1SY-E$GF\KPNA_-
	`RZ3Jnn>RVV#hY)*PAq.7D#u;!EluF([!dS(fF337"pF&N$O&,(X*!hT`lWMNDFR)(*O*A@fUC-\US
	O5GrQAN&>N.gg5u3Y5ue^O$U=h(;.^su0qO=+KWZm8MmE^7BQ4fC!6E_f(-mg5QJRN*JnVod^ETW1C
	P[LsK##HUj^&(On>$6Q9F_Y)KAjsdE9#Z[[L(V0p9Z7s+C8gJ59&qb[AFDMfXkjt!-lU16VhZ'S`8#
	#EQ7WF,Dn/.g1cYj>!&;#-F7uVU$\9RpE/2dm+1%=hX)s[YD7`A_Z&D@iAA^%-H4+f2AfnB^&g_\[4
	ABs[glO&4si=g^\SqOgReqqK;7J[hX5qNRUibLWGi''6A2)31b7=sBQSZ:rN3A/7V'VRDA`gA^moa=
	,a,ORDEa\h&=^+:@l-i;OU+no&O@`jl<OBh<+KH2jSC.qq4i23?G!iDn)#(E#A%1pAstRaj`q3a!9T
	eLpXlD/]mD&*!@.[[5_,(S`/lMSn-+nccuZGZhRb]`%%(ljTB$sq@iI3A`KXj>VlF"SVl<X\KN(eL"
	`kGo@jou\&a<3uB62^JX^Qhb3@=u1e?"K<5X@e5EaT9n70;i'5Cd>L;IL:C>1CL9cte,Ln'7IWb+b?
	LVFQj1WZ;iW6c=D?j,Bj/ceIFV%'6b'cDUP08(Ga`YXft">LY-pB*[D!EnFbYT?gu&D;-aab/n2>P(
	:g!HpAkjH#=:4(oaMb6qf&SB!\M?GP;SrnGOHs52<l!pWd_3Ct]GAI-]K*ok:*;]p%H,YL[be8WTlt
	K?Ylb/TRPNnT1u'3q&+WZS$s@hKX,5qV.KXI+6BL7n]=ggJ*^;`[fYq9@rLG3Y8?jSo+CP5t!W4TNN
	T&b\UdJa+m0Y$XM5eA]^B@$<N=/Cs";#fcc5>-K>@P+C?gXq,G',r-LZ`h:^Z@gW_1l-54M;Re51#R
	oces[I]6_CorOKiT!81.eI!rWZ"l'eH!t<r[=E@,%ko*pMbJ+qdJ6fZfskuYafUFZ+dKRda"c1OL#p
	9mVSAlp*LJ=6&fVW"]YfC!%P!O'i8Jh&+_Uf6O4h85Y;>^L`i"tn1Nm_#Xj`bRSUmJID;;8+oqs$l?
	oVAn99]6dd,k_05nnX/M.FG]YD.$G^/i">OQtWEk>V(@KkmDiuk>KY6&$>*^7FZNN1;g^O'mGkO#b9
	H1/Xg\prI47`\hnXBS-RM-1Y620n=(_)"&eg."K#0hiUuPR:dI"'+TA">^[qSfF<2TL3,`hdVPDb,P
	jDf@Mo=hq\"pYC4nYZ`8-%%j,&k\Zn!jomnd-:93p>9]%$L(0+7b>RHY:7JFdmZ*q+/hn45W]X5=Ne
	O"`XlA#KaZE^DBg55J)+sS:N0f\Qk0Ht+p[W@bJ0*[&k8>8HYD-'chg(>L.!1M'#o]u4Z;;jN_WjD>
	4Rb<aNq#1(opI+'(qMdGk]NPe\+L$Pe'LHj8A.tSkS<Wk8<Ik`EB-pX#RKW7&X<2iiH["o5;$a3Q=5
	UU"d:701;2(88qZMY*W1q,Br<AAj&.qpXTQnb@=gMdJ9[]hZR,d8k\Eb&1o"HNcB4_;I7XUp]F\4Fi
	HK9qH_W1't*W]Z61\E61Ha%q5YV&DeZ(oeih>Z8r[?6>\^fYYkafu_f/Hf>^T99"6l`</ncC'I5ft2
	IC0ZGk[$#Om.nAS3&ldA[r/L=uj4_O1#5;oZ40#3O,/Wg<<(ZTYX>l6X<RNiEP>t9RJ!$\A1RKI=W!
	bMTM+q0!\`.Fe8$?Z9;1b+Yd)NK]\*^&*2?!UXE^2`i"Rr=7@ea5#-rVYhC<GaZR2j6-;8d&Pf,puM
	s;l`)>m<#3f'+68EI,heORhS/QI3CToU+_j47H>?;pdmF[6\^FZ'>-2Vo2Xb;b@Wr-9dY`q<+X?PJ`
	.mE#QT[.IX(cqH@>>&Xe5XD:OQqYYH5=P2BgT0b0kI4"%B(7(,N6G+S6Cq,RaYn(eYiY8jG]3I&p+.
	rTU!K=0J`eQA-RGTXjP=`%EQ#iWQsZ?"E;%%0-qa1'(e`aM:1jVN`fe=W#K!L@?IDc$V:)7-'k*`[#
	#D$rPT/5ksCa63%)6a,:fX"8/h2SBKl):u8p7ldf^X[O9hTg82BnEV%>Wk%9'U,J0sHXT;n(Bgs;ab
	Q[N-G`]1@";0.eNTN6'IspY3^\Y"'9r;uEbd_cHDQFS,G-drWfb[rs"er.[7O0fY>af]Pf5%Nq<QV7
	/r"Pd<kKnU9_g+&1cfZGs7P[Y+@1<h0PSKQg70SerCITF7+<UkFWeC0>'4&Tp1EMTY=4Ti69>A"0f6
	(5Bmsk96*t/A8naZ.7N@W&iq[^,!F3^nj]rM-om-l<]@U91Qli*)MWm>jg^Ffe*N4$qK@qYBn&J<F<
	d30B&.9Z+;MR3-.Z*DkD62o'XCO(>>3]UlBURg0?<LYqN-&e"1NAD-0Sgm1ei_0S4&eHP(R!I6iL(;
	!FoPGp9(Me/1oltc_)Kp>5=4V:"QbFcV8U7@GesQ;%PA9!U7uBic!R<B\Mdg9a0a._nC^$^&<BHC3C
	K!hS70#e45[I8QQ*=U[Vq,q(HTZc'U8Y)b!^I#"!,(Orf>W+q?XI#$+I1`m!jcuO"(8DCPN,q8B@nq
	!,Q]<e.F8RYMTjFLLKnF3-Eqg=$U8F>lFID'ft=nNgH-j-`^@s91]^'84do%^R+X86,m$P'e$droVY
	=o7Jo%P@CitG+KubVT8PaCe4iJR#kFAZ\&-,[k:fS6!5T*+%VauJhdMFWh,+nu;"#:H;P(Hg^(E^mh
	A1G9b2m^bEf/>NF;G(#o?N$MRqtp[`\2>7,9aHBfkh;$*`oCL^4a3d^$$i@LLs.,)ZS/ucWp78^4Da
	.MLW6QS(h:a`ZIVS7o.ua%$92Cr/qcMR]R'O9nT`]0kQgR/[K$Ra^lRqC:de+o:]ejs"O`-!jqn*?+
	t[@G.M+h._eQ]$p#^L$21\f2r-F0_W.GYIV,.#`oW&g?ESU[?8e@93)M-Q<iek6G6j'I8im8B.Bs#K
	[aj^;7E0?PP,m"(npX=\&?S_Zp!$FN7^]8>>?FPE'CG;oOVoR>lHN0Q)XH)W.V'.k_g43HAa]Z5,M6
	J486j,i^^i>*VR+\/^fG;I9`@S'S]d5^T]R$Z)4'u86^\PmoWjJO0797#IW[>t>C<hu5):9jH,\.9C
	2k`B"l]!L_quN-W^>-)5l"!B'dlD4SNT$*8>99"2CQ131Lm#+:.o]<eTU?R8#lm4[5Z%_.TRat2%Ua
	;P*WLnErs&dU?`N+nlSj^,]_BB.BC3k4ki\T9m#V2AO$da@HiJ_ql&Z;cDd7^OfNc@<4gk">2Ub`^-
	'DbS'X/tm,3mmBLlCHKFLJNf/#m_tB+Y+d6rskiM=Qi%1)j:Z0ZG%j[XQKs<VGauY<0M=`>(51BU7&
	K(r,@Y!SIM-+hK&>[0X/G&b16tF9/HYfeT&ic$-k)b$qcY2gp+N*+&;jc*H1GN,FsA)s(J6**b(Nf>
	q"D%`f/d[9D-?fe+N&?I@-E0#AbUqI4tG7$cIK4(O8-2]g'A=sVl&.NjAb84LE[RY^-Gpg=$aO-7HU
	hu=gWN0]7Z;.2#SJi0?e7C"P7@6kW-7'e:0L!3#S1J/q[$oQ6t<d,.W&&/!Z+s)c"<CrKB6.q@^gc*
	(uA69NYqm1>M.9cmj'JuHcQ&-ZF>kYF,%.gZD31\?<GB[&0:tMFL%3*35%Y<j)r^bRgP@(g[Wf+Lp8
	Y<^b'EfT=5'5e6qlg%MB>=@9>n<uN:le(i5/7&(l[Di8<F#prqYGM@<XON5CgMI<mE1Cr:AUm2jDb-
	a@AO[-q1O`9-=]a(1jq68%0M.PY.l:f!F7F!Y'=N(Xfc"96pRe\'ciqLFG`iD+uqC^E<59R.\Hh#5d
	X4jBOEa<*pu7?/hBD";m7jUX,X0N)d#<YXu*SoY-tJk[^:MIb>hWFOrY,LMd"M"pX2JioT)"[FCKnu
	?AgGIhPg`f!!Y+WI+h"OQU=kZ>;+,k'J6riojL]WL!\SU`O0LhWf-1l;uhK;O9hoglcl)E(*%l0XVL
	?Y=@JJiM<r[#1u>5ZPsg%#)\`uSF5QC9U53WI%&ks`GTKi@U*CE2&K2%WZg$HE*24W"H"UfqNb+@'=
	@=Zf2*eQ6WnS=_WBYgHfU'A#!!*&>s7DouBRfc*LiIM-lKic$[C+OAc(H,ZY-,@Q)=,o*2SC'CrU+l
	X2384/Y.lU^E;>c-0cL+OYuOfmMk!\s"d.$Qc8d.:,j.:QXf<O!?Q/->l_T[-<0(@H?#c-UY]Old@Y
	+4%I%ENJ&MXh/dHQ,4P;iNFE+l@\>MCDACg?ic8IH@d)'hU:69$]3U*'fY`!3=in(<s8_n$`p7Ka^;
	MolhU05F':hY?aTk?6r5%"eT`+;"2l29dTV^eDu'ZFADON5MY6%Yk06636-J!0PRicoR4u]WW%Q5nO
	Fn,ias^fG2p8:C'Kb9F-B0fclM+.3SZL++Cl-q<%D%kJp)>loZPYSG2dP[N=3c3'7=/b69(s\c/^H2
	o#%&E@eaX/-,1Rm(+O?LtLn_29+9l?%3k'&JLfjX.h"Ln7;<peE_$7LY(CnHMsBSFq"N[+Wq@JNr/H
	SUT0,BN,6j#?[9Ci3a7Tj(']030[CLeL:)%"h5`KK2*(Mr0U!U\0`j*2&^s;R)Bg$+9ZHtPqmFi^lB
	-&iTbjOn,le]LolUbVY"LM6,7]XS(R8[l^53[<;&8=p(I!#g&gBYlFbaH^CljGQ5p7cK`uff4Wn%os
	HXCM]+jH.CMqueNEJRb^;MKM1qVaqoh`:_rpE@1A/-%rr'O(PL<BsBCR$4K@#CEQBol*=k671gElh.
	`V_r#Fi>;p*d,"W=GW%Z@^IqSq7R>?ZYER'h=]X,Nta<FaiG8,AtraK!TqdKlY`#KJ1iTTtaB`pgH6
	\^\^Z//M^$g4U27#oA=qLI\e4P5?I,X_`&-f)4e-g/bkAWHb)fH))f&IAc*&4qGYiaOX'QduCo[Cr+
	mhI2@Kc?V+BX*S03EoYlCJ+#>rd<N=pbkB-d%bN;L!WZ`#@2D:h"KJ2h`YcmRf_V<ZNL-cP04i/<k4
	$?@/uk6d:gr_3'J!]%J\Da$9[&;X7"u*^>>l;\m#<_GYlRdTg0(eh8:</W7Bfb,q:ZQ6A\!]b"[H$`
	`NWbp,qr#Ifi_5hG#T;o$Y%;f,d`Q^Sb?qZp)KrBE!UuQA=;hZ8dUPSnj+?M0+KOrl&Qo2!AZ,N`?^
	8#*`$:)gY^aXh4XhmkOXp,7<=d\2r>X:=&O@$[lqH'/0p+H<CmObF$Ai%e=rnc9:CQqj>D]G/f3.*,
	cfM8GSIc<l1PQsd&\,leN5^gr6h6KY1Q]]#:[62;r:&l?7bFrd)e;$8Mf61oDNR8K9/Y<W#,S;R(Di
	]K@4c,Cdi4QF)`TY#onKhQg%hH_ir'?8JC4d&f8+F5(Xnf,0LD5N!*h#@[fn&nFX&aL`-(h=auO005
	RK[,)N8)jAfZ[W[FA(Fo^D&&A7/pA]XK.778=KKgUiHOH1!J6a`6&b)?NLK+?!RqcQj9ceJn9/JOPA
	k0o*lao0`VYpPNH**&7A&'%A(9o7rB]JP>-7r@FIcT`e4IA`EH;@0!&5T,i5bA7H8!=8b4E0gm&GW^
	uHgu%8eOrUk#jAfZ[g@c<\`\5f*HrXKopu:kWHAMn-)o&7n"a*:K.s=D_A<l<i%4S$%cuCaHn()q/X
	BomW[_ns-KAk@`gRmljlIo`5PCVg&/L.5+;hrn%56%,mSm3:OOUZhk[[L,a!5t(*V\FZE/iJWSp#*@
	3nlgLMU7dC"8-<XGYT&H>"k>:3kLa_k6IeK<gu7EDJ@*'cS]LV<>^E;`pI(#Tb&i[#)riH#PmmX)ID
	KP>!q^cA;DB;)<JVM0&Weg<,L_Z+ooZD\jgG$O70*i";l?W>^""n&7BaEf"%uL3O??s[rM=ap7d2F!
	078$UT]sp7Jg\%:!.Lb'qu6`X1acSq/;4$'!!!!j78?7R6=>B
	ASCII85End
End

// PNG: width= 216, height= 22
static Picture Toggle3PosVertShort
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!#O!!!!7#Qau+!%jk_IK0?J&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U&YVca5u_NKm9<5)?,psQa3:'oIGj*VnKEc6-'=E?7qK;q39>#Nfjp9r]<[G5c4<HHq&rn:;O,BKI
	isXpMkhhcAa<bdOsSkY83BK%^@+('Au7YJ$P4EdJ=qU:3@T0G=9+0Kh='[tF/Gj^%Y"-)BCHOgLkm`
	pXV(.1GuDGE\c)S_!$V,gL8hF01`\g_d$Ft=<$=d4/4fX.!5H"HBgd%d39K-<`$5Sb-\iD(&u?U>:V
	)8I'[*MfkOYB;3kY1*3/FAM2Apto<#_C`'XZ*<M/Lj2!?gR'Ni8T[BOE/6!.[Neb-;oG4M&i4BbuDC
	;>1#aQ^MnleWaT>`>Ct\,3e=K+VI*aIm5iPSWO=b=V_"T$IL,0F8di45pYM.VM!-SlKOVXd,\cm1k_
	-\6,WL15H$%5-mHrFT4*_0WZX/iK*Vb*A.TGPP0f=eHa0aFfL=bh9A4<HcgR+$rC$SS=.b4Z[ek:s,
	\a`6DqoYOAbAr[EDDlt:#&JB;-!!-##7VJ#i(2/SV+($6dIF(5t"_@oH0$`r1]cH5t\(YTVfT?.7>1
	YBmXY0l>/?nM*<a=^hh0!j]qLY(a>%G8R<\C-m1egKa-3cZ=/UqSpZ['o@h1B^tI.bl[1;nB/Z6,9j
	NL0LO2+V*jp%[@!DRsemgW6mc0j&q<jmKHHR``KBg<C4k]IV&>KIfki.E3ZW^HI'3Sptf%E#,WoD&<
	59K=LYFACJJUu@j!B,\>D+mhuAr'S;KLR7A@;9QG)ak10=^52i`i:L4OEa?',cV+M&nsTV'Vm")#SF
	m&-isnT:JTMa?=1Ig5;*VT&Af=5I`m*k<*,h-RG_lF$;LKpkO1&Up?J[3g=X'L\p!2`>"\IS?[O=Pj
	B,W9hiB_^fr4Ea#*#m*ijAF0,fX"d<EE0/!,r-;8g2`3UPD&Om67I\dnkhPUcNbhB2qr+@]1PIC0ro
	N!+s]20ih3[hIi8"1(,S<ksSMXQ)*!p;i2cn$E>;5<+8g$TLhNT6j3R"Cjtp-Im;9BM_@8R0g&APSR
	D?pMhn:qH3"N8rk@e#8la/uG0XcliTKgs\o8WOct,&1k"o-*=^ADJnLF^ilZ@<Y\,YrYs!Z(^mHomW
	n%L[5gT1XpK^,Ua]KM_nRP7Co72qAf.T'YTVnI(-W2'bP!&tF#gu!MMk`aiq:I]]se(LZ+Z^?>8O;L
	A`87>Doa2?T?;(blM&ODDM\nMoqH:68-henc(e/Dte.LAgC;,gL`5nm9a'efsh-p][=c\:b&rq]#HK
	?%?dCd0'%H!(N*!!GiKKLed%W.].3#\J.HY,=5Zo:.&DI2i6O(aM!oek%(d,*M]NM:,j32,/3[i9-p
	Pc7'f(oGi8(AJ]rNLduU\(4&@_]Pk8`Vs6=^$o=3'):-=)G'@NnQ%/YnJ(`N//Bdt)GOJBIf!AsH)h
	dDU";0<"&MkB%XA4L:B(IlO%R<h.Bc#mChfq4VG>af&l[]Qf6kB>9/MT".j=3t_DKY'PYoQgjU6H:s
	Fj=i@D0bRZF1]m*N@AS)TX)<e7T9Kn6i[oi&0fEl?lqoB-h=flmnSB(bI(!p1IE>m+gEp<)hfOU8Z)
	n-%9i0VYUXCU:=aRVhOV?^0A"dX0g^ZtaX9<4YuXSn1&:pDOF\tO@IY8J%O%DlXjq;HIcam1LoQ!(!
	/d45'ibtO5S8R/P@af62P68b=,ertGncebYF!3OKO_T.n!U`:DFHdr2Eth,nmD=jT/D'#a?Jm*k-&%
	#>Sb;uUPCe3?X54gVATaE<+.-6X>/;Y*,H#RbI4oqguYKr]`5IMrTJNs8*^\gXfaYun&J!5WXpB-Gq
	*%&AU!r^GNneWnf($.VQ,I9lNmQl6Bml!\RG2S>o&hS(/4ddTEmg$85.)i%$WL0aLUNn;YWAHU<GRI
	+5X^&AuAS919rq`^IN`#erN2+*W/s:[j@%C<Me6BG*\=`=Di#('qY0GqH%UmIBuk:RVG'5e;VuWnDS
	2n?B$mUP=P:V1Stc3XR2fb3`Z5uq'LoNUXFt/WU"`.D4-cQ1kIV.!E51["6)`N80USuC7(E>D8*^Rh
	ul6)*o+GWX4(hFS]f$?1F!C-q<']PR?oNMnYe(sf@;'W2VC)(Od[+6e`=i9S]?*3$d7r+J+%`f?G2Y
	Ppt<\PgXt@T$45'ieiLjkTd_/"A6O1oq50Ug+R\Jgo,Q'MY?e[s)cf1Ls23*Pa&*E[NADof`)\:-SL
	[cZIeW,emjqhW;j9o[arj7_Tamd)`a$&p/^JJM)36.FirMCGOI1h8&Wr:uQkj]kBLSO*HifpAY18a$
	^]+0r[B<oK;309UUIXA'c?-^#9uh]D$^DO#+ArTPaA',Q9=]]mVR'oSY$Sgt*DQP#?iOUkkZ<,GSrG
	\LK1D-aPK@o+S'@DELUtk[;</@gQ^ag<8t:c29$^$YZ94u5hqM'A9jXPidAQ1q$n9/[7$=L).PdZ*E
	/]hI(n\S@hY/[1\u[(2s5MWZ*H.[D@E8:e'$fHAI<m)hWZDP9b;'g'9kQ+:TJ4CVBJc`:IkVeEp(kC
	;o(.<[DroCt?`gMU(>\!(HS3X-7Q)RFXt?f^>?*P\UA@R$krG9[LAh,Bg8.;D)eIWLF6O/P'-p\#m!
	:04D_/$H1:E:/o]QKR+iPj$6]0IKC,uhJ31&0<D%&GVh='AK,;O4mQmj/.5!P<XT$ML@\pWV.88,#[
	pB]uPd*-8n6j*Z]9OpPR"JDcf.#h)6b[<Q5O5Pu:UQq*GWlgAmrS/+fU%YkoU+.XM![FT<\u$%>3\*
	irMF]0BBu4-/F?3/OAm(u2,"VqNW2L\o]fpk7L`e-s>&/lQ6X?=6q,tJimrgcX3gbn6@06L'QkVh^E
	6DtpH&AAiKB`"`>6R;l!!Al$$7@FSo0VYCaAN](0I"FP1IBa?f,#a-F."b[)GFU4Ri=Ga^!W&"a3;3
	#e6?7iDVDRYEsg#kA$SaX\VL6Ud.9AS1Ys'6hVD4,.k?N:DS3AtrL;)Oh09"gXk_-XSr1UG4T`PM;,
	t=(.>4R4&CFZs>Y\N(m?`T!)$&nm.<lc'rbsh:%l2^-2-uub6tI]:#uCXf@K%p[g&t/M85k]4S?p6-
	%roV$:NhNR+d5mu(q9hp)9+!0!WXPM<CBhZ)AONL+@lV],!^sISk=ni`Ya7LVWcC*a9d9&9`P:rWgZ
	1=eN*@t]_\Co-^tV9QhMTH]\^0'mTRbLfIR;oML8Ss*qR^R5MCCg8K^7pr0N&@^O5-;M\QiX@bKlOA
	259c!34A*^(c[mR?5DGK1CSt<@?2,jUE^h$<f[r^j4E+KLD?fQb?_O:&VQ8q<`CohO.+8S!srWh>7:
	>>BF5]eu=P,MU)0@Z9=7)Sb>!#*km!i>KC^XdN*+nWm&LS-`8'e!"b:#2C7U2]Bsc'VV$.Nm<"OARK
	AT]4E/m=IM/:-s7d+S5HFXiDnf:'FMNF3KE>0b/"rb*L&a(L9\0!cGYKW`@lUgZE&JZJp"#W"V$1F<
	-B;o,e'jVp.N'GYA2"qfA!8<lg1/R>f%37tm<4Br,6BX#$K9C[Xiq/(5p/Q1!R_gWiUcc6\#S]fk<J
	tgNkV&-%)7b;C0!#O@8iiDQs,=_">e]&i9?*t\U4)EBK5qRj%iL7JS)Fk;40MONX)';$=e/&H<L-./
	\7s$E5Um%&k@(e>4%R&GVT:7-GX5jL(Y,.?t:PtA,rYi0D,i#BO$k*XK3tTR#UbZ<;ka-pXto\e:YT
	gimP71&q$;,dtp%-qS@,dETrpf,S\RUUWtp-k^>gKUVW$'P9_6_[FpC0n@A@BJ;dWKPeqY`XqWfmgp
	(&C_&\P,4J,?AR03rITNF*[D<?l;OMQ*!cZ3bE[MJ=,VI(cI;%u;np:DrqUhHY,;q3#"\82`tQNd^`
	#bWB7P^s$*3Rifi5kDF7#WD:>+@5]PT-&LNJT^$/at,1sQ"j5<]J`-03L_"UMug9h\XkNejK:a&&&L
	($I/*^<=_:pa%]I!AP#3=@dNf#ePQ<$!\f(Li[8r8;ZdtRb$]$nekT/22*"ER3&=L=9"/I+GF#@>o5
	Qi>VZq)HU'kf5Q0MuZ'e^n.ImZ&lgTD\K%O$<O3`q?C'mRkkVnD'oQ/db*KZ_@^K,/S"U*03U8Shh<
	t_AAQuqR"7'NDI$im.-Go?['**:`Wer8Q8]X6)"!C.4mqi5dL)_?-B?FYIAheCooP=@(p<I&e_5pOp
	"!eR+SLOlnVBI0KDiG&J:?0$/t,8ENhnWW(KBA2%#WPO6cYaO$EX=_cLb]IHSoCldo3g;[Q)p#b!_u
	64SZZ7`Oge<jHSqCama^MC"gFoB*0EX%P&&&4;TtRM:Q?OWhRg9S2`fU26k&XL2)NDR!p%pFAaVNCK
	\UaBS%4OZPgYq;ah-;*bco:_HVj2*_V5<QnFi9WECu*oG2IU<%i\dnd,P]CKY6Ibs>Wm7t7+f<!6XI
	/WRC_SMT`&Mhg[4N[3-WbXL>`+3/16n`k`*bO]jI%7SO.u.1S0E<LDlF`;sPZ5KG=ZDt+f;p^(HaSM
	Wo+H,ZYGn1V,R+5k[e%g9P0T.Y7&l&V&#JWZXSW,h!<?")-h:uZ]7[A,KKGSr(a)XI,2s=cM.L*bA`
	jHER@2V]WMr%/%d2fjrDn8R>3cMWc:&nN,!aT;P9s"__Nr\:;d,CF=T'k>FqT40QSBgV8W&7!!Dukh
	Bmki2W(72N!=;.:7^2eLJ,=Hgh<j`GYHtJ&i)fYg5?h7VAM.?RY2+Kk>@kEn]KSKtHAe+B!_5WI.0V
	W<Xst$g`ZgO"[Of&7kN\/"PE/693#KoUe$&R#p(LUtHAcR:iS;"m"QsLq*#)2e"qTl1C2J,;dSA<RZ
	FnXh^&7/BCqP=PKZo5XU+-eD^mI71>,u5c?!K;OVOfi^<sI"1oG2d+bBf`0l`Ye"U`lUCOH<<O<CKl
	CdFt\G=t?_&Bk\I4"YFOkSt[aYM[lK>I.Vrr^NJ-+eX=N=7UmG_,pE9H&-"]63udKmUf[_r8*fKYiC
	(Xi]lErB>AoFiHYI)55rc<PB<%])FmVPR!*Bs&U27Nm+Vc3HMXKqn/jps??XMN$I'2;8rV@K%YUKSR
	,U!4E&Kr;/PB3mjgP)pugTm?/K+W'*EO)a:DnaDbVj'RN.3K9[!eN;jSEgl4W@W,B@`gj"8retrnqX
	e[A_@*[r@ureOX6/'Tjb=P8;;X.+TL@)J(8:XMfQYc,O8UHdq^Tf^O"r62r=EA]m(tg1f_'t*+hRXM
	F9pC@uRZ]g$*U)kFYp!nBp,B>o+gS9KnEbZIt+T?"Ke"R#%,s3R@&$40u(X>6ZPM.[uU.:W5%@?RXZ
	q-sKLjdE$j(R1'h@lZI67Q0_\2=qg9'U,es+Np6ZK@NpS<'`h8ENe.fu)J16aA-!$h3.FqYLd`N3)j
	^oU4?lqfIL"-b@W7>a5j*4'Q_e]<HnGolU84@%BE)LW%--EX0_?6O<mHUrh;#H\[%C%(]/)6]aI[r=
	5<:&&IFXqu+,8H,X)F8HH)X`P0%oql<bJut59#*\Y5+,.;8o;"!+A30H+nK?U1jc)9,!FEIuiY>^i/
	5oMo%LFR/&dGG[YtP%d0R^S]OB%<>ESsM7]]2D:Seh'9A+S7%SXUkJ3L0$B_i3Y8+1IC:Z:eIhAZJG
	R=ETCdTe%g86i.f0KYW+>Z>^W<G-cc4>"e70LDmI!P#Op4(9tM(fR&5lf;%c'._GF(ONf!RT3;,k`*
	-Yp%j*ZnS*h]d+a(7>Ro6%`SDtDuU40&m,W(I5^6g!!!!j78?7R6=>B
	ASCII85End
End

// 
static constant kCCE_mouseup= 2
static constant kCCE_frame= 12
static constant kCCE_mousedown = 1
static constant kCCE_mouseup_out =3

Static Structure ToggleInfo
	Int32 thePos		// current Position (0,1, or 2)
	Int32 direction		//  Going down =0, going up =1
	Int32 disabled		//set if control is disabled
	Int32 mouseDown    // set if mouse down in control
EndStructure

Static Function ToggleFunc(s)
	STRUCT WMCustomControlAction &s
		
	STRUCT ToggleInfo info
	switch (s.eventCode)
		case kCCE_frame: // calculate the correct frame, read it to the WMCustomControlAction struct
			StructGet/S info,s.userdata
			s.curFrame= 3*info.thePos // start at the  "normal" frame for the position
			if (info.disabled == 1)  // disabled frame is "normal" frame + 2
				s.curFrame +=2
			else // mouse down position is 1 past normal frame
				s.curFrame += info.mouseDown
			endif
			break
		case kCCE_mousedown: // mouse down
			StructGet/S info,s.userdata
			info.mouseDown =1  // set mouseDown bit in ToggleInfo struct
			StructPut/S info,s.userdata
			break
		case kCCE_mouseup_out: // mouse up outside of control 
			StructGet/S info,s.userdata
			info.mouseDown =0  // un-set mouseDown bit in ToggleInfo struct
			StructPut/S info,s.userdata
			break
		case kCCE_mouseup:  // mouse up 
			StructGet/S info,s.userdata
			info.mouseDown =0 
			if (s.eventMod & 2) // shift key was pressed, flip enabled state
				if (info.disabled ==1)
					info.disabled =0
				else
					info.disabled =1
				endif
			elseif (info.disabled ==0) // normal mouse-up and control is enabled
				switch (info.thePos) // advance position up or down, depending on current position
					case 0:
					case 2:
						info.thePos =1
						break
					case 1:
						if (info.direction == 0)
							info.thePos = 2
							info.direction=1
						else
							info.thePos = 0
							info.direction=0
						endif
						break
				endSwitch
			endif
			// Put code to do things here based on the position of the switch
			StructPut/S info,s.userdata
	endSwitch
	return 0
End



Window Panel1() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(374,125,643,257)
	SetDrawLayer UserBack
	CustomControl ccToggle,pos={10,10},proc=GUIP#ToggleFunc
	CustomControl ccToggle,userdata= A"zzz",picture= {GUIP#Toggle3PosVertTall,9}
EndMacro



menu "Notebook"
	SubMenu "Color"
		"Comments/O1",/Q, SyntaxColor ("comments")
		"Functions/O2",/Q, SyntaxColor ("functions")
		"Key Words/O3",/Q, SyntaxColor ("keyWords")
		"Operations/O4",/Q, SyntaxColor ("operations")
		"#pragmas/O5",/Q, SyntaxColor ("pragmas")
		"Strings/O6",/Q, SyntaxColor ("strings")
		"Text/O7",/Q, SyntaxColor("text")
	end
end
	
function  SyntaxColor (element)
	string element
	
	strswitch (element)
		case "comments":
			Notebook kwTopWin textRGB=(65535,0,0)  // red
			break
		case "strings":
			Notebook kwTopWin textRGB=(8481,40606,7196) // green
			break
		case "keyWords":
			Notebook kwTopWin textRGB=(1,16019,65535) // blue
			break
		case "operations":
			Notebook kwTopWin textRGB=(5654,29812,30069)//teal
			break
		case "functions":
			Notebook kwTopWin textRGB=(49087,20560,0) // brown
			break
		case "pragmas":
			Notebook kwTopWin textRGB=(51657,0,44461) // purple
			break
		case "text":
		default:
			Notebook kwTopWin textRGB=(0,0,0) // black
			break
	endSwitch
end

Function GUIPTabProc(tca) : TabControl
	STRUCT WMTabControlAction &tca
	switch( tca.eventCode )
	
		case 2: // mouse up
			// database for each tabcontrol is stored in a set of waves in a datafolder within the packages folder 
			string folderPath = "root:packages:GUIP:TCD:" + possiblyquotename (tca.win) + ":" + tca.ctrlName + ":"
			// get string for previous tab, and current tab
			SVAR prevTab= $folderPath + "currentTab"
			SVAR tabList = $folderPath + "tabList"
			string curTab = StringFromList(tca.tab, tabList, ";") 
			if (cmpStr (prevTab, CurTab) !=0)
				variable iControl, nControls
				// get list of controls from previous tab and hide them
				WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (prevTab) + "_ctrlNames"
				WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (prevTab) + "_ctrlTypes"
				WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (prevTab) + "_ctrlAbles"
				if ((WaveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles))
					nControls = numPnts (ctrlNames)
					for (iControl =0; iControl < nControls; iControl +=1)
						GUIPTabShowHide (ctrlNames [iControl], ctrlTypes [iControl], 1, tca.win)
					endfor
				endif
				// get a list of controls from new tab and show them
				WAVE/z/T ctrlNames = $folderPath + PossiblyQuoteName (curTab) + "_ctrlNames"
				WAVE/z/T ctrlTypes = $folderPath + PossiblyQuoteName (curTab) + "_ctrlTypes"
				WAVE/z ctrlAbles = $folderPath + PossiblyQuoteName (curTab) + "_ctrlAbles"
				if ((WaveExists (ctrlNames) && waveExists (ctrlTypes)) && waveExists (ctrlAbles))
					nControls = numPnts (ctrlNames)
					for (iControl =0; iControl < nControls; iControl +=1)
						GUIPTabShowHide (ctrlNames [iControl], ctrlTypes [iControl], ctrlAbles [iControl], tca.win)
					endfor
					// extra user-defined function that runs after updating all the controls, gets the same WMTabControlAction as was passed to this function
					SVAR/Z userUpdateFuncStr= $folderPath + "userUpdateFunc"
					if ((SVAR_EXISTS (userUpdateFuncStr)) && (Cmpstr (userUpdateFuncStr, "") != 0))
						FUNCREF GUIPProtoFuncTabControl UserUpdateFunc = $userUpdateFuncStr
						UserUpdateFunc (tca)
					endif
				endif
				// update curTab string
				prevTab = CurTab
			endif
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End
