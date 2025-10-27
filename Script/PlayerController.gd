extends Node3D

@export var player_body: CharacterBody3D
@export var camera_node: Camera3D
@export var egrek_node: Node3D

# Movement constants
const SPEED = 5.5
const JUMP_VELOCITY = 7.0
const GRAVITY = 20.0

# Mouse control constants
const MOUSE_SENSITIVITY = 0.075
const VERTICAL_CLAMP = Vector2(-70.0, 80.0)

# Egrek positioning constants
const EGREK_UP_POSITION = Vector3(0.45, -0.25, -1.4)
const EGREK_UP_ROTATION = Vector3(-45.5, -70, 80)
const EGREK_DOWN_POSITION = Vector3(0.2, -0.4, 1.1)
const EGREK_DOWN_ROTATION = Vector3(-45.5, -90.0, 80)
const TRANSITION_THRESHOLD = 35.0
const ANIMATION_DISABLE_THRESHOLD = 10.0

# Tween untuk animasi smooth
var egrek_tween: Tween

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	update_egrek_position()

func _input(event):
	if event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event.is_action_pressed("ui_cancel"):
		toggle_mouse_mode()

func handle_mouse_motion(event):
	if !player_body or !camera_node:
		return
	
	player_body.rotation_degrees.y -= event.relative.x * MOUSE_SENSITIVITY
	
	camera_node.rotation_degrees.x -= event.relative.y * MOUSE_SENSITIVITY
	camera_node.rotation_degrees.x = clamp(camera_node.rotation_degrees.x, VERTICAL_CLAMP.x, VERTICAL_CLAMP.y)
	
	update_egrek_position()
	update_egrek_animation_status()

func toggle_mouse_mode():
	var current_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if current_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

func update_egrek_position():
	if !egrek_node or !camera_node:
		return
	
	var camera_x_rotation = camera_node.rotation_degrees.x
	var t = clamp(camera_x_rotation / TRANSITION_THRESHOLD, 0.0, 1.0)
	
	var target_position = EGREK_UP_POSITION.lerp(EGREK_DOWN_POSITION, 1.0 - t)
	var target_rotation = EGREK_UP_ROTATION.lerp(EGREK_DOWN_ROTATION, 1.0 - t)
	
	# Stop tween lama jika ada dan masih berjalan
	if egrek_tween and egrek_tween.is_valid():
		egrek_tween.kill()
	
	# Buat tween baru
	egrek_tween = create_tween()
	egrek_tween.set_parallel(true)
	egrek_tween.tween_property(egrek_node, "position", target_position, 0.2)
	egrek_tween.tween_property(egrek_node, "rotation_degrees", target_rotation, 0.2)

func update_egrek_animation_status():
	if !camera_node:
		return
	
	var egrek_animation_enabled = camera_node.rotation_degrees.x > ANIMATION_DISABLE_THRESHOLD
	set_egrek_animation_enabled(egrek_animation_enabled)

func set_egrek_animation_enabled(enabled: bool):
	# Status animasi disimpan sebagai metadata, bukan variabel class
	egrek_node.set_meta("animation_enabled", enabled)

func _physics_process(delta):
	if !player_body:
		return
	
	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = player_body.transform.basis * Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
	
	player_body.velocity.x = direction.x * SPEED	
	player_body.velocity.z = direction.z * SPEED	
	player_body.velocity.y -= GRAVITY * delta
	
	if Input.is_action_just_pressed("jump") and player_body.is_on_floor():
		player_body.velocity.y = JUMP_VELOCITY
	
	player_body.move_and_slide()

func play_egrek_animation():
	if !egrek_node:
		return
	
	# Cek status animasi dari metadata
	var animation_enabled = egrek_node.get_meta("animation_enabled", true)
	if !animation_enabled:
		print("Animasi egrek dinonaktifkan (player melihat ke bawah)")
		return
	
	var fiber_mesh = egrek_node.get_node_or_null("Fiber")
	if fiber_mesh and fiber_mesh is MeshInstance3D:
		var tween = create_tween()
		tween.set_parallel(true)
		
		tween.tween_property(fiber_mesh, "position:z", -0.3, 0.1)
		tween.tween_property(fiber_mesh, "position:z", 0.0, 0.2).set_delay(0.1)
		
		print("Animasi egrek dijalankan")
