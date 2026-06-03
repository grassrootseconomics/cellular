extends Control

const TITLE_COMPACT_SHORT_EDGE := 640.0
const TITLE_TINY_SHORT_EDGE := 500.0
const GE_LOGO_PATH := "res://graphics/ge-logo-horizontal-text.png"
const TITLE_CELLULAR_BACKGROUND_PATH := "res://graphics/cellular-lapace.png"
const TITLE_SCORE_STAR_COUNT := 12
const TITLE_CELL_RENDERER_PATH := "res://src/CellularBoardRenderer.cs"
const TITLE_CELL_RENDERER_Z := 42
const TITLE_CELL_ENTER_DURATION := 2.15
const TITLE_CELL_SPAWN_DELAY := 0.17
const TITLE_CELL_IDLE_START := 2.45
const TITLE_CELL_VISUAL_SCALE := 1.44
const TITLE_CELL_FINAL_IDS := [
	"title-c",
	"title-e",
	"title-l-1",
	"title-l-2",
	"title-u",
	"title-l-3",
	"title-a",
	"title-r"
]
const TITLE_CELL_SPAWN_IDS := [
	"title-r",
	"title-a",
	"title-l-3",
	"title-u",
	"title-l-2",
	"title-l-1",
	"title-e",
	"title-c"
]
const TITLE_CELL_LETTERS := {
	"title-c": "C",
	"title-e": "E",
	"title-l-1": "L",
	"title-l-2": "L",
	"title-u": "U",
	"title-l-3": "L",
	"title-a": "A",
	"title-r": "R"
}
const TITLE_SAFE_EDGE_MARGIN_DEFAULT := 12.0
const TITLE_SAFE_EDGE_MARGIN_COMPACT := 10.0
const TITLE_SAFE_EDGE_MARGIN_TINY := 8.0
const TITLE_MOBILE_SAFE_TOP_FALLBACK_MIN := 52.0
const TITLE_MOBILE_SAFE_TOP_FALLBACK_MAX := 88.0
const TITLE_MOBILE_SAFE_SIDE_FALLBACK_PORTRAIT_MIN := 18.0
const TITLE_MOBILE_SAFE_SIDE_FALLBACK_PORTRAIT_MAX := 42.0
const TITLE_MOBILE_SAFE_SIDE_FALLBACK_LANDSCAPE_MIN := 48.0
const TITLE_MOBILE_SAFE_SIDE_FALLBACK_LANDSCAPE_MAX := 76.0
const TITLE_MOBILE_SAFE_BOTTOM_FALLBACK_MIN := 18.0
const TITLE_MOBILE_SAFE_BOTTOM_FALLBACK_MAX := 40.0


class TiledTitleBackground:
	extends Control

	var title_texture: Texture2D = null

	func set_title_texture(texture: Texture2D) -> void:
		title_texture = texture
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(title_texture):
			return
		var tile_size := title_texture.get_size()
		tile_size.x = maxf(tile_size.x, 1.0)
		tile_size.y = maxf(tile_size.y, 1.0)
		var cols := int(ceil(size.x / tile_size.x)) + 1
		var rows := int(ceil(size.y / tile_size.y)) + 1
		for y in range(rows):
			for x in range(cols):
				draw_texture(title_texture, Vector2(tile_size.x * x, tile_size.y * y))


var _ge_logo_texture: Texture2D = null
var _title_soil_background: TiledTitleBackground = null
var _title_art_background: TextureRect = null
var _title_pending_layout_frames := 0
var _last_score_label: Label = null
var _high_score_label: Label = null
var _last_score_panel: Panel = null
var _high_score_panel: Panel = null
var _title_score_star_layer: Control = null
var _title_score_stars: Array[Label] = []
var _title_score_sparkle_target: Label = null
var _title_score_sparkle_time := 0.0
var _title_cell_renderer: Control = null
var _title_cell_animation_time := 0.0
var _title_quit_button: Button = null
var _title_quit_requested := false
var _puzzle_progress_label: Label = null
var _puzzle_reset_button: Button = null
var _puzzle_reset_confirm_overlay: Control = null
var _puzzle_reset_confirm_scrim: ColorRect = null
var _puzzle_reset_confirm_panel: Panel = null
var _puzzle_reset_confirm_title: Label = null
var _puzzle_reset_confirm_message: Label = null
var _puzzle_reset_confirm_close_button: Button = null
var _puzzle_reset_confirm_yes_button: Button = null
var _puzzle_reset_confirm_no_button: Button = null
var _arcade_high_score_label: Label = null


func _get_ge_logo_texture() -> Texture2D:
	if is_instance_valid(_ge_logo_texture):
		return _ge_logo_texture
	var texture: Resource = load(GE_LOGO_PATH)
	if not texture is Texture2D:
		return null
	_ge_logo_texture = texture as Texture2D
	return _ge_logo_texture

func _make_cta_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 5
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _make_ge_logo_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.97)
	style.border_color = Color(0.88, 0.82, 0.64, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_title_score_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.16, 0.09, 0.58)
	style.border_color = Color(1.0, 0.86, 0.32, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_title_menu_stat_label_style() -> StyleBoxFlat:
	var style := _make_title_score_panel_style()
	style.bg_color = Color(0.035, 0.105, 0.075, 0.78)
	style.border_color = Color(1.0, 0.86, 0.32, 0.84)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	return style


func _make_title_confirm_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.065, 0.96)
	style.border_color = Color(0.34, 0.92, 0.86, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_title_confirm_button_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _style_cta_button(button: Button, base_bg: Color, base_border: Color) -> void:
	if not is_instance_valid(button):
		return
	button.custom_minimum_size = Vector2(340, 78)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 46)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))

	var hover_bg = base_bg.lightened(0.12)
	var pressed_bg = base_bg.darkened(0.15)
	var focus_border = Color(1, 1, 1, 0.95)

	button.add_theme_stylebox_override("normal", _make_cta_style(base_bg, base_border, 2))
	button.add_theme_stylebox_override("hover", _make_cta_style(hover_bg, base_border, 3))
	button.add_theme_stylebox_override("pressed", _make_cta_style(pressed_bg, base_border, 2))
	button.add_theme_stylebox_override("focus", _make_cta_style(hover_bg, focus_border, 4))
	button.add_theme_stylebox_override("disabled", _make_cta_style(base_bg.darkened(0.35), base_border.darkened(0.4), 2))


func _style_title_quit_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.88, 1.0))
	var base_bg := Color(0.42, 0.06, 0.05, 0.94)
	var base_border := Color(1.0, 0.42, 0.36, 0.86)
	button.add_theme_stylebox_override("normal", _make_cta_style(base_bg, base_border, 2))
	button.add_theme_stylebox_override("hover", _make_cta_style(base_bg.lightened(0.12), Color(1.0, 0.62, 0.54, 1.0), 3))
	button.add_theme_stylebox_override("pressed", _make_cta_style(base_bg.darkened(0.2), Color(0.82, 0.28, 0.24, 1.0), 2))
	button.add_theme_stylebox_override("focus", _make_cta_style(base_bg.lightened(0.12), Color(1, 1, 1, 0.95), 4))


func _style_title_secondary_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.92, 1.0, 0.96, 1.0))
	var base_bg := Color(0.08, 0.22, 0.24, 0.92)
	var base_border := Color(0.48, 0.86, 0.78, 0.86)
	button.add_theme_stylebox_override("normal", _make_cta_style(base_bg, base_border, 2))
	button.add_theme_stylebox_override("hover", _make_cta_style(base_bg.lightened(0.12), Color(0.68, 1.0, 0.92, 1.0), 3))
	button.add_theme_stylebox_override("pressed", _make_cta_style(base_bg.darkened(0.18), Color(0.32, 0.66, 0.60, 1.0), 2))
	button.add_theme_stylebox_override("focus", _make_cta_style(base_bg.lightened(0.12), Color(1, 1, 1, 0.95), 4))


