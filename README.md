# Moonveil — Anime Fantasy RPG

A long-term 2.5D/isometric fantasy RPG project for Godot 4.7.2. The current build is an intentionally lightweight, fully playable greybox slice: all characters and environmental decorations are created from procedural 3D meshes so no external asset downloads are required.

## Run
Open `project.godot` with Godot 4.7.2 and press **F6/F5** (F5 runs the main scene). On Bazzite, the installed Flathub build can be launched with:

```bash
flatpak run org.godotengine.Godot --path ~/Projects/AnimeFantasyRPG
```

## Controls
- **WASD** — Move
- **Left mouse button** — Basic strike against a nearby Voidling
- **Space** — Dodge; 2 charges available, one charge starts recharging every 1.25 seconds after being spent
- **Q** — Auto-lock the nearest Voidling within 18 metres and fire a homing Moonbolt that chases it (15 Mana; 24 base damage). It does not aim based on the mouse cursor.
- **I** — Open/close the satchel; opening it pauses the entire game, including enemies and timers
- **E** — At the glowing Moon Shrine, spend 3 Moonshards to awaken the Apprentice Wand into the Moonfire Staff
- **Esc** — Close the satchel and resume; if the satchel is closed, open/close the pause menu

## Playable loop
1. Defeat Voidlings for XP; level ups raise max HP/mana and basic damage.
2. Voidlings can drop Moonshards.
3. Collect 3 shards, return to the glowing Moon Shrine, and press E to awaken the Moonfire Staff. Its appearance and displayed strike/Moonbolt damage change.
4. Complete the opening quest by defeating 5 Voidlings. Enemies respawn so combat can continue.
5. Floating damage numbers and a remaining-HP label help read combat. If HP reaches zero, the shrine revives the player.

## Current scope and limitations
This is a prototype, not a finished commercial-quality game. Character shapes are placeholders built from primitives. There are no external anime character models, detailed animation rigs, dialogue trees, save/load, audio, crafting or full map yet. These systems are listed in the roadmap and should be added in small, tested milestones.

## Project structure
- `scenes/main.tscn` — entry scene
- `scenes/player.tscn` and `scripts/player.gd` — movement, combat, stats, XP, equipment
- `scenes/enemy.tscn` and `scripts/enemy.gd` — Voidling AI, contact damage, loot
- `scenes/magic_bolt.tscn` and `scripts/magic_bolt.gd` — homing Moonbolt spell
- `scripts/game_controller.gd` — world, quest, camera, UI, enemy spawning
- `docs/ROADMAP.md` — long-term development plan
