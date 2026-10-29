# Mises en situation des props Quaternius adaptés (aperçu Blender EEVEE, PAS le rendu du jeu) :
#   blender.exe -b --python scenes_quaternius.py -- dat=<props_quaternius.dat> sortie=<dossier>
# 480x270 (résolution du jeu), lumière chaude ponctuelle + ambiante bleu nuit, agrandi x3 en « plus proche », quantifié sur la bible.
import bpy, math, os, sys
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importer_quaternius as iq

args = sys.argv[sys.argv.index("--") + 1:]
A = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in args if "=" in a}
D = iq._lire_dat(A["dat"])
MODS = {}
for k, v in D.items():
    nom, mat = k.split("__")
    MODS.setdefault(nom, {})[mat] = v
B = lambda v: (v[0], -v[2], v[1])     # Godot -> Blender

SCENES = {
    "auberge": dict(sol="bois", mur="bois", poses=[
        ("q_grande_table", (0, 0, 0), 0), ("q_chaise", (-0.6, 0, 0.9), 180), ("q_chaise", (0.7, 0, -0.9), 0), ("q_banc", (0, 0, 1.0), 0),
        ("q_tabouret", (1.9, 0, 0.6), 0), ("q_chope", (-0.4, 0.81, 0.1), 20), ("q_chope", (0.5, 0.81, -0.2), 70), ("q_bougeoir_triple", (0.0, 0.81, 0.0), 0),
        ("q_support_tonneau", (-2.2, 0, -1.6), 0), ("q_armoire", (1.2, 0, -1.75), 0), ("q_seau_bois", (2.3, 0, -1.2), 0), ("q_chaudron", (-2.6, 0, 0.6), 30),
        ("q_lit", (3.4, 0, -0.6), 90)],
        lum=[((0.0, 1.3, 0.3), 90), ((-2.0, 1.4, 0.4), 120), ((2.4, 1.6, 0.2), 90)], cam=((0.3, 1.45, 3.0), (0.0, 0.55, -0.9))),
    "forge": dict(sol="pierre", mur="pierre", poses=[
        ("q_enclume", (0, 0, 0), 20), ("q_pierre_aiguiser", (-1.8, 0, 0.2), 60), ("q_etabli", (0.6, 0, -1.6), 0), ("q_seau_fer", (0.9, 0, 0.6), 0),
        ("q_marmite", (-0.9, 0, -1.3), 0), ("q_support_tonneau", (-2.6, 0, -1.5), 0), ("q_caisse", (2.3, 0, -1.3), 15), ("q_caisse", (2.4, 0, -0.3), -10),
        ("q_sac", (1.8, 0, 0.6), 0)],
        lum=[((-0.6, 0.6, -0.5), 200), ((1.5, 1.6, 0.8), 80)], cam=((0.2, 1.4, 2.9), (0.0, 0.45, -0.7))),
    "crypte": dict(sol="pierre", mur="pierre", poses=[
        ("q_lustre", (0, 2.1, 0), 0), ("q_lutrin", (-1.0, 0, -0.6), 30), ("q_etagere_fioles", (0.5, 0, -1.8), 0), ("q_cage", (2.0, 0, -0.8), 20),
        ("q_pile_livres", (1.0, 0, 0.2), 10), ("q_parchemin", (0.6, 0, 0.6), 40), ("q_bougeoir_triple", (-1.8, 0, 0.3), 0), ("q_calice", (1.1, 0.21, 0.2), 0),
        ("q_caisse", (-2.4, 0, -1.4), 30)],
        lum=[((0, 1.9, 0), 90), ((-1.8, 0.7, 0.4), 50), ((1.6, 1.0, 0.4), 50)], cam=((0.2, 1.35, 2.9), (0.0, 0.6, -0.8)), ambiant=(0.01, 0.012, 0.02)),
    "marche": dict(sol="neige", mur=None, poses=[
        ("q_etal", (-1.4, 0, -0.8), 10), ("q_charrette_etal", (2.0, 0, -1.2), -25), ("q_cageot_pommes", (-1.4, 0.9, -0.6), 10),
        ("q_tonneau_pommes", (0.3, 0, -0.2), 0), ("q_caisse", (0.4, 0, -1.4), 20), ("q_sac", (-0.5, 0, 0.5), 0), ("q_sac", (1.0, 0, 0.4), 50),
        ("q_banniere", (-3.2, 0, -1.6), 20), ("q_cageot_pommes", (1.2, 0, -0.1), -30)],
        lum=[((0.0, 2.2, 1.0), 160), ((-1.6, 1.8, 0.2), 80)], cam=((0.3, 1.6, 3.4), (0.0, 0.7, -0.9)), ambiant=(0.035, 0.045, 0.08)),
}
COUL = {"bois": "#472a21", "pierre": "#3a4057", "neige": "#6877a3"}


