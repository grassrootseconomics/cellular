extends Control

const BOARD_SIZE := 8
const RESOURCE_LETTERS := [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
	"M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X"
]
const RESOURCE_COLORS := [
	Color(0.18, 0.72, 0.78, 1.0),
	Color(0.93, 0.42, 0.25, 1.0),
	Color(0.50, 0.78, 0.30, 1.0),
	Color(0.78, 0.46, 0.92, 1.0),
	Color(0.95, 0.74, 0.24, 1.0),
	Color(0.36, 0.52, 0.95, 1.0),
	Color(0.92, 0.30, 0.50, 1.0),
	Color(0.24, 0.80, 0.56, 1.0)
]
const SIM_TICK_SECONDS := 0.12
const SWAP_VISUAL_TTL_TICKS := 10.0
const REACTION_VISUAL_TTL_TICKS := 10.0
const PIP_ANGLE_SMOOTH := 0.10
const PIP_OFFSET_SMOOTH := 0.12
const NEED_STATE_MISSING := "missing"
const NEED_STATE_AVAILABLE := "available"
const NEED_STATE_ACTIVE := "active"
const NEED_STATE_SATISFIED := "satisfied"
const MARK_MODE_LETTERS := 0
const MARK_MODE_SYMBOLS := 1
const MARK_MODE_HIDDEN := 2
const RESOURCE_SYMBOL_MARKS := [
	"+", "*", "#", "@", "$", "%", "&", "!",
	"?", "=", "~", "^", "<", ">", "/", "\\",
	":", ";", "|", "_", "x", "o", "[", "]"
]
const CIRCUIT_GROUP_COLORS := [
	Color(0.30, 1.00, 0.84, 1.0),
	Color(1.00, 0.76, 0.26, 1.0),
	Color(0.68, 0.46, 1.00, 1.0),
	Color(0.28, 0.70, 1.00, 1.0),
	Color(1.00, 0.36, 0.58, 1.0),
	Color(0.58, 1.00, 0.34, 1.0),
	Color(1.00, 0.46, 0.24, 1.0),
	Color(0.45, 0.62, 1.00, 1.0)
]

var _level_number := 1
var _cells: Array[String] = []
var _needs := {}
var _positions := {}
var _produced_by_cell := {}
var _original_drag_tile := Vector2i.ZERO
var _drag_cell := ""
var _drag_offset := Vector2.ZERO
var _drag_position := Vector2.ZERO
var _board_rect := Rect2()
var _tile_size := 64.0
var _board_cols := BOARD_SIZE
var _board_rows := BOARD_SIZE
var _solved := false
var _back_button: Button = null
var _reset_button: Button = null
var _hint_button: Button = null
var _circuit_button: Button = null
var _last_button: Button = null
var _next_button: Button = null
var _level_label: Label = null
var _status_label: Label = null
var _flow_label: Label = null
var _sim_bridge: Node = null
var _board_renderer: Node = null
var _sim_snapshot: Dictionary = {}
var _cell_state_by_id: Dictionary = {}
var _sim_tick_accum := 0.0
var _using_csharp_sim := false
var _using_board_renderer := false
var _board_renderer_full_sync_needed := true
var _board_renderer_has_state := false
var _sim_status_message := ""
var _hint_pair: Array[String] = []
var _hint_cursor := 0
var _hint_text := ""
var _solution_positions: Dictionary = {}
var _resource_mark_mode := MARK_MODE_LETTERS
var _circuit_overlay_enabled := true
var _pip_angle_by_key: Dictionary = {}
var _pip_offset_by_key: Dictionary = {}
var _display_fullness_by_key: Dictionary = {}
var _last_draw_msec := 0
var _frame_blend := 1.0


func _ready() -> void:
	Global.reset_gameplay_speed()
	Global.mode = "puzzle"
	_sim_bridge = get_node_or_null("/root/CellularSim")
	_create_hud()
	_try_create_board_renderer()
	_load_level(maxi(1, Global.cellular_puzzle_current_level))
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _using_csharp_sim or _drag_cell != "":
		return
	_sim_tick_accum += maxf(delta, 0.0)
	var ticked := false
	while _sim_tick_accum >= SIM_TICK_SECONDS:
		_sim_tick_accum -= SIM_TICK_SECONDS
		if is_instance_valid(_sim_bridge):
			_sim_bridge.call("tick_many", 1)
			ticked = true
	if ticked:
		_refresh_sim_snapshot()
		_check_solution()
		queue_redraw()
	elif _has_live_visual_animation():
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_pip_angle_by_key.clear()
		_pip_offset_by_key.clear()
		_board_renderer_full_sync_needed = true
		_layout_hud()
		queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_L:
			_resource_mark_mode = (_resource_mark_mode + 1) % 3
			_board_renderer_full_sync_needed = true
			queue_redraw()
		elif key_event.keycode == KEY_C:
			_toggle_circuit_overlay()
		elif key_event.keycode == KEY_H:
			_on_hint_pressed()


func _create_hud() -> void:
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "Menu"
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)

	_reset_button = Button.new()
	_reset_button.name = "ResetLevelButton"
	_reset_button.text = "Reset"
	_reset_button.pressed.connect(_on_reset_pressed)
	add_child(_reset_button)

	_hint_button = Button.new()
	_hint_button.name = "HintButton"
	_hint_button.text = "Hint"
	_hint_button.pressed.connect(_on_hint_pressed)
	add_child(_hint_button)

	_circuit_button = Button.new()
	_circuit_button.name = "CircuitButton"
	_circuit_button.text = "Circuit"
	_circuit_button.pressed.connect(_toggle_circuit_overlay)
	add_child(_circuit_button)

	_last_button = Button.new()
	_last_button.name = "LastLevelButton"
	_last_button.text = "Last Level"
	_last_button.pressed.connect(_on_last_pressed)
	add_child(_last_button)

	_next_button = Button.new()
	_next_button.name = "NextLevelButton"
	_next_button.text = "Next Level"
	_next_button.visible = true
	_next_button.pressed.connect(_on_next_pressed)
	add_child(_next_button)

	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_level_label)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_status_label)

	_flow_label = Label.new()
	_flow_label.name = "FlowLabel"
	_flow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_flow_label)
	_layout_hud()


func _style_label(label: Label, font_size: int, color: Color) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.03, 0.035, 0.95))
	label.add_theme_constant_override("outline_size", 3)


func _style_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.custom_minimum_size = Vector2(116, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)


func _layout_hud() -> void:
	var view_size := get_viewport_rect().size
	var margin := 18.0
	_style_button(_back_button)
	_style_button(_reset_button)
	_style_button(_hint_button)
	_style_button(_circuit_button)
	_style_button(_last_button)
	_style_button(_next_button)
	if is_instance_valid(_back_button):
		_back_button.position = Vector2(margin, margin)
		_back_button.size = Vector2(116, 44)
	if is_instance_valid(_hint_button):
		_hint_button.position = Vector2(margin, margin + 52.0)
		_hint_button.size = Vector2(116, 44)
	if is_instance_valid(_circuit_button):
		_circuit_button.position = Vector2(margin, view_size.y - 58.0)
		_circuit_button.size = Vector2(116, 40)
		_circuit_button.text = "Circuit" if _circuit_overlay_enabled else "Circuit Off"
	if is_instance_valid(_reset_button):
		_reset_button.position = Vector2(view_size.x - 116.0 - margin, margin)
		_reset_button.size = Vector2(116, 44)
	if is_instance_valid(_last_button):
		_last_button.custom_minimum_size = Vector2(142, 44)
		_last_button.position = Vector2(view_size.x - 142.0 - margin, margin + 52.0)
		_last_button.size = Vector2(142, 44)
		_last_button.disabled = _level_number <= 1
	if is_instance_valid(_next_button):
		_next_button.custom_minimum_size = Vector2(142, 44)
		_next_button.position = Vector2(view_size.x - 142.0 - margin, margin + 104.0)
		_next_button.size = Vector2(142, 44)
		_next_button.visible = true
	if is_instance_valid(_level_label):
		_level_label.position = Vector2(144, 14)
		_level_label.size = Vector2(maxf(1.0, view_size.x - 288.0), 54)
		_style_label(_level_label, 34, Color(0.92, 1.0, 0.96, 1.0))
	if is_instance_valid(_status_label):
		_status_label.position = Vector2(margin, 74)
		_status_label.size = Vector2(maxf(1.0, view_size.x - margin * 2.0), 34)
		_style_label(_status_label, 22, Color(0.74, 0.92, 0.90, 1.0))
	if is_instance_valid(_flow_label):
		_flow_label.position = Vector2(margin, view_size.y - 56.0)
		_flow_label.size = Vector2(maxf(1.0, view_size.x - margin * 2.0), 36)
		_style_label(_flow_label, 21, Color(1.0, 0.86, 0.36, 1.0))
	if is_instance_valid(_board_renderer) and _board_renderer is Control:
		var renderer := _board_renderer as Control
		renderer.position = Vector2.ZERO
		renderer.size = view_size


func _try_create_board_renderer() -> void:
	var renderer_path := "res://src/CellularBoardRenderer.cs"
	if not ResourceLoader.exists(renderer_path):
		return
	var renderer_script: Resource = load(renderer_path)
	if renderer_script == null or not renderer_script is Script:
		return
	var instance: Variant = (renderer_script as Script).new()
	if not instance is Control:
		return
	_board_renderer = instance as Control
	_board_renderer.name = "CellularBoardRenderer"
	(_board_renderer as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_renderer)
	move_child(_board_renderer, 0)
	_using_board_renderer = true
	_board_renderer_full_sync_needed = true
	_board_renderer_has_state = false


