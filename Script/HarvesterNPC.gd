extends CharacterBody3D
class_name HarvesterNPC

enum NPCState {
	SPAWN,
	SEARCH, 
	MOVE,
	HARVEST,
	IDLE,
	RETURN_TO_SPAWN
}

@export var animation_player: AnimationPlayer
@export var move_speed: float = 3.0
@export var harvest_range: float = 2.0
@export var search_radius: float = 15.0
# DIUBAH: Hapus @export
var max_carry_capacity: int = 2

var current_state: NPCState = NPCState.SPAWN
var target_tree: Node3D = null
var harvest_timer: float = 0.0
var harvest_delay_per_fruit: float = 2.0
var fruits_to_harvest: int = 0
var current_harvest_count: int = 0

var npc_carried_ripe_fruits: int = 0
var total_harvested_by_npc: int = 0
var npc_carried_ripe_kg: int = 0

var visited_trees: Array = []
var search_attempts: int = 0
var tree_cooldowns: Dictionary = {}

var current_harvesting_fruits: Array = []
var harvest_progress_timer: float = 0.0

var egrek_model: Node3D = null
var is_harvesting: bool = false
var nearest_spawn_point: Marker3D = null
var stuck_timer: float = 0.0
var stuck_check_position: Vector3 = Vector3.ZERO
var is_destroyed: bool = false

const STUCK_THRESHOLD: float = 3.0
const MIN_MOVEMENT_DISTANCE: float = 0.5
const MAX_SEARCH_ATTEMPTS: int = 15
const TREE_COOLDOWN_TIME: float = 10.0

signal npc_harvested_fruits(harvested_count, total_harvested)
signal npc_returned_to_spawn(npc_instance)

# Setter untuk carry capacity dari NPCManager
func set_carry_capacity(new_capacity: int):
	max_carry_capacity = new_capacity
	print("HarvesterNPC: Kapasitas dibawa diatur ke ", max_carry_capacity)

func _ready():
	add_to_group("harvester_npc")
	setup_collision_config()
	
	if not animation_player:
		find_animation_player_auto()
	
	find_egrek_model_auto()
	call_deferred("delayed_initialize")

func delayed_initialize():
	await get_tree().process_frame
	global_position = Vector3(global_position.x, 0, global_position.z)
	initialize_npc()

func setup_collision_config():
	var collision_shape = find_child("CollisionShape3D")
	if collision_shape:
		collision_mask = 0x00000001
		set_collision_layer_value(2, false)
		set_collision_layer_value(3, false)
		set_collision_layer_value(4, false)
		set_collision_layer_value(5, false)

func play_animation(anim_name: String):
	if animation_player and animation_player.has_animation(anim_name):
		if anim_name == "Jalan":
			var anim = animation_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
		animation_player.play(anim_name)
	update_egrek_visibility(anim_name)

func update_egrek_visibility(anim_name: String):
	if not egrek_model:
		return
	
	if anim_name == "Panen":
		egrek_model.visible = true
		is_harvesting = true
	else:
		egrek_model.visible = false
		is_harvesting = false

func _physics_process(delta):
	if get_tree().paused:
		return
	
	state_process(delta)
	update_tree_cooldowns(delta)

