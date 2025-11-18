extends CharacterBody3D
class_name HarvesterNPC

enum NPCState {
	SPAWN,
	SEARCH, 
	MOVE,
	HARVEST,
	IDLE
}

@export var move_speed: float = 3.0
@export var harvest_range: float = 2.0
@export var search_radius: float = 15.0
@export var max_carry_capacity: int = 10

@export var camera_frustum_margin: float = 100.0

var current_state: NPCState = NPCState.SPAWN
var target_tree: Node3D = null
var harvest_timer: float = 0.0
var harvest_delay_per_fruit: float = 2.0  # ⬅️ 2 DETIK PER BUAH
var fruits_to_harvest: int = 0
var current_harvest_count: int = 0

# Inventory NPC yang terpisah dari player
var npc_carried_ripe_fruits: int = 0
var total_harvested_by_npc: int = 0  # Total buah yang sudah dipanen NPC
var npc_carried_ripe_kg: int = 0  # Tambah tracking kg untuk NPC

var player_node: Node3D = null
var camera_node: Camera3D = null

var last_mode_check_time: float = 0.0
var mode_check_interval: float = 1.0

var visited_trees: Array = []
var search_attempts: int = 0
const MAX_SEARCH_ATTEMPTS: int = 15
var last_tree_check_time: float = 0.0
const TREE_CHECK_INTERVAL: float = 5.0

var tree_cooldowns: Dictionary = {}
const TREE_COOLDOWN_TIME: float = 10.0

# ⬅️ VARIABLE BARU: Tracking buah yang sedang diproses
var current_harvesting_fruits: Array = []  # Array buah yang akan dihapus
var harvest_progress_timer: float = 0.0

# Signal untuk mengirim data panen NPC
signal npc_harvested_fruits(harvested_count, total_harvested)

# Collision configuration
var collision_shape: CollisionShape3D = null

func _ready():
	add_to_group("harvester_npc")
	setup_collision_config()
	# ⬅️ JANGAN LANGSUNG TRANSISI KE SPAWN, TUNGGU PLAYER DULU
	call_deferred("delayed_initialize")

# ⬅️ FUNGSI BARU: Inisialisasi tertunda
func delayed_initialize():
	await get_tree().process_frame
	initialize_npc()

func setup_collision_config():
	# Cari CollisionShape3D dan atur untuk bisa menembus object
	collision_shape = find_child("CollisionShape3D")
	if collision_shape:
		# Set collision mask untuk menghindari tabrakan dengan object static
		collision_mask = 0x00000001  # Hanya layer 1 (ground biasanya)
		# Non-aktifkan collision dengan object lain
		set_collision_layer_value(2, false)  # Player
		set_collision_layer_value(3, false)  # NPC lain  
		set_collision_layer_value(4, false)  # Object static
		set_collision_layer_value(5, false)  # Buah
		
		# Atur collision shape menjadi trigger-only
		if collision_shape.shape is CapsuleShape3D or collision_shape.shape is SphereShape3D:
			collision_shape.shape.radius *= 0.8  # Sedikit perkecil untuk memudahkan navigasi

func _physics_process(delta):
	state_process(delta)
	update_tree_cooldowns(delta)

func state_process(delta):
	match current_state:
		NPCState.SPAWN:
			pass  # ⬅️ SUDAH DIPINDAH KE initialize_npc()
			
		NPCState.SEARCH:
			var nearest_tree = find_nearest_tree()
			if nearest_tree:
				target_tree = nearest_tree
				transition_to_state(NPCState.MOVE)
			else:
				if npc_carried_ripe_fruits > 0:
					# NPC tidak mengantar, tapi tetap reset setelah membawa buah
					reset_after_carrying()
				else:
					if should_reset_visited_trees():
						smart_reset_visited_trees()
					transition_to_state(NPCState.IDLE)
			
		NPCState.MOVE:
			if target_tree and is_instance_valid(target_tree):
				move_towards_target(target_tree.global_position)
				var distance_to_tree = global_position.distance_to(target_tree.global_position)
				if distance_to_tree <= harvest_range:
					transition_to_state(NPCState.HARVEST)
			else:
				target_tree = null
				transition_to_state(NPCState.SEARCH)
			
		NPCState.HARVEST:
			harvest_timer += delta
			harvest_progress_timer += delta  # ⬅️ TIMER PROGRESS HARVEST
			
			# ⬅️ PROSES HARVEST SATU PER SATU
			if harvest_progress_timer >= harvest_delay_per_fruit and current_harvesting_fruits.size() > 0:
				harvest_progress_timer = 0.0
				harvest_single_fruit()  # ⬅️ PANEN SATU BUAH
			
			# Cek apakah harvest sudah selesai
			if current_harvest_count >= fruits_to_harvest or npc_carried_ripe_fruits >= max_carry_capacity:
				if should_mark_tree_visited(target_tree):
					mark_tree_visited(target_tree)
				
				# Setelah panen selesai, reset state (tidak perlu ke delivery zone)
				reset_after_carrying()
			
		NPCState.IDLE:
			harvest_timer += delta
			if harvest_timer >= 3.0:
				harvest_timer = 0.0
				transition_to_state(NPCState.SEARCH)

