# Copyright © 2026 CosmonautFrog - MIT License

@tool
class_name CosmoTreePreset
extends Resource
## A saved tree type: the parameters and materials of a [CosmoTreeGen]. [br][br]
## The toolbar Preset menu lists every CosmoTreePreset saved as .tres in the project.

## See [member CosmoTreeGen.trunk_params].
@export var trunk_params: CosmoTrunkParams
## See [member CosmoTreeGen.branch_levels].
@export var branch_levels: Array[CosmoBranchLevel]
## See [member CosmoTreeGen.foliage_params].
@export var foliage_params: CosmoFoliageParams

## See [member CosmoTreeGen.trunk_material].
@export var trunk_material: Material
## See [member CosmoTreeGen.foliage_material].
@export var foliage_material: Material
## See [member CosmoTreeGen.texel_density].
@export var texel_density: float = 64.0

## See [member CosmoTreeGen.combine_trunk_and_foliage].
@export var combine_trunk_and_foliage: bool = true
## See [member CosmoTreeGen.flat_shading].
@export var flat_shading: bool = false
## See [member CosmoTreeGen.create_trunk].
@export var create_trunk: bool = true
## See [member CosmoTreeGen.create_foliage].
@export var create_foliage: bool = true
## See [member CosmoTreeGen.lod_trunk_share].
@export_range(0.0, 1.0, 0.01) var lod_trunk_share: float = 0.33


func is_valid() -> bool:
	return trunk_params != null


func get_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if trunk_params == null:
		errors.append("missing trunk_params")
	return errors
