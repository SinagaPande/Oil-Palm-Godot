extends Area3D
class_name DeliveryZone

@export var lod_models_high: Array[PackedScene] = []
@export var lod_models_low: Array[PackedScene] = []
@export var weight_threshold_per_model: int = 250

var current_lod_level: String = "high"
var lod_update_timer: float = 0.0
var model_containers: Array[Node3D] = []
var player_node: Node3D = null
var camera_node: Camera3D = null
var current_weight: int = 0

const LOD_UPDATE_INTERVAL: float = 0.3
const LOD_HIGH_DISTANCE = 10
const LOD_LOW_DISTANCE = 15

signal fruits_delivered(ripe_count, unripe_count)

func _ready():
	add_to_group("delivery_zone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	initialize_lod_system()
	initialize_progressive_models()

func initialize_lod_system():
	find_player_and_camera()
	setup_lod_model("high")

func find_player_and_camera():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
		camera_node = find_camera_recursive(player_node)

func find_camera_recursive(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found = find_camera_recursive(child)
		if found:
			return found
	return null

func _process(delta):
	if not player_node or not camera_node:
		return
	
	lod_update_timer += delta
	if lod_update_timer >= LOD_UPDATE_INTERVAL:
		lod_update_timer = 0.0
		update_lod()

func update_lod():
	if not player_node:
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	var new_lod_level = "high" if distance_to_player <= LOD_HIGH_DISTANCE else "low"
	
	if new_lod_level != current_lod_level:
		current_lod_level = new_lod_level
		setup_lod_model(new_lod_level)

func setup_lod_model(lod_level: String):
	clear_all_models()
	
	var selected_models = lod_models_high if lod_level == "high" else lod_models_low
	
	for i in range(selected_models.size()):
		if selected_models[i]:
			var model_instance = selected_models[i].instantiate()
			add_child(model_instance)
			model_containers.append(model_instance)
			setup_model_position(model_instance, i)
	
	update_model_progression()

func clear_all_models():
	for container in model_containers:
		if is_instance_valid(container):
			container.queue_free()
	model_containers.clear()

func setup_model_position(model_instance: Node3D, index: int):
	model_instance.position.x = index * 0

func update_model_progression():
	var models_to_show = calculate_models_to_show()
	
	for i in range(model_containers.size()):
		model_containers[i].visible = i < models_to_show

func initialize_progressive_models():
	load_progress_data()

func load_progress_data():
	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	if inventory_system and inventory_system.has_method("get_delivered_ripe_kg"):
		current_weight = inventory_system.get_delivered_ripe_kg()
		update_model_progression()

func calculate_models_to_show() -> int:
	var models_to_show = 0
	
	if current_weight > 0:
		models_to_show = 1
		if current_weight >= weight_threshold_per_model:
			models_to_show = (current_weight / weight_threshold_per_model) + 1
	
	models_to_show = min(models_to_show, lod_models_high.size())
	return models_to_show

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("set_in_delivery_zone"):
			body.set_in_delivery_zone(true, self)

func _on_body_exited(body):
	if body.is_in_group("player"):
		if body.has_method("set_in_delivery_zone"):
			body.set_in_delivery_zone(false, null)

func deliver_fruits(ripe_count: int, unripe_count: int) -> bool:
	if ripe_count > 0 or unripe_count > 0:
		fruits_delivered.emit(ripe_count, unripe_count)
		
		var total_weight_kg = 0
		if ripe_count > 0:
			total_weight_kg += ripe_count * 35
		
		if unripe_count > 0:
			total_weight_kg += unripe_count * 27
		
		add_delivered_weight(total_weight_kg)
		return true
	return false

func add_delivered_weight(weight_kg: int):
	current_weight += weight_kg
	update_model_progression()

func get_current_weight() -> int:
	return current_weight

func get_models_visible_count() -> int:
	var count = 0
	for container in model_containers:
		if is_instance_valid(container) and container.visible:
			count += 1
	return count
