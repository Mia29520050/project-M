extends Control

signal closed

const C_BG := Color(0.018, 0.025, 0.055, 0.985)
const C_PANEL := Color(0.032, 0.043, 0.085, 0.94)
const C_PANEL_SOFT := Color(0.045, 0.058, 0.108, 0.88)
const C_BORDER := Color(0.34, 0.42, 0.66, 0.72)
const C_ACCENT := Color(0.68, 0.78, 1.0)
const C_TEXT := Color(0.85, 0.91, 1.0)
const C_MUTED := Color(0.54, 0.64, 0.81)
const C_OK := Color(0.55, 0.91, 0.78)
const C_ERROR := Color(1.0, 0.54, 0.60)

var _active_category := "display"
var _pages: Dictionary = {}
var _nav_buttons: Dictionary = {}
var _binding_buttons: Dictionary = {}
var _rebinding_action := ""
var _status_label: Label
var _master_slider: HSlider
var _master_value: Label
var _display_mode_option: OptionButton
var _resolution_option: OptionButton
var _resolution_hint: Label
var _quality_option: OptionButton
var _vsync_check: CheckBox
var _fps_option: OptionButton
var _show_hints_check: CheckBox
var _confirm_exit_check: CheckBox
var _controls_page_box: VBoxContainer
var _back_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_values()
	_select_category("display")
	if not MoonveilSettings.settings_changed.is_connected(_on_settings_changed):
		MoonveilSettings.settings_changed.connect(_on_settings_changed)
	_update_back_label()
	call_deferred("_focus_default_control")

func _focus_default_control() -> void:
	if not visible:
		return
	if is_instance_valid(_back_button):
		_back_button.grab_focus()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.010, 0.028, 0.83)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var frame := PanelContainer.new()
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -560.0
	frame.offset_right = 560.0
	frame.offset_top = -310.0
	frame.offset_bottom = 310.0
	frame.add_theme_stylebox_override("panel", _panel_style(C_BG, Color(0.48, 0.57, 0.82, 0.84), 12, 1, 22))
	add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 13)
	frame.add_child(root)
	_build_header(root)

	var top_rule := ColorRect.new()
	top_rule.custom_minimum_size = Vector2(0, 1)
	top_rule.color = Color(0.40, 0.50, 0.74, 0.55)
	root.add_child(top_rule)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	_build_sidebar(body)
	_build_pages(body)

	var footer_rule := ColorRect.new()
	footer_rule.custom_minimum_size = Vector2(0, 1)
	footer_rule.color = Color(0.27, 0.36, 0.58, 0.52)
	root.add_child(footer_rule)
	_build_footer(root)

func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	row.add_child(title_col)
	var eyebrow := _make_label(title_col, "MOONVEIL  /  WAYFARER", 10, C_ACCENT)
	eyebrow.add_theme_color_override("font_color", Color(0.57, 0.72, 0.98))
	var heading := _make_label(title_col, "SYSTEM SETTINGS", 25, C_TEXT)
	heading.add_theme_color_override("font_color", Color(0.91, 0.94, 1.0))
	var subtitle := _make_label(title_col, "Tuỳ chỉnh trải nghiệm của bạn · thay đổi được lưu tự động", 11, C_MUTED)
	var profile := _make_label(row, "LOCAL PROFILE  ◈", 10, C_MUTED)
	profile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _build_sidebar(parent: HBoxContainer) -> void:
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(194, 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_stylebox_override("panel", _panel_style(Color(0.026, 0.035, 0.072, 0.80), Color(0.23, 0.31, 0.52, 0.54), 8, 1, 10))
	parent.add_child(sidebar)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	sidebar.add_child(list)
	var nav_items := [
		["audio", "♫", "Âm thanh"],
		["display", "▣", "Màn hình"],
		["graphics", "✧", "Đồ hoạ"],
		["controls", "⌘", "Điều khiển"],
		["interface", "◈", "Giao diện"]
	]
	for item in nav_items:
		var category := String(item[0])
		var button := Button.new()
		button.text = "  %s   %s" % [String(item[1]), String(item[2])]
		button.custom_minimum_size = Vector2(0, 43)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(func() -> void: _select_category(category))
		_nav_buttons[category] = button
		list.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_child(spacer)
	var side_note := _make_label(list, "PROFILE\nSettings saved on this device.", 10, C_MUTED)
	side_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_pages(parent: HBoxContainer) -> void:
	var host := Control.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(host)
	for category in ["audio", "display", "graphics", "controls", "interface"]:
		var page := ScrollContainer.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		page.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 12)
		page.add_child(content)
		host.add_child(page)
		_pages[category] = page
		match category:
			"audio": _build_audio_page(content)
			"display": _build_display_page(content)
			"graphics": _build_graphics_page(content)
			"controls":
				_controls_page_box = content
				_build_controls_page(content)
			"interface": _build_interface_page(content)

