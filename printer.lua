local compat_pipeworks = pipeworks or {}

-- Book printer
-- Adds text to books/written books
-- For unwritten books, the first line of text will be the title
-- Line breaks are added after every message
-- Author is set to "[Printer]"

-- taken from default mod:
local lines_per_page = 14
local max_text_size = 10000
local max_title_size = 80
local short_title_size = 35

-- Certain fields cannot be empty, because when you try to set a metadata string to "" it just removes that string
-- Which is fine, normally, since meta:get_string(name) returns "" when there's no value with that name
-- Except, then, the table generated by meta:to_table() will not contain those fields
-- And the default books can't handle that
local function not_empty(str)
	return str ~= "" and str or "\f"
end

local function make_book_data(title, text, author)
	-- Make short title (for item description)
	if #title > short_title_size then
		title = title:sub(1, short_title_size - 3) .. "..."
	end
	-- Count number of lines of text
	local lines = 1
	for _ in string.gmatch(text, "\n") do
		lines = lines + 1
	end
	
	return {
		title = not_empty(title):sub(1, max_title_size),
		text = not_empty(text):sub(1, max_text_size),
		owner = author,
		description = [["]]..title..[[" by ]]..author,
		page = 1,
		page_max = math.ceil(lines / lines_per_page), -- This might not be working perfectly
		-- The builtin book item is weird
	}
end

local function can_insert_book(inv, listname, index, stack)
	if listname == "main" then
		local name = stack:get_name()
		if name ~= "default:book" and name ~= "default:book_written" then return false end
		if inv:get_stack(listname, index):get_count() ~= 0 then return false end
	end
	return true
end

minetest.register_node("digiline_io:printer", {
	description = "Digiline Book Printer",
	tiles = {
		-- Add connection textures if pipeworks is installed
		minetest.get_modpath("pipeworks") and
		"digiline_io_printer.png^pipeworks_tube_connection_metallic.png" or 
		"digiline_io_printer.png"
	},
	groups = {choppy = 3, dig_immediate = 2, tubedevice = 1, tubedevice_receiver = 1},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size("main", 1)
		meta:set_string("formspec",
			"size[8,6.5]"..
			default.gui_bg_img..
			default.gui_slots..
			"label[0.5,0;Book:]"..
			"list[current_name;main;0.5,0.5;1,1;]"..
			"field[2.25,0.75;5.5,1;channel;Digiline Channel:;${channel}]"..
			"list[current_player;main;0,2.25;8,1;]"..
			"list[current_player;main;0,3.5;8,3;8]"..
			"listring[current_name;main]"..
			"listring[current_player;main]"
		)
		meta:set_string("infotext","Digiline Book Printer")
	end,
	digiline = {effector = {
		rules = digiline_io.full_rules,
		action = function(pos, _, channel, message)
			local node_meta = minetest.get_meta(pos)
			if channel == node_meta:get_string("channel") then
				message = digiline_io.to_string(message)--:gsub("\r\n?","\n")
				local inv = node_meta:get_inventory()
				local item = inv:get_stack("main", 1)
				if item:get_count() ~= 1 then return end
				
				local item_name = item:get_name()
				local item_meta = item:get_meta()
				local title, text
				-- New book: Set title
				if item_name == "default:book" then
					local line_break = message:find("\n", 1, true)
					if line_break then
						title = message:sub(1, line_break-1)
						text = message:sub(line_break + 1)
					else
						title = message
						text = ""
					end
					item:set_name("default:book_written")
				-- Written book: Insert text
				elseif item_name == "default:book_written" then
					title = item_meta:get_string("title")
					
					local old_text = item_meta:get_string("text")
					if old_text ~= "\f" then
						text = old_text .. message .. "\n"
					else
						text = message .. "\n"
					end
				else
					return
				end
				item_meta:from_table({fields = make_book_data(title, text, "[Printer]")})
				inv:set_stack("main", 1, item)
			end
		end,
	}},
	tube = {
		insert_object = function(pos, node, stack, direction)
			minetest.get_meta(pos):get_inventory():add_item("main", stack:take_item(1))
			return stack
		end,
		-- Idea: eject current book when new one is inserted
		-- Also: send digiline signal when book is inserted?
		can_insert = function(pos, node, stack, direction)
			return can_insert_book(minetest.get_meta(pos):get_inventory(), "main", 1, stack)
		end,
		input_inventory = "main",
		connect_sides = {left = 1, right = 1, front = 1, back = 1, bottom = 1, top = 1},
	},
	
	after_place_node = compat_pipeworks.after_place,
	after_dig_node = function(pos, old_node, old_meta_table, player)
		digiline_io.after_dig_drop_contents(pos, old_node, old_meta_table, player)
		if compat_pipeworks.after_dig then compat_pipeworks.after_dig(pos, old_node, old_meta_table, player) end
	end,
	--on_rotate = compat_pipeworks.on_rotate,
	
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		return can_insert_book(minetest.get_meta(pos):get_inventory(), listname, index, stack) and 1 or 0
	end,
	-- Formspec submit (change digiline channel)
	on_receive_fields = function(pos, _, fields, sender)
		if digiline_io.protect_formspec(pos, sender, fields) then return end
		digiline_io.field(fields, minetest.get_meta(pos), "channel")
	end,
})