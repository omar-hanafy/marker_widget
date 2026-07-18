// Representative marker_widget 1.1.0 usage. This file compiles against
// marker_widget ^1.1.0 and is the "before" corpus for the v1-to-v2 migration
// skill and its evals. See expected_v2/markers.dart for the reference result.
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_widget/marker_widget.dart';

class ShopPin extends StatelessWidget {
  const ShopPin({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(label)),
    );
  }
}

class ShopMarkers {
  ShopMarkers(this.renderer);

  final MarkerIconRenderer renderer;

  /// v1: positional context + flat params + scalingMode.
  Future<BitmapDescriptor> shopIcon(BuildContext context, String id) {
    return ShopPin(label: id).toMarkerBitmap(
      context,
      logicalSize: const Size(72, 72),
      waitForImages: true,
      cacheKey: buildMarkerCacheKey(
        id: id,
        logicalSize: const Size(72, 72),
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
        brightness: Theme.of(context).brightness,
      ),
      scalingMode: MarkerIconScalingMode.imagePixelRatio,
    );
  }

  /// v1: contextless top-level helper.
  Future<BitmapDescriptor> plainIcon() {
    return widgetToMarkerBitmap(
      const ShopPin(label: 'x'),
      logicalSize: const Size(48, 48),
    );
  }

  /// v1: renderer.render with flat parameters.
  Future<MarkerIcon> preload(BuildContext context) {
    return renderer.render(
      const ShopPin(label: 'hq'),
      context: context,
      logicalSize: const Size(96, 96),
      cacheKey: 'hq',
    );
  }

  /// v1: MarkerIcon converters with scalingMode.
  BitmapDescriptor fromIcon(MarkerIcon icon) {
    return icon.toBitmapDescriptor(
      bitmapScaling: MapBitmapScaling.auto,
      scalingMode: MarkerIconScalingMode.logicalSize,
    );
  }
}
