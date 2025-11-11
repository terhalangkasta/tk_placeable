local spawnedProps = {}
local PromptPlacerGroup = GetRandomIntInRange(0, 0xffffff)

local Prompts = {
    cancel = nil,
    place = nil,
    rotateLeft = nil,
    rotateRight = nil
}

-----------------------------
-- FUNCTIONS
-----------------------------
local function GetItemNameFromModel(model)
    for _, prop in ipairs(Config.availableProps) do
        if prop.model == model then
            return prop.item
        end
    end
    return nil
end

local function Notify(key, subs, notifType)
    lib.notify({
        title = Lang:t('notify.title'),
        description = Lang:t(key, subs),
        type = notifType or 'inform'
    })
end

local function GetPropNameFromHash(hash)
    if not hash then
        print("[ERROR] GetPropNameFromHash: Hash is nil")
        return nil
    end

    for _, prop in ipairs(Config.availableProps) do
        local model = prop.model
        if model and GetHashKey(model) == hash then
            return model
        end
    end

    print(Lang:t('debug.no_prop_match', { hash = hash }))
    return nil
end

local function GetLabelFromModel(modelName)
    for _, prop in ipairs(Config.availableProps) do
        if prop.model == modelName then
            return prop.label
        end
    end
    return Lang:t('text.unknown_prop')
end


local function applyTargetToProp(propEntity)
    if not propEntity or type(propEntity) ~= "number" or not DoesEntityExist(propEntity) then
        print("[ERROR] applyTargetToProp: Invalid or nil propEntity:", propEntity)
        return
    end

    local modelHash = GetEntityModel(propEntity)
    local modelName = GetPropNameFromHash(modelHash)
    local labelName = GetLabelFromModel(modelName)

    exports.ox_target:addLocalEntity(propEntity, {
        {
            name = "delete_prop",
            icon = "fas fa-trash",
            label = Lang:t('text.pickup', { label = labelName }),

            onSelect = function(data)
                local entity = data.entity
                if not entity or not DoesEntityExist(entity) then
                    print("[ERROR] onSelect: Invalid or nil entity:", entity)
                    return
                end

                local coords = GetEntityCoords(entity)
                DeleteEntity(entity)
                TriggerServerEvent('tk_placeable:server:deleteProp', modelName, {
                    x = coords.x, y = coords.y, z = coords.z
                })

                for i = #spawnedProps, 1, -1 do
                    if spawnedProps[i] == entity then
                        table.remove(spawnedProps, i)
                        break
                    end
                end

                Notify('notify.prop_removed', nil, 'success')
                print(string.format("[INFO] Deleted prop '%s' at coords %s", modelName, coords))
            end
        }
    })
end

local function CreatePrompt(label, controlHash, holdMode)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, controlHash)
    local str = CreateVarString(10, 'LITERAL_STRING', label)
    PromptSetText(prompt, str)
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    
    if holdMode then
        PromptSetHoldMode(prompt, true)
    else
        PromptSetStandardMode(prompt, true)
    end
    
    PromptSetGroup(prompt, PromptPlacerGroup)
    PromptRegisterEnd(prompt)
    return prompt
end

local function InitializePrompts()
    Prompts.cancel = CreatePrompt(Lang:t('prompts.cancel'), Config.controlHash.CANCEL, true)
    Prompts.place = CreatePrompt(Lang:t('prompts.place'), Config.controlHash.PLACE, true)
    Prompts.rotateLeft = CreatePrompt(Lang:t('prompts.rotate_left'), Config.controlHash.ROTATE_LEFT, false)
    Prompts.rotateRight = CreatePrompt(Lang:t('prompts.rotate_right'), Config.controlHash.ROTATE_RIGHT, false)
end

