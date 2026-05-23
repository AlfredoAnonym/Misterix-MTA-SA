-- carrec_c.lua
local screenW, screenH = guiGetScreenSize()
local isRecording = false
local isWaitingForRecord = false
local recordingData = {}
local recordingStartTime = 0
local recordingVehicle = nil
local lastNodeTick = 0

local playbackActive = false
local playbackData = {}
local playbackStartTime = 0
local playbackVehicle = nil
local playbackDriver = nil -- Visible AI Driver
local playbackIndex = 1
local currentPlaybackName = ""

-- Tracking state chains for routes
local currentRouteCategory = "None"
local currentLinkedRoute = ""
local pathMetadataCache = {}
local availableMyths = {} -- Stores myths from mysteries.db

-- Taxi Additions
local taxiArrow = nil
local taxiBlip = nil
local showTaxiWaitScreen = false
local taxiWaitStartTick = 0

-- State tracking for our "Fake Passenger" bypass
local isPlayerInFakeTaxi = false 

-- Table to keep track of spawned client-side clone peds inside our vehicle seats
local fakePassengerPeds = {}

local showCinematic = false
local cinematicStartTick = 0
local skipStatusText = ""

-- Main GUI Layout
local wndMain = guiCreateWindow(0.3, 0.3, 0.4, 0.4, "Carrec Path Manager", true)
guiWindowSetSizable(wndMain, false)
guiSetVisible(wndMain, false)

local gridPaths = guiCreateGridList(0.05, 0.1, 0.9, 0.6, true, wndMain)
guiGridListAddColumn(gridPaths, "Recording Name", 0.9)

local btnRecord = guiCreateButton(0.05, 0.75, 0.3, 0.1, "RECORD", true, wndMain)
local btnPlay = guiCreateButton(0.35, 0.75, 0.3, 0.1, "PLAY RECORDING", true, wndMain)
local btnDelete = guiCreateButton(0.65, 0.75, 0.3, 0.1, "DELETE", true, wndMain)

local btnEdit = guiCreateButton(0.05, 0.88, 0.42, 0.08, "EDIT ROUTE", true, wndMain)
local btnClose = guiCreateButton(0.53, 0.88, 0.42, 0.08, "Close", true, wndMain)

-- Save Prompt GUI
local wndSave = guiCreateWindow(0.4, 0.4, 0.2, 0.2, "Save Recording", true)
guiWindowSetSizable(wndSave, false)
guiSetVisible(wndSave, false)
local lblSave = guiCreateLabel(0.05, 0.2, 0.9, 0.2, "Enter a name for this path:", true, wndSave)
local editSave = guiCreateEdit(0.05, 0.4, 0.9, 0.2, "", true, wndSave)
local btnConfirmSave = guiCreateButton(0.05, 0.7, 0.4, 0.2, "Save", true, wndSave)
local btnCancelSave = guiCreateButton(0.55, 0.7, 0.4, 0.2, "Discard", true, wndSave)

-- Route Chaining Configuration GUI
local wndEdit = guiCreateWindow(0.35, 0.22, 0.3, 0.56, "Edit Route Properties", true)
guiWindowSetSizable(wndEdit, false)
guiSetVisible(wndEdit, false)
local lblEditName = guiCreateLabel(0.05, 0.05, 0.9, 0.05, "Selected: None", true, wndEdit)
local lblCategory = guiCreateLabel(0.05, 0.12, 0.9, 0.05, "Assign Route Category:", true, wndEdit)
local cmbCategory = guiCreateComboBox(0.05, 0.18, 0.9, 0.25, "Select Category", true, wndEdit)
guiComboBoxAddItem(cmbCategory, "None")
guiComboBoxAddItem(cmbCategory, "Airport Route")
guiComboBoxAddItem(cmbCategory, "Destination Route")
guiComboBoxAddItem(cmbCategory, "Leaving Route")
guiComboBoxAddItem(cmbCategory, "Skippable Route Sequence")

local lblLink = guiCreateLabel(0.05, 0.34, 0.9, 0.05, "Linked Next Route Sequence(s):", true, wndEdit)
local gridLink = guiCreateGridList(0.05, 0.39, 0.9, 0.16, true, wndEdit)
guiGridListSetSelectionMode(gridLink, 1) -- 1 = Multiple Selection Mode
guiGridListAddColumn(gridLink, "Select Linked Route(s)", 0.9)

local lblMyth = guiCreateLabel(0.05, 0.56, 0.9, 0.05, "Associated Misterix Myth Name(s):", true, wndEdit)
local gridMyth = guiCreateGridList(0.05, 0.62, 0.9, 0.20, true, wndEdit)
guiGridListSetSelectionMode(gridMyth, 1) -- 1 = Multiple Selection Mode
guiGridListAddColumn(gridMyth, "Select Myth(s)", 0.9)

