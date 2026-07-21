---
name: migrating-marker-widget-v2-to-v3
description: Use when upgrading a project from marker_widget 2.x to 3.x, or when a build breaks after a marker_widget upgrade with errors mentioning WidgetBitmapRenderOptions, waitForImages, initialImageDelay, imageRepaintDelay, buildMarkerCacheKey, buildClusterCacheKey, or defaultMarkerIconRenderer.
---

# Migrating marker_widget v2.x to v3.x

Supported path: any 2.x (including 2.1.0-dev.1) -> 3.x. Stable users come from
2.0.x, so 3.0.0 delivers BOTH the v3 API changes and the 2.1-era behavior
hardening in one hop; this skill covers both. The API moves are mostly
mechanical renames; the one step that needs real judgment is replacing
delay-based image waiting with declared `imageDependencies`.

Audience: developers upgrading a consumer app or package. Expected inputs: a
project that currently compiles against marker_widget 2.x (or was just bumped
to 3.x and now fails to compile).

## Step 1: Detect current state

1. `pubspec.yaml` + lockfile: which marker_widget is installed?
   - Already `^3.x` with a clean grep (Step 2 patterns) and passing analyze:
     nothing to migrate; stop and say so.
   - `^2.x`: proceed. `^1.x`: run
     marker-widget:migrating-marker-widget-v1-to-v2 first, then return here.
2. Preconditions: clean VCS state, and note the project's toolchain: v3
   requires Dart ^3.12.0, Flutter >= 3.44.0, and google_maps_flutter ^2.17.1.
   If the environment cannot move to those floors, do NOT start; the project
   stays on 2.x until the toolchain is upgraded.
3. If the app imports `package:equatable/equatable.dart` without declaring
   equatable in its own pubspec, it was leaking through marker_widget 2.x;
   v3 drops that dependency, so add equatable to the app's pubspec or remove
   the usage.

## Step 2: Inventory v2 usage

```
grep -rn "WidgetBitmapRenderOptions\|waitForImages\|initialImageDelay\|imageRepaintDelay\|buildMarkerCacheKey\|buildClusterCacheKey\|defaultMarkerIconRenderer\|const MarkerIcon(" lib/ test/
```

List every hit with file:line before editing. Also grep `MarkerIconRenderer(`
for custom renderer construction (delay parameters must go) and note which
rendered widgets display images (`Image`, `DecorationImage`,
`CircleAvatar(backgroundImage:`, `FadeInImage`, `CachedNetworkImage`) - they
need `imageDependencies` regardless of whether v2 used `waitForImages`.

## Step 3: Update dependencies

In `pubspec.yaml`: `marker_widget: ^3.0.0`, `google_maps_flutter: ^2.17.1`,
raise `environment:` floors to Dart ^3.12.0 / Flutter >=3.44.0 if below. Run
`flutter pub get`; resolve conflicts before touching Dart code so later errors
are purely API errors.

## Step 4: Mechanical replacements

Apply in this order (each is safe independently):

1. `WidgetBitmapRenderOptions(` -> `MarkerRenderOptions(` everywhere (type
   annotations, constructors, parameter types).
2. `defaultMarkerIconRenderer` -> `MarkerIconRenderer.shared`.
3. `buildMarkerCacheKey(id: X, logicalSize: _, pixelRatio: _, brightness: B,
   locale: L, extra: E)` -> `MarkerCacheKey(X, brightness: B, locale: L,
   extra: E)`. Drop the size and pixel-ratio arguments entirely: the renderer
   keys every cache entry by resolved size and DPR itself.
4. `buildClusterCacheKey(count: N, ...)` -> `MarkerCacheKey.cluster(count: N,
   ...)` with the same size/DPR drop.
5. Delete `initialImageDelay:` and `imageRepaintDelay:` from
   `MarkerIconRenderer(...)` constructors and from render options.
6. `const MarkerIcon(...)` -> `MarkerIcon(...)` (the constructor is no longer
   const; it defensively copies bytes).
7. Any reference to `.props` on the options classes: remove (they are no
   longer Equatable; `==`/`hashCode` behave the same).

Before/after (the common case):

```dart
// v2
final marker = await DriverBadge(avatarUrl: url).toMarker(
  context: context,
  base: base,
  renderOptions: WidgetBitmapRenderOptions(
    logicalSize: const Size(56, 56),
    waitForImages: true,
    cacheKey: buildMarkerCacheKey(
      id: driver.id,
      logicalSize: const Size(56, 56),
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      brightness: Theme.of(context).brightness,
      extra: driver.status,
    ),
  ),
);

// v3 - the provider is hoisted so the widget and the dependency
// declaration share the same instance
final avatar = NetworkImage(url);
final marker = await DriverBadge(avatar: avatar).toMarker(
  context: context,
  base: base,
  renderOptions: MarkerRenderOptions(
    logicalSize: const Size(56, 56),
    imageDependencies: [avatar],
    cacheKey: MarkerCacheKey(
      driver.id,
      brightness: Theme.of(context).brightness,
      extra: driver.status,
    ),
  ),
);
```

## Step 5: Replace image waiting with declared dependencies (judgment)

