class_name CompetitiveTowerLevelRules
extends TowerLevelRules

## Exact cooldown setup: piece id → cooldown seconds.
## A piece id is the tower piece node name, Block_<layer>_<index> (e.g. Block_03_01),
## with layer 0 at the bottom and index 0..pieces_per_layer-1.
## Not checked for adjacency. A piece in a locked top layer can't be pulled out, so the round can't be won.
@export var piece_cooldowns: Dictionary[StringName, float] = {}

func get_cooldown_setup() -> Dictionary[StringName, float]:
	return piece_cooldowns.duplicate()
