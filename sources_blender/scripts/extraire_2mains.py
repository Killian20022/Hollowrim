# Variante d'extraire_mixamo.py pour les armes à DEUX MAINS : extrait les DEUX bras (droit + gauche) des captures
# Mixamo « Great Sword Pack » (et de tout fichier au rig Mixamo), dans le repère de la caméra du jeu (+X droite, +Y haut,
# +Z arrière), même format que coups_mixamo.json (clés q_*/p_* du bras droit) + les mêmes clés suffixées « _g » pour le
# bras gauche. Sert à anim_bras_epee.py (CLIPS_MIXAMO, source « 2m:<nom> ») et au contrôle de la prise à deux mains
# (distance poignet droit - poignet gauche).
#
#   blender.exe -b --python sources_blender/scripts/extraire_2mains.py -- --fbx=<references/mixamo> \
#       [--sortie=sources_blender/mixamo/coups_2mains.json] [--seulement=gs_slash_3,...]
#
# Les .fbx Mixamo restent hors du dépôt (references/mixamo/) ; seules les rotations / positions converties sont écrites.
import bpy, sys, os, json
from mathutils import Matrix

ARGS = {}
if "--" in sys.argv:
    for a in sys.argv[sys.argv.index("--") + 1:]:
        k, _, v = a.lstrip("-").partition("=")
        ARGS[k] = v
BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GS = "great_sword_pack/great sword "
SOURCES = {
    "gs_idle": GS + "idle.fbx", "gs_idle_2": GS + "idle (2).fbx", "gs_idle_3": GS + "idle (3).fbx",
    "gs_idle_4": GS + "idle (4).fbx", "gs_idle_5": GS + "idle (5).fbx",
    "gs_slash": GS + "slash.fbx", "gs_slash_2": GS + "slash (2).fbx", "gs_slash_3": GS + "slash (3).fbx",
    "gs_slash_4": GS + "slash (4).fbx", "gs_slash_5": GS + "slash (5).fbx",
    "gs_attack": GS + "attack.fbx", "gs_spin": GS + "high spin attack.fbx", "gs_jump_attack": GS + "jump attack.fbx",
    "gs_block": GS + "blocking.fbx", "gs_block_2": GS + "blocking (2).fbx", "gs_block_3": GS + "blocking (3).fbx",
    "gs_impact": GS + "impact.fbx", "gs_impact_2": GS + "impact (2).fbx",
}
F = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0))).transposed()
CAM_DE_MONDE = F.transposed()
COTES = {"": "Right", "_g": "Left"}

sortie = ARGS.get("sortie", os.path.join(BASE, "sources_blender", "mixamo", "coups_2mains.json"))
seulement = [x for x in ARGS.get("seulement", "").split(",") if x]
donnees = {}
if seulement and os.path.exists(sortie):
    donnees = json.load(open(sortie, encoding="utf-8"))
for nom, fichier in SOURCES.items():
    if seulement and nom not in seulement:
        continue
    chemin = os.path.join(ARGS["fbx"], fichier)
    if not os.path.exists(chemin):
        print("ABSENT", chemin)
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=chemin)
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
        im = {"p_cou": [round(v, 5) for v in cou], "p_tete": [round(v, 5) for v in (pos("Head") - cou)]}
        for suf, c in COTES.items():
            for cle, n in (("epaule", "Shoulder"), ("bras", "Arm"), ("avant_bras", "ForeArm"), ("main", "Hand")):
                R = CAM_DE_MONDE @ (a.matrix_world @ pb(c + n).matrix).to_3x3().normalized()
                q = R.to_quaternion()
                im["q_" + cle + suf] = [round(v, 6) for v in (q.w, q.x, q.y, q.z)]
            for cle, n in (("p_epaule", "Arm"), ("p_coude", "ForeArm"), ("p_poignet", "Hand"),
                           ("p_index", "HandIndex1"), ("p_auriculaire", "HandPinky1")):
                im[cle + suf] = [round(v, 5) for v in (pos(c + n) - cou)]
        images.append(im)
    donnees[nom] = {"fichier": fichier, "fps": sc.render.fps, "images": images}
    print("2MAINS", nom, fichier, len(images), "images à", sc.render.fps, "i/s")
os.makedirs(os.path.dirname(sortie), exist_ok=True)
with open(sortie, "w", encoding="utf-8") as f:
    json.dump(donnees, f, separators=(",", ":"))
print("ECRIT", sortie)