func _load_level(level_number: int) -> void:
	_level_number = level_number
	_cells.clear()
	_needs.clear()
	_positions.clear()
	_produced_by_cell.clear()
	_solution_positions.clear()
	_sim_snapshot.clear()
	_cell_state_by_id.clear()
	_sim_tick_accum = 0.0
	_using_csharp_sim = false
	_board_renderer_full_sync_needed = true
	_board_renderer_has_state = false
	_sim_status_message = ""
	_hint_pair.clear()
	_hint_cursor = 0
	_hint_text = ""
	_pip_angle_by_key.clear()
	_pip_offset_by_key.clear()
	_board_cols = BOARD_SIZE
	_board_rows = BOARD_SIZE
	_solved = false
	var cell_count := mini(RESOURCE_LETTERS.size(), _level_number + 3)
	for index in range(cell_count):
		var resource := str(RESOURCE_LETTERS[index])
		_cells.append(resource)
		_produced_by_cell[resource] = resource
	for index in range(_cells.size()):
		var resource := _cells[index]
		var needed: Array[String] = []
		var offsets: Array[int] = [-1, 1, 2]
		for offset in offsets:
			var candidate := _cells[(index + offset + _cells.size()) % _cells.size()]
			if candidate != resource and not needed.has(candidate):
				needed.append(candidate)
		_needs[resource] = needed
	var starts := _make_start_positions(_cells.size())
	for index in range(_cells.size()):
		_positions[_cells[index]] = starts[index]
	_try_load_csharp_level()
	_load_solution_layout_for_level()
	_update_level_text()


func _try_load_csharp_level() -> void:
	if not is_instance_valid(_sim_bridge):
		return
	var fixture_json := _load_fixture_json_for_level()
	if not fixture_json.is_empty():
		_apply_fixture_document_to_visual_model(fixture_json)
	if fixture_json.is_empty():
		fixture_json = JSON.stringify(_build_current_fixture_document())
	var loaded_value: Variant = _sim_bridge.call("load_fixture_json", fixture_json)
	_using_csharp_sim = bool(loaded_value)
	if not _using_csharp_sim:
		var error_value: Variant = _sim_bridge.call("get_last_error")
		_sim_status_message = str(error_value)
		if not _sim_status_message.contains("unavailable") and not _sim_status_message.contains("not registered"):
			push_warning("Cellular C# sim bridge failed to load level fixture: %s" % _sim_status_message)
		return
	_sim_status_message = "C# sim active"
	_refresh_sim_snapshot()


func _load_fixture_json_for_level() -> String:
	var level_path := "res://levels/puzzle/level-%03d.json" % _level_number
	if FileAccess.file_exists(level_path):
		var file := FileAccess.open(level_path, FileAccess.READ)
		if file != null:
			return file.get_as_text()
	var generated_path := "res://sim/generated/level-%03d/starting-fixture.json" % _level_number
	if FileAccess.file_exists(generated_path):
		var file := FileAccess.open(generated_path, FileAccess.READ)
		if file != null:
			return file.get_as_text()
	return ""


func _load_solution_layout_for_level() -> void:
	_solution_positions.clear()
	var level_path := "res://levels/puzzle/level-%03d-definition.json" % _level_number
	if not FileAccess.file_exists(level_path):
		return
	var file := FileAccess.open(level_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var document: Dictionary = parsed as Dictionary
	var layout_value: Variant = document.get("solutionLayout", {})
	if not layout_value is Dictionary:
		return
	var layout: Dictionary = layout_value as Dictionary
	var cells_value: Variant = layout.get("cells", [])
	if not cells_value is Array:
		return
	var cells: Array = cells_value as Array
	for cell_value in cells:
		if not cell_value is Dictionary:
			continue
		var cell_doc := cell_value as Dictionary
		var cell_id := str(cell_doc.get("cellId", ""))
		if cell_id.is_empty():
			continue
		_solution_positions[cell_id] = Vector2i(int(cell_doc.get("x", 0)), int(cell_doc.get("y", 0)))


func _apply_fixture_document_to_visual_model(fixture_json: String) -> void:
	var parsed: Variant = JSON.parse_string(fixture_json)
	if not parsed is Dictionary:
		return
	var fixture: Dictionary = parsed
	var grid_value: Variant = fixture.get("grid", {})
	if grid_value is Dictionary:
		var grid := grid_value as Dictionary
		_board_cols = maxi(1, int(grid.get("width", BOARD_SIZE)))
		_board_rows = maxi(1, int(grid.get("height", BOARD_SIZE)))
	var cells_value: Variant = fixture.get("cells", [])
	if not cells_value is Array:
		return
	_cells.clear()
	_needs.clear()
	_positions.clear()
	_produced_by_cell.clear()
	for cell_value in cells_value:
		if not cell_value is Dictionary:
			continue
		var cell_doc := cell_value as Dictionary
		var id := str(cell_doc.get("id", ""))
		if id.is_empty():
			continue
		_cells.append(id)
		_positions[id] = Vector2i(int(cell_doc.get("x", 0)), int(cell_doc.get("y", 0)))
		var needs: Array[String] = []
		var slots_value: Variant = cell_doc.get("slots", [])
		if slots_value is Array:
			for slot_value in slots_value:
				if not slot_value is Dictionary:
					continue
				var slot_doc := slot_value as Dictionary
				var resource := str(slot_doc.get("resource", ""))
				var role := str(slot_doc.get("role", ""))
				if role == "SourceOutput":
					_produced_by_cell[id] = resource
				elif role == "Need":
					needs.append(resource)
		if not _produced_by_cell.has(id):
			_produced_by_cell[id] = id
		_needs[id] = needs


func _build_current_fixture_document() -> Dictionary:
	var cell_docs: Array = []
	for cell in _cells:
		var tile := _get_cell_tile(cell)
		var slots: Array = [
			{"resource": cell, "role": "SourceOutput", "quantity": 0, "capacity": 100}
		]
		var needed: Array = _needs.get(cell, [])
		for need in needed:
			slots.append({"resource": str(need), "role": "Need", "quantity": 0, "capacity": 100})
		cell_docs.append({
			"id": cell,
			"x": tile.x,
			"y": tile.y,
			"slots": slots,
			"sources": [
				{"resource": cell, "quantityPerTick": 12, "intervalTicks": 1}
			]
		})
	return {
		"resources": _cells.duplicate(),
		"grid": {"width": _board_cols, "height": _board_rows, "rocks": []},
		"cells": cell_docs,
		"engine": {
			"glowTtlTicks": 200,
			"winRecentFlowWindowTicks": 200,
			"swapRoundsPerTick": 4,
			"needDesiredQuantity": 16,
			"needOfferReserve": 4,
			"allowNeedOverflowPayments": true
		},
		"win": {
			"requiredCells": _cells.duplicate(),
			"requiredResources": _cells.duplicate(),
			"durationTicks": 3
		}
	}


func _refresh_sim_snapshot() -> void:
	if not is_instance_valid(_sim_bridge):
		return
	var snapshot_value: Variant = _sim_bridge.call("get_snapshot")
	if not snapshot_value is Dictionary:
		return
	_sim_snapshot = snapshot_value
	_board_cols = maxi(1, int(_sim_snapshot.get("width", _board_cols)))
	_board_rows = maxi(1, int(_sim_snapshot.get("height", _board_rows)))
	_cell_state_by_id.clear()
	_positions.clear()
	var cells_value: Variant = _sim_snapshot.get("cells", [])
	if cells_value is Array:
		for cell_value in cells_value:
			if not cell_value is Dictionary:
				continue
			var cell_data := cell_value as Dictionary
			var id := str(cell_data.get("id", ""))
			if id.is_empty():
				continue
			_cell_state_by_id[id] = cell_data
			_positions[id] = Vector2i(int(cell_data.get("x", 0)), int(cell_data.get("y", 0)))
			var produced := str(cell_data.get("producedResource", ""))
			if not produced.is_empty():
				_produced_by_cell[id] = produced
	_solved = bool(_sim_snapshot.get("won", false))
	_board_renderer_full_sync_needed = true


func _make_start_positions(count: int) -> Array[Vector2i]:
	var starts: Array[Vector2i] = []
	var mid_col := int(floor(float(_board_cols) / 2.0))
	var mid_row := int(floor(float(_board_rows) / 2.0))
	var anchors: Array[Vector2i] = [
		Vector2i(1, 1),
		Vector2i(_board_cols - 2, 1),
		Vector2i(1, _board_rows - 2),
		Vector2i(_board_cols - 2, _board_rows - 2),
		Vector2i(mid_col, 1),
		Vector2i(mid_col, _board_rows - 2),
		Vector2i(1, mid_row),
		Vector2i(_board_cols - 2, mid_row)
	]
	for tile in anchors:
		_append_start_tile_if_unique(starts, tile)
		if starts.size() >= count:
			return starts

	for parity in [0, 1]:
		for y in range(_board_rows):
			for x in range(_board_cols):
				if (x + y) % 2 != parity:
					continue
				_append_start_tile_if_unique(starts, Vector2i(x, y))
				if starts.size() >= count:
					return starts
	return starts


func _append_start_tile_if_unique(starts: Array[Vector2i], tile: Vector2i) -> void:
	if tile.x < 0 or tile.y < 0 or tile.x >= _board_cols or tile.y >= _board_rows:
		return
	if starts.has(tile):
		return
	starts.append(tile)


func _update_level_text() -> void:
	if is_instance_valid(_level_label):
		_level_label.text = str("Level ", _level_number)
	if is_instance_valid(_status_label):
		if _solved:
			if _circuit_alive_now():
				_status_label.text = "Circuit complete"
			else:
				_status_label.text = "Circuit complete - flow broke apart"
		elif not _hint_text.is_empty():
			_status_label.text = _hint_text
		elif _using_csharp_sim:
			_status_label.text = "C# sim active"
		elif not _sim_status_message.is_empty():
			_status_label.text = "Prototype fallback: C# sim unavailable"
		else:
			_status_label.text = "Form one connected circuit"
	if is_instance_valid(_last_button):
		_last_button.disabled = _level_number <= 1
	if is_instance_valid(_next_button):
		_next_button.visible = true
	if is_instance_valid(_flow_label):
		if _using_csharp_sim:
			var swaps_value: Variant = _sim_snapshot.get("swaps", [])
			var swap_count := (swaps_value as Array).size() if swaps_value is Array else 0
			var circuit_state: String = "alive" if _circuit_alive_now() else ("complete" if _solved else "forming")
			_flow_label.text = str("Tick ", int(_sim_snapshot.get("tick", 0)), "  |  Recent swaps ", swap_count, "  |  Score/tick ", _score_per_tick_from_snapshot(), "  |  Circuit ", circuit_state)
		else:
			var met := _count_met_needs()
			var total := _cells.size() * 3
			_flow_label.text = str("Flow ", met, "/", total, " needs  |  Swaps ", _active_swap_pairs().size())


func _score_per_tick_from_snapshot() -> int:
	var tick_count := int(_sim_snapshot.get("tick", 0))
	if tick_count <= 0:
		return 0
	var score_value := float(_sim_snapshot.get("score", 0))
	return int(round(score_value / float(tick_count)))


func _circuit_alive_now() -> bool:
	if _using_csharp_sim:
		return bool(_sim_snapshot.get("alive", false))
	return _solved


func _draw() -> void:
	_update_frame_blend()
	var view_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.025, 0.055, 0.065, 1.0))
	_layout_board(view_size)
	if _using_board_renderer and is_instance_valid(_board_renderer):
		_sync_board_renderer()
		_draw_next_level_pulse()
		return
	_draw_board()
	_draw_circuit_flow_groups()
	_draw_links()
	_draw_hint()
	_draw_next_level_pulse()
	for cell in _cells:
		if cell == _drag_cell:
			continue
		_draw_cell(cell, _tile_center(_get_cell_tile(cell)), false)
	if _drag_cell != "":
		_draw_cell(_drag_cell, _drag_position, true)


