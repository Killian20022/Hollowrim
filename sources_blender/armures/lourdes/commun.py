# Armures lourdes portées (agent Y, branche rpg/armures_lourdes) : outils communs Blender.
#  - charge le héros exporté par Godot (outils/exporter_heros_armures.gd -> ../heros_reference.glb : Skeleton3D, pose de repos T,
#    pièces peau d'os) ;
#  - « tubes ajustés » : chaque anneau est mesuré au rayon sur le corps réel (lancer de rayons de l'extérieur vers l'axe, seulement sur
#    les faces dont les poids appartiennent aux os de la pièce), lissé, puis décalé vers l'extérieur ; coques sphériques (casques) ;
#  - peau d'os par transfert des poids du corps le plus proche (ou rigide), limite 4 os ;
#  - textures peintes en Python (128², palettes de matières usées, bruit, rivets, rayures, crasse), UV propres (pas de camouflage) ;
#  - export glb : armature + pièce, matériaux nommés par matière (fer, acier, maille, cuir, fourrure, laine, or, givre, braise).
# Repère Blender (import glTF du héros) : Z haut, -Y devant (Godot +Z), +X = gauche du personnage.
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.normpath(os.path.join(ICI, "..", "..", ".."))
REF = os.path.join(ICI, "..", "heros_reference.glb")
PORTE = os.path.join(DEPOT, "assets", "modeles", "armures", "porte")
SOL = os.path.join(DEPOT, "assets", "modeles", "armures", "sol")
TAU = math.tau

# ------------------------------------------------------------------------------------------------ référence
class Ref:
    pass

def charger_reference():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=REF)
    r = Ref()
    r.arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    if r.arm.animation_data:
        r.arm.animation_data.action = None
    for pb in r.arm.pose.bones:
        pb.matrix_basis.identity()
    r.corps = {o.name: o for o in bpy.data.objects if o.type == "MESH" and o.parent == r.arm}
    for o in bpy.data.objects:
        if o.type == "MESH" and o.parent != r.arm:
            o.hide_render = True
            o.hide_set(True)
    r.os = {b.name: (r.arm.matrix_world @ b.head_local) for b in r.arm.data.bones}
    r.queue = {b.name: (r.arm.matrix_world @ b.tail_local) for b in r.arm.data.bones}
    return r

def poids_os(obj, vi, noms):
    """Somme des poids du sommet vi pour les groupes nommés."""
    s = 0.0
    v = obj.data.vertices[vi]
    for g in v.groups:
        if obj.vertex_groups[g.group].name in noms:
            s += g.weight
    return s

def bvh(r, pieces, os_noms=None, seuil=0.5, garder=None):
    """BVH des faces des pièces du corps (repère monde au repos) ; os_noms : faces dont chaque sommet a >= seuil de poids sur ces os ;
    garder(centre) : filtre géométrique."""
    verts, faces = [], []
    for nom in pieces:
        o = r.corps.get(nom)
        if o is None:
            continue
        mw = o.matrix_world
        base = len(verts)
        ok = None
        if os_noms:
            ok = [poids_os(o, i, os_noms) >= seuil for i in range(len(o.data.vertices))]
        for v in o.data.vertices:
            verts.append(mw @ v.co)
        for p in o.data.polygons:
            if ok is not None and not all(ok[i] for i in p.vertices):
                continue
            if garder is not None and not garder(sum((verts[base + i] for i in p.vertices), Vector()) / len(p.vertices)):
                continue
            faces.append([base + i for i in p.vertices])
    return BVHTree.FromPolygons(verts, faces)

# ------------------------------------------------------------------------------------------------ mesures
def repere(axe):
    """Deux vecteurs perpendiculaires à axe (u « devant » quand possible)."""
    axe = axe.normalized()
    ref = Vector((0, -1, 0)) if abs(axe.y) < 0.9 else Vector((0, 0, 1))
    u = (ref - axe * ref.dot(axe)).normalized()
    w = axe.cross(u).normalized()
    return u, w

def mesurer_anneau(arbre, centre, axe, n, r_loin=0.6, r_defaut=0.1, angles=None):
    """Rayon extérieur du corps autour de centre (perpendiculaire à axe) pour n angles (0 = devant), rayon de l'extérieur vers l'axe."""
    u, w = repere(axe)
    res = []
    angs = angles if angles is not None else [TAU * i / n for i in range(n)]
    for a in angs:
        d = u * math.cos(a) + w * math.sin(a)
        o = centre + d * r_loin
        hit = arbre.ray_cast(o, -d, r_loin)
        res.append(r_loin - hit[3] if hit[0] is not None else None)
    # trous (aisselles…) : interpolation circulaire des voisins mesurés
    if all(x is None for x in res):
        return [None] * len(res)
    m = len(res)
    out = list(res)
    for i in range(m):
        if res[i] is None:
            a = b = None
            for k in range(1, m):
                if a is None and res[(i - k) % m] is not None:
                    a = (k, res[(i - k) % m])
                if b is None and res[(i + k) % m] is not None:
                    b = (k, res[(i + k) % m])
            out[i] = (a[1] * b[0] + b[1] * a[0]) / (a[0] + b[0])
    return out

