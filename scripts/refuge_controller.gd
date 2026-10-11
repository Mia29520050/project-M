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
var selection_heading: Label
var selection_details: Label
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
	if get_tree().paused or _transitioning:
		return
	if _selection_open:
		if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]):
			_confirm_character_selection()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if not is_instance_valid(player):
			return
		var nearby_character := _nearest_showcase_character(3.4)
		if not nearby_character.is_empty():
			_select_character_in_world(nearby_character)
		elif player.global_position.distance_to(SHRINE_POSITION) <= INTERACT_RANGE:
			_start_run()
		else:
			_show_message("Approach a wayfarer at the fire to choose them, or visit the Moon Shrine to depart.")

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
	camera.size = 16.0
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
	label.text = "WAYFARERS' FIRE\nCLICK A WAYFARER  ·  E NEAR THEM"
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

	var selection_pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 0.66
	pad_mesh.bottom_radius = 0.70
	pad_mesh.height = 0.055
	pad_mesh.radial_segments = 32
	selection_pad.mesh = pad_mesh
	selection_pad.position.y = 0.045
	selection_pad.material_override = _material(Color(0.20, 0.55, 0.95) if character_id == "moonveil_mage" else Color(0.90, 0.26, 0.50), 0.22, true)
	root.add_child(selection_pad)

	var interaction_body := StaticBody3D.new()
	interaction_body.name = "CharacterInteraction"
	interaction_body.collision_layer = 1
	interaction_body.collision_mask = 0
	interaction_body.input_ray_pickable = true
	interaction_body.position.y = 1.0
	var interaction_shape := CollisionShape3D.new()
	var interaction_capsule := CapsuleShape3D.new()
	interaction_capsule.radius = 0.68
	interaction_capsule.height = 2.25
	interaction_shape.shape = interaction_capsule
	interaction_body.add_child(interaction_shape)
	root.add_child(interaction_body)
	interaction_body.input_event.connect(_on_showcase_input_event.bind(character_id))

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
	title.font_size = 32
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(0.70, 0.88, 1.0) if character_id == "moonveil_mage" else Color(1.0, 0.73, 0.84)
	title.position.y = 2.25
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
	# Soul-Knight-style in-world selection: characters remain visible; only a small
	# contextual confirmation strip appears after clicking or approaching one.
	selection_layer = CanvasLayer.new()
	selection_layer.layer = 20
	selection_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(selection_layer)
	var full := Control.new()
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full.mouse_filter = Control.MOUSE_FILTER_PASS
	selection_layer.add_child(full)

	character_selection_panel = PanelContainer.new()
	character_selection_panel.anchor_left = 0.5
	character_selection_panel.anchor_right = 0.5
	character_selection_panel.anchor_top = 1.0
	character_selection_panel.anchor_bottom = 1.0
	character_selection_panel.offset_left = -310.0
	character_selection_panel.offset_right = 310.0
	character_selection_panel.offset_top = -196.0
	character_selection_panel.offset_bottom = -22.0
	character_selection_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.045, 0.10, 0.96)
	panel_style.border_color = Color(0.45, 0.62, 0.93, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(15)
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	character_selection_panel.add_theme_stylebox_override("panel", panel_style)
	full.add_child(character_selection_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	character_selection_panel.add_child(column)
	selection_heading = Label.new()
	selection_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_heading.add_theme_font_size_override("font_size", 19)
	selection_heading.add_theme_color_override("font_color", Color(0.84, 0.90, 1.0))
	column.add_child(selection_heading)
	selection_details = Label.new()
	selection_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_details.add_theme_font_size_override("font_size", 12)
	selection_details.add_theme_color_override("font_color", Color(0.76, 0.82, 0.95))
	column.add_child(selection_details)
	selection_status = Label.new()
	selection_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_status.add_theme_font_size_override("font_size", 12)
	selection_status.add_theme_color_override("font_color", Color(0.96, 0.79, 0.88))
	column.add_child(selection_status)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	confirm_button = Button.new()
	confirm_button.text = "PLAY AS THIS HERO  ·  ENTER"
	confirm_button.custom_minimum_size = Vector2(265.0, 36.0)
	confirm_button.add_theme_font_size_override("font_size", 13)
	confirm_button.pressed.connect(_confirm_character_selection)
	actions.add_child(confirm_button)
	var cancel_button := Button.new()
	cancel_button.text = "CANCEL  [ESC]"
	cancel_button.custom_minimum_size = Vector2(150.0, 36.0)
	cancel_button.pressed.connect(_close_character_selection)
	actions.add_child(cancel_button)
	character_selection_panel.hide()

func _nearest_showcase_character(max_distance: float) -> String:
	if not is_instance_valid(player):
		return ""
	var nearest_id := ""
	var nearest_distance := max_distance
	for index in range(showcase_roots.size()):
		var candidate := showcase_roots[index]
		if not is_instance_valid(candidate):
			continue
		var distance := player.global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_id = "moonveil_mage" if index == 0 else "sword_duelist"
	return nearest_id

func _on_showcase_input_event(_camera_node: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, character_id: String) -> void:
	if get_tree().paused or _transitioning:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	get_viewport().set_input_as_handled()
	var now := Time.get_ticks_msec()
	if event.double_click or (_last_clicked_character == character_id and now - _last_click_msec <= 450):
		_select_character_in_world(character_id)
		_confirm_character_selection()
		_last_clicked_character = ""
		_last_click_msec = 0
	else:
		_last_clicked_character = character_id
		_last_click_msec = now
		_select_character_in_world(character_id)

func _select_character_in_world(character_id: String) -> void:
	if character_id not in ["moonveil_mage", "sword_duelist"] or _transitioning:
		return
	_selection_open = true
	selected_character_id = character_id
	if is_instance_valid(player):
		player.controls_locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_character_buttons()
	character_selection_panel.show()

func _refresh_character_buttons() -> void:
	if not is_instance_valid(selection_heading) or not is_instance_valid(selection_details):
		return
	if selected_character_id == "sword_duelist":
		selection_heading.text = "ASTRA VALE  ·  SWORD DUELIST"
		selection_heading.add_theme_color_override("font_color", Color(1.0, 0.69, 0.82))
		selection_details.text = "115 HP  ·  35 Stamina\nMouse 1: three-hit chain (16 / 20 / 28)  ·  Q: Crescent Lunge (30 damage, 4.5s cooldown)"
	else:
		selection_heading.text = "MOONVEIL MAGE"
		selection_heading.add_theme_color_override("font_color", Color(0.70, 0.86, 1.0))
		selection_details.text = "100 HP  ·  60 Mana\nQ: homing Moonbolt  ·  Ranged arcane combat"
	if is_instance_valid(selection_status) and is_instance_valid(player):
		selection_status.text = "You're already controlling this hero." if player.character_id == selected_character_id else "Selected wayfarer — confirm to switch control."

func _open_character_selection() -> void:
	# Kept as a compatibility wrapper: E only opens details for the nearest physical hero,
	# never a full roster menu.
	var character_id := _nearest_showcase_character(3.4)
	if not character_id.is_empty():
		_select_character_in_world(character_id)

func _close_character_selection() -> void:
	_selection_open = false
	if is_instance_valid(character_selection_panel):
		character_selection_panel.hide()
	if is_instance_valid(player):
		player.controls_locked = get_tree().paused
	_last_clicked_character = ""
	_last_click_msec = 0
	_refresh_prompt()

func _confirm_character_selection() -> void:
	if not _selection_open:
		return
	var unlocked: Array = MoonveilProfiles.account_data.get("unlocked_character_ids", [])
	if not unlocked.has(selected_character_id):
		selection_status.text = "This wayfarer is not unlocked on this account."
		return
	if is_instance_valid(player) and player.character_id == selected_character_id:
		_close_character_selection()
		_show_message("You're already controlling this wayfarer.")
		return
	if not MoonveilProfiles.set_active_character(selected_character_id):
		selection_status.text = "Could not save this selection. Your current wayfarer is unchanged."
		return
	if not MoonveilProfiles.save_active_character():
		selection_status.text = "Selected for this session, but saving the profile failed. Check storage space."
		return
	_replace_player(selected_character_id)
	_close_character_selection()
	var display_name := "Astra Vale, Sword Duelist" if selected_character_id == "sword_duelist" else "Moonveil Mage"
	_show_message("Now controlling %s. Visit the Moon Shrine when ready to depart." % display_name)
	_refresh_prompt()

func _refresh_prompt() -> void:
	if not is_instance_valid(prompt_label) or not is_instance_valid(player):
		return
	if _selection_open:
		prompt_label.text = "Choose a wayfarer by the fire"
	elif _transitioning:
		prompt_label.text = "The Veil opens…"
	elif not _nearest_showcase_character(3.4).is_empty():
		var nearby_id := _nearest_showcase_character(3.4)
		var nearby_name := "Moonveil Mage" if nearby_id == "moonveil_mage" else "Astra Vale · Sword Duelist"
		prompt_label.text = "Click %s or press E to interact" % nearby_name
	elif player.global_position.distance_to(SHRINE_POSITION) <= INTERACT_RANGE:
		prompt_label.text = "Press E at the Moon Shrine to enter Whispering Woods"
	else:
		prompt_label.text = "Approach a wayfarer and click them to switch heroes   ·   Moon Shrine: start a journey"
	if is_instance_valid(status_label):
		var active_name := "Astra Vale · Sword Duelist" if player.character_id == "sword_duelist" else "Moonveil Mage"
		status_label.text = "ACTIVE WAYFARER: %s   ·   PERMANENT CURRENCY: %d   ·   REGIONS: %d" % [active_name, MoonveilMeta.permanent_currency, MoonveilMeta.unlocked_regions.size()]

func _show_message(message: String) -> void:
	if not is_instance_valid(prompt_label):
		return
	prompt_label.text = message
