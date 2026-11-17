@tool
extends RefCounted
class_name DataFiles
## Чтение и запись data/*.json. Дробные целые сжимаются, чтобы файл не шумел.

const NAMES: Array[String] = ["balance", "biomes", "creatures", "items", "upgrades"]


static func res_path(name: String) -> String:
	return "res://data/%s.json" % name


static func user_path(name: String) -> String:
	return "user://%s.json" % name


static func read_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func read_res_bundle() -> Dictionary:
	var bundle := {}
	for entry in NAMES:
		bundle[entry] = read_dict(res_path(entry))
	return bundle


static func write_text(path: String, data: Variant) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(sanitize(data), "\t") + "\n")
	return OK


static func write_res_bundle(bundle: Dictionary) -> String:
	for entry in NAMES:
		if typeof(bundle.get(entry)) != TYPE_DICTIONARY:
			return "нет раздела %s" % entry
		var err := write_text(res_path(entry), bundle[entry])
		if err != OK:
			return "не записался %s (%s)" % [entry, error_string(err)]
	return "записано в data/"


static func sanitize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var snapped := snappedf(float(value), 0.0001)
			if is_equal_approx(snapped, round(snapped)):
				return int(round(snapped))
			return snapped
		TYPE_DICTIONARY:
			var copy := {}
			for key in value.keys():
				copy[key] = sanitize(value[key])
			return copy
		TYPE_ARRAY:
			var copy: Array = []
			for item in value:
				copy.append(sanitize(item))
			return copy
		_:
			return value
