-- yakuza_server.lua
local playerYakuzas = {}

addCommandHandler("yakuza", function(player)
    if playerYakuzas[player] then
        for _, ped in ipairs(playerYakuzas[player]) do
            if isElement(ped) then destroyElement(ped) end
        end
    end
    playerYakuzas[player] = {}

    local x, y, z = getElementPosition(player)
    local int = getElementInterior(player)
    local dim = getElementDimension(player)
    local skins = {120, 117, 118, 186}

    for i = 1, 2 do
        local skin = skins[math.random(#skins)]
        local ox, oy = math.random(-2, 2), math.random(-2, 2)
        local ped = createPed(skin, x + ox, y + oy, z)
        setElementInterior(ped, int)
        setElementDimension(ped, dim)
        giveWeapon(ped, 30, 9999, true)
        
        -- STAT FIX: We raise max health stat so it can comfortably hold 200 HP without getting clipped visually by the engine.
        setPedStat(ped, 24, 1000) 
        setPedStat(ped, 72, 999) 
        
        -- NEW: Max out all weapon skills (69 to 79) so they shoot accurately
        for stat = 69, 79 do 
            setPedStat(ped, stat, 999) 
        end
        
        setElementData(ped, "isYakuza", true)
        setElementData(ped, "yakuzaOwner", player)
        setElementSyncer(ped, player)
        setElementHealth(ped, 200) -- Matches maximum naturally supported Ped Health. 

        local blip = createBlipAttachedTo(ped, 0, 2, 0, 255, 0)
        setElementVisibleTo(blip, root, false)
        setElementVisibleTo(blip, player, true)
        setElementData(ped, "yakuzaBlip", blip)

        table.insert(playerYakuzas[player], ped)
    end
    outputChatBox("Yakuza guards summoned!", player, 0, 255, 0)
end)

addEventHandler("onPlayerQuit", root, function()
    if playerYakuzas[source] then
        for _, ped in ipairs(playerYakuzas[source]) do
            if isElement(ped) then destroyElement(ped) end
        end
        playerYakuzas[source] = nil
    end
end)

addEventHandler("onPedWasted", root, function()
    if getElementData(source, "isYakuza") then
        local blip = getElementData(source, "yakuzaBlip")
        if isElement(blip) then destroyElement(blip) end
        setTimer(destroyElement, 5000, 1, source)
    end
end)