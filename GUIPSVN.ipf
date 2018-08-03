#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version = 0		/// Last Modified 2014/12/8 by Jamie Boyd
#pragma IgorVersion = 6
#pragma IndependentModule = GUIPSVN // we want this work while programming, when other things may fail to compile

#define isDebug		// does some extra printing to history window if defines

// *****************************************************************************
// Igor Pro procedures for uploading and downloading packages from svn repositories like IgorExchange via subversion (svn)
// subversion is open source.  You can compile it yourself or get a ready-to-go binary of the latest 
// version of subversion from the sources listed at https://subversion.apache.org/packages.html
// On OS X, subversion is (used to be?) pre-installed, but may not be the latest version
// On MS Windows, the installer package at http://sourceforge.net/projects/win32svn/ is nice
// If you already have the very useful TortoiseSVN installed (http://tortoisesvn.net), you already have the command line version

STATIC STRCONSTANT ksSVNPATH = ""
// Path to desired copy of subversion. Because it is possible (inevitable?) to have multiple different versions of subversion installed
// If GUIP_svnWhereIs() returns a path that you are happy with, you can leave this constant blank, in which case the copy of subversion specified
// by the order in which directories are listed in the path variable will be used.

STATIC CONSTANT kMacintosh =1
STATIC CONSTANT kWindows =0

Menu "Misc"
	Submenu "Subversion"
		"Locate Subversion",/Q, GUIPSVN#GUIP_svnCheckVersion ()
		Submenu "Igor Exchange"
			"Packages Notebook",/Q ,GUIPSVN#GUIP_svnRepNoteBook ("svn://svn.igorexchange.com/packages/", 0, "GUIP_svnPkgInfo_IgExch")
		end
	end
end

// ***********************************************************************************************
// ******************* Functions for finding copies of Subversion on the system and Getting Version Numbers*****************
// ***********************************************************************************************

// ***********************************************************************************************
// Finds the latest version of subversion on the machine, and suggests that the user sets the constant to select it
// Last modified 2014/11/06 by Jamie Boyd
function  GUIP_svnCheckVersion ()
	
	string versionAndLocStr=  GUIP_svnBestVersion ()
	string alertStr
	if (cmpStr (versionAndLocStr, "") == 0) // we've already  alerted user that we have no svn
		return 1
	else
		string defaultVersionStr = stringFromList (0, versionAndLocStr, ";")
		string defaultPath = stringFromList (1, versionAndLocStr, ";")
		string bestVersionStr = stringFromList (2, versionAndLocStr, ";")
		string bestPath = stringFromList (3, versionAndLocStr, ";")
		sprintf alertStr, "The latest subversion on this machine is %s at %s\r", bestVersionStr, bestPath
		if ((cmpStr (ksSVNPATH, "") ==0) && (cmpstr (bestPath, defaultPath) ==0)) // best version is default version
			alertSTr += "This version is already set to be used by default. Leave the string constant \"ksSVNPATH\" blank."
		elseif (cmpStr (bestPath, ksSVNPATH) == 0)
			alertStr += "This version is already selected to be used by the string constant \"ksSVNPATH\"."
		else
			putscraptext "STATIC STRCONSTANT ksSVNPATH = \"" + bestPath + "\"\r"
			Execute "SetIgorOption IndependentModuleDev=1"
			DisplayProcedure/W=$"GUIPSVN.ipf [GUIPSVN]"/L=15
			alertStr += " To use this version, paste the clipboard contents into \"GUIPSVN.ipf\", replacing the highlighted line."
		endif
		doAlert 0, alertStr
	endif
end

// *****************************************************************************
// returns directory of svn application as set by the PATH variable. This is the one you get when you type naked svn not preceded by a path
// Last Modified: 2014/11/06 by jamie Boyd
function/s GUIP_svnWhereIs()
	
	string shellCommand, shellResult, returnStr
	variable platform=kWindows
	if (cmpStr ( IgorInfo (2), "Macintosh") ==0)
		Platform =kMacintosh
	endif
	if (platform==kWindows)
		// On Windows, we don't get a return, so write output to a file
		String userPathIgor = SpecialDirPath("Igor Pro User Files", 0, 0, 0) // Igor style path to a writable location
		String userPathNative =  SpecialDirPath("Igor Pro User Files", 0, 1, 0) // "Native style" path to that location
		userPathNative = ReplaceString(" ", userPathNative, "^ ") // Escape spaces with carets
	endif
	try
		// Run the shell command, and On Windows, read the file for results
		If (Platform == kMacintosh)
			shellCommand = "do shell script \"whereis svn\""
#ifDef isDebug
			print shellCommand
#endif
			ExecuteScriptText shellCommand; ABORTONRTE
			shellResult = S_Value // On Mac, result is returned in S_Value
		elseIf (Platform == kWindows)
			sprintf shellCommand, "cmd.exe /C where svn > %sGUIPsvn.txt",  userPathNative // Use  > to pipe output to file
#ifdef isDebug
			print shellCommand