local btnSaveEdit = guiCreateButton(0.05, 0.84, 0.42, 0.10, "Save Settings", true, wndEdit)
local btnCancelEdit = guiCreateButton(0.53, 0.84, 0.42, 0.10, "Cancel", true, wndEdit)

-- Sync data automatically on initialization so cache is never empty after a script restart
addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("onClientRequestPathList", localPlayer)
end)

-- Toggle Menu
bindKey("F5", "down", function()
    if guiGetVisible(wndSave) or guiGetVisible(wndEdit) then return end
    local state = not guiGetVisible(wndMain)
    guiSetVisible(wndMain, state)
    showCursor(state)
    if state then
        triggerServerEvent("onClientRequestPathList", localPlayer)
    end
end)

addEventHandler("onClientGUIClick", btnClose, function(b)
    if b == "left" then
        guiSetVisible(wndMain, false)
        showCursor(false)
    end
end, false)

-- Receiving List
addEvent("onServerSendPathList", true)
addEventHandler("onServerSendPathList", root, function(paths, myths)
    guiGridListClear(gridPaths)
    pathMetadataCache = {}
    for i, pathInfo in ipairs(paths) do
        local row = guiGridListAddRow(gridPaths)
        local displayString = pathInfo.name .. " (" .. pathInfo.category .. ")"
        guiGridListSetItemText(gridPaths, row, 1, displayString, false, false)
        guiGridListSetItemData(gridPaths, row, 1, pathInfo.name)
        
        pathMetadataCache[pathInfo.name] = {
            category = pathInfo.category,
            linked_route = pathInfo.linked_route,
            myth = pathInfo.myth or ""
        }
    end
    availableMyths = myths or {}
end)

-- Open Edit Window Flow
addEventHandler("onClientGUIClick", btnEdit, function(b, s)
    if b == "left" and s == "up" then
        local row = guiGridListGetSelectedItem(gridPaths)
        if row == -1 then return outputChatBox("Please select a recording from the list to edit.", 255, 0, 0) end
        
        local rawName = guiGridListGetItemData(gridPaths, row, 1)
        local meta = pathMetadataCache[rawName] or { category = "None", linked_route = "", myth = "" }
        
        guiSetText(lblEditName, "Selected: " .. rawName)
        guiSetVisible(wndMain, false)
        guiSetVisible(wndEdit, true)
        
        if meta.category == "Airport Route" then guiComboBoxSetSelected(cmbCategory, 1)
        elseif meta.category == "Destination Route" then guiComboBoxSetSelected(cmbCategory, 2)
        elseif meta.category == "Leaving Route" then guiComboBoxSetSelected(cmbCategory, 3)
        elseif meta.category == "Skippable Route Sequence" then guiComboBoxSetSelected(cmbCategory, 4)
        else guiComboBoxSetSelected(cmbCategory, 0) end
        
        -- Populate Path Links (Multi-select)
        guiGridListClear(gridLink)
        local associatedLinks = split(meta.linked_route or "", ",")
        local totalRows = guiGridListGetRowCount(gridPaths)
        for i = 0, totalRows - 1 do
            local loopsName = guiGridListGetItemData(gridPaths, i, 1)
            local mRow = guiGridListAddRow(gridLink)
            guiGridListSetItemText(gridLink, mRow, 1, loopsName, false, false)
            for _, al in ipairs(associatedLinks) do
                if al == loopsName then
                    guiGridListSetSelectedItem(gridLink, mRow, 1, false) -- Keep other selections active
                end
            end
        end
        
        -- Populate Myth GridList (Multi-select)
        guiGridListClear(gridMyth)
        local associatedMyths = split(meta.myth or "", ",")
        for _, mythName in ipairs(availableMyths) do
            local mRow = guiGridListAddRow(gridMyth)
            guiGridListSetItemText(gridMyth, mRow, 1, mythName, false, false)
            for _, am in ipairs(associatedMyths) do
                if am == mythName then
                    guiGridListSetSelectedItem(gridMyth, mRow, 1, false) -- Keep other selections active
                end
            end
        end
    end
end, false)

addEventHandler("onClientGUIClick", btnCancelEdit, function(b, s)
    if b == "left" and s == "up" then
        guiSetVisible(wndEdit, false)
        guiSetVisible(wndMain, true)
    end
end, false)