func state_process(delta):
	if get_tree().paused:
		return
	
	match current_state:
		NPCState.SPAWN:
			pass
			
		NPCState.SEARCH:
			if npc_carried_ripe_fruits >= max_carry_capacity:
				transition_to_state(NPCState.RETURN_TO_SPAWN)
				return
				
			var nearest_tree = find_nearest_tree()
			if nearest_tree:
				target_tree = nearest_tree
				transition_to_state(NPCState.MOVE)
			else:
				if npc_carried_ripe_fruits > 0:
					transition_to_state(NPCState.RETURN_TO_SPAWN)
				else:
					transition_to_state(NPCState.IDLE)
			
		NPCState.MOVE:
			if target_tree and is_instance_valid(target_tree):
				move_towards_target(target_tree.global_position)
				check_if_stuck(delta)
				
				var distance_to_tree = global_position.distance_to(target_tree.global_position)
				if distance_to_tree <= harvest_range:
					transition_to_state(NPCState.HARVEST)
			else:
				target_tree = null
				transition_to_state(NPCState.SEARCH)
			
		NPCState.HARVEST:
			harvest_timer += delta
			harvest_progress_timer += delta
			
			if harvest_progress_timer >= harvest_delay_per_fruit and current_harvesting_fruits.size() > 0:
				harvest_progress_timer = 0.0
				harvest_single_fruit()
			
			if current_harvest_count >= fruits_to_harvest or npc_carried_ripe_fruits >= max_carry_capacity:
				if target_tree and should_mark_tree_visited(target_tree):
					mark_tree_visited(target_tree)
				
				if npc_carried_ripe_fruits >= max_carry_capacity:
					transition_to_state(NPCState.RETURN_TO_SPAWN)
				else:
					transition_to_state(NPCState.SEARCH)
			
		NPCState.IDLE:
			harvest_timer += delta
			if harvest_timer >= 3.0:
				harvest_timer = 0.0
				transition_to_state(NPCState.SEARCH)
		
		NPCState.RETURN_TO_SPAWN:
			if nearest_spawn_point and is_instance_valid(nearest_spawn_point):
				move_towards_target(nearest_spawn_point.global_position)
				check_if_stuck(delta)
				
				var distance_to_spawn = global_position.distance_to(nearest_spawn_point.global_position)
				
				if distance_to_spawn <= 1.5:
					destroy_npc()
				elif stuck_timer >= STUCK_THRESHOLD:
					global_position = Vector3(nearest_spawn_point.global_position.x, global_position.y, nearest_spawn_point.global_position.z)
					destroy_npc()
			else:
				nearest_spawn_point = find_nearest_spawn_point()
				if not nearest_spawn_point:
					destroy_npc()

func check_if_stuck(delta: float):
	var current_pos = global_position
	var distance_moved = current_pos.distance_to(stuck_check_position)
	
	if distance_moved < MIN_MOVEMENT_DISTANCE and velocity.length() < 0.1:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		stuck_check_position = current_pos
	
	if stuck_timer >= STUCK_THRESHOLD:
		handle_stuck_situation()

func handle_stuck_situation():
	match current_state:
		NPCState.RETURN_TO_SPAWN:
			if nearest_spawn_point and is_instance_valid(nearest_spawn_point):
				global_position = nearest_spawn_point.global_position
				destroy_npc()
			else:
				destroy_npc()
		
		NPCState.MOVE:
			if target_tree and is_instance_valid(target_tree):
				stuck_timer = 0.0
				stuck_check_position = global_position
				var random_offset = Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
				global_position += random_offset
			else:
				target_tree = null
				transition_to_state(NPCState.SEARCH)

func destroy_npc():
	if is_destroyed:
		return
	
	is_destroyed = true
	npc_returned_to_spawn.emit(self)
	queue_free()

func harvest_single_fruit():
	if npc_carried_ripe_fruits >= max_carry_capacity:
		return
	
	if current_harvesting_fruits.size() == 0:
		return
		
	if egrek_model:
		egrek_model.visible = true
		
	play_animation("Panen")
	
	var fruit = current_harvesting_fruits[0]
	current_harvesting_fruits.remove_at(0)
	
	if is_instance_valid(fruit):
		fruit.queue_free()
		
		current_harvest_count += 1
		npc_carried_ripe_fruits += 1
		
		var harvested_kg = randi_range(30, 40)
		npc_carried_ripe_kg += harvested_kg
		total_harvested_by_npc += harvested_kg
		
		npc_harvested_fruits.emit(harvested_kg)
		
		if npc_carried_ripe_fruits >= max_carry_capacity:
			transition_to_state(NPCState.RETURN_TO_SPAWN)

