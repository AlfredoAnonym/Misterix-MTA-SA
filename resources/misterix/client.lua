-- client.lua
local missions = {}
activeMission = nil -- Made global for new file
myMissionLeader = nil -- Made global for new file
local destBlip, destMarker, destColShape = nil, nil, nil
local missionEntMarker, missionExitMarker = nil, nil
activeIntData = nil -- Made global for new file
missionPassedTick = 0 -- Made global
missionFailedTick = 0 -- Made global
missionPassedReward = 0 -- Made global
local activeMusicElement = nil 

mythX, mythY, mythZ = 0, 0, 0
isMysteryActive = false
missionFailedReasonStr = ""
local creatorWnd = nil 

local startX, startY, startZ = 423.250, 2536.497, 16.148
baseMarker = createMarker(startX, startY, startZ - 1, "cylinder", 2.0, 255, 0, 0, 150)
baseBlip = createBlip(startX, startY, startZ, 37)

local screenW, screenH = guiGetScreenSize()
local editingMissionId = nil
local oldWeather = nil
local oldTime = nil
local lockedTime = nil

-----------------------------------
-- MISSION BROWSER GUI
-----------------------------------
local browserWnd = guiCreateWindow(0.3, 0.25, 0.4, 0.5, "Misterix - Available Mysteries", true)
guiWindowSetSizable(browserWnd, false)
guiSetVisible(browserWnd, false)

local missionList = guiCreateGridList(0.05, 0.08, 0.9, 0.4, true, browserWnd)
guiGridListAddColumn(missionList, "Mission Name", 0.6)
guiGridListAddColumn(missionList, "Reward", 0.3)

local descLabel = guiCreateMemo(0.05, 0.50, 0.9, 0.28, "Select a mystery...", true, browserWnd)
guiMemoSetReadOnly(descLabel, true)

local btnAccept = guiCreateButton(0.05, 0.80, 0.17, 0.12, "Accept", true, browserWnd)
local btnEdit = guiCreateButton(0.23, 0.80, 0.17, 0.12, "Edit", true, browserWnd)
local btnDelete = guiCreateButton(0.41, 0.80, 0.17, 0.12, "Delete", true, browserWnd)
local btnInvite = guiCreateButton(0.59, 0.80, 0.17, 0.12, "Invite", true, browserWnd)
local btnCloseBrowser = guiCreateButton(0.77, 0.80, 0.17, 0.12, "Close", true, browserWnd)

-----------------------------------
-- INVITE UI GUIS
-----------------------------------
local inviteWnd = guiCreateWindow(0.35, 0.35, 0.3, 0.4, "Invite a Player", true)
guiWindowSetSizable(inviteWnd, false)
guiSetVisible(inviteWnd, false)
local playerList = guiCreateGridList(0.05, 0.1, 0.9, 0.6, true, inviteWnd)
guiGridListAddColumn(playerList, "Player Name", 0.9)
local btnSendInvite = guiCreateButton(0.05, 0.75, 0.4, 0.15, "Send Invite", true, inviteWnd)
local btnCloseInvite = guiCreateButton(0.55, 0.75, 0.4, 0.15, "Cancel", true, inviteWnd)

local currentInviter = nil

addEventHandler("onClientMarkerHit", baseMarker, function(hitElement, matchingDimension)
    if hitElement == localPlayer and matchingDimension and not isPedInVehicle(localPlayer) then
        local px, py, pz = getElementPosition(localPlayer)
        if math.abs(pz - startZ) > 3.0 then return end 
        if guiGetVisible(creatorWnd) then return end
        
        if activeMission then
            outputChatBox("You are already in an active mystery! Finish or fail it first.", 255, 0, 0)
            return
        end
        
        triggerServerEvent("requestMissions", localPlayer)
        guiSetVisible(browserWnd, true)
        showCursor(true)
    end
end)

addEvent("onClientReceiveMissions", true)
addEventHandler("onClientReceiveMissions", root, function(data)
    missions = data
    guiGridListClear(missionList)
    for i, mission in ipairs(missions) do
        local row = guiGridListAddRow(missionList)
        guiGridListSetItemText(missionList, row, 1, mission.name, false, false)
        guiGridListSetItemText(missionList, row, 2, "$" .. mission.reward, false, false)
        guiGridListSetItemData(missionList, row, 1, mission)
    end
end)

addEventHandler("onClientGUIClick", missionList, function()
    local row = guiGridListGetSelectedItem(missionList)
    if row ~= -1 then
        local data = guiGridListGetItemData(missionList, row, 1)
        
        local pData = fromJSON(data.peds)
        while pData and type(pData) == "table" and #pData == 1 and type(pData[1]) == "table" and not pData[1].model do
            pData = pData[1]
        end
        
        local killableBy, invulnTo, abilities = {}, {}, {}
        
        if pData and pData[1] then
            local v = pData[1].vuln or "Normal"
            if v == "Normal" then table.insert(killableBy, "Normal") else
                if string.find(v, "Explosion") then table.insert(killableBy, "Explosions") end
                if string.find(v, "Fire") then table.insert(killableBy, "Fire") end
                if string.find(v, "Water") then table.insert(killableBy, "Water") end
                if string.find(v, "Bullets") then table.insert(killableBy, "Bullets") end
                if string.find(v, "Chainsaw") then table.insert(invulnTo, "Chainsaw") end
                if string.find(v, "Minigun") then table.insert(invulnTo, "Minigun") end
            end
            if pData[1].teleport then table.insert(abilities, "Teleport") end
            if pData[1].heavypunch then table.insert(abilities, "Heavy Punch") end
            if pData[1].explosion then table.insert(abilities, "Explosion") end
        end
        
        local descStr = "Description:\n" .. data.desc .. "\n\nWeather ID: " .. tostring(data.weather or 0) .. "\nTime: " .. tostring(data.time or "-1")
        if #killableBy > 0 then descStr = descStr .. "\nKillable by: " .. table.concat(killableBy, ", ") end
        if #invulnTo > 0 then descStr = descStr .. "\nInvulnerable to: " .. table.concat(invulnTo, ", ") end
        if #abilities > 0 then descStr = descStr .. "\nAbilities: " .. table.concat(abilities, ", ") end
        
        guiSetText(descLabel, descStr)
    end
end, false)

