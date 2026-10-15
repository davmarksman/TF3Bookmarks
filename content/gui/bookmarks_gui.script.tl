-- Bookmarks: the HUD buttons, the Bookmarks window and the saved camera
-- positions.
--
-- The HUD buttons (registered by bookmarks_plugin.res.lua on the HUD's
-- mod-button area), icons only: the Bookmarks toggle (book and pin) opens
-- one singleton window listing every bookmark, newest first (a pin and the
-- name move the camera to the town, an X removes the bookmark); the back
-- button (camera and circular arrow) takes the camera back to where it was
-- before the last jump (see CAMERA POSITIONS). The window subscribes to the store, so a
-- bookmark added from a town window shows at once. No timer; no engine
-- reads in recipe bodies (the click handlers do the entityExists checks and
-- the camera calls).

local react              = ug_require "::/gui/main/react.lua" as React
local builtin            = ug_require "::/gui/main/builtin.lua" as Builtin
local game_react_globals = ug_require "::/gui/main/game_react_globals.tl" as GameReactGlobals
local gui_react_util     = ug_require "::/gui/main/gui_react_util.tl" as GuiReactUtil
local button_react_util  = ug_require "::/gui/main/button_react_util.tl" as ButtonReactUtil
local main_mod_button_area = ug_require "::/gui/main/main_mod_button_area.tl" as MainModButtonArea

-- Own modules: path constant plus a cast to the record in tealdef/bm_def.d.tl.
local STORE : string = "bottle_bookmarks::/scripts/bookmarks_store.script.tl"
local LUA_UTILS : string = "bottle_bookmarks::/scripts/lua_utils.script.tl"
local store = require(STORE) as BmBookmarksStore
local luaUtils = require(LUA_UTILS) as BmLuaUtils

-- Dotted like the timetable mod's id: the stylesheet rule "Window#<id>"
-- that centres the window is keyed on it.
local WINDOW_ID : string = "bm.bookmarks.window"

-- Base-game icons. The game resolves the "@2x" files itself.
local ICON_LOCATE : string = "::/gui/line_vehicle_mgmt/icons/symbol_locate_20.tga"
local ICON_REMOVE : string = "::/gui/line_vehicle_mgmt/icons/close.tga"
-- Our HUD icons: 48 px greyscale "@2x" files in gui/icons, shown at 24 px.
local ICON_BOOKMARKS : string = "bottle_bookmarks::/gui/icons/bookmarks.tga"
local ICON_CAMERA_BACK : string = "bottle_bookmarks::/gui/icons/camera_back.tga"

-- true: the camera jumps to the town (what the game's own locate buttons
-- do); false: it slides.
local CAMERA_JUMP : boolean = true

local EMPTY_MESSAGE : string = "No bookmarks yet. Open a town or vehicle and click Bookmark."

-- A restore moves the camera only to a saved position farther than this
-- from where the camera is (metres): nearer ones were saved by clicks that
-- moved nothing (map and list clicks) and are skipped. See CAMERA POSITIONS.
local MIN_RESTORE_DISTANCE : number = 2000

------------------------------------------------------------
-- TYPES
------------------------------------------------------------

local record WindowParams
	onClose : function()
end

------------------------------------------------------------
-- CAMERA POSITIONS
------------------------------------------------------------

-- The camera positions saved before the last jumps, newest first; module
-- state, GUI thread only, lost with the session. Saved on every
-- "selectEntity" React event (a notification click moves the camera and
-- then fires it; a map click or a list click fires it without moving; an
-- entity window opened that way saves the position its locate pin later
-- leaves from), on the mod's own jumps, and on a restore, so a restore can
-- be undone. No event tells a jump from a plain window open, so distance
-- decides, with MIN_RESTORE_DISTANCE on both sides:
--   - saving: a position within that distance of the newest slot replaces
--     it rather than taking a slot of its own, so clicks that move nothing
--     cannot push the far positions out;
--   - restoring: the camera moves to the newest slot farther than that
--     from where it is, skipping nearer slots. Three slots give the walk
--     something to fall through to.
--
-- The restore uses focusPosition, a camera target that is not an entity.
-- After a locate pin the camera follows the entity, and nothing moves it
-- off a static one (setCameraData, setManualCamera and focusPosition all
-- change the numbers and the follow re-centres next frame) except
-- focusEntity on the followed entity, so a restore calls that first when a
-- follow is active. Angle and pitch are not restored. The look-at height is
-- saved with each position (getCenter) because focusPosition wants a 3D
-- point.
local MAX_SAVED_POSITIONS : integer = 3
local savedPositions : {BmCameraPos} = {}

