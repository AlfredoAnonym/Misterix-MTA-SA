-- carrec_s.lua

local db = dbConnect("sqlite", ":/carrec_paths.db")
local mysteriesDB = dbConnect("sqlite", "mysteries.db") -- Load myths database
local skipVotes = {}

addEventHandler("onResourceStart", resourceRoot, function()
    if db then
        dbExec(db, "CREATE TABLE IF NOT EXISTS vehicle_paths (name TEXT PRIMARY KEY, data TEXT, category TEXT, linked_route TEXT)")
        
        local query = dbQuery(db, "PRAGMA table_info(vehicle_paths)")
        local result = dbPoll(query, -1)
        local hasCategory, hasLinkedRoute, hasMyth = false, false, false
        
        if result then
            for _, row in ipairs(result) do
                if row.name == "category" then hasCategory = true end
                if row.name == "linked_route" then hasLinkedRoute = true end
                if row.name == "myth" then hasMyth = true end
            end
        end
        if not hasCategory then dbExec(db, "ALTER TABLE vehicle_paths ADD COLUMN category TEXT") end
        if not hasLinkedRoute then dbExec(db, "ALTER TABLE vehicle_paths ADD COLUMN linked_route TEXT") end
        if not hasMyth then dbExec(db, "ALTER TABLE vehicle_paths ADD COLUMN myth TEXT") end
    else
        outputDebugString("CARREC CRITICAL ERROR: MTA completely blocked SQLite connection!")
    end
end)

local function playPathForPlayer(player, pathName)
    if not db or not isElement(player) then return false end
    local safeName = string.gsub(pathName, "[^%w_]", "")
    local query = dbQuery(db, "SELECT data, category, linked_route FROM vehicle_paths WHERE name = ?", safeName)
    local result = dbPoll(query, -1)
    
    if result and result[1] then
        local pathData = fromJSON(result[1].data)
        local category = result[1].category or "None"
        local linkedRoute = result[1].linked_route or ""
        
        -- Co-op Sync Matrix: Party members in the SAME ISOLATED DIMENSION within 30 meters
        local px, py, pz = getElementPosition(player)
        local pDim = getElementDimension(player)
        local targets = { player }
        local myLeader = getElementData(player, "missionPartyLeader") or player
        
        for _, pl in ipairs(getElementsByType("player")) do
            local theirLeader = getElementData(pl, "missionPartyLeader") or pl
            if pl ~= player and getElementDimension(pl) == pDim and (myLeader == theirLeader) then
                local fx, fy, fz = getElementPosition(pl)
                if getDistanceBetweenPoints3D(px, py, pz, fx, fy, fz) <= 30 then
                    table.insert(targets, pl)
                end
            end
        end
        
        for _, target in ipairs(targets) do
            triggerClientEvent(target, "onServerSendPlaybackData", target, pathData, category, linkedRoute, safeName)
        end
        return true
    end
    return false
end

-- Fetch paths and the fresh list of available Myths from mysteries.db
local function sendPathListToClient(player)
    if not db then return end
    
    local query = dbQuery(db, "SELECT name, category, linked_route, myth FROM vehicle_paths")
    local result = dbPoll(query, -1)
    local paths = {}
    if result then
        for _, row in ipairs(result) do
            table.insert(paths, {
                name = row.name,
                category = row.category or "None",
                linked_route = row.linked_route or "",
                myth = row.myth or ""
            })
        end
    end
    
    -- Extract valid myth names directly from the misterix database
    local myths = {}
    if mysteriesDB then
        local mQuery = dbQuery(mysteriesDB, "SELECT name FROM missions")
        local mResult = dbPoll(mQuery, -1)
        if mResult then
            for _, row in ipairs(mResult) do
                table.insert(myths, row.name)
            end
        end
    end
    
    triggerClientEvent(player, "onServerSendPathList", player, paths, myths)
end

addEvent("onClientRequestPathList", true)
addEventHandler("onClientRequestPathList", root, function()
    sendPathListToClient(client)
end)

addEvent("onClientSavePath", true)
addEventHandler("onClientSavePath", root, function(name, pathData)
    if not db then return outputChatBox("Database connection missing. Cannot save.", client, 255, 0, 0) end
    
    local safeName = string.gsub(name, "[^%w_]", "")
    if safeName == "" then safeName = "path_" .. tostring(getTickCount()) end
    
    local jsonData = toJSON(pathData)
    local query = dbQuery(db, "SELECT category, linked_route, myth FROM vehicle_paths WHERE name = ?", safeName)
    local result = dbPoll(query, -1)
    local success
    
    if result and result[1] then
        success = dbExec(db, "UPDATE vehicle_paths SET data = ? WHERE name = ?", jsonData, safeName)
    else
        success = dbExec(db, "INSERT INTO vehicle_paths (name, data, category, linked_route, myth) VALUES (?, ?, 'None', '', '')", safeName, jsonData)
    end
    
    if success then
        outputChatBox("Recording '" .. safeName .. "' saved successfully to Database!", client, 0, 255, 0)
        sendPathListToClient(client)
    else
        outputChatBox("Database Error: Failed to save path.", client, 255, 0, 0)
    end
end)

addEvent("onClientUpdatePathSettings", true)
addEventHandler("onClientUpdatePathSettings", root, function(name, category, linkedRoute, myth)
    if not db then return end
    local safeName = string.gsub(name, "[^%w_]", "")
    dbExec(db, "UPDATE vehicle_paths SET category = ?, linked_route = ?, myth = ? WHERE name = ?", category, linkedRoute, myth, safeName)
    outputChatBox("Route settings for '" .. safeName .. "' updated!", client, 0, 255, 0)
    sendPathListToClient(client)
end)

