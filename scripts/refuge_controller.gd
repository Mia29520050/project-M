extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const DUELIST_SCENE: PackedScene = preload("res://scenes/sword_duelist.tscn")
const RUN_SCENE_PATH := "res://scenes/main.tscn"
const SHRINE_POSITION := Vector3(0.0, 0.0, -1.0)
const INTERACT_RANGE := 4.8
const CAMPFIRE_POSITION := Vector3(-5.4, 0.0, 1.0)
const CAMPFIRE_INTERACT_RANGE := 3.8

var player: Node3D
var camera: Camera3D
var prompt_label: Label
var status_label: Label
var pause_label: Label
var _transitioning := false
var _selection_open := false
var selection_layer: CanvasLayer
var character_selection_panel: PanelContainer
var mage_button: Button
var duelist_button: Button
var mage_card_heading: Label
var duelist_card_heading: Label
var confirm_button: Button
var selection_status: Label
var selected_character_id := "moonveil_mage"
var _last_clicked_character := ""
var _last_click_msec := 0
var _showcase_time := 0.0
var showcase_roots: Array[Node3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_environment()
	_build_world()
	_build_hud()
	_build_character_selection_ui()
	_create_player()
	_create_camera()
	_refresh_prompt()

func _process(delta: float) -> void:
	_showcase_time += delta
	for index in range(showcase_roots.size()):
		if is_instance_valid(showcase_roots[index]):
			showcase_roots[index].position.y = sin(_showcase_time * 1.35 + float(index)) * 0.025
			showcase_roots[index].rotation.y = 0.25 + sin(_showcase_time * 0.55 + float(index)) * 0.07
	if is_instance_valid(camera) and is_instance_valid(player):
		camera.global_position = player.global_position + Vector3(0.0, 17.0, 13.0)
		camera.look_at(player.global_position + Vector3(0.0, 0.75, 0.0), Vector3.UP)
	_refresh_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause"):
		if _selection_open:
			_close_character_selection()
		else:
			get_tree().paused = not get_tree().paused
			if is_instance_valid(player):
				player.controls_locked = get_tree().paused
			if is_instance_valid(pause_label):
				pause_label.visible = get_tree().paused
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused or _transitioning or _selection_open:
		return
	if event.is_action_pressed("interact"):
		# The Refuge has two distinct interaction points: roster at the fire, journey at the shrine.
		var viewport := get_viewport()
		if is_instance_valid(viewport):
			viewport.set_input_as_handled()
		if not is_instance_valid(player):
			return
		if player.global_position.distance_to(CAMPFIRE_POSITION) <= CAMPFIRE_INTERACT_RANGE:
			_open_character_selection()
		elif player.global_position.distance_to(SHRINE_POSITION) <= INTERACT_RANGE:
			_start_run()
		else:
			_show_message("Visit the Wayfarers' Fire to choose a character, or the Moon Shrine to enter Whispering Woods.")

func _start_run() -> void:
	if _transitioning:
		return
	_transitioning = true
	if is_instance_valid(prompt_label):
		prompt_label.text = "The Veil opens…"
	var error: Error = get_tree().change_scene_to_file(RUN_SCENE_PATH)
	if error != OK:
		_transitioning = false
		_show_message("Could not enter Whispering Woods (error %d)." % error)

func _create_player() -> void:
	var active_id := String(MoonveilProfiles.account_data.get("active_character_id", "moonveil_mage"))
	_spawn_selected_player(active_id, Vector3(0.0, 0.0, 7.0))

func _spawn_selected_player(character_id: String, spawn_position: Vector3) -> void:
	var selected_scene: PackedScene = DUELIST_SCENE if character_id == "sword_duelist" else PLAYER_SCENE
	player = selected_scene.instantiate() as CharacterBody3D
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = spawn_position
	player.controls_locked = _selection_open or get_tree().paused
	player.notification_requested.connect(_show_message)
	add_child(player)

func _replace_player(character_id: String) -> void:
	var spawn_position := player.global_position if is_instance_valid(player) else Vector3(0.0, 0.0, 7.0)
	if is_instance_valid(player):
		var previous_player := player
		remove_child(previous_player)
		previous_player.queue_free()
	_spawn_selected_player(character_id, spawn_position)

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "RefugeCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.near = 0.1
	camera.far = 120.0
	add_child(camera)
	camera.global_position = player.global_position + Vector3(0.0, 17.0, 13.0)
	camera.look_at(player.global_position + Vector3(0.0, 0.65, 0.0), Vector3.UP)
	camera.current = true

func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.07, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.67, 0.73, 0.98)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sunlight.light_color = Color(0.77, 0.83, 1.0)
	sunlight.light_energy = 0.75
	sunlight.shadow_enabled = true
	add_child(sunlight)

