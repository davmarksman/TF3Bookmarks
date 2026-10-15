-- Bookmarks: the in-memory store.
--
-- A list of bookmarked entities (towns for now), newest first, and the
-- listeners told after every change. Everything here runs on the GUI
-- thread, inside click handlers or mount/unmount hooks: no engine reads,
-- no timers, nothing saved with the game. The list is lost when the game
-- exits. Types in tealdef/bm_def.d.tl (BmBookmark, BmBookmarksStore).

local LUA_UTILS : string = "bottle_bookmarks::/scripts/lua_utils.script.tl"
local luaUtils = require(LUA_UTILS) as BmLuaUtils

local bookmarks : {BmBookmark} = {}
local listeners : {function()} = {}

local function indexOf(entity : Engine.Entity) : integer
	for index, bookmark in ipairs(bookmarks) do
		if bookmark.entity == entity then return index end
	end
	return nil
end

-- Calls every listener. Iterates a copy, so a listener that unsubscribes
-- while being called does not upset the loop.
local function notify()
	local snapshot : {function()} = {}
	for index, listener in ipairs(listeners) do snapshot[index] = listener end
	for _, listener in ipairs(snapshot) do listener() end
end

local function isBookmarked(entity : Engine.Entity) : boolean
	return indexOf(entity) ~= nil
end

local function add(entity : Engine.Entity, kind : string, name : string)
	if entity == nil or indexOf(entity) ~= nil then return end
	table.insert(bookmarks, 1, { entity = entity, kind = kind, name = name } as BmBookmark)
	luaUtils.debug("bookmarked " .. kind .. " " .. tostring(entity) .. " (" .. name .. "), " .. tostring(#bookmarks) .. " in list")
	notify()
end

local function remove(entity : Engine.Entity)
	local index = indexOf(entity)
	if index == nil then return end
	local removed = table.remove(bookmarks, index)
	luaUtils.debug("removed bookmark " .. tostring(entity) .. " (" .. removed.name .. "), " .. tostring(#bookmarks) .. " left")
	notify()
end

-- Empties the list in place (the table itself is kept, so its address in
-- the log stays the same).
local function clear()
	if #bookmarks == 0 then return end
	for index = #bookmarks, 1, -1 do bookmarks[index] = nil end
	luaUtils.debug("all bookmarks cleared")
	notify()
end

-- A copy: callers never hold the live list.
local function getAll() : {BmBookmark}
	local copy : {BmBookmark} = {}
	for index, bookmark in ipairs(bookmarks) do
		copy[index] = { entity = bookmark.entity, kind = bookmark.kind, name = bookmark.name }
	end
	return copy
end

local function subscribe(listener : function()) : function()
	listeners[#listeners + 1] = listener
	return function()
		for index, existing in ipairs(listeners) do
			if existing == listener then
				table.remove(listeners, index)
				return
			end
		end
	end
end

-- The address shows in the log once per Lua state: the card and the window
-- must see the same store, so it must appear once.
luaUtils.debug("bookmarks store loaded: " .. tostring(bookmarks))

local exports : BmBookmarksStore = {
	isBookmarked = isBookmarked,
	add = add,
	remove = remove,
	clear = clear,
	getAll = getAll,
	subscribe = subscribe,
}
return exports
