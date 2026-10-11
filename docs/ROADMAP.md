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
- [x] Refuge pause label, spawn spacing and Shrine-to-run transition
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

## Milestone C — Character-specific builds and shared account storage (future architecture plan)
- [ ] Keep each character's own base stats, growth, skills, animations/VFX, combat mechanics and character-specific equipment/progression separate
- [ ] Keep account-level resources shared across characters, including a common chest/stash and money deposited in a shared bank (or equivalent)
- [ ] Define clear ownership for character-bound items, shared-storage items, carried money and banked money before implementing the save format
- [ ] Store character data separately from shared account data so adding another character does not duplicate the whole game controller or break shared storage
- [ ] Build only the smallest reusable structure needed for the first two characters; avoid creating a large generic framework before a second character proves the design

The shared chest/bank behavior is a future requirement, not a feature currently available in the prototype. MoonveilMeta is only a small persistent-data scaffold at present; it is not yet a complete account inventory or banking system.

## Milestone D — Second character prototype (after Milestone A is solid)
- [ ] Prototype a **mobile sword duelist** as the initial candidate to contrast with the current Moonveil mage
- [ ] Give the duelist a distinct combat rhythm built around close-range attack chains and mobility, rather than simply reskinning Moonbolt
- [ ] Reuse appropriate shared systems (movement, health, enemy targeting, damage/death flow) while keeping that character's skills and stats independent
- [ ] Verify the second character can be added without rewriting the enemy controller or duplicating the entire run scene
- [ ] Playtest both characters against the same Voidling encounters and confirm their choices feel meaningfully different

The second character's weapon, exact skills, visuals and balance are provisional. Implement this milestone only after the existing mage's combat feedback and basic loop feel good.

## Milestone 2 — RPG foundations
- [ ] Data-driven items, stats and equipment slots (weapon, head, body, accessory)
- [ ] Robust save/load profile with versioned data and shared-account/character data ownership
- [ ] Settings, key rebinding and controller support
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
