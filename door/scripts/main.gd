extends Control
## Портретный интерфейс: титр, день, раскрытие, карточка конца, правка текстов.

const Palette := preload("res://scripts/door_theme.gd")
const DESK := Palette.DESK
const INK := Palette.INK
const PAPER := Palette.PAPER_ON_INK
const MUTED := Palette.MUTED
const BLOOD := Palette.MARKER
const MOSS := Palette.INK
const AMBER := Palette.MARKER

var display: Font
var body: Font
var column: Control
var page_host: Control
var screens: Dictionary = {}
var current: Control
var day_photo: TextureRect
var day_art: Panel
var reveal_art: Panel
var day_stamp: Label
var reveal_stamp: Label
var day_title: Label
var day_text: RichTextLabel
var day_hint: Label
var choice_a: Button
var choice_b: Button
var reveal_text: RichTextLabel
var reveal_notes: Label
var delta_box: HBoxContainer
var reveal_photo: TextureRect
var end_photo: TextureRect
var end_mark: Label
var end_rule: ColorRect
var next_button: Button
var end_kicker: Label
var end_day: Label
var end_title: Label
var end_line: Label
var end_bits: VBoxContainer
var end_stats: HBoxContainer
var end_seed: Label
var end_again: Button
var end_fresh: Button
var end_same: Button
var continue_button: Button
var chapter_kicker: Label
var chapter_number: Label
var chapter_name: Label
var chapter_line: Label
var chapter_stats: HBoxContainer
var chapter_bits: VBoxContainer
var chapter_next: Button
var mute_buttons: Array[Button] = []
var stat_numbers: Dictionary = {}
var type_label: RichTextLabel
var type_left: int = 0
var wash: ColorRect
var stat_shown: Dictionary = {}
var stat_tweens: Dictionary = {}
var editor: Control
var shot_mode: bool = false


func _ready() -> void:
	shot_mode = OS.get_environment("DOOR_SHOT") != ""
	var unbounded := load("res://fonts/Unbounded.ttf") as Font
	display = unbounded if unbounded != null else _font("res://fonts/Caveat.ttf", 700)
	body = load("res://fonts/Neucha.ttf")
	_build()
	_show_screen(screens.title)
	if shot_mode:
		_run_shots()
	elif OS.is_debug_build():
		if not _maybe_debug_fight():
			_maybe_web_card()


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
	elif current == screens.chapter and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER):
		_on_chapter_next()
	elif current == screens.title and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE):
		_on_start()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = DESK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	column = Control.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	get_viewport().size_changed.connect(_fit_column)
	_fit_column()

	var paper := preload("res://scripts/notebook.gd").new()
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(paper)
	page_host = Control.new()
	page_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(page_host)

	screens.title = _build_title()
	screens.day = _build_day()
	screens.reveal = _build_reveal()
	screens.chapter = _build_chapter()
	screens["end"] = _build_end()
	var battle_view := preload("res://scripts/battle_view.gd").new()
	battle_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_view.setup(display, body)
	battle_view.visible = false
	battle_view.finished.connect(_on_battle_done)
	page_host.add_child(battle_view)
	screens.battle = battle_view
	editor = preload("res://scripts/editor_ui.gd").new()
	editor.set_anchors_preset(Control.PRESET_FULL_RECT)
	editor.visible = false
	editor.setup(func() -> void: _show_screen(screens.title))
	page_host.add_child(editor)
	wash = ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.color = Palette.MARKER
	wash.modulate.a = 0.0
	page_host.add_child(wash)
	screens.editor = editor
	for key in ["title", "day", "reveal", "chapter", "end", "battle"]:
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
	var art := _art_host(220)
	box.add_child(art)
	var title_photo := _photo_in(art)
	_present_photo(title_photo, "res://art/hero.webp", false)
	box.add_child(_label("ОТКРОЕШЬ", 68, INK, display, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("ДВЕРЬ?", 96, BLOOD, display, HORIZONTAL_ALIGNMENT_CENTER))
	var tag := _label(str(Game.meta.get("tagline", "Тридцать дней. Один стук. Два пальца.")), 28, MUTED, body, HORIZONTAL_ALIGNMENT_CENTER)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tag)
	var start := _button("Начать", true, 78)
	start.pressed.connect(_on_start)
	box.add_child(start)
	continue_button = _button("Продолжить", false, 72)
	continue_button.pressed.connect(_on_continue)
	box.add_child(continue_button)
	var edit := _button("Править события", false, 72)
	edit.pressed.connect(_open_editor)
	box.add_child(edit)
	var mute := _button("", false)
	mute.custom_minimum_size = Vector2(0, 64)
	mute.pressed.connect(_on_mute)
	mute_buttons.append(mute)
	box.add_child(mute)
	box.add_child(_volume_row())
	_refresh_mute()
	return screen


