extends RefCounted
## Порт match-3 из корневого game.js: обмен, каскады, без стартовых совпадений, тупик мешается.

const COLS := 6
const ROWS := 5
const TYPES: Array[String] = ["baguette", "brains", "bandage", "energy_drink", "pot_lid"]

var grid: Array = []
var cursed: Dictionary = {}
var anim_steps: Array = []


func build(rng: RandomNumberGenerator) -> void:
	for _attempt in 80:
		_fill_clean(rng)
		if find_runs().is_empty() and has_move():
			cursed.clear()
			return
	_force_playable()
	cursed.clear()


func _force_playable() -> void:
	var other := "brains"
	var attack := "baguette"
	for r in ROWS:
		for c in COLS:
			grid[r][c] = "energy_drink" if (r + c) % 2 == 0 else "pot_lid"
	var r0 := 1
	var c0 := 1
	for dr in 2:
		for dc in 3:
			grid[r0 + dr][c0 + dc] = other
	grid[r0][c0] = attack
	grid[r0][c0 + 1] = attack
	grid[r0][c0 + 2] = other
	grid[r0 + 1][c0 + 2] = attack
	if find_runs().is_empty() and has_move():
		return
	grid[r0][c0 + 2] = attack
	grid[r0 + 1][c0 + 2] = other


func cell(r: int, c: int) -> String:
	return str(grid[r][c])


func is_cursed(r: int, c: int) -> bool:
	return cursed.has("%d,%d" % [r, c])


func curse_cells(rng: RandomNumberGenerator, count: int) -> void:
	var guard := 0
	var made := 0
	while made < count and guard < 40:
		guard += 1
		var r := rng.randi_range(0, ROWS - 1)
		var c := rng.randi_range(0, COLS - 1)
		var key := "%d,%d" % [r, c]
		if cursed.has(key):
			continue
		cursed[key] = true
		made += 1


func clear_curses() -> void:
	cursed.clear()


func steal(rng: RandomNumberGenerator, prefer: Array) -> String:
	var options: Array = []
	for r in ROWS:
		for c in COLS:
			if prefer.has(cell(r, c)):
				options.append([r, c])
	if options.is_empty():
		for r in ROWS:
			for c in COLS:
				options.append([r, c])
	if options.is_empty():
		return ""
	var pick: Array = options[rng.randi_range(0, options.size() - 1)]
	var taken := cell(pick[0], pick[1])
	grid[pick[0]][pick[1]] = _random_type(rng)
	return taken


func try_swap(r1: int, c1: int, r2: int, c2: int) -> bool:
	if absi(r1 - r2) + absi(c1 - c2) != 1:
		return false
	if is_cursed(r1, c1) or is_cursed(r2, c2):
		return false
	_exchange(r1, c1, r2, c2)
	if find_runs().is_empty():
		_exchange(r1, c1, r2, c2)
		return false
	return true


func resolve(rng: RandomNumberGenerator) -> Array:
	var awarded: Array = []
	var combo := 0
	anim_steps.clear()
	while true:
		var runs := find_runs()
		if runs.is_empty():
			break
		combo += 1
		var cleared: Array = []
		for run in runs:
			run["combo"] = combo
			awarded.append(run)
			for pos in run.get("cells", []):
				cleared.append([int(pos[0]), int(pos[1])])
		anim_steps.append({"op": "clear", "cells": cleared})
		_erase_runs(runs)
		_collapse(rng)
	if not has_move():
		build(rng)
		awarded.append({"type": "_shuffle", "n": 0, "combo": 0})
		anim_steps.append({"op": "shuffle"})
	return awarded


