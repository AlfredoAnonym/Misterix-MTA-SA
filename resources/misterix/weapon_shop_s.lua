-- weapon_shop_s.lua

-- Create the physical markers from your map coordinates
local enterMarker = createMarker(22.7, 2471.9, 15.5, "cylinder", 2.0, 0, 254, 239, 255) 
local exitMarker = createMarker(285.5, -41.4, 1000.5, "cylinder", 1.5, 0, 254, 239, 255)
setElementInterior(exitMarker, 1)

-- Create the vendor ped
local vendorPed = createPed(30, 295.6, -40.3, 1001.5)
setElementInterior(vendorPed, 1)
setElementFrozen(vendorPed, true)
-- Timer to ensure the ped is fully streamed in before applying the animation
setTimer(setPedAnimation, 1000, 1, vendorPed, "GANGS", "leanIDLE", -1, true, false, false)

-- Warp into the shop
-- Removed 'matchingDimension' check so it triggers even if the server marker is in dim 0 and player is in a mission
addEventHandler("onMarkerHit", enterMarker, function(hitElement)
    if getElementType(hitElement) == "player" and not isPedInVehicle(hitElement) then
        local pDim = getElementDimension(hitElement)
        setElementInterior(hitElement, 1)
        setElementDimension(hitElement, pDim) -- Preserve the mission dimension!
        
        -- Warping slightly in front of the exit marker
        setElementPosition(hitElement, 285.5, -39.0, 1001.5) 
        
        -- Fix: "Double-Tap" Step 1 - Apply rotation instantly to prevent flicker
        setElementRotation(hitElement, 0, 0, 270)
        
        -- Fix: "Double-Tap" Step 2 - Re-apply rotation with the camera snap to beat the engine's stream wipe
        setTimer(function(p)
            if isElement(p) then
                setElementRotation(p, 0, 0, 270)
                setCameraTarget(p, p)
            end
        end, 50, 1, hitElement)
    end
end)

-- Warp out of the shop
addEventHandler("onMarkerHit", exitMarker, function(hitElement)
    if getElementType(hitElement) == "player" and not isPedInVehicle(hitElement) then
        local pDim = getElementDimension(hitElement)
        setElementInterior(hitElement, 0)
        setElementDimension(hitElement, pDim) -- Preserve the mission dimension!
        
        -- Warping outside
        setElementPosition(hitElement, 22.7, 2475.0, 16.5)
        
        -- Fix: "Double-Tap" Step 1 - Apply rotation instantly to prevent flicker
        setElementRotation(hitElement, 0, 0, 0)
        
        -- Fix: "Double-Tap" Step 2 - Re-apply rotation with the camera snap to beat the engine's stream wipe
        setTimer(function(p)
            if isElement(p) then
                setElementRotation(p, 0, 0, 0)
                setCameraTarget(p, p)
            end
        end, 200, 1, hitElement)
    end
end)

-- Securely handle weapon purchases
addEvent("onPlayerBuyWeapon", true)
addEventHandler("onPlayerBuyWeapon", root, function(weaponID, price, ammo)
    local playerMoney = getPlayerMoney(client)
    
    if playerMoney >= price then
        takePlayerMoney(client, price)
        
        -- Logic split: Check if the ID string passed is "armor". If so, apply armor. If numerical, apply weapon.
        if weaponID == "armor" then
            setPedArmor(client, 100)
            outputChatBox("Armor purchased successfully!", client, 0, 255, 0)
        else
            giveWeapon(client, weaponID, ammo, true)
            outputChatBox("Weapon purchased successfully!", client, 0, 255, 0)
        end
        
        -- Trigger the client to play the 3D vendor voice line
        triggerClientEvent(client, "onVendorSpeak", client, vendorPed)
    else
        outputChatBox("You don't have enough money for this item.", client, 255, 0, 0)
    end
end)