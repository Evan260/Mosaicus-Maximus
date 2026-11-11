class_name ChaptersPanel
extends PanelContainer
## The chapters as an open book, opened from the laurel in the top bar: a bookmark and a spread for each chapter,
## and a last bookmark, a laurel, for the achievements.

const STACK := 3
const SPINE := 4
const TOP := 8
const OUTER := 10
const INNER := 12
## The book never grows past this, and on a small interface it shrinks to fit.
const MOST := Vector2(236, 250)
const LEAST := Vector2(170, 170)
const PAPER := Color8(240, 226, 192)
const EDGE := Color8(160, 122, 84)
const TAB := Color8(214, 190, 146)
const LEATHER := Color8(104, 60, 40)
const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
## The first spread after the last chapter, which lists the achievements; any more spreads they need count down from it.
const AWARDS := 0

static var _papers := {}
static var _cover: StyleBoxTexture

var chapter := 1
var page_size := MOST
var _book: Control
var _marks: VBoxContainer
var _pages: Array[ScrollContainer] = []
var _turning := false
## A chapter asked for while a page is turning, taken as soon as it lands.
var _queued := 0


## Opens the book sized for `room`, the interface's size in its own pixels, which is the window's unless given.
static func open(parent: Control, room: Vector2 = Vector2.ZERO) -> ChaptersPanel:
	var p := ChaptersPanel.new()
	parent.add_child(p)
	p._build(room if room != Vector2.ZERO else Nav.ui_size())
	return p


## The size of one page that lets the whole book, its cover and its bookmarks fit in `room`.
static func page_for(room: Vector2) -> Vector2:
	var left := room - Vector2(8 + 12 + 24 + STACK * 2 + SPINE, 8 + 12 + STACK)
	return Vector2(clampf(floorf(left.x / 2.0), LEAST.x, MOST.x), clampf(left.y, LEAST.y, MOST.y)).floor()


func _build(room: Vector2) -> void:
	if _cover == null:
		_cover = StyleBoxTexture.new()
		_cover.texture = _leather()
		_cover.set_texture_margin_all(6)
		_cover.set_content_margin_all(6)
		_cover.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		_cover.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	add_theme_stylebox_override("panel", _cover)
	chapter = mini(int(Game.state["chapter"]) + 1, Data.chapters.size())
	page_size = page_for(room)
	var row := Ui.hbox(self, 0)
	_book = Control.new()
	_book.custom_minimum_size = Vector2(STACK * 2 + page_size.x * 2 + SPINE, page_size.y + STACK)
	_book.draw.connect(_draw_book)
	row.add_child(_book)
	var side := Ui.vbox(row, 0)
	Ui.close_button(side, self).size_flags_horizontal = Control.SIZE_SHRINK_END
	_marks = Ui.vbox(side, 1)
	_marks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fill()
	Nav.resized.connect(_place)
	_place.call_deferred()


func _place() -> void:
	reset_size()
	position = ((Nav.ui_size() - size) * 0.5).floor()


func _page_x(side: int) -> float:
	return STACK if side == 0 else STACK + page_size.x + SPINE


func _text_width() -> float:
	return page_size.x - OUTER - INNER - 4


## Lays out the open chapter's spread and the bookmarks beside it.
func _fill() -> void:
	# A page turn takes the pages it pictures out of the book, so only those still in it are freed here.
	for view in _pages:
		if view.get_parent() == _book:
			_book.remove_child(view)
			view.queue_free()
	_pages.clear()
	for side in 2:
		var view := ScrollContainer.new()
		view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		view.position = Vector2(_page_x(side) + (OUTER if side == 0 else INNER), TOP)
		view.size = Vector2(_text_width() + 4, page_size.y - TOP - 6)
		_book.add_child(view)
		_pages.append(view)
	for c in _marks.get_children():
		_marks.remove_child(c)
		c.queue_free()
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_marks.add_child(gap)
	for ch in Data.chapters:
		_bookmark(int(ch["n"]))
	_bookmark(AWARDS)
	if chapter <= AWARDS:
		_awards(_column(_pages[0]), _column(_pages[1]))
		return
	_story(_column(_pages[0]))
	_brings(_column(_pages[1]))


