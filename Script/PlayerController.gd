extends Node3D
class_name PlayerController

@export var player_body: CharacterBody3D
@export var camera_node: Camera3D
@export var egrek_node: Node3D
@export var tojok_node: Node3D

enum Tool { EGREK, TOJOK, KETAPEL } 
var current_tool: Tool = Tool.EGREK

@export var ketapel_node: Node3D  

# Tambah variabel untuk animasi ketapel
var ketapel_animation_player: AnimationPlayer = null
const KETAPEL_SHOOT_ANIM_NAME: String = "Shoot"  # Nama animasi shoot

var current_speed = 5.5
const JUMP_VELOCITY = 7.0
const GRAVITY = 25.0

const MOUSE_SENSITIVITY = 0.075
const VERTICAL_CLAMP = Vector2(-70.0, 80.0)

const EGREK_UP_POSITION = Vector3(0.45, -0.25, -1.4)
const EGREK_UP_ROTATION = Vector3(-45.5, -70, 80)
const EGREK_DOWN_POSITION = Vector3(0.2, -0.4, 1.1)
const EGREK_DOWN_ROTATION = Vector3(-45.5, -90.0, 80)

const TOJOK_DEFAULT_POSITION = Vector3(0.215, -0.15, -0.735)
const TOJOK_DEFAULT_ROTATION = Vector3(51.5, 90.0, 82.0)
const TOJOK_SHOOT_POSITION = Vector3(0.18, -0.15, -0.9)
const TOJOK_SHOOT_ROTATION = Vector3(51.5, 90.0, 82.0)

const TRANSITION_THRESHOLD = 35.0
const ANIMATION_DISABLE_THRESHOLD = 10.0
const DECELERATION = 75
const MIN_VELOCITY_THRESHOLD = 0.01

var raycast_node: RayCast3D = null
var is_shooting: bool = false
const SHOOT_COOLDOWN: float = 1.0
var shoot_timer: float = 0.0

var egrek_tween: Tween
var tojok_tween: Tween
var tojok_shoot_tween: Tween

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	switch_tool(Tool.EGREK)
	update_tool_position()
	
	if player_body and player_body.has_method("get_base_speed"):
		current_speed = player_body.get_base_speed()
	
	# Setup animasi ketapel setelah semua node siap
	await get_tree().process_frame
	setup_ketapel_animation()
	
	# Setup raycast untuk ketapel
	setup_raycast()  # TAMBAHKAN INI
	
	
func setup_ketapel_animation():
	if ketapel_node:
		# Cari AnimationPlayer di ketapel_node seperti di WildBoar.gd
		ketapel_animation_player = find_animation_player_in_node(ketapel_node)
		
		if ketapel_animation_player:
			print("AnimationPlayer ditemukan untuk Ketapel")
			print("Animasi yang tersedia: ", ketapel_animation_player.get_animation_list())
			
			# Cek apakah animasi "Shoot" ada
			if ketapel_animation_player.has_animation(KETAPEL_SHOOT_ANIM_NAME):
				print("Animasi 'Shoot' tersedia untuk Ketapel")
			else:
				print("Peringatan: Animasi 'Shoot' tidak ditemukan untuk Ketapel")
		else:
			print("Peringatan: AnimationPlayer tidak ditemukan untuk Ketapel")

func find_animation_player_in_node(node: Node3D) -> AnimationPlayer:
	# Cari AnimationPlayer di dalam node dan children-nya
	# Sama seperti di WildBoar.gd
	var animation_player = node.find_child("AnimationPlayer", true, false)
	
	# Jika tidak ditemukan, cari secara rekursif
	if not animation_player:
		# Cari semua AnimationPlayer di children
		for child in node.get_children():
			if child is AnimationPlayer:
				return child
			
			# Cari lebih dalam
			var found = find_animation_player_recursive(child)
			if found:
				return found
	
	return animation_player

func find_animation_player_recursive(node: Node) -> AnimationPlayer:
	# Cari rekursif untuk AnimationPlayer
	if node is AnimationPlayer:
		return node
	
	for child in node.get_children():
		var found = find_animation_player_recursive(child)
		if found:
			return found
	
	return null

func set_current_speed(new_speed: float):
	current_speed = new_speed

func switch_tool(new_tool: Tool):
	if current_tool == new_tool:
		return
	
	# Sembunyikan semua tool terlebih dahulu
	match current_tool:
		Tool.EGREK:
			if egrek_node:
				egrek_node.visible = false
		Tool.TOJOK:
			if tojok_node:
				tojok_node.visible = false
		Tool.KETAPEL:
			if ketapel_node:
				ketapel_node.visible = false
	
	current_tool = new_tool
	
	# Tampilkan tool yang baru
	match current_tool:
		Tool.EGREK:
			if egrek_node:
				egrek_node.visible = true
		Tool.TOJOK:
			if tojok_node:
				tojok_node.visible = true
		Tool.KETAPEL:
			if ketapel_node:
				ketapel_node.visible = true
				# Setup animasi saat ketapel diaktifkan
				if not ketapel_animation_player:
					setup_ketapel_animation()
	
	update_tool_position()