func _style_title_confirm_button(button: Button, destructive: bool) -> void:
	if not is_instance_valid(button):
		return
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.92, 1.0, 0.96, 1.0))
	var base_bg := Color(0.08, 0.22, 0.24, 0.94)
	var base_border := Color(0.48, 0.86, 0.78, 0.88)
	if destructive:
		base_bg = Color(0.46, 0.08, 0.06, 0.95)
		base_border = Color(1.0, 0.55, 0.45, 0.92)
	button.add_theme_stylebox_override("normal", _make_title_confirm_button_style(base_bg, base_border, 2))
	button.add_theme_stylebox_override("hover", _make_title_confirm_button_style(base_bg.lightened(0.12), base_border.lightened(0.10), 3))
	button.add_theme_stylebox_override("pressed", _make_title_confirm_button_style(base_bg.darkened(0.18), base_border.darkened(0.12), 2))
	button.add_theme_stylebox_override("focus", _make_title_confirm_button_style(base_bg.lightened(0.12), Color(1, 1, 1, 0.95), 4))


func _style_title_info_label(label: Label, font_size: int) -> void:
	if not is_instance_valid(label):
		return
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.94, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.05, 0.92))
	label.add_theme_constant_override("outline_size", 3)


func _style_title_menu_stat_label(label: Label, font_size: int) -> void:
	if not is_instance_valid(label):
		return
	_style_title_info_label(label, font_size)
	label.add_theme_stylebox_override("normal", _make_title_menu_stat_label_style())
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.64, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.025, 0.08, 0.035, 0.98))
	label.add_theme_constant_override("outline_size", 3)
	label.custom_minimum_size.y = maxf(label.custom_minimum_size.y, 28.0)


