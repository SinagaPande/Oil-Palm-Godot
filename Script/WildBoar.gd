extends CharacterBody3D
class_name WildBoar

enum BoarState {
	SPAWN,
	CHASE,
	ATTACK,
	IDLE
}

# DIUBAH: Hapus @export dari variabel statistik
var move_speed: float = 8.0
var attack_range: float = 2.5
var detection_range: float = 20.0
var attack_cooldown: float = 2.0

# Export variables - simple configuration
@export var attack_damage: int = 20

# Variabel animasi
@export var chase_animation_name: String = "Chase"
@export var idle_animation_name: String = "Idle"
@export var attack_animation_name: String = "Attack"

var current_state: BoarState = BoarState.SPAWN
var player_node: Node3D = null
var camera_node: Camera3D = null

var attack_timer: float = 0.0
var can_attack: bool = true

# Untuk animasi sederhana
var animation_player: AnimationPlayer = null
var current_animation: String = ""
var is_attack_playing: bool = false

# Setter untuk statistik dari GameModeManager
func set_stats(new_detection_range: float, new_move_speed: float, new_attack_range: float, new_attack_cooldown: float):
	detection_range = new_detection_range
	move_speed = new_move_speed
	attack_range = new_attack_range
	attack_cooldown = new_attack_cooldown
	
	print("WildBoar statistik diatur:")
	print("  - Detection range: ", detection_range)
	print("  - Move speed: ", move_speed)
	print("  - Attack range: ", attack_range)
	print("  - Attack cooldown: ", attack_cooldown)

func _ready():
	add_to_group("wild_boar")
	add_to_group("enemy")
	setup_collision_config()
	
	# Cari AnimationPlayer secara otomatis
	find_animation_player_auto()
	
	transition_to_state(BoarState.SPAWN)

func find_animation_player_auto():
	# Cari AnimationPlayer di dalam scene tree
	animation_player = find_child("AnimationPlayer", true, false)
	
	# Jika tidak ditemukan langsung, cari secara rekursif
	if not animation_player:
		var all_nodes = get_tree().get_nodes_in_group("animation")
		for node in all_nodes:
			if node is AnimationPlayer:
				animation_player = node
				break
	
	# Debug info
	if animation_player:
		print("AnimationPlayer ditemukan untuk WildBoar")
		print("Animasi yang tersedia: ", animation_player.get_animation_list())
	else:
		print("Peringatan: AnimationPlayer tidak ditemukan untuk WildBoar")

func setup_collision_config():
	# Setup collision sederhana seperti HarvesterNPC
	collision_layer = 4  # Enemy layer
	collision_mask = 1   # Hanya layer ground
	# Non-aktifkan collision dengan object lain seperti HarvesterNPC
	set_collision_layer_value(2, false)  # Player
	set_collision_layer_value(3, false)  # NPC lain
	set_collision_layer_value(5, false)  # Object lainnya
	
	# Tambahkan collision shape jika belum ada
	var collision_shape = find_child("CollisionShape3D", true, false)
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.shape = CapsuleShape3D.new()
		collision_shape.shape.height = 2.0
		collision_shape.shape.radius = 0.5
		add_child(collision_shape)
		collision_shape.owner = get_tree().edited_scene_root

