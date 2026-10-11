extends Node

const ACCOUNT_SAVE_PATH := "user://moonveil_account.json"
const CHARACTER_DIRECTORY := "user://moonveil_characters"
const SCHEMA_VERSION := 1
const DEFAULT_CHARACTER_ID := "moonveil_mage"

# This is a storage scaffold only. The current playable run still initializes its
# temporary level, XP, equipment and potion stock on the Player node.
var account_save_path := ACCOUNT_SAVE_PATH
var character_directory := CHARACTER_DIRECTORY
var account_data: Dictionary = {}
var active_character_data: Dictionary = {}

func _ready() -> void:
	load_account()
	var active_id := String(account_data.get("active_character_id", DEFAULT_CHARACTER_ID))
	active_character_data = load_character(active_id)
	if active_character_data.is_empty():
		# A missing/corrupt selected character should not leave the game without a usable profile.
		account_data["active_character_id"] = DEFAULT_CHARACTER_ID
		active_character_data = default_character_profile()

func _default_account() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"active_character_id": DEFAULT_CHARACTER_ID,
		"unlocked_character_ids": [DEFAULT_CHARACTER_ID],
		"banked_currency": 0,
		"shared_stash": []
	}

func default_character_profile(
	character_id: String = DEFAULT_CHARACTER_ID,
	display_name: String = "Moonveil Mage",
	class_id: String = "moon_mage"
) -> Dictionary:
	# Starter templates only: the sword duelist's balance is provisional and not yet playable.
	var attributes := {
		"max_hp": 100,
		"max_mana": 60,
		"base_damage": 12,
		"magic_damage": 24
	}
	var skills: Array[String] = ["moonbolt"]
	var equipment := {
		"weapon_id": "apprentice_wand",
		"head_id": "",
		"body_id": "",
		"accessory_id": ""
	}
	if class_id == "sword_duelist":
		attributes = {
			"max_hp": 115,
			"max_mana": 35,
			"base_damage": 16,
			"magic_damage": 0
		}
		skills = ["quick_slash", "evasive_step"]
		equipment["weapon_id"] = "training_sword"

	return {
		"schema_version": SCHEMA_VERSION,
		"character_id": character_id,
		"display_name": display_name,
		"class_id": class_id,
		"carried_currency": 0,
		"progression": {
			"level": 1,
			"experience": 0,
			"xp_to_next": 50
		},
		"attributes": attributes,
		"unlocked_skills": skills,
		"equipment": equipment
	}

