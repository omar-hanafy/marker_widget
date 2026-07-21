# marker_widget consumer-code review checklist

Audit checklist for code that uses marker_widget. Each item: what to search for, why it
is a problem, and the fix. Severity guide: HIGH = user-visible bug or memory risk,
MEDIUM = performance or correctness under specific conditions, LOW = style/robustness.

Find usage sites first:

```
grep -rn "toBitmapDescriptor\|toMapBitmap\|toMarkerIcon\|toMarker(\|toAdvancedMarker\|toAdvancedPinMarker\|toPinConfig\|toBitmapGlyph\|toGroundOverlayBitmap\|MarkerIconRenderer\|MarkerCacheKey\|imageDependencies" lib/
```

## 1. Renders without a cacheKey on a hot path (HIGH)

Search: extension calls whose `renderOptions` has no `cacheKey`, especially inside
`build()`, `didChangeDependencies()`, `onCameraMove`/`onCameraIdle`, stream/listener
callbacks, or loops over model lists.
Why: no `cacheKey` means no caching AND no in-flight deduplication; every call is a full
off-screen build + rasterize + PNG encode. On camera events this renders every frame.
Fix: add `cacheKey: MarkerCacheKey(...)`, or render once into a `MarkerIcon` held in
state and convert synchronously.

## 2. Cache key missing a visual input or lacking value equality (HIGH)

Search: `cacheKey:` values that are plain ids or string literals; `MarkerCacheKey`
without `brightness`/`locale` in apps that support dark mode or localization;
selection/status rendered in the widget but absent from the key (`extra:`); `extra:`
holding a `List`, `Map`, or custom object without `==`.
Why: the first rendered variant sticks; theme toggles, locale switches, or selection
changes show stale icons. An identity-compared `extra` never equals the previous
build's value, so every render misses the cache (safe but wasteful). The renderer
adds resolved size and DPR to cache identity itself; those never belong in the key.
Fix: include every content input that changes pixels: id, brightness, locale,
`extra` for state (selected, count, avatar revision), using records or other
value-equal types for `extra`.

## 3. Images displayed but not declared as dependencies (HIGH)

Search: `Image.network`, `NetworkImage`, `CachedNetworkImage`, `FadeInImage`,
`DecorationImage`, `CircleAvatar(backgroundImage:` inside widgets passed to any `to*`
method, where the render call's `imageDependencies` does not include the same
provider.
Why: the off-screen tree is captured in one deterministic pass; an undeclared async
image is still decoding at capture time and paints blank. Declared providers are
decoded before capture and retained until it completes, which is the supported path.
Fix: declare the exact provider instances in `renderOptions.imageDependencies`. Check
the failure path too: a dead URL now throws `MarkerImageLoadException`; hot paths
should catch it and fall back to a placeholder icon. Flag any widget relying on
animations, `FutureBuilder`, or post-frame state: the renderer captures a single
frame.

## 4. Context omitted where the widget depends on it (MEDIUM)

Search: `to*` calls without `context:` where the rendered widget uses `Theme.of`,
`Localizations`, `Directionality`, `MediaQuery`, `DefaultAssetBundle`, or inherited
widgets (Provider/Riverpod/Bloc via context).
Why: without `context`, the render tree gets defaults (LTR, no app theme, no app
localizations); inherited-widget lookups may throw or silently use fallbacks.
Fix: pass `context:`. Note `InheritedTheme.captureAll` covers theme-like inherited
state; providers that are not `InheritedTheme`s are captured as regular inherited
widgets from the given context.

## 5. Renders off the UI isolate or before binding init (HIGH)

Search: `compute(`, `Isolate.run`, `Isolate.spawn` wrapping marker rendering; renders in
`main()` before `WidgetsFlutterBinding.ensureInitialized()`; renders in background
services (workmanager, alarm callbacks).
Why: the renderer needs a `FlutterView` and the widgets binding; it throws
`No FlutterView is available` or crashes in isolates.
Fix: render on the UI isolate, after binding init, ideally after the first frame.

## 6. MapBitmapScaling.none combined with sizing (MEDIUM)

Search: `MapBitmapScaling.none` together with `width:`, `height:`, `imagePixelRatio:`,
or `MapBitmapOptions.pixelPerfect`.
Why: throws `StateError` at conversion time.
Fix: raw path takes no metadata. For ground overlays use `toGroundOverlayBitmap()`.

## 7. Advanced markers missing platform prerequisites (HIGH)

Search: `toAdvancedMarker`/`toAdvancedPinMarker`/`AdvancedMarker` usage. Then check:
`GoogleMap(markerType: GoogleMapMarkerType.advancedMarker, mapId: ...)` is set where
those markers are shown; on web, `web/index.html` loads the Maps JS API with
`&libraries=marker`.
Why: without all three, advanced markers silently do not appear.
Fix: add the missing pieces; keep a classic-marker fallback when `mapId` is absent
(see the package example's `GOOGLE_MAPS_ADVANCED_MAP_ID` gating).

## 8. PinConfig on iOS without fallback (MEDIUM)

Search: `toPinConfig`/`toAdvancedPinMarker` in apps shipping iOS.
Why: upstream iOS issue: pins with `PinConfig` may fail to render
(issuetracker.google.com/issues/370536110).
Fix: prefer `toAdvancedMarker` with a full widget icon on iOS, or verify on a real
device and keep a fallback.

## 9. Unbounded or never-cleared cache (MEDIUM)

Search: custom `MarkerIconRenderer(maxCacheBytes: null)` or huge `maxCacheEntries`;
apps with logout/theme switches that never call `clearCache()`;
`MarkerIconRenderer.shared` holding user avatars after logout.
Why: PNG bytes accumulate (default cap is 50 MB; null removes the cap); stale
user-specific icons survive account switches.
Fix: keep byte cap; call `MarkerIconRenderer.shared.clearCache()` on logout and on
theme/locale change when keys do not include those inputs.

## 10. Oversized renders (MEDIUM)

Search: `logicalSize` above ~256 logical px for markers, or `pixelRatio` hardcoded to
3.0+ regardless of device.
Why: memory per icon scales with width * height * dpr^2; large icons also evict the
rest of the cache (single icon > maxCacheBytes is silently never cached).
Fix: render at the display size actually needed; let `pixelRatio` default to the view
DPR.

## 11. Re-render instead of reuse for static icons (LOW)

Search: identical static pins rendered per marker in a list (same widget, same size,
no per-item state) with per-item cache keys or no keys.
Why: N renders where 1 suffices.
Fix: render one `MarkerIcon`, reuse via `icon.toMarker(base: ...)` per position
(render once, reuse everywhere).

## 12. Tests that hang or assert on renders (MEDIUM)

Search: `testWidgets` bodies calling any `to*` method directly.
Why: `flutter_test` runs fake async; `RepaintBoundary.toImage` and PNG encoding never
complete without a real event loop, so the test times out.
Fix: wrap the render in `await tester.runAsync(() => ...)` (the package's own test
suite does exactly this), and pump a widget first to obtain a valid context.

## Output contract for reviews

For each finding report: file:line, checklist item number, severity, one-line problem
statement, and the concrete fix (with a short code snippet when the fix is not
obvious). End with a summary table sorted by severity, and list which checklist items
were checked and found clean.