func _build_day() -> Control:
	var screen := _screen()
	var box := _column(screen)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	day_title = _label("Глава 1 · Квартира · День 01", 26, INK, display, HORIZONTAL_ALIGNMENT_LEFT)
	day_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	day_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	day_title.clip_text = true
	top.add_child(day_title)
	var mute := _button("Звук", false, 56)
	mute.autowrap_mode = TextServer.AUTOWRAP_OFF
	mute.clip_text = false
	mute.add_theme_font_size_override("font_size", 22)
	mute.custom_minimum_size = Vector2(148, 72)
	mute.pressed.connect(_on_mute)
	mute_buttons.append(mute)
	top.add_child(mute)
	box.add_child(top)
	box.add_child(_stat_row())
	day_hint = _label("", 22, INK, body, HORIZONTAL_ALIGNMENT_LEFT)
	day_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(day_hint)
	var art := _art_host(420)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = 1.35
	day_art = art
	day_photo = _photo_in(art)
	day_stamp = _stamp(art)
	box.add_child(art)
	var text_panel := PanelContainer.new()
	text_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_panel.size_flags_stretch_ratio = 0.85
	text_panel.add_theme_stylebox_override("panel", preload("res://scripts/chalk_style.gd").panel(14))
	day_text = _rich(28)
	day_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	day_text.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_skip_type()
	)
	text_panel.add_child(day_text)
	box.add_child(text_panel)
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
	box.add_child(_label("И ВОТ", 28, BLOOD, display, HORIZONTAL_ALIGNMENT_LEFT))
	var art := _art_host(360)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reveal_art = art
	reveal_photo = _photo_in(art)
	reveal_stamp = _stamp(art)
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
	end_kicker = _label("ОТКРОЕШЬ ДВЕРЬ?", 26, BLOOD, display, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(end_kicker)
	end_day = _label("14", 92, INK, display, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(end_day)
	end_title = _label("", 46, INK, display, HORIZONTAL_ALIGNMENT_CENTER)
	end_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_title)
	end_rule = ColorRect.new()
	end_rule.custom_minimum_size = Vector2(0, 3)
	end_rule.color = BLOOD
	box.add_child(end_rule)
	end_line = _label("", 26, INK, body, HORIZONTAL_ALIGNMENT_CENTER)
	end_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_line)
	var art := _art_host(200)
	end_photo = _photo_in(art)
	end_mark = _label("✗", 140, BLOOD, display, HORIZONTAL_ALIGNMENT_CENTER)
	end_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(end_mark)
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
	end_again = _button("Главу заново", true, 74)
	end_again.pressed.connect(_on_retry_chapter)
	box.add_child(end_again)
	end_fresh = _button("С начала", false, 74)
	end_fresh.pressed.connect(_on_start)
	box.add_child(end_fresh)
	end_same = _button("То же зерно", false, 74)
	end_same.pressed.connect(_on_same_seed)
	box.add_child(end_same)
	var home := _button("На титр", false, 74)
	home.pressed.connect(func() -> void: _show_screen(screens.title))
	box.add_child(home)
	return screen


