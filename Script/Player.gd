extends CharacterBody3D

class_name Player

@onready var player_controller = $PlayerController
@onready var interaction_system = $InteractionSystem
@onready var camera = $PlayerController/Camera3D
@onready var egrek = $PlayerController/Camera3D/Egrek

signal carried_fruits_updated(ripe_count)
signal player_fully_ready
signal hp_updated(current_hp, max_hp)
signal player_died

var carried_ripe_fruits: int = 0
var in_delivery_zone: bool = false
var current_delivery_zone: DeliveryZone = null
var inventory_system: Node

const BASE_SPEED = 7
const SPEED_REDUCTION_PER_FRUIT = 0.5

const MAX_HP = 100  # HP maksimal player
const DAMAGE_PER_ATTACK = 10  # Damage yang diterima per serangan NPC

var current_hp: int = MAX_HP
var is_dead: bool = false

var is_fully_initialized: bool = false

func _ready():
	add_to_group("player")
	setup_components()
	
	if player_controller:
		player_controller.set_current_speed(BASE_SPEED)
	
	find_inventory_system()
	
	await get_tree().process_frame
	is_fully_initialized = true
	current_hp = MAX_HP
	hp_updated.emit(current_hp, MAX_HP)
	player_fully_ready.emit()

func get_base_speed() -> float:
	return BASE_SPEED

func setup_components():
	if player_controller:
		player_controller.player_body = self
		player_controller.camera_node = camera
		player_controller.egrek_node = egrek
	
	if interaction_system:
		interaction_system.camera = camera
		interaction_system.player_controller = player_controller
		
		var interaction_label = interaction_system.get_node_or_null("CanvasLayer/UI_Container/InteractionLabel")
		if interaction_label:
			interaction_system.interaction_label = interaction_label

func find_inventory_system():
	var paths_to_try = [
		"/root/Node3D/InventorySystem",
		"/root/Level/InventorySystem", 
		"../InventorySystem",
		"../../InventorySystem"
	]
	
	for path in paths_to_try:
		var node = get_node_or_null(path)
		if node and node.has_method("add_unripe_fruit_direct"):
			inventory_system = node
			return
	
	var nodes = get_tree().get_nodes_in_group("inventory_system")
	if nodes.size() > 0:
		inventory_system = nodes[0]

func set_in_delivery_zone(is_in_zone: bool, zone: DeliveryZone):
	in_delivery_zone = is_in_zone
	current_delivery_zone = zone

func add_to_inventory(fruit_type: String):
	if fruit_type == "Masak":
		carried_ripe_fruits += 1
		carried_fruits_updated.emit(carried_ripe_fruits)
		update_speed()

func deliver_fruits():
	if not in_delivery_zone or not current_delivery_zone:
		return false
	
	if carried_ripe_fruits > 0:
		if inventory_system:
			inventory_system.add_delivered_ripe_fruits(carried_ripe_fruits)
		
		carried_ripe_fruits = 0
		carried_fruits_updated.emit(0)
		update_speed()
		return true
	
	return false

func update_speed():
	var total_fruits = carried_ripe_fruits
	var speed_reduction = total_fruits * SPEED_REDUCTION_PER_FRUIT
	var new_speed = max(0, BASE_SPEED - speed_reduction)
	
	if player_controller:
		player_controller.set_current_speed(new_speed)

func get_initialization_status() -> bool:
	return is_fully_initialized

func is_player_ready() -> bool:
	return is_fully_initialized

func get_carried_ripe_fruits() -> int:
	return carried_ripe_fruits

func take_damage(damage: int):
	if is_dead:
		return
	
	# Kurangi HP player
	current_hp = max(0, current_hp - damage)
	hp_updated.emit(current_hp, MAX_HP)
	
	print("Player menerima damage %d! HP: %d / %d" % [damage, current_hp, MAX_HP])
	
	# Cek jika player mati
	if current_hp <= 0:
		is_dead = true
		current_hp = 0
		hp_updated.emit(0, MAX_HP)
		player_died.emit()
		print("Player mati! Game Over!")

func get_hp() -> int:
	return current_hp

func get_max_hp() -> int:
	return MAX_HP

func is_player_dead() -> bool:
	return is_dead
