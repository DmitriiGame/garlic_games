@tool
extends Control
## Док редактора: те же поля, что и экран «Править данные», пишет сразу в data/.

var editor: CatalogEditor
var status: Label


func _ready() -> void:
	custom_minimum_size = Vector2(380, 0)
	var host := VBoxContainer.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Числа из data/. Сохранить пишет файлы проекта."
	host.add_child(status)
	editor = CatalogEditor.new()
	editor.dense = true
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.save_pressed.connect(_save)
	editor.reload_pressed.connect(_reload)
	host.add_child(editor)
	_reload()


func _reload() -> void:
	editor.set_bundle(DataFiles.read_res_bundle())
	status.text = "Прочитано из data/."


func _save() -> void:
	var message := DataFiles.write_res_bundle(editor.edited_bundle())
	var content := get_node_or_null("/root/Content")
	if content and content.has_method("load_all"):
		content.load_all()
		if content.problems.size() > 0:
			message += " Проверь: " + "; ".join(content.problems)
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("repair_state"):
		game.repair_state()
	status.text = message
	editor.set_status(message)
