#SingleInstance Force
#NoEnv
; #NoTrayIcon
; SetBatchLines 20ms
ListLines Off
SetWorkingDir %A_ScriptDir%

#Include %A_ScriptDir%
#Include <jsonlib>
#Include <stdio>
#Include <handles>
#Include <event>
#Include <protocolserver>
#Include <application>
#Include ./mockRuntime.ahk

class DebugSession extends Application
{
	static THREAD_ID := 1

	__New()
	{
		this._configurationDone := false
		this._timeout := false
		this._variableHandles := new Handles()
		this._runtime := new MockRunTime()
	}

	CheckTimeOut()
	{
		this._timeout := true
		; MsgBox, timeout!
	}

	initializeRequest(response, env)
	{
		; body
		response["body"] := {}
		response.body["supportsConfigurationDoneRequest"] := "true"
		; response.body["supportsEvaluateForHovers"] := "true"
		; response.body["supportsDataBreakpoints"] := "true"
		response.body["supportsBreakpointLocationsRequest"] := "true"
		response.body["supportsClipboardContext"] := "true"

		InitializedEvent := {"type": "event", "event": "initialized"}
		return [response, InitializedEvent]
	}

	configurationDoneRequest(response, env)
	{
		; Sleep, 2000 ; test timeout
		this._configurationDone := true
		; MsgBox, _configurationDone!

		return [response]
	}

	; async exec
	launchRequest(response, env)
	{
		; wait until configuration has finished (and configurationDoneRequest has been called)
		; Async wait by send WaitConfiguration event to event queue
		if (!this._configurationDone) ; and !this._timeout
		{
			CTO := ObjBindMethod(this, "CheckTimeOut")
			SetTimer, % CTO, -1000
			Sleep, 25
			server := env.server
			seq := env.seq

			HOR := ObjBindMethod(server, "HandleOneRequest")

			waitConfigurationRequest := {"command": "waitConfiguration", "seq": seq}
			waitConfigurationRequest["arguments"] := env.arguments
			waitConfigurationRequest := fsarr().print(waitConfigurationRequest)

			waitConfigurationRequest := "Content-Length: " StrLen(waitConfigurationRequest) "`r`n`r`n" . waitConfigurationRequest
			EventDispatcher.Put(HOR, waitConfigurationRequest)
			; empty list won't fire send method
			return []
		}

		; start ahk debug here
		this._runtime.Start(env.arguments.program)

		response["command"] := "launch"

		; Send a 'Stop on Entry' Stopped event, to make vs code stop on entry
		stoppedEvent := CreateStoppedEvent("entry", DebugSession.THREAD_ID)

		return [response, stoppedEvent]
	}

	waitConfigurationRequest(response, env)
	{
		; Mock Request to wait ConfigurationDoneRequest
		return this.launchRequest(response, env)
	}

	setBreakPointsRequest(response, env)
	{
		path := env.arguments.source.path
		clientLines := env.arguments.breakpoints

		; clear all breakpoints for this file
		; this._runtime.clearBreakpoints(path)

		; set and verify breakpoint locations
		; temp return all breakpoint of request
		actualBreakpoints := []
		for _, line in clientLines
		{
			bkp := this._runtime.SetBreakpoint(path, line.line)
			; Fuck Weakly Typed!
			actualBreakpoints.Push(CreateBreakpoint(bkp.verified, bkp.id, bkp.line+0))
			;verifyEvent.Push(CreateBreakpointEvent("changed", CreateBreakpoint("true", bkp.id, bkp.line)))
		}

		; body
		response["body"] := {}
		response.body["breakpoints"] := actualBreakpoints
		;verifyEvent.InsertAt(1, response)
		return [response]
	}

	setDataBreakpointsRequest(response, env)
	{
		; set and verify breakpoint locations
		; temp return all breakpoint of request
		if (env.arguments.breakpoints.Length() > 0)
			actualBreakpoints := env.arguments.breakpoints
		else
			actualBreakpoints := []

		; body
		response["body"] := {}
		response.body["breakpoints"] := actualBreakpoints

		return [response]
	}

	breakpointLocationsRequest(response, env)
	{
		; may xdbg doesn't support breakpointLocations
		response["body"] := {}
		response.body["breakpoints"] := {"line": env.arguments.line+0, "column": 1+0}

		return [response]
	}

	threadsRequest(response, env)
	{
		; runtime supports no threads so just return a default thread.
		response["body"] := {"threads": [{"id": DebugSession.THREAD_ID, "name": "thread 1"}]}

		return [response]
	}

	stackTraceRequest(response, env)
	{
		startFrame := env.arguments.startFrame >= 0 ? env.arguments.startFrame : 0
		maxLevels := env.arguments.levels >= 0 ? env.arguments.startFrame : 1000
		endFrame := startFrame + maxLevels

		source := {"name": this._runtime.GetBaseFile(), "path": StrReplace(this._runtime.GetPath(), "\", "\\"), "sourceReference": 0+0}

		; response a constant stack frame for now
		response["body"] := {}
		response.body["stackFrames"] := [{"id": 0, "name": "FakeFrame1"}  ; , "source": source
									   , {"id": 1, "name": "FakeFrame2"}] ; , "source": source
		response.body["totalFrames"] := 2

		return [response]
	}

	scopesRequest(response, env)
	{
		response["body"] := {}
		response.body["scopes"] := [{"name": "Local", "variablesReference": this._variableHandles.create("local"), "expensive": "false"}
								  , {"name": "Global", "variablesReference": this._variableHandles.create("Global"), "expensive": "true"}]
		return [response]
	}

	; TODO: May long running, need async exec here
	variablesRequest(response, env)
	{
		variables := []

		; just return some constant value, for now
		id := this._variableHandles.get(env.arguments.variablesReference)

		if (id)
		{
			variables.push({"name": id . "_i"
						   ,"type": "integer"
						   ,"value": "123"
						   ,"variablesReference": 0})
			variables.push({"name": id . "_f"
						   ,"type": "float"
						   ,"value": "3.1415926"
						   ,"variablesReference": 0})
			variables.push({"name": id . "_s"
						   ,"type": "string"
						   ,"value": "hello world"
						   ,"variablesReference": 0})
			variables.push({"name": id . "_o"
						   ,"type": "object"
						   ,"value": "MockObject"
						   ,"variablesReference": this._variableHandles.create(id . "_o")+0})
		}

		response["body"] := {"variables": variables}

		return [response]
	}

	continueRequest(response, env)
	{
		this._runtime.Continue()
		return [response]
	}

	nextRequest(response, env)
	{
		this._runtime.Next()
		return [response]
	}

	stepInRequest(response, env)
	{
		this._runtime.StepIn()
		return [response]
	}

	stepOutRequest(response, env)
	{
		this._runtime.StepOut()
		return [response]
	}

	disconnectRequest(response, env)
	{
		ExitApp
	}
}

IOStream := new StdIO

SERVER_ADDRESS := [IOStream, IOStream]
module := new DebugSession()
app := module.BuildApp()

DAd := MakeServer(SERVER_ADDRESS, app)

; Register send event handler
EventDispatcher.On("sendEvent", ObjBindMethod(DAd, "HandleEvent"))
DAd.ServeForever()
