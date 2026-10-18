extends Node

# Trims a video or GIF. A player with one slider to scrub through it, play /
# pause, stop (back to the start marker) and one frame back / forward. Go to a
# frame and press "Set start here", then to another and "Set end here": the bar
# under the slider shows the part that is kept. Trim writes "<name>_trim.mp4"
# next to the file with FFmpeg (cut exactly at those frames, sound kept) and
# calls done(new file name); Don't trim calls done("").
#
# Godot can't seek in a video frame by frame, so for the player the video is
# first split into pictures (FFmpeg, at most 60 per second and 1800 in all, in
# Tools\app_preview\trim); the player shows them in turn, without sound.

const UI = preload("res://mlmk_app/ui.gd")
const MAX_FRAMES = 1800
const VIEW = Vector2(960, 500)

var app
var path: String
var done: Callable
# What this animation is in the game (its length), shown under the player.
var game_length_text: String
var modal: Dictionary
var frames_dir = ""
var count = 0
var fps = 30.0
var frame = 0
var mark_start = 0
var mark_end = 0
var playing = false
var clock = 0.0
var thread: Thread
var finished = false
var trimming = false

var picture: TextureRect
var status: Label
var scrub: HSlider
var bar: Control
var times: Label
var play_button: Button
var controls: Array = []


func _init(app_, path_: String, done_: Callable, game_length_text_: String = ""):
	app = app_
	path = path_
	done = done_
	game_length_text = game_length_text_


func _ready():
	modal = UI.modal(app.overlay(), "Trim " + path.get_file(), 1080)
	var body: VBoxContainer = modal["body"]
	body.add_theme_constant_override("separation", 12)
	picture = TextureRect.new()
	picture.custom_minimum_size = VIEW
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var frame_bg = PanelContainer.new()
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color.BLACK
	frame_bg.add_theme_stylebox_override("panel", bg)
	frame_bg.add_child(picture)
	body.add_child(frame_bg)

	scrub = HSlider.new()
	scrub.custom_minimum_size.y = 36
	scrub.step = 1
	scrub.focus_mode = Control.FOCUS_NONE
	# Taking the slider pauses the video (playback moves it without this signal).
	scrub.drag_started.connect(_pause)
	scrub.value_changed.connect(func(v):
		_pause()
		_show(int(v)))
	body.add_child(scrub)
	controls.append(scrub)
	# The kept part, under the slider: S and E mark its start and end.
	bar = Control.new()
	bar.custom_minimum_size.y = 26
	bar.draw.connect(_draw_bar)
	body.add_child(bar)

	var buttons = UI.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	for item in [["Set start here", "The kept part starts at this frame", _set_start],
			["<", "One frame back", func(): _step(-1)], ["▶", "Play / pause (the kept part, looped)", _toggle_play],
			["⏹", "Stop: back to the start marker", _stop], [">", "One frame forward", func(): _step(1)],
			["Set end here", "The kept part ends with this frame", _set_end]]:
		var b = UI.small_button(item[0], 30 if item[0].length() > 2 else 34)
		b.custom_minimum_size = Vector2(250 if item[0].length() > 2 else 96, 66)
		b.tooltip_text = item[1]
		b.pressed.connect(item[2])
		buttons.add_child(b)
		controls.append(b)
		if item[0] == "▶":
			play_button = b
	body.add_child(buttons)

	times = UI.text("", 24)
	times.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(times)
	status = UI.text("Preparing the video...", 22)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(status)
	if game_length_text != "":
		var info = UI.text(game_length_text, 22)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_color_override("font_color", Color("#ffd27d"))
		body.add_child(info)

	var row = UI.hbox(16)
	var trim = UI.button("Trim", 32, 76)
	trim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trim.pressed.connect(_trim)
	row.add_child(trim)
	controls.append(trim)
	var cancel = UI.button("Don't trim", 32, 76)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): _close(""))
	row.add_child(cancel)
	body.add_child(row)
	_set_enabled(false)
	_prepare()


func _set_enabled(on: bool):
	for c in controls:
		if c is Button:
			c.disabled = !on
		else:
			c.editable = on


func _ffmpeg() -> String:
	return app.kit.root + "/Tools/FFmpeg/ffmpeg.exe"


# ---- Splitting into pictures ----

func _prepare():
	frames_dir = app.kit.root + "/Tools/app_preview/trim/" + FileAccess.get_md5(path).left(16)
	thread = Thread.new()
	thread.start(_split.bind(path, frames_dir, _ffmpeg()))


static func _info(ffmpeg: String, file: String) -> Dictionary:
	var out = []
	OS.execute(ffmpeg, ["-hide_banner", "-i", file], out, true)
	var text = "\n".join(out)
	var result = {"fps": 30.0, "duration": 0.0}
	var m = RegEx.create_from_string("Video:.*?([\\d.]+) (fps|tbr)").search(text)
	if m:
		result["fps"] = maxf(m.get_string(1).to_float(), 1.0)
	var d = RegEx.create_from_string("Duration: (\\d+):(\\d+):([\\d.]+)").search(text)
	if d:
		result["duration"] = d.get_string(1).to_int() * 3600 + d.get_string(2).to_int() * 60 + d.get_string(3).to_float()
	return result


