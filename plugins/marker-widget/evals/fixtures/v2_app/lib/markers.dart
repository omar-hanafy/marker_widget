// Representative marker_widget 2.x consumer code for the v2 -> v3 migration
// fixture: delay-based image waiting, string cache-key builders, the
// defaultMarkerIconRenderer global, and renderer delay configuration.
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_widget/marker_widget.dart';

class DriverBadge extends StatelessWidget {
  const DriverBadge({required this.avatarUrl, required this.name, super.key});

  final String avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: NetworkImage(avatarUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(child: Text(name)),
    );
  }
}

class ClusterBubble extends StatelessWidget {
  const ClusterBubble({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(child: Text('$count'));
  }
}

class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.status,
    required this.avatarUrl,
    required this.position,
  });

  final String id;
  final String name;
  final String status;
  final String avatarUrl;
  final LatLng position;
}

class DriverMarkers {
  DriverMarkers()
    : renderer = MarkerIconRenderer(
        maxCacheEntries: 128,
        initialImageDelay: const Duration(milliseconds: 32),
        imageRepaintDelay: const Duration(milliseconds: 400),
      );

  final MarkerIconRenderer renderer;

  Future<Marker> driverMarker(BuildContext context, Driver driver) {
    return DriverBadge(avatarUrl: driver.avatarUrl, name: driver.name).toMarker(
      context: context,
      base: Marker(markerId: MarkerId(driver.id), position: driver.position),
      renderOptions: WidgetBitmapRenderOptions(
        logicalSize: const Size(56, 56),
        waitForImages: true,
        imageRepaintDelay: const Duration(milliseconds: 600),
        cacheKey: buildMarkerCacheKey(
          id: driver.id,
          logicalSize: const Size(56, 56),
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
          brightness: Theme.of(context).brightness,
          extra: driver.status,
        ),
      ),
    );
  }

  Future<BitmapDescriptor> clusterIcon(BuildContext context, int count) {
    return ClusterBubble(count: count).toBitmapDescriptor(
      context: context,
      renderOptions: WidgetBitmapRenderOptions(
        logicalSize: const Size(44, 44),
        cacheKey: buildClusterCacheKey(
          count: count,
          logicalSize: const Size(44, 44),
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
          brightness: Theme.of(context).brightness,
        ),
      ),
    );
  }

  void onLogout() {
    renderer.clearCache();
    defaultMarkerIconRenderer.clearCache();
  }
}
