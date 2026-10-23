# Lot C7c : modules de la rivière du village (pont de pierre en arche, rocher de la source, seuil du moulin, roue à aubes,
# quai sur pieux, pierres du gué).
#   blender.exe -b --python eau_village.py
# Sortie : assets/modeles/eau/eau_village.glb + sources_blender/eau_village.blend
# Tout est construit dans le repère de GODOT (x, y haut, z) puis converti en Blender (x, -z, y) et ré-exporté Y haut.
# Couleur de sommet : rgb = occlusion peinte, a = 0 → neige (shader ps1_bati). Un objet = une matière (affectée dans Godot) :
#   Pont_Maconnerie (pierre sèche), Pont_Taille (voussoirs, bandeau, chaperons : pierre fine), Pont_Tablier (dalles),
#   Pont_Col (collision seule, jamais dessinée), Rocher_Source, Seuil_Taille, Seuil_Roches, Roue (bois, tourne autour de z),
#   Roue_Axe (rondin), Roue_Support, Quai_Planches, Quai_Pieux, Gue_1..3.
import bpy, bmesh, math, os, random
from mathutils import Vector

ICI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(BASE, "assets", "modeles", "eau", "eau_village.glb")
BLEND = os.path.join(BASE, "sources_blender", "eau_village.blend")
os.makedirs(os.path.dirname(SORTIE), exist_ok=True)


def b_of_g(v):
    return Vector((v[0], -v[2], v[1]))


class Maillage:
    """Accumulateur de faces (repère Godot) avec couleur par coin : (r, g, b, a)."""

    def __init__(self, nom):
        self.nom = nom
        self.v = []
        self.f = []
        self.c = []   # couleur par face (liste de 4-uplets par coin)
        self.uv = []  # uv par coin (ou None)

    def face(self, pts, cols=None, uvs=None):
        base = len(self.v)
        self.v.extend([tuple(p) for p in pts])
        self.f.append(tuple(range(base, base + len(pts))))
        self.c.append(cols)
        self.uv.append(uvs)

    def quad(self, a, b, c, d, cols=None, uvs=None):
        self.face([a, b, c, d], cols, uvs)

    def prisme(self, bas, haut, cols=None, cols_haut=None):
        """bas, haut : 4 points (sens trigonométrique vu de dessus, y haut) → 6 faces orientées vers l'extérieur."""
        b0, b1, b2, b3 = bas
        h0, h1, h2, h3 = haut
        self.quad(h0, h1, h2, h3, cols_haut if cols_haut is not None else cols)          # dessus
        self.quad(b3, b2, b1, b0, cols)          # dessous
        self.quad(b0, b1, h1, h0, cols)
        self.quad(b1, b2, h2, h1, cols)
        self.quad(b2, b3, h3, h2, cols)
        self.quad(b3, b0, h0, h3, cols)

    def boite(self, x0, x1, y0, y1, z0, z1, cols=None):
        bas = [Vector((x0, y0, z1)), Vector((x1, y0, z1)), Vector((x1, y0, z0)), Vector((x0, y0, z0))]
        haut = [Vector((p.x, y1, p.z)) for p in bas]
        self.prisme(bas, haut, cols)

    def objet(self, neige_auto=False, ao_auto=None, lisse=False, recalc=True, oriente=None):
        bm = bmesh.new()
        vs = [bm.verts.new(b_of_g(p)) for p in self.v]
        uvl = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.float_color.new("Color")
        for k, f in enumerate(self.f):
            try:
                face = bm.faces.new([vs[i] for i in f])
            except ValueError:
                continue
            face.smooth = lisse
            cols = self.c[k]
            uvs = self.uv[k]
            for j, lp in enumerate(face.loops):
                if uvs is not None:
                    lp[uvl].uv = uvs[j]
                c = cols[j] if (cols is not None and isinstance(cols[0], tuple)) else (cols if cols is not None else (1, 1, 1, 1))
                lp[col] = c
        bm.verts.ensure_lookup_table()
        if recalc:
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        if oriente is not None:
            a_retourner = []
            for face in bm.faces:
                c = face.calc_center_median()
                n = face.normal
                if not oriente(Vector((c.x, c.z, -c.y)), Vector((n.x, n.z, -n.y))):
                    a_retourner.append(face)
            if a_retourner:
                bmesh.ops.reverse_faces(bm, faces=a_retourner)
            bm.normal_update()
        if neige_auto or ao_auto is not None:
            for face in bm.faces:
                n = face.normal
                for lp in face.loops:
                    c = list(lp[col])
                    if neige_auto and n.z > 0.6:
                        c[3] = 0.0
                    if ao_auto is not None:
                        k = ao_auto(lp.vert.co, n)
                        c[0] *= k; c[1] *= k; c[2] *= k
                    lp[col] = c
        me = bpy.data.meshes.new(self.nom)
        bm.to_mesh(me)
        bm.free()
        me.color_attributes.active_color = me.color_attributes["Color"]
        ob = bpy.data.objects.new(self.nom, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


# ------------------------------------------------------------------ roches (enveloppes convexes, arêtes vives)

def hull(pts):
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(b_of_g(p))
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:], use_existing_faces=False)
    perdus = [g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)]
    if perdus:
        bmesh.ops.delete(bm, geom=list(set(perdus)), context='VERTS')
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    tris = []
    for f in bm.faces:
        tris.append([Vector((v.co.x, v.co.z, -v.co.y)) for v in f.verts])   # retour au repère Godot
    bm.free()
    return tris


