extends CanvasLayer

const REFUGE_SCENE := "res://scenes/refuge.tscn"
const WOODS_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const MAX_COMMAND_HISTORY := 80
const MAX_XP_PER_COMMAND := 100000
const MAX_SPAWN_PER_COMMAND := 12

var _root: Control
var _command_input: LineEdit
var _output: RichTextLabel
var _is_open := false
var _was_paused_before_open := false
var _mouse_mode_before_open := Input.MOUSE_MODE_VISIBLE
var _history: Array[String] = []
var _history_index := -1

func _ready() -> void:
	# Keep the developer console out of release exports. Debug builds (including
	# editor playtests) retain the existing allow-listed testing workflow.
	if not OS.is_debug_build():
		set_process_input(false)
		queue_free()
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	_append_line("Moonveil Developer Console — type 'help' for available commands.")

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F10 or key_event.keycode == KEY_QUOTELEFT or key_event.keycode == KEY_ASCIITILDE:
		if _is_open:
			_close_console()
		else:
			_open_console()
		get_viewport().set_input_as_handled()
		return
	if _is_open and key_event.keycode == KEY_ESCAPE:
		_close_console()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "DeveloperConsoleOverlay"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.hide()
	add_child(_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.008, 0.025, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.035
	panel.anchor_right = 0.965
	panel.anchor_top = 0.43
	panel.anchor_bottom = 0.965
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.012, 0.022, 0.048, 0.98)
	panel_style.border_color = Color(0.18, 0.72, 0.86, 0.95)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_top = 13.0
	panel_style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var heading := Label.new()
	heading.text = "MOONVEIL  /  DEVELOPER CONSOLE"
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", Color(0.62, 0.91, 1.0))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var shortcut := Label.new()
	shortcut.text = "F10 / `  ·  ESC TO CLOSE"
	shortcut.add_theme_font_size_override("font_size", 11)
	shortcut.add_theme_color_override("font_color", Color(0.45, 0.66, 0.78))
	header.add_child(shortcut)

	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0.0, 1.0)
	separator.color = Color(0.14, 0.42, 0.55, 0.8)
	column.add_child(separator)

	_output = RichTextLabel.new()
	_output.name = "ConsoleOutput"
	_output.bbcode_enabled = false
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.fit_content = false
	_output.custom_minimum_size = Vector2(0.0, 245.0)
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_size_override("normal_font_size", 13)
	_output.add_theme_color_override("default_color", Color(0.78, 0.87, 0.95))
	column.add_child(_output)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	column.add_child(input_row)
	var prompt := Label.new()
	prompt.text = ">"
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color(0.25, 0.91, 0.98))
	input_row.add_child(prompt)
	_command_input = LineEdit.new()
	_command_input.name = "ConsoleCommandInput"
	_command_input.placeholder_text = "Type a command, e.g. status, scene refuge, heal"
	_command_input.clear_button_enabled = true
	_command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_input.custom_minimum_size = Vector2(0.0, 40.0)
	_command_input.add_theme_font_size_override("font_size", 14)
	_command_input.text_submitted.connect(_on_command_submitted)
	_command_input.gui_input.connect(_on_command_input_gui)
	input_row.add_child(_command_input)
	var execute_button := _make_button("RUN", true)
	execute_button.pressed.connect(_submit_current_command)
	input_row.add_child(execute_button)
	var clear_button := _make_button("CLEAR", false)
	clear_button.pressed.connect(_clear_output)
	input_row.add_child(clear_button)
	var close_button := _make_button("CLOSE", false)
	close_button.pressed.connect(_close_console)
	input_row.add_child(close_button)

	var footer := Label.new()
	footer.text = "Allow-listed local test commands only · No shell access · Commands that change scenes pause input until this console closes."
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.38, 0.55, 0.68))
	column.add_child(footer)

