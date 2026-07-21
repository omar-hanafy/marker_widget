---
name: optimizing-marker-widget
description: Use when marker_widget markers are slow, cause jank, use too much memory, re-render repeatedly, or show stale icons after theme, locale, selection, or account changes - covers MarkerCacheKey design, clearCache and removeFromCache invalidation, maxCacheEntries and maxCacheBytes tuning, render deduplication, MarkerIconRenderer.shared, and render-once preloading.
---

# Optimizing marker_widget caching and performance

Every render is a full off-screen widget build + rasterize + PNG encode on the UI
isolate. Performance work with this package is almost entirely about rendering less:
correct cache keys, correct invalidation, and reuse.

Audience: developers whose app already uses marker_widget 3.x. Inputs: the symptom
(jank, memory growth, stale icons, slow first paint) and the code paths that create
markers. Not for: broken/blank output (marker-widget:troubleshooting-marker-widget) or
first-time integration (marker-widget:using-marker-widget).

## The three rules

1. `cacheKey` is opt-in. No key = no cache AND no in-flight deduplication; identical
   concurrent renders each pay full cost.
2. A key must encode every content input that changes pixels: identity, brightness,
   locale, plus `extra:` for state (selected, count, badge) AND for every mutable
   image the widget shows, its URL or content revision - the cache is consulted
   before image dependencies resolve, so a changed avatar URL behind an unchanged
   key serves the old icon forever. Custom theme colors, text scaling, bold-text
   accessibility, directionality, and prepared-data revisions belong in `extra` too
   when the widget renders them. Missing input = stale icon when that input changes.
   The renderer keys every cache entry by the resolved logicalSize and pixelRatio
   automatically, so `MarkerCacheKey` carries only content inputs and a reused key
   can never return a wrong-sized icon. `extra` compares with `==`: use immutable
   records or other value-equal types. Fresh identity-based collections miss the
   cache; mutating and reusing one can return stale output.
   When `MarkerRenderOptions.prepare` supplies content, include that content's
   revision because preparation is skipped on cache hits.
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
| Static (a handful of pin styles) | Render once at startup or first map open into `MarkerIcon` objects, reuse with `icon.toMarker(base:)`. Zero renders afterwards; a reused icon also returns the identical descriptor, so rebuilt markers stay `==` and the map skips redundant platform icon updates |
| Per-entity | `cacheKey: MarkerCacheKey(entity.id, brightness: ..., locale: ..., extra: visualState)`; keep using `MarkerIconRenderer.shared` so eviction is centralized |
| Cluster badges | `MarkerCacheKey.cluster(count: n, ...)`; bucket counts (10, 50, 100+) via `extra` or by rounding `count` so 137 and 138 share one icon |
| Per-frame | Restructure: precompute icon variants, select among them per frame instead of rendering per frame |

### Step 3: Invalidate deliberately

- Theme/locale change: unnecessary if keys include `brightness`/`locale` (old entries
  age out via LRU). If keys do not, call `MarkerIconRenderer.shared.clearCache()` on
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

The renderer also bounds throughput: `maxConcurrentRenders` (default 1) queues
detached render trees in FIFO order, while `maxConcurrentImageLoads` (default 1)
separately bounds image-backed jobs from dependency resolution through capture.
Image-free jobs can bypass a stalled provider, and `imageLoadTimeout` (default 30
seconds, 3.1+) fails a dependency that never decodes so it cannot hold the image
permit forever. `maxRasterPixels` (default one 2048x2048 physical bitmap) rejects
accidental giant outputs using their exact rounded physical area. Raise or disable
(null) a limit only with measured evidence.

### Step 5: Verify with numbers

Before/after: `stopwatch` around the marker-set build, `cacheSize`/`cacheSizeInBytes`
after typical navigation, DevTools frame chart while panning the map. A correct setup
shows renders only on first appearance and on real state changes; panning and rebuilds
cause zero renders. In widget tests, assert `isCached(key)` and that a second call
returns identical bytes without delay (wrap renders in `tester.runAsync`).

## Failure handling

- Stale icon after a state change: the changed input is missing from the key. Add it
  via `extra:` (do not switch to random keys).
- Cache misses on every render despite stable inputs: `extra` (or the whole custom
  key) lacks value equality - a fresh `List`/`Map`/object per build never equals the
  previous one. Use records or a value-equal type.
- Memory still growing: keys over-encoded (unbounded distinct keys) or a second
  renderer instance bypasses the bounded one; grep for `MarkerIconRenderer(`.
- Jank persists though cache hits: too many markers overall or giant bitmaps; reduce
  logicalSize, bucket cluster counts, or thin markers by viewport.
- Duplicate concurrent work: same logical icon rendered with two different key shapes;
  unify key construction in one helper function in the app.

## Example scenario

"Map janks when 200 delivery markers load, and toggling dark mode leaves old-style
pins": markers rendered per item in `build()` without keys. Fix: one
`MarkerCacheKey(order.id, brightness: theme.brightness, extra: order.status)` per
order; move rendering out of `build()` into the load path; result is 200 renders
once, ~0 on rebuilds, dark-mode toggle renders fresh variants because `brightness`
is in the key.

Renderer/cache API details: ../../references/api-quick-reference.md. Codebase-wide
audit checklist: ../../references/review-checklist.md (Claude Code users can run the
marker-widget-reviewer agent instead).
