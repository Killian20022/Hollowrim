# CHAÎNE D'ADAPTATION DES PROPS QUATERNIUS (CC0) AU RENDU DU JEU (essai/props_quaternius, 2026-10-29).
#   blender.exe -b --python importer_quaternius.py -- liste=<props.json> [sortie=<.dat>] [apercu=<dossier>] [seulement=q_a,q_b]
# Entrée : props.json = [{"nom": "q_enclume", "src": "C:/.../Anvil.gltf", "hauteur": 0.55 | "ech": 1.0, "budget": 400,
#                         "mats": {"MI_Trim_Metal": "fer"}, "lacet": 0, "role": "forge"} ...]
#   (src : .gltf / .glb / .fbx / .obj ; les fichiers Quaternius sont des DONNÉES : on les importe, on n'exécute rien d'eux)
# Étapes par prop :
#   1. import, fusion des maillages, transformations appliquées, passage au repère Godot (y en haut, +z = avant) ;
#   2. mise à l'échelle réelle (hauteur cible en m, ou facteur), origine au sol au centre de l'emprise ;
#   3. réduction (Decimate « collapse ») si le nombre de triangles dépasse le budget du prop ;
#   4. couleur Quaternius REMAPPÉE : pour chaque triangle, couleur de base (texture « trim » échantillonnée au centre UV, sinon
#      couleur du matériau) -> rampe la plus proche de la BIBLE (bois, fer, pierre, or, laine, lin, jute, os, parchemin, argile, noir)
#      = matière de CrypteDecor ; le TON (multiplicateur de la texture du jeu) = luminance relative dans la rampe ;
#   5. couleur de sommet comme objets_donjon.py : ton x occlusion ambiante cuite (creux jusqu'au ton 0, plancher OMBRE) x PIED sombre
#      (-2 tons au ras du sol) ; puis aretes.appliquer (arête haute +1 ton, arête basse -1, creux sombres) ;
#   6. sortie au format .dat des modules (même format que objets_donjon.dat : relu par CrypteDecor._charger_modeles en FileAccess,
#      jamais de .glb dans le fil) : entrées « q_<nom>__<matière> » ;
#   7. aperçus : original Quaternius (ses textures) / adapté (couleur de matière x couleur de sommet, rendu 1/3 puis agrandi en
#      « plus proche », quantifié sur la palette de la bible) -> planche.
import bpy, bmesh, math, os, random, struct, sys, json, colorsys
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aretes

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
DAT = os.path.join(BASE, "assets", "crypte", "modules", "props_quaternius.dat")
TAU = 2 * math.pi
UP = Vector((0, 1, 0))
OMBRE = 0.42        # plancher de l'occlusion : le creux descend vers le ton 0 (rampe Ombre) sans tomber au noir pur
PIED = 0.62         # facteur au ras du sol (≈ -2 tons), remonte à 1 sur PIED_H
PIED_H = 0.22
FER_MAX = 0.6       # plafond du ton du fer (réglé sur les captures en jeu du 2026-10-29)


