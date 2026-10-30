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

# --- v2 (retour utilisateur 2026-10-30 : « elle devrait pencher sur la droite et donner des coups circulaires propres de la tête
# aux pieds ») ----------------------------------------------------------------------------------------------------------------
# TENUES : lame qui PENCHE VERS LA DROITE (30-45° de la verticale), poignée en bas au centre-droit, poing gauche visible sous le
# droit (le pommeau part en bas à gauche).
# COUPS : de vrais ARCS DE CERCLE. La direction de la lame tourne autour d'un axe fixe (rotation uniforme d'angle θ, plan du
# cercle choisi par trois directions : départ, milieu VISIBLE — jamais pointée vers / à l'opposé de la caméra —, arrivée) ; le poing
# décrit un petit cercle devant la poitrine (centre C, rayon R), la lame en est le prolongement radial ; le temps suit une seule
# courbe douce (départ nul, pic, long freinage du suivi : pas d'à-coup entre frappe et suivi). Une clé par 1/60 s, interpolation
# continue (poignées AUTO) ; la torsion de l'avant-bras suit la clé précédente (aucun retournement). Rythme d'après Great Sword
# Mixamo (slash (3), slash, attack) : armé ~0,3 s, arc ~0,4 s, retour ~0,4 s.
import math  # noqa: E402
from mathutils import Vector, Matrix  # noqa: E402

TT2 = TT
COUDE = (0.7, -1, 0.1)
REPOS_2M = dict(nom="repos_2m", poing=E(0.16, -0.50, 0.52), lame=(0.56, 0.78, -0.28), roulis=TT2, coude=(1, -0.9, 0.2), clav=(8, 0),
                epaule=(-0.03, 0.0, -0.03), large=True)
SPRINT_2M = dict(nom="sprint_2m", poing=E(0.30, -0.80, 0.46), lame=(0.45, 0.50, -0.74), roulis=TT2, coude=(0.8, -1, 0.3), large=True)
# blocage : lame levée en travers, pointe en haut à DROITE (~55° de la verticale), poignée au centre
GARDE_2M = dict(nom="garde_2m", poing=E(0.02, -0.30, 0.48), lame=(0.78, 0.58, -0.22), roulis=TT2 + 4, poids_roulis=1.5,
                coude=(0.6, -1, 0.1), clav=(14, 4), epaule=(-0.05, 0.0, -0.05), large=True)
ENCAISSE_2M = dict(GARDE_2M, nom="encaisse_2m", poing=E(0.06, -0.36, 0.44), lame=(0.74, 0.64, -0.12))
PARADE_2M = dict(GARDE_2M, nom="parade_2m", poing=E(0.04, -0.28, 0.48), lame=(0.62, 0.74, -0.24))
BRISEE_2M = dict(nom="brisee_2m", poing=E(0.36, -0.90, 0.44), lame=(0.30, 0.25, -0.92), roulis=TT2, coude=(0.7, -1, 0.3), large=True)


def _n(v):
    return Vector(v).normalized()


def arc(s, m, e, C, R, clav0, clav1, ep0, ep1):
    """Cercle de la lame : axe fixe (départ × milieu), angle total jusqu'à l'arrivée projetée sur le plan. Renvoie pose(u, theta)."""
    s, m, e = _n(s), _n(m), _n(e)
    ax = s.cross(m).normalized()
    ep = (e - ax * e.dot(ax)).normalized()
    th = math.atan2(s.cross(ep).dot(ax), s.dot(ep))
    if th < 0.5:
        th += 2 * math.pi
    C = Vector(C)

    def pose(f, extra=0.0):
        a = th * f + extra
        d = Matrix.Rotation(a, 3, ax) @ s
        tg = ax.cross(d)
        poing = C + Vector((R * d.x, R * 0.9 * d.y, R * 0.35 * d.z))
        k = max(0.0, min(1.0, f))
        cl = tuple(clav0[i] + (clav1[i] - clav0[i]) * k for i in range(2))
        epa = tuple(ep0[i] + (ep1[i] - ep0[i]) * k for i in range(3))
        return dict(nom="arc", poing=tuple(poing), lame=tuple(d), mouvement=tuple(tg), coude=COUDE, clav=cl, epaule=epa,
                    large=True, interp="passe", suivre=True)
    return pose, th


def courbe(u):
    """Temps -> part de l'arc : départ à vitesse nulle, pic vers 35 %, long freinage (suivi) jusqu'à vitesse nulle."""
    return 0.5 - 0.5 * math.cos(math.pi * (u ** 0.75))


def clip_arc(depart, pose, t_arme, t_frappe, t_fin_arc, t_fin, retour=None, extra_arme=0.0):
    """REPOS (ou `depart`) -> armé (début de l'arc, tenu) -> arc dense (1/60 s) -> retour en garde. Marqueurs calculés."""
    cles = [cle(depart, 0.0)]
    a = pose(0.0, extra_arme)
    a.update(interp="amorti")
    cles.append(cle(a, t_arme))
    n = int(round((t_fin_arc - t_frappe) * 60))
    t_ff = None
    for i in range(n + 1):
        u = i / n
        f = courbe(u)
        if t_ff is None and f >= 0.80:
            t_ff = t_frappe + u * (t_fin_arc - t_frappe)
        k = pose(f, extra_arme * (1.0 - min(1.0, u * 4.0)))
        if i == n:
            k.update(interp="amorti")
        cles.append(cle(k, t_frappe + u * (t_fin_arc - t_frappe)))
    cles.append(cle(retour or REPOS_2M, t_fin))
    mq = {"arme": t_arme, "frappe": t_frappe, "fin_frappe": round(t_ff, 4), "suivi": t_fin_arc, "fin": t_fin}
    return cles, mq


