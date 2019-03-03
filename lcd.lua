local RESOLUTION = 80

-- 2 node pixels (to match the texture) + 2 screen pixels (for padding)
local TOP_BORDER = 2/16 * RESOLUTION + 2
local SIDE_BORDER = 1/16 * RESOLUTION + 2

-- These control the spacing between chars
local CHAR_WIDTH = 6
local CHAR_HEIGHT = 9

local LINE_LENGTH = math.floor((RESOLUTION - SIDE_BORDER * 2) / CHAR_WIDTH)
local NUMBER_OF_LINES = math.floor((RESOLUTION - TOP_BORDER * 2) / CHAR_HEIGHT)

--adjust the borders so that the text is "centered"
TOP_BORDER = math.floor(RESOLUTION - CHAR_HEIGHT * NUMBER_OF_LINES) / 2
SIDE_BORDER = math.floor(RESOLUTION - CHAR_WIDTH * LINE_LENGTH) / 2

display_api.register_display_entity("digiline_io:text")

-- (Iterator function)
-- Wraps a string to a certain size and avoid breaking words if possible.
-- O(n)
-- Returns the cursor position and index given a string + width/height
local function wrap_text(text, columns, rows)
	local last_space
	local prev_line_end = 0
	local x, y = 0, -1
	local i = 0
	return function()
		i = i + 1
		if i > #text then return end -- stop at the end of the string
		-- At the start of each line, move the cursor to the next row, and
		-- scan the following characters to decide where the next line starts
		if i == prev_line_end + 1 then
			x = 0
			y = y + 1
			if y == rows then return end -- stop
			-- Search for a spot to break the line
			-- (Either the first \n, or last space)
			for j = i, prev_line_end + columns do
				local char = text:sub(j,j)
				if char == "" or char == "\n" then
					prev_line_end = j
					break
				elseif char:find("[%W]") then
					prev_line_end = j
				end
			end
			-- If there wasn't a nice spot to break the line:
			if prev_line_end + 1 == i then prev_line_end = prev_line_end + columns end
		else
			x = x + 1
		end
		
		return x, y, i
	end
end

-- Generate texture string
local function generate_texture(text, columns, rows)
	local texture = "[combine:"..RESOLUTION.."x"..RESOLUTION
	for x, y, i in wrap_text(text, columns, rows) do
		print(x,y)
		local char = text:byte(i)
		if char >= 33 and char <= 127 then -- printable ASCII (except space) and \127 
			-- :<x>,<y>=lcd_.png\^[sheet\:96x1\:<char>,0
			-- (those are real backslashes in the string)
			texture = texture..":"..
				(SIDE_BORDER + x * CHAR_WIDTH)..",".. -- dest x
				(TOP_BORDER + y * CHAR_HEIGHT).. -- dest y
				[[=lcd_.png\^[sheet\:96x1\:]].. -- source sheet
				(char - 32)..",0" -- source tile
		end
	end
	return texture
end

-- If you want to split the font sheet into one file for each character
-- (Which might be faster or slower, I'm not sure. It's certainly a million times more annoying to deal with 96 texture files)
-- name them "lcd_1.png" to "lcd_95.png", where the number is the ascii code minus 32
-- and use this function instead of the previous one:

--[[local function generate_texture(text, columns, rows)
	local texture = "[combine:"..RESOLUTION.."x"..RESOLUTION
	for x, y, i in wrap_text(text, columns, rows) do
		print(x,y)
		local char = text:byte(i)
		if char >= 33 and char <= 127 then -- printable ASCII + 1 (except space)
			-- :<x>,<y>=font.png\^[sheet\:96x1\:<byte>,0
			-- (those are real backslashes in the string, not escaped chars)
			texture = texture..":"..
				(SIDE_BORDER + x * CHAR_WIDTH)..",".. -- dest x
				(TOP_BORDER + y * CHAR_HEIGHT).. -- dest y
				"=lcd_"..(char-32)..".png" -- source image
		end
	end
	return texture
end--]]


-- Convert a string to readable form
local function readable(thing)
	if type(thing) == "string" then
		return thing
	elseif type(thing) == "number" then
		return tostring(thing)
	else
		return dump(thing)
	end
end

local function lcd_receive(pos, _, channel, message)
	local meta = minetest.get_meta(pos)
	if meta:get_string("channel") == channel then
		meta:set_string("text", readable(message))
		display_lib.update_entities(pos)
	end
end

minetest.register_node("digiline_io:lcd", {
	description = "Digiline LCD",
	
	-- Textures
	tiles = {
		"digiline_io_lcd_sides.png","digiline_io_lcd_sides.png",
		"digiline_io_lcd_sides.png","digiline_io_lcd_sides.png",
		"digiline_io_lcd_sides.png","digiline_io_lcd_front.png",
	},
	inventory_image = "digiline_io_lcd_item.png",
	wield_image = "digiline_io_lcd_item.png",
	
	-- Light
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 6,
	
	-- Nodebox
	paramtype2 = "facedir",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-8/16, -8/16, 6/16, 8/16, 8/16, 8/16},
		}
	},
	
	groups = {choppy = 3, dig_immediate = 2, display_modpack_node = 1},
	
	-- Display lib
	display_entities = {
		["digiline_io:text"] = {
			depth = 0.437 - 1/16,
			on_display_update = function(pos, objref)
				local meta = minetest.get_meta(pos)
				objref:set_properties({
					textures = {generate_texture(meta:get_string("text"), LINE_LENGTH, NUMBER_OF_LINES)},
					visual_size = {x=1, y=1},
				})
			end,
		},
	},
	on_place = display_lib.on_place,
	on_rotate = display_lib.on_rotate,
	on_construct = function(pos)
		minetest.get_meta(pos):set_string("formspec", "field[channel;Channel;${channel}]")
		display_lib.on_construct(pos)
	end,
	on_destruct = display_lib.on_destruct,
	
	-- Formspec
	on_receive_fields = function(pos, _, fields, sender)
		if digiline_io.protect_formspec(pos, sender, fields) then return end
		digiline_io.field(fields, minetest.get_meta(pos), "channel")
	end,
	
	-- Digilines
	digiline = {effector = {
		action = lcd_receive,
	}},
})

minetest.register_craft({
	output = "digiline_io:lcd",
	recipe = {
		{"default:steel_ingot", "digilines:wire_std_00000000", "default:steel_ingot"},
		{"mesecons_lightstone:lightstone_green_off","mesecons_microcontroller:microcontroller0000","mesecons_lightstone:lightstone_green_off"},
		{"default:glass","default:glass","default:glass"}
	}
})