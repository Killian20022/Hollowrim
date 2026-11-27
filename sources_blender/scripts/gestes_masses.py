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
LIM_MX_M = dict(torsion=(-85, 85), flexion=(-50, 50), inclinaison=(int(OPT.get("incl_coups", "-8")), 18))
RACCORD_M = 1.0
# tenue de bord des clips : repos_m, poignet re-résolu dans les butées ci-dessus (même poing, même direction du manche : le
# solveur garde la tenue la plus proche dont le poignet est anatomique ; repos_m d'origine : inclinaison cubitale ~-40°)
REPOS_M6 = dict(L["REPOS_M"], nom="repos_m6")


# butées de la TENUE (inclinaison) : poignet presque droit, le manche reste dans la prise naturelle du poing (critère du brief :
# angle manche / avant-bras 70-110°) ; mesuré : à -24 (butée des coups) le manche tombait à 50-69° de l'avant-bras
INCL_TENUE = (int(OPT.get("incl_min", "0")), 18)


def _poignet_autour(k, f, r):
    return ((max(f - 17, -50), min(f + 19, 50)), (max(r - 6, -24), min(r + 10, 18)))


# épaule avancée de 0,30 m (vue joueur) : à -0,15 la tête de la masse passait DERRIÈRE la caméra à l'armé du revers et du crochet
# (profondeur mesurée -0,08 / -0,01 m : grosse tête cloutée plein écran) ; à -0,30 : 0,07-0,39 m, hors champ ou loin de l'œil
S = dict(ref=0, decalage=(0.0, 0.06, -0.30), echelle_epaule=0.7)
CLIPS_M = {
    # crochet droite -> gauche : « outward slash », la main part à droite à hauteur d'épaule, traverse devant le buste
    # cadrage passe 2 (tête lisible à l'impact 9/9, mesurée par _tete_lisible) : bras tourné de 25° vers la gauche, relevé de 20°
    # passe 3 (« plus un coup plat ») : AUTRE capture, « Sword And Shield Slash (1) » (diagonale haut-droite -> bas-gauche, la
    # capture du coup 1 de l'épée v6), armé 14-16,5, rapide 17,5 -> 21, roulis du bras +20° : la tête plonge à ~41° à l'écran
    # (« revers » : 11°), tête lisible 9/9 à l'impact, à 0,37 m de l'œil au plus près
    "ms_a": dict(S, source="slash_1", centre=19, amplitude=0.5, cadrage=(25, 30, 20),
                 temps=[(10, 0.0), (14, 0.14), (16.5, 0.24), (17.5, 0.28), (21, 0.42), (22.5, 0.50), (23, 0.62), (23, 0.84)],
                 fondu=(0.24, 0.52), plein=(0.24, 0.58), arc=(0.28, 0.42, 0.85), creux=0.04),
    # revers gauche -> droite : « inward slash », armé sur l'épaule gauche, la tête balaie vers la droite
    # passe 2 : bras relevé de 60° et tourné de 15° vers la droite, frappe lue à partir de l'image 33,4 (la tête montait encore de
    # sous le cadre aux images 32,5-33) : tête lisible à l'impact 9/9
    "ms_b": dict(S, source="interieur", centre=35, amplitude=0.45, decalage=(0.05, 0.06, -0.40), cadrage=(-15, 60, 15),
                 temps=[(24, 0.0), (29, 0.12), (32.2, 0.22), (33.4, 0.26), (38.6, 0.40), (39.8, 0.48), (41, 0.60), (41, 0.80)],
                 fondu=(0.22, 0.50), plein=(0.22, 0.56), arc=(0.26, 0.40, 0.85), creux=0.04),
    # écrasement par-dessus l'épaule droite : « Standing Melee Attack Downward » (cadrage du coup puissant de l'épée v6)
    "ms_c": dict(S, source="vertical", centre=23, amplitude=0.45, cadrage=(30, -37, 0),
                 temps=[(10, 0.0), (17, 0.14), (19.5, 0.24), (21, 0.28), (27, 0.42), (28, 0.50), (29, 0.62), (29, 0.84)],
                 fondu=(0.24, 0.52), plein=(0.24, 0.58), arc=(0.28, 0.42, 0.85), creux=0.05),
    # puissante : même écrasement, armé tenu pendant la charge
    "charge_ms": dict(S, source="vertical", centre=23, amplitude=0.45, cadrage=(30, -37, 0),
                      temps=[(2, 0.0), (19, 0.34), (21, 0.62)], fondu=(0.34, 0.62), plein=(0.34, 0.62)),
    "lourd_ms": dict(S, source="vertical", centre=23, amplitude=0.45, cadrage=(30, -37, 0),
                     temps=[(21, 0.0), (21.5, 0.06), (26.5, 0.22), (27.5, 0.30), (29, 0.40), (29, 0.64)],
                     fondu=(0.0, 0.40), plein=(0.0, 0.46), arc=(0.06, 0.22, 0.85), creux=0.06),
}
MARQUEURS_M = {
    "ms_a": {"arme": 0.24, "frappe": 0.28, "fin_frappe": 0.42, "suivi": 0.50, "fin": 0.84},
    "ms_b": {"arme": 0.22, "frappe": 0.26, "fin_frappe": 0.40, "suivi": 0.48, "fin": 0.80},
    "ms_c": {"arme": 0.24, "frappe": 0.28, "fin_frappe": 0.42, "suivi": 0.50, "fin": 0.84},
    "charge_ms": {"arme": 0.34, "fin": 0.62},
    "lourd_ms": {"arme": 0.05, "frappe": 0.06, "fin_frappe": 0.22, "suivi": 0.30, "fin": 0.64},
}

