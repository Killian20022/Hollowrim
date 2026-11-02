# Armures lourdes portées (agent Y) : génère les glb portés (assets/modeles/armures/porte/<id>.glb) et au sol (sol/<id>.glb).
#   blender.exe -b --python sources_blender/armures/lourdes/generer.py -- [ids...] [--apercu DOSSIER] [--pas-sol]
# Sans id : toutes les pièces lourdes (fer, acier nordique) et les 6 uniques.
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import commun as C
import pieces as PC
importlib.reload(C); importlib.reload(PC)
from mathutils import Vector, Matrix

# ------------------------------------------------------------------------------------------------ styles
FER = dict(pal=C.FER, mat="fer", mat_rebord="fer", mat_main="fer", mat_doigts="cuir", mat_genou="fer", base=0.5, pal_cuir=C.CUIR, oxyde=0.35,
           crasse=0.45, poli=0.45, graine=11)
ACIER = dict(pal=C.ACIER, mat="acier", mat_maille="acier.maille", mat_rebord="acier", mat_main="acier", mat_doigts="acier", mat_genou="acier", base=0.46,
             oxyde=0.0, crasse=0.38, poli=0.65, graver=True, graine=23, pal_maille=C.ACIER)

def _s(b0, **kw):
    d = dict(b0); d.update(kw); return d

PIECES = {
    # --- fer
    "casque_fer": lambda r: PC.casque(r, _s(FER, id="casque_fer", bombe=0.012, decor=[PC.deco_nasal])),
    "cuirasse_fer": lambda r: PC.cuirasse(r, _s(FER, id="cuirasse_fer", lames=4)),
    "gantelets_fer": lambda r: PC.gantelets(r, _s(FER, id="gantelets_fer")),
    "bottes_fer": lambda r: PC.bottes(r, _s(FER, id="bottes_fer")),
    # --- acier nordique
    "casque_acier_nordique": lambda r: PC.casque(r, _s(ACIER, id="casque_acier_nordique", bas=(0.0, -0.25, -0.55), bandes=2,
                                                      decor=[PC.deco_joues, PC.deco_cornes], mat_rebord="acier",
                                                      peinture_corne=C.metal(["#1b1712", "#2c261e", "#423a2e", "#5c5242", "#786c58", "#958870", "#b2a58b", "#cfc3a8"], 31, base=0.6, contraste=0.4, poli=0.5))),
    "cuirasse_acier_nordique": lambda r: PC.cuirasse(r, _s(ACIER, id="cuirasse_acier_nordique", lames=3, bombe=0.02, fourrure=True,
                                                           lames_epaule=3)),
    "gantelets_acier_nordique": lambda r: PC.gantelets(r, _s(ACIER, id="gantelets_acier_nordique", evasement=0.035)),
    "bottes_acier_nordique": lambda r: PC.bottes(r, _s(ACIER, id="bottes_acier_nordique",
                                                       peinture_botte=C.metal(C.ACIER, 41, base=0.5, contraste=0.3, crasse=0.3, poli=0.7))),
    # --- pièces uniques (ids de data/objets/armures.json)
    "heaume_jarl": lambda r: PC.casque(r, _s(FER, id="heaume_jarl", pal=C.FER_NOIR, mat="fer.noir", mat_rebord="fer.noir", base=0.5, oxyde=0.1,
                                            crasse=0.3, poli=0.6, bombe=0.006, graver=True, bandes=0,
                                            decor=[lambda *a: PC.deco_nasal(*a, mat="fer.noir"), PC.deco_couronne],
                                            peinture_corne=C.metal(C.FER_NOIR, 71, base=0.55, contraste=0.35, poli=0.7))),
    "cuirasse_gardiens": lambda r: PC.cuirasse(r, _s(ACIER, id="cuirasse_gardiens", mat="acier.givre", lames=3, bombe=0.02, fourrure=True,
                                                     base=0.42, givre=0.75, graine=37, pal_fourrure=C.FOURRURE_BLANCHE, base_fourrure=0.45)),
    "gantelets_hrafn": lambda r: PC.gantelets(r, _s(FER, id="gantelets_hrafn", mat="cuir", mat_main="cuir", mat_doigts="cuir",
                                                    mat_griffes="acier", griffes=0.016, evasement=0.012, rivets=False, lames_main=False,
                                                    debut_manchette=0.6, pal=C.CUIR_ROUGE,
                                                    peinture_manchette=C.cuir(C.CUIR_ROUGE, 81, base=0.5),
                                                    peinture_main=C.cuir(C.CUIR_ROUGE, 82, base=0.55),
                                                    peinture_doigts=C.cuir(C.CUIR_ROUGE, 83, base=0.48))),
    "bottes_rodeur": lambda r: PC.bottes(r, _s(FER, id="bottes_rodeur", mat_botte="fourrure", greve=False, revers=True, sangles=False,
                                                peinture_botte=C.fourrure(C.FOURRURE_BLANCHE, 91, base=0.6),
                                                peinture_revers=C.fourrure(C.FOURRURE_BLANCHE, 92, base=0.7),
                                                decor=[PC.deco_runes_bottes])),
    "capuche_thaumaturge": lambda r: PC.capuche(r, dict(id="capuche_thaumaturge")),
    "brigandine_braise": lambda r: PC.cuirasse(r, _s(FER, id="brigandine_braise", mat="cuir.braise", mat_maille="cuir.ecailles", lames=4, lames_epaule=2,
                                                     rivets=False, pal=C.CUIR_CENDRE, graine=101,
                                                     peinture_maille=C.ecailles(C.CUIR_CENDRE, 102, base=0.45, braise=0.4),
                                                     peinture_plaques=C.ecailles(C.CUIR_CENDRE, 103, base=0.5, braise=0.75))),
}
# matières des bottes d'acier : la botte elle-même est en acier (solerets)
SOLERETS = {"bottes_acier_nordique"}

