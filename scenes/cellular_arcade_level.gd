extends Control

const ArcadeOverlayLayer = preload("res://scenes/cellular_arcade_overlay.gd")

const BOARD_COLS := 5
const BOARD_ROWS := 6
const BOARD_TILE_COUNT := BOARD_COLS * BOARD_ROWS
const INVENTORY_SLOT_COUNT := 3
const CLEAR_GROUP_MIN_SIZE := 4
const CLEAR_EFFECT_MAX_SCALE_COUNT := 10
const RESOURCE_LETTERS := ["A", "B", "C", "D", "E", "F", "G", "H"]
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
const RED_MYCO_INVENTORY_CHANCE := 15
const SOURCE_QUANTITY_PER_TICK := 32
const SOURCE_INTERVAL_TICKS := 1
const MAX_SWAP_QUANTITY_PER_EDGE := 8
const NORMAL_SLOT_CAPACITY := 100
const NEED_DESIRED_QUANTITY := 16
const NEED_OFFER_RESERVE := 4
const GLOW_TTL_TICKS := 200
const WIN_RECENT_FLOW_WINDOW_TICKS := 200
const SWAP_ROUNDS_PER_TICK := 4
const WIN_DURATION_TICKS := 3
const SIM_TICK_SECONDS := 0.12
const CLEAR_EFFECT_SECONDS := 0.88
const SCORE_PULSE_SECONDS := 0.72
const HIGH_SCORE_PULSE_SECONDS := 1.18
const HIGH_SCORE_SPARKLE_COUNT := 14
const INVENTORY_FRESH_SECONDS := 1.55
const INVENTORY_SLOT_SCALE := 1.28
const INVENTORY_CELL_SCALE := 1.10
const HINT_MISSING_CENTER := Vector2(-100000000.0, -100000000.0)
const DRAG_SOURCE_NONE := ""
const DRAG_SOURCE_BOARD := "board"
const DRAG_SOURCE_INVENTORY := "inventory"

var _rng := RandomNumberGenerator.new()
var _seeded := false
var _sim_bridge: Node = null
var _board_renderer: Node = null
var _overlay_layer: Control = null
var _using_board_renderer := false
var _using_csharp_sim := false
var _board_renderer_full_sync_needed := true
var _board_renderer_has_state := false
var _sim_snapshot: Dictionary = {}
var _cell_state_by_id: Dictionary = {}
var _sim_tick_accum := 0.0

var _board_cell_ids: Array[String] = []
var _board_cells: Dictionary = {}
var _inventory_cells: Array[Dictionary] = []
var _cell_sequence := 0
var _positions: Dictionary = {}
var _produced_by_cell: Dictionary = {}
var _cell_kind_by_id: Dictionary = {}
var _needs: Dictionary = {}
var _rocks: Dictionary = {}

var _board_rect := Rect2()
var _tile_size := 64.0
var _inventory_centers: Array[Vector2] = []
var _drag_source := DRAG_SOURCE_NONE
var _drag_cell_id := ""
var _drag_inventory_index := -1
var _drag_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _drag_original_tile := Vector2i.ZERO
var _drag_touch_id := -1

var _hint_button: Button = null
var _hint_pair: Array[String] = []
var _hint_cursor := 0
var _hint_text := ""
var _score := 0
var _game_over := false
var _full_board_pending_check := false
var _status_text := ""
var _clear_effect_ids: Array[String] = []
var _clear_effect_elapsed := 0.0
var _score_pulse_elapsed := SCORE_PULSE_SECONDS
var _high_score_pulse_elapsed := HIGH_SCORE_PULSE_SECONDS
var _high_score_sparkle_nonce := 0
var _inventory_fresh_start_msec_by_id: Dictionary = {}

var _menu_button: Button = null
var _restart_button: Button = null
var _score_label: Label = null
var _high_score_label: Label = null
var _fill_label: Label = null
var _status_label: Label = null
var _game_over_panel: Panel = null
var _game_over_title: Label = null
var _game_over_score_label: Label = null
var _game_over_restart_button: Button = null
var _game_over_menu_button: Button = null


func _ready() -> void:
	Global.reset_gameplay_speed()
	Global.mode = "arcade"
	Global.active_mode_id = "cellular_arcade"
	Global.active_scenario_id = "cellular_arcade"
	Global.score = 0
	_parse_arcade_args()
	if not _seeded:
		_rng.randomize()
	_sim_bridge = get_node_or_null("/root/CellularSim")
	_try_create_board_renderer()
	_create_overlay_layer()
	_create_hud()
	_start_run()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _game_over:
		return
	var score_pulse_active := _advance_score_pulse(delta)
	var high_score_pulse_active := _advance_high_score_pulse(delta)
	var inventory_fresh_active := _has_inventory_fresh_animation()
	var hud_pulse_active := score_pulse_active or high_score_pulse_active
	if _is_clear_effect_active():
		_clear_effect_elapsed += maxf(delta, 0.0)
		_board_renderer_full_sync_needed = true
		if _clear_effect_elapsed >= CLEAR_EFFECT_SECONDS:
			_finish_clear_effect()
		queue_redraw()
		return
	if _using_csharp_sim and _drag_source == DRAG_SOURCE_NONE:
		_sim_tick_accum += maxf(delta, 0.0)
		var ticked := false
		while _sim_tick_accum >= SIM_TICK_SECONDS:
			_sim_tick_accum -= SIM_TICK_SECONDS
			_sim_bridge.call("tick_many", 1)
			ticked = true
		if ticked:
			_refresh_sim_snapshot()
			var cleared := _clear_qualifying_groups()
			if not cleared and _full_board_pending_check and _is_board_full():
				_show_game_over()
			queue_redraw()
		elif hud_pulse_active or inventory_fresh_active:
			queue_redraw()
	elif _full_board_pending_check and _is_board_full():
		_show_game_over()
	elif _has_live_visual_animation() or hud_pulse_active or inventory_fresh_active:
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_scene()
		_board_renderer_full_sync_needed = true
		queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_H:
			_on_hint_pressed()
			get_viewport().set_input_as_handled()


func _parse_arcade_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arcade-seed="):
			_rng.seed = int(arg.trim_prefix("--arcade-seed="))
			_seeded = true


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
	_board_renderer.name = "CellularArcadeBoardRenderer"
	(_board_renderer as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_renderer)
	move_child(_board_renderer, 0)
	_using_board_renderer = true
	_board_renderer_full_sync_needed = true


func _create_overlay_layer() -> void:
	_overlay_layer = ArcadeOverlayLayer.new()
	_overlay_layer.name = "CellularArcadeOverlay"
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.arcade_owner = self
	add_child(_overlay_layer)


func _create_hud() -> void:
	_menu_button = Button.new()
	_menu_button.name = "MainMenuButton"
	_menu_button.text = "Main Menu"
	_menu_button.pressed.connect(_on_main_menu_pressed)
	add_child(_menu_button)

	_restart_button = Button.new()
	_restart_button.name = "RestartButton"
	_restart_button.text = "Restart"
	_restart_button.pressed.connect(_on_restart_pressed)
	add_child(_restart_button)

	_hint_button = Button.new()
	_hint_button.name = "HintButton"
	_hint_button.text = "Hint"
	_hint_button.pressed.connect(_on_hint_pressed)
	add_child(_hint_button)

	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_score_label)

	_high_score_label = Label.new()
	_high_score_label.name = "HighScoreLabel"
	_high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_high_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_high_score_label)

	_fill_label = Label.new()
	_fill_label.name = "FillLabel"
	_fill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_fill_label)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_status_label)

	_game_over_panel = Panel.new()
	_game_over_panel.name = "GameOverPanel"
	_game_over_panel.visible = false
	_game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_game_over_panel)

	_game_over_title = Label.new()
	_game_over_title.name = "GameOverTitle"
	_game_over_title.text = "Game Over"
	_game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_panel.add_child(_game_over_title)

	_game_over_score_label = Label.new()
	_game_over_score_label.name = "GameOverScoreLabel"
	_game_over_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_panel.add_child(_game_over_score_label)

	_game_over_restart_button = Button.new()
	_game_over_restart_button.name = "GameOverRestartButton"
	_game_over_restart_button.text = "Restart"
	_game_over_restart_button.pressed.connect(_on_restart_pressed)
	_game_over_panel.add_child(_game_over_restart_button)

	_game_over_menu_button = Button.new()
	_game_over_menu_button.name = "GameOverMainMenuButton"
	_game_over_menu_button.text = "Main Menu"
	_game_over_menu_button.pressed.connect(_on_main_menu_pressed)
	_game_over_panel.add_child(_game_over_menu_button)
	_layout_scene()


func _start_run() -> void:
	_board_cell_ids.clear()
	_board_cells.clear()
	_inventory_cells.clear()
	_inventory_fresh_start_msec_by_id.clear()
	_positions.clear()
	_produced_by_cell.clear()
	_cell_kind_by_id.clear()
	_needs.clear()
	_rocks.clear()
	_sim_snapshot.clear()
	_cell_state_by_id.clear()
	_cell_sequence = 0
	_score = 0
	Global.score = 0
	_game_over = false
	_full_board_pending_check = false
	_hint_pair.clear()
	_hint_cursor = 0
	_hint_text = ""
	_status_text = ""
	_clear_effect_ids.clear()
	_clear_effect_elapsed = 0.0
	_score_pulse_elapsed = SCORE_PULSE_SECONDS
	_high_score_pulse_elapsed = HIGH_SCORE_PULSE_SECONDS
	_reset_score_pulse_visual()
	_reset_high_score_pulse_visual()
	if is_instance_valid(_game_over_panel):
		_game_over_panel.visible = false

	var first_cell := _make_arcade_cell()
	_add_cell_to_board(first_cell, _random_empty_center_board_tile())
	for index in range(INVENTORY_SLOT_COUNT):
		var inventory_cell := _make_inventory_cell()
		_inventory_cells.append(inventory_cell)
		_mark_inventory_cell_fresh(inventory_cell)
	_reload_sim_from_board()
	_update_hud_text()
	_layout_scene()
	queue_redraw()


