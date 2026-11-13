class_name DemoEnd
extends PanelContainer
## The demo's end card, shown once when the workshop's reputation reaches the first chapter past the demo: thanks, a
## look at what the full game brings next, and a button to wishlist it on Steam. Carry on keeps playing the demo.

## Pictures from the full game's chapters, in their own stones, as a glimpse of what comes next.
const TEASE := ["lion", "octopus", "peacock", "medusa"]
const WIDTH := 250.0


static func open(parent: Control, carry_on: Callable) -> DemoEnd:
	var card := DemoEnd.new()
	card.theme_type_variation = "PagePanel"
	parent.add_child(card)
	var col := Ui.vbox(card, 5)
	var big := Settings.message_scale()
	var head := Ui.label(col, "Thank you for playing the demo!", "Heading", WIDTH * big)
	head.add_theme_font_size_override("font_size", UiTheme.heading_size(true))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.label(col, "Your workshop has come as far as the demo goes. Your floors, coins and reputation are kept, and carry on into the full game.", "", WIDTH * big)
	var pictures := Ui.hbox(col, 6)
	pictures.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in TEASE:
		Ui.texture(pictures, MotifIcons.motif(id, 28, Data.motif(id).get("stones", {})))
	Ui.label(col, "Next, in the full game:", "Heading", WIDTH * big)
	for line in ["Picture panels: tiles half the size, for faces, beasts and myths set into a floor",
			"Glass and gold: glittering wall mosaics for the baths, a fountain niche and the town's new temple",
			"And the grand old floor buried beneath the forum"]:
		var row := Ui.hbox(col, 3)
		Ui.icon(row, "tick_small").size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		Ui.label(row, line, "", WIDTH * big - 13)
	var buttons := Ui.hbox(col, 4)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	wishlist_button(buttons)
	Ui.button(buttons, "Carry on", carry_on, "arrow_r", store_app_id() == 0)
	# Read once and gone if closed by a stray click, so only Carry on and Escape close it.
	Ui.closes_with(card, carry_on, false)
	Audio.play("page_turn", -6.0)
	return card


## The full game's Steam App ID, kept in balance.json's demo block; 0 until Steamworks gives it one.
static func store_app_id() -> int:
	return int(Data.num("demo.store_app_id", 0))


## The Wishlist on Steam button, or nothing while the full game has no App ID yet.
static func wishlist_button(parent: Node) -> Button:
	if store_app_id() == 0:
		return null
	return Ui.button(parent, "Wishlist on Steam", open_store, "star", true)


## Opens the full game's store page: in the Steam client when it is running, else in the browser.
static func open_store() -> void:
	var id := store_app_id()
	OS.shell_open(("steam://store/%d" if Awards.steam_running() else "https://store.steampowered.com/app/%d/") % id)
