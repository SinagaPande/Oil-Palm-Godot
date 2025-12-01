extends CharacterBody3D
class_name HarvesterNPC

enum NPCState {
	SPAWN,
	SEARCH, 
	MOVE,
	HARVEST,
	IDLE,
	RETURN_TO_SPAWN
}

@export var animation_player: AnimationPlayer
var egrek_model: Node3D = null
var is_harvesting: bool = false

# ⬅️ VARIABLE BARU: Untuk anti-stuck mechanism
var nearest_spawn_point: Marker3D = null
var stuck_timer: float = 0.0
var stuck_check_position: Vector3 = Vector3.ZERO
const STUCK_THRESHOLD: float = 3.0  # Detik
const MIN_MOVEMENT_DISTANCE: float = 0.5  # Meter

# ⬅️ VARIABLE BARU: Untuk mencegah double destroy
var is_destroyed: bool = false

@export var move_speed: float = 3.0
@export var harvest_range: float = 2.0
@export var search_radius: float = 15.0
@export var max_carry_capacity: int = 2

var current_state: NPCState = NPCState.SPAWN
var target_tree: Node3D = null
var harvest_timer: float = 0.0
var harvest_delay_per_fruit: float = 2.0
var fruits_to_harvest: int = 0
var current_harvest_count: int = 0

# Inventory NPC
var npc_carried_ripe_fruits: int = 0
var total_harvested_by_npc: int = 0
var npc_carried_ripe_kg: int = 0

var visited_trees: Array = []
var search_attempts: int = 0
const MAX_SEARCH_ATTEMPTS: int = 15

var tree_cooldowns: Dictionary = {}
const TREE_COOLDOWN_TIME: float = 10.0

# Tracking buah yang sedang diproses
var current_harvesting_fruits: Array = []
var harvest_progress_timer: float = 0.0

# Signals
signal npc_harvested_fruits(harvested_count, total_harvested)
signal npc_returned_to_spawn(npc_instance)

# Collision configuration
var collision_shape: CollisionShape3D = null

func _ready():
	add_to_group("harvester_npc")
	setup_collision_config()
	
	# Auto-find AnimationPlayer jika belum terhubung
	if not animation_player:
		find_animation_player_auto()
	
	# ⬅️ CARI MODEL EGREK SECARA OTOMATIS
	find_egrek_model_auto()
	
	call_deferred("delayed_initialize")

func delayed_initialize():
	await get_tree().process_frame
	
	# ⬅️ PERBAIKAN: Pastikan posisi Y konsisten
	var current_pos = global_position
	global_position = Vector3(current_pos.x, 0, current_pos.z)
	
	initialize_npc()
	
# ⬅️ FUNGSI BARU: Cari model egrek secara otomatis
func find_egrek_model_auto():
	# Method 1: Cari node dengan nama mengandung "egrek"
	egrek_model = find_child("*Egrek*", true, false)
	
	# Method 2: Jika tidak ketemu, cari di dalam node Maling
	if not egrek_model:
		var maling_node = find_child("Maling", true, false)
		if maling_node:
			# Cari semua MeshInstance3D di dalam Maling
			var mesh_instances = find_all_mesh_instances_recursive(maling_node)
			for mesh in mesh_instances:
				# Cek nama mesh untuk identifikasi egrek
				var mesh_name = mesh.name.to_lower()
				if "Egrek" in mesh_name or "tool" in mesh_name or "weapon" in mesh_name:
					egrek_model = mesh
					break
	
	if egrek_model:
		print("NPC: Auto-found egrek model: ", egrek_model.name)
		# ⬅️ PASTIKAN EGREK AWALNYA TIDAK TERLIHAT
		egrek_model.visible = false
	else:
		print("NPC: WARNING - Cannot find egrek model automatically")

# ⬅️ FUNGSI BARU: Cari semua MeshInstance3D secara recursive
func find_all_mesh_instances_recursive(node: Node) -> Array:
	var meshes = []
	
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		# Cari juga di child lebih dalam
		meshes.append_array(find_all_mesh_instances_recursive(child))
	
	return meshes

