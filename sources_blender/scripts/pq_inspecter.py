import bpy,sys,os,glob
files=sys.argv[sys.argv.index("--")+1:]
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        if f.endswith(('.glb','.gltf')): bpy.ops.import_scene.gltf(filepath=f)
        else: bpy.ops.import_scene.fbx(filepath=f)
    except Exception as e:
        print("INSP",os.path.basename(f),"ERR",e); continue
    ms=[o for o in bpy.context.scene.objects if o.type=='MESH']
    tris=sum(len(o.data.polygons) for o in ms)  # approx
    arm=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
    from mathutils import Vector
    mn=Vector((1e9,)*3);mx=Vector((-1e9,)*3)
    for o in ms:
        for c in o.bound_box:
            w=o.matrix_world@Vector(c)
            mn=Vector(map(min,mn,w));mx=Vector(map(max,mx,w))
    acts=[a.name for a in bpy.data.actions]
    bones=len(arm[0].data.bones) if arm else 0
    print("INSP",os.path.basename(f),"| polys",tris,"| meshes",len(ms),"| bones",bones,"| size",tuple(round(x,2) for x in (mx-mn)),"| mats",[m.name for m in bpy.data.materials][:4],"| imgs",len(bpy.data.images),"| acts",len(acts),acts[:14])
