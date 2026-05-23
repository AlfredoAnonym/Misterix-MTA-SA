-- yakuza_client.lua

function getVehicleFreeSeat(vehicle)
    local maxPassengers = getVehicleMaxPassengers(vehicle)
    if not maxPassengers then return false end
    for i = 1, maxPassengers do
        if not getVehicleOccupant(vehicle, i) then
            return i
        end
    end
    return false
end

-- Assign an aggro target if the player gets attacked
addEventHandler("onClientPlayerDamage", localPlayer, function(attacker, weapon, bodypart, loss)
    if attacker and isElement(attacker) and (getElementType(attacker) == "ped" or getElementType(attacker) == "vehicle") then
        if not getElementData(attacker, "isYakuza") then
            setElementData(localPlayer, "yakuzaAggroTarget", attacker)
        end
    end
end)

setTimer(function()
    local peds = getElementsByType("ped")
    for _, ped in ipairs(peds) do
        if getElementData(ped, "isYakuza") and not isPedDead(ped) then
            local owner = getElementData(ped, "yakuzaOwner")
            
            -- FIX 2: We removed the "if owner == localPlayer" restriction around the AI.
            -- Now, ALL clients calculate their movements locally so your friend perfectly sees them moving and shooting!
            if owner and isElement(owner) then
                local pVeh = getPedOccupiedVehicle(owner)
                local yVeh = getPedOccupiedVehicle(ped)

                -- Keep enter/exit logic strict to the owner so it doesn't glitch
                if owner == localPlayer then
                    if pVeh and not yVeh then
                        local entering = getElementData(ped, "yakuzaEntering") or 0
                        if getTickCount() - entering > 2000 then
                            local targetSeat = getVehicleFreeSeat(pVeh)
                            if targetSeat then
                                -- Enter player's car as passenger
                                setPedEnterVehicle(ped, pVeh, true)
                                setElementData(ped, "yakuzaEntering", getTickCount())
                            else
                                -- Player's car is full, find the nearest empty car
                                local px, py, pz = getElementPosition(ped)
                                local nearestVeh, minDist = nil, 20
                                for _, veh in ipairs(getElementsByType("vehicle")) do
                                    if veh ~= pVeh and not getVehicleOccupant(veh, 0) then
                                        local vx, vy, vz = getElementPosition(veh)
                                        local dist = getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz)
                                        if dist < minDist then
                                            minDist = dist
                                            nearestVeh = veh
                                        end
                                    end
                                end
                                
                                if nearestVeh then
                                    -- Enter the nearest empty car as driver (false)
                                    setPedEnterVehicle(ped, nearestVeh, false)
                                    setElementData(ped, "yakuzaEntering", getTickCount())
                                end
                            end
                        end
                    elseif not pVeh and yVeh then
                        local exiting = getElementData(ped, "yakuzaExiting") or 0
                        if getTickCount() - exiting > 2000 then
                            setPedExitVehicle(ped)
                            setElementData(ped, "yakuzaExiting", getTickCount())
                        end
                    end
                end

                -- Toggle Driveby status only if they are sitting in the vehicle
                if yVeh then
                    if not getElementData(ped, "yakuzaDriveby") then
                        setPedDoingGangDriveby(ped, true)
                        setElementData(ped, "yakuzaDriveby", true)
                    end
                else
                    if getElementData(ped, "yakuzaDriveby") then
                        setPedDoingGangDriveby(ped, false)
                        setElementData(ped, "yakuzaDriveby", false)
                    end
                end

                local px, py, pz = getElementPosition(ped)
                
                -- Check for an active defensive aggro target first FROM THE OWNER
                local target = getElementData(owner, "yakuzaAggroTarget")
                if target then
                    if not isElement(target) then
                        target = nil
                        if owner == localPlayer then setElementData(localPlayer, "yakuzaAggroTarget", nil) end
                    elseif getElementType(target) == "ped" and isPedDead(target) then
                        target = nil
                        if owner == localPlayer then setElementData(localPlayer, "yakuzaAggroTarget", nil) end
                    elseif getElementType(target) == "vehicle" and isVehicleBlown(target) then
                        target = nil
                        if owner == localPlayer then setElementData(localPlayer, "yakuzaAggroTarget", nil) end
                    end
                end

                -- Fallback to the closest mystery ped if you haven't been attacked recently
                if not target then
                    local minDist = 40
                    local allPeds = getElementsByType("ped")
                    for _, enemy in ipairs(allPeds) do
                        if getElementData(enemy, "isMysteryPed") and not isPedDead(enemy) then
                            local ex, ey, ez = getElementPosition(enemy)
                            local dist = getDistanceBetweenPoints3D(px, py, pz, ex, ey, ez)
                            if dist < minDist then
                                minDist = dist
                                target = enemy
                            end
                        end
                    end

                    local allVehs = getElementsByType("vehicle")
                    for _, enemyVeh in ipairs(allVehs) do
                        if getElementData(enemyVeh, "isMysteryPed") and not isVehicleBlown(enemyVeh) then
                            local ex, ey, ez = getElementPosition(enemyVeh)
                            local dist = getDistanceBetweenPoints3D(px, py, pz, ex, ey, ez)
                            if dist < minDist then
                                minDist = dist
                                target = enemyVeh
                            end
                        end
                    end
                end

                -- Protect the enter/exit tasks so they don't break logic while walking to doors
                local isEnteringCar = (getTickCount() - (getElementData(ped, "yakuzaEntering") or 0) < 5000) and not yVeh
                local isExitingCar = (getTickCount() - (getElementData(ped, "yakuzaExiting") or 0) < 5000) and yVeh

                -- NEW: Teleport to owner if distance is high, player is on foot, and guard is on foot
                if owner == localPlayer and not yVeh then
                    local ox, oy, oz = getElementPosition(owner)
                    local distToOwner = getDistanceBetweenPoints3D(px, py, pz, ox, oy, oz)
                    local ownerVeh = getPedOccupiedVehicle(owner)

                    -- 60 units is a solid threshold for teleportation
                    if distToOwner > 60 and not ownerVeh then
                        setElementPosition(ped, ox + math.random(-2, 2), oy + math.random(-2, 2), oz + 1)
                        setElementInterior(ped, getElementInterior(owner))
                        setElementDimension(ped, getElementDimension(owner))
                        px, py, pz = getElementPosition(ped) -- Update ped coords post-teleport for aim logic
                    end
                end

                -- Attack or Follow logic
                if target and not isEnteringCar and not isExitingCar then
                    local tx, ty, tz = getElementPosition(target)
                    local distToTarget = getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz)
                    
                    local acc = 20 -- Yakuza Guards 20% Accuracy 
                    local missFactor = math.max(0, (100 - acc) / 100)
                    local offsetX = (math.random() - 0.5) * 5 * missFactor
                    local offsetY = (math.random() - 0.5) * 5 * missFactor
                    local offsetZ = (math.random() - 0.5) * 5 * missFactor
                    
                    if yVeh then
                        setPedControlState(ped, "vehicle_fire", true)
                        setPedAimTarget(ped, tx + offsetX, ty + offsetY, tz + offsetZ)
                    else
                        local rot = math.deg(math.atan2(ty - py, tx - px)) - 90
                        setElementRotation(ped, 0, 0, rot, "default", true)
                        setPedAimTarget(ped, tx + offsetX, ty + offsetY, tz + offsetZ)
                        setPedControlState(ped, "aim_weapon", true)
                        setPedControlState(ped, "fire", true)
                        
                        -- NEW: Move forward while shooting if they are further than 10 units (Misterix AI style)
                        if distToTarget > 10 then
                            setPedControlState(ped, "forwards", true)
                        else
                            setPedControlState(ped, "forwards", false)
                        end
                        
                        setPedControlState(ped, "sprint", false)
                    end
                else
                    -- Follow logic if no active target
                    if yVeh then
                        setPedControlState(ped, "vehicle_fire", false)
                        
                        -- FIX 1: If they are exiting the car, kill the gas inputs instantly so they don't hit walls
                        if isExitingCar then
                            setPedControlState(ped, "accelerate", false)
                            setPedControlState(ped, "brake_reverse", true)
                            setPedControlState(ped, "vehicle_left", false)
                            setPedControlState(ped, "vehicle_right", false)
                        elseif getVehicleOccupant(yVeh, 0) == ped then
                            -- Basic driving AI if the Yakuza is the driver of their own car
                            local ox, oy, oz = getElementPosition(owner)
                            
                            -- HUNTBOT CONCEPT: Read owner's velocity to adjust the target position.
                            -- We subtract it so the AI targets a point BEHIND your bike, preventing passing.
                            local pVeh = getPedOccupiedVehicle(owner)
                            if pVeh then
                                local pvx, pvy, pvz = getElementVelocity(pVeh)
                                ox = ox - (15 * pvx)
                                oy = oy - (15 * pvy)
                            end

                            local vx, vy, vz = getElementPosition(yVeh)
                            local dist = getDistanceBetweenPoints3D(vx, vy, vz, ox, oy, oz)
                            
                            -- FIX 2: Catch-up fallback. If they get stuck behind a distant wall out of sight, warp them nearby
                            if dist > 100 then
                                setElementPosition(yVeh, ox + 4, oy + 4, oz + 1)
                            elseif dist > 10 then
                                setPedControlState(ped, "brake_reverse", false)
                                local rot = math.deg(math.atan2(oy - vy, ox - vx)) - 90
                                local _, _, rz = getElementRotation(yVeh)
                                -- Calculate shortest turn angle
                                local diff = math.deg(math.atan2(math.sin(math.rad(rot - rz)), math.cos(math.rad(rot - rz))))
                                
                                setPedControlState(ped, "accelerate", true)
                                -- Corrected left/right steering so they turn towards you
                                if diff > 15 then
                                    setPedControlState(ped, "vehicle_right", false)
                                    setPedControlState(ped, "vehicle_left", true)
                                elseif diff < -15 then
                                    setPedControlState(ped, "vehicle_left", false)
                                    setPedControlState(ped, "vehicle_right", true)
                                else
                                    setPedControlState(ped, "vehicle_left", false)
                                    setPedControlState(ped, "vehicle_right", false)
                                end
                            else
                                -- Stop when close enough to the player
                                setPedControlState(ped, "accelerate", false)
                                setPedControlState(ped, "vehicle_left", false)
                                setPedControlState(ped, "vehicle_right", false)
                                
                                -- Brake if still rolling so they don't coast into walls/you
                                local cvx, cvy, cvz = getElementVelocity(yVeh)
                                if (cvx*cvx + cvy*cvy + cvz*cvz) > 0.001 then
                                    setPedControlState(ped, "brake_reverse", true)
                                else
                                    setPedControlState(ped, "brake_reverse", false)
                                end
                            end
                        end
                    else
                        -- On-foot follow logic when not in a vehicle
                        setPedControlState(ped, "aim_weapon", false)
                        setPedControlState(ped, "fire", false)
                        
                        if not isEnteringCar then
                            local ox, oy, oz = getElementPosition(owner)
                            local dist = getDistanceBetweenPoints3D(px, py, pz, ox, oy, oz)
                            if dist > 3 then
                                local rot = math.deg(math.atan2(oy - py, ox - px)) - 90
                                setElementRotation(ped, 0, 0, rot, "default", true)
                                setPedControlState(ped, "forwards", true)
                                if dist > 12 then
                                    setPedControlState(ped, "sprint", true)
                                else
                                    setPedControlState(ped, "sprint", false)
                                end
                            else
                                setPedControlState(ped, "forwards", false)
                                setPedControlState(ped, "sprint", false)
                            end
                        else
                            setPedControlState(ped, "forwards", false)
                            setPedControlState(ped, "sprint", false)
                        end
                    end
                end
            end
        end
    end
