# Finishers (achèvements) du viewmodel FPS — CLIPS DU BRAS DROIT À IMAGES CLÉS, bibliothèque À PART des coups normaux.
#
#   blender.exe -b sources_blender/bras_fps.blend --python sources_blender/scripts/gestes_finishers.py -- --godot \
#       [--clips=fin_plantee,fin_decapitation] [--rendu=<dossier>] [--pas=0.0333]
#
# Même solveur, même repère caméra, même prise que les coups (anim_bras_epee.py, lu tel quel SANS le modifier : ses fonctions sont
# chargées dans un espace de noms, son main() n'est pas lancé) ; la pose de repos est celle validée (gestes_bras_epee.REPOS :
# tenue « tranche »), chaque clip part et revient sur elle. Sortie : assets/animations/bras_finishers.tres (AnimationLibrary,
# préfixe « fin/ » dans le jeu, AnimateurBras.FINISHERS). Ne touche ni bras_epee.tres ni gestes_bras_epee.py.
# Marqueurs (s, vitesse 1) : arme, frappe (début du geste qui porte), contact (la lame entre / tranche / le pommeau frappe),
# plante (début de la tenue lame plantée), retrait (début du retrait), sortie (la lame est dehors), mort (la cible meurt),
# suivi, fin ; « contact2 » pour un second contact (pommeau puis estoc). Lus par scripts/combat/finishers.gd.
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
REPOS = G.REPOS
TRANCHE = G.TRANCHE

# --- 1. ÉPÉE PLANTÉE (de face) ---------------------------------------------------------------------------------------
# le poing recule à la hanche droite, lame pointée vers le centre ; estoc violent (épaule qui avance) : la lame entre dans le
# torse et y RESTE (poussée, petite torsion, le corps s'affaisse sur elle) ; retrait sec vers l'arrière ; secousse de la lame.
PL_ARME = dict(nom="PL_arme", poing=E(0.66, -0.66, 0.36), lame=(-0.30, 0.16, -0.94), roulis=40, coude=(0.8, -1, 0.5), clav=(-8, 0))
PL_TENSION = dict(PL_ARME, nom="PL_tension", poing=E(0.70, -0.70, 0.33))
PL_ENTREE = dict(nom="PL_entree", poing=E(0.48, -0.52, 0.52), lame=(-0.34, 0.12, -0.93), roulis=40, coude=(0.7, -1, 0.3), clav=(10, 2), epaule=(-0.03, 0.0, -0.06), interp="passe")
PL_IMPACT = dict(nom="PL_impact", poing=E(0.36, -0.46, 0.64), lame=(-0.36, 0.10, -0.93), roulis=40, coude=(0.6, -1, 0.1), clav=(20, 2), epaule=(-0.05, 0.0, -0.12))
PL_POUSSE = dict(PL_IMPACT, nom="PL_pousse", poing=E(0.34, -0.48, 0.67), roulis=55, epaule=(-0.05, 0.0, -0.14))
PL_TIENT = dict(PL_IMPACT, nom="PL_tient", poing=E(0.35, -0.52, 0.66), lame=(-0.36, 0.03, -0.93), roulis=50, epaule=(-0.05, -0.01, -0.13))
PL_TIRE = dict(PL_TIENT, nom="PL_tire", poing=E(0.37, -0.52, 0.64), epaule=(-0.05, -0.01, -0.12))
PL_RETRAIT = dict(nom="PL_retrait", poing=E(0.58, -0.60, 0.33), lame=(-0.28, 0.16, -0.94), roulis=40, coude=(0.8, -1, 0.5), clav=(-6, 0))
PL_SECOUE = dict(nom="PL_secoue", poing=E(0.62, -0.72, 0.42), lame=(0.25, -0.35, -0.90), mouvement=(0.4, -1, 0), coude=(0.8, -1, 0.4), clav=(-2, 0))

