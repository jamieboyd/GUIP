#pragma rtGlobals=3
#pragma IgorVersion=6.1
#pragma version = 1	 // Last Modified: 2016/11/04 by Jamie Boyd
#pragma ModuleName = GUIP

// Static constants used for options variable for functions
STATIC CONSTANT kRECURSE =1
STATIC CONSTANT kGETPATH = 2
STATIC CONSTANT kADDCOLON = 4
STATIC CONSTANT kNOPACKAGES = 8
//Procedures for making lists of Igor objects from folders and graphs, with specializations for making the kinds of lists used in popup menus
//******************************************************************************************************
//  GUIPListObjs returns a semicolon-separated list of all the objects of the slelected type (objectType)
// in the given folder (sourceFoldrStr)whose names match the given string (matchStr)
// Last Modified 2014/12/04 by Jamie Boyd
Function/s GUIPListObjs (sourceFolderStr, objectType, matchStr, options, erstring, [sepStr])
	string sourceFolderStr	// can be either ":" or "" to specify the current data folder. You can also use a full or partial data folder path.
	variable objectType		// 1 = waves, 2= numeric variables, 3= string variables, 4 = data folders
	string matchstr			// limit list of objects with this wildcard-enhanced string. use "*"  to get all objects	
	variable options			// bit 0=1: set to do a recursive call through all subfolders of the source folder
							// bit 1 =2:  set to get full or relative filepaths depending on sourceFolderStr. unset to get just the objects with no path.
							// bit 2 =4: If listing folders, set to suffix folder names with a colon, good for building filepaths, unset for no colon
							// bit 3 = 8: do not list packages folder or items from packages folder
	string erstring			// a string to return if no objects are found
	string sepStr			// optional separator string for returned list. Default is ";"
	
	if (ParamIsDefault(sepStr))
		sepStr = ";"
	endif
	// return error message if folder does not exist
	// why the "\\M1(" ? It is a formatting code for disabling choices in pop-up menus
	if (!(datafolderexists (sourceFolderStr)))
		return "\\M1(" + sourceFolderStr + " does not exist." 
	endif
	// make sure sourceFolderStr ends with a colon
	sourceFolderStr = RemoveEnding (sourceFolderStr, ":") + ":"
	// if giving path, or when doing recursive calls, prepend each object name with sourceFolder
	string endStr = sepStr, prependStr = SelectString ((options & (kGETPATH + kRECURSE)), "", sourceFolderStr)
	DFREF sourceDFR = $sourceFolderStr
	// if listing folders, end each folder name with a colon if requested, and always add a list separator
	if (objectType ==4)
		endStr = SelectString ((options & kADDCOLON), sepStr, ":" + sepStr)
	endif
	// start return list with matching objects in sourceFolder
	variable iObj
	string objName, returnList = ""
	// if not listing packages folder, check for it when we are looking through root folder
	if (((options & kNOPACKAGES) && (cmpStr (sourceFolderStr, "root:") ==0)) && (objectType ==4))
		for (iObj = 0 ; ; iObj += 1)
			objName = GetIndexedObjNameDFR(sourceDFR, objectType, iObj)
			if (strlen (objName) > 0)
				if ((stringmatch(objname, matchStr )) && (stringMatch (objname, "!packages")))
					returnList += prependStr  + possiblyquoteName (objname) + endStr
				endif
			else
				break
			endif
		endfor
	else
		for (iObj = 0 ; ; iObj += 1)
			objName = GetIndexedObjNameDFR(sourceDFR, objectType, iObj)
			if (strlen (objName) > 0)
				if (stringmatch(objname, matchStr ))
					returnList += prependStr  + possiblyquoteName (objname) + endStr
				endif
			else
				break
			endif
		endfor
	endif
	// If recursive, iterate though all folders in sourceFolder
	// in recursive calls, set erString to "", so user's erStr is not added to the return list for every empty subfolder, only if all folders are empty
	if (options & kRECURSE)
		variable iFolder
		string aFolder
		if ((options & kNOPACKAGES) && (cmpStr (sourceFolderStr, "root:") ==0)) 
			for (iFolder =0; ; iFolder +=1)
				aFolder =  GetIndexedObjNameDFR(sourceDFR, 4,  iFolder)
				if (strlen (aFolder) > 0)
					if (StringMatch (aFolder, "!packages")) // if not listing packages folder, check for it when we are looking through root folder
						returnList += GUIPListObjs (sourceFolderStr + possiblyquotename (aFolder), objectType, matchStr, options , "", sepStr = sepStr)
					endif
				else
					break
				endif
			endfor
		else
			for (iFolder =0; ; iFolder +=1)
				aFolder = GetIndexedObjNameDFR(sourceDFR, 4,  iFolder)
				if (strlen (aFolder) > 0)
					returnList += GUIPListObjs (sourceFolderStr + possiblyquotename (aFolder), objectType, matchStr, options , "", sepStr = sepStr)
				else
					break
				endif
			endfor
		endif
	endif
	//  if no list was made, and this is the starting call, return user's error message
	if (strlen (returnList) < 2)
		return erstring
	else
		return returnList
	endif
end

