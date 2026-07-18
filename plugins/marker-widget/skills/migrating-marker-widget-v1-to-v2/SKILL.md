---
name: migrating-marker-widget-v1-to-v2
description: Use when upgrading a project from marker_widget 1.x to 2.x, or when a build breaks after a marker_widget upgrade with errors mentioning toMarkerBitmap, widgetToMarkerBitmap, widgetToMapBitmap, widgetToMarkerIcon, MarkerIconScalingMode, scalingMode, MarkerBuildOptions, AdvancedMarkerBuildOptions, or renderedDpr.
---

# Migrating marker_widget v1.x to v2.x

Supported path: 1.0.0 or 1.1.0 -> any 2.x. This is the only breaking hop that exists;
1.0.0 -> 1.1.0 was additive. The migration is mostly mechanical renames plus reshaping
flat parameters into two option objects, with three decisions that need judgment
(scaling mode, custom renderer defaults, contextless helpers).

Audience: developers upgrading a consumer app or package. Expected inputs: a project
that currently compiles against marker_widget 1.x (or was just bumped to 2.x and now
fails to compile).

## Step 1: Detect current state

1. `pubspec.yaml` + lockfile: which marker_widget is installed?
   - Already `^2.x` with a clean `grep` (Step 2 patterns) and passing analyze: nothing
     to migrate; stop and say so.
   - `^1.x`: proceed.
2. Preconditions: clean VCS state (commit or stash first; the rollback path is
   `git checkout` of these edits), and note the project's Flutter/Dart versions:
   v2 requires Dart ^3.10.0 and Flutter >= 3.41.4, and google_maps_flutter ^2.15.0.
   If the environment cannot move to those floors, do NOT start; the project must stay
   on 1.x until the toolchain is upgraded.

## Step 2: Inventory v1 usage

```
grep -rn "toMarkerBitmap\|widgetToMarkerBitmap\|widgetToMapBitmap\|widgetToMarkerIcon\|MarkerIconScalingMode\|scalingMode\s*:\|MarkerBuildOptions\|AdvancedMarkerBuildOptions\|renderedDpr\|\.render(" lib/ test/
```

List every hit with file:line before editing. Also grep `MarkerIconRenderer(` to find
custom renderer construction (matters for decision 2 below).

## Step 3: Update dependencies

In `pubspec.yaml`: `marker_widget: ^2.0.0`, ensure `google_maps_flutter: ^2.15.0`,
raise `environment:` floors if below Dart 3.10 / Flutter 3.41.4. Run `flutter pub get`;
resolve conflicts before touching Dart code so later errors are purely API errors.

## Step 4: Mechanical replacements

Apply in this order (each is safe independently):

1. `MyWidget().toMarkerBitmap(context, ...)` ->
   `MyWidget().toBitmapDescriptor(context: context, ...)` (context becomes NAMED).
2. `widgetToMarkerBitmap(w, ...)` -> `w.toBitmapDescriptor(...)`;
   `widgetToMapBitmap(w, ...)` -> `w.toMapBitmap(...)`;
   `widgetToMarkerIcon(w, ...)` -> `w.toMarkerIcon(...)`.
   Do NOT add `context:` to these (v1 helpers had no context; adding one changes
   rendered output - see judgment call 3).
3. Fold flat parameters into the two option objects:
   - `logicalSize`, `pixelRatio`, `waitForImages`, `cacheKey`, `initialImageDelay`,
     `imageRepaintDelay` -> `renderOptions: WidgetBitmapRenderOptions(...)`
   - `bitmapScaling` -> `bitmapOptions: MapBitmapOptions(bitmapScaling: ...)`
4. Scaling mode:
   - `scalingMode: MarkerIconScalingMode.logicalSize` (or omitted) -> delete; the v2
     default is equivalent.
   - `scalingMode: MarkerIconScalingMode.imagePixelRatio` ->
     `bitmapOptions: const MapBitmapOptions.pixelPerfect()`.
5. `MarkerIcon.toMapBitmap(bitmapScaling: X, scalingMode: Y)` ->
   `toMapBitmap(options: MapBitmapOptions(bitmapScaling: X))` with the same
   pixelPerfect rule for Y; same for `MarkerIcon.toBitmapDescriptor`.
