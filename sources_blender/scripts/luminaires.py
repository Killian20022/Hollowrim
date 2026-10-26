# Lot L8 objets : LUMINAIRES ET ACCROCHES en modules Blender (retouche des versions procédurales, mêmes encombrements).
#   blender.exe -b --python luminaires.py
# Sortie : assets/crypte/modules/luminaires.dat (même format que crypte_v2.dat ; relu par ObjLuminaires en FileAccess, sûr dans le
#          fil de construction). Pas de .glb ni de .blend : rien à inspecter que les captures ne montrent mieux.
# Modules (repère Godot, y haut, +z = devant / vers la pièce) :
#   maillon       maillon ovale ouvert (chaîne lisible : le jour passe dans l'anneau), pas de 0,1 m ; posé un sur deux tourné de 90°
#   applique_fer  applique murale (dos du mur en z = 0) : platine à fleurons et rivets, bras forgé et console en volute, bague à
#                 griffes, torche goudronnée cerclée ; flamme posée par le jeu à (0, 0,2, 0,32)
#   lanterne_fer  lanterne de fer (origine = crochet) : anneau, chapeau à 6 pans et fleuron, cadre, montants, plateau, bougie ;
#                 les vitres de corne sont des cartes additives posées par le jeu (on voit la flamme à travers)
#   lustre_l8 / lustre_l8_6  couronne de fer à cierges (8 ou 6) : double cercle riveté, pointes de couronne, coupelles, tiges de
#                 suspension à nœuds, anneau d'accroche à +0,55 ; points de flamme dans « pts »
#   candelabre_l8 candélabre à pied (1,45 m) : pieds en volute, fût à nœuds, bobèche, bras courbes ; points de flamme dans « pts »
#   brasero_trepied  brasero de fer de la grotte : trépied à pieds enroulés et cerclage, vasque rivetée à oreilles (0,44 m de rayon)
# Les primitives (Module, occlusion cuite, conversion de repère) sont celles de crypte_modules_v2.py : le haut de ce fichier est
# exécuté tel quel (jusqu'au marqueur « modules »), sans reconstruire crypte_v2.dat.
import math, os, struct, sys

ICI_L8 = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(ICI_L8, "crypte_modules_v2.py"), encoding="utf-8").read()
_src = _src.split("# ======================================================================= modules")[0]
exec(compile(_src, "crypte_modules_v2.py (primitives)", "exec"))
from mathutils import Vector, Matrix
import bmesh

DAT_L8 = os.path.join(DOSSIER, "luminaires.dat")
TEINTE["corne"] = (1.0, 0.9, 0.7)


def anneau(M, R_x, R_y, e, pos, segs=6, mat="fer", ton=0.6, plan="xy", yaw=0.0, cotes=4, phase=0.0):
    """Anneau ovale (tore à section polygonale) : rayons R_x (horizontal) et R_y (vertical) au centre du fil, fil de demi-épaisseur e.
    plan « xy » : anneau vertical face à +z ; « xz » : anneau horizontal. Tourné de `yaw` autour de y."""
    bm = bmesh.new()
    rings = []
    for i in range(segs):
        a = math.tau * (i + phase) / segs
        c = Vector((math.cos(a) * R_x, math.sin(a) * R_y, 0.0))
        # normale dans le plan de l'anneau (ellipse : gradient)
        n = Vector((math.cos(a) / max(R_x, 1e-4), math.sin(a) / max(R_y, 1e-4), 0.0)).normalized()
        z = Vector((0, 0, 1))
        ring = []
        for j in range(cotes):
            b = math.tau * (j + 0.5) / cotes
            q = c + n * (math.cos(b) * e) + z * (math.sin(b) * e)
            if plan == "xz":
                q = Vector((q.x, q.z, q.y))
            q = Matrix.Rotation(yaw, 3, 'Y') @ q
            ring.append(bm.verts.new(B(pos + q)))
        rings.append(ring)
    for i in range(segs):
        r0, r1 = rings[i], rings[(i + 1) % segs]
        for j in range(cotes):
            bm.faces.new((r0[j], r0[(j + 1) % cotes], r1[(j + 1) % cotes], r1[j]))
    M._emettre(bm, mat, ton)


def maillon(nom):
    """Maillon ovale vertical (15 x 8,6 cm hors tout, fil de 2,6 cm, bouts plats) : 6 x 3 faces = 36 triangles. Fer clair (ton 0,9) :
    la chaîne se détache du mur sombre."""
    M = Module(nom, 301)
    anneau(M, 0.03, 0.062, 0.013, Vector((0, 0, 0)), 6, "fer", 0.9, phase=0.5, cotes=3)
    return M


