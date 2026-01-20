local RSGCore = exports['rsg-core']:GetCoreObject()
local propsCache = {}
local propsLoaded = false
local actionCooldowns = {}

-- Performance optimization settings
local PerformanceMode = {
    enabled = false,
    playerThreshold = 100,
    checkInterval = 15 * 60 * 1000, -- Check every 15 minutes
    batchQueryLimit = 100,
    rateLimitMultiplier = 1.5,
    syncInterval = 2000
}

local function GetPlayerCount()
    return #GetPlayers()
end

local function UpdatePerformanceMode()
    local playerCount = GetPlayerCount()
    PerformanceMode.enabled = playerCount > PerformanceMode.playerThreshold
end

local function GetPropConfig(modelName)
    for _, prop in ipairs(Config.availableProps) do
        if prop.model == modelName then
            return prop
        end
    end
    return nil
end

local function IsValidVector3(value)
    return type(value) == 'table'
        and type(value.x) == 'number'
        and type(value.y) == 'number'
        and type(value.z) == 'number'
end

local function CalculateDistanceSquared(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return (dx * dx) + (dy * dy) + (dz * dz)
end

local function GetPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return nil
    end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function IsRateLimited(src, action, cooldownMs)
    cooldownMs = cooldownMs or 1500
    
    -- Increase cooldown in performance mode
    if PerformanceMode.enabled then
        cooldownMs = math.ceil(cooldownMs * PerformanceMode.rateLimitMultiplier)
    end
    
    local now = GetGameTimer()
    actionCooldowns[src] = actionCooldowns[src] or {}
    local lastTime = actionCooldowns[src][action] or 0
    if now - lastTime < cooldownMs then
        return true
    end
    actionCooldowns[src][action] = now
    return false
end

RegisterNetEvent('tk_placeable:server:deleteProp', function(modelName, coords)
    local src = source

    if type(modelName) ~= 'string' then
        print('[tk_placeable] Invalid model from source ' .. tostring(src))
        return
    end

    local propConfig = GetPropConfig(modelName)
    if not propConfig then
        print('[tk_placeable] Unknown model ' .. modelName)
        return
    end

    if not IsValidVector3(coords) then
        print(Lang:t('logs.invalid_coords', { coords = json.encode(coords) }))
        return
    end

    if IsRateLimited(src, 'delete') then
        print('[tk_placeable] Delete rate limit for ' .. tostring(src))
        return
    end

    local playerCoords = GetPlayerCoords(src)
    if not playerCoords then
        return
    end

    local minDistance = Config.objectOptions.minDistanceToProp or 1.0
    local playerToProvidedSq = CalculateDistanceSquared(playerCoords, coords)
    if playerToProvidedSq > ((minDistance + 2.0) * (minDistance + 2.0)) then
        return
    end

    -- Use async processing with smaller batches in performance mode
    local function processDelete()
        local query = 'SELECT id, position FROM tk_placeable WHERE model = ?'
        
        if PerformanceMode.enabled then
            MySQL.query(query, { modelName }, function(results)
                if not results or #results == 0 then
                    return
                end

                local minDistanceSq = minDistance * minDistance
                local allowedPlayerDistanceSq = (minDistance + 1.0) * (minDistance + 1.0)
                local processed = 0
                local maxBatch = PerformanceMode.batchQueryLimit

                for _, row in ipairs(results) do
                    if processed >= maxBatch then
                        break
                    end
                    
                    local storedPosition = json.decode(row.position)
                    if IsValidVector3(storedPosition) then
                        local distToProvidedSq = CalculateDistanceSquared(coords, storedPosition)
                        local distToPlayerSq = CalculateDistanceSquared(playerCoords, storedPosition)

                        if distToProvidedSq <= minDistanceSq and distToPlayerSq <= allowedPlayerDistanceSq then
                            MySQL.execute('DELETE FROM tk_placeable WHERE id = ?', { row.id })
                            print(Lang:t('logs.db_deleted', { model = modelName, coords = ('%.2f, %.2f, %.2f'):format(storedPosition.x, storedPosition.y, storedPosition.z) }))

                            for i = #propsCache, 1, -1 do
                                local cached = propsCache[i]
                                if cached.id == row.id then
                                    table.remove(propsCache, i)
                                    break
                                end
                            end

                            local itemName = propConfig.item
                            if itemName then
                                local Player = RSGCore.Functions.GetPlayer(src)
                                if Player then
                                    Player.Functions.AddItem(itemName, 1)
                                    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], "add")
                                end
                            end
                            processed = processed + 1
                        end
                    end
                end
            end)
        else
            -- Original logic for normal mode
            MySQL.query(query, { modelName }, function(results)
                if not results then
                    return
                end

                local minDistanceSq = minDistance * minDistance
                local allowedPlayerDistanceSq = (minDistance + 1.0) * (minDistance + 1.0)

                for _, row in ipairs(results) do
                    local storedPosition = json.decode(row.position)
                    if IsValidVector3(storedPosition) then
                        local distToProvidedSq = CalculateDistanceSquared(coords, storedPosition)
                        local distToPlayerSq = CalculateDistanceSquared(playerCoords, storedPosition)

                        if distToProvidedSq <= minDistanceSq and distToPlayerSq <= allowedPlayerDistanceSq then
                            MySQL.execute('DELETE FROM tk_placeable WHERE id = ?', { row.id })
                            print(Lang:t('logs.db_deleted', { model = modelName, coords = ('%.2f, %.2f, %.2f'):format(storedPosition.x, storedPosition.y, storedPosition.z) }))

                            for i = #propsCache, 1, -1 do
                                local cached = propsCache[i]
                                if cached.id == row.id then
                                    table.remove(propsCache, i)
                                    break
                                end
                            end

                            local itemName = propConfig.item
                            if itemName then
                                local Player = RSGCore.Functions.GetPlayer(src)
                                if Player then
                                    Player.Functions.AddItem(itemName, 1)
                                    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], "add")
                                end
                            end
                            return
                        end
                    end
                end
            end)
        end
    end

    processDelete()
