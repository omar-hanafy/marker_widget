# Marker Widget

Render any Flutter widget into a `BitmapDescriptor` for `google_maps_flutter` markers — with correct sizing, pixel‑ratio handling, caching, and support for the modern `ViewConfiguration` / `FlutterView` APIs.

[![Pub Version](https://img.shields.io/pub/v/marker_widget.svg)](https://pub.dev/packages/marker_widget)

> **Use widgets as map markers** without fighting with `RepaintBoundary`, `RenderView`, or pixel ratios yourself.

---

## Features

- 🧱 **Widget → Marker**: Turn any widget into a `BitmapDescriptor` for `google_maps_flutter`.
- 📏 **Two scaling modes**:
  - `logicalSize` — stable logical size across devices.
  - `imagePixelRatio` — pixel‑perfect at the device DPR.
- 🧠 **Context‑aware rendering**:
  - Respects `MediaQuery`, `Directionality`, and `Theme` from your app.
- ⚡ **Smart LRU cache**:
  - Count-based and **memory-based** eviction.
  - **Concurrent request deduplication** — multiple calls with the same key share one render.
- 🖼️ **"Wait for images" mode**:
  - Optional second pass when we detect `RenderImage` / `BoxDecoration.image`.
- 🧹 **Impeller‑friendly**:
  - Disposes the intermediate `ui.Image` to avoid GPU leaks.
- ✅ **Modern Flutter API**:
  - Uses the new `ViewConfiguration` constructor and `View.maybeOf`.
  - Targets Flutter 3.29+ and `google_maps_flutter` 2.14+.

Works wherever `google_maps_flutter` works: **Android, iOS, Web**.

---

## Installation

In your app's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  google_maps_flutter: ^2.14.0
  marker_widget: ^1.0.0
```

Then:

```bash
flutter pub get
```

---

## Quick start

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_widget/marker_widget.dart';

class MapWithWidgetMarker extends StatefulWidget {
  const MapWithWidgetMarker({super.key});

  @override
  State<MapWithWidgetMarker> createState() => _MapWithWidgetMarkerState();
}

class _MapWithWidgetMarkerState extends State<MapWithWidgetMarker> {
  static const LatLng _position = LatLng(37.42796133580664, -122.085749655962);

  BitmapDescriptor? _markerIcon;
  Set<Marker> _markers = <Marker>{};
  bool _isLoadingIcon = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_markerIcon == null && !_isLoadingIcon) {
      _loadMarkerIcon();
    }
  }

  Future<void> _loadMarkerIcon() async {
    _isLoadingIcon = true;

    try {
      const logicalSize = Size(80, 80);
      final dpr = MediaQuery.devicePixelRatioOf(context);

      final icon = await _UserMarkerCard(
        label: 'You',
        color: Colors.indigo,
      ).toMarkerBitmap(
        context,
        logicalSize: logicalSize,
        waitForImages: true,
        cacheKey: buildMarkerCacheKey(
          id: 'user-marker',
          logicalSize: logicalSize,
          pixelRatio: dpr,
          brightness: Theme.of(context).brightness,
          locale: Localizations.maybeLocaleOf(context),
        ),
      );

      if (!mounted) return;

      setState(() {
        _markerIcon = icon;
        _markers = {
          Marker(
            markerId: const MarkerId('user-marker'),
            position: _position,
            icon: icon,
            infoWindow: const InfoWindow(title: 'Custom widget marker'),
          ),
        };
      });
    } catch (e) {
      debugPrint('Failed to build marker icon: $e');
    } finally {
      _isLoadingIcon = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('marker_widget example')),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _position,
          zoom: 13,
        ),
        markers: _markers,
        myLocationButtonEnabled: false,
      ),
    );
  }
}

class _UserMarkerCard extends StatelessWidget {
  const _UserMarkerCard({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(8),
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_pin_circle, color: Colors.white, size: 32),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Render Once, Reuse Everywhere

For **static markers** (like a picker pin or category icon) that don't change based on data, you can render once at app startup and reuse synchronously across all maps:

```dart
/// Store your pre-rendered markers globally or in your DI container
class MarkerAssets {
  static late final MarkerIcon pickerIcon;
  static late final MarkerIcon restaurantIcon;
  static late final MarkerIcon gasStationIcon;

  /// Call once during app initialization
  static Future<void> preload(BuildContext context) async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const size = Size(56, 56);

    // Render all static markers in parallel
    final results = await Future.wait([
      const PickerPinWidget().toMarkerIcon(
        context,
        logicalSize: size,
      ),
      const RestaurantMarkerWidget().toMarkerIcon(
        context,
        logicalSize: size,
      ),
      const GasStationMarkerWidget().toMarkerIcon(
        context,
        logicalSize: size,
      ),
    ]);

    pickerIcon = results[0];
    restaurantIcon = results[1];
    gasStationIcon = results[2];
  }
}

// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Builder(
        builder: (context) {
          // Preload after first frame when context is available
          WidgetsBinding.instance.addPostFrameCallback((_) {
            MarkerAssets.preload(context);
          });
          return const MyApp();
        },
      ),
    ),
  );
}

