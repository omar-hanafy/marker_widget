---
name: using-marker-widget
description: Use when adding widget-rendered markers, advanced marker pins, or ground overlays to Google Maps in a Flutter app with the marker_widget package - choosing among toMarker, toAdvancedMarker, toAdvancedPinMarker, toBitmapDescriptor, toMarkerIcon, and toGroundOverlayBitmap, sizing output with MarkerRenderOptions and MapBitmapOptions, declaring imageDependencies, or wiring advanced markers (mapId, markerType, web marker library).
---

# Using marker_widget

marker_widget renders any Flutter widget off-screen into PNG bytes and wraps them as
google_maps_flutter bitmap/marker types. Core principle: two separate option layers.
`MarkerRenderOptions` controls how the widget is rasterized (render size, DPR, image
dependencies); `MapBitmapOptions` controls how the map displays the bytes (on-map
size). Never try to control on-map size with render options or vice versa.

Audience: developers integrating marker_widget into an app. Inputs you need: the
consumer project, what should appear on the map (classic marker, advanced pin, ground
overlay), and where icons vary (per-user, per-theme, per-locale).

Not for: general google_maps_flutter setup (API keys, manifests), upgrading from
marker_widget 1.x or 2.x (use marker-widget:migrating-marker-widget-v1-to-v2 or
marker-widget:migrating-marker-widget-v2-to-v3), or diagnosing broken output (use
marker-widget:troubleshooting-marker-widget).

## Step 1: Inspect before writing code

1. `pubspec.yaml` / lockfile: confirm `marker_widget` 3.x and `google_maps_flutter`
   >= 2.17.1. If the project is on marker_widget 1.x or 2.x, STOP and switch to the
   matching migration skill first.
2. Check SDK floors: Dart ^3.12.0, Flutter >= 3.44.0. If the project cannot meet
   them, marker_widget 3.x is not installable; say so instead of forcing constraints.
3. Note target platforms (android/ios/web only; google_maps_flutter has no desktop
   support) and whether the app has dark mode or localization (affects cache keys and
   the `context` decision).
4. Follow the existing state-management pattern for where rendered markers are stored
   (a `Set<Marker>` in state is the google_maps_flutter convention).

## Step 2: Pick the right method

| Goal | Call |
|---|---|
| Classic marker in one step | `widget.toMarker(base: Marker(...))` |
| Advanced marker, widget IS the icon | `widget.toAdvancedMarker(base: AdvancedMarker(...))` |
| Advanced pin (colored pin + widget glyph) | `widget.toAdvancedPinMarker(base: ..., backgroundColor: ..., borderColor: ...)` |
| Ground overlay image | `widget.toGroundOverlayBitmap()` then `GroundOverlay.fromBounds/fromPosition` |
| Icon rendered once, markers built later synchronously | `widget.toMarkerIcon()` -> store `MarkerIcon` -> `icon.toMarker(base: ...)` |
| Just the `BitmapDescriptor` / raw bitmap | `toBitmapDescriptor()` / `toMapBitmap()` |

Decision points:

- Many markers sharing one static icon: render ONE `MarkerIcon`, reuse it per marker.
  Do not call `toMarker` per item.
- `toMarker` accepts classic `Marker` bases only; an `AdvancedMarker` base throws
  `ArgumentError`. Route advanced markers through `toAdvancedMarker`/
  `toAdvancedPinMarker`.
- iOS in scope and considering `toAdvancedPinMarker`/`toPinConfig`: upstream iOS bug
  can make PinConfig pins fail to render (issuetracker.google.com/issues/370536110).
  Prefer `toAdvancedMarker` with a full widget icon, or flag the risk.
- Advanced markers at all? They need a cloud `mapId`; without one, use classic markers.

## Step 3: Size it

- Set `renderOptions: MarkerRenderOptions(logicalSize: Size(w, h))` to the size
  the widget is designed for. Leave `pixelRatio` unset (defaults to device DPR).
- Default `MapBitmapOptions()` shows the marker at exactly `logicalSize` logical px on
  the map, consistent across devices. This is right for almost everyone.
- `MapBitmapOptions.pixelPerfect()` sizes by physical pixels instead (marker size then
  varies across devices) - only when pixel-exact fidelity beats size consistency.
