-- mission_ai_c.lua

addEvent("onMysteryComplete", true)
addEventHandler("onMysteryComplete", root, function(reward)
    cleanupMissionElements()
    restoreWeather()
    activeMission = nil
    myMissionLeader = nil
    isMysteryActive = false
    setElementData(localPlayer, "mysteryEngaged", false) 
    
    missionPassedReward = reward or 0
    missionPassedTick = getTickCount()
    playSound("missionpassed.mp3") 
    
    -- ISOLATION FIX: Wait 2 seconds, then warp closely outside Verdant Meadows in default dimension 0
    setTimer(function()
        triggerServerEvent("warpMysteryPlayer", localPlayer, 0, 0, 428.0, 2536.0, 16.148)
    end, 2000, 1)
end)

addEvent("onMysteryFailedClient", true)
addEventHandler("onMysteryFailedClient", root, function(reason)
    cleanupMissionElements()
    restoreWeather()
    activeMission = nil
    myMissionLeader = nil
    isMysteryActive = false
    setElementData(localPlayer, "mysteryEngaged", false) 
    
    missionFailedTick = getTickCount()
    if reason == "flee" then missionFailedReasonStr = "You ran, coward! Guess we need to hire better hunters next time."
    else missionFailedReasonStr = "Mission Failed! The mystery remains unsolved." end
    outputChatBox(missionFailedReasonStr, 255, 0, 0)
    
    -- ISOLATION FIX & RESPAWN FIX: Ensure player is alive before warping to airport
    local function warpBack()
        if isPedDead(localPlayer) then
            setTimer(warpBack, 1000, 1) 
        else
            triggerServerEvent("warpMysteryPlayer", localPlayer, 0, 0, 428.0, 2536.0, 16.148)
        end
    end
    
    if reason == "death" then
        setTimer(warpBack, 1000, 1)
    else
        setTimer(warpBack, 2000, 1)
    end
end)

-- Reset engagement flag every time a new mission starts so old mission data doesn't trigger fails
addEventHandler("onClientSetupMission", root, function()
    setElementData(localPlayer, "mysteryEngaged", false)
end)

local function handleEntityDamage(sourceElement, attacker, weapon, loss)
    if getElementData(sourceElement, "isMysteryPed") then
        cancelEvent() 
        local vuln = getElementData(sourceElement, "pedVuln") or "Normal"
        local canDamage = false
        local isVulnRestricted = false
        if string.find(vuln, "Explosion") or string.find(vuln, "Fire") or string.find(vuln, "Water") or string.find(vuln, "Bullets") then
            isVulnRestricted = true
        end
        
        if not isVulnRestricted then canDamage = true else
            if string.find(vuln, "Explosion") and (weapon == 51 or weapon == 16 or (weapon >= 35 and weapon <= 36) or weapon == 39) then canDamage = true end
            if string.find(vuln, "Fire") and (weapon == 37 or weapon == 16) then canDamage = true end
            if string.find(vuln, "Water") and weapon == 53 then canDamage = true end
            if string.find(vuln, "Bullets") and ((weapon >= 22 and weapon <= 34) or weapon == 38) then canDamage = true end
        end
        
        if string.find(vuln, "Chainsaw") and weapon == 9 then canDamage = false end
        if string.find(vuln, "Minigun") and weapon == 38 then canDamage = false end
        if getElementData(sourceElement, "canExplosion") and weapon == 51 then canDamage = false end
        
        if canDamage then
            local targetPlayer = getElementData(sourceElement, "targetPlayer")
            local isPartyMember = false
            
            if targetPlayer == localPlayer then isPartyMember = true end
            if not isPartyMember and isElement(targetPlayer) then
                local members = getElementData(targetPlayer, "partyMembers") or {}
                for _, m in ipairs(members) do if m == localPlayer then isPartyMember = true; break end end
            end
            
            local validAttacker = false
            if attacker == localPlayer then validAttacker = true
            elseif attacker == nil or (isElement(attacker) and getElementType(attacker) ~= "player") then
                if targetPlayer == localPlayer then validAttacker = true end
            end
            
            if validAttacker then triggerServerEvent("damageBossPed", sourceElement, loss) end
        end
    end
