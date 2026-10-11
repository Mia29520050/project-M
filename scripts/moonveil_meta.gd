extends Node

const SAVE_PATH := "user://moonveil_meta.json"
const DEFAULT_REGION := "whispering_woods"

# Long-term progression lives outside a run. Current combat XP, level and Moonshards
# intentionally remain on the Player instance and are discarded when a run ends.
var permanent_currency: int = 0
var permanent_upgrades: Array[String] = []
var story_flags: Dictionary = {}
var unlocked_regions: Array[String] = [DEFAULT_REGION]

func _ready() -> void:
	load_progress()

func has_permanent_upgrade(upgrade_id: String) -> bool:
	return permanent_upgrades.has(upgrade_id)

func unlock_permanent_upgrade(upgrade_id: String) -> void:
	if upgrade_id.is_empty() or permanent_upgrades.has(upgrade_id):
		return
	permanent_upgrades.append(upgrade_id)
	save_progress()

func add_permanent_currency(amount: int) -> void:
	if amount <= 0:
		return
	permanent_currency += amount
	save_progress()

func set_story_flag(flag_id: String, value: bool = true) -> void:
	if flag_id.is_empty():
		return
	story_flags[flag_id] = value
	save_progress()

func has_story_flag(flag_id: String) -> bool:
	return bool(story_flags.get(flag_id, false))

func unlock_region(region_id: String) -> void:
	if region_id.is_empty() or unlocked_regions.has(region_id):
		return
	unlocked_regions.append(region_id)
	save_progress()

func is_region_unlocked(region_id: String) -> bool:
	return unlocked_regions.has(region_id)

func save_progress() -> void:
	var data := {
		"version": 1,
		"permanent_currency": permanent_currency,
		"permanent_upgrades": permanent_upgrades,
		"story_flags": story_flags,
		"unlocked_regions": unlocked_regions,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Moonveil could not save long-term progression: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Moonveil could not read long-term progression: %s" % FileAccess.get_open_error())
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("Moonveil save was invalid; using default long-term progression.")
		return
	var data: Dictionary = parsed
	permanent_currency = maxi(0, int(data.get("permanent_currency", 0)))
	permanent_upgrades.clear()
	var saved_upgrades: Variant = data.get("permanent_upgrades", [])
	if saved_upgrades is Array:
		for item in saved_upgrades:
			if item is String and not permanent_upgrades.has(item):
				permanent_upgrades.append(item)
	story_flags.clear()
	var saved_flags: Variant = data.get("story_flags", {})
	if saved_flags is Dictionary:
		story_flags = saved_flags.duplicate(true)
	unlocked_regions.clear()
	var saved_regions: Variant = data.get("unlocked_regions", [DEFAULT_REGION])
	if saved_regions is Array:
		for item in saved_regions:
			if item is String and not unlocked_regions.has(item):
				unlocked_regions.append(item)
	if not unlocked_regions.has(DEFAULT_REGION):
		unlocked_regions.append(DEFAULT_REGION)
