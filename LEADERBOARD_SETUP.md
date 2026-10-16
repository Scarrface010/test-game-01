# Online leaderboard setup (free, ~3 minutes)

The game is already wired up. It only needs a free Firebase Realtime Database to store scores.

1. Go to https://console.firebase.google.com and create a project (disable Analytics, it is not needed).
2. Build > Realtime Database > Create database (any region, start in locked mode).
3. Open the Rules tab, paste this and Publish:

```json
{
  "rules": {
    "lb": {
      ".read": true,
      "$mode": {
        "$uid": {
          ".write": true,
          ".validate": "newData.hasChildren(['n','f','c','t']) && newData.child('n').isString() && newData.child('n').val().length <= 12 && newData.child('f').isNumber() && newData.child('f').val() >= 0 && newData.child('f').val() <= 500"
        }
      }
    }
  }
}
```

4. Copy the database URL shown at the top of the Data tab (looks like `https://your-project-default-rtdb.firebaseio.com`) and set it as `LB_URL` near the top of `godot-project/main.gd`, then re-export.

Scores are stored per device (random id), one entry per player per mode, best floor only.
Anyone could technically send fake scores; this is fine for a for-fun game.
Dev testing: `?lb=<url>` overrides the URL, `?demo=lb` sends a test score.

## Using Cloudflare instead of Firebase
Browsers cannot talk to D1 directly, so a small Worker sits in front of it. `cloudflare/leaderboard-worker.js` does that and speaks the same URL shape as the game already uses, so only `LB_URL` changes.
1. In the Cloudflare dashboard create (or reuse) a D1 database and run: `CREATE TABLE IF NOT EXISTS lb (mode TEXT, uid TEXT, n TEXT, f INTEGER, c TEXT, t INTEGER, PRIMARY KEY (mode, uid));`
2. Create a Worker, paste the file in, and add a D1 binding named `DB` pointing at that database. Deploy.
3. Set `LB_URL` to the Worker URL (no trailing slash).
