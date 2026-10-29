# Animations FPS des bras (épée à une main) — CLÉS D'OS animées à la main, pour le viewmodel de Hollowrim.
#
#   blender.exe -b sources_blender/bras_fps.blend --python sources_blender/scripts/anim_bras_epee.py -- \
#       [--rendu=<dossier>] [--clips=coup_a,coup_b] [--pas=0.0333] [--godot] [--blend]
#
# Principe (docs/COMBAT.md, « Coups animés à la main ») :
# - chaque geste est une suite de POSES CLÉS du bras droit (spine_03, clavicle_r, upperarm_r, lowerarm_r, hand_r) posées à
#   des instants précis ; entre deux clés, Blender interpole les ROTATIONS DES ARTICULATIONS (courbes de Bézier) : la main
#   décrit naturellement un arc, l'avant-bras tourne (pronation) au lieu de glisser en ligne droite.
# - une pose clé se décrit comme un animateur la placerait : où est le poing à l'écran (repère caméra du jeu), où pointe la
#   lame, de quel côté est le tranchant, où part le coude, combien le buste tourne / la clavicule avance. Un petit solveur
#   (deux os + torsion de l'avant-bras) ne sert qu'à POSER la clé ; ce sont les rotations d'os qui sont enregistrées.
# - la torsion (pronation / supination) est portée par l'avant-bras ; le poignet ne garde que flexion et inclinaison,
#   contrôlées (rapport « poignet » : flexion / extension / inclinaison radiale / cubitale, en degrés).
# - --godot : écrit assets/animations/bras_epee.tres (AnimationLibrary : pistes de rotation des 5 os, échantillonnées à
#   120 Hz, marqueurs en métadonnées) ; --blend : enregistre sources_blender/bras_fps_anims.blend (actions éditables) ;
#   --rendu : planches de contrôle (vue caméra du jeu, épée et torche) dans <dossier>/<clip>_NNN.png.
# Le repère caméra et la prise de l'épée viennent du jeu (sources_blender/scripts/bras_godot.json, extrait par
# outils/anim_bras/dump_bras.gd) : os de Blender = os de Godot (vérifié : correction d'axes identité).

import bpy, json, math, sys, os
from mathutils import Matrix, Vector, Quaternion

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
D = json.load(open(os.path.join(BASE, "sources_blender", "scripts", "bras_godot.json")))
ARGS = {}
if "--" in sys.argv:
    for a in sys.argv[sys.argv.index("--") + 1:]:
        k, _, v = a.lstrip("-").partition("=")
        ARGS[k] = v


def M(a):
    m = Matrix.Identity(4)
    for c in range(3):
        for r in range(3):
            m[r][c] = a[c * 3 + r]
    for r in range(3):
        m[r][3] = a[9 + r]
    return m


C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))   # Blender -> Godot : (x, y, z) -> (x, z, -y)
CAM_DE_B = M(D["bras"]) @ C            # repère caméra (mains.gd) <- armature Blender
B_DE_CAM = CAM_DE_B.inverted()
PRISE_D = M(D["prise_d"])               # épée dans le repère de l'os hand_r (Godot = Blender ici)
PRISE_G = M(D["prise_g"])
MILIEU_POIGNEE = 0.03
GARDE = Vector(D["garde"])
POINTE = Vector(D["pointe"])
FPS = 120
OS_ANIMES = ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]   # main DROITE seule (la gauche : IK torche / sorts)

A = bpy.data.objects["Armature"]
scene = bpy.context.scene
scene.render.fps = FPS
for pb in A.pose.bones:
    pb.rotation_mode = "QUATERNION"


def maj():
    bpy.context.view_layer.update()


# --- poings fermés (pose des doigts du jeu) -------------------------------------------------------------------
def poings():
    for nom, q in D["doigts"].items():
        if nom not in A.pose.bones:
            continue
        rest = M(D["os"][nom]["rest"])
        loc = Matrix.Translation(rest.to_translation()) @ Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4()
        A.pose.bones[nom].matrix_basis = rest.inverted() @ loc


# --- solveur de pose clé ----------------------------------------------------------------------------------------
def repere_arme(poing, lame, fil):
    """Repère de l'épée (repère caméra) : +Y le long de la lame, +X vers le tranchant, origine au pommeau."""
    y = Vector(lame).normalized()
    x = Vector(fil)
    x = (x - y * x.dot(y)).normalized()
    z = x.cross(y)
    m = Matrix.Identity(4)
    for r in range(3):
        m[r][0], m[r][1], m[r][2] = x[r], y[r], z[r]
    m.translation = Vector(poing) - y * MILIEU_POIGNEE
    return m


def roulis(poing, lame, fil, angle):
    """Tranchant tel que le plat de la lame fasse `angle` degrés avec la direction de l'œil (0 = plat face à la caméra,
    90 = tranche pure) ; `fil` choisit le côté (le tranchant qui mène)."""
    y = Vector(lame).normalized()
    milieu = Vector(poing) + y * 0.45
    vers_oeil = (-milieu).normalized()
    n_plat = (vers_oeil - y * vers_oeil.dot(y)).normalized()     # normale du plat face à l'œil
    n_tranche = y.cross(n_plat).normalized()
    a = math.radians(angle)
    n = n_plat * math.cos(a) + n_tranche * math.sin(a)
    x = y.cross(n)
    if x.dot(Vector(fil)) < 0:
        n = n_plat * math.cos(a) - n_tranche * math.sin(a)
        x = y.cross(n)
    return x


def _axe_local(nom, monde):
    rest = A.data.bones[nom].matrix_local.to_3x3()
    return (rest.inverted() @ Vector(monde)).normalized()


def _base(x, y):
    x = (x - y * x.dot(y)).normalized()
    z = x.cross(y)
    return Matrix((x, y, z)).transposed()


def _rot_monde(pb, R, pivot):
    m = pb.matrix.copy()
    pb.matrix = Matrix.Translation(pivot) @ R.to_4x4() @ Matrix.Translation(-pivot) @ m
    maj()


RAPPORT = []


LIM_TORSION = (-80, 85)     # pronation (-) / supination (+) de l'avant-bras autour du neutre (poignée de main)
LIM_FLEXION = (-60, 70)     # extension (-) / flexion (+, vers la paume)
LIM_INCL = (-35, 20)        # inclinaison cubitale (-) / radiale (+, vers le pouce)
LIM_TORSION_L = (-95, 95)   # clés « large » (combo 2026-10-27, finishers) : butées levées, toujours anatomiques
LIM_INCL_L = (-40, 28)
# clés « strict » (coups naturels, 2026-10-29, references/combat_epee/prompt_coups_naturels_2026-10-29.md) : le coup est
# porté par l'épaule, le coude et l'avant-bras ; le poignet reste presque dans l'axe. Butées des CLÉS plus serrées que
# l'anatomie (flexion / extension ±60°, radiale 20°, cubitale 30°) pour que l'interpolation entre deux clés n'en sorte
# jamais (contrôle image par image : --butees).
LIM_TORSION_S = (-85, 85)
LIM_FLEXION_S = (-40, 40)
LIM_INCL_S = (-28, 14)
# (inclinaison cubitale : -32 admis, c'est la tenue de repos VALIDÉE, k=52 f=-11 r=-32, référence tenue_epee_droite ;
# seul écart, 2° au-delà, hérité de la tenue et non des coups)
BUTEES_ANATOMIQUES = dict(flexion=(-60, 60), inclinaison=(-32, 20))


