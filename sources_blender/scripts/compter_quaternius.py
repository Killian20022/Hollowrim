import bpy, os, sys
racine = sys.argv[sys.argv.index("--") + 1]
out = open(os.path.join(racine, "_triangles.tsv"), "w", encoding="utf8")
for d, _, fs in os.walk(racine):
    for f in sorted(fs):
        l = f.lower()
        if not (l.endswith(".gltf") or (l.endswith(".fbx") and "glTF" not in d and "fantasy_props" not in d and "village_megakit" not in d)):
            continue
        p = os.path.join(d, f)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        try:
            (bpy.ops.import_scene.gltf if l.endswith(".gltf") else bpy.ops.import_scene.fbx)(filepath=p)
            t = sum(sum(len(q.vertices) - 2 for q in o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
        except Exception as e:
            t = -1
        out.write("%s\t%s\t%d\n" % (os.path.relpath(d, racine), f.rsplit(".", 1)[0], t))
out.close()
