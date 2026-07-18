# marker_widget v2 API quick reference

Ground truth: `lib/src/marker_widget.dart` in marker_widget 2.x. When in doubt, read the
installed source in the consumer project: `.dart_tool/package_config.json` locates the
package root; the whole implementation is that one file.

## Widget extension methods (all on `Widget`, all async)

| Method | Returns | Use when |
|---|---|---|
| `toBitmapDescriptor()` | `BitmapDescriptor` | You only need `Marker.icon` |
| `toMapBitmap()` | `BytesMapBitmap` | You need the concrete bitmap type (storage, interop) |
| `toGroundOverlayBitmap()` | `BytesMapBitmap` | Building a `GroundOverlay` image (raw, unscaled) |
| `toBitmapGlyph()` | `BitmapGlyph` | Glyph for an advanced marker `PinConfig` |
| `toPinConfig()` | `PinConfig` | Full pin config with rendered glyph |
| `toMarkerIcon()` | `MarkerIcon` | Cacheable value object; convert synchronously later |
| `toMarker(base: Marker)` | `Marker` | One-call classic marker |
| `toAdvancedMarker(base: AdvancedMarker)` | `AdvancedMarker` | Advanced marker whose whole icon is the widget |
| `toAdvancedPinMarker(base: AdvancedMarker)` | `AdvancedMarker` | Advanced pin (colored pin + widget glyph) |

Common named parameters on every extension method:

- `context` (optional `BuildContext`): inherit MediaQuery, theme, directionality,
  localizations, and `DefaultAssetBundle` from the app. Omit only for theme-independent
  icons.
- `renderer` (optional `MarkerIconRenderer`): defaults to `defaultMarkerIconRenderer`.
- `renderOptions` (`WidgetBitmapRenderOptions`): how the widget is rasterized.
- `bitmapOptions` (`MapBitmapOptions`): how the bytes are interpreted on the map
  (not on `toGroundOverlayBitmap`/`toMarkerIcon`).
- `toPinConfig`/`toAdvancedPinMarker` also take `backgroundColor` and `borderColor`.

`toMarker`/`toAdvancedMarker`/`toAdvancedPinMarker` apply the rendered icon to the
`base` object via `copyWith(iconParam: ...)`; everything else on the base is preserved.

## WidgetBitmapRenderOptions (render layer)

| Field | Default | Meaning |
|---|---|---|
| `logicalSize` | renderer's `defaultLogicalSize` (96x96) | Layout size of the off-screen widget in logical px |
| `pixelRatio` | current view DPR | Rasterization density |
| `waitForImages` | `false` | Second paint pass when image render objects are detected |
| `cacheKey` | `null` | Cache identity. `null` means NO caching and NO dedup |
| `initialImageDelay` | renderer default 16ms | Delay before the image check |
| `imageRepaintDelay` | renderer default 200ms | Extra delay before the second paint |

## MapBitmapOptions (map display layer)

| Constructor / field | Effect |
|---|---|
| `MapBitmapOptions()` | Defaults: on-map size = rendered `logicalSize` (device-independent) |
| `width` / `height` | Explicit on-map logical size |
| `imagePixelRatio` | Platform derives size from bitmap pixels / ratio |
| `MapBitmapOptions.pixelPerfect()` | Uses the icon's rendered DPR as `imagePixelRatio` at conversion time |
| `bitmapScaling: MapBitmapScaling.none` | Raw bytes pass-through; `width`, `height`, `imagePixelRatio`, and `pixelPerfect` must all stay unset |

Behavior rules (enforced by `StateError`s):

1. Omit `width`/`height`/`imagePixelRatio` and scaling `auto`: on-map size = `logicalSize`.
2. `MapBitmapScaling.none` + any size/ratio metadata: throws.
3. `width`/`height`/`imagePixelRatio` must be > 0 when provided.
4. `pixelPerfect()` cannot be combined with explicit `width`/`height`/`imagePixelRatio`
   (constructor assert).

## MarkerIcon (cacheable value object)