#endif
			ExecuteScriptText /B shellCommand;ABORTONRTE
			variable svnRef
			Open/R svnRef as userPathIgor + "GUIPsvn.txt" ; ABORTONRTE
			FReadLine svnRef, shellResult ; ABORTONRTE // all we care about is first line, because that is the one that will run with "naked" svn commandê
			close svnRef
		endif
	catch
		if (V_abortCode == -4) // run-time error
			variable error = GetRTError(1)
			string errMsg = GetErrMessage(error, 3)
			string procName = "GUIP_svnWhereIs"
			if (StringMatch(errMsg, "ExecuteScriptText*" ))
				printf "RTE %d from \"%s\" executing \"%s\"\r%s\r", error, ProcName, shellCommand, errMsg
				if (Platform == kWindows)
					FStatus svnRef
					if (V_flag)
						string aLine
						fsetpos svnRef, 0
						do
							FReadLine svnRef, aLine
							if (strLen (aLine) > 0)
								shellResult += aLine + "\r"
							else
								break
							endif
						while (1)
					endif
					close svnRef
				endif
				print shellResult
			elseif (StringMatch(errMsg, "Open*" ))
				printf "RTE %d from \"%s\" opening %s\r%s\r", error, ProcName, userPathIgor +"GUIPsvn.txt" , errMsg
			elseif (StringMatch(errMsg, "FReadLine*"))
				printf "RTE %d from \"%s\" reading %s\r%s\r", error, ProcName, userPathIgor +"GUIPsvn.txt" , errMsg
			else
				printf "RTE %d from \"%s\"\r%s\r", error, ProcName , errMsg
			endif
			DoAlert 0," GUIP_svnWhereIs() reported a Run Time Error, which was printed in the history window."
		endif
		return ""
	endtry
	// Process result
	if (strlen (shellResult) < 3)
		DoAlert 0, "subversion does not appear to be installed on this system."
		returnStr = ""
	else
		If (Platform == kMacintosh)
			 returnStr = removeEnding (shellResult [1, Strlen (shellResult)-2], "svn") // strip the beginning and ending quotes and remove svn to leave bare directory name
		elseIf (Platform == kWindows)
			returnStr = removeEnding (shellResult, "svn.exe\r") // strip svn.exe and line ending
		endif
	endif
	return returnStr
end

// *****************************************************************************
// returns directory of most recent version of svn found on the system, searching the locations listed in the PATH variable
// Last Modified 2014/11/06 by Jamie Boyd
function/s GUIP_svnBestVersion ()
	
	string shellCommand
	variable version, bestVersion =0, defaultVersion
	string pathsList, aPath, bestPath, defaultPath
	string versionDesc, versionStr, bestVersionStr,defaultVersionStr
	variable iPath, nPaths
	variable error
	string errMsg, procName = "GUIP_svnBestVersion" 
	// get platform
	variable platform=kWindows
	if (cmpStr ( IgorInfo (2), "Macintosh") ==0)
		Platform =kMacintosh
	endif
	// stuff for reading from the file for Windows
	if  (platform==kWindows)
		String userPathIgor = SpecialDirPath("Igor Pro User Files", 0, 0, 0) // Igor style path to place we wrote the file
		String userPathNative =  SpecialDirPath("Igor Pro User Files", 0, 1, 0) // "Native style" path to a writable location
		userPathNative = ReplaceString(" ", userPathNative, "^ ") // Escape spaces with carets
		variable svnRef
	endif
	// Get default path
	defaultPath= GUIP_svnWhereIs() // will also make text file on windows, will do an alert if svn not found
	if (CmpStr (defaultPath, "") ==0) // svn not present
		return ""
	endif
	try
		// get list of directories from PATH
		If (Platform == kMacintosh)
			sprintf shellCommand "do shell script \"echo $PATH\""
#ifdef isDebug
			print shellCommand
#endif
			ExecuteScriptText shellCommand; ABORTONRTE
			pathsList =  S_Value [1, Strlen (S_Value)-2]  // S_value is colon-separated list of native paths. Double-quoted
			pathsList = ReplaceString(":", pathsList, ";") + ";" // replace colons with semicolons, the way Howard intended it
		elseif (Platform == kWindows)
			// On Windows,  get list of directories from  file with all the locations, one per line, made with "where" command
			pathsList = ""
			Open/R svnRef as userPathIgor + "GUIPsvn.txt" ; ABORTONRTE
			do
				FReadLine svnRef, aPath ; ABORTONRTE 
				if (strlen(aPath) > 0)
					aPath = RemoveEnding (aPath, "\r")
					aPath = removeEnding  (aPath, "svn.exe")
					pathsList += aPath + ";"
				else
					break
				endif
			while (1)
			close svnref
		endif
		// add ksSVNPATH and default path to paths list, if not already there. 
		if ((Cmpstr (ksSVNPATH, "") != 0) && (WhichListItem(ksSVNPATH, pathsList, ";") ==-1))
			pathsList +=  ksSVNPATH + ";"
		endif
		if (WhichListItem(defaultPath, pathsList, ";") ==-1)
			pathsList += defaultPath + ";"
		endif
		// iterate through paths
		nPaths = itemsinList (pathsList, ";")
		for (iPath =0; iPath < nPaths; iPath+=1)
			try
				aPath= stringFromList (iPath, pathsList, ";")
				if (Platform == kMacintosh)
					sprintf shellCommand "do shell script \"%s/svn --version\"", aPath
#ifdef isDebug
					print shellCommand
#endif
					ExecuteScriptText shellCommand; ABORTONRTE
					versionDesc = S_Value [1, 100] // should be lots
				elseif (Platform == kWindows)
					sprintf shellCommand, "cmd.exe /C \"%ssvn\" --version > %sGUIPsvn.txt", aPath, userPathNative // Use  > to pipe output to file
#ifdef isDebug
					print shellCommand
