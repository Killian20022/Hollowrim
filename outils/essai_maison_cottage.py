import bpy,sys,os,math
sys.path.insert(0,r'C:\Users\lopezk19\AppData\Local\Temp\maison_work')
import clus,mathutils
a=sys.argv[sys.argv.index('--')+1:]
src,out,target,res,name=a[0],a[1],int(a[2]),int(a[3]),a[4]
bpy.ops.wm.read_factory_settings(use_empty=True)
if name in ('cottage','armure'): bpy.ops.import_scene.gltf(filepath=src)
PIECES=None
BUD={'casque':420,'torse':800,'gantelet':340,'jambiere':540,'botte':400}
def lowpoly(o,t):
    decim(o,t)
def decim(o,t):
    tr=sum(len(p.vertices)-2 for p in o.data.polygons)
    if tr>t:
        bpy.context.view_layer.objects.active=o
        m=o.modifiers.new('d','DECIMATE'); m.decimate_type='COLLAPSE'; m.ratio=t/tr; m.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier='d')
# rendu de l'original (workbench, texture)
def rend(obj,path,rot=(0,0,0)):
    sc=bpy.context.scene
    sc.render.engine='BLENDER_WORKBENCH'
    sc.display.shading.light='STUDIO'; sc.display.shading.color_type='TEXTURE'
    sc.render.resolution_x=sc.render.resolution_y=640
    sc.render.film_transparent=False
    sc.world=bpy.data.worlds.new('w'); sc.world.color=(0.12,0.14,0.18)
    d=max(obj.dimensions); 
    cam=bpy.data.objects.get('cam') or bpy.data.objects.new('cam',bpy.data.cameras.new('cam'))
    if cam.name not in sc.collection.objects: sc.collection.objects.link(cam)
    sc.camera=cam
    c=obj.location+sum((obj.matrix_world@__import__('mathutils').Vector(v) for v in obj.bound_box),__import__('mathutils').Vector())/8-obj.location
    cen=sum((obj.matrix_world@__import__('mathutils').Vector(v) for v in obj.bound_box),__import__('mathutils').Vector())/8
    ang=math.radians(35); el=math.radians(22)
    cam.location=cen+__import__('mathutils').Vector((math.sin(ang)*math.cos(el),-math.cos(ang)*math.cos(el),math.sin(el)))*d*2.0
    dirv=cen-cam.location
    cam.rotation_euler=dirv.to_track_quat('-Z','Y').to_euler()
    cam.data.lens=50
    sc.render.filepath=path; bpy.ops.render.render(write_still=True)

if name=='taverne':
    bpy.ops.import_scene.fbx(filepath=src)
    hi=[o for o in bpy.data.objects if o.type=='MESH'][0]
    bpy.context.view_layer.objects.active=hi; hi.select_set(True)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    rend(hi,os.path.join(os.path.dirname(out),name+'_orig.png'))
    decim(hi,target)
    bt=next(n for n in hi.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE'); im=bt.image
    im2=im.copy(); im2.scale(res,res)
    mat2=bpy.data.materials.new('ps1_'+name); mat2.use_nodes=True
    nt=mat2.node_tree; bs=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    t2=nt.nodes.new('ShaderNodeTexImage'); t2.image=im2; t2.interpolation='Closest'
    nt.links.new(t2.outputs['Color'],bs.inputs['Base Color']); bs.inputs['Roughness'].default_value=1.0
    im2.filepath_raw=out.replace('.glb','_tex.png'); im2.file_format='PNG'; im2.save()
    hi.data.materials.clear(); hi.data.materials.append(mat2)
    hi.data.polygons.foreach_set('use_smooth',[False]*len(hi.data.polygons)); hi.name=name
    bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',use_selection=True,export_yup=True)
    print('RESULT',name,sum(len(p.vertices)-2 for p in hi.data.polygons),'tris',res,'px'); sys.exit(0)
bpy.ops.import_scene.gltf(filepath=src)
if name in ('cottage','armure'):
    cl=clus.clusters(clus.split_all(),0.004)
    cl.sort(key=lambda c:(min((o.matrix_world@mathutils.Vector(v)).x for o in c for v in o.bound_box)+max((o.matrix_world@mathutils.Vector(v)).x for o in c for v in o.bound_box))/2)
    if name=='cottage':
        keep=[max(cl,key=lambda c:sum(len(o.data.polygons) for o in c))]
    else:
        keep=[cl[k] for k in (0,8,1,9,4)]; PIECES=['casque','torse','gantelet','jambiere','botte']
    ks=set(o.name for c in keep for o in c)
    for o in list(bpy.data.objects):
        if o.type=='MESH' and o.name not in ks: bpy.data.objects.remove(o)
    his=[]
    for c in keep:
        bpy.ops.object.select_all(action='DESELECT')
        for o in c: o.select_set(True)
        bpy.context.view_layer.objects.active=c[0]
        if len(c)>1: bpy.ops.object.join()
        his.append(bpy.context.view_layer.objects.active)
bpy.ops.object.select_all(action='DESELECT')
los=[]
if PIECES:
    for k,o in enumerate(his):
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
        bpy.ops.object.duplicate(); d=bpy.context.view_layer.objects.active
        mr=d.modifiers.new('r','REMESH'); mr.mode='VOXEL'; mr.voxel_size=max(d.dimensions)/110; mr.use_smooth_shade=False
        bpy.ops.object.modifier_apply(modifier='r')
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
        lowpoly(d,BUD[PIECES[k]])
        d.data.materials.clear(); d.data.materials.append(bpy.data.materials.new('pc%d'%k))
        for p in d.data.polygons: p.material_index=0
        los.append(d)
bpy.ops.object.select_all(action='DESELECT')
for o in his: o.select_set(True)
bpy.context.view_layer.objects.active=his[0]
if len(his)>1: bpy.ops.object.join()
hi=bpy.context.view_layer.objects.active
hi.name='hi'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
rend(hi,os.path.join(os.path.dirname(out),name+'_orig.png'))
if PIECES:
    bpy.ops.object.select_all(action='DESELECT')
    for o in los: o.select_set(True)
    bpy.context.view_layer.objects.active=los[0]
    bpy.ops.object.join(); lo=bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
else:
    bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); bpy.context.view_layer.objects.active=hi
    bpy.ops.object.duplicate(); lo=bpy.context.view_layer.objects.active
    mr=lo.modifiers.new('r','REMESH'); mr.mode='VOXEL'; mr.voxel_size=max(lo.dimensions)/float(os.environ.get('VOX','110')); mr.use_smooth_shade=False
    bpy.ops.object.modifier_apply(modifier='r')
    lowpoly(lo,target); lo.data.materials.clear()
