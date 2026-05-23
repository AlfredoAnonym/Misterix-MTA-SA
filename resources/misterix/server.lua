-- server.lua
local db = dbConnect("sqlite", "mysteries.db")

dbExec(db, "CREATE TABLE IF NOT EXISTS missions (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, desc TEXT, reward INTEGER, weather INTEGER DEFAULT 0, time TEXT DEFAULT '-1', music TEXT DEFAULT 'None', peds TEXT, int_data TEXT)")

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
    dbExec(db, "UPDATE missions SET name=?, desc=?, reward=?, weather=?, time=?, music=?, peds=?, int_data=? WHERE id=?", name, desc, reward, weather, timeStr, music, pedsJSON, intJSON, id)
    outputChatBox("Mystery updated successfully!", client, 0, 255, 0)
    local query = dbQuery(db, "SELECT * FROM missions")
    local result = dbPoll(query, -1)
    if result then triggerClientEvent(root, "onClientReceiveMissions", root, result) end
end)

addEvent("deleteMystery", true)
addEventHandler("deleteMystery", root, function(id)
    dbExec(db, "DELETE FROM missions WHERE id=?", id)
    outputChatBox("Mystery successfully deleted.", client, 0, 255, 0)
    for _, p in ipairs(getElementsByType("player")) do sendMissionsToClient(p) end
end)

-- PARTY SYSTEM
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
        local alreadyIn = false
        for _, m in ipairs(members) do if m == client then alreadyIn = true; break end end
        if not alreadyIn then
            table.insert(members, client)
            setElementData(leader, "partyMembers", members)
        end
        
        outputChatBox(getPlayerName(client) .. " has joined your mystery party!", leader, 0, 255, 0)
        outputChatBox("You joined " .. getPlayerName(leader) .. "'s mystery party! Warping to Verdant Meadows...", client, 0, 255, 0)
        
        -- ISOLATION: Set the player to the leader's generated dimension
        local missionDim = getElementData(leader, "missionDimension") or 0
        setElementPosition(client, 428.0, 2536.0, 16.0)
        setElementInterior(client, 0)
        setElementDimension(client, missionDim)

        local activeMission = getElementData(leader, "activeMissionData")
        if activeMission then
            triggerClientEvent(client, "onClientSetupMission", client, activeMission, leader)
            if getElementData(leader, "pedsSpawned") then
                triggerClientEvent(client, "onClientHideColShape", client, activeMission.weather or 0, activeMission.int_data)
            end
        end
    end
end)

addEvent("startSharedMission", true)
addEventHandler("startSharedMission", root, function(missionData)
    local leader = client
    local missionDim = math.random(1000, 9999) -- ISOLATION: Generate random dim for the party
    
    setElementData(leader, "missionDimension", missionDim)
    setElementDimension(leader, missionDim)
    setElementData(leader, "pedsSpawned", false) 
    setElementData(leader, "activeMissionData", missionData) 
    
    triggerClientEvent(leader, "onClientSetupMission", leader, missionData, leader)
    
    local members = getElementData(leader, "partyMembers") or {}
    for _, member in ipairs(members) do
        if isElement(member) then
            setElementDimension(member, missionDim)
            triggerClientEvent(member, "onClientSetupMission", member, missionData, leader)
        end
    end
end)

