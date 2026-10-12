extends Node

signal settings_changed

const SETTINGS_PATH := "user://moonveil_settings.cfg"
const MODE_WINDOWED := "Windowed"
const MODE_BORDERLESS := "Borderless Fullscreen"
const MODE_EXCLUSIVE := "Exclusive Fullscreen"
const ALL_RESOLUTIONS: Array[String] = ["960x540", "1280x720", "1600x900", "1920x1080", "2560x1440"]
const DEFAULT_RESOLUTION := "1280x720"
const DEFAULT_VOLUME := 0.82
const DEFAULT_VSYNC := true
const DEFAULT_MAX_FPS := 60
const FPS_LIMIT_OPTIONS: Array[int] = [30, 60, 90, 120, 144, 240, 0]
const GRAPHICS_QUALITY_OPTIONS: Array[String] = ["Low", "Balanced", "High"]
# Fixed shortcuts that must remain available to system/debug navigation.
const RESERVED_KEYCODES: Array[int] = [KEY_F10, KEY_QUOTELEFT, KEY_ASCIITILDE, KEY_ENTER, KEY_KP_ENTER]
const CONTROL_ACTIONS := [
	{"action": "move_up", "label": "Move forward", "group": "DI CHUYỂN"},
	{"action": "move_down", "label": "Move backward", "group": "DI CHUYỂN"},
	{"action": "move_left", "label": "Move left", "group": "DI CHUYỂN"},
	{"action": "move_right", "label": "Move right", "group": "DI CHUYỂN"},
	{"action": "attack", "label": "Attack", "group": "CHIẾN ĐẤU"},
	{"action": "dodge", "label": "Dodge", "group": "CHIẾN ĐẤU"},
	{"action": "moonbolt", "label": "Moonbolt / Skill", "group": "KỸ NĂNG"},
	{"action": "interact", "label": "Interact / Shrine", "group": "TƯƠNG TÁC"},
	{"action": "potion_minor", "label": "Minor healing potion", "group": "VẬT PHẨM"},
	{"action": "potion_standard", "label": "Standard healing potion", "group": "VẬT PHẨM"},
	{"action": "potion_greater", "label": "Greater healing potion", "group": "VẬT PHẨM"},
	{"action": "inventory", "label": "Open satchel", "group": "GIAO DIỆN"},
	{"action": "pause", "label": "Pause / Menu", "group": "GIAO DIỆN"}
]

var master_volume: float = DEFAULT_VOLUME
var display_mode: String = MODE_WINDOWED
var windowed_resolution: String = DEFAULT_RESOLUTION
var vsync_enabled: bool = DEFAULT_VSYNC
var max_fps: int = DEFAULT_MAX_FPS
var graphics_quality: String = "Balanced"
var confirm_return_to_title: bool = true
var show_control_hints: bool = true

func _ready() -> void:
	_apply_default_control_bindings()
	get_tree().node_added.connect(_on_tree_node_added)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = clampf(float(config.get_value("audio", "master_volume", DEFAULT_VOLUME)), 0.0, 1.0)
		# Older settings only stored a fullscreen boolean. Do not carry that old
		# implicit fullscreen default forward; new installs/migrations start windowed.
		display_mode = String(config.get_value("display", "display_mode", MODE_WINDOWED))
		if display_mode not in get_display_mode_options():
			display_mode = MODE_WINDOWED
		windowed_resolution = String(config.get_value("display", "windowed_resolution", DEFAULT_RESOLUTION))
		vsync_enabled = bool(config.get_value("display", "vsync", DEFAULT_VSYNC))
		max_fps = int(config.get_value("performance", "max_fps", DEFAULT_MAX_FPS))
		graphics_quality = String(config.get_value("graphics", "quality", "Balanced"))
		if graphics_quality not in GRAPHICS_QUALITY_OPTIONS:
			graphics_quality = "Balanced"
		confirm_return_to_title = bool(config.get_value("interface", "confirm_return_to_title", true))
		show_control_hints = bool(config.get_value("interface", "show_control_hints", true))
		_load_saved_control_bindings(config)
	var available_resolutions := get_available_resolutions()
	if windowed_resolution not in available_resolutions:
		windowed_resolution = DEFAULT_RESOLUTION if DEFAULT_RESOLUTION in available_resolutions else available_resolutions[0]
	if max_fps not in FPS_LIMIT_OPTIONS:
		max_fps = DEFAULT_MAX_FPS
	_apply_all()
	_save() # Also migrates older moonveil_settings.cfg files to the windowed default.

