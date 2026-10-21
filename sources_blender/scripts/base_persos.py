# Lot « personnages de base » (graphisme/persos-base) : BASE MESH unifie + tetes + cheveux + barbes + accessoires, skinnes sur RIG18.
#   blender.exe -b --python base_persos.py -- homme|femme [--apercu=<dossier>]
# Entree : sources_blender/{homme_vetu,femme_vetue}_lot1.glb (SQUELETTE seulement : noms et reperes d'os conserves pour les animations).
# Sortie : assets/modeles/persos/kit_<sexe>.glb (armature RIG18 + os secondaires, un maillage par piece) et
#          assets/personnages/mise_en_page_<sexe>.json (rectangles d'atlas 256x256, lus par PersoAtlas pour peindre les textures).
# Rejouable : le script ne lit que les *_lot1.glb (jamais sa propre sortie).
import bpy, bmesh, math, os, sys, json
from mathutils import Vector
ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
exec(open(os.path.join(ICI, "persos_lib.py")).read())
args = sys.argv[sys.argv.index("--") + 1:]
SEXE = args[0]
F = SEXE == "femme"
APERCU = next((a.split("=", 1)[1] for a in args if a.startswith("--apercu=")), None)
SRC = os.path.join(BASE, "sources_blender", {"homme": "homme_vetu_lot1.glb", "femme": "femme_vetue_lot1.glb"}[SEXE])
SORTIE = os.path.join(BASE, "assets", "modeles", "persos", "kit_%s.glb" % SEXE)
JSON_ = os.path.join(BASE, "assets", "personnages", "mise_en_page_%s.json" % SEXE)
os.makedirs(os.path.dirname(SORTIE), exist_ok=True); os.makedirs(os.path.dirname(JSON_), exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for o in list(bpy.data.objects):
    if o.type != 'ARMATURE':
        bpy.data.objects.remove(o)
RIG18 = [l.strip() for l in open(os.path.join(BASE, "sources_blender", "rig18.txt")) if l.strip()]
BONE = {b.name: (Vector(b.head_local), Vector(b.tail_local)) for b in arm.data.bones}

# ------------------------------------------------------------------ squelette : RIG18 + os secondaires (hors RIG18, <= 26 os)
def ajuster_squelette():
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    for b in list(eb):
        if b.name not in RIG18:
            eb.remove(b)
    hs = BONE["spine_03"][1]; hd = BONE["Head"][0]
    yb = BONE["spine_03"][0].y + (0.115 if not F else 0.105)       # dos
    def os2(nom, parent, tete, queue):
        b = eb.new(nom); b.head = tete; b.tail = queue; b.parent = eb[parent]; b.use_connect = False
        b.align_roll(Vector((1, 0, 0)))
    z0 = hs.z - 0.03
    os2("cape_1", "spine_03", Vector((0, yb, z0)), Vector((0, yb + 0.03, z0 - 0.2)))
    os2("cape_2", "cape_1", Vector((0, yb + 0.03, z0 - 0.2)), Vector((0, yb + 0.07, z0 - 0.45)))
    os2("capuche_1", "Head", Vector((0, BONE["Head"][0].y + 0.07, hd.z + 0.02)), Vector((0, BONE["Head"][0].y + 0.1, hd.z - 0.14)))
    zt = BONE["pelvis"][0].z + 0.06; zg = BONE["calf_l"][0].z; zh = BONE["calf_l"][0].z * 0.5
    yv = BONE["pelvis"][0].y - 0.13
    os2("pan_av_1", "pelvis", Vector((0, yv, zt)), Vector((0, yv - 0.02, zh)))
    os2("pan_ar_1", "pelvis", Vector((0, BONE["pelvis"][0].y + 0.13, zt)), Vector((0, BONE["pelvis"][0].y + 0.14, zg - 0.05)))
    bpy.ops.object.mode_set(mode='OBJECT')
ajuster_squelette()
SECONDAIRES = ["cape_1", "cape_2", "capuche_1", "pan_av_1", "pan_ar_1"]
assert len(RIG18) + len(SECONDAIRES) <= 26

# ------------------------------------------------------------------ repere
def P(b, t=0.0):
    h, q = BONE[b]
    return h + (q - h) * t

_chaine = [BONE["pelvis"][0], BONE["spine_01"][0], BONE["spine_02"][0], BONE["spine_03"][0], BONE["spine_03"][1]]
_cum = [0.0]
for a, b in zip(_chaine, _chaine[1:]):
    _cum.append(_cum[-1] + (b - a).length)

def spine(u):
    """Point de la colonne a la fraction u (0 = bassin, 1 = haut de spine_03), prolonge en dessous / au-dessus."""
    d = u * _cum[-1]
    if d <= 0:
        a, b = _chaine[0], _chaine[1]
        return a + (b - a).normalized() * d
    for i in range(len(_cum) - 1):
        if d <= _cum[i + 1]:
            a, b = _chaine[i], _chaine[i + 1]
            return a + (b - a) * ((d - _cum[i]) / (_cum[i + 1] - _cum[i]))
    a, b = _chaine[-2], _chaine[-1]
    return b + (b - a).normalized() * (d - _cum[-1])

def lerp(a, b, t):
    return a + (b - a) * t

# ------------------------------------------------------------------ morphologie : niveaux du torse (u, rx, ry, dy_avant, poids)
# rx : demi-largeur, ry : demi-profondeur, dy : decalage vers l'avant (poitrine). Valeurs en metres, relevees sur les proportions Skyrim
# (epaules larges, taille marquee) ; la femme est plus etroite aux epaules (squelette Quaternius : epaule a 15 cm contre 21 cm).
if not F:
    TORSE = [(-0.10, 0.212, 0.128, 0.0, {"pelvis": 1}), (0.12, 0.205, 0.122, 0.0, {"pelvis": 1}), (0.36, 0.170, 0.108, 0.0, {"spine_01": 1}),
             (0.58, 0.178, 0.116, 0.0, {"spine_01": 0.4, "spine_02": 0.6}), (0.80, 0.200, 0.122, 0.0, {"spine_02": 0.5, "spine_03": 0.5}),
             (0.95, 0.192, 0.105, 0.0, {"spine_03": 1}), (1.06, 0.095, 0.078, 0.0, {"spine_03": 1})]
else:
    TORSE = [(-0.10, 0.200, 0.120, 0.0, {"pelvis": 1}), (0.12, 0.195, 0.115, 0.0, {"pelvis": 1}), (0.36, 0.140, 0.095, 0.0, {"spine_01": 1}),
             (0.58, 0.150, 0.108, 0.010, {"spine_01": 0.4, "spine_02": 0.6}), (0.80, 0.160, 0.118, 0.012, {"spine_02": 0.5, "spine_03": 0.5}),
             (0.95, 0.158, 0.096, 0.0, {"spine_03": 1}), (1.06, 0.080, 0.070, 0.0, {"spine_03": 1})]

def torse_a(u, marge=0.0):
    """Anneau interpole du torse a la fraction u (pour que gilet, ceinture, tablier... epousent le corps a `marge` pres)."""
    lv = TORSE
    if u <= lv[0][0]: a = b = lv[0]; t = 0
    elif u >= lv[-1][0]: a = b = lv[-1]; t = 0
    else:
        for i in range(len(lv) - 1):
            if lv[i][0] <= u <= lv[i + 1][0]:
                a, b = lv[i], lv[i + 1]; t = (u - a[0]) / (b[0] - a[0]); break
    rx = lerp(a[1], b[1], t) + marge; ry = lerp(a[2], b[2], t) + marge; dy = lerp(a[3], b[3], t)
    # poids : os du niveau le plus proche
    w = a[4] if t < 0.5 else b[4]
    if a[4] != b[4] and 0.2 < t < 0.8:
        w = {}
        for k, v in a[4].items(): w[k] = w.get(k, 0) + v * (1 - t)
        for k, v in b[4].items(): w[k] = w.get(k, 0) + v * t
        w = dict(sorted(w.items(), key=lambda kv: -kv[1])[:2])
    return spine(u), rx, ry, -dy, w

def anneau_torse(u, marge=0.0):
    c, rx, ry, dy, w = torse_a(u, marge)
    return Anneau(c, rx, ry, w, dy=dy)

# ------------------------------------------------------------------ pieces
def nouvelle(nom, double=False):
    p = Piece(nom, double); PIECES.append(p); return p

def cote(nom, s):
    return nom + ("_l" if s > 0 else "_r")

def pieces_corps():
    corps = nouvelle("corps")
    # --- torse (tunique) : ourlet au bassin, col aux epaules
    ring = [anneau_torse(u) for (u, *_r) in TORSE]
    tube(corps, "torse", ring, n=8, cap0=True, cap1=True, kind="tunique", debut="ourlet", fin="col")
    # --- cou (peau)
    r = 0.052 if not F else 0.045
    tube(corps, "cou", [Anneau(P("neck_01", -0.15), r + 0.006, r + 0.004, {"spine_03": 0.5, "neck_01": 0.5}),
                        Anneau(P("neck_01", 0.85), r, r, {"neck_01": 1}),
                        Anneau(P("Head", 0.35), r, r, {"Head": 1})], n=6, kind="peau", debut="aucun", fin="aucun")
    sg = 0.9 if F else 1.0
    for s in (1, -1):
        sf = "_l" if s > 0 else "_r"
        ua, la, ha = "upperarm" + sf, "lowerarm" + sf, "hand" + sf
        ex = Vector((0, 0, 1))
        k = (0.84 if F else 1.0)
        rings = [Anneau(P(ua, -0.20), 0.088 * k, 0.088 * k, {"clavicle" + sf: 0.5, ua: 0.5}, e1=ex),
                 Anneau(P(ua, 0.20), 0.074 * k, 0.076 * k, {ua: 1}, e1=ex),
                 Anneau(P(ua, 0.98), 0.060 * k, 0.062 * k, {ua: 0.5, la: 0.5}, e1=ex),
                 Anneau(P(la, 0.45), 0.054 * k, 0.056 * k, {la: 1}, e1=ex),
                 Anneau(P(la, 1.0), 0.041 * k, 0.043 * k, {la: 0.5, ha: 0.5}, e1=ex)]
        tube(corps, "manche" + sf, rings, n=8, cap1=True, kind="tunique", debut="aucun", fin="poignet", hint=(0, 0, 1))
        # --- main (moufle a pouce separe), paume vers le bas dans la pose de repos
        w0 = P(la, 1.0); dirx = Vector((s, 0, 0)); hk = 0.88 if F else 1.0
        def hp(d): return w0 + dirx * d
        rh = [Anneau(hp(-0.02), 0.026 * hk, 0.034 * hk, {la: 0.3, ha: 0.7}, e1=ex),
              Anneau(hp(0.045), 0.023 * hk, 0.044 * hk, {ha: 1}, e1=ex),
              Anneau(hp(0.115), 0.021 * hk, 0.047 * hk, {ha: 1}, e1=ex),
              Anneau(hp(0.185), 0.013 * hk, 0.030 * hk, {ha: 1}, e1=ex)]
        tube(corps, "main" + sf, rh, n=6, cap1=True, kind="peau", hint=(0, 0, 1))
        tp = [Anneau(hp(0.05) + Vector((0, -0.035 * hk, 0)), 0.016 * hk, 0.016 * hk, {ha: 1}, t=(s * 0.45, -0.9, 0), e1=ex),
              Anneau(hp(0.085) + Vector((0, -0.075 * hk, 0)), 0.012 * hk, 0.012 * hk, {ha: 1}, t=(s * 0.45, -0.9, 0), e1=ex)]
        tube(corps, "pouce" + sf, tp, n=4, cap1=True, kind="peau", hint=(0, 0, 1))
        # --- jambe : pantalon (hanche -> cheville), botte (mollet -> orteil)
        th, ca, fo = "thigh" + sf, "calf" + sf, "foot" + sf
        kt = 1.0 if not F else 1.02
        # v2 : cuisse pleine, genou net, mollet galbe (renfle vers l'arriere, +y = dos dans ce squelette), cheville fine
        rj = [Anneau(P(th, -0.04), (0.098 if not F else 0.094) * kt, 0.114 * kt, {"pelvis": 0.5, th: 0.5}),
              Anneau(P(th, 0.40), 0.106 * kt, 0.110 * kt, {th: 1}),
              Anneau(P(ca, 0.0), 0.077 * kt, 0.081 * kt, {th: 0.5, ca: 0.5}),
              Anneau(P(ca, 0.30), 0.083 * kt, 0.092 * kt, {ca: 1}, dy=0.008),
              Anneau(P(ca, 1.0), 0.049, 0.051, {ca: 0.5, fo: 0.5})]
        tube(corps, "jambe" + sf, rj, n=8, kind="pantalon", debut="aucun", fin="cheville")
        # botte v2 : fut qui epouse le mollet, cou-de-pied, BOUT ARRONDI (profil d'ellipse : r = R sqrt(1 - (s/L)^2)), semelle au sol
        fd = (P(fo, 1.0) - P(fo, 0.0)).normalized()
        def bout(d, f): return P(fo, 1.0) + fd * d
        rb = [Anneau(P(ca, 0.38), 0.091, 0.098, {ca: 1}, dy=0.004),
              Anneau(P(ca, 1.0), 0.066, 0.074, {ca: 0.5, fo: 0.5}, dy=0.010),
              Anneau(P(fo, 0.50), 0.060, 0.058, {fo: 1}),
              Anneau(P(fo, 1.0), 0.061, 0.047, {fo: 1}),
              Anneau(bout(0.045, 0), 0.054, 0.041, {fo: 1}),
              Anneau(bout(0.080, 0), 0.036, 0.027, {fo: 1})]
        tube(corps, "botte" + sf, rb, n=8, cap1=True, kind="cuir", debut="revers", fin="semelle")
    return corps

def bagues():
    bg = nouvelle("bagues", double=True)
    # ceinture (cuir) : deux anneaux autour du torse a la taille ; col de la tunique ; bracelets ; revers de bottes
    tube(bg, "ceinture", [anneau_torse(0.07, 0.014), anneau_torse(0.20, 0.014)], n=8, kind="cuir", debut="aucun", fin="aucun")
    r = (0.052 if not F else 0.045) + 0.02
    tube(bg, "collet", [Anneau(P("neck_01", -0.45), r + 0.03, r + 0.02, {"spine_03": 1}),
                        Anneau(P("neck_01", 0.20), r, r - 0.004, {"neck_01": 1})], n=8, kind="tunique", debut="aucun", fin="col")
    k = (0.84 if F else 1.0)
    for s in (1, -1):
        sf = "_l" if s > 0 else "_r"
        la = "lowerarm" + sf; ex = Vector((0, 0, 1))
        tube(bg, "bracelet" + sf, [Anneau(P(la, 0.80), 0.047 * k + 0.012, 0.049 * k + 0.012, {la: 1}, e1=ex),
                                   Anneau(P(la, 1.04), 0.043 * k + 0.012, 0.045 * k + 0.012, {la: 0.6, "hand" + sf: 0.4}, e1=ex)], n=8, kind="cuir", hint=(0, 0, 1))
        ca = "calf" + sf
        tube(bg, "revers" + sf, [Anneau(P(ca, 0.33), 0.092, 0.096, {ca: 1}), Anneau(P(ca, 0.47), 0.088, 0.092, {ca: 1})], n=6, kind="fourrure")
    return bg

pieces_corps(); bagues()

# ------------------------------------------------------------------ tetes (3), cheveux (3), barbes (2)
HZ0 = BONE["Head"][0].z; HY = BONE["Head"][0].y
HS = 1.07            # v2 : tete agrandie de 7 % (23 cm de haut au lieu de 21,5 : 1/8 de la taille, proportion realiste, visage plus lisible)
ECH = (0.93 if F else 1.0) * HS
DENSITE_VISAGE = 128.0   # texels/m du crane (visage lisible : yeux de 4 texels) ; nez 96, oreilles 64
def hz(z):            # hauteur d'un niveau de tete du modele masculin (repere du squelette masculin : os Head a 1,600) -> squelette courant
    return HZ0 + (z - 1.600) * ECH

# (z, rx, ry, avant) du crane a la machoire ; modele masculin, en metres
TETE0 = [(1.597, .040, .052, .020), (1.628, .066, .082, .008), (1.660, .076, .095, .004), (1.692, .082, .100, .002),
         (1.728, .083, .102, .000), (1.752, .081, .100, .004), (1.784, .072, .090, .000), (1.812, .040, .056, -.010)]
def table_tete(v):
    t = [list(r) for r in TETE0]
    if v == 1:     # visage carre : machoire et menton larges
        t[0][1] += .010; t[1][1] += .010; t[2][1] += .004; t[1][3] += .006
    elif v == 2:   # visage long, etroit, menton avance
        for r in t: r[1] -= .006
        t[0][3] += .012; t[1][3] += .008; t[0][1] -= .002
    else:          # visage rond, joues pleines
        t[0][1] -= .006; t[2][1] += .006; t[3][1] += .006; t[2][2] -= .004; t[3][2] -= .004
    if F:
        for r in t: r[1] *= 0.92; r[2] *= 0.94
        t[0][1] -= .006; t[1][1] -= .008; t[3][1] += .002; t[4][2] += .002
    for r in t: r[1] *= HS; r[2] *= HS
    return t

def interp(t, z):
    zz = [hz(r[0]) for r in t]
    if z <= zz[0]: r = t[0]; return r[1], r[2], r[3]
    if z >= zz[-1]: r = t[-1]; return r[1], r[2], r[3]
    for i in range(len(t) - 1):
        if zz[i] <= z <= zz[i + 1]:
            u = (z - zz[i]) / (zz[i + 1] - zz[i]); a, b = t[i], t[i + 1]
            return lerp(a[1], b[1], u), lerp(a[2], b[2], u), lerp(a[3], b[3], u)

def anneau_tete(t, z, off=0.0, w=None, vz=None):
    rx, ry, av = interp(t, z)
    return Anneau((0, HY, z), rx + off, ry + off, w or {"Head": 1}, dy=-(av * ECH), vz=vz)

def pieces_tetes():
    for v in (1, 2, 3):
        p = nouvelle("tete_%d" % v)
        t = table_tete(v)
        rings = [Anneau((0, HY, hz(r[0])), r[1], r[2], {"Head": 1}, dy=-(r[3] * ECH)) for r in t]
        tube(p, "crane", rings, n=10, cap0=True, cap1=True, kind="visage", var=v, femme=F, z_yeux=hz(1.722), z_sourcils=hz(1.744), z_bouche=hz(1.650), z_nez=hz(1.690), z_menton=hz(1.605), z_front=hz(1.775), ecart_yeux=0.034 * ECH, echelle=ECH, densite=DENSITE_VISAGE)
        # nez : coin pointe, plus ou moins long selon le visage
        zn = hz(1.700); yf = HY - (0.100 * ECH) + 0.004
        ln = (0.030, 0.036, 0.026)[v - 1] * ECH
        tube(p, "nez", [Anneau((0, yf + 0.010, zn + 0.004), 0.017 * ECH, 0.020 * ECH, {"Head": 1}, t=(0, -1, -0.45)),
                        Anneau((0, yf - ln * 0.85, zn - 0.014), 0.008 * ECH, 0.007 * ECH, {"Head": 1}, t=(0, -1, -0.45))], n=4, cap1=True, kind="peau", densite=96.0)
        # oreilles
        for s in (1, -1):
            sf = "_l" if s > 0 else "_r"
            rx = interp(t, hz(1.715))[0]
            tube(p, "oreille" + sf, [Anneau((s * (rx - 0.004), HY + 0.004, hz(1.708)), 0.027 * ECH, 0.016 * ECH, {"Head": 1}, t=(s, 0, 0), e1=(0, 0, 1)),
                                     Anneau((s * (rx + 0.016), HY + 0.012, hz(1.712)), 0.020 * ECH, 0.010 * ECH, {"Head": 1}, t=(s, 0, 0), e1=(0, 0, 1))], n=4, cap1=True, kind="peau", densite=64.0)

def pieces_cheveux():
    t = table_tete(1)
    LIGNE = hz(1.775)                    # ligne des cheveux sur le front
    def lift(zbas, plus=0.0):
        # sommets de devant des anneaux bas remontes a la ligne des cheveux (les faces s'aplatissent, bord net sur le front)
        def f(th):
            s = math.sin(th); m = max(0.0, min(1.0, (s - 0.45) / 0.45))
            return max(0.0, (LIGNE + plus - zbas)) * m
        return f
    def coupe(nom, zs, off, rayons_plus, w_bas, n=10, rot=0.0, extra=None):
        p = nouvelle(nom, double=False)
        rings = []
        for i, z in enumerate(zs):
            rx, ry, av = interp(t, min(z, hz(1.797)) if z > hz(1.797) else max(z, hz(1.628)))
            plus = rayons_plus[i]
            w = {"Head": 1} if z > hz(1.60) else w_bas(z)
            rings.append(Anneau((0, HY + (0.0 if z > hz(1.62) else 0.012), z), rx + off + plus, ry + off + plus, w, dy=-(av * ECH) + (0.0 if z > hz(1.62) else 0.0), vz=lift(z, 0.0) if z < LIGNE else None))
        return p, rings
    # 1 : coupe courte (calotte jusqu'aux oreilles)
    zs = [hz(1.640), hz(1.690), hz(1.725), hz(1.755), hz(1.785), hz(1.815)]
    p, rg = coupe("cheveux_1", zs, 0.012, [0.004, 0.003, 0.003, 0.003, 0.002, -0.008], lambda z: {"Head": 1})
    tube(p, "coupe", rg, n=10, cap1=True, kind="cheveux")
    # 2 : mi-longs, tombant sur la nuque et les epaules (os du cou en bas)
    zs = [hz(1.540), hz(1.585), hz(1.640), hz(1.690), hz(1.730), hz(1.765), hz(1.795), hz(1.818)]
    pl = [-0.020, 0.005, 0.016, 0.014, 0.006, 0.004, 0.002, -0.012]
    def wb(z): return {"neck_01": 0.5, "spine_03": 0.5} if z < hz(1.56) else ({"Head": 0.5, "neck_01": 0.5} if z < hz(1.60) else {"Head": 1})
    p, rg = coupe("cheveux_2", zs, 0.012, pl, wb)
    tube(p, "coupe", rg, n=10, cap1=True, kind="cheveux")
    # 3 : calotte + chignon haut + tresse dans le dos
    zs = [hz(1.640), hz(1.700), hz(1.735), hz(1.765), hz(1.795), hz(1.818)]
    p, rg = coupe("cheveux_3", zs, 0.012, [0.004, 0.004, 0.004, 0.003, 0.0, -0.01], lambda z: {"Head": 1})
    tube(p, "coupe", rg, n=10, cap1=True, kind="cheveux")
    tube(p, "chignon", [Anneau((0, HY + 0.075, hz(1.790)), 0.040 * ECH, 0.036 * ECH, {"Head": 1}, t=(0, 0.3, 1)),
                        Anneau((0, HY + 0.085, hz(1.830)), 0.046 * ECH, 0.040 * ECH, {"Head": 1}, t=(0, 0.3, 1)),
                        Anneau((0, HY + 0.080, hz(1.868)), 0.026 * ECH, 0.022 * ECH, {"Head": 1}, t=(0, 0.3, 1))], n=6, cap0=True, cap1=True, kind="cheveux")
    tube(p, "tresse", [Anneau((0, HY + 0.115, hz(1.700)), 0.026, 0.026, {"Head": 1}, t=(0, 0.4, -1)),
                       Anneau((0, HY + 0.140, hz(1.610)), 0.026, 0.026, {"Head": 0.5, "neck_01": 0.5}, t=(0, 0.3, -1)),
                       Anneau((0, HY + 0.160, hz(1.520)), 0.020, 0.020, {"neck_01": 0.5, "spine_03": 0.5}, t=(0, 0.2, -1)),
                       Anneau((0, HY + 0.165, hz(1.450)), 0.012, 0.012, {"spine_03": 1}, t=(0, 0.1, -1))], n=6, cap1=True, kind="cheveux", tresse=1)

def pieces_barbes():
    if F:
        return
    t = table_tete(1)
    def anneau_b(z, off, w=None):
        return anneau_tete(t, z, off, w)
    # 1 : barbe courte (joues, menton), fente de la bouche peinte
    p = nouvelle("barbe_1", double=True)
    rg = [anneau_b(hz(1.700), 0.010), anneau_b(hz(1.668), 0.012), anneau_b(hz(1.630), 0.014), anneau_b(hz(1.598), 0.010)]
    tube(p, "barbe", rg, n=8, cap1=False, kind="barbe", arc=(70, 290), hint=(1, 0, 0), z_bouche=hz(1.650), echelle=ECH, densite=96.0)
    # 2 : barbe tressee : meme couverture + tresse tombant sur la poitrine
    p = nouvelle("barbe_2", double=True)
    rg = [anneau_b(hz(1.700), 0.010), anneau_b(hz(1.668), 0.014), anneau_b(hz(1.622), 0.018), anneau_b(hz(1.585), 0.018, {"Head": 0.5, "neck_01": 0.5})]
    tube(p, "barbe", rg, n=8, kind="barbe", arc=(70, 290), hint=(1, 0, 0), z_bouche=hz(1.650), echelle=ECH, densite=96.0)
    yf = HY - 0.10 * ECH
    tube(p, "tresse", [Anneau((0, yf + 0.018, hz(1.600)), 0.028, 0.022, {"Head": 0.5, "neck_01": 0.5}, t=(0, -0.2, -1)),
                       Anneau((0, yf + 0.008, hz(1.545)), 0.026, 0.020, {"neck_01": 1}, t=(0, -0.1, -1)),
                       Anneau((0, yf + 0.0, hz(1.485)), 0.017, 0.014, {"neck_01": 0.5, "spine_03": 0.5}, t=(0, 0, -1))], n=6, cap1=True, kind="barbe", tresse=1)

pieces_tetes(); pieces_cheveux(); pieces_barbes()

# ------------------------------------------------------------------ accessoires (vetements en COUCHES : chaque couche epouse le corps a une marge de 1-4 cm)
def th_de(k, n, arc):
    return math.radians(arc[0] + (arc[1] - arc[0]) * k / n) - math.pi / 2

def lateral(k, n, arc):
    """cos de l'angle : > 0 cote gauche (+x), < 0 cote droit."""
    return math.cos(th_de(k, n, arc))

def mix2(a, b, t):
    """Fusion de deux dictionnaires de poids (au plus 2 os gardes)."""
    w = {}
    for k, v in a.items(): w[k] = w.get(k, 0) + v * (1 - t)
    for k, v in b.items(): w[k] = w.get(k, 0) + v * t
    return dict(sorted(w.items(), key=lambda kv: -kv[1])[:2])

def pieces_accessoires():
    ZH = BONE["pelvis"][0].z; Y0 = BONE["pelvis"][0].y
    # 1. gilet de laine : torse + 2,2 cm, epaules, col ouvert
    p = nouvelle("gilet", double=False)
    us = [-0.02, 0.12, 0.36, 0.58, 0.80, 0.95, 1.02]
    rg = [anneau_torse(u, 0.022 if u < 0.9 else 0.020) for u in us]
    tube(p, "gilet", rg, n=8, kind="sur", debut="ourlet", fin="col")
    # 2. tablier de forgeron : panneau avant (arc ±52 degres) du torse aux genoux, ressort sur pan_av_1
    p = nouvelle("tablier", double=True)
    rg = [anneau_torse(0.62, 0.030), anneau_torse(0.30, 0.034), anneau_torse(0.10, 0.040)]
    for r in rg: r.p = {"spine_02": 1} if r is rg[0] else ({"spine_01": 1} if r is rg[1] else {"pelvis": 1})
    zk = BONE["thigh_l"][1].z + 0.05
    bas = Anneau((0, Y0 - 0.02, zk), 0.205, 0.165, {"pan_av_1": 1})
    mid = Anneau((0, Y0 - 0.02, ZH - 0.05), 0.20, 0.158, {"pelvis": 0.5, "pan_av_1": 0.5})
    # le haut suit la poitrine (largeur de torse), le bas s'evase vers le genou
    tube(p, "tablier", rg + [mid, bas], n=6, kind="sur", debut="aucun", fin="ourlet", arc=(130, 230))
    # 3. robe : deux panneaux lateraux (jambes) + panneaux avant / arriere internes sur ressort ; l'ourlet reste au mollet
    p = nouvelle("robe", double=True)
    zc = BONE["calf_l"][0].z * 0.62                        # ourlet : sous le genou, bien au-dessus de la cheville
    zg = BONE["thigh_l"][1].z
    def niveaux(marge):
        # (z, rx, ry) du bord de la robe : evasement progressif sur les cuisses puis le mollet
        return [(ZH + 0.12, 0.185 + marge, 0.125 + marge), (ZH + 0.00, 0.235 + marge, 0.150 + marge), (zg + 0.14, 0.255 + marge, 0.160 + marge),
                (zg - 0.10, 0.262 + marge, 0.165 + marge), (zc, 0.268 + marge, 0.170 + marge)]
    for s in (1, -1):
        sf = "_l" if s > 0 else "_r"
        th, ca = "thigh" + sf, "calf" + sf
        ws = [{"pelvis": 1}, {"pelvis": 0.5, th: 0.5}, {th: 1}, {th: 0.7, ca: 0.3}, {th: 0.4, ca: 0.6}]
        arc = (8, 172) if s > 0 else (188, 352)
        rg = []
        for (z, rx, ry), w in zip(niveaux(0.012 if s < 0 else 0.0), ws):
            rg.append(Anneau((0, Y0 - 0.005, z), rx, ry, w))
        tube(p, "cote" + sf, rg, n=6, kind="sur", debut="aucun", fin="ourlet", arc=arc)
    # v2 : les pans avant / arriere sont des COQUES COURBES (arc +-62 degres, pas un ruban plat) : vus de profil ils gardent une epaisseur visible au lieu d'un
    # trait fin ; ils s'arretent sous le genou (le tissu qui pend entre les jambes ne descend plus jusqu'a l'ourlet des cotes) et restent sous les cotes (marge -0,02).
    zk2 = BONE["thigh_l"][1].z - 0.06
    def niveaux_pan(marge):
        return [(ZH + 0.12, 0.185 + marge, 0.125 + marge), (ZH + 0.00, 0.235 + marge, 0.150 + marge), (zg + 0.14, 0.255 + marge, 0.160 + marge),
                (zk2, 0.262 + marge, 0.165 + marge)]
    def poids_pan(arc):
        # v2 : panneaux ECRASES SUR LES JAMBES (plus de ressort, plus de plaque qui pend) : hanche = bassin, genou = cuisse du cote ; l'axe central partage les deux cuisses
        # (la robe s'ouvre entre les jambes a la foulee, comme une fente de robe, au lieu de laisser pendre une plaque vue par la tranche)
        def cote_de(k):
            l = lateral(k, 6, arc)
            return "thigh_l" if l > 0.15 else ("thigh_r" if l < -0.15 else None)
        return [lambda k: {"pelvis": 1}, lambda k: {"pelvis": 1},
                lambda k: ({"pelvis": 0.4, cote_de(k): 0.6} if cote_de(k) else {"pelvis": 1}),
                lambda k: ({cote_de(k): 1} if cote_de(k) else {"thigh_l": 0.5, "thigh_r": 0.5})]
    for nom, arc in (("avant", (118, 242)), ("arriere", (-62, 62))):
        rg = []
        for (z, rx, ry), w in zip(niveaux_pan(-0.020), poids_pan(arc)):
            rg.append(Anneau((0, Y0 - 0.005, z), rx, ry, w))
        tube(p, nom, rg, n=6, kind="sur", debut="aucun", fin="ourlet", arc=arc)
    # 4. capes : collet de fourrure + panneau dorsal sur la chaine cape_1 / cape_2
    for nom, bas_u, zbas, longue in (("cape_courte", 0.30, None, False), ("cape_longue", 0.12, 0.45, True)):
        p = nouvelle(nom, double=True)
        # collet de fourrure : deux anneaux autour des epaules (cartes decoupees au bord bas)
        c0 = anneau_torse(1.00, 0.050); c0.r1 += 0.02
        c1 = anneau_torse(0.86, 0.075)
        c0.p = {"spine_03": 1}; c1.p = {"spine_03": 1}
        tube(p, "collet", [c0, c1], n=8, kind="fourrure", debut="aucun", fin="aucun")
        us = [0.96, 0.70, bas_u] if not longue else [0.96, 0.62, 0.26, bas_u]
        rg = []
        for i, u in enumerate(us):
            r = anneau_torse(u, 0.040 + 0.012 * i)
            if longue and i >= 2:
                r.r1 += 0.02 * (i - 1)
            r.p = [{"spine_03": 1}, {"spine_03": 0.5, "cape_1": 0.5}, {"cape_1": 0.5, "cape_2": 0.5}, {"cape_2": 1}][min(i, 3)] if longue else [{"spine_03": 1}, {"cape_1": 1}, {"cape_2": 1}][i]
            rg.append(r)
        if longue:
            # prolonge jusqu'a mi-mollet (os cape_2) : meme ellipse, evasement leger
            zb = zbas
            c = rg[-1]
            rg.append(Anneau((c.c.x, c.c.y + 0.015, zb), c.r1 + 0.035, c.r2 + 0.01, {"cape_2": 1}, dy=c.dy))
        tube(p, "panneau", rg, n=6, kind="sur", debut="aucun", fin="ourlet", arc=(-72, 72))
    # 5. capuche : coiffe a +3 cm, ouverture du visage (devant remonte), drape sur la nuque et les epaules
    p = nouvelle("capuche", double=True)
    t = table_tete(1)
    LIGNE = hz(1.752)
    def lift(zbas):
        def f(th):
            s = math.sin(th); m = max(0.0, min(1.0, (s - 0.25) / 0.5))
            return max(0.0, (LIGNE - zbas)) * m
        return f
    zs = [hz(1.470), hz(1.545), hz(1.600), hz(1.655), hz(1.705), hz(1.750), hz(1.790), hz(1.830), hz(1.865)]
    pl = [0.040, 0.050, 0.044, 0.036, 0.034, 0.032, 0.032, 0.026, -0.010]
    rg = []
    for z, pp in zip(zs, pl):
        rx, ry, av = interp(t, min(max(z, hz(1.628)), hz(1.797)))
        w = {"capuche_1": 0.5, "neck_01": 0.5} if z < hz(1.52) else ({"Head": 0.5, "capuche_1": 0.5} if z < hz(1.58) else {"Head": 1})
        rg.append(Anneau((0, HY + (0.018 if z < hz(1.6) else 0.0), z), rx + pp, ry + pp, w, dy=-(av * ECH), vz=lift(z) if z < LIGNE else None))
    tube(p, "capuche", rg, n=10, cap1=True, kind="sur", debut="ourlet", fin="aucun")
    # 6. epaulieres (plaques de fer sur le haut du bras) et pteruges (lanieres de cuir)
    p = nouvelle("epaulieres", double=False)
    for s in (1, -1):
        sf = "_l" if s > 0 else "_r"; ua = "upperarm" + sf; ex = Vector((0, 0, 1))
        rg = [Anneau(P(ua, -0.22), 0.050, 0.050, {"clavicle" + sf: 1}, e1=ex), Anneau(P(ua, -0.05), 0.108, 0.104, {"clavicle" + sf: 0.5, ua: 0.5}, e1=ex),
              Anneau(P(ua, 0.20), 0.100, 0.098, {ua: 1}, e1=ex), Anneau(P(ua, 0.42), 0.088, 0.086, {ua: 1}, e1=ex)]
        if F:
            for r in rg: r.r1 *= 0.88; r.r2 *= 0.88
        tube(p, "plaque" + sf, rg, n=6, cap0=True, kind="fer", hint=(0, 0, 1))
    p = nouvelle("pteruges", double=True)
    zb = ZH - 0.20
    def pw(arc, n):
        def f(k):
            l = lateral(k, n, arc)
            return {"pelvis": 1}
        return f
    rg = [Anneau((0, Y0, ZH + 0.08), 0.200, 0.135, {"pelvis": 1}),
          Anneau((0, Y0, ZH - 0.03), 0.245, 0.165, lambda k: ({"pelvis": 0.6, "thigh_l": 0.4} if lateral(k, 8, None if False else (0, 360)) > 0.3 else ({"pelvis": 0.6, "thigh_r": 0.4} if lateral(k, 8, (0, 360)) < -0.3 else {"pelvis": 1}))),
          Anneau((0, Y0, zb), 0.262, 0.178, lambda k: ({"pelvis": 0.3, "thigh_l": 0.7} if lateral(k, 8, (0, 360)) > 0.3 else ({"pelvis": 0.3, "thigh_r": 0.7} if lateral(k, 8, (0, 360)) < -0.3 else {"pelvis": 0.7, "thigh_l": 0.15 , "thigh_r": 0.15})))]
    # (le dernier jeu de poids est borne a 2 os dans creer_objets : le centre reste au bassin)
    rg[2].p = lambda k: ({"pelvis": 0.3, "thigh_l": 0.7} if lateral(k, 8, (0, 360)) > 0.3 else ({"pelvis": 0.3, "thigh_r": 0.7} if lateral(k, 8, (0, 360)) < -0.3 else {"pelvis": 1}))
    tube(p, "lanieres", rg, n=8, kind="cuir", debut="aucun", fin="ourlet")
    # 7. sacoche (hanche gauche) et carquois (dos, incline)
    p = nouvelle("sacoche", double=False)
    cx = 0.215 if not F else 0.195
    tube(p, "bourse", [Anneau((cx, Y0 + 0.01, ZH - 0.02), 0.020, 0.050, {"pelvis": 1}, t=(0, 0, 1), e1=(1, 0, 0)),
                       Anneau((cx + 0.012, Y0 + 0.01, ZH - 0.075), 0.034, 0.058, {"pelvis": 1}, t=(0, 0, 1), e1=(1, 0, 0)),
                       Anneau((cx + 0.004, Y0 + 0.01, ZH - 0.125), 0.020, 0.040, {"pelvis": 1}, t=(0, 0, 1), e1=(1, 0, 0))], n=6, cap0=True, cap1=True, kind="cuir")
    p = nouvelle("carquois", double=False)
    yb = Y0 + 0.14
    tube(p, "fut", [Anneau((0.10, yb, ZH + 0.02), 0.052, 0.050, {"spine_01": 1}, t=(-0.25, -0.05, 1)),
                    Anneau((0.04, yb + 0.012, ZH + 0.30), 0.056, 0.054, {"spine_02": 1}, t=(-0.25, -0.05, 1)),
                    Anneau((-0.02, yb + 0.02, ZH + 0.58), 0.060, 0.058, {"spine_03": 1}, t=(-0.25, -0.05, 1))], n=6, cap0=True, cap1=True, kind="cuir")

pieces_accessoires()

# ------------------------------------------------------------------ fin : atlas, objets, export
def terminer():
    rects, hauteur = disposer(PIECES)
    uv_pixels(PIECES, rects)
    # controle : chaque coin d'UV tombe dans le rectangle de sa partie (sinon la texture lue appartient a une autre partie)
    mauvais = 0
    for p in PIECES:
        for q, uv, part in p.f:
            x, y, w, h = rects[p.nom + "." + part]
            for (u, v) in uv:
                px = u * ATLAS; py = (1.0 - v) * ATLAS
                if px < x - 0.01 or px > x + w + 0.01 or py < y - 0.01 or py > y + h + 0.01:
                    mauvais += 1
                    if mauvais < 6: print("UV HORS RECT", p.nom, part, round(px, 1), round(py, 1), rects[p.nom + "." + part])
    print("UV hors rectangle :", mauvais)
    # etancheite : aretes de bord (1 seule face) par partie ; les panneaux de tissu OUVERTS (arc) et les tubes sans calotte sont attendus
    bord = {}
    for p in PIECES:
        ar = {}
        for q, uv, part in p.f:
            for i in range(len(q)):
                a, b = q[i], q[(i + 1) % len(q)]
                k = (min(a, b), max(a, b), part)
                ar[k] = ar.get(k, 0) + 1
        for (a, b, part), n_ in ar.items():
            if n_ == 1:
                bord[p.nom + "." + part] = bord.get(p.nom + "." + part, 0) + 1
    print("ARETES DE BORD (parties ouvertes) :", json.dumps(bord))
    objs = creer_objets(PIECES, arm, RIG18 + SECONDAIRES)
    tris = {p.nom: triangles(p) for p in PIECES}
    info = {"densite": DENSITE, "atlas": ATLAS, "sexe": SEXE, "hauteur_utilisee": hauteur, "rects": {}, "triangles": tris}
    for p in PIECES:
        for nom, d in p.parts.items():
            info["rects"][p.nom + "." + nom] = dict(d, rect=rects[p.nom + "." + nom], piece=p.nom, double=p.double)
    json.dump(info, open(JSON_, "w"), indent=1)
    print("TRIANGLES", tris, "corps+bagues =", tris["corps"] + tris["bagues"], "atlas utilise : %d / %d lignes" % (hauteur, ATLAS))
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs + [arm]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=SORTIE, export_format='GLB', use_selection=True, export_skins=True, export_animations=False,
                              export_apply=False, export_yup=True)
    print("EXPORT", SORTIE)
    return objs

