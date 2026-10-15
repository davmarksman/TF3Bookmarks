-- Styles for the Bookmarks window and the HUD button, loaded by the game
-- from content/. Classes are set with meta.class in the gui scripts; only
-- Components and widgets take them. Selectors are keyed on the recipe that
-- owns the node. Margins and padding are { top, right, bottom, left }.
local ssu = require "::/gui/main/stylesheetutil.lua"

-- The game's colour table, read as the timetable mod does. nil if the
-- read fails, and the rule that needs it is then left out rather than
-- breaking the whole stylesheet (a failed load removes the mod's UI).
local function readColors()
	local ok, colors = pcall(function()
		return api.gui.genericRep.get(api.gui.genericRep.find("::/gui/main/default_colors.gres")).data
	end)
	if ok then return colors end
	return nil
end

function data()
	local result = {}
	local add = ssu.makeAdder(result)
	local colorDefault = readColors()

	-- The HUD buttons (bookmarks_gui.script.tl), icons only: the Bookmarks
	-- toggle and the plain back button. 32 px squares holding a 24 px icon,
	-- like the timetable mod's toolbar button and the game's layers button.
	add("R::BmBookmarksButton ToggleButton!bm-toolbar-btn", {
		size = { 32, 32 },
		minSize = { 32, 32 },
		maxSize = { 32, 32 },
		padding = { 4, 4, 4, 4 },
		margin = { 1, 1, 2, 1 },
		gravity = { 0.5, 0.5 },
	})
	local plainButton = {
		size = { 32, 32 },
		minSize = { 32, 32 },
		maxSize = { 32, 32 },
		padding = { 4, 4, 4, 4 },
		margin = { 1, 1, 2, 1 },
		gravity = { 0.5, 0.5 },
	}
	-- A plain Button paints no background colour in the game's stylesheet;
	-- give it the colour of an unpressed ToggleButton so the two match.
	if colorDefault ~= nil and colorDefault.BaseMedium ~= nil then
		plainButton.backgroundColor1 = colorDefault.BaseMedium
	end
	add("R::BmBookmarksButton Button!bm-toolbar-btn", plainButton)
	add("R::BmBookmarksButton !bm-toolbar-icon", {
		size = { 24, 24 },
		minSize = { 24, 24 },
		maxSize = { 24, 24 },
		gravity = { 0.5, 0.5 },
	})

	-- The window opens centred on the screen (anchor and gravity, as the
	-- timetable mod does) at a fixed size. The id must be dotted.
	add("Window#bm.bookmarks.window", {
		anchorPoint = { 0.5, 0.5 },
		gravity = { 0.5, 0.5 },
		size = { 420, 520 },
	})

	-- The window body.
	add("R::BmBookmarksWindowContent !bm-bookmarks", {
		minSize = { 404, -1 },
		padding = { 8, 8, 8, 8 },
	})

	-- The list scrolls inside a fixed box; its content needs its own width.
	-- The rows are narrower than the box, which leaves the gap before the
	-- scrollbar (a spacer beside the row box takes it, so the scroll area
	-- can't stretch the rows).
	add("R::BmBookmarksWindowContent ScrollArea!bm-bookmarks-scrollarea", {
		size = { 404, 400 },
		minSize = { 404, 400 },
		maxSize = { 404, 400 },
	})
	add("R::BmBookmarksWindowContent !bm-rows", {
		size = { 386, -1 },
		minSize = { 386, -1 },
		maxSize = { 386, -1 },
	})
	add("R::BmBookmarksWindowContent !bm-row", {
		maxSize = { -1, 26 },
	})

	-- The pin and X buttons: 24 px squares holding a 20 px icon.
	add("R::BmBookmarksWindowContent Button!bm-locate", {
		size = { 24, 24 },
		minSize = { 24, 24 },
		maxSize = { 24, 24 },
		padding = { 2, 2, 2, 2 },
		margin = { 0, 4, 0, 0 },
	})
	add("R::BmBookmarksWindowContent Button!bm-remove", {
		size = { 24, 24 },
		minSize = { 24, 24 },
		maxSize = { 24, 24 },
		padding = { 2, 2, 2, 2 },
		margin = { 0, 0, 0, 4 },
	})
	add("R::BmBookmarksWindowContent !bm-pin-icon", {
		size = { 20, 20 },
		minSize = { 20, 20 },
		maxSize = { 20, 20 },
	})

	-- The name is a button without the button chrome (an empty file name
	-- clears the surface and contour images, as the game's own stylesheet
	-- does); its text is anchored left, where a button would centre it.
	add("R::BmBookmarksWindowContent Button!bm-name", {
		padding = { 2, 4, 2, 4 },
		margin = { 0, 0, 0, 0 },
		backgroundImage1 = { fileName = "" },
		borderImage = { fileName = "" },
	})
	add("R::BmBookmarksWindowContent Button!bm-name > *", {
		gravity = { 0, 0.5 },
	})
	add("R::BmBookmarksWindowContent Button!bm-name:hover", {
		backgroundColor = { 1, 1, 1, 0.12 },
		backgroundColor1 = { 1, 1, 1, 0.12 },
	})

	-- The count and the Clear All button under the list.
	add("R::BmBookmarksWindowContent !bm-footer", {
		margin = { 8, 0, 0, 0 },
	})

	return result
end
