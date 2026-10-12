extends Control

signal closed

var _volume_slider: HSlider
var _volume_value: Label
var _display_mode_option: OptionButton
var _resolution_option: OptionButton
var _vsync_check: CheckBox
var _fps_option: OptionButton
var _resolution_hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_values()
	call_deferred("_focus_first_control")

func _focus_first_control() -> void:
	if is_instance_valid(_volume_slider) and visible:
		_volume_slider.grab_focus()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.014, 0.035, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320.0
	panel.offset_right = 320.0
	panel.offset_top = -294.0
	panel.offset_bottom = 294.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.085, 0.99)
	panel_style.border_color = Color(0.25, 0.57, 0.77, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_top = 22.0
	panel_style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "SYSTEM SETTINGS"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	column.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Configure sound, display mode, resolution and performance."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.60, 0.73, 0.88))
	column.add_child(subtitle)
	_add_rule(column)

	_add_section_heading(column, "AUDIO")
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	column.add_child(volume_row)
	_volume_slider = HSlider.new()
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.custom_minimum_size = Vector2(0, 28)
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.focus_mode = Control.FOCUS_ALL
	_volume_slider.value_changed.connect(_on_volume_changed)
	volume_row.add_child(_volume_slider)
	_volume_value = Label.new()
	_volume_value.custom_minimum_size = Vector2(52, 0)
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_value.add_theme_font_size_override("font_size", 14)
	_volume_value.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	volume_row.add_child(_volume_value)
	_add_rule(column)

	_add_section_heading(column, "DISPLAY")
	_display_mode_option = _make_option_button()
	for mode in MoonveilSettings.get_display_mode_options():
		_display_mode_option.add_item(mode)
	_display_mode_option.item_selected.connect(_on_display_mode_selected)
	column.add_child(_make_setting_row("Window Mode", _display_mode_option))

	_resolution_option = _make_option_button()
	_resolution_option.item_selected.connect(_on_resolution_selected)
	column.add_child(_make_setting_row("Window Resolution", _resolution_option))

	_resolution_hint = Label.new()
	_resolution_hint.text = "Windowed mode uses this size. Fullscreen modes use your monitor's native size."
	_resolution_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resolution_hint.add_theme_font_size_override("font_size", 11)
	_resolution_hint.add_theme_color_override("font_color", Color(0.48, 0.63, 0.79))
	column.add_child(_resolution_hint)
	_add_rule(column)

	_add_section_heading(column, "PERFORMANCE")
	var performance_row := HBoxContainer.new()
	performance_row.add_theme_constant_override("separation", 18)
	column.add_child(performance_row)
	_vsync_check = CheckBox.new()
	_vsync_check.text = "Vertical sync"
	_vsync_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vsync_check.add_theme_font_size_override("font_size", 14)
	_vsync_check.add_theme_color_override("font_color", Color(0.80, 0.87, 0.98))
	_vsync_check.toggled.connect(_on_vsync_toggled)
	performance_row.add_child(_vsync_check)
	var fps_column := VBoxContainer.new()
	fps_column.custom_minimum_size = Vector2(235, 0)
	fps_column.add_theme_constant_override("separation", 4)
	performance_row.add_child(fps_column)
	var fps_label := Label.new()
	fps_label.text = "FRAME RATE LIMIT"
	fps_label.add_theme_font_size_override("font_size", 10)
	fps_label.add_theme_color_override("font_color", Color(0.57, 0.73, 0.88))
	fps_column.add_child(fps_label)
	_fps_option = _make_option_button()
	for fps in MoonveilSettings.FPS_LIMIT_OPTIONS:
		_fps_option.add_item("Unlimited" if fps == 0 else "%d FPS" % fps)
	_fps_option.item_selected.connect(_on_fps_selected)
	fps_column.add_child(_fps_option)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var footer_hint := Label.new()
	footer_hint.text = "Changes apply immediately and are saved on this device."
	footer_hint.add_theme_font_size_override("font_size", 11)
	footer_hint.add_theme_color_override("font_color", Color(0.48, 0.63, 0.79))
	column.add_child(footer_hint)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	var defaults_button := _make_button("RESTORE DEFAULTS", false)
	defaults_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defaults_button.pressed.connect(_on_restore_defaults)
	footer.add_child(defaults_button)
	var back_button := _make_button("BACK", true)
	back_button.custom_minimum_size = Vector2(120, 42)
	back_button.pressed.connect(_close)
	footer.add_child(back_button)

func _add_section_heading(parent: VBoxContainer, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.40, 0.77, 0.92))
	parent.add_child(label)

func _add_rule(parent: VBoxContainer) -> void:
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.24, 0.48, 0.65, 0.58)
	parent.add_child(rule)

func _make_setting_row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(158, 38)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.78, 0.87, 0.98))
	row.add_child(label)
	control.custom_minimum_size = Vector2(0, 38)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _make_option_button() -> OptionButton:
	var option := OptionButton.new()
	option.add_theme_font_size_override("font_size", 13)
	option.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	option.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	var normal := _make_button_style(false)
	var hover := _make_button_style(true)
	var pressed := _make_button_style(true)
	pressed.bg_color = Color(0.15, 0.37, 0.52, 1.0)
	option.add_theme_stylebox_override("normal", normal)
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("pressed", pressed)
	option.add_theme_stylebox_override("disabled", normal)
	return option

func _make_button_style(emphasized: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.25, 0.39, 0.95) if emphasized else Color(0.055, 0.085, 0.15, 0.95)
	style.border_color = Color(0.31, 0.72, 0.91, 0.95) if emphasized else Color(0.19, 0.33, 0.48, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	return style

func _make_button(caption: String, emphasized: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _make_button_style(emphasized))
	var hover := _make_button_style(true)
	hover.border_color = Color(0.45, 0.83, 0.98, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := _make_button_style(true)
	pressed.bg_color = Color(0.16, 0.40, 0.56, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	return button

func _refresh_values() -> void:
	_volume_slider.set_value_no_signal(roundf(MoonveilSettings.master_volume * 100.0))
	_volume_value.text = "%d%%" % roundi(MoonveilSettings.master_volume * 100.0)

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

	_vsync_check.set_pressed_no_signal(MoonveilSettings.vsync_enabled)
	var fps_index := MoonveilSettings.FPS_LIMIT_OPTIONS.find(MoonveilSettings.max_fps)
	_fps_option.select(maxi(0, fps_index))

func _on_volume_changed(value: float) -> void:
	_volume_value.text = "%d%%" % roundi(value)
	MoonveilSettings.set_master_volume(value / 100.0)

func _on_display_mode_selected(index: int) -> void:
	MoonveilSettings.set_display_mode(_display_mode_option.get_item_text(index))
	_refresh_values()

func _on_resolution_selected(index: int) -> void:
	MoonveilSettings.set_windowed_resolution(_resolution_option.get_item_text(index))
	_refresh_values()

func _on_vsync_toggled(enabled: bool) -> void:
	MoonveilSettings.set_vsync(enabled)

func _on_fps_selected(index: int) -> void:
	if index >= 0 and index < MoonveilSettings.FPS_LIMIT_OPTIONS.size():
		MoonveilSettings.set_max_fps(MoonveilSettings.FPS_LIMIT_OPTIONS[index])

func _on_restore_defaults() -> void:
	MoonveilSettings.reset_defaults()
	_refresh_values()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	hide()
	closed.emit()