end

addEventHandler("onClientPedDamage", root, function(attacker, weapon, bodypart, loss) handleEntityDamage(source, attacker, weapon, loss) end)
addEventHandler("onClientVehicleDamage", root, function(attacker, weapon, loss) handleEntityDamage(source, attacker, weapon, loss) end)

addEventHandler("onClientPlayerDamage", localPlayer, function(attacker, weapon, bodypart, loss)
    if isElement(attacker) and getElementType(attacker) == "ped" and getElementData(attacker, "isMysteryPed") then
        if getElementData(attacker, "canHeavyPunch") and weapon == 0 then
            local px, py, pz = getElementPosition(localPlayer)
            local ax, ay, az = getElementPosition(attacker)
            local angle = math.atan2(py - ay, px - ax)
            local vx = math.cos(angle) * 15.0 
            local vy = math.sin(angle) * 15.0
            
            setTimer(function()
                if isElement(localPlayer) and not isPedDead(localPlayer) then setElementVelocity(localPlayer, vx, vy, 0.3) end
            end, 50, 1)
            
            local extraDamage = 50 
            local armor = getPedArmor(localPlayer)
            if armor > extraDamage then setPedArmor(localPlayer, armor - extraDamage)
            else
                setPedArmor(localPlayer, 0)
                setElementHealth(localPlayer, math.max(0, getElementHealth(localPlayer) - (extraDamage - armor)))
            end
        end
    end
end)

addEventHandler("onClientElementDestroy", root, function()
    if getElementType(source) == "projectile" then
        local creator = getElementData(source, "firedByMysteryPed")
        if creator then
            local x, y, z = getElementPosition(source)
            local type = getProjectileType(source)
            if type == 19 or type == 20 then createExplosion(x, y, z, 0) end
        end
    end
end)

