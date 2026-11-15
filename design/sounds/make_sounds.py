"""拼拼樂工坊: every sound in the app, made here from sine waves and noise: nothing recorded, nothing
downloaded, every tune written for this app.

- Music (WAV, 16,000 Hz, seamless loops of 12 to 20 s): a xylophone-and-ukulele tune for the
  workshop; one for each jigsaw box (fruit bouncy, animals with a soft flute, the night market busy with
  claps, the rides with a train's chug, the temple fair with a little drum and gong, the city brisk);
  a kalimba for the shape box and the tangram, a plucky one for the pattern blocks; a lullaby for the
  rest.
- Short sounds (WAV, 22,050 Hz): the wooden pieces (picked up 「啵」, near its place 「叮」, pulled in
  「咻—咔」, floating back 「咻」, turned 「喀」, flipped 「啪啦」, dropped into the shape box 「咚」), the
  game's (done, the Taiwan piece, a box opened, night), each picture's own sound (the MRT's 「叮咚」, the
  garbage truck's tune, the 叭噗 horn, a little drum, a bird…) and each helper's (甲甲 sniffs, 石石
  mews, 熊熊 hums, 藍藍 chirps, 花花 calls, 猴猴 hoots). No firecrackers, sirens or thunder.
- Every random choice uses a fixed seed (from the sound's name), so each run writes the same files.

    python3 design/sounds/make_sounds.py              # writes app/assets/sounds/*.wav
    python3 design/sounds/make_sounds.py tap snap     # only these
    python3 design/sounds/make_sounds.py preview OUT.m4a   # all of them in a row (needs ffmpeg)
"""
import pathlib
import subprocess
import sys
import tempfile
import wave
import zlib

import numpy as np
from scipy.signal import lfilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "app" / "assets" / "sounds"
SR = 22050
LOOP_SR = 16000
LIMIT = 8_000_000       # bytes, the whole folder

NOTE = {f"{n}{o}": 440 * 2 ** ((k - 9) / 12 + o - 4) for o in range(1, 9) for k, n in enumerate("C C# D D# E F F# G G# A A# B".split())}
for _o in range(1, 9):
    for _f, _s in (("Db", "C#"), ("Eb", "D#"), ("Gb", "F#"), ("Ab", "G#"), ("Bb", "A#")):
        NOTE[f"{_f}{_o}"] = NOTE[f"{_s}{_o}"]


# ---------------------------------------------------------------- helpers
def rng(name):
    return np.random.default_rng(zlib.crc32(name.encode()))


