# Marker Widget

Render Flutter widgets into Google Maps bitmaps, glyphs, markers, and ground overlays.

`marker_widget` handles off-screen widget rendering, caching, and bitmap conversion so you can focus on map UI instead of `RenderView` plumbing.

## AI coding-assistant support (agent plugin)

Package-specific support for **Claude Code** and **OpenAI Codex** ships from this
repository as an installable agent plugin: five skills (correct integration and
sizing, cache/performance tuning, symptom-based troubleshooting, and guided
v1-to-v2 and v2-to-v3 migrations) plus a read-only reviewer agent for Claude Code.
This is tooling for coding agents, not a runtime feature of the Dart package, and it
is not part of the pub.dev archive.

Claude Code (CLI or `/plugin` in a session):

```bash
claude plugin marketplace add omar-hanafy/marker_widget
claude plugin install marker-widget@marker-widget
```

OpenAI Codex (CLI or `/plugins` in a session; supported in Codex CLI and ChatGPT
desktop/web Work mode, not the IDE extension):

```bash
codex plugin marketplace add omar-hanafy/marker_widget
codex plugin add marker-widget@marker-widget
```

Start a new agent session after installing (Codex requires it; it is good hygiene in
Claude Code too). Then try:

- "My marker_widget avatars from Image.network render as blank circles - fix it."
- "Migrate this app from marker_widget 2.0.1 to 3.0.0."
- Explicit invocation: `/marker-widget:troubleshooting-marker-widget` in Claude Code,
  or `$troubleshooting-marker-widget` in Codex.

The plugin contains instructions and reference documents only: no hooks, no MCP
servers, no executable scripts, no network access; the reviewer agent is restricted
to read-only tools. Compatibility: marker_widget 3.x (migration skills cover 1.x to
2.x and 2.x to 3.x); verified with Claude Code 2.1.x and codex-cli 0.144.x. Update
with `claude plugin update marker-widget` / `codex plugin marketplace upgrade
marker-widget`; uninstall with `claude plugin uninstall marker-widget` /
`codex plugin remove marker-widget@marker-widget`.

Full documentation (all capabilities, example prompts, Codex reviewer-subagent
recipe, maintainer guide): [`plugins/marker-widget/README.md`](plugins/marker-widget/README.md).

## Features

- Render self-contained widgets to `BitmapDescriptor`, `BytesMapBitmap`, or cacheable `MarkerIcon`
- Build classic `Marker` and `AdvancedMarker` objects directly
- Create `BitmapGlyph` and `PinConfig` from widgets for advanced marker pins
- Create raw `BytesMapBitmap` instances for `GroundOverlay`
- Deterministic image readiness: declare `imageDependencies` and the renderer decodes them before capture - no delays, no blank markers
- Separate render options from map bitmap options for cleaner sizing control
- Collision-safe structured cache keys with `MarkerCacheKey`
- LRU cache keyed by cache key, size, and pixel ratio, with entry limits, byte limits, and in-flight deduplication
- Stable descriptor identity, so unchanged markers never resend icon bytes to the map
- FIFO-bounded render concurrency and a per-render raster pixel budget

## Installation

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_maps_flutter: ^2.17.1
  marker_widget: ^3.0.0
```

Then run:

```bash
flutter pub get
```

Requires Dart `^3.12.0` and Flutter `>=3.44.0`.

## Quick start

### Build a classic marker directly

```dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_widget/marker_widget.dart';

final marker = await MyMarkerCard().toMarker(
  context: context,
  base: const Marker(
    markerId: MarkerId('coffee-shop'),
    position: LatLng(37.4279, -122.0857),
    infoWindow: InfoWindow(title: 'Coffee shop'),
    zIndexInt: 1,
  ),
  renderOptions: MarkerRenderOptions(
    logicalSize: const Size(96, 96),
    cacheKey: MarkerCacheKey(
      'coffee-shop',
      brightness: Theme.of(context).brightness,
      locale: Localizations.maybeLocaleOf(context),
    ),
  ),
);
```

### Build an advanced pin with a widget glyph

`marker_widget` re-exports the advanced marker types and the common marker
construction types (`Marker`, `MarkerId`, `LatLng`, `BitmapDescriptor`, ...),
so the whole marker flow works from a single import. They are the same
declarations `google_maps_flutter` exports (2.17+ also re-exports the advanced
types), so both imports can coexist.

```dart
final advancedMarker = await MyAvatarBadge().toAdvancedPinMarker(
  context: context,
  base: AdvancedMarker(
    markerId: const MarkerId('driver'),
    position: const LatLng(37.4279, -122.0857),
    collisionBehavior: MarkerCollisionBehavior.requiredAndHidesOptional,
  ),
  backgroundColor: Colors.white,
  borderColor: Colors.indigo,
  renderOptions: const MarkerRenderOptions(
    logicalSize: Size(28, 28),
  ),
  bitmapOptions: const MapBitmapOptions(width: 28, height: 28),
);
```

Advanced markers also need:

- `GoogleMap.markerType: GoogleMapMarkerType.advancedMarker`
- `GoogleMap.mapId`
- `&libraries=marker` in `web/index.html` on web

### Create a ground overlay from a widget

```dart
final overlayBitmap = await MyOverlayCard().toGroundOverlayBitmap(
  context: context,
  renderOptions: const MarkerRenderOptions(
    logicalSize: Size(180, 120),
  ),
);