#endif
					ExecuteScriptText /B shellCommand; ABORTONRTE
					Open/R svnRef as userPathIgor + "GUIPsvn.txt" ; ABORTONRTE
					FReadLine svnRef, versionDesc; ABORTONRTE // first line should be enough
					close svnRef
				endif
				// process versionDesc
				sscanf versionDesc, "svn, version %s (r%d)", versionStr, Version; ABORTONRTE
				printf "svn at %s is version %s, r%d\r", aPath, versionStr, version
				if (version > bestVersion)
					bestVersion = Version
					bestPath = aPath
					bestversionStr = versionStr
				endif
				if (CmpStr (aPath, defaultPath) ==0) // set defaults
					defaultVersion = version
					defaultVersionStr = VersionStr
				endif
			catch // catch No such file errors
				error = GetRTError(0)
				errMsg = GetErrMessage(error, 3)
				if (StringMatch(errMsg, "ExecuteScriptText*" ))
					if (platform == kMacintosh)
						string shellResult = S_Value [1, strlen (S_Value) -2]
					elseif (platform == kWindows)
						Open/R svnRef as userPathIgor + "GUIPsvn.txt" 
						FReadLine svnRef, shellResult
						close svnRef
					endif
					if (!(StringMatch (shellResult, "*svn: No such file or directory")))
						error = GetRTError(1)
						continue
					endif
				endif
			endtry
		endfor
		return defaultVersionStr +";" + defaultPath + ";"  + bestversionStr + ";" + bestPath
	catch
		if (V_abortCode == -4) // run-time error
			error = GetRTError(1)
			errMsg = GetErrMessage(error, 3)
			if (StringMatch(errMsg, "ExecuteScriptText*" ))
				printf "RTE %d from \"%s\" executing \"%s\"\r%s\r", error, ProcName, shellCommand, errMsg
				if (Platform == kWindows)
					FStatus svnRef
					if (V_flag)
						string aLine
						fsetpos svnRef, 0
						do
							FReadLine svnRef, aLine
							if (strLen (aLine) > 0)
								shellResult += aLine + "\r"
							else
								break
							endif
						while (1)
					endif
					close svnRef
				endif
				print shellResult
			elseif (StringMatch(errMsg, "Open*" ))
				printf "RTE %d from \"%s\" opening %s\r%s\r", error, ProcName, userPathIgor +"GUIPsvn.txt" , errMsg
			elseif (StringMatch(errMsg, "FReadLine*"))
				printf "RTE %d from \"%s\" reading %s\r%s\r", error, ProcName, userPathIgor +"GUIPsvn.txt" , errMsg
			else
				printf "RTE %d from \"%s\"\r%s\r", error, ProcName , errMsg
			endif
			DoAlert 0," GUIP_svnWhereIs() reported a Run Time Error, which was printed in the history window."
		endif
		return ""
	endtry
end

// ***********************************************************************************************
// ******************** Functions for Getting and Displaying Information on packages from a Repository *******************
// ***********************************************************************************************

// *****************************************************************************
// Cleans up the address of a repository, as for making a file name or a window name
// Last Modified 2014/11/14 by Jamie Boyd
Function/S  GUIP_svnCleanRepAddress (repAddress)
	string repAddress
	
	string cleanName = ReplaceString("svn:", repAddress, "")
	cleanName = ReplaceString("http:", cleanName, "")
	cleanName = ReplaceString("//", cleanName, "")
	cleanName = ReplaceString("svn.", cleanName, "")
	cleanname = RemoveEnding (cleanName, "/")
	cleanName = ReplaceString("/packages", cleanName, "")
	cleanName = ReplaceString(".com", cleanName, "")
	cleanName = ReplaceString(".org", cleanName, "")
	cleanName = CleanupName(cleanName, 0) 
	return cleanName
end

// *****************************************************************************
// Template for a function to get and print information about a package from some source other than svn, by scraping a separate web-page, e.g.
// Last Modified 2014/11/14 by jamie Boyd
Function GUIP_svnPkgInfo_template (repAddress, pkgName, notebookWin)
	string repAddress // adddress of repository where package is located. May not be that useful
	string pkgName  // name of package we want to get info for
	string notebookWin // notebook to print our info into
	
	return 1 // return 1 because we didn't print anything. 
end

// *****************************************************************************
// gets info from the igor exchange website on the given package, and prints it in the notebook
// Last Modified 2014/11/14 by jamie Boyd
Function GUIP_svnPkgInfo_IgExch(repAddress, pkgName, notebookWin)
	string repAddress // not used in this function
	string pkgName
	string notebookWin
	
	variable errVal = 0 // no error
	// get web page text
	String webPageText = FetchURL("http://www.igorexchange.com/project/" + pkgName)
	if ((CmpStr (webPageText, "Page not found" ) ==0) || (CmpStr (webPageText, "Access Denied" ) ==0))
		errVal =1
	else
		// find our package name, get longer name
		variable startPos = StrSearch (webPagetext, "<title>", 0)
		variable endPos = StrSearch (webPagetext, "</title>", endPos)
		string title = webPageText [startPos + 7, endPos -1]
		title = removeEnding (Title, " | IgorExchange") 
		// get first paragraph of information
		startPos = StrSearch(webPageText, "<p>", endPos) + 3
		endPos = StrSearch(webPageText, "</p>", startPos) - 1
		string description = webPageText [startPos, endPos]
		description = ReplaceString("\n",  description, "\r")
		// print info to notebook
		Notebook $notebookWin fSize =14, fstyle = 1, text=  title + "\r"
		Notebook $notebookWin fSize =12, fstyle = 0, text= description + "\r"
	endif
	return errVal
end


// *****************************************************************************
// gets info from the murphyLab wiki on the given package, and prints it in the notebook
// Last Modified 2014/11/26 by jamie Boyd
Function GUIP_svnPkgInfo_murphyLabWiki(repAddress, pkgName, notebookWin)
	string repAddress // not used in this function
	string pkgName
	string notebookWin
	
	variable errVal = 0 // no error
	// get web page text
	String webPageText = FetchURL("http://tmlab:TimMurphy@142.103.107.188/dokuwiki/doku.php?id=computing")
	print webPageText
