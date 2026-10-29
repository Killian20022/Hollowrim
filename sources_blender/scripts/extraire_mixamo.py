# Extraction des coups d'épée en capture de mouvement Mixamo (corps entier) -> données de bras FPS, dans le repère de la
# caméra du jeu (+X droite, +Y haut, +Z arrière ; le personnage Mixamo importé regarde vers -Y, sa droite est -X).
#
#   blender.exe -b --python sources_blender/scripts/extraire_mixamo.py -- --fbx=<dossier des .fbx> \
#       [--sortie=sources_blender/mixamo/coups_mixamo.json]
#
# Les .fbx Mixamo (gratuits, usage commercial permis, redistribution des fichiers bruts INTERDITE) restent hors du dépôt
# (references/mixamo/). Seules les données converties (rotations d'os, pas le fichier source) sont écrites ici, puis
# anim_bras_epee.py les retarget sur le bras FPS (voir docs/COMBAT.md, « Coups Mixamo »).
# Par image (fréquence de la source, 30 i/s) : rotation MONDE (repère caméra) de l'épaule, du bras, de l'avant-bras et de
# la main droite (quaternions w, x, y, z) et positions (m) de l'épaule (tête du bras), du coude, du poignet, du cou et de
# la tête, relatives au cou.
import bpy, sys, os, json
from mathutils import Matrix, Vector

ARGS = {}
if "--" in sys.argv:
    for a in sys.argv[sys.argv.index("--") + 1:]:
        k, _, v = a.lstrip("-").partition("=")
        ARGS[k] = v
BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES = {   # nom -> fichier Mixamo
    "slash_0": "Sword And Shield Slash.fbx",
    "slash_1": "Sword And Shield Slash (1).fbx",
    "slash_2": "Sword And Shield Slash (2).fbx",
}
OS = {"epaule": "RightShoulder", "bras": "RightArm", "avant_bras": "RightForeArm", "main": "RightHand"}
# repère caméra <- monde Blender du personnage Mixamo (colonnes : droite, haut, arrière)
F = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0))).transposed()
CAM_DE_MONDE = F.transposed()

sortie = ARGS.get("sortie", os.path.join(BASE, "sources_blender", "mixamo", "coups_mixamo.json"))
donnees = {}
for nom, fichier in SOURCES.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(ARGS["fbx"], fichier))
    a = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    act = a.animation_data.action
    sc = bpy.context.scene
    r0, r1 = int(act.frame_range[0]), int(act.frame_range[1])
    images = []
    for fr in range(r0, r1 + 1):
        sc.frame_set(fr)
        pb = lambda n: a.pose.bones["mixamorig:" + n]
        pos = lambda n: CAM_DE_MONDE @ (a.matrix_world @ pb(n).head)
        cou = pos("Neck")
        im = {}
        for cle, n in OS.items():
            R = CAM_DE_MONDE @ (a.matrix_world @ pb(n).matrix).to_3x3().normalized()
            q = R.to_quaternion()
            im["q_" + cle] = [round(v, 6) for v in (q.w, q.x, q.y, q.z)]
        for cle, n in (("p_epaule", "RightArm"), ("p_coude", "RightForeArm"), ("p_poignet", "RightHand"), ("p_tete", "Head"),
                       ("p_index", "RightHandIndex1"), ("p_auriculaire", "RightHandPinky1")):
            im[cle] = [round(v, 5) for v in (pos(n) - cou)]
        im["p_cou"] = [round(v, 5) for v in cou]
        images.append(im)
    donnees[nom] = {"fichier": fichier, "fps": sc.render.fps, "images": images}
    print("MIXAMO", nom, fichier, len(images), "images à", sc.render.fps, "i/s")
os.makedirs(os.path.dirname(sortie), exist_ok=True)
with open(sortie, "w", encoding="utf-8") as f:
    json.dump(donnees, f, separators=(",", ":"))
print("ECRIT", sortie)