func _build_world() -> void:
	var ground := StaticBody3D.new()
	ground.name = "RefugeGround"
	ground.position.y = -0.2
	add_child(ground)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(30.0, 0.4, 30.0)
	ground_collision.shape = ground_shape
	ground.add_child(ground_collision)
	var ground_mesh := MeshInstance3D.new()
	var ground_box := BoxMesh.new()
	ground_box.size = Vector3(30.0, 0.4, 30.0)
	ground_mesh.mesh = ground_box
	ground_mesh.material_override = _material(Color(0.13, 0.22, 0.30))
	ground.add_child(ground_mesh)

	# Safe-zone shrine: it is visual-only on top of the ground collider.
	var shrine_pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.25
	pad_mesh.bottom_radius = 2.45
	pad_mesh.height = 0.14
	pad_mesh.radial_segments = 48
	shrine_pad.mesh = pad_mesh
	shrine_pad.position = SHRINE_POSITION + Vector3(0.0, 0.025, 0.0)
	shrine_pad.material_override = _material(Color(0.25, 0.31, 0.48), 0.25)
	add_child(shrine_pad)

	var outer_ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.68
	ring_mesh.outer_radius = 1.80
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 64
	outer_ring.mesh = ring_mesh
	outer_ring.position = SHRINE_POSITION + Vector3(0.0, 0.12, 0.0)
	outer_ring.material_override = _material(Color(0.34, 0.72, 1.0), 0.1, true)
	outer_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outer_ring)

	_add_crystal(SHRINE_POSITION + Vector3(0.0, 0.0, 0.0), Color(0.46, 0.82, 1.0), 1.7)
	_add_crystal(SHRINE_POSITION + Vector3(-1.15, 0.0, 0.55), Color(0.77, 0.54, 1.0), 0.95)
	_add_crystal(SHRINE_POSITION + Vector3(1.15, 0.0, 0.55), Color(0.77, 0.54, 1.0), 0.95)
	_add_crystal(Vector3(-5.5, 0.0, -5.0), Color(0.38, 0.71, 0.91), 0.78)
	_add_crystal(Vector3(5.8, 0.0, 4.8), Color(0.67, 0.45, 0.91), 0.85)

	var title := Label3D.new()
	title.text = "MOONVEIL REFUGE"
	title.font_size = 42
	title.pixel_size = 0.007
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(0.78, 0.89, 1.0)
	title.position = SHRINE_POSITION + Vector3(0.0, 3.0, -0.2)
	add_child(title)

	# Simple stones mark the route into the next run without building the Woods here.
	for index in range(7):
		var stone := MeshInstance3D.new()
		var stone_mesh := BoxMesh.new()
		stone_mesh.size = Vector3(1.7, 0.055, 0.82)
		stone.mesh = stone_mesh
		stone.position = Vector3(0.0, 0.03, -4.0 - float(index) * 1.35)
		stone.rotation.y = sin(float(index) * 0.65) * 0.06
		stone.material_override = _material(Color(0.30, 0.37, 0.51) if index % 2 == 0 else Color(0.24, 0.31, 0.44), 0.08)
		add_child(stone)

	_create_fire_camp()
	_create_character_showcase("moonveil_mage", CAMPFIRE_POSITION + Vector3(-1.85, 0.0, 0.55))
	_create_character_showcase("sword_duelist", CAMPFIRE_POSITION + Vector3(1.85, 0.0, 0.55))

