extends RefCounted

# The app's look, taken from the game itself: its fonts (UaCadet for titles and
# buttons, Kalam for texts), its main menu background and logo, and Godot's
# default buttons, which the game uses too.

const TITLE_FONT = "res://Reuse/UaCadet-2068.ttf"
const TEXT_FONT = "res://Reuse/Kalam-Regular.ttf"
const BOLD_FONT = "res://Reuse/Kalam-Bold.ttf"
const BACKGROUND = "res://art/characters/bg/Main.png"
const LOGO = "res://art/characters/bg/Logo.png"

const RED = Color("#ff5c5c")
const GREEN = Color("#7dff8a")
const PANEL = Color(0.07, 0.05, 0.1, 0.94)
const MARGIN = 28


static func make_theme() -> Theme:
	var theme = Theme.new()
	theme.default_font = load(TITLE_FONT)
	theme.default_font_size = 32
	# White text with a black outline, like the game's labels.
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_outline_color", "Label", Color.BLACK)
	theme.set_constant("outline_size", "Label", 10)
	theme.set_font("font", "LineEdit", load(TEXT_FONT))
	theme.set_font_size("font_size", "LineEdit", 30)
	theme.set_font("font", "CheckBox", load(TEXT_FONT))
	theme.set_font_size("font_size", "CheckBox", 26)
	theme.set_font("font", "PopupMenu", load(TEXT_FONT))
	theme.set_font_size("font_size", "PopupMenu", 30)
	theme.set_constant("h_separation", "PopupMenu", 12)
	theme.set_constant("v_separation", "PopupMenu", 10)
	theme.set_font_size("font_size", "TooltipLabel", 22)
	# Wide scroll bars: the app is made for a mouse on a small portrait window.
	var grabber = StyleBoxFlat.new()
	grabber.bg_color = Color(1, 1, 1, 0.55)
	grabber.set_corner_radius_all(6)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	var grabber_hl = grabber.duplicate()
	grabber_hl.bg_color = Color(1, 1, 1, 0.8)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber_hl)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber_hl)
	var track = StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.3)
	track.set_corner_radius_all(6)
	track.content_margin_left = 8
	track.content_margin_right = 8
	theme.set_stylebox("scroll", "VScrollBar", track)
	return theme


static func panel_style(alpha = 0.94) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, alpha)
	style.set_corner_radius_all(18)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.75)
	style.set_content_margin_all(24)
	return style


static func button(text: String, font_size = 36, min_height = 96) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, min_height)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func small_button(text: String, font_size = 28) -> Button:
	var b = button(text, font_size, 64)
	b.custom_minimum_size.x = 64
	return b


static func label(text: String, font_size = 32) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l


# A wrapping text in the game's handwritten font.
static func text(content: String, font_size = 26) -> Label:
	var l = Label.new()
	l.text = content
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", load(TEXT_FONT))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	return l


static func vbox(separation = 16) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation = 16) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func spacer(horizontal = true) -> Control:
	var c = Control.new()
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func margin(child: Control, all = MARGIN) -> MarginContainer:
	var m = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, all)
	m.add_child(child)
	return m


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


# The usual 16:9 screen: a narrow column on each side for buttons and a wide one
# in the middle. Returns [left, center, right].
static func three_columns(screen: Control, side = 400) -> Array:
	var root = hbox(40)
	screen.add_child(full_rect(margin(root, 40)))
	var left = vbox(14)
	left.custom_minimum_size.x = side
	var center = vbox(22)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right = vbox(14)
	right.custom_minimum_size.x = side
	root.add_child(left)
	root.add_child(center)
	root.add_child(right)
	return [left, center, right]


# A scrolling list: the returned VBox is where rows go.
static func scroll_list(parent: Control) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list = vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	parent.add_child(scroll)
	return list


# A window in the middle of the screen over a dark veil. Returns
# {"root": the veil (free it to close), "panel", "body": VBox for the content,
# "title": Label}. Clicking the veil doesn't close it; use the buttons.
static func modal(host: Node, title_text: String, width = 760) -> Dictionary:
	var veil = ColorRect.new()
	veil.color = Color(0, 0, 0, 0.6)
	full_rect(veil)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(veil)
	var center = CenterContainer.new()
	full_rect(center)
	veil.add_child(center)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var body = vbox(18)
	panel.add_child(body)
	var title = label(title_text, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	return {"root": veil, "panel": panel, "body": body, "title": title}


# A message with one OK button (or the given buttons). Calls back with the
# index of the pressed button.
static func message(host: Node, title_text: String, content: String, buttons = ["OK"], callback = null):
	var m = modal(host, title_text)
	m["body"].add_child(text(content, 26))
	var row = hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m["body"].add_child(row)
	for i in range(buttons.size()):
		var b = button(buttons[i], 32, 80)
		b.custom_minimum_size.x = 200
		row.add_child(b)
		b.pressed.connect(func():
			m["root"].queue_free()
			if callback != null:
				callback.call(i))
	return m


# Asks before deleting; the folder goes to the Recycle Bin. on_yes() deletes.
static func confirm_delete(host: Node, what: String, on_yes: Callable):
	message(host, "Delete " + what + "?", "Delete " + what + "? It is moved to the Recycle Bin, so you can still get it back from there.", ["Delete", "Cancel"], func(i):
		if i == 0:
			on_yes.call())


# The round "i" button next to a field.
static func info_button() -> Button:
	var b = Button.new()
	b.text = "i"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(52, 52)
	b.add_theme_font_override("font", load(BOLD_FONT))
	b.add_theme_font_size_override("font_size", 30)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.45, 0.9)
	style.set_corner_radius_all(26)
	b.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = Color(0.35, 0.55, 1.0)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b
