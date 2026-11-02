"""Armures LÉGÈRES portées (agent X, branche rpg/armures_legeres) : cuir, fourrure, os de draugr — 4 pièces chacune
(identifiants de data/objets/armures.json). Convention : conception_rpg/CONVENTION_ARMURES_3D.md ; outils : ../armures_lib.py.

  blender -b --python gen_legeres.py -- [famille|tout] [apercu=<dossier>]
      famille : cuir | fourrure | os | tout (défaut)
Sorties : assets/modeles/armures/porte/<id>.glb (skinné sur le squelette du héros) et assets/modeles/armures/sol/<id>.glb (posé).

Zones recouvertes (masquées sur le héros par scripts/rpg/armure_visible.gd, mêmes seuils) :
  tete  : casque, crête, camail et cheveux du héros (la barbe et le visage restent) ;
  torse : cotte (triangles qui ont un sommet à |x| < 0,405), mante, plastron, épaulières, col, tabard, pèlerine, ceinture, surcot (les manches au-delà restent) ;
  mains : tout ce qui est au-delà de |x| = 0,58 (gants, revers fourrés, brassards, bout des manches) ;
  pieds : tout ce qui est sous y = 0,40 (bottes, revers fourrés, bas du pantalon).
"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import importlib
import armures_lib as L
importlib.reload(L)
from armures_lib import B, G

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FAMILLE = next((a for a in ARGS if "=" not in a), "tout")
APERCU = next((a.split("=", 1)[1] for a in ARGS if a.startswith("apercu=")), "")

# ---------------------------------------------------------------------------------------------------------- palettes
CUIR = L.hexa("#120d0a", "#1c1510", "#271d16", "#33271d", "#403125", "#4e3c2d", "#5e4937", "#705843", "#836a53")
CUIR_SOMBRE = L.hexa("#0d0907", "#17100b", "#21170f", "#2d2015", "#3a2a1c", "#493525")
FER = L.hexa("#1b1b1d", "#2c2c30", "#424349", "#5c5e66", "#7c7f88", "#a3a6ae")
FOURRURE = L.hexa("#1d1a17", "#2b2621", "#3a332c", "#4a4138", "#5b5046", "#6e6256", "#837567", "#9a8b7b", "#b0a291")
FOURRURE_BRUNE = L.hexa("#1f1710", "#2e2218", "#3f3022", "#523f2d", "#665039", "#7b6247")
OS = L.hexa("#2e271d", "#463c2e", "#62553f", "#7e7054", "#998a6b", "#b2a383", "#c8ba9b", "#dbcfb3")
LAINE = L.hexa("#1a1714", "#25211c", "#312b24", "#3e362d")


def bruit_cuir(P, g=0):
    return (L.fbm(P, 6.0, g) - 0.5) * 0.18 + (L.bruit(P, 28.0, g + 7) - 0.5) * 0.10 + (L.bruit(P, 75.0, g + 9) - 0.5) * 0.06


def coutures(P, bd, v, d0=0.010, d1=0.017):
    """Ourlet sombre au bord libre, puis rang de points de couture clairs (pointillés irréguliers)."""
    v = np.where(bd < 0.008, v - 0.20, v)
    v = np.where((bd >= 0.008) & (bd < d0 + 0.004), v - 0.06, v)
    pts = (bd >= d0 + 0.004) & (bd < d1 + 0.006)
    v = np.where(pts, v + 0.10, v)
    return v


def mat_cuir(P, N, pa, bd, base=0.52, pal=CUIR, g=0):
    v = base + bruit_cuir(P, g)
    v = v + np.clip(N[:, 1], -1, 1) * 0.06          # dessus plus clair (usure, lumière)
    v = coutures(P, bd, v)
    # éraflures : fines lignes claires obliques
    e = np.abs(np.sin((P[:, 0] * 0.7 + P[:, 1] * 1.3 + P[:, 2] * 0.4) * 70.0 + L.fbm(P, 5.0, g + 3) * 12.0))
    v = np.where((e < 0.10) & (L.bruit(P, 10.0, g + 4) > 0.80), v + 0.06, v)
    rgb = L.rampe(pal, np.clip(v, 0, 0.999))
    a = np.clip(0.18 + v * 0.45, 0.05, 0.6)
    return np.concatenate([rgb, a[:, None]], 1)


def mat_fer(P, N, v0=0.55):
    v = v0 + (L.fbm(P, 30.0, 51) - 0.5) * 0.35 + np.clip(N[:, 1], -1, 1) * 0.1
    rgb = L.rampe(FER, np.clip(v, 0, 0.999))
    a = np.clip(0.55 + v * 0.4, 0, 1)
    return np.concatenate([rgb, a[:, None]], 1)


def mat_fourrure(P, N, pa, bd, pal=FOURRURE, base=0.55, g=0, sens=None):
    """Fourrure : mèches fines très étirées dans le sens du poil (vers le bas par défaut), faible contraste d'ensemble (pas de
    taches), pointes plus claires, racines sombres au bord libre."""
    if sens is None:
        sens = np.array([0.0, 1.0, 0.0])
    s = sens / np.linalg.norm(sens)
    Q = P - np.outer(P @ s, s) * 0.93          # presque constant le long du poil : des stries
    m = L.bruit(Q, 55.0, g) - 0.5
    fines = L.bruit(Q, 140.0, g + 5) - 0.5
    lent = L.fbm(P, 4.0, g + 9) - 0.5
    v = base + m * 0.18 + fines * 0.10 + lent * 0.12 + np.clip(N[:, 1], -1, 1) * 0.07
    v = np.where(bd < 0.010, v - 0.10, v)
    rgb = L.rampe(pal, np.clip(v, 0, 0.999))
    a = np.clip(0.04 + v * 0.12, 0, 0.25)
    return np.concatenate([rgb, a[:, None]], 1)


def mat_os(P, N, pa, bd, base=0.6, g=0):
    """Os patiné : ivoire jauni lisse (variations lentes et douces), pores fins, rares fissures fines, creux crasseux au bord."""
    v = base + (L.fbm(P, 5.0, g) - 0.5) * 0.12 + (L.bruit(P, 45.0, g + 3) - 0.5) * 0.06 + np.clip(N[:, 1], -1, 1) * 0.07
    f = np.abs(L.fbm(P, 9.0, g + 8) - 0.5)
    v = np.where((f < 0.008) & (L.fbm(P, 3.0, g + 11) > 0.62), v - 0.12, v)
    v = np.where(bd < 0.006, v - 0.16, np.where(bd < 0.014, v + 0.05, v))
    rgb = L.rampe(OS, np.clip(v, 0, 0.999))
    # patine brune très légère dans les zones basses (pas de taches franches)
    t = np.clip((L.fbm(P, 3.0, g + 12) - 0.5) * 1.2, 0, 1)[:, None]
    rgb = rgb * (1 - 0.18 * t) + np.array([0.30, 0.24, 0.16]) * 0.18 * t
    a = np.clip(0.25 + v * 0.45, 0, 0.75)
    return np.concatenate([rgb, a[:, None]], 1)


# ---------------------------------------------------------------------------------------------------------- squelette
ARM = L.scene_base()


def os_g(nom):
    return G(ARM.matrix_world @ ARM.data.bones[nom].head_local)


TETE = os_g("Head") + Vector((0, 0.09, 0.0))    # centre du crâne (repère Godot)
COU = os_g("neck_01")


def tete_rigide(o):
    L.ecrire_poids(o, [{"Head": 1.0} for _ in o.data.vertices])


def finir(o, matiere, nom_mat, ident, tris_max, sol, taille=128, poids_src=None, lisse_poids=0):
    """UV, cuisson, matériau, contrôle du budget, poids, export porté + sol."""
    L.lisser_normales(o)
    nb = L.nb_tris(o)
    print("PIECE %s : %d triangles (max %d)" % (ident, nb, tris_max))
    assert nb <= tris_max, ident
    L.uv_auto(o)
    img = L.cuire(o, matiere, taille, ident)
    o.data.materials.clear()
    o.data.materials.append(L.materiau(nom_mat, img))
    if APERCU:
        PIECES.append(o)
    L.exporter(o, ARM, ident, sol)


PIECES = []


# ---------------------------------------------------------------------------------------------------------- coques
def coque_tete(nom, lignes, n, jeu, garder, cibles, partie=0):
    """Coque autour du crâne : rangées d'élévation `lignes` (degrés, de haut en bas ; 90 = pôle), n colonnes (theta 0 = devant).
    Rayon = surface la plus extérieure des `cibles` (BVH) le long du rayon + jeu(theta, phi). garder(theta, phi) des faces."""
    bm = bmesh.new()
    part = L.couche_partie(bm)
    grille = []
    for phi in lignes:
        rang = []
        for j in range(n if phi < 89.9 else 1):
            th = 2 * math.pi * j / n
            ph = math.radians(phi)
            d = Vector((math.sin(th) * math.cos(ph), math.sin(ph), math.cos(th) * math.cos(ph)))
            dep = TETE + d * 0.45
            hit = cibles.ray_cast(B(dep), B(-d), 0.45)
            r = (B(TETE) - hit[0]).length if hit[0] is not None else 0.11
            r += jeu(th, ph)
            rang.append(bm.verts.new(B(TETE + d * r)))
        grille.append(rang)
    for k in range(len(grille) - 1):
        a, b = grille[k], grille[k + 1]
        phc = math.radians((lignes[k] + lignes[k + 1]) / 2)
        for j in range(n):
            j2 = (j + 1) % n
            thc = 2 * math.pi * (j + 0.5) / n
            if not garder(thc, phc):
                continue
            if len(a) == 1:
                f = bm.faces.new((a[0], b[j2], b[j]))
            else:
                f = bm.faces.new((a[j], a[j2], b[j2], b[j]))
            f[part] = partie
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bm.normal_update()
    for f in bm.faces:   # normales vers l'extérieur
        if (f.calc_center_median() - B(TETE)).dot(f.normal) < 0:
            f.normal_flip()
    return bm


def epaissir_bords(bm, ep, vers=None, partie=None):
    """Rabat l'épaisseur sous chaque bord libre (vers l'intérieur : -normale du sommet) : la tranche se lit."""
    part = L.couche_partie(bm)
    bm.normal_update()
    bords = [e for e in bm.edges if e.is_boundary]
    nouv = {}
    for e in bords:
        for v in e.verts:
            if v not in nouv:
                d = -v.normal if vers is None else (vers - v.co).normalized()
                nouv[v] = bm.verts.new(v.co + d * ep)
    for e in bords:
        a, b = e.verts
        f0 = e.link_faces[0]
        p = f0[part]
        # ordre cohérent avec la face voisine
        boucle = [l for l in f0.loops if l.edge == e][0]
        if boucle.vert == a:
            f = bm.faces.new((b, a, nouv[a], nouv[b]))
        else:
            f = bm.faces.new((a, b, nouv[b], nouv[a]))
        f[part] = p if partie is None else partie
    bm.normal_update()


def bande(bm, centres, rayon_in, epaisseur, n, partie, arc=None, bombe=0.0):
    """Bande épaisse (sangle, ceinture, plaque) : centres = [(c_haut, axe, ref), (c_bas, axe, ref)], rayon_in[k](theta) = surface
    sous la bande. Quatre rangées : dessous haut, dessus haut, dessus bas, dessous bas (tranches visibles)."""
    (c0, a0, r0), (c1, a1, r1) = centres
    cm = (Vector(c0) + Vector(c1)) / 2
    f0, f1 = rayon_in
    rs = [lambda t: f0(t) + 0.001,
          lambda t: f0(t) + epaisseur,
          lambda t: (f0(t) + f1(t)) / 2 + epaisseur + bombe,
          lambda t: f1(t) + epaisseur,
          lambda t: f1(t) + 0.001]
    cs = [(c0, a0, r0), (c0, a0, r0), (cm, a0, r0), (c1, a1, r1), (c1, a1, r1)]
    avant = set(bm.faces)
    lignes = L.anneau(bm, cs, rs, n, partie, ferme=arc is None, arc=arc)
    orienter(bm, [f for f in bm.faces if f not in avant], Vector(c0), Vector(c1))
    return lignes


def orienter(bm, faces, c0, c1):
    """Normales vers l'extérieur d'une bande d'axe c0 -> c1 : à l'opposé du point de l'axe (segment resserré de 30 % vers son
    milieu, pour que les tranches haute et basse regardent vers le haut / le bas)."""
    cm = (c0 + c1) / 2
    a = c0.lerp(cm, 0.3)
    b = c1.lerp(cm, 0.3)
    ab = b - a
    bm.normal_update()
    for f in faces:
        p = G(f.calc_center_median())
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        q = a + ab * t
        if G(f.normal).dot(p - q) < 0:
            f.normal_flip()
    bm.normal_update()


def en_objet(bm, nom):
    bm.normal_update()
    o = L.bm_vers_objet(bm, nom)
    bm.free()
    return o


def poids_de(o, src, filtre=None, lissage=1):
    pw = L.poids_proches(o, bpy.data.objects[src], 4, filtre)
    pw = L.lisser_poids(o, pw, lissage, 0.4) if lissage else pw
    L.ecrire_poids(o, L.normaliser(pw))


def fusion(objs, nom):
    return L.joindre(objs, nom)


# ---------------------------------------------------------------------------------------------------------- pièces communes
BVH_TRONC = L.bvh_de(["tunique", "SuperHero_Male"], filtre=lambda p: abs(p.x) < 0.24 or p.y < 1.36)


def torse_base(nom, tris, jeu=0.012):
    """Coque du torse dérivée de la cotte Quaternius (poids hérités) : |x| < 0,43, hanches à l'encolure."""
    o = L.copie("tunique", nom, lambda c, n: abs(c.x) < 0.44)
    bvh = L.bvh_de(["tunique", "SuperHero_Male"])
    j0 = (lambda p: jeu) if not callable(jeu) else jeu
    # bout de manche évasé (la manche de la cotte qui continue dessous ne ressort pas quand le bras plie)
    L.ajuster(o, bvh, lambda p: j0(p) + max(0.0, abs(p.x) - 0.34) * 0.35, lissage=3)
    L.decimer(o, tris)
    # jupe : fentes devant et derrière (chaque pan suit sa cuisse) et poids du PANTALON dessous (le pan bouge comme la jambe qu'il
    # couvre : pas de traversée quand la cuisse se lève), fondus vers ceux de la cotte au-dessus des hanches
    bm = bmesh.new()
    bm.from_mesh(o.data)
    def _fente(c):
        return (abs(c.x) < 0.028 and c.y < 0.86) or (c.y > 1.49 and c.z > 0.03 and abs(c.x) < 0.10 - (1.58 - c.y) * 0.5)
    fentes = [f for f in bm.faces if _fente(G(f.calc_center_median()))]    # fentes de la jupe, encolure en V (la barbe)
    bmesh.ops.delete(bm, geom=fentes, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(o.data)
    bm.free()
    # poids repris de la cotte d'origine (sommets les plus proches) : la décimation moyennait ceux des épaules
    pw_t = L.poids_proches(o, bpy.data.objects["tunique"], 4)
    pw_p = L.poids_proches(o, bpy.data.objects["pantalon"], 3, lambda p: p.y > 0.5)
    res = []
    for v, a, b in zip(o.data.vertices, pw_t, pw_p):
        y = G(v.co).y
        x = G(v.co).x
        t = min(1.0, max(0.0, (0.96 - y) / 0.12))
        # côté de la fente : les poids de la jambe de CE côté seulement
        if t > 0:
            b = {k: w for k, w in b.items() if not (k.endswith("_r") if x > 0 else k.endswith("_l"))} or b
        d = {k: w * (1 - t) for k, w in a.items()}
        for k, w in b.items():
            d[k] = d.get(k, 0.0) + w * t
        res.append(d)
    L.ecrire_poids(o, L.normaliser(res))
    return o


def ceinture(nom, y0=0.935, y1=0.995, ep=0.012, n=18):
    """Ceinture autour du tronc (poids de la cotte)."""
    bm = bmesh.new()
    axe, ref = (0, 1, 0), (0, 0, 1)
    c0, c1 = Vector((0, y1, 0.0)), Vector((0, y0, 0.0))
    shell = L.bvh_de(["tunique"], filtre=lambda p: abs(p.x) < 0.3)
    f0 = L.rayon_sur(shell, c0, axe, ref, 0.012)
    f1 = L.rayon_sur(shell, c1, axe, ref, 0.012)
    bande(bm, [(c0, axe, ref), (c1, axe, ref)], [f0, f1], ep, n, 1)
    o = en_objet(bm, nom)
    poids_de(o, "tunique", lambda p: abs(p.x) < 0.3)
    return o


def axe_bras(cote):
    s = 1 if cote == "l" else -1
    a = os_g("upperarm_" + cote)
    b = os_g("lowerarm_" + cote)
    return a, (b - a).normalized(), s


def epauliere(nom, cote, couches, partie=2, n=8):
    """Épaulière en lames qui se recouvrent sur le haut du bras (de l'épaule vers le coude) ; couches = [(x0, x1, ep, arc_deg)]."""
    bm = bmesh.new()
    a, axe, s = axe_bras(cote)
    ref = Vector((0, 1, 0))
    cible = L.bvh_de(["tunique", "SuperHero_Male"], filtre=lambda p: abs(p.x) > 0.12)
    for i, (x0, x1, ep, arcd) in enumerate(couches):
        c0 = Vector((s * x0, a.y + 0.012 * i, a.z))
        c1 = Vector((s * x1, a.y - 0.01, a.z))
        ar = math.radians(arcd)
        f0 = L.rayon_sur(cible, c0, axe, ref, 0.014 + 0.012 * i)
        f1 = L.rayon_sur(cible, c1, axe, ref, 0.020 + 0.012 * i)
        lignes = bande(bm, [(c0, axe, ref), (c1, axe, ref)], [f0, f1], ep, n, partie, arc=(-ar, ar), bombe=0.004)
    o = en_objet(bm, nom)
    poids_de(o, "tunique", lambda p: abs(p.x) > 0.12)
    return o


def col_montant(nom, h0=1.495, h1=1.565, ep=0.010, n=14, jeu=0.016, ouvert=1.05):
    bm = bmesh.new()
    axe, ref = (0, 1, 0), (0, 0, 1)
    peau = L.bvh_de(noms_heros=["peau", "Hair_Beard"], filtre=lambda p: abs(p.x) < 0.16 and 1.40 < p.y < 1.62)
    c0, c1 = Vector((0, h1, COU.z - 0.01)), Vector((0, h0, COU.z - 0.01))
    f0 = L.rayon_sur(peau, c0, axe, ref, jeu)
    f1 = L.rayon_sur(peau, c1, axe, ref, lambda t: jeu + 0.012)
    # col ouvert devant (la barbe tombe dessus quand la tête se penche) : arc du côté gauche par la nuque au côté droit
    bande(bm, [(c0, axe, ref), (c1, axe, ref)], [f0, f1], ep, n, 3, arc=(ouvert, 2 * math.pi - ouvert))
    o = en_objet(bm, nom)
    poids_de(o, "tunique", lambda p: abs(p.x) < 0.25 and p.y > 1.35)
    return o


def manchette(nom, src_poids, x0, x1, jeu0, jeu1, ep, n=12, partie=1, cote="l", evase=0.0):
    """Revers / manchette autour de l'avant-bras, de |x| = x0 à x1."""
    bm = bmesh.new()
    s = 1 if cote == "l" else -1
    a = os_g("lowerarm_" + cote)
    h = os_g("hand_" + cote)
    axe = (h - a).normalized()
    ref = Vector((0, 1, 0))
    cible = L.bvh_de(["tunique", "gants"], noms_heros=["brassards", "tunique"], filtre=lambda p: abs(p.x) > 0.45)

    def c_at(x):
        t = (x - abs(a.x)) / (abs(h.x) - abs(a.x))
        return a.lerp(h, t)
    c0, c1 = c_at(x0), c_at(x1)
    f0 = L.rayon_sur(cible, c0, axe, ref, jeu0 + evase)
    f1 = L.rayon_sur(cible, c1, axe, ref, jeu1)
    bande(bm, [(c0, axe, ref), (c1, axe, ref)], [f0, f1], ep, n, partie)
    o = en_objet(bm, nom)
    poids_de(o, src_poids, lambda p: abs(p.x) > 0.45 and (p.x > 0) == (s > 0))
    return o


def gants_base(nom, tris, jeu=0.004):
    o = L.copie("gants", nom)
    bvh = L.bvh_de(["gants"])
    L.ajuster(o, bvh, lambda p: jeu, lissage=1, force=0.3)
    L.decimer(o, tris)
    return o


def bottes_base(nom, tris, jeu=0.005):
    o = L.copie("bottes", nom)
    bvh = L.bvh_de(["bottes"])
    L.ajuster(o, bvh, lambda p: jeu, lissage=1, force=0.3)
    L.decimer(o, tris)
    return o


def revers_botte(nom, cote, y0, y1, jeu0, jeu1, ep, n=12, partie=1, evase=0.0):
    bm = bmesh.new()
    s = 1 if cote == "l" else -1
    k = os_g("calf_" + cote)
    f = os_g("foot_" + cote)
    axe = (k - f).normalized()
    ref = Vector((0, 0, 1))
    cible = L.bvh_de(["bottes", "pantalon"], noms_heros=["pantalon", "bottes"], filtre=lambda p: (p.x > 0) == (s > 0) and p.y < 0.6)

    def c_at(y):
        t = (y - f.y) / (k.y - f.y)
        return f.lerp(k, t)
    c0, c1 = c_at(y1), c_at(y0)
    f1 = L.rayon_sur(cible, c0, axe, ref, jeu1 + evase)
    f0 = L.rayon_sur(cible, c1, axe, ref, jeu0)
    bande(bm, [(c0, axe, ref), (c1, axe, ref)], [f1, f0], ep, n, partie)
    o = en_objet(bm, nom)
    poids_de(o, "bottes", lambda p: (p.x > 0) == (s > 0))
    return o


# ---------------------------------------------------------------------------------------------------------- poses au sol
def sol_torse(s):
    # couché sur le dos, devant vers le haut
    M = Matrix.Rotation(-math.pi / 2, 4, 'X')
    L.poser_au_sol(s, [(lambda p: True, M)])


def sol_tete(s):
    L.poser_au_sol(s, [(lambda p: True, Matrix.Translation((0, 0, 0)))])


def sol_paire_mains(s):
    # chaque gant ramené près du centre, posé à plat (paume en bas), légèrement tourné
    def M(cote):
        x = 0.78 * (1 if cote > 0 else -1)
        return (Matrix.Translation((0.09 * cote, 0, 0)) @ Matrix.Rotation(math.radians(-90 * cote), 4, 'Y') @
                Matrix.Translation((-x, -1.40, 0.04)))
    L.poser_au_sol(s, [(lambda p: p.x > 0, M(1)), (lambda p: p.x <= 0, M(-1))])


def sol_paire_pieds(s):
    L.poser_au_sol(s, [(lambda p: p.x > 0, Matrix.Translation((-0.03, 0, 0))), (lambda p: p.x <= 0, Matrix.Translation((0.03, 0, 0.05)))])


# ============================================================================================================ CUIR
def cuir():
    # --- armure_cuir : justaucorps de cuir bouilli, épaulières en lames, ceinture, col montant ; laçage devant
    base = torse_base("armure_cuir", 480)
    bel = ceinture("ceint", n=14)
    ep_l = epauliere("ep_l", "l", [(0.15, 0.33, 0.008, 105), (0.21, 0.40, 0.008, 95)], n=6)
    ep_r = epauliere("ep_r", "r", [(0.15, 0.33, 0.008, 105), (0.21, 0.40, 0.008, 95)], n=6)
    col = col_montant("col", n=12)
    o = fusion([base, bel, ep_l, ep_r, col], "armure_cuir")

    def mat(P, N, pa, bd):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        out = mat_cuir(P, N, pa, bd, 0.50)
        v = np.zeros(len(P))
        # panneaux de cuir bouilli sur le ventre (bandes horizontales cousues) et le dos
        tronc = (pa == 0) & (np.abs(x) < 0.19) & (y > 1.0) & (y < 1.30) & (z > 0.06)
        for yb in (1.06, 1.13, 1.20, 1.27):
            l = tronc & (np.abs(y - yb) < 0.011)
            out[l, :3] *= 0.62
            p2 = tronc & (y - yb > 0.011) & (y - yb < 0.024)
            out[p2, :3] *= 1.12
        # coutures : côtés (sous les bras) et milieu du dos
        cou = (pa == 0) & (((np.abs(np.abs(x) - 0.17) < 0.008) & (np.abs(z) < 0.06)) | ((np.abs(x) < 0.008) & (z < -0.05) & (y > 0.86)))
        out[cou, :3] *= 0.6
        # laçage devant (x ~ 0, de la poitrine au col) : œillets et lacets croisés
        lac = (pa == 0) & (z > 0.05) & (y > 1.30) & (y < 1.50)
        fente = lac & (np.abs(x) < 0.006)
        out[fente, :3] = L.rampe(CUIR_SOMBRE, np.full(fente.sum(), 0.05))
        croix = lac & (np.abs(np.abs(x) - (np.mod(y, 0.04) - 0.02) * 0.9) < 0.004) & (np.abs(x) < 0.02)
        out[croix, :3] = L.rampe(CUIR, np.full(croix.sum(), 0.62))
        # ceinture : cuir sombre, boucle de fer devant, rivets
        c = pa == 1
        out[c] = mat_cuir(P[c], N[c], pa[c], bd[c], 0.30, CUIR_SOMBRE, 5)
        bou = c & (z > 0.05) & (np.abs(x) < 0.035)
        out[bou] = mat_fer(P[bou], N[bou], 0.6)
        anneau = bou & (np.abs(x) < 0.022) & (np.abs(y - 0.965) < 0.018)
        out[anneau, :3] = L.rampe(CUIR_SOMBRE, np.full(anneau.sum(), 0.1))
        riv = c & ~bou & (np.mod(np.arctan2(x, z) * 6.0, 1.0) < 0.12) & (np.abs(y - 0.965) < 0.008)
        out[riv] = mat_fer(P[riv], N[riv], 0.75)
        # épaulières : cuir plus clair et ciré, rivets aux coins
        e = pa == 2
        out[e] = mat_cuir(P[e], N[e], pa[e], bd[e], 0.60, CUIR, 9)
        r2 = e & (bd > 0.012) & (bd < 0.02) & (L.bruit(P, 45.0, 21) > 0.8)
        out[r2] = mat_fer(P[r2], N[r2], 0.7)
        # col montant
        cl = pa == 3
        out[cl] = mat_cuir(P[cl], N[cl], pa[cl], bd[cl], 0.40, CUIR, 13)
        # crasse en bas de la jupe
        bas = (pa == 0) & (y < 0.80)
        out[bas, :3] *= (0.75 + 0.25 * np.clip((y[bas] - 0.66) / 0.14, 0, 1))[:, None]
        return out
    finir(o, mat, "cuir", "armure_cuir", 900, sol_torse)

    # --- capuche_cuir : capuche ajustée au crâne, ouverture du visage, pèlerine courte sur les épaules
    cibles = L.bvh_de(["SuperHero_Male"], noms_heros=["peau", "Hair_Beard", "accessoires_0"],
                      filtre=lambda p: p.y > 1.38 and abs(p.x) < 0.30 and not (p.y > 1.60 and p.z > 0.06))
    lignes = [90, 72, 55, 40, 26, 12, 0, -14, -28, -42, -55, -66]

    def jeu(th, ph):
        dos = max(0.0, -math.cos(th))
        haut = max(0.0, math.sin(ph))
        return 0.015 + 0.012 * dos * haut + (0.022 * (0.4 + 0.6 * dos) if ph < -0.5 else 0.0)

    def garder(th, ph):
        t = abs(math.atan2(math.sin(th), math.cos(th)))
        if ph < math.radians(-30):
            return t > math.radians(50)
        if ph < math.radians(30):
            return t > math.radians(52 - 8 * max(0.0, -ph))
        return True
    bm = coque_tete("capuche_cuir", lignes, 20, jeu, garder, cibles)
    # pointe molle qui tombe vers l'arrière
    for v in bm.verts:
        p = G(v.co) - TETE
        if p.y > 0.06 and p.z < 0.0:
            v.co = B(TETE + p + Vector((0, -0.006, -0.012)) * (p.y - 0.06) / 0.05 * max(0.0, -p.z) / 0.1)
    epaissir_bords(bm, 0.008)
    o = en_objet(bm, "capuche_cuir")
    # bas (cou, épaules) : poids de la PEAU du cou dessous (la nuque et la pèlerine courte bougent comme le cou qu'elles couvrent),
    # de la cotte sur les épaules ; le crâne entier suit la tête
    pw_p = L.poids_proches(o, bpy.data.objects["peau"], 4, lambda p: p.y > 1.40 and abs(p.x) < 0.2)
    pw_t = L.poids_proches(o, bpy.data.objects["tunique"], 4, lambda p: p.y > 1.30 and abs(p.x) < 0.3)
    pw = []
    for v, a, b in zip(o.data.vertices, pw_p, pw_t):
        r = math.hypot(G(v.co).x, G(v.co).z - COU.z)
        u = min(1.0, max(0.0, (r - 0.09) / 0.06))      # loin du cou : la cotte (épaules)
        d = {k: x * (1 - u) for k, x in a.items()}
        for k, x in b.items():
            d[k] = d.get(k, 0.0) + x * u
        pw.append(d)
    res = []
    for v, d in zip(o.data.vertices, pw):
        y = G(v.co).y
        t = min(1.0, max(0.0, (y - (COU.y + 0.03)) / 0.06))
        dd = {k: x * (1 - t) for k, x in d.items()}
        dd["Head"] = dd.get("Head", 0.0) + t
        res.append(dd)
    res = L.lisser_poids(o, res, 3, 0.5)
    L.ecrire_poids(o, L.normaliser(res))

    def mat_cap(P, N, pa, bd):
        out = mat_cuir(P, N, pa, bd, 0.48, CUIR, 17)
        # couture du milieu (crâne, du front à la nuque)
        y, x = P[:, 1], P[:, 0]
        m = (np.abs(x) < 0.004) & (y > 1.72)
        out[m, :3] = L.rampe(CUIR, np.full(m.sum(), 0.15))
        m2 = (np.abs(np.abs(x) - 0.009) < 0.003) & (y > 1.72) & (L.bruit(P, 260.0, 5) > 0.5)
        out[m2, :3] = L.rampe(CUIR, np.full(m2.sum(), 0.7))
        return out
    finir(o, mat_cap, "cuir", "capuche_cuir", 600, sol_tete)

    # --- gants_cuir : gants de travail, jointures renforcées, manchette lacée
    g = gants_base("gants_cuir", 560)
    m_l = manchette("m_l", "brassards", 0.552, 0.665, 0.010, 0.006, 0.006, 12, 1, "l", 0.012)
    m_r = manchette("m_r", "brassards", 0.552, 0.665, 0.010, 0.006, 0.006, 12, 1, "r", 0.012)
    o = fusion([g, m_l, m_r], "gants_cuir")

    def mat_g(P, N, pa, bd):
        out = mat_cuir(P, N, pa, bd, 0.46, CUIR, 23)
        x = np.abs(P[:, 0])
        # jointures : pièce de cuir plus sombre sur le dos de la main (z>0 : dessus en T-pose = +y ; on prend N.y)
        j = (pa == 0) & (x > 0.79) & (x < 0.84) & (N[:, 1] > 0.3)
        out[j, :3] *= 0.7
        c = pa == 1
        out[c] = mat_cuir(P[c], N[c], pa[c], bd[c], 0.38, CUIR, 29)
        lac = c & (np.abs(np.mod(x * 60.0, 1.0) - 0.5) < 0.12) & (N[:, 1] > 0.5)
        out[lac, :3] = L.rampe(CUIR, np.full(lac.sum(), 0.7))
        return out
    finir(o, mat_g, "cuir", "gants_cuir", 900, sol_paire_mains)

    # --- bottes_cuir : bottes hautes, revers, deux sangles à boucle
    b = bottes_base("bottes_cuir", 480)
    parts = [b]
    for cote in ("l", "r"):
        parts.append(revers_botte("rv_" + cote, cote, 0.355, 0.43, 0.008, 0.010, 0.007, 12, 1, evase=0.008))
        parts.append(revers_botte("s1_" + cote, cote, 0.20, 0.235, 0.004, 0.004, 0.006, 10, 2))
    o = fusion(parts, "bottes_cuir")

    def mat_b(P, N, pa, bd):
        out = mat_cuir(P, N, pa, bd, 0.44, CUIR, 33)
        y = P[:, 1]
        sem = (pa == 0) & (y < 0.03)
        out[sem, :3] = L.rampe(CUIR_SOMBRE, np.full(sem.sum(), 0.15))
        boue = (pa == 0) & (y < 0.12)
        out[boue, :3] *= (0.7 + 0.3 * y[boue, None] / 0.12)
        s = pa == 2
        out[s] = mat_cuir(P[s], N[s], pa[s], bd[s], 0.25, CUIR_SOMBRE, 37)
        bou = s & (P[:, 2] > 0.05) & (np.abs(P[:, 0]) > 0.13)
        out[bou] = mat_fer(P[bou], N[bou], 0.6)
        r = pa == 1
        out[r] = mat_cuir(P[r], N[r], pa[r], bd[r], 0.55, CUIR, 39)
        return out
    finir(o, mat_b, "cuir", "bottes_cuir", 900, sol_paire_pieds)


# ============================================================================================================ FOURRURE
def mantelet(nom, y_cou=1.56, y_bas=1.30, n=20, rangs=5, jeu=0.035, partie=4, franges=True):
    """Mantelet de fourrure sur les épaules : anneaux du cou (étroit) jusqu'au bas (large), posés sur la cotte, bord inférieur
    en mèches (sommets alternés plus bas)."""
    bm = bmesh.new()
    part = L.couche_partie(bm)
    cible = L.bvh_de(["tunique", "SuperHero_Male"], noms_heros=["peau"], filtre=lambda p: p.y > 1.15 and abs(p.x) < 0.45)
    c = Vector((0, 1.62, COU.z - 0.01))
    grille = []
    for k in range(rangs):
        t = k / (rangs - 1)
        rang = []
        for j in range(n):
            th = 2 * math.pi * j / n
            # direction : du cou, descend en s'ouvrant (cône) ; les épaules (côtés) plus loin
            ang = math.radians(25 + 52 * t)
            d = Vector((math.sin(th) * math.sin(ang), -math.cos(ang), math.cos(th) * math.sin(ang))).normalized()
            hit = cible.ray_cast(B(c + d * 0.6), B(-d), 0.6)
            r = (hit[0] - B(c)).length if hit[0] is not None else 0.2
            r += jeu * (0.5 + 0.5 * t)
            if franges and k == rangs - 1:
                r += 0.02 * (j % 2)
            p = c + d * r
            if franges and k == rangs - 1 and j % 2:
                p.y -= 0.035
            rang.append(bm.verts.new(B(p)))
        grille.append(rang)
    for k in range(rangs - 1):
        for j in range(n):
            j2 = (j + 1) % n
            f = bm.faces.new((grille[k][j], grille[k][j2], grille[k + 1][j2], grille[k + 1][j]))
            f[part] = partie
    bm.normal_update()
    for f in bm.faces:
        if (f.calc_center_median() - B(c)).dot(f.normal) < 0:
            f.normal_flip()
    epaissir_bords(bm, 0.012)
    o = en_objet(bm, nom)
    poids_de(o, "tunique", lambda p: p.y > 1.2 and abs(p.x) < 0.45, 2)
    return o


def mantelet_coque(base, nom, partie=4, y_bas=1.27, decal=0.026):
    """Mantelet de fourrure : copie des faces hautes de la coque du torse (épaules, haut de poitrine et du dos), poussée de `decal`
    vers l'extérieur, bord bas déchiqueté (mèches de longueurs inégales). Poids de la coque (mêmes sommets)."""
    me = base.data.copy()
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    for vg in base.vertex_groups:
        if o.vertex_groups.get(vg.name) is None:
            o.vertex_groups.new(name=vg.name)
    bm = bmesh.new()
    bm.from_mesh(me)
    suppr = [f for f in bm.faces if G(f.calc_center_median()).y < y_bas or abs(G(f.calc_center_median()).x) > 0.31]
    bmesh.ops.delete(bm, geom=suppr, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.normal_update()
    part = L.couche_partie(bm)
    for f in bm.faces:
        f[part] = partie
    for v in bm.verts:
        v.co = v.co + v.normal * decal * (0.6 + 0.4 * min(1.0, max(0.0, (1.55 - G(v.co).y) / 0.2)))
    bords = [v for v in bm.verts if v.is_boundary and G(v.co).y < y_bas + 0.06 and abs(G(v.co).x) < 0.24]
    for i, v in enumerate(bords):
        k = L._h3(i, 7, 3, 1)
        v.co = v.co + B(0, -0.035 * k - 0.01, 0)
    epaissir_bords(bm, 0.012)
    bm.to_mesh(me)
    bm.free()
    # poids : ceux du sommet de la coque le plus proche (les sommets des tranches n'en ont pas)
    L.ecrire_poids(o, L.normaliser(L.poids_proches(o, base, 3)))
    return o


def fourrure():
    # --- armure_fourrure : peau de loup lacée sur cuir, mantelet de fourrure, ceinture, bas fourré
    base = torse_base("armure_fourrure", 350, jeu=lambda p: 0.014)
    man = mantelet_coque(base, "man")
    bel = ceinture("ceint", 0.94, 1.0, 0.012, 16)
    o = fusion([base, man, bel], "armure_fourrure")

    def mat(P, N, pa, bd):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        # cuir clair de chasseur (plus clair que l'armure de cuir), mantelet de loup sur les épaules
        out = mat_cuir(P, N, pa, bd, 0.62, CUIR, 41)
        m = pa == 4
        out[m] = mat_fourrure(P[m], N[m], pa[m], bd[m], FOURRURE, 0.62, 47)
        c = pa == 1
        out[c] = mat_cuir(P[c], N[c], pa[c], bd[c], 0.3, CUIR_SOMBRE, 49)
        bou = c & (z > 0.05) & (np.abs(x) < 0.03)
        out[bou] = mat_os(P[bou], N[bou], pa[bou], bd[bou], 0.7, 3)    # boucle d'os (fourrure : pas de fer)
        return out
    finir(o, mat, "fourrure", "armure_fourrure", 900, sol_torse)

    # --- casque_fourrure : bonnet de cuir, bordure épaisse de fourrure, rabats d'oreilles
    cibles = L.bvh_de(["SuperHero_Male"], noms_heros=["peau"], filtre=lambda p: p.y > 1.50 and abs(p.x) < 0.2)
    lignes = [90, 70, 52, 36, 26, 12, -4, -18]

    def jeu(th, ph):
        return 0.020

    def garder_c(th, ph):
        # devant : s'arrête au-dessus des sourcils ; côtés et nuque : descend jusqu'à la nuque (couvre l'occiput)
        t = abs(math.atan2(math.sin(th), math.cos(th)))
        return ph > math.radians(24) or t > math.radians(80)
    bm = coque_tete("casque_fourrure", lignes, 18, jeu, garder_c, cibles, 0)
    epaissir_bords(bm, 0.008)
    o_dome = en_objet(bm, "dome")
    # bordure de fourrure : tore autour du front (du sourcil à la nuque)
    bm = bmesh.new()
    axe, ref = (0, 1, 0), (0, 0, 1)
    c = TETE + Vector((0, 0.072, -0.008))
    cbas = TETE + Vector((0, 0.040, -0.008))
    f0 = L.rayon_sur(cibles, c, axe, ref, 0.018)
    f1 = L.rayon_sur(cibles, cbas, axe, ref, 0.016)
    rs = [lambda t: f0(t) - 0.004, lambda t: f0(t) + 0.010, lambda t: (f0(t) + f1(t)) / 2 + 0.020, lambda t: f1(t) + 0.012, lambda t: f1(t) - 0.004]
    cs = [(c + Vector((0, 0.02, 0)), axe, ref), (c + Vector((0, 0.012, 0)), axe, ref), ((c + cbas) / 2, axe, ref), (cbas, axe, ref), (cbas + Vector((0, 0.004, 0)), axe, ref)]
    L.anneau(bm, cs, rs, 18, 4)
    orienter(bm, list(bm.faces), TETE + Vector((0, 0.2, 0)), TETE - Vector((0, 0.2, 0)))
    o_bord = en_objet(bm, "bord")
    # rabats d'oreilles (cuir doublé de fourrure)
    rabats = []
    for s in (1, -1):
        bm = bmesh.new()
        axe2 = Vector((0, 1, 0))
        cs = []
        rs = []
        for k, dy in enumerate([0.045, -0.01, -0.07]):
            cc = TETE + Vector((0, dy, -0.012))
            cs.append((cc, axe2, (0, 0, 1)))
            rs.append(L.rayon_sur(cibles, cc, axe2, (0, 0, 1), 0.026 + 0.004 * k))
        th0 = math.pi / 2 if s > 0 else -math.pi / 2
        # arc autour de l'oreille (theta mesuré depuis +z vers +x)
        L.anneau(bm, cs, rs, 4, 5, ferme=False, arc=(th0 - 0.45, th0 + 0.45))
        orienter(bm, list(bm.faces), TETE + Vector((0, 0.3, 0)), TETE - Vector((0, 0.3, 0)))
        epaissir_bords(bm, 0.008)
        rabats.append(en_objet(bm, "rabat"))
    o = fusion([o_dome, o_bord] + rabats, "casque_fourrure")
    tete_rigide(o)

    def mat_c(P, N, pa, bd):
        out = mat_cuir(P, N, pa, bd, 0.40, CUIR, 51)
        m = pa == 4
        out[m] = mat_fourrure(P[m], N[m], pa[m], bd[m], FOURRURE, 0.6, 53)
        r = pa == 5
        out[r] = mat_fourrure(P[r], N[r], pa[r], bd[r], FOURRURE_BRUNE, 0.5, 57)
        # coutures en croix sur le dôme
        x, z = P[:, 0], P[:, 2]
        cr = (pa == 0) & ((np.abs(x) < 0.004) | (np.abs(z - TETE.z) < 0.004))
        out[cr, :3] = L.rampe(CUIR, np.full(cr.sum(), 0.12))
        return out
    finir(o, mat_c, "fourrure", "casque_fourrure", 600, sol_tete)

    # --- gants_fourrure : gants de cuir, gros revers de fourrure
    g = gants_base("gants_fourrure", 520, 0.005)
    parts = [g]
    for cote in ("l", "r"):
        parts.append(manchette("mf_" + cote, "brassards", 0.548, 0.668, 0.016, 0.010, 0.020, 12, 4, cote, 0.02))
    o = fusion(parts, "gants_fourrure")

    def mat_g(P, N, pa, bd):
        out = mat_cuir(P, N, pa, bd, 0.40, CUIR, 61)
        m = pa == 4
        out[m] = mat_fourrure(P[m], N[m], pa[m], bd[m], FOURRURE, 0.62, 63, sens=np.array([1.0, 0.0, 0.0]))
        return out
    finir(o, mat_g, "fourrure", "gants_fourrure", 900, sol_paire_mains)

    # --- bottes_fourrure : bottes enveloppées de fourrure, lanières croisées
    b = bottes_base("bottes_fourrure", 470, 0.008)
    parts = [b]
    for cote in ("l", "r"):
        parts.append(revers_botte("rf_" + cote, cote, 0.30, 0.445, 0.014, 0.016, 0.018, 12, 4, evase=0.014))
        parts.append(revers_botte("l1_" + cote, cote, 0.13, 0.155, 0.006, 0.006, 0.005, 10, 2))
    o = fusion(parts, "bottes_fourrure")

    def mat_b(P, N, pa, bd):
        out = mat_fourrure(P, N, pa, bd, FOURRURE_BRUNE, 0.5, 67)
        y = P[:, 1]
        sem = (pa == 0) & (y < 0.05)
        out[sem] = mat_cuir(P[sem], N[sem], pa[sem], bd[sem], 0.25, CUIR_SOMBRE, 69)
        # lanières croisées sur le tibia
        x = P[:, 0]
        lan = (pa == 0) & (y > 0.06) & (y < 0.30) & (np.abs(np.mod(y * 25.0 + np.abs(x) * 30.0, 1.0) - 0.5) < 0.1)
        out[lan] = mat_cuir(P[lan], N[lan], pa[lan], bd[lan], 0.3, CUIR_SOMBRE, 71)
        m = pa == 4
        out[m] = mat_fourrure(P[m], N[m], pa[m], bd[m], FOURRURE, 0.6, 73)
        s = pa == 2
        out[s] = mat_cuir(P[s], N[s], pa[s], bd[s], 0.3, CUIR_SOMBRE, 75)
        return out
    finir(o, mat_b, "fourrure", "bottes_fourrure", 900, sol_paire_pieds)


# ============================================================================================================ OS DE DRAUGR
def plaque_torse(bm, y_haut, y_bas, arc_deg, partie, cible, ep=0.010, n=8, dos=False, decal=0.0):
    axe, ref = (0, 1, 0), ((0, 0, -1) if dos else (0, 0, 1))
    c0, c1 = Vector((0, y_haut, 0)), Vector((0, y_bas, 0))
    f0 = L.rayon_sur(cible, c0, axe, ref, 0.004 + decal)
    f1 = L.rayon_sur(cible, c1, axe, ref, 0.010 + decal)
    a = math.radians(arc_deg)
    bande(bm, [(c0, axe, ref), (c1, axe, ref)], [f0, f1], ep, n, partie, arc=(-a, a), bombe=0.004)


def os_draugr():
    # --- cuirasse_os : cuir noirci, côtes d'os en plaques sur la poitrine, échine d'os dans le dos, épaulières (omoplates)
    base = torse_base("cuirasse_os", 360, jeu=0.012)
    L.lisser_normales(base)
    base.data.update()
    cible = L.bvh_de(noms_heros=[], noms_quaternius=[], filtre=None) if False else None
    import mathutils
    me = base.data
    cible = mathutils.bvhtree.BVHTree.FromObject(base, bpy.context.evaluated_depsgraph_get())
    bm = bmesh.new()
    for i, (yh, yb, arc) in enumerate([(1.40, 1.35, 62), (1.33, 1.28, 66), (1.26, 1.21, 64), (1.19, 1.14, 58)]):
        plaque_torse(bm, yh, yb, arc, 6, cible, 0.010, 6, False, 0.002 * i)
    # sternum
    for i, (yh, yb) in enumerate([(1.45, 1.40)]):
        plaque_torse(bm, yh, yb, 22, 6, cible, 0.012, 3)
    # échine (dos) : vertèbres
    for i in range(3):
        y = 1.40 - i * 0.09
        plaque_torse(bm, y, y - 0.05, 16, 6, cible, 0.012, 2, True)
    o_pl = en_objet(bm, "plaques")
    poids_de(o_pl, "tunique", lambda p: abs(p.x) < 0.3, 1)
    ep_l = epauliere("epo_l", "l", [(0.14, 0.30, 0.012, 100), (0.22, 0.37, 0.010, 85)], 7, 5)
    ep_r = epauliere("epo_r", "r", [(0.14, 0.30, 0.012, 100), (0.22, 0.37, 0.010, 85)], 7, 5)
    bel = ceinture("ceint", 0.935, 0.99, 0.012, 12)
    o = fusion([base, o_pl, ep_l, ep_r, bel], "cuirasse_os")

    def mat(P, N, pa, bd):
        out = mat_cuir(P, N, pa, bd, 0.30, CUIR_SOMBRE, 81)
        b = (pa == 6) | (pa == 7)
        out[b] = mat_os(P[b], N[b], pa[b], bd[b], 0.50, 83)
        # épaulières : omoplates empilées, nervures sombres dans l'axe du bras

        # lanières de cuir qui tiennent les côtes (verticales à x = ±0,07)
        lan = (pa == 6) & (np.abs(np.abs(P[:, 0]) - 0.075) < 0.008)
        out[lan] = mat_cuir(P[lan], N[lan], pa[lan], bd[lan], 0.35, CUIR, 85)
        c = pa == 1
        out[c] = mat_cuir(P[c], N[c], pa[c], bd[c], 0.3, CUIR_SOMBRE, 87)
        bou = c & (P[:, 2] > 0.05) & (np.abs(P[:, 0]) < 0.03)
        out[bou] = mat_os(P[bou], N[bou], pa[bou], bd[bou], 0.65, 89)
        return out
    finir(o, mat, "os", "cuirasse_os", 900, sol_torse)

    # --- casque_os : crâne de draugr en casque (orbites au-dessus du front), arcade, pommettes / mâchoire en couvre-joues
    cibles = L.bvh_de(["SuperHero_Male"], noms_heros=["peau"], filtre=lambda p: p.y > 1.50 and abs(p.x) < 0.2)
    lignes = [90, 70, 52, 38, 26, 10, -6]

    def jeu(th, ph):
        devant = max(0.0, math.cos(th))
        return 0.018 + 0.010 * devant * max(0.0, 1 - abs(ph - 0.45) * 2)

    def garder(th, ph):
        t = abs(math.atan2(math.sin(th), math.cos(th)))
        return not (t < math.radians(55) and ph < math.radians(24))
    bm = coque_tete("casque_os", lignes, 18, jeu, garder, cibles, 6)
    epaissir_bords(bm, 0.010)
    o_dome = en_objet(bm, "dome")
    # couvre-joues (mâchoire du crâne)
    bm = bmesh.new()
    for s in (1, -1):
        cs, rs = [], []
        for k, dy in enumerate([0.0, -0.05, -0.10]):
            cc = TETE + Vector((0, dy, 0.0))
            cs.append((cc, (0, 1, 0), (0, 0, 1)))
            rs.append(L.rayon_sur(cibles, cc, (0, 1, 0), (0, 0, 1), 0.022 + 0.004 * k))
        th0 = 0.95 * s
        L.anneau(bm, cs, rs, 3, 8, ferme=False, arc=(th0 - 0.32, th0 + 0.32))
    orienter(bm, list(bm.faces), TETE + Vector((0, 0.3, 0)), TETE - Vector((0, 0.3, 0)))
    epaissir_bords(bm, 0.008)
    o_det = en_objet(bm, "joues")
    o = fusion([o_dome, o_det], "casque_os")
    tete_rigide(o)

    def mat_c(P, N, pa, bd):
        out = mat_os(P, N, pa, bd, 0.62, 91)
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        # orbites et cavité nasale du crâne, au-dessus du front du porteur
        ox = np.abs(x) - 0.038
        orb = (pa == 6) & (z > 0.03) & ((ox ** 2) / 0.021 ** 2 + ((y - (TETE.y + 0.088)) ** 2) / 0.016 ** 2 < 1)
        out[orb, :3] = L.rampe(OS, np.full(orb.sum(), 0.02))
        nez = (pa == 6) & (z > 0.03) & (np.abs(x) < 0.011 - (TETE.y + 0.07 - y) * 0.25) & (y < TETE.y + 0.072) & (y > TETE.y + 0.052)
        out[nez, :3] = L.rampe(OS, np.full(nez.sum(), 0.04))
        # rangée de dents au bord de l'ouverture (mâchoire supérieure du crâne)
        dents = (pa == 6) & (z > 0.04) & (bd < 0.022) & (bd > 0.004) & (y > TETE.y + 0.02)
        out[dents & (np.mod(x * 90.0, 1.0) < 0.22), :3] *= 0.45
        # dents (couvre-joues : mâchoire) en alternance claire/sombre
        j = pa == 8
        den = j & (np.mod(y * 70.0, 1.0) < 0.25)
        out[den, :3] *= 0.55
        # sangle de cuir sous le crâne (derrière)
        s = (pa == 6) & (y < TETE.y + 0.02) & (z < 0.0)
        out[s] = mat_cuir(P[s], N[s], pa[s], bd[s], 0.3, CUIR_SOMBRE, 93)
        return out
    finir(o, mat_c, "os", "casque_os", 600, sol_tete)

    # --- gants_os : gantelets de cuir noirci, phalanges et plaque d'os sur le dos de la main, canon d'os sur l'avant-bras
    g = gants_base("gants_os", 500, 0.004)
    parts = [g]
    for cote in ("l", "r"):
        s = 1 if cote == "l" else -1
        parts.append(manchette("mc_" + cote, "brassards", 0.552, 0.66, 0.008, 0.006, 0.006, 10, 1, cote, 0.008))
        # canon d'os (demi-tube sur le dessus de l'avant-bras)
        bm = bmesh.new()
        a = os_g("lowerarm_" + cote)
        h = os_g("hand_" + cote)
        axe = (h - a).normalized()
        cible = L.bvh_de(["tunique", "gants"], noms_heros=["brassards", "tunique"], filtre=lambda p: abs(p.x) > 0.45)
        c0 = a.lerp(h, (0.50 - abs(a.x)) / (abs(h.x) - abs(a.x)))
        c1 = a.lerp(h, (0.66 - abs(a.x)) / (abs(h.x) - abs(a.x)))
        f0 = L.rayon_sur(cible, c0, axe, (0, 1, 0), 0.020)
        f1 = L.rayon_sur(cible, c1, axe, (0, 1, 0), 0.016)
        bande(bm, [(c0, axe, (0, 1, 0)), (c1, axe, (0, 1, 0))], [f0, f1], 0.010, 6, 6, arc=(-1.2, 1.2), bombe=0.006)
        o_c = en_objet(bm, "canon")
        poids_de(o_c, "brassards", lambda p: (p.x > 0) == (s > 0), 1)
        parts.append(o_c)
    o = fusion(parts, "gants_os")

    def mat_g(P, N, pa, bd):
        out = mat_cuir(P, N, pa, bd, 0.30, CUIR_SOMBRE, 95)
        b = pa == 6
        out[b] = mat_os(P[b], N[b], pa[b], bd[b], 0.6, 97)
        x = np.abs(P[:, 0])
        # phalanges d'os peintes sur le dessus des doigts et le dos de la main
        ph = (pa == 0) & (x > 0.74) & (N[:, 1] > 0.45) & (np.mod(x * 36.0, 1.0) < 0.7)
        out[ph] = mat_os(P[ph], N[ph], pa[ph], bd[ph], 0.6, 99)
        return out
    finir(o, mat_g, "os", "gants_os", 900, sol_paire_mains)

    # --- bottes_os : bottes de cuir noirci, jambières d'os (tibia), genouillère
    b = bottes_base("bottes_os", 440, 0.005)
    parts = [b]
    for cote in ("l", "r"):
        s = 1 if cote == "l" else -1
        parts.append(revers_botte("ro_" + cote, cote, 0.36, 0.42, 0.008, 0.008, 0.006, 10, 1))
        bm = bmesh.new()
        k = os_g("calf_" + cote)
        f = os_g("foot_" + cote)
        axe = (k - f).normalized()
        cible = L.bvh_de(["bottes", "pantalon"], noms_heros=["pantalon", "bottes"], filtre=lambda p: (p.x > 0) == (s > 0) and p.y < 0.65)
        for (y1, y0, arc) in [(0.47, 0.30, 1.1), (0.32, 0.14, 1.0)]:
            c0 = f.lerp(k, (y1 - f.y) / (k.y - f.y))
            c1 = f.lerp(k, (y0 - f.y) / (k.y - f.y))
            f0 = L.rayon_sur(cible, c0, axe, (0, 0, 1), 0.016)
            f1 = L.rayon_sur(cible, c1, axe, (0, 0, 1), 0.012)
            bande(bm, [(c0, axe, (0, 0, 1)), (c1, axe, (0, 0, 1))], [f0, f1], 0.010, 6, 6, arc=(-arc, arc), bombe=0.008)
        o_j = en_objet(bm, "jambiere")
        poids_de(o_j, "bottes", lambda p: (p.x > 0) == (s > 0), 1)
        parts.append(o_j)
    o = fusion(parts, "bottes_os")

    def mat_b(P, N, pa, bd):
        out = mat_cuir(P, N, pa, bd, 0.30, CUIR_SOMBRE, 101)
        b = pa == 6
        out[b] = mat_os(P[b], N[b], pa[b], bd[b], 0.6, 103)
        return out
    finir(o, mat_b, "os", "bottes_os", 900, sol_paire_pieds)


# ============================================================================================================
if FAMILLE in ("cuir", "tout"):
    cuir()
if FAMILLE in ("fourrure", "tout"):
    fourrure()
if FAMILLE in ("os", "tout"):
    os_draugr()
if APERCU:
    os.makedirs(APERCU, exist_ok=True)
    corps = [bpy.data.objects[n] for n in ("SuperHero_Male",) if n in bpy.data.objects]
    L.apercu(PIECES + corps, APERCU, (0, 0.95, 0), 2.0, FAMILLE + "_")
    L.apercu(PIECES + corps, APERCU, (0, 1.35, 0), 0.8, FAMILLE + "_haut_")
print("FINI", FAMILLE)