def t_of(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env(n, attack=.005, release=.05, sr=SR):
    e = np.ones(n)
    a, r = max(1, min(n, int(attack * sr))), max(1, min(n, int(release * sr)))
    e[:a] = np.linspace(0, 1, a) ** 2
    e[-r:] *= np.linspace(1, 0, r) ** 2
    return e


def adsr(n, a, d, s, r, sr=SR):
    """Attack, decay to sustain level s, release (seconds)."""
    e = np.full(n, s, float)
    ia, idd, ir = int(a * sr), int(d * sr), int(r * sr)
    ia = max(1, min(ia, n))
    e[:ia] = np.linspace(0, 1, ia)
    j = min(n, ia + idd)
    if j > ia:
        e[ia:j] = np.linspace(1, s, j - ia)
    ir = max(1, min(ir, n))
    e[-ir:] *= np.linspace(1, 0, ir) ** 1.5
    return e


def lowpass(x, cutoff, sr=SR):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    spec *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(spec, len(x))


def bandpass(x, lo, hi, sr=SR):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    spec *= 1 / (1 + (lo / np.maximum(f, 1)) ** 4) / (1 + (f / hi) ** 4)
    return np.fft.irfft(spec, len(x))


def partial(freq, t, sr):
    return np.sin(2 * np.pi * freq * t) if freq < .45 * sr else np.zeros_like(t)


def bell(freq, dur=.8, sr=SR, bright=.6):
    """A soft glockenspiel / music-box note."""
    t = t_of(dur, sr)
    x = (partial(freq, t, sr) * np.exp(-t / (dur * .35))
         + .3 * bright * partial(freq * 2.76, t, sr) * np.exp(-t / (dur * .12))
         + .12 * bright * partial(freq * 5.4, t, sr) * np.exp(-t / (dur * .06)))
    return x * env(len(t), .002, .04, sr)


def kalimba(freq, dur=.9, sr=SR):
    t = t_of(dur, sr)
    x = partial(freq, t, sr) * np.exp(-t / (dur * .3)) + .25 * partial(freq * 3.0, t, sr) * np.exp(-t / .04) + .1 * partial(freq * 5.2, t, sr) * np.exp(-t / .02)
    return x * env(len(t), .003, .05, sr)


def pad(freqs, dur, sr=SR, swell=.6):
    """A soft, slowly swelling chord (a few detuned sines)."""
    t = t_of(dur, sr)
    x = np.zeros_like(t)
    for f in freqs:
        for det in (-.15, .15):
            x += np.sin(2 * np.pi * (f + det) * t) + .25 * partial(2 * f + det, t, sr)
    return x / len(freqs) * adsr(len(t), dur * swell * .5, .1, .9, dur * .45, sr)


def place(total, parts, sr=SR):
    out = np.zeros(int(total * sr))
    for start, sig in parts:
        i = int(start * sr)
        j = min(len(out), i + len(sig))
        if j > i:
            out[i:j] += sig[: j - i]
    return out


def place_loop(total, parts, sr):
    """Like place, but what runs past the end comes back in at the start (a seamless loop)."""
    n = int(total * sr)
    out = np.zeros(n)
    for start, sig in parts:
        i = int(start * sr) % n
        k = 0
        while k < len(sig):
            j = min(n, i + len(sig) - k)
            out[i:j] += sig[k: k + j - i]
            k += j - i
            i = 0
    return out


def resonator(x, freq, bw, sr=SR):
    r = np.exp(-np.pi * bw / sr)
    th = 2 * np.pi * freq / sr
    return lfilter([1 - r], [1, -2 * r * np.cos(th), r * r], x)


def voice(f0, formants, dur, sr=SR, breath=.15, seed="v"):
    """A soft little hum: a buzz whose pitch follows f0 (an array or a number) through formants."""
    n = int(dur * sr)
    f = np.full(n, f0, float) if np.isscalar(f0) else np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(f0)), f0)
    ph = np.cumsum(f) / sr
    buzz = sum(np.sin(2 * np.pi * k * ph) / k ** 1.2 for k in range(1, 14) if True)
    buzz = buzz + breath * rng(seed).standard_normal(n)
    y = sum(g * resonator(buzz, fr, bw, sr) for fr, bw, g in formants)
    return y / max(1e-9, np.abs(y).max())


VOWEL_M = [(300, 90, 1.0), (900, 160, .25), (2300, 220, .08)]      # a closed-mouth "mmm"
VOWEL_U = [(330, 90, 1.0), (850, 140, .3), (2250, 200, .1)]        # "uu"
VOWEL_A = [(750, 110, 1.0), (1200, 130, .6), (2500, 200, .2)]      # "aa"
VOWEL_E = [(450, 100, 1.0), (1900, 160, .4), (2600, 220, .15)]     # "eh"


def noise(n, name):
    return rng(name).standard_normal(n)


def norm(x, peak=.7):
    return x / max(1e-9, np.abs(x).max()) * peak


def fade_edges(x, sr=SR, ms=6):
    k = max(1, int(sr * ms / 1000))
    x = x.copy()
    x[:k] *= np.linspace(0, 1, k)
    x[-k:] *= np.linspace(1, 0, k)
    return x


# ---------------------------------------------------------------- instruments
def xylo(freq, dur=.5, sr=SR):
    """A wooden xylophone / marimba bar: a quick, woody decay."""
    t = t_of(dur, sr)
    x = (partial(freq, t, sr) * np.exp(-t / .16) + .35 * partial(freq * 3.93, t, sr) * np.exp(-t / .035)
         + .1 * partial(freq * 9.2, t, sr) * np.exp(-t / .012))
    return x * env(len(t), .002, .03, sr)


def harmonica(freq, dur=.5, sr=SR):
    """A soft reed: odd and even harmonics, a little vibrato, breathy."""
    t = t_of(dur, sr)
    vib = 1 + .006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / .15, 0, 1)
    ph = np.cumsum(freq * vib) / sr
    x = sum((.9 ** k) / k * np.sin(2 * np.pi * k * ph) for k in range(1, 8) if k * freq < .45 * sr)
    x = lowpass(x + .04 * rng(f"harm{freq:.0f}").standard_normal(len(t)), 2600, sr)
    return x * adsr(len(t), .03, .08, .75, min(.12, dur * .4), sr)


def piano(freq, dur=1.2, sr=SR):
    """A soft piano-like note."""
    t = t_of(dur, sr)
    x = (partial(freq, t, sr) * np.exp(-t / .7) + .4 * partial(freq * 2.001, t, sr) * np.exp(-t / .35)
         + .15 * partial(freq * 3.003, t, sr) * np.exp(-t / .18) + .06 * partial(freq * 4.01, t, sr) * np.exp(-t / .1))
    return x * env(len(t), .004, .08, sr)