def applique_fer(nom):
    M = Module(nom, 311)
    # platine : plaque chanfreinée, fleurons haut et bas, 4 rivets
    M.boite((0.13, 0.3, 0.035), Vector((0, -0.01, 0.018)), "fer", bev=0.0, jit=0.002, ton=0.5)
    for s in (1, -1):
        M.coin([Vector((-0.045, s * 0.14, 0.0)), Vector((0.045, s * 0.14, 0.0)), Vector((-0.045, s * 0.14, 0.03)), Vector((0.045, s * 0.14, 0.03)),
                Vector((0.0, s * 0.2 - 0.01, 0.0)), Vector((0.0, s * 0.2 - 0.01, 0.025))], "fer", bev=0.0, ton=0.48)
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        M.boite((0.022, 0.022, 0.016), Vector((sx * 0.042, sy * 0.105 - 0.01, 0.04)), "fer", bev=0.0, jit=0.001, ton=0.75)
    # bras forgé (vers +z) et console en volute dessous
    M.boite((0.04, 0.04, 0.3), Vector((0, -0.06, 0.18)), "fer", bev=0.0, jit=0.002, ton=0.58)
    M.barre(Vector((0, -0.17, 0.035)), Vector((0, -0.07, 0.25)), 0.012, "fer", 0.55)
    anneau(M, 0.035, 0.035, 0.008, Vector((0, -0.13, 0.13)), 6, "fer", 0.6, yaw=math.pi / 2, cotes=3)    # volute (anneau de la console)
    # bague : collier + 4 griffes relevées
    anneau(M, 0.07, 0.07, 0.009, Vector((0, 0.015, 0.32)), 6, "fer", 0.7, plan="xz", cotes=3)
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.barre(Vector((0, -0.085, 0.32)) + d * 0.055, Vector((0, 0.03, 0.32)) + d * 0.075, 0.007, "fer", 0.55)
    # torche : manche, tête goudronnée cerclée
    M.cylindre(0.026, 0.032, 0.32, Vector((0, -0.12, 0.32)), 6, "bois", ton=0.75, jit=0.002)
    M.cylindre(0.05, 0.06, 0.1, Vector((0, 0.12, 0.32)), 7, "bois", ton=0.32, jit=0.004)
    for y in (0.135, 0.19):
        M.cylindre(0.063, 0.063, 0.014, Vector((0, y, 0.32)), 7, "fer", ton=0.45, jit=0.001)
    return M


def lanterne_fer(nom):
    M = Module(nom, 321)
    # anneau de suspension (origine = point d'accroche), cheminée, chapeau à 6 pans bas et rebord
    anneau(M, 0.022, 0.028, 0.007, Vector((0, -0.028, 0)), 6, "fer", 0.75)
    M.cylindre(0.032, 0.022, 0.03, Vector((0, -0.085, 0)), 6, "fer", ton=0.7, jit=0.0)
    M.cylindre(0.135, 0.032, 0.055, Vector((0, -0.135, 0)), 6, "fer", ton=0.72, jit=0.0)
    M.cylindre(0.14, 0.14, 0.012, Vector((0, -0.145, 0)), 6, "fer", ton=0.85, jit=0.0)
    # cadre : cercle haut, cercle bas, 6 montants fins (cage haute de 0,2 m : la flamme y tient)
    for y in (-0.15, -0.335):
        M.cylindre(0.118, 0.118, 0.014, Vector((0, y, 0)), 6, "fer", ton=0.75, jit=0.0)
    for k in range(6):
        a = math.tau * k / 6
        M.boite((0.013, 0.19, 0.013), Vector((math.cos(a) * 0.113, -0.24, math.sin(a) * 0.113)), "fer", yaw=-a, bev=0.0, jit=0.0, ton=0.6)
    # plateau, pied court
    M.cylindre(0.1, 0.122, 0.028, Vector((0, -0.37, 0)), 6, "fer", ton=0.65, jit=0.0)
    M.cylindre(0.03, 0.05, 0.03, Vector((0, -0.4, 0)), 6, "fer", ton=0.6, jit=0.0)
    # bougie de suif
    M.cylindre(0.024, 0.022, 0.05, Vector((0, -0.342, 0)), 6, "cire", ton=0.95, jit=0.0)
    return M