objs = terminer()

# ------------------------------------------------------------------ apercu (rendu Workbench, T-pose)
def apercu(dossier):
    os.makedirs(dossier, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'OBJECT'
    sc.render.resolution_x = 900; sc.render.resolution_y = 900
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.55, 0.3, 0.55)
    montrer = next((a.split("=", 1)[1] for a in args if a.startswith("--montrer=")), "corps,bagues,tete_1,cheveux_1,barbe_1").split(",")
    zoom = next((a.split("=", 1)[1] for a in args if a.startswith("--zoom=")), "")
    for o in objs:
        o.hide_render = o.name not in montrer
    cols = {"corps": (0.7, 0.5, 0.3, 1), "bagues": (0.3, 0.2, 0.1, 1)}
    for i, o in enumerate(objs):
        o.color = cols.get(o.name, [(0.6, 0.6, 0.7, 1), (0.5, 0.7, 0.5, 1), (0.8, 0.5, 0.5, 1), (0.7, 0.7, 0.4, 1)][i % 4])
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 0.6 if zoom == "tete" else 2.4
    zc = (BONE["Head"][0].z + 0.06) if zoom == "tete" else 0.95
    for nom, loc, rot in [("face", (0, -4, zc), (90, 0, 0)), ("profil", (4, 0, zc), (90, 0, 90)), ("dos", (0, 4, zc), (90, 0, 180))]:
        cam.location = loc; cam.rotation_euler = [math.radians(a) for a in rot]
        sc.render.filepath = os.path.join(dossier, "%s_%s%s.png" % (SEXE, zoom, nom))
        bpy.ops.render.render(write_still=True)
if APERCU:
    apercu(APERCU)