# --- 2. DÉCAPITATION LATÉRALE --------------------------------------------------------------------------------------------
# grand armé à droite à hauteur du cou, balayage horizontal droite → gauche qui traverse le cou, suivi large à gauche.
D_ARME = dict(nom="D_arme", poing=E(0.74, -0.08, 0.56), lame=(0.0, 0.10, -1.0), roulis=TRANCHE, coude=(1, -0.5, 0.4), clav=(-10, 8), epaule=(0.02, 0.01, 0.01), torsion=-80)
D_TENSION = dict(D_ARME, nom="D_tension", poing=E(0.78, -0.06, 0.55), lame=(0.06, 0.10, -1.0))
D_ENTREE = dict(nom="D_entree", poing=E(0.55, -0.06, 0.55), lame=(-0.36, 0.06, -0.93), mouvement=(-1, -0.05, 0), coude=(1, -0.7, 0.3), clav=(6, 6), interp="passe", torsion=-80)
D_MILIEU = dict(nom="D_milieu", poing=E(0.16, -0.12, 0.60), lame=(-0.80, 0.08, -0.60), mouvement=(-1, -0.05, 0), coude=(0.6, -1, 0.0), clav=(20, 3), epaule=(-0.05, 0.0, -0.06), interp="passe", torsion=-80)
D_FIN = dict(nom="D_fin", poing=E(-0.22, -0.45, 0.58), lame=(-0.92, -0.12, -0.30), mouvement=(-0.8, -0.2, 0.4), coude=(0.3, -1, -0.2), clav=(30, 0), epaule=(-0.12, 0.02, -0.11), torsion=-80)
D_SUIVI = dict(D_FIN, nom="D_suivi", poing=E(-0.30, -0.62, 0.55), lame=(-0.82, -0.32, -0.25))

# --- 3. COUP PLONGÉ (ennemi à terre) -------------------------------------------------------------------------------------
# la caméra regarde le corps au sol (tangage fort) : l'épée monte, pointe en avant-bas, puis plonge dans la poitrine (même
# geste qu'un estoc dans le repère de la caméra baissée), reste plantée, le héros l'arrache vers le haut.
PG_ARME = dict(nom="PG_arme", poing=E(0.50, 0.10, 0.40), lame=(-0.25, -0.10, -0.96), roulis=45, coude=(0.9, -0.6, 0.4), clav=(-4, 14), epaule=(0.0, 0.05, 0.02))
PG_TENSION = dict(PG_ARME, nom="PG_tension", poing=E(0.52, 0.20, 0.37), lame=(-0.25, -0.05, -0.97))
PG_ENTREE = dict(nom="PG_entree", poing=E(0.40, -0.18, 0.52), lame=(-0.28, -0.30, -0.91), roulis=45, coude=(0.7, -1, 0.2), clav=(12, 6), epaule=(-0.03, 0.02, -0.06), interp="passe")
PG_IMPACT = dict(nom="PG_impact", poing=E(0.30, -0.38, 0.64), lame=(-0.28, -0.38, -0.88), roulis=45, coude=(0.6, -1, 0.1), clav=(20, 2), epaule=(-0.05, -0.02, -0.13))
PG_POUSSE = dict(PG_IMPACT, nom="PG_pousse", poing=E(0.31, -0.46, 0.67), roulis=55, epaule=(-0.05, -0.03, -0.15))
PG_TIENT = dict(PG_POUSSE, nom="PG_tient", poing=E(0.32, -0.47, 0.66))
PG_RETRAIT = dict(nom="PG_retrait", poing=E(0.50, 0.0, 0.36), lame=(-0.25, -0.15, -0.96), roulis=45, coude=(0.9, -0.6, 0.4), clav=(-2, 10), epaule=(0.0, 0.03, 0.01))
PG_SECOUE = dict(nom="PG_secoue", poing=E(0.62, -0.55, 0.42), lame=(0.25, -0.35, -0.90), mouvement=(0.4, -1, 0), coude=(0.8, -1, 0.4), clav=(-2, 0))

# --- 4. POMMEAU PUIS ESTOC ------------------------------------------------------------------------------------------------
# coup de pommeau au visage (poing qui frappe devant, lame dressée), la cible recule sonnée ; la lame redescend, estoc dans
# la poitrine, tenue courte, retrait.
PM_ARME = dict(nom="PM_arme", poing=E(0.58, -0.58, 0.30), lame=(0.20, 0.80, 0.55), roulis=TRANCHE, coude=(0.8, -1, 0.6), clav=(-8, 0))
PM_TENSION = dict(PM_ARME, nom="PM_tension", poing=E(0.62, -0.62, 0.28))
PM_FRAPPE = dict(nom="PM_frappe", poing=E(0.12, -0.18, 0.60), lame=(-0.30, 0.85, 0.40), roulis=TRANCHE, coude=(0.5, -1, 0.0), clav=(22, 4), epaule=(-0.06, 0.0, -0.11))
PM_REBOND = dict(PM_FRAPPE, nom="PM_rebond", poing=E(0.18, -0.22, 0.55), epaule=(-0.05, 0.0, -0.08))
PM_ARME2 = dict(PL_ARME, nom="PM_arme2", poing=E(0.64, -0.64, 0.36))
PM_IMPACT = dict(PL_IMPACT, nom="PM_impact", poing=E(0.36, -0.44, 0.64))
PM_TIENT = dict(PL_POUSSE, nom="PM_tient", poing=E(0.35, -0.47, 0.66))

