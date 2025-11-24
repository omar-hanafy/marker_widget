import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// How to interpret a [MarkerIcon] when creating a [BitmapDescriptor].
///
/// - [logicalSize] (default)  → use [MarkerIcon.logicalSize] as the marker's
///   width/height in logical pixels on the map.
/// - [imagePixelRatio]        → use [MarkerIcon.pixelRatio] as
///   `imagePixelRatio` for [BitmapDescriptor.bytes].
///
/// The width/height path gives consistent marker *sizes* across devices.
/// The imagePixelRatio path gives pixel‑perfect rendering but marker size
/// will vary with device DPR.
enum MarkerIconScalingMode {
  /// Interpret the icon size in logical pixels to keep marker dimensions
  /// consistent across devices regardless of device pixel ratio.
  logicalSize,

  /// Preserve the rendered pixel data exactly by passing it as
  /// `imagePixelRatio`, which can yield sharper edges but allows the on-map
  /// size to vary with device pixel ratio.
  imagePixelRatio,
}

/// Small value object that carries everything we know about the rendered marker.
class MarkerIcon {
  /// Create an icon from rendered PNG [bytes] along with the [logicalSize] and
  /// [pixelRatio] used to produce them.
  const MarkerIcon({
    required this.bytes,
    required this.logicalSize,
    required this.pixelRatio,
  });

  /// PNG bytes (Uint8List) of the rendered widget.
  final Uint8List bytes;

  /// Desired size on the map in logical pixels.
  final Size logicalSize;

  /// Device pixel ratio used when rendering the widget off‑screen.
  final double pixelRatio;

  /// Convert to a Google Maps [BitmapDescriptor] using the modern API.
  ///
  /// [bitmapScaling] controls how google_maps_flutter scales the marker.
  ///
  /// [scalingMode] chooses whether we interpret this icon as:
  /// - [MarkerIconScalingMode.logicalSize] (default):
  ///   passes [logicalSize] as `width`/`height`.
  /// - [MarkerIconScalingMode.imagePixelRatio]:
  ///   passes [pixelRatio] as `imagePixelRatio`.
  ///
  /// Throws [StateError] if the icon is in an invalid state (e.g. empty bytes,
  /// non‑positive sizes).
  BitmapDescriptor toBitmapDescriptor({
    MapBitmapScaling bitmapScaling = MapBitmapScaling.auto,
    MarkerIconScalingMode scalingMode = MarkerIconScalingMode.logicalSize,
  }) {
    if (bytes.isEmpty) {
      throw StateError('MarkerIcon.bytes must not be empty.');
    }

    if (scalingMode == MarkerIconScalingMode.imagePixelRatio &&
        bitmapScaling == MapBitmapScaling.none) {
      // google_maps_flutter disallows providing imagePixelRatio when bitmap
      // scaling is disabled.
      throw StateError(
        'bitmapScaling must not be MapBitmapScaling.none when using '
        'MarkerIconScalingMode.imagePixelRatio because '
        'BitmapDescriptor.bytes forbids combining these parameters.',
      );
    }

    switch (scalingMode) {
      case MarkerIconScalingMode.logicalSize:
        if (logicalSize.width <= 0 || logicalSize.height <= 0) {
          throw StateError(
            'MarkerIcon.logicalSize must be > 0 in both dimensions. '
            'Got $logicalSize.',
          );
        }
        return BitmapDescriptor.bytes(
          bytes,
          width: logicalSize.width,
          height: logicalSize.height,
          bitmapScaling: bitmapScaling,
        );

      case MarkerIconScalingMode.imagePixelRatio:
        if (pixelRatio <= 0) {
          throw StateError(
            'MarkerIcon.pixelRatio must be > 0 when using '
            'MarkerIconScalingMode.imagePixelRatio. '
            'Got $pixelRatio.',
          );
        }
        return BitmapDescriptor.bytes(
          bytes,
          imagePixelRatio: pixelRatio,
          bitmapScaling: bitmapScaling,
        );
    }
  }
}

/// Renders arbitrary widgets into PNG bytes off‑screen.
///
/// This is where all the gnarly RenderView / PipelineOwner bits live, so your
/// public API stays stable if Flutter tweaks internals again.
///
/// On web this requires the CanvasKit / Flutter GPU renderer, because
/// [RenderRepaintBoundary.toImage] is not supported by the legacy HTML
/// renderer. On modern Flutter (3.24+), CanvasKit is the default.
class MarkerIconRenderer {
  /// Configure a renderer that turns widgets into marker icons.
  ///
  /// You can tweak [defaultLogicalSize] for callers that omit a size, enable or
  /// disable [enableCaching], control cache capacity via [maxCacheEntries], and
  /// adjust the image settling delays used when [render] waits for images.
  MarkerIconRenderer({
    this.defaultLogicalSize = const Size(96, 96),
    this.enableCaching = true,
    this.maxCacheEntries = 64,
    this.initialImageDelay = const Duration(milliseconds: 16),
    this.imageRepaintDelay = const Duration(milliseconds: 200),
  }) : assert(maxCacheEntries > 0, 'maxCacheEntries > 0');

