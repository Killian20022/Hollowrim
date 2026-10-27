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
    else:                           # pose tenue : angle du plat avec la direction de l'œil
        milieu = W.translation.to_3d() + y * 0.5
        plat = math.degrees(math.acos(min(1.0, abs(z.dot((-milieu).normalized())))))
        c += 0.6 * abs(plat - cle.get("roulis", 70.0))
    k, f, r = kfr
    c += 0.03 * (abs(k - cle.get("torsion", 0)) + abs(f) + abs(r))
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
                grille = (range(LIM_TORSION[0], LIM_TORSION[1] + 1, 20), range(LIM_FLEXION[0], LIM_FLEXION[1] + 1, 20), range(LIM_INCL[0], LIM_INCL[1] + 1, 10))
            else:
                grille = (range(LIM_TORSION[0], LIM_TORSION[1] + 1, 10), range(LIM_FLEXION[0], LIM_FLEXION[1] + 1, 10), range(LIM_INCL[0], LIM_INCL[1] + 1, 5))
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
                        if not (LIM_TORSION[0] <= k <= LIM_TORSION[1] and LIM_FLEXION[0] <= f <= LIM_FLEXION[1] and LIM_INCL[0] <= r <= LIM_INCL[1]):
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


from gestes_bras_epee import CLIPS, MARQUEURS  # noqa: E402  (fichier voisin : les poses clés et les instants)


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


def main():
    poings()
    if "explorer" in ARGS:
        explorer(ARGS["explorer"].split(","))
        return
    if "rendu" not in ARGS:
        poser_torche()
    clips = ARGS.get("clips", "")
    noms = [c for c in clips.split(",") if c] or list(CLIPS)
    actions = {}
    for nom in noms:
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
    if "godot" in ARGS:
        ecrire_godot(os.path.join(BASE, "assets", "animations", "bras_epee.tres"), actions)
    if "blend" in ARGS:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BASE, "sources_blender", "bras_fps_anims.blend"), copy=True)
    print("FIN OK")


main()
