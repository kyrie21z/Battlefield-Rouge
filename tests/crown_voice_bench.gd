extends Node3D
var opening: OpeningSequence
var player: Player
var voice: CrownVoiceSystem
var status: Label
func _ready() -> void:
	opening = preload("res://ui/cinematics/opening_sequence.tscn").instantiate() as OpeningSequence
	add_child(opening)
	opening.set_process(false)
	opening.skip()
	opening.crown.queue_free()
	opening.subtitle.hide()
	player = opening.player
	voice = player.get_node("CrownVoiceSystem") as CrownVoiceSystem
	voice.process_mode = Node.PROCESS_MODE_INHERIT
	voice.set_cinematic_hidden(false)
	voice.configure_history(1,0,"")
	var layer := CanvasLayer.new()
	add_child(layer)
	status = Label.new()
	status.position = Vector2(30,28)
	status.add_theme_font_size_override("font_size",24)
	status.add_theme_color_override("font_color",Color(0.08,0.08,0.08))
	layer.add_child(status)
func _process(_delta: float) -> void:
	status.text = "随行皇冠 / THE CROWN\n碎裂 %d · 自发光 %.4f\n0–4 改变碎裂 / F1 首次 / F2 早期失败 / F3 深渊失败 / F4 深层失败 / F5 老练" % [voice.fracture_level,voice.strength]
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode >= KEY_0 and event.physical_keycode <= KEY_4:
		voice.set_fracture_level(event.physical_keycode - KEY_0)
		(player.get_node("ShadowBody") as ProtagonistBody).set_fracture_level(event.physical_keycode - KEY_0)
	match event.physical_keycode:
		KEY_F1: voice.configure_history(1,0,"")
		KEY_F2: voice.configure_history(2,1,"combat")
		KEY_F3: voice.configure_history(3,1,"abyss")
		KEY_F4: voice.configure_history(4,4,"combat")
		KEY_F5: voice.configure_history(8,2,"combat")
