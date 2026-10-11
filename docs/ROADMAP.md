# Moonveil development roadmap

## Milestone 0 — Playable greybox (current)
- [x] Isometric 3D scene and lightweight stylized world
- [x] Movement, melee strike, homing magic projectile
- [x] Enemy chase/contact damage/death/respawn
- [x] HP, mana, XP, leveling and basic quest tracker
- [x] Loot shards and one weapon upgrade
- [x] Inventory panel and low-HP shrine revive
- [ ] In-engine manual playtest and tuning after first open

## Milestone 1 — RPG foundations
- [ ] Data-driven items, stats and equipment slots (weapon, head, body, accessory)
- [ ] Save/load profile with versioned data
- [ ] Settings, pause menu, key rebinding and controller support
- [ ] Damage numbers, hit feedback, enemy health bars and cooldown UI
- [ ] Basic dialogue and NPC interaction

## Milestone 2 — A first real quest
- [ ] Intro cinematic and lore for Moonveil
- [ ] One safe hub with NPCs, shops and a training area
- [ ] Three connected combat areas and one boss arena
- [ ] Quest journal, quest rewards and branching dialogue
- [ ] Loot tables and rarity levels

## Milestone 3 — Art and combat identity
- [ ] Replace procedural placeholders with licensed/original anime-style characters
- [ ] Rigged character animations and blend trees
- [ ] Skill VFX, hit pause, sound, music and ambient audio
- [ ] Element system (Moon, Ember, Storm) and enemy resistances
- [ ] More enemy archetypes and telegraphed boss attacks

## Milestone 4 — Vertical slice
- [ ] 30–60 minutes of coherent playable content
- [ ] Main quest, optional quests, boss, drops, equipment progression
- [ ] Save/load verification, accessibility and performance pass
- [ ] Package a Linux build and smoke-test on Bazzite

## Engineering guardrails
- Keep the project separate from coursework and desktop configuration.
- Prefer small systems with reproducible tests instead of one giant script.
- Keep an asset manifest and only use assets with clear licenses/permissions.
- Test on the target laptop and use low-cost effects first; add heavier rendering only when measured.
