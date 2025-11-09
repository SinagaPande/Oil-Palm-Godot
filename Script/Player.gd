extends CharacterBody3D

@onready var player_controller = $PlayerController
@onready var interaction_system = $InteractionSystem
@onready var camera = $PlayerController/Camera3D
@onready var egrek = $PlayerController/Camera3D/Egrek

# Tambahkan variabel untuk tracking initialization
var is_fully_initialized: bool = false

# ⚠️ PERBAIKAN: Tambahkan signal untuk memberitahu bahwa player ready
signal player_fully_ready

func _ready():
	add_to_group("player")
	setup_components()
	
	# ⚠️ PERBAIKAN: Tandai player sudah fully ready
	await get_tree().process_frame
	is_fully_initialized = true
	player_fully_ready.emit()  # ⚠️ Kirim signal
	print("Player: Fully initialized and ready")

func setup_components():
	if player_controller:
		player_controller.player_body = self
		player_controller.camera_node = camera
		player_controller.egrek_node = egrek
	
	if interaction_system:
		interaction_system.camera = camera
		interaction_system.player_controller = player_controller
		
		var interaction_label = interaction_system.get_node_or_null("CanvasLayer/UI_Container/InteractionLabel")
		if interaction_label:
			interaction_system.interaction_label = interaction_label

# ⚠️ PERBAIKAN: Ganti nama function untuk hindari bentrok dengan variable
func get_initialization_status() -> bool:
	return is_fully_initialized

# ⚠️ PERBAIKAN: Atau alternatif - gunakan property getter
func is_player_ready() -> bool:
	return is_fully_initialized
