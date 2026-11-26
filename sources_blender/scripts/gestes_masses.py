# COUPS DES MASSES ET MARTEAUX par CAPTURES (branche combat/coups_masses_marteaux, 2026-11-26 ; retour utilisateur : « les coups
# sont pourris, le poignet et les bras ne suivent pas le mouvement, ça n'a RIEN de naturel »).
#
#   blender.exe -b sources_blender/bras_fps.blend --python sources_blender/scripts/gestes_masses.py -- --godot [--clips=ms_c,gm_a]
#
# Remplace, pour les profils « masse », « marteau » et « grand_marteau » (GestesLourds), les clips à poses ÉCRITES À LA MAIN de
# gestes_lourds.py (m_a, m_b, m_c, charge_m, lourd_m, gm_a, charge_gm, lourd_gm : gardés dans bras_lourds.tres, non modifiés)
# par des CAPTURES RETARGETÉES, méthode unique validée (coups d'épée v6, claymore v6, hache par captures) :
# anim_bras_epee.creer_action_mixamo — directions du bras et de l'avant-bras de la capture, main en orientation ANATOMIQUE de la
# main capturée, poignet résolu DANS des butées et verrouillé autour de la tenue, torsion de l'avant-bras qui absorbe la rotation,
# arc guidé pendant la frappe, creux de poids, fondu en S depuis / vers la tenue. AUCUNE pose écrite : seuls la plage de capture,
# la TABLE DE TEMPS (lecture, le poids : armé plus long, frappe sèche, retour amorti), le cadrage (rotation rigide du bras autour
# de l'épaule) et l'amplitude changent.
# Sortie : assets/animations/bras_masses.tres (bibliothèque À PART, préfixe « masse/ » dans AnimateurBras) — bras_lourds.tres
# (haches, tenues) n'est pas réécrit : pas de conflit avec le chantier des haches.
#
# Une main (masse cloutée, gourdin, marteau de guerre) : sources coups_mixamo.json (30 i/s) —
#   ms_a crochet droite -> gauche   « Stable Sword Outward Slash » (revers)    armé 20-23 main à droite, rapide 23 -> 28
#   ms_b revers gauche -> droite    « Stable Sword Inward Slash » (interieur)  armé 30-32 main à gauche, rapide 32 -> 39,5
#   ms_c écrasement par-dessus      « Standing Melee Attack Downward » (vertical) armé 19-20 main derrière l'épaule droite,
#                                    rapide 21 -> 27,5 (pic 8,8 m/s), arrêt sec
#   charge_ms / lourd_ms            même écrasement, armé tenu pendant la charge (2 -> 21), frappe 21 -> 27, grand suivi
# Deux mains (grand marteau) : sources coups_2mains.json (« Great Sword Pack », vraies prises à deux mains, buste entier) —
#   gm_a6 grand vertical            « great sword slash (2) » 1er coup, armé 18, rapide 20 -> 28,8
#   gm_b6 diagonale                 « great sword slash » armé 16, rapide 16 -> 23
#   charge_gm6 / lourd_gm6          « great sword jump attack » : armé haut 25 (tenu pendant la charge), le corps entier
#                                    retombe 27 -> 36 (frappe tête au sol)
import os, sys, math, json

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OPT = {a.lstrip("-").partition("=")[0]: a.partition("=")[2] for a in ARGV}


def _charger(nom):
    src = open(os.path.join(ICI, nom), encoding="utf-8").read()
    src = src[: src.rstrip().rfind("main()")]
    ns = {"__file__": os.path.join(ICI, nom), "__name__": nom[:-3]}
    exec(compile(src, nom, "exec"), ns)
    return ns


# ---------------------------------------------------------------------------------------------------------------------------
# UNE MAIN : espace de noms de gestes_lourds.py (tenue repos_m, solveur des gestes lourds), lu tel quel
L = _charger("gestes_lourds.py")
NS = L["NS"]
G = L["G"]

# Poignet : critère du brief (2026-11-26) — inclinaison radiale / cubitale ≤ 25°, flexion / extension ≤ 60° à TOUTE image.
# LIM_MX : butées du solveur pour ces clips ; POIGNET : verrou autour de la tenue (même logique que l'épée v6 et la hache).
LIM_MX_M = dict(torsion=(-85, 85), flexion=(-50, 50), inclinaison=(-24, 18))
RACCORD_M = 1.0
# tenue de bord des clips : repos_m, poignet re-résolu dans les butées ci-dessus (même poing, même direction du manche : le
# solveur garde la tenue la plus proche dont le poignet est anatomique ; repos_m d'origine : inclinaison cubitale ~-40°)
REPOS_M6 = dict(L["REPOS_M"], nom="repos_m6")


