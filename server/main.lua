local RSGCore = exports['rsg-core']:GetCoreObject()
local propsCache = {}
local propsLoaded = false

local function GetItemFromModel(modelName)
    for _, prop in ipairs(Config.availableProps) do
        if prop.model == modelName then
            return prop.item
        end
    end
    return nil
end

RegisterNetEvent('tk_placeable:deleteProp', function(modelName, coords)
    local src = source

    if not coords or not coords.x then
        print(Lang:t('logs.invalid_coords', { coords = json.encode(coords) }))
        return
    end

    MySQL.query('SELECT id, position FROM tk_placeable WHERE model = ?', { modelName }, function(results)
        for _, row in ipairs(results) do
            local pos = json.decode(row.position)

            if pos then
                local dx = coords.x - pos.x
                local dy = coords.y - pos.y
                local dz = coords.z - pos.z
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

                if dist < Config.objectOptions.minDistanceToProp then
                    MySQL.execute('DELETE FROM tk_placeable WHERE id = ?', { row.id })
                    print(Lang:t('logs.db_deleted', { model = modelName, coords = ('%.2f, %.2f, %.2f'):format(pos.x, pos.y, pos.z) }))

                    local itemName = GetItemFromModel(modelName)
                    if itemName then
                        local Player = RSGCore.Functions.GetPlayer(src)
                        if Player then
                            Player.Functions.AddItem(itemName, 1)
                            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], "add")
                        end
                    end
                    break
                end
            end
        end
    end)
end)

RegisterNetEvent('tk_placeable:server:consumeItem', function(itemName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player and itemName then
        Player.Functions.RemoveItem(itemName, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], "remove")
    end
end)

for _, prop in pairs(Config.availableProps) do
    RSGCore.Functions.CreateUseableItem(prop.item, function(source, item)
        TriggerClientEvent('tk_placeable:client:placeSingleProp', source, prop.model)
    end)
end

RegisterNetEvent('tk_placeable:server:saveProp', function(modelName, coords, rot)
    local posData = json.encode({ x = coords.x, y = coords.y, z = coords.z })
    local rotData = json.encode({ x = rot.x, y = rot.y, z = rot.z })

    MySQL.insert('INSERT INTO tk_placeable (model, position, rotation) VALUES (?, ?, ?)', {
        modelName, posData, rotData
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

RegisterNetEvent('RSGCore:Server:OnPlayerLoaded', function()
    if not propsLoaded or not propsCache then
        return
    end
    
    local playerId = source
    for _, row in ipairs(propsCache) do
        local modelName = row.model
        local position = json.decode(row.position)
        local rotation = json.decode(row.rotation)
        TriggerClientEvent('tk_placeable:client:loadProp', playerId, modelName, position, rotation)
    end
end)
