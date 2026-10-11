extends CharacterBody3D

signal died(xp_reward: int, world_position: Vector3, drops_shard: bool)
const GRAVITY := 22.0
const FALL_RESET_Y := -5.0
const ATTACK_RANGE := 1.35
const ATTACK_WINDUP_DURATION := 0.45
const ATTACK_COOLDOWN := 1.25
const BASE_BODY_COLOR := Color(0.49, 0.20, 0.56)
const WINDUP_BODY_COLOR := Color(1.0, 0.32, 0.09)
const HIT_FLASH_COLOR := Color(1.0, 1.0, 1.0)
const HIT_FLASH_DURATION := 0.14
const COUNTDOWN_RING_INNER_RADIUS := 0.72
const COUNTDOWN_RING_OUTER_RADIUS := 0.88
const COUNTDOWN_RING_START_SCALE := 0.12
var player_ref: Node3D
var spawn_position: Vector3 = Vector3.ZERO
var max_hp := 42
var hp := 42
var move_speed := 2.25
var touch_damage := 8
var xp_reward := 20
var _attack_timer := 0.0
var _flash_timer := 0.0
var _windup_timer := 0.0
var _is_winding_up := false
var _dead := false
var _body_material: StandardMaterial3D
var _visual_root: Node3D
var _name_label: Label3D
var _warning_label: Label3D
var _warning_ring: MeshInstance3D
var _countdown_ring: MeshInstance3D
var _countdown_material: StandardMaterial3D
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
	_body_material.albedo_color = BASE_BODY_COLOR
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

	# Clear wind-up cues: an orange warning symbol above the Voidling and a ring on the ground.
	_warning_label = Label3D.new()
	_warning_label.name = "AttackWarningLabel"
	_warning_label.text = "!"
	_warning_label.font_size = 72
	_warning_label.pixel_size = 0.009
	_warning_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_warning_label.modulate = Color(1.0, 0.30, 0.10)
	_warning_label.position = Vector3(0.0, 2.65, 0.0)
	_warning_label.visible = false
	_visual_root.add_child(_warning_label)

	_warning_ring = MeshInstance3D.new()
	_warning_ring.name = "AttackTelegraphRing"
	var ring_mesh := TorusMesh.new()
	# Outline the actual melee attack radius so players can read the threatened area.
	ring_mesh.inner_radius = ATTACK_RANGE - 0.12
	ring_mesh.outer_radius = ATTACK_RANGE
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 32
	_warning_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.18, 0.06, 0.9)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.12, 0.025)
	ring_material.emission_energy_multiplier = 1.5
	_warning_ring.material_override = ring_material
	_warning_ring.position.y = 0.075
	_warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warning_ring.visible = false
	add_child(_warning_ring)

	# A separate inner ring shrinks toward the center as the attack approaches.
	_countdown_ring = MeshInstance3D.new()
	_countdown_ring.name = "AttackCountdownRing"
	var countdown_mesh := TorusMesh.new()
	countdown_mesh.inner_radius = COUNTDOWN_RING_INNER_RADIUS
	countdown_mesh.outer_radius = COUNTDOWN_RING_OUTER_RADIUS
	countdown_mesh.rings = 8
	countdown_mesh.ring_segments = 32
	_countdown_ring.mesh = countdown_mesh
	_countdown_material = StandardMaterial3D.new()
	_countdown_material.albedo_color = Color(1.0, 0.72, 0.08, 0.95)
	_countdown_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_countdown_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_countdown_material.emission_enabled = true
	_countdown_material.emission = Color(1.0, 0.55, 0.03)
	_countdown_material.emission_energy_multiplier = 1.6
	_countdown_ring.material_override = _countdown_material
	_countdown_ring.position.y = 0.09
	_countdown_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_countdown_ring.visible = false
	add_child(_countdown_ring)