end

// *****************************************************************************
// Returns a list of all the packages on a repository. Makes a text file on Mac OS as well as on Windows, because a file is more permanent
// LastModified 2014/11/09 by jamie Boyd
 function/S GUIP_svnPkgList (repAddress, beVerbose)
 	string repAddress // address of the repository, eg, svn://
 	variable beVerbose // Prints names, last mod dates, mod author, rev #  if verbose, else just prints names of packages 
	
	string shellCommand
	string verboseStr= SelectString((beVerbose) , "", "--verbose")
	variable error
	string errMsg, procName = "GUIP_svnPkgList" 
	String userPathIgor = SpecialDirPath("Igor Pro User Files", 0, 0, 0) // Igor style path to place we wrote the file
	String userPathNative =  SpecialDirPath("Igor Pro User Files", 0, 1, 0) // "Native style" path to a writable location
	variable svnRef
	string fileName
	string aPackage, packageList
	string revNum, author, revMonth,revDay,revYear, pkg
	// make a name for the file to write from repository  address
	//remove address junk
	filename = GUIP_svnCleanRepAddress (repAddress) + ".txt"
	// get platform
	variable platform=kWindows
	if (cmpStr ( IgorInfo (2), "Macintosh") ==0)
		platform =kMacintosh
	endif
	try
		if  (platform==kWindows)
			userPathNative = ReplaceString(" ", userPathNative, "^ ") // Escape spaces with carets
			sprintf shellCommand, "cmd.exe /C \"%ssvn\" list %s  %s > %s\"", ksSVNPATH, verboseStr, repAddress, userPathNative + fileName
		elseif(platform == kMacintosh)
			sprintf shellCommand, "do shell script \"%ssvn list %s %s > '%s'\"", ksSVNPATH, verboseStr, repAddress, userPathNative + fileName
		endif
#ifdef isDebug
		print shellCommand
#endif
		ExecuteScriptText/B shellCommand; ABORTONRTE
		Open/R svnRef as userPathIgor + fileName ; ABORTONRTE
		packageList = ""
		if (beVerbose)
			do 
				FReadLine svnRef, aPackage; ABORTONRTE 
				if (strlen (aPackage) > 0)
					sscanf aPackage, " %s %s %s %s %s %s ", revNum, author, revMonth,revDay, revYear, pkg
					if (cmpStr (pkg, "./") ==0)
						continue
					 else
					 	if (GrepString(revYear, "[0-9]2:[0-9]2")) // not a year, but a time, so year is current year
					 		revYear = stringFromlist (0, secs2date (dateTime, -2), "-")
					 	endif
					 	packageList += removeEnding (pkg, "/") + "\t" + author + "\t" + revNum + "\t" + revYear + "-" + revMonth + "-" + revDay + "\r" 
					 endif
				else
					break
				endif
			while (1)
		else
			do 
				FReadLine svnRef, aPackage; ABORTONRTE 
				if (strlen (aPackage) > 0)
					packageList += removeEnding (aPackage, "/\r") + "\r"
				else
					break
				endif
			while (1)
		endif
		packageList = SortList (packageList, "\r")
	catch
		if (V_abortCode == -4) // run-time error
			error = GetRTError(1)
			errMsg = GetErrMessage(error, 3)
			if (StringMatch(errMsg, "ExecuteScriptText*" ))
				printf "RTE %d from \"%s\" executing \"%s\"\r%s\r", error, ProcName, shellCommand, errMsg
				FStatus svnRef
				if (V_flag)
					string aLine, shellResult = ""
					fsetpos svnRef, 0
					do
						FReadLine svnRef, aLine
						if (strLen (aLine) > 0)
							shellResult += aLine + "\r"
						else
							break
						endif
					while (1)
				endif
				close svnRef
				print shellResult
			elseif (StringMatch(errMsg, "Open*" ))
				printf "RTE %d from \"%s\" opening %s\r%s\r", error, ProcName, userPathIgor + fileName , errMsg
			elseif (StringMatch(errMsg, "FReadLine*"))
				printf "RTE %d from \"%s\" reading %s\r%s\r", error, ProcName, userPathIgor + fileName , errMsg
			else
				printf "RTE %d from \"%s\"\r%s\r", error, ProcName , errMsg
			endif
			DoAlert 0," GUIP_svnWhereIs() reported a Run Time Error, which was printed in the history window."
		endif
		return ""
	endtry
	return packageList
end

// ********************************************************************************
// Makes a nicely formatted notebook showing all the packages on a repository
// Last Modified 2014/11/17 by Jamie Boyd
Function GUIP_svnRepNoteBook(repAddress, tagsAndBranches, infoFuncName)
	string repAddress // address of the repository
	variable tagsAndBranches // if not set, shows only root, else shows tags and branches
	string infoFuncName // name of a function that will get some info for each package, by scraping a webpage perhaps, and print it in the notebook
	
	// make function reference for special function to get extra package info
	funcref  GUIP_svnPkgInfo_template GetPkgInfo = $infoFuncName
	// get list of packages, with --verbose option if not going to do all tags and branches
	string packageList = GUIPSVN#GUIP_svnPkgList (repAddress, !(TagsAndBranches))
	if (strlen (packageList) < 2)
		doAlert 0, "No packages were found, so no notebook was created."
	endif
	variable iPackage, nPackages = itemsinList (packageList, "\r")
#ifdef isDeBug // no need to do the whole thing
	nPackages= min (nPackages, 10)
