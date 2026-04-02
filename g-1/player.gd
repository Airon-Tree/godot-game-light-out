extends CharacterBody2D

@export var move_speed: float = 120.0
@export var interaction_distance: float = 24.0
@export var darkness_light_radius: float = 96.0
@export var darkness_light_energy: float = 1.2

const FOOTSTEP_INTERVAL: float = 0.4
const FOOTSTEP_RADIUS_LIGHT_ON: float = 48.0
const FOOTSTEP_RADIUS_LIGHT_OFF: float = 80.0

var nearby_interactable: Node = null
var _footstep_timer: float = 0.0

@onready var _darkness_light: PointLight2D = get_node_or_null("DarknessLight")
@onready var _footstep_audio: AudioStreamPlayer2D = get_node_or_null("FootstepAudio")


func _ready() -> void:
	var game_manager := _get_game_manager()
	if game_manager != null and game_manager.has_signal("light_state_changed") and not game_manager.light_state_changed.is_connected(_on_light_state_changed):
		game_manager.light_state_changed.connect(_on_light_state_changed)

	_apply_light_state()


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * move_speed
	move_and_slide()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

	_update_footsteps(delta, input_vector)


func set_nearby_interactable(interactable: Node) -> void:
	nearby_interactable = interactable


func clear_nearby_interactable(interactable: Node = null) -> void:
	if interactable == null or nearby_interactable == interactable:
		nearby_interactable = null


func _try_interact() -> void:
	if nearby_interactable == null:
		return

	if not is_instance_valid(nearby_interactable):
		nearby_interactable = null
		return

	if nearby_interactable is Node2D:
		var interactable_node := nearby_interactable as Node2D
		if global_position.distance_to(interactable_node.global_position) > interaction_distance:
			return

	if nearby_interactable.has_method("interact"):
		nearby_interactable.interact(self)


func _update_footsteps(delta: float, input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		_footstep_timer = 0.0
		return

	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return

	_emit_footstep()
	_footstep_timer = FOOTSTEP_INTERVAL


func _emit_footstep() -> void:
	var game_manager := _get_game_manager()
	if game_manager == null:
		return

	var radius := FOOTSTEP_RADIUS_LIGHT_OFF
	if game_manager.has_method("is_light_on") and game_manager.is_light_on():
		radius = FOOTSTEP_RADIUS_LIGHT_ON

	if game_manager.has_method("emit_sound"):
		game_manager.emit_sound(global_position, radius, "footstep")

	if _footstep_audio != null and not _footstep_audio.playing:
		_footstep_audio.play()

	# print("Footstep emitted at %s with radius %.1f" % [global_position, radius])


func _get_game_manager() -> Node:
	var main_root := get_tree().current_scene
	if main_root != null and main_root.has_method("emit_sound"):
		return main_root

	return null


func _on_light_state_changed(_is_on: bool) -> void:
	_apply_light_state()


func _apply_light_state() -> void:
	if _darkness_light == null:
		return

	var game_manager := _get_game_manager()
	var lights_on := true
	if game_manager != null and game_manager.has_method("is_light_on"):
		lights_on = game_manager.is_light_on()

	_darkness_light.enabled = not lights_on
	_darkness_light.texture_scale = maxf(darkness_light_radius / 128.0, 0.01)
	_darkness_light.energy = darkness_light_energy
