@tool
extends EditorPlugin

var dock: Control


func _enter_tree() -> void:
	dock = preload("res://addons/balance_editor/dock.gd").new()
	dock.name = "Баланс"
	call_deferred("_mount_dock")


func _mount_dock() -> void:
	if dock and is_inside_tree():
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
