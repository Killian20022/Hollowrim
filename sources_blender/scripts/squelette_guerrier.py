# Squelette nordique guerrier (ennemi « squelette »), pieces rigides 1 os / sommet, RIG18 + 4 os feuilles du ragdoll.
#   blender.exe -b --python squelette_guerrier.py
# Ecrit : assets/modeles/squelettes/squelette_guerrier.glb (maillages « squelette », « epee », « arc » ; surfaces 0 = os/fer/bois, 1 = orbites)
#         sources_blender/squelette_guerrier_atlas.png (atlas 256x256, peint ici : 1 ilot par face a DENSITE_PERSO texels/m)
# Le squelette est celui de homme_vetu_lot1.glb (memes os, meme pose de repos) : les animations et le ragdoll existants s'appliquent tels quels.
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(BASE, "sources_blender", "homme_vetu_lot1.glb")
OUT_GLB = os.path.join(BASE, "assets", "modeles", "squelettes", "squelette_guerrier.glb")
OUT_PNG = os.path.join(BASE, "sources_blender", "squelette_guerrier_atlas.png")
RIG18 = os.path.join(BASE, "sources_blender", "rig18.txt")
DENSITE_PERSO = 32.0          # texels / m (meme constante que scripts/squelette_guerrier.gd)
ATLAS = 256
GUT = 1                       # marge autour de chaque ilot (texels)
MINI = 2                      # taille mini d'un ilot (texels)

RIG_DEFAUT = ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
              "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"]
FEUILLES = ["ball_l", "ball_r", "middle_01_l", "middle_01_r"]     # le ragdoll en a besoin (axe des pieds, longueur des mains)

def V(x, y, z):
    return Vector((x, y, z))

# ------------------------------------------------------------------ 1. squelette
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for o in list(bpy.data.objects):
    if o.type != 'ARMATURE':
        bpy.data.objects.remove(o)
garde = [l.strip() for l in open(RIG18)] if os.path.exists(RIG18) else RIG_DEFAUT
garde = [n for n in garde if n] + [n for n in FEUILLES if n not in garde]
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
for eb in list(arm.data.edit_bones):
    if eb.name not in garde:
        arm.data.edit_bones.remove(eb)
bpy.ops.object.mode_set(mode='OBJECT')
print("OS gardes :", len(arm.data.bones), [b.name for b in arm.data.bones])

# ------------------------------------------------------------------ 2. constructeur de maille
class Maille:
    def __init__(s):
        s.v = []; s.bone = []; s.f = []
    def pt(s, p, bone):
        s.v.append(Vector(p)); s.bone.append(bone); return len(s.v) - 1
    def face(s, ids, cls, mat=0, part="", **kw):
        d = dict(ids=list(ids), cls=cls, mat=mat, part=part); d.update(kw); s.f.append(d)

def loft(M, bone, rings, cls, part, caps=True, apex=None, pits=None, **kw):
    """Anneaux de n sommets -> bandes de quads ; bouchons (n-gones) ; apex = pointe fermant le dernier anneau ;
    pits = {(bande, arete): (profondeur_vecteur, matiere, classe)} : le quad devient une pyramide creuse (orbite, narine)."""
    ids = [[M.pt(p, bone) for p in r] for r in rings]
    n = len(rings[0])
    for k in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            q = [ids[k][i], ids[k][j], ids[k + 1][j], ids[k + 1][i]]
            if pits and (k, i) in pits:
                prof, mat, cl = pits[(k, i)]
                c = sum((M.v[x] for x in q), Vector()) / 4.0 + prof
                a = M.pt(c, bone)
                for t in range(4):
                    M.face([q[t], q[(t + 1) % 4], a], cl, mat=mat, part=part, **kw)
            else:
                M.face(q, cls, part=part, **kw)
    if apex is not None:
        a = M.pt(apex, bone)
        for i in range(n):
            M.face([ids[-1][i], ids[-1][(i + 1) % n], a], cls, part=part, **kw)
    elif caps:
        M.face(ids[-1], cls, part=part, **kw)
    if caps:
        M.face(ids[0][::-1], cls, part=part, **kw)
    return ids