setTimer(function()
    if activeMission then
        if isMysteryActive then
            local px, py, pz = getElementPosition(localPlayer)
            local currentInt = getElementInterior(localPlayer)
            local flee = true
            
            if activeIntData then
                if activeIntData.entMark and currentInt == (activeIntData.entMark.int or 0) then
                    if getDistanceBetweenPoints3D(px, py, pz, activeIntData.entMark.x, activeIntData.entMark.y, activeIntData.entMark.z) <= 300.0 then flee = false end
                end
                if activeIntData.entTarg and currentInt == (activeIntData.entTarg.int or activeIntData.id or 0) then
                    if getDistanceBetweenPoints3D(px, py, pz, activeIntData.entTarg.x, activeIntData.entTarg.y, activeIntData.entTarg.z) <= 300.0 then flee = false end
                end
            end
            
            if getDistanceBetweenPoints3D(px, py, pz, mythX, mythY, mythZ) <= 300.0 then flee = false end
            
            local engaged = getElementData(localPlayer, "mysteryEngaged")
            if not flee then
                if not engaged then setElementData(localPlayer, "mysteryEngaged", true) end
            elseif engaged and flee then
                failMission("flee")
                isMysteryActive = false 
                return
            end
        end

        local targetLeader = myMissionLeader or localPlayer
        local entities = getElementData(targetLeader, "activeMysteryPeds") or {}
        
        for i, entity in ipairs(entities) do
            if isElement(entity) then
                local eType = getElementData(entity, "eType") or "Ped"
                local isAlive = false
                if eType == "Car" then isAlive = not isVehicleBlown(entity) else isAlive = not isPedDead(entity) end
                
                if isAlive and isElementFrozen(entity) then
                    if getElementInterior(entity) == getElementInterior(localPlayer) and getElementDimension(entity) == getElementDimension(localPlayer) then
                        setElementFrozen(entity, false)
                    end
                end

                if isAlive and not isElementFrozen(entity) then
                    local behavior = getElementData(entity, "pedBehavior") or "chase"
                    local closestPlayer, minLoc = nil, 150 
                    local px, py, pz = 0, 0, 0
                    
                    local potentialTargets = getElementsByType("player")
                    for _, ped in ipairs(getElementsByType("ped")) do
                        if getElementData(ped, "isYakuza") then table.insert(potentialTargets, ped) end
                    end
                    
                    for _, p in ipairs(potentialTargets) do
                        if not isPedDead(p) and getElementInterior(p) == getElementInterior(entity) and getElementDimension(p) == getElementDimension(entity) then
                            local tx, ty, tz = getElementPosition(p)
                            local ex, ey, ez = getElementPosition(entity)
                            local dist = getDistanceBetweenPoints3D(tx, ty, tz, ex, ey, ez)
                            if dist < minLoc then
                                minLoc = dist; closestPlayer = p; px, py, pz = tx, ty, tz
                            end
                        end
                    end
                    
                    if closestPlayer then
                        if getElementData(entity, "canTeleport") then
                            local nextTeleport = getElementData(entity, "nextTeleport")
                            if not nextTeleport then setElementData(entity, "nextTeleport", getTickCount() + math.random(8000, 10000))
                            elseif getTickCount() > nextTeleport then
                                setElementData(entity, "nextTeleport", getTickCount() + math.random(8000, 10000))
                                local _, _, pRot = getElementRotation(closestPlayer)
                                local angle = math.rad(pRot)
                                local backX = px + math.sin(angle) * 3
                                local backY = py - math.cos(angle) * 3
                                setElementPosition(entity, backX, backY, pz + 1.0)
                            end
                        end
                        
                        if getElementData(entity, "canExplosion") then
                            local nextExplosion = getElementData(entity, "nextExplosion")
                            if not nextExplosion then setElementData(entity, "nextExplosion", getTickCount() + math.random(5000, 10000))
                            elseif getTickCount() > nextExplosion then
                                setElementData(entity, "nextExplosion", getTickCount() + math.random(5000, 10000))
                                local rDist = 15 + math.random() * 15
                                local rAngle = math.rad(math.random(0, 360))
                                local offsetX = math.cos(rAngle) * rDist
                                local offsetY = math.sin(rAngle) * rDist
                                createExplosion(px + offsetX, py + offsetY, pz - 0.5, 2)
                                
                                if not getElementData(entity, "pickupsSpawned") then
                                    local ex, ey, ez = getElementPosition(entity)
                                    triggerServerEvent("spawnMythPickups", localPlayer, ex, ey, ez)
                                    setElementData(entity, "pickupsSpawned", true)
                                end
                            end
                        end

                        if eType == "Car" then
                            local driver = getElementData(entity, "driver")
                            
                            if isElement(driver) and (not myMissionLeader or myMissionLeader == localPlayer) then
                                local ex, ey, ez = getElementPosition(entity)
                                local _, _, rz = getElementRotation(entity)
                                local targetRot = math.deg(math.atan2(py - ey, px - ex)) - 90
                                if targetRot < 0 then targetRot = targetRot + 360 end
                                
                                local diff = targetRot - rz
                                while diff < -180 do diff = diff + 360 end
                                while diff > 180 do diff = diff - 360 end
                                
                                local isReversing = getElementData(entity, "isReversing") or 0
                                local cvx, cvy, cvz = getElementVelocity(entity)
                                local speed = math.sqrt(cvx^2 + cvy^2 + cvz^2)
                                
                                if isReversing > getTickCount() then
                                    setPedControlState(driver, "accelerate", false)
                                    setPedControlState(driver, "brake_reverse", true)
                                    if diff > 0 then
                                        setPedControlState(driver, "vehicle_left", false)
                                        setPedControlState(driver, "vehicle_right", true)
                                    else
                                        setPedControlState(driver, "vehicle_left", true)
                                        setPedControlState(driver, "vehicle_right", false)
                                    end
                                else
                                    setPedControlState(driver, "brake_reverse", false)
                                    setPedControlState(driver, "accelerate", true)
                                    
                                    if diff > 10 then
                                        setPedControlState(driver, "vehicle_left", true)
                                        setPedControlState(driver, "vehicle_right", false)
                                    elseif diff < -10 then
                                        setPedControlState(driver, "vehicle_left", false)
                                        setPedControlState(driver, "vehicle_right", true)
                                    else
                                        setPedControlState(driver, "vehicle_left", false)
                                        setPedControlState(driver, "vehicle_right", false)
                                    end
                                    
                                    -- TRACKING FIX: Aggressive Homing / Velocity Lock-on
                                    if math.abs(diff) < 40 and speed > 0.15 and minLoc < 50.0 then
                                        local angle = math.rad(targetRot + 90)
                                        local homing = 0.25 -- Smoothly interpolate the vector path
                                        local tvx = math.cos(angle) * speed
                                        local tvy = math.sin(angle) * speed
                                        local newVx = cvx + (tvx - cvx) * homing
                                        local newVy = cvy + (tvy - cvy) * homing
                                        setElementVelocity(entity, newVx, newVy, cvz - 0.01)
                                    end
                                    
                                    if speed < 0.05 and minLoc > 8.0 then
                                        local stuckStart = getElementData(entity, "stuckStart")
                                        if not stuckStart then setElementData(entity, "stuckStart", getTickCount())
                                        elseif getTickCount() - stuckStart > 1500 then 
                                            setElementData(entity, "isReversing", getTickCount() + 2000) 
                                            setElementData(entity, "stuckStart", nil)
                                        end
                                    else 
                                        setElementData(entity, "stuckStart", nil) 
                                    end
                                end
                            end
                        else
                            local ex, ey, ez = getElementPosition(entity)
                            local dist = minLoc
                            
                            local targetRot = math.deg(math.atan2(py - ey, px - ex)) - 90
                            if targetRot < 0 then targetRot = targetRot + 360 end
                            setElementRotation(entity, 0, 0, targetRot, "default", true)
                            
                            local weapon = getPedWeapon(entity)
                            local isMelee = (weapon <= 15)
                            local isSpray = (weapon == 41 or weapon == 42)
                            local isThrowable = (weapon >= 16 and weapon <= 18) or weapon == 39
                            local isRocket = (weapon == 35 or weapon == 36)
                            
                            local evx, evy, evz = getElementVelocity(entity)
                            local speed = math.sqrt(evx^2 + evy^2)
                            if speed < 0.02 and dist > 3.0 and behavior ~= "stand" then
                                local jumpTimer = getElementData(entity, "jumpTimer") or 0
                                if jumpTimer == 0 then
                                    setElementData(entity, "jumpTimer", getTickCount())
                                elseif getTickCount() - jumpTimer > 1000 then 
                                    setPedControlState(entity, "jump", true)
                                    setElementData(entity, "jumpTimer", getTickCount()) 
                                else
                                    setPedControlState(entity, "jump", false)
                                end
                            else
                                setElementData(entity, "jumpTimer", 0)
                                setPedControlState(entity, "jump", false)
                            end

                            if isMelee or isSpray then 
                                local attackDist = isMelee and 1.5 or 3.5
                                if dist <= attackDist then
                                    setPedControlState(entity, "forwards", false)
                                    setPedControlState(entity, "sprint", false)
                                    if getTickCount() % 1000 < 500 then setPedControlState(entity, "fire", true) else setPedControlState(entity, "fire", false) end
                                else
                                    setPedControlState(entity, "fire", false)
                                    if behavior == "stand" then setPedControlState(entity, "forwards", false); setPedControlState(entity, "sprint", false)
                                    else setPedControlState(entity, "forwards", true); setPedControlState(entity, "sprint", false) end
                                end
                            elseif isThrowable or isRocket then
                                local attackDist = isRocket and 40.0 or 15.0
                                if dist <= attackDist then
                                    setPedControlState(entity, "forwards", false)
                                    setPedControlState(entity, "sprint", false)
                                    setPedAimTarget(entity, px, py, pz)
                                    
                                    local lastThrow = getElementData(entity, "lastThrowTime") or 0
                                    if getTickCount() - lastThrow > 3000 then
                                        setPedControlState(entity, "aim_weapon", true)
                                        setPedControlState(entity, "fire", true)
                                        
                                        setTimer(function()
                                            if isElement(entity) and not isPedDead(entity) and isElement(closestPlayer) then
                                                local ePx, ePy, ePz = getElementPosition(entity)
                                                local tPx, tPy, tPz = getElementPosition(closestPlayer)
                                                local _, _, rz = getElementRotation(entity)
                                                
                                                local projID = weapon
                                                if weapon == 35 then projID = 19 end
                                                if weapon == 36 then projID = 20 end
                                                
                                                local spawnX = ePx + math.sin(math.rad(-rz)) * 1.0
                                                local spawnY = ePy + math.cos(math.rad(-rz)) * 1.0
                                                local spawnZ = ePz + 0.6
                                                
                                                tPz = isRocket and (tPz + 0.0) or (tPz - 0.8)
                                                
                                                local dirX = tPx - spawnX
                                                local dirY = tPy - spawnY
                                                local dirZ = tPz - spawnZ
                                                local distance = math.sqrt(dirX^2 + dirY^2 + dirZ^2)
                                                
                                                local nX = dirX / distance
                                                local nY = dirY / distance
                                                local nZ = dirZ / distance
                                                
                                                local speed = isRocket and 0.75 or math.max(0.15, math.min(0.55, distance / 40.0))
                                                local velX = nX * speed
                                                local velY = nY * speed
                                                local velZ = nZ * speed
                                                
                                                if isThrowable then velZ = velZ + 0.12 end
                                                local targetElement = (weapon == 36) and closestPlayer or nil
                                                local proj = createProjectile(entity, projID, spawnX, spawnY, spawnZ, 1.0, targetElement, 0, 0, 0, velX, velY, velZ)
                                                if proj then setElementData(proj, "firedByMysteryPed", true) end 
                                                
                                                if proj and isThrowable then
                                                    local lx, ly, lz = getElementPosition(proj)
                                                    setTimer(function(p) if isElement(p) then lx, ly, lz = getElementPosition(p) end end, 50, 40, proj)
                                                    setTimer(function(p)
                                                        if isElement(p) then lx, ly, lz = getElementPosition(p); destroyElement(p) end
                                                        local et = (weapon == 18 and 4) or (weapon == 39 and 12) or 0
                                                        createExplosion(lx, ly, lz, et)
                                                    end, 2200, 1, proj)
                                                end
                                                
                                                setPedControlState(entity, "fire", false)
                                                setPedControlState(entity, "aim_weapon", false)
                                            end
                                        end, 600, 1) 
                                        
                                        setElementData(entity, "lastThrowTime", getTickCount())
                                    end
                                else
                                    setPedControlState(entity, "aim_weapon", false)
                                    setPedControlState(entity, "fire", false)
                                    if behavior == "stand" then setPedControlState(entity, "forwards", false); setPedControlState(entity, "sprint", false)
                                    else setPedControlState(entity, "forwards", true); setPedControlState(entity, "sprint", false) end
                                end
                            else 
                                local acc = getElementData(entity, "pedAccuracy") or 25
                                local missFactor = math.max(0, (100 - acc) / 100)
                                local offsetX = (math.random() - 0.5) * 6 * missFactor
                                local offsetY = (math.random() - 0.5) * 6 * missFactor
                                local offsetZ = (math.random() - 0.5) * 6 * missFactor
                                
                                setPedAimTarget(entity, px + offsetX, py + offsetY, pz + offsetZ)
                                setPedControlState(entity, "aim_weapon", true)
                                setPedControlState(entity, "fire", dist > 2)
                                
                                if dist > 10 and behavior ~= "stand" then
                                    setPedControlState(entity, "forwards", true)
                                    setPedControlState(entity, "sprint", false)
                                else
                                    setPedControlState(entity, "forwards", false)
                                    setPedControlState(entity, "sprint", false)
                                end
                            end
                        end
                    else
                        if eType == "Car" then
                            local driver = getElementData(entity, "driver")
                            if isElement(driver) and (not myMissionLeader or myMissionLeader == localPlayer) then
                                setPedControlState(driver, "accelerate", false)
                                setPedControlState(driver, "brake_reverse", false)
                                setPedControlState(driver, "vehicle_left", false)
                                setPedControlState(driver, "vehicle_right", false)
                            end
                        else
                            setPedControlState(entity, "forwards", false)
                            setPedControlState(entity, "sprint", false)
                            setPedControlState(entity, "fire", false)
                            setPedControlState(entity, "aim_weapon", false)
                        end
                    end
                end
            end
        end
    end
end, 200, 0)