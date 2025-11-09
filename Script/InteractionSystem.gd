extends Node3D

@export var camera: Camera3D
@export var interaction_label: Label
@export var player_controller: Node

const RAY_LENGTH = 5.25

var current_target = null

func _ready():
	if interaction_label:
		interaction_label.visible = false

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

func handle_target_interaction():
	if current_target.is_in_group("buah"):
		var player_position = get_parent().global_position
		current_target.fall_from_tree(player_position)
	elif current_target.is_in_group("buah_jatuh") and current_target.has_touched_surface:
		collect_fruit(current_target)

func raycast_system():
	if !camera:
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
		show_interaction_label("Klik untuk menjatuhkan buah " + type_text)
	elif is_collectable_fruit(collider):
		current_target = collider
		var fruit_type = collider.get("fruit_type")
		var type_text = "masak" if fruit_type == "Masak" else "mentah"
		show_interaction_label("Klik untuk mengumpulkan buah " + type_text)
	else:
		clear_target()

func is_fruit(collider) -> bool:
	return collider.is_in_group("buah")

func is_collectable_fruit(collider) -> bool:
	return (collider.is_in_group("buah_jatuh") and 
			collider.get("has_touched_surface") and 
			collider.has_touched_surface)

func show_interaction_label(text):
	if interaction_label:
		interaction_label.text = text
		interaction_label.visible = true

func hide_interaction_label():
	if interaction_label:
		interaction_label.visible = false

func clear_target():
	current_target = null
	hide_interaction_label()

func collect_fruit(fruit):
	if not is_instance_valid(fruit):
		clear_target()
		return
		
	if fruit.is_in_group("buah_jatuh") and fruit.has_touched_surface:
		var fruit_type = fruit.get("fruit_type")
		if fruit_type == "Masak":
			print("Mengumpulkan buah masak (+10 poin)")
		else:
			print("Mengumpulkan buah mentah (+5 poin)")
		
		fruit.queue_free()
		clear_target()
