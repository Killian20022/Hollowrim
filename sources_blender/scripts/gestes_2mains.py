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
# v4 (2026-11-11, retour utilisateur : « la claymore est trop penchée ; les coups de la claymore sont au ralenti ») : la tenue de
# repos est REDRESSÉE (lame (0,20 ; 0,88 ; -0,42) : ~6° de la verticale à l'écran au lieu de 37°, pointe vers le haut-avant ; même
# poing, donc même prise et même IK de la main gauche), la garde Mixamo tournée de 15° (roulis du cadrage : 17° au lieu de 31°), et
# les clips Mixamo des coups rejoués plus VITE (voir CLIPS_MX_2M : armé ~0,5 s, frappe ~0,2 s, retour ~0,7 s dans le jeu, contre
# 0,85 / 0,36 / 1,2 s ; coup léger 2,45 s -> 1,53 s ; combo 1-2-3 3,8 s -> 2,4 s ; épée à une main : 0,63 s / 0,98 s).
COUDE = (0.7, -1, 0.1)
REPOS_2M = dict(nom="repos_2m", poing=E(0.16, -0.50, 0.52), lame=(0.20, 0.88, -0.42), roulis=TT2, coude=(1, -0.9, 0.2), clav=(8, 0),
                epaule=(-0.03, 0.0, -0.03), large=True)
SPRINT_2M = dict(nom="sprint_2m", poing=E(0.16, -0.55, 0.50), lame=(0.45, 0.50, -0.74), roulis=TT2, coude=(0.8, -1, 0.3), large=True)
# blocage : lame levée en travers, pointe en haut à DROITE (~55° de la verticale), poignée au centre
GARDE_2M = dict(nom="garde_2m", poing=E(0.02, -0.30, 0.48), lame=(0.78, 0.58, -0.22), roulis=TT2 + 4, poids_roulis=1.5,
                coude=(0.6, -1, 0.1), clav=(14, 4), epaule=(-0.05, 0.0, -0.05), large=True)
ENCAISSE_2M = dict(GARDE_2M, nom="encaisse_2m", poing=E(0.06, -0.36, 0.44), lame=(0.74, 0.64, -0.12))
PARADE_2M = dict(GARDE_2M, nom="parade_2m", poing=E(0.04, -0.28, 0.48), lame=(0.62, 0.74, -0.24))
BRISEE_2M = dict(nom="brisee_2m", poing=E(0.36, -0.90, 0.44), lame=(0.30, 0.25, -0.92), roulis=TT2, coude=(0.7, -1, 0.3), large=True)


RETOUR_MI = dict(nom="retour_mi", poing=E(0.08, -0.44, 0.52), lame=(-0.15, 0.95, -0.25), roulis=TT2, coude=(1, -0.9, 0.2), clav=(14, 0),
                 epaule=(-0.05, 0.0, -0.05), large=True)


def _n(v):
    return Vector(v).normalized()


