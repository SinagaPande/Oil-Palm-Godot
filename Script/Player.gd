extends CharacterBody3D
class_name Player

@onready var player_controller = $PlayerController
@onready var interaction_system = $InteractionSystem
@onready var camera = $PlayerController/Camera3D
@onready var egrek = $PlayerController/Camera3D/Egrek
@onready var tojok = $PlayerController/Camera3D/Tojok

# --- RAIN PARTICLE SYSTEM ---
@export var rain_particle_node: GPUParticles3D
# ----------------------------------

signal carried_fruits_updated(ripe_count, total_kg)
signal player_fully_ready

# HEALTH SYSTEM SIGNALS - DITAMBAHKAN DARI BRANCH ANSELMARIO
signal health_changed(current_health: int, max_health: int)
signal player_died

# Ubah sistem bawa buah
var carried_ripe_fruits: int = 0
var carried_ripe_kg: int = 0
var in_delivery_zone: bool = false
var current_delivery_zone: DeliveryZone = null
var inventory_system: Node
var ui_manager: UIManager

const BASE_SPEED = 14
var speed_reduction_factor: float = 0.03

var is_fully_initialized: bool = false

# VARIABEL UNTUK AIR
var water_slow_factor: float = 0
var is_in_water: bool = false
var original_speed: float = BASE_SPEED

# HEALTH SYSTEM VARIABLES - DITAMBAHKAN DARI BRANCH ANSELMARIO
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
	
	# --- RAIN VISIBILITY FIX ---
	if rain_particle_node:
		rain_particle_node.visibility_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	# ----------------------------------
	
	await get_tree().process_frame
	is_fully_initialized = true
	player_fully_ready.emit()

# --- UPDATE RAIN POSITION EVERY FRAME ---
func _process(delta):
	move_rain_to_player()
# ----------------------------------------

# --- RAIN LOGIC FUNCTIONS ---
func move_rain_to_player():
	if rain_particle_node:
		var target_pos = global_position
		
		# Offset berdasarkan velocity untuk mencegah outrunning
		var velocity_offset = Vector3(velocity.x, 0, velocity.z) * 0.5
		target_pos += velocity_offset
		
		target_pos.y += 10.0
		rain_particle_node.global_position = target_pos
# ----------------------------------------

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
	var paths_to_try = [
		"/root/Node3D/UIManager",
		"../UIManager",
		"../../UIManager"
	]
	
	for path in paths_to_try:
		ui_manager = get_node_or_null(path)
		if ui_manager:
			break
	
	if ui_manager == null:
		var ui_managers = get_tree().get_nodes_in_group("ui_manager")
		if ui_managers.size() > 0:
			ui_manager = ui_managers[0]

func set_in_delivery_zone(is_in_zone: bool, zone: DeliveryZone):
	in_delivery_zone = is_in_zone
	current_delivery_zone = zone

func add_to_inventory(fruit_type: String):
	var weight_kg: int = 0
	
	if fruit_type == "Masak":
		weight_kg = randi_range(30, 40)
		carried_ripe_fruits += 1
		carried_ripe_kg += weight_kg
		carried_fruits_updated.emit(carried_ripe_fruits, carried_ripe_kg)
		update_speed()
	elif fruit_type == "Mentah":
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
		update_speed_with_water()
		return true
	
	return false

func update_speed():
	update_speed_with_water()

func apply_water_slowdown(factor: float):
	if not is_in_water:
		is_in_water = true
		water_slow_factor = factor
		print("Player terkena efek air: ", factor * 100, "% slowdown")
		update_speed_with_water()
	else:
		water_slow_factor = max(water_slow_factor, factor)
		update_speed_with_water()

func remove_water_slowdown():
	if is_in_water:
		is_in_water = false
		water_slow_factor = 0.0
		print("Player keluar dari air")
		update_speed_with_water()

func update_speed_with_water():
	var total_kg = carried_ripe_kg
	var weight_reduction = total_kg * speed_reduction_factor
	
	var water_reduction = 0.0
	if is_in_water and water_slow_factor > 0:
		water_reduction = BASE_SPEED * water_slow_factor
	
	var new_speed = max(1.0, BASE_SPEED - weight_reduction - water_reduction)
	
	if player_controller:
		player_controller.set_current_speed(new_speed)
	
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

# ===== HEALTH SYSTEM - DITAMBAHKAN DARI BRANCH ANSELMARIO =====
func take_damage(damage: int) -> void:
	## Reduce player health and emit signal
	if is_dead:
		return
	
	current_health -= damage
	print("Player terkena damage: ", damage, " | Health: ", current_health, " / ", MAX_HEALTH)
	
	# Emit signal untuk UI update
	health_changed.emit(current_health, MAX_HEALTH)
	
	# Check if dead
	if current_health <= 0:
		die()

func die() -> void:
	## Handle player death
	if is_dead:
		return
	
	is_dead = true
	print("Player MATI!")
	
	# Emit death signal
	player_died.emit()
	
	# Optional: disable movement, freeze player, show game over, etc.
	if player_controller:
		player_controller.set_process(false)

func is_player_dead() -> bool:
	## Check if player is dead
	return is_dead

func get_current_health() -> int:
	## Get current health
	return current_health

func get_max_health() -> int:
	## Get maximum health
	return MAX_HEALTH

func heal(amount: int) -> void:
	## Heal player
	if is_dead:
		return
	
	current_health = min(current_health + amount, MAX_HEALTH)
	print("Player disembuhkan: ", amount, " | Health: ", current_health, " / ", MAX_HEALTH)
	health_changed.emit(current_health, MAX_HEALTH)
