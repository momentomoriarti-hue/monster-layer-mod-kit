extends Node2D

# Shows a custom Lay's sex videos or pictures in place of the rendered models.
# Added as a child of the round's Anim node by CustomLays.attachMedia().
#
# Playback follows the game's own state (Anim.activestate), not the mouse:
# the media moves exactly while the game counts you as fucking (what hearts check),
# so the delay after a click / press and the tail after releasing are visible.
#   idle   -> idle media (looped), or the last stroke media paused / rewound
#   thrust -> thrust media
#   pound  -> pound media
# One-shot moments, started from the patched Anim.gd (CustomLays.onSpecial):
#   free_cum (free cum perk), egg (free cum as Sylvia), lose (you run out of stamina),
#   orgasm (the Lay cums, end of the round). They play from the start once.
# Hypno trance shows the hypno media on top of everything (CustomLays.onHypno).
# A missing media falls back along FALLBACK, and finally to the thrust media.
#
# Every kind can have several clips (files); one is picked at random each time the
# kind starts from the beginning, and again whenever a video finishes a loop.
# Videos with sped-up copies (anim_acceleration_steps in mod_settings.cfg) use the
# copy for the current Pleasure, picked at the same moments: never mid-loop.
# Pictures for thrust and pound bob up and get 10% bigger (5% for pound) on every
# stroke, in sync with the game's hit timing; other pictures are shown still.

# Area between the top (pleasure) and bottom (stamina) UI, in viewport pixels (720x1280).
const AREA_CENTER = Vector2(360, 665)
const MAX_SIZE = Vector2(720, 1030)
# Media smaller than this is scaled up until it reaches it (keeping aspect ratio).
const MIN_SIZE = Vector2(540, 770)

const BOB = {
	"thrust": {"rise": 0.2, "fall": 0.8, "lift": 0.05, "zoom": 0.10},
	"pound": {"rise": 0.2, "fall": 0.3, "lift": 0.025, "zoom": 0.05},
}
const LOOPED = ["thrust", "pound", "idle", "hypno"]
# Stroke videos fitted to the stroke's length (auto_fit_<kind>_anim_length) always
# play to their end, then show their first frame until the next stroke.
const STROKES = ["thrust", "pound"]
const FALLBACK = {
	"thrust": ["pound"],
	"pound": ["thrust"],
	"lose": ["egg_if_sylvia", "free_cum", "thrust", "pound"],
	"egg": ["free_cum", "thrust", "pound"],
	"free_cum": ["thrust", "pound"],
	"orgasm": ["thrust", "pound"],
}

var anim
# kind -> {"reset", "clips": [clip], "clip": index, "active": copy index, "node"}
# clip -> {"type", "variants": [paths], "nodes": [one node per copy], "size", "scale"}
var media = {}
var current = ""
var special = ""
# The kind whose media is on screen (hypno is drawn on top separately).
var shownkind = ""
var hypnoshowing = false
var bob = 0.0
var bobkind = "thrust"
var bobtween
var hypnotween
# Strokes so far, and the stroke each fitted stroke video was started for: it
# plays again at its end only for a stroke that started after it.
var strokes = 0
var video_stroke = {}


func setup(animnode, lay):
	anim = animnode
	top_level = true
	position = AREA_CENTER
	z_index = 10
	for kind in lay["media"].keys():
		media[kind] = lay["media"][kind].duplicate(true)
	for kind in media.keys():
		if kind != "hypno":
			createNodes(kind)
	# Created last, so it is drawn on top.
	if media.has("hypno"):
		createNodes("hypno")
		for clip in media["hypno"]["clips"]:
			for node in clip["nodes"]:
				node.modulate.a = 0.0
				node.visible = true
	var first = resolve("idle") if media.has("idle") else resolve("thrust")
	if first != "":
		choose(first)
	showOnly(first)
	for kind in media.keys():
		prepareVideos(kind)


func createNodes(kind):
	var info = media[kind]
	for clip in info["clips"]:
		clip["nodes"] = []
		for path in clip["variants"]:
			var node
			if clip["type"] == "video":
				node = VideoStreamPlayer.new()
				var stream = VideoStreamTheora.new()
				stream.file = path
				node.stream = stream
				# Godot 4.3's own Theora looping crashes the game or freezes the video on
				# some files, so videos are looped by hand when they finish (onFinished).
				node.loop = false
				node.finished.connect(onFinished.bind(node))
				node.expand = true
				# The video's own sound follows the game's SFX volume slider.
				node.bus = "sfx"
				node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				node = Sprite2D.new()
				# Pictures are imported by Godot at pack time, so they load as textures.
				node.texture = CustomLays.loadTexture(path)
				var maxsize = MAX_SIZE
				if BOB.has(kind):
					# Leave room for the bob zoom, so the picture stays inside the area at its peak.
					maxsize = MAX_SIZE / (1.0 + BOB[kind]["zoom"])
				clip["size"] = fitSize(node.texture.get_size(), maxsize)
				clip["scale"] = clip["size"] / node.texture.get_size()
				node.scale = clip["scale"]
			node.visible = false
			add_child(node)
			clip["nodes"].append(node)
	info["clip"] = 0
	info["active"] = 0
	info["node"] = info["clips"][0]["nodes"][0]


