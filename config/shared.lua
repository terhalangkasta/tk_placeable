return {
    debug = false,

    --- Available props (model + matching inventory item)
    props = {
        { label = 'Fence',         model = 'val_fencepen01_ax', item = 'fence_prop_1'      },
        { label = 'Fence 2',       model = 'val_fencepen01_bx', item = 'fence_prop_2'      },
        { label = 'Fence 3',       model = 'val_fencepen01_cx', item = 'fence_prop_3'      },
        { label = 'Hay 1',         model = 'p_haypile01x',      item = 'hay_prop_1'        },
        { label = 'Hay 2',         model = 'p_haypile02x',      item = 'hay_prop_2'        },
        { label = 'Hay 3',         model = 'p_haypile03x',      item = 'hay_prop_3'        },
        { label = 'Hay 4',         model = 'p_haypile04x',      item = 'hay_prop_4'        },
        { label = 'Fertilizer 1',  model = 'p_horsepoop02x',    item = 'fertilizer_prop_1' },
    },

    controls = {
        rotateLeft   = 0x7065027D,
        rotateRight  = 0xB4E465B4,
        place        = 0xC7B5340A,
        cancel       = 0x156F7119,
        moveLeft     = 0xA65EBAB4,
        moveRight    = 0xDEB34313,
        moveUp       = 0x6319DB71,
        moveDown     = 0x05CA7C52,
        bringForward = 0x4AF4D473,
        sendBackward = 0x3C3DD371,
    },

    placement = {
        axisLength               = 0.20,
        propSpawnHeight          = 2.0,
        animationDurationMs      = 2000,
        rotationStep             = 1.0,
        translationStep          = 0.05,
        verticalStep             = 0.05,
        defaultPlacementDistance = 2.0,
        approachTimeoutMs        = 5000,
        modelLoadTimeoutMs       = 10000,
    },

    --- Radius constants in meters
    radius = {
        request    = 100.0, -- client re-requests after moving this far
        stream     = 250.0, -- server streams props within this radius
        broadcast  = 250.0, -- save/delete broadcast reach
        pickup     = 1.2,   -- ox_target distance + delete radius
        pickupGate = 2.5,   -- server tolerance for matching delete coord -> stored prop
    },

    --- Anti-cheat / validation thresholds
    validation = {
        maxPlaceDistance = 8.0, -- max distance between player ped and saved coord
        worldMin         = -10000.0,
        worldMax         =  10000.0,
    },
}