func _make_arcade_cell(use_inventory_context: bool = false, ignored_inventory_index: int = -1) -> Dictionary:
	_cell_sequence += 1
	var produced := _choose_produced_resource(use_inventory_context, ignored_inventory_index)
	return {
		"id": "arcade-cell-%04d" % _cell_sequence,
		"kind": "Standard",
		"produced": produced,
		"needs": _choose_needs_for_resource(produced, use_inventory_context, ignored_inventory_index)
	}


func _make_inventory_cell(ignored_inventory_index: int = -1) -> Dictionary:
	if not _inventory_has_red_myco(ignored_inventory_index) and _rng.randi_range(1, RED_MYCO_INVENTORY_CHANCE) == 1:
		return _make_red_myco_cell(ignored_inventory_index)
	return _make_arcade_cell(true, ignored_inventory_index)


func _make_red_myco_cell(ignored_inventory_index: int = -1) -> Dictionary:
	_cell_sequence += 1
	return {
		"id": "arcade-red-myco-%04d" % _cell_sequence,
		"kind": "RedMyco",
		"produced": "",
		"needs": []
	}


func _mark_inventory_cell_fresh(cell: Dictionary) -> void:
	var id := str(cell.get("id", ""))
	if id.is_empty():
		return
	_inventory_fresh_start_msec_by_id[id] = Time.get_ticks_msec()
	_board_renderer_full_sync_needed = true


func _inventory_has_red_myco(ignored_inventory_index: int = -1) -> bool:
	for index in range(_inventory_cells.size()):
		if index == ignored_inventory_index:
			continue
		var cell: Dictionary = _inventory_cells[index]
		if str(cell.get("kind", "Standard")) == "RedMyco":
			return true
	return false


func _choose_produced_resource(use_inventory_context: bool = false, ignored_inventory_index: int = -1) -> String:
	var weighted: Array[String] = []
	var blocked_inventory_sources: Array[String] = []
	if use_inventory_context:
		blocked_inventory_sources = _inventory_produced_resources(ignored_inventory_index)
	var zero_needs := _zero_quantity_board_needs()
	for resource in zero_needs:
		_append_weighted(weighted, str(resource), 8)
	for resource in _unprovided_board_needs():
		_append_weighted(weighted, str(resource), 6)
	for resource in _board_needed_resources():
		_append_weighted(weighted, str(resource), 4)
	if use_inventory_context:
		for resource in _inventory_needed_resources(ignored_inventory_index):
			_append_weighted(weighted, str(resource), 1)
	for resource in RESOURCE_LETTERS:
		_append_weighted(weighted, str(resource), 1)
	if use_inventory_context and not blocked_inventory_sources.is_empty():
		weighted = _filter_blocked_resources(weighted, blocked_inventory_sources)
		if weighted.is_empty():
			for resource in RESOURCE_LETTERS:
				if not blocked_inventory_sources.has(resource):
					weighted.append(resource)
	return _weighted_resource_choice(weighted, "")


func _choose_needs_for_resource(produced: String, use_inventory_context: bool = false, ignored_inventory_index: int = -1) -> Array[String]:
	var needs: Array[String] = []
	var weighted: Array[String] = []
	for resource in _board_produced_resources():
		if resource != produced:
			_append_weighted(weighted, resource, 7)
	for resource in _board_needed_resources():
		if resource != produced:
			_append_weighted(weighted, resource, 2)
	if use_inventory_context:
		for resource in _inventory_produced_resources(ignored_inventory_index):
			if resource != produced:
				_append_weighted(weighted, resource, 2)
		for resource in _inventory_needed_resources(ignored_inventory_index):
			if resource != produced:
				_append_weighted(weighted, resource, 1)
	for resource in RESOURCE_LETTERS:
		if resource != produced:
			_append_weighted(weighted, resource, 1)
	while needs.size() < 3:
		var next := _weighted_resource_choice(weighted, produced)
		if next.is_empty():
			break
		if next != produced and not needs.has(next):
			needs.append(next)
		else:
			weighted.erase(next)
		if weighted.is_empty():
			for resource in RESOURCE_LETTERS:
				if resource != produced and not needs.has(resource):
					weighted.append(resource)
	if needs.size() < 3:
		for resource in RESOURCE_LETTERS:
			if resource != produced and not needs.has(resource):
				needs.append(resource)
			if needs.size() >= 3:
				break
	return needs


func _choose_red_myco_needs(ignored_inventory_index: int = -1) -> Array[String]:
	var needs: Array[String] = []
	var weighted: Array[String] = []
	for resource in _board_produced_resources():
		_append_weighted(weighted, resource, 7)
	for resource in _board_needed_resources():
		_append_weighted(weighted, resource, 2)
	for resource in _inventory_produced_resources(ignored_inventory_index):
		_append_weighted(weighted, resource, 2)
	for resource in _inventory_needed_resources(ignored_inventory_index):
		_append_weighted(weighted, resource, 1)
	for resource in RESOURCE_LETTERS:
		_append_weighted(weighted, resource, 1)
	while needs.size() < 4:
		var next := _weighted_resource_choice(weighted, "")
		if next.is_empty():
			break
		if not needs.has(next):
			needs.append(next)
		else:
			weighted.erase(next)
		if weighted.is_empty():
			for resource in RESOURCE_LETTERS:
				if not needs.has(resource):
					weighted.append(resource)
	if needs.size() < 4:
		for resource in RESOURCE_LETTERS:
			if not needs.has(resource):
				needs.append(resource)
			if needs.size() >= 4:
				break
	return needs


func _append_weighted(target: Array[String], resource: String, count: int) -> void:
	if resource.is_empty():
		return
	for _i in range(maxi(1, count)):
		target.append(resource)


func _weighted_resource_choice(weighted: Array[String], excluded: String) -> String:
	var candidates: Array[String] = []
	for resource in weighted:
		var value := str(resource)
		if not value.is_empty() and value != excluded:
			candidates.append(value)
	if candidates.is_empty():
		return ""
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _filter_blocked_resources(weighted: Array[String], blocked: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	for resource in weighted:
		var value := str(resource)
		if not value.is_empty() and not blocked.has(value):
			filtered.append(value)
	return filtered


func _board_produced_resources() -> Array[String]:
	var resources: Array[String] = []
	for id in _board_cell_ids:
		var cell: Dictionary = _board_cells.get(id, {})
		var resource := str(cell.get("produced", ""))
		if not resource.is_empty() and not resources.has(resource):
			resources.append(resource)
	return resources


func _board_needed_resources() -> Array[String]:
	var resources: Array[String] = []
	for id in _board_cell_ids:
		var cell: Dictionary = _board_cells.get(id, {})
		var needs_value: Variant = cell.get("needs", [])
		if needs_value is Array:
			for need in needs_value:
				var resource := str(need)
				if not resource.is_empty() and not resources.has(resource):
					resources.append(resource)
	return resources


func _inventory_produced_resources(ignored_inventory_index: int = -1) -> Array[String]:
	var resources: Array[String] = []
	for index in range(_inventory_cells.size()):
		if index == ignored_inventory_index:
			continue
		var cell: Dictionary = _inventory_cells[index]
		var resource := str(cell.get("produced", ""))
		if not resource.is_empty() and not resources.has(resource):
			resources.append(resource)
	return resources


func _inventory_needed_resources(ignored_inventory_index: int = -1) -> Array[String]:
	var resources: Array[String] = []
	for index in range(_inventory_cells.size()):
		if index == ignored_inventory_index:
			continue
		var cell: Dictionary = _inventory_cells[index]
		var needs_value: Variant = cell.get("needs", [])
		if needs_value is Array:
			for need in needs_value:
				var resource := str(need)
				if not resource.is_empty() and not resources.has(resource):
					resources.append(resource)
	return resources


func _unprovided_board_needs() -> Array[String]:
	var produced := _board_produced_resources()
	var unprovided: Array[String] = []
	for resource in _board_needed_resources():
		if not produced.has(resource) and not unprovided.has(resource):
			unprovided.append(resource)
	return unprovided


func _zero_quantity_board_needs() -> Array[String]:
	var resources: Array[String] = []
	var cells_value: Variant = _sim_snapshot.get("cells", [])
	if not cells_value is Array:
		return resources
	for cell_value in cells_value:
		if not cell_value is Dictionary:
			continue
		var cell := cell_value as Dictionary
		var slots_value: Variant = cell.get("slots", [])
		if not slots_value is Array:
			continue
		for slot_value in slots_value:
			if not slot_value is Dictionary:
				continue
			var slot := slot_value as Dictionary
			if str(slot.get("role", "")) != "Need":
				continue
			if int(slot.get("quantity", 0)) > 0:
				continue
			var resource := str(slot.get("resource", ""))
			if not resource.is_empty() and not resources.has(resource):
				resources.append(resource)
	return resources


func _add_cell_to_board(cell: Dictionary, tile: Vector2i) -> void:
	var id := str(cell.get("id", ""))
	if id.is_empty():
		return
	cell["x"] = tile.x
	cell["y"] = tile.y
	_board_cells[id] = cell
	if not _board_cell_ids.has(id):
		_board_cell_ids.append(id)
	_refresh_visual_model_from_board()


func _remove_cells_from_board(ids: Array[String]) -> void:
	for id in ids:
		_board_cells.erase(id)
		_board_cell_ids.erase(id)
	_refresh_visual_model_from_board()


func _refresh_visual_model_from_board() -> void:
	_positions.clear()
	_produced_by_cell.clear()
	_cell_kind_by_id.clear()
	_needs.clear()
	for id in _board_cell_ids:
		var cell: Dictionary = _board_cells.get(id, {})
		_positions[id] = Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0)))
		_produced_by_cell[id] = str(cell.get("produced", ""))
		_cell_kind_by_id[id] = str(cell.get("kind", "Standard"))
		var cell_needs: Array[String] = []
		var needs_value: Variant = cell.get("needs", [])
		if needs_value is Array:
			for need in needs_value:
				cell_needs.append(str(need))
		_needs[id] = cell_needs
	_board_renderer_full_sync_needed = true


