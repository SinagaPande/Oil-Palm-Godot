extends Node3D

@export var fruit_scene: PackedScene

func _ready():
	spawn_initial_fruits()

func spawn_initial_fruits():
	var spawn_points_node = $SpawnPoints
	
	if not spawn_points_node:
		spawn_points_node = get_node_or_null("SpawnPoints")
	
	if not spawn_points_node:
		spawn_points_node = find_child("SpawnPoints", true, false)
	
	if not spawn_points_node:
		push_warning("SpawnPoints node tidak ditemukan di tree: " + name)
		return
	
	var markers_found = 0
	for child in spawn_points_node.get_children():
		if child is Marker3D:
			spawn_fruit_at_marker(child)
			markers_found += 1
	
	if markers_found == 0:
		push_warning("Tidak ada Marker3D ditemukan di SpawnPoints")

func spawn_fruit_at_marker(marker: Marker3D):
	if not fruit_scene:
		return
	
	var fruit_instance = fruit_scene.instantiate()
	add_child(fruit_instance)
	
	fruit_instance.global_position = marker.global_position
	fruit_instance.global_rotation = marker.global_rotation
	
