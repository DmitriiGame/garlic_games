extends Control
## Портретный цикл: прицел по полоске, бросок, ловля, загон, лавка.

var tab := 0
var phase := "aim"
var holding := false
var title_open := true
var offline_open := false
var editor_open := false
var flight_t := 0.0
var breathe_t := 0.0
var toast_left := 0.0
var shown_power := 0.0
var last_distance := 0.0
var last_biome_name := ""
var spawned_this_round := 0
var caught_this_round := 0
var save_wait := 0.0
var meter_biome := ""
var toast_lines: Array = []

var money_label: Label
var best_label: Label
var goal_label: Label
var aim_label: Label
var hint_label: Label
var last_label: Label
var toast_label: Label
var round_banner: Label
var live_rate_label: Label
var throw_button: Button
var mute_button: Button
var meter: ProgressBar
var field
var list_page: ScrollContainer
var list_box: VBoxContainer
var title_layer: Control
var offline_layer: Control
var editor_layer: Control
var editor: CatalogEditor
var offline_text: Label
var nav_buttons: Array = []

const TAB_TITLES: Array[String] = ["Бросок", "Бестиарий", "Загон", "Лавка"]
const PORTRAIT := preload("res://scripts/portrait.gd")


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = ThrowFonts.BODY
	self.theme = theme
	var backdrop := ColorRect.new()
	backdrop.color = ThrowTheme.BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_build_header(column)
	_build_body(column)
	_build_throw_bar(column)
	_build_nav(column)
	_build_title()
	_build_offline()
	_build_editor()
	_show_tab(0)
	_refresh_header()
	Game.save_progress()