func best_swap(prefer: String = "baguette") -> Array:
	var best: Array = []
	var best_score := -1
	for r in ROWS:
		for c in COLS:
			for step in [[0, 1], [1, 0]]:
				var r2: int = r + int(step[0])
				var c2: int = c + int(step[1])
				if r2 >= ROWS or c2 >= COLS:
					continue
				if is_cursed(r, c) or is_cursed(r2, c2):
					continue
				_exchange(r, c, r2, c2)
				var runs := find_runs()
				_exchange(r, c, r2, c2)
				if runs.is_empty():
					continue
				var score := 0
				for run in runs:
					var n := int(run["n"])
					var kind := str(run["type"])
					score += n
					if kind == prefer:
						score += 14 + n
					elif kind == "baguette":
						score += 6
					elif kind == "bandage":
						score += 2
				if score > best_score:
					best_score = score
					best = [r, c, r2, c2]
	return best


func find_runs() -> Array:
	var runs: Array = []
	for r in ROWS:
		var start := 0
		while start < COLS:
			var type := cell(r, start)
			var end := start + 1
			while end < COLS and type != "" and cell(r, end) == type:
				end += 1
			if type != "" and end - start >= 3:
				var cells: Array = []
				for c in range(start, end):
					cells.append([r, c])
				runs.append({"type": type, "n": end - start, "cells": cells})
			start = end if end > start else start + 1
	for c in COLS:
		var start := 0
		while start < ROWS:
			var type := cell(start, c)
			var end := start + 1
			while end < ROWS and type != "" and cell(end, c) == type:
				end += 1
			if type != "" and end - start >= 3:
				var cells: Array = []
				for r in range(start, end):
					cells.append([r, c])
				runs.append({"type": type, "n": end - start, "cells": cells})
			start = end if end > start else start + 1
	return runs


func has_move() -> bool:
	for r in ROWS:
		for c in COLS:
			for step in [[0, 1], [1, 0]]:
				var r2: int = r + int(step[0])
				var c2: int = c + int(step[1])
				if r2 >= ROWS or c2 >= COLS:
					continue
				if is_cursed(r, c) or is_cursed(r2, c2):
					continue
				_exchange(r, c, r2, c2)
				var ok := not find_runs().is_empty()
				_exchange(r, c, r2, c2)
				if ok:
					return true
	return false


func _fill_clean(rng: RandomNumberGenerator) -> void:
	grid.clear()
	for r in ROWS:
		var row: Array = []
		for c in COLS:
			var type := ""
			for _try in 16:
				type = _random_type(rng)
				if not _would_match(row, r, c, type):
					break
			row.append(type)
		grid.append(row)


func _would_match(row: Array, r: int, c: int, type: String) -> bool:
	if c >= 2 and str(row[c - 1]) == type and str(row[c - 2]) == type:
		return true
	if r >= 2 and str(grid[r - 1][c]) == type and str(grid[r - 2][c]) == type:
		return true
	return false


func _erase_runs(runs: Array) -> void:
	for run in runs:
		for pos in run.get("cells", []):
			grid[int(pos[0])][int(pos[1])] = ""


func _collapse(rng: RandomNumberGenerator) -> void:
	var moves: Array = []
	var spawns: Array = []
	for c in COLS:
		var stack: Array = []
		for r in range(ROWS - 1, -1, -1):
			if cell(r, c) != "":
				stack.append([cell(r, c), r])
		var write := ROWS - 1
		for item in stack:
			var type: String = str(item[0])
			var old_r: int = int(item[1])
			grid[write][c] = type
			if old_r != write:
				moves.append([old_r, c, write, c])
			write -= 1
		while write >= 0:
			var born := _random_type(rng)
			grid[write][c] = born
			spawns.append([write, c, born])
			write -= 1
	anim_steps.append({"op": "drop", "moves": moves, "spawns": spawns})


func _exchange(r1: int, c1: int, r2: int, c2: int) -> void:
	var saved: String = cell(r1, c1)
	grid[r1][c1] = cell(r2, c2)
	grid[r2][c2] = saved


func _random_type(rng: RandomNumberGenerator) -> String:
	return TYPES[rng.randi_range(0, TYPES.size() - 1)]
