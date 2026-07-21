---
name: reviewing-marker-widget
description: Use when asked to review, audit, or sanity-check how a Flutter codebase uses the marker_widget package - hot-path renders without cache keys, incomplete or non-value-equal cache keys, undeclared image dependencies, missing advanced-marker prerequisites, unbounded caches, oversized renders, or marker-test hangs. Produces a read-only findings report; not for fixing code, general Flutter reviews, or projects that do not depend on marker_widget.
---

# Reviewing marker_widget usage

Audit a consumer codebase for incorrect or wasteful marker_widget usage and
produce a findings report. This is a read-only workflow: never edit, create,
or execute anything while following it.

This skill is the canonical audit procedure for every surface: Claude Code's
`marker-widget-reviewer` agent follows it, and Codex users (or a Codex
subagent recipe) invoke it directly.

## Step 1: Scope check

Confirm `marker_widget` appears in the project's `pubspec.yaml` dependencies.
If it does not, stop and report that the package is not used; do not review
anything else.

## Step 2: Locate every usage site

Search `lib/`, `test/`, and `integration_test/` for:

- Extension calls: `toBitmapDescriptor`, `toMapBitmap`, `toMarkerIcon`,
  `toMarker(`, `toAdvancedMarker`, `toAdvancedPinMarker`, `toPinConfig`,
  `toBitmapGlyph`, `toGroundOverlayBitmap`
- Renderer usage: `MarkerIconRenderer(`, `MarkerIconRenderer.shared`,
  `.render(`
- Keys and dependencies: `MarkerCacheKey`, `MarkerImageDependency`,
  `imageDependencies`, `prepare`

## Step 3: Check each site against the checklist

Read `../../references/review-checklist.md` (relative to this skill
directory) before starting; it defines items 1-12 with search patterns,
severities, and fixes. The core failure modes, in priority order:

1. HIGH: renders on hot paths (build, camera callbacks, listeners, loops)
   without a `cacheKey` (no caching, no dedup, full re-render every call).
2. HIGH: cache keys missing inputs that change pixels (brightness, locale,
   selection/status, image URL or content revision via `extra`) causing stale
   icons, or `extra` values without immutable value equality causing
   permanent misses or stale hits after mutation.
3. HIGH: async images (`Image.network`, `CachedNetworkImage`,
   `DecorationImage`) inside rendered widgets whose providers are not
   declared through `MarkerImageDependency` (blank markers), size-sensitive
   providers with a missing or wrong `configurationSize`, required font/data
   futures absent from `prepare`, or declared-image failure paths without a
   `MarkerImageLoadException` fallback where one is warranted.
4. HIGH: renders in isolates/`compute` or before binding init
   (`No FlutterView`).
5. HIGH: advanced markers missing `markerType: advancedMarker`, `mapId`, or
   web `&libraries=marker` (silently invisible markers).
6. MEDIUM: `MapBitmapScaling.none` combined with size metadata (runtime
   `StateError`); `PinConfig` on iOS without fallback (upstream rendering
   bug); unbounded caches (`maxCacheBytes: null`) or caches never cleared on
   logout/theme change; oversized `logicalSize`/hardcoded `pixelRatio`; test
   renders that reach capture without `tester.runAsync`.
7. LOW: per-item renders of identical static icons instead of
   render-once-reuse.

Read enough surrounding code to avoid false positives: a render without a
cacheKey in one-shot startup preloading is fine; the same call in
`onCameraIdle` is not. When uncertain whether a path is hot, say so
explicitly instead of inflating severity.

## Step 4: Report in the output contract

Return exactly this structure, in this order, with no preamble:

1. `## Summary` - one paragraph: project size of usage (number of call
   sites), overall health, the single most important fix.
2. `## Findings` - one entry per finding: `file:line`, checklist item
   number, severity (HIGH/MEDIUM/LOW), one-line problem, concrete fix (short
   code snippet only when the fix is not obvious from the description).
   Order findings by severity, then by file.
3. `## Clean` - checklist items verified with no findings.
4. `## Not assessed` - anything that could not be verified (missing platform
   folders, generated code) and why.

No generic Flutter advice, no restating the checklist. If there are zero
findings, say so plainly under Summary and still fill in Clean.

## Stopping conditions

Stop after producing the report. Do not propose refactors beyond the
checklist, do not review non-marker code, and do not exceed the audit even if
unrelated issues surface (mention at most one line under Not assessed that
unrelated issues exist).