func update_tool_position():
	if !camera_node:
		return
	
	var camera_x_rotation = camera_node.rotation_degrees.x
	var t = clamp(camera_x_rotation / TRANSITION_THRESHOLD, 0.0, 1.0)
	
	match current_tool:
		Tool.EGREK:
			if egrek_node:
				var target_position = EGREK_UP_POSITION.lerp(EGREK_DOWN_POSITION, 1.0 - t)
				var target_rotation = EGREK_UP_ROTATION.lerp(EGREK_DOWN_ROTATION, 1.0 - t)
				
				if egrek_tween and egrek_tween.is_valid():
					egrek_tween.kill()
				
				egrek_tween = create_tween()
				egrek_tween.set_parallel(true)
				egrek_tween.tween_property(egrek_node, "position", target_position, 0.2)
				egrek_tween.tween_property(egrek_node, "rotation_degrees", target_rotation, 0.2)
		
		Tool.TOJOK:
			if tojok_node:
				if tojok_tween and tojok_tween.is_valid():
					tojok_tween.kill()
				
				tojok_tween = create_tween()
				tojok_tween.set_parallel(true)
				tojok_tween.tween_property(tojok_node, "position", TOJOK_DEFAULT_POSITION, 0.2)
				tojok_tween.tween_property(tojok_node, "rotation_degrees", TOJOK_DEFAULT_ROTATION, 0.2)
		
		Tool.KETAPEL:  # Ketapel diam di tempat
			# Tidak ada animasi atau perubahan posisi untuk sekarang
			pass
	
	update_tool_animation_status()

func update_tool_animation_status():
	if !camera_node:
		return
	
	var animation_enabled = camera_node.rotation_degrees.x > ANIMATION_DISABLE_THRESHOLD
	set_tool_animation_enabled(animation_enabled)

func set_tool_animation_enabled(enabled: bool):
	match current_tool:
		Tool.EGREK:
			if egrek_node:
				egrek_node.set_meta("animation_enabled", enabled)
		Tool.TOJOK:
			if tojok_node:
				tojok_node.set_meta("animation_enabled", true)
		Tool.KETAPEL:
			# Ketapel tidak butuh animasi untuk sekarang
			if ketapel_node:
				ketapel_node.set_meta("animation_enabled", false)

func _input(event):
	if get_tree().paused:
		return
		
	if event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event.is_action_pressed("ui_cancel"):
		toggle_mouse_mode()
	elif event.is_action_pressed("tool_1"):
		switch_tool(Tool.EGREK)
	elif event.is_action_pressed("tool_2"):
		switch_tool(Tool.TOJOK)
	elif event.is_action_pressed("tool_3"):  # Tambah untuk tombol 3
		switch_tool(Tool.KETAPEL)

func handle_mouse_motion(event):
	if !player_body or !camera_node:
		return
	
	player_body.rotation_degrees.y -= event.relative.x * MOUSE_SENSITIVITY
	
	camera_node.rotation_degrees.x -= event.relative.y * MOUSE_SENSITIVITY
	camera_node.rotation_degrees.x = clamp(camera_node.rotation_degrees.x, VERTICAL_CLAMP.x, VERTICAL_CLAMP.y)
	
	update_tool_position()
	update_tool_animation_status()

func toggle_mouse_mode():
	var current_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if current_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

func setup_raycast():
	# Buat RayCast3D node untuk ketapel
	raycast_node = RayCast3D.new()
	raycast_node.enabled = false
	raycast_node.collision_mask = 0b111111  # Deteksi semua layer
	raycast_node.collide_with_areas = true
	raycast_node.collide_with_bodies = true
	raycast_node.exclude_parent = true
	
	# Tambahkan sebagai child dari camera
	if camera_node:
		camera_node.add_child(raycast_node)
		raycast_node.target_position = Vector3(0, 0, -50)  # Ray sejauh 50 unit ke depan
		print("RayCast3D diatur untuk ketapel")