#endif
	// make a new notebook window, closing an old one that might be open
	string notebookWin =GUIPSVN#GUIP_svnCleanRepAddress (repAddress)
	if (itemsinlist(winlist(notebookWin,";","WIN:16"))>0)
		killwindow $notebookWin
	endif
	newnotebook /f=1/k=1/n=$notebookWin as notebookWin + " Packages"
	notebook $notebookWin fSize =16, fstyle = 5, text= "Packages on the SVN Repository \"" + repaddress + "\"\r\r"
	// make an entry for each package
	string aPackage, pkgName, actionStr
	variable getInfoResult
	for (iPackage =0; ipackage < npackages; iPackage +=1)
		aPackage = stringFromList (iPackage, packageList, "\r")
		pkgName = stringfromlist (0, aPackage, "\t")
		getInfoResult = GetPkgInfo (repAddress, pkgName, notebookWin)
		if (getInfoResult)
			Notebook $notebookWin fSize =14, fstyle = 1, text= "package:" +pkgName + "\r"
		else
			Notebook $notebookWin fSize =12, fstyle = 0, text= "package:" + pkgName + "\r"
		endif
		if (tagsAndBranches)
			GUIP_svnTagAndBranchInfo (repAddress + aPackage, notebookWin)
		else
			Notebook $notebookWin fSize =12, fstyle = 0, text= "author:" + stringfromlist (1, aPackage, "\t") + "\r"
			Notebook $notebookWin fSize =12, fstyle = 0, text= "revision:" + stringfromlist (2, aPackage, "\t") + "\r"
			Notebook $notebookWin fSize =12, fstyle = 0, text= "date:" + stringfromlist (3, aPackage, "\t") + "\r"
			sprintf actionStr, "GUIPSVN#GUIP_svnTagAndBranchInfo (\"%s\", \"%s\")", repAddress + pkgName, notebookWin
			NotebookAction /W=$notebookWin commands = actionStr, title = "get more info on \"" + pkgName  + "\" with subversion" 
		endif
		notebook $notebookWin text = "\r\r"
	endfor
end

// *****************************************************************************
// Prints into the NoteBook some info for a Package. For each branch, trunk, and tag folder within the package,
// author, modification dates, etc. are printed, plus a notebook action to checkout that branch or tag are added to the notebook
// Last Modified 2014/11/19 by Jamie Boyd
Function GUIP_svnTagAndBranchInfo (repAddress,  theNoteBook)
	string repAddress  // address to a package, something like svn://svn.igorexchange.com/packages/GUIP/
	string theNoteBook // name of notebook to print tags and branches info
	
	string shellCommand
	string svnResult
	// get platform
	variable platform=kWindows
	if (cmpStr ( IgorInfo (2), "Macintosh") ==0)
		Platform =kMacintosh
		Sprintf shellCommand  "do shell script \"%ssvn info --recursive --depth immediates '%s'\"", ksSVNPATH, repAddress
#ifdef isDebug
	print shellCommand
#endif
	ExecuteScriptText shellCommand; abortonrte
	svnResult = S_Value
	endif
	// stuff for reading from the file for Windows
	if  (platform==kWindows)
		String userPathIgor = SpecialDirPath("Igor Pro User Files", 0, 0, 0) // Igor style path to place we wrote the file
		String userPathNative =  SpecialDirPath("Igor Pro User Files", 0, 1, 0) // "Native style" path to a writable location
		userPathNative = ReplaceString(" ", userPathNative, "^ ") // Escape spaces with carets			
		Sprintf shellCommand "cmd.exe /C \"%ssvn info --recursive --depth immediates %s >  %s\"", ksSVNPATH , repAddress, userPathNative + "svn.txt"
#ifdef isDebug
		print shellCommand
#endif
		ExecuteScriptText/B  shellCommand; abortonrte
		variable svnRef
		Open/R svnRef as userPathIgor + "svn.txt" ; ABORTONRTE
		FStatus svnRef
		svnResult = PadString(svnResult, V_logEOF, 0x20)
		FBinRead svnRef, svnResult
	endif
	// svnResult contains listing of all directories at repaddressor tags and branches
	//get name of current directory, last part of rep address
	variable nLevels = itemsInList (repAddress, "/")
	string thisDir = stringFromList (nLevels-1, repAddress, "/")
	thisDIr = ReplaceString("%20", thisDir, " ")
	string thisInfo, thisUrl, thisPath
	variable startPos, endPos=0
	string containingDir
	// iterate through list of directories, looking for trunks, tags, and branches
	do
		startPos = strsearch(svnResult, "Path: ", endPos)
		if (startPos == -1)
			break
		else
			endPos = strsearch (svnResult, "\r\r", startPos)
			if (endPos == -1)
				endPos = strlen (svnResult) -1
			endif
			thisInfo = GUIP_svnParseInfo (svnResult [StartPos, endPos])
			if (CmpStr (stringbykey ("node kind", thisInfo, ":", "\r"), "directory") ==0)
				thisPath =  stringbykey ("path", thisInfo, ":", "\r")
				thisURL = stringbykey ("URL", thisInfo, ":", "\r")
				nLevels = ItemsInList (thisURL, "/")
				containingDir = StringFromList(nLevels-2, thisURL, "/")
				// we only want to show branches and tags, not other folder structure
				if (((cmpStr (thisDir, "trunk") ==0) || (cmpStr (containingDir, "tags") ==0)) ||  (cmpStr (containingDir, "branches") ==0))
					if ((cmpStr (thisDir, "tags") !=0) && (cmpStr (thisDir, "branches") !=0))  
						notebook $theNoteBook fSize =12, fstyle = 0, text= thisInfo
						NotebookAction /W=$theNoteBook commands = "GUIPSVN#GUIP_svnCheckoutOrExport (\"" + thisURL + "\")", title = "CheckOut " + stringbykey ("path", thisInfo, ":", "\r") + " with subversion" 
						notebook $theNoteBook fSize =12, fstyle = 0, text ="\r\r"
					endif
				endif
				if (CmpStr (thisDir, thisPath) !=0) // this folder.
					GUIP_svnTagAndBranchInfo (thisURL , theNoteBook)
				endif
			endif
		endif
	while (1)
