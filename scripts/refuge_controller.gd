extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const RUN_SCENE_PATH := "res://scenes/main.tscn"
const SHRINE_POSITION := Vector3(0.0, 0.0, -1.0)
const INTERACT_RANGE := 4.8

var player: Node3D
var camera: Camera3D
var prompt_label: Label
var status_label: Label
var _transitioning := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_environment()
	_build_world()
	_build_hud()
	_create_player()
	_create_camera()
	_refresh_prompt()

func _process(_delta: float) -> void:
	if is_instance_valid(camera) and is_instance_valid(player):
		camera.global_position = player.global_position + Vector3(0.0, 17.0, 13.0)
		camera.look_at(player.global_position + Vector3(0.0, 0.75, 0.0), Vector3.UP)
	_refresh_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		if is_instance_valid(player):
			player.controls_locked = get_tree().paused
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused or _transitioning:
		return
	if event.is_action_pressed("interact"):
		# Mark the event handled before requesting a scene change; the Refuge may leave the tree.
		var viewport := get_viewport()
		if is_instance_valid(viewport):
			viewport.set_input_as_handled()
		if not is_instance_valid(player):
			return
		if player.global_position.distance_to(SHRINE_POSITION) <= INTERACT_RANGE:
			_start_run()
		else:
			_show_message("Come closer to the Moon Shrine to begin a journey.")

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
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector3(0.0, 0.0, 3.4)
	player.notification_requested.connect(_show_message)
	add_child(player)

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

func _refresh_prompt() -> void:
	if not is_instance_valid(prompt_label) or not is_instance_valid(player):
		return
	var distance := player.global_position.distance_to(SHRINE_POSITION)
	if _transitioning:
		prompt_label.text = "The Veil opens…"
	elif distance <= INTERACT_RANGE:
		prompt_label.text = "Press E to begin a run in Whispering Woods"
	else:
		prompt_label.text = "Approach the Moon Shrine to begin a run"
	if is_instance_valid(status_label):
		status_label.text = "PERMANENT CURRENCY: %d   ·   UPGRADES: %d   ·   UNLOCKED REGIONS: %d" % [MoonveilMeta.permanent_currency, MoonveilMeta.permanent_upgrades.size(), MoonveilMeta.unlocked_regions.size()]

func _show_message(message: String) -> void:
	if not is_instance_valid(prompt_label):
		return
	prompt_label.text = message
