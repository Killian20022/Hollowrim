# Ennemis Tripo animés (draugr, archer, squelette, gobelin) : habillage du squelette nordique (65 os de homme_vetu.glb), poids automatiques, pose A -> T cuite.
#   blender.exe -b --python tripo_ennemi_rig.py -- --modele=draugr|archer|squelette|gobelin [--debug=<dossier>] [--mains-rigides=1] [--avec-arme=1]
#   Squelette du jeu : --modele=squelette --mains-rigides=1 (l'arme Tripo restée dans sa main gauche est retirée, voir RETIRER plus bas).
# Entrée : assets/pnj/ennemis/tripo_<modele>.glb (sortie de tripo_ennemi_prep.py, pieds à z=0, face -Y). Sortie : tripo_<modele>_rig.glb.
# Dérivé de tripo_rig.py (gardes) sans tabard ni arme : l'arme est celle du jeu, posée dans Godot (BoneAttachment3D sur hand_r).
import bpy, bmesh, math, os, sys
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, kdtree

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=""):
    return next((a.split("=", 1)[1] for a in ARGS if a.startswith("--" + n + "=")), d)
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELE = arg("modele", "draugr")
SRC = os.path.join(BASE, "assets", "pnj", "ennemis", "tripo_%s.glb" % MODELE)
HUMAIN = os.path.join(BASE, "assets", "modeles", "humains", "homme_vetu.glb")
OUT_GLB = arg("sortie", os.path.join(BASE, "assets", "pnj", "ennemis", "tripo_%s_rig.glb" % MODELE))
# Position approximative de chaque main en pose A (mesurée sur les vues de face) : oriente les os des bras.
CONF = {
    "draugr": dict(mains={"r": (-0.37, -0.03, 0.88), "l": (0.37, -0.03, 0.88)}),
    "archer": dict(mains={"r": (-0.35, -0.03, 0.86), "l": (0.34, -0.03, 0.86)}),
    "squelette": dict(mains={"r": (-0.35, -0.03, 0.90), "l": (0.33, -0.03, 0.86)}),
    "gobelin": dict(mains={"r": (-0.52, -0.03, 0.69), "l": (0.52, -0.03, 0.69)}),
}[MODELE]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
garde = next(o for o in bpy.data.objects if o.type == "MESH")
me = garde.data
nv = len(me.vertices)
P = np.array([v.co[:] for v in me.vertices])
x, y, z = P[:, 0], P[:, 1], P[:, 2]
print("maillage :", nv, "sommets,", len(me.polygons), "tris")

# ---------------------------------------------------------------- 1. squelette : humain en T -> pose A
bpy.ops.import_scene.gltf(filepath=HUMAIN)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.type == "MESH" and o != garde:
        bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = arm
for o in bpy.context.selected_objects:
    o.select_set(False)
arm.select_set(True)

# rotation de chaque bras : de la direction du T (±x) vers l'épaule -> main mesurée
ROT = {}
bpy.ops.object.mode_set(mode="POSE")
for s, sg in (("l", 1), ("r", -1)):
    h = arm.matrix_world @ arm.pose.bones["upperarm_" + s].head
    d = (Vector(CONF["mains"][s]) - h).normalized()
    ROT[s] = Vector((sg, 0, 0)).rotation_difference(d)
    print("bras", s, "angle depuis le T : %.1f deg" % math.degrees(ROT[s].angle))
    q = ROT[s]      # même rotation dans le repère de Godot (x, y, z)gltf = (x, z, -y)blender : sert à figer le bras dans scripts/garde_tripo.gd
    print("ROTGODOT", s, "Quaternion(%.5f, %.5f, %.5f, %.5f)" % (q.x, q.z, -q.y, q.w))
def arms(inverse):
    bpy.ops.object.mode_set(mode="POSE")
    for s in ("l", "r"):
        pb = arm.pose.bones["upperarm_" + s]
        h = arm.matrix_world @ pb.head
        q = ROT[s].inverted() if inverse else ROT[s]
        pb.matrix = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ pb.matrix
        bpy.context.view_layer.update()
    if not inverse:
        bpy.ops.pose.armature_apply()
    bpy.ops.object.mode_set(mode="OBJECT")
