local sharedConfig = require 'config.shared'
local serverConfig = require 'config.server'

local RSGCore = exports['rsg-core']:GetCoreObject()
local oxmysql = exports.oxmysql

---@class PropEntry
---@field id    integer
---@field model string
---@field item  string
---@field posX  number
---@field posY  number
---@field posZ  number
---@field rotX  number
---@field rotY  number
---@field rotZ  number

---@class Vec3
---@field x number
---@field y number
---@field z number

---@type table<integer, PropEntry>
local props = {}
---@type table<string, table<integer, PropEntry>>
local propsByModel = {}
local propsLoaded = false
---@type table<integer, table<string, integer>>
local actionCooldown = {}
local perfMode = { enabled = false, last = nil }

---@type table<string, { label:string, model:string, item:string }>
local propByModel = {}
---@type table<string, { label:string, model:string, item:string }>
local propByItem  = {}
for i = 1, #sharedConfig.props do
    local p = sharedConfig.props[i]
    propByModel[p.model] = p
    propByItem[p.item]   = p
end

---@param ... any
local function dprint(...)
    if sharedConfig.debug then print('[tk_placeable]', ...) end
end

---@param src integer
---@param key string
---@param kind? 'inform'|'success'|'error'|'warning'
---@param ... any
local function notify(src, key, kind, ...)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = locale('title'),
        description = locale(key, ...),
        type        = kind or 'inform',
    })
end

---@param v any
---@return boolean
local function isFiniteNumber(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

---@param v any
---@return boolean
local function isValidVector3(v)
    if type(v) ~= 'table' then return false end
    if not (isFiniteNumber(v.x) and isFiniteNumber(v.y) and isFiniteNumber(v.z)) then
        return false
    end
    local lo, hi = sharedConfig.validation.worldMin, sharedConfig.validation.worldMax
    return v.x >= lo and v.x <= hi
       and v.y >= lo and v.y <= hi
       and v.z >= lo and v.z <= hi
end

---@param a Vec3
---@param b Vec3
---@return number
local function distSq(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

---@param coords Vec3
---@param radius number
---@return string[]
local function getPlayersInRadius(coords, radius)
    local result, n = {}, 0
    local r2 = radius * radius
    local players = GetPlayers()
    for i = 1, #players do
        local pid = players[i]
        local ped = GetPlayerPed(pid)
        if ped ~= 0 then
            local pc = GetEntityCoords(ped)
            local dx, dy, dz = coords.x - pc.x, coords.y - pc.y, coords.z - pc.z
            if (dx * dx + dy * dy + dz * dz) <= r2 then
                n = n + 1
                result[n] = pid
            end
        end
    end
    return result
end

---@param coords Vec3
---@param radius number
---@param event string
---@param ... any
local function broadcastNearby(coords, radius, event, ...)
    local nearby = getPlayersInRadius(coords, radius)
    for i = 1, #nearby do
        TriggerClientEvent(event, nearby[i], ...)
    end
end

---@param coords Vec3
---@param radius number
---@param exceptSrc integer
---@param event string
---@param ... any
local function broadcastNearbyExcept(coords, radius, exceptSrc, event, ...)
    local nearby = getPlayersInRadius(coords, radius)
    for i = 1, #nearby do
        local pid = nearby[i]
        if tonumber(pid) ~= exceptSrc then
            TriggerClientEvent(event, pid, ...)
        end
    end
end

---@param src integer
---@return Vec3?
local function getPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

---@param src integer
---@param action string
---@return boolean limited
local function isRateLimited(src, action)
    local cd = serverConfig.rateLimits[action] or 1500
    if perfMode.enabled then
        cd = math.ceil(cd * serverConfig.perfModeRateMultiplier)
    end
    local bucket = actionCooldown[src]
    if not bucket then
        bucket = {}
        actionCooldown[src] = bucket
    end
    local now  = GetGameTimer()
    local last = bucket[action] or 0
    if now - last < cd then return true end
    bucket[action] = now
    return false
end

---@param t table
---@return integer
local function tableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

---@param entry PropEntry
local function cacheInsert(entry)
    props[entry.id] = entry
    local bucket = propsByModel[entry.model]
    if not bucket then
        bucket = {}
        propsByModel[entry.model] = bucket
    end
    bucket[entry.id] = entry
end

---@param id integer
local function cacheRemove(id)
    local entry = props[id]
    if not entry then return end
    props[id] = nil
    local bucket = propsByModel[entry.model]
    if bucket then
        bucket[id] = nil
        if next(bucket) == nil then
            propsByModel[entry.model] = nil
        end
    end
end

---@param row { id:integer, model:string, position:string, rotation:string }
---@return PropEntry?
local function decodeRow(row)
    local pos = json.decode(row.position)
    local rot = json.decode(row.rotation)
    if not (isValidVector3(pos) and isValidVector3(rot)) then return nil end
    local cfg = propByModel[row.model]
    if not cfg then return nil end
    return {
        id    = row.id,
        model = row.model,
        item  = cfg.item,
        posX  = pos.x, posY = pos.y, posZ = pos.z,
        rotX  = rot.x, rotY = rot.y, rotZ = rot.z,
    }
end

---@param src integer
---@param itemName string
---@return boolean
local function giveItem(src, itemName)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    Player.Functions.AddItem(itemName, 1)
    local meta = RSGCore.Shared.Items[itemName]
    if meta then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, meta, 'add')
    end
    return true
end

---@param src integer
---@param itemName string
---@return boolean removed
local function takeItem(src, itemName)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local item = Player.Functions.GetItemByName(itemName)
    if not item or item.amount < 1 then return false end
    Player.Functions.RemoveItem(itemName, 1)
    local meta = RSGCore.Shared.Items[itemName]
    if meta then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, meta, 'remove')
    end
    return true