def _bras_deux_os(s, poignet, coude_indice):
    """Épaule -> coude -> poignet (deux os) : pose upperarm, renvoie (coude, d2, Rl0 = repère neutre de l'avant-bras,
    allonge)."""
    ua = A.pose.bones["upperarm_" + s]
    epaule = ua.head.copy()
    l1 = (A.data.bones["upperarm_" + s].head_local - A.data.bones["lowerarm_" + s].head_local).length
    l2 = (A.data.bones["lowerarm_" + s].head_local - A.data.bones["hand_" + s].head_local).length
    v = poignet - epaule
    d = v.length
    allonge = d / (l1 + l2)
    d = min(max(d, abs(l1 - l2) + 0.01), l1 + l2 - 0.004)
    n = v.normalized()
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    r = math.sqrt(max(l1 * l1 - a * a, 1e-8))
    indice = (B_DE_CAM.to_3x3() @ Vector(coude_indice)).normalized()
    perp = (indice - n * indice.dot(n))
    perp = perp.normalized() if perp.length > 1e-6 else Vector((0, 0, -1))
    coude = epaule + n * a + perp * r
    d1 = (coude - epaule).normalized()
    d2 = (epaule + n * d - coude).normalized()
    signe = 1.0 if s == "r" else -1.0
    # charnière du coude : au repos (bras en croix, paume en bas = neutre anatomique), l'axe vertical du monde
    charn = d1.cross(d2)
    if charn.length < 1e-5:
        charn = d1.cross(perp)
    charn = charn.normalized() * signe
    ax_u = _axe_local("upperarm_" + s, (0, 0, 1))
    ax_l = _axe_local("lowerarm_" + s, (0, 0, 1))
    def repere_os(ax_loc, y_monde, c):
        return _base(c, y_monde) @ _base(ax_loc, Vector((0, 1, 0))).inverted()
    Ru = repere_os(ax_u, d1, charn)
    ua.matrix = Matrix.Translation(epaule) @ Ru.to_4x4()
    maj()
    return coude, d2, repere_os(ax_l, d2, charn), allonge


def _poignet(s, Rl, k, f, r):
    """Rotation (armature) de la main pour une torsion d'avant-bras k, flexion f, inclinaison r (degrés)."""
    lrel = A.data.bones["lowerarm_" + s].matrix_local.to_3x3().inverted() @ A.data.bones["hand_" + s].matrix_local.to_3x3()
    paume = _axe_local("hand_" + s, (0, 0, -1))
    pouce = _axe_local("hand_" + s, (0, -1, 0))
    y = Vector((0, 1, 0))
    signe = 1.0 if s == "r" else -1.0
    a_f = y.cross(paume)
    a_r = y.cross(pouce)
    Rw = Matrix.Rotation(math.radians(f), 3, a_f) @ Matrix.Rotation(math.radians(r), 3, a_r)
    d2 = Rl @ y
    return Matrix.Rotation(math.radians(k * signe), 3, d2) @ Rl @ lrel @ Rw


def _cout(W, cle, kfr):
    y = W.col[1].to_3d().normalized()
    z = W.col[2].to_3d().normalized()
    lame = Vector(cle["lame"]).normalized()
    c = math.degrees(y.angle(lame))
    if "mouvement" in cle:          # le tranchant mène : la normale du plat est perpendiculaire au mouvement
        mv = Vector(cle["mouvement"]).normalized()
        c += 0.3 * math.degrees(math.asin(min(1.0, abs(z.dot(mv)))))
        if "normale" in cle:        # plat imposé (horizontal du combo : normale du plat verticale)
            c += cle.get("poids_normale", 0.4) * math.degrees(math.acos(min(1.0, abs(z.dot(Vector(cle["normale"]).normalized())))))
    else:                           # pose tenue : angle du plat avec la direction de l'œil
        milieu = W.translation.to_3d() + y * 0.5
        plat = math.degrees(math.acos(min(1.0, abs(z.dot((-milieu).normalized())))))
        c += cle.get("poids_roulis", 0.6) * abs(plat - cle.get("roulis", 70.0))
    k, f, r = kfr
    # poignet : écart à l'axe de l'avant-bras (clés « strict » : fortement pénalisé, le bras porte le geste)
    c += cle.get("poids_torsion", 0.03) * abs(k - cle.get("torsion", 0)) + cle.get("poids_poignet", 0.03) * (abs(f) + abs(r))
    if PREC[0] is not None:          # continuité avec la clé précédente (pas de retournement de l'avant-bras)
        c += 0.03 * (abs(k - PREC[0][0]) + 0.5 * abs(f - PREC[0][1]) + 0.5 * abs(r - PREC[0][2]))
    return c


PREC = [None]


