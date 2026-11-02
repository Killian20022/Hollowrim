"""Outils communs des armures PORTÉES (convention : C:/Users/lopezk19/Jeux/conception_rpg/CONVENTION_ARMURES_3D.md).

Toutes les pièces sont construites dans la pose de repos du héros (squelette Quaternius de homme_vetu.glb, mêmes noms d'os que
HerosSkarnholt / corps_joueur.gd), ajustées sur les maillages VISIBLES du héros exportés de Godot (outils/exporter_heros_obj.gd ->
sources_blender/armures/heros/*.obj) et sur les vêtements Quaternius de base, puis :
  - poids d'os : hérités du vêtement Quaternius dont la pièce dérive (tunique, gants, bottes, peau de la tête), ou copiés du sommet
    le plus proche de ce vêtement pour les ajouts (sangles, plaques, fourrures) ;
  - UV automatiques (projection intelligente) MAIS texture CUITE texel par texel depuis la position 3D de repos (fonction de matière
    par pièce : coutures, sangles, plaques, rivets placés dans l'espace, pas d'aplats « camouflage ») ; alpha = brillance (shader_matiere) ;
  - export glb SKINNÉ (armature complète + un maillage) -> assets/modeles/armures/porte/<id>.glb, et pose « au sol » statique
    -> assets/modeles/armures/sol/<id>.glb (pivot au sol).
Repère : on écrit les constantes en repère GODOT (x, y haut, z devant) ; B() les passe en Blender (x, -z, y).
"""
import bpy, bmesh, os, math
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ICI = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(ICI, "..", ".."))
HEROS = os.path.join(ROOT, "sources_blender", "armures", "heros")
PORTE = os.path.join(ROOT, "assets", "modeles", "armures", "porte")
SOL = os.path.join(ROOT, "assets", "modeles", "armures", "sol")


def B(x, y=None, z=None):
    if y is None:
        x, y, z = x
    return Vector((x, -z, y))


def G(v):
    return Vector((v[0], v[2], -v[1]))


# ----------------------------------------------------------------------------------------------------------- scène
def scene_base():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/modeles/humains/homme_vetu.glb"))
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and o.parent is None:
            bpy.data.objects.remove(o)
    return arm


def obj_heros(nom):
    """Maillage visible du héros (repère Godot -> Blender), sans poids : cible de collision."""
    v, f = [], []
    for l in open(os.path.join(HEROS, nom + ".obj")):
        t = l.split()
        if not t:
            continue
        if t[0] == "v":
            v.append(B(float(t[1]), float(t[2]), float(t[3])))
        elif t[0] == "f":
            f.append(tuple(int(q.split("/")[0]) - 1 for q in t[1:4]))
    return v, f


def bvh_de(noms_quaternius=(), noms_heros=(), filtre=None):
    """BVH sur des vêtements Quaternius (pose de repos) et des maillages du héros ; filtre(p_godot) garde les triangles."""
    V, F = [], []
    for nom in noms_quaternius:
        o = bpy.data.objects[nom]
        me = o.data
        off = len(V)
        V += [o.matrix_world @ v.co for v in me.vertices]
        for p in me.polygons:
            vs = list(p.vertices)
            for i in range(1, len(vs) - 1):
                F.append((vs[0] + off, vs[i] + off, vs[i + 1] + off))
    for nom in noms_heros:
        v, f = obj_heros(nom)
        off = len(V)
        V += v
        F += [(a + off, b + off, c + off) for (a, b, c) in f]
    if filtre is not None:
        F = [t for t in F if filtre(G((V[t[0]] + V[t[1]] + V[t[2]]) / 3.0))]
    return BVHTree.FromPolygons(V, F, epsilon=0.0)


def copie(nom_src, nom, garder=None):
    """Copie d'un vêtement Quaternius (poids d'os conservés) ; garder(centre_godot, normale_godot) filtre les faces."""
    src = bpy.data.objects[nom_src]
    me = src.data.copy()
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    o.matrix_world = src.matrix_world.copy()
    for vg in src.vertex_groups:
        if o.vertex_groups.get(vg.name) is None:
            o.vertex_groups.new(name=vg.name)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0015)
    if garder is not None:
        suppr = [f for f in bm.faces if not garder(G(f.calc_center_median()), G(f.normal))]
        bmesh.ops.delete(bm, geom=suppr, context='FACES')
    bm.to_mesh(me)
    bm.free()
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    me.materials.clear()
    return o


