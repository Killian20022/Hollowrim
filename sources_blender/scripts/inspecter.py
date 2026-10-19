# Inspection des maillages : arêtes de bord (ouvertes), arêtes non manifold, composantes, sommets soudables.
# blender.exe -b fichier.blend --python inspecter.py
import bpy, bmesh, sys
print("=== FICHIER", bpy.data.filepath)
for o in bpy.data.objects:
    if o.type != 'MESH':
        print("OBJ", o.name, o.type, "parent=", o.parent.name if o.parent else None)
        continue
    me = o.data
    bm = bmesh.new(); bm.from_mesh(me)
    bord = [e for e in bm.edges if len(e.link_faces) == 1]
    nm = [e for e in bm.edges if len(e.link_faces) > 2]
    # composantes connexes
    seen=set(); comps=0
    for v in bm.verts:
        if v.index in seen: continue
        comps+=1; st=[v]; seen.add(v.index)
        while st:
            x=st.pop()
            for e in x.link_edges:
                y=e.other_vert(x)
                if y.index not in seen: seen.add(y.index); st.append(y)
    mats=[m.name if m else None for m in me.materials]
    print("MESH %-28s v=%6d f=%6d bord=%5d nonmanif=%d comps=%d mats=%s vis=%s mods=%s shapekeys=%s vg=%d" % (
        o.name, len(bm.verts), len(bm.faces), len(bord), len(nm), comps, mats, not o.hide_viewport,
        [m.type for m in o.modifiers], len(me.shape_keys.key_blocks) if me.shape_keys else 0, len(o.vertex_groups)))
    bm.free()
