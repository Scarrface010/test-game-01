"""Original sci-fi enemy sprites, 32x32. Usage: python3 -I mons.py OUTDIR  -> mon_atlas.png (8 cols x 40 rows) + sheet.png"""
import sys, os
from PIL import Image, ImageDraw

def hx(s):
    s = s.lstrip('#'); return tuple(int(s[i:i+2], 16) for i in (0, 2, 4)) + (255,)
def sh(c, f):
    if f >= 0: return tuple(int(c[i] + (255 - c[i]) * f) for i in range(3)) + (255,)
    return tuple(int(c[i] * (1 + f)) for i in range(3)) + (255,)

STEEL, STEEL_D, DK, LT = hx('8a93b5'), hx('4a526e'), hx('232840'), hx('c8d0e8')
RED, CY, YL, GRN, OR, MG, WH = hx('ff4a4a'), hx('4fd1ff'), hx('ffd84f'), hx('6dff9a'), hx('ff9a3c'), hx('d58cff'), hx('ffffff')
BLK = hx('14141c')

class M:
    def __init__(s, dirn=0, blink=False):
        s.im = Image.new('RGBA', (32, 32), (0, 0, 0, 0)); s.d = ImageDraw.Draw(s.im)
        s.fx = 0 if dirn in (0, 1) else 3; s.back = dirn == 1; s.blink = blink; s.dirn = dirn
    def _shape(s, fn, c):
        m = Image.new('L', (32, 32), 0); fn(ImageDraw.Draw(m)); p = m.load()
        g = lambda x, y: p[x, y] if 0 <= x < 32 and 0 <= y < 32 else 0
        for y in range(32):
            for x in range(32):
                if p[x, y]:
                    col = c
                    if not g(x, y - 1) or (not g(x - 1, y) and g(x, y + 1)): col = sh(c, .25)
                    elif not g(x, y + 1) or not g(x + 1, y): col = sh(c, -.3)
                    s.im.putpixel((x, y), col)
    def ell(s, cx, cy, rx, ry, c): s._shape(lambda d: d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255), c)
    def rect(s, x, y, w, h, c): s._shape(lambda d: d.rectangle([x, y, x + w - 1, y + h - 1], fill=255), c)
    def rrect(s, x, y, w, h, c): s._shape(lambda d: d.rounded_rectangle([x, y, x + w - 1, y + h - 1], radius=2, fill=255), c)
    def poly(s, pts, c): s._shape(lambda d: d.polygon(pts, fill=255), c)
    def line(s, a, b, c, w=1): s._shape(lambda d: d.line([a, b], fill=255, width=w), c)
    def px(s, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32: s.im.putpixel((int(x), int(y)), c)
    def flat(s, x, y, w, h, c): s.d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)
    def fline(s, a, b, c, w=1): s.d.line([a, b], fill=c, width=w)
    def fell(s, cx, cy, rx, ry, c): s.d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=c)
    def eye(s, x, y, c=RED, r=1):
        if s.back: return
        x += s.fx
        if s.blink: s.flat(x - r, y, 2 * r + 1, 1, DK); return
        s.flat(x - r - 1, y - r, 2 * r + 3, 2 * r + 1, BLK); s.flat(x - r, y - r + 1 if r > 0 else y, 2 * r + 1, 2 * r - 1 if r > 0 else 1, c)
        s.px(x - r, y - r + 1 if r > 0 else y, sh(c, .7))
    def glow(s, x, y, c, r=1):  # non-blinking light
        s.px(x, y, c)
        if r > 1: [s.px(x + a, y + b, sh(c, -.45)) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))]
    def done(s):
        im = s.im.copy(); p = s.im.load(); o = hx('0a0d1a')
        for y in range(32):
            for x in range(32):
                if p[x, y][3] == 0:
                    for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + a, y + b
                        if 0 <= xx < 32 and 0 <= yy < 32 and p[xx, yy][3] > 0: im.putpixel((x, y), o); break
        if s.dirn == 2: im = im.transpose(Image.FLIP_LEFT_RIGHT)
        return im

# ============================================================ humanoid helper
def human(m, skin, suit, suit2, boots, tw=7, hy=8, hr=5, ly=21):
    m.rect(11, ly, 4, 9 - (ly - 21), suit2); m.rect(17, ly, 4, 9 - (ly - 21), suit2)
    m.rrect(10, 27, 6, 3, boots); m.rrect(16, 27, 6, 3, boots)
    m.rect(16 - tw - 3, 13, 4, 9, suit); m.rect(16 + tw - 1, 13, 4, 9, suit)
    m.ell(16 - tw - 1, 23, 2, 2, skin); m.ell(16 + tw + 1, 23, 2, 2, skin)
    m.rrect(16 - tw, 12, tw * 2, 11, suit)
    m.rect(14, 11, 4, 3, sh(skin, -.3)); m.ell(16, hy, hr, hr, skin)

def visor(m, c=RED, y=8, w=7):
    if m.back: return
    x0 = 16 - w // 2 + m.fx
    if m.blink: m.flat(x0, y, w, 1, DK)
    else: m.flat(x0 - 1, y - 1, w + 2, 3, BLK); m.flat(x0, y, w, 1, c); m.px(x0, y - 1 + 1, sh(c, .7))

