# v1 migration fixture

`lib/markers.dart` is representative marker_widget 1.1.0 code (positional context,
flat parameters, `scalingMode`, `widgetToMarkerBitmap`, flat `render()` arguments).
`expected_v2/markers.dart` is the behavior-preserving 2.x migration of the same file.

Used by the `migration-execution` eval case and useful as a manual regression pair
for the migrating-marker-widget-v1-to-v2 skill. This fixture is a reference corpus,
not a buildable project; validating the expected file means analyzing it inside a
scratch app that depends on marker_widget ^2.0.0.
