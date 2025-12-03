extends CharacterBody3D
class_name Player

@onready var player_controller = $PlayerController
@onready var interaction_system = $InteractionSystem
@onready var camera = $PlayerController/Camera3D
@onready var egrek = $PlayerController/Camera3D/Egrek
@onready var tojok = $PlayerController/Camera3D/Tojok

signal carried_fruits_updated(ripe_count, total_kg)
signal player_fully_ready
signal health_changed(current_health, max_health)
signal player_died

# Ubah sistem bawa buah
var carried_ripe_fruits: int = 0  # Jumlah buah (untuk display)
var carried_ripe_kg: int = 0  # Total kg buah yang dibawa (integer)
var in_delivery_zone: bool = false
var current_delivery_zone: DeliveryZone = null
var inventory_system: Node
var ui_manager: UIManager  # Referensi ke UIManager

const BASE_SPEED = 14
var speed_reduction_factor: float = 0.03  # DIUBAH: dari const ke var

var is_fully_initialized: bool = false

# VARIABEL BARU
var water_slow_factor: float = 0  # 0 = no slow, 0.35 = 35% slow
var is_in_water: bool = false
var original_speed: float = BASE_SPEED

# Health system
const MAX_HEALTH: int = 100
var current_health: int = MAX_HEALTH
var is_dead: bool = false

# Setter untuk speed reduction factor
func set_speed_reduction_factor(new_factor: float):
	speed_reduction_factor = new_factor
	print("Player speed reduction factor diatur ke: ", speed_reduction_factor)
	update_speed()

func _ready():
	add_to_group("player")
	setup_components()
	
	if player_controller:
		player_controller.set_current_speed(BASE_SPEED)
	
	find_inventory_system()
	find_ui_manager()
	
	# Initialize health
	current_health = MAX_HEALTH
	is_dead = false
	health_changed.emit(current_health, MAX_HEALTH)
	
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
		
		# Cari node Ketapel di scene
		var ketapel = camera.get_node_or_null("Ketapel")
		if ketapel:
			player_controller.ketapel_node = ketapel
		else:
			print("Warning: Ketapel node not found under camera")
	
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
		
		if ui_manager:
			ui_manager.show_delivery_notification(carried_ripe_kg)
		
		carried_ripe_fruits = 0
		carried_ripe_kg = 0
		carried_fruits_updated.emit(0, 0)
		update_speed_with_water()  # Ganti ini
		return true
	
	return false

func update_speed():
	update_speed_with_water()  # Ganti dengan fungsi baru
		
func apply_water_slowdown(factor: float):
	if not is_in_water:
		is_in_water = true
		water_slow_factor = factor  # factor = 0.35 dari Genangan
		print("Player terkena efek air: ", factor * 100, "% slowdown")
		update_speed_with_water()
	else:
		# Jika sudah di air, update faktor (jika berbeda)
		water_slow_factor = max(water_slow_factor, factor)
		update_speed_with_water()

func remove_water_slowdown():
	if is_in_water:
		is_in_water = false
		water_slow_factor = 0.0
		print("Player keluar dari air")
		update_speed_with_water()
		
func update_speed_with_water():
	# Hitung reduksi dari buah
	var total_kg = carried_ripe_kg
	var weight_reduction = total_kg * speed_reduction_factor
	
	# Hitung reduksi dari air (jika ada)
	var water_reduction = 0.0
	if is_in_water and water_slow_factor > 0:
		water_reduction = BASE_SPEED * water_slow_factor
	
	# Total speed
	var new_speed = max(1.0, BASE_SPEED - weight_reduction - water_reduction)
	
	if player_controller:
		player_controller.set_current_speed(new_speed)
	
	# DEBUG: Tampilkan info detail
	print("===== SPEED CALCULATION =====")
	print("Base Speed: ", BASE_SPEED)
	print("Carried KG: ", total_kg, " | Weight Reduction: ", weight_reduction)
	print("In Water: ", is_in_water, " | Water Slow Factor: ", water_slow_factor)
	print("Water Reduction: ", water_reduction)
	print("New Speed: ", new_speed)
	print("=============================")

func get_initialization_status() -> bool:
	return is_fully_initialized

func is_player_ready() -> bool:
	return is_fully_initialized

func get_carried_ripe_fruits() -> int:
	return carried_ripe_fruits

func get_carried_ripe_kg() -> int:
	return carried_ripe_kg

# Health system functions
func take_damage(damage: int):
	if is_dead:
		return
	
	current_health = max(0, current_health - damage)
	health_changed.emit(current_health, MAX_HEALTH)
	
	print("Player terkena damage: ", damage, " HP. Health sekarang: ", current_health, "/", MAX_HEALTH)
	
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	current_health = 0
	health_changed.emit(0, MAX_HEALTH)
	player_died.emit()
	
	print("Player MATI! Game Over")

func is_player_dead() -> bool:
	return is_dead

func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return MAX_HEALTH
	