addEventHandler("onClientGUIClick", btnSaveEdit, function(b, s)
    if b == "left" and s == "up" then
        local row = guiGridListGetSelectedItem(gridPaths)
        if row == -1 then return end
        local rawName = guiGridListGetItemData(gridPaths, row, 1)
        
        local catIdx = guiComboBoxGetSelected(cmbCategory)
        local category = "None"
        if catIdx == 1 then category = "Airport Route"
        elseif catIdx == 2 then category = "Destination Route"
        elseif catIdx == 3 then category = "Leaving Route"
        elseif catIdx == 4 then category = "Skippable Route Sequence" end
        
        local selectedLinks = {}
        local selLinkItems = guiGridListGetSelectedItems(gridLink)
        for _, item in ipairs(selLinkItems) do
            local text = guiGridListGetItemText(gridLink, item.row, 1)
            table.insert(selectedLinks, text)
        end
        local linkedRoute = table.concat(selectedLinks, ",")
        
        local selectedMyths = {}
        local selectedItems = guiGridListGetSelectedItems(gridMyth)
        for _, item in ipairs(selectedItems) do
            local text = guiGridListGetItemText(gridMyth, item.row, 1)
            table.insert(selectedMyths, text)
        end
        local myth = table.concat(selectedMyths, ",")
        
        triggerServerEvent("onClientUpdatePathSettings", localPlayer, rawName, category, linkedRoute, myth)
        guiSetVisible(wndEdit, false)
        guiSetVisible(wndMain, true)
    end
end, false)

-- Start Recording Flow
addEventHandler("onClientGUIClick", btnRecord, function(b, s)
    if b == "left" and s == "up" then
        guiSetVisible(wndMain, false)
        showCursor(false)
        isWaitingForRecord = true
        showCinematic = true
        cinematicStartTick = getTickCount()
        outputChatBox("Get in a vehicle and press 'R' to start recording.", 255, 200, 0)
    end
end, false)

bindKey("R", "down", function()
    if isWaitingForRecord and not isRecording then
        local veh = getPedOccupiedVehicle(localPlayer)
        if veh then
            isWaitingForRecord = false
            isRecording = true
            recordingVehicle = veh
            recordingData = {}
            recordingStartTime = getTickCount()
            lastNodeTick = 0
            
            table.insert(recordingData, {
                model = getElementModel(veh),
                time = 0,
                x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0
            })
            
            outputChatBox("Recording STARTED! Press 'R' again to stop.", 255, 0, 0)
        else
            outputChatBox("You must be inside a vehicle to record a path!", 255, 0, 0)
        end
    elseif isRecording then
        isRecording = false
        outputChatBox("Recording STOPPED.", 255, 0, 0)
        
        guiSetVisible(wndSave, true)
        showCursor(true)
        guiSetInputEnabled(true) 
        guiSetText(editSave, "")
    end
end)

addEventHandler("onClientGUIClick", btnConfirmSave, function(b, s)
    if b == "left" and s == "up" then
        local name = guiGetText(editSave)
        if name ~= "" then
            triggerServerEvent("onClientSavePath", localPlayer, name, recordingData)
            guiSetVisible(wndSave, false)
            showCursor(false)
            guiSetInputEnabled(false) 
            recordingData = {}
        else
            outputChatBox("Please enter a valid name.", 255, 0, 0)
        end
    end
end, false)

addEventHandler("onClientGUIClick", btnCancelSave, function(b, s)
    if b == "left" and s == "up" then
        guiSetVisible(wndSave, false)
        showCursor(false)
        guiSetInputEnabled(false)
        recordingData = {}
        outputChatBox("Recording discarded.", 255, 100, 100)
    end
end, false)

addEventHandler("onClientGUIClick", btnDelete, function(b, s)
    if b == "left" and s == "up" then
        local row = guiGridListGetSelectedItem(gridPaths)
        if row ~= -1 then
            local rawName = guiGridListGetItemData(gridPaths, row, 1)
            triggerServerEvent("onClientDeletePath", localPlayer, rawName)
        end
    end
end, false)

addEventHandler("onClientGUIClick", btnPlay, function(b, s)
    if b == "left" and s == "up" then
        local row = guiGridListGetSelectedItem(gridPaths)
        if row ~= -1 then
            local rawName = guiGridListGetItemData(gridPaths, row, 1)
            triggerServerEvent("onClientRequestPlayback", localPlayer, rawName)
            guiSetVisible(wndMain, false)
            showCursor(false)
        end
    end
end, false)

