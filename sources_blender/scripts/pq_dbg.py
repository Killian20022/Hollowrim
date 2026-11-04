import bpy,sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[sys.argv.index("--")+1])
for o in bpy.context.scene.objects:
    if o.type=='MESH' and not o.name.startswith('Icosphere'):
        ca=o.data.color_attributes
        print("DBG",o.name,[ (c.name,c.domain,c.data_type) for c in ca],"active",ca.active_color and ca.active_color.name, "mats",[m.name for m in o.data.materials])
        if len(ca):
            d={}
            for e in ca[0].data: 
                k=tuple(round(x,2) for x in e.color); d[k]=d.get(k,0)+1
            print("DBG distinct",len(d),sorted(d.items(),key=lambda kv:-kv[1])[:6])
        for m in o.data.materials:
            print("DBG nodes",[n.type for n in m.node_tree.nodes])
