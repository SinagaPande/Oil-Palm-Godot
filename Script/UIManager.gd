extends Control
class_name UIManager

# Referensi ke elemen UI
@onready var ripe_label: Label = $RipeLabel
@onready var unripe_label: Label = $UnripeLabel
@onready var interaction_label: Label = $InteractionLabel
@onready var notification_label: Label = $NotificationLabel
@onready var npc_harvest_label: Label = $NpcHarvestLabel

# Inisialisasi tanpa assignment langsung
@onready var timer_label: Label

# CROSSHAIR SYSTEM
@onready var crosshair: Control = $Crosshair

# HEALTH SYSTEM - DITAMBAHKAN DARI BRANCH ANSELMARIO
var health_bar: ProgressBar = null
var health_label: Label = null

# ELEMEN UI PAUSE
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button
@onready var restart_button: Button
@onready var quit_button: Button

# Variabel untuk UI akhir ronde
@onready var round_end_panel: Control = $RoundEndPanel
@onready var final_score_label: Label
@onready var details_label: Label
@onready var restart_button_end: Button
@onready var quit_button_end: Button
@onready var next_button_end: Button  # ⬅️ Variabel untuk tombol Next (restartbutton3)

# Timer untuk auto-hide notifikasi
var notification_timer: Timer

# Variabel pause
var is_paused: bool = false
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

func _ready():
	visible = true
	
	# Inisialisasi timer_label
	timer_label = find_child("TimerLabel", true, false)
	if not timer_label:
		print("WARNING: TimerLabel tidak ditemukan di scene!")
	
	# Biarkan UIManager tetap proses input saat game paused
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
	
	# Gunakan call_deferred() untuk semua pemanggilan fungsi
	call_deferred("setup_pause_menu")
	call_deferred("setup_round_end_ui")
	call_deferred("show_inventory_labels")
	call_deferred("connect_to_game_systems")

func _process(_delta):
	# Safety check berjalan terus menerus
	if not should_show_ui_labels():
		update_sensitive_labels_visibility()
	
	# Update crosshair visibility based on current tool
	update_crosshair_based_on_tool()

func update_crosshair_based_on_tool() -> void:
	## Check if ketapel is active and update crosshair visibility
	var player_controller = get_node_or_null("/root/Node3D/PlayerController")
	if not player_controller:
		var nodes = get_tree().get_nodes_in_group("player_controller")
		if nodes.size() > 0:
			player_controller = nodes[0]
	
	if player_controller and player_controller.has_method("is_ketapel_active"):
		var should_show_crosshair = player_controller.is_ketapel_active()
		update_crosshair_visibility(should_show_crosshair)

func _enter_tree():
	# Set process mode agar UIManager tetap berjalan saat game paused
	process_mode = Node.PROCESS_MODE_ALWAYS

# FUNGSI: Setup pause menu
func setup_pause_menu():
	if pause_menu:
		pause_menu.visible = false
		
		# CARI BUTTON DENGAN PATH YANG LEBIH SPESIFIK
		resume_button = pause_menu.find_child("ResumeButton", true, false)
		restart_button = pause_menu.find_child("RestartButton", true, false)
		quit_button = pause_menu.find_child("QuitButton", true, false)
		
		# Connect buttons
		if resume_button:
			if not resume_button.is_connected("pressed", _on_resume_pressed):
				resume_button.pressed.connect(_on_resume_pressed)
		
		if restart_button:
			if not restart_button.is_connected("pressed", _on_restart_pressed):
				restart_button.pressed.connect(_on_restart_pressed)
			
		if quit_button:
			if not quit_button.is_connected("pressed", _on_quit_pressed):
				quit_button.pressed.connect(_on_quit_pressed)
	else:
		print("PauseMenu tidak ditemukan")

func setup_timer_display():
	if timer_label:
		timer_label.visible = true
		timer_label.text = "03:00"

func update_timer_display(remaining_time: float):
	if timer_label:
		var minutes = int(remaining_time) / 60
		var seconds = int(remaining_time) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		
		# Ubah warna menjadi merah saat waktu hampir habis
		if remaining_time <= 30.0:
			timer_label.modulate = Color.RED
		else:
			timer_label.modulate = Color.WHITE

func show_inventory_labels():
	if ripe_label: ripe_label.visible = true
	if unripe_label: unripe_label.visible = true
	if npc_harvest_label: npc_harvest_label.visible = true
	
	update_ui_from_player()
	update_npc_harvest_display(0)

