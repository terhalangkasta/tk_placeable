# tk_placeable

RedM placeable-prop resource for `rsg-core` with `ox_lib`, `ox_target`, and `oxmysql`.

## Features
- Item-gated prop placement (using an inventory item spawns a placement preview)
- Live placement preview with prompt-driven move/rotate/depth/vertical controls
- Persistent storage in DB (`tk_placeable`) with broadcast-on-change sync
- Distance-validated save and delete (anti-cheat) plus per-action rate limits
- ox_target pickup that refunds the matching item
- Auto-engaging performance mode on busy servers (batched streaming, softer cooldowns)
- Admin command `/loadprops` to reload everything from the database

## Structure
```
tk_placeable/
|-- client/main.lua
|-- server/main.lua
|-- config/
|   |-- client.lua
|   |-- server.lua
|   `-- shared.lua
|-- locales/
|   |-- en.json
|   `-- id.json
`-- installation/
    |-- items.lua
    `-- tk_placeable.sql
```

## Dependencies
- rsg-core
- ox_lib
- ox_target
- oxmysql

## Installation
1. Drop `installation/items.lua` entries into your `rsg-core` shared items.
2. Either run `installation/tk_placeable.sql` or just start the resource (it
   creates the table automatically).
3. Add `ensure tk_placeable` to your server config.

## Commands
- `/loadprops` (ace `command.loadprops`, or rsg admin/god): reload props from DB.
- `/placeable_debug` (client): print local cache stats.

## Support
- [TK Scripts](https://discord.gg/Xj5YYPsWej)
