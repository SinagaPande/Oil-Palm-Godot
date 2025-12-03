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

var audio_player: AudioStreamPlayer3D = null

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
	setup_raycast()
	
	# Setup audio player untuk efek suara ketapel
	setup_audio_player()
	
	# Setup audio player untuk efek suara ketapel
	setup_audio_player()
	
	
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
	# Tidak perlu RayCast3D node, kita akan menggunakan intersect_ray langsung
	# untuk memastikan raycast mengarah ke tengah layar (crosshair)
	raycast_node = null  # Tidak digunakan, kita pakai intersect_ray langsung
	print("Raycast system diatur untuk ketapel (menggunakan intersect_ray dari tengah layar)")

func setup_audio_player():
	# Setup AudioStreamPlayer3D untuk efek suara ketapel
	audio_player = AudioStreamPlayer3D.new()
	audio_player.volume_db = 0.0
	audio_player.max_distance = 50.0
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	# Load sound effect ketapel
	var sound_path = "res://soundeffect/katapel.mp3"
	if ResourceLoader.exists(sound_path):
		var audio_stream = load(sound_path)
		if audio_stream:
			audio_player.stream = audio_stream
			print("Sound effect ketapel dimuat")
		else:
			print("Peringatan: Gagal memuat sound effect ketapel")
	else:
		print("Peringatan: File sound effect ketapel tidak ditemukan: ", sound_path)
	
	# Tambahkan sebagai child dari camera atau player
	if camera_node:
		camera_node.add_child(audio_player)
	elif player_body:
		player_body.add_child(audio_player)

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
		print("Ketapel tidak bisa menembak: ketapel aktif=", is_ketapel_active(), ", cooldown=", shoot_timer)
		return
	
	print("=== KETAPEL MENEMBAK! ===")
	
	# Set cooldown
	shoot_timer = SHOOT_COOLDOWN
	
	# Mainkan efek suara ketapel
	play_ketapel_sound()
	
	# Mainkan animasi ketapel
	play_ketapel_animation()
	
	# Tampilkan efek visual shot
	show_shot_effect()
	
	# Tembak raycast dari tengah layar (crosshair)
	if camera_node:
		# Dapatkan viewport center (tengah layar dimana crosshair berada)
		var viewport = get_viewport()
		var viewport_size = viewport.get_visible_rect().size
		var screen_center = viewport_size / 2.0
		
		# Project screen center ke 3D space
		var ray_origin = camera_node.project_ray_origin(screen_center)
		var ray_direction = camera_node.project_ray_normal(screen_center)
		var ray_end = ray_origin + ray_direction * 200.0  # Ray sejauh 200 unit (diperpanjang)
		
		# Gunakan intersect_ray untuk deteksi collision
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		# Deteksi layer 3 (NPC), layer 4 (Enemy/WildBoar) - fokus pada layer ini
		query.collision_mask = 0b111111  # Deteksi semua layer
		query.collide_with_areas = false  # Hanya bodies, tidak areas
		query.collide_with_bodies = true
		
		# Exclude player dari collision
		var exclude_list = []
		if player_body:
			exclude_list.append(player_body)
		# Exclude camera dan child-nya
		if camera_node:
			exclude_list.append(camera_node)
		# Exclude ground/terrain (layer 1) - kita akan cek manual
		query.exclude = exclude_list
		
		# Coba beberapa raycast dengan prioritas berbeda
		# Pertama, coba dengan mask yang fokus pada NPC dan Enemy
		var query_npc_enemy = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query_npc_enemy.collision_mask = 0b001100  # Hanya layer 3 (NPC) dan 4 (Enemy)
		query_npc_enemy.collide_with_areas = false
		query_npc_enemy.collide_with_bodies = true
		query_npc_enemy.exclude = exclude_list
		
		var result = space_state.intersect_ray(query_npc_enemy)
		
		# Jika tidak menemukan NPC/Enemy, coba dengan semua layer
		if not result:
			result = space_state.intersect_ray(query)
		
		if result:
			var collider = result.get("collider")
			var collision_point = result.get("position")
			
			# Debug: Tampilkan info collision
			print("=== KETAPEL HIT ===")
			print("Ketapel mengenai: ", collider.name if collider else "null")
			print("Tipe collider: ", collider.get_class() if collider else "null")
			print("Posisi collision: ", collision_point)
			if collider:
				print("Groups: ", collider.get_groups())
				print("Parent: ", collider.get_parent().name if collider.get_parent() else "null")
				# Cek collision layer
				if collider.has_method("get_collision_layer"):
					print("Collision layer: ", collider.get_collision_layer())
			
			# Cek apakah mengenai babi atau pencuri
			var is_target = false
			if collider is HarvesterNPC or collider is WildBoar:
				is_target = true
			elif collider.is_in_group("harvester_npc") or collider.is_in_group("wild_boar"):
				is_target = true
			else:
				# Cek parent
				var parent = collider.get_parent()
				if parent:
					if parent is HarvesterNPC or parent is WildBoar:
						is_target = true
					elif parent.is_in_group("harvester_npc") or parent.is_in_group("wild_boar"):
						is_target = true
			
			if is_target:
				# Handle collision dengan target
				handle_ketapel_collision(collider)
			else:
				# Jika hanya mengenai ground/object lain, cari target terdekat di sekitar crosshair
				print("Ketapel hanya mengenai ground/object lain, mencari target terdekat di sekitar crosshair...")
				find_nearest_target_near_crosshair(ray_origin, ray_direction)
		else:
			# Jika tidak ada collision langsung, coba cari babi/pencuri terdekat di sekitar crosshair
			print("Ketapel tidak mengenai apapun langsung, mencari target terdekat...")
			find_nearest_target_near_crosshair(ray_origin, ray_direction)
	else:
		print("ERROR: Camera node tidak ditemukan!")

