# Arme à DEUX MAINS (claymore) du viewmodel FPS — CLIPS DU BRAS DROIT à images clés, bibliothèque À PART des coups à une main.
#
#   blender.exe -b sources_blender/bras_fps.blend --python sources_blender/scripts/gestes_2mains.py -- --godot \
#       [--clips=c2_a,c2_b] [--mesurer]
#
# Même solveur, même repère caméra, même prise que les coups à une main (anim_bras_epee.py, lu tel quel SANS le modifier, comme
# gestes_finishers.py). La main GAUCHE n'est pas animée ici : dans le jeu, elle est posée par IK sur la poignée, sous la main
# droite (mains.gd, _poser_deux_mains) : les deux mains restent sur la poignée quel que soit le clip.
# Sortie : assets/animations/bras_2mains.tres (AnimationLibrary, préfixe « deux/ » dans le jeu, AnimateurBras.DEUX_MAINS).
# Le profil « deux_mains » (ProfilsAnimation, famille de toutes les armes à deux mains) remplace les tenues (repos, garde, sprint, encaisse, parade, garde brisée, contre)
# par leurs versions _2m (AnimateurBras.variante) et joue le combo c2_a → c2_b → c2_c et la puissante lourd_2m.
#
# Rythme et trajets : d'après les captures Mixamo « Great Sword Pack » (great sword slash (3), slash, attack, blocking ;
# extraites par extraire_2mains.py dans sources_blender/mixamo/coups_2mains.json, les deux bras) : armé long et posé (0,3 s
# environ), frappe qui traverse tout le cadre, grand suivi qui emporte le corps, retour lent (≈ 1,1 s par coup contre 0,5 s à
# une main). Les poses sont écrites en ESPACE ÉCRAN (la capture, buste qui tourne de 60°, ne se lit pas telle quelle depuis
# une caméra fixe) : la poignée reste dans le tiers bas-central de l'écran pour que la main gauche l'atteigne.
import os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
_src = open(os.path.join(ICI, "anim_bras_epee.py"), encoding="utf-8").read()
_src = _src[: _src.rstrip().rfind("main()")]          # le fichier finit par « main() » : on garde tout le reste
NS = {"__file__": os.path.join(ICI, "anim_bras_epee.py"), "__name__": "anim_bras_epee"}
exec(compile(_src, "anim_bras_epee.py", "exec"), NS)

import gestes_bras_epee as G  # noqa: E402

E = G.E
cle = G.cle
TRANCHE = G.TRANCHE
TT = G.TRANCHE_TENUE

# --- tenues ---------------------------------------------------------------------------------------------------------------
# garde de repos à deux mains : poings bas, un peu à droite du centre, lame qui monte en diagonale vers le haut gauche
# (la pointe vers le haut du cadre) ; la main gauche tient la poignée juste sous la droite (bas de l'écran)
REPOS_2M = dict(nom="repos_2m", poing=E(0.30, -0.60, 0.50), lame=(-0.32, 0.90, -0.28), roulis=TT, coude=(1, -0.8, 0.2), clav=(6, 0),
                epaule=(-0.02, 0.0, -0.02))
SPRINT_2M = dict(nom="sprint_2m", poing=E(0.50, -0.88, 0.44), lame=(-0.45, 0.55, -0.70), roulis=TT, coude=(0.7, -1, 0.3))
# blocage à deux mains : lame en travers devant le visage, pointe en haut à gauche, poignée à droite (les deux mains côte à
# côte sur la poignée, la gauche à droite de la droite), plat face à l'ennemi
GARDE_2M = dict(nom="garde_2m", poing=E(0.26, -0.30, 0.45), lame=(-0.84, 0.50, -0.18), roulis=TT + 4, poids_roulis=1.5,
                coude=(0.5, -1, 0.1), clav=(12, 4), epaule=(-0.04, 0.0, -0.04))
ENCAISSE_2M = dict(GARDE_2M, nom="encaisse_2m", poing=E(0.30, -0.37, 0.40), lame=(-0.80, 0.58, -0.10))
PARADE_2M = dict(GARDE_2M, nom="parade_2m", poing=E(0.30, -0.28, 0.45), lame=(-0.60, 0.76, -0.22))
BRISEE_2M = dict(nom="brisee_2m", poing=E(0.48, -0.95, 0.42), lame=(-0.40, 0.22, -0.89), roulis=TT, coude=(0.7, -1, 0.3))

# --- coup 1 : diagonale haut-droite -> bas-gauche (armé au-dessus de l'épaule droite, la lame traverse tout le cadre) -------
A2_ARME = dict(nom="A2_arme", poing=E(0.52, 0.10, 0.45), lame=(0.40, 0.78, 0.48), roulis=TRANCHE, coude=(1, -0.4, 0.3), clav=(-6, 12),
               epaule=(0.02, 0.04, 0.02), large=True)
