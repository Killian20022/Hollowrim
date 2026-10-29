# Gestes de magie FPS retargetés depuis les captures Mixamo (« Magic Spell Pack ») -> data/magie/gestes_mixamo.json.
#
#   python3 sources_blender/scripts/gestes_magie.py [--source=sources_blender/mixamo/gestes_magie_mixamo.json] [--detail]
#
# Même méthode que les coups d'épée (anim_bras_epee.py, creer_action_mixamo) : la capture pilote le corps entier, la caméra
# est la tête (orientation fixe : celle du joueur), on garde les DIRECTIONS épaule -> coude -> poignet et le repère
# ANATOMIQUE de la main (poignet -> jointures, auriculaire -> index), posés sur NOTRE bras FPS (épaule et longueurs mesurées
# dans le jeu : outils/captures_gestes_magie.gd --bras). Puis, par clip :
#   - amplitude : directions et main ramenées vers l'image « centre » (le geste garde sa forme, l'arc reste dans le champ) ;
#   - cadrage : rotation rigide du bras autour de l'épaule (lacet, tangage, roulis) et décalage du poignet ;
#   - cadre : la paume est gardée DANS l'écran (fov 72°, 16:9) et devant l'œil ;
#   - poignet : flexion / extension et inclinaison radiale / cubitale résolues dans les BUTÉES anatomiques par rapport à
#     l'avant-bras réellement obtenu par l'IK à deux os (pôle = coude de la capture) ;
#   - fondu depuis / vers la pose de repos magie actuelle (PosesIncantation « repos », inchangée).
# Sortie : pour chaque geste, chaque main et chaque phase (entree, tenue, boucle, depart, fin), des poses au format de
# PosesIncantation (pos, paume, doigts, fermeture) + « coude » (pôle de l'IK), lues par scripts/magie/gestes_magie.gd.
# La main gauche qui joue une piste de main droite (ou l'inverse) prend le MIROIR de la capture (X -> -X).
import json, math, os, sys

ARGS = {}
for a in sys.argv[1:]:
    k, _, v = a.lstrip("-").partition("=")
    ARGS[k] = v
BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# --- bras FPS du jeu (repère caméra : +X droite, +Y haut, -Z devant), mesuré par captures_gestes_magie.gd --bras ---------
EPAULE = {"gauche": (-0.2120, -0.3143, -0.092), "droite": (0.2120, -0.3143, -0.092)}
L1, L2 = 0.2511, 0.2436
# pose de repos magie (PosesIncantation.POSES["repos"], main gauche ; la droite en miroir) et pôle du coude par défaut
# (main_sort.gd : coude à (-0.75, -0.55, 0.25)) : début et fin de chaque geste
REPOS = {"pos": (-0.32, -0.31, -0.42), "paume": (0.45, 0.85, 0.15), "doigts": (0.12, 0.35, -1.0), "fermeture": 0.32,
         "coude": (-0.75, -0.55, 0.25)}
# écran : fov vertical 72° (joueur.gd), 16:9 (480×270)
TV = math.tan(math.radians(36.0))
TH = TV * 16.0 / 9.0
# butées du poignet (degrés) : extension (-) / flexion (+, vers la paume), cubitale (-) / radiale (+, vers le pouce)
BUTEES = {"flexion": (-70.0, 60.0), "inclinaison": (-30.0, 20.0)}
FPS_SORTIE = 60.0
# distance minimale œil -> paume (m) ; la pose de repos est à 0,61 m, l'ancienne pose « charge » à 0,48 m
DIST_MIN = 0.55
# pronation (+) / supination (-) de la main autour de l'avant-bras, mesurée depuis la pose de repos (degrés) : le rig n'a
# pas d'os de torsion, toute la torsion tombe au poignet ; au-delà, l'avant-bras paraît « disloqué » (la capture va
# jusqu'à 195° et fait même un tour complet sur la piste droite de la zone). Bornes douces (marge PRONATION_MARGE).
PRONATION = (-40.0, 125.0)
PRONATION_MARGE = 20.0