func connect_to_game_systems():
	await get_tree().process_frame
	
	# Connect ke InventorySystem
	var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
	if not inventory_system:
		var nodes = get_tree().get_nodes_in_group("inventory_system")
		if nodes.size() > 0: inventory_system = nodes[0]
	
	# Connect ke Player
	var player = get_node_or_null("/root/Node3D/Player")
	if not player:
		var nodes = get_tree().get_nodes_in_group("player")
		if nodes.size() > 0: player = nodes[0]
	
	# Connect ke NPC Manager
	var npc_manager = get_node_or_null("/root/Node3D/NPCManager")
	if not npc_manager:
		var nodes = get_tree().get_nodes_in_group("npc_manager")
		if nodes.size() > 0: npc_manager = nodes[0]
	
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
		
		# HEALTH SYSTEM CONNECTION - DITAMBAHKAN DARI BRANCH ANSELMARIO
		if player.has_signal("health_changed"):
			player.health_changed.connect(update_health_display)
			# Initialize health display
			update_health_display(player.current_health, player.MAX_HEALTH)
		
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)
	
	if npc_manager:
		if npc_manager.has_signal("npc_total_harvest_updated"):
			npc_manager.npc_total_harvest_updated.connect(update_npc_harvest_display)
		if npc_manager.has_method("get_total_npc_harvest"):
			var initial_harvest = npc_manager.get_total_npc_harvest()
			update_npc_harvest_display(initial_harvest)
	
	update_ui_from_player()
	
	# KONEKSI KE GAMEMODEMANAGER
	var game_mode_manager = get_node_or_null("/root/Node3D/GameModeManager")
	if not game_mode_manager:
		var managers = get_tree().get_nodes_in_group("game_mode_manager")
		if managers.size() > 0: game_mode_manager = managers[0]
	
	if game_mode_manager:
		if game_mode_manager.has_signal("game_time_updated") and not game_mode_manager.game_time_updated.is_connected(update_timer_display):
			game_mode_manager.game_time_updated.connect(update_timer_display)
		
		if game_mode_manager.has_signal("round_ended_with_score") and not game_mode_manager.round_ended_with_score.is_connected(show_round_end_notification):
			game_mode_manager.round_ended_with_score.connect(show_round_end_notification)
	else:
		print("WARNING: GameModeManager tidak ditemukan")
	
	setup_round_end_ui()
	setup_timer_display()

func _unhandled_input(event):
	# Blokir input pause jika RoundEndPanel terlihat
	if round_end_panel and round_end_panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func _input(_event):
	pass

func toggle_pause():
	if round_end_panel and round_end_panel.visible:
		return
	
	if is_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	if is_paused: return
	
	is_paused = true
	previous_mouse_mode = Input.get_mouse_mode()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if pause_menu:
		pause_menu.visible = true
		if resume_button: resume_button.grab_focus()
	
	on_ui_state_changed()

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
	
	# ---------------------------------------------------------
	# PERBAIKAN DI SINI:
	# Jangan gunakan previous_mouse_mode, tapi paksa ke CAPTURED
	# Agar cursor hilang dan kamera bisa digerakkan lagi
	# ---------------------------------------------------------
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# ⬅️ PERBAIKAN: Panggil fungsi update visibility
	on_ui_state_changed()
	
	print("Game Resumed")

func _on_resume_pressed():
	resume_game()

func _on_restart_round_pressed():
	if round_end_panel: round_end_panel.visible = false
	on_ui_state_changed()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_restart_pressed():
	resume_game()
	get_tree().reload_current_scene()

func _on_quit_pressed():
	print("Quit button pressed")
	
	# 1. Unpause Game (PENTING)
	get_tree().paused = false
	
	# 2. Pastikan Mouse TERLIHAT (VISIBLE) agar bisa klik menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 3. Pindah Scene
	get_tree().change_scene_to_file("res://Scene/Menu.tscn")

# ⬅️ FUNGSI BARU: Logic tombol Next Level
func _on_next_level_pressed():
	print("Next Level button pressed")
	
	# 1. Unpause Game
	get_tree().paused = false
	
	# 2. Pastikan Mouse TERLIHAT (VISIBLE) untuk menu selanjutnya
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 3. Logic Pindah Scene
	var current_scene_file = get_tree().current_scene.scene_file_path.get_file()
	print("Current Scene: ", current_scene_file)
	
	if current_scene_file == "Level.tscn":
		get_tree().change_scene_to_file("res://Script/MenuLevel2.tscn")
		
	elif current_scene_file == "Level2.tscn":
		get_tree().change_scene_to_file("res://Script/MenuLevel3.tscn")
		
	else:
		print("Tidak ada level selanjutnya")

