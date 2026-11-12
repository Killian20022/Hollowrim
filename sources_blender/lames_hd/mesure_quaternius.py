# Mesure du contour des modèles Quaternius CC0 (assets/modeles/armes/cc0_essai/0x_*.glb) : coupes par plans à intervalles
# réguliers. Sert à lames_hd_v2.py (silhouette d'origine reprise, détail HD par-dessus). Repère Blender après import glTF :
# Z = le long de la lame (glTF Y), X = tranchant, Y = épaisseur. `echelle` / `dz` : montage des anciens .tscn (dague x1,3, -0,009).
import bpy, math, os


def triangles(chemin, echelle=1.0, dz=0.0):
    """{matériau de base : [triangles (3 points)]} en coordonnées monde."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=chemin)
    res = {}
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        me = o.data
        me.calc_loop_triangles()
        M = o.matrix_world
        for t in me.loop_triangles:
            nom = o.material_slots[t.material_index].name.split(".")[0] if o.material_slots else "?"
            pts = []
            for v in t.vertices:
                p = M @ me.vertices[v].co
                pts.append((p.x * echelle, p.y * echelle, p.z * echelle + dz))
            res.setdefault(nom, []).append(pts)
    return res


def coupe(tris, axe, val):
    """Points d'intersection des arêtes des triangles avec le plan axe = val."""
    pts = []
    for t in tris:
        for i in range(3):
            a, b = t[i], t[(i + 1) % 3]
            da, db = a[axe] - val, b[axe] - val
            if da == 0.0:
                pts.append(a)
            if (da < 0 < db) or (db < 0 < da):
                u = da / (da - db)
                pts.append(tuple(a[k] + (b[k] - a[k]) * u for k in range(3)))
    return pts


def etendue(tris, axe):
    vals = [p[axe] for t in tris for p in t]
    return min(vals), max(vals)


def profil(tris, axe, valeurs):
    """Pour chaque plan : (val, min/max des deux autres axes) ; None si le plan ne coupe rien."""
    autres = [k for k in range(3) if k != axe]
    out = []
    for v in valeurs:
        pts = coupe(tris, axe, v)
        if not pts:
            out.append((v, None))
            continue
        out.append((v, tuple((min(p[k] for p in pts), max(p[k] for p in pts)) for k in autres)))
    return out


def sommets_z(tris, z0, z1):
    return sorted(set(round(p[2], 5) for t in tris for p in t if z0 <= p[2] <= z1))


def filtrer(tris, zmin=-9.0, zmax=9.0):
    """Triangles dont le centre est dans [zmin, zmax]."""
    return [t for t in tris if zmin <= (t[0][2] + t[1][2] + t[2][2]) / 3 <= zmax]