addEvent("onServerSendPlaybackData", true)
addEventHandler("onServerSendPlaybackData", root, function(data, category, linkedRoute, pathName)
    if not data or #data < 2 then 
        return outputChatBox("Recording is empty or invalid.", 255, 0, 0) 
    end
    
    playbackData = data
    currentRouteCategory = category or "None"
    currentLinkedRoute = linkedRoute or ""
    currentPlaybackName = pathName or ""
    skipStatusText = "" -- Reset skip votes on path play
    
    local setupNode = playbackData[1]
    
    local function startTaxiPlayback()
        if isElement(playbackVehicle) then
            setElementPosition(playbackVehicle, setupNode.x, setupNode.y, setupNode.z)
            setElementVelocity(playbackVehicle, 0, 0, 0)
            if isElement(playbackDriver) then destroyElement(playbackDriver) end
        else
            playbackVehicle = createVehicle(setupNode.model, setupNode.x, setupNode.y, setupNode.z)
            setElementDimension(playbackVehicle, getElementDimension(localPlayer))
            setElementInterior(playbackVehicle, getElementInterior(localPlayer))
        end
        
        setElementCollisionsEnabled(playbackVehicle, false)
        setElementAlpha(playbackVehicle, 255) 
        
        playbackDriver = createPed(189, setupNode.x, setupNode.y, setupNode.z)
        setElementAlpha(playbackDriver, 255)
        
        warpPedIntoVehicle(playbackDriver, playbackVehicle)
        
        setElementDimension(playbackDriver, getElementDimension(localPlayer))
        setElementInterior(playbackDriver, getElementInterior(localPlayer))
        
        -- Setup Taxi Indicators (Arrow & Radar Blip) - Ignore for Leaving Route
        if currentRouteCategory ~= "Leaving Route" then
            if not isElement(taxiArrow) then
                taxiArrow = createMarker(0, 0, 0, "arrow", 1.5, 0, 150, 255, 255)
                attachElements(taxiArrow, playbackVehicle, 0, 0, 2.5)
                setElementDimension(taxiArrow, getElementDimension(localPlayer))
                setElementInterior(taxiArrow, getElementInterior(localPlayer))
            end
            
            if not isElement(taxiBlip) then
                taxiBlip = createBlipAttachedTo(playbackVehicle, 0, 2, 0, 150, 255, 255)
                setElementDimension(taxiBlip, getElementDimension(localPlayer))
                setElementInterior(taxiBlip, getElementInterior(localPlayer))
            end
        end
        
        playbackActive = true
        playbackStartTime = getTickCount()
        playbackIndex = 1
    end
    
    -- Setup visual delay EXCLUSIVELY for the initial arrival of the taxi
    if currentRouteCategory == "Airport Route" then
        showTaxiWaitScreen = true
        taxiWaitStartTick = getTickCount()
        playbackActive = false
        
        setTimer(startTaxiPlayback, 3500, 1)
    else
        -- If Destination Route or Leaving Route, skip the text delay completely
        startTaxiPlayback()
    end
end)

local function getShortestAngle(angle1, angle2)
    local diff = (angle2 - angle1) % 360
    if diff > 180 then diff = diff - 360
    elseif diff < -180 then diff = diff + 360 end
    return angle1 + diff
end

local function clearAllFakePassengers()
    for element, ped in pairs(fakePassengerPeds) do
        if isElement(ped) then destroyElement(ped) end
    end
    fakePassengerPeds = {}
end

