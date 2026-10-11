extends Node3D

const REFUGE_SCENE_PATH := "res://scenes/refuge.tscn"
const SETTINGS_PANEL_SCENE := preload("res://scenes/settings_panel.tscn")

var _time := 0.0
var _moon_ring: MeshInstance3D
var _floating_shards: Array[MeshInstance3D] = []
var _shard_home_positions: Array[Vector3] = []
var _menu_layer: CanvasLayer
var _menu_buttons: VBoxContainer
var _main_status: Label
var _settings_panel: Control
var _credits_panel: Control
var _credits_back_button: Button
var _confirm_panel: Control
var _confirm_back_button: Button
var _confirm_start_button: Button
var _confirm_body_label: Label
var _continue_button: Button
var _new_journey_button: Button
var _has_saved_wayfarer := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_environment()
	_build_backdrop()
	_build_menu_ui()

func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(_moon_ring):
		_moon_ring.rotation.y += delta * 0.055
		_moon_ring.rotation.z = -0.24 + sin(_time * 0.22) * 0.035
	for index in range(_floating_shards.size()):
		var shard := _floating_shards[index]
		if not is_instance_valid(shard):
			continue
		var home := _shard_home_positions[index]
		shard.position = home + Vector3(0.0, sin(_time * 0.55 + float(index) * 0.9) * 0.16, 0.0)
		shard.rotation.y += delta * (0.16 + float(index % 3) * 0.05)
		shard.rotation.x = sin(_time * 0.2 + float(index)) * 0.12

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.009, 0.015, 0.042, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.29, 0.39, 0.67)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38.0, -24.0, 0.0)
	key_light.light_color = Color(0.63, 0.78, 1.0)
	key_light.light_energy = 1.05
	key_light.shadow_enabled = true
	add_child(key_light)

	var warm_light := OmniLight3D.new()
	warm_light.position = Vector3(3.5, 0.4, 0.6)
	warm_light.light_color = Color(1.0, 0.44, 0.25)
	warm_light.light_energy = 0.72
	warm_light.omni_range = 7.0
	warm_light.shadow_enabled = false
	add_child(warm_light)

	var camera := Camera3D.new()
	camera.name = "TitleCamera"
	camera.position = Vector3(0.0, 3.0, 14.0)
	camera.fov = 42.0
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	camera.look_at(Vector3(0.6, 1.9, -1.0), Vector3.UP)
	camera.current = true

