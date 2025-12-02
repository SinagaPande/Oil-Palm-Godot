extends Control
class_name UIManager

@onready var ripe_label: Label = $RipeLabel
@onready var unripe_label: Label = $UnripeLabel
@onready var interaction_label: Label = $InteractionLabel
@onready var notification_label: Label = $NotificationLabel
@onready var npc_harvest_label: Label = $NpcHarvestLabel
@onready var timer_label: Label = find_child("TimerLabel", true, false)
@onready var pause_menu: Control = $PauseMenu
@onready var round_end_panel: Control = $RoundEndPanel

var notification_timer: Timer
var is_paused: bool = false
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

func _ready():
	visible = true
	
	set_process_input(true)
	set_process_unhandled_input(true)
	
	notification_timer = Timer.new()
	notification_timer.one_shot = true
	notification_timer.timeout.connect(_on_notification_timeout)
	add_child(notification_timer)
	
	interaction_label.visible = false
	notification_label.visible = false
	
	call_deferred("setup_pause_menu")
	call_deferred("setup_round_end_ui")
	call_deferred("show_inventory_labels")
	call_deferred("connect_to_game_systems")

func _process(_delta):
	if not should_show_ui_labels():
		update_sensitive_labels_visibility()

func _enter_tree():
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_pause_menu():
	if pause_menu:
		pause_menu.visible = false
		
		var resume_button = pause_menu.find_child("ResumeButton", true, false)
		var restart_button = pause_menu.find_child("RestartButton", true, false)
		var quit_button = pause_menu.find_child("QuitButton", true, false)
		
		if resume_button and not resume_button.is_connected("pressed", _on_resume_pressed):
			resume_button.pressed.connect(_on_resume_pressed)
			
		if restart_button:
			restart_button.pressed.connect(_on_restart_pressed)
			
		if quit_button:
			quit_button.pressed.connect(_on_quit_pressed)

func setup_timer_display():
	if timer_label:
		timer_label.visible = true
		timer_label.text = "03:00"

func update_timer_display(remaining_time: float):
	if timer_label:
		var minutes = int(remaining_time) / 60
		var seconds = int(remaining_time) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		
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
	
	update_ui_from_player()
	update_npc_harvest_display(0)

func connect_to_game_systems():
	await get_tree().process_frame
	
	var inventory_system = _find_node_by_path_or_group("/root/Node3D/InventorySystem", "inventory_system")
	var player = _find_node_by_path_or_group("/root/Node3D/Player", "player")
	var npc_manager = _find_node_by_path_or_group("/root/Node3D/NPCManager", "npc_manager")
	var game_mode_manager = _find_node_by_path_or_group("/root/Node3D/GameModeManager", "game_mode_manager")
	
	if inventory_system and inventory_system.has_signal("permanent_inventory_updated"):
		inventory_system.permanent_inventory_updated.connect(update_permanent_display)
	else:
		update_ui_from_player()
	
	if player and player.has_signal("carried_fruits_updated"):
		player.carried_fruits_updated.connect(update_carried_fruits)
	elif player and player.has_signal("player_fully_ready"):
		player.player_fully_ready.connect(_on_player_ready)
	else:
		update_ui_from_player()
	
	if npc_manager:
		if npc_manager.has_signal("npc_total_harvest_updated"):
			npc_manager.npc_total_harvest_updated.connect(update_npc_harvest_display)
		if npc_manager.has_method("get_total_npc_harvest"):
			update_npc_harvest_display(npc_manager.get_total_npc_harvest())
	
	update_ui_from_player()
	
	if game_mode_manager:
		if game_mode_manager.has_signal("game_time_updated") and not game_mode_manager.game_time_updated.is_connected(update_timer_display):
			game_mode_manager.game_time_updated.connect(update_timer_display)
		
		if game_mode_manager.has_signal("round_ended_with_score") and not game_mode_manager.round_ended_with_score.is_connected(show_round_end_notification):
			game_mode_manager.round_ended_with_score.connect(show_round_end_notification)
	
	setup_round_end_ui()
	setup_timer_display()

