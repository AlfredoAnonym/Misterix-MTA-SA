-- weapon_shop_c.lua

-- Create the Gun Shop Blip (ID 6)
local shopBlip = createBlip(22.7, 2471.9, 15.5, 6)

-- The Buy Weapon Marker (Z-coordinate adjusted to 1000.5)
local shopMarker = createMarker(295.5, -38.3, 1000.5, "cylinder", 1.0, 0, 0, 255, 150)
setElementInterior(shopMarker, 1)

-----------------------------------
-- DIMENSION SYNC
-----------------------------------
-- This ensures all elements from this resource (map objects, vehicles, markers, peds)
-- physically appear in the dimension the player is currently in (e.g., during an isolated mission).
setTimer(function()
    local pDim = getElementDimension(localPlayer)
    
    if isElement(shopBlip) and getElementDimension(shopBlip) ~= pDim then
        setElementDimension(shopBlip, pDim)
    end
    
    if isElement(shopMarker) and getElementDimension(shopMarker) ~= pDim then
        setElementDimension(shopMarker, pDim)
    end

-- Sync map peds (including the shop vendor) to your mission dimension
    local peds = getElementsByType("ped", resourceRoot)
    for _, pd in ipairs(peds) do
        if getElementDimension(pd) ~= pDim then
            setElementDimension(pd, pDim)
        end
    end
    
    local elementTypes = {"object", "vehicle", "pickup", "marker", "ped"}
    for _, eType in ipairs(elementTypes) do
        local elements = getElementsByType(eType, resourceRoot)
        for _, el in ipairs(elements) do
            if getElementDimension(el) ~= pDim then
                setElementDimension(el, pDim)
            end
        end
    end
end, 1000, 0)

-----------------------------------
-- GUI SETUP
-----------------------------------
local screenW, screenH = guiGetScreenSize()
local shopWnd = guiCreateWindow((screenW - 400) / 2, (screenH - 500) / 2, 400, 500, "Weapon Shop", false)
guiWindowSetSizable(shopWnd, false)
guiSetVisible(shopWnd, false)

local gridWeapons = guiCreateGridList(0.05, 0.08, 0.9, 0.75, true, shopWnd)
guiGridListAddColumn(gridWeapons, "Item", 0.45)
guiGridListAddColumn(gridWeapons, "Ammo/Amount", 0.25)
guiGridListAddColumn(gridWeapons, "Price", 0.20)

local btnBuy = guiCreateButton(0.05, 0.85, 0.4, 0.1, "Buy", true, shopWnd)
local btnClose = guiCreateButton(0.55, 0.85, 0.4, 0.1, "Close", true, shopWnd)

-- Weapon & Item Data
local weapons = {
    {name = "Armor", id = "armor", price = 120, ammo = 100},
    {name = "Golf Club", id = 2, price = 20, ammo = 1},
    {name = "Nightstick", id = 3, price = 30, ammo = 1},
    {name = "Knife", id = 4, price = 35, ammo = 1},
    {name = "Bat", id = 5, price = 50, ammo = 1},
    {name = "Katana", id = 8, price = 120, ammo = 1},
    {name = "Chainsaw", id = 9, price = 4000, ammo = 1},
    {name = "Colt 45", id = 22, price = 200, ammo = 200},
    {name = "Silenced", id = 23, price = 230, ammo = 200},
    {name = "Deagle", id = 24, price = 312, ammo = 100},
    {name = "Shotgun", id = 25, price = 470, ammo = 50},
    {name = "Sawed-Off", id = 26, price = 475, ammo = 55},
    {name = "Combat Shotgun", id = 27, price = 7500, ammo = 200},
    {name = "Uzi", id = 28, price = 350, ammo = 100},
    {name = "MP5", id = 29, price = 400, ammo = 100},
    {name = "Tec-9", id = 32, price = 350, ammo = 100},
    {name = "AK-47", id = 30, price = 6000, ammo = 300},
    {name = "M4", id = 31, price = 8200, ammo = 300},
    {name = "Rifle", id = 33, price = 700, ammo = 70},
    {name = "Sniper", id = 34, price = 800, ammo = 80},
    {name = "Rocket Launcher", id = 35, price = 16000, ammo = 15},
    {name = "HS Rocket Launcher", id = 36, price = 18000, ammo = 10},
    {name = "Flamethrower", id = 37, price = 20000, ammo = 100},
    {name = "Minigun", id = 38, price = 650000, ammo = 200},
    {name = "Grenade", id = 16, price = 140, ammo = 5},
    {name = "Teargas", id = 17, price = 120, ammo = 5},
    {name = "Molotov", id = 18, price = 210, ammo = 5},
    {name = "Spraycan", id = 41, price = 40, ammo = 50},
    {name = "Nightvision", id = 44, price = 30, ammo = 1},
    {name = "Parachute", id = 46, price = 50, ammo = 1}
}

-- Populate the GridList
for _, w in ipairs(weapons) do
    local row = guiGridListAddRow(gridWeapons)
    guiGridListSetItemText(gridWeapons, row, 1, w.name, false, false)
    guiGridListSetItemText(gridWeapons, row, 2, tostring(w.ammo), false, false)
    guiGridListSetItemText(gridWeapons, row, 3, "$" .. tostring(w.price), false, false)
    guiGridListSetItemData(gridWeapons, row, 1, w)
end

-----------------------------------
-- EVENTS
-----------------------------------
addEventHandler("onClientMarkerHit", shopMarker, function(hitElement, matchingDimension)
    if hitElement == localPlayer and matchingDimension then
        guiSetVisible(shopWnd, true)
        showCursor(true)
    end
end)

addEventHandler("onClientMarkerLeave", shopMarker, function(leaveElement, matchingDimension)
    if leaveElement == localPlayer and matchingDimension then
        guiSetVisible(shopWnd, false)
        showCursor(false)
    end
end)

addEventHandler("onClientGUIClick", btnClose, function(button, state)
    if button == "left" and state == "up" then
        guiSetVisible(shopWnd, false)
        showCursor(false)
    end
end, false)

addEventHandler("onClientGUIClick", btnBuy, function(button, state)
    if button == "left" and state == "up" then
        local row = guiGridListGetSelectedItem(gridWeapons)
        if row ~= -1 then
            local w = guiGridListGetItemData(gridWeapons, row, 1)
            triggerServerEvent("onPlayerBuyWeapon", localPlayer, w.id, w.price, w.ammo)
        else
            outputChatBox("Please select an item first.", 255, 0, 0)
        end
    end
end, false)

-- Voice logic with spam prevention
local currentVendorSound = nil

addEvent("onVendorSpeak", true)
addEventHandler("onVendorSpeak", root, function(vendorPed)
    -- If a sound is currently playing, abort so we don't overlap quotes
    if isElement(currentVendorSound) then return end
    
    if isElement(vendorPed) then
        local x, y, z = getElementPosition(vendorPed)
        local soundIndex = math.random(1, 8)
        
        currentVendorSound = playSound3D("line" .. soundIndex .. ".mp3", x, y, z)
        
        -- Fix: Sync the sound's dimension and interior to the player so they can hear it inside the mission
        setElementDimension(currentVendorSound, getElementDimension(localPlayer))
        setElementInterior(currentVendorSound, getElementInterior(localPlayer))
        
        setSoundMaxDistance(currentVendorSound, 25)
        attachElements(currentVendorSound, vendorPed)
    end
end)