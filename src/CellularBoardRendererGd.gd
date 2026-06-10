extends Control

const SWAP_VISUAL_TTL_TICKS := 10.0
const REACTION_VISUAL_TTL_TICKS := 10.0
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
const MYCO_FADE_OUT_MSEC := 1000
const MYCO_ADAPT_TRANSITION_MSEC := 2000
const MYCO_WAITING_SIGNATURE := "<waiting>"
const MYCO_VISUAL_PIP_COUNT := 4
const MAX_VISIBLE_FLOW_LINES := 192
const LOOKUP_KEY_SEPARATOR := "||"
const INVENTORY_SLOT_SCALE := 1.28
const INVENTORY_CELL_SCALE := 1.10
const INVENTORY_CELL_Y_OFFSET := 0.06
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
const NEED_PIP_MARK_SIZE_SCALE := 1.10
const NEED_PIP_MARK_WEIGHT_SCALE := 1.10
const PLAYABLE_TILE_EVEN_COLOR := Color(0.18, 0.285, 0.295, 1.0)
const PLAYABLE_TILE_ODD_COLOR := Color(0.22, 0.335, 0.340, 1.0)
const PLAYABLE_TILE_BORDER_COLOR := Color(0.62, 0.96, 0.86, 0.36)
const CELL_STRESS_GLOW_COLOR := Color(1.0, 0.96, 0.04, 1.0)
const CELL_HEALTHY_GLOW_COLOR := Color(0.30, 1.0, 0.84, 1.0)
const NEED_STATE_MISSING := "missing"
const NEED_STATE_AVAILABLE := "available"
const NEED_STATE_ACTIVE := "active"
const NEED_STATE_SATISFIED := "satisfied"
const CELL_KIND_STANDARD := "Standard"
const CELL_KIND_WHITE_MYCO := "WhiteMyco"
const CELL_KIND_RED_MYCO := "RedMyco"
const MARK_MODE_LETTERS := 0
const MARK_MODE_SYMBOLS := 1
const MARK_MODE_HIDDEN := 2
const RESOURCE_LETTERS := [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
	"M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X",
	"Y", "Z"
]
const RESOURCE_SYMBOL_MARKS := [
	"+", "*", "#", "@", "$", "%", "&", "!",
	"?", "=", "~", "^", "<", ">", "/", "\\",
	":", ";", "|", "_", "x", "o", "[", "]",
	"{", "}"
]
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
const CIRCUIT_GROUP_COLORS := [
	Color(0.30, 1.00, 0.84, 1.0),
	Color(1.00, 0.76, 0.26, 1.0),
	Color(0.68, 0.46, 1.00, 1.0),
	Color(0.28, 0.70, 1.00, 1.0),
	Color(1.00, 0.36, 0.58, 1.0)
]

var _board_rect := Rect2()
var _board_viewport_rect := Rect2()
var _tile_size := 64.0
var _board_cols := 8
var _board_rows := 8
var _board_visible := true
var _using_sim_state := false
var _solved := false
var _circuit_overlay_enabled := true
var _resource_mark_mode := MARK_MODE_LETTERS
var _drag_cell := ""
var _drag_position := Vector2.ZERO
var _original_drag_tile := Vector2i.ZERO
var _inventory_drag_cell := ""
var _inventory_drag_position := Vector2.ZERO
var _hint_pair: Array[String] = []
var _clear_effect_progress := 1.0
var _clear_effect_scale := 1.0

var _cells: Array[String] = []
var _inventory_cells: Array[String] = []
var _positions: Dictionary = {}
var _inventory_centers: Dictionary = {}
var _inventory_fresh_starts: Dictionary = {}
var _override_cell_centers: Dictionary = {}
var _override_cell_scales: Dictionary = {}
var _preferred_need_partners: Dictionary = {}
var _produced_by_cell: Dictionary = {}
var _cell_kinds: Dictionary = {}
var _needs: Dictionary = {}
var _rocks: Dictionary = {}
var _clearing_cells: Dictionary = {}
var _snapshot: Dictionary = {}
var _cell_state_by_id: Dictionary = {}
var _pip_angles: Dictionary = {}
var _pip_offsets: Dictionary = {}
var _pip_partners: Dictionary = {}
var _pip_layout_partners: Dictionary = {}
var _pip_layout_centers: Dictionary = {}
var _pip_layout_cell_centers: Dictionary = {}
var _pip_layout_cell_radii: Dictionary = {}
var _pip_returning_to_default_by_key: Dictionary = {}
var _zero_need_pip_overlay_pips: Array[Dictionary] = []
var _need_pip_layout_by_key: Dictionary = {}
var _need_pip_layout_keys_by_resource: Dictionary = {}
var _need_pip_layout_specs: Array[Dictionary] = []
var _need_pip_layout_groups: Dictionary = {}
var _cell_layout_signature := ""
var _display_fullness: Dictionary = {}
var _myco_pip_signatures: Dictionary = {}
var _myco_pip_transition_starts: Dictionary = {}
var _myco_previous_pip_resources: Dictionary = {}
var _myco_target_pip_resources: Dictionary = {}
var _myco_transition_animation_active := false
var _recent_flow_by_need: Dictionary = {}
var _recent_swap_partner_by_need: Dictionary = {}
var _possible_swap_partner_by_need: Dictionary = {}
var _visible_recent_flows: Array[Dictionary] = []
var _resource_visual_point_cache: Dictionary = {}
var _draw_cell_kind_cache: Dictionary = {}
var _draw_cell_produced_cache: Dictionary = {}
var _draw_visual_needs_cache: Dictionary = {}
var _draw_cell_glow_cache: Dictionary = {}
var _draw_reaction_alpha_cache: Dictionary = {}
var _draw_slot_fullness_cache: Dictionary = {}
var _draw_need_health_cache: Dictionary = {}
var _visual_profile_enabled := false
var _visual_profile_print_every := 120
var _visual_profile_frames := 0
var _visual_profile_frame_usec := 0
var _visual_profile_max_frame_usec := 0
var _visual_profile_board_usec := 0
var _visual_profile_circuit_usec := 0
var _visual_profile_flows_usec := 0
var _visual_profile_sticky_usec := 0
var _visual_profile_hint_usec := 0
var _visual_profile_cells_usec := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_render_state(state: Dictionary) -> void:
	_apply_view_state(
		_dict_rect2(state, "boardRect", _board_rect),
		_dict_rect2(state, "boardViewportRect", _board_rect),
		float(state.get("tileSize", _tile_size))
	)
	_board_cols = int(state.get("boardCols", _board_cols))
	_board_rows = int(state.get("boardRows", _board_rows))
	_board_visible = bool(state.get("boardVisible", true))
	_using_sim_state = bool(state.get("usingSimState", state.get("usingCsharpSim", false)))
	_solved = bool(state.get("solved", false))
	_circuit_overlay_enabled = bool(state.get("circuitOverlayEnabled", true))
	_resource_mark_mode = int(state.get("resourceMarkMode", _resource_mark_mode))
	var profile_was_enabled := _visual_profile_enabled
	_visual_profile_enabled = bool(state.get("visualProfileEnabled", _visual_profile_enabled))
	_visual_profile_print_every = maxi(1, int(state.get("visualProfilePrintEvery", _visual_profile_print_every)))
	if _visual_profile_enabled and not profile_was_enabled:
		_reset_visual_profile()
	_drag_cell = str(state.get("dragCell", ""))
	_drag_position = _dict_vector2(state, "dragPosition", Vector2.ZERO)
	_original_drag_tile = _dict_vector2i(state, "originalDragTile", Vector2i.ZERO)
	_inventory_drag_cell = str(state.get("inventoryDragCell", ""))
	_inventory_drag_position = _dict_vector2(state, "inventoryDragPosition", Vector2.ZERO)
	_clear_effect_progress = clampf(float(state.get("clearEffectProgress", 1.0)), 0.0, 1.0)
	_clear_effect_scale = clampf(float(state.get("clearEffectScale", 1.0)), 1.0, 1.85)
	_read_string_array(state, "cells", _cells)
	_sync_cell_layout_signature()
	_read_string_array(state, "inventoryCells", _inventory_cells)
	_read_positions(state)
	_read_inventory_centers(state)
	_read_inventory_fresh_starts(state)
	_read_override_cell_centers(state)
	_read_override_cell_scales(state)
	_read_preferred_need_partners(state)
	_read_string_map(state, "producedByCell", _produced_by_cell)
	_read_string_map(state, "cellKinds", _cell_kinds)
	_read_needs(state)
	_read_rocks(state)
	_read_clearing_cells(state)
	_read_hint_pair(state)
	var snapshot_value: Variant = state.get("snapshot", {})
	if snapshot_value is Dictionary:
		_snapshot = snapshot_value as Dictionary
	else:
		_snapshot = {}
	_read_cell_states()
	_rebuild_snapshot_indexes()
	queue_redraw()


func set_view_state(board_rect: Rect2, board_viewport_rect: Rect2, tile_size: float) -> void:
	_apply_view_state(board_rect, board_viewport_rect, tile_size)
	queue_redraw()


func _apply_view_state(board_rect: Rect2, board_viewport_rect: Rect2, tile_size: float) -> void:
	var has_previous_geometry := _tile_size > 0.0
	var scale_changed := has_previous_geometry and absf(_tile_size - tile_size) > 0.01
	var size_changed := has_previous_geometry and (_board_rect.size - board_rect.size).length_squared() > 0.01
	var screen_delta := board_rect.position - _board_rect.position if has_previous_geometry else Vector2.ZERO
	var geometry_changed := scale_changed or size_changed
	_board_rect = board_rect
	_board_viewport_rect = board_viewport_rect
	if _board_viewport_rect.size.x <= 1.0 or _board_viewport_rect.size.y <= 1.0:
		_board_viewport_rect = _board_rect
	_tile_size = tile_size
	if geometry_changed:
		_clear_need_pip_layout_state()
	else:
		_translate_need_pip_layout_history(screen_delta)


func set_drag_state(drag_cell: String, drag_position: Vector2, original_drag_tile: Vector2i, _fast_drag_mode: bool) -> void:
	_drag_cell = drag_cell
	_drag_position = drag_position
	_original_drag_tile = original_drag_tile
	queue_redraw()


func _draw() -> void:
	if _visual_profile_enabled:
		_draw_profiled()
		return
	_myco_transition_animation_active = false
	_clear_frame_draw_caches()
	_prepare_need_pip_layouts()
	if _board_visible:
		_draw_board()
		_draw_circuit_flow_groups()
		_draw_recent_flows()
		_draw_drag_sticky_connections()
		_draw_inventory_slot_backings()
		_draw_hint()
	for cell in _cells:
		if cell == _drag_cell:
			continue
		_draw_cell(cell, _visual_cell_center(cell), false, _board_visible, _cell_visual_scale(cell))
	if _board_visible:
		_draw_inventory_cells(false)
	if not _drag_cell.is_empty():
		_draw_cell(_drag_cell, _drag_position, true, true, _cell_visual_scale(_drag_cell))
	if _board_visible and not _inventory_drag_cell.is_empty():
		_draw_cell(_inventory_drag_cell, _inventory_drag_position, true, false, INVENTORY_CELL_SCALE, false)
	_draw_zero_need_pip_overlays()
	if _should_redraw_for_live_visuals():
		queue_redraw()


func _draw_profiled() -> void:
	var frame_start_usec := Time.get_ticks_usec()
	var section_start_usec := frame_start_usec
	_myco_transition_animation_active = false
	_clear_frame_draw_caches()
	_prepare_need_pip_layouts()
	if _board_visible:
		_draw_board()
		_visual_profile_board_usec += Time.get_ticks_usec() - section_start_usec
		section_start_usec = Time.get_ticks_usec()
		_draw_circuit_flow_groups()
		_visual_profile_circuit_usec += Time.get_ticks_usec() - section_start_usec
		section_start_usec = Time.get_ticks_usec()
		_draw_recent_flows()
		_visual_profile_flows_usec += Time.get_ticks_usec() - section_start_usec
		section_start_usec = Time.get_ticks_usec()
		_draw_drag_sticky_connections()
		_visual_profile_sticky_usec += Time.get_ticks_usec() - section_start_usec
		section_start_usec = Time.get_ticks_usec()
		_draw_inventory_slot_backings()
		_draw_hint()
		_visual_profile_hint_usec += Time.get_ticks_usec() - section_start_usec
	section_start_usec = Time.get_ticks_usec()
	for cell in _cells:
		if cell == _drag_cell:
			continue
		_draw_cell(cell, _visual_cell_center(cell), false, _board_visible, _cell_visual_scale(cell))
	if _board_visible:
		_draw_inventory_cells(false)
	if not _drag_cell.is_empty():
		_draw_cell(_drag_cell, _drag_position, true, true, _cell_visual_scale(_drag_cell))
	if _board_visible and not _inventory_drag_cell.is_empty():
		_draw_cell(_inventory_drag_cell, _inventory_drag_position, true, false, INVENTORY_CELL_SCALE, false)
	_draw_zero_need_pip_overlays()
	_visual_profile_cells_usec += Time.get_ticks_usec() - section_start_usec
	var frame_usec := Time.get_ticks_usec() - frame_start_usec
	_visual_profile_frame_usec += frame_usec
	_visual_profile_max_frame_usec = maxi(_visual_profile_max_frame_usec, frame_usec)
	_visual_profile_frames += 1
	if _visual_profile_frames >= _visual_profile_print_every:
		_print_visual_profile()
		_reset_visual_profile()
	if _should_redraw_for_live_visuals():
		queue_redraw()


func _should_redraw_for_live_visuals() -> bool:
	if _myco_transition_animation_active:
		return true
	if _solved or (_using_sim_state and bool(_snapshot.get("alive", false))):
		return true
	if not _clearing_cells.is_empty() and _clear_effect_progress < 1.0:
		return true
	for cell_value in _inventory_fresh_starts.keys():
		if _inventory_fresh_strength(str(cell_value)) > 0.0:
			return true
	if not _using_sim_state:
		return false
	if _snapshot_array_has_items("flows") or _snapshot_array_has_items("reactions") or _snapshot_array_has_items("swaps"):
		return true
	return _has_zero_need_pip()


func _snapshot_array_has_items(key: String) -> bool:
	var value: Variant = _snapshot.get(key, [])
	return value is Array and not (value as Array).is_empty()


func _has_zero_need_pip() -> bool:
	for cell in _cells:
		if not _cell_state_by_id.has(cell):
			continue
		for need in _cell_needs(cell):
			if _cached_slot_fullness(cell, need) <= 0.0:
				return true
	return false


