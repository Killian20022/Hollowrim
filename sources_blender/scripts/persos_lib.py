# Lot « personnages de base » : bibliotheque de modelage procedural (exec depuis base_persos.py).
# Tout est fait d'ANNEAUX (ellipses de N sommets) relies en tubes fermes : etanche par construction, 1-2 os par sommet, UV METRIQUES
# (u = arc, v = longueur de chemin, en metres) puis posees dans un atlas 256x256 a DENSITE texels/m. Voir docs/PERSONNAGES_TECH.md.
import bpy, bmesh, math, os, json
from mathutils import Vector

DENSITE = 48.0        # texels par metre (visage = tunique) : seule constante, lue aussi par le code Godot via le JSON de mise en page
ATLAS = 256

class Anneau:
    """Une ellipse de n sommets : centre c, axes e1 (rayon r1) et e2 (rayon r2), poids p = {os: poids} ou fonction k -> {os: poids}."""
    def __init__(s, c, r1, r2, p, e1=None, t=None, dy=0.0, dx=0.0, rot=0.0, vz=None):
        s.vz = vz; s.c = Vector(c); s.r1 = r1; s.r2 = r2; s.p = p; s.e1 = e1; s.t = t; s.dy = dy; s.dx = dx; s.rot = rot

class Piece:
    """Un maillage (un objet Blender, une surface Godot)."""
    def __init__(s, nom, double=False):
        s.nom = nom; s.double = double
        s.v = []; s.w = []; s.f = []      # sommets, poids, faces [(indices), [(u, v) par coin], partie]
        s.parts = {}                       # partie -> dict(kind, bord_debut, bord_fin, umin..., extras)

    def sommet(s, p, w):
        s.v.append(Vector(p)); s.w.append(w); return len(s.v) - 1

PIECES = []

def perimetre(a, b):
    return math.pi * (3 * (a + b) - math.sqrt((3 * a + b) * (a + 3 * b)))

def _frame(rings, i, hint):
    """Repere (t, e1, e2) du i-eme anneau : t = tangente du chemin des centres, e1 = indice lateral, e2 = e1 x t (vers l'avant du personnage pour un tube vertical)."""
    a = rings[max(i - 1, 0)].c; b = rings[min(i + 1, len(rings) - 1)].c
    t = rings[i].t if rings[i].t is not None else (b - a)
    t = Vector(t).normalized()
    e1h = Vector(rings[i].e1) if rings[i].e1 is not None else Vector(hint)
    e1 = (e1h - t * e1h.dot(t)).normalized()
    e2 = e1.cross(t).normalized()
    if e2.y > 0.2:          # e2 regarde TOUJOURS vers l'avant (-y), quel que soit le sens de parcours du tube : th=90 = devant, th=-90 = dos
        e2 = -e2
    elif abs(e2.y) <= 0.2 and e2.z < -0.2:
        e2 = -e2
    return t, e1, e2