def _poignet_autour(k, f, r):
    return ((max(f - 17, -50), min(f + 19, 50)), (max(r - 2, -24), min(r + 14, 18)))


S = dict(ref=0, decalage=(0.0, 0.06, -0.15), echelle_epaule=0.7)
CLIPS_M = {
    # crochet droite -> gauche : « outward slash », la main part à droite à hauteur d'épaule, traverse devant le buste
    "ms_a": dict(S, source="revers", centre=25, amplitude=0.6, cadrage=(0, 30, -15),
                 temps=[(14, 0.0), (19, 0.12), (22.5, 0.22), (23.5, 0.26), (27.5, 0.40), (28.5, 0.48), (30, 0.60), (30, 0.80)],
                 fondu=(0.22, 0.50), plein=(0.22, 0.56), arc=(0.26, 0.40, 0.85), creux=0.04),
    # revers gauche -> droite : « inward slash », armé sur l'épaule gauche, la tête balaie vers la droite
    "ms_b": dict(S, source="interieur", centre=35, amplitude=0.6, cadrage=(0, 30, 15),
                 temps=[(24, 0.0), (29, 0.12), (31.5, 0.22), (32.5, 0.26), (38.5, 0.40), (39.5, 0.48), (41, 0.60), (41, 0.80)],
                 fondu=(0.22, 0.50), plein=(0.22, 0.56), arc=(0.26, 0.40, 0.85), creux=0.04),
    # écrasement par-dessus l'épaule droite : « Standing Melee Attack Downward » (cadrage du coup puissant de l'épée v6)
    "ms_c": dict(S, source="vertical", centre=23, amplitude=0.45, cadrage=(30, -37, 0),
                 temps=[(10, 0.0), (17, 0.14), (19.5, 0.24), (21, 0.28), (27, 0.42), (28, 0.50), (29, 0.62), (29, 0.84)],
                 fondu=(0.24, 0.52), plein=(0.24, 0.58), arc=(0.28, 0.42, 0.85), creux=0.05),
    # puissante : même écrasement, armé tenu pendant la charge
    "charge_ms": dict(S, source="vertical", centre=23, amplitude=0.45, cadrage=(30, -37, 0),
                      temps=[(2, 0.0), (19, 0.34), (21, 0.62)], fondu=(0.34, 0.62), plein=(0.34, 0.62)),
    "lourd_ms": dict(S, source="vertical", centre=23, amplitude=0.45, cadrage=(30, -37, 0),
                     temps=[(21, 0.0), (21.5, 0.06), (26.5, 0.22), (27.5, 0.32), (29, 0.48), (29, 0.96)],
                     fondu=(0.0, 0.48), plein=(0.0, 0.55), arc=(0.06, 0.22, 0.85), creux=0.06),
}
MARQUEURS_M = {
    "ms_a": {"arme": 0.22, "frappe": 0.26, "fin_frappe": 0.40, "suivi": 0.48, "fin": 0.80},
    "ms_b": {"arme": 0.22, "frappe": 0.26, "fin_frappe": 0.40, "suivi": 0.48, "fin": 0.80},
    "ms_c": {"arme": 0.24, "frappe": 0.28, "fin_frappe": 0.42, "suivi": 0.50, "fin": 0.84},
    "charge_ms": {"arme": 0.34, "fin": 0.62},
    "lourd_ms": {"arme": 0.05, "frappe": 0.06, "fin_frappe": 0.22, "suivi": 0.32, "fin": 0.96},
}

