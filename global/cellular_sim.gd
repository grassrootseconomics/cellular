extends Node

var _bridge: Node = null
var _last_error := ""
var _using_web_shim := false


func _ready() -> void:
	if not _has_user_arg("--force-web-shim"):
		_try_create_csharp_bridge()
	if not is_instance_valid(_bridge):
		_try_create_web_bridge()


func is_available() -> bool:
	return is_instance_valid(_bridge)


func is_loaded() -> bool:
	if is_instance_valid(_bridge) and _bridge.has_method("is_loaded"):
		return bool(_bridge.call("is_loaded"))
	return false


func get_last_error() -> String:
	if is_instance_valid(_bridge) and _bridge.has_method("get_last_error"):
		return str(_bridge.call("get_last_error"))
	return _last_error


func load_fixture_json(json: String) -> bool:
	if not is_instance_valid(_bridge) or not _bridge.has_method("load_fixture_json"):
		_last_error = "Cellular sim bridge is unavailable."
		return false
	return bool(_bridge.call("load_fixture_json", json))


func load_fixture_file(path: String) -> bool:
	if not is_instance_valid(_bridge) or not _bridge.has_method("load_fixture_file"):
		_last_error = "Cellular sim bridge does not expose load_fixture_file."
		return false
	return bool(_bridge.call("load_fixture_file", path))


func can_move_cell(cell_id: String, x: int, y: int) -> bool:
	if not is_instance_valid(_bridge) or not _bridge.has_method("can_move_cell"):
		return false
	return bool(_bridge.call("can_move_cell", cell_id, x, y))


func move_cell(cell_id: String, x: int, y: int) -> bool:
	if not is_instance_valid(_bridge) or not _bridge.has_method("move_cell"):
		return false
	return bool(_bridge.call("move_cell", cell_id, x, y))


func reset_with_current_layout() -> bool:
	if not is_instance_valid(_bridge) or not _bridge.has_method("reset_with_current_layout"):
		_last_error = "Cellular sim bridge does not expose reset_with_current_layout."
		return false
	return bool(_bridge.call("reset_with_current_layout"))


func add_myco_cell(kind: String, id: String, x: int, y: int, needs: Array) -> bool:
	if not is_instance_valid(_bridge) or not _bridge.has_method("add_myco_cell"):
		_last_error = "Cellular sim bridge does not expose add_myco_cell."
		return false
	return bool(_bridge.call("add_myco_cell", kind, id, x, y, needs))


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
		"lastError": "Cellular sim bridge returned an invalid snapshot."
	}


func _try_create_csharp_bridge() -> void:
	_using_web_shim = false
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


func _try_create_web_bridge() -> void:
	var bridge_path := "res://global/cellular_sim_web.gd"
	if not ResourceLoader.exists(bridge_path):
		_last_error = "Cellular GDScript web sim shim is unavailable."
		return
	var bridge_script: Resource = load(bridge_path)
	if bridge_script == null or not bridge_script is Script:
		_last_error = "Cellular GDScript web sim shim could not be loaded."
		return
	var script: Script = bridge_script as Script
	if not script.can_instantiate():
		_last_error = "Cellular GDScript web sim shim could not be instantiated. Check script parse errors."
		return
	var instance: Variant = script.new()
	if not instance is Node:
		_last_error = "Cellular GDScript web sim shim could not be instantiated."
		return
	_bridge = instance
	_bridge.name = "CellularSimWebShim"
	_using_web_shim = true
	add_child(_bridge)
	_last_error = ""


func _has_user_arg(name: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if str(arg) == name:
			return true
	return false
