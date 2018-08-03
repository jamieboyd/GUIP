#pragma rtGlobals=3		// Use modern global access method.
#pragma ModuleName = GUIP
#pragma Version =2 // Last Modified 2013/07/18 by Jamie Boyd

// Boy, these were easy to write. Seriously, I use function references a fair bit and found I was making a bunch of
// empty prototype functions over and over again. So I put a bunch of logically named empty prototypes all in one file.

// no arguments
Function GUIPprotoFunc ()
	return 0
end

// 1 argumnet, wave, variable, or string

// 1 wave
Function GUIPprotoFuncW (w1)
	WAVE w1
	return 0
end

// 1 variable
Function GUIPprotoFuncV (v1)
	variable v1
	return 0
end

// 1 string
Function GUIPprotoFuncS (s1)
	string s1
	return 0
end


// 2 arguments, all 6 possible combinations, waves always listed first, then variables, then strings

// 2 waves
Function GUIPprotoFuncWW (w1, w2)
	WAVE w1, w2
	return 0
end

// 1 wave, 1 variable
Function GUIPprotoFuncWV (w1, v1)
	WAVE w1
	variable v1
	return 0
end

// 1 wave, 1string
Function GUIPprotoFuncWS (w1, s1)
	WAVE w1
	string s1
	return 0
end

// 2 variables
Function GUIPprotoFuncVV (v1, v2)
	variable v1, v2
	return 0
end

// 1 variable, 1string
Function GUIPprotoFuncVS (v1, s1)
	variable v1
	string s1
	return 0
end

// 2 strings
Function GUIPprotoFuncSS (s1, s2)
	string s1, s2
	return 0
end

// 3 arguments, all possible combinations, waves always listed first, then variables, then strings
// 3 waves
Function GUIPprotoFuncWWW (w1, w2, w3)
	wave w1, w2, w3
	return 0
end

// 2 waves, 1 variable
Function GUIPprotoFuncWWV (w1, w2, v1)
	wave w1, w2
	variable v1
	return 0
end

// 2 waves, 1 string
Function GUIPprotoFuncWWS (w1, w2, s1)
	wave w1, w2
	string s1
	return 0
end

// 1 wave, 2 variables
Function GUIPprotoFuncWVV (w1, v1, v2)
	wave w1
	variable v1, v2
	return 0
end

// 1 wave, 2 strings
Function GUIPprotoFuncWSS (w1, s1, s2)
	wave w1
	string s1, s2
	return 0
end

// 1 wave, 1 variable, 1 string
Function GUIPprotoFuncWVS (w1, v1, s1)
	wave w1
	variable v1
	string s1
	return 0
end

// 3 variables
Function GUIPprotoFuncVVV (v1, v2, v3)
	variable v1, v2, v3
	return 0
end

// 2 variables, 1 string
Function GUIPprotoFuncVVS (v1, v2, s1)
	variable v1, v2
	string s1
	return 0
end

// 1 variable, 2 strings
Function GUIPprotoFuncVSS (v1, s1, s2)
	variable v1
	string s1, s2
	return 0
end

// 3 strings
Function GUIPprotoFuncSSS (s1, s2, s3)
	string s1, s2, s3
	return 0
end

// 4 arguments, all possible combinations, waves always listed first, then variables, then strings
// 4 waves
Function GUIPprotoFuncWWWW (w1, w2, w3, w4)
	wave w1, w2, w3, w4
	return 0
end

// 3 waves, 1 variable
Function GUIPprotoFuncWWWV (w1, w2, w3, v1)
	wave w1, w2, w3
	variable v1
	return 0
end

// 3 waves, 1 string
Function GUIPprotoFuncWWWS (w1, w2, w3, s1)
	wave w1, w2, w3
	string s1
	return 0
end

// 2 waves, 2 variables
Function GUIPprotoFuncWWVV (w1, w2, v1, v2)
	wave w1, w2
	variable v1, v2
	return 0
end

// 2 waves, 1 variable, 1 string
Function GUIPprotoFuncWWVS (w1, w2, v1, s1)
	wave w1, w2
	variable v1
	string s1
	return 0
end