addEventHandler("onClientGUIClick", btnCloseBrowser, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    guiSetVisible(browserWnd, false)
    showCursor(false)
end, false)

addEventHandler("onClientGUIClick", btnInvite, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    guiGridListClear(playerList)
    for _, p in ipairs(getElementsByType("player")) do
        if p ~= localPlayer then
            local row = guiGridListAddRow(playerList)
            guiGridListSetItemText(playerList, row, 1, getPlayerName(p), false, false)
            guiGridListSetItemData(playerList, row, 1, p)
        end
    end
    guiSetVisible(inviteWnd, true)
    guiBringToFront(inviteWnd)
end, false)

addEventHandler("onClientGUIClick", btnCloseInvite, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    guiSetVisible(inviteWnd, false)
end, false)

addEventHandler("onClientGUIClick", btnSendInvite, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    local row = guiGridListGetSelectedItem(playerList)
    if row ~= -1 then
        local targetPlayer = guiGridListGetItemData(playerList, row, 1)
        if isElement(targetPlayer) then
            triggerServerEvent("sendMissionInvite", localPlayer, targetPlayer)
            guiSetVisible(inviteWnd, false)
        end
    end
end, false)

addEvent("onClientReceiveInvite", true)
addEventHandler("onClientReceiveInvite", root, function(inviter)
    currentInviter = inviter
    outputChatBox(getPlayerName(inviter) .. " invited you to a mystery party! Type /invite to accept.", 255, 200, 0)
end)

addCommandHandler("invite", function()
    if activeMission then return outputChatBox("You cannot accept an invite while in an active mystery.", 255, 0, 0) end
    if currentInviter and isElement(currentInviter) then
        triggerServerEvent("acceptMissionInvite", localPlayer, currentInviter)
        currentInviter = nil
    else
        outputChatBox("You do not have any pending mystery invites.", 255, 0, 0)
    end
end)

-----------------------------------
-- MISSION CREATOR GUI (/cm / F4)
-----------------------------------
local creatorMode = "Ped" 
creatorWnd = guiCreateWindow(0.2, 0.1, 0.6, 0.85, "Create a Mystery", true)
guiWindowSetSizable(creatorWnd, false)
guiSetVisible(creatorWnd, false)

guiCreateLabel(0.05, 0.05, 0.2, 0.05, "Mission Name:", true, creatorWnd)
local editName = guiCreateEdit(0.25, 0.04, 0.7, 0.05, "", true, creatorWnd)
guiCreateLabel(0.05, 0.11, 0.2, 0.05, "Description:", true, creatorWnd)
local editDesc = guiCreateMemo(0.25, 0.11, 0.7, 0.10, "", true, creatorWnd)

guiCreateLabel(0.05, 0.23, 0.12, 0.05, "Reward ($):", true, creatorWnd)
local editReward = guiCreateEdit(0.18, 0.22, 0.15, 0.05, "5000", true, creatorWnd)

guiCreateLabel(0.35, 0.23, 0.10, 0.05, "Weather:", true, creatorWnd)
local editWeather = guiCreateEdit(0.45, 0.22, 0.08, 0.05, "0", true, creatorWnd)

guiCreateLabel(0.55, 0.23, 0.08, 0.05, "Time:", true, creatorWnd)
local editTime = guiCreateEdit(0.63, 0.22, 0.10, 0.05, "-1", true, creatorWnd)

guiCreateLabel(0.75, 0.23, 0.08, 0.05, "Music:", true, creatorWnd)
local comboMusic = guiCreateComboBox(0.82, 0.22, 0.16, 0.25, "None", true, creatorWnd)
local musicOptions = {"None", "xfiles1.mp3", "xfiles2.mp3", "myth2.mp3", "myth3.mp3", "myth4.mp3", "m-dino.mp3", "m-godzilla.mp3", "m-nemesis.mp3"}
for _, m in ipairs(musicOptions) do guiComboBoxAddItem(comboMusic, m) end
guiComboBoxSetSelected(comboMusic, 0)

local pedsToSave = {}
guiCreateLabel(0.05, 0.30, 0.5, 0.04, "--- Add Entities to Mystery ---", true, creatorWnd)
local btnModeToggle = guiCreateButton(0.75, 0.29, 0.2, 0.05, "Switch to CARS", true, creatorWnd)

local lblPedID = guiCreateLabel(0.05, 0.36, 0.1, 0.05, "Entity ID:", true, creatorWnd)
local editPedID = guiCreateEdit(0.15, 0.35, 0.1, 0.05, "1", true, creatorWnd)

local lblWepID = guiCreateLabel(0.28, 0.36, 0.15, 0.05, "Weapon(Ped):", true, creatorWnd)
local editWepID = guiCreateEdit(0.43, 0.35, 0.1, 0.05, "30", true, creatorWnd)

guiCreateLabel(0.55, 0.36, 0.1, 0.05, "Health:", true, creatorWnd)
local editHP = guiCreateEdit(0.65, 0.35, 0.1, 0.05, "3000", true, creatorWnd)

local lblAcc = guiCreateLabel(0.05, 0.43, 0.1, 0.05, "Accuracy:", true, creatorWnd)
local editAcc = guiCreateEdit(0.15, 0.42, 0.1, 0.05, "25", true, creatorWnd)