func _build_footer(parent: VBoxContainer) -> void:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	parent.add_child(footer)
	var restore := _make_button("RESTORE ALL DEFAULTS", false)
	restore.custom_minimum_size = Vector2(205, 39)
	restore.pressed.connect(_on_restore_defaults)
	footer.add_child(restore)
	_status_label = _make_label(footer, "Changes are saved automatically.", 11, C_MUTED)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_back_button = _make_button("BACK", true)
	_back_button.custom_minimum_size = Vector2(154, 39)
	_back_button.pressed.connect(_close)
	footer.add_child(_back_button)

func _build_audio_page(parent: VBoxContainer) -> void:
	_add_page_heading(parent, "AUDIO", "Điều chỉnh mức âm lượng của toàn bộ âm thanh trong game.")
	var card := _make_card(parent)
	var box := _card_content(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var label := _make_label(row, "MASTER VOLUME", 13, C_TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_master_value = _make_label(row, "82%", 13, C_ACCENT)
	_master_value.custom_minimum_size = Vector2(58, 0)
	_master_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_master_slider = HSlider.new()
	_master_slider.min_value = 0.0
	_master_slider.max_value = 100.0
	_master_slider.step = 1.0
	_master_slider.custom_minimum_size = Vector2(0, 28)
	_master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_master_slider.value_changed.connect(_on_volume_changed)
	box.add_child(_master_slider)
	_add_note(box, "Volume applies to the Master audio bus. Dedicated music and effects sliders will become available when those audio channels are added to the game.")

func _build_display_page(parent: VBoxContainer) -> void:
	_add_page_heading(parent, "DISPLAY", "Chế độ hiển thị và độ phân giải cửa sổ.")
	var card := _make_card(parent)
	var box := _card_content(card)
	_display_mode_option = _make_option_button()
	for mode in MoonveilSettings.get_display_mode_options():
		_display_mode_option.add_item(mode)
	_display_mode_option.item_selected.connect(_on_display_mode_selected)
	box.add_child(_make_setting_row("Window mode", _display_mode_option))
	_resolution_option = _make_option_button()
	_resolution_option.item_selected.connect(_on_resolution_selected)
	box.add_child(_make_setting_row("Window resolution", _resolution_option))
	_resolution_hint = _make_label(box, "Windowed mode uses the chosen size. Fullscreen modes use the monitor's native resolution.", 11, C_MUTED)
	_resolution_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resolution_hint.custom_minimum_size = Vector2(0, 34)
	_add_note(box, "Changes apply immediately. If a resolution is unsupported on this display it will not appear in the list.")

func _build_graphics_page(parent: VBoxContainer) -> void:
	_add_page_heading(parent, "GRAPHICS & PERFORMANCE", "Cân bằng chất lượng hình ảnh với hiệu năng.")
	var card := _make_card(parent)
	var box := _card_content(card)
	_quality_option = _make_option_button()
	_quality_option.add_item("Low  ·  ưu tiên hiệu năng")
	_quality_option.add_item("Balanced  ·  khuyến nghị")
	_quality_option.add_item("High  ·  khử răng cưa 4×")
	_quality_option.item_selected.connect(_on_quality_selected)
	box.add_child(_make_setting_row("Quality preset", _quality_option))
	_vsync_check = _make_check_box("Vertical sync", "Giảm hiện tượng xé hình.")
	_vsync_check.toggled.connect(_on_vsync_toggled)
	box.add_child(_vsync_check)
	_fps_option = _make_option_button()
	for fps in MoonveilSettings.FPS_LIMIT_OPTIONS:
		_fps_option.add_item("Unlimited" if fps == 0 else "%d FPS" % fps)
	_fps_option.item_selected.connect(_on_fps_selected)
	box.add_child(_make_setting_row("Frame rate limit", _fps_option))
	_add_note(box, "Low turns off directional-light shadows and 3D anti-aliasing. Balanced uses 2× MSAA; High uses 4× MSAA. Some changes may be more noticeable in 3D scenes than in the Refuge UI.")

func _build_controls_page(parent: VBoxContainer) -> void:
	_add_page_heading(parent, "CONTROLS", "Chọn một ô phím rồi nhấn phím mới hoặc nút chuột. Gán phím sẽ được lưu ngay.")
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	parent.add_child(top_row)
	var reset_button := _make_button("RESET CONTROLS", false)
	reset_button.custom_minimum_size = Vector2(160, 36)
	reset_button.pressed.connect(_on_reset_controls)
	top_row.add_child(reset_button)
	var caution := _make_label(top_row, "Duplicate bindings are blocked. ESC cancels listening (except when rebinding Pause).", 10, C_MUTED)
	caution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caution.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var current_group := ""
	for item in MoonveilSettings.get_control_actions():
		var group_name := String(item["group"])
		if group_name != current_group:
			current_group = group_name
			var group_header := _make_label(parent, group_name, 10, C_ACCENT)
			group_header.custom_minimum_size = Vector2(0, 20)
			var group_rule := ColorRect.new()
			group_rule.custom_minimum_size = Vector2(0, 1)
			group_rule.color = Color(0.31, 0.40, 0.64, 0.45)
			parent.add_child(group_rule)
		var action := String(item["action"])
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 38)
		row.add_theme_constant_override("separation", 12)
		parent.add_child(row)
		var action_label := _make_label(row, String(item["label"]), 12, C_TEXT)
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var binding_button := _make_button(MoonveilSettings.get_control_binding_label(action), false)
		binding_button.custom_minimum_size = Vector2(206, 34)
		binding_button.add_theme_font_size_override("font_size", 11)
		binding_button.pressed.connect(func() -> void: _begin_rebind(action))
		_binding_buttons[action] = binding_button
		row.add_child(binding_button)
		var row_rule := ColorRect.new()
		row_rule.custom_minimum_size = Vector2(0, 1)
		row_rule.color = Color(0.25, 0.32, 0.52, 0.32)
		parent.add_child(row_rule)

func _build_interface_page(parent: VBoxContainer) -> void:
	_add_page_heading(parent, "INTERFACE & GAMEPLAY", "Các tuỳ chọn ảnh hưởng tới giao diện trong lúc chơi.")
	var card := _make_card(parent)
	var box := _card_content(card)
	_show_hints_check = _make_check_box("Show control hints", "Hiện thanh hướng dẫn phím ở cạnh dưới màn hình trong trận.")
	_show_hints_check.toggled.connect(func(enabled: bool) -> void: MoonveilSettings.set_show_control_hints(enabled))
	box.add_child(_show_hints_check)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.27, 0.36, 0.58, 0.45)
	box.add_child(rule)
	_confirm_exit_check = _make_check_box("Confirm before leaving an expedition", "Show a confirmation dialog before returning to title; prevents accidental loss of temporary run progress.")
	_confirm_exit_check.toggled.connect(func(enabled: bool) -> void: MoonveilSettings.set_confirm_return_to_title(enabled))
	box.add_child(_confirm_exit_check)
	_add_note(box, "Interface options are stored locally and apply immediately. Permanent profile data remains governed by the existing save system.")

