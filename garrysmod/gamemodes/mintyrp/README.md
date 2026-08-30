# MintyRP

Custom serious roleplay gamemode for Garry's Mod — lightweight Perpheads-style framework, **not** based on DarkRP. Built for `rp_rockford_v2b`.

## Install

1. Copy `garrysmod/gamemodes/mintyrp` into your server's `garrysmod/gamemodes/` folder.
2. Install the map [RP Rockford v2](https://steamcommunity.com/sharedfiles/filedetails/?id=622810630) (`rp_rockford_v2b`) plus its content pack / CS:S.
3. Host the `loading/` folder on HTTPS (GitHub Pages, Cloudflare Pages, etc.).
4. Merge settings from `cfg/server.cfg.example` into `garrysmod/cfg/server.cfg`, especially:

```
hostname "MintyRP | Rockford"
sv_loadingurl "https://YOUR_HOST/mintyrp/loading/index.html?steamid=%s"
```

5. Start with `+gamemode mintyrp +map rp_rockford_v2b`.

The main-menu / home-screen logo is `logo.png` (+ `icon24.png`) in the gamemode root — GMod picks these up automatically when the gamemode is installed.

## Controls

| Key | Action |
|-----|--------|
| F2 | Toggle inventory |

Superadmins: `mintyrp_dumppos` prints your current Vector/Angle for updating location tables.

## Layout

```
mintyrp/
  logo.png            Main menu / home-screen logo
  icon24.png          24×24 menu icon
  mintyrp.txt
  cfg/server.cfg.example
  loading/            Custom join loading screen (HTML)
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

## How to smoke-test

Yes — test this before stacking more systems. Fastest path is a **listen server** on your own PC:

1. Copy `garrysmod/gamemodes/mintyrp` into your local `GarrysMod/garrysmod/gamemodes/`.
2. Subscribe to [RP Rockford v2](https://steamcommunity.com/sharedfiles/filedetails/?id=622810630) (+ content / CS:S).
3. Main menu → **Create Multiplayer** → map `rp_rockford_v2b` → gamemode **MintyRP** → Start.
4. Confirm checklist:
   - [ ] Console shows `[MintyRP] Autoload complete` and `SQLite database ready`
   - [ ] Gamemode logo appears in the mode picker (`logo.png`)
   - [ ] Character menu opens on join; create `First Last` + pick a model
   - [ ] You spawn, HUD shows RP name + money
   - [ ] **F2** opens inventory with starter items (water, sandwich, phone)
   - [ ] Reconnect → character list shows your slot; select works
   - [ ] `mintyrp_dumppos` (superadmin) prints a Vector

If create fails with a database error: as host run `mintyrp_dbreset` in console, reconnect, try again.

Optional loading screen: host `loading/` on HTTPS, set `sv_loadingurl` from `cfg/server.cfg.example`, join a dedicated server once.

If something fails, copy the **red console errors** from client + server — that’s enough to fix the next pass.

## What's next (to reach Perpheads-like depth)

Priority systems still needed beyond this foundation:

1. ~~**Character creation**~~ — name, model, 3 slots (done)
2. **Property / doors** — ownable apartments & storefronts on Rockford; keys; eviction
3. **Storage boxes** — dual-pane inventory ↔ property storage (drag/drop, search, categories)
4. **Economy** — ATM/bank, paychecks, shops/NPCs, crafting + workbench queue
5. **Jobs & duty** — PD / EMS / fire whitelists, vehicles, cuff/drag/jail, medicals
6. **Vehicles** — dealership, keys, fuel, impound, lockpicking rules
7. **Phone / radio** — texts, contacts, 911, org channels
8. **HUD & F1/Q menus** — needs, laws, scoreboard, animation menu
9. **Admin / mod tools** — sit, warn, spectate, logs; anti-RDM helpers
10. **Map polish** — replace placeholder Vectors via `mintyrp_dumppos`; zone triggers
11. **Workshop content pack** — custom models/materials + FastDL/`sv_downloadurl`
12. **MySQL option** — scale beyond SQLite for multi-server

## Notes

- Location coordinates in `modules/locations/sh_locations.lua` are **placeholders**. Walk the map, run `mintyrp_dumppos`, and replace Vectors.
- Inventory supports weight limits, categories, use/drop, and a storage-transfer stub.
- All `net.Receive` handlers validate inputs server-side.
- Loading screen details: [`loading/README.md`](loading/README.md).
