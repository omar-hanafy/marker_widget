import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marker_widget/marker_widget.dart';

// Deliberately does not import google_maps_flutter: these tests prove the
// package re-exports every Google Maps type its own API surface needs, so
// consumers can build markers from the marker_widget import alone.
void main() {
  Uint8List onePixel() => Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
    0x42, 0x60, 0x82,
  ]);

  test('re-exports the classic marker construction types', () {
    const marker = Marker(
      markerId: MarkerId('exported'),
      position: LatLng(1, 2),
      infoWindow: InfoWindow(title: 'title'),
    );

    expect(marker.markerId, const MarkerId('exported'));
    expect(marker.icon, isA<BitmapDescriptor>());
    expect(MapBitmapScaling.auto, isNot(MapBitmapScaling.none));
  });

  test('re-exports the bitmap and ground overlay types', () {
    final icon = MarkerIcon(
      bytes: onePixel(),
      logicalSize: const Size(1, 1),
      pixelRatio: 1.0,
    );

    final BytesMapBitmap bitmap = icon.toGroundOverlayBitmap();
    expect(bitmap, isA<BytesMapBitmap>());

    final overlay = GroundOverlay.fromBounds(
      groundOverlayId: const GroundOverlayId('overlay'),
      image: bitmap,
      bounds: LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(1, 1),
      ),
    );

    expect(overlay.groundOverlayId, const GroundOverlayId('overlay'));
  });

  test('re-exports the advanced marker and glyph types', () {
    final icon = MarkerIcon(
      bytes: onePixel(),
      logicalSize: const Size(1, 1),
      pixelRatio: 1.0,
    );

    final AdvancedMarker marker = icon.toAdvancedPinMarker(
      base: AdvancedMarker(
        markerId: const MarkerId('exported-advanced'),
        position: const LatLng(1, 2),
        collisionBehavior:
            MarkerCollisionBehavior.optionalAndHidesLowerPriority,
      ),
      backgroundColor: const Color(0xFF112233),
    );
    expect(marker.icon, isA<PinConfig>());

    final AdvancedMarkerGlyph bitmapGlyph = icon.toBitmapGlyph();
    expect(bitmapGlyph, isA<BitmapGlyph>());

    const AdvancedMarkerGlyph circle = CircleGlyph(color: Color(0xFF445566));
    const AdvancedMarkerGlyph text = TextGlyph(
      text: 'A',
      textColor: Color(0xFF000000),
    );
    expect(circle, isA<CircleGlyph>());
    expect(text, isA<TextGlyph>());
  });
}
