extends Button

# A file path, not a PackedScene: scenes that link to each other would form a cyclic load.
## Scene opened when the button is pressed.
@export_file("*.tscn") var target_scene: String

func _pressed() -> void:
	get_tree().change_scene_to_file(target_scene)
