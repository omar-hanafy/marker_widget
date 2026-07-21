# marker_widget v3 API quick reference

Ground truth: `lib/src/marker_widget.dart` in marker_widget 3.x. When in doubt, read the
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
  and `DefaultAssetBundle` from the app. Its locale is used for image-provider
  resolution, but localization resources are not copied. Omit only for
  environment-independent icons.
- `renderer` (optional `MarkerIconRenderer`): defaults to `MarkerIconRenderer.shared`.
- `renderOptions` (`MarkerRenderOptions`): how the widget is rasterized.
- `bitmapOptions` (`MapBitmapOptions`): how the bytes are interpreted on the map
  (not on `toGroundOverlayBitmap`/`toMarkerIcon`).
- `toPinConfig`/`toAdvancedPinMarker` also take `backgroundColor` and `borderColor`.

`toMarker`/`toAdvancedMarker`/`toAdvancedPinMarker` apply the rendered icon to the
`base` object via `copyWith(iconParam: ...)`; everything else on the base is preserved.

## MarkerRenderOptions (render layer)

| Field | Default | Meaning |
|---|---|---|
| `logicalSize` | renderer's `defaultLogicalSize` (96x96) | Layout size of the off-screen widget in logical px |
| `pixelRatio` | current view DPR | Rasterization density |
| `cacheKey` | `null` | Cache identity together with the resolved size and DPR. `null` means NO caching and NO dedup |
| `prepare` | `null` | Async font/data/resource work awaited on a cache miss before image resolution and rendering |
| `imageDependencies` | `const []` | `MarkerImageDependency` values decoded before capture (see Image dependencies below) |

`MarkerRenderOptions` and `MapBitmapOptions` are value objects with structural
`==`/`hashCode`. Function equality for `prepare` is identity-based.

## Image dependencies (3.0)

Declare every `ImageProvider` the rendered widget displays (through `Image`,
`DecorationImage`, `CircleAvatar.backgroundImage`, ...):

```dart
final avatar = NetworkImage(url);
MarkerRenderOptions(
  logicalSize: const Size(56, 56),
  cacheKey: MarkerCacheKey(id, extra: status),
  imageDependencies: [
    MarkerImageDependency(
      avatar,
      configurationSize: const Size(56, 56),
    ),
  ],
)
```

Contract:

1. Each dependency's provider is resolved against the captured render environment
   (pixel ratio, locale, text direction, asset bundle, platform) and awaited to FULL
   decode before the widget tree is built. One deterministic paint pass; no delays,
   no races.
2. Decoded images are retained until capture completes, so the image cache cannot
   evict them mid-render.
3. The widget must display the SAME provider instances (or providers with equal
   cache keys), or its own lookup misses the warmed image and captures blank.
4. `configurationSize` must match the size supplied by the rendered `Image` or
   `DecorationImage` when a provider's cache key depends on size. Omit it when the
   widget resolves that provider without a size.
5. A failing provider throws `MarkerImageLoadException` (fields: `provider`,
   `cause`, `stackTrace`) instead of capturing a blank area. Catch it to fall
   back to a placeholder icon.
6. Image-backed jobs use the separate `maxConcurrentImageLoads` FIFO permit from
   dependency resolution through capture. This bounds decoded images without
   occupying a render-tree permit while a provider is still loading.
7. Use `prepare` for runtime-loaded fonts, data, or other required async resources.
   It runs only on a cache miss and completes before image resolution begins. Put a
   prepared content revision in `cacheKey` whenever that content changes pixels.

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
   infinity are rejected).
4. `pixelPerfect()` cannot be combined with explicit `width`/`height`/
   `imagePixelRatio`; conversion throws `StateError` in every build mode.

## MarkerCacheKey (3.0)

```dart
const MarkerCacheKey(Object id, {Brightness? brightness, Locale? locale, Object? extra})
const MarkerCacheKey.cluster({required int count, Brightness? brightness, Locale? locale, Object? extra})
```

Structured, collision-safe cache identity. The renderer appends the resolved
logical size and pixel ratio to every cache entry itself, so the key carries only
CONTENT inputs: identity, brightness, locale, and `extra` for anything else that
changes pixels (selection, status, badge count, avatar revision).

- `extra` is compared with `==`: use immutable values with structural equality -
  records such as `(selected: true, badge: 3)` work well. Fresh identity-based
  collections miss the cache; mutating and reusing one can return stale output.
- `MarkerCacheKey.cluster(count: 5)` never collides with `MarkerCacheKey(5)`.
- Any custom object with value semantics also works as `cacheKey`;
  `MarkerCacheKey` is the blessed convenience, not a requirement.

## MarkerIcon (cacheable value object)

Fields: `bytes` (PNG), `logicalSize`, `pixelRatio`, `sizeInBytes`.
Synchronous converters mirroring the extensions: `toMapBitmap`, `toBitmapDescriptor`,
`toGroundOverlayBitmap`, `toBitmapGlyph`, `toPinConfig`, `toMarker(base:)`,
`toAdvancedMarker(base:)`, `toAdvancedPinMarker(base:)`.

Integrity (3.0): the constructor is non-const and defensively copies `bytes`;
the stored `bytes` is an unmodifiable view (writing to it throws
`UnsupportedError`); `hashCode` hashes the content once and is memoized. Icons
are genuinely immutable value objects.