local function updateFakePassengerPeds()
    if not isElement(playbackVehicle) then 
        clearAllFakePassengers()
        return 
    end
    
    -- 1. Render Local Player Fake Clone Ped
    if isPlayerInFakeTaxi then
        if not fakePassengerPeds[localPlayer] or not isElement(fakePassengerPeds[localPlayer]) then
            local fakePed = createPed(getElementModel(localPlayer), 0, 0, 0)
            setElementDimension(fakePed, getElementDimension(playbackVehicle))
            setElementInterior(fakePed, getElementInterior(playbackVehicle))
            
            for slot = 0, 17 do
                local texture, model = getPedClothes(localPlayer, slot)
                if texture then
                    addPedClothes(fakePed, texture, model, slot)
                end
            end
            warpPedIntoVehicle(fakePed, playbackVehicle, 1) 
            fakePassengerPeds[localPlayer] = fakePed
        end
    else
        if fakePassengerPeds[localPlayer] then
            if isElement(fakePassengerPeds[localPlayer]) then destroyElement(fakePassengerPeds[localPlayer]) end
            fakePassengerPeds[localPlayer] = nil
        end
    end
    
    -- 2. Render Real Co-op Friends/Partners Fake Clone Peds (Party Sync Fix)
    local myLeader = getElementData(localPlayer, "missionPartyLeader") or localPlayer
    for _, playerFriend in ipairs(getElementsByType("player", root, true)) do
        local theirLeader = getElementData(playerFriend, "missionPartyLeader") or playerFriend
        if playerFriend ~= localPlayer and myLeader == theirLeader then
            if getElementData(playerFriend, "in_fake_taxi") then
                if not fakePassengerPeds[playerFriend] or not isElement(fakePassengerPeds[playerFriend]) then
                    local fakePed = createPed(getElementModel(playerFriend), 0, 0, 0)
                    setElementDimension(fakePed, getElementDimension(playbackVehicle))
                    setElementInterior(fakePed, getElementInterior(playbackVehicle))
                    
                    for slot = 0, 17 do
                        local texture, model = getPedClothes(playerFriend, slot)
                        if texture then
                            addPedClothes(fakePed, texture, model, slot)
                        end
                    end
                    local seat = 2
                    if getVehicleOccupant(playbackVehicle, 2) then seat = 3 end
                    warpPedIntoVehicle(fakePed, playbackVehicle, seat)
                    fakePassengerPeds[playerFriend] = fakePed
                end
            else
                if fakePassengerPeds[playerFriend] then
                    if isElement(fakePassengerPeds[playerFriend]) then destroyElement(fakePassengerPeds[playerFriend]) end
                    fakePassengerPeds[playerFriend] = nil
                end
            end
        end
    end
    
    for pl, ped in pairs(fakePassengerPeds) do
        if pl ~= localPlayer and (not isElement(pl) or not getElementData(pl, "in_fake_taxi")) then
            if isElement(ped) then destroyElement(ped) end
            fakePassengerPeds[pl] = nil
        end
    end
end

-- Re-upgraded Helper function with bulletproof string manipulation
local function determineNextLinkedRoute()
    if not currentLinkedRoute or currentLinkedRoute == "" then return nil end
    
    local activeMythName = ""
    local leader = getElementData(localPlayer, "missionPartyLeader") or localPlayer
    local aMission = getElementData(leader, "activeMissionData")
    if aMission and aMission.name then activeMythName = aMission.name end

    local routes = split(currentLinkedRoute, ",")
    if #routes == 1 then return routes[1] end
    
    local cleanActiveMyth = string.lower(string.gsub(activeMythName, "[%s_]", ""))
    if cleanActiveMyth == "" then return routes[1] end

    -- Tier 1: Match directly via destination path's metadata settings
    for _, rName in ipairs(routes) do
        local meta = pathMetadataCache[rName]
        if meta and meta.myth and meta.myth ~= "" then
            local routeMyths = split(meta.myth, ",")
            for _, mName in ipairs(routeMyths) do
                local cleanMName = string.lower(string.gsub(mName, "[%s_]", ""))
                if cleanMName == cleanActiveMyth then
                    return rName
                end
            end
        end
    end
    
    -- Tier 2: Smart fallback (Perform intelligent keyword containment search on file/path names)
    for _, rName in ipairs(routes) do
        local cleanRouteName = string.lower(string.gsub(rName, "[%s_]", ""))
        if string.find(cleanRouteName, cleanActiveMyth, 1, true) or string.find(cleanActiveMyth, cleanRouteName, 1, true) then
            return rName
        end
    end
    
    return routes[1] -- fallback to first entry if absolutely no intelligent matches can be correlated
end

-- Smart Passenger Gathering System (Misterix Companions & Party Members)
local function checkPassengersAndProceed()
    if not isElement(playbackVehicle) then return end
    if not isPlayerInFakeTaxi then return end
    
    local passengersReady = true
    
    -- Check AI companions
    for _, ped in ipairs(getElementsByType("ped", root, true)) do
        if ped ~= localPlayer and (getElementData(ped, "misterix_companion") or getElementData(ped, "isFriend") or getElementData(ped, "companion")) then
            if not getElementData(ped, "fake_taxi_passenger") then
                local px, py, pz = getElementPosition(ped)
                local vx, vy, vz = getElementPosition(playbackVehicle)
                local dist = getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz)
                
                if dist < 25 then
                    if dist < 5 then
                        attachElements(ped, playbackVehicle, 0, 0, 0.5)
                        setElementAlpha(ped, 0)
                        setElementCollisionsEnabled(ped, false)
                        setElementData(ped, "fake_taxi_passenger", true, false)
                    else
                        passengersReady = false 
                    end
                end
            end
        end
    end
    
    -- Check human party members (Party Sync Fix)
    local myLeader = getElementData(localPlayer, "missionPartyLeader") or localPlayer
    for _, playerFriend in ipairs(getElementsByType("player", root, true)) do
        local theirLeader = getElementData(playerFriend, "missionPartyLeader") or playerFriend
        if playerFriend ~= localPlayer and myLeader == theirLeader then
            local px, py, pz = getElementPosition(playerFriend)
            local vx, vy, vz = getElementPosition(playbackVehicle)
            if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) < 30.0 then -- Increased range to wait for nearby friends
                if not getElementData(playerFriend, "in_fake_taxi") then
                    passengersReady = false
                    break
                end
            end
        end
    end
    
    if not passengersReady then
        setTimer(checkPassengersAndProceed, 1000, 1) 
        return
    end
    
    fadeCamera(false, 1.5)
    setTimer(function()
        if not isElement(playbackVehicle) then return end
        fadeCamera(true, 1.5)
        
        local nextRoute = determineNextLinkedRoute()
        if nextRoute and nextRoute ~= "" then
            triggerServerEvent("onClientRequestPlayback", localPlayer, nextRoute)
        else
            outputChatBox("Route Error: No valid Destination Route chained to this Airport path for this myth!", 255, 0, 0)
        end
    end, 2000, 1)
