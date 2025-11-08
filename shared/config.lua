Config = {}

Config.controlHash = {
    ROTATE_LEFT = 0xA65EBAB4,
    ROTATE_RIGHT = 0xDEB34313,
    PLACE = 0xC7B5340A,
    CANCEL = 0xF84FA74F
}

Config.objectOptions = {
    axisLength = 0.20,
    raycastDistance = 1000.0,
    propSpawnHeight = 2.0,
    animationDuration = 2000,
    minDistanceToProp = 1.2,
    rotationStep = 1.0,
    movementThreshold = 0.005,
    raycastUpdateMs = 75,
    groundSnapInterval = 150
}

---------------------------------
-- PROPS
---------------------------------
Config.availableProps = {
    { label = "Fence",           model = "val_fencepen01_ax",               item = "fence_prop_1" },
    { label = "Fence 2",         model = "val_fencepen01_bx",               item = "fence_prop_2" },
    { label = "Fence 3",         model = "val_fencepen01_cx",               item = "fence_prop_3" },
    { label = "Hay 1",           model = "p_haypile01x",                    item = "hay_prop_1" },
    { label = "Hay 2",           model = "p_haypile02x",                    item = "hay_prop_2" },
    { label = "Hay 3",           model = "p_haypile03x",                    item = "hay_prop_3" },
    { label = "Hay 4",           model = "p_haypile04x",                    item = "hay_prop_4" },
    { label = "Fertilizer 1",    model = "p_horsepoop02x",                  item = "fertilizer_prop_1" }
}