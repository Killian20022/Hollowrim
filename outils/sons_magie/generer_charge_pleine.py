"""Son « charge pleine » des sorts lancés (assets/sons/magie/charge_pleine.wav, ChargeSort / SonsMagie.charge_pleine) : joué
UNE fois quand la charge atteint le maximum. 100 % synthétisé (bibliothèque standard) : un coup sourd (le « verrou » de
l'énergie, 70 → 48 Hz) et une note runique chaude en quinte (196 + 294 Hz, harmoniques douces) qui résonne ~0,6 s, avec un
léger battement ; passe-bas doux, rien au-dessus de ~2,5 kHz (les sinus aigus « font mal aux oreilles », retour du
2026-10-30). Mono 16 bits 44,1 kHz, crête -3 dBFS comme les autres sons de magie. La hauteur par école est donnée au jeu.
Lancer : python3 -I outils/sons_magie/generer_charge_pleine.py"""
import math, random, struct, wave, os

SR = 44100
DUREE = 0.85
random.seed(11)
N = int(SR * DUREE)
out = [0.0] * N
ph_coup = 0.0
bas = 0.0
for i in range(N):
    t = i / SR
    # coup sourd : sinus qui descend vite, attaque de 4 ms
    f_coup = 48.0 + 22.0 * math.exp(-t * 18.0)
    ph_coup += 2 * math.pi * f_coup / SR
    coup = math.tanh(1.6 * math.sin(ph_coup)) * math.exp(-t * 9.0) * min(t / 0.004, 1.0)
    # souffle bref de l'attaque (bruit filtré très bas)
    bas += 0.06 * (random.uniform(-1.0, 1.0) - bas)
    souffle = bas * math.exp(-t * 22.0) * 1.2
    # note runique en quinte, montée de 25 ms, battement de 3 Hz
    env = min(t / 0.025, 1.0) * math.exp(-t * 4.2)
    bat = 1.0 + 0.18 * math.sin(2 * math.pi * 3.0 * t)
    note = 0.0
    for f, a in ((196.0, 1.0), (294.0, 0.6), (392.0, 0.25), (588.0, 0.1), (196.0 * 1.006, 0.35)):
        note += a * math.sin(2 * math.pi * f * t)
    out[i] = 0.9 * coup + souffle + 0.42 * note * env * bat
# passe-bas doux à deux pôles (~2,4 kHz)
a = math.exp(-2 * math.pi * 2400.0 / SR)
y1 = y2 = 0.0
for i in range(N):
    y1 = (1 - a) * out[i] + a * y1
    y2 = (1 - a) * y1 + a * y2
    out[i] = y2
for i in range(N):
    t = i / SR
    out[i] *= min(1.0, (DUREE - t) / 0.2)
pic = max(abs(x) for x in out)
gain = (10 ** (-3.0 / 20.0)) / pic
chemin = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "sons", "magie", "charge_pleine.wav")
with wave.open(os.path.normpath(chemin), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * gain)) * 32767)) for x in out))
print("ok", os.path.normpath(chemin))
