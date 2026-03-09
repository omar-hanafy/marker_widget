/// A Flutter package for rendering widgets as Google Maps markers.
///
/// This library provides tools to convert any Flutter [Widget] into a
/// [BitmapDescriptor], [BytesMapBitmap], [Marker], or [AdvancedMarker] that
/// can be used with the `google_maps_flutter` package.
///
/// Key features:
/// * [toBitmapDescriptor] extension on [Widget] for easy conversion.
/// * [MarkerIconRenderer] for advanced control and caching.
/// * [MapBitmapOptions] and [WidgetBitmapRenderOptions] for explicit sizing.
/// * Helpers for [PinConfig], [BitmapGlyph], and advanced markers.
library;

export 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    show
        AdvancedMarker,
        AdvancedMarkerGlyph,
        BitmapGlyph,
        CircleGlyph,
        MarkerCollisionBehavior,
        PinConfig,
        TextGlyph;
export 'src/marker_widget.dart';