func _hide_title_menu_stat_label(label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2.ZERO


func _show_title_menu_stat_label(label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.visible = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(180.0, 26.0)


func _get_title_menu_box() -> VBoxContainer:
	return get_node_or_null("CenterContainer/VBoxContainer") as VBoxContainer


func _ensure_cellular_title_widgets() -> void:
	var menu_box := _get_title_menu_box()
	if not is_instance_valid(menu_box):
		return
	if not is_instance_valid(_puzzle_progress_label):
		_puzzle_progress_label = menu_box.get_node_or_null("PuzzleProgressLabel") as Label
	if not is_instance_valid(_puzzle_progress_label):
		_puzzle_progress_label = Label.new()
		_puzzle_progress_label.name = "PuzzleProgressLabel"
		menu_box.add_child(_puzzle_progress_label)
	_show_title_menu_stat_label(_puzzle_progress_label)
	if not is_instance_valid(_puzzle_reset_button):
		_puzzle_reset_button = menu_box.get_node_or_null("ResetPuzzleButton") as Button
	if not is_instance_valid(_puzzle_reset_button):
		_puzzle_reset_button = Button.new()
		_puzzle_reset_button.name = "ResetPuzzleButton"
		menu_box.add_child(_puzzle_reset_button)
	if not _puzzle_reset_button.pressed.is_connected(_on_reset_puzzle_progress_pressed):
		_puzzle_reset_button.pressed.connect(_on_reset_puzzle_progress_pressed)
	_ensure_puzzle_reset_confirm_panel()
	if not is_instance_valid(_arcade_high_score_label):
		_arcade_high_score_label = menu_box.get_node_or_null("ArcadeHighScoreLabel") as Label
	if not is_instance_valid(_arcade_high_score_label):
		_arcade_high_score_label = Label.new()
		_arcade_high_score_label.name = "ArcadeHighScoreLabel"
		menu_box.add_child(_arcade_high_score_label)
	_show_title_menu_stat_label(_arcade_high_score_label)
	var ordered_names := [
		"RegenerationLabel",
		"Tutorial",
		"PuzzleProgressLabel",
		"ChallengeButton",
		"ArcadeHighScoreLabel",
		"LinkButton",
		"ResetPuzzleButton"
	]
	for index in range(ordered_names.size()):
		var child := menu_box.get_node_or_null(ordered_names[index])
		if is_instance_valid(child):
			menu_box.move_child(child, index)
	_puzzle_reset_button.text = "Reset Progress"
	_style_title_secondary_button(_puzzle_reset_button)
	_refresh_cellular_title_stats()


func _ensure_puzzle_reset_confirm_panel() -> void:
	if is_instance_valid(_puzzle_reset_confirm_overlay):
		return
	_puzzle_reset_confirm_overlay = Control.new()
	_puzzle_reset_confirm_overlay.name = "ResetPuzzleProgressConfirmOverlay"
	_puzzle_reset_confirm_overlay.visible = false
	_puzzle_reset_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_puzzle_reset_confirm_overlay.z_as_relative = false
	_puzzle_reset_confirm_overlay.z_index = 95
	add_child(_puzzle_reset_confirm_overlay)

	_puzzle_reset_confirm_scrim = ColorRect.new()
	_puzzle_reset_confirm_scrim.name = "ResetPuzzleProgressScrim"
	_puzzle_reset_confirm_scrim.color = Color(0.0, 0.0, 0.0, 0.54)
	_puzzle_reset_confirm_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_puzzle_reset_confirm_overlay.add_child(_puzzle_reset_confirm_scrim)

	_puzzle_reset_confirm_panel = Panel.new()
	_puzzle_reset_confirm_panel.name = "ResetPuzzleProgressPanel"
	_puzzle_reset_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_puzzle_reset_confirm_overlay.add_child(_puzzle_reset_confirm_panel)

	_puzzle_reset_confirm_title = Label.new()
	_puzzle_reset_confirm_title.name = "ResetPuzzleProgressTitle"
	_puzzle_reset_confirm_title.text = "Restart Puzzle Progress"
	_puzzle_reset_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_puzzle_reset_confirm_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_puzzle_reset_confirm_panel.add_child(_puzzle_reset_confirm_title)

	_puzzle_reset_confirm_message = Label.new()
	_puzzle_reset_confirm_message.name = "ResetPuzzleProgressMessage"
	_puzzle_reset_confirm_message.text = "Are you sure you want to restart? This will reset all your scores also."
	_puzzle_reset_confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_puzzle_reset_confirm_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_puzzle_reset_confirm_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_puzzle_reset_confirm_panel.add_child(_puzzle_reset_confirm_message)

	_puzzle_reset_confirm_close_button = Button.new()
	_puzzle_reset_confirm_close_button.name = "ResetPuzzleProgressCloseButton"
	_puzzle_reset_confirm_close_button.text = "x"
	_puzzle_reset_confirm_close_button.pressed.connect(_hide_puzzle_reset_confirm_panel)
	_puzzle_reset_confirm_panel.add_child(_puzzle_reset_confirm_close_button)

	_puzzle_reset_confirm_yes_button = Button.new()
	_puzzle_reset_confirm_yes_button.name = "ResetPuzzleProgressYesButton"
	_puzzle_reset_confirm_yes_button.text = "Yes"
	_puzzle_reset_confirm_yes_button.pressed.connect(_on_reset_puzzle_progress_confirmed)
	_puzzle_reset_confirm_panel.add_child(_puzzle_reset_confirm_yes_button)

	_puzzle_reset_confirm_no_button = Button.new()
	_puzzle_reset_confirm_no_button.name = "ResetPuzzleProgressNoButton"
	_puzzle_reset_confirm_no_button.text = "No"
	_puzzle_reset_confirm_no_button.pressed.connect(_hide_puzzle_reset_confirm_panel)
	_puzzle_reset_confirm_panel.add_child(_puzzle_reset_confirm_no_button)


func _layout_puzzle_reset_confirm_panel(safe_rect: Rect2, compact: bool, tiny: bool) -> void:
	if not is_instance_valid(_puzzle_reset_confirm_overlay):
		return
	var view_size := get_viewport_rect().size
	_puzzle_reset_confirm_overlay.position = Vector2.ZERO
	_puzzle_reset_confirm_overlay.size = view_size
	if is_instance_valid(_puzzle_reset_confirm_scrim):
		_puzzle_reset_confirm_scrim.position = Vector2.ZERO
		_puzzle_reset_confirm_scrim.size = view_size
	if not is_instance_valid(_puzzle_reset_confirm_panel):
		return
	var panel_width: float = clampf(safe_rect.size.x - 28.0, minf(280.0, safe_rect.size.x), minf(500.0, maxf(280.0, safe_rect.size.x)))
	var panel_height: float = 212.0
	if compact:
		panel_height = 198.0
	if tiny:
		panel_height = 184.0
	var panel_size := Vector2(panel_width, minf(panel_height, maxf(150.0, safe_rect.size.y - 24.0)))
	var panel_pos := safe_rect.get_center() - panel_size * 0.5
	panel_pos = _clamp_title_control_position_to_rect(panel_pos, panel_size, safe_rect)
	_puzzle_reset_confirm_panel.position = Vector2(round(panel_pos.x), round(panel_pos.y))
	_puzzle_reset_confirm_panel.size = Vector2(round(panel_size.x), round(panel_size.y))
	_puzzle_reset_confirm_panel.add_theme_stylebox_override("panel", _make_title_confirm_panel_style())

	var pad: float = 18.0 if not tiny else 14.0
	var title_h: float = 34.0
	var button_h: float = 44.0
	var button_w: float = minf(112.0, maxf(84.0, (panel_size.x - pad * 2.0 - 12.0) * 0.5))
	if is_instance_valid(_puzzle_reset_confirm_title):
		_puzzle_reset_confirm_title.position = Vector2(pad, pad - 1.0)
		_puzzle_reset_confirm_title.size = Vector2(maxf(1.0, panel_size.x - pad * 2.0 - 42.0), title_h)
		_style_title_info_label(_puzzle_reset_confirm_title, 23 if not compact else (21 if not tiny else 19))
		_puzzle_reset_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if is_instance_valid(_puzzle_reset_confirm_close_button):
		_puzzle_reset_confirm_close_button.position = Vector2(panel_size.x - pad - 32.0, pad - 2.0)
		_puzzle_reset_confirm_close_button.size = Vector2(32.0, 32.0)
		_style_title_confirm_button(_puzzle_reset_confirm_close_button, false)
		_puzzle_reset_confirm_close_button.add_theme_font_size_override("font_size", 20)
	if is_instance_valid(_puzzle_reset_confirm_message):
		var message_y: float = pad + title_h + 6.0
		var button_y: float = panel_size.y - pad - button_h
		_puzzle_reset_confirm_message.position = Vector2(pad, message_y)
		_puzzle_reset_confirm_message.size = Vector2(panel_size.x - pad * 2.0, maxf(48.0, button_y - message_y - 12.0))
		_style_title_info_label(_puzzle_reset_confirm_message, 18 if not compact else (17 if not tiny else 15))
		_puzzle_reset_confirm_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_puzzle_reset_confirm_message.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if is_instance_valid(_puzzle_reset_confirm_yes_button) and is_instance_valid(_puzzle_reset_confirm_no_button):
		var buttons_width: float = button_w * 2.0 + 12.0
		var button_y: float = panel_size.y - pad - button_h
		var button_x: float = round((panel_size.x - buttons_width) * 0.5)
		_puzzle_reset_confirm_yes_button.position = Vector2(button_x, button_y)
		_puzzle_reset_confirm_yes_button.size = Vector2(button_w, button_h)
		_puzzle_reset_confirm_no_button.position = Vector2(button_x + button_w + 12.0, button_y)
		_puzzle_reset_confirm_no_button.size = Vector2(button_w, button_h)
		_style_title_confirm_button(_puzzle_reset_confirm_yes_button, true)
		_style_title_confirm_button(_puzzle_reset_confirm_no_button, false)


func _hide_puzzle_reset_confirm_panel() -> void:
	if is_instance_valid(_puzzle_reset_confirm_overlay):
		_puzzle_reset_confirm_overlay.visible = false


func _title_puzzle_flow_text() -> String:
	var highest_puzzle_level := clampi(maxi(1, Global.cellular_puzzle_highest_level), 1, Global.CELLULAR_PUZZLE_FINAL_LEVEL)
	var highest_level_flow := 0
	if Global.has_method("get_cellular_puzzle_level_high_velocity"):
		highest_level_flow = int(Global.get_cellular_puzzle_level_high_velocity(highest_puzzle_level))
	return str("Highest Puzzle Level: ", highest_puzzle_level, " (Flow ", Global.format_score_value(highest_level_flow), ")")


func _title_arcade_cells_cleared_text() -> String:
	return str("Most Cells Cleared: ", Global.format_score_value(Global.high_score))


func _refresh_cellular_title_stats() -> void:
	var puzzle_progress_text := _title_puzzle_flow_text()
	var arcade_high_score_text := _title_arcade_cells_cleared_text()
	if is_instance_valid(_puzzle_progress_label):
		_puzzle_progress_label.text = puzzle_progress_text
	if is_instance_valid(_arcade_high_score_label):
		_arcade_high_score_label.text = arcade_high_score_text
	if is_instance_valid(_last_score_label):
		_last_score_label.text = puzzle_progress_text
	if is_instance_valid(_high_score_label):
		_high_score_label.text = arcade_high_score_text


func _ensure_title_quit_button() -> Button:
	if is_instance_valid(_title_quit_button):
		return _title_quit_button
	_title_quit_button = get_node_or_null("QuitGameButton") as Button
	if not is_instance_valid(_title_quit_button):
		_title_quit_button = get_node_or_null("CenterContainer/VBoxContainer/QuitGameButton") as Button
	if is_instance_valid(_title_quit_button) and _title_quit_button.get_parent() != self:
		var old_parent: Node = _title_quit_button.get_parent()
		if is_instance_valid(old_parent):
			old_parent.remove_child(_title_quit_button)
		add_child(_title_quit_button)
	if not is_instance_valid(_title_quit_button):
		_title_quit_button = Button.new()
		_title_quit_button.name = "QuitGameButton"
		add_child(_title_quit_button)
	_title_quit_button.text = "Quit Game"
	_title_quit_button.z_as_relative = false
	_title_quit_button.z_index = 70
	if not _title_quit_button.pressed.is_connected(_on_quit_game_pressed):
		_title_quit_button.pressed.connect(_on_quit_game_pressed)
	return _title_quit_button


func _setup_primary_buttons() -> void:
	var story_button: Button = $CenterContainer/VBoxContainer/Tutorial
	var challenge_button: Button = $CenterContainer/VBoxContainer/ChallengeButton
	story_button.text = "Puzzle"
	challenge_button.text = "Arcade"
	_ensure_cellular_title_widgets()
	_style_cta_button(story_button, Color(0.13, 0.42, 0.46, 0.95), Color(0.70, 0.98, 0.95, 1.0))
	_style_cta_button(challenge_button, Color(0.68, 0.30, 0.18, 0.95), Color(1.0, 0.76, 0.48, 1.0))
	_style_title_quit_button(_ensure_title_quit_button())


func _setup_version_label() -> void:
	var version_label: Label = $VersionLabel
	if not is_instance_valid(version_label):
		return
	var version_text = str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if version_text.is_empty():
		version_label.visible = false
		return
	version_label.visible = true
	if not version_text.begins_with("v"):
		version_text = "v" + version_text
	version_label.text = version_text
	version_label.add_theme_color_override("font_color", Color(0.08, 0.16, 0.1, 0.86))
	version_label.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.84, 0.7))
	version_label.add_theme_constant_override("outline_size", 2)


func _style_title_score_label(label: Label, font_size: int) -> void:
	if not is_instance_valid(label):
		return
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.34, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.025, 0.08, 0.035, 0.98))
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.02, 0.01, 0.45))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)


