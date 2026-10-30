# Variante d'extraire_mixamo.py pour les clips Quaternius « Universal Animation Library 2 » (CC0, rig à 65 os, nommage
# type mannequin Unreal : clavicle_r, upperarm_r, lowerarm_r, hand_r, index_01_r, pinky_01_r, neck_01, Head). Même format
# de sortie que coups_mixamo.json (repère caméra du jeu : +X droite, +Y haut, +Z arrière ; positions relatives au cou),
# donc anim_bras_epee.creer_action_mixamo retarget ces clips sans changement (source « q_<clip> »).
#
#   blender.exe -b --python sources_blender/scripts/extraire_quaternius.py -- --glb=<UAL2_Standard.glb> \
#       [--clips=Sword_Regular_A,Sword_Regular_B] [--sortie=sources_blender/mixamo/coups_quaternius.json]
#
# Le .glb (CC0) reste hors du dépôt (references/quaternius_anims/). Repère : calculé sur la 1re image de chaque clip
# (droite = épaule gauche -> épaule droite à plat, haut = Z de Blender, arrière = droite x haut) : le personnage regarde
# donc toujours vers -Z de la caméra, quel que soit son orientation dans le fichier.
import bpy, sys, os, json
from mathutils import Matrix, Vector

ARGS = {}
if "--" in sys.argv:
    for a in sys.argv[sys.argv.index("--") + 1:]:
        k, _, v = a.lstrip("-").partition("=")
        ARGS[k] = v
BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLIPS = [c for c in ARGS.get("clips", "Sword_Regular_A,Sword_Regular_B,Sword_Regular_C,Sword_Regular_Combo,Sword_Heavy_Combo,Sword_Attack").split(",") if c]
OS = {"epaule": "clavicle_r", "bras": "upperarm_r", "avant_bras": "lowerarm_r", "main": "hand_r"}
POS = (("p_epaule", "upperarm_r"), ("p_coude", "lowerarm_r"), ("p_poignet", "hand_r"), ("p_tete", "Head"),
       ("p_index", "index_01_r"), ("p_auriculaire", "pinky_01_r"))
sortie = ARGS.get("sortie", os.path.join(BASE, "sources_blender", "mixamo", "coups_quaternius.json"))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=ARGS["glb"])
a = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
a.animation_data_create()
sc = bpy.context.scene
donnees = json.load(open(sortie, encoding="utf-8")) if os.path.exists(sortie) else {}
noms_actions = {act.name: act for act in bpy.data.actions}
for clip in CLIPS:
    act = noms_actions.get(clip) or next((v for k, v in noms_actions.items() if k.startswith(clip + "_") or k.endswith("|" + clip) or k == clip), None)
    if act is None:
        print("ABSENT", clip, sorted(noms_actions)[:80])
        continue
    a.animation_data.action = act
    if hasattr(a.animation_data, "action_slot") and len(getattr(act, "slots", [])) > 0:
        a.animation_data.action_slot = act.slots[0]
    r0, r1 = int(act.frame_range[0]), int(round(act.frame_range[1]))
    pb = lambda n: a.pose.bones[n]
    monde = lambda n: a.matrix_world @ pb(n).head
    sc.frame_set(r0)
    droite = monde("upperarm_r") - monde("upperarm_l")
    droite.z = 0.0
    droite.normalize()
    haut = Vector((0, 0, 1))
    arriere = droite.cross(haut)
    CAM_DE_MONDE = Matrix((droite, haut, arriere))   # lignes : composantes caméra = produits scalaires
    images = []
    for fr in range(r0, r1 + 1):
        sc.frame_set(fr)
        cou = CAM_DE_MONDE @ monde("neck_01")
        im = {}
        for cle, n in OS.items():
            R = CAM_DE_MONDE @ (a.matrix_world @ pb(n).matrix).to_3x3().normalized()
            q = R.to_quaternion()
            im["q_" + cle] = [round(v, 6) for v in (q.w, q.x, q.y, q.z)]
        for cle, n in POS:
            im[cle] = [round(v, 5) for v in (CAM_DE_MONDE @ monde(n) - cou)]
        im["p_cou"] = [round(v, 5) for v in cou]
        images.append(im)
    donnees["q_" + clip] = {"fichier": "UAL2_Standard.glb:" + clip, "fps": sc.render.fps, "images": images}
    print("QUATERNIUS", clip, act.name, len(images), "images à", sc.render.fps, "i/s")
os.makedirs(os.path.dirname(sortie), exist_ok=True)
with open(sortie, "w", encoding="utf-8") as f:
    json.dump(donnees, f, separators=(",", ":"))
print("ECRIT", sortie)
