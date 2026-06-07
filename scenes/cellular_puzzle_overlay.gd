extends Control

var puzzle_owner: Node = null


func _draw() -> void:
	if is_instance_valid(puzzle_owner) and puzzle_owner.has_method("_draw_puzzle_overlay"):
		puzzle_owner.call("_draw_puzzle_overlay", self)