def lustre_l8(nom, cierges=8, leger=False):
    """leger : variante des salles DonjonKit (lustre v1, nombreux) : cercles à 10 et 8 pans, sans rivets."""
    M = Module(nom, 331)
    R = 0.6
    M.tore_polygonal(R, 0.045, Vector((0, 0.0, 0)), 10 if leger else 14, "fer", 0.55, 0.07)
    M.tore_polygonal(R - 0.1, 0.03, Vector((0, 0.02, 0)), 8 if leger else 12, "fer", 0.5, 0.04)
    # pointes de couronne entre les cierges (silhouette nordique), rivets sur le cercle
    for k in range(cierges):
        a = math.tau * k / cierges
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.coin([d * (R - 0.02) + Vector((0, 0.035, 0)) + Vector((-d.z, 0, d.x)) * s * 0.03 for s in (1, -1)] +
               [d * (R + 0.02) + Vector((0, 0.035, 0)) + Vector((-d.z, 0, d.x)) * s * 0.03 for s in (1, -1)] +
               [d * R + Vector((0, 0.13, 0))], "fer", bev=0.0, ton=0.6)
        if not leger:
            M.boite((0.024, 0.02, 0.024), d * (R + 0.026) + Vector((0, -0.005, 0)), "fer", yaw=-a, bev=0.0, jit=0.0, ton=0.78)
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.boite((0.03, 0.03, R * 0.98), d * R * 0.5 + Vector((0, 0.03, 0)), "fer", yaw=-a, bev=0.0, jit=0.002, ton=0.5)
        M.barre(d * R * 0.95 + Vector((0, 0.04, 0)), Vector((0, 0.53, 0)), 0.012, "fer", 0.5)
        M.boite((0.034, 0.04, 0.034), d * R * 0.5 + Vector((0, 0.29, 0)), "fer", yaw=-a, bev=0.0, jit=0.0, ton=0.62)     # nœud de la tige
    M.cylindre(0.05, 0.02, 0.2, Vector((0, -0.2, 0)), 6, "fer", ton=0.55, jit=0.002)
    M.sphere(0.065, Vector((0, 0.0, 0)), mat="fer", seg=6, ton=0.55, jit=0.003)
    M.cylindre(0.06, 0.05, 0.04, Vector((0, 0.51, 0)), 6, "fer", ton=0.55, jit=0.0)
    anneau(M, 0.03, 0.03, 0.008, Vector((0, 0.575, 0)), 6, "fer", 0.65)                     # anneau d'accroche de la chaîne
    for k in range(cierges):
        a = math.tau * (k + 0.5) / cierges
        c = Vector((math.cos(a) * R, 0.035, math.sin(a) * R))
        M.cylindre(0.062, 0.045, 0.06, c, 6, "fer", ton=0.66, jit=0.0)                        # coupelle à bobèche
        hc = 0.12 + 0.05 * (k % 3)
        M.cylindre(0.026, 0.024, hc, c + Vector((0, 0.06, 0)), 6, "cire", ton=0.95, jit=0.002, bev=0.0)
        M.pts.append(Vector((c.x, 0.06 + hc + 0.02, c.z)))
    return M


def candelabre_l8(nom, bras=3):
    M = Module(nom, 341)
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.barre(d * 0.04 + Vector((0, 0.3, 0)), d * 0.17 + Vector((0, 0.035, 0)), 0.016, "fer", 0.58)
        anneau(M, 0.03, 0.03, 0.009, d * 0.175 + Vector((0, 0.035, 0)), 6, "fer", 0.6, yaw=-a + math.pi / 2)     # pied en volute
    M.cylindre(0.07, 0.05, 0.08, Vector((0, 0.27, 0)), 8, "fer", ton=0.6, jit=0.0)
    M.cylindre(0.024, 0.024, 0.8, Vector((0, 0.35, 0)), 6, "fer", ton=0.55, jit=0.0)
    for y in (0.62, 0.95):
        M.cylindre(0.042, 0.042, 0.05, Vector((0, y - 0.025, 0)), 6, "fer", ton=0.62, jit=0.0)       # nœuds du fût
    M.cylindre(0.11, 0.08, 0.05, Vector((0, 1.15, 0)), 8, "fer", ton=0.62, jit=0.0)
    M.cylindre(0.115, 0.115, 0.012, Vector((0, 1.2, 0)), 8, "fer", ton=0.72, jit=0.0)
    for k in range(bras):
        a = math.tau * k / bras + 0.2
        d = Vector((math.cos(a), 0, math.sin(a)))
        c = d * 0.17
        M.barre(d * 0.03 + Vector((0, 1.17, 0)), d * 0.13 + Vector((0, 1.22, 0)), 0.011, "fer", 0.55)
        M.barre(d * 0.13 + Vector((0, 1.22, 0)), c + Vector((0, 1.36, 0)), 0.011, "fer", 0.55)
        M.cylindre(0.05, 0.035, 0.05, Vector((c.x, 1.36, c.z)), 8, "fer", ton=0.6, jit=0.0)
        M.cylindre(0.055, 0.055, 0.01, Vector((c.x, 1.405, c.z)), 8, "fer", ton=0.72, jit=0.0)
        hc = 0.13 + 0.05 * (k % 2)
        M.cylindre(0.024, 0.022, hc, Vector((c.x, 1.41, c.z)), 6, "cire", ton=0.95, jit=0.002, bev=0.0)
        M.cylindre(0.03, 0.028, 0.025, Vector((c.x + 0.005, 1.41 + hc * 0.4, c.z)), 5, "cire", ton=0.85, jit=0.002)
        M.pts.append(Vector((c.x, 1.41 + hc + 0.01, c.z)))
    M.cylindre(0.026, 0.024, 0.2, Vector((0, 1.22, 0)), 6, "cire", ton=0.95, jit=0.002, bev=0.0)
    M.cylindre(0.032, 0.03, 0.03, Vector((0.006, 1.27, 0)), 5, "cire", ton=0.85, jit=0.002)
    M.pts.append(Vector((0, 1.43, 0)))
    return M