func _sync_board_renderer() -> void:
	if not is_instance_valid(_board_renderer) or not _board_renderer.has_method("set_render_state"):
		_using_board_renderer = false
		return
	if _drag_cell != "" and _board_renderer_has_state and not _board_renderer_full_sync_needed and _board_renderer.has_method("set_drag_state"):
		_board_renderer.call("set_drag_state", _drag_cell, _drag_position, _original_drag_tile, true)
		return
	if _board_renderer_has_state and not _board_renderer_full_sync_needed:
		if _board_renderer is CanvasItem:
			(_board_renderer as CanvasItem).queue_redraw()
		return
	var state := {
		"boardRect": _board_rect,
		"tileSize": _tile_size,
		"boardCols": _board_cols,
		"boardRows": _board_rows,
		"cells": _cells,
		"positions": _positions,
		"producedByCell": _produced_by_cell,
		"needs": _needs,
		"snapshot": _sim_snapshot,
		"usingCsharpSim": _using_csharp_sim,
		"solved": _solved,
		"circuitOverlayEnabled": _circuit_overlay_enabled,
		"fastDragMode": _drag_cell != "",
		"dragCell": _drag_cell,
		"dragPosition": _drag_position,
		"originalDragTile": _original_drag_tile,
		"hintPair": _hint_pair,
		"resourceMarkMode": _resource_mark_mode
	}
	_board_renderer.call("set_render_state", state)
	_board_renderer_full_sync_needed = false
	_board_renderer_has_state = true


func _has_live_visual_animation() -> bool:
	if _solved:
		return true
	var flows_value: Variant = _sim_snapshot.get("flows", [])
	if flows_value is Array and not (flows_value as Array).is_empty():
		return true
	var reactions_value: Variant = _sim_snapshot.get("reactions", [])
	return reactions_value is Array and not (reactions_value as Array).is_empty()


func _layout_board(view_size: Vector2) -> void:
	var top := 130.0
	var bottom := 78.0
	var available := Vector2(maxf(1.0, view_size.x - 36.0), maxf(1.0, view_size.y - top - bottom))
	_tile_size = floor(minf(available.x / float(_board_cols), available.y / float(_board_rows)))
	_tile_size = maxf(24.0, _tile_size)
	var board_size := Vector2(_tile_size * _board_cols, _tile_size * _board_rows)
	_board_rect = Rect2(Vector2(round((view_size.x - board_size.x) * 0.5), top + round((available.y - board_size.y) * 0.5)), board_size)


func _draw_board() -> void:
	draw_rect(_board_rect.grow(10.0), Color(0.015, 0.030, 0.035, 0.88), true)
	for y in range(_board_rows):
		for x in range(_board_cols):
			var rect := Rect2(_board_rect.position + Vector2(x, y) * _tile_size, Vector2(_tile_size, _tile_size)).grow(-2.0)
			var shade := 0.085 if (x + y) % 2 == 0 else 0.105
			draw_rect(rect, Color(shade, shade + 0.035, shade + 0.045, 1.0), true)
			draw_rect(rect, Color(0.24, 0.42, 0.42, 0.18), false, 1.0)
	if _drag_cell != "":
		var tile := _screen_to_tile(_drag_position)
		if _is_tile_inside(tile) and (_is_tile_empty(tile) or tile == _original_drag_tile):
			var highlight := Rect2(_board_rect.position + Vector2(tile) * _tile_size, Vector2(_tile_size, _tile_size)).grow(-3.0)
			draw_rect(highlight, Color(0.45, 1.0, 0.78, 0.20), true)
			draw_rect(highlight, Color(0.55, 1.0, 0.82, 0.70), false, 3.0)


func _draw_links() -> void:
	if _using_csharp_sim:
		_draw_csharp_flows()
		return
	for pair in _active_swap_pairs():
		var a := str(pair[0])
		var b := str(pair[1])
		var color := Color(0.35, 1.0, 0.86, 0.68) if _solved else Color(0.30, 0.78, 0.86, 0.42)
		draw_line(_tile_center(_get_cell_tile(a)), _tile_center(_get_cell_tile(b)), color, 7.0, true)
		draw_line(_tile_center(_get_cell_tile(a)), _tile_center(_get_cell_tile(b)), Color(1.0, 1.0, 1.0, 0.18), 2.0, true)


func _draw_circuit_flow_groups() -> void:
	if not _circuit_overlay_enabled or not _using_csharp_sim:
		return
	var diagnostics_value: Variant = _sim_snapshot.get("circuitDiagnostics", {})
	if not diagnostics_value is Dictionary:
		return
	var diagnostics: Dictionary = diagnostics_value as Dictionary
	var edges_value: Variant = diagnostics.get("directedEdges", [])
	if not edges_value is Array:
		return
	var edges: Array = edges_value as Array
	_draw_circuit_blockers(diagnostics)
	if edges.is_empty():
		return

	var alive_now: bool = bool(diagnostics.get("alive", false))
	var window_ticks := maxf(1.0, float(_sim_snapshot.get("tick", 0)) - float(diagnostics.get("sinceTick", 0)))
	var weak_group_by_cell: Dictionary = {}
	var weak_color_by_group: Dictionary = {}
	var weak_groups_value: Variant = diagnostics.get("weakGroups", [])
	if weak_groups_value is Array:
		var weak_groups: Array = weak_groups_value as Array
		for weak_index in range(weak_groups.size()):
			var weak_cells: Array = _strings_from_variant_array(weak_groups[weak_index])
			if weak_cells.size() < 2:
				continue
			var weak_color := Color(1.0, 0.70, 0.20, 1.0)
			weak_color_by_group[weak_index] = weak_color
			for cell_value in weak_cells:
				weak_group_by_cell[str(cell_value)] = weak_index

	var strong_group_by_cell: Dictionary = {}
	var color_by_group: Dictionary = {}
	var cells_by_group: Dictionary = {}
	var active_group_index := 0
	var strong_groups_value: Variant = diagnostics.get("strongGroups", [])
	if strong_groups_value is Array:
		var strong_groups: Array = strong_groups_value as Array
		for group_value in strong_groups:
			var cells: Array = _strings_from_variant_array(group_value)
			if cells.size() < 2:
				continue
			var color := _circuit_group_color(0)
			color_by_group[active_group_index] = color
			cells_by_group[active_group_index] = cells
			for cell_value in cells:
				var cell := str(cell_value)
				strong_group_by_cell[cell] = active_group_index
			active_group_index += 1

	var alpha_by_group: Dictionary = {}
	for alpha_edge_value in edges:
		if not alpha_edge_value is Dictionary:
			continue
		var alpha_edge := alpha_edge_value as Dictionary
		var alpha_source := str(alpha_edge.get("sourceCellId", ""))
		var alpha_target := str(alpha_edge.get("targetCellId", ""))
		var alpha_source_group := int(strong_group_by_cell.get(alpha_source, -1))
		var alpha_target_group := int(strong_group_by_cell.get(alpha_target, -2))
		if alpha_source_group < 0 or alpha_source_group != alpha_target_group:
			continue
		var alpha_age := maxf(0.0, float(alpha_edge.get("ageTicks", 0.0)))
		var edge_alpha := _circuit_age_alpha(alpha_age, window_ticks)
		alpha_by_group[alpha_source_group] = maxf(float(alpha_by_group.get(alpha_source_group, 0.0)), edge_alpha)

	for group_key in cells_by_group.keys():
		var cells_value: Variant = cells_by_group.get(group_key, [])
		if not cells_value is Array:
			continue
		var cells: Array = cells_value as Array
		var group_alpha := float(alpha_by_group.get(group_key, 0.0))
		if group_alpha <= 0.0:
			continue
		var color_value: Variant = color_by_group.get(group_key, Color(0.30, 1.0, 0.84, 1.0))
		var color := Color(0.30, 1.0, 0.84, 1.0)
		if color_value is Color:
			color = color_value as Color
		var is_full_group := _flow_group_contains_all_cells(cells)
		_draw_circuit_component_halo(cells, color, is_full_group and alive_now, group_alpha)

	for edge_value in edges:
		if not edge_value is Dictionary:
			continue
		var edge := edge_value as Dictionary
		var source := str(edge.get("sourceCellId", ""))
		var target := str(edge.get("targetCellId", ""))
		if source.is_empty() or target.is_empty():
			continue
		var age := maxf(0.0, float(edge.get("ageTicks", 0.0)))
		var alpha := _circuit_age_alpha(age, window_ticks)
		if alpha <= 0.0:
			continue
		var source_group := int(strong_group_by_cell.get(source, -1))
		var target_group := int(strong_group_by_cell.get(target, -2))
		var same_strong_group := source_group >= 0 and source_group == target_group
		var source_weak_group := int(weak_group_by_cell.get(source, -1))
		var target_weak_group := int(weak_group_by_cell.get(target, -2))
		var same_weak_group := source_weak_group >= 0 and source_weak_group == target_weak_group
		var color := Color(1.0, 0.70, 0.20, 1.0)
		if same_strong_group:
			var color_value: Variant = color_by_group.get(source_group, Color(0.30, 1.0, 0.84, 1.0))
			if color_value is Color:
				color = color_value as Color
		elif same_weak_group:
			var weak_color_value: Variant = weak_color_by_group.get(source_weak_group, Color(1.0, 0.70, 0.20, 1.0))
			if weak_color_value is Color:
				color = weak_color_value as Color
		var start := _visual_cell_center(source)
		var finish := _visual_cell_center(target)
		_draw_directed_circuit_line(start, finish, color, alpha, same_strong_group and alive_now, not same_strong_group, same_weak_group)


