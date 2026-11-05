#!/usr/bin/env python3
"""Génère les sons de pas par matériau et les sons d'interface de assets/sons (lot « son », 2026-11-05).

Usage : python3 -I outils/generer_sons_nuit.py <dossier_sources> <dossier_sortie>
<dossier_sources> contient, extraits, les paquets CC0 d'OpenGameArt (voir assets/LICENCES.md) :
  weapons-apparel/sfx/boots-leather-*.wav        (Vehicle)  -> pierre, bois, saut
  tinysized/sfx-cc0/{mud,soil}-steps-*.wav, bottle-*, water-drop-*.wav (Vehicle) -> terre, potion
  80-cc0-rpg-sfx/{stones,wood,book}_*.ogg        (rubberduck) -> pierre, bois, menu
  100-cc0-sfx/splash_*.ogg                       (rubberduck) -> eau peu profonde
Les cloches d'interface (niveau, quête) sont SYNTHÉTISÉES ici (sinusoïdes inharmoniques), donc sans source externe.
Sortie : WAV mono 44,1 kHz 16 bits, crête normalisée à -1 dBFS (niveau du footstep_snow existant).
"""
import math, os, random, re, struct, subprocess, sys, wave

SRC, OUT = sys.argv[1], sys.argv[2]
TMP = os.path.join(OUT, "_tmp_gen")
os.makedirs(TMP, exist_ok=True)
FF = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]

def ff(*args):
    subprocess.run(FF + list(args), check=True)

