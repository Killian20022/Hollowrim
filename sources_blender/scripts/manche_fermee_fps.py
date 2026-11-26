# Manches FERMÉES des bras 1re personne (chantier combat/bras_vide_1p, 2026-11-25). Retour utilisateur : « en vue 1re
# personne, quand je donne un coup, on voit le vide du bras ».
# Cause (outils/audit_bras_vide.gd) : le haut du bras de bras_fps.glb était fait de deux bouts de maillage OUVERTS — « manches »
# (tube de mailles coupé aux deux bouts, bords déchiquetés, 138 sommets) et « peau_bras » (sous-couche de cuir, lambeaux autour
# de l'épaule et du col). Dès que le bras se lève (coups, sorts, arc), la caméra regarde DANS le tube par son bout côté épaule :
# on voit l'intérieur (faces arrière) ou le fond à travers ; entre le bout de la manche (|x| 0,456) et le brassard (|x| 0,468) un
# anneau vide de 1,2 cm, avec une marche de rayon 0,09 -> 0,07.
# Correction : chaque haut de bras devient UNE manche de mailles ÉTANCHE (aucune arête de bord) : dôme d'épaule fermé côté
# corps (hors champ, sous la clavicule), tube le long de l'humérus au rayon de l'ancienne manche, revers qui recouvre le haut du
# brassard (1,8 cm de recouvrement : plus d'anneau vide) et fond fermé à l'intérieur du brassard. Les poids viennent de l'ancien
# maillage (manche + sous-couche, sommet le plus proche) côté bras, du brassard (ab_cuir, os de torsion compris) côté revers :
# les gestes capturés (bras_epee.tres, gestes Mixamo, IK) déforment la nouvelle manche comme l'ancienne. Gant, brassard,
# fourrure, mains : inchangés (aucun sommet touché).
#   blender.exe -b --python manche_fermee_fps.py
#   source : sources_blender/bras_fps_avant_manche_fermee.glb (copie de bras_fps.glb gardée la 1re fois, toujours reprise)
#   sortie : assets/modeles/joueur/bras_fps.glb (mêmes réglages d'export qu'os_torsion_bras.py)
import bpy, bmesh, math, os, shutil
from mathutils import Vector
from mathutils.kdtree import KDTree

base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
glb = os.path.join(base, "assets", "modeles", "joueur", "bras_fps.glb")
SAUVE = os.path.join(base, "sources_blender", "bras_fps_avant_manche_fermee.glb")
if not os.path.exists(SAUVE):
    shutil.copy(glb, SAUVE)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SAUVE)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
objs = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
ANCIENS = ("manches", "peau_bras")

# Profil de la manche (repère du bras GAUCHE, +x vers la main ; le droit en miroir) : (x, rayon) le long de l'axe de
# l'humérus. Rayons de l'ancienne manche de mailles : 0,09-0,12 (épaule, biceps), ~0,09 au coude ; brassard : 0,070 de
# |x| 0,468 à 0,52, puis 0,066.
DOME = 0.075          # sommet du dôme d'épaule (côté corps, sous la clavicule : derrière la caméra, hors champ)
PROFIL = [
    (0.080, 0.045), (0.090, 0.072), (0.105, 0.092), (0.130, 0.104), (0.170, 0.110), (0.220, 0.110),
    (0.270, 0.106), (0.320, 0.101), (0.370, 0.095), (0.410, 0.089), (0.440, 0.084), (0.460, 0.080),
    (0.474, 0.077), (0.486, 0.075),
]
FOND = [(0.488, 0.062), (0.491, 0.040), (0.493, 0.0)]   # fond du revers, à l'intérieur du brassard (r < 0,070) : fermé
N = 14                 # côtés autour du bras (PS1 : peu de côtés, le shader fait le reste)
UV_TOURS = 1.0         # répétitions de la texture de mailles autour du bras (matière : x2)
UV_LONG = 3.2          # répétitions le long du bras (matière : x1)
EPAULE = Vector((0.212, 0.065, 1.455))
COUDE = Vector((0.463, 0.073, 1.456))


def h(i, j):
    x = (i * 73856093) ^ (j * 19349663)
    x = (x ^ (x >> 13)) * 1274126177
    return ((x ^ (x >> 16)) & 0xffff) / 65535.0