def poser(cle, cote="r"):
    """Pose une clé (voir gestes_bras_epee.py). Le solveur respecte les butées anatomiques : il cherche la torsion de
    l'avant-bras et l'angle du poignet (dans leurs limites) qui donnent la lame la plus proche de celle demandée."""
    s = cote
    if s == "r":
        sp = A.pose.bones["spine_03"]
        lacet, penche = cle.get("torse", (0.0, 0.0))
        sp.matrix_basis = (Quaternion((0, 1, 0), math.radians(lacet)) @ Quaternion((1, 0, 0), math.radians(penche))).to_matrix().to_4x4()
        maj()
        cl = A.pose.bones["clavicle_" + s]
        cl.matrix_basis = Matrix.Identity(4)
        maj()
        avance, monte = cle.get("clav", (0.0, 0.0))
        R = Quaternion((0, 0, 1), math.radians(avance)) @ Quaternion((0, 1, 0), math.radians(monte))
        _rot_monde(cl, R.to_matrix(), cl.head.copy())
        if "epaule" in cle:        # glissement de l'épaule (hors écran) : le bras FPS gagne de l'allonge vers le centre
            cl.matrix = Matrix.Translation(B_DE_CAM.to_3x3() @ Vector(cle["epaule"])) @ cl.matrix
            maj()
    ua, la, ha = (A.pose.bones[n + s] for n in ("upperarm_", "lowerarm_", "hand_"))
    for pb in (ua, la, ha):
        pb.matrix_basis = Matrix.Identity(4)
    maj()
    prise = PRISE_D if s == "r" else PRISE_G
    centre_poing = prise @ Vector((0, MILIEU_POIGNEE, 0))         # centre du poing, repère de la main
    poing_b = B_DE_CAM @ Vector(cle["poing"])
    Hrot = None
    best = None
    indice0 = Vector(cle.get("coude", (1.0, -1.0, 0.2)))
    fixe = "k" in cle
    # le coude peut tourner autour de l'axe épaule -> poignet (± 90° de l'indication) : le solveur choisit la position du
    # coude qui rend la lame voulue atteignable, en préférant l'indication et la continuité avec la clé précédente
    phis = [cle.get("phi", 0)] if (fixe or cle.get("coude_fixe")) else list(range(-90, 91, 15))
    phi_best = 0
    # butées élargies par clé (« large » : gestes amples des combos / finishers, l'épaule et le coude font le reste)
    LT, LF, LI = (LIM_TORSION_L, LIM_FLEXION, LIM_INCL_L) if cle.get("large") else (LIM_TORSION, LIM_FLEXION, LIM_INCL)
    if cle.get("strict"):
        LT, LF, LI = LIM_TORSION_S, LIM_FLEXION_S, LIM_INCL_S
    for it in range(3):
        decal = (Hrot @ centre_poing) if Hrot is not None else (B_DE_CAM.to_3x3() @ Vector((0.03, -0.06, 0.07)))
        poignet = poing_b - decal
        ep_cam = CAM_DE_B @ ua.head
        n_cam = ((CAM_DE_B @ poignet) - ep_cam).normalized()
        best = None
        for phi in (phis if it == 0 else [phi_best]):
            ind = Matrix.Rotation(math.radians(phi), 3, n_cam) @ indice0
            coude, d2, Rl0, allonge = _bras_deux_os(s, poignet, ind)
            coude_cam = CAM_DE_B @ coude
            pen = 0.05 * abs(phi) + max(0.0, coude_cam.y - ep_cam.y - 0.05) * 100.0
            if PREC[0] is not None and len(PREC[0]) > 3:
                pen += 0.03 * abs(phi - PREC[0][3])
            def evalue(k, f, r):
                Hr = _poignet(s, Rl0, k, f, r)
                H = Matrix.Translation(poing_b - Hr @ centre_poing) @ Hr.to_4x4()
                W = CAM_DE_B @ H @ prise
                return _cout(W, cle, (k, f, r)) + pen, Hr
            if fixe:
                grille = ([cle["k"]], [cle["f"]], [cle["r"]])
            elif it == 0:
                grille = (range(LT[0], LT[1] + 1, 20), range(LF[0], LF[1] + 1, 20), range(LI[0], LI[1] + 1, 10))
            else:
                grille = (range(LT[0], LT[1] + 1, 10), range(LF[0], LF[1] + 1, 10), range(LI[0], LI[1] + 1, 5))
            for k in grille[0]:
                for f in grille[1]:
                    for r in grille[2]:
                        c, Hr = evalue(k, f, r)
                        if best is None or c < best[0]:
                            best = (c, k, f, r, Hr, phi)
        phi_best = best[5]
        ind = Matrix.Rotation(math.radians(phi_best), 3, n_cam) @ indice0
        coude, d2, Rl0, allonge = _bras_deux_os(s, poignet, ind)
        coude_cam = CAM_DE_B @ coude
        pen = 0.05 * abs(phi_best) + max(0.0, coude_cam.y - ep_cam.y - 0.05) * 100.0
        if PREC[0] is not None and len(PREC[0]) > 3:
            pen += 0.03 * abs(phi_best - PREC[0][3])
        def evalue(k, f, r):
            Hr = _poignet(s, Rl0, k, f, r)
            H = Matrix.Translation(poing_b - Hr @ centre_poing) @ Hr.to_4x4()
            W = CAM_DE_B @ H @ prise
            return _cout(W, cle, (k, f, r)) + pen, Hr
        # affinage
        for _ in range(0 if fixe or it < 2 else 2):
            c0, k0, f0, r0, _h, _p = best
            for k in range(k0 - 8, k0 + 9, 2):
                for f in range(f0 - 8, f0 + 9, 2):
                    for r in range(r0 - 4, r0 + 5, 1):
                        if not (LT[0] <= k <= LT[1] and LF[0] <= f <= LF[1] and LI[0] <= r <= LI[1]):
                            continue
                        c, Hr = evalue(k, f, r)
                        if c < best[0]:
                            best = (c, k, f, r, Hr, phi_best)
        Hrot = best[4]
    c, k, f, r, Hrot, phi_best = best
    PREC[0] = (k, f, r, phi_best)
    signe = 1.0 if s == "r" else -1.0
    Rl = Matrix.Rotation(math.radians(k * signe), 3, d2) @ Rl0
    la.matrix = Matrix.Translation(coude) @ Rl.to_4x4()
    maj()
    ha.matrix = Matrix.Translation(la.tail.copy()) @ Hrot.to_4x4()
    maj()
    W = CAM_DE_B @ ha.matrix @ prise
    erreur = math.degrees(W.col[1].to_3d().normalized().angle(Vector(cle["lame"]).normalized()))
    RAPPORT.append((cle.get("nom", "?"), round(allonge, 2), k, f, r, round(erreur, 1), round(c, 1), phi_best))
    return dict(allonge=allonge, torsion=k, flexion=f, inclinaison=r, erreur_lame=erreur)



# --- torche (aperçu : le jeu la pose par IK) ---------------------------------------------------------------------
def poser_torche():
    T = M(D["pivot_torche"])
    H = B_DE_CAM @ T @ PRISE_G.inverted()
    for n in ("upperarm_l", "lowerarm_l", "hand_l"):
        A.pose.bones[n].matrix_basis = Matrix.Identity(4)
    maj()
    coude, d2, Rl0, _ = _bras_deux_os("l", H.to_translation(), (-0.8, -0.9, -0.1))
    la = A.pose.bones["lowerarm_l"]
    la.matrix = Matrix.Translation(coude) @ Rl0.to_4x4()
    maj()
    A.pose.bones["hand_l"].matrix = Matrix.Translation(la.tail.copy()) @ H.to_3x3().normalized().to_4x4()
    maj()


from gestes_bras_epee import CLIPS, MARQUEURS, CLIPS_MIXAMO, REPOS  # noqa: E402  (fichier voisin : poses clés, instants)


# --- coups en capture de mouvement (Mixamo) retargetés sur le bras FPS ---------------------------------------------
# Données : sources_blender/mixamo/coups_mixamo.json (extraire_mixamo.py ; les .fbx bruts restent hors du dépôt).
# Principe (retarget « par écart », classique en FPS) : la caméra est la tête, son orientation est FIXE (celle du joueur) ;
# pour chaque os de la chaîne épaule -> bras -> avant-bras -> main, on prend la rotation MONDE de l'os Mixamo à l'instant t
# relative à sa rotation à l'image de référence (la garde du fichier), D = R(t) · R(réf)⁻¹, et on l'applique à notre os
# dans la pose de repos VALIDÉE : la rotation du buste (épaule qui avance, recule, monte), le coude et la main suivent la
# vraie capture, mais le cadrage de départ reste notre tenue. Le déplacement de l'épaule par rapport au cou (buste qui
# tourne) déplace la clavicule. Le poignet est ensuite RÉSOLU dans les butées anatomiques (torsion de l'avant-bras,
# flexion, inclinaison) : la main Mixamo donne l'orientation voulue de l'épée, la torsion passe dans l'avant-bras.
# la prise Mixamo n'est pas connue (pas d'épée dans les fichiers) : notre prise est posée dans la main Mixamo par le
# repère anatomique, puis tournée de ROULIS_PRISE_MX° autour de la lame (calage : le tranchant mène pendant les frappes)
ROULIS_PRISE_MX = float(ARGS.get("roulis_prise", 0.0))
LIM_MX = dict(torsion=(-85, 85), flexion=(-55, 55), inclinaison=(-29, 18))
_MX = {}