func setup_collision_config():
	collision_shape = find_child("CollisionShape3D")
	if collision_shape:
		collision_mask = 0x00000001
		set_collision_layer_value(2, false)
		set_collision_layer_value(3, false)
		set_collision_layer_value(4, false)
		set_collision_layer_value(5, false)
		
		if collision_shape.shape is CapsuleShape3D or collision_shape.shape is SphereShape3D:
			collision_shape.shape.radius *= 0.8
			
func play_animation(anim_name: String):
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	
	# ⬅️ KONTROL VISIBILITY EGREK BERDASARKAN ANIMASI
	update_egrek_visibility(anim_name)

func update_egrek_visibility(anim_name: String):
	if not egrek_model:
		return
	
	# Tampilkan egrek hanya saat animasi "Panen"
	if anim_name == "Panen":
		egrek_model.visible = true
		is_harvesting = true
	else:
		egrek_model.visible = false
		is_harvesting = false

func _physics_process(delta):
	if get_tree().paused:
		return
	
	state_process(delta)
	update_tree_cooldowns(delta)

func state_process(delta):
	if get_tree().paused:
		return
	
	match current_state:
		NPCState.SPAWN:
			pass
			
		NPCState.SEARCH:
			# Cek kapasitas sebelum mencari pohon
			if npc_carried_ripe_fruits >= max_carry_capacity:
				print("NPC: Kapasitas penuh (%d/%d), mencari spawn point" % [npc_carried_ripe_fruits, max_carry_capacity])
				transition_to_state(NPCState.RETURN_TO_SPAWN)
				return
				
			var nearest_tree = find_nearest_tree()
			if nearest_tree:
				target_tree = nearest_tree
				transition_to_state(NPCState.MOVE)
			else:
				if npc_carried_ripe_fruits > 0:
					transition_to_state(NPCState.RETURN_TO_SPAWN)
				else:
					transition_to_state(NPCState.IDLE)
			
		NPCState.MOVE:
			if target_tree and is_instance_valid(target_tree):
				move_towards_target(target_tree.global_position)
				check_if_stuck(delta)
				
				var distance_to_tree = global_position.distance_to(target_tree.global_position)
				if distance_to_tree <= harvest_range:
					transition_to_state(NPCState.HARVEST)
			else:
				target_tree = null
				transition_to_state(NPCState.SEARCH)
			
		NPCState.HARVEST:
			harvest_timer += delta
			harvest_progress_timer += delta
			
			# PROSES HARVEST SATU PER SATU
			if harvest_progress_timer >= harvest_delay_per_fruit and current_harvesting_fruits.size() > 0:
				harvest_progress_timer = 0.0
				harvest_single_fruit()
			
			# Cek apakah harvest sudah selesai atau kapasitas penuh
			if current_harvest_count >= fruits_to_harvest or npc_carried_ripe_fruits >= max_carry_capacity:
				if target_tree and should_mark_tree_visited(target_tree):
					mark_tree_visited(target_tree)
				
				# ⬅️ MODIFIKASI: Langsung kembali ke spawn point setelah kapasitas penuh
				if npc_carried_ripe_fruits >= max_carry_capacity:
					print("NPC: Kapasitas tercapai (%d/%d), langsung kembali ke spawn point" % [npc_carried_ripe_fruits, max_carry_capacity])
					transition_to_state(NPCState.RETURN_TO_SPAWN)
				else:
					transition_to_state(NPCState.SEARCH)
			
		NPCState.IDLE:
			harvest_timer += delta
			if harvest_timer >= 3.0:
				harvest_timer = 0.0
				transition_to_state(NPCState.SEARCH)
		
		NPCState.RETURN_TO_SPAWN:
			if nearest_spawn_point and is_instance_valid(nearest_spawn_point):
				move_towards_target(nearest_spawn_point.global_position)
				check_if_stuck(delta)
				
				var distance_to_spawn = global_position.distance_to(nearest_spawn_point.global_position)
				
				# ⬅️ PERBAIKAN: Debug info yang lebih informatif
				if Engine.get_frames_drawn() % 60 == 0:
					print("NPC: Menuju spawn point '%s'" % nearest_spawn_point.name)
					print("  Posisi NPC: %s" % global_position)
					print("  Posisi Spawn: %s" % nearest_spawn_point.global_position)
					print("  Jarak: %.1f unit, Kecepatan: %.1f" % [distance_to_spawn, velocity.length()])
				
				# ⬅️ PERBAIKAN: Threshold yang lebih realistis
				if distance_to_spawn <= 1.5:  # Kurangi dari 2.0 ke 1.5
					print("NPC: Sampai di spawn point '%s', menghilang dengan %d buah" % [nearest_spawn_point.name, npc_carried_ripe_fruits])
					destroy_npc()
				elif stuck_timer >= STUCK_THRESHOLD:
					print("NPC: Terjebak selama %.1f detik, teleport ke spawn point" % stuck_timer)
					# ⬅️ PERBAIKAN: Pastikan posisi Y konsisten saat teleport
					var spawn_pos = nearest_spawn_point.global_position
					global_position = Vector3(spawn_pos.x, global_position.y, spawn_pos.z)
					destroy_npc()
			else:
				# Jika tidak ada spawn point, cari lagi atau langsung destroy
				print("NPC: Spawn point tidak valid, mencari yang baru...")
				nearest_spawn_point = find_nearest_spawn_point()
				if not nearest_spawn_point:
					print("NPC: Tidak ada spawn point yang ditemukan, menghilang")
					destroy_npc()

