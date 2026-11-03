"""Armures HD (charte conception_rpg/CHARTE_ARMURES_HD.md, branche armures_hd/os_verre) :
  - OS DE DRAUGR refait (casque_os, cuirasse_os, gants_os, bottes_os + chausses os) : « pourrie mais classe » — os jaunis patinés
    assemblés sur cuir noirci et fer rouillé, crâne-casque à orbites, côtes en plastron, vertèbres en dossière, runes funéraires ;
  - VERRE (casque_verre, cuirasse_verre, gantelets_verre, bottes_verre + chausses verre) : armure légère d'élite, plaques de verre
    vert-bleu translucide serties d'argent sur cuir clair, même famille que Larme-de-Givre ; bandeaux de runes (matériau « runes ») qui
    LUISENT dans la variante enchantée (même modèle, ArmureVisible : variante de matériau « .enchante »).

  blender -b --python gen_os_verre.py -- [os|verre|chausses|tout] [apercu=<dossier>]

Outils repris de l'agent X (../armures_lib.py, ../legeres/gen_legeres.py : coques ajustées sur le héros, poids hérités des vêtements
Quaternius, cuisson texel par texel depuis la position 3D). Nouveautés HD :
  - atlas 1024² par ensemble (≈ 512² par pièce), chausses 512² ; détails peints dans l'espace (runes, rivets, coutures, fissures,
    stries de croissance de l'os, inclusions du verre, bords biseautés) + occlusion dans les creux ;
  - géométrie détaillée (plaques épaisses qui suivent le corps, bords biseautés, sertissures d'argent sous chaque plaque de verre) ;
  - PLUSIEURS MATÉRIAUX par pièce (une surface par matière, même atlas) : cuir / os / fer.rouille ; cuir.clair / argent / verre / runes.
    La surface 0 est toujours la coque de base (ArmureVisible lit son ourlet / le haut des bottes sur la surface 0).
"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, ".."))
sys.path.insert(0, os.path.join(ICI, "..", "legeres"))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
QUOI = next((a for a in ARGS if "=" not in a), "tout")
APERCU = next((a.split("=", 1)[1] for a in ARGS if a.startswith("apercu=")), "")
# gen_legeres (agent X) importé SANS rien générer : famille « rien »
_argv = sys.argv
sys.argv = [sys.argv[0], "--", "rien"]
import armures_lib as L
import gen_legeres as X
sys.argv = _argv
from armures_lib import B, G

ARM = X.ARM
TETE = X.TETE
TEX = os.path.join(L.ROOT, "sources_blender", "armures", "textures")
CHAUSSES = os.path.join(L.ROOT, "assets", "modeles", "armures", "chausses")

# parties (couche de faces « partie ») -> matière
P_COQUE, P_CUIR2, P_OS, P_OS2, P_OS3, P_FER, P_RUNES, P_VERRE, P_ARGENT, P_OR, P_TISSU = 0, 1, 6, 7, 8, 9, 10, 11, 12, 13, 14

# ------------------------------------------------------------------------------------------------------------- palettes
OS = L.hexa("#16110b", "#231a11", "#33281a", "#453723", "#58472d", "#6b5836", "#7e6a42", "#917c50", "#a28e60", "#b3a074", "#c4b28a")
CUIR_NOIRCI = L.hexa("#080706", "#0f0c0a", "#16120e", "#1e1813", "#271f18", "#31271e", "#3c3025", "#493a2d")
FER_ROUILLE = L.hexa("#100e0d", "#1a1715", "#24201d", "#302a26", "#3d3630", "#4c443d", "#5d554d", "#716860")
ROUILLE = L.hexa("#2a1206", "#41200c", "#5a2e12", "#743d18", "#8c4f22", "#a3632f")
VERRE = L.hexa("#020f0c", "#041b16", "#062820", "#0a372c", "#0f4839", "#155b48", "#1d7059", "#28876c", "#38a083", "#55b89b", "#80d2b8", "#b8eadb")
ARGENT = L.hexa("#1d1f23", "#2e3136", "#43474d", "#5b6067", "#767b82", "#91969d", "#adb2b8", "#c8ccd1", "#e0e3e7")
CUIR_CLAIR = L.hexa("#241b14", "#33271d", "#443428", "#574434", "#6b5541", "#7f674f", "#93795e", "#a68b6e", "#b89d80")
NIELLE = L.hexa("#06080a", "#0b0f12", "#11171a", "#182024")


def rgba(rgb, a):
    a = np.broadcast_to(np.asarray(a, dtype=float), (len(rgb),))
    return np.concatenate([rgb, a[:, None]], 1)


def lisse(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------------------------------------------------- runes
## Segments d'un futhark simplifié dans une case (u le long de la rangée 0..1, v en travers -1..1) : un fût + branches choisies par
## le hachage de la case (jamais deux cases identiques côte à côte).
_SEGS = [((0.5, -0.82), (0.5, 0.82)),                       # 0 fût
         ((0.5, 0.82), (0.86, 0.40)), ((0.5, 0.82), (0.14, 0.40)),
         ((0.5, 0.30), (0.86, -0.12)), ((0.5, 0.30), (0.14, -0.12)),
         ((0.5, -0.05), (0.86, -0.50)), ((0.5, 0.45), (0.86, 0.05)),
         ((0.14, 0.80), (0.86, -0.80)), ((0.86, 0.82), (0.86, -0.20)),
         ((0.5, 0.82), (0.86, 0.82))]


def _dseg(u, v, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = np.clip(((u - ax) * dx + (v - ay) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(u - (ax + t * dx), v - (ay + t * dy))


def runes(s, t, h, g=0, w=0.11, asp=0.62):
    """Masque 0..1 de runes gravées : s le long de la rangée (m), t en travers (-1..1), h = largeur d'une case (m)."""
    k = np.floor(s / h).astype(np.int64)
    u = s / h - k
    hs = np.array([L._h3(int(i), 3, g, 11) for i in range(int(k.min()), int(k.max()) + 1)]) if len(k) else np.zeros(1)
    hk = hs[k - k.min()]
    bits = (hk * 65535).astype(np.int64)
    d = np.full(len(s), 9.0)
    uu = (u - 0.5) * asp + 0.5
    for i, (a, b) in enumerate(_SEGS):
        m = np.ones(len(s), bool) if i == 0 else ((bits >> i) & 1).astype(bool)
        if i == 7:
            m &= ((bits >> 12) & 3) == 0
        di = _dseg(uu, t, ((a[0] - 0.5) * asp + 0.5, a[1]), ((b[0] - 0.5) * asp + 0.5, b[1]))
        d = np.where(m, np.minimum(d, di), d)
    # séparateurs (deux points) toutes les 4 à 6 cases
    sep = (np.mod(k, 5) == 4)
    dp = np.minimum(np.hypot((u - 0.5) * asp, t - 0.35), np.hypot((u - 0.5) * asp, t + 0.35))
    d = np.where(sep, dp - 0.04, d)
    return 1.0 - lisse(w * 0.6, w * 1.25, d)


def anneau_st(P, c, axe, ref, rayon=None):
    """(s, t_axial, r) d'un point autour d'un axe : s = angle * rayon moyen (m)."""
    axe = np.asarray(axe, float) / np.linalg.norm(axe)
    ref = np.asarray(ref, float)
    ref = ref - axe * ref.dot(axe)
    ref /= np.linalg.norm(ref)
    e2 = np.cross(axe, ref)
    q = P - np.asarray(c, float)
    ax = q @ axe
    r = q - np.outer(ax, axe)
    ang = np.arctan2(r @ e2, r @ ref)
    rr = np.linalg.norm(r, axis=1)
    return ang * (rayon if rayon else np.median(rr)), ax, rr


# ------------------------------------------------------------------------------------------------------------- matières
def m_cuir_noirci(P, N, bd, base=0.42, g=0):
    v = base + X.bruit_cuir(P, g) * 1.1
    v += np.clip(N[:, 1], -1, 1) * 0.05
    # grain fin + craquelures du cuir sec
    cr = np.abs(L.fbm(P, 38.0, g + 5) - 0.5)
    v = np.where(cr < 0.018, v - 0.12, v)
    v = X.coutures(P, bd, v, 0.006, 0.011)
    # usure claire sur les arêtes vives
    v = np.where((bd > 0.0015) & (bd < 0.004), v + 0.10, v)
    rgb = L.rampe(CUIR_NOIRCI, np.clip(v, 0, 0.999))
    # moisissure / poussière de tombe grise dans les zones basses
    t = np.clip((L.fbm(P, 5.0, g + 9) - 0.56) * 2.5, 0, 1)[:, None] * 0.45
    rgb = rgb * (1 - t) + np.array([0.20, 0.19, 0.16]) * t
    return rgba(rgb, np.clip(0.12 + v * 0.35, 0.05, 0.45))


def m_os(P, N, bd, base=0.56, g=0, stries=None):
    """Os jauni patiné HD : variations lentes, pores, stries de croissance (le long de `stries`), fissures fines, arêtes usées claires,
    patine brune et crasse de crypte dans les creux."""
    v = base + (L.fbm(P, 6.0, g) - 0.5) * 0.14 + (L.bruit(P, 70.0, g + 3) - 0.5) * 0.05 + (L.bruit(P, 190.0, g + 4) - 0.5) * 0.05
    v += np.clip(N[:, 1], -1, 1) * 0.06
    if stries is not None:
        s = P @ np.asarray(stries, float)
        v += (np.sin(s * 900.0 + L.fbm(P, 8.0, g + 6) * 9.0) * 0.5 + 0.5) * -0.045
    pores = L.bruit(P, 260.0, g + 7) > 0.86
    v = np.where(pores, v - 0.10, v)
    f = np.abs(L.fbm(P, 11.0, g + 8) - 0.5)
    zone = L.fbm(P, 3.5, g + 11) > 0.47
    v = np.where((f < 0.007) & zone, v - 0.30, v)
    v = np.where((f >= 0.007) & (f < 0.013) & zone, v - 0.07, v)
    v = np.where(bd < 0.0035, v - 0.16, np.where(bd < 0.009, v + 0.10, v))       # tranche sombre, arête polie (lisible au 480x270)
    rgb = L.rampe(OS, np.clip(v, 0, 0.999))
    t = np.clip((L.fbm(P, 3.0, g + 12) - 0.40) * 1.8, 0, 1)[:, None]
    rgb = rgb * (1 - 0.50 * t) + np.array([0.20, 0.13, 0.07]) * 0.50 * t
    # taches de terre de tombe et coulures sombres (vers le bas)
    tc = np.clip((L.fbm(P * np.array([1.0, 0.35, 1.0]), 14.0, g + 13) - 0.62) * 4.0, 0, 1)[:, None]
    rgb = rgb * (1 - 0.55 * tc) + np.array([0.09, 0.07, 0.05]) * 0.55 * tc
    return rgba(rgb, np.clip(0.20 + v * 0.50, 0, 0.8))


def m_fer_rouille(P, N, bd, base=0.50, g=0):
    v = base + (L.fbm(P, 24.0, g) - 0.5) * 0.30 + np.clip(N[:, 1], -1, 1) * 0.08
    v = np.where(bd < 0.003, v + 0.14, v)
    rgb = L.rampe(FER_ROUILLE, np.clip(v, 0, 0.999))
    r = np.clip((L.fbm(P, 9.0, g + 3) - 0.42) * 2.4, 0, 1)
    r = np.maximum(r, (L.bruit(P, 120.0, g + 4) > 0.8) * 0.6)
    rgb = rgb * (1 - r[:, None] * 0.8) + L.rampe(ROUILLE, np.clip(L.fbm(P, 30.0, g + 5), 0, 0.999)) * r[:, None] * 0.8
    return rgba(rgb, np.clip(0.55 - r * 0.45, 0.05, 0.7))


def gravure(out, masque, prof=0.55):
    """Grave un motif (masque 0..1) : creux sombre et mat."""
    k = (masque * prof)[:, None]
    out[:, :3] = out[:, :3] * (1 - k) + np.array([0.06, 0.045, 0.03]) * k
    out[:, 3] *= 1 - masque * 0.8
    return out


