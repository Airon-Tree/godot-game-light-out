extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.has_method("_try_interact"):
		return

	var game_manager := _get_game_manager()
	if game_manager == null or game_manager.player_has_key:
		return

	game_manager.player_has_key = true
	print("Key collected")
	hide()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func _get_game_manager() -> Node:
	return get_tree().current_scene
