extends Control

const BOARD_SIZE := 8
const RESOURCE_LETTERS := [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
	"M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X",
	"Y", "Z"
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
const ZERO_PIP_PULSE_PERIOD_MSEC := 3000
const ZERO_PIP_PULSE_FADE_MSEC := 1000
const ZERO_PIP_PULSE_COLOR := Color(1.0, 0.04, 0.02, 1.0)
const NEED_STATE_MISSING := "missing"
const NEED_STATE_AVAILABLE := "available"
const NEED_STATE_ACTIVE := "active"
const NEED_STATE_SATISFIED := "satisfied"
const CELL_KIND_STANDARD := "Standard"
const CELL_KIND_WHITE_MYCO := "WhiteMyco"
const CELL_KIND_RED_MYCO := "RedMyco"
const MYCO_MAX_NEEDS := 4
const RED_MYCO_RING_RADIUS := 0.54
const RED_MYCO_RING_EDGE_COLOR := Color(0.86, 0.02, 0.04, 0.16)
const RED_MYCO_RING_MID_COLOR := Color(0.92, 0.04, 0.06, 0.44)
const RED_MYCO_RING_CORE_COLOR := Color(0.70, 0.00, 0.02, 0.88)
const CAMERA_READABLE_TILE_SIZE := 72.0
const CAMERA_TINY_READABLE_TILE_SIZE := 64.0
const CAMERA_MIN_VISIBLE_TILES_AT_MAX_ZOOM := 4.0
const CAMERA_ZOOM_STEP := 1.18
const CAMERA_PINCH_MIN_DISTANCE := 18.0
const CAMERA_RESIZE_TILE_EPSILON := 0.25
const PUZZLE_STATE_VERSION := 1
const PUZZLE_STATE_SAVE_PATH := "user://cellular_puzzle_state.cfg"
const VELOCITY_WINDOW_TICKS := 10
const HINT_RECENT_MEMORY := 5
const HINT_TOP_RANDOM_WINDOW := 8
const HINT_TOP_SCORE_FALLOFF := 160.0
const HUD_LANDSCAPE_ENTER_RATIO := 1.14
const HUD_LANDSCAPE_INITIAL_RATIO := 1.08
const HUD_LANDSCAPE_EXIT_RATIO := 1.02
const SAFE_EDGE_MARGIN_DEFAULT := 12.0
const SAFE_EDGE_MARGIN_COMPACT := 9.0
const SAFE_EDGE_MARGIN_TINY := 6.0
const MOBILE_SAFE_TOP_FALLBACK_MIN := 18.0
const MOBILE_SAFE_TOP_FALLBACK_MAX := 52.0
const MOBILE_SAFE_SIDE_FALLBACK_PORTRAIT_MIN := 8.0
const MOBILE_SAFE_SIDE_FALLBACK_PORTRAIT_MAX := 28.0
const MOBILE_SAFE_SIDE_FALLBACK_LANDSCAPE_MIN := 18.0
const MOBILE_SAFE_SIDE_FALLBACK_LANDSCAPE_MAX := 64.0
const MOBILE_SAFE_BOTTOM_FALLBACK_MIN := 10.0
const MOBILE_SAFE_BOTTOM_FALLBACK_MAX := 36.0
const MARK_MODE_LETTERS := 0
const MARK_MODE_SYMBOLS := 1
const MARK_MODE_HIDDEN := 2
const RESOURCE_SYMBOL_MARKS := [
	"+", "*", "#", "@", "$", "%", "&", "!",
	"?", "=", "~", "^", "<", ">", "/", "\\",
	":", ";", "|", "_", "x", "o", "[", "]",
	"{", "}"
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
const FINAL_PUZZLE_LEVEL := 44

var _level_number := 1
var _cells: Array[String] = []
var _needs := {}
var _positions := {}
var _produced_by_cell := {}
var _cell_kind_by_id := {}
var _rocks := {}
var _original_drag_tile := Vector2i.ZERO
var _drag_cell := ""
var _drag_touch_id := -1
var _drag_offset := Vector2.ZERO
var _drag_position := Vector2.ZERO
var _board_rect := Rect2()
var _board_view_rect := Rect2()
var _tile_size := 64.0
var _fit_tile_size := 64.0
var _camera_tile_size := 64.0
var _camera_center_tiles := Vector2.ZERO
var _camera_initialized := false
var _last_camera_board_size := Vector2i.ZERO
var _last_board_view_size := Vector2.ZERO
var _hud_orientation_initialized := false
var _hud_landscape := false
var _hud_relayout_queued := false
var _pan_active := false
var _pan_last_pos := Vector2.ZERO
var _pan_touch_id := -1
var _touch_points := {}
var _pinch_active := false
var _pinch_touch_a := -1
var _pinch_touch_b := -1
var _pinch_last_distance := 0.0
var _pinch_last_center := Vector2.ZERO
var _board_cols := BOARD_SIZE
var _board_rows := BOARD_SIZE
var _solved := false
var _back_button: Button = null
var _reset_button: Button = null
var _hint_button: Button = null
var _zoom_in_button: Button = null
var _zoom_out_button: Button = null
var _info_button: Button = null
var _last_button: Button = null
var _next_button: Button = null
var _level_label: Label = null
var _status_label: Label = null
var _flow_label: Label = null
var _info_panel: Panel = null
var _info_label: Label = null
var _info_close_button: Button = null
var _final_win_panel: Panel = null
var _final_win_title: Label = null
var _final_win_menu_button: Button = null
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
var _recent_hint_keys: Array[String] = []
var _solution_positions: Dictionary = {}
var _resource_mark_mode := MARK_MODE_LETTERS
var _circuit_overlay_enabled := true
var _pip_angle_by_key: Dictionary = {}
var _pip_offset_by_key: Dictionary = {}
var _display_fullness_by_key: Dictionary = {}
var _last_draw_msec := 0
var _frame_blend := 1.0
var _myco_rng := RandomNumberGenerator.new()
var _white_myco_count := 0
var _red_myco_count := 0
var _fixture_override_path := ""
var _visual_profile_enabled := false
var _visual_profile_print_every := 120
var _visual_profile_duration_seconds := 0.0
var _visual_profile_elapsed := 0.0
var _latest_report := ""
var _latest_report_dirty := false
var _level_high_velocity := 0
var _level_high_velocity_dirty := false
var _final_win_announced := false


func _ready() -> void:
	Global.reset_gameplay_speed()
	Global.mode = "puzzle"
	_myco_rng.randomize()
	_parse_puzzle_debug_args()
	_sim_bridge = get_node_or_null("/root/CellularSim")
	_create_hud()
	_try_create_board_renderer()
	_load_level(_clamp_puzzle_level(Global.cellular_puzzle_current_level))
	set_process(true)
	queue_redraw()


func _exit_tree() -> void:
	_save_puzzle_level_state()


func _process(delta: float) -> void:
	if _visual_profile_enabled:
		_visual_profile_elapsed += maxf(delta, 0.0)
		queue_redraw()
		if _visual_profile_duration_seconds > 0.0 and _visual_profile_elapsed >= _visual_profile_duration_seconds:
			print(str("[cellular-puzzle-profile] complete level=", _level_number, " fixture=", _fixture_override_path, " elapsed=", _visual_profile_elapsed))
			get_tree().quit()
			return
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
		elif key_event.keycode == KEY_H:
			_on_hint_pressed()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_N:
			_on_next_pressed(true)
		elif key_event.keycode == KEY_W:
			_spawn_myco(CELL_KIND_WHITE_MYCO)
		elif key_event.keycode == KEY_R:
			_spawn_myco(CELL_KIND_RED_MYCO)


func _parse_puzzle_debug_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--puzzle-level="):
			Global.cellular_puzzle_current_level = _clamp_puzzle_level(int(arg.trim_prefix("--puzzle-level=")))
		elif arg.begins_with("--puzzle-fixture="):
			_fixture_override_path = _normalize_fixture_override_path(arg.trim_prefix("--puzzle-fixture="))
		elif arg == "--puzzle-visual-profile":
			_visual_profile_enabled = true
		elif arg.begins_with("--puzzle-profile-print-every="):
			_visual_profile_print_every = maxi(1, int(arg.trim_prefix("--puzzle-profile-print-every=")))
		elif arg.begins_with("--puzzle-profile-duration="):
			_visual_profile_duration_seconds = maxf(0.0, float(arg.trim_prefix("--puzzle-profile-duration=")))


func _normalize_fixture_override_path(path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed.is_empty():
		return ""
	if trimmed.begins_with("res://") or trimmed.begins_with("user://") or trimmed.begins_with("/"):
		return trimmed
	return str("res://", trimmed)


func _clamp_puzzle_level(level_number: int) -> int:
	return clampi(maxi(1, level_number), 1, FINAL_PUZZLE_LEVEL)


func _is_final_puzzle_level() -> bool:
	return _level_number >= FINAL_PUZZLE_LEVEL


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

	_zoom_out_button = Button.new()
	_zoom_out_button.name = "ZoomOutButton"
	_zoom_out_button.text = "-"
	_zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	add_child(_zoom_out_button)

	_zoom_in_button = Button.new()
	_zoom_in_button.name = "ZoomInButton"
	_zoom_in_button.text = "+"
	_zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	add_child(_zoom_in_button)

	_last_button = Button.new()
	_last_button.name = "LastLevelButton"
	_last_button.text = "Prev"
	_last_button.pressed.connect(_on_last_pressed)
	add_child(_last_button)

	_next_button = Button.new()
	_next_button.name = "NextLevelButton"
	_next_button.text = "Next"
	_next_button.visible = false
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

	_info_panel = Panel.new()
	_info_panel.name = "LatestInfoPanel"
	_info_panel.visible = false
	add_child(_info_panel)

	_info_label = Label.new()
	_info_label.name = "LatestInfoLabel"
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_info_panel.add_child(_info_label)

	_info_close_button = Button.new()
	_info_close_button.name = "LatestInfoCloseButton"
	_info_close_button.text = "x"
	_info_close_button.pressed.connect(_on_info_close_pressed)
	_info_panel.add_child(_info_close_button)

	_final_win_panel = Panel.new()
	_final_win_panel.name = "FinalPuzzleWinPanel"
	_final_win_panel.visible = false
	_final_win_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_final_win_panel)

	_final_win_title = Label.new()
	_final_win_title.name = "FinalPuzzleWinTitle"
	_final_win_title.text = "You Won!"
	_final_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_win_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_final_win_panel.add_child(_final_win_title)

	_final_win_menu_button = Button.new()
	_final_win_menu_button.name = "FinalPuzzleMainMenuButton"
	_final_win_menu_button.text = "Main Menu"
	_final_win_menu_button.pressed.connect(_on_final_win_main_menu_pressed)
	_final_win_panel.add_child(_final_win_menu_button)
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
	button.custom_minimum_size = Vector2(44, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	_apply_cellular_button_style(button)


func _style_compact_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.custom_minimum_size = Vector2(44, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 23)
	_apply_cellular_button_style(button)


func _apply_cellular_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color(0.92, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.36, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.04, 0.06, 0.045, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.03, 0.92))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_stylebox_override("normal", _make_cellular_button_style(Color(0.045, 0.085, 0.085, 0.94), Color(0.36, 0.92, 0.76, 0.54)))
	button.add_theme_stylebox_override("hover", _make_cellular_button_style(Color(0.065, 0.13, 0.12, 0.98), Color(0.78, 1.0, 0.70, 0.88)))
	button.add_theme_stylebox_override("pressed", _make_cellular_button_style(Color(0.98, 0.78, 0.20, 0.98), Color(1.0, 0.96, 0.48, 1.0)))


func _make_cellular_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
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


func _layout_hud() -> void:
	var view_size := get_viewport_rect().size
	var view_rect := Rect2(Vector2.ZERO, view_size)
	var safe_rect := _get_padded_safe_view_rect()
	if safe_rect.size.x <= 1.0 or safe_rect.size.y <= 1.0:
		safe_rect = view_rect.grow(-12.0)
	var margin := _get_safe_edge_margin()
	var landscape := _resolve_hud_landscape(safe_rect)
	_style_button(_back_button)
	_style_button(_reset_button)
	_style_button(_hint_button)
	_style_compact_button(_zoom_out_button)
	_style_compact_button(_zoom_in_button)
	_style_button(_last_button)
	_style_button(_next_button)
	if is_instance_valid(_status_label):
		_status_label.visible = false
	if landscape:
		_layout_hud_landscape(safe_rect, margin)
	else:
		_layout_hud_portrait(safe_rect, margin)
	_layout_info_panel(safe_rect, landscape, margin)
	_layout_final_win_panel(safe_rect, landscape, margin)
	_update_info_button_state()
	if is_instance_valid(_board_renderer) and _board_renderer is Control:
		var renderer := _board_renderer as Control
		_set_control_rect(renderer, Vector2.ZERO, view_size)


func _request_hud_relayout() -> void:
	if _hud_relayout_queued:
		return
	_hud_relayout_queued = true
	call_deferred("_apply_queued_hud_relayout")


func _apply_queued_hud_relayout() -> void:
	_hud_relayout_queued = false
	_layout_hud()
	queue_redraw()


func _resolve_hud_landscape(safe_rect: Rect2) -> bool:
	var ratio: float = safe_rect.size.x / maxf(safe_rect.size.y, 1.0)
	if not _hud_orientation_initialized:
		_hud_landscape = ratio > HUD_LANDSCAPE_INITIAL_RATIO
		_hud_orientation_initialized = true
	elif _hud_landscape:
		if ratio < HUD_LANDSCAPE_EXIT_RATIO:
			_hud_landscape = false
	elif ratio > HUD_LANDSCAPE_ENTER_RATIO:
		_hud_landscape = true
	return _hud_landscape


func _set_board_view_rect(pos: Vector2, rect_size: Vector2) -> void:
	_board_view_rect = Rect2(
		Vector2(round(pos.x), round(pos.y)),
		Vector2(round(maxf(rect_size.x, 1.0)), round(maxf(rect_size.y, 1.0)))
	)


func _layout_hud_portrait(safe_rect: Rect2, margin: float) -> void:
	var top_height: float = 78.0
	var button_h: float = 44.0
	var button_y: float = safe_rect.position.y + round((top_height - button_h) * 0.5)
	_update_next_button_state()
	var wide_controls: Array = [_hint_button, _zoom_out_button, _zoom_in_button, _last_button, _next_button]
	var wide_widths: Array = [84.0, 46.0, 46.0, 88.0, 88.0]
	var row_available_width: float = maxf(1.0, safe_rect.size.x - _portrait_button_row_side_buffer(safe_rect) * 2.0)
	var use_two_rows: bool = _portrait_button_row_total_width(wide_controls, wide_widths, 12.0) > row_available_width
	var bottom_height: float = 102.0 if use_two_rows else 58.0
	if is_instance_valid(_back_button):
		_set_control_rect(_back_button, safe_rect.position + Vector2(margin, round((top_height - button_h) * 0.5)), Vector2(92, button_h))
	if is_instance_valid(_reset_button):
		_set_control_rect(_reset_button, Vector2(safe_rect.position.x + safe_rect.size.x - margin - 92.0, button_y), Vector2(92, button_h))
	if is_instance_valid(_level_label):
		_set_control_rect(_level_label, safe_rect.position + Vector2(104.0 + margin, 2.0), Vector2(maxf(1.0, safe_rect.size.x - 208.0 - margin * 2.0), 34.0))
		_style_label(_level_label, 25, Color(0.92, 1.0, 0.96, 1.0))
	if use_two_rows:
		_layout_portrait_button_row([_hint_button, _zoom_out_button, _zoom_in_button], [84.0, 46.0, 46.0], safe_rect.position.y + safe_rect.size.y - bottom_height + 5.0, safe_rect)
		_layout_portrait_button_row([_last_button, _next_button], [88.0, 88.0], safe_rect.position.y + safe_rect.size.y - 48.0, safe_rect)
	else:
		_layout_portrait_button_row(wide_controls, wide_widths, safe_rect.position.y + safe_rect.size.y - bottom_height + round((bottom_height - button_h) * 0.5), safe_rect)
	if is_instance_valid(_last_button):
		_last_button.disabled = _level_number <= 1
	if is_instance_valid(_next_button):
		_update_next_button_state()
	if is_instance_valid(_flow_label):
		_set_control_rect(_flow_label, safe_rect.position + Vector2(margin, 35.0), Vector2(maxf(1.0, safe_rect.size.x - margin * 2.0), 36.0))
		_style_label(_flow_label, 15 if safe_rect.size.x < 520.0 else 16, Color(1.0, 0.86, 0.36, 1.0))
	var board_top: float = safe_rect.position.y + top_height + 10.0
	var board_bottom: float = safe_rect.position.y + safe_rect.size.y - bottom_height - 8.0
	_set_board_view_rect(Vector2(safe_rect.position.x + margin, board_top), Vector2(maxf(1.0, safe_rect.size.x - margin * 2.0), maxf(1.0, board_bottom - board_top)))


func _portrait_button_row_total_width(controls: Array, widths: Array, gap: float) -> float:
	var total_width: float = 0.0
	var visible_count := 0
	for index in range(controls.size()):
		var candidate: Control = controls[index] as Control
		if not is_instance_valid(candidate) or not candidate.visible:
			continue
		visible_count += 1
		total_width += maxf(float(widths[index]), _minimum_portrait_button_width(candidate))
	if visible_count <= 0:
		return 0.0
	return total_width + gap * float(visible_count - 1)


func _portrait_button_width_total(widths: Array, gap: float) -> float:
	if widths.is_empty():
		return 0.0
	var total_width: float = 0.0
	for width_value in widths:
		total_width += float(width_value)
	return total_width + gap * float(widths.size() - 1)


func _portrait_button_row_side_buffer(safe_rect: Rect2) -> float:
	return minf(24.0, maxf(12.0, safe_rect.size.x * 0.035))


func _minimum_portrait_button_width(control: Control) -> float:
	var button := control as Button
	if not is_instance_valid(button):
		return 34.0
	var text_length := button.text.length()
	if text_length >= 4:
		return 82.0
	if text_length >= 3:
		return 74.0
	if text_length >= 2:
		return 52.0
	return 42.0


func _layout_portrait_button_row(controls: Array, widths: Array, row_y: float, safe_rect: Rect2) -> void:
	var visible_controls: Array = []
	var visible_widths: Array = []
	for index in range(controls.size()):
		var candidate: Control = controls[index] as Control
		if not is_instance_valid(candidate) or not candidate.visible:
			continue
		visible_controls.append(candidate)
		visible_widths.append(maxf(float(widths[index]), _minimum_portrait_button_width(candidate)))
	if visible_controls.is_empty():
		return
	var side_buffer: float = _portrait_button_row_side_buffer(safe_rect)
	var row_width: float = maxf(1.0, safe_rect.size.x - side_buffer * 2.0)
	var gap: float = 12.0
	var total_width: float = _portrait_button_width_total(visible_widths, gap)
	if total_width > row_width:
		gap = 8.0
		total_width = _portrait_button_width_total(visible_widths, gap)
	if total_width > row_width:
		var width_sum: float = 0.0
		for width_value in visible_widths:
			width_sum += float(width_value)
		var available_width: float = maxf(1.0, row_width - gap * float(visible_widths.size() - 1))
		var scale: float = available_width / maxf(width_sum, 1.0)
		for shrink_index in range(visible_widths.size()):
			var shrink_control: Control = visible_controls[shrink_index] as Control
			visible_widths[shrink_index] = maxf(_minimum_portrait_button_width(shrink_control), floor(float(visible_widths[shrink_index]) * scale))
		total_width = _portrait_button_width_total(visible_widths, gap)
	if total_width > row_width:
		var excess: float = total_width - row_width
		for reduce_index in range(visible_widths.size()):
			if excess <= 0.0:
				break
			var current_width: float = float(visible_widths[reduce_index])
			var reduce_control: Control = visible_controls[reduce_index] as Control
			var reduction: float = minf(excess, maxf(0.0, current_width - _minimum_portrait_button_width(reduce_control)))
			visible_widths[reduce_index] = current_width - reduction
			excess -= reduction
		total_width = _portrait_button_width_total(visible_widths, gap)
	var row_x: float = safe_rect.position.x + side_buffer + round(maxf(0.0, (row_width - total_width) * 0.5))
	for index in range(visible_controls.size()):
		var control: Control = visible_controls[index] as Control
		var width: float = float(visible_widths[index])
		control.custom_minimum_size = Vector2(width, 44.0)
		_set_control_rect(control, Vector2(row_x, row_y), Vector2(width, 44.0))
		row_x += width + gap


func _layout_hud_landscape(safe_rect: Rect2, margin: float) -> void:
	var top_height: float = 68.0
	var rail_width: float = 58.0
	var button_h: float = 44.0
	if is_instance_valid(_back_button):
		_set_control_rect(_back_button, safe_rect.position + Vector2(margin, 5.0), Vector2(88, button_h))
	if is_instance_valid(_level_label):
		_set_control_rect(_level_label, safe_rect.position + Vector2(98.0 + margin, 3.0), Vector2(maxf(1.0, safe_rect.size.x - rail_width - 110.0 - margin * 3.0), 30.0))
		_style_label(_level_label, 24, Color(0.92, 1.0, 0.96, 1.0))
	if is_instance_valid(_flow_label):
		_set_control_rect(_flow_label, safe_rect.position + Vector2(98.0 + margin, 35.0), Vector2(maxf(1.0, safe_rect.size.x - rail_width - 110.0 - margin * 3.0), 24.0))
		_style_label(_flow_label, 14, Color(1.0, 0.86, 0.36, 1.0))
	_update_next_button_state()
	var controls: Array = [_reset_button, _hint_button, _zoom_in_button, _zoom_out_button, _last_button, _next_button]
	var rail_x: float = safe_rect.position.x + safe_rect.size.x - rail_width + 7.0
	var rail_y: float = safe_rect.position.y + top_height + 4.0
	var gap: float = 6.0
	for control_value in controls:
		var control := control_value as Control
		if not is_instance_valid(control) or not control.visible:
			continue
		var width: float = 44.0
		if control == _reset_button or control == _hint_button:
			width = 50.0
		control.custom_minimum_size = Vector2(width, button_h)
		_set_control_rect(control, Vector2(rail_x, rail_y), Vector2(width, button_h))
		rail_y += button_h + gap
	if is_instance_valid(_last_button):
		_last_button.disabled = _level_number <= 1
	if is_instance_valid(_next_button):
		_update_next_button_state()
	_set_board_view_rect(
		safe_rect.position + Vector2(margin, top_height),
		Vector2(maxf(1.0, safe_rect.size.x - rail_width - margin * 2.0), maxf(1.0, safe_rect.size.y - top_height - margin))
	)


func _layout_info_panel(safe_rect: Rect2, landscape: bool, margin: float) -> void:
	if not is_instance_valid(_info_panel):
		return
	var panel_width: float = minf(360.0, maxf(220.0, safe_rect.size.x - margin * 2.0))
	if landscape:
		panel_width = minf(330.0, maxf(220.0, safe_rect.size.x * 0.34))
	var panel_height: float = 116.0
	var panel_pos: Vector2 = Vector2(
		safe_rect.position.x + safe_rect.size.x - panel_width - margin,
		safe_rect.position.y + 58.0
	)
	if landscape:
		panel_pos = Vector2(safe_rect.position.x + safe_rect.size.x - panel_width - 64.0, safe_rect.position.y + margin)
	_set_control_rect(_info_panel, panel_pos, Vector2(panel_width, panel_height))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.065, 0.96)
	panel_style.border_color = Color(0.34, 0.92, 0.86, 0.72)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	_info_panel.add_theme_stylebox_override("panel", panel_style)
	if is_instance_valid(_info_close_button):
		_style_compact_button(_info_close_button)
		_set_control_rect(_info_close_button, Vector2(panel_width - 40.0, 8.0), Vector2(32, 32))
	if is_instance_valid(_info_label):
		_set_control_rect(_info_label, Vector2(14.0, 12.0), Vector2(maxf(1.0, panel_width - 60.0), maxf(1.0, panel_height - 24.0)))
		_style_label(_info_label, 17, Color(0.88, 1.0, 0.96, 1.0))


func _layout_final_win_panel(safe_rect: Rect2, landscape: bool, margin: float) -> void:
	if not is_instance_valid(_final_win_panel):
		return
	var panel_width: float = minf(430.0, maxf(250.0, safe_rect.size.x - margin * 2.0))
	if landscape:
		panel_width = minf(420.0, maxf(260.0, safe_rect.size.x * 0.42))
	var panel_height: float = 176.0
	var panel_pos := Vector2(
		safe_rect.position.x + round((safe_rect.size.x - panel_width) * 0.5),
		safe_rect.position.y + round((safe_rect.size.y - panel_height) * 0.5)
	)
	_set_control_rect(_final_win_panel, panel_pos, Vector2(panel_width, panel_height))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.065, 0.98)
	panel_style.border_color = Color(0.52, 1.0, 0.78, 0.84)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	_final_win_panel.add_theme_stylebox_override("panel", panel_style)
	if is_instance_valid(_final_win_title):
		_set_control_rect(_final_win_title, Vector2(18.0, 22.0), Vector2(maxf(1.0, panel_width - 36.0), 58.0))
		_style_label(_final_win_title, 36, Color(0.92, 1.0, 0.96, 1.0))
	if is_instance_valid(_final_win_menu_button):
		_style_button(_final_win_menu_button)
		var button_width: float = minf(190.0, maxf(140.0, panel_width - 48.0))
		_set_control_rect(_final_win_menu_button, Vector2(round((panel_width - button_width) * 0.5), 108.0), Vector2(button_width, 48.0))


