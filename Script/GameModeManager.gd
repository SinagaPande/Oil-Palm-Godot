extends Node3D
class_name GameModeManager

# Variabel sentral konfigurasi - DITAMBAHKAN @export
@export var round_duration: float = 120.0
@export var player_speed_reduction_per_kg: float = 0.03

# Konfigurasi Harvester NPC
@export var max_npcs: int = 1
@export var npc_spawn_interval: float = 2
@export var npc_max_carry_capacity: int = 2
@export var npc_first_spawn_time: float = 5.0  # DITAMBAHKAN: Waktu spawn pertama NPC

# Konfigurasi WildBoar
@export var boar_detection_range: float = 20.0
@export var boar_move_speed: float = 8.0
@export var boar_attack_range: float = 2.5
@export var boar_attack_cooldown: float = 2.0
@export var max_wildboars: int = 1  # DITAMBAHKAN: Maksimal WildBoar
@export var boar_spawn_interval: float = 15.0  # DITAMBAHKAN: Interval spawn WildBoar
@export var boar_first_spawn_time: float = 30.0  # DITAMBAHKAN: Waktu spawn pertama WildBoar

# Konfigurasi Genangan (water pools) - SISTEM SPAWN AWAL
@export var water_pool_count: int = 5  # Jumlah genangan di awal game
@export var water_pool_scene: PackedScene = null  # Scene Genangan untuk di-spawn
@export var spawn_area_size: Vector3 = Vector3(50, 0, 50)  # Ukuran area spawn (X, Y, Z)
@export var min_spawn_distance_from_player: float = 10.0  # Jarak minimal dari player
@export var min_distance_between_pools: float = 5.0  # Jarak minimal antar genangan
@export var spawn_height_above_ground: float = 0.1  # Tinggi genangan di atas tanah
@export var raycast_start_height: float = 10.0  # Tinggi awal raycast dari atas
@export var max_spawn_attempts_per_pool: int = 30  # Maksimal percobaan spawn per genangan

# Harga yang bisa diatur dari inspector - DITAMBAHKAN
@export var ripe_fruit_price: int = 2000
@export var unripe_fruit_penalty: int = 500
@export var npc_stolen_penalty: int = 500

var remaining_time: float = round_duration
var is_round_active: bool = false

var inventory_system: InventorySystem
var npc_manager: NPCManager
var ui_manager: UIManager

# Variabel untuk manajemen genangan
var water_pool_container: Node3D  # Container untuk genangan
var current_water_pools: Array = []  # Array untuk menyimpan referensi genangan yang aktif

signal game_time_updated(remaining_time)
signal round_ended_with_score(final_score, score_details)
signal round_started()

func _ready():
	add_to_group("game_mode_manager")
	call_deferred("initialize_systems")

func initialize_systems():
	find_systems()
	await get_tree().process_frame
	apply_config_to_systems()
	initialize_water_pool_system()  # Inisialisasi sistem genangan
	start_round()

func find_systems():
	var attempts = 0
	while attempts < 5 and (not inventory_system or not npc_manager):
		inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
		if not inventory_system:
			var inventory_nodes = get_tree().get_nodes_in_group("inventory_system")
			if inventory_nodes.size() > 0:
				inventory_system = inventory_nodes[0]
		
		npc_manager = get_node_or_null("/root/Node3D/NPCManager")
		if not npc_manager:
			var npc_managers = get_tree().get_nodes_in_group("npc_manager")
			if npc_managers.size() > 0:
				npc_manager = npc_managers[0]
		
		attempts += 1
		if not inventory_system or not npc_manager:
			await get_tree().create_timer(0.1).timeout
	
	ui_manager = get_node_or_null("/root/Node3D/UIManager")
	if not ui_manager:
		var ui_managers = get_tree().get_nodes_in_group("ui_manager")
		if ui_managers.size() > 0:
			ui_manager = ui_managers[0]

