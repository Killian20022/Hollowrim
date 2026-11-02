# Coups d'arme du CORPS À LA TROISIÈME PERSONNE (branche tps/coups) : captures Mixamo (corps entier) et clips Quaternius UAL2
# (CC0, même squelette 65 os que le corps du joueur) -> données de mouvement pour outils/coups_tps_retarget.gd.
#
#   blender.exe -b --python sources_blender/scripts/extraire_coups_tps.py -- --ref=<dossier references> \
#       [--sortie=sources_blender/mixamo/coups_tps.json] [--seulement=a,b]
#
# Même format et même repère que extraire_mixamo_zombie.py (draugrs zombies, méthode validée) : par image, rotation MONDE de
# chaque os (quaternion w, x, y, z) et position du bassin, repère de Godot (+X gauche du personnage, +Y haut, +Z avant) ; au
# repos : rotation monde et position de la tête de chaque os. Les clips Quaternius sont écrits sous les NOMS MIXAMO (Hips,
# RightArm…) : le retarget ne connaît qu'une seule convention.
# Les .fbx Mixamo (redistribution des fichiers bruts INTERDITE) et le .glb UAL2 restent hors du dépôt (references/).
import bpy, sys, os, json
from mathutils import Matrix, Vector

ARGS = {}
if "--" in sys.argv:
    for a in sys.argv[sys.argv.index("--") + 1:]:
        k, _, v = a.lstrip("-").partition("=")
        ARGS[k] = v
BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MX = "mixamo/"
SS = "mixamo/sword_and_shield_pack/sword and shield "
GS = "mixamo/great_sword_pack/great sword "
UAL2 = "quaternius_anims/UAL2/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb"
# nom -> (fichier relatif à references/ [« fichier.glb|Action » pour le glb UAL2], image de début, image de fin (0 = dernière),
# trajet du bassin : 0 = gardé, 1 = dérive horizontale linéaire retirée, 2 = tout le trajet horizontal retiré)
SOURCES = {
    # une main (mêmes captures que les coups FPS validés, scripts gestes_bras_epee.py / gestes_une_main.py)
    "slash_1": (MX + "Sword And Shield Slash (1).fbx", 1, 0, 1),
    "slash_2": (MX + "Sword And Shield Slash (2).fbx", 1, 0, 1),
    "slash_0": (MX + "Sword And Shield Slash.fbx", 1, 0, 1),
    "estoc": (MX + "Stabbing.fbx", 1, 0, 1),
    "vertical": (MX + "Standing Melee Attack Downward.fbx", 1, 0, 1),
    "revers_b": (MX + "Standing Melee Attack Backhand.fbx", 1, 0, 1),
    "revers": (MX + "Stable Sword Outward Slash.fbx", 1, 0, 1),
    "interieur": (MX + "Stable Sword Inward Slash.fbx", 1, 0, 1),
    "ss_slash": (SS + "slash.fbx", 1, 0, 1),
    "ss_slash_2": (SS + "slash (2).fbx", 1, 0, 1),
    "ss_slash_3": (SS + "slash (3).fbx", 1, 0, 1),
    "ss_slash_4": (SS + "slash (4).fbx", 1, 0, 1),
    "ss_slash_5": (SS + "slash (5).fbx", 1, 0, 1),
    "ss_attack": (SS + "attack.fbx", 1, 0, 1),
    "ss_attack_2": (SS + "attack (2).fbx", 1, 0, 1),
    "ss_attack_3": (SS + "attack (3).fbx", 1, 0, 1),
    "ss_attack_4": (SS + "attack (4).fbx", 1, 0, 1),
    "ss_block": (SS + "block.fbx", 1, 0, 2),
    "ss_block_2": (SS + "block (2).fbx", 1, 0, 2),
    "ss_block_idle": (SS + "block idle.fbx", 1, 0, 2),
    "ss_impact": (SS + "impact.fbx", 1, 0, 2),
    "ss_impact_2": (SS + "impact (2).fbx", 1, 0, 2),
    "ss_idle": (SS + "idle.fbx", 1, 0, 2),
    # deux mains (claymore, grand marteau : mêmes captures que claymore v3)
    "gs_slash": (GS + "slash.fbx", 1, 0, 1),
    "gs_slash_2": (GS + "slash (2).fbx", 1, 0, 1),
    "gs_slash_3": (GS + "slash (3).fbx", 1, 0, 1),
    "gs_attack": (GS + "attack.fbx", 1, 0, 1),
    "gs_block": (GS + "blocking.fbx", 1, 0, 2),
    "gs_block_2": (GS + "blocking (2).fbx", 1, 0, 2),
    "gs_impact": (GS + "impact.fbx", 1, 0, 2),
    "gs_idle": (GS + "idle.fbx", 1, 0, 2),
    # Quaternius UAL2 (CC0)
    "q_Sword_Regular_Combo": (UAL2 + "|Sword_Regular_Combo", 0, 0, 1),
    "q_Sword_Heavy_Combo": (UAL2 + "|Sword_Heavy_Combo", 0, 0, 1),
    "q_Sword_Block": (UAL2 + "|Sword_Block", 0, 0, 2),
    "q_Idle_Shield_Break": (UAL2 + "|Idle_Shield_Break", 0, 0, 2),
}
OS = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "HeadTop_End"]
for c in ("Left", "Right"):
    OS += [c + n for n in ("Shoulder", "Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot", "ToeBase", "Toe_End")]
    for d in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
        OS += ["%sHand%s%d" % (c, d, i) for i in (1, 2, 3, 4)]
