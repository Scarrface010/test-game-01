"""Original sci-fi tile kit, 32x32. Usage: python3 -I tiles.py OUTDIR"""
import sys, random, os
from PIL import Image, ImageDraw

def hx(s):
    s = s.lstrip('#'); return tuple(int(s[i:i+2], 16) for i in (0, 2, 4)) + (255,)
def sh(c, f):  # f>0 lighten, f<0 darken
    if f >= 0: return tuple(int(c[i] + (255 - c[i]) * f) for i in range(3)) + (255,)
    return tuple(int(c[i] * (1 + f)) for i in range(3)) + (255,)

class T:
    def __init__(s, base, seed):
        s.im = Image.new('RGBA', (32, 32), base); s.d = ImageDraw.Draw(s.im); s.r = random.Random(seed); s.base = base
    def px(s, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32: s.im.putpixel((x, y), c)
    def rect(s, x, y, w, h, c): s.d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)
    def line(s, a, b, c, c2=None, w=1): s.d.line([a, b], fill=c, width=w)
    def noise(s, n, f=0.05):
        for _ in range(n):
            s.px(s.r.randrange(32), s.r.randrange(32), sh(s.base, f if s.r.random() < .5 else -f * 1.4))
    def bevel(s, c=None, hi=.14, lo=-.35):
        c = c or s.base
        for i in range(32):
            s.px(i, 0, sh(c, hi)); s.px(0, i, sh(c, hi * .6))
            s.px(i, 31, sh(c, lo)); s.px(31, i, sh(c, lo))
    def rivet(s, x, y, c):
        s.px(x, y, sh(c, .5)); s.px(x + 1, y, sh(c, .1)); s.px(x, y + 1, sh(c, .1)); s.px(x + 1, y + 1, sh(c, -.5))
    def hazard(s, x, y, w, h, a=hx('e0b020'), b=hx('1c1f28')):
        for i in range(x, x + w):
            for j in range(y, y + h):
                s.px(i, j, a if ((i + j) // 3) % 2 == 0 else b)
    def led(s, x, y, c):
        s.px(x, y, c); s.px(x - 1, y, sh(c, -.6)); s.px(x + 1, y, sh(c, -.6)); s.px(x, y - 1, sh(c, -.6)); s.px(x, y + 1, sh(c, -.6))
    def save(s, p): s.im.save(p)

# ---------------------------------------------------------------- floors
def floor(ti, parity, v):
    P = [
        (hx('232c48'), hx('2a3556')),   # derelict steel
        (hx('1b3427'), hx('223f2f')),   # greenhouse deck
        (hx('3a2a20'), hx('443226')),   # hold diamond plate
        (hx('231a42'), hx('2b2050')),   # crystal hull
    ][ti][parity]
    t = T(P, ti * 1000 + parity * 100 + v * 7 + 3); r = t.r
    t.noise(70)
    k = v % 8
    if ti == 0:
        t.bevel(); dk = sh(P, -.5)
        t.line((16, 1), (16, 30), dk) if k in (1, 5) else None
        if k == 0: [t.rivet(a, b, P) for a in (3, 26) for b in (3, 26)]
        if k == 1:
            t.line((1, 15), (30, 15), dk); [t.rivet(a, b, P) for a in (3, 26) for b in (3, 26)]
        if k == 2:  # grating
            t.rect(5, 5, 22, 22, sh(P, -.6))
            for i in range(6, 26, 3): t.rect(6, i, 20, 1, sh(P, .12)); t.rect(6, i + 1, 20, 1, sh(P, -.2))
            t.d.rectangle([4, 4, 27, 27], outline=sh(P, .2))
        if k == 3:  # vent
            t.rect(8, 8, 16, 16, sh(P, -.55)); t.d.rectangle([7, 7, 24, 24], outline=sh(P, .25))
            for i in range(9, 23, 3): t.rect(9, i, 14, 1, sh(P, .2)); t.rect(9, i + 1, 14, 1, sh(P, -.7))
        if k == 4:  # hazard edge
            t.hazard(0, 25, 32, 5); t.rect(0, 24, 32, 1, sh(P, -.7)); t.rect(0, 30, 32, 1, sh(P, -.7))
        if k == 5:  # cable run
            for dx in (0, 3):
                t.line((0, 20 + dx), (31, 14 + dx), hx('15171f'), w=2)
            t.line((0, 19), (31, 13), hx('4fd1ff')); t.rect(12, 12, 8, 10, sh(P, -.3)); t.rect(13, 13, 6, 8, sh(P, .05))
        if k == 6:  # scorch + crack
            for _ in range(40):
                t.px(r.randrange(6, 26), r.randrange(6, 26), sh(P, -.7))
            pts = [(6, 5), (12, 12), (11, 16), (19, 22), (24, 28)]
            for a, b in zip(pts, pts[1:]): t.line(a, b, hx('0b0e18'))
        if k == 7:  # light strip
            t.rect(3, 14, 26, 4, hx('0b0e18')); t.rect(4, 15, 24, 2, hx('2f8fb0') if parity else hx('4fd1ff'))
            t.rect(4, 15, 24, 1, hx('9fe8ff'))
    elif ti == 1:
        t.bevel(); dk = sh(P, -.5); soil = hx('4a3220'); leaf = hx('5fc06a')
        if k == 0: [t.rivet(a, b, P) for a in (3, 26) for b in (3, 26)]
        if k == 1:  # planter tray
            t.rect(3, 6, 26, 20, hx('2a2118')); t.rect(4, 7, 24, 18, soil)
            for _ in range(40): t.px(r.randrange(4, 28), r.randrange(7, 25), sh(soil, .12) if r.random() < .5 else sh(soil, -.3))
            for x in range(6, 28, 6):
                t.px(x, 12, leaf); t.px(x - 1, 11, sh(leaf, .3)); t.px(x + 1, 11, sh(leaf, -.2)); t.px(x, 13, sh(leaf, -.4))
        if k == 2:  # mesh grating
            t.rect(4, 4, 24, 24, hx('0b1511'))
            for i in range(5, 27, 4):
                t.rect(i, 5, 1, 22, sh(P, .15)); t.rect(5, i, 22, 1, sh(P, .15))
        if k == 3:  # water channel
            t.rect(0, 12, 32, 8, hx('0c2a3a')); t.rect(0, 12, 32, 1, hx('1c5a74'))
            for i in range(2, 30, 6): t.rect(i, 15, 3, 1, hx('4fb7d8'))
            t.rect(0, 11, 32, 1, dk); t.rect(0, 20, 32, 1, dk)
        if k == 4:  # grow-light plate
            t.rect(6, 6, 20, 20, hx('10241a')); t.d.rectangle([6, 6, 25, 25], outline=sh(P, .25))
            t.rect(9, 9, 14, 14, hx('d9a0e8')); t.rect(10, 10, 12, 12, hx('f4d6ff')); t.rect(12, 12, 8, 8, hx('ffffff'))
        if k == 5:  # leaf litter / overgrowth
            for _ in range(7):
                x, y = r.randrange(3, 27), r.randrange(3, 27)
                t.d.polygon([(x, y), (x + 3, y - 2), (x + 5, y + 1), (x + 2, y + 3)], fill=sh(leaf, r.choice((-.3, 0, .2))))
        if k == 6:  # hazard + hose
            t.hazard(0, 2, 32, 4); t.line((0, 24), (31, 20), hx('1a1a20'), w=3); t.line((0, 23), (31, 19), hx('3a8a52'))
        if k == 7:  # seedling pot
            t.disc = None; t.rect(11, 18, 10, 8, hx('8a5a3a')); t.rect(10, 17, 12, 2, hx('a8704a'))
            t.rect(15, 10, 2, 8, hx('3a8a52')); t.d.polygon([(16, 10), (8, 8), (13, 13)], fill=leaf); t.d.polygon([(16, 11), (24, 8), (19, 14)], fill=sh(leaf, .2))
    elif ti == 2:
        t.bevel(); dk = sh(P, -.5)
        for i in range(-32, 64, 8):  # diamond plate
            for j in range(0, 32, 8):
                x, y = i + (4 if (j // 8) % 2 else 0), j + 3
                t.line((x, y + 1), (x + 3, y - 1), sh(P, .25)); t.line((x + 1, y + 2), (x + 3, y + 1), sh(P, -.4))
        if k == 0: [t.rivet(a, b, P) for a in (3, 26) for b in (3, 26)]
        if k == 1: t.rect(0, 14, 32, 4, hx('d9962a')); t.rect(0, 14, 32, 1, hx('f0b64a')); t.rect(0, 17, 32, 1, hx('8a5a1a'))
        if k == 2:  # tie-down ring
            t.rect(12, 12, 8, 8, sh(P, -.5)); t.d.ellipse([12, 12, 19, 19], outline=hx('b0b6c4'), fill=hx('14141a'))
        if k == 3:  # stencil square + marks
            t.d.rectangle([5, 5, 26, 26], outline=hx('d9962a'))
            t.rect(5, 5, 6, 1, P); t.rect(5, 5, 1, 6, P); t.rect(21, 26, 6, 1, P); t.rect(26, 21, 1, 6, P)
        if k == 4: t.hazard(0, 0, 32, 5); t.hazard(0, 27, 32, 5)
        if k == 5:  # spill + oil
            t.d.ellipse([6, 10, 24, 25], fill=hx('15100c')); t.d.ellipse([9, 12, 17, 17], fill=hx('2a2a3a'))
        if k == 6:  # scuff + dented
            for _ in range(5):
                x, y = r.randrange(4, 24), r.randrange(4, 28); t.line((x, y), (x + r.randrange(3, 8), y + r.randrange(-2, 3)), sh(P, -.6))
        if k == 7:  # arrow stencil
            t.d.polygon([(7, 14), (18, 14), (18, 9), (26, 16), (18, 23), (18, 18), (7, 18)], fill=hx('d9962a'))
    else:
        t.bevel(); cy = hx('7fe8ff'); mg = hx('d58cff')
        if k == 0: [t.rivet(a, b, P) for a in (3, 26) for b in (3, 26)]
        if k in (1, 2, 5):  # cracked hull with crystal vein
            n = 3 if k != 5 else 5
            x, y = r.randrange(3, 10), 1
            for _ in range(n + 3):
                nx, ny = x + r.randrange(-4, 6), y + r.randrange(4, 8)
                t.line((x, y), (nx, ny), hx('08040f'), w=1); t.line((x + 1, y), (nx + 1, ny), sh(mg, -.2) if k != 2 else cy)
                x, y = max(1, min(30, nx)), ny
        if k == 3:  # crystal cluster growing through the plate
            for x, hgt in ((10, 8), (15, 13), (20, 9)):
                t.d.polygon([(x - 2, 26), (x, 26 - hgt), (x + 2, 26)], fill=sh(mg, -.1)); t.d.polygon([(x, 26 - hgt), (x + 2, 26), (x, 26)], fill=sh(mg, -.5))
                t.px(x - 1, 26 - hgt + 3, hx('ffffff'))
        if k == 4:  # glowing node
            t.d.ellipse([9, 9, 22, 22], fill=hx('120a24')); t.d.ellipse([12, 12, 19, 19], fill=mg); t.d.ellipse([14, 14, 17, 17], fill=hx('ffffff'))
        if k == 6:
            for _ in range(8):
                x, y = r.randrange(3, 28), r.randrange(3, 28); t.px(x, y, cy); t.px(x + 1, y, sh(cy, -.5)); t.px(x, y + 1, sh(cy, -.5))
        if k == 7: t.hazard(0, 26, 32, 4, hx('b060e0'), hx('120a24'))
    return t.im

# ---------------------------------------------------------------- walls
def wall(ti):
    B = [hx('56607f'), hx('3f6b3a'), hx('8a6a45'), hx('6a4fa0')][ti]
    t = T(B, 555 + ti); r = t.r; t.noise(60)
    if ti == 0:  # bulkhead: recessed panel, conduit, hazard foot, red warning lamp
        t.bevel(B, .3, -.65); t.rect(4, 5, 24, 14, sh(B, -.25)); t.rect(4, 5, 24, 1, sh(B, -.6)); t.rect(4, 18, 24, 1, sh(B, .2))
        for x in range(6, 26, 3): t.rect(x, 8, 2, 8, sh(B, -.55)); t.rect(x + 1, 8, 1, 8, sh(B, .1))
        for a, b in ((2, 2), (27, 2), (2, 27), (27, 27)): t.rivet(a, b, B)
        t.hazard(3, 22, 26, 4); t.led(16, 12, hx('ff5d5d'))
    elif ti == 1:  # greenhouse frame: glass panes with leaves behind
        t.bevel(B, .3, -.65); fr = hx('2c4a2a')
        for (x, y) in ((3, 3), (17, 3), (3, 17), (17, 17)):
            t.rect(x, y, 12, 12, hx('0f2a22')); t.rect(x, y, 12, 1, hx('2f6a5a')); t.rect(x, y, 1, 12, hx('2f6a5a'))
            t.d.polygon([(x + 3, y + 10), (x + 6, y + 3), (x + 9, y + 10)], fill=hx('2f8a4a'))
            t.line((x + 2, y + 9), (x + 9, y + 2), hx('9fe8d8'))
        t.rect(15, 0, 2, 32, fr); t.rect(0, 15, 32, 2, fr); t.rect(15, 0, 1, 32, sh(fr, .3))
        for a, b in ((14, 14), (16, 14), (14, 16), (16, 16)): t.px(a, b, hx('c8d0c0'))
    elif ti == 2:  # shipping container corrugation + number plate
        t.bevel(B, .3, -.65)
        for x in range(2, 30, 4): t.rect(x, 2, 2, 28, sh(B, .18)); t.rect(x + 2, 2, 1, 28, sh(B, -.4))
        t.rect(8, 10, 16, 9, hx('14141a')); t.d.rectangle([8, 10, 23, 18], outline=hx('d9962a'))
        for x in (10, 13, 17, 20): t.rect(x, 12, 2, 5, hx('d9962a'))
        t.rect(0, 0, 32, 2, hx('d9962a')); t.rect(0, 30, 32, 2, hx('5a3a1a'))
    else:  # hull breach: crystal spikes erupting from a cracked panel
        t.bevel(B, .3, -.65); t.rect(3, 3, 26, 26, sh(B, -.3)); t.d.rectangle([3, 3, 28, 28], outline=sh(B, .25))
        for x, hh in ((7, 14), (12, 22), (18, 18), (23, 12)):
            t.d.polygon([(x - 3, 28), (x, 28 - hh), (x + 3, 28)], fill=hx('d58cff')); t.d.polygon([(x, 28 - hh), (x + 3, 28), (x, 28)], fill=hx('7a3aa8'))
            t.px(x - 1, 28 - hh + 4, hx('ffffff'))
        t.line((3, 3), (12, 12), hx('08040f')); t.led(26, 6, hx('7fe8ff'))
    return t.im

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    for ti in range(4):
        wall(ti).save(f'{out}/wall{ti}.png')
        for p in range(2):
            for v in range(16): floor(ti, p, v).save(f'{out}/floor{ti}_{p}_{v}.png')