func _circuit_group_color(index: int) -> Color:
	var value: Variant = CIRCUIT_GROUP_COLORS[index % CIRCUIT_GROUP_COLORS.size()]
	if value is Color:
		return value as Color
	return Color(0.30, 1.0, 0.84, 1.0)


func _circuit_age_alpha(age: float, window_ticks: float) -> float:
	var raw: float = clampf(1.0 - age / maxf(1.0, window_ticks), 0.0, 1.0)
	return float(pow(raw, 1.65))


func _draw_circuit_component_halo(cells: Array, color: Color, complete: bool, strength: float) -> void:
	strength = clampf(strength, 0.0, 1.0)
	if strength <= 0.0:
		return
	var tile_keys: Dictionary = {}
	for cell_value in cells:
		var cell := str(cell_value)
		tile_keys[_component_tile_key(_get_cell_tile(cell))] = true

	var pulse := 0.5 + sin(Time.get_ticks_msec() / (105.0 if complete else 190.0)) * 0.5
	var fill_alpha := (0.13 + pulse * 0.04) * strength
	var boundary_alpha := (0.56 + pulse * 0.14) * strength
	var heat_radius := _tile_size * 0.56
	var connector_width := _tile_size * 0.88
	var boundary_width := 5.0
	if complete:
		fill_alpha = (0.28 + pulse * 0.10) * strength
		boundary_alpha = (0.82 + pulse * 0.16) * strength
		heat_radius = _tile_size * 0.64
		connector_width = _tile_size * 0.96
		boundary_width = 7.0

	var heat := color
	heat.a = fill_alpha
	for cell_value in cells:
		var cell := str(cell_value)
		var tile := _get_cell_tile(cell)
		var center := _tile_center(tile)
		var right_tile := Vector2i(tile.x + 1, tile.y)
		if _component_has_tile(tile_keys, right_tile):
			draw_line(center, _tile_center(right_tile), heat, connector_width, true)
		var down_tile := Vector2i(tile.x, tile.y + 1)
		if _component_has_tile(tile_keys, down_tile):
			draw_line(center, _tile_center(down_tile), heat, connector_width, true)

	for cell_value in cells:
		var cell := str(cell_value)
		var center := _tile_center(_get_cell_tile(cell))
		var halo := color
		halo.a = fill_alpha
		draw_circle(center, heat_radius, halo)

	for cell_value in cells:
		var cell := str(cell_value)
		var tile := _get_cell_tile(cell)
		var tile_origin := _board_rect.position + Vector2(tile) * _tile_size
		var top_left := tile_origin
		var top_right := tile_origin + Vector2(_tile_size, 0.0)
		var bottom_left := tile_origin + Vector2(0.0, _tile_size)
		var bottom_right := tile_origin + Vector2(_tile_size, _tile_size)
		if not _component_has_tile(tile_keys, Vector2i(tile.x, tile.y - 1)):
			_draw_component_boundary_segment(top_left, top_right, color, boundary_alpha, boundary_width)
		if not _component_has_tile(tile_keys, Vector2i(tile.x + 1, tile.y)):
			_draw_component_boundary_segment(top_right, bottom_right, color, boundary_alpha, boundary_width)
		if not _component_has_tile(tile_keys, Vector2i(tile.x, tile.y + 1)):
			_draw_component_boundary_segment(bottom_right, bottom_left, color, boundary_alpha, boundary_width)
		if not _component_has_tile(tile_keys, Vector2i(tile.x - 1, tile.y)):
			_draw_component_boundary_segment(bottom_left, top_left, color, boundary_alpha, boundary_width)


func _component_tile_key(tile: Vector2i) -> String:
	return str(tile.x, ":", tile.y)


func _component_has_tile(tile_keys: Dictionary, tile: Vector2i) -> bool:
	return bool(tile_keys.get(_component_tile_key(tile), false))


func _draw_component_boundary_segment(start: Vector2, finish: Vector2, color: Color, alpha: float, width: float) -> void:
	var glow := color
	glow.a = alpha * 0.32
	draw_line(start, finish, glow, width + 9.0, true)
	var shadow := Color(0.00, 0.07, 0.08, alpha * 0.50)
	draw_line(start, finish, shadow, width + 3.0, true)
	var core := color.lightened(0.30)
	core.a = alpha
	draw_line(start, finish, core, width, true)


func _strings_from_variant_array(value: Variant) -> Array:
	var strings: Array = []
	if not value is Array:
		return strings
	var values: Array = value as Array
	for item in values:
		strings.append(str(item))
	strings.sort()
	return strings


func _draw_circuit_blockers(diagnostics: Dictionary) -> void:
	var blocked_cells: Array = _strings_from_variant_array(diagnostics.get("nonGlowingRequiredCells", []))
	if blocked_cells.is_empty():
		return
	var pulse := 0.5 + sin(Time.get_ticks_msec() / 190.0) * 0.5
	for cell_value in blocked_cells:
		var cell := str(cell_value)
		var center := _visual_cell_center(cell)
		var warning := Color(1.0, 0.40, 0.18, 0.08 + pulse * 0.05)
		draw_circle(center, _tile_size * 0.56, warning)
		var rim := Color(1.0, 0.72, 0.28, 0.22 + pulse * 0.12)
		draw_arc(center, _tile_size * 0.47, -PI * 0.15, TAU * 0.82, 36, rim, 2.5, true)


func _draw_directed_circuit_line(start: Vector2, finish: Vector2, color: Color, alpha: float, intense: bool, transient: bool, in_component: bool) -> void:
	var delta := finish - start
	if delta.length_squared() <= 1.0:
		return
	var direction := delta.normalized()
	var normal := direction.orthogonal()
	var line_start := start + direction * _tile_size * 0.30
	var line_finish := finish - direction * _tile_size * 0.30
	var pulse := 0.5 + sin(Time.get_ticks_msec() / (90.0 if intense else 150.0) + start.x * 0.02) * 0.5
	var broad := color
	broad.a = (0.12 + alpha * 0.20) if transient else ((0.16 + alpha * 0.18) if not intense else (0.24 + alpha * 0.26))
	draw_line(line_start, line_finish, broad, _tile_size * (0.28 if transient else (0.34 if not intense else 0.46)), true)
	if in_component and transient:
		var side := color.lightened(0.18)
		side.a = 0.30 + alpha * 0.22
		draw_line(line_start + normal * _tile_size * 0.09, line_finish + normal * _tile_size * 0.09, side, maxf(2.0, _tile_size * 0.035), true)
		draw_line(line_start - normal * _tile_size * 0.09, line_finish - normal * _tile_size * 0.09, side, maxf(2.0, _tile_size * 0.035), true)
	var core := color.lightened(0.25)
	core.a = (0.34 + alpha * 0.28) if transient else ((0.32 + alpha * 0.32) if not intense else (0.50 + alpha * 0.44))
	draw_line(line_start, line_finish, core, maxf(3.0, _tile_size * (0.050 if transient else (0.065 if not intense else 0.090))), true)
	var spark := Color(1.0, 1.0, 1.0, (0.24 + alpha * 0.24) if transient else (0.28 + alpha * 0.38))
	var offset := normal * sin(Time.get_ticks_msec() / 76.0 + finish.y * 0.025) * _tile_size * 0.035
	draw_line(line_start + offset, line_finish - offset, spark, 1.8 if transient else 2.2, true)
	var arrow_at := line_start.lerp(line_finish, 0.66 + pulse * 0.12)
	var arrow_size := _tile_size * (0.15 if transient else 0.18)
	var arrow_color := core
	arrow_color.a = clampf(core.a + 0.12, 0.0, 1.0)
	draw_line(arrow_at, arrow_at - direction * arrow_size + normal * arrow_size * 0.58, arrow_color, 2.8, true)
	draw_line(arrow_at, arrow_at - direction * arrow_size - normal * arrow_size * 0.58, arrow_color, 2.8, true)


func _draw_group_current_line(start: Vector2, finish: Vector2, color: Color, alpha: float, intense: bool) -> void:
	if start.distance_squared_to(finish) <= 1.0:
		return
	var broad := color
	broad.a = (0.08 + alpha * 0.13) if not intense else (0.20 + alpha * 0.22)
	draw_line(start, finish, broad, _tile_size * (0.34 if not intense else 0.46), true)
	var core := color.lightened(0.30)
	core.a = (0.18 + alpha * 0.30) if not intense else (0.44 + alpha * 0.42)
	draw_line(start, finish, core, maxf(3.0, _tile_size * (0.06 if not intense else 0.09)), true)
	var delta := finish - start
	var normal := delta.orthogonal().normalized()
	var phase := Time.get_ticks_msec() / (70.0 if intense else 115.0)
	var spark := Color(1.0, 1.0, 1.0, 0.20 + alpha * (0.22 if not intense else 0.46))
	var offset := normal * sin(phase + start.x * 0.03 + start.y * 0.02) * _tile_size * 0.045
	draw_line(start + offset, finish - offset, spark, 1.6 if not intense else 2.4, true)


func _flow_groups_from_parent(parent: Dictionary) -> Dictionary:
	var groups := {}
	for cell_value in parent.keys():
		var cell := str(cell_value)
		var root := _flow_group_find(parent, cell)
		if not groups.has(root):
			groups[root] = []
		var cells_value: Variant = groups.get(root, [])
		if cells_value is Array:
			var cells: Array = cells_value as Array
			cells.append(cell)
			groups[root] = cells
	for root in groups.keys():
		var cells_value: Variant = groups.get(root, [])
		if cells_value is Array:
			var cells: Array = cells_value as Array
			cells.sort()
			groups[root] = cells
	return groups


func _flow_group_contains_all_cells(cells: Array) -> bool:
	if cells.size() < _cells.size():
		return false
	var seen := {}
	for cell_value in cells:
		seen[str(cell_value)] = true
	for cell in _cells:
		if not seen.has(cell):
			return false
	return true