def ring_rect(c, s, f, hs, hf):
    return [c + s * hs + f * hf, c + s * hs - f * hf, c - s * hs - f * hf, c - s * hs + f * hf]

EPAIS = 1.22     # os longs plus epais (lisibles a 20 m) ; les epiphyses (extremites) en profitent aussi

def os_long(M, bone, a, b, stations, side, front, part, cls="os"):
    ax = b - a
    rings = [ring_rect(a + ax * t, side, front, hs * EPAIS, hf * EPAIS) for t, hs, hf in stations]
    return loft(M, bone, rings, cls, part)

def mir(p):
    return V(-p.x, p.y, p.z)

def plan_ring(plan, z, s=1.0, c=(0.0, 0.0)):
    return [V(c[0] + (x - c[0]) * s, c[1] + (y - c[1]) * s, z) for x, y in plan]

# ------------------------------------------------------------------ 3. le squelette
corps = Maille()
M = corps
# --- crane (os Head)
P_CRANE = [(-0.050, -0.066), (0.050, -0.066), (0.078, 0.020), (0.052, 0.115), (-0.052, 0.115), (-0.078, 0.020)]
loft(M, "Head", [plan_ring(P_CRANE, 1.672, 0.78, (0, 0.025)), plan_ring(P_CRANE, 1.732, 1.0, (0, 0.025)), plan_ring(P_CRANE, 1.795, 0.80, (0, 0.025))], "os", "crane")
# face : 3 bandes, 4 colonnes en facade ; orbites (pyramides creuses lumineuses) et narine (pyramide sombre)
ZF = [1.748, 1.722, 1.682, 1.622]
YF = [-0.078, -0.076, -0.082, -0.088]
CX = [-0.050, -0.018, 0.018, 0.050]
rings_face = [[V(CX[0], YF[k], ZF[k]), V(CX[1], YF[k], ZF[k]), V(CX[2], YF[k], ZF[k]), V(CX[3], YF[k], ZF[k]), V(0.046, 0.0, ZF[k]), V(-0.046, 0.0, ZF[k])] for k in range(4)]
prof = V(0, 0.030, 0)
loft(M, "Head", rings_face, "os", "face", pits={(1, 0): (prof, 1, "orbite"), (1, 2): (prof, 1, "orbite"), (2, 1): (V(0, 0.026, 0), 0, "noir")})
# machoire
P_MAC = [(-0.040, -0.078), (0.040, -0.078), (0.056, -0.010), (0.040, 0.050), (-0.040, 0.050), (-0.056, -0.010)]
loft(M, "Head", [plan_ring(P_MAC, 1.630, 1.0, (0, -0.005)), [p + V(0, 0.012, 0) for p in plan_ring(P_MAC, 1.576, 0.62, (0, -0.005))]], "os", "machoire")
# casque conique a nasal (fer rouille)
P8 = []
for k in range(8):
    a = math.radians(22.5 + 45 * k)
    P8.append((0.092 * math.cos(a) / math.cos(math.radians(22.5)), 0.115 * math.sin(a) / math.cos(math.radians(22.5)) + 0.025))
