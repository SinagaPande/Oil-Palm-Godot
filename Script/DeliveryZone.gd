extends Area3D

class_name DeliveryZone

# Konfigurasi LOD - ARRAY untuk multiple models
@export var lod_models_high: Array[PackedScene] = []  # [MuatSawit_1_High, MuatSawit_2_High, ...]
@export var lod_models_low: Array[PackedScene] = []   # [MuatSawit_1_Low, MuatSawit_2_Low, ...]

var current_lod_level: String = "high"
var lod_update_timer: float = 0.0
const LOD_UPDATE_INTERVAL: float = 0.3
const LOD_HIGH_DISTANCE = 10
const LOD_LOW_DISTANCE = 15

# Referensi ke model containers
var model_containers: Array[Node3D] = []
var player_node: Node3D = null
var camera_node: Camera3D = null

# Variabel existing...
@export var weight_threshold_per_model: int = 250
var current_weight: int = 0

func _ready():
	add_to_group("delivery_zone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Inisialisasi sistem LOD
	initialize_lod_system()
	initialize_progressive_models()

func initialize_lod_system():
	# Cari player dan camera
	find_player_and_camera()
	
	# Setup model high-poly pertama kali
	setup_lod_model("high")

func find_player_and_camera():
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

func _process(delta):
	if not player_node or not camera_node:
		return
	
	# Update LOD dengan interval
	lod_update_timer += delta
	if lod_update_timer >= LOD_UPDATE_INTERVAL:
		lod_update_timer = 0.0
		update_lod()

func update_lod():
	if not player_node:
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	var new_lod_level = "high" if distance_to_player <= LOD_HIGH_DISTANCE else "low"
	
	if new_lod_level != current_lod_level:
		current_lod_level = new_lod_level
		setup_lod_model(new_lod_level)

func setup_lod_model(lod_level: String):
	# Hapus semua model existing
	clear_all_models()
	
	# Pilih array model berdasarkan LOD level
	var selected_models = lod_models_high if lod_level == "high" else lod_models_low
	
	# Instantiate semua model
	for i in range(selected_models.size()):
		if selected_models[i]:
			var model_instance = selected_models[i].instantiate()
			add_child(model_instance)
			model_containers.append(model_instance)
			
			# Position model sesuai dengan layout yang diinginkan
			setup_model_position(model_instance, i)
	
	# Terapkan progres visibility
	update_model_progression()

func clear_all_models():
	for container in model_containers:
		if is_instance_valid(container):
			container.queue_free()
	model_containers.clear()

func setup_model_position(model_instance: Node3D, index: int):
	# Atur posisi model berdasarkan index
	# Contoh: susunan linear sepanjang sumbu X
	model_instance.position.x = index * 0  # Jarak 2 unit antar model
	# Atau sesuaikan dengan layout scene yang diinginkan

func update_model_progression():
	var models_to_show = calculate_models_to_show()
	
	# Terapkan visibility berdasarkan progres berat
	for i in range(model_containers.size()):
		if i < models_to_show:
			model_containers[i].visible = true
		else:
			model_containers[i].visible = false

# FUNGSI YANG DIPINDAH DARI KODE ASLI (PERBAIKAN)
func initialize_progressive_models():
	# Load data progres dari save system (jika ada)
	load_progress_data()

func load_progress_data():
	# Coba load data progres dari inventory system
	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	if inventory_system and inventory_system.has_method("get_delivered_ripe_kg"):
		current_weight = inventory_system.get_delivered_ripe_kg()
		update_model_progression()
	
	# Atau coba load dari save system jika ada
	elif has_node("/root/SaveSystem"):
		var save_system = get_node("/root/SaveSystem")
		if save_system.has_method("get_delivered_weight"):
			current_weight = save_system.get_delivered_weight()
			update_model_progression()

# FUNGSI YANG DIPINDAH DARI KODE ASLI
func calculate_models_to_show() -> int:
	var models_to_show = 0
	
	# LOGIKA BARU: Minimal 1 model terlihat jika ada berat > 0 kg
	if current_weight > 0:
		models_to_show = 1  # Minimal tampilkan model pertama
		# Untuk berat di atas threshold, tambah model
		if current_weight >= weight_threshold_per_model:
			models_to_show = (current_weight / weight_threshold_per_model) + 1
	
	models_to_show = min(models_to_show, lod_models_high.size())  # Maksimal sesuai jumlah model
	return models_to_show

func save_progress_data():
	# Simpan ke save system jika ada
	if has_node("/root/SaveSystem"):
		var save_system = get_node("/root/SaveSystem")
		if save_system.has_method("set_delivered_weight"):
			save_system.set_delivered_weight(current_weight)

# FUNGSI SIGNAL HANDLER YANG DIPINDAH DARI KODE ASLI
func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("set_in_delivery_zone"):
			body.set_in_delivery_zone(true, self)

func _on_body_exited(body):
	if body.is_in_group("player"):
		if body.has_method("set_in_delivery_zone"):
			body.set_in_delivery_zone(false, null)

# FUNGSI DELIVERY YANG DIPINDAH DARI KODE ASLI
func deliver_fruits(ripe_count: int, unripe_count: int) -> bool:
	if ripe_count > 0 or unripe_count > 0:
		fruits_delivered.emit(ripe_count, unripe_count)
		
		# Hitung total berat yang diantar (dalam kg)
		var total_weight_kg = 0
		if ripe_count > 0:
			# Estimasi: buah matang 30-40 kg per buah, kita pakai rata-rata 35kg
			total_weight_kg += ripe_count * 35
		
		if unripe_count > 0:
			# Estimasi: buah mentah 25-30 kg per buah, kita pakai rata-rata 27.5kg
			total_weight_kg += unripe_count * 27
		
		# Update progres model
		add_delivered_weight(total_weight_kg)
		
		return true
	return false

# FUNGSI TAMBAHAN YANG DIPINDAH DARI KODE ASLI
func add_delivered_weight(weight_kg: int):
	current_weight += weight_kg
	update_model_progression()  # Ini akan update model LOD yang aktif
	save_progress_data()

# Fungsi untuk debugging dan testing
func debug_set_weight(weight_kg: int):
	current_weight = weight_kg
	update_model_progression()
	print("Debug: Set weight to ", weight_kg, " kg")

func get_current_weight() -> int:
	return current_weight

func get_models_visible_count() -> int:
	var count = 0
	for container in model_containers:
		if is_instance_valid(container) and container.visible:
			count += 1
	return count

# SIGNAL YANG DIPINDAH DARI KODE ASLI
signal fruits_delivered(ripe_count, unripe_count)