addEvent("onClientDeletePath", true)
addEventHandler("onClientDeletePath", root, function(name)
    if not db then return end
    local safeName = string.gsub(name, "[^%w_]", "")
    dbExec(db, "DELETE FROM vehicle_paths WHERE name = ?", safeName)
    outputChatBox("Recording '" .. safeName .. "' deleted from Database.", client, 255, 150, 0)
    sendPathListToClient(client)
end)

addEvent("onClientRequestPlayback", true)
addEventHandler("onClientRequestPlayback", root, function(name)
    playPathForPlayer(client, name)
end)

addEvent("onServerCallTaxiForMyth", true)
addEventHandler("onServerCallTaxiForMyth", root, function(mythName)
    local player = client or source
    if not db or not mythName or mythName == "" then return end
    
    local query = dbQuery(db, "SELECT name, myth FROM vehicle_paths WHERE category = 'Airport Route'")
    local result = dbPoll(query, -1)
    local found = false
    
    if result then
        for _, row in ipairs(result) do
            local myths = split(row.myth or "", ",")
            for _, m in ipairs(myths) do
                if m == mythName then
                    playPathForPlayer(player, row.name)
                    found = true
                    break
                end
            end
            if found then break end
        end
    end
    
    if not found then
        local query2 = dbQuery(db, "SELECT name, myth FROM vehicle_paths")
        local result2 = dbPoll(query2, -1)
        if result2 then
            for _, row in ipairs(result2) do
                local myths = split(row.myth or "", ",")
                for _, m in ipairs(myths) do
                    if m == mythName then
                        playPathForPlayer(player, row.name)
                        found = true
                        break
                    end
                end
                if found then break end
            end
        end
    end
    
    if not found then
        outputChatBox("No taxi route configured for myth: " .. tostring(mythName), player, 255, 0, 0)
    end
end)

-- Identifies the active Misterix myth properly, completely blocking mid-mission calls
addCommandHandler("calltaxi", function(player)
    local leader = getElementData(player, "missionPartyLeader") or player
    local activeMission = getElementData(leader, "activeMissionData")
    
    -- Prevent glitches by completely blocking the command if they are already in the taxi sequence
    if getElementData(player, "in_fake_taxi") then
        return outputChatBox("You are already using a taxi sequence!", player, 255, 100, 0)
    end
    
    -- Prevent calling during an actively running mission (Misterix check)
    if getElementData(leader, "mission_active") == true or getElementData(leader, "missionStarted") == true then
        return outputChatBox("You cannot call a taxi while a myth is already actively running!", player, 255, 100, 0)
    end
    
    if activeMission and activeMission.name then
        triggerEvent("onServerCallTaxiForMyth", player, activeMission.name)
    else
        outputChatBox("You are not currently tracking an active myth!", player, 255, 100, 0)
    end
end)

-- Skippable Route Sequence Handler (Fully respects Dimension isolation & Dynamic Voting)
addEvent("onServerRequestSkipDrive", true)
addEventHandler("onServerRequestSkipDrive", root, function()
    local pPlayer = client
    if not db then return end
    
    local myLeader = getElementData(pPlayer, "missionPartyLeader") or pPlayer
    local partyInTaxi = {}
    
    -- Identify everyone in this exact party who is currently in the taxi
    for _, pl in ipairs(getElementsByType("player")) do
        local theirLeader = getElementData(pl, "missionPartyLeader") or pl
        if myLeader == theirLeader and getElementData(pl, "in_fake_taxi") then
            table.insert(partyInTaxi, pl)
        end
    end
    
    local totalRequired = #partyInTaxi
    if totalRequired == 0 then totalRequired = 1 end 

    if not skipVotes[myLeader] then
        skipVotes[myLeader] = {}
    end
    
    -- Register this player's vote
    skipVotes[myLeader][pPlayer] = true
    
    -- Count the votes for this specific taxi trip
    local currentVotes = 0
    for _, pl in ipairs(partyInTaxi) do
        if skipVotes[myLeader][pl] then
            currentVotes = currentVotes + 1
        end
    end
    
    if currentVotes >= totalRequired then
        -- Voting is complete, reset it for future runs
        skipVotes[myLeader] = nil 
        
        local activeMission = getElementData(myLeader, "activeMissionData")
        local activeMyth = activeMission and activeMission.name or ""
        
        local query = dbQuery(db, "SELECT name, data, category, linked_route, myth FROM vehicle_paths WHERE category = 'Skippable Route Sequence'")
        local result = dbPoll(query, -1)
        local foundPath = nil
        
        if result then
            for _, row in ipairs(result) do
                local myths = split(row.myth or "", ",")
                for _, m in ipairs(myths) do
                    if m == activeMyth then
                        foundPath = row
                        break
                    end
                end
                if foundPath then break end
            end
        end
        
        if foundPath then
            local pathData = fromJSON(foundPath.data)
            local category = foundPath.category or "None"
            local linkedRoute = foundPath.linked_route or ""
            local pathName = foundPath.name
            
            -- Trigger the skip exclusively for everyone in the taxi
            for _, pl in ipairs(partyInTaxi) do
                triggerClientEvent(pl, "onClientFadeOutAndStartSkip", pl, pathData, category, linkedRoute, pathName)
            end
        else
            for _, pl in ipairs(partyInTaxi) do
                outputChatBox("No 'Skippable Route Sequence' recording found in Database for myth: " .. tostring(activeMyth), pl, 255, 0, 0)
            end
        end
    else
        -- Need more votes, update the UI for everyone in the taxi
        local statusMsg = tostring(currentVotes) .. "/" .. tostring(totalRequired) .. " players confirmed skip"
        for _, pl in ipairs(partyInTaxi) do
            triggerClientEvent(pl, "onClientUpdateSkipStatus", pl, statusMsg)
        end
    end
end)