# ⬅️ FUNGSI BARU: Panen satu buah matang
func harvest_single_fruit():
	if current_harvesting_fruits.size() == 0:
		return
	
	# Ambil buah pertama dari array
	var fruit = current_harvesting_fruits[0]
	current_harvesting_fruits.remove_at(0)
	
	if is_instance_valid(fruit):
		# Hapus buah dari scene
		fruit.queue_free()
		
		# Update inventory NPC
		current_harvest_count += 1
		npc_carried_ripe_fruits += 1
		
		# Hitung berat (30-40 kg per buah)
		var harvested_kg = randi_range(30, 40)
		npc_carried_ripe_kg += harvested_kg
		total_harvested_by_npc += harvested_kg
		
		# Kirim signal dengan data panen
		npc_harvested_fruits.emit(1, total_harvested_by_npc)  # ⬅️ 1 BUAH PER PANEN
		
		print("NPC memanen 1 buah matang (%d kg). Total dipanen: %d kg" % [harvested_kg, total_harvested_by_npc])

func reset_after_carrying():
	# Reset state setelah NPC membawa buah (tidak mengantar ke zone)
	npc_carried_ripe_fruits = 0
	npc_carried_ripe_kg = 0
	current_harvesting_fruits.clear()  # ⬅️ CLEAR ARRAY BUAH
	visited_trees.clear()
	tree_cooldowns.clear()
	search_attempts = 0
	harvest_progress_timer = 0.0  # ⬅️ RESET TIMER
	transition_to_state(NPCState.SEARCH)

func transition_to_state(new_state: NPCState):
	state_exit(current_state)
	current_state = new_state
	state_enter(new_state)

func state_enter(state: NPCState):
	match state:
		NPCState.SPAWN:
			pass
			
		NPCState.SEARCH:
			search_attempts += 1
			
			if search_attempts >= MAX_SEARCH_ATTEMPTS:
				smart_reset_visited_trees()
				search_attempts = 0
			
		NPCState.MOVE:
			pass
			
		NPCState.HARVEST:
			if target_tree and is_instance_valid(target_tree):
				if target_tree.has_method("set_harvesting_mode_active"):
					target_tree.set_harvesting_mode_active(true)
				
				fruits_to_harvest = calculate_fruits_to_harvest()
				current_harvest_count = 0
				harvest_timer = 0.0
				harvest_progress_timer = 0.0
				
				# ⬅️ PERBAIKAN: Ambil buah matang
				current_harvesting_fruits = get_ripe_fruits_from_tree(target_tree)
				
				# ⬅️ PERBAIKAN CRITICAL: Batasi jumlah buah dengan cara yang benar
				if fruits_to_harvest > 0 and current_harvesting_fruits.size() > 0:
					# Ambil maksimal fruits_to_harvest buah, tapi tidak lebih dari yang tersedia
					var max_fruits_to_take = min(fruits_to_harvest, current_harvesting_fruits.size())
					if max_fruits_to_take < current_harvesting_fruits.size():
						current_harvesting_fruits = current_harvesting_fruits.slice(0, max_fruits_to_take)
					
					print("NPC mulai memanen %d buah matang (satu per satu)" % current_harvesting_fruits.size())
				else:
					# Jika tidak ada buah yang bisa dipanen, kembali ke SEARCH
					print("NPC: Tidak ada buah matang yang bisa dipanen")
					transition_to_state(NPCState.SEARCH)
			
		NPCState.IDLE:
			pass