def poids(o):
    """Liste par sommet de {nom_os: poids}."""
    noms = {g.index: g.name for g in o.vertex_groups}
    return [{noms[g.group]: g.weight for g in v.groups if g.weight > 0.0} for v in o.data.vertices]


def ecrire_poids(o, pw):
    for g in list(o.vertex_groups):
        o.vertex_groups.remove(g)
    groupes = {}
    for i, d in enumerate(pw):
        for nom, w in d.items():
            if nom not in groupes:
                groupes[nom] = o.vertex_groups.new(name=nom)
            groupes[nom].add([i], w, 'REPLACE')


def bm_vers_objet(bm, nom):
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def lisser_normales(o):
    for p in o.data.polygons:
        p.use_smooth = True


# ----------------------------------------------------------------------------------------------------------- ajustement
def ajuster(o, bvh, jeu, portee=0.12, lissage=3, force=0.5, deplacer=None):
    """Place chaque sommet à `jeu(p_godot)` m AU-DESSUS de la surface la plus extérieure de `bvh` le long de sa normale
    (lancer depuis l'extérieur vers l'intérieur) ; sans touche, décalage simple. Puis lissage laplacien (composante tangentielle
    + normale, sans repasser sous la surface)."""
    me = o.data
    me.update()
    n = len(me.vertices)
    for it in range(lissage + 1):
        me.update()
        nr = [v.normal.copy() for v in me.vertices]
        co = [v.co.copy() for v in me.vertices]
        cible = []
        for i in range(n):
            p, nn = co[i], nr[i]
            d = jeu(G(p))
            dep = p + nn * portee
            hit = bvh.ray_cast(dep, -nn, portee * 2.0)
            if hit[0] is not None:
                q = hit[0] + nn * d
                # jamais plus près du corps que la surface + jeu
                s = (q - p).dot(nn)
                cible.append(p + nn * max(s, 0.0) if it > 0 else q)
            else:
                cible.append(p + nn * (d if it == 0 else 0.0))
        for i in range(n):
            me.vertices[i].co = cible[i]
        if it < lissage:
            lisser(o, 1, force)
    if deplacer is not None:
        for v in me.vertices:
            v.co = B(deplacer(G(v.co), G(v.normal)))


def lisser(o, iterations=1, force=0.5, garder=None):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    for _ in range(iterations):
        nouv = {}
        for v in bm.verts:
            if garder is not None and not garder(G(v.co)):
                continue
            if v.is_boundary:
                vois = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            else:
                vois = [e.other_vert(v) for e in v.link_edges]
            if not vois:
                continue
            m = sum((u.co for u in vois), Vector()) / len(vois)
            nouv[v] = v.co.lerp(m, force)
        for v, c in nouv.items():
            v.co = c
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


def decimer(o, tris):
    me = o.data
    nb = sum(len(p.vertices) - 2 for p in me.polygons)
    if nb <= tris:
        return
    m = o.modifiers.new("dec", 'DECIMATE')
    m.ratio = tris / nb
    m.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = o
    with bpy.context.temp_override(object=o):
        bpy.ops.object.modifier_apply(modifier=m.name)


def nb_tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# ----------------------------------------------------------------------------------------------------------- ajouts
def anneau(bm, centres, rayons, n, partie, ferme=True, arc=None, couvercle=False):
    """Tube de sections (centres[k] : (centre_godot, axe_godot, ref_godot) ; rayons[k](theta) -> rayon). arc=(t0, t1) : section
    ouverte (theta de t0 à t1). Retourne la grille de BMVert. Coordonnées en Godot, converties."""
    part = couche_partie(bm)
    lignes = []
    for k, (c, axe, ref) in enumerate(centres):
        axe = Vector(axe).normalized()
        ref = (Vector(ref) - axe * axe.dot(Vector(ref))).normalized()
        ref2 = axe.cross(ref)
        ligne = []
        m = n if ferme else n + 1
        for j in range(m):
            th = (j / n) * 2 * math.pi if arc is None else arc[0] + (arc[1] - arc[0]) * j / n
            r = rayons[k](th) if callable(rayons[k]) else rayons[k]
            p = Vector(c) + (ref * math.cos(th) + ref2 * math.sin(th)) * r
            ligne.append(bm.verts.new(B(p)))
        lignes.append(ligne)
    faces = []
    for k in range(len(lignes) - 1):
        a, b = lignes[k], lignes[k + 1]
        m = len(a)
        for j in range(m if ferme else m - 1):
            j2 = (j + 1) % m
            f = bm.faces.new((a[j], a[j2], b[j2], b[j]))
            faces.append(f)
    for f in faces:
        f[part] = partie
    return lignes


