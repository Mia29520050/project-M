# Moonveil — Anime Fantasy RPG

A lightweight 2.5D/isometric anime-fantasy RPG prototype for Godot 4.7.2. Characters and environment decorations are built from procedural 3D meshes; the current build is a greybox slice focused on movement, combat, a short run, and returning safely to the Refuge.

## Run

Open project.godot with Godot 4.7.2 and press F5 to run the project. The entry scene is `scenes/main_menu.tscn`; F6 runs the currently open scene.

On Bazzite, launch it with:
flatpak run org.godotengine.Godot --path ~/Projects/AnimeFantasyRPG

## Controls

### Refuge
- Default movement is WASD; controls can be rebound from System Settings → Điều khiển.
- The configured Pause/Menu binding opens the shared Pause Menu (Resume, System Settings, Return to Title).
- On a fresh account, the hero is not controllable until the player clicks the **Wayfarers' Fire** (or presses the configured Interact binding) and chooses a wayfarer in the focused campfire view.
- Click a character once to highlight their glowing ring and inspect their role; click the same character again, press the configured Interact binding, or use the compact **Confirm Wayfarer** button to confirm. The Pause/Menu binding returns to the Refuge overview.
- After the first choice, the hero remains controllable in the Refuge. To change heroes later, approach the **Wayfarers' Fire** and press the configured Interact binding; clicking characters in the overview no longer changes heroes.
- The active hero is saved in the account profile. Returning from a run or defeat restores the saved hero directly to the Refuge with movement enabled.
- Go to the **Moon Shrine** and press the configured Interact binding — enter Whispering Woods as the selected character.

### During a run — shared controls
- Default bindings are WASD to move, Mouse 1 to attack, Space to dodge, 1/2/3 for healing potions, Q for the character skill, E to interact, I for the satchel, and Esc for Pause/Menu. Every listed action can be reassigned in System Settings → Điều khiển.
- Opening the satchel pauses the run. The configured Pause/Menu binding closes it or toggles the shared pause menu. Return to Title can ask for confirmation; run-only progress is discarded, while the selected character/profile remains saved.

### Character-specific skill
- **Moonveil Mage:** The configured Character Skill binding fires a homing Moonbolt at the nearest Voidling within range (15 Mana; 24 base damage); the configured Interact binding at the shrine can awaken the Apprentice Wand after collecting 3 Moonshards.
- **Astra Vale, Sword Duelist:** The configured Attack binding chains three close-range strikes (16 / 20 / 28 base damage). The configured Character Skill binding triggers Crescent Lunge, a mobile dash strike using 20 stamina, with a 4.5-second cooldown. The duelist does not use Moonbolt or the staff upgrade.

## Main Menu and settings

F5 starts at a dedicated procedural title screen with Continue, New Journey, System Settings, Credits & Controls, and Quit Game. Continue resumes the saved wayfarer when available. New Journey reopens the Refuge's campfire selection but does not delete character profiles or permanent progression. System Settings are organized into Audio, Display, Graphics, Controls, and Interface pages. They include master volume, Windowed / Borderless Fullscreen (Exclusive Fullscreen is offered on display servers where it is a distinct mode), supported window resolutions, Low / Balanced / High graphics presets, VSync, a 30–240 FPS / Unlimited frame cap, optional in-run control hints, optional Return-to-Title confirmation, and keyboard/mouse rebinds for movement, attack, dodge, skill, interact, potions, satchel, and pause. Bindings reject conflicts, can be reset separately, and are persisted with settings to `user://moonveil_settings.cfg`; new/migrated installs retain the existing Windowed 1280x720, 60 FPS, VSync-on defaults. Fullscreen modes use the monitor's native size. The same settings panel is available from the shared Pause Menu in both the Refuge and an expedition. A built-in Developer Console is available in debug builds only; it opens with **F10** or the backtick key and supports allow-listed test commands such as `help`, `status`, `scene refuge`, `scene woods`, `hero mage|astra`, `heal`, `damage 20`, `xp 100`, `tp 0 0`, `spawn 3`, `clear_enemies`, `kill_player`/`revive`, `reload`, and `time_scale 0.5`. It has command history, pauses the game while open, and does not run arbitrary shell code.

## Current playable loop

1. Visit the Wayfarers' Fire in the Refuge to choose either the Moonveil Mage or Astra Vale, Sword Duelist.
2. Enter Whispering Woods using E near the Moon Shrine; the chosen character is used in the run.
3. Fight Voidlings, gain XP, level up, and collect dropped Moonshards.
4. Collect 3 Moonshards and use the Moon Shrine during the run to awaken the Moonfire Staff (Mage only).
5. Complete the opening quest by defeating 5 Voidlings; enemies can respawn so combat can continue.
6. When HP reaches zero, the death banner appears and the run returns to the Refuge after a short delay.

Each run uses a fresh Player, so run level, XP, Moonshards, and temporary equipment do not carry into the next run. The MoonveilMeta autoload keeps long-term fields separate from the run and saves permanent_currency, permanent_upgrades, story_flags, and unlocked_regions to user://moonveil_meta.json. The permanent progression scaffold is not yet connected to a complete shop or earn/spend loop.

## Current scope and limitations

This is a prototype, not a finished commercial-quality game. Character shapes and environment details are placeholders built from primitives. Full character/world save data, a meta-upgrade shop, dialogue trees, music and sound effects, crafting, detailed animation rigs, and a complete map are not implemented yet. Master-volume preference is already wired to Godot’s audio mixer for when audio is added.

## Project structure

- scenes/main_menu.tscn — procedural title screen and primary navigation.
- scenes/settings_panel.tscn — reusable audio/display settings overlay.
- scenes/pause_menu.tscn — shared pause, settings, and return-to-title flow.
- scenes/refuge.tscn — safe hub.
- scenes/main.tscn — Whispering Woods run scene.
- scenes/player.tscn and scripts/player.gd — Moonveil Mage movement, magic, stats, XP, and run equipment.
- scenes/sword_duelist.tscn and scripts/sword_duelist.gd — Astra Vale, melee combo, Crescent Lunge, and duel-specific visuals.
- scenes/enemy.tscn and scripts/enemy.gd — Voidling AI, telegraphed attacks, contact damage, and loot.
- scenes/magic_bolt.tscn and scripts/magic_bolt.gd — homing Moonbolt.
- scripts/main_menu.gd — animated procedural title background, main navigation, credits, and saved wayfarer summary.
- scripts/moonveil_settings.gd — persistent audio/display preferences.
- scripts/developer_console.gd — debug-build-only F10/backtick allow-listed test console, command history, scene switching and run-only debug commands.
- scripts/settings_panel.gd — reusable audio/display controls.
- scripts/pause_menu.gd — shared pause/settings/return-to-title overlay.
- scripts/refuge_controller.gd — Refuge world, campfire-focused wayfarer selection, pause menu, and run transition.
- scripts/game_controller.gd — run world, quest, camera, combat UI, shared pause menu, death UI, and enemy spawning.
- scripts/moonveil_meta.gd — persistent long-term progression flags, permanent upgrades/currency and unlocked regions.
- scripts/moonveil_profiles.gd — versioned account save, active character selection, character profiles, and shared bank/stash data (live run stats and bank/stash UI are still separate follow-up work).
- docs/SAVE_SCHEMA.md — account/character data ownership and JSON schema v1.
- docs/ROADMAP.md — longer-term development plan.