func state_exit(state: NPCState):
	match state:
		NPCState.HARVEST:
			if target_tree and is_instance_valid(target_tree) and target_tree.has_method("set_harvesting_mode_active"):
				target_tree.set_harvesting_mode_active(false)
			current_harvesting_fruits.clear()  # ⬅️ CLEAR SAAT KELUAR STATE

# ⬅️ FUNGSI BARU: Dapatkan semua buah matang dari pohon
func get_ripe_fruits_from_tree(tree: Node3D) -> Array:
	var ripe_fruits = []
	
	if not tree or not is_instance_valid(tree):
		return ripe_fruits
	
	# Akses array all_fruits dari pohon
	if tree.has_method("get_all_fruits"):
		var all_fruits = tree.get_all_fruits()
		for fruit in all_fruits:
			if is_instance_valid(fruit) and fruit.has_method("get_fruit_type"):
				if fruit.get_fruit_type() == "Masak":
					ripe_fruits.append(fruit)
	
	return ripe_fruits

func calculate_fruits_to_harvest() -> int:
	if not target_tree or not is_instance_valid(target_tree):
		return 0
	
	var available_fruits = 0
	if target_tree.has_method("get_ripe_count"):
		available_fruits = target_tree.get_ripe_count()
	
	var can_carry = max_carry_capacity - npc_carried_ripe_fruits
	
	# ⬅️ PERBAIKAN: Pastikan minimal 1 buah jika ada buah matang
	if available_fruits > 0 and can_carry == 0:
		return 1  # ⬅️ Tetap panen 1 buah meski kapasitas penuh (akan di-reset nanti)
	
	return min(available_fruits, can_carry)

func update_tree_cooldowns(delta: float):
	var trees_to_remove = []
	for tree in tree_cooldowns:
		if not is_instance_valid(tree):
			trees_to_remove.append(tree)
			continue
		
		tree_cooldowns[tree] -= delta
		if tree_cooldowns[tree] <= 0:
			trees_to_remove.append(tree)
	
	for tree in trees_to_remove:
		tree_cooldowns.erase(tree)
		if tree in visited_trees:
			visited_trees.erase(tree)

func smart_reset_visited_trees():
	var trees_to_keep: Array = []
	
	for tree in visited_trees:
		if not is_instance_valid(tree):
			continue
		
		if tree.has_method("has_ripe_fruits") and not tree.has_ripe_fruits():
			trees_to_keep.append(tree)
	
	visited_trees = trees_to_keep

func should_reset_visited_trees() -> bool:
	var all_trees = get_tree().get_nodes_in_group("tree")
	var available_trees = 0
	
	for tree in all_trees:
		if not is_instance_valid(tree):
			continue
		if tree in visited_trees:
			continue
		if tree.has_method("has_ripe_fruits") and tree.has_ripe_fruits():
			available_trees += 1
	
	return available_trees == 0 and visited_trees.size() > 0

func should_mark_tree_visited(tree: Node3D) -> bool:
	if not tree or not is_instance_valid(tree):
		return false
	
	if tree.has_method("has_ripe_fruits"):
		var has_ripe = tree.has_ripe_fruits()
		if not has_ripe:
			return true
		else:
			return false
	
	if tree.has_method("get_ripe_count"):
		var ripe_count = tree.get_ripe_count()
		if ripe_count == 0:
			return true
		else:
			return false
	
	return false

func mark_tree_visited(tree: Node3D):
	if tree in visited_trees:
		return
	
	visited_trees.append(tree)
	tree_cooldowns[tree] = TREE_COOLDOWN_TIME

func find_nearest_tree() -> Node3D:
	var trees = get_tree().get_nodes_in_group("tree")
	var nearest_tree: Node3D = null
	var nearest_distance = INF
	
	for tree in trees:
		if not is_instance_valid(tree):
			continue
		
		if tree in tree_cooldowns:
			continue
		
		if tree in visited_trees:
			continue
		
		if not tree.has_method("has_ripe_fruits") or not tree.has_ripe_fruits():
			if tree not in visited_trees and should_mark_tree_visited(tree):
				mark_tree_visited(tree)
			continue
		
		var distance = global_position.distance_to(tree.global_position)
		
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_tree = tree
	
	return nearest_tree