def couche_partie(bm):
    return bm.faces.layers.int.get("partie") or bm.faces.layers.int.new("partie")


def rayon_sur(bvh, c, axe, ref, jeu, rmax=0.35):
    """Fonction theta -> rayon : distance de l'axe à la surface la plus extérieure de `bvh` (lancer de l'extérieur), + jeu."""
    axe = Vector(axe).normalized()
    ref = (Vector(ref) - axe * axe.dot(Vector(ref))).normalized()
    ref2 = axe.cross(ref)
    cb = B(c)

    def f(th):
        d = ref * math.cos(th) + ref2 * math.sin(th)
        db = B(d)
        hit = bvh.ray_cast(cb + db * rmax, -db, rmax)
        if hit[0] is None:
            return rmax * 0.3 + (jeu(th) if callable(jeu) else jeu)
        return (hit[0] - cb).length + (jeu(th) if callable(jeu) else jeu)
    return f


def poids_proches(o, src, k=4, filtre=None):
    """Poids de chaque sommet de `o` = moyenne (inverse distance) des k sommets les plus proches de `src` (repos)."""
    pw_src = poids(src)
    idx = [i for i, v in enumerate(src.data.vertices) if filtre is None or filtre(G(src.matrix_world @ v.co))]
    kd = KDTree(len(idx))
    for j, i in enumerate(idx):
        kd.insert(src.matrix_world @ src.data.vertices[i].co, j)
    kd.balance()
    res = []
    for v in o.data.vertices:
        d = {}
        tot = 0.0
        for (co, j, dist) in kd.find_n(o.matrix_world @ v.co, k):
            w = 1.0 / max(dist, 1e-4) ** 2
            tot += w
            for nom, x in pw_src[idx[j]].items():
                d[nom] = d.get(nom, 0.0) + x * w
        res.append({nom: x / tot for nom, x in d.items()})
    return res


def normaliser(pw, garder=4):
    res = []
    for d in pw:
        l = sorted(d.items(), key=lambda t: -t[1])[:garder]
        s = sum(x for _, x in l) or 1.0
        res.append({n: x / s for n, x in l if x / s > 0.01})
    return res


def lisser_poids(o, pw, iterations=2, force=0.5):
    me = o.data
    vois = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        vois[a].append(b)
        vois[b].append(a)
    for _ in range(iterations):
        nouv = []
        for i, d in enumerate(pw):
            if not vois[i]:
                nouv.append(d)
                continue
            m = {}
            for j in vois[i]:
                for n_, x in pw[j].items():
                    m[n_] = m.get(n_, 0.0) + x / len(vois[i])
            r = {}
            for n_ in set(d) | set(m):
                r[n_] = d.get(n_, 0.0) * (1 - force) + m.get(n_, 0.0) * force
            nouv.append(r)
        pw = nouv
    return pw


def joindre(objs, nom):
    """Fusionne des objets (poids d'os conservés par nom de groupe)."""
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = objs[0]
    o.name = nom
    o.data.name = nom
    return o


# ----------------------------------------------------------------------------------------------------------- texture cuite
def _h3(ix, iy, iz, g):
    n = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (g * 2654435761)
    n = (n ^ (n >> 13)) * 1274126177
    n = n ^ (n >> 16)
    return (n & 0xffff) / 65535.0


def bruit(p, echelle, g=0):
    """Bruit de valeur 3D lissé (numpy, p : (N, 3) en m), 0..1."""
    q = p * echelle
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3 - 2 * f)
    res = np.zeros(len(p))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                ix, iy, iz = i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz
                n = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (g * 2654435761)
                n = (n ^ (n >> 13)) * 1274126177
                n = (n ^ (n >> 16)) & 0xffff
                h = n / 65535.0
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                res += h * w
    return res


def fbm(p, echelle, g=0, octaves=3):
    s, a, t = 0.0, 0.5, 0.0
    for o in range(octaves):
        s = s + bruit(p, echelle * (2 ** o), g + o) * a
        t += a
        a *= 0.5
    return s / t


