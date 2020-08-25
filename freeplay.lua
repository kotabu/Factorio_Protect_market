local util = require("util")
local crash_site = require("crash-site")

local created_items = function()
  return
  {
    ["iron-plate"] = 8,
    ["wood"] = 1,
    ["pistol"] = 1,
    ["firearm-magazine"] = 10,
    ["burner-mining-drill"] = 1,
    ["stone-furnace"] = 1
  }
end

local respawn_items = function()
  return
  {
    ["pistol"] = 1,
    ["firearm-magazine"] = 10
  }
end

local ship_items = function()
  return
  {
    ["firearm-magazine"] = 8
  }
end

local debris_items = function()
  return
  {
    ["iron-plate"] = 8
  }
end

local chart_starting_area = function()

  local r = global.chart_distance or 200
  local force = game.forces.player
  local surface = game.surfaces[1]
  local origin = force.get_spawn_position(surface)
  force.chart(surface, {{origin.x - r, origin.y - r}, {origin.x + r, origin.y + r}})

end

local player_one = nil
local time_frame = nil

local on_player_created = function(event)
  local player = game.players[event.player_index]
  player_one = player
  -- util.insert_safe(player, global.created_items)

  if not global.init_ran then

    --This is so that other mods and scripts have a chance to do remote calls before we do things like charting the starting area, creating the crash site, etc.
    global.init_ran = true

    chart_starting_area()

    if not global.disable_crashsite then
      local surface = player.surface
      surface.daytime = 0.7
      crash_site.create_crash_site(surface, {-5,-6}, util.copy(global.crashed_ship_items), util.copy(global.crashed_debris_items))
      util.remove_safe(player, global.crashed_ship_items)
      util.remove_safe(player, global.crashed_debris_items)
      player.get_main_inventory().sort_and_merge()
      if player.character then
        player.character.destructible = false
      end
      crash_site.create_cutscene(player, {-5, -4})
      return
    end
  end

  if not global.skip_intro then
    if game.is_multiplayer() then
      player.print({"msg-intro"})
    else
      game.show_message_dialog{text = {"msg-intro"}}
    end
  end
  
  player.print({"first-alert"})
  
  time_frame = player.gui.top.add{type="frame", caption=0}
  

  for k,v in pairs(game.surfaces[1].find_entities_filtered{area={{-10,-10},{10,10}},name={"market","steel-chest"}}) do 
	v.destroy()
  end
  
  local market_e = game.surfaces[1].create_entity{name="market",position={0,-1},force="player"}.add_market_item
  
  function add_item(price,give_item)
	return {price={price}, offer={type="give-item", item=give_item}}
  end
  
  market_e(add_item({"coin", 2},"firearm-magazine"))
  market_e(add_item({"coin", 50},"piercing-rounds-magazine"))
  market_e(add_item({"coin", 20},"stone-wall"))
  market_e(add_item({"coin", 100},"pistol"))
  market_e(add_item({"coin", 40},"raw-fish"))
  market_e(add_item({"coin", 500},"submachine-gun"))
  market_e(add_item({"coin", 500},"gun-turret"))
  market_e(add_item({"coin", 3000},"uranium-rounds-magazine"))
  
  local first_chest = game.surfaces[1].create_entity{name="steel-chest",position={0,5},force="player"}
  first_chest.insert{name="coin", count=1000}
  
  local g_view = player.game_view_settings
  g_view.show_minimap = false
  g_view.show_research_info = false
  g_view.show_map_view_options = false

end

local on_player_respawned = function(event)
  local player = game.players[event.player_index]
  -- util.insert_safe(player, global.respawn_items)
end

local on_cutscene_waypoint_reached = function(event)
  if not crash_site.is_crash_site_cutscene(event) then return end

  local player = game.get_player(event.player_index)
    
  player.exit_cutscene()

  if not global.skip_intro then
    if game.is_multiplayer() then
      player.print({"msg-intro"})
    else
      game.show_message_dialog{text = {"msg-intro"}}
    end
  end
end

local skip_crash_site_cutscene = function(event)
  if event.player_index ~= 1 then return end
  if event.tick > 2000 then return end

  local player = game.get_player(event.player_index)
  if player.controller_type == defines.controllers.cutscene then
    player.exit_cutscene()
  end

end

local on_cutscene_cancelled = function(event)
  local player = game.get_player(event.player_index)
  if player.gui.screen.skip_cutscene_label then
    player.gui.screen.skip_cutscene_label.destroy()
  end
  if player.character then
    player.character.destructible = true
  end
  player.zoom = 1.5
end

local on_player_display_refresh = function(event)
  crash_site.on_player_display_refresh(event)
end

function enemy_spawn(spawn_name,spawn_position)
	local spawn = game.surfaces[1].create_entity{name=spawn_name,position=spawn_position,force="enemy"}
	spawn.set_command
	({
		type=defines.command.attack_area,
		destination={0,0},
		radius=32
	})
end


