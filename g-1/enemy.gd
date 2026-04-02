extends CharacterBody2D

enum State {
	PATROL,
	INVESTIGATE,
	CHASE,
}

@export var patrol_speed: float = 50.0
@export var chase_speed: float = 90.0
@export var idle_wait_min: float = 0.6
@export var idle_wait_max: float = 1.6
@export var wander_move_min: float = 0.5
@export var wander_move_max: float = 1.4
@export var vision_range_light_on: float = 180.0
@export var vision_range_light_off: float = 16.0
@export var lose_sight_time: float = 1.2
@export var catch_distance: float = 18.0
@export var hearing_range_light_on: float = 56.0
@export var hearing_range_light_off: float = 114.0
@export var investigation_arrival_distance: float = 6.0
@export_flags_2d_physics var wall_occlusion_mask: int = 16
@export var debug_occlusion: bool = false
@export_range(-1.0, 1.0, 0.01) var vision_cone_threshold: float = 0.35

var state: State = State.PATROL
var _last_seen_player: Node2D = null
var _lose_sight_timer: float = 0.0
var _facing_direction: Vector2 = Vector2.RIGHT
var _investigation_target: Vector2
var _previous_state: State = State.PATROL
var _enemy_audio_cooldown_timer: float = 0.0
var _is_wandering: bool = false
var _patrol_timer: float = 0.0
var _wander_direction: Vector2 = Vector2.RIGHT

var _rng := RandomNumberGenerator.new()

@onready var _enemy_audio: AudioStreamPlayer2D = get_node_or_null("EnemyAudio")


func _ready() -> void:
	_investigation_target = global_position
	_rng.randomize()
	_begin_idle_wait()

	var game_manager := _get_game_manager()
	if game_manager != null and game_manager.has_signal("sound_emitted") and not game_manager.sound_emitted.is_connected(_on_sound_emitted):
		game_manager.sound_emitted.connect(_on_sound_emitted)


func _physics_process(delta: float) -> void:
	var game_manager := _get_game_manager()
	if game_manager != null and (game_manager.failed or game_manager.level_complete):
		velocity = Vector2.ZERO
		return

	_enemy_audio_cooldown_timer = maxf(_enemy_audio_cooldown_timer - delta, 0.0)
	_previous_state = state

	var player := _get_player()
	var can_see_player := _can_see_player(player)

	if can_see_player:
		state = State.CHASE
		_last_seen_player = player
		_lose_sight_timer = lose_sight_time
	elif state == State.CHASE:
		_lose_sight_timer -= delta
		if _lose_sight_timer <= 0.0:
			state = State.PATROL
			_last_seen_player = null

	if state == State.PATROL and _previous_state != State.PATROL:
		_begin_idle_wait()

	match state:
		State.PATROL:
			_patrol(delta)
		State.INVESTIGATE:
			_investigate()
		State.CHASE:
			_chase()

	_play_enemy_audio_for_state_change()
	_check_catch(player)
	move_and_slide()


func _patrol(delta: float) -> void:
	_patrol_timer -= delta

	if _is_wandering:
		velocity = _wander_direction * patrol_speed
		_update_facing_direction(velocity)
		if _patrol_timer <= 0.0:
			_begin_idle_wait()
		return

	velocity = Vector2.ZERO
	if _patrol_timer <= 0.0:
		_begin_wander_move()


func _chase() -> void:
	if _last_seen_player == null or not is_instance_valid(_last_seen_player):
		state = State.PATROL
		velocity = Vector2.ZERO
		return

	var to_player := _last_seen_player.global_position - global_position
	velocity = to_player.normalized() * chase_speed if to_player.length() > 0.0 else Vector2.ZERO
	_update_facing_direction(velocity)


func _investigate() -> void:
	var to_target := _investigation_target - global_position
	if to_target.length() <= investigation_arrival_distance:
		state = State.PATROL
		_last_seen_player = null
		velocity = Vector2.ZERO
		return

	velocity = to_target.normalized() * patrol_speed
	_update_facing_direction(velocity)


func _can_see_player(player: Node2D) -> bool:
	if player == null:
		return false

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance <= 0.0 or distance > _get_current_vision_range():
		return false

	var direction_to_player := to_player.normalized()
	if _facing_direction.dot(direction_to_player) < vision_cone_threshold:
		return false

	return not _is_wall_blocking(player.global_position)


func _update_facing_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.001:
		_facing_direction = direction.normalized()


func _get_current_vision_range() -> float:
	var game_manager := _get_game_manager()
	if game_manager != null and game_manager.has_method("is_light_on") and game_manager.is_light_on():
		return vision_range_light_on

	return vision_range_light_off


func _get_current_hearing_range() -> float:
	var game_manager := _get_game_manager()
	if game_manager != null and game_manager.has_method("is_light_on") and game_manager.is_light_on():
		return hearing_range_light_on

	return hearing_range_light_off


func _get_player() -> Node2D:
	var main_root := get_tree().current_scene
	if main_root == null:
		return null

	return main_root.get_node_or_null("Player") as Node2D


func _get_game_manager() -> Node:
	return get_tree().current_scene


func _on_sound_emitted(position: Vector2, radius: float, source_type: String) -> void:
	var game_manager := _get_game_manager()
	if game_manager != null and (game_manager.failed or game_manager.level_complete):
		return

	if state == State.CHASE:
		return

	var distance_to_sound: float = global_position.distance_to(position)
	var effective_radius: float = minf(radius, _get_current_hearing_range())
	if distance_to_sound > effective_radius:
		return

	if _is_wall_blocking(position):
		if debug_occlusion:
			print("Enemy hearing blocked by wall")
		return

	_investigation_target = position
	_last_seen_player = null
	state = State.INVESTIGATE
	_play_enemy_audio()
	print("Enemy heard %s at %s and is investigating" % [source_type, position])


func _check_catch(player: Node2D) -> void:
	if player == null:
		return

	if global_position.distance_to(player.global_position) > catch_distance:
		return

	var game_manager := _get_game_manager()
	if game_manager != null and game_manager.has_method("fail_level"):
		game_manager.fail_level()


func _play_enemy_audio_for_state_change() -> void:
	if state == _previous_state:
		return

	if state == State.CHASE:
		_play_enemy_audio()


func _play_enemy_audio() -> void:
	if _enemy_audio == null:
		return

	if _enemy_audio.playing or _enemy_audio_cooldown_timer > 0.0:
		return

	_enemy_audio.play()
	_enemy_audio_cooldown_timer = 0.75


func _begin_idle_wait() -> void:
	_is_wandering = false
	_patrol_timer = _rng.randf_range(idle_wait_min, idle_wait_max)
	velocity = Vector2.ZERO


func _begin_wander_move() -> void:
	_is_wandering = true
	_patrol_timer = _rng.randf_range(wander_move_min, wander_move_max)

	var angle := _rng.randf_range(0.0, TAU)
	_wander_direction = Vector2.RIGHT.rotated(angle).normalized()


func _is_wall_blocking(target_position: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target_position, wall_occlusion_mask)
	query.exclude = [get_rid()]

	var result := space_state.intersect_ray(query)
	var blocked := not result.is_empty()
	if blocked and debug_occlusion:
		print("Enemy perception blocked by wall at %s" % [result.position])

	return blocked
