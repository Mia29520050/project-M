extends Control

const CELL_SIZE := 64.0
const CELL_GAP := 5.0
const GRID_COLUMNS := 6
const GRID_ROWS := 6
const MOONSHARD_DESCRIPTION := "Mảnh tinh thể mặt trăng. Cần 3 mảnh để thức tỉnh Moonfire Staff tại Moon Shrine."

const C_BG := Color(0.012, 0.018, 0.044, 0.58)
const C_PANEL := Color(0.027, 0.035, 0.078, 0.66)
const C_PANEL_SOFT := Color(0.045, 0.052, 0.105, 0.72)
const C_BORDER := Color(0.58, 0.64, 0.86, 0.82)
const C_ACCENT := Color(0.73, 0.78, 1.0, 1.0)
const C_TEXT := Color(0.86, 0.92, 1.0)
const C_MUTED := Color(0.62, 0.65, 0.79)
const C_HP := Color(0.91, 0.23, 0.34)
const C_MP := Color(0.17, 0.61, 0.95)
const C_XP := Color(0.60, 0.43, 0.95)

var _player: Node
var _selected_tab := "Balo"
var _selected_item := "Moonshard"
var _tab_stats: Button
var _tab_bag: Button
var _stats_content: Panel
var _bag_content: Panel
var _weapon_value: Label
var _level_label: Label
var _xp_label: Label
var _xp_bar: ProgressBar
var _hp_label: Label
var _hp_bar: ProgressBar
var _mp_label: Label
var _mp_bar: ProgressBar
var _stat_values: Dictionary = {}
var _item_buttons: Array[Button] = []
var _moonshard_button: Button
var _detail_title: Label
var _detail_description: Label
var _detail_count: Label
var _tab_stats_underline: ColorRect
var _tab_bag_underline: ColorRect
var _character_art: TextureRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_select_tab("Balo")

func refresh(current_player: Node) -> void:
	_player = current_player
	if not is_instance_valid(_player):
		return
	_refresh_character_column()
	_refresh_stats_content()
	_refresh_bag_content()