def H(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# Rampes de la bible (docs/BIBLE_VISUELLE.md §2) -> matière CrypteDecor
RAMPES = {
    "bois": ["#2b1a1e", "#472a21", "#6a4229", "#92613a", "#bb8a53"],
    "fer": ["#20252f", "#3a4256", "#5b6680", "#8a96ae", "#bcc6d8"],
    "pierre": ["#262a3b", "#3a4057", "#565b72", "#787d8e", "#a0a2ab"],
    "or": ["#4a3419", "#7b5a26", "#a98638", "#d3b25c"],
    "laine": ["#351520", "#5c1f2b", "#8a2f35", "#b9504a"],
    "lin": ["#8e8688", "#b9ae9f", "#dbd0b6", "#efe7d0"],
    "jute": ["#211e1c", "#3b3322", "#5c4e2d", "#82723f", "#b39d5d"],
    "argile": ["#3b1f24", "#6a3524", "#9c5129", "#cf7b3c"],
    "toile": ["#1b2a52", "#2a4382", "#4468ac", "#7b9ad0"],      # laine bleue : la « toile » du jeu (à vérifier en jeu)
    "noir": ["#14161a", "#0f0b08"],
    "os": ["#8e8688", "#b9ae9f", "#dbd0b6", "#efe7d0"],          # os, cire (même rampe Écru que le lin, autre matière en jeu)
}
# Familles : le nom du matériau Quaternius (trim sheets des megakits) restreint les matières candidates
FAMILLES = {"metal": ("fer", "or", "noir"), "furniture": ("bois", "fer", "or", "lin", "laine", "noir"),
            "cloth": ("laine", "lin", "toile", "jute", "noir"), "props": ("bois", "fer", "or", "laine", "os", "jute", "argile", "toile", "noir"),
            "rock": ("pierre", "noir"), "stone": ("pierre", "noir")}
DEFAUT = ("bois", "fer", "or", "laine", "lin", "jute", "argile", "toile", "pierre", "noir")
# ton de référence (milieu de rampe) : ton = luminance / luminance de référence
TOUTES = [(m, H(c)) for m, l in RAMPES.items() for c in l]


def famille(nom_mat):
    n = nom_mat.lower()
    for k, v in FAMILLES.items():
        if k in n:
            return v
    return DEFAUT
PALETTE = [H(c) for c in (
    "#4a557f #6877a3 #8898bf #aab8d6 #cdd7ec #f0eff4 #33577f #4f86ae #86bfd3 #cfeef0 #08161a #10272a #1a3d32 #2c5a41 #5b866f #6e9172 "
    "#241a22 #3a2a2a #54402f #735b43 #947c5e #3b1f24 #6a3524 #9c5129 #cf7b3c #ecaa62 #3d3c4a #5b5a66 #7f7d82 #a7a19b #262a3b #3a4057 "
    "#565b72 #787d8e #a0a2ab #2b1a1e #472a21 #6a4229 #92613a #bb8a53 #211e1c #3b3322 #5c4e2d #82723f #b39d5d #1f1418 #3a261b #5b3d27 "
    "#86603a #1b2a52 #2a4382 #4468ac #7b9ad0 #351520 #5c1f2b #8a2f35 #b9504a #8e8688 #b9ae9f #dbd0b6 #efe7d0 #25262f #3d3e4a #5c5d68 "
    "#85848c #b3b0b4 #20252f #3a4256 #5b6680 #8a96ae #bcc6d8 #4a3419 #7b5a26 #a98638 #d3b25c #5a1a1c #b3341f #ec6a1f #fcb53a #fff0a8 "
    "#0c4a5e #14899b #3fd0d0 #b6fbf0 #030303 #090808 #0f0b08 #14161a").split()]
# couleur d'aperçu de chaque matière (≈ ton moyen de la texture du jeu)
APERCU = {m: H(l[-2]) for m, l in RAMPES.items()}      # même référence que le ton
APERCU["lame"] = H("#8a96ae")
APERCU["os"] = H("#dbd0b6")
APERCU["lin"] = H("#dbd0b6")
APERCU["parchemin"] = H("#dbd0b6")


def lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def lin2srgb(x):
    return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055


def classer(c, indice=None, candidats=DEFAUT):
    """c = couleur sRGB 0-1 -> (matière, ton). indice = matière imposée par le nom du matériau (« Metal » -> fer…)."""
    h, s, v = colorsys.rgb_to_hsv(*c)
    if indice:
        m = indice
    else:
        best, m = 9, "bois"
        for mm, cc in TOUTES:
            if mm not in candidats:
                continue
            h2, s2, v2 = colorsys.rgb_to_hsv(*cc)
            dh = min(abs(h - h2), 1 - abs(h - h2)) * min(1.0, 3 * min(s, s2))     # teinte comptée seulement si saturée
            d = 2.2 * dh + 1.2 * abs(s - s2) + 0.6 * abs(v - v2)
            if d < best:
                best, m = d, mm
        if s < 0.12 and v < 0.12:
            m = "noir"
    ref = RAMPES.get(m, RAMPES["bois"])
    # fer : référence au ton clair (le fer foncé descend)
    lref = lum(H(ref[-1 if m == "fer" else -2])) if m in RAMPES else lum(APERCU.get(m, (0.5, 0.5, 0.5)))
    ton = max(0.3, min(1.0, (lum(c) / max(lref, 1e-3)) ** 0.9))
    if m == "fer":
        ton = min(ton, FER_MAX)     # le shader crypte éclaircit déjà le fer (teinte x1,3 + reflet) : sinon l'enclume sort beige      # ton 1 = avant-dernier ton de la rampe
    return m, ton


# --------------------------------------------------------------------- import
def importer(src):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ext = src.lower().rsplit(".", 1)[-1]
    if ext in ("gltf", "glb"):
        bpy.ops.import_scene.gltf(filepath=src)
    elif ext == "fbx":
        bpy.ops.import_scene.fbx(filepath=src)
    elif ext == "obj":
        bpy.ops.wm.obj_import(filepath=src)
    return [o for o in bpy.context.scene.objects if o.type == 'MESH']


_IMG = {}


def pixels(img):
    if img.name not in _IMG:
        w, h = img.size
        _IMG[img.name] = (w, h, list(img.pixels[:]))
    return _IMG[img.name]


def tex_base(mat):
    """Image branchée sur la couleur de base du Principled (texture « trim » des megakits), ou None."""
    if not mat or not mat.use_nodes:
        return None, (0.6, 0.6, 0.6)
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if not bsdf:
        return None, (0.6, 0.6, 0.6)
    inp = bsdf.inputs[0]
    col = tuple(lin2srgb(x) for x in inp.default_value[:3])
    if inp.links:
        n = inp.links[0].from_node
        for _ in range(4):
            if n.type == "TEX_IMAGE":
                return n.image, col
            ins = [i for i in n.inputs if i.links]
            if not ins:
                break
            n = ins[0].links[0].from_node
    return None, col


def echantillon(img, uv):
    w, h, px = pixels(img)
    x = int((uv[0] % 1.0) * w) % w
    y = int((uv[1] % 1.0) * h) % h
    i = (y * w + x) * 4
    c = px[i:i + 3]
    if img.colorspace_settings.name.lower().startswith("srgb"):      # pixels[] de Blender = valeurs linéaires pour les images sRGB
        c = [lin2srgb(v) for v in c]
    return tuple(c)


def triangles(objs, budget):
    """[(a, b, c) repère Godot, couleur sRGB, nom matériau)] ; réduit au budget."""
    dg = bpy.context.evaluated_depsgraph_get()
    total = 0
    for o in objs:
        total += sum(len(p.vertices) - 2 for p in o.data.polygons)
    ratio = min(1.0, budget / max(1, total))
    if ratio < 1.0:
        for o in objs:                      # d'abord fusion des faces coplanaires (garde la silhouette), puis effondrement
            mp = o.modifiers.new("plan", 'DECIMATE')
            mp.decimate_type = 'DISSOLVE'
            mp.angle_limit = math.radians(4)
        dg = bpy.context.evaluated_depsgraph_get()
        tot2 = sum(sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).data.polygons) for o in objs)
        ratio = min(1.0, budget / max(1, tot2))
    if ratio < 1.0:
        for o in objs:
            md = o.modifiers.new("reduc", 'DECIMATE')
            md.ratio = ratio
            md.use_collapse_triangulate = True
        dg = bpy.context.evaluated_depsgraph_get()
    out = []
    for o in objs:
        oe = o.evaluated_get(dg)
        me = oe.to_mesh()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.faces.index_update()
        uvl = bm.loops.layers.uv.active
        W = o.matrix_world
        ile = {}                            # îlots (pièces séparées : planche, cerclage, bougie…) : une matière par îlot
        n_ile = 0
        for f0 in bm.faces:
            if f0.index in ile:
                continue
            pile = [f0]
            ile[f0.index] = n_ile
            while pile:
                f = pile.pop()
                for v in f.verts:
                    for g in v.link_faces:
                        if g.index not in ile:
                            ile[g.index] = n_ile
                            pile.append(g)
            n_ile += 1
        base_ile = len(out) and (out[-1][3] + 1) or 0
        for f in bm.faces:
            mat = o.material_slots[f.material_index].material if o.material_slots else None
            img, col = tex_base(mat)
            if img is not None and uvl is not None:
                uv = sum((l[uvl].uv for l in f.loops), Vector((0, 0))) / 3
                col = echantillon(img, uv)
            pts = []
            for l in f.loops:
                p = W @ l.vert.co
                pts.append(Vector((p.x, p.z, -p.y)))       # Blender (z haut) -> Godot (y haut, +z avant)
            out.append((tuple(pts), col, mat.name if mat else "", base_ile + ile[f.index]))
        bm.free()
        oe.to_mesh_clear()
    return out, total


