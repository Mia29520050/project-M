extends CharacterBody3D

signal stats_changed
signal notification_requested(message: String)
signal magic_requested(origin: Vector3, target: Node3D, damage: int)
signal defeated

const WALK_SPEED := 5.8
const DODGE_SPEED := 13.0
const DODGE_DURATION := 0.22
const DODGE_RECHARGE_PER_CHARGE := 1.25
const GRAVITY := 22.0
const MANA_REGEN_PER_SEC := 4.0
const MANA_REGEN_DELAY_AFTER_CAST := 1.5
const FALL_RESET_Y := -5.0
var level := 1
var xp := 0
var xp_to_next := 50
var max_hp := 100
var hp := 100
var max_mana := 60
var mana := 60
var base_damage := 12
var magic_damage := 24
var mana_cost := 15
var weapon_name := "Apprentice Wand"
var weapon_bonus := 0
var moon_shards := 0
var has_moonfire_staff := false
var _attack_timer := 0.0
var _magic_timer := 0.0
var _dodge_timer := 0.0
var max_dodge_charges := 2
var dodge_charges := 2
var _dodge_recharge_timer := 0.0
var _invulnerability_timer := 0.0
var _dodge_direction := Vector3.ZERO
var _dodge_collision_exceptions: Array[PhysicsBody3D] = []
var _facing_yaw := 0.0
var controls_locked := false
var _staff_instance: MeshInstance3D
var _gem_instance: MeshInstance3D
var _mana_regen_delay := 0.0
var _mana_regen_accumulator := 0.0
var _defeated := false
var _time := 0.0
var _attack_anim := 0.0
var _visual_root: Node3D
var _body_material: StandardMaterial3D

func _ready() -> void:
	name = "Player"
	add_to_group("player")
	_build_collision()
	_build_visuals()
	notification_requested.emit("Welcome to Moonveil, Wayfarer.")
	stats_changed.emit()

func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

