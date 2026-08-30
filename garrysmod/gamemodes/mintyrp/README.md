# MintyRP

Custom serious roleplay gamemode for Garry's Mod — lightweight Perpheads-style framework, **not** based on DarkRP. Built for `rp_rockford_v2b`.

## Install

1. Copy `garrysmod/gamemodes/mintyrp` into your server's `garrysmod/gamemodes/` folder.
2. Install the map [RP Rockford v2](https://steamcommunity.com/sharedfiles/filedetails/?id=622810630) (`rp_rockford_v2b`) plus its content pack / CS:S.
3. In `server.cfg` (or command line):

```
hostname "MintyRP | Rockford"
gamemode mintyrp
map rp_rockford_v2b
```

4. Start the dedicated server (or listen server) and select **MintyRP** from the gamemode list.

## Controls

| Key | Action |
|-----|--------|
| F2 | Toggle inventory |

Superadmins: `mintyrp_dumppos` prints your current Vector/Angle for updating location tables.

## Layout

```
mintyrp/
  mintyrp.txt
  gamemode/
    init.lua          Server entry (GM hooks, net strings)
    cl_init.lua       Client entry
    shared.lua        Autoloader (sh_/sv_/cl_ prefixes)
    core/
      sh_config.lua
      sh_util.lua
      sh_playerclass.lua
      sv_database.lua   SQLite persistence
      sv_player.lua     Load/save/spawn
      cl_hud.lua
    modules/
      inventory/        Weight + category inventory
      locations/        Rockford v2b placeholders
      character/
      player/           Job stubs
```

## Notes

- Location coordinates in `modules/locations/sh_locations.lua` are **placeholders**. Walk the map, run `mintyrp_dumppos`, and replace Vectors.
- Inventory supports weight limits, categories, use/drop, and a storage-transfer stub (Perpheads-like dual-pane UI comes next).
- All `net.Receive` handlers validate inputs server-side.
