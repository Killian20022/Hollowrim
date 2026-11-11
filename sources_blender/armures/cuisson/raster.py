# Cuisson des armures : RASTÉRISATION d'un maillage dans son espace UV (numpy, sans Cycles).
# Pour chaque texel de l'atlas N x N : triangle couvrant, barycentriques, puis position MONDE, normale lissée (normales de coin, donc
# arêtes vives comprises), UV d'ORIGINE (pour reprendre la peinture de la passe 2), matière, repère tangent (dP/dx, dP/dy en m par
# texel). Convention des images Blender : ligne 0 = bas (v = 0).
import numpy as np


class Carte:
    pass


def rasteriser(ob, uv_cible, uv_source, N):
    me = ob.data
    me.calc_loop_triangles()
    nt = len(me.loop_triangles)
    M = np.array(ob.matrix_world)
    R3 = M[:3, :3]
    co = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]
    lt_loops = np.zeros(nt * 3, np.int64); me.loop_triangles.foreach_get("loops", lt_loops); lt_loops = lt_loops.reshape(-1, 3)
    lt_verts = np.zeros(nt * 3, np.int64); me.loop_triangles.foreach_get("vertices", lt_verts); lt_verts = lt_verts.reshape(-1, 3)
    lt_poly = np.zeros(nt, np.int64); me.loop_triangles.foreach_get("polygon_index", lt_poly)
    pm = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("material_index", pm)
    nl = len(me.loops)
    uvc = np.zeros(nl * 2); me.uv_layers[uv_cible].data.foreach_get("uv", uvc); uvc = uvc.reshape(-1, 2)
    uvs = np.zeros(nl * 2); me.uv_layers[uv_source].data.foreach_get("uv", uvs); uvs = uvs.reshape(-1, 2)
    cn = np.zeros(nl * 3); me.corner_normals.foreach_get("vector", cn); cn = cn.reshape(-1, 3) @ R3.T
    cn /= np.maximum(np.linalg.norm(cn, axis=1, keepdims=True), 1e-9)
    tri = np.full((N, N), -1, np.int64)
    bary = np.zeros((N, N, 3))
    P = uvc[lt_loops] * N                  # (nt, 3, 2) en pixels
    for t in range(nt):
        a, b, c = P[t]
        x0 = max(int(np.floor(min(a[0], b[0], c[0]))), 0); x1 = min(int(np.ceil(max(a[0], b[0], c[0]))), N)
        y0 = max(int(np.floor(min(a[1], b[1], c[1]))), 0); y1 = min(int(np.ceil(max(a[1], b[1], c[1]))), N)
        if x1 <= x0 or y1 <= y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        aire = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        if abs(aire) < 1e-12:
            continue
        w0 = ((b[0] - xs) * (c[1] - ys) - (b[1] - ys) * (c[0] - xs)) / aire
        w1 = ((c[0] - xs) * (a[1] - ys) - (c[1] - ys) * (a[0] - xs)) / aire
        w2 = 1.0 - w0 - w1
        e = -1e-4
        ins = (w0 >= e) & (w1 >= e) & (w2 >= e)
        if not ins.any():
            continue
        yy = ys[ins].astype(np.int64); xx = xs[ins].astype(np.int64)
        tri[yy, xx] = t
        bary[yy, xx] = np.stack([w0[ins], w1[ins], w2[ins]], -1)
    K = Carte()
    K.N = N
    K.masque = tri >= 0
    t = np.where(K.masque, tri, 0)
    K.tri = tri
    bw = bary[..., :, None]
    K.pos = (co[lt_verts[t]] * bw).sum(-2)
    n = (cn[lt_loops[t]] * bw).sum(-2)
    K.nrm = n / np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-9)
    K.uv_src = (uvs[lt_loops[t]] * bw).sum(-2)
    K.mat = np.where(K.masque, pm[lt_poly[t]], -1)
    # repère tangent par triangle : dP/dx, dP/dy (m par texel), dans l'espace du texel de la carte cible
    Pv = co[lt_verts]                     # (nt, 3, 3)
    e1, e2 = Pv[:, 1] - Pv[:, 0], Pv[:, 2] - Pv[:, 0]
    d1, d2 = P[:, 1] - P[:, 0], P[:, 2] - P[:, 0]
    det = d1[:, 0] * d2[:, 1] - d1[:, 1] * d2[:, 0]
    det = np.where(np.abs(det) < 1e-12, 1e-12, det)
    Tx = (e1 * d2[:, 1:2] - e2 * d1[:, 1:2]) / det[:, None]
    Ty = (e2 * d1[:, 0:1] - e1 * d2[:, 0:1]) / det[:, None]
    K.tx = Tx[t]; K.ty = Ty[t]
    return K


def echantillonner(img_np, uv):
    """Plus proche voisin (textures pixel art), uv (..., 2) -> (..., C). img_np : (H, W, C), ligne 0 = bas."""
    H, W = img_np.shape[:2]
    x = np.clip(np.floor(uv[..., 0] % 1.0 * W).astype(np.int64), 0, W - 1)
    y = np.clip(np.floor(uv[..., 1] % 1.0 * H).astype(np.int64), 0, H - 1)
    return img_np[y, x]


def dilater(img, masque, passes=12):
    """Étend les îlots dans les marges (mipmaps sans liseré) : chaque passe recopie la moyenne des voisins valides."""
    img = img.copy(); m = masque.copy()
    for _ in range(passes):
        acc = np.zeros_like(img); cnt = np.zeros(m.shape)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            mm = np.roll(np.roll(m, dy, 0), dx, 1)
            acc += np.roll(np.roll(img, dy, 0), dx, 1) * mm[..., None]
            cnt += mm
        neuf = (~m) & (cnt > 0)
        img[neuf] = acc[neuf] / cnt[neuf][:, None]
        m = m | neuf
    return img
