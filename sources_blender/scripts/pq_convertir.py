# CHAÎNE PS1 POUR PERSONNAGES / MONSTRES / ANIMAUX QUATERNIUS (CC0)  (essai/persos_quaternius, 2026-11-03)
#   blender.exe -b --python pq_convertir.py -- liste=<persos.json> sortie=<dossier> [seulement=nom1,nom2]
# Sur le modèle de importer_quaternius.py (props), mais le SQUELETTE et les ANIMATIONS sont conservés :
#   1. import (glb / gltf) ; pièces annexes (tête UBC, cheveux) rattachées au squelette principal (mêmes noms d'os) ;
#   2. mise à l'échelle réelle (hauteur cible en m, mesurée en pose de repos, appliquée à l'armature) ;
#   3. réduction (Decimate collapse) au budget de triangles, la tête gardant son quota (visage lisible) ;
#   4. couleur : par face, couleur de base (texture échantillonnée au centre UV d'une copie 256 px, sinon couleur du matériau),
#      « virage nordique » (désaturation, assombrissement, pointe de bleu froid) puis ACCROCHE À LA PALETTE DE LA BIBLE
#      (les 100 couleurs de importer_quaternius.PALETTE) -> aplats nets façon PS1 ; pied sombre ; couleur en sommets (COLOR_0 linéaire) ;
#   5. un seul maillage, un seul matériau sans texture (le jeu pose le shader ps1_perso : grille, affine, texel net) ;
#   6. clips conservés et RENOMMÉS (Idle, Walk, Run, Attack, Death, Hit) en pistes NLA -> glb avec squelette + animations.
import bpy, bmesh, math, os, sys, json, re, colorsys
from mathutils import Vector

ICI = os.path.dirname(os.path.abspath(__file__))


