extends Node3D

@export var player_body: CharacterBody3D
@export var camera_node: Camera3D

# Movement settings
const SPEED = 5.5
const JUMP_VELOCITY = 10.0
const GRAVITY = 20.0

# Camera settings
var mouse_sensitivity = 10
var vertical_clamp = Vector2(-70.0, 80.0)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Camera look
	if event is InputEventMouseMotion:
		# Rotasi horizontal (pemain)
		player_body.rotation_degrees.y -= event.relative.x * mouse_sensitivity * 0.01
		
		# Rotasi vertikal (kamera)
		if camera_node:
			camera_node.rotation_degrees.x -= event.relative.y * mouse_sensitivity * 0.01
			camera_node.rotation_degrees.x = clamp(camera_node.rotation_degrees.x, vertical_clamp.x, vertical_clamp.y)
	
	# Toggle mouse capture
	elif event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if !player_body:
		return
	
	# Movement
	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_direction_3D = Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
	var direction = player_body.transform.basis * input_direction_3D
	
	player_body.velocity.x = direction.x * SPEED	
	player_body.velocity.z = direction.z * SPEED	
	player_body.velocity.y -= GRAVITY * delta
	
	if Input.is_action_just_pressed("jump") and player_body.is_on_floor():
		player_body.velocity.y = JUMP_VELOCITY
	
	player_body.move_and_slide()
