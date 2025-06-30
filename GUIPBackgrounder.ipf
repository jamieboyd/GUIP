#pragma rtGlobals=2		// Use modern global access method.
#pragma IgorVersion = 5.05
#pragma version = 1.1 //last modified 2013/11/17 by Jamie Boyd
//#pragma ModuleName =GUIP

// A simple background task manager for Igor Pro 5. A global background task runs every tick (60 times a second)
// and iterates through a task list stored in a global string. Each task in the list has an associated value for how often it
// should be called, and when it was last called.

// taskname;parameterlist (comma separated);howOften to call task (in ticks);last Time task was called (in Ticks)


//Function GUIPbkg_AddTask(theTask, HowOften)
//	string theTask
//	variable howOften

// theTask is called with the execute operation, so it needs to be made into a string you could type at the command line and have it work, 
// To make it easier for using functions as inputs, the function name and its parameters can be entered separately

// howOften controls how often the task is called, in Hz.

// A value of 1 means that the corresponding task is run every time
// the global background task runs. A value of 2 means every other time or 30 times/second, and so forth. 
//  Note that if a frequently called task is taking too long to
// execute, it will slow down calls of infrequently called tasks, as timing is based on number of invocations of the
// background task.  If absolute timing is important to you, have your background task set howOften to 1 and call
// stopMSTimer(-1 ), comparing the result to that of a previous call stored in a global variable.
// Bottom line: Keep your background tasks quick.

// To remove a task from the task list global string, and stop the global background task if there are no other tasks, 
// use this function:
//Function GUIPbkg_RemoveTask(theTask)
//	string theTask
// New background tasks can be added to and and old background tasks removed from the list without stopping the global background task. 

// Details: The list of tasks is stored in a global string, root:packages:GUIPbkg_BackGrounder:tasklist. Each item in the task list contains a
// procedure to execute (using the execute command) and how often the task should be called.  The string format is:
// taskname1=howOften1;taskName2=howOften2  . 
//To stop the global background task, but keep all the tasks in the list, call GUIPbkg_Stop () which sets the
// global variable root:packages:GUIPbkg_BackGrounder:bgkStop to 1. To restart GUIPbkg_BackGrounder after thusly stoppng it, call GUIPbkg_Run()

//******************************************************************************************************
// add a task to the list of tasks and start the background task, if neccessary
// can also use this function to change interval for the background task
// Last Modified 2013//11/17 by Jamie Boyd
Function GUIPbkg_AddTask(newTask, taskFreq, removeOld, [funcParamList])
	string newTask
	variable taskFreq		// How often to calll the task, in Hz
	variable removeOld		// set to overwrite old coupies of the task, based on function name
	string funcParamList 	// Use for functions, comma-separated list of parameters. pass empty string for functions  with no paramaters.
	// Don't use paramList for executing simple commands
	
	// reference global task list string
	SVAR/Z taskList=root:packages:GUIPbackGrounder:tasklist
	// if this task already exists in the list, remove it so new version will overwrite old
	string aTaskEntry, aTask, lastTask
	variable iTask, nTasks, nextTaskNum
	if (SVAR_EXISTS (taskList))
		nTasks = itemsinlist (taskList, "\r")
		if (removeOld)
			for (iTask = nTasks -1; iTask >= 0; iTask -=1)
				aTaskEntry = stringFromList (iTask, taskList, "\r")
				aTask=  stringfromlist (0, aTaskEntry, ";")  // aTask will be something like "task0" or "task1"
				SVAR taskGStr = $"root:packages:GUIPbackGrounder:" + aTask
				if (CmpStr (newTask, taskGStr)==0)
					taskList = RemoveListItem(iTask, taskList, "\r")
					KillStrings taskGStr
					NVAR taskGvar = $"root:packages:GUIPbackGrounder:" + aTask + "nextTicks"
					KillVariables nextTicks
				endif
			endfor
		endif
		lastTask = stringFromList (0, stringFromList (nTasks -1, taskList, "\r"), ";")
		nextTaskNum = str2num (lastTask [4, strlen (lastTask)-1]) + 1
		if (numtype (nextTaskNum) != 0)
			nextTaskNum = 0
		endif
	else // make packages folder with new empty global string for the taskList
		GUIPbkg_Init ()
		SVAR taskList=root:packages:GUIPbackGrounder:tasklist
		nextTaskNum =0
	endif
	// make a string containing new task
	String newTaskStrName = "task" + num2str (nextTaskNum)
	String/G $"root:packages:GUIPbackGrounder:" + newTaskStrName = newTask
	// add the new entry to the taskList
	taskList += newTaskStrName + ";"
	if (ParamIsDefault(funcParamList))
		taskList += ";"
	else
		taskList += "(" + funcParamList + ");"
	endif
	// translate taskFreq (Hz) to ticks
	taskList += num2str (round(60/taskFreq)) + ";\r"
	// Set next ticks to now - globalStart - taskTicks, so new task fires start right away
	NVAR globalStart = root:packages:GUIPbackGrounder:GlobalStart
	Variable/G $"root:packages:GUIPbackGrounder:" + newTaskStrName + "nextTicks" = ticks - globalStart
	// ensure global task is running
	GUIPbkg_Run()
