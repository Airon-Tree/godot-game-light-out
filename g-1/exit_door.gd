extends Area2D

@export var interaction_prompt_text: String = "Use exit"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact(player: Node) -> void:
	var game_manager := _get_game_manager()
	if game_manager == null:
		return

	if not game_manager.player_has_key:
		print("Exit locked")
		return

	if game_manager.has_method("complete_level"):
		game_manager.complete_level()
	else:
		print("Level complete")


func _on_body_entered(body: Node) -> void:
	if body.has_method("set_nearby_interactable"):
		body.set_nearby_interactable(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("clear_nearby_interactable"):
		body.clear_nearby_interactable(self)


func _get_game_manager() -> Node:
	return get_tree().current_scene
