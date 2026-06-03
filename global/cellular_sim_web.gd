extends Node

const ROLE_NEED := "Need"
const ROLE_ACCEPT_ONLY := "AcceptOnly"
const ROLE_SOURCE_OUTPUT := "SourceOutput"
const KIND_STANDARD := "Standard"
const KIND_WHITE_MYCO := "WhiteMyco"
const KIND_RED_MYCO := "RedMyco"
const MAX_SLOTS := 4
const DEFAULT_SLOT_CAPACITY := 100
const ADAPTIVE_MYCO_STARTING_QUANTITY := 250
const ADAPTIVE_MYCO_SLOT_CAPACITY := 500
const RED_MYCO_OUTWARD_FEE := 1
const RED_MYCO_MINIMUM_GROSS_SWAP := 2
const STANDARD_MINIMUM_GROSS_SWAP := 1
const RECENT_EVENT_WINDOW_TICKS := 12
const POSSIBLE_SWAP_SNAPSHOT_LIMIT := 4096
const LARGE_RECEIVE_LIMIT := 1073741824
const ADAPTIVE_MYCO_EXACT_CANDIDATE_LIMIT := 12

var _loaded := false
var _last_error := ""
var _resources: Array[String] = []
var _resource_ids: Dictionary = {}
var _width := 0
var _height := 0
var _rocks: Array[Vector2i] = []
var _rock_lookup: Dictionary = {}
var _cells: Array[Dictionary] = []
var _cell_index_by_id: Dictionary = {}
var _occupancy: Dictionary = {}
var _topology_version := 0
var _adaptive_topology_version := -1
var _adjacent_edges_topology_version := -1
var _adjacent_edges_cache: Array[Dictionary] = []
var _adjacent_indices_topology_version := -1
var _adjacent_indices_cache: Array = []
var _myco_neighbor_signatures: Dictionary = {}
var _initial_myco_hints: Dictionary = {}
var _events: Array[Dictionary] = []
var _event_capacity := 65536
var _current_tick := 0
var _reaction_score := 0
var _flow_diversity_score := 0
var _settlement_score := 0
var _strain_penalty := 0
var _alive_this_tick := false
var _won := false
var _sustained_ticks := 0
var _required_cell_ids: Array[String] = []
var _required_resources: Array[int] = []
var _options: Dictionary = {}
var _swap_proposals: Array[Dictionary] = []
var _candidate_swap_proposals: Array[Dictionary] = []
var _reacted_indices: Array[int] = []
var _glow_refreshed_indices: Array[int] = []
var _reserved_out: Dictionary = {}
var _reserved_in: Dictionary = {}
var _profile_enabled := false
var _last_adaptive_profile: Dictionary = {}
var _adaptive_deep_select_count := 0


func _ready() -> void:
	_profile_enabled = _has_user_arg("--puzzle-visual-profile")


func get_last_error() -> String:
	return _last_error


func is_loaded() -> bool:
	return _loaded


func load_fixture_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		_last_error = "Fixture file does not exist: %s" % path
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_last_error = "Could not open fixture file: %s" % path
		return false
	var text: String = file.get_as_text()
	return load_fixture_json(text)


func load_fixture_json(json: String) -> bool:
	_reset_all_state()
	var parsed: Variant = JSON.parse_string(json)
	if not parsed is Dictionary:
		_last_error = "Fixture JSON is empty or invalid."
		return false
	var fixture: Dictionary = parsed as Dictionary
	if not _load_resources(fixture):
		return false
	if not _load_grid(fixture):
		return false
	if not _load_cells(fixture):
		return false
	if not _load_options(fixture):
		return false
	_loaded = true
	_refresh_adaptive_myco(true)
	_last_error = ""
	return true


func can_move_cell(cell_id: String, x: int, y: int) -> bool:
	if not _loaded:
		return false
	return _can_move_cell(cell_id, Vector2i(x, y))


func move_cell(cell_id: String, x: int, y: int) -> bool:
	if not _loaded:
		return false
	var position := Vector2i(x, y)
	if not _can_move_cell(cell_id, position):
		return false
	var index := int(_cell_index_by_id[cell_id])
	var cell: Dictionary = _cells[index]
	var old_position := Vector2i(int(cell["x"]), int(cell["y"]))
	if old_position == position:
		return true
	_occupancy.erase(_position_key(old_position))
	cell["x"] = position.x
	cell["y"] = position.y
	_occupancy[_position_key(position)] = index
	_topology_version += 1
	return true


func reset_with_current_layout() -> bool:
	if not _loaded:
		_last_error = "No loaded Cellular fixture to reset."
		return false
	var profile_start_usec := 0
	var profile_state_usec := 0
	var profile_cell_reset_usec := 0
	var profile_adaptive_usec := 0
	var profile_section_usec := 0
	if _profile_enabled:
		profile_start_usec = Time.get_ticks_usec()
	_current_tick = 0
	_events.clear()
	_reaction_score = 0
	_flow_diversity_score = 0
	_settlement_score = 0
	_strain_penalty = 0
	_alive_this_tick = false
	_won = false
	_sustained_ticks = 0
	_initial_myco_hints.clear()
	if _profile_enabled:
		profile_state_usec = Time.get_ticks_usec() - profile_start_usec
		profile_section_usec = Time.get_ticks_usec()
	for index in range(_cells.size()):
		var cell: Dictionary = _cells[index]
		cell["glow"] = 0
		_clear_strain(cell)
		if _is_myco(cell):
			_reset_adaptive_myco_slot_quantities(cell)
			continue
		var slots: Array = cell["slots"] as Array
		for slot_value in slots:
			var slot: Dictionary = slot_value
			slot["quantity"] = 0
	if _profile_enabled:
		profile_cell_reset_usec = Time.get_ticks_usec() - profile_section_usec
		profile_section_usec = Time.get_ticks_usec()
	_refresh_adaptive_myco(false)
	if _profile_enabled:
		profile_adaptive_usec = Time.get_ticks_usec() - profile_section_usec
		print(str(
			"[cellular-web-shim-profile] event=reset",
			" cells=", _cells.size(),
			" edges=", _get_adjacent_edges().size(),
			" total_ms=", _profile_usecs_to_ms(float(Time.get_ticks_usec() - profile_start_usec)),
			" state_ms=", _profile_usecs_to_ms(float(profile_state_usec)),
			" cell_reset_ms=", _profile_usecs_to_ms(float(profile_cell_reset_usec)),
			" adaptive_ms=", _profile_usecs_to_ms(float(profile_adaptive_usec)),
			" adaptive_passes=", int(_last_adaptive_profile.get("passes", 0)),
			" adaptive_selected=", int(_last_adaptive_profile.get("selected", 0)),
			" adaptive_changed=", int(_last_adaptive_profile.get("changed", 0)),
			" adaptive_myco=", int(_last_adaptive_profile.get("myco", 0)),
			" adaptive_deep=", int(_last_adaptive_profile.get("deep", 0))
		))
	_last_error = ""
	return true


func add_myco_cell(kind: String, id: String, x: int, y: int, needs: Array) -> bool:
	if not _loaded:
		_last_error = "No loaded Cellular fixture to add a myco cell to."
		return false
	var normalized_kind := _parse_kind(kind)
	if normalized_kind != KIND_WHITE_MYCO and normalized_kind != KIND_RED_MYCO:
		_last_error = "Unknown myco kind '%s'." % kind
		return false
	if id.strip_edges() == "":
		_last_error = "Myco cell id cannot be blank."
		return false
	if _cell_index_by_id.has(id):
		_last_error = "Cell id '%s' already exists." % id
		return false
	var position := Vector2i(x, y)
	if not _in_bounds(position):
		_last_error = "Myco position (%d, %d) is outside the grid." % [x, y]
		return false
	if _rock_lookup.has(_position_key(position)) or _occupancy.has(_position_key(position)):
		_last_error = "Myco position (%d, %d) is not empty." % [x, y]
		return false
	var cell := {
		"id": id,
		"kind": normalized_kind,
		"x": x,
		"y": y,
		"slots": [],
		"sources": [],
		"strain": _new_strain(),
		"glow": 0
	}
	var index := _cells.size()
	cell["index"] = index
	_cells.append(cell)
	_cell_index_by_id[id] = index
	_occupancy[_position_key(position)] = index
	_add_required_cell(id)
	_topology_version += 1
	_initial_myco_hints.erase(id)
	_refresh_adaptive_myco(false)
	_last_error = ""
	return true


func tick_many(count: int) -> void:
	if not _loaded or count <= 0:
		return
	var capped_count := mini(count, 512)
	for _i in range(capped_count):
		_tick()


func get_snapshot() -> Dictionary:
	if not _loaded:
		return {
			"loaded": false,
			"lastError": _last_error
		}
	_refresh_adaptive_myco(false)
	return {
		"loaded": true,
		"tick": _current_tick,
		"won": _won,
		"alive": _alive_this_tick,
		"sustainedTicks": _sustained_ticks,
		"score": _total_score(),
		"width": _width,
		"height": _height,
		"rocks": _build_rocks_snapshot(),
		"cells": _build_cells_snapshot(),
		"swaps": _build_recent_swaps_snapshot(),
		"flows": _build_recent_flows_snapshot(),
		"reactions": _build_recent_reactions_snapshot(),
		"possibleSwaps": _build_possible_swaps_snapshot(),
		"circuitDiagnostics": _build_circuit_diagnostics_snapshot()
	}


func _reset_all_state() -> void:
	_loaded = false
	_last_error = ""
	_resources.clear()
	_resource_ids.clear()
	_width = 0
	_height = 0
	_rocks.clear()
	_rock_lookup.clear()
	_cells.clear()
	_cell_index_by_id.clear()
	_occupancy.clear()
	_topology_version = 0
	_adaptive_topology_version = -1
	_adjacent_edges_topology_version = -1
	_adjacent_edges_cache.clear()
	_adjacent_indices_topology_version = -1
	_adjacent_indices_cache.clear()
	_myco_neighbor_signatures.clear()
	_initial_myco_hints.clear()
	_events.clear()
	_current_tick = 0
	_reaction_score = 0
	_flow_diversity_score = 0
	_settlement_score = 0
	_strain_penalty = 0
	_alive_this_tick = false
	_won = false
	_sustained_ticks = 0
	_required_cell_ids.clear()
	_required_resources.clear()
	_options = _default_options()
	_swap_proposals.clear()
	_candidate_swap_proposals.clear()
	_reacted_indices.clear()
	_glow_refreshed_indices.clear()
	_reserved_out.clear()
	_reserved_in.clear()
	_last_adaptive_profile.clear()
	_adaptive_deep_select_count = 0


func _default_options() -> Dictionary:
	return {
		"glowTtlTicks": 5,
		"eventCapacity": 65536,
		"edgeThroughputPerDirection": 1,
		"maxSwapQuantityPerEdge": 8,
		"swapRoundsPerTick": 1,
		"needDesiredQuantity": 100,
		"needOfferReserve": 1,
		"allowNeedOverflowPayments": false,
		"winDurationTicks": 30,
		"winRecentFlowWindowTicks": 30
	}


