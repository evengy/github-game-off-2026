class_name GameSettings
extends RefCounted

enum Complexity { EASY, MEDIUM, HARD, COMPETITIVE }

const PATH := "user://settings.cfg"
const SECTION := "gameplay"
const COMPLEXITY_KEY := "complexity"
const DEFAULT_COMPLEXITY := Complexity.MEDIUM
const AUDIO_SECTION := "audio"
const DEFAULT_VOLUME := 1.0

static func load_complexity() -> Complexity:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return DEFAULT_COMPLEXITY
	var value: Variant = config.get_value(SECTION, COMPLEXITY_KEY, DEFAULT_COMPLEXITY)
	if typeof(value) != TYPE_INT or not Complexity.values().has(value):
		push_warning("Unknown saved complexity %s; using Medium." % str(value))
		return DEFAULT_COMPLEXITY
	return value as Complexity

static func save_complexity(value: Complexity) -> void:
	_save_value(SECTION, COMPLEXITY_KEY, value)

## Linear volume (0..1) saved for the audio bus named `bus`.
static func load_volume(bus: StringName) -> float:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return DEFAULT_VOLUME
	var value: Variant = config.get_value(AUDIO_SECTION, String(bus), DEFAULT_VOLUME)
	if (typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT) or value < 0.0 or value > 1.0:
		push_warning("Invalid saved volume %s for bus %s; using %s." % [str(value), bus, DEFAULT_VOLUME])
		return DEFAULT_VOLUME
	return float(value)

static func save_volume(bus: StringName, value: float) -> void:
	_save_value(AUDIO_SECTION, String(bus), clampf(value, 0.0, 1.0))

static func _save_value(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	# A missing file is fine; other settings in an existing file are preserved.
	config.load(PATH)
	config.set_value(section, key, value)
	var error := config.save(PATH)
	if error != OK:
		push_error("Failed to save settings to %s (error %d)." % [PATH, error])