func _get_safe_edge_margin() -> float:
	var view_size: Vector2 = get_viewport_rect().size
	var short_edge: float = minf(view_size.x, view_size.y)
	if short_edge < 520.0:
		return SAFE_EDGE_MARGIN_TINY
	if short_edge < 760.0:
		return SAFE_EDGE_MARGIN_COMPACT
	return SAFE_EDGE_MARGIN_DEFAULT


func _apply_mobile_safe_fallback(view_rect: Rect2, safe_rect: Rect2) -> Rect2:
	if not Global.is_mobile_platform:
		return safe_rect
	var short_edge: float = minf(view_rect.size.x, view_rect.size.y)
	var portrait: bool = view_rect.size.y >= view_rect.size.x
	var min_top: float = clampf(short_edge * 0.09, MOBILE_SAFE_TOP_FALLBACK_MIN, MOBILE_SAFE_TOP_FALLBACK_MAX)
	var side_min: float = MOBILE_SAFE_SIDE_FALLBACK_PORTRAIT_MIN if portrait else MOBILE_SAFE_SIDE_FALLBACK_LANDSCAPE_MIN
	var side_max: float = MOBILE_SAFE_SIDE_FALLBACK_PORTRAIT_MAX if portrait else MOBILE_SAFE_SIDE_FALLBACK_LANDSCAPE_MAX
	var side_fraction: float = 0.035 if portrait else 0.08
	var min_side: float = clampf(short_edge * side_fraction, side_min, side_max)
	var min_bottom: float = clampf(short_edge * 0.035, MOBILE_SAFE_BOTTOM_FALLBACK_MIN, MOBILE_SAFE_BOTTOM_FALLBACK_MAX)
	var safe_left: float = maxf(safe_rect.position.x, view_rect.position.x + min_side)
	var safe_top: float = maxf(safe_rect.position.y, view_rect.position.y + min_top)
	var safe_right: float = minf(safe_rect.position.x + safe_rect.size.x, view_rect.position.x + view_rect.size.x - min_side)
	var safe_bottom: float = minf(safe_rect.position.y + safe_rect.size.y, view_rect.position.y + view_rect.size.y - min_bottom)
	if safe_right - safe_left <= 1.0 or safe_bottom - safe_top <= 1.0:
		return safe_rect
	return Rect2(Vector2(safe_left, safe_top), Vector2(safe_right - safe_left, safe_bottom - safe_top))