def _mx_donnees():
    if not _MX:
        _MX.update(json.load(open(os.path.join(BASE, "sources_blender", "mixamo", "coups_mixamo.json"), encoding="utf-8")))
    return _MX


def _mx_image(src, f):
    """Image Mixamo interpolée (f fractionnaire) : quaternions (slerp) et positions (lerp), repère caméra."""
    ims = src["images"]
    f = min(max(f, 0.0), len(ims) - 1.0)
    i = int(math.floor(f))
    j = min(i + 1, len(ims) - 1)
    a = f - i
    out = {}
    for k, v in ims[i].items():
        w = ims[j][k]
        if k.startswith("q_"):
            q0, q1 = Quaternion(v), Quaternion(w)
            if q0.dot(q1) < 0:
                q1 = -q1
            out[k] = q0.slerp(q1, a)
        else:
            out[k] = Vector(v).lerp(Vector(w), a)
    return out


def _mx_melange(a, b, x):
    out = {}
    for k, v in a.items():
        if k.startswith("q_"):
            w = b[k] if v.dot(b[k]) >= 0 else -b[k]
            out[k] = v.slerp(w, x)
        else:
            out[k] = v.lerp(b[k], x)
    return out


def _pose_repos_cam():
    """Rotations (repère caméra) et vecteurs d'os de notre bras dans la pose de repos validée."""
    PREC[0] = None
    poser(dict(REPOS))
    R = lambda n: (CAM_DE_B.to_3x3() @ A.pose.bones[n].matrix.to_3x3()).normalized()
    pt = lambda n: CAM_DE_B @ A.pose.bones[n].head
    return dict(cl=R("clavicle_r"), ua=R("upperarm_r"), la=R("lowerarm_r"), ha=R("hand_r"),
                epaule=pt("upperarm_r"), v_ua=pt("lowerarm_r") - pt("upperarm_r"), v_la=pt("hand_r") - pt("lowerarm_r"))


def _rot_ecart(R1, R0):
    return R1 @ R0.inverted()


def _resoudre_main(Rl0, Hd, prec_k):
    """Torsion k (avant-bras), flexion f, inclinaison r dans LIM_MX qui approchent le mieux l'orientation voulue Hd
    (armature) : la lame d'abord (axe Y de l'épée), puis le tranchant ; continuité de la torsion avec l'image précédente."""
    Ry = (Hd @ PRISE_D.to_3x3()).col[1].normalized()
    Rx = (Hd @ PRISE_D.to_3x3()).col[0].normalized()
    LT, LF, LI = LIM_MX["torsion"], LIM_MX["flexion"], LIM_MX["inclinaison"]

    def cout(k, f, r):
        Hr = _poignet("r", Rl0, k, f, r)
        E = Hr @ PRISE_D.to_3x3()
        c = math.degrees(E.col[1].normalized().angle(Ry)) + 0.4 * math.degrees(E.col[0].normalized().angle(Rx))
        c += 0.02 * (abs(f) + abs(r))
        if prec_k is not None:
            c += 0.04 * abs(k - prec_k)
        return c, Hr
    best = None
    for k in range(LT[0], LT[1] + 1, 10):
        for f in range(LF[0], LF[1] + 1, 10):
            for r in range(LI[0], LI[1] + 1, 6):
                c, Hr = cout(k, f, r)
                if best is None or c < best[0]:
                    best = (c, k, f, r, Hr)
    for pas in (4, 2, 1):
        c0, k0, f0, r0, _ = best
        for k in (k0 - pas, k0, k0 + pas):
            for f in (f0 - pas, f0, f0 + pas):
                for r in (r0 - pas, r0, r0 + pas):
                    if LT[0] <= k <= LT[1] and LF[0] <= f <= LF[1] and LI[0] <= r <= LI[1]:
                        c, Hr = cout(k, f, r)
                        if c < best[0]:
                            best = (c, k, f, r, Hr)
    return best


def _poids_cadrage(spec, t, longueur):
    """Poids (0..1, en S) du cadrage : monte de 0 à « plein[0] », tient, redescend après « plein[1] » (un bord de
    « plein » égal au bord du clip = pas de rampe de ce côté : clip de charge enchaîné au coup)."""
    t0, t1 = spec.get("plein", (0.0, longueur))
    a = 1.0
    if t < t0:
        a = t / t0
    elif t > t1 and t1 < longueur:
        a = (longueur - t) / (longueur - t1)
    a = max(0.0, min(1.0, a))
    return a * a * (3 - 2 * a)


def _cadrage(spec, t, longueur):
    """Correction de cadrage (rotation rigide du bras autour de l'épaule, repère caméra) : (lacet°, tangage°, roulis°)
    pondérée par _poids_cadrage."""
    lacet, tangage, roul = spec.get("cadrage", (0.0, 0.0, 0.0))
    a = _poids_cadrage(spec, t, longueur)
    return (Matrix.Rotation(math.radians(lacet * a), 3, "Y") @ Matrix.Rotation(math.radians(tangage * a), 3, "X")
            @ Matrix.Rotation(math.radians(roul * a), 3, "Z"))


def _repere_main(poignet, index, auriculaire):
    """Repère anatomique de la main (colonnes) : Y = du poignet vers les jointures, X = vers le pouce (auriculaire ->
    index), Z = X × Y (dos de la main pour une main droite)."""
    y = ((index + auriculaire) * 0.5 - poignet).normalized()
    x = index - auriculaire
    x = (x - y * x.dot(y)).normalized()
    return Matrix((x, y, x.cross(y))).transposed()


def _repere_main_local():
    """Le même repère anatomique, exprimé dans le repère de l'os hand_r de notre rig (constant)."""
    b = A.data.bones
    H = b["hand_r"].matrix_local
    F = _repere_main(H.to_translation(), b["index_01_r"].head_local, b["pinky_01_r"].head_local)
    return (H.to_3x3().normalized().inverted() @ F)