// Later, anywhere in your app — fully synchronous!
Marker(
  markerId: const MarkerId('restaurant_123'),
  position: restaurantLatLng,
  icon: MarkerAssets.restaurantIcon.toBitmapDescriptor(), // ✅ No async!
)
```

### Why This Pattern?

- **Zero async tax** after initial load — `toBitmapDescriptor()` is synchronous
- **Consistent across all maps** — same `MarkerIcon` instance everywhere
- **Works with any state management** — Provider, Riverpod, GetIt, or plain statics
- **Memory efficient** — one bitmap per marker type, not per marker instance

### Direct `BytesMapBitmap` Access

If you need the concrete google_maps_flutter type (for typed collections or interop):

```dart
// Extension method
final bitmap = await MyWidget().toMapBitmap(context, logicalSize: size);

// Or standalone function
final bitmap = await widgetToMapBitmap(MyWidget(), logicalSize: size);

// Or from a MarkerIcon
final bitmap = markerIcon.toMapBitmap();
```

---

## API overview

### `WidgetMarkerExtension`

Available on every `Widget`:

```dart
// Returns BitmapDescriptor (abstract type)
Future<BitmapDescriptor> toMarkerBitmap(BuildContext context, { ... });

// Returns BytesMapBitmap (concrete type)
Future<BytesMapBitmap> toMapBitmap(BuildContext context, { ... });

// Returns MarkerIcon (for storage and later conversion)
Future<MarkerIcon> toMarkerIcon(BuildContext context, { ... });
```

Common options:

* **`logicalSize`** – desired size on the map in logical pixels.
* **`pixelRatio`** – override device pixel ratio (defaults to `view.devicePixelRatio`).
* **`waitForImages`** – do a cheap second pass when image render objects are detected.
* **`cacheKey`** – any object/string that encodes everything affecting visuals.

### Standalone Functions

Same as the extensions, but without a `BuildContext`:

```dart
// Returns BitmapDescriptor
final descriptor = await widgetToMarkerBitmap(MyWidget(), logicalSize: size);

// Returns BytesMapBitmap
final bitmap = await widgetToMapBitmap(MyWidget(), logicalSize: size);