func _get_safe_view_rect() -> Rect2:
	var view_rect := get_viewport_rect()
	if not Global.is_mobile_platform:
		return view_rect
	var window_size_i := DisplayServer.window_get_size()
	var window_size := Vector2(window_size_i)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return _apply_mobile_safe_fallback(view_rect, view_rect)
	var safe_area_i := DisplayServer.get_display_safe_area()
	var safe_area := Rect2(Vector2(safe_area_i.position), Vector2(safe_area_i.size))
	if safe_area.size.x <= 0.0 or safe_area.size.y <= 0.0:
		return _apply_mobile_safe_fallback(view_rect, view_rect)
	var scale := Vector2(view_rect.size.x / window_size.x, view_rect.size.y / window_size.y)
	var safe_pos := view_rect.position + safe_area.position * scale
	var safe_size := safe_area.size * scale
	var safe_left := clampf(safe_pos.x, view_rect.position.x, view_rect.position.x + view_rect.size.x)
	var safe_top := clampf(safe_pos.y, view_rect.position.y, view_rect.position.y + view_rect.size.y)
	var safe_right := clampf(safe_pos.x + safe_size.x, view_rect.position.x, view_rect.position.x + view_rect.size.x)
	var safe_bottom := clampf(safe_pos.y + safe_size.y, view_rect.position.y, view_rect.position.y + view_rect.size.y)
	if safe_right - safe_left <= 1.0 or safe_bottom - safe_top <= 1.0:
		return _apply_mobile_safe_fallback(view_rect, view_rect)
	return _apply_mobile_safe_fallback(view_rect, Rect2(Vector2(safe_left, safe_top), Vector2(safe_right - safe_left, safe_bottom - safe_top)))


func _get_padded_safe_view_rect(extra_margin: float = 0.0) -> Rect2:
	var safe_rect := _get_safe_view_rect()
	var margin: float = maxf(_get_safe_edge_margin() + extra_margin, 0.0)
	var padded := safe_rect.grow(-margin)
	if padded.size.x <= 1.0 or padded.size.y <= 1.0:
		return safe_rect
	return padded


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
		_board_renderer.name = "CellularBoardRenderer"
		(_board_renderer as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_board_renderer)
		move_child(_board_renderer, 0)
		_using_board_renderer = true
		_board_renderer_full_sync_needed = true
		_board_renderer_has_state = false
		return


func _has_user_arg(name: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if str(arg) == name:
			return true
	return false


func _load_level(level_number: int, record_progress: bool = true) -> void:
	_save_level_high_velocity_if_dirty()
	_level_number = _clamp_puzzle_level(level_number)
	Global.active_scenario_id = str("puzzle_level_", _level_number)
	if record_progress:
		Global.cellular_puzzle_current_level = _clamp_puzzle_level(_level_number)
		if Global.cellular_puzzle_current_level > Global.cellular_puzzle_highest_level:
			Global.cellular_puzzle_highest_level = Global.cellular_puzzle_current_level
		if Global.has_method("save_cellular_progress"):
			Global.save_cellular_progress()
	_level_high_velocity = 0
	if Global.has_method("get_cellular_puzzle_level_high_velocity"):
		_level_high_velocity = int(Global.get_cellular_puzzle_level_high_velocity(_level_number))
	_level_high_velocity_dirty = false
	_cells.clear()
	_needs.clear()
	_positions.clear()
	_produced_by_cell.clear()
	_cell_kind_by_id.clear()
	_rocks.clear()
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
	_recent_hint_keys.clear()
	_pip_angle_by_key.clear()
	_pip_offset_by_key.clear()
	_white_myco_count = 0
	_red_myco_count = 0
	_board_cols = BOARD_SIZE
	_board_rows = BOARD_SIZE
	_solved = false
	_final_win_announced = false
	_hide_final_win_panel()
	_reset_camera_state()
	_latest_report = ""
	_latest_report_dirty = false
	var cell_count := mini(RESOURCE_LETTERS.size(), _level_number + 3)
	for index in range(cell_count):
		var resource := str(RESOURCE_LETTERS[index])
		_cells.append(resource)
		_produced_by_cell[resource] = resource
		_cell_kind_by_id[resource] = CELL_KIND_STANDARD
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
	if not _using_csharp_sim:
		_apply_saved_puzzle_state_to_visual_model()
	_load_solution_layout_for_level()
	_update_level_text()


func _try_load_csharp_level() -> void:
	if not is_instance_valid(_sim_bridge):
		return
	var fixture_json := _load_fixture_json_for_level()
	if not fixture_json.is_empty():
		fixture_json = _apply_saved_puzzle_state_to_fixture_json(fixture_json)
		_apply_fixture_document_to_visual_model(fixture_json)
	if fixture_json.is_empty():
		fixture_json = JSON.stringify(_build_current_fixture_document())
		fixture_json = _apply_saved_puzzle_state_to_fixture_json(fixture_json)
		_apply_fixture_document_to_visual_model(fixture_json)
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
	if not _fixture_override_path.is_empty() and FileAccess.file_exists(_fixture_override_path):
		var override_file := FileAccess.open(_fixture_override_path, FileAccess.READ)
		if override_file != null:
			return override_file.get_as_text()
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


func _puzzle_state_section(level_number: int) -> String:
	return "level_%03d" % maxi(1, level_number)


func _load_saved_puzzle_state_document(level_number: int) -> Dictionary:
	if not _fixture_override_path.is_empty():
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(PUZZLE_STATE_SAVE_PATH) != OK:
		return {}
	var section := _puzzle_state_section(level_number)
	var state_json := str(cfg.get_value(section, "state_json", ""))
	if state_json.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(state_json)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _save_puzzle_level_state() -> void:
	if _fixture_override_path != "":
		_save_level_high_velocity_if_dirty()
		return
	if _cells.is_empty():
		_save_level_high_velocity_if_dirty()
		return
	var cfg := ConfigFile.new()
	cfg.load(PUZZLE_STATE_SAVE_PATH)
	cfg.set_value(_puzzle_state_section(_level_number), "state_json", JSON.stringify(_build_puzzle_level_state_document()))
	var err := cfg.save(PUZZLE_STATE_SAVE_PATH)
	if err != OK:
		push_warning("Cellular puzzle state save failed: %s" % str(err))
	_save_level_high_velocity_if_dirty()


func _clear_saved_puzzle_level_state(level_number: int) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PUZZLE_STATE_SAVE_PATH) != OK:
		return
	var section := _puzzle_state_section(level_number)
	if cfg.has_section(section):
		cfg.erase_section(section)
		cfg.save(PUZZLE_STATE_SAVE_PATH)


func _build_puzzle_level_state_document() -> Dictionary:
	var cell_docs: Array = []
	for cell in _cells:
		var tile := _get_cell_tile(cell)
		var needs: Array = []
		if not _is_myco_cell(cell):
			var needs_value: Array = _needs.get(cell, [])
			for need in needs_value:
				needs.append(str(need))
		cell_docs.append({
			"id": cell,
			"x": tile.x,
			"y": tile.y,
			"kind": _cell_kind(cell),
			"produced": _cell_produced_resource(cell),
			"needs": needs
		})
	return {
		"version": PUZZLE_STATE_VERSION,
		"level": _level_number,
		"width": _board_cols,
		"height": _board_rows,
		"cells": cell_docs
	}


func _apply_saved_puzzle_state_to_fixture_json(fixture_json: String) -> String:
	var state := _load_saved_puzzle_state_document(_level_number)
	if state.is_empty():
		return fixture_json
	var parsed: Variant = JSON.parse_string(fixture_json)
	if not parsed is Dictionary:
		return fixture_json
	var fixture: Dictionary = parsed as Dictionary
	var grid_info := _fixture_grid_info(fixture)
	var rocks_value: Variant = grid_info.get("rocks", {})
	var rocks: Dictionary = {}
	if rocks_value is Dictionary:
		rocks = rocks_value as Dictionary
	var saved_cell_by_id := _build_saved_cell_map(state, int(grid_info.get("width", BOARD_SIZE)), int(grid_info.get("height", BOARD_SIZE)), rocks)
	if saved_cell_by_id.is_empty():
		return fixture_json
	var cells_value: Variant = fixture.get("cells", [])
	if not cells_value is Array:
		return fixture_json
	var cells: Array = cells_value as Array
	var fixture_cell_ids: Dictionary = {}
	for cell_value in cells:
		if not cell_value is Dictionary:
			continue
		var cell_doc := cell_value as Dictionary
		var id := str(cell_doc.get("id", ""))
		if not id.is_empty():
			fixture_cell_ids[id] = true
	for id in fixture_cell_ids.keys():
		if not saved_cell_by_id.has(id):
			return fixture_json
	if saved_cell_by_id.size() < fixture_cell_ids.size():
		return fixture_json
	var remaining := saved_cell_by_id.duplicate()
	for index in range(cells.size()):
		var cell_value: Variant = cells[index]
		if not cell_value is Dictionary:
			continue
		var cell_doc := cell_value as Dictionary
		var id := str(cell_doc.get("id", ""))
		if not saved_cell_by_id.has(id):
			continue
		var saved_cell := saved_cell_by_id.get(id, {}) as Dictionary
		cell_doc["x"] = int(saved_cell.get("x", cell_doc.get("x", 0)))
		cell_doc["y"] = int(saved_cell.get("y", cell_doc.get("y", 0)))
		cells[index] = cell_doc
		remaining.erase(id)
	for id in remaining.keys():
		var saved_cell := remaining.get(id, {}) as Dictionary
		var kind := str(saved_cell.get("kind", CELL_KIND_STANDARD))
		if not _is_myco_kind(kind):
			return fixture_json
		cells.append(_build_saved_myco_cell_doc(saved_cell))
	fixture["cells"] = cells
	_ensure_fixture_resources_for_saved_cells(fixture, saved_cell_by_id)
	_normalize_fixture_integer_fields(fixture)
	return JSON.stringify(fixture)