# ============================================================ WORLD 0: DERELICT STATION
def w0_ratbot(m):
    m.line((6, 22), (3, 17), DK, 1); m.px(3, 16, YL)
    for x in (9, 12, 17, 20): m.rect(x, 25, 2, 5, STEEL_D)
    m.ell(14, 22, 8, 5, STEEL); m.rect(8, 19, 10, 2, STEEL_D); m.flat(9, 19, 8, 1, sh(STEEL, .3))
    m.ell(23, 21, 4, 3, STEEL); m.poly([(26, 19), (30, 22), (26, 24)], STEEL); m.poly([(20, 17), (22, 13), (24, 18)], STEEL_D)
    m.px(30, 22, RED); m.eye(24, 20, RED, 0); m.flat(10, 21, 2, 1, CY)
def w0_drone(m):
    m.flat(4, 7, 9, 1, STEEL_D); m.flat(19, 7, 9, 1, STEEL_D); m.px(3, 7, LT); m.px(28, 7, LT)
    m.line((10, 12), (7, 8), STEEL_D); m.line((22, 12), (25, 8), STEEL_D)
    m.ell(16, 16, 8, 7, STEEL); m.rect(8, 15, 16, 2, STEEL_D)
    m.ell(16 + m.fx, 16, 4, 4, DK) if not m.back else m.rect(12, 14, 8, 4, STEEL_D)
    if not m.back: m.eye(16, 16, CY, 1)
    m.rect(14, 23, 4, 2, STEEL_D); m.flat(14, 26, 4, 1, hx('8fe8ff')); m.flat(15, 27, 2, 2, hx('4fd1ff')); m.line((16, 9), (16, 4), DK); m.px(16, 3, RED)
def w0_crawler(m):
    for sx in (-1, 1):
        for i, (ox, oy) in enumerate(((4, 14), (6, 18), (5, 22))):
            m.line((16 + sx * 4, 20), (16 + sx * (4 + ox), oy + 5), STEEL_D, 2); m.line((16 + sx * (4 + ox), oy + 5), (16 + sx * (6 + ox), 29), STEEL_D, 1)
    m.ell(16, 19, 8, 5, STEEL); m.rect(8, 21, 16, 2, STEEL_D)
    m.ell(16, 15, 5, 4, hx('6a7396')); m.eye(15 if not m.fx else 16, 15, YL, 1); m.eye(18 if not m.fx else 19, 15, YL, 0)
    m.line((12, 22), (9, 27), DK, 1); m.px(9, 28, OR)
def w0_turret(m):
    m.rect(7, 24, 18, 6, STEEL_D); m.flat(8, 25, 16, 1, STEEL); [m.px(x, 28, LT) for x in (9, 22)]
    m.ell(16, 20, 7, 6, STEEL); m.rect(9, 19, 14, 3, STEEL_D)
    m.rect(17, 15, 12, 3, DK); m.rect(17, 19, 12, 3, DK); m.flat(26, 16, 3, 1, hx('ff8a3c')); m.flat(26, 20, 3, 1, hx('ff8a3c'))
    m.eye(14, 18, RED, 1); m.px(11, 16, RED)
