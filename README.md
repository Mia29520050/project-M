# Moonveil — Anime Fantasy RPG

A lightweight 2.5D/isometric anime-fantasy RPG prototype for Godot 4.7.2. Characters and environment decorations are built from procedural 3D meshes; the current build is a greybox slice focused on movement, combat, a short run, and returning safely to the Refuge.

## Run

Open project.godot with Godot 4.7.2 and press F5 to run the project. The entry scene is scenes/refuge.tscn; F6 runs the currently open scene.

On Bazzite, launch it with:
flatpak run org.godotengine.Godot --path ~/Projects/AnimeFantasyRPG

## Controls

### Refuge
- WASD — Move.
- E — Begin a run in Whispering Woods when close to the Moon Shrine.
- Esc — Pause/resume; a PAUSED label appears while paused.

### During a run
- WASD — Move.
- Left mouse button — Strike a nearby Voidling.
- Space — Dodge; 2 charges are available and recharge over time.
- Q — Fire a homing Moonbolt at the nearest Voidling within range (15 Mana; 24 base damage). It does not aim with the mouse cursor.
- I — Open/close the satchel; opening it pauses the run.
- Esc — Close the satchel or toggle the pause menu.
- E — At the Moon Shrine, awaken the Apprentice Wand into the Moonfire Staff after collecting 3 Moonshards.

## Current playable loop

1. Enter Whispering Woods from the Refuge using E near the Moon Shrine.
2. Fight Voidlings, gain XP, level up, and collect dropped Moonshards.
3. Collect 3 Moonshards and use the Moon Shrine during the run to awaken the Moonfire Staff.
4. Complete the opening quest by defeating 5 Voidlings; enemies can respawn so combat can continue.
5. When HP reaches zero, the death banner appears and the run returns to the Refuge after a short delay.

Each run uses a fresh Player, so run level, XP, Moonshards, and temporary equipment do not carry into the next run. The MoonveilMeta autoload keeps long-term fields separate from the run and saves permanent_currency, permanent_upgrades, story_flags, and unlocked_regions to user://moonveil_meta.json. The permanent progression scaffold is not yet connected to a complete shop or earn/spend loop.

## Current scope and limitations

This is a prototype, not a finished commercial-quality game. Character shapes and environment details are placeholders built from primitives. Full character/world save data, a meta-upgrade shop, dialogue trees, audio, crafting, detailed animation rigs, and a complete map are not implemented yet.

## Project structure

- scenes/refuge.tscn — entry scene / safe hub.
- scenes/main.tscn — Whispering Woods run scene.
- scenes/player.tscn and scripts/player.gd — movement, combat, stats, XP, and run equipment.
- scenes/enemy.tscn and scripts/enemy.gd — Voidling AI, telegraphed attacks, contact damage, and loot.
- scenes/magic_bolt.tscn and scripts/magic_bolt.gd — homing Moonbolt.
- scripts/refuge_controller.gd — Refuge world, HUD, pause label, and run transition.
- scripts/game_controller.gd — run world, quest, camera, combat UI, pause/death panels, and enemy spawning.
- scripts/moonveil_meta.gd — persistent long-term progression data.
- docs/ROADMAP.md — longer-term development plan.