def finir(entree, nom, filtre="anull", pitch=1.0):
    """Mono, 44,1 kHz, crête -1 dBFS, 16 bits."""
    f = filtre
    if pitch != 1.0:
        f = f"asetrate=44100*{pitch},aresample=44100," + f
    sortie = os.path.join(OUT, nom + ".wav")
    # 1re passe : crête
    r = subprocess.run(FF[:1] + ["-hide_banner", "-i", entree, "-af", f + ",volumedetect", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.search(r"max_volume: (-?[\d.]+) dB", r.stderr)
    gain = -1.0 - (float(m.group(1)) if m else 0.0)
    ff("-i", entree, "-af", f"{f},volume={gain}dB", "-ac", "1", "-ar", "44100", "-c:a", "pcm_s16le", sortie)
    return sortie

def src(*parts):
    return os.path.join(SRC, *parts)

def tranche(entree, debut, duree, sortie, fondu=0.04):
    ff("-ss", f"{debut}", "-t", f"{duree}", "-i", entree, "-af",
       f"afade=t=in:d=0.004,afade=t=out:st={max(duree - fondu, 0):.3f}:d={fondu}", "-ac", "1", sortie)
    return sortie

def melanger(a, b, sortie, vol_b=0.6, decal_b=0.0):
    ff("-i", a, "-i", b, "-filter_complex",
       f"[1:a]volume={vol_b},adelay={int(decal_b * 1000)}[b];[0:a][b]amix=inputs=2:duration=longest:normalize=0", sortie)
    return sortie

# ---------------------------------------------------------------- terre / herbe : pas isolés des enregistrements de boue et de terre
def segments(fichier):
    r = subprocess.run(FF[:1] + ["-hide_banner", "-i", fichier, "-af", "silencedetect=n=-30dB:d=0.12", "-f", "null", "-"],
                       capture_output=True, text=True)
    duree = float(re.search(r"Duration: (\d+):(\d+):([\d.]+)", r.stderr).group(3))
    fins = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", r.stderr)]
    debuts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", r.stderr)]
    segs = []
    for fin in fins:
        suiv = [d for d in debuts if d > fin + 0.01]
        segs.append((fin, (suiv[0] if suiv else duree) - fin))
    return [(d, l) for d, l in segs if l >= 0.10]

k = 0
for nom in ["mud-steps-01", "mud-steps-02", "mud-steps-03", "mud-steps-04", "mud-steps-05", "soil-steps-01"]:
    f = src("tinysized", "sfx-cc0", nom + ".wav")
    for d, l in segments(f):
        if k >= 8:
            break
        t = tranche(f, max(d - 0.01, 0), min(l + 0.01, 0.42), os.path.join(TMP, f"t{k}.wav"))
        finir(t, f"pas_terre_{k:02d}", "highpass=f=80,lowpass=f=6000")
        k += 1

# ---------------------------------------------------------------- pierre : semelle de cuir + claquement de pierre
bottes = [src("weapons-apparel", "sfx", f"boots-leather-step-0{i}.wav") for i in (1, 2, 3, 4)]
pierres = [src("80-cc0-rpg-sfx", f"stones_0{i}.ogg") for i in (1, 2, 3, 4)]
for i in range(5):
    b = tranche(bottes[i % 4], 0.0, 0.30, os.path.join(TMP, f"pb{i}.wav"), 0.08)
    p = tranche(pierres[(i * 3) % 4], 0.0, 0.16, os.path.join(TMP, f"pp{i}.wav"), 0.06)
    mel = melanger(b, p, os.path.join(TMP, f"pm{i}.wav"), 0.55, 0.01)
    finir(mel, f"pas_pierre_{i:02d}", "highpass=f=140,treble=g=3:f=3500", pitch=(0.94, 1.0, 1.06, 0.97, 1.03)[i])

# ---------------------------------------------------------------- bois : semelle + toc de planche, grave
bois = [src("80-cc0-rpg-sfx", f"wood_0{i}.ogg") for i in (1, 2, 3, 5)]
for i in range(5):
    b = tranche(bottes[(i + 1) % 4], 0.0, 0.30, os.path.join(TMP, f"bb{i}.wav"), 0.08)
    w = tranche(bois[i % 4], 0.0, 0.20, os.path.join(TMP, f"bw{i}.wav"), 0.06)
    mel = melanger(b, w, os.path.join(TMP, f"bm{i}.wav"), 0.9, 0.0)
    finir(mel, f"pas_bois_{i:02d}", "highpass=f=90,lowpass=f=5200", pitch=(0.92, 1.0, 1.05, 0.96, 1.02)[i])

# ---------------------------------------------------------------- eau peu profonde : éclaboussures courtes
spl = [src("100-cc0-sfx", "splash_01.ogg"), src("100-cc0-sfx", "splash_02.ogg")]
for i in range(4):
    t = tranche(spl[i % 2], (0.0, 0.0, 0.18, 0.15)[i], 0.34, os.path.join(TMP, f"e{i}.wav"), 0.12)
    finir(t, f"pas_eau_{i:02d}", "highpass=f=200,lowpass=f=7000", pitch=(1.0, 1.08, 0.95, 1.12)[i])

# ---------------------------------------------------------------- saut (effort de botte)
for i in range(3):
    t = tranche(src("weapons-apparel", "sfx", f"boots-leather-jump-0{i + 1}.wav"), 0.0, 0.42, os.path.join(TMP, f"j{i}.wav"), 0.1)
    finir(t, f"saut_{i:02d}", "highpass=f=100")

# ---------------------------------------------------------------- interface : synthèse de cloches
SR = 44100

def cloche(buf, t0, f0, duree, vol=1.0):
    """Cloche sourde : partiels inharmoniques à décroissances différentes."""
    parts = [(1.0, 1.0, 1.00), (2.0, 0.55, 0.62), (2.76, 0.40, 0.45), (4.07, 0.22, 0.30), (5.4, 0.12, 0.2)]
    n0 = int(t0 * SR)
    for i in range(int(duree * SR)):
        if n0 + i >= len(buf):
            break
        t = i / SR
        att = min(t / 0.004, 1.0)
        s = 0.0
        for r, a, tau in parts:
            s += a * math.sin(2 * math.pi * f0 * r * t) * math.exp(-t / (tau * duree * 0.42))
        buf[n0 + i] += vol * att * s

def ecrire(buf, nom):
    p = os.path.join(TMP, nom + "_brut.wav")
    m = max(max(abs(x) for x in buf), 1e-9)
    with wave.open(p, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x / m)) * 30000)) for x in buf))
    return p

