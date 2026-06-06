extends Control

const ArcadeOverlayLayer = preload("res://scenes/cellular_arcade_overlay.gd")

const BOARD_COLS := 5
const BOARD_ROWS := 5
const BOARD_TILE_COUNT := BOARD_COLS * BOARD_ROWS
const INVENTORY_SLOT_COUNT := 3
const CLEAR_GROUP_MIN_SIZE := 4
const CLEAR_EFFECT_MAX_SCALE_COUNT := 10
const CLEAR_SETTLE_TICKS := 6
const FULL_BOARD_GAME_OVER_GRACE_SECONDS := 5.0
const NORMAL_MIN_NEEDS := 3
const NORMAL_MAX_NEEDS := 3
const NORMAL_ONE_NEED_WEIGHT := 20
const NORMAL_TWO_NEEDS_WEIGHT := 35
const NORMAL_THREE_NEEDS_WEIGHT := 45
const RESOURCE_LETTERS := ["A", "B", "C", "D", "E", "F", "G", "H"]
const RESOURCE_COLORS := [
	Color(0.18, 0.72, 0.78, 1.0),
	Color(0.93, 0.42, 0.25, 1.0),
	Color(0.50, 0.78, 0.30, 1.0),
	Color(0.78, 0.46, 0.92, 1.0),
	Color(0.95, 0.74, 0.24, 1.0),
	Color(0.36, 0.52, 0.95, 1.0),
	Color(0.92, 0.30, 0.50, 1.0),
	Color(0.24, 0.80, 0.56, 1.0),
	Color(0.18, 0.61, 0.94, 1.0),
	Color(0.71, 0.85, 0.25, 1.0),
	Color(0.85, 0.30, 0.75, 1.0),
	Color(0.95, 0.55, 0.18, 1.0),
	Color(0.27, 0.82, 0.74, 1.0),
	Color(0.49, 0.45, 0.95, 1.0),
	Color(0.94, 0.35, 0.35, 1.0),
	Color(0.65, 0.89, 0.29, 1.0),
	Color(0.29, 0.78, 0.95, 1.0),
	Color(0.62, 0.36, 0.86, 1.0),
	Color(0.73, 0.71, 0.28, 1.0),
	Color(0.94, 0.55, 0.43, 1.0),
	Color(0.16, 0.75, 0.63, 1.0),
	Color(0.43, 0.60, 0.95, 1.0),
	Color(0.95, 0.36, 0.66, 1.0),
	Color(0.37, 0.75, 0.35, 1.0),
	Color(0.73, 0.52, 0.95, 1.0),
	Color(0.85, 0.60, 0.20, 1.0)
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
const CLEAR_EFFECT_SECONDS := 1.65
const SCORE_PULSE_SECONDS := 0.72
const HIGH_SCORE_PULSE_SECONDS := 1.18
const HIGH_SCORE_SPARKLE_COUNT := 14
const INVENTORY_FRESH_SECONDS := 1.55
const IDLE_HINT_DELAY_SECONDS := 5.0
const IDLE_HINT_PULSE_SECONDS := 2.0
const IDLE_HINT_MAX_SCALE := 1.22
const INVENTORY_SLOT_SCALE := 1.28
const INVENTORY_CELL_SCALE := 1.10
const INVENTORY_CELL_Y_OFFSET := 0.06
const PIP_ANGLE_SMOOTH := 0.10
const PIP_OFFSET_SMOOTH := 0.12
const PIP_ANGLE_RETURN_SMOOTH := 0.045
const PIP_OFFSET_RETURN_SMOOTH := 0.055
const PIP_ANGLE_DEAD_ZONE := 0.018
const PIP_OFFSET_DEAD_ZONE := 0.45
const NEED_PIP_MINIMUM_ANGLE_GAP := 0.30
const NEED_PIP_FAN_ANGLE_STEP := 0.32
const NEED_PIP_LANE_FOOTPRINT_SCALE := 1.36
const NEED_PIP_LANE_MARGIN := 4.0
const ZERO_PIP_PULSE_PERIOD_MSEC := 3000
const ZERO_PIP_PULSE_FADE_MSEC := 1000
const ZERO_PIP_PULSE_GLOW_SCALE := 1.20
const ZERO_PIP_PULSE_BRIGHTNESS_SCALE := 1.20
const ZERO_PIP_PULSE_COLOR := Color(1.0, 0.0, 0.0, 1.0)
const CELL_STRESS_GLOW_STRENGTH := 0.42
const CELL_HEALTHY_GLOW_STRENGTH := 0.72
const CELL_STRESS_GLOW_RADIUS_SCALE := 1.14
const CELL_HEALTHY_GLOW_RADIUS_SCALE := 1.48
const CELL_STRESS_GLOW_ALPHA_SCALE := 0.44
const CELL_HEALTHY_GLOW_ALPHA_SCALE := 0.56
const CELL_HEALTH_COLOR_CURVE := 0.52
const CELL_HEALTH_RADIUS_CURVE := 0.42
const CELL_HEALTH_ALPHA_CURVE := 0.46
const CELL_GLOW_MID_RADIUS_FRACTION := 0.64
const CELL_GLOW_INNER_RADIUS_FRACTION := 0.34
const CELL_GLOW_OUTER_ALPHA_FRACTION := 0.34
const CELL_GLOW_MID_ALPHA_FRACTION := 0.52
const CELL_GLOW_INNER_ALPHA_FRACTION := 0.70
const CELL_STRESS_GLOW_COLOR := Color(1.0, 0.96, 0.04, 1.0)
const CELL_HEALTHY_GLOW_COLOR := Color(0.30, 1.0, 0.84, 1.0)
const NEED_PIP_MARK_SIZE_SCALE := 1.10
const NEED_PIP_MARK_WEIGHT_SCALE := 1.10
const PLAYABLE_TILE_EVEN_COLOR := Color(0.18, 0.285, 0.295, 1.0)
const PLAYABLE_TILE_ODD_COLOR := Color(0.22, 0.335, 0.340, 1.0)
const PLAYABLE_TILE_BORDER_COLOR := Color(0.62, 0.96, 0.86, 0.36)
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
var _board_renderer_view_dirty := false
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
var _board_view_rect := Rect2()
var _tile_size := 64.0
var _fit_tile_size := 64.0
var _camera_tile_size := 64.0
var _camera_max_tile_size := 64.0
var _camera_center_tiles := Vector2(float(BOARD_COLS) * 0.5, float(BOARD_ROWS) * 0.5)
var _camera_initialized := false
var _last_board_view_size := Vector2.ZERO
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
var _hint_inventory_cursor := 0
var _hint_board_cursor := 0
var _hint_next_inventory_board := true
var _hint_text := ""
var _idle_hint_elapsed := 0.0
var _idle_hint_pulse_elapsed := IDLE_HINT_PULSE_SECONDS
var _idle_hint_disabled_after_hint := false
var _score := 0
var _game_over := false
var _full_board_pending_check := false
var _full_board_game_over_grace_elapsed := 0.0
var _run_had_new_high_score := false
var _status_text := ""
var _clear_effect_ids: Array[String] = []
var _clear_effect_elapsed := 0.0
var _pending_clear_ids: Array[String] = []
var _pending_clear_started_tick := -1
var _score_pulse_elapsed := SCORE_PULSE_SECONDS
var _high_score_pulse_elapsed := HIGH_SCORE_PULSE_SECONDS
var _high_score_sparkle_nonce := 0
var _inventory_fresh_start_msec_by_id: Dictionary = {}
var _pip_angle_by_key: Dictionary = {}
var _pip_offset_by_key: Dictionary = {}
var _pip_partner_by_key: Dictionary = {}
var _pip_layout_partner_by_key: Dictionary = {}
var _pip_layout_center_by_key: Dictionary = {}
var _pip_layout_cell_center_by_key: Dictionary = {}
var _pip_layout_cell_radius_by_key: Dictionary = {}
var _pip_returning_to_default_by_key: Dictionary = {}
var _zero_need_pip_overlay_pips: Array[Dictionary] = []
var _need_pip_layout_by_key: Dictionary = {}
var _need_pip_layout_keys_by_resource: Dictionary = {}
var _need_pip_layout_specs: Array[Dictionary] = []
var _need_pip_layout_groups: Dictionary = {}
var _visual_profile_enabled := false
var _visual_profile_print_every := 120
var _visual_profile_duration_seconds := 0.0
var _visual_profile_elapsed := 0.0

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
	if _visual_profile_enabled:
		_visual_profile_elapsed += maxf(delta, 0.0)
		queue_redraw()
		if _visual_profile_duration_seconds > 0.0 and _visual_profile_elapsed >= _visual_profile_duration_seconds:
			print(str("[cellular-arcade-profile] complete elapsed=", _visual_profile_elapsed, " score=", _score, " cells=", _board_cell_ids.size()))
			get_tree().quit()
			return
	if _game_over:
		return
	var score_pulse_active := _advance_score_pulse(delta)
	var high_score_pulse_active := _advance_high_score_pulse(delta)
	var idle_hint_active := _advance_idle_hint_nudge(delta)
	var inventory_fresh_active := _has_inventory_fresh_animation()
	var hud_pulse_active := score_pulse_active or high_score_pulse_active or idle_hint_active
	if _is_clear_effect_active():
		_reset_full_board_game_over_grace()
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
			if cleared:
				_reset_full_board_game_over_grace()
			elif _update_full_board_game_over_grace(delta):
				_show_game_over()
			queue_redraw()
		elif _update_full_board_game_over_grace(delta):
			_show_game_over()
			queue_redraw()
		elif hud_pulse_active or inventory_fresh_active:
			queue_redraw()
	elif _update_full_board_game_over_grace(delta):
		_show_game_over()
	elif _has_live_visual_animation() or hud_pulse_active or inventory_fresh_active:
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_clear_need_pip_layout_state()
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
		elif arg == "--arcade-visual-profile":
			_visual_profile_enabled = true
		elif arg.begins_with("--arcade-profile-print-every="):
			_visual_profile_print_every = maxi(1, int(arg.trim_prefix("--arcade-profile-print-every=")))
		elif arg.begins_with("--arcade-profile-duration="):
			_visual_profile_duration_seconds = maxf(0.0, float(arg.trim_prefix("--arcade-profile-duration=")))


func _try_create_board_renderer() -> void:
	var renderer_paths: Array[String] = []
	if _has_user_arg("--force-gd-renderer"):
		renderer_paths.append("res://src/CellularBoardRendererGd.gd")
	else:
		renderer_paths.append("res://src/CellularBoardRenderer.cs")
		renderer_paths.append("res://src/CellularBoardRendererGd.gd")
	for renderer_path in renderer_paths:
		if not ResourceLoader.exists(renderer_path):
			continue
		var renderer_script: Resource = load(renderer_path)
		if renderer_script == null or not renderer_script is Script:
			continue
		var instance: Variant = (renderer_script as Script).new()
		if not instance is Control:
			continue
		_board_renderer = instance as Control
		_board_renderer.name = "CellularArcadeBoardRenderer"
		(_board_renderer as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_board_renderer)
		move_child(_board_renderer, 0)
		_using_board_renderer = true
		_board_renderer_full_sync_needed = true
		return


func _has_user_arg(name: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if str(arg) == name:
			return true
	return false


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
	_game_over_score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_clear_need_pip_layout_state()
	_cell_sequence = 0
	_score = 0
	Global.score = 0
	_game_over = false
	_full_board_pending_check = false
	_full_board_game_over_grace_elapsed = 0.0
	_run_had_new_high_score = false
	_hint_pair.clear()
	_hint_inventory_cursor = 0
	_hint_board_cursor = 0
	_hint_next_inventory_board = true
	_hint_text = ""
	_enable_idle_hint_nudge()
	_status_text = ""
	_clear_effect_ids.clear()
	_clear_effect_elapsed = 0.0
	_reset_pending_clear()
	_score_pulse_elapsed = SCORE_PULSE_SECONDS
	_high_score_pulse_elapsed = HIGH_SCORE_PULSE_SECONDS
	_reset_camera_state()
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
	var need_count := _choose_normal_need_count()
	return {
		"id": "arcade-cell-%04d" % _cell_sequence,
		"kind": "Standard",
		"produced": produced,
		"needs": _choose_needs_for_resource(produced, need_count, use_inventory_context, ignored_inventory_index)
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


func _choose_normal_need_count() -> int:
	var min_needs := clampi(NORMAL_MIN_NEEDS, 1, 3)
	var max_needs := clampi(NORMAL_MAX_NEEDS, min_needs, 3)
	if min_needs == max_needs:
		return min_needs
	var total_weight := 0
	for count in range(min_needs, max_needs + 1):
		total_weight += _normal_need_count_weight(count)
	var roll := _rng.randi_range(1, maxi(1, total_weight))
	var accumulated := 0
	for count in range(min_needs, max_needs + 1):
		accumulated += _normal_need_count_weight(count)
		if roll <= accumulated:
			return count
	return max_needs


func _normal_need_count_weight(count: int) -> int:
	match count:
		1:
			return NORMAL_ONE_NEED_WEIGHT
		2:
			return NORMAL_TWO_NEEDS_WEIGHT
		3:
			return NORMAL_THREE_NEEDS_WEIGHT
		_:
			return 1


func _choose_needs_for_resource(produced: String, target_count: int, use_inventory_context: bool = false, ignored_inventory_index: int = -1) -> Array[String]:
	target_count = clampi(target_count, 1, 3)
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
	while needs.size() < target_count:
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
	if needs.size() < target_count:
		for resource in RESOURCE_LETTERS:
			if resource != produced and not needs.has(resource):
				needs.append(resource)
			if needs.size() >= target_count:
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
	_reset_full_board_game_over_grace()
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
	_reset_full_board_game_over_grace()


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
		_reset_pending_clear()
		return false
	var clear_ids: Array[String] = []
	for group in groups:
		for id in group:
			if not clear_ids.has(id):
				clear_ids.append(id)
	if clear_ids.is_empty():
		_reset_pending_clear()
		return false
	clear_ids.sort()
	var current_tick := int(_sim_snapshot.get("tick", 0))
	if not _pending_clear_matches(clear_ids):
		_pending_clear_ids = clear_ids.duplicate()
		_pending_clear_started_tick = current_tick
		_status_text = str("Amazing! ", clear_ids.size(), "-Cell Network Forming!")
		_update_hud_text()
		queue_redraw()
		return true
	_pending_clear_ids = clear_ids.duplicate()
	if current_tick - _pending_clear_started_tick < CLEAR_SETTLE_TICKS:
		_status_text = str("Amazing! ", clear_ids.size(), "-Cell Network Forming!")
		_update_hud_text()
		queue_redraw()
		return true
	var cleared_count := clear_ids.size()
	var points := cleared_count + maxi(0, cleared_count - CLEAR_GROUP_MIN_SIZE)
	var previous_high_score := int(Global.high_score)
	_score += points
	if _score > 4:
		_reset_idle_hint_nudge()
	Global.add_score(points)
	if _score > previous_high_score and int(Global.high_score) > previous_high_score:
		_run_had_new_high_score = true
		_start_high_score_pulse()
	_status_text = _clear_message(cleared_count)
	_clear_hint(false)
	_reset_pending_clear()
	_start_clear_effect(clear_ids)
	_update_hud_text()
	queue_redraw()
	return true


func _start_clear_effect(clear_ids: Array[String]) -> void:
	_clear_effect_ids.clear()
	for id in clear_ids:
		_clear_effect_ids.append(id)
	_clear_effect_elapsed = 0.0
	_reset_full_board_game_over_grace()
	_score_pulse_elapsed = 0.0
	_apply_score_pulse_visual()
	_board_renderer_full_sync_needed = true


func _clear_message(cleared_count: int) -> String:
	match cleared_count:
		4:
			return "Amazing!"
		5:
			return "Wow!"
		6:
			return "How?!"
		7:
			return "What?!"
		8:
			return "Super!"
		9:
			return "Great!"
		10:
			return "Genius!"
		_:
			return str("Break time!", cleared_count, " Cells!")


func _reset_pending_clear() -> void:
	_pending_clear_ids.clear()
	_pending_clear_started_tick = -1


func _pending_clear_matches(clear_ids: Array[String]) -> bool:
	if _pending_clear_ids.is_empty() or _pending_clear_started_tick < 0:
		return false
	for id in _pending_clear_ids:
		if not clear_ids.has(id):
			return false
	return true


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
	_reset_full_board_game_over_grace()
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
	var diagnostics: Dictionary = diagnostics_value as Dictionary
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
		for start_key in remaining.keys():
			start = str(start_key)
			break
		if start.is_empty():
			break
		remaining.erase(start)
		var component: Array[String] = []
		var queue: Array[String] = [start]
		var index := 0
		while index < queue.size():
			var current: String = str(queue[index])
			index += 1
			component.append(current)
			var current_tile := _get_cell_tile(current)
			for candidate_key in remaining.keys():
				var other := str(candidate_key)
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
	_reset_idle_hint_nudge()
	_reset_full_board_game_over_grace()
	Global.record_last_score(_score)
	_update_hud_text()
	if is_instance_valid(_game_over_panel):
		_game_over_panel.visible = true
		move_child(_game_over_panel, get_child_count() - 1)
	_layout_scene()
	queue_redraw()


func _is_board_full() -> bool:
	return _board_cell_ids.size() >= BOARD_TILE_COUNT


func _reset_full_board_game_over_grace() -> void:
	_full_board_game_over_grace_elapsed = 0.0


func _update_full_board_game_over_grace(delta: float) -> bool:
	if _game_over or _is_clear_effect_active():
		_reset_full_board_game_over_grace()
		return false
	if not _full_board_pending_check or not _is_board_full():
		_full_board_pending_check = false
		_reset_full_board_game_over_grace()
		return false
	if not _pending_clear_ids.is_empty():
		_reset_full_board_game_over_grace()
		return false
	_full_board_game_over_grace_elapsed += maxf(delta, 0.0)
	return _full_board_game_over_grace_elapsed >= FULL_BOARD_GAME_OVER_GRACE_SECONDS


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
	var top_h := 106.0 if compact_hud else 76.0
	var inventory_gap_factor := 0.22
	var inventory_h_factor := INVENTORY_SLOT_SCALE + 0.10
	var play_bottom_padding := maxf(2.0, margin * 0.35)
	var playable_h := maxf(1.0, safe_rect.size.y - top_h - play_bottom_padding)
	var combined_h_denominator := float(BOARD_ROWS) + inventory_gap_factor + inventory_h_factor
	var tile_by_w := maxf(28.0, (safe_rect.size.x - margin * 0.20) / float(BOARD_COLS))
	var tile_by_h := maxf(28.0, playable_h / combined_h_denominator)
	var max_tile := 176.0 if compact_hud else 190.0
	_fit_tile_size = floorf(clampf(minf(tile_by_w, tile_by_h), 30.0, max_tile))
	var row_available_w := maxf(1.0, safe_rect.size.x - margin * 2.0)
	var hint_w := 70.0 if compact_hud else 78.0
	var hint_h := 42.0
	var row_gap := maxf(8.0, _fit_tile_size * 0.08)
	var provisional_inventory_gap := _fit_tile_size * inventory_gap_factor
	var provisional_inventory_h := _fit_tile_size * inventory_h_factor
	var board_view_top: float = safe_rect.position.y + top_h
	var provisional_board_view_h := maxf(1.0, safe_rect.position.y + safe_rect.size.y - play_bottom_padding - board_view_top - provisional_inventory_gap - provisional_inventory_h)
	_board_view_rect = Rect2(Vector2(safe_rect.position.x, board_view_top), Vector2(safe_rect.size.x, provisional_board_view_h))
	_camera_center_tiles = Vector2(float(BOARD_COLS) * 0.5, float(BOARD_ROWS) * 0.5)
	_camera_tile_size = _fit_tile_size
	_camera_max_tile_size = _fit_tile_size
	_camera_initialized = true
	_last_board_view_size = _board_view_rect.size

	_tile_size = _fit_tile_size
	var inventory_gap := _tile_size * inventory_gap_factor
	var inventory_h := _tile_size * inventory_h_factor
	var board_view_h := maxf(1.0, safe_rect.position.y + safe_rect.size.y - play_bottom_padding - board_view_top - inventory_gap - inventory_h)
	_board_view_rect = Rect2(Vector2(safe_rect.position.x, board_view_top), Vector2(safe_rect.size.x, board_view_h))
	_camera_tile_size = _fit_tile_size
	_camera_max_tile_size = _fit_tile_size
	_camera_center_tiles = Vector2(float(BOARD_COLS) * 0.5, float(BOARD_ROWS) * 0.5)
	_clamp_arcade_camera(false)
	_update_arcade_board_rect_from_camera()

	_inventory_centers.clear()
	var inv_y := _board_view_rect.position.y + _board_view_rect.size.y + inventory_gap + inventory_h * 0.5
	var slot_size := _tile_size * INVENTORY_SLOT_SCALE
	var slot_gap := _tile_size * (INVENTORY_SLOT_SCALE + 0.12)
	row_gap = maxf(8.0, _tile_size * 0.08)
	var fit_slot_gap := (row_available_w - hint_w - row_gap - slot_size) / maxf(1.0, float(INVENTORY_SLOT_COUNT - 1))
	if fit_slot_gap >= slot_size:
		slot_gap = clampf(minf(slot_gap, fit_slot_gap), slot_size, _tile_size * (INVENTORY_SLOT_SCALE + 0.12))
	else:
		slot_gap = maxf(_tile_size * 0.90, fit_slot_gap)
	var row_width := hint_w + row_gap + slot_size + slot_gap * float(INVENTORY_SLOT_COUNT - 1)
	var row_left := _board_view_rect.position.x + _board_view_rect.size.x * 0.5 - row_width * 0.5
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
		_set_control_rect(_status_label, safe_rect.position + Vector2(margin, 88.0), Vector2(safe_rect.size.x - margin * 2.0, 32.0))
	else:
		var center_left := safe_rect.position.x + margin + menu_w + 18.0
		var center_right := safe_rect.position.x + safe_rect.size.x - margin - restart_w - 10.0
		var center_w := maxf(1.0, center_right - center_left)
		var stat_gap := 10.0
		var stat_w := maxf(90.0, (center_w - stat_gap) * 0.5)
		_set_control_rect(_score_label, Vector2(center_left, safe_rect.position.y), Vector2(stat_w, 42.0))
		_set_control_rect(_high_score_label, Vector2(center_left + stat_w + stat_gap, safe_rect.position.y), Vector2(maxf(90.0, center_w - stat_w - stat_gap), 42.0))
		_set_control_rect(_status_label, safe_rect.position + Vector2(margin, 42.0), Vector2(safe_rect.size.x - margin * 2.0, 34.0))
	_style_hud()

	if is_instance_valid(_overlay_layer):
		_set_control_rect(_overlay_layer, Vector2.ZERO, view_size)
	if is_instance_valid(_board_renderer) and _board_renderer is Control:
		var renderer_control := _board_renderer as Control
		_set_control_rect(renderer_control, Vector2.ZERO, view_size)
	_board_renderer_full_sync_needed = true
	_layout_game_over_panel(view_size)
	_update_hud_text()


func _update_arcade_board_rect_from_camera() -> void:
	var previous_board_rect := _board_rect
	var previous_tile_size := _tile_size
	_tile_size = clampf(_camera_tile_size, _fit_tile_size, _camera_max_tile_size)
	var board_size := Vector2(_tile_size * float(BOARD_COLS), _tile_size * float(BOARD_ROWS))
	var origin := _board_view_rect.get_center() - _camera_center_tiles * _tile_size
	_board_rect = Rect2(origin, board_size)
	_sync_need_pip_history_after_board_rect_change(previous_board_rect, previous_tile_size)


func _clamp_arcade_camera(resize_deadband: bool = true) -> void:
	_camera_tile_size = minf(_camera_tile_size, _camera_max_tile_size)
	if resize_deadband:
		if _camera_tile_size < _fit_tile_size:
			_camera_tile_size = _fit_tile_size
	else:
		_camera_tile_size = maxf(_camera_tile_size, _fit_tile_size)
	var visible_tiles := Vector2(_board_view_rect.size.x / _camera_tile_size, _board_view_rect.size.y / _camera_tile_size)
	if visible_tiles.x >= float(BOARD_COLS):
		_camera_center_tiles.x = float(BOARD_COLS) * 0.5
	else:
		_camera_center_tiles.x = clampf(_camera_center_tiles.x, visible_tiles.x * 0.5, float(BOARD_COLS) - visible_tiles.x * 0.5)
	if visible_tiles.y >= float(BOARD_ROWS):
		_camera_center_tiles.y = float(BOARD_ROWS) * 0.5
	else:
		_camera_center_tiles.y = clampf(_camera_center_tiles.y, visible_tiles.y * 0.5, float(BOARD_ROWS) - visible_tiles.y * 0.5)


func _layout_game_over_panel(view_size: Vector2) -> void:
	if not is_instance_valid(_game_over_panel):
		return
	var panel_size := Vector2(minf(380.0, view_size.x - 32.0), 250.0)
	var panel_pos := (view_size - panel_size) * 0.5
	_set_control_rect(_game_over_panel, panel_pos, panel_size)
	_game_over_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.07, 0.08, 0.94), Color(0.45, 1.0, 0.82, 0.84), 3, 8))
	_set_control_rect(_game_over_title, Vector2(22.0, 22.0), Vector2(panel_size.x - 44.0, 48.0))
	_set_control_rect(_game_over_score_label, Vector2(24.0, 82.0), Vector2(panel_size.x - 48.0, 76.0))
	var button_w := (panel_size.x - 52.0) * 0.5
	_set_control_rect(_game_over_restart_button, Vector2(18.0, 178.0), Vector2(button_w, 48.0))
	_set_control_rect(_game_over_menu_button, Vector2(34.0 + button_w, 178.0), Vector2(button_w, 48.0))
	_style_button(_game_over_restart_button)
	_style_button(_game_over_menu_button)
	_style_label(_game_over_title, 31, Color(0.88, 1.0, 0.96, 1.0))
	_style_label(_game_over_score_label, 22, Color(0.78, 0.95, 0.92, 1.0))


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
	_style_label(_status_label, 22, Color(1.0, 0.84, 0.54, 1.0))


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


