extends CharacterBody3D
class_name HarvesterNPC

enum NPCState {
	SPAWN,
	SEARCH, 
	MOVE,
	HARVEST,
	IDLE,
	DELIVER
}

@export var move_speed: float = 3.0
@export var harvest_range: float = 2.0
@export var search_radius: float = 15.0
@export var max_carry_capacity: int = 10

@export var physical_harvest_distance: float = 40.0
@export var camera_frustum_margin: float = 100.0

var current_state: NPCState = NPCState.SPAWN
var target_tree: Node3D = null
var target_delivery_zone: Area3D = null
var harvest_timer: float = 0.0
var harvest_delay_per_fruit: float = 2.0
var fruits_to_harvest: int = 0
var current_harvest_count: int = 0

var carried_ripe_fruits: int = 0
var inventory_system: Node = null

var player_node: Node3D = null
var camera_node: Camera3D = null

var last_mode_check_time: float = 0.0
var mode_check_interval: float = 1.0
var current_harvest_mode: String = "physical"

var visited_trees: Array = []
var search_attempts: int = 0
const MAX_SEARCH_ATTEMPTS: int = 15
var last_tree_check_time: float = 0.0
const TREE_CHECK_INTERVAL: float = 5.0

var tree_cooldowns: Dictionary = {}
const TREE_COOLDOWN_TIME: float = 10.0

func _ready():
	add_to_group("harvester_npc")
	transition_to_state(NPCState.SPAWN)

func _physics_process(delta):
	state_process(delta)
	update_tree_cooldowns(delta)

func state_process(delta):
	match current_state:
		NPCState.SPAWN:
			initialize_npc()
			
		NPCState.SEARCH:
			var nearest_tree = find_nearest_tree()
			if nearest_tree:
				target_tree = nearest_tree
				transition_to_state(NPCState.MOVE)
			else:
				if carried_ripe_fruits > 0:
					find_delivery_zone()
				else:
					if should_reset_visited_trees():
						smart_reset_visited_trees()
					transition_to_state(NPCState.IDLE)
			
		NPCState.MOVE:
			if target_tree and is_instance_valid(target_tree):
				move_towards_target(target_tree.global_position)
				var distance_to_tree = global_position.distance_to(target_tree.global_position)
				if distance_to_tree <= harvest_range:
					transition_to_state(NPCState.HARVEST)
			elif target_delivery_zone and is_instance_valid(target_delivery_zone):
				move_towards_target(target_delivery_zone.global_position)
				var distance_to_zone = global_position.distance_to(target_delivery_zone.global_position)
				if distance_to_zone <= harvest_range:
					transition_to_state(NPCState.DELIVER)
			else:
				target_tree = null
				target_delivery_zone = null
				transition_to_state(NPCState.SEARCH)
			
		NPCState.HARVEST:
			harvest_timer += delta
			last_mode_check_time += delta
			
			if last_mode_check_time >= mode_check_interval:
				last_mode_check_time = 0.0
				update_harvest_mode()
			
			if harvest_timer >= harvest_delay_per_fruit:
				harvest_timer = 0.0
				harvest_next_fruit()
			
		NPCState.DELIVER:
			deliver_fruits()
			
		NPCState.IDLE:
			harvest_timer += delta
			if harvest_timer >= 3.0:
				harvest_timer = 0.0
				transition_to_state(NPCState.SEARCH)

func transition_to_state(new_state: NPCState):
	state_exit(current_state)
	current_state = new_state
	state_enter(new_state)

func state_enter(state: NPCState):
	match state:
		NPCState.SPAWN:
			pass
			
		NPCState.SEARCH:
			search_attempts += 1
			
			if search_attempts >= MAX_SEARCH_ATTEMPTS:
				smart_reset_visited_trees()
				search_attempts = 0
			
		NPCState.MOVE:
			pass
			
		NPCState.HARVEST:
			if target_tree and is_instance_valid(target_tree):
				if target_tree.has_method("set_harvesting_mode_active"):
					target_tree.set_harvesting_mode_active(true)
				
				fruits_to_harvest = calculate_fruits_to_harvest()
				current_harvest_count = 0
				harvest_timer = 0.0
				last_mode_check_time = 0.0
				
				update_harvest_mode()
			
		NPCState.DELIVER:
			pass
			
		NPCState.IDLE:
			pass

