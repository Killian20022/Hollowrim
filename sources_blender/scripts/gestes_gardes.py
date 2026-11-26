# GARDE / BLOCAGE DE TOUTES LES ARMES (branche combat/gardes_toutes_armes, 2026-11-26) — clips du bras droit du viewmodel FPS,
# bibliothèque À PART : assets/animations/bras_gardes.tres (préfixe « garde/ » dans le jeu, AnimateurBras.GARDES).
#
#   blender.exe -b sources_blender/bras_fps.blend --python sources_blender/scripts/gestes_gardes.py -- --godot [--clips=g1_garde,...]
#       [--essai=<fichier.json>]   (réglages essayés sans modifier ce fichier : {"g1_garde": {"cadrage": [0, 10, 30]}, ...})
#
# Retour utilisateur (2026-11-26) : « en défense, l'avant-bras vertical et le poignet horizontal, ça fait un angle de 90 degrés,
# ça n'a aucun sens, la hache devrait être de biais pour bloquer un coup » ; « fais la même chose pour tout quand on se défend,
# même sur l'épée ». Les anciennes gardes à une main (gestes_bras_epee.GARDE / ENCAISSE / PARADE) étaient des POSES ÉCRITES À LA
# MAIN (mesuré dans le jeu : poignet en flexion 76° et déviation 41°, lame à 65° de la verticale) ; garde_2m venait déjà d'une
# capture mais encaisse_2m / parade_2m étaient écrites (poignet à 55° à l'impact).
#
# MÊME MÉTHODE que les coups v6 validés (anim_bras_epee.creer_action_mixamo, lu tel quel sans le modifier) : captures Mixamo de
# BLOCAGE retargetées par directions (épaule, bras, avant-bras de la capture, main en orientation anatomique), POIGNET VERROUILLÉ
# dans des butées serrées autour du neutre (« poignet »), la torsion de l'avant-bras et le bras portent l'orientation de l'arme ;
# l'inclinaison de l'arme (30-60° de la verticale) vient d'une rotation RIGIDE de tout le bras autour de l'épaule (« cadrage »),
# jamais d'une rotation de poignet. Aucune pose écrite.
#   Captures (Mixamo « Great Sword Pack », extraites dans sources_blender/mixamo/coups_2mains.json par extraire_2mains.py) :
#     gs_block_2  « great sword blocking (2) »  : blocage tenu (arme levée en travers devant le visage) -> GARDE tenue ;
#     gs_impact   « great sword impact »        : coup reçu en garde (les bras cèdent, recul amorti, retour en garde, 0,8 s)
#                                                -> ENCAISSE (coup bloqué) ;
#     gs_block    « great sword blocking »      : montée en garde (images 6 -> 15) -> PARADE (la garde jaillit vers le coup puis se
#                                                replace, rejouée de 0,75 s à 0,25 s : vitesse = table « temps »).
#   Le bras droit de ces captures sert pour les armes à une main (épées, dagues, épées longues ; haches, masses, marteaux : le
#   poing tient le manche plus bas, même orientation) ; les armes à deux mains gardent l'IK de la main gauche sur le manche
#   (mains._poser_deux_mains), écartée selon ecart_mains.
# Familles (GardesArmes, scripts/combat/gardes_armes.gd) :
#     g1_*  épée, sabre, dague, épée longue (lame de biais, pointe en haut à GAUCHE devant le visage) ;
#     gl_*  hache, masse, marteau à une main (manche de biais, tête en haut à gauche, un peu plus bas et plus près : poids en tête) ;
#     g2_*  claymore, hybrides, grand marteau (deux mains : manche de biais, tête / pointe en haut à DROITE, mains espacées).
import os, sys, json

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
_src = open(os.path.join(ICI, "anim_bras_epee.py"), encoding="utf-8").read()
_src = _src[: _src.rstrip().rfind("main()")]          # le fichier finit par « main() » : on garde tout le reste
NS = {"__file__": os.path.join(ICI, "anim_bras_epee.py"), "__name__": "anim_bras_epee"}
exec(compile(_src, "anim_bras_epee.py", "exec"), NS)
import math  # noqa: E402
from mathutils import Vector  # noqa: E402

ARGS = NS["ARGS"]
# butées anatomiques larges (celles des coups v6 à deux mains) ; le verrou « poignet » de chaque clip les resserre
LIM_GARDE = dict(torsion=(-85, 85), flexion=(-55, 55), inclinaison=(-45, 18))
# poignet NEUTRE verrouillé (flexion°, inclinaison°) dans le repère du solveur (0, 0 = main dans l'axe de l'avant-bras)
POIGNET_NEUTRE = ((-12, 12), (-12, 8))


def _tenue(source, image, cadrage, decalage, poignet=POIGNET_NEUTRE, roulis_prise=0.0, duree=0.5):
    return dict(source=source, ref=0, temps=[(image, 0.0), (image, duree)], fondu=(0.0, duree), plein=(0.0, duree), cadrage=cadrage,
                decalage=decalage, amplitude=1.0, centre=image, echelle_epaule=0.5, poignet=poignet, lim_mx=LIM_GARDE,
                roulis_prise=roulis_prise, continuite=0.2)


def _choc(base, source, temps):
    """Geste de défense (coup encaissé, parade) : la capture rejouée selon `temps` [(image, s)], même cadrage que la garde,
    clip bordé par la pose de garde (la capture y part et y revient)."""
    s = dict(base)
    # amplitude 0,5 : les directions de la capture sont ramenées à mi-chemin de la garde (image « centre ») : le choc se lit (les
    # bras cèdent, recul amorti, retour), mais l'arme reste de biais (pleine amplitude : la lame se redressait à 15° de la verticale)
    s.update(source=source, temps=temps, fondu=(0.0, temps[-1][1]), plein=(0.0, temps[-1][1]), amplitude=0.5, centre=temps[0][0])
    return s