def creer_action_mixamo(nom, spec):
    """Clip retargeté depuis une capture Mixamo (`spec` : gestes_bras_epee.CLIPS_MIXAMO).
    Retarget par DIRECTIONS (pas par écart de rotations : la garde Mixamo, bras pendant en arrière, n'a rien à voir avec
    notre tenue FPS) : l'épaule de notre bras se déplace comme l'épaule Mixamo par rapport au cou (le buste tourne), le
    bras et l'avant-bras prennent les DIRECTIONS de la capture (repère caméra = tête, orientation fixe du joueur) avec nos
    longueurs d'os, la main prend l'orientation ANATOMIQUE de la main Mixamo (poignet -> jointures, auriculaire -> index) :
    l'épée, tenue par notre prise, suit donc la vraie main. Le poignet est résolu dans les butées (LIM_MX), la torsion de
    l'avant-bras absorbe la rotation de la main. Fondu en S depuis / vers la tenue validée (« fondu » : fin de l'entrée,
    début de la sortie, en s) et cadrage optionnel (rotation rigide du bras autour de l'épaule, en cloche)."""
    src = _mx_donnees()[spec["source"]]
    ref = _mx_image(src, spec.get("ref", 0))
    table = spec["temps"]
    longueur = table[-1][1]
    # pose de repos validée : rotations locales des os, et CIBLES (épaule, coude, poignet, repère de la main, repère
    # caméra) pour le fondu : on mélange les cibles puis on résout le bras (le poing va droit de la garde à l'armé au lieu
    # de passer par un mélange de rotations d'os)
    G = _repere_main_local()
    PREC[0] = None
    poser(dict(REPOS))
    repos_q = {nb: A.pose.bones[nb].matrix_basis.to_quaternion() for nb in OS_ANIMES}
    repos_loc = A.pose.bones["clavicle_r"].matrix_basis.to_translation()
    pc = lambda nb: CAM_DE_B @ A.pose.bones[nb].head
    S0, E0, W0 = pc("upperarm_r"), pc("lowerarm_r"), pc("hand_r")
    F0 = (CAM_DE_B.to_3x3() @ A.pose.bones["hand_r"].matrix.to_3x3().normalized() @ G).to_quaternion()
    l1 = (A.data.bones["upperarm_r"].head_local - A.data.bones["lowerarm_r"].head_local).length
    l2 = (A.data.bones["lowerarm_r"].head_local - A.data.bones["hand_r"].head_local).length
    act = bpy.data.actions.new(nom)
    act.use_fake_user = True
    A.animation_data_create()
    A.animation_data.action = act
    prec = {}
    prec_k = None
    n = int(round(longueur * 60))
    B3 = B_DE_CAM.to_3x3()
    cl, ua, la, ha = (A.pose.bones[x] for x in OS_ANIMES)
    echelle = spec.get("echelle_epaule", 1.0)
    t_in, t_out = spec.get("fondu", (0.0, longueur))
    rapport = []
    for i in range(n + 1):
        t = i / 60
        for (f0, t0), (f1, t1) in zip(table, table[1:]):
            if t0 - 1e-9 <= t <= t1 + 1e-9:
                a = (t - t0) / max(t1 - t0, 1e-6)
                break
        fr = f0 + (f1 - f0) * a
        im = _mx_image(src, fr)
        Q = _cadrage(spec, t, longueur)
        w = 1.0
        if t < t_in:
            w = t / t_in
        elif t > t_out:
            w = (longueur - t) / max(longueur - t_out, 1e-6)
        w = max(0.0, min(1.0, w))
        w = w * w * (3 - 2 * w)
        # épaule : déplacement de l'épaule Mixamo par rapport au cou
        for pb in (cl, ua, la, ha):
            pb.matrix_basis = Matrix.Identity(4)
        cl.matrix_basis = Quaternion(repos_q["clavicle_r"]).to_matrix().to_4x4()
        cl.location = repos_loc
        maj()
        dep = (im["p_epaule"] - ref["p_epaule"]) * echelle + Vector(spec.get("decalage", (0.0, 0.0, 0.0))) * _poids_cadrage(spec, t, longueur)
        cl.matrix = Matrix.Translation(B3 @ (dep * w)) @ cl.matrix
        maj()
        S = CAM_DE_B @ ua.head
        d_ua = Q @ (im["p_coude"] - im["p_epaule"]).normalized()
        d_la = Q @ (im["p_poignet"] - im["p_coude"]).normalized()
        E = S + d_ua * l1
        W = E + d_la * l2
        # fondu des cibles avec la garde (positions relatives à l'épaule, repère de la main en slerp)
        E = S + (E0 - S0).lerp(E - S, w)
        W = S + (W0 - S0).lerp(W - S, w)
        Fm = F0.slerp((Q @ _repere_main(im["p_poignet"], im["p_index"], im["p_auriculaire"])).to_quaternion(), w).to_matrix()
        coude, d2, Rl0, allonge = _bras_deux_os("r", B_DE_CAM @ W, (E - (S + W) * 0.5).normalized())
        Hd = B3 @ Fm @ G.inverted() @ Matrix.Rotation(math.radians(ROULIS_PRISE_MX), 3, PRISE_D.to_3x3().col[1].normalized())
        c, k, f, r, Hr = _resoudre_main(Rl0, Hd, prec_k)
        prec_k = k
        Rl = Matrix.Rotation(math.radians(k), 3, d2) @ Rl0
        la.matrix = Matrix.Translation(coude) @ Rl.to_4x4()
        maj()
        ha.matrix = Matrix.Translation(la.tail.copy()) @ Hr.to_4x4()
        maj()
        rapport.append((round(t, 3), round(fr, 1), k, f, r, round(c, 1), round(w, 2)))
        for nb in OS_ANIMES:
            pb = A.pose.bones[nb]
            q = pb.matrix_basis.to_quaternion()
            q0 = repos_q[nb]
            if q0.dot(q) < 0:
                q = -q
            q = q0.slerp(q, min(1.0, 4.0 * w))   # bords du clip : exactement la tenue validée (r = -32)
            if nb in prec and prec[nb].dot(q) < 0:
                q = -q
            prec[nb] = q
            if nb == "clavicle_r":
                loc = repos_loc.lerp(pb.matrix_basis.to_translation(), min(1.0, 4.0 * w))
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=t * FPS, group=nb)
            if nb == "clavicle_r":
                pb.location = loc
                pb.keyframe_insert("location", frame=t * FPS, group=nb)
    for fc in _fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
        fc.update()
    pire = max(x[5] for x in rapport)
    print("MIXAMO %-10s source %s, %d clés ; écart à la main Mixamo max %.1f (coût) ; torsion %d..%d flexion %d..%d inclinaison %d..%d" % (
        nom, spec["source"], len(rapport), pire, min(x[2] for x in rapport), max(x[2] for x in rapport),
        min(x[3] for x in rapport), max(x[3] for x in rapport), min(x[4] for x in rapport), max(x[4] for x in rapport)))
    if "detail" in ARGS:
        for x in rapport:
            print("MIXAMO_IMG", nom, x)
    return act, longueur

# --- clés d'animation ---------------------------------------------------------------------------------------------
def creer_action(nom, cles):
    act = bpy.data.actions.new(nom)
    act.use_fake_user = True
    A.animation_data_create()
    A.animation_data.action = act
    prec = {}
    PREC[0] = None
    for cle in cles:
        poser(cle)
        f = cle["t"] * FPS
        for n in OS_ANIMES:
            pb = A.pose.bones[n]
            q = pb.matrix_basis.to_quaternion()
            if n in prec and prec[n].dot(q) < 0:
                q = -q
            prec[n] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
            if n == "clavicle_r":
                pb.location = pb.matrix_basis.to_translation()
                pb.keyframe_insert("location", frame=f, group=n)
    # interpolation : Bézier ; les clés « passe » (milieu de frappe) gardent leur vitesse (poignées AUTO), les extrêmes
    # (armé, fin du suivi, repos) amortissent (AUTO_CLAMPED) ; « lin » = linéaire (choc bref)
    for fc in _fcurves(act):
        for i, kp in enumerate(fc.keyframe_points):
            mode = cles[i].get("interp", "amorti")
            if mode == "lin":
                kp.interpolation = "LINEAR"
            else:
                kp.interpolation = "BEZIER"
                kp.handle_left_type = kp.handle_right_type = "AUTO" if mode == "passe" else "AUTO_CLAMPED"
        fc.update()
    return act


