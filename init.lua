digiline_io = {};

digiline_io.full_rules = {
	{x= 0, y=-1, z= 0}, -- down
	{x= 0, y= 1, z= 0}, -- up
	{x= 1, y= 0, z= 0}, -- sideways
	{x=-1 ,y= 0, z= 0}, --
	{x= 0, y= 0, z= 1}, --
	{x= 0, y= 0, z=-1}, --
	{x= 1, y=-1, z= 0}, -- sideways + down
	{x=-1 ,y=-1, z= 0}, --
	{x= 0, y=-1, z= 1}, --
	{x= 0, y=-1, z=-1}, --
	{x= 1, y= 1, z= 0}, -- sideways + up
	{x=-1 ,y= 1, z= 0}, --
	{x= 0, y= 1, z= 1}, --
	{x= 0, y= 1, z=-1}, --
}

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

function digiline_io.after_dig_drop_contents(pos, old_node, old_meta_table, player)
	if old_meta_table.inventory then
		for _, list in pairs(old_meta_table.inventory) do
			for _, stack in ipairs(list) do
				if not stack:is_empty() then minetest.add_item(pos, stack) end
			end
		end
	end
end

-- true = player tried to modify formspec without permission
-- false = player modified formspec with permission
-- nil = formspec exited without changes
function digiline_io.protect_formspec(pos, player, fields)
	for i in pairs(fields) do
		if i ~= "quit" then
			local name = player:get_player_name()
			if minetest.is_protected(pos, name) then
				minetest.record_protection_violation(pos, name)
				return true
			end
			return false
		end
	end
end

function digiline_io.checkbox(fields, meta, name)
	local value = fields[name]
	if value then
		meta:set_int(name, value=="true" and 1 or 0)
	end
end

function digiline_io.field(fields, meta, name)
	local value = fields[name]
	if value then
		meta:set_string(name, value)
	end
end

function digiline_io.protected(pos, player)
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
		if digiline_io.protected(pos, sender) then return end
		minetest.get_meta(pos):set_string(channel_name, channel)
	end
end

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

local terminal_rules = {
	{x= 0, y=-1, z= 0}, -- down
	{x= 1, y= 0, z= 0}, -- sideways
	{x=-1 ,y= 0, z= 0}, --
	{x= 0, y= 0, z= 1}, --
	{x= 0, y= 0, z=-1}, --
	{x= 1, y=-1, z= 0}, -- sideways + down
	{x=-1 ,y=-1, z= 0}, --
	{x= 0, y=-1, z= 1}, --
	{x= 0, y=-1, z=-1}, --
}

minetest.register_node("digiline_io:terminal", {
	description = "Digiline Terminal",
	paramtype = "light",
	paramtype2 = "facedir",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-7/16, -8/16, -7/16,  7/16,  -7/16, -1/16}, -- Keyboard
			{-6/16, -8/16, -6/16,  6/16,-6.5/16, -2/16}, -- Keys
			{-5/16, -8/16,0.5/16,  5/16,   3/16,  8/16}, -- Screen
			{-5/16,  2/16,  0/16,  5/16,   3/16,0.5/16}, -- Screen_Top
			{-5/16, -8/16,  0/16,  5/16,  -6/16,0.5/16}, -- Screen_Bottom
			{-6/16, -8/16,  0/16, -5/16,   3/16,  8/16}, -- Screen_Left
			{ 5/16, -8/16,  0/16,  6/16,   3/16,  8/16}, -- Screen_Right
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{-7/16, -8/16, -7/16, 7/16,-6.5/16, -1/16}, -- Keyboard
			{-6/16, -8/16,  0/16, 6/16,   3/16,  8/16}, -- Screen
		}
		
	},
	
	tiles = {
		"digiline_io_terminal_top.png", "digiline_io_terminal_bottom.png",
		"digiline_io_terminal_side.png^[transformFX", "digiline_io_terminal_side.png",
		"digiline_io_terminal_back.png", "digiline_io_terminal_front.png",
	},
	
	groups = {choppy = 3, dig_immediate = 2},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		set_input_output_formspec(meta)
		meta:set_string("infotext","Digiline Terminal")
	end,
	
	digiline = {
		receptor = {
			rules = terminal_rules;
		},
		effector = {
			action = function(pos, _, channel, message)
				local meta = minetest.get_meta(pos)
				if channel == meta:get_string("recv_channel") then
					message = digiline_io.to_string(message)
					-- Form feed = clear screen
					-- (Only checking at the start of the message) (Because why would you clear the screen instantly after displaying part of a message?)s
					if message:sub(1,1) == "\f" then
						meta:set_string("output", message:sub(2, 1001))
					else
						meta:set_string("output", (message.."\n"..meta:get_string("output")):sub(1, 1000))
					end
					set_input_output_formspec(meta)
				end
			end,
			rules = terminal_rules;
		},
	},
	on_receive_fields = function(pos, _, fields, sender)
		if digiline_io.protect_formspec(pos, sender, fields) then return end
		
		local meta = minetest.get_meta(pos)
		
		digiline_io.field(fields, meta, "send_channel")
		digiline_io.field(fields, meta, "recv_channel")
		
		if fields.clear then
			meta:set_string("output", "")
			set_input_output_formspec(meta)
		end
		
		if fields.key_enter_field == "input" then
			set_input_output_formspec(meta)
			digilines.receptor_send(pos, terminal_rules, fields.send_channel, fields.input)
		end
	end,
})

dofile(minetest.get_modpath("digiline_io").."/printer.lua")
dofile(minetest.get_modpath("digiline_io").."/lcd.lua")
dofile(minetest.get_modpath("digiline_io").."/controller.lua")

-- Idea: book scanner?