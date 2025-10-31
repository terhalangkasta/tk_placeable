local spawnedProps = {}
local placing = false
local currentModelName = nil
local currentItemName = nil
local currentProp = nil -- tetap dipakai saat sedang placing
local confirmed = false
local heading = 0.0

local PromptPlacerGroup = GetRandomIntInRange(0, 0xffffff)

-----------------------------
-- FUNCTIONS
-----------------------------
function GetItemNameFromModel(model)
    for _, prop in ipairs(propsConfig.availableProps) do
        if prop.model == model then
            return prop.item
        end
    end
    return nil
end

function notify(msg)
    lib.notify({
        title = 'Prop Placer',
        description = msg,
        type = 'inform'
    })
end

function GetEntityInFront(pos, distance)
    local heading = GetEntityHeading(PlayerPedId())
    local forward = GetForwardVectorFromHeading(heading)
    local targetPos = pos + (forward * distance)

    local ray = StartShapeTestRay(pos.x, pos.y, pos.z, targetPos.x, targetPos.y, targetPos.z, 16, PlayerPedId(), 0)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    return (hit == 1 and entity or nil)
end

function GetForwardVectorFromHeading(heading)
    local rad = math.rad(heading)
    return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

function GetPropNameFromHash(hash)
    if not hash then
        print("[ERROR] GetPropNameFromHash: Hash is nil")
        return nil
    end

    for _, prop in ipairs(propsConfig.availableProps) do
        local model = prop.model
        if model and GetHashKey(model) == hash then
            return model
        end
    end

    print(string.format("[DEBUG] No matching prop found for hash: %s", hash))
    return nil
end

function GetLabelFromModel(modelName)
    for _, prop in ipairs(propsConfig.availableProps) do
        if prop.model == modelName then
            return prop.label
        end
    end
    return "Tidak Dikenal"
end


function applyTargetToProp(propEntity)
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
            label = ("Pickup : %s"):format(labelName),

            onSelect = function(data)
                local entity = data.entity
                if not entity or not DoesEntityExist(entity) then
                    print("[ERROR] onSelect: Invalid or nil entity:", entity)
                    return
                end

                local coords = GetEntityCoords(entity)
                DeleteEntity(entity)
                TriggerServerEvent('rsm_placeable:deleteProp', modelName, {
                    x = coords.x, y = coords.y, z = coords.z
                })

                for i = #spawnedProps, 1, -1 do
                    if spawnedProps[i] == entity then
                        table.remove(spawnedProps, i)
                        break
                    end
                end

                notify("Prop dihapus.")
                print(string.format("[INFO] Deleted prop '%s' at coords %s", modelName, coords))
            end
        }
    })
end

-- Fungsi Prompt Setup (Sama seperti yang kamu punya)
function Del()
    local str = 'Cancel'
    CancelPrompt = PromptRegisterBegin()
    PromptSetControlAction(CancelPrompt, 0xF84FA74F)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(CancelPrompt, str)
    PromptSetEnabled(CancelPrompt, true)
    PromptSetVisible(CancelPrompt, true)
    PromptSetHoldMode(CancelPrompt, true)
    PromptSetGroup(CancelPrompt, PromptPlacerGroup)
    PromptRegisterEnd(CancelPrompt)
end

function Set()
    local str = 'Place'
    SetPrompt = PromptRegisterBegin()
    PromptSetControlAction(SetPrompt, 0xC7B5340A)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(SetPrompt, str)
    PromptSetEnabled(SetPrompt, true)
    PromptSetVisible(SetPrompt, true)
    PromptSetHoldMode(SetPrompt, true)
    PromptSetGroup(SetPrompt, PromptPlacerGroup)
    PromptRegisterEnd(SetPrompt)
end

function RotateLeft()
    local str = 'Rotate Left'
    RotateLeftPrompt = PromptRegisterBegin()
    PromptSetControlAction(RotateLeftPrompt, 0xA65EBAB4)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(RotateLeftPrompt, str)
    PromptSetEnabled(RotateLeftPrompt, true)
    PromptSetVisible(RotateLeftPrompt, true)
    PromptSetStandardMode(RotateLeftPrompt, true)
    PromptSetGroup(RotateLeftPrompt, PromptPlacerGroup)
    PromptRegisterEnd(RotateLeftPrompt)
end

function RotateRight()
    local str = 'Rotate Right'
    RotateRightPrompt = PromptRegisterBegin()
    PromptSetControlAction(RotateRightPrompt, 0xDEB34313)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(RotateRightPrompt, str)
    PromptSetEnabled(RotateRightPrompt, true)
    PromptSetVisible(RotateRightPrompt, true)
    PromptSetStandardMode(RotateRightPrompt, true)
    PromptSetGroup(RotateRightPrompt, PromptPlacerGroup)
    PromptRegisterEnd(RotateRightPrompt)
end

function RotationToDirection(rotation)
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

