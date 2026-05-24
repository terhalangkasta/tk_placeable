local sharedConfig = require 'config.shared'
local clientConfig = require 'config.client'

---@class Vec3
---@field x number
---@field y number
---@field z number

---@class SpawnedRec
---@field id?    integer database id once reconciled
---@field model  string
---@field label  string

---@type table<string, integer>
local modelHashByName = {}
---@type table<string, string>
local labelByModel = {}
for i = 1, #sharedConfig.props do
    local p = sharedConfig.props[i]
    modelHashByName[p.model] = GetHashKey(p.model)
    labelByModel[p.model]    = p.label
end

---@type table<integer, SpawnedRec>
local spawnedProps = {}
---@type table<integer, integer>
local entityById = {}
---@type table<integer, table<string, integer>>
local pendingPlacement = {}

local promptGroup = GetRandomIntInRange(0, 0xffffff)
---@type table<string, any>
local Prompts  = {}
local perfMode = { enabled = false, last = nil }

---@param ... any
local function dprint(...)
    if sharedConfig.debug then print('[tk_placeable]', ...) end
end

---@param key string
---@param kind? 'inform'|'success'|'error'|'warning'
---@param ... any
local function notify(key, kind, ...)
    lib.notify({
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

---@param value any
---@return Vec3?
local function normalizeVector3(value)
    if not value then return nil end
    local t = type(value)
    if t == 'vector3' or t == 'vector4' then
        return { x = value.x, y = value.y, z = value.z }
    end
    if t == 'table' then
        if isFiniteNumber(value.x) and isFiniteNumber(value.y) and isFiniteNumber(value.z) then
            return { x = value.x, y = value.y, z = value.z }
        end
        if isFiniteNumber(value[1]) and isFiniteNumber(value[2]) and isFiniteNumber(value[3]) then
            return { x = value[1], y = value[2], z = value[3] }
        end
    end
    return nil
end

---@param c Vec3
---@return string
local function coordKey(c)
    return ('%.2f|%.2f|%.2f'):format(c.x, c.y, c.z)
end

---@param model string
---@param coords Vec3
---@param entity integer
local function rememberPending(model, coords, entity)
    local hash = modelHashByName[model]
    if not hash then return end
    local bucket = pendingPlacement[hash]
    if not bucket then
        bucket = {}
        pendingPlacement[hash] = bucket
    end
    bucket[coordKey(coords)] = entity
end

---@param model string
---@param coords Vec3
---@return integer? entity
local function consumePending(model, coords)
    local hash = modelHashByName[model]
    if not hash then return nil end
    local bucket = pendingPlacement[hash]
    if not bucket then return nil end
    local key = coordKey(coords)
    local entity = bucket[key]
    bucket[key] = nil
    if next(bucket) == nil then
        pendingPlacement[hash] = nil
    end
    return entity
end

---@param modelName string
---@return integer? hash
local function requestModelWithTimeout(modelName)
    local hash = modelHashByName[modelName] or GetHashKey(modelName)
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local deadline = GetGameTimer() + (sharedConfig.placement.modelLoadTimeoutMs or 10000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(10)
    end
    return hash
end

---@param h number
---@return number
local function clampHeading(h)
    if h >= 360.0 then return h - 360.0 end
    if h < 0.0    then return h + 360.0 end
    return h
end

---@param entity integer
---@param modelName string
local function applyTarget(entity, modelName)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    local label = labelByModel[modelName] or locale('unknown_prop')

    exports.ox_target:addLocalEntity(entity, {
        {
            name     = 'tk_placeable_pickup',
            icon     = 'fas fa-trash',
            label    = locale('pickup', label),
            distance = sharedConfig.radius.pickup,
            onSelect = function(data)
                local ent = data.entity
                if not ent or not DoesEntityExist(ent) then return end

                local rec = spawnedProps[ent]
                if not rec then return end

                local c = GetEntityCoords(ent)
                local coords = { x = c.x, y = c.y, z = c.z }

                if rec.id then entityById[rec.id] = nil end
                spawnedProps[ent] = nil
                if DoesEntityExist(ent) then DeleteEntity(ent) end

                TriggerServerEvent('tk_placeable:server:deleteProp', rec.model, coords)
                notify('prop_removed', 'success')
            end,
        },
    })
end

---@param label string
---@param controlHashes integer|integer[]
---@param holdMode boolean
---@return any prompt
local function createPrompt(label, controlHashes, holdMode)
    local prompt = PromptRegisterBegin()
    if type(controlHashes) ~= 'table' then controlHashes = { controlHashes } end
    for i = 1, #controlHashes do
        PromptSetControlAction(prompt, controlHashes[i])
    end
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', label))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    if holdMode then
        PromptSetHoldMode(prompt, true)
    else
        PromptSetStandardMode(prompt, true)
    end
    PromptSetGroup(prompt, promptGroup)
    PromptRegisterEnd(prompt)
    return prompt
end

local function initPrompts()
    local c = sharedConfig.controls
    Prompts.cancel       = createPrompt(locale('prompt_cancel'),          c.cancel,                          true)
    Prompts.place        = createPrompt(locale('prompt_place'),           c.place,                           true)
    Prompts.rotate       = createPrompt(locale('prompt_rotate'),          { c.rotateLeft,   c.rotateRight }, false)
    Prompts.moveHoriz    = createPrompt(locale('prompt_move_horizontal'), { c.moveLeft,     c.moveRight   }, false)
    Prompts.moveDepth    = createPrompt(locale('prompt_move_depth'),      { c.bringForward, c.sendBackward}, false)
    Prompts.moveVertical = createPrompt(locale('prompt_move_vertical'),   { c.moveDown,     c.moveUp      }, false)
end

---@param prop integer
local function drawAxes(prop)
    local fwd, right, up, pos = GetEntityMatrix(prop)
    local base = pos + vector3(0.0, 0.0, 0.1)
    local len  = sharedConfig.placement.axisLength
    local x = pos + right * len
    local y = pos + fwd   * len
    local z = pos + up    * len
    DrawLine(base.x, base.y, base.z, x.x, x.y, x.z, 255, 0,   0,   255)
    DrawLine(base.x, base.y, base.z, y.x, y.y, y.z, 0,   255, 0,   255)
    DrawLine(base.x, base.y, base.z, z.x, z.y, z.z, 0,   0,   255, 255)
end

---@param prop integer
local function applyMoveControls(prop)
    local fwd, right = GetEntityMatrix(prop)
    if not (fwd and right) then return end

    local moveStep     = sharedConfig.placement.translationStep
    local verticalStep = sharedConfig.placement.verticalStep or moveStep
    local c            = sharedConfig.controls

    local mv = vector3(0.0, 0.0, 0.0)
    if IsControlPressed(1, c.moveLeft)     then mv = mv - (right * moveStep) end
    if IsControlPressed(1, c.moveRight)    then mv = mv + (right * moveStep) end
    if IsControlPressed(1, c.bringForward) then mv = mv + (fwd   * moveStep) end
    if IsControlPressed(1, c.sendBackward) then mv = mv - (fwd   * moveStep) end
    if IsControlPressed(1, c.moveUp)       then mv = mv + vector3(0.0, 0.0, verticalStep) end
    if IsControlPressed(1, c.moveDown)     then mv = mv - vector3(0.0, 0.0, verticalStep) end

    if mv.x ~= 0.0 or mv.y ~= 0.0 or mv.z ~= 0.0 then
        local p = GetEntityCoords(prop)
        local t = p + mv
        SetEntityCoordsNoOffset(prop, t.x, t.y, t.z, false, false, false, true)
    end
end

---@param prop integer
---@param currentHeading number
---@return number heading
local function applyRotationControls(prop, currentHeading)
    local step = sharedConfig.placement.rotationStep
    local c    = sharedConfig.controls
    local h    = currentHeading
    if IsControlPressed(1, c.rotateLeft) then
        h = clampHeading(h + step)
    elseif IsControlPressed(1, c.rotateRight) then
        h = clampHeading(h - step)
    end
    if h ~= currentHeading then
        SetEntityHeading(prop, h)
    end
    return h
end

---@param modelName string
local function spawnProp(modelName)
    if type(modelName) ~= 'string' or not modelHashByName[modelName] then
        notify('invalid_model', 'error')
        return
    end

    if not requestModelWithTimeout(modelName) then
        notify('create_failed', 'error')
        return
    end

    local ped       = cache.ped or PlayerPedId()
    local pCoords   = GetEntityCoords(ped)
    local forward   = GetEntityForwardVector(ped)
    local placeDist = sharedConfig.placement.defaultPlacementDistance

    local base = vector3(
        pCoords.x + forward.x * placeDist,
        pCoords.y + forward.y * placeDist,
        pCoords.z + forward.z * placeDist
    )

    local prop = CreateObject(modelName, base.x, base.y, base.z + sharedConfig.placement.propSpawnHeight, false, false, true)
    if not prop or prop == 0 then
        notify('create_failed', 'error')
        SetModelAsNoLongerNeeded(modelName)
        return
    end

    FreezeEntityPosition(prop, true)
    SetEntityAlpha(prop, 180, false)
    SetEntityCollision(prop, false, false)
    SetEntityCoordsNoOffset(prop, base.x, base.y, base.z, false, false, false, true)
    PlaceObjectOnGroundProperly(prop)

    local heading   = GetEntityHeading(ped)
    local groupName = CreateVarString(10, 'LITERAL_STRING', locale('prompt_group'))
    SetEntityHeading(prop, heading)

    while true do
        Wait(0)
        PromptSetActiveGroupThisFrame(promptGroup, groupName)
        drawAxes(prop)
        applyMoveControls(prop)
        heading = applyRotationControls(prop, heading)

        if PromptHasHoldModeCompleted(Prompts.place) then break end
        if PromptHasHoldModeCompleted(Prompts.cancel) then
            DeleteEntity(prop)
            SetModelAsNoLongerNeeded(modelName)
            return
        end
    end

    SetEntityAlpha(prop, 255, false)
    SetEntityCollision(prop, true, true)
    FreezeEntityPosition(prop, false)

    local propCoords = GetEntityCoords(prop)
    local minDist    = sharedConfig.radius.pickup
    local timeoutAt  = GetGameTimer() + (sharedConfig.placement.approachTimeoutMs or 5000)

    TaskGoStraightToCoord(ped, propCoords.x, propCoords.y, propCoords.z, 1.0, -1, GetEntityHeading(ped), 0.0)

    local pc = GetEntityCoords(ped)
    while #(propCoords - pc) > minDist and GetGameTimer() < timeoutAt do
        Wait(0)
        pc = GetEntityCoords(ped)
    end

    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, GetHeadingFromVector_2d(propCoords.x - pc.x, propCoords.y - pc.y))

    local anim = clientConfig.placementAnim
    lib.requestAnimDict(anim.dict)
    if HasAnimDictLoaded(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 4.0, -4.0, -1, 1, 0.0, false, 0, false, 0, false)
    end

    Wait(sharedConfig.placement.animationDurationMs)

    FreezeEntityPosition(prop, true)

    local savedCoords = normalizeVector3(GetEntityCoords(prop))
    local savedRot    = normalizeVector3(GetEntityRotation(prop, 2))

    if not savedCoords or not savedRot then
        DeleteEntity(prop)
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        SetModelAsNoLongerNeeded(modelName)
        return
    end

    spawnedProps[prop] = { id = nil, model = modelName, label = labelByModel[modelName] }
    rememberPending(modelName, savedCoords, prop)
    applyTarget(prop, modelName)

    TriggerServerEvent('tk_placeable:server:saveProp', modelName, savedCoords, savedRot)
    notify('prop_saved', 'success')

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    SetModelAsNoLongerNeeded(modelName)
end

---@param modelName string
RegisterNetEvent('tk_placeable:client:placeSingleProp', function(modelName)
    spawnProp(modelName)
end)

---@param id integer
---@param modelName string
---@param pos Vec3
---@param rot Vec3
RegisterNetEvent('tk_placeable:client:spawnProp', function(id, modelName, pos, rot)
    if not modelHashByName[modelName] then return end

    local coords = normalizeVector3(pos)
    if not coords then return end
    local rotation = normalizeVector3(rot) or { x = 0.0, y = 0.0, z = 0.0 }

    if id and entityById[id] and DoesEntityExist(entityById[id]) then return end

    local existing = consumePending(modelName, coords)
    if existing and DoesEntityExist(existing) then
        if id then
            entityById[id] = existing
            local rec = spawnedProps[existing]
            if rec then rec.id = id end
        end
        return
    end

    if not requestModelWithTimeout(modelName) then return end

    local prop = CreateObject(modelHashByName[modelName], coords.x, coords.y, coords.z, false, false, true)
    SetEntityCoordsNoOffset(prop, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityRotation(prop, rotation.x, rotation.y, rotation.z, 2, true)
    SetEntityCollision(prop, true, true)
    FreezeEntityPosition(prop, true)
    SetModelAsNoLongerNeeded(modelName)

    spawnedProps[prop] = { id = id, model = modelName, label = labelByModel[modelName] }
    if id then entityById[id] = prop end
    applyTarget(prop, modelName)
end)

---@param id integer
---@param modelName string
---@param coords Vec3
RegisterNetEvent('tk_placeable:client:propSaved', function(id, modelName, coords)
    local norm = normalizeVector3(coords)
    if not norm then return end
    local entity = consumePending(modelName, norm)
    if entity and DoesEntityExist(entity) then
        entityById[id] = entity
        local rec = spawnedProps[entity]
        if rec then rec.id = id end
    end
end)

---@param id integer
RegisterNetEvent('tk_placeable:client:removeProp', function(id)
    local entity = entityById[id]
    if not entity then return end
    entityById[id] = nil
    if spawnedProps[entity] then spawnedProps[entity] = nil end
    if DoesEntityExist(entity) then DeleteEntity(entity) end
end)

RegisterNetEvent('tk_placeable:client:clearAll', function()
    for entity in pairs(spawnedProps) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    spawnedProps     = {}
    entityById       = {}
    pendingPlacement = {}
end)

CreateThread(function()
    while true do
        Wait(clientConfig.perfModeCheckIntervalMs)
        local n = #GetActivePlayers()
        local enabled = n > clientConfig.perfModePlayerThreshold
        if enabled ~= perfMode.last then
            perfMode.enabled = enabled
            perfMode.last    = enabled
            dprint(('perf mode %s (active=%d threshold=%d)'):format(
                enabled and 'ENABLED' or 'DISABLED', n, clientConfig.perfModePlayerThreshold))
        else
            perfMode.enabled = enabled
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print(locale('log_resource_stopping'))
    for entity in pairs(spawnedProps) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    spawnedProps     = {}
    entityById       = {}
    pendingPlacement = {}
end)

RegisterCommand('placeable_debug', function()
    local count = 0
    for _ in pairs(spawnedProps) do count = count + 1 end
    print(('[tk_placeable] spawned=%d perf=%s'):format(
        count, tostring(perfMode.enabled)))
end, false)

initPrompts()