def m_cuir_clair(P, N, bd, g=0, piqure=True):
    v = 0.50 + X.bruit_cuir(P, g) * 0.9 + np.clip(N[:, 1], -1, 1) * 0.06
    if piqure:
        # matelassage en losanges (piqûres fines)
        a = np.mod((P[:, 0] + P[:, 1]) / 0.045, 1.0)
        b = np.mod((-P[:, 0] + P[:, 1]) / 0.045, 1.0)
        l = (np.minimum(a, 1 - a) < 0.035) | (np.minimum(b, 1 - b) < 0.035)
        v = np.where(l, v - 0.13, v)
        v = np.where(~l, v + 0.03 * np.sin(np.minimum(a, b) * math.pi), v)
    v = X.coutures(P, bd, v, 0.006, 0.011)
    rgb = L.rampe(CUIR_CLAIR, np.clip(v, 0, 0.999))
    return rgba(rgb, np.clip(0.15 + v * 0.35, 0.05, 0.5))


def m_argent(P, N, bd, g=0, entrelacs=True):
    v = 0.58 + (L.fbm(P, 30.0, g) - 0.5) * 0.18 + np.clip(N[:, 1], -1, 1) * 0.10
    # brossé fin
    v += (L.bruit(P * np.array([1.0, 12.0, 1.0]), 120.0, g + 2) - 0.5) * 0.06
    v = np.where(bd < 0.0022, v + 0.22, np.where(bd < 0.004, v - 0.10, v))     # biseau poli + filet gravé
    out = rgba(L.rampe(ARGENT, np.clip(v, 0, 0.999)), 0.9)
    if entrelacs:
        # rinceau / entrelacs nordique gravé sur les marlis larges
        q = P * 140.0
        e = np.abs(np.sin(q[:, 0] + np.sin(q[:, 1] * 0.7) * 1.6) * np.cos(q[:, 1] * 0.9 + np.sin(q[:, 2]) * 1.2))
        m = ((e < 0.16) & (bd > 0.005)).astype(float)
        out[:, :3] *= (1 - 0.45 * m)[:, None]
    # ternissure dans les creux (l'occlusion de cuire() la renforce)
    return out


def m_verre(P, N, bd, g=0, teinte=0.5):
    """Verre vert-bleu : voiles internes lents, inclusions scintillantes (comme Larme-de-Givre), facettes, biseau clair aux bords."""
    v = teinte + (L.fbm(P, 7.0, g) - 0.5) * 0.22 + (L.fbm(P, 22.0, g + 2) - 0.5) * 0.10
    # facettes : paliers selon la normale (cristal taillé)
    fac = np.floor((N[:, 0] * 2.0 + N[:, 1] * 3.0 + N[:, 2] * 1.0) * 2.0) * 0.025
    v += fac
    # veines blanchâtres (givre pris dans le verre)
    vn = np.abs(L.fbm(P, 9.0, g + 5) - 0.5)
    v = np.where(vn < 0.012, v + 0.18, v)
    v = np.where(bd < 0.003, v + 0.28, np.where(bd < 0.006, v + 0.12, v))
    rgb = L.rampe(VERRE, np.clip(v, 0, 0.999))
    ec = L.bruit(P, 300.0, g + 7) > 0.93
    rgb[ec] = rgb[ec] * 0.3 + np.array([0.75, 1.0, 0.9]) * 0.7
    return rgba(rgb, np.clip(0.75 + v * 0.3, 0, 1))


def m_runes(P, N, bd, masque, glyphe=(0.66, 0.92, 0.80)):
    """Bandeau niellé : fond noir d'argent, runes incrustées claires (elles luisent avec la variante « .enchante »)."""
    v = 0.4 + (L.fbm(P, 40.0, 3) - 0.5) * 0.3
    rgb = L.rampe(NIELLE, np.clip(v, 0, 0.999))
    rgb = rgb * (1 - masque[:, None]) + np.array(glyphe) * masque[:, None]
    return rgba(rgb, 0.4 + 0.5 * masque)


# ------------------------------------------------------------------------------------------------------------- géométrie
def cible_de(o):
    o.data.update()
    return BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())


def plaque(bm, ys, axe_c, axe, ref, cible, jeu, ep, n, partie, arc, bombe=0.004, biseau=0.6):
    """Plaque épaisse qui SUIT le corps : sections aux points `ys` (abscisses le long de `axe` depuis `axe_c`), arc (t0, t1) autour de
    l'axe ; rangées : dessous haut, dessus haut (biseau), dessus..., dessus bas (biseau), dessous bas ; bord latéral fermé par
    epaissir via la tranche des rangées. jeu(t) : écart à la surface ; bombe : bombé au milieu de la plaque."""
    axe = Vector(axe).normalized()
    cs, rs = [], []
    k = len(ys)

    def sec(y):
        return (Vector(axe_c) + axe * y, axe, ref)
    fs = [L.rayon_sur(cible, Vector(axe_c) + axe * y, axe, ref, jeu) for y in ys]
    a0, a1 = arc
    mid = (a0 + a1) / 2
    demi = max((a1 - a0) / 2, 1e-4)

    def bom(th, i):
        u = (th - mid) / demi
        w = 1 - (2 * i / max(k - 1, 1) - 1) ** 2
        return bombe * max(0.0, 1 - u * u) * (0.4 + 0.6 * w)
    cs.append(sec(ys[0]))
    rs.append(lambda th, f=fs[0]: f(th) + 0.0008)
    for i, y in enumerate(ys):
        e = ep * (biseau if i in (0, k - 1) else 1.0)
        cs.append(sec(y))
        rs.append(lambda th, f=fs[i], e=e, i=i: f(th) + e + bom(th, i))
    cs.append(sec(ys[-1]))
    rs.append(lambda th, f=fs[-1]: f(th) + 0.0008)
    avant = set(bm.faces)
    lignes = L.anneau(bm, cs, rs, n, partie, ferme=False, arc=arc)
    # tranches latérales (début et fin de l'arc) : un polygone par bout (la plaque est fermée sur ses côtés)
    part = L.couche_partie(bm)
    for j in (0, len(lignes[0]) - 1):
        try:
            f = bm.faces.new([l[j] for l in lignes])
            f[part] = partie
        except ValueError:
            pass
    nouv = [f for f in bm.faces if f not in avant]
    p0 = Vector(axe_c) + axe * ys[0]
    p1 = Vector(axe_c) + axe * ys[-1]
    X.orienter(bm, nouv, p0, p1)
    return lignes


def crete(bm, cibles, a0, a1, nseg, h, larg, decal, partie, plein=0.75, pas=12):
    """Crête sagittale (x = 0) sur le crâne, de l'angle a0 à a1 (degrés dans le plan médian, 90 = sommet, 0 = devant) : nseg segments
    (vertèbres si plein < 1 : un vide entre deux) ; section en coin (base `larg`, arête 1/3), hauteur h (profil en cloche), fermée."""
    part = L.couche_partie(bm)
    def point(a, dh):
        d = Vector((0, math.sin(math.radians(a)), math.cos(math.radians(a))))
        hit = cibles.ray_cast(B(TETE + d * 0.45), B(-d), 0.45)
        r = (B(TETE) - hit[0]).length if hit[0] is not None else 0.11
        return TETE + d * (r + decal + dh)
    for k in range(nseg):
        s0 = a0 + (a1 - a0) * k / nseg
        s1 = s0 + (a1 - a0) / nseg * plein
        n = max(2, int(abs(s1 - s0) / pas) + 1)
        anneaux = []
        for i in range(n):
            a = s0 + (s1 - s0) * i / (n - 1)
            u = (a - a0) / (a1 - a0)
            hh = h * (0.35 + 0.65 * math.sin(u * math.pi) ** 0.8) * (1.0 if plein >= 1 else (0.75 + 0.25 * math.sin((i / (n - 1)) * math.pi)))
            pin = point(a, 0.0)
            pout = point(a, hh)
            anneaux.append([bm.verts.new(B(pin + Vector((larg / 2, 0, 0)))), bm.verts.new(B(pout + Vector((larg / 6, 0, 0)))),
                            bm.verts.new(B(pout + Vector((-larg / 6, 0, 0)))), bm.verts.new(B(pin + Vector((-larg / 2, 0, 0))))])
        for i in range(n - 1):
            A, Bv = anneaux[i], anneaux[i + 1]
            for j in range(3):
                f = bm.faces.new((A[j], Bv[j], Bv[j + 1], A[j + 1]))
                f[part] = partie
        for An in (anneaux[0], anneaux[-1]):
            f = bm.faces.new(An)
            f[part] = partie
    bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if f[part] == partie])


def ys_entre(a, b, pas=0.025):
    n = max(2, int(abs(b - a) / pas) + 1)
    return [a + (b - a) * i / (n - 1) for i in range(n)]


def en_objet_poids(bm, nom, src, filtre=None, lissage=1):
    o = X.en_objet(bm, nom)
    X.poids_de(o, src, filtre, lissage)
    return o


def joindre(objs, nom):
    print("  parts %s : %s" % (nom, ", ".join("%s=%d" % (o.name, L.nb_tris(o)) for o in objs)))
    return X.fusion(objs, nom)


def axe_avantbras(cote):
    a = X.os_g("lowerarm_" + cote)
    h = X.os_g("hand_" + cote)
    return a, (h - a).normalized(), h


def axe_tibia(cote):
    k = X.os_g("calf_" + cote)
    f = X.os_g("foot_" + cote)
    return f, (k - f).normalized(), k


def t_bras(a, h, x):
    return a.lerp(h, (x - abs(a.x)) / (abs(h.x) - abs(a.x)))


def anneau_rayon(cible, c, axe, ref, jeu):
    return L.rayon_sur(cible, c, axe, ref, jeu)


# ------------------------------------------------------------------------------------------------------------- finition
ATLAS = 1024
ZONES = {"torse": (0, 0, 1024, 576), "tete": (0, 576, 384, 448), "mains": (384, 576, 288, 448), "pieds": (672, 576, 352, 448)}
FAM = []
PIECES = []
BUDGET = {"torse": 2500, "tete": 1400, "mains": 1200, "pieds": 1200}


def finir(o, matiere, mats, ident, empl, sol):
    """mats : [(nom_matériau, {parties})], le premier = surface 0 (coque)."""
    L.lisser_normales(o)
    # cristal : facettes à plat (ombrage net de pierre taillée, éclats du reflet par facette)
    attr = o.data.attributes.get("partie")
    if attr is not None:
        for p in o.data.polygons:
            if attr.data[p.index].value == P_VERRE:
                p.use_smooth = False
    nb = L.nb_tris(o)
    print("PIECE %s : %d triangles (budget %d)" % (ident, nb, BUDGET[empl]))
    if nb > BUDGET[empl]:
        print("  !!! HORS BUDGET", ident)
    FAM.append({"o": o, "matiere": matiere, "mats": mats, "ident": ident, "empl": empl, "sol": sol})


def finir_ensemble(nom):
    atlas = np.zeros((ATLAS, ATLAS, 4))
    atlas[:, :, 3] = 1.0
    for piece in FAM:
        o = piece["o"]
        x, y, w, h = ZONES[piece["empl"]]
        L.uv_auto(o, 4.0 / min(w, h), 66)
        rgba_ = L.cuire(o, piece["matiere"], (w, h), piece["ident"], tableau=True)
        atlas[y:y + h, x:x + w] = rgba_
        for uv in o.data.uv_layers.active.data:
            uv.uv = ((x + uv.uv[0] * w) / ATLAS, (y + uv.uv[1] * h) / ATLAS)
    dilater(atlas, 12)
    img = L.image_atlas("atlas_" + nom, atlas)
    for piece in FAM:
        o = piece["o"]
        appliquer_materiaux(o, piece["mats"], img)
        if APERCU:
            PIECES.append(o)
        L.exporter(o, ARM, piece["ident"], piece["sol"])
        liberer_noms(o)
    FAM.clear()


