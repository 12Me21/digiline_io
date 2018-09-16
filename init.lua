-- Debug
local function disp(x)
	minetest.chat_send_all(dump(x))
end

local function to_string_readable(x)
	local type_ = type(x)
	if type_ == "string" then 
		return x
	elseif type_ == "table" then
		return dump(x)
	else
		return tostring(x)
	end
end

local function protected(pos, player)
	local name = player:get_player_name()
	if minetest.is_protected(pos, name) then
		minetest.record_protection_violation(pos, name)
		return true
	end
end

-- Debug console
-- Displays digiline messages from all channels
-- New messages added at the top of the output

local function set_debug_formspec(meta, text)
	meta:set_string("formspec",
		"size[6,3.75]"..
		default.gui_bg_img..
		"textarea[0.5,0.25;5.5,4;_;Digiline Events (All Channels) (top = new);"..minetest.formspec_escape(text).."]"
	)
end

minetest.register_node("digiline_io:debug", {
	description = "Digiline Debugger",
	tiles = {"digiline_io_debug.png"},
	groups = {choppy = 3, dig_immediate = 2},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("text", "")
		set_debug_formspec(meta,"")
	end,
	digiline = {effector = {
		action = function(pos, _, channel, message)
			local meta = minetest.get_meta(pos)
			message = to_string_readable(message):sub(1,1000)
			local text = (channel..": "..message.."\n"..meta:get_string("text")):sub(1,1000)
			meta:set_string("text", text)
			set_debug_formspec(meta, text)
		end,
	}},
})

-- Text output console
-- Displays only the last message it recieved.

local function set_output_formspec(meta, text)
	meta:set_string("formspec",
		"size[6,5]"..
		default.gui_bg_img..
		"textarea[0.5,0.25;5.5,4;_;Output:;"..minetest.formspec_escape(text).."]"..
		"field[0.5,4.5;5.5,1;channel;Digiline Channel:;${channel}]"
	)
end

minetest.register_node("digiline_io:output", {
	description = "Digiline Output",
	tiles = {"digiline_io_output.png"},
	groups = {choppy = 3, dig_immediate = 2},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("text", "")
		set_output_formspec(meta, "")
	end,
	digiline = {effector = {
		action = function(pos, _, channel, message)
			local meta = minetest.get_meta(pos)
			if channel == meta:get_string("channel") then
				meta:set_string("text",message)
				set_output_formspec(meta, message)
			end
		end,
	}},
	on_receive_fields = function(pos, _, fields, sender)
		if fields.channel then
			if not protected(pos, sender) then minetest.get_meta(pos):set_string("channel", fields.channel) end
		end
	end,
})

-- Multi-line input console
-- Text is only sent when the [send] button is clicked

minetest.register_node("digiline_io:input", {
	description = "Digiline Input",
	tiles = {"digiline_io_input.png"},
	groups = {choppy = 3, dig_immediate = 2},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
			meta:set_string("formspec",
			"size[6,6]"..
			default.gui_bg_img..
			"textarea[0.5,0.25;5.5,4;text;Input:;]"..
			"button_exit[0.25,4;5.5,1;send;Send]"..
			"field[0.5,5.5;5.5,1;channel;Digiline Channel:;${channel}]"
		)
	end,
	digiline = {receptor = {}},
	on_receive_fields = function(pos, _, fields, sender)
		local meta = minetest.get_meta(pos)
		if fields.channel then
			if protected(pos, sender) then return end
			meta:set_string("channel", fields.channel)
		end
		if fields.send then
			if protected(pos, sender) then return end
			digilines.receptor_send(pos, digilines.rules.default, fields.channel, fields.text)
		end
	end,
})

-- Book printer
-- Adds text to books/written books
-- For unwritten books, the first line of text will be the title
-- Line breaks are added after every message
-- Author is set to "[Printer]"

local lpp = 14 -- Lines per book's page
local max_text_size = 10000
local max_title_size = 80
local short_title_size = 35

local function not_empty(str)
	return str ~= "" and str or "\r"
end

local function make_book_data(title, text, author)
	if #title > short_title_size then
		title = title:sub(1, short_title_size - 3) .. "..."
	end
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
		page_max = math.ceil(lines / lpp),
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
			"size[8,8.5]"..
			default.gui_bg_img..
			default.gui_slots..
			"list[current_name;main;4.75,0.96;1,1;]"..
			"field[0.5,3;5.5,1;channel;Digiline Channel:;${channel}]"..
			"list[current_player;main;0,4.25;8,1;]"..
			"list[current_player;main;0,5.5;8,3;8]"
		)
	end,
	digiline = {effector = {
		action = function(pos, _, channel, message)
			local node_meta = minetest.get_meta(pos)
			if channel == node_meta:get_string("channel") then
				message = to_string_readable(message)
				local inv = node_meta:get_inventory()
				local item = inv:get_stack("main", 1)
				if item:get_count() ~= 1 then return end
				
				local item_name = item:get_name()
				local item_meta = item:get_meta()
				local title, text
				-- New book: Set title
				if item_name == "default:book" then
					local line_break = message:find("\n",1,true)
					if line_break then
						title = message:sub(1,line_break-1)
						text = message:sub(line_break+1)
					else
						title = message
						text = ""
					end
					item:set_name("default:book_written")
				-- Written book: Insert text
				elseif item_name == "default:book_written" then
					title = item_meta:get_string("title")
					
					local old_text = item_meta:get_string("text")
					if old_text ~= "\r" then
						text = old_text .. message .. "\n"
					else
						text = message
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
	after_place_node = pipeworks.after_place,
	after_dig_node = pipeworks.after_dig,
	--on_rotate = pipeworks.on_rotate,
	
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if protected(pos, player) then return end
		return can_insert_book(minetest.get_meta(pos):get_inventory(), listname, index, stack) and 1 or 0
	end,
	on_receive_fields = function(pos, _, fields, sender)
		if fields.channel and not protected(pos, sender) then
			minetest.get_meta(pos):set_string("channel", fields.channel)
		end
	end,
})

