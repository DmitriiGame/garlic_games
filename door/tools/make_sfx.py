#!/usr/bin/env python3
"""Мягкие звуки для «Откроешь дверь?».

Все сэмплы синтезированы здесь, без чужих записей, и отдаются как CC0.
На выходе моно OGG, 22050 Гц, с плавным появлением и затуханием.
"""

import math
import random
import struct
import subprocess
import wave
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parent.parent / "audio"
RNG = random.Random(17)


def env(i: int, n: int, attack: float, release: float) -> float:
    if n <= 1:
        return 0.0
    t = i / (n - 1)
    if t < attack:
        return t / max(attack, 1e-6)
    if t > 1.0 - release:
        return max(0.0, (1.0 - t) / max(release, 1e-6))
    return 1.0


def fade(samples: list[float], inn: float = 0.02, out: float = 0.08) -> list[float]:
    n = len(samples)
    a = min(n, int(inn * RATE))
    b = min(n, int(out * RATE))
    for i in range(a):
        samples[i] *= i / max(a, 1)
    for i in range(b):
        samples[n - 1 - i] *= i / max(b, 1)
    return samples


def normalize(samples: list[float], peak: float = 0.28) -> list[float]:
    loud = max((abs(s) for s in samples), default=1.0)
    if loud < 1e-6:
        return samples
    gain = peak / loud
    return [max(-0.9, min(0.9, s * gain)) for s in samples]


def silence(dur: float) -> list[float]:
    return [0.0] * int(dur * RATE)


def tone(freq: float, dur: float, vol: float = 0.2, kind: str = "sine") -> list[float]:
    n = max(1, int(dur * RATE))
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.08, 0.28)
        phase = 2 * math.pi * freq * t
        if kind == "sine":
            s = math.sin(phase)
        else:
            s = math.sin(phase) + 0.25 * math.sin(phase * 2)
            s /= 1.25
        out.append(s * e * vol)
    return out


def sweep(f0: float, f1: float, dur: float, vol: float = 0.2) -> list[float]:
    n = max(1, int(dur * RATE))
    out = []
    phase = 0.0
    for i in range(n):
        k = i / max(n - 1, 1)
        freq = f0 + (f1 - f0) * k
        phase += 2 * math.pi * freq / RATE
        e = env(i, n, 0.12, 0.35)
        out.append(math.sin(phase) * e * vol)
    return out


def noise(dur: float, vol: float = 0.1, seed: int = 1) -> list[float]:
    rng = random.Random(seed)
    n = max(1, int(dur * RATE))
    out = []
    prev = 0.0
    for i in range(n):
        white = rng.uniform(-1.0, 1.0)
        prev = prev * 0.85 + white * 0.15
        out.append(prev * env(i, n, 0.1, 0.3) * vol)
    return out


def mix(*tracks: list[float]) -> list[float]:
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, sample in enumerate(track):
            out[i] += sample
    return out


def concat(*tracks: list[float]) -> list[float]:
    out: list[float] = []
    for track in tracks:
        out.extend(track)
    return out


def write_ogg(rel: str, samples: list[float], peak: float = 0.26) -> None:
    samples = fade(normalize(samples, peak), 0.018, 0.09)
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    wav_path = path.with_suffix(".wav")
    with wave.open(str(wav_path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        handle.writeframes(frames)
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error",
            "-i", str(wav_path),
            "-c:a", "libvorbis", "-q:a", "2",
            "-ac", "1", "-ar", str(RATE),
            str(path),
        ],
        check=True,
    )
    wav_path.unlink()


def paper() -> list[float]:
    return noise(0.28, 0.12, 3)


def pen() -> list[float]:
    return mix(noise(0.12, 0.08, 9), tone(880, 0.07, 0.04))


def tap() -> list[float]:
    return mix(tone(220, 0.06, 0.12), noise(0.05, 0.05, 4))


def good() -> list[float]:
    return concat(tone(523, 0.12, 0.16), tone(659, 0.18, 0.14))


def bad() -> list[float]:
    return mix(sweep(240, 180, 0.42, 0.16), tone(190, 0.42, 0.05))


