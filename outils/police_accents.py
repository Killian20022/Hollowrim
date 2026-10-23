import struct
class TTF:
    def __init__(s, fn):
        d = s.d = open(fn,'rb').read()
        n = struct.unpack('>H', d[4:6])[0]; s.t = {}
        for i in range(n):
            tag, cs, off, ln = struct.unpack('>4sIII', d[12+16*i:28+16*i]); s.t[tag.decode()] = (off, ln)
        h = s.t['head'][0]
        s.upem = struct.unpack('>H', d[h+18:h+20])[0]; s.lf = struct.unpack('>h', d[h+50:h+52])[0]
        s.ng = struct.unpack('>H', d[s.t['maxp'][0]+4:s.t['maxp'][0]+6])[0]
        lo = s.t['loca'][0]
        if s.lf == 0: s.loca = [struct.unpack('>H', d[lo+2*i:lo+2*i+2])[0]*2 for i in range(s.ng+1)]
        else: s.loca = [struct.unpack('>I', d[lo+4*i:lo+4*i+4])[0] for i in range(s.ng+1)]
        g = s.t['glyf'][0]
        s.glyphs = [d[g+s.loca[i]:g+s.loca[i+1]] for i in range(s.ng)]
        s.cmap = {}
        c = s.t['cmap'][0]; nt = struct.unpack('>H', d[c+2:c+4])[0]
        for i in range(nt):
            pid, eid, off = struct.unpack('>HHI', d[c+4+8*i:c+12+8*i]); o = c+off
            if struct.unpack('>H', d[o:o+2])[0] != 4: continue
            sc = struct.unpack('>H', d[o+6:o+8])[0]//2
            ends = struct.unpack('>%dH'%sc, d[o+14:o+14+2*sc]); starts = struct.unpack('>%dH'%sc, d[o+16+2*sc:o+16+4*sc])
            deltas = struct.unpack('>%dh'%sc, d[o+16+4*sc:o+16+6*sc]); ro_o = o+16+6*sc
            ros = struct.unpack('>%dH'%sc, d[ro_o:ro_o+2*sc])
            for k in range(sc):
                for ch in range(starts[k], ends[k]+1):
                    if ch == 0xFFFF: continue
                    if ros[k] == 0: gid = (ch + deltas[k]) & 0xFFFF
                    else:
                        a = ro_o + 2*k + ros[k] + 2*(ch-starts[k]); gid = struct.unpack('>H', d[a:a+2])[0]
                        if gid: gid = (gid + deltas[k]) & 0xFFFF
                    s.cmap[ch] = gid
    def contours(s, gid):
        b = s.glyphs[gid]
        if not b: return []
        nc = struct.unpack('>h', b[0:2])[0]
        assert nc >= 0, 'composite'
        ends = struct.unpack('>%dH'%nc, b[10:10+2*nc]); p = 10+2*nc
        il = struct.unpack('>H', b[p:p+2])[0]; p += 2+il
        npt = ends[-1]+1 if nc else 0
        flags = []
        while len(flags) < npt:
            f = b[p]; p += 1; flags.append(f)
            if f & 8:
                r = b[p]; p += 1; flags += [f]*r
        def rd(short, same):
            nonlocal p
            out = []; v = 0
            for f in flags:
                if f & short:
                    dv = b[p]; p += 1; v += dv if f & same else -dv
                elif not (f & same):
                    v += struct.unpack('>h', b[p:p+2])[0]; p += 2
                out.append(v)
            return out
        xs = rd(2, 16); ys = rd(4, 32)
        res = []; st = 0
        for e in ends:
            res.append([(xs[i], ys[i], flags[i] & 1) for i in range(st, e+1)]); st = e+1
        return res


# ---------------------------------------------------------------------------------------------------------------
# C6 — police Kenney corrigée pour le français :  python3 -I outils/police_accents.py <Kenney Pixel.ttf> <sortie.ttf>
# Dans Kenney Pixel (et Kenney Mini), les minuscules accentuées sont des COPIES des capitales (é = É, ç = Ç, à = À) :
# « quête », « brisés » sautaient d'une hauteur de capitale au milieu des mots (relevé de l'audit graphique).
# On reconstruit chaque minuscule accentuée = contours de la minuscule de base + accent repris de la capitale,
# abaissé de (hauteur de capitale - hauteur d'x) et centré sur la lettre. Marche pour Kenney Mini (1 px = 128 unités) et Kenney Pixel (64).
import sys, unicodedata

def encoder(contours):
    pts = [p for c in contours for p in c]
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    out = struct.pack('>hhhhh', len(contours), min(xs), min(ys), max(xs), max(ys))
    fin = -1; ends = []
    for c in contours:
        fin += len(c); ends.append(fin)
    out += struct.pack('>%dH' % len(ends), *ends) + struct.pack('>H', 0)
    out += bytes(p[2] & 1 for p in pts)                       # coordonnées en delta 16 bits, sans répétition
    px = 0
    for x in xs:
        out += struct.pack('>h', x - px); px = x
    py = 0
    for y in ys:
        out += struct.pack('>h', y - py); py = y
    return out, min(xs)