func _ensure_title_score_widgets() -> void:
	if not is_instance_valid(_last_score_panel):
		_last_score_panel = Panel.new()
		_last_score_panel.name = "LastScorePanel"
		_last_score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_last_score_panel.z_as_relative = false
		_last_score_panel.z_index = 34
		add_child(_last_score_panel)
	if not is_instance_valid(_last_score_label):
		_last_score_label = Label.new()
		_last_score_label.name = "LastScoreLabel"
		_last_score_label.z_as_relative = false
		_last_score_label.z_index = 35
		add_child(_last_score_label)
	if not is_instance_valid(_high_score_panel):
		_high_score_panel = Panel.new()
		_high_score_panel.name = "TitleHighScorePanel"
		_high_score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_high_score_panel.z_as_relative = false
		_high_score_panel.z_index = 34
		add_child(_high_score_panel)
	if not is_instance_valid(_high_score_label):
		_high_score_label = Label.new()
		_high_score_label.name = "TitleHighScoreLabel"
		_high_score_label.z_as_relative = false
		_high_score_label.z_index = 35
		add_child(_high_score_label)
	if not is_instance_valid(_title_score_star_layer):
		_title_score_star_layer = Control.new()
		_title_score_star_layer.name = "TitleScoreStars"
		_title_score_star_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_score_star_layer.z_as_relative = false
		_title_score_star_layer.z_index = 38
		add_child(_title_score_star_layer)
	while _title_score_stars.size() < TITLE_SCORE_STAR_COUNT:
		var star := Label.new()
		star.name = str("ScoreStar", _title_score_stars.size())
		star.text = "*"
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.custom_minimum_size = Vector2(24, 24)
		star.size = Vector2(24, 24)
		star.add_theme_font_size_override("font_size", 24)
		star.add_theme_color_override("font_color", Color(1.0, 0.92, 0.20, 1.0))
		star.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.0, 1.0))
		star.add_theme_constant_override("outline_size", 3)
		_title_score_star_layer.add_child(star)
		_title_score_stars.append(star)


func _get_last_rank_text() -> String:
	var rank_key = int(Global.last_rank_key)
	if not Global.ranks.has(rank_key):
		rank_key = Global.get_rank_threshold(Global.last_score)
	return str(Global.ranks.get(rank_key, "Sporeling"))


func _layout_title_score_panel(panel: Panel, label: Label, visible: bool) -> void:
	if not is_instance_valid(panel):
		return
	panel.visible = visible and is_instance_valid(label)
	if not panel.visible:
		return
	panel.add_theme_stylebox_override("panel", _make_title_score_panel_style())
	var label_rect = Rect2(label.position, label.size)
	panel.position = Vector2(label_rect.position.x - 10.0, label_rect.position.y - 6.0)
	panel.size = Vector2(label_rect.size.x + 20.0, label_rect.size.y + 12.0)


func _get_title_menu_column_rect(view_size: Vector2, fallback_width: float) -> Rect2:
	var column_center_x: float = view_size.x * 0.5
	var center_container := get_node_or_null("CenterContainer") as Control
	if is_instance_valid(center_container):
		var center_rect: Rect2 = center_container.get_global_rect()
		if center_rect.size.x > 1.0:
			column_center_x = center_rect.get_center().x
	for button_path in ["CenterContainer/VBoxContainer/Tutorial", "CenterContainer/VBoxContainer/ChallengeButton"]:
		var button := get_node_or_null(button_path) as Button
		if not is_instance_valid(button) or not button.visible:
			continue
		var button_rect: Rect2 = button.get_global_rect()
		if button_rect.size.x > 1.0:
			return Rect2(Vector2(round(column_center_x - button_rect.size.x * 0.5), button_rect.position.y), button_rect.size)
	var menu_box := get_node_or_null("CenterContainer/VBoxContainer") as Control
	if is_instance_valid(menu_box):
		var menu_rect: Rect2 = menu_box.get_global_rect()
		if menu_rect.size.x > 1.0:
			return Rect2(Vector2(round(column_center_x - menu_rect.size.x * 0.5), menu_rect.position.y), menu_rect.size)
	return Rect2(Vector2(round(column_center_x - fallback_width * 0.5), 0.0), Vector2(fallback_width, 0.0))


func _update_title_score_widgets(view_size: Vector2, compact: bool, tiny: bool) -> void:
	_ensure_title_score_widgets()
	if is_instance_valid(_last_score_label):
		_last_score_label.visible = false
	if is_instance_valid(_high_score_label):
		_high_score_label.visible = false
	_layout_title_score_panel(_last_score_panel, _last_score_label, false)
	_layout_title_score_panel(_high_score_panel, _high_score_label, false)
	_title_score_sparkle_target = null
	if int(Global.high_score) > 0 and is_instance_valid(_arcade_high_score_label):
		_title_score_sparkle_target = _arcade_high_score_label
	elif is_instance_valid(_puzzle_progress_label):
		_title_score_sparkle_target = _puzzle_progress_label
	_update_title_score_sparkles(0.0)


func _update_title_score_sparkles(delta: float) -> void:
	_title_score_sparkle_time += maxf(delta, 0.0)
	var show_stars = is_instance_valid(_title_score_sparkle_target) and _title_score_sparkle_target.visible
	if is_instance_valid(_title_score_star_layer):
		_title_score_star_layer.visible = show_stars
	if not show_stars:
		for star in _title_score_stars:
			if is_instance_valid(star):
				star.visible = false
		return
	var target_rect = _title_score_sparkle_target.get_global_rect()
	var center = target_rect.get_center()
	var radius_x = target_rect.size.x * 0.52 + 14.0
	var radius_y = target_rect.size.y * 0.50 + 10.0
	for idx in range(_title_score_stars.size()):
		var star = _title_score_stars[idx]
		if not is_instance_valid(star):
			continue
		var phase = (idx * TAU) / max(TITLE_SCORE_STAR_COUNT, 1)
		var shimmer = 0.5 + 0.5 * sin(_title_score_sparkle_time * 4.2 + idx * 0.91)
		var orbit = phase + sin(_title_score_sparkle_time * 0.9 + idx) * 0.08
		star.visible = true
		star.modulate.a = 0.38 + shimmer * 0.62
		star.scale = Vector2.ONE * (0.82 + shimmer * 0.36)
		star.position = center + Vector2(cos(orbit) * radius_x, sin(orbit) * radius_y) - star.size * 0.5


func _ensure_title_cell_renderer() -> void:
	if is_instance_valid(_title_cell_renderer):
		return
	if not ResourceLoader.exists(TITLE_CELL_RENDERER_PATH):
		return
	var renderer_script: Resource = load(TITLE_CELL_RENDERER_PATH)
	if renderer_script == null or not renderer_script is Script:
		return
	var instance: Variant = (renderer_script as Script).new()
	if not instance is Control:
		return
	_title_cell_renderer = instance as Control
	_title_cell_renderer.name = "TitleCellWordRenderer"
	_title_cell_renderer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_cell_renderer.z_as_relative = false
	_title_cell_renderer.z_index = TITLE_CELL_RENDERER_Z
	_title_cell_renderer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_cell_renderer.offset_left = 0.0
	_title_cell_renderer.offset_top = 0.0
	_title_cell_renderer.offset_right = 0.0
	_title_cell_renderer.offset_bottom = 0.0
	add_child(_title_cell_renderer)


func _get_title_cell_rect() -> Rect2:
	var title_label: Label = $CenterContainer/VBoxContainer/RegenerationLabel
	if is_instance_valid(title_label):
		var rect := title_label.get_global_rect()
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			return rect
	var view_size := get_viewport_rect().size
	return Rect2(Vector2(view_size.x * 0.5 - 340.0, view_size.y * 0.12), Vector2(680.0, 120.0))


func _title_cell_letter(cell_id: String) -> String:
	return str(TITLE_CELL_LETTERS.get(cell_id, ""))


func _title_cell_spawn_index(cell_id: String) -> int:
	return maxi(TITLE_CELL_SPAWN_IDS.find(cell_id), 0)


func _title_cell_final_index(cell_id: String) -> int:
	return maxi(TITLE_CELL_FINAL_IDS.find(cell_id), 0)