def lisser_grille(R, passes=2, circulaire=True, k=0.5):
    for _ in range(passes):
        N = []
        for j, row in enumerate(R):
            m = len(row)
            nr = []
            for i in range(m):
                g = row[(i - 1) % m] if circulaire or i > 0 else row[i]
                d = row[(i + 1) % m] if circulaire or i < m - 1 else row[i]
                h = R[j - 1][i] if j > 0 else row[i]
                b = R[j + 1][i] if j < len(R) - 1 else row[i]
                nr.append(row[i] * (1 - k) + k * (g + d + h + b) / 4.0)
            N.append(nr)
        R = N
    return R

def max_grille(R, passes=1):
    """Dilatation : chaque rayon >= max de ses voisins d'angle (enveloppe convexe locale : pas de creux qui collent aux plis)."""
    for _ in range(passes):
        R = [[max(row[(i - 1) % len(row)], row[i], row[(i + 1) % len(row)]) for i in range(len(row))] for row in R]
    return R

# ------------------------------------------------------------------------------------------------ maillage
class Piece:
    """Accumulateur de géométrie : sommets, faces (avec matériau), UV par coin, couleur de sommet (occlusion)."""
    def __init__(self, nom):
        self.nom = nom
        self.v = []
        self.f = []       # (indices, mat, uvs)
        self.ao = []      # par sommet
        self.mats = []

    def mat(self, nom):
        if nom not in self.mats:
            self.mats.append(nom)
        return self.mats.index(nom)

    def sommet(self, p, ao=1.0):
        self.v.append(Vector(p))
        self.ao.append(ao)
        return len(self.v) - 1

    def face(self, idx, mat, uvs):
        self.f.append((list(idx), self.mat(mat), [tuple(x) for x in uvs]))

    def grille(self, P, mat, uv_rect, fermer=True, ao=None, inverser=False, u_tours=1.0):
        """P[j][i] : anneaux (j) de points (i). uv_rect = (u0, v0, u1, v1) dans l'atlas ; fermer : anneau bouclé."""
        nj, ni = len(P), len(P[0])
        ids = [[self.sommet(P[j][i], ao[j][i] if ao else 1.0) for i in range(ni)] for j in range(nj)]
        u0, v0, u1, v1 = uv_rect
        nci = ni if fermer else ni - 1
        for j in range(nj - 1):
            for i in range(nci):
                i2 = (i + 1) % ni
                a, b, c, d = ids[j][i], ids[j][i2], ids[j + 1][i2], ids[j + 1][i]
                ua = u0 + (u1 - u0) * (i / nci) * u_tours
                ub = u0 + (u1 - u0) * ((i + 1) / nci) * u_tours
                va = v0 + (v1 - v0) * (j / (nj - 1))
                vb = v0 + (v1 - v0) * ((j + 1) / (nj - 1))
                q = [a, b, c, d]
                uv = [(ua, va), (ub, va), (ub, vb), (ua, vb)]
                if inverser:
                    q.reverse(); uv.reverse()
                self.face(q, mat, uv)
        return ids

    def objet(self, collection=None):
        me = bpy.data.meshes.new(self.nom)
        bm = bmesh.new()
        bv = [bm.verts.new(p) for p in self.v]
        bm.verts.ensure_lookup_table()
        uvl = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.float_color.new("Col")
        for idx, m, uvs in self.f:
            try:
                f = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            f.material_index = m
            for lp, uv, i in zip(f.loops, uvs, idx):
                lp[uvl].uv = uv
                a = self.ao[i]
                lp[col] = (a, a, a, 1.0)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(self.nom, me)
        (collection or bpy.context.scene.collection).objects.link(ob)
        for p in me.polygons:
            p.use_smooth = True
        return ob

def orienter_dehors(ob, centre_fn):
    """Normales vers l'extérieur : chaque face retournée si sa normale pointe vers centre_fn(centre_face)."""
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    flip = [f for f in bm.faces if f.normal.dot(f.calc_center_median() - centre_fn(f.calc_center_median())) < 0]
    bmesh.ops.reverse_faces(bm, faces=flip)
    bm.to_mesh(ob.data); bm.free()

