extends HSlider

## Audio bus this slider controls (linear volume 0..1).
@export var bus_name: StringName = &"Master"

var _bus_index: int = -1

func _ready() -> void:
	_bus_index = AudioServer.get_bus_index(bus_name)
	if _bus_index < 0:
		push_error("Volume slider references unknown audio bus '%s'." % bus_name)
		editable = false
		return
	value = GameSettings.load_volume(bus_name)
	value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: float) -> void:
	AudioServer.set_bus_volume_linear(_bus_index, new_value)
	GameSettings.save_volume(bus_name, new_value)
