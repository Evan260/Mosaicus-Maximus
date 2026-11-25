class_name DemoEnd
extends PanelContainer
## The demo's end card, shown once when the workshop's reputation reaches the first chapter past the demo: thanks, a
## look at what the full game brings next, and a button to wishlist it on Steam, or on a phone to buy it. Carry on plays on.

## Pictures from the full game's chapters, in their own stones, as a glimpse of what comes next.
const TEASE := ["lion", "octopus", "peacock", "medusa"]
const WIDTH := 250.0

var _unlock: Button
var _carry_on: Callable


static func open(parent: Control, carry_on: Callable) -> DemoEnd:
	var card := DemoEnd.new()
	card.theme_type_variation = "PagePanel"
	parent.add_child(card)
	var col := Ui.vbox(card, 5)
	# A phone's screen is wide but short, so there the card spreads out to keep within its height.
	var big := maxf(Settings.message_scale(), minf(Nav.ui_size().x - 40.0, 400.0) / WIDTH if Nav.phone and Nav.ui_size().y < 320.0 else 1.0)
	# A phone selling the full game shows its limits without calling itself a demo, which App Review refuses.
	var thanks := "Thank you for playing!" if FullGame.sold_here() else "Thank you for playing the demo!"
	var head := Ui.label(col, thanks, "Heading", WIDTH * big)
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
	var full := full_game_button(buttons)
	Ui.button(buttons, "Carry on", carry_on, "arrow_r", full == null)
	# Read once and gone if closed by a stray click, so only Carry on and Escape close it.
	Ui.closes_with(card, carry_on, false)
	card._unlock = full if FullGame.sold_here() else null
	card._carry_on = carry_on
	FullGame.changed.connect(card._on_store_changed)
	Audio.play("page_turn", -6.0)
	return card


## The full game's Steam App ID, kept in balance.json's demo block; 0 until Steamworks gives it one.
static func store_app_id() -> int:
	return int(Data.num("demo.store_app_id", 0))


## The Wishlist on Steam button, or nothing while the full game has no App ID yet, or on a phone, which has no Steam.
static func wishlist_button(parent: Node) -> Button:
	if store_app_id() == 0 or Nav.phone:
		return null
	return Ui.button(parent, "Wishlist on Steam", open_store, "star", true)


## Where the demo stops the player: the unlock on a phone that sells the full game, the wishlist anywhere else.
static func full_game_button(parent: Node) -> Button:
	return unlock_button(parent) if FullGame.sold_here() else wishlist_button(parent)


## A phone's button that buys the full game, or nothing once it is owned or where nothing is for sale.
static func unlock_button(parent: Node) -> Button:
	if not FullGame.locked():
		return null
	var b := Ui.button(parent, unlock_text(), FullGame.buy, "star", true)
	b.name = "UnlockButton"
	return b


## The unlock's words, with the store's own price once it has said it.
static func unlock_text() -> String:
	if FullGame.price() == "":
		return TranslationServer.translate("Unlock the full game")
	return TranslationServer.translate("Unlock the full game: %s") % FullGame.price()


## Buying the full game from this card opens the next chapter at once, so the card makes way for its letter.
func _on_store_changed() -> void:
	if not Game.is_demo():
		_carry_on.call()
	elif is_instance_valid(_unlock):
		Ui.relabel(_unlock, unlock_text())


## Opens the full game's store page: in the Steam client when it is running, else in the browser.
static func open_store() -> void:
	var id := store_app_id()
	OS.shell_open(("steam://store/%d" if Awards.steam_running() else "https://store.steampowered.com/app/%d/") % id)
