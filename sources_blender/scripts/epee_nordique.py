# Lot 6 (graphisme) : épée nordique reconstruite de zéro (lame à gorge et biseaux, garde à quillons évasés,
# poignée de cuir renflée, pommeau en noix, rivets). Même repère que l'ancienne (lame le long de +Y glTF,
# tranchant en +X, poignée sous 0,078, pointe à 0,84 m), mêmes noms de matériaux (lame / fer / cuir).
#   blender.exe -b --python epee_nordique.py      (ré-exporte assets/modeles/joueur/epee_nordique.glb)
# Repère Blender : Z = le long de la lame, X = tranchant, Y = épaisseur (glTF : Y = Z, Z = -Y).
import bpy, bmesh, math, os, shutil

BASE = r"C:\Users\lopezk19\Jeux\nordique_objets"
GLB = BASE + r"\assets\modeles\joueur\epee_nordique.glb"
SAUVE = BASE + r"\sources_blender\epee_nordique_original.glb"
if os.path.exists(GLB) and not os.path.exists(SAUVE):
    shutil.copy(GLB, SAUVE)          # état d'avant le lot 6, conservé

bpy.ops.wm.read_factory_settings(use_empty=True)
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

def materiau(nom):
    m = bpy.data.materials.new(nom)
    return m

M = {n: materiau(n) for n in ("lame", "fer", "cuir")}

def objet(nom, mat, verts, faces, uvs, lisse):
    """verts : [(x, y, z)] ; faces : [[i, ...]] ; uvs : [(u, v)] par sommet (un UV par sommet suffit ici)."""
    me = bpy.data.meshes.new(nom)
    bm = bmesh.new()
    bv = [bm.verts.new(v) for v in verts]
    uvl = bm.loops.layers.uv.new("UVMap")
    for f in faces:
        try:
            bf = bm.faces.new([bv[i] for i in f])
        except ValueError:
            continue
        bf.smooth = lisse
        for lo, i in zip(bf.loops, f):
            lo[uvl].uv = uvs[i]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M[mat])
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    return o

def anneaux(rings, uv_de, ferme=True, cap_bas=False, pointe=None):
    """rings : liste d'anneaux (liste de (x, y, z)) de même taille ; relie anneau k à k+1. Renvoie verts, faces, uvs."""
    verts, uvs, faces = [], [], []
    n = len(rings[0])
    for k, r in enumerate(rings):
        for i, p in enumerate(r):
            verts.append(p)
            uvs.append(uv_de(k, i, n, p))
    for k in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            if not ferme and j == 0:
                continue
            faces.append([k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i])
    if pointe is not None:
        verts.append(pointe[0]); uvs.append(pointe[1])
        t = len(verts) - 1
        k = len(rings) - 1
        for i in range(n):
            faces.append([k * n + i, k * n + (i + 1) % n, t])
    if cap_bas:
        for i in range(1, n - 1):
            faces.append([0, i + 1, i][::-1] if False else [0, i + 1, i])
    return verts, faces, uvs

