Config = {}

Config.controlHash = {
    ROTATE_LEFT = 0x7065027D,
    ROTATE_RIGHT = 0xB4E465B4,
    PLACE = 0xC7B5340A,
    CANCEL = 0x156F7119,
    MOVE_LEFT = 0xA65EBAB4,
    MOVE_RIGHT = 0xDEB34313,
    MOVE_UP = 0x6319DB71,
    MOVE_DOWN = 0x05CA7C52,
    BRING_FORWARD = 0x4AF4D473,
    SEND_BACKWARD = 0x3C3DD371
}

Config.objectOptions = {
    axisLength = 0.20,
    propSpawnHeight = 2.0,
    animationDuration = 2000,
    minDistanceToProp = 1.2,
    rotationStep = 1.0,
    translationStep = 0.05,
    verticalStep = 0.05,
    defaultPlacementDistance = 2.0
}

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