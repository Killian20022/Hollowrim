# ÉPÉES HYBRIDES (essai 2026-10-30, branche essai/epees_hybrides) : nos lames (epees_longues.py : longueur, gouttière, reflet)
# + montures Quaternius CC0 (garde, fusée, pommeau du « LowPoly Medieval Weapons » 2018), ou l'inverse (lame Quaternius + nos pièces).
#   blender.exe -b --python epees_hybrides.py -- [id ...]      (sans argument : toutes)
# Exporte assets/modeles/armes/hybrides/<id>.glb + hybrides_info.json (à côté de ce script).
# REPÈRE ET MATÉRIAUX : identiques à epees_longues.py (lame +Z Blender / +Y glTF, centre du poing à z = 0,03, nœuds prise/garde/pointe,
# matériaux nommés lame, lame_or, fer, or, cuir, gemme, rubis, verre, emeraude, obsidienne, veine ; + « saphir », nouveau, habillé
# pour l'instant par le script de planche seulement).
# Sources Quaternius : C:/Users/lopezk19/Jeux/references/armes_cc0/glb/ (déjà mises au repère par convertir_armes.py ; CC0).
import bpy, bmesh, json, math, os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
_lib = os.path.join(os.path.dirname(ICI), "epees_longues", "epees_longues.py")
exec(open(_lib, encoding="utf-8").read().split("# ================================================================== variantes")[0])
ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.dirname(os.path.dirname(ICI))
SORTIE = os.path.join(DEPOT, "assets", "modeles", "armes", "hybrides")
QGLB = "C:/Users/lopezk19/Jeux/references/armes_cc0/glb/"
MATS = MATS + ("saphir",)
Z_HAUT = 0.084          # haut de la fusée (sous la garde), comme nos épées
LAMES_Q = {"01_sword": ("lame",), "02_sword_2": ("lame",), "03_sword_golden": ("or",), "05_claymore": ("rubis",)}

_cache = {}


def quaternius(src):
    """Pièces d'une arme Quaternius, classées par matériau et hauteur : faces (sommets monde, uv) + repères."""
    if src in _cache:
        return _cache[src]
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=QGLB + src + ".glb")
    nouveaux = list(set(bpy.data.objects) - avant)
    brut = []
    for o in nouveaux:
        if o.type != 'MESH':
            continue
        me, mw, uvl = o.data, o.matrix_world, o.data.uv_layers.active
        for p in me.polygons:
            mat = me.materials[p.material_index].name.split(".")[0]
            vs = [tuple(mw @ me.vertices[me.loops[li].vertex_index].co) for li in p.loop_indices]
            uvs = [tuple(uvl.data[li].uv) for li in p.loop_indices]
            brut.append((mat, (mw @ p.center).z, vs, uvs))
    for o in nouveaux:
        bpy.data.objects.remove(o)
    zc = [v[2] for m, z, vs, u in brut if m == "cuir" for v in vs]
    gz0, gz1 = min(zc), max(zc)
    P = {"poignee": [], "bagues": [], "garde": [], "pommeau": [], "lame": []}
    for mat, z, vs, uvs in brut:
        if mat in LAMES_Q[src]:
            P["lame"].append((vs, uvs))
        elif mat == "cuir":
            P["poignee"].append((vs, uvs))
        elif z > gz1 - 0.004:
            P["garde"].append((vs, uvs))
        elif z < gz0 + 0.004:
            P["pommeau"].append((vs, uvs))
        else:
            P["bagues"].append((vs, uvs))

    def ext(k, i):
        vals = [v[i] for vs, u in P[k] for v in vs]
        return (min(vals), max(vals)) if vals else (0.0, 0.0)
    P["gz"] = (gz0, gz1)
    for k in ("garde", "pommeau", "lame"):
        P[k + "_z"] = ext(k, 2)
        P[k + "_x"] = ext(k, 0)
        P[k + "_y"] = ext(k, 1)
    _cache[src] = P
    return P


