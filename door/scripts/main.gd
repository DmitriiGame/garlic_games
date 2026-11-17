extends Control
## Портретный интерфейс: титр, день, раскрытие, карточка конца, правка текстов.

const NIGHT := Color("1a1613")
const INK := Color("14110e")
const PAPER := Color("f4ecdf")
const MUTED := Color("a39888")
const BLOOD := Color("e5484d")
const MOSS := Color("c5d67a")
const AMBER := Color("f0a05a")
const PANEL := Color("241f1b")

var display: Font
var body: Font
var column: Control
var shake_host: Control
var screens: Dictionary = {}
var current: Control
var stick: Control
var day_title: Label
var day_text: RichTextLabel
var day_hint: Label
var choice_a: Button
var choice_b: Button
var reveal_text: RichTextLabel
var reveal_notes: Label
var delta_box: HBoxContainer
var reveal_stick: Control
var next_button: Button
var end_kicker: Label
var end_day: Label
var end_title: Label
var end_line: Label
var end_bits: VBoxContainer
var end_stats: HBoxContainer
var end_seed: Label
var end_again: Button
var end_same: Button
var mute_buttons: Array[Button] = []
var stat_numbers: Dictionary = {}
var type_label: RichTextLabel
var type_left: int = 0
var shake: float = 0.0
var editor: Control
var shot_mode: bool = false


func _ready() -> void:
	shot_mode = OS.get_environment("DOOR_SHOT") != ""
	display = _font("res://fonts/Unbounded.ttf", 780)
	body = _font("res://fonts/Manrope.ttf", 560)
	_build()
	_show_screen(screens.title)
	if shot_mode:
		_run_shots()


func _font(path: String, weight: int) -> Font:
	var file := load(path) as Font
	var variation := FontVariation.new()
	variation.base_font = file
	variation.variation_opentype = {"wght": weight}
	return variation


func _process(delta: float) -> void:
	if type_label != null and type_left > 0:
		var step := maxi(1, int(delta / 0.012))
		type_left = maxi(0, type_left - step)
		var total := maxi(type_label.get_total_character_count(), type_label.text.length())
		type_label.visible_characters = maxi(0, total - type_left)
	if shake > 0.5:
		var kick := shake
		shake_host.offset_left = randf_range(-kick, kick)
		shake_host.offset_top = randf_range(-kick, kick)
		shake_host.offset_right = shake_host.offset_left
		shake_host.offset_bottom = shake_host.offset_top
		shake = lerpf(shake, 0.0, 1.0 - pow(0.04, delta))
	elif shake_host.offset_left != 0.0:
		shake = 0.0
		shake_host.offset_left = 0
		shake_host.offset_top = 0
		shake_host.offset_right = 0
		shake_host.offset_bottom = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event is InputEventMouseButton and event.pressed and type_left > 0:
		_skip_type()
		return
	if event is InputEventScreenTouch and event.pressed and type_left > 0:
		_skip_type()
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_M:
		_on_mute()
	elif current == screens.day and key.keycode == KEY_1:
		_on_choice("a")
	elif current == screens.day and key.keycode == KEY_2:
		_on_choice("b")
	elif current == screens.reveal and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER):
		_on_next()
	elif current == screens.title and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE):
		_on_start()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = NIGHT
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	column = Control.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	get_viewport().size_changed.connect(_fit_column)
	_fit_column()

	shake_host = Control.new()
	shake_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	shake_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(shake_host)

	screens.title = _build_title()
	screens.day = _build_day()
	screens.reveal = _build_reveal()
	screens["end"] = _build_end()
	editor = preload("res://scripts/editor_ui.gd").new()
	editor.set_anchors_preset(Control.PRESET_FULL_RECT)
	editor.visible = false
	editor.setup(func() -> void: _show_screen(screens.title))
	shake_host.add_child(editor)
	screens.editor = editor
	for key in ["title", "day", "reveal", "end"]:
		screens[key].visible = false