func _idle_hint_should_pause() -> bool:
	if _score > 4:
		return true
	if _visual_profile_enabled:
		return true
	if _drag_source != DRAG_SOURCE_NONE:
		return true
	return _game_over or _is_clear_effect_active()


func _advance_idle_hint_nudge(delta: float) -> bool:
	if _idle_hint_disabled_after_hint:
		if _is_idle_hint_nudge_active():
			_reset_idle_hint_nudge()
			return true
		return false
	if _idle_hint_should_pause():
		if _is_idle_hint_nudge_active():
			_reset_idle_hint_nudge()
			return true
		return false
	if _is_idle_hint_nudge_active():
		_idle_hint_pulse_elapsed = minf(IDLE_HINT_PULSE_SECONDS, _idle_hint_pulse_elapsed + maxf(delta, 0.0))
		_apply_idle_hint_nudge_visual()
		if _idle_hint_pulse_elapsed >= IDLE_HINT_PULSE_SECONDS:
			_reset_idle_hint_button_visual()
			_idle_hint_elapsed = 0.0
		return true
	_idle_hint_elapsed += maxf(delta, 0.0)
	if _idle_hint_elapsed >= IDLE_HINT_DELAY_SECONDS:
		_start_idle_hint_nudge()
		return true
	return false


func _start_idle_hint_nudge() -> void:
	_idle_hint_pulse_elapsed = 0.0
	_apply_idle_hint_nudge_visual()