func _build_backdrop() -> void:
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(70.0, 70.0)
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.32, -4.0)
	floor.material_override = _material(Color(0.018, 0.026, 0.061), 0.08)
	add_child(floor)

	# A restrained ringed moon gives the title screen its own silhouette while
	# keeping the scene fully procedural and inexpensive on integrated graphics.
	var moon := MeshInstance3D.new()
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 2.55
	moon_mesh.height = 5.1
	moon_mesh.radial_segments = 64
	moon_mesh.rings = 32
	moon.mesh = moon_mesh
	moon.position = Vector3(3.2, 3.25, -3.4)
	moon.material_override = _material(Color(0.48, 0.59, 0.83), 0.18, true, Color(0.14, 0.22, 0.48), 0.5)
	add_child(moon)

	_moon_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.9
	ring_mesh.outer_radius = 3.0
	ring_mesh.rings = 88
	ring_mesh.ring_segments = 12
	_moon_ring.mesh = ring_mesh
	_moon_ring.position = moon.position
	_moon_ring.rotation = Vector3(0.88, 0.0, -0.24)
	_moon_ring.material_override = _material(Color(0.37, 0.83, 0.98), 0.25, true, Color(0.22, 0.62, 0.95), 1.2)
	_moon_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_moon_ring)

	var second_ring := MeshInstance3D.new()
	var second_ring_mesh := TorusMesh.new()
	second_ring_mesh.inner_radius = 3.28
	second_ring_mesh.outer_radius = 3.34
	second_ring_mesh.rings = 76
	second_ring_mesh.ring_segments = 10
	second_ring.mesh = second_ring_mesh
	second_ring.position = moon.position + Vector3(0.0, 0.12, 0.0)
	second_ring.rotation = Vector3(0.94, 0.0, 0.08)
	second_ring.material_override = _material(Color(0.87, 0.67, 0.43), 0.2, true, Color(0.54, 0.27, 0.09), 0.6)
	second_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(second_ring)

	# Broken slate monoliths frame the moon like the remnants of an old sanctuary.
	for index in range(9):
		var shard := MeshInstance3D.new()
		var shard_mesh := PrismMesh.new()
		shard_mesh.size = Vector3(0.24 + float(index % 3) * 0.10, 0.9 + float(index % 4) * 0.28, 0.24)
		shard.mesh = shard_mesh
		var side := -1.0 if index % 2 == 0 else 1.0
		var home := Vector3(2.0 + sin(float(index) * 1.7) * 2.5, 0.3 + float(index % 4) * 0.75, -1.0 - float(index % 3) * 1.1)
		home.x *= side
		shard.position = home
		shard.rotation_degrees = Vector3(float(index % 3) * 9.0, float(index) * 21.0, float(index % 4) * 5.0 - 8.0)
		shard.material_override = _material(Color(0.14, 0.24, 0.39) if index % 2 == 0 else Color(0.17, 0.29, 0.43), 0.15, true, Color(0.10, 0.23, 0.42), 0.18)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shard)
		_floating_shards.append(shard)
		_shard_home_positions.append(home)

	# A tiny distant wayfarer fire mirrors the hub without showing gameplay UI.
	var fire_base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.82
	base_mesh.bottom_radius = 1.0
	base_mesh.height = 0.14
	base_mesh.radial_segments = 9
	fire_base.mesh = base_mesh
	fire_base.position = Vector3(3.25, -0.13, 0.9)
	fire_base.material_override = _material(Color(0.13, 0.19, 0.33), 0.16)
	add_child(fire_base)
	for index in range(7):
		var coal := MeshInstance3D.new()
		var coal_mesh := SphereMesh.new()
		coal_mesh.radius = 0.13
		coal_mesh.height = 0.2
		coal.mesh = coal_mesh
		var angle := TAU * float(index) / 7.0
		coal.position = Vector3(3.25 + cos(angle) * 0.57, -0.015, 0.9 + sin(angle) * 0.57)
		coal.material_override = _material(Color(0.96, 0.34, 0.17) if index % 2 == 0 else Color(0.64, 0.20, 0.20), 0.05, true, Color(0.8, 0.16, 0.045), 1.0)
		coal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(coal)

func _material(color: Color, metallic: float = 0.0, glow: bool = false, emission_color: Color = Color(0.18, 0.52, 0.88), emission_strength: float = 0.65) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.48
	if glow:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = emission_strength
	return material

