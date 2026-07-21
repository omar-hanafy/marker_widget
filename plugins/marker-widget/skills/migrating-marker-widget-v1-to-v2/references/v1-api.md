# marker_widget v1.x API surface and exact v2 mappings

Ground truth: `lib/src/marker_widget.dart` at tag v1.1.0 (git b605abc). v1.0.0 differs
from 1.1.0 only by lacking `toMapBitmap`/`toMarkerIcon`/`widgetToMapBitmap`/
`widgetToMarkerIcon`/`sizeInBytes`/`maxCacheBytes`/cache introspection; the same
mappings apply.

## Removed / renamed symbols (compile errors after upgrade)

| v1 symbol | v2 replacement |
|---|---|
| `MarkerIconScalingMode` (enum) | Gone. `logicalSize` mode -> default `MapBitmapOptions()`; `imagePixelRatio` mode -> `MapBitmapOptions.pixelPerfect()` |
| `Widget.toMarkerBitmap(context, ...)` | `Widget.toBitmapDescriptor(context: context, renderOptions: ..., bitmapOptions: ...)` |
| `widgetToMarkerBitmap(widget, ...)` | `widget.toBitmapDescriptor(...)` (no context arg needed) |
| `widgetToMapBitmap(widget, ...)` | `widget.toMapBitmap(...)` |
| `widgetToMarkerIcon(widget, ...)` | `widget.toMarkerIcon(...)` |
| `MapBitmapOptions.renderedDpr()` (never shipped in 1.x stable; only in prereleases) | `MapBitmapOptions.pixelPerfect()` |
| `MarkerBuildOptions`, `AdvancedMarkerBuildOptions` (prerelease-only builders) | Pass real `Marker` / `AdvancedMarker` objects as `base:` |

## Signature reshaping (same concept, new shape)

v1 extension methods took a REQUIRED POSITIONAL `BuildContext` plus flat named
parameters. v2 takes an OPTIONAL NAMED `context` plus two option objects.

v1 (1.1.0):

```dart
Future<BitmapDescriptor> toMarkerBitmap(
  BuildContext context, {
  MarkerIconRenderer? renderer,
  Size logicalSize = const Size(96, 96),
  double? pixelRatio,
  bool waitForImages = false,
  Object? cacheKey,
  Duration? initialImageDelay,
  Duration? imageRepaintDelay,
  MapBitmapScaling bitmapScaling = MapBitmapScaling.auto,
  MarkerIconScalingMode scalingMode = MarkerIconScalingMode.logicalSize,
})
```

`toMapBitmap` had the identical v1 shape; `toMarkerIcon` the same minus
`bitmapScaling`/`scalingMode`.

v2 equivalents:

```dart
Future<BitmapDescriptor> toBitmapDescriptor({
  BuildContext? context,
  MarkerIconRenderer? renderer,
  WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
  MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
})
```

## Flat parameter -> options object mapping

| v1 flat parameter | v2 home |
|---|---|
| `logicalSize` | `WidgetBitmapRenderOptions.logicalSize` |
| `pixelRatio` | `WidgetBitmapRenderOptions.pixelRatio` |
| `waitForImages` | `WidgetBitmapRenderOptions.waitForImages` |
| `cacheKey` | `WidgetBitmapRenderOptions.cacheKey` |
| `initialImageDelay` | `WidgetBitmapRenderOptions.initialImageDelay` |
| `imageRepaintDelay` | `WidgetBitmapRenderOptions.imageRepaintDelay` |
| `bitmapScaling` | `MapBitmapOptions.bitmapScaling` |
| `scalingMode: MarkerIconScalingMode.logicalSize` | `MapBitmapOptions()` (default behavior) |
| `scalingMode: MarkerIconScalingMode.imagePixelRatio` | `MapBitmapOptions.pixelPerfect()` |
| `renderer` | unchanged (`renderer:`) |
| positional `context` | named optional `context:` |

## MarkerIcon method changes

v1:

```dart
BytesMapBitmap toMapBitmap({MapBitmapScaling bitmapScaling, MarkerIconScalingMode scalingMode})
BitmapDescriptor toBitmapDescriptor({MapBitmapScaling bitmapScaling, MarkerIconScalingMode scalingMode})
```