func _create_fire_camp() -> void:
	var stone_circle := MeshInstance3D.new()
	var circle_mesh := CylinderMesh.new()
	circle_mesh.top_radius = 1.25
	circle_mesh.bottom_radius = 1.38
	circle_mesh.height = 0.12
	circle_mesh.radial_segments = 36
	stone_circle.mesh = circle_mesh
	stone_circle.position = CAMPFIRE_POSITION + Vector3(0.0, 0.055, 0.0)
	stone_circle.material_override = _material(Color(0.22, 0.27, 0.39), 0.18)
	add_child(stone_circle)

	for index in range(9):
		var angle := TAU * float(index) / 9.0
		var stone := MeshInstance3D.new()
		var stone_mesh := SphereMesh.new()
		stone_mesh.radius = 0.20 if index % 2 == 0 else 0.16
		stone_mesh.height = 0.21
		stone.mesh = stone_mesh
		stone.material_override = _material(Color(0.36, 0.39, 0.52) if index % 2 == 0 else Color(0.27, 0.31, 0.43))
		stone.position = CAMPFIRE_POSITION + Vector3(cos(angle) * 0.93, 0.18, sin(angle) * 0.93)
		add_child(stone)

	for index in range(3):
		var log := MeshInstance3D.new()
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.11
		log_mesh.bottom_radius = 0.12
		log_mesh.height = 1.12
		log.mesh = log_mesh
		log.rotation_degrees.z = 90.0
		log.rotation.y = float(index) * 1.05
		log.position = CAMPFIRE_POSITION + Vector3(0.0, 0.24 + float(index) * 0.06, 0.0)
		log.material_override = _material(Color(0.25, 0.13, 0.16))
		add_child(log)

	var outer_flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.38
	flame_mesh.height = 1.12
	outer_flame.mesh = flame_mesh
	outer_flame.scale = Vector3(0.82, 1.0, 0.82)
	outer_flame.position = CAMPFIRE_POSITION + Vector3(0.0, 0.78, 0.0)
	outer_flame.material_override = _material(Color(1.0, 0.32, 0.11), 0.0, true)
	add_child(outer_flame)

	var inner_flame := MeshInstance3D.new()
	var inner_mesh := SphereMesh.new()
	inner_mesh.radius = 0.23
	inner_mesh.height = 0.83
	inner_flame.mesh = inner_mesh
	inner_flame.scale = Vector3(0.72, 1.0, 0.72)
	inner_flame.position = CAMPFIRE_POSITION + Vector3(0.0, 0.78, 0.0)
	inner_flame.material_override = _material(Color(1.0, 0.76, 0.34), 0.0, true)
	add_child(inner_flame)

	var fire_light := OmniLight3D.new()
	fire_light.position = CAMPFIRE_POSITION + Vector3(0.0, 1.15, 0.0)
	fire_light.light_color = Color(1.0, 0.42, 0.22)
	fire_light.light_energy = 1.4
	fire_light.omni_range = 8.0
	fire_light.shadow_enabled = false
	add_child(fire_light)

	var label := Label3D.new()
	label.text = "WAYFARERS' FIRE\nE  ·  CHOOSE A CHARACTER"
	label.font_size = 30
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.79, 0.62)
	label.position = CAMPFIRE_POSITION + Vector3(0.0, 2.3, -0.15)
	add_child(label)