func _clear_frame_draw_caches() -> void:
	_resource_visual_point_cache.clear()
	_zero_need_pip_overlay_pips.clear()
	_draw_cell_kind_cache.clear()
	_draw_cell_produced_cache.clear()
	_draw_visual_needs_cache.clear()
	_draw_cell_glow_cache.clear()
	_draw_reaction_alpha_cache.clear()
	_draw_slot_fullness_cache.clear()
	_draw_need_health_cache.clear()


func _prepare_need_pip_layouts() -> void:
	_clear_need_pip_frame_layouts()
	for cell in _cells:
		var dragging := cell == _drag_cell
		var center := _drag_position if dragging else _visual_cell_center(cell)
		_add_need_pip_layout_specs_for_cell(cell, center, dragging, true, _cell_visual_scale(cell))
	_layout_need_pip_specs()


func _clear_need_pip_frame_layouts() -> void:
	_zero_need_pip_overlay_pips.clear()
	_need_pip_layout_by_key.clear()
	_need_pip_layout_keys_by_resource.clear()
	_need_pip_layout_specs.clear()
	_need_pip_layout_groups.clear()
	_resource_visual_point_cache.clear()


func _clear_need_pip_layout_state() -> void:
	_clear_need_pip_frame_layouts()
	_pip_angles.clear()
	_pip_offsets.clear()
	_pip_partners.clear()
	_pip_layout_partners.clear()
	_pip_layout_centers.clear()
	_pip_layout_cell_centers.clear()
	_pip_layout_cell_radii.clear()
	_pip_returning_to_default_by_key.clear()


func _translate_need_pip_layout_history(delta: Vector2) -> void:
	if delta.length_squared() <= 0.0001:
		return
	_translate_vector_history(_pip_layout_centers, delta)
	_translate_vector_history(_pip_layout_cell_centers, delta)
	_resource_visual_point_cache.clear()


func _translate_vector_history(history: Dictionary, delta: Vector2) -> void:
	for key in history.keys():
		var value: Variant = history.get(key, null)
		if value is Vector2:
			history[key] = (value as Vector2) + delta


func _sync_cell_layout_signature() -> void:
	var cells := _cells.duplicate()
	cells.sort()
	var signature := ""
	for cell in cells:
		signature = str(signature, LOOKUP_KEY_SEPARATOR, cell)
	if signature != _cell_layout_signature:
		var had_cell_layout := not _cell_layout_signature.is_empty()
		_cell_layout_signature = signature
		if had_cell_layout:
			_prune_need_pip_layout_state_for_cells(_cells)
		else:
			_clear_need_pip_layout_state()


func _prune_need_pip_layout_state_for_cells(cells: Array[String]) -> void:
	_clear_need_pip_frame_layouts()
	var live_cells: Dictionary = {}
	for cell in cells:
		live_cells[str(cell)] = true
	_prune_pip_history_dictionary(_pip_angles, live_cells)
	_prune_pip_history_dictionary(_pip_offsets, live_cells)
	_prune_pip_history_dictionary(_pip_partners, live_cells)
	_prune_pip_history_dictionary(_pip_layout_partners, live_cells)
	_prune_pip_history_dictionary(_pip_layout_centers, live_cells)
	_prune_pip_history_dictionary(_pip_layout_cell_centers, live_cells)
	_prune_pip_history_dictionary(_pip_layout_cell_radii, live_cells)
	_prune_pip_history_dictionary(_pip_returning_to_default_by_key, live_cells)
	_prune_cell_history_dictionary(_myco_pip_signatures, live_cells)
	_prune_cell_history_dictionary(_myco_pip_transition_starts, live_cells)
	_prune_cell_history_dictionary(_myco_previous_pip_resources, live_cells)
	_prune_cell_history_dictionary(_myco_target_pip_resources, live_cells)


func _prune_pip_history_dictionary(dictionary: Dictionary, live_cells: Dictionary) -> void:
	for key_value in dictionary.keys():
		var key := str(key_value)
		if not _pip_history_key_belongs_to_cells(key, live_cells):
			dictionary.erase(key)


func _prune_cell_history_dictionary(dictionary: Dictionary, live_cells: Dictionary) -> void:
	for key_value in dictionary.keys():
		var key := str(key_value)
		if not live_cells.has(key):
			dictionary.erase(key)


func _pip_history_key_belongs_to_cells(key: String, live_cells: Dictionary) -> bool:
	for cell_value in live_cells.keys():
		if key.begins_with(str(cell_value, ":")):
			return true
	return false


func _add_need_pip_layout_specs_for_cell(cell: String, center: Vector2, dragging: bool, use_sim_state: bool, visual_scale: float) -> void:
	var radius := _tile_size * (0.43 if dragging else 0.39) * visual_scale
	var clearing := _clearing_cells.has(cell)
	var clear_alpha := _clearing_alpha() if clearing else 1.0
	if clear_alpha <= 0.0:
		return
	var kind := _cached_cell_kind(cell)
	var is_myco := _is_myco_kind(kind)
	var current_needed: Array[String] = _cached_visual_needs_for_cell(cell, is_myco, use_sim_state)
	var myco_state: Dictionary = _build_myco_pip_visual_state(cell, current_needed) if is_myco else {"resources": current_needed, "progress": 1.0}
	var needed: Array[String] = []
	var needed_value: Variant = myco_state.get("resources", [])
	if needed_value is Array:
		needed = _strings_from_array(needed_value as Array)
	var pip_count := MYCO_VISUAL_PIP_COUNT if is_myco else needed.size()
	var pip_radius := _need_pip_radius(radius)
	for index in range(pip_count):
		if index >= needed.size():
			if is_myco:
				_add_need_pip_layout_spec({
					"key": _pip_slot_key(cell, index),
					"cell": cell,
					"need": "",
					"index": index,
					"count": pip_count,
					"cellCenter": center,
					"cellRadius": radius,
					"pipRadius": pip_radius,
					"visual": _blank_myco_need_visual(index, pip_count, radius),
					"isMyco": is_myco,
					"mycoProgress": float(myco_state.get("progress", 1.0)),
					"clearAlpha": clear_alpha,
					"clearing": clearing,
					"hasLiveState": false,
					"partner": "",
					"dragging": dragging,
					"laidOut": false
				})
			continue
		var need := needed[index]
		var fading_obsolete_myco_resource := is_myco and not current_needed.has(need)
		var visual := _fading_myco_need_visual(index, pip_count, radius) if fading_obsolete_myco_resource else _need_state_data(cell, need, use_sim_state)
		var stable_partner := "" if fading_obsolete_myco_resource else _stabilize_need_partner(cell, need, index, str(visual.get("partner", "")))
		visual["partner"] = stable_partner
		_add_need_pip_layout_spec({
			"key": _pip_key(cell, need, index),
			"cell": cell,
			"need": need,
			"index": index,
			"count": pip_count,
			"cellCenter": center,
			"cellRadius": radius,
			"pipRadius": pip_radius,
			"visual": visual,
			"isMyco": is_myco,
			"mycoProgress": float(myco_state.get("progress", 1.0)),
			"clearAlpha": clear_alpha,
			"clearing": clearing,
			"hasLiveState": use_sim_state and _using_sim_state and _cell_state_by_id.has(cell),
			"partner": stable_partner,
			"dragging": dragging,
			"laidOut": false
		})


func _add_need_pip_layout_spec(spec: Dictionary) -> void:
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


func _layout_need_pip_specs() -> void:
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
			var lane_offset := (float(lane) - lane_center) * lane_spacing
			_store_provider_need_pip_layout(spec, lane_offset)
			spec["laidOut"] = true
	for spec_value in _need_pip_layout_specs:
		if not bool(spec_value.get("laidOut", false)):
			_store_default_need_pip_layout(spec_value)


func _store_provider_need_pip_layout(spec: Dictionary, lane_offset: float) -> void:
	var partner := str(spec.get("partner", ""))
	var cell_center: Vector2 = spec.get("cellCenter", Vector2.ZERO) as Vector2
	var delta := _visual_cell_center(partner) - cell_center
	if delta.length_squared() <= 1.0:
		_store_default_need_pip_layout(spec)
		return
	var direction := delta.normalized()
	var cell_radius := float(spec.get("cellRadius", 0.0))
	var pip_radius := float(spec.get("pipRadius", 0.0))
	var base_offset := _need_pip_offset(cell_center, partner, cell_radius, pip_radius)
	var lane_direction := _need_pip_edge_lane_direction(str(spec.get("cell", "")), partner)
	var lane_vector := direction * base_offset + lane_direction * lane_offset
	if lane_vector.length_squared() <= 0.0001:
		_store_default_need_pip_layout(spec)
		return
	_store_need_pip_layout(spec, cell_center + lane_vector.normalized() * base_offset)


func _store_default_need_pip_layout(spec: Dictionary) -> void:
	var visual_value: Variant = spec.get("visual", {})
	var visual: Dictionary = {}
	if visual_value is Dictionary:
		visual = visual_value as Dictionary
	var index := int(spec.get("index", 0))
	var count := int(spec.get("count", 1))
	var target_angle := float(visual.get("targetAngle", 0.0))
	var partner := str(spec.get("partner", ""))
	if absf(target_angle) <= 0.0001 and partner.is_empty():
		target_angle = -PI * 0.5 + TAU * float(index) / maxf(float(count), 1.0)
	var cell_center: Vector2 = spec.get("cellCenter", Vector2.ZERO) as Vector2
	var cell_radius := float(spec.get("cellRadius", 0.0))
	var pip_radius := float(spec.get("pipRadius", 0.0))
	var target_offset := float(visual.get("offset", 0.0))
	if target_offset <= 0.0:
		target_offset = _need_pip_offset_for_state(cell_center, "", cell_radius, pip_radius, str(visual.get("state", NEED_STATE_MISSING)))
	_store_need_pip_layout(spec, cell_center + Vector2(cos(target_angle), sin(target_angle)) * target_offset)


func _store_need_pip_layout(spec: Dictionary, target_center: Vector2) -> void:
	var key := str(spec.get("key", ""))
	var cell := str(spec.get("cell", ""))
	var need := str(spec.get("need", ""))
	var index := int(spec.get("index", 0))
	var count := int(spec.get("count", 1))
	var partner := str(spec.get("partner", ""))
	var is_myco := bool(spec.get("isMyco", false))
	var slot_key := _pip_slot_key(cell, index) if is_myco else ""
	var cell_center: Vector2 = spec.get("cellCenter", Vector2.ZERO) as Vector2
	var visual_value: Variant = spec.get("visual", {})
	var visual: Dictionary = {}
	if visual_value is Dictionary:
		visual = visual_value as Dictionary
	var delta := target_center - cell_center
	var target_angle := delta.angle() if delta.length_squared() > 0.0001 else -PI * 0.5 + TAU * float(index) / maxf(float(count), 1.0)
	var target_offset := delta.length() if delta.length_squared() > 0.0001 else _need_pip_offset_for_state(cell_center, partner, float(spec.get("cellRadius", 0.0)), float(spec.get("pipRadius", 0.0)), str(visual.get("state", NEED_STATE_MISSING)))
	var cell_radius := float(spec.get("cellRadius", 0.0))
	if not bool(spec.get("dragging", false)):
		_seed_pip_smoothing_from_previous_center(key, cell_center, cell_radius, slot_key)
	var returning_to_default := _pip_returning_to_default(key, partner, slot_key)
	var angle := _smooth_pip_angle(key, target_angle, PIP_ANGLE_RETURN_SMOOTH if returning_to_default else PIP_ANGLE_SMOOTH)
	var offset := _smooth_pip_offset(key, target_offset, PIP_OFFSET_RETURN_SMOOTH if returning_to_default else PIP_OFFSET_SMOOTH)
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
		"radius": float(spec.get("pipRadius", 0.0)),
		"state": str(visual.get("state", NEED_STATE_MISSING)),
		"fullness": float(visual.get("fullness", 0.0)),
		"activeAlpha": float(visual.get("activeAlpha", 0.0)),
		"isMyco": is_myco,
		"mycoProgress": float(spec.get("mycoProgress", 1.0)),
		"clearAlpha": float(spec.get("clearAlpha", 1.0)),
		"clearing": bool(spec.get("clearing", false)),
		"hasLiveState": bool(spec.get("hasLiveState", false)),
		"cellRadius": float(spec.get("cellRadius", 0.0))
	}
	_need_pip_layout_by_key[key] = layout
	_pip_layout_partners[key] = partner
	_pip_layout_centers[key] = center
	_pip_layout_cell_centers[key] = cell_center
	_pip_layout_cell_radii[key] = cell_radius
	if is_myco:
		_pip_layout_partners[slot_key] = partner
		_pip_layout_centers[slot_key] = center
		_pip_layout_cell_centers[slot_key] = cell_center
		_pip_layout_cell_radii[slot_key] = cell_radius
	if need.is_empty():
		return
	var lookup_key := _need_lookup_key(cell, need)
	if not _need_pip_layout_keys_by_resource.has(lookup_key):
		_need_pip_layout_keys_by_resource[lookup_key] = []
	var keys_value: Variant = _need_pip_layout_keys_by_resource.get(lookup_key, [])
	if keys_value is Array:
		(keys_value as Array).append(key)


func _need_pip_edge_lane_direction(cell: String, partner: String) -> Vector2:
	var first := cell
	var second := partner
	if first > second:
		var tmp := first
		first = second
		second = tmp
	var delta := _visual_cell_center(second) - _visual_cell_center(first)
	if delta.length_squared() <= 1.0:
		return Vector2.RIGHT
	var direction := delta.normalized()
	return Vector2(-direction.y, direction.x)


func _need_pip_edge_group_key(cell: String, partner: String) -> String:
	if cell <= partner:
		return str("edge:", cell, ":", partner)
	return str("edge:", partner, ":", cell)


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
	return not str(_pip_layout_partners.get(key, "")).is_empty()


func _seed_pip_smoothing_from_previous_center(key: String, cell_center: Vector2, cell_radius: float, fallback_key: String = "") -> void:
	if _try_seed_pip_smoothing_from_previous_center(key, key, cell_center, cell_radius, true):
		return
	if not fallback_key.is_empty() and fallback_key != key and not _pip_angles.has(key) and not _pip_offsets.has(key):
		_try_seed_pip_smoothing_from_previous_center(key, fallback_key, cell_center, cell_radius, false)