func _reload_sim_from_board() -> void:
	_refresh_visual_model_from_board()
	_sim_tick_accum = 0.0
	_using_csharp_sim = false
	_sim_snapshot.clear()
	_cell_state_by_id.clear()
	_full_board_pending_check = _is_board_full()
	if _board_cell_ids.is_empty():
		_status_text = ""
		_board_renderer_full_sync_needed = true
		return
	if not is_instance_valid(_sim_bridge):
		_status_text = "C# sim bridge unavailable"
		return
	var fixture_json := JSON.stringify(_build_fixture_document())
	var loaded_value: Variant = _sim_bridge.call("load_fixture_json", fixture_json)
	_using_csharp_sim = bool(loaded_value)
	if not _using_csharp_sim:
		var error_value: Variant = _sim_bridge.call("get_last_error")
		_status_text = str(error_value)
		push_warning("Cellular arcade C# sim bridge failed to load fixture: %s" % _status_text)
		return
	_status_text = ""
	_refresh_sim_snapshot()
	_full_board_pending_check = _is_board_full()


func _build_fixture_document() -> Dictionary:
	var cells: Array = []
	var required_cells: Array = []
	for id in _board_cell_ids:
		var cell: Dictionary = _board_cells.get(id, {})
		var produced := str(cell.get("produced", ""))
		var kind := str(cell.get("kind", "Standard"))
		var slots: Array = []
		var sources: Array = []
		if kind != "RedMyco":
			slots.append({
				"resource": produced,
				"role": "SourceOutput",
				"quantity": 0,
				"capacity": NORMAL_SLOT_CAPACITY
			})
			sources.append({
				"resource": produced,
				"quantityPerTick": SOURCE_QUANTITY_PER_TICK,
				"intervalTicks": SOURCE_INTERVAL_TICKS
			})
		var needs_value: Variant = cell.get("needs", [])
		if kind != "RedMyco" and needs_value is Array:
			for need in needs_value:
				slots.append({
					"resource": str(need),
					"role": "Need",
					"quantity": 0,
					"capacity": NORMAL_SLOT_CAPACITY
				})
		var cell_doc := {
			"id": id,
			"x": int(cell.get("x", 0)),
			"y": int(cell.get("y", 0)),
			"slots": slots,
			"sources": sources
		}
		if kind != "Standard":
			cell_doc["kind"] = kind
		cells.append(cell_doc)
		required_cells.append(id)
	return {
		"resources": RESOURCE_LETTERS,
		"grid": {
			"width": BOARD_COLS,
			"height": BOARD_ROWS,
			"rocks": []
		},
		"engine": {
			"glowTtlTicks": GLOW_TTL_TICKS,
			"winRecentFlowWindowTicks": WIN_RECENT_FLOW_WINDOW_TICKS,
			"swapRoundsPerTick": SWAP_ROUNDS_PER_TICK,
			"maxSwapQuantityPerEdge": MAX_SWAP_QUANTITY_PER_EDGE,
			"needDesiredQuantity": NEED_DESIRED_QUANTITY,
			"needOfferReserve": NEED_OFFER_RESERVE,
			"allowNeedOverflowPayments": true
		},
		"cells": cells,
		"win": {
			"requiredCells": required_cells,
			"requiredResources": [],
			"durationTicks": WIN_DURATION_TICKS
		}
	}


func _refresh_sim_snapshot() -> void:
	if not is_instance_valid(_sim_bridge):
		return
	var snapshot_value: Variant = _sim_bridge.call("get_snapshot")
	if not snapshot_value is Dictionary:
		return
	_sim_snapshot = snapshot_value as Dictionary
	_cell_state_by_id.clear()
	var cells_value: Variant = _sim_snapshot.get("cells", [])
	if cells_value is Array:
		for cell_value in cells_value:
			if cell_value is Dictionary:
				var cell := cell_value as Dictionary
				var id := str(cell.get("id", ""))
				_cell_state_by_id[id] = cell
				var kind := str(cell.get("kind", "Standard"))
				if kind == "RedMyco" and _board_cells.has(id):
					var adapted_needs: Array[String] = []
					var slots_value: Variant = cell.get("slots", [])
					if slots_value is Array:
						for slot_value in slots_value:
							if not slot_value is Dictionary:
								continue
							var slot_doc := slot_value as Dictionary
							if str(slot_doc.get("role", "")) == "Need":
								adapted_needs.append(str(slot_doc.get("resource", "")))
					var board_cell := _board_cells.get(id, {}) as Dictionary
					board_cell["needs"] = adapted_needs
					_board_cells[id] = board_cell
	_board_renderer_full_sync_needed = true


func _clear_qualifying_groups() -> bool:
	if _is_clear_effect_active():
		return true
	var groups := _clearable_groups_from_snapshot()
	if groups.is_empty():
		return false
	var clear_ids: Array[String] = []
	for group in groups:
		for id in group:
			if not clear_ids.has(id):
				clear_ids.append(id)
	if clear_ids.is_empty():
		return false
	var cleared_count := clear_ids.size()
	var points := cleared_count + maxi(0, cleared_count - CLEAR_GROUP_MIN_SIZE)
	var previous_high_score := int(Global.high_score)
	_score += points
	Global.add_score(points)
	if _score > previous_high_score and int(Global.high_score) > previous_high_score:
		_start_high_score_pulse()
	_status_text = str("Amazing! ", cleared_count, "-Cells Cleared!")
	_clear_hint(false)
	_start_clear_effect(clear_ids)
	_update_hud_text()
	queue_redraw()
	return true


func _start_clear_effect(clear_ids: Array[String]) -> void:
	_clear_effect_ids.clear()
	for id in clear_ids:
		_clear_effect_ids.append(id)
	_clear_effect_elapsed = 0.0
	_score_pulse_elapsed = 0.0
	_apply_score_pulse_visual()
	_board_renderer_full_sync_needed = true


func _finish_clear_effect() -> void:
	if _clear_effect_ids.is_empty():
		return
	var clear_ids: Array[String] = []
	for id in _clear_effect_ids:
		clear_ids.append(id)
	_clear_effect_ids.clear()
	_clear_effect_elapsed = 0.0
	_remove_cells_from_board(clear_ids)
	_reload_sim_from_board()
	for index in range(INVENTORY_SLOT_COUNT):
		if index >= _inventory_cells.size():
			_inventory_cells.append(_make_inventory_cell())
	_full_board_pending_check = false
	_update_hud_text()
	_board_renderer_full_sync_needed = true


func _is_clear_effect_active() -> bool:
	return not _clear_effect_ids.is_empty()


func _clear_effect_progress() -> float:
	if not _is_clear_effect_active():
		return 1.0
	return clampf(_clear_effect_elapsed / CLEAR_EFFECT_SECONDS, 0.0, 1.0)


func _clear_effect_scale() -> float:
	if not _is_clear_effect_active():
		return 1.0
	var capped_count := clampi(_clear_effect_ids.size(), CLEAR_GROUP_MIN_SIZE, CLEAR_EFFECT_MAX_SCALE_COUNT)
	var denominator := maxi(1, CLEAR_EFFECT_MAX_SCALE_COUNT - CLEAR_GROUP_MIN_SIZE)
	var amount := float(capped_count - CLEAR_GROUP_MIN_SIZE) / float(denominator)
	return lerpf(1.0, 1.85, amount)


func _clearable_groups_from_snapshot() -> Array:
	var result: Array = []
	var diagnostics_value: Variant = _sim_snapshot.get("circuitDiagnostics", {})
	if not diagnostics_value is Dictionary:
		return result
	var diagnostics := diagnostics_value as Dictionary
	var groups_value: Variant = diagnostics.get("strongGroups", [])
	if not groups_value is Array:
		return result
	var glowing := _glowing_cell_lookup()
	for group_value in groups_value:
		var ids := _strings_from_variant_array(group_value)
		if ids.size() < CLEAR_GROUP_MIN_SIZE:
			continue
		var glowing_board_ids: Array[String] = []
		for id in ids:
			if not _board_cells.has(id):
				continue
			if not bool(glowing.get(id, false)):
				continue
			glowing_board_ids.append(id)
		if glowing_board_ids.size() < CLEAR_GROUP_MIN_SIZE:
			continue
		for subgroup in _connected_board_subgroups(glowing_board_ids):
			if subgroup.size() >= CLEAR_GROUP_MIN_SIZE:
				result.append(subgroup)
	return result


func _connected_board_subgroups(ids: Array[String]) -> Array:
	var result: Array = []
	var remaining := {}
	for id in ids:
		remaining[id] = true
	while not remaining.is_empty():
		var start := ""
		for key in remaining.keys():
			start = str(key)
			break
		if start.is_empty():
			break
		remaining.erase(start)
		var component: Array[String] = []
		var queue: Array[String] = [start]
		var index := 0
		while index < queue.size():
			var current := queue[index]
			index += 1
			component.append(current)
			var current_tile := _get_cell_tile(current)
			for key in remaining.keys():
				var other := str(key)
				if current_tile.distance_squared_to(_get_cell_tile(other)) != 1:
					continue
				remaining.erase(other)
				queue.append(other)
		result.append(component)
	return result


func _glowing_cell_lookup() -> Dictionary:
	var glowing := {}
	var cells_value: Variant = _sim_snapshot.get("cells", [])
	if not cells_value is Array:
		return glowing
	for cell_value in cells_value:
		if cell_value is Dictionary:
			var cell := cell_value as Dictionary
			glowing[str(cell.get("id", ""))] = bool(cell.get("glowing", false))
	return glowing


