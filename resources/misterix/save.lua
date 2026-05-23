-- save.lua
local spawnX, spawnY, spawnZ = 427.441, 2526.714, 16.570

local respawnData = {}

function savePlayerData(player)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return end
    
    setAccountData(account, "misterix_money", getPlayerMoney(player))
    setAccountData(account, "misterix_skin", getElementModel(player))
    setAccountData(account, "misterix_health", getElementHealth(player))
    setAccountData(account, "misterix_armor", getPedArmor(player))
    
    local x, y, z = getElementPosition(player)
    setAccountData(account, "misterix_x", x)
    setAccountData(account, "misterix_y", y)
    setAccountData(account, "misterix_z", z)
    setAccountData(account, "misterix_int", getElementInterior(player))
    setAccountData(account, "misterix_dim", getElementDimension(player))
    
    local weps = {}
    for i=0, 12 do
        local w = getPedWeapon(player, i)
        local a = getPedTotalAmmo(player, i)
        if w and w > 0 and a > 0 then
            table.insert(weps, {w, a})
        end
    end
    setAccountData(account, "misterix_weapons", toJSON(weps))
    
    local stats = {}
    local statsToSave = {22, 23, 24} -- Added Lung Capacity, Muscle, and Max Health
    for stat=69, 79 do table.insert(statsToSave, stat) end
    
    for _, stat in ipairs(statsToSave) do
        table.insert(stats, {stat, getPedStat(player, stat)})
    end
    setAccountData(account, "misterix_stats", toJSON(stats))
    
    if getElementModel(player) == 0 then
        local clothes = {}
        for i=0, 17 do
            local texture, model = getPedClothes(player, i)
            if texture and model then
                table.insert(clothes, {i, texture, model})
            end
        end
        setAccountData(account, "misterix_clothes", toJSON(clothes))
    end
end

function loadPlayerData(player)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return end
    
    local money = getAccountData(account, "misterix_money")
    if money then setPlayerMoney(player, tonumber(money)) end
    
    local skin = getAccountData(account, "misterix_skin")
    if skin then setElementModel(player, tonumber(skin)) end
    
    local hp = getAccountData(account, "misterix_health")
    if hp then setElementHealth(player, tonumber(hp)) end
    
    local armor = getAccountData(account, "misterix_armor")
    if armor then setPedArmor(player, tonumber(armor)) end
    
    local weps = getAccountData(account, "misterix_weapons")
    if weps then
        local parsed = fromJSON(weps)
        if type(parsed) == "table" then
            for _, w in ipairs(parsed) do
                giveWeapon(player, w[1], w[2], false)
            end
        end
    end
    
    local stats = getAccountData(account, "misterix_stats")
    if stats then
        local parsed = fromJSON(stats)
        if type(parsed) == "table" then
            for _, s in ipairs(parsed) do
                setPedStat(player, s[1], s[2])
            end
        end
    end
    
    local x = getAccountData(account, "misterix_x")
    local y = getAccountData(account, "misterix_y")
    local z = getAccountData(account, "misterix_z")
    if x and y and z then
        setElementPosition(player, tonumber(x), tonumber(y), tonumber(z))
        setElementInterior(player, tonumber(getAccountData(account, "misterix_int")) or 0)
        setElementDimension(player, tonumber(getAccountData(account, "misterix_dim")) or 0)
    else
        setElementPosition(player, spawnX, spawnY, spawnZ)
        setElementInterior(player, 0)
        setElementDimension(player, 0)
    end
    
    if getElementModel(player) == 0 then
        local clothes = getAccountData(account, "misterix_clothes")
        if clothes then
            local parsed = fromJSON(clothes)
            if type(parsed) == "table" then
                setTimer(function(p, clothesTable)
                    if isElement(p) and getElementModel(p) == 0 then
                        for _, c in ipairs(clothesTable) do
                            addPedClothes(p, c[2], c[3], c[1])
                        end
                    end
                end, 250, 1, player, parsed)
            end
        end
    end
end

addEventHandler("onPlayerQuit", root, function()
    respawnData[source] = nil
    savePlayerData(source)
end)

addEventHandler("onPlayerLogin", root, function(_, account)
    loadPlayerData(source)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do
        savePlayerData(p)
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do
        loadPlayerData(p)
    end
end)

addEventHandler("onPlayerWasted", root, function()
    local weps = {}
    for i=0, 12 do
        local w = getPedWeapon(source, i)
        local a = getPedTotalAmmo(source, i)
        if w and w > 0 and a > 0 then
            table.insert(weps, {w, a})
        end
    end
    
    local clothes = nil
    if getElementModel(source) == 0 then
        clothes = {}
        for i=0, 17 do
            local texture, model = getPedClothes(source, i)
            if texture and model then
                table.insert(clothes, {i, texture, model})
            end
        end
    end
    
    respawnData[source] = {
        skin = getElementModel(source),
        weps = weps,
        clothes = clothes
    }
end)

addEventHandler("onPlayerSpawn", root, function()
    local data = respawnData[source]
    if data then
        setElementModel(source, data.skin)
        for _, w in ipairs(data.weps) do
            giveWeapon(source, w[1], w[2], false)
        end
        
        if data.skin == 0 and data.clothes then
            setTimer(function(p, clothesTable)
                if isElement(p) and getElementModel(p) == 0 then
                    for _, c in ipairs(clothesTable) do
                        addPedClothes(p, c[2], c[3], c[1])
                    end
                end
            end, 250, 1, source, data.clothes)
        end
        
        respawnData[source] = nil
    end
end)