// Returns MarkerIcon
final icon = await widgetToMarkerIcon(MyWidget(), logicalSize: size);
```

Useful for code that lives outside the widget tree but still runs on the UI isolate.

### `MarkerIconRenderer`

The workhorse that does the off‑screen rendering:

* Configurable:
  * `defaultLogicalSize`
  * `enableCaching`
  * `maxCacheEntries` — count-based LRU limit
  * `maxCacheBytes` — memory-based limit (default: 50MB)
  * `initialImageDelay` / `imageRepaintDelay`

* Methods:
  * `Future<MarkerIcon> render(Widget widget, { ... })`
  * `clearCache()`
  * `removeFromCache(Object key)`
  * `isCached(Object key)` — check if a key exists
  * `peekCache(Object key)` — get without LRU bump

* Properties:
  * `cacheSize` — current entry count
  * `cacheSizeInBytes` — current memory usage

You can pass your own `MarkerIconRenderer` everywhere to customize caching and timing.

### `MarkerIcon` & `MarkerIconScalingMode`

* `MarkerIcon` is a small **immutable** value object with:
  * `bytes` (PNG),
  * `logicalSize`,
  * `pixelRatio`,
  * `sizeInBytes` — for memory tracking
  * `toBitmapDescriptor(...)` — returns `BitmapDescriptor`
  * `toMapBitmap(...)` — returns `BytesMapBitmap`

* `MarkerIconScalingMode` tells the conversion how to interpret the data:
  * `logicalSize` (default) – pass `width`/`height` for consistent sizes.
  * `imagePixelRatio` – pass `imagePixelRatio` for pixel-perfect rendering.

### `buildMarkerCacheKey`

Helper to build a cache key that "does the right thing" for typical use cases:

```dart
final key = buildMarkerCacheKey(
  id: user.id,
  logicalSize: const Size(80, 80),
  pixelRatio: MediaQuery.devicePixelRatioOf(context),
  brightness: Theme.of(context).brightness,
  locale: Localizations.localeOf(context),
);
```

---

## Performance Tips

### Caching

* **Always include size + DPR** in your cache key.
* Include theme/locale if your marker visuals depend on them.
* Use `MarkerIconRenderer(enableCaching: false)` if you want to fully control caching externally.
* **Concurrent deduplication**: Multiple simultaneous calls with the same `cacheKey` automatically share one render operation.

### Memory Management

The default renderer limits cache to **50MB** (`maxCacheBytes`). Adjust based on your needs:

```dart
final renderer = MarkerIconRenderer(
  maxCacheEntries: 100,      // Max 100 unique markers
  maxCacheBytes: 20 * 1024 * 1024,  // Max 20MB
);
```

### Static vs Dynamic Markers

| Marker Type | Strategy |
|-------------|----------|
| **Static** (picker pin, category icons) | Render once at startup, store `MarkerIcon`, reuse everywhere |
| **Semi-dynamic** (price labels, user avatars) | Use cache keys that capture all visual variants |
| **Fully dynamic** (real-time updates) | Minimize size, consider simpler widgets |

---

## Image loading tips

If your marker includes `Image.network`, `FadeInImage`, or a `BoxDecoration.image`, pass `waitForImages: true`. The renderer will:

1. Build the tree once.
2. Pause briefly to let images start loading.
3. If it finds any image render objects, it waits a bit more and repaints.

This is a best‑effort optimization; it won't wait for *all* images in pathological cases, but it's usually enough for markers.

---

## Limitations

* Must be called on the **UI isolate** (no background isolates).
* This package only builds marker bitmaps; you still need to configure
  `google_maps_flutter` for Android, iOS, and Web (API key, manifests, etc.).
* The example app assumes you've already wired up your Google Maps API keys.
* **Web**: Requires CanvasKit renderer (default in Flutter 3.24+).

---

## Example app

A complete example is in [`example/lib/main.dart`](example/lib/main.dart) and shows:

* Custom widget markers with theme/locale‑aware caching.
* `waitForImages` usage.
* Switching between scaling modes.

---

## Contributing

Issues and pull requests are welcome at the GitHub repository:

* Repository: [https://github.com/omar-hanafy/marker_widget](https://github.com/omar-hanafy/marker_widget)
* Issues: [https://github.com/omar-hanafy/marker_widget/issues](https://github.com/omar-hanafy/marker_widget/issues)

---

## License

See the `LICENSE` file in this repository.
