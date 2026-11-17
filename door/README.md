# Откроешь дверь?

Портретная история на 30 дней: каждый день один короткий эпизод и два варианта. Ресурсы — еда, здоровье, рассудок, патроны. Выбор может убить. Тридцатый день — победа. Забеги разные: пул событий тасуется, часть дней срабатывает только после флагов.

Движок: **Godot 4.7.2**, GDScript, без .NET. Рендер: GL Compatibility. Веб-экспорт однопоточный, без SharedArrayBuffer и без заголовков cross-origin isolation — его можно класть на GitHub Pages.

Игра живёт в этой папке и не заменяет «Огурчика Чака» в корне репозитория. После деплоя:

- корень: https://dmitriigame.github.io/garlic_games/
- эта игра: https://dmitriigame.github.io/garlic_games/door/

## Открыть проект

1. Поставить [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) (стандартная сборка, не .NET).
2. Godot → Import → `door/project.godot`.
3. F5. Окно редактора узкое и вертикальное; на телефоне сцена занимает экран.

Управление: пальцем или мышью. На клавиатуре `1` / `2` — выбор, пробел — дальше, `M` — звук.

## Как устроен забег

Данные читает `scripts/game.gd`.

- День 1 — событие из `meta.opening_event`, если оно подходит по условиям. Дальше каждый день случайное подходящее событие с учётом `weight`.
- `once: true` (по умолчанию) — событие один раз за забег.
- `priority: true` — если событие подошло, оно вытесняет обычный пул. Так день 27 почти наверняка случается в свой день.
- Ночью, если еда за день не выросла, списывается `meta.upkeep`. Если списать нечего, срабатывает `meta.starve`.
- Здоровье или рассудок на нуле — смерть. У выбора может быть `kill: true`, тогда смерть сразу, с своим заголовком карточки.
- `meta.days_to_win` дней без смерти — победа.
- Карточка конца берёт до четырёх последних флагов, у которых есть строка в `meta.epithets`. «То же зерно» повторяет сид: те же события, если выбирать так же.

Если ни одно событие не подошло, есть тихий запасной день в коде, чтобы забег не вставал.

## Формат `data/events.json`

Файл — единственный источник дней, выборов, условий и эффектов. Код трогать не нужно, чтобы дописать серию.

```json
{
  "version": 1,
  "meta": {
    "days_to_win": 30,
    "opening_event": "knock_soft",
    "night_hint": "Текст под ресурсами.",
    "win_title": "Заголовок победы",
    "win_line": "Строка победы.",
    "stats": {
      "food": { "label": "еда", "start": 7, "max": 9 },
      "health": { "label": "здоровье", "start": 5, "max": 5 },
      "sanity": { "label": "рассудок", "start": 5, "max": 5 },
      "ammo": { "label": "патроны", "start": 2, "max": 6 }
    },
    "upkeep": { "food": -1 },
    "upkeep_skip_if_gained": ["food"],
    "starve": {
      "when": "food",
      "damage": { "health": -1 },
      "line": "Еды нет. Ночь ест тебя."
    },
    "epithets": { "has_dog": "с тобой был пёс" }
  },
  "events": []
}
```

Четыре ключа ресурсов зашиты в интерфейс (`food`, `health`, `sanity`, `ammo`). Новый ключ в эффектах игра проигнорирует, пока его не добавят в `STAT_ORDER` и в ряд на экране.

Событие:

| Поле | Зачем |
| --- | --- |
| `id` | Уникальная строка. |
| `scene` | Сценка. Картинка по умолчанию — `res://art/scenes/<scene>.webp`. Сейчас есть: `door`, `open`, `basement`, `window`, `stranger`, `radio`, `dog`, `street`, `mirror`, `kid`, `horde`, `letter`, `food`, `cult`, `soldier`, `quiet`. |
| `image` | Необязательный путь картинки относительно `res://art/`, без расширения. Пример: `scenes/door` или `hero`. Если файла нет, игра берёт картинку сцены, потом `hero.webp`. |
| `sound` | Необязательный путь звука относительно `res://audio/`, без расширения. Пример: `scenes/door` или `ui/page`. Если пусто или файла нет — звук сцены `scenes/<scene>.ogg`. |
| `setup` | Текст дня. Можно подставить `{day}`, `{food}`, `{health}`, `{sanity}`, `{ammo}`. |
| `once` | `true` по умолчанию. `false` — событие может повторяться. |
| `weight` | Вес в случайном выборе. |
| `priority` | Если подошло, выбирается только среди таких. |
| `when` | Условия, см. ниже. |
| `a`, `b` | Два выбора. |

`when`:

| Поле | Зачем |
| --- | --- |
| `min_day`, `max_day` | Окно дней, включительно. |
| `flags_all` | Все эти флаги уже стоят. |
| `flags_none` | Ни одного из этих флагов нет. |
| `flags_any` | Стоит хотя бы один. Пустой список ничего не требует. |
| `seen_all` | Эти `id` уже случались. |
| `stats` | Границы ресурса: `{ "food": { "min": 1, "max": 3 } }`. |

Выбор (`a` или `b`):