func _create_character_showcase(character_id: String, world_position: Vector3) -> void:
	var root := Node3D.new()
	root.position = world_position
	root.rotation.y = 0.25
	root.scale = Vector3(0.88, 0.88, 0.88)
	add_child(root)
	showcase_roots.append(root)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 1.24
	body.mesh = body_mesh
	body.material_override = _material(Color(0.20, 0.28, 0.58) if character_id == "moonveil_mage" else Color(0.36, 0.10, 0.24), 0.15)
	body.position.y = 0.85
	root.add_child(body)

	var chest := MeshInstance3D.new()
	var chest_mesh := CapsuleMesh.new()
	chest_mesh.radius = 0.27
	chest_mesh.height = 0.83
	chest.mesh = chest_mesh
	chest.material_override = _material(Color(0.27, 0.73, 0.91) if character_id == "moonveil_mage" else Color(0.84, 0.34, 0.49), 0.2)
	chest.position.y = 0.91
	root.add_child(chest)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.27
	head_mesh.height = 0.53
	head.mesh = head_mesh
	head.material_override = _material(Color(1.0, 0.80, 0.73))
	head.position.y = 1.63
	root.add_child(head)

	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.30
	hair_mesh.height = 0.31
	hair.mesh = hair_mesh
	hair.material_override = _material(Color(0.20, 0.13, 0.39) if character_id == "moonveil_mage" else Color(0.75, 0.81, 0.94), 0.1)
	hair.position = Vector3(0.0, 1.82, -0.05)
	root.add_child(hair)

	var weapon := MeshInstance3D.new()
	if character_id == "moonveil_mage":
		var staff_mesh := CylinderMesh.new()
		staff_mesh.top_radius = 0.035
		staff_mesh.bottom_radius = 0.045
		staff_mesh.height = 1.14
		weapon.mesh = staff_mesh
		weapon.material_override = _material(Color(0.65, 0.49, 0.94), 0.25, true)
		weapon.position = Vector3(0.48, 0.72, 0.05)
		weapon.rotation_degrees.z = -10.0
	else:
		var sword_mesh := BoxMesh.new()
		sword_mesh.size = Vector3(0.09, 0.95, 0.06)
		weapon.mesh = sword_mesh
		weapon.material_override = _material(Color(0.84, 0.92, 1.0), 0.65, true)
		weapon.position = Vector3(0.48, 1.03, 0.04)
		weapon.rotation_degrees.z = -30.0
	root.add_child(weapon)

	var title := Label3D.new()
	title.text = "MOONVEIL MAGE" if character_id == "moonveil_mage" else "ASTRA VALE  ·  DUELIST"
	title.font_size = 24
	title.pixel_size = 0.006
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(0.70, 0.88, 1.0) if character_id == "moonveil_mage" else Color(1.0, 0.73, 0.84)
	title.position.y = 2.2
	root.add_child(title)

func _material(color: Color, metallic: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.42
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.4
	return material

func _add_crystal(position_in_world: Vector3, color: Color, height: float) -> void:
	var crystal := MeshInstance3D.new()
	var crystal_mesh := CylinderMesh.new()
	crystal_mesh.top_radius = 0.025
	crystal_mesh.bottom_radius = 0.25 * height
	crystal_mesh.height = height
	crystal_mesh.radial_segments = 5
	crystal.mesh = crystal_mesh
	crystal.position = position_in_world + Vector3(0.0, height * 0.5 + 0.08, 0.0)
	crystal.rotation_degrees.z = 7.0
	crystal.material_override = _material(color, 0.2, true)
	add_child(crystal)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = 8
	add_child(layer)
	var full := Control.new()
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(full)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(530.0, 145.0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -265.0
	panel.offset_right = 265.0
	panel.offset_top = 22.0
	panel.offset_bottom = 167.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.105, 0.92)
	style.border_color = Color(0.40, 0.61, 0.90, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	full.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var header := Label.new()
	header.text = "MOONVEIL REFUGE"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	box.add_child(header)
	var description := Label.new()
	description.text = "A safe haven between journeys. Run level, XP and Moonshards reset when a run ends."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.75, 0.81, 0.94))
	box.add_child(description)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 15)
	prompt_label.add_theme_color_override("font_color", Color(0.98, 0.83, 0.96))
	box.add_child(prompt_label)

	status_label = Label.new()
	status_label.position = Vector2(24.0, 180.0)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.84, 1.0))
	full.add_child(status_label)

	pause_label = Label.new()
	pause_label.text = "PAUSED"
	pause_label.anchor_left = 0.5
	pause_label.anchor_right = 0.5
	pause_label.anchor_top = 0.5
	pause_label.anchor_bottom = 0.5
	pause_label.offset_left = -150.0
	pause_label.offset_right = 150.0
	pause_label.offset_top = -40.0
	pause_label.offset_bottom = 40.0
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.add_theme_font_size_override("font_size", 34)
	pause_label.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	full.add_child(pause_label)
	pause_label.hide()


