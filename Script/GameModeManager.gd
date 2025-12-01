extends Node
class_name GameModeManager

const ROUND_DURATION: float = 120
var remaining_time: float = ROUND_DURATION
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

func start_round():
	remaining_time = ROUND_DURATION
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
	
	var ripe_income: int = delivered_ripe_kg * 2000
	var unripe_penalty: int = collected_unripe_kg * 500
	var npc_penalty: int = npc_stolen_kg * 500
	
	var final_score: int = ripe_income - (unripe_penalty + npc_penalty)
	
	var score_details = {
		"ripe_income": ripe_income,
		"unripe_penalty": unripe_penalty,
		"npc_penalty": npc_penalty,
		"delivered_ripe_kg": delivered_ripe_kg,
		"collected_unripe_kg": collected_unripe_kg,
		"npc_stolen_kg": npc_stolen_kg
	}
	
	round_ended_with_score.emit(final_score, score_details)

func get_remaining_time() -> float:
	return remaining_time

func is_round_running() -> bool:
	return is_round_active and remaining_time > 0