# 1 : diagonale haut-droite (lame au-dessus de l'épaule droite) -> bas-gauche, lame finit près du sol
POSE_A, TH_A = arc((0.45, 0.85, 0.30), (-0.70, 0.30, -0.65), (-0.55, -0.80, -0.25), (0.10, -0.16, -0.42), 0.24,
                   (-6, 12), (30, -2), (0.02, 0.04, 0.02), (-0.12, 0.02, -0.12))
# 2 : retour en arc : de bas-gauche, la lame passe par le bas devant (en bas à droite) et remonte en haut à droite
POSE_B, TH_B = arc((-0.55, -0.80, -0.25), (0.50, -0.55, -0.67), (0.50, 0.80, -0.30), (0.12, -0.18, -0.44), 0.22,
                   (30, -2), (6, 10), (-0.12, 0.02, -0.12), (0.0, 0.03, -0.01))
# 3 : grand vertical tête -> pieds (lame au-dessus et derrière la tête, descend devant, un peu à droite du centre, jusqu'au sol)
POSE_C, TH_C = arc((0.10, 0.70, 0.70), (-0.32, 0.30, -0.90), (-0.10, -0.90, -0.42), (0.16, -0.14, -0.40), 0.26,
                   (-4, 16), (24, 0), (0.0, 0.06, 0.0), (-0.08, 0.0, -0.10))
POSE_P, TH_P = arc((0.10, 0.70, 0.70), (-0.32, 0.30, -0.90), (-0.10, -0.90, -0.42), (0.16, -0.12, -0.40), 0.28,
                   (-6, 18), (26, 0), (0.0, 0.07, 0.01), (-0.09, 0.0, -0.11))

C_A, M_A = clip_arc(REPOS_2M, POSE_A, 0.30, 0.38, 0.80, 1.20)
C_B, M_B = clip_arc(dict(POSE_A(1.0), torsion=125, poids_torsion=1.0), POSE_B, 0.20, 0.28, 0.70, 1.10)
C_C, M_C = clip_arc(REPOS_2M, POSE_C, 0.34, 0.44, 0.88, 1.30, extra_arme=-0.15)
P_CHARGE = POSE_P(0.0, -0.22)
P_CHARGE.update(interp="amorti")
C_L, M_L = clip_arc(P_CHARGE, POSE_P, 0.06, 0.08, 0.50, 1.10, extra_arme=-0.25)

CLIPS = {
    "repos_2m": [cle(REPOS_2M, 0.0), cle(REPOS_2M, 0.5)],
    "sprint_2m": [cle(SPRINT_2M, 0.0), cle(SPRINT_2M, 0.5)],
    "garde_2m": [cle(GARDE_2M, 0.0), cle(GARDE_2M, 0.5)],
    "encaisse_2m": [cle(GARDE_2M, 0.0), cle(ENCAISSE_2M, 0.06, interp="lin"), cle(PARADE_2M, 0.16), cle(GARDE_2M, 0.30)],
    "parade_2m": [cle(GARDE_2M, 0.0), cle(PARADE_2M, 0.05, interp="lin"), cle(ENCAISSE_2M, 0.13), cle(GARDE_2M, 0.24)],
    "brisee_2m": [cle(GARDE_2M, 0.0), cle(BRISEE_2M, 0.14, interp="lin"), cle(BRISEE_2M, 0.30), cle(REPOS_2M, 0.60)],
    "c2_a": C_A, "c2_b": C_B, "c2_c": C_C,
    "charge_2m": [cle(REPOS_2M, 0.0), cle(dict(POSE_C(0.0, -0.15), interp="amorti"), 0.35), cle(P_CHARGE, 0.70)],
    "lourd_2m": C_L,
}

MARQUEURS = {
    "c2_a": M_A, "c2_b": M_B, "c2_c": M_C, "lourd_2m": M_L,
    "charge_2m": {"arme": 0.35, "fin": 0.70},
    "encaisse_2m": {"fin": 0.30},
    "parade_2m": {"fin": 0.24},
}

# torsion de l'avant-bras CONTINUE dans les arcs : chaque clé « suivre » préfère la torsion de la clé précédente
_poser = NS["poser"]


def _poser_suivi(c, cote="r"):
    if c.get("suivre") and NS["PREC"][0] is not None:
        c = dict(c, torsion=NS["PREC"][0][0], poids_torsion=0.12)
    return _poser(c, cote)


NS["poser"] = _poser_suivi
# arcs à deux mains : la main droite (main du haut) tourne davantage que pour un coup à une main (la gauche porte une part de
# l'orientation) : butées « large » élargies pour ces clips seulement (torsion répartie du coude au poignet par TorsionAvantBras)
NS["LIM_TORSION_L"] = (-125, 125)
NS["LIM_INCL_L"] = (-45, 32)


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
    for nom, (x, n_) in ((k, (v, len(CLIPS[k]))) for k, v in MARQUEURS.items()):
        print("MARQUEURS", nom, x)
    if "mesurer" in ARGS:
        NS["mesurer_clips"](actions)
    if "godot" in ARGS:
        NS["MARQUEURS"] = MARQUEURS          # ecrire_godot lit les marqueurs de l'espace de noms
        NS["ecrire_godot"](os.path.join(NS["BASE"], "assets", "animations", "bras_2mains.tres"), actions)
    print("FIN OK")


main()
