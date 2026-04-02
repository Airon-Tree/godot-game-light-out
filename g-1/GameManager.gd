extends Node2D

signal light_state_changed(is_on: bool)
signal sound_emitted(position: Vector2, radius: float, source_type: String)

enum LightState {
	LIGHT_ON,
	LIGHT_OFF,
}

var light_state: LightState = LightState.LIGHT_ON
var player_has_key: bool = false
var level_complete: bool = false
var failed: bool = false

@export var darkness_color: Color = Color(0.06, 0.06, 0.08, 1.0)

@onready var _light_status_label: Label = get_node_or_null("FeedbackUI/LightStatusLabel")
@onready var _key_status_label: Label = get_node_or_null("FeedbackUI/KeyStatusLabel")
@onready var _fail_status_label: Label = get_node_or_null("FeedbackUI/FailStatusLabel")
@onready var _win_status_label: Label = get_node_or_null("FeedbackUI/WinStatusLabel")
@onready var _darkness_overlay: CanvasModulate = get_node_or_null("DarknessOverlay")


func _ready() -> void:
	_apply_light_visual_state()


func _process(_delta: float) -> void:
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if failed and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func is_light_on() -> bool:
	return light_state == LightState.LIGHT_ON


func toggle_lights() -> void:
	if failed or level_complete:
		return

	light_state = LightState.LIGHT_OFF if is_light_on() else LightState.LIGHT_ON
	_apply_light_visual_state()
	light_state_changed.emit(is_light_on())


func reset_run_state() -> void:
	player_has_key = false
	level_complete = false
	failed = false
	light_state = LightState.LIGHT_ON
	_apply_light_visual_state()
	light_state_changed.emit(true)


func emit_sound(position: Vector2, radius: float, source_type: String) -> void:
	sound_emitted.emit(position, radius, source_type)


func complete_level() -> void:
	if failed or level_complete:
		return

	level_complete = true
	print("Level complete")


func fail_level() -> void:
	if failed or level_complete:
		return

	failed = true
	print("Player caught")


func _update_ui() -> void:
	if _light_status_label != null:
		_light_status_label.text = "Lights ON" if is_light_on() else "Lights OFF"

	if _key_status_label != null:
		_key_status_label.text = "Key collected" if player_has_key else "No key"

	if _fail_status_label != null:
		_fail_status_label.text = "Caught! Press R to restart" if failed else ""

	if _win_status_label != null:
		_win_status_label.text = "Level complete!" if level_complete else ""


func _apply_light_visual_state() -> void:
	if _darkness_overlay == null:
		return

	_darkness_overlay.color = Color.WHITE if is_light_on() else darkness_color