local lblWalk = guiCreateLabel(0.28, 0.43, 0.1, 0.05, "WalkStyle:", true, creatorWnd)
local editWalk = guiCreateEdit(0.38, 0.42, 0.1, 0.05, "0", true, creatorWnd)

guiCreateLabel(0.50, 0.43, 0.1, 0.05, "Alpha:", true, creatorWnd)
local editAlpha = guiCreateEdit(0.58, 0.42, 0.1, 0.05, "255", true, creatorWnd)
local chkStandStill = guiCreateCheckBox(0.70, 0.42, 0.2, 0.05, "Stand Still", false, false, creatorWnd)

local btnGetCoords = guiCreateButton(0.75, 0.35, 0.2, 0.12, "Get Coords", true, creatorWnd)
local currentCoords = nil

local lblPowers = guiCreateLabel(0.05, 0.49, 0.2, 0.05, "Special Powers:", true, creatorWnd)
local gridPowers = guiCreateGridList(0.25, 0.49, 0.4, 0.13, true, creatorWnd)
guiGridListSetSelectionMode(gridPowers, 1) 
guiGridListAddColumn(gridPowers, "Select Multi (Hold CTRL)", 0.9)
local rowExp = guiGridListAddRow(gridPowers); guiGridListSetItemText(gridPowers, rowExp, 1, "Vuln: Explosion", false, false)
local rowFire = guiGridListAddRow(gridPowers); guiGridListSetItemText(gridPowers, rowFire, 1, "Vuln: Fire", false, false)
local rowWater = guiGridListAddRow(gridPowers); guiGridListSetItemText(gridPowers, rowWater, 1, "Vuln: Water", false, false)
local rowBullets = guiGridListAddRow(gridPowers); guiGridListSetItemText(gridPowers, rowBullets, 1, "Vuln: Bullets", false, false)
local rowChain = guiGridListAddRow(gridPowers); guiGridListSetItemText(gridPowers, rowChain, 1, "Invuln: Chainsaw", false, false)
local rowMini = guiGridListAddRow(gridPowers); guiGridListSetItemText(gridPowers, rowMini, 1, "Invuln: Minigun", false, false)
local rowPunch = guiGridListAddRow(gridPowers); guiGridListSetItemText(gridPowers, rowPunch, 1, "Ability: Heavy Punch", false, false)
local rowTp = guiGridListAddRow(gridPowers); guiGridListSetItemText(gridPowers, rowTp, 1, "Ability: Teleport", false, false)
local rowExplosion = guiGridListAddRow(gridPowers); guiGridListSetItemText(gridPowers, rowExplosion, 1, "Ability: Explosion", false, false)

local btnAddPed = guiCreateButton(0.68, 0.49, 0.28, 0.05, "Add Entity", true, creatorWnd)
local btnRemovePed = guiCreateButton(0.68, 0.55, 0.28, 0.05, "Remove Last", true, creatorWnd)
local pedCountLabel = guiCreateLabel(0.68, 0.61, 0.28, 0.05, "Entities added: 0", true, creatorWnd)

local intDataToSave = {id = 0}
local lblIntHeader = guiCreateLabel(0.05, 0.64, 0.9, 0.04, "--- Interior Settings ---", true, creatorWnd)
local lblIntID = guiCreateLabel(0.3, 0.69, 0.1, 0.05, "Int ID:", true, creatorWnd)
local editIntID = guiCreateEdit(0.4, 0.68, 0.1, 0.05, "0", true, creatorWnd)

local btnSetEntMark = guiCreateButton(0.05, 0.75, 0.22, 0.06, "Ent. Marker Pos", true, creatorWnd)
local btnSetEntTarg = guiCreateButton(0.28, 0.75, 0.22, 0.06, "Ent. Target Pos", true, creatorWnd)
local btnSetExitMark = guiCreateButton(0.51, 0.75, 0.22, 0.06, "Exit Marker Pos", true, creatorWnd)
local btnSetExitTarg = guiCreateButton(0.74, 0.75, 0.22, 0.06, "Exit Target Pos", true, creatorWnd)

local lblIntStatus = guiCreateLabel(0.05, 0.82, 0.9, 0.05, "Int Coords: 0/4 set", true, creatorWnd)

local btnSaveMystery = guiCreateButton(0.05, 0.88, 0.4, 0.07, "Save mystery", true, creatorWnd)
local btnCloseCreator = guiCreateButton(0.55, 0.88, 0.4, 0.07, "Close", true, creatorWnd)

addEventHandler("onClientGUIClick", btnModeToggle, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    if creatorMode == "Ped" then
        creatorMode = "Car"
        guiSetText(btnModeToggle, "Switch to PEDS")
        guiSetText(lblPedID, "Vehicle ID:")
        guiSetVisible(lblWepID, false)
        guiSetVisible(editWepID, false)
        guiSetVisible(lblAcc, false)
        guiSetVisible(editAcc, false)
        guiSetVisible(lblWalk, false)
        guiSetVisible(editWalk, false)
        guiSetVisible(chkStandStill, false)
        guiSetVisible(lblPowers, false)
        guiSetVisible(gridPowers, false)
        guiSetVisible(lblIntHeader, false)
        guiSetVisible(lblIntID, false)
        guiSetVisible(editIntID, false)
        guiSetVisible(btnSetEntMark, false)
        guiSetVisible(btnSetEntTarg, false)
        guiSetVisible(btnSetExitMark, false)
        guiSetVisible(btnSetExitTarg, false)
        guiSetVisible(lblIntStatus, false)
    else
        creatorMode = "Ped"
        guiSetText(btnModeToggle, "Switch to CARS")
        guiSetText(lblPedID, "Entity ID:")
        guiSetVisible(lblWepID, true)
        guiSetVisible(editWepID, true)
        guiSetVisible(lblAcc, true)
        guiSetVisible(editAcc, true)
        guiSetVisible(lblWalk, true)
        guiSetVisible(editWalk, true)
        guiSetVisible(chkStandStill, true)
        guiSetVisible(lblPowers, true)
        guiSetVisible(gridPowers, true)
        guiSetVisible(lblIntHeader, true)
        guiSetVisible(lblIntID, true)
        guiSetVisible(editIntID, true)
        guiSetVisible(btnSetEntMark, true)
        guiSetVisible(btnSetEntTarg, true)
        guiSetVisible(btnSetExitMark, true)
        guiSetVisible(btnSetExitTarg, true)
        guiSetVisible(lblIntStatus, true)
    end
end, false)