# Decodes the first frame of every video (a Theora player shows nothing before
# that) and sizes it to the area.
func prepareVideos(kind):
	for clip in media[kind]["clips"]:
		if clip["type"] != "video":
			continue
		for node in clip["nodes"]:
			await showFirstFrame(node)
			if !is_instance_valid(node):
				return
			clip["size"] = fitSize(node.get_video_texture().get_size() if node.get_video_texture() != null else MAX_SIZE)
			node.size = clip["size"]
			node.position = -clip["size"] / 2


# Fits the media into maxsize, and scales it up to MIN_SIZE if it is smaller.
func fitSize(native: Vector2, maxsize: Vector2 = MAX_SIZE) -> Vector2:
	if native.x <= 0 || native.y <= 0:
		return MIN_SIZE
	var maxscale = min(maxsize.x / native.x, maxsize.y / native.y)
	var minscale = min(MIN_SIZE.x / native.x, MIN_SIZE.y / native.y)
	return native * clampf(1.0, minscale, maxscale)


# Plays a video for a moment so its first frame is shown, then pauses it unless it
# is the one playing right now.
func showFirstFrame(player):
	player.paused = false
	player.play()
	for i in range(2):
		await get_tree().process_frame
	if !is_instance_valid(player):
		return
	var kind = getKind(player)
	var playing = media.has(kind) && media[kind]["node"] == player && (kind == current || (kind == "hypno" && Perks.intrance))
	if !playing:
		player.paused = true


# Shows the video's first frame, paused (the look between strokes).
func rewindPaused(player):
	player.stop()
	player.paused = false
	player.play()
	for i in range(2):
		await get_tree().process_frame
	if is_instance_valid(player):
		player.paused = true


func getKind(node):
	for kind in media.keys():
		for clip in media[kind]["clips"]:
			if clip["nodes"].has(node):
				return kind
	return ""


func currentClip(kind):
	return media[kind]["clips"][media[kind]["clip"]]


# The media kind actually shown for a wanted kind, or "" if there is none.
func resolve(kind):
	if media.has(kind):
		return kind
	for next in FALLBACK.get(kind, []):
		if next == "egg_if_sylvia":
			if Settings.playersprite == "Sylvia" && media.has("egg"):
				return "egg"
		elif media.has(next):
			return next
	return ""


# Index of the sped-up copy for the current Pleasure (0 = slowest). Copy k covers
# k/steps to (k+1)/steps of Pleasure; the game's speed is 1 + 0.5 * Pleasure.
func copyFor(clip):
	var steps = clip["nodes"].size()
	if steps <= 1:
		return 0
	var pleasure = clampf((anim.animspeed - 1.0) / 0.5, 0.0, 1.0)
	return mini(int(pleasure * steps), steps - 1)


# Picks a random clip of the kind and the copy for the current Pleasure. Call only
# when the kind starts from the beginning. Returns true if the node changed; the
# new node is rewound and shown in place of the old one.
func choose(kind):
	var info = media[kind]
	var clipindex = randi() % info["clips"].size()
	var copy = copyFor(info["clips"][clipindex])
	var node = info["clips"][clipindex]["nodes"][copy]
	info["clip"] = clipindex
	info["active"] = copy
	if node == info["node"]:
		return false
	var old = info["node"]
	if old is VideoStreamPlayer:
		old.stop()
	if kind == "hypno":
		node.modulate.a = old.modulate.a
		old.modulate.a = 0.0
	else:
		old.visible = false
		node.visible = (kind == shownkind)
	info["node"] = node
	if node is VideoStreamPlayer:
		node.stop()
	return true


func showOnly(kind):
	shownkind = kind
	for k in media.keys():
		if k == "hypno":
			continue
		for clip in media[k]["clips"]:
			for node in clip["nodes"]:
				node.visible = (k == kind && node == media[k]["node"])


# The media the game's state asks for right now ("" = none: the last stroke media
# stays on screen, paused).
func wantedKind():
	if special != "":
		return special
	match anim.activestate:
		"thrust", "freecum":
			return resolve("thrust")
		"pound":
			return resolve("pound")
		_:
			return resolve("idle") if media.has("idle") else ""


# A fitted stroke video that is still playing (it finishes before the idle).
func fittedPlaying(kind):
	if !STROKES.has(kind) || !media.has(kind) || !media[kind].get("fit", false):
		return false
	var node = media[kind]["node"]
	return node is VideoStreamPlayer && node.is_playing() && !node.paused


func _process(_delta):
	if anim == null || !is_instance_valid(anim):
		return
	if special != "" && anim.activestate != "freecum":
		special = ""
	var wanted = wantedKind()
	# The stroke ended but its fitted video hasn't: let it finish first
	# (onFinished() then rewinds it to its first frame).
	if wanted != current && special == "" && (wanted == "" || wanted == resolve("idle")) && fittedPlaying(current):
		updateBob()
		return
	if wanted != current:
		if current != "":
			pauseMedia(current)
		current = wanted
		if current != "":
			playMedia(current)
	updateBob()