func _normalize_fixture_integer_fields(fixture: Dictionary) -> void:
	var grid_value: Variant = fixture.get("grid", {})
	if grid_value is Dictionary:
		var grid := grid_value as Dictionary
		_set_int_field(grid, "width")
		_set_int_field(grid, "height")
		var rocks_value: Variant = grid.get("rocks", [])
		if rocks_value is Array:
			for rock_value in rocks_value:
				if rock_value is Dictionary:
					_normalize_position_doc(rock_value as Dictionary)
	var cells_value: Variant = fixture.get("cells", [])
	if cells_value is Array:
		for cell_value in cells_value:
			if not cell_value is Dictionary:
				continue
			var cell_doc := cell_value as Dictionary
			_normalize_position_doc(cell_doc)
			var slots_value: Variant = cell_doc.get("slots", [])
			if slots_value is Array:
				for slot_value in slots_value:
					if slot_value is Dictionary:
						var slot_doc := slot_value as Dictionary
						_set_int_field(slot_doc, "quantity")
						_set_int_field(slot_doc, "capacity")
			var sources_value: Variant = cell_doc.get("sources", [])
			if sources_value is Array:
				for source_value in sources_value:
					if source_value is Dictionary:
						var source_doc := source_value as Dictionary
						_set_int_field(source_doc, "quantityPerTick")
						_set_int_field(source_doc, "intervalTicks")
	var engine_value: Variant = fixture.get("engine", {})
	if engine_value is Dictionary:
		var engine_doc := engine_value as Dictionary
		var engine_int_fields: Array[String] = [
			"glowTtlTicks",
			"winRecentFlowWindowTicks",
			"swapRoundsPerTick",
			"maxSwapQuantityPerEdge",
			"needDesiredQuantity",
			"needOfferReserve"
		]
		for field in engine_int_fields:
			_set_int_field(engine_doc, field)
	var win_value: Variant = fixture.get("win", {})
	if win_value is Dictionary:
		_set_int_field(win_value as Dictionary, "durationTicks")


func _normalize_position_doc(doc: Dictionary) -> void:
	_set_int_field(doc, "x")
	_set_int_field(doc, "y")


func _set_int_field(doc: Dictionary, field: String) -> void:
	if doc.has(field):
		doc[field] = int(doc.get(field, 0))


func _apply_saved_puzzle_state_to_visual_model() -> bool:
	var state := _load_saved_puzzle_state_document(_level_number)
	if state.is_empty():
		return false
	var saved_cell_by_id := _build_saved_cell_map(state, _board_cols, _board_rows, _rocks)
	if saved_cell_by_id.is_empty():
		return false
	for cell in _cells:
		if not saved_cell_by_id.has(cell):
			return false
	for id in saved_cell_by_id.keys():
		var saved_cell := saved_cell_by_id.get(id, {}) as Dictionary
		var kind := str(saved_cell.get("kind", CELL_KIND_STANDARD))
		if not _positions.has(id) and not _is_myco_kind(kind):
			return false
	for id in saved_cell_by_id.keys():
		var saved_cell := saved_cell_by_id.get(id, {}) as Dictionary
		var kind := str(saved_cell.get("kind", CELL_KIND_STANDARD))
		if not _positions.has(id):
			_cells.append(str(id))
		_cell_kind_by_id[id] = kind
		if _is_myco_kind(kind):
			_produced_by_cell[id] = ""
			_needs[id] = []
		else:
			_produced_by_cell[id] = str(saved_cell.get("produced", id))
			_needs[id] = _saved_cell_needs(saved_cell)
		_positions[id] = Vector2i(int(saved_cell.get("x", 0)), int(saved_cell.get("y", 0)))
	_refresh_myco_id_counters()
	_board_renderer_full_sync_needed = true
	return true


func _fixture_grid_info(fixture: Dictionary) -> Dictionary:
	var width := BOARD_SIZE
	var height := BOARD_SIZE
	var rocks: Dictionary = {}
	var grid_value: Variant = fixture.get("grid", {})
	if grid_value is Dictionary:
		var grid := grid_value as Dictionary
		width = maxi(1, int(grid.get("width", BOARD_SIZE)))
		height = maxi(1, int(grid.get("height", BOARD_SIZE)))
		var rocks_value: Variant = grid.get("rocks", [])
		if rocks_value is Array:
			for rock_value in rocks_value:
				if not rock_value is Dictionary:
					continue
				var rock := rock_value as Dictionary
				rocks[_tile_key(Vector2i(int(rock.get("x", 0)), int(rock.get("y", 0))))] = true
	return {"width": width, "height": height, "rocks": rocks}


func _build_saved_cell_map(state: Dictionary, width: int, height: int, rocks: Dictionary) -> Dictionary:
	if int(state.get("level", _level_number)) != _level_number:
		return {}
	if int(state.get("width", width)) != width or int(state.get("height", height)) != height:
		return {}
	var cells_value: Variant = state.get("cells", [])
	if not cells_value is Array:
		return {}
	var saved_cells: Array = cells_value as Array
	var result: Dictionary = {}
	var used_tiles: Dictionary = {}
	for cell_value in saved_cells:
		if not cell_value is Dictionary:
			return {}
		var cell_doc := cell_value as Dictionary
		var id := str(cell_doc.get("id", ""))
		if id.is_empty() or result.has(id):
			return {}
		var tile := Vector2i(int(cell_doc.get("x", -1)), int(cell_doc.get("y", -1)))
		if tile.x < 0 or tile.y < 0 or tile.x >= width or tile.y >= height:
			return {}
		var key := _tile_key(tile)
		if rocks.has(key) or used_tiles.has(key):
			return {}
		used_tiles[key] = true
		result[id] = cell_doc
	return result


func _build_saved_myco_cell_doc(saved_cell: Dictionary) -> Dictionary:
	return {
		"id": str(saved_cell.get("id", "")),
		"kind": str(saved_cell.get("kind", CELL_KIND_RED_MYCO)),
		"x": int(saved_cell.get("x", 0)),
		"y": int(saved_cell.get("y", 0)),
		"slots": []
	}


func _saved_cell_needs(saved_cell: Dictionary) -> Array[String]:
	var needs: Array[String] = []
	var needs_value: Variant = saved_cell.get("needs", [])
	if needs_value is Array:
		for need in needs_value:
			var resource := str(need)
			if not resource.is_empty() and not needs.has(resource):
				needs.append(resource)
	return needs


func _ensure_fixture_resources_for_saved_cells(fixture: Dictionary, saved_cell_by_id: Dictionary) -> void:
	var resources: Array = []
	var seen: Dictionary = {}
	var resources_value: Variant = fixture.get("resources", [])
	if resources_value is Array:
		for resource_value in resources_value:
			var resource := str(resource_value)
			if not resource.is_empty() and not seen.has(resource):
				seen[resource] = true
				resources.append(resource)
	for saved_value in saved_cell_by_id.values():
		if not saved_value is Dictionary:
			continue
		var saved_cell := saved_value as Dictionary
		var produced := str(saved_cell.get("produced", ""))
		if not produced.is_empty() and not seen.has(produced):
			seen[produced] = true
			resources.append(produced)
		for need in _saved_cell_needs(saved_cell):
			if not seen.has(need):
				seen[need] = true
				resources.append(need)
	fixture["resources"] = resources


func _refresh_myco_id_counters() -> void:
	_white_myco_count = 0
	_red_myco_count = 0
	for cell in _cells:
		if cell.begins_with("white-myco-"):
			_white_myco_count = maxi(_white_myco_count, int(cell.trim_prefix("white-myco-")))
		elif cell.begins_with("red-myco-"):
			_red_myco_count = maxi(_red_myco_count, int(cell.trim_prefix("red-myco-")))


func _maybe_update_level_high_velocity() -> void:
	if not _using_csharp_sim:
		return
	var velocity := _swap_velocity_from_snapshot()
	if velocity <= _level_high_velocity:
		return
	_level_high_velocity = velocity
	_level_high_velocity_dirty = true


func _save_level_high_velocity_if_dirty() -> void:
	if not _level_high_velocity_dirty:
		return
	if Global.has_method("record_cellular_puzzle_level_high_velocity"):
		Global.record_cellular_puzzle_level_high_velocity(_level_number, _level_high_velocity)
	_level_high_velocity_dirty = false


func _save_current_level_progress() -> void:
	if _solved:
		_save_level_high_velocity_if_dirty()
		return
	Global.cellular_puzzle_current_level = clampi(_clamp_puzzle_level(_level_number), 1, maxi(1, Global.cellular_puzzle_highest_level))
	if Global.has_method("save_cellular_progress"):
		Global.save_cellular_progress()
	_save_level_high_velocity_if_dirty()


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
		_rocks.clear()
		var rocks_value: Variant = grid.get("rocks", [])
		if rocks_value is Array:
			for rock_value in rocks_value:
				if not rock_value is Dictionary:
					continue
				var rock := rock_value as Dictionary
				_rocks[_tile_key(Vector2i(int(rock.get("x", 0)), int(rock.get("y", 0))))] = true
	var cells_value: Variant = fixture.get("cells", [])
	if not cells_value is Array:
		return
	_cells.clear()
	_needs.clear()
	_positions.clear()
	_produced_by_cell.clear()
	_cell_kind_by_id.clear()
	for cell_value in cells_value:
		if not cell_value is Dictionary:
			continue
		var cell_doc := cell_value as Dictionary
		var id := str(cell_doc.get("id", ""))
		if id.is_empty():
			continue
		var kind := str(cell_doc.get("kind", CELL_KIND_STANDARD))
		_cells.append(id)
		_cell_kind_by_id[id] = kind
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
		if _is_myco_kind(kind):
			_produced_by_cell[id] = ""
		elif not _produced_by_cell.has(id):
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
	_rocks.clear()
	var rocks_value: Variant = _sim_snapshot.get("rocks", [])
	if rocks_value is Array:
		for rock_value in rocks_value:
			if not rock_value is Dictionary:
				continue
			var rock := rock_value as Dictionary
			_rocks[_tile_key(Vector2i(int(rock.get("x", 0)), int(rock.get("y", 0))))] = true
	_cell_state_by_id.clear()
	_positions.clear()
	_cells.clear()
	_needs.clear()
	_produced_by_cell.clear()
	_cell_kind_by_id.clear()
	var cells_value: Variant = _sim_snapshot.get("cells", [])
	if cells_value is Array:
		for cell_value in cells_value:
			if not cell_value is Dictionary:
				continue
			var cell_data := cell_value as Dictionary
			var id := str(cell_data.get("id", ""))
			if id.is_empty():
				continue
			var kind := str(cell_data.get("kind", CELL_KIND_STANDARD))
			_cells.append(id)
			_cell_state_by_id[id] = cell_data
			_cell_kind_by_id[id] = kind
			_positions[id] = Vector2i(int(cell_data.get("x", 0)), int(cell_data.get("y", 0)))
			var produced := str(cell_data.get("producedResource", ""))
			if _is_myco_kind(kind):
				_produced_by_cell[id] = ""
			elif not produced.is_empty():
				_produced_by_cell[id] = produced
			else:
				_produced_by_cell[id] = id
			var needs: Array[String] = []
			var slots_value: Variant = cell_data.get("slots", [])
			if slots_value is Array:
				for slot_value in slots_value:
					if not slot_value is Dictionary:
						continue
					var slot_doc := slot_value as Dictionary
					if str(slot_doc.get("role", "")) == "Need":
						needs.append(str(slot_doc.get("resource", "")))
			_needs[id] = needs
	var was_solved := _solved
	_solved = bool(_sim_snapshot.get("won", false))
	_handle_solved_state(was_solved)
	_refresh_myco_id_counters()
	_maybe_update_level_high_velocity()
	_board_renderer_full_sync_needed = true


func _spawn_myco(kind: String) -> void:
	if not _using_csharp_sim or not is_instance_valid(_sim_bridge) or not _sim_bridge.has_method("add_myco_cell"):
		_sim_status_message = "Myco requires the C# sim bridge"
		_hint_text = ""
		_update_level_text()
		queue_redraw()
		return
	var tile := _random_empty_tile()
	if tile == Vector2i(-1, -1):
		_sim_status_message = "No empty tile for myco"
		_hint_text = ""
		_update_level_text()
		queue_redraw()
		return
	var id := _next_myco_id(kind)
	var needs_arg := Array()
	var added_value: Variant = _sim_bridge.call("add_myco_cell", kind, id, tile.x, tile.y, needs_arg)
	if not bool(added_value):
		var error_value: Variant = _sim_bridge.call("get_last_error")
		_sim_status_message = str(error_value)
		_hint_text = ""
		_update_level_text()
		queue_redraw()
		return
	_clear_hint()
	_sim_tick_accum = 0.0
	_refresh_sim_snapshot()
	_sim_status_message = str("Added ", _myco_display_name(kind))
	_board_renderer_full_sync_needed = true
	_save_puzzle_level_state()
	_update_level_text()
	queue_redraw()