# PlayerController.gd - Tambahkan di _physics_process()
func _physics_process(delta):
	if get_tree().paused:
		return
		
	if !player_body:
		return
	
	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = player_body.transform.basis * Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
	
	if input_direction_2D.length() > 0:
		player_body.velocity.x = direction.x * current_speed
		player_body.velocity.z = direction.z * current_speed
	else:
		var horizontal_velocity = Vector2(player_body.velocity.x, player_body.velocity.z)
		if horizontal_velocity.length() > MIN_VELOCITY_THRESHOLD:
			var deceleration_amount = DECELERATION * delta
			horizontal_velocity = horizontal_velocity.move_toward(Vector2.ZERO, deceleration_amount)
			player_body.velocity.x = horizontal_velocity.x
			player_body.velocity.z = horizontal_velocity.y
		else:
			player_body.velocity.x = 0.0
			player_body.velocity.z = 0.0
	
	player_body.velocity.y -= GRAVITY * delta
	
	if Input.is_action_just_pressed("jump") and player_body.is_on_floor():
		player_body.velocity.y = JUMP_VELOCITY
	
	player_body.move_and_slide()
	
	# Update shoot cooldown
	if shoot_timer > 0:
		shoot_timer -= delta
	
	# Handle shooting input
	if Input.is_action_just_pressed("shoot") and is_ketapel_active() and shoot_timer <= 0:
		shoot_ketapel()

func play_tool_animation():
	match current_tool:
		Tool.EGREK:
			play_egrek_animation()
		Tool.TOJOK:
			play_tojok_animation()
		Tool.KETAPEL:
			play_ketapel_animation()  # Akan kita buat

func play_ketapel_animation():
	# Ketapel: Mainkan animasi "Shoot" jika ada
	if not ketapel_node or not is_instance_valid(ketapel_node):
		return
	
	# Pastikan ketapel aktif
	if not is_ketapel_active():
		return
	
	# Cari AnimationPlayer jika belum ditemukan
	if not ketapel_animation_player:
		setup_ketapel_animation()
	
	# Mainkan animasi Shoot
	if ketapel_animation_player and ketapel_animation_player.has_animation(KETAPEL_SHOOT_ANIM_NAME):
		# Mainkan animasi shoot (tidak loop)
		ketapel_animation_player.play(KETAPEL_SHOOT_ANIM_NAME)
		
		# Tunggu animasi selesai jika ingin sinkronisasi dengan logika lain
		# var anim_length = ketapel_animation_player.current_animation_length
		# await get_tree().create_timer(anim_length).timeout
		
		print("Ketapel: Memutar animasi 'Shoot'")
	else:
		# Fallback: Log atau efek visual sederhana jika tidak ada animasi
		print("Ketapel: Tidak ada animasi 'Shoot' yang ditemukan")
		
		# Anda bisa tambahkan efek visual sederhana di sini
		# Misalnya: menggerakkan ketapel dengan tween
		play_ketapel_fallback_animation()

func play_ketapel_fallback_animation():
	# Animasi fallback sederhana dengan tween jika tidak ada AnimationPlayer
	if ketapel_node:
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Efek "recoil" sederhana
		var original_position = ketapel_node.position
		var recoil_position = original_position + Vector3(0, 0, -0.1)
		
		tween.tween_property(ketapel_node, "position", recoil_position, 0.1)
		tween.tween_property(ketapel_node, "position", original_position, 0.2).set_delay(0.1)

func play_egrek_animation():
	if !egrek_node:
		return
	
	var animation_enabled = egrek_node.get_meta("animation_enabled", true)
	if !animation_enabled:
		return
	
	var fiber_mesh = egrek_node.get_node_or_null("Fiber")
	if fiber_mesh and fiber_mesh is MeshInstance3D:
		var tween = create_tween()
		tween.set_parallel(true)
		
		tween.tween_property(fiber_mesh, "position:z", -0.3, 0.1)
		tween.tween_property(fiber_mesh, "position:z", 0.0, 0.2).set_delay(0.1)

func play_tojok_animation():
	if !tojok_node:
		return
	
	if tojok_shoot_tween and tojok_shoot_tween.is_valid():
		tojok_shoot_tween.kill()
	
	tojok_shoot_tween = create_tween()
	tojok_shoot_tween.set_parallel(true)
	
	tojok_shoot_tween.tween_property(tojok_node, "position", TOJOK_SHOOT_POSITION, 0.1)
	tojok_shoot_tween.tween_property(tojok_node, "rotation_degrees", TOJOK_SHOOT_ROTATION, 0.1)
	
	tojok_shoot_tween.tween_property(tojok_node, "position", TOJOK_DEFAULT_POSITION, 0.2).set_delay(0.1)
	tojok_shoot_tween.tween_property(tojok_node, "rotation_degrees", TOJOK_DEFAULT_ROTATION, 0.2).set_delay(0.1)

