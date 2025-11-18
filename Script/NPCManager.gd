extends Node
class_name NPCManager

@export var harvester_npc_scene: PackedScene
@export var max_npcs: int = 1
@export var spawn_interval: float = 10.0

@export var manual_spawn_points: Array[Marker3D] = []
@export var use_manual_spawn_points: bool = false

var spawn_points: Array[Marker3D] = []
var active_npcs: Array[HarvesterNPC] = []
var spawn_timer: float = 0.0
var is_ready: bool = false

@export var ground_collision_mask: int = 1
@export var spawn_height_offset: float = 1.0

# Variabel untuk tracking total panen semua NPC
var total_npc_harvest: int = 0
signal npc_total_harvest_updated(total_kg)

func _ready():
	add_to_group("npc_manager")
	is_ready = true
	call_deferred("initialize_spawn_system")

func initialize_spawn_system():
	find_spawn_points()
	
	for i in range(max_npcs):
		if spawn_points.size() > 0:
			spawn_harvester_npc()

func _process(delta):
	if not is_ready:
		return
	
	if active_npcs.size() < max_npcs:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			if spawn_points.size() > 0:
				spawn_harvester_npc()

func find_spawn_points():
	spawn_points.clear()
	
	if use_manual_spawn_points and manual_spawn_points.size() > 0:
		for marker in manual_spawn_points:
			if is_instance_valid(marker) and marker is Marker3D:
				spawn_points.append(marker)
	else:
		var root = get_tree().root
		find_markers_recursive(root)

func find_markers_recursive(node: Node):
	for child in node.get_children():
		if child is Marker3D:
			if should_use_as_spawn_point(child):
				spawn_points.append(child)
		find_markers_recursive(child)

func should_use_as_spawn_point(marker: Marker3D) -> bool:
	var marker_name = marker.name.to_lower()
	
	if ("spawn" in marker_name or "npc" in marker_name or "harvester" in marker_name):
		return true
	
	if marker.is_in_group("npc_spawn"):
		return true
	
	return true

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
	
	call_deferred("add_npc_to_scene", npc_instance, safe_spawn_position, spawn_point.global_rotation)

func get_safe_spawn_position(original_position: Vector3) -> Vector3:
	var viewport = get_tree().root
	var space_state = viewport.get_world_3d().direct_space_state
	
	var ray_origin = original_position + Vector3.UP * 10.0
	var ray_end = original_position + Vector3.DOWN * 50.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = ground_collision_mask
	query.exclude = []
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var ground_position = result.position
		return ground_position + Vector3.UP * spawn_height_offset
	else:
		return Vector3(original_position.x, spawn_height_offset, original_position.z)

func add_npc_to_scene(npc_instance: HarvesterNPC, spawn_position: Vector3, spawn_rotation: Vector3):
	get_parent().add_child(npc_instance)
	npc_instance.global_position = spawn_position
	npc_instance.global_rotation = spawn_rotation
	
	# Connect signal untuk menerima data panen dari NPC
	if npc_instance.has_signal("npc_harvested_fruits"):
		npc_instance.npc_harvested_fruits.connect(_on_npc_harvested_fruits)
	
	if npc_instance.has_method("initialize_npc"):
		npc_instance.call_deferred("initialize_npc")
	
	active_npcs.append(npc_instance)

func _on_npc_harvested_fruits(harvested_count: int, _total_harvested_kg: int):
	# Ubah tracking dari jumlah buah menjadi kg (integer)
	var harvested_kg = harvested_count * randi_range(30, 40)  # Estimasi kg
	total_npc_harvest += harvested_kg  # Sekarang total_npc_harvest adalah integer
	
	# ⬅️ PANCAHKAN SIGNAL BARU SETELAH UPDATE TOTAL
	npc_total_harvest_updated.emit(total_npc_harvest)
	
	print("=== NPC HARVEST REPORT ===")
	print("Buah dipanen saat ini: %d buah (%d kg)" % [harvested_count, harvested_kg])
	print("Total buah dipanen NPC: %d kg" % total_npc_harvest)
	print("Jumlah NPC aktif: %d" % active_npcs.size())
	print("==========================")


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

# Method untuk mendapatkan total panen semua NPC
func get_total_npc_harvest() -> int:
	return total_npc_harvest

# Method untuk menampilkan status semua NPC
func show_npc_status():
	print("=== NPC STATUS ===")
	print("Total NPC aktif: %d" % active_npcs.size())
	print("Total buah dipanen: %.1f kg" % total_npc_harvest)
	
	for i in range(active_npcs.size()):
		var npc = active_npcs[i]
		if is_instance_valid(npc):
			var carried = npc.get_npc_carried_fruits()
			var carried_kg = npc.get_npc_carried_kg()
			var total = npc.get_total_harvested()
			print("NPC %d: Membawa %d buah (%.1f kg), Total dipanen: %.1f kg" % [i, carried, carried_kg, total])
	
	print("==================")
