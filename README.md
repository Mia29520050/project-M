# Moonveil — Anime Fantasy RPG

A lightweight 2.5D/isometric anime-fantasy RPG prototype for Godot 4.7.2. Characters and environment decorations are built from procedural 3D meshes; the current build is a greybox slice focused on movement, combat, a short run, and returning safely to the Refuge.

## Run

Open project.godot with Godot 4.7.2 and press F5 to run the project. The entry scene is scenes/refuge.tscn; F6 runs the currently open scene.

On Bazzite, launch it with:
flatpak run org.godotengine.Godot --path ~/Projects/AnimeFantasyRPG

## Controls

### Refuge
- WASD — Move around the safe hub.
- Go to the **Wayfarers' Fire** and press E — open the character-selection panel.
- Click a character once to select; double-click to confirm immediately, or click once and press **Confirm Wayfarer**.
- Esc or Cancel — close character selection without changing the active hero.
- Go to the **Moon Shrine** and press E — enter Whispering Woods as the selected character.

### During a run — shared controls
- WASD — Move.
- Left mouse button — Attack; the duelist uses a three-hit chain.
- Space — Dodge; 2 charges are available and recharge over time.
- 1 / 2 / 3 — Use Minor / Standard / Greater healing potion; recovery is gradual and only one potion recovery can run at a time.
- I — Open/close the satchel; opening it pauses the run.
- Esc — Close the satchel or toggle the pause menu.

### Character-specific skill
- **Moonveil Mage:** Q — fire a homing Moonbolt at the nearest Voidling within range (15 Mana; 24 base damage); E at the shrine can awaken the Apprentice Wand after collecting 3 Moonshards.
- **Astra Vale, Sword Duelist:** Mouse 1 chains three close-range strikes (16 / 20 / 28 base damage). Q — Crescent Lunge, a mobile dash strike using 20 stamina, with a 4.5-second cooldown. The duelist does not use Moonbolt or the staff upgrade.

## Current playable loop

1. Visit the Wayfarers' Fire in the Refuge to choose either the Moonveil Mage or Astra Vale, Sword Duelist.
2. Enter Whispering Woods using E near the Moon Shrine; the chosen character is used in the run.
3. Fight Voidlings, gain XP, level up, and collect dropped Moonshards.
4. Collect 3 Moonshards and use the Moon Shrine during the run to awaken the Moonfire Staff (Mage only).
5. Complete the opening quest by defeating 5 Voidlings; enemies can respawn so combat can continue.
6. When HP reaches zero, the death banner appears and the run returns to the Refuge after a short delay.

Each run uses a fresh Player, so run level, XP, Moonshards, and temporary equipment do not carry into the next run. The MoonveilMeta autoload keeps long-term fields separate from the run and saves permanent_currency, permanent_upgrades, story_flags, and unlocked_regions to user://moonveil_meta.json. The permanent progression scaffold is not yet connected to a complete shop or earn/spend loop.

## Current scope and limitations

This is a prototype, not a finished commercial-quality game. Character shapes and environment details are placeholders built from primitives. Full character/world save data, a meta-upgrade shop, dialogue trees, audio, crafting, detailed animation rigs, and a complete map are not implemented yet.

## Project structure

- scenes/refuge.tscn — entry scene / safe hub.
- scenes/main.tscn — Whispering Woods run scene.
- scenes/player.tscn and scripts/player.gd — Moonveil Mage movement, magic, stats, XP, and run equipment.
- scenes/sword_duelist.tscn and scripts/sword_duelist.gd — Astra Vale, melee combo, Crescent Lunge, and duel-specific visuals.
- scenes/enemy.tscn and scripts/enemy.gd — Voidling AI, telegraphed attacks, contact damage, and loot.
- scenes/magic_bolt.tscn and scripts/magic_bolt.gd — homing Moonbolt.
- scripts/refuge_controller.gd — Refuge world, Wayfarers' Fire, character-selection panel, pause label, and run transition.
- scripts/game_controller.gd — run world, quest, camera, combat UI, pause/death panels, and enemy spawning.
- scripts/moonveil_meta.gd — persistent long-term progression flags, permanent upgrades/currency and unlocked regions.
- scripts/moonveil_profiles.gd — versioned account save, active character selection, character profiles, and shared bank/stash data (live run stats and bank/stash UI are still separate follow-up work).
- docs/SAVE_SCHEMA.md — account/character data ownership and JSON schema v1.
- docs/ROADMAP.md — longer-term development plan.