func _strings_from_variant_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var array_value: Array = value as Array
	for item in array_value:
		result.append(str(item))
	return result


func _show_game_over() -> void:
	if _game_over:
		return
	_game_over = true
	Global.record_last_score(_score)
	_update_hud_text()
	if is_instance_valid(_game_over_panel):
		_game_over_panel.visible = true
		move_child(_game_over_panel, get_child_count() - 1)
	_layout_scene()
	queue_redraw()


func _is_board_full() -> bool:
	return _board_cell_ids.size() >= BOARD_TILE_COUNT


func _random_empty_board_tile() -> Vector2i:
	var empty_tiles: Array[Vector2i] = []
	for y in range(BOARD_ROWS):
		for x in range(BOARD_COLS):
			var tile := Vector2i(x, y)
			if _is_tile_empty(tile):
				empty_tiles.append(tile)
	if empty_tiles.is_empty():
		return Vector2i(-1, -1)
	return empty_tiles[_rng.randi_range(0, empty_tiles.size() - 1)]


func _random_empty_center_board_tile() -> Vector2i:
	var center_tiles: Array[Vector2i] = []
	var min_x := int(floor(float(BOARD_COLS - 1) * 0.5))
	var max_x := int(ceil(float(BOARD_COLS - 1) * 0.5))
	var min_y := int(floor(float(BOARD_ROWS - 1) * 0.5))
	var max_y := int(ceil(float(BOARD_ROWS - 1) * 0.5))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var tile := Vector2i(x, y)
			if _is_tile_inside(tile) and _is_tile_empty(tile):
				center_tiles.append(tile)
	if center_tiles.is_empty():
		return _random_empty_board_tile()
	return center_tiles[_rng.randi_range(0, center_tiles.size() - 1)]


func _layout_scene() -> void:
	var view_size := get_viewport_rect().size
	var safe_rect := _get_arcade_padded_safe_view_rect()
	if safe_rect.size.x <= 1.0 or safe_rect.size.y <= 1.0:
		safe_rect = Rect2(Vector2.ZERO, view_size).grow(-4.0)
	var short_edge := minf(safe_rect.size.x, safe_rect.size.y)
	var margin := _get_arcade_safe_edge_margin()
	var portrait := safe_rect.size.y >= safe_rect.size.x
	var compact_hud := portrait or safe_rect.size.x < 760.0 or short_edge < 620.0
	var top_h := 96.0 if compact_hud else 68.0
	var inventory_gap_factor := 0.22
	var inventory_h_factor := INVENTORY_SLOT_SCALE + 0.10
	var play_bottom_padding := maxf(2.0, margin * 0.35)
	var playable_h := maxf(1.0, safe_rect.size.y - top_h - play_bottom_padding)
	var combined_h_denominator := float(BOARD_ROWS) + inventory_gap_factor + inventory_h_factor
	var tile_by_w := maxf(28.0, (safe_rect.size.x - margin * 0.20) / float(BOARD_COLS))
	var tile_by_h := maxf(28.0, playable_h / combined_h_denominator)
	var max_tile := 176.0 if compact_hud else 190.0
	_tile_size = floorf(clampf(minf(tile_by_w, tile_by_h), 30.0, max_tile))
	var board_size := Vector2(_tile_size * BOARD_COLS, _tile_size * BOARD_ROWS)
	var inventory_gap := _tile_size * inventory_gap_factor
	var inventory_h := _tile_size * inventory_h_factor
	var total_play_h := board_size.y + inventory_gap + inventory_h
	var spare_play_h := maxf(0.0, playable_h - total_play_h)
	var play_top: float = safe_rect.position.y + top_h + round(spare_play_h * 0.16)
	var board_x: float = roundf(safe_rect.position.x + (safe_rect.size.x - board_size.x) * 0.5)
	_board_rect = Rect2(Vector2(board_x, roundf(play_top)), board_size)

	_inventory_centers.clear()
	var inv_y := _board_rect.position.y + _board_rect.size.y + inventory_gap + inventory_h * 0.5
	var hint_w := 70.0 if compact_hud else 78.0
	var hint_h := 42.0
	var slot_size := _tile_size * INVENTORY_SLOT_SCALE
	var slot_gap := _tile_size * (INVENTORY_SLOT_SCALE + 0.12)
	var row_available_w := maxf(1.0, safe_rect.size.x - margin * 2.0)
	var row_gap := maxf(8.0, _tile_size * 0.08)
	var fit_slot_gap := (row_available_w - hint_w - row_gap - slot_size) / maxf(1.0, float(INVENTORY_SLOT_COUNT - 1))
	if fit_slot_gap >= slot_size:
		slot_gap = clampf(minf(slot_gap, fit_slot_gap), slot_size, _tile_size * (INVENTORY_SLOT_SCALE + 0.12))
	else:
		slot_gap = maxf(_tile_size * 0.90, fit_slot_gap)
	var row_width := hint_w + row_gap + slot_size + slot_gap * float(INVENTORY_SLOT_COUNT - 1)
	var row_left := _board_rect.position.x + _board_rect.size.x * 0.5 - row_width * 0.5
	var min_row_left := safe_rect.position.x + margin
	var max_row_left := safe_rect.position.x + safe_rect.size.x - margin - row_width
	row_left = clampf(row_left, min_row_left, maxf(min_row_left, max_row_left))
	var slots_start_x := row_left + hint_w + row_gap + slot_size * 0.5
	for index in range(INVENTORY_SLOT_COUNT):
		_inventory_centers.append(Vector2(slots_start_x + float(index) * slot_gap, inv_y))

	var menu_w := 96.0 if compact_hud else 118.0
	var restart_w := 88.0 if compact_hud else 102.0
	_set_control_rect(_menu_button, safe_rect.position + Vector2(margin, 0.0), Vector2(menu_w, 42.0))
	_set_control_rect(_hint_button, Vector2(row_left, inv_y - hint_h * 0.5), Vector2(hint_w, hint_h))
	_set_control_rect(_restart_button, Vector2(safe_rect.position.x + safe_rect.size.x - margin - restart_w, safe_rect.position.y), Vector2(restart_w, 42.0))
	if is_instance_valid(_fill_label):
		_fill_label.visible = false
	if compact_hud:
		_set_control_rect(_score_label, safe_rect.position + Vector2(margin, 42.0), Vector2(safe_rect.size.x - margin * 2.0, 28.0))
		_set_control_rect(_high_score_label, safe_rect.position + Vector2(margin, 68.0), Vector2(safe_rect.size.x - margin * 2.0, 24.0))
		_set_control_rect(_status_label, safe_rect.position + Vector2(margin, 90.0), Vector2(safe_rect.size.x - margin * 2.0, 20.0))
	else:
		var center_left := safe_rect.position.x + margin + menu_w + 18.0
		var center_right := safe_rect.position.x + safe_rect.size.x - margin - restart_w - 10.0
		var center_w := maxf(1.0, center_right - center_left)
		var stat_gap := 10.0
		var stat_w := maxf(90.0, (center_w - stat_gap) * 0.5)
		_set_control_rect(_score_label, Vector2(center_left, safe_rect.position.y), Vector2(stat_w, 42.0))
		_set_control_rect(_high_score_label, Vector2(center_left + stat_w + stat_gap, safe_rect.position.y), Vector2(maxf(90.0, center_w - stat_w - stat_gap), 42.0))
		_set_control_rect(_status_label, safe_rect.position + Vector2(margin, 42.0), Vector2(safe_rect.size.x - margin * 2.0, 24.0))
	_style_hud()

	if is_instance_valid(_overlay_layer):
		_set_control_rect(_overlay_layer, Vector2.ZERO, view_size)
	if is_instance_valid(_board_renderer) and _board_renderer is Control:
		var renderer_control := _board_renderer as Control
		_set_control_rect(renderer_control, Vector2.ZERO, view_size)
	_board_renderer_full_sync_needed = true
	_layout_game_over_panel(view_size)
	_update_hud_text()


func _layout_game_over_panel(view_size: Vector2) -> void:
	if not is_instance_valid(_game_over_panel):
		return
	var panel_size := Vector2(minf(360.0, view_size.x - 32.0), 230.0)
	var panel_pos := (view_size - panel_size) * 0.5
	_set_control_rect(_game_over_panel, panel_pos, panel_size)
	_game_over_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.07, 0.08, 0.94), Color(0.45, 1.0, 0.82, 0.84), 3, 8))
	_set_control_rect(_game_over_title, Vector2(18.0, 20.0), Vector2(panel_size.x - 36.0, 50.0))
	_set_control_rect(_game_over_score_label, Vector2(18.0, 78.0), Vector2(panel_size.x - 36.0, 50.0))
	var button_w := (panel_size.x - 52.0) * 0.5
	_set_control_rect(_game_over_restart_button, Vector2(18.0, 154.0), Vector2(button_w, 48.0))
	_set_control_rect(_game_over_menu_button, Vector2(34.0 + button_w, 154.0), Vector2(button_w, 48.0))
	_style_button(_game_over_restart_button)
	_style_button(_game_over_menu_button)
	_style_label(_game_over_title, 31, Color(0.88, 1.0, 0.96, 1.0))
	_style_label(_game_over_score_label, 20, Color(0.78, 0.95, 0.92, 1.0))


func _get_arcade_safe_edge_margin() -> float:
	var view_size := get_viewport_rect().size
	var short_edge := minf(view_size.x, view_size.y)
	if short_edge < 520.0:
		return 3.0
	if short_edge < 760.0:
		return 4.0
	return 6.0


