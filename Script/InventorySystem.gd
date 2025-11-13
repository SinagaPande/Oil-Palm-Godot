extends Node

class_name InventorySystem

# POIN PERMANEN (sudah diantar)
var delivered_ripe_fruits: int = 0
var collected_unripe_fruits: int = 0

# SIGNAL untuk UI
signal permanent_inventory_updated(delivered_ripe, collected_unripe)
signal temporary_inventory_updated(carried_ripe, carried_unripe)

func _ready():
	add_to_group("inventory_system")

# ✅ BUAH MENTAH: tambah poin langsung
func add_unripe_fruit_direct():
	collected_unripe_fruits += 1
	permanent_inventory_updated.emit(delivered_ripe_fruits, collected_unripe_fruits)
	print("Buah mentah dikumpulkan: +1 poin (Total: ", collected_unripe_fruits, ")")

# ✅ BUAH MATANG: tambah ke poin permanen setelah diantar
func add_delivered_ripe_fruits(count: int):
	delivered_ripe_fruits += count
	permanent_inventory_updated.emit(delivered_ripe_fruits, collected_unripe_fruits)
	print("Buah matang diantar: +", count, " poin (Total: ", delivered_ripe_fruits, ")")

func get_delivered_ripe_count() -> int:
	return delivered_ripe_fruits

func get_collected_unripe_count() -> int:
	return collected_unripe_fruits

func reset_inventory():
	delivered_ripe_fruits = 0
	collected_unripe_fruits = 0
	permanent_inventory_updated.emit(delivered_ripe_fruits, collected_unripe_fruits)
