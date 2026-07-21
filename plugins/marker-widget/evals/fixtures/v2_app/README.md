# v2 migration fixture

`lib/markers.dart` is representative marker_widget 2.x code (delay-based image
waiting via `waitForImages`/`imageRepaintDelay`, string cache-key builders,
the `defaultMarkerIconRenderer` global, renderer delay configuration).
`expected_v3/markers.dart` is the same file migrated to 3.x: providers hoisted
and declared in `imageDependencies`, `MarkerCacheKey` values without size/DPR,
`MarkerIconRenderer.shared`, delay knobs deleted.

Used by the `migration-v3-execution` eval case and useful as a manual
regression pair for the migrating-marker-widget-v2-to-v3 skill. This fixture
is a reference corpus, not a buildable project; validating the expected file
means analyzing it inside a scratch app that depends on marker_widget ^3.0.0.
