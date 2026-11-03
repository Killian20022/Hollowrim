#!/usr/bin/env python3
"""Fabrique le son de décharge des sorts à charge (orage runique) : synthèse pure (bibliothèque
standard, aucune source externe). Usage : python3 -I generer_decharges.py <dossier_sortie> (assets/sons/magie).
  electricite_decharge.wav : craquement sec + éclats qui se répondent + grondement d'orage qui roule (1,7 s)
WAV PCM 16 bits mono 44,1 kHz, crête -3 dBFS (comme les autres one-shots de assets/sons/magie)."""
import array, math, os, random, sys, wave
OUT = sys.argv[1]
R = 44100
random.seed(11)

def passe_bas(a, fc):
    k = 1 - math.exp(-2 * math.pi * fc / R); y = 0.0; o = array.array("f")
    for x in a:
        y += k * (x - y); o.append(y)
    return o

def passe_haut(a, fc):
    b = passe_bas(a, fc)
    return array.array("f", [x - y for x, y in zip(a, b)])

def bruit(n, brun=False):
    o = array.array("f"); y = 0.0
    for _ in range(n):
        w = random.uniform(-1, 1)
        if brun:
            y = (y + 0.02 * w) / 1.002; o.append(y * 8)
        else:
            o.append(w)
    return o

def env(n, f):
    return array.array("f", [f(i / R) for i in range(n)])

def mul(a, e):
    return array.array("f", [x * y for x, y in zip(a, e)])

def somme(*parts):
    n = max(len(a) for a, g, d in parts)
    o = array.array("f", [0.0]) * n
    for a, g, d in parts:
        s = int(d * R)
        for i, x in enumerate(a):
            if s + i < n: o[s + i] += x * g
    return o

def finir(a, nom, fondu_out=0.12):
    pic = max(max(abs(x) for x in a), 1e-6); g = 10 ** (-3 / 20) / pic
    n = len(a); fi = int(0.004 * R); fo = int(fondu_out * R); pcm = array.array("h")
    for i, x in enumerate(a):
        k = 1.0
        if i < fi: k = i / fi
        if i > n - fo: k = min(k, (n - i) / fo)
        pcm.append(int(max(-1, min(1, x * g * k)) * 32767))
    with wave.open(os.path.join(OUT, nom + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R); w.writeframes(pcm.tobytes())
    print(nom, "%.2fs" % (n / R))

# ---- électricité : craquement + éclats + tonnerre
n = int(1.7 * R)
crack = mul(passe_haut(bruit(n), 1500), env(n, lambda t: math.exp(-t * 38)))
eclats = array.array("f", [0.0]) * n
for t0 in (0.05, 0.11, 0.2, 0.31, 0.46):
    i0 = int(t0 * R); l = int(0.09 * R)
    for i in range(l):
        eclats[i0 + i] += random.uniform(-1, 1) * math.exp(-i / R * 45) * 0.6
eclats = passe_haut(eclats, 900)
rumble = mul(passe_bas(bruit(n, True), 240), env(n, lambda t: min(1, t / 0.05) * math.exp(-t * 2.2)))
rumble = mul(rumble, env(n, lambda t: 0.75 + 0.25 * math.sin(t * 2 * math.pi * 9)))
zap = array.array("f", [math.sin(2 * math.pi * (3200 * math.exp(-t * 6)) * t) * math.exp(-t * 14) * 0.4 for t in (i / R for i in range(n))])
finir(somme((crack, 1.0, 0), (eclats, 0.8, 0), (rumble, 2.4, 0.03), (zap, 0.5, 0)), "electricite_decharge", 0.3)