# ⬅️ FUNGSI BARU: Anti-stuck mechanism - DIPERBAIKI
func check_if_stuck(delta: float):
	var current_pos = global_position
	var distance_moved = current_pos.distance_to(stuck_check_position)
	
	# ⬅️ MODIFIKASI: Hanya anggap stuck jika benar-benar tidak bergerak
	if distance_moved < MIN_MOVEMENT_DISTANCE and velocity.length() < 0.1:  # ⬅️ TAMBAH cek velocity
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		stuck_check_position = current_pos
	
	# Jika terjebak lebih dari threshold, coba atasi
	if stuck_timer >= STUCK_THRESHOLD:
		handle_stuck_situation()

# ⬅️ FUNGSI BARU: Handle stuck situation - DIPERBAIKI
func handle_stuck_situation():
	print("NPC: Terdeteksi terjebak selama %.1f detik, kecepatan: %.1f" % [stuck_timer, velocity.length()])  # ⬅️ TAMBAH info velocity
	
	match current_state:
		NPCState.RETURN_TO_SPAWN:
			if nearest_spawn_point and is_instance_valid(nearest_spawn_point):
				print("NPC: Teleport ke spawn point karena terjebak")
				global_position = nearest_spawn_point.global_position
				destroy_npc()
			else:
				print("NPC: Tidak ada spawn point, langsung menghilang")
				destroy_npc()
		
		NPCState.MOVE:
			if target_tree and is_instance_valid(target_tree):
				print("NPC: Coba reset movement ke pohon")
				stuck_timer = 0.0
				stuck_check_position = global_position
				# ⬅️ TAMBAHAN: Coba path alternatif dengan random offset
				var random_offset = Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
				global_position += random_offset
			else:
				print("NPC: Target tree hilang, kembali search")
				target_tree = null
				transition_to_state(NPCState.SEARCH)

# ⬅️ MODIFIKASI: Fungsi destroy_npc dengan protection double destroy
func destroy_npc():
	if is_destroyed:
		return
	
	is_destroyed = true
	
	# Kirim signal ke NPCManager bahwa NPC sudah kembali
	npc_returned_to_spawn.emit(self)
	
	print("NPC: Menghilang dengan membawa %d buah (total dipanen: %d kg)" % [npc_carried_ripe_fruits, total_harvested_by_npc])
	
	# Hapus NPC dari scene
	queue_free()

