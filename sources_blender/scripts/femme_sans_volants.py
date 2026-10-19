# Lot 1 (graphisme) : la tunique de la femme porte deux îlots détachés à hauteur de mollet (z 0,34-0,53 m,
# jusqu'à 41 cm de côté) : des « volants » flottants, absents chez l'homme. On les supprime.
# blender.exe -b femme_vetue.blend --python femme_sans_volants.py   (réécrit le .blend et assets/.../femme_vetue.glb)
import bpy, bmesh, os, shutil
base = r"C:\Users\lopezk19\Jeux\nordique_lot1"
glb = base + r"\assets\modeles\humains\femme_vetue.glb"
orig = base + r"\sources_blender\femme_vetue_original.glb"
if not os.path.exists(orig): shutil.copy(glb, orig)
o = bpy.data.objects["tunique"]
bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
seen=set(); a_suppr=[]
for v in bm.verts:
    if v.index in seen: continue
    comp=[]; st=[v]; seen.add(v.index)
    while st:
        x=st.pop(); comp.append(x)
        for e in x.link_edges:
            y=e.other_vert(x)
            if y.index not in seen: seen.add(y.index); st.append(y)
    zs=[c.co.z for c in comp]
    if max(zs) < 0.6: a_suppr += comp
print("SUPPRIME", len(a_suppr), "sommets")
bm2 = bmesh.new(); bm2.from_mesh(o.data)
bm2.verts.ensure_lookup_table()
idx = {v.index for v in a_suppr}
bmesh.ops.delete(bm2, geom=[bm2.verts[i] for i in idx], context='VERTS')
bm2.to_mesh(o.data); bm2.free(); bm.free()
bpy.ops.object.select_all(action='DESELECT')
for ob in bpy.data.objects:
    if ob.type in ('MESH','ARMATURE'): ob.select_set(True)
bpy.context.view_layer.objects.active = bpy.data.objects["Armature"]
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_skins=True, export_animations=False, export_apply=False)
bpy.ops.wm.save_as_mainfile(filepath=base + r"\sources_blender\femme_vetue.blend")
print("EXPORT OK")
