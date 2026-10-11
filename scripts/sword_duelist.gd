extends "res://scripts/player.gd"

const COMBO_WINDOW := 0.82
const LUNGE_COOLDOWN := 4.5
const LUNGE_COST := 20

var _combo_stage := 0
var _combo_window := 0.0
var _lunge_cooldown := 0.0
var _sword_blade: MeshInstance3D
var _sword_guard: MeshInstance3D

func _ready() -> void:
	character_id = "sword_duelist"
	max_hp = 115
	hp = 115
	max_mana = 35
	mana = 35
	base_damage = 16
	magic_damage = 0
	mana_cost = LUNGE_COST
	weapon_name = "Training Sword"
	weapon_bonus = 0
	super._ready()
	notification_requested.emit("Astra Vale, Sword Duelist. Chain three strikes; Q uses Crescent Lunge.")

func _build_visuals() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "AstraValeDuelistVisuals"
	add_child(_visual_root)

	var mantle := MeshInstance3D.new()
	var mantle_mesh := CapsuleMesh.new()
	mantle_mesh.radius = 0.36
	mantle_mesh.height = 1.34
	mantle.mesh = mantle_mesh
	mantle.material_override = _material(Color(0.32, 0.10, 0.23), 0.18)
	mantle.position.y = 0.91
	_visual_root.add_child(mantle)

	var breastplate := MeshInstance3D.new()
	var plate_mesh := CapsuleMesh.new()
	plate_mesh.radius = 0.285
	plate_mesh.height = 0.88
	breastplate.mesh = plate_mesh
	breastplate.material_override = _material(Color(0.80, 0.34, 0.48), 0.22)
	breastplate.position.y = 0.97
	_visual_root.add_child(breastplate)

	var belt := MeshInstance3D.new()
	var belt_mesh := BoxMesh.new()
	belt_mesh.size = Vector3(0.52, 0.12, 0.40)
	belt.mesh = belt_mesh
	belt.material_override = _material(Color(0.20, 0.17, 0.27), 0.3)
	belt.position.y = 0.67
	_visual_root.add_child(belt)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.285
	head_mesh.height = 0.56
	head.mesh = head_mesh
	head.material_override = _material(Color(1.0, 0.80, 0.72), 0.04)
	head.position.y = 1.72
	_visual_root.add_child(head)

	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.31
	hair_mesh.height = 0.34
	hair.mesh = hair_mesh
	hair.material_override = _material(Color(0.76, 0.79, 0.91), 0.16)
	hair.position = Vector3(0.0, 1.91, -0.05)
	_visual_root.add_child(hair)

	var sword := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.105, 0.95, 0.055)
	sword.mesh = blade_mesh
	sword.material_override = _material(Color(0.79, 0.91, 1.0), 0.72, true)
	sword.position = Vector3(0.48, 1.12, 0.04)
	sword.rotation_degrees.z = -17.0
	_sword_blade = sword
	_visual_root.add_child(sword)

	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.34, 0.075, 0.10)
	guard.mesh = guard_mesh
	guard.material_override = _material(Color(0.94, 0.53, 0.65), 0.6, true)
	guard.position = Vector3(0.48, 0.66, 0.04)
	guard.rotation_degrees.z = -17.0
	_sword_guard = guard
	_visual_root.add_child(guard)

	var pommel := MeshInstance3D.new()
	var pommel_mesh := SphereMesh.new()
	pommel_mesh.radius = 0.09
	pommel_mesh.height = 0.16
	pommel.mesh = pommel_mesh
	pommel.material_override = _material(Color(1.0, 0.68, 0.82), 0.3, true)
	pommel.position = Vector3(0.48, 0.53, 0.04)
	_visual_root.add_child(pommel)

	_hit_flash_material = StandardMaterial3D.new()
	_hit_flash_material.albedo_color = Color(1.0, 1.0, 1.0, 0.72)
	_hit_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hit_flash_material.emission_enabled = true
	_hit_flash_material.emission = Color(1.0, 1.0, 1.0)
	_hit_flash_material.emission_energy_multiplier = 0.35
	for child in _visual_root.get_children():
		var visual := child as MeshInstance3D
		if visual != null:
			_visual_meshes.append(visual)