local function updateIntStatusLabel()
    local c = 0
    if intDataToSave.entMark then c = c + 1 end
    if intDataToSave.entTarg then c = c + 1 end
    if intDataToSave.exitMark then c = c + 1 end
    if intDataToSave.exitTarg then c = c + 1 end
    guiSetText(lblIntStatus, "Int Coords: " .. c .. "/4 set")
end

function clearCreatorData()
    editingMissionId = nil
    guiSetText(creatorWnd, "Create a Mystery")
    guiSetText(btnSaveMystery, "Create mystery")
    guiSetText(editName, "")
    guiSetText(editDesc, "")
    guiSetText(editReward, "5000")
    guiSetText(editWeather, "0")
    guiSetText(editTime, "-1")
    guiSetText(editWalk, "0")
    guiComboBoxSetSelected(comboMusic, 0)
    guiGridListSetSelectedItem(gridPowers, -1, -1, true) 
    pedsToSave = {}
    guiSetText(pedCountLabel, "Entities added: 0")
    intDataToSave = {id = 0}
    guiSetText(editIntID, "0")
    updateIntStatusLabel()
end

function toggleCreatorWindow()
    guiSetVisible(creatorWnd, not guiGetVisible(creatorWnd))
    showCursor(guiGetVisible(creatorWnd))
end

addCommandHandler("cm", function()
    if activeMission then return outputChatBox("You cannot use the Creator Menu while in an active mystery.", 255, 0, 0) end
    triggerServerEvent("requestCMOpen", localPlayer)
end)

bindKey("F4", "down", function()
    if activeMission or guiGetVisible(browserWnd) then return end
    if guiGetVisible(creatorWnd) then toggleCreatorWindow() else triggerServerEvent("requestCMOpen", localPlayer) end
end)

addEvent("openCM", true)
addEventHandler("openCM", root, function()
    if not guiGetVisible(creatorWnd) then toggleCreatorWindow() end
end)