func _build_character_selection_ui() -> void:
	selection_layer = CanvasLayer.new()
	selection_layer.layer = 20
	selection_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(selection_layer)
	var full := Control.new()
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection_layer.add_child(full)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.02, 0.06, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	full.add_child(backdrop)

	character_selection_panel = PanelContainer.new()
	character_selection_panel.anchor_left = 0.5
	character_selection_panel.anchor_right = 0.5
	character_selection_panel.anchor_top = 0.5
	character_selection_panel.anchor_bottom = 0.5
	character_selection_panel.offset_left = -450.0
	character_selection_panel.offset_right = 450.0
	character_selection_panel.offset_top = -270.0
	character_selection_panel.offset_bottom = 270.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.055, 0.12, 0.98)
	panel_style.border_color = Color(0.55, 0.63, 0.92, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(20)
	panel_style.content_margin_left = 24.0
	panel_style.content_margin_right = 24.0
	panel_style.content_margin_top = 20.0
	panel_style.content_margin_bottom = 20.0
	character_selection_panel.add_theme_stylebox_override("panel", panel_style)
	full.add_child(character_selection_panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	character_selection_panel.add_child(column)

	var title := Label.new()
	title.text = "WAYFARERS BY THE FIRE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Choose the hero you will take into the Whispering Woods. Double-click a portrait or select one and confirm."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.73, 0.80, 0.94))
	column.add_child(subtitle)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 18)
	column.add_child(card_row)

	mage_button = Button.new()
	mage_button.custom_minimum_size = Vector2(385.0, 250.0)
	mage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mage_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mage_button.text = ""
	mage_button.pressed.connect(_on_character_button_pressed.bind("moonveil_mage"))
	card_row.add_child(mage_button)
	mage_card_heading = _add_character_card_content(mage_button, "moonveil_mage")

	duelist_button = Button.new()
	duelist_button.custom_minimum_size = Vector2(385.0, 250.0)
	duelist_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duelist_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	duelist_button.text = ""
	duelist_button.pressed.connect(_on_character_button_pressed.bind("sword_duelist"))
	card_row.add_child(duelist_button)
	duelist_card_heading = _add_character_card_content(duelist_button, "sword_duelist")

	selection_status = Label.new()
	selection_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_status.add_theme_font_size_override("font_size", 13)
	selection_status.add_theme_color_override("font_color", Color(0.95, 0.80, 0.94))
	column.add_child(selection_status)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	confirm_button = Button.new()
	confirm_button.text = "CONFIRM WAYFARER"
	confirm_button.custom_minimum_size = Vector2(240.0, 46.0)
	confirm_button.add_theme_font_size_override("font_size", 16)
	confirm_button.pressed.connect(_confirm_character_selection)
	actions.add_child(confirm_button)
	var cancel_button := Button.new()
	cancel_button.text = "CANCEL  [ESC]"
	cancel_button.custom_minimum_size = Vector2(180.0, 46.0)
	cancel_button.pressed.connect(_close_character_selection)
	actions.add_child(cancel_button)

	character_selection_panel.hide()
	_refresh_character_buttons()