def _fcurves(act):
    try:
        return list(act.fcurves)
    except AttributeError:   # actions à emplacements (Blender 4.4+)
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    out.extend(bag.fcurves)
        return out


def echantillons(act, longueur, freq=120):
    """Rotations LOCALES (repère du parent, comme Godot) des os animés, échantillonnées à `freq` Hz."""
    A.animation_data.action = act
    out = {n: [] for n in OS_ANIMES}
    nb = int(round(longueur * freq))
    for i in range(nb + 1):
        t = i / freq
        f = t * FPS
        scene.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
        for n in OS_ANIMES:
            pb = A.pose.bones[n]
            rest = M(D["os"][n]["rest"])
            loc = rest @ pb.matrix_basis
            q = loc.to_quaternion()
            if out[n] and out[n][-1][1].dot(q) < 0:
                q = -q
            out[n].append((t, q, loc.to_translation()))
    return out


def ecrire_godot(chemin, actions):
    lignes = []
    ids = []
    for nom, (act, longueur) in actions.items():
        ech = echantillons(act, longueur)
        sid = "Animation_" + nom
        ids.append((nom, sid))
        lignes.append('[sub_resource type="Animation" id="%s"]' % sid)
        lignes.append('resource_name = "%s"' % nom)
        lignes.append("length = %.5f" % longueur)
        pistes = [(n, "rotation_3d") for n in OS_ANIMES] + [("clavicle_r", "position_3d")]
        for i, (n, genre) in enumerate(pistes):
            vals = []
            for t, q, p in ech[n]:
                if genre == "rotation_3d":
                    vals += ["%.5f" % t, "1", "%.6f" % q.x, "%.6f" % q.y, "%.6f" % q.z, "%.6f" % q.w]
                else:
                    vals += ["%.5f" % t, "1", "%.6f" % p.x, "%.6f" % p.y, "%.6f" % p.z]
            lignes.append('tracks/%d/type = "%s"' % (i, genre))
            lignes.append("tracks/%d/imported = false" % i)
            lignes.append("tracks/%d/enabled = true" % i)
            lignes.append('tracks/%d/path = NodePath("%s:%s")' % (i, ARGS.get("chemin_squelette", "Armature/Skeleton3D"), n))
            lignes.append("tracks/%d/interp = 1" % i)
            lignes.append("tracks/%d/loop_wrap = true" % i)
            lignes.append("tracks/%d/keys = PackedFloat32Array(%s)" % (i, ", ".join(vals)))
        mq = MARQUEURS.get(nom, {})
        lignes.append("metadata/marqueurs = {%s}" % ", ".join('"%s": %.4f' % (k, v) for k, v in mq.items()))
        lignes.append("")
    tete = '[gd_resource type="AnimationLibrary" load_steps=%d format=3]\n' % (len(ids) + 1)
    corps = "\n".join(lignes)
    data = "[resource]\n_data = {\n" + ",\n".join('&"%s": SubResource("%s")' % (n, s) for n, s in ids) + "\n}\n"
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(tete + "\n" + corps + "\n" + data)
    print("GODOT", chemin, len(ids), "animations")


# --- aperçu (rendu vue caméra du jeu) -------------------------------------------------------------------------------
def preparer_rendu():
    # épée : modèle du jeu, accroché à la main par la prise du jeu
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(BASE, "assets", "modeles", "armes", "epees", "metal.glb"))
    neufs = [o for o in bpy.data.objects if o not in avant]
    epee = []
    for o in neufs:
        if o.type == "MESH":
            o["init"] = [v for row in o.matrix_world for v in row]
            epee.append(o)
    # torche : manche simple (aperçu)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.026, depth=0.5, vertices=8)
    t = bpy.context.object
    t.name = "torche_apercu"
    t.data.transform(Matrix.Translation((0, 0, 0.15)))
    cam_d = bpy.data.cameras.new("cam_jeu")
    cam = bpy.data.objects.new("cam_jeu", cam_d)
    scene.collection.objects.link(cam)
    cam.matrix_world = B_DE_CAM
    cam_d.sensor_fit = "VERTICAL"
    cam_d.angle_y = math.radians(D["fov"])
    # --vue=cote|dessus|epaule : contrôle des trajectoires sous d'autres angles (repère caméra du jeu : œil à l'origine)
    vue = ARGS.get("vue", "jeu")
    if vue != "jeu":
        poses = {"cote": ((1.7, -0.05, -0.55), (0.0, -0.15, -0.55), (0, 1, 0)),
                 "dessus": ((0.0, 1.9, -0.6), (0.0, -0.1, -0.6), (0, 0, -1)),
                 "epaule": ((0.9, 0.6, 1.1), (-0.05, -0.15, -0.7), (0, 1, 0))}
        oeil, cible, haut = (Vector(v) for v in poses[vue])
        z = (oeil - cible).normalized()
        x = Vector(haut).cross(z).normalized()
        y = z.cross(x)
        m = Matrix.Identity(4)
        for r in range(3):
            m[r][0], m[r][1], m[r][2], m[r][3] = x[r], y[r], z[r], oeil[r]
        cam.matrix_world = B_DE_CAM @ m
        cam_d.angle_y = math.radians(55)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.04, location=(B_DE_CAM @ Vector((0, 0, 0))))   # œil du joueur
    cam_d.clip_start = 0.02
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 480, 270
    scene.render.resolution_percentage = 200
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = False
    sh.show_cavity = True
    scene.render.film_transparent = False
    w = scene.world or bpy.data.worlds.new("w")
    scene.world = w
    w.color = (0.55, 0.62, 0.72)
    return epee, t


def placer_accessoires(epee, torche):
    H = A.matrix_world @ A.pose.bones["hand_r"].matrix
    for o in epee:
        init = Matrix([o["init"][i * 4:(i + 1) * 4] for i in range(4)])
        o.matrix_world = H @ PRISE_D @ C @ init
    G = A.matrix_world @ A.pose.bones["hand_l"].matrix
    # manche de torche : +Y du jeu (Godot) = +Z Blender du cylindre après C
    torche.matrix_world = G @ PRISE_G @ C @ Matrix.Rotation(math.radians(-90), 4, "X")


def mesures_cam():
    """Pointe / garde à l'écran et angle du plat (roulis) pour la pose courante."""
    H = A.pose.bones["hand_r"].matrix
    W = CAM_DE_B @ H @ PRISE_D       # repère de l'épée, repère caméra
    g = W @ GARDE
    p = W @ POINTE
    tv, th = math.tan(math.radians(D["fov"]) / 2), math.tan(math.radians(D["fov"]) / 2) * 16 / 9
    ecr = lambda v: (round(v.x / -v.z / th, 2), round(v.y / -v.z / tv, 2))
    milieu = (g + p) * 0.5
    z = W.to_3x3() @ Vector((0, 0, 1))
    plat = math.degrees(math.acos(min(1, abs(z.normalized().dot((-milieu).normalized())))))
    return ecr(g), ecr(p), round(plat)


