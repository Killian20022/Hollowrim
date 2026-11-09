import bpy,mathutils
def clusters(objs,pad):
    n=len(objs); par=list(range(n))
    def f(i):
        while par[i]!=i: par[i]=par[par[i]]; i=par[i]
        return i
    bb=[]
    for o in objs:
        vs=[o.matrix_world@mathutils.Vector(v) for v in o.bound_box]
        bb.append((min(v.x for v in vs)-pad,max(v.x for v in vs)+pad,min(v.y for v in vs)-pad,max(v.y for v in vs)+pad,min(v.z for v in vs)-pad,max(v.z for v in vs)+pad))
    order=sorted(range(n),key=lambda i:bb[i][0])
    for a in range(n):
        i=order[a]
        for b in range(a+1,n):
            j=order[b]
            if bb[j][0]>bb[i][1]: break
            if bb[i][2]<=bb[j][3] and bb[j][2]<=bb[i][3] and bb[i][4]<=bb[j][5] and bb[j][4]<=bb[i][5]:
                par[f(i)]=f(j)
    g={}
    for i in range(n): g.setdefault(f(i),[]).append(objs[i])
    return list(g.values())
def split_all():
    o=[o for o in bpy.data.objects if o.type=='MESH'][0]
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.separate(type='LOOSE'); bpy.ops.object.mode_set(mode='OBJECT')
    return [o for o in bpy.data.objects if o.type=='MESH']
def info(cl):
    out=[]
    for c in cl:
        vs=[o.matrix_world@mathutils.Vector(v) for o in c for v in o.bound_box]
        mn=mathutils.Vector((min(v.x for v in vs),min(v.y for v in vs),min(v.z for v in vs)));mx=mathutils.Vector((max(v.x for v in vs),max(v.y for v in vs),max(v.z for v in vs)))
        out.append((sum(len(o.data.polygons) for o in c),(mn+mx)/2,mx-mn))
    return out
