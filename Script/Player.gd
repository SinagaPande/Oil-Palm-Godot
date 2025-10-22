extends CharacterBody3D

@onready var player_controller = $PlayerController
@onready var interaction_system = $InteractionSystem

func _ready():
	add_to_group("player")
	
	# Setup references untuk child controllers
	if player_controller:
		player_controller.player_body = self
		player_controller.camera_node = $PlayerController/Camera3D
	if interaction_system:
		interaction_system.camera = $PlayerController/Camera3D
		interaction_system.interaction_label = $InteractionSystem/CanvasLayer/UI_Container/InteractionLabel
