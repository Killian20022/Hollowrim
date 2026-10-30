#!/usr/bin/env python3
"""Fabrique assets/sons/magie/*.wav (magie, branche magie/sons) : sons CC0 retaillés + boucles synthétisées par ffmpeg.
Usage : python3 -I generer.py <dossier_sources_CC0> <dossier_sortie>
Sources (CC0, détail dans assets/LICENCES.md) attendues dans <dossier_sources> :
  rpg80/ (80 CC0 RPG SFX, artisticdude?/OGA), 105016__...fireball-01.wav, freeze.wav, ice/, elec/ (Electricity game sound pack),
  dm.mp3 (3 dark magic spells), qubodup-PowerDrain.ogg, cure/ (Cure Magic).
Sortie : WAV PCM 16 bits mono. One-shots 44,1 kHz crête -3 dBFS ; boucles 32 kHz (raccord croisé, crête -9 dBFS).
Le décodage des .ogg/.mp3 sources se fait ICI, jamais dans le jeu."""
import array, subprocess, sys, wave, math, random, os
SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
random.seed(7)

def ff(args, rate):
    d = subprocess.run(["ffmpeg", "-v", "error", *args, "-ac", "1", "-ar", str(rate), "-f", "f32le", "-"], capture_output=True, check=True).stdout
    a = array.array("f"); a.frombytes(d); return a

def charger(rel, debut=0.0, duree=None, pitch=1.0, filtre="", rate=44100):
    af = []
    if pitch != 1.0:
        af.append(f"asetrate={int(rate*pitch)},aresample={rate}")
    if filtre:
        af.append(filtre)
    args = ["-ss", str(debut)]
    if duree: args += ["-t", str(duree)]
    args += ["-i", os.path.join(SRC, rel)]
    if af: args += ["-af", ",".join(af)]
    return ff(args, rate)

def melange(*parts):
    """parts : (array, gain, decalage_s)"""
    n = max(int((len(a) / 44100 + d) * 44100) for a, g, d in parts)
    out = array.array("f", [0.0]) * n
    for a, g, d in parts:
        o = int(d * 44100)
        for i, x in enumerate(a): out[o + i] += x * g
    return out