func _build_menu_ui() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 12
	_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu_layer)
	var full := Control.new()
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_layer.add_child(full)

	var left_shade := ColorRect.new()
	left_shade.anchor_right = 0.46
	left_shade.anchor_bottom = 1.0
	left_shade.color = Color(0.009, 0.018, 0.048, 0.82)
	left_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full.add_child(left_shade)

	var right_vignette := ColorRect.new()
	right_vignette.anchor_left = 0.45
	right_vignette.anchor_right = 1.0
	right_vignette.anchor_bottom = 1.0
	right_vignette.color = Color(0.008, 0.018, 0.045, 0.16)
	right_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full.add_child(right_vignette)

	var eyebrow := Label.new()
	eyebrow.position = Vector2(68, 76)
	eyebrow.size = Vector2(380, 26)
	eyebrow.text = "A WAYFARER'S TALE"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.43, 0.82, 0.94))
	full.add_child(eyebrow)

	var title := Label.new()
	title.position = Vector2(63, 102)
	title.size = Vector2(470, 90)
	title.text = "MOONVEIL"
	title.add_theme_font_size_override("font_size", 63)
	title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.035, 0.09, 0.95))
	title.add_theme_constant_override("outline_size", 3)
	full.add_child(title)

	var subtitle := Label.new()
	subtitle.position = Vector2(69, 184)
	subtitle.size = Vector2(400, 40)
	subtitle.text = "E C H O E S   B E Y O N D   T H E   V E I L"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.60, 0.72, 0.88))
	full.add_child(subtitle)

	var divider := ColorRect.new()
	divider.position = Vector2(70, 235)
	divider.size = Vector2(350, 1)
	divider.color = Color(0.26, 0.58, 0.75, 0.82)
	full.add_child(divider)

	_menu_buttons = VBoxContainer.new()
	_menu_buttons.position = Vector2(68, 253)
	_menu_buttons.size = Vector2(370, 250)
	_menu_buttons.add_theme_constant_override("separation", 6)
	full.add_child(_menu_buttons)

	_has_saved_wayfarer = bool(MoonveilProfiles.account_data.get("has_selected_character", false))
	_continue_button = _make_menu_button("CONTINUE", _has_saved_wayfarer)
	_continue_button.disabled = not _has_saved_wayfarer
	_continue_button.pressed.connect(_continue_game)
	_menu_buttons.add_child(_continue_button)

	_new_journey_button = _make_menu_button("NEW JOURNEY", not _has_saved_wayfarer)
	_new_journey_button.pressed.connect(_open_new_journey_confirmation)
	_menu_buttons.add_child(_new_journey_button)

	var settings_button := _make_menu_button("SYSTEM SETTINGS", false)
	settings_button.pressed.connect(_open_settings)
	_menu_buttons.add_child(settings_button)
	var credits_button := _make_menu_button("CREDITS & CONTROLS", false)
	credits_button.pressed.connect(_open_credits)
	_menu_buttons.add_child(credits_button)
	var quit_button := _make_menu_button("QUIT GAME", false)
	quit_button.pressed.connect(_quit_game)
	_menu_buttons.add_child(quit_button)

	var status_rule := ColorRect.new()
	status_rule.position = Vector2(70, 520)
	status_rule.size = Vector2(350, 1)
	status_rule.color = Color(0.20, 0.36, 0.52, 0.75)
	full.add_child(status_rule)

	var profile_title := Label.new()
	profile_title.position = Vector2(70, 534)
	profile_title.size = Vector2(330, 20)
	profile_title.text = "CURRENT WAYFARER"
	profile_title.add_theme_font_size_override("font_size", 10)
	profile_title.add_theme_color_override("font_color", Color(0.49, 0.69, 0.83))
	full.add_child(profile_title)

	_main_status = Label.new()
	_main_status.position = Vector2(70, 555)
	_main_status.size = Vector2(410, 58)
	_main_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_status.add_theme_font_size_override("font_size", 15)
	_main_status.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	full.add_child(_main_status)
	_refresh_profile_summary()

	var right_title := Label.new()
	right_title.anchor_left = 0.63
	right_title.anchor_right = 0.96
	right_title.anchor_top = 0.81
	right_title.anchor_bottom = 0.81
	right_title.offset_top = -6
	right_title.offset_bottom = 23
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_title.text = "THE REFUGE AWAITS"
	right_title.add_theme_font_size_override("font_size", 13)
	right_title.add_theme_color_override("font_color", Color(0.78, 0.89, 1.0))
	full.add_child(right_title)

	var right_caption := Label.new()
	right_caption.anchor_left = 0.62
	right_caption.anchor_right = 0.96
	right_caption.anchor_top = 0.85
	right_caption.anchor_bottom = 0.85
	right_caption.offset_top = 23
	right_caption.offset_bottom = 60
	right_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_caption.text = "A quiet fire. A sleeping moon.\nOne more journey beyond the veil."
	right_caption.add_theme_font_size_override("font_size", 12)
	right_caption.add_theme_color_override("font_color", Color(0.61, 0.74, 0.90))
	full.add_child(right_caption)

	var build_label := Label.new()
	build_label.position = Vector2(70, 687)
	build_label.size = Vector2(500, 20)
	build_label.text = "MOONVEIL  •  EARLY DEVELOPMENT BUILD"
	build_label.add_theme_font_size_override("font_size", 10)
	build_label.add_theme_color_override("font_color", Color(0.35, 0.49, 0.66))
	full.add_child(build_label)

	_build_credits_panel()
	_build_new_journey_confirmation()
	if _has_saved_wayfarer:
		_continue_button.grab_focus()
	else:
		_new_journey_button.grab_focus()