end)

RegisterNetEvent('tk_placeable:server:consumeItem', function() end)

for _, prop in pairs(Config.availableProps) do
    RSGCore.Functions.CreateUseableItem(prop.item, function(source, item)
        TriggerClientEvent('tk_placeable:client:placeSingleProp', source, prop.model)
    end)
end

RegisterNetEvent('tk_placeable:server:saveProp', function(modelName, coords, rot)
    local src = source

    if type(modelName) ~= 'string' then
        return
    end

    if IsRateLimited(src, 'save') then
        print('[tk_placeable] Save rate limit for ' .. tostring(src))
        return
    end

    local propConfig = GetPropConfig(modelName)
    if not propConfig then
        print('[tk_placeable] Unknown model ' .. modelName)
        return
    end

    if not IsValidVector3(coords) then
        print(Lang:t('logs.invalid_coords', { coords = json.encode(coords) }))
        return
    end

    if not IsValidVector3(rot) then
        print('[tk_placeable] Invalid rotation from source ' .. tostring(src))
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local itemName = propConfig.item
    if not itemName then
        return
    end

    local item = Player.Functions.GetItemByName(itemName)
    if not item or item.amount < 1 then
        print('[tk_placeable] Missing item ' .. itemName .. ' for player ' .. tostring(src))
        return
    end

    local posData = json.encode({ x = coords.x, y = coords.y, z = coords.z })
    local rotData = json.encode({ x = rot.x, y = rot.y, z = rot.z })

    Player.Functions.RemoveItem(itemName, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], "remove")

    local insertId
    local success, errorMsg = pcall(function()
        if MySQL.insert and MySQL.insert.await then
            insertId = MySQL.insert.await('INSERT INTO tk_placeable (model, position, rotation) VALUES (?, ?, ?)', {
                modelName, posData, rotData
            })
        else
            insertId = MySQL.insert('INSERT INTO tk_placeable (model, position, rotation) VALUES (?, ?, ?)', {
                modelName, posData, rotData
            })
        end
    end)

    if not success or not insertId or insertId == 0 then
        Player.Functions.AddItem(itemName, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], "add")
        print('[tk_placeable] Failed to save prop for player ' .. tostring(src) .. ': ' .. tostring(errorMsg or insertId))
        return
    end

    table.insert(propsCache, {
        id = insertId,
        model = modelName,
        position = posData,
        rotation = rotData
    })
end)

local function loadAllProps()
    print(Lang:t('logs.loading'))

    local success, results = pcall(function()
        return MySQL.query.await('SELECT * FROM tk_placeable')
    end)

    if not success then
        print(Lang:t('logs.load_failed', { error = tostring(results) }))
        return
    end

    propsCache = results or {}
    propsLoaded = true

    for _, row in ipairs(propsCache) do
        local modelName = row.model
        local position = json.decode(row.position)
        local rotation = json.decode(row.rotation)
        TriggerClientEvent('tk_placeable:client:loadProp', -1, modelName, position, rotation)
    end

    print(Lang:t('logs.loaded_count', { count = #propsCache }))
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Citizen.CreateThread(function()
            Wait(1000)
            loadAllProps()
        end)
    end
end)

RegisterCommand('loadprops', function(source, args, raw)
    if source == 0 or IsPlayerAceAllowed(source, 'command.loadprops') then
        loadAllProps()
        print(Lang:t('logs.reload_complete'))
    else
        TriggerClientEvent('ox_lib:notify', source, {
            description = Lang:t('command.no_permission'),
            type = 'error'
        })
    end
end, false)

-- Performance monitoring and mode update
local lastPerformanceCheck = 0
Citizen.CreateThread(function()
    while true do
        Wait(PerformanceMode.checkInterval)
        UpdatePerformanceMode()
        if GetGameTimer() - lastPerformanceCheck > PerformanceMode.checkInterval then
            local playerCount = GetPlayerCount()
            local mode = PerformanceMode.enabled and "ENABLED" or "DISABLED"
            print(string.format("[tk_placeable] Performance Mode: %s | Players: %d/%d", mode, playerCount, PerformanceMode.playerThreshold))
            lastPerformanceCheck = GetGameTimer()
        end
    end
end)

RegisterNetEvent('RSGCore:Server:OnPlayerLoaded', function()
    if not propsLoaded or not propsCache then
        return
    end
    
    local playerId = source
    
    -- In performance mode, send props in batches with delay
    if PerformanceMode.enabled then
        local totalProps = #propsCache
        local batchSize = PerformanceMode.batchQueryLimit
        local sentCount = 0
        
        for index, row in ipairs(propsCache) do
            local modelName = row.model
            local position = json.decode(row.position)
            local rotation = json.decode(row.rotation)
            TriggerClientEvent('tk_placeable:client:loadProp', playerId, modelName, position, rotation)
            
            sentCount = sentCount + 1
            if sentCount % batchSize == 0 then
                Wait(50) -- Small delay between batches to reduce spike
            end
        end
    else
        -- Original logic - send all at once
        for _, row in ipairs(propsCache) do
            local modelName = row.model
            local position = json.decode(row.position)
            local rotation = json.decode(row.rotation)
            TriggerClientEvent('tk_placeable:client:loadProp', playerId, modelName, position, rotation)
        end
    end
end)
