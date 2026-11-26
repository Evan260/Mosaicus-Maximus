@tool
extends EditorPlugin

const ExportPlugin := preload("export_plugin.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	# Listed under Project Settings; left at its default it is never written into project.godot.
	if not ProjectSettings.has_setting(ExportPlugin.NOTIFICATIONS):
		ProjectSettings.set_setting(ExportPlugin.NOTIFICATIONS, true)
	ProjectSettings.set_initial_value(ExportPlugin.NOTIFICATIONS, true)
	ProjectSettings.add_property_info({"name": ExportPlugin.NOTIFICATIONS, "type": TYPE_BOOL})
	ProjectSettings.set_as_basic(ExportPlugin.NOTIFICATIONS, true)
	_export_plugin = ExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
