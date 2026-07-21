---
name: optimizing-marker-widget
description: Use when marker_widget markers are slow, cause jank, use too much memory, re-render repeatedly, or show stale icons after theme, locale, selection, or account changes - covers cacheKey design, buildMarkerCacheKey and buildClusterCacheKey, clearCache and removeFromCache invalidation, maxCacheEntries and maxCacheBytes tuning, render deduplication, and render-once preloading.
---

# Optimizing marker_widget caching and performance

Every render is a full off-screen widget build + rasterize + PNG encode on the UI
isolate. Performance work with this package is almost entirely about rendering less:
correct cache keys, correct invalidation, and reuse.

Audience: developers whose app already uses marker_widget 2.x. Inputs: the symptom
(jank, memory growth, stale icons, slow first paint) and the code paths that create
markers. Not for: broken/blank output (marker-widget:troubleshooting-marker-widget) or
first-time integration (marker-widget:using-marker-widget).

## The three rules

1. `cacheKey` is opt-in. No key = no cache AND no in-flight deduplication; identical
   concurrent renders each pay full cost.
2. A key must encode every content input that changes pixels: identity, brightness,
   locale, plus `extra:` for state (selected, count, badge, avatar revision). Missing
   input = stale icon when that input changes. Since 2.1 the renderer also keys every
   cache entry by the resolved logicalSize and pixelRatio automatically, so a reused
   key can never return a wrong-sized icon; keeping size/DPR inside
   `buildMarkerCacheKey` stays correct and readable.
3. Keys that over-encode (e.g. include a timestamp or camera position) defeat caching
   entirely. If `cacheSize` grows with every frame, the key is over-encoded.

## Workflow

### Step 1: Find the render sites and classify

Grep for `toBitmapDescriptor|toMapBitmap|toMarkerIcon|toMarker(|toAdvancedMarker|toAdvancedPinMarker|toPinConfig|toGroundOverlayBitmap`.
For each site: static icon (same for all users/time), per-entity icon (varies by id +
small state), or per-frame (depends on camera/continuous values; this is a design
smell, fix first).

### Step 2: Apply the matching strategy

| Class | Strategy |
|---|---|
| Static (a handful of pin styles) | Render once at startup or first map open into `MarkerIcon` objects, reuse with `icon.toMarker(base:)`. Zero renders afterwards; since 2.1 a reused icon also returns the identical descriptor, so rebuilt markers stay `==` and the map skips redundant platform icon updates |
| Per-entity | `buildMarkerCacheKey(id: entity.id, ..., extra: visualState)`; keep using the shared `defaultMarkerIconRenderer` so eviction is centralized |
| Cluster badges | `buildClusterCacheKey(count: n, ...)`; bucket counts (10, 50, 100+) via `extra` or by rounding `count` so 137 and 138 share one icon |
| Per-frame | Restructure: precompute icon variants, select among them per frame instead of rendering per frame |

### Step 3: Invalidate deliberately

- Theme/locale change: unnecessary if keys include `brightness`/`locale` (old entries
  age out via LRU). If keys do not, call `defaultMarkerIconRenderer.clearCache()` on
  change.
- Logout/account switch: `clearCache()` always (user avatars must not survive).
- One entity changed: `removeFromCache(key)` then re-render.
- Invalidation is safe against races: renders started before `clearCache()`/
  `removeFromCache()` cannot repopulate the cache.

### Step 4: Bound memory

Defaults: 64 entries, 50 MB. `cacheSizeInBytes` tells you actual usage; PNG cost
scales with logicalSize * dpr squared (a 256x256 icon at 3x DPR is ~9x the pixels of
96x96). Tune `MarkerIconRenderer(maxCacheEntries: ..., maxCacheBytes: ...)` only with
evidence from `cacheSize`/`cacheSizeInBytes`. Never pass `maxCacheBytes: null` in an
app that renders user-generated content. An icon bigger than `maxCacheBytes` by itself
is silently never cached - if `isCached(key)` stays false after a render, check icon
size vs the cap. `maxCacheBytes` measures encoded PNG bytes, not the platform map's
decoded bitmap memory.

Since 2.1 the renderer also bounds render throughput: `maxConcurrentRenders`
(default 3) queues extra renders in FIFO order so a 200-marker prewarm cannot hold
200 detached render trees at once, and `maxRasterPixels` (default one 2048x2048
physical bitmap) rejects accidental giant renders with `ArgumentError`. Raise or
disable (null) either one only with measured evidence.

### Step 5: Verify with numbers

Before/after: `stopwatch` around the marker-set build, `cacheSize`/`cacheSizeInBytes`
after typical navigation, DevTools frame chart while panning the map. A correct setup
shows renders only on first appearance and on real state changes; panning and rebuilds
cause zero renders. In widget tests, assert `isCached(key)` and that a second call
returns identical bytes without delay (wrap renders in `tester.runAsync`).

## Failure handling

- Stale icon after a state change: the changed input is missing from the key. Add it
  via `extra:` (do not switch to random keys).
- Memory still growing: keys over-encoded (unbounded distinct keys) or a second
  renderer instance bypasses the bounded one; grep for `MarkerIconRenderer(`.
- Jank persists though cache hits: too many markers overall or giant bitmaps; reduce
  logicalSize, bucket cluster counts, or thin markers by viewport.
- Duplicate concurrent work: same logical icon rendered with two different key shapes;
  unify key construction in one helper function in the app.

## Example scenario

"Map janks when 200 delivery markers load, and toggling dark mode leaves old-style
pins": markers rendered per item in `build()` without keys. Fix: one
`buildMarkerCacheKey(id: order.id, logicalSize: const Size(64, 64), pixelRatio: dpr,
brightness: theme.brightness, extra: order.status)` per order; move rendering out of
`build()` into the load path; result is 200 renders once, ~0 on rebuilds, dark-mode
toggle renders fresh variants because `brightness` is in the key.

Renderer/cache API details: ../../references/api-quick-reference.md. Codebase-wide
audit checklist: ../../references/review-checklist.md (Claude Code users can run the
marker-widget-reviewer agent instead).