final overlay = GroundOverlay.fromBounds(
  groundOverlayId: const GroundOverlayId('coverage'),
  image: overlayBitmap,
  bounds: LatLngBounds(
    southwest: const LatLng(37.4268, -122.0867),
    northeast: const LatLng(37.4290, -122.0848),
  ),
);
```

## The v3 model

Marker creation is split into two layers:

- `MarkerRenderOptions` controls how the widget is rendered off-screen
- `MapBitmapOptions` controls how the rendered bytes are interpreted on the map

That means render size and display size are never mixed together. Marker builder
APIs take real upstream `Marker` and `AdvancedMarker` objects as the build input,
so `marker_widget` stays focused on rasterization instead of mirroring Google
Maps constructors.

### Widget render options

```dart
final renderOptions = MarkerRenderOptions(
  logicalSize: const Size(96, 96),
  pixelRatio: 3.0,
  cacheKey: const MarkerCacheKey('user-42', brightness: Brightness.light),
  imageDependencies: [NetworkImage(user.avatarUrl)],
);
```

### Map bitmap options

```dart
const defaultSized = MapBitmapOptions();
const explicitWidth = MapBitmapOptions(width: 48);
const explicitPixelRatio = MapBitmapOptions(imagePixelRatio: 3.0);
const pixelPerfect = MapBitmapOptions.pixelPerfect();
const rawBitmap = MapBitmapOptions(bitmapScaling: MapBitmapScaling.none);
```

Behavior rules:

- If `width`, `height`, and `imagePixelRatio` are omitted, `marker_widget` uses the rendered `logicalSize`
- If `bitmapScaling` is `MapBitmapScaling.none`, `width`, `height`, and `imagePixelRatio` must stay null
- `toGroundOverlayBitmap()` is a discoverability alias for the raw `MapBitmapScaling.none` path

## Images inside markers: declare them

The renderer captures one deterministic frame. Network, file, asset, and memory
images decode asynchronously, so a widget that displays them would capture blank
unless the renderer waits for the decode. Declare every `ImageProvider` the
widget displays and the renderer guarantees they are decoded before capture:

```dart
final avatar = NetworkImage(user.avatarUrl);

final marker = await DriverBadge(avatar: avatar).toMarker(
  context: context,
  base: Marker(markerId: MarkerId(user.id), position: user.position),
  renderOptions: MarkerRenderOptions(
    logicalSize: const Size(56, 56),
    cacheKey: MarkerCacheKey(user.id, extra: user.status),
    imageDependencies: [avatar],
  ),
);
```

The contract:

- Each declared provider is resolved against the render environment (pixel
  ratio, locale, text direction, asset bundle) and awaited to full decode
  before the widget tree is built.
- The decoded images are kept alive until the capture completes, so they
  cannot be evicted mid-render.
- Use the same provider instances (or providers with equal cache keys) as the
  widget itself displays.
- A provider that fails to load throws `MarkerImageLoadException` instead of
  capturing a marker with a hole in it. Catch it to fall back to a placeholder
  icon.

Fonts loaded at runtime (for example `google_fonts` or `FontLoader`) are global
once loaded: `await` the font load before rendering and the text paints
correctly; no declaration is needed.

## Render once, reuse everywhere

```dart
class MarkerAssets {
  static late final MarkerIcon restaurant;

  static Future<void> preload(BuildContext context) async {
    restaurant = await RestaurantPin().toMarkerIcon(
      context: context,
      renderOptions: const MarkerRenderOptions(
        logicalSize: Size(64, 64),
      ),
    );
  }
}

