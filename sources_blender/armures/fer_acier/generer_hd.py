# Armures lourdes HD : FER et ACIER NORDIQUE (charte CHARTE_ARMURES_HD.md + planche de référence planche_armures_5.png, colonne
# STEEL/IRON). Génère les glb portés (assets/modeles/armures/porte/<id>.glb) et au sol (sol/<id>.glb).
#   blender.exe -b --python sources_blender/armures/fer_acier/generer_hd.py -- [ids...] [--apercu DOSSIER] [--pas-sol]
# Sans id : les 8 pièces (4 fer + 4 acier nordique). Chausses : chausses_hd.py.
import bpy, sys, os, math, importlib
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
sys.path.insert(1, os.path.join(ICI, "..", "lourdes"))
import commun as C
import hd as H
import pieces_hd as PH
importlib.reload(C); importlib.reload(H); importlib.reload(PH)
from mathutils import Vector, Matrix

# ------------------------------------------------------------------------------------------------ styles
# ACIER NORDIQUE : acier gris usé et riveté (planche), arêtes polies, peu de rouille ; cuir brun ; fourrure beige.
ACIER = dict(pal=H.ACIER_NEUTRE, mat="acier", mat_rebord="acier", mat_main="cuir", mat_doigts="cuir", mat_genou="acier", base=0.46, contraste=0.30,
             martele=0.15, cellule=3.2, oxyde=0.0, crasse=0.45, poli=0.22, patine=0.18, rouille=0.06, sale=0.85, poli_arete=1.0, poli_bord=0.5,
             rayures=2.2, r_rivet=0.8, k_rivet=0.74, graine=23, pal_cuir=H.CUIR, base_cuir=0.44, pal_maille=H.FER, base_maille=0.55,
             oxyde_maille=0.1, mat_maille="acier.maille")
# FER : même famille, plus simple et rustique : fer sombre piqué et martelé, rouille dans les creux, cuir plus sombre.
FER = dict(pal=H.FER, mat="fer", mat_rebord="fer", mat_main="cuir", mat_doigts="cuir", mat_genou="fer", base=0.42, contraste=0.30,
           martele=0.42, cellule=3.0, oxyde=0.5, crasse=0.55, poli=0.28, patine=0.22, rouille=0.85, sale=0.7, poli_arete=0.55,
           rayures=0.6, r_rivet=0.85, k_rivet=0.6, graine=11, pal_cuir=H.CUIR, base_cuir=0.36, pal_maille=H.FER, base_maille=0.46,
           oxyde_maille=0.55, mat_maille="fer.maille")


def _s(b0, **kw):
    d = dict(b0); d.update(kw)
    d["peintures"] = list(kw.get("peintures", []))
    return d


