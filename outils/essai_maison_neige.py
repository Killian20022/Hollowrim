import bpy,sys
a=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
ob=[o for o in bpy.data.objects if o.type=='MESH'][0]
me=ob.data
ca=me.color_attributes.new('Col','BYTE_COLOR','CORNER')
zmin=min(v.co.z for v in me.vertices); zmax=max(v.co.z for v in me.vertices)
cnt=0
for p in me.polygons:
    snow = p.normal.z>0.55 and p.center.z>zmin+0.5*(zmax-zmin)
    for li in p.loop_indices:
        ca.data[li].color=(1,1,1,0.0 if snow else 1.0)
    cnt+=snow
me.color_attributes.active_color=ca
print('SNOWFACES',cnt,len(me.polygons))
import inspect
bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
try:
    bpy.ops.export_scene.gltf(filepath=a[1],export_format='GLB',use_selection=True,export_yup=True,export_vertex_color='ACTIVE')
except TypeError as e:
    print('ERR',e); bpy.ops.export_scene.gltf(filepath=a[1],export_format='GLB',use_selection=True,export_yup=True,export_active_vertex_color_when_no_material=True)