end

-- Smart Empty Exit Check before leaving
local function checkExitAndLeave()
    if not isElement(playbackVehicle) then return end
    if isPlayerInFakeTaxi then return end
    
    local emptyOfCustomers = true
    
    for _, ped in ipairs(getElementsByType("ped", root, true)) do
        if getElementData(ped, "fake_taxi_passenger") then 
            if getElementData(ped, "misterix_companion") or getElementData(ped, "isFriend") or getElementData(ped, "companion") then
                detachElements(ped)
                setElementAlpha(ped, 255)
                setElementCollisionsEnabled(ped, true)
                local vx, vy, vz = getElementPosition(playbackVehicle)
                setElementPosition(ped, vx - 3, vy + 3, vz + 0.5) 
                setElementData(ped, "fake_taxi_passenger", nil, false)
            else
                emptyOfCustomers = false 
            end
        end
    end
    
    for _, pl in ipairs(getElementsByType("player", root, true)) do
        if getElementData(pl, "in_fake_taxi") then
            emptyOfCustomers = false 
            break 
        end
    end
    
    if not emptyOfCustomers then
        setTimer(checkExitAndLeave, 1000, 1)
        return
    end
    
    local nextRoute = determineNextLinkedRoute()
    if nextRoute and nextRoute ~= "" then
        triggerServerEvent("onClientRequestPlayback", localPlayer, nextRoute)
    else
        if isElement(playbackVehicle) then destroyElement(playbackVehicle) end
        if isElement(taxiArrow) then destroyElement(taxiArrow) end
        if isElement(taxiBlip) then destroyElement(taxiBlip) end
        clearAllFakePassengers()
        currentRouteCategory = "None"
    end
end

-- Custom Entry/Exit interceptor using Fake Passenger Attachment Tricks
local function handleTaxiInteractions(key, keyState)
    if not isElement(playbackVehicle) then return end
    
    if isPlayerInFakeTaxi then
        if currentRouteCategory == "WaitingToLeave" then
            isPlayerInFakeTaxi = false
            setElementData(localPlayer, "in_fake_taxi", nil, true) 
            detachElements(localPlayer)
            setElementAlpha(localPlayer, 255)
            setElementCollisionsEnabled(localPlayer, true)
            setCameraTarget(localPlayer) 
            
            local x, y, z = getElementPosition(playbackVehicle)
            setElementPosition(localPlayer, x - 3, y + 3, z + 0.5) 
            setTimer(checkExitAndLeave, 500, 1)
        else
            outputChatBox("Please wait until the taxi stops at the destination to exit!", 255, 100, 0)
        end
        return
    end
    
    if currentRouteCategory == "Airport Route" then
        local px, py, pz = getElementPosition(localPlayer)
        local vx, vy, vz = getElementPosition(playbackVehicle)
        
        if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 5 then
            isPlayerInFakeTaxi = true
            setElementData(localPlayer, "in_fake_taxi", true, true) 
            
            attachElements(localPlayer, playbackVehicle, 0, 0, 0.5)
            setElementAlpha(localPlayer, 0)
            setElementCollisionsEnabled(localPlayer, false)
            
            setCameraTarget(playbackVehicle)
            setTimer(checkPassengersAndProceed, 500, 1)
        end
    end
end

bindKey("enter_exit", "down", handleTaxiInteractions)
bindKey("enter_passenger", "down", handleTaxiInteractions)

addEvent("onClientUpdateSkipStatus", true)
addEventHandler("onClientUpdateSkipStatus", root, function(statusText)
    skipStatusText = statusText or ""
end)

