#!/usr/bin/env bash
# Compare deux dossiers du banc FPS (outils/banc_fps_exe.sh) : tableau markdown avant / après, MÉDIANE des répétitions par (lieu, heure).
#   bash outils/compare_fps.sh <dossier_avant> <dossier_après>
#   bash outils/compare_fps.sh <dossier>                      (un seul dossier : le tableau de référence)
# Colonnes : FPS moyen, FPS 1 % bas, dt p99, images > 16,7 et > 33 ms (sur la durée de mesure), GPU médian, CPU des scripts
# (process + physics, sonde), appels de dessin, primitives ; « autres » = nombre max d'autres Godot/Hollowrim actifs (bruit GPU).
set -u
[[ $# -ge 1 ]] || { echo "usage : compare_fps.sh <avant> [après]" >&2; exit 1; }
python3 -I - "$@" <<'PY'
import json, os, sys, glob, statistics as st
def charger(d):
    r = {}
    for f in sorted(glob.glob(os.path.join(d, "*.json"))):
        try:
            j = json.load(open(f))
        except Exception:
            continue
        if "lieu" not in j:
            continue
        c = os.path.splitext(f)[0] + ".charge"
        j["autres"] = int(open(c).read().strip() or 0) if os.path.exists(c) else -1
        r.setdefault((j["lieu"], int(round(j["heure"]))), []).append(j)
    return r
ORDRE = ["temoin", "place", "foret", "halle", "ferme", "grotte", "crypte", "combat"]
def med(l, k):
    v = [x[k] for x in l if k in x]
    return st.median(v) if v else float("nan")
def cpu(l):
    return st.median([x["cpu_scripts_process_med"] + x["cpu_scripts_physics_med"] * max(1.0, x["cpu_scripts_physics_pas"] / max(1, x["n"])) for x in l])
COLS = [("FPS moy", lambda l: med(l, "fps_moy"), "%.1f"), ("1 % bas", lambda l: med(l, "fps_1pc_bas"), "%.1f"),
        ("dt p99 ms", lambda l: med(l, "dt_p99"), "%.2f"), (">16,7", lambda l: med(l, "sup_16_7"), "%.0f"),
        (">33", lambda l: med(l, "sup_33"), "%.0f"), ("GPU med ms", lambda l: med(l, "gpu_med"), "%.2f"),
        ("CPU scripts ms", cpu, "%.2f"), ("appels", lambda l: med(l, "appels"), "%.0f"), ("prims", lambda l: med(l, "prims"), "%.0f")]
A = charger(sys.argv[1])
B = charger(sys.argv[2]) if len(sys.argv) > 2 else None
cles = sorted(set(A) | set(B or {}), key=lambda k: (ORDRE.index(k[0]) if k[0] in ORDRE else 99, k[1]))
if B is None:
    print("| lieu | heure | " + " | ".join(c[0] for c in COLS) + " | n rép | autres |")
    print("|---|---|" + "---|" * (len(COLS) + 2))
    for k in cles:
        l = A[k]
        print("| %s | %d h | " % k + " | ".join(f % fn(l) for _, fn, f in COLS) + " | %d | %d |" % (len(l), max(x["autres"] for x in l)))
else:
    print("| lieu | heure | " + " | ".join(c[0] + " avant → après" for c in COLS) + " | rép A/B | autres A/B |")
    print("|---|---|" + "---|" * (len(COLS) + 2))
    for k in cles:
        la, lb = A.get(k, []), B.get(k, [])
        cel = []
        for _, fn, f in COLS:
            va = fn(la) if la else float("nan")
            vb = fn(lb) if lb else float("nan")
            d = ""
            if la and lb and va == va and vb == vb and va != 0:
                d = " (%+.0f %%)" % (100.0 * (vb - va) / abs(va))
            cel.append((f % va) + " → " + (f % vb) + d)
        print("| %s | %d h | " % k + " | ".join(cel) + " | %d/%d | %s/%s |" % (len(la), len(lb),
              max([x["autres"] for x in la] or [-1]), max([x["autres"] for x in lb] or [-1])))
PY