# --- réglages par famille (cadrage = lacet°, tangage°, roulis° du bras entier autour de l'épaule ; decalage = épaule, m) --------
# Choisis sur balayage (cadrage roulis -75..+90°, tangage 0..30°, lacet -25..+20° ; mesure GARDE_MESURE ci-dessous) : arme de
# biais à 40-50° de la verticale, pointe / tête en haut à droite, avant-bras à 35-45° (jamais vertical), poing dans le tiers bas
# de l'écran. Pointe à GAUCHE essayée : avec le poignet neutre, l'avant-bras doit alors PENDRE du coude (110-150° de la
# verticale, coude plus haut que la main) : rejeté.
G1 = _tenue("gs_block_2", 0, cadrage=(-25, 2, -18), decalage=(0.14, 0.02, -0.24))
GL = _tenue("gs_block_2", 0, cadrage=(-20, 5, -22), decalage=(0.12, 0.02, -0.14))
G2 = _tenue("gs_block_2", 0, cadrage=(-8, 2, -18), decalage=(0.12, 0.06, -0.18))
# grand marteau (manche ~1,2 m, poing près du bout) : avec G2, tête hors cadre et manche au centre de l'écran (relecture
# 2026-11-26) -> bras plus loin de l'œil (épaule avancée de 0,32 m) et manche plus couché (53°), tête dans le coin haut droit
GM = _tenue("gs_block_2", 0, cadrage=(-8, 2, -28), decalage=(0.14, -0.04, -0.32))
# coup encaissé : gs_impact images 0 -> 24 (choc à 3-6, recul max à 9, retour en garde à 21-24), rejoué en 0,40 s
T_ENCAISSE = [(0, 0.0), (6, 0.06), (9, 0.11), (15, 0.22), (21, 0.33), (24, 0.40)]
# parade parfaite : gs_block images 15 -> 10 -> 15 (la garde jaillit un peu plus haut puis se replace), 0,24 s
T_PARADE = [(14, 0.0), (11, 0.05), (10, 0.09), (12, 0.15), (14, 0.24)]

CLIPS = {}
for p, base in (("g1", G1), ("gl", GL), ("g2", G2), ("gg", GM)):
    CLIPS[p + "_garde"] = base
    CLIPS[p + "_encaisse"] = _choc(base, "gs_impact", T_ENCAISSE)
    CLIPS[p + "_parade"] = _choc(base, "gs_block", T_PARADE)
MARQUEURS = {}

_essai = ARGS.get("essai", "")
for _n, _r in (json.load(open(_essai, encoding="utf-8")) if _essai else {}).items():
    if _n not in CLIPS:   # variante nommée : {"g1_garde_b": {"base": "g1_garde", ...}}
        CLIPS[_n] = dict(CLIPS[_r.pop("base")])
    CLIPS[_n].update({k: ([tuple(x) if isinstance(x, list) else x for x in v] if k in ("temps", "poignet") else (tuple(v) if isinstance(v, list) else v)) for k, v in _r.items()})


def mesurer(nom, act, longueur):
    """Arme (axe Y de la prise) et avant-bras dans le repère caméra au début du clip : inclinaison à la verticale de l'écran."""
    A = NS["A"]
    NS["bpy"].context.scene.frame_set(0)
    NS["maj"]()
    C = NS["CAM_DE_B"]
    ha, la = A.pose.bones["hand_r"], A.pose.bones["lowerarm_r"]
    ax = (C.to_3x3() @ ha.matrix.to_3x3() @ NS["PRISE_D"].to_3x3()).col[1].normalized()
    fa = (C @ la.tail - C @ la.head).normalized()
    incl = lambda v: math.degrees(math.atan2(abs(v.x), v.y))
    poing = C @ ha.head
    ecr = lambda p: (p.x / max(-p.z, 0.05) / 1.2916, p.y / max(-p.z, 0.05) / 0.7265)
    e0, e1 = ecr(poing), ecr(poing + ax * float(ARGS.get("long_arme", "0.85")))
    coude = ecr(C @ la.head)
    print("GARDE_MESURE %-12s arme incl %.0f (x %+.2f y %+.2f z %+.2f) avant-bras incl %.0f (x %+.2f y %+.2f z %+.2f) ; arme/avant-bras %.0f ; "
          "écran poing (%+.2f %+.2f) pointe (%+.2f %+.2f) coude (%+.2f %+.2f)" % (
        nom, incl(ax), ax.x, ax.y, ax.z, incl(fa), fa.x, fa.y, fa.z, math.degrees(ax.angle(fa)), e0[0], e0[1], e1[0], e1[1], coude[0], coude[1]))


def main():
    NS["poings"]()
    NS["poser_torche"]()
    NS["_mx_donnees"]()
    NS["_MX"].update(json.load(open(os.path.join(NS["BASE"], "sources_blender", "mixamo", "coups_2mains.json"), encoding="utf-8")))
    noms = [c for c in ARGS.get("clips", "").split(",") if c] or list(CLIPS)
    actions = {}
    for nom in noms:
        NS["LIM_MX"].update(CLIPS[nom].get("lim_mx", LIM_GARDE))
        actions[nom] = NS["creer_action_mixamo"](nom, CLIPS[nom])
        mesurer(nom, *actions[nom])
    if "godot" in ARGS:
        NS["MARQUEURS"] = MARQUEURS
        NS["ecrire_godot"](os.path.join(NS["BASE"], "assets", "animations", ARGS.get("sortie", "bras_gardes.tres")), actions)
    print("FIN OK")


main()