| Поле | Зачем |
| --- | --- |
| `label` | Текст кнопки. |
| `text` | Что показать после нажатия. |
| `effects` | Прибавки и штрафы, например `{ "food": 2, "sanity": -1 }`. Значения режутся в `0…max`. |
| `set_flags`, `clear_flags` | Поставить или снять флаги. |
| `kill` | Сразу смерть. |
| `death_title`, `death_line` | Карточка смерти. Если пусто, игра подставит текст по причине: голод, рассудок, тело. |
| `needs` | Минимум ресурса, например `{ "ammo": 1 }`. |
| `blocked` | Исход, если `needs` не выполнен. Без него кнопка просто погаснет. |
| `roll` | Список случайных исходов. У каждого `w` (вес), `text`, и те же `effects` / флаги / `kill`. Если `roll` есть, верхние `effects` выбора не применяются. |

Пример с цепочкой и случайностью:

```json
{
  "id": "basement",
  "scene": "basement",
  "once": true,
  "weight": 2,
  "when": { "min_day": 2, "max_day": 12 },
  "setup": "Из подвала звякает ложка.",
  "a": {
    "label": "Спуститься",
    "text": "Фонарь берёт тебя в историю.",
    "roll": [
      { "w": 3, "text": "Три банки.", "effects": { "food": 3 }, "set_flags": ["basement_loot"] },
      { "w": 2, "text": "У ложки был хозяин.", "effects": { "sanity": -2 }, "set_flags": ["basement_horror"] }
    ]
  },
  "b": {
    "label": "Заколотить люк",
    "text": "Тишина становится официальной.",
    "effects": { "sanity": 1 },
    "set_flags": ["basement_shut"]
  }
}
```

Дальше событие с `"when": { "flags_all": ["basement_shut"] }` увидит только тех, кто заколотил люк.

Новые рисунки клади в `door/art/` уже сжатыми (примерно 768 px, WebP quality 80) и укажи путь в `image`. Имя без папки `art/` и без `.webp`. Поле есть и в доке «События», и на экране «Править события».

## Как добавить событие

Любой из трёх путей пишет в один и тот же JSON.

1. **Файл.** Скопировать объект в `events`, дать новый `id`, сохранить. Godot подхватит при следующем запуске.
2. **Док редактора.** Плагин «События двери» включён в проекте. Справа док «События»: список, поля, сырой JSON одного события, кнопки «Новое», «Дублировать», «Удалить», «Сохранить файл». Если дока нет: Проект → Настройки проекта → Плагины → включить «События двери».
3. **Экран в игре.** На титре «Править события». Там тексты кнопок, ситуации и четыре числа эффектов. Случайный `roll` этот экран не затирает. В редакторе Godot запись идёт в `res://data/events.json`. В веб-сборке и в экспорте `res://` только для чтения, поэтому правка ложится в `user://events.json` и перекрывает файл игры. Кнопка «Сбросить user://» возвращает встроенные события. Пока проект открыт в редакторе, игра всегда читает `data/events.json`, чтобы док и плейтест не расходились.

Проверка без окна:

```bash
godot --headless --path door -s res://scripts/sim.gd
```

Скрипт гоняет осторожные, случайные и безрассудные забеги, проверяет цепочки флагов и смерть от «хора». Ненулевой код — правила сломались.

Звуки — записи CC0 (Kenney и OpenGameArt), список с авторами и ссылками в `door/audio/CREDITS.md`. Громкость — ползунок на титре, кнопка «Звук» выключает всё. В браузере звук начинается с первого нажатия.

Патроны встречаются в обычном забеге, не только в конце. Отдельные события: `stair_zombie`, `marauders`, `mailbox_rounds`, `trader_shells`, `peephole_shot`, `basement_lurker`, `horde_warning`, `window_scare`, `soldier_box`, `landing_shot`, `kid_shells`, `radio_belt`. В них патроны тратят, находят или меняют. Цвета палитры — в `door/scripts/door_theme.gd`.

## Веб

Пресет **Web**: `variant/thread_support=false`, `progressive_web_app/ensure_cross_origin_isolation_headers=false`. GitHub Pages такие заголовки не отдаёт, и мобильный браузер тоже не обязан.

Локально:

```bash
godot --headless --path door --import --quit
godot --headless --path door --export-release "Web" /tmp/door-web/index.html
python3 -m http.server -d /tmp/door-web 8765
```

Нужны экспортные шаблоны той же версии. В CI их ставит `.github/workflows/pages.yml`: качает Godot 4.7.2, забирает из архива шаблонов только `web_nothreads_*`, собирает сайт и кладёт игру в `/door/`, а корневые `index.html`, `game.js`, `style.css` и `assets/` копирует как были.

## Android

Пресет **Android** уже в `export_presets.cfg`:

- пакет `com.dmitriigame.door`;
- имя «Откроешь дверь?»;
- портрет берётся из настройки проекта `display/window/handheld/orientation = portrait`, её читает экспорт Android;
- архитектура `arm64-v8a`, формат APK, immersive и edge-to-edge.

Сборка APK в CI не включена: для подписи нужен keystore, а для Gradle — Android SDK. Корневой деплой Pages из‑за этого не зависит от Android.

Собрать у себя:

1. Editor → Manage Export Templates, шаблоны 4.7.2.
2. Поставить Android SDK (хватит command-line tools и build-tools) и указать пути в Editor Settings → Export → Android.
3. Создать keystore:

```bash
keytool -genkeypair -v -keystore door.keystore -alias door -keyalg RSA -keysize 2048 -validity 10000
```

4. В пресете Android вписать путь к keystore, alias и пароли (release; для отладки Godot может взять debug-keystore).
5. Проект → Экспорт → Android → `door/build/android/door.apk`.
6. `adb install -r door/build/android/door.apk`.

Если позже понадобится APK из GitHub Actions, в job нужны SDK, шаблон `android_source.zip` и секреты `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Сейчас этого нет специально.