func _try_seed_pip_smoothing_from_previous_center(target_key: String, history_key: String, cell_center: Vector2, cell_radius: float, require_cell_center_moved: bool) -> bool:
	var previous_center_value: Variant = _pip_layout_centers.get(history_key, null)
	var previous_cell_center_value: Variant = _pip_layout_cell_centers.get(history_key, null)
	if not previous_center_value is Vector2 or not previous_cell_center_value is Vector2:
		return false
	var previous_cell_center: Vector2 = previous_cell_center_value as Vector2
	var previous_center: Vector2 = previous_center_value as Vector2
	var previous_radius := float(_pip_layout_cell_radii.get(history_key, 0.0))
	var radius_changed := previous_radius > 0.0001 and absf(previous_radius - cell_radius) > 0.01
	if require_cell_center_moved and (previous_cell_center - cell_center).length_squared() <= 1.0 and not radius_changed:
		return false
	var delta := previous_center - previous_cell_center
	if previous_radius > 0.0001 and cell_radius > 0.0001:
		delta *= cell_radius / previous_radius
	if delta.length_squared() <= 0.0001:
		return false
	_pip_angles[target_key] = delta.angle()
	_pip_offsets[target_key] = delta.length()
	return true


func _stop_pip_return_to_default_if_settled(key: String, returning_to_default: bool, angle: float, target_angle: float, offset: float, target_offset: float) -> void:
	if not returning_to_default:
		return
	if absf(wrapf(target_angle - angle, -PI, PI)) < PIP_ANGLE_DEAD_ZONE * 2.0 and absf(target_offset - offset) < PIP_OFFSET_DEAD_ZONE * 2.0:
		_pip_returning_to_default_by_key.erase(key)


func _print_visual_profile() -> void:
	if _visual_profile_frames <= 0:
		return
	var frames := maxi(1, _visual_profile_frames)
	print(str(
		"[cellular-visual-profile] renderer=gd",
		" frames=", frames,
		" cells=", _cells.size(),
		" visible_flows=", _visible_recent_flows.size(),
		" indexed_possible=", _possible_swap_partner_by_need.size(),
		" avg_ms=", _profile_usecs_to_ms(float(_visual_profile_frame_usec) / float(frames)),
		" max_ms=", _profile_usecs_to_ms(float(_visual_profile_max_frame_usec)),
		" board_ms=", _profile_usecs_to_ms(float(_visual_profile_board_usec) / float(frames)),
		" circuit_ms=", _profile_usecs_to_ms(float(_visual_profile_circuit_usec) / float(frames)),
		" flows_ms=", _profile_usecs_to_ms(float(_visual_profile_flows_usec) / float(frames)),
		" sticky_ms=", _profile_usecs_to_ms(float(_visual_profile_sticky_usec) / float(frames)),
		" hint_ms=", _profile_usecs_to_ms(float(_visual_profile_hint_usec) / float(frames)),
		" cells_ms=", _profile_usecs_to_ms(float(_visual_profile_cells_usec) / float(frames))
	))


func _reset_visual_profile() -> void:
	_visual_profile_frames = 0
	_visual_profile_frame_usec = 0
	_visual_profile_max_frame_usec = 0
	_visual_profile_board_usec = 0
	_visual_profile_circuit_usec = 0
	_visual_profile_flows_usec = 0
	_visual_profile_sticky_usec = 0
	_visual_profile_hint_usec = 0
	_visual_profile_cells_usec = 0


func _profile_usecs_to_ms(usec: float) -> String:
	return "%.3f" % (usec / 1000.0)


func _draw_board() -> void:
	draw_rect(_board_viewport_rect, Color(0.015, 0.030, 0.035, 0.88), true)
	for y in range(_board_rows):
		for x in range(_board_cols):
			var tile := Vector2i(x, y)
			if _rocks.has(_tile_key(tile)):
				continue
			var rect := Rect2(_board_rect.position + Vector2(tile) * _tile_size, Vector2(_tile_size, _tile_size)).grow(-2.0)
			if not _board_viewport_rect.grow(4.0).intersects(rect, true):
				continue
			var tile_color := PLAYABLE_TILE_EVEN_COLOR if (x + y) % 2 == 0 else PLAYABLE_TILE_ODD_COLOR
			draw_rect(rect, tile_color, true)
			draw_rect(rect, PLAYABLE_TILE_BORDER_COLOR, false, 1.0)
	if _drag_cell.is_empty():
		return
	var target_tile := _screen_to_tile(_drag_position)
	if _is_tile_inside(target_tile) and (_is_tile_empty(target_tile) or target_tile == _original_drag_tile):
		var highlight := _tile_rect(target_tile).grow(-3.0)
		draw_rect(highlight, Color(0.45, 1.0, 0.78, 0.20), true)
		draw_rect(highlight, Color(0.55, 1.0, 0.82, 0.70), false, 3.0)


func _draw_circuit_flow_groups() -> void:
	if not _circuit_overlay_enabled or not _using_sim_state:
		return
	var diagnostics_value: Variant = _snapshot.get("circuitDiagnostics", {})
	if not diagnostics_value is Dictionary:
		return
	var diagnostics: Dictionary = diagnostics_value as Dictionary
	var edges_value: Variant = diagnostics.get("directedEdges", [])
	_draw_circuit_blockers(diagnostics)
	if not edges_value is Array:
		_draw_simple_strong_groups(diagnostics)
		return
	var edges: Array = edges_value as Array
	if edges.is_empty():
		_draw_simple_strong_groups(diagnostics)
		return
	var alive := bool(diagnostics.get("alive", false))
	var window_ticks := maxf(1.0, float(_snapshot.get("tick", 0.0)) - float(diagnostics.get("sinceTick", 0.0)))
	var strong_group_by_cell := {}
	var cells_by_group := {}
	var groups_value: Variant = diagnostics.get("strongGroups", [])
	if groups_value is Array:
		var groups: Array = groups_value as Array
		var group_index := 0
		for group_build_value in groups:
			if not group_build_value is Array:
				continue
			var build_group_cells: Array[String] = _strings_from_array(group_build_value as Array)
			if build_group_cells.size() < 2:
				continue
			cells_by_group[group_index] = build_group_cells
			for build_cell in build_group_cells:
				strong_group_by_cell[build_cell] = group_index
			group_index += 1
	var alpha_by_group := {}
	for edge_alpha_value in edges:
		if not edge_alpha_value is Dictionary:
			continue
		var edge_alpha_dict: Dictionary = edge_alpha_value as Dictionary
		var edge_alpha_source := str(edge_alpha_dict.get("sourceCellId", ""))
		var edge_alpha_target := str(edge_alpha_dict.get("targetCellId", ""))
		if not strong_group_by_cell.has(edge_alpha_source) or not strong_group_by_cell.has(edge_alpha_target):
			continue
		var edge_alpha_source_group := int(strong_group_by_cell.get(edge_alpha_source, -1))
		var edge_alpha_target_group := int(strong_group_by_cell.get(edge_alpha_target, -2))
		if edge_alpha_source_group != edge_alpha_target_group:
			continue
		var edge_alpha := _circuit_age_alpha(float(edge_alpha_dict.get("ageTicks", 0.0)), window_ticks)
		alpha_by_group[edge_alpha_source_group] = maxf(float(alpha_by_group.get(edge_alpha_source_group, 0.0)), edge_alpha)
	var circuit_color := Color(0.30, 1.00, 0.84, 1.0)
	for group_key in cells_by_group.keys():
		var group_id := int(group_key)
		var strength := float(alpha_by_group.get(group_id, 0.0))
		if strength <= 0.0:
			continue
		var group_cells_value: Variant = cells_by_group.get(group_id, [])
		if not group_cells_value is Array:
			continue
		var halo_group_cells: Array[String] = _strings_from_array(group_cells_value as Array)
		_draw_circuit_component_halo(halo_group_cells, circuit_color, _flow_group_contains_all_cells(halo_group_cells) and alive, strength)
	for edge_draw_value in edges:
		if not edge_draw_value is Dictionary:
			continue
		var edge_draw_dict: Dictionary = edge_draw_value as Dictionary
		var draw_source := str(edge_draw_dict.get("sourceCellId", ""))
		var draw_target := str(edge_draw_dict.get("targetCellId", ""))
		if draw_source.is_empty() or draw_target.is_empty():
			continue
		var draw_alpha := _circuit_age_alpha(float(edge_draw_dict.get("ageTicks", 0.0)), window_ticks)
		if draw_alpha <= 0.0:
			continue
		var draw_source_group := int(strong_group_by_cell.get(draw_source, -1))
		var draw_target_group := int(strong_group_by_cell.get(draw_target, -2))
		var same_strong_group := strong_group_by_cell.has(draw_source) and strong_group_by_cell.has(draw_target) and draw_source_group == draw_target_group
		var draw_color := circuit_color if same_strong_group else Color(1.0, 0.70, 0.20, 1.0)
		_draw_directed_circuit_line(_visual_cell_center(draw_source), _visual_cell_center(draw_target), draw_color, draw_alpha, same_strong_group and alive, not same_strong_group)


func _draw_simple_strong_groups(diagnostics: Dictionary) -> void:
	var groups_value: Variant = diagnostics.get("strongGroups", [])
	if not groups_value is Array:
		return
	var groups: Array = groups_value as Array
	var pulse := 0.5 + sin(Time.get_ticks_msec() / 170.0) * 0.5
	for group_index in range(groups.size()):
		var group_value: Variant = groups[group_index]
		if not group_value is Array:
			continue
		var group_cells: Array[String] = _strings_from_array(group_value as Array)
		if group_cells.size() < 2:
			continue
		var color := _circuit_group_color(group_index)
		var edge := color.lightened(0.28)
		edge.a = 0.62 + pulse * 0.18
		for simple_cell in group_cells:
			if _positions.has(simple_cell):
				var simple_health := _overlay_cell_health(simple_cell)
				var simple_fill := _overlay_health_color(simple_health, color)
				simple_fill.a = (0.12 + pulse * 0.04) * lerpf(0.28, 1.0, _health_alpha_amount(simple_health))
				draw_circle(_tile_center(_get_cell_tile(simple_cell)), _tile_size * 0.58 * lerpf(0.54, 1.04, _health_radius_amount(simple_health)), simple_fill)
		for simple_rect_cell in group_cells:
			if not _positions.has(simple_rect_cell):
				continue
			var simple_rect_health := _overlay_cell_health(simple_rect_cell)
			var simple_rect_fill := _overlay_health_color(simple_rect_health, color)
			var rect := _tile_rect(_get_cell_tile(simple_rect_cell)).grow(-2.0)
			draw_rect(rect, Color(simple_rect_fill.r, simple_rect_fill.g, simple_rect_fill.b, (0.06 + pulse * 0.03) * lerpf(0.28, 1.0, _health_alpha_amount(simple_rect_health))), true)
			draw_rect(rect, edge, false, maxf(3.0, _tile_size * 0.045))


func _draw_circuit_component_halo(cells: Array[String], color: Color, complete: bool, strength: float) -> void:
	strength = clampf(strength, 0.0, 1.0)
	if strength <= 0.0:
		return
	var tiles := {}
	var cell_by_tile := {}
	for cell in cells:
		if _positions.has(cell):
			var cell_tile := _get_cell_tile(cell)
			var cell_tile_key := _tile_key(cell_tile)
			tiles[cell_tile_key] = cell_tile
			cell_by_tile[cell_tile_key] = cell
	var pulse := 0.5 + sin(Time.get_ticks_msec() / (105.0 if complete else 190.0)) * 0.5
	var fill_alpha := (0.12 + pulse * 0.04) * strength
	var boundary_alpha := ((0.82 + pulse * 0.16) if complete else (0.56 + pulse * 0.14)) * strength
	var heat_radius := _tile_size * 0.56
	var connector_width := _tile_size * 0.88
	var boundary_width := 7.0 if complete else 5.0
	for tile_connect_value in tiles.values():
		if not tile_connect_value is Vector2i:
			continue
		var tile_connect: Vector2i = tile_connect_value as Vector2i
		var center_connect := _tile_center(tile_connect)
		var right_connect := Vector2i(tile_connect.x + 1, tile_connect.y)
		if tiles.has(_tile_key(right_connect)):
			var right_center_connect := _tile_center(right_connect)
			if _line_intersects_viewport(center_connect, right_center_connect, connector_width):
				var right_link_health := _average_overlay_health(str(cell_by_tile.get(_tile_key(tile_connect), "")), str(cell_by_tile.get(_tile_key(right_connect), "")))
				var right_link_heat := _overlay_health_color(right_link_health, color)
				right_link_heat.a = fill_alpha * lerpf(0.24, 0.78, _health_alpha_amount(right_link_health))
				draw_line(center_connect, right_center_connect, right_link_heat, connector_width * lerpf(0.32, 0.86, _health_radius_amount(right_link_health)), true)
		var down_connect := Vector2i(tile_connect.x, tile_connect.y + 1)
		if tiles.has(_tile_key(down_connect)):
			var down_center_connect := _tile_center(down_connect)
			if _line_intersects_viewport(center_connect, down_center_connect, connector_width):
				var down_link_health := _average_overlay_health(str(cell_by_tile.get(_tile_key(tile_connect), "")), str(cell_by_tile.get(_tile_key(down_connect), "")))
				var down_link_heat := _overlay_health_color(down_link_health, color)
				down_link_heat.a = fill_alpha * lerpf(0.24, 0.78, _health_alpha_amount(down_link_health))
				draw_line(center_connect, down_center_connect, down_link_heat, connector_width * lerpf(0.32, 0.86, _health_radius_amount(down_link_health)), true)
	for tile_heat_value in tiles.values():
		if not tile_heat_value is Vector2i:
			continue
		var tile_heat: Vector2i = tile_heat_value as Vector2i
		var center_heat := _tile_center(tile_heat)
		var tile_health := _overlay_cell_health(str(cell_by_tile.get(_tile_key(tile_heat), "")))
		var cell_heat_radius := heat_radius * lerpf(0.54, 1.04, _health_radius_amount(tile_health))
		if _point_intersects_viewport(center_heat, cell_heat_radius):
			var tile_heat_color := _overlay_health_color(tile_health, color)
			var pulse_boost := (0.04 + pulse * 0.04) * _health_pulse_amount(tile_health) * strength if complete else 0.0
			tile_heat_color.a = fill_alpha * lerpf(0.28, 1.0, _health_alpha_amount(tile_health)) + pulse_boost
			draw_circle(center_heat, cell_heat_radius, tile_heat_color)
	for tile_boundary_value in tiles.values():
		if not tile_boundary_value is Vector2i:
			continue
		var tile_boundary: Vector2i = tile_boundary_value as Vector2i
		var origin_boundary := _tile_rect(tile_boundary).position
		var top_left := origin_boundary
		var top_right := origin_boundary + Vector2(_tile_size, 0.0)
		var bottom_left := origin_boundary + Vector2(0.0, _tile_size)
		var bottom_right := origin_boundary + Vector2(_tile_size, _tile_size)
		if not tiles.has(_tile_key(Vector2i(tile_boundary.x, tile_boundary.y - 1))):
			_draw_component_boundary_segment(top_left, top_right, color, boundary_alpha, boundary_width)
		if not tiles.has(_tile_key(Vector2i(tile_boundary.x + 1, tile_boundary.y))):
			_draw_component_boundary_segment(top_right, bottom_right, color, boundary_alpha, boundary_width)
		if not tiles.has(_tile_key(Vector2i(tile_boundary.x, tile_boundary.y + 1))):
			_draw_component_boundary_segment(bottom_right, bottom_left, color, boundary_alpha, boundary_width)
		if not tiles.has(_tile_key(Vector2i(tile_boundary.x - 1, tile_boundary.y))):
			_draw_component_boundary_segment(bottom_left, top_left, color, boundary_alpha, boundary_width)


