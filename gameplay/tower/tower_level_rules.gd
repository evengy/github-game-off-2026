class_name TowerLevelRules
extends Resource

## Topmost layer count that cannot be picked and cannot receive cooldowns.
@export_range(0, 30, 1) var locked_top_layers: int = 2
