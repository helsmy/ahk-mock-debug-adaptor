#Include <protocolserver>
#Include <event>

class MockRunTime
{
	__New()
	{
		this.dbgAddr := "127.0.0.1"
		this.dbgPort := 9000
		this.bIsAttach := false
		this.dbgCaptureStreams := false ; unsupport this for now
		this.Dbg_Session := ""
		this.Dbg_BkList := {}
		this._breakpointId := 1
		; temp mock id
		this.bkID := 1
	}

	Start(path)
	{
		this.path := path, szFilename := path
		; dbgAddr := this.dbgAddr, dbgPort := this.dbgPort
		; ; Now really run AutoHotkey and wait for it to connect
		; this.Dbg_Socket := DBGp_StartListening(dbgAddr, dbgPort) ; start listening
		; ; DebugRun
		; Run, "%AhkExecutable%" /Debug=%dbgAddr%:%dbgPort% "%szFilename%", %szDir%,, Dbg_PID ; run AutoHotkey and store its process ID
		; this.Dbg_PID := Dbg_PID

		; while (Dbg_AHKExists := Util_ProcessExist(Dbg_PID)) && this.Dbg_Session = "" ; wait for AutoHotkey to connect or exit
		; 	Sleep, 100 ; avoid smashing the CPU
		; DBGp_StopListening(Dbg_Socket) ; stop accept script connection
	}

	GetPath()
	{
		return this.path
	}

	GetBaseFile()
	{
		SplitPath, % this.path, , , , thisscriptname
		return thisscriptname
	}

	Continue()
	{
		; this.Run()
	}

	Next()
	{

	}

	StepIn()
	{

	}

	StepOut()
	{

	}

	Run()
	{

	}
	; @lParam 1 based lineno
	SetBreakpoint(uri, lParam)
	{
		;uri := DBGp_EncodeFileURI(uri)
		bk := this.GetBk(uri, lParam)
		if bk
		{
			; Dbg_Session.breakpoint_remove("-d " bk.id)
			; SciTE_BPSymbolRemove(lParam)
			this.RemoveBk(uri, lParam)
			return {"verified": "false", "line": lParam}
		}else
		{
			this.bInBkProcess := true
			; Dbg_Session.breakpoint_set("-t line -n " lParam " -f " uri, Dbg_Response)
			; If InStr(Dbg_Response, "<error") ; Check if AutoHotkey actually inserted the breakpoint.
			; {
			; 	bInBkProcess := false
			; 	return
			; }
			; dom := loadXML(Dbg_Response)
			; bkID := dom.selectSingleNode("/response/@id").text
			; Dbg_Session.breakpoint_get("-d " bkID, Dbg_Response)
			; dom := loadXML(Dbg_Response)
			; lParam := dom.selectSingleNode("/response/breakpoint[@id=" bkID "]/@lineno").text
			; SciTE_BPSymbol(lParam)
			this.AddBkToList(uri, lParam, this.bkID)
			this.bInBkProcess := false
			; this.VerifyBreakpoints(uri)
			; this.SendEvent(CreateBreakpointEvent("changed", CreateBreakpoint("true",, lParam)))
			this.bkID++
			return {"verified": "true", "line": lParam, "id": this.bkID-1}
		}
	}

	AddBkToList(uri, line, id, cond := "")
	{
		this.Dbg_BkList[uri, line] := { "id": id, "cond": cond }
	}

	GetBk(uri, line)
	{
		return this.Dbg_BkList[uri, line]
	}

	RemoveBk(uri, line)
	{
		this.Dbg_BkList[uri].Delete(line)
	}

	VerifyBreakpoints(uri)
	{
		for line,_ in this.Dbg_BkList[uri]
			this.SendEvent(CreateBreakpointEvent("changed", CreateBreakpoint("true",, line)))
	}

	SendEvent(event)
	{
		EventDispatcher.EmitImmediately("sendEvent", event)
	}

	__Delete()
	{
		;DBGp_StopListening(this.Dbg_Socket)
	}
}

; //////////////////////// Util Function ///////////////////////
Util_ProcessExist(a)
{
	t := ErrorLevel
	Process, Exist, %a%
	r := ErrorLevel
	ErrorLevel := t
	return r
}

loadXML(ByRef data)
{
	o := ComObjCreate("MSXML2.DOMDocument")
	o.async := false
	o.setProperty("SelectionLanguage", "XPath")
	o.loadXML(data)
	return o
}