func _flow_group_find(parent: Dictionary, cell: String) -> String:
	if not parent.has(cell):
		parent[cell] = cell
		return cell
	var current := str(parent[cell])
	if current == cell:
		return cell
	var root := _flow_group_find(parent, current)
	parent[cell] = root
	return root


func _flow_group_union(parent: Dictionary, a: String, b: String) -> void:
	var root_a := _flow_group_find(parent, a)
	var root_b := _flow_group_find(parent, b)
	if root_a == root_b:
		return
	if root_a < root_b:
		parent[root_b] = root_a
	else:
		parent[root_a] = root_b


func _draw_csharp_flows() -> void:
	var flows_value: Variant = _sim_snapshot.get("flows", [])
	if not flows_value is Array:
		return
	var current_tick := float(_sim_snapshot.get("tick", 0))
	var flows: Array = flows_value as Array
	for flow_value in flows:
		if not flow_value is Dictionary:
			continue
		var flow := flow_value as Dictionary
		var source := str(flow.get("sourceCellId", ""))
		var target := str(flow.get("targetCellId", ""))
		var resource := str(flow.get("resource", ""))
		if source.is_empty() or target.is_empty() or resource.is_empty():
			continue
		var age := maxf(0.0, current_tick - float(flow.get("tick", current_tick)))
		var alpha := clampf(1.0 - age / SWAP_VISUAL_TTL_TICKS, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var source_point := _resource_visual_point(source, resource)
		var target_point := _resource_visual_point(target, resource)
		var flow_color := _resource_color(resource)
		_draw_electric_flow_line(source_point, target_point, flow_color, alpha)
		var t := clampf(age / 2.4, 0.0, 1.0)
		_draw_swap_particle(source_point.lerp(target_point, t), resource, alpha)


func _draw_swap_particle(position: Vector2, resource: String, alpha: float) -> void:
	var color := _resource_color(resource)
	color.a = clampf(alpha, 0.0, 1.0)
	var radius := maxf(3.0, _tile_size * 0.055)
	draw_circle(position, radius, color)
	draw_circle(position, radius, Color(1, 1, 1, 0.34 * alpha), false, 1.6)


func _draw_electric_flow_line(start: Vector2, finish: Vector2, color: Color, alpha: float) -> void:
	var delta := finish - start
	if delta.length_squared() <= 1.0:
		return
	var normal := delta.orthogonal().normalized()
	var phase := Time.get_ticks_msec() / 82.0
	var electric_color := color
	electric_color.a = 0.24 + alpha * (0.38 if _circuit_alive_now() else 0.26)
	draw_line(start, finish, electric_color, 3.0 + alpha * 2.0, true)
	for index in range(2):
		var wave := sin(phase + float(index) * PI)
		var offset := normal * wave * _tile_size * 0.025
		var branch_color := color.lightened(0.22)
		branch_color.a = 0.14 + alpha * 0.20
		draw_line(start + offset, finish - offset, branch_color, 1.4, true)


func _draw_hint() -> void:
	if _hint_pair.size() != 2:
		return
	var a := _hint_pair[0]
	var b := _hint_pair[1]
	var a_center := _visual_cell_center(a)
	var b_center := _visual_cell_center(b)
	var hint_color := Color(1.0, 0.92, 0.24, 0.86)
	draw_line(a_center, b_center, Color(1.0, 0.92, 0.24, 0.34), 9.0, true)
	draw_line(a_center, b_center, hint_color, 3.0, true)
	draw_arc(a_center, _tile_size * 0.49, 0.0, TAU, _arc_segments(_tile_size * 0.49), hint_color, 5.0, true)
	draw_arc(b_center, _tile_size * 0.49, 0.0, TAU, _arc_segments(_tile_size * 0.49), hint_color, 5.0, true)


func _draw_cell(cell: String, center: Vector2, dragging: bool) -> void:
	var radius := _tile_size * (0.39 if not dragging else 0.43)
	var produced_resource := _cell_produced_resource(cell)
	var color := _resource_color(produced_resource)
	var live_complete: bool = _circuit_alive_now()
	var glow_alpha := 0.46 if _cell_has_all_needs(cell) else 0.18
	if _using_csharp_sim:
		glow_alpha = 0.56 if _cell_is_glowing(cell) else 0.16
	if live_complete:
		glow_alpha = 0.72
	var reaction_alpha := _recent_reaction_alpha(cell)
	if reaction_alpha > 0.0:
		glow_alpha = maxf(glow_alpha, 0.52 + reaction_alpha * 0.28)
		draw_circle(center, radius * (1.22 + reaction_alpha * 0.10), Color(1.0, 0.95, 0.58, reaction_alpha * 0.18))
	draw_circle(center, radius * (1.16 + (0.04 if live_complete else 0.0)), Color(color.r, color.g, color.b, glow_alpha * 0.28))
	draw_circle(center, radius, Color(color.r, color.g, color.b, 0.72))
	draw_arc(center, radius * 0.96, 0.0, TAU, _arc_segments(radius), Color(0.92, 1.0, 0.95, 0.68), 3.0, true)
	if live_complete:
		var solved_pulse := 0.5 + sin(Time.get_ticks_msec() / 160.0) * 0.5
		draw_arc(center, radius * (1.07 + solved_pulse * 0.03), 0.0, TAU, _arc_segments(radius), Color(0.62, 1.0, 0.88, 0.28 + solved_pulse * 0.18), 3.0, true)
	if _using_csharp_sim:
		_draw_fullness_arc(center, radius * 1.07, _display_fullness(cell, produced_resource, _slot_fullness(cell, produced_resource)), color, 6.0)
	var font := get_theme_default_font()
	var needed: Array = _needs.get(cell, [])
	var used_angles: Array[float] = []
	for index in range(needed.size()):
		var need := str(needed[index])
		var pip_radius := _need_pip_radius(radius)
		var visual := _need_visual_data(cell, need, index, needed.size(), center, radius, pip_radius, used_angles)
		var angle := float(visual.get("angle", 0.0))
		used_angles.append(float(visual.get("targetAngle", angle)))
		var pip_offset := float(visual.get("offset", radius * 1.18))
		var pip_center := center + Vector2(cos(angle), sin(angle)) * pip_offset
		var state := str(visual.get("state", NEED_STATE_MISSING))
		var fullness := float(visual.get("fullness", 0.0))
		var active_alpha := float(visual.get("activeAlpha", 0.0))
		var met := state != NEED_STATE_MISSING or fullness > 0.0
		var pip_color := _resource_color(need)
		if state == NEED_STATE_MISSING:
			pip_color = pip_color.darkened(0.48)
			pip_color.a = 1.0
			_draw_need_tether(center, pip_center, radius, pip_radius, Color(0.75, 0.88, 0.90, 0.28))
		elif state == NEED_STATE_AVAILABLE:
			pip_color = pip_color.darkened(0.12)
			pip_color.a = 1.0
			_draw_need_tether(center, pip_center, radius, pip_radius, Color(pip_color.r, pip_color.g, pip_color.b, 0.42))
		elif state == NEED_STATE_ACTIVE:
			pip_color.a = 1.0
			draw_circle(pip_center, pip_radius * (1.14 + active_alpha * 0.16), Color(pip_color.r, pip_color.g, pip_color.b, 0.20 + active_alpha * 0.26))
		else:
			pip_color.a = 1.0
		draw_circle(pip_center, pip_radius, pip_color)
		draw_circle(pip_center, pip_radius, Color(0.01, 0.025, 0.03, 0.82), false, 2.2)
		draw_circle(pip_center, pip_radius * 0.86, Color(1, 1, 1, 0.44 if met else 0.28), false, 1.4)
		_draw_fullness_arc(pip_center, pip_radius * 1.12, _display_fullness(cell, need, fullness), pip_color, maxf(2.0, pip_radius * 0.20))
		_draw_resource_mark(font, pip_center, pip_radius, need, int(pip_radius * 1.02), Color.WHITE)
	_draw_resource_mark(font, center, radius, produced_resource, int(radius * 1.48), Color.WHITE)


func _draw_need_tether(center: Vector2, pip_center: Vector2, cell_radius: float, pip_radius: float, color: Color) -> void:
	var delta := pip_center - center
	if delta.length_squared() <= 1.0:
		return
	var direction := delta.normalized()
	var start := center + direction * (cell_radius * 0.78)
	var finish := pip_center - direction * (pip_radius * 0.72)
	draw_line(start, finish, color, 2.0, true)


func _need_pip_radius(cell_radius: float) -> float:
	return maxf(5.5, minf(cell_radius * 0.38, _tile_size * 0.15))


func _need_visual_data(
	cell: String,
	need: String,
	index: int,
	count: int,
	center: Vector2,
	cell_radius: float,
	pip_radius: float,
	used_angles: Array[float],
	apply_smoothing: bool = true) -> Dictionary:
	var state_data := _need_state_data(cell, need)
	var partner := str(state_data.get("partner", ""))
	var base_angle := _base_need_angle(cell, need, index, count, center, partner)
	var target_angle := _separate_need_angle(base_angle, used_angles)
	var target_offset := _need_pip_offset_for_state(center, partner, cell_radius, pip_radius, str(state_data.get("state", NEED_STATE_MISSING)))
	var angle := target_angle
	var offset := target_offset
	var pip_key := _pip_key(cell, need)
	if apply_smoothing:
		angle = _smooth_pip_angle(pip_key, angle)
		offset = _smooth_pip_offset(pip_key, offset)
	state_data["angle"] = angle
	state_data["offset"] = offset
	state_data["targetAngle"] = target_angle
	state_data["targetOffset"] = target_offset
	return state_data


func _need_state_data(cell: String, need: String) -> Dictionary:
	var fullness := _slot_fullness(cell, need) if _using_csharp_sim else 0.0
	var active_partner := _recent_flow_source_for_need(cell, need)
	var active_alpha := _recent_flow_alpha_for_need(cell, need)
	if active_partner.is_empty():
		active_partner = _recent_swap_partner_for_need(cell, need)
	if not active_partner.is_empty():
		if not _using_csharp_sim:
			fullness = 1.0
		return {
			"state": NEED_STATE_ACTIVE,
			"partner": active_partner,
			"fullness": maxf(fullness, 0.18),
			"activeAlpha": maxf(active_alpha, 0.45)
		}

	var possible_partner := _possible_swap_partner_for_need(cell, need)
	if possible_partner.is_empty() and not _using_csharp_sim:
		possible_partner = _adjacent_reciprocal_partner_for_need(cell, need)
	if possible_partner.is_empty() and _using_csharp_sim:
		possible_partner = _adjacent_exchange_partner_for_need(cell, need)
	if not possible_partner.is_empty():
		return {
			"state": NEED_STATE_AVAILABLE,
			"partner": possible_partner,
			"fullness": fullness,
			"activeAlpha": 0.0
		}

	if fullness > 0.0:
		return {
			"state": NEED_STATE_SATISFIED,
			"partner": "",
			"fullness": fullness,
			"activeAlpha": 0.0
		}

	return {
		"state": NEED_STATE_MISSING,
		"partner": "",
		"fullness": 0.0,
		"activeAlpha": 0.0
	}


func _base_need_angle(cell: String, need: String, index: int, count: int, center: Vector2, partner: String) -> float:
	if not partner.is_empty():
		var delta := _visual_cell_center(partner) - center
		if delta.length_squared() > 1.0:
			return delta.angle()
	return _need_angle_for_cell(cell, need, index, count, center)


func _separate_need_angle(base_angle: float, used_angles: Array[float]) -> float:
	if used_angles.is_empty():
		return base_angle
	var minimum_gap := 0.58
	var offsets: Array[float] = [0.0, minimum_gap, -minimum_gap, minimum_gap * 2.0, -minimum_gap * 2.0]
	for offset in offsets:
		var candidate := base_angle + offset
		var separated := true
		for used in used_angles:
			if absf(wrapf(candidate - used, -PI, PI)) < minimum_gap:
				separated = false
				break
		if separated:
			return candidate
	return base_angle


func _need_pip_offset_for_state(center: Vector2, partner: String, cell_radius: float, pip_radius: float, state: String) -> float:
	if partner.is_empty():
		if state == NEED_STATE_SATISFIED:
			return cell_radius + pip_radius * 0.10
		return cell_radius + pip_radius * 0.55
	return _need_pip_offset(center, partner, cell_radius, pip_radius)


func _resource_visual_point(cell: String, resource: String) -> Vector2:
	var center := _visual_cell_center(cell)
	if _cell_needs_resource(cell, resource):
		return _need_pip_center_for_resource(cell, resource, center)
	return center


func _need_pip_center_for_resource(cell: String, resource: String, center: Vector2) -> Vector2:
	var needed: Array = _needs.get(cell, [])
	var radius := _tile_size * (0.43 if cell == _drag_cell else 0.39)
	var pip_radius := _need_pip_radius(radius)
	var used_angles: Array[float] = []
	for index in range(needed.size()):
		var need := str(needed[index])
		var pip_key := _pip_key(cell, need)
		var visual := _need_visual_data(cell, need, index, needed.size(), center, radius, pip_radius, used_angles, false)
		var angle := float(visual.get("angle", 0.0))
		used_angles.append(float(visual.get("targetAngle", angle)))
		if need == resource:
			if _pip_angle_by_key.has(pip_key) and _pip_offset_by_key.has(pip_key):
				var stored_angle := float(_pip_angle_by_key.get(pip_key, angle))
				var stored_offset := float(_pip_offset_by_key.get(pip_key, radius * 1.18))
				return center + Vector2(cos(stored_angle), sin(stored_angle)) * stored_offset
			var offset := float(visual.get("offset", radius * 1.18))
			return center + Vector2(cos(angle), sin(angle)) * offset
	return center


func _pip_key(cell: String, need: String) -> String:
	return str(cell, ":", need)


func _smooth_pip_angle(key: String, target_angle: float) -> float:
	if not _pip_angle_by_key.has(key):
		_pip_angle_by_key[key] = target_angle
		return target_angle
	var current := float(_pip_angle_by_key.get(key, target_angle))
	var smoothed := current + wrapf(target_angle - current, -PI, PI) * PIP_ANGLE_SMOOTH
	_pip_angle_by_key[key] = smoothed
	return smoothed


func _smooth_pip_offset(key: String, target_offset: float) -> float:
	if not _pip_offset_by_key.has(key):
		_pip_offset_by_key[key] = target_offset
		return target_offset
	var current := float(_pip_offset_by_key.get(key, target_offset))
	var smoothed := lerpf(current, target_offset, PIP_OFFSET_SMOOTH)
	_pip_offset_by_key[key] = smoothed
	return smoothed


func _draw_next_level_pulse() -> void:
	if not _solved or not is_instance_valid(_next_button):
		return
	var rect := Rect2(_next_button.position, _next_button.size).grow(6.0)
	var pulse := 0.5 + sin(Time.get_ticks_msec() / 130.0) * 0.5
	draw_rect(rect, Color(0.52, 1.0, 0.78, 0.12 + pulse * 0.18), true)
	draw_rect(rect, Color(0.72, 1.0, 0.86, 0.50 + pulse * 0.32), false, 3.0)


func _draw_resource_mark(font: Font, center: Vector2, radius: float, resource: String, font_size: int, color: Color) -> void:
	var mark := _resource_mark_text(resource)
	if mark.is_empty():
		return
	_draw_centered_bold_resource(font, center, radius, mark, font_size, color)


func _resource_mark_text(resource: String) -> String:
	if _resource_mark_mode == MARK_MODE_HIDDEN:
		return ""
	if _resource_mark_mode == MARK_MODE_SYMBOLS:
		var index := RESOURCE_LETTERS.find(resource)
		if index >= 0 and index < RESOURCE_SYMBOL_MARKS.size():
			return str(RESOURCE_SYMBOL_MARKS[index])
	return resource


func _draw_centered_bold_resource(font: Font, center: Vector2, radius: float, text: String, font_size: int, color: Color) -> void:
	if text.is_empty():
		return
	var adjusted_size := font_size
	if text.length() > 1:
		adjusted_size = maxi(8, int(float(font_size) / (float(text.length()) * 0.72)))
	var width := radius * 2.0
	var origin := Vector2(center.x - radius, center.y + float(adjusted_size) * 0.35)
	var outline_color := Color(0.01, 0.025, 0.03, 0.86)
	var outline_offsets: Array[Vector2] = [
		Vector2(-1.5, 0.0),
		Vector2(1.5, 0.0),
		Vector2(0.0, -1.5),
		Vector2(0.0, 1.5)
	]
	for offset in outline_offsets:
		draw_string(font, origin + offset, text, HORIZONTAL_ALIGNMENT_CENTER, width, adjusted_size, outline_color)
	var weight_offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(0.75, 0.0),
		Vector2(-0.75, 0.0)
	]
	for offset in weight_offsets:
		draw_string(font, origin + offset, text, HORIZONTAL_ALIGNMENT_CENTER, width, adjusted_size, color)