func _fit_column() -> void:
	var view := get_viewport_rect().size
	var width := view.x
	if view.x > view.y:
		width = minf(view.x, view.y * 9.0 / 16.0)
	var x := (view.x - width) * 0.5
	column.offset_left = x
	column.offset_top = 0
	column.offset_right = -(view.x - x - width)
	column.offset_bottom = 0


func _build_title() -> Control:
	var screen := _screen()
	var box := _column(screen)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var art := _art_host(340)
	box.add_child(art)
	var stick_title: Control = preload("res://scripts/stick.gd").new()
	stick_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick_title.scene_name = "door"
	art.add_child(stick_title)
	box.add_child(_label("ОТКРОЕШЬ", 64, PAPER, display, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("ДВЕРЬ?", 92, AMBER, display, HORIZONTAL_ALIGNMENT_CENTER))
	var tag := _label(str(Game.meta.get("tagline", "Тридцать дней. Один стук. Два пальца.")), 26, MUTED, body, HORIZONTAL_ALIGNMENT_CENTER)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tag)
	var start := _button("Начать", true)
	start.pressed.connect(_on_start)
	box.add_child(start)
	var edit := _button("Править события", false)
	edit.pressed.connect(_open_editor)
	box.add_child(edit)
	var mute := _button("", false)
	mute.custom_minimum_size = Vector2(0, 64)
	mute.pressed.connect(_on_mute)
	mute_buttons.append(mute)
	box.add_child(mute)
	_refresh_mute()
	return screen


func _build_day() -> Control:
	var screen := _screen()
	var box := _column(screen)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	day_title = _label("ДЕНЬ 01", 36, PAPER, display, HORIZONTAL_ALIGNMENT_LEFT)
	day_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(day_title)
	var mute := _button("звук", false)
	mute.custom_minimum_size = Vector2(148, 64)
	mute.pressed.connect(_on_mute)
	mute_buttons.append(mute)
	top.add_child(mute)
	box.add_child(top)
	box.add_child(_stat_row())
	day_hint = _label("", 22, MUTED, body, HORIZONTAL_ALIGNMENT_LEFT)
	day_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(day_hint)
	var art := _art_host(300)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = 1.1
	stick = preload("res://scripts/stick.gd").new()
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(stick)
	box.add_child(art)
	day_text = _rich(30)
	day_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	day_text.size_flags_stretch_ratio = 0.9
	day_text.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_skip_type()
	)
	box.add_child(day_text)
	choice_a = _button("…", true)
	choice_a.pressed.connect(func() -> void: _on_choice("a"))
	choice_b = _button("…", false)
	choice_b.pressed.connect(func() -> void: _on_choice("b"))
	box.add_child(choice_a)
	box.add_child(choice_b)
	return screen


func _build_reveal() -> Control:
	var screen := _screen()
	var box := _column(screen)
	box.add_child(_label("И ВОТ", 22, AMBER, display, HORIZONTAL_ALIGNMENT_LEFT))
	var art := _art_host(280)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reveal_stick = preload("res://scripts/stick.gd").new()
	reveal_stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(reveal_stick)
	box.add_child(art)
	reveal_text = _rich(36)
	reveal_text.custom_minimum_size = Vector2(0, 160)
	reveal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reveal_text.size_flags_stretch_ratio = 0.8
	box.add_child(reveal_text)
	delta_box = HBoxContainer.new()
	delta_box.alignment = BoxContainer.ALIGNMENT_CENTER
	delta_box.add_theme_constant_override("separation", 16)
	box.add_child(delta_box)
	reveal_notes = _label("", 22, AMBER, body, HORIZONTAL_ALIGNMENT_CENTER)
	reveal_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(reveal_notes)
	next_button = _button("Дальше", true)
	next_button.pressed.connect(_on_next)
	box.add_child(next_button)
	return screen


