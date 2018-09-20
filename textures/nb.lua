-- GENERATED CODE
-- Node Box Editor, version 0.9.0
-- Namespace: test

minetest.register_node("test:node_1", {
	tiles = {
		"default_wood.png",
		"default_wood.png",
		"default_wood.png",
		"default_wood.png",
		"digiline_io_terminal_back.png",
		"digiline_io_terminal_front.png"
	},
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.4375, -0.5, -0.4375, 0.4375, -0.4375, -0.0625}, -- Keyboard
			{-0.375, -0.5, -0.375, 0.375, -0.40625, -0.125}, -- Keys
			{-0.375, -0.375, 0.03125, 0.375, 0.125, 0.5}, -- Screen
			{-0.375, 0.125, 0, 0.375, 0.1875, 0.5}, -- Screen_Top
			{-0.375, -0.5, 0, 0.375, -0.375, 0.5}, -- Screen_Bottom
			{-0.375, -0.375, 0, -0.3125, 0.125, 0.0625}, -- Screen_Left
			{0.3125, -0.375, 0, 0.375, 0.125, 0.0625}, -- Screen_Right
		}
	}
})

