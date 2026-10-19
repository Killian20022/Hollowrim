# blender.exe -b --python inspecter_glb.py -- fichier.glb : mêmes mesures que inspecter.py sur un glb.
import bpy, bmesh, sys
f = sys.argv[sys.argv.index("--")+1]
bpy.ops.wm.read_factory_settings(use_empty=False)
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
bpy.ops.import_scene.gltf(filepath=f)
print("=== GLB", f)
for o in bpy.data.objects:
    if o.type != 'MESH':
        print("OBJ", o.name, o.type); continue
    me=o.data; bm=bmesh.new(); bm.from_mesh(me)
    bord=[e for e in bm.edges if len(e.link_faces)==1]
    print("MESH %-24s v=%5d f=%5d bord=%4d mats=%s" % (o.name,len(bm.verts),len(bm.faces),len(bord),[m.name if m else None for m in me.materials]))