# ---------------------------------------------------------------------------------------------------------------------------
# DEUX MAINS : réglages repris de la claymore v6 (gestes_2mains.py : tenue repos_2m, poignet verrouillé POIGNET_2M, LIM_MX_2M) ;
# le grand marteau partage ses tenues (repos_2m, garde_2m...) : bord des clips = repos_2m exacte.
POIGNET_GM = ((-28, 4), (-24, -6))
LIM_MX_GM = dict(torsion=(-85, 85), flexion=(-55, 55), inclinaison=(-24, 18))
S2 = dict(ref=0, decalage=(0.0, 0.08, -0.12), echelle_epaule=0.6, poignet=POIGNET_GM, lim_mx=LIM_MX_GM)
CLIPS_GM = {
    "gm_a6": dict(S2, source="gs_slash_2", centre=26, amplitude=0.55, cadrage=(0, 30, 25),
                 temps=[(10, 0.0), (16, 0.14), (18, 0.24), (21, 0.30), (27.5, 0.44), (28.5, 0.52), (29.5, 0.66), (29.5, 0.92)],
                 fondu=(0.24, 0.56), plein=(0.24, 0.62), arc=(0.30, 0.44, 0.85), creux=0.05),
    "gm_b6": dict(S2, source="gs_slash", centre=20, amplitude=0.55, cadrage=(0, 35, -10),
                 temps=[(8, 0.0), (13, 0.14), (15.5, 0.24), (16.5, 0.30), (22, 0.44), (23, 0.52), (24, 0.66), (24, 0.92)],
                 fondu=(0.24, 0.56), plein=(0.24, 0.62), arc=(0.30, 0.44, 0.85), creux=0.05),
    "charge_gm6": dict(S2, source="gs_jump_attack", centre=31, amplitude=0.55, cadrage=(0, 25, 10),
                      temps=[(14, 0.0), (23, 0.38), (25.5, 0.70)], fondu=(0.38, 0.70), plein=(0.38, 0.70)),
    "lourd_gm6": dict(S2, source="gs_jump_attack", centre=31, amplitude=0.55, cadrage=(0, 25, 10),
                     temps=[(25.5, 0.0), (27, 0.08), (35.5, 0.26), (36.5, 0.36), (38, 0.54), (38, 1.04)],
                     fondu=(0.0, 0.54), plein=(0.0, 0.62), arc=(0.08, 0.26, 0.85), creux=0.07),
}
MARQUEURS_GM = {
    "gm_a6": {"arme": 0.24, "frappe": 0.30, "fin_frappe": 0.44, "suivi": 0.52, "fin": 0.92},
    "gm_b6": {"arme": 0.24, "frappe": 0.30, "fin_frappe": 0.44, "suivi": 0.52, "fin": 0.92},
    "charge_gm6": {"arme": 0.38, "fin": 0.70},
    "lourd_gm6": {"arme": 0.07, "frappe": 0.08, "fin_frappe": 0.26, "suivi": 0.36, "fin": 1.04},
}

_essai = OPT.get("essai", "")   # --essai=<fichier.json> : réglages sans modifier ce fichier
for _n, _r in (json.load(open(_essai, encoding="utf-8")) if _essai else {}).items():
    _m = _r.pop("marqueurs", None)
    _t = CLIPS_M if _n in CLIPS_M else CLIPS_GM
    _t[_n].update({k: (tuple(tuple(x) if isinstance(x, list) else x for x in v) if isinstance(v, list) else v) for k, v in _r.items()})
    if _m:
        (MARQUEURS_M if _n in MARQUEURS_M else MARQUEURS_GM)[_n] = dict(_m)


def tete_ecran(ns, longueur=0.55):
    W = ns["CAM_DE_B"] @ ns["A"].pose.bones["hand_r"].matrix @ ns["PRISE_D"]
    from mathutils import Vector
    p = W @ Vector((0, ns["MILIEU_POIGNEE"], 0))
    t = W @ Vector((0, ns["MILIEU_POIGNEE"] + longueur, 0))
    tv = G.TAN_V
    e = lambda v: (v.x / max(-v.z, 1e-3) / (tv * 16 / 9), v.y / max(-v.z, 1e-3) / tv)
    return e(p), e(t)


def mesurer(ns, nom, act, longueur, mq, freq=60):
    """Tête de l'arme à l'écran (dans le cadre ? arc continu ?) et pires sauts de rotation des os par image."""
    ns["A"].animation_data.action = act
    pts, rot = [], []
    prec = None
    t = 0.0
    while t <= longueur + 1e-6:
        f = t * ns["FPS"]
        ns["scene"].frame_set(int(math.floor(f)), subframe=f - math.floor(f))
        pts.append((t, tete_ecran(ns)[1]))
        q = {b: ns["A"].pose.bones[b].matrix.to_quaternion() for b in ("upperarm_r", "lowerarm_r", "hand_r")}
        if prec is not None:
            rot.append(max(min(a, 360.0 - a) for a in (math.degrees(q[b].rotation_difference(prec[b]).angle) for b in q)))
        prec = q
        t += 1.0 / freq
    vis = sum(1 for _, e in pts if abs(e[0]) < 1.0 and abs(e[1]) < 1.0)
    # retour en arrière pendant la frappe : la tête recule sur sa propre trajectoire (produit scalaire de pas successifs < 0)
    arr = 0
    if "frappe" in mq:
        seg = [e for tt, e in pts if mq["frappe"] <= tt <= mq["fin_frappe"]]
        for a, b, c in zip(seg, seg[1:], seg[2:]):
            u = (b[0] - a[0], b[1] - a[1])
            v = (c[0] - b[0], c[1] - b[1])
            if u[0] * v[0] + u[1] * v[1] < 0 and math.hypot(*u) > 0.01 and math.hypot(*v) > 0.01:
                arr += 1
    xs = [e[0] for _, e in pts]
    ys = [e[1] for _, e in pts]
    print("MASSES %-10s tete dans le cadre %d/%d | retours en arriere %d | x %.2f..%.2f y %.2f..%.2f | saut os max %.1f deg/img" % (
        nom, vis, len(pts), arr, min(xs), max(xs), min(ys), max(ys), max(rot or [0.0])))


