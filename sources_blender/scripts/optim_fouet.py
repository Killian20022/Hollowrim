# Recherche du POIGNET QUI FOUETTE (references/combat_epee/prompt_poignet_fouet.md) : pour un clip, cherche les angles
# d'articulation (torsion k, flexion f, inclinaison r, rotation du coude phi) de ses clés de frappe qui donnent
#   - un vrai fouet : pointe DERRIÈRE la main au début de la frappe, DEVANT à la fin, pointe bien plus rapide que le poing ;
#   - le tranchant qui mène (angle normale du plat / mouvement du milieu de lame, comme outils/test_combat_epee.gd) ;
#   - le bon trajet du milieu de lame à l'écran (diagonale haut-droite -> bas-gauche, balayage droite -> gauche...) ;
#   - pas de saut d'une image à l'autre (pointe), pas de retournement de l'avant-bras entre deux clés.
# Les poings (positions) restent ceux de gestes_bras_epee.py ; seules les articulations bougent. Recherche locale
# aléatoire (graine fixe : résultat reproductible), point de départ = la solution du solveur de anim_bras_epee.py.
#
#   blender.exe -b sources_blender/bras_fps.blend --python sources_blender/scripts/optim_fouet.py -- --clips=repos \
#       --optim=coup_a [--iter=600]
# Sortie : lignes OPTIM <clé> k=.. f=.. r=.. phi=.. à recopier dans les clés (k, f, r, phi : clé « fixée »).

import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_bras_epee as AB   # noqa: E402  (exécute main() : passer --clips=repos pour qu'il ne fasse presque rien)
from mathutils import Vector   # noqa: E402
import bpy   # noqa: E402

ARGS = AB.ARGS
CLIP = ARGS.get("optim", "coup_a")
CLES = AB.CLIPS[CLIP]
MQ = AB.MARQUEURS[CLIP]
T0, T1 = MQ["frappe"], MQ["fin_frappe"]
# trajet voulu du milieu de lame à l'écran entre frappe et fin_frappe : (a, b) -> booléen + écart
CIBLES = {
    # diagonale du combo (test_combat_epee : d.x < -0.4, d.y < -0.3, a en haut à droite, b en bas à gauche)
    "coup_a": dict(a=(0.25, 0.25), b=(-0.25, -0.35), dir_fin=(-0.6, -0.8)),
    # balayage lourd droite -> gauche, un peu plongeant
    "lourd": dict(a=(0.55, 0.15), b=(-0.45, -0.25), dir_fin=(-1.0, -0.3)),
}
CIBLE = CIBLES.get(CLIP, CIBLES["coup_a"])
# clés optimisées : celles dont l'instant touche la frappe (de l'armé au suivi)
INDICES = [i for i, c in enumerate(CLES) if MQ["arme"] - 1e-6 <= c["t"] <= MQ.get("suivi", T1) + 1e-6 and c["nom"] != "repos"]

tv = math.tan(math.radians(AB.D["fov"]) / 2)
th = tv * 16 / 9


def ecr(v):
    if v.z > -0.02:
        return None
    return Vector((v.x / -v.z / th, v.y / -v.z / tv))