func _is_valid_id(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges():
		return false
	var pattern := RegEx.new()
	pattern.compile("^[a-zA-Z0-9_-]+$")
	return pattern.search(value) != null

func load_account() -> bool:
	if not FileAccess.file_exists(account_save_path):
		account_data = _default_account()
		return true

	var file := FileAccess.open(account_save_path, FileAccess.READ)
	if file == null:
		push_error("MoonveilProfiles could not read the account save: %s" % FileAccess.get_open_error())
		account_data = _default_account()
		return false

	var parser := JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not (parser.data is Dictionary):
		push_warning("Moonveil account save is invalid (%s); defaults loaded in memory without overwriting the file." % parser.get_error_message())
		account_data = _default_account()
		return false

	var saved: Dictionary = parser.data
	if int(saved.get("schema_version", -1)) != SCHEMA_VERSION:
		push_warning("Moonveil account schema version is unsupported; defaults loaded in memory without overwriting the file.")
		account_data = _default_account()
		return false

	account_data = _normalize_account(saved)
	return true

func _normalize_account(saved: Dictionary) -> Dictionary:
	var normalized := _default_account()
	normalized["banked_currency"] = maxi(0, int(saved.get("banked_currency", 0)))

	var unlocked: Array[String] = []
	var saved_unlocked: Variant = saved.get("unlocked_character_ids", [DEFAULT_CHARACTER_ID])
	if saved_unlocked is Array:
		for item in saved_unlocked:
			if item is String and _is_valid_id(item) and not unlocked.has(item):
				unlocked.append(item)
	if not unlocked.has(DEFAULT_CHARACTER_ID):
		unlocked.push_front(DEFAULT_CHARACTER_ID)
	normalized["unlocked_character_ids"] = unlocked

	var active_id := String(saved.get("active_character_id", DEFAULT_CHARACTER_ID))
	if not _is_valid_id(active_id) or not unlocked.has(active_id):
		active_id = DEFAULT_CHARACTER_ID
	normalized["active_character_id"] = active_id

	var normalized_stash: Array[Dictionary] = []
	var saved_stash: Variant = saved.get("shared_stash", [])
	if saved_stash is Array:
		for entry in saved_stash:
			if not (entry is Dictionary):
				continue
			var item_id := String(entry.get("item_id", ""))
			var quantity := int(entry.get("quantity", 0))
			if _is_valid_id(item_id) and quantity > 0:
				var found := false
				for existing in normalized_stash:
					if String(existing.get("item_id", "")) == item_id:
						existing["quantity"] = int(existing.get("quantity", 0)) + quantity
						found = true
						break
				if not found:
					normalized_stash.append({"item_id": item_id, "quantity": quantity})
	normalized["shared_stash"] = normalized_stash
	return normalized

func load_character(character_id: String) -> Dictionary:
	if not _is_valid_id(character_id):
		return {}
	var path := _character_path(character_id)
	if not FileAccess.file_exists(path):
		return default_character_profile() if character_id == DEFAULT_CHARACTER_ID else {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MoonveilProfiles could not read character '%s': %s" % [character_id, FileAccess.get_open_error()])
		return {}
	var parser := JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not (parser.data is Dictionary):
		push_warning("Character save '%s' is invalid (%s); it was left untouched." % [character_id, parser.get_error_message()])
		return {}
	var saved: Dictionary = parser.data
	if int(saved.get("schema_version", -1)) != SCHEMA_VERSION or String(saved.get("character_id", "")) != character_id:
		push_warning("Character save '%s' has an unsupported schema or mismatched ID; it was left untouched." % character_id)
		return {}
	return _normalize_character(saved, character_id)

func _normalize_character(saved: Dictionary, character_id: String) -> Dictionary:
	var defaults := default_character_profile(
		character_id,
		String(saved.get("display_name", "Wayfarer")),
		String(saved.get("class_id", "unknown"))
	)
	var normalized := saved.duplicate(true)
	normalized["schema_version"] = SCHEMA_VERSION
	normalized["character_id"] = character_id
	normalized["display_name"] = String(saved.get("display_name", defaults["display_name"]))
	normalized["class_id"] = String(saved.get("class_id", defaults["class_id"]))
	normalized["carried_currency"] = maxi(0, int(saved.get("carried_currency", 0)))

	var progression: Dictionary = defaults["progression"].duplicate(true)
	var saved_progression: Variant = saved.get("progression", {})
	if saved_progression is Dictionary:
		progression["level"] = maxi(1, int(saved_progression.get("level", progression["level"])))
		progression["experience"] = maxi(0, int(saved_progression.get("experience", progression["experience"])))
		progression["xp_to_next"] = maxi(1, int(saved_progression.get("xp_to_next", progression["xp_to_next"])))
	normalized["progression"] = progression

	var attributes: Dictionary = defaults["attributes"].duplicate(true)
	var saved_attributes: Variant = saved.get("attributes", {})
	if saved_attributes is Dictionary:
		for key in attributes.keys():
			var minimum_value := 0 if key == "magic_damage" else 1
			attributes[key] = maxi(minimum_value, int(saved_attributes.get(key, attributes[key])))
	normalized["attributes"] = attributes

	var skills: Array[String] = []
	var saved_skills: Variant = saved.get("unlocked_skills", defaults["unlocked_skills"])
	if saved_skills is Array:
		for skill in saved_skills:
			if skill is String and _is_valid_id(skill) and not skills.has(skill):
				skills.append(skill)
	normalized["unlocked_skills"] = skills

	var equipment: Dictionary = defaults["equipment"].duplicate(true)
	var saved_equipment: Variant = saved.get("equipment", {})
	if saved_equipment is Dictionary:
		for slot in equipment.keys():
			var item_id := String(saved_equipment.get(slot, equipment[slot]))
			equipment[slot] = item_id if item_id.is_empty() or _is_valid_id(item_id) else String(defaults["equipment"][slot])
	normalized["equipment"] = equipment
	return normalized

func save_account() -> bool:
	account_data = _normalize_account(account_data)
	return _write_json_atomic(account_save_path, account_save_path + ".tmp", account_data)

func save_character(character_id: String, profile: Dictionary) -> bool:
	if not _is_valid_id(character_id) or not profile is Dictionary:
		return false
	if not account_data.get("unlocked_character_ids", []).has(character_id):
		push_warning("Cannot save locked character '%s'." % character_id)
		return false
	if String(profile.get("character_id", "")) != character_id:
		push_warning("Character profile ID does not match the requested save ID.")
		return false
	var normalized := _normalize_character(profile, character_id)
	var path := _character_path(character_id)
	var temp_path := path + ".tmp"
	return _write_json_atomic(path, temp_path, normalized)

func save_active_character() -> bool:
	var active_id := String(account_data.get("active_character_id", DEFAULT_CHARACTER_ID))
	if active_character_data.is_empty():
		return false
	return save_character(active_id, active_character_data)

func set_active_character(character_id: String) -> bool:
	var unlocked: Array = account_data.get("unlocked_character_ids", [])
	if not _is_valid_id(character_id) or not unlocked.has(character_id):
		return false
	var current_id := String(account_data.get("active_character_id", DEFAULT_CHARACTER_ID))
	if character_id == current_id:
		return save_active_character()
	var profile := load_character(character_id)
	if profile.is_empty():
		return false

	# Persist the current character before switching so unsaved profile edits are not lost.
	if not active_character_data.is_empty() and not save_character(current_id, active_character_data):
		return false
	var previous_account: Dictionary = account_data.duplicate(true)
	account_data["active_character_id"] = character_id
	if not save_account():
		account_data = previous_account
		return false
	active_character_data = profile
	return true

func create_character(character_id: String, display_name: String, class_id: String) -> bool:
	if not _is_valid_id(character_id) or display_name.strip_edges().is_empty() or not _is_valid_id(class_id):
		return false
	if account_data.get("unlocked_character_ids", []).has(character_id) or FileAccess.file_exists(_character_path(character_id)):
		return false

	var profile := default_character_profile(character_id, display_name.strip_edges(), class_id)
	if not _write_json_atomic(_character_path(character_id), _character_path(character_id) + ".tmp", profile):
		return false

	var previous_account: Dictionary = account_data.duplicate(true)
	var unlocked: Array = account_data.get("unlocked_character_ids", [])
	unlocked.append(character_id)
	account_data["unlocked_character_ids"] = unlocked
	if not save_account():
		account_data = previous_account
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_character_path(character_id)))
		return false
	return true

