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
| `cacheKey` | `null` | Cache identity together with the resolved size and DPR (2.1+). `null` means NO caching and NO dedup |
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
3. `width`/`height`/`imagePixelRatio` must be > 0 and finite when provided (NaN and
   infinity are rejected, 2.1+).
4. `pixelPerfect()` cannot be combined with explicit `width`/`height`/`imagePixelRatio`
   (constructor assert).

## MarkerIcon (cacheable value object)

Fields: `bytes` (PNG), `logicalSize`, `pixelRatio`, `sizeInBytes`.
Synchronous converters mirroring the extensions: `toMapBitmap`, `toBitmapDescriptor`,
`toGroundOverlayBitmap`, `toBitmapGlyph`, `toPinConfig`, `toMarker(base:)`,
`toAdvancedMarker(base:)`, `toAdvancedPinMarker(base:)`.

Descriptor identity (2.1+): repeated `toMapBitmap`/`toBitmapDescriptor` calls with an
equal `MapBitmapOptions` on the same icon instance return the IDENTICAL
`BytesMapBitmap` object. Markers rebuilt from a reused icon therefore stay `==` to
their previous versions and google_maps_flutter sends no redundant platform icon
update. Two value-equal but distinct `MarkerIcon` instances still produce distinct
descriptors; reuse instances.

`toMarker(base:)` throws `ArgumentError` when `base` is an `AdvancedMarker` (2.1+);
route advanced markers through `toAdvancedMarker`/`toAdvancedPinMarker`.

## MarkerIconRenderer

```dart
MarkerIconRenderer({
  Size defaultLogicalSize = const Size(96, 96),
  bool enableCaching = true,
  int maxCacheEntries = 64,
  int? maxCacheBytes = 50 * 1024 * 1024, // null disables byte-based eviction
  int? maxConcurrentRenders = 3,         // 2.1+; null disables the FIFO gate
  int? maxRasterPixels = 4 * 1024 * 1024, // 2.1+; null disables the budget
  Duration initialImageDelay = const Duration(milliseconds: 16),
  Duration imageRepaintDelay = const Duration(milliseconds: 200),
})
```

Configuration is validated at runtime (2.1+): non-positive or non-finite values throw
`ArgumentError` in release builds too (previously a debug-only assert on
`maxCacheEntries`).

Cache identity is `(cacheKey, resolved logicalSize, resolved pixelRatio)` (2.1+): one
key can never return an icon rendered at another size or DPR, and `cacheSize` counts
each such combination as one entry. `isCached(key)` matches any variant of the key,
`peekCache(key)` returns the most recently used variant (no LRU bump),
`removeFromCache(key)` evicts every variant. After `clearCache()`/
`removeFromCache()`, in-flight renders started earlier still resolve for their
callers but will NOT repopulate the cache.

Render limits (2.1+): `maxConcurrentRenders` gates how many detached render trees run
at once; excess renders wait in FIFO order. `maxRasterPixels` rejects a render whose
`width * height * pixelRatio^2` exceeds the budget (default equals one 2048x2048
physical bitmap) with `ArgumentError` before any allocation.

Lifecycle (2.1+): the off-screen tree is fully unmounted after capture, so
`State.dispose` runs for stateful marker widgets; timers/controllers they hold are
released per render.

`defaultMarkerIconRenderer` is the shared instance used by all extension methods when
`renderer` is omitted. An icon larger than `maxCacheBytes` on its own is never cached
(`maxCacheBytes` measures encoded PNG bytes, not decoded platform bitmap memory).

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

`package:marker_widget/marker_widget.dart` re-exports the Google Maps types its API
uses, so the whole marker flow works from one import (2.1+): `AdvancedMarker`,
`AdvancedMarkerGlyph`, `BitmapDescriptor`, `BitmapGlyph`, `BytesMapBitmap`,
`CircleGlyph`, `GroundOverlay`, `GroundOverlayId`, `InfoWindow`, `LatLng`,
`LatLngBounds`, `MapBitmap`, `MapBitmapScaling`, `Marker`, `MarkerCollisionBehavior`,
`MarkerId`, `PinConfig`, `TextGlyph`. These are the same declarations
`google_maps_flutter` exports, so both imports coexist without conflicts. Do not add
an import of `google_maps_flutter_platform_interface` to consumer code; import from
`marker_widget` (or `google_maps_flutter` where it exports the type).

## Exact runtime error strings (source of truth for diagnosis)

| Error contains | Thrown when |
|---|---|
| `MarkerIcon.bytes must not be empty.` | Converting an icon constructed with empty bytes |
| `MapBitmapScaling.none cannot be combined with width, height, or imagePixelRatio.` | Rule 2 above (also triggered by `pixelPerfect` + `none`) |
| `MapBitmapOptions.width must be > 0 and finite` / `.height ...` / `.imagePixelRatio ...` | Non-positive, NaN, or infinite values |
| `MarkerIcon.logicalSize must be > 0 and finite in both dimensions.` | Default-size conversion with degenerate logical size |
| `MarkerIcon.pixelRatio must be > 0 and finite to use MapBitmapOptions.useRenderedPixelRatio.` | `pixelPerfect()` on an icon with a degenerate pixel ratio |
| `logicalSize.width and logicalSize.height must both be > 0 and finite.` (`ArgumentError`) | Render called with a non-positive/NaN/infinite logical size |
| `pixelRatio must be > 0 and finite when provided.` (`ArgumentError`) | Render called with non-positive/NaN/infinite pixel ratio |
| `above maxRasterPixels` (`ArgumentError`) | Render whose physical pixel count exceeds the raster budget; shrink the marker or adjust `maxRasterPixels` |
| `AdvancedMarker cannot go through toMarker` (`ArgumentError`) | An `AdvancedMarker` passed as `base` to classic `toMarker`; use `toAdvancedMarker` |
| `must be > 0.` / `must be > 0 when provided.` / `must not be negative.` (`ArgumentError`) | Invalid `MarkerIconRenderer` constructor configuration |
| `No FlutterView is available. Ensure WidgetsFlutterBinding is initialized` | Render before `WidgetsFlutterBinding.ensureInitialized()` or in a headless isolate |
| `Multiple FlutterViews are available` (`StateError`) | Contextless render in a multi-view app with no implicit view; pass `context` |
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