def indice_mat(nom, mats):
    for k, v in mats.items():
        if k.lower() in nom.lower():
            return v
    return None


class Prop:
    def __init__(self, nom):
        self.nom = nom
        self.tris = []      # (matière, (a, b, c), ton)
        self.sol = True
        self.bandes = "hautes"
        self.brute = {}

    def finir(self, rayons=12, portee=0.22, force=0.7):
        verts, polys = [], []
        for (m, p, t) in self.tris:
            polys.append((len(verts), len(verts) + 1, len(verts) + 2))
            verts.extend(p)
        arbre = BVHTree.FromPolygons([tuple(v) for v in verts], polys, all_triangles=True, epsilon=1e-6)
        rg = random.Random(7)
        dirs = []
        for _ in range(rayons):
            u, v = rg.random(), rg.random()
            r = math.sqrt(u)
            th = TAU * v
            dirs.append((r * math.cos(th), r * math.sin(th), math.sqrt(max(0.0, 1.0 - u))))
        sortie = {}
        for (m, p, t) in self.tris:
            n = (p[1] - p[0]).cross(p[2] - p[0])
            if n.length < 1e-12:
                continue
            n.normalize()
            tg = n.cross(UP if abs(n.y) < 0.9 else Vector((1, 0, 0))).normalized()
            bt = n.cross(tg)
            cols = []
            for q in p:
                occ = 0.0
                o = q + n * 0.004
                for dx, dy, dz in dirs:
                    d = (tg * dx + bt * dy + n * dz).normalized()
                    h = arbre.ray_cast(o, d, portee)
                    if h[0] is not None:
                        occ += 1.0 - h[3] / portee
                ao = max(OMBRE, min(1.0, 1.0 - force * occ / len(dirs) * 1.6))
                pied = (PIED + (1 - PIED) * min(1.0, max(0.0, q.y / PIED_H))) if self.sol else 1.0
                k = ao * t * pied
                cols.append((min(1.0, k), min(1.0, k), min(1.0, k), 1.0))
            sortie.setdefault(m, []).append((p, cols))
        return sortie


