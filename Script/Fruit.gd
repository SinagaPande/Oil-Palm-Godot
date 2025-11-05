extends RigidBody3D

var has_touched_surface = false
var is_falling = false
var fruit_type: String = "Masak"

@export var linear_damping = 0.5
@export var angular_damping = 2.0
@export var fruit_mass = 1.0
# HAPUS @export untuk models, gunakan preload langsung

# GANTI dengan preload - SESUAIKAN PATH dengan project Anda
var ripe_model = preload("res://3D Asset/Buah_Sawit_Masak.gltf")
var unripe_model = preload("res://3D Asset/Buah_Sawit_Mentah.gltf")

const AREA_OFFSET = Vector3(0, -0.8, 0)
const COLLISION_RADIUS = 0.8

func _ready():
	add_to_group("buah")
	freeze = true
	
	linear_damp = linear_damping
	angular_damp = angular_damping
	mass = fruit_mass
	
	setup_area_detector()

func set_fruit_type(type: String):
	fruit_type = type
	setup_fruit_model()

func setup_fruit_model():
	print("=== SETUP FRUIT MODEL ===")
	print("fruit_type: ", fruit_type)
	print("ripe_model loaded: ", ripe_model != null)
	print("unripe_model loaded: ", unripe_model != null)
	
	# Hapus semua model existing
	var nodes_to_remove = []
	for child in get_children():
		if (child is Node3D and 
			not child is CollisionShape3D and 
			not child is Area3D and
			child.name != "ModelContainer"):
			nodes_to_remove.append(child)
	
	for node in nodes_to_remove:
		node.queue_free()
	
	# Setup model container
	var model_container = get_node_or_null("ModelContainer")
	if not model_container:
		model_container = Node3D.new()
		model_container.name = "ModelContainer"
		add_child(model_container)
	
	# Hapus model lama di container
	for child in model_container.get_children():
		child.queue_free()
	
	# Pilih dan instantiate model
	var selected_model = ripe_model if fruit_type == "Masak" else unripe_model
	
	if selected_model:
		var model_instance = selected_model.instantiate()
		model_container.add_child(model_instance)
		print("✅ Model berhasil di-load: " + fruit_type)
	else:
		push_error("❌ Model gagal di-load untuk: " + fruit_type)

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
	
func test_models():
	print("=== TESTING MODELS ===")
	if ripe_model:
		print("Testing ripe_model instantiate...")
		var test_instance = ripe_model.instantiate()
		if test_instance:
			print("✅ ripe_model OK")
			test_instance.queue_free()
		else:
			print("❌ ripe_model FAILED")
	else:
		print("❌ ripe_model is NULL")
	
	if unripe_model:
		print("Testing unripe_model instantiate...")
		var test_instance = unripe_model.instantiate()
		if test_instance:
			print("✅ unripe_model OK") 
			test_instance.queue_free()
		else:
			print("❌ unripe_model FAILED")
	else:
		print("❌ unripe_model is NULL")