// 2 waves, 2 strings
Function GUIPprotoFuncWWSS (w1, w2,  s1, s2)
	wave w1, w2
	string s1, s2
	return 0
end

// 1 wave, 3 variables
Function GUIPprotoFuncWVVV (w1, v1, v2, v3)
	wave w1
	variable v1, v2, v3
	return 0
end

// 1 wave, 2 variables, 1 string
Function GUIPprotoFuncWVVS (w1, v1, v2, s1)
	wave w1
	variable v1, v2
	string s1
	return 0
end

// 1 wave, 1 variable, 2 strings
Function GUIPprotoFuncWVSS (w1, v1, s1, s2)
	wave w1
	variable v1
	string s1, s2
	return 0
end

// 1 wave, 3 strings
Function GUIPprotoFuncWSSS (w1, s1, s2, s3)
	wave w1
	string s1, s2, s3
	return 0
end

// 4 variables
Function GUIPprotoFuncVVVV (v1, v2, v3, v4)
	variable v1, v2, v3, v4
	return 0
end

// 3 variables, 1 string
Function GUIPprotoFuncVVVS (v1, v2, v3, s1)
	variable v1, v2, v3
	string s1
	return 0
end

// 2 variables, 2 strings
Function GUIPprotoFuncVVSS (v1, v2,  s1, s2)
	variable v1, v2
	string s1, s2
	return 0
end

// 1 variable, 3 strings
Function GUIPprotoFuncVSSS (v1, s1, s2, s3)
	variable v1
	string s1, s2, s3
	return 0
end

// 4 strings
Function GUIPprotoFuncSSSS (s1, s2, s3, s4)
	string s1, s2, s3, s4
	return 0
end

// 5 arguments, all possible combinations, waves always listed first, then variables, then strings
// 5 waves
Function GUIPprotoFuncWWWWW (w1, w2, w3, w4, w5)
	wave w1, w2, w3, w4, w5
	return 0
end

// 4 waves, 1 string
Function GUIPprotoFuncWWWWS (w1, w2, w3, w4,s1)
	wave w1, w2, w3, w4
	string s1
	return 0
end

// 4 waves, 1 variable
Function GUIPprotoFuncWWWWV (w1, w2, w3, w4, v1)
	wave w1, w2, w3, w4
	variable v1
	return 0
end

// 3 waves, 2 strings
Function GUIPprotoFuncWWWSS (w1, w2, w3, s1, s2)
	wave w1, w2, w3
	string s1, s2
	return 0
end

// 3 waves, 1string, 1 variable
Function GUIPprotoFuncWWWSV (w1, w2, w3, s1, v1)
	wave w1, w2, w3
	string s1
	variable v1
	return 0
end

// 3 waves, 2 variables
Function GUIPprotoFuncWWWVV(w1, w2, w3, v1, v2)
	wave w1, w2, w3
	variable v1, v2
	return 0
end

// 2 waves, 3 strings
Function GUIPprotoFuncWWSSS (w1, w2, s1, s2, s3)
	wave w1, w2
	string s1, s2, s3
	return 0
end

// 2 waves, 2 strings, 1 variable
Function GUIPprotoFuncWWSSV (w1, w2, s1, s2, v1)
	wave w1, w2
	string s1, s2
	variable v1
	return 0
end

// 2 waves, 1 string, 2 variables
Function GUIPprotoFuncWWSVV (w1, w2, s1,  v1, v2)
	wave w1, w2
	string s1
	variable v1, v2
	return 0
end

// 2 waves, 3 variables
Function GUIPprotoFuncWWVVV(w1, w2, v1, v2, v3)
	wave w1, w2
	variable v1, v2, v3
	return 0
end

// 1 wave, 4 strings
Function GUIPprotoFuncWSSSS (w1, s1, s2, s3, s4)
	wave w1
	string s1, s2, s3, s4
	return 0
end

// 1 wave, 3 strings, 1 variable
Function GUIPprotoFuncWSSSV (w1, s1, s2, s3, v1)
	wave w1
	string s1, s2, s3
	variable v1
	return 0
end

// 1 wave, 2 strings, 2 variables
Function GUIPprotoFuncWSSVV (w1, s1, s2, v1, v2)
	wave w1
	string s1, s2
	variable v1, v2
	return 0