lo.name='lo'
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); bpy.context.view_layer.objects.active=lo
bpy.ops.object.mode_set(mode="OBJECT")
sm=lo.copy(); sm.data=lo.data.copy(); bpy.context.scene.collection.objects.link(sm)
mo=sm.modifiers.new('s','SMOOTH'); mo.factor=1.0; mo.iterations=int(os.environ.get('SMIT','4'))
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT'); sm.select_set(True); bpy.context.view_layer.objects.active=sm
bpy.ops.object.modifier_apply(modifier='s')
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(float(os.environ.get('ANG','85'))),island_margin=0.01)
bpy.ops.object.mode_set(mode='OBJECT')
n=len(sm.data.loops)
buf=[0.0]*(2*n); sm.data.uv_layers.active.data.foreach_get('uv',buf)
if not lo.data.uv_layers: lo.data.uv_layers.new()
lo.data.uv_layers.active.data.foreach_set('uv',buf)
bpy.data.objects.remove(sm)
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); bpy.context.view_layer.objects.active=lo
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.mode_set(mode='OBJECT')
img=bpy.data.images.new('bake',res,res)
for mt in hi.data.materials:
    nt=mt.node_tree; bt=next(n for n in nt.nodes if n.type=='TEX_IMAGE' and 'basecolor' in n.image.name); ot=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL')
    em=nt.nodes.new('ShaderNodeEmission'); nt.links.new(bt.outputs['Color'],em.inputs['Color']); nt.links.new(em.outputs['Emission'],ot.inputs['Surface'])

if PIECES:
    for mt in lo.data.materials:
        mt.use_nodes=True; nt=mt.node_tree; tn=nt.nodes.new('ShaderNodeTexImage'); tn.image=img; tn.interpolation='Closest'; nt.nodes.active=tn
else:
    mat=bpy.data.materials.new('m'); mat.use_nodes=True
    nt=mat.node_tree; tn=nt.nodes.new('ShaderNodeTexImage'); tn.image=img; tn.interpolation='Closest'; nt.nodes.active=tn
    lo.data.materials.append(mat)
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=1
sc.render.bake.use_pass_direct=False; sc.render.bake.use_pass_indirect=False; sc.render.bake.use_pass_color=True
sc.render.bake.margin=8
bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active=lo
d=max(hi.dimensions)
bpy.ops.object.bake(type='EMIT',use_selected_to_active=True,cage_extrusion=d*0.02,max_ray_distance=d*0.06)
rend(lo,os.path.join(os.path.dirname(out),name+'_low.png'))
bpy.data.objects.remove(hi)
# matériau d'export
mat2=bpy.data.materials.new('ps1_'+name); mat2.use_nodes=True
nt=mat2.node_tree; bs=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
t2=nt.nodes.new('ShaderNodeTexImage'); t2.image=img; t2.interpolation='Closest'
nt.links.new(t2.outputs['Color'],bs.inputs['Base Color']); bs.inputs['Roughness'].default_value=1.0; bs.inputs['Metallic'].default_value=0.0
img.filepath_raw=out.replace('.glb','_tex.png'); img.file_format='PNG'; img.save()
objs=[lo]
if PIECES:
    bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); bpy.context.view_layer.objects.active=lo
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.separate(type='MATERIAL'); bpy.ops.object.mode_set(mode='OBJECT')
    objs=[o for o in bpy.data.objects if o.type=='MESH']
    objs.sort(key=lambda o:int(o.data.materials[0].name[2:]) if o.data.materials[0].name.startswith('pc') else 99)
    for k,o in enumerate(objs): o.name=PIECES[k]
for o in objs:
    o.data.materials.clear(); o.data.materials.append(mat2)
    o.data.polygons.foreach_set('use_smooth',[False]*len(o.data.polygons))
    if PIECES:
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
        bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
        print('PIECE',o.name,len(o.data.polygons),[round(x,3) for x in o.dimensions],[round(x,3) for x in o.location])
bpy.ops.object.select_all(action='DESELECT')
for o in objs: o.select_set(True)
if not PIECES: lo.name=name
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',use_selection=True,export_image_format='AUTO',export_yup=True)
print('RESULT',name,sum(len(p.vertices)-2 for o in objs for p in o.data.polygons),'tris',res,'px')
