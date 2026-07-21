# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0-dev.1] - 2026-07-21

Hardening prerelease. All changes are backward compatible for correct usage;
several misuses that previously produced silently wrong output now throw.

### Fixed

- The off-screen render tree is now fully unmounted after capture, so
  `State.dispose` runs for stateful marker widgets and resources they hold
  (timers, controllers, subscriptions) are released per render. All manually
  created render objects and the captured `ui.Image` are disposed even when a
  setup step or PNG encoding throws.
- Cache identity now combines the cache key with the resolved logical size and
  pixel ratio. Reusing one `cacheKey` at a different size or pixel ratio
  (sequentially or concurrently) renders a fresh icon instead of returning the
  previously cached, wrongly sized one.
- Screen geometry no longer leaks into rendered markers: safe-area padding,
  keyboard insets, system gesture insets, and display features are zeroed in
  the render tree's `MediaQuery`, so a `SafeArea` inside a marker renders edge
  to edge. Accessibility values (text scaling, brightness, bold text) are
  still inherited.
- `removeFromCache` no longer grows internal bookkeeping for every key it is
  ever called with; invalidation state now lives only while a render is in
  flight.

### Added

- `MarkerIconRenderer.maxConcurrentRenders` (default 3): a FIFO gate on how
  many off-screen render trees exist at once, bounding transient memory during
  batch rendering. Set to null to disable.
- `MarkerIconRenderer.maxRasterPixels` (default 4194304, one 2048 x 2048
  physical bitmap): renders whose physical pixel count exceeds the budget
  throw `ArgumentError` instead of allocating enormous bitmaps. Set to null to
  disable.
- Re-exports of the remaining Google Maps types used by the package API:
  `Marker`, `MarkerId`, `LatLng`, `LatLngBounds`, `InfoWindow`,
  `BitmapDescriptor`, `MapBitmap`, `BytesMapBitmap`, `MapBitmapScaling`,
  `GroundOverlay`, and `GroundOverlayId`. The whole marker flow now works from
  the `marker_widget` import alone.

### Changed

- `MarkerIcon.toMapBitmap` / `toBitmapDescriptor` return the identical
  `BytesMapBitmap` instance for repeated calls with equal options on the same
  icon. Rebuilt markers therefore stay equal to their previous versions and
  google_maps_flutter no longer pushes redundant platform-side icon updates
  for unchanged markers.
- Dimensions and ratios are validated as positive and finite everywhere:
  NaN and infinity are rejected with descriptive `ArgumentError` /
  `StateError` instead of propagating to the platform.
- `MarkerIconRenderer` constructor configuration is validated at runtime with
  `ArgumentError` (previously a debug-only assert covered `maxCacheEntries`
  only).
- `MarkerIcon.toMarker` and the widget `toMarker` extension throw
  `ArgumentError` when the base is an `AdvancedMarker`, which would otherwise
  silently flow through the classic marker pipeline; use `toAdvancedMarker` or
  `toAdvancedPinMarker`.
- Contextless rendering in a multi-view app with no implicit view now throws a
  `StateError` asking for a `BuildContext` instead of picking an arbitrary
  `FlutterView`.
- `removeFromCache` removes every size/pixel-ratio variant of the key,
  `isCached` matches any variant, `peekCache` returns the most recently used
  variant, and `cacheSize` counts each variant as one entry.

## [2.0.1] - 2026-07-18

### Added

- AI coding-assistant support, installable from the GitHub repository for both
  Claude Code and OpenAI Codex (`plugins/marker-widget` plus repo marketplace
  catalogs). Includes four package-specific skills (integration and sizing,
  caching and performance tuning, symptom-based troubleshooting, and a guided
  v1-to-v2 migration), a read-only marker_widget reviewer agent for Claude
  Code, shared API references, and an evaluation suite. See "AI coding-assistant
  support" in the README. The plugin tree is excluded from the pub.dev archive;
  the Dart package itself is unchanged.
- Repository maintainer guidance (`AGENTS.md`, imported by `CLAUDE.md`) and a
  structural validator (`tool/validate_agent_plugin.dart`) wired into CI.

### Changed

- `dart pub publish` archive no longer contains leftover empty `lib/src/`
  directories.
- The pub.dev publish workflow now runs exclusively on release tags
  (`workflow_dispatch` trigger removed).

No runtime, API, or dependency changes.

## [2.0.0] - 2026-03-08

### Breaking

- Removed `MarkerIconScalingMode`.
- Replaced the old flat scaling parameters with:
  - `WidgetBitmapRenderOptions` for off-screen rendering
  - `MapBitmapOptions` for map bitmap output
- Updated `MarkerIconRenderer.render()` to accept `WidgetBitmapRenderOptions`.
- Renamed `Widget.toMarkerBitmap()` to `Widget.toBitmapDescriptor()`.
- Removed the top-level `widgetTo*` helpers in favor of widget extensions with
  optional named `context`.
- Removed `MarkerBuildOptions` and `AdvancedMarkerBuildOptions`. Marker builder
  APIs now accept real upstream `Marker` and `AdvancedMarker` objects.
- Updated widget extensions to use optional named `context`, `renderOptions`,
  and `bitmapOptions`.