local function describePosition(position : BmCameraPos) : string
	return string.format("centre (%.0f, %.0f, h %.0f) distance %.0f angle %.2f pitch %.2f",
		position.x, position.y, position.height, position.z, position.w, position.q)
end

-- Ground distance between two positions' centres, in metres.
local function distanceBetween(first : BmCameraPos, second : BmCameraPos) : number
	local dx = first.x - second.x
	local dy = first.y - second.y
	return math.sqrt(dx * dx + dy * dy)
end

-- The camera now, as plain numbers. Click and event handlers only (api.gui).
local function readCamera(source : string) : BmCameraPos
	local camera : Vec5f = api.gui.camera.getCameraData()
	local center : Vec3f = api.gui.camera.getCenter()
	return { x = camera.x, y = camera.y, z = camera.z, w = camera.w, q = camera.q,
		height = center.z, source = source }
end

local function savePosition(position : BmCameraPos)
	local newest = savedPositions[1]
	if newest ~= nil and distanceBetween(newest, position) <= MIN_RESTORE_DISTANCE then
		savedPositions[1] = position
		luaUtils.debug("camera saved (" .. position.source .. ") in place of the newest slot, "
			.. string.format("%.0f", distanceBetween(newest, position)) .. " m away: " .. describePosition(position))
		return
	end
	table.insert(savedPositions, 1, position)
	while #savedPositions > MAX_SAVED_POSITIONS do table.remove(savedPositions) end
	luaUtils.debug("camera saved (" .. position.source .. "): " .. describePosition(position)
		.. "; " .. tostring(#savedPositions) .. " saved")
end

local function saveCurrentPosition(source : string)
	savePosition(readCamera(source))
end

-- "selectEntity": save where the camera is.
local function onSelectEntity(entity : Engine.Entity)
	saveCurrentPosition("selectEntity " .. tostring(entity))
end

-- Moves the camera to the newest saved position that is farther than
-- MIN_RESTORE_DISTANCE from the camera; nearer slots are skipped. The
-- position the camera leaves is saved first, so the move can be undone with
-- the same button.
local function restorePosition(source : string)
	local current = readCamera(source)
	local target : BmCameraPos = nil
	for slot, position in ipairs(savedPositions) do
		local distance = distanceBetween(current, position)
		if distance > MIN_RESTORE_DISTANCE then
			target = position
			luaUtils.debug("restore (" .. source .. "): slot " .. tostring(slot)
				.. " at " .. string.format("%.0f", distance) .. " m, saved by " .. position.source)
			break
		end
		luaUtils.debug("restore (" .. source .. "): slot " .. tostring(slot)
			.. " skipped, only " .. string.format("%.0f", distance) .. " m away")
	end
	if target == nil then
		luaUtils.debug("restore (" .. source .. "): no saved position farther than "
			.. tostring(MIN_RESTORE_DISTANCE) .. " m")
		return
	end
	savePosition(current)
	local followed = api.gui.camera.getFollowEntity()
	local followedEntity : Engine.Entity = followed and followed[1]
	luaUtils.debug("camera restore to " .. describePosition(target) .. "; following " .. tostring(followedEntity))
	if followedEntity ~= nil and followedEntity ~= -1 then
		-- Ends the follow (see the section comment); -1 means none.
		api.gui.camera.focusEntity(followedEntity)
		if luaUtils.DEBUG then
			-- A second camera call only for the log, so only while DEBUG is on.
			local after = api.gui.camera.getFollowEntity()
			luaUtils.debug("follow ended with focusEntity(" .. tostring(followedEntity) .. "); following now "
				.. tostring(after and after[1]))
		end
	end
	api.gui.camera.focusPosition(api.type.Vec3f.new(target.x, target.y, target.height), target.z)
end

------------------------------------------------------------
-- WIDGET HELPERS
------------------------------------------------------------

local function text(str : string, class : string, tooltip? : string) : TreeNodeId
	return builtin.TextView{ meta = { class = class, tooltip = tooltip }, text = str }
end

local function iconButton(class : string, path : string, tooltip : string, onClick : function()) : TreeNodeId
	return builtin.Button{
		meta = { class = class, tooltip = tooltip },
		content = builtin.ImageView{
			meta = { class = "bm-pin-icon" },
			path = path,
			scaling = builtin.type.ImageViewScaling.AutoFit,
		},
		onClick = onClick,
	}
end

-- True if the entity is still there. A bookmark whose entity has gone
-- (another save loaded, say) is logged and dropped, so the camera and the
-- window event never get a dead entity.
local function stillExists(bookmark : BmBookmark) : boolean
	if bookmark.entity ~= nil and api.engine.entityExists(bookmark.entity) then return true end
	luaUtils.log("bookmark " .. bookmark.name .. " (" .. tostring(bookmark.entity) .. ") no longer exists; removed")
	store.remove(bookmark.entity)
	return false
end

-- Moves the camera to the bookmark's town, saving the position it leaves.
-- Click handlers only (api.gui).
local function goTo(bookmark : BmBookmark)
	if not stillExists(bookmark) then return end
	saveCurrentPosition("jump to " .. bookmark.name)
	api.gui.camera.followEntity(bookmark.entity, CAMERA_JUMP)
end

-- "<pin> Town name ............ [x]". The pin and the name both move the
-- camera; nothing here opens the town window.
local function bookmarkRow(bookmark : BmBookmark) : TreeNodeId
	local tooltip = "Go to " .. bookmark.name
	local pin = iconButton("bm-locate", ICON_LOCATE, tooltip, function() goTo(bookmark) end)
	local name = button_react_util.makeTextButton("bm-name", bookmark.name, function() goTo(bookmark) end, tooltip)
	local remove = iconButton("bm-remove", ICON_REMOVE, "Remove " .. bookmark.name .. " from the bookmarks", function()
		store.remove(bookmark.entity)
	end)
	return builtin.Component{
		meta = { class = "bm-row" },
		layout = builtin.BoxLayout{
			orientation = builtin.type.Orientation.Horizontal,
			children = { pin, name, gui_react_util.makeHorizontalSpacer(), remove },
		},
	}
end

-- The scrolling list box. It is always there, even with no rows (then it
-- holds the empty message), so the window keeps the same layout. The scroll
-- area stretches its content to the viewport width, so the rows sit in a
-- fixed-width box beside a spacer and keep their width.
local function bookmarksList(bookmarks : {BmBookmark}) : TreeNodeId
	local rows : {TreeNodeId} = {}
	for _, bookmark in ipairs(bookmarks) do
		rows[#rows + 1] = bookmarkRow(bookmark)
	end
	if #rows == 0 then rows[1] = text(EMPTY_MESSAGE, "font-scale-body") end
	return builtin.ScrollArea{
		meta = { class = "bm-bookmarks-scrollarea" },
		content = builtin.Component{
			layout = builtin.BoxLayout{
				orientation = builtin.type.Orientation.Horizontal,
				children = {
					builtin.Component{
						meta = { class = "bm-rows" },
						layout = builtin.BoxLayout{
							orientation = builtin.type.Orientation.Vertical,
							children = rows,
						},
					},
					gui_react_util.makeHorizontalSpacer(),
				},
			},
		},
		horizontalPolicy = builtin.type.ScrollBarPolicy.AlwaysOff,
		verticalPolicy = builtin.type.ScrollBarPolicy.AsNeeded,
	}
end

-- "N bookmarks" and, at the right, Clear All.
local function footer(count : integer) : TreeNodeId
	local label = count == 0 and "" or (tostring(count) .. (count == 1 and " bookmark" or " bookmarks"))
	return builtin.Component{
		meta = { class = "bm-footer" },
		layout = builtin.BoxLayout{
			orientation = builtin.type.Orientation.Horizontal,
			children = {
				text(label, "font-scale-annotation"),
				gui_react_util.makeHorizontalSpacer(),
				button_react_util.makeTextButton("primary", "Clear All",
					function() store.clear() end,
					"Remove every bookmark."),
			},
		},
	}
end

------------------------------------------------------------
-- WINDOW
------------------------------------------------------------

-- GUI thread only. Whether the singleton window is open, so the HUD toggle
-- button can follow it whichever way it was closed (X, Escape, toggle).
-- Reset in the content's onUnmount as well as in onClose: the window can
-- be destroyed without onClose, and a flag stuck at true would need three
-- clicks to open the window again.
local windowIsOpen : boolean = false

local BookmarksWindowContent = react.RegisterRecipe(
	"BmBookmarksWindowContent",
	function(params : WindowParams) : TreeNodeId
		react.useInputAction("IA_MENU_BACK", react.iaHandler(params.onClose))

		-- The rows live in state; the store's listener replaces them after
		-- every change while the window is open.
		local rowsState = react.useState(store.getAll()) as ReactStateT<{BmBookmark}>
		-- The unsubscribe function, in a ref because the recipe body re-runs
		-- on every render and a local would be replaced each time.
		local unsubscribeRef = react.useRef(nil as function()) as ReactRefT<function()>

		react.onMount(function()
			unsubscribeRef:set(store.subscribe(function()
				if not rowsState:hasExpired() then rowsState:set(store.getAll()) end
			end))
			luaUtils.debug("bookmarks window opened")
		end)
		-- The window can be destroyed without onClose, so unsubscribe here.
		react.onUnmount(function()
			local unsubscribe = unsubscribeRef:get()
			if unsubscribe ~= nil then unsubscribe() end
			unsubscribeRef:set(nil)
			windowIsOpen = false
			luaUtils.debug("bookmarks window closed")
		end)

		local bookmarks : {BmBookmark} = rowsState:old() or {}

		return builtin.BoxLayout{
			child = builtin.Component{
				meta = { class = "bm-bookmarks" },
				layout = builtin.BoxLayout{
					orientation = builtin.type.Orientation.Vertical,
					children = {
						bookmarksList(bookmarks),
						footer(#bookmarks),
						-- The window has a fixed height; the spacer takes the
						-- leftover room so the parts above pack together.
						gui_react_util.makeVerticalSpacer(),
					},
				},
			},
		}
	end)

local BookmarksWindow = react.RegisterWrapperRecipe(
	"BmBookmarksWindow",
	builtin.Window,
	function(params : WindowParams) : TreeNodeId
		return builtin.Window{
			id = WINDOW_ID,
			title = "Bookmarks",
			onClose = params.onClose,
			closable = true,
			autoFocusOnBecomingVisible = true,
			content = BookmarksWindowContent(params),
		}
	end)

------------------------------------------------------------
-- HUD BUTTON
------------------------------------------------------------

-- The icon inside a HUD button (sized by the stylesheet, as the timetable
-- mod's toolbar button does).
local function toolbarIcon(path : string) : TreeNodeId
	return builtin.ImageView{
		meta = { class = "bm-toolbar-icon" },
		path = path,
		scaling = builtin.type.ImageViewScaling.AutoFit,
	}
end

local BookmarksButton = react.RegisterPluginRecipe(
	main_mod_button_area.MainModButtonAreaExtension,
	"BmBookmarksButton",
	function() : TreeNodeId
		local openState = react.useState(false) as ReactStateT<boolean>

		-- The HUD button is mounted for the whole session, so it hosts the
		-- listener that saves camera positions (CAMERA POSITIONS above).
		-- "selectEntity" is the game's own event, fired by map clicks, list
		-- clicks and notifications; every registered listener receives it,
		-- and the game's entity window registers for it the same way.
		react.onEvent("selectEntity", function(_key : string, eventParams : table)
			onSelectEntity(eventParams and eventParams.entity as Engine.Entity)
		end)

		local function onClose()
			local winApi = game_react_globals.getDefaultWindowApi()
			if winApi ~= nil then winApi.removeAllWindows(BookmarksWindow) end
			windowIsOpen = false
			openState:set(false)
		end

		local function open()
			local winApi = game_react_globals.getDefaultWindowApi()
			if winApi == nil then return end
			winApi.addSingletonWindow(BookmarksWindow, { onClose = onClose } as WindowParams)
			windowIsOpen = true
			openState:set(true)
		end

		local children : {TreeNodeId} = {
			builtin.ToggleButton{
				meta = { tooltip = "More Camera: Bookmarked Towns", class = "bm-toolbar-btn" },
				content = toolbarIcon(ICON_BOOKMARKS),
				value = (openState:old() == true) and 1 or 0,
				onValueChange = function(value : integer)
					if value == 1 and not windowIsOpen then
						open()
					elseif value == 0 and windowIsOpen then
						onClose()
					else
						-- The window was closed another way; re-sync the toggle.
						openState:set(windowIsOpen)
					end
				end,
			},
			builtin.Button{
				meta = { tooltip = "More Camera: Go to where you were before", class = "bm-toolbar-btn" },
				content = toolbarIcon(ICON_CAMERA_BACK),
				onClick = function() restorePosition("back button") end,
			},
		}

		return builtin.BoxLayout{
			orientation = builtin.type.Orientation.Horizontal,
			children = children,
		}
	end)

luaUtils.debug("bookmarksGui loaded")

return {
	BmBookmarksButton = BookmarksButton,
}