end

// *****************************************************************************
// Copies the information we are interested in from the info string produced by subversion
// Last modified 2014/11/16 by Jamie Boyd
Function/S GUIP_svnParseInfo (thisInfo)
	string thisInfo
	
#ifdef isDebug
	print thisInfo
#endif
	string revision = stringByKey("Revision", thisInfo, ":" , "\r")
	string Path =  StringByKey ("Path", thisInfo, ":", "\r")
	string author = StringByKey ("Last Changed Author", thisInfo, ":", "\r")
	string changeDate = StringByKey ("Last Changed Date", thisInfo, ":", "\r")
	string nodeKind = StringByKey ("Node Kind", thisInfo, ":", "\r")
	string url =  StringByKey ("URL", thisInfo, ":", "\r")
	
	variable startPos=strsearch (changeDate, "(", 0) + 1
	variable endPos = strsearch (changeDate, ")", startPos) -1
	changeDate = changeDate [startPos, endPos]
	string outStr ="path:" + path[1, strlen (path)-1] + "\r"
	outStr += "author:" + author[1, strlen (author)-1] + "\r"
	outStr += "date:" + changeDate + "\r"
	outStr +=  "revision:" + revision [1, strlen (revision)-1] + "\r"
	outStr +=  "node kind:" + nodeKind [1, strlen(nodeKind)-1] + "\r"
	outStr += "URL:" + url [1, strlen (url)-1] + "\r"
	return outStr
end

// ***********************************************************************************************
// ********Exports or Checks Out a package from the given repository and puts all the code in the requested directory*************
// ***********************************************************************************************

// Last Modified 2014/12/08 by Jamie Boyd
function GUIP_svnCheckoutOrExport (repository_pkg, [isExport, directory])
	string repository_pkg
	variable isExport
	string directory
	
	string shellCommand
	variable error
	string errMsg, procName = "IgorSVN_Checkout" 
	variable svnRef
	string WCpath, igorPath, pkgName
	// get platform
	variable platform=kWindows
	if (cmpStr ( IgorInfo (2), "Macintosh") ==0)
		platform =kMacintosh
	endif
	// checkout or export ?
	string actionString
	Prompt actionString, "Do you want to checkout a working copy or just export the code?", popup, "checkout;export"
	if (!(ParamIsDefault(directory )))
		doPrompt "Checkout or Export?", actionString
		if (V_Flag)
			return 1
		endif
	else	
		actionString = SelectString((isExport) , "checkout", "export")
	endif
	pkgName = stringfromlist (itemsinlist(repository_pkg, "/") -1, repository_pkg, "/")
	igorPath = cleanupname (pkgName, 0) + "_Path"
	if (ParamIsDefault(directory ))
		string MsgString = SelectString((isExport) , "new working copy of ", "exported files from ")
		NewPath /O/M= "Select directory to contain " + MsgString + pkgName +  "." $igorPath
		if (V_Flag)
			return 1
		endif
		PathInfo $igorPath
		WCPath= S_path + pkgName
	else
		WCPAth = removeEnding (directory, ":") + ":" + pkgName
	endif
	try
		if  (platform==kWindows)
			String userPathIgor = SpecialDirPath("Igor Pro User Files", 0, 0, 0) // Igor style path to place we wrote the file
			String userPathNative =  SpecialDirPath("Igor Pro User Files", 0, 1, 0) // "Native style" path to a writable location
			string aLine
			userPathNative = ReplaceString(" ", userPathNative, "^ ") // Escape spaces with carets
			WCPath = ReplaceString (":", WCPath, "\\")
			WCPath = ReplaceString ("\\", WCPath, ":\\", 1)
			sprintf shellCommand, "cmd.exe /C \"%ssvn\" %s %s  %s > %s\"", ksSVNPATH, actionString, repository_pkg, WCPath, userPathNative + "svn.txt"
#ifdef isDebug
			print shellCommand
#endif
			ExecuteScriptText/B shellCommand; ABORTONRTE
			// show results, i.e. which files were added
			Open/R svnRef as userPathIgor + "svn.txt" ; ABORTONRTE
			do 
				FReadLine svnRef, aLine; ABORTONRTE 
				if (strlen (aLine) > 0)
					print aLine
				else
					break
				endif
			while (1)
		elseif(platform == kMacintosh)
			WCPath = ":" + RemoveListItem(0, WCPath, ":")
			WCPath = ReplaceString (":", WCPath, "/")
			sprintf shellCommand, "do shell script \"%ssvn %s %s '%s'\"", ksSVNPATH, actionString, repository_pkg, WCPath
#ifdef isDebug
			print shellCommand