func _add_character_card_content(button: Button, character_id: String) -> Label:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(0.0, 137.0)
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 140)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	# Only render these lightweight portraits while their selection panel is visible.
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	preview_container.add_child(viewport)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.05, 0.11, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.76, 0.81, 1.0)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28.0, -25.0, 0.0)
	key_light.light_color = Color(0.77, 0.85, 1.0)
	key_light.light_energy = 1.4
	key_light.shadow_enabled = false
	viewport.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.0, 2.0, 2.0)
	fill_light.light_color = Color(1.0, 0.50, 0.69) if character_id == "sword_duelist" else Color(0.50, 0.72, 1.0)
	fill_light.light_energy = 0.8
	fill_light.omni_range = 7.0
	fill_light.shadow_enabled = false
	viewport.add_child(fill_light)

	var figure := Node3D.new()
	figure.rotation.y = -0.18
	viewport.add_child(figure)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 1.25
	body.mesh = body_mesh
	body.material_override = _material(Color(0.20, 0.28, 0.58) if character_id == "moonveil_mage" else Color(0.32, 0.09, 0.23), 0.16)
	body.position.y = 0.83
	figure.add_child(body)

	var chest := MeshInstance3D.new()
	var chest_mesh := CapsuleMesh.new()
	chest_mesh.radius = 0.275
	chest_mesh.height = 0.84
	chest.mesh = chest_mesh
	chest.material_override = _material(Color(0.28, 0.76, 0.92) if character_id == "moonveil_mage" else Color(0.83, 0.33, 0.49), 0.2)
	chest.position.y = 0.91
	figure.add_child(chest)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.27
	head_mesh.height = 0.54
	head.mesh = head_mesh
	head.material_override = _material(Color(1.0, 0.80, 0.73))
	head.position.y = 1.63
	figure.add_child(head)

	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.30
	hair_mesh.height = 0.34
	hair.mesh = hair_mesh
	hair.material_override = _material(Color(0.20, 0.12, 0.38) if character_id == "moonveil_mage" else Color(0.76, 0.82, 0.96), 0.12, character_id == "sword_duelist")
	hair.position = Vector3(0.0, 1.82, -0.055)
	figure.add_child(hair)

	var weapon := MeshInstance3D.new()
	if character_id == "moonveil_mage":
		var staff_mesh := CylinderMesh.new()
		staff_mesh.top_radius = 0.035
		staff_mesh.bottom_radius = 0.045
		staff_mesh.height = 1.25
		weapon.mesh = staff_mesh
		weapon.material_override = _material(Color(0.70, 0.52, 0.97), 0.28, true)
		weapon.position = Vector3(0.48, 0.80, 0.04)
		weapon.rotation_degrees.z = -13.0
	else:
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.095, 1.02, 0.065)
		weapon.mesh = blade_mesh
		weapon.material_override = _material(Color(0.85, 0.93, 1.0), 0.75, true)
		weapon.position = Vector3(0.48, 1.04, 0.04)
		weapon.rotation_degrees.z = -28.0
	figure.add_child(weapon)

	if character_id == "sword_duelist":
		var guard := MeshInstance3D.new()
		var guard_mesh := BoxMesh.new()
		guard_mesh.size = Vector3(0.32, 0.07, 0.09)
		guard.mesh = guard_mesh
		guard.material_override = _material(Color(1.0, 0.55, 0.70), 0.45, true)
		guard.position = Vector3(0.48, 0.54, 0.04)
		guard.rotation_degrees.z = -28.0
		figure.add_child(guard)
	else:
		var crystal := MeshInstance3D.new()
		var crystal_mesh := SphereMesh.new()
		crystal_mesh.radius = 0.13
		crystal_mesh.height = 0.25
		crystal.mesh = crystal_mesh
		crystal.material_override = _material(Color(0.62, 0.91, 1.0), 0.1, true)
		crystal.position = Vector3(0.48, 1.42, 0.04)
		figure.add_child(crystal)

	var preview_camera := Camera3D.new()
	preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	preview_camera.size = 2.9
	preview_camera.position = Vector3(0.0, 1.03, 4.2)
	viewport.add_child(preview_camera)
	preview_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	preview_camera.current = true

	var heading := Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0) if character_id == "moonveil_mage" else Color(1.0, 0.72, 0.83))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(heading)

	var description := Label.new()
	description.text = "Ranged arcane caster · homing Moonbolt" if character_id == "moonveil_mage" else "Close-range 3-hit combo · Crescent Lunge"
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.75, 0.81, 0.94))
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(description)
	return heading

