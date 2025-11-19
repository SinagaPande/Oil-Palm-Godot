extends CharacterBody3D
class_name Player

@onready var player_controller = $PlayerController
@onready var interaction_system = $InteractionSystem
@onready var camera = $PlayerController/Camera3D
@onready var egrek = $PlayerController/Camera3D/Egrek
@onready var tojok = $PlayerController/Camera3D/Tojok

signal carried_fruits_updated(ripe_count, total_kg)
signal player_fully_ready

# Ubah sistem bawa buah
var carried_ripe_fruits: int = 0  # Jumlah buah (untuk display)
var carried_ripe_kg: int = 0  # Total kg buah yang dibawa (integer)
var in_delivery_zone: bool = false
var current_delivery_zone: DeliveryZone = null
var inventory_system: Node
var ui_manager: UIManager  # Referensi ke UIManager

const BASE_SPEED = 8
const SPEED_REDUCTION_PER_KG = 0.01

var is_fully_initialized: bool = false

func _ready():
	add_to_group("player")
	setup_components()
	
	if player_controller:
		player_controller.set_current_speed(BASE_SPEED)
	
	find_inventory_system()
	find_ui_manager()
	
	await get_tree().process_frame
	is_fully_initialized = true
	player_fully_ready.emit()

func get_base_speed() -> float:
	return BASE_SPEED

func setup_components():
	if player_controller:
		player_controller.player_body = self
		player_controller.camera_node = camera
		player_controller.egrek_node = egrek
		player_controller.tojok_node = tojok
	
	if interaction_system:
		interaction_system.camera = camera
		interaction_system.player_controller = player_controller

func find_inventory_system():
	var paths_to_try = [
		"/root/Node3D/InventorySystem",
		"/root/Level/InventorySystem", 
		"../InventorySystem",
		"../../InventorySystem"
	]
	
	for path in paths_to_try:
		var node = get_node_or_null(path)
		if node and node.has_method("add_unripe_fruit_kg"):
			inventory_system = node
			return
	
	var nodes = get_tree().get_nodes_in_group("inventory_system")
	if nodes.size() > 0:
		inventory_system = nodes[0]

func find_ui_manager():
	# Cari di berbagai lokasi possible
	var paths_to_try = [
		"/root/Node3D/UIManager",
		"../UIManager",
		"../../UIManager"
	]
	
	for path in paths_to_try:
		ui_manager = get_node_or_null(path)
		if ui_manager:
			break
	
	# Fallback: cari by group
	if ui_manager == null:
		var ui_managers = get_tree().get_nodes_in_group("ui_manager")
		if ui_managers.size() > 0:
			ui_manager = ui_managers[0]

func set_in_delivery_zone(is_in_zone: bool, zone: DeliveryZone):
	in_delivery_zone = is_in_zone
	current_delivery_zone = zone

# Fungsi baru untuk menambah buah dengan berat acak
func add_to_inventory(fruit_type: String):
	var weight_kg: int = 0
	
	if fruit_type == "Masak":
		# Buah matang: 30-40 kg (integer)
		weight_kg = randi_range(30, 40)
		carried_ripe_fruits += 1
		carried_ripe_kg += weight_kg
		carried_fruits_updated.emit(carried_ripe_fruits, carried_ripe_kg)
		update_speed()
	elif fruit_type == "Mentah":
		# Buah mentah: 25-30 kg (integer), langsung ke inventory system
		weight_kg = randi_range(25, 30)
		if inventory_system:
			inventory_system.add_unripe_fruit_kg(weight_kg)

func deliver_fruits():
	if not in_delivery_zone or not current_delivery_zone:
		return false
	
	if carried_ripe_fruits > 0:
		if inventory_system:
			inventory_system.add_delivered_ripe_kg(carried_ripe_kg)
		
		# Tampilkan notifikasi dengan total kg melalui UIManager
		if ui_manager:
			ui_manager.show_delivery_notification(carried_ripe_kg)
		
		carried_ripe_fruits = 0
		carried_ripe_kg = 0
		carried_fruits_updated.emit(0, 0)
		update_speed()
		return true
	
	return false

func update_speed():
	var total_kg = carried_ripe_kg
	var speed_reduction = total_kg * SPEED_REDUCTION_PER_KG
	var new_speed = max(1.0, BASE_SPEED - speed_reduction)  # Minimum speed 1.0
	
	if player_controller:
		player_controller.set_current_speed(new_speed)

func get_initialization_status() -> bool:
	return is_fully_initialized

func is_player_ready() -> bool:
	return is_fully_initialized

func get_carried_ripe_fruits() -> int:
	return carried_ripe_fruits

func get_carried_ripe_kg() -> int:
	return carried_ripe_kg
