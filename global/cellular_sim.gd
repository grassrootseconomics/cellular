extends Node

var _bridge: Node = null
var _last_error := ""


func _ready() -> void:
	_try_create_csharp_bridge()


func is_available() -> bool:
	return is_instance_valid(_bridge)


func get_last_error() -> String:
	if is_instance_valid(_bridge) and _bridge.has_method("get_last_error"):
		return str(_bridge.call("get_last_error"))
	return _last_error


func load_fixture_json(json: String) -> bool:
	if not is_instance_valid(_bridge) or not _bridge.has_method("load_fixture_json"):
		_last_error = "Cellular C# bridge is unavailable. Use the Godot .NET editor/runtime."
		return false
	return bool(_bridge.call("load_fixture_json", json))


func move_cell(cell_id: String, x: int, y: int) -> bool:
	if not is_instance_valid(_bridge) or not _bridge.has_method("move_cell"):
		return false
	return bool(_bridge.call("move_cell", cell_id, x, y))


func reset_with_current_layout() -> bool:
	if not is_instance_valid(_bridge) or not _bridge.has_method("reset_with_current_layout"):
		_last_error = "Cellular C# bridge does not expose reset_with_current_layout. Build Cellular.csproj and restart Godot."
		return false
	return bool(_bridge.call("reset_with_current_layout"))


func tick_many(count: int) -> void:
	if is_instance_valid(_bridge) and _bridge.has_method("tick_many"):
		_bridge.call("tick_many", count)


func get_snapshot() -> Dictionary:
	if not is_instance_valid(_bridge) or not _bridge.has_method("get_snapshot"):
		return {
			"loaded": false,
			"lastError": get_last_error()
		}
	var snapshot: Variant = _bridge.call("get_snapshot")
	if snapshot is Dictionary:
		return snapshot
	return {
		"loaded": false,
		"lastError": "Cellular C# bridge returned an invalid snapshot."
	}


func _try_create_csharp_bridge() -> void:
	var bridge_path := "res://src/CellularSimBridge.cs"
	if not ResourceLoader.exists(bridge_path):
		_last_error = "CellularSimBridge script is unavailable. Use the Godot .NET build and build Cellular.csproj."
		return
	var bridge_script: Resource = load(bridge_path)
	if bridge_script == null or not bridge_script is Script:
		_last_error = "CellularSimBridge script could not be loaded. Use the Godot .NET build and build Cellular.csproj."
		return
	var instance: Variant = (bridge_script as Script).new()
	if not instance is Node:
		_last_error = "CellularSimBridge could not be instantiated."
		return
	_bridge = instance
	_bridge.name = "CellularSimBridge"
	add_child(_bridge)
