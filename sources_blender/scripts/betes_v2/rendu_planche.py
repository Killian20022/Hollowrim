# Rendus « façon jeu » (480x270, texels nets, soleil désaturé + ciel froid / nuit bleue) d'un glb de bête, pour les planches
# AVANT | APRÈS des animaux v2 (art/animaux_v2, 2026-11-20). Approximation Blender du shader ps1_perso : à confirmer en jeu (Godot).
#   blender.exe -b --python rendu_planche.py -- glb=<C:\...\x.glb> sortie=<C:\...\prefixe> [vues=face,profil,trois_quarts]
#       [anim=Walk:0,4,8,12] [eclairage=jour,nuit] [taille=480x270] [dist=1.0]
import bpy, sys, os, math
from mathutils import Vector

A = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:])
GLB, SORTIE = A["glb"], A["sortie"]
VUES = A.get("vues", "face,profil,trois_quarts").split(",")
ECL = A.get("eclairage", "jour,nuit").split(",")
W, H = (int(x) for x in A.get("taille", "480x270").split("x"))
DIST = float(A.get("dist", "1.0"))
ANIM = A.get("anim", "")
TEX = A.get("tex", "")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
for o in list(bpy.context.scene.objects):
    if o.type == 'MESH' and o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.name.endswith("_loin")]
for o in bpy.context.scene.objects:
    if o.type == 'MESH' and o.name.endswith("_loin"):
        o.hide_render = True
arm = next((o for o in bpy.context.scene.objects if o.type == 'ARMATURE'), None)

# matériau : albédo = texture (nette) x couleur de sommet, mat, sans spéculaire (comme ps1_perso)
for o in meshes:
    for i, slot in enumerate(o.material_slots):
        src = slot.material
        img = bpy.data.images.load(TEX, check_existing=True) if TEX else None
        if img is None and src and src.use_nodes:
            for n in src.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image:
                    img = n.image
        m = bpy.data.materials.new("rendu_%s_%d" % (o.name, i))
        m.use_nodes = True
        nt = m.node_tree
        b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        b.inputs["Roughness"].default_value = 1.0
        for k in ("Specular IOR Level", "Specular"):
            if k in b.inputs:
                b.inputs[k].default_value = 0.0
        col = None
        if o.data.color_attributes:
            at = nt.nodes.new("ShaderNodeVertexColor")
            at.layer_name = o.data.color_attributes[0].name
            col = at.outputs["Color"]
        if img is not None:
            tx = nt.nodes.new("ShaderNodeTexImage")
            tx.image = img
            tx.interpolation = 'Closest'
            if col is not None:
                mu = nt.nodes.new("ShaderNodeMix")
                mu.data_type = 'RGBA'
                mu.blend_type = 'MULTIPLY'
                mu.inputs["Factor"].default_value = 1.0
                nt.links.new(tx.outputs["Color"], mu.inputs[6])
                nt.links.new(col, mu.inputs[7])
                col = mu.outputs[2]
            else:
                col = tx.outputs["Color"]
        if col is not None:
            nt.links.new(col, b.inputs["Base Color"])
        slot.material = m

sc = bpy.context.scene
try:
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
except TypeError:
    sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x, sc.render.resolution_y = W, H
sc.render.resolution_percentage = 100
sc.render.filter_size = 0.01
sc.view_settings.view_transform = 'Standard'
sc.render.film_transparent = False
try:
    sc.eevee.taa_render_samples = 1
except Exception:
    pass

# boîte englobante en pose de repos (frame 0 de la pose courante)
def boite():
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in meshes:
        oe = o.evaluated_get(dg)
        me = oe.to_mesh()
        pts += [oe.matrix_world @ v.co for v in me.vertices]
        oe.to_mesh_clear()
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx

def poser(action, frame):
    if arm is None:
        return
    if arm.animation_data is None:
        arm.animation_data_create()
    for t in arm.animation_data.nla_tracks:
        t.mute = True
    act = bpy.data.actions.get(action)
    if act is None:
        act = next((a for a in bpy.data.actions if a.name.startswith(action)), None)
    arm.animation_data.action = act
    if act is not None and hasattr(arm.animation_data, "action_slot") and act.slots:
        arm.animation_data.action_slot = act.slots[0]
    sc.frame_set(int(frame))