end

// 1 wave, 1 string, 3 variables
Function GUIPprotoFuncWSVVV (w1, s1, v1, v2, v3)
	wave w1
	string s1
	variable v1, v2, v3
	return 0
end

// 1 wave, 4 variables
Function GUIPprotoFuncWVVVV (w1, v1, v2, v3, v4)
	wave w1
	variable v1, v2, v3, v4
	return 0
end

// 5 strings
Function GUIPprotoFuncSSSSS (s1, s2 s3, s4, s5)
	string s1, s2, s3, s4, s5
	return 0
end

// 4 strings, 1 variable
Function GUIPprotoFuncSSSSV (s1, s2, s3, s4, v1)
	string s1, s2, s3, s4
	variable v1
	return 0
end

// 3 strings, 2 variables
Function GUIPprotoFuncSSSVV (s1, s2, s3, v1, v2)
	string s1, s2, s3
	variable v1, v2
	return 0
end

// 2 strings, 3 variables
Function GUIPprotoFuncSSVVV (s1, s2, v1, v2, v3)
	string s1, s2
	variable v1, v2, v3
	return 0
end

// 1 string, 4 variables
Function GUIPprotoFuncSVVVV (s1, v1, v2, v3, v4)
	string s1
	variable v1, v2, v3, v4
	return 0
end

// 5 variables
Function GUIPprotoFuncVVVVV (v1, v2, v3, v4, v5)
	variable v1, v2, v3, v4, v5
	return 0
end

// *******************************************************************
// Now repeat for functions returning a string
Function/S GUIPsprotoFunc ()
	return ""
end

// 1 argumnet, wave, variable, or string
// 1 wave
Function/S GUIPsprotoFuncW (w1)
	WAVE w1
	return ""
end

// 1 variable
Function/S GUIPsprotoFuncV (v1)
	variable v1
	return ""
end

// 1 string
Function/S GUIPsprotoFuncS (s1)
	string s1
	return ""
end

// 2 arguments, all 6 possible combinations, waves always listed first, then variables, then strings
// 2 waves
Function/S GUIPsprotoFuncWW (w1, w2)
	WAVE w1, w2
	return ""
end

// 1 wave, 1 variable
Function/S GUIPsprotoFuncWV (w1, v1)
	WAVE w1
	variable v1
	return ""
end

// 1 wave, 1string
Function/S GUIPsprotoFuncWS (w1, s1)
	WAVE w1
	string s1
	return ""
end

// 2 variables
Function/S GUIPsprotoFuncVV (v1, v2)
	variable v1, v2
	return ""
end

// 1 variable, 1string
Function/S GUIPsprotoFuncVS (v1, s1)
	variable v1
	string s1
	return ""
end

// 2 strings
Function/S GUIPsprotoFuncSS (s1, s2)
	string s1, s2
	return ""
end

// 3 arguments, all possible combinations, waves always listed first, then variables, then strings
// 3 waves
Function/S GUIPsprotoFuncWWW (w1, w2, w3)
	wave w1, w2, w3
	return ""
end

// 2 waves, 1 variable
Function/S GUIPsprotoFuncWWV (w1, w2, v1)
	wave w1, w2
	variable v1
	return ""
end

// 2 waves, 1 string
Function/S GUIPsprotoFuncWWS (w1, w2, s1)
	wave w1, w2
	string s1
	return ""
end

// 1 wave, 2 variables
Function/S GUIPsprotoFuncWVV (w1, v1, v2)
	wave w1
	variable v1, v2
	return ""
end

// 1 wave, 2 strings
Function/S GUIPsprotoFuncWSS (w1, s1, s2)
	wave w1
	string s1, s2
	return ""
end

// 1 wave, 1 variable, 1 string
Function/S GUIPsprotoFuncWVS (w1, v1, s1)
	wave w1
	variable v1
	string s1
	return ""
end

// 3 variables
Function/S GUIPsprotoFuncVVV (v1, v2, v3)
	variable v1, v2, v3
	return ""
end

// 2 variables, 1 string
Function/S GUIPsprotoFuncVVS (v1, v2, s1)
	variable v1, v2
	string s1
	return ""
