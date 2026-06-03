extends Control

const SWAP_VISUAL_TTL_TICKS := 10.0
const REACTION_VISUAL_TTL_TICKS := 10.0
const PIP_ANGLE_SMOOTH := 0.14
const PIP_OFFSET_SMOOTH := 0.16
const ZERO_PIP_PULSE_PERIOD_MSEC := 3000
const ZERO_PIP_PULSE_FADE_MSEC := 1000
const MYCO_VISUAL_PIP_COUNT := 4
const INVENTORY_SLOT_SCALE := 1.28
const INVENTORY_CELL_SCALE := 1.10
const NEED_STATE_MISSING := "missing"
const NEED_STATE_AVAILABLE := "available"
const NEED_STATE_ACTIVE := "active"
const NEED_STATE_SATISFIED := "satisfied"
const CELL_KIND_STANDARD := "Standard"
const CELL_KIND_WHITE_MYCO := "WhiteMyco"
const CELL_KIND_RED_MYCO := "RedMyco"
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
var _display_fullness: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_render_state(state: Dictionary) -> void:
	_board_rect = _dict_rect2(state, "boardRect", _board_rect)
	_board_viewport_rect = _dict_rect2(state, "boardViewportRect", _board_rect)
	if _board_viewport_rect.size.x <= 1.0 or _board_viewport_rect.size.y <= 1.0:
		_board_viewport_rect = _board_rect
	_tile_size = float(state.get("tileSize", _tile_size))
	_board_cols = int(state.get("boardCols", _board_cols))
	_board_rows = int(state.get("boardRows", _board_rows))
	_board_visible = bool(state.get("boardVisible", true))
	_using_sim_state = bool(state.get("usingCsharpSim", false))
	_solved = bool(state.get("solved", false))
	_circuit_overlay_enabled = bool(state.get("circuitOverlayEnabled", true))
	_drag_cell = str(state.get("dragCell", ""))
	_drag_position = _dict_vector2(state, "dragPosition", Vector2.ZERO)
	_original_drag_tile = _dict_vector2i(state, "originalDragTile", Vector2i.ZERO)
	_inventory_drag_cell = str(state.get("inventoryDragCell", ""))
	_inventory_drag_position = _dict_vector2(state, "inventoryDragPosition", Vector2.ZERO)
	_clear_effect_progress = clampf(float(state.get("clearEffectProgress", 1.0)), 0.0, 1.0)
	_clear_effect_scale = clampf(float(state.get("clearEffectScale", 1.0)), 1.0, 1.85)
	_read_string_array(state, "cells", _cells)
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
	queue_redraw()


func set_drag_state(drag_cell: String, drag_position: Vector2, original_drag_tile: Vector2i, _fast_drag_mode: bool) -> void:
	_drag_cell = drag_cell
	_drag_position = drag_position
	_original_drag_tile = original_drag_tile
	queue_redraw()


