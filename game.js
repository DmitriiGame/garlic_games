// Огурчик Чак: Сад Искушений (18+)
(function () {
  "use strict";

  const ROWS = 8, COLS = 8, MANA_MAX = 10;
  const AGE_KEY = "cucumber-chuck-18";
  const MUTE_KEY = "chuck-mute";
  const TYPE_IDS = ["passion", "dew", "sap", "amber", "temptation"];
  const TYPE = {
    passion:    { id: "passion",    name: "Страсть",     short: "СТ" },
    dew:        { id: "dew",        name: "Роса",        short: "РС" },
    sap:        { id: "sap",        name: "Сок",         short: "СК" },
    amber:      { id: "amber",      name: "Янтарь",      short: "ЯН" },
    temptation: { id: "temptation", name: "Искушение",   short: "ИС" }
  };

  const $ = (id) => document.getElementById(id);
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  const clamp = (n, a, b) => Math.max(a, Math.min(b, n));
  const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
  const uid = (() => { let n = 1; return () => ++n; })();

  /* ---------- web audio (unlocked on the first gesture) ---------- */
  const SFX = (() => {
    let ctx = null;
    let master = null;
    let noiseBuf = null;
    let muted = false;
    try { muted = localStorage.getItem(MUTE_KEY) === "1"; } catch (_) {}

    function ac() {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      if (!ctx) {
        ctx = new AC();
        master = ctx.createGain();
        master.gain.value = 0.32;
        master.connect(ctx.destination);
        const n = Math.floor(ctx.sampleRate * 0.2);
        noiseBuf = ctx.createBuffer(1, n, ctx.sampleRate);
        const data = noiseBuf.getChannelData(0);
        for (let i = 0; i < n; i++) data[i] = Math.random() * 2 - 1;
      }
      if (ctx.state === "suspended") ctx.resume().catch(() => {});
      return ctx;
    }

    function unlock() {
      try { ac(); } catch (_) {}
    }

    function setMuted(v) {
      muted = !!v;
      try { localStorage.setItem(MUTE_KEY, muted ? "1" : "0"); } catch (_) {}
      const btn = $("btn-mute");
      if (btn) {
        btn.textContent = muted ? "🔇" : "🔊";
        btn.setAttribute("aria-pressed", muted ? "true" : "false");
        btn.setAttribute("aria-label", muted ? "Звук выключен" : "Звук включён");
      }
    }

    function toggle() {
      unlock();
      setMuted(!muted);
    }

    function env(t, dur, peak) {
      const g = ctx.createGain();
      g.connect(master);
      const p = Math.max(0.001, peak || 0.12);
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(p, t + 0.012);
      g.gain.exponentialRampToValueAtTime(0.0001, t + Math.max(0.03, dur));
      return g;
    }

    function tone(freq, dur, type, peak, delay) {
      const c = ac();
      if (!c || !master) return;
      const t0 = c.currentTime + (delay || 0);
      const o = c.createOscillator();
      o.type = type || "sine";
      o.frequency.setValueAtTime(freq, t0);
      o.connect(env(t0, dur, peak));
      o.start(t0);
      o.stop(t0 + dur + 0.03);
    }

    function noise(dur, peak, freq) {
      const c = ac();
      if (!c || !master || !noiseBuf) return;
      const t0 = c.currentTime;
      const src = c.createBufferSource();
      src.buffer = noiseBuf;
      const filter = c.createBiquadFilter();
      filter.type = "bandpass";
      filter.frequency.value = freq || 700;
      filter.Q.value = 0.6;
      src.connect(filter);
      filter.connect(env(t0, dur, peak));
      src.start(t0);
      src.stop(t0 + dur + 0.02);
    }

    function play(name, opt) {
      try {
        if (muted) return;
        const o = opt || {};
        if (name === "swap") {
          tone(520, 0.06, "triangle", 0.1);
          tone(700, 0.05, "sine", 0.05, 0.03);
        } else if (name === "bad") {
          tone(130, 0.12, "square", 0.05);
          tone(86, 0.14, "sawtooth", 0.03, 0.04);
        } else if (name === "match") {
          const step = Math.min(o.combo || 1, 8);
          const f = 360 * Math.pow(1.16, step - 1);
          tone(f, 0.08, "triangle", 0.12);
          tone(f * 1.5, 0.09, "sine", 0.06, 0.035);
        } else if (name === "spell") {
          const map = {
            passion: [520, 680, "sawtooth"],
            dew: [660, 880, "sine"],
            sap: [392, 494, "triangle"],
            amber: [440, 587, "square"],
            temptation: [311, 466, "triangle"]
          };
          const m = map[o.type] || map.passion;
          tone(m[0], 0.11, m[2], 0.09);
          tone(m[1], 0.14, "sine", 0.06, 0.05);
        } else if (name === "hit") {
          noise(0.07, 0.16, 420);
          tone(170, 0.09, "square", 0.06);
        } else if (name === "attack") {
          noise(0.09, 0.14, 200);
          tone(100, 0.14, "sawtooth", 0.05);
        } else if (name === "shield") {
          tone(880, 0.07, "sine", 0.08);
          tone(1320, 0.09, "triangle", 0.05, 0.035);
        } else if (name === "heal") {
          tone(523, 0.09, "sine", 0.08);
          tone(659, 0.1, "sine", 0.06, 0.06);
          tone(784, 0.12, "triangle", 0.05, 0.11);
        } else if (name === "win") {
          [523, 659, 784, 1046].forEach((f, i) => tone(f, 0.15, "triangle", 0.08, i * 0.08));
        } else if (name === "lose") {
          [392, 330, 262, 196].forEach((f, i) => tone(f, 0.16, "sine", 0.07, i * 0.09));
        } else if (name === "click") {
          tone(760, 0.035, "square", 0.04);
        }
      } catch (_) {}
    }

    return { unlock, toggle, setMuted, play, isMuted: () => muted };
  })();

  /* ---------- portraits ---------- */
  function svgWrap(id, inner, bg0, bg1) {
    return `<svg viewBox="0 0 80 80" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <defs>
        <radialGradient id="${id}-bg" cx="38%" cy="30%">
          <stop offset="0%" stop-color="${bg0 || "#6a3060"}"/>
          <stop offset="100%" stop-color="${bg1 || "#241018"}"/>
        </radialGradient>
      </defs>
      <circle cx="40" cy="40" r="38.5" fill="url(#${id}-bg)" stroke="#e8b86a" stroke-width="1.8"/>
      ${inner}
    </svg>`;
  }

  // Cute cartoon enemies: bold outlines, blush, bedroom eyes, fully clothed
  const CARTOON = {
    radish: svgWrap("radish", `
      <path d="M18 78 Q28 58 40 60 Q52 58 62 78 Z" fill="#c45a7a" stroke="#2a1218" stroke-width="1.6"/>
      <path d="M26 70 Q40 62 54 70" fill="none" stroke="#f8d0dc" stroke-width="1.2"/>
      <ellipse cx="40" cy="44" rx="22" ry="24" fill="#e85a72" stroke="#2a1218" stroke-width="2"/>
      <ellipse cx="40" cy="46" rx="15" ry="16" fill="#f4a0b0" opacity=".35"/>
      <path d="M22 20 Q32 4 40 16 Q48 2 58 18 Q50 14 40 16 Q30 14 22 20Z" fill="#3d8a3a" stroke="#1a3018" stroke-width="1.6"/>
      <path d="M30 16 Q26 0 20 8" fill="#4ea050" stroke="#1a3018" stroke-width="1.2"/>
      <path d="M50 16 Q58 0 60 12" fill="#3d8a3a" stroke="#1a3018" stroke-width="1.2"/>
      <path d="M24 58 Q40 52 56 58 Q54 66 40 66 Q26 66 24 58Z" fill="#fff8f0" stroke="#2a1218" stroke-width="1.4"/>
      <path d="M28 62 Q40 58 52 62" fill="none" stroke="#e8a0b8" stroke-width="1"/>
      <ellipse cx="29" cy="46" rx="5.5" ry="3.2" fill="#ff9ab0" opacity=".85"/>
      <ellipse cx="51" cy="46" rx="5.5" ry="3.2" fill="#ff9ab0" opacity=".85"/>
      <path d="M26 36 Q32 32 37 36" fill="none" stroke="#2a1218" stroke-width="1.5" stroke-linecap="round"/>
      <path d="M44 35 Q50 31 55 36" fill="none" stroke="#2a1218" stroke-width="1.5" stroke-linecap="round"/>
      <ellipse cx="32" cy="42" rx="3.2" ry="3.6" fill="#2a1218"/>
      <path d="M44 42 Q48 38 53 42 Q48 44 44 42Z" fill="#2a1218"/>
      <circle cx="33.2" cy="40.8" r="1" fill="#fff"/>
      <path d="M28 41.5 Q31 40 35 41.8" fill="none" stroke="#2a1218" stroke-width="1.1"/>
      <path d="M34 54 Q40 59 49 53" fill="none" stroke="#6a2030" stroke-width="1.8" stroke-linecap="round"/>
    `, "#7a3050", "#2a1018"),

    eggplant: svgWrap("egg", `
      <path d="M10 80 L16 60 Q40 50 64 60 L70 80 Z" fill="#1a1028" stroke="#100814" stroke-width="1.4"/>
      <path d="M14 62 L40 52 L66 62 L72 46 L40 34 L8 46 Z" fill="#f4e8dc" stroke="#2a1810" stroke-width="1.5"/>
      <path d="M16 62 L40 54 L64 62 L64 70 L16 70 Z" fill="#1a1028"/>
      <ellipse cx="40" cy="40" rx="20" ry="23" fill="#5a2a78" stroke="#1a1020" stroke-width="2"/>
      <ellipse cx="40" cy="38" rx="14" ry="16" fill="#7a48a0"/>
      <path d="M28 14 Q40 6 52 14 Q48 24 40 22 Q32 24 28 14Z" fill="#2d7a34" stroke="#143018" stroke-width="1.4"/>
      <ellipse cx="29" cy="42" rx="5.2" ry="3" fill="#e89ad0" opacity=".7"/>
      <ellipse cx="51" cy="42" rx="5.2" ry="3" fill="#e89ad0" opacity=".7"/>
      <path d="M26 32 Q32 27 37 32" fill="none" stroke="#1a0818" stroke-width="1.6" stroke-linecap="round"/>
      <path d="M43 31 Q49 26 54 32" fill="none" stroke="#1a0818" stroke-width="1.6" stroke-linecap="round"/>
      <ellipse cx="32" cy="38" rx="3.4" ry="2.3" fill="#1a0818"/>
      <ellipse cx="48" cy="38" rx="3.4" ry="2.3" fill="#1a0818"/>
      <circle cx="33.2" cy="37.2" r=".9" fill="#fff"/>
      <circle cx="49.2" cy="37.2" r=".9" fill="#fff"/>
      <path d="M36 50 Q42 55 51 48" fill="none" stroke="#f0c0e0" stroke-width="1.7" stroke-linecap="round"/>
      <path d="M51 50 L54.5 54.5" fill="none" stroke="#f4e8dc" stroke-width="1.6" stroke-linecap="round"/>
    `, "#3a1850", "#140818"),

    vine: svgWrap("vine", `
      <path d="M12 80 Q28 56 40 60 Q52 56 68 80 Z" fill="#2d6a38" stroke="#143018" stroke-width="1.6"/>
      <path d="M24 70 Q40 60 56 70" fill="none" stroke="#f0c0d0" stroke-width="1.1"/>
      <circle cx="20" cy="66" r="3.4" fill="#7a2a60" stroke="#2a1020" stroke-width="1"/>
      <circle cx="60" cy="68" r="3.4" fill="#7a2a60" stroke="#2a1020" stroke-width="1"/>
      <circle cx="20" cy="66" r="1.4" fill="#f0c14b"/><circle cx="60" cy="68" r="1.4" fill="#f0c14b"/>
      <ellipse cx="40" cy="42" rx="18" ry="21" fill="#f0d8c0" stroke="#2a1810" stroke-width="2"/>
      <path d="M22 26 Q28 6 40 14 Q52 4 58 26" fill="#3d8a3a" stroke="#1a3018" stroke-width="1.6"/>
      <path d="M28 18 Q22 4 16 12" fill="#4ea050" stroke="#1a3018" stroke-width="1.2"/>
      <path d="M50 16 Q60 2 64 16" fill="#2d6a34" stroke="#1a3018" stroke-width="1.2"/>
      <path d="M16 50 Q6 36 18 28" fill="none" stroke="#3d8a3a" stroke-width="2.4" stroke-linecap="round"/>
      <path d="M64 52 Q76 38 62 26" fill="none" stroke="#3d8a3a" stroke-width="2.4" stroke-linecap="round"/>
      <ellipse cx="30" cy="44" rx="5" ry="3" fill="#f0a0b8" opacity=".8"/>
      <ellipse cx="50" cy="44" rx="5" ry="3" fill="#f0a0b8" opacity=".8"/>
      <path d="M26 34 Q32 30 37 35" fill="none" stroke="#2a1810" stroke-width="1.4" stroke-linecap="round"/>
      <path d="M44 33 Q50 29 55 35" fill="none" stroke="#2a1810" stroke-width="1.4" stroke-linecap="round"/>
      <ellipse cx="32" cy="40" rx="2.9" ry="3.3" fill="#2a1810"/>
      <path d="M44 40 Q48 36 53 40 Q48 43 44 40Z" fill="#2a1810"/>
      <circle cx="33" cy="38.8" r=".9" fill="#fff"/>
      <path d="M28 39.4 Q31 38 35 39.6" fill="none" stroke="#2a1810" stroke-width="1"/>
      <path d="M34 52 Q40 57 49 51" fill="none" stroke="#6b3040" stroke-width="1.7" stroke-linecap="round"/>
    `, "#2a5030", "#141810")
  };

  const GEM_IMG = {
    passion: "assets/gem-passion.png",
    dew: "assets/gem-dew.png",
    sap: "assets/gem-sap.png",
    amber: "assets/gem-amber.png",
    temptation: "assets/gem-temptation.png"
  };
  const GEM_COLOR = {
    passion: "#ff4d6d",
    dew: "#7ecbff",
    sap: "#5ee58a",
    amber: "#ffc14d",
    temptation: "#c77dff"
  };

  const PHOTO = {
    hero:  { src: "assets/cucumber-chuck.png", alt: "Огурчик Чак" },
    chili: { src: "assets/chili-enemy.png", alt: "Перчик-жегучик" },
    onion: { src: "assets/onion-enemy.png", alt: "Луковая роковая дама" },
    melon: { src: "assets/melon-boss.png", alt: "Дынька-Искусительница" }
  };

  function photoHTML(id, mode) {
    const p = PHOTO[id];
    if (!p) return CARTOON[id] || CARTOON.vine;
    const cls = mode === "figure" ? ("figure fig-" + id) : ("bust bust-" + id);
    return `<img class="${cls}" src="${p.src}" alt="${p.alt}" draggable="false">`;
  }

  function setPortrait(el, id, mode) {
    if (!el) return;
    el.innerHTML = photoHTML(id, mode || "bust");
  }

  /* ---------- flirt copy (bawdy innuendo, no graphic acts) ---------- */
  const HERO_CAST_LINES = [
    "Дыши глубже — сейчас будет хрустко.",
    "Не красней. Я только рассол разогрел.",
    "Ещё один пупырышек — и ты уже на моей стороне постели… то есть грядки.",
    "Поцелуй с огурчиком. Бесплатно, но с послевкусием рассола.",
    "Я не снимаю жилетку даже в самые пикантные моменты.",
    "Мой хруст работает ниже пояса настроения. Замечаешь?",
    "Подмигнул. Дальше ты сама додумывай."
  ];
  const HERO_WIN_LINES = [
    "Ну что, признайся: от моего хруста у тебя подкосились ножки.",
    "Победа хрустящая. Почти как ты, когда злишься.",
    "Я бы предложил реванш в более мягкой постели… то есть, клумбе.",
    "Пупырышки на месте, репутация — уже нет. Принимаю комплименты."
  ];
  const HERO_HIT_LINES = [
    "Ой. Кто-то любит пожестче.",
    "Ещё раз так, и я подумаю, что ты заигрываешь.",
    "Ай. Зато страстно."
  ];

  /* ---------- content ---------- */
  const SPELLS = {
    crunchStrike: {
      id: "crunchStrike",
      name: "Хрустящий выпад",
      desc: "11 урона. Хруст, от которого слабеют колени — и не только.",
      cost: { passion: 3 },
      cast() { damageEnemy(11 + relicBonus("firstBump"), pick(HERO_CAST_LINES)); }
    },
    brineCloak: {
      id: "brineCloak",
      name: "Рассольный плащ",
      desc: "Щит 8. Рассол тоже умеет быть бархатным наощупь.",
      cost: { dew: 3 },
      cast() { addShield(8); toast("Плащ сел как вторая кожа. Очень к лицу — и к телу."); }
    },
    healingBump: {
      id: "healingBump",
      name: "Целебный пупырышек",
      desc: "Лечение 9. Один пупырышек — и снова в форме для шалостей.",
      cost: { sap: 3 },
      cast() { healHero(9); toast("Рассол побежал куда надо. Чак снова свеж и хрустит."); }
    },
    brineKiss: {
      id: "brineKiss",
      name: "Рассольный поцелуй",
      desc: "6 лечения и 8 урона. Близко, солоно, с хрустящим послевкусием.",
      cost: { amber: 2, sap: 2 },
      cast() { healHero(6); damageEnemy(8 + relicBonus("firstBump"), "Поцелуй с рассольным послевкусием. Не благодари — лучше покрасней.", "kiss"); }
    },
    spicyWhisper: {
      id: "spicyWhisper",
      name: "Пьянящий шёпот",
      desc: "Следующий удар врага слабее вдвое. Голова — не тем занята.",
      cost: { temptation: 4 },
      cast(s) { s.enemy.frail = Math.max(s.enemy.frail || 0, 50); playHitOnEnemy("temptation"); toast("Я шепнул такое, что клинок сам выпал из мыслей."); }
    },
    petalStorm: {
      id: "petalStorm",
      name: "Буря лепестков",
      desc: "18 урона. Лепестки липнут, как чужие руки на танцах.",
      cost: { passion: 5 },
      cast() { damageEnemy(18 + relicBonus("firstBump"), "Лепестки хлещут сладко. И чуть ниже приличия."); }
    },
    royalCrunch: {
      id: "royalCrunch",
      name: "Королевский хруст",
      desc: "9 урона и щит 5. Хрустишь так, будто уже остался на ночь.",
      cost: { amber: 3, passion: 2 },
      cast() { damageEnemy(9 + relicBonus("firstBump")); addShield(5); toast("Воздух стал густым, как комплимент шёпотом на ухо."); }
    },
    sapFeast: {
      id: "sapFeast",
      name: "Пир рассола",
      desc: "Лечение 17. Солёно, сытно, почти неприлично вкусно.",
      cost: { sap: 5 },
      cast() { healHero(17); toast("Чак отпивает — и цветом играет, как после хорошего свидания."); }
    },
    coldShoulder: {
      id: "coldShoulder",
      name: "Холодное плечо",
      desc: "Щит 9 и −3 к следующему удару. Сначала дай, потом отодвинь.",
      cost: { dew: 4, temptation: 1 },
      cast(s) { addShield(9); s.enemy.weaken = (s.enemy.weaken || 0) + 3; toast("Она тянется — он чуть отстраняется. Играем, милая."); }
    }
  };

  const RELICS = {
    firstBump: { id: "firstBump", name: "Медальон Первого Пупырышка", desc: "Все заклинания наносят на 2 урона больше. Острее, чем комплимент." },
    eveningPerfume: { id: "eveningPerfume", name: "Духи «Полуночный рассол»", desc: "В начале каждого боя — по 2 маны каждого цвета. Пахнешь, как банка до полуночи." },
    silkRibbon: { id: "silkRibbon", name: "Шёлковая лента Лозы", desc: "+12 к запасу здоровья. Сразу ощущается на шее — и не только." },
    pepperHeart: { id: "pepperHeart", name: "Сердце перчика", desc: "Камни Страсти бьют на 1 сильнее за каждый камень. Горячее обычного." },
    onionRing: { id: "onionRing", name: "Перстенёк из шелухи", desc: "Сборка из 4+ камней даёт ещё 2 маны того же цвета." },
    ripeCharm: { id: "ripeCharm", name: "Спелый талисман", desc: "В начале вашего хода восстанавливает 2 здоровья. Спелость идёт на пользу." },
    countCape: { id: "countCape", name: "Кружевная накидка дамы", desc: "Первый удар врага в каждом бою слабее вдвое. Слёзы — её сцена, кружева — твоя защита." }
  };

  const ENEMIES = [
    {
      id: "chili",
      name: "Перчик-жегучик",
      where: "Жгучая аллея",
      maxHp: 41,
      atk: 8,
      portrait: "chili",
      taunts: [
        "Осторожно, Чак: я жгуче целуюсь. Проверишь?",
        "Этот огонёк на макушке — не единственное, что у меня горячее.",
        "Не красней так, это моя работа. Хотя тебе идёт.",
        "Мускулы, ус и характер. Жилетку поправь и подойди ближе.",
        "Я подмигнул. Дальше будет остро — и тебе понравится."
      ],
      intent() { return { label: `Удар ${this.atk}`, type: "hit" }; },
      act(s) { enemyStrike(this.atk, pick(this.taunts)); }
    },
    {
      id: "onion",
      name: "Луковая роковая дама",
      where: "Кружевной будуар",
      maxHp: 59,
      atk: 10,
      portrait: "onion",
      taunts: [
        "Не смотри так… от твоего хруста у меня уже слеза, и вовсе не от горя.",
        "Платочек мокрый, кружева чёрные, намерения ещё чернее.",
        "Поплакать на твоём плече? Только если снимешь жилетку и пообещаешь не уходить.",
        "Я роковая дама: сначала слезинка, потом ты уже не вспомнишь, зачем пришёл.",
        "Шелуха у меня многослойная. Снимать будешь медленно… если победишь."
      ],
      intent() { return { label: `Удар ${this.atk} + Слеза`, type: "tear" }; },
      act(s) {
        enemyStrike(this.atk, pick(this.taunts));
        if (s.enemy.hp > 0) {
          s.enemy.hp = Math.min(s.enemy.maxHp, s.enemy.hp + 4);
          toast("Томная слеза — и она снова в форме. Какая актриса.");
        }
      }
    },
    {
      id: "vine",
      name: "Изабелла, Лоза-Дриада",
      where: "Беседка сладкой лозы",
      maxHp: 72,
      atk: 11,
      portrait: "vine",
      taunts: [
        "Подойди ближе, я только обовьюсь… совсем чуть-чуть. Потом крепче.",
        "Мои усики лезут не в те места. Приятные, впрочем.",
        "В моей тени тепло и тесно. Оставайся, снимем жилетку аккуратно.",
        "Не вырывайся: от меня уходят только с ягодкой на губах и путаницей в голове."
      ],
      intent(s) {
        const wrap = ((s.enemy.turnCount || 0) + 1) % 3 === 0;
        return wrap
          ? { label: `Обвитие + удар ${this.atk}`, type: "wrap" }
          : { label: `Удар ${this.atk}`, type: "hit" };
      },
      act(s) {
        const wrap = ((s.enemy.turnCount || 0) + 1) % 3 === 0;
        enemyStrike(this.atk, pick(this.taunts));
        if (wrap && s.hero.hp > 0) {
          stealMostMana(2);
          toast("Усики скользнули к мане — пальцы у неё явно опытные.");
        }
        s.enemy.turnCount = (s.enemy.turnCount || 0) + 1;
      }
    },
    {
      id: "melon",
      name: "Дынька-Искусительница",
      where: "Чертог спелости",
      maxHp: 109,
      atk: 15,
      portrait: "melon",
      isBoss: true,
      taunts: [
        "Ну наконец-то, мой хрустящий. Я так долго тебя зрела — уже сок на уме.",
        "Спелая, сладкая, в кружевах. Угадай, с чего начнём, если проиграешь.",
        "Попробуй на запах. Потом, если повезёт, и на вкус. Я не кусаюсь. Обычно.",
        "Жилетку сними, Чак. Она будет мешать, когда я к тебе наклонюсь.",
        "После меня тебе пресный суп даже на ум не придёт. Я порция на всю ночь.",
        "Хрустни ещё раз. Я люблю, когда от тебя несёт уверенностью. И рассолом.",
        "В этих кружевах жарко. Виноват будешь ты, если они вдруг станут тесны."
      ],
      intent(s) {
        const heavy = ((s.enemy.turnCount || 0) + 1) % 3 === 0;
        const dmg = heavy ? Math.round(this.atk * 1.6) : this.atk;
        return heavy
          ? { label: `Томный вздох ${dmg}`, type: "sigh" }
          : { label: `Удар ${this.atk}`, type: "hit" };
      },
      act(s) {
        const heavy = ((s.enemy.turnCount || 0) + 1) % 3 === 0;
        const dmg = heavy ? Math.round(this.atk * 1.6) : this.atk;
        enemyStrike(dmg, pick(this.taunts));
        if (heavy && s.hero.hp > 0) {
          s.hero.shield = 0;
          toast("Томный вздох снёс и щит, и остатки скромности.");
        }
        s.enemy.turnCount = (s.enemy.turnCount || 0) + 1;
      }
    }
  ];

  const REWARD_SPELLS = ["brineKiss", "spicyWhisper", "petalStorm", "royalCrunch", "sapFeast", "coldShoulder"];
  const REWARD_RELICS = Object.keys(RELICS);

  /* ---------- state ---------- */
  let S = null;
  let gems = [];
  let selected = null;
  let busy = false;
  let swappedThisTurn = false;
  let drag = null;

  function newRun() {
    return {
      floor: 0,
      hero: {
        name: "Огурчик Чак",
        hp: 90,
        maxHp: 90,
        shield: 0,
        mana: { passion: 0, dew: 0, sap: 0, amber: 0, temptation: 0 },
        spells: ["crunchStrike", "brineCloak", "healingBump"],
        relics: [],
        firstHitPending: false
      },
      enemy: null,
      turn: "player",
      tutorial: true,
      over: false
    };
  }

  function hasRelic(id) { return S.hero.relics.includes(id); }
  function relicBonus(id) { return hasRelic(id) ? 2 : 0; }

  /* ---------- board ---------- */
  function randomType() { return TYPE_IDS[Math.floor(Math.random() * TYPE_IDS.length)]; }

  function gridTypes() {
    const g = Array.from({ length: ROWS }, () => Array(COLS).fill(null));
    for (const gem of gems) if (gem.r >= 0 && gem.r < ROWS) g[gem.r][gem.c] = gem.type;
    return g;
  }

  function wouldMatchAt(grid, r, c, type) {
    if (c >= 2 && grid[r][c - 1] === type && grid[r][c - 2] === type) return true;
    if (r >= 2 && grid[r - 1][c] === type && grid[r - 2][c] === type) return true;
    return false;
  }

  function findMatches(grid) {
    const del = new Set();
    for (let r = 0; r < ROWS; r++) {
      let run = 1;
      for (let c = 1; c <= COLS; c++) {
        if (c < COLS && grid[r][c] && grid[r][c] === grid[r][c - 1]) run++;
        else {
          if (run >= 3) for (let k = c - run; k < c; k++) del.add(r + "," + k);
          run = 1;
        }
      }
    }
    for (let c = 0; c < COLS; c++) {
      let run = 1;
      for (let r = 1; r <= ROWS; r++) {
        if (r < ROWS && grid[r][c] && grid[r][c] === grid[r - 1][c]) run++;
        else {
          if (run >= 3) for (let k = r - run; k < r; k++) del.add(k + "," + c);
          run = 1;
        }
      }
    }
    return del;
  }

  function hasMove(grid) {
    const dirs = [[0, 1], [1, 0]];
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        for (const [dr, dc] of dirs) {
          const r2 = r + dr, c2 = c + dc;
          if (r2 >= ROWS || c2 >= COLS) continue;
          const a = grid[r][c]; grid[r][c] = grid[r2][c2]; grid[r2][c2] = a;
          const ok = findMatches(grid).size > 0;
          grid[r2][c2] = grid[r][c]; grid[r][c] = a;
          if (ok) return true;
        }
      }
    }
    return false;
  }

  function buildInitialBoard() {
    for (let attempt = 0; attempt < 40; attempt++) {
      const grid = Array.from({ length: ROWS }, () => Array(COLS).fill(null));
      for (let r = 0; r < ROWS; r++) {
        for (let c = 0; c < COLS; c++) {
          let type, tries = 0;
          do { type = randomType(); tries++; }
          while (wouldMatchAt(grid, r, c, type) && tries < 16);
          grid[r][c] = type;
        }
      }
      if (findMatches(grid).size === 0 && hasMove(grid)) return grid;
    }
    const grid = Array.from({ length: ROWS }, () => Array(COLS).fill(null));
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
      let type, tries = 0;
      do { type = randomType(); tries++; }
      while (wouldMatchAt(grid, r, c, type) && tries < 16);
      grid[r][c] = type;
    }
    return grid;
  }

  function gemAt(r, c) { return gems.find((g) => g.r === r && g.c === c); }

  function positionGem(g, animate) {
    if (animate) g.el.classList.add("falling");
    g.el.style.setProperty("--r", g.r);
    g.el.style.setProperty("--c", g.c);
    if (animate) {
      const el = g.el;
      window.setTimeout(() => el.classList.remove("falling"), 220);
    }
  }

  function makeGemEl(g) {
    const el = document.createElement("div");
    el.className = "gem";
    el.dataset.type = g.type;
    el.dataset.id = String(g.id);
    el.style.setProperty("--r", g.r);
    el.style.setProperty("--c", g.c);
    const inner = document.createElement("img");
    inner.className = "gem-art";
    inner.src = GEM_IMG[g.type];
    inner.alt = TYPE[g.type].name;
    inner.draggable = false;
    el.appendChild(inner);
    el.addEventListener("pointerdown", onPointerDown);
    return el;
  }

  function mountBoard(grid) {
    const board = $("board");
    [...board.querySelectorAll(".gem")].forEach((el) => el.remove());
    gems = [];
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        const g = { id: uid(), type: grid[r][c], r, c, el: null };
        g.el = makeGemEl(g);
        board.appendChild(g.el);
        gems.push(g);
      }
    }
    selected = null;
  }

  async function trySwap(a, b) {
    if (busy || S.turn !== "player" || S.over) return;
    if (!a || !b) return;
    const adj = Math.abs(a.r - b.r) + Math.abs(a.c - b.c) === 1;
    if (!adj) {
      setSelected(b);
      return;
    }
    if (swappedThisTurn) {
      toast("Один ход — один обмен. Дальше — заклинания или конец хода. Я никуда не спешу… почти.");
      setSelected(null);
      return;
    }
    busy = true;
    setSelected(null);
    await swapGems(a, b, true);
    const grid = gridTypes();
    if (findMatches(grid).size === 0) {
      await wait(140);
      await swapGems(a, b, true);
      SFX.play("bad");
      toast("Камни не хотят так стоять. Попробуй иначе, смелее.");
      busy = false;
      return;
    }
    swappedThisTurn = true;
    SFX.play("swap");
    await resolveMatches();
    if (S.over) { busy = false; return; }
    if (!hasMove(gridTypes())) await shuffleBoard("Камни перемешались, будто от смущения. Мило.");
    busy = false;
    renderChrome();
    pulseEndTurn();
  }

  async function swapGems(a, b, animate) {
    const ar = a.r, ac = a.c;
    a.r = b.r; a.c = b.c;
    b.r = ar; b.c = ac;
    if (animate) {
      a.el.classList.add("swapping");
      b.el.classList.add("swapping");
    }
    positionGem(a, animate);
    positionGem(b, animate);
    await wait(animate ? 170 : 0);
    a.el.classList.remove("swapping");
    b.el.classList.remove("swapping");
  }

  async function resolveMatches() {
    let combo = 0;
    while (!S.over) {
      const grid = gridTypes();
      const del = findMatches(grid);
      if (del.size === 0) break;
      combo++;
      await popMatches(del, combo);
      if (S.over) break;
      await fallAndFill();
    }
    if (combo >= 2 && !S.over) {
      floatBoard(combo >= 3 ? "Ох, какой размах!" : "Комбо ×" + combo, "combo");
      burstFX($("board"), 6);
      if (combo >= 4) shake(false);
    }
  }

  async function popMatches(del, combo) {
    const groups = {};
    const toPop = [];
    for (const key of del) {
      const [r, c] = key.split(",").map(Number);
      const g = gemAt(r, c);
      if (!g) continue;
      toPop.push(g);
      (groups[g.type] ||= []).push(g);
    }
    for (const g of toPop) g.el.classList.add("popping");
    for (const [type, list] of Object.entries(groups)) burstParticles(list, type);
    SFX.play("match", { combo });
    awardGroups(groups, combo);
    renderChrome();
    await wait(200);
    for (const g of toPop) {
      g.el.remove();
      gems = gems.filter((x) => x.id !== g.id);
    }
  }

  function awardGroups(groups, combo) {
    const comboBonus = combo > 1 ? combo - 1 : 0;
    for (const [type, list] of Object.entries(groups)) {
      const n = list.length;
      let mana = n + (n >= 5 ? 2 : n >= 4 ? 1 : 0) + comboBonus;
      if (n >= 4 && hasRelic("onionRing")) mana += 2;
      addMana(type, mana);
      const mid = list[Math.floor(list.length / 2)];
      if (type === "passion") {
        const dmg = Math.max(1, Math.round(n * 1.55) + (hasRelic("pepperHeart") ? n : 0));
        damageEnemy(dmg);
        floatAtGem(mid, "−" + dmg, "dmg");
      } else if (type === "dew") {
        const shield = Math.max(1, Math.round(n * 0.8));
        addShield(shield);
        floatAtGem(mid, "щит +" + shield, "mana");
        playHealOnHero("щит +" + shield);
      } else if (type === "sap") {
        const heal = Math.max(1, Math.round(n * 0.8));
        healHero(heal);
        floatAtGem(mid, "+" + heal, "heal");
        playHealOnHero("+" + heal);
      } else if (type === "amber") {
        const others = TYPE_IDS.filter((t) => t !== "amber");
        addMana(pick(others), n >= 4 ? 2 : 1);
        floatAtGem(mid, "искра", "mana");
        playHitOnEnemy("amber");
      } else if (type === "temptation") {
        S.enemy.weaken = (S.enemy.weaken || 0) + n;
        floatAtGem(mid, "томность", "mana");
        playHitOnEnemy("temptation", "томность");
      }
    }
  }

  async function fallAndFill() {
    const board = $("board");
    for (let c = 0; c < COLS; c++) {
      const col = gems.filter((g) => g.c === c).sort((a, b) => b.r - a.r);
      let write = ROWS - 1;
      for (const g of col) {
        if (g.r !== write) {
          g.r = write;
          positionGem(g, true);
        }
        write--;
      }
      let spawn = -1;
      while (write >= 0) {
        const g = { id: uid(), type: randomType(), r: write, c, el: null };
        g.el = makeGemEl(g);
        g.el.style.setProperty("--r", spawn);
        board.appendChild(g.el);
        gems.push(g);
        g.el.getBoundingClientRect();
        positionGem(g, true);
        write--;
        spawn--;
      }
    }
    await wait(220);
  }

  async function shuffleBoard(msg) {
    toast(msg || "Камни смущённо меняются местами.");
    await wait(280);
    const types = gems.map((g) => g.type);
    for (let i = types.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [types[i], types[j]] = [types[j], types[i]];
    }
    gems.forEach((g, i) => {
      g.type = types[i];
      g.el.dataset.type = g.type;
      const img = g.el.querySelector("img.gem-art");
      if (img) { img.src = GEM_IMG[g.type]; img.alt = TYPE[g.type].name; }
    });
    const grid = gridTypes();
    if (findMatches(grid).size || !hasMove(grid)) {
      mountBoard(buildInitialBoard());
    }
    await wait(120);
  }

  /* ---------- combat ---------- */
  function startBattle() {
    const def = ENEMIES[S.floor];
    S.enemy = {
      id: def.id,
      name: def.name,
      where: def.where,
      hp: def.maxHp,
      maxHp: def.maxHp,
      atk: def.atk,
      portrait: def.portrait,
      taunts: def.taunts,
      isBoss: !!def.isBoss,
      intent: def.intent,
      act: def.act,
      frail: 0,
      weaken: 0,
      turnCount: 0
    };
    S.hero.shield = 0;
    S.hero.firstHitPending = hasRelic("countCape");
    if (hasRelic("eveningPerfume")) {
      for (const t of TYPE_IDS) addMana(t, 2);
    }
    S.turn = "player";
    S.over = false;
    swappedThisTurn = false;
    mountBoard(buildInitialBoard());
    setPortrait($("enemy-figure"), def.portrait, "figure");
    setPortrait($("hero-portrait"), "hero", "bust");
    $("enemy-stage").classList.toggle("boss", !!def.isBoss);
    $("hero-name").textContent = S.hero.name;
    $("enemy-name").textContent = def.name;
    $("battle-where").textContent = def.where;
    $("battle-floor").textContent = (def.isBoss ? "Босс · " : "") + "Бой " + (S.floor + 1) + " из 4";
    $("enemy-taunt").textContent = pick(def.taunts);
    if (S.tutorial) $("tutorial").classList.add("show");
    else $("tutorial").classList.remove("show");
    showScreen("battle");
    sizeBoard();
    renderChrome();
    maybeRipeCharm();
    if (def.isBoss) burstFX($("enemy-figure"), 8);
  }

  function maybeRipeCharm() {
    if (hasRelic("ripeCharm") && S.hero.hp > 0 && S.hero.hp < S.hero.maxHp) {
      healHero(2);
    }
  }

  function addMana(type, n) {
    S.hero.mana[type] = clamp((S.hero.mana[type] || 0) + n, 0, MANA_MAX);
  }

  function addShield(n) {
    if (!n) return;
    S.hero.shield = (S.hero.shield || 0) + n;
    SFX.play("shield");
    renderChrome();
  }

  function healHero(n) {
    const before = S.hero.hp;
    S.hero.hp = clamp(S.hero.hp + n, 0, S.hero.maxHp);
    const gained = S.hero.hp - before;
    if (gained > 0) {
      flash($("hero-card"));
      floatOn($("hero-card"), "+" + gained, "heal");
      SFX.play("heal");
    }
    renderChrome();
  }

  function damageEnemy(n, line, kind) {
    if (S.over || !S.enemy) return;
    let dmg = Math.max(0, Math.round(n));
    S.enemy.hp = clamp(S.enemy.hp - dmg, 0, S.enemy.maxHp);
    flash($("enemy-stage"));
    playHitOnEnemy(kind || "passion", dmg ? ("−" + dmg) : "");
    if (dmg > 0) SFX.play("hit");
    if (dmg >= 12) shake(dmg >= 18);
    if (line) $("enemy-taunt").textContent = line;
    renderChrome();
    if (S.enemy.hp <= 0) onEnemyDown();
  }

  function enemyStrike(raw, taunt) {
    if (S.over) return;
    let dmg = raw;
    if (S.enemy.frail) { dmg = Math.round(dmg * (100 - S.enemy.frail) / 100); S.enemy.frail = 0; }
    if (S.enemy.weaken) { dmg = Math.max(0, dmg - S.enemy.weaken); S.enemy.weaken = 0; }
    if (S.hero.firstHitPending) { dmg = Math.round(dmg / 2); S.hero.firstHitPending = false; }
    if (taunt) $("enemy-taunt").textContent = taunt;
    let rest = dmg;
    let blocked = 0;
    if (S.hero.shield > 0) {
      blocked = Math.min(S.hero.shield, rest);
      S.hero.shield -= blocked;
      rest -= blocked;
    }
    S.hero.hp = clamp(S.hero.hp - rest, 0, S.hero.maxHp);
    SFX.play("attack");
    if (blocked > 0) SFX.play("shield");
    if (rest > 0) floatOn($("hero-card"), "−" + rest, "");
    if (raw >= 10) shake(raw >= 16);
    playEnemyAttack();
    flash($("hero-card"));
    wigglePortrait($("hero-portrait"), "hit");
    burstFX($("hero-portrait"), 4, ["💥", "♥"]);
    if (rest > 0 && Math.random() < 0.45) toast(pick(HERO_HIT_LINES));
    renderChrome();
    if (S.hero.hp <= 0) onHeroDown();
  }

  function stealMostMana(n) {
    let best = TYPE_IDS[0], v = -1;
    for (const t of TYPE_IDS) if ((S.hero.mana[t] || 0) > v) { v = S.hero.mana[t]; best = t; }
    S.hero.mana[best] = clamp((S.hero.mana[best] || 0) - n, 0, MANA_MAX);
  }

  function canAfford(cost) {
    return Object.entries(cost).every(([t, n]) => (S.hero.mana[t] || 0) >= n);
  }

  function payCost(cost) {
    for (const [t, n] of Object.entries(cost)) S.hero.mana[t] -= n;
  }

  function heroFlirt(line) {
    const p = $("hero-portrait");
    wigglePortrait(p, "flirt");
    burstFX(p, 7);
    const text = line || pick(HERO_CAST_LINES);
    $("hero-status").textContent = "😉";
    toast(text);
  }

  function wigglePortrait(el, cls) {
    if (!el) return;
    el.classList.remove("flirt", "hit");
    void el.offsetWidth;
    el.classList.add(cls);
    window.setTimeout(() => el.classList.remove(cls), 520);
  }

  function burstFX(el, n, customBits) {
    const layer = $("fx-layer");
    if (!layer) return;
    const bits = customBits && customBits.length ? customBits : ["♥", "♥", "♡", "💋", "✦", "♥"];
    let x = window.innerWidth / 2, y = window.innerHeight / 3;
    if (el && el.getBoundingClientRect) {
      const r = el.getBoundingClientRect();
      if (r.width) { x = r.left + r.width / 2; y = r.top + r.height / 2; }
    }
    for (let i = 0; i < (n || 6); i++) {
      const bit = document.createElement("div");
      bit.className = "fx-bit";
      bit.textContent = bits[i % bits.length];
      const ang = Math.random() * Math.PI * 2;
      const dist = 28 + Math.random() * 46;
      bit.style.left = x + "px";
      bit.style.top = y + "px";
      bit.style.setProperty("--dx", Math.cos(ang) * dist + "px");
      bit.style.setProperty("--dy", (Math.sin(ang) * dist - 24) + "px");
      bit.style.setProperty("--rot", (Math.random() * 50 - 25) + "deg");
      bit.style.fontSize = (14 + Math.random() * 10) + "px";
      layer.appendChild(bit);
      window.setTimeout(() => bit.remove(), 820);
    }
  }

  function burstParticles(list, type) {
    const board = $("board");
    const layer = $("floaters");
    if (!board || !layer || !list || !list.length) return;
    const br = board.getBoundingClientRect();
    const color = GEM_COLOR[type] || "#fff4d0";
    let spawned = 0;
    for (const g of list) {
      if (!g.el || spawned >= 16) break;
      const gr = g.el.getBoundingClientRect();
      const cx = gr.left + gr.width / 2 - br.left;
      const cy = gr.top + gr.height / 2 - br.top;
      for (let i = 0; i < 4 && spawned < 16; i++, spawned++) {
        const p = document.createElement("i");
        p.className = "particle";
        p.style.left = cx + "px";
        p.style.top = cy + "px";
        p.style.background = color;
        const ang = Math.random() * Math.PI * 2;
        const dist = 12 + Math.random() * 20;
        p.style.setProperty("--dx", (Math.cos(ang) * dist) + "px");
        p.style.setProperty("--dy", (Math.sin(ang) * dist) + "px");
        layer.appendChild(p);
        window.setTimeout(() => p.remove(), 480);
      }
    }
  }

  function shake(strong) {
    const app = $("app");
    if (!app) return;
    app.classList.remove("shake", "shake-big");
    void app.offsetWidth;
    app.classList.add(strong ? "shake-big" : "shake");
    window.setTimeout(() => app.classList.remove("shake", "shake-big"), 340);
  }

  function spellFlash(color) {
    const layer = $("fx-layer");
    if (!layer) return;
    const el = document.createElement("div");
    el.className = "spell-veil";
    el.style.background = "radial-gradient(circle at 50% 42%, " + color + "99, transparent 62%)";
    layer.appendChild(el);
    window.setTimeout(() => el.remove(), 320);
  }

  function floatOn(el, text, cls) {
    if (!el) return;
    const d = document.createElement("div");
    d.className = "dmg-float" + (cls ? " " + cls : "");
    d.textContent = text;
    el.appendChild(d);
    window.setTimeout(() => d.remove(), 820);
  }


  function playHitOnEnemy(kind, dmgText) {
    const fig = $("enemy-figure");
    const layer = $("enemy-fx");
    if (!fig || !layer) return;
    fig.classList.remove("recoil", "lunge");
    void fig.offsetWidth;
    fig.classList.add("recoil");
    window.setTimeout(() => fig.classList.remove("recoil"), 430);

    const flash = document.createElement("div");
    flash.className = "fx-flash " + ({
      passion: "red", dew: "blue", sap: "gold", amber: "gold", temptation: "violet", kiss: "red"
    }[kind] || "red");
    layer.appendChild(flash);
    window.setTimeout(() => flash.remove(), 420);

    if (kind === "passion" || kind === "kiss") {
      const slash = document.createElement("div");
      slash.className = "fx-slash";
      layer.appendChild(slash);
      window.setTimeout(() => slash.remove(), 400);
    }
    const marks = {
      passion: ["♥", "🔥", "♥"],
      kiss: ["💋", "♥", "💋"],
      temptation: ["💋", "♡", "✦"],
      amber: ["✦", "✧", "✦"],
      dew: ["✦", "💧"],
      sap: ["✦", "✨"]
    }[kind] || ["♥"];
    const rect = fig.getBoundingClientRect();
    for (let i = 0; i < marks.length + 2; i++) {
      const el = document.createElement("div");
      el.className = kind === "kiss" || kind === "temptation" ? "fx-kiss" : "fx-spark";
      el.textContent = marks[i % marks.length];
      el.style.left = (20 + Math.random() * 60) + "%";
      el.style.top = (20 + Math.random() * 50) + "%";
      layer.appendChild(el);
      window.setTimeout(() => el.remove(), 720);
    }
    if (dmgText) {
      const d = document.createElement("div");
      d.className = "dmg-float";
      d.textContent = dmgText;
      layer.appendChild(d);
      window.setTimeout(() => d.remove(), 820);
    }
    burstFX(fig, 7, marks);
  }

  function playHealOnHero(text) {
    const dock = $("hero-card");
    if (!dock) return;
    flash(dock);
    burstFX($("hero-portrait") || dock, 5, ["✦", "✨", "♥"]);
  }

  function playEnemyAttack() {
    const fig = $("enemy-figure");
    const dock = $("hero-card");
    const layer = $("enemy-fx");
    if (fig) {
      fig.classList.remove("recoil", "lunge");
      void fig.offsetWidth;
      fig.classList.add("lunge");
      window.setTimeout(() => fig.classList.remove("lunge"), 500);
    }
    if (layer) {
      const slash = document.createElement("div");
      slash.className = "fx-slash";
      slash.style.top = "62%";
      slash.style.background = "linear-gradient(90deg, transparent, #fff, #ff8ab0, transparent)";
      layer.appendChild(slash);
      window.setTimeout(() => slash.remove(), 400);
    }
    if (dock) {
      dock.classList.remove("hit");
      void dock.offsetWidth;
      dock.classList.add("hit");
      window.setTimeout(() => dock.classList.remove("hit"), 400);
    }
  }

  function castSpell(id) {
    if (busy || S.turn !== "player" || S.over) return;
    const spell = SPELLS[id];
    if (!spell) return;
    if (!canAfford(spell.cost)) {
      toast("Маны маловато — собери ещё камней нужного цвета, красавчик.");
      return;
    }
    payCost(spell.cost);
    const primary = Object.keys(spell.cost)[0];
    SFX.play("spell", { type: primary });
    spellFlash(GEM_COLOR[primary] || "#ffd76a");
    heroFlirt(pick(HERO_CAST_LINES));
    spell.cast(S);
    renderChrome();
  }

  async function endTurn() {
    if (busy || S.turn !== "player" || S.over) return;
    busy = true;
    $("btn-end").classList.remove("waiting");
    S.turn = "enemy";
    renderChrome();
    await wait(280);
    if (!S.over) {
      const def = ENEMIES[S.floor];
      def.act.call(def, S);
      renderChrome();
    }
    await wait(380);
    if (S.over) { busy = false; return; }
    S.turn = "player";
    swappedThisTurn = false;
    maybeRipeCharm();
    renderChrome();
    busy = false;
  }

  function onEnemyDown() {
    if (S.over) return;
    S.over = true;
    burstFX($("enemy-figure"), 10);
    $("enemy-taunt").textContent = S.enemy.isBoss
      ? "Какая острота… ещё встретимся, Чак. В более удобной позе."
      : "Хорошо, ты умеешь ухаживать. Ступай дальше, не без сожаления…";
    window.setTimeout(() => {
      if (S.floor >= ENEMIES.length - 1) showEnd(true);
      else showRewards();
    }, 700);
  }

  function onHeroDown() {
    if (S.over) return;
    S.over = true;
    $("enemy-taunt").textContent = "Даже огурчики иногда теряют хруст. Миленько, кстати.";
    window.setTimeout(() => showEnd(false), 800);
  }

  /* ---------- rewards ---------- */
  function showRewards() {
    const miss = S.hero.maxHp - S.hero.hp;
    const rec = Math.max(6, Math.round(miss * 0.32));
    healHero(rec);
    $("reward-sub").textContent = "Здоровье подлечено на " + rec + ". Выберите одну награду — одну, как один поцелуй.";
    const options = rollRewards();
    const box = $("rewards");
    box.innerHTML = "";
    for (const opt of options) {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "reward-card";
      btn.innerHTML = `<span class="kind">${opt.kind}</span><span class="r-name">${opt.name}</span><span class="r-desc">${opt.desc}</span>`;
      btn.addEventListener("click", () => takeReward(opt));
      box.appendChild(btn);
    }
    showScreen("reward");
  }

  function rollRewards() {
    const ownedSpells = new Set(S.hero.spells);
    const ownedRelics = new Set(S.hero.relics);
    const spells = REWARD_SPELLS.filter((id) => !ownedSpells.has(id));
    const relics = REWARD_RELICS.filter((id) => !ownedRelics.has(id));
    const pool = [];
    for (const id of spells) pool.push({ kind: "Заклинание", typ: "spell", id, name: SPELLS[id].name, desc: SPELLS[id].desc });
    for (const id of relics) pool.push({ kind: "Реликвия", typ: "relic", id, name: RELICS[id].name, desc: RELICS[id].desc });
    for (let i = pool.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [pool[i], pool[j]] = [pool[j], pool[i]];
    }
    const picked = pool.slice(0, 3);
    while (picked.length < 3) {
      picked.push({ kind: "Утешение", typ: "heal", id: "heal", name: "Кубок нектара", desc: "Восстанавливает 12 здоровья. Сладко, липко и вовремя." });
    }
    return picked;
  }

  function takeReward(opt) {
    if (opt.typ === "spell") S.hero.spells.push(opt.id);
    else if (opt.typ === "relic") {
      S.hero.relics.push(opt.id);
      if (opt.id === "silkRibbon") {
        S.hero.maxHp += 12;
        S.hero.hp += 12;
      }
    } else if (opt.typ === "heal") {
      healHero(12);
    }
    S.floor += 1;
    startBattle();
  }

  function showEnd(win) {
    setPortrait($("end-portrait"), win ? "melon" : "hero", "figure");
    $("end-portrait").classList.toggle("flirt-idle", true);
    $("end-title").innerHTML = win
      ? 'Сад склонён<em>перед хрустом</em>'
      : 'Хруст смолк<em>на этот раз</em>';
    $("end-flavor").textContent = win
      ? pick(HERO_WIN_LINES) + " Дынька шепчет, что реванш будет ещё слаще — и уже поправляет кружева."
      : "Сад ещё не допит до дна. Чак отряхивается, освежает рассол и готов к новой, не менее пикантной прогулке.";
    SFX.play(win ? "win" : "lose");
    if (win) burstFX($("end-portrait"), 12);
    showScreen("end");
  }

  /* ---------- UI ---------- */
  function showScreen(name) {
    document.querySelectorAll(".screen").forEach((el) => el.classList.remove("active"));
    $("screen-" + name).classList.add("active");
    if (name === "battle") requestAnimationFrame(sizeBoard);
  }

  function renderChrome() {
    if (!S || !S.enemy) return;
    const e = S.enemy, h = S.hero;
    $("enemy-hp-fill").style.transform = "scaleX(" + (e.hp / e.maxHp) + ")";
    $("enemy-hp-label").textContent = e.hp + "/" + e.maxHp;
    const hpRatio = h.hp / h.maxHp;
    $("hero-hp-fill").style.transform = "scaleX(" + hpRatio + ")";
    const shRatio = h.maxHp > 0 ? Math.min(1, (h.hp + h.shield) / h.maxHp) : 0;
    $("hero-shield-fill").style.transform = "scaleX(" + (h.shield > 0 ? shRatio : hpRatio) + ")";
    $("hero-hp-label").textContent = h.shield > 0 ? (h.hp + " + " + h.shield + " щит") : (h.hp + "/" + h.maxHp);
    const def = ENEMIES[S.floor];
    if (def && S.turn === "player" && !S.over) {
      const intent = def.intent.call(def, S);
      $("enemy-intent").textContent = intent.label;
    } else if (S.over) {
      $("enemy-intent").textContent = e.hp <= 0 ? "Побеждена" : "Победа";
    } else {
      $("enemy-intent").textContent = "Ход…";
    }
    if (!$("hero-status").textContent || $("hero-status").textContent === "Ваш ход" || $("hero-status").textContent === "Можно чары") {
      $("hero-status").textContent = S.turn === "player" && !S.over ? (swappedThisTurn ? "Можно чары" : "Ваш ход") : "";
    }

    const row = $("mana-row");
    row.innerHTML = TYPE_IDS.map((t) =>
      `<div class="mana-pip" data-type="${t}" title="${TYPE[t].name}">
        <img src="${GEM_IMG[t]}" alt="${TYPE[t].name}"><div class="n">${h.mana[t] || 0}</div>
      </div>`
    ).join("");

    const box = $("spells");
    const prevScroll = box.scrollLeft;
    box.innerHTML = "";
    for (const id of h.spells) {
      const sp = SPELLS[id];
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "spell";
      const ready = canAfford(sp.cost) && S.turn === "player" && !S.over && !busy;
      if (ready) btn.classList.add("ready");
      else btn.classList.add("locked");
      btn.disabled = !(canAfford(sp.cost) && S.turn === "player" && !S.over);
      btn.innerHTML = `<span class="s-name">${sp.name}</span>
        <span class="s-desc">${sp.desc}</span>
        <span class="s-cost">${costHtml(sp.cost)}</span>`;
      btn.addEventListener("click", () => castSpell(id));
      box.appendChild(btn);
    }
    box.scrollLeft = prevScroll;
    $("btn-end").disabled = S.turn !== "player" || S.over;
  }

  function costHtml(cost) {
    return Object.entries(cost).map(([t, n]) =>
      `<span class="cost-pip" title="${TYPE[t].name}"><img src="${GEM_IMG[t]}" alt="${TYPE[t].name}">${n}</span>`
    ).join("");
  }

  function pulseEndTurn() {
    if (S.turn === "player" && !S.over && swappedThisTurn) $("btn-end").classList.add("waiting");
  }

  function flash(el) {
    el.classList.remove("fx-hit");
    void el.offsetWidth;
    el.classList.add("fx-hit");
  }

  let toastTimer = 0;
  function toast(msg) {
    const el = $("toast");
    if (!el) return;
    el.textContent = msg;
    el.classList.add("show");
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => el.classList.remove("show"), 1700);
  }

  function floatAtGem(g, text, cls) {
    if (!g || !g.el) return;
    const board = $("board");
    const br = board.getBoundingClientRect();
    const gr = g.el.getBoundingClientRect();
    const f = document.createElement("div");
    f.className = "floater " + cls;
    f.textContent = text;
    f.style.left = (gr.left + gr.width / 2 - br.left) + "px";
    f.style.top = (gr.top - br.top) + "px";
    $("floaters").appendChild(f);
    window.setTimeout(() => f.remove(), 720);
  }

  function floatBoard(text, cls) {
    const f = document.createElement("div");
    f.className = "floater " + cls;
    f.textContent = text;
    $("floaters").appendChild(f);
    window.setTimeout(() => f.remove(), 800);
  }

  /* ---------- input ---------- */
  function setSelected(g) {
    if (selected && selected.el) selected.el.classList.remove("selected");
    selected = g;
    if (selected && selected.el) selected.el.classList.add("selected");
  }

  function gemFromEvent(e) {
    const el = e.target && e.target.closest ? e.target.closest(".gem") : null;
    if (!el) return null;
    const id = Number(el.dataset.id);
    return gems.find((g) => g.id === id) || null;
  }

  function gemFromPoint(x, y) {
    const el = document.elementFromPoint(x, y);
    const gemEl = el && el.closest ? el.closest(".gem") : null;
    if (!gemEl) return null;
    const id = Number(gemEl.dataset.id);
    return gems.find((g) => g.id === id) || null;
  }

  function onPointerDown(e) {
    if (busy || S.turn !== "player" || S.over) return;
    if (e.pointerType === "mouse" && e.button !== 0) return;
    const g = gemFromEvent(e);
    if (!g) return;
    e.preventDefault();
    try { g.el.setPointerCapture(e.pointerId); } catch (_) {}
    drag = { start: g, from: g, pointerId: e.pointerId };
    if (selected && selected !== g) {
      const other = selected;
      if (Math.abs(other.r - g.r) + Math.abs(other.c - g.c) === 1) {
        drag = null;
        trySwap(other, g);
        return;
      }
    }
    setSelected(g);
  }

  function onPointerMove(e) {
    if (!drag || drag.pointerId !== e.pointerId) return;
    e.preventDefault();
    const g = gemFromPoint(e.clientX, e.clientY);
    if (g && g !== drag.start) {
      if (Math.abs(g.r - drag.start.r) + Math.abs(g.c - drag.start.c) === 1) {
        drag.target = g;
      }
    }
  }

  function onPointerUp(e) {
    if (!drag || drag.pointerId !== e.pointerId) return;
    e.preventDefault();
    const start = drag.start;
    const target = drag.target || gemFromPoint(e.clientX, e.clientY);
    drag = null;
    if (target && target !== start && Math.abs(target.r - start.r) + Math.abs(target.c - start.c) === 1) {
      trySwap(start, target);
    }
  }

  function sizeBoard() {
    const sizer = $("board-sizer");
    const board = $("board");
    if (!sizer || !board || !$("screen-battle").classList.contains("active")) return;
    board.style.width = "0px";
    board.style.height = "0px";
    const w = sizer.clientWidth;
    const h = sizer.clientHeight;
    const side = Math.max(0, Math.floor(Math.min(w, h)));
    board.style.width = side + "px";
    board.style.height = side + "px";
  }

  function preventGestures() {
    const stop = (e) => { e.preventDefault(); };
    document.addEventListener("gesturestart", stop, { passive: false });
    document.addEventListener("gesturechange", stop, { passive: false });
    document.addEventListener("gestureend", stop, { passive: false });
    document.addEventListener("touchmove", (e) => {
      if (e.touches && e.touches.length > 1) e.preventDefault();
      const t = e.target;
      if (t && t.closest && (t.closest("#board") || t.closest(".board-wrap") || t.closest(".board-sizer"))) {
        e.preventDefault();
      }
    }, { passive: false });
    document.addEventListener("dblclick", (e) => e.preventDefault(), { passive: false });
    document.addEventListener("touchstart", (e) => {
      if (e.touches && e.touches.length > 1) e.preventDefault();
    }, { passive: false });
  }

  /* ---------- age gate & boot ---------- */
  function showAgeExit() {
    $("age-actions").hidden = true;
    $("age-exit").hidden = false;
    $("age-question").hidden = true;
  }

  function showAgeAsk() {
    $("age-actions").hidden = false;
    $("age-exit").hidden = true;
    $("age-question").hidden = false;
  }

  function applyAge(val) {
    try { localStorage.setItem(AGE_KEY, val); } catch (_) {}
    if (val === "yes") {
      showScreen("title");
    } else {
      showAgeExit();
      showScreen("age");
    }
  }

  function startRun() {
    S = newRun();
    startBattle();
  }

  function startFightForShot(floor) {
    try { localStorage.setItem(AGE_KEY, "yes"); } catch (_) {}
    S = newRun();
    S.floor = floor || 0;
    S.tutorial = false;
    S.hero.mana.passion = 5;
    S.hero.mana.dew = 3;
    S.hero.mana.sap = 3;
    startBattle();
  }
  function startBossForShot() { startFightForShot(3); }

  function bind() {
    setPortrait($("age-portrait"), "hero", "figure");
    setPortrait($("title-portrait"), "hero", "figure");
    SFX.setMuted(SFX.isMuted());

    $("btn-mute").addEventListener("click", (e) => {
      e.stopPropagation();
      SFX.toggle();
    });
    document.addEventListener("pointerdown", () => SFX.unlock(), { passive: true });
    document.addEventListener("keydown", () => SFX.unlock());
    document.addEventListener("click", (e) => {
      const b = e.target && e.target.closest ? e.target.closest("button") : null;
      if (!b || b.id === "btn-mute" || b.classList.contains("spell")) return;
      SFX.play("click");
    });

    $("btn-age-yes").addEventListener("click", () => applyAge("yes"));
    $("btn-age-no").addEventListener("click", () => applyAge("no"));
    $("btn-age-back").addEventListener("click", () => {
      try { localStorage.removeItem(AGE_KEY); } catch (_) {}
      showAgeAsk();
      showScreen("age");
    });
    $("btn-start").addEventListener("click", startRun);
    $("btn-again").addEventListener("click", startRun);
    $("btn-end").addEventListener("click", endTurn);
    $("btn-tutorial").addEventListener("click", () => {
      S.tutorial = false;
      $("tutorial").classList.remove("show");
      sizeBoard();
    });
    document.addEventListener("pointermove", onPointerMove);
    document.addEventListener("pointerup", onPointerUp);
    document.addEventListener("pointercancel", onPointerUp);
    window.addEventListener("resize", sizeBoard);
    window.addEventListener("orientationchange", () => setTimeout(sizeBoard, 120));
    if (window.visualViewport) visualViewport.addEventListener("resize", sizeBoard);
    preventGestures();

    let saved = null;
    try { saved = localStorage.getItem(AGE_KEY); } catch (_) {}
    if (saved === "yes") showScreen("title");
    else if (saved === "no") showAgeExit();
    else showScreen("age");
  }

  window.__qa = {
    acceptAge() { applyAge("yes"); },
    declineAge() { applyAge("no"); },
    startBoss: startBossForShot,
    startFight: startFightForShot,
    startRun,
    giveAllSpells() {
      if (!S) return;
      S.hero.spells = Object.keys(SPELLS);
      renderChrome();
    },
    boardBox() {
      const b = $("board").getBoundingClientRect();
      return { w: Math.round(b.width), h: Math.round(b.height) };
    },
    spellBoxes() {
      const app = $("app").getBoundingClientRect();
      return [...document.querySelectorAll("#spells .spell")].map((el) => {
        const r = el.getBoundingClientRect();
        return {
          name: (el.querySelector(".s-name") || {}).textContent || "",
          w: Math.round(r.width),
          h: Math.round(r.height),
          inside: r.width >= 44 && r.height >= 44 &&
            r.left >= app.left - 1 && r.top >= app.top - 1 &&
            r.right <= app.right + 1 && r.bottom <= app.bottom + 1
        };
      });
    },
    sounds() {
      const names = ["swap", "bad", "match", "spell", "hit", "attack", "shield", "heal", "win", "lose", "click"];
      const errors = [];
      for (const n of names) {
        try { SFX.play(n, { combo: 4, type: "sap" }); }
        catch (e) { errors.push(String(e && e.message || e)); }
      }
      return errors;
    },
    tutorialOpen() { return $("tutorial").classList.contains("show"); }
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", bind);
  else bind();
})();
