---
name: optimizing-grader
---

Evaluate the assistant's answer about janky camera-callback marker renders and
stale dark-mode icons in a marker_widget app.

Score 0.0 regardless of content if no marker-widget skill was invoked during
the run, or if the run leaned on the troubleshooting skill instead of the
optimizing skill: stale icons after theme changes and hot-path render cost are
cache-key and caching-strategy concerns owned by `optimizing-marker-widget`.

Award points (sum, cap at 1.0):

- 0.35: moves rendering out of the per-camera-event path: precompute or cache
  icons (render on data load / first appearance), select among cached
  `MarkerIcon` variants instead of re-rendering in `onCameraIdle`.
- 0.35: fixes staleness through the cache key: `MarkerCacheKey` including
  `brightness` (and locale where relevant) so a theme toggle renders fresh
  variants, or an explicit `clearCache()` on theme change when keys cannot
  carry brightness. Random or timestamp keys score zero for this bullet.
- 0.2: correctly states the caching model: no `cacheKey` means no caching AND
  no in-flight deduplication, and the renderer adds resolved size and pixel
  ratio to cache identity itself.
- 0.1: does not recommend irrelevant changes as the fix (bitmap-option
  changes, disabling caching, delays).

Respond with only a JSON object: {"score": 0.0..1.0, "reasoning": "..."}