func _draw() -> void:
	if _board_visible:
		_draw_board()
		_draw_circuit_flow_groups()
		_draw_recent_flows()
		_draw_hint()
	for cell in _cells:
		if cell == _drag_cell:
			continue
		_draw_cell(cell, _visual_cell_center(cell), false, true, _cell_visual_scale(cell))
	if _board_visible:
		_draw_inventory_cells()
	if not _drag_cell.is_empty():
		_draw_cell(_drag_cell, _drag_position, true, true, _cell_visual_scale(_drag_cell))
	if _board_visible and not _inventory_drag_cell.is_empty():
		_draw_cell(_inventory_drag_cell, _inventory_drag_position, true, false, INVENTORY_CELL_SCALE)


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
			var shade := 0.085 if (x + y) % 2 == 0 else 0.105
			draw_rect(rect, Color(shade, shade + 0.035, shade + 0.045, 1.0), true)
			draw_rect(rect, Color(0.24, 0.42, 0.42, 0.18), false, 1.0)
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
	_draw_circuit_blockers(diagnostics)
	var groups_value: Variant = diagnostics.get("strongGroups", [])
	if not groups_value is Array:
		return
	var groups: Array = groups_value as Array
	var pulse := 0.5 + sin(Time.get_ticks_msec() / 170.0) * 0.5
	for index in range(groups.size()):
		var group_value: Variant = groups[index]
		if not group_value is Array:
			continue
		var group_cells: Array[String] = _strings_from_array(group_value as Array)
		if group_cells.size() < 2:
			continue
		var color := _circuit_group_color(index)
		var fill := color
		fill.a = 0.14 + pulse * 0.06
		var edge := color.lightened(0.28)
		edge.a = 0.62 + pulse * 0.18
		for cell in group_cells:
			if not _positions.has(cell):
				continue
			draw_circle(_tile_center(_get_cell_tile(cell)), _tile_size * 0.58, fill)
		for cell in group_cells:
			if not _positions.has(cell):
				continue
			var rect := _tile_rect(_get_cell_tile(cell)).grow(-2.0)
			draw_rect(rect, Color(color.r, color.g, color.b, 0.08 + pulse * 0.04), true)
			draw_rect(rect, edge, false, maxf(3.0, _tile_size * 0.045))


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
	var flows_value: Variant = _snapshot.get("flows", [])
	if not flows_value is Array:
		return
	var current_tick := float(_snapshot.get("tick", 0))
	var flows: Array = flows_value as Array
	for flow_value in flows:
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
		if alpha <= 0.0:
			continue
		var start := _resource_visual_point(source, resource)
		var finish := _resource_visual_point(target, resource)
		var color := _resource_color(resource)
		color.a = 0.24 + alpha * 0.44
		draw_line(start, finish, Color(color.r, color.g, color.b, color.a * 0.42), maxf(5.0, _tile_size * 0.070), true)
		draw_line(start, finish, color.lightened(0.22), maxf(2.4, _tile_size * 0.028), true)
		var particle := start.lerp(finish, clampf(age / 2.4, 0.0, 1.0))
		draw_circle(particle, maxf(3.0, _tile_size * 0.045), _resource_color(resource))
		draw_circle(particle, maxf(3.0, _tile_size * 0.045), Color(1.0, 1.0, 1.0, 0.34 * alpha), false, 1.6)


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
	draw_arc(a_center, _tile_size * 0.49, 0.0, TAU, _arc_segments(_tile_size * 0.49), color, 5.0, true)
	draw_arc(b_center, _tile_size * 0.49, 0.0, TAU, _arc_segments(_tile_size * 0.49), color, 5.0, true)


func _draw_inventory_cells() -> void:
	for cell in _inventory_cells:
		if not _inventory_centers.has(cell):
			continue
		var center: Vector2 = _inventory_centers[cell] as Vector2
		var fresh := _inventory_fresh_strength(cell)
		var burst := sin((1.0 - fresh) * PI)
		var slot_size := _tile_size * INVENTORY_SLOT_SCALE
		_draw_inventory_slot_backing(center, slot_size)
		if cell != _inventory_drag_cell:
			if fresh > 0.0:
				var halo_radius := _tile_size * (0.50 + burst * 0.08)
				draw_circle(center, halo_radius, Color(1.0, 0.90, 0.28, 0.18 * fresh + 0.12 * burst))
				draw_arc(center, halo_radius * 1.04, 0.0, TAU, 48, Color(1.0, 0.90, 0.30, 0.46 * fresh), maxf(3.0, _tile_size * 0.052), true)
			_draw_cell(cell, center, false, false, INVENTORY_CELL_SCALE + fresh * 0.10 + burst * 0.07)
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