local function RotationToDirection(rotation)
    local adjustedRotation = {
        x = math.rad(rotation.x),
        y = math.rad(rotation.y),
        z = math.rad(rotation.z)
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

local function DrawPropAxes(prop)
    local propForward, propRight, propUp, propCoords = GetEntityMatrix(prop)
    local baseCoords = propCoords + vector3(0, 0, 0.1)

    local axisLength = Config.objectOptions.axisLength
    local propXAxisEnd = propCoords + propRight * axisLength
    local propYAxisEnd = propCoords + propForward * axisLength
    local propZAxisEnd = propCoords + propUp * axisLength

    DrawLine(baseCoords.x, baseCoords.y, baseCoords.z, propXAxisEnd.x, propXAxisEnd.y, propXAxisEnd.z, 255, 0, 0, 255)
    DrawLine(baseCoords.x, baseCoords.y, baseCoords.z, propYAxisEnd.x, propYAxisEnd.y, propYAxisEnd.z, 0, 255, 0, 255)
    DrawLine(baseCoords.x, baseCoords.y, baseCoords.z, propZAxisEnd.x, propZAxisEnd.y, propZAxisEnd.z, 0, 0, 255, 255)
end

local function RayCastGamePlayCamera(distance)
    local rayDistance = distance or Config.objectOptions.raycastDistance
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(cameraRotation)
    local destination = cameraCoord + vector3(
        direction.x * rayDistance,
        direction.y * rayDistance,
        direction.z * rayDistance
    )
    
    local _, hit, coords, _, entity = GetShapeTestResult(StartShapeTestRay(
        cameraCoord.x, cameraCoord.y, cameraCoord.z,
        destination.x, destination.y, destination.z,
        -1, PlayerPedId(), 0
    ))
    return hit, coords, entity
end

local function spawnProp(modelName, fromItemName)
    if type(modelName) ~= "string" then
        Notify('notify.invalid_model', nil, 'error')
        return
    end

    lib.requestModel(modelName)

    local hit, coords = RayCastGamePlayCamera()
    while hit ~= 1 or not coords do
        Wait(0)
        hit, coords = RayCastGamePlayCamera()
    end

    local prop = CreateObject(modelName, coords.x, coords.y, coords.z + Config.objectOptions.propSpawnHeight, true, false, true)
    if not prop or prop == 0 then
        Notify('notify.create_failed', nil, 'error')
        SetModelAsNoLongerNeeded(modelName)
        return
    end

    FreezeEntityPosition(prop, true)
    SetEntityAlpha(prop, 180, false)
    SetEntityCollision(prop, false, false)
    SetEntityCoordsNoOffset(prop, coords.x, coords.y, coords.z, false, false, false, true)
    PlaceObjectOnGroundProperly(prop)

    local heading = 0.0
    local lastCoords = vector3(coords.x, coords.y, coords.z)
    local lastHeading = heading
    local groupName = CreateVarString(10, 'LITERAL_STRING', Lang:t('prompts.group'))
    local lastRaycastTime = 0
    local lastGroundSnapTime = GetGameTimer()

    while true do
        Wait(0)

        local now = GetGameTimer()
        if now - lastRaycastTime >= Config.objectOptions.raycastUpdateMs then
            lastRaycastTime = now
            hit, coords = RayCastGamePlayCamera()
            if hit == 1 and coords then
                local dx = coords.x - lastCoords.x
                local dy = coords.y - lastCoords.y
                local dz = coords.z - lastCoords.z
                if math.abs(dx) > Config.objectOptions.movementThreshold or math.abs(dy) > Config.objectOptions.movementThreshold or math.abs(dz) > Config.objectOptions.movementThreshold then
                    SetEntityCoordsNoOffset(prop, coords.x, coords.y, coords.z, false, false, false, true)
                    if now - lastGroundSnapTime >= Config.objectOptions.groundSnapInterval then
                        PlaceObjectOnGroundProperly(prop)
                        lastGroundSnapTime = now
                    end
                    lastCoords = vector3(coords.x, coords.y, coords.z)
                end
            end
        end

        PromptSetActiveGroupThisFrame(PromptPlacerGroup, groupName)
        DrawPropAxes(prop)

        local rotationChanged = false
        if IsControlPressed(1, Config.controlHash.ROTATE_LEFT) then
            heading += Config.objectOptions.rotationStep
            rotationChanged = true
        elseif IsControlPressed(1, Config.controlHash.ROTATE_RIGHT) then
            heading -= Config.objectOptions.rotationStep
            rotationChanged = true
        end

        if heading >= 360.0 then
            heading -= 360.0
        elseif heading < 0.0 then
            heading += 360.0
        end

        if rotationChanged and heading ~= lastHeading then
            SetEntityHeading(prop, heading)
            lastHeading = heading
        end

        if PromptHasHoldModeCompleted(Prompts.place) then
            break
        end

        if PromptHasHoldModeCompleted(Prompts.cancel) then
            DeleteEntity(prop)
            SetModelAsNoLongerNeeded(modelName)
            return
        end
    end

    SetEntityAlpha(prop, 255, false)
    SetEntityCollision(prop, true, true)
    FreezeEntityPosition(prop, false)

    local playerPed = PlayerPedId()
    local propCoords = GetEntityCoords(prop)

    TaskGoStraightToCoord(playerPed, propCoords.x, propCoords.y, propCoords.z, 1.0, -1, GetEntityHeading(playerPed), 0.0)

    local playerPosition = GetEntityCoords(playerPed)
    while Vdist(playerPosition.x, playerPosition.y, playerPosition.z, propCoords.x, propCoords.y, propCoords.z) > Config.objectOptions.minDistanceToProp do
        Wait(0)
        playerPosition = GetEntityCoords(playerPed)
    end

    ClearPedTasksImmediately(playerPed)
    FreezeEntityPosition(playerPed, true)

    local headingToProp = GetHeadingFromVector_2d(propCoords.x - playerPosition.x, propCoords.y - playerPosition.y)
    SetEntityHeading(playerPed, headingToProp)

    local animDict = "amb_work@world_human_hammer@wall@male_a@trans"
    local animName = "a_trans_kneel_a"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    TaskPlayAnim(playerPed, animDict, animName, 4.0, -4.0, -1, 1, 0.0, false, 0, false, 0, false)

    Wait(Config.objectOptions.animationDuration)

    FreezeEntityPosition(prop, true)

    local savedCoords = GetEntityCoords(prop)
    local rot = GetEntityRotation(prop, 2)

    TriggerServerEvent('tk_placeable:server:saveProp', modelName, savedCoords, rot)

    if fromItemName then
        TriggerServerEvent('tk_placeable:server:consumeItem', fromItemName)
    end

    applyTargetToProp(prop)
    table.insert(spawnedProps, prop)
    Notify('notify.prop_saved', nil, 'success')

    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)
    SetModelAsNoLongerNeeded(modelName)
end

-----------------------------
-- EVENTS
-----------------------------
RegisterNetEvent("tk_placeable:client:placeSingleProp", function(modelName)
    spawnProp(modelName, GetItemNameFromModel(modelName))
end)

RegisterNetEvent('tk_placeable:client:loadProp', function(modelName, pos, rot)
    lib.requestModel(modelName)
    local prop = CreateObject(GetHashKey(modelName), pos.x, pos.y, pos.z, false, false, false, false, true)
    SetEntityRotation(prop, rot.x, rot.y, rot.z, 2, true)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    applyTargetToProp(prop)

    table.insert(spawnedProps, prop)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print(Lang:t('debug.resource_stopping'))
    for _, prop in ipairs(spawnedProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
            DeleteObject(prop)
        end
    end
    spawnedProps = {}
end)

InitializePrompts()