def dilater(atlas, passes):
    """Débord supplémentaire autour des îlots (texels vides = noir pur) : les mipmaps des pièces ne bavent pas d'un îlot à l'autre."""
    rempli = atlas[:, :, :3].sum(2) > 0
    for _ in range(passes):
        vide = ~rempli
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.roll(np.roll(rempli, dy, 0), dx, 1)
            m = vide & src
            atlas[m] = np.roll(np.roll(atlas, dy, 0), dx, 1)[m]
            rempli = rempli | m
            vide = ~rempli


def appliquer_materiaux(o, mats, img):
    o.data.materials.clear()
    slot = {}
    for i, (nom, parties) in enumerate(mats):
        ancien = bpy.data.materials.get(nom)
        if ancien is not None:
            ancien.name = "zz_" + nom
        m = L.materiau(nom, img)
        assert m.name == nom, (m.name, nom)
        o.data.materials.append(m)
        for p in parties:
            slot[p] = i
    attr = o.data.attributes.get("partie")
    for p in o.data.polygons:
        v = attr.data[p.index].value if attr is not None else 0
        p.material_index = slot.get(v, 0)


def liberer_noms(o):
    for m in o.data.materials:
        if m is not None and not m.name.startswith("zz_"):
            m.name = "zz_" + m.name


def dispatch(table, defaut):
    """matière par partie : table {partie: fn(P, N, bd)}."""
    def f(P, N, pa, bd):
        out = defaut(P, N, bd)
        for p, fn in table.items():
            m = pa == p
            if m.any():
                out[m] = fn(P[m], N[m], bd[m])
        return out
    return f


# =============================================================================================================== OS DE DRAUGR
def os_draugr():
    # ------------------------------------------------------------------ cuirasse_os
    base = X.torse_base("cuirasse_os", 700, jeu=0.012)
    L.lisser_normales(base)
    cible = cible_de(base)
    bm = bmesh.new()
    o_y = Vector((0, 0, 0))
    up = (0, 1, 0)
    # côtes : 5 paires, arcs de chaque côté du sternum (du milieu vers le flanc), plus courtes en bas
    cotes = [(1.395, 0.026, 0.30, 1.30), (1.320, 0.026, 0.28, 1.36), (1.245, 0.025, 0.27, 1.30), (1.170, 0.023, 0.30, 1.12)]
    for i, (y, h, t0, t1) in enumerate(cotes):
        for s in (1, -1):
            arc = (t0, t1) if s > 0 else (-t1, -t0)
            # la côte descend vers le flanc (pente) : sections décalées en y selon theta -> 3 plaques courtes enchaînées
            plaque(bm, [y + h / 2, y, y - h / 2], o_y, up, (0, 0, 1), cible, lambda th, i=i: 0.003 + 0.0015 * i, 0.008, 6, P_OS, arc, 0.004)
    # sternum : 3 segments (manubrium, corps, xiphoïde), plus épais, runes gravées
    for (y0, y1, a) in [(1.47, 1.40, 0.20), (1.395, 1.20, 0.16), (1.195, 1.13, 0.10)]:
        plaque(bm, ys_entre(y0, y1, 0.03), o_y, up, (0, 0, 1), cible, lambda th: 0.004, 0.011, 4, P_OS2, (-a, a), 0.006)
    # dossière : 8 vertèbres + apophyses (crête), omoplates
    for i in range(8):
        y = 1.46 - i * 0.055
        plaque(bm, [y, y - 0.04], o_y, up, (0, 0, -1), cible, lambda th: 0.004, 0.010, 4, P_OS2, (-0.30, 0.30), 0.006)
        plaque(bm, [y - 0.006, y - 0.034], o_y, up, (0, 0, -1), cible, lambda th: 0.014, 0.010, 1, P_OS2, (-0.06, 0.06), 0.004)
    for s in (1, -1):
        plaque(bm, ys_entre(1.44, 1.27, 0.06), o_y, up, (0, 0, -1), cible, lambda th: 0.005, 0.009, 5, P_OS, (0.42, 1.05) if s > 0 else (-1.05, -0.42), 0.008)
    o_pl = en_objet_poids(bm, "os_plaques", "tunique", lambda p: abs(p.x) < 0.3, 1)
    # lanières de cuir qui tiennent la cage (bandes horizontales sous les côtes, sur le flanc) + fer rouillé (anneaux)
    bm = bmesh.new()
    for y in (1.37, 1.25):
        for s in (1, -1):
            plaque(bm, [y + 0.012, y - 0.012], o_y, up, (0, 0, 1), cible, lambda th: 0.002, 0.004, 5, P_CUIR2, (1.25, 1.75) if s > 0 else (-1.75, -1.25), 0.001)
    o_lan = en_objet_poids(bm, "lanieres", "tunique", lambda p: abs(p.x) < 0.3, 1)
    # épaulières : omoplates de bête en 3 lames + rebord de fer rouillé
    ep_l = X.epauliere("epo_l", "l", [(0.13, 0.29, 0.011, 105), (0.19, 0.34, 0.010, 92), (0.25, 0.385, 0.009, 80)], P_OS3, 7)
    ep_r = X.epauliere("epo_r", "r", [(0.13, 0.29, 0.011, 105), (0.19, 0.34, 0.010, 92), (0.25, 0.385, 0.009, 80)], P_OS3, 7)
    bel = X.ceinture("ceint", 0.93, 0.995, 0.012, 20)
    # boucle : plaque de fer rouillé + petit crâne d'os (bosse) au milieu devant
    bm = bmesh.new()
    plaque(bm, ys_entre(1.005, 0.92, 0.02), Vector((0, 0, 0)), up, (0, 0, 1), L.bvh_de(["tunique"], filtre=lambda p: abs(p.x) < 0.3), lambda th: 0.026, 0.008, 5, P_FER, (-0.20, 0.20), 0.006)
    plaque(bm, ys_entre(0.99, 0.935, 0.018), Vector((0, 0, 0)), up, (0, 0, 1), L.bvh_de(["tunique"], filtre=lambda p: abs(p.x) < 0.3), lambda th: 0.034, 0.012, 4, P_OS2, (-0.11, 0.11), 0.010)
    o_bou = en_objet_poids(bm, "boucle", "tunique", lambda p: abs(p.x) < 0.3, 1)
    col = X.col_montant("col", 1.49, 1.56, 0.010, 14, 0.016, 1.05)
    bpy.data.objects.remove(o_lan)
    o = joindre([base, o_pl, ep_l, ep_r, bel, o_bou, col], "cuirasse_os")

    def m_sternum(P, N, bd):
        out = m_os(P, N, bd, 0.62, 301, stries=(0, 1, 0))
        m = runes(P[:, 1], np.clip(P[:, 0] / 0.017, -1.2, 1.2), 0.026, 7, 0.12) * (bd > 0.005) * (np.abs(P[:, 0]) < 0.02) * (P[:, 2] > 0)
        return gravure(out, m, 0.75)

    def m_cuir_corps(P, N, bd):
        out = m_cuir_noirci(P, N, bd, 0.40, 305)
        # rivets de fer rouillé le long des bords de la jupe et aux attaches des lanières
        return out

    def m_epo(P, N, bd):
        out = m_os(P, N, bd, 0.58, 307, stries=(0, 1, 0))
        # rebord de fer rouillé (bord libre des lames)
        fe = bd < 0.006
        out[fe] = m_fer_rouille(P[fe], N[fe], bd[fe], 0.45, 309)
        return out

    def m_ceint(P, N, bd):
        return m_cuir_noirci(P, N, bd, 0.46, 311)

    mat = dispatch({P_OS: lambda P, N, bd: m_os(P, N, bd, 0.58, 303, stries=(1, 0.35, 0)), P_OS2: m_sternum, P_OS3: m_epo,
                    P_CUIR2: m_ceint, P_FER: lambda P, N, bd: m_fer_rouille(P, N, bd, 0.5, 313), 1: m_ceint}, m_cuir_corps)
    finir(o, mat, [("cuir", {P_COQUE, P_CUIR2, 1, 3}), ("os", {P_OS, P_OS2, P_OS3}), ("fer.rouille", {P_FER})], "cuirasse_os", "torse", X.sol_torse)

    # ------------------------------------------------------------------ casque_os
    cibles = L.bvh_de(["SuperHero_Male"], noms_heros=["peau"], filtre=lambda p: p.y > 1.50 and abs(p.x) < 0.2)
    lignes = [90, 78, 66, 55, 45, 35, 26, 17, 8, -2, -10]

    def jeu(th, ph):
        devant = max(0.0, math.cos(th))
        return 0.016 + 0.010 * devant * max(0.0, 1 - abs(ph - 0.45) * 2)

    def garder(th, ph):
        t = abs(math.atan2(math.sin(th), math.cos(th)))
        if ph < math.radians(-4) and t < math.radians(110):
            return False
        return not (t < math.radians(52) and ph < math.radians(22))
    bm = X.coque_tete("casque_os", lignes, 26, jeu, garder, cibles, P_OS)
    X.epaissir_bords(bm, 0.009)
    o_dome = X.en_objet(bm, "dome")
    # arcade sourcilière épaisse au-dessus du visage + orbites en relief (bourrelets)
    bm = bmesh.new()
    cc = TETE + Vector((0, 0.035, 0))
    f0 = L.rayon_sur(cibles, cc + Vector((0, 0.012, 0)), (0, 1, 0), (0, 0, 1), 0.030)
    f1 = L.rayon_sur(cibles, cc - Vector((0, 0.012, 0)), (0, 1, 0), (0, 0, 1), 0.034)
    X.bande(bm, [(cc + Vector((0, 0.012, 0)), (0, 1, 0), (0, 0, 1)), (cc - Vector((0, 0.012, 0)), (0, 1, 0), (0, 0, 1))], [f0, f1], 0.008, 14, P_OS2, arc=(-1.0, 1.0), bombe=0.004)
    # crête de vertèbres du front à la nuque (classe, sinistre)
    o_det = X.en_objet(bm, "arcade")
    bm = bmesh.new()
    crete(bm, cibles, 62, 165, 7, 0.022, 0.020, 0.010, P_OS2, 0.72, 5)
    o_cr = X.en_objet(bm, "crete_os")
    # couvre-joues : mâchoire du crâne (os) + rebord de fer, nuque de cuir noirci
    bm = bmesh.new()
    for s in (1, -1):
        cs, rs = [], []
        for k, dy in enumerate([0.01, -0.04, -0.09]):
            c = TETE + Vector((0, dy, 0.0))
            cs.append((c, (0, 1, 0), (0, 0, 1)))
            rs.append(L.rayon_sur(cibles, c, (0, 1, 0), (0, 0, 1), 0.024 + 0.004 * k))
        th0 = 0.98 * s
        L.anneau(bm, cs, rs, 5, P_OS3, ferme=False, arc=(th0 - 0.36, th0 + 0.36))
    X.orienter(bm, list(bm.faces), TETE + Vector((0, 0.3, 0)), TETE - Vector((0, 0.3, 0)))
    X.epaissir_bords(bm, 0.008)
    o_joue = X.en_objet(bm, "joues")
    bm = bmesh.new()
    cs, rs = [], []
    for k, dy in enumerate([-0.005, -0.05, -0.095]):
        c = TETE + Vector((0, dy, -0.01))
        cs.append((c, (0, 1, 0), (0, 0, -1)))
        rs.append(L.rayon_sur(cibles, c, (0, 1, 0), (0, 0, -1), 0.020 + 0.010 * k))
    L.anneau(bm, cs, rs, 10, P_CUIR2, ferme=False, arc=(-1.75, 1.75))
    X.orienter(bm, list(bm.faces), TETE + Vector((0, 0.3, 0)), TETE - Vector((0, 0.3, 0)))
    X.epaissir_bords(bm, 0.005)
    o_nuq = X.en_objet(bm, "nuque")
    o = joindre([o_dome, o_det, o_cr, o_joue, o_nuq], "casque_os")
    X.tete_rigide(o)
    YO = TETE.y + 0.075

    def m_crane(P, N, bd):
        out = m_os(P, N, bd, 0.64, 321, stries=(0, 0.3, 1))
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        # orbites profondes du crâne au-dessus du front + cavité nasale, rebord clair
        ox = np.abs(x) - 0.041
        e = (ox ** 2) / 0.027 ** 2 + ((y - YO) ** 2) / 0.022 ** 2
        orb = (z > 0.03) & (e < 1)
        out[orb, :3] = L.rampe(OS, np.clip(0.02 + e[orb] * 0.08, 0, 1))
        bord = (z > 0.03) & (e >= 1) & (e < 1.7)
        out[bord, :3] *= (0.62 + 0.25 * (e[bord] - 1))[:, None]
        nez = (z > 0.03) & (np.abs(x) < 0.016 - (YO - 0.012 - y) * 0.35) & (y < YO - 0.006) & (y > YO - 0.045)
        out[nez, :3] = L.rampe(OS, np.full(nez.sum(), 0.03))
        # sutures crâniennes (zigzag) au sommet
        sut = np.abs(x + 0.004 * np.sin(z * 260.0)) < 0.0018
        out[sut & (y > YO + 0.03), :3] *= 0.45
        # runes funéraires sur le pourtour (bandeau au-dessus de la nuque)
        s_, ax, _ = anneau_st(P, TETE, (0, 1, 0), (0, 0, 1), 0.12)
        band = (np.abs(ax - 0.035) < 0.012) & (z < 0.0)
        m = runes(s_, np.clip((ax - 0.035) / 0.011, -1.2, 1.2), 0.02, 9, 0.12) * band
        return gravure(out, m, 0.7)

    def m_joue(P, N, bd):
        out = m_os(P, N, bd, 0.60, 323, stries=(0, 1, 0))
        den = (np.mod(P[:, 1] * 80.0, 1.0) < 0.16) & (bd < 0.02)
        out[den, :3] *= 0.4
        fe = bd < 0.005
        out[fe] = m_fer_rouille(P[fe], N[fe], bd[fe], 0.45, 325)
        return out

    mat = dispatch({P_OS2: lambda P, N, bd: m_os(P, N, bd, 0.66, 327, stries=(1, 0, 0)), P_OS3: m_joue,
                    P_CUIR2: lambda P, N, bd: m_cuir_noirci(P, N, bd, 0.42, 329)}, m_crane)
    finir(o, mat, [("os", {P_COQUE, P_OS, P_OS2, P_OS3}), ("cuir", {P_CUIR2})], "casque_os", "tete", X.sol_tete)

    # ------------------------------------------------------------------ gants_os
    g = X.gants_base("gants_os", 430, 0.004)
    parts = [g]
    br = L.bvh_de(["tunique", "gants"], noms_heros=["brassards", "tunique"], filtre=lambda p: abs(p.x) > 0.45)
    gt = L.bvh_de(["gants"])
    for cote in ("l", "r"):
        s = 1 if cote == "l" else -1
        parts.append(X.manchette("mc_" + cote, "brassards", 0.552, 0.665, 0.007, 0.005, 0.004, 10, P_CUIR2, cote, 0.004))
        a, ax, h = axe_avantbras(cote)
        bm = bmesh.new()
        # canon : deux os longs (radius / ulna) côte à côte sur le dessus de l'avant-bras, sanglés de fer rouillé
        d0 = (0.50 - abs(a.x)) / (abs(h.x) - abs(a.x)) * (h - a).length
        d1 = (0.655 - abs(a.x)) / (abs(h.x) - abs(a.x)) * (h - a).length
        plaque(bm, ys_entre(d0, d1, 0.05), a, ax, (0, 1, 0), br, lambda th: 0.018, 0.009, 4, P_OS, (-1.05, -0.12), 0.006)
        plaque(bm, ys_entre(d0 + 0.01, d1 - 0.01, 0.05), a, ax, (0, 1, 0), br, lambda th: 0.018, 0.009, 4, P_OS, (0.12, 1.05), 0.006)
        for dd in ((d0 + d1) / 2,):
            plaque(bm, [dd + 0.008, dd - 0.008], a, ax, (0, 1, 0), br, lambda th: 0.028, 0.004, 7, P_FER, (-1.2, 1.2), 0.001)
        o_c = X.en_objet(bm, "canon")
        X.poids_de(o_c, "brassards", lambda p, s=s: (p.x > 0) == (s > 0), 1)
        parts.append(o_c)
        # dos de la main : plaque d'os (métacarpe) + rangée de phalanges
        bm = bmesh.new()
        hb = X.os_g("hand_" + cote)
        hx = Vector((s, 0, 0))
        plaque(bm, ys_entre(0.02, 0.075, 0.018), hb, hx, (0, 1, 0), gt, lambda th: 0.004, 0.007, 5, P_OS2, (-0.75, 0.75), 0.005)
        for k in range(3):
            plaque(bm, [0.085 + k * 0.022, 0.085 + k * 0.022 + 0.016], hb, hx, (0, 1, 0), gt, lambda th: 0.003, 0.006, 4, P_OS2, (-0.8, 0.8), 0.003)
        o_m = X.en_objet(bm, "main_os")
        X.poids_de(o_m, "gants", lambda p, s=s: (p.x > 0) == (s > 0), 0)
        parts.append(o_m)
    o = joindre(parts, "gants_os")

    def m_canon(P, N, bd):
        out = m_os(P, N, bd, 0.60, 331, stries=(1, 0, 0))
        s_ = np.abs(P[:, 0])
        m = runes(s_, np.clip((P[:, 1] - 1.405) / 0.014, -1.2, 1.2), 0.022, 13, 0.12) * (bd > 0.004)
        return gravure(out, m * (N[:, 1] > 0.5), 0.6)

    mat = dispatch({P_OS: m_canon, P_OS2: lambda P, N, bd: m_os(P, N, bd, 0.62, 333, stries=(1, 0, 0)),
                    P_CUIR2: lambda P, N, bd: m_cuir_noirci(P, N, bd, 0.44, 335), P_FER: lambda P, N, bd: m_fer_rouille(P, N, bd, 0.5, 337)},
                   lambda P, N, bd: m_cuir_noirci(P, N, bd, 0.36, 339))
    finir(o, mat, [("cuir", {P_COQUE, P_CUIR2}), ("os", {P_OS, P_OS2}), ("fer.rouille", {P_FER})], "gants_os", "mains", X.sol_paire_mains)

    # ------------------------------------------------------------------ bottes_os
    b = X.bottes_base("bottes_os", 480, 0.005)
    parts = [b]
    for cote in ("l", "r"):
        s = 1 if cote == "l" else -1
        parts.append(X.revers_botte("ro_" + cote, cote, 0.355, 0.425, 0.007, 0.007, 0.004, 10, P_CUIR2))
        f, ax, k = axe_tibia(cote)
        cible = L.bvh_de(["bottes", "pantalon"], noms_heros=["pantalon", "bottes"], filtre=lambda p, s=s: (p.x > 0) == (s > 0) and p.y < 0.65)
        bm = bmesh.new()
        # jambière : tibia d'os en deux lames qui se chevauchent + genouillère (rotule) ; sangles de fer rouillé
        y_ = lambda y: (y - f.y) / (k.y - f.y) * (k - f).length
        plaque(bm, ys_entre(y_(0.30), y_(0.47), 0.05), f, ax, (0, 0, 1), cible, lambda th: 0.017, 0.010, 5, P_OS, (-1.05, 1.05), 0.008)
        plaque(bm, ys_entre(y_(0.13), y_(0.32), 0.05), f, ax, (0, 0, 1), cible, lambda th: 0.012, 0.010, 5, P_OS, (-0.95, 0.95), 0.008)
        for yy in (0.20, 0.40):
            plaque(bm, [y_(yy) + 0.009, y_(yy) - 0.009], f, ax, (0, 0, 1), cible, lambda th: 0.028, 0.004, 6, P_FER, (-1.25, 1.25), 0.001)
        o_j = X.en_objet(bm, "jambiere")
        X.poids_de(o_j, "bottes", lambda p, s=s: (p.x > 0) == (s > 0), 1)
        parts.append(o_j)
    o = joindre(parts, "bottes_os")

    def m_tibia(P, N, bd):
        out = m_os(P, N, bd, 0.60, 341, stries=(0, 1, 0))
        m = runes(P[:, 1], np.clip((np.abs(P[:, 0]) - 0.11) / 0.012, -1.2, 1.2), 0.024, 17, 0.12) * (bd > 0.005) * (P[:, 2] > 0.02)
        return gravure(out, m, 0.6)

    mat = dispatch({P_OS: m_tibia, P_CUIR2: lambda P, N, bd: m_cuir_noirci(P, N, bd, 0.44, 343),
                    P_FER: lambda P, N, bd: m_fer_rouille(P, N, bd, 0.5, 345)}, lambda P, N, bd: m_cuir_noirci(P, N, bd, 0.36, 347))
    finir(o, mat, [("cuir", {P_COQUE, P_CUIR2}), ("os", {P_OS}), ("fer.rouille", {P_FER})], "bottes_os", "pieds", X.sol_paire_pieds)