func _build_ui() -> void:
	# Explicitly capture the current scene/HUD before the blur shader samples it.
	var back_buffer := BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(back_buffer)

	# Blur and dim only the captured scene; inventory UI is drawn afterwards and stays crisp.
	var blur_overlay := ColorRect.new()
	blur_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var blur_material := ShaderMaterial.new()
	blur_material.shader = load("res://shaders/inventory_blur.gdshader") as Shader
	blur_overlay.material = blur_material
	add_child(blur_overlay)

	# The old panel occupied almost the entire 1280x720 viewport. Scale the whole
	# interface uniformly so the full-body art, item grid and text keep their ratios.
	var ui_root := Control.new()
	ui_root.position = Vector2(92, 50)
	ui_root.scale = Vector2(0.84, 0.84)
	ui_root.size = Vector2(1280, 720)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	var frame := Panel.new()
	frame.position = Vector2(22, 18)
	frame.size = Vector2(1236, 684)
	frame.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.024, 0.060, 0.50), Color(0.62, 0.66, 0.91, 0.76), 13, 1))
	ui_root.add_child(frame)

	var content := Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(content)

	# Fine moonlit dividers replace the old heavy card framing.
	var divider := ColorRect.new()
	divider.position = Vector2(568, 38)
	divider.size = Vector2(1, 606)
	divider.color = Color(0.61, 0.65, 0.86, 0.42)
	content.add_child(divider)
	var divider_glow := ColorRect.new()
	divider_glow.position = Vector2(566, 38)
	divider_glow.size = Vector2(1, 606)
	divider_glow.color = Color(0.49, 0.46, 0.85, 0.15)
	content.add_child(divider_glow)

	_build_character_column(content)
	_build_inventory_column(content)

	var close_hint := Label.new()
	close_hint.text = "%s / %s  ·  ĐÓNG TÚI ĐỒ" % [MoonveilSettings.get_control_binding_label("inventory"), MoonveilSettings.get_control_binding_label("pause")]
	close_hint.position = Vector2(918, 638)
	close_hint.size = Vector2(276, 20)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.add_theme_font_size_override("font_size", 10)
	close_hint.add_theme_color_override("font_color", C_MUTED)
	content.add_child(close_hint)

	# Tiny silver corner flourishes keep the frame ornate without adding visual bulk.
	for ornament_data in [
		[Vector2(9, 5), "✧"],
		[Vector2(1203, 5), "✧"],
		[Vector2(9, 659), "✧"],
		[Vector2(1203, 659), "✧"]
	]:
		var ornament := _make_label(frame, ornament_data[1], 13, Color(0.72, 0.76, 1.0, 0.86))
		ornament.position = ornament_data[0]
		ornament.size = Vector2(20, 18)
		ornament.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_character_column(parent: Control) -> void:
	var column := Control.new()
	column.position = Vector2(20, 34)
	column.size = Vector2(535, 610)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)

	# Full-body 2D character illustration, intentionally not a 3D viewport.
	_character_art = TextureRect.new()
	_character_art.position = Vector2(-2, 4)
	_character_art.size = Vector2(340, 510)
	_character_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_character_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_character_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_character_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_character_art)

	var character_title := Label.new()
	character_title.text = "NHÂN VẬT"
	character_title.position = Vector2(24, 4)
	character_title.size = Vector2(270, 24)
	character_title.add_theme_font_size_override("font_size", 11)
	character_title.add_theme_color_override("font_color", Color(0.84, 0.85, 1.0, 0.92))
	column.add_child(character_title)

	var equipment_header := _make_label(column, "TRANG BỊ", 11, C_ACCENT)
	equipment_header.position = Vector2(350, 38)
	equipment_header.size = Vector2(170, 20)
	equipment_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_decorative_rule(column, Vector2(356, 60), 158)

	_weapon_value = _make_equipment_slot(column, Vector2(350, 70), "Vũ khí", "—", true)
	_make_equipment_slot(column, Vector2(350, 174), "Giáp", "Trống", false)
	_make_equipment_slot(column, Vector2(350, 278), "Phụ kiện", "Trống", false)

	var stat_block := Panel.new()
	stat_block.position = Vector2(0, 526)
	stat_block.size = Vector2(535, 108)
	stat_block.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.040, 0.088, 0.74), Color(0.48, 0.52, 0.76, 0.65), 9, 1))
	column.add_child(stat_block)

	_level_label = _make_label(stat_block, "CẤP ĐỘ  1", 13, C_TEXT)
	_level_label.position = Vector2(13, 8)
	_level_label.size = Vector2(125, 20)
	_xp_label = _make_label(stat_block, "XP  0 / 50", 10, C_MUTED)
	_xp_label.position = Vector2(13, 33)
	_xp_label.size = Vector2(91, 16)
	_xp_bar = _make_bar(stat_block, C_XP, 7)
	_xp_bar.position = Vector2(107, 38)
	_xp_bar.size = Vector2(414, 7)
	_hp_label = _make_label(stat_block, "HP  100 / 100", 10, Color(1.0, 0.67, 0.75))
	_hp_label.position = Vector2(13, 55)
	_hp_label.size = Vector2(105, 16)
	_hp_bar = _make_bar(stat_block, C_HP, 7)
	_hp_bar.position = Vector2(120, 60)
	_hp_bar.size = Vector2(401, 7)
	_mp_label = _make_label(stat_block, "MP  60 / 60", 10, Color(0.63, 0.82, 1.0))
	_mp_label.position = Vector2(13, 78)
	_mp_label.size = Vector2(105, 16)
	_mp_bar = _make_bar(stat_block, C_MP, 7)
	_mp_bar.position = Vector2(120, 83)
	_mp_bar.size = Vector2(401, 7)