def bloc(rg, centre, taille, n=15, aplat_bas=0.55, aplat_haut=1.5):
    pts = []
    for _ in range(n):
        while True:
            v = Vector((rg.gauss(0, 1), rg.gauss(0, 1), rg.gauss(0, 1)))
            if v.length > 0.05:
                break
        v.normalize()
        v *= rg.uniform(0.74, 1.26)
        v.y = max(v.y, -aplat_bas)
        v.y = min(v.y, aplat_haut)
        pts.append(Vector((centre[0] + v.x * taille[0], centre[1] + v.y * taille[1], centre[2] + v.z * taille[2])))
    return hull(pts)


def ajouter_tris(m, tris):
    for t in tris:
        m.face(t)


def ao_hauteur(y0, y1, mini=0.6):
    def f(co, n):
        y = co.z   # Blender z = Godot y
        return mini + (1.0 - mini) * max(0.0, min(1.0, (y - y0) / max(y1 - y0, 0.01)))
    return f


# ------------------------------------------------------------------ pont de pierre en arche
# Repère : origine au milieu du pont, au niveau des deux extrémités du tablier (= plateau, 3,6 m) ; axe du pont = z (9 m),
# largeur x ±1,6 ; la rivière passe sous l'arche selon x. Arche segmentaire : portée 6 m (z ±3), naissances à y -1,4
# (fond du lit), clé de l'intrados à y +0,55 (1,3 m au-dessus de l'eau) ; tablier bombé : +1,1 m au milieu (1,9 m au-dessus de l'eau).

L = 9.0
DEMI_L = L / 2
W = 3.2
DW = W / 2
PORTEE = 3.0
Y_NAISS = -1.4
Y_CLE = 0.55
FLECHE = Y_CLE - Y_NAISS
R_ARC = (PORTEE ** 2 + FLECHE ** 2) / (2 * FLECHE)
CY = Y_CLE - R_ARC
PHI = math.asin(PORTEE / R_ARC)
BOMBE = 1.1
Y_BAS = -2.4          # pied des culées (enterré)
PARA_IN = 1.28        # face intérieure des parapets
PARA_H = 0.62         # hauteur du mur de parapet (+ chaperon 0,1)
EP_VOUSS = 0.5


def dessus(z):
    t = max(-1.0, min(1.0, z / DEMI_L))
    return BOMBE * (1.0 - t * t)


def intrados(z):
    return CY + math.sqrt(max(R_ARC * R_ARC - z * z, 0.0))


def echantillons():
    zs = []
    n = 36
    for i in range(n + 1):
        zs.append(-DEMI_L + L * i / n)
    for z in (-PORTEE, PORTEE):
        if all(abs(z - q) > 1e-4 for q in zs):
            zs.append(z)
    return sorted(zs)


