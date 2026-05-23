-- server.lua
local db = dbConnect("sqlite", "mysteries.db")

-- Create the base table if it doesn't exist
dbExec(db, "CREATE TABLE IF NOT EXISTS missions (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, desc TEXT, reward INTEGER, weather INTEGER DEFAULT 0, time TEXT DEFAULT '-1', music TEXT DEFAULT 'None', peds TEXT, int_data TEXT)")

-- Handle older versions of the database by safely adding the new columns
local query = dbQuery(db, "PRAGMA table_info(missions)")
local result = dbPoll(query, -1)
if result then
    local hasWeather, hasTime, hasIntData, hasMusic = false, false, false, false
    for _, col in ipairs(result) do
        if col.name == "weather" then hasWeather = true end
        if col.name == "time" then hasTime = true end
        if col.name == "int_data" then hasIntData = true end
        if col.name == "music" then hasMusic = true end
    end
    if not hasWeather then dbExec(db, "ALTER TABLE missions ADD COLUMN weather INTEGER DEFAULT 0") end
    if not hasTime then dbExec(db, "ALTER TABLE missions ADD COLUMN time TEXT DEFAULT '-1'") end
    if not hasIntData then dbExec(db, "ALTER TABLE missions ADD COLUMN int_data TEXT") end
    if not hasMusic then dbExec(db, "ALTER TABLE missions ADD COLUMN music TEXT DEFAULT 'None'") end
end

local activeMissionPeds = {}

function sendMissionsToClient(player)
    local q = dbQuery(db, "SELECT * FROM missions")
    local res = dbPoll(q, -1)
    if res then
        triggerClientEvent(player, "onClientReceiveMissions", player, res)
    end
end

addEvent("requestMissions", true)
addEventHandler("requestMissions", root, function()
    sendMissionsToClient(client)
end)

addEvent("requestCMOpen", true)
addEventHandler("requestCMOpen", root, function()
    local accName = getAccountName(getPlayerAccount(client))
    if accName and isObjectInACLGroup("user."..accName, aclGetGroup("Admin")) then
        triggerClientEvent(client, "openCM", client)
    else
        outputChatBox("The Creator Menu is available for Admins only.", client, 255, 0, 0)
    end
end)

addEvent("saveNewMystery", true)
addEventHandler("saveNewMystery", root, function(name, desc, reward, weather, timeStr, music, pedsJSON, intJSON)
    dbExec(db, "INSERT INTO missions (name, desc, reward, weather, time, music, peds, int_data) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", name, desc, reward, weather, timeStr, music, pedsJSON, intJSON)
    outputChatBox("Mystery '" .. name .. "' successfully saved to database!", client, 0, 255, 0)
    for _, p in ipairs(getElementsByType("player")) do sendMissionsToClient(p) end
end)

addEvent("updateMystery", true)
addEventHandler("updateMystery", root, function(id, name, desc, reward, weather, timeStr, music, pedsJSON, intJSON)
    -- 1. Correctly update the mystery in the database
    dbExec(db, "UPDATE missions SET name=?, desc=?, reward=?, weather=?, time=?, music=?, peds=?, int_data=? WHERE id=?", name, desc, reward, weather, timeStr, music, pedsJSON, intJSON, id)
    
    -- 2. Let the user know the update worked
    outputChatBox("Mystery updated successfully!", client, 0, 255, 0)
    
    -- 3. IMMEDIATELY fetch the refreshed list and broadcast it to all players so their GUI menus update instantly!
    local query = dbQuery(db, "SELECT * FROM missions")
    local result = dbPoll(query, -1)
    if result then
        triggerClientEvent(root, "onClientReceiveMissions", root, result)
    end
end)

addEvent("deleteMystery", true)
addEventHandler("deleteMystery", root, function(id)
    dbExec(db, "DELETE FROM missions WHERE id=?", id)
    outputChatBox("Mystery successfully deleted.", client, 0, 255, 0)
    for _, p in ipairs(getElementsByType("player")) do sendMissionsToClient(p) end
end)

-- PARTY SYSTEM: Invites
addEvent("sendMissionInvite", true)
addEventHandler("sendMissionInvite", root, function(targetPlayer)
    if isElement(targetPlayer) then
        triggerClientEvent(targetPlayer, "onClientReceiveInvite", targetPlayer, client)
        outputChatBox("Mission invite sent to " .. getPlayerName(targetPlayer) .. ".", client, 0, 255, 0)
    end
end)