class Greffe(Maille):
    """Maille sans recalcul des normales (les faces Quaternius gardent leur sens d'origine)."""

    def creer(self, lisse=False):
        me = bpy.data.meshes.new(self.nom)
        bm = bmesh.new()
        bv = [bm.verts.new(p) for p in self.v]
        uvl = bm.loops.layers.uv.new("UVMap")
        noms = []
        for idx, mat, uvs in self.f:
            if mat not in noms:
                noms.append(mat)
        for idx, mat, uvs in self.f:
            try:
                bf = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            bf.material_index = noms.index(mat)
            bf.smooth = lisse
            for lo, uv in zip(bf.loops, uvs):
                lo[uvl].uv = uv
        bm.to_mesh(me)
        bm.free()
        for n in noms:
            me.materials.append(bpy.data.materials.get(n) or bpy.data.materials.new(n))
        o = bpy.data.objects.new(self.nom, me)
        bpy.context.scene.collection.objects.link(o)
        return o


def greffer(m, faces, mat, f, uv_de=None):
    """f(p) -> nouvelle position ; uv_de(p_nouveau) -> uv (sinon uv d'origine)."""
    for vs, uvs in faces:
        nv = [f(v) for v in vs]
        idx = [m.sommet(p) for p in nv]
        m.face(idx, mat, [uv_de(p) for p in nv] if uv_de else uvs)


def lame_rel(m, prof_rel, z0, zt, section, mat_de, w_ref, elargir=ELARGIR):
    """Lame de epees_longues.lame() avec des stations relatives (f = 0 garde -> 1 pointe)."""
    L = zt - z0
    prof = [(z0 + st[0] * L,) + tuple(st[1:]) for st in prof_rel]
    lame(m, prof, z0, zt, section, mat_de, w_ref, elargir=elargir)


# --------------------------------------------------------------- profils de lame (stations relatives)
P_ACIER = [(0.0, 0.0235, 0.0042), (0.05, 0.0240, 0.0040), (0.414, 0.0215, 0.0036), (0.767, 0.0180, 0.0031),
           (0.903, 0.0120, 0.0026), (0.966, 0.0060, 0.0020)]
P_ACIER_RICASSO = [(0.0, 0.0175, 0.0050), (0.07, 0.0175, 0.0050), (0.075, 0.0240, 0.0041), (0.12, 0.0240, 0.0040),
                   (0.45, 0.0215, 0.0036), (0.78, 0.0180, 0.0031), (0.905, 0.0120, 0.0026), (0.966, 0.0060, 0.0020)]
P_OBSI = [(0.0, 0.0290, 0.0062), (0.035, 0.0315, 0.0062), (0.068, 0.0270, 0.0062), (0.070, 0.0320, 0.0061),
          (0.123, 0.0280, 0.0060), (0.126, 0.0322, 0.0060), (0.184, 0.0290, 0.0059), (0.40, 0.0300, 0.0056),
          (0.70, 0.0265, 0.0050), (0.85, 0.0190, 0.0042), (0.94, 0.0090, 0.0030)]
P_VERRE = [(0.0, 0.0190, 0.0042, 0.0), (0.05, 0.0225, 0.0045, 0.002), (0.27, 0.0212, 0.0043, -0.002),
           (0.50, 0.0205, 0.0040, 0.002), (0.70, 0.0188, 0.0036, -0.0015), (0.84, 0.0145, 0.0031, 0.001),
           (0.93, 0.0080, 0.0025, 0.0)]
# lame de claymore à crans (esprit de la n°05) : talon large en gradins, deux crans, renflement au tiers, pointe longue
P_CLAYMORE = [(0.0, 0.0200, 0.0062), (0.03, 0.0262, 0.0066), (0.10, 0.0262, 0.0064), (0.104, 0.0200, 0.0062),
              (0.125, 0.0260, 0.0063), (0.20, 0.0252, 0.0061), (0.204, 0.0190, 0.0059), (0.226, 0.0232, 0.0059),
              (0.45, 0.0212, 0.0056), (0.60, 0.0222, 0.0054), (0.62, 0.0180, 0.0051), (0.645, 0.0212, 0.0050),
              (0.82, 0.0162, 0.0045), (0.925, 0.0095, 0.0037)]

