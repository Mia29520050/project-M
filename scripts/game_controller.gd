extends Node3D

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const DUELIST_SCENE = preload("res://scenes/sword_duelist.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const BOLT_SCENE = preload("res://scenes/magic_bolt.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/pause_menu.tscn")
const INVENTORY_PANEL_SCRIPT: Script = preload("res://scripts/inventory_panel.gd")

var player: Node3D
var camera: Camera3D
var hud_layer: CanvasLayer
var inventory_layer: CanvasLayer
var hp_bar: ProgressBar
var mana_bar: ProgressBar
var xp_bar: ProgressBar
var level_label: Label
var hp_label: Label
var mana_label: Label
var dodge_label: Label
var potion_label: Label
var _inventory_paused := false
var weapon_label: Label
var shard_label: Label
var quest_label: Label
var enemy_label: Label
var inventory_panel: Control
var controls_hint_panel: Control
var controls_hint_label: Label
var pause_menu: CanvasLayer
var death_panel: PanelContainer
var toast_panel: PanelContainer
var toast_label: Label
var toast_token := 0
var defeated_count := 0
var quest_completed := false
var _time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Player uses the default physics priority (0); run this controller after it.
	process_priority = 1
	randomize()
	_build_world()
	_create_player()
	_create_camera()
	_build_hud()
	_build_pause_menu()
	if not MoonveilSettings.settings_changed.is_connected(_on_settings_changed):
		MoonveilSettings.settings_changed.connect(_on_settings_changed)
	for spawn_point in [
		Vector3(-3.0, 0.0, 1.0),
		Vector3(4.0, 0.0, 0.0),
		Vector3(-5.0, 0.0, -5.0),
		Vector3(5.0, 0.0, -6.0),
		Vector3(0.0, 0.0, -10.0),
		Vector3(8.0, 0.0, 3.0)
	]:
		_spawn_enemy(spawn_point)
	_refresh_hud()
	_show_toast("Welcome to Moonveil — defeat 5 Voidlings!")

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_time += delta
	_refresh_dodge_hud()
	_refresh_potion_hud()
	if is_instance_valid(player) and player.character_id == "sword_duelist" and is_instance_valid(shard_label):
		shard_label.text = player.call("get_skill_status_text")


func _on_settings_changed() -> void:
	if is_instance_valid(controls_hint_panel):
		controls_hint_panel.visible = MoonveilSettings.show_control_hints
	if is_instance_valid(controls_hint_label):
		controls_hint_label.text = _build_controls_hint_text()

func _build_controls_hint_text() -> String:
	var movement := "%s/%s/%s/%s" % [
		MoonveilSettings.get_control_binding_label("move_up"),
		MoonveilSettings.get_control_binding_label("move_left"),
		MoonveilSettings.get_control_binding_label("move_down"),
		MoonveilSettings.get_control_binding_label("move_right")
	]
	return "MOVE %s · ATK %s · DODGE %s · POT %s/%s/%s · SKILL %s · BAG %s · INTERACT %s · PAUSE %s" % [
		movement,
		MoonveilSettings.get_control_binding_label("attack"),
		MoonveilSettings.get_control_binding_label("dodge"),
		MoonveilSettings.get_control_binding_label("potion_minor"),
		MoonveilSettings.get_control_binding_label("potion_standard"),
		MoonveilSettings.get_control_binding_label("potion_greater"),
		MoonveilSettings.get_control_binding_label("moonbolt"),
		MoonveilSettings.get_control_binding_label("inventory"),
		MoonveilSettings.get_control_binding_label("interact"),
		MoonveilSettings.get_control_binding_label("pause")
	]

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return
	if is_instance_valid(camera) and is_instance_valid(player):
		# Controller priority 1 runs after the Player's default priority 0 physics tick.
		camera.global_position = player.global_position + Vector3(0.0, 17.0, 13.0)
		camera.look_at(player.global_position + Vector3(0.0, 0.75, 0.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	# Ignore pause/inventory input once the run has ended and the death banner is active.
	if is_instance_valid(player) and player.has_method("is_defeated") and bool(player.call("is_defeated")):
		if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
			get_viewport().set_input_as_handled()
			return

	# ESC always exits the inventory first; otherwise it toggles the pause menu.
	if event.is_action_pressed("pause"):
		if _inventory_paused:
			_inventory_paused = false
			inventory_panel.hide()
			hud_layer.visible = true
			_set_paused(false)
		elif get_tree().paused:
			_set_paused(false)
		else:
			_set_paused(true)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("inventory"):
		if _inventory_paused:
			_inventory_paused = false
			inventory_panel.hide()
			hud_layer.visible = true
			_set_paused(false)
		elif not get_tree().paused:
			_inventory_paused = true
			inventory_panel.refresh(player)
			hud_layer.visible = false
			inventory_panel.show()
			_set_paused(true)
		_refresh_hud()
		get_viewport().set_input_as_handled()
		return

	if get_tree().paused:
		return
	if is_instance_valid(player) and event.is_action_pressed("potion_minor"):
		player.call("use_healing_potion", 0)
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(player) and event.is_action_pressed("potion_standard"):
		player.call("use_healing_potion", 1)
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(player) and event.is_action_pressed("potion_greater"):
		player.call("use_healing_potion", 2)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		if not is_instance_valid(player):
			return
		if player.character_id == "sword_duelist":
			player.call("equip_moonfire_staff")
		elif player.has_moonfire_staff:
			player.equip_moonfire_staff()
		elif player.moon_shards < 3:
			_show_toast("Collect 3 Moonshards before awakening your staff.")
		elif player.global_position.distance_to(Vector3(0.0, 0.0, 11.0)) > 3.5:
			_show_toast("Return to the glowing Moon Shrine to enhance your staff.")
		else:
			player.equip_moonfire_staff()
		_refresh_hud()
		get_viewport().set_input_as_handled()

func _set_paused(should_pause: bool) -> void:
	get_tree().paused = should_pause
	if is_instance_valid(pause_menu):
		if should_pause and not _inventory_paused:
			pause_menu.open_menu()
		else:
			pause_menu.hide()
	if is_instance_valid(player):
		player.controls_locked = should_pause or (is_instance_valid(inventory_panel) and inventory_panel.visible)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume_game() -> void:
	_set_paused(false)

func _build_pause_menu() -> void:
	pause_menu = PAUSE_MENU_SCENE.instantiate() as CanvasLayer
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.return_to_title_requested.connect(_return_to_title)
	add_child(pause_menu)
	pause_menu.hide()

func _return_to_title() -> void:
	_inventory_paused = false
	get_tree().paused = false
	var error := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if error != OK:
		push_error("Moonveil could not return to the main menu (error %d)." % error)

func _build_world() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.085, 0.095, 0.20)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.66, 0.70, 0.92)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-53.0, -32.0, 0.0)
	sunlight.light_color = Color(1.0, 0.83, 0.77)
	sunlight.light_energy = 1.1
	sunlight.shadow_enabled = true
	add_child(sunlight)

	var ground_body := StaticBody3D.new()
	ground_body.name = "WalkableGround"
	ground_body.position.y = -0.2
	add_child(ground_body)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(48.0, 0.4, 48.0)
	ground_collision.shape = ground_shape
	ground_body.add_child(ground_collision)

	var ground_mesh := MeshInstance3D.new()
	var ground_box := BoxMesh.new()
	ground_box.size = Vector3(48.0, 0.4, 48.0)
	ground_mesh.mesh = ground_box
	ground_mesh.material_override = _mat(Color(0.13, 0.26, 0.28), 0.0)
	ground_body.add_child(ground_mesh)

	# A pale stone trail guides the player from the shrine into the clearing.
	for i in range(13):
		var stone := MeshInstance3D.new()
		var stone_mesh := BoxMesh.new()
		stone_mesh.size = Vector3(2.35, 0.045, 1.18)
		stone.mesh = stone_mesh
		stone.material_override = _mat(Color(0.34, 0.39, 0.52) if i % 2 == 0 else Color(0.27, 0.33, 0.46), 0.08)
		stone.position = Vector3(0.0, 0.035, 8.4 - float(i) * 1.55)
		stone.rotation.y = sin(float(i) * 0.7) * 0.08
		add_child(stone)

	# The shrine behind the starting point.
	_add_crystal(Vector3(0.0, 0.0, 11.0), Color(0.48, 0.78, 1.0), 1.45)
	_add_crystal(Vector3(-1.1, 0.0, 11.35), Color(0.82, 0.56, 1.0), 0.95)
	_add_crystal(Vector3(1.1, 0.0, 11.35), Color(0.82, 0.56, 1.0), 0.95)
	var shrine_label := Label3D.new()
	shrine_label.text = "MOON SHRINE\nE  ·  ENHANCE STAFF"
	shrine_label.font_size = 32
	shrine_label.pixel_size = 0.006
	shrine_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shrine_label.modulate = Color(0.72, 0.88, 1.0)
	shrine_label.position = Vector3(0.0, 2.5, 11.0)
	add_child(shrine_label)

	var tree_spots: Array[Vector3] = [
		Vector3(-9, 0, -8), Vector3(-11, 0, -1), Vector3(-10, 0, 6),
		Vector3(-7, 0, 12), Vector3(8, 0, -11), Vector3(11, 0, -5),
		Vector3(12, 0, 2), Vector3(10, 0, 10), Vector3(-14, 0, 10),
		Vector3(15, 0, -10), Vector3(-15, 0, -10), Vector3(15, 0, 12)
	]
	for index in range(tree_spots.size()):
		_add_tree(tree_spots[index], index)

	for crystal_index in range(7):
		var x: float = [-7.0, 7.0, -12.0, 12.0, -4.0, 13.0, 3.0][crystal_index]
		var z: float = [1.0, -3.0, -8.0, 7.0, -12.0, 0.0, 13.0][crystal_index]
		if absf(x) > 5.0 or z < -8.0:
			_add_crystal(Vector3(x, 0.0, z), Color(0.40, 0.82, 0.94) if crystal_index % 2 == 0 else Color(0.72, 0.43, 0.98), 0.55 + float(crystal_index % 3) * 0.18)

