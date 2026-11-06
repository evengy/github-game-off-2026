class_name RandomTowerLevelRules
extends TowerLevelRules

## Exact number of cooldown pieces in this level; which pieces get them is random.
@export_range(0, 200, 1) var cooldown_piece_count: int = 6
## Minimum cooldown duration (s).
@export_range(1.0, 600.0, 1.0) var cooldown_min_seconds: float = 45.0
## Maximum cooldown duration (s).
@export_range(1.0, 600.0, 1.0) var cooldown_max_seconds: float = 120.0
