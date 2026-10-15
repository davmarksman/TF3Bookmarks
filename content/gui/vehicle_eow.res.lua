function data()
	return {
		-- Adds the Bookmarks card to the vehicle window
		-- (react-plugin at the base-game "::VehicleEowExtensionPoint").
		-- "@BmVehicleCard" is the key in bookmark_card_gui.script.tl's return table.
		-- The game's own cards use orders 0 to 70, so 100 puts ours last.
		type = "react-plugin ::VehicleEowExtensionPoint",
		data = {
			filePath = "bottle_bookmarks::/gui/bookmark_card_gui.script@BmVehicleCard",
			order = 100,
		}
	}
end
