extends CharacterBody3D
class_name WildBoar

enum BoarState {
	SPAWN,
	CHASE,
	ATTACK,
	IDLE
}

# Export variables - simple configuration
@export var move_speed: float = 8.0
@export var attack_range: float = 2.5
@export var detection_range: float = 20.0
@export var attack_damage: int = 20
@export var attack_cooldown: float = 2.0

var current_state: BoarState = BoarState.SPAWN
var player_node: Node3D = null
var camera_node: Camera3D = null

var attack_timer: float = 0.0
var can_attack: bool = true

# Untuk animasi sederhana - gunakan @onready dengan ? operator
@onready var mesh_instance: MeshInstance3D = get_node_or_null("Babi_Hutan")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

func _ready():
	add_to_group("wild_boar")
	add_to_group("enemy")
	setup_collision_config()
	
	# Cari mesh instance secara manual jika path langsung tidak berfungsi
	if not mesh_instance:
		mesh_instance = find_child("*", true, false) as MeshInstance3D
	
	# Cari AnimationPlayer secara manual
	if not animation_player:
		animation_player = find_child("AnimationPlayer", true, false)
	
	transition_to_state(BoarState.SPAWN)

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
				play_animation("run")
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
			
		BoarState.IDLE:
			# Jika player masuk range deteksi, kejar
			if distance_to_player <= detection_range and not player_is_dead:
				transition_to_state(BoarState.CHASE)
			else:
				# Idle animation
				velocity.x = 0
				velocity.z = 0
				play_animation("idle")

func perform_attack():
	if not player_node or not is_instance_valid(player_node):
		return
	
	if not can_attack:
		return
	
	# Cek apakah player masih hidup
	if player_node.has_method("is_player_dead") and player_node.is_player_dead():
		transition_to_state(BoarState.IDLE)
		return
	
	# Serang player dengan damage 20 HP
	if player_node.has_method("take_damage"):
		player_node.take_damage(attack_damage)
		print("Babi hutan menyerang player! Damage: %d HP" % attack_damage)
	
	# Play attack animation
	play_animation("attack")
	
	# Attack cooldown
	can_attack = false
	attack_timer = attack_cooldown
	
	# Kembali ke chase state setelah attack
	await get_tree().create_timer(0.5).timeout
	if current_state == BoarState.ATTACK:
		transition_to_state(BoarState.CHASE)

func transition_to_state(new_state: BoarState):
	state_exit(current_state)
	current_state = new_state
	state_enter(new_state)

func state_enter(state: BoarState):
	match state:
		BoarState.SPAWN:
			play_animation("idle")
			
		BoarState.CHASE:
			can_attack = true
			attack_timer = 0.0
			play_animation("run")
			
		BoarState.ATTACK:
			play_animation("attack_prepare")
			
		BoarState.IDLE:
			play_animation("idle")

func state_exit(state: BoarState):
	pass

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

func play_animation(anim_name: String):
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	elif animation_player:
		# Coba cari animasi dengan nama yang mirip
		for anim in animation_player.get_animation_list():
			if anim_name in anim:
				animation_player.play(anim)
				return
		# Fallback ke animasi pertama yang ada
		var animations = animation_player.get_animation_list()
		if animations.size() > 0:
			animation_player.play(animations[0])
	elif mesh_instance:
		# Fallback jika tidak ada animation player
		pass  # Hanya print jika debugging
		# print("Animation '%s' tidak ditemukan" % anim_name)

# Public methods untuk interaksi eksternal
func stun_boar(duration: float = 1.5):
	# Interupsi state saat ini
	can_attack = false
	attack_timer = duration
	play_animation("hurt")
	
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