func _get_arcade_safe_view_rect() -> Rect2:
	var view_rect := get_viewport_rect()
	if not Global.is_mobile_platform:
		return view_rect
	var window_size_i := DisplayServer.window_get_size()
	var window_size := Vector2(window_size_i)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return view_rect
	var safe_area_i := DisplayServer.get_display_safe_area()
	var safe_area := Rect2(Vector2(safe_area_i.position), Vector2(safe_area_i.size))
	if safe_area.size.x <= 0.0 or safe_area.size.y <= 0.0:
		return view_rect
	var scale := Vector2(view_rect.size.x / window_size.x, view_rect.size.y / window_size.y)
	var safe_pos := view_rect.position + safe_area.position * scale
	var safe_size := safe_area.size * scale
	var safe_left := clampf(safe_pos.x, view_rect.position.x, view_rect.position.x + view_rect.size.x)
	var safe_top := clampf(safe_pos.y, view_rect.position.y, view_rect.position.y + view_rect.size.y)
	var safe_right := clampf(safe_pos.x + safe_size.x, view_rect.position.x, view_rect.position.x + view_rect.size.x)
	var safe_bottom := clampf(safe_pos.y + safe_size.y, view_rect.position.y, view_rect.position.y + view_rect.size.y)
	if safe_right - safe_left <= 1.0 or safe_bottom - safe_top <= 1.0:
		return view_rect
	return Rect2(Vector2(safe_left, safe_top), Vector2(safe_right - safe_left, safe_bottom - safe_top))


func _get_arcade_padded_safe_view_rect(extra_margin: float = 0.0) -> Rect2:
	var safe_rect := _get_arcade_safe_view_rect()
	var margin := maxf(_get_arcade_safe_edge_margin() + extra_margin, 0.0)
	var padded := safe_rect.grow(-margin)
	if padded.size.x <= 1.0 or padded.size.y <= 1.0:
		return safe_rect
	return padded


func _style_hud() -> void:
	_style_button(_menu_button)
	_style_button(_hint_button)
	_style_button(_restart_button)
	_style_label(_score_label, 22, Color(0.88, 1.0, 0.96, 1.0))
	_style_label(_high_score_label, 18, Color(0.78, 0.94, 1.0, 1.0))
	_style_label(_fill_label, 15, Color(0.78, 0.94, 1.0, 1.0))
	_style_label(_status_label, 15, Color(1.0, 0.84, 0.54, 1.0))


func _style_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.custom_minimum_size = Vector2(46.0, 42.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.92, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.36, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.04, 0.06, 0.045, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.03, 0.92))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.045, 0.085, 0.085, 0.94), Color(0.36, 0.92, 0.76, 0.54), 2, 8))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.065, 0.13, 0.12, 0.98), Color(0.78, 1.0, 0.70, 0.88), 2, 8))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.98, 0.78, 0.20, 0.98), Color(1.0, 0.96, 0.48, 1.0), 2, 8))


func _style_label(label: Label, font_size: int, color: Color) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.03, 0.95))
	label.add_theme_constant_override("outline_size", 3)


func _advance_score_pulse(delta: float) -> bool:
	if _score_pulse_elapsed >= SCORE_PULSE_SECONDS:
		_reset_score_pulse_visual()
		return false
	_score_pulse_elapsed = minf(SCORE_PULSE_SECONDS, _score_pulse_elapsed + maxf(delta, 0.0))
	_apply_score_pulse_visual()
	return true


func _apply_score_pulse_visual() -> void:
	if not is_instance_valid(_score_label):
		return
	var progress := clampf(_score_pulse_elapsed / SCORE_PULSE_SECONDS, 0.0, 1.0)
	var pulse := sin(progress * PI)
	var scale := 1.0 + pulse * 0.46
	_score_label.pivot_offset = _score_label.size * 0.5
	_score_label.scale = Vector2(scale, scale)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.90 + pulse * 0.10, 0.32, 1.0).lerp(Color(0.88, 1.0, 0.96, 1.0), progress))
	_score_label.add_theme_constant_override("outline_size", 4 + int(roundf(pulse * 4.0)))


func _reset_score_pulse_visual() -> void:
	if not is_instance_valid(_score_label):
		return
	_score_label.scale = Vector2.ONE
	_score_label.pivot_offset = _score_label.size * 0.5
	_score_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.96, 1.0))
	_score_label.add_theme_constant_override("outline_size", 3)


func _start_high_score_pulse() -> void:
	_high_score_pulse_elapsed = 0.0
	_high_score_sparkle_nonce += 1
	_apply_high_score_pulse_visual()


func _advance_high_score_pulse(delta: float) -> bool:
	if _high_score_pulse_elapsed >= HIGH_SCORE_PULSE_SECONDS:
		_reset_high_score_pulse_visual()
		return false
	_high_score_pulse_elapsed = minf(HIGH_SCORE_PULSE_SECONDS, _high_score_pulse_elapsed + maxf(delta, 0.0))
	_apply_high_score_pulse_visual()
	return true


func _high_score_pulse_progress() -> float:
	return clampf(_high_score_pulse_elapsed / HIGH_SCORE_PULSE_SECONDS, 0.0, 1.0)


func _is_high_score_pulse_active() -> bool:
	return _high_score_pulse_elapsed < HIGH_SCORE_PULSE_SECONDS


func _apply_high_score_pulse_visual() -> void:
	if not is_instance_valid(_high_score_label):
		return
	var progress := _high_score_pulse_progress()
	var grow := sin(progress * PI)
	var flash := clampf(1.0 - abs(progress - 0.18) / 0.18, 0.0, 1.0)
	var scale := 1.0 + grow * 0.52 + flash * 0.18
	_high_score_label.pivot_offset = _high_score_label.size * 0.5
	_high_score_label.scale = Vector2(scale, scale)
	var hot_color := Color(1.0, 0.92 + flash * 0.08, 0.28, 1.0)
	var base_color := Color(0.78, 0.94, 1.0, 1.0)
	_high_score_label.add_theme_color_override("font_color", hot_color.lerp(base_color, progress * progress))
	_high_score_label.add_theme_constant_override("outline_size", 4 + int(roundf((grow + flash) * 4.0)))


func _reset_high_score_pulse_visual() -> void:
	if not is_instance_valid(_high_score_label):
		return
	_high_score_label.scale = Vector2.ONE
	_high_score_label.pivot_offset = _high_score_label.size * 0.5
	_high_score_label.add_theme_color_override("font_color", Color(0.78, 0.94, 1.0, 1.0))
	_high_score_label.add_theme_constant_override("outline_size", 3)


func _make_panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _set_control_rect(control: Control, pos: Vector2, rect_size: Vector2) -> void:
	if not is_instance_valid(control):
		return
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.position = Vector2(round(pos.x), round(pos.y))
	control.size = Vector2(round(maxf(rect_size.x, 1.0)), round(maxf(rect_size.y, 1.0)))


func _update_hud_text() -> void:
	if is_instance_valid(_score_label):
		_score_label.text = str("Cells Cleared ", Global.format_score_value(_score))
	if is_instance_valid(_high_score_label):
		_high_score_label.text = str("Most Cleared ", Global.format_score_value(Global.high_score))
	if is_instance_valid(_fill_label):
		_fill_label.text = ""
	if is_instance_valid(_status_label):
		_status_label.text = _hint_text if not _hint_text.is_empty() else _status_text
	if is_instance_valid(_game_over_score_label):
		_game_over_score_label.text = str("Cells Cleared ", Global.format_score_value(_score), "  |  Most Cleared ", Global.format_score_value(Global.high_score))


func _draw_arcade_overlay(layer: Control) -> void:
	if not _using_board_renderer:
		_draw_fallback_board(layer)
		_draw_hint_overlay(layer)
		_draw_inventory(layer, true)
		_draw_inventory_drag(layer)
	_draw_clear_effect_overlay(layer)
	_draw_high_score_sparkles(layer)


func _draw_fallback_board(layer: Control) -> void:
	for y in range(BOARD_ROWS):
		for x in range(BOARD_COLS):
			var rect := Rect2(_board_rect.position + Vector2(x, y) * _tile_size, Vector2(_tile_size, _tile_size)).grow(-2.0)
			layer.draw_rect(rect, Color(0.06, 0.12, 0.13, 0.92), true)
			layer.draw_rect(rect, Color(0.42, 0.86, 0.74, 0.34), false, 2.0)
	for id in _board_cell_ids:
		if _drag_source == DRAG_SOURCE_BOARD and id == _drag_cell_id:
			continue
		var cell: Dictionary = _board_cells.get(id, {})
		_draw_cell(layer, cell, _tile_center(_get_cell_tile(id)), false)
	if _drag_source == DRAG_SOURCE_BOARD and _board_cells.has(_drag_cell_id):
		_draw_cell(layer, _board_cells.get(_drag_cell_id, {}), _drag_position, true)


