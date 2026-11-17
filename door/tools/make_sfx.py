#!/usr/bin/env python3
"""Синтез коротких звуков для «Откроешь дверь?». Никаких чужих сэмплов."""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "audio"


def env(i: int, n: int, attack: float = 0.01, release: float = 0.2) -> float:
    if n <= 1:
        return 0.0
    t = i / (n - 1)
    if t < attack:
        return t / attack
    if t > 1.0 - release:
        return max(0.0, (1.0 - t) / release)
    return 1.0


def silence(dur: float) -> list[float]:
    return [0.0] * int(dur * RATE)


def tone(freq: float, dur: float, vol: float = 0.3, kind: str = "sine", release: float = 0.25) -> list[float]:
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        e = env(i, n, 0.01, release)
        phase = 2 * math.pi * freq * t
        if kind == "square":
            s = 1.0 if math.sin(phase) >= 0 else -1.0
        elif kind == "tri":
            s = 2.0 * abs(2.0 * ((t * freq) % 1.0) - 1.0) - 1.0
        else:
            s = math.sin(phase)
        out.append(s * e * vol)
    return out


def noise(dur: float, vol: float = 0.2, release: float = 0.3) -> list[float]:
    rng = random.Random(7)
    n = int(dur * RATE)
    out = []
    for i in range(n):
        out.append(rng.uniform(-1.0, 1.0) * env(i, n, 0.005, release) * vol)
    return out


def mix(*tracks: list[float]) -> list[float]:
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, s in enumerate(track):
            out[i] += s
    peak = max(1e-6, max(abs(s) for s in out))
    if peak > 0.95:
        scale = 0.95 / peak
        out = [s * scale for s in out]
    return out


def concat(*tracks: list[float]) -> list[float]:
    out: list[float] = []
    for track in tracks:
        out.extend(track)
    return out


def write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with wave.open(str(path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        handle.writeframes(frames)


def main() -> None:
    write("tap.wav", noise(0.045, 0.22, 0.55))
    write(
        "knock.wav",
        concat(
            mix(noise(0.07, 0.45, 0.6), tone(90, 0.09, 0.35, "sine", 0.7)),
            silence(0.09),
            mix(noise(0.08, 0.4, 0.65), tone(70, 0.11, 0.3, "sine", 0.75)),
        ),
    )
    write(
        "good.wav",
        concat(
            tone(523.25, 0.11, 0.28, "sine", 0.35),
            tone(783.99, 0.16, 0.24, "sine", 0.45),
        ),
    )
    write(
        "bad.wav",
        mix(
            tone(98, 0.38, 0.34, "tri", 0.55),
            tone(123, 0.38, 0.18, "sine", 0.6),
            noise(0.2, 0.12, 0.7),
        ),
    )
    write(
        "death.wav",
        concat(
            tone(440, 0.16, 0.28, "tri", 0.4),
            tone(349.2, 0.16, 0.26, "tri", 0.4),
            tone(261.6, 0.18, 0.26, "tri", 0.45),
            mix(tone(174.6, 0.42, 0.32, "sine", 0.6), tone(185, 0.42, 0.12, "sine", 0.6)),
        ),
    )
    write(
        "win.wav",
        concat(
            tone(392, 0.12, 0.22, "sine", 0.3),
            tone(523.25, 0.12, 0.22, "sine", 0.3),
            tone(659.25, 0.12, 0.22, "sine", 0.3),
            tone(783.99, 0.28, 0.24, "sine", 0.5),
        ),
    )
    write("whoosh.wav", noise(0.22, 0.16, 0.75))


if __name__ == "__main__":
    main()