  /// Default marker size used when [render] is called without [logicalSize].
  final Size defaultLogicalSize;

  /// Enables the internal LRU cache if true.
  final bool enableCaching;

  /// Maximum number of cached entries before LRU eviction kicks in.
  final int maxCacheEntries;

  /// Default delay between first paint and checking for images when
  /// [waitForImages] is enabled.
  final Duration initialImageDelay;

  /// Default extra delay to give images time to resolve before repainting when
  /// [waitForImages] is enabled.
  final Duration imageRepaintDelay;

  /// Simple LRU cache keyed by any object (string, enum, etc).
  ///
  /// We rely on [LinkedHashMap] preserving insertion order.
  final LinkedHashMap<Object, MarkerIcon> _cache =
      LinkedHashMap<Object, MarkerIcon>();

  /// Render [widget] to a [MarkerIcon].
  ///
  /// - If [context] is provided, we reuse its MediaQuery/Theme/Directionality.
  /// - [logicalSize] is the size you want on the map in logical pixels.
  /// - [pixelRatio] defaults to the view's devicePixelRatio.
  /// - If [waitForImages] is true, we do a cheap second pass when we detect
  ///   image render objects to give network/asset images a chance to load.
  ///
  /// [cacheKey] is entirely up to you: make sure it encodes *everything*
  /// that affects the visual output (e.g. user ID + theme + locale + size).
  ///
  /// You can override the default [initialImageDelay] / [imageRepaintDelay]
  /// per call if needed.
  Future<MarkerIcon> render(
    Widget widget, {
    BuildContext? context,
    Size? logicalSize,
    double? pixelRatio,
    bool waitForImages = false,
    Object? cacheKey,
    Duration? initialImageDelay,
    Duration? imageRepaintDelay,
  }) async {
    final Object? key = enableCaching ? cacheKey : null;

    if (key != null) {
      final cached = _cache[key];
      if (cached != null) {
        _bump(key);
        return cached;
      }
    }

    final ui.FlutterView view = _resolveView(context);
    final Size size = logicalSize ?? defaultLogicalSize;

    // Runtime guards (not just asserts) so release builds fail loudly.
    if (size.width <= 0 || size.height <= 0) {
      throw ArgumentError.value(
        size,
        'logicalSize',
        'logicalSize.width and logicalSize.height must both be > 0.',
      );
    }

    if (pixelRatio != null && pixelRatio <= 0) {
      throw ArgumentError.value(
        pixelRatio,
        'pixelRatio',
        'pixelRatio must be > 0 when provided.',
      );
    }

    final double dpr = pixelRatio ?? view.devicePixelRatio;

    final Widget wrapped = _wrapWidget(
      widget,
      context: context,
      view: view,
      logicalSize: size,
      devicePixelRatio: dpr,
    );

    final Duration resolvedInitialDelay =
        initialImageDelay ?? this.initialImageDelay;
    final Duration resolvedRepaintDelay =
        imageRepaintDelay ?? this.imageRepaintDelay;

    final Uint8List bytes = await _renderOffScreen(
      wrapped,
      view: view,
      logicalSize: size,
      pixelRatio: dpr,
      waitForImages: waitForImages,
      initialImageDelay: resolvedInitialDelay,
      imageRepaintDelay: resolvedRepaintDelay,
    );

    final icon = MarkerIcon(
      bytes: bytes,
      logicalSize: size,
      pixelRatio: dpr,
    );

    if (key != null) {
      _put(key, icon);
    }

    return icon;
  }

  /// Clear the internal cache.
  void clearCache() {
    _cache.clear();
  }

  /// Remove one cached entry.
  void removeFromCache(Object key) {
    _cache.remove(key);
  }

  // ---- internals -----------------------------------------------------------

  ui.FlutterView _resolveView(BuildContext? context) {
    if (context != null) {
      final ui.FlutterView? view = View.maybeOf(context);
      if (view != null) {
        return view;
      }
    }

    final dispatcher = WidgetsBinding.instance.platformDispatcher;

    final ui.FlutterView? implicitView = dispatcher.implicitView;
    if (implicitView != null) {
      return implicitView;
    }

    if (dispatcher.views.isNotEmpty) {
      return dispatcher.views.first;
    }

    throw StateError(
      'No FlutterView is available. Ensure WidgetsFlutterBinding is '
      'initialized before calling MarkerIconRenderer.render.',
    );
  }