def materiau():
    m = bpy.data.materials.new("vc")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    at = nt.nodes.new("ShaderNodeVertexColor")
    at.layer_name = "c"
    nt.links.new(at.outputs[0], bsdf.inputs[0])
    bsdf.inputs["Roughness"].default_value = 1.0
    for nom in ("Specular IOR Level", "Specular"):
        if nom in bsdf.inputs:
            bsdf.inputs[nom].default_value = 0.0
    return m


def plan(nom, c, taille, rot, hexa):
    bpy.ops.mesh.primitive_plane_add(size=1, location=c, rotation=rot)
    o = bpy.context.object
    o.scale = (taille[0], taille[1], 1)
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    col = iq.H(hexa)
    b.inputs[0].default_value = (iq.srgb2lin(col[0]), iq.srgb2lin(col[1]), iq.srgb2lin(col[2]), 1)
    b.inputs["Roughness"].default_value = 1.0
    o.data.materials.append(m)


def scene(nom, S, dossier):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = e
            break
        except TypeError:
            pass
    sc.render.resolution_x, sc.render.resolution_y = 480, 270
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    amb = S.get("ambiant", (0.018, 0.016, 0.022))
    bg.inputs[0].default_value = (*amb, 1)
    mat = materiau()
    plan("sol", (0, 0, 0), (12, 10), (0, 0, 0), COUL[S["sol"]])
    if S["mur"]:
        plan("mur", (0, 2.4, 2.5), (12, 5), (math.pi / 2, 0, 0), COUL[S["mur"]])
    for mod, pos, lacet in S["poses"]:
        me_ob = iq.maillage_adapte(None, MODS[mod], nom=mod)
        me_ob.data.materials.append(mat)
        me_ob.rotation_euler = (0, 0, math.radians(lacet))
        me_ob.location = B(pos)
    for i, (p, e) in enumerate(S["lum"]):
        ld = bpy.data.lights.new("l%d" % i, 'POINT')
        ld.energy = e
        ld.color = (1.0, 0.62, 0.3)
        ld.shadow_soft_size = 0.1
        lo = bpy.data.objects.new("l%d" % i, ld)
        lo.location = B(p)
        sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("cam")
    cd.angle_y = math.radians(72) if hasattr(cd, "angle_y") else cd.angle
    cd.sensor_fit = 'VERTICAL'
    cd.angle = math.radians(72)
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cp, cv = Vector(B(S["cam"][0])), Vector(B(S["cam"][1]))
    cam.location = cp
    cam.rotation_euler = (cv - cp).to_track_quat('-Z', 'Y').to_euler()
    brut = os.path.join(dossier, "_brut_%s.png" % nom)
    sc.render.filepath = brut
    bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(brut)
    w_, h_ = im.size
    px = iq.quantifier(list(im.pixels[:]), w_, h_, 3)
    out = bpy.data.images.new(nom, w_ * 3, h_ * 3, alpha=False)
    out.pixels[:] = px
    out.filepath_raw = os.path.join(dossier, "situation_%s.png" % nom)
    out.file_format = 'PNG'
    out.save()
    print("scene", nom, "->", out.filepath_raw)


for n, S in SCENES.items():
    if "seulement" in A and n not in A["seulement"].split(","):
        continue
    scene(n, S, A["sortie"])
