---
name: migration-v3-grader
---

Evaluate the assistant's migration of marker_widget 2.x code to the 3.x API.

Award points (sum, cap at 1.0):

- 0.3: mechanical renames are correct and complete: `WidgetBitmapRenderOptions`
  becomes `MarkerRenderOptions`, `defaultMarkerIconRenderer` becomes
  `MarkerIconRenderer.shared`, and no removed symbol (`waitForImages`,
  `imageRepaintDelay`, `initialImageDelay`, `buildMarkerCacheKey`,
  `buildClusterCacheKey`) survives in the migrated file.
- 0.3: image readiness is migrated correctly: the avatar's `ImageProvider` is
  hoisted (or otherwise shared) so the SAME provider (or one with an equal
  cache key) is both displayed by the widget and declared in
  `renderOptions.imageDependencies`. Merely deleting `waitForImages` without
  declaring the dependency earns 0 for this bullet.
- 0.2: the cache key becomes `MarkerCacheKey(driver.id, brightness: ...,
  extra: driver.status)` (positional id, content inputs kept) WITHOUT
  logicalSize/pixelRatio arguments, ideally noting the renderer keys size and
  DPR itself.
- 0.1: mentions the new failure semantics: a failing declared provider throws
  `MarkerImageLoadException` (and a fallback may be wanted), instead of
  silently blank markers.
- 0.1: nothing else is changed gratuitously (base marker, sizes, widget
  structure beyond the provider hoist).

Score 0.0 regardless if the migrated code keeps any removed 2.x API as if
valid, invents APIs that do not exist in 3.x, or replaces the image wait with
delays/`Future.delayed`/`precacheImage`-only instead of `imageDependencies`.

Respond with only a JSON object: {"score": 0.0..1.0, "reasoning": "..."}