loft(M, "Head", [[V(x, y, 1.745) for x, y in P8], [V(0.95 * (x), 0.025 + 0.93 * (y - 0.025), 1.815) for x, y in P8]], "fer", "casque", apex=V(0, 0.028, 1.892))
os_long(M, "Head", V(0, -0.0915, 1.752), V(0, -0.0875, 1.674), [(0.0, 0.0075, 0.004), (1.0, 0.0115, 0.004)], V(1, 0, 0), V(0, 1, 0), "nasal", "fer")
# cou
os_long(M, "neck_01", V(0, 0.034, 1.495), V(0, 0.034, 1.695), [(0, 0.022, 0.024), (1, 0.019, 0.021)], V(1, 0, 0), V(0, 1, 0), "cou")
# colonne lombaire
os_long(M, "spine_01", V(0, 0.032, 1.062), V(0, 0.032, 1.250), [(0, 0.030, 0.032), (1, 0.027, 0.030)], V(1, 0, 0), V(0, 1, 0), "lombes")
# cage thoracique : bloc prismatique a 6 pans, fentes intercostales peintes
P_CAGE = [(-0.055, -0.105), (0.055, -0.105), (0.150, -0.015), (0.080, 0.070), (-0.080, 0.070), (-0.150, -0.015)]
loft(M, "spine_03", [plan_ring(P_CAGE, 1.205, 0.82, (0, -0.015)), plan_ring(P_CAGE, 1.360, 1.0, (0, -0.015)), plan_ring(P_CAGE, 1.500, 0.56, (0, -0.012))], "cage", "cage")
loft(M, "spine_03", [[V(-0.018, -0.118, 1.320), V(0.018, -0.118, 1.320), V(0.016, -0.096, 1.320), V(-0.016, -0.096, 1.320)],
                     [V(-0.014, -0.092, 1.475), V(0.014, -0.092, 1.475), V(0.012, -0.070, 1.475), V(-0.012, -0.070, 1.475)]], "os", "sternum")
# clavicules
for cote, bone, sg in (("l", "clavicle_l", 1), ("r", "clavicle_r", -1)):
    a = V(sg * 0.030, -0.045, 1.494); b = V(sg * 0.218, 0.060, 1.484)
    os_long(M, bone, a, b, [(0, 0.015, 0.016), (1, 0.021, 0.019)], V(0, 0, 1), (b - a).cross(V(0, 0, 1)).normalized(), "clavicule_" + cote)
# bassin : sacrum/pubis + deux ailes iliaques
loft(M, "pelvis", [[V(-0.050, -0.055, 0.935), V(0.050, -0.055, 0.935), V(0.050, 0.085, 0.935), V(-0.050, 0.085, 0.935)],
                   [V(-0.050, -0.045, 1.012), V(0.050, -0.045, 1.012), V(0.050, 0.085, 1.012), V(-0.050, 0.085, 1.012)]], "os", "sacrum")
for sg, nom in ((1, "l"), (-1, "r")):
    loft(M, "pelvis", [[V(sg * 0.040, -0.058, 0.952), V(sg * 0.150, -0.050, 0.952), V(sg * 0.150, 0.078, 0.952), V(sg * 0.040, 0.078, 0.952)],
                       [V(sg * 0.065, -0.050, 1.085), V(sg * 0.205, -0.040, 1.085), V(sg * 0.205, 0.066, 1.085), V(sg * 0.065, 0.066, 1.085)]], "os", "ilion_" + nom)