func transition_to_state(new_state: NPCState):
	if get_tree().paused:
		return
	
	state_exit(current_state)
	current_state = new_state
	state_enter(new_state)
	
	stuck_timer = 0.0
	stuck_check_position = global_position

func state_enter(state: NPCState):
	match state:
		NPCState.SPAWN:
			play_animation("Jalan")
			
		NPCState.SEARCH:
			play_animation("Jalan")
			search_attempts += 1
			if search_attempts >= MAX_SEARCH_ATTEMPTS:
				visited_trees.clear()
				search_attempts = 0
			
		NPCState.MOVE:
			play_animation("Jalan")
			
		NPCState.HARVEST:
			play_animation("Panen")
			if npc_carried_ripe_fruits >= max_carry_capacity:
				transition_to_state(NPCState.RETURN_TO_SPAWN)
				return
				
			if target_tree and is_instance_valid(target_tree):
				if target_tree.has_method("set_harvesting_mode_active"):
					target_tree.set_harvesting_mode_active(true)
				
				fruits_to_harvest = calculate_fruits_to_harvest()
				
				if fruits_to_harvest <= 0:
					transition_to_state(NPCState.SEARCH)
					return
				
				current_harvest_count = 0
				harvest_timer = 0.0
				harvest_progress_timer = 0.0
				
				current_harvesting_fruits = get_ripe_fruits_from_tree(target_tree)
				
				if fruits_to_harvest > 0 and current_harvesting_fruits.size() > 0:
					var max_fruits_to_take = min(fruits_to_harvest, current_harvesting_fruits.size())
					if max_fruits_to_take < current_harvesting_fruits.size():
						current_harvesting_fruits = current_harvesting_fruits.slice(0, max_fruits_to_take)
				else:
					transition_to_state(NPCState.SEARCH)
			else:
				transition_to_state(NPCState.SEARCH)
			
		NPCState.IDLE:
			play_animation("Jalan")
			
		NPCState.RETURN_TO_SPAWN:
			play_animation("Jalan")
			nearest_spawn_point = find_nearest_spawn_point()
			if not nearest_spawn_point:
				destroy_npc()

func state_exit(state: NPCState):
	if get_tree().paused:
		return
	
	match state:
		NPCState.HARVEST:
			play_animation("Jalan")
			if target_tree and is_instance_valid(target_tree) and target_tree.has_method("set_harvesting_mode_active"):
				target_tree.set_harvesting_mode_active(false)
			current_harvesting_fruits.clear()
			
			if egrek_model:
				egrek_model.visible = false
				is_harvesting = false

func find_animation_player_auto():
	animation_player = find_child("AnimationPlayer", true, false)
	
	if not animation_player:
		var maling_node = find_child("Maling", true, false)
		if maling_node:
			animation_player = maling_node.find_child("AnimationPlayer", true, false)

func find_egrek_model_auto():
	egrek_model = find_child("*Egrek*", true, false)
	
	if not egrek_model:
		var maling_node = find_child("Maling", true, false)
		if maling_node:
			var mesh_instances = find_all_mesh_instances_recursive(maling_node)
			for mesh in mesh_instances:
				var mesh_name = mesh.name.to_lower()
				if "Egrek" in mesh_name or "tool" in mesh_name or "weapon" in mesh_name:
					egrek_model = mesh
					break
	
	if egrek_model:
		egrek_model.visible = false

func find_all_mesh_instances_recursive(node: Node) -> Array:
	var meshes = []
	
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		meshes.append_array(find_all_mesh_instances_recursive(child))
	
	return meshes

