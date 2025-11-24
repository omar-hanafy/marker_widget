# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
