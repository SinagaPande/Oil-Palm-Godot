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
	
	if inventory_system:
		inventory_system.permanent_inventory_updated.connect(update_permanent_display)
		print("UI_Inventory terhubung ke InventorySystem")
	else:
		print("Warning: InventorySystem tidak ditemukan untuk UI")

func update_temporary_display(carried_ripe: int, _carried_unripe: int):  # ✅ PERBAIKAN: tambahkan underscore
	if ripe_label:
		ripe_label.text = "Buah matang dibawa: %d" % carried_ripe
	if unripe_label:
		# ✅ MODIFIKASI: Tampilkan total poin buah mentah yang sudah dikumpulkan
		var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
		if inventory_system:
			var unripe_points = inventory_system.get_collected_unripe_count()
			unripe_label.text = "Poin buah mentah: %d" % unripe_points
		else:
			unripe_label.text = "Poin buah mentah: 0"  # Fallback

func update_permanent_display(_delivered_ripe: int, collected_unripe: int):  # ✅ PERBAIKAN: tambahkan underscore
	# Update UI untuk menampilkan poin permanen
	if unripe_label:
		unripe_label.text = "Poin buah mentah: %d" % collected_unripe

func update_display(ripe_count: int, unripe_count: int):
	update_temporary_display(ripe_count, unripe_count)
