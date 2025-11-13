local Translations = {
    notify = {
        title = 'Prop Placer',
        invalid_model = 'Invalid model.',
        create_failed = 'Failed to create prop.',
        prop_saved = 'Prop saved.',
        prop_removed = 'Prop removed.'
    },
    text = {
        unknown_prop = 'Unknown',
        pickup = 'Pick up: %{label}'
    },
    prompts = {
        cancel = 'Cancel',
        place = 'Place',
        rotate = 'Rotate Left/Right',
        move_horizontal = 'Move Left/Right',
        move_depth = 'Bring Forward/Send Backward',
        move_vertical = 'Move Down/Up',
        group = 'TK PLACEABLES'
    },
    debug = {
        no_prop_match = 'No matching prop found for hash: %{hash}',
        resource_stopping = 'Resource stopping. Removing all props...'
    },
    logs = {
        invalid_coords = '[ERROR] Invalid coordinates received from client: %{coords}',
        db_deleted = '[INFO] Deleted prop from database: model=%{model}, coords=%{coords}',
        loading = '^2[tk_placeable]^7 Loading placed props from database...',
        load_failed = '^1[ERROR]^7 Failed to load props from database: %{error}',
        loaded_count = '^2[tk_placeable]^7 Loaded %{count} props.',
        reload_complete = '[tk_placeable] Props from the database have been reloaded.'
    },
    command = {
        no_permission = 'You do not have permission to run this command.'
    }
}

Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
