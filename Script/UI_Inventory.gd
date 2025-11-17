extends Control

class_name UI_Inventory

@onready var ripe_label: Label = $RipeLabel
@onready var unripe_label: Label = $UnripeLabel

func _ready():
	visible = true
	update_display(0, 0.0)
	connect_to_inventory_system()

func connect_to_inventory_system():
	await get_tree().process_frame
	
	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	if not inventory_system:
		var nodes = get_tree().get_nodes_in_group("inventory_system")
		if nodes.size() > 0:
			inventory_system = nodes[0]
	
	var player = get_node_or_null("/root/Node3D/Player")
	if not player:
		var player_nodes = get_tree().get_nodes_in_group("player")
		if player_nodes.size() > 0:
			player = player_nodes[0]
	
	if inventory_system:
		inventory_system.permanent_inventory_updated.connect(update_permanent_display)
	
	if player:
		if player.has_signal("carried_fruits_updated"):
			player.carried_fruits_updated.connect(update_carried_fruits)
		elif player.has_signal("player_fully_ready"):
			player.player_fully_ready.connect(_on_player_ready)
	
	update_ui_from_player()

func _on_player_ready():
	await get_tree().process_frame
	update_ui_from_player()

func update_ui_from_player():
	var player = get_node_or_null("/root/Node3D/Player")
	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	
	if player and inventory_system:
		var carried_ripe = player.get_carried_ripe_fruits()
		var delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		var collected_unripe_kg = inventory_system.get_collected_unripe_kg()
		
		if ripe_label:
			ripe_label.text = "Buah matang: %d dibawa, total %.1f kg" % [carried_ripe, delivered_ripe_kg]
		if unripe_label:
			unripe_label.text = "Buah mentah: %.1f kg" % collected_unripe_kg

func update_permanent_display(delivered_ripe_kg: float, collected_unripe_kg: float):
	if ripe_label:
		var player = get_node_or_null("/root/Node3D/Player")
		var carried_ripe = 0
		if player and player.has_method("get_carried_ripe_fruits"):
			carried_ripe = player.get_carried_ripe_fruits()
		
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]
	
	if unripe_label:
		unripe_label.text = "Buah mentah: %d kg" % collected_unripe_kg

func update_carried_fruits(carried_ripe: int, carried_kg: float):
	if ripe_label:
		var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
		var delivered_ripe_kg = 0.0
		if inventory_system:
			delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		
		ripe_label.text = "Buah matang: %d dibawa, total %.1f kg" % [carried_ripe, delivered_ripe_kg]

func update_temporary_display(carried_ripe: int, carried_kg: float):
	update_carried_fruits(carried_ripe, carried_kg)

func update_display(ripe_count: int, ripe_kg: float):
	update_temporary_display(ripe_count, ripe_kg)