def evaluer(cles, detail=False):
    act = AB.creer_action("_optim", cles)
    AB.A.animation_data.action = act
    pts = []
    n = int(round((min(T1 + 0.03, cles[-1]["t"]) - (T0 - 0.03)) * 120))
    for i in range(n + 1):
        t = T0 - 0.03 + i / 120
        fr = t * AB.FPS
        AB.scene.frame_set(int(math.floor(fr)), subframe=fr - math.floor(fr))
        W = AB.CAM_DE_B @ AB.A.pose.bones["hand_r"].matrix @ AB.PRISE_D
        g, p = W @ AB.GARDE, W @ AB.POINTE
        pts.append((t, W @ Vector((0, AB.MILIEU_POIGNEE, 0)), g, p, (W.to_3x3() @ Vector((0, 0, 1))).normalized()))
    bpy.data.actions.remove(act)
    cout = 0.0
    fils, devant, rap, sauts = [], [], [], []
    hors = 0
    a = b = None
    for i in range(len(pts) - 1):
        t, po, g, p, z = pts[i]
        t2, po2, g2, p2, z2 = pts[i + 1]
        if not (T0 - 1e-6 <= t and t2 <= T1 + 1e-6):
            continue
        m6, m62 = g.lerp(p, 0.6), g2.lerp(p2, 0.6)
        mv = m62 - m6
        if mv.length > 1e-5:
            fils.append(math.degrees(math.acos(min(1.0, abs(z2.dot(mv.normalized()))))))
        e_po, e_p, e_m = ecr(po), ecr(p), ecr(g.lerp(p, 0.5))
        e_po2, e_p2, e_m2 = ecr(po2), ecr(p2), ecr(g2.lerp(p2, 0.5))
        if None in (e_po, e_p, e_m, e_po2, e_p2, e_m2):
            hors += 1
            continue
        if a is None:
            a = e_m
        b = e_m2
        dfin = (e_p2 - e_po2)
        vm = e_m2 - e_m
        if vm.length > 1e-4:
            d = vm.normalized()
            devant.append((e_p - e_po).dot(d) / max((e_p - e_po).length, 1e-6))
        rap.append((e_p2 - e_p).length / max((e_po2 - e_po).length, 1e-3))
        sauts.append((e_p2 - e_p).length)
        if max(abs(e_p.x), abs(e_p.y)) > 1.25:
            hors += 0.5
    if a is None or not devant:
        return 1e9, {}
    fil = sum(fils) / max(1, len(fils))
    cout += 3.0 * max(0.0, 75.0 - fil)
    # fouet : pointe derrière au début (premier tiers), devant à la fin (dernier tiers)
    k3 = max(1, len(devant) // 3)
    deb = sum(devant[:k3]) / k3
    fin = sum(devant[-k3:]) / k3
    cout += 40.0 * max(0.0, deb + 0.2) + 40.0 * max(0.0, 0.6 - fin)
    rmoy = sum(rap) / len(rap)
    cout += 10.0 * max(0.0, 3.0 - rmoy)
    # pas de saut : la pointe ne doit pas traverser plus de 0,45 écran en 1/120 s... (≈ 0,9 par image à 60 i/s)
    cout += 60.0 * sum(max(0.0, s - 0.45) for s in sauts)
    cout += 8.0 * hors
    cout += 30.0 * ((a - Vector(CIBLE["a"])).length + (b - Vector(CIBLE["b"])).length)
    # direction finale de la lame à l'écran (poing -> pointe) : du haut vers le BAS (diagonale), pas un simple balayage
    if "dir_fin" in CIBLE and dfin.length > 1e-3:
        cout += 0.8 * math.degrees(dfin.normalized().angle(Vector(CIBLE["dir_fin"]).normalized()))
    # continuité articulaire entre clés successives (pas de retournement)
    for i in range(1, len(cles)):
        c0, c1 = cles[i - 1], cles[i]
        if "k" in c0 and "k" in c1:
            dt = max(0.02, c1["t"] - c0["t"])
            cout += 0.4 * max(0.0, abs(c1["k"] - c0["k"]) - 70.0) + 0.2 * max(0.0, abs(c1["phi"] - c0["phi"]) - 45.0)
    info = dict(dir_fin=round(math.degrees(math.atan2(dfin.y, dfin.x))), fil=fil, deb=deb, fin=fin, rap=rmoy, saut=max(sauts), hors=hors, a=tuple(round(v, 2) for v in a), b=tuple(round(v, 2) for v in b))
    return cout, info


def main():
    random.seed(int(ARGS.get("graine", "7")))
    cles = [dict(c) for c in CLES]
    # départ : solution du solveur (poser) pour chaque clé non fixée
    AB.PREC[0] = None
    for i, c in enumerate(cles):
        r = AB.poser(c)
        if i in INDICES and "k" not in c:
            c.update(k=r["torsion"], f=r["flexion"], r=r["inclinaison"], phi=AB.PREC[0][3])
    for i in INDICES:
        for k in ("k", "f", "r", "phi"):
            cles[i][k] = int(cles[i].get(k, 0))
    best, info = evaluer(cles)
    print("OPTIM depart cout %.1f %s" % (best, info))
    LIM = dict(k=(-95, 95), f=(-60, 70), r=(-40, 28), phi=(-90, 90))
    pas0 = dict(k=20, f=15, r=8, phi=15)
    n = int(ARGS.get("iter", "600"))
    for it in range(n):
        ech = 1.0 if it < n * 0.5 else 0.5
        essai = [dict(c) for c in cles]
        for _ in range(random.choice((1, 1, 2, 3))):
            i = random.choice(INDICES)
            k = random.choice(("k", "f", "r", "phi"))
            v = essai[i][k] + random.choice((-1, 1)) * max(1, int(round(pas0[k] * ech * random.random())))
            essai[i][k] = max(LIM[k][0], min(LIM[k][1], v))
            # la tension suit l'armé de près (même articulations, petit écart)
        c, inf = evaluer(essai)
        if c < best:
            best, info, cles = c, inf, essai
            print("OPTIM it %d cout %.1f %s" % (it, best, info))
    print("OPTIM final cout %.1f %s" % (best, info))
    for i in INDICES:
        c = cles[i]
        print("OPTIM %s k=%d, f=%d, r=%d, phi=%d" % (c["nom"], c["k"], c["f"], c["r"], c["phi"]))


main()