func playMedia(kind, fromstart = false):
	var info = media[kind]
	var node = info["node"]
	# At the very start of the media (from the start, after a rewind, never played,
	# or a picture), a random clip and the copy for the current Pleasure are picked.
	var atstart = fromstart || !(node is VideoStreamPlayer) || !node.is_playing() || node.stream_position < 0.1
	if atstart:
		choose(kind)
		node = info["node"]
	showOnly(kind)
	if atstart:
		video_stroke[kind] = strokes
	if node is VideoStreamPlayer:
		if fromstart:
			node.stop()
			node.paused = false
			node.play()
		elif node.is_playing():
			node.paused = false
		else:
			# play() keeps the paused flag (set when its first frame was prepared).
			node.paused = false
			node.play()


func pauseMedia(kind):
	var node = media[kind]["node"]
	if !(node is VideoStreamPlayer):
		return
	if media[kind].get("reset", false):
		node.stop()
		showFirstFrame(node)
	else:
		node.paused = true


# A video reached its end. A looping kind that is on screen starts again, with a
# random clip and the copy for the current Pleasure picked anew; one-shot videos
# (free cum, egg, lose, orgasm) stay on their last frame.
func onFinished(node):
	var kind = getKind(node)
	if !LOOPED.has(kind) || media[kind]["node"] != node:
		return
	if kind != current && !(kind == "hypno" && hypnoshowing):
		return
	# A fitted stroke video plays once per stroke: again only for a stroke that
	# started while it played, otherwise back to its first frame. (Its end and the
	# game's end of the stroke come at the same moment, in either order.)
	if STROKES.has(kind) && media[kind].get("fit", false) && (wantedKind() != kind || strokes <= video_stroke.get(kind, -1)):
		rewindPaused(node)
		return
	video_stroke[kind] = strokes
	choose(kind)
	var next = media[kind]["node"]
	next.paused = false
	next.play()


# Called from the patched Anim.gd when a one-shot moment starts.
func onSpecial(kind):
	var shown = resolve(kind)
	if shown == "":
		return
	if current != "" && current != shown:
		pauseMedia(current)
	special = shown
	current = shown
	# One-shot media start from the beginning; a fallback stroke media just plays on.
	playMedia(shown, !LOOPED.has(shown))


# Called from the patched Anim.playHypnoAnim(): "Start" shows the overlay, "End" hides it.
func onHypno(animname):
	if !media.has("hypno"):
		return
	var showing = animname == "Start"
	hypnoshowing = showing
	if showing:
		choose("hypno")
	var node = media["hypno"]["node"]
	if node is VideoStreamPlayer && showing:
		node.paused = false
		if !node.is_playing():
			node.play()
	if hypnotween != null:
		hypnotween.kill()
	hypnotween = create_tween()
	hypnotween.tween_property(node, "modulate:a", 1.0 if showing else 0.0, 0.3)
	if !showing && node is VideoStreamPlayer:
		hypnotween.tween_callback(func(): node.paused = true)


# Called from the patched Anim.gd at the start of every thrust and pound stroke.
# Spammed thrusts can follow each other in the same frame, without an idle frame
# between them, so every new playback is started from here:
#   a picture is one stroke long: a random clip is picked on every stroke;
#   a thrust video with reset_on_pause restarts from a random clip on every thrust.
# Other videos go on and pick a new clip when they finish a loop (onFinished()).
func onStroke(kind):
	strokes += 1
	if special != "":
		return
	var shown = resolve(kind)
	if shown == "":
		return
	# A fitted video that already stopped on its first frame starts this stroke.
	if shown == current && currentClip(shown)["type"] != "image" && media[shown].get("fit", false) && !fittedPlaying(shown):
		playMedia(shown, true)
		return
	if currentClip(shown)["type"] == "image":
		if shown == current:
			choose(shown)
			showOnly(shown)
	elif kind == "thrust" && shown == current && media[shown].get("reset", false):
		playMedia(shown, true)
	if currentClip(shown)["type"] != "image":
		return
	var timing = BOB[kind]
	var speed = max(anim.animspeed, 0.01)
	bobkind = kind
	if bobtween != null:
		bobtween.kill()
	bobtween = create_tween()
	bobtween.tween_property(self, "bob", 1.0, timing["rise"] / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bobtween.tween_property(self, "bob", 0.0, timing["fall"] / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func updateBob():
	for kind in BOB.keys():
		if !media.has(kind):
			continue
		var clip = currentClip(kind)
		if clip["type"] != "image":
			continue
		var node = media[kind]["node"]
		var timing = BOB[bobkind]
		node.position.y = -bob * timing["lift"] * clip["size"].y
		node.scale = clip["scale"] * (1.0 + bob * timing["zoom"])
