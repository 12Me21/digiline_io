-- Debug
local function disp(x)
	minetest.chat_send_all(dump(x))
end

local options = {
	["No Mesecon Output"] = 1,
	["Mesecon Pulse"] = 2,
	["Mesecon Toggle"] = 3,
	["Mesecon On"] = 4,
	["Mesecon Off"] = 5,
}

local function set_controller_formspec(meta)
	meta:set_string("formspec",
		"size[8,7.25]"..
		default.gui_bg_img..
		-- Input
		   "field[0.5,0.5;3.5,1;pattern;Message Pattern:;${pattern}]"..
		   "field[4.5,0.5;3.5,1;in_channel;Input Channel:;${in_channel}]"..
		-- Output (Match)
		   "label[0.25,1.5;If message matches pattern:]"..
		"checkbox[0.25,2   ;true_digiline;Output Digiline Message;"..tostring(meta:get_int("true_digiline")~=0).."]"..
		"dropdown[4.25,2;3.5;true_mesecon;No Mesecon Output,Mesecon Pulse,Mesecon Toggle,Mesecon On,Mesecon Off;"..meta:get_int("true_mesecon").."]"..
		   "field[0.5,3.5;3.5,1;true_message;Message:;${true_message}]"..
		   "field[4.5,3.5;3.5,1;true_channel;Output Channel:;${true_channel}]"..
		-- Output (No match)
		"container[0,3]"..
		   "label[0.25,1.5;If message doesn't match pattern:]"..
		"checkbox[0.25,2   ;false_digiline;Output Digiline Message;"..tostring(meta:get_int("false_digiline")~=0).."]"..
		"dropdown[4.25,2;3.5;false_mesecon;No Mesecon Output,Mesecon Pulse,Mesecon Toggle,Mesecon On,Mesecon Off;"..meta:get_int("false_mesecon").."]"..
		   "field[0.5,3.5;3.5,1;false_message;Message:;${false_message}]"..
		   "field[4.5,3.5;3.5,1;false_channel;Output Channel:;${false_channel}]"..
		"container_end[]"
		
		-- Idea: add options to output when message doesn't match
		-- And maybe hide unused fields (remove digiline channel/message when digiline i/o is not enabled)
		-- and then maybe add options to turn mesecon output on or off (since there are 2 output sets now)
	)
end

local function match(message, pattern, replace)
	local result, matches = message:gsub("^"..pattern.."$", replace, 1)
	if matches == 1 then return result end
end

-- Idea: password terminal
-- Outputs the hash of the entered text

-- result = true_pattern with captured groups, or nil (if message did not match)
local function handle_output(pos, meta, result)
	
	if meta:get_int(result and "true_digiline" or "false_digiline") ~= 0 then -- digiline
		digilines.receptor_send(pos, digiline_io.full_rules, meta:get_string(result and "true_channel" or "false_channel"), result or meta:get_string("false_message"))
	end
	
	local output_type = meta:get_int(result and "true_mesecon" or "false_mesecon")
	if output_type == 2 then -- Pulse
		local node = minetest.get_node(pos)
		if node.name == "digiline_io:controller" or node.name == "digiline_io:controller_on" then
			node.name = "digiline_io:controller_on"
			minetest.swap_node(pos, node)
			mesecon.receptor_on(pos, digiline_io.full_rules)
			minetest.get_node_timer(pos):start(1)
		end
	else
		local node = minetest.get_node(pos)
		if node.name == "digiline_io:controller" then -- Currently Off
			if output_type == 3 or output_type == 4 then -- Mode: Toggle or On
				node.name = "digiline_io:controller_on"
				minetest.swap_node(pos, node)
				mesecon.receptor_on(pos, digiline_io.full_rules)
			end
		elseif node.name == "digiline_io:controller_on" then -- Currently On
			if output_type == 3 or output_type == 5 then -- Mode: Toggle or Off
				node.name = "digiline_io:controller"
				minetest.swap_node(pos, node)
				mesecon.receptor_off(pos, digiline_io.full_rules)
			end
		end
	end