# --- gestes : piste source (clip, côté de la main qui lance dans la capture), phases et cadrage --------------------------
# entree : jouée pendant l'incantation (u = t / sort.incantation), images [a, b] de la source.
# tenue : charge 0 -> 1 (sorts chargés, zone), images [a, b].
# boucle : canalisation tenue, images [a, b] en aller-retour (vitesse 1 = temps réel de la capture).
# depart / fin : après le lancer / la fin du jet, table [[image, secondes], ...] ; « vers_repos » = s où le fondu vers le
# repos commence (il finit à la dernière clé).
# « pistes » : pour la main gauche et la main droite, côté source (g/d) ; un côté différent de la main = miroir.
GESTES = {
    # sort rapide à une main (éclat de glace, trait d'ombre, chaîne d'éclairs) : la main droite du « 1H Magic Attack 01 »
    # (armé près de l'épaule, poussée paume en avant, bras tendu, retour) ; la main gauche du jeu en joue le miroir
    "lance": dict(source="jet_1m", pistes={"gauche": "d", "droite": "d"}, centre=24, amplitude=0.6, cadrage=(0, 12, 0), poignet=-45.0,
                  poignet_entree=1.0, poignet_rampe=(0.04, 0.16), depuis_repos=0.35, entree=(12, 20),
                  depart=[[20, 0.0], [23, 0.06], [26, 0.18], [30, 0.28], [42, 0.48], [58, 0.68]], vers_repos=0.30),
    # sort chargé (boule de feu, lance de givre) : même capture, l'armé est TENU pendant la charge puis la poussée part
    "charge": dict(source="jet_1m", pistes={"gauche": "d", "droite": "d"}, centre=24, amplitude=0.6, cadrage=(0, 12, 0), poignet=-45.0,
                   depuis_repos=0.6, poignet_entree=1.0, poignet_rampe=(0.04, 0.16), entree=(6, 13), tenue=(13, 18),
                   depart=[[18, 0.0], [23, 0.08], [26, 0.20], [30, 0.30], [42, 0.50], [58, 0.70]], vers_repos=0.32),
    # jet tenu à une main (jet de flammes, arc électrique, drain) : main gauche du « 2H Magic Attack 03 » (rassemble,
    # pousse, puis TIENT le bras tendu ~2 s : la boucle reprend ce maintien, avec le léger balancement de la capture)
    "jet": dict(source="jet_2m", pistes={"gauche": "g", "droite": "g"}, centre=40, amplitude=0.75, poignet=-55.0, cadrage=(6, 8, 0),
                depuis_repos=0.45, entree=(24, 33), boucle=(36, 96),
                fin=[[98, 0.0], [110, 0.25], [124, 0.50]], vers_repos=0.0),
    # double incantation (les deux mains, même sort) : « 2H Magic Attack 04 », chaque main joue SA piste
    "double": dict(source="souffle_2m", pistes={"gauche": "g", "droite": "d"}, centre=40, amplitude=0.75, cadrage=(0, 14, 0),
                   depuis_repos=0.35, entree=(12, 27),
                   depart=[[27, 0.0], [31, 0.08], [38, 0.28], [78, 0.30], [90, 0.55], [100, 0.75]], vers_repos=0.36),
    "double_charge": dict(source="souffle_2m", pistes={"gauche": "g", "droite": "d"}, centre=40, amplitude=0.75, cadrage=(0, 14, 0),
                          depuis_repos=0.6, poignet_entree=1.0, entree=(4, 14), tenue=(14, 24),
                          depart=[[24, 0.0], [31, 0.10], [38, 0.28], [78, 0.30], [90, 0.55], [100, 0.75]], vers_repos=0.36),
    "double_jet": dict(source="souffle_2m", pistes={"gauche": "g", "droite": "d"}, centre=40, amplitude=0.75, cadrage=(0, 14, 0),
                       depuis_repos=0.45, entree=(24, 31), boucle=(33, 76),
                       fin=[[80, 0.0], [90, 0.25], [100, 0.50]], vers_repos=0.0),
    # sort de zone (explosion, tempête statique, nova) : « 2H Magic Area Attack 01 » : la main monte, poing fermé (charge),
    # puis frappe vers le sol ; la main droite joue le miroir de la piste gauche (la piste droite de la capture roule la
    # main d'un tour complet autour de l'avant-bras : impossible sans os de torsion)
    "zone": dict(source="zone_2m", pistes={"gauche": "g", "droite": "g"}, centre=36, amplitude=0.6, cadrage=(-8, 0, 0),
                 depuis_repos=0.5, entree=(26, 31), tenue=(31, 33),
                 depart=[[33, 0.0], [37, 0.08], [41, 0.18], [52, 0.42], [60, 0.66]], vers_repos=0.24),
}