# os longs, symetriques
for sg, nom in ((1, "l"), (-1, "r")):
    # femur / tibia
    os_long(M, "thigh_" + nom, V(sg * 0.114, 0.036, 0.988), V(sg * 0.114, 0.036, 0.520), [(0, 0.031, 0.033), (0.28, 0.018, 0.020), (0.72, 0.019, 0.021), (1, 0.034, 0.036)], V(1, 0, 0), V(0, 1, 0), "femur_" + nom)
    a = V(sg * 0.114, 0.036, 0.568); b = V(sg * 0.114, 0.0905, 0.070)
    os_long(M, "calf_" + nom, a, b, [(0, 0.034, 0.033), (0.5, 0.015, 0.017), (1, 0.026, 0.026)], V(1, 0, 0), (b - a).cross(V(1, 0, 0)).normalized(), "tibia_" + nom)
    # humerus / avant-bras / main
    os_long(M, "upperarm_" + nom, V(sg * 0.190, 0.065, 1.456), V(sg * 0.484, 0.073, 1.456), [(0, 0.031, 0.031), (0.28, 0.015, 0.016), (0.72, 0.016, 0.017), (1, 0.031, 0.030)], V(0, 0, 1), V(0, 1, 0), "humerus_" + nom)
    os_long(M, "lowerarm_" + nom, V(sg * 0.445, 0.073, 1.456), V(sg * 0.724, 0.065, 1.456), [(0, 0.030, 0.029), (0.5, 0.014, 0.016), (1, 0.022, 0.022)], V(0, 0, 1), V(0, 1, 0), "avantbras_" + nom)
    loft(M, "hand_" + nom, [[V(sg * 0.698, 0.038, 1.435), V(sg * 0.698, 0.094, 1.435), V(sg * 0.698, 0.094, 1.476), V(sg * 0.698, 0.038, 1.476)],
                            [V(sg * 0.842, 0.051, 1.444), V(sg * 0.842, 0.082, 1.444), V(sg * 0.842, 0.082, 1.467), V(sg * 0.842, 0.051, 1.467)]], "os", "main_" + nom)
    # pied
    x = sg * 0.114
    loft(M, "foot_" + nom, [[V(x + 0.032, 0.125, 0.0), V(x - 0.032, 0.125, 0.0), V(x - 0.030, 0.125, 0.096), V(x + 0.030, 0.125, 0.096)],
                            [V(x + 0.046, -0.215, 0.0), V(x - 0.046, -0.215, 0.0), V(x - 0.040, -0.215, 0.034), V(x + 0.040, -0.215, 0.034)]], "os", "pied_" + nom)

# tete : un peu plus grosse (lisibilite a distance), echelle autour de la nuque
CTR = V(0.0, 0.03, 1.75)
for i, b in enumerate(corps.bone):
    if b == "Head":
        corps.v[i] = CTR + (corps.v[i] - CTR) * 1.12

# bouclier rond ebreche, fixe a l'avant-bras gauche (face vers l'avant = -Y)
SC = V(0.600, 0.065 - 0.155, 1.456)
R = 0.225
bor = []
anneaux = []
for yy in (-0.014, 0.014):
    ring = []
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        rr = R / math.cos(math.radians(22.5))
        if k == 5:
            rr *= 0.80                      # ebrechure
        ring.append(V(SC.x + rr * math.cos(a), SC.y + yy, SC.z + rr * math.sin(a)))
    anneaux.append(ring)
loft(M, "lowerarm_l", anneaux, "bouclier", "bouclier", centre=SC, rayon=R)
loft(M, "lowerarm_l", [[V(SC.x + 0.06 * sx, SC.y - 0.014, SC.z + 0.06 * sz) for sx, sz in ((1, 1), (1, -1), (-1, -1), (-1, 1))],
                       [V(SC.x + 0.034 * sx, SC.y - 0.052, SC.z + 0.034 * sz) for sx, sz in ((1, 1), (1, -1), (-1, -1), (-1, 1))]], "fer", "umbo", centre=SC)

# --- armes (repere de la prise de l'epee du joueur : scripts/draugr.gd `prise`, cf. outils/analyse_prise.gd)
O = V(-0.849425, 0.063159, 1.447565)
XB = V(0.038334, 0.005288, -0.999251)
YB = V(-0.24307, -0.969901, -0.014458)
ZB = V(-0.969252, 0.243442, -0.035895)
def S(lx, ly, lz):
    return O + XB * lx + YB * ly + ZB * lz

epee = Maille()
loft(epee, "hand_r", [[S(sx * 0.020, -0.045, sz * 0.020) for sx, sz in ((1, 1), (1, -1), (-1, -1), (-1, 1))],
                      [S(sx * 0.012, 0.100, sz * 0.012) for sx, sz in ((1, 1), (1, -1), (-1, -1), (-1, 1))]], "cuir", "poignee")
loft(epee, "hand_r", [[S(sx * 0.095, 0.098, sz * 0.016) for sx, sz in ((1, 1), (1, -1), (-1, -1), (-1, 1))],
                      [S(sx * 0.095, 0.120, sz * 0.016) for sx, sz in ((1, 1), (1, -1), (-1, -1), (-1, 1))]], "fer", "garde")