end

local function controller_off(pos)
	local node = minetest.get_node(pos)
	if node.name == "digiline_io:controller_on" then
		node.name = "digiline_io:controller"
		minetest.swap_node(pos, node)
		mesecon.receptor_off(pos, digiline_io.full_rules)
	end
end

local function register_controller(name, not_in_creative_inventory, on_timer, state)
	minetest.register_node(name, {
		description = "Digiline Controller",
		tiles = {"digiline_io_output.png"},
		groups = {choppy = 3, dig_immediate = 2, not_in_creative_inventory = not_in_creative_inventory},
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_int("true_mesecon", 1)
			meta:set_int("false_mesecon", 1)
			set_controller_formspec(meta)
		end,
		
		on_timer = on_timer,
		
		digiline = {
			receptor = {
				rules = digiline_io.full_rules,
			},
			effector = {
				action = function(pos, _, channel, message)
					local meta = minetest.get_meta(pos)
					if channel == meta:get_string("in_channel") then
						if mesecon.do_overheat(pos) then -- why is it `mesecon` instead of `mesecons`?
							minetest.swap_node(pos, {name="digiline_io:overheated_controller"})
							minetest.after(0.2, mesecon.receptor_off, pos, digiline_io.full_rules)
							return
						end
						
						message = tostring(message)
						local status, result = pcall(match, message, meta:get_string("pattern"), meta:get_string("true_message"))
						disp(status)
						disp(result)
						if status then
							handle_output(pos, meta, result)
						else
							--show some kind of error message
						end
					end
				end,
				rules = digiline_io.full_rules,
			},
		},
		on_receive_fields = function(pos, _, fields, sender)
			disp(fields)
			if digiline_io.protect_formspec(pos, sender, fields) then return end
			local meta = minetest.get_meta(pos)
			
			
			
			digiline_io.field(fields, meta, "pattern")
			digiline_io.field(fields, meta, "in_channel")
			
			digiline_io.checkbox(fields, meta, "true_digiline")
			digiline_io.dropdown(fields, meta, "true_mesecon", options)
			digiline_io.field(fields, meta, "true_message")
			digiline_io.field(fields, meta, "true_channel")
			
			digiline_io.checkbox(fields, meta, "false_digiline")
			digiline_io.dropdown(fields, meta, "false_mesecon", options)
			digiline_io.field(fields, meta, "false_message")
			digiline_io.field(fields, meta, "false_channel")
			
			if fields.quit then set_controller_formspec(meta) end
		end,
		mesecons = {
			-- effector = {
				-- rules = digiline_io.full_rules,
				-- action_change = function (pos, _, rule_name, new_state)
					-- local meta = minetest.get_meta(pos)
					-- if
						-- (meta:get_int("mesecon_input_on") ~= 0 and new_state == mesecon.state.on) or
						-- (meta:get_int("mesecon_input_off") ~= 0 and new_state == mesecon.state.off)
					-- then
						-- handle_output(pos, meta, meta:get_string("replace"))
					-- end
				-- end,
			-- },
			receptor = {
				state = state,
				rules = digiline_io.full_rules,
			},
		},
	})
end

register_controller("digiline_io:controller", nil, nil, mesecon.state.off)
register_controller("digiline_io:controller_on", 1, controller_off, mesecon.state.on)

minetest.register_node("digiline_io:overheated_controller", {
	tiles = {"digiline_io_output.png^digiline_io_overheated.png"},
	groups = {choppy = 3, dig_immediate = 2},
	
	digiline = {
		receptor = {
			rules = digiline_io.full_rules,
		},
		--effector = {
		--	rules = controller_rules,
		--},
	},
	mesecons = {
		receptor = {
			rules = digiline_io.full_rules,
			state = mesecon.state.off,
		}
	}
})