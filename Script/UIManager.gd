extends Control
class_name UIManager

# Referensi ke elemen UI
@onready var ripe_label: Label = $RipeLabel
@onready var unripe_label: Label = $UnripeLabel
@onready var interaction_label: Label = $InteractionLabel
@onready var notification_label: Label = $NotificationLabel
@onready var npc_harvest_label: Label = $NpcHarvestLabel

# ⬅️ PERBAIKAN: Inisialisasi tanpa assignment langsung
@onready var timer_label: Label

# ⬅️ ELEMEN UI PAUSE BARU
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button
@onready var restart_button: Button  
@onready var quit_button: Button

# Variabel untuk UI akhir ronde
@onready var round_end_panel: Control = $RoundEndPanel
@onready var final_score_label: Label
@onready var details_label: Label
@onready var restart_button_end: Button  # ⬅️ TAMBAHKAN: Tombol restart di panel akhir
@onready var quit_button_end: Button     # ⬅️ TAMBAHKAN: Tombol quit di panel akhir

# Timer untuk auto-hide notifikasi
var notification_timer: Timer

# Variabel pause
var is_paused: bool = false
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

func _ready():
	visible = true
	
	# ⬅️ PERBAIKAN: Inisialisasi timer_label
	timer_label = find_child("TimerLabel", true, false)
	if not timer_label:
		print("WARNING: TimerLabel tidak ditemukan di scene!")
	
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
	call_deferred("setup_round_end_ui")  # ⬅️ PASTIKAN setup_round_end_ui dipanggil
	call_deferred("show_inventory_labels")
	call_deferred("connect_to_game_systems")
	
func _process(_delta):
	# ⬅️ PERBAIKAN: Safety check berjalan terus menerus
	# Ini memastikan label tetap disembunyikan meskipun ada bug di tempat lain
	if not should_show_ui_labels():
		update_sensitive_labels_visibility()

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
		
func setup_timer_display():
	if timer_label:
		timer_label.visible = true
		# Format awal: 03:00
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
	
	# Connect ke NPC Manager
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
	
	# ⬅️ PERBAIKAN: KONEKSI KE GAMEMODEMANAGER - HANYA SATU KONEKSI
	var game_mode_manager = get_node_or_null("/root/Node3D/GameModeManager")
	if not game_mode_manager:
		var managers = get_tree().get_nodes_in_group("game_mode_manager")
		if managers.size() > 0:
			game_mode_manager = managers[0]
	
	if game_mode_manager:
		# Hapus duplikasi koneksi - pastikan hanya connect sekali
		if game_mode_manager.has_signal("game_time_updated") and not game_mode_manager.game_time_updated.is_connected(update_timer_display):
			game_mode_manager.game_time_updated.connect(update_timer_display)
		
		if game_mode_manager.has_signal("round_ended_with_score") and not game_mode_manager.round_ended_with_score.is_connected(show_round_end_notification):
			game_mode_manager.round_ended_with_score.connect(show_round_end_notification)
		else:
			print("WARNING: GameModeManager tidak memiliki signal round_ended_with_score")
	else:
		print("WARNING: GameModeManager tidak ditemukan")
	
	# Setup UI akhir ronde
	setup_round_end_ui()
	# Setup timer display
	setup_timer_display()

# ⬅️ PERBAIKAN: Gunakan _unhandled_input() untuk menangkap input saat paused
func _unhandled_input(event):
	# ⬅️ PERBAIKAN KRITIS: Blokir input pause jika RoundEndPanel terlihat
	if round_end_panel and round_end_panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			print("Input pause diabaikan - RoundEndPanel sedang aktif")
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

# ⬅️ SISTEM PAUSE BARU
func _input(_event):
	# ⬅️ PERBAIKAN: Jangan handle input pause di sini, pindah ke _unhandled_input()
	pass

func toggle_pause():
	# ⬅️ PERBAIKAN KEAMANAN: Jangan izinkan pause jika RoundEndPanel terlihat
	if round_end_panel and round_end_panel.visible:
		print("Tidak bisa pause - RoundEndPanel sedang aktif")
		return
	
	print("Toggle pause called. Current state: ", is_paused)
	if is_paused:
		resume_game()
	else:
		pause_game()

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
	
	# ⬅️ PERBAIKAN: Panggil fungsi update visibility
	on_ui_state_changed()
	
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
	
	# ⬅️ PERBAIKAN: Panggil fungsi update visibility
	on_ui_state_changed()
	
	print("Game Resumed")