func get_display_mode_options() -> Array[String]:
	# Godot documents exclusive fullscreen as equivalent to regular fullscreen
	# on Wayland, so don't offer a duplicate mode on the Bazzite desktop session.
	var options: Array[String] = [MODE_WINDOWED, MODE_BORDERLESS]
	if not DisplayServer.get_name().to_lower().contains("wayland"):
		options.append(MODE_EXCLUSIVE)
	return options

func get_available_resolutions() -> Array[String]:
	var screen_index := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen_index)
	var result: Array[String] = []
	for label in ALL_RESOLUTIONS:
		var size := _resolution_from_label(label)
		if size.x <= screen_size.x and size.y <= screen_size.y:
			result.append(label)
	if result.is_empty():
		result.append(DEFAULT_RESOLUTION)
	return result

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save()
	settings_changed.emit()

func set_display_mode(value: String) -> void:
	if value not in get_display_mode_options():
		return
	display_mode = value
	_apply_display()
	_save()
	settings_changed.emit()

func set_windowed_resolution(value: String) -> void:
	if value not in get_available_resolutions():
		return
	windowed_resolution = value
	if display_mode == MODE_WINDOWED:
		_apply_display()
	_save()
	settings_changed.emit()

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply_vsync()
	_save()
	settings_changed.emit()

func set_max_fps(value: int) -> void:
	if value not in FPS_LIMIT_OPTIONS:
		return
	max_fps = value
	_apply_fps_limit()
	_save()
	settings_changed.emit()

func reset_defaults() -> void:
	master_volume = DEFAULT_VOLUME
	display_mode = MODE_WINDOWED
	windowed_resolution = DEFAULT_RESOLUTION if DEFAULT_RESOLUTION in get_available_resolutions() else get_available_resolutions()[0]
	vsync_enabled = DEFAULT_VSYNC
	max_fps = DEFAULT_MAX_FPS
	graphics_quality = "Balanced"
	confirm_return_to_title = true
	show_control_hints = true
	_apply_default_control_bindings()
	_apply_all()
	_save()
	settings_changed.emit()

func _apply_all() -> void:
	_apply_audio()
	_apply_display()
	_apply_vsync()
	_apply_fps_limit()
	_apply_graphics()

func _apply_audio() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.001)))

func _apply_display() -> void:
	match display_mode:
		MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size := _resolution_from_label(windowed_resolution)
			DisplayServer.window_set_size(size)
			_center_window(size)
		MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		MODE_EXCLUSIVE:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _center_window(size: Vector2i) -> void:
	var screen_index := DisplayServer.window_get_current_screen()
	var screen_origin := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)
	var centered_position := screen_origin + Vector2i(maxi(0, int((screen_size.x - size.x) / 2)), maxi(0, int((screen_size.y - size.y) / 2)))
	DisplayServer.window_set_position(centered_position)

func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

func _apply_fps_limit() -> void:
	Engine.max_fps = max_fps

