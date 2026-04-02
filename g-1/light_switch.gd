extends Area2D

@export var sound_radius: float = 1200.0
@export var interaction_prompt_text: String = "Toggle lights"

@onready var _switch_audio: AudioStreamPlayer2D = get_node_or_null("SwitchAudio")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact(player: Node) -> void:
	var game_manager := _get_game_manager()
	if game_manager == null:
		return

	if game_manager.has_method("toggle_lights"):
		game_manager.toggle_lights()

	if game_manager.has_method("emit_sound"):
		game_manager.emit_sound(global_position, sound_radius, "switch")

	if _switch_audio != null:
		_switch_audio.play()

	print("LightSwitch interacted by %s at %s" % [player.name, global_position])


func _on_body_entered(body: Node) -> void:
	if body.has_method("set_nearby_interactable"):
		body.set_nearby_interactable(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("clear_nearby_interactable"):
		body.clear_nearby_interactable(self)


func _get_game_manager() -> Node:
	return get_tree().current_scene