-- Input/output console
-- Single line input
-- Recieved text is added to the start of the output field (so, newest text is at the top)
-- (There is no way to set the default scroll position of a textarea)
-- line breaks are added automatically at the end of each message.
-- "\f" (form feed) clears the output

local function set_input_output_formspec(meta)
	local swap = meta:get_int("swap")
	--disp(swap)
	meta:set_string("formspec",
		"size[6,6.5]"..
		default.gui_bg_img..
		--not going to use gui_bg ok...
		"field[0.5,0.5;4,1;input;Input:;]"..
		"button[4.75,0.25;1,1;clear;CLS]"..
		"textarea[0.5,1.5;5.5,4;output;Output: (top = new);"..
			minetest.formspec_escape(meta:get_string("output")).. -- ${output} would not update properly here
		"]"..
		"field_close_on_enter[input;false]"..
		
		-- this is added/removed so that the formspec will update every time
		(swap == 1 and "field_close_on_enter[input;false]" or "")..

		"field[0.5,6;2.5,1;send_channel;Digiline Send Channel:;${send_channel}]"..
		"field[3.5,6;2.5,1;recv_channel;Digiline Receive Channel:;${recv_channel}]"
	)
	meta:set_int("swap", 1 - swap)
end

minetest.register_node("digiline_io:input_output", {
	description = "Digiline Input/Output",
	tiles = {"digiline_io_input_output.png"},
	groups = {choppy = 3, dig_immediate = 2},
	on_construct = function(pos)
		set_input_output_formspec(minetest.get_meta(pos))
	end,
	
	digiline = {
		receptor = {},
		effector = {
			action = function(pos, _, channel, message)
				local meta = minetest.get_meta(pos)
				if channel == meta:get_string("recv_channel") then
					message = to_string_readable(message)
					-- Form feed = clear screen
					-- (Only checking at the start of the message)
					if message:sub(1,1) == "\f" then
						meta:set_string("output", message:sub(2, 1001))
					else
						meta:set_string("output", (message.."\n"..meta:get_string("output")):sub(1, 1000))
					end
					set_input_output_formspec(meta)
				end
			end,
		},
	},
	on_receive_fields = function(pos, _, fields, sender)
		local meta = minetest.get_meta(pos)
		--disp(fields)
		if fields.send_channel and fields.recv_channel then
			if protected(pos, sender) then return end
			meta:set_string("send_channel", fields.send_channel)
			meta:set_string("recv_channel", fields.recv_channel)
		end
		
		if fields.clear then
			if protected(pos, sender) then return end
			meta:set_string("output", "")
			set_input_output_formspec(meta)
		end
		
		if fields.key_enter_field == "input" then
			if protected(pos, sender) then return end
			set_input_output_formspec(meta)
			digilines.receptor_send(pos, digilines.rules.default, fields.send_channel, fields.input)
		end
	end,
})

-- Data storage
-- This device uses THREE(!) digiline channels:
-- Receive: This is where you send data TO the device, to be saved
-- Request: Stored data will be sent when any message is recieved on this channel (instead of the "GET" message used by other devices)
-- Send: Data is sent out through this channel

-- The reason for this is so there isn't 1 value (like "GET") that can't be stored.
-- and other reasons

-- Idea: maybe add send button and split channel input boxes into 2 rows?

minetest.register_node("digiline_io:storage", {
	description = "Digiline Data Storage",
	tiles = {"digiline_io_data_storage.png"},
	groups = {choppy = 3, dig_immediate = 2},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("data", minetest.serialize(nil))
		meta:set_string("formspec",
			"size[6,6]"..
			default.gui_bg_img..
			"textarea[0.5,0.25;5.5,3;_;Data: (cannot be edited from this menu);${data}]"..
			"field[0.5,3.5;5.5,1;recv_channel;Data Receive Channel:;${recv_channel}]"..
			"field[0.5,4.5;5.5,1;request_channel;Request Channel:;${request_channel}]"..
			"field[0.5,5.5;5.5,1;send_channel;Data Send Channel:;${send_channel}]"
		)
		meta:set_string("request_channel","GET")
	end,
	digiline = {
		receptor = {},
		effector = {
		action = function(pos, _, channel, message)
			local meta = minetest.get_meta(pos)
			if channel == meta:get_string("request_channel") then
				digilines.receptor_send(pos, digilines.rules.default, meta:get_string("send_channel"), minetest.deserialize(meta:get_string("data")))
			elseif channel == meta:get_string("recv_channel") then
				meta:set_string("data", minetest.serialize(message))
			end
		end,
	}},
	on_receive_fields = function(pos, _, fields, sender)
		if protected(pos, sender) then return end
		if fields.recv_channel and fields.send_channel and fields.request_channel then
			local meta = minetest.get_meta(pos)
			meta:set_string("recv_channel", fields.recv_channel)		
			meta:set_string("request_channel", fields.request_channel)
			meta:set_string("send_channel", fields.send_channel)
		end
	end,
})

-- Idea: book scanner?
-- Todo: drop item when printer is broken