func _mat(color: Color, metallic: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.48
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.6
	return material

func _add_tree(pos: Vector3, variant: int) -> void:
	var tree := Node3D.new()
	tree.position = pos
	add_child(tree)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.23
	trunk_mesh.height = 1.5
	trunk.mesh = trunk_mesh
	trunk.material_override = _mat(Color(0.25, 0.16, 0.23))
	trunk.position.y = 0.72
	tree.add_child(trunk)

	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0 if variant % 3 == 0 else 0.82
	crown_mesh.height = 1.8
	crown.mesh = crown_mesh
	var foliage: Color = [Color(0.16, 0.39, 0.38), Color(0.23, 0.31, 0.49), Color(0.35, 0.25, 0.48)][variant % 3]
	crown.material_override = _mat(foliage, 0.03)
	crown.position.y = 1.85
	crown.scale = Vector3(1.0, 1.15, 0.92)
	tree.add_child(crown)

	var glow_orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.09
	orb_mesh.height = 0.18
	glow_orb.mesh = orb_mesh
	glow_orb.material_override = _mat(Color(0.55, 0.88, 1.0), 0.0, true)
	glow_orb.position = Vector3(0.45, 1.5, 0.1)
	tree.add_child(glow_orb)

func _add_crystal(pos: Vector3, color: Color, height: float) -> void:
	var crystal := MeshInstance3D.new()
	var crystal_mesh := CylinderMesh.new()
	crystal_mesh.top_radius = 0.025
	crystal_mesh.bottom_radius = 0.28 * height
	crystal_mesh.height = height
	crystal_mesh.radial_segments = 5
	crystal.mesh = crystal_mesh
	crystal.material_override = _mat(color, 0.24, true)
	crystal.position = pos + Vector3(0.0, height * 0.5, 0.0)
	crystal.rotation_degrees.z = 7.0
	add_child(crystal)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.42
	base_mesh.bottom_radius = 0.48
	base_mesh.height = 0.16
	base.mesh = base_mesh
	base.material_override = _mat(Color(0.17, 0.19, 0.34), 0.22)
	base.position = pos + Vector3(0.0, 0.08, 0.0)
	add_child(base)

func _create_player() -> void:
	var active_character_id := String(MoonveilProfiles.account_data.get("active_character_id", "moonveil_mage"))
	var selected_scene: PackedScene = DUELIST_SCENE if active_character_id == "sword_duelist" else PLAYER_SCENE
	player = selected_scene.instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.global_position = Vector3(0.0, 0.0, 6.0)
	player.stats_changed.connect(_refresh_hud)
	player.notification_requested.connect(_show_toast)
	player.magic_requested.connect(_on_magic_requested)
	player.defeated.connect(_refresh_hud)
	player.defeated.connect(_show_death_panel)

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.near = 0.1
	camera.far = 120.0
	add_child(camera)
	camera.global_position = player.global_position + Vector3(0.0, 17.0, 13.0)
	camera.look_at(player.global_position + Vector3(0.0, 0.65, 0.0), Vector3.UP)
	camera.current = true

func _spawn_enemy(position_in_world: Vector3) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.player_ref = player
	enemy.died.connect(_on_enemy_died)
	# Set local position before _ready() so the enemy records the correct respawn point.
	enemy.position = position_in_world
	add_child(enemy)

func _on_enemy_died(xp_reward: int, world_position: Vector3, drops_shard: bool) -> void:
	if is_instance_valid(player):
		player.gain_xp(xp_reward)
		if drops_shard:
			player.add_shard()
	defeated_count += 1
	_refresh_hud()
	if defeated_count >= 5 and not quest_completed:
		quest_completed = true
		_show_toast("QUEST COMPLETE! Moonveil's first clearing is safe.")
		if is_instance_valid(player):
			player.gain_xp(35)
			if player.character_id != "sword_duelist" and not player.has_moonfire_staff and player.moon_shards < 3:
				var bonus_shards: int = 3 - player.moon_shards
				player.add_shard(bonus_shards)
				_show_toast("Quest reward: %d Moonshards! Return to the Moon Shrine to awaken your staff." % bonus_shards)
	var spawn_points: Array[Vector3] = [
		Vector3(-6, 0, -3), Vector3(6, 0, -2), Vector3(-4, 0, -10),
		Vector3(4, 0, -11), Vector3(9, 0, 4), Vector3(-8, 0, 4)
	]
	var respawn_point: Vector3 = spawn_points[randi_range(0, spawn_points.size() - 1)]
	get_tree().create_timer(2.5, false).timeout.connect(func() -> void:
		if is_instance_valid(player):
			_spawn_enemy(respawn_point)
	)

func _on_magic_requested(origin: Vector3, target: Node3D, damage: int) -> void:
	if not is_instance_valid(target):
		return
	var bolt := BOLT_SCENE.instantiate()
	bolt.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bolt)
	bolt.global_position = origin
	bolt.configure(target, damage)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.105, 0.91)
	style.border_color = Color(0.38, 0.48, 0.75, 0.84)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style