func move_towards_target(target_position: Vector3):
	var direction = (target_position - global_position).normalized()
	direction.y = 0
	
	velocity = direction * move_speed
	velocity.y = -9.8
	
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
	
	move_and_slide()

func initialize_npc():
	# ⬅️ TUNGGU SAMPAI PLAYER SIAP
	var player_ready = await wait_for_player_ready()
	if not player_ready:
		print("NPC: Player tidak ditemukan, tetap beroperasi dengan mode fallback")
		# Tetap lanjut meski player tidak ditemukan
		find_player_fallback()
	
	transition_to_state(NPCState.SEARCH)

# ⬅️ FUNGSI YANG DITAMBAHKAN: Fallback mechanism
func find_player_fallback():
	# Coba temukan player dengan metode lebih agresif
	var root = get_tree().root
	player_node = find_player_recursive_fallback(root)
	
	if player_node:
		print("NPC: Player ditemukan via fallback")
		camera_node = find_camera_recursive(player_node)
	else:
		print("NPC: Player tidak ditemukan sama sekali, NPC akan tetap beroperasi")

func wait_for_player_ready():
	var max_attempts = 30
	var attempt = 0
	
	while attempt < max_attempts:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			if is_player_ready(player):
				player_node = player
				if setup_camera_from_player(player):
					print("NPC: Player siap, mulai bekerja")
					return true
				else:
					print("NPC: Player ditemukan tapi kamera tidak")
			else:
				print("NPC: Player belum siap, attempt ", attempt)
		else:
			print("NPC: Player belum ditemukan, attempt ", attempt)
		
		attempt += 1
		await get_tree().create_timer(0.2).timeout
	
	print("NPC: Timeout menunggu player, menggunakan fallback")
	return false

# ⬅️ FUNGSI YANG DITAMBAHKAN: Setup camera dari player
func setup_camera_from_player(player: Node) -> bool:
	if player == null:
		return false
	
	var camera_paths = [
		"PlayerController/Camera3D",
		"Camera3D",
		"Head/Camera3D",
		"Camera",
		"../Camera3D"
	]
	
	for path in camera_paths:
		if player.has_node(path):
			camera_node = player.get_node(path)
			if camera_node and camera_node is Camera3D:
				return true
	
	camera_node = find_camera_recursive(player)
	return camera_node != null

func find_player_recursive_fallback(node: Node) -> Node:
	if node == null:
		return null
	
	# Kriteria lebih longgar untuk menemukan player
	if node.is_in_group("player"):
		return node
	if node.has_method("get_carried_ripe_fruits"):  # Method khas player
		return node
	if node is CharacterBody3D and node.name.to_lower().contains("player"):
		return node
	
	for child in node.get_children():
		var found = find_player_recursive_fallback(child)
		if found:
			return found
	
	return null

func is_player_ready(player: Node) -> bool:
	if player == null:
		return false
	
	# Kriteria lebih longgar
	if player.has_method("is_player_ready"):
		return player.is_player_ready()
	if player.has_method("get_initialization_status"):
		return player.get_initialization_status()
	if player.has_method("get_carried_ripe_fruits"):  # Jika player sudah punya method ini, artinya siap
		return true
	if player.is_inside_tree() and player.process_mode != PROCESS_MODE_DISABLED:
		return true
	
	return true

func find_player_and_camera():
	if not is_inside_tree():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
		if player_node.has_node("PlayerController/Camera3D"):
			camera_node = player_node.get_node("PlayerController/Camera3D")
		else:
			camera_node = find_camera_recursive(player_node)

func find_camera_recursive(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found = find_camera_recursive(child)
		if found:
			return found
	return null

func get_npc_carried_fruits() -> int:
	return npc_carried_ripe_fruits

func get_npc_carried_kg() -> int:
	return npc_carried_ripe_kg

func get_npc_capacity() -> int:
	return max_carry_capacity

func is_npc_full() -> bool:
	return npc_carried_ripe_fruits >= max_carry_capacity

func get_total_harvested() -> int:
	return total_harvested_by_npc
