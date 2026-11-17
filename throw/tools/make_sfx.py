#!/usr/bin/env python3
"""Синтез коротких звуков для «Бросай и лови». Чужих сэмплов нет."""

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
            sample = 1.0 if math.sin(phase) >= 0 else -1.0
        elif kind == "tri":
            sample = 2.0 * abs(2.0 * ((t * freq) % 1.0) - 1.0) - 1.0
        elif kind == "slide":
            sample = math.sin(2 * math.pi * (freq + freq * t) * t)
        else:
            sample = math.sin(phase)
        out.append(sample * e * vol)
    return out


def noise(dur: float, vol: float = 0.2, release: float = 0.3, seed: int = 7) -> list[float]:
    rng = random.Random(seed)
    n = int(dur * RATE)
    out = []
    for i in range(n):
        out.append(rng.uniform(-1.0, 1.0) * env(i, n, 0.005, release) * vol)
    return out


def mix(*tracks: list[float]) -> list[float]:
    length = max(len(track) for track in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, sample in enumerate(track):
            out[i] += sample
    peak = max(1e-6, max(abs(sample) for sample in out))
    if peak > 0.9:
        out = [sample * (0.9 / peak) for sample in out]
    return out


def concat(*tracks: list[float]) -> list[float]:
    out: list[float] = []
    for track in tracks:
        out.extend(track)
    return out


def write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(sample * 32767))))
            for sample in samples
        )
        handle.writeframes(frames)


def main() -> None:
    write("tap.wav", tone(620, 0.05, 0.22, "sine", 0.4))
    write(
        "throw.wav",
        mix(
            noise(0.28, 0.2, 0.72, 3),
            tone(280, 0.22, 0.16, "slide", 0.7),
        ),
    )
    write(
        "catch.wav",
        concat(
            tone(523.25, 0.08, 0.26, "sine", 0.3),
            tone(784, 0.12, 0.22, "sine", 0.4),
        ),
    )
    write("miss.wav", tone(164, 0.16, 0.22, "tri", 0.55))
    write(
        "coin.wav",
        concat(
            tone(880, 0.07, 0.2, "sine", 0.3),
            tone(1320, 0.12, 0.18, "sine", 0.45),
        ),
    )
    write(
        "unlock.wav",
        concat(
            tone(392, 0.09, 0.2, "sine", 0.3),
            tone(523.25, 0.09, 0.2, "sine", 0.3),
            tone(659.25, 0.16, 0.22, "sine", 0.45),
        ),
    )


if __name__ == "__main__":
    main()