# --------------------------------------------------------------- variantes
# Chaque fiche : prise (1 ou 2 mains), longueurs (m) et origines. Les pièces Quaternius sont mises à l'échelle (sx, sy, sz) ;
# la fusée Quaternius est étirée sur la longueur voulue (lp) ; la lame est la nôtre (profil) ou celle de Quaternius étirée (lame_q).
FICHES = {
    "h1_garde_du_guet": dict(nom="Garde-du-Guet", mains=1, lp=0.12, lame=0.80,
        garde=("01_sword", (0.92, 0.9, 0.85), "fer"), poignee=("01_sword", 0.85, "cuir"), pommeau=("01_sword", (0.9, 0.9, 0.9), "fer"),
        prof=P_ACIER, mat_lame="lame", gemme="gemme", origine_lame="nôtre (acier à gouttière, reflet)",
        origine_garde="Quaternius Sword (garde, fusée gainée, pommeau)"),
    "h2_dent_d_or": dict(nom="Dent-d'Or", mains=1, lp=0.12, lame=0.78,
        garde=("03_sword_golden", (1.0, 1.0, 0.9), "or"), poignee=("03_sword_golden", 1.0, "cuir"),
        pommeau=("03_sword_golden", (1.0, 1.0, 1.0), "or"), prof=P_ACIER, mat_lame="lame_or", gemme="rubis",
        origine_lame="nôtre (acier doré gravé, gouttière, reflet)", origine_garde="Quaternius Sword_Golden (garde, fusée, pommeau) dorés"),
    "h3_veilleuse": dict(nom="Veilleuse", mains=1.5, lp=0.20, lame=0.92,
        garde=("05_claymore", (0.80, 0.72, 0.78), "fer"), poignee=("05_claymore", 0.78, "cuir"), bagues="fer",
        pommeau=("05_claymore", (0.78, 0.78, 0.78), "fer"), prof=P_ACIER_RICASSO, mat_lame="lame", gemme="gemme",
        origine_lame="nôtre (acier, talon/ricasso, gouttière, reflet)", origine_garde="Quaternius Claymore réduite (garde à cornes, fusée baguée, pommeau à pointe)"),
    "h4_crocs_de_cendre": dict(nom="Crocs-de-Cendre", mains=1.5, lp=0.20, lame=0.95,
        garde=("02_sword_2", (1.0, 1.0, 1.0), "obsidienne"), poignee=("02_sword_2", 0.85, "cuir"),
        pommeau=("02_sword_2", (1.0, 1.0, 1.0), "obsidienne"), prof=P_OBSI, section="veine", mat_lame="obsidienne",
        gemme="veine", cristal_pommeau="veine", elargir=(1.45, 1.15), w_ref=0.032,
        origine_lame="nôtre (obsidienne à veines, crans)", origine_garde="Quaternius Sword_2 (garde, fusée, pommeau) en obsidienne"),
    "h5_larme_de_givre": dict(nom="Larme-de-Givre", mains=1.5, lp=0.20, lame=0.93,
        garde=("01_sword", (1.0, 0.85, 0.85), "fer"), poignee=("01_sword", 0.82, "cuir"),
        pommeau=("05_claymore", (0.7, 0.7, 0.7), "fer"), prof=P_VERRE, mat_lame="verre", gemme="emeraude", gemmes_bouts="emeraude",
        elargir=(1.55, 1.15), w_ref=0.0225,
        origine_lame="nôtre (verre émeraude translucide)", origine_garde="Quaternius Sword (garde, fusée) + pommeau de la Claymore"),
    "h6_coeur_de_braise": dict(nom="Cœur-de-Braise", mains=2, lp=0.30, lame=1.06,
        garde=("05_claymore", (1.1, 1.0, 1.05), "fer"), lame_q="05_claymore", mat_lame="rubis", gemme="rubis", gemmes_bouts="rubis",
        poignee_notre=0.0185, bagues_notre="fer", pommeau_notre="rubis",
        origine_lame="Quaternius Claymore (lame rouge étirée à 1,06 m)", origine_garde="garde Claymore Quaternius + NOTRE fusée tressée baguée et pommeau-cristal"),
    "h7_sang_du_roi": dict(nom="Sang-du-Roi", mains=2, lp=0.30, lame=1.04,
        garde=("05_claymore", (1.12, 1.0, 1.05), "or"), poignee=("05_claymore", 0.72, "cuir"), bagues="or",
        pommeau=("05_claymore", (1.0, 1.0, 1.0), "or"), prof=P_CLAYMORE, mat_lame="rubis", gemme="rubis", cristal_pommeau="rubis",
        w_ref=0.026, origine_lame="nôtre (cristal rubis à crans, gouttière)", origine_garde="Quaternius Claymore (garde, fusée baguée, pommeau) dorés"),
    "h8_croc_de_givre": dict(nom="Croc-de-Givre", mains=2, lp=0.30, lame=1.04,
        garde=("05_claymore", (1.12, 1.0, 1.05), "fer"), poignee=("05_claymore", 0.72, "cuir"), bagues="fer",
        pommeau=("05_claymore", (1.0, 1.0, 1.0), "fer"), prof=P_CLAYMORE, mat_lame="saphir", gemme="saphir", cristal_pommeau="saphir",
        gemmes_bouts="saphir", w_ref=0.026,
        origine_lame="nôtre (cristal saphir à crans, gouttière)", origine_garde="Quaternius Claymore (garde, fusée baguée, pommeau) en fer"),
}