# PlayerController.gd - Tambahkan fungsi shoot_ketapel()
func shoot_ketapel():
	if not is_ketapel_active() or shoot_timer > 0:
		return
	
	# Set cooldown
	shoot_timer = SHOOT_COOLDOWN
	
	# Mainkan animasi ketapel
	play_ketapel_animation()
	
	# Aktifkan dan tembak raycast
	if raycast_node:
		raycast_node.enabled = true
		raycast_node.force_raycast_update()
		
		# Cek apakah mengenai sesuatu
		if raycast_node.is_colliding():
			var collider = raycast_node.get_collider()
			var collision_point = raycast_node.get_collision_point()
			
			# Debug: Tampilkan info collision
			print("Ketapel mengenai: ", collider.name if collider else "null")
			print("Posisi collision: ", collision_point)
			
			# Handle collision dengan berbagai tipe object
			handle_ketapel_collision(collider)
		
		# Nonaktifkan raycast setelah digunakan
		raycast_node.enabled = false
	
	# Tampilkan efek visual shot (opsional)
	show_shot_effect()

func handle_ketapel_collision(collider: Object):
	if not collider:
		return
	
	# Cek jika mengenai HarvesterNPC
	if collider is HarvesterNPC or collider.is_in_group("harvester_npc"):
		print("Ketapel mengenai HarvesterNPC!")
		send_npc_to_spawn(collider)
		return
	
	# Cek jika mengenai WildBoar
	if collider is WildBoar or collider.is_in_group("wild_boar"):
		print("Ketapel mengenai WildBoar!")
		send_wildboar_to_spawn(collider)
		return
	
	# Cek parent jika langsung mengenai collision shape
	var parent = collider.get_parent()
	if parent:
		if parent is HarvesterNPC or parent.is_in_group("harvester_npc"):
			print("Ketapel mengenai collision shape HarvesterNPC!")
			send_npc_to_spawn(parent)
			return
		elif parent is WildBoar or parent.is_in_group("wild_boar"):
			print("Ketapel mengenai collision shape WildBoar!")
			send_wildboar_to_spawn(parent)
			return
	
	# Cek node yang lebih tinggi di hierarchy
	var ancestor = collider
	while ancestor and ancestor != get_tree().root:
		if ancestor is HarvesterNPC or ancestor.is_in_group("harvester_npc"):
			print("Ketapel mengenai bagian dari HarvesterNPC!")
			send_npc_to_spawn(ancestor)
			return
		elif ancestor is WildBoar or ancestor.is_in_group("wild_boar"):
			print("Ketapel mengenai bagian dari WildBoar!")
			send_wildboar_to_spawn(ancestor)
			return
		ancestor = ancestor.get_parent()

func send_npc_to_spawn(npc: HarvesterNPC):
	if not is_instance_valid(npc):
		return
	
	# Panggil fungsi untuk kembali ke spawn
	if npc.has_method("transition_to_state"):
		npc.transition_to_state(npc.NPCState.RETURN_TO_SPAWN)
		print("HarvesterNPC dikirim kembali ke spawn point")
		
		# Tambahkan efek visual atau suara
		show_hit_effect_on_npc(npc)

func send_wildboar_to_spawn(boar: WildBoar):
	if not is_instance_valid(boar):
		return
	
	# Untuk WildBoar, gunakan stun lalu kembali ke spawn
	if boar.has_method("stun_boar"):
		# Stun boar dulu
		boar.stun_boar(1.0)
		
		# Setelah stun, paksa kembali ke IDLE state yang akan di-respawn
		await get_tree().create_timer(1.0).timeout
		
		if is_instance_valid(boar) and boar.has_method("transition_to_state"):
			boar.transition_to_state(boar.BoarState.IDLE)
			
			# Cari NPCManager untuk menghapus dari active list
			var npc_managers = get_tree().get_nodes_in_group("npc_manager")
			if npc_managers.size() > 0:
				var npc_manager = npc_managers[0]
				if npc_manager.has_method("remove_wildboar_from_active"):
					npc_manager.remove_wildboar_from_active(boar)
		
		print("WildBoar dikirim kembali ke spawn point")
		show_hit_effect_on_boar(boar)

func show_shot_effect():
	# Tampilkan efek visual shot (misalnya particle system)
	# Anda bisa menambahkan particle system di sini
	pass

func show_hit_effect_on_npc(npc: HarvesterNPC):
	# Tampilkan efek visual ketika terkena ketapel
	# Misalnya: particle system atau perubahan material sementara
	pass

func show_hit_effect_on_boar(boar: WildBoar):
	# Tampilkan efek visual ketika terkena ketapel
	# Misalnya: particle system atau perubahan material sementara
	pass

func is_egrek_active() -> bool:
	return current_tool == Tool.EGREK

func is_tojok_active() -> bool:
	return current_tool == Tool.TOJOK

func is_ketapel_active() -> bool:  # Tambah ini
	return current_tool == Tool.KETAPEL

func get_current_tool() -> Tool:
	return current_tool