# --- petites maths (sans dépendance) -----------------------------------------------------------------------------------
def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def mul(a, k): return (a[0] * k, a[1] * k, a[2] * k)
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def norm(a): return math.sqrt(dot(a, a))
def unit(a):
    n = norm(a)
    return mul(a, 1.0 / n) if n > 1e-9 else (0.0, 0.0, -1.0)
def lerp(a, b, k): return add(mul(a, 1 - k), mul(b, k))
def miroir(a): return (-a[0], a[1], a[2])
def lisse(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def q_axe(axe, ang):
    s = math.sin(ang / 2)
    u = unit(axe)
    return (math.cos(ang / 2), u[0] * s, u[1] * s, u[2] * s)


def q_mul(a, b):
    w1, x1, y1, z1 = a
    w2, x2, y2, z2 = b
    return (w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2, w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
            w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2, w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2)


def q_rot(q, v):
    w, x, y, z = q
    u = (x, y, z)
    t = mul(cross(u, v), 2.0)
    return add(add(v, mul(t, w)), cross(u, t))


def q_de_vers(a, b):
    """Plus petite rotation qui amène la direction a sur b."""
    a, b = unit(a), unit(b)
    c = dot(a, b)
    if c > 0.999999:
        return (1.0, 0.0, 0.0, 0.0)
    if c < -0.999999:
        ax = cross(a, (1, 0, 0)) if abs(a[0]) < 0.9 else cross(a, (0, 1, 0))
        return q_axe(ax, math.pi)
    return q_axe(cross(a, b), math.acos(max(-1.0, min(1.0, c))))


def q_de_base(x, y, z):
    """Quaternion de la base orthonormée de colonnes x, y, z."""
    m00, m11, m22 = x[0], y[1], z[2]
    tr = m00 + m11 + m22
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        q = (0.25 * s, (y[2] - z[1]) / s, (z[0] - x[2]) / s, (x[1] - y[0]) / s)
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(1.0 + m00 - m11 - m22) * 2
        q = ((y[2] - z[1]) / s, 0.25 * s, (y[0] + x[1]) / s, (z[0] + x[2]) / s)
    elif m11 > m22:
        s = math.sqrt(1.0 + m11 - m00 - m22) * 2
        q = ((z[0] - x[2]) / s, (y[0] + x[1]) / s, 0.25 * s, (z[1] + y[2]) / s)
    else:
        s = math.sqrt(1.0 + m22 - m00 - m11) * 2
        q = ((x[1] - y[0]) / s, (z[0] + x[2]) / s, (z[1] + y[2]) / s, 0.25 * s)
    n = math.sqrt(sum(c * c for c in q))
    return tuple(c / n for c in q)


def q_slerp(a, b, k):
    d = sum(a[i] * b[i] for i in range(4))
    if d < 0:
        b = tuple(-c for c in b)
        d = -d
    if d > 0.9995:
        r = tuple(a[i] + (b[i] - a[i]) * k for i in range(4))
    else:
        th = math.acos(d)
        s = math.sin(th)
        r = tuple((math.sin((1 - k) * th) * a[i] + math.sin(k * th) * b[i]) / s for i in range(4))
    n = math.sqrt(sum(c * c for c in r))
    return tuple(c / n for c in r)


def v_slerp(a, b, k):
    """Direction interpolée sur la sphère (de a vers b, k)."""
    return unit(q_rot(q_slerp((1.0, 0.0, 0.0, 0.0), q_de_vers(a, b), k), a))


# --- lecture d'une image de capture ------------------------------------------------------------------------------------
def image(src, f, cote, mir):
    """Positions interpolées (f fractionnaire) d'un côté de la capture, miroir éventuel."""
    ims = src["images"]
    f = min(max(f, 0.0), len(ims) - 1.0)
    i = int(math.floor(f))
    j = min(i + 1, len(ims) - 1)
    a = f - i
    out = {}
    for k in ("epaule", "coude", "poignet", "index", "auriculaire", "majeur", "majeur_bout"):
        p = lerp(ims[i][k + "_" + cote], ims[j][k + "_" + cote], a)
        out[k] = miroir(p) if mir else p
    return out


def repere_main(im, main):
    """Repère DIRECT de la main (colonnes y × paume, doigts, paume) : doigts = poignet -> jointure du majeur (comme main_sort._repere_main), paume = normale côté
    paume (pouce = auriculaire -> index ; la paume est pouce × doigts pour une main droite, l'opposé pour une gauche)."""
    y = unit(sub(im["majeur"], im["poignet"]))
    x = sub(im["index"], im["auriculaire"])
    x = unit(sub(x, mul(y, dot(x, y))))
    p = cross(x, y) if main == "droite" else mul(cross(x, y), -1.0)
    return cross(y, p), y, p


def base_pose(doigts, paume):
    y = unit(doigts)
    p = unit(sub(paume, mul(y, dot(paume, y))))
    return q_de_base(cross(y, p), y, p)


def fermeture(im):
    a = sub(im["majeur"], im["poignet"])
    b = sub(im["majeur_bout"], im["majeur"])
    ang = math.degrees(math.acos(max(-1.0, min(1.0, dot(unit(a), unit(b))))))
    return max(0.0, min(1.0, (ang - 8.0) / 95.0))


def ik_coude(S, W, pole):
    """Coude de l'IK à deux os (longueurs L1, L2) dans le plan (épaule, poignet, pôle)."""
    d = sub(W, S)
    n = norm(d)
    n = max(1e-4, min(n, L1 + L2 - 1e-4))
    u = unit(d)
    a = (L1 * L1 - L2 * L2 + n * n) / (2 * n)
    h = math.sqrt(max(0.0, L1 * L1 - a * a))
    v = sub(pole, S)
    v = unit(sub(v, mul(u, dot(v, u))))
    return add(add(S, mul(u, a)), mul(v, h))


def angles_poignet(a, x, y, p):
    """Flexion (+ vers la paume) et inclinaison (+ vers le pouce) de la main (x, y, p) sur l'avant-bras a (degrés)."""
    f = math.degrees(math.atan2(-dot(a, p), dot(a, y)))
    r = math.degrees(math.atan2(-dot(a, x), dot(a, y)))
    return f, r


def borner_poignet(a, x, y, p):
    """Ramène la main dans les butées en la tournant le moins possible (l'avant-bras ne bouge pas). x = côté du pouce."""
    f, r = angles_poignet(a, x, y, p)
    fb = max(BUTEES["flexion"][0], min(BUTEES["flexion"][1], f))
    rb = max(BUTEES["inclinaison"][0], min(BUTEES["inclinaison"][1], r))
    if abs(fb - f) < 1e-6 and abs(rb - r) < 1e-6:
        return x, y, p, f, r, False
    # direction voulue de l'avant-bras dans le repère de la main, puis rotation minimale de la main
    ah = unit((-math.tan(math.radians(rb)), 1.0, -math.tan(math.radians(fb))))
    b = add(add(mul(x, ah[0]), mul(y, ah[1])), mul(p, ah[2]))
    q = q_de_vers(b, a)
    x, y, p = q_rot(q, x), q_rot(q, y), q_rot(q, p)
    f2, r2 = angles_poignet(a, x, y, p)
    return x, y, p, f2, r2, True


def cadre(C):
    """Décalage qui ramène le point C (centre de la paume) dans l'écran, devant l'œil et à DIST_MIN au moins (sinon la
    main remplit l'écran et le sort part de l'objectif)."""
    if norm(C) < DIST_MIN:
        C2 = mul(unit(C), DIST_MIN)
        return add(sub(C2, C), cadre(C2))
    x, y, z = C
    z2 = min(z, -0.40)
    prof = -z2
    x2 = max(-0.80 * TH * prof, min(0.80 * TH * prof, x))
    y2 = max(-0.92 * TV * prof, min(0.62 * TV * prof, y))
    return (x2 - x, y2 - y, z2 - z)


# --- retarget d'une image ----------------------------------------------------------------------------------------------
class Retarget:
    def __init__(self, spec, src, main):
        self.spec, self.src, self.main = spec, src, main
        self.cote = spec["pistes"][main]
        self.mir = (self.cote == "g") != (main == "gauche")
        self.S = EPAULE[main]
        c = image(src, spec["centre"], self.cote, self.mir)
        self.c_ua = unit(sub(c["coude"], c["epaule"]))
        self.c_la = unit(sub(c["poignet"], c["coude"]))
        self.c_q = q_de_base(*repere_main(c, main))
        lacet, tangage, roulis = spec.get("cadrage", (0.0, 0.0, 0.0))
        k = -1.0 if main == "droite" else 1.0   # cadrage écrit pour la main gauche : miroir pour la droite
        self.Q = q_mul(q_axe((0, 1, 0), math.radians(lacet * k)), q_mul(q_axe((1, 0, 0), math.radians(tangage)),
                                                                        q_axe((0, 0, 1), math.radians(roulis * k))))
        dec = spec.get("decalage", (0.0, 0.0, 0.0))
        self.dec = (dec[0] * (-k), dec[1], dec[2]) if main == "droite" else dec
        self.repos = {"pos": REPOS["pos"], "paume": unit(REPOS["paume"]), "doigts": unit(REPOS["doigts"]),
                      "fermeture": REPOS["fermeture"], "coude": REPOS["coude"]}
        if main == "droite":
            for kk in ("pos", "paume", "doigts", "coude"):
                self.repos[kk] = miroir(self.repos[kk])
        self.stats = {"f": [], "r": [], "bornes": 0, "cadre": 0, "n": 0}

    def pose(self, f, w_repos, k_poignet=1.0):
        """Pose FPS (dict) à l'image f de la source ; w_repos = part de la pose de repos (fondu) ; k_poignet = part de la
        correction « poignet » (la paume se tourne vers la cible au moment de lancer, pas pendant l'armé)."""
        im = image(self.src, f, self.cote, self.mir)
        al = self.spec["amplitude"]
        d_ua = q_rot(self.Q, v_slerp(self.c_ua, unit(sub(im["coude"], im["epaule"])), al))
        d_la = q_rot(self.Q, v_slerp(self.c_la, unit(sub(im["poignet"], im["coude"])), al))
        E = add(add(self.S, mul(d_ua, L1)), self.dec)
        W = add(E, mul(d_la, L2))
        # main portée par l'avant-bras : repère de la main Mixamo, puis la rotation qui amène l'avant-bras Mixamo sur le
        # nôtre (calculé plus bas, après cadre et fondu) : flexion / inclinaison du poignet = celles de la capture
        x0, y0, p0 = repere_main(im, self.main)
        a0 = unit(sub(im["poignet"], im["coude"]))
        a1 = d_la
        q = q_de_vers(a0, a1)
        x, y, p = q_rot(q, x0), q_rot(q, y0), q_rot(q, p0)
        # « poignet » : flexion (+) / extension (-) ajoutée (degrés), pour tourner la paume vers la cible (jet tenu) ;
        # les butées passent après
        dfl = self.spec.get("poignet", 0.0) * k_poignet
        if dfl:
            qf = q_axe(cross(y, p), math.radians(dfl))
            x, y, p = q_rot(qf, x), q_rot(qf, y), q_rot(qf, p)
        # « roulis » : la main tourne autour de l'axe des doigts (pronation, écrit pour la main gauche ; miroir à droite)
        dro = self.spec.get("roulis", 0.0)
        if dro:
            qr = q_axe(y, math.radians(dro * (1.0 if self.main == "gauche" else -1.0)))
            x, y, p = q_rot(qr, x), q_rot(qr, y), q_rot(qr, p)
        # paume dans l'écran
        C = add(add(W, mul(y, 0.07)), mul(p, 0.03))
        dc = cadre(C)
        if norm(dc) > 1e-4:
            self.stats["cadre"] += 1
        W = add(W, dc)
        E = add(E, mul(dc, 0.5))
        ferm = fermeture(im)
        pole = add(E, mul(unit(sub(E, lerp(self.S, W, 0.5))), 0.5))
        # l'avant-bras réel (IK, pôle = coude de la capture) : la main le suit
        a2 = unit(sub(W, ik_coude(self.S, W, pole)))
        q = q_de_vers(a1, a2)
        x, y, p = q_rot(q, x), q_rot(q, y), q_rot(q, p)
        # fondu avec la pose de repos (positions, pôle, repère de la main)
        rp = self.repos
        if w_repos > 0.0:
            W = lerp(W, rp["pos"], w_repos)
            pole = lerp(pole, rp["coude"], w_repos)
            qq = q_slerp(q_de_base(x, y, p), base_pose(rp["doigts"], rp["paume"]), w_repos)
            x, y, p = q_rot(qq, (1, 0, 0)), q_rot(qq, (0, 1, 0)), q_rot(qq, (0, 0, 1))
            ferm = ferm + (rp["fermeture"] - ferm) * w_repos
        # poignet dans les butées, sur l'avant-bras que donnera l'IK (x : côté du pouce)
        Ei = ik_coude(self.S, W, pole)
        a = unit(sub(W, Ei))
        sg = 1.0 if self.main == "droite" else -1.0
        xp, y, p, fl, inc, borne = borner_poignet(a, mul(x, sg), y, p)
        st = self.stats
        st["n"] += 1
        st["f"].append(fl)
        st["r"].append(inc)
        st["bornes"] += 1 if borne else 0
        r5 = lambda v: [round(c, 4) for c in v]
        return {"pos": r5(W), "paume": r5(p), "doigts": r5(y), "fermeture": round(ferm, 3), "coude": r5(pole)}


def pronation(main, W, paume, pole):
    """Angle (degrés) de la paume autour de l'avant-bras de l'IK, repéré sur le plan du coude (repère de lowerarm)."""
    S = EPAULE[main]
    a = unit(sub(W, ik_coude(S, W, pole)))
    r = cross(sub(W, S), sub(pole, S))
    r = unit(sub(r, mul(a, dot(r, a))))
    pp = unit(sub(paume, mul(a, dot(paume, a))))
    return math.degrees(math.atan2(dot(cross(r, pp), a), dot(r, pp))), a


def borne_douce(x, lo, hi, m):
    """x borné à [lo, hi], raccord C1 sur une marge m (saturation exponentielle)."""
    if x > hi - m:
        return hi - m * math.exp(-(x - (hi - m)) / m)
    if x < lo + m:
        return lo + m * math.exp((x - (lo + m)) / m)
    return x


def borner_pronation(rt, poses, prec):
    """Pronation de chaque pose suivie CONTINÛMENT depuis `prec` (déroulée, pas de saut de ±360°), bornée (PRONATION) ;
    la main tourne autour de l'avant-bras de l'écart (flexion / inclinaison du poignet inchangées). Rend la dernière
    pronation (raccord de la phase suivante) et le pire écart avant bornage."""
    sg = 1.0 if rt.main == "gauche" else -1.0   # + = pronation pour les deux mains
    rp = rt.repos
    ref, _ = pronation(rt.main, rp["pos"], rp["paume"], rp["coude"])
    pire = prec
    for p in poses:
        W, pole = tuple(p["pos"]), tuple(p["coude"])
        ang, a = pronation(rt.main, W, tuple(p["paume"]), pole)
        x = sg * (ang - ref)
        x += 360.0 * round((prec - x) / 360.0)
        prec = x
        pire = max(pire, abs(x), key=abs)
        xb = borne_douce(x, PRONATION[0], PRONATION[1], PRONATION_MARGE)
        if abs(xb - x) > 1e-6:
            q = q_axe(a, math.radians(sg * (xb - x)))
            p["paume"] = [round(c, 4) for c in q_rot(q, tuple(p["paume"]))]
            p["doigts"] = [round(c, 4) for c in q_rot(q, tuple(p["doigts"]))]
    return prec, pire


def table_vers(table, t):
    """Image source à l'instant t (s) d'une table [[image, s], ...] (linéaire par morceaux)."""
    for (f0, t0), (f1, t1) in zip(table, table[1:]):
        if t <= t1 + 1e-9:
            a = (t - t0) / max(t1 - t0, 1e-6)
            return f0 + (f1 - f0) * max(0.0, min(1.0, a))
    return table[-1][0]


def construire(nom, spec, sources):
    src = sources[spec["source"]]
    out = {"source": src["fichier"]}
    rapport = []
    for main in ("gauche", "droite"):
        rt = Retarget(spec, src, main)
        pistes = {}
        if "entree" in spec:
            a, b = spec["entree"]
            n = 16
            dr = spec.get("depuis_repos", 0.0)
            kp = spec.get("poignet_entree", 0.55)   # la paume se tourne vers la cible sur la fin de l'incantation
            pistes["entree"] = [rt.pose(a + (b - a) * i / (n - 1), 1.0 - lisse((i / (n - 1)) / dr) if dr > 0 else 0.0,
                                        lisse((i / (n - 1) - kp) / max(1.0 - kp, 1e-6)) if kp < 1.0 else 0.0) for i in range(n)]
        if "tenue" in spec:
            a, b = spec["tenue"]
            n = 12
            pistes["tenue"] = [rt.pose(a + (b - a) * i / (n - 1), 0.0, 0.0) for i in range(n)]
        if "boucle" in spec:
            a, b = spec["boucle"]
            fps = src["fps"]
            duree = (b - a) / fps
            n = int(round(duree * 30)) + 1
            pistes["boucle"] = [rt.pose(a + (b - a) * i / (n - 1), 0.0) for i in range(n)]
            out["boucle_duree"] = round(duree, 3)
        for ph in ("depart", "fin"):
            if ph in spec:
                table = spec[ph]
                duree = table[-1][1]
                n = int(round(duree * FPS_SORTIE)) + 1
                v0 = spec.get("vers_repos", 0.0)
                poses = []
                for i in range(n):
                    t = duree * i / (n - 1)
                    w = lisse((t - v0) / max(duree - v0, 1e-6)) if t > v0 else 0.0
                    # « poignet_rampe » (t0, t1) : la correction arrive pendant la poussée (la capture tourne d'abord la paume
                    # vers la cible elle-même, puis la roule vers le sol : la correction prend le relais)
                    r0, r1 = spec.get("poignet_rampe", (0.0, 0.0)) if ph == "depart" else (0.0, 0.0)
                    kp = lisse((t - r0) / (r1 - r0)) if r1 > r0 else 1.0
                    poses.append(rt.pose(table_vers(table, t), w, kp))
                pistes[ph] = poses
                out[ph + "_duree"] = round(duree, 3)
        # pronation continue d'une phase à l'autre (entree -> tenue -> depart, ou entree -> boucle -> fin), bornée
        prec = 0.0
        pire = 0.0
        for ph in ("entree", "tenue", "boucle", "depart", "fin"):
            if ph in pistes:
                prec, pr = borner_pronation(rt, pistes[ph], prec)
                pire = max(pire, abs(pr))
        out[main] = pistes
        st = rt.stats
        st["pronation"] = pire
        rapport.append("%-14s %-6s piste %s%s : poignet flexion %+.0f..%+.0f inclinaison %+.0f..%+.0f ; %d/%d bornées, %d recadrées ; pronation capture %.0f° (bornée %+.0f..%+.0f)" % (
            nom, main, rt.cote, " (miroir)" if rt.mir else "", min(st["f"]), max(st["f"]), min(st["r"]), max(st["r"]),
            st["bornes"], st["n"], st["cadre"], st["pronation"], PRONATION[0], PRONATION[1]))
    return out, rapport


def main():
    chemin = ARGS.get("source", os.path.join(BASE, "sources_blender", "mixamo", "gestes_magie_mixamo.json"))
    sources = json.load(open(chemin, encoding="utf-8"))
    donnees = {"_doc": "Gestes de magie FPS retargetés depuis Mixamo (sources_blender/scripts/gestes_magie.py). "
                       "Repère caméra ; poses au format PosesIncantation + coude (pôle de l'IK).",
               "fps_depart": FPS_SORTIE, "gestes": {}}
    for nom, spec in GESTES.items():
        g, rapport = construire(nom, spec, sources)
        donnees["gestes"][nom] = g
        for ligne in rapport:
            print("GESTE", ligne)
    sortie = os.path.join(BASE, "data", "magie", "gestes_mixamo.json")
    with open(sortie, "w", encoding="utf-8") as f:
        json.dump(donnees, f, ensure_ascii=False, separators=(",", ":"))
    print("ECRIT", sortie, os.path.getsize(sortie), "octets")


if __name__ == "__main__":
    main()