func _draw_inventory(layer: Control, draw_cells: bool) -> void:
	for index in range(_inventory_centers.size()):
		var center := _inventory_centers[index]
		var cell_id := ""
		if index < _inventory_cells.size():
			cell_id = str(_inventory_cells[index].get("id", ""))
		var fresh_strength := _inventory_fresh_strength(cell_id)
		var burst := sin((1.0 - fresh_strength) * PI)
		var slot_size := _tile_size * INVENTORY_SLOT_SCALE
		var slot_rect := Rect2(center - Vector2(slot_size * 0.5, slot_size * 0.5), Vector2(slot_size, slot_size))
		var shadow_rect := slot_rect.grow(_tile_size * 0.018)
		shadow_rect.position += Vector2(0.0, _tile_size * 0.055)
		if draw_cells:
			layer.draw_rect(shadow_rect, Color(0.0, 0.012, 0.015, 0.50), true)
			layer.draw_rect(slot_rect, Color(0.085, 0.120, 0.130, 0.98), true)
			layer.draw_rect(slot_rect.grow(-_tile_size * 0.045), Color(0.115, 0.158, 0.165, 0.55), true)
			layer.draw_rect(slot_rect.grow(-_tile_size * 0.030), Color(0.24, 0.42, 0.42, 0.20), false, maxf(1.4, _tile_size * 0.018))
		if not draw_cells:
			layer.draw_rect(shadow_rect, Color(0.0, 0.012, 0.015, 0.30), false, maxf(3.0, _tile_size * 0.040))
			layer.draw_rect(slot_rect.grow(-_tile_size * 0.030), Color(1.0, 1.0, 1.0, 0.13), false, maxf(1.2, _tile_size * 0.016))
			layer.draw_rect(slot_rect, Color(0.08, 0.25, 0.21, 0.72), false, maxf(5.0, _tile_size * 0.074))
			layer.draw_rect(slot_rect.grow(-_tile_size * 0.022), Color(0.54, 1.0, 0.84, 0.82), false, maxf(3.2, _tile_size * 0.046))
			continue
		if index < _inventory_cells.size():
			if _drag_source == DRAG_SOURCE_INVENTORY and index == _drag_inventory_index:
				pass
			else:
				if fresh_strength > 0.0:
					var cell_halo_radius := _tile_size * (0.50 + burst * 0.08)
					layer.draw_circle(center, cell_halo_radius, Color(1.0, 0.90, 0.28, 0.18 * fresh_strength + 0.12 * burst))
					layer.draw_arc(center, cell_halo_radius * 1.04, 0.0, TAU, 42, Color(1.0, 0.90, 0.30, 0.46 * fresh_strength), maxf(3.0, _tile_size * 0.052), true)
				_draw_cell(layer, _inventory_cells[index], center, false, INVENTORY_CELL_SCALE + fresh_strength * 0.10 + burst * 0.07)
		layer.draw_rect(shadow_rect, Color(0.0, 0.012, 0.015, 0.36), false, maxf(3.0, _tile_size * 0.040))
		layer.draw_rect(slot_rect.grow(-_tile_size * 0.030), Color(1.0, 1.0, 1.0, 0.13), false, maxf(1.2, _tile_size * 0.016))
		layer.draw_rect(slot_rect, Color(0.08, 0.25, 0.21, 0.72), false, maxf(5.0, _tile_size * 0.074))
		layer.draw_rect(slot_rect.grow(-_tile_size * 0.022), Color(0.54, 1.0, 0.84, 0.82), false, maxf(3.2, _tile_size * 0.046))


func _draw_inventory_drag(layer: Control) -> void:
	if _drag_source == DRAG_SOURCE_INVENTORY and _drag_inventory_index >= 0 and _drag_inventory_index < _inventory_cells.size():
		_draw_cell(layer, _inventory_cells[_drag_inventory_index], _drag_position, true, INVENTORY_CELL_SCALE)


func _draw_hint_overlay(layer: Control) -> void:
	if _hint_pair.size() != 2:
		return
	var start := _hint_cell_center(_hint_pair[0])
	var finish := _hint_cell_center(_hint_pair[1])
	if start == HINT_MISSING_CENTER or finish == HINT_MISSING_CENTER:
		return
	var color := Color(1.0, 0.92, 0.24, 0.88)
	layer.draw_line(start, finish, Color(1.0, 0.92, 0.24, 0.34), 9.0, true)
	layer.draw_line(start, finish, color, 3.0, true)
	layer.draw_arc(start, _tile_size * 0.49, 0.0, TAU, 36, color, 4.0, true)
	layer.draw_arc(finish, _tile_size * 0.49, 0.0, TAU, 36, color, 4.0, true)


func _draw_clear_effect_overlay(layer: Control) -> void:
	if not _is_clear_effect_active():
		return
	var progress := _clear_effect_progress()
	var scale := _clear_effect_scale()
	var fade := 1.0 - progress
	var burst := sin(progress * PI)
	var flash := clampf(1.0 - abs(progress - 0.18) / 0.18, 0.0, 1.0)
	var centers: Array[Vector2] = []
	var effect_ids: Array[String] = []
	for id in _clear_effect_ids:
		if not _board_cells.has(id):
			continue
		effect_ids.append(id)
		centers.append(_tile_center(_get_cell_tile(id)))
	var connector_color := Color(1.0, 0.88, 0.28, 0.26 * fade + 0.30 * flash)
	for i in range(centers.size()):
		for j in range(i + 1, centers.size()):
			if centers[i].distance_squared_to(centers[j]) <= _tile_size * _tile_size * 1.35:
				layer.draw_line(centers[i], centers[j], connector_color, maxf(3.0, _tile_size * (0.08 + flash * 0.08) * scale), true)
	for index in range(centers.size()):
		var center := centers[index]
		var ring_radius := _tile_size * (0.46 + progress * 0.82) * scale
		var hot := Color(1.0, 0.96, 0.48, 0.24 * fade + 0.54 * flash)
		layer.draw_circle(center, _tile_size * (0.45 + burst * 0.24) * scale, Color(1.0, 0.92, 0.34, 0.10 * fade + 0.24 * flash))
		layer.draw_arc(center, ring_radius, 0.0, TAU, 48, hot, maxf(3.0, _tile_size * 0.08 * scale), true)
		layer.draw_arc(center, ring_radius * 0.68, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.22 * fade + 0.42 * flash), maxf(2.0, _tile_size * 0.035 * scale), true)
		var spark_count := int(roundf(8.0 + (scale - 1.0) * 10.0))
		for spark in range(spark_count):
			var angle_seed := float((abs(hash(str(effect_ids[index], ":", spark))) % 1000)) / 1000.0
			var angle := angle_seed * TAU + progress * TAU * (0.35 + float(spark % 3) * 0.09)
			var direction := Vector2(cos(angle), sin(angle))
			var spark_start := center + direction * _tile_size * (0.24 + progress * 0.28) * scale
			var spark_end := center + direction * _tile_size * (0.44 + progress * 0.74) * scale
			var spark_color := Color(1.0, 0.90, 0.26, (0.18 + flash * 0.42) * fade)
			layer.draw_line(spark_start, spark_end, spark_color, maxf(1.6, _tile_size * 0.024 * scale), true)
	_draw_clear_effect_message(layer, centers, scale, fade, flash)


func _draw_clear_effect_message(layer: Control, centers: Array[Vector2], scale: float, fade: float, flash: float) -> void:
	if centers.is_empty():
		return
	var center := Vector2.ZERO
	for point in centers:
		center += point
	center /= float(centers.size())
	center.y = clampf(center.y - _tile_size * (0.85 + 0.25 * scale), _board_rect.position.y + _tile_size * 0.42, _board_rect.position.y + _board_rect.size.y - _tile_size * 0.35)
	var text := str("Amazing! ", _clear_effect_ids.size(), "-Cells Cleared!")
	var font: Font = ThemeDB.fallback_font
	var font_size := int(roundf(_tile_size * (0.25 + 0.07 * scale)))
	var width := minf(_board_rect.size.x, _tile_size * (4.6 + scale * 1.2))
	var origin := Vector2(center.x - width * 0.5, center.y + float(font_size) * 0.38)
	var alpha := clampf(0.36 + flash * 0.46 + fade * 0.22, 0.0, 1.0)
	var pad := Vector2(_tile_size * 0.18, _tile_size * 0.12)
	var box := Rect2(Vector2(center.x - width * 0.5 - pad.x, center.y - font_size * 0.82 - pad.y), Vector2(width + pad.x * 2.0, font_size * 1.32 + pad.y * 2.0))
	layer.draw_rect(box, Color(0.02, 0.07, 0.06, 0.32 * alpha), true)
	layer.draw_rect(box, Color(1.0, 0.88, 0.28, 0.58 * alpha), false, maxf(2.0, _tile_size * 0.028 * scale))
	layer.draw_string(font, origin + Vector2(1.8, 1.8), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(0.01, 0.025, 0.03, 0.86 * alpha))
	layer.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(1.0, 0.92, 0.34, alpha))


func _draw_high_score_sparkles(layer: Control) -> void:
	if not _is_high_score_pulse_active() or not is_instance_valid(_high_score_label):
		return
	var progress := _high_score_pulse_progress()
	var pulse := sin(progress * PI)
	var flash := clampf(1.0 - abs(progress - 0.18) / 0.18, 0.0, 1.0)
	var rect := Rect2(_high_score_label.position, _high_score_label.size)
	var center := rect.get_center()
	var radius := maxf(rect.size.x, rect.size.y) * (0.42 + pulse * 0.18 + flash * 0.08)
	var alpha := clampf((1.0 - progress) * 0.70 + pulse * 0.36, 0.0, 1.0)
	layer.draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 0.88, 0.28, 0.32 * alpha), maxf(2.0, _tile_size * 0.026), true)
	layer.draw_arc(center, radius * 0.72, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.26 * alpha + flash * 0.18), maxf(1.4, _tile_size * 0.016), true)
	for index in range(HIGH_SCORE_SPARKLE_COUNT):
		var seed := float((abs(hash(str(_high_score_sparkle_nonce, ":", index))) % 1000)) / 1000.0
		var phase := seed * TAU + progress * TAU * (0.72 + float(index % 4) * 0.08)
		var direction := Vector2(cos(phase), sin(phase))
		var wobble := 0.82 + 0.30 * sin(progress * TAU + float(index) * 1.37)
		var spark_center := center + direction * radius * wobble
		var spark_len := _tile_size * (0.07 + 0.05 * pulse + 0.04 * flash)
		var color := Color(1.0, 0.92, 0.30, alpha)
		layer.draw_line(spark_center - direction * spark_len, spark_center + direction * spark_len, color, maxf(1.5, _tile_size * 0.018), true)
		var cross := Vector2(-direction.y, direction.x)
		layer.draw_line(spark_center - cross * spark_len * 0.62, spark_center + cross * spark_len * 0.62, Color(1.0, 1.0, 1.0, alpha * 0.72), maxf(1.2, _tile_size * 0.014), true)


func _hint_cell_center(id: String) -> Vector2:
	if _drag_cell_id == id:
		return _drag_position
	if _board_cells.has(id):
		return _tile_center(_get_cell_tile(id))
	for index in range(_inventory_cells.size()):
		if index >= _inventory_centers.size():
			continue
		if str(_inventory_cells[index].get("id", "")) == id:
			return _inventory_centers[index]
	return HINT_MISSING_CENTER