func is_game_paused() -> bool:
	return is_paused

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

func show_interaction_label(text: String):
	if not should_show_ui_labels():
		if interaction_label and interaction_label.visible:
			interaction_label.visible = false
		return
		
	if interaction_label:
		interaction_label.text = text
		interaction_label.visible = true

func hide_interaction_label():
	if interaction_label: interaction_label.visible = false

func clear_target():
	hide_interaction_label()

func show_delivery_notification(total_kg: int):
	if not should_show_ui_labels():
		if notification_label and notification_label.visible:
			notification_label.visible = false
			if notification_timer and notification_timer.time_left > 0:
				notification_timer.stop()
		return
		
	if notification_label:
		notification_label.text = "%d kg buah matang berhasil diantar!" % total_kg
		notification_label.visible = true
		notification_timer.start(3.0)

func _on_notification_timeout():
	if notification_label: notification_label.visible = false

func update_permanent_display(delivered_ripe_kg: int, collected_unripe_kg: int):
	if ripe_label:
		var player = get_node_or_null("/root/Node3D/Player")
		var carried_ripe = 0
		if player and player.has_method("get_carried_ripe_fruits"):
			carried_ripe = player.get_carried_ripe_fruits()
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]
	
	if unripe_label:
		unripe_label.text = "Buah mentah: %d kg" % collected_unripe_kg

func update_carried_fruits(carried_ripe: int, _carried_kg: int):
	if ripe_label:
		var inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
		var delivered_ripe_kg = 0
		if inventory_system:
			delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]

func update_temporary_display(carried_ripe: int, carried_kg: int):
	update_carried_fruits(carried_ripe, carried_kg)

func update_display(ripe_count: int, ripe_kg: int):
	update_temporary_display(ripe_count, ripe_kg)

# ⬅️ PERBAIKAN BESAR: Setup UI untuk tampilan akhir ronde
func setup_round_end_ui():
	print("Setting up round end UI...")
	
	if round_end_panel:
		round_end_panel.visible = false
		
		# --- 1. SET PROCESS MODE PANEL AGAR TETAP AKTIF SAAT PAUSE ---
		# Ini penting! Panel dan anak-anaknya harus bisa jalan saat pause
		round_end_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		
		# Cari elemen UI
		final_score_label = round_end_panel.find_child("FinalScoreLabel", true, false)
		details_label = round_end_panel.find_child("DetailsLabel", true, false)
		restart_button_end = round_end_panel.find_child("RestartButton", true, false)
		quit_button_end = round_end_panel.find_child("QuitButton", true, false)
		
		# Cari tombol Next (restartbutton3)
		next_button_end = round_end_panel.find_child("RestartButton3", true, false)
		
		# --- 2. SETUP TOMBOL RESTART ---
		if restart_button_end:
			# Pastikan tombol bisa diklik saat pause
			restart_button_end.process_mode = Node.PROCESS_MODE_ALWAYS
			
			if not restart_button_end.is_connected("pressed", _on_restart_round_pressed):
				restart_button_end.pressed.connect(_on_restart_round_pressed)
				
		# --- 3. SETUP TOMBOL QUIT ---
		if quit_button_end:
			# Pastikan tombol bisa diklik saat pause
			quit_button_end.process_mode = Node.PROCESS_MODE_ALWAYS
			
			if not quit_button_end.is_connected("pressed", _on_quit_pressed):
				quit_button_end.pressed.connect(_on_quit_pressed)

		# --- 4. SETUP TOMBOL NEXT ---
		if next_button_end:
			print("Tombol Next (RestartButton3) ditemukan.")
			# Pastikan tombol bisa diklik saat pause
			next_button_end.process_mode = Node.PROCESS_MODE_ALWAYS
			
			if not next_button_end.is_connected("pressed", _on_next_level_pressed):
				next_button_end.pressed.connect(_on_next_level_pressed)
			
			# Logic Hide/Show
			var current_scene_file = get_tree().current_scene.scene_file_path.get_file()
			
			if current_scene_file == "Level3.tscn":
				next_button_end.visible = false
			else:
				next_button_end.visible = true
		else:
			print("WARNING: 'RestartButton3' tidak ditemukan di RoundEndPanel!")
			
	else:
		print("ERROR: RoundEndPanel tidak ditemukan!")

