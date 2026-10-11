# Moonveil save schema v1

## Ownership rules

- `MoonveilMeta` remains the existing long-term progression scaffold. Its current `user://moonveil_meta.json` format is unchanged: permanent currency, permanent upgrades, account/story flags and unlocked regions.
- `MoonveilProfiles` owns account inventory and character profile storage. This is a new scaffold and does not replace `MoonveilMeta`.
- The active playable run is still temporary. The current `Player` node's HP, run level/XP, Moonshards, potion stock and temporary weapon upgrade are not automatically persisted by this schema.
- Carried currency is character-specific. Banked currency and the shared stash belong to the account and are shared across all unlocked characters.

## Account file

Path: `user://moonveil_account.json`

```json
{
  "schema_version": 1,
  "active_character_id": "moonveil_mage",
  "unlocked_character_ids": ["moonveil_mage"],
  "banked_currency": 0,
  "shared_stash": [
    { "item_id": "minor_potion", "quantity": 2 }
  ]
}
```

The starter schema uses an empty shared stash by default. Stash entries have a stable `item_id` and positive integer `quantity`. Duplicate IDs are merged when normalizing loaded data.

## Character files

One file per character: `user://moonveil_characters/<character_id>.json`. Character IDs are limited to letters, digits, underscore and hyphen and are never interpreted as arbitrary paths.

```json
{
  "schema_version": 1,
  "character_id": "moonveil_mage",
  "display_name": "Moonveil Mage",
  "class_id": "moon_mage",
  "carried_currency": 0,
  "progression": { "level": 1, "experience": 0, "xp_to_next": 50 },
  "attributes": { "max_hp": 100, "max_mana": 60, "base_damage": 12, "magic_damage": 24 },
  "unlocked_skills": ["moonbolt"],
  "equipment": {
    "weapon_id": "apprentice_wand",
    "head_id": "",
    "body_id": "",
    "accessory_id": ""
  }
}
```

Each profile owns character-specific progression, attributes, skills, equipment and carried currency. Adding a character does not copy account bank funds or the shared stash into its file. The current `sword_duelist` starter template is only a provisional data placeholder to test independent class profiles; it is not yet an available playable character, and its balance is not final.

## Safety and compatibility

- Writes use a temporary file followed by an atomic rename in the same directory.
- Unsupported versions, invalid JSON and character ID mismatches are left untouched on disk; defaults are used only in memory and a warning is emitted.
- IDs, currencies, quantities and core numeric progression values are validated and normalized on load.
- This v1 scaffold has not yet been wired to the live Player stats, inventory UI, a character-select screen, or an in-game banking/shop UI. These connections come after schema tests and review.
- No migration is applied to `moonveil_meta.json`; its existing version-1 content remains separate and compatible.

## Next integration steps

1. Test account/character read-write round trips, separate character files, shared bank/stash and invalid/corrupt-save handling.
2. Add the smallest character-selection flow while ensuring it only swaps the selected profile, not shared account data.
3. Connect persistent character progression only after deciding which of the current run-only values become long-term character values.
