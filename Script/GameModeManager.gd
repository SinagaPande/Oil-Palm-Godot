extends Node
class_name GameModeManager

# Konfigurasi waktu
const ROUND_DURATION: float = 20  # 3 menit
var remaining_time: float = ROUND_DURATION
var is_round_active: bool = false
var was_paused_before_round_end: bool = false

# Referensi ke sistem lain
var inventory_system: InventorySystem
var npc_manager: NPCManager
var ui_manager: UIManager

# Signals
signal game_time_updated(remaining_time)
signal round_ended_with_score(final_score, score_details)
signal round_started()

func _ready():
	add_to_group("game_mode_manager")
	call_deferred("initialize_systems")

func initialize_systems():
	# Cari sistem yang diperlukan
	find_systems()
	
	# Tunggu frame berikutnya untuk memastikan semua sistem siap
	await get_tree().process_frame
	
	# Mulai ronde
	start_round()

func find_systems():
	# Cari InventorySystem dengan retry mechanism
	var attempts = 0
	while attempts < 5 and (not inventory_system or not npc_manager):
		inventory_system = get_node_or_null("/root/Node3D/InventorySystem")
		if not inventory_system:
			var inventory_nodes = get_tree().get_nodes_in_group("inventory_system")
			if inventory_nodes.size() > 0:
				inventory_system = inventory_nodes[0]
		
		# Cari NPCManager
		npc_manager = get_node_or_null("/root/Node3D/NPCManager")
		if not npc_manager:
			var npc_managers = get_tree().get_nodes_in_group("npc_manager")
			if npc_managers.size() > 0:
				npc_manager = npc_managers[0]
		
		attempts += 1
		if not inventory_system or not npc_manager:
			await get_tree().create_timer(0.1).timeout
	
	# Cari UIManager (opsional, untuk notifikasi)
	ui_manager = get_node_or_null("/root/Node3D/UIManager")
	if not ui_manager:
		var ui_managers = get_tree().get_nodes_in_group("ui_manager")
		if ui_managers.size() > 0:
			ui_manager = ui_managers[0]

func start_round():
	remaining_time = ROUND_DURATION
	is_round_active = true
	was_paused_before_round_end = false
	
	print("=== ARCADE MODE ===")
	print("Ronde dimulai! Waktu: %.0f detik" % remaining_time)
	
	round_started.emit()
	game_time_updated.emit(remaining_time)

func _process(delta):
	if not is_round_active:
		return
	
	# Jangan update timer jika game paused
	if get_tree().paused:
		return
	
	# Update timer
	remaining_time -= delta
	
	# Kirim sinyal setiap detik untuk update UI
	if int(remaining_time) != int(remaining_time + delta):
		game_time_updated.emit(remaining_time)
	
	# Cek apakah waktu habis
	if remaining_time <= 0:
		remaining_time = 0
		end_round_and_calculate_score()

func end_round_and_calculate_score():
	if not is_round_active:
		return
	
	is_round_active = false
	
	print("=== RONDE BERAKHIR ===")
	
	# Simpan status pause sebelumnya
	was_paused_before_round_end = get_tree().paused
	
	# Pause game secara permanen untuk ronde ini
	get_tree().paused = true
	
	# ⬅️ PERBAIKAN KRITIS: Pastikan mouse cursor terlihat
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Hitung skor
	calculate_final_score()

func calculate_final_score():
	# Ambil data dari sistem yang ada
	var delivered_ripe_kg: int = 0
	var collected_unripe_kg: int = 0
	var npc_stolen_kg: int = 0
	
	if inventory_system:
		if inventory_system.has_method("get_delivered_ripe_kg"):
			delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		if inventory_system.has_method("get_collected_unripe_kg"):
			collected_unripe_kg = inventory_system.get_collected_unripe_kg()
	
	if npc_manager:
		if npc_manager.has_method("get_total_npc_harvest"):
			npc_stolen_kg = npc_manager.get_total_npc_harvest()
	
	# Hitung komponen skor
	var ripe_income: int = delivered_ripe_kg * 2000      # Pemasukan buah matang
	var unripe_penalty: int = collected_unripe_kg * 500  # Denda buah mentah
	var npc_penalty: int = npc_stolen_kg * 500          # Denda buah curian NPC
	
	# Hitung skor akhir
	var final_score: int = ripe_income - (unripe_penalty + npc_penalty)
	
	# Siapkan detail skor untuk UI
	var score_details = {
		"ripe_income": ripe_income,
		"unripe_penalty": unripe_penalty,
		"npc_penalty": npc_penalty,
		"delivered_ripe_kg": delivered_ripe_kg,
		"collected_unripe_kg": collected_unripe_kg,
		"npc_stolen_kg": npc_stolen_kg
	}
	
	# Tampilkan hasil di console untuk debugging
	print("=== HASIL AKHIR RONDE ===")
	print("Buah Matang Terkirim: %d kg" % delivered_ripe_kg)
	print("Buah Mentah Terkumpul: %d kg" % collected_unripe_kg)
	print("Buah Dicuri NPC: %d kg" % npc_stolen_kg)
	print("---")
	print("Pemasukan Buah Matang: Rp %d" % ripe_income)
	print("Denda Buah Mentah: Rp %d" % unripe_penalty)
	print("Denda Buah Curian NPC: Rp %d" % npc_penalty)
	print("---")
	print("SKOR AKHIR: Rp %d" % final_score)
	print("========================")
	
	# ⬅️ PERBAIKAN: HANYA KIRIM SINYAL, TIDAK PANGGIL UI MANAGER LANGSUNG
	round_ended_with_score.emit(final_score, score_details)
	
	# ⬅️ DIHAPUS: Hapus panggilan langsung ke UI manager
	# if ui_manager and ui_manager.has_method("show_round_end_notification"):

# ⬅️ PERBAIKAN: Hapus logic restart lemah, biarkan scene reload yang menangani
func restart_round():
	print("GameModeManager: Restart round called - using scene reload instead")
	# Logic restart sekarang ditangani oleh scene reload di UIManager

func get_remaining_time() -> float:
	return remaining_time

func is_round_running() -> bool:
	return is_round_active and remaining_time > 0

# Fungsi untuk debugging dan testing
func debug_set_remaining_time(time: float):
	remaining_time = time
	game_time_updated.emit(remaining_time)

func debug_end_round_early():
	end_round_and_calculate_score()
