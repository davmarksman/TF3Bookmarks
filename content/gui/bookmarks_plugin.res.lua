-- Registers the "Bookmarks" button in the HUD's mod-button area.
-- Pattern from celmi_timetables: the extension-point id is "::<name>" for a
-- base-game point, and the recipe is the "@Export" of the module's return
-- table. Order 20 puts it after the More Line Stats button (10).
function data()
	return {
		type = "react-plugin ::MainModButtonAreaExtension",
		data = {
			filePath = "bottle_bookmarks::/gui/bookmarks_gui.script@BmBookmarksButton",
			order = 20,
		},
	}
end