func _make_panel(parent: Control, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = size
	panel.size = size
	parent.add_child(panel)
	return panel

func _make_label(parent: Node, value: String, font_size: int = 15, color: Color = Color(0.89, 0.92, 1.0)) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _make_bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(280, 14)
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.11, 0.13, 0.22, 1.0)
	background.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.layer = 8
	add_child(hud_layer)
	var full := Control.new()
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(full)

	# Keep inventory on a dedicated layer above the HUD so its backdrop can blur
	# both the world and HUD without changing gameplay or the HUD itself.
	inventory_layer = CanvasLayer.new()
	inventory_layer.name = "InventoryCanvasLayer"
	inventory_layer.layer = 9
	inventory_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(inventory_layer)

	var stats_panel := _make_panel(full, Vector2(326, 240))
	stats_panel.position = Vector2(22, 22)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 5)
	stats_panel.add_child(stats_box)
	_make_label(stats_box, "MOONVEIL  /  WAYFARER", 17, Color(0.70, 0.90, 1.0))
	level_label = _make_label(stats_box, "LEVEL 1  ·  Apprentice", 14, Color(0.98, 0.82, 0.94))
	hp_label = _make_label(stats_box, "HP 100 / 100", 12, Color(1.0, 0.71, 0.76))
	hp_bar = _make_bar(stats_box, Color(0.91, 0.31, 0.48))
	mana_label = _make_label(stats_box, "MANA 60 / 60", 12, Color(0.65, 0.86, 1.0))
	mana_bar = _make_bar(stats_box, Color(0.29, 0.72, 0.98))
	_make_label(stats_box, "EXPERIENCE", 11, Color(0.81, 0.81, 0.94))
	xp_bar = _make_bar(stats_box, Color(0.69, 0.48, 1.0))
	dodge_label = _make_label(stats_box, "DODGE  2 / 2  ·  READY", 12, Color(0.78, 0.88, 1.0))
	potion_label = _make_label(stats_box, "POTIONS  1:2  2:1  3:0", 12, Color(0.86, 0.91, 0.74))

	var quest_panel := _make_panel(full, Vector2(340, 128))
	quest_panel.anchor_left = 1.0
	quest_panel.anchor_right = 1.0
	quest_panel.anchor_top = 0.0
	quest_panel.anchor_bottom = 0.0
	quest_panel.offset_left = -362.0
	quest_panel.offset_right = -22.0
	quest_panel.offset_top = 22.0
	quest_panel.offset_bottom = 154.0
	var quest_box := VBoxContainer.new()
	quest_box.add_theme_constant_override("separation", 6)
	quest_panel.add_child(quest_box)
	_make_label(quest_box, "✦ FIRST LIGHT", 16, Color(0.89, 0.79, 1.0))
	quest_label = _make_label(quest_box, "Defeat 5 Voidlings", 13)
	enemy_label = _make_label(quest_box, "Voidlings gather in the clearing.", 11, Color(0.67, 0.75, 0.89))
	weapon_label = _make_label(quest_box, "Weapon: Apprentice Wand", 12, Color(0.69, 0.92, 0.96))
	shard_label = _make_label(quest_box, "Moonshards: 0 / 3", 12, Color(0.79, 0.69, 1.0))

	controls_hint_panel = _make_panel(full, Vector2(940, 72))
	controls_hint_panel.anchor_left = 0.5
	controls_hint_panel.anchor_right = 0.5
	controls_hint_panel.anchor_top = 1.0
	controls_hint_panel.anchor_bottom = 1.0
	controls_hint_panel.offset_left = -470.0
	controls_hint_panel.offset_right = 470.0
	controls_hint_panel.offset_top = -90.0
	controls_hint_panel.offset_bottom = -14.0
	controls_hint_panel.visible = MoonveilSettings.show_control_hints
	controls_hint_label = _make_label(controls_hint_panel, _build_controls_hint_text(), 11, Color(0.79, 0.86, 1.0))
	controls_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	toast_panel = _make_panel(full, Vector2(500, 52))
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_right = 0.5
	toast_panel.anchor_top = 0.0
	toast_panel.anchor_bottom = 0.0
	toast_panel.offset_left = -260.0
	toast_panel.offset_right = 260.0
	toast_panel.offset_top = 25.0
	toast_panel.offset_bottom = 84.0
	toast_label = _make_label(toast_panel, "", 15, Color(0.84, 0.93, 1.0))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_panel.hide()

	inventory_panel = Control.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.set_script(INVENTORY_PANEL_SCRIPT)
	inventory_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_layer.add_child(inventory_panel)
	inventory_panel.hide()

	# A dedicated death banner stays visible for the full shrine-return delay,
	# instead of relying only on the short-lived toast notification.
	death_panel = _make_panel(full, Vector2(470, 136))
	death_panel.anchor_left = 0.5
	death_panel.anchor_right = 0.5
	death_panel.anchor_top = 0.5
	death_panel.anchor_bottom = 0.5
	death_panel.offset_left = -235.0
	death_panel.offset_right = 235.0
	death_panel.offset_top = -68.0
	death_panel.offset_bottom = 68.0
	var death_style := _panel_style()
	death_style.bg_color = Color(0.12, 0.025, 0.07, 0.97)
	death_style.border_color = Color(0.95, 0.28, 0.48, 0.96)
	death_panel.add_theme_stylebox_override("panel", death_style)
	var death_box := VBoxContainer.new()
	death_box.alignment = BoxContainer.ALIGNMENT_CENTER
	death_box.add_theme_constant_override("separation", 9)
	death_panel.add_child(death_box)
	var death_title := _make_label(death_box, "YOU HAVE FALLEN", 25, Color(1.0, 0.47, 0.61))
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var death_subtitle := _make_label(death_box, "Returning to the Refuge…", 14, Color(0.94, 0.86, 0.91))
	death_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_panel.hide()