function DrawPropAxes(prop)
    local propForward, propRight, propUp, propCoords = GetEntityMatrix(prop)

    local propXAxisEnd = propCoords + propRight * 0.20
    local propYAxisEnd = propCoords + propForward * 0.20
    local propZAxisEnd = propCoords + propUp * 0.20

    DrawLine(propCoords.x, propCoords.y, propCoords.z + 0.1, propXAxisEnd.x, propXAxisEnd.y, propXAxisEnd.z, 255, 0, 0, 255)
    DrawLine(propCoords.x, propCoords.y, propCoords.z + 0.1, propYAxisEnd.x, propYAxisEnd.y, propYAxisEnd.z, 0, 255, 0, 255)
    DrawLine(propCoords.x, propCoords.y, propCoords.z + 0.1, propZAxisEnd.x, propZAxisEnd.y, propZAxisEnd.z, 0, 0, 255, 255)
end

function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    local a, hit, coords, d, e = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0))
    return hit, coords, e
end

function spawnProp(modelName, fromItemName)
    if type(modelName) ~= "string" then
        notify("Model tidak valid.")
        return
    end

    lib.requestModel(modelName)

    local hit, coords, entity
    while not hit do
        hit, coords, entity = RayCastGamePlayCamera(1000.0)
        Wait(0)
    end

    local prop = CreateObject(modelName, coords.x, coords.y, coords.z + 2.0, true, false, true)
    FreezeEntityPosition(prop, true)
    SetEntityAlpha(prop, 180, false)
    SetEntityCollision(prop, false, false)

    local heading = 0.0

    while true do
        hit, coords, entity = RayCastGamePlayCamera(1000.0)
        SetEntityCoordsNoOffset(prop, coords.x, coords.y, coords.z, false, false, false, true)
        PlaceObjectOnGroundProperly(prop)
        DrawPropAxes(prop)

        local groupName = CreateVarString(10, 'LITERAL_STRING', 'ROSESMILES PLACEBALES')
        PromptSetActiveGroupThisFrame(PromptPlacerGroup, groupName)

        if IsControlPressed(1, 0xA65EBAB4) then
            heading += 1.0
        elseif IsControlPressed(1, 0xDEB34313) then
            heading -= 1.0
        end

        if heading > 360.0 then heading = 0.0 end
        if heading < 0.0 then heading = 360.0 end

        SetEntityHeading(prop, heading)

        if PromptHasHoldModeCompleted(SetPrompt) then
            break
        end

        if PromptHasHoldModeCompleted(CancelPrompt) then
            DeleteEntity(prop)
            SetModelAsNoLongerNeeded(modelName)
            return
        end

        Wait(0)
    end

    -- Lanjutkan penempatan (langsung, tanpa perlu F)
    SetEntityAlpha(prop, 255, false)
    SetEntityCollision(prop, true, true)
    FreezeEntityPosition(prop, false)

    local playerPed = PlayerPedId()
    local propCoords = GetEntityCoords(prop)

    TaskGoStraightToCoord(playerPed, propCoords.x, propCoords.y, propCoords.z, 1.0, -1, GetEntityHeading(playerPed), 0.0)

    while #(GetEntityCoords(playerPed) - propCoords) > 1.2 do
        Wait(0)
    end

    ClearPedTasksImmediately(playerPed)
    FreezeEntityPosition(playerPed, true)

    local headingToProp = GetHeadingFromVector_2d(propCoords.x - GetEntityCoords(playerPed).x, propCoords.y - GetEntityCoords(playerPed).y)
    SetEntityHeading(playerPed, headingToProp)

    local animDict = "amb_work@world_human_hammer@wall@male_a@trans"
    local animName = "a_trans_kneel_a"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end
    TaskPlayAnim(playerPed, animDict, animName, 4.0, -4.0, -1, 1, 0.0, false, 0, false, 0, false)

    Wait(2000) -- Durasi animasi secukupnya

    FreezeEntityPosition(prop, true)

    local coords = GetEntityCoords(prop)
    local rot = GetEntityRotation(prop, 2)

    TriggerServerEvent('rsm_placeable:server:saveProp', modelName, coords, rot)

    if fromItemName then
        TriggerServerEvent('rsm_placeable:server:consumeItem', fromItemName)
    end

    if applyTargetToProp then
        applyTargetToProp(prop)
    end

    table.insert(spawnedProps, prop)
    notify("Prop disimpan.")

    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)
end

-----------------------------
-- EVENTS
-----------------------------
RegisterNetEvent("rsm_placeable:client:placeSingleProp", function(modelName)
    spawnProp(modelName, GetItemNameFromModel(modelName))
end)

RegisterNetEvent('rsm_placeable:client:loadProp', function(modelName, pos, rot)
    lib.requestModel(modelName)
    local prop = CreateObject(GetHashKey(modelName), pos.x, pos.y, pos.z, false, false, false, false, true)
    SetEntityRotation(prop, rot.x, rot.y, rot.z, 2, true)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    applyTargetToProp(prop)

    table.insert(spawnedProps, prop) -- Tambahkan ke array
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print("[DEBUG] Resource berhenti. Menghapus semua prop...")
    for _, prop in ipairs(spawnedProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
            DeleteObject(prop)
        end
    end
    spawnedProps = {} -- Kosongkan array
end)

-----------------------------
-- LOOPING
-----------------------------
CreateThread(function()
    Set()
    Del()
    RotateLeft()
    RotateRight()
end)