def corriger(f):
    import math
    from functools import reduce
    PX = reduce(math.gcd, [abs(v) for c in f.contours(f.cmap[ord('E')]) for p in c for v in p[:2] if v])   # 1 pixel de police
    remplace = {}
    for code in sorted(f.cmap):
        ch = chr(code)
        if not ch.islower() or not ch.isalpha():
            continue
        dec = unicodedata.normalize('NFD', ch)
        if len(dec) != 2:
            continue
        base, cap = dec[0], ch.upper()
        if ord(base) not in f.cmap or ord(cap) not in f.cmap or ord(base.upper()) not in f.cmap:
            continue
        gb, gc, gB = f.cmap[ord(base)], f.cmap[ord(cap)], f.cmap[ord(base.upper())]
        cB = f.contours(gB); cC = f.contours(gc); cb = f.contours(gb)
        if not cB or not cb:
            continue
        hB = max(p[1] for c in cB for p in c)          # hauteur de la capitale
        hb = max(p[1] for c in cb for p in c)          # hauteur de la minuscule (x ou ascendante)
        haut = [c for c in cC if min(p[1] for p in c) >= hB]   # accent au-dessus
        bas = [c for c in cC if max(p[1] for p in c) <= 0]     # cédille dessous
        if not haut and not bas:
            continue
        if base in "ij":                                # i/j : on retire le point (au-dessus de la hauteur d'x) avant l'accent
            hx = max(p[1] for c in f.contours(f.cmap[ord("x")]) for p in c)
            cb = [c for c in cb if min(p[1] for p in c) < hx]
            hb = max(p[1] for c in cb for p in c)
        cx = lambda cs: (min(p[0] for c in cs for p in c) + max(p[0] for c in cs for p in c)) / 2
        dx = int(round((cx(cb) - cx(cB)) / PX)) * PX
        dy = hb - hB
        neuf = [list(c) for c in cb]
        neuf += [[(p[0] + dx, p[1] + dy, p[2]) for p in c] for c in haut]
        neuf += [[(p[0] + dx, p[1], p[2]) for p in c] for c in bas]
        for c in bas:                                   # cédille : la capitale la rattache par sa barre du bas (sous 0) ;
            x0 = min(p[0] for p in c) + dx                # la minuscule s'arrête à 0 -> on ajoute la tige d'un pixel
            neuf.append([(x0, max(p[1] for p in c), 1), (x0, 0, 1), (x0 + PX, 0, 1), (x0 + PX, max(p[1] for p in c), 1)])
        remplace[f.cmap[code]] = (neuf, gb)
    return remplace

def ecrire(f, remplace, sortie):
    d = f.d
    glyphs = list(f.glyphs)
    lsb = {}
    for g, (cs, gb) in remplace.items():
        glyphs[g], lsb[g] = encoder(cs)
    glyf = b''; loca = []
    for g in glyphs:
        loca.append(len(glyf)); glyf += g + (b'\0' * ((4 - len(g) % 4) % 4))
    loca.append(len(glyf))
    tables = {k: bytearray(d[o:o + l]) for k, (o, l) in f.t.items()}
    tables['glyf'] = bytearray(glyf)
    tables['loca'] = bytearray(struct.pack('>%dI' % len(loca), *loca))
    tables['head'][50:52] = struct.pack('>h', 1)                       # loca longue
    tables['head'][8:12] = b'\0\0\0\0'
    # hmtx : avance et approche gauche reprises de la minuscule de base
    nh = struct.unpack('>H', tables['hhea'][34:36])[0]
    hm = tables['hmtx']
    def adv(g):
        i = min(g, nh - 1); return struct.unpack('>H', hm[4 * i:4 * i + 2])[0]
    for g, (cs, gb) in remplace.items():
        assert g < nh
        hm[4 * g:4 * g + 4] = struct.pack('>Hh', adv(gb), lsb[g])
    # maxp : maxima de points / contours
    mp = tables['maxp']
    npts = max(struct.unpack('>H', mp[6:8])[0], *(sum(len(c) for c in cs) for cs, _ in remplace.values()))
    ncs = max(struct.unpack('>H', mp[8:10])[0], *(len(cs) for cs, _ in remplace.values()))
    mp[6:10] = struct.pack('>HH', npts, ncs)
    noms = sorted(tables)
    n = len(noms)
    es = 1
    while es * 2 <= n: es *= 2
    entete = struct.pack('>IHHHH', 0x00010000, n, es * 16, (es.bit_length() - 1), n * 16 - es * 16)
    def somme(b):
        b = bytes(b) + b'\0' * ((4 - len(b) % 4) % 4)
        return sum(struct.unpack('>%dI' % (len(b) // 4), b)) & 0xFFFFFFFF
    off = 12 + 16 * n; rep = b''; corps = b''
    for k in noms:
        t = bytes(tables[k])
        rep += struct.pack('>4sIII', k.encode(), somme(t), off + len(corps), len(t))
        corps += t + b'\0' * ((4 - len(t) % 4) % 4)
    tout = bytearray(entete + rep + corps)
    # checkSumAdjustment de head
    ho = [struct.unpack('>I', tout[12 + 16 * i + 8:12 + 16 * i + 12])[0] for i, k in enumerate(noms) if k == 'head'][0]
    tout[ho + 8:ho + 12] = struct.pack('>I', (0xB1B0AFBA - somme(tout)) & 0xFFFFFFFF)
    open(sortie, 'wb').write(tout)

if __name__ == '__main__':
    f = TTF(sys.argv[1])
    r = corriger(f)
    ecrire(f, r, sys.argv[2])
    print('corrigés :', ''.join(sorted(chr(c) for c, g in f.cmap.items() if g in r)))
