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
