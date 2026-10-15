function data()
	return {
		-- Adds the Bookmarks card to the town window
		-- (react-plugin at the base-game "::TownEowExtensionPoint").
		-- "@BmTownCard" is the key in bookmark_card_gui.script.tl's return table.
		type = "react-plugin ::TownEowExtensionPoint",
		data = {
			filePath = "bottle_bookmarks::/gui/bookmark_card_gui.script@BmTownCard",
			order = 100,
		}
	}
end
