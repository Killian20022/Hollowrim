# Main gantée ANATOMIQUE du bras FPS (retour utilisateur 2026-10-29 : « mains de robots », doigts en boudins) : la main
# gauche du maillage de base MakeHuman hm08 (CC0 1.0, via MPFB2 — sources_blender/mpfb/main_gauche_mh.json, écrit par
# extraire_main_mpfb.py ; licence : assets/LICENCES.md) remplace la paume et les doigts en tubes d'avant_bras_runes.py.
#   - Réduite (Decimate) à ~CIBLE_TRIS triangles ; jointures, phalanges, paume creuse, éminences de la main humaine.
#   - Recalée os par os sur le rig EXISTANT (aucun os ajouté ni déplacé) : chaque sommet suit ses poids MakeHuman
#     (Mixamo -> hand_l, thumb/index/middle/ring/pinky_0k_l) ; pour chaque os, repère (axe de l'os, normale de la paume)
#     MakeHuman -> repère du bras FPS, longueur à l'échelle de l'os, épaisseur à l'échelle de la largeur des jointures
#     (× EPAISSEUR_GANT : cuir par-dessus la peau). Phalange distale : LONG_DISTALE de l'os _03 (l'os du rig est long).
#   - Couleurs de sommet du gant : paume et creux plus sombres, plis des jointures (côté paume) marqués, dos des
#     jointures plus clair (cuir tendu), coutures sur les côtés des doigts.
# Appelée par avant_bras_runes.py : main(m, os_, Vector) ajoute les sommets / faces à la Maille du bras gauche.
import bpy, json, math, os
from mathutils import Vector, Matrix

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ICI, "mpfb", "main_gauche_mh.json")
CIBLE_TRIS = 2200
EPAISSEUR_GANT = 1.12
LONG_DISTALE = 0.80
DOIGTS = ["thumb", "index", "middle", "ring", "pinky"]


def _decimer(d):
    me = bpy.data.meshes.new("_main_mh")
    me.from_pydata([Vector(p) for p in d["sommets"]], [], d["faces"])
    o = bpy.data.objects.new("_main_mh", me)
    bpy.context.scene.collection.objects.link(o)
    for i, w in enumerate(d["poids"]):
        for g, p in w.items():
            (o.vertex_groups.get(g) or o.vertex_groups.new(name=g)).add([i], p, 'REPLACE')
    tris = sum(len(f) - 2 for f in d["faces"])
    if tris > CIBLE_TRIS:
        mod = o.modifiers.new("dec", 'DECIMATE')
        mod.ratio = CIBLE_TRIS / tris
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    gi = {g.index: g.name for g in o.vertex_groups}
    sommets = [v.co.copy() for v in o.data.vertices]
    poids = [{gi[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in o.data.vertices]
    faces = [list(p.vertices) for p in o.data.polygons]
    bpy.data.objects.remove(o)
    bpy.data.meshes.remove(me)
    return sommets, poids, faces


def _repere(h, t, n):
    d = (t - h).normalized()
    u = (n - d * n.dot(d)).normalized()
    s = u.cross(d)
    return Matrix((d, s, u)).transposed()      # colonnes : axe de l'os, travers, normale du dos de la main


def main(m, os_):
    d = json.load(open(SOURCE))
    sommets, poids, faces = _decimer(d)
    mh = {k: (Vector(a), Vector(b)) for k, (a, b) in d["os"].items()}
    nous = {}
    for k in mh:
        b = os_(k[:-2])
        h, t = b.head_local.copy(), b.tail_local.copy()
        if k.endswith("_03_l"):
            t = h + (t - h) * LONG_DISTALE
        nous[k] = (h, t)
    nous["hand_l"] = (os_("hand").head_local.copy(), os_("middle_01").head_local.copy())

    def normale(r):     # dos de la main (index -> auriculaire × poignet -> jointures), même formule des deux côtés
        w = r["hand_l"][0]
        n = (r["index_01_l"][0] - w).cross(r["pinky_01_l"][0] - w)
        return n.normalized()
    n_mh, n_nous = normale(mh), normale(nous)
    if n_nous.z < 0:                                          # dos de la main du rig FPS = +z (repos)
        n_nous, n_mh = -n_nous, -n_mh
    lar = (nous["index_01_l"][0] - nous["pinky_01_l"][0]).length / (mh["index_01_l"][0] - mh["pinky_01_l"][0]).length
    xf = {}
    for k in mh:
        h0, t0 = mh[k]
        h1, t1 = nous[k]
        r0, r1 = _repere(h0, t0, n_mh), _repere(h1, t1, n_nous)
        ech = Matrix.Diagonal(((t1 - h1).length / (t0 - h0).length, lar * EPAISSEUR_GANT, lar * EPAISSEUR_GANT))
        xf[k] = (h0, h1, r1 @ ech @ r0.transposed())
    # joints (côté paume) pour les plis
    plis = [mh[k][0] for k in mh if k != "hand_l"] + [mh[k][1] for k in mh if k.endswith("_03_l") is False and k != "hand_l"]
    idx = []
    for i, p in enumerate(sommets):
        w = poids[i] or {"hand_l": 1.0}
        tot = sum(w.values())
        q = Vector((0, 0, 0))
        for k, pk in w.items():
            h0, h1, a = xf[k]
            q += (h1 + a @ (p - h0)) * (pk / tot)
        # couleur : dos clair, paume sombre ; plis des jointures côté paume ; dos des jointures plus clair
        cote = (p - mh[max(w, key=w.get)][0]).normalized().dot(n_mh)
        col = 0.95 + 0.12 * cote if cote > 0 else 0.95 + 0.30 * cote
        dj = min((p - j).length for j in plis)
        if dj < 0.007:
            col *= (0.80 if cote < 0.2 else 1.10)
        col = max(0.45, min(col, 1.15))
        idx.append(m.sommet(q, [(k, pk / tot) for k, pk in w.items()], col))
    # UV : projection sur le plan de la main (le cuir est un bruit sans direction)
    for f in faces:
        uvs = [((sommets[i].x - 0.3) * 14.0, (sommets[i].y + sommets[i].z) * 14.0) for i in f]
        m.face([idx[i] for i in f], uvs, "ab_gant")
    print("MAIN HUMAINE", len(sommets), "sommets", sum(len(f) - 2 for f in faces), "triangles ; largeur ×%.3f" % lar)