# ------------------------------------------------------------------------------------------------ tubes ajustés
def tube(arbre, A, B, ts, n, decalage, r_min=0.02, r_loin=0.6, lisse=2, dilate=1, angles=None, axe=None, a0=math.pi):
    """Anneaux ajustés autour du segment A->B aux fractions ts ; decalage(j, i, angle) -> m ajoutés au rayon mesuré.
    Retourne (P, R, repere) : P[j][i] points, R rayons finaux."""
    axe = (axe or (B - A)).normalized()
    R = []
    # anneau fermé : couture derrière (a0 = pi), devant au milieu de la texture (u = 0,5)
    angs = angles if angles is not None else [a0 + TAU * i / n for i in range(n)]
    for t in ts:
        c = A.lerp(B, t)
        R.append(mesurer_anneau(arbre, c, axe, n, r_loin, angles=angs))
    # anneaux sans mesure (au-delà du corps) : copie de l'anneau mesuré le plus proche
    ok = [j for j, row in enumerate(R) if row[0] is not None]
    for j in range(len(R)):
        if R[j][0] is None:
            src = min(ok, key=lambda k: abs(k - j)) if ok else None
            R[j] = list(R[src]) if src is not None else [0.06] * len(angs)
        R[j] = [max(x, r_min) for x in R[j]]
    if dilate:
        R = max_grille(R, dilate)
    R = lisser_grille(R, lisse, circulaire=angles is None)
    u, w = repere(axe)
    P = []
    for j, t in enumerate(ts):
        c = A.lerp(B, t)
        row = []
        for i, a in enumerate(angs):
            R[j][i] += decalage(j, i, a)
            row.append(c + (u * math.cos(a) + w * math.sin(a)) * R[j][i])
        P.append(row)
    return P, R, (u, w, axe)

def coque(arbre, centre, lats, n, decalage, r_loin=0.5, lisse=2, axe_haut=Vector((0, 0, 1)), devant=Vector((0, -1, 0))):
    """Coque sphérique : lats = latitudes (rad, 0 = horizon, pi/2 = sommet) ; points depuis le centre vers l'extérieur.
    decalage(j, i, lat, lon) -> m. Le sommet est un anneau minuscule (pas de pôle dégénéré)."""
    w = axe_haut.cross(devant).normalized()   # gauche ? (devant x haut)
    R = []
    dirs = []
    for la in lats:
        row = []; drow = []
        for i in range(n):
            lo = TAU * i / n
            d = (devant * math.cos(lo) + (-w) * math.sin(lo)) * math.cos(la) + axe_haut * math.sin(la)
            d.normalize()
            o = centre + d * r_loin
            hit = arbre.ray_cast(o, -d, r_loin)
            row.append(r_loin - hit[3] if hit[0] is not None else None)
            drow.append(d)
        R.append(row); dirs.append(drow)
    # trous : moyenne de l'anneau
    for j, row in enumerate(R):
        ok = [x for x in row if x is not None]
        moy = sum(ok) / len(ok) if ok else 0.1
        R[j] = [x if x is not None else moy for x in row]
    R = max_grille(R, 1)
    R = lisser_grille(R, lisse)
    P = []
    for j, la in enumerate(lats):
        row = []
        for i in range(n):
            lo = TAU * i / n
            R[j][i] += decalage(j, i, la, lo)
            row.append(centre + dirs[j][i] * R[j][i])
        P.append(row)
    return P, R, dirs

def rebord(P_bord, centre_fn, epaisseur, dehors=True):
    """Anneau décalé vers l'axe (épaisseur visible du bord) : liste de points."""
    out = []
    for p in P_bord:
        c = centre_fn(p)
        d = (p - c)
        d.normalize()
        out.append(p - d * epaisseur if dehors else p + d * epaisseur)
    return out

def degager(ob, r, pieces, marge, filtre=None, os_noms=None, passes=2):
    """Pousse dehors les sommets de ob (repère monde au repos) qui sont sous la surface des pièces du corps ou à moins de marge :
    sommet ramené à point_proche + normale * marge, puis le déplacement est lissé (pas de bosses)."""
    arbre = bvh(r, pieces, os_noms, 0.5)
    me = ob.data
    dep = [Vector() for _ in me.vertices]
    for v in me.vertices:
        p = ob.matrix_world @ v.co
        if filtre and not filtre(p):
            continue
        loc, nrm, _, dist = arbre.find_nearest(p, 0.2)
        if loc is None:
            continue
        sgn = (p - loc).dot(nrm)
        if sgn < marge:
            dep[v.index] = nrm * (marge - sgn)
    voisins = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        voisins[a].append(b); voisins[b].append(a)
    for _ in range(passes):
        dep = [max([dep[i]] + [dep[j] * 0.7 for j in voisins[i]], key=lambda d: d.length) for i in range(len(dep))]
    n = 0
    for v in me.vertices:
        if dep[v.index].length > 0:
            v.co += dep[v.index]
            n += 1
    print("DEGAGER", ob.name, n, "sommets poussés")

