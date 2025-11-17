extends CharacterBody3D
class_name HarvesterNPC

enum NPCState {
	SPAWN,
	CHASE,
	ATTACK,
	IDLE
}

@export var move_speed: float = 4.0
@export var attack_range: float = 2.5
@export var detection_range: float = 100.0  # Jarak deteksi lebih jauh agar selalu mengejar
@export var attack_damage: int = 10  # Damage per serangan = 10 HP
@export var attack_cooldown: float = 1.5

var current_state: NPCState = NPCState.SPAWN
var player_node: Node3D = null
var camera_node: Camera3D = null

var attack_timer: float = 0.0
var can_attack: bool = true

# Collision configuration
var collision_shape: CollisionShape3D = null

func _ready():
	add_to_group("harvester_npc")
	setup_collision_config()
	transition_to_state(NPCState.SPAWN)

func setup_collision_config():
	# Cari CollisionShape3D dan atur untuk bisa menembus object
	collision_shape = find_child("CollisionShape3D")
	if collision_shape:
		# Set collision mask untuk menghindari tabrakan dengan object static
		collision_mask = 0x00000001  # Hanya layer 1 (ground biasanya)
		# Non-aktifkan collision dengan object lain
		set_collision_layer_value(2, false)  # Player
		set_collision_layer_value(3, false)  # NPC lain  
		set_collision_layer_value(4, false)  # Object static
		set_collision_layer_value(5, false)  # Buah
		
		# Atur collision shape menjadi trigger-only
		if collision_shape.shape is CapsuleShape3D or collision_shape.shape is SphereShape3D:
			collision_shape.shape.radius *= 0.8  # Sedikit perkecil untuk memudahkan navigasi

func _physics_process(delta):
	state_process(delta)
	
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

func state_process(delta):
	if not player_node or not is_instance_valid(player_node):
		find_player_and_camera()
		if not player_node:
			return
	
	# Check if player is dead
	var player_is_dead = false
	if player_node.has_method("is_player_dead"):
		player_is_dead = player_node.is_player_dead()
	
	if player_is_dead:
		transition_to_state(NPCState.IDLE)
		return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	match current_state:
		NPCState.SPAWN:
			initialize_npc()
			
		NPCState.CHASE:
			if distance_to_player <= attack_range:
				transition_to_state(NPCState.ATTACK)
			else:
				# Selalu mengejar player selama player masih hidup
				move_towards_target(player_node.global_position)
			
		NPCState.ATTACK:
			if distance_to_player > attack_range * 1.5:
				transition_to_state(NPCState.CHASE)
			elif can_attack:
				perform_attack()
			else:
				# Keep looking at player while in attack range
				var direction = (player_node.global_position - global_position).normalized()
				direction.y = 0
				if direction.length() > 0.1:
					look_at(global_position + direction, Vector3.UP)
			
		NPCState.IDLE:
			# Jika player masih hidup, langsung kejar
			if not player_is_dead:
				transition_to_state(NPCState.CHASE)

func perform_attack():
	if not player_node or not is_instance_valid(player_node):
		return
	
	if not can_attack:
		return
	
	# Cek apakah player masih hidup
	if player_node.has_method("is_player_dead") and player_node.is_player_dead():
		transition_to_state(NPCState.IDLE)
		return
	
	# Serang player dengan damage 10 HP
	if player_node.has_method("take_damage"):
		player_node.take_damage(attack_damage)
		var current_hp = 0
		if player_node.has_method("get_hp"):
			current_hp = player_node.get_hp()
		print("NPC menyerang player! HP player sekarang: %d / %d" % [current_hp, player_node.get_max_hp() if player_node.has_method("get_max_hp") else 100])
	
	can_attack = false
	attack_timer = attack_cooldown

func transition_to_state(new_state: NPCState):
	state_exit(current_state)
	current_state = new_state
	state_enter(new_state)

func state_enter(state: NPCState):
	match state:
		NPCState.SPAWN:
			pass
			
		NPCState.CHASE:
			pass
			
		NPCState.ATTACK:
			can_attack = true
			attack_timer = 0.0
			
		NPCState.IDLE:
			pass

func state_exit(state: NPCState):
	pass


func move_towards_target(target_position: Vector3):
	var direction = (target_position - global_position).normalized()
	direction.y = 0
	
	velocity = direction * move_speed
	velocity.y = -9.8
	
	# Simplified movement tanpa obstacle avoidance yang kompleks
	# karena collision sudah diatur untuk menembus object
	
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
	
	move_and_slide()

func initialize_npc():
	find_player_and_camera()
	if player_node:
		# Langsung mulai mengejar player
		transition_to_state(NPCState.CHASE)
	else:
		# Jika player belum ditemukan, tunggu sebentar lalu coba lagi
		await get_tree().create_timer(0.5).timeout
		find_player_and_camera()
		if player_node:
			transition_to_state(NPCState.CHASE)
		else:
			transition_to_state(NPCState.IDLE)

func find_player_and_camera():
	if not is_inside_tree():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
		if player_node.has_node("PlayerController/Camera3D"):
			camera_node = player_node.get_node("PlayerController/Camera3D")
		else:
			camera_node = find_camera_recursive(player_node)

func find_camera_recursive(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var found = find_camera_recursive(child)
		if found:
			return found
	return null
