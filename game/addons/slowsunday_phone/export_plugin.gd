@tool
extends EditorExportPlugin
## Adds the SlowSundayPhone library to Android exports with the libraries it uses, and writes the game's Play Games
## app id, notification colour and status-bar icon into the Gradle build before it runs.

const StatusIcon := preload("status_icon.gd")

const NAME := "SlowSundayPhone"
## Keep in step with the dependencies in plugin/build.gradle.kts.
const DEPENDENCIES := [
	"androidx.core:core:1.13.1",
	"com.google.android.gms:play-services-games-v2:22.1.0",
	"com.android.billingclient:billing:9.1.0",
]
const APP_ID := "slowsunday_phone/play_games_app_id"
const ICON := "slowsunday_phone/notification_icon"
const COLOR := "slowsunday_phone/notification_color"
const ICON_NAME := "slowsunday_phone_notification.png"


func _get_name() -> String:
	return NAME


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_export_options(platform: EditorExportPlatform) -> Array[Dictionary]:
	if not platform is EditorExportPlatformAndroid:
		return []
	return [
		{"option": {"name": APP_ID, "type": TYPE_STRING}, "default_value": ""},
		{
			"option": {"name": ICON, "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.png,*.webp,*.svg"},
			"default_value": "",
		},
		{"option": {"name": COLOR, "type": TYPE_COLOR}, "default_value": Color(0, 0, 0, 0)},
	]


func _get_export_option_warning(platform: EditorExportPlatform, option: String) -> String:
	if option == "gradle_build/use_gradle_build" and not get_option(option):
		return "SlowSunday Phone needs Use Gradle Build."
	if option == APP_ID and _app_id() != "" and not _app_id().is_valid_int():
		return "The Play Games app id is the number the Play Console shows for the game's Play Games Services project."
	return ""


func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	var kind := "debug" if debug else "release"
	return PackedStringArray([_addon_dir().path_join("bin/%s/%s-%s.aar" % [kind, NAME, kind])])


func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray(DEPENDENCIES)


func _get_android_manifest_application_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
	if _app_id() == "":
		# Play Games' own start-up provider tries to sign the player in at every launch, which fails without an app id.
		return '\t\t<provider android:name="com.google.android.gms.games.provider.PlayGamesInitProvider" android:authorities="${applicationId}.playgamesinitprovider" tools:node="remove" />\n'
	# Play Games reads the id as text, and a bare number in the manifest would be stored as an integer.
	return '\t\t<meta-data android:name="com.google.android.gms.games.APP_ID" android:value="@string/slowsunday_phone_play_games_app_id" />\n'


func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	if not features.has("android"):
		return
	var build_dir := str(get_option("gradle_build/gradle_build_directory")).strip_edges()
	build_dir = ProjectSettings.globalize_path(build_dir if build_dir != "" else "res://android/build")
	if not DirAccess.dir_exists_absolute(build_dir):
		push_warning("SlowSunday Phone: no Android build template at %s; install it from the Project menu." % build_dir)
		return
	_write_values(build_dir.path_join("res"))
	_write_icons(build_dir.path_join("res"))


func _write_values(res_dir: String) -> void:
	var color: Color = get_option(COLOR)
	var text := "\n".join(PackedStringArray([
		'<?xml version="1.0" encoding="utf-8"?>',
		"<!-- Written by the SlowSunday Phone export plugin on every Android export. -->",
		"<resources>",
		'    <string name="slowsunday_phone_play_games_app_id" translatable="false">%s</string>' % _app_id().xml_escape(),
		'    <color name="slowsunday_phone_notification_color">#%02X%02X%02X%02X</color>' % [color.a8, color.r8, color.g8, color.b8],
		"</resources>",
		"",
	]))
	DirAccess.make_dir_recursive_absolute(res_dir.path_join("values"))
	var file := FileAccess.open(res_dir.path_join("values/slowsunday_phone_game.xml"), FileAccess.WRITE)
	if file == null:
		push_error("SlowSunday Phone: cannot write the game's values into %s" % res_dir)
		return
	file.store_string(text)


func _write_icons(res_dir: String) -> void:
	var source := _icon_source()
	var image := Image.new()
	if source == "" or image.load(ProjectSettings.globalize_path(source)) != OK:
		push_warning("SlowSunday Phone: no picture for the notification icon, so notifications show a plain sun.")
		_remove_icons(res_dir)
		return
	if StatusIcon.is_tile(image):
		push_warning("SlowSunday Phone: %s fills its whole square, so the status-bar icon drawn from it is only a filled square; set %s to a picture on a clear background, such as the main building's sprite." % [source, ICON])
	var white := StatusIcon.shape(image)
	if white == null:
		_remove_icons(res_dir)
		return
	for density in StatusIcon.DENSITIES:
		var dir := res_dir.path_join("drawable-%s" % density)
		DirAccess.make_dir_recursive_absolute(dir)
		StatusIcon.at_size(white, StatusIcon.DENSITIES[density]).save_png(dir.path_join(ICON_NAME))


func _remove_icons(res_dir: String) -> void:
	for density in StatusIcon.DENSITIES:
		var file := res_dir.path_join("drawable-%s/%s" % [density, ICON_NAME])
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


## The picture the status-bar icon is drawn from: this plugin's option, else the monochrome launcher icon, else the
## game's own icon.
func _icon_source() -> String:
	for path in [get_option(ICON), get_option("launcher_icons/adaptive_monochrome_432x432")]:
		if str(path).strip_edges() != "":
			return str(path).strip_edges()
	return str(ProjectSettings.get_setting("application/config/icon", ""))


func _app_id() -> String:
	return str(get_option(APP_ID)).strip_edges()


func _addon_dir() -> String:
	return (get_script() as Script).resource_path.get_base_dir()