`waitForImages` and the delay knobs are gone; there is no drop-in flag. For
every rendered widget that displays images:

1. Identify the exact `ImageProvider`s the widget displays.
2. Hoist them so the render call can pass the same instances (or providers
   with equal cache keys, e.g. `NetworkImage` with the same URL and scale) in
   `renderOptions.imageDependencies`.
3. Delete `waitForImages`/delay arguments.
4. Decide failure handling: a dependency that fails to load now throws
   `MarkerImageLoadException` instead of rendering a blank area. On hot paths,
   catch it and fall back to a placeholder icon; do not swallow it silently.

Widgets that used `waitForImages: false` (or nothing) while displaying images
were capturing blanks nondeterministically in v2 - that was a latent bug.
Declare their dependencies too, and say so in the migration report.
`precacheImage` alone is not equivalent: it does not pin the decoded image
across the render, and it cannot fail the render loudly.

## Step 6: Absorb the 2.0 -> 3.0 behavior changes (no code pattern to grep)

These arrive silently for 2.0.x users; check each against the app:

- `toMarker` now throws `ArgumentError` for an `AdvancedMarker` base. If that
  fires, the app was silently pushing advanced markers through the classic
  pipeline; decide per site between a real classic `Marker` base or
  `toAdvancedMarker` plus the advanced-marker wiring (mapId, markerType).
- Oversized renders now throw: `logicalSize * pixelRatio^2` above
  `maxRasterPixels` (default one 2048x2048 physical bitmap) is rejected with
  `ArgumentError`. Batch renders are also gated to `maxConcurrentRenders`
  (default 3) at a time. Raise either limit deliberately if giant or highly
  parallel renders were intended.
- NaN/infinite sizes and ratios are rejected everywhere with descriptive
  errors instead of producing garbage output.
- Cache identity now includes resolved size and DPR: reusing one key at two
  sizes produces two entries (previously the first-rendered size was returned
  for both - a bug). `cacheSize` counts each variant; `removeFromCache`
  removes all variants of a key.
- `MediaQuery` screen geometry is zeroed in the render tree: `SafeArea`
  inside a marker renders edge to edge and notch padding no longer leaks into
  markers. Visually compare any marker widget containing `SafeArea` or
  MediaQuery-derived padding.
- The off-screen tree is fully unmounted after capture: `State.dispose` now
  runs for stateful marker widgets (timers/controllers they hold are
  released). Widgets with dispose side effects will now see them per render.
- Repeated `toMapBitmap`/`toBitmapDescriptor` on the same `MarkerIcon` return
  the identical descriptor, so rebuilt markers stay `==` and the map skips
  redundant icon updates. Code that relied on getting distinct descriptor
  instances (rare) must copy explicitly.
- `MarkerIcon.bytes` is a defensive unmodifiable copy: code that mutated the
  returned bytes, or relied on the icon aliasing the caller's buffer, now
  breaks (writes throw `UnsupportedError`).
- Contextless rendering in a multi-view app with no implicit view now throws
  `StateError` asking for a `BuildContext` instead of picking a view.
- v2 `MarkerCacheKey` note: the removed string builders compared `extra` by
  its `toString()`, which silently COLLIDED for objects with the default
  toString. `MarkerCacheKey` compares `extra` with `==`; give `extra` value
  equality (records work well) or every render is a safe-but-wasteful cache
  miss.

## Step 7: Validate

1. `dart analyze` (or `flutter analyze`): zero errors referencing Step 2
   symbols.
2. Re-run the Step 2 grep: zero hits (except intentional comments).
3. `flutter test`; wrap any test render in `tester.runAsync` if suites hang
   (fake async).
4. Run the app; verify markers with images now render their images every
   time (including cold start with an empty image cache), and compare any
   SafeArea/MediaQuery-dependent marker against pre-migration screenshots.
5. Verify error paths: point one image dependency at a dead URL in a debug
   build and confirm the app's fallback (or intentional crash) is acceptable.

## Failure handling and rollback

- Unresolvable SDK/dependency conflicts: revert the pubspec change; report
  the blocking constraint (do not loosen unrelated constraints to force
  resolution).
- A provider that cannot be hoisted to the call site (constructed deep inside
  the widget): restructure the widget to accept the provider as a parameter -
  that is the v3-idiomatic shape - or construct an equal-keyed provider (same
  URL/scale) at the call site.
- Rollback: revert the migration edits via VCS; 2.x remains on pub.dev and
  installable as `marker_widget: ^2.0.0`.

Current API details and exact error strings:
../../references/api-quick-reference.md. A fixture project pair for practicing
or regression-testing this migration: ../../evals/fixtures/v2_app/ (v2 source,
expected_v3 result) in the plugin root.

## Example scenario

"Bumped marker_widget to 3.0.0 and got 'Undefined name
defaultMarkerIconRenderer' plus 'The named parameter waitForImages isn't
defined'": inventory found 9 call sites; renames per Step 4, two avatar
widgets restructured to accept a hoisted `NetworkImage` declared in
`imageDependencies`, keys rebuilt as `MarkerCacheKey` with record `extra`,
`MarkerImageLoadException` fallback added to the driver-list path; analyze
clean, avatars verified on a cold image cache.