func apply_config_to_systems():
	# Konfigurasi Player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.has_method("set_speed_reduction_factor"):
			player.set_speed_reduction_factor(player_speed_reduction_per_kg)
	
	# Konfigurasi NPCManager dengan semua parameter baru
	if npc_manager:
		if npc_manager.has_method("set_max_npcs"):
			npc_manager.set_max_npcs(max_npcs)
		if npc_manager.has_method("set_spawn_interval"):
			npc_manager.set_spawn_interval(npc_spawn_interval)
		if npc_manager.has_method("set_npc_carry_capacity"):
			npc_manager.set_npc_carry_capacity(npc_max_carry_capacity)
		if npc_manager.has_method("set_npc_first_spawn_time"):
			npc_manager.set_npc_first_spawn_time(npc_first_spawn_time)
		
		# DITAMBAHKAN: Konfigurasi WildBoar
		if npc_manager.has_method("set_max_wildboars"):
			npc_manager.set_max_wildboars(max_wildboars)
		if npc_manager.has_method("set_boar_spawn_interval"):
			npc_manager.set_boar_spawn_interval(boar_spawn_interval)
		if npc_manager.has_method("set_boar_first_spawn_time"):
			npc_manager.set_boar_first_spawn_time(boar_first_spawn_time)
	
	# Konfigurasi semua WildBoar yang sudah ada
	var wild_boars = get_tree().get_nodes_in_group("wild_boar")
	for boar in wild_boars:
		if boar.has_method("set_stats"):
			boar.set_stats(boar_detection_range, boar_move_speed, boar_attack_range, boar_attack_cooldown)
	
	print("Konfigurasi level diterapkan dari GameModeManager")
	print("Round Duration: ", round_duration)
	print("Max NPCs: ", max_npcs, " | NPC Spawn Interval: ", npc_spawn_interval, " | First Spawn: ", npc_first_spawn_time)
	print("Max WildBoars: ", max_wildboars, " | Boar Spawn Interval: ", boar_spawn_interval, " | First Spawn: ", boar_first_spawn_time)
	print("Boar Speed: ", boar_move_speed)
	print("Water Pool Count: ", water_pool_count, " | Spawn Area: ", spawn_area_size)
	print("Ripe Price: Rp ", ripe_fruit_price)
	print("Penalties: Rp ", unripe_fruit_penalty, " (unripe), Rp ", npc_stolen_penalty, " (stolen)")

func initialize_water_pool_system():
	# Buat node container untuk genangan jika belum ada
	if not has_node("WaterPoolsContainer"):
		water_pool_container = Node3D.new()
		water_pool_container.name = "WaterPoolsContainer"
		add_child(water_pool_container)
		print("WaterPoolsContainer dibuat")
	else:
		water_pool_container = get_node("WaterPoolsContainer")
	
	# Reset array tracking
	current_water_pools.clear()
	
	print("Sistem genangan diinisialisasi")

func start_round():
	remaining_time = round_duration
	is_round_active = true
	
	# Bersihkan genangan yang ada dari ronde sebelumnya
	cleanup_existing_water_pools()
	
	# SPAWN SEMUA GENANGAN DI AWAL ROUND (seperti spawn pohon)
	spawn_all_water_pools_at_start()
	
	round_started.emit()
	game_time_updated.emit(remaining_time)

func spawn_all_water_pools_at_start():
	print("Memulai spawn genangan di awal round...")
	
	if not water_pool_scene:
		print("Peringatan: water_pool_scene tidak di-set di GameModeManager")
		return
	
	var successful_spawns = 0
	var failed_spawns = 0
	
	for i in range(water_pool_count):
		var spawn_success = try_spawn_single_water_pool()
		if spawn_success:
			successful_spawns += 1
		else:
			failed_spawns += 1
	
	print("Spawn genangan selesai: ", successful_spawns, " berhasil, ", failed_spawns, " gagal")
	print("Total genangan aktif: ", current_water_pools.size())

func try_spawn_single_water_pool() -> bool:
	# Dapatkan posisi spawn yang valid
	var spawn_position = find_valid_spawn_position_for_pool()
	if spawn_position == Vector3.ZERO:
		return false
	
	# Instantiate genangan baru
	var new_water_pool_instance = water_pool_scene.instantiate()
	water_pool_container.add_child(new_water_pool_instance)
	
	# Atur posisi genangan
	new_water_pool_instance.global_position = spawn_position
	
	# Tambahkan ke array tracking
	current_water_pools.append(new_water_pool_instance)
	
	return true

