-- garage_client.lua

local screenW, screenH = guiGetScreenSize()
local garageWnd = guiCreateWindow((screenW - 400) / 2, (screenH - 300) / 2, 400, 300, "Personal Garage", false)
guiWindowSetSizable(garageWnd, false)
guiSetVisible(garageWnd, false)

local garageList = guiCreateGridList(0.05, 0.1, 0.9, 0.65, true, garageWnd)
guiGridListAddColumn(garageList, "Vehicle Model", 0.9)

local btnSpawn = guiCreateButton(0.05, 0.8, 0.3, 0.15, "Spawn Vehicle", true, garageWnd)
local btnDelete = guiCreateButton(0.38, 0.8, 0.3, 0.15, "Delete", true, garageWnd)
local btnClose = guiCreateButton(0.71, 0.8, 0.24, 0.15, "Close", true, garageWnd)

addEvent("onClientOpenGarage", true)
addEventHandler("onClientOpenGarage", root, function(garageData)
    guiGridListClear(garageList)
    if type(garageData) == "table" then
        for i, veh in ipairs(garageData) do
            local row = guiGridListAddRow(garageList)
            guiGridListSetItemText(garageList, row, 1, veh.name, false, false)
            veh.originalIndex = i -- Saved to quickly remove from DB list
            guiGridListSetItemData(garageList, row, 1, veh)
        end
    end
    guiSetVisible(garageWnd, true)
    showCursor(true)
end)

addEventHandler("onClientGUIClick", btnClose, function(button, state)
    if button == "left" and state == "up" then
        guiSetVisible(garageWnd, false)
        showCursor(false)
    end
end, false)

addEventHandler("onClientGUIClick", btnSpawn, function(button, state)
    if button == "left" and state == "up" then
        local row = guiGridListGetSelectedItem(garageList)
        if row ~= -1 then
            local vehData = guiGridListGetItemData(garageList, row, 1)
            triggerServerEvent("onServerSpawnGarageVehicle", localPlayer, vehData)
            guiSetVisible(garageWnd, false)
            showCursor(false)
        else
            outputChatBox("Please select a vehicle from the list to spawn.", 255, 0, 0)
        end
    end
end, false)

addEventHandler("onClientGUIClick", btnDelete, function(button, state)
    if button == "left" and state == "up" then
        local row = guiGridListGetSelectedItem(garageList)
        if row ~= -1 then
            local vehData = guiGridListGetItemData(garageList, row, 1)
            triggerServerEvent("onServerDeleteGarageVehicle", localPlayer, vehData.originalIndex)
        else
            outputChatBox("Please select a vehicle to delete.", 255, 0, 0)
        end
    end
end, false)