func harvest_single_fruit():
	# Cek kapasitas sebelum memanen
	if npc_carried_ripe_fruits >= max_carry_capacity:
		print("NPC: Kapasitas penuh, berhenti memanen")
		return
	
	if current_harvesting_fruits.size() == 0:
		return
		
	if egrek_model:
		egrek_model.visible = true
		
	play_animation("Panen")
	
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
		
		# ⬅️ PERBAIKAN: Signal hanya kirim INCREMENT, bukan total
		npc_harvested_fruits.emit(harvested_kg)  # Hanya kirim berat buah ini saja
		
		print("NPC memanen 1 buah matang (%d kg). Total dipanen: %d kg, Kapasitas: %d/%d" % [harvested_kg, total_harvested_by_npc, npc_carried_ripe_fruits, max_carry_capacity])
		
		# ⬅️ MODIFIKASI: Langsung kembali ke spawn jika kapasitas penuh setelah panen
		if npc_carried_ripe_fruits >= max_carry_capacity:
			print("NPC: Kapasitas maksimum tercapai! Langsung kembali ke spawn point")
			transition_to_state(NPCState.RETURN_TO_SPAWN)

func transition_to_state(new_state: NPCState):
	if get_tree().paused:
		return
	
	state_exit(current_state)
	current_state = new_state
	state_enter(new_state)
	
	# ⬅️ RESET STUCK TIMER SETIAP STATE BERUBAH
	stuck_timer = 0.0
	stuck_check_position = global_position

func state_enter(state: NPCState):
	match state:
		NPCState.SPAWN:
			play_animation("Jalan")  # ⬅️ TAMBAH INI
			
		NPCState.SEARCH:
			play_animation("Jalan")  # ⬅️ TAMBAH INI
			search_attempts += 1
			if search_attempts >= MAX_SEARCH_ATTEMPTS:
				visited_trees.clear()
				search_attempts = 0
			
		NPCState.MOVE:
			play_animation("Jalan")  # ⬅️ TAMBAH INI
			
		NPCState.HARVEST:
			play_animation("Panen")
			# Cek kapasitas sebelum mulai harvest
			if npc_carried_ripe_fruits >= max_carry_capacity:
				print("NPC: Kapasitas penuh, langsung kembali ke spawn point")
				transition_to_state(NPCState.RETURN_TO_SPAWN)
				return
				
			if target_tree and is_instance_valid(target_tree):
				if target_tree.has_method("set_harvesting_mode_active"):
					target_tree.set_harvesting_mode_active(true)
				
				fruits_to_harvest = calculate_fruits_to_harvest()
				
				# Cek apakah ada buah yang bisa dipanen
				if fruits_to_harvest <= 0:
					print("NPC: Tidak ada buah yang bisa dipanen")
					transition_to_state(NPCState.SEARCH)
					return
				
				current_harvest_count = 0
				harvest_timer = 0.0
				harvest_progress_timer = 0.0
				
				current_harvesting_fruits = get_ripe_fruits_from_tree(target_tree)
				
				if fruits_to_harvest > 0 and current_harvesting_fruits.size() > 0:
					var max_fruits_to_take = min(fruits_to_harvest, current_harvesting_fruits.size())
					if max_fruits_to_take < current_harvesting_fruits.size():
						current_harvesting_fruits = current_harvesting_fruits.slice(0, max_fruits_to_take)
					
					print("NPC mulai memanen %d buah matang" % current_harvesting_fruits.size())
				else:
					transition_to_state(NPCState.SEARCH)
			else:
				transition_to_state(NPCState.SEARCH)
			
		NPCState.IDLE:
			play_animation("Jalan")  # ⬅️ TAMBAH INI
			
		NPCState.RETURN_TO_SPAWN:
			play_animation("Jalan")  # ⬅️ TAMBAH INI
			print("NPC: Mencari spawn point terdekat...")
			nearest_spawn_point = find_nearest_spawn_point()
			if nearest_spawn_point:
				print("NPC: Menemukan spawn point '%s' di posisi %s" % [nearest_spawn_point.name, nearest_spawn_point.global_position])
				print("NPC: Posisi saat ini: %s" % global_position)
				var initial_distance = global_position.distance_to(nearest_spawn_point.global_position)
				print("NPC: Jarak awal: %.1f unit" % initial_distance)
			else:
				print("NPC: Tidak ada spawn point yang ditemukan, menghilang")
				destroy_npc()