def construire(ident):
    F = FICHES[ident]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _cache.clear()
    for n in MATS:
        bpy.data.materials.new(n)
    zg = Z_HAUT
    zb = zg - F["lp"]
    G = Greffe("monture")
    # ---- garde (Quaternius) : le haut de SA fusée -> zg
    src, (sx, sy, sz), mat_g = F["garde"]
    Q = quaternius(src)
    q1 = Q["gz"][1]
    greffer(G, Q["garde"], mat_g, lambda v: (v[0] * sx, v[1] * sy, zg + (v[2] - q1) * sz))
    g_z0 = zg + (Q["garde_z"][0] - q1) * sz
    g_z1 = zg + (Q["garde_z"][1] - q1) * sz
    g_x = Q["garde_x"][1] * sx
    g_y = Q["garde_y"][1] * sy
    z_lame = zg + (Q["lame_z"][0] - q1) * sz          # où la lame Quaternius sortait de cette garde
    # ---- lame
    if F.get("lame_q"):
        QL = quaternius(F["lame_q"])
        l0, l1 = QL["lame_z"]
        sl = F["lame"] / (l1 - l0)
        wq = QL["lame_x"][1] * sx
        greffer(G, QL["lame"], F["mat_lame"], lambda v: (v[0] * sx, v[1] * sy, z_lame + (v[2] - l0) * sl),
                uv_de=lambda p: ((p[0] + wq) / (2 * wq), (p[2] - z_lame) / F["lame"]))
        z0, zt = z_lame, z_lame + F["lame"]
    else:
        z0 = z_lame - 0.010
        zt = z0 + F["lame"]
        L = Maille("lame")
        mat = F["mat_lame"]
        if F.get("section") == "veine":
            n = len(F["prof"])
            md = lambda k, i: "veine" if (i in (2, 7) and k < n - 1) else mat
        else:
            md = lambda k, i: mat
        lame_rel(L, F["prof"], z0, zt, F.get("section", "gorge"), md, F.get("w_ref", 0.024), elargir=F.get("elargir", ELARGIR))
        L.creer()
    # ---- fusée
    if F.get("poignee"):
        src, sr, mat_p = F["poignee"]
        Q = quaternius(src)
        q0, q1 = Q["gz"]
        s = F["lp"] / (q1 - q0)
        f = lambda v: (v[0] * sr, v[1] * sr, zb + (v[2] - q0) * s)
        greffer(G, Q["poignee"], mat_p, f)
        if F.get("bagues"):
            greffer(G, Q["bagues"], F["bagues"], f)
    else:   # NOTRE fusée : cuir tressé (10 pans) + bagues
        r = F["poignee_notre"]
        P = Maille("fusee")
        n = 6
        zs = [zb + F["lp"] * k / n for k in range(n + 1)]
        tour(P, [(z, r * (1.0 + 0.06 * math.sin(k * 1.3))) for k, z in enumerate(zs)], "cuir", cotes=10, ecrase_y=0.9, uv_tours=2.0)
        for z in [zb + 0.008, zb + F["lp"] * 0.36, zb + F["lp"] * 0.68, zg - 0.008]:
            tour(P, [(z - 0.007, r * 1.06), (z - 0.003, r * 1.22), (z + 0.003, r * 1.22), (z + 0.007, r * 1.06)],
                 F["bagues_notre"], cotes=10, ecrase_y=0.9, uv_tours=1.0)
        P.creer()
    # ---- pommeau
    J = Maille("ornements")
    if F.get("pommeau"):
        src, (px, py, pz), mat_m = F["pommeau"]
        Q = quaternius(src)
        q0 = Q["gz"][0]
        greffer(G, Q["pommeau"], mat_m, lambda v: (v[0] * px, v[1] * py, zb + (v[2] - q0) * pz))
        z_bas = zb + (Q["pommeau_z"][0] - q0) * pz
        if F.get("cristal_pommeau"):          # cristal serti sous le pommeau, pointe vers le bas
            octaedre(J, (0, 0, z_bas + 0.004), 0.013, 0.010, 0.010, 0.026, F["cristal_pommeau"])
            z_bas -= 0.022
    else:   # NOTRE pommeau : coupe de fer à six pans + cristal (comme l'épée rubis, agrandi)
        M = Maille("pommeau")
        tour(M, [(zb - 0.030, 0.0190), (zb - 0.020, 0.0260), (zb - 0.008, 0.0230), (zb, 0.0180)], "fer", cotes=6,
             ecrase_y=0.8, uv_tours=1.0)
        M.creer()
        octaedre(J, (0, 0, zb - 0.040), 0.0230, 0.0170, 0.0140, 0.0330, F["pommeau_notre"])
        z_bas = zb - 0.073
    # ---- gemmes (ajouts : plus de détail que l'original)
    zc = (g_z0 + g_z1) * 0.5
    if F.get("gemme"):
        octaedre(J, (0, 0, zc), 0.016, g_y * 1.12, 0.020, 0.016, F["gemme"])
    if F.get("gemmes_bouts"):
        for s_ in (-1, 1):
            octaedre(J, (s_ * g_x * 0.86, 0, g_z1 - 0.010), 0.0075, g_y * 0.9, 0.012, 0.006, F["gemmes_bouts"])
    G.creer()
    if J.f:
        J.creer()
    vide("prise", Z_PRISE)
    vide("garde", z0 + 0.010)
    vide("pointe", zt)
    os.makedirs(SORTIE, exist_ok=True)
    glb = os.path.join(SORTIE, ident + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_yup=True, use_selection=False)
    tris = 0
    zmin, zmax = 9.0, -9.0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
            zmin = min(zmin, min(v.co.z for v in o.data.vertices))
            zmax = max(zmax, max(v.co.z for v in o.data.vertices))
    info = {"nom": F["nom"], "mains": F["mains"], "triangles": tris, "longueur": round(zmax - zmin, 3),
            "lame": round(zt - z0, 3), "fusee": F["lp"], "origine_lame": F["origine_lame"], "origine_garde": F["origine_garde"]}
    print("HYBRIDE %-20s tris=%4d longueur=%.3f lame=%.3f -> %s" % (ident, tris, zmax - zmin, zt - z0, glb))
    return info


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
choix = [a for a in args if a in FICHES] or list(FICHES)
chemin_info = os.path.join(ICI, "hybrides_info.json")
infos = json.load(open(chemin_info, encoding="utf-8")) if os.path.exists(chemin_info) else {}
for ident in choix:
    infos[ident] = construire(ident)
json.dump(infos, open(chemin_info, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