def H(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


PALETTE = [H(c) for c in (
    "#4a557f #6877a3 #8898bf #aab8d6 #cdd7ec #f0eff4 #33577f #4f86ae #86bfd3 #cfeef0 #08161a #10272a #1a3d32 #2c5a41 #5b866f #6e9172 "
    "#241a22 #3a2a2a #54402f #735b43 #947c5e #3b1f24 #6a3524 #9c5129 #cf7b3c #ecaa62 #3d3c4a #5b5a66 #7f7d82 #a7a19b #262a3b #3a4057 "
    "#565b72 #787d8e #a0a2ab #2b1a1e #472a21 #6a4229 #92613a #bb8a53 #211e1c #3b3322 #5c4e2d #82723f #b39d5d #1f1418 #3a261b #5b3d27 "
    "#86603a #1b2a52 #2a4382 #4468ac #7b9ad0 #351520 #5c1f2b #8a2f35 #b9504a #8e8688 #b9ae9f #dbd0b6 #efe7d0 #25262f #3d3e4a #5c5d68 "
    "#85848c #b3b0b4 #20252f #3a4256 #5b6680 #8a96ae #bcc6d8 #4a3419 #7b5a26 #a98638 #d3b25c #5a1a1c #b3341f #ec6a1f #fcb53a #fff0a8 "
    "#0c4a5e #14899b #3fd0d0 #b6fbf0 #030303 #090808 #0f0b08 #14161a").split()]
FROID = H("#4a557f")


def lin(x):
    return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4


def lin2srgb(x):
    return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055


def oklab(c):
    r, g, b = (lin(v) for v in c)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (max(v, 0) ** (1 / 3) for v in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


PAL_LAB = [oklab(c) for c in PALETTE]
_snap_cache = {}


def accrocher(c):
    k = (round(c[0] * 64), round(c[1] * 64), round(c[2] * 64))
    if k in _snap_cache:
        return _snap_cache[k]
    lab = oklab(c)
    best, bi = 9e9, 0
    for i, p in enumerate(PAL_LAB):
        d = 1.4 * (lab[0] - p[0]) ** 2 + (lab[1] - p[1]) ** 2 + (lab[2] - p[2]) ** 2
        if d < best:
            best, bi = d, i
    _snap_cache[k] = PALETTE[bi]
    return PALETTE[bi]


def virage(c, sat, val, froid):
    h, s, v = colorsys.rgb_to_hsv(*c)
    c2 = colorsys.hsv_to_rgb(h, min(1, s * sat), min(1, v * val))
    return tuple(c2[i] * (1 - froid) + FROID[i] * froid * (v * val + 0.25) for i in range(3))


# ------------------------------------------------------------------ import
def vider():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def importer(src):
    avant = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=src)
    for o in list(bpy.context.scene.objects):          # « Icosphere » : forme d'os créée par l'importeur (pas du contenu)
        if o not in avant and o.type == 'MESH' and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
    return [o for o in bpy.context.scene.objects if o not in avant]


def rattacher(objets, arm):
    """Maillages d'un autre fichier (mêmes noms d'os) : rattachés à l'armature principale ; leur armature est supprimée."""
    for o in objets:
        if o.type != 'MESH':
            continue
        mw = o.matrix_world.copy()
        o.parent = arm
        o.matrix_parent_inverse = arm.matrix_world.inverted()
        o.matrix_world = mw
        for m in o.modifiers:
            if m.type == 'ARMATURE':
                m.object = arm
    for o in objets:
        if o.type == 'ARMATURE' and o != arm:
            bpy.data.objects.remove(o, do_unlink=True)


def garder_tete(o, seuil=0.45):
    """Ne garde de la peau UBC que la tête et le cou (poids des os Head + neck_01)."""
    gids = {g.index for g in o.vertex_groups if g.name in ("Head", "neck_01")}
    bm = bmesh.new()
    bm.from_mesh(o.data)
    dl = bm.verts.layers.deform.active
    sup = []
    for f in bm.faces:
        ok = True
        for v in f.verts:
            w = sum(wt for gi, wt in v[dl].items() if gi in gids)
            if w < seuil:
                ok = False
                break
        if not ok:
            sup.append(f)
    bmesh.ops.delete(bm, geom=sup, context='FACES')
    bm.to_mesh(o.data)
    bm.free()


def action_actif(o):
    bpy.context.view_layer.objects.active = o
    for x in bpy.context.view_layer.objects:
        x.select_set(False)
    o.select_set(True)


def sans_shape_keys(o):
    if o.data.shape_keys:
        action_actif(o)
        bpy.ops.object.shape_key_remove(all=True, apply_mix=False)


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def reduire(o, cible):
    n = tris(o)
    if cible >= n:
        return
    sans_shape_keys(o)
    action_actif(o)
    md = o.modifiers.new("reduc", 'DECIMATE')
    md.ratio = max(0.02, cible / n)
    md.use_collapse_triangulate = True
    bpy.ops.object.modifier_move_to_index(modifier=md.name, index=0)
    bpy.ops.object.modifier_apply(modifier=md.name)


def etendue(meshes, arm):
    """(zmin, zmax) en pose de repos (monde Blender, z en haut)."""
    arm.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    zmin, zmax = 9e9, -9e9
    for o in meshes:
        oe = o.evaluated_get(dg)
        me = oe.to_mesh()
        for v in me.vertices:
            z = (oe.matrix_world @ v.co).z
            zmin, zmax = min(zmin, z), max(zmax, z)
        oe.to_mesh_clear()
    return zmin, zmax


# ------------------------------------------------------------------ couleur
_IMG = {}


def pixels(img):
    if img.name not in _IMG:
        c = img.copy()
        m = max(img.size)
        if m > 256:
            f = 256 / m
            c.scale(max(1, int(img.size[0] * f)), max(1, int(img.size[1] * f)))
        w, h = c.size
        _IMG[img.name] = (w, h, list(c.pixels[:]), img.colorspace_settings.name.lower().startswith("srgb"))
        bpy.data.images.remove(c)
    return _IMG[img.name]


def tex_base(mat):
    if not mat or not mat.use_nodes:
        return None, (0.6, 0.6, 0.6), 1.0
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if not bsdf:
        return None, (0.6, 0.6, 0.6), 1.0
    inp = bsdf.inputs[0]
    col = tuple(lin2srgb(x) for x in inp.default_value[:3])
    if inp.links:
        n = inp.links[0].from_node
        for _ in range(4):
            if n.type == "TEX_IMAGE":
                return n.image, col, 1.0
            ins = [i for i in n.inputs if i.links]
            if not ins:
                break
            n = ins[0].links[0].from_node
    return None, col, 1.0


def echantillon(img, uv):
    w, h, px, srgb = pixels(img)
    x = int((uv[0] % 1.0) * w) % w
    y = int((uv[1] % 1.0) * h) % h
    i = (y * w + x) * 4
    c = px[i:i + 3]
    return tuple(lin2srgb(v) for v in c) if srgb else tuple(c)


def colorier(o, cfg, zmin, hauteur):
    """Une couleur (accrochée à la palette) par face -> attribut de couleur par coin (COLOR_0 linéaire)."""
    me = o.data
    sat, val, froid = cfg.get("sat", 0.62), cfg.get("val", 0.85), cfg.get("froid", 0.10)
    over = cfg.get("mats", {})
    pied = cfg.get("pied", 0.7)
    mats = list(me.materials)
    cache = [tex_base(m) for m in mats]
    uvl = me.uv_layers.active
    for c_ in list(me.color_attributes):         # couleurs d'origine (COLOR_0 blanc des glb) : retirées, seule « Col » reste
        me.color_attributes.remove(c_)
    ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
    me.color_attributes.active_color = ca
    me.color_attributes.render_color_index = list(me.color_attributes).index(ca)
    mw = o.matrix_world
    for p in me.polygons:
        mi = p.material_index
        nom = mats[mi].name if mi < len(mats) and mats[mi] else ""
        ov = None
        for k, v in over.items():
            if k in nom:
                ov = H(v)
        if ov is not None:
            c = ov
            gradé = ov
        else:
            img, col, _ = cache[mi] if mi < len(cache) else (None, (0.6, 0.6, 0.6), 1)
            if img is not None and uvl is not None:
                u = sum(uvl.data[li].uv[0] for li in p.loop_indices) / p.loop_total
                v = sum(uvl.data[li].uv[1] for li in p.loop_indices) / p.loop_total
                c = echantillon(img, (u, v))
            else:
                c = col
            gradé = virage(c, sat, val, froid)
        z = (mw @ p.center).z
        f = pied + (1.0 - pied) * max(0.0, min(1.0, (z - zmin) / max(0.15 * hauteur, 0.05)))
        gradé = tuple(max(0.0, min(1.0, x * f)) for x in gradé)
        s = accrocher(gradé)
        l = (lin(s[0]), lin(s[1]), lin(s[2]), 1.0)
        for li in p.loop_indices:
            ca.data[li].color = l
    mat = bpy.data.materials.new("ps1_perso")
    mat.use_nodes = True
    me.materials.clear()
    me.materials.append(mat)
    for p in me.polygons:
        p.material_index = 0


# ------------------------------------------------------------------ animations
CLIPS = {
    "Idle": [r"^Idle$", r"Idle_Loop", r"Flying_Idle", r"_Idle$", r"^Idle_2$", r"ArmatureAction"],
    "Walk": [r"^Walk$", r"_Walk$", r"Fast_Flying", r"Bat_Flying", r"Walk_Loop", r"Gallop$"],
    "Run": [r"^Run$", r"Running", r"^Gallop$", r"Jog_Fwd", r"Run2"],
    "Attack": [r"^Attack$", r"_Attack$", r"Bite_Front", r"^Punch$", r"Headbutt", r"Attack_Headbutt", r"Attack_Kick", r"Weapon"],
    "Death": [r"^Death$", r"_Death$", r"Death01"],
    "Hit": [r"HitRecieve", r"HitReact$", r"^HitReact", r"_Hit$", r"Hit_Chest"],
}


def clips(arm, cfg):
    ad = arm.animation_data
    if ad is None or not bpy.data.actions:
        return []
    voulu = cfg.get("clips", {})
    acts = list(bpy.data.actions)
    choisis = {}
    for cible, motifs in CLIPS.items():
        if cible in voulu:
            a = next((a for a in acts if a.name == voulu[cible] or a.name.split('|')[-1] == voulu[cible]), None)
            if a:
                choisis[cible] = a
            continue
        for mo in motifs:
            a = next((a for a in acts if re.search(mo, a.name.split('|')[-1], re.I)), None)
            if a:
                choisis[cible] = a
                break
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    ad.action = None
    gardes = set(choisis.values())
    copies = {}
    for cible, a in choisis.items():
        c = a.copy()
        c.name = cible
        copies[cible] = c
    for a in acts:
        bpy.data.actions.remove(a)
    for cible, c in copies.items():
        t = ad.nla_tracks.new()
        t.name = cible
        s = t.strips.new(cible, int(c.frame_range[0]), c)
        s.name = cible
    return list(copies)


def _fcurves(act):
    """Blender 5 : fcurves dans les calques/pistes/« channelbags » de l'action."""
    out = []
    for lay in act.layers:
        for st in lay.strips:
            for cb in st.channelbags:
                out.extend(cb.fcurves)
    return out


def peau_os(o, arm):
    """Maillage rigide accroché à un os (bois du cerf, arme…) -> maillage skinné (groupe de sommets = l'os) : peut être fusionné."""
    if o.parent_type == 'BONE' and o.parent_bone and not any(m.type == 'ARMATURE' for m in o.modifiers):
        mw = o.matrix_world.copy()
        os_ = o.parent_bone
        o.parent_type = 'OBJECT'
        o.parent = arm
        o.matrix_parent_inverse = arm.matrix_world.inverted()
        o.matrix_world = mw
        vg = o.vertex_groups.new(name=os_)
        vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
        md = o.modifiers.new("Armature", 'ARMATURE')
        md.object = arm


# ------------------------------------------------------------------ un personnage
def convertir(item, sortie):
    nom = item["nom"]
    vider()
    _IMG.clear()
    objets = importer(item["src"])
    arm = next(o for o in objets if o.type == 'ARMATURE')
    for extra in item.get("extras", []):
        ex = importer(extra["src"])
        for o in list(ex):
            if o.type != 'MESH':
                continue
            pat = extra.get("garder_tete") or extra.get("garder")
            if pat and not re.search(pat, o.name):
                bpy.data.objects.remove(o, do_unlink=True)
            elif extra.get("garder_tete"):
                garder_tete(o)
        ex = [o for o in bpy.context.scene.objects if o in ex]
        rattacher(ex, arm)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in meshes:
        peau_os(o, arm)
    for pat in item.get("retirer", []):
        for o in list(meshes):
            if re.search(pat, o.name):
                bpy.data.objects.remove(o, do_unlink=True)
                meshes.remove(o)
    # budget : la tête garde son quota, le reste se partage la différence
    budget = item.get("budget", 3000)
    caps = item.get("caps", {})

    def cap(o):
        for k, v in caps.items():
            if re.search(k, o.name):
                return v
        return None
    tete = [o for o in meshes if cap(o) is not None]
    autres = [o for o in meshes if o not in tete]
    for o in meshes:
        sans_shape_keys(o)
    n_tete = sum(min(tris(o), cap(o)) for o in tete)
    reste = max(300, budget - n_tete)
    n_autres = sum(tris(o) for o in autres)
    for o in tete:
        reduire(o, cap(o))
    for o in autres:
        if n_autres:
            reduire(o, max(40, int(tris(o) * reste / n_autres)))
    # échelle
    zmin, zmax = etendue(meshes, arm)
    h0 = zmax - zmin
    f = item["hauteur"] / h0 if item.get("hauteur") else 1.0
    if abs(f - 1.0) > 1e-4:
        for o in meshes:
            if o.parent != arm:
                mw = o.matrix_world.copy()
                o.parent = arm
                o.matrix_parent_inverse = arm.matrix_world.inverted()
                o.matrix_world = mw
        arm.scale = arm.scale * f
        for x in bpy.context.scene.objects:
            x.select_set(x == arm)
        bpy.context.view_layer.objects.active = arm
        if not item.get("sans_apply"):
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        for a_ in ([] if item.get("sans_apply") else bpy.data.actions):                 # translations des clips : mêmes unités que le squelette mis à l'échelle
            for fc in a_.fcurves if hasattr(a_, "fcurves") else _fcurves(a_):
                if fc.data_path.endswith("location"):
                    for k in fc.keyframe_points:
                        k.co.y *= f
                        k.handle_left.y *= f
                        k.handle_right.y *= f
                    fc.update()
        bpy.context.view_layer.update()
    zmin, zmax = etendue(meshes, arm)
    haut = zmax - zmin
    for o in meshes:
        colorier(o, item, zmin, haut)
    if item.get("rot_x"):            # rig dont l'export Blender perd une rotation de 90° de l'os Root (démon) : on la remet sur l'armature
        for o in meshes:
            if o.parent != arm:
                mw = o.matrix_world.copy()
                o.parent = arm
                o.matrix_parent_inverse = arm.matrix_world.inverted()
                o.matrix_world = mw
        arm.rotation_euler.x += math.radians(item["rot_x"])
        bpy.context.view_layer.update()
    # un seul maillage
    action_actif(meshes[0])
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    corps = bpy.context.view_layer.objects.active
    corps.name = nom
    mat1 = bpy.data.materials.new("ps1_perso")
    mat1.use_nodes = True
    corps.data.materials.clear()
    corps.data.materials.append(mat1)
    for p_ in corps.data.polygons:
        p_.material_index = 0
    arm.name = "Armature"
    noms = clips(arm, item)
    for pb in arm.pose.bones:                     # pose neutre à l'export (l'importeur laisse l'armature dans la pose du dernier clip)
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    arm.data.pose_position = 'POSE'
    n_t = tris(corps)
    for x in bpy.context.scene.objects:
        x.select_set(x in (arm, corps))
    bpy.context.view_layer.objects.active = arm
    os.makedirs(sortie, exist_ok=True)
    chemin = os.path.join(sortie, nom + ".glb")
    kw = dict(filepath=chemin, export_format='GLB', use_selection=True, export_skins=True, export_apply=False,
              export_animations=bool(noms), export_animation_mode='NLA_TRACKS', export_force_sampling=True,
              export_image_format='NONE')
    for essai in (dict(export_vertex_color='ACTIVE'), dict(export_active_vertex_color_when_no_material=True), {}):
        try:
            bpy.ops.export_scene.gltf(**kw, **essai)
            break
        except TypeError as e:
            print("export kw", essai, e)
    print("PQ %-18s tris=%d os=%d haut=%.2f clips=%s -> %s" % (nom, n_t, len(arm.data.bones), haut, noms, chemin))


def main():
    a = {k: v for k, v in (s.split("=", 1) for s in sys.argv[sys.argv.index("--") + 1:])}
    liste = json.load(open(a["liste"], encoding="utf8"))
    seul = a.get("seulement", "").split(",") if a.get("seulement") else None
    for it in liste:
        if seul and it["nom"] not in seul:
            continue
        try:
            convertir(it, a["sortie"])
        except Exception as e:
            import traceback
            traceback.print_exc()
            print("PQ ECHEC", it["nom"], e)


main()
