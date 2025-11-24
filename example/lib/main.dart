import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_widget/marker_widget.dart';

void main() {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MarkerWidgetExampleApp());
}

class MarkerWidgetExampleApp extends StatelessWidget {
  const MarkerWidgetExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'marker_widget example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MarkerWidgetExamplePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MarkerWidgetExamplePage extends StatefulWidget {
  const MarkerWidgetExamplePage({super.key});

  @override
  State<MarkerWidgetExamplePage> createState() =>
      _MarkerWidgetExamplePageState();
}

class _MarkerWidgetExamplePageState extends State<MarkerWidgetExamplePage> {
  static const LatLng _markerPosition = LatLng(
    37.42796133580664,
    -122.085749655962,
  );

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: _markerPosition,
    zoom: 13,
  );

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  BitmapDescriptor? _markerIcon;
  Set<Marker> _markers = <Marker>{};
  bool _isLoadingIcon = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_markerIcon == null && !_isLoadingIcon) {
      _loadMarkerIcon();
    }
  }

  Future<void> _loadMarkerIcon() async {
    _isLoadingIcon = true;

    try {
      const logicalSize = Size(100, 100);
      final dpr = MediaQuery.devicePixelRatioOf(context);

      final icon =
          await _DemoMarkerWidget(
            title: 'You are here',
            subtitle: 'Widget-powered marker',
            color: Theme.of(context).colorScheme.primary,
          ).toMarkerBitmap(
            context,
            logicalSize: logicalSize,
            waitForImages: true,
            cacheKey: buildMarkerCacheKey(
              id: 'demo-marker',
              logicalSize: logicalSize,
              pixelRatio: dpr,
              brightness: Theme.of(context).brightness,
              locale: Localizations.maybeLocaleOf(context),
            ),
            // Try the alternative scaling mode:
            // scalingMode: MarkerIconScalingMode.imagePixelRatio,
            // bitmapScaling: MapBitmapScaling.none,
          );

      if (!mounted) return;

      setState(() {
        _markerIcon = icon;
        _markers = {
          Marker(
            markerId: const MarkerId('demo-marker'),
            position: _markerPosition,
            icon: icon,
            infoWindow: const InfoWindow(
              title: 'Custom widget marker',
              snippet: 'Rendered with marker_widget',
            ),
          ),
        };
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to create marker icon: $error\n$stackTrace');
    } finally {
      _isLoadingIcon = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _markerIcon == null;

    return Scaffold(
      appBar: AppBar(title: const Text('marker_widget example')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialCameraPosition,
              onMapCreated: (controller) {
                if (!_controller.isCompleted) {
                  _controller.complete(controller);
                }
              },
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Building marker icon…'),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text('Marker is rendered from a widget.'),
                  FilledButton.tonal(
                    onPressed: _recreateMarkerWithOtherScaling,
                    child: const Text('Try imagePixelRatio scaling'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _recreateMarkerWithOtherScaling() async {
    if (_markerIcon == null) {
      return;
    }

    const logicalSize = Size(100, 100);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final icon =
        await _DemoMarkerWidget(
          title: 'Crisp marker',
          subtitle: 'scaling mode',
          color: Colors.deepOrange,
        ).toMarkerBitmap(
          context,
          logicalSize: logicalSize,
          waitForImages: true,
          cacheKey: buildMarkerCacheKey(
            id: 'demo-marker-imagePixelRatio',
            logicalSize: logicalSize,
            pixelRatio: dpr,
            brightness: Theme.of(context).brightness,
            locale: Localizations.maybeLocaleOf(context),
          ),
          scalingMode: MarkerIconScalingMode.imagePixelRatio,
          // google_maps_flutter forbids combining imagePixelRatio with
          // MapBitmapScaling.none.
          bitmapScaling: MapBitmapScaling.auto,
        );

    if (!mounted) return;

    setState(() {
      _markerIcon = icon;
      _markers = {
        Marker(
          markerId: const MarkerId('demo-marker'),
          position: _markerPosition,
          icon: icon,
          infoWindow: const InfoWindow(
            title: 'Crisp custom marker',
            snippet: 'Using imagePixelRatio scaling',
          ),
        ),
      };
    });
  }
}

class _DemoMarkerWidget extends StatelessWidget {
  const _DemoMarkerWidget({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, scheme.primaryContainer]),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.place, color: Colors.white, size: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
