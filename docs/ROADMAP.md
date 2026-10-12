# Moonveil development roadmap

## Milestone 0 — Playable greybox (current baseline)
- [x] Isometric 3D scene and lightweight stylized world
- [x] Refuge entry scene and Whispering Woods run scene
- [x] Movement, melee strike, homing magic projectile and two-charge dodge
- [x] Enemy chase, telegraphed melee attack, damage, death, loot and respawn
- [x] HP, mana, XP, leveling and basic quest tracker
- [x] Moonshards and one temporary weapon upgrade
- [x] Inventory and pause UI
- [x] Death banner and return-to-Refuge loop; run-only stats/equipment reset on a new run
- [x] Separate MoonveilMeta scaffold for long-term progression fields
- [x] Shared Pause Menu for Refuge and expedition, spawn spacing and Shrine-to-run transition
- [x] Headless import and smoke tests for Refuge and Whispering Woods
- [ ] Continue GUI playtesting and combat tuning on the target laptop

## Milestone A — Combat feel and hit feedback (in progress)
- [x] When a Voidling is hit, flash its body **white briefly**, then restore its normal base appearance
- [x] Make the enemy white hit-flash work for both melee strikes and Moonbolt hits
- [x] On player damage, briefly overlay a soft white flash without replacing original character materials
- [x] Give the player 0.72 seconds of post-hit invulnerability, with brief visibility flicker after the initial flash
- [x] Ignore enemy body collisions during post-hit invulnerability, then restore collisions and visibility cleanly
- [x] Keep enemy hit feedback readable when several hits occur close together; ensure the enemy cannot remain stuck white
- [x] Add a short, low-cost icy-white impact spark burst on every Voidling hit (shared by melee and Moonbolt damage)
- [x] Cap simultaneous impact effects, disable their shadows and automatically clean them up
- [ ] Playtest enemy telegraph clarity, damage feedback, dodge response and camera framing before adding enemy archetypes
- [x] Show a fixed outer attack-range ring during wind-up, sized to the actual 1.35-unit damage range
- [x] Add a separate inner countdown ring that expands from the center to the edge of the fixed range ring and shifts from amber to red as the strike approaches
- [x] Smooth both torus rings by increasing major-circle tessellation from 8 to 64 segments
- [x] Make the warning marker intensify/pulse near impact, then clear all telegraph visuals when the attack resolves
- [x] Headless validation confirms hit-flash restoration, repeated-hit behavior, and attack-ring visibility/radius
- [x] Headless validation confirms the countdown ring expands/changes color and telegraph visuals clear at impact
- [x] Headless validation confirms six impact sparks are created per hit and self-clean without casting shadows

**Acceptance checks:** melee and Moonbolt each trigger the enemy's white flash and impact sparks; impact meshes fade and clean up, with active effects capped; player damage triggers a brief white overlay and 0.72 seconds of invulnerability; repeat damage is ignored during that window; enemy body collisions, visibility and original materials restore afterward; headless tests pass and effects remain readable in a GUI playtest.

## Milestone B — Healing items and deliberate recovery (prototype implemented; balance needs playtesting)
- [x] Healing potions restore HP gradually over time instead of healing the full amount immediately
- [x] Minor, Standard and Greater grades use distinct recovery profiles: 24 HP / 3 seconds, 45 HP / 4 seconds, and 70 HP / 5 seconds (capped by missing HP)
- [x] Add simple run-scoped starter stock: 2 Minor, 1 Standard and 1 Greater potion; number keys 1/2/3 use the matching grade
- [x] Prevent potion stacking and prevent wasting a potion at full HP or when its grade is out of stock
- [x] Show potion counts and the active recovery countdown in the HUD and satchel
- [ ] Playtest whether the recovery pace encourages players to make space and find a safer moment before drinking
- [ ] Decide after playtesting whether taking damage interrupts, delays or leaves ongoing recovery unchanged; this prototype currently lets recovery continue after a hit
- [ ] Add ways to obtain more potions through gameplay when loot/reward systems are designed

The current starter counts and healing profiles are a minimal prototype, not a final economy or rarity system. Potion stock resets when a new Player/run is created. Continue tuning only after a real GUI playtest.

## Milestone C — Character-specific builds and shared account storage (schema scaffold implemented)
- [x] Define versioned account and per-character JSON save structures with separate files
- [x] Keep character-level progression, attributes, skills, equipment and carried currency in each character profile
- [x] Keep banked currency and a stack-based shared stash in the account profile, outside character files
- [x] Add atomic temp-file writes, ID validation, normalized quantities and safe handling for corrupt/unsupported saves
- [ ] Connect persistent profile progression to live Player stats and decide which values remain run-only
- [x] Add a focused Wayfarers' Fire selection flow: first-time players choose before control unlocks; returning players press E near the fire to reopen it
- [ ] Integrate shared stash and bank with the item inventory and economy UI when those systems exist
- [ ] Build only the smallest reusable structure needed for the first two characters; avoid creating a large generic framework before a second character proves the design

