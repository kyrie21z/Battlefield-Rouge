class_name CodexTopology
extends Control
## Pure view: six edges come from the authored dual cards' required_sins.
signal card_selected(card: BoonData)
const POINTS: Array[Vector2] = [Vector2(.14, .12), Vector2(.86, .12), Vector2(.14, .88), Vector2(.86, .88)]
const INK := Color("151a23")
const PAPER := Color("f1f0e9")
var cards: Array[BoonData] = []
var eligible: Dictionary = {}
var cores: Dictionary = {}
var selected := ""
var _nodes: Array[Label] = []
var _edges: Dictionary = {}
var _phase := 0.0
var _node_styles: Array[StyleBoxFlat] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(420, 260)
	resized.connect(_layout)
	for sin_type in 4:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_nodes.append(label)
	_rebuild()

func update_state(duals: Array[BoonData], available: Dictionary, held: Dictionary, selection: String) -> void:
	cards = duals
	eligible = available
	cores = held
	selected = selection
	if is_node_ready():
		if _edges.size() != cards.size():
			_rebuild()
		_refresh_nodes()
		_layout()
		queue_redraw()

func _rebuild() -> void:
	for edge: Button in _edges.values():
		edge.free()
	_edges.clear()
	for card in cards:
		var button := Button.new()
		button.text = card.name
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", PAPER)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.pressed.connect(func(): card_selected.emit(card))
		add_child(button)
		_edges[card.id] = button
	_refresh_nodes()
	_layout()

func _refresh_nodes() -> void:
	_node_styles.clear()
	for sin_type in _nodes.size():
		var active := cores.has(sin_type)
		var label := _nodes[sin_type]
		_node_styles.append(BoonPresentation.panel(INK, BoonIdentity.COLORS[sin_type] if active else Color("566070"), 2 if active else 1))
		label.text = "%s\n%s" % [BoonIdentity.SIN_NAMES[sin_type], "核心已持有" if active else "尚缺核心"]
		label.add_theme_color_override("font_color", BoonIdentity.COLORS[sin_type] if active else Color("b8bfcc"))

func _layout() -> void:
	for sin_type in _nodes.size():
		_nodes[sin_type].position = POINTS[sin_type] * size - Vector2(56, 32)
		_nodes[sin_type].size = Vector2(112, 64)
	for card in cards:
		if card.required_sins.size() != 2 or not _edges.has(card.id):
			continue
		var a := POINTS[card.required_sins[0]]
		var b := POINTS[card.required_sins[1]]
		var midpoint := (a + b) * .5
		if a.x != b.x and a.y != b.y:
			# Separate the two crossing diagonal labels so both routes stay legible.
			midpoint = a.lerp(b, .32)
		var button: Button = _edges[card.id]
		button.position = midpoint * size - Vector2(62, 21)
		button.size = Vector2(124, 42)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_phase = fmod(_phase + delta * 2.5, TAU)
	queue_redraw()

func _draw() -> void:
	var glow := .5 + .5 * sin(_phase)
	for card in cards:
		if card.required_sins.size() != 2:
			continue
		var a := POINTS[card.required_sins[0]] * size
		var b := POINTS[card.required_sins[1]] * size
		var ready_card: bool = eligible.get(card.id, false)
		var chosen := selected == card.id
		var color := Color("677181") if chosen else Color("3e4654")
		if ready_card:
			color = Color("e7ce8c")
			draw_line(a, b, Color(color, .07 + .08 * glow), 12, true)
		draw_line(a, b, color, 2.5 if chosen or ready_card else 1.2, true)
	for sin_type in 4:
		var center := POINTS[sin_type] * size
		var rect := Rect2(center - Vector2(58, 35), Vector2(116, 70))
		draw_style_box(_node_styles[sin_type], rect)

func style_edges() -> void:
	for card in cards:
		if not _edges.has(card.id):
			continue
		var button: Button = _edges[card.id]
		var color := Color("e7ce8c") if eligible.get(card.id, false) else Color("596475")
		button.add_theme_stylebox_override("normal", _edge_style(INK, color, 2 if selected == card.id else 1))
		button.add_theme_stylebox_override("hover", _edge_style(Color("283140"), PAPER, 2))
		button.add_theme_stylebox_override("focus", _edge_style(Color(0, 0, 0, 0), PAPER, 2))

func _edge_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := BoonPresentation.panel(background, border, width)
	style.set_content_margin_all(4)
	return style
