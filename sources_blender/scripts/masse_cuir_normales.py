# Masse cloutée HD (hybrides_hd/quaternius_hd.py, lot 2) : la poignée de cuir enroulé (maillage « cuir », 1 280 faces) avait
# TOUTES ses faces tournées vers l'intérieur du manche (audit bras_vide 2026-11-26 : faces arrière visibles en 1re
# personne ; la matière double face le cachait au rendu). On retourne ses faces, le reste du modèle n'est pas touché.
#   blender.exe -b --python masse_cuir_normales.py      (réécrit assets/modeles/armes/integrees/hd/10_club_mace.glb)
import bpy, bmesh, os
base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
glb = os.path.join(base, "assets", "modeles", "armes", "integrees", "hd", "10_club_mace.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
o = bpy.data.objects["cuir"]
bm = bmesh.new()
bm.from_mesh(o.data)
from mathutils import Vector
c = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
# axe du manche vertical (z Blender) : normale radiale attendue vers l'extérieur
dedans = [f for f in bm.faces if f.normal.x * (f.calc_center_median().x - c.x) + f.normal.y * (f.calc_center_median().y - c.y) < 0]
bmesh.ops.reverse_faces(bm, faces=dedans)
bm.to_mesh(o.data)
bm.free()
print("CUIR retournées", len(dedans))
bpy.ops.object.select_all(action='SELECT')
kw = dict(filepath=glb, export_format='GLB', use_selection=True, export_apply=False)
try:
    bpy.ops.export_scene.gltf(export_vertex_color='ACTIVE', **kw)
except TypeError:
    bpy.ops.export_scene.gltf(**kw)
print("EXPORT OK", glb)