def tampon(sec):
    return [0.0] * int(sec * SR)

# montée de niveau : arpège de ré mineur (D4 F4 A4 D5), puis accord tenu qui s'éteint
b = tampon(2.6)
for t0, f in [(0.0, 293.66), (0.16, 349.23), (0.32, 440.0), (0.50, 587.33)]:
    cloche(b, t0, f, 1.7, 0.8)
for f in (293.66, 440.0, 587.33):
    cloche(b, 0.7, f, 1.9, 0.45)
finir(ecrire(b, "ui_niveau"), "ui_niveau", "lowpass=f=9000,aecho=0.7:0.5:90:0.25")

# quête commencée : quinte creuse montante (A3 -> E4)
b = tampon(1.5)
cloche(b, 0.0, 220.0, 1.2, 0.9)
cloche(b, 0.22, 329.63, 1.2, 0.8)
finir(ecrire(b, "ui_quete_debut"), "ui_quete_debut", "lowpass=f=8000,aecho=0.7:0.5:70:0.2")

# quête terminée : D4 A4 D5 F5 puis accord de ré majeur (tierce picarde), plus ample que la montée de niveau
b = tampon(3.0)
for t0, f in [(0.0, 293.66), (0.20, 440.0), (0.40, 587.33)]:
    cloche(b, t0, f, 1.8, 0.8)
for f in (293.66, 369.99, 440.0, 587.33):
    cloche(b, 0.72, f, 2.2, 0.5)
finir(ecrire(b, "ui_quete_fin"), "ui_quete_fin", "lowpass=f=9000,aecho=0.7:0.5:110:0.28")

# objet ramassé : petit tintement sourd (bois + cloche courte)
b = tampon(0.45)
cloche(b, 0.0, 880.0, 0.35, 0.8)
rnd = random.Random(7)
for i in range(int(0.02 * SR)):
    b[i] += (rnd.random() * 2 - 1) * 0.6 * (1 - i / (0.02 * SR))
finir(ecrire(b, "ui_ramasse"), "ui_ramasse", "lowpass=f=6500")

# potion : bouchon + deux gorgées
bouchon = src("tinysized", "sfx-cc0", "bottle-glass-uncork-01.wav")
g = src("tinysized", "sfx-cc0", "water-drop-01.wav")
ff("-i", bouchon, "-i", g, "-i", g, "-filter_complex",
   "[0:a]volume=0.8[a];[1:a]asetrate=44100*0.62,aresample=44100,volume=0.9,adelay=520[b];"
   "[2:a]asetrate=44100*0.55,aresample=44100,volume=0.8,adelay=900[c];[a][b][c]amix=inputs=3:duration=longest:normalize=0",
   "-ac", "1", os.path.join(TMP, "potion.wav"))
finir(os.path.join(TMP, "potion.wav"), "ui_potion", "lowpass=f=7000")

# ouverture / fermeture du menu : page de livre
tranche(src("80-cc0-rpg-sfx", "book_01.ogg"), 0.0, 0.50, os.path.join(TMP, "m1.wav"), 0.2)
finir(os.path.join(TMP, "m1.wav"), "ui_menu_ouvre", "highpass=f=120")
tranche(src("80-cc0-rpg-sfx", "book_02.ogg"), 0.0, 0.38, os.path.join(TMP, "m2.wav"), 0.16)
finir(os.path.join(TMP, "m2.wav"), "ui_menu_ferme", "highpass=f=120")

for f in os.listdir(TMP):
    os.remove(os.path.join(TMP, f))
os.rmdir(TMP)
print("fait :", sorted(x for x in os.listdir(OUT) if x.startswith(("pas_", "saut_", "ui_"))))
