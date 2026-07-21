/// A Flutter package for rendering widgets as Google Maps markers.
///
/// This library provides tools to convert any Flutter [Widget] into a
/// [BitmapDescriptor], [BytesMapBitmap], [Marker], or [AdvancedMarker] that
/// can be used with the `google_maps_flutter` package.
///
/// Key features:
/// * [toBitmapDescriptor] extension on [Widget] for easy conversion.
/// * [MarkerIconRenderer] for advanced control and caching.
/// * [MapBitmapOptions] and [MarkerRenderOptions] for explicit sizing.
/// * [MarkerRenderOptions.imageDependencies] for deterministic image
///   readiness (images are decoded before capture, never blank).
/// * [MarkerCacheKey] for collision-safe cache identity.
/// * Helpers for [PinConfig], [BitmapGlyph], and advanced markers.
///
/// The Google Maps types used by this package's API ([Marker],
/// [BitmapDescriptor], [BytesMapBitmap], [GroundOverlay], ...) are
/// re-exported, so markers can be built without a second import.
library;

export 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
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
        MapBitmap,
        MapBitmapScaling,
        Marker,
        MarkerCollisionBehavior,
        MarkerId,
        PinConfig,
        TextGlyph;
export 'src/marker_widget.dart';