- Replaced `MapBitmapOptions.renderedDpr()` with
  `MapBitmapOptions.pixelPerfect()`.
- Raised the minimum supported SDK versions to Flutter 3.41.4 and Dart 3.10.

### Added

- `MapBitmapOptions` and `WidgetBitmapRenderOptions` value objects.
- `MapBitmapOptions.pixelPerfect()` for pixel-perfect display using the
  rendered widget DPR.
- `MarkerIcon.toGroundOverlayBitmap()`.
- `MarkerIcon.toBitmapGlyph()`.
- `MarkerIcon.toPinConfig()`.
- `MarkerIcon.toMarker()` and `MarkerIcon.toAdvancedMarker()`.
- `MarkerIcon.toAdvancedPinMarker()` for one-call widget-to-pin-marker flow.
- Widget extension helpers:
  - `toGroundOverlayBitmap()`
  - `toBitmapGlyph()`
  - `toPinConfig()`
  - `toMarker()`
  - `toAdvancedMarker()`
  - `toAdvancedPinMarker()`
- `buildClusterCacheKey()`.
- `buildMarkerCacheKey(extra: ...)` for additional visual-state cache inputs.
- `defaultMarkerIconRenderer` exposed for cache inspection, clearing, and
  prewarming.
- `Equatable` on all value objects for structural equality.
- Curated re-exports for advanced marker types that are missing from
  `google_maps_flutter`.

### Changed

- `MapBitmapScaling.none` is now supported through raw bitmap conversion.
- `toGroundOverlayBitmap()` is a discoverability alias for the raw
  `MapBitmapScaling.none` path.
- Renderer context capture now includes `Localizations` and
  `DefaultAssetBundle`, not just themes and `MediaQuery`.
- Cache invalidation now blocks stale in-flight renders from repopulating cache
  after `clearCache()` or `removeFromCache()`.
- README and example app now demonstrate base `Marker` / `AdvancedMarker`
  inputs, advanced marker pins, and ground overlays.

## [1.1.0] - 2025-12-04

### Added

- **`MarkerIcon.toMapBitmap()`**: Returns `BytesMapBitmap` directly for users who need the concrete type for storage or interoperability.
- **`MarkerIcon.sizeInBytes`**: Getter for memory tracking.
- **Memory-based cache eviction**: New `maxCacheBytes` parameter (default 50 MB) on `MarkerIconRenderer` to prevent unbounded memory growth.
- **Concurrent render deduplication**: Multiple simultaneous calls with the same `cacheKey` now share a single render operation instead of duplicating work.
- **Cache introspection**:
  - `MarkerIconRenderer.cacheSize` — current entry count.
  - `MarkerIconRenderer.cacheSizeInBytes` — current memory usage.
  - `MarkerIconRenderer.isCached(key)` — check if a key exists.
  - `MarkerIconRenderer.peekCache(key)` — get without LRU bump.
- **New extension methods on `Widget`**:
  - `toMapBitmap()` — returns `BytesMapBitmap` directly.
  - `toMarkerIcon()` — returns `MarkerIcon` for storage and later conversion.
- **New standalone functions**:
  - `widgetToMapBitmap()` — convenience without `BuildContext`, returns `BytesMapBitmap`.
  - `widgetToMarkerIcon()` — convenience without `BuildContext`, returns `MarkerIcon`.
- **`@immutable` annotation** on `MarkerIcon` for correctness.
- **Enhanced documentation**: Added "Render Once, Reuse Everywhere" pattern examples in README and class docs.

### Changed

- **`MapBitmapScaling.none` validation**: Now throws `StateError` for both scaling modes (not just `imagePixelRatio`). This was already invalid at the platform level; the error message is now clearer and fails earlier.
- Improved code style: explicit type annotations throughout for better readability.
- Updated README with performance tips, memory management guidance, and static vs dynamic marker strategies.

## [1.0.0] - 2025-11-24

### Added

- Initial release of **marker_widget**.
- Off-screen renderer that converts any `Widget` into PNG bytes using:
  - `RenderView` + `ViewConfiguration` with logical & physical constraints.
  - `RepaintBoundary` and explicit `PipelineOwner` / `BuildOwner` lifecycle.
- `MarkerIcon` value object that encapsulates:
  - PNG bytes.
  - Logical size.
  - Device pixel ratio.
  - Conversion to `BitmapDescriptor.bytes` with `MapBitmapScaling`.
- `MarkerIconRenderer`:
  - Configurable default logical size.
  - Optional LRU-based in-memory cache with size limit.
  - Optional image-aware second pass via `waitForImages`.
- `MarkerIconScalingMode`:
  - `logicalSize` mode (stable logical size, default).
  - `imagePixelRatio` mode (pixel-perfect using `imagePixelRatio`).
- `WidgetMarkerExtension.toMarkerBitmap`:
  - Convert any widget into a `BitmapDescriptor` using the default (or injected) renderer.
  - Supports `waitForImages`, custom pixel ratio, bitmap scaling, and scaling mode.
- Top-level `widgetToMarkerBitmap` helper for use without a `BuildContext`.
- `buildMarkerCacheKey` helper for theme/locale/size-aware marker caching.
- Example app demonstrating:
  - Basic usage with a custom card-like marker.
  - Toggling between logical-size and image-pixel-ratio scaling modes.