# ------------------------------------------------------------------------------------------------ peau d'os
def peau_transfert(ob, r, sources, lisser=1, os_permis=None, os_force=None, cote_strict=False):
    """Poids transférés depuis les pièces du corps (face la plus proche, interpolée), limités à 4, normalisés.
    os_permis : seuls ces os gardent un poids (les autres sont reversés au plus proche permis) ; os_force : {os: poids min}."""
    src = []
    for nom in sources:
        o = r.corps.get(nom)
        if o is None:
            continue
        c = o.copy(); c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        src.append(c)
    bpy.ops.object.select_all(action="DESELECT")
    for c in src:
        c.select_set(True)
    bpy.context.view_layer.objects.active = src[0]
    if len(src) > 1:
        bpy.ops.object.join()
    s = bpy.context.view_layer.objects.active
    # groupes de la cible = tous les os
    for b in r.arm.data.bones:
        if b.name not in ob.vertex_groups:
            ob.vertex_groups.new(name=b.name)
    md = ob.modifiers.new("transfert", "DATA_TRANSFER")
    md.object = s
    md.use_vert_data = True
    md.data_types_verts = {"VGROUP_WEIGHTS"}
    md.vert_mapping = "POLYINTERP_NEAREST"
    md.layers_vgroup_select_src = "ALL"
    md.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.data.objects.remove(s, do_unlink=True)
    nettoyer_poids(ob, lisser, os_permis, os_force, cote_strict)

def peau_rigide(ob, r, os_nom):
    for b in r.arm.data.bones:
        if b.name not in ob.vertex_groups:
            ob.vertex_groups.new(name=b.name)
    ob.vertex_groups[os_nom].add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")

def peau_fonction(ob, r, fn):
    """fn(position monde) -> {os: poids}."""
    for b in r.arm.data.bones:
        if b.name not in ob.vertex_groups:
            ob.vertex_groups.new(name=b.name)
    for v in ob.data.vertices:
        for k, w in fn(ob.matrix_world @ v.co).items():
            if w > 0:
                ob.vertex_groups[k].add([v.index], w, "ADD")
    nettoyer_poids(ob, 0)

