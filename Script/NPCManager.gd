extends Node
class_name NPCManager

@export var harvester_npc_scene: PackedScene
@export var max_npcs: int = 1
@export var spawn_interval: float = 10.0
@export var manual_spawn_points: Array[Marker3D] = []
@export var use_manual_spawn_points: bool = true

var spawn_points: Array[Marker3D] = []
var active_npcs: Array[HarvesterNPC] = []
var spawn_timer: float = 0.0
var total_npc_harvest: int = 0

@export var ground_collision_mask: int = 1
@export var spawn_height_offset: float = 1.0

signal npc_total_harvest_updated(total_kg)

func _ready():
	add_to_group("npc_manager")
	call_deferred("initialize_spawn_system")

func initialize_spawn_system():
	find_spawn_points()
	
	for i in range(max_npcs):
		if spawn_points.size() > 0:
			spawn_harvester_npc()

func _process(delta):
	if active_npcs.size() < max_npcs:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			if spawn_points.size() > 0:
				spawn_harvester_npc()

func find_spawn_points():
	spawn_points.clear()
	
	if use_manual_spawn_points:
		for marker in manual_spawn_points:
			if is_instance_valid(marker) and marker is Marker3D:
				spawn_points.append(marker)
				if not marker.is_in_group("npc_spawn"):
					marker.add_to_group("npc_spawn")
	else:
		var root = get_tree().root
		find_markers_recursive(root)

func find_markers_recursive(node: Node):
	for child in node.get_children():
		if child is Marker3D:
			if should_use_as_spawn_point(child):
				spawn_points.append(child)
				if not child.is_in_group("npc_spawn"):
					child.add_to_group("npc_spawn")
		find_markers_recursive(child)

func should_use_as_spawn_point(marker: Marker3D) -> bool:
	var marker_name = marker.name.to_lower()
	
	if ("spawn" in marker_name or "npc" in marker_name or "harvester" in marker_name):
		return true
	
	if marker.is_in_group("npc_spawn"):
		return true
	
	return false

func spawn_harvester_npc():
	if not harvester_npc_scene:
		return
	
	if spawn_points.size() == 0:
		return
	
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	var safe_spawn_position = get_safe_spawn_position(spawn_point.global_position)
	
	var npc_instance = harvester_npc_scene.instantiate()
	if not npc_instance:
		return
	
	call_deferred("add_npc_to_scene", npc_instance, safe_spawn_position)

func get_safe_spawn_position(original_position: Vector3) -> Vector3:
	var viewport = get_tree().root
	var space_state = viewport.get_world_3d().direct_space_state
	
	var ray_origin = original_position + Vector3.UP * 10.0
	var ray_end = original_position + Vector3.DOWN * 50.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = ground_collision_mask
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position + Vector3.UP * spawn_height_offset
	else:
		return Vector3(original_position.x, spawn_height_offset, original_position.z)

func add_npc_to_scene(npc_instance: HarvesterNPC, spawn_position: Vector3):
	if not is_instance_valid(npc_instance):
		return
	
	get_parent().add_child(npc_instance)
	npc_instance.global_position = spawn_position
	
	if npc_instance.has_signal("npc_harvested_fruits"):
		npc_instance.npc_harvested_fruits.connect(_on_npc_harvested_fruits)
	
	if npc_instance.has_signal("npc_returned_to_spawn"):
		npc_instance.npc_returned_to_spawn.connect(_on_npc_returned_to_spawn)
	
	if npc_instance.has_method("initialize_npc"):
		npc_instance.call_deferred("initialize_npc")
	
	active_npcs.append(npc_instance)

func _on_npc_returned_to_spawn(npc_instance: HarvesterNPC):
	if npc_instance.has_signal("npc_harvested_fruits"):
		npc_instance.npc_harvested_fruits.disconnect(_on_npc_harvested_fruits)
	if npc_instance.has_signal("npc_returned_to_spawn"):
		npc_instance.npc_returned_to_spawn.disconnect(_on_npc_returned_to_spawn)
	
	if npc_instance in active_npcs:
		active_npcs.erase(npc_instance)

func _on_npc_harvested_fruits(harvested_kg: int):
	total_npc_harvest += harvested_kg
	npc_total_harvest_updated.emit(total_npc_harvest)

func reset_npc_harvest():
	total_npc_harvest = 0
	
	for npc in active_npcs:
		if is_instance_valid(npc):
			if npc.has_method("reset_after_carrying"):
				npc.reset_after_carrying()
	
	npc_total_harvest_updated.emit(0)

func get_active_npc_count() -> int:
	return active_npcs.size()

func set_max_npcs(new_max: int):
	max_npcs = new_max
	while active_npcs.size() > max_npcs:
		var npc = active_npcs.pop_back()
		if is_instance_valid(npc):
			npc.queue_free()

func add_spawn_point(marker: Marker3D):
	if is_instance_valid(marker) and marker is Marker3D:
		if marker not in spawn_points:
			spawn_points.append(marker)

func remove_spawn_point(marker: Marker3D):
	if marker in spawn_points:
		spawn_points.erase(marker)

func clear_spawn_points():
	spawn_points.clear()

func refresh_spawn_points():
	find_spawn_points()

func configure_manager(npc_scene: PackedScene, max_count: int = 1):
	harvester_npc_scene = npc_scene
	max_npcs = max_count

func get_total_npc_harvest() -> int:
	return total_npc_harvest