func _column(view: ScrollContainer) -> VBoxContainer:
	var col := Ui.vbox(view, 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size.y = view.size.y
	return col


## A ribbon beside the right page with the chapter's numeral; the open one is the colour of the paper.
func _bookmark(n: int) -> void:
	var now := int(Game.state["chapter"])
	var open_now := n == chapter or (n == AWARDS and chapter < AWARDS)
	var b := Button.new()
	if n == AWARDS:
		b.icon = UiTheme.icon("laurel")
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		b.text = NUMERALS[n - 1] if n <= NUMERALS.size() else str(n)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(24, 22)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = PAPER if open_now else (TAB.lightened(0.12) if state.begins_with("hover") else TAB)
		box.border_color = EDGE
		box.border_width_top = 1
		box.border_width_bottom = 1
		box.border_width_right = 1
		box.border_width_left = 0 if open_now else 1
		box.corner_radius_top_right = 2
		box.corner_radius_bottom_right = 2
		box.content_margin_left = 3
		box.content_margin_right = 4
		box.content_margin_top = 2 if n == AWARDS else -1
		box.content_margin_bottom = 2 if n == AWARDS else -1
		b.add_theme_stylebox_override(state, box)
	var ink := UiTheme.INK if n <= now + 1 or n == AWARDS else UiTheme.MUTED
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_font_override("font", UiTheme.title_font("en"))
	b.add_theme_font_size_override("font_size", 8)
	Ui.tip_on(b, "Achievements" if n == AWARDS else tr("Chapter %d: %s") % [n, tr(Data.chapter(n)["title"])])
	b.pressed.connect(func() -> void: turn_to(n))
	_marks.add_child(b)


## The left page: the chapter's number and title over a band of its stones, its story, and for the next chapter how close it is.
func _story(page: VBoxContainer) -> void:
	var st := Game.state
	var now := int(st["chapter"])
	var ch := Data.chapter(chapter)
	var w := _text_width()
	var number := Ui.label(page, tr("Chapter %d") % chapter, "MutedLabel", w)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := Ui.label(page, tr(ch["title"]), "Heading", w)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_band(w))
	Ui.label(page, tr(ch["text"]), "", w)
	page.add_child(_emblem())
	if chapter != now + 1:
		return
	var from := int(Data.chapter(now)["reputation"])
	page.add_child(_progress(int(st["reputation"]) - from, int(ch["reputation"]) - from, w))
	Ui.label(page, tr("Reputation %d of %d: %d more to go.") % [int(st["reputation"]), int(ch["reputation"]), int(ch["reputation"]) - int(st["reputation"])], "", w)
	Ui.label(page, "Every finished floor earns reputation, and better floors earn more. Enough reputation opens the next chapter.", "MutedLabel", w)


## The achievements, the earned ones first, running on from page to page over as many spreads as they need: each
## name with a gold dot when earned, and how to earn it in its tip.
func _awards(left: VBoxContainer, right: VBoxContainer) -> void:
	var have: Array = Game.state.get("achievements", [])
	var w := _text_width()
	var spread := AWARDS - chapter
	var pages := _award_pages(have)
	if spread == 0:
		var title := Ui.label(left, "Achievements", "Heading", w)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var count := Ui.label(left, tr("%d of %d earned") % [have.size(), Achievements.all().size()], "MutedLabel", w)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for side in 2:
		var page: VBoxContainer = [left, right][side]
		page.add_theme_constant_override("separation", 1)
		for a in pages[spread * 2 + side] if spread * 2 + side < pages.size() else []:
			var earned: bool = a["id"] in have
			var row := Ui.hbox(page, 3)
			var mark := Art.new()
			mark.kind = "dot" if earned else "ring"
			mark.custom_minimum_size = Vector2(4, 9)
			mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(mark)
			var name := Ui.label(row, tr(str(a["name"])), "" if earned else "MutedLabel", w - 7)
			Ui.tip_on(name, tr(str(a["text"])))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(gap)
	var turns := Ui.hbox(right, 2)
	turns.alignment = BoxContainer.ALIGNMENT_END
	if spread > 0:
		Ui.icon_button(turns, "arrow_l", "Previous page", func() -> void: turn_to(chapter + 1))
	if (spread + 1) * 2 < pages.size():
		Ui.icon_button(turns, "arrow_r", "Next page", func() -> void: turn_to(chapter - 1))