func _title_cell_tile_size(title_rect: Rect2) -> float:
	var width_limited := title_rect.size.x / 9.7
	var height_limited := title_rect.size.y / 1.42
	return clampf(minf(width_limited, height_limited), 32.0, 84.0)


func _title_ease_sine(t: float) -> float:
	return 0.5 - 0.5 * cos(clampf(t, 0.0, 1.0) * PI)


func _title_cell_position(cell_id: String, title_rect: Rect2, tile_size: float) -> Vector2:
	var final_index := _title_cell_final_index(cell_id)
	var spawn_index := _title_cell_spawn_index(cell_id)
	var spacing := tile_size * 0.82
	var row_width := spacing * float(TITLE_CELL_FINAL_IDS.size() - 1)
	var target := Vector2(
		title_rect.get_center().x - row_width * 0.5 + float(final_index) * spacing,
		title_rect.get_center().y + tile_size * 0.02
	)
	var delay := float(spawn_index) * TITLE_CELL_SPAWN_DELAY
	var local_time := _title_cell_animation_time - delay
	var start := Vector2(
		-tile_size * (1.45 + float(spawn_index) * 0.32),
		target.y + sin(float(spawn_index) * 1.37) * tile_size * 0.18
	)
	if local_time <= 0.0:
		return start
	var t := clampf(local_time / TITLE_CELL_ENTER_DURATION, 0.0, 1.0)
	if t < 1.0:
		var remaining := 1.0 - t
		var pos := target - (target - start) * remaining * remaining * remaining
		pos.x += sin(t * PI * 3.6 + float(spawn_index) * 0.18) * tile_size * 0.24 * remaining
		pos.y += sin(t * PI * 2.1 + float(spawn_index) * 0.63) * tile_size * 0.11 * remaining
		return pos
	var settle_time := local_time - TITLE_CELL_ENTER_DURATION
	var collision := sin(settle_time * 7.8 + float(final_index) * 0.82) * exp(-settle_time * 1.65) * tile_size * 0.10
	var idle_time := maxf(local_time - TITLE_CELL_IDLE_START, 0.0)
	var idle := sin(idle_time * 1.85 + float(final_index) * 0.57) * tile_size * 0.016
	return target + Vector2(collision + idle, sin(idle_time * 1.35 + float(final_index)) * tile_size * 0.010)


func _title_cell_scale(cell_id: String) -> float:
	var spawn_index := _title_cell_spawn_index(cell_id)
	var local_time := _title_cell_animation_time - float(spawn_index) * TITLE_CELL_SPAWN_DELAY
	var appear := clampf(local_time / 0.45, 0.0, 1.0)
	var settle := maxf(local_time - TITLE_CELL_ENTER_DURATION, 0.0)
	var bounce := sin(settle * 8.0 + float(_title_cell_final_index(cell_id))) * exp(-settle * 1.8) * 0.045
	var idle := sin(maxf(local_time - TITLE_CELL_IDLE_START, 0.0) * 1.9 + float(spawn_index)) * 0.020
	return ((0.78 + appear * 0.22) + bounce + idle) * TITLE_CELL_VISUAL_SCALE


func _title_partner_for_need(cell_id: String, need: String) -> String:
	var own_index := _title_cell_final_index(cell_id)
	var best_id := ""
	var best_distance := 999
	for other_id in TITLE_CELL_FINAL_IDS:
		if other_id == cell_id or _title_cell_letter(other_id) != need:
			continue
		var distance: int = absi(_title_cell_final_index(other_id) - own_index)
		if distance < best_distance:
			best_distance = distance
			best_id = other_id
	return best_id


func _title_cell_needs(cell_id: String) -> Array[String]:
	var own_letter := _title_cell_letter(cell_id)
	var own_index := _title_cell_final_index(cell_id)
	var candidate_ids: Array[String] = []
	for offset in [-1, 1, -2, 2, -3, 3]:
		var index := own_index + int(offset)
		if index >= 0 and index < TITLE_CELL_FINAL_IDS.size():
			candidate_ids.append(str(TITLE_CELL_FINAL_IDS[index]))
	var needs: Array[String] = []
	for candidate_id in candidate_ids:
		var letter := _title_cell_letter(candidate_id)
		if letter == "" or letter == own_letter or needs.has(letter):
			continue
		needs.append(letter)
		if needs.size() >= 3:
			return needs
	for letter in ["C", "E", "L", "U", "A", "R"]:
		if letter == own_letter or needs.has(letter):
			continue
		needs.append(letter)
		if needs.size() >= 3:
			return needs
	return needs


func _sync_title_cell_renderer() -> void:
	_ensure_title_cell_renderer()
	if not is_instance_valid(_title_cell_renderer) or not _title_cell_renderer.has_method("set_render_state"):
		return
	var title_rect := _get_title_cell_rect()
	var tile_size := _title_cell_tile_size(title_rect)
	var view_rect := get_viewport_rect()
	var cells: Array[String] = []
	var centers := {}
	var scales := {}
	var produced := {}
	var kinds := {}
	var needs := {}
	var preferred := {}
	for cell_id in TITLE_CELL_FINAL_IDS:
		var id := str(cell_id)
		cells.append(id)
		centers[id] = _title_cell_position(id, title_rect, tile_size)
		scales[id] = _title_cell_scale(id)
		produced[id] = _title_cell_letter(id)
		kinds[id] = "Standard"
		var cell_needs := _title_cell_needs(id)
		needs[id] = cell_needs
		var partners := {}
		for need in cell_needs:
			var partner := _title_partner_for_need(id, need)
			if partner != "":
				partners[need] = partner
		preferred[id] = partners
	var state := {
		"boardVisible": false,
		"boardRect": title_rect,
		"boardViewportRect": view_rect,
		"tileSize": tile_size,
		"boardCols": 1,
		"boardRows": 1,
		"cells": cells,
		"positions": {},
		"overrideCellCenters": centers,
		"overrideCellScales": scales,
		"producedByCell": produced,
		"cellKinds": kinds,
		"rocks": {},
		"needs": needs,
		"preferredNeedPartners": preferred,
		"snapshot": {},
		"usingCsharpSim": false,
		"solved": true,
		"circuitOverlayEnabled": false,
		"fastDragMode": false,
		"dragCell": "",
		"dragPosition": Vector2.ZERO,
		"originalDragTile": Vector2i.ZERO,
		"hintPair": [],
		"resourceMarkMode": 0
	}
	_title_cell_renderer.call("set_render_state", state)


func _get_title_safe_edge_margin(compact: bool, tiny: bool) -> float:
	if tiny:
		return TITLE_SAFE_EDGE_MARGIN_TINY
	if compact:
		return TITLE_SAFE_EDGE_MARGIN_COMPACT
	return TITLE_SAFE_EDGE_MARGIN_DEFAULT


func _apply_title_mobile_safe_fallback(view_rect: Rect2, safe_rect: Rect2) -> Rect2:
	if not Global.is_mobile_platform:
		return safe_rect
	var short_edge: float = minf(view_rect.size.x, view_rect.size.y)
	var portrait: bool = view_rect.size.y >= view_rect.size.x
	var min_top: float = clampf(short_edge * 0.09, TITLE_MOBILE_SAFE_TOP_FALLBACK_MIN, TITLE_MOBILE_SAFE_TOP_FALLBACK_MAX)
	var side_min: float = TITLE_MOBILE_SAFE_SIDE_FALLBACK_PORTRAIT_MIN if portrait else TITLE_MOBILE_SAFE_SIDE_FALLBACK_LANDSCAPE_MIN
	var side_max: float = TITLE_MOBILE_SAFE_SIDE_FALLBACK_PORTRAIT_MAX if portrait else TITLE_MOBILE_SAFE_SIDE_FALLBACK_LANDSCAPE_MAX
	var side_fraction: float = 0.035 if portrait else 0.08
	var min_side: float = clampf(short_edge * side_fraction, side_min, side_max)
	var min_bottom: float = clampf(short_edge * 0.035, TITLE_MOBILE_SAFE_BOTTOM_FALLBACK_MIN, TITLE_MOBILE_SAFE_BOTTOM_FALLBACK_MAX)
	var safe_left: float = maxf(safe_rect.position.x, view_rect.position.x + min_side)
	var safe_top: float = maxf(safe_rect.position.y, view_rect.position.y + min_top)
	var safe_right: float = minf(safe_rect.position.x + safe_rect.size.x, view_rect.position.x + view_rect.size.x - min_side)
	var safe_bottom: float = minf(safe_rect.position.y + safe_rect.size.y, view_rect.position.y + view_rect.size.y - min_bottom)
	if safe_right - safe_left <= 1.0 or safe_bottom - safe_top <= 1.0:
		return safe_rect
	return Rect2(Vector2(safe_left, safe_top), Vector2(safe_right - safe_left, safe_bottom - safe_top))