def explorer(noms):
    """Lames atteignables pour la position de poing / coude de clés nommées : torsion k × inclinaison r × flexion f."""
    import gestes_bras_epee as G
    tv = math.tan(math.radians(D["fov"]) / 2)
    th = tv * 16 / 9
    for nom in noms:
        base = getattr(G, nom)
        print("EXPLORER", nom, "poing", tuple(round(v, 2) for v in base["poing"]))
        ks, fs, rs = (-80, -40, 0, 40, 84), (-40, 0, 40), (-35, 0, 20)
        if "grille" in ARGS:      # --grille=k0:k1:pas,f0:f1:pas,r0:r1:pas
            ks, fs, rs = (range(int(a), int(b) + 1, int(c)) for a, b, c in (x.split(":") for x in ARGS["grille"].split(",")))
        for k in ks:
            for f in fs:
                for r in rs:
                    c = dict(base, k=k, f=f, r=r)
                    poser(c)
                    W = CAM_DE_B @ A.pose.bones["hand_r"].matrix @ PRISE_D
                    y = (W.to_3x3() @ Vector((0, 1, 0))).normalized()
                    p = W @ POINTE
                    g = W @ GARDE
                    e = lambda v: "(%.2f,%.2f)" % (v.x / -v.z / th, v.y / -v.z / tv) if v.z < -0.01 else "(derr)"
                    z = (W.to_3x3() @ Vector((0, 0, 1))).normalized()
                    plat = math.degrees(math.acos(min(1, abs(z.dot((-(g + p) * 0.5).normalized())))))
                    vx, vy = (p.x / -p.z - g.x / -g.z) / th * 16, (p.y / -p.z - g.y / -g.z) / tv * 9
                    print("  vert %5.1f" % math.degrees(math.atan2(-vx, vy)), end="")
                    print("  k%4d f%4d r%4d  lame (%.2f,%.2f,%.2f) garde %s pointe %s plat %d" % (k, f, r, y.x, y.y, y.z, e(g), e(p), plat))


def mesurer_clips(actions):
    """--mesurer : géométrie image par image (60 i/s, sans rendu) : garde / pointe à l'écran, part de la lame DANS le cadre
    (hors occultation par le bras : la mesure complète est outils/captures_combat_epee.gd --mesures), part du plat vue."""
    tv = math.tan(math.radians(D["fov"]) / 2)
    th = tv * 16 / 9
    for nom, (act, longueur) in actions.items():
        A.animation_data.action = act
        n = int(math.floor(longueur * 60 + 1e-6)) + 1
        for i in range(n):
            t = i / 60
            f = t * FPS
            scene.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
            W = CAM_DE_B @ A.pose.bones["hand_r"].matrix @ PRISE_D
            g = W @ GARDE
            p = W @ POINTE
            vus = 0
            for k in range(25):
                q = g.lerp(p, k / 24)
                if q.z < -0.02 and abs(q.x / -q.z / th) <= 1 and abs(q.y / -q.z / tv) <= 1:
                    vus += 1
            z = (W.to_3x3() @ Vector((0, 0, 1))).normalized()
            part = abs(z.dot((-(g + p) * 0.5).normalized()))
            visee = math.degrees(math.acos(min(1.0, abs((p - g).normalized().dot(((g + p) * 0.5).normalized())))))
            e = lambda v: "(%5.2f,%5.2f)" % (v.x / -v.z / th, v.y / -v.z / tv) if v.z < -0.01 else "(derriere)"
            coude = CAM_DE_B @ A.pose.bones["lowerarm_r"].head
            print("MESURER %-14s #%02d t=%.3f garde %s pointe %s cadre %3d%% plat %3d%% visee %2d coude %s" % (nom, i, t, e(g), e(p), round(100 * vus / 25), round(100 * part), round(visee), e(coude)))


def angles_poignet():
    """Flexion f (+ vers la paume) et inclinaison r (+ radiale, vers le pouce) de la main droite par rapport à
    l'avant-bras (mêmes axes que _poignet), en degrés, plus la « cassure » totale (angle avant-bras / main)."""
    la, ha = A.pose.bones["lowerarm_r"], A.pose.bones["hand_r"]
    lrel = A.data.bones["lowerarm_r"].matrix_local.to_3x3().inverted() @ A.data.bones["hand_r"].matrix_local.to_3x3()
    Rw = lrel.inverted() @ la.matrix.to_3x3().normalized().inverted() @ ha.matrix.to_3x3().normalized()
    y = Vector((0, 1, 0))
    a_f = y.cross(_axe_local("hand_r", (0, 0, -1))).normalized()
    a_r = y.cross(_axe_local("hand_r", (0, -1, 0))).normalized()
    v = Rw @ y
    r = math.degrees(math.asin(max(-1.0, min(1.0, v.dot(a_r.cross(y))))))
    f = math.degrees(math.atan2(v.dot(a_f.cross(y)), v.dot(y)))
    return f, r, math.degrees(math.acos(max(-1.0, min(1.0, v.dot(y)))))