def knock(dur, f, name, sr=SR, decay=.02, cut=1400):
    """A dull wooden knock (a toy's click)."""
    t = t_of(dur, sr)
    x = lowpass(noise(len(t), name), cut, sr) * np.exp(-t / decay) * .7 + np.sin(2 * np.pi * f * t) * np.exp(-t / (decay * 1.4))
    return x


def pluck(freq, dur=.8, sr=SR, bright=.5, name="pluck"):
    """A plucked nylon string (a ukulele): Karplus-Strong, softened."""
    n = int(dur * sr)
    period = max(2, int(sr / freq))
    buf = lowpass(rng(f"{name}{freq:.0f}").uniform(-1, 1, period * 4), 2000 + 4000 * bright, sr)[:period]
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = .5 * (buf[i % period] + buf[(i + 1) % period]) * .996
    return out * env(n, .002, .05, sr)


def tom(dur=.35, f=110, sr=SR, name="tom"):
    t = t_of(dur, sr)
    ff = f * (1 + .5 * np.exp(-t / .03))
    return np.sin(2 * np.pi * np.cumsum(ff) / sr) * np.exp(-t / .12) + .2 * lowpass(noise(len(t), name), 800, sr) * np.exp(-t / .03)


def gong(freq=180, dur=1.6, sr=SR):
    t = t_of(dur, sr)
    x = sum(a * partial(freq * r, t, sr) * np.exp(-t / (dur * d)) for r, a, d in [(1, 1, .5), (1.48, .5, .35), (2.31, .35, .25), (2.9, .2, .15)])
    return x * env(len(t), .01, .2, sr)


def sweep(f0, f1, dur, sr=SR, decay=None):
    t = t_of(dur, sr)
    f = np.geomspace(f0, f1, len(t))
    x = np.sin(2 * np.pi * np.cumsum(f) / sr)
    return x * (np.exp(-t / decay) if decay else np.sin(np.pi * t / dur))


# ---------------------------------------------------------------- the wooden pieces
def s_tap():
    t = t_of(.13)
    x = lowpass(noise(len(t), "tap"), 900) * np.exp(-t / .025) * .6 + np.sin(2 * np.pi * 180 * t) * np.exp(-t / .03)
    return norm(x, .5)


def s_pick():
    """Picked up: a small hollow 「啵」."""
    return norm(sweep(380, 900, .12, decay=.035) + .5 * knock(.12, 300, "pick", decay=.015), .5)


def s_near():
    """Near its place: a soft high 「叮」."""
    return norm(bell(NOTE["E7"], .5, bright=.3), .3)


def s_snap():
    """Pulled into its place: a little 「咻」 and wood meeting wood, 「咔」."""
    t = t_of(.14)
    sw = bandpass(noise(len(t), "snap"), 1200, 3800) * np.sin(np.pi * t / .14) ** 2 * .35
    return norm(place(.4, [(0, sw), (.11, knock(.2, 420, "snap2", decay=.016, cut=2600)), (.12, .5 * xylo(NOTE["G5"], .25))]), .6)


def s_back():
    """Floating back to the tray: a soft falling 「咻」 (no buzzer, nothing wrong)."""
    t = t_of(.38)
    x = bandpass(noise(len(t), "back"), 500, 1800) * np.sin(np.pi * t / .38) ** 2
    return norm(x + .3 * sweep(700, 420, .38), .3)


def s_turn():
    """Turned 45 degrees: 「喀」."""
    return norm(knock(.12, 650, "turn", decay=.01, cut=3200) + .4 * knock(.12, 900, "turn2", decay=.006, cut=4000), .5)


def s_flip():
    """Flipped over: 「啪啦」."""
    one = lambda k, d: bandpass(noise(int(.09 * SR), f"flip{k}"), 900, 3500) * np.exp(-t_of(.09) / d)
    return norm(place(.3, [(0, one(0, .02)), (.1, .7 * one(1, .03))]), .45)


def s_drop():
    """Into the shape box: a hollow 「咚」."""
    return norm(tom(.45, 140, name="drop") + .4 * xylo(NOTE["C4"], .45), .6)


def s_pop():
    """Little pops (seeds jumping, bubbles)."""
    return norm(place(.6, [(k * .09, (1 - k * .12) * sweep(500 + k * 120, 1100 + k * 150, .08, decay=.025)) for k in range(5)]), .5)