func _get_title_safe_view_rect() -> Rect2:
	var view_rect := get_viewport_rect()
	if not Global.is_mobile_platform:
		return view_rect
	var window_size_i := DisplayServer.window_get_size()
	var window_size := Vector2(window_size_i)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return _apply_title_mobile_safe_fallback(view_rect, view_rect)
	var safe_area_i := DisplayServer.get_display_safe_area()
	var safe_area := Rect2(Vector2(safe_area_i.position), Vector2(safe_area_i.size))
	if safe_area.size.x <= 0.0 or safe_area.size.y <= 0.0:
		return _apply_title_mobile_safe_fallback(view_rect, view_rect)
	var scale := Vector2(view_rect.size.x / window_size.x, view_rect.size.y / window_size.y)
	var safe_pos := view_rect.position + safe_area.position * scale
	var safe_size := safe_area.size * scale
	var safe_left: float = clampf(safe_pos.x, view_rect.position.x, view_rect.position.x + view_rect.size.x)
	var safe_top: float = clampf(safe_pos.y, view_rect.position.y, view_rect.position.y + view_rect.size.y)
	var safe_right: float = clampf(safe_pos.x + safe_size.x, view_rect.position.x, view_rect.position.x + view_rect.size.x)
	var safe_bottom: float = clampf(safe_pos.y + safe_size.y, view_rect.position.y, view_rect.position.y + view_rect.size.y)
	if safe_right - safe_left <= 1.0 or safe_bottom - safe_top <= 1.0:
		return _apply_title_mobile_safe_fallback(view_rect, view_rect)
	var reported_safe_rect := Rect2(Vector2(safe_left, safe_top), Vector2(safe_right - safe_left, safe_bottom - safe_top))
	return _apply_title_mobile_safe_fallback(view_rect, reported_safe_rect)


func _get_title_padded_safe_view_rect(compact: bool, tiny: bool, extra_margin: float = 0.0) -> Rect2:
	var safe_rect := _get_title_safe_view_rect()
	var margin: float = maxf(_get_title_safe_edge_margin(compact, tiny) + extra_margin, 0.0)
	var padded: Rect2 = safe_rect.grow(-margin)
	if padded.size.x <= 1.0 or padded.size.y <= 1.0:
		return safe_rect
	return padded


func _clamp_title_control_position_to_rect(pos: Vector2, size: Vector2, rect: Rect2) -> Vector2:
	var max_x: float = maxf(rect.position.x, rect.position.x + rect.size.x - size.x)
	var max_y: float = maxf(rect.position.y, rect.position.y + rect.size.y - size.y)
	return Vector2(
		clampf(pos.x, rect.position.x, max_x),
		clampf(pos.y, rect.position.y, max_y)
	)


func _get_title_quit_bottom_margin(compact: bool, tiny: bool) -> float:
	return 10.0 if tiny else (12.0 if compact else 16.0)


func _get_title_quit_height(compact: bool, tiny: bool) -> float:
	if tiny:
		return 38.0
	return 42.0 if compact else 46.0


func _get_title_version_gap(tiny: bool) -> float:
	return 5.0 if tiny else 7.0


func _get_title_version_label_size() -> Vector2:
	var version_label: Label = get_node_or_null("VersionLabel") as Label
	if not is_instance_valid(version_label):
		return Vector2(112.0, 24.0)
	var label_size: Vector2 = version_label.size
	if label_size.x <= 1.0 or label_size.y <= 1.0:
		label_size = version_label.custom_minimum_size
	if label_size.x <= 1.0 or label_size.y <= 1.0:
		label_size = Vector2(112.0, 24.0)
	return label_size


func _get_title_version_top_y(_view_size: Vector2, compact: bool, tiny: bool) -> float:
	var safe_rect := _get_title_padded_safe_view_rect(compact, tiny)
	var version_size: Vector2 = _get_title_version_label_size()
	var quit_top_y: float = safe_rect.position.y + safe_rect.size.y - _get_title_quit_height(compact, tiny) - _get_title_quit_bottom_margin(compact, tiny)
	return quit_top_y - version_size.y - _get_title_version_gap(tiny)


func _get_title_score_gap() -> float:
	return 8.0


func _get_title_score_stack_height(compact: bool, tiny: bool) -> float:
	var has_puzzle_progress := true
	var has_arcade_high_score := true
	var height: float = 0.0
	if has_puzzle_progress:
		height += 42.0 if tiny else (48.0 if compact else 54.0)
	if has_arcade_high_score:
		if height > 0.0:
			height += _get_title_score_gap()
		height += 42.0 if tiny else (48.0 if compact else 54.0)
	return height


func _get_title_ge_button_bottom_y(view_size: Vector2) -> float:
	var link: LinkButton = get_node_or_null("CenterContainer/VBoxContainer/LinkButton") as LinkButton
	if is_instance_valid(link):
		var link_rect: Rect2 = link.get_global_rect()
		if link_rect.size.y > 1.0:
			return link_rect.position.y + link_rect.size.y
	var menu_box: Control = get_node_or_null("CenterContainer/VBoxContainer") as Control
	if is_instance_valid(menu_box):
		var menu_rect: Rect2 = menu_box.get_global_rect()
		if menu_rect.size.y > 1.0:
			return menu_rect.position.y + menu_rect.size.y
	return view_size.y * 0.52


func _shutdown_title_runtime() -> void:
	set_process(false)
	_title_cell_renderer = null
	_ge_logo_texture = null


func _connect_viewport_resize_signal() -> void:
	var viewport = get_viewport()
	if not is_instance_valid(viewport):
		return
	if viewport.size_changed.is_connected(_on_viewport_size_changed):
		return
	viewport.size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()
	_request_title_layout_refresh(3)


func _request_title_layout_refresh(frames: int = 3) -> void:
	_title_pending_layout_frames = maxi(_title_pending_layout_frames, frames)
	call_deferred("_apply_responsive_layout")


func _load_title_texture(path: String) -> Texture2D:
	if path != TITLE_CELLULAR_BACKGROUND_PATH or OS.has_feature("template") or _title_import_cache_exists(path):
		var texture: Resource = load(path)
		if texture is Texture2D:
			return texture as Texture2D
	if path == TITLE_CELLULAR_BACKGROUND_PATH and not OS.has_feature("template"):
		var image := _load_png_image_from_file(path)
		if is_instance_valid(image):
			return ImageTexture.create_from_image(image)
	return null


func _title_import_cache_exists(path: String) -> bool:
	var import_config := ConfigFile.new()
	if import_config.load(str(path, ".import")) != OK:
		return false
	var dest_files = import_config.get_value("deps", "dest_files", [])
	if typeof(dest_files) != TYPE_ARRAY:
		return false
	for dest_file in dest_files:
		if typeof(dest_file) == TYPE_STRING and FileAccess.file_exists(dest_file):
			return true
	return false


