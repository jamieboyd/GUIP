#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName = SaveExpName

// Makes a variable called ExpFileName in the packages folder.  Saves the name of the experiment there
// everytime you save the experiment.
Static Function BeforeExperimentSaveHook(refNum,fileName,pathName,type,creator,kind)
	Variable refNum,kind
	String fileName,pathName,type,creator
	
	if (!(DatafolderExists ("Root:packages")))
		NewDataFolder root:packages
	endif
	
	String/G root:packages:ExpFileName
	SVAR ExpFileName =root:packages:ExpFileName
	ExpFileName = RemoveEnding(fileName,".pxp" )
End
