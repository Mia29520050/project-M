extends CharacterBody3D

signal stats_changed
signal notification_requested(message: String)
signal magic_requested(origin: Vector3, target: Node3D, damage: int)
signal defeated

const WALK_SPEED := 5.8
const GRAVITY := 22.0
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
	staff.position = Vector3(0.55, 0.77, 0.05)
	staff.rotation_degrees.z = -9.0
	_visual_root.add_child(staff)

	var gem := MeshInstance3D.new()
	var gem_mesh := SphereMesh.new()
	gem_mesh.radius = 0.15
	gem_mesh.height = 0.30
	gem.mesh = gem_mesh
	gem.material_override = _material(Color(0.63, 0.92, 1.0), 0.1, true)
	gem.position = Vector3(0.55, 1.43, 0.05)
	_visual_root.add_child(gem)

func _physics_process(delta: float) -> void:
	_time += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_magic_timer = maxf(0.0, _magic_timer - delta)
	if _defeated:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * delta * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * delta * 3.0)
		return

	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1.0
	direction = direction.normalized()
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.25

	if direction.length_squared() > 0.01:
		_visual_root.rotation.y = atan2(direction.x, direction.z)
		_visual_root.position.y = sin(_time * 9.0) * 0.025
	else:
		_visual_root.position.y = move_toward(_visual_root.position.y, 0.0, delta * 0.2)
	if _attack_anim > 0.0:
		_attack_anim = maxf(0.0, _attack_anim - delta)
		_visual_root.rotation.y += sin(_attack_anim * 17.0) * 0.5
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if _defeated: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: perform_attack()
		elif event.keycode == KEY_Q: cast_magic()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		perform_attack()

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
		target.call("take_damage", base_damage + weapon_bonus)
	else:
		notification_requested.emit("Move closer to a Voidling to strike.")

func cast_magic() -> void:
	if _magic_timer > 0.0 or _defeated: return
	if mana < mana_cost:
		notification_requested.emit("Not enough mana. Wait for it to recover.")
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
	magic_requested.emit(global_position + Vector3(0, 1.25, 0), target, magic_damage + weapon_bonus * 2)
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
	if _defeated: return
	hp = maxi(0, hp - amount)
	stats_changed.emit()
	if hp <= 0:
		_defeated = true
		defeated.emit()
		notification_requested.emit("You have fallen. Returning to the Moonveil shrine...")
		await get_tree().create_timer(2.0).timeout
		if not is_inside_tree(): return
		hp = max_hp
		mana = max_mana
		global_position = Vector3(0, 0, 6)
		velocity = Vector3.ZERO
		_defeated = false
		notification_requested.emit("The shrine has restored you.")
		stats_changed.emit()

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
	notification_requested.emit("Equipment upgraded: Moonfire Staff! Magic power increased.")
	stats_changed.emit()
	return true