addEventHandler("onClientGUIClick", btnEdit, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    local row = guiGridListGetSelectedItem(missionList)
    if row ~= -1 then
        local data = guiGridListGetItemData(missionList, row, 1)
        editingMissionId = data.id
        
        guiSetText(creatorWnd, "Edit Mystery")
        guiSetText(btnSaveMystery, "Update Mystery")
        guiSetText(editName, data.name)
        guiSetText(editDesc, data.desc)
        guiSetText(editReward, tostring(data.reward))
        guiSetText(editWeather, tostring(data.weather or 0))
        guiSetText(editTime, tostring(data.time or "-1"))
        
        local selectedMusicIdx = 0
        for i, m in ipairs(musicOptions) do if data.music == m then selectedMusicIdx = i - 1 end end
        guiComboBoxSetSelected(comboMusic, selectedMusicIdx)
        
        local pData = fromJSON(data.peds)
        while pData and type(pData) == "table" and #pData == 1 and type(pData[1]) == "table" and not pData[1].model do pData = pData[1] end
        pedsToSave = pData or {}
        guiSetText(pedCountLabel, "Entities added: " .. #pedsToSave)
        
        guiGridListSetSelectedItem(gridPowers, -1, -1, true)
        
        if pedsToSave[1] then
            local firstPed = pedsToSave[1]
            if firstPed.eType == "Car" and creatorMode == "Ped" then
                creatorMode = "Car"
                guiSetText(btnModeToggle, "Switch to PEDS")
                guiSetText(lblPedID, "Vehicle ID:")
                guiSetVisible(lblWepID, false); guiSetVisible(editWepID, false); guiSetVisible(lblAcc, false); guiSetVisible(editAcc, false)
                guiSetVisible(lblWalk, false); guiSetVisible(editWalk, false); guiSetVisible(chkStandStill, false); guiSetVisible(lblPowers, false)
                guiSetVisible(gridPowers, false); guiSetVisible(lblIntHeader, false); guiSetVisible(lblIntID, false); guiSetVisible(editIntID, false)
                guiSetVisible(btnSetEntMark, false); guiSetVisible(btnSetEntTarg, false); guiSetVisible(btnSetExitMark, false); guiSetVisible(btnSetExitTarg, false); guiSetVisible(lblIntStatus, false)
            elseif firstPed.eType == "Ped" and creatorMode == "Car" then
                creatorMode = "Ped"
                guiSetText(btnModeToggle, "Switch to CARS")
                guiSetText(lblPedID, "Entity ID:")
                guiSetVisible(lblWepID, true); guiSetVisible(editWepID, true); guiSetVisible(lblAcc, true); guiSetVisible(editAcc, true)
                guiSetVisible(lblWalk, true); guiSetVisible(editWalk, true); guiSetVisible(chkStandStill, true); guiSetVisible(lblPowers, true)
                guiSetVisible(gridPowers, true); guiSetVisible(lblIntHeader, true); guiSetVisible(lblIntID, true); guiSetVisible(editIntID, true)
                guiSetVisible(btnSetEntMark, true); guiSetVisible(btnSetEntTarg, true); guiSetVisible(btnSetExitMark, true); guiSetVisible(btnSetExitTarg, true); guiSetVisible(lblIntStatus, true)
            end
            
            guiSetText(editPedID, tostring(firstPed.model or 1))
            guiSetText(editWepID, tostring(firstPed.wep or 0))
            guiSetText(editHP, tostring(firstPed.hp or 3000))
            guiSetText(editAcc, tostring(firstPed.acc or 25))
            guiSetText(editWalk, tostring(firstPed.walkstyle or 0))
            guiSetText(editAlpha, tostring(firstPed.alpha or 255))
            guiCheckBoxSetSelected(chkStandStill, firstPed.behavior == "stand")

            local v = firstPed.vuln
            if v and string.find(v, "Explosion") then guiGridListSetSelectedItem(gridPowers, rowExp, 1, false) end
            if v and string.find(v, "Fire") then guiGridListSetSelectedItem(gridPowers, rowFire, 1, false) end
            if v and string.find(v, "Water") then guiGridListSetSelectedItem(gridPowers, rowWater, 1, false) end
            if v and string.find(v, "Bullets") then guiGridListSetSelectedItem(gridPowers, rowBullets, 1, false) end
            if v and string.find(v, "Chainsaw") then guiGridListSetSelectedItem(gridPowers, rowChain, 1, false) end
            if v and string.find(v, "Minigun") then guiGridListSetSelectedItem(gridPowers, rowMini, 1, false) end
            if firstPed.teleport then guiGridListSetSelectedItem(gridPowers, rowTp, 1, false) end
            if firstPed.heavypunch then guiGridListSetSelectedItem(gridPowers, rowPunch, 1, false) end
            if firstPed.explosion then guiGridListSetSelectedItem(gridPowers, rowExplosion, 1, false) end
        end

        local iData = fromJSON(data.int_data or "{}")
        if type(iData) == "table" and iData[1] then iData = iData[1] end
        intDataToSave = iData or {id = 0}
        
        guiSetText(editIntID, tostring(intDataToSave.id or 0))
        updateIntStatusLabel()
        guiSetVisible(browserWnd, false)
        guiSetVisible(creatorWnd, true)
    end
end, false)

addEventHandler("onClientGUIClick", btnDelete, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    local row = guiGridListGetSelectedItem(missionList)
    if row ~= -1 then
        local data = guiGridListGetItemData(missionList, row, 1)
        triggerServerEvent("deleteMystery", localPlayer, data.id)
    end
end, false)

addEventHandler("onClientGUIClick", btnGetCoords, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    local x, y, z = getElementPosition(localPlayer)
    currentCoords = {x = x, y = y, z = z}
    outputChatBox("Coords set!", 0, 255, 0)
end, false)

local function saveIntPos(key)
    local x,y,z = getElementPosition(localPlayer)
    local int = getElementInterior(localPlayer)
    local dim = getElementDimension(localPlayer)
    intDataToSave[key] = {x=x, y=y, z=z, int=int, dim=dim}
    updateIntStatusLabel()
    outputChatBox(key .. " coords saved!", 0, 255, 0)
end
addEventHandler("onClientGUIClick", btnSetEntMark, function(b,s) if b=="left" and s=="up" then saveIntPos("entMark") end end, false)
addEventHandler("onClientGUIClick", btnSetEntTarg, function(b,s) if b=="left" and s=="up" then saveIntPos("entTarg") end end, false)
addEventHandler("onClientGUIClick", btnSetExitMark, function(b,s) if b=="left" and s=="up" then saveIntPos("exitMark") end end, false)
addEventHandler("onClientGUIClick", btnSetExitTarg, function(b,s) if b=="left" and s=="up" then saveIntPos("exitTarg") end end, false)

addEventHandler("onClientGUIClick", btnAddPed, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    if not currentCoords then return outputChatBox("Get coordinates first!", 255, 0, 0) end
    
    local modelID = tonumber(guiGetText(editPedID)) or 1
    local eType = creatorMode
    
    if eType == "Car" then
        local validCar = true
        if modelID == 539 or modelID == 476 then validCar = true
        else
            local vType = getVehicleType(modelID)
            if not vType or vType == "Plane" or vType == "Helicopter" or vType == "Train" or vType == "Trailer" or vType == "Boat" then validCar = false end
        end
        if not validCar then return outputChatBox("Invalid Car ID! No planes/boats (except Vortex 539 & Rustler 476).", 255, 0, 0) end
    end

    local selectedPowers = guiGridListGetSelectedItems(gridPowers)
    local vulns = {}
    local doTeleport, doHeavyPunch, doExplosion = false, false, false
    
    for _, item in ipairs(selectedPowers) do
        local text = guiGridListGetItemText(gridPowers, item.row, 1)
        if text == "Vuln: Explosion" then table.insert(vulns, "Explosion") end
        if text == "Vuln: Fire" then table.insert(vulns, "Fire") end
        if text == "Vuln: Water" then table.insert(vulns, "Water") end
        if text == "Vuln: Bullets" then table.insert(vulns, "Bullets") end
        if text == "Invuln: Chainsaw" then table.insert(vulns, "Chainsaw") end 
        if text == "Invuln: Minigun" then table.insert(vulns, "Minigun") end
        if text == "Ability: Teleport" then doTeleport = true end
        if text == "Ability: Heavy Punch" then doHeavyPunch = true end
        if text == "Ability: Explosion" then doExplosion = true end
    end
    local vulnStr = (#vulns > 0) and table.concat(vulns, ", ") or "Normal"

    table.insert(pedsToSave, {
        eType = eType, model = modelID,
        wep = (eType == "Ped") and (tonumber(guiGetText(editWepID)) or 0) or 0,
        hp = tonumber(guiGetText(editHP)) or 3000,
        acc = (eType == "Ped") and (tonumber(guiGetText(editAcc)) or 25) or 0,
        walkstyle = (eType == "Ped") and (tonumber(guiGetText(editWalk)) or 0) or 0,
        alpha = tonumber(guiGetText(editAlpha)) or 255,
        behavior = (eType == "Ped" and guiCheckBoxGetSelected(chkStandStill)) and "stand" or "chase",
        vuln = (eType == "Ped") and vulnStr or "Normal",
        teleport = (eType == "Ped") and doTeleport or false,
        heavypunch = (eType == "Ped") and doHeavyPunch or false,
        explosion = doExplosion, interior = getElementInterior(localPlayer), dimension = getElementDimension(localPlayer),
        x = currentCoords.x, y = currentCoords.y, z = currentCoords.z
    })
    guiSetText(pedCountLabel, "Entities added: " .. #pedsToSave)
    outputChatBox(eType .. " added to mission draft.", 0, 255, 0)
end, false)

addEventHandler("onClientGUIClick", btnRemovePed, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    if #pedsToSave > 0 then
        table.remove(pedsToSave)
        guiSetText(pedCountLabel, "Entities added: " .. #pedsToSave)
        outputChatBox("Last entity removed from mission draft.", 255, 150, 0)
    else outputChatBox("No entities to remove!", 255, 0, 0) end
end, false)

addEventHandler("onClientGUIClick", btnSaveMystery, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    local name = guiGetText(editName)
    local desc = guiGetText(editDesc)
    local reward = tonumber(guiGetText(editReward)) or 0
    local weather = tonumber(guiGetText(editWeather)) or 0
    local timeStr = guiGetText(editTime)
    local selMusicItem = guiComboBoxGetSelected(comboMusic)
    local music = (selMusicItem and selMusicItem ~= -1) and guiComboBoxGetItemText(comboMusic, selMusicItem) or "None"
    
    if name == "" or #pedsToSave == 0 then return outputChatBox("Need a name and at least 1 entity!", 255, 0, 0) end
    
    if #pedsToSave == 1 then
        pedsToSave[1].model = tonumber(guiGetText(editPedID)) or pedsToSave[1].model
        pedsToSave[1].wep = tonumber(guiGetText(editWepID)) or pedsToSave[1].wep
        pedsToSave[1].hp = tonumber(guiGetText(editHP)) or pedsToSave[1].hp
        pedsToSave[1].acc = tonumber(guiGetText(editAcc)) or pedsToSave[1].acc
        pedsToSave[1].walkstyle = tonumber(guiGetText(editWalk)) or pedsToSave[1].walkstyle
        pedsToSave[1].alpha = tonumber(guiGetText(editAlpha)) or pedsToSave[1].alpha
        
        local selectedPowers = guiGridListGetSelectedItems(gridPowers)
        local vulns = {}
        local doTeleport, doHeavyPunch, doExplosion = false, false, false
        for _, item in ipairs(selectedPowers) do
            local text = guiGridListGetItemText(gridPowers, item.row, 1)
            if text == "Vuln: Explosion" then table.insert(vulns, "Explosion") end
            if text == "Vuln: Fire" then table.insert(vulns, "Fire") end
            if text == "Vuln: Water" then table.insert(vulns, "Water") end
            if text == "Vuln: Bullets" then table.insert(vulns, "Bullets") end
            if text == "Invuln: Chainsaw" then table.insert(vulns, "Chainsaw") end
            if text == "Invuln: Minigun" then table.insert(vulns, "Minigun") end
            if text == "Ability: Teleport" then doTeleport = true end
            if text == "Ability: Heavy Punch" then doHeavyPunch = true end
            if text == "Ability: Explosion" then doExplosion = true end
        end
        pedsToSave[1].vuln = (#vulns > 0) and table.concat(vulns, ", ") or "Normal"
        pedsToSave[1].teleport = doTeleport
        pedsToSave[1].heavypunch = doHeavyPunch
        pedsToSave[1].explosion = doExplosion
    end

    intDataToSave.id = tonumber(guiGetText(editIntID)) or 0
    local pedsJSON = toJSON(pedsToSave)
    local intJSON = toJSON(intDataToSave)
    
    if editingMissionId then triggerServerEvent("updateMystery", localPlayer, editingMissionId, name, desc, reward, weather, timeStr, music, pedsJSON, intJSON)
    else triggerServerEvent("saveNewMystery", localPlayer, name, desc, reward, weather, timeStr, music, pedsJSON, intJSON) end
    
    guiSetVisible(creatorWnd, false)
    showCursor(false)
    clearCreatorData()
end, false)

addEventHandler("onClientGUIClick", btnCloseCreator, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    guiSetVisible(creatorWnd, false)
    showCursor(false)
end, false)

-----------------------------------
-- MISSION LOGIC & HEALTHBAR
-----------------------------------
function cleanupMissionElements()
    if isElement(destBlip) then destroyElement(destBlip) end
    if isElement(destMarker) then destroyElement(destMarker) end
    if isElement(destColShape) then destroyElement(destColShape) end
    if isElement(missionEntMarker) then destroyElement(missionEntMarker) end
    if isElement(missionExitMarker) then destroyElement(missionExitMarker) end
    if isElement(activeMusicElement) then stopSound(activeMusicElement); activeMusicElement = nil end
    activeIntData = nil
end

function restoreWeather()
    if oldWeather then setWeather(oldWeather); oldWeather = nil end
    if oldTime then setTime(oldTime[1], oldTime[2]); oldTime = nil end
    lockedTime = nil
end

addEventHandler("onClientResourceStop", resourceRoot, restoreWeather)

function failMission(reason)
    if activeMission then triggerServerEvent("mysteryFailed", localPlayer, myMissionLeader, reason) end
end
addEventHandler("onClientPlayerWasted", localPlayer, function() failMission("death") end)

addEventHandler("onClientGUIClick", btnAccept, function(button, state)
    if button ~= "left" or state ~= "up" then return end
    local row = guiGridListGetSelectedItem(missionList)
    if row ~= -1 then
        local missionData = guiGridListGetItemData(missionList, row, 1)
        guiSetVisible(browserWnd, false)
        showCursor(false)
        triggerServerEvent("startSharedMission", localPlayer, missionData)
    end
end, false)

addEvent("onClientSetupMission", true)
addEventHandler("onClientSetupMission", root, function(missionData, leader)
    activeMission = missionData
    myMissionLeader = leader
    isMysteryActive = false
    
    local pedsData = fromJSON(activeMission.peds)
    while pedsData and type(pedsData) == "table" and #pedsData == 1 and type(pedsData[1]) == "table" and not pedsData[1].model do pedsData = pedsData[1] end
    
    local iData = fromJSON(activeMission.int_data or "{}")
    if type(iData) == "table" and iData[1] then iData = iData[1] end
    
    if pedsData and #pedsData > 0 then
        local firstPed = pedsData[1]
        cleanupMissionElements()
        
        local targetX, targetY, targetZ
        local targetInt, targetDim = 0, 0
        
        if iData and iData.entMark then
            activeIntData = iData
            if not isElement(missionEntMarker) then
                missionEntMarker = createMarker(iData.entMark.x, iData.entMark.y, iData.entMark.z - 1.0, "cylinder", 1.5, 255, 255, 0, 150)
                setElementInterior(missionEntMarker, iData.entMark.int or 0)
                setElementDimension(missionEntMarker, getElementDimension(localPlayer))
            end
            if iData.exitMark and not isElement(missionExitMarker) then
                missionExitMarker = createMarker(iData.exitMark.x, iData.exitMark.y, iData.exitMark.z - 1.0, "cylinder", 1.5, 255, 255, 0, 150)
                setElementInterior(missionExitMarker, iData.exitMark.int or iData.id or 0)
                setElementDimension(missionExitMarker, getElementDimension(localPlayer))
            end
            destBlip = createBlip(iData.entMark.x, iData.entMark.y, iData.entMark.z, 23)
            setElementDimension(destBlip, getElementDimension(localPlayer))
            targetX, targetY, targetZ = firstPed.x, firstPed.y, firstPed.z
            targetInt = firstPed.interior or 0
            targetDim = getElementDimension(localPlayer) -- Use the isolated dimension we were placed in
        else
            targetX, targetY, targetZ = firstPed.x, firstPed.y, firstPed.z
            targetInt = firstPed.interior or 0
            destBlip = createBlip(targetX, targetY, targetZ, 23)
            setElementDimension(destBlip, getElementDimension(localPlayer))
        end
        
        mythX, mythY, mythZ = targetX, targetY, targetZ
        destMarker = createMarker(targetX, targetY, targetZ - 1, "checkpoint", 4.0, 255, 0, 0, 150)
        destColShape = createColTube(targetX, targetY, targetZ - 20, 50.0, 60.0)
        
        setElementInterior(destMarker, targetInt)
        setElementDimension(destMarker, getElementDimension(localPlayer))
        setElementInterior(destColShape, targetInt)
        setElementDimension(destColShape, getElementDimension(localPlayer))
        
        outputChatBox("Mystery Accepted! Head to the location on your radar.", 255, 255, 0)
        
        setTimer(function()
            if isElement(destColShape) then
                addEventHandler("onClientColShapeHit", destColShape, function(hitElement, matchingDimension)
                    if hitElement == localPlayer and matchingDimension then
                        triggerServerEvent("spawnMissionPedsShared", localPlayer, pedsData, activeMission.reward, myMissionLeader, activeMission.weather or 0, activeMission.int_data)
                    end
                end)
            end
        end, 1500, 1)
    end 
end)

addEvent("onClientHideColShape", true)
addEventHandler("onClientHideColShape", root, function(weatherID, intDataJSON)
    if isElement(destColShape) then destroyElement(destColShape) end
    if isElement(destMarker) then destroyElement(destMarker) end
    if isElement(destBlip) then destroyElement(destBlip) end

    isMysteryActive = true
    outputChatBox("The mystery reveals itself! Defend yourself!", 255, 0, 0)
    
    if weatherID and tonumber(weatherID) >= 0 then
        local w, bw = getWeather()
        if not oldWeather then oldWeather = w end
        setWeather(tonumber(weatherID))
    end
    
    if activeMission and activeMission.time and activeMission.time ~= "-1" then
        local timeStr = tostring(activeMission.time)
        local h, m = 0, 0
        if string.find(timeStr, ":") then
            local parts = split(timeStr, ":")
            h = tonumber(parts[1]) or 0; m = tonumber(parts[2]) or 0
        else
            local timeNum = tonumber(timeStr) or 0
            h = math.floor(timeNum); m = math.floor((timeNum - h) * 100)
        end
        if h >= 0 and h <= 23 then
            local curH, curM = getTime()
            if not oldTime then oldTime = {curH, curM} end
            lockedTime = {h, m}
        end
    end

    if isElement(activeMusicElement) then stopSound(activeMusicElement); activeMusicElement = nil end
    if activeMission and activeMission.music and activeMission.music ~= "None" then
        activeMusicElement = playSound(activeMission.music, true)
    end
    
    local iData = fromJSON(intDataJSON or "{}")
    if type(iData) == "table" and iData[1] then iData = iData[1] end
    
    if iData and (iData.entMark or iData.exitMark) then
        activeIntData = iData
        if iData.entMark and not isElement(missionEntMarker) then
            missionEntMarker = createMarker(iData.entMark.x, iData.entMark.y, iData.entMark.z - 1.0, "cylinder", 1.5, 255, 255, 0, 150)
            setElementInterior(missionEntMarker, iData.entMark.int or 0)
            setElementDimension(missionEntMarker, getElementDimension(localPlayer))
        end
        if iData.exitMark and not isElement(missionExitMarker) then
            missionExitMarker = createMarker(iData.exitMark.x, iData.exitMark.y, iData.exitMark.z - 1.0, "cylinder", 1.5, 255, 255, 0, 150)
            setElementInterior(missionExitMarker, iData.exitMark.int or iData.id or 0)
            setElementDimension(missionExitMarker, getElementDimension(localPlayer))
        end
    end
end)

addEventHandler("onClientMarkerHit", root, function(hitElement, matchingDimension)
    if hitElement == localPlayer and matchingDimension and not isPedInVehicle(localPlayer) and activeIntData then
        if source == missionEntMarker and activeIntData.entTarg then
            triggerServerEvent("warpMysteryPlayer", localPlayer, activeIntData.entTarg.int or activeIntData.id or 0, getElementDimension(localPlayer), activeIntData.entTarg.x, activeIntData.entTarg.y, activeIntData.entTarg.z)
        elseif source == missionExitMarker and activeIntData.exitTarg then
            triggerServerEvent("warpMysteryPlayer", localPlayer, activeIntData.exitTarg.int or 0, getElementDimension(localPlayer), activeIntData.exitTarg.x, activeIntData.exitTarg.y, activeIntData.exitTarg.z)
        end
    end
end)

addEventHandler("onClientRender", root, function()
    if lockedTime then setTime(lockedTime[1], lockedTime[2]) end

    if missionPassedTick > 0 then
        if getTickCount() - missionPassedTick < 5000 then
            dxDrawText("Mission Passed!", 0, screenH * 0.4 - 30, screenW, screenH * 0.4 - 30, tocolor(255, 215, 0, 255), 3.0, "pricedown", "center", "center")
            dxDrawText("$" .. tostring(missionPassedReward), 0, screenH * 0.4 + 30, screenW, screenH * 0.4 + 30, tocolor(20, 150, 20, 255), 2.5, "pricedown", "center", "center")
        else missionPassedTick = 0 end
    end
    
    if missionFailedTick > 0 then
        if getTickCount() - missionFailedTick < 5000 then
            dxDrawText("Mission Failed", 0, screenH * 0.4 - 40, screenW, screenH * 0.4 - 40, tocolor(200, 0, 0, 255), 3.0, "pricedown", "center", "center")
            if missionFailedReasonStr ~= "" then
                dxDrawText(missionFailedReasonStr, 0, screenH * 0.4 + 20, screenW, screenH * 0.4 + 20, tocolor(255, 255, 255, 255), 1.5, "default-bold", "center", "center")
            end
        else missionFailedTick = 0 end
    end

    if activeMission then
        local peds = getElementData(myMissionLeader or localPlayer, "activeMysteryPeds") or {}
        local activeEntities = {}
        
        for _, ent in ipairs(peds) do
            if isElement(ent) then
                local eType = getElementData(ent, "eType") or "Ped"
                local isAlive = false
                if eType == "Car" then isAlive = not isVehicleBlown(ent) else isAlive = not isPedDead(ent) end
                if isAlive then table.insert(activeEntities, ent) end
            end
        end
        
        local count = #activeEntities
        local titleText = activeMission and activeMission.name or "Mystery Entity"
        
        if count == 1 then
            local ent = activeEntities[1]
            local hp = getElementData(ent, "bossHealth") or 0
            local maxHp = getElementData(ent, "maxBossHealth") or 1
            
            local width, height = 500, 25
            local x = (screenW - width) / 2
            local y = screenH - 80
            
            dxDrawRectangle(x, y, width, height, tocolor(0, 0, 0, 180))
            local healthWidth = (width - 4) * (hp / maxHp)
            if healthWidth < 0 then healthWidth = 0 end
            dxDrawRectangle(x + 2, y + 2, healthWidth, height - 4, tocolor(200, 0, 0, 255))
            
            dxDrawText(titleText, x, y - 25, x + width, y, tocolor(255, 255, 255, 255), 1.5, "default-bold", "center", "bottom")
            dxDrawText(math.floor(hp) .. " / " .. math.floor(maxHp), x, y, x + width, y + height, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")
            
        elseif count > 1 then
            local px, py, pz = getElementPosition(localPlayer)
            local pDim = getElementDimension(localPlayer)
            local pInt = getElementInterior(localPlayer)
            
            for i, ent in ipairs(activeEntities) do
                if getElementDimension(ent) == pDim and getElementInterior(ent) == pInt then
                    local ex, ey, ez = getElementPosition(ent)
                    local dist = getDistanceBetweenPoints3D(px, py, pz, ex, ey, ez)
                    
                    if dist < 40.0 then 
                        local eType = getElementData(ent, "eType") or "Ped"
                        local zOffset = (eType == "Car") and 1.5 or 1.1
                        local sx, sy = getScreenFromWorldPosition(ex, ey, ez + zOffset)
                        if sx and sy then
                            local hp = getElementData(ent, "bossHealth") or 0
                            local maxHp = getElementData(ent, "maxBossHealth") or 1
                            
                            local width, height = 80, 8
                            local drawX = sx - width / 2
                            local drawY = sy
                            
                            dxDrawRectangle(drawX, drawY, width, height, tocolor(0, 0, 0, 180))
                            local healthWidth = (width - 2) * (hp / maxHp)
                            if healthWidth < 0 then healthWidth = 0 end
                            dxDrawRectangle(drawX + 1, drawY + 1, healthWidth, height - 2, tocolor(200, 0, 0, 255))
                            
                            dxDrawText(titleText, drawX, drawY - 18, drawX + width, drawY, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "bottom")
                        end
                    end
                end
            end
        end
    end
end)