extends Control

var arcade_owner: Node = null


func _draw() -> void:
	if is_instance_valid(arcade_owner) and arcade_owner.has_method("_draw_arcade_overlay"):
		arcade_owner.call("_draw_arcade_overlay", self)