func state_exit(state: NPCState):
	match state:
		NPCState.HARVEST:
			if target_tree and is_instance_valid(target_tree) and target_tree.has_method("set_harvesting_mode_active"):
				target_tree.set_harvesting_mode_active(false)

func calculate_fruits_to_harvest() -> int:
	if not target_tree or not is_instance_valid(target_tree):
		return 0
	
	var available_fruits = 0
	if target_tree.has_method("get_ripe_count"):
		available_fruits = target_tree.get_ripe_count()
	
	var can_carry = max_carry_capacity - carried_ripe_fruits
	return min(available_fruits, can_carry)

func update_tree_cooldowns(delta: float):
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

func smart_reset_visited_trees():
	var trees_to_keep: Array = []
	
	for tree in visited_trees:
		if not is_instance_valid(tree):
			continue
		
		if tree.has_method("has_ripe_fruits") and not tree.has_ripe_fruits():
			trees_to_keep.append(tree)
	
	visited_trees = trees_to_keep

func should_reset_visited_trees() -> bool:
	var all_trees = get_tree().get_nodes_in_group("tree")
	var available_trees = 0
	
	for tree in all_trees:
		if not is_instance_valid(tree):
			continue
		if tree in visited_trees:
			continue
		if tree.has_method("has_ripe_fruits") and tree.has_ripe_fruits():
			available_trees += 1
	
	return available_trees == 0 and visited_trees.size() > 0

func update_harvest_mode():
	var new_mode = determine_harvest_mode()
	if new_mode != current_harvest_mode:
		current_harvest_mode = new_mode

func determine_harvest_mode() -> String:
	if not player_node or not camera_node or not target_tree:
		return "physical"
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	var is_in_frustum = is_tree_in_camera_frustum()
	
	if distance_to_player > physical_harvest_distance or not is_in_frustum:
		return "physical"
	else:
		return "simulated"

func is_tree_in_camera_frustum() -> bool:
	if not camera_node or not target_tree:
		return false
	
	var tree_screen_pos = camera_node.unproject_position(target_tree.global_position)
	var viewport_size = get_viewport().get_visible_rect().size
	
	return (
		tree_screen_pos.x >= -camera_frustum_margin and
		tree_screen_pos.x <= viewport_size.x + camera_frustum_margin and
		tree_screen_pos.y >= -camera_frustum_margin and
		tree_screen_pos.y <= viewport_size.y + camera_frustum_margin
	)

func harvest_next_fruit():
	if not target_tree or not is_instance_valid(target_tree):
		transition_to_state(NPCState.SEARCH)
		return
	
	if current_harvest_count >= fruits_to_harvest or carried_ripe_fruits >= max_carry_capacity:
		if should_mark_tree_visited(target_tree):
			mark_tree_visited(target_tree)
		
		transition_to_state(NPCState.SEARCH)
		return
	
	var harvested_count = 0
	
	match current_harvest_mode:
		"physical":
			harvested_count = harvest_physical(target_tree)
		"simulated":
			harvested_count = harvest_simulated(target_tree)
	
	if harvested_count > 0:
		current_harvest_count += harvested_count
		carried_ripe_fruits += harvested_count
		
		if inventory_system and inventory_system.has_method("add_delivered_ripe_fruits"):
			inventory_system.add_delivered_ripe_fruits(harvested_count)
	else:
		if target_tree and is_instance_valid(target_tree):
			tree_cooldowns[target_tree] = TREE_COOLDOWN_TIME
		
		transition_to_state(NPCState.SEARCH)

func should_mark_tree_visited(tree: Node3D) -> bool:
	if not tree or not is_instance_valid(tree):
		return false
	
	if tree.has_method("has_ripe_fruits"):
		var has_ripe = tree.has_ripe_fruits()
		if not has_ripe:
			return true
		else:
			return false
	
	if tree.has_method("get_ripe_count"):
		var ripe_count = tree.get_ripe_count()
		if ripe_count == 0:
			return true
		else:
			return false
	
	return false

