# Lot 1 (graphisme) : ajoute à bras_fps.glb une « sous-couche » (peau des bras et des mains, tirée du corps
# homme_vetu.blend, rentrée sous l'étoffe), sinon les manches/brassards/gants (coques ouvertes) laissent
# voir le ciel entre eux et à travers la main.
# blender.exe -b --python bras_sous_couche.py     (ré-exporte assets/modeles/joueur/bras_fps.glb)
import bpy, bmesh, os
base = r"C:\Users\lopezk19\Jeux\nordique_lot1"
glb = base + r"\assets\modeles\joueur\bras_fps.glb"
SAUVE = base + r"\sources_blender\bras_fps_original.glb"
if not os.path.exists(SAUVE):
    import shutil; shutil.copy(glb, SAUVE)   # état d'avant le lot 1, conservé
bpy.ops.wm.read_factory_settings(use_empty=False)
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
bpy.ops.import_scene.gltf(filepath=SAUVE)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
with bpy.data.libraries.load(base + r"\sources_blender\homme_vetu.blend") as (src, dst):
    dst.objects = ["SuperHero_Male"]
corps = dst.objects[0]
bpy.context.scene.collection.objects.link(corps)

HAND = ("hand_",)   # paume seulement : les doigts sont trop fins (le gant colle ou rentre dans la peau), le gant creux suffit
ARM = ("upperarm_", "lowerarm_", "clavicle_")
def classe(nom):
    if nom.startswith(HAND) and nom[-2:] in ("_r", "_l"): return "hand"
    if nom.startswith(ARM) or "twist" in nom: return "arm"
    return None

me = corps.data
noms = {g.index: g.name for g in corps.vertex_groups}
poids = []
for v in me.vertices:
    h = a = 0.0; tot = 0.0
    for g in v.groups:
        c = classe(noms[g.group]); tot += g.weight
        if c == "hand": h += g.weight
        elif c == "arm": a += g.weight
    poids.append((h, a, tot))
def garde(i):
    h, a, t = poids[i]
    return t > 0 and (h + a) / t >= 0.6
bm = bmesh.new(); bm.from_mesh(me)
bm.verts.ensure_lookup_table()
sup = [f for f in bm.faces if not all(garde(v.index) for v in f.verts)]
bmesh.ops.delete(bm, geom=sup, context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.normal_update()
# rentrée : 1,6 cm sous la manche (avant-bras, bras), 0,8 cm sous le gant (paume)
orig = {v.index: poids[v.index] for v in bm.verts}
for v in bm.verts:
    h, a, t = orig[v.index]
    s = (h + a) or 1.0
    d = 0.016 * (a / s) + 0.008 * (h / s)
    v.co -= v.normal * d
bm.to_mesh(me); bm.free()
corps.name = "peau_bras"; me.name = "peau_bras"
me.materials.clear()
mat = bpy.data.materials.new("sous_couche"); me.materials.append(mat)
corps.parent = arm
for m in list(corps.modifiers): corps.modifiers.remove(m)
mod = corps.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
print("PEAU_BRAS verts", len(me.vertices), "faces", len(me.polygons))

for o in list(bpy.data.objects):
    if o.name.startswith("Armature.") or o.name == "Icosphere":   # armature importée avec le corps ; forme d'os de l'importeur
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type == 'ARMATURE' or o.name in ("brassards", "gants", "manches", "peau_bras"):
        o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_skins=True,
                          export_animations=False, export_apply=False)
bpy.ops.wm.save_as_mainfile(filepath=base + r"\sources_blender\bras_fps.blend")
print("EXPORT OK")