def adapter(e):
    objs = importer(e["src"])
    if not objs:
        print("  AUCUN MAILLAGE", e["src"])
        return None, None
    tris, total = triangles(objs, e.get("budget", 400))
    pts = [q for p, _, _, _ in tris for q in p]
    lo = Vector([min(q[i] for q in pts) for i in range(3)])
    hi = Vector([max(q[i] for q in pts) for i in range(3)])
    ech = e.get("ech", 1.0)
    if "hauteur" in e:
        ech = e["hauteur"] / max(1e-4, hi.y - lo.y)
    c0 = Vector(((lo.x + hi.x) / 2, lo.y, (lo.z + hi.z) / 2))
    R = Matrix.Rotation(math.radians(e.get("lacet", 0)), 3, 'Y')
    P = Prop(e["nom"])
    P.sol = e.get("sol", True)
    stat = {}
    cl = [classer(col, indice_mat(mn, e.get("mats", {})) if e.get("mats") else None, famille(mn)) for p, col, mn, il in tris]
    vote = {}                               # vote pondéré par l'aire : matière majoritaire et ton moyen de chaque îlot
    for (p, col, mn, il), (m, ton) in zip(tris, cl):
        a = (p[1] - p[0]).cross(p[2] - p[0]).length + 1e-9
        d = vote.setdefault(il, {})
        w = d.setdefault(m, [0.0, 0.0])
        w[0] += a
        w[1] += a * ton
    choix = {}
    for il, d in vote.items():
        m = max(d, key=lambda k: d[k][0])
        choix[il] = (m, d[m][1] / d[m][0])
    for (p, col, mn, il), (m0, ton0) in zip(tris, cl):
        m, tmoy = choix[il]
        ton = tmoy + 0.35 * ((ton0 if m0 == m else tmoy) - tmoy)      # garde un peu de la variation de la texture, sans taches
        if e.get("forcer", {}).get(m):
            m = e["forcer"][m]
        stat[m] = stat.get(m, 0) + 1
        P.tris.append((m, tuple(R @ ((q - c0) * ech) for q in p), ton))
    P.total_src = total
    P.stat = stat
    return P, objs


# --------------------------------------------------------------------- aperçus
def _camera(sc, lo, hi, B):
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = 'ORTHO'
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    ctr = Vector(B(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)))
    cam_d.ortho_scale = max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]) * 1.4
    d = Vector((0.9, -1.4, 0.75))
    cam.location = ctr + d.normalized() * 30
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam_d.clip_end = 100


def _workbench(sc, couleur, res):
    try:
        sc.render.engine = 'BLENDER_WORKBENCH'
    except TypeError as er:
        print("moteur :", er)
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = couleur
    sh.show_backface_culling = False
    sh.show_specular_highlight = False      # pas de reflet de studio (il bleuissait le bois une fois quantifié)
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.film_transparent = True