def pont():
    rg = random.Random(4401)
    zs = echantillons()
    mac = Maillage("Pont_Maconnerie")
    col = Maillage("Pont_Col")
    blanc = (1, 1, 1, 1)

    def bas(z, cote):
        # cote : -1 = côté z<0 de la discontinuité, +1 = côté z>0
        if abs(z) < PORTEE - 1e-5:
            return intrados(z)
        if abs(abs(z) - PORTEE) < 1e-5:
            # à la naissance : dans l'arche (vers le milieu) = intrados, dehors = pied de culée
            vers_milieu = (cote > 0) if z < 0 else (cote < 0)
            return Y_NAISS if vers_milieu else Y_BAS
        return Y_BAS

    for k in range(len(zs) - 1):
        za, zb = zs[k], zs[k + 1]
        ba, bb = bas(za, +1), bas(zb, -1)
        ta, tb = dessus(za), dessus(zb)
        for sx in (-1, 1):
            x = sx * DW
            pa, pb = Vector((x, ba, za)), Vector((x, bb, zb))
            qa, qb = Vector((x, ta, za)), Vector((x, tb, zb))
            ao = lambda y: 0.62 + 0.38 * max(0.0, min(1.0, (y + 1.6) / 2.2))
            cols = [(ao(ba),) * 3 + (1,), (ao(bb),) * 3 + (1,), (ao(tb),) * 3 + (1,), (ao(ta),) * 3 + (1,)]
            if sx > 0:
                mac.quad(pa, pb, qb, qa, cols)
                col.quad(pa, pb, qb, qa)
            else:
                mac.quad(pb, pa, qa, qb, [cols[1], cols[0], cols[3], cols[2]])
                col.quad(pb, pa, qa, qb)
        # dessous (intrados ou pied) : face vers le bas
        c_bas = (0.55, 0.55, 0.6, 1)
        mac.quad(Vector((DW, ba, za)), Vector((-DW, ba, za)), Vector((-DW, bb, zb)), Vector((DW, bb, zb)), c_bas)
        col.quad(Vector((DW, ba, za)), Vector((-DW, ba, za)), Vector((-DW, bb, zb)), Vector((DW, bb, zb)))
        # dessus de la collision : tablier sur toute la largeur
        col.quad(Vector((-DW, ta, za)), Vector((DW, ta, za)), Vector((DW, tb, zb)), Vector((-DW, tb, zb)))
    # faces des culées (côté rivière, entre le pied et la naissance)
    for s in (-1, 1):
        z = s * PORTEE
        a, b = Vector((-DW, Y_BAS, z)), Vector((DW, Y_BAS, z))
        c, d = Vector((DW, Y_NAISS, z)), Vector((-DW, Y_NAISS, z))
        mac.quad(a, b, c, d, (0.6, 0.6, 0.64, 1))
        col.quad(a, b, c, d)
    # bouts (enterrés dans le plateau)
    for s in (-1, 1):
        z = s * DEMI_L
        pts = [Vector((-DW, Y_BAS, z)), Vector((DW, Y_BAS, z)), Vector((DW, dessus(z), z)), Vector((-DW, dessus(z), z))]
        mac.quad(*pts, (0.7, 0.7, 0.72, 1))
        col.quad(*pts)

    # --- parapets (mur + chaperon) et piliers d'extrémité
    taille = Maillage("Pont_Taille")
    for sx in (-1, 1):
        xi, xe = sx * PARA_IN, sx * DW
        zp = [z for z in zs if abs(z) <= DEMI_L - 0.42 + 1e-6] + [DEMI_L - 0.42, -(DEMI_L - 0.42)]
        zp = sorted(set(round(z, 5) for z in zp))
        for k in range(len(zp) - 1):
            za, zb = zp[k], zp[k + 1]
            ta, tb = dessus(za), dessus(zb)
            # mur : face intérieure, face extérieure (dans le prolongement de la façade), dessus sous le chaperon
            a0, b0 = Vector((xi, ta, za)), Vector((xi, tb, zb))
            a1, b1 = Vector((xi, ta + PARA_H, za)), Vector((xi, tb + PARA_H, zb))
            e0, f0 = Vector((xe, ta, za)), Vector((xe, tb, zb))
            e1, f1 = Vector((xe, ta + PARA_H, za)), Vector((xe, tb + PARA_H, zb))
            ci = [(0.7, 0.7, 0.72, 1), (0.7, 0.7, 0.72, 1), (1, 1, 1, 1), (1, 1, 1, 1)]
            if sx > 0:
                mac.quad(b0, a0, a1, b1, ci)
                mac.quad(e0, f0, f1, e1)
            else:
                mac.quad(a0, b0, b1, a1, ci)
                mac.quad(f0, e0, e1, f1)
            # chaperon : pierres de 0,6 à 0,9 m, débordant de 4 cm, dessus enneigé
            pass
        # chaperons en pierres séparées
        z = -(DEMI_L - 0.42)
        while z < DEMI_L - 0.42 - 0.05:
            lz = min(rg.uniform(0.6, 0.95), DEMI_L - 0.42 - z)
            za, zb = z + 0.012, z + lz - 0.012
            ta, tb = dessus(za) + PARA_H, dessus(zb) + PARA_H
            h = 0.1 + rg.uniform(-0.01, 0.02)
            x0, x1 = min(xi, xe) - 0.04, max(xi, xe) + 0.04
            bas_ = [Vector((x0, ta, zb)), Vector((x1, tb, zb)), Vector((x1, ta, za)), Vector((x0, ta, za))]
            bas_ = [Vector((x0, tb, zb)), Vector((x1, tb, zb)), Vector((x1, ta, za)), Vector((x0, ta, za))]
            haut_ = [p + Vector((0, h, 0)) for p in bas_]
            taille.prisme(bas_, haut_)
            z += lz
        # collision : prisme du parapet
        for k in range(len(zp) - 1):
            za, zb = zp[k], zp[k + 1]
            ta, tb = dessus(za), dessus(zb)
            x0, x1 = min(xi, xe), max(xi, xe)
            bas_ = [Vector((x0, ta, zb)), Vector((x1, tb, zb)), Vector((x1, ta, za)), Vector((x0, ta, za))]
            bas_ = [Vector((x0, tb, zb)), Vector((x1, tb, zb)), Vector((x1, ta, za)), Vector((x0, ta, za))]
            haut_ = [p + Vector((0, PARA_H + 0.1, 0)) for p in bas_]
            col.prisme(bas_, haut_)
        # piliers d'extrémité (0,45 × 0,45, chapeau pyramidal)
        for sz in (-1, 1):
            zc = sz * (DEMI_L - 0.22)
            xc = sx * (DW - 0.2)
            y0 = dessus(zc) - 0.3
            y1 = dessus(zc) + 0.92
            taille.boite(xc - 0.23, xc + 0.23, y0, y1, zc - 0.23, zc + 0.23)
            col.boite(xc - 0.23, xc + 0.23, y0, y1 + 0.1, zc - 0.23, zc + 0.23)
            # chapeau
            a = 0.27
            base = [Vector((xc - a, y1, zc + a)), Vector((xc + a, y1, zc + a)), Vector((xc + a, y1, zc - a)), Vector((xc - a, y1, zc - a))]
            top = Vector((xc, y1 + 0.2, zc))
            for i in range(4):
                taille.face([base[i], base[(i + 1) % 4], top])
            taille.quad(base[3], base[2], base[1], base[0])
    # --- bandeau (cordon) sous le parapet, sur les deux façades
    for sx in (-1, 1):
        x0 = sx * DW
        x1 = sx * (DW + 0.06)
        for k in range(len(zs) - 1):
            za, zb = zs[k], zs[k + 1]
            if abs(za) > DEMI_L - 0.45 or abs(zb) > DEMI_L - 0.45:
                continue
            ta, tb = dessus(za) - 0.02, dessus(zb) - 0.02
            h = 0.16
            pts_b = [Vector((min(x0, x1), ta - h, za)), Vector((max(x0, x1), ta - h, za)), Vector((max(x0, x1), tb - h, zb)), Vector((min(x0, x1), tb - h, zb))]
            pts_h = [Vector((p.x, p.y + h, p.z)) for p in pts_b]
            pts_h[0].y = ta; pts_h[1].y = ta; pts_h[2].y = tb; pts_h[3].y = tb
            taille.prisme([pts_b[3], pts_b[2], pts_b[1], pts_b[0]], [pts_h[3], pts_h[2], pts_h[1], pts_h[0]])
    # --- voussoirs (anneau de l'arche, sur toute la largeur : la voûte est appareillée)
    n_v = 15
    for i in range(n_v):
        a0 = -PHI + 2 * PHI * i / n_v + 0.006
        a1 = -PHI + 2 * PHI * (i + 1) / n_v - 0.006
        cle = (i == n_v // 2)
        ext = EP_VOUSS + (0.1 if cle else rg.uniform(-0.05, 0.06))
        ri = R_ARC - 0.035
        re = R_ARC + ext
        x0, x1 = -DW - 0.035, DW + 0.035

        def p(r, a, x):
            return Vector((x, CY + r * math.cos(a), r * math.sin(a)))
        # en z : sin, en y : cos (a = 0 à la clé)
        bas_ = [p(ri, a0, x0), p(ri, a1, x0), p(ri, a1, x1), p(ri, a0, x1)]
        haut_ = [p(re, a0, x0), p(re, a1, x0), p(re, a1, x1), p(re, a0, x1)]
        # les voussoirs s'arrêtent sous le bandeau
        for q in haut_:
            q.y = min(q.y, dessus(q.z) - 0.2)
        taille.prisme(bas_, haut_)
    # --- tablier : dalles (bandes en x, joints en z), rives enneigées le long des parapets
    tab = Maillage("Pont_Tablier")
    xs = [-PARA_IN, -0.95, -0.35, 0.3, 0.9, PARA_IN]
    zt = [z for z in zs]
    for k in range(len(zt) - 1):
        za, zb = zt[k], zt[k + 1]
        for j in range(len(xs) - 1):
            xa, xb = xs[j], xs[j + 1]
            ta, tb = dessus(za), dessus(zb)

            def c(x):
                return (0.9, 0.9, 0.9, 0.0 if abs(x) > 1.05 else 1.0)
            tab.quad(Vector((xa, ta, za)), Vector((xa, tb, zb)), Vector((xb, tb, zb)), Vector((xb, ta, za)),
                     [c(xa), c(xa), c(xb), c(xb)])
    # fond du tablier sous les extrémités : rien (posé sur la maçonnerie)
    def dehors(c, n):
        s = 1.0 if c.x >= 0 else -1.0
        if abs(abs(c.x) - DW) < 0.01:
            return n.x * s > 0
        if abs(abs(c.x) - PARA_IN) < 0.01:
            return n.x * s < 0
        if abs(abs(c.z) - DEMI_L) < 0.01:
            return n.z * (1.0 if c.z > 0 else -1.0) > 0
        if abs(abs(c.z) - PORTEE) < 0.01 and abs(n.z) > 0.9:
            return n.z * (1.0 if c.z > 0 else -1.0) < 0
        return n.y < 0
    mac.objet(recalc=False, oriente=dehors)
    taille.objet(neige_auto=True, ao_auto=ao_hauteur(-1.6, 0.9, 0.62))
    tab.objet(recalc=False)
    col.objet(recalc=False)


# ------------------------------------------------------------------ rocher de la source
# Origine = LÈVRE de la cascade (haut de l'eau) ; l'eau coule vers +x ; le rocher est derrière (x < 0) et sur les côtés.

def rocher_source():
    rg = random.Random(9057)
    m = Maillage("Rocher_Source")
    blocs = [
        # masse du fond
        ((-2.6, 0.2, 0.0), (1.6, 2.4, 2.4), 20, 0.9),
        ((-3.4, -0.6, 1.9), (1.4, 2.2, 1.5), 18, 0.9),
        ((-3.2, -0.4, -2.0), (1.5, 2.0, 1.6), 18, 0.9),
        # joues de la fissure
        ((-0.7, -0.4, 1.35), (0.9, 1.5, 0.7), 16, 0.9),
        ((-0.6, -0.5, -1.4), (0.95, 1.4, 0.75), 16, 0.9),
        ((-0.2, -1.6, 2.1), (0.9, 1.0, 0.9), 15, 0.8),
        ((-0.3, -1.7, -2.2), (0.85, 1.0, 0.95), 15, 0.8),
        # linteau en surplomb au-dessus de la sortie d'eau
        ((-0.9, 1.55, 0.0), (1.05, 0.62, 1.55), 16, 0.8),
        ((-1.5, 2.6, 0.5), (1.2, 0.8, 1.6), 16, 0.8),
        # seuil sous la lèvre (l'eau glisse dessus)
        ((-0.6, -0.42, 0.0), (0.75, 0.38, 0.75), 14, 0.9),
        # éboulis devant
        ((0.9, -2.5, 1.9), (0.6, 0.45, 0.6), 12, 0.6),
        ((1.2, -2.6, -1.7), (0.55, 0.4, 0.55), 12, 0.6),
        ((0.4, -2.2, 2.9), (0.7, 0.55, 0.6), 12, 0.6),
        ((-1.2, -1.4, 3.3), (0.9, 1.0, 0.8), 14, 0.8),
        ((-1.0, -1.3, -3.3), (0.9, 0.9, 0.8), 14, 0.8),
    ]
    for c, t, n, ab in blocs:
        ajouter_tris(m, bloc(rg, c, t, n, ab))
    m.objet(neige_auto=True, ao_auto=ao_hauteur(-2.6, 2.6, 0.55), recalc=False)


# ------------------------------------------------------------------ seuil du moulin (barrage de pierre de taille)
# Origine = LÈVRE (bord aval du seuil) au niveau de l'eau ; l'eau coule vers +x. Le seuil va de x = -2,7 à 0, z ±2,5 ;
# son dessus est à -0,45 (sous l'eau) ; la face aval tombe jusqu'à -4,2 ; murs en aile sur les berges.

def seuil():
    rg = random.Random(2218)
    m = Maillage("Seuil_Taille")
    # dessus : dalles
    z = -2.5
    while z < 2.5 - 0.05:
        lz = min(rg.uniform(0.7, 1.1), 2.5 - z)
        x = -2.7
        while x < -0.05:
            lx = min(rg.uniform(0.6, 1.0), -x)
            h = rg.uniform(-0.03, 0.02)
            m.boite(x + 0.015, x + lx - 0.015, -1.0, -0.45 + h, z + 0.015, z + lz - 0.015)
            x += lx
        z += lz
    # face aval : 4 assises de blocs (débord léger, irrégulier)
    y = -0.45
    for assise in range(5):
        hy = rg.uniform(0.62, 0.85)
        z = -2.5 + (0.0 if assise % 2 == 0 else -0.35)
        while z < 2.5 - 0.05:
            lz = min(rg.uniform(0.75, 1.25), 2.5 - z)
            za = max(z, -2.5)
            d = rg.uniform(-0.02, 0.05)
            m.boite(-0.9, 0.02 + d, y - hy + 0.012, y - 0.012, za + 0.012, z + lz - 0.012)
            z += lz
        y -= hy
    # murs en aile (berges) : pierre de taille, dessus enneigé
    for sz in (-1, 1):
        z0, z1 = (2.5, 3.1) if sz > 0 else (-3.1, -2.5)
        x = -3.4
        while x < 0.45:
            lx = min(rg.uniform(0.7, 1.0), 0.45 - x)
            top = 0.55 + rg.uniform(-0.04, 0.05)
            m.boite(x + 0.012, x + lx - 0.012, -4.0, top, z0, z1)
            x += lx
    m.objet(neige_auto=True, ao_auto=ao_hauteur(-3.6, 0.5, 0.55))
    # roches au pied, mouillées
    r = Maillage("Seuil_Roches")
    for k in range(7):
        zc = -2.2 + k * 0.72 + rg.uniform(-0.15, 0.15)
        ajouter_tris(r, bloc(rg, (0.6 + rg.uniform(0, 0.9), -3.15 + rg.uniform(-0.15, 0.1), zc), (0.4 + rg.uniform(0, 0.2), 0.3, 0.38), 12, 0.6))
    r.objet(neige_auto=True, ao_auto=ao_hauteur(-3.6, -2.6, 0.6), recalc=False)


# ------------------------------------------------------------------ roue à aubes (axe = z local, origine au centre)

R_ROUE = 1.5
LARG_ROUE = 0.8


def cyl(m, r, z0, z1, n, x=0.0, y=0.0, uv_m=False, couvercles=True):
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 1) / n
        p0 = Vector((x + r * math.cos(a0), y + r * math.sin(a0), z0))
        p1 = Vector((x + r * math.cos(a1), y + r * math.sin(a1), z0))
        uvs = None
        if uv_m:
            u0, u1 = r * a0, r * a1
            uvs = [(u0, 0.0), (u1, 0.0), (u1, z1 - z0), (u0, z1 - z0)]
        m.quad(p0, p1, Vector((p1.x, p1.y, z1)), Vector((p0.x, p0.y, z1)), None, uvs)
    if couvercles:
        for zc in (z0, z1):
            pts = [Vector((x + r * math.cos(2 * math.pi * i / n), y + r * math.sin(2 * math.pi * i / n), zc)) for i in range(n)]
            m.face(pts if zc == z1 else list(reversed(pts)), None, [(0, 0)] * n if uv_m else None)