PIECES = {
    # --- fer : casque à nasal (spangenhelm riveté) et camail ; cuirasse à deux lames, baudrier, col de fourrure brune
    "casque_fer": lambda r: PH.casque(r, _s(FER, id="casque_fer", bombe=0.012, rivets_rebord=16, larg_bande=0.014,
                                           camail_arc=(100, 260), decor=[PH.deco_nasal, PH.deco_camail])),
    "cuirasse_fer": lambda r: PH.cuirasse(r, _s(FER, id="cuirasse_fer", z_lames=[1.06, 1.17, 1.42], bombe=0.012, tablier=20,
                                               fentes=(-95, 95, 180), dechire=0.03, rivets_lame=12, sangles=[((36, 1.42), (-30, 1.04)),],
                                               lames_epaule=3, rivets_epaule=6, epaule_ecart=0.024, bord_roule=True,
                                               fourrure=dict(gonfle=0.95, arc=(0, 360), ferme=True, devant=0.55, pas=22.5, meches=0.045, cote=0.15, r_max=0.16, r_max_cote=0.07, phis=(-14, -8, 4, 16, 34, 50), phis_cote=(-4, 2, 12, 24, 38, 52)),
                                               pal_fourrure=H.FOURRURE_BRUNE_CLAIRE, base_fourrure=0.5)),
    "gantelets_fer": lambda r: PH.gantelets(r, _s(FER, id="gantelets_fer", main_cuir=True, lames_main=1, rivets_manchette=7, rivets_lames=4,
                                                  evasement=0.022, jointures=False, debut_manchette=0.08)),
    "bottes_fer": lambda r: PH.bottes(r, _s(FER, id="bottes_fer", greve=False, revers_fourrure=True, ep_revers=1.1, sangles=(0.10, 0.26), cuissots=3,
                                           ailette=0.0, rivets_greve=True, pal_fourrure=H.FOURRURE_BRUNE_CLAIRE, base_fourrure=0.5)),
    # --- acier nordique : la colonne STEEL de la planche
    "casque_acier_nordique": lambda r: PH.casque(r, _s(ACIER, id="casque_acier_nordique", bas=(0.26, -0.2, -0.55), bandes=[0.0, math.pi],
                                                      larg_bande=0.009, haut_bande=0.0055, rivets_rebord=20, rebord=0.008, haut_rebord=0.03,
                                                      joues_arc=(13, 92), joues_z=(1.676, 1.650, 1.622, 1.590), joues_ecart=0.027,
                                                      decor=[PH.deco_masque_t, PH.deco_joues])),
    "cuirasse_acier_nordique": lambda r: PH.cuirasse(r, _s(ACIER, id="cuirasse_acier_nordique", n=18, z_lames=[1.04, 1.11, 1.18, 1.43], bombe=0.025,
                                                           tablier=22, fentes=(-100, 100, 180), rivets_lame=16, rivets_milieu=True,
                                                           tassettes=(58, 100), sangles=[((40, 1.43), (-30, 1.04)), ((-40, 1.43), (30, 1.04))],
                                                           disque=(-33, 1.365), sacoche=-38, lames_epaule=3, rivets_epaule=7, bord_roule=True,
                                                           fourrure=dict(gonfle=1.2, arc=(0, 360), ferme=True, devant=0.55, pas=22.5, densite=(2, 1, 1, 1, 1), meches=0.06, cote=0.25, r_max=0.165, r_max_cote=0.085, phis=(-12, -6, 6, 18, 36, 52), phis_cote=(-6, 0, 10, 24, 38, 52)),
                                                           pal_fourrure=H.FOURRURE_GRISE, base_fourrure=0.74, degrade_fourrure=0.5)),
    "gantelets_acier_nordique": lambda r: PH.gantelets(r, _s(ACIER, id="gantelets_acier_nordique", main_cuir=True, lames_main=2, rivets_manchette=9,
                                                             rivets_lames=5, evasement=0.03, jointures=True, debut_manchette=0.08)),
    "bottes_acier_nordique": lambda r: PH.bottes(r, _s(ACIER, id="bottes_acier_nordique", greve=False, revers_fourrure=True, sangles=(0.08, 0.20, 0.32), ep_revers=1.35, cuissots=3,
                                                       embout=False, ailette=0.032, rivets_greve=True, pal_fourrure=H.FOURRURE_BEIGE, base_fourrure=0.6)),
}

MASQUE = {"tete": {"Hair_Long"}, "torse": {"tunique", "mante", "accessoires", "pantalon"}, "mains": set(), "pieds": {"bottes"}}


def _famille(pid):
    if "casque" in pid:
        return "tete"
    if "cuirasse" in pid:
        return "torse"
    if "gant" in pid:
        return "mains"
    return "pieds"


VUE = {"tete": ((0, 0, 1.66), 0.55), "torse": ((0, 0, 1.12), 1.3), "mains": ((0.6, 0, 1.45), 0.75), "pieds": ((0, 0, 0.3), 0.8)}


def apercu(r, dossier, pid, vues=("face", "34", "profil", "dos"), corps=True):
    import apercu as AP
    importlib.reload(AP)
    cache = MASQUE.get(_famille(pid), set())
    for n, o in r.corps.items():
        o.hide_render = (not corps) or n in cache
    cible, ortho = VUE[_famille(pid)]
    AP.rendre(os.path.join(dossier, pid), cible=cible, ortho=ortho, dist=3.0, vues=vues, taille=(480, 640))