func _resolution_from_label(label: String) -> Vector2i:
	var parts := label.split("x")
	if parts.size() != 2:
		return Vector2i(1280, 720)
	return Vector2i(maxi(320, int(parts[0])), maxi(240, int(parts[1])))

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "display_mode", display_mode)
	config.set_value("display", "windowed_resolution", windowed_resolution)
	config.set_value("display", "vsync", vsync_enabled)
	config.set_value("performance", "max_fps", max_fps)
	config.set_value("graphics", "quality", graphics_quality)
	config.set_value("interface", "confirm_return_to_title", confirm_return_to_title)
	config.set_value("interface", "show_control_hints", show_control_hints)
	for item in CONTROL_ACTIONS:
		var action := String(item["action"])
		var events := InputMap.action_get_events(action) if InputMap.has_action(action) else []
		if not events.is_empty():
			config.set_value("controls", action, _event_to_data(events[0]))
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Moonveil could not save settings (error %d)." % error)


func get_control_actions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in CONTROL_ACTIONS:
		result.append(item.duplicate(true))
	return result

func get_control_binding_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "UNAVAILABLE"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "UNBOUND"
	return _event_label(events[0])

func get_control_binding_short_label(action: String) -> String:
	var label := get_control_binding_label(action)
	if label.begins_with("MOUSE "):
		return label.replace("MOUSE ", "M").replace(" · LEFT", "").replace(" · RIGHT", "").replace(" · MIDDLE", "")
	return label

func set_control_binding(action: String, event: InputEvent) -> String:
	if not _is_rebindable_action(action):
		return "That action cannot be rebound."
	if not (event is InputEventKey or event is InputEventMouseButton):
		return "Choose a keyboard key or mouse button."
	var candidate := event.duplicate() as InputEvent
	if candidate is InputEventKey:
		var key_event := candidate as InputEventKey
		key_event.pressed = false
		key_event.echo = false
	if candidate is InputEventMouseButton:
		(candidate as InputEventMouseButton).pressed = false
	if _has_modifier_binding(candidate):
		return "Modifier combinations are not supported yet; choose a single key or mouse button."
	if _is_reserved_binding(candidate):
		return "That key is reserved for a fixed game shortcut."
	var conflict := _find_binding_conflict(action, candidate)
	if not conflict.is_empty():
		return "Already used by %s." % conflict
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, candidate)
	_save()
	settings_changed.emit()
	return ""

func reset_control_bindings() -> void:
	_apply_default_control_bindings()
	_save()
	settings_changed.emit()

func set_graphics_quality(value: String) -> void:
	if value not in GRAPHICS_QUALITY_OPTIONS:
		return
	graphics_quality = value
	_apply_graphics()
	_save()
	settings_changed.emit()

func set_confirm_return_to_title(enabled: bool) -> void:
	confirm_return_to_title = enabled
	_save()
	settings_changed.emit()

func set_show_control_hints(enabled: bool) -> void:
	show_control_hints = enabled
	_save()
	settings_changed.emit()

func _is_rebindable_action(action: String) -> bool:
	for item in CONTROL_ACTIONS:
		if String(item["action"]) == action:
			return InputMap.has_action(action)
	return false

func _has_modifier_binding(event: InputEvent) -> bool:
	if not (event is InputEventWithModifiers):
		return false
	var modifier_event := event as InputEventWithModifiers
	# Input action checks here use Godot's default non-exact matching, which ignores
	# modifiers. Reject chords so Shift+W cannot also trigger an action bound to W.
	return modifier_event.shift_pressed or modifier_event.ctrl_pressed or modifier_event.alt_pressed or modifier_event.meta_pressed