func _reset_idle_hint_nudge() -> void:
	_idle_hint_elapsed = 0.0
	_idle_hint_pulse_elapsed = IDLE_HINT_PULSE_SECONDS
	_reset_idle_hint_button_visual()


func _enable_idle_hint_nudge() -> void:
	_idle_hint_disabled_after_hint = false
	_reset_idle_hint_nudge()


func _is_idle_hint_nudge_active() -> bool:
	return _idle_hint_pulse_elapsed < IDLE_HINT_PULSE_SECONDS


func _idle_hint_nudge_amount() -> float:
	if not _is_idle_hint_nudge_active():
		return 0.0
	var progress := clampf(_idle_hint_pulse_elapsed / IDLE_HINT_PULSE_SECONDS, 0.0, 1.0)
	return sin(progress * PI)


func _apply_idle_hint_nudge_visual() -> void:
	if not is_instance_valid(_hint_button):
		return
	var pulse := _idle_hint_nudge_amount()
	var scale := 1.0 + (IDLE_HINT_MAX_SCALE - 1.0) * pulse
	_hint_button.pivot_offset = _hint_button.size * 0.5
	_hint_button.scale = Vector2(scale, scale)
	_hint_button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.38, 1.0).lerp(Color(0.92, 1.0, 0.96, 1.0), 1.0 - pulse * 0.55))
	_hint_button.add_theme_constant_override("outline_size", 3 + int(roundf(pulse * 3.0)))


func _reset_idle_hint_button_visual() -> void:
	if not is_instance_valid(_hint_button):
		return
	_hint_button.scale = Vector2.ONE
	_hint_button.pivot_offset = _hint_button.size * 0.5
	_hint_button.add_theme_color_override("font_color", Color(0.92, 1.0, 0.96, 1.0))
	_hint_button.add_theme_constant_override("outline_size", 3)


func _draw_idle_hint_nudge() -> void:
	if not is_instance_valid(_hint_button) or not _is_idle_hint_nudge_active():
		return
	var pulse := _idle_hint_nudge_amount()
	if pulse <= 0.0:
		return
	var rect := Rect2(_hint_button.position, _hint_button.size)
	var center := rect.get_center()
	var radius := maxf(rect.size.x, rect.size.y) * (0.54 + pulse * 0.24)
	var teal := Color(0.36, 1.0, 0.78, 0.18 + pulse * 0.18)
	var gold := Color(1.0, 0.88, 0.22, 0.22 + pulse * 0.24)
	draw_circle(center, radius * 1.22, Color(teal.r, teal.g, teal.b, teal.a * pulse))
	draw_circle(center, radius, Color(gold.r, gold.g, gold.b, gold.a * pulse))
	draw_rect(rect.grow(4.0 + pulse * 8.0), Color(1.0, 0.90, 0.22, 0.10 + pulse * 0.18), false, 2.0 + pulse * 2.0)


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
		_status_label.add_theme_font_size_override("font_size", _status_font_size(_status_label.text))
	if is_instance_valid(_game_over_score_label):
		_game_over_score_label.text = _game_over_score_text()


func _game_over_score_text() -> String:
	var cleared_text := str(Global.format_score_value(_score), " Cells Cleared!")
	if _run_had_new_high_score:
		return str(cleared_text, "\nHigh Score!")
	return str(cleared_text, "\nMost Cells Cleared ", Global.format_score_value(Global.high_score))


func _status_font_size(text: String) -> int:
	if text.length() > 36:
		return 18
	if text.length() > 28:
		return 20
	return 22


func _draw_arcade_overlay(layer: Control) -> void:
	if not _using_board_renderer:
		_clear_need_pip_frame_layouts()
		_prepare_fallback_need_pip_layouts()
		_draw_fallback_board(layer, false)
		_draw_inventory(layer, false)
		_draw_hint_overlay(layer)
		_draw_fallback_board_cells(layer)
		_draw_inventory(layer, true)
		_draw_inventory_drag(layer)
		_draw_zero_need_pip_overlays(layer)
	_draw_clear_effect_overlay(layer)
	_draw_high_score_sparkles(layer)


func _prepare_fallback_need_pip_layouts() -> void:
	for id in _board_cell_ids:
		var cell: Dictionary = _board_cells.get(id, {})
		var dragging := _drag_source == DRAG_SOURCE_BOARD and id == _drag_cell_id
		var center := _drag_position if dragging else _tile_center(_get_cell_tile(id))
		_add_fallback_need_pip_layout_specs_for_cell(cell, center, dragging)
	_layout_fallback_need_pip_specs()


func _clear_need_pip_frame_layouts() -> void:
	_zero_need_pip_overlay_pips.clear()
	_need_pip_layout_by_key.clear()
	_need_pip_layout_keys_by_resource.clear()
	_need_pip_layout_specs.clear()
	_need_pip_layout_groups.clear()


func _clear_need_pip_layout_state() -> void:
	_clear_need_pip_frame_layouts()
	_pip_angle_by_key.clear()
	_pip_offset_by_key.clear()
	_pip_partner_by_key.clear()
	_pip_layout_partner_by_key.clear()
	_pip_layout_center_by_key.clear()
	_pip_layout_cell_center_by_key.clear()
	_pip_layout_cell_radius_by_key.clear()
	_pip_returning_to_default_by_key.clear()


func _sync_need_pip_history_after_board_rect_change(previous_board_rect: Rect2, previous_tile_size: float) -> void:
	var had_previous_geometry := previous_tile_size > 0.0 and previous_board_rect.size.x > 1.0 and previous_board_rect.size.y > 1.0
	if not had_previous_geometry:
		return
	var scale_changed := absf(previous_tile_size - _tile_size) > 0.01
	var size_changed := (previous_board_rect.size - _board_rect.size).length_squared() > 0.01
	if scale_changed or size_changed:
		_clear_need_pip_layout_state()
	else:
		_translate_need_pip_layout_history(_board_rect.position - previous_board_rect.position)


func _translate_need_pip_layout_history(delta: Vector2) -> void:
	if delta.length_squared() <= 0.0001:
		return
	_translate_vector_history(_pip_layout_center_by_key, delta)
	_translate_vector_history(_pip_layout_cell_center_by_key, delta)


func _translate_vector_history(history: Dictionary, delta: Vector2) -> void:
	for key in history.keys():
		var value: Variant = history.get(key, null)
		if value is Vector2:
			history[key] = (value as Vector2) + delta


func _add_fallback_need_pip_layout_specs_for_cell(cell: Dictionary, center: Vector2, dragging: bool) -> void:
	var cell_id := str(cell.get("id", ""))
	if cell_id.is_empty():
		return
	var is_myco := str(cell.get("kind", "Standard")) == "RedMyco"
	var needs_value: Variant = cell.get("needs", [])
	if not needs_value is Array:
		return
	var needs: Array = needs_value as Array
	var pip_count := 4 if is_myco else needs.size()
	var radius := _tile_size * (0.41 if dragging else 0.38)
	var pip_radius := maxf(7.0, minf(radius * 0.34, _tile_size * 0.15))
	for index in range(pip_count):
		if index >= needs.size():
			if is_myco:
				_add_fallback_need_pip_layout_spec({
					"key": _fallback_pip_slot_key(cell_id, index),
					"cell": cell_id,
					"need": "",
					"index": index,
					"count": pip_count,
					"cellCenter": center,
					"cellRadius": radius,
					"pipRadius": pip_radius,
					"partner": "",
					"fullness": 1.0,
					"visualScale": 1.0,
					"isMyco": is_myco,
					"dragging": dragging,
					"hasLiveState": false,
					"laidOut": false
				})
			continue
		var need := str(needs[index])
		var partner := _fallback_stabilize_need_partner(cell_id, need, index, _fallback_need_partner(cell_id, need))
		var fullness := _slot_fullness(cell_id, need)
		_add_fallback_need_pip_layout_spec({
			"key": _fallback_pip_key(cell_id, need, index),
			"cell": cell_id,
			"need": need,
			"index": index,
			"count": pip_count,
			"cellCenter": center,
			"cellRadius": radius,
			"pipRadius": pip_radius,
			"partner": partner,
			"fullness": fullness,
			"visualScale": 1.0,
			"isMyco": is_myco,
			"dragging": dragging,
			"hasLiveState": _using_csharp_sim and _cell_state_by_id.has(cell_id),
			"laidOut": false
		})


func _add_fallback_need_pip_layout_spec(spec: Dictionary) -> void:
	_need_pip_layout_specs.append(spec)
	var partner := str(spec.get("partner", ""))
	if partner.is_empty():
		return
	var group_key := _need_pip_edge_group_key(str(spec.get("cell", "")), partner)
	if not _need_pip_layout_groups.has(group_key):
		_need_pip_layout_groups[group_key] = []
	var group_value: Variant = _need_pip_layout_groups.get(group_key, [])
	if group_value is Array:
		(group_value as Array).append(spec)


func _layout_fallback_need_pip_specs() -> void:
	for group_value in _need_pip_layout_groups.values():
		if not group_value is Array:
			continue
		var group: Array = group_value as Array
		if group.is_empty():
			continue
		group.sort_custom(Callable(self, "_compare_need_pip_layout_specs"))
		var max_pip_radius := 0.0
		for spec_value in group:
			if spec_value is Dictionary:
				max_pip_radius = maxf(max_pip_radius, float((spec_value as Dictionary).get("pipRadius", 0.0)))
		var lane_spacing := max_pip_radius * NEED_PIP_LANE_FOOTPRINT_SCALE * 2.0 + NEED_PIP_LANE_MARGIN
		var lane_center := float(group.size() - 1) * 0.5
		for lane in range(group.size()):
			var spec_value: Variant = group[lane]
			if not spec_value is Dictionary:
				continue
			var spec: Dictionary = spec_value as Dictionary
			_store_fallback_provider_need_pip_layout(spec, (float(lane) - lane_center) * lane_spacing)
			spec["laidOut"] = true
	for spec in _need_pip_layout_specs:
		if not bool(spec.get("laidOut", false)):
			_store_fallback_default_need_pip_layout(spec)