poser("Idle", 0)
MN, MX = boite()
import json as _j
if A.get("cadre_in") and os.path.exists(A["cadre_in"]):
    d = _j.load(open(A["cadre_in"]))
    MN, MX = Vector(d["mn"]), Vector(d["mx"])
if A.get("cadre_out"):
    _j.dump({"mn": list(MN), "mx": list(MX)}, open(A["cadre_out"], "w"))
CEN = (MN + MX) / 2
TAILLE = max((MX - MN).x, (MX - MN).y, (MX - MN).z)
# axe avant du glb : -Y Blender (glTF +Z) ; on le déduit de l'étendue : le plus long axe horizontal = longueur du corps
long_y = (MX - MN).y >= (MX - MN).x

cam_d = bpy.data.cameras.new("cam")
cam_d.lens = 50
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam

def eclairage(mode):
    for o in [o for o in sc.objects if o.type == 'LIGHT']:
        bpy.data.objects.remove(o, do_unlink=True)
    w = sc.world or bpy.data.worlds.new("monde")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND')
    sol = bpy.data.lights.new("sol", 'SUN')
    s = bpy.data.objects.new("sol", sol)
    sc.collection.objects.link(s)
    if mode == "jour":
        bg.inputs[0].default_value = (0.42, 0.50, 0.62, 1)
        bg.inputs[1].default_value = 0.55
        sol.color = (1.0, 0.93, 0.82)
        sol.energy = 3.2
        s.rotation_euler = (math.radians(50), 0, math.radians(35))
    else:
        bg.inputs[0].default_value = (0.10, 0.14, 0.26, 1)
        bg.inputs[1].default_value = 1.0
        sol.color = (0.55, 0.65, 1.0)
        sol.energy = 0.55
        s.rotation_euler = (math.radians(60), 0, math.radians(-40))
    sc.world.color = bg.inputs[0].default_value[:3]

DIRS = {"face": 0.0, "profil": 90.0, "trois_quarts": 40.0, "dos": 180.0}

def viser(vue):
    ang = math.radians(DIRS[vue])
    d = TAILLE * 2.1 * DIST
    # devant = -Y si long_y sinon -X (repère glTF importé : avant +Z glTF = -Y Blender)
    if long_y:
        v = Vector((math.sin(ang), -math.cos(ang), 0.0))
    else:
        v = Vector((-math.cos(ang), math.sin(ang), 0.0))
    pos = CEN + v * d + Vector((0, 0, TAILLE * 0.35 * DIST))
    cam.location = pos
    dirv = (CEN - pos).normalized()
    cam.rotation_euler = dirv.to_track_quat('-Z', 'Y').to_euler()

ETIQ = A.get("etiquette", "")
r_ = sc.render
for k in dir(r_):
    if k.startswith("use_stamp_") and k not in ("use_stamp_note", "use_stamp_labels"):
        try:
            setattr(r_, k, False)
        except Exception:
            pass


def rendre(chemin, texte=""):
    if ETIQ:
        r_.use_stamp = True
        r_.use_stamp_note = True
        r_.use_stamp_labels = False
        r_.stamp_note_text = (ETIQ + "  " + texte).strip()
        r_.stamp_font_size = 13
        r_.stamp_background = (0, 0, 0, 0.55)
    sc.render.filepath = chemin
    bpy.ops.render.render(write_still=True)

for e in ECL:
    eclairage(e)
    poser("Idle", 0)
    for v in VUES:
        viser(v)
        rendre("%s_%s_%s.png" % (SORTIE, e, v), "%s - %s" % (v.replace("trois_quarts", "3/4"), e))
    for anim in [x for x in ANIM.split(";") if x]:
        nom, frames = anim.split(":")
        viser("trois_quarts")
        for i, f in enumerate(frames.split(",")):
            poser(nom, f)
            rendre("%s_%s_%s_%02d.png" % (SORTIE, e, nom, i), "%s - %s" % (nom, e))
print("RENDU OK")