def death() -> list[float]:
    return concat(
        tone(392, 0.18, 0.12),
        tone(330, 0.2, 0.11),
        tone(262, 0.36, 0.1),
    )


def win() -> list[float]:
    return concat(
        tone(392, 0.12, 0.12),
        tone(494, 0.12, 0.12),
        tone(587, 0.28, 0.13),
    )


def knock() -> list[float]:
    hit = mix(tone(130, 0.09, 0.2), noise(0.04, 0.04, 2))
    return concat(hit, silence(0.12), hit)


def bark() -> list[float]:
    one = mix(sweep(340, 160, 0.13, 0.2), noise(0.08, 0.05, 6))
    return concat(one, silence(0.1), one)


def drip() -> list[float]:
    drop = mix(tone(740, 0.08, 0.1), tone(370, 0.16, 0.06))
    creak = sweep(180, 260, 0.35, 0.05)
    return concat(drop, silence(0.16), drop, silence(0.08), creak)


def rustle() -> list[float]:
    return noise(0.35, 0.1, 11)


def creak_open() -> list[float]:
    return sweep(210, 420, 0.55, 0.1)


def steps(seed: int, count: int, gap: float, pitch: float) -> list[float]:
    step = mix(tone(pitch, 0.06, 0.12), noise(0.04, 0.04, seed))
    parts = []
    for i in range(count):
        parts.append(step)
        if i != count - 1:
            parts.append(silence(gap))
    return concat(*parts)


def radio() -> list[float]:
    hiss = noise(0.7, 0.08, 21)
    blip = concat(silence(0.18), tone(980, 0.05, 0.05), silence(0.12), tone(760, 0.04, 0.04))
    return mix(hiss, blip)


def wind() -> list[float]:
    return noise(0.9, 0.09, 31)


def glass() -> list[float]:
    return mix(noise(0.55, 0.06, 33), tone(1560, 0.2, 0.03))


def bell() -> list[float]:
    return mix(tone(1320, 0.45, 0.1), tone(1980, 0.3, 0.04))


def choir() -> list[float]:
    return mix(
        tone(196, 1.1, 0.08),
        tone(247, 1.1, 0.06),
        tone(294, 1.1, 0.05),
    )


def radio_steps() -> list[float]:
    return concat(steps(8, 2, 0.16, 140), silence(0.05), tone(640, 0.08, 0.06))


def moan() -> list[float]:
    return mix(sweep(150, 120, 0.7, 0.1), tone(90, 0.7, 0.05))


def crickets() -> list[float]:
    chirp = tone(3200, 0.04, 0.05)
    return concat(chirp, silence(0.12), chirp, silence(0.2), chirp)


def main() -> None:
    files = {
        "ui/tap.ogg": tap(),
        "ui/pen.ogg": pen(),
        "ui/page.ogg": paper(),
        "ui/good.ogg": good(),
        "ui/bad.ogg": bad(),
        "ui/death.ogg": death(),
        "ui/win.ogg": win(),
        "scenes/door.ogg": knock(),
        "scenes/dog.ogg": bark(),
        "scenes/basement.ogg": drip(),
        "scenes/food.ogg": rustle(),
        "scenes/letter.ogg": paper(),
        "scenes/open.ogg": creak_open(),
        "scenes/stranger.ogg": steps(5, 3, 0.14, 150),
        "scenes/radio.ogg": radio(),
        "scenes/street.ogg": wind(),
        "scenes/window.ogg": glass(),
        "scenes/kid.ogg": steps(12, 3, 0.11, 240),
        "scenes/mirror.ogg": bell(),
        "scenes/cult.ogg": choir(),
        "scenes/soldier.ogg": radio_steps(),
        "scenes/horde.ogg": moan(),
        "scenes/quiet.ogg": crickets(),
    }
    total = 0
    for name, samples in files.items():
        write_ogg(name, samples)
        size = (ROOT / name).stat().st_size
        total += size
        print(f"{name:22} {size / 1024:6.1f} KB")
    print(f"total {total / 1024:.1f} KB")


if __name__ == "__main__":
    main()