addEvent("onClientFadeOutAndStartSkip", true)
addEventHandler("onClientFadeOutAndStartSkip", root, function(data, category, linkedRoute, pathName)
    fadeCamera(false, 1.0)
    setTimer(function()
        if not data or #data < 2 then return end
        
        playbackData = data
        currentRouteCategory = category or "None"
        currentLinkedRoute = linkedRoute or ""
        currentPlaybackName = pathName or ""
        playbackActive = true
        playbackStartTime = getTickCount()
        playbackIndex = 1
        skipStatusText = ""
        
        local setupNode = playbackData[1]
        if isElement(playbackVehicle) then
            setElementPosition(playbackVehicle, setupNode.x, setupNode.y, setupNode.z)
            setElementVelocity(playbackVehicle, 0, 0, 0)
            setElementRotation(playbackVehicle, setupNode.rx, setupNode.ry, setupNode.rz, "ZXY")
            
            if currentRouteCategory == "Leaving Route" then
                if isElement(taxiArrow) then destroyElement(taxiArrow) end
                if isElement(taxiBlip) then destroyElement(taxiBlip) end
            else
                if not isElement(taxiArrow) then
                    taxiArrow = createMarker(0, 0, 0, "arrow", 1.5, 0, 150, 255, 255)
                    attachElements(taxiArrow, playbackVehicle, 0, 0, 2.5)
                    setElementDimension(taxiArrow, getElementDimension(localPlayer))
                    setElementInterior(taxiArrow, getElementInterior(localPlayer))
                end
                if not isElement(taxiBlip) then
                    taxiBlip = createBlipAttachedTo(playbackVehicle, 0, 2, 0, 150, 255, 255)
                    setElementDimension(taxiBlip, getElementDimension(localPlayer))
                    setElementInterior(taxiBlip, getElementInterior(localPlayer))
                end
            end
        end
        
        fadeCamera(true, 1.0)
    end, 1100, 1)
end)

-- Keybind for Skip Drive
bindKey("X", "down", function()
    if isPlayerInFakeTaxi and currentRouteCategory == "Destination Route" then
        triggerServerEvent("onServerRequestSkipDrive", localPlayer)
    end
end)

-- Screen Click handler for Skip Drive
addEventHandler("onClientClick", root, function(button, state, absoluteX, absoluteY)
    if button == "left" and state == "down" then
        if isPlayerInFakeTaxi and currentRouteCategory == "Destination Route" then
            if absoluteY >= screenH - 100 then
                triggerServerEvent("onServerRequestSkipDrive", localPlayer)
            end
        end
    end
end)