func _load_png_image_from_file(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return image


func _configure_title_background_rect(rect: Control, z_index: int, texture_path: String, tiled: bool = false) -> void:
	if not is_instance_valid(rect):
		return
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_as_relative = false
	rect.z_index = z_index
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED if tiled else CanvasItem.TEXTURE_REPEAT_DISABLED
	var texture = _load_title_texture(texture_path)
	if not is_instance_valid(texture):
		return
	if rect is TiledTitleBackground:
		(rect as TiledTitleBackground).set_title_texture(texture)
	elif rect is TextureRect:
		var texture_rect := rect as TextureRect
		texture_rect.texture = texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_TILE if tiled else TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _ensure_responsive_background_nodes() -> void:
	if not is_instance_valid(_title_soil_background):
		_title_soil_background = TiledTitleBackground.new()
		_title_soil_background.name = "ResponsiveCellularBackground"
		add_child(_title_soil_background)
		_configure_title_background_rect(_title_soil_background, -120, TITLE_CELLULAR_BACKGROUND_PATH, true)
	if is_instance_valid(_title_art_background):
		_title_art_background.queue_free()
		_title_art_background = null
	move_child(_title_soil_background, 0)
	_hide_legacy_background_nodes()


func _hide_legacy_background_nodes() -> void:
	for path in ["CenterContainer/BG", "CenterContainer/BG2"]:
		var bg := get_node_or_null(path) as Sprite2D
		if is_instance_valid(bg):
			bg.visible = false


func _layout_responsive_background(view_size: Vector2) -> void:
	_ensure_responsive_background_nodes()
	if is_instance_valid(_title_soil_background):
		_title_soil_background.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_title_soil_background.position = Vector2.ZERO
		_title_soil_background.size = Vector2(ceil(view_size.x), ceil(view_size.y))
		_title_soil_background.visible = true
		_title_soil_background.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_title_soil_background.queue_redraw()


func _apply_responsive_layout() -> void:
	var view_size = get_viewport_rect().size
	_layout_responsive_background(view_size)
	var short_edge = minf(view_size.x, view_size.y)
	var compact = Global.is_mobile_platform or short_edge <= TITLE_COMPACT_SHORT_EDGE
	var tiny = short_edge <= TITLE_TINY_SHORT_EDGE
	var safe_rect := _get_title_padded_safe_view_rect(compact, tiny)
	var center_container := $CenterContainer as CenterContainer
	if is_instance_valid(center_container):
		var center_y_offset := -92.0
		if compact:
			center_y_offset = -74.0
		if tiny:
			center_y_offset = -56.0
		var safe_center_offset: Vector2 = safe_rect.get_center() - view_size * 0.5
		center_container.offset_left = -283.5 + safe_center_offset.x
		center_container.offset_right = 283.5 + safe_center_offset.x
		center_container.offset_top = -229.5 + center_y_offset + safe_center_offset.y
		center_container.offset_bottom = 229.5 + center_y_offset + safe_center_offset.y
	var title_font_size := 56
	if compact:
		title_font_size = 42
	if tiny:
		title_font_size = 34
	var title: Label = $TopLabel
	if is_instance_valid(title):
		title.visible = false
		title.add_theme_font_size_override("font_size", title_font_size)
		var fallback_top = maxf(safe_rect.position.y, 22.0 if compact else 68.0)
		var fallback_bottom = 156.0 if compact else 228.0
		title.offset_top = fallback_top
		title.offset_bottom = maxf(fallback_bottom, fallback_top + 1.0)
	var menu_box: VBoxContainer = $CenterContainer/VBoxContainer
	if is_instance_valid(menu_box):
		menu_box.custom_minimum_size = Vector2(clampf(safe_rect.size.x - 24.0, minf(180.0, safe_rect.size.x), minf(420.0, safe_rect.size.x)), 0.0)
		menu_box.add_theme_constant_override("separation", 7 if compact else 9)
	var cta_min_width: float = minf(220.0, safe_rect.size.x)
	var cta_width = clampf(safe_rect.size.x - 48.0, cta_min_width, minf(340.0, maxf(cta_min_width, safe_rect.size.x)))
	var cta_height = 62.0 if compact else 70.0
	var cta_font_size = 34 if compact else 42
	var quit_min_width: float = minf(190.0, safe_rect.size.x)
	var quit_width = clampf(cta_width * 0.62, quit_min_width, minf(280.0, maxf(quit_min_width, safe_rect.size.x)))
	var quit_height = _get_title_quit_height(compact, tiny)
	var quit_font_size = 22 if compact else 24
	if tiny:
		cta_height = 56.0
		cta_font_size = 29
		quit_font_size = 20
	for button in [$CenterContainer/VBoxContainer/Tutorial, $CenterContainer/VBoxContainer/ChallengeButton]:
		if not is_instance_valid(button):
			continue
		button.custom_minimum_size = Vector2(cta_width, cta_height)
		button.add_theme_font_size_override("font_size", cta_font_size)
	if is_instance_valid(_puzzle_reset_button):
		var reset_width := clampf(cta_width * 0.78, minf(170.0, safe_rect.size.x), cta_width)
		_puzzle_reset_button.custom_minimum_size = Vector2(reset_width, 42.0 if compact else 46.0)
		_puzzle_reset_button.add_theme_font_size_override("font_size", 18 if compact else 20)
	var info_font_size := 20 if compact else 22
	if tiny:
		info_font_size = 17
	_style_title_menu_stat_label(_puzzle_progress_label, info_font_size)
	_style_title_menu_stat_label(_arcade_high_score_label, info_font_size)
	_layout_puzzle_reset_confirm_panel(safe_rect, compact, tiny)
	if is_instance_valid(_title_quit_button):
		_title_quit_button.custom_minimum_size = Vector2(quit_width, quit_height)
		_title_quit_button.size = Vector2(quit_width, quit_height)
		_title_quit_button.position = _clamp_title_control_position_to_rect(
			Vector2(
				round(safe_rect.position.x + (safe_rect.size.x - quit_width) * 0.5),
				round(safe_rect.position.y + safe_rect.size.y - quit_height - _get_title_quit_bottom_margin(compact, tiny))
			),
			Vector2(quit_width, quit_height),
			safe_rect
		)
		_title_quit_button.add_theme_font_size_override("font_size", quit_font_size)
	var link: LinkButton = $CenterContainer/VBoxContainer/LinkButton
	if is_instance_valid(link):
		var ge_panel = link.get_node_or_null("GEPanel") as Panel
		var ge_logo = link.get_node_or_null("GELogo") as TextureRect
		var ge_texture = _get_ge_logo_texture()
		var logo_aspect := 4.63
		if is_instance_valid(ge_texture) and ge_texture.get_height() > 0:
			logo_aspect = (ge_texture.get_width() * 1.0) / (ge_texture.get_height() * 1.0)
		var pad_x := 10.0 if tiny else 12.0
		var pad_y := 6.0 if tiny else 8.0
		var logo_min_width: float = minf(140.0, safe_rect.size.x)
		var logo_width = clampf((safe_rect.size.x - 48.0) * 0.5, logo_min_width, minf(230.0, maxf(logo_min_width, safe_rect.size.x)))
		var logo_height = logo_width / logo_aspect
		link.tooltip_text = "Grassroots Economics"
		link.custom_minimum_size = Vector2(logo_width + pad_x * 2.0, logo_height + pad_y * 2.0)
		link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if is_instance_valid(ge_panel):
			ge_panel.visible = true
			ge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ge_panel.add_theme_stylebox_override("panel", _make_ge_logo_panel_style())
		if is_instance_valid(ge_logo) and is_instance_valid(ge_texture):
			link.text = ""
			ge_logo.visible = true
			ge_logo.texture = ge_texture
			ge_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ge_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			ge_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ge_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ge_logo.offset_left = pad_x
			ge_logo.offset_top = pad_y
			ge_logo.offset_right = -pad_x
			ge_logo.offset_bottom = -pad_y
		else:
			link.text = "Grassroots Economics"
			link.add_theme_color_override("font_color", Color(0.08, 0.16, 0.1, 1.0))
			link.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.84, 0.78))
			link.add_theme_constant_override("outline_size", 2)
			link.add_theme_font_size_override("font_size", 24 if compact else 30)
	var regen_label: Label = $CenterContainer/VBoxContainer/RegenerationLabel
	if is_instance_valid(regen_label):
		var title_width = clampf(view_size.x - 48.0, 340.0, 720.0)
		var title_height_box = 88.0 if tiny else (98.0 if compact else 112.0)
		regen_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		regen_label.custom_minimum_size = Vector2(title_width, title_height_box)
		regen_label.text = "Cellular"
		regen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		regen_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		regen_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
		regen_label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.0))
		regen_label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.0))
		regen_label.add_theme_constant_override("outline_size", 0)
		regen_label.add_theme_constant_override("shadow_offset_x", 0)
		regen_label.add_theme_constant_override("shadow_offset_y", 0)
		regen_label.add_theme_font_size_override("font_size", maxi(1, title_font_size))
	var shroom: Sprite2D = get_node_or_null("CenterContainer/shroom") as Sprite2D
	var farmer: Sprite2D = get_node_or_null("CenterContainer/farmer") as Sprite2D
	var small_shroom: Sprite2D = get_node_or_null("CenterContainer/SmallShroom") as Sprite2D
	if is_instance_valid(shroom):
		shroom.visible = false
		shroom.scale = Vector2(0.24, 0.24) if compact else Vector2(0.30561, 0.30561)
		if tiny:
			shroom.scale = Vector2(0.20, 0.20)
		shroom.position = Vector2(86.0, -62.0) if compact else Vector2(88.5, -73.4999)
	if is_instance_valid(farmer):
		farmer.visible = false
		farmer.scale = Vector2(1.64, 1.64) if compact else Vector2(2.03894, 2.03894)
		if tiny:
			farmer.scale = Vector2(1.48, 1.48)
		farmer.position = Vector2(454.0, -70.0) if compact else Vector2(449.5, -84.5)
	if is_instance_valid(small_shroom):
		small_shroom.visible = false
		small_shroom.scale = Vector2(0.48, 0.48) if compact else Vector2(0.629555, 0.629555)
		if tiny:
			small_shroom.scale = Vector2(0.42, 0.42)
		small_shroom.position = Vector2(270.0, 522.0) if compact else Vector2(269.5, 541.5)
	_update_title_score_widgets(view_size, compact, tiny)
	_sync_title_cell_renderer()
	if is_instance_valid(title):
		var title_height = 122.0 if tiny else (134.0 if compact else 160.0)
		var fallback_top = 22.0 if compact else 68.0
		var vertical_bias = 100.0 if compact else 70.0
		if is_instance_valid(shroom) and shroom.visible and is_instance_valid(farmer) and farmer.visible:
			var shroom_y = shroom.global_position.y
			var farmer_y = farmer.global_position.y
			var midpoint_y = (shroom_y + farmer_y) * 0.5
			var parent_control = title.get_parent() as Control
			var parent_global_y = parent_control.global_position.y if is_instance_valid(parent_control) else 0.0
			var local_midpoint_y = midpoint_y - parent_global_y
			title.offset_top = maxf(safe_rect.position.y, round(local_midpoint_y - title_height * 0.5 + vertical_bias))
		else:
			title.offset_top = maxf(safe_rect.position.y, fallback_top + vertical_bias)
		title.offset_bottom = title.offset_top + title_height
	var version_label: Label = $VersionLabel
	if is_instance_valid(version_label):
		version_label.add_theme_font_size_override("font_size", 13 if compact else 16)
		version_label.custom_minimum_size = Vector2(112.0, 24.0)
		var label_size: Vector2 = _get_title_version_label_size()
		if label_size.x <= 1.0 or label_size.y <= 1.0:
			label_size = version_label.custom_minimum_size
		version_label.size = label_size
		var version_y = _get_title_version_top_y(view_size, compact, tiny)
		version_label.position = _clamp_title_control_position_to_rect(
			Vector2(
				round(safe_rect.position.x + (safe_rect.size.x - label_size.x) * 0.5),
				round(version_y)
			),
			label_size,
			safe_rect
		)