func find_valid_spawn_position_for_pool() -> Vector3:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		print("Tidak ada player ditemukan untuk validasi posisi spawn")
		return Vector3.ZERO
	
	var player = players[0]
	var player_position = player.global_position
	
	var attempts = 0
	
	while attempts < max_spawn_attempts_per_pool:
		# Generate posisi acak dalam area spawn
		var random_offset = Vector3(
			randf_range(-spawn_area_size.x / 2, spawn_area_size.x / 2),
			0,  # Y akan disesuaikan dengan raycast
			randf_range(-spawn_area_size.z / 2, spawn_area_size.z / 2)
		)
		
		# Tambahkan offset dari posisi GameModeManager
		var final_position = global_position + random_offset
		
		# Cek jarak dari player
		var distance_to_player = final_position.distance_to(player_position)
		if distance_to_player < min_spawn_distance_from_player:
			attempts += 1
			continue
		
		# Cek jarak dari genangan lain yang sudah ada
		var too_close_to_other_pool = false
		for existing_pool in current_water_pools:
			if is_instance_valid(existing_pool):
				var distance_to_existing = final_position.distance_to(existing_pool.global_position)
				if distance_to_existing < min_distance_between_pools:
					too_close_to_other_pool = true
					break
		
		if too_close_to_other_pool:
			attempts += 1
			continue
		
		# Lakukan raycast untuk cek jika posisi valid (di atas tanah)
		var space_state = get_world_3d().direct_space_state
		var ray_start = final_position + Vector3(0, raycast_start_height, 0)
		var ray_end = final_position - Vector3(0, 100, 0)
		
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collision_mask = 1  # Layer default
		query.exclude = [player]  # Exclude player dari raycast
		
		var result = space_state.intersect_ray(query)
		if result:
			# Gunakan posisi hasil raycast (di atas tanah)
			var ground_position = result.position
			return ground_position + Vector3(0, spawn_height_above_ground, 0)
		
		attempts += 1
	
	# print("Gagal menemukan posisi spawn yang valid setelah ", max_spawn_attempts_per_pool, " percobaan")
	return Vector3.ZERO

func _process(delta):
	if not is_round_active:
		return
	
	if get_tree().paused:
		return
	
	remaining_time -= delta
	
	if int(remaining_time) != int(remaining_time + delta):
		game_time_updated.emit(remaining_time)
	
	if remaining_time <= 0:
		remaining_time = 0
		end_round_and_calculate_score()

func cleanup_existing_water_pools():
	# Hapus semua genangan yang ada
	for water_pool in current_water_pools:
		if is_instance_valid(water_pool):
			water_pool.queue_free()
	
	current_water_pools.clear()
	print("Semua genangan dibersihkan")

func _on_water_pool_destroyed(water_pool: Node):
	# Hapus dari array tracking jika genangan dihancurkan
	if current_water_pools.has(water_pool):
		current_water_pools.erase(water_pool)
		print("Genangan dihapus dari tracking. Total: ", current_water_pools.size())

func end_round_and_calculate_score():
	if not is_round_active:
		return
	
	is_round_active = false
	
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	calculate_final_score()

func calculate_final_score():
	var delivered_ripe_kg: int = 0
	var collected_unripe_kg: int = 0
	var npc_stolen_kg: int = 0
	
	if inventory_system:
		if inventory_system.has_method("get_delivered_ripe_kg"):
			delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		if inventory_system.has_method("get_collected_unripe_kg"):
			collected_unripe_kg = inventory_system.get_collected_unripe_kg()
	
	if npc_manager:
		if npc_manager.has_method("get_total_npc_harvest"):
			npc_stolen_kg = npc_manager.get_total_npc_harvest()
	
	# Menggunakan variabel dari inspector - DIPERBAHARUI
	var ripe_income: int = delivered_ripe_kg * ripe_fruit_price
	var unripe_penalty: int = collected_unripe_kg * unripe_fruit_penalty
	var npc_penalty: int = npc_stolen_kg * npc_stolen_penalty
	
	var final_score: int = ripe_income - (unripe_penalty + npc_penalty)
	
	var score_details = {
		"ripe_income": ripe_income,
		"unripe_penalty": unripe_penalty,
		"npc_penalty": npc_penalty,
		"delivered_ripe_kg": delivered_ripe_kg,
		"collected_unripe_kg": collected_unripe_kg,
		"npc_stolen_kg": npc_stolen_kg,
		# Tambahkan informasi harga untuk UI - DITAMBAHKAN
		"ripe_fruit_price": ripe_fruit_price,
		"unripe_fruit_penalty": unripe_fruit_penalty,
		"npc_stolen_penalty": npc_stolen_penalty
	}
	
	round_ended_with_score.emit(final_score, score_details)

func get_remaining_time() -> float:
	return remaining_time

func is_round_running() -> bool:
	return is_round_active and remaining_time > 0
