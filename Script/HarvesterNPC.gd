extends CharacterBody3D
class_name HarvesterNPC

enum NPCState {
	SPAWN,
	SEARCH, 
	MOVE,
	HARVEST,
	IDLE
}

@export var move_speed: float = 3.0
@export var harvest_range: float = 2.0
@export var search_radius: float = 15.0
@export var max_carry_capacity: int = 10

@export var physical_harvest_distance: float = 40.0
@export var camera_frustum_margin: float = 100.0

var current_state: NPCState = NPCState.SPAWN
var target_tree: Node3D = null
var harvest_timer: float = 0.0
var harvest_delay_per_fruit: float = 2.0
var fruits_to_harvest: int = 0
var current_harvest_count: int = 0

# Inventory NPC yang terpisah dari player
var npc_carried_ripe_fruits: int = 0
var total_harvested_by_npc: int = 0  # Total buah yang sudah dipanen NPC

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

# Signal untuk mengirim data panen NPC
signal npc_harvested_fruits(harvested_count, total_harvested)

# Collision configuration
var collision_shape: CollisionShape3D = null

func _ready():
	add_to_group("harvester_npc")
	setup_collision_config()
	transition_to_state(NPCState.SPAWN)

func setup_collision_config():
	# Cari CollisionShape3D dan atur untuk bisa menembus object
	collision_shape = find_child("CollisionShape3D")
	if collision_shape:
		# Set collision mask untuk menghindari tabrakan dengan object static
		collision_mask = 0x00000001  # Hanya layer 1 (ground biasanya)
		# Non-aktifkan collision dengan object lain
		set_collision_layer_value(2, false)  # Player
		set_collision_layer_value(3, false)  # NPC lain  
		set_collision_layer_value(4, false)  # Object static
		set_collision_layer_value(5, false)  # Buah
		
		# Atur collision shape menjadi trigger-only
		if collision_shape.shape is CapsuleShape3D or collision_shape.shape is SphereShape3D:
			collision_shape.shape.radius *= 0.8  # Sedikit perkecil untuk memudahkan navigasi

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
				if npc_carried_ripe_fruits > 0:
					# NPC tidak mengantar, tapi tetap reset setelah membawa buah
					reset_after_carrying()
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
			else:
				target_tree = null
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
			
		NPCState.IDLE:
			harvest_timer += delta
			if harvest_timer >= 3.0:
				harvest_timer = 0.0
				transition_to_state(NPCState.SEARCH)

func reset_after_carrying():
	# Reset state setelah NPC membawa buah (tidak mengantar ke zone)
	npc_carried_ripe_fruits = 0
	visited_trees.clear()
	tree_cooldowns.clear()
	search_attempts = 0
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
	
	var can_carry = max_carry_capacity - npc_carried_ripe_fruits
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
	
	if current_harvest_count >= fruits_to_harvest or npc_carried_ripe_fruits >= max_carry_capacity:
		if should_mark_tree_visited(target_tree):
			mark_tree_visited(target_tree)
		
		# Setelah panen selesai, reset state (tidak perlu ke delivery zone)
		reset_after_carrying()
		return
	
	var harvested_count = 0
	
	match current_harvest_mode:
		"physical":
			harvested_count = harvest_physical(target_tree)
		"simulated":
			harvested_count = harvest_simulated(target_tree)
	
	if harvested_count > 0:
		current_harvest_count += harvested_count
		npc_carried_ripe_fruits += harvested_count
		total_harvested_by_npc += harvested_count
		
		# Kirim signal dengan data panen (TIDAK masuk ke inventory system)
		npc_harvested_fruits.emit(harvested_count, total_harvested_by_npc)
		
		# Tampilkan output di console
		print("NPC memanen %d buah matang. Total dipanen: %d" % [harvested_count, total_harvested_by_npc])
		
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

func move_towards_target(target_position: Vector3):
	var direction = (target_position - global_position).normalized()
	direction.y = 0
	
	velocity = direction * move_speed
	velocity.y = -9.8
	
	# Simplified movement tanpa obstacle avoidance yang kompleks
	# karena collision sudah diatur untuk menembus object
	
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
	
	move_and_slide()

func initialize_npc():
	find_player_and_camera()
	transition_to_state(NPCState.SEARCH)

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

# Method untuk mendapatkan status inventory NPC
func get_npc_carried_fruits() -> int:
	return npc_carried_ripe_fruits

func get_npc_capacity() -> int:
	return max_carry_capacity

func is_npc_full() -> bool:
	return npc_carried_ripe_fruits >= max_carry_capacity

func get_total_harvested() -> int:
	return total_harvested_by_npc