def rampe(pal, k):
    """Couleur dans une palette (liste de (r, g, b) 0..1) par k 0..1, interpolée (32 bits : pas d'aplats « camouflage »)."""
    pal = np.array(pal)
    t = np.clip(k, 0.0, 0.999) * (len(pal) - 1)
    i = np.floor(t).astype(int)
    f = (t - i)[:, None]
    j = np.minimum(i + 1, len(pal) - 1)
    return pal[i] * (1 - f) + pal[j] * f


def hexa(*cs):
    return [tuple(int(c[i:i + 2], 16) / 255.0 for i in (1, 3, 5)) for c in cs]


def uv_auto(o, marge=0.02):
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=marge, area_weight=1.0, scale_to_bounds=True)
    bpy.ops.uv.pack_islands(margin=marge, rotate=True)
    bpy.ops.object.mode_set(mode='OBJECT')


def distance_bords(o, rmax=0.08):
    """Par sommet : distance (m) au bord libre le plus proche (arêtes à une seule face), bornée à rmax."""
    me = o.data
    nb = {}
    for p in me.polygons:
        for k in p.edge_keys:
            nb[k] = nb.get(k, 0) + 1
    bords = {v for k, c in nb.items() if c == 1 for v in k}
    if not bords:
        return [rmax] * len(me.vertices)
    kd = KDTree(len(bords))
    for i, v in enumerate(bords):
        kd.insert(me.vertices[v].co, i)
    kd.balance()
    return [min(kd.find(v.co)[2], rmax) for v in me.vertices]


def occlusion(o, rayons=14, portee=0.07):
    """Occlusion ambiante par sommet (0 = creux fermé, 1 = à l'air) : rayons dans l'hémisphère de la normale contre la pièce
    elle-même (sous la ceinture, sous les lames, entre les plaques, plis) : la salissure se dépose dans les creux."""
    import random
    me = o.data
    me.update()
    bvh = BVHTree.FromPolygons([v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons], epsilon=0.0)
    rnd = random.Random(7)
    dirs = []
    while len(dirs) < rayons:
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
        if 0.1 < d.length <= 1.0:
            dirs.append(d.normalized())
    res = []
    for v in me.vertices:
        n = v.normal
        libres = 0
        tot = 0
        for d in dirs:
            if d.dot(n) < 0:
                d = -d
            if d.dot(n) < 0.15:
                continue
            tot += 1
            hit = bvh.ray_cast(v.co + n * 0.002, d, portee)
            if hit[0] is None:
                libres += 1
        res.append(libres / max(tot, 1))
    return res


