--[[
Afk Kick mod for Minetest by GunshipPenguin

To the extent possible under law, the author(s)
have dedicated all copyright and related and neighboring rights
to this software to the public domain worldwide. This software is
distributed without any warranty.
]]

-- Settings
local MAX_INACTIVE_TIME = 300
local CHECK_INTERVAL = 1
local WARN_TIME = 20

local players = {}
local checkTimer = 0

minetest.register_on_joinplayer(function(player)
	local playerName = player:get_player_name()
	players[playerName] = {
		lastAction = minetest.get_gametime()
	}
end)

minetest.register_on_leaveplayer(function(player)
	local playerName = player:get_player_name()
	players[playerName] = nil
end)

minetest.register_on_chat_message(function(playerName, message)
	-- Verify that it's a player and that it is not the terminal
	if not playerName or not minetest.get_player_by_name(playerName) then
		return -- Abort tracking the last action
	end
	players[playerName]["lastAction"] = minetest.get_gametime()
end)

-- Provide a priv to prevent being kicked
minetest.register_privilege("bypass_afk_kick", {
	description = "Don't get kicked for being AFK.",
	give_to_singleplayer = true,
})

minetest.register_globalstep(function(dtime)
	local currGameTime = minetest.get_gametime()

	--Check for inactivity once every CHECK_INTERVAL seconds
	checkTimer = checkTimer + dtime

	local checkNow = checkTimer >= CHECK_INTERVAL
	if checkNow then
		checkTimer = checkTimer - CHECK_INTERVAL
	end

	--Loop through each player in players
	for playerName, info in pairs(players) do
		local player = minetest.get_player_by_name(playerName)
		if player then
			--Check if this player is doing an action
			for _, keyPressed in pairs(player:get_player_control()) do
				if keyPressed then
					info["lastAction"] = currGameTime
				end
			end

			if checkNow then
				--Kick player if he/she has been inactive for longer than MAX_INACTIVE_TIME seconds
				if info["lastAction"] + MAX_INACTIVE_TIME < currGameTime then
					-- Only kick the player if they don't have bypass_afk_kick
					if not minetest.check_player_privs(playerName, {bypass_afk_kick = true}) then
						minetest.kick_player(playerName, "Kicked for inactivity")
					end
				end

				--Warn player if he/she has less than WARN_TIME seconds to move or be kicked
				-- Only show this if they can be kicked
				if info["lastAction"] + MAX_INACTIVE_TIME - WARN_TIME < currGameTime and not minetest.check_player_privs(playerName, {bypass_afk_kick = true}) then
					minetest.chat_send_player(playerName,
						minetest.colorize("#FF8C00", "Warning, you have " ..
						tostring(info["lastAction"] + MAX_INACTIVE_TIME - currGameTime + 1) ..
						" seconds to move or be kicked"))
				end
			end
		else
			-- Clean up garbage
			players[playerName] = nil
		end
	end
end)