`MoonveilProfiles` is a persistence/ownership scaffold, not a finished character selector or live banking system. Current run stats, Moonshards, potions and temporary weapon upgrades still reset with each new Player. `MoonveilMeta` remains unchanged and continues to store its existing long-term progression fields. See `docs/SAVE_SCHEMA.md` for the exact v1 contract.

## Milestone D — Second character prototype (implemented; balance needs playtesting)
- [x] Add **Astra Vale, Sword Duelist** as a second playable character with separate procedural model and weapon
- [x] Give the duelist a three-hit close-range chain (16 / 20 / 28 base damage) and Q **Crescent Lunge** (dash strike, 20 stamina, 4.5-second cooldown)
- [x] Reuse the shared movement, health, dodge, hit flash, potions, Voidling AI, damage/death flow and run scene
- [x] Give the player HUD and help text character-specific skill/weapon messaging
- [x] Make the active Refuge selection drive which character scene enters Whispering Woods
- [ ] Playtest both characters against the same Voidling encounters and tune damage, reach, mobility and stamina in GUI; follow `docs/QA_CHECKLIST.md` before adding new enemy archetypes or controller support

Both models are procedural placeholders rather than rigged art assets. The duelist's numbers are a first-pass prototype, not final balance; profile saves for long-term live stats/equipment remain a separate integration task.

## Milestone 2 — RPG foundations
- [ ] Data-driven items, stats and equipment slots (weapon, head, body, accessory)
- [ ] Robust save/load profile with versioned data and shared-account/character data ownership
- [x] Audio/display settings stored in user configuration and shared between Main Menu and Pause Menu
- [x] Keyboard/mouse key rebinding with duplicate/reserved-key checks, modifier-chord rejection, invalid-config recovery, reset-to-defaults, and `user://moonveil_settings.cfg` persistence
- [ ] Gamepad/controller support
- [ ] Dodge cooldown UI, more impact feedback and tuning
- [ ] Basic dialogue and NPC interaction

## Milestone 3 — A first real quest and broader world
- [ ] Intro cinematic and lore for Moonveil, retaining the established roots: Aether, Moonfall, Astral Sea and Voidlings
- [ ] One safe hub with NPCs, shops and a training area
- [ ] Expand the world only after the Refuge and Whispering Woods loop is stable
- [ ] Quest journal, quest rewards and branching dialogue
- [ ] Loot tables and rarity levels
- [ ] More enemy archetypes and telegraphed boss attacks

## Milestone 4 — Art and combat identity
- [ ] Replace procedural placeholders with licensed/original anime-style characters
- [ ] Rigged character animations and blend trees
- [ ] Skill VFX, hit pause, sound, music and ambient audio
- [ ] Element system (Moon, Ember, Storm) and enemy resistances
- [ ] Distinct skill sets and visual identity for additional characters

## Milestone 5 — Vertical slice
- [ ] 30–60 minutes of coherent playable content
- [ ] Main quest, optional quests, boss, drops, equipment progression
- [ ] Save/load verification, accessibility and performance pass
- [ ] Package a Linux build and smoke-test on Bazzite

## Engineering guardrails
- Keep the project separate from coursework and desktop configuration.
- Prefer small systems with reproducible tests instead of one giant script.
- First improve readability and feel of current attacks/enemies; do not add multiple new enemy types or a boss before this pass is validated.
- Keep shared account storage separate from character-specific stats, skills and progression.
- Keep an asset manifest and only use assets with clear licenses/permissions.
- Test on the target laptop and use low-cost effects first; add heavier rendering only when measured.

## Menu system — implemented
- [x] Procedural anime-fantasy Main Menu with animated moon backdrop, saved-wayfarer summary, Continue, New Journey, Settings, Credits & Controls, and Quit
- [x] New Journey confirmation returns to the Refuge's campfire selection without deleting character profiles or permanent progression
- [x] Reusable category-based Settings panel for master volume, platform-appropriate Windowed/Fullscreen modes, windowed resolution, Low/Balanced/High graphics presets, VSync and FPS limit, persisted to `user://moonveil_settings.cfg`
- [x] Remappable keyboard/mouse controls, duplicate/reserved-key guard, modifier-chord rejection, invalid-config recovery, live key hints, optional HUD hints, and Return-to-Title confirmation preference
- [x] Shared Pause Menu in Refuge and expedition with Resume, Settings, and confirmed Return to Title
- [x] Main Menu is the F5 entry scene; Continue opens the Refuge with the saved wayfarer
- [x] Headless smoke tests for Main Menu, Refuge and Whispering Woods; GUI-tested Settings, Credits, New Journey, Pause, and Continue/return-to-title flow


## Developer tools — implemented
- [x] Debug-build-only in-game console on F10 or backtick, persistent across scenes, with Up/Down command history and clearable output
- [x] Allow-listed scene/profile/status/settings commands plus run-only XP, teleport, heal/nonlethal damage, spawn/clear enemies, time scaling, and defeat/revive tests
- [x] Developer console pauses game input while open, resets time scale on close/scene change, and has no shell/eval command path