def roue():
    rg = random.Random(6161)
    m = Maillage("Roue")
    n = 16
    # deux jantes (anneaux polygonaux à section rectangulaire)
    for sz in (-1, 1):
        zc = sz * LARG_ROUE / 2
        for i in range(n):
            a0 = 2 * math.pi * i / n
            a1 = 2 * math.pi * (i + 1) / n
            ri, re = R_ROUE - 0.16, R_ROUE - 0.02
            bas_ = []
            pts_i0 = Vector((ri * math.cos(a0), ri * math.sin(a0), 0))
            pts_i1 = Vector((ri * math.cos(a1), ri * math.sin(a1), 0))
            pts_e0 = Vector((re * math.cos(a0), re * math.sin(a0), 0))
            pts_e1 = Vector((re * math.cos(a1), re * math.sin(a1), 0))
            z0, z1 = zc - 0.05, zc + 0.05
            q = lambda p, z: Vector((p.x, p.y, z))
            # prisme : on le construit comme une boîte déformée
            m.prisme([q(pts_i0, z1), q(pts_e0, z1), q(pts_e1, z1), q(pts_i1, z1)],
                     [q(pts_i0, z0), q(pts_e0, z0), q(pts_e1, z0), q(pts_i1, z0)])
        # rayons (8 par côté)
        for i in range(8):
            a = 2 * math.pi * i / 8 + (0.0 if sz < 0 else math.pi / 8)
            d = Vector((math.cos(a), math.sin(a), 0))
            t = Vector((-d.y, d.x, 0)) * 0.045
            r0, r1 = 0.18, R_ROUE - 0.12
            z0, z1 = zc - 0.04, zc + 0.04
            pa, pb = d * r0, d * r1
            bas_ = [pa - t, pb - t, pb + t, pa + t]
            m.prisme([Vector((p.x, p.y, z1)) for p in bas_], [Vector((p.x, p.y, z0)) for p in bas_])
    # aubes (16 planches radiales entre les jantes)
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        d = Vector((math.cos(a), math.sin(a), 0))
        t = Vector((-d.y, d.x, 0)) * 0.025
        r0, r1 = R_ROUE - 0.5, R_ROUE + 0.04 + rg.uniform(-0.02, 0.02)
        z0, z1 = -LARG_ROUE / 2 + 0.03, LARG_ROUE / 2 - 0.03
        pa, pb = d * r0, d * r1
        bas_ = [pa - t, pb - t, pb + t, pa + t]
        m.prisme([Vector((p.x, p.y, z1)) for p in bas_], [Vector((p.x, p.y, z0)) for p in bas_])
    # moyeu
    cyl(m, 0.24, -LARG_ROUE / 2 - 0.06, LARG_ROUE / 2 + 0.06, 8)
    m.objet(ao_auto=lambda co, nn: 0.8 + 0.2 * max(0.0, nn.z))
    # axe (rondin) : du côté maison (z < 0) jusqu'au mur, 1,6 m ; de l'autre côté jusqu'au palier, 0,75 m
    ax = Maillage("Roue_Axe")
    cyl(ax, 0.1, -1.75, 0.8, 8, uv_m=True)
    ax.objet()
    # palier côté rivière : chevalet de deux poteaux plantés dans le lit + traverse + coussinet
    s = Maillage("Roue_Support")
    zc = 0.72
    for sx in (-1, 1):
        xx = sx * 0.42
        s.boite(xx - 0.09, xx + 0.09, -2.25, 0.05, zc - 0.09, zc + 0.09)
    s.boite(-0.62, 0.62, -0.14, 0.02, zc - 0.11, zc + 0.11)    # traverse sous l'axe
    s.boite(-0.16, 0.16, 0.02, 0.12, zc - 0.12, zc + 0.12)     # coussinet (l'axe y tourne)
    # contre-fiches
    for sx in (-1, 1):
        a = Vector((sx * 0.42, -1.6, zc))
        b = Vector((sx * 0.06, -0.14, zc))
        d = (b - a).normalized()
        t = Vector((-d.y, d.x, 0)) * 0.05
        s.prisme([a - t + Vector((0, 0, 0.06)), b - t + Vector((0, 0, 0.06)), b + t + Vector((0, 0, 0.06)), a + t + Vector((0, 0, 0.06))],
                 [a - t - Vector((0, 0, 0.06)), b - t - Vector((0, 0, 0.06)), b + t - Vector((0, 0, 0.06)), a + t - Vector((0, 0, 0.06))])
    # palier côté maison (au mur) : console
    s.boite(-0.2, 0.2, -0.32, 0.12, -1.75, -1.5)
    s.boite(-0.12, 0.12, -0.9, -0.32, -1.72, -1.52)
    s.objet(neige_auto=True)