func _make_menu_button(caption: String, emphasized: bool) -> Button:
	var button := Button.new()
	button.text = "   " + caption
	button.custom_minimum_size = Vector2(355, 44)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.22, 0.34, 0.68) if emphasized else Color(0.025, 0.045, 0.085, 0.22)
	normal.border_color = Color(0.31, 0.69, 0.85, 0.86) if emphasized else Color(0.19, 0.31, 0.44, 0.28)
	normal.set_border_width_all(1)
	normal.border_width_left = 3 if emphasized else 1
	normal.set_corner_radius_all(3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.31, 0.45, 0.92)
	hover.border_color = Color(0.46, 0.83, 0.96, 0.96)
	hover.border_width_left = 3
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.17, 0.37, 0.51, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.78, 0.87, 0.98))
	button.add_theme_color_override("font_hover_color", Color(0.96, 0.99, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.38, 0.47, 0.60, 0.72))
	return button

func _build_credits_panel() -> void:
	_credits_panel = Control.new()
	_credits_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_layer.add_child(_credits_panel)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.014, 0.035, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_credits_panel.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -210
	panel.offset_bottom = 210
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.085, 0.99)
	style.border_color = Color(0.25, 0.57, 0.77, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 26.0
	style.content_margin_bottom = 26.0
	panel.add_theme_stylebox_override("panel", style)
	_credits_panel.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "MOONVEIL ARCHIVE"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(0.84, 0.93, 1.0))
	column.add_child(heading)
	var body := Label.new()
	body.text = "A small anime-fantasy RPG prototype, built around a quiet refuge and short expeditions beyond the veil.\n\nCONTROLS\nWASD  Move\nMouse 1  Attack\nSpace  Dodge\nQ  Character skill\nE  Interact\nI  Satchel\nEsc  Pause\n\nBuilt with Godot. Character and environment meshes are procedural prototypes."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.69, 0.80, 0.93))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_credits_back_button = _make_menu_button("BACK TO TITLE", true)
	_credits_back_button.pressed.connect(_close_credits)
	column.add_child(_credits_back_button)
	_credits_panel.hide()

func _build_new_journey_confirmation() -> void:
	_confirm_panel = Control.new()
	_confirm_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_panel.hide()
	_menu_layer.add_child(_confirm_panel)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.006, 0.012, 0.032, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_panel.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -285.0
	panel.offset_right = 285.0
	panel.offset_top = -165.0
	panel.offset_bottom = 165.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.085, 0.99)
	style.border_color = Color(0.30, 0.65, 0.82, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 25.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	_confirm_panel.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var eyebrow := Label.new()
	eyebrow.text = "A NEW CHAPTER"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", Color(0.42, 0.80, 0.93))
	column.add_child(eyebrow)
	var heading := Label.new()
	heading.text = "BEGIN A NEW JOURNEY?"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	column.add_child(heading)
	_confirm_body_label = Label.new()
	_confirm_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_body_label.add_theme_font_size_override("font_size", 14)
	_confirm_body_label.add_theme_color_override("font_color", Color(0.67, 0.79, 0.92))
	_confirm_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_confirm_body_label)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.color = Color(0.22, 0.46, 0.64, 0.78)
	column.add_child(rule)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	_confirm_back_button = _make_menu_button("KEEP SAVED PROFILE" if _has_saved_wayfarer else "GO BACK", false)
	_confirm_back_button.custom_minimum_size = Vector2(0, 44)
	_confirm_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_back_button.pressed.connect(_close_new_journey_confirmation)
	actions.add_child(_confirm_back_button)
	_confirm_start_button = _make_menu_button("BEGIN JOURNEY", true)
	_confirm_start_button.custom_minimum_size = Vector2(0, 44)
	_confirm_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_start_button.pressed.connect(_start_new_journey)
	actions.add_child(_confirm_start_button)