def nettoyer_poids(ob, lisser=1, os_permis=None, os_force=None, cote_strict=False):
    """cote_strict : un sommet à gauche (x > 0) ne garde que les os _l (et inversement) : l'intérieur d'une botte décalée vers l'autre
    jambe ne prend pas les poids de l'autre jambe (sinon il s'étire vers elle en marchant)."""
    me = ob.data
    noms = [g.name for g in ob.vertex_groups]
    W = [{noms[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in me.vertices]
    if cote_strict:
        for v, d in zip(me.vertices, W):
            autre = "_r" if (ob.matrix_world @ v.co).x > 0 else "_l"
            for k in list(d):
                if k.endswith(autre):
                    d.pop(k)
    if os_permis:
        for d in W:
            for k in list(d):
                if k not in os_permis:
                    d.pop(k)
    if lisser:
        voisins = [[] for _ in me.vertices]
        for e in me.edges:
            a, b = e.vertices
            voisins[a].append(b); voisins[b].append(a)
        for _ in range(lisser):
            N = []
            for i, d in enumerate(W):
                acc = dict((k, w * 2.0) for k, w in d.items())
                for j in voisins[i]:
                    for k, w in W[j].items():
                        acc[k] = acc.get(k, 0.0) + w
                N.append(acc)
            W = N
    if cote_strict:
        for v, d in zip(me.vertices, W):
            autre = "_r" if (ob.matrix_world @ v.co).x > 0 else "_l"
            for k in list(d):
                if k.endswith(autre):
                    d.pop(k)
    for i, d in enumerate(W):
        if os_force:
            for k, w in os_force.items():
                d[k] = max(d.get(k, 0.0), w)
        it = sorted(d.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(w for _, w in it)
        if tot <= 0:
            continue
        for g in ob.vertex_groups:
            g.remove([i])
        for k, w in it:
            ob.vertex_groups[k].add([i], w / tot, "REPLACE")
    # groupes vides retirés (export plus léger) : gardés tous pour l'ordre des os ? non, l'export lie par nom
    for g in list(ob.vertex_groups):
        if not any(g.index in [x.group for x in v.groups] for v in me.vertices):
            ob.vertex_groups.remove(g)

def poids_transferes(ob, r, sources, os_permis=None, lisser=1):
    """Poids transférés (sans toucher ob) : liste de {os: poids} par sommet."""
    c = ob.copy(); c.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(c)
    c.vertex_groups.clear()
    peau_transfert(c, r, sources, lisser=lisser, os_permis=os_permis)
    noms = {g.index: g.name for g in c.vertex_groups}
    W = [{noms[g.group]: g.weight for g in v.groups} for v in c.data.vertices]
    bpy.data.objects.remove(c, do_unlink=True)
    return W

def poids_fondus(ob, W_haut, W_bas, z_bas, z_haut):
    """Écrit dans ob le mélange W_bas (sous z_bas) -> W_haut (au-dessus de z_haut), limite 4 os."""
    ob.vertex_groups.clear()
    for v in ob.data.vertices:
        z = (ob.matrix_world @ v.co).z
        t = min(max((z - z_bas) / (z_haut - z_bas), 0.0), 1.0)
        t = t * t * (3 - 2 * t)
        d = {}
        for k, w in W_bas[v.index].items():
            d[k] = d.get(k, 0.0) + w * (1 - t)
        for k, w in W_haut[v.index].items():
            d[k] = d.get(k, 0.0) + w * t
        it = sorted(d.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(w for _, w in it)
        for k, w in it:
            if w <= 0:
                continue
            if k not in ob.vertex_groups:
                ob.vertex_groups.new(name=k)
            ob.vertex_groups[k].add([v.index], w / tot, "REPLACE")

def fondre_tete(ob, z_bas, z_haut):
    """Mélange les poids actuels (corps) avec la tête selon la hauteur : 0 sous z_bas, tout Head au-dessus de z_haut."""
    if "Head" not in ob.vertex_groups:
        ob.vertex_groups.new(name="Head")
    noms = {g.index: g.name for g in ob.vertex_groups}
    for v in ob.data.vertices:
        z = (ob.matrix_world @ v.co).z
        t = min(max((z - z_bas) / (z_haut - z_bas), 0.0), 1.0)
        t = t * t * (3 - 2 * t)
        d = {noms[g.group]: g.weight * (1 - t) for g in v.groups}
        d["Head"] = d.get("Head", 0.0) + t
        for g in list(v.groups):
            ob.vertex_groups[noms[g.group]].remove([v.index])
        it = sorted(d.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(w for _, w in it)
        for k, w in it:
            if w > 0:
                ob.vertex_groups[k].add([v.index], w / tot, "REPLACE")

def lier(ob, r):
    ob.parent = r.arm
    md = ob.modifiers.new("Armature", "ARMATURE")
    md.object = r.arm

# ------------------------------------------------------------------------------------------------ textures peintes
def _h(x, y, g):
    n = (x * 374761393 + y * 668265263 + g * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0

def bruit(x, y, echelle, g, w=128, h=128):
    """Bruit de valeur lissé, tuilable sur (w, h)."""
    fx, fy = x / echelle, y / echelle
    x0, y0 = int(math.floor(fx)), int(math.floor(fy))
    tx, ty = fx - x0, fy - y0
    tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)
    px, py = max(1, int(round(w / echelle))), max(1, int(round(h / echelle)))
    a = _h(x0 % px, y0 % py, g); b = _h((x0 + 1) % px, y0 % py, g)
    c = _h(x0 % px, (y0 + 1) % py, g); d = _h((x0 + 1) % px, (y0 + 1) % py, g)
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty

def fbm(x, y, g, w=128, h=128, oct=((16, 0.5), (8, 0.3), (4, 0.2))):
    return sum(bruit(x, y, e, g + k * 17, w, h) * a for k, (e, a) in enumerate(oct))

def hexa(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16) / 255.0, int(s[2:4], 16) / 255.0, int(s[4:6], 16) / 255.0)

def rampe(pal, t):
    cols = [hexa(c) for c in pal]
    t = min(max(t, 0.0), 1.0) * (len(cols) - 1)
    i = min(int(t), len(cols) - 2)
    f = t - i
    a, b = cols[i], cols[i + 1]
    return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f)

# palettes (neutres, usées : pas de teinte jouet ; reprises de EpeesLongues.ACIER_USE / FER_FORGE / CUIR_GRAIN…)
ACIER = ["#0b0c0e", "#15171a", "#202328", "#2d3137", "#3c4148", "#4e545b", "#62686f", "#797f85", "#93989d", "#b0b4b7", "#d0d3d4"]
FER = ["#0c0d0f", "#141619", "#1d2024", "#272b30", "#33383e", "#41474e", "#525960", "#666d74", "#7e858b", "#9aa0a5"]
FER_NOIR = ["#060607", "#0b0b0d", "#111214", "#18191c", "#202226", "#2a2c31", "#36393f", "#454950", "#5a5f66"]
CUIR = ["#0f0905", "#190f09", "#25160d", "#321e12", "#402717", "#4f301d", "#603b24", "#72472c"]
CUIR_ROUGE = ["#0e0404", "#1a0706", "#290b09", "#3a100c", "#4c1610", "#5e1d15", "#71261b", "#853224"]
CUIR_CENDRE = ["#060505", "#0c0a09", "#14110f", "#1d1916", "#27221e", "#322c27", "#3e3731", "#4b423a"]
FOURRURE_LOUP = ["#100e0c", "#1b1815", "#28231f", "#36302a", "#463e36", "#574d43", "#6a5e52", "#7d7063", "#918373"]
FOURRURE = ["#1a1510", "#2a2219", "#3b3023", "#4d3f2e", "#605039", "#746246", "#887454", "#9c8865", "#b09c79"]
FOURRURE_BLANCHE = ["#4a4a4c", "#5f5f62", "#757578", "#8b8b8e", "#a1a1a3", "#b6b5b5", "#c9c7c4", "#dad8d3", "#e8e6e0"]
OXYDE = ["#24130a", "#3a1e0e", "#552c14", "#6e3a1b", "#87502a"]
CRASSE = ["#0d0a07", "#17120c", "#221a11", "#2e2316", "#3b2e1e"]
OR = ["#151009", "#241b0f", "#352816", "#4a391e", "#614b27", "#7a5f31", "#94753d", "#ad8c4c", "#c5a462", "#dabd7e"]
LAINE_BLEUE = ["#05080f", "#0a1020", "#101a33", "#172447", "#1f305b", "#283c6e", "#334a80", "#425a90"]
ARGENT = ["#2b2e33", "#454950", "#62676f", "#80868e", "#a0a6ad", "#c2c7cc", "#e2e5e8"]
GIVRE = ["#3c4a58", "#566676", "#728494", "#90a2b2", "#aec0ce", "#cbdbe6", "#e6f0f6"]
BRAISE = ["#2a0402", "#4e0904", "#7a1406", "#a8240a", "#d44412", "#f2782a", "#ffb35a"]

class Toile:
    """Image RGBA 128² peinte au pixel ; alpha = brillance (lue par shader_matiere : 1 poli, 0 mat)."""
    def __init__(self, nom, w=128, h=128):
        self.nom, self.w, self.h = nom, w, h
        self.px = [[0.0, 0.0, 0.0, 1.0] for _ in range(w * h)]

    def set(self, x, y, c, b=None):
        if 0 <= x < self.w and 0 <= y < self.h:
            p = self.px[y * self.w + x]
            p[0], p[1], p[2] = c[0], c[1], c[2]
            if b is not None:
                p[3] = b

    def get(self, x, y):
        return self.px[(y % self.h) * self.w + (x % self.w)]

    def mul(self, x, y, k, db=0.0):
        if 0 <= x < self.w and 0 <= y < self.h:
            p = self.px[y * self.w + x]
            p[0] *= k; p[1] *= k; p[2] *= k
            p[3] = min(max(p[3] + db, 0.0), 1.0)

    def zone(self, rect, fn):
        """fn(x, y, u, v) -> (couleur, brillance) sur un rectangle de pixels (x0, y0, x1, y1)."""
        x0, y0, x1, y1 = rect
        for y in range(y0, y1):
            for x in range(x0, x1):
                c, b = fn(x, y, (x - x0) / max(1, x1 - x0 - 1), (y - y0) / max(1, y1 - y0 - 1))
                self.set(x, y, c, b)

    def image(self):
        img = bpy.data.images.new(self.nom, self.w, self.h, alpha=True)
        flat = []
        # Blender : ligne 0 en bas ; nos UV v=0 en bas aussi (y = v * h)
        for p in self.px:
            flat.extend((min(max(p[0], 0), 1), min(max(p[1], 0), 1), min(max(p[2], 0), 1), min(max(p[3], 0), 1)))
        img.pixels = flat
        img.pack()
        return img

def rect_uv(rect, w=128, h=128):
    """Rectangle de pixels -> (u0, v0, u1, v1), avec un demi-texel de marge."""
    x0, y0, x1, y1 = rect
    return ((x0 + 0.5) / w, (y0 + 0.5) / h, (x1 - 0.5) / w, (y1 - 0.5) / h)

# --- peintures de matières (fonctions pour Toile.zone)
def metal(pal, g, base=0.55, contraste=0.35, rayures=0.5, oxyde=0.0, crasse=0.0, poli=0.7, echelle=1.0, martele=0.0):
    def fn(x, y, u, v):
        n = fbm(x / echelle, y / echelle, g)
        t = base + (n - 0.5) * contraste
        if martele > 0:
            # coups de marteau : cuvettes de 5 px en quinconce irrégulier, clair en haut-gauche, sombre en bas-droite
            cx, cy = x // 5, y // 5
            ox = int(_h(cx, cy, g + 61) * 3) - 1
            oy = int(_h(cx, cy, g + 62) * 3) - 1
            dx = x - (cx * 5 + 2 + ox); dy = y - (cy * 5 + 2 + oy)
            if dx * dx + dy * dy <= 5:
                t += martele * (0.12 if dx + dy < 0 else -0.14)
        # rayures fines obliques (brillantes)
        r = _h(int((x + y * 0.35) / 1.0), int(y / 7), g + 3)
        b = poli * (0.55 + 0.45 * n)
        if r > 1.0 - 0.06 * rayures:
            t += 0.12; b = min(1.0, b + 0.3)
        c = rampe(pal, t)
        if oxyde > 0:
            o = fbm(x, y, g + 41, oct=((12, 0.6), (5, 0.4)))
            if o > 1.0 - oxyde * 0.5:
                k = min(1.0, (o - (1.0 - oxyde * 0.5)) * 6)
                oc = rampe(OXYDE, 0.3 + 0.5 * n)
                c = tuple(c[i] * (1 - k) + oc[i] * k for i in range(3)); b *= 1 - 0.8 * k
        if crasse > 0:
            o = fbm(x, y, g + 77, oct=((20, 0.6), (6, 0.4)))
            if o > 1.0 - crasse * 0.5:
                k = min(1.0, (o - (1.0 - crasse * 0.5)) * 4) * 0.8
                cc = rampe(CRASSE, 0.4 * n)
                c = tuple(c[i] * (1 - k) + cc[i] * k for i in range(3)); b *= 1 - 0.7 * k
        return c, b
    return fn

def maille(pal, g, base=0.5):
    """Cotte de mailles : RANGS horizontaux (ligne claire des anneaux / ligne sombre des jours) au grain aléatoire par pixel, plis de
    crasse ; jamais de quinconce régulier (damier interdit par la bible) : vu de loin, une étoffe d'acier striée."""
    def fn(x, y, u, v):
        rang = 1.0 if y % 2 == 0 else 0.6
        grain = _h(x, y, g + 29)
        n = fbm(x, y, g, oct=((10, 0.5), (5, 0.3), (2, 0.2)))
        pli = bruit(x * 0.5, y * 2.0, 8, g + 13)
        t = base * rang * (0.78 + 0.45 * pli) + (n - 0.5) * 0.2 + (grain - 0.5) * 0.12
        b = (0.2 + 0.6 * n) * rang * (0.6 + 0.6 * grain)
        return rampe(pal, t), min(b, 1.0)
    return fn

def cuir(pal, g, base=0.5, couture=False):
    def fn(x, y, u, v):
        n = fbm(x, y, g, oct=((10, 0.5), (4, 0.3), (2, 0.2)))
        t = base + (n - 0.5) * 0.5
        t -= 0.15 * (1 if _h(x, y, g + 9) > 0.93 else 0)
        use = fbm(x, y, g + 31, oct=((14, 0.6), (5, 0.4)))
        if use > 0.68:                      # cuir élimé (plus clair, mat)
            t += (use - 0.68) * 1.2
        return rampe(pal, t), 0.08 + 0.18 * n * (1.0 if use < 0.68 else 0.4)
    return fn

def fourrure(pal, g, base=0.55):
    """Mèches verticales (le haut de la zone = racine sombre, pointes claires)."""
    def fn(x, y, u, v):
        m = bruit(x * 3.0, y * 0.35, 4, g) * 0.6 + bruit(x * 6.0, y * 0.5, 2, g + 5) * 0.4
        t = base + (m - 0.5) * 0.9 + (v - 0.5) * 0.25
        return rampe(pal, t), 0.05 + 0.15 * m
    return fn

def laine(pal, g, base=0.55):
    def fn(x, y, u, v):
        n = fbm(x, y, g, oct=((6, 0.4), (3, 0.35), (1.5, 0.25)))
        trame = 0.06 if (x + y) % 2 == 0 else -0.04
        return rampe(pal, base + (n - 0.5) * 0.4 + trame), 0.05
    return fn

def ecailles(pal, g, base=0.5, braise=0.0, pal_braise=None):
    """Écailles de cuir en rangs décalés qui se recouvrent (10x7 px) : chaque écaille s'éclaircit vers son bord bas arrondi (arête qui
    accroche la lumière), ombre portée juste dessous, grain du cuir ; braise : fins liserés incandescents dans quelques jours."""
    def fn(x, y, u, v):
        ry = y // 7
        xx = (x + (ry % 2) * 5) % 10 - 4.5
        yy = 6 - (y % 7)                       # 0 = bas de l'écaille (bord libre), 6 = haut (sous l'écaille du dessus)
        bord = (xx / 5.0) ** 2 + ((yy - 6) / 7.0) ** 2   # ellipse ancrée en haut : bord bas arrondi
        n = fbm(x, y, g, oct=((8, 0.5), (3, 0.3), (1.5, 0.2)))
        t = base + (n - 0.5) * 0.3 + 0.18 * (1.0 - yy / 6.0)
        b = 0.25 + 0.3 * n
        if bord > 0.92:
            t -= 0.28; b = 0.05                 # jour entre écailles (ombre)
        elif bord > 0.78:
            t += 0.12; b = 0.6                  # arête claire
        c = rampe(pal, t)
        if braise > 0 and bord > 0.86 and _h(x // 4, y // 2, g + 5) < braise * bruit(x, y, 16, g + 8):
            c = rampe(pal_braise or BRAISE, 0.62 + 0.38 * _h(x, y, g + 6)); b = 0.0
        return c, b
    return fn

def runes(toile, rect, pal, g, k=0.9):
    """Rangée de runes (traits verticaux et obliques 1 px) brodées / gravées, claires."""
    x0, y0, x1, y1 = rect
    x = x0 + 1
    i = 0
    while x < x1 - 4:
        motif = int(_h(i, 0, g) * 6)
        h = y1 - y0 - 1
        for yy in range(h):
            toile.set(x, y0 + yy, rampe(pal, k), 0.9)
        if motif in (0, 3):
            for yy in range(h // 2):
                toile.set(x + 1 + yy // 2, y1 - 2 - yy, rampe(pal, k * 0.95), 0.9)
        if motif in (1, 4):
            for yy in range(h // 2):
                toile.set(x + 1 + yy // 2, y0 + 1 + yy, rampe(pal, k * 0.95), 0.9)
        if motif in (2, 5):
            toile.set(x + 1, y0 + h // 2, rampe(pal, k), 0.9); toile.set(x + 2, y0 + h // 2, rampe(pal, k), 0.9)
        x += 5 + (motif % 2)
        i += 1

def rivets(toile, pts, pal_clair, pal_ombre=None, r=1):
    """Rivets : point clair 1 px + ombre portée en bas à droite (lumière du haut-gauche)."""
    for (x, y) in pts:
        toile.mul(x + 1, y - 1, 0.45, -0.3)
        toile.mul(x, y - 1, 0.6, -0.2)
        toile.set(x, y, rampe(pal_clair, 0.92), 1.0)
        if r > 1:
            toile.set(x - 1, y, rampe(pal_clair, 0.75), 0.9)
            toile.set(x, y + 1, rampe(pal_clair, 0.8), 0.9)

def ligne_h(toile, y, x0, x1, k, db=-0.3):
    for x in range(x0, x1):
        toile.mul(x, y, k, db)

def ligne_v(toile, x, y0, y1, k, db=-0.3):
    for y in range(y0, y1):
        toile.mul(x, y, k, db)

def entrelacs(toile, rect, pal, g, k_creux=0.55):
    """Gravure d'entrelacs nordiques : deux rubans sinusoïdaux croisés, creusés (sombres) bordés d'un filet clair."""
    x0, y0, x1, y1 = rect
    h = y1 - y0
    for x in range(x0, x1):
        for ph in (0.0, math.pi):
            yc = y0 + h / 2 + (h / 2 - 1.5) * math.sin((x - x0) * TAU / max(8, h * 1.6) + ph)
            yi = int(round(yc))
            toile.mul(x, yi, k_creux, -0.3)
            toile.mul(x, yi + 1, 1.12, 0.15)

# ------------------------------------------------------------------------------------------------ matériaux, export
def materiau(nom, img):
    m = bpy.data.materials.get(nom)
    if m:
        return m
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    tx.interpolation = "Closest"
    nt.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    try:
        nt.links.new(tx.outputs["Alpha"], bsdf.inputs["Alpha"])   # brillance dans l'alpha (gardée par l'export : alphaMode MASK, seuil 0)
        m.blend_method = "CLIP"
        m.alpha_threshold = 0.0
    except Exception:
        pass
    bsdf.inputs["Roughness"].default_value = 0.6
    return m

def appliquer_materiaux(ob, piece, img):
    for nom in piece.mats:
        ob.data.materials.append(materiau("%s" % nom, img))

def compter_tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)

def exporter(obs, r, chemin):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    r.arm.select_set(True)
    bpy.context.view_layer.objects.active = r.arm
    kw = dict(filepath=chemin, export_format="GLB", use_selection=True, export_skins=True, export_animations=False,
              export_apply=False, export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
              export_image_format="AUTO", export_def_bones=False)
    for k, v in (("export_vertex_color", "ACTIVE"), ("export_all_vertex_colors", True), ("export_colors", True)):
        try:
            bpy.ops.export_scene.gltf.get_rna_type().properties[k]
            kw[k] = v
        except KeyError:
            pass
    bpy.ops.export_scene.gltf(**kw)
    print("EXPORT", chemin, sum(compter_tris(o) for o in obs), "tris")