func _overlay_cell_health(cell: String) -> float:
	if cell.is_empty():
		return 1.0
	var health_info: Dictionary = _cached_need_health(cell)
	if not bool(health_info.get("known", false)):
		return 1.0
	return clampf(float(health_info.get("health", 1.0)), 0.0, 1.0)


func _average_overlay_health(first_cell: String, second_cell: String) -> float:
	return (_overlay_cell_health(first_cell) + _overlay_cell_health(second_cell)) * 0.5


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


func _draw_component_boundary_segment(start: Vector2, finish: Vector2, color: Color, alpha: float, width: float) -> void:
	if not _line_intersects_viewport(start, finish, width + 9.0):
		return
	draw_line(start, finish, Color(color.r, color.g, color.b, alpha * 0.32), width + 9.0, true)
	draw_line(start, finish, Color(0.0, 0.07, 0.08, alpha * 0.50), width + 3.0, true)
	var highlight := color.lightened(0.30)
	highlight.a = alpha
	draw_line(start, finish, highlight, width, true)


func _draw_directed_circuit_line(start: Vector2, finish: Vector2, color: Color, alpha: float, intense: bool, transient: bool) -> void:
	var delta := finish - start
	if delta.length_squared() <= 1.0:
		return
	var direction := delta.normalized()
	var normal := direction.orthogonal()
	var line_start := start + direction * _tile_size * 0.30
	var line_finish := finish - direction * _tile_size * 0.30
	if not _line_intersects_viewport(line_start, line_finish, _tile_size * 0.50):
		return
	var pulse := 0.5 + sin(Time.get_ticks_msec() / (90.0 if intense else 150.0) + start.x * 0.02) * 0.5
	var broad_alpha := (0.12 + alpha * 0.20) if transient else ((0.24 + alpha * 0.26) if intense else (0.16 + alpha * 0.18))
	var broad := Color(color.r, color.g, color.b, broad_alpha)
	draw_line(line_start, line_finish, broad, _tile_size * (0.28 if transient else (0.46 if intense else 0.34)), true)
	var core_alpha := (0.34 + alpha * 0.28) if transient else ((0.50 + alpha * 0.44) if intense else (0.32 + alpha * 0.32))
	var core := color.lightened(0.25)
	core.a = core_alpha
	draw_line(line_start, line_finish, core, maxf(3.0, _tile_size * (0.05 if transient else (0.09 if intense else 0.065))), true)
	var spark := Color(1.0, 1.0, 1.0, (0.24 + alpha * 0.24) if transient else (0.28 + alpha * 0.38))
	var offset := normal * sin(Time.get_ticks_msec() / 76.0 + finish.y * 0.025) * _tile_size * 0.035
	draw_line(line_start + offset, line_finish - offset, spark, 1.8 if transient else 2.2, true)
	var arrow_at := line_start.lerp(line_finish, 0.66 + pulse * 0.12)
	var arrow_size := _tile_size * (0.15 if transient else 0.18)
	var arrow_color := core
	arrow_color.a = clampf(core.a + 0.12, 0.0, 1.0)
	draw_line(arrow_at, arrow_at - direction * arrow_size + normal * arrow_size * 0.58, arrow_color, 2.8, true)
	draw_line(arrow_at, arrow_at - direction * arrow_size - normal * arrow_size * 0.58, arrow_color, 2.8, true)


func _draw_circuit_blockers(diagnostics: Dictionary) -> void:
	var blocked_value: Variant = diagnostics.get("nonGlowingRequiredCells", [])
	var blocked: Array[String] = []
	if blocked_value is Array:
		blocked = _strings_from_array(blocked_value as Array)
	if blocked.is_empty():
		return
	var pulse := 0.5 + sin(Time.get_ticks_msec() / 190.0) * 0.5
	for cell in blocked:
		if not _positions.has(cell):
			continue
		var center := _visual_cell_center(cell)
		draw_circle(center, _tile_size * 0.56, Color(1.0, 0.40, 0.18, 0.08 + pulse * 0.05))
		draw_arc(center, _tile_size * 0.47, -PI * 0.15, TAU * 0.82, _arc_segments(_tile_size * 0.47), Color(1.0, 0.72, 0.28, 0.22 + pulse * 0.12), 2.5, true)


func _draw_recent_flows() -> void:
	if not _using_sim_state:
		return
	for flow_visual in _visible_recent_flows:
		var source := str(flow_visual.get("source", ""))
		var target := str(flow_visual.get("target", ""))
		var resource := str(flow_visual.get("resource", ""))
		if source.is_empty() or target.is_empty() or resource.is_empty():
			continue
		var alpha := float(flow_visual.get("alpha", 0.0))
		if alpha <= 0.0:
			continue
		var start := _cached_resource_visual_point(source, resource)
		var finish := _cached_resource_visual_point(target, resource)
		if not _line_intersects_viewport(start, finish, _tile_size * 0.20):
			continue
		var color := _resource_color(resource)
		_draw_electric_flow_line(start, finish, color, alpha)
		var age := float(flow_visual.get("age", 0.0))
		var particle := start.lerp(finish, clampf(age / 2.4, 0.0, 1.0))
		if _point_intersects_viewport(particle, _tile_size * 0.08):
			_draw_swap_particle(particle, resource, alpha)


func _draw_drag_sticky_connections() -> void:
	if _drag_cell.is_empty() or not _using_sim_state:
		return
	_draw_drag_recent_flow_connections()
	_draw_drag_possible_swap_connections()


