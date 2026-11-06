class_name TowerCollapsedChannel
extends Resource

signal collapsed

func raise() -> void:
	collapsed.emit()