def s_done():
    """A picture done: a little fanfare on the xylophone."""
    return norm(place(1.3, [(0, xylo(NOTE["C6"])), (.12, xylo(NOTE["E6"])), (.24, xylo(NOTE["G6"])), (.4, bell(NOTE["C7"], .8, bright=.5)),
                            (.4, .6 * xylo(NOTE["E6"], .7))]), .55)


def s_star():
    """A piece flies onto the Taiwan puzzle: a rising sparkle."""
    return norm(place(1.0, [(k * .07, bell(NOTE[n], .5, bright=.3) * (1 - k * .1)) for k, n in enumerate(["C6", "E6", "G6", "C7", "E7"])]), .45)


def s_open():
    """A toy box opens."""
    return norm(place(.8, [(0, knock(.15, 200, "open", decay=.03)), (.08, .5 * bell(NOTE["G6"], .6)), (.16, .4 * bell(NOTE["D7"], .5))]), .5)


def s_night():
    return norm(place(1.5, [(0, bell(NOTE["G5"], .9, bright=.3)), (.3, bell(NOTE["E5"], .9, bright=.3)), (.6, bell(NOTE["C5"], .9, bright=.3))]), .45)


def s_sparkle():
    return norm(place(.8, [(k * .05, bell(NOTE[n], .35, bright=.2)) for k, n in enumerate(["G6", "B6", "D7", "G7"])]), .4)


# ---------------------------------------------------------------- the pictures' sounds
def s_munch():
    """Munch munch: soft crunches."""
    one = lambda k: lowpass(noise(int(.12 * SR), f"munch{k}"), 1800) * np.exp(-t_of(.12) / .03)
    return norm(place(.8, [(0, one(0)), (.25, .8 * one(1)), (.5, .9 * one(2))]), .45)


def s_boing():
    t = t_of(.6)
    f = 220 * (1 + .35 * np.sin(2 * np.pi * 9 * t) * np.exp(-t / .25)) * (1 + .8 * np.exp(-t / .05))
    return norm(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / .22), .5)


def s_ding():
    return norm(bell(NOTE["A6"], .9, bright=.7), .5)


def s_chime():
    """叮咚."""
    return norm(place(1.4, [(0, bell(NOTE["E6"], 1.0, bright=.4)), (.32, bell(NOTE["C6"], 1.1, bright=.4))]), .5)


def s_waves():
    t = t_of(1.8)
    x = lowpass(noise(len(t), "waves"), 900) * np.sin(np.pi * t / 1.8) ** 2
    return norm(x + .3 * bandpass(noise(len(t), "waves2"), 2000, 5000) * np.sin(np.pi * t / 1.8) ** 6, .4)


def s_splash():
    t = t_of(.5)
    x = bandpass(noise(len(t), "splash"), 600, 4000) * np.exp(-t / .12)
    return norm(place(.9, [(0, x), (.3, .4 * sweep(900, 1500, .06, decay=.02)), (.45, .3 * sweep(1100, 1700, .05, decay=.02))]), .45)


def s_sizzle():
    t = t_of(1.0)
    crack = np.zeros(len(t))
    r = rng("sizzle")
    for k in r.integers(0, len(t) - 200, 40):
        crack[k:k + 120] += r.uniform(.3, 1) * np.exp(-np.arange(120) / 20)
    x = bandpass(noise(len(t), "sizzle2"), 3000, 8000) * .4 + bandpass(crack * noise(len(t), "sz3"), 1500, 6000)
    return norm(x * np.sin(np.pi * t / 1.0), .35)


def s_bapu():
    """The ice-cream cart's horn: 叭—噗."""
    def horn(f, d):
        t = t_of(d)
        ph = np.cumsum(np.full(len(t), f)) / SR
        x = sum(np.sin(2 * np.pi * k * ph) / k for k in range(1, 9))
        return lowpass(x, 1800) * adsr(len(t), .02, .05, .8, .08)
    return norm(place(1.0, [(0, horn(NOTE["A4"], .3)), (.38, horn(NOTE["E4"], .45))]), .45)


def s_mrt():
    """The MRT: 叮咚 and the doors' 「咻」."""
    t = t_of(.4)
    door = bandpass(noise(len(t), "door"), 800, 2500) * np.sin(np.pi * t / .4) ** 2 * .3
    return norm(place(1.8, [(0, bell(NOTE["G5"], .9, bright=.3)), (.3, bell(NOTE["E5"], 1.0, bright=.3)), (1.2, door)]), .5)