# ---------------------------------------------------------------------------------------------------------------------------
# DEUX MAINS : réglages repris de la claymore v6 (gestes_2mains.py : tenue repos_2m, poignet verrouillé POIGNET_2M, LIM_MX_2M) ;
# le grand marteau partage ses tenues (repos_2m, garde_2m...) : bord des clips = repos_2m exacte.
POIGNET_GM = ((-28, 4), (-22, -2))
INCL_TENUE_GM = (int(OPT.get("incl_gm", "-22")), 32)
LIM_MX_GM = dict(torsion=(-85, 85), flexion=(-55, 55), inclinaison=(-24, 18))
# décalage de l'épaule vers l'avant (-0,25 m) : à l'armé, le bout du long manche passait à 33 cm de l'œil (gros plan brun en vue
# joueur) ; à -0,25 et amplitude 0,45 : 39 cm, la tête sort encore par le haut de l'écran à l'armé
S2 = dict(ref=0, decalage=(0.0, 0.0, -0.25), echelle_epaule=0.6, poignet=POIGNET_GM, lim_mx=LIM_MX_GM)
CLIPS_GM = {
    # restes de l'exe 8 (défaut B, 2026-11-27) : à amplitude 0,45, l'armé de « great sword slash (2) » et de la « jump attack »
    # portait le fer du marteau AU-DESSUS ET DERRIÈRE l'œil (coins du fer jusqu'à 94° au-dessus du bord haut, fer entier hors champ
    # 87 images en jeu, outils/mesure_tete_gm.gd). Mêmes captures, ramenées vers leur image d'impact : amplitude 0,22 (diagonale
    # 0,30, puissante 0,25), armé de la puissante abaissé par le cadrage (tangage -45, charge et frappe identiques : pas de saut au
    # raccord). Avec le cadrage de la tête en jeu (mains._cadrer_tete, <= 8°), le fer ne dépasse qu'au sommet de l'armé (<= 10 images,
    # <= 9°), jamais pendant la frappe ; mains plus visibles qu'avec un cadrage de 16° (décision du 2026-11-27 : armé lourd, mains vues).
    "gm_a6": dict(S2, source="gs_slash_2", centre=26, amplitude=0.22, cadrage=(0, 30, 25),
                 temps=[(10, 0.0), (16, 0.12), (18, 0.20), (21, 0.24), (27.5, 0.36), (28.5, 0.43), (29.5, 0.52), (29.5, 0.70)],
                 fondu=(0.20, 0.45), plein=(0.20, 0.50), arc=(0.24, 0.36, 0.85), creux=0.05),
    "gm_b6": dict(S2, source="gs_slash", centre=20, amplitude=0.30, cadrage=(0, 35, -10),
                 temps=[(8, 0.0), (13, 0.12), (15.5, 0.20), (16.5, 0.24), (22, 0.36), (23, 0.43), (24, 0.52), (24, 0.70)],
                 fondu=(0.20, 0.45), plein=(0.20, 0.50), arc=(0.24, 0.36, 0.85), creux=0.05),
    "charge_gm6": dict(S2, source="gs_jump_attack", centre=31, amplitude=0.25, cadrage=(0, -45, 10),
                      temps=[(14, 0.0), (23, 0.38), (25.5, 0.70)], fondu=(0.38, 0.70), plein=(0.38, 0.70)),
    "lourd_gm6": dict(S2, source="gs_jump_attack", centre=31, amplitude=0.25, cadrage=(0, -45, 10),
                     temps=[(25.5, 0.0), (27, 0.08), (35.5, 0.22), (36.5, 0.30), (38, 0.40), (38, 0.60)],
                     fondu=(0.0, 0.40), plein=(0.0, 0.46), arc=(0.08, 0.22, 0.85), creux=0.07),
}
MARQUEURS_GM = {
    "gm_a6": {"arme": 0.20, "frappe": 0.24, "fin_frappe": 0.36, "suivi": 0.43, "fin": 0.70},
    "gm_b6": {"arme": 0.20, "frappe": 0.24, "fin_frappe": 0.36, "suivi": 0.43, "fin": 0.70},
    "charge_gm6": {"arme": 0.38, "fin": 0.70},
    "lourd_gm6": {"arme": 0.07, "frappe": 0.08, "fin_frappe": 0.22, "suivi": 0.30, "fin": 0.60},
}