func _is_reserved_binding(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	# Fixed handlers look at keycode alone, so modifier variants remain reserved too.
	return int(key_event.keycode) in RESERVED_KEYCODES or int(key_event.physical_keycode) in RESERVED_KEYCODES

func _build_default_control_bindings() -> Dictionary:
	return {
		"move_up": _make_key_event(KEY_W),
		"move_down": _make_key_event(KEY_S),
		"move_left": _make_key_event(KEY_A),
		"move_right": _make_key_event(KEY_D),
		"attack": _make_mouse_event(MOUSE_BUTTON_LEFT),
		"dodge": _make_key_event(KEY_SPACE),
		"moonbolt": _make_key_event(KEY_Q),
		"interact": _make_key_event(KEY_E),
		"potion_minor": _make_key_event(KEY_1),
		"potion_standard": _make_key_event(KEY_2),
		"potion_greater": _make_key_event(KEY_3),
		"inventory": _make_key_event(KEY_I),
		"pause": _make_key_event(KEY_ESCAPE, false)
	}

func _make_key_event(code: Key, physical: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	if physical:
		event.physical_keycode = code
	else:
		event.keycode = code
	return event

func _make_mouse_event(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event

func _apply_default_control_bindings() -> void:
	var defaults := _build_default_control_bindings()
	for action in defaults:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, (defaults[action] as InputEvent).duplicate())

func _load_saved_control_bindings(config: ConfigFile) -> void:
	# Clear all managed actions first so valid saved layouts can reuse a key that
	# another action has moved away from (e.g. swapping WASD for arrow keys).
	var saved_events: Dictionary = {}
	for item in CONTROL_ACTIONS:
		var action := String(item["action"])
		if config.has_section_key("controls", action):
			var data: Variant = config.get_value("controls", action, {})
			if data is Dictionary:
				var event := _data_to_event(data as Dictionary)
				if event != null:
					if _is_reserved_binding(event) or _has_modifier_binding(event):
						push_warning("Ignoring unsupported saved key for control action '%s'." % action)
					else:
						saved_events[action] = event
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)

	# Custom saved entries take priority over defaults; invalid duplicate entries
	# are skipped. A second pass fills remaining actions with non-conflicting defaults.
	for item in CONTROL_ACTIONS:
		var action := String(item["action"])
		if not saved_events.has(action):
			continue
		var event := saved_events[action] as InputEvent
		if _find_binding_conflict(action, event).is_empty():
			InputMap.action_add_event(action, event)
	var default_bindings := _build_default_control_bindings()
	for action in default_bindings:
		if not InputMap.has_action(action) or not InputMap.action_get_events(action).is_empty():
			continue
		var default_event := default_bindings[action] as InputEvent
		if _find_binding_conflict(action, default_event).is_empty():
			InputMap.action_add_event(action, default_event.duplicate())

	# A conflicting/corrupt layout can consume an action's default key before its
	# fallback is applied. Never leave the player with an invisible/unbound action.
	var unbound_actions: Array[String] = []
	for item in CONTROL_ACTIONS:
		var action := String(item["action"])
		if InputMap.has_action(action) and InputMap.action_get_events(action).is_empty():
			unbound_actions.append(action)
	if not unbound_actions.is_empty():
		push_warning("Saved controls left actions unbound (%s); restored all default controls." % ", ".join(unbound_actions))
		_apply_default_control_bindings()

func _find_binding_conflict(action: String, candidate: InputEvent) -> String:
	var signature := _binding_signature(candidate)
	for item in CONTROL_ACTIONS:
		var other_action := String(item["action"])
		if other_action == action or not InputMap.has_action(other_action):
			continue
		for existing in InputMap.action_get_events(other_action):
			if _binding_signature(existing) == signature:
				return String(item["label"])
	return ""

func _binding_signature(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := int(key_event.physical_keycode) if key_event.physical_keycode != KEY_NONE else int(key_event.keycode)
		return "key:%d:%s:%s:%s:%s" % [code, key_event.shift_pressed, key_event.ctrl_pressed, key_event.alt_pressed, key_event.meta_pressed]
	if event is InputEventMouseButton:
		return "mouse:%d" % int((event as InputEventMouseButton).button_index)
	return "other:%s" % event.as_text()

func _event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		var key_name := OS.get_keycode_string(code)
		match code:
			KEY_ESCAPE: key_name = "ESC"
			KEY_SPACE: key_name = "SPACE"
			KEY_ENTER: key_name = "ENTER"
			KEY_KP_ENTER: key_name = "NUM ENTER"
			KEY_TAB: key_name = "TAB"
			KEY_BACKSPACE: key_name = "BACKSPACE"
			KEY_DELETE: key_name = "DELETE"
			KEY_UP: key_name = "↑"
			KEY_DOWN: key_name = "↓"
			KEY_LEFT: key_name = "←"
			KEY_RIGHT: key_name = "→"
		if key_event.ctrl_pressed:
			key_name = "CTRL+" + key_name
		if key_event.alt_pressed:
			key_name = "ALT+" + key_name
		if key_event.shift_pressed:
			key_name = "SHIFT+" + key_name
		if key_event.meta_pressed:
			key_name = "META+" + key_name
		return key_name.to_upper()
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		match button:
			MOUSE_BUTTON_LEFT: return "MOUSE 1 · LEFT"
			MOUSE_BUTTON_RIGHT: return "MOUSE 2 · RIGHT"
			MOUSE_BUTTON_MIDDLE: return "MOUSE 3 · MIDDLE"
			_: return "MOUSE %d" % int(button)
	return event.as_text().to_upper()

func _event_to_data(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {
			"kind": "key",
			"keycode": int(key_event.keycode),
			"physical_keycode": int(key_event.physical_keycode),
			"shift": key_event.shift_pressed,
			"ctrl": key_event.ctrl_pressed,
			"alt": key_event.alt_pressed,
			"meta": key_event.meta_pressed
		}
	if event is InputEventMouseButton:
		return {"kind": "mouse", "button_index": int((event as InputEventMouseButton).button_index)}
	return {}

func _data_to_event(data: Dictionary) -> InputEvent:
	match String(data.get("kind", "")):
		"key":
			var event := InputEventKey.new()
			event.keycode = int(data.get("keycode", 0)) as Key
			event.physical_keycode = int(data.get("physical_keycode", 0)) as Key
			event.shift_pressed = bool(data.get("shift", false))
			event.ctrl_pressed = bool(data.get("ctrl", false))
			event.alt_pressed = bool(data.get("alt", false))
			event.meta_pressed = bool(data.get("meta", false))
			if event.keycode == KEY_NONE and event.physical_keycode == KEY_NONE:
				return null
			return event
		"mouse":
			var button_index := int(data.get("button_index", 0))
			if button_index < MOUSE_BUTTON_LEFT or button_index > MOUSE_BUTTON_XBUTTON2:
				return null
			return _make_mouse_event(button_index as MouseButton)
	return null

func _on_tree_node_added(node: Node) -> void:
	if node is DirectionalLight3D:
		if not node.has_meta("moonveil_default_shadow_enabled"):
			node.set_meta("moonveil_default_shadow_enabled", (node as DirectionalLight3D).shadow_enabled)
		call_deferred("_apply_light_quality", node)

func _apply_graphics() -> void:
	if is_instance_valid(get_tree().root):
		match graphics_quality:
			"Low": get_tree().root.msaa_3d = Viewport.MSAA_DISABLED
			"Balanced": get_tree().root.msaa_3d = Viewport.MSAA_2X
			"High": get_tree().root.msaa_3d = Viewport.MSAA_4X
	var scene := get_tree().current_scene
	if is_instance_valid(scene):
		for node in scene.find_children("*", "DirectionalLight3D", true, false):
			if not node.has_meta("moonveil_default_shadow_enabled"):
				node.set_meta("moonveil_default_shadow_enabled", (node as DirectionalLight3D).shadow_enabled)
			_apply_light_quality(node)

func _apply_light_quality(node: Node) -> void:
	if not is_instance_valid(node) or not (node is DirectionalLight3D):
		return
	var light := node as DirectionalLight3D
	if not light.has_meta("moonveil_default_shadow_enabled"):
		light.set_meta("moonveil_default_shadow_enabled", light.shadow_enabled)
	light.shadow_enabled = bool(light.get_meta("moonveil_default_shadow_enabled")) and graphics_quality != "Low"