func _draw_fullness_arc(center: Vector2, radius: float, fullness: float, color: Color, width: float) -> void:
	var amount := clampf(fullness, 0.0, 1.0)
	var segments := _fullness_arc_segments(radius)
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, segments, Color(0.0, 0.0, 0.0, 0.34), width, true)
	if amount <= 0.0:
		return
	var arc_color := color.lightened(0.26)
	arc_color.a = 0.92
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * amount, segments, arc_color, width, true)


func _update_frame_blend() -> void:
	var now := Time.get_ticks_msec()
	if _last_draw_msec == 0:
		_last_draw_msec = now
		_frame_blend = 1.0
		return
	var delta_seconds := clampf(float(now - _last_draw_msec) / 1000.0, 0.0, 0.10)
	_last_draw_msec = now
	_frame_blend = 1.0 - exp(-delta_seconds * 18.0)


func _display_fullness(cell: String, resource: String, target: float) -> float:
	var key := str(cell, ":", resource)
	var clamped_target := clampf(target, 0.0, 1.0)
	if not _display_fullness_by_key.has(key):
		_display_fullness_by_key[key] = clamped_target
		return clamped_target
	var current := float(_display_fullness_by_key.get(key, clamped_target))
	var next := lerpf(current, clamped_target, _frame_blend)
	if absf(next - clamped_target) < 0.0025:
		next = clamped_target
	_display_fullness_by_key[key] = next
	return next


func _arc_segments(radius: float) -> int:
	if radius < 14.0:
		return 16
	if radius < 28.0:
		return 24
	return 36


func _fullness_arc_segments(radius: float) -> int:
	if radius < 14.0:
		return 12
	if radius < 28.0:
		return 16
	return 24


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_drag(mouse_event.position)
			else:
				_finish_drag(mouse_event.position)
	elif event is InputEventMouseMotion and _drag_cell != "":
		_update_drag((event as InputEventMouseMotion).position)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_drag(touch_event.position)
		else:
			_finish_drag(touch_event.position)
	elif event is InputEventScreenDrag and _drag_cell != "":
		_update_drag((event as InputEventScreenDrag).position)


func _begin_drag(screen_pos: Vector2) -> void:
	var picked := _cell_at(screen_pos)
	if picked == "":
		return
	_drag_cell = picked
	_clear_hint()
	_original_drag_tile = _get_cell_tile(picked)
	_drag_position = _tile_center(_original_drag_tile)
	_drag_offset = _drag_position - screen_pos
	accept_event()
	queue_redraw()


func _update_drag(screen_pos: Vector2) -> void:
	_drag_position = screen_pos + _drag_offset
	accept_event()
	queue_redraw()


func _finish_drag(screen_pos: Vector2) -> void:
	if _drag_cell == "":
		return
	_drag_position = screen_pos + _drag_offset
	var tile := _screen_to_tile(_drag_position)
	if _is_tile_inside(tile) and (_is_tile_empty(tile) or tile == _original_drag_tile):
		if _using_csharp_sim and is_instance_valid(_sim_bridge):
			var moved_value: Variant = _sim_bridge.call("move_cell", _drag_cell, tile.x, tile.y)
			if bool(moved_value):
				var reset_value: Variant = _sim_bridge.call("reset_with_current_layout")
				if not bool(reset_value):
					var error_value: Variant = _sim_bridge.call("get_last_error")
					push_warning("Cellular C# sim bridge failed to reset moved layout: %s" % str(error_value))
				_sim_tick_accum = 0.0
				_refresh_sim_snapshot()
				_board_renderer_full_sync_needed = true
		else:
			_positions[_drag_cell] = tile
			_board_renderer_full_sync_needed = true
	_drag_cell = ""
	_check_solution()
	accept_event()
	queue_redraw()


