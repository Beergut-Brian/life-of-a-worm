## JSON save under user://saves/<profile>.json. Autoload: Save.
## The launcher passes --profile=<id>; default "p1".
## Settings (volumes, screen shake, solo playtest) are per install, not per profile:
## user://settings.json, written on every change.
extends Node

signal saved()
signal loaded()

var profile: String = "p1"
## Which save of this profile is open: "" = the profile's own file; a game with several saves per
## profile (Worm's bait tins: "tin1".."tin3") opens one with use_slot(). Never restored at boot.
var slot := ""
## Where save files live. Tests point it at a scratch folder (res://.scratch/...) so they never
## write a real tin; the game never changes it.
var dir := "user://saves"
var _data: Dictionary = {}
var _dirty := false
## Tests point this somewhere else so they never touch the real settings.
var settings_path := "user://settings.json"
var _settings: Dictionary = {}


func _ready() -> void:
	profile = profile_from_args(OS.get_cmdline_args() + OS.get_cmdline_user_args(), profile)
	_load()
	reload_settings()


## The launcher passes --profile=<id> without a "--" separator, so Godot puts it in
## get_cmdline_args(), not get_cmdline_user_args(); accept it in either.
static func profile_from_args(args: PackedStringArray, default: String) -> String:
	var out := default
	for arg in args:
		if arg.begins_with("--profile="):
			var id := arg.trim_prefix("--profile=").strip_edges()
			if id.is_valid_identifier():   # keeps it a plain file name under user://saves
				out = id
	return out


func get_value(key: String, default = null):
	return _data.get(key, default)


func set_value(key: String, value) -> void:
	_data[key] = value
	_dirty = true


func flush() -> void:
	if not _dirty:
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not open %s" % _path())
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
	_dirty = false
	saved.emit()


func get_setting(key: String, default = null):
	return _settings.get(key, default)


func set_setting(key: String, value) -> void:
	_settings[key] = value
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not open %s" % settings_path)
		return
	f.store_string(JSON.stringify(_settings, "\t"))
	f.close()


func reload_settings() -> void:
	_settings = {}
	if FileAccess.file_exists(settings_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if parsed is Dictionary:
			_settings = parsed


func wipe_settings() -> void:
	_settings = {}
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)


## Switch to another profile's save (the test sandbox): flushes the current one, loads the new.
func use_profile(id: String) -> void:
	flush()
	profile = id
	slot = ""
	_load()


## Open another save of the same profile (flushes the current one first). "" = the profile's own.
func use_slot(id: String) -> void:
	flush()
	slot = id if id.is_valid_identifier() else ""
	_load()


## Path of a profile's save, for tools that read a slot without opening it (the tin shelf).
func path_for(p_slot: String, p_profile := "") -> String:
	var who := p_profile if p_profile != "" else profile
	return "%s/%s.json" % [dir, who if p_slot == "" else "%s_%s" % [who, p_slot]]


func wipe() -> void:
	_data = {}
	_dirty = true
	flush()


func _path() -> String:
	return path_for(slot)


func _load() -> void:
	if not FileAccess.file_exists(_path()):
		_data = {}
		return
	var text := FileAccess.get_file_as_string(_path())
	var parsed = JSON.parse_string(text)
	_data = parsed if parsed is Dictionary else {}
	loaded.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush()