arms(False)
if arg("diag"):
    for s_ in ("r", "l"):
        for n_ in ("upperarm_", "lowerarm_", "hand_", "middle_01_", "middle_03_"):
            b_ = arm.data.bones[n_ + s_]
            print("DIAG", n_ + s_, "head", tuple(round(a, 3) for a in (arm.matrix_world @ b_.head_local)), "tail", tuple(round(a, 3) for a in (arm.matrix_world @ b_.tail_local)))
    for sg_ in (-1, 1):
        sel_ = P[(sg_ * x > 0.25) & (z > 0.55) & (z < 1.25)]
        print("DIAG maillage bras", sg_, "n", len(sel_), "z min %.3f max %.3f" % (sel_[:, 2].min(), sel_[:, 2].max()))
        for zc in np.arange(0.6, 1.2, 0.05):
            t_ = sel_[(sel_[:, 2] >= zc) & (sel_[:, 2] < zc + 0.05)]
            if len(t_): print("DIAG  z %.2f : x %.3f..%.3f  y %.3f..%.3f  n %d" % (zc, t_[:, 0].min(), t_[:, 0].max(), t_[:, 1].min(), t_[:, 1].max(), len(t_)))

# jambes : décalage en x (translation seule, l'orientation des os et donc les clips ne change pas), mesuré sur les cuisses et les bottes
def jambe_x(sg):
    cuisse = P[(z > 0.70) & (z < 0.90) & (sg * x > 0.03) & (np.abs(x) < 0.30) & (y > -0.12) & (y < 0.12)]
    botte = P[(z > 0.04) & (z < 0.30) & (sg * x > 0.03) & (np.abs(x) < 0.32) & (y > -0.2) & (y < 0.2)]
    return (abs(float(cuisse[:, 0].mean())) + abs(float(botte[:, 0].mean()))) / 2.0
bpy.ops.object.mode_set(mode="EDIT")
for s, sg in (("l", 1), ("r", -1)):
    dx = jambe_x(sg) - 0.114
    print("jambe", s, "décalage x : %.3f" % dx)
    for nom in ("thigh", "calf", "foot", "ball", "ball_leaf"):
        eb = arm.data.edit_bones[nom + "_" + s]
        eb.head.x += sg * dx
        eb.tail.x += sg * dx
bpy.ops.object.mode_set(mode="OBJECT")
for b in arm.data.bones:
    n = b.name
    b.use_deform = not (n == "root" or n.endswith("_leaf_l") or n.endswith("_leaf_r") or
                        any(n.startswith(f) for f in ("index_", "middle_", "pinky_", "ring_", "thumb_")))