func mark_tree_visited(tree: Node3D):
	if tree in visited_trees:
		return
	
	visited_trees.append(tree)

func harvest_physical(tree: Node3D) -> int:
	if tree and tree.has_method("harvest_physical"):
		return tree.harvest_physical(global_position)
	return 0

func harvest_simulated(tree: Node3D) -> int:
	if tree and tree.has_method("harvest_simulated"):
		return tree.harvest_simulated()
	return 0

func deliver_fruits():
	if not target_delivery_zone or not is_instance_valid(target_delivery_zone):
		transition_to_state(NPCState.SEARCH)
		return
	
	if carried_ripe_fruits > 0:
		if inventory_system and inventory_system.has_method("add_delivered_ripe_fruits"):
			inventory_system.add_delivered_ripe_fruits(carried_ripe_fruits)
		
		if target_delivery_zone.has_method("deliver_fruits"):
			target_delivery_zone.deliver_fruits(carried_ripe_fruits, 0)
		
		carried_ripe_fruits = 0
	
	target_delivery_zone = null
	
	visited_trees.clear()
	tree_cooldowns.clear()
	search_attempts = 0
	
	transition_to_state(NPCState.SEARCH)

func find_nearest_tree() -> Node3D:
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

func find_delivery_zone():
	var delivery_zones = get_tree().get_nodes_in_group("delivery_zone")
	if delivery_zones.size() > 0:
		var nearest_zone: Area3D = null
		var nearest_distance = 50.0
		
		for zone in delivery_zones:
			if is_instance_valid(zone):
				var distance = global_position.distance_to(zone.global_position)
				if distance <= nearest_distance:
					nearest_distance = distance
					nearest_zone = zone
		
		if nearest_zone:
			target_delivery_zone = nearest_zone
			target_tree = null
			return true
	
	return false

func move_towards_target(target_position: Vector3):
	var direction = (target_position - global_position).normalized()
	direction.y = 0
	
	velocity = direction * move_speed
	velocity.y = -9.8
	
	if is_near_obstacle():
		velocity += get_avoidance_vector() * 2.0
	
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
	
	move_and_slide()
	
func is_near_obstacle() -> bool:
	var viewport = get_tree().root
	var space_state = viewport.get_world_3d().direct_space_state
	
	var check_distance = 2.0
	var forward = -global_transform.basis.z
	var check_position = global_position + forward * check_distance
	
	var query = PhysicsRayQueryParameters3D.create(global_position, check_position)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()
	
func get_avoidance_vector() -> Vector3:
	var viewport = get_tree().root
	var space_state = viewport.get_world_3d().direct_space_state
	var avoidance = Vector3.ZERO
	
	var directions = [
		-global_transform.basis.z,
		global_transform.basis.x,
		-global_transform.basis.x,
		global_transform.basis.z,
	]
	
	var check_distance = 3.0
	
	for i in range(directions.size()):
		var direction = directions[i]
		var check_position = global_position + direction * check_distance
		
		var query = PhysicsRayQueryParameters3D.create(global_position, check_position)
		query.exclude = [self]
		
		var result = space_state.intersect_ray(query)
		
		if not result.is_empty():
			var hit_position = result.get("position", Vector3.ZERO)
			if hit_position != Vector3.ZERO:
				var hit_distance = global_position.distance_to(hit_position)
				var avoidance_strength = 1.0 - (hit_distance / check_distance)
				
				avoidance -= direction * avoidance_strength
	
	return avoidance.normalized()

func initialize_npc():
	find_player_and_camera()
	find_inventory_system()
	transition_to_state(NPCState.SEARCH)

func find_inventory_system():
	var inventory_systems = get_tree().get_nodes_in_group("inventory_system")
	if inventory_systems.size() > 0:
		inventory_system = inventory_systems[0]

func find_player_and_camera():
	if not is_inside_tree():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
		if player_node.has_node("PlayerController/Camera3D"):
			camera_node = player_node.get_node("PlayerController/Camera3D")
		else:
			camera_node = find_camera_recursive(player_node)

func find_camera_recursive(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found = find_camera_recursive(child)
		if found:
			return found
	return null