# nom Mixamo -> os Quaternius (UAL2)
Q = {"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03", "Neck": "neck_01", "Head": "Head"}
for c, q in (("Left", "l"), ("Right", "r")):
    Q.update({c + "Shoulder": "clavicle_" + q, c + "Arm": "upperarm_" + q, c + "ForeArm": "lowerarm_" + q, c + "Hand": "hand_" + q,
              c + "UpLeg": "thigh_" + q, c + "Leg": "calf_" + q, c + "Foot": "foot_" + q, c + "ToeBase": "ball_" + q,
              c + "Toe_End": "ball_leaf_" + q})
    for d, dq in (("Thumb", "thumb"), ("Index", "index"), ("Middle", "middle"), ("Ring", "ring"), ("Pinky", "pinky")):
        for i in (1, 2, 3):
            Q["%sHand%s%d" % (c, d, i)] = "%s_0%d_%s" % (dq, i, q)
        Q["%sHand%s4" % (c, d)] = "%s_04_leaf_%s" % (dq, q)
C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
CT = C.transposed()


def quat(R):
    q = (C @ R @ CT).to_quaternion()
    return [round(v, 5) for v in (q.w, q.x, q.y, q.z)]


def vec(p):
    return [round(x, 4) for x in (C @ p)]


ref = ARGS["ref"]
sortie = ARGS.get("sortie", os.path.join(BASE, "sources_blender", "mixamo", "coups_tps.json"))
seulement = [x for x in ARGS.get("seulement", "").split(",") if x]
donnees = json.load(open(sortie, encoding="utf-8")) if (seulement and os.path.exists(sortie)) else {}
glb_charge = None
for nom, (fichier, i0, i1, sur_place) in SOURCES.items():
    if seulement and nom not in seulement:
        continue
    action = ""
    if "|" in fichier:
        fichier, action = fichier.split("|")
    chemin = os.path.join(ref, fichier)
    if not os.path.exists(chemin):
        print("ABSENT", nom, chemin)
        continue
    if action:
        if glb_charge != chemin:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.context.scene.render.fps = 30
            bpy.ops.import_scene.gltf(filepath=chemin)
            glb_charge = chemin
        a = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
        a.animation_data_create()
        act = next((v for k, v in bpy.data.actions.items() if k == action or k.endswith("|" + action) or k.startswith(action + "_")), None)
        if act is None:
            print("ABSENT action", action, sorted(bpy.data.actions.keys())[:60])
            continue
        a.animation_data.action = act
        nom_os = lambda n: Q.get(n, "")
    else:
        glb_charge = None
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=chemin)
        a = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
        act = a.animation_data.action
        nom_os = lambda n: "mixamorig:" + n
    sc = bpy.context.scene
    r0, r1 = int(act.frame_range[0]), int(act.frame_range[1])
    r0 = max(r0, i0)
    if i1 > 0:
        r1 = min(r1, i1)
    mw = a.matrix_world
    presents = [n for n in OS if nom_os(n) in a.data.bones]
    repos = {}
    for n in presents:
        b = a.data.bones[nom_os(n)]
        repos[n] = {"q": quat((mw @ b.matrix_local).to_3x3().normalized()), "p": vec(mw @ b.head_local)}
    images, bassins = [], []
    for fr in range(r0, r1 + 1):
        sc.frame_set(fr)
        im = {}
        for n in presents:
            pb = a.pose.bones[nom_os(n)]
            im[n] = quat((mw @ pb.matrix).to_3x3().normalized())
        bassins.append(C @ (mw @ a.pose.bones[nom_os("Hips")].head))
        images.append(im)
    n_im = len(bassins)
    for k in range(n_im):
        p = bassins[k].copy()
        if sur_place == 1:
            t = k / max(n_im - 1, 1)
            p.x -= bassins[0].x + (bassins[-1].x - bassins[0].x) * t
            p.z -= bassins[0].z + (bassins[-1].z - bassins[0].z) * t
        elif sur_place == 2:
            p.x -= bassins[0].x
            p.z -= bassins[0].z
        images[k]["_bassin"] = [round(x, 4) for x in p]
    donnees[nom] = {"fichier": os.path.basename(fichier) + ("|" + action if action else ""), "fps": sc.render.fps,
                    "repos": repos, "images": images, "impact": -1.0, "boucle": False}
    print("TPS", nom, n_im, "images à", sc.render.fps, "i/s, os", len(presents))
os.makedirs(os.path.dirname(sortie), exist_ok=True)
with open(sortie, "w", encoding="utf-8") as f:
    json.dump(donnees, f, separators=(",", ":"))
print("ECRIT", sortie, os.path.getsize(sortie), "octets")