def cuire(o, matiere, taille=128, nom_img=None, tableau=False):
    """Rastérise chaque triangle dans ses UV et appelle matiere(P_godot (N,3), N_godot (N,3), partie (N,), bord (N,)) -> RGBA (N,4)
    (bord = distance au bord libre le plus proche, m). Débord de 3 texels autour des îles. Retourne l'image Blender (empaquetée)."""
    me = o.data
    me.calc_loop_triangles()
    dist = np.array(distance_bords(o))
    ao_v = np.array(occlusion(o))
    uvl = me.uv_layers.active.data
    attr = me.attributes.get("partie")
    W, H = (taille, taille) if isinstance(taille, int) else taille
    Ao = np.ones((H, W))
    P = np.zeros((H, W, 3))
    Nn = np.zeros((H, W, 3))
    Pa = np.zeros((H, W), dtype=np.int64)
    Bd = np.zeros((H, W))
    rempli = np.zeros((H, W), dtype=bool)
    for t in me.loop_triangles:
        uv = np.array([uvl[l].uv[:] for l in t.loops]) * [W, H]
        ps = np.array([G(me.vertices[v].co)[:] for v in t.vertices])
        ns = np.array([G(me.vertices[v].normal)[:] for v in t.vertices]) if t.use_smooth else np.array([G(t.normal)[:]] * 3)
        pa = attr.data[t.polygon_index].value if attr is not None else 0
        bs = dist[list(t.vertices)]
        aos = ao_v[list(t.vertices)]
        x0, y0 = np.floor(uv.min(0)).astype(int)
        x1, y1 = np.ceil(uv.max(0)).astype(int)
        x0, y0 = max(x0 - 1, 0), max(y0 - 1, 0)
        x1, y1 = min(x1 + 1, W), min(y1 + 1, H)
        if x1 <= x0 or y1 <= y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        a, b, c = uv
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        l1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        l2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        l3 = 1 - l1 - l2
        dedans = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not dedans.any():
            continue
        yy, xx = (ys[dedans] - 0.5).astype(int), (xs[dedans] - 0.5).astype(int)
        L = np.stack([l1[dedans], l2[dedans], l3[dedans]], 1).clip(0, 1)
        L /= L.sum(1, keepdims=True)
        P[yy, xx] = L @ ps
        Nn[yy, xx] = L @ ns
        Pa[yy, xx] = pa
        Bd[yy, xx] = L @ bs
        Ao[yy, xx] = L @ aos
        rempli[yy, xx] = True
    # débord : chaque texel vide prend la valeur d'un voisin rempli (3 passes)
    for _ in range(3):
        vide = ~rempli
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.roll(np.roll(rempli, dy, 0), dx, 1)
            m = vide & src
            P[m] = np.roll(np.roll(P, dy, 0), dx, 1)[m]
            Nn[m] = np.roll(np.roll(Nn, dy, 0), dx, 1)[m]
            Pa[m] = np.roll(np.roll(Pa, dy, 0), dx, 1)[m]
            Bd[m] = np.roll(np.roll(Bd, dy, 0), dx, 1)[m]
            Ao[m] = np.roll(np.roll(Ao, dy, 0), dx, 1)[m]
            rempli = rempli | m
            vide = ~rempli
    flat = rempli.reshape(-1)
    # distance au bord libre calculée PAR TEXEL (points échantillonnés tous les 4 mm sur les arêtes de bord, en 3D) : liserés nets
    # même sur les bandes étroites (l'interpolation par sommet y faisait des taches triangulaires)
    nb = {}
    for p_ in me.polygons:
        for k in p_.edge_keys:
            nb[k] = nb.get(k, 0) + 1
    ech = []
    for (a_, b_), c_ in nb.items():
        if c_ != 1:
            continue
        pa_, pb_ = G(me.vertices[a_].co), G(me.vertices[b_].co)
        n_ = max(1, int((pb_ - pa_).length / 0.004))
        for i_ in range(n_ + 1):
            ech.append(pa_.lerp(pb_, i_ / n_))
    if ech:
        kd = KDTree(len(ech))
        for i_, q_ in enumerate(ech):
            kd.insert(q_, i_)
        kd.balance()
        Pf = P.reshape(-1, 3)
        Bf = Bd.reshape(-1)
        for i_ in np.nonzero(flat)[0]:
            Bf[i_] = min(kd.find(Pf[i_])[2], 0.08)
    rgba = np.zeros((H * W, 4))
    rgba[:, 3] = 1.0
    nn = Nn.reshape(-1, 3)
    nn = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-6)
    rgba[flat] = matiere(P.reshape(-1, 3)[flat], nn[flat], Pa.reshape(-1)[flat], Bd.reshape(-1)[flat])
    # salissure et ombre dans les creux (occlusion), brillance éteinte dans la crasse
    ao = np.clip(Ao.reshape(-1)[flat], 0.0, 1.0)
    k = 0.50 + 0.50 * ao ** 1.4
    rgba[flat, :3] *= k[:, None]
    rgba[flat, :3] = rgba[flat, :3] * (1 - 0.25 * (1 - ao))[:, None] + np.array([0.10, 0.08, 0.06]) * (0.25 * (1 - ao))[:, None]
    rgba[flat, 3] *= 0.4 + 0.6 * ao
    if tableau:
        return rgba.reshape(H, W, 4)
    img = bpy.data.images.new(nom_img or (o.name + "_tex"), W, H, alpha=True)
    img.pixels = rgba.reshape(-1).tolist()   # ligne 0 = bas de l'image = v 0 : même convention que les UV Blender
    dossier = os.path.join(ROOT, "sources_blender", "armures", "textures")
    os.makedirs(dossier, exist_ok=True)
    img.filepath_raw = os.path.join(dossier, (nom_img or o.name) + ".png")
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img


