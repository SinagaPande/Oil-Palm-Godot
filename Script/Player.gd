extends CharacterBody3D

@onready var player_controller = $PlayerController
@onready var interaction_system = $InteractionSystem
@onready var camera = $PlayerController/Camera3D
@onready var egrek = $PlayerController/Camera3D/Egrek

func _ready():
	add_to_group("player")
	setup_components()

func setup_components():
	# Setup player controller
	if player_controller:
		player_controller.player_body = self
		player_controller.camera_node = camera
		player_controller.egrek_node = egrek
	
	# Setup interaction system
	if interaction_system:
		interaction_system.camera = camera
		interaction_system.player_controller = player_controller
		
		# Setup interaction label jika ada
		var interaction_label = interaction_system.get_node_or_null("CanvasLayer/UI_Container/InteractionLabel")
		if interaction_label:
			interaction_system.interaction_label = interaction_label