func _on_resume_pressed():
	print("Resume button pressed")
	resume_game()

func _on_restart_round_pressed():
	print("Restart round button pressed - performing full scene reload")
	
	# ⬅️ PERBAIKAN: Sembunyikan panel akhir ronde terlebih dahulu
	if round_end_panel:
		round_end_panel.visible = false
	
	# ⬅️ PERBAIKAN: Panggil fungsi update visibility terakhir kali
	on_ui_state_changed()
	
	# ⬅️ PERBAIKAN: Resume game sebelum reload untuk menghindari issue
	get_tree().paused = false
	
	# ⬅️ PERBAIKAN: Lakukan full scene reload untuk reset semua data
	print("Reloading current scene...")
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
	# ⬅️ PERBAIKAN: Gunakan fungsi helper yang konsisten
	if not should_show_ui_labels():
		# Jika tidak boleh menampilkan, pastikan label disembunyikan
		if interaction_label and interaction_label.visible:
			interaction_label.visible = false
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

func show_delivery_notification(total_kg: int):
	# ⬅️ PERBAIKAN: Gunakan fungsi helper yang konsisten
	if not should_show_ui_labels():
		# Jika tidak boleh menampilkan, pastikan label disembunyikan
		if notification_label and notification_label.visible:
			notification_label.visible = false
			if notification_timer and notification_timer.time_left > 0:
				notification_timer.stop()
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
	
# ⬅️ PERBAIKAN BESAR: Setup UI untuk tampilan akhir ronde dengan TOMBOL QUIT
func setup_round_end_ui():
	print("Setting up round end UI...")
	
	# Setup UI untuk tampilan akhir ronde
	if round_end_panel:
		round_end_panel.visible = false
		
		# Cari elemen UI (sesuaikan dengan struktur scene Anda)
		final_score_label = round_end_panel.find_child("FinalScoreLabel", true, false)
		details_label = round_end_panel.find_child("DetailsLabel", true, false)
		restart_button_end = round_end_panel.find_child("RestartButton", true, false)
		quit_button_end = round_end_panel.find_child("QuitButton", true, false)  # ⬅️ CARI TOMBOL QUIT BARU
		
		print("Round End UI Elements Found:")
		print("- FinalScoreLabel: ", final_score_label != null)
		print("- DetailsLabel: ", details_label != null)
		print("- RestartButton: ", restart_button_end != null)
		print("- QuitButton: ", quit_button_end != null)
		
		# Connect tombol restart
		if restart_button_end:
			if not restart_button_end.is_connected("pressed", _on_restart_round_pressed):
				restart_button_end.pressed.connect(_on_restart_round_pressed)
		else:
			print("WARNING: RestartButton tidak ditemukan di RoundEndPanel!")
			
		# ⬅️ TAMBAHKAN: Connect tombol quit jika ada
		if quit_button_end:
			if not quit_button_end.is_connected("pressed", _on_quit_pressed):
				quit_button_end.pressed.connect(_on_quit_pressed)
			print("QuitButton ditemukan dan terhubung di RoundEndPanel")
		else:
			print("WARNING: QuitButton tidak ditemukan di RoundEndPanel! Tambahkan tombol Quit ke scene.")
	else:
		print("ERROR: RoundEndPanel tidak ditemukan!")
			