func _physics_process(delta: float) -> void:
	_combo_window = maxf(0.0, _combo_window - delta)
	if _combo_window <= 0.0:
		_combo_stage = 0
	_lunge_cooldown = maxf(0.0, _lunge_cooldown - delta)
	super._physics_process(delta)
	if is_instance_valid(_sword_blade) and _attack_anim > 0.0:
		var progress := 1.0 - _attack_anim / 0.28
		_sword_blade.rotation_degrees.z = -17.0 + sin(progress * PI) * 92.0
		_sword_blade.position.x = 0.48 + sin(progress * PI) * 0.20
		if is_instance_valid(_sword_guard):
			_sword_guard.rotation_degrees.z = _sword_blade.rotation_degrees.z
			_sword_guard.position.x = _sword_blade.position.x
	else:
		if is_instance_valid(_sword_blade):
			_sword_blade.rotation_degrees.z = -17.0
			_sword_blade.position.x = 0.48
		if is_instance_valid(_sword_guard):
			_sword_guard.rotation_degrees.z = -17.0
			_sword_guard.position.x = 0.48

func _nearest_enemy(max_range: float) -> Node3D:
	var target: Node3D = null
	var nearest := max_range
	for item in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(item):
			continue
		var distance := global_position.distance_to(item.global_position)
		if distance < nearest:
			nearest = distance
			target = item as Node3D
	return target

func perform_attack() -> void:
	if _attack_timer > 0.0 or _defeated or controls_locked:
		return
	_attack_timer = 0.34
	_attack_anim = 0.28
	_combo_stage = (_combo_stage % 3) + 1 if _combo_window > 0.0 else 1
	_combo_window = COMBO_WINDOW
	var damages: Array[int] = [16, 20, 28]
	var ranges: Array[float] = [2.7, 2.9, 3.2]
	var target: Node3D = _nearest_enemy(ranges[_combo_stage - 1])
	if is_instance_valid(target):
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			_facing_yaw = atan2(to_target.x, to_target.z)
		target.call("take_damage", damages[_combo_stage - 1] + weapon_bonus)
		notification_requested.emit("%s STRIKE  ·  %d damage" % [ ["FIRST", "CROSS", "FINISHER"][_combo_stage - 1], damages[_combo_stage - 1] + weapon_bonus])
	else:
		notification_requested.emit("Move within sword range to strike.")

func cast_magic() -> void:
	if _lunge_cooldown > 0.0 or _defeated or controls_locked:
		notification_requested.emit("Crescent Lunge recharging: %.1fs." % _lunge_cooldown)
		return
	if mana < LUNGE_COST:
		notification_requested.emit("Not enough stamina for Crescent Lunge.")
		return
	var target: Node3D = _nearest_enemy(12.0)
	var dash_direction := Vector3(sin(_facing_yaw), 0.0, cos(_facing_yaw)).normalized()
	if is_instance_valid(target):
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			dash_direction = to_target.normalized()
			_facing_yaw = atan2(dash_direction.x, dash_direction.z)
	else:
		notification_requested.emit("No Voidling nearby; Crescent Lunge follows your facing direction.")
	mana -= LUNGE_COST
	_mana_regen_delay = 0.8
	_mana_regen_accumulator = 0.0
	_lunge_cooldown = LUNGE_COOLDOWN
	_dodge_direction = dash_direction
	_dodge_timer = 0.31
	_invulnerability_timer = maxf(_invulnerability_timer, 0.31)
	_begin_dodge_collision_phase()
	_attack_anim = 0.28
	if is_instance_valid(target):
		_resolve_lunge_hit.call_deferred(target)
	stats_changed.emit()
	notification_requested.emit("CRESCENT LUNGE  ·  dash strike  ·  %.1fs cooldown" % LUNGE_COOLDOWN)

func _resolve_lunge_hit(target: Node3D) -> void:
	await get_tree().create_timer(0.25, false).timeout
	if not is_inside_tree() or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) <= 3.5 and target.has_method("take_damage"):
		target.call("take_damage", 30 + weapon_bonus)
		notification_requested.emit("CRESCENT LUNGE HIT  ·  %d damage" % (30 + weapon_bonus))

func get_skill_status_text() -> String:
	return "Q CRESCENT LUNGE  ·  READY" if _lunge_cooldown <= 0.0 else "Q LUNGE  ·  %.1fs" % _lunge_cooldown

func equip_moonfire_staff() -> bool:
	notification_requested.emit("The Training Sword has its own path; no staff upgrade is available.")
	return false
