import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_widget/marker_widget.dart';

void main() {
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

enum _DemoMode { classicMarker, advancedPin, groundOverlay }

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

  static const String _advancedMapIdValue = String.fromEnvironment(
    'GOOGLE_MAPS_ADVANCED_MAP_ID',
  );

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  _DemoMode _mode = _DemoMode.classicMarker;
  Set<Marker> _markers = <Marker>{};
  Set<GroundOverlay> _groundOverlays = <GroundOverlay>{};
  bool _isLoading = false;
  String _statusMessage = 'Classic marker built with Widget.toMarker().';

  String? get _advancedMapId =>
      _advancedMapIdValue.isEmpty ? null : _advancedMapIdValue;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoading && _markers.isEmpty && _groundOverlays.isEmpty) {
      _loadModeContent();
    }
  }

  Future<void> _loadModeContent() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final ThemeData theme = Theme.of(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);

    try {
      switch (_mode) {
        case _DemoMode.classicMarker:
          final Marker marker =
              await _ClassicMarkerCard(
                title: 'Classic marker',
                subtitle: 'Widget.toMarker()',
                color: theme.colorScheme.primary,
              ).toMarker(
                context: context,
                base: const Marker(
                  markerId: MarkerId('classic-marker'),
                  position: _markerPosition,
                  infoWindow: InfoWindow(
                    title: 'Classic marker',
                    snippet: 'Built directly from a widget',
                  ),
                  zIndexInt: 1,
                ),
                renderOptions: WidgetBitmapRenderOptions(
                  logicalSize: const Size(104, 104),
                  cacheKey: buildMarkerCacheKey(
                    id: 'classic-marker',
                    logicalSize: const Size(104, 104),
                    pixelRatio: dpr,
                    brightness: theme.brightness,
                    locale: Localizations.maybeLocaleOf(context),
                  ),
                ),
              );

          if (!mounted) {
            return;
          }

          setState(() {
            _markers = <Marker>{marker};
            _groundOverlays = <GroundOverlay>{};
            _statusMessage = 'Classic marker built with Widget.toMarker().';
          });
        case _DemoMode.advancedPin:
          if (_advancedMapId == null) {
            if (!mounted) {
              return;
            }

            setState(() {
              _markers = <Marker>{};
              _groundOverlays = <GroundOverlay>{};
              _statusMessage =
                  'Set GOOGLE_MAPS_ADVANCED_MAP_ID to preview advanced '
                  'markers. Web also needs &libraries=marker.';
            });
            break;
          }

          final AdvancedMarker marker =
              await _GlyphBadge(
                label: 'MW',
                color: theme.colorScheme.primary,
              ).toAdvancedPinMarker(
                context: context,
                base: AdvancedMarker(
                  markerId: const MarkerId('advanced-pin'),
                  position: _markerPosition,
                  infoWindow: const InfoWindow(
                    title: 'Advanced marker',
                    snippet: 'PinConfig + widget glyph',
                  ),
                  zIndex: 2,
                  collisionBehavior:
                      MarkerCollisionBehavior.requiredAndHidesOptional,
                ),
                backgroundColor: theme.colorScheme.surface,
                borderColor: theme.colorScheme.primary,
                renderOptions: WidgetBitmapRenderOptions(
                  logicalSize: const Size(28, 28),
                  cacheKey: buildMarkerCacheKey(
                    id: 'advanced-pin',
                    logicalSize: const Size(28, 28),
                    pixelRatio: dpr,
                    brightness: theme.brightness,
                    locale: Localizations.maybeLocaleOf(context),
                  ),
                ),
                bitmapOptions: const MapBitmapOptions(width: 28, height: 28),
              );

          if (!mounted) {
            return;
          }

          setState(() {
            _markers = <Marker>{marker};
            _groundOverlays = <GroundOverlay>{};
            _statusMessage =
                'AdvancedMarker using a widget-rendered glyph inside '
                'PinConfig.';
          });
        case _DemoMode.groundOverlay:
          final BytesMapBitmap bitmap =
              await _GroundOverlayCard(
                label: 'Widget Ground Overlay',
              ).toGroundOverlayBitmap(
                context: context,
                renderOptions: WidgetBitmapRenderOptions(
                  logicalSize: const Size(180, 120),
                  cacheKey: buildMarkerCacheKey(
                    id: 'ground-overlay',
                    logicalSize: const Size(180, 120),
                    pixelRatio: dpr,
                    brightness: theme.brightness,
                    locale: Localizations.maybeLocaleOf(context),
                  ),
                ),
              );

          final GroundOverlay overlay = GroundOverlay.fromBounds(
            groundOverlayId: const GroundOverlayId('widget-ground-overlay'),
            image: bitmap,
            bounds: LatLngBounds(
              southwest: const LatLng(37.4268, -122.0867),
              northeast: const LatLng(37.4290, -122.0848),
            ),
            transparency: 0.08,
            zIndex: 1,
          );

          if (!mounted) {
            return;
          }

          setState(() {
            _markers = <Marker>{};
            _groundOverlays = <GroundOverlay>{overlay};
            _statusMessage =
                'GroundOverlay built from Widget.toGroundOverlayBitmap().';
          });
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to build example content: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _markers = <Marker>{};
        _groundOverlays = <GroundOverlay>{};
        _statusMessage = 'Failed to build example content: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onModeChanged(Set<_DemoMode> selection) {
    final _DemoMode nextMode = selection.first;
    if (_mode == nextMode) {
      return;
    }

    setState(() {
      _mode = nextMode;
      _markers = <Marker>{};
      _groundOverlays = <GroundOverlay>{};
    });
    unawaited(_loadModeContent());
  }

  @override
  Widget build(BuildContext context) {
    final bool useAdvancedMarkers =
        _mode == _DemoMode.advancedPin && _advancedMapId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('marker_widget v2 example')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<_DemoMode>(
              segments: const <ButtonSegment<_DemoMode>>[
                ButtonSegment<_DemoMode>(
                  value: _DemoMode.classicMarker,
                  label: Text('Classic'),
                  icon: Icon(Icons.place_outlined),
                ),
                ButtonSegment<_DemoMode>(
                  value: _DemoMode.advancedPin,
                  label: Text('Advanced'),
                  icon: Icon(Icons.push_pin_outlined),
                ),
                ButtonSegment<_DemoMode>(
                  value: _DemoMode.groundOverlay,
                  label: Text('Overlay'),
                  icon: Icon(Icons.layers_outlined),
                ),
              ],
              selected: <_DemoMode>{_mode},
              onSelectionChanged: _onModeChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_statusMessage, textAlign: TextAlign.center),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Rendering widgets for the map...'),
                ],
              ),
            ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialCameraPosition,
              onMapCreated: (GoogleMapController controller) {
                if (!_controller.isCompleted) {
                  _controller.complete(controller);
                }
              },
              mapId: useAdvancedMarkers ? _advancedMapId : null,
              markerType: useAdvancedMarkers
                  ? GoogleMapMarkerType.advancedMarker
                  : GoogleMapMarkerType.marker,
              markers: _markers,
              groundOverlays: _groundOverlays,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              useAdvancedMarkers
                  ? 'Advanced markers need a mapId. On web, also load '
                        '&libraries=marker in web/index.html.'
                  : 'Classic markers and ground overlays work with the regular '
                        'Google Maps setup.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassicMarkerCard extends StatelessWidget {
  const _ClassicMarkerCard({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: <Color>[color, scheme.primary]),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.place, color: Colors.white, size: 26),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlyphBadge extends StatelessWidget {
  const _GlyphBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _GroundOverlayCard extends StatelessWidget {
  const _GroundOverlayCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[scheme.primaryContainer, scheme.tertiaryContainer],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.layers, color: scheme.onPrimaryContainer, size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Rendered from a Flutter widget',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