def mesurer_fouet(actions):
    """--fouet : le poignet fouette-t-il ? Par image (60 i/s) : angles du poignet, poing et pointe à l'écran, vitesses à
    l'écran (hauteurs d'écran / s, x corrigé du format 16/9) et signe « pointe devant / derrière la main » dans le sens du
    coup (sens = déplacement du milieu de lame à l'écran ; devant = (pointe - poing) · sens > 0).
    Résumé (fenêtre frappe -> fin_frappe des MARQUEURS) : part des images où la pointe est devant, rapport moyen des
    vitesses pointe / poing, amplitude du poignet (f, r, cassure)."""
    tv = math.tan(math.radians(D["fov"]) / 2)
    th = tv * 16 / 9
    ecr = lambda v: Vector((v.x / -v.z / th * 16 / 9, v.y / -v.z / tv)) if v.z < -0.01 else None
    for nom, (act, longueur) in actions.items():
        A.animation_data.action = act
        m = MARQUEURS.get(nom, {})
        t0, t1 = m.get("frappe", 0.0), m.get("fin_frappe", longueur)
        n = int(math.floor(longueur * 60 + 1e-6)) + 1
        img = []
        m6, zs = [], []     # milieu de lame (0,6) et normale du plat, repère caméra : « le tranchant mène » (test_combat_epee)
        for i in range(n):
            t = i / 60
            fr = t * FPS
            scene.frame_set(int(math.floor(fr)), subframe=fr - math.floor(fr))
            W = CAM_DE_B @ A.pose.bones["hand_r"].matrix @ PRISE_D
            poing = W @ Vector((0, MILIEU_POIGNEE, 0))
            p = W @ POINTE
            mil = (W @ GARDE + p) * 0.5
            f, r, c = angles_poignet()
            img.append((t, ecr(poing), ecr(p), ecr(mil), f, r, c))
            m6.append((W @ GARDE).lerp(p, 0.6))
            zs.append((W.to_3x3() @ Vector((0, 0, 1))).normalized())
        devant = []      # pointe devant le poing (position) dans le sens du coup
        fouette = []     # la pointe gagne sur le poing (vitesse relative pointe - poing dans le sens du coup > 0)
        rapports = []
        pos_debut = pos_fin = None
        for i, (t, po, pt, mi, f, r, c) in enumerate(img):
            sgn, rel, rap, vpo, vpt = 0.0, 0.0, 0.0, 0.0, 0.0
            dans = t0 - 1e-6 <= t <= t1 + 1e-6
            voisins = [img[j][k] for j in (i - 1, i + 1) for k in (1, 2, 3)] if 0 < i < n - 1 else [None]
            if None not in voisins and None not in (po, pt, mi):
                vmi = (img[i + 1][3] - img[i - 1][3]) * 30
                vpo_v = (img[i + 1][1] - img[i - 1][1]) * 30
                vpt_v = (img[i + 1][2] - img[i - 1][2]) * 30
                vpo, vpt = vpo_v.length, vpt_v.length
                if vmi.length > 0.3:
                    d = vmi.normalized()
                    sgn = (pt - po).dot(d) / max((pt - po).length, 1e-6)
                    rel = (vpt_v - vpo_v).dot(d)
                rap = vpt / max(vpo, 1e-3)
                if dans and vmi.length > 0.3:
                    devant.append(sgn > 0.0)
                    fouette.append(rel > 0.0)
                    rapports.append(rap)
                    if pos_debut is None:
                        pos_debut = sgn
                    pos_fin = sgn
            e = lambda v: "(%5.2f,%5.2f)" % (v.x * 9 / 16, v.y) if v is not None else "(derriere)"
            etat = "DEVANT  " if sgn > 0.05 else ("DERRIERE" if sgn < -0.05 else "--      ")
            print("FOUET %-14s #%02d t=%.3f%s poignet f %4d r %4d cassure %3d  poing %s pointe %s  v_poing %4.1f v_pointe %5.1f  rel %+6.1f %s  pointe %s (%5.2f)" % (
                nom, i, t, "*" if dans else " ", round(f), round(r), round(c), e(po), e(pt), vpo, vpt, rel,
                "FOUETTE" if rel > 0 else ("LEVIER " if rel < 0 else "       "), etat, sgn))
        fils = []
        for i in range(n - 1):
            mv = m6[i + 1] - m6[i]
            if t0 - 1e-6 <= img[i][0] and img[i + 1][0] <= t1 + 1e-6 and mv.length > 1e-4:
                fils.append(math.degrees(math.acos(min(1.0, abs(zs[i + 1].dot(mv.normalized()))))))
        fs = [x[4] for x in img]
        rs = [x[5] for x in img]
        cs = [x[6] for x in img]
        print("FOUET_RESUME %-14s frappe %d images : pointe qui gagne sur le poing %3d%%, pointe devant %3d%% (début %+.2f, fin %+.2f) ; v_pointe / v_poing moyen %.1f ; fil moyen %d° (tranchant qui mène >= 70) ; poignet f %d..%d r %d..%d cassure %d..%d" % (
            nom, len(devant), round(100 * sum(fouette) / max(1, len(fouette))), round(100 * sum(devant) / max(1, len(devant))),
            pos_debut or 0.0, pos_fin or 0.0, sum(rapports) / max(1, len(rapports)), round(sum(fils) / max(1, len(fils))),
            round(min(fs)), round(max(fs)), round(min(rs)), round(max(rs)), round(min(cs)), round(max(cs))))


def verifier_butees(actions):
    """--butees : angles du poignet image par image (120 i/s) ; ÉCHEC si une image sort des butées anatomiques
    (BUTEES_ANATOMIQUES : flexion / extension ±60°, inclinaison radiale 20°, cubitale 30°)."""
    (f0, f1), (r0, r1) = BUTEES_ANATOMIQUES["flexion"], BUTEES_ANATOMIQUES["inclinaison"]
    ok = True
    for nom, (act, longueur) in actions.items():
        A.animation_data.action = act
        fs, rs, hors = [], [], []
        for i in range(int(math.floor(longueur * 120 + 1e-6)) + 1):
            t = i / 120
            scene.frame_set(int(math.floor(t * FPS)), subframe=t * FPS - math.floor(t * FPS))
            f, r, _c = angles_poignet()
            fs.append(f)
            rs.append(r)
            if not (f0 - 0.5 <= f <= f1 + 0.5 and r0 - 0.5 <= r <= r1 + 0.5):
                hors.append("t=%.3f f %d r %d" % (t, round(f), round(r)))
        ok = ok and not hors
        print("BUTEES %-14s %s  flexion %d..%d  inclinaison %d..%d%s" % (nom, "OK   " if not hors else "ECHEC", round(min(fs)), round(max(fs)),
              round(min(rs)), round(max(rs)), ("  hors butées : " + ", ".join(hors[:6]) + (" …" if len(hors) > 6 else "")) if hors else ""))
    print("BUTEES_RESUME", "OK" if ok else "ECHEC")


def main():
    poings()
    if "explorer" in ARGS:
        explorer(ARGS["explorer"].split(","))
        return
    if "rendu" not in ARGS:
        poser_torche()
    clips = ARGS.get("clips", "")
    noms = [c for c in clips.split(",") if c] or list(dict.fromkeys(list(CLIPS) + list(CLIPS_MIXAMO)))
    actions = {}
    for nom in noms:
        if nom in CLIPS_MIXAMO:
            actions[nom] = creer_action_mixamo(nom, CLIPS_MIXAMO[nom])
            continue
        cles = CLIPS[nom]
        act = creer_action(nom, cles)
        actions[nom] = (act, cles[-1]["t"])
    print("POIGNET  (clé, allonge, torsion avant-bras° (+ supination), flexion°, inclinaison° (+ radiale), erreur lame°, coût)")
    for r in RAPPORT:
        print("POIGNET ", r)
    if "rendu" in ARGS:
        dossier = ARGS["rendu"]
        os.makedirs(dossier, exist_ok=True)
        epee, torche = preparer_rendu()
        pas = float(ARGS.get("pas", "0.0333"))
        for nom in noms:
            act, longueur = actions[nom]
            A.animation_data.action = act
            n = int(math.floor(longueur / pas + 1e-6)) + 1
            for i in range(n):
                t = i * pas
                f = t * FPS
                scene.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
                poser_torche()
                placer_accessoires(epee, torche)
                g, p, plat = mesures_cam()
                print("MESURE %s t=%.3f garde=%s pointe=%s plat=%d" % (nom, t, g, p, plat))
                scene.render.filepath = os.path.join(dossier, "%s_%03d.png" % (nom, i))
                bpy.ops.render.render(write_still=True)
    if "mesurer" in ARGS:
        mesurer_clips(actions)
    if "fouet" in ARGS:
        mesurer_fouet(actions)
    if "butees" in ARGS:
        verifier_butees(actions)
    if "godot" in ARGS:
        ecrire_godot(os.path.join(BASE, "assets", "animations", "bras_epee.tres"), actions)
    if "blend" in ARGS:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BASE, "sources_blender", "bras_fps_anims.blend"), copy=True)
    print("FIN OK")


main()
