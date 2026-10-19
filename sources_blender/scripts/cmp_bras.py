import bpy, sys, os
base = r"C:\Users\lopezk19\Jeux\nordique_lot1"
bpy.ops.wm.read_factory_settings(use_empty=False)
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
bpy.ops.import_scene.gltf(filepath=base+r"\assets\modeles\joueur\bras_fps.glb")
arm = [o for o in bpy.data.objects if o.type=='ARMATURE'][0]
print("GLB arm", arm.name, arm.location, arm.rotation_euler, arm.scale, arm.parent)
for n in ("hand_r","head","upperarm_r","index_01_r"):
    b=arm.data.bones.get(n)
    print("GLB", n, tuple(round(x,4) for x in (arm.matrix_world@b.head_local)) if b else None)
for o in bpy.data.objects:
    if o.type=='MESH': print("GLBMESH", o.name, o.parent.name if o.parent else None, [m.type for m in o.modifiers], tuple(round(x,3) for x in o.dimensions))
with bpy.data.libraries.load(base+r"\sources_blender\homme_vetu.blend") as (src, dst):
    dst.objects = [n for n in src.objects]
for o in dst.objects:
    if o.type=='ARMATURE':
        print("HV arm", o.name, o.location, o.rotation_euler, o.scale)
        for n in ("hand_r","head","upperarm_r","index_01_r"):
            b=o.data.bones.get(n)
            print("HV", n, tuple(round(x,4) for x in (o.matrix_world@b.head_local)))
    elif o.name.startswith("Super"):
        print("HVMESH", o.name, tuple(round(x,3) for x in o.dimensions), o.matrix_world.translation)
