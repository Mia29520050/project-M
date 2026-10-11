extends CanvasLayer

signal resume_requested
signal return_to_title_requested

const SETTINGS_PANEL_SCENE := preload("res://scenes/settings_panel.tscn")

var _pause_panel: PanelContainer
var _confirm_panel: PanelContainer
var _settings_panel: Control
var _resume_button: Button
var _stay_button: Button
var _leave_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build_ui()
	hide()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.015, 0.04, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_pause_panel = _make_panel(Vector2(430, 400))
	_pause_panel.anchor_left = 0.5
	_pause_panel.anchor_right = 0.5
	_pause_panel.anchor_top = 0.5
	_pause_panel.anchor_bottom = 0.5
	_pause_panel.offset_left = -215
	_pause_panel.offset_right = 215
	_pause_panel.offset_top = -200
	_pause_panel.offset_bottom = 200
	add_child(_pause_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(column)
	var eyebrow := Label.new()
	eyebrow.text = "THE VEIL IS STILL"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", Color(0.42, 0.78, 0.93))
	column.add_child(eyebrow)
	var heading := Label.new()
	heading.text = "PAUSED"
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	column.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "Time is held. Take a breath before continuing."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.75, 0.89))
	column.add_child(subtitle)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.22, 0.43, 0.60, 0.8)
	column.add_child(rule)

	_resume_button = _make_button("RESUME EXPEDITION", true)
	_resume_button.pressed.connect(_on_resume)
	column.add_child(_resume_button)
	var settings_button := _make_button("SYSTEM SETTINGS", false)
	settings_button.pressed.connect(_open_settings)
	column.add_child(settings_button)
	var title_button := _make_button("RETURN TO TITLE", false)
	title_button.pressed.connect(_open_return_confirmation)
	column.add_child(title_button)
	var footer := Label.new()
	footer.text = "Press Esc to resume"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.50, 0.64, 0.79))
	column.add_child(footer)

	_confirm_panel = _make_panel(Vector2(460, 220))
	_confirm_panel.anchor_left = 0.5
	_confirm_panel.anchor_right = 0.5
	_confirm_panel.anchor_top = 0.5
	_confirm_panel.anchor_bottom = 0.5
	_confirm_panel.offset_left = -230
	_confirm_panel.offset_right = 230
	_confirm_panel.offset_top = -110
	_confirm_panel.offset_bottom = 110
	_confirm_panel.z_index = 5
	add_child(_confirm_panel)
	var confirm_column := VBoxContainer.new()
	confirm_column.add_theme_constant_override("separation", 14)
	_confirm_panel.add_child(confirm_column)
	var confirm_heading := Label.new()
	confirm_heading.text = "LEAVE THIS EXPEDITION?"
	confirm_heading.add_theme_font_size_override("font_size", 20)
	confirm_heading.add_theme_color_override("font_color", Color(1.0, 0.79, 0.68))
	confirm_column.add_child(confirm_heading)
	var confirm_text := Label.new()
	confirm_text.text = "If you are in an expedition, temporary run progress will be lost. Your selected wayfarer and permanent profile will remain saved."
	confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_text.add_theme_font_size_override("font_size", 13)
	confirm_text.add_theme_color_override("font_color", Color(0.73, 0.81, 0.91))
	confirm_column.add_child(confirm_text)
	var confirm_actions := HBoxContainer.new()
	confirm_actions.add_theme_constant_override("separation", 10)
	confirm_column.add_child(confirm_actions)
	_stay_button = _make_button("STAY HERE", false)
	_stay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stay_button.pressed.connect(_close_return_confirmation)
	confirm_actions.add_child(_stay_button)
	_leave_button = _make_button("RETURN TO TITLE", true)
	_leave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leave_button.pressed.connect(_confirm_return_to_title)
	confirm_actions.add_child(_leave_button)
	_confirm_panel.hide()

func _make_panel(minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.085, 0.98)
	style.border_color = Color(0.25, 0.57, 0.77, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_button(caption: String, emphasized: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.25, 0.39, 0.96) if emphasized else Color(0.045, 0.07, 0.13, 0.92)
	normal.border_color = Color(0.31, 0.72, 0.91, 0.95) if emphasized else Color(0.18, 0.31, 0.46, 0.88)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.33, 0.49, 1.0)
	hover.border_color = Color(0.45, 0.83, 0.98, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	return button

func _open_settings() -> void:
	if is_instance_valid(_settings_panel):
		_settings_panel.queue_free()
	_settings_panel = SETTINGS_PANEL_SCENE.instantiate() as Control
	_settings_panel.closed.connect(_on_settings_closed)
	add_child(_settings_panel)

func _on_settings_closed() -> void:
	if is_instance_valid(_settings_panel):
		_settings_panel.queue_free()
	_settings_panel = null
	_resume_button.grab_focus()

func _open_return_confirmation() -> void:
	_pause_panel.hide()
	_confirm_panel.show()
	_leave_button.grab_focus()

func _close_return_confirmation() -> void:
	_confirm_panel.hide()
	_pause_panel.show()
	_resume_button.grab_focus()

func _confirm_return_to_title() -> void:
	_confirm_panel.hide()
	return_to_title_requested.emit()

func _on_resume() -> void:
	hide()
	resume_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("pause"):
		return
	if is_instance_valid(_settings_panel):
		return
	get_viewport().set_input_as_handled()
	if _confirm_panel.visible:
		_close_return_confirmation()
	else:
		_on_resume()

func open_menu() -> void:
	show()
	_confirm_panel.hide()
	_pause_panel.show()
	_resume_button.grab_focus()