- `MapBitmapScaling.none` (or `toGroundOverlayBitmap()`): raw bytes, no metadata. Never
  combine with `width`/`height`/`imagePixelRatio`/`pixelPerfect` - that throws
  `StateError` at runtime.

## Step 4: Declare images, context, and caching

- Any image the widget displays (`Image`, `DecorationImage`,
  `CircleAvatar.backgroundImage`, network/asset/file/memory providers) MUST be
  declared in `renderOptions.imageDependencies` with the same provider instance the
  widget uses. The renderer decodes every declared provider before capture and keeps
  it alive until capture finishes - deterministic, no delays, no blank markers. A
  provider that fails throws `MarkerImageLoadException`; catch it where a placeholder
  fallback is wanted.
- Runtime-loaded fonts (google_fonts, `FontLoader`) need no declaration: `await` the
  font load once before rendering.
- Pass `context:` whenever the widget uses Theme, MediaQuery, Directionality,
  Localizations, DefaultAssetBundle, or context-based state (Provider etc.). Omit only
  for fully self-contained icons. Note: inside the render tree, `MediaQuery.size`
  equals the marker's `logicalSize`, not the screen.
- Rendering is async and must happen on the UI isolate after
  `WidgetsFlutterBinding.ensureInitialized()`; never in `compute`/isolates.
- Any render that can happen more than once needs `cacheKey:
  MarkerCacheKey(id, brightness: ..., locale: ..., extra: <state that changes
  pixels>)`. The renderer adds the resolved size and DPR to the cache identity
  itself. No cacheKey means no caching and no deduplication. `extra` compares with
  `==`, so use records or other value-equal types. Details and tuning:
  marker-widget:optimizing-marker-widget.

## Step 5: Advanced marker wiring (only if used)

All three are required or advanced markers silently do not appear:

1. `GoogleMap(markerType: GoogleMapMarkerType.advancedMarker, ...)`
2. `GoogleMap(mapId: '<cloud map id>')` (from Google Cloud console)
3. Web only: `&libraries=marker` appended to the Maps JS `<script>` URL in
   `web/index.html`.

Import advanced types (`AdvancedMarker`, `PinConfig`, `BitmapGlyph`,
`MarkerCollisionBehavior`, ...) from `package:marker_widget/marker_widget.dart`; do not
add a direct dependency on google_maps_flutter_platform_interface. The classic
construction types (`Marker`, `MarkerId`, `LatLng`, `InfoWindow`,
`BitmapDescriptor`, `GroundOverlay`, ...) are re-exported too, so marker-building code
can use the marker_widget import alone. Keep a classic-marker fallback when `mapId`
may be absent (see `example/lib/main.dart` in the package repo for the gating
pattern).

## Step 6: Verify

1. `dart analyze` the touched code; `dart format` changed files.
2. Run the app on a real device or emulator per target platform; confirm marker
   appears, is crisp, and is the intended size at several zoom levels; toggle dark
   mode/locale if the app supports them and confirm the icon updates.
3. In widget tests, wrap render calls in `await tester.runAsync(() => ...)`; the
   fake-async test environment deadlocks `toImage` otherwise.
4. Report any assumption made (sizes chosen, context omitted, fallback behavior).

Failure handling: if output is blank, mis-sized, stale, or missing, do not iterate
blindly on options; switch to marker-widget:troubleshooting-marker-widget which maps
symptoms to causes.

## Example scenario

"Show each driver as a rounded avatar badge on the map" ->
`DriverBadge(avatar: avatar)` widget where `avatar = NetworkImage(driver.avatarUrl)`;
`toMarker(context: context, base: Marker(markerId: MarkerId(driver.id), position:
driver.latLng), renderOptions: MarkerRenderOptions(logicalSize: const Size(56, 56),
cacheKey: MarkerCacheKey(driver.id, brightness: Theme.of(context).brightness,
extra: driver.status), imageDependencies: [avatar]))`; store results in a
`Set<Marker>`; rebuild only markers whose status changed (cache serves the rest).

Full API tables, defaults, and exact error strings: ../../references/api-quick-reference.md
(relative to this skill directory).