_essai = OPT.get("essai_masses", "")   # --essai_masses=<fichier.json> : réglages sans modifier ce fichier
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


def _tete_lisible(ns):
    """Tête de l'arme dans le champ (marge 5 %), à plus de 15 cm de l'œil, et pas cachée par le poing ni l'avant-bras
    (projetée à moins de 0,16 écran du segment poing-coude ET plus loin qu'eux)."""
    from mathutils import Vector
    C = ns["CAM_DE_B"]
    W = C @ ns["A"].pose.bones["hand_r"].matrix @ ns["PRISE_D"]
    tete = W @ Vector((0, ns["MILIEU_POIGNEE"] + 0.5, 0))
    poing = W @ Vector((0, ns["MILIEU_POIGNEE"], 0))
    coude = C @ ns["A"].pose.bones["lowerarm_r"].head
    tv = G.TAN_V
    e = lambda v: Vector((v.x / max(-v.z, 1e-3) / (tv * 16 / 9), v.y / max(-v.z, 1e-3) / tv))
    et = e(tete)
    if "detail" in OPT:
        print("DET tete (%.2f,%.2f) z %.2f poing (%.2f,%.2f) z %.2f" % (et.x, et.y, -tete.z, e(poing).x, e(poing).y, -poing.z))
    if -tete.z < 0.15:
        return False
    if abs(et.x) > 0.95 or abs(et.y) > 0.95:
        return False
    a, b = e(poing), e(coude) if -coude.z > 0.05 else e(poing)
    ab = b - a
    u = max(0.0, min(1.0, (et - a).dot(ab) / max(ab.length_squared, 1e-9)))
    d = (a + ab * u - et).length
    prof_bras = min(-poing.z, -coude.z)
    return not (d < 0.16 and -tete.z > prof_bras)