def axe(x):
    t = (x - EPAULE.x) / (COUDE.x - EPAULE.x)
    return EPAULE.lerp(COUDE, t)


# --- poids sources : ancienne manche + sous-couche (bras), brassard ab_cuir (revers)
def source_poids(o, mats=None):
    me = o.data
    vg = {g.index: g.name for g in o.vertex_groups}
    ids = set()
    for p in me.polygons:
        if mats is None or me.materials[p.material_index].name.split(".")[0] in mats:
            ids.update(p.vertices)
    pts = []
    for i in ids:
        v = me.vertices[i]
        pts.append((o.matrix_world @ v.co, [(vg[g.group], g.weight) for g in v.groups if g.weight > 1e-4]))
    return pts


def kd(pts):
    t = KDTree(len(pts))
    for k, (co, _) in enumerate(pts):
        t.insert(co, k)
    t.balance()
    return t


src_bras = source_poids(objs["manches"]) + source_poids(objs["peau_bras"])
src_bras_l = [p for p in src_bras if p[0].x > 0]
src_bras_r = [p for p in src_bras if p[0].x < 0]
src_brass_l = source_poids(objs["avant_bras_l"], ("ab_cuir",))
src_brass_r = source_poids(objs["avant_bras_r"], ("ab_cuir",))


def poids_proches(t, pts, co, n=4):
    acc = {}
    tot = 0.0
    for (c, k, d) in t.find_n(co, n):
        w = 1.0 / max(d, 1e-4)
        tot += w
        for g, ww in pts[k][1]:
            acc[g] = acc.get(g, 0.0) + ww * w
    s = sum(acc.values()) or 1.0
    return {g: v / s for g, v in acc.items()}


