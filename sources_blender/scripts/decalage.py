# Distance de chaque pièce de vêtement au corps (BVH), en mètres : médiane, min, part des sommets à moins de 1 cm.
import bpy, bmesh, mathutils, statistics
from mathutils.bvhtree import BVHTree
corps = [o for o in bpy.data.objects if o.type=='MESH' and o.name.lower().startswith('superhero')][0]
dg = bpy.context.evaluated_depsgraph_get()
bm = bmesh.new(); bm.from_mesh(corps.data); bm.transform(corps.matrix_world)
t = BVHTree.FromBMesh(bm)
for o in bpy.data.objects:
    if o.type!='MESH' or o is corps or o.name in ('Eyes','Eyebrows','peau'): continue
    d=[]; inside=0
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        loc,n,i,dist = t.find_nearest(p)
        if loc is None: continue
        s = (p-loc).dot(n)
        d.append(s)
        if s<0: inside+=1
    d.sort()
    print("DEC %-10s n=%d min=%.4f p10=%.4f med=%.4f p90=%.4f inside=%d" % (o.name,len(d),d[0],d[len(d)//10],d[len(d)//2],d[len(d)*9//10],inside))
