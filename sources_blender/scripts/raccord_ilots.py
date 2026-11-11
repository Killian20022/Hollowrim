# Raccord des « éclats » du poignet (2026-11-11) : appelé par tripo_rig.py et tripo_ennemi_rig.py juste avant l'export, sur le maillage
# déjà cuit en T. Les modèles Tripo décimés sont découpés en îlots (coutures d'UV, décimation) ; près du poignet, quelques petits îlots
# (4 à 10 faces : bouts de lanière, dessous de gant, griffe) touchent le reste à 0,5-3 mm sans y être soudés. outils/controle_modele.gd les
# compte comme éclats flottants, et s'ils n'ont pas les mêmes poids que leurs voisins ils se décollent quand le poignet plie (lame sombre
# qui traverse l'avant-bras du squelette). Ce ne sont PAS des déchets : les supprimer ouvrirait des fentes. On les RACCORDE :
#   - chaque sommet de l'îlot à moins de `dist_max` d'un sommet hors de l'îlot vient se poser dessus (déplacement <= 4 mm, invisible),
#     ce qui soude l'îlot au reste pour le contrôle (même position) sans toucher aux UV (sommets non fusionnés) ;
#   - chaque sommet de l'îlot prend les poids du sommet voisin le plus proche hors de l'îlot : l'îlot suit sa surface sans cisaillement.
# Zone poignet : celle du contrôle un peu élargie (moitié de l'avant-bras -> 1 paume après le poignet au lieu de 0,8, à moins de 0,17 m
# au lieu de 0,15 de l'axe coude -> poignet -> base du majeur ; le contrôle centre l'îlot autrement), calculée sur l'armature au repos.
import bmesh
from mathutils import Vector, kdtree


def _zone(arm, p, rayon=0.17):
    for s in ("l", "r"):
        b = arm.data.bones
        if "lowerarm_" + s not in b or "hand_" + s not in b or "middle_01_" + s not in b:
            continue
        pe = arm.matrix_world @ b["lowerarm_" + s].head_local
        pw = arm.matrix_world @ b["hand_" + s].head_local
        pb = arm.matrix_world @ b["middle_01_" + s].head_local
        lf, lh = (pw - pe).length, (pb - pw).length
        a1 = (pw - pe).normalized()
        t = (p - pe).dot(a1)
        if t < 0.5 * lf or t > lf + 1.0 * lh:
            continue
        ax, o = ((pb - pw).normalized(), pw) if t > lf else (a1, pe)
        q = p - o
        if (q - ax * q.dot(ax)).length <= rayon:
            return True
    return False


def raccorder(obj, arm, eclat_faces=12, soudure=0.0005, dist_max=0.004, log=print):
    me = obj.data
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    cle, rep = {}, []
    for v in bm.verts:
        rep.append(cle.setdefault(tuple(round(c / soudure) for c in v.co), v.index))
    par = list(range(len(bm.verts)))
    def rac(i):
        while par[i] != i:
            par[i] = par[par[i]]; i = par[i]
        return i
    for f in bm.faces:
        r0 = rac(rep[f.verts[0].index])
        for v in f.verts[1:]:
            r1 = rac(rep[v.index])
            if r1 != r0:
                par[r1] = r0
    ilots = {}
    for f in bm.faces:
        ilots.setdefault(rac(rep[f.verts[0].index]), []).append(f)
    mw = obj.matrix_world
    cibles = []
    for r, fs in ilots.items():
        if len(fs) >= eclat_faces:
            continue
        vs = sorted({v.index for f in fs for v in f.verts})
        c = sum((mw @ bm.verts[i].co for i in vs), Vector()) / len(vs)
        if _zone(arm, c):
            cibles.append((r, vs, len(fs)))
    gn = {g.index: g.name for g in obj.vertex_groups}
    groupes = {g.name: g for g in obj.vertex_groups}
    n_ok = 0
    for r, vs, nf in cibles:
        dedans = set(vs)
        autres = [v.index for v in bm.verts if v.index not in dedans and rac(rep[v.index]) != r]
        kd = kdtree.KDTree(len(autres))
        for k, i in enumerate(autres):
            kd.insert(bm.verts[i].co, k)
        kd.balance()
        poses, dmin = 0, 1e9
        for i in vs:
            co, k, d = kd.find(bm.verts[i].co)
            dmin = min(dmin, d)
            j = autres[k]
            # poids du voisin (sommet j du maillage d'origine : mêmes index, bmesh non modifié en topologie)
            for g in list(me.vertices[i].groups):
                obj.vertex_groups[g.group].remove([i])
            for g in me.vertices[j].groups:
                groupes[gn[g.group]].add([i], g.weight, "REPLACE")
            if d <= dist_max:
                bm.verts[i].co = co.copy()
                poses += 1
        c = sum((mw @ bm.verts[i].co for i in vs), Vector()) / len(vs)
        log("raccord : îlot de %d faces en (%.3f %.3f %.3f), écart %.1f mm, %d/%d sommets posés sur leur voisin%s" % (
            nf, c.x, c.y, c.z, dmin * 1000, poses, len(vs), "" if poses else " (TROP LOIN : non raccordé)"))
        n_ok += 1 if poses else 0
    # positions seulement (les poids sont déjà écrits dans me.vertices par les groupes)
    co = [v.co.copy() for v in bm.verts]
    bm.free()
    for i, c in enumerate(co):
        me.vertices[i].co = c
    me.update()
    log("raccord : %d îlots du poignet raccordés sur %d" % (n_ok, len(cibles)))
    return len(cibles), n_ok
