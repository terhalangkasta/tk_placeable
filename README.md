# tk_placeable
Requires rsg-core, ox_lib, oxmysql! Persistent props synced across the server!

# Features
- Configurable placement controls: Prompt bindings, raycast range, rotation step, and snap timing.
- Item-gated props: Useable inventory items spawn matching models and refund on pickup.
- Database persistence: Props saved, reloaded on start, and streamed to joining players.
- Target integration: ox_target pickup prompt with dynamic labels.
- Placement assistance: Camera raycast, ground snapping, rotation visualization, and placement animation.

# Description
- Standalone prop placement system letting players deploy objects, align them live, and persist them via MySQL while keeping recovery tied to inventory items.

# Commands
- loadprops: Reload all stored props from the database.
