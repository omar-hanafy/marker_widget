# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