def mesurer(ns, nom, act, longueur, mq, freq=60):
    """Tête de l'arme à l'écran (dans le cadre ? arc continu ?) et pires sauts de rotation des os par image."""
    ns["A"].animation_data.action = act
    pts, rot, pom, tz, imp = [], [], [], [], []
    prec = None
    t = 0.0
    while t <= longueur + 1e-6:
        f = t * ns["FPS"]
        ns["scene"].frame_set(int(math.floor(f)), subframe=f - math.floor(f))
        # tête du grand marteau : à ~0,95 m du poing (le fer du long marteau), pas 0,55 m (masses) ; --tete_long=x pour les essais
        pts.append((t, tete_ecran(ns, float(OPT.get("tete_long", "0.95" if nom in CLIPS_GM else "0.55")))[1]))
        W = ns["CAM_DE_B"] @ ns["A"].pose.bones["hand_r"].matrix @ ns["PRISE_D"]
        from mathutils import Vector
        pom.append(-(W @ Vector((0, ns["MILIEU_POIGNEE"] - float(OPT.get("bout", "0.35")), 0))).z)
        imp.append((t, _tete_lisible(ns)))
        tz.append(min(-(W @ Vector((0, ns["MILIEU_POIGNEE"] + l, 0))).z for l in (0.3, 0.45, 0.6)))
        q = {b: ns["A"].pose.bones[b].matrix.to_quaternion() for b in ("upperarm_r", "lowerarm_r", "hand_r")}
        if prec is not None:
            rot.append(max(min(a, 360.0 - a) for a in (math.degrees(q[b].rotation_difference(prec[b]).angle) for b in q)))
        prec = q
        t += 1.0 / freq
    vis = sum(1 for _, e in pts if abs(e[0]) < 1.0 and abs(e[1]) < 1.0)
    if "frappe" in mq:
        okf = sum(1 for (tt, ok) in imp if mq["frappe"] - 1e-6 <= tt <= mq["fin_frappe"] + 1e-6 and ok)
        nf = sum(1 for (tt, ok) in imp if mq["frappe"] - 1e-6 <= tt <= mq["fin_frappe"] + 1e-6)
        seg = [e for tt, e in pts if mq["frappe"] - 1e-6 <= tt <= mq["fin_frappe"] + 1e-6]
        dx, dy = seg[-1][0] - seg[0][0], seg[-1][1] - seg[0][1]
        pente = math.degrees(math.atan2(abs(dy), abs(dx) * 16 / 9)) if seg else 0.0
        print("MASSES %-10s IMPACT tete lisible %d/%d | pente de la frappe a l'ecran %.0f deg (0 = plat, 90 = vertical)" % (nom, okf, nf, pente))
    print("MASSES %-10s bout du manche (35 cm sous le poing) : profondeur min %.2f m | tete profondeur min %.2f m" % (nom, min(pom), min(tz)))
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
        NS["LIM_INCL_L"] = INCL_TENUE   # la tenue de bord, résolue dans des butées anatomiques serrées
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
        NS["LIM_INCL_L"] = INCL_TENUE
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
        # tenue propre au grand marteau (repos_gm6) : la tenue repos_2m de la claymore (inclinaison cubitale -44°, mesurée) re-résolue
        # dans les butées du critère (|inclinaison| <= 25°) ; même poing, même manche visé, poignet anatomique
        # cadrage du repos 1P (passe 3) : la lame de repos_2m (0,20 ; 0,88 ; -0,42) laissait la tête du long marteau coupée par le bord
        # haut de l'écran ; manche plus incliné vers l'avant-droite, tête dans le cadre (option lame_gm=x,y,z pour les essais), même poing, même prise
        LAME_GM = tuple(float(v) for v in OPT.get("lame_gm", "0.34,0.55,-0.76").split(","))
        REPOS_GM6 = dict(D["REPOS_2M"], nom="repos_gm6", lame=LAME_GM)
        _orig = D["_poser"]

        def _tenue_gm6(cote="r"):
            garde = N2["LIM_INCL_L"], N2["LIM_INCL"]
            N2["LIM_INCL_L"] = N2["LIM_INCL"] = INCL_TENUE_GM
            try:
                N2["PREC"][0] = None
                return _orig(dict(REPOS_GM6), cote)
            finally:
                N2["LIM_INCL_L"], N2["LIM_INCL"] = garde

        def _poser_gm(c, cote="r"):
            if c.get("tenue_exacte"):
                return _tenue_gm6(cote)
            return D["_poser_suivi"](c, cote)
        N2["poser"] = _poser_gm
        _tenue_gm6()
        k, f, r = N2["PREC"][0][:3]
        N2["REPOS"] = dict(REPOS_GM6, k=k, f=f, r=r, tenue_exacte=True)
        print("TENUE repos_gm6 k %d f %d r %d" % (k, f, r))
        if not clips:
            act = N2["bpy"].data.actions.new("repos_gm6")
            act.use_fake_user = True
            N2["A"].animation_data.action = act
            _tenue_gm6()
            for t_ in (0.0, 0.5):
                for nb in N2["OS_ANIMES"]:
                    pb = N2["A"].pose.bones[nb]
                    pb.rotation_quaternion = pb.matrix_basis.to_quaternion()
                    pb.keyframe_insert("rotation_quaternion", frame=t_ * N2["FPS"], group=nb)
                    if nb == "clavicle_r":
                        pb.location = pb.matrix_basis.to_translation()
                        pb.keyframe_insert("location", frame=t_ * N2["FPS"], group=nb)
            actions["repos_gm6"] = (act, 0.5)
        for nom in noms_gm:
            spec = dict(CLIPS_GM[nom])
            spec["poignet"] = _poignet_autour(k, f, r)   # verrou autour de la tenue repos_gm6
            N2["LIM_MX"].update(spec.get("lim_mx", LIM_MX_GM))
            garde_r = N2["RACCORD_MX"]
            N2["RACCORD_MX"] = RACCORD_M
            actions[nom] = N2["creer_action_mixamo"](nom, spec)
            N2["RACCORD_MX"] = garde_r
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
