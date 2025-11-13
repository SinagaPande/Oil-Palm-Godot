extends Node3D

@export var fruit_scene: PackedScene
@export var auto_ripe_chance: bool = true
@export var min_ripe_chance: float = 0.3
@export var max_ripe_chance: float = 0.8

@export var tree_model_low: PackedScene

const TREE_LOD_HIGH_DISTANCE = 20
const TREE_LOD_LOW_DISTANCE = 25.0
const TREE_CULLING_DISTANCE: float = 300
const TREE_MIN_CULLING_DISTANCE: float = 10
const TREE_BACKFACE_THRESHOLD: float = 0.2

const TREE_NEAR_UPDATE_INTERVAL: float = 0.05
const TREE_FAR_UPDATE_INTERVAL: float = 0.3

var current_tree_lod: String = "high"
var player_node: Node3D = null
var camera_node: Camera3D = null
var has_tree_lod: bool = false
var original_mesh: MeshInstance3D = null
var is_tree_culled: bool = false

var tree_culling_update_timer: float = 0.0
var tree_current_update_interval: float = 0.3
var tree_last_camera_forward: Vector3 = Vector3.ZERO
var tree_last_player_position: Vector3 = Vector3.ZERO

var ripe_chance: float = 0.5
var lod_update_timer: float = 0.0
const LOD_UPDATE_INTERVAL: float = 0.2
var all_fruits: Array = []
var has_spawned_fruits: bool = false

var is_initializing: bool = true
var spawn_retry_count: int = 0
const MAX_SPAWN_RETRIES: int = 3

# ⚠️ PERBAIKAN: Tambahkan variabel untuk menunggu player
var player_search_attempts: int = 0
const MAX_PLAYER_SEARCH_ATTEMPTS: int = 10

func _ready():
	add_to_group("tree")
	
	if auto_ripe_chance:
		ripe_chance = randf_range(min_ripe_chance, max_ripe_chance)
	
	# ⚠️ PERBAIKAN: Tunggu player sebelum setup sistem apapun
	var player_found = await wait_for_player()
	if not player_found:
		push_error("Tree: Gagal menemukan player, skip initialization")
		return
	
	# ⚠️ PERBAIKAN: Setup semua sistem sekaligus setelah player ready
	setup_all_systems()
	
	visible = true
	
	# ⚠️ PERBAIKAN: Spawn fruits setelah semua sistem ready
	await get_tree().process_frame
	spawn_initial_fruits()

# ⚠️ PERBAIKAN: Fungsi baru untuk menunggu player ready
func wait_for_player():
	print("Tree: Mencari player...")
	player_search_attempts = 0
	
	# Coba method 1: Cek existing players
	while player_search_attempts < MAX_PLAYER_SEARCH_ATTEMPTS:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0]
			
			# ⚠️ PERBAIKAN: Update pemanggilan function yang baru
			if is_player_ready(player_node):
				if setup_camera_from_player(player_node):
					print("Tree: Player dan camera ready setelah ", player_search_attempts + 1, " attempts")
					return true
			else:
				print("Tree: Player found tapi belum ready, attempt ", player_search_attempts + 1)
		else:
			print("Tree: Player tidak ditemukan, attempt ", player_search_attempts + 1)
		
		player_search_attempts += 1
		await get_tree().create_timer(0.2).timeout  # ⚠️ PERBAIKAN: Increase delay
	
	# ⚠️ PERBAIKAN: Method 2: Coba cari player di scene tree
	print("Tree: Mencoba method alternatif mencari player...")
	player_node = find_player_in_scene()
	if player_node and is_player_ready(player_node) and setup_camera_from_player(player_node):
		print("Tree: Player ditemukan via scene search")
		return true
	
	push_error("Tree: Gagal menemukan player setelah " + str(MAX_PLAYER_SEARCH_ATTEMPTS) + " attempts")
	return false