func _store_fallback_provider_need_pip_layout(spec: Dictionary, lane_offset: float) -> void:
	var partner := str(spec.get("partner", ""))
	var cell_center: Vector2 = spec.get("cellCenter", Vector2.ZERO) as Vector2
	var partner_center := _cell_visual_center(partner)
	if partner_center == HINT_MISSING_CENTER:
		_store_fallback_default_need_pip_layout(spec)
		return
	var delta := partner_center - cell_center
	if delta.length_squared() <= 1.0:
		_store_fallback_default_need_pip_layout(spec)
		return
	var direction := delta.normalized()
	var base_offset := _fallback_need_target_offset(str(spec.get("cell", "")), str(spec.get("need", "")), float(spec.get("cellRadius", 0.0)), bool(spec.get("dragging", false)), partner)
	var lane_direction := _need_pip_edge_lane_direction(str(spec.get("cell", "")), partner)
	var lane_vector := direction * base_offset + lane_direction * lane_offset
	if lane_vector.length_squared() <= 0.0001:
		_store_fallback_default_need_pip_layout(spec)
		return
	_store_fallback_need_pip_layout(spec, cell_center + lane_vector.normalized() * base_offset)


func _store_fallback_default_need_pip_layout(spec: Dictionary) -> void:
	var index := int(spec.get("index", 0))
	var count := int(spec.get("count", 1))
	var cell_center: Vector2 = spec.get("cellCenter", Vector2.ZERO) as Vector2
	var angle := -PI * 0.5 + TAU * float(index) / maxf(float(count), 1.0)
	var offset := _fallback_need_target_offset(str(spec.get("cell", "")), str(spec.get("need", "")), float(spec.get("cellRadius", 0.0)), bool(spec.get("dragging", false)), "")
	_store_fallback_need_pip_layout(spec, cell_center + Vector2(cos(angle), sin(angle)) * offset)


func _store_fallback_need_pip_layout(spec: Dictionary, target_center: Vector2) -> void:
	var key := str(spec.get("key", ""))
	var cell := str(spec.get("cell", ""))
	var need := str(spec.get("need", ""))
	var index := int(spec.get("index", 0))
	var count := int(spec.get("count", 1))
	var cell_center: Vector2 = spec.get("cellCenter", Vector2.ZERO) as Vector2
	var is_myco := bool(spec.get("isMyco", false))
	var slot_key := _fallback_pip_slot_key(cell, index) if is_myco else ""
	var delta := target_center - cell_center
	var target_angle := delta.angle() if delta.length_squared() > 0.0001 else -PI * 0.5 + TAU * float(index) / maxf(float(count), 1.0)
	var target_offset := delta.length() if delta.length_squared() > 0.0001 else _fallback_need_target_offset(cell, need, float(spec.get("cellRadius", 0.0)), bool(spec.get("dragging", false)), str(spec.get("partner", "")))
	var cell_radius := float(spec.get("cellRadius", 0.0))
	var partner := str(spec.get("partner", ""))
	if not bool(spec.get("dragging", false)):
		_seed_pip_smoothing_from_previous_center(key, cell_center, cell_radius, slot_key)
	var returning_to_default := _pip_returning_to_default(key, partner, slot_key)
	var angle := _fallback_smooth_pip_angle(key, target_angle, PIP_ANGLE_RETURN_SMOOTH if returning_to_default else PIP_ANGLE_SMOOTH)
	var offset := _fallback_smooth_pip_offset(key, target_offset, PIP_OFFSET_RETURN_SMOOTH if returning_to_default else PIP_OFFSET_SMOOTH)
	_stop_pip_return_to_default_if_settled(key, returning_to_default, angle, target_angle, offset, target_offset)
	var center := cell_center + Vector2(cos(angle), sin(angle)) * offset
	var layout := {
		"key": key,
		"cell": cell,
		"need": need,
		"index": index,
		"partner": partner,
		"cellCenter": cell_center,
		"center": center,
		"angle": angle,
		"radius": float(spec.get("pipRadius", 0.0)),
		"fullness": float(spec.get("fullness", 0.0)),
		"visualScale": float(spec.get("visualScale", 1.0)),
		"hasLiveState": bool(spec.get("hasLiveState", false)),
		"cellRadius": float(spec.get("cellRadius", 0.0))
	}
	_need_pip_layout_by_key[key] = layout
	_pip_layout_partner_by_key[key] = partner
	_pip_layout_center_by_key[key] = center
	_pip_layout_cell_center_by_key[key] = cell_center
	_pip_layout_cell_radius_by_key[key] = cell_radius
	if is_myco:
		_pip_layout_partner_by_key[slot_key] = partner
		_pip_layout_center_by_key[slot_key] = center
		_pip_layout_cell_center_by_key[slot_key] = cell_center
		_pip_layout_cell_radius_by_key[slot_key] = cell_radius
	if need.is_empty():
		return
	var lookup_key := _need_lookup_key(cell, need)
	if not _need_pip_layout_keys_by_resource.has(lookup_key):
		_need_pip_layout_keys_by_resource[lookup_key] = []
	var keys_value: Variant = _need_pip_layout_keys_by_resource.get(lookup_key, [])
	if keys_value is Array:
		(keys_value as Array).append(key)


func _fallback_need_target_offset(cell_id: String, need: String, radius: float, dragging: bool, partner: String) -> float:
	if not partner.is_empty():
		return radius * (1.10 if dragging else 1.08)
	if _slot_fullness(cell_id, need) > 0.0:
		return radius * 1.02
	return radius * 1.18


func _need_pip_edge_lane_direction(cell: String, partner: String) -> Vector2:
	var first := cell
	var second := partner
	if first > second:
		var tmp := first
		first = second
		second = tmp
	var delta := _cell_visual_center(second) - _cell_visual_center(first)
	if delta.length_squared() <= 1.0:
		return Vector2.RIGHT
	var direction := delta.normalized()
	return Vector2(-direction.y, direction.x)


func _need_pip_edge_group_key(cell: String, partner: String) -> String:
	if cell <= partner:
		return str("edge:", cell, ":", partner)
	return str("edge:", partner, ":", cell)


func _need_lookup_key(cell: String, resource: String) -> String:
	return str(cell, "||", resource)