//******************************************************************************************************
//  GUIPCountObjs just counts the objects of the slelected type (objectType)
// in the given folder (sourceFoldrStr)whose names match the given string (matchStr)
// Last Modified 2014/12/04 by Jamie Boyd
Function GUIPCountObjs (sourceFolderStr, objectType, matchStr, options)
	string sourceFolderStr	// can be either ":" or "" to specify the current data folder. You can also use a full or partial data folder path.
	variable objectType		// 1 = waves, 2= numeric variables, 3= string variables, 4 = data folders
	string matchstr			// limit list of objects with this wildcard-enhanced string. use "*"  to get all objects	
	variable options			// bit 0=1: set to do a recursive call through all subfolders of the source folder
							// bit 3 = 8: do not list packages folder or items from packages folder
	
	// return error message if folder does not exist
	// why the "\\M1(" ? It is a formatting code for disabling choices in pop-up menus
	if (!(datafolderexists (sourceFolderStr)))
		return 0
	endif
	// make sure sourceFolderStr ends with a colon
	sourceFolderStr = RemoveEnding (sourceFolderStr, ":") + ":"
	DFREF sourceDFR = $sourceFolderStr
	variable iObj, returnNum =0
	string objName
	// if not listing packages folder, check for it when we are looking through root folder
	if (((options & kNOPACKAGES) && (cmpStr (sourceFolderStr, "root:") ==0)) && (objectType ==4))
		for (iObj = 0 ; ; iObj += 1)
			objName = GetIndexedObjNameDFR(sourceDFR, objectType, iObj)
			if (strlen (objName) > 0)
				if ((stringmatch(objname, matchStr )) && (stringMatch (objname, "!packages")))
					returnNum +=1
				endif
			else
				break
			endif
		endfor
	else
		for (iObj = 0 ; ; iObj += 1)
			objName = GetIndexedObjNameDFR(sourceDFR, objectType, iObj)
			if (strlen (objName) > 0)
				if (stringmatch(objname, matchStr ))
					returnNum +=1
				endif
			else
				break
			endif
		endfor
	endif
	// If recursive, iterate though all folders in sourceFolder
	// in recursive calls, set erString to "", so user's erStr is not added to the return list for every empty subfolder, only if all folders are empty
	if (options & kRECURSE)
		variable iFolder
		string aFolder
		if ((options & kNOPACKAGES) && (cmpStr (sourceFolderStr, "root:") ==0)) 
			for (iFolder =0; ; iFolder +=1)
				aFolder = GetIndexedObjNameDFR (sourceDFR, 4,  iFolder)
				if (strlen (aFolder) > 0)
					if (StringMatch (aFolder, "!packages")) // if not listing packages folder, check for it when we are looking through root folder
						returnNum += GUIPCountObjs (sourceFolderStr + possiblyquotename (aFolder), objectType, matchStr, options)
					endif
				else
					break
				endif
			endfor
		else
			for (iFolder =0; ; iFolder +=1)
				aFolder = GetIndexedObjNameDFR (sourceDFR, 4,  iFolder)
				if (strlen (aFolder) > 0)
					returnNum += GUIPCountObjs (sourceFolderStr + possiblyquotename (aFolder), objectType, matchStr, options)
				else
					break
				endif
			endfor
		endif
	endif
	return returnNum
end
//******************************************************************************************************
// UpDownFolders is designed for use as the list expression in a popupmenu for setting the current data folder. It returns a semicolon-separated list
// containing the full paths to all the folders in the folder hierarchy above the current data folder, the full path to the current data folder, and the full path to
// all the data folders in the current folder. Because of some fancy formatting, the current folder  will be 
// greyed out and set off by list separators in the popup menu.
// Last Modified 2013/04/03 by Jamie Boyd
Function/s  GUIPListUpDownFolders ()

	string curPath = GetDataFolder(1) // full path to current folder
	variable iLevel, nLevels = ItemsInList(curPath, ":")-1
	string returnStr, pathStr
	// for each level, add full path to the return string. Build up full path in pathStr, level by level
	for (iLevel =0, pathStr = "", returnStr = ""; iLevel < nLevels; iLevel += 1)
		pathStr += stringFromList (iLevel, curPath, ":") + ":"
		returnStr += pathStr + ";"
	endfor
	return returnStr + "\\M1-;\\M1(" + curPath + ";\\M1-;" + GUIPlistObjs (Curpath, 4, "*", ( kADDCOLON + kGETPATH), "")
end	

