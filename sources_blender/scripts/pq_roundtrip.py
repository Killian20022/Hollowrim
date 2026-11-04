import bpy, sys
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0], **({'bone_heuristic': [x for x in a if x in ('TEMPERANCE','FORTUNE','BLENDER')][0]} if any(x in a for x in ('TEMPERANCE','FORTUNE','BLENDER')) else {}))
for o in list(bpy.context.scene.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)
arm=[o for o in bpy.context.scene.objects if o.type=='ARMATURE'][0]
print("RT arm", tuple(arm.scale), tuple(arm.rotation_euler), [ (o.name, tuple(round(x,3) for x in o.scale), o.parent and o.parent.name, o.parent_type) for o in bpy.context.scene.objects if o.type=='MESH'])
if 'apply' in a:
    for o in bpy.context.scene.objects: o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
kw = dict(filepath=a[1], export_format='GLB', export_skins=True, export_animation_mode=a[2] if len(a) > 2 else 'ACTIONS', export_force_sampling=("nosamp" not in a))
bpy.ops.export_scene.gltf(**kw)
