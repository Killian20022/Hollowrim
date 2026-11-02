# Extraction du « Magic Spell Pack » Mixamo (corps entier) -> clips d'incantation du CORPS à la 3e personne (squelette Quaternius).
# Même méthode et même format que extraire_mixamo_zombie.py ; outils/zombie_retarget.gd --source/--sortie en fait
# assets/modeles/humains/animations_sorts_tps.res (lu par scripts/corps_mains_tps.gd, couche du bras qui incante).
#
#   blender.exe -b --python sources_blender/scripts/extraire_mixamo_sorts_tps.py -- --fbx=<dossier magic_spell_pack> \
#       [--sortie=sources_blender/mixamo/sorts_tps_mixamo.json]
#
# Les .fbx Mixamo (usage commercial permis, redistribution des fichiers bruts INTERDITE) restent hors du dépôt
# (references/mixamo/magic_spell_pack/). Seules les données converties sont écrites (rotations monde des os, bassin).
# Chaque clip existe aussi en MIROIR (suffixe « _G ») : gauche <-> droite échangés, rotations réfléchies sur le plan X
# (q = (w, x, y, z) -> (w, x, -y, -z), positions x -> -x) : le geste de la main droite de la capture fait par la main gauche.
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
# clips retenus (planche outils/planche_clips_tps.gd sur tout le pack, 2026-11-02) ; les autres fichiers du pack : voir extraire_mixamo_magie.py
SOURCES = {
    "Sort_Lancer1M": ("Standing 1H Magic Attack 01.fbx", 1, 0, 2),     # sort lancé d'une main (main droite)
    "Sort_Zone2M": ("Standing 2H Magic Area Attack 01.fbx", 1, 0, 2),
    "Sort_Jet2M": ("Standing 2H Magic Attack 03.fbx", 1, 0, 2),        # jet tenu, bras tendu (~2 s)
    "Sort_Souffle2M": ("Standing 2H Magic Attack 04.fbx", 1, 0, 2),    # deux mains (double incantation)
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

sortie = ARGS.get("sortie", os.path.join(BASE, "sources_blender", "mixamo", "sorts_tps_mixamo.json"))
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
    if True:
        cles = ["RightHand", "LeftHand"]
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
    print("SORT", nom, fichier, n_im, "images à", sc.render.fps, "i/s, impact", impact, "os", len(presents))
# miroirs (main gauche) : gauche <-> droite, réflexion sur le plan X
def _nom_miroir(n):
    return n.replace("Left", "@").replace("Right", "Left").replace("@", "Right")
def _q_miroir(q):
    return [q[0], q[1], -q[2], -q[3]]
for nom in list(donnees.keys()):
    d = donnees[nom]
    m = {"fichier": d["fichier"], "fps": d["fps"], "impact": d["impact"], "boucle": d["boucle"], "miroir": True}
    m["repos"] = {_nom_miroir(n): {"q": _q_miroir(v["q"]), "p": [-v["p"][0], v["p"][1], v["p"][2]]} for n, v in d["repos"].items()}
    m["images"] = []
    for im in d["images"]:
        im2 = {}
        for n, v in im.items():
            if n == "_bassin":
                im2[n] = [-v[0], v[1], v[2]]
            else:
                im2[_nom_miroir(n)] = _q_miroir(v)
        m["images"].append(im2)
    donnees[nom + "_G"] = m
os.makedirs(os.path.dirname(sortie), exist_ok=True)
with open(sortie, "w", encoding="utf-8") as f:
    json.dump(donnees, f, separators=(",", ":"))
print("ECRIT", sortie, os.path.getsize(sortie), "octets")
