extends Control

@export var collapsed_channel: TowerCollapsedChannel
@export var defused_channel: TowerDefusedChannel
## Optional: shows the final Competitive time when raised. Leave empty to never show a time.
@export var time_channel: CompetitiveTimeChannel

@export_group("Copy")
@export var win_title: String = "Tower Defused!"
@export_multiline var win_message: String = "All countdown blocks are out.\nNice work."
@export var lose_title: String = "Game Over"
@export_multiline var lose_message: String = "The tower collapsed."
@export_group("")

@onready var _title := $Center/Panel/Margin/Box/Title as Label
@onready var _message := $Center/Panel/Margin/Box/Message as Label
@onready var _time := $Center/Panel/Margin/Box/Time as Label

func _enter_tree() -> void:
	if collapsed_channel != null:
		collapsed_channel.collapsed.connect(_on_collapsed)
	if defused_channel != null:
		defused_channel.defused.connect(_on_defused)
	if time_channel != null:
		time_channel.time_recorded.connect(_on_time_recorded)

func _exit_tree() -> void:
	if collapsed_channel != null and collapsed_channel.collapsed.is_connected(_on_collapsed):
		collapsed_channel.collapsed.disconnect(_on_collapsed)
	if defused_channel != null and defused_channel.defused.is_connected(_on_defused):
		defused_channel.defused.disconnect(_on_defused)
	if time_channel != null and time_channel.time_recorded.is_connected(_on_time_recorded):
		time_channel.time_recorded.disconnect(_on_time_recorded)

func _on_collapsed() -> void:
	_show_result(false)

func _on_defused() -> void:
	_show_result(true)

func _on_time_recorded(seconds: float) -> void:
	_time.text = "Time: %s" % CompetitiveTimeChannel.format_seconds(seconds)
	_time.show()

func _show_result(won: bool) -> void:
	if visible:
		return
	_title.text = win_title if won else lose_title
	_message.text = win_message if won else lose_message
	show()