func _compare_need_pip_layout_specs(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		return str((a as Dictionary).get("key", "")) < str((b as Dictionary).get("key", ""))
	return str(a) < str(b)


func _pip_returning_to_default(key: String, partner: String, fallback_key: String = "") -> bool:
	if not partner.is_empty():
		_pip_returning_to_default_by_key.erase(key)
		return false
	if _pip_returning_to_default_by_key.has(key):
		return true
	if _pip_layout_history_has_partner(key) or (not fallback_key.is_empty() and _pip_layout_history_has_partner(fallback_key)):
		_pip_returning_to_default_by_key[key] = true
		return true
	return false


func _pip_layout_history_has_partner(key: String) -> bool:
	return not str(_pip_layout_partner_by_key.get(key, "")).is_empty()


func _seed_pip_smoothing_from_previous_center(key: String, cell_center: Vector2, cell_radius: float, fallback_key: String = "") -> void:
	if _try_seed_pip_smoothing_from_previous_center(key, key, cell_center, cell_radius, true):
		return
	if not fallback_key.is_empty() and fallback_key != key and not _pip_angle_by_key.has(key) and not _pip_offset_by_key.has(key):
		_try_seed_pip_smoothing_from_previous_center(key, fallback_key, cell_center, cell_radius, false)


func _try_seed_pip_smoothing_from_previous_center(target_key: String, history_key: String, cell_center: Vector2, cell_radius: float, require_cell_center_moved: bool) -> bool:
	var previous_center_value: Variant = _pip_layout_center_by_key.get(history_key, null)
	var previous_cell_center_value: Variant = _pip_layout_cell_center_by_key.get(history_key, null)
	if not previous_center_value is Vector2 or not previous_cell_center_value is Vector2:
		return false
	var previous_cell_center: Vector2 = previous_cell_center_value as Vector2
	var previous_center: Vector2 = previous_center_value as Vector2
	var previous_radius := float(_pip_layout_cell_radius_by_key.get(history_key, 0.0))
	var radius_changed := previous_radius > 0.0001 and absf(previous_radius - cell_radius) > 0.01
	if require_cell_center_moved and (previous_cell_center - cell_center).length_squared() <= 1.0 and not radius_changed:
		return false
	var delta := previous_center - previous_cell_center
	if previous_radius > 0.0001 and cell_radius > 0.0001:
		delta *= cell_radius / previous_radius
	if delta.length_squared() <= 0.0001:
		return false
	_pip_angle_by_key[target_key] = delta.angle()
	_pip_offset_by_key[target_key] = delta.length()
	return true


func _stop_pip_return_to_default_if_settled(key: String, returning_to_default: bool, angle: float, target_angle: float, offset: float, target_offset: float) -> void:
	if not returning_to_default:
		return
	if absf(wrapf(target_angle - angle, -PI, PI)) < PIP_ANGLE_DEAD_ZONE * 2.0 and absf(target_offset - offset) < PIP_OFFSET_DEAD_ZONE * 2.0:
		_pip_returning_to_default_by_key.erase(key)


func _draw_fallback_board(layer: Control, draw_cells: bool = true) -> void:
	layer.draw_rect(_board_view_rect, Color(0.006, 0.020, 0.024, 0.72), true)
	for y in range(BOARD_ROWS):
		for x in range(BOARD_COLS):
			var rect := Rect2(_board_rect.position + Vector2(x, y) * _tile_size, Vector2(_tile_size, _tile_size)).grow(-2.0)
			if not _board_view_rect.grow(4.0).intersects(rect, true):
				continue
			var tile_color := PLAYABLE_TILE_EVEN_COLOR if (x + y) % 2 == 0 else PLAYABLE_TILE_ODD_COLOR
			layer.draw_rect(rect, tile_color, true)
			layer.draw_rect(rect, PLAYABLE_TILE_BORDER_COLOR, false, maxf(1.0, _tile_size * 0.014))
	_draw_fallback_circuit_groups(layer)
	_draw_fallback_recent_flows(layer)
	if draw_cells:
		_draw_fallback_board_cells(layer)


func _draw_fallback_board_cells(layer: Control) -> void:
	for id in _board_cell_ids:
		if _drag_source == DRAG_SOURCE_BOARD and id == _drag_cell_id:
			continue
		if not _board_view_rect.grow(_tile_size * 0.7).has_point(_tile_center(_get_cell_tile(id))):
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
		var cell_center := _inventory_visual_center(index)
		if not draw_cells:
			layer.draw_rect(shadow_rect, Color(0.0, 0.012, 0.015, 0.50), true)
			layer.draw_rect(slot_rect, Color(0.085, 0.120, 0.130, 0.98), true)
			layer.draw_rect(slot_rect.grow(-_tile_size * 0.045), Color(0.115, 0.158, 0.165, 0.55), true)
			layer.draw_rect(slot_rect.grow(-_tile_size * 0.030), Color(0.24, 0.42, 0.42, 0.20), false, maxf(1.4, _tile_size * 0.018))
			continue
		if index < _inventory_cells.size():
			if _drag_source == DRAG_SOURCE_INVENTORY and index == _drag_inventory_index:
				pass
			else:
				if fresh_strength > 0.0:
					var cell_halo_radius := _tile_size * (0.50 + burst * 0.08)
					layer.draw_circle(cell_center, cell_halo_radius, Color(1.0, 0.90, 0.28, 0.18 * fresh_strength + 0.12 * burst))
					layer.draw_arc(cell_center, cell_halo_radius * 1.04, 0.0, TAU, 42, Color(1.0, 0.90, 0.30, 0.46 * fresh_strength), maxf(3.0, _tile_size * 0.052), true)
				_draw_cell(layer, _inventory_cells[index], cell_center, false, INVENTORY_CELL_SCALE + fresh_strength * 0.10 + burst * 0.07)
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


func _draw_fallback_circuit_groups(layer: Control) -> void:
	var diagnostics_value: Variant = _sim_snapshot.get("circuitDiagnostics", {})
	if not diagnostics_value is Dictionary:
		return
	var diagnostics: Dictionary = diagnostics_value as Dictionary
	var groups_value: Variant = diagnostics.get("strongGroups", [])
	if not groups_value is Array:
		return
	var groups: Array = groups_value as Array
	var pulse := 0.5 + sin(Time.get_ticks_msec() / 170.0) * 0.5
	for group_index in range(groups.size()):
		var group_value: Variant = groups[group_index]
		if not group_value is Array:
			continue
		var cells: Array = group_value as Array
		if cells.size() < CLEAR_GROUP_MIN_SIZE:
			continue
		var all_on_board := true
		for board_check_value in cells:
			if not _board_cells.has(str(board_check_value)):
				all_on_board = false
				break
		if not all_on_board:
			continue
		var color := _fallback_group_color(group_index)
		var edge := color.lightened(0.24)
		edge.a = 0.64 + pulse * 0.20
		for circle_value in cells:
			var circle_id := str(circle_value)
			var center := _tile_center(_get_cell_tile(circle_id))
			var circle_health := _overlay_cell_health(circle_id)
			var circle_fill := _overlay_health_color(circle_health, color)
			circle_fill.a = (0.12 + pulse * 0.04) * lerpf(0.28, 1.0, _health_alpha_amount(circle_health))
			layer.draw_circle(center, _tile_size * 0.58 * lerpf(0.54, 1.04, _health_radius_amount(circle_health)), circle_fill)
		for rect_value in cells:
			var rect_id := str(rect_value)
			var tile := _get_cell_tile(rect_id)
			var rect_health := _overlay_cell_health(rect_id)
			var rect_fill := _overlay_health_color(rect_health, color)
			var rect := Rect2(_board_rect.position + Vector2(tile) * _tile_size, Vector2(_tile_size, _tile_size)).grow(-2.0)
			layer.draw_rect(rect, Color(rect_fill.r, rect_fill.g, rect_fill.b, (0.06 + pulse * 0.03) * lerpf(0.28, 1.0, _health_alpha_amount(rect_health))), true)
			layer.draw_rect(rect, edge, false, maxf(3.0, _tile_size * 0.045))


func _overlay_cell_health(cell_id: String) -> float:
	if cell_id.is_empty():
		return 1.0
	var health_info: Dictionary = _cell_need_health(cell_id)
	if not bool(health_info.get("known", false)):
		return 1.0
	return clampf(float(health_info.get("health", 1.0)), 0.0, 1.0)


func _overlay_health_color(need_health: float, _healthy_color: Color) -> Color:
	return CELL_STRESS_GLOW_COLOR.lerp(CELL_HEALTHY_GLOW_COLOR, _health_color_amount(need_health))


func _health_color_amount(need_health: float) -> float:
	return pow(clampf(need_health, 0.0, 1.0), CELL_HEALTH_COLOR_CURVE)


func _health_radius_amount(need_health: float) -> float:
	return pow(clampf(need_health, 0.0, 1.0), CELL_HEALTH_RADIUS_CURVE)


func _health_alpha_amount(need_health: float) -> float:
	return pow(clampf(need_health, 0.0, 1.0), CELL_HEALTH_ALPHA_CURVE)


func _health_pulse_amount(need_health: float) -> float:
	return pow(clampf(need_health, 0.0, 1.0), 1.35)


func _draw_fallback_recent_flows(layer: Control) -> void:
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
		if not _board_cells.has(source) or not _board_cells.has(target):
			continue
		var age := maxf(0.0, current_tick - float(flow.get("tick", current_tick)))
		var alpha := clampf(1.0 - age / 10.0, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var start := _fallback_resource_point(source, resource)
		var finish := _fallback_resource_point(target, resource)
		var color := _resource_color(resource)
		color.a = 0.24 + alpha * 0.44
		layer.draw_line(start, finish, Color(color.r, color.g, color.b, color.a * 0.42), maxf(5.0, _tile_size * 0.070), true)
		layer.draw_line(start, finish, color.lightened(0.22), maxf(2.4, _tile_size * 0.028), true)
		var t := clampf(age / 2.4, 0.0, 1.0)
		var particle := start.lerp(finish, t)
		layer.draw_circle(particle, maxf(3.0, _tile_size * 0.045), _resource_color(resource))
		layer.draw_circle(particle, maxf(3.0, _tile_size * 0.045), Color(1.0, 1.0, 1.0, 0.34 * alpha), false, 1.6)


func _fallback_group_color(index: int) -> Color:
	var colors: Array[Color] = [
		Color(0.30, 1.00, 0.84, 1.0),
		Color(1.00, 0.76, 0.26, 1.0),
		Color(0.68, 0.46, 1.00, 1.0),
		Color(0.28, 0.70, 1.00, 1.0),
		Color(1.00, 0.36, 0.58, 1.0)
	]
	return colors[index % colors.size()]


func _fallback_resource_point(cell_id: String, resource: String) -> Vector2:
	var center := _tile_center(_get_cell_tile(cell_id))
	var lookup_key := _need_lookup_key(cell_id, resource)
	var keys_value: Variant = _need_pip_layout_keys_by_resource.get(lookup_key, [])
	if not keys_value is Array:
		return center
	var keys: Array = keys_value as Array
	var found := false
	var best_index := 2147483647
	var best_center := center
	for key_value in keys:
		var layout_value: Variant = _need_pip_layout_by_key.get(str(key_value), {})
		if not layout_value is Dictionary:
			continue
		var layout: Dictionary = layout_value as Dictionary
		var index := int(layout.get("index", 0))
		if index >= best_index:
			continue
		best_index = index
		var center_value: Variant = layout.get("center", center)
		if center_value is Vector2:
			best_center = center_value as Vector2
			found = true
	return best_center if found else center


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
	var text := _clear_message(_clear_effect_ids.size())
	var font: Font = ThemeDB.fallback_font
	var font_size := int(roundf(_tile_size * (0.36 + 0.10 * scale)))
	if text.length() > 28:
		font_size = int(roundf(float(font_size) * 0.84))
	if text.length() > 36:
		font_size = int(roundf(float(font_size) * 0.76))
	font_size = maxi(font_size, 22)
	var width := minf(_board_rect.size.x * 0.96, _tile_size * (6.2 + scale * 2.4))
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
			return _inventory_visual_center(index)
	return HINT_MISSING_CENTER


func _draw_cell(layer: Control, cell: Dictionary, center: Vector2, dragging: bool, visual_scale: float = 1.0) -> void:
	var produced := str(cell.get("produced", ""))
	var kind := str(cell.get("kind", "Standard"))
	var is_myco := kind == "RedMyco"
	var label := "" if is_myco else produced
	var color := Color(0.94, 0.97, 0.94, 1.0) if is_myco else _resource_color(produced)
	var radius := _tile_size * (0.41 if dragging else 0.38) * visual_scale
	var cell_id := str(cell.get("id", ""))
	var body_glow_color := color
	var glow_alpha := 0.52 if _cell_is_glowing(cell_id) else 0.18
	var glow_health := 1.0
	var glow_alpha_health := 1.0
	var need_health_info: Dictionary = _cell_need_health(cell_id)
	if bool(need_health_info.get("known", false)):
		var need_health := float(need_health_info.get("health", 1.0))
		var color_health := _health_color_amount(need_health)
		var radius_health := _health_radius_amount(need_health)
		var alpha_health := _health_alpha_amount(need_health)
		glow_health = radius_health
		glow_alpha_health = alpha_health
		body_glow_color = CELL_STRESS_GLOW_COLOR.lerp(CELL_HEALTHY_GLOW_COLOR, color_health)
		glow_alpha = lerpf(CELL_STRESS_GLOW_STRENGTH, CELL_HEALTHY_GLOW_STRENGTH, alpha_health)
	var glow_radius_scale := lerpf(CELL_STRESS_GLOW_RADIUS_SCALE, CELL_HEALTHY_GLOW_RADIUS_SCALE, glow_health)
	var glow_alpha_scale := lerpf(CELL_STRESS_GLOW_ALPHA_SCALE, CELL_HEALTHY_GLOW_ALPHA_SCALE, glow_alpha_health)
	var glow_alpha_value := glow_alpha * glow_alpha_scale
	var glow_thickness := maxf(0.0, glow_radius_scale - 1.0)
	layer.draw_circle(center, radius * glow_radius_scale, Color(body_glow_color.r, body_glow_color.g, body_glow_color.b, glow_alpha_value * CELL_GLOW_OUTER_ALPHA_FRACTION))
	layer.draw_circle(center, radius * (1.0 + glow_thickness * CELL_GLOW_MID_RADIUS_FRACTION), Color(body_glow_color.r, body_glow_color.g, body_glow_color.b, glow_alpha_value * CELL_GLOW_MID_ALPHA_FRACTION))
	layer.draw_circle(center, radius * (1.0 + glow_thickness * CELL_GLOW_INNER_RADIUS_FRACTION), Color(body_glow_color.r, body_glow_color.g, body_glow_color.b, glow_alpha_value * CELL_GLOW_INNER_ALPHA_FRACTION))
	layer.draw_circle(center + Vector2(0.0, radius * 0.08), radius * 1.04, Color(0.0, 0.0, 0.0, 0.30))
	layer.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.74))
	layer.draw_arc(center, radius * 0.96, 0.0, TAU, 42, Color(0.95, 1.0, 0.96, 0.66), maxf(2.0, radius * 0.080), true)
	if is_myco:
		_draw_fallback_red_myco_ring(layer, center, radius)
	var font: Font = ThemeDB.fallback_font
	if not label.is_empty():
		_draw_centered_text(layer, font, center, radius, label, int(_tile_size * 0.46 * visual_scale), Color.WHITE)
	var needs_value: Variant = cell.get("needs", [])
	if needs_value is Array:
		var needs: Array = needs_value as Array
		var pip_count := 4 if is_myco else needs.size()
		var used_angles: Array[float] = []
		var normal_need_pips: Array[Dictionary] = []
		var zero_need_pips: Array[Dictionary] = []
		for index in range(pip_count):
			var pip_radius := maxf(7.0, minf(radius * 0.34, _tile_size * 0.15) * visual_scale)
			if index >= needs.size():
				var blank_layout_key := _fallback_pip_slot_key(cell_id, index)
				var blank_layout_value: Variant = _need_pip_layout_by_key.get(blank_layout_key, {})
				var pip_center := _fallback_default_myco_slot_center(center, index, pip_count, radius)
				var blank_radius := pip_radius
				if blank_layout_value is Dictionary:
					var blank_layout: Dictionary = blank_layout_value as Dictionary
					var blank_center_value: Variant = blank_layout.get("center", pip_center)
					if blank_center_value is Vector2:
						pip_center = blank_center_value as Vector2
					blank_radius = float(blank_layout.get("radius", blank_radius))
				_draw_fallback_blank_myco_pip(layer, pip_center, blank_radius)
				continue
			var need := str(needs[index])
			var key := _fallback_pip_key(cell_id, need, index)
			var pip_data := _fallback_need_pip_draw_from_layout(_need_pip_layout_by_key.get(key, {})) if _need_pip_layout_by_key.has(key) else _build_fallback_need_pip_draw(cell_id, need, index, pip_count, center, radius, pip_radius, dragging, visual_scale, used_angles)
			if _fallback_should_elevate_need_pip(pip_data):
				zero_need_pips.append(pip_data)
				_zero_need_pip_overlay_pips.append({"pip": pip_data, "cellRadius": radius})
			else:
				normal_need_pips.append(pip_data)
		for pip_data in normal_need_pips:
			_draw_fallback_need_pip(layer, font, pip_data, radius, true)
		for pip_data in zero_need_pips:
			_draw_fallback_need_pip(layer, font, pip_data, radius, true)


func _fallback_need_pip_draw_from_layout(layout_value: Variant) -> Dictionary:
	if not layout_value is Dictionary:
		return {}
	var layout: Dictionary = layout_value as Dictionary
	return {
		"cell": str(layout.get("cell", "")),
		"need": str(layout.get("need", "")),
		"cellCenter": layout.get("cellCenter", Vector2.ZERO),
		"center": layout.get("center", Vector2.ZERO),
		"angle": float(layout.get("angle", 0.0)),
		"radius": float(layout.get("radius", 0.0)),
		"fullness": float(layout.get("fullness", 0.0)),
		"visualScale": float(layout.get("visualScale", 1.0)),
		"hasLiveState": bool(layout.get("hasLiveState", false))
	}


func _build_fallback_need_pip_draw(cell_id: String, need: String, index: int, count: int, center: Vector2, radius: float, pip_radius: float, dragging: bool, visual_scale: float, used_angles: Array[float]) -> Dictionary:
	var angle := _fallback_need_angle(cell_id, need, index, count, center, used_angles)
	used_angles.append(angle)
	var pip_offset := _fallback_need_offset(cell_id, need, index, radius, dragging)
	return {
		"cell": cell_id,
		"need": need,
		"cellCenter": center,
		"center": center + Vector2(cos(angle), sin(angle)) * pip_offset,
		"angle": angle,
		"radius": pip_radius,
		"fullness": _slot_fullness(cell_id, need),
		"visualScale": visual_scale,
		"hasLiveState": _using_csharp_sim and _cell_state_by_id.has(cell_id)
	}


func _draw_fallback_blank_myco_pip(layer: Control, center: Vector2, radius: float) -> void:
	layer.draw_circle(center, radius, Color(0.92, 0.97, 0.96, 1.0))
	layer.draw_arc(center, radius, 0.0, TAU, 18, Color(0.01, 0.025, 0.03, 0.76), maxf(1.4, radius * 0.16), true)
	layer.draw_arc(center, radius * 0.84, 0.0, TAU, 18, Color(1.0, 1.0, 1.0, 0.44), maxf(1.0, radius * 0.10), true)