def construire(pid):
    r = C.charger_reference()
    ob = PIECES[pid](r)
    if pid in SOLERETS:
        for m in ob.data.materials:
            pass
    return r, ob

def apercu(r, ob, dossier, pid, corps=True):
    import apercu as AP
    importlib.reload(AP)
    cache = MASQUE.get(_famille(pid), set())
    for n, o in r.corps.items():
        o.hide_render = (not corps) or n in cache
    AP.rendre(os.path.join(dossier, pid), cible=_cible(pid), ortho=_ortho(pid), dist=3.0, vues=("face", "34", "profil", "dos"), taille=(360, 480))

# pièces du corps cachées sous chaque emplacement (pour les aperçus ; le jeu : scripts/rpg/armure_visible.gd de l'agent X)
MASQUE = {"tete": {"Hair_Long"}, "torse": {"tunique", "mante", "accessoires"}, "mains": set(), "pieds": {"bottes"}}

def _famille(pid):
    if any(k in pid for k in ("casque", "heaume", "capuche")):
        return "tete"
    if any(k in pid for k in ("cuirasse", "brigandine")):
        return "torse"
    if "gant" in pid:
        return "mains"
    return "pieds"

def _cible(pid):
    if "casque" in pid or "heaume" in pid or "capuche" in pid:
        return (0, 0, 1.66)
    if "botte" in pid:
        return (0, 0, 0.3)
    if "gant" in pid:
        return (0.6, 0, 1.45)
    return (0, 0, 1.15)

def _ortho(pid):
    if "casque" in pid or "heaume" in pid or "capuche" in pid:
        return 0.55
    if "botte" in pid:
        return 0.8
    if "gant" in pid:
        return 0.75
    return 1.25

def version_sol(r, ob, pid):
    """Pièce posée : copie sans peau d'os, couchée (torse sur le dos, gantelets à plat) ou debout (casque, bottes), pivot au sol."""
    c = ob.copy(); c.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(c)
    c.parent = None
    c.modifiers.clear()
    c.vertex_groups.clear()
    c.matrix_world = Matrix.Identity(4)
    me = c.data
    if "cuirasse" in pid or "brigandine" in pid:
        # couchée sur le dos : rotation -90° autour de X (le dos vers le sol), manches rabattues le long du corps
        for v in me.vertices:
            p = v.co
            if abs(p.x) > 0.2 and p.z > 1.3:          # manches / épaulières : repliées vers le bas (angle 70°)
                s = 1 if p.x > 0 else -1
                o = Vector((0.2 * s, p.y, 1.45))
                d = p - o
                a = math.radians(70) * s
                x = d.x * math.cos(a) + d.z * math.sin(a)
                z = -d.x * math.sin(a) + d.z * math.cos(a)
                v.co = o + Vector((x, d.y, z))
        me.transform(Matrix.Rotation(math.radians(90), 4, "X"))
    elif "gant" in pid:
        me.transform(Matrix.Rotation(math.radians(90), 4, "X"))
        # rapprochés : les deux mains côte à côte
        for v in me.vertices:
            s = 1 if v.co.x > 0 else -1
            v.co.x -= s * 0.52
    elif "botte" in pid:
        for v in me.vertices:
            s = 1 if v.co.x > 0 else -1
            v.co.x -= s * 0.05
    zmin = min(v.co.z for v in me.vertices)
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    me.transform(Matrix.Translation((-cx, -cy, -zmin)))
    chemin = os.path.join(C.SOL, pid + ".glb")
    os.makedirs(C.SOL, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    c.select_set(True)
    bpy.context.view_layer.objects.active = c
    bpy.ops.export_scene.gltf(filepath=chemin, export_format="GLB", use_selection=True, export_skins=False, export_animations=False,
                              export_yup=True, export_materials="EXPORT")
    print("EXPORT SOL", chemin)
    bpy.data.objects.remove(c, do_unlink=True)

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    dossier = None
    if "--apercu" in argv:
        k = argv.index("--apercu"); dossier = argv[k + 1]; del argv[k:k + 2]
    sol = "--pas-sol" not in argv
    argv = [a for a in argv if not a.startswith("--")]
    ids = argv or list(PIECES)
    for pid in ids:
        r, ob = construire(pid)
        print("PIECE", pid, C.compter_tris(ob), "tris", "groupes", len(ob.vertex_groups))
        C.exporter([ob], r, os.path.join(C.PORTE, pid + ".glb"))
        if sol:
            version_sol(r, ob, pid)
        if dossier:
            apercu(r, ob, dossier, pid)
            r.corps and None
            for o in r.corps.values():
                o.hide_render = True
            import apercu as AP
            AP.rendre(os.path.join(dossier, pid + "_seul"), cible=_cible(pid), ortho=_ortho(pid), dist=3.0, vues=("face", "34", "dos"), taille=(360, 480))

main()