func _draw_drag_recent_flow_connections() -> void:
	var flows_value: Variant = _snapshot.get("flows", [])
	if not flows_value is Array:
		return
	var current_tick := float(_snapshot.get("tick", 0.0))
	var flows: Array = flows_value as Array
	for flow_value in flows:
		if not flow_value is Dictionary:
			continue
		var flow: Dictionary = flow_value as Dictionary
		var source := str(flow.get("sourceCellId", ""))
		var target := str(flow.get("targetCellId", ""))
		var resource := str(flow.get("resource", ""))
		if resource.is_empty() or (source != _drag_cell and target != _drag_cell):
			continue
		var other := target if source == _drag_cell else source
		if other.is_empty():
			continue
		var age := maxf(0.0, current_tick - float(flow.get("tick", current_tick)))
		var alpha := clampf(1.0 - age / SWAP_VISUAL_TTL_TICKS, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		_draw_drag_elastic_line(_cached_resource_visual_point(_drag_cell, resource), _cached_resource_visual_point(other, resource), _resource_color(resource), 0.30 + alpha * 0.44, true)


func _draw_drag_possible_swap_connections() -> void:
	var possible_value: Variant = _snapshot.get("possibleSwaps", [])
	if not possible_value is Array:
		return
	var drawn_pairs := {}
	var possible_swaps: Array = possible_value as Array
	for swap_value in possible_swaps:
		if not swap_value is Dictionary:
			continue
		var swap: Dictionary = swap_value as Dictionary
		var initiator := str(swap.get("initiator", ""))
		var counterparty := str(swap.get("counterparty", ""))
		if initiator != _drag_cell and counterparty != _drag_cell:
			continue
		var other := counterparty if initiator == _drag_cell else initiator
		if other.is_empty():
			continue
		var pair_key := str(_drag_cell, LOOKUP_KEY_SEPARATOR, other)
		var reverse_pair_key := str(other, LOOKUP_KEY_SEPARATOR, _drag_cell)
		if drawn_pairs.has(pair_key) or drawn_pairs.has(reverse_pair_key):
			continue
		drawn_pairs[pair_key] = true
		var resource := str(swap.get("counterpartyPaidResource", "")) if initiator == _drag_cell else str(swap.get("initiatorPaidResource", ""))
		var color := Color(0.35, 1.0, 0.86, 1.0) if resource.is_empty() else _resource_color(resource)
		var start := _visual_cell_center(_drag_cell) if resource.is_empty() else _cached_resource_visual_point(_drag_cell, resource)
		var finish := _visual_cell_center(other) if resource.is_empty() else _cached_resource_visual_point(other, resource)
		_draw_drag_elastic_line(start, finish, color, 0.48, false)


func _draw_drag_elastic_line(start: Vector2, finish: Vector2, color: Color, alpha: float, active: bool) -> void:
	var delta := finish - start
	if delta.length_squared() <= 1.0:
		return
	var distance := delta.length()
	var stretch := clampf((distance - _tile_size * 0.72) / maxf(_tile_size * 4.0, 1.0), 0.0, 1.0)
	var direction := delta / distance
	var normal := direction.orthogonal()
	var phase := Time.get_ticks_msec() / (72.0 if active else 116.0)
	var wave := sin(phase + start.x * 0.013 + finish.y * 0.017) * _tile_size * (0.018 + stretch * 0.030)
	var offset := normal * wave
	var line_start := start + direction * _tile_size * 0.04
	var line_finish := finish - direction * _tile_size * 0.04
	if not _line_intersects_viewport(line_start, line_finish, _tile_size * 0.24):
		return
	var outer := Color(color.r, color.g, color.b, alpha * (0.28 if active else 0.20))
	draw_line(line_start, line_finish, outer, _tile_size * (0.16 if active else 0.12), true)
	var body := color.lightened(0.18)
	body.a = alpha * (0.54 + stretch * 0.18)
	draw_line(line_start + offset, line_finish - offset, body, maxf(3.0, _tile_size * (0.055 if active else 0.040)), true)
	var highlight := Color(1.0, 1.0, 1.0, alpha * (0.34 if active else 0.22))
	draw_line(line_start - offset * 0.65, line_finish + offset * 0.65, highlight, 1.8 if active else 1.3, true)


func _draw_electric_flow_line(start: Vector2, finish: Vector2, color: Color, alpha: float) -> void:
	var delta := finish - start
	if delta.length_squared() <= 1.0:
		return
	var normal := delta.orthogonal().normalized()
	var line_alpha := 0.24 + alpha * (0.38 if _circuit_alive_now() else 0.26)
	draw_line(start, finish, Color(color.r, color.g, color.b, line_alpha), 3.0 + alpha * 2.0, true)
	var phase := Time.get_ticks_msec() / 82.0
	for index in range(2):
		var wave := sin(phase + float(index) * PI)
		var offset := normal * wave * _tile_size * 0.025
		var wave_color := color.lightened(0.22)
		wave_color.a = 0.14 + alpha * 0.20
		draw_line(start + offset, finish - offset, wave_color, 1.4, true)


func _draw_swap_particle(position: Vector2, resource: String, alpha: float) -> void:
	var color := _resource_color(resource)
	color.a = clampf(alpha, 0.0, 1.0)
	var radius := maxf(3.0, _tile_size * 0.055)
	draw_circle(position, radius, color)
	_draw_ring(position, radius, Color(1.0, 1.0, 1.0, 0.34 * alpha), 1.6)


func _draw_hint() -> void:
	if _hint_pair.size() != 2:
		return
	var a := _hint_pair[0]
	var b := _hint_pair[1]
	var a_center := _visual_cell_center(a)
	var b_center := _visual_cell_center(b)
	var color := Color(1.0, 0.92, 0.24, 0.86)
	draw_line(a_center, b_center, Color(1.0, 0.92, 0.24, 0.34), 9.0, true)
	draw_line(a_center, b_center, color, 3.0, true)
	_draw_ring(a_center, _tile_size * 0.49, color, 5.0)
	_draw_ring(b_center, _tile_size * 0.49, color, 5.0)


func _draw_inventory_slot_backings() -> void:
	for cell in _inventory_cells:
		if not _inventory_centers.has(cell):
			continue
		var center: Vector2 = _inventory_centers[cell] as Vector2
		_draw_inventory_slot_backing(center, _tile_size * INVENTORY_SLOT_SCALE)


func _draw_inventory_cells(draw_backings: bool = true) -> void:
	for cell in _inventory_cells:
		if not _inventory_centers.has(cell):
			continue
		var center: Vector2 = _inventory_centers[cell] as Vector2
		var fresh := _inventory_fresh_strength(cell)
		var burst := sin((1.0 - fresh) * PI)
		var slot_size := _tile_size * INVENTORY_SLOT_SCALE
		var cell_center := _inventory_visual_center(center)
		if draw_backings:
			_draw_inventory_slot_backing(center, slot_size)
		if cell != _inventory_drag_cell:
			if fresh > 0.0:
				var halo_radius := _tile_size * (0.50 + burst * 0.08)
				draw_circle(cell_center, halo_radius, Color(1.0, 0.90, 0.28, 0.18 * fresh + 0.12 * burst))
				_draw_ring(cell_center, halo_radius * 1.04, Color(1.0, 0.90, 0.30, 0.46 * fresh), maxf(3.0, _tile_size * 0.052))
			_draw_cell(cell, cell_center, false, false, INVENTORY_CELL_SCALE + fresh * 0.10 + burst * 0.07, false)
		_draw_inventory_slot_frame(center, slot_size)


func _draw_inventory_slot_backing(center: Vector2, slot_size: float) -> void:
	var slot_rect := Rect2(center - Vector2(slot_size * 0.5, slot_size * 0.5), Vector2(slot_size, slot_size))
	var shadow_rect := Rect2(slot_rect.position + Vector2(0.0, _tile_size * 0.055), slot_rect.size).grow(_tile_size * 0.018)
	draw_rect(shadow_rect, Color(0.0, 0.012, 0.015, 0.50), true)
	draw_rect(slot_rect, Color(0.085, 0.120, 0.130, 0.98), true)
	draw_rect(slot_rect.grow(-_tile_size * 0.045), Color(0.115, 0.158, 0.165, 0.55), true)
	draw_rect(slot_rect.grow(-_tile_size * 0.030), Color(0.24, 0.42, 0.42, 0.20), false, maxf(1.4, _tile_size * 0.018))


func _draw_inventory_slot_frame(center: Vector2, slot_size: float) -> void:
	var slot_rect := Rect2(center - Vector2(slot_size * 0.5, slot_size * 0.5), Vector2(slot_size, slot_size))
	var shadow_rect := Rect2(slot_rect.position + Vector2(0.0, _tile_size * 0.055), slot_rect.size).grow(_tile_size * 0.018)
	draw_rect(shadow_rect, Color(0.0, 0.012, 0.015, 0.36), false, maxf(3.0, _tile_size * 0.040))
	draw_rect(slot_rect.grow(-_tile_size * 0.030), Color(1.0, 1.0, 1.0, 0.13), false, maxf(1.2, _tile_size * 0.016))
	draw_rect(slot_rect, Color(0.08, 0.25, 0.21, 0.72), false, maxf(5.0, _tile_size * 0.074))
	draw_rect(slot_rect.grow(-_tile_size * 0.022), Color(0.54, 1.0, 0.84, 0.82), false, maxf(3.2, _tile_size * 0.046))


func _draw_cell(cell: String, center: Vector2, dragging: bool, clip_to_viewport: bool, visual_scale: float = 1.0, use_sim_state: bool = true) -> void:
	var radius := _tile_size * (0.43 if dragging else 0.39) * visual_scale
	var clearing := _clearing_cells.has(cell)
	var clear_alpha := _clearing_alpha() if clearing else 1.0
	var clear_flash := _clearing_flash() if clearing else 0.0
	if clearing:
		radius *= 1.0 + (sin(_clear_effect_progress * PI) * 0.22 + clear_flash * 0.12) * _clear_effect_scale
	if clip_to_viewport and not _board_viewport_rect.grow(radius * 1.95).has_point(center):
		return
	if clear_alpha <= 0.02:
		return
	var kind := _cached_cell_kind(cell)
	var is_myco := _is_myco_kind(kind)
	var produced := _cached_cell_produced_resource(cell)
	var color := Color(0.94, 0.97, 0.94, 1.0) if is_myco else _resource_color(produced)
	var live_complete := use_sim_state and _circuit_alive_now()
	var has_live_state := use_sim_state and _using_sim_state and _cell_state_by_id.has(cell)
	var body_glow_color := color
	var glow_alpha := 0.56 if _cached_cell_is_glowing(cell) else 0.16
	if not has_live_state:
		glow_alpha = 0.46 if use_sim_state and _cell_has_all_needs(cell, use_sim_state) else 0.18
	var glow_health := 1.0
	var glow_alpha_health := 1.0
	var need_health_info: Dictionary = _cached_need_health(cell)
	var has_need_health := bool(need_health_info.get("known", false))
	var need_health := float(need_health_info.get("health", 1.0))
	if has_need_health:
		var color_health := _health_color_amount(need_health)
		var radius_health := _health_radius_amount(need_health)
		var alpha_health := _health_alpha_amount(need_health)
		glow_health = radius_health
		glow_alpha_health = alpha_health
		body_glow_color = CELL_STRESS_GLOW_COLOR.lerp(CELL_HEALTHY_GLOW_COLOR, color_health)
		glow_alpha = lerpf(CELL_STRESS_GLOW_STRENGTH, CELL_HEALTHY_GLOW_STRENGTH, alpha_health)
	var reaction_alpha := _cached_recent_reaction_alpha(cell) if has_live_state else 0.0
	if reaction_alpha > 0.0:
		var reaction_health := need_health if has_need_health else 1.0
		if reaction_health > 0.0:
			body_glow_color = body_glow_color.lerp(CELL_HEALTHY_GLOW_COLOR, reaction_alpha * reaction_health)
			glow_alpha = maxf(glow_alpha, lerpf(CELL_STRESS_GLOW_STRENGTH, 0.52 + reaction_alpha * 0.28, reaction_health))
			draw_circle(center, radius * (1.22 + reaction_alpha * 0.10), Color(1.0, 0.95, 0.58, reaction_alpha * 0.18 * reaction_health * clear_alpha))
	var glow_radius_scale := lerpf(CELL_STRESS_GLOW_RADIUS_SCALE, CELL_HEALTHY_GLOW_RADIUS_SCALE, glow_health)
	var glow_alpha_scale := lerpf(CELL_STRESS_GLOW_ALPHA_SCALE, CELL_HEALTHY_GLOW_ALPHA_SCALE, glow_alpha_health)
	var glow_alpha_value := glow_alpha * glow_alpha_scale * clear_alpha
	var glow_thickness := maxf(0.0, glow_radius_scale - 1.0)
	draw_circle(center, radius * glow_radius_scale, Color(body_glow_color.r, body_glow_color.g, body_glow_color.b, glow_alpha_value * CELL_GLOW_OUTER_ALPHA_FRACTION))
	draw_circle(center, radius * (1.0 + glow_thickness * CELL_GLOW_MID_RADIUS_FRACTION), Color(body_glow_color.r, body_glow_color.g, body_glow_color.b, glow_alpha_value * CELL_GLOW_MID_ALPHA_FRACTION))
	draw_circle(center, radius * (1.0 + glow_thickness * CELL_GLOW_INNER_RADIUS_FRACTION), Color(body_glow_color.r, body_glow_color.g, body_glow_color.b, glow_alpha_value * CELL_GLOW_INNER_ALPHA_FRACTION))
	draw_circle(center, radius, Color(color.r, color.g, color.b, 0.72 * clear_alpha))
	_draw_ring(center, radius * 0.96, Color(0.92, 1.0, 0.95, 0.68 * clear_alpha), 3.0)
	if clearing:
		draw_circle(center, radius * (1.05 + _clear_effect_progress * 0.28 * _clear_effect_scale), Color(1.0, 0.95, 0.34, clear_flash * 0.48 + (1.0 - _clear_effect_progress) * 0.10))
		_draw_ring(center, radius * (1.12 + _clear_effect_progress * 0.34 * _clear_effect_scale), Color(1.0, 0.88, 0.22, clear_alpha * 0.46), 4.5 * _clear_effect_scale)
	if kind == CELL_KIND_RED_MYCO:
		_draw_red_myco_ring(center, radius, clear_alpha)
	if live_complete:
		var pulse_health := _health_pulse_amount(need_health) if has_need_health else 1.0
		var solved_pulse := 0.5 + sin(Time.get_ticks_msec() / 160.0) * 0.5
		if pulse_health > 0.02:
			_draw_ring(center, radius * (1.07 + pulse_health * 0.03 + solved_pulse * 0.03), Color(0.62, 1.0, 0.88, (0.18 + solved_pulse * 0.24) * pulse_health * clear_alpha), 3.0)
	if not clearing and has_live_state and not is_myco and not produced.is_empty():
		_draw_fullness_arc(center, radius * 1.07, _displayed_fullness(cell, produced, _cached_slot_fullness(cell, produced)), color, 6.0)
	var font := get_theme_default_font()
	var current_needed: Array[String] = _cached_visual_needs_for_cell(cell, is_myco, use_sim_state)
	var myco_state: Dictionary = _build_myco_pip_visual_state(cell, current_needed) if is_myco else {"resources": current_needed, "progress": 1.0}
	var needed: Array[String] = []
	var needed_value: Variant = myco_state.get("resources", [])
	if needed_value is Array:
		needed = _strings_from_array(needed_value as Array)
	var pip_count := MYCO_VISUAL_PIP_COUNT if is_myco else needed.size()
	var myco_progress := float(myco_state.get("progress", 1.0))
	var used_angles: Array[float] = []
	var normal_need_pips: Array[Dictionary] = []
	var zero_need_pips: Array[Dictionary] = []
	for index in range(pip_count):
		var pip_radius := _need_pip_radius(radius)
		if index >= needed.size():
			var blank_layout_key := _pip_slot_key(cell, index)
			var blank_layout_value: Variant = _need_pip_layout_by_key.get(blank_layout_key, {})
			var blank_center := _default_myco_slot_center(center, index, pip_count, radius)
			var blank_radius := pip_radius
			if blank_layout_value is Dictionary:
				var blank_layout: Dictionary = blank_layout_value as Dictionary
				var blank_center_value: Variant = blank_layout.get("center", blank_center)
				if blank_center_value is Vector2:
					blank_center = blank_center_value as Vector2
				blank_radius = float(blank_layout.get("radius", blank_radius))
			_draw_blank_myco_pip(blank_center, blank_radius, clear_alpha)
			continue
		var need := needed[index]
		var key := _pip_key(cell, need, index)
		var pip_data := _need_pip_draw_from_layout(_need_pip_layout_by_key.get(key, {})) if use_sim_state and _need_pip_layout_by_key.has(key) else _build_fallback_need_pip_draw(cell, need, index, pip_count, center, radius, pip_radius, used_angles, use_sim_state, is_myco, myco_progress, clear_alpha, clearing, has_live_state, current_needed)
		if _should_elevate_need_pip(pip_data):
			zero_need_pips.append(pip_data)
			_zero_need_pip_overlay_pips.append({"pip": pip_data, "cellRadius": radius})
		else:
			normal_need_pips.append(pip_data)
	for pip_data in normal_need_pips:
		_draw_need_pip(font, pip_data, radius, true)
	for pip_data in zero_need_pips:
		_draw_need_pip(font, pip_data, radius, true)
	if not is_myco:
		_draw_resource_mark(font, center, radius, produced, int(radius * 1.48), Color(1.0, 1.0, 1.0, clear_alpha))


func _need_pip_draw_from_layout(layout_value: Variant) -> Dictionary:
	if not layout_value is Dictionary:
		return {}
	var layout: Dictionary = layout_value as Dictionary
	return {
		"cell": str(layout.get("cell", "")),
		"need": str(layout.get("need", "")),
		"cellCenter": layout.get("cellCenter", Vector2.ZERO),
		"center": layout.get("center", Vector2.ZERO),
		"radius": float(layout.get("radius", 0.0)),
		"state": str(layout.get("state", NEED_STATE_MISSING)),
		"fullness": float(layout.get("fullness", 0.0)),
		"activeAlpha": float(layout.get("activeAlpha", 0.0)),
		"isMyco": bool(layout.get("isMyco", false)),
		"mycoProgress": float(layout.get("mycoProgress", 1.0)),
		"clearAlpha": float(layout.get("clearAlpha", 1.0)),
		"clearing": bool(layout.get("clearing", false)),
		"hasLiveState": bool(layout.get("hasLiveState", false))
	}


func _build_fallback_need_pip_draw(cell: String, need: String, index: int, count: int, center: Vector2, cell_radius: float, pip_radius: float, used_angles: Array[float], use_sim_state: bool, is_myco: bool, myco_progress: float, clear_alpha: float, clearing: bool, has_live_state: bool, current_needed: Array[String]) -> Dictionary:
	var fading_obsolete_myco_resource := is_myco and not current_needed.has(need)
	var visual := _fading_myco_need_visual(index, count, cell_radius) if fading_obsolete_myco_resource else _need_visual_data(cell, need, index, count, center, cell_radius, pip_radius, used_angles, true, use_sim_state)
	var angle := float(visual.get("angle", 0.0))
	used_angles.append(float(visual.get("targetAngle", angle)))
	var pip_offset := float(visual.get("offset", cell_radius * 1.18))
	return {
		"cell": cell,
		"need": need,
		"cellCenter": center,
		"center": center + Vector2(cos(angle), sin(angle)) * pip_offset,
		"radius": pip_radius,
		"state": str(visual.get("state", NEED_STATE_MISSING)),
		"fullness": float(visual.get("fullness", 0.0)),
		"activeAlpha": float(visual.get("activeAlpha", 0.0)),
		"isMyco": is_myco,
		"mycoProgress": myco_progress,
		"clearAlpha": clear_alpha,
		"clearing": clearing,
		"hasLiveState": has_live_state
	}


func _draw_blank_myco_pip(center: Vector2, radius: float, alpha: float) -> void:
	draw_circle(center, radius, Color(0.92, 0.97, 0.96, alpha))
	_draw_ring(center, radius, Color(0.01, 0.025, 0.03, 0.68 * alpha), 2.2)
	_draw_ring(center, radius * 0.84, Color(1.0, 1.0, 1.0, 0.52 * alpha), 1.4)


func _draw_need_pip(font: Font, pip_data: Dictionary, cell_radius: float, draw_tether: bool = true) -> void:
	var cell := str(pip_data.get("cell", ""))
	var need := str(pip_data.get("need", ""))
	var cell_center: Vector2 = pip_data.get("cellCenter", Vector2.ZERO) as Vector2
	var pip_center: Vector2 = pip_data.get("center", Vector2.ZERO) as Vector2
	var pip_radius := float(pip_data.get("radius", 0.0))
	var state := str(pip_data.get("state", NEED_STATE_MISSING))
	var fullness := float(pip_data.get("fullness", 0.0))
	var active_alpha := float(pip_data.get("activeAlpha", 0.0))
	var is_myco := bool(pip_data.get("isMyco", false))
	var myco_progress := float(pip_data.get("mycoProgress", 1.0))
	var clear_alpha := float(pip_data.get("clearAlpha", 1.0))
	var clearing := bool(pip_data.get("clearing", false))
	var pip_color := _resource_color(need)
	if state == NEED_STATE_MISSING:
		pip_color = pip_color.darkened(0.48)
		if draw_tether:
			_draw_need_tether(cell_center, pip_center, cell_radius, pip_radius, Color(0.75, 0.88, 0.90, 0.28 * clear_alpha))
	elif state == NEED_STATE_AVAILABLE:
		pip_color = pip_color.darkened(0.12)
		if draw_tether:
			_draw_need_tether(cell_center, pip_center, cell_radius, pip_radius, Color(pip_color.r, pip_color.g, pip_color.b, 0.42 * clear_alpha))
	elif state == NEED_STATE_ACTIVE:
		draw_circle(pip_center, pip_radius * (1.14 + active_alpha * 0.16), Color(pip_color.r, pip_color.g, pip_color.b, (0.20 + active_alpha * 0.26) * clear_alpha))
	pip_color.a = clear_alpha
	if is_myco:
		var waiting_color := Color(0.92, 0.97, 0.96, clear_alpha)
		pip_color = waiting_color.lerp(pip_color, myco_progress)
		pip_color.a = clear_alpha
	draw_circle(pip_center, pip_radius, pip_color)
	_draw_ring(pip_center, pip_radius, Color(0.01, 0.025, 0.03, 0.82 * clear_alpha), 2.2)
	_draw_ring(pip_center, pip_radius * 0.86, Color(1.0, 1.0, 1.0, (0.44 if state != NEED_STATE_MISSING or fullness > 0.0 else 0.28) * clear_alpha), 1.4)
	var pip_bar_radius := pip_radius * 1.12
	var pip_bar_width := maxf(2.0, pip_radius * 0.20)
	if not clearing:
		var visual_fullness := fullness * myco_progress if is_myco else fullness
		_draw_fullness_arc(pip_center, pip_bar_radius, _displayed_fullness(cell, need, visual_fullness), pip_color, pip_bar_width)
	if _should_elevate_need_pip(pip_data):
		_draw_zero_pip_pulse_arc(pip_center, pip_bar_radius, pip_bar_width)
	var mark_alpha := clear_alpha * (myco_progress if is_myco else 1.0)
	_draw_resource_mark(font, pip_center, pip_radius, need, int(pip_radius * 1.02 * NEED_PIP_MARK_SIZE_SCALE), Color(1.0, 1.0, 1.0, mark_alpha), NEED_PIP_MARK_WEIGHT_SCALE)


func _should_elevate_need_pip(pip_data: Dictionary) -> bool:
	return not bool(pip_data.get("clearing", false)) and bool(pip_data.get("hasLiveState", false)) and float(pip_data.get("fullness", 0.0)) <= 0.0


func _draw_zero_need_pip_overlays() -> void:
	if not _board_visible or not _using_sim_state or _zero_need_pip_overlay_pips.is_empty():
		return
	var font := get_theme_default_font()
	for overlay_data in _zero_need_pip_overlay_pips:
		var pip_value: Variant = overlay_data.get("pip", {})
		if not pip_value is Dictionary:
			continue
		_draw_need_pip(font, pip_value as Dictionary, float(overlay_data.get("cellRadius", 0.0)), false)


func _need_visual_data(cell: String, need: String, index: int, count: int, center: Vector2, cell_radius: float, pip_radius: float, used_angles: Array[float], apply_smoothing: bool = true, use_sim_state: bool = true) -> Dictionary:
	var state := _need_state_data(cell, need, use_sim_state)
	state["partner"] = _stabilize_need_partner(cell, need, index, str(state.get("partner", "")))
	var partner := str(state.get("partner", ""))
	var base_angle := _base_need_angle(cell, need, index, count, center, partner)
	var target_angle := _separate_need_angle(base_angle, used_angles)
	var target_offset := _need_pip_offset_for_state(center, partner, cell_radius, pip_radius, str(state.get("state", NEED_STATE_MISSING)))
	var key := _pip_key(cell, need, index)
	var angle := _smooth_pip_angle(key, target_angle) if apply_smoothing else target_angle
	var offset := _smooth_pip_offset(key, target_offset) if apply_smoothing else target_offset
	state["angle"] = angle
	state["offset"] = offset
	state["targetAngle"] = target_angle
	return state


func _need_state_data(cell: String, need: String, use_sim_state: bool = true) -> Dictionary:
	var live_state := use_sim_state and _using_sim_state
	var preferred_partner := _preferred_need_partner(cell, need)
	var fullness := _cached_slot_fullness(cell, need) if live_state else 0.0
	var active_partner := _recent_flow_source_for_need(cell, need) if live_state else ""
	var active_alpha := _recent_flow_alpha_for_need(cell, need) if live_state else 0.0
	if live_state and active_partner.is_empty():
		active_partner = _recent_swap_partner_for_need(cell, need)
	if not preferred_partner.is_empty() and _can_partner_satisfy_need(cell, need, preferred_partner):
		if live_state and not active_partner.is_empty():
			return {"state": NEED_STATE_ACTIVE, "partner": preferred_partner, "fullness": maxf(fullness, 0.18), "activeAlpha": maxf(active_alpha, 0.45)}
		return {"state": NEED_STATE_AVAILABLE, "partner": preferred_partner, "fullness": 1.0, "activeAlpha": 0.0}
	var possible_partner := _possible_swap_partner_for_need(cell, need) if live_state else _adjacent_reciprocal_partner_for_need(cell, need)
	if live_state and possible_partner.is_empty():
		possible_partner = _adjacent_exchange_partner_for_need(cell, need)
	if live_state and not active_partner.is_empty():
		return {"state": NEED_STATE_ACTIVE, "partner": possible_partner, "fullness": maxf(fullness, 0.18), "activeAlpha": maxf(active_alpha, 0.45)}
	if not possible_partner.is_empty():
		return {"state": NEED_STATE_AVAILABLE, "partner": possible_partner, "fullness": fullness, "activeAlpha": 0.0}
	if fullness > 0.0:
		return {"state": NEED_STATE_SATISFIED, "partner": "", "fullness": fullness, "activeAlpha": 0.0}
	return {"state": NEED_STATE_MISSING, "partner": "", "fullness": 0.0, "activeAlpha": 0.0}


func _draw_red_myco_ring(center: Vector2, radius: float, alpha: float) -> void:
	var ring_radius := radius * 0.54
	_draw_ring(center, ring_radius, Color(0.86, 0.02, 0.04, 0.16 * alpha), maxf(2.0, radius * 0.18))
	_draw_ring(center, ring_radius, Color(0.92, 0.04, 0.06, 0.44 * alpha), maxf(1.6, radius * 0.12))
	_draw_ring(center, ring_radius, Color(0.70, 0.00, 0.02, 0.88 * alpha), maxf(1.2, radius * 0.055))


func _draw_need_tether(center: Vector2, pip_center: Vector2, cell_radius: float, pip_radius: float, color: Color) -> void:
	var delta := pip_center - center
	if delta.length_squared() <= 1.0:
		return
	var direction := delta.normalized()
	draw_line(center + direction * (cell_radius * 0.78), pip_center - direction * (pip_radius * 0.72), color, 2.0, true)


func _draw_fullness_arc(center: Vector2, radius: float, fullness: float, color: Color, width: float) -> void:
	var amount := clampf(fullness, 0.0, 1.0)
	_draw_ring(center, radius, Color(0.0, 0.0, 0.0, 0.34), width)
	if amount <= 0.0:
		return
	var active := color.lightened(0.26)
	active.a = 0.92
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * amount, _arc_segments(radius), active, width, true)


