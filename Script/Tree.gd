extends Node3D

@export var fruit_scene: PackedScene
@export var auto_ripe_chance: bool = true  # Opsi untuk auto chance
@export var min_ripe_chance: float = 0.3   # Peluang minimal buah masak
@export var max_ripe_chance: float = 0.8   # Peluang maksimal buah masak

var ripe_chance: float = 0.5

func _ready():
	# Generate random ripe chance jika auto mode
	if auto_ripe_chance:
		ripe_chance = randf_range(min_ripe_chance, max_ripe_chance)
		print(name + " - Ripe chance: " + str(ripe_chance * 100) + "%")
	
	spawn_initial_fruits()

# GANTI fungsi spawn_initial_fruits() dengan ini:
func spawn_initial_fruits():
	var spawn_points_node = $SpawnPoints
	
	if not spawn_points_node:
		spawn_points_node = get_node_or_null("SpawnPoints")
	
	if not spawn_points_node:
		spawn_points_node = find_child("SpawnPoints", true, false)
	
	if not spawn_points_node:
		push_warning("SpawnPoints node tidak ditemukan di tree: " + name)
		return
	
	var markers = []
	# Kumpulkan semua marker
	for child in spawn_points_node.get_children():
		if child is Marker3D:
			markers.append(child)
	
	# Hitung jumlah buah masak berdasarkan ripe_chance
	var total_markers = markers.size()
	var ripe_count = int(total_markers * ripe_chance)
	
	# Pastikan ada minimal 1 buah masak dan maksimal total_markers-1
	ripe_count = clamp(ripe_count, 1, total_markers - 1)
	
	# Buat array jenis buah
	var fruit_types = []
	for i in range(total_markers):
		if i < ripe_count:
			fruit_types.append("Masak")
		else:
			fruit_types.append("Mentah")
	
	# Acak distribusi jenis buah
	shuffle_array(fruit_types)
	
	# Spawn buah dengan distribusi yang sudah diacak
	for i in range(markers.size()):
		spawn_fruit_with_type(markers[i], fruit_types[i])

func shuffle_array(arr: Array):
	for i in range(arr.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

func spawn_fruit_with_type(marker: Marker3D, fruit_type: String):
	if not fruit_scene:
		return
	
	var fruit_instance = fruit_scene.instantiate()
	add_child(fruit_instance)
	
	# Set jenis buah sesuai parameter
	if fruit_instance.has_method("set_fruit_type"):
		fruit_instance.set_fruit_type(fruit_type)
	else:
		fruit_instance.fruit_type = fruit_type
		if fruit_instance.has_method("setup_fruit_model"):
			fruit_instance.setup_fruit_model()
	
	fruit_instance.global_position = marker.global_position
	fruit_instance.global_rotation = marker.global_rotation
	
func shuffle_markers(markers: Array):
	# Fisher-Yates shuffle algorithm
	for i in range(markers.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = markers[i]
		markers[i] = markers[j]
		markers[j] = temp

func spawn_fruit_at_marker(marker: Marker3D):
	if not fruit_scene:
		return
	
	var fruit_instance = fruit_scene.instantiate()
	add_child(fruit_instance)
	
	# Set jenis buah secara random dengan ripe_chance yang sudah ditentukan
	var random_type = "Masak" if randf() <= ripe_chance else "Mentah"
	
	# GUNAKAN FUNGSI set_fruit_type() bukan set properti langsung
	if fruit_instance.has_method("set_fruit_type"):
		fruit_instance.set_fruit_type(random_type)
	else:
		# Fallback jika method tidak ada
		fruit_instance.fruit_type = random_type
		if fruit_instance.has_method("setup_fruit_model"):
			fruit_instance.setup_fruit_model()
	
	fruit_instance.global_position = marker.global_position
	fruit_instance.global_rotation = marker.global_rotation

# Fungsi untuk debug - lihat distribusi buah di pohon
func print_fruit_distribution():
	var ripe_count = 0
	var unripe_count = 0
	
	for child in get_children():
		if child.is_in_group("buah"):
			if child.has_method("get_fruit_type"):
				var fruit_type = child.get_fruit_type()
				if fruit_type == "Masak":
					ripe_count += 1
				else:
					unripe_count += 1
	
	print(name + " - Buah Masak: " + str(ripe_count) + ", Buah Mentah: " + str(unripe_count))
