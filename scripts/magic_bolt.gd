extends Node3D

var target: Node3D
var damage := 24
var travel_speed := 15.5
const RETARGET_RADIUS := 8.0
var _last_target_position := Vector3.ZERO
var _visual: MeshInstance3D

func _ready() -> void:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.50
	orb.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.53, 0.91, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.30, 0.82, 1.0)
	material.emission_energy_multiplier = 4.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb.material_override = material
	add_child(orb)
	_visual = orb

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.25
	ring_mesh.outer_radius = 0.34
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.64, 0.94, 1.0)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.36, 0.86, 1.0)
	ring_material.emission_energy_multiplier = 2.2
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	ring.rotation_degrees = Vector3(52.0, 18.0, 26.0)
	add_child(ring)

	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 0.82, 1.0)
	light.light_energy = 1.8
	light.omni_range = 3.5
	add_child(light)

func configure(target_node: Node3D, hit_damage: int) -> void:
	target = target_node
	damage = hit_damage
	if is_instance_valid(target_node):
		_last_target_position = target_node.global_position + Vector3(0.0, 0.85, 0.0)

func _process(delta: float) -> void:
	rotation.z += delta * 5.0
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		_last_target_position = target.global_position + Vector3(0.0, 0.85, 0.0)
	else:
		target = _find_retarget()
		if is_instance_valid(target):
			_last_target_position = target.global_position + Vector3(0.0, 0.85, 0.0)
		else:
			# No replacement in range: finish travelling toward the previous target point.
			_move_toward_last_target(delta)
			return

	var to_target := _last_target_position - global_position
	if to_target.length() <= travel_speed * delta + 0.30:
		if is_instance_valid(target) and not target.is_queued_for_deletion() and target.has_method("take_damage"):
			target.call("take_damage", damage)
		queue_free()
		return
	global_position += to_target.normalized() * travel_speed * delta

func _find_retarget() -> Node3D:
	var nearest_target: Node3D = null
	var nearest_distance := RETARGET_RADIUS
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		if not candidate.has_method("take_damage"):
			continue
		var distance: float = global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_target = candidate as Node3D
	return nearest_target

func _move_toward_last_target(delta: float) -> void:
	var to_last_target: Vector3 = _last_target_position - global_position
	if to_last_target.length() <= travel_speed * delta + 0.30:
		queue_free()
		return
	global_position += to_last_target.normalized() * travel_speed * delta