func _reset_run_state() -> void:
	Global.values = {
		"N": 1,
		"P": 1,
		"K": 1,
		"R": 1
	}
	Global.active_agent = null
	Global.is_dragging = false
	Global.stage_inc = 0
	Global.bars_on = false
	Global.allow_agent_reposition = false
	Global.social_mode = false
	Global.enable_tuktuk_predators = false
	Global.story_chapter_id = 1
	Global.village_revealed = false
	Global.village_objective_flags = {}
	Global.perf_tier = 0
	Global.perf_tile_occupancy_queries = 0
	Global.perf_last_sample = {}
	if Global.has_method("reset_trade_dispatch_budgets"):
		Global.reset_trade_dispatch_budgets()


func _ready():
	Global.reset_gameplay_speed()
	DisplayServer.window_set_title("Cellular")
	Global.record_last_score()
	Global.score = 0
	_ensure_responsive_background_nodes()
	$CenterContainer/VBoxContainer/HBoxContainer.visible = false
	_setup_primary_buttons()
	_refresh_cellular_title_stats()
	_setup_version_label()
	_ensure_title_score_widgets()
	_ensure_title_cell_renderer()
	_connect_viewport_resize_signal()
	_apply_responsive_layout()
	_request_title_layout_refresh(4)
	Global.social_mode = false


func _process(delta: float) -> void:
	if _title_pending_layout_frames > 0:
		_title_pending_layout_frames -= 1
		_apply_responsive_layout()
	_title_cell_animation_time += maxf(delta, 0.0)
	_sync_title_cell_renderer()
	_update_title_score_sparkles(delta)


func _exit_tree() -> void:
	_shutdown_title_runtime()
		

func _on_tutorial_pressed() -> void:
	_reset_run_state()
	Global.mode = "puzzle"
	Global.active_mode_id = "cellular_puzzle"
	Global.cellular_puzzle_highest_level = clampi(maxi(1, Global.cellular_puzzle_highest_level), 1, Global.CELLULAR_PUZZLE_FINAL_LEVEL)
	Global.cellular_puzzle_current_level = clampi(maxi(1, Global.cellular_puzzle_current_level), 1, maxi(1, Global.cellular_puzzle_highest_level))
	Global.active_scenario_id = str("puzzle_level_", Global.cellular_puzzle_current_level)
	get_tree().change_scene_to_file("res://scenes/cellular_puzzle_level.tscn")

func _on_free_garden_pressed() -> void:
	_on_challenge_button_pressed()

func _on_challenge_button_pressed() -> void:
	_reset_run_state()
	Global.mode = "arcade"
	Global.active_mode_id = "cellular_arcade"
	Global.active_scenario_id = "cellular_arcade"
	get_tree().change_scene_to_file("res://scenes/cellular_arcade_level.tscn")


func _on_reset_puzzle_progress_pressed() -> void:
	_ensure_puzzle_reset_confirm_panel()
	_apply_responsive_layout()
	if is_instance_valid(_puzzle_reset_confirm_overlay):
		_puzzle_reset_confirm_overlay.visible = true
		if is_instance_valid(_puzzle_reset_confirm_no_button):
			_puzzle_reset_confirm_no_button.grab_focus()


func _on_reset_puzzle_progress_confirmed() -> void:
	_hide_puzzle_reset_confirm_panel()
	if Global.has_method("reset_cellular_puzzle_progress"):
		Global.reset_cellular_puzzle_progress()
	_refresh_cellular_title_stats()
	_request_title_layout_refresh(2)


func _on_cofi_button_pressed() -> void:
	_on_challenge_button_pressed()


func _on_quit_game_pressed() -> void:
	if _title_quit_requested:
		return
	_title_quit_requested = true
	Global.record_last_score()
	_shutdown_title_runtime()
	await get_tree().process_frame
	Global.request_quit_game(get_tree())


func _on_check_button_toggled(toggled_on: bool) -> void:
	Global.social_mode = false
		


func _on_check_button_2_toggled(toggled_on: bool) -> void:
	Global.social_mode = false