def version_sol(r, ob, pid):
    """Pièce posée : copie sans peau d'os ni corps ; cuirasse couchée sur le dos (manches rabattues), casque sur le côté avec
    doublure, gantelets à plat côte à côte, bottes debout ; pivot au sol."""
    import bmesh
    c = ob.copy(); c.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(c)
    c.parent = None
    c.modifiers.clear()
    c.vertex_groups.clear()
    c.matrix_world = Matrix.Identity(4)
    me = c.data
    if "cuirasse" in pid:
        for v in me.vertices:
            p = v.co
            if abs(p.x) > 0.2 and 1.3 < p.z < 1.54:
                s = 1 if p.x > 0 else -1
                o = Vector((0.2 * s, p.y, 1.45))
                d = p - o
                a = math.radians(70) * s
                v.co = o + Vector((d.x * math.cos(a) + d.z * math.sin(a), d.y, -d.x * math.sin(a) + d.z * math.cos(a)))
        me.transform(Matrix.Rotation(math.radians(90), 4, "X"))
    elif "casque" in pid:
        bm = bmesh.new(); bm.from_mesh(me)
        col = bm.loops.layers.float_color.get("Col") or bm.loops.layers.float_color.new("Col")
        faces = list(bm.faces)
        ret = bmesh.ops.duplicate(bm, geom=faces)
        nf = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMFace)]
        nv = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
        bm.normal_update()
        for v in nv:
            v.co = v.co - v.normal * 0.005
        bmesh.ops.reverse_faces(bm, faces=nf)
        for f in nf:
            for lp in f.loops:
                lp[col] = (0.2, 0.18, 0.16, 1.0)
        bm.to_mesh(me); bm.free()
        me.transform(Matrix.Rotation(math.radians(-80), 4, "Y") @ Matrix.Rotation(math.radians(12), 4, "X"))
    elif "gant" in pid:
        me.transform(Matrix.Rotation(math.radians(90), 4, "X"))
        for v in me.vertices:
            s = 1 if v.co.x > 0 else -1
            v.co.x -= s * 0.52
    elif "botte" in pid:
        for v in me.vertices:
            s = 1 if v.co.x > 0 else -1
            v.co.x -= s * 0.05
        me.transform(Matrix.Scale(0.72, 4))      # cuissots compris : la pièce au sol reste sous 75 cm (test)
    zmin = min(v.co.z for v in me.vertices)
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    me.transform(Matrix.Translation((-cx, -cy, -zmin)))
    chemin = os.path.join(C.SOL, pid + ".glb")
    os.makedirs(C.SOL, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    c.select_set(True)
    bpy.context.view_layer.objects.active = c
    kw = dict(filepath=chemin, export_format="GLB", use_selection=True, export_skins=False, export_animations=False,
              export_yup=True, export_materials="EXPORT")
    if "export_vertex_color" in bpy.ops.export_scene.gltf.get_rna_type().properties:
        kw["export_vertex_color"] = "ACTIVE"
    bpy.ops.export_scene.gltf(**kw)
    print("EXPORT SOL", chemin)
    bpy.data.objects.remove(c, do_unlink=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    dossier = None
    if "--apercu" in argv:
        k = argv.index("--apercu"); dossier = argv[k + 1]; del argv[k:k + 2]
    sol = "--pas-sol" not in argv
    exporter = "--pas-export" not in argv
    argv = [a for a in argv if not a.startswith("--")]
    ids = argv or list(PIECES)
    for pid in ids:
        r = C.charger_reference()
        ob = PIECES[pid](r)
        print("PIECE", pid, C.compter_tris(ob), "tris", "groupes", len(ob.vertex_groups),
              "texture", next(n for n in ob.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE").image.size[:])
        _rep = {}
        for _p in ob.data.polygons:
            _m = ob.data.materials[_p.material_index].name.split(".")[0]
            _rep[_m] = _rep.get(_m, 0) + len(_p.vertices) - 2
        print("REPARTITION", pid, _rep)
        if exporter:
            C.exporter([ob], r, os.path.join(C.PORTE, pid + ".glb"))
        if sol and exporter:
            version_sol(r, ob, pid)
        if dossier:
            os.makedirs(dossier, exist_ok=True)
            apercu(r, dossier, pid)
            if "--gros" in sys.argv and _famille(pid) in ("torse", "pieds"):
                # gros plans (col de fourrure / cuissots), corps du héros visible
                import apercu as AP
                for n, o in r.corps.items():
                    o.hide_render = (n in MASQUE[_famille(pid)]) or (_famille(pid) == "pieds" and n not in ("pantalon",))
                cible, ortho = ((0, 0, 1.52), 0.55) if _famille(pid) == "torse" else ((0.1, 0, 0.72), 0.75)
                AP.rendre(os.path.join(dossier, pid + "_gros"), cible=cible, ortho=ortho, dist=3.0, vues=("face", "34", "profil", "dos"), taille=(640, 640))
            for o in r.corps.values():
                o.hide_render = True
            import apercu as AP
            cible, ortho = VUE[_famille(pid)]
            AP.rendre(os.path.join(dossier, pid + "_seul"), cible=cible, ortho=ortho, dist=3.0, vues=("face", "34", "dos"), taille=(480, 640))


main()
