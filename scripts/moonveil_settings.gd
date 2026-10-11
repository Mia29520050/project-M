extends Node

const SETTINGS_PATH := "user://moonveil_settings.cfg"

var master_volume: float = 0.82
var fullscreen_enabled: bool = false
var vsync_enabled: bool = true

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
		fullscreen_enabled = bool(config.get_value("display", "fullscreen", fullscreen_enabled))
		vsync_enabled = bool(config.get_value("display", "vsync", vsync_enabled))
	_apply_all()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.001)))
	_save()

func set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_save()

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
	_save()

func reset_defaults() -> void:
	master_volume = 0.82
	fullscreen_enabled = false
	vsync_enabled = true
	_apply_all()
	_save()

func _apply_all() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.001)))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen_enabled)
	config.set_value("display", "vsync", vsync_enabled)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Moonveil could not save settings (error %d)." % error)
