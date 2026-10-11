extends CharacterBody3D

signal died(xp_reward: int, world_position: Vector3, drops_shard: bool)
const GRAVITY := 22.0
const FALL_RESET_Y := -5.0
var player_ref: Node3D
var spawn_position: Vector3 = Vector3.ZERO
var max_hp := 42
var hp := 42
var move_speed := 2.25
var touch_damage := 8
var xp_reward := 20
var _attack_timer := 0.0
var _flash_timer := 0.0
var _dead := false
var _body_material: StandardMaterial3D
var _visual_root: Node3D
var _name_label: Label3D
var _time := 0.0

func _ready() -> void:
	spawn_position = global_position
	add_to_group("enemies")
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.55
	collision.shape = capsule
	collision.position.y = 0.77
	add_child(collision)

	_visual_root = Node3D.new()
	add_child(_visual_root)
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color(0.49, 0.20, 0.56)
	_body_material.roughness = 0.34

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.2
	body.mesh = body_mesh
	body.material_override = _body_material
	body.position.y = 0.73
	_visual_root.add_child(body)

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.30
	core_mesh.height = 0.60
	core.mesh = core_mesh
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.18, 0.11, 0.30)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.38, 0.12, 0.72)
	core_mat.emission_energy_multiplier = 0.65
	core.material_override = core_mat
	core.position.y = 1.28
	_visual_root.add_child(core)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.055
		eye_mesh.height = 0.11
		eye.mesh = eye_mesh
		var eye_mat := StandardMaterial3D.new()
		eye_mat.albedo_color = Color(1.0, 0.45, 0.74)
		eye_mat.emission_enabled = true
		eye_mat.emission = eye_mat.albedo_color
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.12, 1.32, 0.26)
		_visual_root.add_child(eye)

	var label := Label3D.new()
	label.text = "VOIDLING  ·  %d HP" % hp
	label.font_size = 28
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.78, 0.94)
	label.position.y = 2.0
	_visual_root.add_child(label)
	_name_label = label

func _physics_process(delta: float) -> void:
	if _dead: return
	if global_position.y < FALL_RESET_Y:
		global_position = spawn_position
		velocity = Vector3.ZERO
		return
	_time += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_flash_timer = maxf(0.0, _flash_timer - delta)
	if _flash_timer == 0.0 and _body_material.albedo_color != Color(0.49, 0.20, 0.56):
		_body_material.albedo_color = Color(0.49, 0.20, 0.56)
	_visual_root.position.y = sin(_time * 3.2) * 0.06
	if not is_instance_valid(player_ref):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty(): player_ref = players[0] as Node3D
	if not is_instance_valid(player_ref): return

	var to_player := player_ref.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	if distance > 1.35:
		var direction := to_player.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		_visual_root.rotation.y = atan2(direction.x, direction.z)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		if _attack_timer <= 0.0 and player_ref.has_method("take_damage"):
			_attack_timer = 1.25
			player_ref.call("take_damage", touch_damage)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.25
	move_and_slide()

func _spawn_damage_number(amount: int) -> void:
	var popup := Label3D.new()
	popup.process_mode = Node.PROCESS_MODE_PAUSABLE
	popup.text = str(amount)
	popup.font_size = 64
	popup.pixel_size = 0.007
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.modulate = Color(1.0, 0.94, 0.66)
	popup.outline_size = 7
	popup.outline_modulate = Color(0.10, 0.05, 0.17, 1.0)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root == null:
		return
	scene_root.add_child(popup)
	popup.global_position = global_position + Vector3(randf_range(-0.22, 0.22), 1.55, randf_range(-0.12, 0.12))
	var tween := popup.create_tween()
	tween.tween_property(popup, "global_position", popup.global_position + Vector3(0.0, 1.05, 0.0), 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.72)
	tween.tween_callback(popup.queue_free)

func take_damage(amount: int) -> void:
	if _dead: return
	hp = maxi(0, hp - amount)
	_spawn_damage_number(amount)
	if is_instance_valid(_name_label):
		_name_label.text = "VOIDLING  ·  %d HP" % hp
	_body_material.albedo_color = Color(1.0, 0.38, 0.67)
	_flash_timer = 0.14
	if hp <= 0:
		_dead = true
		died.emit(xp_reward, global_position, randf() < 0.32)
		queue_free()