## The achievements in page-sized groups: the first page leaves room for its heading, and the right pages for the arrows.
func _award_pages(have: Array) -> Array:
	var ordered := Achievements.all().filter(func(a: Dictionary) -> bool: return a["id"] in have)
	ordered += Achievements.all().filter(func(a: Dictionary) -> bool: return not a["id"] in have)
	var font := UiTheme.body_font()
	var size := UiTheme.text_size()
	var line := font.get_height(size) + 1.0
	var full := _pages[0].size.y
	var pages := [[]]
	var room := full - UiTheme.heading_size() - line - 6.0
	for a in ordered:
		var tall := font.get_multiline_string_size(tr(str(a["name"])), HORIZONTAL_ALIGNMENT_LEFT, _text_width() - 7, size).y + 1.0
		if tall > room and not pages[-1].is_empty():
			pages.append([])
			room = full - (24.0 if pages.size() % 2 == 0 else 0.0)
		pages[-1].append(a)
		room -= tall
	return pages


## The right page: whether the chapter is done, open or still to come, and everything it brings.
func _brings(page: VBoxContainer) -> void:
	var now := int(Game.state["chapter"])
	if chapter < now:
		_status(page, "tick", "Done. It brought:")
	elif chapter == now:
		_status(page, "laurel", "You are here. It brought:")
	elif chapter == now + 1:
		_status(page, "lock", "It brings:")
	else:
		_status(page, "lock", tr("Opens at %d reputation. It brings:") % int(Data.chapter(chapter)["reputation"]))
	page.add_theme_constant_override("separation", 1)
	for line in Story.chapter_unlocks(chapter):
		var row := Ui.hbox(page, 3)
		var dot := Art.new()
		dot.kind = "dot"
		dot.custom_minimum_size = Vector2(4, 9)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(dot)
		Ui.label(row, line, "", _text_width() - 7)


func _status(page: VBoxContainer, icon_name: String, text: String) -> void:
	var row := Ui.hbox(page, 3)
	Ui.icon(row, icon_name).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var l := Ui.label(row, text, "MutedLabel", _text_width() - 19)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## A strip of little tesserae in the chapter's own stones, set in grout like a border on a floor.
func _band(width: float) -> Control:
	var colours: Array = Stones.LIST.filter(func(s: Dictionary) -> bool: return int(s["tier"]) == chapter).map(func(s: Dictionary) -> Color: return s["tile"])
	var rng := RandomNumberGenerator.new()
	rng.seed = chapter
	var band := Art.new()
	band.kind = "band"
	band.custom_minimum_size = Vector2(width, 7)
	for i in int((width - 1) / 4.0):
		band.colours.append(colours[rng.randi() % colours.size()] if not colours.is_empty() else UiTheme.GOLD)
	return band


## The chapter's first picture as a little framed mosaic, under the story at the largest size the space allows.
func _emblem() -> Control:
	var pictures := Data.motif_order.filter(func(id: String) -> bool: return int(Data.motif(id).get("tier", 1)) == chapter and Data.motif(id).get("kind", "") == "picture")
	var art := Art.new()
	art.kind = "emblem"
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.custom_minimum_size.y = 4
	if not pictures.is_empty():
		for side in Art.SIDES:
			art.pictures.append(MotifIcons.motif(pictures[0], side - 6))
	return art


func _progress(have: int, need: int, width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 5)
	bar.max_value = maxi(need, 1)
	bar.value = clampi(have, 0, need)
	bar.add_theme_stylebox_override("background", _flat(Color8(196, 172, 128)))
	bar.add_theme_stylebox_override("fill", _flat(UiTheme.GOLD))
	return bar


