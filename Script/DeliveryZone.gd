extends Area3D

class_name DeliveryZone

signal fruits_delivered(ripe_count, unripe_count)

# Konfigurasi progresi model
@export var weight_threshold_per_model: int = 150  # 120 kg per model
var muat_sawit_models: Array[Node3D] = []
var current_weight: int = 0

func _ready():
	add_to_group("delivery_zone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Inisialisasi sistem model progresif
	initialize_progressive_models()

func initialize_progressive_models():
	# Cari semua model Muat Sawit
	muat_sawit_models.clear()
	
	# Cari node StaticBody3D yang berisi model L300
	var static_body = find_child("StaticBody3D")
	if static_body:
		# Cari node L300
		var l300_node = static_body.find_child("L300")
		if l300_node:
			# Kumpulkan semua model Muat Sawit
			for i in range(1, 6):  # dari Muat Sawit_1 sampai Muat Sawit_5
				var model_name = "Muat Sawit_%d" % i
				var model_node = l300_node.find_child(model_name, true, false)
				if model_node:
					muat_sawit_models.append(model_node)
					# Sembunyikan semua model awalnya
					model_node.visible = false
					print("Found model: ", model_name)
	
	print("Total Muat Sawit models found: ", muat_sawit_models.size())
	
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

func update_model_progression():
	var models_to_show = 0
	
	# LOGIKA BARU: Minimal 1 model terlihat jika ada berat > 0 kg
	if current_weight > 0:
		models_to_show = 1  # Minimal tampilkan model pertama
		# Untuk berat di atas threshold, tambah model
		if current_weight >= weight_threshold_per_model:
			models_to_show = (current_weight / weight_threshold_per_model) + 1
	
	models_to_show = min(models_to_show, muat_sawit_models.size())
	
	print("Updating model progression: ", current_weight, " kg -> ", models_to_show, " models")
	
	# Tampilkan/sembunyikan model berdasarkan progres
	for i in range(muat_sawit_models.size()):
		if i < models_to_show:
			muat_sawit_models[i].visible = true
		else:
			muat_sawit_models[i].visible = false

func add_delivered_weight(weight_kg: int):
	current_weight += weight_kg
	update_model_progression()
	
	# Simpan progres (jika ada save system)
	save_progress_data()

func save_progress_data():
	# Simpan ke save system jika ada
	if has_node("/root/SaveSystem"):
		var save_system = get_node("/root/SaveSystem")
		if save_system.has_method("set_delivered_weight"):
			save_system.set_delivered_weight(current_weight)

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("set_in_delivery_zone"):
			body.set_in_delivery_zone(true, self)

func _on_body_exited(body):
	if body.is_in_group("player"):
		if body.has_method("set_in_delivery_zone"):
			body.set_in_delivery_zone(false, null)

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

# Fungsi untuk debugging dan testing
func debug_set_weight(weight_kg: int):
	current_weight = weight_kg
	update_model_progression()
	print("Debug: Set weight to ", weight_kg, " kg")

func get_current_weight() -> int:
	return current_weight

func get_models_visible_count() -> int:
	var count = 0
	for model in muat_sawit_models:
		if model.visible:
			count += 1
	return count
