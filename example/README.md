# marker_widget example

Runnable demonstrations of classic markers, advanced marker pins, and ground
overlays generated with `marker_widget`.

The example targets Android, iOS, and web, matching the platforms supported by
`google_maps_flutter`. Configure the normal Google Maps API keys for the target
platform, then run:

```sh
flutter pub get
flutter run
```

Advanced markers require a cloud map ID. Supply it at build time:

```sh
flutter run --dart-define=GOOGLE_MAPS_ADVANCED_MAP_ID=your-map-id
```

On web, also load the Google Maps JavaScript `marker` library in
`web/index.html`.
