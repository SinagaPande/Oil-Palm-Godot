extends Control
class_name UIManager

# Referensi ke elemen UI
@onready var ripe_label: Label = $RipeLabel
@onready var unripe_label: Label = $UnripeLabel
@onready var interaction_label: Label = $InteractionLabel
@onready var notification_label: Label = $NotificationLabel
@onready var npc_harvest_label: Label = $NpcHarvestLabel

# ⬅️ ELEMEN UI PAUSE BARU
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button
@onready var restart_button: Button  
@onready var quit_button: Button

# Timer untuk auto-hide notifikasi
var notification_timer: Timer

# Variabel pause
var is_paused: bool = false
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

func _ready():
	visible = true
	
	# ⬅️ PERBAIKAN PENTING: Biarkan UIManager tetap proses input saat game paused
	set_process_input(true)
	set_process_unhandled_input(true)
	
	# Setup timer untuk notifikasi
	notification_timer = Timer.new()
	notification_timer.one_shot = true
	notification_timer.timeout.connect(_on_notification_timeout)
	add_child(notification_timer)
	
	# Sembunyikan label yang tidak perlu di awal
	interaction_label.visible = false
	notification_label.visible = false
	
	# ⬅️ PERBAIKAN: Gunakan call_deferred() untuk semua pemanggilan fungsi
	call_deferred("setup_pause_menu")
	call_deferred("show_inventory_labels")
	call_deferred("connect_to_game_systems")

# ⬅️ PERBAIKAN: Override process mode agar tetap aktif saat paused
func _enter_tree():
	# Set process mode agar UIManager tetap berjalan saat game paused
	process_mode = Node.PROCESS_MODE_ALWAYS

# ⬅️ FUNGSI BARU: Setup pause menu
func setup_pause_menu():
	if pause_menu:
		pause_menu.visible = false
		
		# CARI BUTTON DENGAN PATH YANG LEBIH SPESIFIK
		resume_button = pause_menu.find_child("ResumeButton", true, false)
		restart_button = pause_menu.find_child("RestartButton", true, false)
		quit_button = pause_menu.find_child("QuitButton", true, false)
		
		print("Debug - ResumeButton found: ", resume_button != null)
		print("Debug - RestartButton found: ", restart_button != null)
		print("Debug - QuitButton found: ", quit_button != null)
		
		# Connect buttons
		if resume_button:
			if not resume_button.is_connected("pressed", _on_resume_pressed):
				resume_button.pressed.connect(_on_resume_pressed)
		else:
			print("ERROR: ResumeButton tidak ditemukan!")
			
		if restart_button:
			restart_button.pressed.connect(_on_restart_pressed)
		else:
			print("RestartButton tidak ditemukan")
			
		if quit_button:
			quit_button.pressed.connect(_on_quit_pressed)
		else:
			print("QuitButton tidak ditemukan")
	else:
		print("PauseMenu tidak ditemukan")

func show_inventory_labels():
	if ripe_label:
		ripe_label.visible = true
	if unripe_label:
		unripe_label.visible = true
	if npc_harvest_label:
		npc_harvest_label.visible = true
	
	# Update dengan data awal
	update_ui_from_player()
	update_npc_harvest_display(0)

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
			update_ui_from_player()
	
	if player:
		if player.has_signal("carried_fruits_updated"):
			player.carried_fruits_updated.connect(update_carried_fruits)
		elif player.has_signal("player_fully_ready"):
			player.player_fully_ready.connect(_on_player_ready)
		else:
			update_ui_from_player()
	
	if npc_manager:
		if npc_manager.has_signal("npc_total_harvest_updated"):
			npc_manager.npc_total_harvest_updated.connect(update_npc_harvest_display)
		if npc_manager.has_method("get_total_npc_harvest"):
			var initial_harvest = npc_manager.get_total_npc_harvest()
			update_npc_harvest_display(initial_harvest)
	
	update_ui_from_player()

# ⬅️ PERBAIKAN: Gunakan _unhandled_input() untuk menangkap input saat paused
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