func _make_button(caption: String, emphasized: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(74.0, 40.0)
	button.add_theme_font_size_override("font_size", 12)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.23, 0.34, 0.98) if emphasized else Color(0.035, 0.075, 0.12, 0.98)
	normal.border_color = Color(0.20, 0.75, 0.88, 0.95) if emphasized else Color(0.12, 0.30, 0.41, 0.9)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.11, 0.32, 0.45, 1.0)
	hover.border_color = Color(0.40, 0.86, 0.98, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	return button

func _open_console() -> void:
	_was_paused_before_open = get_tree().paused
	_mouse_mode_before_open = Input.get_mouse_mode()
	_is_open = true
	_root.show()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_command_input.grab_focus()
	_command_input.caret_column = _command_input.text.length()
	_append_line("Console opened. Type 'help' to list commands.")

func _close_console() -> void:
	if not _is_open:
		return
	_is_open = false
	_root.hide()
	get_tree().paused = _was_paused_before_open
	Input.set_mouse_mode(_mouse_mode_before_open)

func _on_command_input_gui(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_UP:
		_navigate_history(-1)
		_command_input.accept_event()
	elif key_event.keycode == KEY_DOWN:
		_navigate_history(1)
		_command_input.accept_event()

func _navigate_history(direction: int) -> void:
	if _history.is_empty():
		return
	if _history_index < 0:
		_history_index = _history.size()
	_history_index = clampi(_history_index + direction, 0, _history.size())
	_command_input.text = "" if _history_index >= _history.size() else _history[_history_index]
	_command_input.caret_column = _command_input.text.length()

func _submit_current_command() -> void:
	_on_command_submitted(_command_input.text)

func _on_command_submitted(raw_command: String) -> void:
	var command_text := raw_command.strip_edges()
	if command_text.is_empty():
		return
	_append_line("> " + command_text)
	if _history.is_empty() or _history.back() != command_text:
		_history.append(command_text)
		if _history.size() > MAX_COMMAND_HISTORY:
			_history.pop_front()
	_history_index = -1
	_command_input.clear()
	_execute_command(command_text)
	if _is_open:
		_command_input.grab_focus()

func _execute_command(command_text: String) -> void:
	var args := command_text.split(" ", false)
	if args.is_empty():
		return
	var command := String(args[0]).to_lower()
	match command:
		"help", "?":
			_show_help()
		"clear", "cls":
			_clear_output()
		"close", "exit":
			_close_console()
		"status":
			_show_status()
		"profile":
			_show_profile()
		"settings":
			_show_settings()
		"scene":
			_command_scene(args)
		"menu":
			_change_scene(MENU_SCENE)
		"refuge":
			_change_scene(REFUGE_SCENE)
		"woods", "run":
			_change_scene(WOODS_SCENE)
		"reload", "restart":
			_reload_current_scene()
		"hero":
			_command_hero(args)
		"heal":
			_command_heal()
		"damage":
			_command_damage(args)
		"revive":
			_command_revive()
		"xp":
			_command_xp(args)
		"tp", "teleport":
			_command_teleport(args)
		"spawn":
			_command_spawn(args)
		"clear_enemies":
			_command_clear_enemies()
		"kill_player":
			_command_kill_player()
		"time_scale":
			_command_time_scale(args)
		"fps":
			_append_line("FPS: %d  |  time_scale: %.2f" % [Engine.get_frames_per_second(), Engine.time_scale])
		_:
			_append_line("Unknown command '%s'. Type 'help'." % command)

func _show_help() -> void:
	_append_line("Available commands:")
	_append_line("  help                         Show this command list")
	_append_line("  status                       Scene, player stats, position, enemy count")
	_append_line("  profile                      Active and unlocked saved characters, stash size")
	_append_line("  settings                     Current display, audio and performance settings")
	_append_line("  scene menu|refuge|woods      Change to a scene (also: menu, refuge, woods)")
	_append_line("  hero mage|astra              Change active hero and reload the current scene")
	_append_line("  heal | damage <amount>       Restore stats or apply nonlethal test damage")
	_append_line("  revive | kill_player        Test revive and defeat transitions")
	_append_line("  xp <amount>                  Add run-only XP (1..%d)" % MAX_XP_PER_COMMAND)
	_append_line("  tp <x> <z>                   Teleport player on the ground plane")
	_append_line("  spawn [count]                Spawn 1..%d enemies in Whispering Woods" % MAX_SPAWN_PER_COMMAND)
	_append_line("  clear_enemies                Remove current enemies in the active scene")
	_append_line("  reload                       Restart the current scene")
	_append_line("  time_scale <0.25..2>         Set speed; use time_scale 1 to reset")
	_append_line("  fps                          Show the current frame rate")
	_append_line("  clear | cls                  Clear console output")
	_append_line("  close | exit                 Close and resume previous pause state")
	_append_line("Scenes: menu=%s | refuge=%s | woods=%s" % [MENU_SCENE, REFUGE_SCENE, WOODS_SCENE])

func _show_status() -> void:
	var scene := get_tree().current_scene
	var scene_path := "(none)" if scene == null else scene.scene_file_path
	_append_line("Scene: %s  |  paused: %s  |  FPS: %d" % [scene_path, str(get_tree().paused), Engine.get_frames_per_second()])
	var player := _find_player()
	if player == null:
		_append_line("Player: none in this scene")
	else:
		var p: Vector3 = player.global_position
		_append_line("Player: %s  HP %d/%d  MP %d/%d  LV %d  XP %d/%d" % [
			String(player.get("character_id")), int(player.get("hp")), int(player.get("max_hp")),
			int(player.get("mana")), int(player.get("max_mana")), int(player.get("level")),
			int(player.get("xp")), int(player.get("xp_to_next"))
		])
		_append_line("Position: x=%.2f y=%.2f z=%.2f" % [p.x, p.y, p.z])
	_append_line("Enemies: %d" % get_tree().get_nodes_in_group("enemies").size())

func _show_profile() -> void:
	var account: Dictionary = MoonveilProfiles.account_data
	var unlocked: Array = account.get("unlocked_character_ids", [])
	var stash: Array = account.get("shared_stash", [])
	_append_line("Active character: %s  |  first selection complete: %s" % [
		String(account.get("active_character_id", "(unset)")),
		str(bool(account.get("has_selected_character", false)))
	])
	_append_line("Unlocked characters: %s  |  banked currency: %d  |  stash stacks: %d" % [
		", ".join(unlocked), int(account.get("banked_currency", 0)), stash.size()
	])

func _show_settings() -> void:
	_append_line("Display: %s at %s  |  Master: %d%%  |  VSync: %s  |  FPS limit: %s" % [
		MoonveilSettings.display_mode, MoonveilSettings.windowed_resolution,
		roundi(MoonveilSettings.master_volume * 100.0), str(MoonveilSettings.vsync_enabled),
		"Unlimited" if MoonveilSettings.max_fps == 0 else str(MoonveilSettings.max_fps)
	])

func _command_scene(args: PackedStringArray) -> void:
	if args.size() != 2:
		_append_line("Usage: scene menu|refuge|woods")
		return
	match String(args[1]).to_lower():
		"menu", "title":
			_change_scene(MENU_SCENE)
		"refuge", "hub":
			_change_scene(REFUGE_SCENE)
		"woods", "run", "main":
			_change_scene(WOODS_SCENE)
		_:
			_append_line("Unknown scene. Use menu, refuge or woods.")

func _change_scene(path: String) -> void:
	_append_line("Changing scene to %s" % path)
	# The console survives scene changes. Closing it afterwards should unpause a
	# scene that replaced an old pause menu while the console was open.
	_was_paused_before_open = false
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_append_line("Scene change failed (error %d)." % error)

func _reload_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.is_empty():
		_append_line("Cannot reload: there is no current scene file.")
		return
	_change_scene(scene.scene_file_path)

func _command_hero(args: PackedStringArray) -> void:
	if args.size() != 2:
		_append_line("Usage: hero mage|astra")
		return
	var hero_name := String(args[1]).to_lower()
	var character_id := ""
	match hero_name:
		"mage", "moonveil_mage":
			character_id = "moonveil_mage"
		"astra", "sword_duelist":
			character_id = "sword_duelist"
		_:
			_append_line("Unknown hero. Use mage or astra.")
			return
	if MoonveilProfiles.set_active_character(character_id):
		_append_line("Active character set to %s." % character_id)
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path in [REFUGE_SCENE, WOODS_SCENE]:
			_reload_current_scene()
		elif scene != null and scene.has_method("_refresh_profile_summary"):
			scene.call("_refresh_profile_summary")
	else:
		_append_line("Could not select %s. Check that the character is unlocked and its profile is valid." % character_id)

func _command_heal() -> void:
	var player := _find_player()
	if player == null:
		_append_line("No player in this scene.")
		return
	if bool(player.get("_defeated")):
		_append_line("Player is defeated. Use 'revive' to restore them.")
		return
	player.set("hp", int(player.get("max_hp")))
	player.set("mana", int(player.get("max_mana")))
	player.emit_signal("stats_changed")
	_append_line("Player health and mana restored.")

func _command_damage(args: PackedStringArray) -> void:
	if args.size() != 2 or not String(args[1]).is_valid_int():
		_append_line("Usage: damage <amount> (1..100; nonlethal)")
		return
	var amount := int(args[1])
	if amount < 1 or amount > 100:
		_append_line("Damage must be between 1 and 100.")
		return
	var player := _find_player()
	if player == null or not player.has_method("take_damage"):
		_append_line("No damageable player in this scene.")
		return
	if not player.has_method("debug_take_nonlethal_damage"):
		_append_line("This player does not support debug damage.")
		return
	var applied_damage := int(player.call("debug_take_nonlethal_damage", amount))
	if applied_damage <= 0:
		_append_line("Cannot apply nonlethal test damage at 1 HP or while defeated. Use 'heal' first.")
		return
	_append_line("Applied %d nonlethal test damage. HP is now %d." % [applied_damage, int(player.get("hp"))])

func _command_revive() -> void:
	var player := _find_player()
	if player == null:
		_append_line("No player in this scene.")
		return
	if not player.has_method("debug_revive"):
		_append_line("This player does not support the debug revive command.")
		return
	player.call("debug_revive")
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_hide_death_panel"):
		scene.call("_hide_death_panel")
	_append_line("Player revived and the delayed defeat transition was cancelled.")

func _command_xp(args: PackedStringArray) -> void:
	if args.size() != 2 or not String(args[1]).is_valid_int():
		_append_line("Usage: xp <amount> (1..%d)" % MAX_XP_PER_COMMAND)
		return
	var amount := int(args[1])
	if amount < 1 or amount > MAX_XP_PER_COMMAND:
		_append_line("XP amount must be between 1 and %d." % MAX_XP_PER_COMMAND)
		return
	var player := _find_player()
	if player == null or not player.has_method("gain_xp"):
		_append_line("XP is only available in a scene with a player.")
		return
	player.call("gain_xp", amount)
	_append_line("Added %d run XP." % amount)

func _command_teleport(args: PackedStringArray) -> void:
	if args.size() != 3 or not String(args[1]).is_valid_float() or not String(args[2]).is_valid_float():
		_append_line("Usage: tp <x> <z>")
		return
	var player := _find_player()
	if player == null:
		_append_line("No player in this scene.")
		return
	var x := clampf(float(args[1]), -22.0, 22.0)
	var z := clampf(float(args[2]), -22.0, 22.0)
	player.global_position = Vector3(x, 0.0, z)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	_append_line("Teleported to x=%.1f, z=%.1f." % [x, z])

func _command_spawn(args: PackedStringArray) -> void:
	var amount := 1
	if args.size() > 2 or (args.size() == 2 and not String(args[1]).is_valid_int()):
		_append_line("Usage: spawn [count]")
		return
	if args.size() == 2:
		amount = int(args[1])
	if amount < 1 or amount > MAX_SPAWN_PER_COMMAND:
		_append_line("Spawn count must be between 1 and %d." % MAX_SPAWN_PER_COMMAND)
		return
	var scene := get_tree().current_scene
	var player := _find_player()
	if scene == null or player == null or not scene.has_method("_spawn_enemy"):
		_append_line("Spawn is only available in Whispering Woods.")
		return
	for i in range(amount):
		var angle := TAU * float(i) / float(amount)
		var spawn_position: Vector3 = player.global_position + Vector3(cos(angle) * 5.0, 0.0, sin(angle) * 5.0)
		scene.call("_spawn_enemy", spawn_position)
	_append_line("Spawned %d test enemy/enemies." % amount)

func _command_clear_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_append_line("Removed %d enemy/enemies." % enemies.size())

func _command_kill_player() -> void:
	var player := _find_player()
	if player == null or not player.has_method("take_damage"):
		_append_line("No damageable player in this scene.")
		return
	if not player.has_method("debug_kill"):
		_append_line("This player does not support debug defeat.")
		return
	player.call("debug_kill")
	_append_line("Forced the defeat flow. Use 'revive' before closing the console to cancel the return-to-Refuge timer.")

func _command_time_scale(args: PackedStringArray) -> void:
	if args.size() != 2 or not String(args[1]).is_valid_float():
		_append_line("Usage: time_scale <0.25..2> (1 resets normal speed)")
		return
	var value := float(args[1])
	if value < 0.25 or value > 2.0:
		_append_line("Time scale must be between 0.25 and 2.0.")
		return
	Engine.time_scale = value
	_append_line("Time scale set to %.2f." % Engine.time_scale)

func _find_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node

func _clear_output() -> void:
	_output.clear()
	_append_line("Output cleared. Type 'help' for commands.")

func _append_line(message: String) -> void:
	if not is_instance_valid(_output):
		return
	_output.append_text(message + "\n")