func _draw_fallback_need_pip(layer: Control, font: Font, pip_data: Dictionary, cell_radius: float, draw_tether: bool = true) -> void:
	var need := str(pip_data.get("need", ""))
	var cell_center: Vector2 = pip_data.get("cellCenter", Vector2.ZERO) as Vector2
	var pip_center: Vector2 = pip_data.get("center", Vector2.ZERO) as Vector2
	var angle := float(pip_data.get("angle", 0.0))
	var pip_radius := float(pip_data.get("radius", 0.0))
	var fullness := float(pip_data.get("fullness", 0.0))
	var visual_scale := float(pip_data.get("visualScale", 1.0))
	var direction := Vector2(cos(angle), sin(angle))
	if draw_tether:
		var tether := _resource_color(need)
		tether.a = 0.30
		layer.draw_line(cell_center + direction * cell_radius * 0.78, pip_center - direction * pip_radius * 0.72, tether, maxf(1.8, _tile_size * 0.018), true)
	var pip_color := _resource_color(need)
	if fullness <= 0.0:
		pip_color = pip_color.darkened(0.36)
	layer.draw_circle(pip_center, pip_radius, pip_color)
	layer.draw_arc(pip_center, pip_radius, 0.0, TAU, 18, Color(0.01, 0.025, 0.03, 0.82), maxf(1.5, pip_radius * 0.18), true)
	layer.draw_arc(pip_center, pip_radius * 0.86, 0.0, TAU, 18, Color.WHITE, maxf(1.1, pip_radius * 0.11), true)
	var pip_bar_radius := pip_radius * 1.12
	var pip_bar_width := maxf(2.0, pip_radius * 0.20)
	_draw_fallback_fullness_arc(layer, pip_center, pip_bar_radius, fullness, pip_color, pip_bar_width)
	if _fallback_should_elevate_need_pip(pip_data):
		_draw_fallback_zero_pip_pulse_arc(layer, pip_center, pip_bar_radius, pip_bar_width)
	_draw_centered_text(layer, font, pip_center, pip_radius, need, int(_tile_size * 0.15 * visual_scale * NEED_PIP_MARK_SIZE_SCALE), Color.WHITE, NEED_PIP_MARK_WEIGHT_SCALE)


func _fallback_should_elevate_need_pip(pip_data: Dictionary) -> bool:
	return bool(pip_data.get("hasLiveState", false)) and float(pip_data.get("fullness", 0.0)) <= 0.0


func _draw_zero_need_pip_overlays(layer: Control) -> void:
	if not _using_csharp_sim or _zero_need_pip_overlay_pips.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	for overlay_data in _zero_need_pip_overlay_pips:
		var pip_value: Variant = overlay_data.get("pip", {})
		if not pip_value is Dictionary:
			continue
		_draw_fallback_need_pip(layer, font, pip_value as Dictionary, float(overlay_data.get("cellRadius", 0.0)), false)


func _draw_fallback_red_myco_ring(layer: Control, center: Vector2, radius: float) -> void:
	var ring_radius := radius * 0.54
	layer.draw_arc(center, ring_radius, 0.0, TAU, 42, Color(0.86, 0.02, 0.04, 0.18), maxf(2.0, radius * 0.18), true)
	layer.draw_arc(center, ring_radius, 0.0, TAU, 42, Color(0.92, 0.04, 0.06, 0.48), maxf(1.6, radius * 0.12), true)
	layer.draw_arc(center, ring_radius, 0.0, TAU, 42, Color(0.70, 0.00, 0.02, 0.90), maxf(1.2, radius * 0.055), true)


func _draw_fallback_fullness_arc(layer: Control, center: Vector2, radius: float, fullness: float, color: Color, width: float) -> void:
	var clamped := clampf(fullness, 0.0, 1.0)
	var track := Color(0.0, 0.0, 0.0, 0.38)
	layer.draw_arc(center, radius, -PI * 0.5, TAU - PI * 0.5, 28, track, width, true)
	if clamped <= 0.0:
		return
	var active := color.lightened(0.20)
	active.a = 0.92
	layer.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clamped, 28, active, width, true)


func _draw_fallback_zero_pip_pulse_arc(layer: Control, center: Vector2, radius: float, width: float) -> void:
	var alpha := _fallback_zero_pip_pulse_alpha()
	if alpha <= 0.0:
		return
	var pulse_color := ZERO_PIP_PULSE_COLOR
	var glow_radius := radius * ZERO_PIP_PULSE_GLOW_SCALE
	pulse_color.a = minf(1.0, 0.58 * ZERO_PIP_PULSE_BRIGHTNESS_SCALE * alpha)
	layer.draw_arc(center, glow_radius, -PI * 0.5, PI * 1.5, 28, pulse_color, (width + 1.2) * ZERO_PIP_PULSE_GLOW_SCALE, true)
	pulse_color.a = minf(1.0, 0.22 * ZERO_PIP_PULSE_BRIGHTNESS_SCALE * alpha)
	layer.draw_arc(center, radius * 1.08 * ZERO_PIP_PULSE_GLOW_SCALE, -PI * 0.5, PI * 1.5, 28, pulse_color, maxf(1.4, width * 0.55) * ZERO_PIP_PULSE_GLOW_SCALE, true)


func _fallback_zero_pip_pulse_alpha() -> float:
	var phase := Time.get_ticks_msec() % ZERO_PIP_PULSE_PERIOD_MSEC
	if phase < ZERO_PIP_PULSE_FADE_MSEC:
		return float(phase) / float(ZERO_PIP_PULSE_FADE_MSEC)
	if phase < ZERO_PIP_PULSE_FADE_MSEC * 2:
		return 1.0 - float(phase - ZERO_PIP_PULSE_FADE_MSEC) / float(ZERO_PIP_PULSE_FADE_MSEC)
	return 0.0


func _fallback_need_angle(cell_id: String, need: String, index: int, count: int, center: Vector2, used_angles: Array[float], apply_smoothing: bool = true) -> float:
	var partner := _fallback_layout_partner(cell_id, need, index)
	var target_angle := -PI * 0.5 + TAU * float(index) / maxf(float(count), 1.0)
	if not partner.is_empty():
		var partner_center := _cell_visual_center(partner)
		if partner_center != HINT_MISSING_CENTER:
			var delta := partner_center - center
			if delta.length_squared() > 1.0:
				target_angle = delta.angle()
	target_angle = _fallback_separate_need_angle(target_angle, used_angles)
	return _fallback_smooth_pip_angle(_fallback_pip_key(cell_id, need, index), target_angle) if apply_smoothing else target_angle


func _fallback_need_offset(cell_id: String, need: String, index: int, radius: float, dragging: bool, apply_smoothing: bool = true) -> float:
	var target_offset := radius * 1.18
	if not _fallback_layout_partner(cell_id, need, index).is_empty():
		target_offset = radius * (1.10 if dragging else 1.08)
	elif _slot_fullness(cell_id, need) > 0.0:
		target_offset = radius * 1.02
	return _fallback_smooth_pip_offset(_fallback_pip_key(cell_id, need, index), target_offset) if apply_smoothing else target_offset


func _fallback_layout_partner(cell_id: String, need: String, index: int) -> String:
	return _fallback_stabilize_need_partner(cell_id, need, index, _fallback_need_partner(cell_id, need))


func _fallback_stabilize_need_partner(cell_id: String, need: String, index: int, proposed_partner: String) -> String:
	var key := _fallback_pip_key(cell_id, need, index)
	var current_partner := str(_pip_partner_by_key.get(key, ""))
	if not current_partner.is_empty() and _fallback_is_usable_need_partner(cell_id, need, current_partner):
		return current_partner
	if not proposed_partner.is_empty() and _fallback_is_usable_need_partner(cell_id, need, proposed_partner):
		_pip_partner_by_key[key] = proposed_partner
		return proposed_partner
	_pip_partner_by_key.erase(key)
	return ""


func _fallback_is_usable_need_partner(cell_id: String, need: String, partner: String) -> bool:
	if cell_id.is_empty() or partner.is_empty():
		return false
	if _board_cells.has(cell_id) and _board_cells.has(partner):
		return _get_cell_tile(cell_id).distance_squared_to(_get_cell_tile(partner)) == 1 and _cell_can_offer_resource(partner, need)
	return _cell_can_offer_resource(partner, need)


func _fallback_need_partner(cell_id: String, need: String) -> String:
	if cell_id.is_empty() or need.is_empty():
		return ""
	var hinted := _hint_partner_for_cell(cell_id)
	if not hinted.is_empty() and _cell_can_offer_resource(hinted, need):
		return hinted
	var possible_partner := _possible_swap_partner_for_need(cell_id, need)
	if not possible_partner.is_empty():
		return possible_partner
	var inventory_partner := _board_partner_for_inventory_need(cell_id, need)
	if not inventory_partner.is_empty():
		return inventory_partner
	var adjacent_partner := _adjacent_partner_for_need(cell_id, need)
	if not adjacent_partner.is_empty():
		return adjacent_partner
	return ""


func _hint_partner_for_cell(cell_id: String) -> String:
	if _hint_pair.size() != 2:
		return ""
	var first := str(_hint_pair[0])
	var second := str(_hint_pair[1])
	if first == cell_id:
		return second
	if second == cell_id:
		return first
	return ""


func _recent_flow_partner_for_need(cell_id: String, need: String) -> String:
	var flows_value: Variant = _sim_snapshot.get("flows", [])
	if not flows_value is Array:
		return ""
	var current_tick := float(_sim_snapshot.get("tick", 0))
	var best_partner := ""
	var best_age := 999999.0
	var flows: Array = flows_value as Array
	for flow_value in flows:
		if not flow_value is Dictionary:
			continue
		var flow := flow_value as Dictionary
		if str(flow.get("resource", "")) != need:
			continue
		var source := str(flow.get("sourceCellId", ""))
		var target := str(flow.get("targetCellId", ""))
		if target != cell_id:
			continue
		var age := maxf(0.0, current_tick - float(flow.get("tick", current_tick)))
		if age < best_age:
			best_age = age
			best_partner = source
	return best_partner


func _possible_swap_partner_for_need(cell_id: String, need: String) -> String:
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
		if initiator == cell_id and str(swap.get("counterpartyPaidResource", "")) == need:
			return counterparty
		if counterparty == cell_id and str(swap.get("initiatorPaidResource", "")) == need:
			return initiator
	return ""


func _adjacent_partner_for_need(cell_id: String, need: String) -> String:
	if not _board_cells.has(cell_id):
		return ""
	var tile := _get_cell_tile(cell_id)
	var best_partner := ""
	var best_score := -1.0
	for other_id in _board_cell_ids:
		if other_id == cell_id:
			continue
		if tile.distance_squared_to(_get_cell_tile(other_id)) != 1:
			continue
		if not _cell_can_offer_resource(other_id, need):
			continue
		var score := 10.0
		var other_doc := _cell_doc_by_id(other_id)
		if _cell_needs_resource_doc(other_doc, _cell_produced_resource_doc(_cell_doc_by_id(cell_id))):
			score += 5.0
		if score > best_score or (is_equal_approx(score, best_score) and other_id < best_partner):
			best_score = score
			best_partner = other_id
	return best_partner


func _board_partner_for_inventory_need(cell_id: String, need: String) -> String:
	if _board_cells.has(cell_id):
		return ""
	var cell := _cell_doc_by_id(cell_id)
	if cell.is_empty():
		return ""
	var best_partner := ""
	var best_score := -1.0
	for board_id in _board_cell_ids:
		if not _cell_can_offer_resource(board_id, need):
			continue
		var board_cell: Dictionary = _board_cells.get(board_id, {})
		var score := _inventory_hint_score(cell, board_cell)
		if _cell_needs_resource_doc(board_cell, _cell_produced_resource_doc(cell)):
			score += 4.0
		if score > best_score or (is_equal_approx(score, best_score) and board_id < best_partner):
			best_score = score
			best_partner = board_id
	return best_partner


func _cell_can_offer_resource(cell_id: String, resource: String) -> bool:
	if cell_id.is_empty() or resource.is_empty():
		return false
	var cell := _cell_doc_by_id(cell_id)
	if cell.is_empty():
		return false
	for offered in _cell_offer_resources(cell):
		if offered == resource:
			return true
	return false


func _cell_doc_by_id(cell_id: String) -> Dictionary:
	if _board_cells.has(cell_id):
		return _board_cells.get(cell_id, {}) as Dictionary
	for cell in _inventory_cells:
		if str(cell.get("id", "")) == cell_id:
			return cell
	return {}


