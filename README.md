# tk_placeable
Requires rsg-core, ox_lib, oxmysql! Persistent ranch props synced across the server!

# Features
- Configurable placement controls: Prompt bindings, raycast range, rotation step, and snap timing (shared/config.lua:3-20).
- Item-gated props: Useable inventory items spawn matching models and refund on pickup (server/main.lua:60-64, server/main.lua:33-43).
- Database persistence: Props saved, reloaded on start, and streamed to joining players (server/main.lua:67-133).
- Target integration: ox_target pickup prompt with dynamic labels (client/main.lua:58-98).
- Placement assistance: Camera raycast, ground snapping, rotation visualization, and placement animation (client/main.lua:141-313).

# Description
- Standalone prop placement system letting players deploy ranch objects, align them live, and persist them via MySQL while keeping recovery tied to inventory items (client/main.lua:175-313, server/main.lua:67-133).

# Commands
- loadprops: Reload all stored props from the database (server/main.lua:109-118).