func _draw_cell(cell: String, center: Vector2, dragging: bool, clip_to_viewport: bool, visual_scale: float = 1.0) -> void:
	var radius := _tile_size * (0.43 if dragging else 0.39) * visual_scale
	if clip_to_viewport and not _board_viewport_rect.grow(radius * 1.95).has_point(center):
		return
	var kind := _cell_kind(cell)
	var is_myco := _is_myco_kind(kind)
	var produced := _cell_produced_resource(cell)
	var color := Color(0.94, 0.97, 0.94, 1.0) if is_myco else _resource_color(produced)
	var clearing := _clearing_cells.has(cell)
	var clear_alpha := _clearing_alpha() if clearing else 1.0
	if clear_alpha <= 0.02:
		return
	var live_complete := _circuit_alive_now()
	var glow_alpha := 0.56 if _cell_is_glowing(cell) else 0.16
	if live_complete:
		glow_alpha = 0.72
	var reaction_alpha := _recent_reaction_alpha(cell)
	if reaction_alpha > 0.0:
		glow_alpha = maxf(glow_alpha, 0.52 + reaction_alpha * 0.28)
		draw_circle(center, radius * (1.22 + reaction_alpha * 0.10), Color(1.0, 0.95, 0.58, reaction_alpha * 0.18 * clear_alpha))
	draw_circle(center, radius * (1.16 + (0.04 if live_complete else 0.0)), Color(color.r, color.g, color.b, glow_alpha * 0.28 * clear_alpha))
	draw_circle(center, radius, Color(color.r, color.g, color.b, 0.72 * clear_alpha))
	draw_arc(center, radius * 0.96, 0.0, TAU, _arc_segments(radius), Color(0.92, 1.0, 0.95, 0.68 * clear_alpha), 3.0, true)
	if kind == CELL_KIND_RED_MYCO:
		_draw_red_myco_ring(center, radius, clear_alpha)
	if live_complete:
		var solved_pulse := 0.5 + sin(Time.get_ticks_msec() / 160.0) * 0.5
		draw_arc(center, radius * (1.07 + solved_pulse * 0.03), 0.0, TAU, _arc_segments(radius), Color(0.62, 1.0, 0.88, (0.28 + solved_pulse * 0.18) * clear_alpha), 3.0, true)
	if _using_sim_state and not is_myco and not produced.is_empty():
		_draw_fullness_arc(center, radius * 1.07, _displayed_fullness(cell, produced, _slot_fullness(cell, produced)), color, 6.0)
	var font := get_theme_default_font()
	var needed: Array[String] = _cell_needs(cell)
	var pip_count := MYCO_VISUAL_PIP_COUNT if is_myco else needed.size()
	var used_angles: Array[float] = []
	for index in range(pip_count):
		var pip_radius := _need_pip_radius(radius)
		if index >= needed.size():
			var blank_angle := -PI * 0.5 + TAU * float(index) / maxf(float(pip_count), 1.0)
			var blank_center := center + Vector2(cos(blank_angle), sin(blank_angle)) * radius * 1.18
			draw_circle(blank_center, pip_radius, Color(0.92, 0.97, 0.96, clear_alpha))
			draw_arc(blank_center, pip_radius, 0.0, TAU, _arc_segments(pip_radius), Color(0.01, 0.025, 0.03, 0.68 * clear_alpha), 2.2, true)
			draw_arc(blank_center, pip_radius * 0.84, 0.0, TAU, _arc_segments(pip_radius), Color(1.0, 1.0, 1.0, 0.52 * clear_alpha), 1.4, true)
			continue
		var need := needed[index]
		var visual := _need_visual_data(cell, need, index, pip_count, center, radius, pip_radius, used_angles)
		var angle := float(visual.get("angle", 0.0))
		used_angles.append(float(visual.get("targetAngle", angle)))
		var pip_offset := float(visual.get("offset", radius * 1.18))
		var pip_center := center + Vector2(cos(angle), sin(angle)) * pip_offset
		var state := str(visual.get("state", NEED_STATE_MISSING))
		var fullness := float(visual.get("fullness", 0.0))
		var active_alpha := float(visual.get("activeAlpha", 0.0))
		var pip_color := _resource_color(need)
		if state == NEED_STATE_MISSING:
			pip_color = pip_color.darkened(0.48)
			_draw_need_tether(center, pip_center, radius, pip_radius, Color(0.75, 0.88, 0.90, 0.28 * clear_alpha))
		elif state == NEED_STATE_AVAILABLE:
			pip_color = pip_color.darkened(0.12)
			_draw_need_tether(center, pip_center, radius, pip_radius, Color(pip_color.r, pip_color.g, pip_color.b, 0.42 * clear_alpha))
		elif state == NEED_STATE_ACTIVE:
			draw_circle(pip_center, pip_radius * (1.14 + active_alpha * 0.16), Color(pip_color.r, pip_color.g, pip_color.b, (0.20 + active_alpha * 0.26) * clear_alpha))
		pip_color.a = clear_alpha
		draw_circle(pip_center, pip_radius, pip_color)
		draw_arc(pip_center, pip_radius, 0.0, TAU, _arc_segments(pip_radius), Color(0.01, 0.025, 0.03, 0.82 * clear_alpha), 2.2, true)
		draw_arc(pip_center, pip_radius * 0.86, 0.0, TAU, _arc_segments(pip_radius), Color(1.0, 1.0, 1.0, (0.44 if state != NEED_STATE_MISSING or fullness > 0.0 else 0.28) * clear_alpha), 1.4, true)
		var pip_bar_radius := pip_radius * 1.12
		var pip_bar_width := maxf(2.0, pip_radius * 0.20)
		_draw_fullness_arc(pip_center, pip_bar_radius, _displayed_fullness(cell, need, fullness), pip_color, pip_bar_width)
		if _using_sim_state and fullness <= 0.0:
			_draw_zero_pip_pulse_arc(pip_center, pip_bar_radius, pip_bar_width)
		_draw_centered_text(font, pip_center, pip_radius, need, int(pip_radius * 1.02), Color(1.0, 1.0, 1.0, clear_alpha))
	if not is_myco:
		_draw_centered_text(font, center, radius, produced, int(radius * 1.48), Color(1.0, 1.0, 1.0, clear_alpha))