func _unhandled_input(event):
	if round_end_panel and round_end_panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause():
	if round_end_panel and round_end_panel.visible:
		return
	
	if is_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	if is_paused:
		return
	
	is_paused = true
	previous_mouse_mode = Input.get_mouse_mode()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if pause_menu:
		pause_menu.visible = true
		var resume_button = pause_menu.find_child("ResumeButton", true, false)
		if resume_button:
			resume_button.grab_focus()
	
	on_ui_state_changed()

func resume_game():
	if not is_paused:
		return
	
	is_paused = false
	if pause_menu:
		pause_menu.visible = false
	
	get_tree().paused = false
	Input.set_mouse_mode(previous_mouse_mode)
	on_ui_state_changed()

func _on_resume_pressed():
	resume_game()

func _on_restart_pressed():
	resume_game()
	get_tree().reload_current_scene()

func _on_quit_pressed():
	resume_game()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func update_npc_harvest_display(total_kg: int):
	if npc_harvest_label:
		npc_harvest_label.visible = true
		npc_harvest_label.text = "Buah yang Dicuri: %d kg" % total_kg

func _on_player_ready():
	await get_tree().process_frame
	update_ui_from_player()

func update_ui_from_player():
	var player = _find_node_by_path_or_group("/root/Node3D/Player", "player")
	var inventory_system = _find_node_by_path_or_group("/root/Node3D/InventorySystem", "inventory_system")
	
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
	if interaction_label:
		interaction_label.visible = false

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
	if notification_label:
		notification_label.visible = false

func update_permanent_display(delivered_ripe_kg: int, collected_unripe_kg: int):
	if ripe_label:
		var player = _find_node_by_path_or_group("/root/Node3D/Player", "player")
		var carried_ripe = 0
		if player and player.has_method("get_carried_ripe_fruits"):
			carried_ripe = player.get_carried_ripe_fruits()
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]
	
	if unripe_label:
		unripe_label.text = "Buah mentah: %d kg" % collected_unripe_kg

func update_carried_fruits(carried_ripe: int, _carried_kg: int):
	if ripe_label:
		var inventory_system = _find_node_by_path_or_group("/root/Node3D/InventorySystem", "inventory_system")
		var delivered_ripe_kg = 0
		if inventory_system:
			delivered_ripe_kg = inventory_system.get_delivered_ripe_kg()
		ripe_label.text = "Buah matang: %d dibawa, total %d kg" % [carried_ripe, delivered_ripe_kg]

func update_temporary_display(carried_ripe: int, carried_kg: int):
	update_carried_fruits(carried_ripe, carried_kg)

func update_display(ripe_count: int, ripe_kg: int):
	update_temporary_display(ripe_count, ripe_kg)

func setup_round_end_ui():
	if round_end_panel:
		round_end_panel.visible = false
		
		var final_score_label = round_end_panel.find_child("FinalScoreLabel", true, false)
		var details_label = round_end_panel.find_child("DetailsLabel", true, false)
		var restart_button_end = round_end_panel.find_child("RestartButton", true, false)
		var quit_button_end = round_end_panel.find_child("QuitButton", true, false)
		
		if restart_button_end and not restart_button_end.is_connected("pressed", _on_restart_pressed):
			restart_button_end.pressed.connect(_on_restart_pressed)
			
		if quit_button_end and not quit_button_end.is_connected("pressed", _on_quit_pressed):
			quit_button_end.pressed.connect(_on_quit_pressed)