end

//******************************************************************************************************
//removes a task from the task list global string, and stops the background task if there are no more tasks
// theTask has to match the task you entered, and, optionally, also match the funcParamList and/or the taskFreq
// Last modified 2013/11/17  by Jamie Boyd
Function GUIPbkg_RemoveTask(remTask, [funcParamList,taskFreq])
	string remTask
	string funcParamList
	variable taskfreq
	
	SVAR/Z taskList=root:packages:GUIPbackGrounder:tasklist
	if (!(SVAR_EXISTS (taskList)))
		return 0
	endif
	
	string funcParamMatchStr, taskFreqMatchStr
	if (ParamIsDefault (funcParamList))
		funcParamMatchStr = "*"
	else
		funcParamMatchStr = "(" + funcParamList + ")"
	endif
	
	if (ParamIsDefault (taskFreq))
		taskFreqMatchStr = "*"
	else
		taskFreqMatchStr =num2str (round(60/taskFreq))
	endif
	variable iTask, nTasks = ItemsInList (taskList, "\r")
	string aTaskEntry, aTask, aParamList, aTaskFreq
	for (iTask = nTasks -1; iTask >= 0; iTask -=1)
		aTaskEntry = stringFromList (iTask, taskList, "\r")
		aTask=  stringfromlist (0, aTaskEntry, ";")  // aTask will be something like "task0" or "task1"
		SVAR taskGStr = $"root:packages:GUIPbackGrounder:" + aTask
		if (CmpStr (remTask, taskGStr) !=0)
			continue
		endif
		aParamList = stringfromlist (1, aTaskEntry, ";")
		if (StringMatch (aParamList, funcParamMatchStr) == 0)
			continue
		endif
		aTaskFreq = stringfromlist (2, aTaskEntry, ";")
		if (StringMatch (aTaskFreq, taskFreqMatchStr) == 0)
			continue
		endif
		// if we got to here, we can remove the task
		taskList = RemoveListItem(iTask, taskList, "\r")
		KillStrings taskGStr
		NVAR nextTicks = $"root:packages:GUIPbackGrounder:" + aTask + "nextTicks"
		KillVariables nextTicks
	endfor
	if (itemsinlist (taskList, "\r") == 0)
		GUIPbkg_Stop ()
	endif
end

//******************************************************************************************************
//Ensure existence of needed globals
// last Modified 2013//11/17  by Jamie Boyd
Static Function GUIPbkg_Init()	
	
	if (!(datafolderexists ("root:packages")))
		newdatafolder root:packages
	endif
	if (!(datafolderexists("root:packages:GUIPbackGrounder")))
		newdatafolder root:packages:GUIPbackGrounder
	endif
	// List of tasks to call
	string/G root:packages:GUIPbackGrounder:tasklist = ""
	// signal to stop background task
	variable/G root:packages:GUIPbackGrounder:bgkStop = 0
	// times for calling each task are determined relative to a starting time, because ticks
	// returns time since computer started up, and that can be many days, so the tick numbers get ugly big
	variable/G root:packages:GUIPbackGrounder:GlobalStart =ticks
end