def apercu_original(e, objs, chemin):
    """Les objets importés sont encore dans la scène : rendu avec leurs textures."""
    sc = bpy.context.scene
    for o in objs:
        for md in list(o.modifiers):
            o.modifiers.remove(md)
    pts = [o.matrix_world @ Vector(b) for o in objs for b in o.bound_box]
    B = lambda v: v
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    # repère Blender ici (z haut) : caméra adaptée
    cam_d = bpy.data.cameras.new("cam0")
    cam_d.type = 'ORTHO'
    cam = bpy.data.objects.new("cam0", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    ctr = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2))
    cam_d.ortho_scale = max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]) * 1.4
    d = Vector((0.9, -1.4, 0.75))
    cam.location = ctr + d.normalized() * 30
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam_d.clip_end = 100
    _workbench(sc, 'TEXTURE', 240)
    sc.render.filepath = chemin
    bpy.ops.render.render(write_still=True)


def maillage_adapte(P, res, nom="adapte", couleur=True):
    sc = bpy.context.scene
    B = lambda v: (v[0], -v[2], v[1])
    me = bpy.data.meshes.new(nom)
    vs, cols = [], []
    for mat, faces in res.items():
        t = APERCU.get(mat, (0.5, 0.5, 0.5))
        for p, c in faces:
            for q, cc in zip(p, c):
                vs.append(B(q))
                cols.append((srgb2lin(t[0] * cc[0]), srgb2lin(t[1] * cc[1]), srgb2lin(t[2] * cc[2]), 1) if couleur else cc)
    me.from_pydata(vs, [], [(i, i + 1, i + 2) for i in range(0, len(vs), 3)])
    me.update()
    ca = me.color_attributes.new(name="c", type='BYTE_COLOR', domain='CORNER')
    for poly in me.polygons:
        for li in poly.loop_indices:
            ca.data[li].color = cols[me.loops[li].vertex_index]
    me.color_attributes.active_color = ca
    ob = bpy.data.objects.new(nom, me)
    sc.collection.objects.link(ob)
    return ob


def apercu_adapte(P, res, chemin):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    maillage_adapte(P, res)
    pts = [q for (_, p, _) in P.tris for q in p]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    _camera(sc, lo, hi, lambda v: (v[0], -v[2], v[1]))
    _workbench(sc, 'VERTEX', 120)       # 1/2 de la taille : gros texels du rendu 480x270, agrandis ensuite en « plus proche »
    sc.display.shading.studio_light = 'paint.sl' if 'paint.sl' in [x.name for x in bpy.context.preferences.studio_lights] else sc.display.shading.studio_light
    sc.render.filepath = chemin
    bpy.ops.render.render(write_still=True)


def quantifier(img_px, w, h, ech=1):
    """Pixels RGBA linéaires -> chaque pixel opaque ramené à la couleur la plus proche de la palette de la bible ; agrandi x ech."""
    pal = PALETTE
    out = [0.0] * (w * ech * h * ech * 4)
    cache = {}
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            a = img_px[i + 3]
            if a < 0.5:
                c = (0, 0, 0, 0)
            else:
                s = tuple(lin2srgb(v) for v in img_px[i:i + 3])
                k = tuple(int(v * 32) for v in s)
                if k not in cache:
                    cache[k] = min(pal, key=lambda p: (p[0] - s[0]) ** 2 * 0.3 + (p[1] - s[1]) ** 2 * 0.59 + (p[2] - s[2]) ** 2 * 0.11)
                q = cache[k]
                c = (srgb2lin(q[0]), srgb2lin(q[1]), srgb2lin(q[2]), 1.0)
            for dy in range(ech):
                for dx in range(ech):
                    j = ((y * ech + dy) * w * ech + x * ech + dx) * 4
                    out[j:j + 4] = c
    return out


def srgb2lin(x):
    return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4