addEvent("acceptMissionInvite", true)
addEventHandler("acceptMissionInvite", root, function(leader)
    if isElement(leader) then
        setElementData(client, "missionPartyLeader", leader)
        local members = getElementData(leader, "partyMembers") or {}
        
        -- FIXED: Verify user isn't duplicated in the members array from repeated invites
        local alreadyIn = false
        for _, m in ipairs(members) do
            if m == client then alreadyIn = true; break end
        end
        if not alreadyIn then
            table.insert(members, client)
            setElementData(leader, "partyMembers", members)
        end
        
        outputChatBox(getPlayerName(client) .. " has joined your mystery party!", leader, 0, 255, 0)
        outputChatBox("You joined " .. getPlayerName(leader) .. "'s mystery party! Warping to Verdant Meadows...", client, 0, 255, 0)
        
        setElementPosition(client, 428.0, 2536.0, 16.0)
        setElementInterior(client, 0)
        setElementDimension(client, 0)

        local activeMission = getElementData(leader, "activeMissionData")
        if activeMission then
            triggerClientEvent(client, "onClientSetupMission", client, activeMission, leader)
            if getElementData(leader, "pedsSpawned") then
                triggerClientEvent(client, "onClientHideColShape", client, activeMission.weather or 0, activeMission.int_data)
            end
        end
    end
end)

-- PARTY SYSTEM: Starting the mission
addEvent("startSharedMission", true)
addEventHandler("startSharedMission", root, function(missionData)
    local leader = client
    setElementData(leader, "pedsSpawned", false) 
    setElementData(leader, "activeMissionData", missionData) 
    
    triggerClientEvent(leader, "onClientSetupMission", leader, missionData, leader)
    
    local members = getElementData(leader, "partyMembers") or {}
    for _, member in ipairs(members) do
        if isElement(member) then
            triggerClientEvent(member, "onClientSetupMission", member, missionData, leader)
        end
    end
end)

-- PARTY SYSTEM: Spawning the Peds
addEvent("spawnMissionPedsShared", true)
addEventHandler("spawnMissionPedsShared", root, function(pedsData, reward, leader, weatherID, intDataJSON)
    if getElementData(leader, "pedsSpawned") then return end 
    setElementData(leader, "pedsSpawned", true)
    
    triggerClientEvent(leader, "onClientHideColShape", leader, weatherID, intDataJSON)
    local members = getElementData(leader, "partyMembers") or {}
    for _, member in ipairs(members) do
        if isElement(member) then
            triggerClientEvent(member, "onClientHideColShape", member, weatherID, intDataJSON)
        end
    end

    local playerPeds = {}
    
    for _, pData in ipairs(pedsData) do
        local entity
        local isCar = (pData.eType == "Car")
        
        if isCar then
            entity = createVehicle(pData.model, pData.x, pData.y, pData.z + 1.0)
            if not entity then -- Safety check
                entity = createVehicle(400, pData.x, pData.y, pData.z + 1.0)
            end
            if entity then
                local driver = createPed(0, pData.x, pData.y, pData.z)
                setElementAlpha(driver, 0)
                warpPedIntoVehicle(driver, entity)
                setElementData(entity, "driver", driver)
            end
        else
            entity = createPed(pData.model, pData.x, pData.y, pData.z + 1.5)
            if not entity then -- Safety check if given invalid ped ID
                outputChatBox("Failed to create ped model " .. tostring(pData.model) .. ". Defaulting to CJ.", leader, 255, 0, 0)
                entity = createPed(0, pData.x, pData.y, pData.z + 1.5)
            end
            
            if entity then
                setPedArmor(entity, 100)
                setPedWalkingStyle(entity, tonumber(pData.walkstyle) or 0)
                local safeWep = tonumber(pData.wep) or 0
                if safeWep > 46 then safeWep = 0 end -- Weapon IDs above 46 throw errors
                giveWeapon(entity, safeWep, 9999, true)
                for stat = 69, 79 do setPedStat(entity, stat, 999) end
            end
        end
        
        if entity then
            -- Create radar blip for the entity
            local blip = createBlipAttachedTo(entity, 0, 2, 255, 0, 0, 255)
            setElementData(entity, "bossBlip", blip)
            
            -- Make blip visible only to the leader and party
            for _, p in ipairs(getElementsByType("player")) do
                setElementVisibleTo(blip, p, false)
            end
            setElementVisibleTo(blip, leader, true)
            local currentMembers = getElementData(leader, "partyMembers") or {}
            for _, member in ipairs(currentMembers) do
                if isElement(member) then
                    setElementVisibleTo(blip, member, true)
                end
            end

            -- Freeze the entity so it doesn't fall through the floor of an unloaded interior
            setElementFrozen(entity, true) 
            setElementSyncer(entity, leader) 
            setElementAlpha(entity, pData.alpha or 255) 
            setElementInterior(entity, pData.interior or 0)
            setElementDimension(entity, pData.dimension or 0)
            
            setElementData(entity, "isMysteryPed", true)
            setElementData(entity, "eType", pData.eType or "Ped")
            setElementData(entity, "bossHealth", pData.hp)
            setElementData(entity, "maxBossHealth", pData.hp)
            setElementData(entity, "pedAccuracy", pData.acc) 
            setElementData(entity, "pedBehavior", pData.behavior or "chase")
            setElementData(entity, "pedVuln", pData.vuln or "Normal")
            setElementData(entity, "canTeleport", pData.teleport)
            setElementData(entity, "canHeavyPunch", pData.heavypunch) -- Sync Heavy Punch to client
            setElementData(entity, "canExplosion", pData.explosion) -- Sync Explosion ability to client
            setElementData(entity, "targetPlayer", leader) 
            setElementData(entity, "missionReward", reward)
            
            table.insert(activeMissionPeds, entity)
            table.insert(playerPeds, entity)
        end
    end
    
    setElementData(leader, "activeMysteryPeds", playerPeds)
end)