CLIPS = {
    "fin_plantee": [cle(REPOS, 0.0), cle(PL_ARME, 0.16), cle(PL_TENSION, 0.22), cle(PL_ENTREE, 0.27), cle(PL_IMPACT, 0.30, interp="lin"),
                    cle(PL_POUSSE, 0.45), cle(PL_TIENT, 0.70), cle(PL_TIRE, 0.86), cle(PL_RETRAIT, 0.95), cle(PL_SECOUE, 1.08),
                    cle(REPOS, 1.45)],
    "fin_decapitation": [cle(REPOS, 0.0), cle(D_ARME, 0.24), cle(D_TENSION, 0.30), cle(D_ENTREE, 0.335), cle(D_MILIEU, 0.37),
                         cle(D_FIN, 0.42), cle(D_SUIVI, 0.56), cle(REPOS, 1.00)],
    "fin_plonge": [cle(REPOS, 0.0), cle(PG_ARME, 0.20), cle(PG_TENSION, 0.27), cle(PG_ENTREE, 0.31), cle(PG_IMPACT, 0.34, interp="lin"),
                   cle(PG_POUSSE, 0.50), cle(PG_TIENT, 0.78), cle(PG_RETRAIT, 0.92), cle(PG_SECOUE, 1.06), cle(REPOS, 1.40)],
    "fin_pommeau": [cle(REPOS, 0.0), cle(PM_ARME, 0.13), cle(PM_TENSION, 0.17), cle(PM_FRAPPE, 0.23, interp="lin"), cle(PM_REBOND, 0.32),
                    cle(PM_ARME2, 0.48), cle(PL_TENSION, 0.53), cle(PL_ENTREE, 0.575), cle(PM_IMPACT, 0.60, interp="lin"),
                    cle(PM_TIENT, 0.74), cle(PL_TIRE, 0.86), cle(PL_RETRAIT, 0.95), cle(PL_SECOUE, 1.08), cle(REPOS, 1.42)],
}

MARQUEURS = {
    "fin_plantee": {"arme": 0.16, "frappe": 0.24, "contact": 0.30, "plante": 0.30, "retrait": 0.86, "sortie": 0.95, "mort": 1.02,
                    "suivi": 1.08, "fin": 1.45},
    "fin_decapitation": {"arme": 0.24, "frappe": 0.31, "contact": 0.36, "fin_frappe": 0.42, "mort": 0.36, "suivi": 0.56, "fin": 1.00},
    "fin_plonge": {"arme": 0.20, "frappe": 0.28, "contact": 0.34, "plante": 0.34, "retrait": 0.80, "sortie": 0.90, "mort": 0.98,
                   "suivi": 1.06, "fin": 1.40},
    "fin_pommeau": {"arme": 0.13, "frappe": 0.18, "contact": 0.23, "contact2": 0.60, "plante": 0.60, "retrait": 0.86, "sortie": 0.95,
                    "mort": 1.02, "suivi": 1.08, "fin": 1.42},
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
    if "rendu" in ARGS:
        import bpy, math
        dossier = ARGS["rendu"]
        os.makedirs(dossier, exist_ok=True)
        epee, torche = NS["preparer_rendu"]()
        pas = float(ARGS.get("pas", "0.0333"))
        A = NS["A"]
        for nom in noms:
            act, longueur = actions[nom]
            A.animation_data.action = act
            n = int(math.floor(longueur / pas + 1e-6)) + 1
            for i in range(n):
                t = i * pas
                f = t * NS["FPS"]
                NS["scene"].frame_set(int(math.floor(f)), subframe=f - math.floor(f))
                NS["poser_torche"]()
                NS["placer_accessoires"](epee, torche)
                g, p, plat = NS["mesures_cam"]()
                print("MESURE %s t=%.3f garde=%s pointe=%s plat=%d" % (nom, t, g, p, plat))
                NS["scene"].render.filepath = os.path.join(dossier, "%s_%03d.png" % (nom, i))
                bpy.ops.render.render(write_still=True)
    if "godot" in ARGS:
        NS["MARQUEURS"] = MARQUEURS          # ecrire_godot lit les marqueurs de l'espace de noms
        NS["ecrire_godot"](os.path.join(NS["BASE"], "assets", "animations", "bras_finishers.tres"), actions)
    print("FIN OK")


main()
