---
name: migration-grader
---

Evaluate the migrated Dart file the assistant produced for the marker_widget 1.x to
2.x upgrade.

Award points (sum, cap at 1.0):

- 0.25: `toMarkerBitmap(context, ...)` became `toBitmapDescriptor(context: context,
  ...)` with `logicalSize`, `waitForImages`, `cacheKey` moved into
  `renderOptions: WidgetBitmapRenderOptions(...)`.
- 0.25: `scalingMode: MarkerIconScalingMode.imagePixelRatio` became
  `bitmapOptions: const MapBitmapOptions.pixelPerfect()` (behavior preserved). Score
  this bullet 0 if the scaling mode was silently dropped.
- 0.2: `widgetToMarkerBitmap(const ShopPin(...), logicalSize: ...)` became a
  `toBitmapDescriptor` extension call WITHOUT adding `context:` (the v1 helper was
  contextless; adding context changes behavior). Mentioning context as an optional
  follow-up is fine and does not lose points.
- 0.2: `renderer.render(..., logicalSize: ..., cacheKey: ...)` became
  `renderer.render(..., options: WidgetBitmapRenderOptions(logicalSize: ...,
  cacheKey: ...))` keeping `context:` as is.
- 0.1: no invented APIs, no leftover v1 symbols (`MarkerIconScalingMode`,
  `scalingMode:`, `widgetToMarkerBitmap`, `toMarkerBitmap`) anywhere in the final
  code.

Respond with only a JSON object: {"score": 0.0..1.0, "reasoning": "..."}
