-- Bookmarks: the "Bookmarks" card in the town window and the vehicle window.
--
-- Registered by town_eow.res.lua on every town window and by
-- vehicle_eow.res.lua on every vehicle window. One blue button that reads
-- "Bookmark" or "Remove Bookmark" and flips the entity's bookmark in the
-- store (scripts/bookmarks_store). The label is read from the store when
-- the window opens and on the card's own clicks only: a removal made in the
-- Bookmarks window leaves the card stale until the entity window is
-- reopened (by design, no live update), which is why the click asks the
-- store, not the React state, what to do.
--
-- No timer, no engine reads in the recipe body. The one engine read (the
-- entity's name) happens in the click handler.

local react              = ug_require "::/gui/main/react.lua" as React
local builtin            = ug_require "::/gui/main/builtin.lua" as Builtin
local gui_react_util     = ug_require "::/gui/main/gui_react_util.tl" as GuiReactUtil
local button_react_util  = ug_require "::/gui/main/button_react_util.tl" as ButtonReactUtil
local content_card       = ug_require "::/gui/main/content_card.tl" as ContentCard
local town_eow           = ug_require "::/gui/entity_window/town/town_eow.script.tl" as TownEow
local vehicle_eow        = ug_require "::/gui/entity_window/vehicle/vehicle_eow.script.tl" as VehicleEow

-- Own modules go through a path constant and a cast to their record in
-- tealdef/bm_def.d.tl, because `tl check` can't resolve "<modId>::/" paths.
local STORE : string = "bottle_bookmarks::/scripts/bookmarks_store.script.tl"
local LUA_UTILS : string = "bottle_bookmarks::/scripts/lua_utils.script.tl"
local store = require(STORE) as BmBookmarksStore
local luaUtils = require(LUA_UTILS) as BmLuaUtils

local record CardParams
	entity : Engine.Entity
	kind : string   -- "town" or "vehicle": stored with the bookmark, used in the tooltips
end

local BmBookmarkCardContent = react.RegisterRecipe(
	"BmBookmarkCardContent",
	function(params : CardParams) : TreeNodeId
		local entity : Engine.Entity = params.entity
		-- Read once when the card mounts; flipped by the clicks below.
		local bookmarkedState = react.useState(store.isBookmarked(entity)) as ReactStateT<boolean>
		local bookmarked : boolean = bookmarkedState:old() == true

		local function onClick()
			if store.isBookmarked(entity) then
				store.remove(entity)
			else
				local name : string = api.engine.util.getEntityName(entity)
				if name == nil or name == "" then name = "?" end
				store.add(entity, params.kind, name)
			end
			-- Read back rather than guessed, so label and store always agree.
			bookmarkedState:set(store.isBookmarked(entity))
		end

		local tooltip = bookmarked
			and ("Remove this " .. params.kind .. " from the Bookmarks list.")
			or ("Add this " .. params.kind .. " to the Bookmarks list (the Bookmarks button in the HUD).")

		return builtin.BoxLayout{
			orientation = builtin.type.Orientation.Horizontal,
			children = {
				button_react_util.makeTextButton(
					"primary",
					bookmarked and "Remove Bookmark" or "Bookmark",
					onClick,
					tooltip),
				gui_react_util.makeHorizontalSpacer(),
			},
		}
	end)

-- The card for one entity window. Both window kinds hand their params in
-- as the shared extension interface.
local function makeCard(params : EowExtensionUtil.IEowWidgetsExtensionParams, kind : string) : TreeNodeId
	-- `any`: ContentCardParam doesn't declare meta.localKey. The key
	-- carries the entity id so a reopened window remounts the content and
	-- re-reads the label from the store.
	local cardParam : any = {
		meta = { localKey = "bmCard_" .. kind .. "_" .. tostring(params.entityId) },
		title = "Bookmarks",
		initialCalloutTextPermanent = "",
		recipeAndParamPermanent = content_card.makeRecipeAndParam(BmBookmarkCardContent, { entity = params.entityId, kind = kind } as CardParams),
		hasPermanentFocusables = true,
		gameCtx = params.gameCtx,
		showOnRightSide = params.showCalloutOnRightSide,
	}
	return builtin.BoxLayout{
		child = content_card.ContentCard(cardParam),
	}
end

local BmTownCard = react.RegisterPluginRecipe(
	town_eow.TownEowExtensionPoint,
	"BmTownCard",
	function(params : TownEow.TownWidgetPluginParams) : TreeNodeId
		return makeCard(params, "town")
	end)

local BmVehicleCard = react.RegisterPluginRecipe(
	vehicle_eow.VehicleEowExtensionPoint,
	"BmVehicleCard",
	function(params : VehicleEow.VehicleWidgetPluginParams) : TreeNodeId
		return makeCard(params, "vehicle")
	end)

luaUtils.debug("bookmarkCardGui loaded")

return {
	BmTownCard = BmTownCard,
	BmVehicleCard = BmVehicleCard,
}