# ---------------------------------------------------------------- 2. poids du corps (auto, copie soudée : le maillage est découpé par îlots UV)
cp_me = me.copy()
cp = bpy.data.objects.new("soude", cp_me)
bpy.context.scene.collection.objects.link(cp)
bm = bmesh.new(); bm.from_mesh(cp_me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
bm.to_mesh(cp_me); bm.free()
for o in bpy.context.selected_objects:
    o.select_set(False)
cp.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
gn = {g.index: g.name for g in cp.vertex_groups}
kd = kdtree.KDTree(len(cp_me.vertices))
for v in cp_me.vertices:
    kd.insert(v.co, v.index)
kd.balance()
body = []
for i in range(nv):
    _, j, _ = kd.find(Vector(P[i]))
    body.append({gn[g.group]: g.weight for g in cp_me.vertices[j].groups if g.weight > 1e-4})
sans = [i for i in range(nv) if not body[i]]
print("poids auto : sommets sans poids :", len(sans))
if sans:        # éclats isolés (hors de la copie soudée) : ils prennent les poids du sommet pondéré le plus proche
    kdp = kdtree.KDTree(nv - len(sans))
    for i in range(nv):
        if body[i]:
            kdp.insert(Vector(P[i]), i)
    kdp.balance()
    for i in sans:
        body[i] = body[kdp.find(Vector(P[i]))[1]]
bpy.data.objects.remove(cp)

# ---------------------------------------------------------------- 3. poids finals = poids du corps (4 influences max)
final = []
for i in range(nv):
    top = sorted(body[i].items(), key=lambda kv: -kv[1])[:4]
    tot = sum(v for _, v in top) or 1.0
    final.append([(n_, v / tot) for n_, v in top if v / tot > 0.015])
# mains rigides (--mains-rigides) : sans cela, les poids automatiques étalent la main sur l'avant-bras et le poignet, et la cuisson A -> T écrase
# les doigts en moignons. Tout ce qui dépasse le poignet (le long de l'avant-bras, en pose A) suit l'os de la main à 100 %.
if arg("mains-rigides"):
    for s_, sg_ in (("r", -1), ("l", 1)):
        hb_ = arm.data.bones["hand_" + s_]
        wr_ = np.array((arm.matrix_world @ hb_.head_local)[:])
        u_ = wr_ - np.array((arm.matrix_world @ arm.data.bones["lowerarm_" + s_].head_local)[:])
        u_ /= np.linalg.norm(u_)
        nrig_ = 0
        for i in range(nv):
            if sg_ * x[i] < 0.2:
                continue
            d_ = P[i] - wr_
            t_ = float(d_ @ u_)
            r_ = float(np.linalg.norm(d_ - t_ * u_))
            if t_ > float(arg("mains-poignet", "-0.03")) and r_ < 0.14:
                final[i] = [("hand_" + s_, 1.0)]
                nrig_ += 1
        print("mains rigides", s_, ":", nrig_, "sommets")
for g in list(garde.vertex_groups):
    garde.vertex_groups.remove(g)
groupes = {}
for i, lst in enumerate(final):
    for n_, v_ in lst:
        if n_ not in groupes:
            groupes[n_] = garde.vertex_groups.new(name=n_)
        groupes[n_].add([i], v_, "REPLACE")
garde.parent = arm
garde.matrix_parent_inverse = Matrix.Identity(4)
for md in list(garde.modifiers):
    garde.modifiers.remove(md)
md = garde.modifiers.new("Armature", "ARMATURE")
md.object = arm

# ---------------------------------------------------------------- 5. cuisson en T (clips des humains) puis export
bpy.context.view_layer.objects.active = arm
arms(True)
for o in bpy.context.selected_objects:
    o.select_set(False)
bpy.context.view_layer.objects.active = garde
garde.select_set(True)
bpy.ops.object.modifier_apply(modifier="Armature")
md = garde.modifiers.new("Armature", "ARMATURE")
md.object = arm
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.armature_apply()
bpy.ops.object.mode_set(mode="OBJECT")
garde.name = "tripo_" + MODELE
arm.name = "Armature"

# ---------------------------------------------------------------- 6. reste de l'arme Tripo fondu dans le corps : retiré par îlots, après la cuisson
# (repère en T de la sortie : bras le long de ±x, mains vers z = 1,4) ; les poids des autres sommets ne changent pas.
# Îlot = composante connexe de faces après soudure des sommets par position (0,5 mm), comme outils/controle_modele.gd.
# Critère : n (faces), mn, mx (boîte de l'îlot) -> True pour l'îlot à retirer. --avec-arme=1 : sortie d'avant la correction.
RETIRER = {
    # lame sombre que le modèle source tient dans la main gauche (elle pend sous la main en pose A) : 7 îlots, 130 faces. Ses poids
    # mêlés main / cuisse la faisaient passer devant les jambes en course. La main (phalanges repliées) reste intacte.
    "squelette": [("lame de la main gauche", lambda n, mn, mx: mn.x > 0.45 and mn.z < 1.30)],
}.get(MODELE, [])
if RETIRER and not arg("avec-arme"):
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    cle_, rep_ = {}, []
    for v in bm.verts:
        rep_.append(cle_.setdefault(tuple(round(c_ / 0.0005) for c_ in v.co), v.index))
    par_ = list(range(len(bm.verts)))
    def rac_(i):
        while par_[i] != i:
            par_[i] = par_[par_[i]]; i = par_[i]
        return i
    for f_ in bm.faces:
        r0_ = rac_(rep_[f_.verts[0].index])
        for v in f_.verts[1:]:
            r1_ = rac_(rep_[v.index])
            if r1_ != r0_:
                par_[r1_] = r0_
    ilots_ = {}
    for f_ in bm.faces:
        ilots_.setdefault(rac_(rep_[f_.verts[0].index]), []).append(f_)
    a_suppr = set()
    for desc_, crit_ in RETIRER:
        nf_, ni_ = 0, 0
        for fs_ in ilots_.values():
            co_ = [v.co for f_ in fs_ for v in f_.verts]
            mn_ = Vector([min(c_[k] for c_ in co_) for k in range(3)])
            mx_ = Vector([max(c_[k] for c_ in co_) for k in range(3)])
            if crit_(len(fs_), mn_, mx_):
                a_suppr.update(fs_); nf_ += len(fs_); ni_ += 1
        print("arme retirée (%s) : %d îlots, %d faces" % (desc_, ni_, nf_))
    bmesh.ops.delete(bm, geom=list(a_suppr), context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me); bm.free(); me.update()

# ---------------------------------------------------------------- 7. îlots du poignet raccordés à leur surface (raccord_ilots.py : posés sur le voisin
# à <= 4 mm et mêmes poids, rien n'est supprimé) ; modèles listés ici seulement, les autres sortent comme avant. --sans-raccord=1 : sans.
if MODELE in ("squelette", "draugr") and not arg("sans-raccord"):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import raccord_ilots
    raccord_ilots.raccorder(garde, arm)

if arg("blend"):
    bpy.ops.wm.save_as_mainfile(filepath=arg("blend"))
for o in bpy.context.selected_objects:
    o.select_set(False)
arm.select_set(True)
garde.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_skins=True, export_animations=False, export_apply=False)
print("EXPORT OK", OUT_GLB, "tris", len(me.polygons), "os", len(arm.data.bones))