# ⚠️ PERBAIKAN: Helper function untuk cek player readiness - UPDATE
func is_player_ready(player: Node) -> bool:
	if player == null:
		return false
	
	# Method 1: Cek method exists - UPDATE nama function
	if player.has_method("is_player_ready"):
		return player.is_player_ready()
	
	# Method 2: Cek method alternatif
	if player.has_method("get_initialization_status"):
		return player.get_initialization_status()
	
	# Method 3: Cek property exists
	if player.has_method("get") and player.get("is_fully_initialized") != null:
		return player.get("is_fully_initialized")
	
	# Method 4: Asumsikan ready setelah beberapa detik
	return true  # Fallback: assume ready after timeout

# ⚠️ PERBAIKAN: Helper function untuk setup camera
func setup_camera_from_player(player: Node) -> bool:
	if player == null:
		return false
	
	# Coba berbagai path camera yang mungkin
	var camera_paths = [
		"PlayerController/Camera3D",
		"Camera3D",
		"Head/Camera3D",
		"Camera"
	]
	
	for path in camera_paths:
		if player.has_node(path):
			camera_node = player.get_node(path)
			print("Tree: Camera ditemukan di path: ", path)
			return true
	
	# Fallback: cari camera recursively
	camera_node = find_camera_recursive(player)
	if camera_node:
		print("Tree: Camera ditemukan via recursive search")
		return true
	
	print("Tree: Camera tidak ditemukan")
	return false