func _collect_myco_resource_names() -> Array[String]:
	var resources: Array[String] = []
	var seen := {}
	var cells_value: Variant = _sim_snapshot.get("cells", [])
	if cells_value is Array:
		for cell_value in cells_value:
			if not cell_value is Dictionary:
				continue
			var cell_data := cell_value as Dictionary
			var slots_value: Variant = cell_data.get("slots", [])
			if not slots_value is Array:
				continue
			for slot_value in slots_value:
				if not slot_value is Dictionary:
					continue
				var slot := slot_value as Dictionary
				_append_unique_resource(resources, seen, str(slot.get("resource", "")))
	if resources.is_empty():
		for cell in _cells:
			_append_unique_resource(resources, seen, _cell_produced_resource(cell))
			for need in _needs.get(cell, []):
				_append_unique_resource(resources, seen, str(need))
	return resources


func _append_unique_resource(resources: Array[String], seen: Dictionary, resource: String) -> void:
	if resource.is_empty() or seen.has(resource):
		return
	seen[resource] = true
	resources.append(resource)


func _choose_myco_needs(resources: Array[String]) -> Array[String]:
	var shuffled: Array[String] = []
	for resource in resources:
		shuffled.append(resource)
	for index in range(shuffled.size() - 1, 0, -1):
		var swap_index := _myco_rng.randi_range(0, index)
		var value := shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = value
	var count := mini(MYCO_MAX_NEEDS, shuffled.size())
	var chosen: Array[String] = []
	for index in range(count):
		chosen.append(shuffled[index])
	return chosen


func _random_empty_tile() -> Vector2i:
	var tiles: Array[Vector2i] = []
	for y in range(_board_rows):
		for x in range(_board_cols):
			var tile := Vector2i(x, y)
			if _is_tile_empty(tile):
				tiles.append(tile)
	if tiles.is_empty():
		return Vector2i(-1, -1)
	return tiles[_myco_rng.randi_range(0, tiles.size() - 1)]


func _next_myco_id(kind: String) -> String:
	var prefix: String = "white-myco" if kind == CELL_KIND_WHITE_MYCO else "red-myco"
	if kind == CELL_KIND_WHITE_MYCO:
		while true:
			_white_myco_count += 1
			var white_id := "%s-%03d" % [prefix, _white_myco_count]
			if not _positions.has(white_id):
				return white_id
	else:
		while true:
			_red_myco_count += 1
			var red_id := "%s-%03d" % [prefix, _red_myco_count]
			if not _positions.has(red_id):
				return red_id
	return "%s-fallback" % [prefix]


func _myco_display_name(kind: String) -> String:
	return "white myco" if kind == CELL_KIND_WHITE_MYCO else "red myco"


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
	var report := ""
	if is_instance_valid(_status_label):
		if _solved:
			_status_label.text = _puzzle_circuit_state_label()
		elif not _hint_text.is_empty():
			_status_label.text = _hint_text
		elif not _sim_status_message.is_empty() and _sim_status_message != "C# sim active":
			_status_label.text = _sim_status_message
		elif _using_csharp_sim:
			_status_label.text = _puzzle_circuit_state_label()
		elif not _sim_status_message.is_empty():
			_status_label.text = "Prototype fallback: C# sim unavailable"
		else:
			_status_label.text = _puzzle_circuit_state_label()
		report = _status_label.text
	else:
		if _solved:
			report = _puzzle_circuit_state_label()
		elif not _hint_text.is_empty():
			report = _hint_text
		elif not _sim_status_message.is_empty() and _sim_status_message != "C# sim active":
			report = _sim_status_message
		elif _using_csharp_sim:
			report = _puzzle_circuit_state_label()
		elif not _sim_status_message.is_empty():
			report = "Prototype fallback: C# sim unavailable"
		else:
			report = _puzzle_circuit_state_label()
	_set_latest_report(report)
	if is_instance_valid(_last_button):
		_last_button.disabled = _level_number <= 1
	if is_instance_valid(_next_button):
		_update_next_button_state()
	if is_instance_valid(_flow_label):
		if _using_csharp_sim:
			if get_viewport_rect().size.x < 560.0:
				_flow_label.text = str(_puzzle_circuit_state_label(), "  |  Flow ", _swap_velocity_from_snapshot())
			else:
				_flow_label.text = str(_puzzle_circuit_state_label(), "  |  Flow ", _swap_velocity_from_snapshot(), "  |  Best ", _level_high_velocity)
		else:
			var met := _count_met_needs()
			var total := _cells.size() * 3
			_flow_label.text = str(_puzzle_circuit_state_label(), "  |  Flow ", met, "/", total, "  |  Swaps ", _active_swap_pairs().size())


func _can_go_next() -> bool:
	return _level_number < FINAL_PUZZLE_LEVEL and (_solved or Global.cellular_puzzle_highest_level > _level_number)


func _update_next_button_state() -> void:
	if not is_instance_valid(_next_button):
		return
	var can_go_next := _can_go_next()
	var was_visible := _next_button.visible
	_next_button.visible = can_go_next
	_next_button.disabled = not can_go_next
	if was_visible != can_go_next:
		_request_hud_relayout()


func _set_latest_report(message: String) -> void:
	var trimmed := message.strip_edges()
	if trimmed.is_empty():
		return
	if trimmed == _latest_report:
		if is_instance_valid(_info_panel) and _info_panel.visible and is_instance_valid(_info_label):
			_info_label.text = _latest_report
		_update_info_button_state()
		return
	var had_previous := not _latest_report.is_empty()
	_latest_report = trimmed
	if is_instance_valid(_info_panel) and _info_panel.visible:
		if is_instance_valid(_info_label):
			_info_label.text = _latest_report
	else:
		_latest_report_dirty = had_previous
	_update_info_button_state()


func _update_info_button_state() -> void:
	if not is_instance_valid(_info_button):
		return
	_info_button.text = "i"
	_info_button.disabled = _latest_report.is_empty()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.12, 0.14, 0.90) if not _latest_report_dirty else Color(0.95, 0.76, 0.24, 0.96)
	normal.border_color = Color(0.32, 0.70, 0.72, 0.55) if not _latest_report_dirty else Color(1.0, 0.96, 0.62, 0.92)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	_info_button.add_theme_stylebox_override("normal", normal)
	_info_button.add_theme_stylebox_override("hover", normal)
	_info_button.add_theme_stylebox_override("pressed", normal)
	_info_button.add_theme_color_override("font_color", Color(0.90, 1.0, 0.96, 1.0) if not _latest_report_dirty else Color(0.08, 0.06, 0.02, 1.0))


func _on_info_pressed() -> void:
	if _latest_report.is_empty() or not is_instance_valid(_info_panel):
		return
	_info_panel.visible = not _info_panel.visible
	if _info_panel.visible:
		_latest_report_dirty = false
		if is_instance_valid(_info_label):
			_info_label.text = _latest_report
	_update_info_button_state()
	accept_event()


func _on_info_close_pressed() -> void:
	if is_instance_valid(_info_panel):
		_info_panel.visible = false
	_latest_report_dirty = false
	_update_info_button_state()
	accept_event()


func _on_zoom_in_pressed() -> void:
	_zoom_camera(CAMERA_ZOOM_STEP, _board_view_rect.get_center())


func _on_zoom_out_pressed() -> void:
	_zoom_camera(1.0 / CAMERA_ZOOM_STEP, _board_view_rect.get_center())


func _swap_velocity_from_snapshot() -> int:
	if not _using_csharp_sim:
		return 0
	var current_tick := int(_sim_snapshot.get("tick", 0))
	if current_tick <= 0:
		return 0
	var swaps_value: Variant = _sim_snapshot.get("swaps", [])
	if not swaps_value is Array:
		return 0
	var swap_count := 0
	var swaps: Array = swaps_value as Array
	for swap_value in swaps:
		if not swap_value is Dictionary:
			continue
		var swap := swap_value as Dictionary
		var swap_tick := int(swap.get("tick", current_tick))
		var age := current_tick - swap_tick
		if age >= 0 and age < VELOCITY_WINDOW_TICKS:
			swap_count += 1
	return int(round(float(swap_count) / float(VELOCITY_WINDOW_TICKS)))


func _circuit_alive_now() -> bool:
	if _using_csharp_sim:
		return bool(_sim_snapshot.get("alive", false))
	return _solved


func _puzzle_circuit_state_label() -> String:
	if _circuit_alive_now():
		return "Alive"
	if not _all_cells_connected_by_useful_links():
		return "Dormant"
	if _all_cells_participating_in_recent_flow():
		return "Flowing"
	return "Connecting"


func _all_cells_connected_by_useful_links() -> bool:
	if _cells.size() < 2:
		return false
	var adjacency: Dictionary = {}
	for cell in _cells:
		adjacency[cell] = []
	for i in range(_cells.size()):
		var a: String = _cells[i]
		for j in range(i + 1, _cells.size()):
			var b: String = _cells[j]
			if _get_cell_tile(a).distance_squared_to(_get_cell_tile(b)) != 1:
				continue
			if not _cell_pair_can_hint_match(a, b):
				continue
			var a_neighbors: Array = adjacency[a] as Array
			var b_neighbors: Array = adjacency[b] as Array
			a_neighbors.append(b)
			b_neighbors.append(a)
	for cell in _cells:
		var neighbors: Array = adjacency[cell] as Array
		if neighbors.is_empty():
			return false
	var seen: Dictionary = {}
	var queue: Array[String] = [str(_cells[0])]
	while not queue.is_empty():
		var current: String = str(queue.pop_front())
		if seen.has(current):
			continue
		seen[current] = true
		var current_neighbors: Array = adjacency[current] as Array
		for neighbor_value in current_neighbors:
			var neighbor: String = str(neighbor_value)
			if not seen.has(neighbor):
				queue.append(neighbor)
	return seen.size() == _cells.size()


func _all_cells_participating_in_recent_flow() -> bool:
	if _cells.is_empty():
		return false
	if _using_csharp_sim:
		var participating := _recent_flow_participating_cells()
		if participating.is_empty():
			return false
		for cell in _cells:
			if not participating.has(cell):
				return false
		return true
	for cell in _cells:
		if not _cell_has_all_needs(cell):
			return false
	return true


func _recent_flow_participating_cells() -> Dictionary:
	var participating: Dictionary = {}
	var current_tick := int(_sim_snapshot.get("tick", 0))
	if current_tick <= 0:
		return participating
	_add_recent_event_participants(participating, "flows", current_tick, "sourceCellId", "targetCellId")
	_add_recent_event_participants(participating, "swaps", current_tick, "initiator", "counterparty")
	return participating