func show_round_end_notification(final_score: int, score_details: Dictionary):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Ambil harga dari score_details - DITAMBAHKAN
	var ripe_price = score_details.get("ripe_fruit_price", 2000)
	var unripe_penalty_price = score_details.get("unripe_fruit_penalty", 500)
	var npc_penalty_price = score_details.get("npc_stolen_penalty", 500)
	
	if round_end_panel:
		round_end_panel.visible = true
		
		var final_score_label = round_end_panel.find_child("FinalScoreLabel", true, false)
		var details_label = round_end_panel.find_child("DetailsLabel", true, false)
		var restart_button_end = round_end_panel.find_child("RestartButton", true, false)
		var quit_button_end = round_end_panel.find_child("QuitButton", true, false)
		
		if final_score_label:
			final_score_label.text = "Skor Akhir: Rp %s" % _format_currency(final_score)
			
			if final_score > 0:
				final_score_label.modulate = Color.GREEN
			elif final_score < 0:
				final_score_label.modulate = Color.RED
			else:
				final_score_label.modulate = Color.WHITE
		
		if details_label:
			var details_text = "RINCIAN AKHIR:\n"
			
			var ripe_kg = score_details.get("delivered_ripe_kg", 0)
			var ripe_income = score_details.get("ripe_income", 0)
			
			# Format harga dengan padding yang dinamis - DIPERBAHARUI
			var ripe_price_formatted = _format_currency(ripe_price)
			var ripe_price_padding = ""
			if ripe_price >= 1000 and ripe_price < 10000:
				ripe_price_padding = " "
			elif ripe_price < 1000:
				ripe_price_padding = "   "
			
			details_text += "+ PENJUALAN BUAH MATANG:    %3d kg × Rp%s%s = +Rp %8s\n" % [
				ripe_kg, 
				ripe_price_padding,
				ripe_price_formatted,
				_format_currency_with_padding(ripe_income)
			]
			
			var unripe_kg = score_details.get("collected_unripe_kg", 0)
			var unripe_penalty_amount = score_details.get("unripe_penalty", 0)
			
			# Format harga dengan padding yang dinamis - DIPERBAHARUI
			var unripe_price_formatted = _format_currency(unripe_penalty_price)
			var unripe_price_padding = ""
			if unripe_penalty_price >= 1000 and unripe_penalty_price < 10000:
				unripe_price_padding = " "
			elif unripe_penalty_price < 1000:
				unripe_price_padding = "   "
			
			details_text += "- KERUGIAN BUAH MENTAH:     %3d kg × Rp%s%s = -Rp %8s\n" % [
				unripe_kg,
				unripe_price_padding,
				unripe_price_formatted,
				_format_currency_with_padding(unripe_penalty_amount)
			]
			
			var npc_kg = score_details.get("npc_stolen_kg", 0)
			var npc_penalty_amount = score_details.get("npc_penalty", 0)
			
			# Format harga dengan padding yang dinamis - DIPERBAHARUI
			var npc_price_formatted = _format_currency(npc_penalty_price)
			var npc_price_padding = ""
			if npc_penalty_price >= 1000 and npc_penalty_price < 10000:
				npc_price_padding = " "
			elif npc_penalty_price < 1000:
				npc_price_padding = "   "
			
			details_text += "- KERUGIAN KARENA PENCURIAN: %3d kg × Rp%s%s = -Rp %8s" % [
				npc_kg,
				npc_price_padding,
				npc_price_formatted,
				_format_currency_with_padding(npc_penalty_amount)
			]
			
			details_label.text = details_text
		
		on_ui_state_changed()
		
		if restart_button_end:
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
		if i > 0 and i % 3 == 0:
			formatted = "." + formatted
		formatted = str_amount[length - i - 1] + formatted
	
	if is_negative:
		formatted = "-" + formatted
	
	return formatted

func should_show_ui_labels() -> bool:
	return not (is_paused or (round_end_panel and round_end_panel.visible))

func update_sensitive_labels_visibility():
	var should_show = should_show_ui_labels()
	
	if interaction_label and not should_show and interaction_label.visible:
		interaction_label.visible = false
	
	if notification_label and not should_show and notification_label.visible:
		notification_label.visible = false
		if notification_timer and notification_timer.time_left > 0:
			notification_timer.stop()

func on_ui_state_changed():
	update_sensitive_labels_visibility()

func _find_node_by_path_or_group(path: String, group: String) -> Node:
	var node = get_node_or_null(path)
	if not node:
		var nodes = get_tree().get_nodes_in_group(group)
		if nodes.size() > 0:
			node = nodes[0]
	return node