func _physics_process(delta):
	state_process(delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0  # Reset vertical velocity on floor
	
	# Move and slide
	move_and_slide()
	
	# Update attack cooldown
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

func state_process(delta):
	# Cari player jika belum ada
	if not player_node or not is_instance_valid(player_node):
		find_player()
		if not player_node:
			return
	
	# Check if player is dead
	var player_is_dead = false
	if player_node.has_method("is_player_dead"):
		player_is_dead = player_node.is_player_dead()
	
	if player_is_dead:
		transition_to_state(BoarState.IDLE)
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	match current_state:
		BoarState.SPAWN:
			initialize_boar()
			
		BoarState.CHASE:
			if distance_to_player <= attack_range:
				transition_to_state(BoarState.ATTACK)
			elif distance_to_player <= detection_range:
				# Mengejar player
				move_towards_target(player_node.global_position)
				# Play animasi Chase dengan loop
				play_animation(chase_animation_name, true)
			else:
				# Player terlalu jauh, idle
				transition_to_state(BoarState.IDLE)
			
		BoarState.ATTACK:
			if distance_to_player > attack_range * 1.2:
				# Player keluar dari jarak serang, kejar lagi
				transition_to_state(BoarState.CHASE)
			elif can_attack:
				perform_attack()
			else:
				# Tetap lihat ke player saat dalam jarak serang
				var direction = (player_node.global_position - global_position).normalized()
				direction.y = 0
				if direction.length() > 0.1:
					look_at(global_position + direction, Vector3.UP)
				# Jika tidak menyerang, kembali ke idle animasi
				if not is_attack_playing:
					play_animation(idle_animation_name, true)
			
		BoarState.IDLE:
			# Jika player masuk range deteksi, kejar
			if distance_to_player <= detection_range and not player_is_dead:
				transition_to_state(BoarState.CHASE)
			else:
				# Idle animation dengan loop
				velocity.x = 0
				velocity.z = 0
				play_animation(idle_animation_name, true)

func perform_attack():
	if not player_node or not is_instance_valid(player_node):
		return
	
	if not can_attack:
		return
	
	# Cek apakah player masih hidup
	if player_node.has_method("is_player_dead") and player_node.is_player_dead():
		transition_to_state(BoarState.IDLE)
		return
	
	# Tandai sedang memainkan animasi serangan
	is_attack_playing = true
	
	# Play attack animation (non-loop)
	play_animation(attack_animation_name, false)
	
	# Tunggu sedikit untuk sinkronisasi animasi dengan damage
	await get_tree().create_timer(0.3).timeout
	
	# Serang player dengan damage 20 HP
	if player_node.has_method("take_damage"):
		player_node.take_damage(attack_damage)
		print("Babi hutan menyerang player! Damage: %d HP" % attack_damage)
	
	# Attack cooldown
	can_attack = false
	attack_timer = attack_cooldown
	
	# Tunggu animasi serangan selesai
	if animation_player and animation_player.has_animation(attack_animation_name):
		var attack_anim = animation_player.get_animation(attack_animation_name)
		if attack_anim:
			await get_tree().create_timer(attack_anim.length - 0.3).timeout
	
	# Reset flag
	is_attack_playing = false
	
	# Kembali ke chase state setelah attack
	if current_state == BoarState.ATTACK:
		transition_to_state(BoarState.CHASE)

func transition_to_state(new_state: BoarState):
	state_exit(current_state)
	current_state = new_state
	state_enter(new_state)

func state_enter(state: BoarState):
	match state:
		BoarState.SPAWN:
			play_animation(idle_animation_name, true)
			
		BoarState.CHASE:
			can_attack = true
			attack_timer = 0.0
			is_attack_playing = false
			play_animation(chase_animation_name, true)
			
		BoarState.ATTACK:
			# Hanya set state, animasi akan diputar di perform_attack()
			pass
			
		BoarState.IDLE:
			play_animation(idle_animation_name, true)

func state_exit(state: BoarState):
	# Reset attack flag saat keluar dari attack state
	if state == BoarState.ATTACK:
		is_attack_playing = false

func move_towards_target(target_position: Vector3):
	var direction = (target_position - global_position).normalized()
	direction.y = 0
	
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	
	# Rotasi untuk menghadap target
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)

func initialize_boar():
	find_player()
	if player_node:
		# Langsung mulai mengejar player
		transition_to_state(BoarState.CHASE)
	else:
		# Jika player belum ditemukan, tunggu sebentar lalu coba lagi
		await get_tree().create_timer(0.5).timeout
		find_player()
		if player_node:
			transition_to_state(BoarState.CHASE)
		else:
			transition_to_state(BoarState.IDLE)

func find_player():
	if not is_inside_tree():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]

func play_animation(anim_name: String, loop: bool = false):
	# Jika animasi sama dan sedang diputar, jangan ganggu
	if anim_name == current_animation and animation_player and animation_player.is_playing():
		return
	
	if animation_player and animation_player.has_animation(anim_name):
		current_animation = anim_name
		
		# Set loop mode jika tersedia
		var anim = animation_player.get_animation(anim_name)
		if anim:
			if loop:
				anim.loop_mode = Animation.LOOP_LINEAR
			else:
				anim.loop_mode = Animation.LOOP_NONE
		
		animation_player.play(anim_name)
	else:
		# Coba cari animasi dengan nama yang mirip
		if animation_player:
			for anim in animation_player.get_animation_list():
				if anim_name.to_lower() in anim.to_lower():
					current_animation = anim
					
					# Set loop mode
					var anim_ref = animation_player.get_animation(anim)
					if anim_ref:
						if loop:
							anim_ref.loop_mode = Animation.LOOP_LINEAR
						else:
							anim_ref.loop_mode = Animation.LOOP_NONE
					
					animation_player.play(anim)
					return
			
			# Fallback ke animasi pertama yang ada
			var animations = animation_player.get_animation_list()
			if animations.size() > 0:
				current_animation = animations[0]
				animation_player.play(animations[0])

# Public methods untuk interaksi eksternal
func stun_boar(duration: float = 1.5):
	# Interupsi state saat ini
	can_attack = false
	attack_timer = duration
	is_attack_playing = false
	
	# Coba mainkan animasi "Hurt" jika ada
	if animation_player and animation_player.has_animation("Hurt"):
		play_animation("Hurt", false)
	else:
		play_animation(idle_animation_name, true)
	
	# Stop movement selama stunned
	velocity = Vector3.ZERO
	
	# Kembali ke chase setelah stun
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self) and player_node and is_instance_valid(player_node):
		if not player_node.has_method("is_player_dead") or not player_node.is_player_dead():
			transition_to_state(BoarState.CHASE)

func is_chasing() -> bool:
	return current_state == BoarState.CHASE

func is_attacking() -> bool:
	return current_state == BoarState.ATTACK

func get_current_state() -> String:
	match current_state:
		BoarState.SPAWN:
			return "SPAWN"
		BoarState.CHASE:
			return "CHASE"
		BoarState.ATTACK:
			return "ATTACK"
		BoarState.IDLE:
			return "IDLE"
		_:
			return "UNKNOWN"
