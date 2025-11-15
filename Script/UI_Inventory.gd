extends Control

class_name UI_Inventory

@onready var ripe_label: Label = $RipeLabel
@onready var unripe_label: Label = $UnripeLabel

func _ready():
	visible = true
	update_display(0, 0)
	
	connect_to_inventory_system()

func connect_to_inventory_system():
	await get_tree().process_frame
	
	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	if not inventory_system:
		var nodes = get_tree().get_nodes_in_group("inventory_system")
		if nodes.size() > 0:
			inventory_system = nodes[0]
	
	# ✅ CARI PLAYER UNTUK REAL-TIME UPDATES
	var player = get_node_or_null("/root/Node3D/Player")
	if not player:
		var player_nodes = get_tree().get_nodes_in_group("player")
		if player_nodes.size() > 0:
			player = player_nodes[0]
	
	if inventory_system:
		inventory_system.permanent_inventory_updated.connect(update_permanent_display)
		print("UI_Inventory terhubung ke InventorySystem")
	
	if player:
		# ✅ HUBUNGKAN KE PLAYER UNTUK UPDATE BUAH YANG DIBAWA
		if player.has_signal("carried_fruits_updated"):
			player.carried_fruits_updated.connect(update_carried_fruits)
		elif player.has_signal("player_fully_ready"):
			player.player_fully_ready.connect(_on_player_ready)
		print("UI_Inventory terhubung ke Player")
	else:
		print("Warning: Player tidak ditemukan untuk UI")
	
	# ✅ INITIAL UPDATE
	update_ui_from_player()

func _on_player_ready():
	await get_tree().process_frame
	update_ui_from_player()

func update_ui_from_player():
	var player = get_node_or_null("/root/Node3D/Player")
	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	
	if player and inventory_system:
		var carried_ripe = player.get_carried_ripe_fruits()
		var delivered_ripe = inventory_system.get_delivered_ripe_count()
		var collected_unripe = inventory_system.get_collected_unripe_count()
		
		if ripe_label:
			ripe_label.text = "Buah matang: %d dibawa, %d diantar" % [carried_ripe, delivered_ripe]
		if unripe_label:
			unripe_label.text = "Poin buah mentah: %d" % collected_unripe

# ✅ PERBAIKI: Tampilkan kedua jenis buah
func update_permanent_display(delivered_ripe: int, collected_unripe: int):
	if ripe_label:
		# Ambil info buah yang sedang dibawa dari player
		var player = get_node_or_null("/root/Node3D/Player")
		var carried_ripe = 0
		if player and player.has_method("get_carried_ripe_fruits"):
			carried_ripe = player.get_carried_ripe_fruits()
		
		ripe_label.text = "Buah matang: %d dibawa, %d diantar" % [carried_ripe, delivered_ripe]
	
	if unripe_label:
		unripe_label.text = "Poin buah mentah: %d" % collected_unripe

# ✅ FUNGSI BARU: Update ketika buah yang dibawa berubah
func update_carried_fruits(carried_ripe: int):
	if ripe_label:
		var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
		var delivered_ripe = 0
		if inventory_system:
			delivered_ripe = inventory_system.get_delivered_ripe_count()
		
		ripe_label.text = "Buah matang: %d dibawa, %d diantar" % [carried_ripe, delivered_ripe]

func update_temporary_display(carried_ripe: int, _carried_unripe: int):
	update_carried_fruits(carried_ripe)

func update_display(ripe_count: int, unripe_count: int):
	update_temporary_display(ripe_count, unripe_count)
