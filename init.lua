digiline_io = {}

-- Debug
local function disp(x)
	minetest.chat_send_all(dump(x))
end

function digiline_io.to_string(x)
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

-- Attempt to set channel
-- Checks for permissions
function digiline_io.set_channel(pos, sender, fields, channel_name)
	local channel = fields[channel_name]
	if channel then
		if protected(pos, sender) then return end
		minetest.get_meta(pos):set_string("channel", channel)
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
		set_debug_formspec(meta, "")
	end,
	digiline = {effector = {
		action = function(pos, _, channel, message)
			local meta = minetest.get_meta(pos)
			local text = (
				channel..": "..
				digiline_io.to_string(message):sub(1,1000).."\n"..
				meta:get_string("text")
			):sub(1,1000)
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
		digiline_io.set_channel(pos, sender, fields, "channel")
	end,
})

-- Multi-line input console
-- Text is only sent when the [send] button is clicked

minetest.register_node("digiline_io:input", {
	description = "Digiline Input",
	tiles = {"digiline_io_input.png"},
	groups = {choppy = 3, dig_immediate = 2},
	on_construct = function(pos)
		minetest.get_meta(pos):set_string("formspec",
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
		digiline_io.set_channel(pos, sender, fields, "channel")
		if fields.send then
			if protected(pos, sender) then return end
			digilines.receptor_send(pos, digilines.rules.default, fields.channel, fields.text)
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
		"field[0.5,0.5;4,1;input;Input:;]"..
		"button[4.75,0.25;1,1;clear;CLS]"..
		"textarea[0.5,1.5;5.5,4;output;Output: (top = new);"..
			minetest.formspec_escape(meta:get_string("output")).. -- ${output} would not update properly here
		"]"..
		"field_close_on_enter[input;false]"..
		-- this is added/removed so that the formspec will update every time
		(swap == 1 and " " or "")..
		
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
					message = digiline_io.to_string(message)
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
		digiline_io.set_channel(pos, sender, fields, "send_channel")
		digiline_io.set_channel(pos, sender, fields, "recv_channel")
		
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
		meta:set_string("request_channel","GET") -- needs to be a different channel
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
		digiline_io.set_channel(pos, sender, fields, "recv_channel")
		digiline_io.set_channel(pos, sender, fields, "request_channel")
		digiline_io.set_channel(pos, sender, fields, "send_channel")
	end,
})

dofile(minetest.get_modpath("digiline_io").."/printer.lua")

-- Idea: book scanner?
-- Todo: drop item when printer is broken
-- filter
-- input digiline signal (pattern match?) or mesecon signal
-- output: digiline signal or mesecon signal
-- hmm