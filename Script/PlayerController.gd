extends Node3D

class_name PlayerController

@export var player_body: CharacterBody3D
@export var camera_node: Camera3D
@export var egrek_node: Node3D
@export var tojok_node: Node3D

# ✅ Enum untuk jenis alat
enum Tool { EGREK, TOJOK }
var current_tool: Tool = Tool.EGREK

var current_speed = 5.5
const JUMP_VELOCITY = 7.0
const GRAVITY = 20.0

const MOUSE_SENSITIVITY = 0.075
const VERTICAL_CLAMP = Vector2(-70.0, 80.0)

const EGREK_UP_POSITION = Vector3(0.45, -0.25, -1.4)
const EGREK_UP_ROTATION = Vector3(-45.5, -70, 80)
const EGREK_DOWN_POSITION = Vector3(0.2, -0.4, 1.1)
const EGREK_DOWN_ROTATION = Vector3(-45.5, -90.0, 80)

# ✅ TOJOK HANYA MEMILIKI SATU POSISI TETAP
const TOJOK_DEFAULT_POSITION = Vector3(0.215, -0.15, -0.735)
const TOJOK_DEFAULT_ROTATION = Vector3(51.5, 90.0, 82.0)
const TOJOK_SHOOT_POSITION = Vector3(0.18, -0.15, -0.9)
const TOJOK_SHOOT_ROTATION = Vector3(51.5, 90.0, 82.0)

const TRANSITION_THRESHOLD = 35.0
const ANIMATION_DISABLE_THRESHOLD = 10.0

var egrek_tween: Tween
var tojok_tween: Tween
var tojok_shoot_tween: Tween  # ✅ Tween khusus untuk animasi shoot Tojok

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	switch_tool(Tool.EGREK)
	update_tool_position()
	
	if player_body and player_body.has_method("get_base_speed"):
		current_speed = player_body.get_base_speed()
	else:
		current_speed = 5.5

func set_current_speed(new_speed: float):
	current_speed = new_speed

func switch_tool(new_tool: Tool):
	if current_tool == new_tool:
		return
	
	# Sembunyikan alat sebelumnya
	match current_tool:
		Tool.EGREK:
			if egrek_node:
				egrek_node.visible = false
		Tool.TOJOK:
			if tojok_node:
				tojok_node.visible = false
	
	current_tool = new_tool
	
	# Tampilkan alat baru
	match current_tool:
		Tool.EGREK:
			if egrek_node:
				egrek_node.visible = true
		Tool.TOJOK:
			if tojok_node:
				tojok_node.visible = true
	
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
			# ✅ TOJOK TETAP DI POSISI DEFAULT TANPA PERUBAHAN BERDASARKAN SUDUT KAMERA
			if tojok_node:
				# Set posisi tetap untuk Tojok
				if tojok_tween and tojok_tween.is_valid():
					tojok_tween.kill()
				
				tojok_tween = create_tween()
				tojok_tween.set_parallel(true)
				tojok_tween.tween_property(tojok_node, "position", TOJOK_DEFAULT_POSITION, 0.2)
				tojok_tween.tween_property(tojok_node, "rotation_degrees", TOJOK_DEFAULT_ROTATION, 0.2)
	
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
				# ✅ TOJOK SELALU BISA ANIMASI TANPA BATASAN SUDUT KAMERA
				tojok_node.set_meta("animation_enabled", true)

func _input(event):
	if event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event.is_action_pressed("ui_cancel"):
		toggle_mouse_mode()
	elif event.is_action_pressed("tool_1"):
		switch_tool(Tool.EGREK)
	elif event.is_action_pressed("tool_2"):
		switch_tool(Tool.TOJOK)

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

func _physics_process(delta):
	if !player_body:
		return
	
	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = player_body.transform.basis * Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
	
	player_body.velocity.x = direction.x * current_speed
	player_body.velocity.z = direction.z * current_speed
	player_body.velocity.y -= GRAVITY * delta
	
	if Input.is_action_just_pressed("jump") and player_body.is_on_floor():
		player_body.velocity.y = JUMP_VELOCITY
	
	player_body.move_and_slide()

# ✅ FUNGSI ANIMASI BERDASARKAN ALAT AKTIF
func play_tool_animation():
	match current_tool:
		Tool.EGREK:
			play_egrek_animation()
		Tool.TOJOK:
			play_tojok_animation()

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
	
	# ✅ TOJOK SELALU BISA BERANIMASI TANPA KONDISI APAPUN
	# ANIMASI SHOOT TOJOK
	if tojok_shoot_tween and tojok_shoot_tween.is_valid():
		tojok_shoot_tween.kill()
	
	tojok_shoot_tween = create_tween()
	tojok_shoot_tween.set_parallel(true)
	
	# Animasi: Bergerak ke posisi shoot
	tojok_shoot_tween.tween_property(tojok_node, "position", TOJOK_SHOOT_POSITION, 0.1)
	tojok_shoot_tween.tween_property(tojok_node, "rotation_degrees", TOJOK_SHOOT_ROTATION, 0.1)
	
	# Animasi: Kembali ke posisi default
	tojok_shoot_tween.tween_property(tojok_node, "position", TOJOK_DEFAULT_POSITION, 0.2).set_delay(0.1)
	tojok_shoot_tween.tween_property(tojok_node, "rotation_degrees", TOJOK_DEFAULT_ROTATION, 0.2).set_delay(0.1)

func get_current_tool() -> Tool:
	return current_tool

func is_egrek_active() -> bool:
	return current_tool == Tool.EGREK

func is_tojok_active() -> bool:
	return current_tool == Tool.TOJOK