func _selection_card_style(is_selected: bool, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.085, 0.16, 0.98) if is_selected else Color(0.045, 0.055, 0.115, 0.98)
	style.border_color = accent if is_selected else Color(0.25, 0.30, 0.46, 0.95)
	style.set_border_width_all(3 if is_selected else 1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _refresh_character_buttons() -> void:
	if not is_instance_valid(mage_button) or not is_instance_valid(duelist_button):
		return
	var mage_selected := selected_character_id == "moonveil_mage"
	var duelist_selected := selected_character_id == "sword_duelist"
	mage_card_heading.text = "✦  MOONVEIL MAGE  ·  SELECTED" if mage_selected else "MOONVEIL MAGE"
	duelist_card_heading.text = "✦  ASTRA VALE  ·  SELECTED" if duelist_selected else "ASTRA VALE · SWORD DUELIST"
	mage_button.add_theme_stylebox_override("normal", _selection_card_style(mage_selected, Color(0.47, 0.78, 1.0)))
	mage_button.add_theme_stylebox_override("hover", _selection_card_style(mage_selected, Color(0.58, 0.85, 1.0)))
	mage_button.add_theme_stylebox_override("pressed", _selection_card_style(true, Color(0.60, 0.88, 1.0)))
	duelist_button.add_theme_stylebox_override("normal", _selection_card_style(duelist_selected, Color(1.0, 0.46, 0.68)))
	duelist_button.add_theme_stylebox_override("hover", _selection_card_style(duelist_selected, Color(1.0, 0.63, 0.79)))
	duelist_button.add_theme_stylebox_override("pressed", _selection_card_style(true, Color(1.0, 0.63, 0.79)))
	if is_instance_valid(selection_status):
		selection_status.text = "Current selection: Moonveil Mage" if mage_selected else "Current selection: Astra Vale · Sword Duelist"

func _open_character_selection() -> void:
	if _selection_open or _transitioning or not is_instance_valid(player):
		return
	_selection_open = true
	selected_character_id = String(MoonveilProfiles.account_data.get("active_character_id", "moonveil_mage"))
	_last_clicked_character = ""
	_last_click_msec = 0
	player.controls_locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_character_buttons()
	character_selection_panel.show()

func _close_character_selection() -> void:
	_selection_open = false
	if is_instance_valid(character_selection_panel):
		character_selection_panel.hide()
	if is_instance_valid(player):
		player.controls_locked = get_tree().paused
	_last_clicked_character = ""
	_refresh_prompt()

func _on_character_button_pressed(character_id: String) -> void:
	selected_character_id = character_id
	_refresh_character_buttons()
	var now := Time.get_ticks_msec()
	if _last_clicked_character == character_id and now - _last_click_msec <= 450:
		_confirm_character_selection()
		return
	_last_clicked_character = character_id
	_last_click_msec = now

func _confirm_character_selection() -> void:
	if not _selection_open:
		return
	var unlocked: Array = MoonveilProfiles.account_data.get("unlocked_character_ids", [])
	if not unlocked.has(selected_character_id):
		selection_status.text = "This wayfarer is not unlocked on this account."
		return
	if not MoonveilProfiles.set_active_character(selected_character_id):
		selection_status.text = "Could not save this selection. Your current wayfarer is unchanged."
		return
	if not MoonveilProfiles.save_active_character():
		selection_status.text = "Selected in this session, but saving the profile failed. Check storage space."
		return
	_replace_player(selected_character_id)
	_close_character_selection()
	var display_name := "Astra Vale, Sword Duelist" if selected_character_id == "sword_duelist" else "Moonveil Mage"
	_show_message("Wayfarer ready: %s. Visit the Moon Shrine when you are ready to depart." % display_name)
	_refresh_prompt()

func _refresh_prompt() -> void:
	if not is_instance_valid(prompt_label) or not is_instance_valid(player):
		return
	if _selection_open:
		prompt_label.text = "Choose a wayfarer by the fire"
	elif _transitioning:
		prompt_label.text = "The Veil opens…"
	elif player.global_position.distance_to(CAMPFIRE_POSITION) <= CAMPFIRE_INTERACT_RANGE:
		prompt_label.text = "Press E to choose your character at the Wayfarers' Fire"
	elif player.global_position.distance_to(SHRINE_POSITION) <= INTERACT_RANGE:
		prompt_label.text = "Press E at the Moon Shrine to enter Whispering Woods"
	else:
		prompt_label.text = "Wayfarers' Fire: choose a character   ·   Moon Shrine: start a journey"
	if is_instance_valid(status_label):
		var active_name := "Astra Vale · Sword Duelist" if player.character_id == "sword_duelist" else "Moonveil Mage"
		status_label.text = "ACTIVE WAYFARER: %s   ·   PERMANENT CURRENCY: %d   ·   REGIONS: %d" % [active_name, MoonveilMeta.permanent_currency, MoonveilMeta.unlocked_regions.size()]

func _show_message(message: String) -> void:
	if not is_instance_valid(prompt_label):
		return
	prompt_label.text = message