func _open_new_journey_confirmation() -> void:
	if _has_saved_wayfarer:
		_confirm_body_label.text = "This returns you to the Refuge and asks you to choose a wayfarer again. Your character profiles and permanent progression remain saved."
	else:
		_confirm_body_label.text = "Begin in the Refuge, then choose your first wayfarer at the fire. Your future character and progression saves will be kept locally."
	_confirm_panel.show()
	_confirm_start_button.grab_focus()

func _close_new_journey_confirmation() -> void:
	_confirm_panel.hide()
	_new_journey_button.grab_focus()

func _start_new_journey() -> void:
	var had_selection := bool(MoonveilProfiles.account_data.get("has_selected_character", false))
	MoonveilProfiles.account_data["has_selected_character"] = false
	if not MoonveilProfiles.save_account():
		MoonveilProfiles.account_data["has_selected_character"] = had_selection
		_main_status.text = "Could not save this choice. Your existing profile is unchanged."
		_confirm_panel.hide()
		return
	_confirm_panel.hide()
	_enter_refuge()

func _refresh_profile_summary() -> void:
	_has_saved_wayfarer = bool(MoonveilProfiles.account_data.get("has_selected_character", false))
	if not _has_saved_wayfarer:
		_main_status.text = "YOUR JOURNEY AWAITS\nChoose your first wayfarer at the Refuge fire."
		return
	var active_id := String(MoonveilProfiles.account_data.get("active_character_id", "moonveil_mage"))
	var active_name := "Astra Vale  ·  Sword Duelist" if active_id == "sword_duelist" else "Moonveil Mage"
	var regions := int(MoonveilMeta.unlocked_regions.size())
	var region_word := "region" if regions == 1 else "regions"
	_main_status.text = "%s\nProfile saved locally  ·  %d %s discovered" % [active_name, regions, region_word]

func _continue_game() -> void:
	if not bool(MoonveilProfiles.account_data.get("has_selected_character", false)):
		_main_status.text = "No active wayfarer yet. Choose NEW JOURNEY to begin."
		return
	_enter_refuge()

func _enter_refuge() -> void:
	var error := get_tree().change_scene_to_file(REFUGE_SCENE_PATH)
	if error != OK:
		_main_status.text = "Unable to enter the Refuge (error %d)." % error

func _focus_default_menu_button() -> void:
	if _has_saved_wayfarer and is_instance_valid(_continue_button):
		_continue_button.grab_focus()
	elif is_instance_valid(_new_journey_button):
		_new_journey_button.grab_focus()

func _open_settings() -> void:
	if is_instance_valid(_settings_panel):
		_settings_panel.queue_free()
	_settings_panel = SETTINGS_PANEL_SCENE.instantiate() as Control
	_settings_panel.closed.connect(_on_settings_closed)
	_menu_layer.add_child(_settings_panel)

func _on_settings_closed() -> void:
	if is_instance_valid(_settings_panel):
		_settings_panel.queue_free()
	_settings_panel = null
	_focus_default_menu_button()

func _open_credits() -> void:
	_credits_panel.show()
	_credits_back_button.grab_focus()

func _close_credits() -> void:
	_credits_panel.hide()
	_focus_default_menu_button()

func _quit_game() -> void:
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_instance_valid(_settings_panel):
		return
	if is_instance_valid(_confirm_panel) and _confirm_panel.visible:
		get_viewport().set_input_as_handled()
		_close_new_journey_confirmation()
	elif is_instance_valid(_credits_panel) and _credits_panel.visible:
		get_viewport().set_input_as_handled()
		_close_credits()
