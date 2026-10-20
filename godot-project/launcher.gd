extends Node
# Tiny start scene: the game scene is only loaded after the Boot autoload has applied any update pack.
func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
