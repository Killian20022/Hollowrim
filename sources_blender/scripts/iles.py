# Liste les îlots (composantes connexes) d'une pièce : boîte englobante monde, sommets. blender -b f.blend --python iles.py -- piece
import bpy, bmesh, sys
piece = sys.argv[sys.argv.index("--")+1]
o = bpy.data.objects[piece]
bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
seen=set(); k=0
for v in bm.verts:
    if v.index in seen: continue
    comp=[]; st=[v]; seen.add(v.index)
    while st:
        x=st.pop(); comp.append(x)
        for e in x.link_edges:
            y=e.other_vert(x)
            if y.index not in seen: seen.add(y.index); st.append(y)
    xs=[c.co.x for c in comp]; ys=[c.co.y for c in comp]; zs=[c.co.z for c in comp]
    print("ILE %s #%d verts=%d x[%.2f,%.2f] y[%.2f,%.2f] z[%.2f,%.2f]"%(piece,k,len(comp),min(xs),max(xs),min(ys),max(ys),min(zs),max(zs))); k+=1
