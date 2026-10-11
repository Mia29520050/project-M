extends Control

signal closed

var _volume_slider: HSlider
var _volume_value: Label
var _fullscreen_check: CheckBox
var _vsync_check: CheckBox

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
	panel.offset_left = -270.0
	panel.offset_right = 270.0
	panel.offset_top = -235.0
	panel.offset_bottom = 235.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.085, 0.99)
	panel_style.border_color = Color(0.25, 0.57, 0.77, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_top = 26.0
	panel_style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "SYSTEM SETTINGS"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	column.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Tune the way the world looks and sounds."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.60, 0.73, 0.88))
	column.add_child(subtitle)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.24, 0.48, 0.65, 0.72)
	column.add_child(rule)

	var volume_heading := Label.new()
	volume_heading.text = "MASTER VOLUME"
	volume_heading.add_theme_font_size_override("font_size", 13)
	volume_heading.add_theme_color_override("font_color", Color(0.76, 0.85, 0.96))
	column.add_child(volume_heading)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	column.add_child(volume_row)
	_volume_slider = HSlider.new()
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.custom_minimum_size = Vector2(0, 28)
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.value_changed.connect(_on_volume_changed)
	volume_row.add_child(_volume_slider)
	_volume_value = Label.new()
	_volume_value.custom_minimum_size = Vector2(48, 0)
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_value.add_theme_font_size_override("font_size", 14)
	_volume_value.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	volume_row.add_child(_volume_value)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.add_theme_font_size_override("font_size", 15)
	_fullscreen_check.add_theme_color_override("font_color", Color(0.80, 0.87, 0.98))
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	column.add_child(_fullscreen_check)

	_vsync_check = CheckBox.new()
	_vsync_check.text = "Vertical sync"
	_vsync_check.add_theme_font_size_override("font_size", 15)
	_vsync_check.add_theme_color_override("font_color", Color(0.80, 0.87, 0.98))
	_vsync_check.toggled.connect(_on_vsync_toggled)
	column.add_child(_vsync_check)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

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

func _make_button(caption: String, emphasized: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 13)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.25, 0.39, 0.95) if emphasized else Color(0.055, 0.085, 0.15, 0.95)
	normal.border_color = Color(0.31, 0.72, 0.91, 0.95) if emphasized else Color(0.19, 0.33, 0.48, 0.9)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.33, 0.49, 1.0)
	hover.border_color = Color(0.45, 0.83, 0.98, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.16, 0.40, 0.56, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	return button

func _refresh_values() -> void:
	_volume_slider.set_value_no_signal(roundf(MoonveilSettings.master_volume * 100.0))
	_volume_value.text = "%d%%" % roundi(MoonveilSettings.master_volume * 100.0)
	_fullscreen_check.set_pressed_no_signal(MoonveilSettings.fullscreen_enabled)
	_vsync_check.set_pressed_no_signal(MoonveilSettings.vsync_enabled)

func _on_volume_changed(value: float) -> void:
	_volume_value.text = "%d%%" % roundi(value)
	MoonveilSettings.set_master_volume(value / 100.0)

func _on_fullscreen_toggled(enabled: bool) -> void:
	MoonveilSettings.set_fullscreen(enabled)

func _on_vsync_toggled(enabled: bool) -> void:
	MoonveilSettings.set_vsync(enabled)

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
