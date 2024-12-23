## Represents and manages the game board. Stores references to entities that are in each cell and
## tells whether cells are occupied or not.
## Units can only move around the grid one at a time.
class_name GameBoard
extends Node2D

const DIRECTIONS = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

## Resource of type Grid.
@export var grid: Resource

## Mapping of coordinates of a cell to a reference to the unit it contains.
var _units := {}
var _selected_unit: Unit
var _active_unit: Unit
var _attacking_unit: Unit
var _walkable_cells := []
var _active_team := 0

@onready var _unit_overlay: UnitOverlay = $UnitOverlay
@onready var _attack_overlay: UnitOverlay = $AttackOverlay
@onready var _unit_path: UnitPath = $UnitPath
@onready var _menu = $PopupMenu


func _ready() -> void:
	_reinitialize()


func _unhandled_input(event: InputEvent) -> void:
	if _active_unit and event.is_action_pressed("ui_cancel"):
		_deselect_active_unit()
		_clear_active_unit()


func _get_configuration_warning() -> String:
	var warning := ""
	if not grid:
		warning = "You need a Grid resource for this node to work."
	return warning


## Returns `true` if the cell is occupied by a unit.
func is_occupied(cell: Vector2) -> bool:
	return _units.has(cell)


## Returns an array of cells a given unit can walk using the flood fill algorithm.
func get_walkable_cells(unit: Unit) -> Array:
	return _flood_fill(unit.cell, unit.move_range)


## Clears, and refills the `_units` dictionary with game objects that are on the board.
func _reinitialize() -> void:
	_units.clear()

	for child in get_children():
		var unit := child as Unit
		if not unit:
			continue

		if unit.team != _active_team:
			unit.set_inactive()

		_units[unit.cell] = unit


## Returns an array with all the coordinates of walkable cells based on the `max_distance`.
func _flood_fill(cell: Vector2, max_distance: int) -> Array:
	var array := []
	var stack := [cell]
	while not stack.size() == 0:
		var current = stack.pop_back()
		if not grid.is_within_bounds(current):
			continue
		if current in array:
			continue

		var difference: Vector2 = (current - cell).abs()
		var distance := int(difference.x + difference.y)
		if distance > max_distance:
			continue

		array.append(current)
		for direction in DIRECTIONS:
			var coordinates: Vector2 = current + direction
			if is_occupied(coordinates):
				continue
			if coordinates in array:
				continue
			# Minor optimization: If this neighbor is already queued
			#	to be checked, we don't need to queue it again
			if coordinates in stack:
				continue

			stack.append(coordinates)
	return array


## Updates the _units dictionary with the target position for the unit and asks the _active_unit to walk to it.
func _move_active_unit(new_cell: Vector2) -> void:
	if is_occupied(new_cell) or not new_cell in _walkable_cells:
		return

	_active_unit.can_move = false
	_units.erase(_active_unit.cell)
	_units[new_cell] = _active_unit
	_deselect_active_unit()
	_active_unit.walk_along(_unit_path.current_path)
	await _active_unit.walk_finished
	_active_unit.try_set_inactive()
	_clear_active_unit()


## Selects the unit in the `cell` if there's one there.
## Sets it as the `_active_unit` and draws its walkable cells and interactive move path. 
func _set_moving_unit() -> void:
	_active_unit = _selected_unit
	_active_unit.is_selected = true
	_walkable_cells = get_walkable_cells(_active_unit)
	_unit_overlay.draw(_walkable_cells)
	_unit_path.initialize(_walkable_cells)

func _set_attacking_unit() -> void:
	_attacking_unit = _selected_unit
	_attack_overlay.draw([_attacking_unit.cell + Vector2.LEFT, _attacking_unit.cell + Vector2.RIGHT, _attacking_unit.cell + Vector2.UP, _attacking_unit.cell + Vector2.DOWN])

func _attack(cell: Vector2) -> void:
	_attack_overlay.clear()

	if _units.has(cell) and cell.distance_to(_attacking_unit.cell) == 1:
		_attacking_unit.can_attack = false
		if _units[cell].take_damage(10):
			## delete unit
			_units[cell].queue_free()
			_units.erase(cell)

	_attacking_unit.try_set_inactive()
	_attacking_unit = null

## Deselects the active unit, clearing the cells overlay and interactive path drawing.
func _deselect_active_unit() -> void:
	_active_unit.is_selected = false
	_unit_overlay.clear()
	_unit_path.stop()


## Clears the reference to the _active_unit and the corresponding walkable cells.
func _clear_active_unit() -> void:
	_active_unit = null
	_walkable_cells.clear()


## Selects or moves a unit based on where the cursor is.
func _on_Cursor_accept_pressed(cell: Vector2) -> void:
	if _active_unit and _active_unit.is_selected:
		_move_active_unit(cell)
		return
	
	if _attacking_unit:
		_attack(cell)
		return
	
	if not _units.has(cell):
		return
	
	if _active_team != _units[cell].team:
		return
	
	_selected_unit = _units[cell]
	var test := get_global_mouse_position()
	_menu.set_item_disabled(0, !_selected_unit.can_move)
	_menu.set_item_disabled(1, !_selected_unit.can_attack)
	_menu.popup(Rect2(test.x, test.y, 100, 100))


## Updates the interactive path's drawing if there's an active and selected unit.
func _on_Cursor_moved(new_cell: Vector2) -> void:
	if _active_unit and _active_unit.is_selected:
		_unit_path.draw(_active_unit.cell, new_cell)


func _on_popup_menu_id_pressed(id):
	if id == 0: # moving
		_set_moving_unit()
	elif id == 1: # attacking
		_set_attacking_unit()
		
	_selected_unit = null

func _end_turn_pressed():
	if _active_team == 0:
		_active_team = 1
	else:
		_active_team = 0
	
	for child in get_children():
		var unit := child as Unit
		if not unit:
			continue

		if unit.team != _active_team:
			unit.set_inactive()
		else:
			unit.set_active()
