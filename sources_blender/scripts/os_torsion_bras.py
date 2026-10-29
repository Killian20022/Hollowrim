# Os de torsion des avant-bras du bras FPS : deux os par avant-bras, enfants de lowerarm, sur son axe et avec son
# orientation (repos identique à lowerarm, seule leur rotation autour de l'axe coude -> poignet compte) :
#   lowerarm_twist_01_<c> au milieu de l'avant-bras, lowerarm_twist_02_<c> au poignet.
# Poids de peau : la part « lowerarm » de chaque sommet de peau, de manche, de revers de fourrure et de gant est répartie
# progressivement selon s (0 au coude, 1 au poignet) : lowerarm (s = 0) -> twist_01 (s = 0,5) -> twist_02 (s = 1) ; le
# brassard (RIGIDES) suit twist_02 d'un bloc.
# Les parts upperarm / hand / doigts ne changent pas. Godot (scripts/combat/torsion_avant_bras.gd) ramène lowerarm sur la
# charnière du coude et donne à twist_01 un tiers de la pronation, à twist_02 la totalité : la torsion va en douceur du
# coude au poignet au lieu de tomber d'un coup sur l'un des deux.
#   blender.exe -b --python os_torsion_bras.py      (ré-exporte assets/modeles/joueur/bras_fps.glb ; état d'avant :
#   sources_blender/bras_fps_avant_torsion.glb, gardé la première fois et toujours repris comme source)
import bpy, os, shutil

base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
glb = os.path.join(base, "assets", "modeles", "joueur", "bras_fps.glb")
SAUVE = os.path.join(base, "sources_blender", "bras_fps_avant_torsion.glb")
if not os.path.exists(SAUVE):
    shutil.copy(glb, SAUVE)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SAUVE)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')

NOEUDS = [(0.0, "lowerarm_{c}"), (0.5, "lowerarm_twist_01_{c}"), (1.0, "lowerarm_twist_02_{c}")]
# Brassard d'avant-bras (coque de cuir, canon de fer, rivets, sangles, boucles) : une pièce rigide sanglée au poignet, qui
# tourne d'un bloc avec lui (twist_02) par-dessus la peau qui, elle, se tord progressivement (pas de plaques vrillées).
RIGIDES = ("brassard", "canon_", "rivets", "sangle_", "boucle_")

# --- 1. os
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.data.edit_bones
axes = {}
for c in ("l", "r"):
    la = eb["lowerarm_" + c]
    head, tail = la.head.copy(), la.tail.copy()
    axes[c] = (head, tail)
    for s, nom in NOEUDS[1:]:
        nom = nom.format(c=c)
        b = eb.get(nom) or eb.new(nom)
        b.head = head + (tail - head) * (s if s < 1.0 else 0.92)
        b.tail = b.head + (tail - head) * 0.08
        b.roll = la.roll
        b.align_roll(la.z_axis)            # même repère que lowerarm (repos relatif = identité)
        b.parent = la
        b.use_connect = False
        b.use_deform = True
bpy.ops.object.mode_set(mode='OBJECT')
for c in ("l", "r"):
    la = arm.data.bones["lowerarm_" + c]
    for _, nom in NOEUDS[1:]:
        b = arm.data.bones[nom.format(c=c)]
        ecart = (la.matrix_local.to_3x3().inverted() @ b.matrix_local.to_3x3()).to_quaternion().angle
        print("OS", b.name, "écart d'orientation avec lowerarm %.4f°" % (ecart * 57.2958))


# --- 2. poids : part lowerarm répartie selon s
def poids_noeuds(s, c):
    s = min(max(s, 0.0), 1.0)
    out = []
    for k in range(len(NOEUDS) - 1):
        s0, n0 = NOEUDS[k]
        s1, n1 = NOEUDS[k + 1]
        if s0 <= s <= s1:
            t = (s - s0) / (s1 - s0)
            return [(n0.format(c=c), 1.0 - t), (n1.format(c=c), t)]
    return out


nb = {}
for o in bpy.data.objects:
    if o.type != 'MESH' or not o.vertex_groups:
        continue
    for c in ("l", "r"):
        g_l = o.vertex_groups.get("lowerarm_" + c)
        if g_l is None:
            continue
        head, tail = axes[c]
        ax = tail - head
        L2 = ax.length_squared
        groupes = {}
        for s_, nom in NOEUDS:
            nom = nom.format(c=c)
            groupes[nom] = o.vertex_groups.get(nom) or o.vertex_groups.new(name=nom)
        for v in o.data.vertices:
            w = 0.0
            for g in v.groups:
                if g.group == g_l.index:
                    w = g.weight
            if w <= 0.0:
                continue
            # sommets dans le repère de l'armature (les maillages sont enfants de l'armature sans décalage)
            p = o.matrix_world @ v.co
            p = arm.matrix_world.inverted() @ p
            s = (p - head).dot(ax) / L2
            if o.name.startswith(RIGIDES):
                s = 1.0
            g_l.remove([v.index])
            for nom, k in poids_noeuds(s, c):
                if k * w > 1e-4:
                    groupes[nom].add([v.index], k * w, 'ADD')
            nb[o.name] = nb.get(o.name, 0) + 1
for n, k in sorted(nb.items()):
    print("POIDS", n, k, "sommets répartis")

# --- 3. export (mêmes réglages que brassards_skarnholt.py)
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_skins=True,
                          export_animations=False, export_apply=False)
print("EXPORT OK", glb)
