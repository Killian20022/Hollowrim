# Vérifie un glb converti : importe, applique chaque clip à mi-course, imprime les dimensions (x,y,z Blender, z = haut) du maillage.
import bpy, sys
from mathutils import Vector
for f in sys.argv[sys.argv.index("--") + 1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    ms = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.startswith('Icosphere')]
    for a in list(bpy.data.actions):
        if arm.animation_data is None:
            arm.animation_data_create()
        for t in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(t)
        arm.animation_data.action = a
        try:
            arm.animation_data.action_slot = a.slots[0]
        except Exception:
            pass
        bpy.context.scene.frame_set(int((a.frame_range[0] + a.frame_range[1]) / 2))
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
        for o in ms:
            oe = o.evaluated_get(dg); me = oe.to_mesh()
            for v in me.vertices:
                w = oe.matrix_world @ v.co
                mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
            oe.to_mesh_clear()
        ys=[]
        for o in ms:
            oe = o.evaluated_get(dg); me = oe.to_mesh()
            ys += [(oe.matrix_world @ v.co).y for v in me.vertices]
            oe.to_mesh_clear()
        print("VP rot+90X: zmin %.2f zmax %.2f | rot-90X: zmin %.2f zmax %.2f" % (min(ys), max(ys), -max(ys), -min(ys)))
        print("VP", f.split("/")[-1], a.name, tuple(round(x, 2) for x in (mx - mn)), "zmin", round(mn.z, 2))