end

// 1 variable, 2 strings
Function/S GUIPsprotoFuncVSS (v1, s1, s2)
	variable v1
	string s1, s2
	return ""
end

// 3 strings
Function/S GUIPsprotoFuncSSS (s1, s2, s3)
	variable s1, s2, s3
	return ""
end

// 4 arguments, all possible combinations, waves always listed first, then variables, then strings
// 4 waves
Function/S GUIPsprotoFuncWWWW (w1, w2, w3, w4)
	wave w1, w2, w3, w4
	return ""
end

// 3 waves, 1 variable
Function/S GUIPsprotoFuncWWWV (w1, w2, w3, v1)
	wave w1, w2, w3
	variable v1
	return ""
end

// 3 waves, 1 string
Function/S GUIPsprotoFuncWWWS (w1, w2, w3, s1)
	wave w1, w2, w3
	string s1
	return ""
end

// 2 waves, 2 variables
Function/S GUIPsprotoFuncWWVV (w1, w2, v1, v2)
	wave w1, w2
	variable v1, v2
	return ""
end

// 2 waves, 1 variable, 1 string
Function/S GUIPsprotoFuncWWVS (w1, w2, v1, s1)
	wave w1, w2
	variable v1
	string s1
	return ""
end

// 2 waves, 2 strings
Function/S GUIPsprotoFuncWWSS (w1, w2,  s1, s2)
	wave w1, w2
	string s1, s2
	return ""
end

// 1 wave, 3 variables
Function/S GUIPsprotoFuncWVVV (w1, v1, v2, v3)
	wave w1
	variable v1, v2, v3
	return ""
end

// 1 wave, 2 variables, 1 string
Function/S GUIPsprotoFuncWVVS (w1, v1, v2, s1)
	wave w1
	variable v1, v2
	string s1
	return ""
end

// 1 wave, 1 variable, 2 strings
Function/S GUIPsprotoFuncWVSS (w1, v1, s1, s2)
	wave w1
	variable v1
	string s1, s2
	return ""
end

// 1 wave, 3 strings
Function/S GUIPsprotoFuncWSSS (w1, s1, s2, s3)
	wave w1
	string s1, s2, s3
	return ""
end

// 4 variables
Function/S GUIPsprotoFuncVVVV (v1, v2, v3, v4)
	variable v1, v2, v3, v4
	return ""
end

// 3 variables, 1 str
Function/S GUIPsprotoFuncVVVS (v1, v2, v3, s1)
	variable v1, v2, v3
	string s1
	return ""
end

// 2 variables, 2 strings
Function/S GUIPsprotoFuncVVSS (v1, v2,  s1, s2)
	variable v1, v2
	string s1, s2
	return ""
end

// 1 variable, 3 strings
Function/S GUIPsprotoFuncVSSS (v1, s1, s2, s3)
	variable v1
	string s1, s2, s3
	return ""
end

// 4 strings
Function/S GUIPsprotoFuncSSSS (s1, s2, s3, s4)
	string s1, s2, s3, s4
	return ""
end

// 5 arguments, all possible combinations, waves always listed first, then variables, then strings
// 5 waves
Function/s GUIPsprotoFuncWWWWW (w1, w2, w3, w4, w5)
	wave w1, w2, w3, w4, w5
	return ""
end

// 4 waves, 1 string
Function/s GUIPsprotoFuncWWWWS (w1, w2, w3, w4,s1)
	wave w1, w2, w3, w4
	string s1
	return ""
end

// 4 waves, 1 variable
Function/s GUIPsprotoFuncWWWWV (w1, w2, w3, w4, v1)
	wave w1, w2, w3, w4
	variable v1
	return ""
end

// 3 waves, 2 strings
Function/s GUIPsprotoFuncWWWSS (w1, w2, w3, s1, s2)
	wave w1, w2, w3
	string s1, s2
	return ""
end

// 3 waves, 1string, 1 variable
Function/s GUIPsprotoFuncWWWSV (w1, w2, w3, s1, v1)
	wave w1, w2, w3
	string s1
	variable v1
	return ""
end

