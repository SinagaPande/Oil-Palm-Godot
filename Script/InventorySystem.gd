extends Node

class_name InventorySystem

var ripe_fruit_count: int = 0
var unripe_fruit_count: int = 0

signal inventory_updated(ripe_count, unripe_count)

func _ready():
	add_to_group("inventory_system")

func add_fruit(fruit_type: String):
	if fruit_type == "Masak":
		ripe_fruit_count += 1
	else:
		unripe_fruit_count += 1
	
	inventory_updated.emit(ripe_fruit_count, unripe_fruit_count)

func get_ripe_count() -> int:
	return ripe_fruit_count

func get_unripe_count() -> int:
	return unripe_fruit_count

func reset_inventory():
	ripe_fruit_count = 0
	unripe_fruit_count = 0
	inventory_updated.emit(ripe_fruit_count, unripe_fruit_count)