v2:

```dart
BytesMapBitmap toMapBitmap({MapBitmapOptions options = const MapBitmapOptions()})
BitmapDescriptor toBitmapDescriptor({MapBitmapOptions options = const MapBitmapOptions()})
```

Mapping: `bitmapScaling: X` becomes `options: MapBitmapOptions(bitmapScaling: X)`;
`scalingMode: imagePixelRatio` becomes `options: const MapBitmapOptions.pixelPerfect()`.
v1 rejected `MapBitmapScaling.none` entirely; v2 supports it (raw pass-through path)
with no size metadata.

## MarkerIconRenderer.render changes

v1:

```dart
Future<MarkerIcon> render(Widget widget, {BuildContext? context, Size? logicalSize,
  double? pixelRatio, bool waitForImages = false, Object? cacheKey,
  Duration? initialImageDelay, Duration? imageRepaintDelay})
```

v2:

```dart
Future<MarkerIcon> render(Widget widget, {BuildContext? context,
  WidgetBitmapRenderOptions options = const WidgetBitmapRenderOptions()})
```

Constructor: `maxCacheEntries`, `maxCacheBytes`, `enableCaching`, `defaultLogicalSize`,
delays are unchanged between 1.1.0 and 2.x.

## buildMarkerCacheKey changes

v1 had no `extra` parameter. v2 adds `extra:` (appends `|extra=...`); existing calls
compile unchanged, but keys gain a trailing `|extra=none` component, so PERSISTED v1
key strings (if an app stored them) no longer match freshly built v2 keys. In-memory
usage is unaffected. `buildClusterCacheKey` is new in v2.

## Behavior differences to preserve or flag

1. Default on-map sizing is identical (logical size path), so plain migrations keep
   marker sizes.
2. v1 `scalingMode: imagePixelRatio` produced DPR-dependent on-map size; the exact
   equivalent is `MapBitmapOptions.pixelPerfect()`. Do NOT silently drop it to the
   default, that changes visible marker size on high-DPR devices.
3. v1 extension `logicalSize` default was `Size(96, 96)` per-call; v2 default comes
   from the renderer's `defaultLogicalSize` (also 96x96 unless customized). If the app
   constructed a custom renderer with a different `defaultLogicalSize`, calls that
   previously used the v1 per-call default of 96x96 now inherit the renderer default:
   set `logicalSize` explicitly in that case.
4. v1 `widgetTo*` helpers never captured context; replacing them with extension calls
   WITHOUT `context:` is behavior-preserving. Adding `context:` during migration is an
   improvement but changes rendered output (theme/locale become inherited): call it out
   rather than doing it silently.
5. New capture in v2: with `context:`, localizations and `DefaultAssetBundle` are now
   inherited too (v1 captured only themes/MediaQuery/directionality). Rendered output
   can legitimately change for localized marker widgets: expected, mention it.
6. Cache invalidation semantics changed: v2 blocks stale in-flight renders from
   repopulating the cache after `clearCache()`/`removeFromCache()`. Apps that relied on
   the old repopulation behavior (unlikely, it was a bug) must re-render after clearing.

## Environment floors

| | v1.1.0 | v2.x |
|---|---|---|
| Dart SDK | >=3.7.0 <4.0.0 | ^3.10.0 |
| Flutter | >=3.29.0 | >=3.41.4 |
| google_maps_flutter | ^2.14.0 | ^2.15.0 |
| new direct dependency | (none) | `equatable` (transitive; no consumer action) |

Consumers must also depend on `google_maps_flutter ^2.15.0` or later and may need to
raise their own SDK floors before `dart pub get` resolves.

## Detection greps (run in the consumer project)

```
grep -rn "toMarkerBitmap\|widgetToMarkerBitmap\|widgetToMapBitmap\|widgetToMarkerIcon\|MarkerIconScalingMode\|scalingMode\s*:\|MarkerBuildOptions\|AdvancedMarkerBuildOptions\|renderedDpr" lib/ test/
```

Any hit means v1-era usage remains. A clean grep plus `marker_widget: ^2.0.0` in
pubspec.yaml and a passing `dart analyze` means the migration is complete.