# ⬅️ SISTEM PAUSE BARU
func _input(event):
	# ⬅️ PERBAIKAN: Jangan handle input pause di sini, pindah ke _unhandled_input()
	pass

func toggle_pause():
	print("Toggle pause called. Current state: ", is_paused)
	if is_paused:
		resume_game()
	else:
		pause_game()

# ⬅️ PERBAIKAN: HAPUS DUPLIKASI - hanya satu fungsi pause_game()
func pause_game():
	print("Attempting to pause game...")
	if is_paused:
		print("Game already paused")
		return
	
	is_paused = true
	print("Game paused state set to: ", is_paused)
	
	# Store previous mouse mode
	previous_mouse_mode = Input.get_mouse_mode()
	
	# Set game to pause mode
	get_tree().paused = true
	
	# Show mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Show pause menu
	if pause_menu:
		pause_menu.visible = true
		
		# Focus pada resume button untuk navigasi gamepad
		if resume_button:
			resume_button.grab_focus()
	
	# Sembunyikan interaction label saat pause
	hide_interaction_label()
	
	print("Game Paused")

func resume_game():
	print("Attempting to resume game...")
	if not is_paused:
		print("Game not paused")
		return
	
	is_paused = false
	print("Game paused state set to: ", is_paused)
	
	# Hide pause menu
	if pause_menu:
		pause_menu.visible = false
	
	# Resume game
	get_tree().paused = false
	
	# Restore previous mouse mode
	Input.set_mouse_mode(previous_mouse_mode)
	
	print("Game Resumed")

func _on_resume_pressed():
	print("Resume button pressed")
	resume_game()

func _on_restart_pressed():
	print("Restart button pressed")
	# First resume the game
	resume_game()
	
	# Then restart the current scene
	get_tree().reload_current_scene()

func _on_quit_pressed():
	print("Quit button pressed")
	# First resume the game to avoid issues
	resume_game()
	
	# Change to main menu scene
	# Ganti dengan path scene main menu Anda
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func is_game_paused() -> bool:
	return is_paused

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
	
	if ripe_label:
		ripe_label.visible = true
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]
	
	if unripe_label:
		unripe_label.visible = true
		unripe_label.text = "Buah mentah: %d kg" % collected_unripe_kg

# Fungsi untuk menampilkan label interaksi
func show_interaction_label(text: String):
	# Jangan tampilkan interaction label saat game paused
	if is_paused:
		return
		
	if interaction_label:
		interaction_label.text = text
		interaction_label.visible = true

# Fungsi untuk menyembunyikan label interaksi
func hide_interaction_label():
	if interaction_label:
		interaction_label.visible = false

# Fungsi untuk membersihkan target
func clear_target():
	hide_interaction_label()

# Fungsi untuk menampilkan notifikasi pengantaran
func show_delivery_notification(total_kg: int):
	# Jangan tampilkan notifikasi saat game paused
	if is_paused:
		return
		
	if notification_label:
		var notification_text = "%d kg buah matang berhasil diantar!" % total_kg
		notification_label.text = notification_text
		notification_label.visible = true
		notification_timer.start(3.0)

func _on_notification_timeout():
	if notification_label:
		notification_label.visible = false

# Update display permanen
func update_permanent_display(delivered_ripe_kg: int, collected_unripe_kg: int):
	if ripe_label:
		var player = get_node_or_null("/root/Node3D/Player")
		var carried_ripe = 0
		if player and player.has_method("get_carried_ripe_fruits"):
			carried_ripe = player.get_carried_ripe_fruits()
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]
	
	if unripe_label:
		unripe_label.text = "Buah mentah: %d kg" % collected_unripe_kg

# Update buah yang dibawa
func update_carried_fruits(carried_ripe: int, _carried_kg: int):
	if ripe_label:
		var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
		var delivered_ripe_kg = 0
		if inventory_system:
			delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]

# Update display sementara
func update_temporary_display(carried_ripe: int, carried_kg: int):
	update_carried_fruits(carried_ripe, carried_kg)

# Update display umum
func update_display(ripe_count: int, ripe_kg: int):
	update_temporary_display(ripe_count, ripe_kg)
