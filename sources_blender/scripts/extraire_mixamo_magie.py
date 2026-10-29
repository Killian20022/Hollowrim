# Extraction des gestes de magie en capture de mouvement Mixamo (« Magic Spell Pack », corps entier) -> données des DEUX
# bras, dans le repère de la caméra du jeu (+X droite, +Y haut, +Z arrière ; le personnage Mixamo importé regarde vers -Y,
# sa droite est -X). Même méthode que extraire_mixamo.py (coups d'épée), étendue à la main gauche et aux doigts.
#
#   blender.exe -b --python sources_blender/scripts/extraire_mixamo_magie.py -- --fbx=<dossier des .fbx> \
#       [--sortie=sources_blender/mixamo/gestes_magie_mixamo.json] [--tous]
#
# Les .fbx Mixamo (gratuits, usage commercial permis, redistribution des fichiers bruts INTERDITE) restent hors du dépôt
# (references/mixamo/magic_spell_pack/). Seules les données converties (positions d'articulations, pas le fichier source)
# sont écrites ici, puis gestes_magie.py les retarget sur les poses FPS de la main qui incante (docs/MAGIE.md,
# « Gestes Mixamo »). --tous : extrait tout le pack (exploration, choix des clips) ; sinon seulement les clips retenus.
# Par image (30 i/s) et par côté (« g », « d ») : positions (m) relatives au cou de l'épaule (tête du bras), du coude, du
# poignet, de la base de l'index, de l'auriculaire et du majeur, du bout du majeur (fermeture de la main) ; plus la tête.
import bpy, sys, os, json
from mathutils import Matrix

ARGS = {}
if "--" in sys.argv:
    for a in sys.argv[sys.argv.index("--") + 1:]:
        k, _, v = a.lstrip("-").partition("=")
        ARGS[k] = v
BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RETENUS = {   # nom -> fichier Mixamo (clips utilisés par gestes_magie.py)
    "jet_1m": "Standing 1H Magic Attack 01.fbx",        # sort rapide et sort chargé (main droite de la capture)
    "jet_2m": "Standing 2H Magic Attack 03.fbx",        # jet tenu à une main (main gauche : maintien bras tendu ~2 s)
    "souffle_2m": "Standing 2H Magic Attack 04.fbx",    # double incantation (les deux mains)
    "zone_2m": "Standing 2H Magic Area Attack 01.fbx",  # sort de zone (main levée poing fermé, frappe vers le sol)
}
TOUS = {
    "c1m_cast_01": "standing 1H cast spell 01.fbx",
    "c1m_att_01": "Standing 1H Magic Attack 01.fbx",
    "c1m_att_02": "Standing 1H Magic Attack 02.fbx",
    "c1m_att_03": "Standing 1H Magic Attack 03.fbx",
    "c2m_cast_01": "Standing 2H Cast Spell 01.fbx",
    "c2m_zone_01": "Standing 2H Magic Area Attack 01.fbx",
    "c2m_zone_02": "Standing 2H Magic Area Attack 02.fbx",
    "c2m_att_01": "Standing 2H Magic Attack 01.fbx",
    "c2m_att_02": "Standing 2H Magic Attack 02.fbx",
    "c2m_att_03": "Standing 2H Magic Attack 03.fbx",
    "c2m_att_04": "Standing 2H Magic Attack 04.fbx",
    "c2m_att_05": "Standing 2H Magic Attack 05.fbx",
    "idle": "standing idle.fbx",
    "epee_bouclier_sort": "../Sword And Shield Casting.fbx",
}
SOURCES = TOUS if "tous" in ARGS else RETENUS
COTES = {"g": "Left", "d": "Right"}
# repère caméra <- monde Blender du personnage Mixamo (colonnes : droite, haut, arrière)
F = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0))).transposed()
CAM_DE_MONDE = F.transposed()

sortie = ARGS.get("sortie", os.path.join(BASE, "sources_blender", "mixamo", "gestes_magie_mixamo.json"))
donnees = {}
for nom, fichier in SOURCES.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.normpath(os.path.join(ARGS["fbx"], fichier)))
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
        im = {"tete": [round(v, 5) for v in (pos("Head") - cou)], "cou": [round(v, 5) for v in cou]}
        for c, s in COTES.items():
            for cle, n in (("epaule", "Arm"), ("coude", "ForeArm"), ("poignet", "Hand"), ("index", "HandIndex1"),
                           ("auriculaire", "HandPinky1"), ("majeur", "HandMiddle1"), ("majeur_bout", "HandMiddle4")):
                im[cle + "_" + c] = [round(v, 5) for v in (pos(s + n) - cou)]
        images.append(im)
    donnees[nom] = {"fichier": os.path.basename(fichier), "fps": sc.render.fps, "images": images}
    print("MIXAMO", nom, fichier, len(images), "images à", sc.render.fps, "i/s")
os.makedirs(os.path.dirname(sortie), exist_ok=True)
with open(sortie, "w", encoding="utf-8") as f:
    json.dump(donnees, f, separators=(",", ":"))
print("ECRIT", sortie)
