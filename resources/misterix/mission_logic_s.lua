-- mission_logic_s.lua

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

    triggerClientEvent(actualLeader, "onMysteryFailedClient", actualLeader, reason)
    local members = getElementData(actualLeader, "partyMembers") or {}
    for _, member in ipairs(members) do
        if isElement(member) then triggerClientEvent(member, "onMysteryFailedClient", member, reason) end
    end
    setElementData(actualLeader, "partyMembers", {}) 
end)

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
            else killPed(source) end
            
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
                    setElementData(targetPlayer, "partyMembers", {}) 
                    
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
    local isExiting = (int == 0 and dim == 0) 

    if isExiting then
        setElementFrozen(player, true)
        setTimer(function(p, targetInt, targetDim, targetX, targetY, targetZ)
            if isElement(p) then
                setElementInterior(p, targetInt)
                setElementDimension(p, targetDim)
                if targetX and targetY and targetZ then
                    local offsetX = (math.random() - 0.5) * 1.5
                    local offsetY = (math.random() - 0.5) * 1.5
                    setElementPosition(p, targetX + offsetX, targetY + offsetY, targetZ + 0.5)
                end
                setTimer(setElementFrozen, 500, 1, p, false)
            end
        end, 500, 1, player, int, dim, x, y, z)
    else
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
                -- DRIVER FIX: Force the driver into the mission dimension to prevent car teleportation bugs
                setElementInterior(driver, pData.interior or 0)
                setElementDimension(driver, missionDim) 
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
            setElementDimension(blip, missionDim)
            
            for _, p in ipairs(getElementsByType("player")) do setElementVisibleTo(blip, p, false) end
            setElementVisibleTo(blip, leader, true)
            for _, member in ipairs(members) do if isElement(member) then setElementVisibleTo(blip, member, true) end end

            setElementFrozen(entity, true) 
            setElementSyncer(entity, leader) 
            setElementAlpha(entity, pData.alpha or 255) 
            setElementInterior(entity, pData.interior or 0)
            setElementDimension(entity, missionDim) 
            
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
        outputChatBox("You joined " .. getPlayerName(leader) .. "'s mystery party! Warping to leader...", client, 0, 255, 0)
        
        -- WARP FIX: Send them exactly to where the leader is located in the world, not Verdant Meadows
        local lx, ly, lz = getElementPosition(leader)
        local lint = getElementInterior(leader)
        local ldim = getElementDimension(leader)
        setElementPosition(client, lx + (math.random()-0.5)*4, ly + (math.random()-0.5)*4, lz + 1.0)
        setElementInterior(client, lint)
        setElementDimension(client, ldim)

        local activeMission = getElementData(leader, "activeMissionData")
        if activeMission then
            triggerClientEvent(client, "onClientSetupMission", client, activeMission, leader)
            if getElementData(leader, "pedsSpawned") then
                triggerClientEvent(client, "onClientHideColShape", client, activeMission.weather or 0, activeMission.int_data)
            end
        end
    end
end)