def s_whoosh():
    n = int(.5 * SR)
    t = t_of(.5)
    x = np.zeros(n)
    nz = noise(n, "whoosh")
    for i, c in enumerate(np.linspace(600, 2400, 8)):
        seg = slice(i * n // 8, (i + 1) * n // 8)
        x[seg] = bandpass(nz, c * .7, c * 1.3)[seg]
    return norm(lowpass(x, 3000) * np.sin(np.pi * t / .5) ** 2, .4)


def s_toot():
    """A little train's horn: two soft chords."""
    def tone(d):
        t = t_of(d)
        x = sum(np.sin(2 * np.pi * f * t) + .2 * np.sin(4 * np.pi * f * t) for f in (NOTE["D5"], NOTE["F#5"], NOTE["A5"]))
        return x * adsr(len(t), .04, .05, .85, .1)
    return norm(place(1.0, [(0, tone(.3)), (.4, tone(.5))]), .45)


def s_bell():
    """A bicycle (or bus) bell: 叮叮."""
    one = lambda: bell(NOTE["B6"], .4, bright=.9) + .5 * bell(NOTE["B6"] * 1.02, .4, bright=.9)
    return norm(place(.8, [(0, one()), (.16, one())]), .45)


def s_garbage():
    """The garbage truck's tune (給愛麗絲's opening, as Taiwan's trucks play it) on a music box."""
    notes = ["E6", "D#6", "E6", "D#6", "E6", "B5", "D6", "C6", "A5"]
    parts = [(k * .2, bell(NOTE[n], .5, bright=.35)) for k, n in enumerate(notes[:-1])]
    parts.append((1.6, bell(NOTE["A5"], .9, bright=.35)))
    parts.append((1.6, .5 * bell(NOTE["A4"], .9, bright=.2)))
    return norm(place(2.6, parts), .45)


def s_cymbal():
    """A soft cymbal (the lion dance), quiet."""
    t = t_of(.9)
    x = bandpass(noise(len(t), "cymbal"), 3000, 9000) * np.exp(-t / .3)
    return norm(x, .25)


def s_drum():
    """A temple drum, softly: 咚咚咚."""
    return norm(place(.9, [(0, tom(.3, 95, name="d1")), (.22, .8 * tom(.3, 95, name="d2")), (.44, tom(.4, 85, name="d3"))]), .5)


def s_wind():
    t = t_of(1.4)
    x = bandpass(noise(len(t), "wind"), 300, 1400) * np.sin(np.pi * t / 1.4) ** 2
    return norm(x, .35)


def s_spin():
    """A top spinning: a soft whirr."""
    t = t_of(1.0)
    x = bandpass(noise(len(t), "spin"), 800, 3000) * (.6 + .4 * np.sin(2 * np.pi * 14 * t)) * np.sin(np.pi * t / 1.0)
    return norm(x, .35)


def s_fireworks():
    """Tiny fireworks: soft pops and sparkles (no bangs)."""
    parts = []
    for k in range(4):
        t = t_of(.12)
        parts.append((k * .22, lowpass(noise(len(t), f"fw{k}"), 1500) * np.exp(-t / .03) * .6))
        parts.append((k * .22 + .05, .4 * bell(NOTE[["C7", "E7", "G7", "D7"][k]], .4, bright=.2)))
    return norm(place(1.3, parts), .4)


# ---------------------------------------------------------------- the helpers' little sounds
def s_sniff():
    """甲甲: two little sniffs."""
    one = lambda k: bandpass(noise(int(.1 * SR), f"sniff{k}"), 1500, 5000) * np.sin(np.pi * t_of(.1) / .1)
    return norm(place(.4, [(0, one(0)), (.16, one(1))]), .4)


def s_mew():
    """石石: a small 「喵」."""
    f = np.concatenate([np.linspace(600, 820, 6), np.linspace(820, 560, 6)])
    return norm(voice(f, VOWEL_E, .45, seed="mew") * adsr(int(.45 * SR), .03, .05, .8, .15), .4)


def s_grunt():
    """熊熊: a low, happy 「嗯～」."""
    return norm(voice([150, 175, 160], VOWEL_M, .5, seed="grunt") * adsr(int(.5 * SR), .04, .05, .8, .18), .45)


def s_chirp():
    """藍藍: 「啾啾」."""
    return norm(place(.4, [(0, sweep(2400, 3600, .07)), (.12, sweep(2600, 3900, .07))]), .4)


def s_bleat():
    """花花: a soft 「呦」."""
    return norm(voice([520, 640, 480], VOWEL_U, .45, seed="bleat") * adsr(int(.45 * SR), .03, .05, .8, .15), .4)


def s_ooh():
    """猴猴: 「嗚嗚」."""
    one = lambda k: voice([300, 520], VOWEL_U, .2, seed=f"ooh{k}") * adsr(int(.2 * SR), .02, .03, .8, .06)
    return norm(place(.5, [(0, one(0)), (.24, one(1))]), .4)


# ---------------------------------------------------------------- the music
def loop(total, parts, sr=LOOP_SR, peak=.42):
    x = place_loop(total, parts, sr)
    return x / max(1e-9, np.abs(x).max()) * peak


def song(bpm, beats, mel, roots, lead, comp, extra=(), peak=.4, name="song"):
    """A short loop: a lead over a simple accompaniment (four beats a chord)."""
    b = 60 / bpm
    parts = [(beat * b, lead(NOTE[n], max(.3, ln * b))) for beat, n, ln in mel]
    for k, root in enumerate(roots):
        parts += comp(k * 4 * b, NOTE[root], b)
    for at, sig in extra:
        parts.append((at * b, sig))
    return loop(beats * b, parts, peak=peak)


def melody(text):
    """'C6 1, E6 .5, …' (a rest is '- 1') into (beat, note, length)."""
    out, at = [], 0.0
    for item in text.split(","):
        n, ln = item.split()
        if n != "-":
            out.append((at, n, float(ln)))
        at += float(ln)
    return out


def comp_uke(at, root, b):
    """Ukulele strums on 1 and 3 (root, third, fifth)."""
    out = []
    for k in (0, 2):
        for j, ratio in enumerate((1, 1.26, 1.5)):
            out.append((at + k * b + j * .015, .35 * pluck(root * 2 * ratio, 1.2, LOOP_SR, name="uke")))
    return out


def comp_xylo(at, root, b):
    return [(at + k * b, .45 * xylo(root * (1 if k % 2 == 0 else 1.5), .35, LOOP_SR)) for k in range(4)]


def comp_pad(at, root, b):
    return [(at, .35 * pad([root * 2, root * 2.52, root * 3], 4 * b * 1.1, LOOP_SR))]


def comp_pluck(at, root, b):
    return [(at + k * b, .4 * pluck(root * (2 if k % 2 == 0 else 3), .5, LOOP_SR, name="pz")) for k in range(4)]


def x(f, d):
    return xylo(f, d, LOOP_SR)


def k(f, d):
    return kalimba(f, max(.7, d * 1.5), LOOP_SR)


def h(f, d):
    return .55 * harmonica(f, d * .95, LOOP_SR)


def p(f, d):
    return .8 * piano(f, max(.8, d * 1.4), LOOP_SR)


def drums(beats, kick=True, clap=True, name="dr"):
    out = []
    for i in range(beats):
        t = t_of(.2, LOOP_SR)
        if i % 2 == 0 and kick:
            out.append((i, .5 * np.sin(2 * np.pi * np.cumsum(np.linspace(120, 50, len(t))) / LOOP_SR) * np.exp(-t / .09)))
        elif clap:
            out.append((i, .22 * bandpass(noise(len(t), f"{name}{i % 3}"), 900, 3500, LOOP_SR) * np.exp(-t / .03)))
    return out


def m_workshop():
    mel = melody("E5 1, G5 1, A5 1, G5 1, E5 1, D5 1, C5 2, D5 1, E5 1, G5 1, A5 1, G5 3, - 1, "
                 "A5 1, C6 1, A5 1, G5 1, E5 1, G5 1, A5 2, G5 1, E5 1, D5 1, E5 1, C5 3, - 1")
    return song(104, 32, mel, ["C3", "A2", "F2", "G2", "F2", "C3", "D3", "C3"], x, comp_uke)


def m_shapes():
    mel = melody("F5 1, A5 1, C6 2, A5 1, G5 1, F5 2, G5 1, A5 1, G5 1, F5 1, D5 4, "
                 "F5 1, A5 1, C6 1, D6 1, C6 2, A5 2, G5 1, F5 1, G5 1, A5 1, F5 4")
    return song(96, 32, mel, ["F2", "D3", "A#2", "C3", "F2", "D3", "C3", "F2"], k, comp_pluck, peak=.38)


def m_fruit():
    mel = melody("G5 .5, A5 .5, B5 1, D6 1, B5 1, A5 .5, G5 .5, E5 1, G5 2, A5 .5, B5 .5, D6 1, E6 1, D6 1, B5 1, A5 2, "
                 "G5 .5, A5 .5, B5 1, D6 1, E6 1, D6 .5, B5 .5, A5 1, G5 2, E5 1, G5 1, A5 1, G5 3")
    return song(116, 32, mel, ["G2", "E2", "C3", "D3", "G2", "E2", "C3", "D3"], x, comp_xylo, extra=drums(32, clap=False))


def m_animals():
    mel = melody("D5 1, F#5 1, A5 2, B5 1, A5 1, F#5 2, E5 1, F#5 1, D5 2, E5 4, "
                 "F#5 1, A5 1, B5 2, D6 1, B5 1, A5 2, F#5 1, E5 1, F#5 1, E5 1, D5 4")
    return song(100, 32, mel, ["D3", "B2", "G2", "A2", "D3", "B2", "G2", "D3"], h, comp_pluck, peak=.38)


def m_night():
    mel = melody("A5 .5, C6 .5, D6 1, E6 1, D6 .5, C6 .5, A5 1, G5 1, A5 2, C6 .5, D6 .5, E6 1, G6 1, E6 1, D6 1, C6 2, "
                 "A5 .5, C6 .5, D6 1, E6 1, G6 1, E6 .5, D6 .5, C6 1, A5 2, G5 1, A5 1, C6 1, A5 3")
    return song(120, 32, mel, ["A2", "F2", "C3", "G2", "A2", "F2", "G2", "A2"], x, comp_xylo, extra=drums(32, name="nm"), peak=.4)


def m_ride():
    mel = melody("C5 1, E5 1, G5 1, C6 1, B5 1, G5 1, E5 2, F5 1, A5 1, C6 1, A5 1, G5 4, "
                 "C5 1, E5 1, G5 1, C6 1, D6 1, C6 1, A5 2, G5 1, E5 1, D5 1, E5 1, C5 4")
    chug = []
    for i in range(64):
        t = t_of(.1, LOOP_SR)
        chug.append((i * .5, (.16 if i % 2 else .1) * lowpass(noise(len(t), f"chug{i % 4}"), 900, LOOP_SR) * np.sin(np.pi * t / .1) ** 2))
    return song(112, 32, mel, ["C3", "C3", "F2", "G2", "C3", "A2", "G2", "C3"], h, comp_uke, extra=chug)


def m_temple():
    mel = melody("D5 1, E5 1, G5 2, A5 1, G5 1, E5 2, D5 1, E5 1, D5 1, B4 1, A4 4, "
                 "D5 1, E5 1, G5 1, A5 1, B5 2, A5 2, G5 1, E5 1, G5 1, A5 1, D5 4")
    extra = [(i, .5 * tom(.3, 100, LOOP_SR, name=f"tt{i % 2}")) for i in range(0, 32, 2)] + [(0, .3 * gong(170, 1.6, LOOP_SR)), (16, .3 * gong(170, 1.6, LOOP_SR))]
    return song(96, 32, mel, ["D3", "B2", "G2", "A2", "D3", "E3", "A2", "D3"], x, comp_pad, extra=extra, peak=.38)


def m_city():
    mel = melody("A#4 .5, D5 .5, F5 1, A#5 1, A5 .5, G5 .5, F5 1, D5 1, F5 2, G5 .5, A5 .5, A#5 1, C6 1, A#5 1, A5 1, G5 2, "
                 "F5 .5, G5 .5, A5 1, A#5 1, D6 1, C6 .5, A#5 .5, A5 1, G5 1, F5 1, D5 1, D#5 1, A#4 3")
    return song(124, 32, mel, ["A#2", "G2", "D#2", "F2", "A#2", "G2", "F2", "A#2"], p, comp_pluck, extra=drums(32, kick=True, clap=False, name="ct"))


def m_tangram():
    mel = melody("C5 2, E5 1, G5 1, A5 2, G5 2, E5 2, D5 1, C5 1, D5 4, E5 2, G5 1, A5 1, C6 2, A5 2, G5 2, E5 1, D5 1, C5 4")
    return song(84, 28, mel, ["C3", "A2", "F2", "G2", "C3", "F2", "C3"], k, comp_pad, peak=.36)


def m_blocks():
    mel = melody("G5 .5, G5 .5, A5 1, B5 1, D6 1, B5 1, A5 1, G5 2, E5 .5, G5 .5, A5 1, B5 1, A5 1, G5 4, "
                 "B5 .5, B5 .5, D6 1, E6 1, D6 1, B5 1, A5 1, G5 2, E5 1, D5 1, E5 1, G5 3, - 1")
    return song(100, 32, mel, ["G2", "C3", "E2", "D3", "G2", "C3", "D3", "G2"], x, comp_pluck)


def m_rest():
    """A music-box lullaby, 56 bpm."""
    bpm, beats = 56, 16
    b = 60 / bpm
    sr = LOOP_SR
    mel = [(0, "E5", 2), (2, "D5", 1), (3, "C5", 1), (4, "D5", 2), (6, "G4", 2), (8, "E5", 2), (10, "G5", 1), (11, "E5", 1),
           (12, "C5", 4)]
    ch = [(0, ["C4", "E4", "G4"]), (4, ["G3", "B3", "D4"]), (8, ["A3", "C4", "E4"]), (12, ["F3", "A3", "C4"])]
    parts = [(beat * b, .7 * bell(NOTE[nt], max(.6, ln * b * 1.6), sr, .25)) for beat, nt, ln in mel]
    for beat, notes in ch:
        parts.append((beat * b, .45 * pad([NOTE[q] for q in notes], 4 * b * 1.15, sr)))
    return loop(beats * b, parts, peak=.38)


SOUNDS = {
    "tap": s_tap, "pick": s_pick, "near": s_near, "snap": s_snap, "back": s_back, "turn": s_turn, "flip": s_flip, "drop": s_drop,
    "pop": s_pop, "done": s_done, "star": s_star, "open": s_open, "night": s_night, "sparkle": s_sparkle,
    "munch": s_munch, "boing": s_boing, "ding": s_ding, "chime": s_chime, "waves": s_waves, "splash": s_splash, "sizzle": s_sizzle,
    "bapu": s_bapu, "mrt": s_mrt, "whoosh": s_whoosh, "toot": s_toot, "bell": s_bell, "garbage": s_garbage, "cymbal": s_cymbal,
    "drum": s_drum, "wind": s_wind, "spin": s_spin, "fireworks": s_fireworks,
    "sniff": s_sniff, "mew": s_mew, "grunt": s_grunt, "chirp": s_chirp, "bleat": s_bleat, "ooh": s_ooh,
}
MUSIC = {
    "music_workshop": m_workshop, "music_shapes": m_shapes, "music_fruit": m_fruit, "music_animals": m_animals,
    "music_night": m_night, "music_ride": m_ride, "music_temple": m_temple, "music_city": m_city,
    "music_tangram": m_tangram, "music_blocks": m_blocks, "music_rest": m_rest,
}
LONG = {"garbage": 2.7, "waves": 1.9, "mrt": 1.9}


def write(path, x, sr):
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def make(names=None):
    OUT.mkdir(parents=True, exist_ok=True)
    wanted = set(names or [*SOUNDS, *MUSIC])
    for name, f in SOUNDS.items():
        if name not in wanted:
            continue
        y = fade_edges(np.asarray(f(), float))
        d = len(y) / SR
        if d > LONG.get(name, 1.5):
            raise SystemExit(f"{name}: {d:.2f} s is too long")
        if np.abs(y).max() > .75:
            raise SystemExit(f"{name}: too loud")
        write(OUT / f"{name}.wav", y, SR)
        print(f"  {name:20s} {d:5.2f} s  peak {np.abs(y).max():.2f}")
    for name, f in MUSIC.items():
        if name not in wanted:
            continue
        y = np.asarray(f(), float)
        d = len(y) / LOOP_SR
        jump = abs(y[0] - y[-1])
        if not 12 <= d <= 22 or jump > .05:
            raise SystemExit(f"{name}: {d:.1f} s, seam jump {jump:.3f}")
        write(OUT / f"{name}.wav", y, LOOP_SR)
        print(f"  {name:20s} {d:5.2f} s  loop seam {jump:.3f}")
    known = {f"{n}.wav" for n in [*SOUNDS, *MUSIC]}
    extra = [q.name for q in OUT.glob("*.wav") if q.name not in known]
    if extra:
        raise SystemExit(f"files nobody makes: {extra}")
    size = sum(q.stat().st_size for q in OUT.glob("*.wav"))
    if size > LIMIT:
        raise SystemExit(f"{size} bytes: over {LIMIT}")
    print(f"{len(known)} sounds, {size:,} bytes")


def preview(out):
    with tempfile.TemporaryDirectory(dir="/dev/shm") as tmp:
        lst = pathlib.Path(tmp) / "list.txt"
        lst.write_text("".join(f"file '{OUT / (n + '.wav')}'\n" for n in [*MUSIC, *SOUNDS]))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-ar", "22050", "-c:a", "aac", "-b:a", "96k", out], check=True)
    print(out)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["preview"]:
        preview(args[1])
    else:
        make(args or None)