# =============================================================================================================== VERRE
## Référence : conception_rpg/references/planche_armures_5.png, colonne « GLASS » (prime sur la charte pour formes et couleurs) :
## panneaux de cristal émeraude en couches, liserés et filets DORÉS, casque à crête effilée, écharpe de tissu clair, ceintures de cuir
## brun à boucle d'or, pan de tissu crème brodé, combinaison vert sombre, silhouette fine. Transparence : FAUX translucide peint
## (opaque : facettes en dégradé, veines claires, reflets internes du shader « profondeur », arêtes claires) -> aucun tri alpha.
VERT = L.hexa("#02100c", "#04201a", "#073026", "#0b4232", "#0f5640", "#146b4e", "#1b8260", "#25986f", "#3bb085", "#63cb9f", "#9be3c0", "#d2f7e4")
OR = L.hexa("#151009", "#241b0f", "#352816", "#4a391e", "#614b27", "#7a5f31", "#94753d", "#ad8c4c", "#c5a462", "#dabd7e", "#ead6a4")
VERT_SOMBRE = L.hexa("#060d09", "#09130d", "#0d1a12", "#122217", "#172b1e", "#1e3526", "#26402f")
CREME = L.hexa("#3e3a2e", "#5a5546", "#787160", "#938c77", "#aaa38c", "#bdb79f", "#cec9b2", "#dcd8c3")


def voronoi(P, c, g=0):
    """F1, F2 (m) et identifiant de cellule d'un Voronoï 3D à points tirés par case (taille c)."""
    q = P / c
    i0 = np.floor(q).astype(np.int64)
    f1 = np.full(len(P), 9.0)
    f2 = np.full(len(P), 9.0)
    idc = np.zeros(len(P), np.int64)
    fpm = np.zeros((len(P), 3))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                ix, iy, iz = i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz
                hsh = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (g * 2654435761)
                h1 = ((hsh * 1274126177) >> 7) & 0xffff
                h2 = ((hsh * 2246822519) >> 9) & 0xffff
                h3 = ((hsh * 3266489917) >> 11) & 0xffff
                fp = np.stack([ix + h1 / 65535.0, iy + h2 / 65535.0, iz + h3 / 65535.0], 1)
                d = np.linalg.norm(q - fp, axis=1)
                plus = d < f1
                f2 = np.where(plus, f1, np.minimum(f2, d))
                idc = np.where(plus, hsh, idc)
                fpm = np.where(plus[:, None], fp, fpm)
                f1 = np.where(plus, d, f1)
    return f1 * c, f2 * c, idc, fpm * c