def image_atlas(nom, atlas):
    """Image Blender empaquetée depuis un tableau (H, W, 4) (ligne 0 = bas), copie dans sources_blender/armures/textures/."""
    H, W = atlas.shape[:2]
    img = bpy.data.images.new(nom, W, H, alpha=True)
    img.pixels = atlas.reshape(-1).tolist()
    dossier = os.path.join(ROOT, "sources_blender", "armures", "textures")
    os.makedirs(dossier, exist_ok=True)
    img.filepath_raw = os.path.join(dossier, nom + ".png")
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img


def materiau(nom, img):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.8
    return m


# ----------------------------------------------------------------------------------------------------------- export
def exporter(o, arm, ident, sol_transformer=None):
    """Exporte <id>.glb porté (armature + maillage skinné) et, si sol_transformer, la pose au sol statique."""
    os.makedirs(PORTE, exist_ok=True)
    os.makedirs(SOL, exist_ok=True)
    # groupes de sommets qui ne sont pas des os (restes d'outils) : retirés, poids renormalisés
    os_ = {b.name for b in arm.data.bones}
    pw = [{k: w for k, w in d.items() if k in os_} for d in poids(o)]
    etrangers = [g.name for g in o.vertex_groups if g.name not in os_]
    if etrangers:
        print("  groupes retirés (pas des os) :", etrangers)
    pw = normaliser(pw)
    vides = [i for i, d in enumerate(pw) if not d]
    assert not vides, "%s : %d sommets sans poids d'os" % (ident, len(vides))
    ecrire_poids(o, pw)
    o.parent = arm
    o.matrix_parent_inverse = arm.matrix_world.inverted()
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    mod = o.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=os.path.join(PORTE, ident + ".glb"), export_format='GLB', use_selection=True,
                              export_skins=True, export_animations=False, export_yup=True, export_apply=False,
                              export_materials='EXPORT', export_image_format='AUTO', export_vertex_color='NONE')
    if sol_transformer is None:
        return
    me = o.data.copy()
    s = bpy.data.objects.new(ident + "_sol", me)
    bpy.context.scene.collection.objects.link(s)
    s.matrix_world = Matrix()
    for g in list(s.vertex_groups):
        s.vertex_groups.remove(g)
    sol_transformer(s)
    bpy.ops.object.select_all(action='DESELECT')
    s.select_set(True)
    bpy.context.view_layer.objects.active = s
    bpy.ops.export_scene.gltf(filepath=os.path.join(SOL, ident + ".glb"), export_format='GLB', use_selection=True,
                              export_skins=False, export_animations=False, export_yup=True,
                              export_materials='EXPORT', export_image_format='AUTO', export_vertex_color='NONE')
    bpy.data.objects.remove(s)


def poser_au_sol(s, parties):
    """parties : liste de (filtre(p_godot) -> bool, Matrix godot 4x4 appliquée aux sommets concernés). Puis pivot au sol (y min = 0),
    centré en x/z."""
    me = s.data
    for v in me.vertices:
        p = G(v.co)
        for filtre, M in parties:
            if filtre(p):
                p = M @ p
                break
        v.co = B(p)
    ys = [G(v.co).y for v in me.vertices]
    xs = [G(v.co).x for v in me.vertices]
    zs = [G(v.co).z for v in me.vertices]
    d = Vector(((min(xs) + max(xs)) / 2, min(ys), (min(zs) + max(zs)) / 2))
    for v in me.vertices:
        v.co = B(G(v.co) - d)
    me.update()


def apercu(objs, dossier, cible_godot=(0, 1.0, 0), taille=2.0, prefixe=""):
    """Rendu Workbench (texture) face / profil / dos / 3-4 pour contrôle rapide."""
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'TEXTURE'
    sc.display.shading.show_backface_culling = True     # faces retournées = trous (comme en jeu)
    sc.render.resolution_x = 600
    sc.render.resolution_y = 600
    cam = bpy.data.objects.get("cam_apercu")
    if cam is None:
        cam = bpy.data.objects.new("cam_apercu", bpy.data.cameras.new("cam_apercu"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = taille
    cible = B(cible_godot)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o not in objs
    for nom, d in [("face", Vector((0, -1, 0))), ("profil", Vector((1, 0, 0))), ("dos", Vector((0, 1, 0))), ("tq", Vector((0.7, -0.7, 0.3)))]:
        cam.location = cible + d.normalized() * 5
        cam.rotation_euler = (cible - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(dossier, prefixe + nom + ".png")
        bpy.ops.render.render(write_still=True)
