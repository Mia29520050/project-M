# Technical architecture

## Current runtime flow
- `scenes/main.tscn` loads `scripts/game_controller.gd`.
- The controller builds the world, adds the player and spawns enemy scene instances.
- Player and enemy scenes use `CharacterBody3D` for collision-aware movement.
- The player's signals decouple game systems: stat changes refresh the HUD, magic requests spawn a projectile, and notifications show toasts.
- Enemies report defeat with XP and an optional Moonshard drop. The controller updates the quest and schedules respawns.
- The current build uses primitive meshes, generated materials and a simple orthographic follow camera to keep the project lightweight.

## Stable boundaries to preserve
1. Keep combat and player progression logic in `player.gd`.
2. Keep enemy behaviour and rewards emitted on defeat in `enemy.gd`.
3. Keep world composition, quest state, HUD and spawn coordination in `game_controller.gd`.
4. Put reusable gameplay objects into their own scenes/scripts before adding content.
5. When adding persistence, store data (levels, equipment IDs, quests) rather than serializing live scene nodes.
