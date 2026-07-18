# Marker Widget

Render Flutter widgets into Google Maps bitmaps, glyphs, markers, and ground overlays.

`marker_widget` handles off-screen widget rendering, caching, and bitmap conversion so you can focus on map UI instead of `RenderView` plumbing.

## AI coding-assistant support (agent plugin)

Package-specific support for **Claude Code** and **OpenAI Codex** ships from this
repository as an installable agent plugin: four skills (correct integration and
sizing, cache/performance tuning, symptom-based troubleshooting, and a guided
v1-to-v2 migration) plus a read-only reviewer agent for Claude Code. This is tooling
for coding agents, not a runtime feature of the Dart package, and it is not part of
the pub.dev archive.

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
- "Migrate this app from marker_widget 1.1.0 to 2.0.0."
- Explicit invocation: `/marker-widget:troubleshooting-marker-widget` in Claude Code,
  or `$troubleshooting-marker-widget` in Codex.

The plugin contains instructions and reference documents only: no hooks, no MCP
servers, no executable scripts, no network access; the reviewer agent is restricted
to read-only tools. Compatibility: marker_widget 2.x (migration skill covers 1.x to
2.x); verified with Claude Code 2.1.x and codex-cli 0.144.x. Update with
`claude plugin update marker-widget` / `codex plugin marketplace upgrade
marker-widget`; uninstall with `claude plugin uninstall marker-widget` /
`codex plugin remove marker-widget@marker-widget`.

Full documentation (all capabilities, example prompts, Codex reviewer-subagent
recipe, maintainer guide): [`plugins/marker-widget/README.md`](plugins/marker-widget/README.md).

## Features

- Render any widget to `BitmapDescriptor`, `BytesMapBitmap`, or cacheable `MarkerIcon`
- Build classic `Marker` and `AdvancedMarker` objects directly
- Create `BitmapGlyph` and `PinConfig` from widgets for advanced marker pins
- Create raw `BytesMapBitmap` instances for `GroundOverlay`
- Separate render options from map bitmap options for cleaner sizing control
- LRU cache with entry limits, byte limits, and in-flight deduplication

## Installation

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_maps_flutter: ^2.15.0
  marker_widget: ^2.0.0
```

Then run:

```bash
flutter pub get
```

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
  renderOptions: WidgetBitmapRenderOptions(
    logicalSize: const Size(96, 96),
    cacheKey: buildMarkerCacheKey(
      id: 'coffee-shop',
      logicalSize: const Size(96, 96),
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      brightness: Theme.of(context).brightness,
      locale: Localizations.maybeLocaleOf(context),
    ),
  ),
);
```

### Build an advanced pin with a widget glyph

`google_maps_flutter` does not re-export the advanced marker types yet. `marker_widget` re-exports the missing types for convenience.

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
  renderOptions: const WidgetBitmapRenderOptions(
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
  renderOptions: const WidgetBitmapRenderOptions(
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

## The v2 model

v2 splits marker creation into two layers:

- `WidgetBitmapRenderOptions` controls how the widget is rendered off-screen
- `MapBitmapOptions` controls how the rendered bytes are interpreted on the map

That means render size and display size are no longer mixed together.

v2 also uses real upstream `Marker` and `AdvancedMarker` objects as the build
input, so `marker_widget` stays focused on rasterization instead of mirroring
Google Maps constructors.

### Widget render options

```dart
const renderOptions = WidgetBitmapRenderOptions(
  logicalSize: Size(96, 96),
  pixelRatio: 3.0,
  waitForImages: true,
  cacheKey: 'user:42:light:96x96',
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

## Render once, reuse everywhere

```dart
class MarkerAssets {
  static late final MarkerIcon restaurant;

  static Future<void> preload(BuildContext context) async {
    restaurant = await RestaurantPin().toMarkerIcon(
      context: context,
      renderOptions: const WidgetBitmapRenderOptions(
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

`MarkerIcon` exposes the same bitmap, glyph, and builder methods synchronously after rendering.

## Caching

The convenience extensions use `defaultMarkerIconRenderer`, which is exposed so
you can inspect, clear, or prewarm the cache:

```dart
// Clear on logout or theme change
defaultMarkerIconRenderer.clearCache();

// Inspect
print(defaultMarkerIconRenderer.cacheSize);
print(defaultMarkerIconRenderer.cacheSizeInBytes);
```

`MarkerIconRenderer` supports:

- `maxCacheEntries`
- `maxCacheBytes`
- in-flight render deduplication
- invalidation-safe cache clearing while renders are still in flight
- explicit cache inspection via `cacheSize`, `cacheSizeInBytes`, `isCached`, and `peekCache`

For cluster badges, `buildClusterCacheKey()` gives you a count-aware cache key helper:

```dart
final key = buildClusterCacheKey(
  count: 27,
  logicalSize: const Size(48, 48),
  pixelRatio: MediaQuery.devicePixelRatioOf(context),
  brightness: Theme.of(context).brightness,
  locale: Localizations.maybeLocaleOf(context),
);
```

## Important notes

- Call this package on the UI isolate only
- `PinConfig` currently has an upstream iOS caveat where the marker may fail to render: https://issuetracker.google.com/issues/370536110
- Web advanced markers require the Google Maps JavaScript `marker` library
- The package only renders widgets and builds marker objects; you still need normal Google Maps API key and manifest setup

## Example

See [`example/lib/main.dart`](example/lib/main.dart) for a runnable demo that includes:

- classic marker creation through `Widget.toMarker()`
- advanced marker pin creation through `Widget.toAdvancedPinMarker()`
- ground overlay creation through `Widget.toGroundOverlayBitmap()`

## License

See [`LICENSE`](LICENSE).