# ------------------------------------------------------------------ quai sur pieux
# Origine : coin (x 0, dessus des planches y 0, z 0) côté berge ; 9 m en x, 2,2 m en z (z = 2,2 côté eau).

def quai():
    rg = random.Random(3712)
    pl = Maillage("Quai_Planches")
    x = 0.0
    while x < 9.0 - 0.05:
        w = rg.uniform(0.22, 0.28)
        if x + w > 9.0:
            w = 9.0 - x
        dz0 = rg.uniform(-0.04, 0.03)
        dz1 = 2.2 + rg.uniform(-0.05, 0.06)
        h = rg.uniform(-0.012, 0.006)
        neige = rg.random() < 0.4
        top_col = (0.92, 0.92, 0.92, 0.0 if neige else 1.0)
        bas_ = [Vector((x + 0.01, -0.07, dz1)), Vector((x + w - 0.01, -0.07, dz1)), Vector((x + w - 0.01, -0.07, dz0)), Vector((x + 0.01, -0.07, dz0))]
        haut_ = [Vector((p.x, h, p.z)) for p in bas_]
        # léger gauchissement
        haut_[1].y += rg.uniform(-0.01, 0.01)
        pl.prisme(bas_, haut_, None, top_col)
        x += w + 0.018
    # longerons
    for zl in (0.18, 1.1, 2.02):
        pl.boite(-0.05, 9.05, -0.27, -0.07, zl - 0.08, zl + 0.08, (0.62, 0.62, 0.62, 1))
    # chasse-roue (planche de rive côté eau)
    pl.prisme([Vector((0.0, -0.07, 2.24)), Vector((9.0, -0.07, 2.24)), Vector((9.0, -0.07, 2.12)), Vector((0.0, -0.07, 2.12))],
              [Vector((0.0, 0.09, 2.24)), Vector((9.0, 0.09, 2.24)), Vector((9.0, 0.09, 2.12)), Vector((0.0, 0.09, 2.12))], None, (0.85, 0.85, 0.85, 0.0))
    pl.objet()
    pi_ = Maillage("Quai_Pieux")
    for zr, haut_ok in ((0.18, False), (2.06, True)):
        for i in range(7):
            xp = 0.2 + i * (8.6 / 6) + rg.uniform(-0.06, 0.06)
            r = 0.1 + rg.uniform(0, 0.03)
            top = 0.5 + rg.uniform(-0.05, 0.12) if (haut_ok and i in (0, 3, 6)) else -0.07
            cyl(pi_, r, 0, 1, 7, uv_m=True) if False else None
            # cylindre vertical (axe y) : on construit directement
            n = 7
            y0 = -2.4
            for k in range(n):
                a0 = 2 * math.pi * k / n
                a1 = 2 * math.pi * (k + 1) / n
                p0 = Vector((xp + r * math.cos(a0), y0, zr + r * math.sin(a0)))
                p1 = Vector((xp + r * math.cos(a1), y0, zr + r * math.sin(a1)))
                uvs = [(r * a0, 0.0), (r * a0, top - y0), (r * a1, top - y0), (r * a1, 0.0)]
                pi_.quad(p0, Vector((p0.x, top, p0.z)), Vector((p1.x, top, p1.z)), p1, None, uvs)
            pts = [Vector((xp + r * math.cos(2 * math.pi * k / n), top, zr + r * math.sin(2 * math.pi * k / n))) for k in range(n)]
            pi_.face(list(reversed(pts)), (0.9, 0.9, 0.9, 0.0), [(0, 0)] * n)
    # croisillons entre les pieux côté eau
    for i in range(6):
        xa = 0.2 + i * (8.6 / 6)
        xb = xa + 8.6 / 6
        a, b = Vector((xa, -1.6, 2.2)), Vector((xb, -0.3, 2.2))
        d = (b - a).normalized()
        t = Vector((-d.y, d.x, 0)) * 0.05
        e = Vector((0, 0, 0.04))
        pi_.prisme([a - t + e, b - t + e, b + t + e, a + t + e], [a - t - e, b - t - e, b + t - e, a + t - e])
    pi_.objet()


# ------------------------------------------------------------------ pierres plates du gué

def gue():
    rg = random.Random(7859)
    for k in range(3):
        m = Maillage("Gue_%d" % (k + 1))
        ajouter_tris(m, bloc(rg, (0, -0.22, 0), (0.42 + 0.06 * k, 0.3, 0.36 + 0.05 * k), 16, 0.9, 0.42))
        m.objet(neige_auto=True, ao_auto=ao_hauteur(-0.5, 0.0, 0.6), recalc=False)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pont()
    rocher_source()
    seuil()
    roue()
    quai()
    gue()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=SORTIE, export_format='GLB', use_selection=True, export_apply=False,
                              export_normals=True, export_texcoords=True, export_vertex_color='ACTIVE',
                              export_active_vertex_color_when_no_material=True, export_materials='NONE', export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    for ob in bpy.context.scene.objects:
        print("objet", ob.name, len(ob.data.vertices), "sommets", len(ob.data.polygons), "faces")
    print("eau_village ->", SORTIE)


main()
