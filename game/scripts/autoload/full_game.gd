extends Node
## The one purchase that opens the whole game on a phone, where the game is free and plays like the Steam demo until it
## is bought. The store is the phone's native plugin (SlowSundayPhone's Google Play Billing on Android; an Apple one
## later, with the same methods and signals), so a computer has none and nothing there is for sale or locked. Owning
## the full game is written to user://store.cfg, so a phone without a connection keeps it. --store tries a pretend
## store on a computer, and --store=owned one where the full game is already bought.

## Whether the full game is owned, or its price, changed.
signal changed
## How a purchase or restore ended: purchased, pending, cancelled, error, unavailable, restored or not_found.
signal finished(result: String)

## The product the store sells; each game creates it in the Play Console (and later App Store Connect) with this id.
const PRODUCT := "full_game"
const PLUGINS := ["SlowSundayPhone"]

var store: Object = null
## Where owning the full game is written down; empty keeps nothing, as for the pretend store.
var cache_path := "user://store.cfg"
var _owned := false
var _price := ""
var _restoring := false
var _pending := false


func _ready() -> void:
	var preview := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--store" or arg.begins_with("--store="):
			preview = arg
	if preview != "":
		cache_path = ""
		use_store(PreviewStore.new(preview == "--store=owned"))
		return
	for plugin in PLUGINS:
		if Engine.has_singleton(plugin):
			use_store(Engine.get_singleton(plugin))
			return


## Hands the purchase to a store, or to none; the tests give it a fake one.
func use_store(new_store: Object) -> void:
	if store != null:
		for link in _links():
			if store.is_connected(link[0], link[1]):
				store.disconnect(link[0], link[1])
	store = new_store
	_price = ""
	_restoring = false
	_pending = false
	_owned = store != null and _cached()
	changed.emit()
	if store == null:
		return
	for link in _links():
		store.connect(link[0], link[1])
	store.call("billing_start")


func _links() -> Array:
	return [["billing_connected", _on_connected], ["billing_unavailable", _on_unavailable], ["price_found", _on_price],
		["purchase_finished", _on_purchase], ["owned_found", _on_owned]]


## Whether this build sells the full game at all.
func sold_here() -> bool:
	return store != null


func owned() -> bool:
	return _owned


## True on a phone that has not bought the full game, which then plays by the demo's limits.
func locked() -> bool:
	return store != null and not _owned


## The store's own price text, such as CA$6.99 in the player's currency, or "" until the store has said it.
func price() -> String:
	return _price


func buy() -> void:
	if locked():
		store.call("buy", PRODUCT)


## Asks the store again what the player owns, for a new phone or the game installed again.
func restore() -> void:
	if store != null:
		_restoring = true
		store.call("query_owned")


func _on_connected() -> void:
	store.call("query_price", PRODUCT)


func _on_unavailable(_message: String) -> void:
	if _restoring:
		_restoring = false
		finished.emit("unavailable")


func _on_price(product_id: String, text: String) -> void:
	if product_id == PRODUCT and text != _price:
		_price = text
		changed.emit()


func _on_purchase(product_id: String, status: String) -> void:
	if product_id != PRODUCT:
		return
	if status == "purchased":
		_pending = false
		_set_owned(true)
	elif status == "pending":
		_pending = true
	finished.emit(status)


## The store's list is the truth whenever it answers: a refunded purchase drops off it and locks the game again.
func _on_owned(product_ids: Variant) -> void:
	var has: bool = PRODUCT in product_ids
	var was := _owned
	_set_owned(has)
	if _restoring:
		_restoring = false
		finished.emit("restored" if has else "not_found")
	elif has and not was and _pending:
		_pending = false
		finished.emit("purchased")


func _set_owned(value: bool) -> void:
	if value == _owned:
		return
	_owned = value
	if cache_path != "":
		var cfg := ConfigFile.new()
		cfg.set_value("store", PRODUCT, value)
		cfg.save(cache_path)
	changed.emit()


func _cached() -> bool:
	var cfg := ConfigFile.new()
	return cache_path != "" and cfg.load(cache_path) == OK and bool(cfg.get_value("store", PRODUCT, false))


## A store that answers at once, for trying the purchase and the unlock on a computer.
class PreviewStore:
	signal billing_connected
	signal billing_unavailable(message: String)
	signal price_found(product_id: String, price: String)
	signal purchase_finished(product_id: String, status: String)
	signal owned_found(product_ids: PackedStringArray)

	var owned := PackedStringArray()

	func _init(bought: bool) -> void:
		if bought:
			owned.append(PRODUCT)

	func billing_start() -> void:
		(func() -> void:
			billing_connected.emit()
			owned_found.emit(owned)).call_deferred()

	func billing_ready() -> bool:
		return true

	func query_price(product_id: String) -> void:
		price_found.emit(product_id, "CA$6.99")

	func buy(product_id: String) -> void:
		owned.append(product_id)
		purchase_finished.emit(product_id, "purchased")

	func query_owned() -> void:
		owned_found.emit(owned)
