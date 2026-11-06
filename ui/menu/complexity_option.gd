extends OptionButton

# Item ids must match GameSettings.Complexity values.

func _ready() -> void:
	select(get_item_index(GameSettings.load_complexity()))
	item_selected.connect(_on_item_selected)

func _on_item_selected(index: int) -> void:
	GameSettings.save_complexity(get_item_id(index) as GameSettings.Complexity)