func find_nearest_target_near_crosshair(ray_origin: Vector3, ray_direction: Vector3):
	# Cari babi atau pencuri terdekat di sekitar raycast
	var search_radius = 8.0  # Radius pencarian 8 unit (diperbesar)
	var max_distance = 50.0  # Maksimal jarak dari camera
	var nearest_boar: WildBoar = null
	var nearest_npc: HarvesterNPC = null
	var nearest_boar_distance = INF
	var nearest_npc_distance = INF
	
	print("Mencari target terdekat di sekitar crosshair (radius: ", search_radius, ", max distance: ", max_distance, ")")
	
	# Cari semua babi
	var boars = get_tree().get_nodes_in_group("wild_boar")
	print("Ditemukan ", boars.size(), " babi di scene")
	for boar in boars:
		if not is_instance_valid(boar) or not (boar is WildBoar):
			continue
		
		# Hitung jarak dari ray ke babi
		var boar_pos = boar.global_position
		var to_boar = boar_pos - ray_origin
		var distance_from_camera = to_boar.length()
		
		# Skip jika terlalu jauh
		if distance_from_camera > max_distance:
			continue
		
		var projection_length = to_boar.dot(ray_direction)
		
		# Jika proyeksi negatif, babi di belakang camera
		if projection_length < 0:
			continue
		
		# Hitung jarak dari ray ke babi
		var closest_point_on_ray = ray_origin + ray_direction * projection_length
		var distance_to_ray = boar_pos.distance_to(closest_point_on_ray)
		
		print("  Babi ditemukan - pos: ", boar_pos, ", distance to ray: ", distance_to_ray, ", projection: ", projection_length)
		
		# Jika dalam radius dan lebih dekat dari sebelumnya
		if distance_to_ray <= search_radius and projection_length < nearest_boar_distance:
			nearest_boar = boar
			nearest_boar_distance = projection_length
			print("    -> Babi ini lebih dekat!")
	
	# Cari semua NPC
	var npcs = get_tree().get_nodes_in_group("harvester_npc")
	print("Ditemukan ", npcs.size(), " NPC di scene")
	for npc in npcs:
		if not is_instance_valid(npc) or not (npc is HarvesterNPC):
			continue
		
		# Hitung jarak dari ray ke NPC
		var npc_pos = npc.global_position
		var to_npc = npc_pos - ray_origin
		var distance_from_camera = to_npc.length()
		
		# Skip jika terlalu jauh
		if distance_from_camera > max_distance:
			continue
		
		var projection_length = to_npc.dot(ray_direction)
		
		# Jika proyeksi negatif, NPC di belakang camera
		if projection_length < 0:
			continue
		
		# Hitung jarak dari ray ke NPC
		var closest_point_on_ray = ray_origin + ray_direction * projection_length
		var distance_to_ray = npc_pos.distance_to(closest_point_on_ray)
		
		print("  NPC ditemukan - pos: ", npc_pos, ", distance to ray: ", distance_to_ray, ", projection: ", projection_length)
		
		# Jika dalam radius dan lebih dekat dari sebelumnya
		if distance_to_ray <= search_radius and projection_length < nearest_npc_distance:
			nearest_npc = npc
			nearest_npc_distance = projection_length
			print("    -> NPC ini lebih dekat!")
	
	# Pilih target terdekat
	if nearest_boar and (not nearest_npc or nearest_boar_distance < nearest_npc_distance):
		print("Menemukan babi terdekat di sekitar crosshair (jarak: ", nearest_boar_distance, ")")
		send_wildboar_to_spawn(nearest_boar)
	elif nearest_npc:
		print("Menemukan NPC terdekat di sekitar crosshair (jarak: ", nearest_npc_distance, ")")
		send_npc_to_spawn(nearest_npc)
	else:
		print("Tidak ada target terdekat di sekitar crosshair")

