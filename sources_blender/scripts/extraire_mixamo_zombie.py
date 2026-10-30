# Extraction du « Not So Scary Zombie Pack » Mixamo (corps entier) -> données de mouvement pour les draugrs (squelette Quaternius).
#
#   blender.exe -b --python sources_blender/scripts/extraire_mixamo_zombie.py -- --fbx=<dossier zombie_pack> \
#       [--sortie=sources_blender/mixamo/zombie_mixamo.json]
#
# Les .fbx Mixamo (usage commercial permis, redistribution des fichiers bruts INTERDITE) restent hors du dépôt
# (references/mixamo/zombie_pack/). Seules les données converties sont écrites ici : par image, rotation MONDE de chaque os
# utile (quaternion w, x, y, z) et position du bassin, déjà dans le repère de Godot (+X gauche du personnage, +Y haut, +Z avant :
# le personnage Mixamo importé regarde vers -Y Blender) ; au repos : rotation monde et position de la tête de chaque os.
# outils/zombie_retarget.gd en fait les clips « Zombie_* » du squelette Quaternius (assets/modeles/humains/animations_zombie.res).
#
# Contenu réel des clips (mesuré le 2026-10-30) : aucun ne rampe (« transition » = debout -> attente
# voûtée, « agonizing » = se tord sur place debout, « stumbling » = trébuche de côté puis tombe).
import bpy, sys, os, json
from mathutils import Matrix, Vector

ARGS = {}
if "--" in sys.argv:
    for a in sys.argv[sys.argv.index("--") + 1:]:
        k, _, v = a.lstrip("-").partition("=")
        ARGS[k] = v
BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# nom du clip -> (fichier, image de début, image de fin (0 = dernière), « sur place » : 0 = garder le trajet du bassin,
# 1 = retirer la dérive horizontale linéaire (boucles), 2 = retirer tout le trajet horizontal (bassin ramené au départ))
SOURCES = {
    "Zombie_Reveil": ("zombie stand up.fbx", 1, 0, 0),        # allongé face au sol -> debout (3,1 s)
    "Zombie_Marche": ("walking.fbx", 1, 0, 1),                # démarche titubante, boucle (0,55 m/s d'origine)
    "Zombie_Attente": ("zombie idle.fbx", 1, 0, 1),           # attente voûtée qui oscille, boucle
    "Zombie_Poing": ("zombie punching.fbx", 1, 0, 2),         # coup de poing bref (1 s)
    "Zombie_Tete": ("zombie headbutt.fbx", 1, 0, 2),          # coup de tête (2,6 s)
    "Zombie_Griffes": ("zombie attack.fbx", 1, 110, 2),       # deux bras levés, abattus en griffant (coupé à 3,6 s : la fin est un retour lent)
    "Zombie_Coup": ("zombie reaction hit.fbx", 1, 0, 2),      # encaisse, buste rejeté
    "Zombie_Coup2": ("zombie reaction hit (2).fbx", 1, 0, 2), # encaisse et recule (trajet retiré : le jeu applique son recul)
}
# os Mixamo -> os Quaternius (le retarget aligne la direction tête -> enfant de chaque os sur celle du squelette cible)
OS = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "HeadTop_End"]
for c in ("Left", "Right"):
    OS += [c + n for n in ("Shoulder", "Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot", "ToeBase", "Toe_End")]
    for d in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
        OS += ["%sHand%s%d" % (c, d, i) for i in (1, 2, 3, 4)]
# Blender (Z haut, personnage vers -Y) -> Godot (Y haut, personnage vers +Z) : (x, y, z) -> (x, z, -y)
C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
CT = C.transposed()

def quat(R):
    q = (C @ R @ CT).to_quaternion()
    return [round(v, 5) for v in (q.w, q.x, q.y, q.z)]

def vec(p):
    v = C @ p
    return [round(x, 4) for x in v]

sortie = ARGS.get("sortie", os.path.join(BASE, "sources_blender", "mixamo", "zombie_mixamo.json"))
donnees = {}
for nom, (fichier, i0, i1, sur_place) in SOURCES.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(ARGS["fbx"], fichier))
    a = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    act = a.animation_data.action
    sc = bpy.context.scene
    r0, r1 = int(act.frame_range[0]), int(act.frame_range[1])
    r0 = max(r0, i0)
    if i1 > 0:
        r1 = min(r1, i1)
    mw = a.matrix_world
    presents = [n for n in OS if ("mixamorig:" + n) in a.data.bones]
    repos = {}
    for n in presents:
        b = a.data.bones["mixamorig:" + n]
        repos[n] = {"q": quat((mw @ b.matrix_local).to_3x3().normalized()), "p": vec(mw @ b.head_local)}
    images = []
    bassins = []
    for fr in range(r0, r1 + 1):
        sc.frame_set(fr)
        im = {}
        for n in presents:
            pb = a.pose.bones["mixamorig:" + n]
            im[n] = quat((mw @ pb.matrix).to_3x3().normalized())
        bassins.append(C @ (mw @ a.pose.bones["mixamorig:Hips"].head))
        images.append(im)
    # trajet horizontal du bassin (X, Z Godot)
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
    # image du contact (attaques) : main la plus en avant (+Z) pour les coups de poing/griffes, tête pour le coup de tête
    impact = -1.0
    if nom in ("Zombie_Poing", "Zombie_Griffes", "Zombie_Tete"):
        cles = ["Head"] if nom == "Zombie_Tete" else ["RightHand", "LeftHand"]
        best, kbest = -1e9, 0
        for k, fr in enumerate(range(r0, r1 + 1)):
            sc.frame_set(fr)
            h = C @ (mw @ a.pose.bones["mixamorig:Hips"].head)
            for c in cles:
                z = (C @ (mw @ a.pose.bones["mixamorig:" + c].head)).z - bassins[0].z
                if z > best:
                    best, kbest = z, k
        impact = round(kbest / max(n_im - 1, 1), 3)
    donnees[nom] = {"fichier": fichier, "fps": sc.render.fps, "repos": repos, "images": images, "impact": impact,
                    "boucle": sur_place == 1}
    print("ZOMBIE", nom, fichier, n_im, "images à", sc.render.fps, "i/s, impact", impact, "os", len(presents))
os.makedirs(os.path.dirname(sortie), exist_ok=True)
with open(sortie, "w", encoding="utf-8") as f:
    json.dump(donnees, f, separators=(",", ":"))
print("ECRIT", sortie, os.path.getsize(sortie), "octets")