func _add_page_heading(parent: VBoxContainer, title: String, description: String) -> void:
	var heading := _make_label(parent, title, 18, C_TEXT)
	heading.add_theme_color_override("font_color", Color(0.88, 0.91, 1.0))
	var note := _make_label(parent, description, 11, C_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.36, 0.45, 0.69, 0.48)
	parent.add_child(rule)

func _make_card(parent: VBoxContainer) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_BORDER, 7, 1, 14))
	parent.add_child(card)
	return card

func _card_content(card: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	return box

func _add_note(parent: VBoxContainer, message: String) -> void:
	var note := _make_label(parent, message, 10, C_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(0, 30)

func _make_setting_row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := _make_label(row, caption, 12, C_TEXT)
	label.custom_minimum_size = Vector2(185, 38)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	control.custom_minimum_size = Vector2(250, 38)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _make_option_button() -> OptionButton:
	var option := OptionButton.new()
	option.add_theme_font_size_override("font_size", 12)
	option.add_theme_color_override("font_color", C_TEXT)
	option.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	option.add_theme_stylebox_override("normal", _control_style(false))
	option.add_theme_stylebox_override("hover", _control_style(true))
	var pressed := _control_style(true)
	pressed.bg_color = Color(0.14, 0.20, 0.35, 1.0)
	option.add_theme_stylebox_override("pressed", pressed)
	option.add_theme_stylebox_override("disabled", _control_style(false))
	return option

func _make_check_box(caption: String, _description: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = caption
	check.tooltip_text = _description
	check.custom_minimum_size = Vector2(0, 34)
	check.add_theme_font_size_override("font_size", 12)
	check.add_theme_color_override("font_color", C_TEXT)
	check.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	return check

func _make_button(caption: String, emphasized: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 40)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", C_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", _control_style(emphasized))
	button.add_theme_stylebox_override("hover", _control_style(true))
	var pressed := _control_style(true)
	pressed.bg_color = Color(0.18, 0.27, 0.43, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _control_style(true))
	return button

func _control_style(emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.20, 0.34, 0.98) if emphasized else Color(0.045, 0.062, 0.112, 0.96)
	style.border_color = Color(0.60, 0.69, 0.94, 0.94) if emphasized else Color(0.26, 0.35, 0.57, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	return style

func _panel_style(background: Color, border: Color, radius: int, border_width: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _make_label(parent: Node, value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _select_category(category: String) -> void:
	_active_category = category
	for key in _pages:
		(_pages[key] as Control).visible = String(key) == category
	for key in _nav_buttons:
		var button := _nav_buttons[key] as Button
		var selected := String(key) == category
		button.add_theme_stylebox_override("normal", _control_style(selected))
		button.add_theme_stylebox_override("hover", _control_style(true))
		button.add_theme_color_override("font_color", C_TEXT if selected else C_MUTED)

func _on_settings_changed() -> void:
	_update_back_label()

func _update_back_label() -> void:
	if is_instance_valid(_back_button):
		_back_button.text = "BACK  ·  %s" % MoonveilSettings.get_control_binding_label("pause")

func _refresh_values() -> void:
	_master_slider.set_value_no_signal(roundf(MoonveilSettings.master_volume * 100.0))
	_master_value.text = "%d%%" % roundi(MoonveilSettings.master_volume * 100.0)

	_display_mode_option.clear()
	for mode in MoonveilSettings.get_display_mode_options():
		_display_mode_option.add_item(mode)
	var mode_index := MoonveilSettings.get_display_mode_options().find(MoonveilSettings.display_mode)
	_display_mode_option.select(maxi(0, mode_index))

	_resolution_option.clear()
	var resolutions := MoonveilSettings.get_available_resolutions()
	for resolution in resolutions:
		_resolution_option.add_item(resolution)
	var resolution_index := resolutions.find(MoonveilSettings.windowed_resolution)
	_resolution_option.select(maxi(0, resolution_index))
	_resolution_option.disabled = MoonveilSettings.display_mode != MoonveilSettings.MODE_WINDOWED
	_resolution_hint.modulate = Color(1.0, 1.0, 1.0, 0.95) if not _resolution_option.disabled else Color(0.68, 0.74, 0.82, 0.62)

	_quality_option.select(maxi(0, MoonveilSettings.GRAPHICS_QUALITY_OPTIONS.find(MoonveilSettings.graphics_quality)))
	_vsync_check.set_pressed_no_signal(MoonveilSettings.vsync_enabled)
	_fps_option.select(maxi(0, MoonveilSettings.FPS_LIMIT_OPTIONS.find(MoonveilSettings.max_fps)))
	_show_hints_check.set_pressed_no_signal(MoonveilSettings.show_control_hints)
	_confirm_exit_check.set_pressed_no_signal(MoonveilSettings.confirm_return_to_title)
	_refresh_binding_buttons()

func _refresh_binding_buttons() -> void:
	for action in _binding_buttons:
		var button := _binding_buttons[action] as Button
		if String(action) == _rebinding_action:
			button.text = "PRESS A KEY…"
			button.add_theme_stylebox_override("normal", _control_style(true))
		else:
			button.text = MoonveilSettings.get_control_binding_label(String(action))
			button.add_theme_stylebox_override("normal", _control_style(false))

func _on_volume_changed(value: float) -> void:
	_master_value.text = "%d%%" % roundi(value)
	MoonveilSettings.set_master_volume(value / 100.0)

func _on_display_mode_selected(index: int) -> void:
	MoonveilSettings.set_display_mode(_display_mode_option.get_item_text(index))
	_refresh_values()

func _on_resolution_selected(index: int) -> void:
	MoonveilSettings.set_windowed_resolution(_resolution_option.get_item_text(index))
	_refresh_values()

func _on_quality_selected(index: int) -> void:
	if index >= 0 and index < MoonveilSettings.GRAPHICS_QUALITY_OPTIONS.size():
		MoonveilSettings.set_graphics_quality(MoonveilSettings.GRAPHICS_QUALITY_OPTIONS[index])
		_set_status("Graphics preset applied.", false)

func _on_vsync_toggled(enabled: bool) -> void:
	MoonveilSettings.set_vsync(enabled)

func _on_fps_selected(index: int) -> void:
	if index >= 0 and index < MoonveilSettings.FPS_LIMIT_OPTIONS.size():
		MoonveilSettings.set_max_fps(MoonveilSettings.FPS_LIMIT_OPTIONS[index])

func _begin_rebind(action: String) -> void:
	_rebinding_action = action
	_set_status("Listening for %s · press a key or mouse button. Esc cancels." % _control_action_label(action), false)
	_refresh_binding_buttons()
	if _binding_buttons.has(action):
		(_binding_buttons[action] as Button).grab_focus()

func _input(event: InputEvent) -> void:
	if _rebinding_action.is_empty() or not visible:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		var key_code := key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
		if key_code == KEY_ESCAPE and _rebinding_action != "pause":
			get_viewport().set_input_as_handled()
			_cancel_rebind()
			return
		if key_code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		_finish_rebind(MoonveilSettings.set_control_binding(_rebinding_action, key_event))
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return
		get_viewport().set_input_as_handled()
		_finish_rebind(MoonveilSettings.set_control_binding(_rebinding_action, mouse_event))

func _finish_rebind(error_message: String) -> void:
	_rebinding_action = ""
	_refresh_binding_buttons()
	if error_message.is_empty():
		_set_status("Binding saved.", false)
	else:
		_set_status(error_message, true)

func _cancel_rebind() -> void:
	_rebinding_action = ""
	_refresh_binding_buttons()
	_set_status("Rebinding cancelled.", false)

func _control_action_label(action: String) -> String:
	for item in MoonveilSettings.get_control_actions():
		if String(item["action"]) == action:
			return String(item["label"])
	return action

func _on_reset_controls() -> void:
	_rebinding_action = ""
	MoonveilSettings.reset_control_bindings()
	_refresh_binding_buttons()
	_set_status("Default controls restored.", false)

func _on_restore_defaults() -> void:
	_rebinding_action = ""
	MoonveilSettings.reset_defaults()
	_refresh_values()
	_set_status("All settings restored to defaults.", false)

func _set_status(message: String, error: bool) -> void:
	if not is_instance_valid(_status_label):
		return
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", C_ERROR if error else (C_OK if message.to_lower().contains("saved") or message.to_lower().contains("restored") else C_MUTED))

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _rebinding_action != "" or not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	_close()

func _close() -> void:
	if not _rebinding_action.is_empty():
		_cancel_rebind()
	hide()
	closed.emit()
