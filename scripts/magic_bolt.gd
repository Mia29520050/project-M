extends Node3D

var target: Node3D
var damage := 24
var travel_speed := 15.5
var _visual: MeshInstance3D

func _ready() -> void:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	orb.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.53, 0.91, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.30, 0.82, 1.0)
	material.emission_energy_multiplier = 3.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb.material_override = material
	add_child(orb)
	_visual = orb

func configure(target_node: Node3D, hit_damage: int) -> void:
	target = target_node
	damage = hit_damage

func _process(delta: float) -> void:
	rotation.z += delta * 5.0
	if not is_instance_valid(target):
		queue_free()
		return
	var destination := target.global_position + Vector3(0.0, 0.85, 0.0)
	var to_target := destination - global_position
	if to_target.length() <= travel_speed * delta + 0.30:
		if target.has_method("take_damage"):
			target.call("take_damage", damage)
		queue_free()
		return
	global_position += to_target.normalized() * travel_speed * delta