func _physics_process(delta: float) -> void:
	if _dead: return
	if global_position.y < FALL_RESET_Y:
		global_position = spawn_position
		velocity = Vector3.ZERO
		return
	_time += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_flash_timer = maxf(0.0, _flash_timer - delta)
	# Hit flash has priority over the orange wind-up tint. Restore the correct state color afterward.
	if _flash_timer > 0.0:
		_body_material.albedo_color = HIT_FLASH_COLOR
	elif _is_winding_up:
		_body_material.albedo_color = WINDUP_BODY_COLOR
	else:
		_body_material.albedo_color = BASE_BODY_COLOR
	_visual_root.position.y = sin(_time * 3.2) * 0.06
	if not is_instance_valid(player_ref):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty(): player_ref = players[0] as Node3D
	if not is_instance_valid(player_ref): return

	var to_player := player_ref.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	if _is_winding_up:
		# Commit to a short, readable wind-up before the hit can happen.
		# Tint the body as well so the cue remains legible if the ring is partly occluded.
		_windup_timer = maxf(0.0, _windup_timer - delta)
		var progress := 1.0 - (_windup_timer / ATTACK_WINDUP_DURATION)
		# Keep the ring at the true attack radius throughout the warning window.
		if is_instance_valid(_warning_ring):
			_warning_ring.scale = Vector3.ONE
		if is_instance_valid(_warning_label):
			# The exclamation mark warms to red and pulses during the final part of the wind-up.
			var urgency := Color(1.0, 0.72, 0.08).lerp(Color(1.0, 0.035, 0.02), progress)
			var final_pulse := sin(_time * 30.0) * 0.10 if progress >= 0.70 else 0.0
			_warning_label.modulate = urgency
			_warning_label.scale = Vector3.ONE * (0.85 + 0.45 * progress + final_pulse)
		if is_instance_valid(_countdown_ring):
			# Outer ring shows reach; this inner ring expands toward its edge to show time remaining.
			# Expand outward from the center to the edge of the fixed danger radius as impact approaches.
			var countdown_scale := lerpf(COUNTDOWN_RING_START_SCALE, ATTACK_RANGE / COUNTDOWN_RING_OUTER_RADIUS, progress)
			_countdown_ring.scale = Vector3(countdown_scale, 1.0, countdown_scale)
			var countdown_color := Color(1.0, 0.72, 0.08).lerp(Color(1.0, 0.035, 0.02), progress)
			countdown_color.a = 0.95
			_countdown_material.albedo_color = countdown_color
			_countdown_material.emission = countdown_color
			_countdown_material.emission_energy_multiplier = 1.6 + progress * 1.4
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		if _windup_timer <= 0.0:
			_is_winding_up = false
			_attack_timer = ATTACK_COOLDOWN
			if is_instance_valid(_warning_ring):
				_warning_ring.hide()
				_warning_ring.scale = Vector3.ONE
			if is_instance_valid(_countdown_ring):
				_countdown_ring.hide()
				_countdown_ring.scale = Vector3.ONE
			if is_instance_valid(_warning_label):
				_warning_label.hide()
				_warning_label.scale = Vector3.ONE
				_warning_label.modulate = Color(1.0, 0.30, 0.10)
			# The attack misses if the player leaves melee range during the warning.
			if distance <= ATTACK_RANGE and player_ref.has_method("take_damage"):
				player_ref.call("take_damage", touch_damage)
	elif distance > ATTACK_RANGE:
		var direction := to_player.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		_visual_root.rotation.y = atan2(direction.x, direction.z)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		if _attack_timer <= 0.0 and player_ref.has_method("take_damage"):
			_is_winding_up = true
			_windup_timer = ATTACK_WINDUP_DURATION
			if is_instance_valid(_warning_ring):
				_warning_ring.show()
				_warning_ring.scale = Vector3.ONE
			if is_instance_valid(_countdown_ring):
				_countdown_ring.show()
				_countdown_ring.scale = Vector3(COUNTDOWN_RING_START_SCALE, 1.0, COUNTDOWN_RING_START_SCALE)
				_countdown_material.albedo_color = Color(1.0, 0.72, 0.08, 0.95)
				_countdown_material.emission = Color(1.0, 0.55, 0.03)
				_countdown_material.emission_energy_multiplier = 1.6
			if is_instance_valid(_warning_label):
				_warning_label.show()
				_warning_label.modulate = Color(1.0, 0.72, 0.08)
				_warning_label.scale = Vector3.ONE * 0.85
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
	var active_popups := scene_root.get_tree().get_nodes_in_group("damage_popups")
	if active_popups.size() >= 24:
		# Popups are added as scene-root children in creation order; remove the oldest first.
		var oldest_popup: Node = active_popups[0]
		oldest_popup.free()
	scene_root.add_child(popup)
	popup.add_to_group("damage_popups")
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
	_body_material.albedo_color = HIT_FLASH_COLOR
	_flash_timer = HIT_FLASH_DURATION
	if hp <= 0:
		_dead = true
		died.emit(xp_reward, global_position, randf() < 0.32)
		queue_free()
