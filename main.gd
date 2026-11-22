extends Node
## App shell. This is the only entry scene, and it owns exactly one thing:
## which screen is on stage. Boot always lands on the title screen, so the
## arena never starts by itself.
##
## Screens: modules/title/title.tscn  <->  modules/stage/stage.tscn
## Global keys live here so they work on both screens.

const TITLE_SCENE := preload("res://modules/title/title.tscn")
const STAGE_SCENE := preload("res://modules/stage/stage.tscn")

var _screen: Node = null


func _ready() -> void:
	# The stage pauses the tree on death; the shell has to stay awake so it can
	# still swap screens while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	show_title()


func show_title() -> void:
	var title := TITLE_SCENE.instantiate()
	title.start_requested.connect(start_run)
	title.quit_requested.connect(_on_quit_requested)
	_swap(title)


func start_run() -> void:
	var stage := STAGE_SCENE.instantiate()
	stage.restart_requested.connect(start_run)
	stage.title_requested.connect(show_title)
	_swap(stage)


func _swap(screen: Node) -> void:
	get_tree().paused = false
	Game.running = false
	Game.clear_scene_refs()
	if is_instance_valid(_screen):
		remove_child(_screen)
		_screen.queue_free()
	_screen = screen
	add_child(_screen)


func _on_quit_requested() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		_toggle_fullscreen()
	elif event.is_action_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))


func _toggle_fullscreen() -> void:
	var window := get_window()
	if window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN or window.mode == Window.MODE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
	else:
		window.mode = Window.MODE_FULLSCREEN
