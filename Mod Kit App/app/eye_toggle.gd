extends Button

# The eye button next to a Lay or boss: open eye = in the mod (active=true),
# crossed out = switched off (active=false).

var on = true:
	set(value):
		on = value
		tooltip_text = "In the mod: click to switch it off" if on else "Switched off: click to put it in the mod"
		queue_redraw()


func _init():
	custom_minimum_size = Vector2(96, 96)
	focus_mode = Control.FOCUS_NONE
	on = true


func _draw():
	var c = size / 2
	var w = size.x * 0.34
	var h = size.y * 0.2
	var color = Color.WHITE if on else Color(1, 1, 1, 0.4)
	var outline = PackedVector2Array()
	for i in range(21):
		var t = i / 20.0
		outline.append(c + Vector2(lerpf(-w, w, t), -h * sin(PI * t)))
	for i in range(21):
		var t = 1.0 - i / 20.0
		outline.append(c + Vector2(lerpf(-w, w, t), h * sin(PI * t)))
	draw_polyline(outline, color, 4.0, true)
	draw_circle(c, h * 0.62, color)
	draw_circle(c, h * 0.25, Color(0, 0, 0, 0.8))
	if !on:
		draw_line(c + Vector2(-w, h * 1.5), c + Vector2(w, -h * 1.5), Color("#ff5c5c"), 6.0, true)
