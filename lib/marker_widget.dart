/// A Flutter package for rendering widgets as Google Maps markers.
///
/// This library provides tools to convert any Flutter [Widget] into a
/// [BitmapDescriptor] or [BytesMapBitmap] that can be used with the
/// `google_maps_flutter` package.
///
/// Key features:
/// * [toMarkerBitmap] extension on [Widget] for easy conversion.
/// * [MarkerIconRenderer] for advanced control and caching.
/// * Support for device pixel ratio and logical sizing.
library;

export 'src/marker_widget.dart';