//******************************************************************************************************
// ensure the correct background task is running or give an error message
// last Modified 2013//11/17  by Jamie Boyd
Static Function GUIPbkg_Run()
	
	SVAR/Z taskList=root:packages:GUIPbackGrounder:tasklist
	if (!(SVAR_EXISTS (taskList)))
		GUIPbkg_Init ()
	endif
	BackgroundInfo
	switch (V_Flag)
		case 0: // No background task defined
			SetBackground GUIPbkg_BackGrounder()
			CtrlBackground period=1, noBurst=1,start
			break
		case 1:  // A task is defined but not running. If it is our task, re-start it, else alert
			if ((cmpstr (S_Value, "GUIPbkg_BackGrounder()")) == 0)
				NVAR bkgStop =root:packages:GUIPbackGrounder:bgkStop
				bkgStop = 0
				CtrlBackground period=1, noBurst=1,start
			else
				doalert 1, "A background task, " + S_value + ", is already defined, but is not running. Kill it and start GUIP backgrounder?"
				if (V_Flag ==1) // yes
					SetBackground GUIPbkg_BackGrounder()
					CtrlBackground period=1, noBurst=1,start
				endif
			endif
			break
		case 2: // a task is defined and running. If it is not our task, alert
			if ((cmpstr (S_Value, "GUIPbkg_BackGrounder()")) != 0)
				doalert 1, "A background task, " + S_value + ", is already defined and running. Kill it and start GUIP backgrounder?"
				if (V_Flag ==1) // yes
					KillBackground
					SetBackground GUIPbkg_BackGrounder()
					CtrlBackground period=1, noBurst=1,start
				endif
			endif
			break
	endswitch
	return 0
end

//******************************************************************************************************
// Stop the background task by setting global variable to 1. 
// Last modified 2013//11/17  by Jamie Boyd
Static Function GUIPbkg_Stop ()
	NVAR/Z bgkStop = root:packages:GUIPbackGrounder:bgkStop
	if (NVAR_EXISTS (bgkStop))
		bgkStop = 1
	endif
end

//******************************************************************************************************
// the background task iterates through the task list doing things whose time has come
// Last modified 2013//11/17  by Jamie Boyd
Function GUIPbkg_BackGrounder()
	
	NVAR bkgStop = root:packages:GUIPbackGrounder:bgkStop 
	if (bkgstop)
		return 1
	endif
	// the list of tasks
	SVAR taskList=root:packages:GUIPbackGrounder:tasklist
	// init time
	NVAR globalStart = root:packages:GUIPbackGrounder:GlobalStart
	// iterate through tasks
	variable iTask,nTasks = itemsinlist (taskList, "\r")
	string aTask, aTaskStrName
	variable curTicks = ticks - globalStart
	for (iTask=0; iTask < nTasks; iTask +=1)
		aTask = stringFromList (iTask, taskList, "\r")
		aTaskStrName = stringFromList (0, aTask, ";")
		NVAR nextTicks = $"root:packages:GUIPbackGrounder:" + aTaskStrName + "nextTicks"
		if (curTicks >= nextTicks)
			// run task
			SVAR taskGstr = $"root:packages:GUIPbackGrounder:" + aTaskStrName
			execute taskGstr + stringFromList (1, aTask, ";")
			// recalculate task ticks
			nextTicks = curTicks +  str2num (stringFromList (2, aTask, ";"))
		endif
	endfor
	return 0
end

//******************************************************************************************************
// Test functions for GUIP Backgrounder 
function GUIPBkgTest_Add ()
	
	GUIPbkg_AddTask("GUIPbkg_test1", (1/2), 1,funcParamList="")
	GUIPbkg_AddTask("GUIPbkg_test2", (1/3), 1,funcParamList="")
	GUIPbkg_AddTask("GUIPbkg_test3", (1/10),1, funcParamList="\"I am working properly\",1,3,7") // Note escaped quotation marks for strings \" 
end

Function GUIPBkgTest_Remove ()
	GUIPbkg_RemoveTask ("GUIPbkg_test1")
	GUIPbkg_RemoveTask ("GUIPbkg_test2")
	GUIPbkg_RemoveTask ("GUIPbkg_test3")
end


function GUIPbkg_test1 ()
	NVAR globalStart = root:packages:GUIPbackGrounder:GlobalStart
	printf "Test 1 was executed at %s.\r", secs2time (ticks -globalStart, 5, 2)
end

function GUIPbkg_test2 ()
	NVAR globalStart = root:packages:GUIPbackGrounder:GlobalStart
	printf "Test 2 was executed at %s.\r", secs2time (ticks-globalStart, 5, 2)
end

function GUIPbkg_test3 (stringToPrint, v1,v2,v3)
	String stringToPrint
	variable v1, v2 ,v3
	NVAR globalStart = root:packages:GUIPbackGrounder:GlobalStart
	printf "Test 3 was executed at %s and wants you to know:\r%s.\r", secs2time (ticks - globalStart, 5, 2), stringToPrint
	Printf  "Also, the product of v1, v2, and v3 = %d;their sum is %d.\r", v1 * v2 * v3, v1 + v2 + v3
end