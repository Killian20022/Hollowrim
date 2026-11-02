# Aperçu Workbench (agent Y) : rend les objets visibles de la scène courante sous plusieurs angles.
import bpy, math, mathutils
def rendre(chemin_base, cible=(0, 0, 1.0), dist=3.2, vues=("face", "34", "profil", "dos"), taille=(420, 560), ortho=1.9, couleur_obj=True):
    sc = bpy.context.scene
    # l'alpha des textures porte la BRILLANCE (shader_matiere), pas la transparence : aperçus opaques (export déjà fait)
    for m in bpy.data.materials:
        try:
            m.blend_method = "OPAQUE"
        except Exception:
            pass
        if m.use_nodes:
            for l in list(m.node_tree.links):
                if l.to_socket.name == "Alpha":
                    m.node_tree.links.remove(l)
    # Workbench (mode texture) lit l'alpha de l'image même sans lien : alpha ignoré le temps des rendus, rétabli à la fin (export du sol)
    modes = {}
    for im in bpy.data.images:
        modes[im.name] = im.alpha_mode
        try:
            im.alpha_mode = "NONE"
        except Exception:
            pass
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE" if couleur_obj else "OBJECT"
    sc.display.shading.show_cavity = True
    sc.display.shading.cavity_type = "BOTH"
    sc.render.resolution_x, sc.render.resolution_y = taille
    sc.render.film_transparent = False
    cam = bpy.data.objects.get("CamApercu")
    if cam is None:
        cam = bpy.data.objects.new("CamApercu", bpy.data.cameras.new("CamApercu"))
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"; cam.data.ortho_scale = ortho
    sc.camera = cam
    angles = {"face": 0, "34": 35, "profil": 90, "dos": 180, "34dos": 145}
    c = mathutils.Vector(cible)
    for v in vues:
        if isinstance(v, tuple):
            v, d = v[0], mathutils.Vector(v[1]).normalized()
        else:
            a = math.radians(angles[v])
            # Godot +Z devant -> Blender -Y devant (import glTF : Y_godot = Z_blender, Z_godot = -Y_blender)
            d = mathutils.Vector((math.sin(a), -math.cos(a), 0.12)).normalized()
        cam.location = c + d * dist
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y" if abs(d.z) < 0.95 else "X").to_euler()
        sc.render.filepath = "%s_%s.png" % (chemin_base, v)
        bpy.ops.render.render(write_still=True)
    for im in bpy.data.images:
        if im.name in modes:
            im.alpha_mode = modes[im.name]
