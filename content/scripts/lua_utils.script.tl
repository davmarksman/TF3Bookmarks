-- Logging helpers. No engine calls, so safe anywhere.
-- Types live in tealdef/bm_def.d.tl (BmLuaUtils).

-- false: only errors are logged (a bookmark whose town has gone). Set to
-- true to trace store changes and window open/close while debugging.
local DEBUG : boolean = false

-- Always logged: errors a user's log should show.
local function logAlways(message : string)
	debugPrint("[BM] " .. message)
end

-- Logged only while DEBUG is true: traces for development.
local function logDebug(message : string)
	if DEBUG then debugPrint("[BM] " .. message) end
end

local exports : BmLuaUtils = {
	DEBUG = DEBUG,
	log = logAlways,
	debug = logDebug,
}
return exports
