class_name Backdrop
extends Control
## The clear cover `Ui.closes_with` puts under a window, which closes it on a click beside it. Controls in the
## `ABOVE` group, such as the workshop's top bar, still take their own clicks through it.

const ABOVE := "above_backdrops"


func _has_point(point: Vector2) -> bool:
	var at := get_global_transform() * point
	for c in get_tree().get_nodes_in_group(ABOVE):
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(at):
			return false
	return true
