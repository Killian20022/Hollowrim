"""Son du « rayon du néant » (assets/sons/magie/rayon_neant_lancer.wav) : 100 % synthétisé (bibliothèque standard, pas
d'ffmpeg ni de numpy) : montée sombre (souffle filtré), puis le tir = grondement grave qui descend + déchirure aiguë qui
tombe, queue de bruit sourd. Mono 16 bits 44,1 kHz, crête -3 dBFS comme les autres sons de magie.
Lancer : python3 outils/sons_magie/generer_rayon_neant.py"""
import math, random, struct, wave, os

SR = 44100
DUREE = 1.9
random.seed(7)
N = int(SR * DUREE)
out = [0.0] * N
bas1 = bas2 = 0.0
phase_grave = 0.0
phase_aigu = 0.0
phase_mi = 0.0
for i in range(N):
    t = i / SR
    bruit = random.uniform(-1.0, 1.0)
    # filtres passe-bas à un pôle : souffle (fréquence qui monte pendant la montée) et rumeur sourde
    f_souffle = 0.02 + 0.16 * min(t / 0.3, 1.0) if t < 0.3 else 0.18 * math.exp(-(t - 0.3) * 2.0) + 0.02
    bas1 += f_souffle * (bruit - bas1)
    bas2 += 0.012 * (bruit - bas2)
    v = 0.0
    # montée (0 - 0,3 s) : souffle qui enfle
    if t < 0.3:
        v += bas1 * (t / 0.3) ** 2 * 1.4
    # tir (dès 0,3 s)
    if t >= 0.3:
        u = t - 0.3
        env = math.exp(-u * 1.7) * min(u / 0.012, 1.0)
        f_grave = 38.0 + 52.0 * math.exp(-u * 3.2)
        phase_grave += 2 * math.pi * f_grave / SR
        g = math.sin(phase_grave) + 0.5 * math.sin(2 * phase_grave + 0.6) + 0.25 * math.sin(3 * phase_grave)
        g = math.tanh(g * 1.8)
        phase_mi += 2 * math.pi * (f_grave * 2.01 + 3.0 * math.sin(u * 40.0)) / SR
        f_aigu = 220.0 + 2400.0 * math.exp(-u * 7.0)
        phase_aigu += 2 * math.pi * f_aigu / SR
        aigu = (math.sin(phase_aigu) * 0.5 + (bruit * 0.5)) * math.exp(-u * 6.0)
        v += env * (0.75 * g + 0.25 * math.sin(phase_mi)) + 0.35 * aigu + 3.0 * bas2 * math.exp(-u * 1.1) + 0.5 * bas1 * math.exp(-u * 3.5)
    out[i] = v
# fondu final et normalisation à -3 dBFS
for i in range(N):
    t = i / SR
    out[i] *= min(1.0, (DUREE - t) / 0.25)
pic = max(abs(x) for x in out)
gain = (10 ** (-3.0 / 20.0)) / pic
chemin = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "sons", "magie", "rayon_neant_lancer.wav")
with wave.open(os.path.normpath(chemin), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * gain)) * 32767)) for x in out))
print("ok", os.path.normpath(chemin))
