extends Node3D

@export var fruit_scene: PackedScene
@export var spawn_points: Array[NodePath]

var spawned_fruits = []

func _ready():
	spawn_initial_fruits()

func spawn_initial_fruits():
	for spawn_point_path in spawn_points:
		var spawn_point = get_node(spawn_point_path) as Marker3D
		if spawn_point and fruit_scene:
			var fruit_instance = fruit_scene.instantiate()
			add_child(fruit_instance)
			
			# Set posisi dan rotasi mengikuti spawn point
			fruit_instance.global_position = spawn_point.global_position
			fruit_instance.global_rotation = spawn_point.global_rotation
			
			spawned_fruits.append(fruit_instance)