def brasero_trepied(nom):
    M = Module(nom, 351)
    for k in range(3):
        a = math.tau * k / 3 + 0.3
        d = Vector((math.cos(a), 0, math.sin(a)))
        M.barre(d * 0.34 + Vector((0, 0.05, 0)), d * 0.16 + Vector((0, 0.72, 0)), 0.02, "fer", 0.55)
        anneau(M, 0.04, 0.04, 0.012, d * 0.37 + Vector((0, 0.045, 0)), 6, "fer", 0.6, yaw=-a + math.pi / 2)     # pied enroulé
    M.tore_polygonal(0.27, 0.022, Vector((0, 0.3, 0)), 9, "fer", 0.6, 0.03)                     # cerclage des pieds
    # vasque : profil évasé, lèvre épaisse rivetée, 4 oreilles
    M.cylindre(0.14, 0.36, 0.1, Vector((0, 0.68, 0)), 10, "fer", ton=0.58, jit=0.0)
    M.cylindre(0.36, 0.43, 0.14, Vector((0, 0.78, 0)), 10, "fer", ton=0.6, jit=0.0)
    M.tore_polygonal(0.425, 0.03, Vector((0, 0.925, 0)), 10, "fer", 0.72, 0.035)
    for k in range(10):
        a = math.tau * (k + 0.5) / 10
        M.boite((0.024, 0.024, 0.014), Vector((math.cos(a) * 0.41, 0.86, math.sin(a) * 0.41)), "fer", yaw=-a, bev=0.0, jit=0.0, ton=0.8)
    for k in range(2):
        a = math.pi * k + 0.3
        anneau(M, 0.04, 0.03, 0.01, Vector((math.cos(a) * 0.43, 0.9, math.sin(a) * 0.43)), 6, "fer", 0.62, yaw=-a + math.pi / 2)
    return M


def construire_l8():
    return [maillon("maillon"), applique_fer("applique_fer"), lanterne_fer("lanterne_fer"), lustre_l8("lustre_l8", 8),
            lustre_l8("lustre_l8_6", 6, leger=True), candelabre_l8("candelabre_l8"), brasero_trepied("brasero_trepied")]


def exporter_l8(mods):
    donnees = {}
    for M in mods:
        res = M.finir()
        for mat, faces in res.items():
            donnees["%s__%s" % (M.nom, mat)] = faces
        if M.pts:
            donnees["%s__pts" % M.nom] = [((p, p, p), [(1, 1, 1, 1)] * 3) for p in M.pts]
        print("  %-18s %5d tris" % (M.nom, len(M.tris)))
    with open(DAT_L8, "wb") as f:
        f.write(struct.pack("<I", len(donnees)))
        for nom, faces in donnees.items():
            nb = nom.encode()
            f.write(struct.pack("<B", len(nb)) + nb + struct.pack("<I", len(faces) * 3))
            for p, c in faces:
                for q, cc in zip(p, c):
                    f.write(struct.pack("<7f", q.x, q.y, q.z, cc[0], cc[1], cc[2], cc[3]))
    print("luminaires L8 : %d modules ->" % len(mods), DAT_L8)


exporter_l8(construire_l8())
