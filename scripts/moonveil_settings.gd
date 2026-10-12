extends Node

const SETTINGS_PATH := "user://moonveil_settings.cfg"
const MODE_WINDOWED := "Windowed"
const MODE_BORDERLESS := "Borderless Fullscreen"
const MODE_EXCLUSIVE := "Exclusive Fullscreen"
const ALL_RESOLUTIONS: Array[String] = ["960x540", "1280x720", "1600x900", "1920x1080", "2560x1440"]
const DEFAULT_RESOLUTION := "1280x720"
const DEFAULT_VOLUME := 0.82
const DEFAULT_VSYNC := true
const DEFAULT_MAX_FPS := 60
const FPS_LIMIT_OPTIONS: Array[int] = [30, 60, 90, 120, 144, 240, 0]

var master_volume: float = DEFAULT_VOLUME
var display_mode: String = MODE_WINDOWED
var windowed_resolution: String = DEFAULT_RESOLUTION
var vsync_enabled: bool = DEFAULT_VSYNC
var max_fps: int = DEFAULT_MAX_FPS

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = clampf(float(config.get_value("audio", "master_volume", DEFAULT_VOLUME)), 0.0, 1.0)
		# Older settings only stored a fullscreen boolean. Do not carry that old
		# implicit fullscreen default forward; new installs/migrations start windowed.
		display_mode = String(config.get_value("display", "display_mode", MODE_WINDOWED))
		if display_mode not in get_display_mode_options():
			display_mode = MODE_WINDOWED
		windowed_resolution = String(config.get_value("display", "windowed_resolution", DEFAULT_RESOLUTION))
		vsync_enabled = bool(config.get_value("display", "vsync", DEFAULT_VSYNC))
		max_fps = int(config.get_value("performance", "max_fps", DEFAULT_MAX_FPS))
	var available_resolutions := get_available_resolutions()
	if windowed_resolution not in available_resolutions:
		windowed_resolution = DEFAULT_RESOLUTION if DEFAULT_RESOLUTION in available_resolutions else available_resolutions[0]
	_apply_all()
	_save() # Also migrates older moonveil_settings.cfg files to the windowed default.

func get_display_mode_options() -> Array[String]:
	# Godot documents exclusive fullscreen as equivalent to regular fullscreen
	# on Wayland, so don't offer a duplicate mode on the Bazzite desktop session.
	var options: Array[String] = [MODE_WINDOWED, MODE_BORDERLESS]
	if not DisplayServer.get_name().to_lower().contains("wayland"):
		options.append(MODE_EXCLUSIVE)
	return options

func get_available_resolutions() -> Array[String]:
	var screen_index := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen_index)
	var result: Array[String] = []
	for label in ALL_RESOLUTIONS:
		var size := _resolution_from_label(label)
		if size.x <= screen_size.x and size.y <= screen_size.y:
			result.append(label)
	if result.is_empty():
		result.append(DEFAULT_RESOLUTION)
	return result

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save()

func set_display_mode(value: String) -> void:
	if value not in get_display_mode_options():
		return
	display_mode = value
	_apply_display()
	_save()

func set_windowed_resolution(value: String) -> void:
	if value not in get_available_resolutions():
		return
	windowed_resolution = value
	if display_mode == MODE_WINDOWED:
		_apply_display()
	_save()

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply_vsync()
	_save()

func set_max_fps(value: int) -> void:
	if value not in FPS_LIMIT_OPTIONS:
		return
	max_fps = value
	_apply_fps_limit()
	_save()

func reset_defaults() -> void:
	master_volume = DEFAULT_VOLUME
	display_mode = MODE_WINDOWED
	windowed_resolution = DEFAULT_RESOLUTION if DEFAULT_RESOLUTION in get_available_resolutions() else get_available_resolutions()[0]
	vsync_enabled = DEFAULT_VSYNC
	max_fps = DEFAULT_MAX_FPS
	_apply_all()
	_save()

func _apply_all() -> void:
	_apply_audio()
	_apply_display()
	_apply_vsync()
	_apply_fps_limit()

func _apply_audio() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.001)))

func _apply_display() -> void:
	match display_mode:
		MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size := _resolution_from_label(windowed_resolution)
			DisplayServer.window_set_size(size)
			_center_window(size)
		MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		MODE_EXCLUSIVE:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _center_window(size: Vector2i) -> void:
	var screen_index := DisplayServer.window_get_current_screen()
	var screen_origin := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)
	var centered_position := screen_origin + Vector2i(maxi(0, int((screen_size.x - size.x) / 2)), maxi(0, int((screen_size.y - size.y) / 2)))
	DisplayServer.window_set_position(centered_position)

func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

func _apply_fps_limit() -> void:
	Engine.max_fps = max_fps

func _resolution_from_label(label: String) -> Vector2i:
	var parts := label.split("x")
	if parts.size() != 2:
		return Vector2i(1280, 720)
	return Vector2i(maxi(320, int(parts[0])), maxi(240, int(parts[1])))

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "display_mode", display_mode)
	config.set_value("display", "windowed_resolution", windowed_resolution)
	config.set_value("display", "vsync", vsync_enabled)
	config.set_value("performance", "max_fps", max_fps)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Moonveil could not save settings (error %d)." % error)
