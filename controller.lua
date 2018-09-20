-- Debug
local function disp(x)
	minetest.chat_send_all(dump(x))
end

local options = {
	input = {
		["Digiline Message"] = 1,
		["Mesecon On"] = 2,
		["Mesecon Off"] = 3,
		["Mesecon Change"] = 4,
	},
	output = {
		["Digiline Message"] = 1,
		["Mesecon Pulse"] = 2,
		["Mesecon Change"] = 3,
	},
}

local function set_controller_formspec(meta)
	meta:set_string("formspec",
		"size[8,7.25]"..
		default.gui_bg_img..
		"checkbox[0.25,0   ;digiline_input;Detect Digiline Message;"..tostring(meta:get_int("digiline_input")~=0).."]"..
		   "field[4.5 ,0.5 ;3.5,1;recv_channel;Digiline Receive Channel:;${recv_channel}]"..
		   "field[0.5 ,1.5 ;7.5,1;pattern;Match Digiline Message:;${pattern}]"..
		   "label[0.25,2.25;Detect Mesecon Change:]"..
		"checkbox[0.5 ,2.5 ;mesecon_input_on;Turning On;"..tostring(meta:get_int("mesecon_input_on")~=0).."]"..
		"checkbox[4.5 ,2.5 ;mesecon_input_off;Turning Off;"..tostring(meta:get_int("mesecon_input_off")~=0).."]"..
		
		"container[0,4]"..
		"checkbox[0.25,0   ;digiline_output;Output Digiline Message;"..tostring(meta:get_int("digiline_output")~=0).."]"..
		   "field[4.5 ,0.5 ;3.5,1;send_channel;Digiline Send Channel:;${send_channel}]"..
		   "field[0.5 ,1.5 ;7.5,1;replace;Digiline Message:;${replace}]"..
		   "label[0.25,2.25;Mesecon Output:]"..
		"checkbox[0.5 ,2.5 ;mesecon_output_pulse;Pulse;"..tostring(meta:get_int("mesecon_output_pulse")~=0).."]"..
		"checkbox[4.5 ,2.5 ;mesecon_output_flip;Flip;"..tostring(meta:get_int("mesecon_output_flip")~=0).."]"..
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

local function handle_output(pos, meta, message)
	local output_type = meta:get_int("output")
	if meta:get_int("digiline_output") ~= 0 then -- digiline
		digilines.receptor_send(pos, digiline_io.full_rules, meta:get_string("send_channel"), message)
	end
	
	-- maybe flip + pulse = pulse off?
	if meta:get_int("mesecon_output_pulse") ~= 0 then -- pulse
		local node = minetest.get_node(pos)
		node.name = "digiline_io:controller_on"
		minetest.swap_node(pos, node)
		mesecon.receptor_on(pos, digiline_io.full_rules)
		minetest.get_node_timer(pos):start(1)
	elseif meta:get_int("mesecon_output_flip") ~= 0 then -- flip state
		local node = minetest.get_node(pos)
		if node.name == "digiline_io:controller_on" then -- on -> off
			node.name = "digiline_io:controller"
			minetest.swap_node(pos, node)
			mesecon.receptor_off(pos, digiline_io.full_rules)
		elseif node.name == "digiline_io:controller" then --off -> on
			node.name = "digiline_io:controller_on"
			minetest.swap_node(pos, node)
			mesecon.receptor_on(pos, digiline_io.full_rules)
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
			meta:set_int("input", 2)
			meta:set_int("output", 1)
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
					if meta:get_int("digiline_input") ~= 0 and channel == meta:get_string("recv_channel") then
						if mesecon.do_overheat(pos) then -- why is it `mesecon` instead of `mesecons`?
							minetest.swap_node(pos, {name="digiline_io:overheated_controller"})
							minetest.after(0.2, mesecon.receptor_off, pos, digiline_io.full_rules)
							return
						end
						
						message = tostring(message)
						local status, result = pcall(match, message, meta:get_string("pattern"), meta:get_string("replace"))
						disp(status)
						disp(result)
						if status then
							if result then
								handle_output(pos, meta, result)
							end
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
			
			digiline_io.checkbox(fields, meta, "digiline_input")
			digiline_io.field(fields, meta, "recv_channel")
			digiline_io.field(fields, meta, "pattern")
			digiline_io.checkbox(fields, meta, "mesecon_input_on")
			digiline_io.checkbox(fields, meta, "mesecon_input_off")
			
			digiline_io.checkbox(fields, meta, "digiline_output")
			digiline_io.field(fields, meta, "send_channel")
			digiline_io.field(fields, meta, "replace")
			digiline_io.checkbox(fields, meta, "mesecon_output_pulse")
			digiline_io.checkbox(fields, meta, "mesecon_output_flip")
			
			if fields.quit then set_controller_formspec(meta) end
		end,
		mesecons = {
			effector = {
				rules = digiline_io.full_rules,
				action_change = function (pos, _, rule_name, new_state)
					local meta = minetest.get_meta(pos)
					if
						(meta:get_int("mesecon_input_on") ~= 0 and new_state == mesecon.state.on) or
						(meta:get_int("mesecon_input_off") ~= 0 and new_state == mesecon.state.off)
					then
						handle_output(pos, meta, meta:get_string("replace"))
					end
				end,
			},
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