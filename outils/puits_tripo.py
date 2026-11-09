import bpy,math,numpy as np,mathutils,bmesh,os
bpy.ops.wm.open_mainfile(filepath=r'C:\Users\lopezk19\Temp\puits_work\c2.blend')
hi=bpy.data.objects['hi']; lo=bpy.data.objects['lo']
RES=256
BK=1024
OUT=r'C:\Users\lopezk19\Jeux\nordique_puits\assets\essai_tripo'
hi.hide_set(False)
# 1. nettoyage du lo
bm=bmesh.new(); bm.from_mesh(lo.data)
kill=[]
for f in bm.faces:
    c=f.calc_center_median(); zs=[v.co.z for v in f.verts]; rs=[math.hypot(v.co.x,v.co.y) for v in f.verts]
    if max(zs)<0.03: kill.append(f); continue                                   # dessous
    if abs(f.normal.z)>0.8 and min(zs)>0.77 and max(zs)<0.84 and max(rs)<0.64: kill.append(f)   # eau (dessus et dessous) et fond du seau
print('KILL',len(kill),'of',len(bm.faces))
bmesh.ops.delete(bm,geom=kill,context='FACES')
# manivelle : la décimation l'a réduite en rubans ; on la refait en quatre poutres (le bake reprend les couleurs du modèle d'origine)
crank=[f for f in bm.faces if f.calc_center_median().x<-1.075 and f.calc_center_median().z<1.6]
print('CRANK faces removed',len(crank))
bmesh.ops.delete(bm,geom=crank,context='FACES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
def box(x0,x1,y0,y1,z0,z1):
    vs=[bm.verts.new((x,y,z)) for x in (x0,x1) for y in (y0,y1) for z in (z0,z1)]
    # index = x*4+y*2+z
    q=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    for a in q: bm.faces.new([vs[i] for i in a])
box(-1.285,-1.075,0.10-0.035,0.10+0.035,1.51-0.035,1.51+0.035)
box(-1.275,-1.205,0.10-0.035,0.10+0.035,1.15,1.545)
box(-1.64,-1.205,0.10-0.03,0.10+0.03,1.16-0.03,1.16+0.03)
box(-1.64,-1.48,0.10-0.045,0.10+0.045,1.16-0.045,1.16+0.045)
bm.to_mesh(lo.data); bm.free(); lo.data.update()
lo.data.materials.clear()
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); bpy.context.view_layer.objects.active=lo
# orientation des faces d'après la surface la plus proche du hi (BVH)
from mathutils.bvhtree import BVHTree
dg=bpy.context.evaluated_depsgraph_get()
bvh=BVHTree.FromObject(hi,dg)
bmx=bmesh.new(); bmx.from_mesh(lo.data)
flip=[]
for f in bmx.faces:
    c=f.calc_center_median()
    loc,nor,idx,dist=bvh.find_nearest(c)
    if loc is not None and nor.dot(f.normal)<0: flip.append(f)
print('FLIP',len(flip),'of',len(bmx.faces))
bmesh.ops.reverse_faces(bmx,faces=flip)
bmx.to_mesh(lo.data); bmx.free(); lo.data.update()
# 2. UV (copie lissée)
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); bpy.context.view_layer.objects.active=lo
sm=lo.copy(); sm.data=lo.data.copy(); bpy.context.scene.collection.objects.link(sm)
mo=sm.modifiers.new('s','SMOOTH'); mo.factor=0.5; mo.iterations=14
bpy.ops.object.select_all(action='DESELECT'); sm.select_set(True); bpy.context.view_layer.objects.active=sm
bpy.ops.object.modifier_apply(modifier='s')
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=0.003,rotate_method='AXIS_ALIGNED')
bpy.context.scene.tool_settings.use_uv_select_sync=True
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.pack_islands(rotate=True,margin=0.003,margin_method='FRACTION',shape_method='CONCAVE')
bpy.ops.object.mode_set(mode='OBJECT')
n=len(sm.data.loops); buf=[0.0]*(2*n); sm.data.uv_layers.active.data.foreach_get('uv',buf)
if not lo.data.uv_layers: lo.data.uv_layers.new()
lo.data.uv_layers.active.data.foreach_set('uv',buf)
bpy.data.objects.remove(sm)
# 3. bake
lo.data.polygons.foreach_set('use_smooth',[True]*len(lo.data.polygons))
img=bpy.data.images.new('bake',BK,BK)
for mt in hi.data.materials:
    nt=mt.node_tree; bt=next(n for n in nt.nodes if n.type=='TEX_IMAGE' and 'basecolor' in n.image.name); ot=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL')
    em=nt.nodes.new('ShaderNodeEmission'); nt.links.new(bt.outputs['Color'],em.inputs['Color']); nt.links.new(em.outputs['Emission'],ot.inputs['Surface'])