def w0_mech(m):
    m.rect(9, 20, 5, 7, STEEL_D); m.rect(18, 20, 5, 7, STEEL_D); m.rrect(7, 27, 8, 3, DK); m.rrect(17, 27, 8, 3, DK)
    m.rrect(8, 11, 16, 11, STEEL); m.rect(10, 13, 12, 2, STEEL_D)
    m.rrect(5, 11, 6, 6, hx('b86a3a')); m.rect(22, 15, 4, 6, STEEL_D); m.rect(25, 16, 6, 4, DK); m.flat(29, 17, 2, 2, OR)
    m.rrect(11, 4, 10, 8, STEEL_D); m.flat(12 + m.fx // 2, 6, 8, 3, BLK) if not m.back else None; m.eye(16, 7, CY, 1) if False else None
    if not m.back: m.flat(13 + m.fx, 6, 6, 2, hx('2fa0c8')); m.px(14 + m.fx, 6, hx('bff4ff'))
    m.flat(12, 17, 8, 3, DK); [m.px(x, 18, c) for x, c in ((13, RED), (16, YL), (19, GRN))]
def w0_warden(m):
    m.rect(11, 21, 4, 9, DK); m.rect(17, 21, 4, 9, DK); m.rrect(10, 27, 6, 3, STEEL_D); m.rrect(16, 27, 6, 3, STEEL_D)
    m.rrect(10, 11, 12, 11, STEEL); m.rect(14, 13, 4, 6, DK); m.px(15, 15, CY); m.px(16, 15, CY)
    m.rect(7, 12, 4, 9, STEEL_D); m.rect(22, 12, 4, 9, STEEL_D)
    m.rrect(2, 10, 8, 16, hx('3a6a9a')); m.rect(2, 10, 8, 2, YL); m.rect(2, 24, 8, 2, YL); m.flat(5, 14, 2, 6, LT)  # riot shield
    m.line((27, 20), (28, 7), hx('e8e2d0'), 2); m.flat(27, 6, 3, 2, CY)
    m.rrect(11, 3, 10, 9, STEEL); visor(m, RED, 7, 6)
def w0_hunter(m):
    for x in (6, 10, 20, 24): m.line((x, 20), (x - 1, 29), STEEL_D, 2)
    m.poly([(4, 17), (18, 14), (24, 18), (20, 24), (6, 24)], STEEL); m.rect(6, 21, 14, 2, STEEL_D)
    m.poly([(22, 14), (30, 17), (28, 22), (22, 21)], STEEL); m.poly([(20, 10), (22, 5), (24, 12)], STEEL_D); m.eye(26, 17, RED, 1); m.flat(28, 20, 2, 1, LT)
    m.line((5, 17), (1, 10), STEEL_D, 2); m.px(1, 9, RED)
def w0_overseer(m):
    for x in (9, 12, 16, 20, 23): m.fline((x, 20), (x + (x - 16) // 3, 28 - abs(x - 16) // 4), DK, 1)
    m.ell(16, 13, 10, 8, STEEL); m.rect(6, 12, 20, 2, STEEL_D)
    m.ell(16, 12, 5, 5, BLK); m.ell(16 + m.fx, 12, 3, 3, hx('ff2a2a')) if not m.back else None
    if not m.blink and not m.back: m.px(15 + m.fx, 11, WH)
    elif m.blink and not m.back: m.flat(14 + m.fx, 12, 5, 1, DK)
    for x in (9, 23): m.ell(x, 13, 1, 1, CY)
    m.line((16, 5), (16, 1), DK); m.px(16, 0, CY); m.line((8, 7), (6, 3), DK); m.line((24, 7), (26, 3), DK)
def w0_coreai(m):
    m.rect(6, 26, 20, 4, STEEL_D); m.flat(7, 27, 18, 1, STEEL)
    m.line((8, 26), (8, 8), STEEL_D, 2); m.line((24, 26), (24, 8), STEEL_D, 2); m.rect(6, 6, 20, 3, STEEL_D)
    m.ell(16, 17, 7, 7, hx('2fa0c8')); m.ell(16, 17, 5, 5, hx('8fe8ff')); m.fell(16, 17, 2, 2, WH)
    if not m.blink: m.fell(16 + m.fx, 17, 1, 1, RED)
    for x, y in ((12, 10), (20, 10), (10, 22), (22, 22)): m.px(x, y, CY)
    m.fline((16, 24), (16, 26), CY); m.fline((12, 8), (14, 11), YL); m.fline((20, 8), (18, 11), YL)
def b0_core(m):
    m.rect(3, 26, 26, 4, STEEL_D); m.flat(4, 27, 24, 1, STEEL)
    for sx in (-1, 1):
        m.line((16 + sx * 5, 22), (16 + sx * 13, 12), STEEL_D, 3); m.poly([(16 + sx * 13, 10), (16 + sx * 15, 15), (16 + sx * 11, 14)], hx('b0b6c4'))
    m.ell(16, 16, 11, 11, STEEL_D); m.ell(16, 16, 9, 9, hx('2a6a8a')); m.ell(16, 16, 7, 7, hx('4fd1ff')); m.ell(16, 16, 4, 4, hx('bff4ff'))
    m.fell(16 + m.fx, 16, 2, 2, hx('ff2a2a') if not m.blink else DK); m.px(15 + m.fx, 15, WH) if not m.blink else None
    m.rect(14, 3, 4, 4, YL); m.px(15, 4, RED); m.px(16, 4, RED)
    for x, y in ((8, 8), (24, 8), (6, 18), (26, 18)): m.px(x, y, YL)

# ============================================================ WORLD 1: GREENHOUSE
LF, LFD, FL = hx('5fc06a'), hx('2f7a3a'), hx('ff7ab8')
def w1_aphid(m):
    for x in (9, 12, 18, 21): m.line((x, 22), (x - 2 + (x > 15) * 4, 29), LFD, 1)
    m.ell(14, 20, 8, 7, hx('9be36b')); m.ell(23, 17, 5, 4, hx('b6f08a')); m.line((24, 13), (27, 8), LFD); m.line((22, 13), (21, 8), LFD)
    m.eye(25, 17, BLK, 0); m.px(26, 16, WH); m.fell(12, 17, 2, 1, hx('c8f8a0')); m.px(7, 22, hx('7ad04a')); m.flat(6, 23, 3, 2, hx('d8f0a0'))
def w1_vine(m):
    m.rect(8, 23, 16, 7, hx('5a6a70')); m.flat(9, 24, 14, 1, LT); m.flat(8, 23, 16, 1, STEEL_D); [m.px(x, 27, LT) for x in (10, 21)]
    for x, tx, ty in ((11, 5, 5), (16, 16, 2), (21, 27, 6)):
        m.line((x, 23), (tx, ty + 6), LFD, 3); m.line((tx, ty + 6), (tx, ty), LF, 2)
        m.poly([(tx - 2, ty + 2), (tx, ty - 2), (tx + 2, ty + 2)], hx('b0e86a')); m.px(tx, ty + 1, RED)
def w1_beetle(m):
    for sx in (-1, 1):
        for oy in (18, 22, 26): m.line((16 + sx * 6, oy), (16 + sx * 12, oy + 3), DK, 2)
    m.ell(16, 21, 9, 7, hx('2a7a6a')); m.line((16, 14), (16, 27), hx('155a4a'), 1); m.fell(12, 18, 2, 1, hx('7ad8c0')); m.fell(20, 18, 2, 1, hx('7ad8c0'))
    m.rect(9, 20, 3, 2, STEEL); m.rect(20, 23, 3, 2, STEEL)
    m.ell(16, 11, 5, 4, hx('1f5a4a')); m.poly([(10, 11), (6, 6), (12, 8)], hx('c8c0a0')); m.poly([(22, 11), (26, 6), (20, 8)], hx('c8c0a0'))
    m.eye(14, 11, YL, 0); m.eye(18, 11, YL, 0)
def w1_spore(m):
    m.line((16, 30), (16, 18), LFD, 3); m.poly([(10, 30), (16, 26), (22, 30)], LFD)
    m.ell(16, 13, 9, 9, hx('c98a3a')); m.ell(16, 12, 6, 6, hx('e8c060'))
    for x, y in ((12, 9), (20, 10), (15, 15), (19, 15), (11, 14)): m.px(x, y, hx('fff08a')); m.px(x + 1, y, hx('ffcf5c'))
    m.flat(13, 18, 7, 1, DK) if not m.blink else m.flat(13, 18, 7, 1, hx('c98a3a')); m.px(14, 17, hx('f6efd6')); m.px(18, 17, hx('f6efd6'))
    for x, y in ((6, 6), (26, 5), (4, 12), (28, 11)): m.px(x, y, hx('fff08a'))
def w1_stalker(m):
    m.line((12, 21), (8, 29), LFD, 2); m.line((20, 21), (24, 29), LFD, 2); m.line((14, 21), (14, 29), LFD, 2); m.line((18, 21), (18, 29), LFD, 2)
    m.ell(16, 17, 5, 6, hx('3a7a4a')); m.line((11, 15), (6, 24), hx('3a7a4a'), 2); m.line((21, 15), (26, 24), hx('3a7a4a'), 2)
    m.poly([(10, 9), (22, 9), (16, 15)], hx('4a9a5a')); m.eye(13, 10, hx('ffe066'), 0); m.eye(19, 10, hx('ffe066'), 0)
    m.line((12, 9), (9, 3), LFD); m.line((20, 9), (23, 3), LFD)
def w1_bloom(m):
    m.rect(9, 24, 14, 6, hx('5a6a70')); m.flat(10, 25, 12, 1, LT); m.line((16, 24), (16, 17), LFD, 3)
    for a in range(8):
        import math; ang = a * math.pi / 4; m.poly([(16, 12), (16 + 8 * math.cos(ang) - 2, 12 + 8 * math.sin(ang)), (16 + 8 * math.cos(ang) + 2, 12 + 8 * math.sin(ang))], FL if a % 2 else sh(FL, -.2))
    m.ell(16, 12, 4, 4, hx('7a1a3a')); m.flat(13, 12, 7, 1, hx('f6efd6')) if not m.blink else None; m.px(14, 13, hx('f6efd6')); m.px(18, 13, hx('f6efd6')); m.px(16, 11, YL)
def w1_mantis(m):
    m.line((13, 22), (11, 30), LFD, 2); m.line((19, 22), (21, 30), LFD, 2)
    m.poly([(11, 14), (21, 14), (19, 24), (13, 24)], hx('7ac84a')); m.line((12, 15), (5, 8), hx('7ac84a'), 2); m.line((5, 8), (3, 18), hx('9be36b'), 2); m.px(3, 19, WH)
    m.line((20, 15), (27, 8), hx('7ac84a'), 2); m.line((27, 8), (29, 18), hx('9be36b'), 2); m.px(29, 19, WH)
    m.poly([(11, 5), (21, 5), (16, 13)], hx('9be36b')); m.eye(13, 7, hx('ff5c5c'), 0); m.eye(19, 7, hx('ff5c5c'), 0); m.line((13, 5), (10, 1), LFD); m.line((19, 5), (22, 1), LFD)
def w1_elder(m):
    for x, tx in ((8, 4), (12, 10), (20, 22), (24, 28)): m.line((x, 22), (tx, 30), hx('5a3a22'), 3)
    m.ell(16, 16, 10, 10, hx('6a4a2a')); m.ell(16, 14, 7, 6, hx('7a5a34'))
    for a, b in ((9, 10), (22, 12), (10, 20), (23, 21)): m.line((a, b), (a + (3 if a < 16 else -3), b - 4), hx('3a8a4a'), 2)
    m.eye(13, 14, OR, 1); m.eye(19, 14, OR, 1); m.flat(13, 19, 7, 2, BLK) if not m.back else None; m.px(14, 18, hx('d8c8a0')); m.px(18, 18, hx('d8c8a0'))
    m.line((3, 8), (10, 14), hx('3a8a4a'), 2); m.line((29, 8), (22, 14), hx('3a8a4a'), 2)
def w1_hive(m):
    m.line((6, 28), (12, 22), hx('a03a5a'), 2); m.line((26, 28), (20, 22), hx('a03a5a'), 2); m.line((16, 29), (16, 24), hx('a03a5a'), 3)
    m.ell(16, 16, 11, 10, hx('c04a6a')); m.ell(16, 15, 8, 7, hx('e0708a'))
    for x1, y1, x2, y2 in ((8, 12, 12, 16), (24, 12, 20, 16), (16, 8, 16, 12), (10, 20, 14, 18), (22, 20, 18, 18)): m.fline((x1, y1), (x2, y2), hx('7a1a3a'))
    m.fell(16, 15, 3, 3, hx('fff0d0')); m.fell(16 + m.fx, 15, 1, 1, BLK) if not m.blink and not m.back else None
    for x, y in ((10, 12), (22, 12), (12, 20), (20, 20)): m.fell(x, y, 1, 1, hx('ffe066'))
def b1_queen(m):
    m.poly([(2, 12), (10, 4), (12, 18)], hx('a0e8d8')); m.poly([(30, 12), (22, 4), (20, 18)], hx('a0e8d8')); m.fline((4, 12), (11, 8), hx('4a9a8a')); m.fline((28, 12), (21, 8), hx('4a9a8a'))
    m.ell(16, 24, 8, 6, hx('8a5a9a')); m.ell(16, 27, 5, 3, hx('6a3a7a'))
    for x in (9, 12, 20, 23): m.line((x, 22), (x - 2 + (x > 15) * 4, 30), LFD, 2)
    m.ell(16, 15, 7, 7, hx('7ac84a')); m.ell(16, 8, 5, 5, hx('9be36b'))
    m.poly([(11, 5), (12, 0), (14, 3), (16, -1), (18, 3), (20, 0), (21, 5)], YL)
    m.eye(13, 8, RED, 1); m.eye(19, 8, RED, 1); m.line((12, 12), (9, 16), hx('c8c0a0'), 1); m.line((20, 12), (23, 16), hx('c8c0a0'), 1)
    m.px(16, 2, hx('ff5c8a'))

# ============================================================ WORLD 2: SMUGGLER HOLD
SK = hx('c89a74')
def w2_pest(m):
    human(m, hx('8aa090'), hx('6a5a44'), hx('3a3428'), BLK, tw=5, hy=11, hr=5, ly=23)
    m.fell(16, 11, 5, 5, hx('8aa090')); m.ell(16, 11, 5, 5, hx('8aa090'))
    if not m.back: m.flat(11 + m.fx, 10, 4, 3, hx('2a2a38')); m.flat(17 + m.fx, 10, 4, 3, hx('2a2a38')); m.px(12 + m.fx, 11, CY) if not m.blink else None; m.px(18 + m.fx, 11, CY) if not m.blink else None
    m.line((11, 7), (8, 3), hx('8aa090')); m.line((21, 7), (24, 3), hx('8aa090')); m.flat(13, 24, 6, 1, hx('4a4234'))
def w2_cutpurse(m):
    human(m, SK, hx('3a2a50'), hx('241a34'), hx('14141c'), tw=6)
    m.poly([(9, 3), (23, 3), (24, 14), (8, 14)], hx('3a2a50')); m.ell(16, 9, 4, 4, hx('120e1c'))
    if not m.back: m.flat(13 + m.fx, 8, 6, 2, hx('241a34')); m.px(14 + m.fx, 9, YL) if not m.blink else None; m.px(18 + m.fx, 9, YL) if not m.blink else None
    m.rrect(4, 18, 6, 6, hx('8a6a3a')); m.px(6, 20, YL)
    m.line((24, 22), (29, 15), LT, 2); m.px(29, 14, WH); m.flat(21, 17, 6, 1, hx('6a2a2a'))
def w2_bruiser(m):
    human(m, hx('b88a64'), hx('6a3a2a'), hx('2a2a38'), BLK, tw=8, hy=7, hr=5)
    m.rect(5, 13, 5, 9, hx('b88a64')); m.rect(22, 13, 5, 9, hx('b88a64')); m.ell(5, 23, 3, 3, hx('4a4f68')); m.ell(27, 23, 4, 4, hx('4a4f68')); m.fell(27, 23, 2, 2, OR); m.fline((24, 23), (31, 23), OR)
    m.flat(11, 14, 10, 2, hx('d9b020')); visor(m, hx('2a2a38'), 7, 7) if False else None
    if not m.back: m.flat(11 + m.fx, 5, 10, 2, hx('b83a2c')); m.px(13 + m.fx, 8, BLK); m.px(18 + m.fx, 8, BLK); m.flat(13 + m.fx, 10, 6, 1, hx('f6efd6'))
def w2_gunhand(m):
    human(m, SK, hx('8a6a3a'), hx('3a3a4a'), hx('4a2a1a'), tw=6)
    m.rect(11, 12, 10, 8, hx('3a3a4a')); m.flat(15, 13, 2, 7, hx('b0b6c4'))
    m.rect(8, 4, 16, 2, hx('5a3a1a')); m.rrect(11, 1, 10, 5, hx('6a4a2a'))
    if not m.back: m.px(14 + m.fx, 8, BLK); m.px(18 + m.fx, 8, BLK)
    m.rect(22, 19, 8, 3, DK); m.rect(28, 17, 3, 4, DK); m.flat(30, 20, 1, 1, CY); m.flat(23, 20, 5, 1, STEEL)
def w2_enforcer(m):
    human(m, STEEL_D, hx('c8d0e8'), hx('8a93b5'), hx('2a2f45'), tw=7)
    m.rrect(10, 11, 12, 6, hx('e0e6f4')); m.flat(10, 18, 12, 1, hx('3a6a9a')); m.ell(16, 8, 6, 6, hx('c8d0e8')); visor(m, hx('2fa0c8'), 8, 8)
    m.rect(4, 13, 5, 6, hx('e0e6f4')); m.rect(23, 13, 5, 6, hx('e0e6f4'))
    m.line((27, 22), (28, 8), hx('2a2f45'), 2); m.flat(27, 7, 3, 2, YL)
def w2_captain(m):
    human(m, SK, hx('2a6a7a'), hx('1a3a4a'), BLK, tw=7)
    m.poly([(10, 13), (22, 13), (24, 28), (8, 28)], hx('2a6a7a')); m.rect(15, 14, 2, 14, YL); [m.px(x, y, YL) for x, y in ((12, 16), (12, 20), (20, 16), (20, 20))]
    m.rect(9, 3, 14, 3, hx('1a3a4a')); m.rrect(11, 0, 10, 4, hx('2a6a7a')); m.flat(15, 1, 2, 2, YL)
    if not m.back: m.px(14 + m.fx, 8, BLK); m.px(18 + m.fx, 8, BLK)
    m.line((26, 25), (30, 9), LT, 2); m.flat(24, 24, 5, 2, YL)
def w2_assassin(m):
    human(m, hx('2a2a38'), hx('1a1a24'), hx('14141c'), BLK, tw=5)
    m.ell(16, 8, 5, 5, hx('1a1a24')); visor(m, RED, 8, 6)
    m.line((5, 14), (3, 4), LT, 2); m.line((27, 14), (29, 4), LT, 2); m.flat(3, 3, 1, 1, WH)
    m.poly([(11, 12), (6, 24), (13, 22)], hx('6a1a2a')); m.fline((11, 13), (22, 13), hx('6a1a2a'))
def w2_warlord(m):
    human(m, hx('6a4a3a'), hx('6a3a2a'), hx('3a2a2a'), BLK, tw=8, hy=7, hr=5)
    for sx in (-1, 1): m.poly([(16 + sx * 9, 11), (16 + sx * 13, 4), (16 + sx * 12, 14)], hx('b0b6c4')); m.rrect(16 + sx * 9 - 3, 11, 6, 5, hx('4a4f68'))
    m.rrect(9, 1, 14, 9, hx('4a4f68')); visor(m, RED, 6, 8); m.rect(15, 11, 2, 12, YL)
    m.rect(24, 17, 6, 5, DK); [m.px(30, y, hx('ff8a3c')) for y in (18, 20)]; m.fline((24, 19), (30, 19), STEEL)
def w2_kingpin(m):
    human(m, SK, hx('3a2a50'), hx('241a34'), hx('14141c'), tw=7)
    m.poly([(11, 12), (16, 20), (21, 12)], hx('e8e2d0')); m.line((12, 13), (20, 13), YL, 1); m.px(16, 15, YL); m.px(15, 16, YL); m.px(17, 16, YL)
    m.rect(5, 13, 4, 10, hx('c9a52a')); m.rect(23, 13, 4, 10, hx('3a2a50')); m.fell(7, 23, 2, 2, hx('c9a52a'))
    m.rrect(9, 1, 14, 4, hx('14141c')); m.rect(7, 4, 18, 2, hx('14141c'))
    if not m.back: m.flat(11 + m.fx, 8, 4, 2, BLK); m.flat(17 + m.fx, 8, 4, 2, BLK); m.px(12 + m.fx, 8, hx('fff08a')); m.flat(14 + m.fx, 11, 4, 1, hx('f6efd6'))
def b2_lord(m):
    m.poly([(5, 12), (27, 12), (30, 30), (2, 30)], hx('8a1a2a')); m.fline((16, 14), (16, 29), hx('5a0a1a'))
    m.rect(10, 22, 5, 8, hx('3a3a4a')); m.rect(17, 22, 5, 8, hx('3a3a4a')); m.rrect(9, 28, 7, 3, DK); m.rrect(16, 28, 7, 3, DK)
    m.rrect(7, 11, 18, 13, hx('c9a52a')); m.rect(10, 14, 12, 2, hx('f0d060')); m.rect(14, 15, 4, 8, hx('8a6a1a')); m.px(16, 19, RED)
    m.ell(4, 13, 4, 4, hx('d9b020')); m.ell(28, 13, 4, 4, hx('d9b020')); m.rect(26, 15, 5, 8, hx('c9a52a')); m.rect(28, 22, 4, 5, DK)
    m.ell(16, 8, 6, 6, hx('c9a52a')); m.poly([(9, 5), (9, -1), (12.5, 3), (16, -3), (19.5, 3), (23, -1), (23, 5)], hx('f0d060'))
    visor(m, hx('ff2a2a'), 8, 8)

# ============================================================ WORLD 3: CRYSTAL DEEP
CR, CRD, CRL = hx('b070e8'), hx('6a3aa8'), hx('e0c0ff')
def cst(m, pts, c=CR): m.poly(pts, c); m.d.line([pts[0], pts[1]], fill=sh(c, .5))
def w3_glimmer(m):
    m.poly([(16, 6), (19, 15), (28, 16), (19, 18), (16, 27), (13, 18), (4, 16), (13, 15)], hx('c0e8ff')); m.poly([(16, 11), (18, 16), (16, 21), (14, 16)], WH)
    for x, y in ((6, 6), (26, 7), (24, 25), (7, 24)): m.px(x, y, hx('7fe8ff')); m.px(x + 1, y, hx('bff4ff'))
    m.eye(16, 16, hx('7a3aa8'), 0)
def w3_geode(m):
    m.ell(16, 20, 11, 9, hx('7a6a8a')); m.ell(16, 19, 8, 6, hx('2a1a4a'))
    for x, h in ((11, 6), (15, 9), (19, 7), (22, 5)): cst(m, [(x - 2, 22), (x, 22 - h), (x + 2, 22)], hx('7fe8ff') if x % 2 else CR)
    m.eye(14, 21, RED, 0); m.eye(19, 21, RED, 0); m.flat(9, 28, 14, 2, hx('5a4a6a'))
def w3_wisp(m):
    m.poly([(16, 14), (24, 30), (8, 30)], hx('6a3aa8')); m.poly([(16, 16), (21, 29), (11, 29)], hx('9a5ad8'))
    m.ell(16, 13, 8, 8, hx('c070f8')); m.ell(16, 13, 5, 5, hx('f0c0ff')); m.fell(16, 13, 2, 2, WH)
    m.eye(13, 13, hx('2a0a4a'), 0); m.eye(19, 13, hx('2a0a4a'), 0)
    for x, y in ((6, 6), (26, 10), (24, 3)): m.px(x, y, hx('e0c0ff'))
def w3_shardling(m):
    for x in (9, 13, 19, 23): m.line((x, 22), (x - 2 + (x > 15) * 4, 29), CRD, 2)
    m.poly([(8, 24), (11, 10), (16, 22)], CRD); m.poly([(24, 24), (21, 10), (16, 22)], CR); m.poly([(10, 24), (16, 4), (22, 24)], hx('c890f8')); m.poly([(16, 4), (22, 24), (16, 24)], CR)
    m.eye(14, 16, hx('7fe8ff'), 0); m.eye(18, 16, hx('7fe8ff'), 0)
def w3_prism(m):
    m.poly([(16, 3), (28, 26), (4, 26)], hx('a0d8ff')); m.poly([(16, 3), (28, 26), (16, 26)], hx('6aa8e8')); m.poly([(16, 9), (23, 24), (9, 24)], hx('d0f0ff'))
    for i, c in enumerate(('ff6a6a', 'ffd84f', '6dff9a', '4fd1ff', 'c07cff')): m.px(8 + i * 3, 27, hx(c)); m.px(8 + i * 3, 28, hx(c))
    m.fell(16, 18, 3, 3, hx('2a1a4a')); m.fell(16 + m.fx, 18, 1, 1, hx('ff6ad8')) if not m.blink and not m.back else None
def w3_golem(m):
    m.rect(10, 22, 5, 8, CRD); m.rect(17, 22, 5, 8, CRD); m.rect(9, 28, 7, 2, hx('4a2a7a')); m.rect(16, 28, 7, 2, hx('4a2a7a'))
    m.poly([(8, 12), (24, 12), (22, 24), (10, 24)], CR); m.poly([(16, 12), (24, 12), (22, 24), (16, 24)], CRD)
    m.poly([(3, 12), (9, 11), (8, 20), (4, 24)], CRD); m.poly([(29, 12), (23, 11), (24, 20), (28, 24)], CRD); m.poly([(3, 12), (4, 7), (7, 12)], CRL); m.poly([(29, 12), (28, 7), (25, 12)], CRL)
    m.poly([(11, 3), (21, 3), (22, 11), (10, 11)], hx('c890f8')); m.eye(13, 7, hx('7fe8ff'), 1); m.eye(19, 7, hx('7fe8ff'), 1); m.fell(16, 17, 2, 2, hx('7fe8ff'))
def w3_stalker(m):
    for sx in (-1, 1):
        for oy, ox in ((18, 6), (22, 9)): m.line((16 + sx * 5, oy), (16 + sx * (5 + ox), 29), CRD, 2)
    m.poly([(8, 16), (24, 16), (22, 24), (10, 24)], CR); m.poly([(16, 16), (24, 16), (22, 24), (16, 24)], CRD)
    m.poly([(11, 15), (13, 7), (19, 7), (21, 15)], hx('c890f8')); m.poly([(13, 7), (16, 2), (19, 7)], CRL); m.eye(14, 11, hx('ff6ad8'), 0); m.eye(18, 11, hx('ff6ad8'), 0)
    m.poly([(22, 18), (30, 13), (26, 22)], CRL)
def w3_oracle(m):
    m.ell(16, 15, 12, 11, hx('4a2a7a')); m.ell(16, 15, 10, 9, hx('120a24'))
    for a, b in ((16, 2), (5, 8), (27, 8), (3, 22), (29, 22), (16, 29)): cst(m, [(a - 2, b + 2), (a, b - 3), (a + 2, b + 2)], hx('c890f8'))
    m.ell(16, 15, 7, 6, hx('f6efe0')); m.fell(16 + m.fx, 15, 3, 3, hx('7a3aa8')) if not m.back else None
    if m.blink: m.flat(10, 15, 12, 2, hx('4a2a7a'))
    elif not m.back: m.fell(16 + m.fx, 15, 1, 1, BLK); m.px(15 + m.fx, 14, WH)
def w3_heart(m):
    m.rect(8, 27, 16, 3, hx('4a3a6a')); m.rect(11, 24, 10, 4, hx('3a2a5a'))
    m.poly([(16, 26), (4, 14), (7, 6), (13, 5), (16, 9), (19, 5), (25, 6), (28, 14)], hx('e060c0')); m.poly([(16, 26), (28, 14), (25, 6), (19, 5), (16, 9)], hx('a02a8a'))
    m.poly([(16, 22), (9, 14), (11, 9), (15, 10)], hx('ffa0e8')); m.fline((16, 9), (16, 24), hx('7a1a6a')); m.fline((10, 11), (16, 18), hx('7a1a6a')); m.fline((22, 11), (16, 18), hx('7a1a6a'))
    m.fell(16, 16, 2, 2, WH); m.px(16, 16, hx('ff6ad8'))
def b3_titan(m):
    m.rect(8, 21, 6, 9, CRD); m.rect(18, 21, 6, 9, CRD); m.rect(7, 28, 8, 2, hx('4a2a7a')); m.rect(17, 28, 8, 2, hx('4a2a7a'))
    m.poly([(5, 10), (27, 10), (24, 24), (8, 24)], CR); m.poly([(16, 10), (27, 10), (24, 24), (16, 24)], CRD)
    m.poly([(0, 8), (7, 8), (6, 22), (2, 26)], CRD); m.poly([(32, 8), (25, 8), (26, 22), (30, 26)], CRD)
    for x, h in ((2, 8), (6, 6), (26, 6), (30, 8)): m.poly([(x - 2, 9), (x, 9 - h), (x + 2, 9)], CRL)
    for x, h in ((9, 8), (13, 12), (19, 11), (23, 7)): m.poly([(x - 2, 6), (x, 6 - h), (x + 2, 6)], hx('e0c0ff') if x % 2 else hx('7fe8ff'))
    m.poly([(9, 2), (23, 2), (24, 10), (8, 10)], hx('c890f8')); m.eye(13, 6, hx('ff2a8a'), 1); m.eye(19, 6, hx('ff2a8a'), 1)
    m.fell(16, 17, 3, 3, hx('7fe8ff')); m.fell(16, 17, 1, 1, WH)

MONS = [
    [w0_ratbot, w0_drone, w0_crawler, w0_turret, w0_mech, w0_warden, w0_hunter, w0_overseer, w0_coreai, b0_core],
    [w1_aphid, w1_vine, w1_beetle, w1_spore, w1_stalker, w1_bloom, w1_mantis, w1_elder, w1_hive, b1_queen],
    [w2_pest, w2_cutpurse, w2_bruiser, w2_gunhand, w2_enforcer, w2_captain, w2_assassin, w2_warlord, w2_kingpin, b2_lord],
    [w3_glimmer, w3_geode, w3_wisp, w3_shardling, w3_prism, w3_golem, w3_stalker, w3_oracle, w3_heart, b3_titan],
]

def render(ti, idx, dirn, blink):
    m = M(dirn, blink); MONS[ti][idx](m); return m.done()

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    atlas = Image.new('RGBA', (8 * 32, 40 * 32), (0, 0, 0, 0))
    for ti in range(4):
        for idx in range(10):
            for dirn in range(4):
                for b in (0, 1): atlas.alpha_composite(render(ti, idx, dirn, bool(b)), ((dirn * 2 + b) * 32, (ti * 10 + idx) * 32))
    atlas.save(f'{out}/mon_atlas.png')
    S = 4; sheet = Image.new('RGBA', (10 * 34 * S, 4 * 34 * S), (36, 38, 52, 255))
    for ti in range(4):
        for idx in range(10):
            im = render(ti, idx, 0, False).resize((32 * S, 32 * S), Image.NEAREST); sheet.alpha_composite(im, (idx * 34 * S, ti * 34 * S))
    sheet.save(f'{out}/mon_sheet.png')