6. `MarkerIconRenderer.render(w, context: c, logicalSize: s, ...)` ->
   `render(w, context: c, options: WidgetBitmapRenderOptions(logicalSize: s, ...))`.
7. Prerelease-only symbols if present: `MapBitmapOptions.renderedDpr()` ->
   `MapBitmapOptions.pixelPerfect()`; `MarkerBuildOptions`/`AdvancedMarkerBuildOptions`
   -> pass real `Marker`/`AdvancedMarker` objects as `base:`.

Before/after (the common case):

```dart
// v1
final icon = await MyPin().toMarkerBitmap(
  context,
  logicalSize: const Size(80, 80),
  cacheKey: key,
  scalingMode: MarkerIconScalingMode.imagePixelRatio,
);

// v2
final icon = await MyPin().toBitmapDescriptor(
  context: context,
  renderOptions: WidgetBitmapRenderOptions(
    logicalSize: const Size(80, 80),
    cacheKey: key,
  ),
  bitmapOptions: const MapBitmapOptions.pixelPerfect(),
);
```

## Judgment calls (ask or flag; do not decide silently)

1. `imagePixelRatio` scaling: `pixelPerfect()` preserves v1 behavior exactly
   (DPR-dependent on-map size). Dropping it changes visible marker size on high-DPR
   devices. Preserve behavior by default; flag if the default path seems intended.
2. Custom renderer with non-default `defaultLogicalSize`: v1 extension calls defaulted
   to `Size(96, 96)` PER CALL; v2 defaults to the RENDERER's `defaultLogicalSize`. If a
   custom renderer sets a different default, add explicit
   `logicalSize: const Size(96, 96)` to calls that previously relied on the v1
   per-call default.
3. Replacing `widgetTo*` helpers: keeping them contextless is behavior-preserving.
   Passing `context:` is usually an improvement (theme/locale-aware icons) but changes
   output; offer it as a follow-up, not part of the migration.
4. Persisted cache-key strings: v2 `buildMarkerCacheKey` appends `|extra=none`. Only
   matters if an app persisted v1 key strings across sessions (rare); in-memory keys
   are fine.

## Edge cases

- App relied on stale in-flight renders repopulating the cache after `clearCache()`:
  v2 blocks that (it was a v1 bug). Re-render after clearing if needed.
- Localized marker widgets rendered WITH context may legitimately look different in
  v2: localizations and DefaultAssetBundle are now inherited too. Expected; mention it.
- `MapBitmapScaling.none`: rejected by v1's converters entirely; in v2 it works but
  only metadata-free. Code that hand-built raw `BytesMapBitmap`s can now use
  `toGroundOverlayBitmap()`/`MapBitmapOptions(bitmapScaling: MapBitmapScaling.none)`.

## Step 5: Validate

1. `dart analyze` (or `flutter analyze`): zero errors referencing the Step 2 symbols.
2. Re-run Step 2 grep: zero hits (except intentional comments).
3. `flutter test`; wrap any test render in `tester.runAsync` if suites hang (fake
   async).
4. Run the app; verify marker sizes match pre-migration screenshots, especially any
   call migrated to `pixelPerfect()`.
5. Expected warnings: none from marker_widget itself. Analyzer may newly flag
   `unawaited_futures` where call shapes changed; fix properly, do not ignore.

## Failure handling and rollback

- Unresolvable SDK/dependency conflicts: revert the pubspec change; report the
  blocking constraint (do not loosen unrelated constraints to force resolution).
- Behavior ambiguity you cannot resolve from code (e.g. whether DPR-dependent sizing
  was intentional): keep the behavior-preserving mapping and list it in the report.
- Rollback: revert the migration edits via VCS; v1 remains on pub.dev and installable
  as `marker_widget: ^1.1.0`.

Complete v1 signatures, exact mapping tables, and behavior-difference details:
references/v1-api.md (in this skill directory). A fixture project pair for practicing
or regression-testing this migration: ../../evals/fixtures/v1_app/ (v1 source) in the
plugin root.

## Example scenario

"Bumped marker_widget to 2.0.0 and got 'The method toMarkerBitmap isn't defined for
the type MyPin'": classic Step 4.1 + 4.3 case; inventory found 6 call sites and one
`scalingMode: imagePixelRatio` which became `MapBitmapOptions.pixelPerfect()`;
analyze clean, sizes verified unchanged on a 3x device.