A2_TENSION = dict(A2_ARME, nom="A2_tension", poing=E(0.58, 0.16, 0.44), lame=(0.46, 0.72, 0.52))
A2_ENTREE = dict(nom="A2_entree", poing=E(0.42, 0.0, 0.52), lame=(-0.10, 0.85, -0.50), mouvement=(-0.6, -0.8, 0), coude=(1, -0.6, 0.2),
                 clav=(8, 8), epaule=(-0.02, 0.02, -0.03), interp="passe", large=True)
A2_MILIEU = dict(nom="A2_milieu", poing=E(0.15, -0.25, 0.58), lame=(-0.80, 0.25, -0.55), mouvement=(-0.5, -0.85, 0), coude=(0.6, -1, 0.0),
                 clav=(20, 4), epaule=(-0.06, 0.0, -0.07), interp="passe", large=True)
A2_FIN = dict(nom="A2_fin", poing=E(-0.10, -0.52, 0.56), lame=(-0.70, -0.50, -0.45), mouvement=(-0.6, -0.7, 0.2), coude=(0.3, -1, -0.2),
              clav=(30, 0), epaule=(-0.11, 0.02, -0.11), large=True)
A2_SUIVI = dict(A2_FIN, nom="A2_suivi", poing=E(-0.20, -0.66, 0.54), lame=(-0.55, -0.72, -0.40), clav=(34, -3), epaule=(-0.13, 0.02, -0.12))

# --- coup 2 : horizontal gauche -> droite à plat (repart de la fin du 1, en bas à gauche) ----------------------------------
B2_ARME = dict(nom="B2_arme", poing=E(-0.24, -0.32, 0.52), lame=(-0.90, 0.30, -0.30), mouvement=(1, 0.1, 0), coude=(0.3, -1, -0.2),
               clav=(30, 2), epaule=(-0.12, 0.02, -0.11), large=True)
B2_TENSION = dict(B2_ARME, nom="B2_tension", poing=E(-0.30, -0.30, 0.51), lame=(-0.92, 0.25, -0.22))
B2_MILIEU = dict(nom="B2_milieu", poing=E(0.10, -0.28, 0.60), lame=(0.20, 0.12, -0.97), mouvement=(1, 0.05, 0), coude=(0.5, -1, -0.1),
                 clav=(18, 2), epaule=(-0.05, 0.0, -0.06), interp="passe", large=True)
B2_FIN = dict(nom="B2_fin", poing=E(0.48, -0.30, 0.57), lame=(0.88, 0.12, -0.45), mouvement=(0.8, 0.1, 0.4), coude=(1, -1, 0.2),
              clav=(6, 4), large=True)
B2_SUIVI = dict(B2_FIN, nom="B2_suivi", poing=E(0.58, -0.38, 0.54), lame=(0.90, -0.05, -0.30), mouvement=(0.5, 0, 0.6))

# --- coup 3 : vertical par-dessus la tête (le plus lourd du combo, tassement de la caméra) ---------------------------------
C2_ARME = dict(nom="C2_arme", poing=E(0.28, 0.36, 0.42), lame=(-0.10, 0.80, 0.55), roulis=TRANCHE, coude=(1, -0.5, 0.0), clav=(-4, 18),
               epaule=(0.0, 0.07, 0.01), large=True)
C2_TENSION = dict(C2_ARME, nom="C2_tension", poing=E(0.28, 0.44, 0.40), lame=(-0.08, 0.70, 0.70))
C2_ENTREE = dict(nom="C2_entree", poing=E(0.22, 0.24, 0.52), lame=(-0.10, 0.60, -0.80), mouvement=(0, -1, -0.3), coude=(0.8, -1, 0.0),
                 clav=(8, 16), epaule=(-0.03, 0.04, -0.04), interp="passe", large=True)
C2_MILIEU = dict(nom="C2_milieu", poing=E(0.12, -0.12, 0.60), lame=(-0.08, -0.05, -1.0), mouvement=(0, -1, 0), coude=(0.6, -1, 0.0),
                 clav=(18, 8), epaule=(-0.05, 0.02, -0.08), interp="passe", large=True)
C2_FIN = dict(nom="C2_fin", poing=E(0.06, -0.55, 0.58), lame=(-0.05, -0.70, -0.70), mouvement=(0, -0.8, 0.4), coude=(0.4, -1, 0.0),
              clav=(24, 0), epaule=(-0.08, 0.0, -0.10), large=True)
C2_SUIVI = dict(C2_FIN, nom="C2_suivi", poing=E(0.04, -0.68, 0.55), lame=(-0.03, -0.85, -0.50))