func _cell_at(screen_pos: Vector2) -> String:
	for index in range(_cells.size() - 1, -1, -1):
		var cell := _cells[index]
		var center := _tile_center(_get_cell_tile(cell))
		if center.distance_to(screen_pos) <= _tile_size * 0.44:
			return cell
	return ""


func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var local := screen_pos - _board_rect.position
	return Vector2i(floori(local.x / _tile_size), floori(local.y / _tile_size))


func _tile_center(tile: Vector2i) -> Vector2:
	return _board_rect.position + (Vector2(tile) + Vector2(0.5, 0.5)) * _tile_size


func _is_tile_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < _board_cols and tile.y < _board_rows


func _is_tile_empty(tile: Vector2i) -> bool:
	for cell in _cells:
		if cell == _drag_cell:
			continue
		if _get_cell_tile(cell) == tile:
			return false
	return true


func _active_swap_pairs() -> Array:
	var pairs := []
	for i in range(_cells.size()):
		for j in range(i + 1, _cells.size()):
			var a := _cells[i]
			var b := _cells[j]
			if _can_swap_pair(a, b):
				pairs.append([a, b])
	return pairs


func _can_swap_pair(a: String, b: String) -> bool:
	if _get_cell_tile(a).distance_squared_to(_get_cell_tile(b)) != 1:
		return false
	return _cells_can_match(a, b)


func _cells_can_match(a: String, b: String) -> bool:
	return _cell_needs_resource(a, _cell_produced_resource(b)) and _cell_needs_resource(b, _cell_produced_resource(a))


func _cell_needs_resource(cell: String, resource: String) -> bool:
	var needed: Array = _needs.get(cell, [])
	return needed.has(resource)


func _need_has_active_swap(cell: String, need: String) -> bool:
	if not _cell_needs_resource(cell, need):
		return false
	return _active_component_resources(cell).has(need)


func _need_angle_for_cell(cell: String, need: String, index: int, count: int, center: Vector2) -> float:
	if not _using_csharp_sim:
		var partner := _adjacent_reciprocal_partner_for_need(cell, need)
		if partner.is_empty():
			partner = _recent_swap_partner_for_need(cell, need)
		if not partner.is_empty():
			var delta := _visual_cell_center(partner) - center
			if delta.length_squared() > 1.0:
				return delta.angle()
	return -PI * 0.5 + (float(index) / maxf(1.0, float(count))) * TAU


func _need_pip_offset(center: Vector2, partner: String, cell_radius: float, pip_radius: float) -> float:
	if partner.is_empty():
		return cell_radius + pip_radius * 0.30
	var partner_delta := _visual_cell_center(partner) - center
	var center_distance := partner_delta.length()
	if center_distance <= 1.0:
		return cell_radius + pip_radius * 0.30
	var rim_offset := cell_radius + pip_radius * 0.08
	var maximum_offset := maxf(rim_offset, center_distance * 0.5 - pip_radius * 0.58)
	return minf(rim_offset, maximum_offset)


func _recent_swap_partner_for_need(cell: String, need: String) -> String:
	if not _using_csharp_sim:
		return ""
	var swaps_value: Variant = _sim_snapshot.get("swaps", [])
	if not swaps_value is Array:
		return ""
	var swaps: Array = swaps_value as Array
	for index in range(swaps.size() - 1, -1, -1):
		var swap_value: Variant = swaps[index]
		if not swap_value is Dictionary:
			continue
		var swap := swap_value as Dictionary
		var initiator := str(swap.get("initiator", ""))
		var counterparty := str(swap.get("counterparty", ""))
		var initiator_received := str(swap.get("counterpartyPaidResource", ""))
		var counterparty_received := str(swap.get("initiatorPaidResource", ""))
		if cell == initiator and need == initiator_received:
			return counterparty
		if cell == counterparty and need == counterparty_received:
			return initiator
	return ""


func _recent_flow_source_for_need(cell: String, need: String) -> String:
	if not _using_csharp_sim:
		return ""
	var flows_value: Variant = _sim_snapshot.get("flows", [])
	if not flows_value is Array:
		return ""
	var flows: Array = flows_value as Array
	for index in range(flows.size() - 1, -1, -1):
		var flow_value: Variant = flows[index]
		if not flow_value is Dictionary:
			continue
		var flow := flow_value as Dictionary
		if str(flow.get("targetCellId", "")) == cell and str(flow.get("resource", "")) == need:
			return str(flow.get("sourceCellId", ""))
	return ""


func _recent_flow_alpha_for_need(cell: String, need: String) -> float:
	if not _using_csharp_sim:
		return 0.0
	var flows_value: Variant = _sim_snapshot.get("flows", [])
	if not flows_value is Array:
		return 0.0
	var current_tick := float(_sim_snapshot.get("tick", 0))
	var flows: Array = flows_value as Array
	for index in range(flows.size() - 1, -1, -1):
		var flow_value: Variant = flows[index]
		if not flow_value is Dictionary:
			continue
		var flow := flow_value as Dictionary
		if str(flow.get("targetCellId", "")) != cell or str(flow.get("resource", "")) != need:
			continue
		var age := maxf(0.0, current_tick - float(flow.get("tick", current_tick)))
		return clampf(1.0 - age / SWAP_VISUAL_TTL_TICKS, 0.0, 1.0)
	return 0.0


func _possible_swap_partner_for_need(cell: String, need: String) -> String:
	if not _using_csharp_sim:
		return ""
	var possible_value: Variant = _sim_snapshot.get("possibleSwaps", [])
	if not possible_value is Array:
		return ""
	var possible_swaps: Array = possible_value as Array
	for swap_value in possible_swaps:
		if not swap_value is Dictionary:
			continue
		var swap := swap_value as Dictionary
		var initiator := str(swap.get("initiator", ""))
		var counterparty := str(swap.get("counterparty", ""))
		var initiator_received := str(swap.get("counterpartyPaidResource", ""))
		var counterparty_received := str(swap.get("initiatorPaidResource", ""))
		if cell == initiator and need == initiator_received:
			return counterparty
		if cell == counterparty and need == counterparty_received:
			return initiator
	return ""


func _adjacent_reciprocal_partner_for_need(cell: String, need: String) -> String:
	for other in _cells:
		if other == cell:
			continue
		if _get_cell_tile(cell).distance_squared_to(_get_cell_tile(other)) != 1:
			continue
		if _cell_produced_resource(other) != need:
			continue
		if _cell_needs_resource(other, _cell_produced_resource(cell)):
			return other
	return ""


func _adjacent_exchange_partner_for_need(cell: String, need: String) -> String:
	for other in _cells:
		if other == cell:
			continue
		if _get_cell_tile(cell).distance_squared_to(_get_cell_tile(other)) != 1:
			continue
		if not _cell_can_offer_resource_to(other, need, cell):
			continue
		if _cell_has_payable_resource_for(other, cell):
			return other
	return ""


func _cell_has_payable_resource_for(cell: String, other: String) -> bool:
	var produced := _cell_produced_resource(cell)
	if _cell_accepts_resource(other, produced):
		return true
	var state := _get_cell_state(cell)
	var slots_value: Variant = state.get("slots", [])
	if slots_value is Array:
		for slot_value in slots_value:
			if not slot_value is Dictionary:
				continue
			var slot := slot_value as Dictionary
			var resource := str(slot.get("resource", ""))
			if resource.is_empty() or not _cell_accepts_resource(other, resource):
				continue
			if _slot_offerable_quantity(cell, resource) > 0:
				return true
	return false


func _cell_can_offer_resource_to(cell: String, resource: String, other: String) -> bool:
	if _cell_produced_resource(cell) == resource and _cell_accepts_resource(other, resource):
		return true
	return _cell_accepts_resource(other, resource) and _slot_offerable_quantity(cell, resource) > 0


func _cell_accepts_resource(cell: String, resource: String) -> bool:
	if _cell_produced_resource(cell) == resource:
		return true
	if _cell_needs_resource(cell, resource):
		return true
	var state := _get_cell_state(cell)
	var slots_value: Variant = state.get("slots", [])
	if not slots_value is Array:
		return false
	for slot_value in slots_value:
		if not slot_value is Dictionary:
			continue
		var slot := slot_value as Dictionary
		if str(slot.get("resource", "")) == resource:
			return true
	return false


func _slot_offerable_quantity(cell: String, resource: String) -> int:
	var state := _get_cell_state(cell)
	var slots_value: Variant = state.get("slots", [])
	if not slots_value is Array:
		return 0
	for slot_value in slots_value:
		if not slot_value is Dictionary:
			continue
		var slot := slot_value as Dictionary
		if str(slot.get("resource", "")) != resource:
			continue
		var quantity := int(slot.get("quantity", 0))
		var role := str(slot.get("role", ""))
		if role == "Need" or role == "SourceOutput":
			quantity -= 1
		return maxi(0, quantity)
	return 0


func _active_component_resources(cell: String) -> Array[String]:
	var seen := {}
	var queue: Array[String] = [cell]
	var resources: Array[String] = []
	while not queue.is_empty():
		var current := str(queue.pop_front())
		if seen.has(current):
			continue
		seen[current] = true
		resources.append(_cell_produced_resource(current))
		for other in _cells:
			if other == current or seen.has(other):
				continue
			if _can_swap_pair(current, other):
				queue.append(other)
	return resources


func _get_cell_tile(cell: String) -> Vector2i:
	var value: Variant = _positions.get(cell, Vector2i.ZERO)
	if value is Vector2i:
		return value
	return Vector2i.ZERO


func _get_cell_state(cell: String) -> Dictionary:
	var value: Variant = _cell_state_by_id.get(cell, {})
	if value is Dictionary:
		return value
	return {}


func _cell_produced_resource(cell: String) -> String:
	var value: Variant = _produced_by_cell.get(cell, cell)
	return str(value)


func _cell_is_glowing(cell: String) -> bool:
	if not _using_csharp_sim:
		return _cell_has_all_needs(cell)
	var state := _get_cell_state(cell)
	return bool(state.get("glowing", false))