// 3 waves, 2 variables
Function/s GUIPsprotoFuncWWWVV(w1, w2, w3, v1, v2)
	wave w1, w2, w3
	variable v1, v2
	return ""
end

// 2 waves, 3 strings
Function/s GUIPsprotoFuncWWSSS (w1, w2, s1, s2, s3)
	wave w1, w2
	string s1, s2, s3
	return ""
end

// 2 waves, 2 strings, 1 variable
Function/s GUIPsprotoFuncWWSSV (w1, w2, s1, s2, v1)
	wave w1, w2
	string s1, s2
	variable v1
	return ""
end

// 2 waves, 1 string, 2 variables
Function/s GUIPsprotoFuncWWSVV (w1, w2, s1,  v1, v2)
	wave w1, w2
	string s1
	variable v1, v2
	return ""
end

// 2 waves, 3 variables
Function/s GUIPsprotoFuncWWVVV(w1, w2, v1, v2, v3)
	wave w1, w2
	variable v1, v2, v3
	return ""
end

// 1 wave, 4 strings
Function/s GUIPsprotoFuncWSSSS (w1, s1, s2, s3, s4)
	wave w1
	string s1, s2, s3, s4
	return ""
end

// 1 wave, 3 strings, 1 variable
Function/s GUIPsprotoFuncWSSSV (w1, s1, s2, s3, v1)
	wave w1
	string s1, s2, s3
	variable v1
	return ""
end

// 1 wave, 2 strings, 2 variables
Function/s GUIPsprotoFuncWSSVV (w1, s1, s2, v1, v2)
	wave w1
	string s1, s2
	variable v1, v2
	return ""
end

// 1 wave, 1 string, 3 variables
Function/s GUIPsprotoFuncWSVVV (w1, s1, v1, v2, v3)
	wave w1
	string s1
	variable v1, v2, v3
	return ""
end

// 1 wave, 4 variables
Function/s GUIPsprotoFuncWVVVV (w1, v1, v2, v3, v4)
	wave w1
	variable v1, v2, v3, v4
	return ""
end

// 5 strings
Function/s GUIPsprotoFuncSSSSS (s1, s2 s3, s4, s5)
	string s1, s2, s3, s4, s5
	return ""
end

// 4 strings, 1 variable
Function/s GUIPsprotoFuncSSSSV (s1, s2, s3, s4, v1)
	string s1, s2, s3, s4
	variable v1
	return ""
end

// 3 strings, 2 variables
Function/s GUIPsprotoFuncSSSVV (s1, s2, s3, v1, v2)
	string s1, s2, s3
	variable v1, v2
	return ""
end

// 2 strings, 3 variables
Function/s GUIPsprotoFuncSSVVV (s1, s2, v1, v2, v3)
	string s1, s2
	variable v1, v2, v3
	return ""
end

// 1 string, 4 variables
Function/s GUIPsprotoFuncSVVVV (s1, v1, v2, v3, v4)
	string s1
	variable v1, v2, v3, v4
	return ""
end

// 5 variables
Function/s GUIPsprotoFuncVVVVV (v1, v2, v3, v4, v5)
	variable v1, v2, v3, v4, v5
	return ""
end

//********************************************************************************
// Common UI control functions
Function GUIPProtoFuncButton(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	return 0
end

Function GUIPProtoFuncCheckBox (CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
	return 0
End

Function GUIPProtoFuncListBox(LB_Struct) : ListboxControl
	STRUCT WMListboxAction &LB_Struct
	return 0
End

Function GUIPProtoFuncPopUpMenu(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	return 0
end

Function GUIPProtoFuncSetVariable(SV_Struct) : SetVariableControl
	STRUCT WMSetVariableAction &SV_Struct
	return 0
End

Function GUIPProtoFuncSlider(S_Struct) : SliderControl
	STRUCT WMSliderAction &S_Struct
	return 0
End

Function GUIPProtoFuncTabControl(tca) : TabControl
	STRUCT WMTabControlAction &tca
	return 0
end

//********************************************************************************
// Hook functions
Function GUIPProtoFuncWinHook (s)
	STRUCT WMWinHookStruct &s
	return 0
end

Function GUIPProtoFuncAxisHook(info)
	STRUCT WMAxisHookStruct &info
	return 0
End