func _need_visual_data(cell: String, need: String, index: int, count: int, center: Vector2, cell_radius: float, pip_radius: float, used_angles: Array[float]) -> Dictionary:
	var state := _need_state_data(cell, need)
	var partner := str(state.get("partner", ""))
	var base_angle := -PI * 0.5 + TAU * float(index) / maxf(float(count), 1.0)
	if not partner.is_empty():
		var delta := _visual_cell_center(partner) - center
		if delta.length_squared() > 1.0:
			base_angle = delta.angle()
	var target_angle := _separate_need_angle(base_angle, used_angles)
	var target_offset := _need_pip_offset_for_state(center, partner, cell_radius, pip_radius, str(state.get("state", NEED_STATE_MISSING)))
	var key := str(cell, ":", need)
	var angle := _smooth_pip_angle(key, target_angle)
	var offset := _smooth_pip_offset(key, target_offset)
	state["angle"] = angle
	state["offset"] = offset
	state["targetAngle"] = target_angle
	return state


func _need_state_data(cell: String, need: String) -> Dictionary:
	var fullness := _slot_fullness(cell, need) if _using_sim_state else 0.0
	var preferred_partner := _preferred_need_partner(cell, need)
	var active_partner := _recent_flow_source_for_need(cell, need)
	var active_alpha := _recent_flow_alpha_for_need(cell, need)
	if active_partner.is_empty():
		active_partner = _recent_swap_partner_for_need(cell, need)
	if not active_partner.is_empty():
		return {"state": NEED_STATE_ACTIVE, "partner": active_partner, "fullness": maxf(fullness, 0.18), "activeAlpha": maxf(active_alpha, 0.45)}
	var possible_partner := _possible_swap_partner_for_need(cell, need)
	if possible_partner.is_empty():
		possible_partner = _adjacent_exchange_partner_for_need(cell, need)
	if possible_partner.is_empty():
		possible_partner = preferred_partner
	if not possible_partner.is_empty():
		return {"state": NEED_STATE_AVAILABLE, "partner": possible_partner, "fullness": maxf(fullness, 0.18 if not _using_sim_state else 0.0), "activeAlpha": 0.0}
	if fullness > 0.0:
		return {"state": NEED_STATE_SATISFIED, "partner": "", "fullness": fullness, "activeAlpha": 0.0}
	return {"state": NEED_STATE_MISSING, "partner": "", "fullness": 0.0, "activeAlpha": 0.0}


