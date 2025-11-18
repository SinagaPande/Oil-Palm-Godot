extends Control
class_name UIManager

# Referensi ke elemen UI
@onready var ripe_label: Label = $RipeLabel
@onready var unripe_label: Label = $UnripeLabel
@onready var interaction_label: Label = $InteractionLabel
@onready var notification_label: Label = $NotificationLabel
@onready var npc_harvest_label: Label = $NpcHarvestLabel  # ⬅️ LABEL BARU

# Timer untuk auto-hide notifikasi
var notification_timer: Timer

func _ready():
	visible = true
	
	# Setup timer untuk notifikasi
	notification_timer = Timer.new()
	notification_timer.one_shot = true
	notification_timer.timeout.connect(_on_notification_timeout)
	add_child(notification_timer)
	
	# Sembunyikan label yang tidak perlu di awal
	interaction_label.visible = false
	notification_label.visible = false
	
	# ⬅️ PERBAIKAN: Tampilkan inventory labels dari awal
	show_inventory_labels()
	
	connect_to_game_systems()

func show_inventory_labels():
	# ⬅️ FUNGSI BARU: Tampilkan dan update inventory labels segera
	if ripe_label:
		ripe_label.visible = true
	if unripe_label:
		unripe_label.visible = true
	if npc_harvest_label:
		npc_harvest_label.visible = true  # ⬅️ TAMPILKAN LABEL NPC
	
	# Update dengan data awal
	update_ui_from_player()
	update_npc_harvest_display(0)  # ⬅️ INIT DENGAN NILAI 0

func connect_to_game_systems():
	await get_tree().process_frame
	
	# Connect ke InventorySystem
	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	if not inventory_system:
		var nodes = get_tree().get_nodes_in_group("inventory_system")
		if nodes.size() > 0:
			inventory_system = nodes[0]
	
	# Connect ke Player
	var player = get_node_or_null("/root/Node3D/Player")
	if not player:
		var player_nodes = get_tree().get_nodes_in_group("player")
		if player_nodes.size() > 0:
			player = player_nodes[0]
	
	# ⬅️ CONNECT KE NPC MANAGER
	var npc_manager = get_node_or_null("/root/Node3D/NPCManager")
	if not npc_manager:
		var npc_managers = get_tree().get_nodes_in_group("npc_manager")
		if npc_managers.size() > 0:
			npc_manager = npc_managers[0]
	
	if inventory_system:
		if inventory_system.has_signal("permanent_inventory_updated"):
			inventory_system.permanent_inventory_updated.connect(update_permanent_display)
		else:
			# ⬅️ FALLBACK: Update manual jika signal tidak ada
			update_ui_from_player()
	
	if player:
		if player.has_signal("carried_fruits_updated"):
			player.carried_fruits_updated.connect(update_carried_fruits)
		elif player.has_signal("player_fully_ready"):
			player.player_fully_ready.connect(_on_player_ready)
		else:
			# ⬅️ FALLBACK: Update manual jika signal tidak ada
			update_ui_from_player()
	
	# ⬅️ CONNECT SIGNAL NPC MANAGER
	if npc_manager:
		if npc_manager.has_signal("npc_total_harvest_updated"):
			npc_manager.npc_total_harvest_updated.connect(update_npc_harvest_display)
		# Update dengan nilai awal
		if npc_manager.has_method("get_total_npc_harvest"):
			var initial_harvest = npc_manager.get_total_npc_harvest()
			update_npc_harvest_display(initial_harvest)
	
	# ⬅️ PASTIKAN update dilakukan setelah connect
	update_ui_from_player()

# ⬅️ FUNGSI BARU: Update display buah yang dicuri NPC
func update_npc_harvest_display(total_kg: int):
	if npc_harvest_label:
		npc_harvest_label.visible = true
		npc_harvest_label.text = "Buah yang Dicuri: %d kg" % total_kg

func _on_player_ready():
	await get_tree().process_frame
	update_ui_from_player()

func update_ui_from_player():
	var player = get_node_or_null("/root/Node3D/Player")
	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	
	# ⬅️ PERBAIKAN: Gunakan nilai default jika node tidak ditemukan
	var carried_ripe = 0
	var delivered_ripe_kg = 0
	var collected_unripe_kg = 0
	
	if player and player.has_method("get_carried_ripe_fruits"):
		carried_ripe = player.get_carried_ripe_fruits()
	
	if inventory_system:
		if inventory_system.has_method("get_delivered_ripe_kg"):
			delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		if inventory_system.has_method("get_collected_unripe_kg"):
			collected_unripe_kg = inventory_system.get_collected_unripe_kg()
	
	# ⬅️ PASTIKAN label ditampilkan dan diupdate
	if ripe_label:
		ripe_label.visible = true
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]
	
	if unripe_label:
		unripe_label.visible = true
		unripe_label.text = "Buah mentah: %d kg" % collected_unripe_kg
	
	# ⬅️ PASTIKAN label ditampilkan dan diupdate
	if ripe_label:
		ripe_label.visible = true
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]
	
	if unripe_label:
		unripe_label.visible = true
		unripe_label.text = "Buah mentah: %d kg" % collected_unripe_kg

# Fungsi untuk menampilkan label interaksi (dipindahkan dari InteractionSystem)
func show_interaction_label(text: String):
	if interaction_label:
		interaction_label.text = text
		interaction_label.visible = true

# Fungsi untuk menyembunyikan label interaksi (dipindahkan dari InteractionSystem)
func hide_interaction_label():
	if interaction_label:
		interaction_label.visible = false

# Fungsi untuk membersihkan target (dipindahkan dari InteractionSystem)
func clear_target():
	hide_interaction_label()

# Fungsi untuk menampilkan notifikasi pengantaran (dipindahkan dari Player)
func show_delivery_notification(total_kg: int):
	if notification_label:
		var notification_text = "%d kg buah matang berhasil diantar!" % total_kg
		notification_label.text = notification_text
		notification_label.visible = true
		
		# Auto hide setelah 3 detik
		notification_timer.start(3.0)

func _on_notification_timeout():
	if notification_label:
		notification_label.visible = false

# Update display permanen (dari UI_Inventory.gd)
func update_permanent_display(delivered_ripe_kg: int, collected_unripe_kg: int):
	if ripe_label:
		var player = get_node_or_null("/root/Node3D/Player")
		var carried_ripe = 0
		if player and player.has_method("get_carried_ripe_fruits"):
			carried_ripe = player.get_carried_ripe_fruits()
		
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]
	
	if unripe_label:
		unripe_label.text = "Buah mentah: %d kg" % collected_unripe_kg

# Update buah yang dibawa (dari UI_Inventory.gd)
func update_carried_fruits(carried_ripe: int, _carried_kg: int):
	if ripe_label:
		var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
		var delivered_ripe_kg = 0
		if inventory_system:
			delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]

# Update display sementara (dari UI_Inventory.gd)
func update_temporary_display(carried_ripe: int, carried_kg: int):
	update_carried_fruits(carried_ripe, carried_kg)

# Update display umum (dari UI_Inventory.gd)
func update_display(ripe_count: int, ripe_kg: int):
	update_temporary_display(ripe_count, ripe_kg)