func _build_end() -> Control:
	var screen := _screen()
	var box := _column(screen)
	end_kicker = _label("ОТКРОЕШЬ ДВЕРЬ?", 20, AMBER, display, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(end_kicker)
	end_day = _label("14", 120, PAPER, display, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(end_day)
	end_title = _label("", 42, PAPER, display, HORIZONTAL_ALIGNMENT_CENTER)
	end_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_title)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = AMBER
	box.add_child(rule)
	end_line = _label("", 26, PAPER, body, HORIZONTAL_ALIGNMENT_CENTER)
	end_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_line)
	var art := _art_host(220)
	var end_stick: Control = preload("res://scripts/stick.gd").new()
	end_stick.name = "EndStick"
	end_stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(end_stick)
	box.add_child(art)
	end_bits = VBoxContainer.new()
	end_bits.add_theme_constant_override("separation", 4)
	box.add_child(end_bits)
	end_stats = HBoxContainer.new()
	end_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	end_stats.add_theme_constant_override("separation", 14)
	box.add_child(end_stats)
	end_seed = _label("", 16, MUTED, body, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(end_seed)
	end_again = _button("Ещё раз", true)
	end_again.pressed.connect(_on_start)
	box.add_child(end_again)
	end_same = _button("То же зерно", false)
	end_same.pressed.connect(_on_same_seed)
	box.add_child(end_same)
	var home := _button("На титр", false)
	home.pressed.connect(func() -> void: _show_screen(screens.title))
	box.add_child(home)
	return screen


func _screen() -> Control:
	var screen := MarginContainer.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_theme_constant_override("margin_left", 28)
	screen.add_theme_constant_override("margin_right", 28)
	screen.add_theme_constant_override("margin_top", 22)
	screen.add_theme_constant_override("margin_bottom", 18)
	shake_host.add_child(screen)
	return screen


func _column(screen: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(box)
	return box


func _art_host(min_h: float) -> Control:
	var host := Panel.new()
	host.custom_minimum_size = Vector2(0, min_h)
	host.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color("120f0d")
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	host.add_theme_stylebox_override("panel", style)
	return host


func _label(text: String, size: int, color: Color, font: Font, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _rich(size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = false
	label.scroll_active = true
	label.selection_enabled = false
	label.context_menu_enabled = false
	label.shortcut_keys_enabled = false
	label.fit_content = false
	label.scroll_following = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("normal_font", body)
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_color_override("default_color", PAPER)
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	return label


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(0, 92)
	button.add_theme_font_override("font", display)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_stylebox_override("normal", _button_style(primary, false))
	button.add_theme_stylebox_override("hover", _button_style(primary, true))
	button.add_theme_stylebox_override("pressed", _button_style(primary, true))
	button.add_theme_stylebox_override("focus", _button_style(primary, true))
	button.add_theme_stylebox_override("disabled", _button_style(false, false))
	button.add_theme_color_override("font_color", INK if primary else PAPER)
	button.add_theme_color_override("font_hover_color", INK if primary else AMBER)
	button.add_theme_color_override("font_pressed_color", INK if primary else AMBER)
	button.add_theme_color_override("font_focus_color", INK if primary else PAPER)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button


func _button_style(primary: bool, hot: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	if primary:
		style.bg_color = Color("ffb56e") if hot else AMBER
	else:
		style.bg_color = Color("2c261f") if hot else Color(0, 0, 0, 0)
		style.set_border_width_all(3)
		style.border_color = AMBER if hot else PAPER
	return style


func _stat_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in Game.STAT_ORDER:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		var number := _label("0", 40, PAPER, display, HORIZONTAL_ALIGNMENT_CENTER)
		stat_numbers[id] = number
		cell.add_child(number)
		var name := _label(Game.stat_label(id), 20, MUTED, body, HORIZONTAL_ALIGNMENT_CENTER)
		cell.add_child(name)
		row.add_child(cell)
	return row


func _refresh_stats(pop_id: String = "") -> void:
	for id in Game.STAT_ORDER:
		var value := int(Game.stats.get(id, 0))
		var number: Label = stat_numbers[id]
		number.text = str(value)
		if value <= 0:
			number.add_theme_color_override("font_color", BLOOD)
		elif value == 1:
			number.add_theme_color_override("font_color", AMBER)
		else:
			number.add_theme_color_override("font_color", PAPER)
		if id == pop_id:
			_pop(number)


func _pop(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.28, 1.28), 0.08)
	tween.tween_property(node, "scale", Vector2.ONE, 0.12)


func _show_screen(screen: Control) -> void:
	if current == screen:
		screen.visible = true
		return
	var previous := current
	screen.visible = true
	screen.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(screen, "modulate:a", 1.0, 0.22)
	if previous != null and previous != screen:
		tween.tween_property(previous, "modulate:a", 0.0, 0.16)
		tween.chain().tween_callback(func() -> void:
			previous.visible = false
			previous.modulate.a = 1.0
		)
	current = screen


func _type_into(label: RichTextLabel, text: String) -> void:
	label.text = text
	var count := label.get_total_character_count()
	if count <= 0:
		count = text.length()
	label.visible_characters = 0
	type_label = label
	type_left = count


func _skip_type() -> void:
	if type_label == null:
		return
	type_label.visible_characters = -1
	type_left = 0


func _on_mute() -> void:
	Sfx.toggle_mute()
	_refresh_mute()
	Sfx.play("tap")


func _refresh_mute() -> void:
	var caption := "Тихо" if Sfx.muted else "Звук"
	for button in mute_buttons:
		button.text = caption


func _on_start() -> void:
	Sfx.play("tap")
	Game.start_run()
	_show_day()


func _on_same_seed() -> void:
	Sfx.play("tap")
	Game.start_run(Game.seed_value)
	_show_day()


func _open_editor() -> void:
	Sfx.play("tap")
	editor.reload()
	_show_screen(screens.editor)


func _show_day() -> void:
	day_title.text = "ДЕНЬ %02d" % Game.day
	day_hint.text = Game.night_hint()
	_refresh_stats()
	_refresh_mute()
	stick.scene_name = Game.scene_id()
	stick.mood = "idle"
	_type_into(day_text, Game.setup_text())
	_apply_choice_button(choice_a, "a")
	_apply_choice_button(choice_b, "b")
	var scene_id := Game.scene_id()
	if scene_id in ["door", "letter", "cult", "soldier", "kid", "open"]:
		Sfx.play("knock")
	else:
		Sfx.play("whoosh")
	_show_screen(screens.day)


func _apply_choice_button(button: Button, which: String) -> void:
	var view: Dictionary = Game.choice_view(which)
	button.disabled = not bool(view.enabled)
	if button.disabled:
		var missing: Array = view.missing
		button.text = "%s\nнет: %s" % [view.label, ", ".join(missing)]
	else:
		button.text = str(view.label)


func _on_choice(which: String) -> void:
	if current != screens.day:
		return
	var button := choice_a if which == "a" else choice_b
	if button.disabled:
		return
	_skip_type()
	Sfx.play("tap")
	var reveal: Dictionary = Game.choose(which)
	_show_reveal(reveal)


func _show_reveal(reveal: Dictionary) -> void:
	_type_into(reveal_text, str(reveal.get("text", "")))
	var notes: Array = reveal.get("notes", [])
	reveal_notes.text = "\n".join(notes)
	for child in delta_box.get_children():
		child.queue_free()
	var deltas: Dictionary = reveal.get("deltas", {})
	for id in Game.STAT_ORDER:
		if not deltas.has(id) or int(deltas[id]) == 0:
			continue
		var amount := int(deltas[id])
		var chip := _label(
			"%s%d %s" % ["+" if amount > 0 else "−", absi(amount), Game.stat_label(id)],
			28,
			MOSS if amount > 0 else BLOOD,
			display,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		chip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		delta_box.add_child(chip)
		_pop(chip)
	_refresh_stats()
	var scene_now := str(reveal.get("scene", "quiet"))
	var mood_now := "bad" if bool(reveal.get("bad", false)) else "good"
	stick.scene_name = scene_now
	stick.mood = mood_now
	if reveal_stick:
		reveal_stick.scene_name = scene_now
		reveal_stick.mood = mood_now
	if bool(reveal.get("dead", false)):
		next_button.text = "Это конец"
		Sfx.play("bad")
		_bump_shake(16)
	elif bool(reveal.get("won", false)):
		next_button.text = "Итог"
		Sfx.play("good")
	elif bool(reveal.get("bad", false)):
		next_button.text = "Дальше"
		Sfx.play("bad")
		_bump_shake(12)
	else:
		next_button.text = "Дальше"
		Sfx.play("good")
	_show_screen(screens.reveal)


func _bump_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func _on_next() -> void:
	if current != screens.reveal:
		return
	Sfx.play("tap")
	if Game.run_over:
		_show_end()
	else:
		_show_day()


func _show_end() -> void:
	var won := Game.won
	end_kicker.text = "СЕРИЯ ЗАКРЫТА" if won else "СЕРИЯ ОБОРВАЛАСЬ"
	end_kicker.add_theme_color_override("font_color", MOSS if won else BLOOD)
	end_day.text = "%02d" % Game.day
	end_day.add_theme_color_override("font_color", MOSS if won else PAPER)
	end_title.text = Game.ending_title
	end_line.text = Game.ending_line
	for child in end_bits.get_children():
		child.queue_free()
	for bit in Game.epitaphs(4):
		end_bits.add_child(_label(bit, 22, AMBER, body, HORIZONTAL_ALIGNMENT_CENTER))
	for child in end_stats.get_children():
		child.queue_free()
	for id in Game.STAT_ORDER:
		end_stats.add_child(_label("%s %d" % [Game.stat_label(id), int(Game.stats.get(id, 0))], 20, PAPER, body, HORIZONTAL_ALIGNMENT_CENTER))
	end_seed.text = "зерно %d  ·  день %d из %d" % [Game.seed_value, Game.day, Game.days_to_win]
	var end_stick: Control = screens["end"].find_child("EndStick", true, false)
	if end_stick:
		end_stick.scene_name = "win" if won else "death"
		end_stick.mood = "good" if won else "bad"
	if won:
		Sfx.play("win")
	else:
		Sfx.play("death")
		_bump_shake(18)
	_show_screen(screens["end"])


func _run_shots() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_fit_column()
	await get_tree().create_timer(0.35).timeout
	await _shot("01-title")
	Game.start_run(7)
	_show_day()
	_skip_type()
	await get_tree().create_timer(0.25).timeout
	await _shot("02-day")
	_on_choice("a")
	_skip_type()
	await get_tree().create_timer(0.25).timeout
	await _shot("03-reveal")
	Game.run_over = true
	Game.won = false
	Game.day = 14
	Game.ending_title = "Тебя съели на пороге"
	Game.ending_line = "Он сказал, что он из ЖЭКа. ЖЭК теперь с зубами."
	Game.stats = {"food": 0, "health": 0, "sanity": 2, "ammo": 1}
	Game.flags = {"has_dog": true, "refused_neighbor": true, "trader_fair": true}
	Game.flag_order.clear()
	Game.flag_order.append("refused_neighbor")
	Game.flag_order.append("has_dog")
	Game.flag_order.append("trader_fair")
	_show_end()
	await get_tree().create_timer(0.35).timeout
	await _shot("04-death")
	Game.won = true
	Game.day = 30
	Game.ending_title = str(Game.meta.get("win_title", "Дверь осталась при тебе"))
	Game.ending_line = str(Game.meta.get("win_line", ""))
	Game.stats = {"food": 4, "health": 3, "sanity": 2, "ammo": 1}
	_show_end()
	await get_tree().create_timer(0.35).timeout
	await _shot("05-win")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/tmp/door-shots")
	var err := image.save_png("/tmp/door-shots/%s.png" % shot_name)
	print("shot ", shot_name, " ", err, " ", image.get_width(), "x", image.get_height())