func _draw_cell(layer: Control, cell: Dictionary, center: Vector2, dragging: bool, visual_scale: float = 1.0) -> void:
	var produced := str(cell.get("produced", ""))
	var kind := str(cell.get("kind", "Standard"))
	var label := "*" if kind == "RedMyco" else produced
	var color := Color(0.88, 0.02, 0.10, 1.0) if kind == "RedMyco" else _resource_color(produced)
	var radius := _tile_size * (0.41 if dragging else 0.38) * visual_scale
	layer.draw_circle(center + Vector2(0.0, radius * 0.08), radius * 1.04, Color(0.0, 0.0, 0.0, 0.30))
	layer.draw_circle(center, radius, color)
	layer.draw_arc(center, radius, 0.0, TAU, 36, Color(0.95, 1.0, 0.96, 0.62), 2.4, true)
	var font: Font = ThemeDB.fallback_font
	_draw_centered_text(layer, font, center, radius, label, int(_tile_size * 0.46 * visual_scale), Color.WHITE)
	var needs_value: Variant = cell.get("needs", [])
	if needs_value is Array:
		var needs: Array = needs_value as Array
		var pip_count := 4 if kind == "RedMyco" else needs.size()
		for index in range(pip_count):
			var angle := -PI * 0.5 + TAU * float(index) / maxf(float(pip_count), 1.0)
			var pip_center := center + Vector2(cos(angle), sin(angle)) * radius * 0.86
			if index >= needs.size():
				var blank_radius := maxf(7.0, radius * 0.22)
				layer.draw_circle(pip_center, blank_radius, Color(0.92, 0.97, 0.96, 1.0))
				layer.draw_arc(pip_center, blank_radius, 0.0, TAU, 16, Color(0.01, 0.025, 0.03, 0.70), 1.4, true)
				continue
			var need := str(needs[index])
			var pip_color := _resource_color(need)
			layer.draw_circle(pip_center, maxf(7.0, radius * 0.22), pip_color.darkened(0.10))
			layer.draw_arc(pip_center, maxf(7.0, radius * 0.22), 0.0, TAU, 16, Color.WHITE, 1.4, true)
			_draw_centered_text(layer, font, pip_center, radius * 0.22, need, int(_tile_size * 0.15 * visual_scale), Color.WHITE)


