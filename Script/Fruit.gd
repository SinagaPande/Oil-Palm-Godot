extends RigidBody3D

var has_touched_surface = false
var area_detector = null
var last_touched_surface = ""
var is_falling = false  # Flag tambahan untuk state management

# Tambahkan setting physics
@export var linear_damping = 0.5
@export var angular_damping = 2.0
@export var fruit_mass = 1.0

func _ready():
	add_to_group("buah")
	freeze = true
	
	# Set physics properties
	linear_damp = linear_damping
	angular_damp = angular_damping
	mass = fruit_mass
	
	# Buat Area3D untuk deteksi permukaan
	area_detector = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = SphereShape3D.new()
	collision_shape.shape.radius = 0.8
	area_detector.add_child(collision_shape)
	add_child(area_detector)
	area_detector.position = Vector3(0, -0.8, 0)
	
	# Set collision mask untuk semua layer
	area_detector.collision_mask = 0xFFFFFFFF
	area_detector.collision_layer = 0
	
	area_detector.body_entered.connect(_on_body_entered)
	
	print("Buah siap - Area detector position: ", area_detector.position)

func _on_body_entered(body):
	# Pengecekan state yang lebih robust
	if has_touched_surface or freeze or not is_falling:
		return
	
	print("=== DETEKSI PERMUKAAN ===")
	print("Buah menyentuh: ", body.name)
	print("Tipe: ", body.get_class())
	print("Groups: ", body.get_groups())
	print("=== AKHIR DETEKSI ===")
	
	if (body is StaticBody3D or body is RigidBody3D):
		# Lebih longgar untuk testing
		if not body.is_in_group("player") and not body.is_in_group("buah"):
			last_touched_surface = body.name
			has_touched_surface = true
			print("✅ BUAH TELAH MENYENTUH PERMUKAAN: ", body.name)
			print("has_touched_surface diubah menjadi: ", has_touched_surface)

func fall_from_tree(target_position: Vector3 = Vector3.ZERO):
	if is_falling:
		return
	
	remove_from_group("buah")
	add_to_group("buah_jatuh")
	freeze = false
	is_falling = true
	
	var force_direction = Vector3.ZERO
	
	if target_position != Vector3.ZERO:
		# Hitung arah ke player
		var direction_to_player = (target_position - global_position).normalized()
		# Berikan gaya ke arah player dengan sedikit random
		force_direction = Vector3(
			direction_to_player.x * randf_range(1.5, 3.0),
			randf_range(1.0, 3.0),  # Tetap beri gaya ke atas
			direction_to_player.z * randf_range(1.5, 3.0)
		)
	else:
		# Fallback ke sistem lama jika tidak ada target
		force_direction = Vector3(
			randf_range(-2.0, 2.0),
			randf_range(1.0, 3.0),
			randf_range(-2.0, 2.0)
		)
	
	apply_impulse(force_direction)
	print("Buah jatuh dengan force: ", force_direction)

# Cleanup
func _exit_tree():
	if area_detector and is_inside_tree():
		area_detector.queue_free()
