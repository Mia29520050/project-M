# Moonveil Developer Console

**Debug builds only.** The console removes itself when running a release build. Do not export a shareable release build with debugging enabled, or the console and its test commands will remain available.

Open the console from any scene with **F10** or the backtick key (`). Press **Escape** or use **Close** to return to the previous pause state. The console pauses gameplay while open, persists through scene changes, and supports Up/Down for command history.

Type `help` for the current command list. Supported commands:

| Command | Purpose |
| --- | --- |
| `status` | Current scene, pause state, FPS, player stats/position, enemy count |
| `profile` | Active/unlocked characters, selection state, currency and stash stack count |
| `settings` | Current display/audio/performance settings |
| `scene menu` / `scene refuge` / `scene woods` | Change scene; the console stays open |
| `hero mage` / `hero astra` | Persist active character and reload the current playable scene |
| `heal` | Restore the current player's HP and mana |
| `damage 20` | Apply bounded nonlethal test damage |
| `kill_player` / `revive` | Exercise defeat and recovery flow without waiting for the automatic return |
| `xp 100` | Add run-only XP, bounded to 1–100,000 per command |
| `tp 0 0` | Teleport the player on the ground plane; coordinates are clamped to ±22 |
| `spawn 3` | Spawn 1–12 test enemies in Whispering Woods |
| `clear_enemies` | Remove current enemies from the running test scene |
| `reload` | Reload the current scene and reset run-only stats |
| `time_scale 0.5` / `time_scale 1` | Slow the scene or restore normal time |
| `fps` | Show frame rate and current time scale |
| `clear` | Clear console output |
| `close` | Close the console |

This is a development tool, not a secure sandbox: the command set is intentionally allow-listed and does not expose arbitrary script evaluation or terminal commands. Do not run character-changing commands if you do not intend to update the saved active character. Inventory-item injection and permanent-currency commands are deliberately omitted until their gameplay and save behavior are implemented.