def planche(cases, chemin, cols=5, tw=240, fond=(0.06, 0.06, 0.08)):
    """cases = [(png original, png adapté 80 px)] -> planche PNG (paires côte à côte)."""
    rows = (len(cases) + cols - 1) // cols
    W, Hh = cols * tw * 2 + (cols + 1) * 8, rows * (tw + 8) + 8
    buf = [0.0] * (W * Hh * 4)
    lf = [srgb2lin(v) for v in fond]
    for i in range(W * Hh):
        buf[i * 4:i * 4 + 4] = [lf[0], lf[1], lf[2], 1.0]
    for n, (a, b) in enumerate(cases):
        cx, cy = n % cols, n // cols
        x0 = 8 + cx * (tw * 2 + 8)
        y0 = Hh - (cy + 1) * (tw + 8)
        for k, f in enumerate((a, b)):
            if not os.path.exists(f):
                continue
            im = bpy.data.images.load(f)
            w, h = im.size
            px = list(im.pixels[:])
            if k == 1:
                px = quantifier(px, w, h, tw // w)
                w, h = w * (tw // w), h * (tw // h)
            for y in range(min(h, tw)):
                for x in range(min(w, tw)):
                    i = (y * w + x) * 4
                    al = px[i + 3]
                    if al > 0.01:
                        j = ((y0 + y) * W + x0 + k * tw + x) * 4
                        for c in range(3):
                            buf[j + c] = buf[j + c] * (1 - al) + px[i + c] * al
            bpy.data.images.remove(im)
    out = bpy.data.images.new("planche", W, Hh, alpha=False)
    out.pixels[:] = buf
    out.filepath_raw = chemin
    out.file_format = 'PNG'
    out.save()


# --------------------------------------------------------------------- main
def _lire_dat(chemin):
    d = {}
    if not os.path.exists(chemin):
        return d
    b = open(chemin, "rb").read()
    o = 4
    for _ in range(struct.unpack_from("<I", b, 0)[0]):
        nom = b[o + 1:o + 1 + b[o]].decode()
        o += 1 + b[o]
        nb = struct.unpack_from("<I", b, o)[0]
        o += 4
        fl = struct.unpack_from("<%df" % (nb * 7), b, o)
        o += nb * 28
        sv = [(Vector(fl[i * 7:i * 7 + 3]), tuple(fl[i * 7 + 3:i * 7 + 7])) for i in range(nb)]
        d[nom] = [(tuple(q for q, _ in sv[j:j + 3]), tuple(c for _, c in sv[j:j + 3])) for j in range(0, nb, 3)]
    return d


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    A = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in args if "=" in a}
    liste = json.load(open(A["liste"], encoding="utf8"))
    dat = A.get("sortie", DAT)
    seul = tuple(A["seulement"].split(",")) if "seulement" in A else None
    dossier = A.get("apercu")
    donnees = {k: v for k, v in _lire_dat(dat).items() if seul and not k.split("__")[0] in seul}
    cases = []
    bilan = []
    for e in liste:
        if seul and e["nom"] not in seul:
            continue
        P, objs = adapter(e)
        if P is None:
            continue
        if dossier:
            os.makedirs(dossier, exist_ok=True)
            apercu_original(e, objs, os.path.join(dossier, e["nom"] + "_orig.png"))
        st = {}
        res = aretes.appliquer(P.finir(), bandes=P.bandes, stats=st)
        for mat, faces in res.items():
            donnees["%s__%s" % (P.nom, mat)] = faces
        pts = [q for (_, p, _) in P.tris for q in p]
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        n_fin = sum(len(f) for f in res.values())
        ligne = "%-22s src %5d -> %4d tris (budget %4d) -> %4d apres aretes  %.2fx%.2fx%.2f m  %s" % (
            P.nom, P.total_src, len(P.tris), e.get("budget", 400), n_fin, hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2],
            " ".join("%s:%d" % kv for kv in sorted(P.stat.items(), key=lambda kv: -kv[1])))
        print("  " + ligne)
        bilan.append(ligne)
        if dossier:
            apercu_adapte(P, res, os.path.join(dossier, e["nom"] + "_adapte.png"))
            cases.append((os.path.join(dossier, e["nom"] + "_orig.png"), os.path.join(dossier, e["nom"] + "_adapte.png")))
    os.makedirs(os.path.dirname(dat), exist_ok=True)
    with open(dat, "wb") as f:
        f.write(struct.pack("<I", len(donnees)))
        for nom, faces in donnees.items():
            nb = nom.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<I", len(faces) * 3))
            for p, c in faces:
                for q, cc in zip(p, c):
                    f.write(struct.pack("<7f", q.x, q.y, q.z, cc[0], cc[1], cc[2], cc[3]))
    print("props quaternius : %d entrees -> %s" % (len(donnees), dat))
    if dossier:
        open(os.path.join(dossier, "bilan.txt"), "w", encoding="utf8").write("\n".join(bilan) + "\n")
        if cases and A.get("planche"):
            planche(cases, A["planche"])
            print("planche ->", A["planche"])


if __name__ == "__main__":
    main()