func _build_chapter() -> Control:
	var screen := _screen()
	var box := _column(screen)
	chapter_kicker = _label("ГЛАВА ПРОЙДЕНА", 28, BLOOD, display, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(chapter_kicker)
	chapter_number = _label("1", 96, BLOOD, display, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(chapter_number)
	chapter_name = _label("Квартира", 48, INK, display, HORIZONTAL_ALIGNMENT_CENTER)
	chapter_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(chapter_name)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = BLOOD
	box.add_child(rule)
	chapter_line = _label("", 26, INK, body, HORIZONTAL_ALIGNMENT_CENTER)
	chapter_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(chapter_line)
	var art := _art_host(240)
	var photo := _photo_in(art)
	photo.name = "ChapterPhoto"
	box.add_child(art)
	chapter_bits = VBoxContainer.new()
	chapter_bits.add_theme_constant_override("separation", 4)
	box.add_child(chapter_bits)
	chapter_stats = HBoxContainer.new()
	chapter_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	chapter_stats.add_theme_constant_override("separation", 14)
	box.add_child(chapter_stats)
	chapter_next = _button("Дальше", true)
	chapter_next.pressed.connect(_on_chapter_next)
	box.add_child(chapter_next)
	return screen


func _screen() -> Control:
	var screen := MarginContainer.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_theme_constant_override("margin_left", 28)
	screen.add_theme_constant_override("margin_right", 28)
	screen.add_theme_constant_override("margin_top", 22)
	screen.add_theme_constant_override("margin_bottom", 18)
	page_host.add_child(screen)
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
	host.add_theme_stylebox_override("panel", preload("res://scripts/chalk_style.gd").panel(12))
	return host


func _stamp(host: Control) -> Label:
	var stamp := _label("изюминка", 26, BLOOD, display, HORIZONTAL_ALIGNMENT_RIGHT)
	stamp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stamp.offset_left = -196
	stamp.offset_top = 14
	stamp.offset_right = -18
	stamp.offset_bottom = 46
	stamp.rotation_degrees = -6
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.visible = false
	host.add_child(stamp)
	return stamp


func _frame_art(host: Panel, highlight: bool) -> void:
	if host == null:
		return
	var style := host.get_theme_stylebox("panel")
	if style == null:
		return
	var copy := style.duplicate() as StyleBoxTexture
	if copy == null:
		return
	copy.modulate_color = Color(1.22, 0.74, 0.68) if highlight else Color.WHITE
	host.add_theme_stylebox_override("panel", copy)


func _photo_in(host: Control) -> TextureRect:
	var rect := TextureRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ink_photo.gdshader")
	mat.set_shader_parameter("ink", Palette.INK)
	mat.set_shader_parameter("marker", Palette.MARKER)
	rect.material = mat
	host.add_child(rect)
	return rect


func _present_photo(rect: TextureRect, path: String, motion: bool) -> void:
	if rect == null:
		return
	var changed := str(rect.get_meta("path", "")) != path
	rect.set_meta("path", path)
	var texture: Texture2D = null
	if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		texture = load(path)
	rect.texture = texture
	if not motion:
		rect.modulate.a = 1.0
		rect.position = Vector2.ZERO
		rect.rotation_degrees = 0.0
		return
	rect.pivot_offset = rect.size * 0.5
	if rect.pivot_offset == Vector2.ZERO:
		rect.pivot_offset = Vector2(180, 160)
	if changed:
		rect.modulate.a = 0.0
		rect.position = Vector2(randf_range(-8, 8), 6)
		rect.rotation_degrees = randf_range(-0.8, 0.8)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(rect, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(rect, "position", Vector2.ZERO, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(rect, "rotation_degrees", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _label(text: String, size: int, color: Color, font: Font, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
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
	label.add_theme_color_override("default_color", INK)
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	return label


func _button(text: String, primary: bool, height: int = 92) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(0, height)
	button.add_theme_font_override("font", display)
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_stylebox_override("normal", _button_style(primary, false))
	button.add_theme_stylebox_override("hover", _button_style(primary, true))
	button.add_theme_stylebox_override("pressed", _button_style(primary, true))
	button.add_theme_stylebox_override("focus", _button_style(primary, true))
	button.add_theme_stylebox_override("disabled", _button_style(false, false))
	button.add_theme_color_override("font_color", PAPER if primary else INK)
	button.add_theme_color_override("font_hover_color", PAPER if primary else BLOOD)
	button.add_theme_color_override("font_pressed_color", PAPER if primary else BLOOD)
	button.add_theme_color_override("font_focus_color", PAPER if primary else INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button


func _button_style(primary: bool, hot: bool) -> StyleBoxTexture:
	var style: StyleBoxTexture = preload("res://scripts/chalk_style.gd").button(14)
	if primary or hot:
		style.modulate_color = Color(1.08, 0.9, 0.86)
	return style


func _stat_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icons := {
		"food": "res://art/ui/stat_food.png",
		"health": "res://art/ui/stat_health.png",
		"sanity": "res://art/ui/stat_sanity.png",
		"ammo": "res://art/ui/stat_ammo.png",
	}
	for id in Game.STAT_ORDER:
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", preload("res://scripts/chalk_style.gd").button(6))
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_path := str(icons.get(id, ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		line.add_child(icon)
		var stack := VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		var number := _label("0", 32, INK, display, HORIZONTAL_ALIGNMENT_LEFT)
		stat_numbers[id] = number
		stack.add_child(number)
		var name := _label(Game.stat_label(id), 16, MUTED, body, HORIZONTAL_ALIGNMENT_LEFT)
		stack.add_child(name)
		line.add_child(stack)
		cell.add_child(line)
		row.add_child(cell)
	return row


func _volume_row() -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_slider_line("Звуки", Sfx.volume, func(value: float) -> void:
		Sfx.set_volume(value)
	))
	row.add_child(_slider_line("Музыка", Sfx.music_volume, func(value: float) -> void:
		Sfx.set_music_volume(value)
	))
	return row


func _slider_line(caption: String, current: float, apply: Callable) -> Control:
	var line := VBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	line.add_child(_label(caption, 20, MUTED, body, HORIZONTAL_ALIGNMENT_CENTER))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = current * 100.0
	slider.custom_minimum_size = Vector2(0, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gate := {"on": false}
	slider.value_changed.connect(func(value: float) -> void:
		if not gate.on:
			return
		Sfx.note_input()
		apply.call(value / 100.0)
	)
	slider.tree_entered.connect(func() -> void:
		slider.set_value_no_signal(current * 100.0)
		gate.on = true
	)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		Sfx.note_input()
		Sfx.play("ui/tap", -6.0)
	)
	line.add_child(slider)
	return line


func _tint_stat(number: Label, id: String, value: int) -> void:
	var low := value <= 8 if id == "health" else value <= 1
	number.add_theme_color_override("font_color", BLOOD if low else INK)


func _refresh_stats(animate: bool = false) -> void:
	for id in Game.STAT_ORDER:
		var value := int(Game.stats.get(id, 0))
		var number: Label = stat_numbers[id]
		var previous := int(stat_shown.get(id, value))
		stat_shown[id] = value
		if stat_tweens.has(id) and stat_tweens[id] != null:
			(stat_tweens[id] as Tween).kill()
		if not animate or previous == value:
			number.text = str(value)
			_tint_stat(number, id, value)
			continue
		var tween := create_tween()
		stat_tweens[id] = tween
		var stat_id := id
		tween.tween_method(func(shown: float) -> void:
			var current := int(round(shown))
			number.text = str(current)
			_tint_stat(number, stat_id, current)
		, float(previous), float(value), 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		number.pivot_offset = number.size * 0.5
		var settle := create_tween()
		settle.tween_property(number, "scale", Vector2(1.06, 1.06), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		settle.tween_property(number, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _soft_reaction(bad: bool, leaf: TextureRect = null) -> void:
	if leaf == null:
		leaf = reveal_photo if reveal_photo != null else day_photo
	if leaf != null:
		leaf.pivot_offset = leaf.size * 0.5 if leaf.size != Vector2.ZERO else Vector2(180, 140)
		var tilt := 0.7 if bad else 0.3
		var sway := create_tween()
		sway.tween_property(leaf, "rotation_degrees", tilt, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(leaf, "rotation_degrees", -tilt * 0.45, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(leaf, "rotation_degrees", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not bad or wash == null:
		return
	wash.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(wash, "modulate:a", 0.08, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(wash, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _pop(node: Control) -> void:
	node.modulate.a = 0.0
	node.pivot_offset = node.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2(1.04, 1.04), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
	if screen == screens.title:
		_refresh_title()


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
	Sfx.note_input()
	Sfx.toggle_mute()
	_refresh_mute()
	Sfx.play("ui/tap", -6.0)


func _refresh_mute() -> void:
	var caption := "Тихо" if Sfx.muted else "Звук"
	for button in mute_buttons:
		button.text = caption


func _on_start() -> void:
	Sfx.note_input()
	Sfx.play("ui/tap", -6.0)
	Game.start_run()
	_show_day()


func _on_continue() -> void:
	Sfx.note_input()
	Sfx.play("ui/tap", -6.0)
	if not Game.load_checkpoint():
		Game.start_run()
	_show_day()


func _on_retry_chapter() -> void:
	Sfx.note_input()
	Sfx.play("ui/tap", -6.0)
	if not Game.load_checkpoint():
		Game.start_run()
	_show_day()


func _refresh_title() -> void:
	Sfx.set_duck(false)
	if continue_button == null:
		return
	var saved: Dictionary = Game.peek_checkpoint()
	continue_button.visible = not saved.is_empty()
	if saved.is_empty():
		return
	var number := int(saved.get("chapter", 1))
	continue_button.text = "Продолжить · %s" % Game.chapter_title(number)


func _on_same_seed() -> void:
	Sfx.note_input()
	Sfx.play("ui/tap", -6.0)
	Game.start_run(Game.seed_value)
	_show_day()


func _open_editor() -> void:
	Sfx.note_input()
	Sfx.play("ui/tap", -6.0)
	editor.reload()
	_show_screen(screens.editor)


func _show_day() -> void:
	Sfx.set_duck(false)
	day_title.text = Game.header_text()
	day_hint.text = Game.night_hint()
	_refresh_stats(false)
	_refresh_mute()
	var highlight := Game.is_highlight()
	_frame_art(day_art, highlight)
	if day_stamp:
		day_stamp.visible = highlight
	_present_photo(day_photo, Game.illustration_path(), true)
	_type_into(day_text, Game.setup_text())
	_apply_choice_button(choice_a, "a")
	_apply_choice_button(choice_b, "b")
	Sfx.play("ui/page", -10.0)
	Sfx.play(Game.sound_key(), -4.0)
	if highlight:
		Sfx.play("ui/stamp", -8.0)
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
	Sfx.note_input()
	Sfx.play("ui/pen", -4.0)
	var reveal: Dictionary = Game.choose(which)
	if OS.is_debug_build() and OS.has_feature("web"):
		JavaScriptBridge.eval("window.DOOR_EVENT=%s;" % var_to_str("%s battle=%s" % [str(reveal.get("event_id", "")), str(reveal.get("battle", false))]), true)
	if bool(reveal.get("battle", false)):
		screens.battle.call("refresh")
		_show_screen(screens.battle)
		return
	_show_reveal(reveal)


func _on_battle_done(won: bool) -> void:
	var reveal: Dictionary = Game.finish_battle(won)
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
	_refresh_stats(true)
	_present_photo(reveal_photo, str(reveal.get("image", Game.illustration_path())), true)
	var highlight := bool(reveal.get("highlight", false))
	_frame_art(reveal_art, highlight)
	if reveal_stamp:
		reveal_stamp.visible = highlight
	var bad := bool(reveal.get("bad", false)) or bool(reveal.get("dead", false))
	_soft_reaction(bad)
	if bool(reveal.get("dead", false)):
		next_button.text = "Это конец"
		Sfx.play("ui/bad", -2.0)
	elif bool(reveal.get("won", false)):
		next_button.text = "Итог"
		Sfx.play("ui/good", -2.0)
	elif bool(reveal.get("chapter_break", false)):
		next_button.text = "Глава пройдена"
		Sfx.play("ui/good", -2.0)
	elif bad:
		next_button.text = "Дальше"
		Sfx.play("ui/bad", -2.0)
	else:
		next_button.text = "Дальше"
		Sfx.play("ui/good", -2.0)
	_show_screen(screens.reveal)


func _on_next() -> void:
	if current != screens.reveal:
		return
	Sfx.note_input()
	Sfx.play("ui/tap", -8.0)
	if Game.run_over:
		_show_end()
	elif Game.chapter_break:
		_show_chapter()
	else:
		_show_day()


func _show_chapter() -> void:
	Sfx.set_duck(false)
	var report: Dictionary = Game.chapter_report
	var number := int(report.get("number", Game.chapter))
	chapter_kicker.text = "ГЛАВА ПРОЙДЕНА"
	chapter_number.text = "%02d" % number
	chapter_name.text = str(report.get("name", Game.chapter_title(number)))
	chapter_line.text = str(report.get("line", ""))
	chapter_next.text = str(report.get("next", "Дальше"))
	for child in chapter_bits.get_children():
		child.queue_free()
	for bit in Game.epitaphs(3):
		chapter_bits.add_child(_label(bit, 24, INK, body, HORIZONTAL_ALIGNMENT_CENTER))
	for child in chapter_stats.get_children():
		child.queue_free()
	for id in Game.STAT_ORDER:
		var value := int(Game.stats.get(id, 0))
		chapter_stats.add_child(_label("%s %d" % [Game.stat_label(id), value], 28, BLOOD if (id == "health" and value <= 8) or (id != "health" and value <= 1) else INK, display, HORIZONTAL_ALIGNMENT_CENTER))
	var photo := screens.chapter.find_child("ChapterPhoto", true, false) as TextureRect
	_present_photo(photo, str(Game.last_reveal.get("image", "res://art/hero.webp")), true)
	Sfx.play("ui/good", -4.0)
	_show_screen(screens.chapter)


func _on_chapter_next() -> void:
	if current != screens.chapter:
		return
	Sfx.note_input()
	Sfx.play("ui/tap", -8.0)
	Game.advance_chapter()
	_show_day()


func _show_end() -> void:
	Sfx.set_duck(true)
	var won := Game.won
	end_kicker.text = "СЕРИЯ ЗАКРЫТА" if won else "СЕРИЯ ОБОРВАЛАСЬ"
	end_kicker.add_theme_color_override("font_color", INK if won else BLOOD)
	end_day.text = "%02d" % Game.day
	end_day.add_theme_color_override("font_color", INK if won else BLOOD)
	end_title.text = Game.ending_title
	end_title.add_theme_color_override("font_color", INK if won else BLOOD)
	end_line.text = Game.ending_line
	if end_rule:
		end_rule.color = INK if won else BLOOD
	for child in end_bits.get_children():
		child.queue_free()
	for bit in Game.epitaphs(4):
		end_bits.add_child(_label(bit, 24, INK, body, HORIZONTAL_ALIGNMENT_CENTER))
	for child in end_stats.get_children():
		child.queue_free()
	for id in Game.STAT_ORDER:
		var value := int(Game.stats.get(id, 0))
		end_stats.add_child(_label("%s %d" % [Game.stat_label(id), value], 28, BLOOD if (id == "health" and value <= 8) or (id != "health" and value <= 1) else INK, display, HORIZONTAL_ALIGNMENT_CENTER))
	end_seed.text = "зерно %d  ·  глава %d  ·  день %d  ·  всего %d" % [Game.seed_value, Game.chapter, Game.day, Game.total_day()]
	if end_again:
		end_again.text = "Ещё раз" if won else "Главу заново"
	if end_fresh:
		end_fresh.visible = not won
	var photo := "res://art/hero.webp" if won else str(Game.last_reveal.get("image", "res://art/hero.webp"))
	_present_photo(end_photo, photo, true)
	if end_mark:
		end_mark.text = "V" if won else "X"
		end_mark.add_theme_color_override("font_color", BLOOD if not won else INK)
		end_mark.modulate.a = 0.0
		var ink := create_tween()
		ink.tween_property(end_mark, "modulate:a", 0.55, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_soft_reaction(not won, end_photo)
	if won:
		Sfx.play("ui/win", -2.0)
	else:
		Sfx.play("ui/death", -2.0)
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
	Game.start_run(11)
	Game.chapter = 2
	Game.day = 7
	if Game.by_id.has("rope_seen"):
		Game.pending = Game.by_id["rope_seen"]
	_show_day()
	_skip_type()
	await get_tree().create_timer(0.25).timeout
	await _shot("06-chapter2")
	Game.start_run(4)
	Game.day = 8
	if Game.by_id.has("basement"):
		Game.pending = Game.by_id["basement"]
	elif Game.by_id.has("window"):
		Game.pending = Game.by_id["window"]
	_show_day()
	_on_choice("a")
	await get_tree().create_timer(0.35).timeout
	await _shot("07-battle")
	Game.chapter = 2
	Game.battle = preload("res://scripts/battle.gd").new()
	Game.battle.start(Game, {"enemy": "pigeon", "subtype": "a"})
	screens.battle.call("refresh")
	_show_screen(screens.battle)
	await get_tree().create_timer(0.35).timeout
	await _shot("09-pigeon")
	if Game.by_id.has("pigeon_ultimatum"):
		Game.pending = Game.by_id["pigeon_ultimatum"]
	_show_day()
	_skip_type()
	await get_tree().create_timer(0.25).timeout
	await _shot("07-highlight")
	Game.chapter = 1
	Game.day = 30
	Game.chapter_break = true
	Game._mark_chapter_break()
	Game.last_reveal = {"image": "res://art/scenes/door.webp"}
	Game.stats = {"food": 4, "health": 3, "sanity": 4, "ammo": 2}
	_show_chapter()
	await get_tree().create_timer(0.35).timeout
	await _shot("08-chapter")
	get_tree().quit()


func _maybe_debug_fight() -> bool:
	if not OS.has_feature("web"):
		return false
	var href := str(JavaScriptBridge.eval("String(window.location.href)", true))
	JavaScriptBridge.eval("window.DOOR_HREF = %s;" % var_to_str(href), true)
	if "fight=1" not in href:
		return false
	JavaScriptBridge.eval("window.DOOR_STEP='choice';", true)
	Game.best_weapon = "baguette"
	Game.flat_medal = false
	Game._save_meta()
	Game.start_run(4)
	Game.day = 8
	if Game.by_id.has("window"):
		Game.pending = Game.by_id["window"]
	current = screens.day
	_on_choice("a")
	JavaScriptBridge.eval("window.DOOR_STEP='after';", true)
	return true


func _maybe_web_card() -> void:
	if not OS.has_feature("web"):
		return
	var query := str(JavaScriptBridge.eval("window.location.search", true))
	var won := "card=win" in query
	if "card=death" not in query and not won:
		return
	await get_tree().process_frame
	Game.start_run(7)
	Game.run_over = true
	Game.won = won
	Game.day = 30 if won else 14
	if won:
		Game.ending_title = str(Game.meta.get("win_title", "Дверь осталась при тебе"))
		Game.ending_line = str(Game.meta.get("win_line", ""))
	else:
		Game.ending_title = "Тебя съели на пороге"
		Game.ending_line = "Он сказал, что он из ЖЭКа. ЖЭК теперь с зубами."
	Game.stats = {"food": 0, "health": 0, "sanity": 2, "ammo": 1} if not won else {"food": 4, "health": 3, "sanity": 2, "ammo": 1}
	Game.last_reveal = {"image": "res://art/scenes/door.webp"}
	_show_end()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/tmp/door-shots")
	var err := image.save_png("/tmp/door-shots/%s.png" % shot_name)
	print("shot ", shot_name, " ", err, " ", image.get_width(), "x", image.get_height())
