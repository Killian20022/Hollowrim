import bpy,math,numpy as np,mathutils,bmesh
bpy.ops.wm.open_mainfile(filepath=r'C:\Users\lopezk19\Temp\puits_work\c0.blend')
hi=bpy.data.objects['hi']
n=len(hi.data.vertices); co=np.zeros(n*3); hi.data.vertices.foreach_get('co',co); co=co.reshape(-1,3)
a=math.radians(97.7092); c,s=math.cos(a),math.sin(a)
x=co[:,0]*c-co[:,1]*s; y=co[:,0]*s+co[:,1]*c
p=np.array([-0.17222213*c+0.18927389*s,-0.17222213*s-0.18927389*c])
x-=p[0]; y-=p[1]; z=co[:,2]-0.036
r=np.hypot(x,y)
m=(r>0.17)&(r<0.27)&(np.abs(y)>0.1)
print('RIMTOP',z[m].max(), np.percentile(z[m],99.5))
# water: what's the plane at r in(0.1,0.16)
mm=(r>0.08)&(r<0.16)&(z>0.19)&(z<0.23)
print('WATERZ',np.percentile(z[mm],[1,10,50,90,99]),mm.sum())
SC=0.85/np.percentile(z[m],99.5)
print('SC',SC)
new=np.stack([x,y,z],1)*SC
hi.data.vertices.foreach_set('co',new.ravel()); hi.data.update()
# normals check: n vertex normal not needed
bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); bpy.context.view_layer.objects.active=hi
bpy.ops.object.duplicate(); lo=bpy.context.view_layer.objects.active; lo.name='lo'
bm=bmesh.new(); bm.from_mesh(lo.data)
nv=len(bm.verts)
bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=0.0004)
bmb=sum(1 for e in bm.edges if len(e.link_faces)==1); bmn=sum(1 for e in bm.edges if len(e.link_faces)>2)
print('WELD verts',nv,'->',len(bm.verts),'boundary',bmb,'nonman',bmn)
bm.to_mesh(lo.data); bm.free(); lo.data.update()
tr=sum(len(p.vertices)-2 for p in lo.data.polygons); print('HITRIS',tr)
# intermediate: 150k then target
for tgt in (120000,):
    md=lo.modifiers.new('d','DECIMATE'); md.decimate_type='COLLAPSE'; md.ratio=tgt/tr; md.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier='d')
tr2=len(lo.data.polygons); print('MID',tr2)
vg=lo.vertex_groups.new(name='w')
for v in lo.data.vertices:
    z=v.co.z*2.957
    vg.add([v.index], 0.2 if z<1.05 else (0.3 if z<2.6 else 0.5),'REPLACE')
md=lo.modifiers.new('d','DECIMATE'); md.decimate_type='COLLAPSE'; md.ratio=10500/tr2; md.use_collapse_triangulate=True
md.vertex_group='w'; md.vertex_group_factor=3.0
bpy.ops.object.modifier_apply(modifier='d')
print('LOTRIS',len(lo.data.polygons))
bm=bmesh.new(); bm.from_mesh(lo.data)
print('FINAL boundary',sum(1 for e in bm.edges if len(e.link_faces)==1),'nonman',sum(1 for e in bm.edges if len(e.link_faces)>2)); bm.free()
lo.vertex_groups.clear()
nm=sum(1 for p in lo.data.polygons if p.center.z*2.957<1.05)
print('MARGELLE faces',nm,'rest',len(lo.data.polygons)-nm)
hi.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=r'C:\Users\lopezk19\Temp\puits_work\c1.blend')