final marker = MarkerAssets.restaurant.toMarker(
  base: const Marker(
    markerId: MarkerId('restaurant'),
    position: LatLng(37.4279, -122.0857),
  ),
);
```

This pattern gives you:

- one async render up front
- synchronous marker creation later
- consistent reuse across multiple maps

## API overview

Main widget extensions:

```dart
Future<BitmapDescriptor> toBitmapDescriptor({BuildContext? context, ... })
Future<BytesMapBitmap> toMapBitmap({BuildContext? context, ... })
Future<BytesMapBitmap> toGroundOverlayBitmap({BuildContext? context, ... })
Future<BitmapGlyph> toBitmapGlyph({BuildContext? context, ... })
Future<PinConfig> toPinConfig({BuildContext? context, ... })
Future<MarkerIcon> toMarkerIcon({BuildContext? context, ... })
Future<Marker> toMarker({required Marker base, BuildContext? context, ... })
Future<AdvancedMarker> toAdvancedMarker({
  required AdvancedMarker base,
  BuildContext? context,
  ...
})
Future<AdvancedMarker> toAdvancedPinMarker({
  required AdvancedMarker base,
  BuildContext? context,
  ...
})
```

You can omit `context` when you do not need to inherit theme, directionality,
localizations, or the current asset bundle.

`MarkerIcon` exposes the same bitmap, glyph, and builder methods synchronously after rendering. Its bytes are defensively copied and unmodifiable, so an icon can never change after construction.

## What can be rendered

The output is a static PNG snapshot of one widget, rendered once in a
detached tree. Self-contained visual widgets (containers, text, icons,
decorations, images declared as dependencies) render reliably. Not supported
as marker content:

- platform views and texture-backed widgets (maps, video players, web views)
- widgets that only settle in later frames or post-frame callbacks
- live animation (the snapshot freezes the first frame)
- widgets that require ancestors such as a `Navigator`, `Overlay`,
  `Scaffold`, or a state-management scope; wrap the marker widget in what it
  needs before rendering

Passing `context` captures inherited themes, `MediaQuery` accessibility
values (text scaling, brightness, bold text), `Directionality`,
`Localizations`, and the asset bundle. It does not capture arbitrary
`InheritedWidget`s such as provider scopes. Screen geometry (notch padding,
keyboard insets, display features) is deliberately zeroed out, so a
`SafeArea` inside a marker renders edge to edge.

Interactivity flattens: buttons and gestures inside the widget do nothing on
the map. Marker taps and drags come from the `Marker` / `AdvancedMarker` you
build, and when the widget's state changes you rerender and swap the icon.

Images are covered by `imageDependencies` (see above); anything else
asynchronous inside the widget is captured in whatever state it reached in
the single frame.

## Caching

The convenience extensions use `MarkerIconRenderer.shared`, which is exposed so
you can inspect, clear, or prewarm the cache:

```dart
// Clear on logout or theme change
MarkerIconRenderer.shared.clearCache();

// Inspect
print(MarkerIconRenderer.shared.cacheSize);
print(MarkerIconRenderer.shared.cacheSizeInBytes);
```

`MarkerIconRenderer` supports:

- `maxCacheEntries`
- `maxCacheBytes`
- in-flight render deduplication
- invalidation-safe cache clearing while renders are still in flight
- explicit cache inspection via `cacheSize`, `cacheSizeInBytes`, `isCached`, and `peekCache`

Cache entries are identified by `cacheKey` combined with the resolved logical
size and pixel ratio, so one key can never return an icon rendered at another
size. Everything else that changes the rendered pixels belongs in the key
itself; `MarkerCacheKey` structures the common inputs:

```dart
final key = MarkerCacheKey(
  user.id,
  brightness: Theme.of(context).brightness,
  locale: Localizations.maybeLocaleOf(context),
  extra: (selected: isSelected, badge: badgeCount),
);
```

`extra` is compared with `==`, so use values with structural equality; records
work well. For cluster badges, `MarkerCacheKey.cluster(count: 27, ...)` builds
count-aware keys that never collide with plain keys. Any custom object with
value semantics also works as a `cacheKey`; `MarkerCacheKey` is a convenience,
not a requirement.

`maxCacheBytes` counts the encoded PNG bytes held by the cache, not the
decoded bitmap memory the platform map allocates. Icons larger than the limit
are returned to the caller but not cached.

Repeated `toMapBitmap()` / `toBitmapDescriptor()` calls on the same
`MarkerIcon` return the identical descriptor instance. Google Maps compares
icons by identity, so rebuilt markers stay equal to their previous versions
and the map skips redundant platform-side icon updates. Cache hits therefore
avoid both re-rendering and marker churn.

### Render limits

`MarkerIconRenderer` bounds resource usage during batch rendering:

- `maxConcurrentRenders` (default 3): additional renders wait in FIFO order,
  capping how many detached render trees and uncompressed images exist at the
  same time (relevant when prewarming many markers at once). Set to null to
  disable the gate. Image-dependency decoding happens before a slot is taken,
  so slow networks never starve the gate.
- `maxRasterPixels` (default 4194304, a 2048 x 2048 physical bitmap): a
  render whose `width x height x pixelRatio^2` exceeds the budget throws
  `ArgumentError` instead of allocating an enormous bitmap. Set to null to
  disable the check.

## Important notes

- Call this package on the UI isolate only
- `PinConfig` currently has an upstream iOS caveat where the marker may fail to render: https://issuetracker.google.com/issues/370536110
- Web advanced markers require the Google Maps JavaScript `marker` library
- The package only renders widgets and builds marker objects; you still need normal Google Maps API key and manifest setup
- In multi-view scenarios (desktop window embedding), pass `context` so the renderer resolves the `FlutterView` the marker belongs to
- The marker types come from `google_maps_flutter_platform_interface`, the same declarations `google_maps_flutter` re-exports; depending on both is intentional and conflict-free

## Example

See [`example/lib/main.dart`](example/lib/main.dart) for a runnable demo that includes:

- classic marker creation through `Widget.toMarker()` with a declared image dependency
- advanced marker pin creation through `Widget.toAdvancedPinMarker()`
- ground overlay creation through `Widget.toGroundOverlayBitmap()`

## License

See [`LICENSE`](LICENSE).