addEvent("spawnMissionPedsShared", true)
addEventHandler("spawnMissionPedsShared", root, function(pedsData, reward, leader, weatherID, intDataJSON)
    if getElementData(leader, "pedsSpawned") then return end 
    setElementData(leader, "pedsSpawned", true)
    
    local missionDim = getElementData(leader, "missionDimension") or 0
    triggerClientEvent(leader, "onClientHideColShape", leader, weatherID, intDataJSON)
    
    local members = getElementData(leader, "partyMembers") or {}
    for _, member in ipairs(members) do
        if isElement(member) then triggerClientEvent(member, "onClientHideColShape", member, weatherID, intDataJSON) end
    end

    local playerPeds = {}
    
    for _, pData in ipairs(pedsData) do
        local entity
        local isCar = (pData.eType == "Car")
        
        if isCar then
            entity = createVehicle(pData.model, pData.x, pData.y, pData.z + 1.0)
            if not entity then entity = createVehicle(400, pData.x, pData.y, pData.z + 1.0) end
            if entity then
                local driver = createPed(0, pData.x, pData.y, pData.z)
                setElementAlpha(driver, 0)
                warpPedIntoVehicle(driver, entity)
                setElementData(entity, "driver", driver)
            end
        else
            entity = createPed(pData.model, pData.x, pData.y, pData.z + 1.5)
            if not entity then entity = createPed(0, pData.x, pData.y, pData.z + 1.5) end
            if entity then
                setPedArmor(entity, 100)
                setPedWalkingStyle(entity, tonumber(pData.walkstyle) or 0)
                local safeWep = tonumber(pData.wep) or 0
                if safeWep > 46 then safeWep = 0 end
                giveWeapon(entity, safeWep, 9999, true)
                for stat = 69, 79 do setPedStat(entity, stat, 999) end
            end
        end
        
        if entity then
            local blip = createBlipAttachedTo(entity, 0, 2, 255, 0, 0, 255)
            setElementData(entity, "bossBlip", blip)
            setElementDimension(blip, missionDim) -- Force blip into the party's dimension
            
            for _, p in ipairs(getElementsByType("player")) do setElementVisibleTo(blip, p, false) end
            setElementVisibleTo(blip, leader, true)
            for _, member in ipairs(members) do if isElement(member) then setElementVisibleTo(blip, member, true) end end

            setElementFrozen(entity, true) 
            setElementSyncer(entity, leader) 
            setElementAlpha(entity, pData.alpha or 255) 
            setElementInterior(entity, pData.interior or 0)
            setElementDimension(entity, missionDim) -- Spawn in the isolated dimension
            
            setElementData(entity, "isMysteryPed", true)
            setElementData(entity, "eType", pData.eType or "Ped")
            setElementData(entity, "bossHealth", pData.hp)
            setElementData(entity, "maxBossHealth", pData.hp)
            setElementData(entity, "pedAccuracy", pData.acc) 
            setElementData(entity, "pedBehavior", pData.behavior or "chase")
            setElementData(entity, "pedVuln", pData.vuln or "Normal")
            setElementData(entity, "canTeleport", pData.teleport)
            setElementData(entity, "canHeavyPunch", pData.heavypunch)
            setElementData(entity, "canExplosion", pData.explosion)
            setElementData(entity, "targetPlayer", leader) 
            setElementData(entity, "missionReward", reward)
            
            table.insert(activeMissionPeds, entity)
            table.insert(playerPeds, entity)
        end
    end
    setElementData(leader, "activeMysteryPeds", playerPeds)
end)

addEvent("spawnMythPickups", true)
addEventHandler("spawnMythPickups", root, function(x, y, z)
    local leader = client
    local pickups = getElementData(leader, "activeMythPickups") or {}
    if #pickups == 0 then
        local hpPickup = createPickup(x + 5, y + 5, z, 0, 100, 75000)
        local armorPickup = createPickup(x - 5, y - 5, z, 1, 100, 75000)
        
        setElementInterior(hpPickup, getElementInterior(leader))
        setElementDimension(hpPickup, getElementDimension(leader))
        setElementInterior(armorPickup, getElementInterior(leader))
        setElementDimension(armorPickup, getElementDimension(leader))
        
        table.insert(pickups, hpPickup)
        table.insert(pickups, armorPickup)
        setElementData(leader, "activeMythPickups", pickups)
    end
end)

-- Restart safety: Reset players back to normal dimension and clean up tracking data
addEventHandler("onResourceStart", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do
        removeElementData(p, "activeMissionData")
        removeElementData(p, "missionPartyLeader")
        if getElementDimension(p) > 0 then
            setElementDimension(p, 0)
            setElementInterior(p, 0)
        end
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do
        removeElementData(p, "activeMissionData")
        removeElementData(p, "missionPartyLeader")
        if getElementDimension(p) > 0 then
            setElementDimension(p, 0)
            setElementInterior(p, 0)
        end
    end
end)

-- Logout safety: Automatically fail mission for remaining party members if leader quits
addEventHandler("onPlayerQuit", root, function()
    local members = getElementData(source, "partyMembers") or {}
    for _, m in ipairs(members) do
        if isElement(m) then
            triggerClientEvent(m, "onMysteryFailedClient", m, "quit")
            setElementData(m, "missionPartyLeader", nil)
        end
    end
end)