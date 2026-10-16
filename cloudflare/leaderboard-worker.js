// Cloudflare Worker for the Pocket Station leaderboard (uses a D1 database bound as DB).
// Speaks the same tiny REST shape the game already uses:
//   GET /lb/puzzle.json            -> { "<uid>": { n, f, c, t }, ... }
//   PUT /lb/puzzle/<uid>.json      -> body { n, f, c, t }   (keeps the best floor only)
// Table (run once in the D1 console):
//   CREATE TABLE IF NOT EXISTS lb (mode TEXT, uid TEXT, n TEXT, f INTEGER, c TEXT, t INTEGER, PRIMARY KEY (mode, uid));

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,PUT,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...CORS, "Content-Type": "application/json" } });

export default {
  async fetch(req, env) {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    const parts = new URL(req.url).pathname.replace(/\.json$/, "").split("/").filter(Boolean);
    if (parts[0] !== "lb" || !["puzzle", "adv"].includes(parts[1])) return json({ error: "not found" }, 404);
    const mode = parts[1];

    if (req.method === "GET" && parts.length === 2) {
      const { results } = await env.DB.prepare(
        "SELECT uid, n, f, c, t FROM lb WHERE mode = ? ORDER BY f DESC, t ASC LIMIT 50"
      ).bind(mode).all();
      const out = {};
      for (const r of results) out[r.uid] = { n: r.n, f: r.f, c: r.c, t: r.t };
      return json(out);
    }

    if (req.method === "PUT" && parts.length === 3) {
      const uid = parts[2];
      if (!/^[a-z0-9]{6,32}$/.test(uid)) return json({ error: "bad id" }, 400);
      let b;
      try { b = await req.json(); } catch { return json({ error: "bad json" }, 400); }
      const n = String(b.n ?? "").replace(/[^A-Za-z0-9 _.\-]/g, "").trim().slice(0, 12);
      const f = Math.floor(Number(b.f));
      const c = String(b.c ?? "").replace(/[^a-z]/g, "").slice(0, 12);
      if (!n || !Number.isFinite(f) || f < 0 || f > 500) return json({ error: "invalid" }, 400);
      // keep the best floor; always refresh the name
      await env.DB.prepare(
        `INSERT INTO lb (mode, uid, n, f, c, t) VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(mode, uid) DO UPDATE SET n = excluded.n,
           c = CASE WHEN excluded.f >= lb.f THEN excluded.c ELSE lb.c END,
           t = CASE WHEN excluded.f > lb.f THEN excluded.t ELSE lb.t END,
           f = MAX(lb.f, excluded.f)`
      ).bind(mode, uid, n, f, c, Math.floor(Date.now() / 1000)).run();
      return json({ ok: true });
    }
    return json({ error: "not found" }, 404);
  },
};