func _recent_reaction_alpha(cell: String) -> float:
	if not _using_csharp_sim:
		return 0.0
	var reactions_value: Variant = _sim_snapshot.get("reactions", [])
	if not reactions_value is Array:
		return 0.0
	var current_tick := float(_sim_snapshot.get("tick", 0))
	var reactions: Array = reactions_value as Array
	for index in range(reactions.size() - 1, -1, -1):
		var reaction_value: Variant = reactions[index]
		if not reaction_value is Dictionary:
			continue
		var reaction := reaction_value as Dictionary
		if str(reaction.get("cellId", "")) != cell:
			continue
		var age := maxf(0.0, current_tick - float(reaction.get("tick", current_tick)))
		return clampf(1.0 - age / REACTION_VISUAL_TTL_TICKS, 0.0, 1.0)
	return 0.0


func _slot_fullness(cell: String, resource: String) -> float:
	var state := _get_cell_state(cell)
	var slots_value: Variant = state.get("slots", [])
	if not slots_value is Array:
		return 0.0
	for slot_value in slots_value:
		if not slot_value is Dictionary:
			continue
		var slot := slot_value as Dictionary
		if str(slot.get("resource", "")) == resource:
			return clampf(float(slot.get("fullness", 0.0)), 0.0, 1.0)
	return 0.0


func _cell_has_all_needs(cell: String) -> bool:
	if _using_csharp_sim:
		for need in _needs.get(cell, []):
			if _slot_fullness(cell, str(need)) <= 0.0:
				return false
		return true
	for need in _needs.get(cell, []):
		if not _need_has_active_swap(cell, str(need)):
			return false
	return true


func _find_matching_pairs() -> Array:
	var strong_group_by_cell := _diagnostic_group_by_cell("strongGroups")
	var weak_group_by_cell := _diagnostic_group_by_cell("weakGroups")
	var pairs := _best_solution_hint_pairs(strong_group_by_cell, weak_group_by_cell)
	if not pairs.is_empty():
		return pairs
	return _best_resource_hint_pairs(strong_group_by_cell, weak_group_by_cell)


func _best_solution_hint_pairs(strong_group_by_cell: Dictionary, weak_group_by_cell: Dictionary) -> Array:
	if _solution_positions.is_empty():
		return []
	var pairs: Array = []
	var best_score := -1000000.0
	for i in range(_cells.size()):
		var a := _cells[i]
		if not _solution_positions.has(a):
			continue
		for j in range(i + 1, _cells.size()):
			var b := _cells[j]
			if not _solution_positions.has(b):
				continue
			var a_solution_value: Variant = _solution_positions.get(a, Vector2i.ZERO)
			var b_solution_value: Variant = _solution_positions.get(b, Vector2i.ZERO)
			if not a_solution_value is Vector2i or not b_solution_value is Vector2i:
				continue
			var a_solution: Vector2i = a_solution_value as Vector2i
			var b_solution: Vector2i = b_solution_value as Vector2i
			if a_solution.distance_squared_to(b_solution) != 1:
				continue
			var score := _hint_pair_score(a, b, strong_group_by_cell, weak_group_by_cell, true)
			if score < -999999.0:
				continue
			if score > best_score:
				best_score = score
				pairs.clear()
				pairs.append([a, b])
			elif is_equal_approx(score, best_score):
				pairs.append([a, b])
	return pairs


func _best_resource_hint_pairs(strong_group_by_cell: Dictionary, weak_group_by_cell: Dictionary) -> Array:
	var pairs: Array = []
	var best_score := -1000000.0
	for i in range(_cells.size()):
		for j in range(i + 1, _cells.size()):
			var a := _cells[i]
			var b := _cells[j]
			if not _cells_can_match(a, b):
				continue
			var score := _hint_pair_score(a, b, strong_group_by_cell, weak_group_by_cell, false)
			if score < -999999.0:
				continue
			if score > best_score:
				best_score = score
				pairs.clear()
				pairs.append([a, b])
			elif is_equal_approx(score, best_score):
				pairs.append([a, b])
	return pairs


func _hint_pair_score(a: String, b: String, strong_group_by_cell: Dictionary, weak_group_by_cell: Dictionary, solution_pair: bool) -> float:
	var a_strong := int(strong_group_by_cell.get(a, -1))
	var b_strong := int(strong_group_by_cell.get(b, -2))
	if a_strong >= 0 and a_strong == b_strong:
		return -1000000.0
	var score := 0.0
	if solution_pair:
		score += 1000.0
	if _get_cell_tile(a).distance_squared_to(_get_cell_tile(b)) == 1:
		score += 45.0
	else:
		score += 90.0
	if a_strong >= 0 or b_strong >= 0:
		score += 220.0
	var a_weak := int(weak_group_by_cell.get(a, -1))
	var b_weak := int(weak_group_by_cell.get(b, -2))
	if a_weak >= 0 and b_weak >= 0 and a_weak != b_weak:
		score += 120.0
	elif a_weak != b_weak:
		score += 60.0
	if _pair_has_possible_swap(a, b):
		score += 100.0
	if _cells_can_match(a, b):
		score += 80.0
	score += _missing_need_score(a, _cell_produced_resource(b))
	score += _missing_need_score(b, _cell_produced_resource(a))
	return score


func _missing_need_score(cell: String, resource: String) -> float:
	if not _cell_needs_resource(cell, resource):
		return 0.0
	return (1.0 - _slot_fullness(cell, resource)) * 50.0


func _pair_has_possible_swap(a: String, b: String) -> bool:
	if not _using_csharp_sim:
		return _can_swap_pair(a, b)
	var possible_value: Variant = _sim_snapshot.get("possibleSwaps", [])
	if not possible_value is Array:
		return false
	var possible_swaps: Array = possible_value as Array
	for swap_value in possible_swaps:
		if not swap_value is Dictionary:
			continue
		var swap := swap_value as Dictionary
		var initiator := str(swap.get("initiator", ""))
		var counterparty := str(swap.get("counterparty", ""))
		if initiator == a and counterparty == b:
			return true
		if initiator == b and counterparty == a:
			return true
	return false


func _diagnostic_group_by_cell(group_key: String) -> Dictionary:
	var group_by_cell: Dictionary = {}
	if not _using_csharp_sim:
		return group_by_cell
	var diagnostics_value: Variant = _sim_snapshot.get("circuitDiagnostics", {})
	if not diagnostics_value is Dictionary:
		return group_by_cell
	var diagnostics: Dictionary = diagnostics_value as Dictionary
	var groups_value: Variant = diagnostics.get(group_key, [])
	if not groups_value is Array:
		return group_by_cell
	var groups: Array = groups_value as Array
	for group_index in range(groups.size()):
		var cells: Array = _strings_from_variant_array(groups[group_index])
		if group_key == "strongGroups" and cells.size() < 2:
			continue
		for cell_value in cells:
			group_by_cell[str(cell_value)] = group_index
	return group_by_cell


func _visual_cell_center(cell: String) -> Vector2:
	if cell == _drag_cell:
		return _drag_position
	return _tile_center(_get_cell_tile(cell))


func _clear_hint() -> void:
	_hint_pair.clear()
	_hint_text = ""
	_board_renderer_full_sync_needed = true


func _toggle_circuit_overlay() -> void:
	_circuit_overlay_enabled = not _circuit_overlay_enabled
	if is_instance_valid(_circuit_button):
		_circuit_button.text = "Circuit" if _circuit_overlay_enabled else "Circuit Off"
	_board_renderer_full_sync_needed = true
	queue_redraw()


func _count_met_needs() -> int:
	var count := 0
	for cell in _cells:
		for need in _needs.get(cell, []):
			if _using_csharp_sim:
				if _slot_fullness(cell, str(need)) > 0.0:
					count += 1
			elif _need_has_active_swap(cell, str(need)):
				count += 1
	return count


func _check_solution() -> void:
	if _using_csharp_sim:
		var was_solved := _solved
		_solved = bool(_sim_snapshot.get("won", false))
		if _solved and not was_solved and Global.has_method("record_cellular_puzzle_level_complete"):
			Global.record_cellular_puzzle_level_complete(_level_number)
		_update_level_text()
		return
	var all_met := true
	for cell in _cells:
		if not _cell_has_all_needs(cell):
			all_met = false
			break
	if all_met and not _solved:
		_solved = true
		if Global.has_method("record_cellular_puzzle_level_complete"):
			Global.record_cellular_puzzle_level_complete(_level_number)
	_update_level_text()


func _resource_color(resource: String) -> Color:
	var index := RESOURCE_LETTERS.find(resource)
	if index < 0:
		return Color(0.80, 0.86, 0.86, 1.0)
	return RESOURCE_COLORS[index % RESOURCE_COLORS.size()]


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _on_reset_pressed() -> void:
	_load_level(_level_number)
	queue_redraw()


func _on_last_pressed() -> void:
	var last_level := maxi(1, _level_number - 1)
	Global.cellular_puzzle_current_level = last_level
	_load_level(last_level)
	_layout_hud()
	queue_redraw()


func _on_hint_pressed() -> void:
	var pairs := _find_matching_pairs()
	if pairs.is_empty():
		_hint_pair.clear()
		_hint_text = "No missing solution connection found"
		_board_renderer_full_sync_needed = true
		_update_level_text()
		queue_redraw()
		return
	var pair: Array = pairs[_hint_cursor % pairs.size()]
	_hint_cursor += 1
	_hint_pair = [str(pair[0]), str(pair[1])]
	_hint_text = str("Hint: connect ", _cell_hint_mark(_hint_pair[0]), " with ", _cell_hint_mark(_hint_pair[1]))
	_board_renderer_full_sync_needed = true
	_update_level_text()
	queue_redraw()


func _cell_hint_mark(cell: String) -> String:
	var produced := _cell_produced_resource(cell)
	if not produced.is_empty():
		return produced
	return cell


func _on_next_pressed() -> void:
	var next_level := _level_number + 1
	Global.cellular_puzzle_current_level = next_level
	if next_level > Global.cellular_puzzle_highest_level:
		Global.cellular_puzzle_highest_level = next_level
		if Global.has_method("save_cellular_progress"):
			Global.save_cellular_progress()
	_load_level(next_level)
	_layout_hud()
	queue_redraw()