#endif
			ExecuteScriptText shellCommand; ABORTONRTE
			// show result
			print S_Value // show results, i.e. which files were added
		endif
	catch
		if (V_abortCode == -4) // run-time error
			error = GetRTError(1)
			errMsg = GetErrMessage(error, 3)
			if (StringMatch(errMsg, "ExecuteScriptText*" ))
				printf "RTE %d from \"%s\" executing \"%s\"\r%s\r", error, ProcName, shellCommand, errMsg
				if(platform == kWindows)
					FStatus svnRef
					if (V_flag)
						string shellResult = ""
						fsetpos svnRef, 0
						do
							FReadLine svnRef, aLine
							if (strLen (aLine) > 0)
								shellResult += aLine + "\r"
							else
								break
							endif
						while (1)
					endif
					close svnRef
					print shellResult
				elseif (platform == kMacintosh)
					print S_Value
				endif
			elseif (StringMatch(errMsg, "Open*" ))
				printf "RTE %d from \"%s\" opening %s\r%s\r", error, ProcName, userPathIgor + "svn.txt" , errMsg
			elseif (StringMatch(errMsg, "FReadLine*"))
				printf "RTE %d from \"%s\" reading %s\r%s\r", error, ProcName, userPathIgor + "svn.txt" , errMsg
			else
				printf "RTE %d from \"%s\"\r%s\r", error, ProcName , errMsg
			endif
			DoAlert 0, ProcName + " reported a Run Time Error, which was printed in the history window."
		endif
		return 1
	endtry
	return 0
end

// ***********************************************************************************************
// ************************** Code that Works with Local Repositories*****************************************
// ***********************************************************************************************

// ***********************************************************************************************
// Gets status info on the Working Copy (but not the Repository) and prints it in the history
function/S IgorSVN_Status (PathName, pkg, noteBookName)
	string pathName // name of an Igor Path pointing to the containing folder of the package
	string pkg
	string noteBookName
	
	string shellCommand
	variable error
	string errMsg, procName = "IgorSVN_Status" 
	variable svnRef
	String WCPath, pkgName
	// get platform
	variable platform=kWindows
	if (cmpStr ( IgorInfo (2), "Macintosh") ==0)
		platform =kMacintosh
	endif
	
//	The first seven columns in the output are each one character wide:
//	First column: Says if item was added, deleted, or otherwise changed
//      ' ' no modifications												"UnModified"
//      'A' Added															"Added"
//      'C' Conflicted														"Conflicted"
//      'D' Deleted														"Deleted"
//      'I' Ignored															"Ignored"
//      'M' Modified														"Modified"
//      'R' Replaced														"Replaced"
//      'X' an unversioned directory created by an externals definition		"Ext Dir"
//      '?' item is not under version control								"UnVersioned"
//      '!' item is missing (removed by non-svn command) or incomplete	"Missing/Inc"
//      '~' versioned item obstructed by some item of a different kind		"Obstructed"

//    Second column: Modifications of a file's or directory's properties
//      ' ' no modifications
//      'C' Conflicted
//      'M' Modified

//    Third column: Whether the working copy directory is locked
//      ' ' not locked
//      'L' locked
//    Fourth column: Scheduled commit will contain addition-with-history
//      ' ' no history scheduled with commit
//      '+' history scheduled with commit
//    Fifth column: Whether the item is switched or a file external
//      ' ' normal
//      'S' the item has a Switched URL relative to the parent
//      'X' a versioned file created by an eXternals definition
//    Sixth column: Repository lock token
//      (without -u)
//      ' ' no lock token
//      'K' lock token present
//      (with -u)
//      ' ' not locked in repository, no lock token
//      'K' locked in repository, lock toKen present
//      'O' locked in repository, lock token in some Other working copy
//      'T' locked in repository, lock token present but sTolen
//      'B' not locked in repository, lock token present but Broken
//    Seventh column: Whether the item is the victim of a tree conflict
//      ' ' normal
//      'C' tree-Conflicted
//    If the item is a tree conflict victim, an additional line is printed
//    after the item's status line, explaining the nature of the conflict.
//
//  The out-of-date information appears in the ninth column (with -u):
//      '*' a newer revision exists on the server
//      ' ' the working copy is up to date

printf "%- 13s%- 13s%- 13s%- 13s%- 13s%- 13s%- 13s\r", "File Modded", "Properties", "WC Locked", "History", "Switch/Ext", "Repo Lock", "Tree Status"
	