def tube(piece, part, rings, n=8, cap0=False, cap1=False, kind="tunique", debut="aucun", fin="aucun", hint=(1, 0, 0), arc=None, **extra):
    """Relie les anneaux en un tube. cap0/cap1 : calotte (eventail) au premier / dernier anneau. arc=(a0, a1) en degres autour de e2 :
    tube OUVERT sur cet arc (panneaux de cape, de robe) au lieu du tour complet. extra : indications au peintre de textures."""
    if part in piece.parts:
        raise Exception("partie en double " + part)
    ouvert = arc is not None
    nk = n + 1 if ouvert else n       # sommets par anneau
    idx = []; uvs = []; pos_c = []
    vcum = 0.0
    for i, r in enumerate(rings):
        t, e1, e2 = _frame(rings, i, hint)
        if i > 0:
            d = (r.c - rings[i - 1].c).length
            dr = (r.r1 + r.r2 - rings[i - 1].r1 - rings[i - 1].r2) * 0.5
            vcum += math.hypot(d, dr)
        row = []; urow = []
        per = perimetre(r.r1, r.r2) if not ouvert else perimetre(r.r1, r.r2) * (arc[1] - arc[0]) / 360.0
        for k in range(nk):
            if ouvert:
                th = math.radians(arc[0] + (arc[1] - arc[0]) * k / n) - math.pi / 2
            else:
                th = -math.pi / 2 + 2 * math.pi * k / n + math.radians(r.rot)
            p = r.c + e1 * (r.r1 * math.cos(th)) + e2 * (r.r2 * math.sin(th)) + Vector((r.dx, r.dy, 0.0))
            if r.vz:
                p = p + Vector((0, 0, r.vz(th)))
            w = r.p(k) if callable(r.p) else r.p
            if k == n and not ouvert:
                continue
            row.append(piece.sommet(p, w)); urow.append(per * k / n)
        idx.append(row); uvs.append((urow, vcum))
        pos_c.append(r)
    faces = []
    for i in range(len(rings) - 1):
        for k in range(n):
            k2 = k + 1
            a = idx[i][k]; b = idx[i][k2 % len(idx[i])] if not ouvert else idx[i][k2]
            c = idx[i + 1][k2 % len(idx[i + 1])] if not ouvert else idx[i + 1][k2]; d = idx[i + 1][k]
            ua = uvs[i][0][k]; ub = uvs[i][0][k2] if (ouvert or k2 < n) else perimetre(rings[i].r1, rings[i].r2)
            uc = uvs[i + 1][0][k2] if (ouvert or k2 < n) else perimetre(rings[i + 1].r1, rings[i + 1].r2)
            ud = uvs[i + 1][0][k]
            v0 = uvs[i][1]; v1 = uvs[i + 1][1]
            faces.append(((a, b, c, d), [(ua, v0), (ub, v0), (uc, v1), (ud, v1)]))
    # orientation des quads : normale vers l'exterieur (ecart au centre, sans la composante le long du tube)
    t0 = _frame(rings, 0, hint)[0]
    vs = [piece.v[j] for j in faces[0][0]]
    nrm = (vs[1] - vs[0]).cross(vs[3] - vs[0])
    ext = sum(vs, Vector()) / 4.0 - (rings[0].c + rings[1].c) / 2.0
    ext = ext - t0 * ext.dot(t0)
    flip = nrm.dot(ext) < 0
    out = []
    for (q, uv) in faces:
        if flip:
            q = tuple(reversed(q)); uv = list(reversed(uv))
        out.append((q, uv))
    def calotte(i, signe):
        if ouvert:
            return
        r = rings[i]
        c = piece.sommet(r.c + Vector((r.dx, r.dy, 0.0)), r.p(0) if callable(r.p) else r.p)
        row = idx[i]; v = uvs[i][1]; per = perimetre(r.r1, r.r2)
        vc = v + signe * (r.r1 + r.r2) / 2
        t = _frame(rings, i, hint)[0] * signe
        for k in range(n):
            k2 = (k + 1) % n
            q = (row[k], row[k2], c)
            u2 = uvs[i][0][k + 1] if k + 1 < n else per
            uv = [(uvs[i][0][k], v), (u2, v), (per * (k + 0.5) / n, vc)]
            vv = [piece.v[j] for j in q]
            if (vv[1] - vv[0]).cross(vv[2] - vv[0]).dot(t) < 0:
                q = (q[1], q[0], q[2]); uv = [uv[1], uv[0], uv[2]]
            out.append((q, uv))
    if cap0: calotte(0, -1)
    if cap1: calotte(len(rings) - 1, 1)
    for (q, uv) in out:
        piece.f.append((q, uv, part))
    ext_u = max(a[2] for a in [[0, 0, perimetre(r.r1, r.r2) * ((arc[1] - arc[0]) / 360.0 if ouvert else 1.0)] for r in rings])
    vmax = uvs[-1][1]
    rmax = max(max(r.r1, r.r2) for r in rings)
    anneaux = [[round(uvs[i][1], 4), round(rings[i].c.z + rings[i].dy * 0, 4), round(perimetre(rings[i].r1, rings[i].r2) if not ouvert else perimetre(rings[i].r1, rings[i].r2) * (arc[1] - arc[0]) / 360.0, 4)] for i in range(len(rings))]
    piece.parts[part] = dict(anneaux=anneaux, kind=kind, bord_debut=debut, bord_fin=fin, umax=ext_u, vmin=-rmax if cap0 else 0.0, vmax=vmax + (rmax if cap1 else 0.0), **extra)
    return idx