func _process(delta: float) -> void:
	Game.accrue(delta)
	save_wait += delta
	if save_wait >= 5.0:
		save_wait = 0.0
		Game.save_progress()
	_animate(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Game.save_progress()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed and holding:
			holding = false
			_release_throw()
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER:
		if key.pressed:
			_on_throw_down()
		elif holding:
			holding = false
			_release_throw()
		get_viewport().set_input_as_handled()
		return
	if not key.pressed:
		return
	match key.keycode:
		KEY_M:
			_toggle_mute()
		KEY_1:
			_show_tab(0)
		KEY_2:
			_show_tab(1)
		KEY_3:
			_show_tab(2)
		KEY_4:
			_show_tab(3)
		KEY_E:
			_open_editor()


func debug_force_round(power: float) -> Dictionary:
	title_open = false
	if title_layer:
		title_layer.visible = false
	offline_open = false
	editor_open = false
	phase = "aim"
	_show_tab(0)
	var result := _begin_throw(power)
	phase = "catch"
	field.skip_to_wait()
	return result


func debug_catch_all() -> int:
	var caught_now := 0
	var index := 0
	while index < field.guests.size():
		if field.can_catch(index):
			_on_guest_tapped(index)
			caught_now += 1
		index += 1
	return caught_now


func debug_phase() -> String:
	return phase


func debug_press_buy(kind: String, id: String) -> bool:
	_show_tab(3)
	return _on_buy("%s:%s" % [kind, id])


func _animate(delta: float) -> void:
	var watching := tab == 0 and not title_open and not editor_open and not offline_open
	if phase == "aim":
		shown_power = _meter_power()
		if watching:
			field.set_mode("aim")
			field.set_view(Game.preview_view())
			field.aim_distance = Game.distance_for_power(shown_power)
			field.queue_redraw()
			_show_preview()
	elif phase == "flight" and watching:
		flight_t += delta
		field.set_flight_k(minf(1.0, flight_t / 0.72))
		if flight_t >= 0.72:
			phase = "catch"
			field.begin_chase()
	elif phase == "catch" and watching:
		field.advance(delta)
		if field.all_settled():
			_finish_round()
	elif phase == "breathe":
		breathe_t -= delta
		if breathe_t <= 0.0:
			phase = "aim"
			field.set_mode("aim")
	if toast_left > 0.0:
		toast_left = maxf(0.0, toast_left - delta)
		if toast_left == 0.0:
			toast_lines.clear()
			toast_label.text = ""
	if is_instance_valid(live_rate_label):
		live_rate_label.text = Game.format_rate(Game.income_per_sec())
	_sync_throw_button()
	if money_label:
		money_label.text = Game.format_money(Game.currency)


func _meter_power() -> float:
	var hz := float(Content.balance.get("meter_hz", 0.45))
	var cycle := fposmod(Time.get_ticks_msec() / 1000.0 * hz, 1.0)
	return 1.0 - absf(cycle * 2.0 - 1.0)


func _show_preview() -> void:
	var distance := Game.distance_for_power(shown_power)
	var biome := Game.biome_at(distance)
	var biome_id := str(biome.get("id", ""))
	var extra := ""
	if biome_id != "" and not Game.unlocked.has(biome_id):
		extra = " · откроется"
	aim_label.text = "%d м · %s%s" % [int(round(distance)), biome.get("name", "—"), extra]
	meter.value = shown_power
	if biome_id != meter_biome:
		meter_biome = biome_id
		var fill := _flat(ThrowTheme.color_or(str(biome.get("ground", "")), ThrowTheme.METER), 8)
		meter.add_theme_stylebox_override("fill", fill)


func _begin_throw(power: float) -> Dictionary:
	var result: Dictionary = Game.commit_throw(clampf(power, 0.0, 1.0))
	shown_power = float(result.power)
	last_distance = float(result.distance)
	last_biome_name = str(result.biome.get("name", ""))
	spawned_this_round = result.spawns.size()
	caught_this_round = 0
	phase = "flight"
	flight_t = 0.0
	field.start_round(last_distance, Game.preview_view(), _guest_specs(result.spawns))
	aim_label.text = "летит на %d м" % int(round(last_distance))
	meter.value = shown_power
	Sfx.play("throw")
	for biome_id in result.unlocked:
		var biome: Dictionary = Content.biome_by_id.get(str(biome_id), {})
		_toast("Открыт край: %s. %s" % [biome.get("name", biome_id), biome.get("blurb", "")])
		Sfx.play("unlock")
		field.flash = 0.8
	_refresh_header()
	return result


func _release_throw() -> void:
	if title_open or offline_open or editor_open:
		return
	if tab != 0 or phase != "aim":
		return
	_begin_throw(_meter_power())


func _on_throw_down() -> void:
	if title_open or offline_open or editor_open or tab != 0 or phase != "aim":
		return
	holding = true
	_sync_throw_button()


func _on_throw_up() -> void:
	if not holding:
		return
	holding = false
	_release_throw()


func _finish_round() -> void:
	phase = "breathe"
	breathe_t = 0.4
	if caught_this_round < spawned_this_round and spawned_this_round > 0:
		Sfx.play("miss")
	last_label.text = "Прошлый: %d м · %s · %d из %d" % [
		int(round(last_distance)), last_biome_name, caught_this_round, spawned_this_round,
	]
	Game.save_progress()
	_refresh_header()


func _on_guest_tapped(index: int) -> void:
	if not field.can_catch(index):
		return
	var info: Dictionary = Game.register_catch(field.guest_id(index))
	field.mark_caught(index)
	caught_this_round += 1
	Sfx.play("catch")
	if not OS.has_feature("headless"):
		Input.vibrate_handheld(16)
	var line := str(info.get("name", ""))
	if bool(info.get("first", false)):
		line = "%s в бестиарии. %s" % [info.get("name", ""), info.get("line", "")]
	else:
		line = "%s ×%s" % [info.get("name", ""), info.get("count", 1)]
	if int(info.get("bonus", 0)) > 0:
		line += "  +%d" % int(info.bonus)
	_toast(line)
	Game.save_progress()
	_refresh_header()


func _guest_specs(ids: Array) -> Array:
	var specs: Array = []
	var index := 0
	for id in ids:
		var creature: Dictionary = Content.creature_by_id.get(str(id), {})
		specs.append({
			"id": str(id),
			"shape": str(creature.get("shape", "blob")),
			"color": str(creature.get("color", "#888888")),
			"window": Game.window_for(str(id)),
			"delay": 0.1 * index,
		})
		index += 1
	return specs


func _bind_tab(button: Button, index: int) -> void:
	button.pressed.connect(_show_tab.bind(index))


func _show_tab(index: int) -> void:
	tab = clampi(index, 0, 3)
	field.visible = tab == 0
	list_page.visible = tab != 0
	if tab != 0:
		_fill_tab()
	for i in nav_buttons.size():
		var button: Button = nav_buttons[i]
		var active := i == tab
		button.add_theme_stylebox_override("normal", _flat(ThrowTheme.ACCENT_DEEP if active else ThrowTheme.BG_RAISED, 14))
		button.add_theme_color_override("font_color", ThrowTheme.PAPER if active else ThrowTheme.INK)
	round_banner.visible = tab != 0 and phase != "aim"


func _fill_tab() -> void:
	live_rate_label = null
	_clear(list_box)
	match tab:
		1:
			_fill_collection()
		2:
			_fill_pen()
		3:
			_fill_shop()


func _fill_collection() -> void:
	var title := _label("Бестиарий %d/%d" % [Game.unique_caught(), Content.creatures.size()], 32, ThrowTheme.INK, true)
	list_box.add_child(title)
	var note := "Силуэт без имени — ещё не пойман. Закрытый край откроется дальним броском."
	if Game.collection_complete():
		note = "Чердак пуст. Все, кого звали тапки, уже при деле."
	list_box.add_child(_label(note, 18, ThrowTheme.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	list_box.add_child(grid)
	for creature in Content.creatures:
		grid.add_child(_creature_card(creature))


func _creature_card(creature: Dictionary) -> PanelContainer:
	var id := str(creature.get("id", ""))
	var count := int(Game.caught.get(id, 0))
	var caught := count > 0
	var biome: Dictionary = Content.biome_by_id.get(str(creature.get("biome", "")), {})
	var open := Game.unlocked.has(str(biome.get("id", "")))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _flat(ThrowTheme.BG_RAISED, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var portrait = PORTRAIT.new()
	var tint := ThrowTheme.color_or(str(creature.get("color", "")), ThrowTheme.ACCENT)
	portrait.setup(str(creature.get("shape", "blob")), tint, caught)
	box.add_child(portrait)
	var name := "край закрыт" if not open else ("???" if not caught else str(creature.get("name", id)))
	box.add_child(_label(name, 20, ThrowTheme.INK if caught else ThrowTheme.MUTED, true))
	var rarity := Content.rarity_label(str(creature.get("rarity", "")))
	var meta := "%s · %s" % [biome.get("name", ""), rarity]
	if caught:
		meta += " · ×%d" % count
	box.add_child(_label(meta, 16, ThrowTheme.MUTED))
	if caught:
		box.add_child(_label(str(creature.get("line", "")), 16, ThrowTheme.PAPER))
	return card


func _fill_pen() -> void:
	list_box.add_child(_label("Загон", 32, ThrowTheme.INK, true))
	live_rate_label = _label(Game.format_rate(Game.income_per_sec()), 28, ThrowTheme.GOOD, true)
	list_box.add_child(live_rate_label)
	var cap := int(Content.balance.get("offline_cap_sec", 28800))
	list_box.add_child(_label(
		"Пока игра закрыта, загон копит по этой скорости, но не дольше %s. Место достаётся самым доходным. Сейчас %d из %d." % [
			Game.format_duration(cap), Game.pen_members().size(), Game.pen_capacity(),
		],
		18, ThrowTheme.MUTED))
	var members: Array = Game.pen_members()
	if members.is_empty():
		list_box.add_child(_label("Пока пусто. Поймай кого-нибудь — и он начнёт таскать гроши.", 20, ThrowTheme.INK))
		return
	for member in members:
		var creature: Dictionary = Content.creature_by_id.get(str(member.id), {})
		list_box.add_child(_shop_row(
			str(creature.get("name", member.id)),
			"%s · ×%d · %s" % [Content.rarity_label(str(creature.get("rarity", ""))), int(member.count), Game.format_rate(float(member.rate))],
			"",
			false,
		))
	var idle := 0
	for creature in Content.creatures:
		var id := str(creature.get("id", ""))
		if int(Game.caught.get(id, 0)) <= 0:
			continue
		var working := false
		for member in members:
			if str(member.id) == id:
				working = true
		if not working:
			idle += 1
	if idle > 0:
		list_box.add_child(_label("Ещё %d в бестиарии: в загон не влезли." % idle, 18, ThrowTheme.MUTED))
	var free_slots := Game.pen_capacity() - members.size()
	if free_slots > 0:
		list_box.add_child(_label("Свободных мест: %d." % free_slots, 18, ThrowTheme.MUTED))


func _fill_shop() -> void:
	list_box.add_child(_label("Лавка", 32, ThrowTheme.INK, true))
	list_box.add_child(_label("Гроши капают из загона, даже когда чердак закрыт. Покупки без рекламы.", 18, ThrowTheme.MUTED))
	list_box.add_child(_label("Снаряды", 24, ThrowTheme.INK, true))
	for item in Content.items:
		var id := str(item.get("id", ""))
		var owned := Game.owned.has(id)
		var worn := Game.equipped == id
		var reach := int(round(Game.distance_if(0, id)))
		var blurb := "%s На полной силе %d м, приманка +%d." % [item.get("blurb", ""), reach, int(item.get("lure", 0))]
		var button_text := "Надет"
		var token := ""
		if not owned:
			button_text = "Купить за %s" % Game.format_money(float(item.get("price", 0)))
			token = "item:%s" % id
		elif not worn:
			button_text = "Надеть"
			token = "equip:%s" % id
		list_box.add_child(_shop_row(str(item.get("name", id)), blurb, button_text, token != "", token))
	list_box.add_child(_label("Улучшения", 24, ThrowTheme.INK, true))
	for upgrade in Content.upgrades:
		var id := str(upgrade.get("id", ""))
		var level := Game.upgrade_level(id)
		var max_level := int(upgrade.get("max_level", 0))
		var cost := Game.upgrade_cost(id)
		var blurb := "%s %s Сейчас %d/%d." % [upgrade.get("blurb", ""), _upgrade_effect(id), level, max_level]
		var button_text := "Дальше некуда"
		var token := ""
		if cost >= 0:
			button_text = "Купить за %s" % Game.format_money(float(cost))
			token = "upgrade:%s" % id
		list_box.add_child(_shop_row(str(upgrade.get("name", id)), blurb, button_text, token != "", token))
	var edit := _text_button("Править числа", false)
	edit.pressed.connect(_open_editor)
	list_box.add_child(edit)


func _shop_row(title: String, blurb: String, button_text: String, enabled: bool, token: String = "") -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _flat(ThrowTheme.BG_RAISED, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	box.add_child(_label(title, 22, ThrowTheme.INK, true))
	box.add_child(_label(blurb, 16, ThrowTheme.MUTED))
	if button_text != "":
		var button := _text_button(button_text, enabled)
		button.disabled = not enabled
		if token != "":
			button.pressed.connect(_on_buy.bind(token))
		box.add_child(button)
	return card


func _upgrade_effect(id: String) -> String:
	match id:
		"throw_power":
			var now := Game.max_distance()
			var nxt := Game.distance_if(1, Game.equipped)
			return "Полная сила %d м, следующий уровень %d м." % [int(round(now)), int(round(nxt))]
		"pen_slots":
			return "Мест станет %d." % (Game.pen_capacity() + 1)
		"pen_income":
			var percent := int(round(float(Content.balance.get("income_step", 0)) * 100.0))
			return "Доход загона +%d%% за уровень." % percent
		"lure":
			var now := Game.spawn_count()
			var cap := int(Content.balance.get("max_spawns", now))
			return "Гостей за бросок %d, дальше до %d." % [now, mini(now + int(Content.balance.get("lure_per_level", 1)), cap)]
		_:
			return "У этого id нет эффекта в коде."


func _on_buy(token: String) -> bool:
	var before := Game.currency
	var ok := Game.try_buy(token)
	if not ok:
		if token.begins_with("equip:"):
			_toast("Этот снаряд ещё не твой.")
		else:
			_toast("Пока не хватает грошей.")
		Sfx.play("miss")
		return false
	if Game.currency < before:
		Sfx.play("coin")
	else:
		Sfx.play("tap")
	Game.save_progress()
	_refresh_header()
	if tab == 3:
		_fill_tab()
	return true


func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(_label("ЧЕРДАК", 14, ThrowTheme.MUTED))
	money_label = _label("0", 30, ThrowTheme.PAPER, true)
	left.add_child(money_label)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	best_label = _label("", 18, ThrowTheme.INK)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal_label = _label("", 16, ThrowTheme.MUTED)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(best_label)
	right.add_child(goal_label)
	mute_button = _text_button("звук", false)
	mute_button.custom_minimum_size = Vector2(96, 56)
	mute_button.add_theme_font_size_override("font_size", 18)
	mute_button.pressed.connect(_toggle_mute)
	row.add_child(mute_button)


func _build_body(parent: VBoxContainer) -> void:
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(0, 420)
	parent.add_child(body)
	field = preload("res://scripts/field.gd").new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.tapped.connect(_on_guest_tapped)
	body.add_child(field)
	list_page = ScrollContainer.new()
	list_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_page.visible = false
	body.add_child(list_page)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	list_page.add_child(list_box)


func _build_throw_bar(parent: VBoxContainer) -> void:
	toast_label = _label("", 18, ThrowTheme.GOOD)
	parent.add_child(toast_label)
	meter = ProgressBar.new()
	meter.min_value = 0
	meter.max_value = 1
	meter.step = 0.001
	meter.show_percentage = false
	meter.custom_minimum_size = Vector2(0, 22)
	meter.add_theme_stylebox_override("background", _flat(ThrowTheme.TRACK, 8))
	meter.add_theme_stylebox_override("fill", _flat(ThrowTheme.METER, 8))
	parent.add_child(meter)
	aim_label = _label("смотри на метры", 22, ThrowTheme.INK, true)
	parent.add_child(aim_label)
	hint_label = _label("Зажми «Бросить» и отпусти, когда на полоске нужный край. Потом тыкай тех, кто подбежал.", 16, ThrowTheme.MUTED)
	parent.add_child(hint_label)
	last_label = _label("", 16, ThrowTheme.MUTED)
	parent.add_child(last_label)
	throw_button = _text_button("БРОСИТЬ", true)
	throw_button.custom_minimum_size = Vector2(0, 84)
	throw_button.add_theme_font_size_override("font_size", 32)
	throw_button.button_down.connect(_on_throw_down)
	throw_button.button_up.connect(_on_throw_up)
	parent.add_child(throw_button)
	round_banner = _label("Раунд на паузе, пока ты не на броске.", 16, ThrowTheme.ACCENT)
	round_banner.visible = false
	parent.add_child(round_banner)


func _build_nav(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	for index in TAB_TITLES.size():
		var button := Button.new()
		button.text = TAB_TITLES[index]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 58)
		button.add_theme_font_override("font", ThrowFonts.BODY)
		button.add_theme_font_size_override("font_size", 16)
		_bind_tab(button, index)
		row.add_child(button)
		nav_buttons.append(button)


func _build_title() -> void:
	title_layer = _overlay(ThrowTheme.BG)
	title_layer.visible = true
	var box := _overlay_box(title_layer)
	box.add_child(_label("ЧЕРДАК", 16, ThrowTheme.MUTED))
	box.add_child(_label("Бросай и лови", 48, ThrowTheme.PAPER, true))
	box.add_child(_label("Бабушкины тапки улетают с чердака. Нечисть прибегает посмотреть. Успей поймать, пока не утащили.", 20, ThrowTheme.INK))
	var start := _text_button("Дальше ловить" if Game.throw_count > 0 else "К чердаку", true)
	start.pressed.connect(_leave_title)
	box.add_child(start)
	var edit := _text_button("Править данные", false)
	edit.pressed.connect(_open_editor)
	box.add_child(edit)
	box.add_child(_label("Прогресс лежит на этом устройстве. Никакой награды за ролик.", 16, ThrowTheme.MUTED))


func _build_offline() -> void:
	offline_layer = _overlay(Color(ThrowTheme.BG.r, ThrowTheme.BG.g, ThrowTheme.BG.b, 0.94))
	var box := _overlay_box(offline_layer)
	box.add_child(_label("Пока тебя не было", 36, ThrowTheme.PAPER, true))
	offline_text = _label("", 22, ThrowTheme.INK)
	box.add_child(offline_text)
	var ok := _text_button("Хорошо", true)
	ok.pressed.connect(func() -> void:
		offline_open = false
		offline_layer.visible = false
		Sfx.unlock()
		Sfx.play("coin")
		Game.save_progress()
	)
	box.add_child(ok)


func _build_editor() -> void:
	editor_layer = _overlay(ThrowTheme.BG)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_top = 12
	box.offset_right = -12
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 8)
	editor_layer.add_child(box)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	box.add_child(bar)
	var back := _text_button("Назад", false)
	back.pressed.connect(_close_editor)
	bar.add_child(back)
	var reset_data := _text_button("Сбросить правки", false)
	reset_data.pressed.connect(_reset_data)
	bar.add_child(reset_data)
	var reset_run := _text_button("Сбросить прогресс", false)
	reset_run.pressed.connect(_reset_progress)
	bar.add_child(reset_run)
	editor = CatalogEditor.new()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.save_pressed.connect(_save_editor)
	editor.reload_pressed.connect(_reload_editor)
	box.add_child(editor)


func _leave_title() -> void:
	Sfx.unlock()
	Sfx.play("tap")
	title_open = false
	title_layer.visible = false
	if float(Game.offline_report.get("gained", 0.0)) >= 0.5:
		offline_text.text = Game.offline_line() + "\n\nГроши уже в кубышке."
		offline_open = true
		offline_layer.visible = true
		offline_layer.move_to_front()
	else:
		Game.save_progress()
	if Game.tutorial_throws >= 8:
		hint_label.text = ""


func _open_editor() -> void:
	Sfx.unlock()
	Sfx.play("tap")
	editor.set_bundle(Content.bundle())
	editor.set_status(Content.source_label())
	editor_open = true
	editor_layer.visible = true
	editor_layer.move_to_front()


func _close_editor() -> void:
	editor_open = false
	editor_layer.visible = false
	_refresh_header()
	if tab != 0:
		_fill_tab()


func _save_editor() -> void:
	var message := Content.save_all(editor.edited_bundle())
	Game.repair_state()
	if not Content.problems.is_empty():
		message += " " + "; ".join(Content.problems)
	editor.set_status(message)
	_toast(message)
	_refresh_header()


func _reload_editor() -> void:
	Content.load_all()
	Game.repair_state()
	editor.set_bundle(Content.bundle())
	var message := "Перечитано. " + Content.source_label()
	if not Content.problems.is_empty():
		message += " " + "; ".join(Content.problems)
	editor.set_status(message)


func _reset_data() -> void:
	Content.clear_overrides()
	Game.repair_state()
	editor.set_bundle(Content.bundle())
	editor.set_status("Правки user:// стёрты. " + Content.source_label())


func _reset_progress() -> void:
	Game.wipe_progress()
	editor.set_status("Прогресс стёрт.")
	_toast("Чердак снова пуст.")
	_refresh_header()


func _toggle_mute() -> void:
	Sfx.unlock()
	Sfx.toggle_mute()
	_refresh_header()


func _refresh_header() -> void:
	if money_label == null:
		return
	money_label.text = Game.format_money(Game.currency)
	if Game.throw_count <= 0:
		best_label.text = "броска ещё не было"
	else:
		best_label.text = "рекорд %d м" % int(round(Game.best_distance))
	goal_label.text = Game.goal_text()
	mute_button.text = "тихо" if Sfx.muted else "звук"
	if Game.tutorial_throws >= 8 and hint_label.text.begins_with("Зажми"):
		hint_label.text = ""
	round_banner.visible = tab != 0 and phase != "aim"


func _sync_throw_button() -> void:
	if throw_button == null:
		return
	var ready := phase == "aim" and tab == 0 and not title_open and not editor_open and not offline_open
	throw_button.disabled = not ready
	if not ready:
		holding = false
	if phase == "flight":
		throw_button.text = "ЛЕТИТ"
	elif phase == "catch":
		throw_button.text = "ЛОВИ"
	elif holding:
		throw_button.text = "ОТПУСТИ"
	else:
		throw_button.text = "БРОСИТЬ"


func _toast(text: String) -> void:
	if text.strip_edges() == "":
		return
	toast_lines.append(text)
	while toast_lines.size() > 3:
		toast_lines.pop_front()
	toast_label.text = "\n".join(toast_lines)
	toast_left = 3.0


func _overlay(color: Color) -> ColorRect:
	var layer := ColorRect.new()
	layer.color = color
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.visible = false
	add_child(layer)
	return layer


func _overlay_box(layer: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 28
	box.offset_top = 80
	box.offset_right = -28
	box.offset_bottom = -48
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	layer.add_child(box)
	return box


func _label(text: String, size: int, color: Color, display_font: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", ThrowFonts.DISPLAY if display_font else ThrowFonts.BODY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _text_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", ThrowFonts.DISPLAY if primary else ThrowFonts.BODY)
	button.add_theme_font_size_override("font_size", 26 if primary else 20)
	button.add_theme_color_override("font_color", ThrowTheme.PAPER if primary else ThrowTheme.INK)
	button.add_theme_color_override("font_hover_color", ThrowTheme.PAPER)
	button.add_theme_color_override("font_pressed_color", ThrowTheme.PAPER)
	button.add_theme_color_override("font_disabled_color", ThrowTheme.MUTED)
	button.add_theme_stylebox_override("normal", _flat(ThrowTheme.ACCENT_DEEP if primary else ThrowTheme.BG_RAISED, 16))
	button.add_theme_stylebox_override("hover", _flat((ThrowTheme.ACCENT if primary else ThrowTheme.BG_RAISED).lightened(0.08), 16))
	button.add_theme_stylebox_override("pressed", _flat(ThrowTheme.ACCENT if primary else ThrowTheme.LINE, 16))
	button.add_theme_stylebox_override("focus", _flat(ThrowTheme.ACCENT_DEEP if primary else ThrowTheme.BG_RAISED, 16, ThrowTheme.ACCENT))
	button.add_theme_stylebox_override("disabled", _flat(ThrowTheme.SLOT, 16))
	return button


func _flat(color: Color, radius: int, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(2)
	return style


func _clear(node: Node) -> void:
	while node.get_child_count() > 0:
		var child := node.get_child(0)
		node.remove_child(child)
		child.free()