func _draw_red_myco_ring(center: Vector2, radius: float, alpha: float) -> void:
	var ring_radius := radius * 0.54
	draw_arc(center, ring_radius, 0.0, TAU, _arc_segments(ring_radius), Color(0.86, 0.02, 0.04, 0.16 * alpha), maxf(2.0, radius * 0.18), true)
	draw_arc(center, ring_radius, 0.0, TAU, _arc_segments(ring_radius), Color(0.92, 0.04, 0.06, 0.44 * alpha), maxf(1.6, radius * 0.12), true)
	draw_arc(center, ring_radius, 0.0, TAU, _arc_segments(ring_radius), Color(0.70, 0.00, 0.02, 0.88 * alpha), maxf(1.2, radius * 0.055), true)


func _draw_need_tether(center: Vector2, pip_center: Vector2, cell_radius: float, pip_radius: float, color: Color) -> void:
	var delta := pip_center - center
	if delta.length_squared() <= 1.0:
		return
	var direction := delta.normalized()
	draw_line(center + direction * (cell_radius * 0.78), pip_center - direction * (pip_radius * 0.72), color, 2.0, true)


func _draw_fullness_arc(center: Vector2, radius: float, fullness: float, color: Color, width: float) -> void:
	var amount := clampf(fullness, 0.0, 1.0)
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, _arc_segments(radius), Color(0.0, 0.0, 0.0, 0.34), width, true)
	if amount <= 0.0:
		return
	var active := color.lightened(0.26)
	active.a = 0.92
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * amount, _arc_segments(radius), active, width, true)


func _draw_zero_pip_pulse_arc(center: Vector2, radius: float, width: float) -> void:
	var alpha := _zero_pip_pulse_alpha()
	if alpha <= 0.0:
		return
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, _arc_segments(radius), Color(1.0, 0.04, 0.02, 0.58 * alpha), width + 1.2, true)
	draw_arc(center, radius * 1.08, -PI * 0.5, PI * 1.5, _arc_segments(radius), Color(1.0, 0.04, 0.02, 0.22 * alpha), maxf(1.4, width * 0.55), true)