func _show_death_panel() -> void:
	if is_instance_valid(death_panel):
		death_panel.show()

func _hide_death_panel() -> void:
	if is_instance_valid(death_panel):
		death_panel.hide()

func _refresh_potion_hud() -> void:
	if not is_instance_valid(player) or not is_instance_valid(potion_label):
		return
	potion_label.text = player.call("get_potion_status_text")

func _refresh_dodge_hud() -> void:
	if not is_instance_valid(player) or not is_instance_valid(dodge_label):
		return
	if player.dodge_charges >= player.max_dodge_charges:
		dodge_label.text = "DODGE  %d / %d  ·  READY" % [player.dodge_charges, player.max_dodge_charges]
	else:
		dodge_label.text = "DODGE  %d / %d  ·  NEXT IN %.1fs" % [player.dodge_charges, player.max_dodge_charges, player._dodge_recharge_timer]

func _refresh_hud() -> void:
	if not is_instance_valid(player) or not is_instance_valid(hp_bar):
		return
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	mana_bar.max_value = player.max_mana
	mana_bar.value = player.mana
	xp_bar.max_value = player.xp_to_next
	xp_bar.value = player.xp
	hp_label.text = "HP  %d / %d" % [player.hp, player.max_hp]
	mana_label.text = "MANA  %d / %d" % [player.mana, player.max_mana]
	if player.character_id == "sword_duelist":
		level_label.text = "LEVEL %d  ·  Sword Duelist" % player.level
		hp_label.text = "HP  %d / %d" % [player.hp, player.max_hp]
		mana_label.text = "STAMINA  %d / %d" % [player.mana, player.max_mana]
		weapon_label.text = "Weapon: Training Sword  ·  Combo 16 / 20 / 28"
		shard_label.text = player.call("get_skill_status_text")
	else:
		level_label.text = "LEVEL %d  ·  %s" % [player.level, "Moonfire Adept" if player.has_moonfire_staff else "Apprentice"]
		mana_label.text = "MANA  %d / %d" % [player.mana, player.max_mana]
		weapon_label.text = "Weapon: %s  ·  Strike %d / Moonbolt %d" % [player.weapon_name, player.base_damage + player.weapon_bonus, player.magic_damage + player.weapon_bonus * 2]
		shard_label.text = "Moonshards: %d / 3" % player.moon_shards
	quest_label.text = "Quest complete!" if quest_completed else "Defeat 5 Voidlings  (%d/5)" % mini(defeated_count, 5)
	enemy_label.text = "%d Voidlings in the clearing" % get_tree().get_nodes_in_group("enemies").size()
	_refresh_dodge_hud()
	if is_instance_valid(inventory_panel) and inventory_panel.visible:
		inventory_panel.refresh(player)

func _show_toast(message: String) -> void:
	if not is_instance_valid(toast_panel):
		return
	toast_token += 1
	var current_token := toast_token
	toast_label.text = message
	toast_panel.show()
	await get_tree().create_timer(2.7, false).timeout
	if is_instance_valid(toast_panel) and current_token == toast_token:
		toast_panel.hide()
