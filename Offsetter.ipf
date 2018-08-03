#pragma rtGlobals=1		// Use modern global access method.
// Last Modified Feb 15 2011 by Jamie Boyd
//Have you ever dragged a trace on a graph and wished that it was the wave itself, not just its offset on the graph,
// that was changed? This function does that. It looks at every trace on the top graph, reads its  offset, and subtracts 
//that offset from the data of the wave
Function Offsetter ()

	string traces = TraceNameList("", ";", 1)
	variable ii, numtraces = itemsinlist (traces, ";")
	string aTRace, aTraceName
	variable anInstance, flag
	string offsetInfo
	variable xoffset, yoffset
	for (ii = 0, flag = 0; ii < numtraces; ii += 1, flag = 0)
		aTrace = stringfromlist (ii, traces)
		aTraceName = stringfromlist (0, aTrace, "#")
		aninstance = str2num (stringfromlist (1,  aTrace, "#"))
		if ((numtype (aninstance) == 2))
			aninstance = 0
		else
			flag = 1
		endif
		offsetInfo =  stringbykey ("offset(x)",  TraceInfo("", atracename, aninstance ), "=", ";")
		offsetinfo = offsetinfo [1, strlen (offsetinfo) -2]
		xoffset = str2num (stringfromlist (0, offsetinfo, ","))
		yoffset = str2num (stringfromlist (1, offsetinfo, ","))
		if (((xoffset != 0) || (yoffset != 0)) && (flag))
			doalert 0, "The wave corresponding to " + atrace + " was offset adjusted for its first instance on the graph. Offsets of further instances are ignored."
			continue
		endif
		WAVE ywave = TraceNameToWaveRef("", aTrace)
		yWave += yoffset
		WAVE/Z xwave = XWaveRefFromTrace("", aTrace )
		if (waveexists (xwave))
			xwave += xOffset
		else
			Setscale/P x , (dimoffset (ywave, 0) + xoffset), (dimdelta (ywave, 0)), (GetDimLabel(ywave, 0, -1 )), ywave
		endif
		ModifyGraph  offset ($aTrace)={0,0}
	endfor
end

// mOffsetter where only X (toDo=1) or only Y (toDo=2) or both Axes (toDo=3)  can be chosen for modification
Function mOffsetter (toDo) // bit 1 =x, bit2 =y
 	variable toDo
 	
	string traces = TraceNameList("", ";", 1)
	variable ii, numtraces = itemsinlist (traces, ";")
	string aTRace, aTraceName
	variable anInstance, flag
	string offsetInfo
	variable xoffset, yoffset
	for (ii = 0, flag = 0; ii < numtraces; ii += 1, flag = 0)
		aTrace = stringfromlist (ii, traces)
		aTraceName = stringfromlist (0, aTrace, "#")
		aninstance = str2num (stringfromlist (1,  aTrace, "#"))
		if ((numtype (aninstance) == 2))
			aninstance = 0
		else
			flag = 1
		endif
		offsetInfo =  stringbykey ("offset(x)",  TraceInfo("", atracename, aninstance ), "=", ";")
		offsetinfo = offsetinfo [1, strlen (offsetinfo) -2]
		xoffset = str2num (stringfromlist (0, offsetinfo, ","))
		yoffset = str2num (stringfromlist (1, offsetinfo, ","))
		if (((xoffset != 0) || (yoffset != 0)) && (flag))
			doalert 0, "The wave corresponding to " + atrace + " was offset adjusted for its first instance on the graph. Offsets of further instances are ignored."
			continue
		endif
		WAVE ywave = TraceNameToWaveRef("", aTrace)
		yWave += yoffset *  ((toDo & 2) ==2)
		WAVE/Z xwave = XWaveRefFromTrace("", aTrace )
		if (waveexists (xwave))
			xwave += xOffset * ((toDo & 1) == 1)
		else
			Setscale/P x , (dimoffset (ywave, 0) + xoffset*((toDo & 1) == 1)), (dimdelta (ywave, 0)), (GetDimLabel(ywave, 0, -1 )), ywave
		endif
		ModifyGraph  offset ($aTrace)={xoffset*((toDo & 1) == 0),yoffset*((toDo & 2) ==0)}
	endfor
end