-- Cleanup peds and pickups if the mission fails and sync failure to party
addEvent("mysteryFailed", true)
addEventHandler("mysteryFailed", root, function(leader, reason)
    local actualLeader = leader or client
    local peds = getElementData(actualLeader, "activeMysteryPeds") or {}
    for _, ent in ipairs(peds) do
        if isElement(ent) then 
            local blip = getElementData(ent, "bossBlip")
            if isElement(blip) then destroyElement(blip) end

            local driver = getElementData(ent, "driver")
            if isElement(driver) then destroyElement(driver) end
            destroyElement(ent) 
        end
    end
    
    local pickups = getElementData(actualLeader, "activeMythPickups") or {}
    for _, p in ipairs(pickups) do if isElement(p) then destroyElement(p) end end
    
    setElementData(actualLeader, "activeMythPickups", {})
    setElementData(actualLeader, "activeMysteryPeds", {})
    setElementData(actualLeader, "pedsSpawned", false)
    setElementData(actualLeader, "activeMissionData", nil) 
    setElementData(actualLeader, "partyMembers", {}) -- FIXED: Disband party on mission fail

    triggerClientEvent(actualLeader, "onMysteryFailedClient", actualLeader, reason)
    local members = getElementData(actualLeader, "partyMembers") or {}
    for _, member in ipairs(members) do
        if isElement(member) then triggerClientEvent(member, "onMysteryFailedClient", member, reason) end
    end
end)