func _flat(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	return s


## Pictures the pages as they are, lays the new spread out underneath, and turns a PageTurn leaf over it.
func turn_to(n: int) -> void:
	if n == chapter or n > Data.chapters.size():
		return
	if _turning:
		_queued = n
		return
	if not is_instance_valid(_book) or not _book.is_inside_tree():
		return
	if Settings.reduced_motion:
		Audio.play("page_turn")
		chapter = n
		_fill()
		return
	_turning = true
	var direction := 1 if _place_in_book(n) > _place_in_book(chapter) else -1
	var turn := PageTurn.new()
	var shots := turn.capture([_shot(1 if direction > 0 else 0), _shot(0 if direction > 0 else 1)], Nav.scale_factor())
	Audio.play("page_turn")
	chapter = n
	_fill()
	turn.direction = direction
	turn.left_page = Rect2(_page_x(0), 0, page_size.x, page_size.y)
	turn.right_page = Rect2(_page_x(1), 0, page_size.x, page_size.y)
	turn.front = shots[0]
	turn.behind = shots[1]
	turn.gutter = _draw_spine
	turn.size = _book.size
	turn.landed.connect(_landed)
	# A leaf that landed has already passed the turning on to the next one, so only a leaf cut short clears it.
	turn.tree_exiting.connect(func() -> void:
		if turn.progress < 1.0:
			_turning = false)
	_book.add_child(turn)
	# The new page is pictured a frame later, long before the leaf shows its back, so no one frame does all the work.
	await get_tree().process_frame
	if is_instance_valid(turn):
		var back := _shot(0 if direction > 0 else 1)
		back["page"] = back["page"].duplicate()
		turn.back = turn.capture([back], Nav.scale_factor())[0]


## Where a spread lies in the book: the achievements come after the last chapter.
func _place_in_book(n: int) -> int:
	return Data.chapters.size() + 1 + AWARDS - n if n <= AWARDS else n


## Opens the book at the achievements, at once, without turning to them.
func show_awards() -> void:
	chapter = AWARDS
	_fill()


func _landed() -> void:
	_turning = false
	if _queued != 0:
		var next := _queued
		_queued = 0
		turn_to(next)


## A page as it is laid out, to be pictured on its paper: 0 the left page, 1 the right.
func _shot(side: int) -> Dictionary:
	return {"page": _pages[side], "paper": _paper(side == 0), "at": _pages[side].position - Vector2(_page_x(side), 0),
		"size": page_size, "theme": Nav.ui.theme}


## Two pages of paper with the edges of the pages under them showing at the sides and bottom, and the fold between them.
func _draw_book() -> void:
	var right_x := _page_x(1)
	for k in range(STACK, 0, -1):
		var shade := PAPER.darkened(0.12 + 0.1 * (k % 2))
		_book.draw_rect(Rect2(STACK - k, k, page_size.x, page_size.y), shade)
		_book.draw_rect(Rect2(right_x + k, k, page_size.x, page_size.y), shade)
	_book.draw_rect(Rect2(0, STACK, 1, page_size.y), EDGE)
	_book.draw_rect(Rect2(right_x + page_size.x + STACK - 1, STACK, 1, page_size.y), EDGE)
	_book.draw_texture(_paper(true), Vector2(STACK, 0))
	_book.draw_texture(_paper(false), Vector2(right_x, 0))
	_draw_spine(_book)


func _draw_spine(canvas: Control) -> void:
	var x := STACK + page_size.x
	canvas.draw_rect(Rect2(x, 0, 1, page_size.y), Color8(176, 140, 98))
	canvas.draw_rect(Rect2(x + 1, 0, 1, page_size.y), Color8(130, 96, 66))
	canvas.draw_rect(Rect2(x + 2, 0, 1, page_size.y), Color8(90, 64, 46))
	canvas.draw_rect(Rect2(x + 3, 0, 1, page_size.y), Color8(156, 122, 86))


## A page of paper: a fine grain, a few fibres and age spots, browned edges, and a shadow towards the fold.
func _paper(gutter_right: bool) -> Texture2D:
	var key := "%s %s" % [gutter_right, page_size]
	if _papers.has(key):
		return _papers[key]
	var w := int(page_size.x)
	var h := int(page_size.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if gutter_right else 23
	for y in h:
		for x in w:
			var c := PAPER
			if rng.randf() < 0.14:
				c = c.darkened(0.035)
			var inner := w - 1 - x if gutter_right else x
			var edge := mini(w - 1 - inner, mini(y, h - 1 - y))
			if edge < 4:
				c = c.darkened(0.07 * (1.0 - edge / 4.0))
			if inner < 16:
				c = c.darkened(0.2 * pow(1.0 - inner / 16.0, 2.0))
			img.set_pixel(x, y, c)
	for i in 70:
		var x := rng.randi_range(3, w - 8)
		var y := rng.randi_range(3, h - 4)
		for k in rng.randi_range(2, 5):
			img.set_pixel(x + k, y, img.get_pixel(x + k, y).darkened(0.05))
	for i in 9:
		var at := Vector2i(rng.randi_range(6, w - 8), rng.randi_range(6, h - 8))
		var spot := Color8(184, 132, 82)
		img.set_pixelv(at, img.get_pixelv(at).lerp(spot, 0.22))
		img.set_pixelv(at + Vector2i(1, 0), img.get_pixelv(at + Vector2i(1, 0)).lerp(spot, 0.12))
	var tex := ImageTexture.create_from_image(img)
	_papers[key] = tex
	return tex


## The cover: grained leather with a tooled line round its edge and gold caps on its corners, cut as a nine-slice.
static func _leather() -> Texture2D:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in n:
		for x in n:
			var c := LEATHER
			var r := rng.randf()
			if r < 0.12:
				c = c.darkened(0.08)
			elif r < 0.18:
				c = c.lightened(0.05)
			var edge := mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			if edge == 0:
				c = LEATHER.darkened(0.5)
			elif edge == 3:
				c = UiTheme.GOLD.darkened(0.35)
			img.set_pixel(x, y, c)
	var gold := [UiTheme.GOLD, UiTheme.GOLD.darkened(0.2), UiTheme.GOLD.darkened(0.4)]
	for corner in [Vector2i(0, 0), Vector2i(n - 1, 0), Vector2i(0, n - 1), Vector2i(n - 1, n - 1)]:
		var dx := 1 if corner.x == 0 else -1
		var dy := 1 if corner.y == 0 else -1
		for i in 5:
			for j in 5 - i:
				var shade: Color = gold[0] if i + j < 2 else (gold[1] if i + j < 4 else gold[2])
				img.set_pixel(corner.x + dx * i, corner.y + dy * j, shade)
	return ImageTexture.create_from_image(img)


## The pages' little drawings, kept in exported values so the copies pictured for a page turn draw them too.
class Art extends Control:
	const SIDES := [64, 48, 36]
	@export var kind := ""
	@export var colours: Array = []
	@export var pictures: Array = []

	func _draw() -> void:
		match kind:
			"dot":
				draw_rect(Rect2(0, 5, 3, 3), UiTheme.GOLD.darkened(0.3))
				draw_rect(Rect2(0, 5, 2, 2), UiTheme.GOLD)
			"ring":
				draw_rect(Rect2(0, 5, 3, 3), UiTheme.MUTED, false, 1.0)
			"band":
				var left := floorf((size.x - colours.size() * 4 - 1) / 2.0)
				draw_rect(Rect2(left, 1, colours.size() * 4 + 1, 5), Color8(196, 176, 140))
				for i in colours.size():
					draw_rect(Rect2(left + 1 + i * 4, 2, 3, 3), colours[i])
			"emblem":
				for i in pictures.size():
					var side: int = SIDES[i]
					if side + 8 > size.y:
						continue
					var at := Vector2(floorf((size.x - side) / 2.0), floorf((size.y - side) / 2.0))
					draw_rect(Rect2(at - Vector2.ONE, Vector2(side + 2, side + 2)), EDGE)
					draw_rect(Rect2(at, Vector2(side, side)), Color8(204, 186, 150))
					draw_texture(pictures[i], at + Vector2(3, 3))
					return