func _draw_zero_pip_pulse_arc(center: Vector2, radius: float, width: float) -> void:
	var alpha := _zero_pip_pulse_alpha()
	if alpha <= 0.0:
		return
	var pulse_color := ZERO_PIP_PULSE_COLOR
	var glow_radius := radius * ZERO_PIP_PULSE_GLOW_SCALE
	pulse_color.a = minf(1.0, 0.58 * ZERO_PIP_PULSE_BRIGHTNESS_SCALE * alpha)
	_draw_ring(center, glow_radius, pulse_color, (width + 1.2) * ZERO_PIP_PULSE_GLOW_SCALE)
	pulse_color.a = minf(1.0, 0.22 * ZERO_PIP_PULSE_BRIGHTNESS_SCALE * alpha)
	_draw_ring(center, radius * 1.08 * ZERO_PIP_PULSE_GLOW_SCALE, pulse_color, maxf(1.4, width * 0.55) * ZERO_PIP_PULSE_GLOW_SCALE)


func _draw_ring(center: Vector2, radius: float, color: Color, width: float, antialiased: bool = true) -> void:
	if radius <= 0.0 or width <= 0.0 or color.a <= 0.0:
		return
	draw_circle(center, radius, color, false, width, antialiased)


func _draw_resource_mark(font: Font, center: Vector2, radius: float, resource: String, font_size: int, color: Color, mark_weight_scale: float = 1.0) -> void:
	var mark := _resource_mark_text(resource)
	if mark.is_empty():
		return
	_draw_centered_text(font, center, radius, mark, font_size, color, mark_weight_scale)


func _resource_mark_text(resource: String) -> String:
	if _resource_mark_mode == MARK_MODE_HIDDEN:
		return ""
	if _resource_mark_mode == MARK_MODE_SYMBOLS:
		var index := RESOURCE_LETTERS.find(resource)
		if index >= 0 and index < RESOURCE_SYMBOL_MARKS.size():
			return str(RESOURCE_SYMBOL_MARKS[index])
	return resource


