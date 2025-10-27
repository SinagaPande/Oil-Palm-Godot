extends RigidBody3D

var has_touched_surface = false
var is_falling = false

@export var linear_damping = 0.5
@export var angular_damping = 2.0
@export var fruit_mass = 1.0

const AREA_OFFSET = Vector3(0, -0.8, 0)
const COLLISION_RADIUS = 0.8

func _ready():
	add_to_group("buah")
	freeze = true
	
	linear_damp = linear_damping
	angular_damp = angular_damping
	mass = fruit_mass
	
	setup_area_detector()

func setup_area_detector():
	var area_detector = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = SphereShape3D.new()
	collision_shape.shape.radius = COLLISION_RADIUS
	
	area_detector.add_child(collision_shape)
	add_child(area_detector)
	
	area_detector.position = AREA_OFFSET
	area_detector.collision_mask = 0xFFFFFFFF
	area_detector.collision_layer = 0
	area_detector.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if has_touched_surface or freeze or not is_falling:
		return
	
	if body is StaticBody3D or body is RigidBody3D:
		if not body.is_in_group("player") and not body.is_in_group("buah"):
			has_touched_surface = true

func fall_from_tree(target_position: Vector3 = Vector3.ZERO):
	if is_falling:
		return
	
	remove_from_group("buah")
	add_to_group("buah_jatuh")
	freeze = false
	is_falling = true
	
	var force_direction = Vector3(
		randf_range(-2.0, 2.0),
		randf_range(1.0, 3.0),
		randf_range(-2.0, 2.0)
	)
	
	# Jika ada target position, arahkan ke player
	if target_position != Vector3.ZERO:
		var direction_to_player = (target_position - global_position).normalized()
		force_direction = Vector3(
			direction_to_player.x * randf_range(1.5, 3.0),
			randf_range(1.0, 3.0),
			direction_to_player.z * randf_range(1.5, 3.0)
		)
	
	apply_impulse(force_direction)