mat=bpy.data.materials.new('m'); mat.use_nodes=True
nt=mat.node_tree; tn=nt.nodes.new('ShaderNodeTexImage'); tn.image=img; tn.interpolation='Closest'; nt.nodes.active=tn
lo.data.materials.append(mat)
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=1
sc.render.bake.use_pass_direct=False; sc.render.bake.use_pass_indirect=False; sc.render.bake.use_pass_color=True; sc.render.bake.margin=16
bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active=lo
d=max(hi.dimensions)
bpy.ops.object.bake(type='EMIT',use_selected_to_active=True,cage_extrusion=d*0.02,max_ray_distance=d*0.08)
px=np.array(img.pixels[:],dtype=np.float32).reshape(BK,BK,4)
k=BK//RES
sm_=px.reshape(RES,k,RES,k,4).mean(axis=(1,3)); sm_[...,3]=1.0
print('COVER',float((sm_[...,:3].sum(axis=2)>0.02).mean()))
img2=bpy.data.images.new('puits_tex',RES,RES); img2.pixels.foreach_set(sm_.ravel()); img2.update()
img2.filepath_raw=OUT+r'\puits_tex.png'; img2.file_format='PNG'; img2.save()
img=img2
bpy.data.objects.remove(hi)
# 4. seau + corde : descendre le seau de D, étirer la corde
D=3.8
bm=bmesh.new(); bm.from_mesh(lo.data)
for v in bm.verts:
    r=math.hypot(v.co.x,v.co.y)
    if r<0.26 and 0.1<v.co.z<1.48:
        w=min(1.0,(1.48-v.co.z)/(1.48-1.18)); v.co.z-=D*w
seau=[]
for f in bm.faces:
    c=f.calc_center_median(); r=math.hypot(c.x,c.y)
    if all(math.hypot(v.co.x,v.co.y)<0.26 for v in f.verts) and c.z<1.47 and c.z>-4.5 and max(v.co.z for v in f.verts)<1.49 and any(v.co.z<1.2 for v in f.verts):
        seau.append(f)
print('SEAU faces',len(seau))
# géométrie seau seule
geom=set(seau)
bm2=bmesh.new()
# copie par duplication
dup=bmesh.ops.duplicate(bm,geom=seau)
newf=[g for g in dup['geom'] if isinstance(g,bmesh.types.BMFace)]
bmesh.ops.delete(bm,geom=seau,context='FACES')
# retirer sommets orphelins
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
# le seau = duplicat : on le sépare dans un second mesh
mseau=bpy.data.meshes.new('seau')
# extraire les faces dupliquées dans bm2
vmap={}
uvl=bm.loops.layers.uv.active
for f in newf:
    vs=[]
    for v in f.verts:
        if v not in vmap: vmap[v]=bm2.verts.new(v.co)
        vs.append(vmap[v])
    nf=bm2.faces.new(vs)
uv2=bm2.loops.layers.uv.new('UVMap')
for f,nf in zip(newf,bm2.faces):
    for l,nl in zip(f.loops,nf.loops): nl[uv2].uv=l[uvl].uv.copy()
bm2.verts.ensure_lookup_table()
# bissecter au sol (z=0)
geomall=bm2.verts[:]+bm2.edges[:]+bm2.faces[:]
bmesh.ops.bisect_plane(bm2,geom=geomall,plane_co=(0,0,0),plane_no=(0,0,1))
# couleurs de sommet : profondeur
cl=bm2.loops.layers.float_color.new('Color')
for f in bm2.faces:
    for l in f.loops:
        z=l.vert.co.z
        if z>=0.0: om=1.0
        else:
            prof=min(1.0,-z/5.0); om=(1.0-prof)**1.7*0.95+0.03
        l[cl]=(om,om,om,1.0)
print('SEAU tris',sum(len(f.verts)-2 for f in bm2.faces))
# fusion des faces triangles
bmesh.ops.triangulate(bm2,faces=bm2.faces[:])
bm2.to_mesh(mseau); bm2.free()
# restes de l'ancien seau/corde etires (lamelles du haut du conduit jusqu'a z=-3,6) : ils formaient la 'dalle grise' dans le conduit
rest=[f for f in bm.faces if all(math.hypot(v.co.x,v.co.y)<0.45 for v in f.verts) and min(v.co.z for v in f.verts)<1.2]
print('RESTES supprimes',len(rest))
bmesh.ops.delete(bm,geom=rest,context='FACES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
bm.to_mesh(lo.data); bm.free(); lo.data.update()
oseau=bpy.data.objects.new('seau',mseau); bpy.context.scene.collection.objects.link(oseau)
mat2=bpy.data.materials.new('ps1_puits'); mat2.use_nodes=True
nt=mat2.node_tree; bs=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
t2=nt.nodes.new('ShaderNodeTexImage'); t2.image=img; t2.interpolation='Closest'
nt.links.new(t2.outputs['Color'],bs.inputs['Base Color']); bs.inputs['Roughness'].default_value=1.0; bs.inputs['Metallic'].default_value=0.0
lo.data.materials.clear(); lo.data.materials.append(mat2)
oseau.data.materials.append(mat2)
for o in (lo,oseau):
    o.data.polygons.foreach_set('use_smooth',[False]*len(o.data.polygons))
lo.name='puits'
def exp(o,path,col):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    kw=dict(filepath=path,export_format='GLB',use_selection=True,export_yup=True,export_image_format='AUTO')
    if col: kw.update(export_vertex_color='ACTIVE',export_active_vertex_color_when_no_material=True)
    bpy.ops.export_scene.gltf(**kw)
exp(lo,OUT+r'\puits.glb',False)
exp(oseau,OUT+r'\puits_seau.glb',True)
print('RESULT puits',len(lo.data.polygons),'tris; seau',len(oseau.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=r'C:\Users\lopezk19\Temp\puits_work\c3.blend')