def finir(a, nom, crete_db=-3.0, rate=44100, fondu_in=0.004, fondu_out=0.05):
    pic = max(max(abs(x) for x in a), 1e-6)
    g = 10 ** (crete_db / 20) / pic
    n = len(a); fi = int(fondu_in * rate); fo = int(fondu_out * rate)
    pcm = array.array("h")
    for i, x in enumerate(a):
        k = 1.0
        if i < fi: k = i / fi
        if i > n - fo: k = min(k, (n - i) / fo)
        v = int(max(-1, min(1, x * g * k)) * 32767)
        pcm.append(v)
    with wave.open(os.path.join(OUT, nom + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(pcm.tobytes())
    print(nom, "%.2fs" % (n / rate))

def boucle(nom, expr, duree=2.0, crete_db=-9.0, rate=32000, xf=0.3):
    """expr : filtergraph lavfi (sortie [o]). Rend duree+xf puis raccorde la fin sur le début (fondu enchaîné à puissance constante)."""
    L = duree + xf
    a = ff(["-f", "lavfi", "-i", f"anullsrc=r={rate}:cl=mono", "-filter_complex", expr.replace("{L}", str(L)).replace("{R}", str(rate)), "-map", "[o]", "-t", str(L)], rate)
    N = int(duree * rate); X = int(xf * rate)
    b = array.array("f", a[:N])
    for i in range(X):
        t = i / X
        ga = math.sin(t * math.pi / 2); gb = math.cos(t * math.pi / 2)
        b[i] = a[i] * ga + a[N + i] * gb
    m = sum(b) / len(b)
    b = array.array("f", [x - m for x in b])
    finir(b, nom, crete_db, rate, 0.0, 0.0)

def R(rel, **k): return charger(rel, **k)

# ------------------------------------------------------------------ ONE-SHOTS (CC0 retaillés)
F = "highpass=f=60"
# FEU
finir(R("105016__julien-matthey__jm-fx-fireball-01.wav", duree=1.3, filtre=F), "feu_lancer_1")
finir(R("rpg80/spell_fire_06.ogg", filtre=F), "feu_lancer_2")
finir(R("rpg80/spell_fire_07.ogg", pitch=0.85), "feu_impact_1")
finir(melange((R("rpg80/spell_fire_03.ogg", duree=1.2, filtre=F), 1.0, 0), (R("rpg80/spell_fire_07.ogg", pitch=0.7), 0.8, 0.0)), "feu_impact_2")
# GLACE
finir(R("freeze.wav", duree=1.6, filtre=F), "glace_lancer_1", fondu_out=0.25)
finir(R("ice/ice.wav"), "glace_lancer_2")
finir(R("ice/coldsnap.wav", duree=1.1), "glace_impact_1", fondu_out=0.2)
finir(melange((R("ice/ice.wav", pitch=0.8), 1.0, 0), (R("ice/coldsnap.wav", duree=0.6, pitch=1.2), 0.6, 0.05)), "glace_impact_2")
# ELECTRICITE
finir(R("elec/teleport_1.wav", filtre=F), "electricite_lancer_1")
finir(melange((R("rpg80/spell_01.ogg"), 1.0, 0), (R("elec/groundhit.wav", pitch=1.2), 0.8, 0.0)), "electricite_lancer_2")
finir(R("elec/hit.wav", duree=1.2, filtre=F), "electricite_impact_1", fondu_out=0.2)
finir(melange((R("elec/groundhit.wav"), 1.0, 0), (R("elec/shieldhit.wav", duree=0.8, pitch=1.3), 0.5, 0.0)), "electricite_impact_2")
# TENEBRES
finir(R("qubodup-PowerDrain.ogg", duree=1.8, pitch=0.9), "tenebres_lancer_1", fondu_out=0.25)
finir(R("dm.mp3", duree=2.4, filtre="alimiter=limit=0.9"), "tenebres_lancer_2", fondu_out=0.3)
finir(R("dm.mp3", debut=2.6, duree=1.2, filtre="alimiter=limit=0.9"), "tenebres_impact_1", fondu_out=0.15)
finir(R("dm.mp3", debut=3.95, duree=1.9, filtre="alimiter=limit=0.9"), "tenebres_impact_2", fondu_out=0.3)
# SOIN, PROTECTION
finir(R("cure/Cure1.wav"), "soin_lancer_1"); finir(R("cure/Cure6.wav", duree=1.6), "soin_lancer_2", fondu_out=0.2)
finir(R("cure/Cure3.wav"), "soin_impact_1"); finir(R("cure/Cure4.wav"), "soin_impact_2")
finir(R("elec/powerup.wav", duree=1.4, filtre=F), "protection_lancer_1", fondu_out=0.2)
finir(R("elec/shieldhit.wav"), "protection_lancer_2")
finir(R("elec/shieldhit.wav", pitch=0.9), "protection_impact_1"); finir(R("elec/shieldhit.wav", pitch=1.15), "protection_impact_2")
# COMMUNS
finir(R("elec/powerdown.wav", duree=0.7, pitch=1.1), "refus_mana", fondu_out=0.25)
finir(R("elec/powerup.wav", duree=1.1, filtre=F), "double", fondu_out=0.2)
# REACTIONS
vap = ff(["-f", "lavfi", "-i", "anoisesrc=color=white:r=44100:d=1.6:seed=3", "-af", "highpass=f=2500,lowpass=f=9000,afade=t=in:d=0.05,afade=t=out:st=0.2:d=1.4,volume=0.7"], 44100)
finir(melange((vap, 1.0, 0), (R("ice/coldsnap.wav", duree=0.5, pitch=0.8), 0.5, 0), (R("rpg80/spell_fire_07.ogg"), 0.6, 0.0)), "reaction_vapeur", fondu_out=0.2)
finir(melange((R("elec/hit.wav", duree=1.0, filtre=F), 1.0, 0), (R("elec/groundhit.wav"), 0.9, 0.0), (R("elec/teleport_1.wav", pitch=1.2), 0.6, 0.04)), "reaction_decharge", fondu_out=0.2)
finir(melange((R("elec/hit.wav", duree=1.0, filtre=F), 0.9, 0), (R("rpg80/spell_fire_03.ogg", duree=1.2, filtre=F), 1.0, 0.0), (R("rpg80/spell_fire_07.ogg", pitch=0.7), 0.8, 0.06)), "reaction_decharge_incendiaire", fondu_out=0.25)
finir(melange((R("ice/coldsnap.wav", duree=0.9, pitch=0.9), 1.0, 0), (R("dm.mp3", debut=2.6, duree=1.2, filtre="alimiter=limit=0.9"), 0.9, 0.05)), "reaction_cristaux_corrompus", fondu_out=0.25)
finir(melange((R("rpg80/spell_fire_03.ogg", duree=1.4, pitch=0.85, filtre=F), 1.0, 0), (R("qubodup-PowerDrain.ogg", duree=1.4, pitch=0.8), 0.9, 0.0)), "reaction_flammes_obscures", fondu_out=0.25)
finir(melange((R("elec/teleport_1.wav", pitch=0.85), 1.0, 0), (R("dm.mp3", duree=1.5, filtre="alimiter=limit=0.9"), 0.8, 0.0)), "reaction_arcs_violets", fondu_out=0.25)

# ------------------------------------------------------------------ BOUCLES (synthèse ffmpeg, 2 s, 32 kHz)
# charge : douce, basse énergie
# (2026-10-30) glace et électricité refaites : plus de sinus aigus ni de bruit blanc haché 30-47 Hz (« font mal aux
# oreilles ») ; bruit rose filtré, passe-bas 2,8-3,8 kHz, niveau aligné sur le feu (≈ -23 LUFS, < -45 dB au-dessus de 3 kHz).
boucle("charge_feu",
  "anoisesrc=c=brown:r={R}:seed=11,lowpass=f=420,tremolo=f=4:d=0.35,volume=2.2[a];"
  "anoisesrc=c=pink:r={R}:seed=12,highpass=f=2500,lowpass=f=7000,tremolo=f=11:d=0.95,volume=0.25[b];[a][b]amix=inputs=2:normalize=0[o]")
boucle("charge_glace",
  "anoisesrc=c=pink:r={R}:seed=13,bandpass=f=900:width_type=h:w=900,tremolo=f=0.5:d=0.5,volume=1.6[a];"
  "anoisesrc=c=brown:r={R}:seed=17,lowpass=f=350,tremolo=f=0.7:d=0.3,volume=1.4[b];"
  "sine=f=440:r={R},tremolo=f=1.5:d=0.6,volume=0.05[c];sine=f=659:r={R},tremolo=f=2:d=0.6,volume=0.03[d];"
  "[a][b][c][d]amix=inputs=4:normalize=0,lowpass=f=3200,lowpass=f=3200[o]")
boucle("charge_electricite",
  "sine=f=60:r={R},volume=0.30[a];sine=f=120:r={R},volume=0.15[b];"
  "anoisesrc=c=pink:r={R}:seed=14,bandpass=f=900:width_type=h:w=700,tremolo=f=9:d=0.6,volume=0.7[c];"
  "[a][b][c]amix=inputs=3:normalize=0,lowpass=f=2800,lowpass=f=2800[o]")
boucle("charge_tenebres",
  "sine=f=55:r={R},vibrato=f=0.5:d=0.3,volume=0.40[a];sine=f=82.4:r={R},vibrato=f=1:d=0.2,volume=0.25[b];"
  "anoisesrc=c=brown:r={R}:seed=15,lowpass=f=260,volume=1.2[c];[a][b][c]amix=inputs=3:normalize=0[o]")
boucle("charge_soin",
  "sine=f=523:r={R},tremolo=f=2:d=0.4,volume=0.2[a];sine=f=659:r={R},tremolo=f=2.5:d=0.4,volume=0.15[b];sine=f=784:r={R},tremolo=f=1.5:d=0.4,volume=0.12[c];[a][b][c]amix=inputs=3:normalize=0[o]")
boucle("charge_protection",
  "sine=f=220:r={R},tremolo=f=2:d=0.3,volume=0.3[a];sine=f=330:r={R},tremolo=f=3:d=0.3,volume=0.2[b];"
  "anoisesrc=c=pink:r={R}:seed=16,lowpass=f=500,volume=0.4[c];[a][b][c]amix=inputs=3:normalize=0[o]")
# jets : plus présents
boucle("jet_feu",
  "anoisesrc=c=pink:r={R}:seed=21,bandpass=f=700:width_type=h:w=900,tremolo=f=8:d=0.45,volume=2.0[a];"
  "anoisesrc=c=brown:r={R}:seed=22,lowpass=f=220,volume=3.0[b];"
  "anoisesrc=c=white:r={R}:seed=23,highpass=f=4000,tremolo=f=15:d=1.0,volume=0.12[c];[a][b][c]amix=inputs=3:normalize=0[o]", crete_db=-8.0)
boucle("jet_glace",
  "anoisesrc=c=pink:r={R}:seed=24,bandpass=f=1100:width_type=h:w=1400,tremolo=f=1.2:d=0.35,volume=2.2[a];"
  "anoisesrc=c=brown:r={R}:seed=25,lowpass=f=300,volume=2.4[b];"
  "anoisesrc=c=pink:r={R}:seed=32,bandpass=f=2200:width_type=h:w=800,tremolo=f=6:d=0.9,volume=0.35[c];"
  "[a][b][c]amix=inputs=3:normalize=0,lowpass=f=3800,lowpass=f=3800[o]", crete_db=-8.0)
boucle("jet_electricite",
  "sine=f=60:r={R},volume=0.30[a];sine=f=120:r={R},volume=0.18[b];sine=f=180:r={R},volume=0.08[e];"
  "anoisesrc=c=pink:r={R}:seed=26,bandpass=f=1000:width_type=h:w=900,tremolo=f=13:d=0.7,volume=1.1[c];"
  "anoisesrc=c=brown:r={R}:seed=27,lowpass=f=400,tremolo=f=5:d=0.4,volume=1.5[d];"
  "[a][b][e][c][d]amix=inputs=5:normalize=0,lowpass=f=3000,lowpass=f=3000[o]", crete_db=-8.0)
boucle("jet_tenebres",
  "sine=f=70:r={R},volume=0.35[a];sine=f=73:r={R},volume=0.35[b];"
  "anoisesrc=c=brown:r={R}:seed=28,lowpass=f=300,volume=2.0[c];"
  "anoisesrc=c=pink:r={R}:seed=29,bandpass=f=1000:width_type=h:w=500,tremolo=f=5:d=0.7,volume=0.3[d];[a][b][c][d]amix=inputs=4:normalize=0[o]", crete_db=-8.0)
boucle("jet_soin",
  "sine=f=784:r={R},tremolo=f=4:d=0.5,volume=0.2[a];sine=f=1047:r={R},tremolo=f=5:d=0.5,volume=0.15[b];"
  "anoisesrc=c=white:r={R}:seed=30,highpass=f=5000,volume=0.1[c];[a][b][c]amix=inputs=3:normalize=0[o]", crete_db=-10.0)
boucle("jet_protection",
  "sine=f=150:r={R},tremolo=f=6:d=0.3,volume=0.3[a];sine=f=450:r={R},tremolo=f=4:d=0.3,volume=0.15[b];"
  "anoisesrc=c=pink:r={R}:seed=31,bandpass=f=900:width_type=h:w=700,volume=0.5[c];[a][b][c]amix=inputs=3:normalize=0[o]", crete_db=-10.0)