Fields: `bytes` (PNG), `logicalSize`, `pixelRatio`, `sizeInBytes`.
Synchronous converters mirroring the extensions: `toMapBitmap`, `toBitmapDescriptor`,
`toGroundOverlayBitmap`, `toBitmapGlyph`, `toPinConfig`, `toMarker(base:)`,
`toAdvancedMarker(base:)`, `toAdvancedPinMarker(base:)`.

## MarkerIconRenderer

```dart
MarkerIconRenderer({
  Size defaultLogicalSize = const Size(96, 96),
  bool enableCaching = true,
  int maxCacheEntries = 64,
  int? maxCacheBytes = 50 * 1024 * 1024, // null disables byte-based eviction
  Duration initialImageDelay = const Duration(milliseconds: 16),
  Duration imageRepaintDelay = const Duration(milliseconds: 200),
})
```

Cache API: `cacheSize`, `cacheSizeInBytes`, `isCached(key)`, `peekCache(key)` (no LRU
bump), `removeFromCache(key)`, `clearCache()`. Invalidation is generation-based: after
`clearCache()`/`removeFromCache()`, in-flight renders started earlier will NOT
repopulate the cache.

`defaultMarkerIconRenderer` is the shared instance used by all extension methods when
`renderer` is omitted. An icon larger than `maxCacheBytes` on its own is never cached.

## Cache key helpers

```dart
buildMarkerCacheKey({required Object id, required Size logicalSize,
  required double pixelRatio, Brightness? brightness, Locale? locale, Object? extra})
buildClusterCacheKey({required int count, ...same...})
```

Every input that changes rendered pixels must be part of the key: id/count, size, DPR,
brightness, locale, and `extra` for selection state, status, badge counts, avatar
versions.

## Re-exports

`package:marker_widget/marker_widget.dart` re-exports these advanced marker types that
`google_maps_flutter` does not yet re-export: `AdvancedMarker`, `AdvancedMarkerGlyph`,
`BitmapGlyph`, `CircleGlyph`, `MarkerCollisionBehavior`, `PinConfig`, `TextGlyph`.
Do not add an import of `google_maps_flutter_platform_interface` to consumer code for
these; import them from `marker_widget`.

## Exact runtime error strings (source of truth for diagnosis)

| Error contains | Thrown when |
|---|---|
| `MarkerIcon.bytes must not be empty.` | Converting an icon constructed with empty bytes |
| `MapBitmapScaling.none cannot be combined with width, height, or imagePixelRatio.` | Rule 2 above (also triggered by `pixelPerfect` + `none`) |
| `MapBitmapOptions.width must be > 0` / `.height must be > 0` / `.imagePixelRatio must be > 0` | Non-positive values |
| `MarkerIcon.logicalSize must be > 0 in both dimensions.` | Default-size conversion with degenerate logical size |
| `logicalSize.width and logicalSize.height must both be > 0.` (`ArgumentError`) | Render called with a non-positive logical size |
| `pixelRatio must be > 0 when provided.` (`ArgumentError`) | Render called with non-positive pixel ratio |
| `No FlutterView is available. Ensure WidgetsFlutterBinding is initialized` | Render before `WidgetsFlutterBinding.ensureInitialized()` or in a headless isolate |
| `Failed to convert widget to marker image bytes.` | PNG encoding returned null (platform/graphics failure) |

## Platform notes

- UI isolate only. The renderer builds a real element tree; `compute`/background
  isolates cannot run it.
- Advanced markers require: `GoogleMap.markerType: GoogleMapMarkerType.advancedMarker`,
  a `GoogleMap.mapId` (cloud map ID), and on web `&libraries=marker` in the Maps
  JavaScript bootstrap in `web/index.html`.
- `PinConfig` has an upstream iOS issue where the marker may fail to render:
  https://issuetracker.google.com/issues/370536110. Prefer `toAdvancedMarker` (full
  bitmap icon) over `toAdvancedPinMarker` when iOS reliability matters.
- Supported platforms: Android, iOS, web (google_maps_flutter's platforms).