end

---@param entry PropEntry
---@return integer id, string model, Vec3 pos, Vec3 rot
local function entryToPayload(entry)
    return entry.id, entry.model,
        { x = entry.posX, y = entry.posY, z = entry.posZ },
        { x = entry.rotX, y = entry.rotY, z = entry.rotZ }
end

---@param target integer player id or -1 for everyone
---@param entry PropEntry
local function broadcastEntry(target, entry)
    TriggerClientEvent('tk_placeable:client:spawnProp', target, entryToPayload(entry))
end

local function loadProps()
    print(locale('log_loading'))

    oxmysql:fetch('SELECT id, model, position, rotation FROM tk_placeable', {}, function(rows)
        rows = rows or {}
        props, propsByModel = {}, {}
        local skipped = 0

        for i = 1, #rows do
            local entry = decodeRow(rows[i])
            if entry then
                cacheInsert(entry)
            else
                skipped = skipped + 1
            end
        end

        propsLoaded = true

        for _, entry in pairs(props) do
            broadcastEntry(-1, entry)
        end

        print(locale('log_loaded_count', tableCount(props)))
        if skipped > 0 then
            print(locale('log_skipped_rows', skipped))
        end
    end)
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    oxmysql:query([[
        CREATE TABLE IF NOT EXISTS `tk_placeable` (
            `id`       INT NOT NULL AUTO_INCREMENT,
            `model`    VARCHAR(100) NOT NULL,
            `position` LONGTEXT NOT NULL,
            `rotation` LONGTEXT NOT NULL,
            PRIMARY KEY (`id`),
            INDEX `idx_model` (`model`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        loadProps()
    end)
end)

AddEventHandler('playerDropped', function()
    actionCooldown[source] = nil
end)

---@param src integer
---@param itemName string
---@return boolean
lib.callback.register('tk_placeable:server:hasItem', function(src, itemName)
    if type(src) ~= 'number' or src <= 0 then return false end
    if not propByItem[itemName] then return false end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local it = Player.Functions.GetItemByName(itemName)
    return it ~= nil and (it.amount or 0) >= 1
end)

---@param modelName string
---@param coords Vec3
---@param rot Vec3
RegisterNetEvent('tk_placeable:server:saveProp', function(modelName, coords, rot)
    local src = source

    if type(modelName) ~= 'string' then return end
    local cfg = propByModel[modelName]
    if not cfg then
        dprint('unknown model from src', src, modelName)
        return
    end

    if not isValidVector3(coords) then
        print(locale('log_invalid_coords', src))
        return
    end
    if not isValidVector3(rot) then return end
    if isRateLimited(src, 'save') then return end

    local pc = getPlayerCoords(src)
    if not pc then return end

    local maxDist = sharedConfig.validation.maxPlaceDistance
    if distSq(pc, coords) > (maxDist * maxDist) then
        dprint('rejected save: too far', src)
        return
    end

    if not takeItem(src, cfg.item) then
        dprint('missing item', src, cfg.item)
        return
    end

    local posJson = json.encode({ x = coords.x, y = coords.y, z = coords.z })
    local rotJson = json.encode({ x = rot.x,    y = rot.y,    z = rot.z    })

    oxmysql:insert('INSERT INTO tk_placeable (model, position, rotation) VALUES (?, ?, ?)',
        { modelName, posJson, rotJson }, function(insertId)
            if not insertId or insertId == 0 then
                giveItem(src, cfg.item)
                dprint('insert failed for src', src)
                return
            end

            local entry = {
                id    = insertId,
                model = modelName,
                item  = cfg.item,
                posX  = coords.x, posY = coords.y, posZ = coords.z,
                rotX  = rot.x,    rotY = rot.y,    rotZ = rot.z,
            }
            cacheInsert(entry)

            broadcastNearbyExcept(coords, sharedConfig.radius.broadcast, src,
                'tk_placeable:client:spawnProp', entryToPayload(entry))

            TriggerClientEvent('tk_placeable:client:propSaved', src,
                insertId, modelName,
                { x = coords.x, y = coords.y, z = coords.z })
        end)
end)

---@param modelName string
---@param coords Vec3
RegisterNetEvent('tk_placeable:server:deleteProp', function(modelName, coords)
    local src = source

    if type(modelName) ~= 'string' then return end
    local cfg = propByModel[modelName]
    if not cfg then return end

    if not isValidVector3(coords) then
        print(locale('log_invalid_coords', src))
        return
    end

    if isRateLimited(src, 'delete') then return end

    local pc = getPlayerCoords(src)
    if not pc then return end

    local gate        = sharedConfig.radius.pickupGate
    local matchSq     = gate * gate
    local pickup      = sharedConfig.radius.pickup
    local playerReach = (pickup + 1.0) * (pickup + 1.0)

    if distSq(pc, coords) > playerReach then return end

    local bucket = propsByModel[modelName]
    if not bucket then return end

    ---@type PropEntry?
    local target
    local bestSq
    for _, entry in pairs(bucket) do
        local entryPos = { x = entry.posX, y = entry.posY, z = entry.posZ }
        local d = distSq(coords, entryPos)
        if d <= matchSq and (not bestSq or d < bestSq) then
            if distSq(pc, entryPos) <= playerReach then
                target, bestSq = entry, d
            end
        end
    end

    if not target then return end

    oxmysql:execute('DELETE FROM tk_placeable WHERE id = ?', { target.id }, function()
        cacheRemove(target.id)

        print(locale('log_db_deleted',
            target.id, modelName,
            ('%.2f, %.2f, %.2f'):format(target.posX, target.posY, target.posZ)))

        giveItem(src, cfg.item)

        broadcastNearbyExcept(
            { x = target.posX, y = target.posY, z = target.posZ },
            sharedConfig.radius.broadcast,
            src,
            'tk_placeable:client:removeProp', target.id)
    end)
end)

RegisterNetEvent('RSGCore:Server:OnPlayerLoaded', function()
    if not propsLoaded then return end
    local src = source

    local batchSize  = serverConfig.streamBatchSize
    local batchDelay = serverConfig.streamBatchDelay

    if perfMode.enabled and batchSize > 0 then
        Citizen.CreateThread(function()
            local sent = 0
            for _, entry in pairs(props) do
                broadcastEntry(src, entry)
                sent = sent + 1
                if sent % batchSize == 0 then Wait(batchDelay) end
            end
        end)
    else
        for _, entry in pairs(props) do
            broadcastEntry(src, entry)
        end
    end
end)

for i = 1, #sharedConfig.props do
    local p = sharedConfig.props[i]
    RSGCore.Functions.CreateUseableItem(p.item, function(source)
        TriggerClientEvent('tk_placeable:client:placeSingleProp', source, p.model)
    end)
end

---@param src integer
---@return boolean
local function isAuthorized(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, 'command.loadprops') then return true end
    if RSGCore and RSGCore.Functions and RSGCore.Functions.HasPermission then
        for _, group in ipairs(serverConfig.adminGroups) do
            if RSGCore.Functions.HasPermission(src, group) then return true end
        end
    end
    return false
end

lib.addCommand('loadprops', {
    help   = 'Reload all props from the database',
    params = {},
}, function(source)
    if not isAuthorized(source) then
        return notify(source, 'no_permission', 'error')
    end
    TriggerClientEvent('tk_placeable:client:clearAll', -1)
    loadProps()
    print(locale('log_reload_complete'))
end)

Citizen.CreateThread(function()
    while true do
        Wait(serverConfig.perfModeCheckIntervalMs)
        local n = #GetPlayers()
        local enabled = n > serverConfig.perfModePlayerThreshold
        if enabled ~= perfMode.last then
            perfMode.enabled = enabled
            perfMode.last    = enabled
            dprint(('perf mode %s (players=%d threshold=%d)'):format(
                enabled and 'ENABLED' or 'DISABLED', n, serverConfig.perfModePlayerThreshold))
        else
            perfMode.enabled = enabled
        end
    end
end)