def melanger(a, b, k):
    r = {}
    for g, v in a.items():
        r[g] = r.get(g, 0.0) + v * (1.0 - k)
    for g, v in b.items():
        r[g] = r.get(g, 0.0) + v * k
    # 4 influences au plus (glTF), renormalisées
    r = dict(sorted(r.items(), key=lambda e: -e[1])[:4])
    s = sum(r.values()) or 1.0
    return {g: v / s for g, v in r.items() if v / s > 1e-3}


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def manche(nom, droite):
    s = -1.0 if droite else 1.0
    pts_b = src_bras_r if droite else src_bras_l
    pts_c = src_brass_r if droite else src_brass_l
    tb, tc = kd(pts_b), kd(pts_c)
    me = bpy.data.meshes.new(nom)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.new("Col")
    anneaux = []
    rangs = PROFIL + FOND
    for j, (x, r) in enumerate(rangs):
        c = axe(x)
        a = []
        if r <= 0.0:
            a.append(bm.verts.new((c.x * s, c.y, c.z)))
        else:
            for i in range(N):
                ang = 2 * math.pi * i / N
                # mailles un peu inégales (bosses de 4 mm au plus) : pas un tuyau parfait
                rr = r * (1.0 + (h(i, j) - 0.5) * 0.06) if 1 <= j <= len(PROFIL) - 3 else r
                # section légèrement aplatie d'avant en arrière, comme un bras (y = profondeur, z = hauteur)
                a.append(bm.verts.new((c.x * s, c.y + math.cos(ang) * rr * 0.92, c.z + math.sin(ang) * rr)))
        anneaux.append(a)
    dome = bm.verts.new((axe(DOME).x * s, axe(DOME).y, axe(DOME).z))
    bm.verts.ensure_lookup_table()

    def face(vs, uvs, cs):
        if droite:
            vs, uvs, cs = vs[::-1], uvs[::-1], cs[::-1]
        f = bm.faces.new(vs)
        f.smooth = True
        f.material_index = 0
        for lo, uv, cc in zip(f.loops, uvs, cs):
            lo[uvl].uv = uv
            lo[col] = (cc, cc, cc, 1.0)
        return f

    def v_uv(x):
        return (x - DOME) / (0.49 - DOME) * UV_LONG

    def occ(x):
        # creux sombres : sous l'aisselle/dans le dôme et sous le revers (occlusion douce, comme les ab_*)
        return 0.62 + 0.18 * smooth(0.08, 0.14, x) - 0.12 * smooth(0.47, 0.488, x)

    # dôme d'épaule : triangles du sommet au 1er anneau (normales vers l'extérieur = vers -x pour le bras gauche)
    a0 = anneaux[0]
    x0 = rangs[0][0]
    for i in range(N):
        i2 = (i + 1) % N
        face([dome, a0[i2], a0[i]], [((i + 0.5) / N * UV_TOURS, 0.0), ((i + 1) / N * UV_TOURS, v_uv(x0)), (i / N * UV_TOURS, v_uv(x0))],
             [0.55, occ(x0), occ(x0)])
    # tube
    for j in range(len(rangs) - 1):
        a, b = anneaux[j], anneaux[j + 1]
        xa, xb = rangs[j][0], rangs[j + 1][0]
        if len(b) == 1:
            for i in range(N):
                i2 = (i + 1) % N
                face([a[i], a[i2], b[0]], [(i / N * UV_TOURS, v_uv(xa)), ((i + 1) / N * UV_TOURS, v_uv(xa)), ((i + 0.5) / N * UV_TOURS, v_uv(xb))],
                     [occ(xa), occ(xa), 0.45])
            continue
        for i in range(N):
            i2 = (i + 1) % N
            face([a[i], a[i2], b[i2], b[i]],
                 [(i / N * UV_TOURS, v_uv(xa)), ((i + 1) / N * UV_TOURS, v_uv(xa)), ((i + 1) / N * UV_TOURS, v_uv(xb)), (i / N * UV_TOURS, v_uv(xb))],
                 [occ(xa), occ(xa), occ(xb), occ(xb)])
    bm.normal_update()
    # étanchéité : aucune arête de bord, aucune arête non-manifold
    bords = [e for e in bm.edges if e.is_boundary or not e.is_manifold]
    assert not bords, "%s : %d arêtes ouvertes" % (nom, len(bords))
    # normales vers l'extérieur (maillage fermé : recalcul cohérent), contrôlées au milieu du bras
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        c = f.calc_center_median()
        if 0.15 < abs(c.x) < 0.42:
            ax = axe(abs(c.x))
            assert f.normal.dot(c - Vector((ax.x * s, ax.y, ax.z))) > 0, "%s : face retournée" % nom
    bm.to_mesh(me)
    bm.free()
    me.materials.append(bpy.data.materials.get("tunique") or bpy.data.materials.new("tunique"))
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    o.parent = arm
    o.matrix_parent_inverse = arm.matrix_world.inverted()
    for v in me.vertices:
        x = abs(v.co.x)
        wb = poids_proches(tb, pts_b, v.co)
        wc = poids_proches(tc, pts_c, v.co)
        # haut du bras : l'ancienne manche donnait déjà 57 % d'avant-bras à 5 cm AVANT le coude (|x| 0,41) -> pli retourné
        # au creux du coude quand il plie fort (audit : triangle intérieur visible au coup 2). Ici : pas d'avant-bras avant
        # 0,40, puis un coude « charnière » (moitié bras / moitié avant-bras au pli, |x| 0,463)
        cote = "_r" if droite else "_l"
        wb = {g: q for g, q in wb.items() if not g.startswith("lowerarm")} or {"upperarm" + cote: 1.0}
        wb = melanger(wb, {}, 0.0)   # renormalisé
        # épaule : l'ancienne sous-couche mêlait clavicule, colonne et cou (45/24/6 %) au dôme -> quand le bras passe
        # devant le corps (revers, coup 2), le dôme restait derrière et se repliait en pointe retournée juste sous l'œil.
        # Ici le dôme est une ROTULE : il tourne avec l'humérus, la clavicule n'en garde qu'un peu au sommet (côté corps).
        if x < 0.27:
            rotule = melanger({"upperarm" + cote: 1.0}, {"clavicle" + cote: 1.0}, 0.3 * (1.0 - smooth(0.08, 0.2, x)))
            wb = melanger(rotule, wb, smooth(0.2, 0.27, x))
        wb = melanger(wb, {"lowerarm" + cote: 1.0}, 0.5 * smooth(0.40, 0.463, x))
        # bras -> revers : le revers (|x| >= 0,474) suit le brassard qu'il recouvre (il ne glisse pas dessus au coude)
        w = melanger(wb, wc, smooth(0.455, 0.476, x))
        for g, ww in w.items():
            vg = o.vertex_groups.get(g) or o.vertex_groups.new(name=g)
            vg.add([v.index], ww, 'REPLACE')
    mod = o.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("MANCHE", nom, len(me.vertices), "sommets", tris, "triangles, étanche")
    return o


