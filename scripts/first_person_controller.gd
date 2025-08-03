# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 7.0
## Speed of jump.
@export var jump_velocity : float = 4.5
## How fast do we run?
@export var sprint_speed : float = 10.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

@export_group("Footsteps")
@export var footstep_player : AudioStreamPlayer
@export var footsteps : Array[AudioStream]
@export var footstep_frequency : float = 1.0
@export var footstep_variance : float = 0.1

@export_group("Beats")
@export var beat_player : AudioStreamPlayer
@export var beats : Array[AudioStream]

@export_group("Light")
@export var player_light : OmniLight3D

@export_category("Lerping")
@export var min_y : float = 10.0
@export var max_y : float = 78.0 
 
@export_group("Room Size")
@export var room_size_min : float = 0.0
@export var room_size_max : float = 1.0

@export_group("Damping")
@export var damping_min : float = 0.0
@export var damping_max : float = 1.0

@export_group("Spread")
@export var spread_min : float = 0.0
@export var spread_max : float = 1.0

@export_group("Predelay feedback")
@export var predelay_feedback_min : float = 0.0
@export var predelay_feedback_max : float = 0.4

@export_group("Beat volume")
@export var beat_volume_min : float = -48.0
@export var beat_volume_max : float = 0.0

@export_group("Beat frequency")
@export var beat_frequency_min : float = 20.0
@export var beat_frequency_max : float = 1.0

@export_group("Beat variance")
@export var beat_variance_min : float = 3.0
@export var beat_variance_max : float = 0.1

@export_group("Light energy")
@export var light_energy_min : float = 1.5
@export var light_energy_max : float = 0.25

@export_group("Fog density")
@export var fog_density_min : float = 0.0
@export var fog_density_max : float = 1.0

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false
var time_since_last_footstep : float = 0.0
var time_since_last_beat : float = 0.0

var beat_frequency : float = beat_frequency_min
var beat_variance : float = beat_variance_min

var rng = RandomNumberGenerator.new();
var reverb : AudioEffectReverb
var environment : Environment

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider

func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	
	var bus_index = AudioServer.get_bus_index("Master")
	reverb = AudioServer.get_bus_effect(bus_index, 0) as AudioEffectReverb
	
	if not reverb:
		print("Warning: No AudioEffectReverb found on Master bus!")
		
	var world_env = get_node("../WorldEnvironment")
	environment = world_env.environment
	
	if not environment:
		print("Warning: No Environment found in scene!")

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capturing
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta

	# Apply jumping
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity

	# Modify speed based on sprinting
	if can_sprint and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.y = 0
	
	update_lerps(abs(position.y))
	
	time_since_last_footstep += delta;
	
	if velocity.length() > 0 && time_since_last_footstep > (footstep_frequency + rng.randf_range(-footstep_variance, footstep_variance)):
		footstep_player.stream = footsteps.filter(func(footstep): return footstep != footstep_player.stream).pick_random()
		footstep_player.playing = true
		time_since_last_footstep = 0.0;
	
	time_since_last_beat += delta;
	
	if time_since_last_beat > (beat_frequency + rng.randf_range(-beat_variance, beat_variance)):
		beat_player.stream = beats.filter(func(beat): return beat != beat_player.stream).pick_random()
		beat_player.playing = true
		time_since_last_beat = 0.0
	
	# Use velocity to actually move
	move_and_slide()

func update_lerps(player_y : float):
	var normalized_y = clamp((player_y - min_y) / (max_y - min_y), 0.0, 1.0)
	
	reverb.room_size = lerp(room_size_min, room_size_max, normalized_y)
	reverb.damping = lerp(damping_min, damping_max, normalized_y)
	reverb.spread = lerp(spread_min, spread_max, normalized_y)
	reverb.predelay_feedback = lerp(predelay_feedback_min, predelay_feedback_max, normalized_y)

	beat_player.volume_db = lerp(beat_volume_min, beat_volume_max, normalized_y)
	beat_frequency = lerp(beat_frequency_min, beat_frequency_max, normalized_y)
	beat_variance = lerp(beat_variance_min, beat_variance_max, normalized_y)
	
	player_light.light_energy = lerp(light_energy_min, light_energy_max, normalized_y)
	environment.fog_density = lerp(fog_density_min, fog_density_max, normalized_y)

## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