func _cell_visual_center(cell_id: String) -> Vector2:
	if _drag_cell_id == cell_id:
		return _drag_position
	if _board_cells.has(cell_id):
		return _tile_center(_get_cell_tile(cell_id))
	for index in range(_inventory_cells.size()):
		if index >= _inventory_centers.size():
			continue
		if str(_inventory_cells[index].get("id", "")) == cell_id:
			return _inventory_visual_center(index)
	return HINT_MISSING_CENTER


func _cell_produced_resource_doc(cell: Dictionary) -> String:
	return str(cell.get("produced", ""))


func _fallback_separate_need_angle(base_angle: float, used_angles: Array[float]) -> float:
	if used_angles.is_empty():
		return base_angle
	var minimum_gap := NEED_PIP_MINIMUM_ANGLE_GAP
	var fan_step := NEED_PIP_FAN_ANGLE_STEP
	var offsets: Array[float] = [0.0, fan_step, -fan_step, fan_step * 2.0, -fan_step * 2.0]
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


func _fallback_pip_key(cell_id: String, need: String, index: int) -> String:
	return str(cell_id, ":", need, ":", index)


func _fallback_pip_slot_key(cell_id: String, index: int) -> String:
	return str(cell_id, ":__slot__:", index)


func _fallback_default_myco_slot_center(center: Vector2, index: int, count: int, radius: float) -> Vector2:
	var angle := -PI * 0.5 + TAU * float(index) / maxf(float(count), 1.0)
	return center + Vector2(cos(angle), sin(angle)) * radius * 1.18


func _fallback_smooth_pip_angle(key: String, target_angle: float, smooth: float = PIP_ANGLE_SMOOTH) -> float:
	if not _pip_angle_by_key.has(key):
		_pip_angle_by_key[key] = target_angle
		return target_angle
	var current := float(_pip_angle_by_key.get(key, target_angle))
	var delta := wrapf(target_angle - current, -PI, PI)
	if absf(delta) < PIP_ANGLE_DEAD_ZONE:
		return current
	var smoothed := current + delta * smooth
	_pip_angle_by_key[key] = smoothed
	return smoothed


func _fallback_smooth_pip_offset(key: String, target_offset: float, smooth: float = PIP_OFFSET_SMOOTH) -> float:
	if not _pip_offset_by_key.has(key):
		_pip_offset_by_key[key] = target_offset
		return target_offset
	var current := float(_pip_offset_by_key.get(key, target_offset))
	if absf(target_offset - current) < PIP_OFFSET_DEAD_ZONE:
		return current
	var smoothed := lerpf(current, target_offset, smooth)
	_pip_offset_by_key[key] = smoothed
	return smoothed


func _cell_is_glowing(cell_id: String) -> bool:
	var state_value: Variant = _cell_state_by_id.get(cell_id, {})
	if state_value is Dictionary:
		return bool((state_value as Dictionary).get("glowing", false))
	return false


func _slot_fullness(cell_id: String, resource: String) -> float:
	var state_value: Variant = _cell_state_by_id.get(cell_id, {})
	if not state_value is Dictionary:
		return 0.0
	var slots_value: Variant = (state_value as Dictionary).get("slots", [])
	if not slots_value is Array:
		return 0.0
	var slots: Array = slots_value as Array
	for slot_value in slots:
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value as Dictionary
		if str(slot.get("resource", "")) == resource:
			return clampf(float(slot.get("fullness", 0.0)), 0.0, 1.0)
	return 0.0


func _cell_need_health(cell_id: String) -> Dictionary:
	var state_value: Variant = _cell_state_by_id.get(cell_id, {})
	if not state_value is Dictionary:
		return {"known": false, "health": 1.0}
	var slots_value: Variant = (state_value as Dictionary).get("slots", [])
	if not slots_value is Array:
		return {"known": false, "health": 1.0}
	var health := 1.0
	var met_need_count := 0
	var need_count := 0
	var found_need := false
	# Health is the fraction of live Need slots with any resource, so variable
	# need counts scale without assuming three pips.
	var slots: Array = slots_value as Array
	for slot_value in slots:
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value as Dictionary
		if str(slot.get("role", "")) != "Need":
			continue
		found_need = true
		need_count += 1
		if int(slot.get("quantity", 0)) > 0 or float(slot.get("fullness", 0.0)) > 0.0:
			met_need_count += 1
	if found_need:
		health = clampf(float(met_need_count) / float(maxi(1, need_count)), 0.0, 1.0)
	return {"known": found_need, "health": health}


