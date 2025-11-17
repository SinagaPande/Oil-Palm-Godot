extends Control

class_name UI_Manager

# UI Elements - Inventory
@onready var ripe_label: Label = $CanvasLayer/UI_Container/InventoryPanel/RipeLabel
@onready var unripe_label: Label = $CanvasLayer/UI_Container/InventoryPanel/UnripeLabel
@onready var hp_label: Label = $CanvasLayer/UI_Container/InventoryPanel/HPLabel

# UI Elements - Interaction
@onready var interaction_label: Label = $CanvasLayer/UI_Container/InteractionLabel

# References
var inventory_system: InventorySystem = null
var player: Player = null
var interaction_system: InteractionSystem = null

func _ready():
	add_to_group("ui_manager")
	visible = true
	# Initialize labels
	if interaction_label:
		interaction_label.visible = false
	
	# Connect to systems
	await get_tree().process_frame
	connect_to_systems()

func connect_to_systems():
	# Find InventorySystem - coba berbagai path
	var paths_to_try = [
		"/root/Node3D/InventorySystem",
		"/root/Level/InventorySystem",
		"../InventorySystem",
		"../../InventorySystem"
	]
	
	for path in paths_to_try:
		inventory_system = get_node_or_null(path)
		if inventory_system:
			break
	
	if not inventory_system:
		var nodes = get_tree().get_nodes_in_group("inventory_system")
		if nodes.size() > 0:
			inventory_system = nodes[0] as InventorySystem
	
	# Find Player - coba berbagai path
	paths_to_try = [
		"/root/Node3D/Player",
		"/root/Level/Player",
		"../Player",
		"../../Player"
	]
	
	for path in paths_to_try:
		player = get_node_or_null(path)
		if player:
			break
	
	if not player:
		var player_nodes = get_tree().get_nodes_in_group("player")
		if player_nodes.size() > 0:
			player = player_nodes[0] as Player
	
	# Find InteractionSystem
	if player:
		interaction_system = player.get_node_or_null("InteractionSystem")
	
	if not interaction_system:
		var interaction_nodes = get_tree().get_nodes_in_group("interaction_system")
		if interaction_nodes.size() > 0:
			interaction_system = interaction_nodes[0] as InteractionSystem
	
	# Connect signals
	if inventory_system:
		if inventory_system.has_signal("permanent_inventory_updated"):
			inventory_system.permanent_inventory_updated.connect(update_permanent_display)
	
	if player:
		if player.has_signal("carried_fruits_updated"):
			player.carried_fruits_updated.connect(update_carried_fruits)
		if player.has_signal("hp_updated"):
			player.hp_updated.connect(update_hp_display)
		if player.has_signal("player_fully_ready"):
			player.player_fully_ready.connect(_on_player_ready)
	
	# Set interaction label reference in InteractionSystem
	if interaction_system:
		interaction_system.interaction_label = interaction_label
	
	# Initialize display
	update_ui_from_player()
	update_hp_from_player()

func _on_player_ready():
	await get_tree().process_frame
	update_ui_from_player()

# ========== INVENTORY UI FUNCTIONS ==========

func update_ui_from_player():
	if not player or not inventory_system:
		return
	
	var carried_ripe = player.get_carried_ripe_fruits()
	var delivered_ripe = inventory_system.get_delivered_ripe_count()
	var collected_unripe = inventory_system.get_collected_unripe_count()
	
	if ripe_label:
		ripe_label.text = "Buah matang: %d dibawa, %d diantar" % [carried_ripe, delivered_ripe]
	if unripe_label:
		unripe_label.text = "Poin buah mentah: %d" % collected_unripe

func update_permanent_display(delivered_ripe: int, collected_unripe: int):
	if not player:
		player = get_node_or_null("/root/Node3D/Player")
		if not player:
			var player_nodes = get_tree().get_nodes_in_group("player")
			if player_nodes.size() > 0:
				player = player_nodes[0] as Player
	
	if ripe_label:
		var carried_ripe = 0
		if player and player.has_method("get_carried_ripe_fruits"):
			carried_ripe = player.get_carried_ripe_fruits()
		
		ripe_label.text = "Buah matang: %d dibawa, %d diantar" % [carried_ripe, delivered_ripe]
	
	if unripe_label:
		unripe_label.text = "Poin buah mentah: %d" % collected_unripe

func update_carried_fruits(carried_ripe: int):
	if not inventory_system:
		inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
		if not inventory_system:
			var nodes = get_tree().get_nodes_in_group("inventory_system")
			if nodes.size() > 0:
				inventory_system = nodes[0] as InventorySystem
	
	if ripe_label:
		var delivered_ripe = 0
		if inventory_system:
			delivered_ripe = inventory_system.get_delivered_ripe_count()
		
		ripe_label.text = "Buah matang: %d dibawa, %d diantar" % [carried_ripe, delivered_ripe]

func update_display(ripe_count: int, unripe_count: int):
	update_carried_fruits(ripe_count)

# ========== HP UI FUNCTIONS ==========

func update_hp_display(current_hp: int, max_hp: int):
	if hp_label:
		hp_label.text = "HP: %d / %d" % [current_hp, max_hp]

func update_hp_from_player():
	if not player:
		player = get_node_or_null("/root/Node3D/Player")
		if not player:
			var player_nodes = get_tree().get_nodes_in_group("player")
			if player_nodes.size() > 0:
				player = player_nodes[0] as Player
	
	if player and player.has_method("get_hp") and player.has_method("get_max_hp"):
		var current_hp = player.get_hp()
		var max_hp = player.get_max_hp()
		update_hp_display(current_hp, max_hp)

# ========== INTERACTION UI FUNCTIONS ==========

func show_interaction_label(text: String):
	if interaction_label:
		interaction_label.text = text
		interaction_label.visible = true

func hide_interaction_label():
	if interaction_label:
		interaction_label.visible = false

func clear_interaction_target():
	hide_interaction_label()