# les anciens morceaux ouverts sont remplacés (copie gardée dans SAUVE)
nouv_l = manche("manche_l", False)
nouv_r = manche("manche_r", True)
for n in ANCIENS:
    bpy.data.objects.remove(objs[n])
# un seul maillage « manches » (nom lu par les tests de torsion), deux bras
bpy.ops.object.select_all(action='DESELECT')
nouv_l.select_set(True)
nouv_r.select_set(True)
bpy.context.view_layer.objects.active = nouv_l
bpy.ops.object.join()
nouv_l.name = "manches"
nouv_l.data.name = "manches"


# --- avant-bras : bouts de gant fermés, petites pièces de fer remises à l'endroit (aucun sommet déplacé)
# Audit après les manches : restaient ~200-450 px d'intérieur par image, aux poignets : (1) l'ouverture du poignet de la
# main MakeHuman (boucle de 24 arêtes, rayon jusqu'à 0,062 côté pouce) dépasse du revers du gant -> on voit dans la main ;
# (2) le bord du revers (38 arêtes) ; (3) boucles, rivets et sangles plats du brassard dont les faces regardaient l'axe du bras
# (normales retournées : la matière est double face, l'image est la même, mais c'est une face arrière vue). Correction : les deux
# bords du gant reçoivent un fond en éventail (sommet central aux poids et UV moyens des bords, couleur de creux), les faces
# des pièces plates tournées vers l'axe sont retournées. Les cartes de fourrure (une face, double face voulue) ne changent pas.
AXE_B = Vector((0.463, 0.073, 1.456))
AXE_C = Vector((0.706, 0.065, 1.456))
PLATES = ("ab_fer", "ab_sangle", "ab_metal")


def axe_av(x):
    return AXE_B + (AXE_C - AXE_B) * ((x - AXE_B.x) / (AXE_C.x - AXE_B.x))


