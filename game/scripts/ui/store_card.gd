class_name StoreCard
extends PanelContainer
## What the store said about the full game, over whichever screen is open: thanks once it is bought, and a short line
## when it is found again, waits for its payment, does not go through or the store cannot be reached.

const WIDTH := 250.0
## The line for each of FullGame's results but a purchase, which gets the thank-you; closing the store's sheet says nothing.
const LINES := {
	"restored": "The full game is unlocked again. Welcome back!",
	"pending": "Your purchase is waiting for its payment. The full game opens as soon as it goes through.",
	"error": "The purchase did not go through. Please try again later.",
	"unavailable": "The store cannot be reached right now. Please try again later.",
	"not_found": "No purchase of the full game was found for this account.",
}


## Shows the card for one of FullGame's results once any change of screen under way is done, so it lands on the new one.
static func answer(result: String) -> void:
	if result != "purchased" and not LINES.has(result):
		return
	while Nav._busy:
		await Nav.get_tree().process_frame
	open(result)


static func open(result: String) -> StoreCard:
	var card := StoreCard.new()
	card.theme_type_variation = "PagePanel"
	Nav.ui.add_child(card)
	var col := Ui.vbox(card, 5)
	var big := Settings.message_scale()
	var width := minf(WIDTH * big, Nav.ui_size().x - 24.0)
	if result == "purchased":
		var head := Ui.label(col, "Thank you for buying the full game!", "Heading", width)
		head.add_theme_font_size_override("font_size", UiTheme.heading_size(true))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var line := Ui.label(col, "The whole town's floors are yours to lay now, and your workshop carries on just as you left it.", "", width)
		line.add_theme_font_size_override("font_size", UiTheme.text_size() * big)
		Ui.button(col, "Lovely", card.queue_free, "tick", true).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		Audio.glissando()
	else:
		var line := Ui.label(col, LINES[result], "", width)
		line.add_theme_font_size_override("font_size", UiTheme.text_size() * big)
		Ui.button(col, "Got it", card.queue_free, "tick", true).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		Audio.play("page_turn", -6.0)
	Ui.closes_with(card)
	card.resized.connect(card._place)
	Nav.resized.connect(card._place)
	card._place.call_deferred()
	return card


func _place() -> void:
	if not is_inside_tree():
		return
	reset_size()
	position = ((Nav.ui_size() - size) * 0.5).floor()
