extends Area3D

class_name DeliveryZone

signal fruits_delivered(ripe_count, unripe_count)

func _ready():
	add_to_group("delivery_zone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("set_in_delivery_zone"):
			body.set_in_delivery_zone(true, self)

func _on_body_exited(body):
	if body.is_in_group("player"):
		if body.has_method("set_in_delivery_zone"):
			body.set_in_delivery_zone(false, null)

func deliver_fruits(ripe_count: int, unripe_count: int) -> bool:
	if ripe_count > 0 or unripe_count > 0:
		fruits_delivered.emit(ripe_count, unripe_count)
		return true
	return false