func _draw_centered_text(font: Font, center: Vector2, radius: float, text: String, font_size: int, color: Color) -> void:
	if text.is_empty():
		return
	var width := radius * 2.0
	var origin := Vector2(center.x - radius, center.y + float(font_size) * 0.35)
	var outline := Color(0.01, 0.025, 0.03, 0.86 * color.a)
	draw_string(font, origin + Vector2(-1.5, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	draw_string(font, origin + Vector2(1.5, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	draw_string(font, origin + Vector2(0.0, -1.5), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	draw_string(font, origin + Vector2(0.0, 1.5), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
	draw_string(font, origin + Vector2(0.7, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _resource_visual_point(cell: String, resource: String) -> Vector2:
	var center := _visual_cell_center(cell)
	var needed := _cell_needs(cell)
	if not needed.has(resource):
		return center
	var radius := _tile_size * (0.43 if cell == _drag_cell or cell == _inventory_drag_cell else 0.39) * _cell_visual_scale(cell)
	var pip_radius := _need_pip_radius(radius)
	var used_angles: Array[float] = []
	for index in range(needed.size()):
		var need := needed[index]
		var visual := _need_visual_data(cell, need, index, needed.size(), center, radius, pip_radius, used_angles)
		used_angles.append(float(visual.get("targetAngle", 0.0)))
		if need == resource:
			var angle := float(visual.get("angle", 0.0))
			var offset := float(visual.get("offset", radius * 1.18))
			return center + Vector2(cos(angle), sin(angle)) * offset
	return center


func _recent_flow_source_for_need(cell: String, need: String) -> String:
	if not _using_sim_state:
		return ""
	var flows_value: Variant = _snapshot.get("flows", [])
	if not flows_value is Array:
		return ""
	var current_tick := float(_snapshot.get("tick", 0))
	var best_partner := ""
	var best_age := 999999.0
	var flows: Array = flows_value as Array
	for flow_value in flows:
		if not flow_value is Dictionary:
			continue
		var flow: Dictionary = flow_value as Dictionary
		if str(flow.get("resource", "")) != need:
			continue
		if str(flow.get("targetCellId", "")) != cell:
			continue
		var age := maxf(0.0, current_tick - float(flow.get("tick", current_tick)))
		if age < best_age:
			best_age = age
			best_partner = str(flow.get("sourceCellId", ""))
	return best_partner


func _recent_flow_alpha_for_need(cell: String, need: String) -> float:
	var flows_value: Variant = _snapshot.get("flows", [])
	if not flows_value is Array:
		return 0.0
	var current_tick := float(_snapshot.get("tick", 0))
	var flows: Array = flows_value as Array
	for flow_value in flows:
		if not flow_value is Dictionary:
			continue
		var flow: Dictionary = flow_value as Dictionary
		if str(flow.get("targetCellId", "")) == cell and str(flow.get("resource", "")) == need:
			var age := maxf(0.0, current_tick - float(flow.get("tick", current_tick)))
			return clampf(1.0 - age / SWAP_VISUAL_TTL_TICKS, 0.0, 1.0)
	return 0.0


func _recent_swap_partner_for_need(cell: String, need: String) -> String:
	var swaps_value: Variant = _snapshot.get("swaps", [])
	if not swaps_value is Array:
		return ""
	var swaps: Array = swaps_value as Array
	for swap_value in swaps:
		if not swap_value is Dictionary:
			continue
		var swap: Dictionary = swap_value as Dictionary
		var initiator := str(swap.get("initiator", ""))
		var counterparty := str(swap.get("counterparty", ""))
		if initiator == cell and str(swap.get("counterpartyPaidResource", "")) == need:
			return counterparty
		if counterparty == cell and str(swap.get("initiatorPaidResource", "")) == need:
			return initiator
	return ""


func _possible_swap_partner_for_need(cell: String, need: String) -> String:
	var possible_value: Variant = _snapshot.get("possibleSwaps", [])
	if not possible_value is Array:
		return ""
	var possible_swaps: Array = possible_value as Array
	for swap_value in possible_swaps:
		if not swap_value is Dictionary:
			continue
		var swap: Dictionary = swap_value as Dictionary
		var initiator := str(swap.get("initiator", ""))
		var counterparty := str(swap.get("counterparty", ""))
		if initiator == cell and str(swap.get("counterpartyPaidResource", "")) == need:
			return counterparty
		if counterparty == cell and str(swap.get("initiatorPaidResource", "")) == need:
			return initiator
	return ""


func _adjacent_exchange_partner_for_need(cell: String, need: String) -> String:
	if not _positions.has(cell):
		return ""
	var tile := _get_cell_tile(cell)
	for other in _cells:
		if other == cell:
			continue
		if not _positions.has(other):
			continue
		if tile.distance_squared_to(_get_cell_tile(other)) != 1:
			continue
		if _cell_produced_resource(other) == need:
			return other
	return ""


func _cell_is_glowing(cell: String) -> bool:
	var state_value: Variant = _cell_state_by_id.get(cell, {})
	if state_value is Dictionary:
		return bool((state_value as Dictionary).get("glowing", false))
	return false


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
		return _inventory_centers[cell] as Vector2
	if _positions.has(cell):
		return _tile_center(_get_cell_tile(cell))
	return Vector2.ZERO


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


func _cell_produced_resource(cell: String) -> String:
	if _is_myco_kind(_cell_kind(cell)):
		return ""
	return str(_produced_by_cell.get(cell, cell))


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


func _smooth_pip_angle(key: String, target_angle: float) -> float:
	if not _pip_angles.has(key):
		_pip_angles[key] = target_angle
		return target_angle
	var current := float(_pip_angles.get(key, target_angle))
	var smoothed := current + wrapf(target_angle - current, -PI, PI) * PIP_ANGLE_SMOOTH
	_pip_angles[key] = smoothed
	return smoothed


func _smooth_pip_offset(key: String, target_offset: float) -> float:
	if not _pip_offsets.has(key):
		_pip_offsets[key] = target_offset
		return target_offset
	var current := float(_pip_offsets.get(key, target_offset))
	var smoothed := lerpf(current, target_offset, PIP_OFFSET_SMOOTH)
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


func _strings_from_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for item in values:
		result.append(str(item))
	return result