func _material(color: Color, metallic: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.38
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
	return material

func _build_visuals() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "AnimeStylizedVisuals"
	add_child(_visual_root)

	var cloak := MeshInstance3D.new()
	var cloak_mesh := CapsuleMesh.new()
	cloak_mesh.radius = 0.37
	cloak_mesh.height = 1.32
	cloak.mesh = cloak_mesh
	cloak.material_override = _material(Color(0.21, 0.27, 0.57), 0.15)
	cloak.position.y = 0.91
	_visual_root.add_child(cloak)

	var tunic := MeshInstance3D.new()
	var tunic_mesh := CapsuleMesh.new()
	tunic_mesh.radius = 0.29
	tunic_mesh.height = 0.90
	tunic.mesh = tunic_mesh
	tunic.material_override = _material(Color(0.28, 0.77, 0.91), 0.12)
	tunic.position.y = 0.94
	_visual_root.add_child(tunic)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.29
	head_mesh.height = 0.58
	head.mesh = head_mesh
	head.material_override = _material(Color(1.0, 0.79, 0.72), 0.05)
	head.position.y = 1.72
	_visual_root.add_child(head)

	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.31
	hair_mesh.height = 0.37
	hair.mesh = hair_mesh
	hair.material_override = _material(Color(0.20, 0.12, 0.34), 0.1)
	hair.position = Vector3(0.0, 1.91, -0.055)
	_visual_root.add_child(hair)

	var staff := MeshInstance3D.new()
	var staff_mesh := CylinderMesh.new()
	staff_mesh.top_radius = 0.045
	staff_mesh.bottom_radius = 0.055
	staff_mesh.height = 1.3
	staff.mesh = staff_mesh
	staff.material_override = _material(Color(0.59, 0.39, 0.86), 0.25)
	_staff_instance = staff
	staff.position = Vector3(0.55, 0.77, 0.05)
	staff.rotation_degrees.z = -9.0
	_visual_root.add_child(staff)

	var gem := MeshInstance3D.new()
	var gem_mesh := SphereMesh.new()
	gem_mesh.radius = 0.15
	gem_mesh.height = 0.30
	gem.mesh = gem_mesh
	gem.material_override = _material(Color(0.63, 0.92, 1.0), 0.1, true)
	_gem_instance = gem
	gem.position = Vector3(0.55, 1.43, 0.05)
	_visual_root.add_child(gem)

func _physics_process(delta: float) -> void:
	if global_position.y < FALL_RESET_Y:
		global_position = Vector3(0.0, 0.0, 6.0)
		velocity = Vector3.ZERO
		_dodge_timer = 0.0
		_end_dodge_collision_phase()
		return
	_time += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_magic_timer = maxf(0.0, _magic_timer - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_invulnerability_timer = maxf(0.0, _invulnerability_timer - delta)
	if dodge_charges < max_dodge_charges:
		_dodge_recharge_timer = maxf(0.0, _dodge_recharge_timer - delta)
		if _dodge_recharge_timer <= 0.0:
			dodge_charges += 1
			_dodge_recharge_timer = DODGE_RECHARGE_PER_CHARGE if dodge_charges < max_dodge_charges else 0.0
			stats_changed.emit()
	else:
		_dodge_recharge_timer = 0.0
	if _defeated:
		_dodge_timer = 0.0
		_end_dodge_collision_phase()
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * delta * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * delta * 3.0)
		return

	if _mana_regen_delay > 0.0:
		_mana_regen_delay = maxf(0.0, _mana_regen_delay - delta)
	elif mana < max_mana:
		_mana_regen_accumulator += delta * MANA_REGEN_PER_SEC
		var whole_mana: int = int(_mana_regen_accumulator)
		if whole_mana > 0:
			var restored: int = mini(whole_mana, max_mana - mana)
			mana += restored
			_mana_regen_accumulator -= float(whole_mana)
			stats_changed.emit()
	else:
		_mana_regen_accumulator = 0.0

	var direction := Vector3.ZERO
	if not controls_locked:
		if Input.is_action_pressed("move_up"): direction.z -= 1.0
		if Input.is_action_pressed("move_down"): direction.z += 1.0
		if Input.is_action_pressed("move_left"): direction.x -= 1.0
		if Input.is_action_pressed("move_right"): direction.x += 1.0
	direction = direction.normalized()
	if direction.length_squared() > 0.01:
		_facing_yaw = atan2(direction.x, direction.z)

	if _dodge_timer > 0.0 and not controls_locked:
		velocity.x = _dodge_direction.x * DODGE_SPEED
		velocity.z = _dodge_direction.z * DODGE_SPEED
		_visual_root.scale = Vector3(0.88, 0.90, 0.88)
	else:
		velocity.x = direction.x * WALK_SPEED
		velocity.z = direction.z * WALK_SPEED
		_visual_root.scale = Vector3.ONE

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.25

	if direction.length_squared() > 0.01:
		_visual_root.position.y = sin(_time * 9.0) * 0.025
	else:
		_visual_root.position.y = move_toward(_visual_root.position.y, 0.0, delta * 0.2)
	var attack_sway := sin((_attack_anim / 0.28) * PI) * 0.20 if _attack_anim > 0.0 else 0.0
	if _attack_anim > 0.0:
		_attack_anim = maxf(0.0, _attack_anim - delta)
	_visual_root.rotation.y = _facing_yaw + attack_sway
	move_and_slide()
	if _dodge_timer <= 0.0:
		_end_dodge_collision_phase()

func _unhandled_input(event: InputEvent) -> void:
	if _defeated or controls_locked:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("attack"):
		perform_attack()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("moonbolt"):
		cast_magic()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dodge"):
		_start_dodge()
		get_viewport().set_input_as_handled()

func _start_dodge() -> void:
	if _defeated or controls_locked or dodge_charges <= 0:
		return
	var input_direction := Vector3.ZERO
	if Input.is_action_pressed("move_up"): input_direction.z -= 1.0
	if Input.is_action_pressed("move_down"): input_direction.z += 1.0
	if Input.is_action_pressed("move_left"): input_direction.x -= 1.0
	if Input.is_action_pressed("move_right"): input_direction.x += 1.0
	if input_direction.length_squared() > 0.01:
		_dodge_direction = input_direction.normalized()
	else:
		_dodge_direction = Vector3(sin(_facing_yaw), 0.0, cos(_facing_yaw)).normalized()
	_begin_dodge_collision_phase()
	_dodge_timer = DODGE_DURATION
	dodge_charges -= 1
	if _dodge_recharge_timer <= 0.0:
		_dodge_recharge_timer = DODGE_RECHARGE_PER_CHARGE
	_invulnerability_timer = DODGE_DURATION
	stats_changed.emit()
	notification_requested.emit("Dodge! %d/%d charges left." % [dodge_charges, max_dodge_charges])

func _begin_dodge_collision_phase() -> void:
	# Temporarily ignore enemy bodies so dodge can escape a surround; terrain collision stays intact.
	_end_dodge_collision_phase()
	for item in get_tree().get_nodes_in_group("enemies"):
		var enemy_body := item as PhysicsBody3D
		if is_instance_valid(enemy_body):
			add_collision_exception_with(enemy_body)
			_dodge_collision_exceptions.append(enemy_body)

func _end_dodge_collision_phase() -> void:
	for enemy_body in _dodge_collision_exceptions:
		if is_instance_valid(enemy_body):
			remove_collision_exception_with(enemy_body)
	_dodge_collision_exceptions.clear()

func perform_attack() -> void:
	if _attack_timer > 0.0 or _defeated: return
	_attack_timer = 0.48
	_attack_anim = 0.28
	var target: Node3D = null
	var nearest := 2.7
	for item in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(item): continue
		var distance := global_position.distance_to(item.global_position)
		if distance < nearest:
			nearest = distance
			target = item as Node3D
	if target != null and target.has_method("take_damage"):
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			_facing_yaw = atan2(to_target.x, to_target.z)
		target.call("take_damage", base_damage + weapon_bonus)
	else:
		notification_requested.emit("Move closer to a Voidling to strike.")

func cast_magic() -> void:
	if _magic_timer > 0.0 or _defeated: return
	if mana < mana_cost:
		notification_requested.emit("Not enough mana. Wait a moment for it to regenerate.")
		return
	var target: Node3D = null
	var nearest := 18.0
	for item in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(item): continue
		var distance := global_position.distance_to(item.global_position)
		if distance < nearest:
			nearest = distance
			target = item as Node3D
	if target == null:
		notification_requested.emit("No target in range for Moonbolt.")
		return
	mana -= mana_cost
	_magic_timer = 0.85
	_mana_regen_delay = MANA_REGEN_DELAY_AFTER_CAST
	_mana_regen_accumulator = 0.0
	var bolt_damage: int = magic_damage + weapon_bonus * 2
	magic_requested.emit(global_position + Vector3(0, 1.25, 0), target, bolt_damage)
	notification_requested.emit("MOONBOLT launched: homing shot • %d damage • %d Mana." % [bolt_damage, mana_cost])
	stats_changed.emit()

func gain_xp(amount: int) -> void:
	xp += amount
	var gained_levels := 0
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		gained_levels += 1
		xp_to_next = 50 + (level - 1) * 30
		max_hp += 18
		max_mana += 8
		base_damage += 2
		hp = max_hp
		mana = max_mana
	if gained_levels > 0:
		notification_requested.emit("LEVEL UP! You are now level %d." % level)
	else:
		notification_requested.emit("+%d XP" % amount)
	stats_changed.emit()

func take_damage(amount: int) -> void:
	if _defeated or _invulnerability_timer > 0.0: return
	hp = maxi(0, hp - amount)
	stats_changed.emit()
	if hp <= 0:
		_defeated = true
		defeated.emit()
		# The death panel is the only death message; end the run after a short delay.
		var game_tree := get_tree()
		await game_tree.create_timer(2.0, false).timeout
		if not is_inside_tree(): return
		var scene_change_error: Error = game_tree.change_scene_to_file("res://scenes/refuge.tscn")
		if scene_change_error != OK:
			push_error("Moonveil failed to return to the Refuge after death (error %d)." % scene_change_error)

func add_shard(amount: int = 1) -> void:
	moon_shards += amount
	notification_requested.emit("Moonshard acquired! (%d/3)" % moon_shards)
	stats_changed.emit()

func equip_moonfire_staff() -> bool:
	if has_moonfire_staff:
		notification_requested.emit("Moonfire Staff is already equipped.")
		return false
	if moon_shards < 3:
		notification_requested.emit("Collect 3 Moonshards before upgrading your staff.")
		return false
	moon_shards -= 3
	has_moonfire_staff = true
	weapon_name = "Moonfire Staff"
	weapon_bonus = 8
	magic_damage += 12
	if is_instance_valid(_staff_instance):
		_staff_instance.material_override = _material(Color(0.96, 0.38, 0.78), 0.55, true)
	if is_instance_valid(_gem_instance):
		_gem_instance.material_override = _material(Color(1.0, 0.66, 0.91), 0.25, true)
	notification_requested.emit("MOONFIRE STAFF AWAKENED! Strike %d damage • Moonbolt %d damage." % [base_damage + weapon_bonus, magic_damage + weapon_bonus * 2])
	stats_changed.emit()
	return true
