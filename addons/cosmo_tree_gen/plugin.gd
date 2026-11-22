# Copyright © 2026 CosmonautFrog - MIT License

@tool
extends EditorPlugin

const Settings := preload("./core/settings.gd")
const TreeGenBar := preload("./ui/tree_gen_bar.gd")
const BAR_SCENE := preload("./ui/tree_gen_bar.tscn")

var _bar: TreeGenBar


func _enter_tree() -> void:
	Settings.setup_settings()
	_bar = BAR_SCENE.instantiate()
	_bar.hide()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)


func _exit_tree() -> void:
	_edit(null)
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	_bar.queue_free()
	_bar = null


func _handles(object: Object) -> bool:
	return object is CosmoTreeGen


func _edit(object: Object) -> void:
	_bar.tree = object as CosmoTreeGen


func _make_visible(visible: bool) -> void:
	_bar.visible = visible
