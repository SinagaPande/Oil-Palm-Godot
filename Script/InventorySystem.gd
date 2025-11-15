extends Node

class_name InventorySystem

var delivered_ripe_fruits: int = 0
var collected_unripe_fruits: int = 0

signal permanent_inventory_updated(delivered_ripe, collected_unripe)

func _ready():
	add_to_group("inventory_system")

func add_unripe_fruit_direct():
	collected_unripe_fruits += 1
	permanent_inventory_updated.emit(delivered_ripe_fruits, collected_unripe_fruits)

func add_delivered_ripe_fruits(count: int):
	delivered_ripe_fruits += count
	permanent_inventory_updated.emit(delivered_ripe_fruits, collected_unripe_fruits)

func get_delivered_ripe_count() -> int:
	return delivered_ripe_fruits

func get_collected_unripe_count() -> int:
	return collected_unripe_fruits

func reset_inventory():
	delivered_ripe_fruits = 0
	collected_unripe_fruits = 0
	permanent_inventory_updated.emit(delivered_ripe_fruits, collected_unripe_fruits)
