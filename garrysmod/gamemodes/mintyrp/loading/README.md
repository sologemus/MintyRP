# MintyRP Loading Screen

Custom join screen for dedicated servers. GMod loads this via `sv_loadingurl` (a real HTTP/HTTPS page — not a file inside the gamemode alone).

## Quick setup

1. Host the entire `loading/` folder on any static host (GitHub Pages, Cloudflare Pages, Nginx, etc.) so `index.html` is publicly reachable over **HTTPS**.
2. In `garrysmod/cfg/server.cfg`:

```
sv_loadingurl "https://YOUR_HOST/path/to/loading/index.html?steamid=%s"
```

3. Restart the server and join once to verify the progress callbacks fill in server name, map, and download status.

## Local preview

Open `index.html` in a browser. It runs a fake progress animation in preview mode.

## Files

| Path | Purpose |
|------|---------|
| `index.html` | Shell markup |
| `css/loading.css` | Layout / motion |
| `js/loading.js` | GMod Loading URL API hooks |
| `assets/logo.png` | Wordmark |
| `assets/background.jpg` | Full-bleed Rockford mood art |
| `assets/icon.png` | Optional monogram |

## Main menu logo

Separately, GMod reads these from the gamemode root (already shipped):

- `../logo.png` — gamemode picker / home-screen logo
- `../icon24.png` — 24×24 menu icon