def fermer_avant_bras(o):
    me = o.data
    s = 1.0 if o.name.endswith("_l") else -1.0
    mats = [m.name.split(".")[0] for m in me.materials]
    vg = {g.index: g.name for g in o.vertex_groups}
    poids = {v.index: {vg[g.group]: g.weight for g in v.groups} for v in me.vertices}
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv.active
    col = bm.loops.layers.color.active
    dl = bm.verts.layers.deform.verify()
    # 1. pièces plates : chaque pièce FERMÉE (cadre de boucle, rivet) reçoit des normales cohérentes vers l'extérieur
    # (recalc), chaque pièce OUVERTE (plaque, sangle à une face) a sa face visible tournée vers l'extérieur du bras
    plates = [f for f in bm.faces if mats[f.material_index] in PLATES]
    vus_f = set()
    tournees = []
    for f0 in plates:
        if f0 in vus_f:
            continue
        comp = []
        pile = [f0]
        while pile:
            f = pile.pop()
            if f in vus_f:
                continue
            vus_f.add(f)
            comp.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g not in vus_f and mats[g.material_index] in PLATES:
                        pile.append(g)
        ouverte = any(e.is_boundary for f in comp for e in f.edges)
        if not ouverte:
            bmesh.ops.recalc_face_normals(bm, faces=comp)
            continue
        for f in comp:
            c = f.calc_center_median()
            a = axe_av(abs(c.x))
            radial = Vector((0.0, c.y - a.y, c.z - a.z)).normalized()
            if f.normal.dot(radial) < -0.3:
                tournees.append(f)
    bmesh.ops.reverse_faces(bm, faces=tournees)
    # 2. bords du gant fermés
    ig = mats.index("ab_gant")
    bords = [e for e in bm.edges if e.is_boundary and e.link_faces[0].material_index == ig]
    vus = set()
    fonds = 0
    for e0 in bords:
        if e0 in vus:
            continue
        # boucle ordonnée
        boucle = [e0.verts[0], e0.verts[1]]
        vus.add(e0)
        while True:
            v = boucle[-1]
            nxt = [e for e in v.link_edges if e.is_boundary and e not in vus and e.link_faces[0].material_index == ig]
            if not nxt:
                break
            e = nxt[0]
            vus.add(e)
            w = e.other_vert(v)
            if w == boucle[0]:
                break
            boucle.append(w)
        if len(boucle) < 3:
            continue
        centre = sum((v.co for v in boucle), Vector()) / len(boucle)
        vc = bm.verts.new(centre)
        acc = {}
        for v in boucle:
            for g, w in poids.get(v.index, {}).items():
                acc[g] = acc.get(g, 0.0) + w / len(boucle)
        # sens des faces : celui de la face voisine (bord parcouru à l'envers de sa face)
        f0 = e0.link_faces[0]
        lo = next(l for l in f0.loops if l.edge == e0)
        meme_sens = lo.vert == boucle[0]
        for k in range(len(boucle)):
            a, b = boucle[k], boucle[(k + 1) % len(boucle)]
            vs = [b, a, vc] if meme_sens else [a, b, vc]
            try:
                nf = bm.faces.new(vs)
            except ValueError:
                continue
            nf.material_index = ig
            nf.smooth = True
            for l in nf.loops:
                src = l.vert.link_loops[0] if l.vert != vc else None
                if src is not None and src.face is not None and src.face != nf:
                    l[uvl].uv = src[uvl].uv
                    l[col] = src[col]
                else:
                    uv = Vector((0.0, 0.0))
                    for v in boucle:
                        uv += v.link_loops[0][uvl].uv
                    l[uvl].uv = uv / len(boucle)
                    l[col] = (0.35, 0.35, 0.35, 1.0)
        fonds += 1
        # les deux bords s'ouvrent vers le COUDE : chaque face du fond regarde vers le coude (-x pour le bras gauche)
        neuves = list(vc.link_faces)
        for f in neuves:
            f.normal_update()
        a_tourner = [f for f in neuves if f.normal.x * s > 0]
        bmesh.ops.reverse_faces(bm, faces=a_tourner)
        print("FOND", o.name, len(boucle), "sommets,", len(a_tourner), "faces remises vers le coude sur", len(neuves))
        vc[dl].clear()
        for g, w in acc.items():
            gi = o.vertex_groups[g].index
            vc[dl][gi] = w
    # 2b. FOND DU BRASSARD au poignet : un disque de cuir sombre (16 côtés, r 0,0505 = intérieur des derniers tours
    # tressés, |x| 0,712) tourné vers la main, rigide avec le brassard. L'arc ramène la main à sa taille source (1/1,3) :
    # le revers du gant ne recouvre plus le bout du brassard, et l'avant-bras d'arc vu depuis la main montrait le tube vide
    # (audit : anneau intérieur de 170-290 px en bas d'écran pendant le tir). Caché sous le gant et les tours ailleurs.
    it = mats.index("ab_tresse")
    pts_t = [(v.co.copy(), list(poids.get(v.index, {}).items())) for v in bm.verts if any(f.material_index == it for f in v.link_faces)]
    kt = kd(pts_t)
    xd = 0.712
    cd_ = axe_av(xd)
    centre = bm.verts.new((cd_.x * s, cd_.y, cd_.z))
    anneau = []
    for i in range(16):
        a = 2 * math.pi * i / 16
        anneau.append(bm.verts.new((cd_.x * s, cd_.y + math.cos(a) * 0.0505, cd_.z + math.sin(a) * 0.0505)))
    disque = []
    for i in range(16):
        f = bm.faces.new([centre, anneau[i], anneau[(i + 1) % 16]])
        f.material_index = ig
        f.smooth = True
        disque.append(f)
        for l in f.loops:
            l[uvl].uv = (0.5 + (l.vert.co.y - cd_.y) * 4.0, 0.5 + (l.vert.co.z - cd_.z) * 4.0)
            l[col] = (0.3, 0.3, 0.3, 1.0)
        f.normal_update()
    bmesh.ops.reverse_faces(bm, faces=[f for f in disque if f.normal.x * s < 0])   # vers la main
    for v in [centre] + anneau:
        w = poids_proches(kt, pts_t, v.co)
        v[dl].clear()
        for g, ww in w.items():
            v[dl][o.vertex_groups[g].index] = ww
    # 2c. TAMPON DE POIGNET : un petit volume fermé de cuir (|x| 0,690 -> 0,726, r 0,046 -> 0,030), rigide avec le
    # brassard, dans le poignet du gant. Main à sa taille d'origine : il est dedans. Arc (main ramenée à 1/1,3) : il bouche
    # le croissant qui s'ouvrait entre le dos de la main et le bout du brassard (on y voyait l'intérieur du revers).
    prof = [(0.690, 0.046), (0.700, 0.045), (0.710, 0.040), (0.718, 0.034), (0.724, 0.026)]
    anneaux = []
    for xx, rr in prof:
        c0 = axe_av(xx)
        anneaux.append([bm.verts.new((c0.x * s, c0.y + math.cos(2 * math.pi * i / 12) * rr * 0.9, c0.z + math.sin(2 * math.pi * i / 12) * rr)) for i in range(12)])
    bouts = []
    for xx in (0.686, 0.727):
        c0 = axe_av(xx)
        bouts.append(bm.verts.new((c0.x * s, c0.y, c0.z)))
    tampon = []
    for j in range(len(anneaux) - 1):
        for i in range(12):
            tampon.append(bm.faces.new([anneaux[j][i], anneaux[j][(i + 1) % 12], anneaux[j + 1][(i + 1) % 12], anneaux[j + 1][i]]))
    for i in range(12):
        tampon.append(bm.faces.new([bouts[0], anneaux[0][(i + 1) % 12], anneaux[0][i]]))
        tampon.append(bm.faces.new([bouts[1], anneaux[-1][i], anneaux[-1][(i + 1) % 12]]))
    bmesh.ops.recalc_face_normals(bm, faces=tampon)
    for f in tampon:
        f.material_index = ig
        f.smooth = True
        for l in f.loops:
            l[uvl].uv = (0.5 + (l.vert.co.y - cd_.y) * 4.0, 0.5 + (l.vert.co.z - cd_.z) * 4.0)
            l[col] = (0.4, 0.4, 0.4, 1.0)
    for v in bouts + [v for a in anneaux for v in a]:
        w = poids_proches(kt, pts_t, v.co)
        v[dl].clear()
        for g, ww in w.items():
            v[dl][o.vertex_groups[g].index] = ww
    # 3. ÉPAISSEUR du gant, des tours tressés et de la coque du brassard : une doublure intérieure (copie retournée, 1,5 mm
    # vers l'intérieur, mêmes poids et UV) ; quand le poignet plie, l'ouverture du revers côté paume laissait voir le dos
    # de sa face (audit : croissant de 90-180 px aux sorts de la main gauche). Il y a désormais une face de cuir de chaque côté.
    bm.faces.ensure_lookup_table()
    # v2 : toute la main gantée, les tours tressés et la coque du brassard (bouts ouverts, fente) : audit, restaient 10-200 px
    # aux poignets (arc : main ramenée à sa taille source, l'ouverture du revers s'écarte ; claymore : bout des tours tressés)
    doubles = [mats.index(n) for n in ("ab_gant", "ab_tresse", "ab_cuir")]
    poignet = [f for f in bm.faces if f.material_index in doubles]
    bm.normal_update()
    dup = bmesh.ops.duplicate(bm, geom=poignet)
    nf = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)]
    nv = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.reverse_faces(bm, faces=nf)
    for f in nf:
        f.normal_update()
    for v in nv:
        v.normal_update()
    normales = {v: v.normal.copy() for v in nv}   # copie retournée : normales vers l'intérieur de la main
    for v in nv:
        v.co += normales[v] * 0.0015
    print("DOUBLURE", o.name, len(nf), "faces")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    print("AVANT_BRAS", o.name, "faces retournées", len(tournees), "fonds de gant", fonds)


for n in ("avant_bras_l", "avant_bras_r"):
    fermer_avant_bras(bpy.data.objects[n])

bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
kw = dict(filepath=glb, export_format='GLB', use_selection=True, export_skins=True, export_animations=False,
          export_apply=False)
try:
    bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
except TypeError:
    bpy.ops.export_scene.gltf(**kw)
print("EXPORT OK", glb)