func find_nearest_spawn_point() -> Marker3D:
	var spawn_points = get_tree().get_nodes_in_group("npc_spawn")
	var nearest_spawn: Marker3D = null
	var nearest_distance = INF
	
	for spawn_point in spawn_points:
		if not is_instance_valid(spawn_point):
			continue
		
		if spawn_point.global_position == Vector3.ZERO:
			continue
			
		var distance = global_position.distance_to(spawn_point.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_spawn = spawn_point
	
	return nearest_spawn

func move_towards_target(target_position: Vector3):
	if get_tree().paused:
		return
	
	var current_pos = global_position
	var target_pos_flat = Vector3(target_position.x, current_pos.y, target_position.z)
	
	var direction = (target_pos_flat - current_pos).normalized()
	var actual_distance = current_pos.distance_to(target_pos_flat)
	
	if direction.length() > 0.1 and actual_distance > 0.5:
		velocity = direction * move_speed
		velocity.y = 0
		
		if velocity.length() > 0.5:
			look_at(global_position + direction, Vector3.UP)
	else:
		velocity = Vector3.ZERO
	
	move_and_slide()

func calculate_fruits_to_harvest() -> int:
	if not target_tree or not is_instance_valid(target_tree):
		return 0
	
	if npc_carried_ripe_fruits >= max_carry_capacity:
		return 0
	
	var available_fruits = 0
	if target_tree.has_method("get_ripe_count"):
		available_fruits = target_tree.get_ripe_count()
	
	var can_carry = max_carry_capacity - npc_carried_ripe_fruits
	
	if can_carry <= 0:
		return 0
	
	return min(available_fruits, can_carry)

func initialize_npc():
	await get_tree().create_timer(0.5).timeout
	transition_to_state(NPCState.SEARCH)

func get_ripe_fruits_from_tree(tree: Node3D) -> Array:
	var ripe_fruits = []
	
	if not tree or not is_instance_valid(tree):
		return ripe_fruits
	
	if tree.has_method("get_all_fruits"):
		var all_fruits = tree.get_all_fruits()
		for fruit in all_fruits:
			if is_instance_valid(fruit) and fruit.has_method("get_fruit_type"):
				if fruit.get_fruit_type() == "Masak":
					ripe_fruits.append(fruit)
	
	return ripe_fruits

func update_tree_cooldowns(delta: float):
	if get_tree().paused:
		return
	
	var trees_to_remove = []
	for tree in tree_cooldowns:
		if not is_instance_valid(tree):
			trees_to_remove.append(tree)
			continue
		
		tree_cooldowns[tree] -= delta
		if tree_cooldowns[tree] <= 0:
			trees_to_remove.append(tree)
	
	for tree in trees_to_remove:
		tree_cooldowns.erase(tree)
		if tree in visited_trees:
			visited_trees.erase(tree)

func should_mark_tree_visited(tree: Node3D) -> bool:
	if not tree or not is_instance_valid(tree):
		return false
	
	if tree.has_method("has_ripe_fruits"):
		return not tree.has_ripe_fruits()
	
	if tree.has_method("get_ripe_count"):
		return tree.get_ripe_count() == 0
	
	return false

func mark_tree_visited(tree: Node3D):
	if tree in visited_trees:
		return
	
	visited_trees.append(tree)
	tree_cooldowns[tree] = TREE_COOLDOWN_TIME

func find_nearest_tree() -> Node3D:
	if get_tree().paused:
		return null
	
	var trees = get_tree().get_nodes_in_group("tree")
	var nearest_tree: Node3D = null
	var nearest_distance = INF
	
	for tree in trees:
		if not is_instance_valid(tree):
			continue
		
		if tree in tree_cooldowns:
			continue
		
		if tree in visited_trees:
			continue
		
		if not tree.has_method("has_ripe_fruits") or not tree.has_ripe_fruits():
			if tree not in visited_trees and should_mark_tree_visited(tree):
				mark_tree_visited(tree)
			continue
		
		var distance = global_position.distance_to(tree.global_position)
		
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_tree = tree
	
	return nearest_tree

func get_npc_carried_fruits() -> int:
	return npc_carried_ripe_fruits

func get_npc_carried_kg() -> int:
	return npc_carried_ripe_kg

func get_npc_capacity() -> int:
	return max_carry_capacity

func is_npc_full() -> bool:
	return npc_carried_ripe_fruits >= max_carry_capacity

func get_total_harvested() -> int:
	return total_harvested_by_npc
