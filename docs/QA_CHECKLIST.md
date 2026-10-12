# Moonveil Manual QA Checklist

**Purpose:** verify Settings, input routing, scene transitions, and the playable combat loop before merging.

**Build / commit:** ____________________  **Date:** ____________________  **Tester:** ____________________

For every item, record **PASS / FAIL / NOT RUN** and a brief note. Headless smoke tests do not replace these GUI checks.

## Settings and controls

- [ ] **Binding persistence:** Settings → Controls; set Dodge to `F`, confirm the success message, quit the game fully, relaunch, and verify `F` dodges, Space no longer dodges, and the HUD shows `F`.
- [ ] **Duplicate rejection:** try assigning Dodge to `Q` while Moonbolt uses `Q`; it must be rejected without changing Dodge. Free `Q` from Moonbolt, then verify assigning it to Dodge succeeds.
- [ ] **Reserved shortcuts and modifiers:** attempt to assign `F10`, backtick, tilde, Enter, and Numpad Enter to an action. Each must be rejected and the old binding must remain intact. Modifier chords such as `Shift+W` and `Ctrl+Mouse 1` must also be rejected because Godot's default action matching ignores modifiers.
- [ ] **Reset controls:** Reset Controls restores all default bindings and updates HUD hints. Restore All Defaults also resets audio, display, graphics, and interface settings. Quit and relaunch to verify persistence.
- [ ] **Malformed settings:** in a test copy of `moonveil_settings.cfg`, give two actions the same key and relaunch. All managed actions should have bindings; Pause should still work. A saved reserved key should be ignored and replaced by a usable default.

## Pause, inventory, console, and transitions

- [ ] **Pause in expedition:** the configured Pause binding opens the pause menu, freezes enemies, and Resume restores gameplay. Rebind Pause to `P`, then verify `P` works and record the expected loss of Escape as Pause. Repeat in Refuge and during character selection (Pause should close selection there).
- [ ] **Inventory:** open the satchel; gameplay pauses. Close using Inventory and using Pause. Potion keys must not activate while the satchel is open. Confirm potion and Moonshard counts remain correct.
- [ ] **Developer Console (debug builds only):** F10 and backtick open/close it; Escape closes it; the previous paused state is restored. Test `status`, `damage 20`, `heal`, `spawn 3`, and `time_scale 0.5` followed by `time_scale 1`. Open it over Pause, run `scene refuge`, close the console, and verify the new scene is not stuck paused.
- [ ] **Defeat:** let player HP reach zero. During the defeat delay, Pause and Inventory should be ignored. Verify automatic return to Refuge, run-only stats reset, and permanent flags remain. Open and close the debug console during the defeat delay.
- [ ] **Scene cycling:** Refuge → Shrine → Woods → defeat → Refuge, three cycles. After each transition, check Pause and one rebound action. From the title menu test Continue and the Return-to-Title confirmation.
- [ ] **Hints:** rebind potion, skill, and Interact; inspect HUD potion status, Astra skill status, the campfire 3D prompt, and both character descriptions for stale key labels.

## Combat playtest gate

For **each** character (Moonveil Mage and Astra Vale), complete at least **two runs of 15 minutes**. Record deaths, approximate seconds to defeat a Voidling, dodge uses, potion uses, and FPS while the game is using the intended NVIDIA GPU.

For each run answer YES / NO:

- [ ] I could tell when an enemy was about to attack.
- [ ] I could tell why I lost health.
- [ ] Dodging felt responsive and useful.
- [ ] The camera did not obscure or lose my character.
- [ ] Potion use felt like a meaningful decision.
- [ ] I would play another 20 minutes.

**Proposed gate:** at least four of the five combat answers are YES in at least two runs for each character, no blocking soft-lock/control-loss issues, and “play another 20 minutes” is YES. If the gate fails, fix combat feel/readability before adding enemy types, controller support, or progression systems.
