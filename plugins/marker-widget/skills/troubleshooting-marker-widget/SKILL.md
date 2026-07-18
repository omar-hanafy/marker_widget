---
name: troubleshooting-marker-widget
description: Use when marker_widget output is wrong or failing - blank or transparent marker bitmaps, network images missing inside markers, markers sized wrong or blurry, stale icons that ignore theme or state changes, advanced markers or PinConfig pins not appearing, StateError or ArgumentError from MapBitmapOptions or rendering, "No FlutterView is available", or widget tests that hang or time out on marker rendering.
---

# Troubleshooting marker_widget

Diagnose by symptom, confirm the cause in code, apply the smallest fix, then verify on
a device. Do not tweak options at random: every symptom below has a small set of real
causes.

Audience: developers with a failing or wrong marker_widget integration. Inputs: the
exact symptom (screenshot or error text) and the render call site. If the report is a
compile error after upgrading from 1.x, switch to
marker-widget:migrating-marker-widget-v1-to-v2.

## Diagnosis workflow

1. Reproduce and capture: exact error text, or what the marker looks like vs expected.
2. Locate the render call and read its `renderOptions`/`bitmapOptions`/`context`
   arguments.
3. Match the symptom table below; confirm the cause before editing.
4. Fix minimally, `dart analyze`, re-run on the affected platform, and confirm at
   multiple zoom levels / theme states as relevant.

## Exceptions (exact messages)

| Message contains | Cause | Fix |
|---|---|---|
| `MapBitmapScaling.none cannot be combined with width, height, or imagePixelRatio` | Raw scaling plus size metadata (includes `pixelPerfect()` with `none`) | Drop the size fields, or use `MapBitmapScaling.auto`; for ground overlays call `toGroundOverlayBitmap()` |
| `MapBitmapOptions.width must be > 0` (also height / imagePixelRatio variants) | Zero or negative option value, often from a computed size | Guard the computation; sizes must be positive |
| `logicalSize.width and logicalSize.height must both be > 0` | `WidgetBitmapRenderOptions(logicalSize: ...)` computed as zero (e.g. from an unlaid-out box) | Pass an explicit positive design size, not a measured one |
| `pixelRatio must be > 0 when provided` | Bad explicit pixelRatio | Remove it (defaults to view DPR) |
| `MarkerIcon.bytes must not be empty` | Hand-built `MarkerIcon` with empty bytes (renderer never produces this) | Fix the construction site |
| `MarkerIcon.logicalSize must be > 0 in both dimensions` | Hand-built `MarkerIcon` with degenerate size converted with default options | Store the real rendered size |
| `No FlutterView is available` | Render before `WidgetsFlutterBinding.ensureInitialized()`, or in a background isolate / headless context | Render on the UI isolate after binding init; never inside `compute`/`Isolate.run` |
| `Failed to convert widget to marker image bytes` | PNG encode returned null (rare; graphics backend issue) | Retry path/report; check for headless or test environment |

## Visual symptoms

| Symptom | Likely cause | Confirm | Fix |
|---|---|---|---|
| Blank/transparent marker, no error | Widget painted before async content was ready (network/file images, FutureBuilder) | Widget contains `Image.network`/`NetworkImage`/`CachedNetworkImage` | `precacheImage()` before rendering (reliable), or `waitForImages: true` and raise `imageRepaintDelay` for slow sources. The wait is delay-based (default 16ms check + 200ms repaint), not a completion guarantee |
| Marker shows but image area inside is empty | Same as above, image-specific | Same | Same; note `CachedNetworkImage` placeholders render as the placeholder |
| Marker huge or tiny on map | On-map size taken from wrong layer | `bitmapOptions` has explicit `width`/`height`, or `pixelPerfect()` on a high-DPR device | Default `MapBitmapOptions()` displays at `logicalSize`; remove conflicting metadata |
| Marker blurry/pixelated | Rendered at DPR 1 then upscaled | Explicit `pixelRatio: 1.0`, or bytes reused across DPRs via persisted cache | Let `pixelRatio` default to the view DPR; include DPR in cache keys |
| Marker crisp but size differs per device | `pixelPerfect()`/`imagePixelRatio` path in use | See `bitmapOptions` | That is the documented tradeoff; use default options for device-independent size |
| Icon ignores dark mode / locale / selection | Cache key missing that input | Key lacks `brightness`/`locale`/`extra` | Add the input to `buildMarkerCacheKey`; see marker-widget:optimizing-marker-widget |
| Marker uses wrong theme/direction/language | `context:` omitted at render | Call has no `context` argument | Pass `context:` from the app tree |
| Widget layout differs from the same widget on screen | Render tree MediaQuery differs: `MediaQuery.size` is the marker's `logicalSize` | Widget reads `MediaQuery.of(context).size` | Size the widget from its own constraints, not MediaQuery |
| Asset image/font missing in marker (contextless call) | No `DefaultAssetBundle`/theme inheritance without `context` | Call has no `context` | Pass `context:` |

## Advanced markers and pins

| Symptom | Cause | Fix |
|---|---|---|
| AdvancedMarker never appears (any platform) | `GoogleMap.markerType` not `advancedMarker`, or no `mapId` | Set both on the `GoogleMap` widget |
| AdvancedMarker fine on Android, absent on web | Maps JS loaded without marker library | Add `&libraries=marker` to the script URL in `web/index.html` |
| Pin appears without the widget glyph, or not at all, on iOS | Upstream `PinConfig` iOS bug (issuetracker.google.com/issues/370536110) | Use `toAdvancedMarker` (full widget icon) on iOS, or accept and track upstream |
| `AdvancedMarker`/`PinConfig` types unresolved | Importing only google_maps_flutter | Import them from `package:marker_widget/marker_widget.dart` (curated re-exports) |

## Tests

| Symptom | Cause | Fix |
|---|---|---|
| `testWidgets` hangs/times out on any `to*` call | flutter_test fake async never completes `toImage`/PNG encode | Wrap the render: `await tester.runAsync(() => widget.toMarkerIcon(...))`; pump a widget first for a context (the package's own test suite is the reference) |
| Renders fine in `flutter run`, fails in CI | No implicit view / binding differences in headless env | Ensure `TestWidgetsFlutterBinding.ensureInitialized()`; keep renders inside `runAsync` |

## When it is not marker_widget

Map does not load at all, all markers (including stock red pins) missing, or platform
exceptions from the maps SDK: that is google_maps_flutter setup (API key, manifest,
minSdk). Verify a stock `Marker` with the default icon appears before debugging
widget rendering.

## Failure handling

If no row matches: read the actual installed source (single file,
`lib/src/marker_widget.dart` under the package root from
`.dart_tool/package_config.json`), reproduce in a minimal 20-line snippet, and compare
against the package example `example/lib/main.dart`. Report what was ruled out. Never
"fix" by deleting cache keys, disabling caching, or swallowing exceptions.

## Example scenario

"Driver avatars are blank white circles in release builds but fine in debug":
avatars are `NetworkImage`s; debug is slow enough that images happen to load. Confirm
via symptom row 1, fix with `await precacheImage(NetworkImage(url), context)` before
`toMarker(...)`, keep `waitForImages: false`, verify on a throttled network.

API defaults and the full error-string table: ../../references/api-quick-reference.md.