  Widget _wrapWidget(
    Widget child, {
    required ui.FlutterView view,
    required Size logicalSize,
    required double devicePixelRatio,
    BuildContext? context,
  }) {
    final MediaQueryData baseMediaQuery = context != null
        ? (MediaQuery.maybeOf(context) ?? MediaQueryData.fromView(view))
        : MediaQueryData.fromView(view);

    // Make the off‑screen MediaQuery match the logical size and DPR we use
    // when rendering into the off‑screen RenderView, so widgets that read
    // MediaQuery.size/devicePixelRatio behave consistently.
    final MediaQueryData mediaQuery = baseMediaQuery.copyWith(
      size: logicalSize,
      devicePixelRatio: devicePixelRatio,
    );

    final TextDirection textDirection = context != null
        ? (Directionality.maybeOf(context) ?? TextDirection.ltr)
        : TextDirection.ltr;

    Widget current;
    if (context != null) {
      // Capture Theme, IconTheme, etc. from the live tree.
      current = InheritedTheme.captureAll(
        context,
        Material(
          type: MaterialType.transparency,
          child: child,
        ),
      );
    } else {
      current = Material(
        type: MaterialType.transparency,
        child: child,
      );
    }

    current = Directionality(
      textDirection: textDirection,
      child: current,
    );

    current = MediaQuery(
      data: mediaQuery,
      child: current,
    );

    // Force the logical size at the widget level as well, to make it clear
    // that the widget is laid out at exactly [logicalSize].
    return SizedBox(
      width: logicalSize.width,
      height: logicalSize.height,
      child: current,
    );
  }

  Future<Uint8List> _renderOffScreen(
    Widget widget, {
    required ui.FlutterView view,
    required Size logicalSize,
    required double pixelRatio,
    required bool waitForImages,
    required Duration initialImageDelay,
    required Duration imageRepaintDelay,
  }) async {
    final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();

    // Use the new ViewConfiguration that takes logical + physical constraints.
    final ViewConfiguration configuration = ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(logicalSize),
      physicalConstraints: BoxConstraints.tight(logicalSize * pixelRatio),
      devicePixelRatio: pixelRatio,
    );

    final RenderView renderView = RenderView(
      view: view,
      configuration: configuration,
      child: repaintBoundary,
    );

    final PipelineOwner pipelineOwner = PipelineOwner();
    final FocusManager focusManager = FocusManager();
    final BuildOwner buildOwner = BuildOwner(focusManager: focusManager);

    // Bootstrapping order as per RenderView docs: set configuration,
    // attach to PipelineOwner (via rootNode), then prepareInitialFrame.
    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> rootElement =
        RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: widget,
    ).attachToRenderTree(buildOwner);

    try {
      // Initial build & layout.
      buildOwner.buildScope(rootElement);
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      if (waitForImages) {
        // Give the image pipeline a tick to start loading.
        await Future<void>.delayed(initialImageDelay);

        // If we have any image render objects that are likely still
        // resolving at this point, give them a bit more time and repaint.
        if (_hasImagesBelow(repaintBoundary)) {
          await Future<void>.delayed(imageRepaintDelay);

          buildOwner.buildScope(rootElement);
          pipelineOwner
            ..flushLayout()
            ..flushCompositingBits()
            ..flushPaint();
        }
      }

      final ui.Image image = await repaintBoundary.toImage(
        pixelRatio: pixelRatio,
      );
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      // Avoid leaking GPU-side resources (important with Impeller/Skia).
      image.dispose();

      if (byteData == null) {
        throw StateError('Failed to convert widget to marker image bytes.');
      }

      return byteData.buffer.asUint8List();
    } finally {
      // Tear down the tree cleanly.
      buildOwner.finalizeTree();
      pipelineOwner
        ..rootNode = null
        ..dispose();
      focusManager.dispose();
    }
  }

  bool _hasImagesBelow(RenderObject root) {
    var found = false;

    void visitor(RenderObject child) {
      if (found) return;

      if (child is RenderImage) {
        // Only unresolved images should trigger a second pass.
        if (child.image == null) {
          found = true;
          return;
        }
      }

      // Also detect background images like BoxDecoration.image. We can’t
      // easily tell if they’re resolved, so we conservatively assume that
      // they might still be loading.
      if (child is RenderDecoratedBox) {
        final decoration = child.decoration;
        if (decoration is BoxDecoration && decoration.image != null) {
          found = true;
          return;
        }
      }

      child.visitChildren(visitor);
    }

    root.visitChildren(visitor);
    return found;
  }

  void _bump(Object key) {
    final icon = _cache.remove(key);
    if (icon != null) {
      // Reinsert as most recently used.
      _cache[key] = icon;
    }
  }

  void _put(Object key, MarkerIcon icon) {
    // Remove existing entry to move it to the end.
    _cache.remove(key);

    // Enforce capacity: evict least‑recently‑used (first key).
    if (_cache.length >= maxCacheEntries && _cache.isNotEmpty) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = icon;
  }
}