func _new_strain() -> Dictionary:
	return {
		"unmet": 0,
		"failed": 0,
		"sourceBlocked": 0,
		"overCapacity": 0
	}


func _clear_strain(cell: Dictionary) -> void:
	var strain_value: Variant = cell.get("strain", {})
	if not strain_value is Dictionary:
		cell["strain"] = _new_strain()
		return
	var strain: Dictionary = strain_value as Dictionary
	strain["unmet"] = 0
	strain["failed"] = 0
	strain["sourceBlocked"] = 0
	strain["overCapacity"] = 0


func _profile_usecs_to_ms(usec: float) -> String:
	return "%.3f" % (usec / 1000.0)


func _has_user_arg(name: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if str(arg) == name:
			return true
	return false


func _load_resources(fixture: Dictionary) -> bool:
	var resources_value: Variant = fixture.get("resources", [])
	if not resources_value is Array or (resources_value as Array).is_empty():
		_last_error = "Fixture must define resources."
		return false
	var seen: Dictionary = {}
	for resource_value in resources_value as Array:
		var resource := str(resource_value).strip_edges()
		if resource == "":
			_last_error = "Resource names cannot be blank."
			return false
		if seen.has(resource):
			_last_error = "Duplicate resource '%s'." % resource
			return false
		seen[resource] = true
		_resource_ids[resource] = _resources.size()
		_resources.append(resource)
	return true


func _load_grid(fixture: Dictionary) -> bool:
	var grid_value: Variant = fixture.get("grid", {})
	if not grid_value is Dictionary:
		_last_error = "Fixture must define a grid."
		return false
	var grid: Dictionary = grid_value as Dictionary
	_width = _as_int(grid.get("width", 0), 0)
	_height = _as_int(grid.get("height", 0), 0)
	if _width <= 0 or _height <= 0:
		_last_error = "Invalid grid dimensions."
		return false
	var rocks_value: Variant = grid.get("rocks", [])
	if rocks_value is Array:
		for rock_value in rocks_value as Array:
			if not rock_value is Dictionary:
				continue
			var rock_doc: Dictionary = rock_value
			var position := Vector2i(_as_int(rock_doc.get("x", 0), 0), _as_int(rock_doc.get("y", 0), 0))
			if not _in_bounds(position):
				_last_error = "Invalid rock at (%d, %d): position is outside the grid." % [position.x, position.y]
				return false
			var key := _position_key(position)
			if _rock_lookup.has(key):
				continue
			_rocks.append(position)
			_rock_lookup[key] = true
			_topology_version += 1
	return true


func _load_cells(fixture: Dictionary) -> bool:
	var cells_value: Variant = fixture.get("cells", [])
	if not cells_value is Array or (cells_value as Array).is_empty():
		_last_error = "Fixture must define cells."
		return false
	for cell_value in cells_value as Array:
		if not cell_value is Dictionary:
			_last_error = "Fixture cells must be objects."
			return false
		var cell_doc: Dictionary = cell_value
		var id := str(cell_doc.get("id", "")).strip_edges()
		if id == "":
			_last_error = "Cell ids cannot be blank."
			return false
		if _cell_index_by_id.has(id):
			_last_error = "Duplicate cell id '%s'." % id
			return false
		var kind := _parse_kind(str(cell_doc.get("kind", KIND_STANDARD)))
		if kind == "":
			_last_error = "Cell '%s' has invalid kind '%s'." % [id, str(cell_doc.get("kind", ""))]
			return false
		var position := Vector2i(_as_int(cell_doc.get("x", 0), 0), _as_int(cell_doc.get("y", 0), 0))
		if not _in_bounds(position):
			_last_error = "Invalid cell '%s': position is outside the grid." % id
			return false
		var position_key := _position_key(position)
		if _rock_lookup.has(position_key):
			_last_error = "Invalid cell '%s': cannot place a cell on a rock." % id
			return false
		if _occupancy.has(position_key):
			_last_error = "Invalid cell '%s': cannot place two cells on the same tile." % id
			return false
		var slots: Array = []
		var hinted_resources: Array[int] = []
		if not _load_cell_slots(id, kind, cell_doc, slots, hinted_resources):
			return false
		var sources: Array = []
		if not _load_cell_sources(id, kind, cell_doc, slots, sources):
			return false
		var cell := {
			"id": id,
			"kind": kind,
			"x": position.x,
			"y": position.y,
			"slots": slots,
			"sources": sources,
			"strain": _new_strain(),
			"glow": 0
		}
		var index := _cells.size()
		cell["index"] = index
		_cells.append(cell)
		_cell_index_by_id[id] = index
		_occupancy[position_key] = index
		if kind == KIND_WHITE_MYCO or kind == KIND_RED_MYCO:
			if hinted_resources.size() > 0:
				_initial_myco_hints[id] = hinted_resources.duplicate()
		_topology_version += 1
	return true


func _load_cell_slots(id: String, kind: String, cell_doc: Dictionary, slots: Array, hinted_resources: Array[int]) -> bool:
	var slots_value: Variant = cell_doc.get("slots", [])
	if not slots_value is Array or (slots_value as Array).is_empty():
		if kind == KIND_WHITE_MYCO or kind == KIND_RED_MYCO:
			return true
		_last_error = "Cell '%s' must define at least one pool slot." % id
		return false
	var slot_resources: Dictionary = {}
	for slot_value in slots_value as Array:
		if not slot_value is Dictionary:
			_last_error = "Cell '%s' slots must be objects." % id
			return false
		if slots.size() >= MAX_SLOTS:
			_last_error = "Cell '%s' has more than %d pool slots." % [id, MAX_SLOTS]
			return false
		var slot_doc: Dictionary = slot_value
		var resource_name := str(slot_doc.get("resource", "")).strip_edges()
		if not _resource_ids.has(resource_name):
			_last_error = "Unknown resource '%s'." % resource_name
			return false
		var resource := int(_resource_ids[resource_name])
		if slot_resources.has(resource):
			_last_error = "Cell '%s' has duplicate pool slot '%s'." % [id, resource_name]
			return false
		slot_resources[resource] = true
		var role := _parse_role(str(slot_doc.get("role", ROLE_ACCEPT_ONLY)))
		if role == "":
			_last_error = "Cell '%s' has invalid slot role '%s'." % [id, str(slot_doc.get("role", ""))]
			return false
		if (kind == KIND_WHITE_MYCO or kind == KIND_RED_MYCO) and role == ROLE_SOURCE_OUTPUT:
			_last_error = "Myco cell '%s' cannot define SourceOutput slots." % id
			return false
		var capacity := _as_int(slot_doc.get("capacity", DEFAULT_SLOT_CAPACITY), DEFAULT_SLOT_CAPACITY)
		if capacity <= 0:
			capacity = DEFAULT_SLOT_CAPACITY
		var quantity := _as_int(slot_doc.get("quantity", 0), 0)
		quantity = clampi(quantity, 0, capacity)
		slots.append({
			"resource": resource,
			"role": role,
			"quantity": quantity,
			"capacity": capacity
		})
		if kind == KIND_WHITE_MYCO or kind == KIND_RED_MYCO:
			_add_unique_int(hinted_resources, resource)
	return true


func _load_cell_sources(id: String, kind: String, cell_doc: Dictionary, slots: Array, sources: Array) -> bool:
	var sources_value: Variant = cell_doc.get("sources", [])
	if not sources_value is Array:
		return true
	if (kind == KIND_WHITE_MYCO or kind == KIND_RED_MYCO) and not (sources_value as Array).is_empty():
		_last_error = "Myco cell '%s' cannot define sources." % id
		return false
	for source_value in sources_value as Array:
		if not source_value is Dictionary:
			_last_error = "Cell '%s' sources must be objects." % id
			return false
		var source_doc: Dictionary = source_value
		var resource_name := str(source_doc.get("resource", "")).strip_edges()
		if not _resource_ids.has(resource_name):
			_last_error = "Unknown resource '%s'." % resource_name
			return false
		var resource := int(_resource_ids[resource_name])
		if _find_slot_in_array(slots, resource).is_empty():
			_last_error = "Cell '%s' source resource '%s' does not have a pool slot." % [id, resource_name]
			return false
		var quantity := _as_int(source_doc.get("quantityPerTick", 1), 1)
		var interval := _as_int(source_doc.get("intervalTicks", 1), 1)
		if quantity <= 0:
			_last_error = "Cell '%s' source quantity must be positive." % id
			return false
		if interval <= 0:
			_last_error = "Cell '%s' source interval must be positive." % id
			return false
		sources.append({
			"resource": resource,
			"quantityPerTick": quantity,
			"intervalTicks": interval
		})
	return true


func _load_options(fixture: Dictionary) -> bool:
	_options = _default_options()
	var engine_value: Variant = fixture.get("engine", {})
	if engine_value is Dictionary:
		var engine: Dictionary = engine_value as Dictionary
		_set_positive_option(engine, "glowTtlTicks")
		_set_positive_option(engine, "winRecentFlowWindowTicks")
		_set_positive_option(engine, "swapRoundsPerTick")
		_set_positive_option(engine, "maxSwapQuantityPerEdge")
		_set_positive_option(engine, "needDesiredQuantity")
		_set_positive_option(engine, "needOfferReserve")
		_options["allowNeedOverflowPayments"] = bool(engine.get("allowNeedOverflowPayments", false))
	_event_capacity = maxi(int(_options["eventCapacity"]), 65536)
	var win_value: Variant = fixture.get("win", {})
	if not win_value is Dictionary:
		return true
	var win: Dictionary = win_value as Dictionary
	var duration := _as_int(win.get("durationTicks", 0), 0)
	if duration > 0:
		_options["winDurationTicks"] = duration
	var required_cells_value: Variant = win.get("requiredCells", [])
	if required_cells_value is Array:
		for cell_id_value in required_cells_value as Array:
			var cell_id := str(cell_id_value)
			if not _cell_index_by_id.has(cell_id):
				_last_error = "Required cell '%s' does not exist." % cell_id
				return false
			_add_required_cell(cell_id)
	var required_resources_value: Variant = win.get("requiredResources", [])
	if required_resources_value is Array:
		for resource_value in required_resources_value as Array:
			var resource_name := str(resource_value)
			if not _resource_ids.has(resource_name):
				_last_error = "Unknown resource '%s'." % resource_name
				return false
			_add_unique_int(_required_resources, int(_resource_ids[resource_name]))
	return true


func _set_positive_option(engine: Dictionary, key: String) -> void:
	var value := _as_int(engine.get(key, 0), 0)
	if value > 0:
		_options[key] = value


func _tick() -> void:
	_refresh_adaptive_myco(false)
	_current_tick += 1
	_glow_refreshed_indices.clear()
	_run_source_production()
	_resolve_swap_rounds()
	_resolve_reactions()
	_update_glow_and_strain()
	_update_score()
	_update_win_check()


func _refresh_adaptive_myco(force: bool) -> void:
	if not force and _adaptive_topology_version == _topology_version:
		return
	var myco_count := 0
	var myco_indices: Array[int] = []
	for cell in _cells:
		if _is_myco(cell):
			myco_count += 1
			myco_indices.append(int(cell["index"]))
	if myco_count == 0:
		_adaptive_topology_version = _topology_version
		_last_adaptive_profile = {"myco": 0, "passes": 0, "selected": 0, "changed": 0, "deep": 0}
		return
	var full_refresh := force or _adaptive_topology_version < 0 or _myco_neighbor_signatures.is_empty()
	var queue: Array[int] = []
	var queued: Dictionary = {}
	if full_refresh:
		_myco_neighbor_signatures.clear()
		for myco_index in myco_indices:
			var myco: Dictionary = _cells[myco_index]
			_cell_slots(myco).clear()
			queue.append(myco_index)
			queued[myco_index] = 1
	else:
		for myco_index in myco_indices:
			var cell: Dictionary = _cells[myco_index]
			var signature := _myco_neighbor_signature(myco_index)
			var cell_id := str(cell["id"])
			if str(_myco_neighbor_signatures.get(cell_id, "")) != signature:
				_cell_slots(cell).clear()
				queue.append(myco_index)
				queued[myco_index] = 1
	if queue.is_empty():
		_adaptive_topology_version = _topology_version
		_last_adaptive_profile = {"myco": myco_count, "passes": 0, "selected": 0, "changed": 0, "deep": 0}
		return
	var use_hints := full_refresh and _current_tick == 0
	var profile_passes := 0
	var profile_selected := 0
	var profile_changed := 0
	_adaptive_deep_select_count = 0
	var cursor := 0
	while cursor < queue.size():
		var changed := false
		var selected_this_pass := 0
		var pass_end := queue.size()
		while cursor < pass_end:
			var myco_index := int(queue[cursor])
			cursor += 1
			var cell: Dictionary = _cells[myco_index]
			var resources: Array[int] = _select_adaptive_myco_resources(cell, use_hints)
			selected_this_pass += 1
			profile_selected += 1
			var resources_changed := _replace_adaptive_myco_slots(cell, resources)
			_myco_neighbor_signatures[str(cell["id"])] = _myco_neighbor_signature(myco_index)
			if resources_changed:
				changed = true
				profile_changed += 1
				_enqueue_waiting_myco_neighbors(myco_index, queue, queued)
		profile_passes += 1
		if selected_this_pass == 0:
			break
		if not changed and cursor >= queue.size():
			break
	_adaptive_topology_version = _topology_version
	_last_adaptive_profile = {
		"myco": myco_count,
		"passes": profile_passes,
		"selected": profile_selected,
		"changed": profile_changed,
		"deep": _adaptive_deep_select_count
	}


func _select_adaptive_myco_resources(myco: Dictionary, use_hints: bool) -> Array[int]:
	var useful_neighbors: Array[Dictionary] = []
	var myco_index := int(myco["index"])
	var adjacent_indices: Array = _get_adjacent_indices_by_cell()
	if myco_index < 0 or myco_index >= adjacent_indices.size():
		return []
	var neighbor_indices: Array = adjacent_indices[myco_index] as Array
	for neighbor_index_value in neighbor_indices:
		var neighbor_index := int(neighbor_index_value)
		var neighbor: Dictionary = _cells[neighbor_index]
		var neighbor_slots: Array = neighbor["slots"] as Array
		if not _is_myco(neighbor) or neighbor_slots.size() > 0:
			useful_neighbors.append(neighbor)
	var resources: Array[int] = []
	if useful_neighbors.is_empty():
		return resources
	if useful_neighbors.size() == 1:
		var only_neighbor: Dictionary = useful_neighbors[0]
		if _is_myco(only_neighbor):
			_add_slot_resources(resources, only_neighbor["slots"] as Array)
		else:
			_add_normal_offers(resources, only_neighbor)
			_add_role_resources(resources, only_neighbor["slots"] as Array, ROLE_NEED)
		return resources
	var hint_value: Variant = _initial_myco_hints.get(str(myco["id"]), [])
	var hinted: Array[int] = []
	if use_hints and hint_value is Array:
		for resource_value in hint_value as Array:
			_add_unique_int(hinted, int(resource_value))
		if not hinted.is_empty():
			var local_offer_scores: Dictionary = {}
			var local_offers: Array[int] = []
			_score_multiple_myco_neighbors(myco, useful_neighbors, local_offer_scores, local_offers)
			_ensure_local_payment_resource(myco, hinted, local_offers, local_offer_scores)
			return hinted
	return _select_adaptive_myco_from_multiple_neighbors(myco, useful_neighbors)


func _select_adaptive_myco_from_multiple_neighbors(myco: Dictionary, useful_neighbors: Array[Dictionary]) -> Array[int]:
	_adaptive_deep_select_count += 1
	var scores: Dictionary = {}
	var local_offers: Array[int] = []
	_add_connected_component_candidate_scores(myco, scores)
	_score_multiple_myco_neighbors(myco, useful_neighbors, scores, local_offers)
	var candidates: Array[Dictionary] = []
	for resource_value in scores.keys():
		var resource := int(resource_value)
		var score := int(scores[resource])
		candidates.append({
			"resource": resource,
			"score": score,
			"hash": _stable_adaptive_myco_hash(str(myco["id"]), "candidate", resource, score, 0, _topology_version)
		})
	candidates.sort_custom(Callable(self, "_compare_myco_resource_candidates"))
	return _select_best_adaptive_myco_resource_set(myco, useful_neighbors, candidates, local_offers, scores)


func _score_multiple_myco_neighbors(myco: Dictionary, useful_neighbors: Array[Dictionary], scores: Dictionary, local_offers: Array[int]) -> void:
	for neighbor_index in range(useful_neighbors.size()):
		var neighbor: Dictionary = useful_neighbors[neighbor_index]
		var slots: Array = neighbor["slots"] as Array
		for slot_value in slots:
			var slot: Dictionary = slot_value
			var resource := int(slot["resource"])
			var role := str(slot["role"])
			if _is_myco(neighbor):
				_add_candidate_score(scores, resource, 170)
			elif role == ROLE_SOURCE_OUTPUT:
				_add_candidate_score(scores, resource, 170)
				_add_unique_int(local_offers, resource)
			elif role == ROLE_NEED:
				_add_candidate_score(scores, resource, 210)
		var sources: Array = neighbor["sources"] as Array
		for source_value in sources:
			var source: Dictionary = source_value
			var source_resource := int(source["resource"])
			_add_candidate_score(scores, source_resource, 170)
			_add_unique_int(local_offers, source_resource)


func _select_best_adaptive_myco_resource_set(myco: Dictionary, useful_neighbors: Array[Dictionary], candidates: Array[Dictionary], local_offers: Array[int], scores: Dictionary) -> Array[int]:
	var best_resources: Array[int] = []
	var best_score := -2147483648
	var best_hash := 2147483647
	var candidate_limit := mini(ADAPTIVE_MYCO_EXACT_CANDIDATE_LIMIT, candidates.size())
	if candidate_limit <= MAX_SLOTS:
		var resources: Array[int] = []
		for index in range(candidate_limit):
			var candidate: Dictionary = candidates[index]
			_add_unique_int(resources, int(candidate["resource"]))
		var considered := _consider_myco_resource_set(myco, resources, useful_neighbors, local_offers, scores)
		best_resources = _int_array_from_variant(considered["resources"])
		best_score = int(considered["score"])
		best_hash = int(considered["hash"])
	else:
		for a in range(candidate_limit - 3):
			for b in range(a + 1, candidate_limit - 2):
				for c in range(b + 1, candidate_limit - 1):
					for d in range(c + 1, candidate_limit):
						var set_resources: Array[int] = [
							int((candidates[a] as Dictionary)["resource"]),
							int((candidates[b] as Dictionary)["resource"]),
							int((candidates[c] as Dictionary)["resource"]),
							int((candidates[d] as Dictionary)["resource"])
						]
						var considered_set := _consider_myco_resource_set(myco, set_resources, useful_neighbors, local_offers, scores)
						var score := int(considered_set["score"])
						var hash := int(considered_set["hash"])
						if score > best_score or (score == best_score and hash < best_hash):
							best_resources = _int_array_from_variant(considered_set["resources"])
							best_score = score
							best_hash = hash
	if best_resources.is_empty() and candidate_limit > 0:
		for index in range(mini(MAX_SLOTS, candidate_limit)):
			_add_unique_int(best_resources, int((candidates[index] as Dictionary)["resource"]))
		_ensure_local_payment_resource(myco, best_resources, local_offers, scores)
	return best_resources


func _consider_myco_resource_set(myco: Dictionary, resources: Array[int], useful_neighbors: Array[Dictionary], local_offers: Array[int], scores: Dictionary) -> Dictionary:
	var normalized: Array[int] = []
	for resource in resources:
		_add_unique_int(normalized, int(resource))
	_ensure_local_payment_resource(myco, normalized, local_offers, scores)
	var score := _score_adaptive_myco_resource_set(normalized, useful_neighbors, scores)
	var hash := _hash_adaptive_myco_resource_set(str(myco["id"]), normalized, score, _topology_version)
	return {
		"resources": normalized,
		"score": score,
		"hash": hash
	}


func _score_adaptive_myco_resource_set(resources: Array[int], useful_neighbors: Array[Dictionary], base_scores: Dictionary) -> int:
	var score := 0
	for resource in resources:
		score += int(base_scores.get(int(resource), 0))
	var reciprocal_neighbors := 0
	for neighbor in useful_neighbors:
		var receives_from_neighbor := false
		var pays_neighbor := false
		var local_offer_matches := 0
		var local_need_matches := 0
		for resource in resources:
			var resource_id := int(resource)
			if _cell_can_offer_resource_statically(neighbor, resource_id):
				receives_from_neighbor = true
				local_offer_matches += 1
			if _cell_can_receive_resource_statically(neighbor, resource_id):
				pays_neighbor = true
			if _cell_has_need_resource(neighbor, resource_id):
				local_need_matches += 1
		score += local_offer_matches * 260
		score += local_need_matches * 320
		if receives_from_neighbor and pays_neighbor:
			score += 1400
			reciprocal_neighbors += 1
		elif receives_from_neighbor or pays_neighbor:
			score += 250
	return score + reciprocal_neighbors * reciprocal_neighbors * 180


func _cell_slots(cell: Dictionary) -> Array:
	return cell["slots"] as Array


func _reset_adaptive_myco_slot_quantities(myco: Dictionary) -> void:
	var slots: Array = _cell_slots(myco)
	for slot_value in slots:
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		slot["role"] = ROLE_NEED
		slot["quantity"] = ADAPTIVE_MYCO_STARTING_QUANTITY
		slot["capacity"] = ADAPTIVE_MYCO_SLOT_CAPACITY


func _myco_neighbor_signature(myco_index: int) -> String:
	var adjacent_indices: Array = _get_adjacent_indices_by_cell()
	if myco_index < 0 or myco_index >= adjacent_indices.size():
		return ""
	var names: Array[String] = []
	var neighbors: Array = adjacent_indices[myco_index] as Array
	for neighbor_index_value in neighbors:
		var neighbor_index := int(neighbor_index_value)
		if neighbor_index >= 0 and neighbor_index < _cells.size():
			var neighbor: Dictionary = _cells[neighbor_index]
			names.append(str(neighbor["id"]))
	names.sort()
	var signature := ""
	for name in names:
		if signature.is_empty():
			signature = name
		else:
			signature = str(signature, "|", name)
	return signature


func _enqueue_waiting_myco_neighbors(myco_index: int, queue: Array[int], queued: Dictionary) -> void:
	var adjacent_indices: Array = _get_adjacent_indices_by_cell()
	if myco_index < 0 or myco_index >= adjacent_indices.size():
		return
	var neighbors: Array = adjacent_indices[myco_index] as Array
	for neighbor_index_value in neighbors:
		var neighbor_index := int(neighbor_index_value)
		if neighbor_index < 0 or neighbor_index >= _cells.size():
			continue
		var neighbor: Dictionary = _cells[neighbor_index]
		if not _is_myco(neighbor):
			continue
		if not _cell_slots(neighbor).is_empty():
			continue
		var enqueue_count := int(queued.get(neighbor_index, 0))
		if enqueue_count >= _cells.size():
			continue
		queue.append(neighbor_index)
		queued[neighbor_index] = enqueue_count + 1


func _add_connected_component_candidate_scores(myco: Dictionary, scores: Dictionary) -> void:
	var max_depth := 8
	var adjacent_indices: Array = _get_adjacent_indices_by_cell()
	var queue: Array[Dictionary] = [{"cell": int(myco["index"]), "depth": 0}]
	var visited: Dictionary = {int(myco["index"]): true}
	var cursor := 0
	while cursor < queue.size():
		var entry: Dictionary = queue[cursor]
		cursor += 1
		var cell_index := int(entry["cell"])
		var depth := int(entry["depth"])
		if depth > 0:
			_add_connected_cell_scores(_cells[cell_index], depth, scores)
		if depth >= max_depth:
			continue
		if cell_index < 0 or cell_index >= adjacent_indices.size():
			continue
		var neighbors: Array = adjacent_indices[cell_index] as Array
		for next_value in neighbors:
			var next := int(next_value)
			if next >= 0 and not visited.has(next):
				visited[next] = true
				queue.append({"cell": next, "depth": depth + 1})


func _add_connected_cell_scores(cell: Dictionary, depth: int, scores: Dictionary) -> void:
	var distance_penalty := mini(48, depth * 6)
	var slots: Array = cell["slots"] as Array
	for slot_value in slots:
		var slot: Dictionary = slot_value
		var resource := int(slot["resource"])
		var role := str(slot["role"])
		if _is_myco(cell):
			_add_candidate_score(scores, resource, maxi(12, 72 - distance_penalty))
		elif role == ROLE_SOURCE_OUTPUT:
			_add_candidate_score(scores, resource, maxi(12, 88 - distance_penalty))
		elif role == ROLE_NEED:
			_add_candidate_score(scores, resource, maxi(8, 58 - distance_penalty))
	var sources: Array = cell["sources"] as Array
	for source_value in sources:
		var source: Dictionary = source_value
		_add_candidate_score(scores, int(source["resource"]), maxi(12, 88 - distance_penalty))


func _replace_adaptive_myco_slots(myco: Dictionary, resources: Array[int]) -> bool:
	var slots: Array = myco["slots"] as Array
	if slots.size() == resources.size():
		var same := true
		for index in range(resources.size()):
			var slot: Dictionary = slots[index]
			if int(slot["resource"]) != int(resources[index]) or str(slot["role"]) != ROLE_NEED or int(slot["quantity"]) != ADAPTIVE_MYCO_STARTING_QUANTITY or int(slot["capacity"]) != ADAPTIVE_MYCO_SLOT_CAPACITY:
				same = false
				break
		if same:
			return false
	slots.clear()
	for index in range(mini(MAX_SLOTS, resources.size())):
		slots.append({
			"resource": int(resources[index]),
			"role": ROLE_NEED,
			"quantity": ADAPTIVE_MYCO_STARTING_QUANTITY,
			"capacity": ADAPTIVE_MYCO_SLOT_CAPACITY
		})
	return true


func _run_source_production() -> void:
	for cell in _cells:
		var sources: Array = cell["sources"] as Array
		for source_value in sources:
			var source: Dictionary = source_value
			var interval := int(source["intervalTicks"])
			if interval <= 0 or _current_tick % interval != 0:
				continue
			var resource := int(source["resource"])
			var quantity := int(source["quantityPerTick"])
			var slot: Dictionary = _get_slot(cell, resource)
			if slot.is_empty():
				_increment_strain(cell, "sourceBlocked")
				_add_event({"type": "overflow", "tick": _current_tick, "cellId": str(cell["id"]), "resource": resource, "quantity": quantity})
				_add_event({"type": "strain", "tick": _current_tick, "cellId": str(cell["id"]), "reason": "SourceBlocked"})
				continue
			var accepted := _add_resource_to_slot(slot, quantity)
			if accepted < quantity:
				var blocked := quantity - accepted
				_increment_strain(cell, "sourceBlocked")
				_increment_strain(cell, "overCapacity")
				_add_event({"type": "overflow", "tick": _current_tick, "cellId": str(cell["id"]), "resource": resource, "quantity": blocked})
				_add_event({"type": "strain", "tick": _current_tick, "cellId": str(cell["id"]), "reason": "OverCapacityPressure"})


func _resolve_swap_rounds() -> void:
	var edges: Array[Dictionary] = _get_adjacent_edges()
	if edges.is_empty():
		return
	var edge_used: Array[bool] = []
	for _edge in edges:
		edge_used.append(false)
	for _round in range(int(_options["swapRoundsPerTick"])):
		_generate_swap_proposals(edges, edge_used)
		if _swap_proposals.is_empty():
			break
		_resolve_swap_proposals()


func _generate_swap_proposals(edges: Array[Dictionary], edge_used: Array[bool]) -> void:
	_swap_proposals.clear()
	_candidate_swap_proposals.clear()
	_reserved_out.clear()
	_reserved_in.clear()
	for edge_order in range(edges.size()):
		if edge_used[edge_order]:
			continue
		var edge: Dictionary = edges[edge_order]
		_add_swap_candidates_for_direction(int(edge["a"]), int(edge["b"]), edge_order)
		_add_swap_candidates_for_direction(int(edge["b"]), int(edge["a"]), edge_order)
	_candidate_swap_proposals.sort_custom(Callable(self, "_compare_prioritized_swap_proposals"))
	for candidate in _candidate_swap_proposals:
		var edge_order := int(candidate["edgeOrder"])
		if edge_used[edge_order]:
			continue
		var proposal: Dictionary = candidate["proposal"]
		if _can_reserve_swap(proposal):
			_reserve_swap(proposal)
			_swap_proposals.append(proposal)
			edge_used[edge_order] = true


func _add_swap_candidates_for_direction(initiator_index: int, counterparty_index: int, edge_order: int) -> void:
	var initiator: Dictionary = _cells[initiator_index]
	var counterparty: Dictionary = _cells[counterparty_index]
	var slots: Array = initiator["slots"] as Array
	for requested_value in slots:
		var requested_slot: Dictionary = requested_value
		if str(requested_slot["role"]) != ROLE_NEED:
			continue
		_add_swap_candidates_for_requested_resource(initiator, counterparty, initiator_index, counterparty_index, requested_slot, edge_order)


func _add_swap_candidates_for_requested_resource(initiator: Dictionary, counterparty: Dictionary, initiator_index: int, counterparty_index: int, requested_slot: Dictionary, edge_order: int) -> void:
	var requested_resource := int(requested_slot["resource"])
	var counterparty_offerable := _get_offerable_swap_quantity(counterparty, requested_resource, _get_reserved_out(counterparty_index, requested_resource))
	if counterparty_offerable <= 0:
		return
	var initiator_receivable := _get_requested_resource_receivable_swap_quantity(initiator, requested_resource, _get_reserved_in(initiator_index, requested_resource))
	if initiator_receivable <= 0:
		return
	var slots: Array = initiator["slots"] as Array
	for slot_value in slots:
		var slot: Dictionary = slot_value
		var candidate_resource := int(slot["resource"])
		if int(slot["quantity"]) <= 0 or candidate_resource == requested_resource:
			continue
		var initiator_offerable := _get_offerable_swap_quantity(initiator, candidate_resource, _get_reserved_out(initiator_index, candidate_resource))
		if initiator_offerable <= 0:
			continue
		var counterparty_receive_slot: Dictionary = _get_slot(counterparty, candidate_resource)
		if counterparty_receive_slot.is_empty():
			continue
		var counterparty_reserved_in := _get_reserved_in(counterparty_index, candidate_resource)
		var counterparty_receivable := _get_receivable_swap_quantity(counterparty, candidate_resource, counterparty_reserved_in)
		if counterparty_receivable <= 0:
			continue
		var proposal := _create_swap_proposal(initiator, counterparty, initiator_index, counterparty_index, candidate_resource, requested_resource, initiator_offerable, counterparty_offerable, initiator_receivable, counterparty_receivable)
		if proposal.is_empty():
			continue
		var offer_priority := _create_offer_priority(slot, counterparty_receive_slot, counterparty_reserved_in)
		_candidate_swap_proposals.append({
			"proposal": proposal,
			"requestedBalance": int(requested_slot["quantity"]) + _get_reserved_in(initiator_index, requested_resource),
			"missingNeedRank": int(offer_priority["missingNeedRank"]),
			"sourceReturnRank": int(offer_priority["sourceReturnRank"]),
			"counterpartyNeedBalance": int(offer_priority["counterpartyNeedBalance"]),
			"offeredRoleRank": int(offer_priority["offeredRoleRank"]),
			"edgeOrder": edge_order
		})


func _create_swap_proposal(initiator: Dictionary, counterparty: Dictionary, initiator_index: int, counterparty_index: int, initiator_paid_resource: int, counterparty_paid_resource: int, initiator_paid_offerable: int, counterparty_paid_offerable: int, initiator_receivable: int, counterparty_receivable: int) -> Dictionary:
	var quantities := _get_swap_quantities(initiator, counterparty, int(_options["maxSwapQuantityPerEdge"]), initiator_paid_offerable, counterparty_paid_offerable, initiator_receivable, counterparty_receivable)
	if quantities.is_empty():
		return {}
	return {
		"initiatorIndex": initiator_index,
		"counterpartyIndex": counterparty_index,
		"initiatorPaidResource": initiator_paid_resource,
		"counterpartyPaidResource": counterparty_paid_resource,
		"initiatorPaidQuantity": int(quantities["initiatorPaidQuantity"]),
		"counterpartyPaidQuantity": int(quantities["counterpartyPaidQuantity"]),
		"initiatorReceivedQuantity": int(quantities["initiatorReceivedQuantity"]),
		"counterpartyReceivedQuantity": int(quantities["counterpartyReceivedQuantity"]),
		"priorityQuantity": maxi(int(quantities["initiatorPaidQuantity"]), int(quantities["counterpartyPaidQuantity"]))
	}


func _get_swap_quantities(initiator: Dictionary, counterparty: Dictionary, max_swap_quantity: int, initiator_paid_offerable: int, counterparty_paid_offerable: int, initiator_receivable: int, counterparty_receivable: int) -> Dictionary:
	var initiator_fee := RED_MYCO_OUTWARD_FEE if _is_red_myco(initiator) else 0
	var counterparty_fee := RED_MYCO_OUTWARD_FEE if _is_red_myco(counterparty) else 0
	var minimum_gross := RED_MYCO_MINIMUM_GROSS_SWAP if initiator_fee > 0 or counterparty_fee > 0 else STANDARD_MINIMUM_GROSS_SWAP
	var gross := mini(max_swap_quantity, mini(mini(initiator_paid_offerable, counterparty_paid_offerable), mini(_increase_limit(initiator_receivable, counterparty_fee), _increase_limit(counterparty_receivable, initiator_fee))))
	if gross < minimum_gross:
		return {}
	return {
		"initiatorPaidQuantity": gross,
		"counterpartyPaidQuantity": gross,
		"initiatorReceivedQuantity": gross - counterparty_fee,
		"counterpartyReceivedQuantity": gross - initiator_fee
	}


func _can_reserve_swap(proposal: Dictionary) -> bool:
	var initiator_index := int(proposal["initiatorIndex"])
	var counterparty_index := int(proposal["counterpartyIndex"])
	var initiator: Dictionary = _cells[initiator_index]
	var counterparty: Dictionary = _cells[counterparty_index]
	var initiator_paid := int(proposal["initiatorPaidResource"])
	var counterparty_paid := int(proposal["counterpartyPaidResource"])
	if _get_offerable_swap_quantity(initiator, initiator_paid, _get_reserved_out(initiator_index, initiator_paid)) < int(proposal["initiatorPaidQuantity"]):
		return false
	if _get_offerable_swap_quantity(counterparty, counterparty_paid, _get_reserved_out(counterparty_index, counterparty_paid)) < int(proposal["counterpartyPaidQuantity"]):
		return false
	if _get_requested_resource_receivable_swap_quantity(initiator, counterparty_paid, _get_reserved_in(initiator_index, counterparty_paid)) < int(proposal["initiatorReceivedQuantity"]):
		return false
	return _get_receivable_swap_quantity(counterparty, initiator_paid, _get_reserved_in(counterparty_index, initiator_paid)) >= int(proposal["counterpartyReceivedQuantity"])


func _reserve_swap(proposal: Dictionary) -> void:
	var initiator_index := int(proposal["initiatorIndex"])
	var counterparty_index := int(proposal["counterpartyIndex"])
	var initiator_paid := int(proposal["initiatorPaidResource"])
	var counterparty_paid := int(proposal["counterpartyPaidResource"])
	_add_reserved_out(initiator_index, initiator_paid, int(proposal["initiatorPaidQuantity"]))
	_add_reserved_out(counterparty_index, counterparty_paid, int(proposal["counterpartyPaidQuantity"]))
	_add_reserved_in(initiator_index, counterparty_paid, int(proposal["initiatorReceivedQuantity"]))
	_add_reserved_in(counterparty_index, initiator_paid, int(proposal["counterpartyReceivedQuantity"]))


func _resolve_swap_proposals() -> void:
	for proposal in _swap_proposals:
		var initiator: Dictionary = _cells[int(proposal["initiatorIndex"])]
		var counterparty: Dictionary = _cells[int(proposal["counterpartyIndex"])]
		var initiator_paid := int(proposal["initiatorPaidResource"])
		var counterparty_paid := int(proposal["counterpartyPaidResource"])
		var initiator_receive_slot: Dictionary = _get_slot(initiator, counterparty_paid)
		var counterparty_receive_slot: Dictionary = _get_slot(counterparty, initiator_paid)
		_remove_resource(initiator, initiator_paid, int(proposal["initiatorPaidQuantity"]))
		_remove_resource(counterparty, counterparty_paid, int(proposal["counterpartyPaidQuantity"]))
		_add_resource_to_slot(initiator_receive_slot, int(proposal["initiatorReceivedQuantity"]))
		_add_resource_to_slot(counterparty_receive_slot, int(proposal["counterpartyReceivedQuantity"]))
		if _is_red_myco(initiator):
			initiator["glow"] = int(_options["glowTtlTicks"])
			_add_unique_int(_glow_refreshed_indices, int(initiator["index"]))
		if _is_red_myco(counterparty):
			counterparty["glow"] = int(_options["glowTtlTicks"])
			_add_unique_int(_glow_refreshed_indices, int(counterparty["index"]))
		_add_event({
			"type": "swap",
			"tick": _current_tick,
			"initiator": str(initiator["id"]),
			"counterparty": str(counterparty["id"]),
			"initiatorPaidResource": initiator_paid,
			"counterpartyPaidResource": counterparty_paid,
			"initiatorPaidQuantity": int(proposal["initiatorPaidQuantity"]),
			"counterpartyPaidQuantity": int(proposal["counterpartyPaidQuantity"]),
			"initiatorReceivedQuantity": int(proposal["initiatorReceivedQuantity"]),
			"counterpartyReceivedQuantity": int(proposal["counterpartyReceivedQuantity"]),
			"initiatorReceivedBalance": int(initiator_receive_slot.get("quantity", 0)),
			"initiatorReceivedCapacity": int(initiator_receive_slot.get("capacity", DEFAULT_SLOT_CAPACITY)),
			"counterpartyReceivedBalance": int(counterparty_receive_slot.get("quantity", 0)),
			"counterpartyReceivedCapacity": int(counterparty_receive_slot.get("capacity", DEFAULT_SLOT_CAPACITY))
		})
		_add_event({
			"type": "flow",
			"tick": _current_tick,
			"sourceCellId": str(initiator["id"]),
			"targetCellId": str(counterparty["id"]),
			"resource": initiator_paid,
			"quantity": int(proposal["counterpartyReceivedQuantity"]),
			"kind": "Reciprocal"
		})
		_add_event({
			"type": "flow",
			"tick": _current_tick,
			"sourceCellId": str(counterparty["id"]),
			"targetCellId": str(initiator["id"]),
			"resource": counterparty_paid,
			"quantity": int(proposal["initiatorReceivedQuantity"]),
			"kind": "Reciprocal"
		})


func _resolve_reactions() -> void:
	_reacted_indices.clear()
	for cell in _cells:
		if _is_myco(cell):
			continue
		if not _pool_can_react(cell):
			continue
		var slots: Array = cell["slots"] as Array
		for slot_value in slots:
			var slot: Dictionary = slot_value
			if str(slot["role"]) != ROLE_ACCEPT_ONLY:
				slot["quantity"] = maxi(0, int(slot["quantity"]) - 1)
		cell["glow"] = int(_options["glowTtlTicks"])
		_add_unique_int(_reacted_indices, int(cell["index"]))
		_reaction_score += 10
		_add_event({"type": "reaction", "tick": _current_tick, "cellId": str(cell["id"])})


func _update_glow_and_strain() -> void:
	for cell in _cells:
		var index := int(cell["index"])
		var reacted := _reacted_indices.has(index)
		var glow_refreshed := _glow_refreshed_indices.has(index)
		if not reacted and not glow_refreshed and int(cell["glow"]) > 0:
			cell["glow"] = int(cell["glow"]) - 1
		if reacted or _is_myco(cell):
			continue
		var slots: Array = cell["slots"] as Array
		for slot_value in slots:
			var slot: Dictionary = slot_value
			if str(slot["role"]) == ROLE_NEED and int(slot["quantity"]) <= 0:
				_increment_strain(cell, "unmet")
				_add_event({"type": "strain", "tick": _current_tick, "cellId": str(cell["id"]), "reason": "UnmetNeed"})


func _update_score() -> void:
	var flow_seen: Dictionary = {}
	var flow_diversity := 0
	var settlement := 0
	for event in _events:
		var event_type := str(event.get("type", ""))
		if event_type == "flow":
			var resource := int(event.get("resource", -1))
			if resource >= 0 and not flow_seen.has(resource):
				flow_seen[resource] = true
				flow_diversity += 1
		elif event_type == "reaction":
			settlement += 1
	var strain := 0
	for cell in _cells:
		strain += _strain_total(cell)
	_flow_diversity_score = flow_diversity * 2
	_settlement_score = settlement
	_strain_penalty = strain


func _update_win_check() -> void:
	var was_won := _won
	var alive := _compute_living_circuit()
	_alive_this_tick = alive
	_sustained_ticks = _sustained_ticks + 1 if alive else 0
	if not _won and alive and _sustained_ticks >= int(_options["winDurationTicks"]):
		_won = true
	if was_won != _won:
		_add_event({"type": "win", "tick": _current_tick, "won": _won})


func _compute_living_circuit() -> bool:
	if _required_cell_ids.is_empty():
		return false
	for cell_id in _required_cell_ids:
		if not _cell_index_by_id.has(cell_id):
			return false
		if not _is_cell_glowing(_cells[int(_cell_index_by_id[cell_id])]):
			return false
	var since_tick := _current_tick - int(_options["winRecentFlowWindowTicks"])
	var flow_resource_seen: Dictionary = {}
	var graph: Dictionary = {}
	for event in _events:
		if str(event.get("type", "")) != "flow" or int(event.get("tick", 0)) < since_tick:
			continue
		var resource := int(event.get("resource", -1))
		if resource >= 0:
			flow_resource_seen[resource] = true
		var source := str(event.get("sourceCellId", ""))
		var target := str(event.get("targetCellId", ""))
		if not graph.has(source):
			graph[source] = []
		(graph[source] as Array).append(target)
	for resource in _required_resources:
		if not flow_resource_seen.has(int(resource)):
			return false
	if _required_cell_ids.size() <= 1:
		return true
	for source in _required_cell_ids:
		for target in _required_cell_ids:
			if source != target and not _can_reach(graph, source, target):
				return false
	return true


func _can_reach(graph: Dictionary, source: String, target: String) -> bool:
	var seen: Dictionary = {}
	var stack: Array[String] = [source]
	while not stack.is_empty():
		var current: String = str(stack.pop_back())
		if seen.has(current):
			continue
		seen[current] = true
		if current == target:
			return true
		var neighbors_value: Variant = graph.get(current, [])
		if not neighbors_value is Array:
			continue
		for neighbor_value in neighbors_value as Array:
			stack.append(str(neighbor_value))
	return false


func _build_rocks_snapshot() -> Array:
	var result: Array = []
	for rock in _rocks:
		result.append({"x": rock.x, "y": rock.y})
	return result


func _build_cells_snapshot() -> Array:
	var result: Array = []
	for cell in _cells:
		result.append({
			"id": str(cell["id"]),
			"x": int(cell["x"]),
			"y": int(cell["y"]),
			"kind": str(cell["kind"]),
			"glowing": _is_cell_glowing(cell),
			"glowTicks": int(cell["glow"]),
			"mycoWaiting": _is_myco(cell) and (cell["slots"] as Array).is_empty(),
			"strain": _strain_total(cell),
			"producedResource": _produced_resource_name(cell),
			"slots": _build_slots_snapshot(cell)
		})
	return result


func _build_slots_snapshot(cell: Dictionary) -> Array:
	var result: Array = []
	var slots: Array = cell["slots"] as Array
	for slot_value in slots:
		var slot: Dictionary = slot_value
		var capacity := int(slot["capacity"])
		var quantity := int(slot["quantity"])
		result.append({
			"resource": _resource_name(int(slot["resource"])),
			"role": str(slot["role"]),
			"quantity": quantity,
			"capacity": capacity,
			"fullness": 0.0 if capacity <= 0 else float(quantity) / float(capacity)
		})
	return result


func _build_recent_swaps_snapshot() -> Array:
	var result: Array = []
	var min_tick := _current_tick - RECENT_EVENT_WINDOW_TICKS
	for event in _events:
		if str(event.get("type", "")) != "swap" or int(event.get("tick", 0)) < min_tick:
			continue
		result.append({
			"tick": int(event["tick"]),
			"initiator": str(event["initiator"]),
			"counterparty": str(event["counterparty"]),
			"initiatorPaidResource": _resource_name(int(event["initiatorPaidResource"])),
			"counterpartyPaidResource": _resource_name(int(event["counterpartyPaidResource"])),
			"initiatorPaidQuantity": int(event["initiatorPaidQuantity"]),
			"counterpartyPaidQuantity": int(event["counterpartyPaidQuantity"]),
			"initiatorReceivedQuantity": int(event["initiatorReceivedQuantity"]),
			"counterpartyReceivedQuantity": int(event["counterpartyReceivedQuantity"]),
			"initiatorReceivedBalance": int(event["initiatorReceivedBalance"]),
			"initiatorReceivedCapacity": int(event["initiatorReceivedCapacity"]),
			"counterpartyReceivedBalance": int(event["counterpartyReceivedBalance"]),
			"counterpartyReceivedCapacity": int(event["counterpartyReceivedCapacity"])
		})
	return result


func _build_recent_flows_snapshot() -> Array:
	var result: Array = []
	var min_tick := _current_tick - RECENT_EVENT_WINDOW_TICKS
	for event in _events:
		if str(event.get("type", "")) != "flow" or int(event.get("tick", 0)) < min_tick:
			continue
		result.append({
			"tick": int(event["tick"]),
			"sourceCellId": str(event["sourceCellId"]),
			"targetCellId": str(event["targetCellId"]),
			"resource": _resource_name(int(event["resource"])),
			"quantity": int(event["quantity"]),
			"kind": str(event["kind"])
		})
	return result


func _build_recent_reactions_snapshot() -> Array:
	var result: Array = []
	var min_tick := _current_tick - RECENT_EVENT_WINDOW_TICKS
	for event in _events:
		if str(event.get("type", "")) == "reaction" and int(event.get("tick", 0)) >= min_tick:
			result.append({"tick": int(event["tick"]), "cellId": str(event["cellId"])})
	return result


func _build_possible_swaps_snapshot() -> Array:
	var result: Array = []
	var edges: Array[Dictionary] = _get_adjacent_edges()
	for edge in edges:
		_add_possible_swap_direction(int(edge["a"]), int(edge["b"]), result)
		if result.size() >= POSSIBLE_SWAP_SNAPSHOT_LIMIT:
			break
		_add_possible_swap_direction(int(edge["b"]), int(edge["a"]), result)
		if result.size() >= POSSIBLE_SWAP_SNAPSHOT_LIMIT:
			break
	return result


func _add_possible_swap_direction(initiator_index: int, counterparty_index: int, result: Array) -> void:
	if result.size() >= POSSIBLE_SWAP_SNAPSHOT_LIMIT:
		return
	var initiator: Dictionary = _cells[initiator_index]
	var counterparty: Dictionary = _cells[counterparty_index]
	var slots: Array = initiator["slots"] as Array
	for requested_value in slots:
		var requested_slot: Dictionary = requested_value
		if str(requested_slot["role"]) != ROLE_NEED:
			continue
		var requested_resource := int(requested_slot["resource"])
		var requested_offerable := _get_visual_offerable_quantity(counterparty, requested_resource)
		var requested_receivable := _get_visual_requested_receivable_quantity(initiator, requested_resource)
		if requested_offerable <= 0 or requested_receivable <= 0:
			continue
		for offered_value in slots:
			var offered_slot: Dictionary = offered_value
			var offered_resource := int(offered_slot["resource"])
			if offered_resource == requested_resource:
				continue
			var offered_quantity := _get_visual_offerable_quantity(initiator, offered_resource)
			var counterparty_receivable := _get_visual_receivable_quantity(counterparty, offered_resource)
			var quantities := _get_swap_quantities(initiator, counterparty, int(_options["maxSwapQuantityPerEdge"]), offered_quantity, requested_offerable, requested_receivable, counterparty_receivable)
			if quantities.is_empty():
				continue
			result.append({
				"initiator": str(initiator["id"]),
				"counterparty": str(counterparty["id"]),
				"initiatorPaidResource": _resource_name(offered_resource),
				"counterpartyPaidResource": _resource_name(requested_resource),
				"quantity": maxi(int(quantities["initiatorPaidQuantity"]), int(quantities["counterpartyPaidQuantity"])),
				"initiatorPaidQuantity": int(quantities["initiatorPaidQuantity"]),
				"counterpartyPaidQuantity": int(quantities["counterpartyPaidQuantity"]),
				"initiatorReceivedQuantity": int(quantities["initiatorReceivedQuantity"]),
				"counterpartyReceivedQuantity": int(quantities["counterpartyReceivedQuantity"])
			})
			if result.size() >= POSSIBLE_SWAP_SNAPSHOT_LIMIT:
				return


func _build_circuit_diagnostics_snapshot() -> Dictionary:
	var since_tick := _current_tick - int(_options["winRecentFlowWindowTicks"])
	var required_cells: Array[String] = []
	if _required_cell_ids.is_empty():
		for cell in _cells:
			_add_unique_string(required_cells, str(cell["id"]))
	else:
		for cell_id in _required_cell_ids:
			_add_unique_string(required_cells, cell_id)
	required_cells.sort()
	var required_lookup: Dictionary = {}
	var adjacency: Dictionary = {}
	var weak_parent: Dictionary = {}
	for cell_id in required_cells:
		required_lookup[cell_id] = true
		adjacency[cell_id] = []
		weak_parent[cell_id] = cell_id
	var edge_accumulators: Dictionary = {}
	var seen_resources: Dictionary = {}
	for event in _events:
		if str(event.get("type", "")) != "flow" or int(event.get("tick", 0)) < since_tick:
			continue
		var resource := int(event.get("resource", -1))
		if resource >= 0:
			seen_resources[resource] = true
		var source := str(event.get("sourceCellId", ""))
		var target := str(event.get("targetCellId", ""))
		var key := source + "\n" + target
		if not edge_accumulators.has(key):
			edge_accumulators[key] = {
				"source": source,
				"target": target,
				"latest": int(event.get("tick", 0)),
				"quantity": 0,
				"resources": {}
			}
		var accumulator: Dictionary = edge_accumulators[key]
		accumulator["quantity"] = int(accumulator["quantity"]) + int(event.get("quantity", 0))
		accumulator["latest"] = maxi(int(accumulator["latest"]), int(event.get("tick", 0)))
		(accumulator["resources"] as Dictionary)[resource] = true
		if required_lookup.has(source) and required_lookup.has(target):
			(adjacency[source] as Array).append(target)
			_union_parent(weak_parent, source, target)
	var directed_edges: Array = []
	for accumulator_value in edge_accumulators.values():
		var accumulator_doc: Dictionary = accumulator_value
		var resource_ids: Array[int] = []
		for resource_key in (accumulator_doc["resources"] as Dictionary).keys():
			resource_ids.append(int(resource_key))
		resource_ids.sort()
		var resource_names: Array = []
		for resource_id in resource_ids:
			resource_names.append(_resource_name(resource_id))
		directed_edges.append({
			"sourceCellId": str(accumulator_doc["source"]),
			"targetCellId": str(accumulator_doc["target"]),
			"latestTick": int(accumulator_doc["latest"]),
			"ageTicks": maxi(0, _current_tick - int(accumulator_doc["latest"])),
			"quantity": int(accumulator_doc["quantity"]),
			"resources": resource_names
		})
	directed_edges.sort_custom(Callable(self, "_compare_diagnostic_edges"))
	var missing_resources: Array = []
	for resource in _required_resources:
		if not seen_resources.has(int(resource)):
			missing_resources.append(_resource_name(int(resource)))
	var non_glowing: Array = []
	for cell_id in required_cells:
		if not _cell_index_by_id.has(cell_id) or not _is_cell_glowing(_cells[int(_cell_index_by_id[cell_id])]):
			non_glowing.append(cell_id)
	return {
		"alive": _alive_this_tick,
		"won": _won,
		"sustainedTicks": _sustained_ticks,
		"sinceTick": since_tick,
		"directedEdges": directed_edges,
		"strongGroups": _build_strong_groups(required_cells, adjacency),
		"weakGroups": _build_weak_groups(required_cells, weak_parent),
		"nonGlowingRequiredCells": non_glowing,
		"missingRequiredResources": missing_resources
	}


func _build_strong_groups(nodes: Array[String], adjacency: Dictionary) -> Array:
	var reverse: Dictionary = {}
	for node in nodes:
		reverse[node] = []
	for source in nodes:
		var neighbors_value: Variant = adjacency.get(source, [])
		if not neighbors_value is Array:
			continue
		for target_value in neighbors_value as Array:
			var target := str(target_value)
			if reverse.has(target):
				(reverse[target] as Array).append(source)
	var seen: Dictionary = {}
	var order: Array[String] = []
	for node in nodes:
		_dfs_order(node, adjacency, seen, order)
	seen.clear()
	var groups: Array = []
	for index in range(order.size() - 1, -1, -1):
		var node: String = str(order[index])
		if seen.has(node):
			continue
		var members: Array[String] = []
		_dfs_collect(node, reverse, seen, members)
		members.sort()
		groups.append(members)
	return _sort_diagnostic_groups(groups)


func _dfs_order(node: String, adjacency: Dictionary, seen: Dictionary, order: Array[String]) -> void:
	if seen.has(node):
		return
	seen[node] = true
	var neighbors_value: Variant = adjacency.get(node, [])
	if neighbors_value is Array:
		for target_value in neighbors_value as Array:
			_dfs_order(str(target_value), adjacency, seen, order)
	order.append(node)


func _dfs_collect(node: String, adjacency: Dictionary, seen: Dictionary, members: Array[String]) -> void:
	if seen.has(node):
		return
	seen[node] = true
	members.append(node)
	var neighbors_value: Variant = adjacency.get(node, [])
	if neighbors_value is Array:
		for target_value in neighbors_value as Array:
			_dfs_collect(str(target_value), adjacency, seen, members)


func _build_weak_groups(nodes: Array[String], parent: Dictionary) -> Array:
	var groups_by_root: Dictionary = {}
	for node in nodes:
		var root := _find_parent(parent, node)
		if not groups_by_root.has(root):
			groups_by_root[root] = []
		(groups_by_root[root] as Array).append(node)
	var groups: Array = []
	for group_value in groups_by_root.values():
		var group: Array = group_value
		group.sort()
		groups.append(group)
	return _sort_diagnostic_groups(groups)


func _sort_diagnostic_groups(groups: Array) -> Array:
	groups.sort_custom(Callable(self, "_compare_diagnostic_groups"))
	return groups


func _get_adjacent_edges() -> Array[Dictionary]:
	if _adjacent_edges_topology_version == _topology_version:
		return _adjacent_edges_cache
	var edges: Array[Dictionary] = []
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	for cell in _cells:
		var cell_index := int(cell["index"])
		var position := Vector2i(int(cell["x"]), int(cell["y"]))
		for offset_value in offsets:
			var offset: Vector2i = offset_value
			var neighbor_position: Vector2i = position + offset
			var neighbor_key := _position_key(neighbor_position)
			if not _occupancy.has(neighbor_key):
				continue
			var neighbor_index := int(_occupancy[neighbor_key])
			if cell_index >= neighbor_index:
				continue
			var first_index := cell_index
			var second_index := neighbor_index
			if _compare_cells_stable(_cells[first_index], _cells[second_index]) > 0:
				first_index = neighbor_index
				second_index = cell_index
			edges.append({"a": first_index, "b": second_index})
	edges.sort_custom(Callable(self, "_compare_edges"))
	_adjacent_edges_cache = edges
	_adjacent_edges_topology_version = _topology_version
	return _adjacent_edges_cache


func _get_adjacent_indices_by_cell() -> Array:
	if _adjacent_indices_topology_version == _topology_version:
		return _adjacent_indices_cache
	var adjacent: Array = []
	for _cell in _cells:
		adjacent.append([])
	var edges: Array[Dictionary] = _get_adjacent_edges()
	for edge in edges:
		var a := int(edge["a"])
		var b := int(edge["b"])
		if a >= 0 and a < adjacent.size() and b >= 0 and b < adjacent.size():
			(adjacent[a] as Array).append(b)
			(adjacent[b] as Array).append(a)
	_adjacent_indices_cache = adjacent
	_adjacent_indices_topology_version = _topology_version
	return _adjacent_indices_cache


func _can_move_cell(cell_id: String, position: Vector2i) -> bool:
	if not _cell_index_by_id.has(cell_id):
		return false
	if not _in_bounds(position) or _rock_lookup.has(_position_key(position)):
		return false
	var index := int(_cell_index_by_id[cell_id])
	var key := _position_key(position)
	return not _occupancy.has(key) or int(_occupancy[key]) == index


func _pool_can_react(cell: Dictionary) -> bool:
	var has_need := false
	var has_active_slot := false
	var slots: Array = cell["slots"] as Array
	for slot_value in slots:
		var slot: Dictionary = slot_value
		var role := str(slot["role"])
		if role == ROLE_NEED:
			has_need = true
		if role == ROLE_ACCEPT_ONLY:
			continue
		has_active_slot = true
		if int(slot["quantity"]) < 1:
			return false
	return has_need and has_active_slot


func _get_requested_resource_receivable_swap_quantity(cell: Dictionary, resource: int, reserved_incoming: int) -> int:
	var slot: Dictionary = _get_slot(cell, resource)
	if slot.is_empty():
		return 0
	if _is_myco(cell):
		return _get_receivable_swap_quantity(cell, resource, reserved_incoming)
	if str(slot["role"]) == ROLE_NEED:
		var target := mini(int(slot["capacity"]), int(_options["needDesiredQuantity"]))
		return maxi(0, target - int(slot["quantity"]) - reserved_incoming)
	return _get_receivable_swap_quantity(cell, resource, reserved_incoming)


func _get_receivable_swap_quantity(cell: Dictionary, resource: int, reserved_incoming: int) -> int:
	var slot: Dictionary = _get_slot(cell, resource)
	if slot.is_empty():
		return 0
	if _is_myco(cell):
		return maxi(0, int(slot["capacity"]) - int(slot["quantity"]) - reserved_incoming)
	var role := str(slot["role"])
	if role == ROLE_SOURCE_OUTPUT or (role == ROLE_NEED and bool(_options["allowNeedOverflowPayments"])):
		return LARGE_RECEIVE_LIMIT
	return maxi(0, int(slot["capacity"]) - int(slot["quantity"]) - reserved_incoming)


func _get_offerable_swap_quantity(cell: Dictionary, resource: int, reserved_outgoing: int) -> int:
	var slot: Dictionary = _get_slot(cell, resource)
	if slot.is_empty():
		return 0
	var available := int(slot["quantity"]) - reserved_outgoing
	if _is_myco(cell):
		return maxi(0, available)
	var role := str(slot["role"])
	if role == ROLE_NEED:
		available -= int(_options["needOfferReserve"])
	elif role == ROLE_SOURCE_OUTPUT and _has_need_slot(cell):
		available -= 1
	return maxi(0, available)


func _get_visual_requested_receivable_quantity(cell: Dictionary, resource: int) -> int:
	var slot: Dictionary = _get_slot(cell, resource)
	if slot.is_empty():
		return 0
	if _is_myco(cell):
		return maxi(0, int(slot["capacity"]) - int(slot["quantity"]))
	if str(slot["role"]) == ROLE_NEED:
		var target := mini(int(slot["capacity"]), int(_options["needDesiredQuantity"]))
		return maxi(0, target - int(slot["quantity"]))
	return _get_visual_receivable_quantity(cell, resource)


func _get_visual_receivable_quantity(cell: Dictionary, resource: int) -> int:
	var slot: Dictionary = _get_slot(cell, resource)
	if slot.is_empty():
		return 0
	if _is_myco(cell):
		return maxi(0, int(slot["capacity"]) - int(slot["quantity"]))
	var role := str(slot["role"])
	if role == ROLE_SOURCE_OUTPUT or (role == ROLE_NEED and bool(_options["allowNeedOverflowPayments"])):
		return LARGE_RECEIVE_LIMIT
	return maxi(0, int(slot["capacity"]) - int(slot["quantity"]))


func _get_visual_offerable_quantity(cell: Dictionary, resource: int) -> int:
	var slot: Dictionary = _get_slot(cell, resource)
	if slot.is_empty():
		return 0
	var available := int(slot["quantity"])
	if _is_myco(cell):
		return maxi(0, available)
	var role := str(slot["role"])
	if role == ROLE_NEED:
		available -= int(_options["needOfferReserve"])
	elif role == ROLE_SOURCE_OUTPUT and _has_need_slot(cell):
		available -= 1
	return maxi(0, available)


func _create_offer_priority(offered_slot: Dictionary, counterparty_receive_slot: Dictionary, counterparty_reserved_in: int) -> Dictionary:
	var counterparty_need_balance := int(counterparty_receive_slot["quantity"]) + counterparty_reserved_in
	var counterparty_missing_need_rank := 0 if str(counterparty_receive_slot["role"]) == ROLE_NEED and counterparty_need_balance == 0 else 1
	var source_return_rank := 0 if str(counterparty_receive_slot["role"]) == ROLE_SOURCE_OUTPUT else 1
	var offered_role_rank := 3
	var offered_role := str(offered_slot["role"])
	if offered_role == ROLE_SOURCE_OUTPUT:
		offered_role_rank = 0
	elif offered_role == ROLE_NEED:
		offered_role_rank = 1
	elif offered_role == ROLE_ACCEPT_ONLY:
		offered_role_rank = 2
	return {
		"missingNeedRank": counterparty_missing_need_rank,
		"sourceReturnRank": source_return_rank,
		"counterpartyNeedBalance": counterparty_need_balance,
		"offeredRoleRank": offered_role_rank
	}


func _get_slot(cell: Dictionary, resource: int) -> Dictionary:
	var slots: Array = cell["slots"] as Array
	return _find_slot_in_array(slots, resource)


func _find_slot_in_array(slots: Array, resource: int) -> Dictionary:
	for slot_value in slots:
		var slot: Dictionary = slot_value
		if int(slot["resource"]) == resource:
			return slot
	return {}


func _add_resource_to_slot(slot: Dictionary, amount: int) -> int:
	if slot.is_empty() or amount <= 0:
		return 0
	var capacity := int(slot["capacity"])
	var quantity := int(slot["quantity"])
	var accepted := mini(amount, maxi(0, capacity - quantity))
	slot["quantity"] = quantity + accepted
	return accepted


func _remove_resource(cell: Dictionary, resource: int, amount: int) -> bool:
	var slot: Dictionary = _get_slot(cell, resource)
	if slot.is_empty() or amount <= 0 or int(slot["quantity"]) < amount:
		return false
	slot["quantity"] = int(slot["quantity"]) - amount
	return true


func _has_need_slot(cell: Dictionary) -> bool:
	var slots: Array = cell["slots"] as Array
	for slot_value in slots:
		var slot: Dictionary = slot_value
		if str(slot["role"]) == ROLE_NEED:
			return true
	return false


func _is_myco(cell: Dictionary) -> bool:
	var kind := str(cell.get("kind", KIND_STANDARD))
	return kind == KIND_WHITE_MYCO or kind == KIND_RED_MYCO


func _is_red_myco(cell: Dictionary) -> bool:
	return str(cell.get("kind", KIND_STANDARD)) == KIND_RED_MYCO


func _is_cell_glowing(cell: Dictionary) -> bool:
	return str(cell.get("kind", KIND_STANDARD)) == KIND_WHITE_MYCO or int(cell.get("glow", 0)) > 0


func _cell_can_offer_resource_statically(cell: Dictionary, resource: int) -> bool:
	var slots: Array = cell["slots"] as Array
	for slot_value in slots:
		var slot: Dictionary = slot_value
		if int(slot["resource"]) != resource:
			continue
		if _is_myco(cell) or str(slot["role"]) == ROLE_SOURCE_OUTPUT or int(slot["quantity"]) > 1:
			return true
	var sources: Array = cell["sources"] as Array
	for source_value in sources:
		var source: Dictionary = source_value
		if int(source["resource"]) == resource:
			return true
	return false


func _cell_can_receive_resource_statically(cell: Dictionary, resource: int) -> bool:
	return not _get_slot(cell, resource).is_empty()


func _cell_has_need_resource(cell: Dictionary, resource: int) -> bool:
	var slots: Array = cell["slots"] as Array
	for slot_value in slots:
		var slot: Dictionary = slot_value
		if int(slot["resource"]) == resource and str(slot["role"]) == ROLE_NEED:
			return true
	return false


func _add_normal_offers(resources: Array[int], cell: Dictionary) -> void:
	_add_role_resources(resources, cell["slots"] as Array, ROLE_SOURCE_OUTPUT)
	var sources: Array = cell["sources"] as Array
	for source_value in sources:
		if resources.size() >= MAX_SLOTS:
			return
		var source: Dictionary = source_value
		_add_unique_int(resources, int(source["resource"]))


func _add_role_resources(resources: Array[int], slots: Array, role: String) -> void:
	for slot_value in slots:
		if resources.size() >= MAX_SLOTS:
			return
		var slot: Dictionary = slot_value
		if str(slot["role"]) == role:
			_add_unique_int(resources, int(slot["resource"]))


func _add_slot_resources(resources: Array[int], slots: Array) -> void:
	for slot_value in slots:
		if resources.size() >= MAX_SLOTS:
			return
		var slot: Dictionary = slot_value
		_add_unique_int(resources, int(slot["resource"]))


func _ensure_local_payment_resource(myco: Dictionary, resources: Array[int], local_offers: Array[int], scores: Dictionary) -> void:
	if resources.is_empty() or local_offers.is_empty():
		return
	for resource in resources:
		if local_offers.has(int(resource)):
			return
	var best_offer := int(local_offers[0])
	var best_score := int(scores.get(best_offer, 0))
	for index in range(1, local_offers.size()):
		var offer := int(local_offers[index])
		var score := int(scores.get(offer, 0))
		if score > best_score or (score == best_score and _stable_adaptive_myco_hash(str(myco["id"]), "local-offer", offer, score, index, _topology_version) < _stable_adaptive_myco_hash(str(myco["id"]), "local-offer", best_offer, best_score, 0, _topology_version)):
			best_offer = offer
			best_score = score
	if resources.size() < MAX_SLOTS:
		_add_unique_int(resources, best_offer)
	else:
		resources[resources.size() - 1] = best_offer


func _add_candidate_score(scores: Dictionary, resource: int, score: int) -> void:
	if resource < 0 or score <= 0:
		return
	scores[resource] = int(scores.get(resource, 0)) + score


func _add_unique_int(values: Array[int], value: int) -> void:
	if values.has(value):
		return
	values.append(value)


func _add_unique_string(values: Array[String], value: String) -> void:
	if not values.has(value):
		values.append(value)


func _add_required_cell(cell_id: String) -> void:
	if not _required_cell_ids.has(cell_id):
		_required_cell_ids.append(cell_id)


func _increment_strain(cell: Dictionary, key: String) -> void:
	var strain: Dictionary = cell["strain"]
	strain[key] = int(strain.get(key, 0)) + 1


func _strain_total(cell: Dictionary) -> int:
	var strain: Dictionary = cell["strain"]
	return int(strain.get("unmet", 0)) + int(strain.get("failed", 0)) + int(strain.get("sourceBlocked", 0)) + int(strain.get("overCapacity", 0))


func _total_score() -> int:
	return _reaction_score + _flow_diversity_score + _settlement_score - _strain_penalty


func _add_event(event: Dictionary) -> void:
	_events.append(event)
	while _events.size() > _event_capacity:
		_events.pop_front()


func _position_key(position: Vector2i) -> String:
	return "%d,%d" % [position.x, position.y]


func _in_bounds(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < _width and position.y >= 0 and position.y < _height


func _resource_name(resource: int) -> String:
	if resource >= 0 and resource < _resources.size():
		return _resources[resource]
	return ""


func _produced_resource_name(cell: Dictionary) -> String:
	if _is_myco(cell):
		return ""
	var sources: Array = cell["sources"] as Array
	for source_value in sources:
		var source: Dictionary = source_value
		return _resource_name(int(source["resource"]))
	var slots: Array = cell["slots"] as Array
	for slot_value in slots:
		var slot: Dictionary = slot_value
		if str(slot["role"]) == ROLE_SOURCE_OUTPUT:
			return _resource_name(int(slot["resource"]))
	return ""


func _reserved_key(cell_index: int, resource: int) -> String:
	return "%d:%d" % [cell_index, resource]


func _get_reserved_out(cell_index: int, resource: int) -> int:
	return int(_reserved_out.get(_reserved_key(cell_index, resource), 0))


func _get_reserved_in(cell_index: int, resource: int) -> int:
	return int(_reserved_in.get(_reserved_key(cell_index, resource), 0))


func _add_reserved_out(cell_index: int, resource: int, quantity: int) -> void:
	var key := _reserved_key(cell_index, resource)
	_reserved_out[key] = int(_reserved_out.get(key, 0)) + quantity


func _add_reserved_in(cell_index: int, resource: int, quantity: int) -> void:
	var key := _reserved_key(cell_index, resource)
	_reserved_in[key] = int(_reserved_in.get(key, 0)) + quantity


func _increase_limit(value: int, increase: int) -> int:
	if increase <= 0 or value >= LARGE_RECEIVE_LIMIT:
		return value
	return mini(LARGE_RECEIVE_LIMIT, value + increase)


func _find_parent(parent: Dictionary, node: String) -> String:
	if not parent.has(node):
		parent[node] = node
		return node
	var current := str(parent[node])
	if current == node:
		return node
	var root := _find_parent(parent, current)
	parent[node] = root
	return root


func _union_parent(parent: Dictionary, a: String, b: String) -> void:
	var root_a := _find_parent(parent, a)
	var root_b := _find_parent(parent, b)
	if root_a == root_b:
		return
	if root_a < root_b:
		parent[root_b] = root_a
	else:
		parent[root_a] = root_b


func _parse_kind(value: String) -> String:
	var lower := value.strip_edges().to_lower()
	if lower == "" or lower == "standard":
		return KIND_STANDARD
	if lower == "whitemyco" or lower == "white_myco" or lower == "white-myco":
		return KIND_WHITE_MYCO
	if lower == "redmyco" or lower == "red_myco" or lower == "red-myco":
		return KIND_RED_MYCO
	return ""


func _parse_role(value: String) -> String:
	var lower := value.strip_edges().to_lower()
	if lower == "need":
		return ROLE_NEED
	if lower == "acceptonly" or lower == "accept_only" or lower == "accept-only":
		return ROLE_ACCEPT_ONLY
	if lower == "sourceoutput" or lower == "source_output" or lower == "source-output":
		return ROLE_SOURCE_OUTPUT
	if lower == "catalyst":
		return "Catalyst"
	return ""


func _as_int(value: Variant, default_value: int) -> int:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			var text := str(value)
			if text.is_valid_int():
				return int(text)
			if text.is_valid_float():
				return int(float(text))
	return default_value


func _int_array_from_variant(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item in value as Array:
			result.append(int(item))
	return result


func _compare_cells_stable(left: Dictionary, right: Dictionary) -> int:
	var left_y := int(left["y"])
	var right_y := int(right["y"])
	if left_y != right_y:
		return left_y - right_y
	var left_x := int(left["x"])
	var right_x := int(right["x"])
	if left_x != right_x:
		return left_x - right_x
	var left_id := str(left["id"])
	var right_id := str(right["id"])
	if left_id < right_id:
		return -1
	if left_id > right_id:
		return 1
	return 0


func _compare_edges(left: Dictionary, right: Dictionary) -> bool:
	var left_a: Dictionary = _cells[int(left["a"])]
	var right_a: Dictionary = _cells[int(right["a"])]
	var compare_a := _compare_cells_stable(left_a, right_a)
	if compare_a != 0:
		return compare_a < 0
	var left_b: Dictionary = _cells[int(left["b"])]
	var right_b: Dictionary = _cells[int(right["b"])]
	return _compare_cells_stable(left_b, right_b) < 0


func _compare_prioritized_swap_proposals(left: Dictionary, right: Dictionary) -> bool:
	for key in ["requestedBalance", "sourceReturnRank", "missingNeedRank", "counterpartyNeedBalance", "offeredRoleRank"]:
		var left_value := int(left[key])
		var right_value := int(right[key])
		if left_value != right_value:
			return left_value < right_value
	var left_proposal: Dictionary = left["proposal"]
	var right_proposal: Dictionary = right["proposal"]
	var left_quantity := int(left_proposal["priorityQuantity"])
	var right_quantity := int(right_proposal["priorityQuantity"])
	if left_quantity != right_quantity:
		return left_quantity > right_quantity
	var left_edge := int(left["edgeOrder"])
	var right_edge := int(right["edgeOrder"])
	if left_edge != right_edge:
		return left_edge < right_edge
	var compare_initiator := _compare_cells_stable(_cells[int(left_proposal["initiatorIndex"])], _cells[int(right_proposal["initiatorIndex"])])
	if compare_initiator != 0:
		return compare_initiator < 0
	var compare_counterparty := _compare_cells_stable(_cells[int(left_proposal["counterpartyIndex"])], _cells[int(right_proposal["counterpartyIndex"])])
	if compare_counterparty != 0:
		return compare_counterparty < 0
	var left_paid := int(left_proposal["initiatorPaidResource"])
	var right_paid := int(right_proposal["initiatorPaidResource"])
	if left_paid != right_paid:
		return left_paid < right_paid
	return int(left_proposal["counterpartyPaidResource"]) < int(right_proposal["counterpartyPaidResource"])


func _compare_myco_resource_candidates(left: Dictionary, right: Dictionary) -> bool:
	var left_bucket := int(float(int(left["score"])) / 25.0)
	var right_bucket := int(float(int(right["score"])) / 25.0)
	if left_bucket != right_bucket:
		return left_bucket > right_bucket
	var left_hash := int(left["hash"])
	var right_hash := int(right["hash"])
	if left_hash != right_hash:
		return left_hash < right_hash
	return int(left["resource"]) < int(right["resource"])


func _compare_diagnostic_edges(left: Dictionary, right: Dictionary) -> bool:
	var left_source := str(left["sourceCellId"])
	var right_source := str(right["sourceCellId"])
	if left_source != right_source:
		return left_source < right_source
	return str(left["targetCellId"]) < str(right["targetCellId"])


func _compare_diagnostic_groups(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return left.size() > right.size()
	var left_first := "" if left.is_empty() else str(left[0])
	var right_first := "" if right.is_empty() else str(right[0])
	return left_first < right_first


func _hash_adaptive_myco_resource_set(myco_id: String, resources: Array[int], score: int, topology_version: int) -> int:
	var hash := 2166136261
	hash = _hash_string(hash, myco_id)
	hash = _hash_int(hash, score)
	hash = _hash_int(hash, topology_version)
	for index in range(resources.size()):
		hash = _hash_int(hash, int(resources[index]))
		hash = _hash_int(hash, index)
	return hash & 0x7fffffff


func _stable_adaptive_myco_hash(myco_id: String, neighbor_id: String, resource: int, neighbor_order: int, slot_order: int, topology_version: int) -> int:
	var hash := 2166136261
	hash = _hash_string(hash, myco_id)
	hash = _hash_string(hash, neighbor_id)
	hash = _hash_int(hash, resource)
	hash = _hash_int(hash, neighbor_order)
	hash = _hash_int(hash, slot_order)
	hash = _hash_int(hash, topology_version)
	return hash & 0x7fffffff


func _hash_string(hash: int, value: String) -> int:
	var result := hash
	for index in range(value.length()):
		result = _hash_int(result, value.unicode_at(index))
	return result


func _hash_int(hash: int, value: int) -> int:
	return int(((hash ^ value) * 16777619) & 0xffffffff)