func show_round_end_notification(final_score: int, score_details: Dictionary):
	print("Showing round end notification...")
	
	# ⬅️ PERBAIKAN KEAMANAN: Pastikan mouse terlihat
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Tampilkan panel akhir ronde
	if round_end_panel:
		round_end_panel.visible = true
		
		# Update teks skor akhir dengan warna berdasarkan nilai
		if final_score_label:
			final_score_label.text = "Skor Akhir: Rp %s" % _format_currency(final_score)
			
			# Terapkan warna berdasarkan nilai skor akhir
			if final_score > 0:
				final_score_label.modulate = Color.GREEN
			elif final_score < 0:
				final_score_label.modulate = Color.RED
			else:
				final_score_label.modulate = Color.WHITE
		
		# FORMAT TABEL RAPI - PERBAIKAN BESAR
		if details_label:
			var details_text = "RINCIAN AKHIR:\n"
			
			# 1. PENJUALAN BUAH MATANG (POSITIF)
			var ripe_kg = score_details.get("delivered_ripe_kg", 0)
			var ripe_income = score_details.get("ripe_income", 0)
			details_text += "+ PENJUALAN BUAH MATANG:    %3d kg × Rp 2.000 = +Rp %8s\n" % [
				ripe_kg, 
				_format_currency_with_padding(ripe_income)
			]
			
			# 2. KERUGIAN BUAH MENTAH (NEGATIV)
			var unripe_kg = score_details.get("collected_unripe_kg", 0)
			var unripe_penalty = score_details.get("unripe_penalty", 0)
			details_text += "- KERUGIAN BUAH MENTAH:     %3d kg × Rp   500 = -Rp %8s\n" % [
				unripe_kg,
				_format_currency_with_padding(unripe_penalty)
			]
			
			# 3. KERUGIAN KARENA PENCURIAN (NEGATIV)
			var npc_kg = score_details.get("npc_stolen_kg", 0)
			var npc_penalty = score_details.get("npc_penalty", 0)
			details_text += "- KERUGIAN KARENA PENCURIAN: %3d kg × Rp   500 = -Rp %8s" % [
				npc_kg,
				_format_currency_with_padding(npc_penalty)
			]
			
			details_label.text = details_text
		
		# ⬅️ PERBAIKAN: Panggil fungsi update visibility
		on_ui_state_changed()
		
		# Focus pada restart button untuk navigasi gamepad
		if restart_button_end:
			restart_button_end.grab_focus()
		elif quit_button_end:
			quit_button_end.grab_focus()
		
		print("Round End Panel ditampilkan dengan format baru")
	else:
		print("ERROR: RoundEndPanel tidak tersedia!")

# ⬅️ FUNGSI BARU: Format currency dengan padding untuk alignment yang rapi
func _format_currency_with_padding(amount: int) -> String:
	var formatted = _format_currency(amount)
	# Tambahkan padding spasi di depan untuk membuat panjang konsisten (8 karakter)
	return formatted.rpad(8, " ")

# ⬅️ FUNGSI BARU: Format currency dengan separator ribuan
func _format_currency(amount: int) -> String:
	# Handle angka negatif
	var is_negative = amount < 0
	var abs_amount = abs(amount)
	
	# Format dengan separator ribuan
	var formatted = ""
	var str_amount = str(abs_amount)
	var length = str_amount.length()
	
	for i in range(length):
		if i > 0 and i % 3 == 0:
			formatted = "." + formatted
		formatted = str_amount[length - i - 1] + formatted
	
	# Tambahkan tanda negatif jika perlu
	if is_negative:
		formatted = "-" + formatted
	
	return formatted

# Fungsi helper untuk mengecek apakah UI harus menampilkan label interaksi/notifikasi
func should_show_ui_labels() -> bool:
	return not (is_paused or (round_end_panel and round_end_panel.visible))

# Fungsi untuk update visibility semua label yang sensitif terhadap pause/round end
func update_sensitive_labels_visibility():
	var should_show = should_show_ui_labels()
	
	# Sembunyikan interaction label jika tidak boleh ditampilkan
	if interaction_label:
		if not should_show and interaction_label.visible:
			interaction_label.visible = false
	
	# Sembunyikan notification label jika tidak boleh ditampilkan
	if notification_label:
		if not should_show and notification_label.visible:
			notification_label.visible = false
			if notification_timer and notification_timer.time_left > 0:
				notification_timer.stop()

# Panggil fungsi ini setiap kali state berubah
func on_ui_state_changed():
	update_sensitive_labels_visibility()
	
func _on_restart_pressed():
	print("Restart button pressed")
	# First resume the game
	resume_game()
	
	# ⬅️ PERBAIKAN: Gunakan scene reload untuk reset penuh
	get_tree().reload_current_scene()