string result = "                43       43 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/ExpName.ipf\r"
result +="                 45       45 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIP.ihf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPBackgrounder.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPControls.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPDSD.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPDirectoryLoad.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPDirectoryLoadLSM.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPDirectoryLoadTiffs.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPHist.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPKillDisplayedWave.ipf\r"
result +="                 44       44 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPList.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPMath.ipf\r"
result +=" M               45       45 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPSVN.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPSubWinUtils.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPWinPos.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/GUIPprotoFuncs.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/Offsetter.ipf\r"
result +="                 43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/PXPprocessor.ipf\r"
 result +="                43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/SharedWavesManager.ipf\r"
 result +="                43        1 jamie        /Users/jamie/Documents/WaveMetrics/murphylabSVN/GUIP/trunk/TIFFwriter.ipf\r"
	
	
	
	variable  iItem, nItems = itemsInList (result, "\r")
	string anItem, outputStr, valStr
	variable iCol
	for (iItem =0; iITem < nItems; iItem += 1)
		anItem = stringFromList (iItem, result, "\r")
		// column 0, added, deleted, or otherwise changed
		valStr = anItem [0]
		StrSwitch (valStr)
			case " ": 
				printf "%- 13s","------------"
				break
			case "A": 
				printf "%- 13s", "Added"
				break
			case "C": 
				printf "%- 13s", "Conflicted"
				break
			case "D":
				printf "%- 13s", "Deleted"
				break
			case "I":
				printf "%- 13s", "Ignored"
				break
			case "M":
				printf "%- 13s", "Modified"
				break
			case "R":
				printf "%- 13s", "Replaced"
				break
			case "X":
				printf "%- 13s", "Ext Dir"
				break
			case "?":
				printf "%- 13s", "Unversioned"
				break
			case "!":
				printf "%- 13s", "Missing/Inc"
				break
			case "~":
				printf "%- 13s", "Obstructed"
				break
		endSwitch
		// column 1, Properties changed
		valStr = anItem [1]
		StrSwitch (valStr)
			case " ": 
				printf "%- 13s", "------------"
				break
			case "C": 
				printf "%- 13s", "Conflicted"
				break
			case "M": 
				printf "%- 13s", "Modified"
				break
		endSwitch
		// column 2 Whether the working copy directory is locked
		valStr = anItem [2]
		StrSwitch (valStr)
			case " ": 
				printf "%- 13s", "------------"
				break
			case "L":
				printf "%- 13s", "Locked"
				break
		endSwitch
		// Column 3  Scheduled commit will contain addition-with-history
		valStr = anItem [3]
		StrSwitch (valStr)
			case " ": 
				printf "%- 13s","------------"
				break
			case "+":
				printf "%- 13s", "Commit"
				break
		endSwitch
		//   Fifth column: Whether the item is switched or a file external
		//      ' ' normal
		//      'S' the item has a Switched URL relative to the parent
		//      'X' a versioned file created by an eXternals definition
		valStr = anItem [4]
		StrSwitch (valStr)
			case " ": 
				printf "%- 13s","------------"
				break
			case "S":
				printf "%- 13s","Switched URL"
				break
			case "X":
				printf "%- 13s","Externals Def"
				break
		endSwitch
		//    Sixth column: Repository lock token
		//      (without -u)
		//      ' ' no lock token
		//      'K' lock token present
		valStr = anItem [5]
		StrSwitch (valStr)
			case " ": 
				printf "%- 13s","------------"
				break
			case "K":
				printf "%- 13s","Lock Token"
				break
		endSwitch
		//    Seventh column: Whether the item is the victim of a tree conflict
		//      ' ' normal
		//      'C' tree-Conflicted
		valStr = anItem [6]
		StrSwitch (valStr)
			case " ": 
				printf "%- 13s","------------"
				break
			case "C":
				printf "%- 13s", "Tree Conflict"
				break
		endSwitch
		
		printf "\r"
	endfor
	return ""
end

	try
		if  (platform==kWindows)
			
		
	string dirPathNative = SpecialDirPath("Igor Pro User Files", 0, 1, 0 ) +  "User Procedures/" + pkg
	string UnixCommandStr
	sprintf UnixCommandStr "%s/svn status -v '%s'", ksSVNPATH,  dirPathNative
	
	string igorCmd
	sprintf igorCmd, "do shell script \"%s\"", UnixCommandStr
	ExecuteScriptText igorCmd
	return S_value
end


// *****************************************************************************
// Checks Out a package from the IgorExchange repositiry and puts all the code in the User Procedures folder
GUIP_svnIgExCheckout (pkg, [directory])
	
	GUIP_svnCheckout (repository, pkg, [directory])

end


function GUIP_svnUpdate(pkgDirectory)
	string pkgDirectory
	
	
end
//	DoAlert 1,"Close all procedure files, update, and reload them?  Unsaved changes to procedure files will be lost."
//	Variable i
//	if(V_flag==1)		
//                String cmdList=CloseAllProcs(exec=0); // Generate a list of procedure closing commands.  For some reason directly executing CloseAllProcs(exec=1) in the execute queue doesn't work correctly.  
//		for(i=0;i<ItemsInList(cmdList);i+=1)
//			String cmd=StringFromList(i,cmdList)
//			Execute /Q/P cmd // Execute each procedure closing.  
//		endfor
		string cmd="TortoiseProc /command:update /path:"
		String codePath="C:\Users\jamieVB\Documents\WaveMetrics\Igor Pro 6 User Files\User Procedures\ChrMapper"
		NewPath /O/Q CodePath, codePath
		ExecuteScriptText cmd + "\\\""+codePath+"\"" // Run the SVN update.  Extra slashes needed to escape the quotes in the command.  
		
	//	Execute /Q/P "OpenProc /P=CodePath /V=1 \"Master.ipf\"" // Assume that master.ipf will #include the other procedure files.  
	//	Execute /Q/P "Silent 101" // Recompile.  
//	endif
End
 
Function /S CloseAllProcs([except,exec])
	String except
	Variable exec
 
	if(ParamIsDefault(except))
		except=""
	endif
	exec=ParamIsDefault(exec) ? 1 : exec
	Execute /Q "SetIgorOption IndependentModuleDev=1"
	String currProcs=WinList("*",";","WIN:128,INDEPENDENTMODULE:1")
	Variable i=0
	String cmdList=""
	for(i=0;i<ItemsInList(currProcs);i+=1)
		String procName=StringFromList(i,currProcs)
		Variable pos=strsearch(procName,"[",0)
		if(pos>=0) // If this has an independent module name. 
			procName=procName[0,pos-2]// Truncate it to be compatible with CloseProc.  
		endif
		if(WhichListItem(except,procName)>=0)
			continue // Do not close procedures on the except list.  
		endif
		if(StringMatch(procName,"Procedure"))
			continue // Do not close experiment procedure file.  
		endif
 
		String cmd
		sprintf cmd, "CloseProc /NAME=\"%s\"",procName
		if(exec)
			Execute /Q/P cmd
		endif
		cmdList+=cmd+";"
	endfor
	Execute /Q "SetIgorOption independentModuleDev=0"
	if(exec)
		Execute /Q/P "Silent 101"
	endif
	return cmdList
End