# --- puissante (maintien) : armé tenu au-dessus de la tête, la lame tombe de tout son poids -------------------------------
P2_CHARGE = dict(C2_TENSION, nom="P2_charge", poing=E(0.30, 0.50, 0.40), lame=(-0.06, 0.62, 0.78))
P2_ARME = dict(P2_CHARGE, nom="P2_arme", poing=E(0.31, 0.54, 0.39), lame=(-0.05, 0.55, 0.83))

CLIPS = {
    "repos_2m": [cle(REPOS_2M, 0.0), cle(REPOS_2M, 0.5)],
    "sprint_2m": [cle(SPRINT_2M, 0.0), cle(SPRINT_2M, 0.5)],
    "garde_2m": [cle(GARDE_2M, 0.0), cle(GARDE_2M, 0.5)],
    "encaisse_2m": [cle(GARDE_2M, 0.0), cle(ENCAISSE_2M, 0.06, interp="lin"), cle(PARADE_2M, 0.16), cle(GARDE_2M, 0.30)],
    "parade_2m": [cle(GARDE_2M, 0.0), cle(PARADE_2M, 0.05, interp="lin"), cle(ENCAISSE_2M, 0.13), cle(GARDE_2M, 0.24)],
    "brisee_2m": [cle(GARDE_2M, 0.0), cle(BRISEE_2M, 0.14, interp="lin"), cle(BRISEE_2M, 0.30), cle(REPOS_2M, 0.60)],
    "c2_a": [cle(REPOS_2M, 0.0), cle(A2_ARME, 0.30), cle(A2_TENSION, 0.38), cle(A2_ENTREE, 0.43), cle(A2_MILIEU, 0.48),
             cle(A2_FIN, 0.55), cle(A2_SUIVI, 0.72), cle(REPOS_2M, 1.10)],
    "c2_b": [cle(A2_SUIVI, 0.0), cle(B2_ARME, 0.22), cle(B2_TENSION, 0.30), cle(B2_MILIEU, 0.38), cle(B2_FIN, 0.46),
             cle(B2_SUIVI, 0.62), cle(REPOS_2M, 1.00)],
    "c2_c": [cle(REPOS_2M, 0.0), cle(C2_ARME, 0.34), cle(C2_TENSION, 0.44), cle(C2_ENTREE, 0.49), cle(C2_MILIEU, 0.53),
             cle(C2_FIN, 0.60), cle(C2_SUIVI, 0.78), cle(REPOS_2M, 1.25)],
    "charge_2m": [cle(REPOS_2M, 0.0), cle(C2_ARME, 0.35), cle(P2_CHARGE, 0.70)],
    "lourd_2m": [cle(P2_CHARGE, 0.0), cle(P2_ARME, 0.10), cle(C2_ENTREE, 0.16), cle(C2_MILIEU, 0.20), cle(C2_FIN, 0.27),
                 cle(C2_SUIVI, 0.50), cle(REPOS_2M, 1.15)],
}

MARQUEURS = {
    "c2_a": {"arme": 0.30, "frappe": 0.38, "fin_frappe": 0.55, "suivi": 0.72, "fin": 1.10},
    "c2_b": {"arme": 0.22, "frappe": 0.30, "fin_frappe": 0.46, "suivi": 0.62, "fin": 1.00},
    "c2_c": {"arme": 0.34, "frappe": 0.44, "fin_frappe": 0.60, "suivi": 0.78, "fin": 1.25},
    "charge_2m": {"arme": 0.35, "fin": 0.70},
    "lourd_2m": {"arme": 0.10, "frappe": 0.10, "fin_frappe": 0.27, "suivi": 0.50, "fin": 1.15},
    "encaisse_2m": {"fin": 0.30},
    "parade_2m": {"fin": 0.24},
}


def main():
    ARGS = NS["ARGS"]
    NS["poings"]()
    NS["poser_torche"]()
    noms = [c for c in ARGS.get("clips", "").split(",") if c] or list(CLIPS)
    actions = {}
    for nom in noms:
        cles = CLIPS[nom]
        act = NS["creer_action"](nom, cles)
        actions[nom] = (act, cles[-1]["t"])
    print("POIGNET  (clé, allonge, torsion avant-bras° (+ supination), flexion°, inclinaison° (+ radiale), erreur lame°, coût)")
    for r in NS["RAPPORT"]:
        print("POIGNET ", r)
    if "mesurer" in ARGS:
        NS["mesurer_clips"](actions)
    if "godot" in ARGS:
        NS["MARQUEURS"] = MARQUEURS          # ecrire_godot lit les marqueurs de l'espace de noms
        NS["ecrire_godot"](os.path.join(NS["BASE"], "assets", "animations", "bras_2mains.tres"), actions)
    print("FIN OK")


main()
