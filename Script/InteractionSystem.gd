extends Node3D

@export var camera: Camera3D
@export var interaction_label: Label

var ray_length = 10.0
var current_target = null
var collected_fruits = 0

func _ready():
	if interaction_label:
		interaction_label.visible = false

func _input(event):
	if event.is_action_pressed("shoot"):
		handle_interaction()

func _physics_process(delta):
	raycast_system()

func handle_interaction():
	print("Shoot action pressed!")
	if current_target:
		print("Current target: ", current_target.name)
		if current_target.is_in_group("buah"):
			print("Calling fall_from_tree()")
			# Kirim posisi player ke buah
			var player_position = get_parent().global_position
			current_target.fall_from_tree(player_position)
		elif current_target.is_in_group("buah_jatuh") and current_target.has_touched_surface:
			print("Calling collect_fruit()")
			collect_fruit(current_target)
	else:
		print("No current target")

func raycast_system():
	if !camera:
		return
		
	var space_state = get_world_3d().direct_space_state
	var origin = camera.global_position
	var end = origin - camera.global_transform.basis.z * ray_length
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_parent()]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		
		# Debug lebih detail
		var has_touched = false
		if collider.has_method("get") and collider.get("has_touched_surface") != null:
			has_touched = collider.has_touched_surface
		
		print("Raycast hit: ", collider.name, " | Type: ", collider.get_class())
		print("Groups: ", collider.get_groups(), " | Has touched: ", has_touched)
		print("Position: ", collider.global_position)
		print("---")
		
		if collider.is_in_group("buah"):
			current_target = collider
			show_interaction_label("Klik untuk menjatuhkan buah")
		elif collider.is_in_group("buah_jatuh"):
			if has_touched:
				current_target = collider
				show_interaction_label("Klik untuk mengumpulkan buah")
			else:
				print("❌ Buah jatuh tapi belum sentuh permukaan")
				current_target = null
				hide_interaction_label()
		else:
			current_target = null
			hide_interaction_label()
	else:
		current_target = null
		hide_interaction_label()

func show_interaction_label(text):
	if interaction_label:
		interaction_label.text = text
		interaction_label.visible = true

func hide_interaction_label():
	if interaction_label:
		interaction_label.visible = false

func collect_fruit(fruit):
	if fruit.is_in_group("buah_jatuh") and fruit.has_touched_surface:
		fruit.queue_free()
		collected_fruits += 1
		current_target = null
		hide_interaction_label()
		print("Buah terkumpul: ", collected_fruits)