def m_cristal(P, N, bd, g=0, base=0.44, c=0.075):
    """Cristal émeraude à faux translucide : facettes (Voronoï) de tons différents en dégradé, veines claires dont une part dorées,
    éclats internes, filet d'OR au bord, puis arête claire et liseré sombre (épaisseur du verre)."""
    f1, f2, idc, fp = voronoi(P, c, g)
    hc = ((idc * 2654435761) >> 13 & 0xffff) / 65535.0
    hd = ((idc * 40503) >> 5 & 0xffff) / 65535.0
    v = base + (hc - 0.5) * 0.34
    # dégradé dans la facette (plan incliné : direction pseudo-aléatoire par cellule)
    ang = hd * math.tau
    dirc = np.stack([np.cos(ang), np.sin(ang) * 0.8, np.sin(ang * 1.7)], 1)
    v += np.clip(((P - fp) * dirc).sum(1) / c, -0.6, 0.6) * 0.55       # facette : plan incliné, clair d'un côté, sombre de l'autre
    v += (L.fbm(P, 9.0, g + 3) - 0.5) * 0.12 + np.clip(N[:, 1], -1, 1) * 0.06
    # reflets internes : un second réseau de veines, plus large et plus doux, « sous » la surface (faux translucide)
    g1, g2, _, _ = voronoi(P + np.array([0.013, -0.021, 0.008]), c * 0.7, g + 31)
    v += np.clip(1.0 - (g2 - g1) / 0.006, 0, 1) * 0.10
    vein = f2 - f1
    clair = vein < 0.0024
    dore = clair & (hc > 2.0)       # plus de veines dorées (marbre) : l'or ne reste qu'en liserés fins
    v = np.where(clair & ~dore, v + 0.34, v)
    v -= np.clip(vein / 0.022, 0, 1) * 0.10          # coeurs plus sombres, facettes plus claires vers les arêtes
    v = np.where((vein >= 0.0024) & (vein < 0.006), v - 0.16, v)       # creux sombre le long des veines (taille) : plus de contraste
    rgb = L.rampe(VERT, np.clip(v, 0, 0.999))
    rgb[dore] = L.rampe(OR, np.clip(0.72 + (L.bruit(P[dore], 90.0, g + 4) - 0.5) * 0.3, 0, 0.999))
    ec = L.bruit(P, 330.0, g + 7) > 0.935
    rgb[ec] = rgb[ec] * 0.35 + np.array([0.80, 1.0, 0.92]) * 0.65
    a = np.clip(0.80 + (v - 0.5) * 0.3, 0.4, 1.0)
    # bord : filet d'or (4 mm : lisible au 480x270), arête claire, liseré sombre (épaisseur du verre)
    fo = bd < 0.0022
    rgb[fo] = L.rampe(OR, np.clip(0.74 + (L.bruit(P[fo], 120.0, g + 5) - 0.5) * 0.25 + N[fo, 1] * 0.06 - (bd[fo] < 0.0012) * 0.25, 0, 0.999))
    cl = (bd >= 0.0022) & (bd < 0.0068)
    rgb[cl] = rgb[cl] * 0.35 + np.array([0.62, 0.98, 0.85]) * 0.65     # arête claire fraîche (émission légère)
    so = (bd >= 0.0068) & (bd < 0.012)
    rgb[so] *= 0.70
    a = np.where(fo, 0.95, a)
    return rgba(rgb, a)


def m_or(P, N, bd, g=0, base=0.62):
    v = base + (L.fbm(P, 28.0, g) - 0.5) * 0.20 + np.clip(N[:, 1], -1, 1) * 0.10
    v = np.where(bd < 0.0018, v + 0.18, np.where(bd < 0.0035, v - 0.14, v))
    q = P * 160.0
    e = np.abs(np.sin(q[:, 0] + np.sin(q[:, 1] * 0.7) * 1.6) * np.cos(q[:, 1] * 0.9 + np.sin(q[:, 2]) * 1.2))
    v = np.where((e < 0.15) & (bd > 0.0045), v - 0.22, v)               # entrelacs gravés, sombres dans les creux
    return rgba(L.rampe(OR, np.clip(v, 0, 0.999)), np.clip(0.45 + v * 0.5, 0, 0.95))


def m_vert_sombre(P, N, bd, g=0):
    """Combinaison vert sombre (cuir souple / drap serré) : grain, plis lents, coutures sombres."""
    v = 0.48 + X.bruit_cuir(P, g) * 0.9 + (L.fbm(P * np.array([1, 3.0, 1]), 4.0, g + 2) - 0.5) * 0.16 + np.clip(N[:, 1], -1, 1) * 0.05
    v = X.coutures(P, bd, v, 0.005, 0.009)
    return rgba(L.rampe(VERT_SOMBRE, np.clip(v, 0, 0.999)), np.clip(0.10 + v * 0.25, 0.04, 0.35))


def m_cuir_brun(P, N, bd, g=0, base=0.50):
    out = X.mat_cuir(P, N, None, bd, base, X.CUIR, g)
    # rivets dorés réguliers le long de la ceinture (une rangée au milieu)
    return out


def m_tissu_creme(P, N, bd, g=0, broderie=None, plis=None):
    v = 0.55 + (L.fbm(P, 12.0, g) - 0.5) * 0.14 + (L.bruit(P * np.array([1, 4, 1]), 140.0, g + 1) - 0.5) * 0.07
    if plis is not None:
        v += np.sin(P @ np.asarray(plis, float) * 1.0 + L.fbm(P, 6.0, g + 2) * 4.0) * 0.08
    v += np.clip(N[:, 1], -1, 1) * 0.05
    v = np.where(bd < 0.0035, v - 0.12, v)     # bord effiloché sombre
    rgb = L.rampe(CREME, np.clip(v, 0, 0.999))
    if broderie is not None:
        rgb = rgb * (1 - broderie[:, None]) + np.array([0.52, 0.78, 0.60]) * broderie[:, None]
    return rgba(rgb, 0.08)


def entrelacs_vertical(x, y, larg, g=0):
    """Broderie : tresse nordique verticale (deux brins sinueux croisés + anneaux) et filets latéraux, x en travers (m), y le long."""
    A = larg * 0.32
    f = 2 * math.pi / (larg * 1.25)
    w = larg * 0.055
    b1 = np.abs(x - A * np.sin(y * f)) < w
    b2 = np.abs(x + A * np.sin(y * f)) < w
    # au croisement, un brin passe dessus (alternance) : petite coupure de l'autre
    crois = np.abs(np.sin(y * f)) < 0.18
    dessus = np.mod(np.floor(y * f / math.pi), 2) == 0
    b2 = b2 & ~(crois & dessus)
    b1 = b1 & ~(crois & ~dessus)
    fil = np.abs(np.abs(x) - larg * 0.80) < w * 0.6
    return (b1 | b2 | fil).astype(float)


def plaque2(bm, c, axe, ref, cible, ys, arc, n, ep, jeu, partie, dy=None, taper=None, bombe=0.004, biseau=0.55, rmax=0.40, lisse=2, arete=None):
    """Plaque de cristal ÉPAISSE qui suit le corps, de forme libre : sections aux abscisses `ys` le long de `axe` depuis `c`, arc
    (t0, t1) ; dy(u) décale la section en hauteur selon u = position dans l'arc (-1..1) -> pointe en V, biais ; taper(v) (v = 0..1 le
    long de la plaque) rétrécit l'arc -> éclat effilé. Rangées : dessous haut, dessus (biseaux aux bouts), dessous bas ; côtés fermés."""
    axe = Vector(axe).normalized()
    ref = Vector(ref)
    ref = (ref - axe * axe.dot(ref)).normalized()
    ref2 = axe.cross(ref)
    c = Vector(c)
    part = L.couche_partie(bm)
    k = len(ys)
    a0, a1 = arc
    mid, demi = (a0 + a1) / 2, (a1 - a0) / 2

    # rayons mesurés sur une grille (sections x colonnes), puis LISSÉS : surface de plaque nette, sans bosses du corps dessous
    grille = []
    for i in range(k):
        v = i / max(k - 1, 1)
        tp = taper(v) if taper else 1.0
        rang_ = []
        for j in range(n + 1):
            u = -1 + 2 * j / n
            th = mid + u * demi * tp
            yy = ys[i] + (dy(u) if dy else 0.0)
            d = ref * math.cos(th) + ref2 * math.sin(th)
            cc = c + axe * yy
            hit = cible.ray_cast(B(cc + d * rmax), B(-d), rmax)
            r = (hit[0] - B(cc)).length if hit[0] is not None else None
            rang_.append([cc, d, r, u, v])
        grille.append(rang_)
    connus = [e[2] for l in grille for e in l if e[2] is not None]
    defaut = sum(connus) / len(connus) if connus else rmax * 0.3
    R = np.array([[e[2] if e[2] is not None else defaut for e in l] for l in grille])
    for _ in range(lisse):
        R2 = R.copy()
        R2[:, 1:-1] = np.maximum(R[:, 1:-1], (R[:, :-2] + R[:, 1:-1] * 2 + R[:, 2:]) / 4)
        if k > 2:
            R2[1:-1, :] = np.maximum(R2[1:-1, :] * 0.5 + (R2[:-2, :] + R2[2:, :]) * 0.25, R2[1:-1, :] * 0.985)
        R = R2
    lignes = []
    rang = [(0, 0.0008)] + [(i, None) for i in range(k)] + [(k - 1, 0.0008)]
    for (i, dr0) in rang:
        ligne = []
        for j in range(n + 1):
            cc, d, _, u, v = grille[i][j]
            j_ = jeu(u) if callable(jeu) else jeu
            if dr0 is None:
                e = ep * (biseau if i in (0, k - 1) else 1.0)
                w = 1 - (2 * v - 1) ** 2
                ar = arete if arete is not None else (partie == P_VERRE)
                prof = max(0.0, 1 - abs(u)) if ar else max(0.0, 1 - u * u)      # cristal : arête vive au milieu, pans plats
                dr = j_ + e + bombe * prof * ((0.25 + 0.75 * min(1.0, 2.5 * min(v, 1 - v) + 0.2)) if ar else (0.4 + 0.6 * w))
            else:
                dr = j_ + dr0
            ligne.append(bm.verts.new(B(cc + d * (R[i, j] + dr))))
        lignes.append(ligne)
    faces = []
    for r in range(len(lignes) - 1):
        A, Bv = lignes[r], lignes[r + 1]
        for j in range(n):
            f = bm.faces.new((A[j], A[j + 1], Bv[j + 1], Bv[j]))
            f[part] = partie
            faces.append(f)
    for j in (0, n):
        try:
            f = bm.faces.new([l[j] for l in lignes])
            f[part] = partie
            faces.append(f)
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=list({v for f in faces for v in f.verts}), dist=0.0004)
    faces = [f for f in faces if f.is_valid]
    X.orienter(bm, faces, c + axe * ys[0], c + axe * ys[-1])
    return faces


def eclat(bm, base, direction, longueur, larg, partie, tour=0.0):
    """Éclat de cristal (pyramide à 4 pans, base losange) qui SORT de l'armure : base posée sous la surface, pointe dehors."""
    part = L.couche_partie(bm)
    d = Vector(direction).normalized()
    t1 = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
    t2 = d.cross(t1)
    t1, t2 = t1 * math.cos(tour) + t2 * math.sin(tour), -t1 * math.sin(tour) + t2 * math.cos(tour)
    b = Vector(base) - d * 0.006
    coins = [bm.verts.new(B(b + t1 * larg)), bm.verts.new(B(b + t2 * larg * 0.55)), bm.verts.new(B(b - t1 * larg)), bm.verts.new(B(b - t2 * larg * 0.55))]
    pt = bm.verts.new(B(b + d * longueur))
    fs = [bm.faces.new((coins[i], coins[(i + 1) % 4], pt)) for i in range(4)]
    for f in fs:
        f[part] = partie
    bm.normal_update()
    cen = Vector(base) + d * longueur * 0.3
    for f in fs:
        if (G(f.calc_center_median()) - cen).dot(G(f.normal)) < 0:
            f.normal_flip()
    return fs