func _add_recent_event_participants(participating: Dictionary, event_key: String, current_tick: int, first_cell_key: String, second_cell_key: String) -> void:
	var events_value: Variant = _sim_snapshot.get(event_key, [])
	if not events_value is Array:
		return
	var events: Array = events_value as Array
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event := event_value as Dictionary
		var event_tick := int(event.get("tick", current_tick))
		var age := current_tick - event_tick
		if age < 0 or age >= VELOCITY_WINDOW_TICKS:
			continue
		var first_cell := str(event.get(first_cell_key, ""))
		var second_cell := str(event.get(second_cell_key, ""))
		if not first_cell.is_empty():
			participating[first_cell] = true
		if not second_cell.is_empty():
			participating[second_cell] = true


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
	_draw_drag_sticky_connections()
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
		_board_renderer.call("set_drag_state", _drag_cell, _drag_position, _original_drag_tile, false)
		return
	if _board_renderer_has_state and not _board_renderer_full_sync_needed:
		if _board_renderer is CanvasItem:
			(_board_renderer as CanvasItem).queue_redraw()
		return
	var state := {
		"boardRect": _board_rect,
		"boardViewportRect": _board_view_rect,
		"tileSize": _tile_size,
		"boardCols": _board_cols,
		"boardRows": _board_rows,
		"cells": _cells,
		"positions": _positions,
		"producedByCell": _produced_by_cell,
		"cellKinds": _cell_kind_by_id,
		"rocks": _rocks,
		"needs": _needs,
		"snapshot": _sim_snapshot,
		"usingCsharpSim": _using_csharp_sim,
		"solved": _solved,
		"circuitOverlayEnabled": _circuit_overlay_enabled,
		"fastDragMode": false,
		"dragCell": _drag_cell,
		"dragPosition": _drag_position,
		"originalDragTile": _original_drag_tile,
		"hintPair": _hint_pair,
		"resourceMarkMode": _resource_mark_mode,
		"visualProfileEnabled": _visual_profile_enabled,
		"visualProfilePrintEvery": _visual_profile_print_every
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
	if reactions_value is Array and not (reactions_value as Array).is_empty():
		return true
	return _has_zero_need_pip()


func _has_zero_need_pip() -> bool:
	if not _using_csharp_sim:
		return false
	for cell in _cells:
		var needed: Array = _needs.get(cell, [])
		for need_value in needed:
			if _slot_fullness(cell, str(need_value)) <= 0.0:
				return true
	return false


func _layout_board(view_size: Vector2) -> void:
	if _board_view_rect.size.x <= 1.0 or _board_view_rect.size.y <= 1.0:
		_set_board_view_rect(Vector2(18.0, 130.0), Vector2(maxf(1.0, view_size.x - 36.0), maxf(1.0, view_size.y - 208.0)))
	_fit_tile_size = maxf(4.0, minf(_board_view_rect.size.x / float(_board_cols), _board_view_rect.size.y / float(_board_rows)))
	var tiny_view: bool = minf(_board_view_rect.size.x, _board_view_rect.size.y) < 520.0
	var readable_tile_size: float = CAMERA_TINY_READABLE_TILE_SIZE if tiny_view else CAMERA_READABLE_TILE_SIZE
	var initial_tile_size: float = _fit_tile_size if _fit_tile_size >= readable_tile_size else readable_tile_size
	initial_tile_size = clampf(initial_tile_size, _fit_tile_size, _camera_max_tile_size())
	var board_size: Vector2i = Vector2i(_board_cols, _board_rows)
	var viewport_changed: bool = _last_board_view_size != _board_view_rect.size
	if not _camera_initialized or _last_camera_board_size != board_size:
		_camera_center_tiles = Vector2(float(_board_cols) * 0.5, float(_board_rows) * 0.5)
		_camera_tile_size = initial_tile_size
		_camera_initialized = true
		_last_camera_board_size = board_size
		_last_board_view_size = _board_view_rect.size
		_board_renderer_full_sync_needed = true
	elif viewport_changed:
		_camera_tile_size = minf(_camera_tile_size, _camera_max_tile_size())
		_last_board_view_size = _board_view_rect.size
		_board_renderer_full_sync_needed = true
	_clamp_camera(true)
	_update_board_rect_from_camera()


func _reset_camera_state() -> void:
	_drag_cell = ""
	_drag_touch_id = -1
	_camera_initialized = false
	_camera_center_tiles = Vector2.ZERO
	_camera_tile_size = 64.0
	_last_camera_board_size = Vector2i.ZERO
	_last_board_view_size = Vector2.ZERO
	_pan_active = false
	_pan_touch_id = -1
	_touch_points.clear()
	_pinch_active = false
	_pinch_touch_a = -1
	_pinch_touch_b = -1
	_pinch_last_distance = 0.0


func _camera_max_tile_size() -> float:
	if _board_view_rect.size.x <= 1.0 or _board_view_rect.size.y <= 1.0:
		return maxf(_fit_tile_size, CAMERA_READABLE_TILE_SIZE)
	var four_tile_size: float = minf(_board_view_rect.size.x, _board_view_rect.size.y) / CAMERA_MIN_VISIBLE_TILES_AT_MAX_ZOOM
	return maxf(_fit_tile_size, four_tile_size)


func _update_board_rect_from_camera() -> void:
	_tile_size = clampf(_camera_tile_size, 4.0, _camera_max_tile_size())
	var board_size := Vector2(_tile_size * float(_board_cols), _tile_size * float(_board_rows))
	var origin := _board_view_rect.get_center() - _camera_center_tiles * _tile_size
	_board_rect = Rect2(origin, board_size)


func _clamp_camera(resize_deadband: bool = true) -> void:
	_camera_tile_size = minf(_camera_tile_size, _camera_max_tile_size())
	if resize_deadband:
		if _camera_tile_size < _fit_tile_size - CAMERA_RESIZE_TILE_EPSILON:
			_camera_tile_size = _fit_tile_size
	else:
		_camera_tile_size = maxf(_camera_tile_size, _fit_tile_size)
	var visible_tiles := Vector2(_board_view_rect.size.x / _camera_tile_size, _board_view_rect.size.y / _camera_tile_size)
	if visible_tiles.x >= float(_board_cols):
		_camera_center_tiles.x = float(_board_cols) * 0.5
	else:
		_camera_center_tiles.x = clampf(_camera_center_tiles.x, visible_tiles.x * 0.5, float(_board_cols) - visible_tiles.x * 0.5)
	if visible_tiles.y >= float(_board_rows):
		_camera_center_tiles.y = float(_board_rows) * 0.5
	else:
		_camera_center_tiles.y = clampf(_camera_center_tiles.y, visible_tiles.y * 0.5, float(_board_rows) - visible_tiles.y * 0.5)


func _screen_to_board_point(screen_pos: Vector2) -> Vector2:
	if _tile_size <= 0.0:
		return _camera_center_tiles
	return (screen_pos - _board_rect.position) / _tile_size


func _set_camera_tile_size(next_tile_size: float, focal_screen_pos: Vector2) -> void:
	if not _camera_initialized:
		return
	var clamped_size := clampf(next_tile_size, _fit_tile_size, _camera_max_tile_size())
	if is_equal_approx(clamped_size, _camera_tile_size):
		return
	var focal_board_point := _screen_to_board_point(focal_screen_pos)
	_camera_tile_size = clamped_size
	_camera_center_tiles = focal_board_point - (focal_screen_pos - _board_view_rect.get_center()) / _camera_tile_size
	_clamp_camera(false)
	_update_board_rect_from_camera()
	_board_renderer_full_sync_needed = true
	queue_redraw()


func _zoom_camera(factor: float, focal_screen_pos: Vector2) -> void:
	_set_camera_tile_size(_camera_tile_size * factor, focal_screen_pos)


func _pan_camera_by_screen_delta(delta: Vector2) -> void:
	if not _camera_initialized or _tile_size <= 0.0:
		return
	_camera_center_tiles -= delta / _tile_size
	_clamp_camera()
	_update_board_rect_from_camera()
	_board_renderer_full_sync_needed = true
	queue_redraw()


func _draw_board() -> void:
	draw_rect(_board_view_rect, Color(0.015, 0.030, 0.035, 0.88), true)
	for y in range(_board_rows):
		for x in range(_board_cols):
			if _rocks.has(_tile_key(Vector2i(x, y))):
				continue
			var rect := Rect2(_board_rect.position + Vector2(x, y) * _tile_size, Vector2(_tile_size, _tile_size)).grow(-2.0)
			if not _board_view_rect.grow(4.0).intersects(rect):
				continue
			var shade: float = 0.085 if (x + y) % 2 == 0 else 0.105
			draw_rect(rect, Color(shade, shade + 0.035, shade + 0.045, 1.0), true)
			draw_rect(rect, Color(0.24, 0.42, 0.42, 0.18), false, 1.0)
	if _drag_cell != "":
		var tile := _screen_to_tile(_drag_position)
		if _is_tile_inside(tile) and (_is_tile_empty(tile) or tile == _original_drag_tile):
			var highlight := Rect2(_board_rect.position + Vector2(tile) * _tile_size, Vector2(_tile_size, _tile_size)).grow(-3.0)
			if _board_view_rect.grow(4.0).intersects(highlight):
				draw_rect(highlight, Color(0.45, 1.0, 0.78, 0.20), true)
				draw_rect(highlight, Color(0.55, 1.0, 0.82, 0.70), false, 3.0)


func _draw_links() -> void:
	if _using_csharp_sim:
		_draw_csharp_flows()
		return
	for pair in _active_swap_pairs():
		var a := str(pair[0])
		var b := str(pair[1])
		var color: Color = Color(0.35, 1.0, 0.86, 0.68) if _solved else Color(0.30, 0.78, 0.86, 0.42)
		draw_line(_tile_center(_get_cell_tile(a)), _tile_center(_get_cell_tile(b)), color, 7.0, true)
		draw_line(_tile_center(_get_cell_tile(a)), _tile_center(_get_cell_tile(b)), Color(1.0, 1.0, 1.0, 0.18), 2.0, true)


func _draw_drag_sticky_connections() -> void:
	if _drag_cell.is_empty():
		return
	if _using_csharp_sim:
		_draw_drag_recent_flow_connections()
		_draw_drag_possible_swap_connections()
		return
	for pair in _active_swap_pairs():
		var a := str(pair[0])
		var b := str(pair[1])
		if a != _drag_cell and b != _drag_cell:
			continue
		var other: String = b if a == _drag_cell else a
		_draw_drag_elastic_line(_visual_cell_center(_drag_cell), _visual_cell_center(other), Color(0.35, 1.0, 0.86, 1.0), 0.48, false)


func _draw_drag_recent_flow_connections() -> void:
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
		if source != _drag_cell and target != _drag_cell:
			continue
		if resource.is_empty():
			continue
		var other: String = target if source == _drag_cell else source
		if other.is_empty():
			continue
		var age: float = maxf(0.0, current_tick - float(flow.get("tick", current_tick)))
		var alpha: float = clampf(1.0 - age / SWAP_VISUAL_TTL_TICKS, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		_draw_drag_elastic_line(_resource_visual_point(_drag_cell, resource), _resource_visual_point(other, resource), _resource_color(resource), 0.30 + alpha * 0.44, true)


func _draw_drag_possible_swap_connections() -> void:
	var possible_value: Variant = _sim_snapshot.get("possibleSwaps", [])
	if not possible_value is Array:
		return
	var possible_swaps: Array = possible_value as Array
	var drawn_pairs: Dictionary = {}
	for swap_value in possible_swaps:
		if not swap_value is Dictionary:
			continue
		var swap := swap_value as Dictionary
		var initiator := str(swap.get("initiator", ""))
		var counterparty := str(swap.get("counterparty", ""))
		if initiator != _drag_cell and counterparty != _drag_cell:
			continue
		var other: String = counterparty if initiator == _drag_cell else initiator
		if other.is_empty():
			continue
		var pair_key: String = str(_drag_cell, "|", other)
		var reverse_pair_key: String = str(other, "|", _drag_cell)
		if drawn_pairs.has(pair_key) or drawn_pairs.has(reverse_pair_key):
			continue
		drawn_pairs[pair_key] = true
		drawn_pairs[reverse_pair_key] = true
		var resource: String = str(swap.get("counterpartyPaidResource", "")) if initiator == _drag_cell else str(swap.get("initiatorPaidResource", ""))
		var start: Vector2 = _visual_cell_center(_drag_cell)
		var finish: Vector2 = _visual_cell_center(other)
		var color: Color = Color(0.35, 1.0, 0.86, 1.0)
		if not resource.is_empty():
			start = _resource_visual_point(_drag_cell, resource)
			finish = _resource_visual_point(other, resource)
			color = _resource_color(resource)
		_draw_drag_elastic_line(start, finish, color, 0.48, false)


func _draw_drag_elastic_line(start: Vector2, finish: Vector2, color: Color, alpha: float, active: bool) -> void:
	var delta: Vector2 = finish - start
	if delta.length_squared() <= 1.0:
		return
	var distance: float = delta.length()
	var stretch: float = clampf((distance - _tile_size * 0.72) / maxf(_tile_size * 4.0, 1.0), 0.0, 1.0)
	var direction: Vector2 = delta / distance
	var normal: Vector2 = direction.orthogonal()
	var phase: float = Time.get_ticks_msec() / (72.0 if active else 116.0)
	var wave: float = sin(phase + start.x * 0.013 + finish.y * 0.017) * _tile_size * (0.018 + stretch * 0.030)
	var offset: Vector2 = normal * wave
	var line_start: Vector2 = start + direction * _tile_size * 0.04
	var line_finish: Vector2 = finish - direction * _tile_size * 0.04
	var outer: Color = color
	outer.a = alpha * (0.28 if active else 0.20)
	draw_line(line_start, line_finish, outer, _tile_size * (0.16 if active else 0.12), true)
	var body: Color = color.lightened(0.18)
	body.a = alpha * (0.54 + stretch * 0.18)
	draw_line(line_start + offset, line_finish - offset, body, maxf(3.0, _tile_size * (0.055 if active else 0.040)), true)
	var highlight: Color = Color(1.0, 1.0, 1.0, alpha * (0.34 if active else 0.22))
	draw_line(line_start - offset * 0.65, line_finish + offset * 0.65, highlight, 1.8 if active else 1.3, true)


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

	var pulse: float = 0.5 + sin(Time.get_ticks_msec() / (105.0 if complete else 190.0)) * 0.5
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
	var pulse: float = 0.5 + sin(Time.get_ticks_msec() / (90.0 if intense else 150.0) + start.x * 0.02) * 0.5
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
	var spark: Color = Color(1.0, 1.0, 1.0, (0.24 + alpha * 0.24) if transient else (0.28 + alpha * 0.38))
	var offset := normal * sin(Time.get_ticks_msec() / 76.0 + finish.y * 0.025) * _tile_size * 0.035
	draw_line(line_start + offset, line_finish - offset, spark, 1.8 if transient else 2.2, true)
	var arrow_at := line_start.lerp(line_finish, 0.66 + pulse * 0.12)
	var arrow_size: float = _tile_size * (0.15 if transient else 0.18)
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
	var phase: float = Time.get_ticks_msec() / (70.0 if intense else 115.0)
	var spark: Color = Color(1.0, 1.0, 1.0, 0.20 + alpha * (0.22 if not intense else 0.46))
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
	var a: String = str(_hint_pair[0])
	var b: String = str(_hint_pair[1])
	var a_center := _visual_cell_center(a)
	var b_center := _visual_cell_center(b)
	var hint_color := Color(1.0, 0.92, 0.24, 0.86)
	draw_line(a_center, b_center, Color(1.0, 0.92, 0.24, 0.34), 9.0, true)
	draw_line(a_center, b_center, hint_color, 3.0, true)
	draw_arc(a_center, _tile_size * 0.49, 0.0, TAU, _arc_segments(_tile_size * 0.49), hint_color, 5.0, true)
	draw_arc(b_center, _tile_size * 0.49, 0.0, TAU, _arc_segments(_tile_size * 0.49), hint_color, 5.0, true)


func _draw_cell(cell: String, center: Vector2, dragging: bool) -> void:
	var radius: float = _tile_size * (0.39 if not dragging else 0.43)
	var produced_resource := _cell_produced_resource(cell)
	var color := _resource_color(produced_resource)
	var kind := _cell_kind(cell)
	var is_myco := _is_myco_kind(kind)
	if is_myco:
		color = Color(0.94, 0.97, 0.94, 1.0)
	var live_complete: bool = _circuit_alive_now()
	var glow_alpha: float = 0.46 if _cell_has_all_needs(cell) else 0.18
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
	if kind == CELL_KIND_RED_MYCO:
		_draw_red_myco_ring(center, radius)
	if live_complete:
		var solved_pulse := 0.5 + sin(Time.get_ticks_msec() / 160.0) * 0.5
		draw_arc(center, radius * (1.07 + solved_pulse * 0.03), 0.0, TAU, _arc_segments(radius), Color(0.62, 1.0, 0.88, 0.28 + solved_pulse * 0.18), 3.0, true)
	if _using_csharp_sim and not is_myco and not produced_resource.is_empty():
		_draw_fullness_arc(center, radius * 1.07, _display_fullness(cell, produced_resource, _slot_fullness(cell, produced_resource)), color, 6.0)
	var font := get_theme_default_font()
	var needed: Array = _needs.get(cell, [])
	var pip_count := MYCO_MAX_NEEDS if is_myco else needed.size()
	var used_angles: Array[float] = []
	for index in range(pip_count):
		var pip_radius := _need_pip_radius(radius)
		if index >= needed.size():
			var blank_angle := -PI * 0.5 + TAU * float(index) / maxf(float(pip_count), 1.0)
			var blank_center := center + Vector2(cos(blank_angle), sin(blank_angle)) * radius * 1.18
			draw_circle(blank_center, pip_radius, Color(0.92, 0.97, 0.96, 1.0))
			draw_circle(blank_center, pip_radius, Color(0.01, 0.025, 0.03, 0.70), false, 2.2)
			draw_circle(blank_center, pip_radius * 0.84, Color(1, 1, 1, 0.52), false, 1.4)
			continue
		var need := str(needed[index])
		var visual := _need_visual_data(cell, need, index, pip_count, center, radius, pip_radius, used_angles)
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
		var pip_bar_radius := pip_radius * 1.12
		var pip_bar_width := maxf(2.0, pip_radius * 0.20)
		_draw_fullness_arc(pip_center, pip_bar_radius, _display_fullness(cell, need, fullness), pip_color, pip_bar_width)
		if _using_csharp_sim and fullness <= 0.0:
			_draw_zero_pip_pulse_arc(pip_center, pip_bar_radius, pip_bar_width)
		_draw_resource_mark(font, pip_center, pip_radius, need, int(pip_radius * 1.02), Color.WHITE)
	if not is_myco:
		_draw_resource_mark(font, center, radius, produced_resource, int(radius * 1.48), Color.WHITE)


func _draw_red_myco_ring(center: Vector2, radius: float) -> void:
	var ring_radius := radius * RED_MYCO_RING_RADIUS
	var segments := _arc_segments(ring_radius)
	draw_arc(center, ring_radius, 0.0, TAU, segments, RED_MYCO_RING_EDGE_COLOR, maxf(2.0, radius * 0.18), true)
	draw_arc(center, ring_radius, 0.0, TAU, segments, RED_MYCO_RING_MID_COLOR, maxf(1.6, radius * 0.12), true)
	draw_arc(center, ring_radius, 0.0, TAU, segments, RED_MYCO_RING_CORE_COLOR, maxf(1.2, radius * 0.055), true)


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
	var fullness: float = _slot_fullness(cell, need) if _using_csharp_sim else 0.0
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
	var radius: float = _tile_size * (0.43 if cell == _drag_cell else 0.39)
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
	if not _solved or not is_instance_valid(_next_button) or not _next_button.visible:
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


func _draw_zero_pip_pulse_arc(center: Vector2, radius: float, width: float) -> void:
	var alpha := _zero_pip_pulse_alpha()
	if alpha <= 0.0:
		return
	var segments := _fullness_arc_segments(radius)
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, segments, Color(ZERO_PIP_PULSE_COLOR.r, ZERO_PIP_PULSE_COLOR.g, ZERO_PIP_PULSE_COLOR.b, 0.58 * alpha), width + 1.2, true)
	draw_arc(center, radius * 1.08, -PI * 0.5, PI * 1.5, segments, Color(ZERO_PIP_PULSE_COLOR.r, ZERO_PIP_PULSE_COLOR.g, ZERO_PIP_PULSE_COLOR.b, 0.22 * alpha), maxf(1.4, width * 0.55), true)


func _zero_pip_pulse_alpha() -> float:
	var phase := int(Time.get_ticks_msec() % ZERO_PIP_PULSE_PERIOD_MSEC)
	if phase < ZERO_PIP_PULSE_FADE_MSEC:
		return float(phase) / float(ZERO_PIP_PULSE_FADE_MSEC)
	if phase < ZERO_PIP_PULSE_FADE_MSEC * 2:
		return 1.0 - float(phase - ZERO_PIP_PULSE_FADE_MSEC) / float(ZERO_PIP_PULSE_FADE_MSEC)
	return 0.0


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
				if not _begin_drag(mouse_event.position):
					_begin_camera_pan(mouse_event.position)
			else:
				if _drag_cell != "":
					_finish_drag(mouse_event.position)
				else:
					_finish_camera_pan()
		elif mouse_event.pressed and _board_view_rect.has_point(mouse_event.position):
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_camera(CAMERA_ZOOM_STEP, mouse_event.position)
				accept_event()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_camera(1.0 / CAMERA_ZOOM_STEP, mouse_event.position)
				accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _drag_cell != "":
			_update_drag(motion.position)
		elif _pan_active and _pan_touch_id == -1:
			_update_camera_pan(motion.position)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_touch_points[touch_event.index] = touch_event.position
		else:
			_touch_points.erase(touch_event.index)
		if touch_event.pressed:
			if _drag_cell != "":
				accept_event()
			elif _touch_points.size() >= 2:
				_start_pinch_from_touches()
			elif not _begin_drag(touch_event.position, touch_event.index):
				_begin_camera_pan(touch_event.position, touch_event.index)
		else:
			if _drag_cell != "" and touch_event.index == _drag_touch_id:
				_finish_drag(touch_event.position)
			if _pinch_active and (touch_event.index == _pinch_touch_a or touch_event.index == _pinch_touch_b):
				_finish_pinch()
			if _pan_active and touch_event.index == _pan_touch_id:
				_finish_camera_pan()
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_touch_points[drag_event.index] = drag_event.position
		if _pinch_active:
			_update_pinch_from_touches()
		elif _drag_cell != "" and drag_event.index == _drag_touch_id:
			_update_drag(drag_event.position)
		elif _pan_active and drag_event.index == _pan_touch_id:
			_update_camera_pan(drag_event.position)
		elif _touch_points.size() >= 2:
			_start_pinch_from_touches()
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		if _board_view_rect.has_point(magnify.position):
			_zoom_camera(maxf(0.1, magnify.factor), magnify.position)
			accept_event()
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		if _board_view_rect.has_point(pan.position) and _drag_cell == "":
			_pan_camera_by_screen_delta(-pan.delta)
			accept_event()


func _begin_drag(screen_pos: Vector2, touch_id: int = -1) -> bool:
	if not _board_view_rect.has_point(screen_pos):
		return false
	var picked := _cell_at(screen_pos)
	if picked == "":
		return false
	_drag_cell = picked
	_drag_touch_id = touch_id
	_clear_hint()
	_original_drag_tile = _get_cell_tile(picked)
	_drag_position = _tile_center(_original_drag_tile)
	_drag_offset = _drag_position - screen_pos
	accept_event()
	queue_redraw()
	return true


func _update_drag(screen_pos: Vector2) -> void:
	_drag_position = screen_pos + _drag_offset
	accept_event()
	queue_redraw()


func _finish_drag(screen_pos: Vector2) -> void:
	if _drag_cell == "":
		return
	_drag_position = screen_pos + _drag_offset
	var tile := _screen_to_tile(_drag_position)
	var moved := false
	if _is_tile_inside(tile) and (_is_tile_empty(tile) or tile == _original_drag_tile):
		if _using_csharp_sim and is_instance_valid(_sim_bridge):
			var moved_value: Variant = _sim_bridge.call("move_cell", _drag_cell, tile.x, tile.y)
			if bool(moved_value):
				var reset_value: Variant = _sim_bridge.call("reset_with_current_layout")
				if not bool(reset_value):
					var error_value: Variant = _sim_bridge.call("get_last_error")
					_sim_status_message = str("Move reset failed: ", error_value)
					push_warning("Cellular C# sim bridge failed to reset moved layout: %s" % str(error_value))
				_sim_tick_accum = 0.0
				_refresh_sim_snapshot()
				_board_renderer_full_sync_needed = true
				moved = true
			else:
				var move_error_value: Variant = _sim_bridge.call("get_last_error")
				_sim_status_message = str("Move rejected: ", move_error_value)
				_hint_text = ""
		else:
			_positions[_drag_cell] = tile
			_board_renderer_full_sync_needed = true
			moved = true
	else:
		_sim_status_message = "Move rejected"
		_hint_text = ""
	_drag_cell = ""
	_drag_touch_id = -1
	if moved:
		_sim_status_message = ""
		_save_puzzle_level_state()
	_check_solution()
	accept_event()
	queue_redraw()


func _begin_camera_pan(screen_pos: Vector2, touch_id: int = -1) -> void:
	if not _board_view_rect.has_point(screen_pos):
		return
	_pan_active = true
	_pan_touch_id = touch_id
	_pan_last_pos = screen_pos
	accept_event()


func _update_camera_pan(screen_pos: Vector2) -> void:
	if not _pan_active:
		return
	var delta := screen_pos - _pan_last_pos
	_pan_last_pos = screen_pos
	_pan_camera_by_screen_delta(delta)
	accept_event()


func _finish_camera_pan() -> void:
	if not _pan_active:
		return
	_pan_active = false
	_pan_touch_id = -1
	accept_event()


func _start_pinch_from_touches() -> void:
	if _drag_cell != "" or _touch_points.size() < 2:
		return
	var keys := _touch_points.keys()
	_pinch_touch_a = int(keys[0])
	_pinch_touch_b = int(keys[1])
	var a: Vector2 = _touch_points.get(_pinch_touch_a, Vector2.ZERO) as Vector2
	var b: Vector2 = _touch_points.get(_pinch_touch_b, Vector2.ZERO) as Vector2
	_pinch_last_distance = a.distance_to(b)
	if _pinch_last_distance < CAMERA_PINCH_MIN_DISTANCE:
		return
	_pinch_last_center = (a + b) * 0.5
	_pinch_active = true
	_pan_active = false
	_pan_touch_id = -1
	accept_event()


func _update_pinch_from_touches() -> void:
	if not _pinch_active:
		return
	if not _touch_points.has(_pinch_touch_a) or not _touch_points.has(_pinch_touch_b):
		_finish_pinch()
		return
	var a: Vector2 = _touch_points.get(_pinch_touch_a, Vector2.ZERO) as Vector2
	var b: Vector2 = _touch_points.get(_pinch_touch_b, Vector2.ZERO) as Vector2
	var distance := a.distance_to(b)
	if distance < CAMERA_PINCH_MIN_DISTANCE or _pinch_last_distance < CAMERA_PINCH_MIN_DISTANCE:
		return
	var center := (a + b) * 0.5
	_pan_camera_by_screen_delta(center - _pinch_last_center)
	_zoom_camera(distance / _pinch_last_distance, center)
	_pinch_last_center = center
	_pinch_last_distance = distance
	accept_event()


func _finish_pinch() -> void:
	if not _pinch_active:
		return
	_pinch_active = false
	_pinch_touch_a = -1
	_pinch_touch_b = -1
	_pinch_last_distance = 0.0
	accept_event()


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
	if _rocks.has(_tile_key(tile)):
		return false
	for cell in _cells:
		if cell == _drag_cell:
			continue
		if _get_cell_tile(cell) == tile:
			return false
	return true


func _tile_key(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]


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
	return _cells_have_reciprocal_main_need(a, b)


func _cells_have_reciprocal_main_need(a: String, b: String) -> bool:
	var a_produced := _cell_produced_resource(a)
	var b_produced := _cell_produced_resource(b)
	if a_produced.is_empty() or b_produced.is_empty():
		return false
	return _cell_needs_resource(a, b_produced) and _cell_needs_resource(b, a_produced)


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
	if not produced.is_empty() and _cell_accepts_resource(other, produced):
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
	if resource.is_empty():
		return false
	if _cell_produced_resource(cell) == resource and _cell_accepts_resource(other, resource):
		return true
	return _cell_accepts_resource(other, resource) and _slot_offerable_quantity(cell, resource) > 0


func _cell_accepts_resource(cell: String, resource: String) -> bool:
	if resource.is_empty():
		return false
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
		if _is_myco_cell(cell):
			return maxi(0, quantity)
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
		var produced := _cell_produced_resource(current)
		if not produced.is_empty():
			resources.append(produced)
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
	if _is_myco_cell(cell):
		return ""
	var value: Variant = _produced_by_cell.get(cell, cell)
	return str(value)


func _cell_kind(cell: String) -> String:
	return str(_cell_kind_by_id.get(cell, CELL_KIND_STANDARD))


func _is_myco_kind(kind: String) -> bool:
	return kind == CELL_KIND_WHITE_MYCO or kind == CELL_KIND_RED_MYCO


func _is_myco_cell(cell: String) -> bool:
	return _is_myco_kind(_cell_kind(cell))


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
	var candidates := _rank_hint_candidates(strong_group_by_cell, weak_group_by_cell)
	if candidates.is_empty():
		return []
	var selected := _select_hint_candidates(candidates)
	if selected.is_empty():
		return []
	return [[str(selected.get("a", "")), str(selected.get("b", ""))]]


func _has_myco_cells() -> bool:
	for cell in _cells:
		if _is_myco_cell(cell):
			return true
	return false


func _best_myco_hint_pairs(strong_group_by_cell: Dictionary, weak_group_by_cell: Dictionary) -> Array:
	var pairs: Array = []
	var best_score := -1000000.0
	for i in range(_cells.size()):
		for j in range(i + 1, _cells.size()):
			var a := _cells[i]
			var b := _cells[j]
			if not _is_myco_cell(a) and not _is_myco_cell(b):
				continue
			if not _cell_pair_can_hint_match(a, b):
				continue
			var score := _hint_pair_score(a, b, strong_group_by_cell, weak_group_by_cell, false)
			score += 260.0
			if _is_myco_cell(a) and _is_myco_cell(b):
				score -= 120.0
			if score < -999999.0:
				continue
			if score > best_score:
				best_score = score
				pairs.clear()
				pairs.append([a, b])
			elif is_equal_approx(score, best_score):
				pairs.append([a, b])
	return pairs


func _rank_hint_candidates(strong_group_by_cell: Dictionary, weak_group_by_cell: Dictionary) -> Array:
	var candidates: Array = []
	var solution_pair_keys: Dictionary = _solution_hint_pair_keys()
	var seen: Dictionary = {}
	for i in range(_cells.size()):
		for j in range(i + 1, _cells.size()):
			var a: String = _cells[i]
			var b: String = _cells[j]
			var pair_key: String = _hint_pair_key(a, b)
			if seen.has(pair_key):
				continue
			seen[pair_key] = true
			if not _cell_pair_can_hint_match(a, b):
				continue
			var solution_pair: bool = bool(solution_pair_keys.get(pair_key, false))
			var score: float = _hint_pair_score(a, b, strong_group_by_cell, weak_group_by_cell, solution_pair)
			score += _hint_variety_score(a, b)
			if score < -999999.0:
				continue
			candidates.append({
				"a": a,
				"b": b,
				"key": pair_key,
				"score": score
			})
	candidates.sort_custom(Callable(self, "_compare_hint_candidates"))
	return candidates


func _solution_hint_pair_keys() -> Dictionary:
	var keys: Dictionary = {}
	if _solution_positions.is_empty():
		return keys
	for i in range(_cells.size()):
		var a: String = _cells[i]
		if not _solution_positions.has(a):
			continue
		for j in range(i + 1, _cells.size()):
			var b: String = _cells[j]
			if not _solution_positions.has(b):
				continue
			var a_solution_value: Variant = _solution_positions.get(a, Vector2i.ZERO)
			var b_solution_value: Variant = _solution_positions.get(b, Vector2i.ZERO)
			if not a_solution_value is Vector2i or not b_solution_value is Vector2i:
				continue
			var a_solution: Vector2i = a_solution_value as Vector2i
			var b_solution: Vector2i = b_solution_value as Vector2i
			if a_solution.distance_squared_to(b_solution) == 1:
				keys[_hint_pair_key(a, b)] = true
	return keys


func _hint_variety_score(a: String, b: String) -> float:
	var score: float = 0.0
	var a_myco: bool = _is_myco_cell(a)
	var b_myco: bool = _is_myco_cell(b)
	if a_myco or b_myco:
		score -= 180.0
	if a_myco and b_myco:
		score -= 180.0
	if not a_myco and not b_myco:
		score += 75.0
	var key: String = _hint_pair_key(a, b)
	var recent_index: int = _recent_hint_keys.find(key)
	if recent_index >= 0:
		score -= 1000.0 - float(recent_index) * 110.0
	return score


func _select_hint_candidates(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	var best_score: float = float((candidates[0] as Dictionary).get("score", -1000000.0))
	var window: Array = []
	for candidate_value in candidates:
		if not candidate_value is Dictionary:
			continue
		var candidate: Dictionary = candidate_value as Dictionary
		var score: float = float(candidate.get("score", -1000000.0))
		if window.size() >= HINT_TOP_RANDOM_WINDOW:
			break
		if best_score - score > HINT_TOP_SCORE_FALLOFF:
			break
		window.append(candidate)
	if window.is_empty():
		return candidates[0] as Dictionary
	var selected_index: int = _myco_rng.randi_range(0, window.size() - 1)
	return window[selected_index] as Dictionary


func _compare_hint_candidates(a: Variant, b: Variant) -> bool:
	var a_candidate: Dictionary = a as Dictionary
	var b_candidate: Dictionary = b as Dictionary
	return float(a_candidate.get("score", -1000000.0)) > float(b_candidate.get("score", -1000000.0))


func _hint_pair_key(a: String, b: String) -> String:
	if a < b:
		return str(a, "::", b)
	return str(b, "::", a)


func _remember_hint_pair(a: String, b: String) -> void:
	var key: String = _hint_pair_key(a, b)
	_recent_hint_keys.erase(key)
	_recent_hint_keys.push_front(key)
	while _recent_hint_keys.size() > HINT_RECENT_MEMORY:
		_recent_hint_keys.pop_back()


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
			if not _cell_pair_can_hint_match(a, b):
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
	var reciprocal_main_need := _cells_have_reciprocal_main_need(a, b)
	if not reciprocal_main_need and not _is_myco_cell(a) and not _is_myco_cell(b):
		return -1000000.0
	var score := 0.0
	if solution_pair:
		score += 1000.0
	if reciprocal_main_need:
		score += 520.0
	elif _is_myco_cell(a) or _is_myco_cell(b):
		score -= 220.0
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
	if _cells_can_exchange(a, b):
		score += 95.0
	elif _cells_can_match(a, b):
		score += 80.0
	score += _exchange_need_score(a, b)
	score += _exchange_need_score(b, a)
	score += _missing_need_score(a, _cell_produced_resource(b))
	score += _missing_need_score(b, _cell_produced_resource(a))
	return score


func _cell_pair_can_hint_match(a: String, b: String) -> bool:
	if _cells_have_reciprocal_main_need(a, b):
		return true
	if not _is_myco_cell(a) and not _is_myco_cell(b):
		return false
	if _using_csharp_sim:
		return _pair_has_possible_swap(a, b) or _cells_can_exchange(a, b)
	return _cells_can_match(a, b)


func _cells_can_exchange(a: String, b: String) -> bool:
	return _cell_has_payable_resource_for(a, b) and _cell_has_payable_resource_for(b, a)


func _exchange_need_score(receiver: String, giver: String) -> float:
	var best := 0.0
	for need_value in _needs.get(receiver, []):
		var need := str(need_value)
		if _cell_can_offer_resource_to(giver, need, receiver):
			best = maxf(best, (1.0 - _slot_fullness(receiver, need)) * 70.0)
	return best


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
		_handle_solved_state(was_solved)
		_update_level_text()
		return
	var all_met := true
	for cell in _cells:
		if not _cell_has_all_needs(cell):
			all_met = false
			break
	if all_met and not _solved:
		var was_solved := _solved
		_solved = true
		_handle_solved_state(was_solved)
	_update_level_text()


func _handle_solved_state(was_solved: bool) -> void:
	if not _solved:
		return
	if not was_solved and Global.has_method("record_cellular_puzzle_level_complete"):
		_save_level_high_velocity_if_dirty()
		Global.record_cellular_puzzle_level_complete(_level_number)
	if _is_final_puzzle_level():
		_show_final_win_panel()


func _show_final_win_panel() -> void:
	if _final_win_announced and is_instance_valid(_final_win_panel) and _final_win_panel.visible:
		return
	_final_win_announced = true
	if is_instance_valid(_final_win_panel):
		_final_win_panel.visible = true
		move_child(_final_win_panel, get_child_count() - 1)
	_layout_hud()


func _hide_final_win_panel() -> void:
	if is_instance_valid(_final_win_panel):
		_final_win_panel.visible = false


func _resource_color(resource: String) -> Color:
	var index := RESOURCE_LETTERS.find(resource)
	if index < 0:
		return Color(0.80, 0.86, 0.86, 1.0)
	return RESOURCE_COLORS[index % RESOURCE_COLORS.size()]


func _on_back_pressed() -> void:
	_save_puzzle_level_state()
	_save_current_level_progress()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _on_final_win_main_menu_pressed() -> void:
	_on_back_pressed()


func _on_reset_pressed() -> void:
	_save_level_high_velocity_if_dirty()
	_clear_saved_puzzle_level_state(_level_number)
	_load_level(_level_number, _level_number <= Global.cellular_puzzle_highest_level)
	queue_redraw()


func _on_last_pressed() -> void:
	_save_puzzle_level_state()
	var last_level := maxi(1, _level_number - 1)
	var record_progress := last_level <= Global.cellular_puzzle_highest_level
	if record_progress:
		Global.cellular_puzzle_current_level = last_level
		if Global.has_method("save_cellular_progress"):
			Global.save_cellular_progress()
	_load_level(last_level, record_progress)
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
	_remember_hint_pair(_hint_pair[0], _hint_pair[1])
	_hint_text = str("Hint: connect ", _cell_hint_mark(_hint_pair[0]), " with ", _cell_hint_mark(_hint_pair[1]))
	_board_renderer_full_sync_needed = true
	_update_level_text()
	queue_redraw()


func _cell_hint_mark(cell: String) -> String:
	var produced := _cell_produced_resource(cell)
	if not produced.is_empty():
		return produced
	return cell


func _on_next_pressed(diagnostic_bypass: bool = false) -> void:
	if _is_final_puzzle_level():
		if _solved:
			_show_final_win_panel()
		return
	var record_progress := _can_go_next()
	if not record_progress and not diagnostic_bypass:
		return
	_save_puzzle_level_state()
	var next_level := _clamp_puzzle_level(_level_number + 1)
	if record_progress:
		Global.cellular_puzzle_current_level = next_level
		if next_level > Global.cellular_puzzle_highest_level:
			Global.cellular_puzzle_highest_level = next_level
		if Global.has_method("save_cellular_progress"):
			Global.save_cellular_progress()
	_load_level(next_level, record_progress)
	_layout_hud()
	queue_redraw()