func _draw_centered_text(font: Font, center: Vector2, radius: float, text: String, font_size: int, color: Color, mark_weight_scale: float = 1.0) -> void:
	if text.is_empty():
		return
	var width := radius * 2.0
	var origin := Vector2(center.x - radius, center.y + float(font_size) * 0.35)
	var outline := Color(0.01, 0.025, 0.03, 0.86 * color.a)
	var outline_offset := 1.5 * mark_weight_scale
	draw_string(font, origin + Vector2(-outline_offset, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	draw_string(font, origin + Vector2(outline_offset, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	draw_string(font, origin + Vector2(0.0, -outline_offset), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	draw_string(font, origin + Vector2(0.0, outline_offset), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
	draw_string(font, origin + Vector2(0.7 * mark_weight_scale, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _cached_resource_visual_point(cell: String, resource: String) -> Vector2:
	var key := str(cell, LOOKUP_KEY_SEPARATOR, resource)
	var cached_value: Variant = _resource_visual_point_cache.get(key, null)
	if cached_value is Vector2:
		return cached_value as Vector2
	var point := _resource_visual_point(cell, resource)
	_resource_visual_point_cache[key] = point
	return point


func _resource_visual_point(cell: String, resource: String) -> Vector2:
	var center := _visual_cell_center(cell)
	var lookup_key := _need_lookup_key(cell, resource)
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


func _pip_key(cell: String, need: String, index: int) -> String:
	return str(cell, ":", need, ":", index)


func _pip_slot_key(cell: String, index: int) -> String:
	return str(cell, ":__slot__:", index)


func _recent_flow_source_for_need(cell: String, need: String) -> String:
	if not _using_sim_state:
		return ""
	var flow_value: Variant = _recent_flow_by_need.get(_need_lookup_key(cell, need), {})
	if flow_value is Dictionary:
		return str((flow_value as Dictionary).get("source", ""))
	return ""


func _recent_flow_alpha_for_need(cell: String, need: String) -> float:
	if not _using_sim_state:
		return 0.0
	var flow_value: Variant = _recent_flow_by_need.get(_need_lookup_key(cell, need), {})
	if flow_value is Dictionary:
		return float((flow_value as Dictionary).get("alpha", 0.0))
	return 0.0


func _recent_swap_partner_for_need(cell: String, need: String) -> String:
	return str(_recent_swap_partner_by_need.get(_need_lookup_key(cell, need), "")) if _using_sim_state else ""


func _possible_swap_partner_for_need(cell: String, need: String) -> String:
	return str(_possible_swap_partner_by_need.get(_need_lookup_key(cell, need), "")) if _using_sim_state else ""


func _adjacent_exchange_partner_for_need(cell: String, need: String) -> String:
	if not _positions.has(cell):
		return ""
	for other in _cells:
		if other == cell or not _is_adjacent(cell, other):
			continue
		if _cell_can_offer_resource_to(other, need, cell) and _cell_has_payable_resource_for(other, cell):
			return other
	return ""


func _adjacent_reciprocal_partner_for_need(cell: String, need: String) -> String:
	if not _positions.has(cell):
		return ""
	for other in _cells:
		if other == cell or not _is_adjacent(cell, other):
			continue
		if _cached_cell_produced_resource(other) == need and _cell_needs_resource(other, _cached_cell_produced_resource(cell)):
			return other
	return ""


func _stabilize_need_partner(cell: String, need: String, index: int, proposed_partner: String) -> String:
	var key := _pip_key(cell, need, index)
	var preferred_partner := _preferred_need_partner(cell, need)
	if not preferred_partner.is_empty() and _can_partner_satisfy_need(cell, need, preferred_partner):
		_pip_partners[key] = preferred_partner
		return preferred_partner
	var current_partner := str(_pip_partners.get(key, ""))
	if not current_partner.is_empty() and _is_usable_need_partner(cell, need, current_partner):
		return current_partner
	if not proposed_partner.is_empty() and _is_usable_need_partner(cell, need, proposed_partner):
		_pip_partners[key] = proposed_partner
		return proposed_partner
	_pip_partners.erase(key)
	return ""


func _is_usable_need_partner(cell: String, need: String, partner: String) -> bool:
	return (_is_preferred_need_partner(cell, need, partner) or _is_adjacent(cell, partner)) and _can_partner_satisfy_need(cell, need, partner)


func _can_partner_satisfy_need(cell: String, need: String, partner: String) -> bool:
	return not partner.is_empty() and _cell_structurally_offers_resource_to(partner, need, cell)


func _cell_structurally_offers_resource_to(cell: String, resource: String, other: String) -> bool:
	if resource.is_empty() or not _cell_accepts_resource(other, resource):
		return false
	if _cached_cell_produced_resource(cell) == resource:
		return true
	var state_value: Variant = _cell_state_by_id.get(cell, {})
	if state_value is Dictionary:
		var slots_value: Variant = (state_value as Dictionary).get("slots", [])
		if slots_value is Array:
			var slots: Array = slots_value as Array
			for slot_value in slots:
				if slot_value is Dictionary and str((slot_value as Dictionary).get("resource", "")) == resource:
					return true
	return _cell_needs_resource(cell, resource)


func _is_preferred_need_partner(cell: String, need: String, partner: String) -> bool:
	return not partner.is_empty() and _preferred_need_partner(cell, need) == partner


func _is_adjacent(a: String, b: String) -> bool:
	return not a.is_empty() and not b.is_empty() and _positions.has(a) and _positions.has(b) and _get_cell_tile(a).distance_squared_to(_get_cell_tile(b)) == 1


func _base_need_angle(cell: String, need: String, index: int, count: int, center: Vector2, partner: String) -> float:
	if not partner.is_empty():
		var partner_delta := _visual_cell_center(partner) - center
		if partner_delta.length_squared() > 1.0:
			return partner_delta.angle()
	if not _using_sim_state:
		var reciprocal_partner := _adjacent_reciprocal_partner_for_need(cell, need)
		if not reciprocal_partner.is_empty():
			var reciprocal_delta := _visual_cell_center(reciprocal_partner) - center
			if reciprocal_delta.length_squared() > 1.0:
				return reciprocal_delta.angle()
	return -PI * 0.5 + TAU * float(index) / maxf(float(count), 1.0)


func _cell_has_payable_resource_for(cell: String, other: String) -> bool:
	var produced := _cached_cell_produced_resource(cell)
	if not produced.is_empty() and _cell_accepts_resource(other, produced):
		return true
	var state_value: Variant = _cell_state_by_id.get(cell, {})
	if not state_value is Dictionary:
		return false
	var slots_value: Variant = (state_value as Dictionary).get("slots", [])
	if not slots_value is Array:
		return false
	var slots: Array = slots_value as Array
	for slot_value in slots:
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value as Dictionary
		var resource := str(slot.get("resource", ""))
		if _cell_accepts_resource(other, resource) and _slot_offerable_quantity(cell, resource) > 0:
			return true
	return false


func _cell_can_offer_resource_to(cell: String, resource: String, other: String) -> bool:
	if resource.is_empty():
		return false
	if _cached_cell_produced_resource(cell) == resource and _cell_accepts_resource(other, resource):
		return true
	return _cell_accepts_resource(other, resource) and _slot_offerable_quantity(cell, resource) > 0


func _cell_accepts_resource(cell: String, resource: String) -> bool:
	if resource.is_empty():
		return false
	if _cached_cell_produced_resource(cell) == resource or _cell_needs_resource(cell, resource):
		return true
	var state_value: Variant = _cell_state_by_id.get(cell, {})
	if not state_value is Dictionary:
		return false
	var slots_value: Variant = (state_value as Dictionary).get("slots", [])
	if not slots_value is Array:
		return false
	var slots: Array = slots_value as Array
	for slot_value in slots:
		if slot_value is Dictionary and str((slot_value as Dictionary).get("resource", "")) == resource:
			return true
	return false


func _slot_offerable_quantity(cell: String, resource: String) -> int:
	var state_value: Variant = _cell_state_by_id.get(cell, {})
	if not state_value is Dictionary:
		return 0
	var slots_value: Variant = (state_value as Dictionary).get("slots", [])
	if not slots_value is Array:
		return 0
	var slots: Array = slots_value as Array
	for slot_value in slots:
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value as Dictionary
		if str(slot.get("resource", "")) != resource:
			continue
		var quantity := int(slot.get("quantity", 0))
		if _is_myco_kind(_cached_cell_kind(cell)):
			return maxi(0, quantity)
		var role := str(slot.get("role", ""))
		if role == "Need" or role == "SourceOutput":
			quantity -= 1
		return maxi(0, quantity)
	return 0


func _cell_needs_resource(cell: String, resource: String) -> bool:
	if resource.is_empty():
		return false
	if _cell_needs(cell).has(resource):
		return true
	if _is_myco_kind(_cached_cell_kind(cell)):
		return _need_slot_resources_for_cell(cell).has(resource)
	return false


func _cell_has_all_needs(cell: String, use_sim_state: bool = true) -> bool:
	var needed := _cell_needs(cell)
	for need in needed:
		if use_sim_state and _using_sim_state:
			if _cached_slot_fullness(cell, need) <= 0.0:
				return false
		elif _preferred_need_partner(cell, need).is_empty() and _adjacent_reciprocal_partner_for_need(cell, need).is_empty():
			return false
	return not needed.is_empty()


func _cached_cell_is_glowing(cell: String) -> bool:
	if _draw_cell_glow_cache.has(cell):
		return bool(_draw_cell_glow_cache.get(cell, false))
	var glowing := _cell_is_glowing(cell)
	_draw_cell_glow_cache[cell] = glowing
	return glowing


func _cell_is_glowing(cell: String) -> bool:
	var state_value: Variant = _cell_state_by_id.get(cell, {})
	if state_value is Dictionary:
		return bool((state_value as Dictionary).get("glowing", false))
	return false


func _cached_slot_fullness(cell: String, resource: String) -> float:
	var key := str(cell, LOOKUP_KEY_SEPARATOR, resource)
	if _draw_slot_fullness_cache.has(key):
		return float(_draw_slot_fullness_cache.get(key, 0.0))
	var fullness := _slot_fullness(cell, resource)
	_draw_slot_fullness_cache[key] = fullness
	return fullness


func _slot_fullness(cell: String, resource: String) -> float:
	var state_value: Variant = _cell_state_by_id.get(cell, {})
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


func _cached_need_health(cell: String) -> Dictionary:
	if _draw_need_health_cache.has(cell):
		var cached_value: Variant = _draw_need_health_cache.get(cell, {})
		if cached_value is Dictionary:
			return cached_value as Dictionary
	var health := _need_health(cell)
	_draw_need_health_cache[cell] = health
	return health


func _need_health(cell: String) -> Dictionary:
	var state_value: Variant = _cell_state_by_id.get(cell, {})
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


func _cached_recent_reaction_alpha(cell: String) -> float:
	if _draw_reaction_alpha_cache.has(cell):
		return float(_draw_reaction_alpha_cache.get(cell, 0.0))
	var alpha := _recent_reaction_alpha(cell)
	_draw_reaction_alpha_cache[cell] = alpha
	return alpha


func _recent_reaction_alpha(cell: String) -> float:
	if not _using_sim_state:
		return 0.0
	var reactions_value: Variant = _snapshot.get("reactions", [])
	if not reactions_value is Array:
		return 0.0
	var current_tick := float(_snapshot.get("tick", 0))
	var reactions: Array = reactions_value as Array
	for index in range(reactions.size() - 1, -1, -1):
		var reaction_value: Variant = reactions[index]
		if not reaction_value is Dictionary:
			continue
		var reaction: Dictionary = reaction_value as Dictionary
		if str(reaction.get("cellId", "")) != cell:
			continue
		var age := maxf(0.0, current_tick - float(reaction.get("tick", current_tick)))
		return clampf(1.0 - age / REACTION_VISUAL_TTL_TICKS, 0.0, 1.0)
	return 0.0


func _visual_cell_center(cell: String) -> Vector2:
	if cell == _drag_cell:
		return _drag_position
	if cell == _inventory_drag_cell:
		return _inventory_drag_position
	if _override_cell_centers.has(cell):
		return _override_cell_centers[cell] as Vector2
	if _inventory_centers.has(cell):
		return _inventory_visual_center(_inventory_centers[cell] as Vector2)
	if _positions.has(cell):
		return _tile_center(_get_cell_tile(cell))
	return Vector2.ZERO


func _inventory_visual_center(center: Vector2) -> Vector2:
	return center + Vector2(0.0, _tile_size * INVENTORY_CELL_Y_OFFSET)


func _cell_visual_scale(cell: String) -> float:
	if _override_cell_scales.has(cell):
		return float(_override_cell_scales.get(cell, 1.0))
	return INVENTORY_CELL_SCALE if _inventory_cells.has(cell) else 1.0


func _preferred_need_partner(cell: String, need: String) -> String:
	var value: Variant = _preferred_need_partners.get(cell, {})
	if not value is Dictionary:
		return ""
	var by_need: Dictionary = value as Dictionary
	var partner := str(by_need.get(need, ""))
	if not partner.is_empty() and _cells.has(partner):
		return partner
	return ""


func _cell_needs(cell: String) -> Array[String]:
	var result: Array[String] = []
	var value: Variant = _needs.get(cell, [])
	if value is Array:
		var needs_array: Array = value as Array
		for need in needs_array:
			result.append(str(need))
	return result


func _cached_visual_needs_for_cell(cell: String, is_myco: bool, use_sim_state: bool = true) -> Array[String]:
	var kind_key := "myco" if is_myco else "normal"
	var state_key := "sim" if use_sim_state else "base"
	var key := str(cell, LOOKUP_KEY_SEPARATOR, kind_key, LOOKUP_KEY_SEPARATOR, state_key)
	var cached_value: Variant = _draw_visual_needs_cache.get(key, null)
	if cached_value is Array:
		return _strings_from_array(cached_value as Array)
	var needs := _visual_needs_for_cell(cell, is_myco, use_sim_state)
	_draw_visual_needs_cache[key] = needs
	return needs


func _visual_needs_for_cell(cell: String, is_myco: bool, use_sim_state: bool = true) -> Array[String]:
	if is_myco and use_sim_state and _using_sim_state and _cell_state_by_id.has(cell):
		return _need_slot_resources_for_cell(cell)
	return _cell_needs(cell)


func _need_slot_resources_for_cell(cell: String) -> Array[String]:
	var result: Array[String] = []
	var state_value: Variant = _cell_state_by_id.get(cell, {})
	if not state_value is Dictionary:
		return result
	var slots_value: Variant = (state_value as Dictionary).get("slots", [])
	if not slots_value is Array:
		return result
	var slots: Array = slots_value as Array
	for slot_value in slots:
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value as Dictionary
		if str(slot.get("role", "")) == "Need":
			var resource := str(slot.get("resource", ""))
			if not resource.is_empty():
				result.append(resource)
	return result


func _build_myco_pip_visual_state(cell: String, current_resources: Array[String]) -> Dictionary:
	var now := Time.get_ticks_msec()
	var target_signature := _myco_pip_signature(current_resources)
	if not _myco_pip_signatures.has(cell):
		_myco_pip_signatures[cell] = target_signature
		_myco_pip_transition_starts[cell] = now
		_myco_previous_pip_resources[cell] = []
		_myco_target_pip_resources[cell] = current_resources.duplicate()
		if current_resources.is_empty():
			return {"resources": [], "progress": 1.0}
		_myco_transition_animation_active = true
		return {"resources": current_resources, "progress": 0.0}

	var previous_signature := str(_myco_pip_signatures.get(cell, MYCO_WAITING_SIGNATURE))
	if previous_signature != target_signature:
		_myco_pip_signatures[cell] = target_signature
		_myco_pip_transition_starts[cell] = now
		var old_target_value: Variant = _myco_target_pip_resources.get(cell, [])
		if old_target_value is Array:
			_myco_previous_pip_resources[cell] = _strings_from_array(old_target_value as Array)
		else:
			_myco_previous_pip_resources[cell] = _resources_from_myco_pip_signature(previous_signature)
		_myco_target_pip_resources[cell] = current_resources.duplicate()

	if not _myco_pip_transition_starts.has(cell):
		return {"resources": current_resources, "progress": 1.0}

	var start := int(_myco_pip_transition_starts.get(cell, now))
	var elapsed := now - start
	var previous_resources: Array[String] = []
	var previous_value: Variant = _myco_previous_pip_resources.get(cell, [])
	if previous_value is Array:
		previous_resources = _strings_from_array(previous_value as Array)
	var target_resources: Array[String] = current_resources
	var target_value: Variant = _myco_target_pip_resources.get(cell, current_resources)
	if target_value is Array:
		target_resources = _strings_from_array(target_value as Array)

	if not previous_resources.is_empty() and elapsed < MYCO_FADE_OUT_MSEC:
		var fade_out_progress := 1.0 - clampf(float(elapsed) / float(MYCO_FADE_OUT_MSEC), 0.0, 1.0)
		if fade_out_progress > 0.0:
			_myco_transition_animation_active = true
		return {"resources": previous_resources, "progress": fade_out_progress}

	if target_resources.is_empty():
		return {"resources": [], "progress": 1.0}

	var fade_in_elapsed := elapsed - MYCO_FADE_OUT_MSEC if not previous_resources.is_empty() else elapsed
	var fade_in_progress := clampf(float(fade_in_elapsed) / float(MYCO_ADAPT_TRANSITION_MSEC), 0.0, 1.0)
	if fade_in_progress < 1.0:
		_myco_transition_animation_active = true
	return {"resources": target_resources, "progress": fade_in_progress}


func _myco_pip_signature(resources: Array[String]) -> String:
	if resources.is_empty():
		return MYCO_WAITING_SIGNATURE
	var signature := ""
	for resource in resources:
		if signature.is_empty():
			signature = resource
		else:
			signature = str(signature, "|", resource)
	return signature


func _resources_from_myco_pip_signature(signature: String) -> Array[String]:
	var result: Array[String] = []
	if signature == MYCO_WAITING_SIGNATURE:
		return result
	for resource in signature.split("|", false):
		var text := str(resource)
		if not text.is_empty():
			result.append(text)
	return result


func _fading_myco_need_visual(index: int, count: int, cell_radius: float) -> Dictionary:
	var angle := -PI * 0.5 + TAU * float(index) / maxf(float(count), 1.0)
	return {
		"state": NEED_STATE_SATISFIED,
		"partner": "",
		"fullness": 1.0,
		"activeAlpha": 0.0,
		"angle": angle,
		"offset": cell_radius * 1.18,
		"targetAngle": angle
	}


func _blank_myco_need_visual(index: int, count: int, cell_radius: float) -> Dictionary:
	return _fading_myco_need_visual(index, count, cell_radius)


func _default_myco_slot_center(center: Vector2, index: int, count: int, cell_radius: float) -> Vector2:
	var angle := -PI * 0.5 + TAU * float(index) / maxf(float(count), 1.0)
	return center + Vector2(cos(angle), sin(angle)) * cell_radius * 1.18


func _cached_cell_produced_resource(cell: String) -> String:
	if _draw_cell_produced_cache.has(cell):
		return str(_draw_cell_produced_cache.get(cell, ""))
	var produced := _cell_produced_resource(cell)
	_draw_cell_produced_cache[cell] = produced
	return produced


func _cell_produced_resource(cell: String) -> String:
	if _is_myco_kind(_cached_cell_kind(cell)):
		return ""
	return str(_produced_by_cell.get(cell, cell))


func _cached_cell_kind(cell: String) -> String:
	if _draw_cell_kind_cache.has(cell):
		return str(_draw_cell_kind_cache.get(cell, CELL_KIND_STANDARD))
	var kind := _cell_kind(cell)
	_draw_cell_kind_cache[cell] = kind
	return kind


func _cell_kind(cell: String) -> String:
	return str(_cell_kinds.get(cell, CELL_KIND_STANDARD))


func _is_myco_kind(kind: String) -> bool:
	return kind == CELL_KIND_WHITE_MYCO or kind == CELL_KIND_RED_MYCO


func _circuit_alive_now() -> bool:
	return bool(_snapshot.get("alive", false)) if _using_sim_state else _solved


func _displayed_fullness(cell: String, resource: String, target: float) -> float:
	var key := str(cell, ":", resource)
	target = clampf(target, 0.0, 1.0)
	if not _display_fullness.has(key):
		_display_fullness[key] = target
		return target
	var current := float(_display_fullness.get(key, target))
	var next := lerpf(current, target, 0.18)
	if absf(next - target) < 0.0025:
		next = target
	_display_fullness[key] = next
	return next


func _need_pip_radius(cell_radius: float) -> float:
	return maxf(5.5, minf(cell_radius * 0.38, _tile_size * 0.15))


func _need_pip_offset(center: Vector2, partner: String, cell_radius: float, pip_radius: float) -> float:
	if partner.is_empty():
		return cell_radius + pip_radius * 0.30
	var distance := (_visual_cell_center(partner) - center).length()
	if distance <= 1.0:
		return cell_radius + pip_radius * 0.30
	var rim := cell_radius + pip_radius * 0.08
	var maximum := maxf(rim, distance * 0.5 - pip_radius * 0.58)
	return minf(rim, maximum)


func _need_pip_offset_for_state(center: Vector2, partner: String, cell_radius: float, pip_radius: float, state: String) -> float:
	if partner.is_empty():
		return cell_radius + pip_radius * (0.10 if state == NEED_STATE_SATISFIED else 0.55)
	var distance := (_visual_cell_center(partner) - center).length()
	if distance <= 1.0:
		return cell_radius + pip_radius * 0.30
	var rim := cell_radius + pip_radius * 0.08
	var maximum := maxf(rim, distance * 0.5 - pip_radius * 0.58)
	return minf(rim, maximum)


func _separate_need_angle(base_angle: float, used_angles: Array[float]) -> float:
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


func _smooth_pip_angle(key: String, target_angle: float, smooth: float = PIP_ANGLE_SMOOTH) -> float:
	if not _pip_angles.has(key):
		_pip_angles[key] = target_angle
		return target_angle
	var current := float(_pip_angles.get(key, target_angle))
	var delta := wrapf(target_angle - current, -PI, PI)
	if absf(delta) < PIP_ANGLE_DEAD_ZONE:
		return current
	var smoothed := current + delta * smooth
	_pip_angles[key] = smoothed
	return smoothed


func _smooth_pip_offset(key: String, target_offset: float, smooth: float = PIP_OFFSET_SMOOTH) -> float:
	if not _pip_offsets.has(key):
		_pip_offsets[key] = target_offset
		return target_offset
	var current := float(_pip_offsets.get(key, target_offset))
	if absf(target_offset - current) < PIP_OFFSET_DEAD_ZONE:
		return current
	var smoothed := lerpf(current, target_offset, smooth)
	_pip_offsets[key] = smoothed
	return smoothed


func _inventory_fresh_strength(cell: String) -> float:
	if not _inventory_fresh_starts.has(cell):
		return 0.0
	var start_msec := int(_inventory_fresh_starts.get(cell, 0))
	var elapsed := float(Time.get_ticks_msec() - start_msec) / 1000.0
	return clampf(1.0 - elapsed / 1.55, 0.0, 1.0)


func _clearing_alpha() -> float:
	var fade_progress := clampf((_clear_effect_progress - 0.18) / 0.82, 0.0, 1.0)
	return clampf(1.0 - pow(fade_progress, 1.35), 0.0, 1.0)


func _clearing_flash() -> float:
	return clampf(1.0 - absf(_clear_effect_progress - 0.18) / 0.18, 0.0, 1.0)


func _zero_pip_pulse_alpha() -> float:
	var phase := Time.get_ticks_msec() % ZERO_PIP_PULSE_PERIOD_MSEC
	if phase < ZERO_PIP_PULSE_FADE_MSEC:
		return float(phase) / float(ZERO_PIP_PULSE_FADE_MSEC)
	if phase < ZERO_PIP_PULSE_FADE_MSEC * 2:
		return 1.0 - float(phase - ZERO_PIP_PULSE_FADE_MSEC) / float(ZERO_PIP_PULSE_FADE_MSEC)
	return 0.0


func _resource_color(resource: String) -> Color:
	var index := RESOURCE_LETTERS.find(resource)
	if index < 0:
		return Color(0.80, 0.86, 0.86, 1.0)
	var value: Variant = RESOURCE_COLORS[index % RESOURCE_COLORS.size()]
	if value is Color:
		return value as Color
	return Color(0.80, 0.86, 0.86, 1.0)


func _circuit_group_color(index: int) -> Color:
	var value: Variant = CIRCUIT_GROUP_COLORS[index % CIRCUIT_GROUP_COLORS.size()]
	if value is Color:
		return value as Color
	return Color(0.30, 1.00, 0.84, 1.0)


func _circuit_age_alpha(age: float, window_ticks: float) -> float:
	var raw := clampf(1.0 - age / maxf(1.0, window_ticks), 0.0, 1.0)
	return pow(raw, 1.65)


func _flow_group_contains_all_cells(cells: Array[String]) -> bool:
	if cells.size() < _cells.size():
		return false
	var cell_set := {}
	for cell in cells:
		cell_set[cell] = true
	for cell in _cells:
		if not cell_set.has(cell):
			return false
	return true


func _line_intersects_viewport(start: Vector2, finish: Vector2, grow: float) -> bool:
	if _board_viewport_rect.size == Vector2.ZERO:
		return true
	var min_x := minf(start.x, finish.x)
	var min_y := minf(start.y, finish.y)
	var max_x := maxf(start.x, finish.x)
	var max_y := maxf(start.y, finish.y)
	var rect := Rect2(Vector2(min_x, min_y), Vector2(maxf(1.0, max_x - min_x), maxf(1.0, max_y - min_y))).grow(grow)
	return _board_viewport_rect.grow(grow).intersects(rect, true)


func _point_intersects_viewport(point: Vector2, radius: float) -> bool:
	if _board_viewport_rect.size == Vector2.ZERO:
		return true
	return _board_viewport_rect.grow(radius).has_point(point)


func _arc_segments(radius: float) -> int:
	return 16 if radius < 14.0 else (24 if radius < 28.0 else 36)


func _get_cell_tile(cell: String) -> Vector2i:
	var value: Variant = _positions.get(cell, Vector2i.ZERO)
	if value is Vector2i:
		return value as Vector2i
	return Vector2i.ZERO


func _tile_center(tile: Vector2i) -> Vector2:
	return _board_rect.position + (Vector2(tile) + Vector2(0.5, 0.5)) * _tile_size


func _tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(_board_rect.position + Vector2(tile) * _tile_size, Vector2(_tile_size, _tile_size))


func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var local := screen_pos - _board_rect.position
	return Vector2i(floori(local.x / _tile_size), floori(local.y / _tile_size))


func _is_tile_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < _board_cols and tile.y < _board_rows


func _is_tile_empty(tile: Vector2i) -> bool:
	for cell in _cells:
		if cell == _drag_cell:
			continue
		if _get_cell_tile(cell) == tile:
			return false
	return true


func _tile_key(tile: Vector2i) -> String:
	return str(tile.x, ":", tile.y)


func _dict_rect2(dict: Dictionary, key: String, fallback: Rect2) -> Rect2:
	var value: Variant = dict.get(key, fallback)
	if value is Rect2:
		return value as Rect2
	return fallback


func _dict_vector2(dict: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = dict.get(key, fallback)
	if value is Vector2:
		return value as Vector2
	return fallback


func _dict_vector2i(dict: Dictionary, key: String, fallback: Vector2i) -> Vector2i:
	var value: Variant = dict.get(key, fallback)
	if value is Vector2i:
		return value as Vector2i
	return fallback


func _read_string_array(state: Dictionary, key: String, target: Array[String]) -> void:
	target.clear()
	var value: Variant = state.get(key, [])
	if not value is Array:
		return
	var values: Array = value as Array
	for item in values:
		var text := str(item)
		if not text.is_empty():
			target.append(text)


func _read_positions(state: Dictionary) -> void:
	_positions.clear()
	var value: Variant = state.get("positions", {})
	if not value is Dictionary:
		return
	var positions: Dictionary = value as Dictionary
	for key in positions.keys():
		var position_value: Variant = positions.get(key, Vector2i.ZERO)
		if position_value is Vector2i:
			_positions[str(key)] = position_value


func _read_inventory_centers(state: Dictionary) -> void:
	_inventory_centers.clear()
	var value: Variant = state.get("inventoryCenters", {})
	if not value is Dictionary:
		return
	var centers: Dictionary = value as Dictionary
	for key in centers.keys():
		var center_value: Variant = centers.get(key, Vector2.ZERO)
		if center_value is Vector2:
			_inventory_centers[str(key)] = center_value


func _read_inventory_fresh_starts(state: Dictionary) -> void:
	_inventory_fresh_starts.clear()
	var value: Variant = state.get("inventoryFreshStarts", {})
	if not value is Dictionary:
		return
	var starts: Dictionary = value as Dictionary
	for key in starts.keys():
		_inventory_fresh_starts[str(key)] = int(starts.get(key, 0))


func _read_override_cell_centers(state: Dictionary) -> void:
	_override_cell_centers.clear()
	var value: Variant = state.get("overrideCellCenters", {})
	if not value is Dictionary:
		return
	var centers: Dictionary = value as Dictionary
	for key in centers.keys():
		var center_value: Variant = centers.get(key, Vector2.ZERO)
		if center_value is Vector2:
			_override_cell_centers[str(key)] = center_value


func _read_override_cell_scales(state: Dictionary) -> void:
	_override_cell_scales.clear()
	var value: Variant = state.get("overrideCellScales", {})
	if not value is Dictionary:
		return
	var scales: Dictionary = value as Dictionary
	for key in scales.keys():
		_override_cell_scales[str(key)] = float(scales.get(key, 1.0))


func _read_preferred_need_partners(state: Dictionary) -> void:
	_preferred_need_partners.clear()
	var value: Variant = state.get("preferredNeedPartners", {})
	if not value is Dictionary:
		return
	var source: Dictionary = value as Dictionary
	for cell_key in source.keys():
		var needs_value: Variant = source.get(cell_key, {})
		if not needs_value is Dictionary:
			continue
		var partner_by_need: Dictionary = {}
		var needs_source: Dictionary = needs_value as Dictionary
		for need_key in needs_source.keys():
			var need := str(need_key)
			var partner := str(needs_source.get(need_key, ""))
			if not need.is_empty() and not partner.is_empty():
				partner_by_need[need] = partner
		if not partner_by_need.is_empty():
			_preferred_need_partners[str(cell_key)] = partner_by_need


func _read_string_map(state: Dictionary, key: String, target: Dictionary) -> void:
	target.clear()
	var value: Variant = state.get(key, {})
	if not value is Dictionary:
		return
	var source: Dictionary = value as Dictionary
	for source_key in source.keys():
		target[str(source_key)] = str(source.get(source_key, ""))


func _read_needs(state: Dictionary) -> void:
	_needs.clear()
	var value: Variant = state.get("needs", {})
	if not value is Dictionary:
		return
	var source: Dictionary = value as Dictionary
	for source_key in source.keys():
		var result: Array[String] = []
		var needs_value: Variant = source.get(source_key, [])
		if needs_value is Array:
			var needs_array: Array = needs_value as Array
			for need in needs_array:
				result.append(str(need))
		_needs[str(source_key)] = result


func _read_rocks(state: Dictionary) -> void:
	_rocks.clear()
	var value: Variant = state.get("rocks", {})
	if value is Dictionary:
		var rocks_dict: Dictionary = value as Dictionary
		for key in rocks_dict.keys():
			_rocks[str(key)] = true
	elif value is Array:
		var rocks_array: Array = value as Array
		for rock in rocks_array:
			if rock is Vector2i:
				_rocks[_tile_key(rock)] = true


func _read_clearing_cells(state: Dictionary) -> void:
	_clearing_cells.clear()
	var value: Variant = state.get("clearingCells", [])
	if not value is Array:
		return
	var cells: Array = value as Array
	for cell in cells:
		_clearing_cells[str(cell)] = true


func _read_hint_pair(state: Dictionary) -> void:
	_hint_pair.clear()
	var value: Variant = state.get("hintPair", [])
	if not value is Array:
		return
	var pair: Array = value as Array
	if pair.size() == 2:
		_hint_pair = [str(pair[0]), str(pair[1])]


func _read_cell_states() -> void:
	_cell_state_by_id.clear()
	var value: Variant = _snapshot.get("cells", [])
	if not value is Array:
		return
	var cells: Array = value as Array
	for cell_value in cells:
		if not cell_value is Dictionary:
			continue
		var cell: Dictionary = cell_value as Dictionary
		var id := str(cell.get("id", ""))
		if not id.is_empty():
			_cell_state_by_id[id] = cell


func _rebuild_snapshot_indexes() -> void:
	_recent_flow_by_need.clear()
	_recent_swap_partner_by_need.clear()
	_possible_swap_partner_by_need.clear()
	_visible_recent_flows.clear()
	if not _using_sim_state:
		return
	var current_tick := float(_snapshot.get("tick", 0.0))
	var flows_value: Variant = _snapshot.get("flows", [])
	var visible_flow_keys := {}
	if flows_value is Array:
		var flows: Array = flows_value as Array
		for flow_index in range(flows.size() - 1, -1, -1):
			var flow_value: Variant = flows[flow_index]
			if not flow_value is Dictionary:
				continue
			var flow: Dictionary = flow_value as Dictionary
			var source := str(flow.get("sourceCellId", ""))
			var target := str(flow.get("targetCellId", ""))
			var resource := str(flow.get("resource", ""))
			if source.is_empty() or target.is_empty() or resource.is_empty():
				continue
			var age := maxf(0.0, current_tick - float(flow.get("tick", current_tick)))
			var alpha := clampf(1.0 - age / SWAP_VISUAL_TTL_TICKS, 0.0, 1.0)
			var line_key := str(source, LOOKUP_KEY_SEPARATOR, target, LOOKUP_KEY_SEPARATOR, resource)
			if alpha > 0.0 and _visible_recent_flows.size() < MAX_VISIBLE_FLOW_LINES and not visible_flow_keys.has(line_key):
				visible_flow_keys[line_key] = true
				_visible_recent_flows.append({"source": source, "target": target, "resource": resource, "age": age, "alpha": alpha})
			var need_key := _need_lookup_key(target, resource)
			if not _recent_flow_by_need.has(need_key):
				_recent_flow_by_need[need_key] = {"source": source, "alpha": alpha}
	var swaps_value: Variant = _snapshot.get("swaps", [])
	if swaps_value is Array:
		var swaps: Array = swaps_value as Array
		for swap_index in range(swaps.size() - 1, -1, -1):
			var swap_value: Variant = swaps[swap_index]
			if swap_value is Dictionary:
				_index_swap_partner(_recent_swap_partner_by_need, swap_value as Dictionary, false)
	var possible_value: Variant = _snapshot.get("possibleSwaps", [])
	if possible_value is Array:
		var possible_swaps: Array = possible_value as Array
		for possible_value_item in possible_swaps:
			if possible_value_item is Dictionary:
				_index_swap_partner(_possible_swap_partner_by_need, possible_value_item as Dictionary, false)


func _index_swap_partner(index: Dictionary, swap: Dictionary, overwrite: bool) -> void:
	var initiator := str(swap.get("initiator", ""))
	var counterparty := str(swap.get("counterparty", ""))
	if initiator.is_empty() or counterparty.is_empty():
		return
	var initiator_received := str(swap.get("counterpartyPaidResource", ""))
	if not initiator_received.is_empty():
		var initiator_key := _need_lookup_key(initiator, initiator_received)
		if overwrite or not index.has(initiator_key):
			index[initiator_key] = counterparty
	var counterparty_received := str(swap.get("initiatorPaidResource", ""))
	if not counterparty_received.is_empty():
		var counterparty_key := _need_lookup_key(counterparty, counterparty_received)
		if overwrite or not index.has(counterparty_key):
			index[counterparty_key] = initiator


func _need_lookup_key(cell: String, resource: String) -> String:
	return str(cell, LOOKUP_KEY_SEPARATOR, resource)


func _strings_from_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for item in values:
		result.append(str(item))
	return result