# ------------------------------------------------------------------ atlas
def disposer(pieces, densite=DENSITE, atlas=ATLAS, marge=1):
    """Pose chaque partie dans l'atlas (rangees, hauteurs decroissantes) ; renvoie {piece.partie: [x, y, w, h]} (pixels)."""
    items = []
    for p in pieces:
        for nom, d in p.parts.items():
            dn = d.get("densite", densite)       # densite propre a la partie (visage : plus fine que le reste)
            w = int(math.ceil(d["umax"] * dn)) + 2 * marge + 1
            h = int(math.ceil((d["vmax"] - d["vmin"]) * dn)) + 2 * marge + 1
            items.append((h, w, p.nom + "." + nom, p, nom))
    items.sort(key=lambda a: (-a[0], -a[1]))
    x = y = 0; rang = 0; rects = {}
    for h, w, cle, p, nom in items:
        if x + w > atlas:
            x = 0; y += rang; rang = 0
        if y + h > atlas:
            raise Exception("atlas plein : %s (%dx%d) a y=%d" % (cle, w, h, y))
        rects[cle] = [x, y, w, h]
        x += w; rang = max(rang, h)
    return rects, y + rang

def uv_pixels(pieces, rects, densite=DENSITE, atlas=ATLAS, marge=1):
    """Coordonnees UV de chaque coin (convention Blender : v vers le haut ; l'export glTF retourne v : image Godot = ligne y vers le bas)."""
    for p in pieces:
        for fi, (q, uv, part) in enumerate(p.f):
            x, y, w, h = rects[p.nom + "." + part]
            vmin = p.parts[part]["vmin"]
            dn = p.parts[part].get("densite", densite)
            p.f[fi] = (q, [((x + marge + u * dn) / atlas, 1.0 - (y + marge + (v - vmin) * dn) / atlas) for (u, v) in uv], part)

# ------------------------------------------------------------------ objets Blender
def creer_objets(pieces, arm, noms_os):
    objs = []
    for p in pieces:
        me = bpy.data.meshes.new(p.nom)
        bm = bmesh.new()
        bv = [bm.verts.new(v) for v in p.v]
        layer = bm.loops.layers.uv.new("UVMap")
        for q, uv, part in p.f:
            try:
                f = bm.faces.new([bv[i] for i in q])
            except ValueError:
                continue
            for l, (u, v) in zip(f.loops, uv):
                l[layer].uv = (u, v)
            f.smooth = True
        bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(p.nom, me)
        bpy.context.scene.collection.objects.link(ob)
        groupes = {}
        for i, w in enumerate(p.w):
            if len(w) > 2:
                raise Exception("plus de 2 os : %s %s" % (p.nom, w))
            tot = sum(w.values())
            for os_, val in w.items():
                if val <= 0:
                    continue
                g = groupes.get(os_) or ob.vertex_groups.new(name=os_)
                groupes[os_] = g
                g.add([i], val / tot, 'REPLACE')
        ob.parent = arm
        md = ob.modifiers.new("Armature", 'ARMATURE'); md.object = arm
        objs.append(ob)
    return objs

def triangles(p):
    t = 0
    for q, uv, part in p.f:
        t += 1 if len(q) == 3 else 2
    return t