end, 50, 0)

-- Small health bars for Yakuza
addEventHandler("onClientRender", root, function()
    local px, py, pz = getElementPosition(localPlayer)
    local pDim = getElementDimension(localPlayer)
    local pInt = getElementInterior(localPlayer)
    
    local peds = getElementsByType("ped")
    for _, ped in ipairs(peds) do
        if getElementData(ped, "isYakuza") and not isPedDead(ped) then
            if getElementDimension(ped) == pDim and getElementInterior(ped) == pInt then
                local ex, ey, ez = getElementPosition(ped)
                local dist = getDistanceBetweenPoints3D(px, py, pz, ex, ey, ez)
                
                if dist < 40.0 then 
                    local sx, sy = getScreenFromWorldPosition(ex, ey, ez + 1.1)
                    if sx and sy then
                        local hp = getElementHealth(ped)
                        local maxHp = 200 
                        
                        local width = 60
                        local height = 6
                        local drawX = sx - width / 2
                        local drawY = sy
                        
                        -- Background bar
                        dxDrawRectangle(drawX, drawY, width, height, tocolor(0, 0, 0, 180))
                        
                        -- Green health fill
                        local healthWidth = (width - 2) * (hp / maxHp)
                        if healthWidth < 0 then healthWidth = 0 end
                        if healthWidth > width - 2 then healthWidth = width - 2 end
                        dxDrawRectangle(drawX + 1, drawY + 1, healthWidth, height - 2, tocolor(0, 200, 0, 255)) 
                        
                        -- Label
                        dxDrawText("Yakuza Guard", drawX, drawY - 18, drawX + width, drawY, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "bottom")
                    end
                end
            end
        end
    end
end)