addEventHandler("onClientRender", root, function()
    updateFakePassengerPeds() 

    if showCinematic then
        local elapsed = getTickCount() - cinematicStartTick
        if elapsed < 3500 then
            dxDrawRectangle(0, 0, screenW, 100, tocolor(0, 0, 0, 255))
            dxDrawRectangle(0, screenH - 100, screenW, 100, tocolor(0, 0, 0, 255))
            dxDrawText("Get in a vehicle and press 'R' to start recording.", 0, screenH - 100, screenW, screenH, tocolor(255, 255, 255, 255), 1.5, "default-bold", "center", "center")
        else
            showCinematic = false
        end
    end

    -- Delay UI for the taxi
    if showTaxiWaitScreen then
        local elapsed = getTickCount() - taxiWaitStartTick
        if elapsed < 3500 then
            local boxH = 60
            dxDrawRectangle(0, (screenH / 2) - (boxH / 2), screenW, boxH, tocolor(0, 0, 0, 200))
            dxDrawText("Taxi is on the way, wait for few seconds", 0, (screenH / 2) - (boxH / 2), screenW, (screenH / 2) + (boxH / 2), tocolor(255, 255, 255, 255), 1.5, "default-bold", "center", "center")
        else
            showTaxiWaitScreen = false
        end
    end

    -- Rendering Black Bars text when Destination Route is skippable
    if isPlayerInFakeTaxi and currentRouteCategory == "Destination Route" then
        dxDrawRectangle(0, 0, screenW, 100, tocolor(0, 0, 0, 255))
        dxDrawRectangle(0, screenH - 100, screenW, 100, tocolor(0, 0, 0, 255))
        
        local txt = "Press 'X' or Click here to Skip Drive"
        if skipStatusText ~= "" then
            txt = "Skip Drive: " .. skipStatusText
        end
        dxDrawText(txt, 0, screenH - 100, screenW, screenH, tocolor(255, 255, 0, 255), 1.5, "default-bold", "center", "center")
    end

    if isRecording and isElement(recordingVehicle) then
        local currentTick = getTickCount()
        if currentTick - lastNodeTick >= 100 then
            local x, y, z = getElementPosition(recordingVehicle)
            local rx, ry, rz = getElementRotation(recordingVehicle)
            local timeOffset = currentTick - recordingStartTime
            
            table.insert(recordingData, {
                time = timeOffset,
                x = x, y = y, z = z,
                rx = rx, ry = ry, rz = rz
            })
            lastNodeTick = currentTick
        end
    end

    if playbackActive and isElement(playbackVehicle) then
        local currentTick = getTickCount() - playbackStartTime
        
        while playbackData[playbackIndex + 1] and currentTick >= playbackData[playbackIndex + 1].time do
            playbackIndex = playbackIndex + 1
        end
        
        local node1 = playbackData[playbackIndex]
        local node2 = playbackData[playbackIndex + 1]
        
        if node2 then
            local progress = (currentTick - node1.time) / (node2.time - node1.time)
            if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end
            
            local ix, iy, iz = interpolateBetween(node1.x, node1.y, node1.z, node2.x, node2.y, node2.z, progress, "Linear")
            local targetRx = getShortestAngle(node1.rx, node2.rx)
            local targetRy = getShortestAngle(node1.ry, node2.ry)
            local targetRz = getShortestAngle(node1.rz, node2.rz)
            
            local irx, iry, irz = interpolateBetween(node1.rx, node1.ry, node1.rz, targetRx, targetRy, targetRz, progress, "Linear")
            
            setElementPosition(playbackVehicle, ix, iy, iz)
            
            local timeDiff = (node2.time - node1.time) / 1000
            if timeDiff > 0 then
                local vx = ((node2.x - node1.x) / timeDiff) / 50
                local vy = ((node2.y - node1.y) / timeDiff) / 50
                local vz = ((node2.z - node1.z) / timeDiff) / 50
                setElementVelocity(playbackVehicle, vx, vy, vz)
            end
            
            setElementRotation(playbackVehicle, irx, iry, irz, "ZXY")
            
            if isElement(playbackDriver) then
                local targetRot = math.deg(math.atan2(node2.y - node1.y, node2.x - node1.x)) - 90
                if targetRot < 0 then targetRot = targetRot + 360 end
                
                local diff = targetRot - irz
                while diff < -180 do diff = diff + 360 end
                while diff > 180 do diff = diff - 360 end
                
                setPedControlState(playbackDriver, "accelerate", true)
                
                if diff > 10 then
                    setPedControlState(playbackDriver, "vehicle_left", true)
                    setPedControlState(playbackDriver, "vehicle_right", false)
                elseif diff < -10 then
                    setPedControlState(playbackDriver, "vehicle_left", false)
                    setPedControlState(playbackDriver, "vehicle_right", true)
                else
                    setPedControlState(playbackDriver, "vehicle_left", false)
                    setPedControlState(playbackDriver, "vehicle_right", false)
                end
            end
        else
            playbackActive = false
            if isElement(playbackDriver) then destroyElement(playbackDriver) end
            
            if currentRouteCategory == "Airport Route" then
                setElementAlpha(playbackVehicle, 255)
                setElementCollisionsEnabled(playbackVehicle, true)
                setElementVelocity(playbackVehicle, 0, 0, 0)
                outputChatBox("Taxi has arrived! Press ENTER near the car to begin travel.", 0, 255, 0)
                
            elseif currentRouteCategory == "Destination Route" or currentRouteCategory == "Skippable Route Sequence" then
                setElementAlpha(playbackVehicle, 255)
                setElementCollisionsEnabled(playbackVehicle, true)
                setElementVelocity(playbackVehicle, 0, 0, 0)
                currentRouteCategory = "WaitingToLeave"
                outputChatBox("You have arrived at your destination! Press ENTER to exit the vehicle.", 0, 255, 0)
                
            else
                if isElement(playbackVehicle) then destroyElement(playbackVehicle) end
                
                if isPlayerInFakeTaxi then
                    isPlayerInFakeTaxi = false
                    setElementData(localPlayer, "in_fake_taxi", nil, true)
                    detachElements(localPlayer)
                    setElementAlpha(localPlayer, 255)
                    setElementCollisionsEnabled(localPlayer, true)
                    setCameraTarget(localPlayer)
                end
                
                if isElement(taxiArrow) then destroyElement(taxiArrow) end
                if isElement(taxiBlip) then destroyElement(taxiBlip) end
                
                clearAllFakePassengers()
                currentRouteCategory = "None"
                currentLinkedRoute = ""
            end
        end
    end
end)