# ⚠️ PERBAIKAN: Recursive camera search
func find_camera_recursive(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found = find_camera_recursive(child)
		if found:
			return found
	return null

# ⚠️ PERBAIKAN: Alternative player search
func find_player_in_scene() -> Node:
	# Coba cari di root scene
	var root = get_tree().root
	return find_player_recursive(root)

func find_player_recursive(node: Node) -> Node:
	# Cek jika node ini player
	if node.is_in_group("player"):
		return node
	
	# Cek jika node memiliki method player
	if node.has_method("is_fully_initialized") or node.has_method("get_player_position"):
		return node
	
	# Recurse melalui children
	for child in node.get_children():
		var found = find_player_recursive(child)
		if found:
			return found
	
	return null

# ⚠️ PERBAIKAN: Setup semua sistem dalam satu fungsi
func setup_all_systems():
	setup_tree_lod_system()
	setup_tree_culling_system()
	
	if player_node and camera_node:
		tree_last_camera_forward = -camera_node.global_transform.basis.z
		tree_last_player_position = player_node.global_position
		print("Tree: Semua sistem setup complete")

func _process(delta):
	# ⚠️ PERBAIKAN: Skip processing selama initialization
	if not is_initializing and player_node and camera_node:
		lod_update_timer += delta
		if lod_update_timer >= LOD_UPDATE_INTERVAL:
			lod_update_timer = 0.0
			update_all_fruits_lod()
			if has_tree_lod:
				update_tree_lod()
		
		tree_culling_update_timer += delta
		check_tree_immediate_culling_trigger()
		
		if tree_culling_update_timer >= tree_current_update_interval:
			tree_culling_update_timer = 0.0
			update_tree_culling()
			update_tree_culling_priority()

func check_tree_immediate_culling_trigger():
	if not camera_node or not player_node:
		return
	
	var current_camera_forward = -camera_node.global_transform.basis.z
	var current_player_position = player_node.global_position
	
	var camera_dot = current_camera_forward.dot(tree_last_camera_forward)
	var camera_changed = camera_dot < 0.9
	
	var position_delta = current_player_position.distance_to(tree_last_player_position)
	var position_changed = position_delta > 3.0
	
	var distance_to_player = global_position.distance_to(current_player_position)
	var entered_near_zone = distance_to_player <= 25.0 and tree_last_player_position.distance_to(global_position) > 25.0
	
	if camera_changed or position_changed or entered_near_zone:
		update_tree_culling()
		update_tree_culling_priority()
		tree_last_camera_forward = current_camera_forward
		tree_last_player_position = current_player_position

func update_tree_culling_priority():
	if not player_node:
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	if distance_to_player <= 12.0:
		tree_current_update_interval = 0.03
	elif distance_to_player <= 25.0 and (is_tree_in_front_of_player() or is_tree_in_camera_frustum()):
		tree_current_update_interval = TREE_NEAR_UPDATE_INTERVAL
	elif distance_to_player <= 50.0:
		tree_current_update_interval = 0.2
	else:
		tree_current_update_interval = TREE_FAR_UPDATE_INTERVAL

func setup_tree_lod_system():
	# ⚠️ PERBAIKAN: Player sudah di-set di wait_for_player(), tidak perlu search lagi
	if not tree_model_low:
		return
	
	_find_original_mesh()

func setup_tree_culling_system():
	# ⚠️ PERBAIKAN: Player dan camera sudah di-set di wait_for_player()
	if not original_mesh:
		return
	
	has_tree_lod = true
	# ⚠️ PERBAIKAN: Jangan update LOD selama initialization
	# update_tree_lod() dipindah ke _process setelah initialization selesai

func _find_original_mesh():
	for child in get_children():
		if child is MeshInstance3D:
			original_mesh = child
			return
	
	var found_mesh = _find_mesh_recursive(self)
	if found_mesh:
		original_mesh = found_mesh
		return

func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found = _find_mesh_recursive(child)
		if found:
			return found
	return null

func update_tree_lod():
	if not player_node or not has_tree_lod:
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	var new_lod_level = "high" if distance_to_player <= TREE_LOD_HIGH_DISTANCE else "low"
	
	if new_lod_level != current_tree_lod:
		current_tree_lod = new_lod_level
		apply_tree_lod()

func update_tree_culling():
	if not player_node or not camera_node:
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	if distance_to_player <= TREE_MIN_CULLING_DISTANCE:
		if is_tree_culled:
			set_tree_culled(false)
		return
	
	var should_be_active = (
		distance_to_player <= TREE_CULLING_DISTANCE and
		is_tree_in_camera_frustum() and
		is_tree_in_front_of_player()
	)
	
	if should_be_active and is_tree_culled:
		set_tree_culled(false)
	elif not should_be_active and not is_tree_culled:
		set_tree_culled(true)

func is_tree_in_camera_frustum() -> bool:
	if not camera_node:
		return true
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	if distance_to_player <= TREE_MIN_CULLING_DISTANCE:
		return true
	
	var tree_screen_pos = camera_node.unproject_position(global_position)
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 150
	
	return (
		tree_screen_pos.x >= -margin and
		tree_screen_pos.x <= viewport_size.x + margin and
		tree_screen_pos.y >= -margin and
		tree_screen_pos.y <= viewport_size.y + margin
	)

func is_tree_in_front_of_player() -> bool:
	if not player_node or not camera_node:
		return true
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	if distance_to_player <= TREE_MIN_CULLING_DISTANCE:
		return true
	
	var player_forward = -camera_node.global_transform.basis.z
	var direction_to_tree = (global_position - player_node.global_position).normalized()
	
	return player_forward.dot(direction_to_tree) > TREE_BACKFACE_THRESHOLD

func set_tree_culled(culled: bool):
	if is_tree_culled == culled:
		return
	
	# ⚠️ PERBAIKAN: Block culling selama initialization
	if is_initializing and culled:
		return
	
	is_tree_culled = culled
	
	if culled:
		visible = false
		for fruit in all_fruits:
			if is_instance_valid(fruit):
				fruit.visible = false
				fruit.process_mode = PROCESS_MODE_DISABLED
	else:
		visible = true
		for fruit in all_fruits:
			if is_instance_valid(fruit):
				fruit.process_mode = PROCESS_MODE_INHERIT
				fruit.visible = true
		
		if has_tree_lod:
			update_tree_lod()

func apply_tree_lod():
	if not original_mesh:
		return
	
	if current_tree_lod == "high":
		original_mesh.visible = true
		var low_model = find_child("TreeLowLOD", true, false)
		if low_model:
			low_model.queue_free()
	else:
		original_mesh.visible = false
		var low_model = find_child("TreeLowLOD", true, false)
		if not low_model and tree_model_low:
			var low_instance = tree_model_low.instantiate()
			if low_instance:
				low_instance.name = "TreeLowLOD"
				add_child(low_instance)
				low_instance.global_position = global_position
				low_instance.global_rotation = global_rotation

func update_all_fruits_lod():
	for fruit in all_fruits:
		if is_instance_valid(fruit) and fruit.has_method("update_lod"):
			fruit.update_lod()

func spawn_initial_fruits():
	if has_spawned_fruits:
		return
	
	var spawn_points_node = $SpawnPoints
	if not spawn_points_node:
		# ⚠️ PERBAIKAN: Retry mechanism jika node belum ready
		if spawn_retry_count < MAX_SPAWN_RETRIES:
			spawn_retry_count += 1
			await get_tree().process_frame
			call_deferred("spawn_initial_fruits")
			return
		else:
			push_error("Failed to find SpawnPoints after " + str(MAX_SPAWN_RETRIES) + " attempts")
			return
	
	var markers = []
	for child in spawn_points_node.get_children():
		if child is Marker3D:
			markers.append(child)
	
	var total_markers = markers.size()
	if total_markers == 0:
		push_warning("No spawn markers found for tree")
		has_spawned_fruits = true
		is_initializing = false
		return
	
	var ripe_count = int(total_markers * ripe_chance)
	ripe_count = clamp(ripe_count, 1, total_markers)
	
	var fruit_types = []
	for i in range(total_markers):
		if i < ripe_count:
			fruit_types.append("Masak")
		else:
			fruit_types.append("Mentah")
	
	shuffle_array(fruit_types)
	all_fruits.clear()
	
	for i in range(markers.size()):
		spawn_fruit_with_type(markers[i], fruit_types[i])
	
	has_spawned_fruits = true
	
	# ⚠️ PERBAIKAN: Tandai initialization selesai setelah semua fruit ter-spawn
	is_initializing = false
	print("Tree initialized with ", all_fruits.size(), " fruits")

func shuffle_array(arr: Array):
	for i in range(arr.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

func spawn_fruit_with_type(marker: Marker3D, fruit_type: String) -> RigidBody3D:
	if not fruit_scene:
		push_error("Fruit scene not assigned to tree")
		return null
	
	var fruit_instance = fruit_scene.instantiate()
	if not fruit_instance:
		push_error("Failed to instantiate fruit")
		return null
	
	add_child(fruit_instance)
	all_fruits.append(fruit_instance)
	
	fruit_instance.global_position = marker.global_position
	fruit_instance.global_rotation = marker.global_rotation
	
	# ⚠️ PERBAIKAN: Berikan reference tree ke fruit untuk sync
	if fruit_instance.has_method("set_parent_tree"):
		fruit_instance.set_parent_tree(self)
	
	if fruit_instance.has_method("set_fruit_type"):
		fruit_instance.set_fruit_type(fruit_type)
	else:
		fruit_instance.fruit_type = fruit_type
		if fruit_instance.has_method("setup_fruit_model"):
			fruit_instance.setup_fruit_model()
	
	# ✅ DEBUG: Print jenis buah yang di-spawn
	print("Tree spawned fruit: ", fruit_type, " at position: ", marker.global_position)
	
	# ⚠️ PERBAIKAN: Selalu aktifkan fruit selama initialization
	# Fruit akan diatur ulang oleh culling system nanti
	fruit_instance.visible = true
	fruit_instance.process_mode = PROCESS_MODE_INHERIT
	
	return fruit_instance