Descriptor identity: repeated `toMapBitmap`/`toBitmapDescriptor` calls with an
equal `MapBitmapOptions` on the same icon instance return the IDENTICAL
`BytesMapBitmap` object. Markers rebuilt from a reused icon therefore stay `==` to
their previous versions and google_maps_flutter sends no redundant platform icon
update. Two value-equal but distinct `MarkerIcon` instances still produce distinct
descriptors; reuse instances.

`toMarker(base:)` throws `ArgumentError` when `base` is an `AdvancedMarker`;
route advanced markers through `toAdvancedMarker`/`toAdvancedPinMarker`.

## MarkerIconRenderer

```dart
MarkerIconRenderer({
  Size defaultLogicalSize = const Size(96, 96),
  bool enableCaching = true,
  int maxCacheEntries = 64,
  int? maxCacheBytes = 50 * 1024 * 1024, // null disables byte-based eviction
  int? maxConcurrentRenders = 1,         // null disables the FIFO gate
  int? maxConcurrentImageLoads = 1,      // null disables the image-job gate
  int? maxRasterPixels = 4 * 1024 * 1024, // null disables the budget
})
```

`MarkerIconRenderer.shared` is the shared instance used by all extension methods
when `renderer` is omitted.

Configuration is validated at runtime: non-positive or non-finite values throw
`ArgumentError` in release builds too.

Cache identity is `(cacheKey, resolved logicalSize, resolved pixelRatio)`: one
key can never return an icon rendered at another size or DPR, and `cacheSize` counts
each such combination as one entry. `isCached(key)` matches any variant of the key,
`peekCache(key)` returns the most recently used variant (no LRU bump),
`removeFromCache(key)` evicts every variant. After `clearCache()`/
`removeFromCache()`, in-flight renders started earlier still resolve for their
callers but will NOT repopulate the cache.

Render limits: `maxConcurrentRenders` gates detached render trees;
`maxConcurrentImageLoads` separately gates image-backed jobs from dependency
resolution through capture, so decoded native images stay bounded while image-free
jobs bypass stalled providers. Both are FIFO. `maxRasterPixels` rejects a render
whose exact rounded physical output area exceeds the budget (default equals one
2048x2048 physical bitmap) with `ArgumentError` before any allocation.

Lifecycle: the off-screen tree is fully unmounted after capture, so
`State.dispose` runs for stateful marker widgets; timers/controllers they hold are
released per render.

An icon larger than `maxCacheBytes` on its own is never cached
(`maxCacheBytes` measures encoded PNG bytes, not decoded platform bitmap memory).

## Re-exports

`package:marker_widget/marker_widget.dart` re-exports the Google Maps types its API
uses, so the whole marker flow works from one import: `AdvancedMarker`,
`AdvancedMarkerGlyph`, `BitmapDescriptor`, `BitmapGlyph`, `BytesMapBitmap`,
`CircleGlyph`, `GroundOverlay`, `GroundOverlayId`, `InfoWindow`, `LatLng`,
`LatLngBounds`, `MapBitmapScaling`, `Marker`, `MarkerCollisionBehavior`,
`MarkerId`, `PinConfig`, `TextGlyph`. These are the same declarations
`google_maps_flutter` exports, so both imports coexist without conflicts. Do not add
an import of `google_maps_flutter_platform_interface` to consumer code; import from
`marker_widget` (or `google_maps_flutter` where it exports the type).

## Exact runtime error strings (source of truth for diagnosis)

| Error contains | Thrown when |
|---|---|
| `MarkerIcon.bytes must not be empty.` | Constructing an icon with empty bytes |
| `MapBitmapScaling.none cannot be combined with width, height, or imagePixelRatio.` | Rule 2 above (also triggered by `pixelPerfect` + `none`) |
| `MapBitmapOptions.width must be > 0 and finite` / `.height ...` / `.imagePixelRatio ...` | Non-positive, NaN, or infinite values |
| `width and height must both be > 0 and finite.` with argument `logicalSize` | Constructing an icon with a degenerate logical size |
| `must be > 0 and finite.` with argument `pixelRatio` | Constructing an icon with a degenerate pixel ratio |
| `MapBitmapOptions.useRenderedPixelRatio cannot be combined with width, height, or imagePixelRatio.` | `pixelPerfect()` combined with explicit size metadata |
| `logicalSize.width and logicalSize.height must both be > 0 and finite.` (`ArgumentError`) | Render called with a non-positive/NaN/infinite logical size |
| `the resolved pixelRatio must be > 0 and finite.` (`ArgumentError`) | Render called with a non-positive/NaN/infinite explicit or view pixel ratio |
| `the resolved physical dimensions and pixel count must be finite.` (`ArgumentError`) | Logical size times DPR overflows or is otherwise invalid |
| `configurationSize dimensions must be finite and non-negative` (`ArgumentError`) | A `MarkerImageDependency` has an invalid size |
| `above maxRasterPixels` (`ArgumentError`) | Render whose physical pixel count exceeds the raster budget; shrink the marker or adjust `maxRasterPixels` |
| `AdvancedMarker cannot go through toMarker` (`ArgumentError`) | An `AdvancedMarker` passed as `base` to classic `toMarker`; use `toAdvancedMarker` |
| `must be > 0.` / `must be > 0 when provided.` (`ArgumentError`) | Invalid `MarkerIconRenderer` constructor configuration |
| `MarkerImageLoadException: image dependency ... failed to load` | A declared `imageDependencies` provider failed to load or decode; fix the provider or catch and fall back |
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
- SDK floors: Dart `^3.12.0`, Flutter `>=3.44.0`, google_maps_flutter `^2.17.1`.