def arc(s, m, e, C, R, clav0, clav1, ep0, ep1, plan_z=0.45):
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
        # la lame DEMANDÉE est ramenée vers le plan de l'écran (z × 0,45) : le solveur, en butée de poignet, la laisse sinon pointer
        # vers l'avant (vue en bout, cachée par les mains) au milieu et à la fin des arcs (mesure --mesurer : « visee » 6-12°)
        dl = Vector((d.x, d.y, d.z * (plan_z if d.z < 0 else 0.45))).normalized()
        return dict(nom="arc", poing=tuple(poing), lame=tuple(dl), mouvement=tuple(tg), coude=COUDE, clav=cl, epaule=epa,
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
    if retour is None:   # retour en garde par une lame presque verticale (sinon l'interpolation la fait passer derrière la tête)
        cles.append(cle(RETOUR_MI, t_fin_arc + 0.5 * (t_fin - t_fin_arc)))
    cles.append(cle(retour or REPOS_2M, t_fin))
    mq = {"arme": t_arme, "frappe": t_frappe, "fin_frappe": round(t_ff, 4), "suivi": t_fin_arc, "fin": t_fin}
    return cles, mq


# 1 : diagonale haut-droite (lame au-dessus de l'épaule droite) -> bas-gauche, lame finit près du sol
POSE_A, TH_A = arc((0.45, 0.85, 0.30), (-0.70, 0.30, -0.65), (-0.45, -0.55, -0.70), (0.22, -0.20, -0.44), 0.12,
                   (-6, 12), (30, -2), (0.02, 0.04, 0.02), (-0.12, 0.02, -0.12))
# 2 : retour en arc : de bas-gauche, la lame remonte par la GAUCHE, passe en haut et finit en haut à droite (jamais cachée par
# les bras : une lame pointée vers le bas, devant, passe derrière les avant-bras)
POSE_B, TH_B = arc((-0.45, -0.55, -0.70), (-0.80, 0.25, -0.55), (0.45, 0.80, -0.38), (0.18, -0.20, -0.46), 0.12,
                   (30, -2), (6, 10), (-0.12, 0.02, -0.12), (0.0, 0.03, -0.01))
# 3 : grand vertical tête -> pieds (lame au-dessus et derrière la tête, descend devant, finit vers le sol un peu à gauche : à la
# verticale, elle serait cachée par les avant-bras)
POSE_C, TH_C = arc((0.10, 0.70, 0.70), (-0.32, 0.30, -0.90), (-0.60, -0.58, -0.55), (0.22, -0.14, -0.43), 0.14,
                   (-4, 16), (24, 0), (0.0, 0.06, 0.0), (-0.08, 0.0, -0.10), plan_z=0.15)
POSE_P, TH_P = arc((0.10, 0.70, 0.70), (-0.32, 0.30, -0.90), (-0.60, -0.58, -0.55), (0.22, -0.13, -0.43), 0.15,
                   (-6, 18), (26, 0), (0.0, 0.07, 0.01), (-0.09, 0.0, -0.11), plan_z=0.15)

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
    if c.get("tenue_exacte"):   # v6 : bord des clips Mixamo = la tenue repos_2m EXACTEMENT comme son clip la pose (solveur libre)
        NS["PREC"][0] = None
        return _poser(dict(REPOS_2M), cote)
    if c.get("suivre") and NS["PREC"][0] is not None:
        c = dict(c, torsion=NS["PREC"][0][0], poids_torsion=0.12)
    return _poser(c, cote)


NS["poser"] = _poser_suivi
# arcs à deux mains : la main droite (main du haut) tourne davantage que pour un coup à une main (la gauche porte une part de
# l'orientation) : butées « large » élargies pour ces clips seulement (torsion répartie du coude au poignet par TorsionAvantBras)
NS["LIM_TORSION_L"] = (-125, 125)
NS["LIM_INCL_L"] = (-45, 32)

# =====================================================================================================================
# v3 (2026-10-30, retour utilisateur : « on retrouve le poignet qui se casse et pas de mouvement d'épée fluide ») : les COUPS
# et le BLOCAGE sont des captures Mixamo « Great Sword Pack » RETARGETÉES (anim_bras_epee.creer_action_mixamo, même méthode
# que les coups à une main validés) au lieu des arcs écrits à la main : la courbe de vitesse est celle de la capture (continue),
# le poignet est résolu dans des butées SERRÉES (pas de poignet cassé), la torsion passe dans l'avant-bras avec continuité.
# Retouches vue FPS par clip : roulis / tangage du bras (cadrage), balayage autour de l'épaule, déplacement de l'épaule réduit
# (echelle_epaule), prise tournée autour de la lame (roulis_prise) pour que le tranchant mène, main inclinée (main).
# Données : sources_blender/mixamo/coups_2mains.json (extraire_2mains.py ; les .fbx restent hors du dépôt). Les tenues
# (repos, sprint, encaisse, parade, garde brisée) restent celles de la v2 ci-dessus ; les clips Mixamo partent de / reviennent à
# REPOS_2M (fondu en S).
CLIPS_MX_2M = {
    # réglage commun vue FPS : bras relevé de 30-35° (tangage) et épaule avancée/relevée (decalage), amplitude 0,5 (l'arc reste
    # dans le champ, la poignée au tiers bas : la main gauche l'atteint), déplacement de l'épaule de la capture à 50 %.
    # 1 : diagonale haut-droite -> bas-gauche (« great sword slash », images 12 -> 24 ; roulis -30° du bras : la verticale de
    # la capture devient une diagonale) ; milieu de lame (0,46 ; 0,69) -> (-0,44 ; -0,06), fil 63°
    "c2_a": dict(source="gs_slash", ref=0, temps=[(12, 0.0), (16, 0.22), (18, 0.27), (22, 0.41), (24, 0.52), (24, 0.74)],
                 fondu=(0.22, 0.56), plein=(0.22, 0.56), cadrage=(0, 35, -30), decalage=(0.0, 0.08, -0.12), amplitude=0.5, centre=20,
                 echelle_epaule=0.5),
    # 2 : retour horizontal gauche -> droite, légèrement montant (« great sword slash (2) », 2e coup, images 46 -> 57 ; prise tournée
    # de 90° : le tranchant mène) ; milieu de lame (-0,51 ; 0,04) -> (0,82 ; 0,42), fil 66°. (« slash (3) » essayé : sa main est
    # hors des butées serrées du poignet, fil < 20°.)
    "c2_b": dict(source="gs_slash_2", ref=0, temps=[(46, 0.0), (50.5, 0.15), (52, 0.20), (55.5, 0.34), (57, 0.44), (57, 0.68)],
                 fondu=(0.15, 0.48), plein=(0.15, 0.48), cadrage=(0, 30, 0), decalage=(0.0, 0.08, -0.12), amplitude=0.5, centre=53,
                 echelle_epaule=0.5, roulis_prise=90),
    # 3 : grand vertical tête -> pieds (« great sword slash (2) », 1er coup, images 18 -> 31, diagonale raide redressée par un
    # roulis de +25°) ; milieu de lame (0,15 ; 1,09) -> (-0,16 ; -0,65), fil 76°
    "c2_c": dict(source="gs_slash_2", ref=0, temps=[(18, 0.0), (22, 0.25), (23.5, 0.31), (29, 0.46), (31, 0.58), (31, 0.84)],
                 fondu=(0.25, 0.62), plein=(0.25, 0.62), cadrage=(0, 30, 25), decalage=(0.0, 0.08, -0.12), amplitude=0.5, centre=26,
                 echelle_epaule=0.5),
    # puissante : même grand vertical, armé tenu pendant la charge (charge et coup partagent cadrage et amplitude)
    "charge_2m": dict(source="gs_slash_2", ref=0, temps=[(10, 0.0), (21, 0.30), (22.5, 0.55)], fondu=(0.30, 0.55), plein=(0.30, 0.55),
                      cadrage=(0, 30, 25), decalage=(0.0, 0.08, -0.12), amplitude=0.5, centre=26, echelle_epaule=0.5),
    "lourd_2m": dict(source="gs_slash_2", ref=0, temps=[(22.5, 0.0), (23.5, 0.05), (29, 0.22), (31, 0.32), (31, 0.74)],
                     fondu=(0.0, 0.40), plein=(0.0, 0.40), cadrage=(0, 30, 25), decalage=(0.0, 0.08, -0.12), amplitude=0.5, centre=26,
                     echelle_epaule=0.5),
    # blocage tenu : lame en travers devant le visage (« great sword blocking (2) », pose tenue) ; milieu de lame (0,09 ; 0,65)
    "garde_2m": dict(source="gs_block_2", ref=0, temps=[(0, 0.0), (0, 0.5)], fondu=(0.0, 0.5), plein=(0.0, 0.5),
                     cadrage=(0, 12, 15), decalage=(0.1, 0.1, -0.1), amplitude=1.0, centre=0, echelle_epaule=0.5),
}
MARQUEURS_MX_2M = {
    "c2_a": {"arme": 0.22, "frappe": 0.27, "fin_frappe": 0.41, "suivi": 0.52, "fin": 0.74},
    "c2_b": {"arme": 0.15, "frappe": 0.20, "fin_frappe": 0.34, "suivi": 0.44, "fin": 0.68},
    "c2_c": {"arme": 0.25, "frappe": 0.31, "fin_frappe": 0.46, "suivi": 0.58, "fin": 0.84},
    "charge_2m": {"arme": 0.30, "fin": 0.55},
    "lourd_2m": {"arme": 0.04, "frappe": 0.05, "fin_frappe": 0.22, "suivi": 0.32, "fin": 0.74},
}
MARQUEURS.update(MARQUEURS_MX_2M)
# butées du poignet SERRÉES pour ces clips (pas de poignet cassé) ; torsion de l'avant-bras dans les limites du maillage
NS["LIM_MX"].update(torsion=(-85, 85), flexion=(-35, 35), inclinaison=(-22, 15))


# =====================================================================================================================
# v6 (2026-11-12, retour utilisateur : « mêmes coups propres qu'à l'épée, plus jamais de poignets cassés ») : MÊME MÉTHODE que
# les coups d'épée v6 validés (coup_a6 / coup_b6 / coup_t6 / coup_c6, gestes_une_main.surcouche_v6) : captures Great Sword
# retargetées par anim_bras_epee.creer_action_mixamo (directions du bras, main en orientation anatomique, poignet résolu DANS
# des butées, torsion de l'avant-bras qui absorbe la rotation, fondu en S depuis / vers la tenue validée), avec les trois
# surcouches v6 : POIGNET VERROUILLÉ autour de la tenue, ARC GUIDÉ pendant la frappe, CREUX de poids. AUCUNE pose écrite à la
# main : mêmes extraits et mêmes réglages de cadrage que la v4 (validés pour le cadrage), seule la TABLE DE TEMPS de lecture
# change (structure des clips d'épée v6 : armé = fondu de la tenue vers l'image d'armé de la capture, tenue jusqu'à la tension,
# la partie RAPIDE de la capture (vitesse de la lame mesurée image par image dans coups_2mains.json) tombe exactement dans la
# fenêtre de frappe, suivi, puis fondu en S jusqu'à la tenue exacte).
# Défaut de la v4 corrigé (mesuré : 150 px entre le bord des clips et la tenue, d'où un saut vers la garde à la fin de chaque
# coup) : le bord des clips reprenait la tenue SANS l'angle du coude (phi, trouvé par le solveur de repos_2m) -> phi gardé.
# Les anciens clips v4 se régénèrent avec --v4.
# Poignet verrouillé (flexion, inclinaison)° autour de la tenue repos_2m (k 37, f -18, r -44) : même logique que POIGNET_V6
# de l'épée (tenue f -11 / r -32, verrou f -28..8, r -29..-18) : flexion à ±18° de la tenue, inclinaison ramenée de 2 à 14°
# vers le neutre (la tenue est déjà en inclinaison cubitale) : pendant les coups, le poignet est PLUS droit qu'au repos.
POIGNET_2M = ((-28, 4), (-40, -14))
LIM_MX_2M = dict(torsion=(-85, 85), flexion=(-55, 55), inclinaison=(-45, 18))


def _v6(spec, temps, fondu, arc, poignet=POIGNET_2M, creux=0.03):
    s = dict(spec)
    s.update(temps=temps, fondu=fondu, plein=(fondu[0], min(fondu[1] + 0.08, temps[-1][1])), poignet=poignet, lim_mx=LIM_MX_2M)
    if arc is not None:
        s.update(arc=arc, creux=creux)
    return s


# coups légers : armé 0,10 s (fondu), tension 0,10 -> 0,14, frappe 0,14 -> 0,25, suivi -> 0,31, retour en S -> 0,47 (claymore du
# jeu : coup léger ~0,95 s, frappe ~0,17 s ; épée v6 : 0,13 / 0,16 / 0,26 / 0,33 / 0,54). Images de la capture (30 i/s) : armé =
# image où la lame est la plus lente avant le coup, frappe = la partie rapide.
MQ_LEGER = {"arme": 0.10, "frappe": 0.14, "fin_frappe": 0.25, "suivi": 0.31, "fin": 0.47}
ARC_LEGER = (0.14, 0.25, 0.85)
CLIPS_MX_2M_V6 = {
    # 1 : gs_slash, armé image 16 (lame en diagonale au-dessus de l'épaule droite, comme l'armé de la v4 ; les images 12-16, lame
    # qui monte vers la caméra, sont sautées comme l'armé derrière la tête de l'épée v6), rapide 16 -> 22 (pic 18-21)
    "c2_a": _v6(CLIPS_MX_2M["c2_a"], [(16, 0.0), (16, 0.09), (16.5, 0.14), (22, 0.25), (22.6, 0.31), (23, 0.40), (23, 0.47)], (0.10, 0.27), ARC_LEGER),
    # 2 : GAUCHE -> DROITE montant (corrigé le 2026-11-12, « le coup de gauche à droite casse encore le poignet ») : même extrait
    # (gs_slash_2 images 47 -> 60), poignet droit verrouillé à ±5° de la tenue, roulis_prise 90 supprimé : voir C2B_V6 plus bas.
    "c2_b": _v6(CLIPS_MX_2M["c2_b"], [(47, 0.0), (47, 0.08), (50, 0.14), (56, 0.25), (57.5, 0.31), (60, 0.40), (60, 0.47)], (0.10, 0.27), ARC_LEGER,
                poignet=((-23, -13), (-44, -34))),
    # 3 : gs_slash_2, 1er coup, armé image 18 (presque immobile à 17-18), rapide 20 -> 28 (pic 22-25) ; suivi arrêté à l'image
    # 28,8 (les images 29-31 emmènent les mains sous le cadre ; idem pour la puissante)
    "c2_c": _v6(CLIPS_MX_2M["c2_c"], [(18, 0.0), (18, 0.08), (21.5, 0.14), (27.5, 0.25), (28.3, 0.31), (28.8, 0.40), (28.8, 0.47)], (0.10, 0.27), ARC_LEGER),
    # puissante : même capture que le 3 ; charge = fondu de la tenue vers l'armé (image 21, tenue pendant la charge), coup =
    # image 22,5 -> 28 en frappe, suivi, retour en S (après le relâchement : ~0,9 s de jeu)
    "charge_2m": _v6(CLIPS_MX_2M["charge_2m"], [(10, 0.0), (19, 0.30), (21, 0.55)], (0.30, 0.55), None),
    "lourd_2m": _v6(CLIPS_MX_2M["lourd_2m"], [(21, 0.0), (22.5, 0.03), (28, 0.15), (28.8, 0.21), (29.3, 0.30), (29.3, 0.46)], (0.0, 0.24), (0.03, 0.15, 0.85)),
}
CLIPS_MX_2M_V6["charge_2m"]["plein"] = (0.30, 0.55)
# 1 : roulis du bras -30 -> -10° (la v4 tournait la capture de 30° pour une diagonale ; avec le poignet verrouillé, la lame finissait
# couchée à l'horizontale, pommeau à droite : main gauche à 11,5 cm de la fusée, mains sous le cadre ; à -10° : 8,7 cm, lame
# qui finit en bas à gauche comme le coup 1 de l'épée v6)
CLIPS_MX_2M_V6["c2_a"]["cadrage"] = (0, 35, -10)
# 2 (C2B_V6) : candidats mesurés (2026-11-12) parmi les balayages gauche -> droite des captures Great Sword (azimut de la lame
# +60° et plus ; sens du balayage vu de la caméra, vitesse, flexion / déviation des DEUX poignets de la capture image par image ;
# outils hors dépôt), puis retargetés et mesurés dans le jeu (mesures_coups_v5 --seq=coup2, deux poignets après l'IK) :
#   gs_slash_2 47-60 (2e coup)  : seul candidat dont l'ARMÉ est à gauche (lame pointée à gauche, au-dessus de l'épaule gauche) et
#                                 qui traverse l'écran ; la capture tourne le buste et casse son poignet (flexion -44 -> +77°) : on
#                                 ne la suit PAS au poignet (verrou ±5° autour de la tenue), la torsion de l'avant-bras (29 -> 57°)
#                                 et le bras portent la rotation. Jeu : poignet droit 16° / 11° de la tenue (v6 : 42° / 29°).
#   gs_slash_2 4-10 (1er coup)  : poignets de la capture à ±15°, mais part de face (pas d'armé à gauche) : avec un balayage du
#                                 buste de 60°, lame VERTICALE qui glisse de gauche à droite (« essuie-glace ») : rejeté sur film.
#   gs_spin 43-50               : mains sous le cadre (garde y -6,6) ; gs_kick_2 8-16, gs_slash_4 27-33 : lame qui monte ou passe
#                                 derrière la tête, balayage < 0,3 écran ; gs_slash_3 : droite -> gauche.
# roulis_prise 90 SUPPRIMÉ : il faisait tourner la prise dans la main, rotation que le poignet absorbait (mesuré : 42° de flexion).
CLIPS_MX_2M_V6["c2_b"].update(roulis_prise=0)
# TRANCHANT QUI MÈNE (2026-11-13, mesure : coup 2 = le PLAT mène, fil / mouvement 74° en moyenne ; coup 1 : 34° ; épée v6 : 12-24°) :
# pendant la frappe, l'avant-bras tourne sur son axe (pronation / supination, le poignet reste verrouillé) de l'angle qui met la
# normale du plat perpendiculaire à la vitesse de la lame (anim_bras_epee._thetas_tranchant, sur la lame réellement obtenue).
# Coup 1 : -78° max, fil 16° en moyenne. Coup 2 : la lame balaie presque dans l'axe de l'avant-bras, la torsion ne suffit pas
# (bornée à 85°, au-delà d'une rotation anatomique) : 74 -> 54°.
CLIPS_MX_2M_V6["c2_a"].update(tranchant=(0.14, 0.25, 0.10), theta_max=85.0)
CLIPS_MX_2M_V6["c2_b"].update(tranchant=(0.14, 0.25, 0.10), theta_max=85.0)
import json as _json
_essai = NS["ARGS"].get("essai", "")   # --essai=<fichier.json> : essais de réglage des clips v6 sans modifier ce fichier
for _n, _r in (_json.load(open(_essai, encoding="utf-8")) if _essai else {}).items():
    CLIPS_MX_2M_V6[_n].update({k: (tuple(v) if isinstance(v, list) else v) for k, v in _r.items()})
CLIPS_MX_2M_V6["lourd_2m"]["plein"] = (0.0, 0.32)
MARQUEURS_MX_2M_V6 = {
    "c2_a": dict(MQ_LEGER), "c2_b": dict(MQ_LEGER), "c2_c": dict(MQ_LEGER),
    "charge_2m": {"arme": 0.30, "fin": 0.55},
    "lourd_2m": {"arme": 0.02, "frappe": 0.03, "fin_frappe": 0.15, "suivi": 0.21, "fin": 0.46},
}
V4 = "v4" in NS["ARGS"]
if not V4:
    CLIPS_MX_2M.update(CLIPS_MX_2M_V6)
    MARQUEURS.update(MARQUEURS_MX_2M_V6)
# butées de la v3/v4 (les clips Mixamo sans « lim_mx », dont la garde garde_2m : inchangés)
LIM_MX_V4 = dict(NS["LIM_MX"])


def _preparer_mx_2m():
    """Données Mixamo deux bras + tenue de repos à deux mains comme bord des clips retargetés."""
    import json
    NS["_mx_donnees"]()
    NS["_MX"].update(json.load(open(os.path.join(NS["BASE"], "sources_blender", "mixamo", "coups_2mains.json"), encoding="utf-8")))
    NS["PREC"][0] = None
    NS["poser"](dict(REPOS_2M))
    k, f, r, phi = NS["PREC"][0][:4]
    NS["REPOS"] = dict(REPOS_2M, k=k, f=f, r=r)   # poignet fixé : exactement la tenue de repos aux bords des clips
    if not V4:   # v6 : bord des clips = la tenue exacte (k, f, r fixés sans phi, poser() reprenait phi = 0 et un autre point
        # de départ du poignet : bord des clips à 150 px de la tenue, d'où un saut vers la garde à la fin de chaque coup)
        NS["REPOS"]["tenue_exacte"] = True



def main():
    ARGS = NS["ARGS"]
    NS["poings"]()
    NS["poser_torche"]()
    noms = [c for c in ARGS.get("clips", "").split(",") if c] or list(CLIPS)
    noms = list(dict.fromkeys(noms + ([] if ARGS.get("clips") else list(CLIPS_MX_2M))))
    _preparer_mx_2m()
    actions = {}
    for nom in noms:
        if nom in CLIPS_MX_2M:
            NS["LIM_MX"].update(CLIPS_MX_2M[nom].get("lim_mx", LIM_MX_V4))
            actions[nom] = NS["creer_action_mixamo"](nom, CLIPS_MX_2M[nom])
            continue
        cles = CLIPS[nom]
        act = NS["creer_action"](nom, cles)
        actions[nom] = (act, cles[-1]["t"])
    print("POIGNET  (clé, allonge, torsion avant-bras° (+ supination), flexion°, inclinaison° (+ radiale), erreur lame°, coût)")
    for r in NS["RAPPORT"]:
        print("POIGNET ", r)
    for nom, x in MARQUEURS.items():
        print("MARQUEURS", nom, x)
    if "mesurer" in ARGS:
        NS["mesurer_clips"](actions)
    if "godot" in ARGS:
        NS["MARQUEURS"] = MARQUEURS          # ecrire_godot lit les marqueurs de l'espace de noms
        NS["ecrire_godot"](os.path.join(NS["BASE"], "assets", "animations", "bras_2mains.tres"), actions)
    print("FIN OK")


main()