lame = lambda ly, w, t: [S(w, ly, 0), S(0, ly, t), S(-w, ly, 0), S(0, ly, -t)]
loft(epee, "hand_r", [lame(0.118, 0.027, 0.006), lame(0.58, 0.023, 0.005)], "fer", "lame", apex=S(0.002, 0.79, 0.0))

arc = Maille()
pts = [(-0.46, -0.13), (-0.24, -0.035), (0.0, 0.0), (0.24, -0.035), (0.46, -0.13)]
dem = [0.009, 0.013, 0.016, 0.013, 0.009]
anneaux = []
for i, (lx, lz) in enumerate(pts):
    j0, j1 = max(i - 1, 0), min(i + 1, len(pts) - 1)
    tx, tz = pts[j1][0] - pts[j0][0], pts[j1][1] - pts[j0][1]
    nrm = math.hypot(tx, tz); nx, nz = -tz / nrm, tx / nrm          # normale dans le plan de courbure
    c = S(lx, 0.040, lz)
    sd = YB * dem[i]; fr = (XB * nx + ZB * nz) * (dem[i] * 0.8)
    anneaux.append([c + sd + fr, c + sd - fr, c - sd - fr, c - sd + fr])
loft(arc, "hand_r", anneaux, "bois", "arc")
corde = [[S(-0.46 + 0.0, 0.040, -0.13 - 0.0) + YB * 0.0 + off for off in (V(0, 0, 0),)]]
t0, t1 = S(-0.46, 0.040, -0.13), S(0.46, 0.040, -0.13)
cr = lambda p: [p + YB * 0.004, p - YB * 0.004 + XB * 0.003, p - YB * 0.004 - XB * 0.003]
loft(arc, "hand_r", [cr(t0), cr(t1)], "corde", "corde")

# ------------------------------------------------------------------ 4. ilots UV + peinture
def base_plane(co_list, nrm):
    # axe U = arete la plus longue de la face, projetee dans le plan
    best = None; bl = -1
    n = len(co_list)
    for i in range(n):
        e = co_list[(i + 1) % n] - co_list[i]
        e = e - nrm * e.dot(nrm)
        if e.length > bl:
            bl = e.length; best = e
    U = best.normalized() if best is not None and bl > 1e-9 else nrm.orthogonal().normalized()
    Vv = nrm.cross(U).normalized()
    return U, Vv

