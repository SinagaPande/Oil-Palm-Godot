extends Node
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

# Harga yang bisa diatur dari inspector - DITAMBAHKAN
@export var ripe_fruit_price: int = 2000
@export var unripe_fruit_penalty: int = 500
@export var npc_stolen_penalty: int = 500

var remaining_time: float = round_duration
var is_round_active: bool = false

var inventory_system: InventorySystem
var npc_manager: NPCManager
var ui_manager: UIManager

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
	print("Ripe Price: Rp ", ripe_fruit_price)
	print("Penalties: Rp ", unripe_fruit_penalty, " (unripe), Rp ", npc_stolen_penalty, " (stolen)")

func start_round():
	remaining_time = round_duration
	is_round_active = true
	
	round_started.emit()
	game_time_updated.emit(remaining_time)

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