func _make_equipment_slot(parent: Control, slot_position: Vector2, caption: String, initial_value: String, functional: bool) -> Label:
	var slot := Panel.new()
	slot.position = slot_position
	slot.size = Vector2(170, 88)
	var slot_style := _panel_style(Color(0.035, 0.042, 0.090, 0.60) if functional else Color(0.025, 0.032, 0.065, 0.42), Color(0.73, 0.76, 0.96, 0.80) if functional else Color(0.43, 0.45, 0.62, 0.46), 7, 1)
	slot.add_theme_stylebox_override("panel", slot_style)
	parent.add_child(slot)
	var icon_label := _make_label(slot, "✧" if functional else "◇", 21, C_ACCENT if functional else Color(0.54, 0.55, 0.70, 0.64))
	icon_label.position = Vector2(5, 4)
	icon_label.size = Vector2(160, 33)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _make_label(slot, caption, 10, C_MUTED)
	title.position = Vector2(5, 38)
	title.size = Vector2(160, 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var value := _make_label(slot, initial_value, 11, C_TEXT if functional else Color(0.62, 0.63, 0.73, 0.68))
	value.position = Vector2(5, 57)
	value.size = Vector2(160, 24)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return value

func _add_decorative_rule(parent: Control, rule_position: Vector2, rule_width: float) -> void:
	var rule := ColorRect.new()
	rule.position = rule_position
	rule.size = Vector2(rule_width, 1)
	rule.color = Color(0.58, 0.61, 0.88, 0.54)
	parent.add_child(rule)

func _build_inventory_column(parent: Control) -> void:
	var column := Control.new()
	column.position = Vector2(585, 34)
	column.size = Vector2(610, 610)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(column)

	var tabs := HBoxContainer.new()
	tabs.position = Vector2(0, 0)
	tabs.size = Vector2(610, 38)
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	_tab_stats = _make_tab("Chỉ số")
	_tab_stats.custom_minimum_size = Vector2(150, 38)
	_tab_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_stats.pressed.connect(func() -> void: _select_tab("Chỉ số"))
	tabs.add_child(_tab_stats)
	_tab_bag = _make_tab("Balo")
	_tab_bag.custom_minimum_size = Vector2(150, 38)
	_tab_bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bag.pressed.connect(func() -> void: _select_tab("Balo"))
	tabs.add_child(_tab_bag)
	_tab_stats_underline = ColorRect.new()
	_tab_stats_underline.position = Vector2(22, 35)
	_tab_stats_underline.size = Vector2(258, 2)
	_tab_stats_underline.color = C_ACCENT
	_tab_stats.add_child(_tab_stats_underline)
	_tab_bag_underline = ColorRect.new()
	_tab_bag_underline.position = Vector2(22, 35)
	_tab_bag_underline.size = Vector2(258, 2)
	_tab_bag_underline.color = C_ACCENT
	_tab_bag.add_child(_tab_bag_underline)

	var header_rule := ColorRect.new()
	header_rule.position = Vector2(0, 43)
	header_rule.size = Vector2(610, 1)
	header_rule.color = Color(0.54, 0.57, 0.82, 0.48)
	column.add_child(header_rule)

	_stats_content = Panel.new()
	_stats_content.position = Vector2(0, 52)
	_stats_content.size = Vector2(610, 558)
	_stats_content.add_theme_stylebox_override("panel", _panel_style(Color(0.020, 0.028, 0.065, 0.48), Color(0.51, 0.55, 0.82, 0.52), 8, 1))
	column.add_child(_stats_content)
	var stat_list := VBoxContainer.new()
	stat_list.position = Vector2(18, 16)
	stat_list.size = Vector2(574, 525)
	stat_list.add_theme_constant_override("separation", 0)
	_stats_content.add_child(stat_list)
	_add_section_header(stat_list, "THÔNG TIN NHÂN VẬT")
	_add_stat_row(stat_list, "Cấp độ", "level")
	_add_stat_row(stat_list, "Kinh nghiệm", "xp")
	_add_stat_row(stat_list, "Máu (HP)", "hp")
	_add_stat_row(stat_list, "Năng lượng (MP)", "mp")
	_add_stat_row(stat_list, "Sát thương đánh thường", "strike")
	_add_stat_row(stat_list, "Sát thương Moonbolt", "moonbolt")
	_add_stat_row(stat_list, "Lượt né hiện có / tối đa", "dodge")
	_add_stat_row(stat_list, "Moonshard", "moonshard")
	var stats_note := Label.new()
	stats_note.text = "Các chỉ số lấy trực tiếp từ nhân vật hiện tại."
	stats_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_note.add_theme_font_size_override("font_size", 11)
	stats_note.add_theme_color_override("font_color", C_MUTED)
	stats_note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stat_list.add_child(stats_note)

	_bag_content = Panel.new()
	_bag_content.position = Vector2(0, 52)
	_bag_content.size = Vector2(610, 558)
	_bag_content.add_theme_stylebox_override("panel", _panel_style(Color(0.020, 0.028, 0.065, 0.48), Color(0.51, 0.55, 0.82, 0.52), 8, 1))
	column.add_child(_bag_content)
	_build_bag_contents()

func _build_bag_contents() -> void:
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", int(CELL_GAP))
	grid.add_theme_constant_override("v_separation", int(CELL_GAP))
	grid.position = Vector2((610.0 - (CELL_SIZE * GRID_COLUMNS + CELL_GAP * (GRID_COLUMNS - 1))) * 0.5, 10.0)
	grid.size = Vector2(CELL_SIZE * GRID_COLUMNS + CELL_GAP * (GRID_COLUMNS - 1), CELL_SIZE * GRID_ROWS + CELL_GAP * (GRID_ROWS - 1))
	_bag_content.add_child(grid)

	for index in range(GRID_COLUMNS * GRID_ROWS):
		var button := Button.new()
		button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		button.size = Vector2(CELL_SIZE, CELL_SIZE)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", C_ACCENT)
		button.add_theme_color_override("font_hover_color", Color(0.95, 0.99, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		button.add_theme_stylebox_override("normal", _slot_style(false, index == 0))
		button.add_theme_stylebox_override("hover", _slot_style(true, index == 0))
		button.add_theme_stylebox_override("pressed", _slot_style(true, index == 0))
		button.text = "✧\n0" if index == 0 else ""
		button.tooltip_text = "Moonshard" if index == 0 else "Ô trống"
		if index == 0:
			_moonshard_button = button
			button.pressed.connect(_select_moonshard)
		else:
			button.pressed.connect(func() -> void: _select_empty_slot())
		_item_buttons.append(button)
		grid.add_child(button)

	var details := Panel.new()
	details.position = Vector2(14, 430)
	details.size = Vector2(582, 114)
	details.add_theme_stylebox_override("panel", _panel_style(Color(0.030, 0.035, 0.078, 0.66), Color(0.70, 0.72, 0.95, 0.78), 6, 1))
	_bag_content.add_child(details)
	var shard_icon := _make_label(details, "✧", 42, Color(0.68, 0.77, 1.0))
	shard_icon.position = Vector2(20, 16)
	shard_icon.size = Vector2(110, 78)
	shard_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shard_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var icon_rule := ColorRect.new()
	icon_rule.position = Vector2(143, 14)
	icon_rule.size = Vector2(1, 86)
	icon_rule.color = Color(0.50, 0.54, 0.78, 0.48)
	details.add_child(icon_rule)
	_detail_title = _make_label(details, "Moonshard", 14, C_ACCENT)
	_detail_title.position = Vector2(160, 10)
	_detail_title.size = Vector2(400, 22)
	_detail_description = _make_label(details, MOONSHARD_DESCRIPTION, 11, C_TEXT)
	_detail_description.position = Vector2(160, 36)
	_detail_description.size = Vector2(405, 47)
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_count = _make_label(details, "Số lượng: 0", 11, C_MUTED)
	_detail_count.position = Vector2(160, 86)
	_detail_count.size = Vector2(405, 17)

func _make_tab(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.flat = true
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", C_MUTED)
	button.add_theme_color_override("font_hover_color", C_TEXT)
	button.add_theme_color_override("font_pressed_color", C_TEXT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.set_border_width_all(0)
		button.add_theme_stylebox_override(state, style)
	return button

func _select_tab(tab_name: String) -> void:
	_selected_tab = tab_name
	_stats_content.visible = tab_name == "Chỉ số"
	_bag_content.visible = tab_name == "Balo"
	_tab_stats.add_theme_color_override("font_color", Color(0.88, 0.87, 1.0, 1.0) if tab_name == "Chỉ số" else C_MUTED)
	_tab_bag.add_theme_color_override("font_color", Color(0.88, 0.87, 1.0, 1.0) if tab_name == "Balo" else C_MUTED)
	_tab_stats_underline.visible = tab_name == "Chỉ số"
	_tab_bag_underline.visible = tab_name == "Balo"

func _refresh_character_column() -> void:
	var level := int(_player.get("level"))
	var xp := int(_player.get("xp"))
	var xp_to_next := maxi(1, int(_player.get("xp_to_next")))
	var hp := int(_player.get("hp"))
	var max_hp := maxi(1, int(_player.get("max_hp")))
	var mp := int(_player.get("mana"))
	var max_mp := maxi(1, int(_player.get("max_mana")))
	_level_label.text = "CẤP ĐỘ  %d" % level
	_xp_label.text = "XP  %d / %d" % [xp, xp_to_next]
	_set_bar(_xp_bar, xp, xp_to_next)
	_hp_label.text = "HP  %d / %d" % [hp, max_hp]
	_set_bar(_hp_bar, hp, max_hp)
	_mp_label.text = ("MP" if String(_player.get("character_id")) != "sword_duelist" else "Thể lực") + "  %d / %d" % [mp, max_mp]
	_set_bar(_mp_bar, mp, max_mp)
	_weapon_value.text = String(_player.get("weapon_name"))
	var character_id := String(_player.get("character_id"))
	var art_path := "res://assets/ui/moonveil_duelist_fullbody.svg" if character_id == "sword_duelist" else "res://assets/ui/moonveil_mage_fullbody.svg"
	var art := load(art_path) as Texture2D
	if art != null and _character_art.texture != art:
		_character_art.texture = art

func _refresh_stats_content() -> void:
	var level := int(_player.get("level"))
	var xp := int(_player.get("xp"))
	var xp_to_next := int(_player.get("xp_to_next"))
	var hp := int(_player.get("hp"))
	var max_hp := int(_player.get("max_hp"))
	var mp := int(_player.get("mana"))
	var max_mp := int(_player.get("max_mana"))
	var strike_damage := int(_player.get("base_damage")) + int(_player.get("weapon_bonus"))
	var moonbolt_damage := int(_player.get("magic_damage")) + int(_player.get("weapon_bonus")) * 2
	var dodge_charges := int(_player.get("dodge_charges"))
	var max_dodge_charges := int(_player.get("max_dodge_charges"))
	var moon_shards := int(_player.get("moon_shards"))
	var values := {
		"level": str(level),
		"xp": "%d / %d" % [xp, xp_to_next],
		"hp": "%d / %d" % [hp, max_hp],
		"mp": "%d / %d" % [mp, max_mp],
		"strike": str(strike_damage),
		"moonbolt": str(moonbolt_damage),
		"dodge": "%d / %d" % [dodge_charges, max_dodge_charges],
		"moonshard": str(moon_shards)
	}
	for key in values:
		if _stat_values.has(key):
			(_stat_values[key] as Label).text = String(values[key])

func _refresh_bag_content() -> void:
	var count := int(_player.get("moon_shards"))
	_moonshard_button.text = "✧\n%d" % count
	_moonshard_button.tooltip_text = "Moonshard  ·  %d" % count
	# The Moonshard slot represents this item type even while its quantity is zero,
	# so players can still inspect the description before finding the first shard.
	_moonshard_button.disabled = false
	_moonshard_button.add_theme_stylebox_override("normal", _slot_style(_selected_item == "Moonshard", true))
	_moonshard_button.add_theme_stylebox_override("hover", _slot_style(true, true))
	if _selected_item == "Moonshard":
		_detail_title.text = "Moonshard"
		_detail_description.text = MOONSHARD_DESCRIPTION
		_detail_count.text = "Số lượng: %d" % count

func _select_moonshard() -> void:
	_selected_item = "Moonshard"
	_refresh_bag_content()

func _select_empty_slot() -> void:
	_selected_item = ""
	_select_empty_item_details()

func _select_empty_item_details() -> void:
	_detail_title.text = "Ô trống"
	_detail_description.text = "Ô này chưa có vật phẩm."
	_detail_count.text = ""

func _add_section_header(parent: VBoxContainer, caption: String) -> void:
	var header := _make_label(parent, caption, 12, C_ACCENT)
	header.custom_minimum_size = Vector2(0, 32)
	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 1)
	separator.color = Color(0.47, 0.50, 0.72, 0.55)
	parent.add_child(separator)

func _add_stat_row(parent: VBoxContainer, caption: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 45)
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var name_label := _make_label(row, caption, 13, C_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _make_label(row, "—", 13, C_ACCENT)
	value_label.custom_minimum_size = Vector2(88, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stat_values[key] = value_label
	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 1)
	separator.color = Color(0.40, 0.43, 0.64, 0.42)
	parent.add_child(separator)

func _make_label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _make_bar(parent: Node, color: Color, bar_height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, bar_height)
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.095, 0.12, 0.19, 1.0)
	background.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _set_bar(bar: ProgressBar, current: int, maximum: int) -> void:
	bar.max_value = maxi(1, maximum)
	bar.value = clampi(current, 0, maxi(1, maximum))

func _slot_style(emphasized: bool, occupied: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.16, 0.29, 0.92) if emphasized else (Color(0.055, 0.060, 0.12, 0.70) if occupied else Color(0.025, 0.030, 0.065, 0.48))
	style.border_color = C_ACCENT if emphasized else (Color(0.53, 0.57, 0.82, 0.70) if occupied else Color(0.35, 0.39, 0.58, 0.44))
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _panel_style(background: Color, border: Color, corner_radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style