def lame(bm, cibles, sg, th0, th1, ph0, ph1, w, gap, jeu_fn, n=8, ep=0.004, deborde=0.35):
    """Lame cristalline plate et fine couchée sur le heaume : chemin sur la sphère du crâne de (th0, ph0) à (th1, ph1) (degrés,
    th 0 = devant, côté sg), rayon = coque + jeu_fn + gap ; la pointe dépasse (deborde : fraction de plus) et se relève ; largeur en
    feuille (base étroite, ventre, pointe) ; section : arête médiane, dessous plat, tranches."""
    part = L.couche_partie(bm)
    rangs = []
    for i in range(n + 1):
        t = i / n * (1 + deborde)
        th = math.radians(th0 + (th1 - th0) * min(t, 1.0) + (th1 - th0) * 0.25 * max(0.0, t - 1.0)) * sg
        ph = math.radians(ph0 + (ph1 - ph0) * min(t, 1.0) + 6.0 * max(0.0, t - 1.0))
        d = Vector((math.sin(th) * math.cos(ph), math.sin(ph), math.cos(th) * math.cos(ph)))
        hit = cibles.ray_cast(B(TETE + d * 0.45), B(-d), 0.45)
        r = (B(TETE) - hit[0]).length if hit[0] is not None else 0.11
        r += jeu_fn(th, ph) + gap + 0.12 * max(0.0, t - 0.7) ** 1.3
        rangs.append((TETE + d * r, d))
    for i in range(len(rangs)):
        p, d = rangs[i]
        q = rangs[min(i + 1, n)][0] - rangs[max(i - 1, 0)][0]
        tr = d.cross(q).normalized()
        u = i / n
        larg = w * (0.35 + 0.65 * math.sin(min(1.0, u * 1.25) * math.pi * 0.5) ** 0.6) * (1 - u) ** 0.8 + 0.0008
        rangs[i] = (p, d, tr, larg)
    lignes = []
    for (p, d, tr, larg) in rangs:
        lignes.append([bm.verts.new(B(p + tr * larg)), bm.verts.new(B(p + d * 0.0025)), bm.verts.new(B(p - tr * larg)),
                       bm.verts.new(B(p - tr * larg - d * ep)), bm.verts.new(B(p + tr * larg - d * ep))])
    fs = []
    for i in range(n):
        A, Bv = lignes[i], lignes[i + 1]
        for j in range(5):
            fs.append(bm.faces.new((A[j], A[(j + 1) % 5], Bv[(j + 1) % 5], Bv[j])))
    fs.append(bm.faces.new(list(reversed(lignes[0]))))
    fs.append(bm.faces.new(lignes[-1]))
    for f in fs:
        f[part] = P_VERRE
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    return fs


def poids_moyens_cuisses(o, haut=0.93, bas=0.80):
    """Pan central (devant / derrière) : poids = moyenne des deux cuisses (pantalon), fondus vers la cotte au-dessus des hanches."""
    pl = L.poids_proches(o, bpy.data.objects["pantalon"], 3, lambda p: p.x > 0.02 and p.y > 0.4)
    pr = L.poids_proches(o, bpy.data.objects["pantalon"], 3, lambda p: p.x < -0.02 and p.y > 0.4)
    pt = L.poids_proches(o, bpy.data.objects["tunique"], 4, lambda p: abs(p.x) < 0.3)
    res = []
    for v, a, b, t in zip(o.data.vertices, pl, pr, pt):
        y = G(v.co).y
        k = min(1.0, max(0.0, (haut - y) / (haut - bas)))
        d = {}
        for src, w in ((a, 0.5 * k), (b, 0.5 * k), (t, 1 - k)):
            for nom, x in src.items():
                d[nom] = d.get(nom, 0.0) + x * w
        res.append(d)
    L.ecrire_poids(o, L.normaliser(res))


COU_Z = 0.0