func add_shared_item(item_id: String, quantity: int = 1) -> bool:
	if not _is_valid_id(item_id) or quantity <= 0:
		return false
	var previous_account: Dictionary = account_data.duplicate(true)
	var stash: Array = account_data.get("shared_stash", [])
	for entry in stash:
		if String(entry.get("item_id", "")) == item_id:
			entry["quantity"] = int(entry.get("quantity", 0)) + quantity
			account_data["shared_stash"] = stash
			if save_account():
				return true
			account_data = previous_account
			return false
	stash.append({"item_id": item_id, "quantity": quantity})
	account_data["shared_stash"] = stash
	if save_account():
		return true
	account_data = previous_account
	return false

func remove_shared_item(item_id: String, quantity: int = 1) -> bool:
	if not _is_valid_id(item_id) or quantity <= 0:
		return false
	var previous_account: Dictionary = account_data.duplicate(true)
	var stash: Array = account_data.get("shared_stash", [])
	for index in range(stash.size()):
		var entry: Dictionary = stash[index]
		if String(entry.get("item_id", "")) != item_id:
			continue
		var existing_quantity := int(entry.get("quantity", 0))
		if existing_quantity < quantity:
			return false
		if existing_quantity == quantity:
			stash.remove_at(index)
		else:
			entry["quantity"] = existing_quantity - quantity
		account_data["shared_stash"] = stash
		if save_account():
			return true
		account_data = previous_account
		return false
	return false

func deposit_to_bank(amount: int) -> bool:
	if amount <= 0 or active_character_data.is_empty():
		return false
	var carried_before := int(active_character_data.get("carried_currency", 0))
	var bank_before := int(account_data.get("banked_currency", 0))
	if amount > carried_before:
		return false

	var previous_account: Dictionary = account_data.duplicate(true)
	var previous_character: Dictionary = active_character_data.duplicate(true)
	active_character_data["carried_currency"] = carried_before - amount
	account_data["banked_currency"] = bank_before + amount
	if save_active_character() and save_account():
		return true

	# The two files are individually atomic; if either side fails, restore both snapshots.
	account_data = previous_account
	active_character_data = previous_character
	save_active_character()
	save_account()
	return false

func withdraw_from_bank(amount: int) -> bool:
	if amount <= 0 or active_character_data.is_empty():
		return false
	var bank_before := int(account_data.get("banked_currency", 0))
	if amount > bank_before:
		return false
	var carried_before := int(active_character_data.get("carried_currency", 0))

	var previous_account: Dictionary = account_data.duplicate(true)
	var previous_character: Dictionary = active_character_data.duplicate(true)
	account_data["banked_currency"] = bank_before - amount
	active_character_data["carried_currency"] = carried_before + amount
	if save_active_character() and save_account():
		return true

	account_data = previous_account
	active_character_data = previous_character
	save_active_character()
	save_account()
	return false

func _character_path(character_id: String) -> String:
	return "%s/%s.json" % [character_directory, character_id]

func _write_json_atomic(path: String, temp_path: String, data: Dictionary) -> bool:
	var parent_absolute := ProjectSettings.globalize_path(path).get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(parent_absolute)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("MoonveilProfiles could not create save directory (error %d)." % mkdir_error)
		return false
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("MoonveilProfiles could not open temporary save: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		push_error("MoonveilProfiles could not atomically replace save (error %d)." % rename_error)
		return false
	return true