func _draw_centered_text(layer: Control, font: Font, center: Vector2, radius: float, text: String, font_size: int, color: Color, mark_weight_scale: float = 1.0) -> void:
	if text.is_empty():
		return
	var width := radius * 2.0
	var origin := Vector2(center.x - radius, center.y + float(font_size) * 0.35)
	var outline := Color(0.01, 0.025, 0.03, 0.88)
	var outline_offset := 1.4 * mark_weight_scale
	layer.draw_string(font, origin + Vector2(-outline_offset, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	layer.draw_string(font, origin + Vector2(outline_offset, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	layer.draw_string(font, origin + Vector2(0.0, -outline_offset), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	layer.draw_string(font, origin + Vector2(0.0, outline_offset), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	layer.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
	layer.draw_string(font, origin + Vector2(0.7 * mark_weight_scale, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _sync_board_renderer() -> void:
	if not is_instance_valid(_board_renderer) or not _board_renderer.has_method("set_render_state"):
		_using_board_renderer = false
		return
	var view_updated := false
	if _board_renderer_has_state and not _board_renderer_full_sync_needed and _board_renderer_view_dirty:
		if _board_renderer.has_method("set_view_state"):
			_board_renderer.call("set_view_state", _board_rect, _board_view_rect, _tile_size)
			_board_renderer_view_dirty = false
			view_updated = true
		else:
			_board_renderer_full_sync_needed = true
	if _drag_source == DRAG_SOURCE_BOARD and _board_renderer_has_state and not _board_renderer_full_sync_needed and _board_renderer.has_method("set_drag_state"):
		_board_renderer.call("set_drag_state", _drag_cell_id, _drag_position, _drag_original_tile, false)
		return
	if _board_renderer_has_state and not _board_renderer_full_sync_needed:
		if not view_updated and _board_renderer is CanvasItem:
			(_board_renderer as CanvasItem).queue_redraw()
		return
	var state := {
		"boardRect": _board_rect,
		"boardViewportRect": _board_view_rect,
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
		"usingSimState": is_instance_valid(_sim_bridge) and not _sim_snapshot.is_empty(),
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
		"visualProfileEnabled": _visual_profile_enabled,
		"visualProfilePrintEvery": _visual_profile_print_every
	}
	_board_renderer.call("set_render_state", state)
	_board_renderer_full_sync_needed = false
	_board_renderer_view_dirty = false
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
	_draw_idle_hint_nudge()
	_sync_board_renderer()
	if is_instance_valid(_overlay_layer):
		_overlay_layer.queue_redraw()


func _reset_camera_state() -> void:
	_camera_initialized = false
	_camera_center_tiles = Vector2(float(BOARD_COLS) * 0.5, float(BOARD_ROWS) * 0.5)
	_camera_tile_size = 64.0
	_camera_max_tile_size = 64.0
	_last_board_view_size = Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if _game_over or _is_clear_effect_active():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				if _drag_source == DRAG_SOURCE_NONE:
					_begin_drag(mouse_event.position, -1)
			else:
				if _drag_source != DRAG_SOURCE_NONE:
					_finish_drag(mouse_event.position)
	elif event is InputEventMouseMotion:
		if _drag_source != DRAG_SOURCE_NONE:
			_update_drag((event as InputEventMouseMotion).position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _drag_source == DRAG_SOURCE_NONE:
				_begin_drag(touch.position, touch.index)
		else:
			if _drag_source != DRAG_SOURCE_NONE and touch.index == _drag_touch_id:
				_finish_drag(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _drag_source != DRAG_SOURCE_NONE and drag.index == _drag_touch_id:
			_update_drag(drag.position)


func _begin_drag(screen_pos: Vector2, touch_id: int = -1) -> bool:
	var board_cell := _board_cell_at(screen_pos)
	if not board_cell.is_empty():
		_reset_idle_hint_nudge()
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
		_reset_idle_hint_nudge()
		_clear_hint(false)
		_drag_source = DRAG_SOURCE_INVENTORY
		_drag_cell_id = str(_inventory_cells[inventory_index].get("id", ""))
		_drag_inventory_index = inventory_index
		_drag_touch_id = touch_id
		_drag_position = _inventory_visual_center(inventory_index)
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
	_reset_idle_hint_nudge()
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
			var cell_to_place: Dictionary = _inventory_cells[_drag_inventory_index].duplicate(true)
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
		if index < _inventory_cells.size() and _inventory_visual_center(index).distance_to(screen_pos) <= _tile_size * 0.64:
			return index
	return -1


func _inventory_visual_center(index: int) -> Vector2:
	if index < 0 or index >= _inventory_centers.size():
		return HINT_MISSING_CENTER
	return _inventory_centers[index] + Vector2(0.0, _tile_size * INVENTORY_CELL_Y_OFFSET)


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
	_idle_hint_disabled_after_hint = true
	_reset_idle_hint_nudge()
	var candidates: Array = _arcade_hint_candidates()
	if candidates.is_empty():
		_hint_pair.clear()
		_hint_text = "No useful connection found"
		_board_renderer_full_sync_needed = true
		_update_hud_text()
		queue_redraw()
		return
	var inventory_candidates: Array = []
	var board_candidates: Array = []
	for candidate_value in candidates:
		if not candidate_value is Dictionary:
			continue
		var candidate_entry: Dictionary = candidate_value as Dictionary
		var candidate_kind := str(candidate_entry.get("kind", ""))
		if candidate_kind == "inventory":
			inventory_candidates.append(candidate_entry)
		elif candidate_kind == "board":
			board_candidates.append(candidate_entry)
	var candidate: Dictionary = _select_arcade_hint_candidate(inventory_candidates, board_candidates)
	if candidate.is_empty():
		_hint_pair.clear()
		_hint_text = "No useful connection found"
		_board_renderer_full_sync_needed = true
		_update_hud_text()
		queue_redraw()
		return
	_hint_pair = [str(candidate.get("a", "")), str(candidate.get("b", ""))]
	_hint_text = str(candidate.get("text", "Hint: connect these cells"))
	_board_renderer_full_sync_needed = true
	_update_hud_text()
	queue_redraw()


func _select_arcade_hint_candidate(inventory_candidates: Array, board_candidates: Array) -> Dictionary:
	if not inventory_candidates.is_empty() and not board_candidates.is_empty():
		if _hint_next_inventory_board:
			var inventory_candidate: Dictionary = inventory_candidates[_hint_inventory_cursor % inventory_candidates.size()] as Dictionary
			_hint_inventory_cursor += 1
			_hint_next_inventory_board = false
			return inventory_candidate
		var board_candidate: Dictionary = board_candidates[_hint_board_cursor % board_candidates.size()] as Dictionary
		_hint_board_cursor += 1
		_hint_next_inventory_board = true
		return board_candidate
	if not inventory_candidates.is_empty():
		var inventory_only_candidate: Dictionary = inventory_candidates[_hint_inventory_cursor % inventory_candidates.size()] as Dictionary
		_hint_inventory_cursor += 1
		_hint_next_inventory_board = false
		return inventory_only_candidate
	if not board_candidates.is_empty():
		var board_only_candidate: Dictionary = board_candidates[_hint_board_cursor % board_candidates.size()] as Dictionary
		_hint_board_cursor += 1
		_hint_next_inventory_board = true
		return board_only_candidate
	return {}


func _clear_hint(update_hud: bool = true) -> void:
	_hint_pair.clear()
	_hint_text = ""
	_board_renderer_full_sync_needed = true
	if update_hud:
		_update_hud_text()
		queue_redraw()


func _arcade_hint_candidates() -> Array:
	var candidates: Array = []
	var component_ids_by_cell: Dictionary = _board_component_ids_by_cell()
	for inv_cell in _inventory_cells:
		for board_id in _board_cell_ids:
			var board_cell: Dictionary = _board_cells.get(board_id, {})
			var board_component_ids: Array[String] = _component_ids_for_board_cell(board_id, component_ids_by_cell)
			var inventory_score := _inventory_hint_score_for_component(inv_cell, board_cell, board_component_ids)
			if inventory_score <= 0.0:
				continue
			candidates.append({
				"a": str(inv_cell.get("id", "")),
				"b": board_id,
				"kind": "inventory",
				"score": inventory_score + 100.0,
				"text": str("Hint: place ", _cell_hint_mark(inv_cell), " next to ", _cell_hint_mark(board_cell))
			})
	for i in range(_board_cell_ids.size()):
		for j in range(i + 1, _board_cell_ids.size()):
			var a_id := _board_cell_ids[i]
			var b_id := _board_cell_ids[j]
			if _get_cell_tile(a_id).distance_squared_to(_get_cell_tile(b_id)) == 1:
				continue
			var a_component_ids: Array[String] = _component_ids_for_board_cell(a_id, component_ids_by_cell)
			var b_component_ids: Array[String] = _component_ids_for_board_cell(b_id, component_ids_by_cell)
			if _components_overlap(a_component_ids, b_component_ids):
				continue
			var a_cell: Dictionary = _board_cells.get(a_id, {})
			var b_cell: Dictionary = _board_cells.get(b_id, {})
			var board_score := _hint_pair_score_for_components(a_cell, b_cell, a_component_ids, b_component_ids)
			if board_score <= 0.0:
				continue
			candidates.append({
				"a": a_id,
				"b": b_id,
				"kind": "board",
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
	var component_ids_by_cell: Dictionary = _board_component_ids_by_cell()
	var board_id := str(board_cell.get("id", ""))
	var board_component_ids: Array[String] = _component_ids_for_board_cell(board_id, component_ids_by_cell)
	return _inventory_hint_score_for_component(inventory_cell, board_cell, board_component_ids)


func _inventory_hint_score_for_component(inventory_cell: Dictionary, board_cell: Dictionary, board_component_ids: Array[String]) -> float:
	var board_id := str(board_cell.get("id", ""))
	if board_component_ids.is_empty() and not board_id.is_empty():
		board_component_ids = [board_id]
	var inventory_to_board: Dictionary = _hint_cell_to_component_score(inventory_cell, board_component_ids, board_id)
	var board_to_inventory: Dictionary = _hint_component_to_cell_score(board_component_ids, board_id, inventory_cell)
	var forward_score := float(inventory_to_board.get("score", 0.0))
	var reverse_score := float(board_to_inventory.get("score", 0.0))
	var forward_matches := int(inventory_to_board.get("matches", 0))
	var reverse_matches := int(board_to_inventory.get("matches", 0))
	var forward_empty_matches := int(inventory_to_board.get("emptyMatches", 0))
	var inventory_is_red_myco := _cell_is_red_myco(inventory_cell)
	if forward_matches <= 0 and reverse_matches <= 0:
		return 0.0
	if forward_matches <= 0 and not inventory_is_red_myco:
		return 0.0
	if reverse_matches <= 0 and forward_empty_matches <= 0 and not inventory_is_red_myco:
		return 0.0
	var score := forward_score + reverse_score
	if forward_matches > 0 and reverse_matches > 0:
		score += 90.0
	elif forward_matches > 0:
		score = forward_score * 0.22 + float(forward_empty_matches) * 12.0
	if forward_empty_matches > 0:
		score += float(forward_empty_matches) * (60.0 if reverse_matches > 0 else 0.0)
	if inventory_is_red_myco:
		score += 35.0
	return score


func _hint_pair_score(a: Dictionary, b: Dictionary) -> float:
	var component_ids_by_cell: Dictionary = _board_component_ids_by_cell()
	var a_component_ids: Array[String] = _component_ids_for_board_cell(str(a.get("id", "")), component_ids_by_cell)
	var b_component_ids: Array[String] = _component_ids_for_board_cell(str(b.get("id", "")), component_ids_by_cell)
	if _components_overlap(a_component_ids, b_component_ids):
		return 0.0
	return _hint_pair_score_for_components(a, b, a_component_ids, b_component_ids)


func _hint_pair_score_for_components(a: Dictionary, b: Dictionary, a_component_ids: Array[String], b_component_ids: Array[String]) -> float:
	var a_id := str(a.get("id", ""))
	var b_id := str(b.get("id", ""))
	var a_to_b: Dictionary = _hint_component_to_component_score(a_component_ids, b_component_ids, a_id, b_id)
	var b_to_a: Dictionary = _hint_component_to_component_score(b_component_ids, a_component_ids, b_id, a_id)
	var a_to_b_matches := int(a_to_b.get("matches", 0))
	var b_to_a_matches := int(b_to_a.get("matches", 0))
	if a_to_b_matches <= 0 and b_to_a_matches <= 0:
		return 0.0
	var match_count := a_to_b_matches + b_to_a_matches
	var empty_match_count := int(a_to_b.get("emptyMatches", 0)) + int(b_to_a.get("emptyMatches", 0))
	var direct_match_count := int(a_to_b.get("directMatches", 0)) + int(b_to_a.get("directMatches", 0))
	var has_red_myco := _cell_is_red_myco(a) or _cell_is_red_myco(b)
	var score := float(a_to_b.get("score", 0.0)) + float(b_to_a.get("score", 0.0))
	if a_to_b_matches > 0 and b_to_a_matches > 0:
		score += 120.0
		score += float(empty_match_count) * 44.0
		score += float(direct_match_count) * 28.0
	else:
		if match_count < 2 and not has_red_myco:
			return 0.0
		score *= 0.12
		score += float(empty_match_count) * 4.0
		score += float(maxi(0, match_count - 1)) * 3.0
	if has_red_myco:
		score += 18.0
	return score


func _board_component_ids_by_cell() -> Dictionary:
	var result: Dictionary = {}
	var all_ids: Array[String] = []
	for id in _board_cell_ids:
		all_ids.append(id)
	for component_value in _connected_board_subgroups(all_ids):
		var component_ids := _strings_from_variant_array(component_value)
		for id in component_ids:
			result[id] = component_ids
	return result


func _component_ids_for_board_cell(cell_id: String, component_ids_by_cell: Dictionary) -> Array[String]:
	var component_ids: Array[String] = []
	var value: Variant = component_ids_by_cell.get(cell_id, [])
	if value is Array:
		for id_value in value as Array:
			var id := str(id_value)
			if _board_cells.has(id) and not component_ids.has(id):
				component_ids.append(id)
	if component_ids.is_empty() and _board_cells.has(cell_id):
		component_ids.append(cell_id)
	return component_ids


func _components_overlap(a_component_ids: Array[String], b_component_ids: Array[String]) -> bool:
	for id in a_component_ids:
		if b_component_ids.has(id):
			return true
	return false


func _hint_cell_to_component_score(source_cell: Dictionary, target_component_ids: Array[String], target_focus_id: String) -> Dictionary:
	var source_offers := _hint_offer_resources_for_cell(source_cell, target_component_ids)
	return _hint_offers_to_component_score(source_offers, target_component_ids, target_focus_id)


func _hint_component_to_cell_score(source_component_ids: Array[String], source_focus_id: String, target_cell: Dictionary) -> Dictionary:
	var target_context_ids: Array[String] = []
	for context_id in source_component_ids:
		target_context_ids.append(context_id)
	var target_needs := _hint_need_resources_for_cell(target_cell, target_context_ids)
	var target_id := str(target_cell.get("id", ""))
	var result := _empty_hint_score()
	for source_id in source_component_ids:
		var source_cell: Dictionary = _board_cells.get(source_id, {})
		var source_offers := _hint_offer_resources_for_cell(source_cell, [])
		var source_is_focus := source_id == source_focus_id
		for resource in source_offers:
			if not target_needs.has(resource):
				continue
			var need_is_empty := _cell_need_is_empty(target_id, resource)
			var weight := 10.0
			if source_is_focus and need_is_empty:
				weight = 42.0
			elif source_is_focus or need_is_empty:
				weight = 24.0
			_add_hint_match_score(result, weight, need_is_empty, source_is_focus)
	return result


func _hint_component_to_component_score(source_component_ids: Array[String], target_component_ids: Array[String], source_focus_id: String, target_focus_id: String) -> Dictionary:
	var result := _empty_hint_score()
	for source_id in source_component_ids:
		var source_cell: Dictionary = _board_cells.get(source_id, {})
		var source_offers := _hint_offer_resources_for_cell(source_cell, [])
		var source_is_focus := source_id == source_focus_id
		if source_offers.is_empty():
			continue
		for target_id in target_component_ids:
			var target_cell: Dictionary = _board_cells.get(target_id, {})
			var target_needs := _hint_need_resources_for_cell(target_cell, target_component_ids)
			var target_is_focus := target_id == target_focus_id
			for resource in source_offers:
				if not target_needs.has(resource):
					continue
				var need_is_empty := _cell_need_is_empty(target_id, resource)
				var weight := 10.0
				if source_is_focus and target_is_focus:
					weight = 70.0 if need_is_empty else 44.0
				elif source_is_focus or target_is_focus:
					weight = 44.0 if need_is_empty else 24.0
				elif need_is_empty:
					weight = 24.0
				_add_hint_match_score(result, weight, need_is_empty, source_is_focus and target_is_focus)
	return result


func _hint_offers_to_component_score(offer_resources: Array[String], target_component_ids: Array[String], target_focus_id: String) -> Dictionary:
	var result := _empty_hint_score()
	for target_id in target_component_ids:
		var target_cell: Dictionary = _board_cells.get(target_id, {})
		var target_needs := _hint_need_resources_for_cell(target_cell, target_component_ids)
		var target_is_focus := target_id == target_focus_id
		for resource in offer_resources:
			if not target_needs.has(resource):
				continue
			var need_is_empty := _cell_need_is_empty(target_id, resource)
			var weight := 16.0
			if target_is_focus and need_is_empty:
				weight = 58.0
			elif target_is_focus or need_is_empty:
				weight = 34.0
			_add_hint_match_score(result, weight, need_is_empty, target_is_focus)
	return result


func _empty_hint_score() -> Dictionary:
	return {
		"score": 0.0,
		"matches": 0,
		"emptyMatches": 0,
		"directMatches": 0
	}


func _add_hint_match_score(score_data: Dictionary, weight: float, empty_match: bool, direct_match: bool) -> void:
	score_data["score"] = float(score_data.get("score", 0.0)) + weight
	score_data["matches"] = int(score_data.get("matches", 0)) + 1
	if empty_match:
		score_data["emptyMatches"] = int(score_data.get("emptyMatches", 0)) + 1
	if direct_match:
		score_data["directMatches"] = int(score_data.get("directMatches", 0)) + 1


func _hint_offer_resources_for_cell(cell: Dictionary, context_component_ids: Array[String]) -> Array[String]:
	if _cell_is_red_myco(cell):
		var red_myco_needs := _cell_need_resources_doc(cell)
		var id := str(cell.get("id", ""))
		if red_myco_needs.is_empty() and not _board_cells.has(id):
			return _predict_myco_resources_for_component(context_component_ids)
		return red_myco_needs
	var resources: Array[String] = []
	var produced := str(cell.get("produced", ""))
	if not produced.is_empty():
		resources.append(produced)
	return resources


func _hint_need_resources_for_cell(cell: Dictionary, context_component_ids: Array[String]) -> Array[String]:
	if _cell_is_red_myco(cell):
		var red_myco_needs := _cell_need_resources_doc(cell)
		var id := str(cell.get("id", ""))
		if red_myco_needs.is_empty() and not _board_cells.has(id):
			return _predict_myco_resources_for_component(context_component_ids)
		return red_myco_needs
	return _cell_need_resources_doc(cell)


func _predict_myco_resources_for_component(component_ids: Array[String]) -> Array[String]:
	var resources: Array[String] = []
	for id in component_ids:
		var cell: Dictionary = _board_cells.get(id, {})
		for offer in _cell_offer_resources(cell):
			_append_unique_hint_resource(resources, offer)
			if resources.size() >= 4:
				return resources
	for id in component_ids:
		var cell: Dictionary = _board_cells.get(id, {})
		for need in _cell_need_resources_doc(cell):
			_append_unique_hint_resource(resources, need)
			if resources.size() >= 4:
				return resources
	return resources


func _append_unique_hint_resource(resources: Array[String], resource: String) -> void:
	if not resource.is_empty() and not resources.has(resource):
		resources.append(resource)


func _cell_need_resources_doc(cell: Dictionary) -> Array[String]:
	var resources: Array[String] = []
	var needs_value: Variant = cell.get("needs", [])
	if not needs_value is Array:
		return resources
	for need in needs_value:
		var resource := str(need)
		if not resource.is_empty() and not resources.has(resource):
			resources.append(resource)
	return resources


func _cell_need_is_empty(cell_id: String, resource: String) -> bool:
	if cell_id.is_empty() or resource.is_empty():
		return false
	var state_value: Variant = _cell_state_by_id.get(cell_id, {})
	if not state_value is Dictionary:
		return false
	var slots_value: Variant = (state_value as Dictionary).get("slots", [])
	if not slots_value is Array:
		return false
	for slot_value in slots_value as Array:
		if not slot_value is Dictionary:
			continue
		var slot := slot_value as Dictionary
		if str(slot.get("role", "")) != "Need":
			continue
		if str(slot.get("resource", "")) != resource:
			continue
		return int(slot.get("quantity", 0)) <= 0 and float(slot.get("fullness", 0.0)) <= 0.0
	return false


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
