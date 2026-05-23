-- plane_ai.lua

-- Helper function to calculate exact offset positions for the rockets
local function getPositionFromElementOffset(element, offX, offY, offZ)
    local m = getElementMatrix(element)
    local x = offX * m[1][1] + offY * m[2][1] + offZ * m[3][1] + m[4][1]
    local y = offX * m[1][2] + offY * m[2][2] + offZ * m[3][2] + m[4][2]
    local z = offX * m[1][3] + offY * m[2][3] + offZ * m[3][3] + m[4][3]
    return x, y, z
end

-- Runs at 50ms to provide smooth control state updates without breaking GTA physics
setTimer(function()
    local targetLeader = getElementData(localPlayer, "missionPartyLeader") or localPlayer
    local entities = getElementData(targetLeader, "activeMysteryPeds") or {}

    for i, entity in ipairs(entities) do
        if isElement(entity) then
            local eType = getElementData(entity, "eType") or "Ped"
            
            if eType == "Car" and not isVehicleBlown(entity) and not isElementFrozen(entity) then
                local vType = getVehicleType(entity)
                
                if vType == "Helicopter" or vType == "Plane" then
                    local driver = getElementData(entity, "driver")
                    
                    if isElement(driver) then
                        if not isPedDead(driver) and not isPedDead(targetLeader) then
                            
                            local ex, ey, ez = getElementPosition(entity)
                            local tx, ty, tz = getElementPosition(targetLeader)
                            local dx = tx - ex
                            local dy = ty - ey
                            local dz = tz - ez
                            local dist = getDistanceBetweenPoints2D(ex, ey, tx, ty)
                            local altitudeDiff = ez - tz

                            -- Calculate target rotations
                            local targetRot = -math.deg(math.atan2(dx, dy))
                            if targetRot < 0 then targetRot = targetRot + 360 end
                            
                            -- In MTA: Negative pitch is nose UP, Positive pitch is nose DOWN
                            local targetPitch = -math.deg(math.atan2(dz, dist)) 

                            -- Get current rotations to steer organically (no shit AI, didn't help me that much here)
                            local currentPitch, currentRoll, currentYaw = getElementRotation(entity)

                            -- Yaw diff for left/right steering
                            local yawDiff = targetRot - currentYaw
                            while yawDiff < -180 do yawDiff = yawDiff + 360 end
                            while yawDiff > 180 do yawDiff = yawDiff - 360 end

                            -- Pitch diff for up/down stick movement
                            local pitchDiff = targetPitch - currentPitch
                            while pitchDiff < -180 do pitchDiff = pitchDiff + 360 end
                            while pitchDiff > 180 do pitchDiff = pitchDiff - 360 end

                            if vType == "Helicopter" then
                                setHelicopterRotorSpeed(entity, 0.2)
                            end

                            -- State Machine (Defaults to climb so they take off normally)
                            local state = getElementData(entity, "flight_state") or "climb"

                            if state == "climb" then
                                if altitudeDiff > 50 then
                                    state = "attack"
                                end
                            elseif state == "attack" then
                                -- If they dive too close to the ground, force them to pull up and circle back
                                if dist < 30 and altitudeDiff < 10 then 
                                    state = "climb"
                                elseif altitudeDiff < -5 then -- Player is higher than them
                                    state = "climb"
                                elseif dist > 350 then -- Flew way out of bounds
                                    state = "reset"
                                end
                            elseif state == "reset" then
                                -- Only teleport if severely stuck/lost, then immediately attack again
                                local randomAngle = math.rad(math.random(0, 360))
                                local resetDist = 150
                                local nx = tx + math.cos(randomAngle) * resetDist
                                local ny = ty + math.sin(randomAngle) * resetDist
                                setElementPosition(entity, nx, ny, tz + 70)
                                setElementRotation(entity, 0, 0, targetRot)
                                setElementVelocity(entity, 0, 0, 0)
                                state = "attack"
                            end

                            setElementData(entity, "flight_state", state)

                            -- BASE CONTROLS (Always accelerating to keep flying)
                            setPedControlState(driver, "accelerate", true)
                            setPedControlState(driver, "brake_reverse", false)

                            -- ORGANIC STEERING (YAW)
                            if yawDiff > 5 then
                                setPedControlState(driver, "vehicle_left", true)
                                setPedControlState(driver, "vehicle_right", false)
                            elseif yawDiff < -5 then
                                setPedControlState(driver, "vehicle_left", false)
                                setPedControlState(driver, "vehicle_right", true)
                            else
                                setPedControlState(driver, "vehicle_left", false)
                                setPedControlState(driver, "vehicle_right", false)
                            end

                            -- STATE BASED PITCH & FIRING
                            if state == "climb" then
                                -- Pull stick back to climb into the air
                                setPedControlState(driver, "vehicle_down", true) 
                                setPedControlState(driver, "vehicle_up", false)
                                setPedControlState(driver, "vehicle_fire", false)
                                setPedControlState(driver, "vehicle_secondary_fire", false)

                            elseif state == "attack" then
                                -- Steer pitch towards player
                                if pitchDiff > 5 then
                                    setPedControlState(driver, "vehicle_up", true)   -- Push stick forward (nose down)
                                    setPedControlState(driver, "vehicle_down", false)
                                elseif pitchDiff < -5 then
                                    setPedControlState(driver, "vehicle_up", false)
                                    setPedControlState(driver, "vehicle_down", true) -- Pull stick back (nose up)
                                else
                                    setPedControlState(driver, "vehicle_up", false)
                                    setPedControlState(driver, "vehicle_down", false)
                                end

                                -- Firing logic: Only shoot if roughly facing the player!
                                local fireTick = getTickCount() % 3000
                                local isFacingPlayer = math.abs(yawDiff) < 25
                                local shouldFire = (fireTick < 800) and (dist < 200) and isFacingPlayer
                                
                                setPedControlState(driver, "vehicle_fire", shouldFire) 
                                setPedControlState(driver, "vehicle_secondary_fire", shouldFire)

                                -- Manual Hunter Rocket Spawn (Since AI misses secondary inputs sometimes)
                                if shouldFire and getElementModel(entity) == 425 then
                                    local lastRocket = getElementData(entity, "bot_lastRocket") or 0
                                    if getTickCount() - lastRocket > 400 then
                                        setElementData(entity, "bot_lastRocket", getTickCount())
                                        local px, py, pz = getPositionFromElementOffset(entity, 0, 4, -1)
                                        createProjectile(entity, 19, px, py, pz, 1.0, targetLeader)
                                    end
                                end

                            elseif state == "reset" then
                                setPedControlState(driver, "vehicle_fire", false)
                                setPedControlState(driver, "vehicle_secondary_fire", false)
                            end
                            
                        else
                            -- Clear all controls if target is dead/lost
                            setPedControlState(driver, "accelerate", false)
                            setPedControlState(driver, "vehicle_left", false)
                            setPedControlState(driver, "vehicle_right", false)
                            setPedControlState(driver, "vehicle_down", false)
                            setPedControlState(driver, "vehicle_up", false)
                            setPedControlState(driver, "vehicle_fire", false)
                            setPedControlState(driver, "vehicle_secondary_fire", false)
                        end
                    end
                end
            end
        end
    end
end, 50, 0)
