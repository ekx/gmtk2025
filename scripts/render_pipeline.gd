extends Node

@export var render_viewport : SubViewport
@export var post_process_viewport : SubViewport
@export var post_process_color_rect : ColorRect
@export var final_color_rect : ColorRect

var post_process_material : ShaderMaterial
var final_material : ShaderMaterial
var first_person_controller : CharacterBody3D

var is_post_processing_enabled = true
var is_crt_enabled = true

func _ready():
	var initial_texture = render_viewport.get_texture()
	
	post_process_material = post_process_color_rect.material as ShaderMaterial
	post_process_material.set_shader_parameter("source_texture", initial_texture)
	
	var post_processed_texture = post_process_viewport.get_texture()
	
	final_material = final_color_rect.material as ShaderMaterial
	final_material.set_shader_parameter("source_texture", post_processed_texture)
	
	first_person_controller = render_viewport.find_child("FirstPersonController", true, false)

func _input(event):
	if event.is_action_pressed("toggle_shaders"):
		toggle_shaders()

func _unhandled_input(event):
	first_person_controller._unhandled_input(event)

func toggle_shaders():
	if is_post_processing_enabled && is_crt_enabled:
		is_post_processing_enabled = false;
		is_crt_enabled = false;
	elif !is_post_processing_enabled && !is_crt_enabled:
		is_post_processing_enabled = true;
	else:
		is_crt_enabled = true;
	
	post_process_material.set_shader_parameter("enabled", is_post_processing_enabled)
	final_material.set_shader_parameter("enabled", is_crt_enabled)