func state_exit(state: NPCState):
	if get_tree().paused:
		return
	
	match state:
		NPCState.HARVEST:
			# Kembali ke animasi jalan setelah selesai panen
			play_animation("Jalan")
			if target_tree and is_instance_valid(target_tree) and target_tree.has_method("set_harvesting_mode_active"):
				target_tree.set_harvesting_mode_active(false)
			current_harvesting_fruits.clear()
			
			# ⬅️ PASTIKAN EGREK TIDAK TERLIHAT SETELAH PANEN SELESAI
			if egrek_model:
				egrek_model.visible = false
				is_harvesting = false
			
func find_animation_player_auto():
	# Method 1: Cari langsung
	animation_player = find_child("AnimationPlayer", true, false)
	
	# Method 2: Jika tidak ketemu, cari di dalam Maling
	if not animation_player:
		var maling_node = find_child("Maling", true, false)
		if maling_node:
			animation_player = maling_node.find_child("AnimationPlayer", true, false)
	
	if animation_player:
		print("NPC: Auto-found AnimationPlayer: ", animation_player.name)
		print("NPC: Animations: ", animation_player.get_animation_list())
		
		# AUTO-CONFIGURE LOOP FOR WALK ANIMATION
		if animation_player.has_animation("Jalan"):
			var walk_anim = animation_player.get_animation("Jalan")
			walk_anim.loop_mode = Animation.LOOP_LINEAR
			print("NPC: Set Jalan animation to LOOP")
		
		# ⬅️ MODIFIKASI: Animasi Panen TIDAK looping karena diputar sekali per buah
		if animation_player.has_animation("Panen"):
			var harvest_anim = animation_player.get_animation("Panen")
			harvest_anim.loop_mode = Animation.LOOP_NONE  # ⬅️ TIDAK LOOPING
			print("NPC: Set Panen animation to NO LOOP (play once per fruit)")
	else:
		print("NPC: ERROR - Cannot find AnimationPlayer automatically")