func handle_ketapel_collision(collider: Object):
	if not collider:
		return
	
	print("handle_ketapel_collision - Collider: ", collider.name, " Type: ", collider.get_class())
	
	# Cek langsung jika collider adalah HarvesterNPC atau WildBoar
	if collider is HarvesterNPC:
		print("Ketapel mengenai HarvesterNPC (langsung)!")
		send_npc_to_spawn(collider)
		return
	
	if collider is WildBoar:
		print("Ketapel mengenai WildBoar (langsung)!")
		send_wildboar_to_spawn(collider)
		return
	
	# Cek group
	if collider.is_in_group("harvester_npc"):
		print("Ketapel mengenai HarvesterNPC (by group)!")
		# Cari parent yang merupakan HarvesterNPC
		var npc = collider
		while npc and not (npc is HarvesterNPC):
			npc = npc.get_parent()
		if npc and npc is HarvesterNPC:
			send_npc_to_spawn(npc)
		return
	
	if collider.is_in_group("wild_boar"):
		print("Ketapel mengenai WildBoar (by group)!")
		# Cari parent yang merupakan WildBoar
		var boar = collider
		while boar and not (boar is WildBoar):
			boar = boar.get_parent()
		if boar and boar is WildBoar:
			send_wildboar_to_spawn(boar)
		return
	
	# Cek parent jika langsung mengenai collision shape
	var parent = collider.get_parent()
	if parent:
		if parent is HarvesterNPC:
			print("Ketapel mengenai collision shape HarvesterNPC!")
			send_npc_to_spawn(parent)
			return
		elif parent is WildBoar:
			print("Ketapel mengenai collision shape WildBoar!")
			send_wildboar_to_spawn(parent)
			return
	
	# Cek node yang lebih tinggi di hierarchy (hingga 5 level)
	var ancestor = collider
	var depth = 0
	while ancestor and ancestor != get_tree().root and depth < 5:
		if ancestor is HarvesterNPC:
			print("Ketapel mengenai bagian dari HarvesterNPC (depth ", depth, ")!")
			send_npc_to_spawn(ancestor)
			return
		elif ancestor is WildBoar:
			print("Ketapel mengenai bagian dari WildBoar (depth ", depth, ")!")
			send_wildboar_to_spawn(ancestor)
			return
		ancestor = ancestor.get_parent()
		depth += 1
	
	print("Peringatan: Collider tidak dikenali sebagai HarvesterNPC atau WildBoar")

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
		print("ERROR: WildBoar tidak valid di send_wildboar_to_spawn")
		return
	
	print("=== send_wildboar_to_spawn DIPANGGIL ===")
	print("Babi name: ", boar.name)
	print("Babi state saat ini: ", boar.get_current_state())
	print("Babi position: ", boar.global_position)
	
	# Panggil fungsi flee_from_player() untuk membuat babi lari dan hilang setelah 3 detik
	if boar.has_method("flee_from_player"):
		print("Memanggil flee_from_player() pada babi...")
		boar.flee_from_player()
		print("Babi hutan terkena ketapel, akan lari dan hilang setelah 3 detik")
		show_hit_effect_on_boar(boar)
	else:
		# Fallback jika fungsi tidak ada
		print("Peringatan: Fungsi flee_from_player() tidak ditemukan di WildBoar")
		print("Methods yang tersedia: ", boar.get_method_list())

func show_hit_effect_on_npc(_npc: HarvesterNPC):
	# Tampilkan efek visual ketika terkena ketapel
	# Misalnya: particle system atau perubahan material sementara
	pass

func show_hit_effect_on_boar(_boar: WildBoar):
	# Tampilkan efek visual ketika terkena ketapel
	# Misalnya: particle system atau perubahan material sementara
	pass

func play_ketapel_sound():
	# Mainkan efek suara ketapel
	if audio_player and audio_player.stream:
		audio_player.play()
		print("Memutar suara ketapel")
	else:
		print("Peringatan: Audio player atau stream tidak tersedia")

func show_shot_effect():
	# Tampilkan efek visual shot - flash effect pada ketapel
	if ketapel_node:
		# Efek flash/recoil pada ketapel
		var original_scale = ketapel_node.scale
		var flash_scale = original_scale * 1.1
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(ketapel_node, "scale", flash_scale, 0.05)
		tween.tween_property(ketapel_node, "scale", original_scale, 0.15).set_delay(0.05)
		
		print("Efek visual shot ditampilkan")

func is_egrek_active() -> bool:
	return current_tool == Tool.EGREK

func is_tojok_active() -> bool:
	return current_tool == Tool.TOJOK

func is_ketapel_active() -> bool:  # Tambah ini
	return current_tool == Tool.KETAPEL

func get_current_tool() -> Tool:
	return current_tool
