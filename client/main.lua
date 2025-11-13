local spawnedProps = {}
local PromptPlacerGroup = GetRandomIntInRange(0, 0xffffff)

local Prompts = {
    cancel = nil,
    place = nil,
    rotate = nil,
    moveHorizontal = nil,
    moveVertical = nil
}

local function NormalizeVector3(value)
    if not value then
        return nil
    end
    local valueType = type(value)
    if valueType == "vector3" or valueType == "vector4" then
        return { x = value.x, y = value.y, z = value.z }
    end
    if valueType == "table" then
        if type(value.x) == "number" and type(value.y) == "number" and type(value.z) == "number" then
            return { x = value.x, y = value.y, z = value.z }
        end
        if type(value[1]) == "number" and type(value[2]) == "number" and type(value[3]) == "number" then
            return { x = value[1], y = value[2], z = value[3] }
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

local function CreatePrompt(label, controlHashes, holdMode)
    local prompt = PromptRegisterBegin()
    if type(controlHashes) ~= "table" then
        controlHashes = { controlHashes }
    end
    for _, controlHash in ipairs(controlHashes) do
        PromptSetControlAction(prompt, controlHash)
    end
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
    Prompts.rotate = CreatePrompt(Lang:t('prompts.rotate'), { Config.controlHash.ROTATE_LEFT, Config.controlHash.ROTATE_RIGHT }, false)
    Prompts.moveHorizontal = CreatePrompt(Lang:t('prompts.move_horizontal'), { Config.controlHash.MOVE_LEFT, Config.controlHash.MOVE_RIGHT }, false)
    Prompts.moveVertical = CreatePrompt(Lang:t('prompts.move_vertical'), { Config.controlHash.MOVE_DOWN, Config.controlHash.MOVE_UP }, false)
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

local function spawnProp(modelName)
    if type(modelName) ~= "string" then
        Notify('notify.invalid_model', nil, 'error')
        return
    end

    lib.requestModel(modelName)

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local forward = GetEntityForwardVector(playerPed)
    local placementDistance = Config.objectOptions.defaultPlacementDistance
    local baseCoords = vector3(
        playerCoords.x + forward.x * placementDistance,
        playerCoords.y + forward.y * placementDistance,
        playerCoords.z + forward.z * placementDistance
    )

    local prop = CreateObject(modelName, baseCoords.x, baseCoords.y, baseCoords.z + Config.objectOptions.propSpawnHeight, true, false, true)
    if not prop or prop == 0 then
        Notify('notify.create_failed', nil, 'error')
        SetModelAsNoLongerNeeded(modelName)
        return
    end

    FreezeEntityPosition(prop, true)
    SetEntityAlpha(prop, 180, false)
    SetEntityCollision(prop, false, false)
    SetEntityCoordsNoOffset(prop, baseCoords.x, baseCoords.y, baseCoords.z, false, false, false, true)
    PlaceObjectOnGroundProperly(prop)

    local heading = GetEntityHeading(playerPed)
    local lastHeading = heading
    SetEntityHeading(prop, heading)
    local groupName = CreateVarString(10, 'LITERAL_STRING', Lang:t('prompts.group'))
    local moveStep = Config.objectOptions.translationStep
    local verticalStep = Config.objectOptions.verticalStep or moveStep
    while true do
        Wait(0)

        PromptSetActiveGroupThisFrame(PromptPlacerGroup, groupName)
        DrawPropAxes(prop)

        local moveVector = vector3(0.0, 0.0, 0.0)
        local _, propRight = GetEntityMatrix(prop)

        if propRight and IsControlPressed(1, Config.controlHash.MOVE_LEFT) then
            moveVector = moveVector - (propRight * moveStep)
        end

        if propRight and IsControlPressed(1, Config.controlHash.MOVE_RIGHT) then
            moveVector = moveVector + (propRight * moveStep)
        end

        if IsControlPressed(1, Config.controlHash.MOVE_UP) then
            moveVector = moveVector + vector3(0.0, 0.0, verticalStep)
        end

        if IsControlPressed(1, Config.controlHash.MOVE_DOWN) then
            moveVector = moveVector - vector3(0.0, 0.0, verticalStep)
        end

        if moveVector.x ~= 0.0 or moveVector.y ~= 0.0 or moveVector.z ~= 0.0 then
            local propCoords = GetEntityCoords(prop)
            local targetCoords = propCoords + moveVector
            SetEntityCoordsNoOffset(prop, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, true)
        end

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

    local savedCoords = NormalizeVector3(GetEntityCoords(prop))
    local rot = NormalizeVector3(GetEntityRotation(prop, 2))

    if not savedCoords or not rot then
        DeleteEntity(prop)
        FreezeEntityPosition(playerPed, false)
        SetModelAsNoLongerNeeded(modelName)
        return
    end

    TriggerServerEvent('tk_placeable:server:saveProp', modelName, savedCoords, rot)

    applyTargetToProp(prop)
    table.insert(spawnedProps, prop)
    Notify('notify.prop_saved', nil, 'success')

    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)
    SetModelAsNoLongerNeeded(modelName)
end

RegisterNetEvent("tk_placeable:client:placeSingleProp", function(modelName)
    spawnProp(modelName)
end)

RegisterNetEvent('tk_placeable:client:loadProp', function(modelName, pos, rot)
    local savedCoords = NormalizeVector3(pos)
    if not savedCoords then
        return
    end

    local savedRotation = NormalizeVector3(rot)
    if not savedRotation then
        savedRotation = { x = 0.0, y = 0.0, z = 0.0 }
    end

    lib.requestModel(modelName)

    local prop = CreateObject(GetHashKey(modelName), savedCoords.x, savedCoords.y, savedCoords.z, false, false, false, false, true)
    SetEntityCoordsNoOffset(prop, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false, true)
    SetEntityRotation(prop, savedRotation.x, savedRotation.y, savedRotation.z, 2, true)
    SetEntityCollision(prop, true, true)
    FreezeEntityPosition(prop, true)
    applyTargetToProp(prop)
    SetModelAsNoLongerNeeded(modelName)

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