def creer_une_main(nom):
    garde_repos, garde_lim, garde_raccord = NS["REPOS"], dict(NS["LIM_MX"]), NS["RACCORD_MX"]
    garde_lt, garde_li = NS["LIM_TORSION_L"], NS["LIM_INCL_L"]
    try:
        NS["LIM_INCL_L"] = (-24, 18)   # la tenue de bord, résolue dans les mêmes butées anatomiques que les coups
        NS["PREC"][0] = None
        NS["poser"](dict(REPOS_M6))
        k, f, r = NS["PREC"][0][:3]
        NS["REPOS"] = dict(REPOS_M6, k=k, f=f, r=r, tenue_exacte=True)
        print("TENUE repos_m6 k %d f %d r %d" % (k, f, r))
        spec = dict(CLIPS_M[nom])
        spec.setdefault("poignet", _poignet_autour(k, f, r))
        NS["LIM_MX"].update(LIM_MX_M)
        NS["RACCORD_MX"] = RACCORD_M
        return NS["creer_action_mixamo"](nom, spec)
    finally:
        NS["RACCORD_MX"] = garde_raccord
        NS["REPOS"] = garde_repos
        NS["LIM_MX"].clear()
        NS["LIM_MX"].update(garde_lim)
        NS["LIM_TORSION_L"], NS["LIM_INCL_L"] = garde_lt, garde_li


def _poser_tenue_m(c, cote="r"):
    if c.get("tenue_exacte"):
        NS["PREC"][0] = None
        return L["_poser_diag"](dict(REPOS_M6), cote)
    return L["_poser_diag"](c, cote)


NS["poser"] = _poser_tenue_m


def main():
    clips = [c for c in OPT.get("clips", "").split(",") if c]
    NS["poings"]()
    NS["poser_torche"]()
    actions = {}
    if not clips:   # tenue de repos des masses / marteaux (bord exact des clips), poignet dans les mêmes butées
        garde_li = NS["LIM_INCL_L"]
        NS["LIM_INCL_L"] = (-24, 18)
        NS["PREC"][0] = None
        act = NS["creer_action"]("repos_m6", [G.cle(REPOS_M6, 0.0), G.cle(REPOS_M6, 0.5)])
        NS["LIM_INCL_L"] = garde_li
        actions["repos_m6"] = (act, 0.5)
    for nom in [n for n in CLIPS_M if not clips or n in clips]:
        actions[nom] = creer_une_main(nom)
        mesurer(NS, nom, actions[nom][0], actions[nom][1], MARQUEURS_M[nom])
    noms_gm = [n for n in CLIPS_GM if not clips or n in clips]
    if noms_gm:
        D = _charger("gestes_2mains.py")
        N2 = D["NS"]
        D["_preparer_mx_2m"]()
        print("TENUE repos_2m", N2["REPOS"].get("k"), N2["REPOS"].get("f"), N2["REPOS"].get("r"))
        for nom in noms_gm:
            spec = dict(CLIPS_GM[nom])
            N2["LIM_MX"].update(spec.get("lim_mx", LIM_MX_GM))
            actions[nom] = N2["creer_action_mixamo"](nom, spec)
            mesurer(N2, nom, actions[nom][0], actions[nom][1], MARQUEURS_GM[nom])
    mq = dict(MARQUEURS_M)
    mq.update(MARQUEURS_GM)
    for nom, x in mq.items():
        print("MARQUEURS", nom, x)
    if "godot" in OPT:
        if clips:
            raise SystemExit("--godot réécrit toute la bibliothèque : pas avec --clips")
        NS["MARQUEURS"] = mq
        NS["ecrire_godot"](os.path.join(NS["BASE"], "assets", "animations", "bras_masses.tres"), actions)
    print("FIN OK")


main()