// Shared default renderer instance.
final MarkerIconRenderer _defaultMarkerIconRenderer = MarkerIconRenderer();

/// Extension helpers to render any widget into a Google Maps marker bitmap.
extension WidgetMarkerExtension on Widget {
  /// Convert this widget into a Google Maps [BitmapDescriptor].
  ///
  /// Typical usage:
  ///
  /// ```dart
  /// final icon = await MyMarkerWidget().toMarkerBitmap(
  ///   context,
  ///   logicalSize: const Size(80, 80),
  ///   cacheKey: buildMarkerCacheKey(
  ///     id: user.id,
  ///     logicalSize: const Size(80, 80),
  ///     pixelRatio: MediaQuery.devicePixelRatioOf(context),
  ///     brightness: Theme.of(context).brightness,
  ///   ),
  /// );
  /// ```
  Future<BitmapDescriptor> toMarkerBitmap(
    BuildContext context, {
    MarkerIconRenderer? renderer,
    Size logicalSize = const Size(96, 96),
    double? pixelRatio,
    bool waitForImages = false,
    Object? cacheKey,
    Duration? initialImageDelay,
    Duration? imageRepaintDelay,
    MapBitmapScaling bitmapScaling = MapBitmapScaling.auto,
    MarkerIconScalingMode scalingMode = MarkerIconScalingMode.logicalSize,
  }) async {
    final MarkerIconRenderer effectiveRenderer =
        renderer ?? _defaultMarkerIconRenderer;

    final icon = await effectiveRenderer.render(
      this,
      context: context,
      logicalSize: logicalSize,
      pixelRatio: pixelRatio,
      waitForImages: waitForImages,
      cacheKey: cacheKey,
      initialImageDelay: initialImageDelay,
      imageRepaintDelay: imageRepaintDelay,
    );

    return icon.toBitmapDescriptor(
      bitmapScaling: bitmapScaling,
      scalingMode: scalingMode,
    );
  }
}

/// Convenience when you don't have a [BuildContext].
Future<BitmapDescriptor> widgetToMarkerBitmap(
  Widget widget, {
  MarkerIconRenderer? renderer,
  Size logicalSize = const Size(96, 96),
  double? pixelRatio,
  bool waitForImages = false,
  Object? cacheKey,
  Duration? initialImageDelay,
  Duration? imageRepaintDelay,
  MapBitmapScaling bitmapScaling = MapBitmapScaling.auto,
  MarkerIconScalingMode scalingMode = MarkerIconScalingMode.logicalSize,
}) async {
  final MarkerIconRenderer effectiveRenderer =
      renderer ?? _defaultMarkerIconRenderer;

  final icon = await effectiveRenderer.render(
    widget,
    logicalSize: logicalSize,
    pixelRatio: pixelRatio,
    waitForImages: waitForImages,
    cacheKey: cacheKey,
    initialImageDelay: initialImageDelay,
    imageRepaintDelay: imageRepaintDelay,
  );

  return icon.toBitmapDescriptor(
    bitmapScaling: bitmapScaling,
    scalingMode: scalingMode,
  );
}

/// Helper for building a cache key that tends to "do the right thing".
///
/// You don't have to use this — it's just a convenient convention if you
/// want theme/locale/size aware caching without thinking too hard.
///
/// Example:
/// ```dart
/// cacheKey: buildMarkerCacheKey(
///   id: user.id,
///   logicalSize: const Size(80, 80),
///   pixelRatio: MediaQuery.devicePixelRatioOf(context),
///   brightness: Theme.of(context).brightness,
///   locale: Localizations.localeOf(context),
/// ),
/// ```
String buildMarkerCacheKey({
  required Object id,
  required Size logicalSize,
  required double pixelRatio,
  ui.Brightness? brightness,
  Locale? locale,
}) {
  final String brightnessPart = brightness?.name ?? 'none';
  final String localePart = locale?.toLanguageTag() ?? 'xx';
  return 'id=$id'
      '|size=${logicalSize.width}x${logicalSize.height}'
      '|dpr=$pixelRatio'
      '|brightness=$brightnessPart'
      '|locale=$localePart';
}