.//******************************************************************************************************
// Use SetFolderPopMenuProc to set the current folder to whatever folder was chosen from the popup menu.
// Last Modified 2012/06/03 by Jamie Boyd
Function GUIPListSetFolder(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			SetDataFolder  $pa.popstr
		case -1: // control being killed
			break
	endswitch
	return 0
End

//******************************************************************************************************
//Returns a list of all the waves of a particular number of dimensions in the folder
// Last Modified 2014/12/04 by Jamie Boyd
Function/s GUIPListWavesByDim (sourceFolderStr, NumDims, matchStr, options, erstring, [sepStr])
	string sourceFolderStr 	// can be either ":" or "" to specify the current data folder. You can also use a full or partial data folder path.
	variable numdims	// bitwise for number of dimensions you are looking for bit 1 for 1D, bit 2 for 2D, bit 3 for 3D, or bit 4 for 4D. bit 0 is not used
	string matchstr	// limit list of objects with this wildcard-enhanced string. use "*"  to get all waves	
	variable options	
	string erstring	// a string to return if no objects are found
	string sepStr
	
	if (ParamIsDefault(sepStr))
		sepStr = ";"
	endif
	// return error message if folder does not exist
	if (!(datafolderexists (sourceFolderStr)))
		return "\\M1(" + sourceFolderStr + " does not exist." // why the "\\M1(" ? It is a formatting code for disabling choices in pop-up menus
	endif
	// make sure sourceFolderStr ends with a colon
	sourceFolderStr = RemoveEnding (sourceFolderStr, ":") + ":"
	DFREF sourceDFR = $sourceFolderStr
	variable iObj
	string objName, returnList = ""
	// make sure sourceFolderStr ends with a colon
	sourceFolderStr = RemoveEnding (sourceFolderStr, ":") + ":"
	// if giving path, or when doing recursive calls, prepend each object name with sourceFolder
	string prependStr = SelectString ((options & (kGETPATH + kRECURSE)), "", sourceFolderStr)
	//iterate through objects
	for (iObj = 0; ; iObj += 1)
		objName = GetIndexedObjNameDFR(sourceDFR, 1, iObj)
		if (strlen (objName) >  0)
			WAVE thewave = $sourceFolderStr + possiblyquotename (objName)
			if ((stringmatch(objname, matchStr)) && ((2^WaveDims(thewave)) & numDIms))
				returnList += prependStr + possiblyquotename(objname) +sepStr
			endif
		else
			break
		endif
	endfor
	// If recursive, iterate though all folders in sourceFolder
	// Turn off high bit, signalling that this is a recursive call, so that
	// erString is not added to the return list for every empty subfolder, only if all folders are empty
	if (options & kRECURSE)
		variable iFolder
		string aFolder
		if ((options & kNOPACKAGES) && (cmpStr (sourceFolderStr, "root:") ==0))
			for (iFolder =0; ; iFolder +=1)
				aFolder = GetIndexedObjNameDFR (sourceDFR, 4,  iFolder)
				if (strlen (aFolder) > 0)
					if (stringMatch (aFolder, "!packages"))
						returnList += GUIPListWavesByDim (sourceFolderStr + possiblyquotename (aFolder), numDims, matchStr, options , "", sepStr=sepStr)
					endif
				else
					break
				endif
			endfor
		else
			for (iFolder =0; ; iFolder +=1)
				aFolder = GetIndexedObjNameDFR (sourceDFR, 4,  iFolder)
				if (strlen (aFolder) > 0)
					returnList += GUIPListWavesByDim (sourceFolderStr + possiblyquotename(aFolder), numDims, matchStr, options , "", sepStr=sepStr)
				else
					break
				endif
			endfor
		endif
	endif
	//  if no list was made, return user's error message
	if (strlen (returnList) < 2) 
		return erstring
	else
		return returnList
	endif
end

//******************************************************************************************************
//Returns a list of all the waves of a particular type in the folder, according to the waveType function return value:
//Type				Bit #
//complex			0
//32-bit float		1
//64-bit float		2
//8-bit integer 	3
//16-bit integer 	4
//32-bit integer 	5
//unsigned 			6
// text waves are wavetype 0
// Last Modified 2014/12/04 by Jamie Boyd
Function/s GUIPListWavesByType(sourceFolderStr, type, matchStr, options, erstring, [sepStr])
	string sourceFolderStr	 // can be either ":" or "" to specify the current data folder. You can also use a full or partial data folder path.
	variable type			// bit-wise wavemetrics code for type (see above)
	string matchstr		// limit list of objects with this wildcard-enhanced string. use "*"  to get all objects	
	variable options	
	string erstring		// a string to return if no objects are found
	string sepStr
	
	if (ParamIsDefault(sepStr))
		sepStr = ";"
	endif
	// return error message if folder does not exist
	// why the "\\M1(" ? It is a formatting code for disabling choices in pop-up menus
	if (!(datafolderexists (sourceFolderStr)))
		return "\\M1(" + sourceFolderStr + " does not exist." 
	endif
	// make sure sourceFolderStr ends with a colon
	sourceFolderStr = RemoveEnding (sourceFolderStr, ":") + ":"
	DFREF sourceDFR = $sourceFolderStr
	// if giving path, or when doing recursive calls, prepend each object name with sourceFolder
	string prependStr = SelectString ((options & (kGETPATH + kRECURSE)), "", sourceFolderStr)
	variable iObj
	string objName, returnList = ""
	//iterate through waves
	if (type == 0) // text waves need to be handled differently
		for (iObj = 0; ; iObj += 1)
			objName = GetIndexedObjNameDFR(sourceDFR, 1, iObj)
			if (strlen (objName) > 0)
				WAVE thewave = $sourceFolderStr + PossiblyQuoteName (objName)
				if ((stringmatch(objname, matchStr)) && (WaveType(thewave) == 0))
					returnList += prependStr + PossiblyQuoteName(objname) + sepStr
				endif
			else
				break
			endif
		endfor
	else
		//iterate through waves
		for (iObj = 0; ; iObj += 1)
			objName = GetIndexedObjName(sourceFolderStr, 1, iObj)
			if (strlen (objName) > 0)
				WAVE thewave = $sourceFolderStr + PossiblyQuoteName (objName)
				if ((stringmatch(objname, matchStr)) && ((WaveType(thewave) & type) == type))
					returnList += prependStr + PossiblyQuoteName (objname) + ";"
				endif
			else
				break
			endif
		endfor
	endif
	// If recursive, iterate though all folders in sourceFolder
	if (options & kRECURSE)
		variable iFolder
		string aFolder
		if ((options & KNOPACKAGES) && (CmpStr (sourceFolderStr, "root:") ==0))
			for (iFolder =0; ; iFolder +=1)
				aFolder = GetIndexedObjNameDFR (sourceDFR, 4,  iFolder)
				if (strlen (aFolder) > 0)
					if (stringmatch (aFolder, "!packages"))
						returnList += GUIPListWavesByType (sourceFolderStr + PossiblyQuoteName (aFolder), type, matchStr, options  , "",  sepStr=sepStr)
					endif
				else
					break
				endif
			endfor
		else
			for (iFolder =0; ; iFolder +=1)
				aFolder = GetIndexedObjNameDFR (sourceDFR, 4,  iFolder)
				if (strlen (aFolder) > 0)
					returnList += GUIPListWavesByType (sourceFolderStr + PossiblyQuoteName (aFolder), type, matchStr, options  , "",  sepStr=sepStr)
				else
					break
				endif
			endfor
		endif
	endif
	//  if no list was made,  return user's error message
	if (strlen (returnList) < 2)
		return erstring
	else
		return returnList
	endif
end

//******************************************************************************************************
// Some functions returning lists of waves based on keyword-value pairs in the wavenote.
//******************************************************************************************************
// Returns a list of all the waves in the given folder that match the given value for the given keyword. This one uses stringmatch so it is wild-card enabled
// for the KeyValue, e.g, using "*" will return a list of all waves that have that keyword, with any keyvalue.  Returns the error string if no matches.
// Last Modified 2014/10/15 by Jamie Boyd
Function/s GUIPListWavesByNoteKey (sourceFolderStr, KeyWordStr, KeyValue,  options, erstring, [sepStr, keySepStr, listSepStr])
	string sourceFolderStr		// the folder to search
	string KeyWordStr		// The keyword in the Wave note to search for
	string keyValue			//select waves that have this value of the keyword in the wavenote.
	variable options			// set bit 0 to include full path to wave, unset to not give path. Set bits 2 and 3 to be recursive
	String erstring			// A string to return if no matches are found
	string sepStr			// 
	string keySepStr		// the key separator string in the wavenote, default is ":"
	string listSepStr		// the list separator in the wavenote, default is ";"

	if (ParamIsDefault(sepStr))
		sepStr = ";"
	endif
	if (ParamIsDefault(keySepStr))
		keySepStr = ":"
	endif
		if (ParamIsDefault(listSepStr))
		listSepStr = ";"
	endif
	
	// return error message if folder does not exist
	// why the "\\M1(" ? It is a formatting code for disabling choices in pop-up menus
	if (!(datafolderexists (sourceFolderStr)))
		return "\\M1(" + sourceFolderStr + " does not exist." 
	endif
	// make sure sourceFolderStr ends with a colon
	sourceFolderStr = RemoveEnding (sourceFolderStr, ":") + ":"
	DFREF sourceDFR = $sourceFolderStr
	// if giving path, or when doing recursive calls, prepend each object name with sourceFolder
	string prependStr = SelectString ((options & (kGETPATH + kRECURSE)), "", sourceFolderStr)
	// iterate through waves
	variable iWave//, nWaves = CountObjects(sourceFolderStr, 1)
	string anObj, aVal, returnList
	for (iWave = 0, returnList = ""; ; iWave += 1)
		anObj = GetIndexedObjName(sourceFolderStr, 1, iWave)
		if (strlen (anObj) > 0)
			Wave aWave = $sourceFolderStr +  PossiblyQuoteName (anObj)
			aVal = StringByKey (KeyWordStr,note (aWave), keySepStr, listSepStr)
			if ((cmpStr (aVal, "") != 0) && (stringMatch (aVal,KeyValue)))
				returnList += prependStr + PossiblyQuoteName (anObj) + sepStr
			endif
		else
			break
		endif
	endfor
	// If recursive, iterate though all folders in sourceFolder
	if (options & kRECURSE)
		variable iFolder
		string aFolder
		for (iFolder =0; ; iFolder +=1)
			aFolder = GetIndexedObjNameDFR (sourceDFR, 4,  iFolder)
			if (strlen (aFolder) > 0)
				returnList += GUIPListWavesByNoteKey (sourceFolderStr + PossiblyQuoteName (aFolder), KeyWordStr, KeyValue, options , "", sepStr=sepStr, keySepStr=keySepStr, listSepStr=listSepStr)
			else
				break
			endif
		endfor
	endif
	//  if no list was made, return user's error message
	if (strlen (returnList) < 2)
		return erstring
	else
		return returnList
	endif
end	

//******************************************************************************************************
//Returns a list of all the waves in the given folder that match any one of a list of keyvalues for the given keyword in their wavenotes
// For times when the wild-card enabled function is not fine-grained enough
// Last Modified 2014/12/04 by Jamie Boyd
Function/s GUIPListWavesByNoteKeys (sourceFolderStr, KeyWordStr, KeyValueList, options, erstring, [sepStr, keySepStr, listSepStr])
	string sourceFolderStr		// name of the folder to search
	string KeyWordStr		// The keyword in the Wave note to search for
	string KeyValueList		// A list of values of the key word to search for
	variable options			// 1 to include full path to wave, 0 to not give path
	String erstring			// A string to return if no matches are found
	string sepStr
	string keySepStr			// the key separator string in the wavenote, usually ":"
	string listSepStr			// the list separator in the wavenote, usually ";"

	if (ParamIsDefault(sepStr))
		sepStr = ";"
	endif
	if (ParamIsDefault(keySepStr))
		keySepStr = ":"
	endif
		if (ParamIsDefault(listSepStr))
		listSepStr = ";"
	endif
	DFREF sourceDFR = $sourceFolderStr
	// return error message if folder does not exist
	// why the "\\M1(" ? It is a formatting code for disabling choices in pop-up menus
	if (!(datafolderexists (sourceFolderStr)))
		return "\\M1(" + sourceFolderStr + " does not exist." 
	endif
	// make sure sourceFolderStr ends with a colon
	sourceFolderStr = RemoveEnding (sourceFolderStr, ":") + ":"
	// if giving path, or when doing recursive calls, prepend each object name with sourceFolder
	string prependStr = SelectString ((options & (kGETPATH + kRECURSE)), "", sourceFolderStr)
	// iterate through waves
	variable iWave
	string anObj, aVal, returnList
	for (iWave = 0, returnList = ""; ; iWave += 1)
		anObj = GetIndexedObjNameDFR(sourceDFR, 1, iWave)
		if (strlen (anObj) > 0)
			Wave aWave = $sourceFolderStr +  PossiblyQuoteName (anObj)
			aVal = StringByKey (KeyWordStr,note (aWave), keySepStr, listSepStr)
			if (FindListItem(aVal, KeyValueList, ",") > -1)
				returnList += prependStr + PossiblyQuoteName (anObj) + sepStr
			endif
		else
			break
		endif
	endfor
	// If recursive, iterate though all folders in sourceFolder
	if (options & kRECURSE)
		variable iFolder
		string aFolder
		for (iFolder =0; ; iFolder +=1)
			aFolder = GetIndexedObjNameDFR (sourceDFR, 4,  iFolder)
			if (strlen (aFolder) >0)
				returnList += GUIPListWavesByNoteKeys (sourceFolderStr + PossiblyQuoteName (aFolder), KeyWordStr, KeyValueList, options , "", sepStr = sepStr, keySepStr=keySepStr, listSepStr=listSepStr)
			else
				break
			endif
		endfor
	endif
	//  if no list was made, and this is the starting call, return user's error message
	if (strlen (returnList) < 2)
		return erstring
	else
		return returnList
	endif
end	

//******************************************************************************************************
//Returns a list of all the waves in the given folder that match ALL of the listed key:value pairs.
// Last Modified 2014/10/15 by Jamie Boyd
Function/s GUIPListWavesByNoteKeyList (sourceFolderStr, KeyValuePairsList, options, erstring, [sepStr, keySepStr, listSepStr])
	string sourceFolderStr		// name of the folder to search
	string KeyValuePairsList	// A list of key value pairs in this format key:value;key:value;
	variable options			// set bit 0 (1) to include  path to wave, unset to not give path. set bits 2 and 3 (12) to go recursive
	String erstring			// A string to return if no matches are found
	string sepStr
	string keySepStr			// the key separator string in the keyValuePairsList, and in the wavenote, usually ":"
	string listSepStr			// the list separator in the keyValuePairsList, and in the wavenote, usually ";"

	if (ParamIsDefault(sepStr))
		sepStr = ";"
	endif
	if (ParamIsDefault(keySepStr))
		keySepStr = ":"
	endif
		if (ParamIsDefault(listSepStr))
		listSepStr = ";"
	endif
	// return error message if folder does not exist
	// why the "\\M1(" ? It is a formatting code for disabling choices in pop-up menus
	if (!(datafolderexists (sourceFolderStr)))
		return "\\M1(" + sourceFolderStr + " does not exist." 
	endif
	// make sure sourceFolderStr ends with a colon
	sourceFolderStr = RemoveEnding (sourceFolderStr, ":") + ":"
	DFREF sourceDFR = $sourceFolderStr
	// if giving path, or when doing recursive calls, prepend each object name with sourceFolder
	string prependStr = SelectString ((options & (kGETPATH + kRECURSE)), "", sourceFolderStr)
	// iterate through waves
	variable iWave//, nWaves = CountObjects(sourceFolderStr, 1)
	// iterate through key:value; pairs
	variable iPair, nPairs = ItemsInList(KeyValuePairsList, listSepStr)
	string returnList, anObj, aNote, aPair, aKey, aValue
	// iterate through waves
	for (iWave = 0, returnList = ""; ; iWave += 1)
		anObj = GetIndexedObjNameDFR(sourceDFR, 1, iWave)
		if (strLen (anObj) > 0)
			Wave aWave = $sourceFolderStr +  PossiblyQuoteName (anObj)
			aNote = note (aWave)
			// iterate through key:value pairs
			for (iPair=0; iPair < nPairs; iPair +=1)
				aPair = stringfromlist (iPair, KeyValuePairsList, listSepStr)
				aKey = stringfromlist (0, aPair, keySepStr)
				aValue = StringFromList (1, aPair, keySepStr)
				if (!((stringMatch (StringByKey(aKey, aNote, keySepStr, listSepStr), aValue))))
					break //exit the loop if this key-value pair doesn't match
				endif
			endFor
			if (iPair == nPairs)  //then we matched all the key:value pairs
				returnList += prePendStr + PossiblyQuoteName (anObj) +sepStr
			endif
		else
			break
		endif
	endfor
	// If recursive, iterate though all folders in sourceFolder
	if (options & kRECURSE)
		variable iFolder
		string aFolder
		for (iFolder =0; ; iFolder +=1)
			aFolder = GetIndexedObjNameDFR (sourceDFR, 4,  iFolder)
			if (strlen (aFolder) > 0)
				returnList += GUIPListWavesByNoteKeyList (sourceFolderStr + PossiblyQuoteName (aFolder), KeyValuePairsList, options , "", sepStr = sepStr, keySepStr=keySepStr, listSepStr= listSepStr)
			else
				break
			endif
		endfor
	endif
	//  if no list was made, return user's error message
	if (strlen (returnList) < 2)
		return erstring
	else
		return returnList
	endif
end	

//******************************************************************************************************
// Returns a list of waves displayed on the graph named in GraphNameStr. Pass "" for top graph
// Last Modified 2014/10/15 by Jamie Boyd
Function/S GUIPListWavesFromGraph (GraphNameStr, matchStr, type, options, erStr, [sepStr])
	string GraphNameStr	// name (not title) of graph
	string matchStr
	variable type  	// set bit 0=1 for Y waves, bit 1=2 for x waves, bit 2 =4 for images, 
	variable options // bit 0=1 for subwindow recursion. bit 1 = 2 to return paths, not just names
	string erStr
	string sepStr
	
	if (ParamIsDefault(sepStr))
		sepStr = ";"
	endif
	// make sure graph is open. use stringfromlist (0, graphNameStr, "#") to avoid problem of searching for subwindows in Winlist
	string superGraph =  stringfromlist (0, graphNameStr, "#")
	if (cmpstr (GraphNameStr, "") == 0)	// "" means use top graph
		if (strlen (WinList("*", "", "WIN:1" )) ==0)
			return "\\M1(" + " No Graphs are open."
		endif
	elseif (cmpstr (superGraph, WinList(superGraph, "", "WIN:1")) != 0)
		return "\\M1(" + superGraph + " is not open."
	endif
	// iterate through traces
	string returnList = ""
	variable iWave
	if (type & 3)
		For (iWave =0; ; iWave += 1)
			WAVE/z aWave = WaveRefIndexed(GraphNameStr, iWave, (type & 3))
			if (WaveExists (aWave))
				if (StringMatch (nameofWave (aWave), matchStr))
					if (options & 2)
						returnList += GetWavesDataFolder(aWave, 2) + sepStr
					else
						returnList += nameofWave (aWave) + sepStr
					endif
				endif
			else
				break
			endif
		endfor
	endif
	// iterate through images
	if (type & 4)
		string ImageList =  ImageNameList(GraphNameStr, ";" )
		variable nImages = itemsinlist (imageList)
		string anImage
		for (iWave =0; iWave < nImages; iWave += 1)
			anImage =  stringfromlist (iWave, ImageList)
			if (StringMatch (anImage, matchStr))
				if (options & 2)
					returnList +=GetWavesDataFolder (ImageNameToWaveRef (GraphNameStr,anImage), 2) + sepStr
				else
					returnList += anImage + sepStr
				endif
			endif
		endfor
	endif
	if (options & kRECURSE)
		string aChild, children = ChildWindowList(GraphNameStr)
		variable iChild, nChildren = itemsinlist (children)
		for (iChild =0; iChild < nChildren; iChild +=1)
			aChild = stringfromlist (iChild, children)
			returnList += GUIPListWavesFromGraph(GraphNameStr + "#" + aChild, matchStr, type, options, "", sepStr = sepStr)
		endfor
	endif
	if (strlen (returnList) < 2)
		return erStr
	else
		return returnList
	endif
end

//******************************************************************************************************
// Lists Waves displayed in a particular table.
//  Last Modified 2014/10/15 by Jamie Boyd
Function/S GUIPListWavesFromTable (TableNameStr, matchStr, options, erStr, [sepStr])
	string TableNameStr	// name (not title) of Table
	string matchStr
	variable options // bit 1 =2  to return full paths, not just names.
	string erStr
	string sepStr
	
	if (ParamIsDefault(sepStr))
		sepStr = ";"
	endif
	// make sure Table is open. use stringfromlist (0, TableNameStr, "#") to avoid problem of searching for subwindows in Winlist
	string superTable =  stringfromlist (0, TableNameStr, "#")
	if (cmpstr (TableNameStr, "") == 0)	// "" means use top Table
		if (strlen (WinList("*", "", "WIN:2" )) ==0)
			return "\\M1(" + " No Tables are open."
		endif
	elseif (cmpstr (superTable, WinList(superTable, "", "WIN:2")) != 0)
		return "\\M1(" + superTable + " is not open."
	endif
	// iterate through waves
	string returnList = ""
	variable iWave
	For (iWave =0; ; iWave += 1)
		WAVE/z aWave = WaveRefIndexed(TableNameStr, iWave,1)
		if (WaveExists (aWave))
			if (StringMatch (nameofWave (aWave), matchStr))
				if (options & 2)
					returnList += GetWavesDataFolder(aWave, 2) + sepStr
				else
					returnList += nameofWave (aWave) + sepStr
				endif
			endif
		else
			break
		endif
	endfor
	if (strlen (returnList) < 2)
		return erStr
	else
		return returnList
	endif
end

//******************************************************************************************************
//Returns a list of files of a particular type, whose names match the match string, and are located in the disk directory pointed to by the given path 
// Last modified:
// 2016/11/04 fixed bug - forgot to check for strip extension for alias
// 2016/10/13 by Jamie Boyd: when searching for shorcuts (fileTypeOrExtStr = ".lnk") and bit 2 is set, also strip " - shortcut"
// 2014/10/22 by Jamie Boyd: Includes option to also list creation date and modification date
Function/S GUIPListFiles (ImportpathStr,  fileTypeOrExtStr, matchStr, options, erstring, [sepStr])
	String ImportPathStr	// Name of an Igor Path
	String fileTypeOrExtStr	// macintosh file type (4 characters) or Windows extension, e.g.,  ".txt", or "dirs" to list directories
	String MatchStr  		// string to match file names for listing. Wildcard enabled. Pass "*" to list all files
	variable options			// bit 0=1: set to do a recursive call through all directories of the source directory
							// bit 1 =2: set to get full file paths. unset to get just the object names with no path.
							// bit 2 =4: set to strip three character file name extensions from returned file names
							// bit 3 = 8: set to allow user to set ImportPath if it does not already exist.
							// bit 4 = 16: set to list file creation dates after each file name
							// bit 5 = 32: set to list file modification dates after each file name, or after each creation date
							// bit 6 = 64: set to list alias/shortcuts that point to files, and to list contents of aliases to folders-must be listing full paths
	string erstring			// a string to return if no objects are found
	string sepStr			// optional separator string for returned list. Default is ";"
	
	if (ParamIsDefault(sepStr))
		sepStr = ";"
	endif
	// we  have to look for shorcuts/aliases differently on Mac vs PC 
	string fileAliasExt = ".lnk", fldrAliasExt = ".lnk"
	if (cmpStr ( IgorInfo (2), "Macintosh") ==0)
		fileAliasExt = "alis"
		fldrAliasExt ="fdrp"
	endif
	// if the Igor path does not exist, let the user set it, if that option is chosen
	string sourceDirStr
	PathInfo  $ImportPathStr
	if (!(V_Flag))
		if (options & 8)
			NewPath /O/M= "Set Path to Files of type " + fileTypeOrExtStr $ImportPathStr
			if (V_flag)
				return "\\M1(Invalid Path"
			else
				PathInfo  $ImportPathStr
				sourceDirStr = S_path
			endif
		else
			return "\\M1(Invalid Path"
		endif
	else
		sourceDirStr = S_path
	endif
	// if giving path, prepend each object name with sourceFolder
	string prependStr = SelectString ((options & kGETPATH), "", sourceDirStr)
	// iterate through files in this directory
	string afileName, allFiles, returnList = "" // lists of files that we will return
	variable iFile, nFiles, nameLen, aliasPathDepth, cutPos
	if (cmpStr (fileTypeOrExtStr, "dirs") ==0) // looking for directories
		AllFiles = IndexedDir($ImportpathStr, -1, (options & 4))
		nFiles = itemsinlist (AllFiles, ";")
		Make/N=(nFiles)/T/FREE tempFiles = StringFromList(p, AllFiles)
		for (iFile =0; iFile < nFiles; iFile +=1)
			afileName =tempFiles [iFile]
			if (stringmatch(afileName, matchStr))
				returnList += prependStr + aFileName + sepStr
				if (options & 48)
					GetFileFolderInfo /P=$ImportpathStr/Q afileName
					if (options & 16)
						returnList += secs2Date (V_creationDate, -2, "/") + "/" + Secs2Time(V_creationDate, 2) + sepStr
					endif
					if (options & 32)
						returnList += secs2Date (V_modificationDate, -2, "/") + "/" + Secs2Time(V_creationDate, 2) +  sepStr
					endif
				endif
			endif
		endfor
		if (options & 64)
			// now look for aliases to folders, probably fewer of these, so not bothering making a temp wave
			AllFiles =  IndexedFile ($ImportPathStr, -1, fldrAliasExt)
			for (iFile =0, nFiles = itemsinlist (AllFiles, ";"); iFile < nFiles; iFile +=1)
				afileName = StringFromList (iFile, allFiles, ";")
				GetFileFolderInfo /P=$ImportpathStr /Q aFilename
				if ((V_isAliasShortcut) && (cmpStr (S_aliasPath [Strlen (s_aliasPath) -1], ":") ==0))
					aliasPathDepth = itemsinlist (s_aliasPath, ":") -1
					afileName = StringFromList(aliasPathDepth, S_aliasPath, ":" )
					if (stringmatch(afileName, matchStr))
						returnList +=S_aliasPath + sepStr
						if (options & 48)
							GetFileFolderInfo S_aliasPath
							if (options & 16)
								returnList += secs2Date (V_creationDate, -2, "/") + "/" + Secs2Time(V_creationDate, 2) + sepStr
							endif
							if (options & 32)
								returnList += secs2Date (V_modificationDate, -2, "/") + "/" + Secs2Time(V_creationDate, 2) +  sepStr
							endif
						endif
					endif
				endif
			endfor
		endif
	else  //looking for files
		AllFIles = IndexedFile ($ImportPathStr, -1, fileTypeOrExtStr)
		nFiles = itemsinlist (AllFiles, ";")
		Make/O/N=(nFiles)/T/FREE tempFiles = StringFromList(p, AllFiles)
		for (iFile =0; iFile < nFiles; iFile +=1)
			afileName =tempFiles [iFile]
			if (stringmatch(afileName, matchStr))
				if (options & 4)
					NameLen = strlen (afileName)
					if ((cmpstr (afileName [NameLen - 4], ".")) == 0)
						if ((CmpStr (fileTypeOrExtStr, fileAliasExt) ==0) && (cmpStr (afileName [NameLen - 15, NameLen -5], " - Shortcut") ==0))
							cutPos = 16
						else
							cutPos =5
						endif
						returnList += prependStr + aFileName [0, NameLen - cutPos] +  sepStr
					else
						returnList += prependStr  + aFileName + sepStr
					endif
				else
					returnList += prependStr  + aFileName + sepStr
				endif
				if (options & 48)
					GetFileFolderInfo /P=$ImportpathStr/Q afileName
					if (options & 16)
						returnList += secs2Date (V_creationDate, -2, "/") + "/" + Secs2Time(V_creationDate, 2) +  sepStr
					endif
					if (options & 32)
						returnList += secs2Date (V_modificationDate, -2, "/") + "/" + Secs2Time(V_creationDate, 2) +  sepStr
					endif
				endif
			endif
		endfor
		if (options & 64)
			// now look for aliases to files, probably fewer of these, so not bothering making a temp wave
			AllFiles =  IndexedFile ($ImportPathStr, -1, fileAliasExt)
			for (iFile =0, nFiles = itemsinlist (AllFiles, ";"); iFile < nFiles; iFile +=1)
				afileName = StringFromList (iFile, allFiles, ";")
				GetFileFolderInfo /P=$ImportpathStr /Q aFilename
				if ((V_isAliasShortcut) && (cmpStr (S_aliasPath [Strlen (s_aliasPath) -1], ":") !=0))
					aliasPathDepth = itemsinlist (s_aliasPath, ":") -1
					afileName = StringFromList(aliasPathDepth, S_aliasPath, ":" )
					if (stringmatch(afileName, matchStr))
						if (options & 4)
					NameLen = strlen (afileName)
					if ((cmpstr (afileName [NameLen - 4], ".")) == 0)
						if ((CmpStr (fileTypeOrExtStr, fileAliasExt) ==0) && (cmpStr (afileName [NameLen - 15, NameLen -5], " - Shortcut") ==0))
							cutPos = 16
						else
							cutPos =5
						endif
						returnList += prependStr + aFileName [0, NameLen - cutPos] +  sepStr
					else
						returnList += prependStr  + aFileName + sepStr
					endif
				else
					returnList += prependStr  + aFileName + sepStr
				endif
						if (options & 48)
							GetFileFolderInfo S_aliasPath
							if (options & 16)
								returnList += secs2Date (V_creationDate, -2, "/") + "/" + Secs2Time(V_creationDate, 2) + sepStr
							endif
							if (options & 32)
								returnList += secs2Date (V_modificationDate, -2, "/") + "/" + Secs2Time(V_creationDate, 2) +  sepStr
							endif
						endif
					endif
				endif
			endfor
		endif
	endif
	// If recursive, iterate though all folders in sourceFolder
	// in recursive calls, set erString to "", so user's erStr is not added to the return list for every empty subfolder, only if all folders are empty
	if (options & kRECURSE)
		string subFolders
		variable iFolder, nFolders
		if ((options & kGETPATH) ||  (options & 64)) // if getting full path, just list the files
			subFolders = IndexedDir($ImportpathStr, -1, 1)
			nFolders = itemsinList (subFolders, ";")
			for (iFolder =0; iFolder < nFolders; iFolder +=1)
				NewPath /O/Q GuipListRecPath, stringFromList (iFolder, subFolders, ";")
				returnList += GUIPListFiles ("GuipListRecPath",  fileTypeOrExtStr, matchStr, options, "", sepStr = sepStr)
			endfor
			if (options & 64)
				AllFiles =  IndexedFile ($ImportPathStr, -1, fldrAliasExt)
				for (iFile =0, nFiles = itemsinlist (AllFiles, ";"); iFile < nFiles; iFile +=1)
					afileName = StringFromList (iFile, allFiles, ";")
					GetFileFolderInfo /P=$ImportpathStr /Q aFilename
					if ((V_isAliasShortcut) && (cmpStr (S_aliasPath [Strlen (s_aliasPath) -1], ":") ==0))
						NewPath /O/Q GuipListRecPath, S_aliasPath
						returnList += GUIPListFiles ("GuipListRecPath",  fileTypeOrExtStr, matchStr, options, "", sepStr = sepStr)
					endif
				endfor
			endif
		else	 // if not getting full path, need to make relative path from starting folder
			string dirStr = stringFromList (itemsinList (sourceDirStr, ":")-1, sourceDirStr, ":") + ":"
			string subList
			string subDirStr
			subFolders = IndexedDir($ImportpathStr, -1, 0)
			nFolders = itemsinList (subFolders, ";")
			for (iFolder =0; iFolder < nFolders; iFolder +=1)
				subDirStr = stringFromList (iFolder, subFolders, ";")
				NewPath /O/Q GuipListRecPath, sourceDirStr + subDirStr
				subList = GUIPListFiles ("GuipListRecPath",  fileTypeOrExtStr, matchStr, options, "", sepStr = sepStr)
				for (iFile=0, nFiles = itemsinList (subList, sepStr); iFile < nFiles; iFile +=1)
					returnList += subDirStr + ":" + stringFromList (iFile, subList, sepStr) + sepStr
					if ((options & 16) || (options & 32))
						iFIle +=1
						returnList += stringFromList (iFile, subList, sepStr) + sepStr
					endif
					if ((options & 16) && (options & 32))
						iFIle +=1
						returnList += stringFromList (iFile, subList, sepStr) + sepStr
					endif
				endfor

			endfor
		endif
	endif
	//  if no list was made, and this is the starting call, return user's error message
	if (strlen (returnList) < 2)
		return erString
	else
		return returnList
	endif
end