# ⬅️ FUNGSI: Cari spawn point terdekat
func find_nearest_spawn_point() -> Marker3D:
	var spawn_points = get_tree().get_nodes_in_group("npc_spawn")
	var nearest_spawn: Marker3D = null
	var nearest_distance = INF
	
	for spawn_point in spawn_points:
		if not is_instance_valid(spawn_point):
			continue
		
		# ⬅️ PERBAIKAN: Pastikan spawn point punya posisi valid
		if spawn_point.global_position == Vector3.ZERO:
			continue
			
		var distance = global_position.distance_to(spawn_point.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_spawn = spawn_point
	
	if nearest_spawn:
		print("NPC: Spawn point terdekat: '%s' (%.1f unit)" % [nearest_spawn.name, nearest_distance])
	else:
		print("NPC: WARNING - Tidak ada spawn point yang valid!")
	
	return nearest_spawn

func move_towards_target(target_position: Vector3):
	if get_tree().paused:
		return
	
	# ⬅️ PERBAIKAN: Debug lebih detail
	var current_pos = global_position
	var target_pos_flat = Vector3(target_position.x, current_pos.y, target_position.z)
	
	# Hitung arah dan jarak sebenarnya
	var direction = (target_pos_flat - current_pos).normalized()
	var actual_distance = current_pos.distance_to(target_pos_flat)
	
	# ⬅️ DEBUG: Tampilkan info movement detail
	if Engine.get_frames_drawn() % 30 == 0 and current_state == NPCState.RETURN_TO_SPAWN:
		print("NPC Movement Debug:")
		print("  Posisi NPC: %s" % current_pos)
		print("  Target: %s" % target_pos_flat)
		print("  Arah: %s" % direction)
		print("  Jarak: %.1f" % actual_distance)
		print("  Kecepatan: %.1f" % move_speed)
	
	# ⬅️ PERBAIKAN: Pastikan arah valid sebelum bergerak
	if direction.length() > 0.1 and actual_distance > 0.5:
		velocity = direction * move_speed
		velocity.y = 0
		
		# Rotasi hanya jika bergerak cukup cepat
		if velocity.length() > 0.5:
			look_at(global_position + direction, Vector3.UP)
	else:
		velocity = Vector3.ZERO
	
	move_and_slide()

# ⬅️ PERBAIKAN: Fungsi calculate_fruits_to_harvest yang benar
func calculate_fruits_to_harvest() -> int:
	if not target_tree or not is_instance_valid(target_tree):
		return 0
	
	# ⬅️ PERBAIKAN KRITIS: Jangan panen jika kapasitas sudah penuh
	if npc_carried_ripe_fruits >= max_carry_capacity:
		print("NPC: Kapasitas sudah penuh (%d/%d), tidak bisa panen lagi" % [npc_carried_ripe_fruits, max_carry_capacity])
		return 0
	
	var available_fruits = 0
	if target_tree.has_method("get_ripe_count"):
		available_fruits = target_tree.get_ripe_count()
	
	var can_carry = max_carry_capacity - npc_carried_ripe_fruits
	
	# ⬅️ PERBAIKAN: Pastikan tidak memanen jika kapasitas 0
	if can_carry <= 0:
		return 0
	
	var fruits_to_take = min(available_fruits, can_carry)
	print("NPC: Bisa memanen %d buah (tersedia: %d, kapasitas: %d/%d)" % [fruits_to_take, available_fruits, npc_carried_ripe_fruits, max_carry_capacity])
	
	return fruits_to_take

# ⬅️ TAMBAHKAN FUNGSI YANG HILANG: initialize_npc
func initialize_npc():
	# Simplifikasi total
	await get_tree().create_timer(0.5).timeout  # Delay kecil
	transition_to_state(NPCState.SEARCH)
	

# ⬅️ TAMBAHKAN FUNGSI YANG HILANG: get_ripe_fruits_from_tree
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

# ⬅️ TAMBAHKAN FUNGSI YANG HILANG: wait_for_player_ready
func wait_for_player_ready():
	var max_attempts = 30
	var attempt = 0
	
	while attempt < max_attempts:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			if is_player_ready(player):
				# Player ditemukan dan siap, tapi tidak perlu simpan reference
				print("NPC: Player siap, mulai bekerja")
				return true
			else:
				print("NPC: Player belum siap, attempt ", attempt)
		else:
			print("NPC: Player belum ditemukan, attempt ", attempt)
		
		attempt += 1
		await get_tree().create_timer(0.2).timeout
	
	print("NPC: Timeout menunggu player, menggunakan fallback")
	return false

# ⬅️ TAMBAHKAN FUNGSI YANG HILANG: find_player_fallback
func find_player_fallback():
	# Coba temukan player dengan metode lebih agresif
	var root = get_tree().root
	var player_node = find_player_recursive_fallback(root)
	
	if player_node:
		print("NPC: Player ditemukan via fallback")
	else:
		print("NPC: Player tidak ditemukan sama sekali, NPC akan tetap beroperasi")

# ⬅️ TAMBAHKAN FUNGSI YANG HILANG: find_player_recursive_fallback
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

# ⬅️ TAMBAHKAN FUNGSI YANG HILANG: is_player_ready
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

# ⬅️ TAMBAHKAN FUNGSI YANG HILANG: Inventory getters
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

# ... (FUNGSI LAINNYA YANG SUDAH ADA)
func update_tree_cooldowns(delta: float):
	if get_tree().paused:
		return
	
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
	if get_tree().paused:
		return null
	
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