-- Handle Custom Damage & Party Rewards
addEvent("damageBossPed", true)
addEventHandler("damageBossPed", root, function(loss)
    local hp = getElementData(source, "bossHealth")
    local isDead = getElementData(source, "bossDead") 
    
    if hp and not isDead then
        local newHp = hp - loss
        if newHp <= 0 then
            setElementData(source, "bossHealth", 0)
            setElementData(source, "bossDead", true) 
            
            local blip = getElementData(source, "bossBlip")
            if isElement(blip) then destroyElement(blip) end

            local eType = getElementData(source, "eType") or "Ped"
            
            if eType == "Car" then
                blowVehicle(source)
                local driver = getElementData(source, "driver")
                if isElement(driver) then killPed(driver) end
            else
                killPed(source)
            end
            
            local targetPlayer = getElementData(source, "targetPlayer")
            local reward = getElementData(source, "missionReward")
            if isElement(targetPlayer) then
                local peds = getElementData(targetPlayer, "activeMysteryPeds") or {}
                local alive = 0
                for _, p in ipairs(peds) do
                    if isElement(p) then
                        local pType = getElementData(p, "eType") or "Ped"
                        if pType == "Car" then
                            if not isVehicleBlown(p) then alive = alive + 1 end
                        else
                            if not isPedDead(p) then alive = alive + 1 end
                        end
                    end
                end
                
                if alive == 0 then
                    givePlayerMoney(targetPlayer, reward)
                    outputChatBox("Mystery solved! You earned $" .. reward .. ".", targetPlayer, 255, 215, 0)
                    triggerClientEvent(targetPlayer, "onMysteryComplete", targetPlayer, reward)
                    
                    local members = getElementData(targetPlayer, "partyMembers") or {}
                    for _, member in ipairs(members) do
                        if isElement(member) then
                            givePlayerMoney(member, reward)
                            outputChatBox("Mystery solved! You earned $" .. reward .. ".", member, 255, 215, 0)
                            triggerClientEvent(member, "onMysteryComplete", member, reward)
                        end
                    end
                    
                    setElementData(targetPlayer, "partyMembers", {}) -- FIXED: Disband party on mission complete
                    
                    local pickups = getElementData(targetPlayer, "activeMythPickups") or {}
                    for _, p in ipairs(pickups) do if isElement(p) then destroyElement(p) end end
                    setElementData(targetPlayer, "activeMythPickups", {})
                    
                    setElementData(targetPlayer, "activeMysteryPeds", {})
                    setElementData(targetPlayer, "pedsSpawned", false)
                    setElementData(targetPlayer, "activeMissionData", nil)
                end
            end
        else
            setElementData(source, "bossHealth", newHp)
        end
    end
end)

addEvent("warpMysteryPlayer", true)
addEventHandler("warpMysteryPlayer", root, function(int, dim, x, y, z)
    local player = client
    -- Check if we are returning to the main overworld (Interior 0, Dimension 0)
    local isExiting = (int == 0 and dim == 0) 

    if isExiting then
        -- 1. Freeze the player BEFORE warping (they freeze while still inside)
        setElementFrozen(player, true)
        
        -- 2. Delay the actual warp out by 1.5 seconds so it doesn't happen instantly
        setTimer(function(p, targetInt, targetDim, targetX, targetY, targetZ)
            if isElement(p) then
                setElementInterior(p, targetInt)
                setElementDimension(p, targetDim)
                
                if targetX and targetY and targetZ then
                    -- 3. Widen the offset to ~2.5 meters apart so you don't spawn inside each other
                    local offsetX = (math.random() - 0.5) * 5.0
                    local offsetY = (math.random() - 0.5) * 5.0
                    setElementPosition(p, targetX + offsetX, targetY + offsetY, targetZ + 0.5)
                end
                
                -- 4. Keep frozen for 1 extra second while the outside map loads, then unfreeze
                setTimer(setElementFrozen, 1000, 1, p, false)
            end
        end, 1500, 1, player, int, dim, x, y, z)
    else
        -- Going INTO an interior: No freeze, immediate warp, standard small offset
        setElementInterior(player, int)
        setElementDimension(player, dim)
        if x and y and z then
            local offsetX = (math.random() - 0.5) * 1.5
            local offsetY = (math.random() - 0.5) * 1.5
            setElementPosition(player, x + offsetX, y + offsetY, z + 0.5)
        end
    end
end)

addEvent("spawnMythPickups", true)
addEventHandler("spawnMythPickups", root, function(x, y, z)
    local leader = client
    local pickups = getElementData(leader, "activeMythPickups") or {}
    if #pickups == 0 then
        -- Health (0) and Armor (1), respawn time 75 seconds (75000ms)
        local hpPickup = createPickup(x + 5, y + 5, z, 0, 100, 75000)
        local armorPickup = createPickup(x - 5, y - 5, z, 1, 100, 75000)
        
        local int = getElementInterior(leader)
        local dim = getElementDimension(leader)
        
        setElementInterior(hpPickup, int)
        setElementDimension(hpPickup, dim)
        setElementInterior(armorPickup, int)
        setElementDimension(armorPickup, dim)
        
        table.insert(pickups, hpPickup)
        table.insert(pickups, armorPickup)
        setElementData(leader, "activeMythPickups", pickups)
    end
end)