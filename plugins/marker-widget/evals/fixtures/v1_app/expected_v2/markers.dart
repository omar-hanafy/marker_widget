// Reference "after" state: fixtures/v1_app/lib/markers.dart migrated to
// marker_widget ^2.0.0 with behavior preserved (note pixelPerfect for the
// v1 imagePixelRatio scaling mode, and NO context added to the migrated
// widgetToMarkerBitmap call).
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

  Future<BitmapDescriptor> shopIcon(BuildContext context, String id) {
    return ShopPin(label: id).toBitmapDescriptor(
      context: context,
      renderOptions: WidgetBitmapRenderOptions(
        logicalSize: const Size(72, 72),
        waitForImages: true,
        cacheKey: buildMarkerCacheKey(
          id: id,
          logicalSize: const Size(72, 72),
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
          brightness: Theme.of(context).brightness,
        ),
      ),
      bitmapOptions: const MapBitmapOptions.pixelPerfect(),
    );
  }

  Future<BitmapDescriptor> plainIcon() {
    return const ShopPin(label: 'x').toBitmapDescriptor(
      renderOptions: const WidgetBitmapRenderOptions(logicalSize: Size(48, 48)),
    );
  }

  Future<MarkerIcon> preload(BuildContext context) {
    return renderer.render(
      const ShopPin(label: 'hq'),
      context: context,
      options: const WidgetBitmapRenderOptions(
        logicalSize: Size(96, 96),
        cacheKey: 'hq',
      ),
    );
  }

  BitmapDescriptor fromIcon(MarkerIcon icon) {
    return icon.toBitmapDescriptor(
      options: const MapBitmapOptions(bitmapScaling: MapBitmapScaling.auto),
    );
  }
}
