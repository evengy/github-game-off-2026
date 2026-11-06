class_name TowerDefusedChannel
extends Resource

signal defused

func raise() -> void:
	defused.emit()