def pelerine(base, nom, y_bas, decal):
    """Pèlerine de l'écharpe : copie des faces hautes de la coque (épaules, haut du dos et de la poitrine), poussée de `decal`, bord
    bas ondulé, tranche épaissie ; poids de la coque (mêmes sommets)."""
    me = base.data.copy()
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    for vg in base.vertex_groups:
        if o.vertex_groups.get(vg.name) is None:
            o.vertex_groups.new(name=vg.name)
    bm = bmesh.new()
    bm.from_mesh(me)
    suppr = [f for f in bm.faces if G(f.calc_center_median()).y < y_bas or abs(G(f.calc_center_median()).x) > 0.215
             or G(f.calc_center_median()).y > 1.53]
    bmesh.ops.delete(bm, geom=suppr, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.normal_update()
    part = L.couche_partie(bm)
    for f in bm.faces:
        f[part] = P_TISSU
    for v in bm.verts:
        v.co = v.co + v.normal * decal
    bm.to_mesh(me)
    bm.free()
    L.decimer(o, 200)
    bm = bmesh.new()
    bm.from_mesh(me)
    for v in [v for v in bm.verts if v.is_boundary and G(v.co).y < y_bas + 0.05]:
        g = G(v.co)
        a = math.atan2(g.x, g.z)
        v.co = v.co + B(0, -0.012 - 0.018 * (0.5 + 0.5 * math.sin(a * 4.0 + 0.7)), 0)
    X.epaissir_bords(bm, 0.010)
    bm.to_mesh(me)
    bm.free()
    L.ecrire_poids(o, L.normaliser(L.poids_proches(o, base, 3)))
    return o


def verre():
    up = (0, 1, 0)
    O = Vector((0, 0, 0))
    # ------------------------------------------------------------------ cuirasse_verre
    base = X.torse_base("cuirasse_verre", 350, jeu=0.010)
    L.lisser_normales(base)
    cible = cible_de(base)
    bm = bmesh.new()
    # plastron en V : pectoraux (bas en pointe vers le centre), plaque centrale en pointe sous le sternum
    for s in (1, -1):
        arc = (0.12, 1.05) if s > 0 else (-1.05, -0.12)
        plaque2(bm, O, up, (0, 0, 1), cible, ys_entre(1.47, 1.30, 0.045), arc, 6, 0.008, 0.003, P_VERRE,
                dy=lambda u, s=s: -0.05 * (1 - (u * s + 1) / 2) ** 1.4, bombe=0.006)
        # flanc : deuxième couche, sous le bras
        plaque2(bm, O, up, (0, 0, 1), cible, ys_entre(1.30, 1.12, 0.06), (0.75, 1.45) if s > 0 else (-1.45, -0.75), 4, 0.007, 0.002, P_VERRE,
                taper=lambda v: 1.0 - 0.45 * v, bombe=0.004)
    plaque2(bm, O, up, (0, 0, 1), cible, ys_entre(1.42, 1.13, 0.05), (-0.30, 0.30), 4, 0.010, 0.009, P_VERRE,
            taper=lambda v: 1.0 - 0.85 * v ** 1.5, bombe=0.008)
    # ventre : deux lames en recouvrement sous le V
    for i, (yh, yb) in enumerate([(1.22, 1.11), (1.13, 1.03)]):
        plaque2(bm, O, up, (0, 0, 1), cible, ys_entre(yh, yb, 0.05), (-0.95, 0.95), 7, 0.007, 0.002 + 0.004 * (1 - i), P_VERRE,
                dy=lambda u: -0.02 * (1 - abs(u)), bombe=0.004)
    # dos : deux plaques d'omoplate et une lame lombaire
    for s in (1, -1):
        plaque2(bm, O, up, (0, 0, -1), cible, ys_entre(1.46, 1.24, 0.07), (0.12, 0.90) if s > 0 else (-0.90, -0.12), 4, 0.007, 0.003, P_VERRE,
                dy=lambda u, s=s: -0.035 * (1 - (u * s + 1) / 2), bombe=0.005)
    plaque2(bm, O, up, (0, 0, -1), cible, ys_entre(1.20, 1.06, 0.07), (-0.85, 0.85), 6, 0.007, 0.003, P_VERRE, dy=lambda u: -0.025 * (1 - abs(u)))
    # quille d'or au milieu de la poitrine + incrustation de runes niellées
    plaque2(bm, O, up, (0, 0, 1), cible, ys_entre(1.46, 1.20, 0.065), (-0.075, 0.075), 2, 0.005, 0.0195, P_OR, bombe=0.002)
    plaque2(bm, O, up, (0, 0, 1), cible, ys_entre(1.445, 1.215, 0.0575), (-0.045, 0.045), 1, 0.0015, 0.0248, P_RUNES, bombe=0.002)
    o_pl = en_objet_poids(bm, "plaques_v", "tunique", lambda p: abs(p.x) < 0.3, 1)
    # tassettes : six panneaux de cristal pointus en deux couches autour des hanches (poids repris de la jupe de la cotte)
    bm = bmesh.new()
    for i, (c0, larg, yh, yb, j) in enumerate([(0.60, 0.25, 0.97, 0.52, 0.006), (-0.60, 0.25, 0.97, 0.52, 0.006), (1.10, 0.28, 0.96, 0.54, 0.006),
                                               (-1.10, 0.28, 0.96, 0.54, 0.006), (1.65, 0.30, 0.95, 0.54, 0.006), (-1.65, 0.30, 0.95, 0.54, 0.006),
                                               (2.35, 0.34, 0.95, 0.54, 0.006), (-2.35, 0.34, 0.95, 0.54, 0.006), (3.0, 0.34, 0.95, 0.56, 0.006),
                                               (0.85, 0.20, 0.92, 0.62, 0.015), (-0.85, 0.20, 0.92, 0.62, 0.015), (1.40, 0.22, 0.92, 0.62, 0.015),
                                               (-1.40, 0.22, 0.92, 0.62, 0.015)]):
        plaque2(bm, O, up, (0, 0, 1), cible, ys_entre(yh, yb, 0.075), (c0 - larg, c0 + larg), 3 if j < 0.01 else 2, 0.006, j, P_VERRE,
                taper=lambda v: 1.0 - 0.88 * v ** 1.8, bombe=0.004, rmax=0.5)
    o_tas = X.en_objet(bm, "tassettes")
    X.poids_de(o_tas, "cuirasse_verre", None, 1)
    # pan de tissu crème brodé devant (moyenne des cuisses) et écharpe claire au cou
    bm = bmesh.new()
    plaque2(bm, O, up, (0, 0, 1), cible, ys_entre(0.975, 0.50, 0.05), (-0.32, 0.32), 3, 0.003, 0.028, P_TISSU,
            dy=lambda u: 0.0, taper=lambda v: 1.0 - 0.10 * v, bombe=0.002, rmax=0.5)
    o_pan = X.en_objet(bm, "pan")
    poids_moyens_cuisses(o_pan)
    # ceintures de cuir brun : une droite à la taille, une en biais sur les hanches ; boucle ronde dorée ; baudrier en travers
    bel = X.ceinture("ceint_v", 0.955, 1.005, 0.009, 20)
    tb = L.bvh_de(["tunique"], filtre=lambda p: abs(p.x) < 0.3)
    bm = bmesh.new()
    plaque2(bm, O, up, (0, 0, 1), tb, [0.925, 0.895], (-math.pi + 0.02, math.pi - 0.02), 20, 0.007, 0.024, P_CUIR2,
            dy=lambda u: -0.035 * u, bombe=0.0, biseau=1.0, rmax=0.5)
    o_bel2 = X.en_objet(bm, "ceint2")
    X.poids_de(o_bel2, "cuirasse_verre", None, 1)
    bm = bmesh.new()
    plaque2(bm, O, up, (0, 0, 1), tb, ys_entre(1.012, 0.948, 0.032), (-0.13, 0.13), 4, 0.006, 0.020, P_OR, taper=lambda v: 0.75 + 0.25 * math.sin(v * math.pi), bombe=0.006)
    plaque2(bm, O, up, (0, 0, 1), cible, [1.395, 1.365], (-0.95, 0.55), 10, 0.004, 0.0185, P_CUIR2, dy=lambda u: 0.10 * u, biseau=1.0)
    plaque2(bm, O, up, (0, 0, 1), cible, ys_entre(1.462, 1.432, 0.03), (-0.52, -0.38), 3, 0.005, 0.0245, P_OR, bombe=0.004)
    o_bou = en_objet_poids(bm, "boucle_v", "tunique", lambda p: abs(p.x) < 0.3, 1)
    # épaulières (planche GLASS) : trois lames de cristal plates en tuiles (la plus haute par-dessus), facettes nettes, et trois
    # éclats qui sortent vers le haut et l'extérieur ; mesurées : pas de « sac » rond
    eps = []
    for cote in ("l", "r"):
        s = 1 if cote == "l" else -1
        a, axb, _ = X.axe_bras(cote)
        c_ep = Vector((s * 0.10, a.y, a.z))
        cb = L.bvh_de(["tunique", "SuperHero_Male"], filtre=lambda p: abs(p.x) > 0.10)
        bm = bmesh.new()
        for (y0, y1, jeu_, arc) in [(0.17, 0.27, 0.020, (-1.15, 1.00)), (0.10, 0.21, 0.027, (-1.25, 1.10)), (0.03, 0.14, 0.034, (-1.30, 1.15)), (0.22, 0.31, 0.030, (-1.9, 1.9)), (0.28, 0.37, 0.026, (-2.0, 2.0))]:
            plaque2(bm, c_ep, Vector((s, 0, 0)), (0, 1, 0), cb, ys_entre(y0, y1, 0.05), arc, 2, 0.006, jeu_, P_VERRE,
                    taper=lambda v: 1.0 - 0.45 * v, dy=None, bombe=0.006, lisse=4)
        for (x, d, lg, la) in [(0.17, (0.30, 1.0, -0.10), 0.150, 0.024), (0.25, (0.75, 0.75, 0.05), 0.115, 0.020), (0.12, (0.05, 1.0, -0.45), 0.090, 0.017), (0.21, (0.50, 0.9, -0.40), 0.080, 0.015)]:
            top = Vector((s * x, a.y + 0.4, a.z))
            hit = cb.ray_cast(B(top), B(Vector((0, -1, 0))), 0.5)
            ytop = G(hit[0]).y if hit[0] is not None else a.y + 0.08
            eclat(bm, Vector((s * x, ytop + 0.030, a.z - 0.005)), (s * d[0], d[1], d[2]), lg, la, P_VERRE)
        o_e = X.en_objet(bm, "epv_" + cote)
        X.poids_de(o_e, "tunique", lambda p, s=s: abs(p.x) > 0.12 and (p.x > 0) == (s > 0), 1)
        eps.append(o_e)
    # écharpe crème bien visible : col épais enroulé + pèlerine courte sur les épaules et le haut du dos
    col = X.col_montant("col_v", 1.45, 1.61, 0.016, 16, 0.020, 0.62)
    attr = col.data.attributes.get("partie")
    for p in col.data.polygons:
        attr.data[p.index].value = P_TISSU
    # un pan fin qui retombe sur la poitrine depuis l'épaule gauche, bout effilé
    bm = bmesh.new()
    plaque2(bm, O, up, (0, 0, 1), cible, ys_entre(1.55, 1.20, 0.05), (0.52, 0.62), 3, 0.004, 0.034, P_TISSU,
            dy=lambda u: 0.0, taper=lambda v: 1.0 - 0.55 * v, bombe=0.002, rmax=0.5)
    o_pan2 = X.en_objet(bm, "pan_echarpe")
    X.poids_de(o_pan2, "tunique", lambda p: abs(p.x) < 0.3, 1)
    col = joindre([col, o_pan2], "echarpe")
    o = joindre([base, o_pl, o_tas, o_pan, bel, o_bel2, o_bou, col] + eps, "cuirasse_verre")

    def m_runes_st(P, N, bd):
        m = runes(P[:, 1], np.clip(P[:, 0] / 0.0085, -1.2, 1.2), 0.016, 21, 0.13)
        return m_runes(P, N, bd, m, (0.62, 0.95, 0.66))

    def m_pan(P, N, bd):
        return m_tissu_creme(P, N, bd, 355, entrelacs_vertical(P[:, 0], P[:, 1], 0.075), plis=(0, 0, 0))

    def m_echarpe(P, N, bd):
        return m_tissu_creme(P, N, bd, 357, None, plis=(0, 140.0, 40.0))

    def m_tissu(P, N, bd):
        out = m_echarpe(P, N, bd)
        pan = P[:, 1] < 1.15
        if pan.any():
            out[pan] = m_pan(P[pan], N[pan], bd[pan])
        return out

    mat = dispatch({P_VERRE: lambda P, N, bd: m_cristal(P, N, bd, 351), P_OR: lambda P, N, bd: m_or(P, N, bd, 353),
                    P_RUNES: m_runes_st, P_TISSU: m_tissu, P_CUIR2: lambda P, N, bd: m_cuir_brun(P, N, bd, 359, 0.52),
                    1: lambda P, N, bd: m_cuir_brun(P, N, bd, 361, 0.50)},
                   lambda P, N, bd: m_vert_sombre(P, N, bd, 363))
    finir(o, mat, [("cuir.vert", {P_COQUE, 3}), ("verre", {P_VERRE}), ("or", {P_OR}), ("cuir", {P_CUIR2, 1}), ("tissu", {P_TISSU}), ("runes", {P_RUNES})],
          "cuirasse_verre", "torse", X.sol_torse)

    # ------------------------------------------------------------------ casque_verre
    cibles = L.bvh_de(["SuperHero_Male"], noms_heros=["peau"], filtre=lambda p: p.y > 1.50 and abs(p.x) < 0.2)

    def ouvert(th, ph):
        t = abs(math.atan2(math.sin(th), math.cos(th)))
        return not (t < math.radians(28) and ph < math.radians(12))

    def jeu_heaume(th, ph):
        t = abs(math.atan2(math.sin(th), math.cos(th)))
        arriere = max(0.0, -math.cos(th))
        # profil effilé vers l'arrière (bosse en pointe derrière le crâne), front qui avance au-dessus du visage (ombre)
        pointe = 0.125 * arriere ** 5 * max(0.0, 1 - abs(ph - 0.22) / 0.60)       # longue pointe de capuche vers l'arrière
        sommet = 0.060 * max(0.0, (ph - 0.95) / 0.62) ** 1.6                      # le dessus monte en pointe (profil en goutte)
        visiere = 0.014 * max(0.0, math.cos(th)) ** 3 * max(0.0, 1 - abs(ph - 0.30) / 0.25)
        joue = 0.010 * min(1.0, max(0.0, (t - 0.35) / 0.5)) * (1.0 if ph < 0.2 else 0.0)       # joues : volume vers l'extérieur
        evase = 0.020 * min(1.0, max(0.0, -ph / 0.5))                                         # bas du heaume évasé (pas d'anneau dans la peau)
        return 0.017 + pointe + sommet + visiere + joue + evase
    # heaume-capuche de cristal : enveloppe le crâne, les joues et la nuque ; visage dans l'ombre
    bm = X.coque_tete("casque_verre", [90, 72, 56, 42, 30, 18, 8, -4, -16, -28], 24, jeu_heaume, ouvert, cibles, P_VERRE)
    X.epaissir_bords(bm, 0.008)
    o_dome = X.en_objet(bm, "dome_v")
    # doublure presque noire dans l'ouverture : le visage reste dans l'ombre du heaume
    def ouvert_large(th, ph):
        t = abs(math.atan2(math.sin(th), math.cos(th)))
        return not (t < math.radians(36) and ph < math.radians(16))
    # la doublure avance de ~3 cm devant le visage : vue de face, la peau ne se voit plus (visage dans l'ombre)
    bm = X.coque_tete("doublure", [26, 14, 2, -10, -22, -34], 14, lambda th, ph: 0.007 + 0.024 * max(0.0, math.cos(th)) ** 2, ouvert_large, cibles, P_COQUE)
    o_dbl_ = None
    o_dbl = X.en_objet(bm, "doublure")
    # bandeau d'or frontal + runes (variante enchantée)
    bm = bmesh.new()
    yb = TETE.y + 0.03
    for (h, jeu_, ep, part) in [(0.010, 0.0285, 0.004, P_OR), (0.0055, 0.0328, 0.0012, P_RUNES)]:
        c0, c1 = Vector((0, yb + h, TETE.z)), Vector((0, yb - h, TETE.z))
        f0 = L.rayon_sur(cibles, c0, (0, 1, 0), (0, 0, 1), jeu_)
        f1 = L.rayon_sur(cibles, c1, (0, 1, 0), (0, 0, 1), jeu_)
        X.bande(bm, [(c0, (0, 1, 0), (0, 0, 1)), (c1, (0, 1, 0), (0, 0, 1))], [f0, f1], ep, 14, part, arc=(-1.30, 1.30))
    o_band = X.en_objet(bm, "bandeau_v")
    # plaques en écailles qui se chevauchent du front vers l'arrière : trois rangées de lames par côté
    bm = bmesh.new()
    for sg in (1, -1):
        for (th0, th1, ph0, ph1, w, gap) in [(24, 172, 62, 46, 0.034, 0.012), (28, 170, 44, 26, 0.036, 0.015), (32, 166, 26, 8, 0.036, 0.018)]:
            lame(bm, cibles, sg, th0, th1, ph0, ph1, w, gap, jeu_heaume, n=6, deborde=0.2)
    o_cre = X.en_objet(bm, "feuilles_v")
    o_jou = None
    o = joindre([o_dome, o_dbl, o_band, o_cre], "casque_verre")
    X.tete_rigide(o)

    def m_runes_cas(P, N, bd):
        s_, ax, _ = anneau_st(P, TETE, (0, 1, 0), (0, 0, 1), 0.12)
        m = runes(s_, np.clip((ax - 0.03) / 0.006, -1.2, 1.2), 0.013, 23, 0.13)
        return m_runes(P, N, bd, m, (0.62, 0.95, 0.66))

    mat = dispatch({P_VERRE: lambda P, N, bd: m_cristal(P, N, bd, 371, 0.46, 0.055), P_OR: lambda P, N, bd: m_or(P, N, bd, 373), P_RUNES: m_runes_cas},
                   lambda P, N, bd: m_vert_sombre(P, N, bd, 375) * np.array([0.10, 0.10, 0.10, 1.0]))
    finir(o, mat, [("verre", {P_VERRE}), ("cuir.vert", {P_COQUE}), ("or", {P_OR}), ("runes", {P_RUNES})], "casque_verre", "tete", X.sol_tete)

    # ------------------------------------------------------------------ gantelets_verre
    g = X.gants_base("gantelets_verre", 420, 0.004)
    parts = [g]
    br = L.bvh_de(["tunique", "gants"], noms_heros=["brassards", "tunique"], filtre=lambda p: abs(p.x) > 0.45)
    gt = L.bvh_de(["gants"])
    for cote in ("l", "r"):
        s = 1 if cote == "l" else -1
        a, ax, h = axe_avantbras(cote)
        lg = (h - a).length
        d = lambda x: (x - abs(a.x)) / (abs(h.x) - abs(a.x)) * lg
        bm = bmesh.new()
        # manche vert sombre (tube) jusqu'au poignet
        ys = ys_entre(d(0.50), d(0.665), 0.08)
        fs = [L.rayon_sur(br, a + ax * y, ax, (0, 1, 0), 0.008) for y in ys]
        cs = [(a + ax * ys[0], ax, (0, 1, 0))] + [(a + ax * y, ax, (0, 1, 0)) for y in ys] + [(a + ax * ys[-1], ax, (0, 1, 0))]
        rs = [lambda t, f=fs[0]: f(t) + 0.0008] + [lambda t, f=f: f(t) + 0.004 for f in fs] + [lambda t, f=fs[-1]: f(t) + 0.0008]
        avant = set(bm.faces)
        L.anneau(bm, cs, rs, 10, P_COQUE)
        X.orienter(bm, [f for f in bm.faces if f not in avant], a + ax * ys[0], a + ax * ys[-1])
        # canon de cristal : grande lame effilée vers le coude (pointe qui dépasse) + lame intérieure
        plaque2(bm, a, ax, (0, 1, 0), br, ys_entre(d(0.645), d(0.47), 0.045), (-1.25, 1.25), 6, 0.008, 0.013, P_VERRE,
                taper=lambda v: 1.0 - 0.85 * v ** 1.8, bombe=0.008)
        plaque2(bm, a, ax, (0, 1, 0), br, ys_entre(d(0.64), d(0.53), 0.055), (1.9, 3.0), 3, 0.006, 0.011, P_VERRE,
                taper=lambda v: 1.0 - 0.7 * v, bombe=0.004)
        plaque2(bm, a, ax, (0, 1, 0), br, ys_entre(d(0.60), d(0.50), 0.045), (-1.9, 1.9), 3, 0.006, 0.020, P_VERRE,
                taper=lambda v: 1.0 - 0.6 * v, bombe=0.005)
        # lame de coude qui dépasse vers l'arrière et l'extérieur
        eclat(bm, a + Vector((0, 0.012, -0.040)), (s * 0.30, 0.30, -1.0), 0.125, 0.024, P_VERRE)
        # bracelet d'or au poignet + runes
        for (jeu_, ep, part, hh) in [(0.0125, 0.004, P_OR, 0.011), (0.0168, 0.0012, P_RUNES, 0.0065)]:
            plaque(bm, [d(0.655) + hh, d(0.655) - hh], a, ax, (0, 1, 0), br, lambda th, j=jeu_: j, ep, 8, part, (-math.pi + 0.01, math.pi - 0.01), 0.0005, 1.0)
        o_c = X.en_objet(bm, "canon_v")
        X.poids_de(o_c, "brassards", lambda p, s=s: (p.x > 0) == (s > 0), 1)
        parts.append(o_c)
        bm = bmesh.new()
        hb = X.os_g("hand_" + cote)
        plaque2(bm, hb, Vector((s, 0, 0)), (0, 1, 0), gt, ys_entre(0.015, 0.085, 0.035), (-0.85, 0.85), 4, 0.006, 0.003, P_VERRE,
                taper=lambda v: 1.0 - 0.55 * v, bombe=0.005)
        o_m = X.en_objet(bm, "main_v")
        X.poids_de(o_m, "gants", lambda p, s=s: (p.x > 0) == (s > 0), 0)
        parts.append(o_m)
    o = joindre(parts, "gantelets_verre")
    AX = {c: axe_avantbras(c) for c in ("l", "r")}

    def m_runes_g(P, N, bd):
        out = np.zeros((len(P), 4))
        for c, sg in (("l", 1), ("r", -1)):
            m_ = (P[:, 0] > 0) == (sg > 0)
            if not m_.any():
                continue
            a, ax, h = AX[c]
            dc = (0.655 - abs(a.x)) / (abs(h.x) - abs(a.x)) * (h - a).length
            s_, t_, _ = anneau_st(P[m_], a, ax, (0, 1, 0), 0.045)
            mk = runes(s_, np.clip((t_ - dc) / 0.006, -1.2, 1.2), 0.012, 25 + sg, 0.13)
            out[m_] = m_runes(P[m_], N[m_], bd[m_], mk, (0.62, 0.95, 0.66))
        return out

    mat = dispatch({P_VERRE: lambda P, N, bd: m_cristal(P, N, bd, 381, 0.46, 0.05), P_OR: lambda P, N, bd: m_or(P, N, bd, 383),
                    P_RUNES: m_runes_g}, lambda P, N, bd: np.where((np.abs(P[:, 0]) > 0.68)[:, None], m_cuir_brun(P, N, bd, 385, 0.46), m_vert_sombre(P, N, bd, 387)))
    finir(o, mat, [("cuir", {P_COQUE}), ("verre", {P_VERRE}), ("or", {P_OR}), ("runes", {P_RUNES})], "gantelets_verre", "mains", X.sol_paire_mains)

    # ------------------------------------------------------------------ bottes_verre
    b = X.bottes_base("bottes_verre", 470, 0.005)
    parts = [b]
    for cote in ("l", "r"):
        s = 1 if cote == "l" else -1
        f, ax, k = axe_tibia(cote)
        lg = (k - f).length
        y_ = lambda y: (y - f.y) / (k.y - f.y) * lg
        cible = L.bvh_de(["bottes", "pantalon"], noms_heros=["pantalon", "bottes"], filtre=lambda p, s=s: (p.x > 0) == (s > 0) and p.y < 0.65)
        bm = bmesh.new()
        # bandeau d'or + runes au haut de la tige
        for (jeu_, ep, part, hh) in [(0.0075, 0.004, P_OR, 0.012), (0.0118, 0.0012, P_RUNES, 0.007)]:
            plaque(bm, [y_(0.385) + hh, y_(0.385) - hh], f, ax, (0, 0, 1), cible, lambda th, j=jeu_: j, ep, 10, part, (-math.pi + 0.01, math.pi - 0.01), 0.0005, 1.0)
        # grève de cristal (pointe vers le genou) + genouillère en losange qui déborde + plaque du cou-de-pied
        plaque2(bm, f, ax, (0, 0, 1), cible, ys_entre(y_(0.13), y_(0.44), 0.06), (-1.45, 1.45), 6, 0.008, 0.012, P_VERRE,
                taper=lambda v: 1.0 - 0.80 * max(0.0, v - 0.35) ** 1.2 / 0.65 ** 1.2, bombe=0.008)
        plaque2(bm, f, ax, (0, 0, 1), cible, ys_entre(y_(0.465), y_(0.615), 0.05), (-0.90, 0.90), 4, 0.009, 0.020, P_VERRE,
                taper=lambda v: 0.25 + 0.75 * math.sin(v * math.pi) ** 0.8, bombe=0.012)
        for yy in (0.25, 0.37):
            eclat(bm, f + ax * y_(yy) + Vector((s * 0.058, 0, 0.0)), (s * 0.75, 0.65, 0.05), 0.095, 0.020, P_VERRE)
        o_j = X.en_objet(bm, "greve_v")
        X.poids_de(o_j, "bottes", lambda p, s=s: (p.x > 0) == (s > 0) and p.y < 0.5, 1)
        # genouillère : poids du GENOU (pantalon autour de y = 0,54)
        parts.append(o_j)
        bm = bmesh.new()
        ft = X.os_g("foot_" + cote)
        bl = X.os_g("ball_" + cote)
        axp = (bl - ft).normalized()
        cp = L.bvh_de(["bottes"], filtre=lambda p, s=s: (p.x > 0) == (s > 0) and p.y < 0.2)
        plaque2(bm, ft, axp, (0, 1, 0), cp, ys_entre(0.02, (bl - ft).length + 0.05, 0.05), (-0.9, 0.9), 4, 0.006, 0.004, P_VERRE,
                taper=lambda v: 1.0 - 0.6 * v ** 1.5, bombe=0.006)
        eclat(bm, bl + Vector((0, 0.03, 0.09)), (0, 0.18, 1.0), 0.10, 0.030, P_VERRE)
        o_p = X.en_objet(bm, "pied_v")
        X.poids_de(o_p, "bottes", lambda p, s=s: (p.x > 0) == (s > 0) and p.y < 0.2, 0)
        parts.append(o_p)
    o = joindre(parts, "bottes_verre")
    # genouillères : poids repris du pantalon (genou), pas des bottes
    me = o.data
    pw = L.poids(o)
    pk = L.poids_proches(o, bpy.data.objects["pantalon"], 3, None)
    for i, v in enumerate(me.vertices):
        if G(v.co).y > 0.46:
            pw[i] = pk[i]
    L.ecrire_poids(o, L.normaliser(pw))
    AXB = {c: axe_tibia(c) for c in ("l", "r")}

    def m_runes_b(P, N, bd):
        out = np.zeros((len(P), 4))
        for c, sg in (("l", 1), ("r", -1)):
            m_ = (P[:, 0] > 0) == (sg > 0)
            if not m_.any():
                continue
            f, ax, k = AXB[c]
            dc = (0.385 - f.y) / (k.y - f.y) * (k - f).length
            s_, t_, _ = anneau_st(P[m_], f, ax, (0, 0, 1), 0.06)
            mk = runes(s_, np.clip((t_ - dc) / 0.0065, -1.2, 1.2), 0.013, 27 + sg, 0.13)
            out[m_] = m_runes(P[m_], N[m_], bd[m_], mk, (0.62, 0.95, 0.66))
        return out

    mat = dispatch({P_VERRE: lambda P, N, bd: m_cristal(P, N, bd, 391, 0.46, 0.055), P_OR: lambda P, N, bd: m_or(P, N, bd, 393),
                    P_RUNES: m_runes_b}, lambda P, N, bd: m_cuir_brun(P, N, bd, 395, 0.44))
    finir(o, mat, [("cuir", {P_COQUE, P_CUIR2}), ("verre", {P_VERRE}), ("or", {P_OR}), ("runes", {P_RUNES})], "bottes_verre", "pieds", X.sol_paire_pieds)


# =============================================================================================================== CHAUSSES
def chausses_hd():
    o = L.copie("pantalon", "chausses_hd", lambda c, n: c.y < 0.93)
    bvh = L.bvh_de(["pantalon"])
    L.ajuster(o, bvh, lambda p: 0.004, lissage=1, force=0.2)
    # densité : une subdivision si le pantalon est trop pauvre pour la charte (600-900)
    if L.nb_tris(o) < 600:
        # subdivision (silhouette du genou et des mollets plus ronde) puis décimation au budget, poids repris du pantalon
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=1, use_grid_fill=True, smooth=0.5)
        bm.to_mesh(o.data)
        bm.free()
        L.decimer(o, 860)
        X.poids_de(o, "pantalon", None, 0)
        L.ajuster(o, bvh, lambda p: 0.004, lissage=1, force=0.2)
    L.ecrire_poids(o, L.normaliser(L.poids(o)))
    L.lisser_normales(o)
    print("PIECE chausses_hd : %d triangles" % L.nb_tris(o))
    L.uv_auto(o, 4.0 / 512, 80)

    def os_ch(P, N, pa, bd):
        out = m_cuir_noirci(P, N, bd, 0.34, 401)
        y, z = P[:, 1], P[:, 2]
        # plaques d'os cousues sur le devant des cuisses (écailles qui se recouvrent), lacets de cuir
        r = np.floor(y / 0.045)
        u = np.mod(y / 0.045, 1.0)
        pl = (y > 0.56) & (y < 0.88) & (z > 0.0) & (u > 0.12)
        o_ = m_os(P[pl], N[pl], bd[pl], 0.55 + 0.05 * np.sin(r[pl]), 403, stries=(1, 0, 0))
        o_[:, :3] *= (0.75 + 0.25 * u[pl])[:, None]
        out[pl] = o_
        lat = np.abs(np.abs(P[:, 0]) - 0.20) < 0.010
        out[lat & (y > 0.45), :3] *= 0.5
        return out

    def verre_ch(P, N, pa, bd):
        out = m_vert_sombre(P, N, bd, 411)
        # coutures doublées le long de la jambe (devant et côté), genou renforcé (empiècement)
        lat = np.abs(np.abs(P[:, 0]) - 0.205) < 0.004
        dev = np.abs(np.arctan2(P[:, 0] - np.sign(P[:, 0]) * 0.114, P[:, 2] + 0.03)) < 0.035
        out[lat | dev, :3] *= 0.6
        gen = (np.abs(P[:, 1] - 0.54) < 0.06) & (P[:, 2] > -0.0)
        out[gen, :3] *= 1.18
        return out

    for fam, nom_mat, fn in (("os", "cuir", os_ch), ("verre", "cuir.vert", verre_ch)):
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        c.name = "chausses_" + fam
        img = L.cuire(c, fn, 512, "chausses_" + fam)
        c.data.materials.clear()
        ancien = bpy.data.materials.get(nom_mat)
        if ancien is not None:
            ancien.name = "zz_" + nom_mat
        c.data.materials.append(L.materiau(nom_mat, img))
        L.exporter(c, ARM, fam, None, CHAUSSES)
        liberer_noms(c)
        if APERCU:
            PIECES.append(c)


if QUOI in ("chausses", "tout"):
    chausses_hd()
if QUOI in ("os", "tout"):
    os_draugr()
    finir_ensemble("os_hd")
if QUOI in ("verre", "tout"):
    verre()
    finir_ensemble("verre")
if APERCU:
    os.makedirs(APERCU, exist_ok=True)
    corps = [bpy.data.objects[n] for n in ("SuperHero_Male",) if n in bpy.data.objects]
    L.apercu(PIECES + corps, APERCU, (0, 0.95, 0), 2.0, QUOI + "_")
    L.apercu(PIECES + corps, APERCU, (0, 1.35, 0), 0.8, QUOI + "_haut_")
print("FINI", QUOI)