func show_round_end_notification(final_score: int, score_details: Dictionary):
	print("Showing round end notification...")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if round_end_panel:
		round_end_panel.visible = true
		
		if final_score_label:
			final_score_label.text = "Skor Akhir: Rp %s" % _format_currency(final_score)
			if final_score > 0: final_score_label.modulate = Color.GREEN
			elif final_score < 0: final_score_label.modulate = Color.RED
			else: final_score_label.modulate = Color.WHITE
		
		if details_label:
			var details_text = "RINCIAN AKHIR:\n"
			var ripe_kg = score_details.get("delivered_ripe_kg", 0)
			var ripe_income = score_details.get("ripe_income", 0)
			details_text += "+ PENJUALAN BUAH MATANG:    %3d kg × Rp 2.000 = +Rp %8s\n" % [ripe_kg, _format_currency_with_padding(ripe_income)]
			
			var unripe_kg = score_details.get("collected_unripe_kg", 0)
			var unripe_penalty = score_details.get("unripe_penalty", 0)
			details_text += "- KERUGIAN BUAH MENTAH:     %3d kg × Rp   500 = -Rp %8s\n" % [unripe_kg, _format_currency_with_padding(unripe_penalty)]
			
			var npc_kg = score_details.get("npc_stolen_kg", 0)
			var npc_penalty = score_details.get("npc_penalty", 0)
			details_text += "- KERUGIAN KARENA PENCURIAN: %3d kg × Rp   500 = -Rp %8s" % [npc_kg, _format_currency_with_padding(npc_penalty)]
			
			details_label.text = details_text
		
		on_ui_state_changed()
		
		# Focus priority: Next -> Restart -> Quit
		if next_button_end and next_button_end.visible:
			next_button_end.grab_focus()
		elif restart_button_end:
			restart_button_end.grab_focus()
		elif quit_button_end:
			quit_button_end.grab_focus()

func _format_currency_with_padding(amount: int) -> String:
	return _format_currency(amount).rpad(8, " ")

func _format_currency(amount: int) -> String:
	var is_negative = amount < 0
	var abs_amount = abs(amount)
	var formatted = ""
	var str_amount = str(abs_amount)
	var length = str_amount.length()
	
	for i in range(length):
		if i > 0 and i % 3 == 0: formatted = "." + formatted
		formatted = str_amount[length - i - 1] + formatted
	
	if is_negative: formatted = "-" + formatted
	return formatted

func should_show_ui_labels() -> bool:
	return not (is_paused or (round_end_panel and round_end_panel.visible))

func update_sensitive_labels_visibility():
	var should_show = should_show_ui_labels()
	
	if interaction_label:
		if not should_show and interaction_label.visible: interaction_label.visible = false
	
	if notification_label:
		if not should_show and notification_label.visible:
			notification_label.visible = false
			if notification_timer and notification_timer.time_left > 0: notification_timer.stop()

func on_ui_state_changed():
	update_sensitive_labels_visibility()

# ===== CROSSHAIR SYSTEM =====
func update_crosshair_visibility(should_show: bool) -> void:
	## Update crosshair visibility based on tool
	if crosshair:
		crosshair.visible = should_show

func setup_crosshair() -> void:
	## Initialize crosshair position and state
	if crosshair:
		# Center crosshair on screen
		var viewport_size = get_viewport_rect().size
		crosshair.position = viewport_size / 2.0 - crosshair.size / 2.0
		crosshair.visible = false

# ===== HEALTH SYSTEM - DITAMBAHKAN DARI BRANCH ANSELMARIO =====
func setup_health_ui() -> void:
	## Initialize health bar and label
	health_bar = find_child("HealthBar", true, false)
	health_label = find_child("HealthLabel", true, false)
	
	if health_bar:
		health_bar.max_value = 100.0
		health_bar.value = 100.0
	
	if health_label:
		health_label.text = "100 / 100"

func update_health_display(current_health: int, max_health: int) -> void:
	## Update health bar and label display
	# Setup UI jika belum ada
	if not health_bar or not health_label:
		setup_health_ui()
	
	if health_bar:
		health_bar.max_value = float(max_health)
		health_bar.value = float(current_health)
		
		# Color gradient: Green (normal) -> Yellow (warning) -> Red (critical)
		var health_ratio = float(current_health) / float(max_health)
		if health_ratio > 0.5:
			# Green to Yellow
			health_bar.modulate = Color.GREEN.lerp(Color.YELLOW, 1.0 - (health_ratio - 0.5) * 2.0)
		else:
			# Yellow to Red
			health_bar.modulate = Color.YELLOW.lerp(Color.RED, 1.0 - health_ratio * 2.0)
	
	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]

func _on_player_died() -> void:
	## Handle player death event
	print("Player died! Showing game over...")
	if health_label:
		health_label.text = "DEAD"
		health_label.modulate = Color.RED