def fabriquer(Mm, nom, marche):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in Mm.v]
    fs = []
    for d in Mm.f:
        fs.append(bm.faces.new([vs[i] for i in d["ids"]]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    uvl = bm.loops.layers.uv.new("UVMap")
    for f, d in zip(fs, Mm.f):
        f.smooth = False
        f.material_index = d["mat"]
        cos = [l.vert.co.copy() for l in f.loops]
        U, Vv = base_plane(cos, f.normal)
        o = sum(cos, Vector()) / len(cos)
        uu = [(c - o).dot(U) for c in cos]; vv = [(c - o).dot(Vv) for c in cos]
        d.update(U=U, Vv=Vv, o=o, umin=min(uu), vmin=min(vv), N=f.normal.copy(), p2=[(a, b) for a, b in zip(uu, vv)])
        d["w"] = max(MINI, int(math.ceil((max(uu) - min(uu)) * DENSITE_PERSO - 1e-6)))
        d["h"] = max(MINI, int(math.ceil((max(vv) - min(vv)) * DENSITE_PERSO - 1e-6)))
        d["f"] = f
    marche.append((bm, uvl, fs, Mm, nom))

pieces = []
fabriquer(corps, "squelette", pieces)
fabriquer(epee, "epee", pieces)
fabriquer(arc, "arc", pieces)

# emballage (etageres) : l'ilot le plus haut d'abord
tous = [d for (_, _, _, Mm, _) in pieces for d in Mm.f if d["mat"] == 0]
tous.sort(key=lambda d: (-d["h"], -d["w"]))
x = y = rang = 0
x0 = 4; y0 = 4                                  # (0..3, 0..3) : bloc noir reserve
x = x0; y = 0; rang = 4
rang_h = 0
for d in tous:
    w = d["w"] + 2 * GUT; h = d["h"] + 2 * GUT
    if x + w > ATLAS:
        x = 0; y += rang_h; rang_h = 0
    if y == 0 and x < 4:
        x = 4
    if y + h > ATLAS:
        raise SystemExit("ATLAS PLEIN")
    d["rect"] = (x, y, w, h)
    x += w; rang_h = max(rang_h, h)
used = sum(d["rect"][2] * d["rect"][3] for d in tous)
print("ATLAS : %d ilots, %d texels sur %d (%.0f %%), hauteur utilisee %d" % (len(tous), used, ATLAS * ATLAS, 100.0 * used / ATLAS ** 2, y + rang_h))

# ---- peinture
def q5(c):
    return tuple(round(v / 255.0 * 31) / 31.0 for v in c)
def hexc(h):
    return q5((int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)))
RAMPES = {
    "os": [hexc(h) for h in ("#241911", "#43301f", "#654a30", "#8a6c47", "#a98f66", "#c4ae83", "#d9c89c", "#ece0bd")],
    "fer": [hexc(h) for h in ("#171413", "#272220", "#3a332f", "#4f453e", "#665a50", "#7f7266", "#9d9181", "#bcb09e")],
    "rouille": [hexc(h) for h in ("#211410", "#35201a", "#492d22", "#5e3b2a", "#744a34", "#8a5c40", "#a07150", "#b58862")],
    "cuir": [hexc(h) for h in ("#1c130c", "#2e2015", "#43301f", "#5a412a", "#72553a", "#8a6a48", "#a3835c", "#bc9c74")],
    "bois": [hexc(h) for h in ("#1d140d", "#322216", "#493221", "#614530", "#7b5a3f", "#967353", "#b08d68", "#c8a883")],
    "peinture": [hexc(h) for h in ("#1f0e0b", "#3a1a14", "#55261c", "#6f3426", "#8a4431", "#a45a3f", "#b97351", "#cc8b66")],
}
NOIR = hexc("#08070b")

def hsh(ix, iy, iz, seed):
    h = np.sin(ix * 127.1 + iy * 311.7 + iz * 74.7 + seed * 53.3) * 43758.5453
    return h - np.floor(h)

def vnoise(p, freq, seed):
    """bruit de valeur 3D (tableaux numpy) : p = (X, Y, Z) en metres, freq en 1/m."""
    X, Y, Z = (c * freq for c in p)
    ix, iy, iz = np.floor(X), np.floor(Y), np.floor(Z)
    fx, fy, fz = X - ix, Y - iy, Z - iz
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    def h(a, b, c):
        return hsh(ix + a, iy + b, iz + c, seed)
    x00 = h(0, 0, 0) * (1 - fx) + h(1, 0, 0) * fx
    x10 = h(0, 1, 0) * (1 - fx) + h(1, 1, 0) * fx
    x01 = h(0, 0, 1) * (1 - fx) + h(1, 0, 1) * fx
    x11 = h(0, 1, 1) * (1 - fx) + h(1, 1, 1) * fx
    return (x00 * (1 - fy) + x10 * fy) * (1 - fz) + (x01 * (1 - fy) + x11 * fy) * fz

img = np.zeros((ATLAS, ATLAS, 3), dtype=np.float32)
img[:, :] = NOIR
IDX_TONS = np.arange(8)

def colorer(ramp, tone, dith):
    idx = np.clip(np.floor(tone + dith), 0, 7).astype(int)
    r = np.array(RAMPES[ramp])
    return r[idx]

def peindre(d):
    x0, y0, W, H = d["rect"]
    jj, ii = np.meshgrid(np.arange(H), np.arange(W), indexing="ij")     # (rangee, colonne)
    u = d["umin"] + ((ii - GUT) + 0.5) / DENSITE_PERSO
    v = d["vmin"] + ((jj - GUT) + 0.5) / DENSITE_PERSO
    U, Vv, o, N = d["U"], d["Vv"], d["o"], d["N"]
    pos = tuple(o[k] + u * U[k] + v * Vv[k] for k in range(3))
    # distance au bord du polygone (en texels)
    p2 = d["p2"]; n = len(p2)
    dist = np.full(u.shape, 1e9)
    for i in range(n):
        ax, ay = p2[i]; bx, by = p2[(i + 1) % n]
        ex, ey = bx - ax, by - ay
        L2 = max(ex * ex + ey * ey, 1e-12)
        t = np.clip(((u - ax) * ex + (v - ay) * ey) / L2, 0, 1)
        dist = np.minimum(dist, np.hypot(u - (ax + t * ex), v - (ay + t * ey)))
    dpx = dist * DENSITE_PERSO
    grand = min(d["w"], d["h"]) >= 4
    cls = d["cls"]
    seed = (hash(d["part"]) % 97) * 0.37
    haut = N.z
    lum = np.full(u.shape, 0.0)
    lum += 1.25 * haut + 0.35 * (-N.y)                                # eclairage cuit : dessus clair, dessous sombre
    n1 = vnoise(pos, 1.0 / 0.07, seed); n2 = vnoise(pos, 1.0 / 0.20, seed + 3); n3 = vnoise(pos, 1.0 / 0.11, seed + 7)
    dith = (vnoise(pos, 1.0 / 0.05, seed + 11) - 0.5) * 0.9
    arete = (dpx < 0.8) & grand
    if cls in ("os", "cage"):
        tone = 4.1 + lum + (n2 - 0.5) * 1.7 + (n1 - 0.5) * 0.9
        tone -= np.where(n3 > 0.66, 1.5, 0.0)                         # taches brunes (os vieilli)
        tone -= 0.8 * np.clip(1.0 - (pos[2] / 1.7), 0, 1) * 0.6        # poussiere vers le bas
        if haut < -0.35:
            tone -= 1.5                                                # creux : dessous de l'os
        if cls == "cage":
            s = pos[2] + 0.45 * pos[1]
            ph = (s / 0.094) % 1.0
            fente = (ph < 0.36) & (np.abs(pos[0]) < 0.148)
            tone = np.where(fente, 0.0, tone)
            tone = np.where((ph >= 0.36) & (ph < 0.5), tone - 1.4, tone)      # ombre sous la fente
        tone = np.where(arete & (tone > 1.0), tone + 1.9, tone)
        if d["part"] in ("face", "machoire"):
            dent = (pos[2] < 1.645) & (pos[2] > 1.58) & (N.y < -0.2)
            tone = np.where(dent, 6.2 - 4.5 * ((np.floor(pos[0] / 0.0095) % 2) == 0), tone)
        c = colorer("os", tone, dith)
    elif cls == "fer":
        rouille = (n2 * 0.6 + n1 * 0.4) > 0.60
        tone = 3.6 + lum * 0.9 + (n1 - 0.5) * 1.2
        tone = np.where(arete, tone + 2.0, tone)
        c = np.where(rouille[..., None], colorer("rouille", tone * 0.95 + 0.4 * (n3 - 0.5) * 3, dith), colorer("fer", tone, dith))
    elif cls == "cuir":
        c = colorer("cuir", 3.2 + lum + (n1 - 0.5) * 1.4 + np.where(arete, 1.4, 0.0), dith)
    elif cls == "corde":
        c = colorer("cuir", 5.2 + (n1 - 0.5) * 0.8, dith)
    elif cls == "bois":
        c = colorer("bois", 3.4 + lum + (n1 - 0.5) * 1.6 + np.where(arete, 1.5, 0.0), dith)
    elif cls == "bouclier":
        C = d["centre"]; Rr = d["rayon"]
        dx, dz = pos[0] - C.x, pos[2] - C.z
        r = np.hypot(dx, dz)
        ang = (np.arctan2(dz, dx) + math.pi) / (2 * math.pi) * 8.0
        planche = (np.floor((dx + 0.30) / 0.094) % 2)
        tone = 3.6 + lum * 0.8 + (n1 - 0.5) * 1.2 + planche * 0.7
        joint = (((dx + 0.30) / 0.094) % 1.0) < 0.12
        tone = np.where(joint, tone - 1.5, tone)
        bois = colorer("bois", tone, dith)
        sect = (np.floor(ang) % 2) == 0
        ecaille = (n2 * 0.7 + n1 * 0.3) > 0.62                       # peinture ecaillee : le bois reparait
        pe = colorer("peinture", 3.2 + lum * 0.8 + (n1 - 0.5) * 1.3, dith)
        c = np.where((sect & ~ecaille & (haut < -0.5))[..., None], pe, bois)
        cerc = (r > Rr - 0.034) & (haut < -0.5)
        fer = colorer("fer", 3.0 + (n1 - 0.5) * 1.4 + np.where(r > Rr - 0.012, 2.0, 0.0), dith)
        c = np.where(cerc[..., None], fer, c)
        if haut > -0.5:
            c = colorer("bois", 3.0 + lum * 0.6 + (n1 - 0.5), dith)      # chant et revers
    elif cls == "noir":
        c = np.broadcast_to(np.array(NOIR), u.shape + (3,))
    else:
        c = np.broadcast_to(np.array(NOIR), u.shape + (3,))
    img[y0:y0 + H, x0:x0 + W] = c

for d in tous:
    peindre(d)

# ------------------------------------------------------------------ 5. objets Blender
img_b = bpy.data.images.new("squelette_guerrier_atlas", ATLAS, ATLAS, alpha=False)
rgba = np.ones((ATLAS, ATLAS, 4), dtype=np.float32)
rgba[:, :, :3] = img
rgba = rgba[::-1]                                  # Blender : rangee 0 = bas de l'image
img_b.pixels.foreach_set(rgba.ravel())
img_b.filepath_raw = OUT_PNG
img_b.file_format = 'PNG'
img_b.save()

def materiau(nom, couleur):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = couleur
    return m
mat_os = materiau("squelette_os", (0.75, 0.68, 0.55, 1.0))
mat_orb = materiau("squelette_orbites", (0.07, 0.14, 0.22, 1.0))

tris_tot = {}
for bm, uvl, fs, Mm, nom in pieces:
    for f, d in zip(fs, Mm.f):
        if d["mat"] == 0:
            x0, y0, W, H = d["rect"]
            for l in f.loops:
                c = l.vert.co
                uu = (c - d["o"]).dot(d["U"]) - d["umin"]; vv = (c - d["o"]).dot(d["Vv"]) - d["vmin"]
                px = x0 + GUT + uu * DENSITE_PERSO; py = y0 + GUT + vv * DENSITE_PERSO
                l[uvl].uv = (px / ATLAS, 1.0 - py / ATLAS)
        else:
            for l in f.loops:
                l[uvl].uv = (1.5 / ATLAS, 1.0 - 1.5 / ATLAS)
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    nt = sum(len(p.vertices) - 2 for p in me.polygons)
    tris_tot[nom] = nt
    me.materials.append(mat_os)
    me.materials.append(mat_orb)
    ob = bpy.data.objects.new(nom, me)
    bpy.context.collection.objects.link(ob)
    ob.parent = arm
    groupes = {}
    for i, b in enumerate(Mm.bone):
        groupes.setdefault(b, []).append(i)
    for b, lst in groupes.items():
        ob.vertex_groups.new(name=b).add(lst, 1.0, 'REPLACE')
    mod = ob.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
    bm.free()
print("TRIANGLES :", tris_tot, " corps+bouclier+casque =", tris_tot["squelette"])

bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', use_selection=True, export_skins=True, export_animations=False, export_apply=False)
print("EXPORT OK", OUT_GLB)