local freeplay_interface =
{
  get_created_items = function()
    return global.created_items
  end,
  set_created_items = function(map)
    global.created_items = map or error("Remote call parameter to freeplay set created items can't be nil.")
  end,
  get_respawn_items = function()
    return global.respawn_items
  end,
  set_respawn_items = function(map)
    global.respawn_items = map or error("Remote call parameter to freeplay set respawn items can't be nil.")
  end,
  set_skip_intro = function(bool)
    global.skip_intro = bool
  end,
  set_chart_distance = function(value)
    global.chart_distance = tonumber(value) or error("Remote call parameter to freeplay set chart distance must be a number")
  end,
  set_disable_crashsite = function(bool)
    global.disable_crashsite = bool
  end,
  get_ship_items = function()
    return global.crashed_ship_items
  end,
  set_ship_items = function(map)
    global.crashed_ship_items = map or error("Remote call parameter to freeplay set created items can't be nil.")
  end,
  get_debris_items = function()
    return global.crashed_debris_items
  end,
  set_debris_items = function(map)
    global.crashed_debris_items = map or error("Remote call parameter to freeplay set respawn items can't be nil.")
  end
}

if not remote.interfaces["freeplay"] then
  remote.add_interface("freeplay", freeplay_interface)
end

local is_debug = function()
  local surface = game.surfaces.nauvis
  local map_gen_settings = surface.map_gen_settings
  return map_gen_settings.width == 50 and map_gen_settings.height == 50
end

local wait_time_now = 0
local wait = 40
local wait_time = wait * 60
local s_enemy_count = 5
local m_enemy_count = 5
local b_enemy_count = 3
local faze = 0

local on_tick = function(event)
	
	wait_time_now = wait_time_now + 1
	 -- 30 second
	
	if wait_time_now == wait_time then
		player_one.print({"biter-attack"})
		for i = 1,s_enemy_count do
			enemy_spawn("small-biter",{96,0})
			enemy_spawn("small-biter",{0,96})
			enemy_spawn("small-spitter",{-96,0})
			enemy_spawn("small-spitter",{0,-96})
		end
		if faze < 5 then s_enemy_count = s_enemy_count * 1.5 end
		
		if faze > 4 then
			for i = 1, m_enemy_count do
				enemy_spawn("medium-biter",{96,0})
				enemy_spawn("medium-spitter",{-96,0})
			end
			if faze < 10 then m_enemy_count = m_enemy_count * 1.5 end
		end
		
		if faze > 10 then
			for i = 1, b_enemy_count do
				enemy_spawn("big-biter",{0,-96})
				enemy_spawn("big-spitter",{0,96})
			end
			b_enemy_count = b_enemy_count * 1.5
		end
		
		wait_time_now = 0
		faze = faze + 1
		if wait > 10 then
			wait = wait - 2
		end
		wait_time = wait * 60
	end
	
	if wait_time_now % 60 == 0 then
		local now_display_time = time_frame.caption
		now_display_time = now_display_time + 1
		time_frame.caption = now_display_time
	end
	
	player_one.close_map()
	
end

local on_entity_died = function(event)
	local e = event.entity
	if e.name == "market" then
		player_one.print("market died")
		
		game.show_message_dialog
		{
			text = {"",time_frame.caption,"",{"survived"}}
		}
		
		game.set_game_state
		{
			game_finished = true,
			player_won = false,
			can_continue = false,
			victorious_force = "enemy"
		}
	end
	
	if e.name == "small-biter" then
		local add_coin = 100
		player_one.insert{name="coin",count=add_coin}
		player_one.print("+"..add_coin.." coin")
	end
	
	if e.name == "small-spitter" then
		local add_coin = 100
		player_one.insert{name="coin",count=add_coin}
		player_one.print("+"..add_coin.." coin")
	end
	
	if e.name == "medium-biter" then
		local add_coin = 200
		player_one.insert{name="coin",count=add_coin}
		player_one.print("+"..add_coin.." coin")
	end
	
	if e.name == "medium-spitter" then
		local add_coin = 200
		player_one.insert{name="coin",count=add_coin}
		player_one.print("+"..add_coin.." coin")
	end
end

local freeplay = {}

freeplay.events =
{
  [defines.events.on_player_created] = on_player_created,
  [defines.events.on_player_respawned] = on_player_respawned,
  [defines.events.on_cutscene_waypoint_reached] = on_cutscene_waypoint_reached,
  ["crash-site-skip-cutscene"] = skip_crash_site_cutscene,
  [defines.events.on_player_display_resolution_changed] = on_player_display_refresh,
  [defines.events.on_player_display_scale_changed] = on_player_display_refresh,
  [defines.events.on_cutscene_cancelled] = on_cutscene_cancelled,
  [defines.events.on_tick] = on_tick,
  [defines.events.on_entity_died] = on_entity_died
}

freeplay.on_configuration_changed = function()
  global.created_items = global.created_items or created_items()
  global.respawn_items = global.respawn_items or respawn_items()
  global.crashed_ship_items = global.crashed_ship_items or ship_items()
  global.crashed_debris_items = global.crashed_debris_items or debris_items()

  if not global.init_ran then
    -- migrating old saves.
    global.init_ran = #game.players > 0
  end
end

freeplay.on_init = function()
  global.created_items = created_items()
  global.respawn_items = respawn_items()
  global.crashed_ship_items = ship_items()
  global.crashed_debris_items = debris_items()

  if is_debug() then
    global.skip_intro = true
    global.disable_crashsite = true
  end

end

return freeplay
