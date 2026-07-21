/// A Flutter package for rendering widgets as Google Maps markers.
///
/// This library converts self-contained, rasterizable Flutter snapshot widgets
/// into [BitmapDescriptor], [BytesMapBitmap], [Marker], or [AdvancedMarker]
/// values for the `google_maps_flutter` package.
///
/// Key features:
/// * [WidgetMarkerExtension.toBitmapDescriptor] on [Widget] for easy
///   conversion.
/// * [MarkerIconRenderer] for advanced control and caching.
/// * [MapBitmapOptions] and [MarkerRenderOptions] for explicit sizing.
/// * [MarkerRenderOptions.imageDependencies] for deterministic image
///   provider decoding before capture.
/// * [MarkerRenderOptions.prepare] for required asynchronous font or data work.
/// * [MarkerCacheKey] for collision-safe cache identity.
/// * Helpers for [PinConfig], [BitmapGlyph], and advanced markers.
///
/// The Google Maps types used by this package's API ([Marker],
/// [BitmapDescriptor], [BytesMapBitmap], [GroundOverlay], ...) are
/// re-exported, so markers can be built without a second import.
library;

export 'package:google_maps_flutter/google_maps_flutter.dart'
    show
        AdvancedMarker,
        AdvancedMarkerGlyph,
        BitmapDescriptor,
        BitmapGlyph,
        BytesMapBitmap,
        CircleGlyph,
        GroundOverlay,
        GroundOverlayId,
        InfoWindow,
        LatLng,
        LatLngBounds,
        MapBitmapScaling,
        Marker,
        MarkerCollisionBehavior,
        MarkerId,
        PinConfig,
        TextGlyph;
export 'src/marker_widget.dart';