# ------------------------------------------------------------------ lame
def ss(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

def station(z):
    """largeur, épaisseur, profondeur de la gorge (0..1) à la hauteur z."""
    w = 0.0275 - 0.0040 * ss(0.12, 0.62, z) - 0.010 * ss(0.62, 0.80, z) - 0.0095 * ss(0.80, 0.838, z)
    t = 0.0036 - 0.0006 * ss(0.30, 0.80, z) - 0.0010 * ss(0.80, 0.84, z)
    d = ss(0.165, 0.19, z) * (1.0 - ss(0.60, 0.70, z))
    return w, t, d

ZS = [0.10, 0.12, 0.14, 0.165, 0.18, 0.19, 0.25, 0.35, 0.45, 0.55, 0.60, 0.64, 0.68, 0.72, 0.76, 0.79, 0.81, 0.825, 0.835]
def anneau_lame(z):
    w, t, d = station(z)
    b = 0.0070 * (1.0 - 0.3 * ss(0.7, 0.84, z))        # largeur du biseau du fil
    f = 0.0072 * (0.55 + 0.45 * d) * (1.0 if d > 0 else 0.0)
    ft = t - (t - 0.0016) * d
    top = [(-w, 0), (-w + b, t), (-f - 0.0016, t), (-f + 0.0008, ft), (f - 0.0008, ft), (f + 0.0016, t), (w - b, t), (w, 0)]
    bas = [(w - b, -t), (f + 0.0016, -t), (f - 0.0008, -ft), (-f + 0.0008, -ft), (-f - 0.0016, -t), (-w + b, -t)]
    return [(x, y, z) for x, y in top + bas]

rings = [anneau_lame(z) for z in ZS]
W0 = 0.0275
def uv_lame(k, i, n, p):
    # u : travers (x), v : longueur ; face inférieure = même texture, sens miroir (symétrie de la lame)
    return ((p[0] + W0) / (2 * W0), (p[2] - 0.10) / 0.74)
v, f, u = anneaux(rings, uv_lame, pointe=((0, 0, 0.84), (0.5, 1.0)))
objet("lame", "lame", v, f, u, False)

# ------------------------------------------------------------------ garde
def octogone(hx, hy, ch=0.35):
    c = ch
    return [(-hx * (1 - c), -hy), (hx * (1 - c), -hy), (hx, -hy * (1 - c)), (hx, hy * (1 - c)),
            (hx * (1 - c), hy), (-hx * (1 - c), hy), (-hx, hy * (1 - c)), (-hx, -hy * (1 - c))]

# stations le long de X : (x, demi-hauteur, demi-épaisseur, affaissement en z)
GX = [-0.098, -0.090, -0.078, -0.060, -0.032, -0.018, 0.018, 0.032, 0.060, 0.078, 0.090, 0.098]
GP = [(0.0045, 0.0060, 0.016), (0.0105, 0.0090, 0.014), (0.0125, 0.0105, 0.010), (0.0100, 0.0125, 0.005),
      (0.0120, 0.0145, 0.001), (0.0160, 0.0185, 0.0), (0.0160, 0.0185, 0.0), (0.0120, 0.0145, 0.001),
      (0.0100, 0.0125, 0.005), (0.0125, 0.0105, 0.010), (0.0105, 0.0090, 0.014), (0.0045, 0.0060, 0.016)]
ZG = 0.092
rg = []
for x, (hy, hz, aff) in zip(GX, GP):
    oc = octogone(hz, hy)             # (épaisseur, hauteur) -> (y, z)
    rg.append([(x, a, ZG - aff + b) for a, b in oc])
def uv_garde(k, i, n, p):
    return ((p[0] + 0.098) / 0.196 * 2.0, i / n)
v, f, u = anneaux(rg, uv_garde)
# fermeture des extrémités
n = 8
for k in (0, len(rg) - 1):
    for i in range(1, n - 1):
        f.append([k * n, k * n + i + 1, k * n + i] if k == 0 else [k * n, k * n + i, k * n + i + 1])
def sphere(cx, cy, cz, r, seg=6, anneaux_n=4):
    vs, fs, us = [], [], []
    rows = []
    for a in range(1, anneaux_n):
        th = math.pi * a / anneaux_n
        rows.append([(cx + r * math.sin(th) * math.cos(2 * math.pi * i / seg),
                      cy + r * math.sin(th) * math.sin(2 * math.pi * i / seg),
                      cz + r * math.cos(th)) for i in range(seg)])
    return rows
def ajouter_sphere(vs, fs, us, c, r, seg=6, na=4):
    base = len(vs)
    rows = sphere(c[0], c[1], c[2], r, seg, na)
    haut = (c[0], c[1], c[2] + r); bas = (c[0], c[1], c[2] - r)
    vs.append(haut); us.append((0.5, 0.5)); ih = len(vs) - 1
    for row in rows:
        for p in row:
            vs.append(p); us.append((0.5 + (p[0] - c[0]) / (2 * r) * 0.2, 0.5 + (p[1] - c[1]) / (2 * r) * 0.2))
    vs.append(bas); us.append((0.5, 0.5)); ib = len(vs) - 1
    for i in range(seg):
        j = (i + 1) % seg
        fs.append([ih, ih + 1 + j, ih + 1 + i])
    for r_ in range(len(rows) - 1):
        for i in range(seg):
            j = (i + 1) % seg
            a = ih + 1 + r_ * seg
            b = a + seg
            fs.append([a + i, a + j, b + j, b + i][::-1])
    last = ih + 1 + (len(rows) - 1) * seg
    for i in range(seg):
        j = (i + 1) % seg
        fs.append([last + i, last + j, ib][::-1])
# rivets : deux par face de la garde, encadrant la lame
for sx in (-1, 1):
    for sy in (-1, 1):
        ajouter_sphere(v, f, u, (sx * 0.050, sy * 0.0112, ZG), 0.0036)
objet("garde", "fer", v, f, u, True)

# ------------------------------------------------------------------ poignée de cuir : renflement léger, nœuds aux extrémités
SEG = 14
def prof_poignee(z):
    t = (z - 0.002) / 0.076
    r = 0.0172 + 0.0026 * math.sin(math.pi * t) ** 0.8
    r += 0.0030 * (math.exp(-((t - 0.02) / 0.05) ** 2) + math.exp(-((t - 0.98) / 0.05) ** 2))   # frettes de cuir aux bouts
    return r
ZP = [0.002 + 0.076 * k / 13 for k in range(14)]
rp = []
for z in ZP:
    r = prof_poignee(z)
    rp.append([(r * 1.0 * math.cos(2 * math.pi * i / SEG), r * 0.93 * math.sin(2 * math.pi * i / SEG), z) for i in range(SEG)])
def uv_poignee(k, i, n, p):
    return (i / n * 2.0, (p[2] - 0.002) / 0.076 * 1.6)
v, f, u = anneaux(rp, uv_poignee)
# la couture : un dernier anneau d'UV (i = SEG) n'existe pas ; le raccord u=2.0 -> 0.0 reste visible mais cousu (couture voulue)
objet("poignee", "cuir", v, f, u, True)

# ------------------------------------------------------------------ pommeau : noix aplatie, bague, rivet de rivetage
PR = [(-0.0445, 0.0), (-0.0440, 0.0075), (-0.0405, 0.0105), (-0.0385, 0.0190), (-0.0335, 0.0290), (-0.0260, 0.0345),
      (-0.0180, 0.0365), (-0.0125, 0.0345), (-0.0105, 0.0300), (-0.0085, 0.0345), (-0.0050, 0.0310), (-0.0010, 0.0215), (0.0020, 0.0170)]
SP = 12
rr = []
for z, r in PR[1:]:
    rr.append([(r * math.cos(2 * math.pi * i / SP), r * 0.50 * math.sin(2 * math.pi * i / SP), z) for i in range(SP)])
def uv_pom(k, i, n, p):
    return (i / n * 2.0, (p[2] + 0.0445) / 0.047)
v, f, u = anneaux(rr, uv_pom)
# calotte du bas
bas = len(v)
v.append((0, 0, PR[0][0])); u.append((0.5, 0.0))
for i in range(SP):
    f.append([i, (i + 1) % SP, bas])
objet("pommeau", "fer", v, f, u, True)

# ------------------------------------------------------------------ export
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', export_apply=True, export_materials='EXPORT',
                          export_image_format='NONE', export_yup=True, use_selection=False)
print("épée exportée :", GLB, sum(len(o.data.polygons) for o in bpy.data.objects), "faces")