static func _split(file: String, dir: String, ffmpeg: String) -> float:
	var info = _info(ffmpeg, file)
	var rate = minf(info["fps"], 60.0)
	if info["duration"] > 0 && info["duration"] * rate > MAX_FRAMES:
		rate = MAX_FRAMES / info["duration"]
	var done_file = dir + "/done.txt"
	if FileAccess.file_exists(done_file):
		return FileAccess.get_file_as_string(done_file).to_float()
	DirAccess.make_dir_recursive_absolute(dir)
	OS.execute(ffmpeg, ["-hide_banner", "-loglevel", "error", "-y", "-i", file, "-vf", "fps=%.4f,scale=-2:540" % rate, "-q:v", "3", dir + "/f_%05d.jpg"], [], true)
	var f = FileAccess.open(done_file, FileAccess.WRITE)
	if f:
		f.store_string(str(rate))
	return rate


func _split_done():
	fps = thread.wait_to_finish()
	thread = null
	count = 0
	while FileAccess.file_exists(_frame_path(count)):
		count += 1
	if count == 0:
		status.text = "This file couldn't be opened as a video or GIF."
		return
	status.text = "%d frames, %.2f s (shown at %.0f frames per second, without sound)" % [count, count / fps, fps]
	scrub.max_value = count - 1
	mark_start = 0
	mark_end = count - 1
	_set_enabled(true)
	_show(0)


func _frame_path(i: int) -> String:
	return frames_dir + "/f_%05d.jpg" % (i + 1)


# ---- Player ----

func _show(i: int):
	if count == 0:
		return
	frame = clampi(i, 0, count - 1)
	var image = Image.load_from_file(_frame_path(frame))
	if image != null:
		picture.texture = ImageTexture.create_from_image(image)
	scrub.set_value_no_signal(frame)
	_update_times()


func _update_times():
	var a = mark_start / fps
	var b = (mark_end + 1) / fps
	times.text = "Frame %d  (%.2f s)        Start %.2f s   End %.2f s   Kept %.2f s" % [frame, frame / fps, a, b, b - a]
	bar.queue_redraw()


func _draw_bar():
	if count == 0:
		return
	var w = bar.size.x
	var h = bar.size.y
	bar.draw_rect(Rect2(0, 8, w, h - 16), Color(1, 1, 1, 0.15))
	var x0 = w * mark_start / max(count - 1, 1)
	var x1 = w * mark_end / max(count - 1, 1)
	bar.draw_rect(Rect2(x0, 8, max(x1 - x0, 2), h - 16), Color("#7dff8a", 0.7))
	for x in [x0, x1]:
		bar.draw_rect(Rect2(x - 2, 0, 4, h), Color("#ffd27d"))
	var xf = w * frame / max(count - 1, 1)
	bar.draw_rect(Rect2(xf - 1, 4, 2, h - 8), Color.WHITE)


func _set_start():
	mark_start = frame
	if mark_end < mark_start:
		mark_end = count - 1
	_update_times()


func _set_end():
	mark_end = frame
	if mark_start > mark_end:
		mark_start = 0
	_update_times()


func _toggle_play():
	playing = !playing
	play_button.text = "⏸" if playing else "▶"
	if playing && (frame < mark_start || frame >= mark_end):
		_show(mark_start)
	clock = 0.0


func _pause():
	playing = false
	play_button.text = "▶"


func _stop():
	playing = false
	play_button.text = "▶"
	_show(mark_start)


func _step(d: int):
	playing = false
	play_button.text = "▶"
	_show(frame + d)


func _process(delta):
	if thread != null && !thread.is_alive():
		if trimming:
			_trim_finished()
		else:
			_split_done()
		return
	if !playing || count == 0:
		return
	clock += delta
	var steps = int(clock * fps)
	if steps <= 0:
		return
	clock -= steps / fps
	var next = frame + steps
	# Loops inside the kept part.
	if next > mark_end:
		next = mark_start
	_show(next)


# ---- Trim ----

func _trim():
	playing = false
	play_button.text = "▶"
	_set_enabled(false)
	status.text = "Trimming..."
	trimming = true
	var start = mark_start / fps
	var end = (mark_end + 1) / fps
	var base = path.get_basename() + "_trim"
	var target = base + ".mp4"
	var n = 2
	while FileAccess.file_exists(target):
		target = base + str(n) + ".mp4"
		n += 1
	thread = Thread.new()
	thread.start(_cut.bind(path, target, start, end, _ffmpeg()))


static func _cut(file: String, target: String, start: float, end: float, ffmpeg: String):
	var out = []
	var code = OS.execute(ffmpeg, ["-hide_banner", "-loglevel", "error", "-y", "-i", file,
		"-ss", "%.4f" % start, "-to", "%.4f" % end,
		"-map", "0:v:0", "-map", "0:a:0?",
		"-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-c:v", "libx264", "-crf", "17", "-preset", "veryfast", "-pix_fmt", "yuv420p",
		"-c:a", "aac", "-b:a", "160k", target], out, true)
	return {"code": code, "target": target, "out": "\n".join(out)}


func _trim_finished():
	trimming = false
	var result = thread.wait_to_finish()
	thread = null
	if result["code"] != 0 || !FileAccess.file_exists(result["target"]):
		status.text = "Trimming failed: " + String(result["out"]).left(300)
		_set_enabled(true)
		return
	_close(String(result["target"]).get_file())


func _close(new_name: String):
	if finished:
		return
	finished = true
	playing = false
	if thread != null:
		thread.wait_to_finish()
		thread = null
	modal["root"].queue_free()
	queue_free()
	done.call(new_name)