func _draw_centered_text(layer: Control, font: Font, center: Vector2, radius: float, text: String, font_size: int, color: Color) -> void:
	if text.is_empty():
		return
	var width := radius * 2.0
	var origin := Vector2(center.x - radius, center.y + float(font_size) * 0.35)
	var outline := Color(0.01, 0.025, 0.03, 0.88)
	layer.draw_string(font, origin + Vector2(-1.4, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	layer.draw_string(font, origin + Vector2(1.4, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	layer.draw_string(font, origin + Vector2(0.0, -1.4), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	layer.draw_string(font, origin + Vector2(0.0, 1.4), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	layer.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
	layer.draw_string(font, origin + Vector2(0.7, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _sync_board_renderer() -> void:
	if not is_instance_valid(_board_renderer) or not _board_renderer.has_method("set_render_state"):
		_using_board_renderer = false
		return
	if _drag_source == DRAG_SOURCE_BOARD and _board_renderer_has_state and not _board_renderer_full_sync_needed and _board_renderer.has_method("set_drag_state"):
		_board_renderer.call("set_drag_state", _drag_cell_id, _drag_position, _drag_original_tile, false)
		return
	if _board_renderer_has_state and not _board_renderer_full_sync_needed:
		if _board_renderer is CanvasItem:
			(_board_renderer as CanvasItem).queue_redraw()
		return
	var state := {
		"boardRect": _board_rect,
		"boardViewportRect": _board_rect,
		"tileSize": _tile_size,
		"boardCols": BOARD_COLS,
		"boardRows": BOARD_ROWS,
		"cells": _board_cell_ids,
		"positions": _positions,
		"inventoryCells": _inventory_cell_ids(),
		"inventoryCenters": _inventory_center_lookup(),
		"inventoryFreshStarts": _inventory_fresh_start_lookup(),
		"producedByCell": _renderer_produced_by_cell(),
		"cellKinds": _renderer_cell_kinds(),
		"rocks": _rocks,
		"needs": _renderer_needs(),
		"snapshot": _sim_snapshot,
		"usingCsharpSim": _using_csharp_sim,
		"solved": false,
		"circuitOverlayEnabled": true,
		"fastDragMode": false,
		"dragCell": _drag_cell_id if _drag_source == DRAG_SOURCE_BOARD else "",
		"dragPosition": _drag_position,
		"originalDragTile": _drag_original_tile,
		"inventoryDragCell": _drag_cell_id if _drag_source == DRAG_SOURCE_INVENTORY else "",
		"inventoryDragPosition": _drag_position,
		"hintPair": _hint_pair,
		"clearingCells": _clear_effect_ids,
		"clearEffectProgress": _clear_effect_progress(),
		"clearEffectScale": _clear_effect_scale(),
		"resourceMarkMode": 0,
		"visualProfileEnabled": false,
		"visualProfilePrintEvery": 120
	}
	_board_renderer.call("set_render_state", state)
	_board_renderer_full_sync_needed = false
	_board_renderer_has_state = true


func _inventory_cell_ids() -> Array[String]:
	var result: Array[String] = []
	for cell in _inventory_cells:
		result.append(str(cell.get("id", "")))
	return result


func _inventory_center_lookup() -> Dictionary:
	var centers: Dictionary = {}
	for index in range(_inventory_cells.size()):
		if index >= _inventory_centers.size():
			continue
		var cell: Dictionary = _inventory_cells[index]
		centers[str(cell.get("id", ""))] = _inventory_centers[index]
	return centers


func _inventory_fresh_start_lookup() -> Dictionary:
	var starts: Dictionary = {}
	var active_ids: Dictionary = {}
	for cell in _inventory_cells:
		var id := str(cell.get("id", ""))
		if id.is_empty():
			continue
		active_ids[id] = true
		if _inventory_fresh_strength(id) > 0.0:
			starts[id] = int(_inventory_fresh_start_msec_by_id.get(id, 0))
	for id in _inventory_fresh_start_msec_by_id.keys():
		var key := str(id)
		if not active_ids.has(key) or _inventory_fresh_strength(key) <= 0.0:
			_inventory_fresh_start_msec_by_id.erase(id)
	return starts


func _renderer_produced_by_cell() -> Dictionary:
	var produced: Dictionary = _produced_by_cell.duplicate()
	for cell in _inventory_cells:
		produced[str(cell.get("id", ""))] = str(cell.get("produced", ""))
	return produced


func _renderer_cell_kinds() -> Dictionary:
	var kinds: Dictionary = _cell_kind_by_id.duplicate()
	for cell in _inventory_cells:
		kinds[str(cell.get("id", ""))] = str(cell.get("kind", "Standard"))
	return kinds


func _renderer_needs() -> Dictionary:
	var needs: Dictionary = _needs.duplicate(true)
	for cell in _inventory_cells:
		var cell_needs: Array[String] = []
		var needs_value: Variant = cell.get("needs", [])
		if needs_value is Array:
			for need in needs_value:
				cell_needs.append(str(need))
		needs[str(cell.get("id", ""))] = cell_needs
	return needs


func _draw() -> void:
	var view_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.025, 0.055, 0.065, 1.0), true)
	_sync_board_renderer()
	if is_instance_valid(_overlay_layer):
		_overlay_layer.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _game_over or _is_clear_effect_active():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_drag(mouse_event.position, -1)
			else:
				_finish_drag(mouse_event.position)
	elif event is InputEventMouseMotion:
		if _drag_source != DRAG_SOURCE_NONE:
			_update_drag((event as InputEventMouseMotion).position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_drag(touch.position, touch.index)
		elif _drag_source != DRAG_SOURCE_NONE and touch.index == _drag_touch_id:
			_finish_drag(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _drag_source != DRAG_SOURCE_NONE and drag.index == _drag_touch_id:
			_update_drag(drag.position)


func _begin_drag(screen_pos: Vector2, touch_id: int = -1) -> bool:
	var board_cell := _board_cell_at(screen_pos)
	if not board_cell.is_empty():
		_clear_hint(false)
		_drag_source = DRAG_SOURCE_BOARD
		_drag_cell_id = board_cell
		_drag_inventory_index = -1
		_drag_touch_id = touch_id
		_drag_original_tile = _get_cell_tile(board_cell)
		_drag_position = _tile_center(_drag_original_tile)
		_drag_offset = _drag_position - screen_pos
		accept_event()
		queue_redraw()
		return true
	var inventory_index := _inventory_cell_at(screen_pos)
	if inventory_index >= 0:
		_clear_hint(false)
		_drag_source = DRAG_SOURCE_INVENTORY
		_drag_cell_id = str(_inventory_cells[inventory_index].get("id", ""))
		_drag_inventory_index = inventory_index
		_drag_touch_id = touch_id
		_drag_position = _inventory_centers[inventory_index]
		_drag_offset = _drag_position - screen_pos
		_board_renderer_full_sync_needed = true
		accept_event()
		queue_redraw()
		return true
	return false


func _update_drag(screen_pos: Vector2) -> void:
	_drag_position = screen_pos + _drag_offset
	if _drag_source == DRAG_SOURCE_INVENTORY:
		_board_renderer_full_sync_needed = true
	accept_event()
	queue_redraw()


func _finish_drag(screen_pos: Vector2) -> void:
	if _drag_source == DRAG_SOURCE_NONE:
		return
	_drag_position = screen_pos + _drag_offset
	var target_tile := _screen_to_tile(_drag_position)
	var changed := false
	if _drag_source == DRAG_SOURCE_BOARD:
		if _is_tile_inside(target_tile) and (_is_tile_empty(target_tile) or target_tile == _drag_original_tile):
			var cell: Dictionary = _board_cells.get(_drag_cell_id, {})
			cell["x"] = target_tile.x
			cell["y"] = target_tile.y
			_board_cells[_drag_cell_id] = cell
			changed = true
	elif _drag_source == DRAG_SOURCE_INVENTORY:
		if _is_tile_inside(target_tile) and _is_tile_empty(target_tile):
			var cell_to_place := _inventory_cells[_drag_inventory_index].duplicate(true)
			_add_cell_to_board(cell_to_place, target_tile)
			var replacement := _make_inventory_cell(_drag_inventory_index)
			_inventory_cells[_drag_inventory_index] = replacement
			_mark_inventory_cell_fresh(replacement)
			changed = true
	_reset_drag()
	if changed:
		_clear_hint(false)
		_reload_sim_from_board()
		_status_text = ""
		_update_hud_text()
	accept_event()
	queue_redraw()


func _reset_drag() -> void:
	_drag_source = DRAG_SOURCE_NONE
	_drag_cell_id = ""
	_drag_inventory_index = -1
	_drag_touch_id = -1
	_drag_original_tile = Vector2i.ZERO
	_board_renderer_full_sync_needed = true


func _board_cell_at(screen_pos: Vector2) -> String:
	for id in _board_cell_ids:
		var center := _tile_center(_get_cell_tile(id))
		if center.distance_to(screen_pos) <= _tile_size * 0.44:
			return id
	return ""


func _inventory_cell_at(screen_pos: Vector2) -> int:
	for index in range(_inventory_centers.size()):
		if index < _inventory_cells.size() and _inventory_centers[index].distance_to(screen_pos) <= _tile_size * 0.64:
			return index
	return -1


func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var local := screen_pos - _board_rect.position
	return Vector2i(floori(local.x / _tile_size), floori(local.y / _tile_size))


func _tile_center(tile: Vector2i) -> Vector2:
	return _board_rect.position + (Vector2(tile) + Vector2(0.5, 0.5)) * _tile_size


func _get_cell_tile(id: String) -> Vector2i:
	var cell: Dictionary = _board_cells.get(id, {})
	return Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0)))


func _is_tile_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < BOARD_COLS and tile.y < BOARD_ROWS


func _is_tile_empty(tile: Vector2i) -> bool:
	if not _is_tile_inside(tile):
		return false
	for id in _board_cell_ids:
		if _drag_source == DRAG_SOURCE_BOARD and id == _drag_cell_id:
			continue
		if _get_cell_tile(id) == tile:
			return false
	return true


func _resource_color(resource: String) -> Color:
	var index := RESOURCE_LETTERS.find(resource)
	if index < 0:
		return Color(0.80, 0.86, 0.86, 1.0)
	return RESOURCE_COLORS[index % RESOURCE_COLORS.size()]


func _inventory_fresh_strength(cell_id: String) -> float:
	if cell_id.is_empty() or not _inventory_fresh_start_msec_by_id.has(cell_id):
		return 0.0
	var start_msec := int(_inventory_fresh_start_msec_by_id.get(cell_id, 0))
	var elapsed := float(Time.get_ticks_msec() - start_msec) / 1000.0
	return clampf(1.0 - elapsed / INVENTORY_FRESH_SECONDS, 0.0, 1.0)


func _has_inventory_fresh_animation() -> bool:
	for cell in _inventory_cells:
		if _inventory_fresh_strength(str(cell.get("id", ""))) > 0.0:
			return true
	return false


func _has_live_visual_animation() -> bool:
	if not _using_csharp_sim:
		return false
	var current_tick := int(_sim_snapshot.get("tick", 0))
	for event_key in ["swaps", "flows", "reactions", "possibleSwaps"]:
		var value: Variant = _sim_snapshot.get(event_key, [])
		if value is Array:
			var array_value: Array = value as Array
			if not array_value.is_empty():
				return true
	return current_tick > 0


func _on_restart_pressed() -> void:
	Global.record_last_score(_score)
	_start_run()


func _on_main_menu_pressed() -> void:
	Global.record_last_score(_score)
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _on_hint_pressed() -> void:
	var candidates: Array = _arcade_hint_candidates()
	if candidates.is_empty():
		_hint_pair.clear()
		_hint_text = "No useful connection found"
		_board_renderer_full_sync_needed = true
		_update_hud_text()
		queue_redraw()
		return
	var candidate: Dictionary = candidates[_hint_cursor % candidates.size()] as Dictionary
	_hint_cursor += 1
	_hint_pair = [str(candidate.get("a", "")), str(candidate.get("b", ""))]
	_hint_text = str(candidate.get("text", "Hint: connect these cells"))
	_board_renderer_full_sync_needed = true
	_update_hud_text()
	queue_redraw()


func _clear_hint(update_hud: bool = true) -> void:
	_hint_pair.clear()
	_hint_text = ""
	_board_renderer_full_sync_needed = true
	if update_hud:
		_update_hud_text()
		queue_redraw()


func _arcade_hint_candidates() -> Array:
	var candidates: Array = []
	for inv_cell in _inventory_cells:
		for board_id in _board_cell_ids:
			var board_cell: Dictionary = _board_cells.get(board_id, {})
			var inventory_score := _inventory_hint_score(inv_cell, board_cell)
			if inventory_score <= 0.0:
				continue
			candidates.append({
				"a": str(inv_cell.get("id", "")),
				"b": board_id,
				"score": inventory_score + 100.0,
				"text": str("Hint: place ", _cell_hint_mark(inv_cell), " next to ", _cell_hint_mark(board_cell))
			})
	for i in range(_board_cell_ids.size()):
		for j in range(i + 1, _board_cell_ids.size()):
			var a_id := _board_cell_ids[i]
			var b_id := _board_cell_ids[j]
			if _get_cell_tile(a_id).distance_squared_to(_get_cell_tile(b_id)) == 1:
				continue
			var a_cell: Dictionary = _board_cells.get(a_id, {})
			var b_cell: Dictionary = _board_cells.get(b_id, {})
			var board_score := _hint_pair_score(a_cell, b_cell)
			if board_score <= 0.0:
				continue
			candidates.append({
				"a": a_id,
				"b": b_id,
				"score": board_score,
				"text": str("Hint: connect ", _cell_hint_mark(a_cell), " with ", _cell_hint_mark(b_cell))
			})
	candidates.sort_custom(Callable(self, "_compare_hint_candidates"))
	return candidates


func _compare_hint_candidates(a: Variant, b: Variant) -> bool:
	var da: Dictionary = a as Dictionary
	var db: Dictionary = b as Dictionary
	var score_a := float(da.get("score", 0.0))
	var score_b := float(db.get("score", 0.0))
	if not is_equal_approx(score_a, score_b):
		return score_a > score_b
	return str(da.get("text", "")) < str(db.get("text", ""))


func _inventory_hint_score(inventory_cell: Dictionary, board_cell: Dictionary) -> float:
	var inventory_to_board := _cell_offer_match_count(inventory_cell, board_cell)
	var board_to_inventory := _cell_offer_match_count(board_cell, inventory_cell)
	if inventory_to_board <= 0 and board_to_inventory <= 0:
		return 0.0
	var score := float(inventory_to_board * 4 + board_to_inventory * 2)
	if inventory_to_board > 0 and board_to_inventory > 0:
		score += 5.0
	if _cell_has_main_need_match(inventory_cell, board_cell):
		score += 4.0
	if _cell_has_main_need_match(board_cell, inventory_cell):
		score += 4.0
	if _cell_is_red_myco(inventory_cell):
		score += 1.0
	return score


func _hint_pair_score(a: Dictionary, b: Dictionary) -> float:
	var a_to_b := _cell_offer_match_count(a, b)
	var b_to_a := _cell_offer_match_count(b, a)
	if a_to_b <= 0 or b_to_a <= 0:
		return 0.0
	var score := float(a_to_b + b_to_a)
	if _cell_has_main_need_match(a, b):
		score += 5.0
	if _cell_has_main_need_match(b, a):
		score += 5.0
	if _cell_is_red_myco(a) or _cell_is_red_myco(b):
		score += 1.0
	return score


func _cell_offer_match_count(source: Dictionary, target: Dictionary) -> int:
	var count := 0
	for resource in _cell_offer_resources(source):
		if _cell_accepts_resource_doc(target, resource):
			count += 1
	return count


func _cell_has_main_need_match(a: Dictionary, b: Dictionary) -> bool:
	var produced := str(a.get("produced", ""))
	return not produced.is_empty() and _cell_needs_resource_doc(b, produced)


func _cell_offer_resources(cell: Dictionary) -> Array[String]:
	var resources: Array[String] = []
	var produced := str(cell.get("produced", ""))
	if not produced.is_empty():
		resources.append(produced)
	if _cell_is_red_myco(cell):
		var needs_value: Variant = cell.get("needs", [])
		if needs_value is Array:
			for need in needs_value:
				var resource := str(need)
				if not resource.is_empty() and not resources.has(resource):
					resources.append(resource)
	return resources


func _cell_accepts_resource_doc(cell: Dictionary, resource: String) -> bool:
	return not resource.is_empty() and (str(cell.get("produced", "")) == resource or _cell_needs_resource_doc(cell, resource))


func _cell_needs_resource_doc(cell: Dictionary, resource: String) -> bool:
	if resource.is_empty():
		return false
	var needs_value: Variant = cell.get("needs", [])
	if not needs_value is Array:
		return false
	for need in needs_value:
		if str(need) == resource:
			return true
	return false


func _cell_is_red_myco(cell: Dictionary) -> bool:
	return str(cell.get("kind", "Standard")) == "RedMyco"


func _cell_hint_mark(cell: Dictionary) -> String:
	if _cell_is_red_myco(cell):
		return "*"
	var produced := str(cell.get("produced", ""))
	return produced if not produced.is_empty() else str(cell.get("id", "cell"))
