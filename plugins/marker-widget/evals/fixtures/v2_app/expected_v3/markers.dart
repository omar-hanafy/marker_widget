// Reference "after" state: fixtures/v2_app/lib/markers.dart migrated to
// marker_widget ^3.0.0. Key moves: the avatar provider is hoisted so the
// SAME instance feeds both the widget and imageDependencies; the delay knobs
// are deleted (readiness is deterministic); the string key builders become
// MarkerCacheKey values without size/DPR (the renderer keys those itself);
// defaultMarkerIconRenderer becomes MarkerIconRenderer.shared.
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_widget/marker_widget.dart';

class DriverBadge extends StatelessWidget {
  const DriverBadge({required this.avatar, required this.name, super.key});

  final ImageProvider avatar;
  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(image: avatar, fit: BoxFit.cover),
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
  DriverMarkers() : renderer = MarkerIconRenderer(maxCacheEntries: 128);

  final MarkerIconRenderer renderer;

  Future<Marker> driverMarker(BuildContext context, Driver driver) {
    final ImageProvider avatar = NetworkImage(driver.avatarUrl);
    return DriverBadge(avatar: avatar, name: driver.name).toMarker(
      context: context,
      base: Marker(markerId: MarkerId(driver.id), position: driver.position),
      renderOptions: MarkerRenderOptions(
        logicalSize: const Size(56, 56),
        imageDependencies: [avatar],
        cacheKey: MarkerCacheKey(
          driver.id,
          brightness: Theme.of(context).brightness,
          extra: driver.status,
        ),
      ),
    );
  }

  Future<BitmapDescriptor> clusterIcon(BuildContext context, int count) {
    return ClusterBubble(count: count).toBitmapDescriptor(
      context: context,
      renderOptions: MarkerRenderOptions(
        logicalSize: const Size(44, 44),
        cacheKey: MarkerCacheKey.cluster(
          count: count,
          brightness: Theme.of(context).brightness,
        ),
      ),
    );
  }

  void onLogout() {
    renderer.clearCache();
    MarkerIconRenderer.shared.clearCache();
  }
}
