extends Node3D

class_name InteractionSystem

@export var camera: Camera3D
@export var interaction_label: Label  # Fallback jika UI_Manager tidak ditemukan
@export var player_controller: Node

const RAY_LENGTH = 5.25

var current_target = null
var player_node: Node3D = null
var ui_manager: UI_Manager = null

func _ready():
	if interaction_label:
		interaction_label.visible = false
	
	player_node = get_parent()
	
	# Cari UI_Manager
	await get_tree().process_frame
	find_ui_manager()

func find_ui_manager():
	# Cari UI_Manager di scene - coba berbagai path
	var paths_to_try = [
		"/root/Node3D/UI_Manager",
		"/root/Level/UI_Manager",
		"../UI_Manager",
		"../../UI_Manager"
	]
	
	for path in paths_to_try:
		ui_manager = get_node_or_null(path)
		if ui_manager:
			break
	
	if not ui_manager:
		var ui_nodes = get_tree().get_nodes_in_group("ui_manager")
		if ui_nodes.size() > 0:
			ui_manager = ui_nodes[0] as UI_Manager

func _input(event):
	if event.is_action_pressed("shoot"):
		handle_interaction()

func _physics_process(_delta):
	raycast_system()

func handle_interaction():
	if player_controller and player_controller.has_method("play_egrek_animation"):
		player_controller.play_egrek_animation()
	
	if current_target:
		handle_target_interaction()
	else:
		if player_node and player_node.has_method("deliver_fruits"):
			var can_deliver = player_node.deliver_fruits()
			if can_deliver:
				show_interaction_label("Buah matang berhasil diantar!")
			elif player_node.in_delivery_zone and player_node.get_carried_ripe_fruits() == 0:
				show_interaction_label("Tidak ada buah matang untuk diantar")

func handle_target_interaction():
	if current_target.is_in_group("buah"):
		var player_position = get_parent().global_position
		
		var fruit_type = current_target.get("fruit_type")
		if fruit_type == "Mentah":
			var inventory_system = get_node("/root/Node3D/InventorySystem")
			if inventory_system:
				inventory_system.add_unripe_fruit_direct()
		
		current_target.fall_from_tree(player_position)
		
	elif current_target.is_in_group("buah_jatuh") and current_target.has_touched_surface:
		if current_target.can_be_collected:
			collect_fruit(current_target)

func raycast_system():
	if !camera:
		return
	
	if player_node and player_node.in_delivery_zone and player_node.get_carried_ripe_fruits() > 0:
		show_interaction_label("Tekan untuk menyerahkan buah")
		return
		
	var space_state = get_world_3d().direct_space_state
	var origin = camera.global_position
	var end = origin - camera.global_transform.basis.z * RAY_LENGTH
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_parent()]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		handle_raycast_result(result.collider)
	else:
		clear_target()

func handle_raycast_result(collider):
	if is_fruit(collider):
		current_target = collider
		var fruit_type = collider.get("fruit_type")
		var type_text = "masak" if fruit_type == "Masak" else "mentah"
		
		if fruit_type == "Mentah":
			show_interaction_label("Klik untuk menjatuhkan buah mentah (+1 poin langsung)")
		else:
			show_interaction_label("Klik untuk menjatuhkan buah " + type_text)
			
	elif is_collectable_fruit(collider):
		current_target = collider
		var fruit_type = collider.get("fruit_type")
		var type_text = "masak" if fruit_type == "Masak" else "mentah"
		
		if collider.can_be_collected:
			show_interaction_label("Klik untuk mengumpulkan buah " + type_text)
		else:
			show_interaction_label("Buah " + type_text + " (belum menyentuh tanah)")
	else:
		clear_target()

func is_fruit(collider) -> bool:
	return collider.is_in_group("buah")

func is_collectable_fruit(collider) -> bool:
	return (collider.is_in_group("buah_jatuh") and 
			collider.get("has_touched_surface") and 
			collider.has_touched_surface and
			collider.get("can_be_collected") and
			collider.can_be_collected)

func show_interaction_label(text):
	# Gunakan UI_Manager jika tersedia, jika tidak gunakan interaction_label langsung
	if ui_manager:
		ui_manager.show_interaction_label(text)
	elif interaction_label:
		interaction_label.text = text
		interaction_label.visible = true

func hide_interaction_label():
	# Gunakan UI_Manager jika tersedia, jika tidak gunakan interaction_label langsung
	if ui_manager:
		ui_manager.hide_interaction_label()
	elif interaction_label:
		interaction_label.visible = false

func clear_target():
	current_target = null
	hide_interaction_label()

func collect_fruit(fruit):
	if not is_instance_valid(fruit):
		clear_target()
		return
		
	if fruit.is_in_group("buah_jatuh") and fruit.has_touched_surface and fruit.can_be_collected:
		var fruit_type = fruit.get("fruit_type")
		
		if fruit_type == "Masak":
			if player_node and player_node.has_method("add_to_inventory"):
				player_node.add_to_inventory("Masak")
		
		fruit.queue_free()
		clear_target()
