import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Options that control how a rendered bitmap is interpreted on the map.
///
/// When [width], [height], and [imagePixelRatio] are all omitted,
/// [MarkerIcon.toMapBitmap] defaults to the icon's [MarkerIcon.logicalSize].
///
/// When [bitmapScaling] is [MapBitmapScaling.none], [width], [height], and
/// [imagePixelRatio] must all remain null so the bitmap is passed through
/// without extra scaling metadata.
@immutable
class MapBitmapOptions extends Equatable {
  /// Creates bitmap conversion options.
  const MapBitmapOptions({
    this.bitmapScaling = MapBitmapScaling.auto,
    this.width,
    this.height,
    this.imagePixelRatio,
    this.useRenderedPixelRatio = false,
  }) : assert(
         !useRenderedPixelRatio ||
             (width == null && height == null && imagePixelRatio == null),
         'useRenderedPixelRatio cannot be combined with width, height, or '
         'imagePixelRatio.',
       );

  /// Uses the rendered pixel ratio from the [MarkerIcon] at conversion time
  /// for pixel-perfect display.
  const MapBitmapOptions.pixelPerfect()
    : bitmapScaling = MapBitmapScaling.auto,
      width = null,
      height = null,
      imagePixelRatio = null,
      useRenderedPixelRatio = true;

  /// The scaling behavior applied by the Google Maps platform layer.
  final MapBitmapScaling bitmapScaling;

  /// The target bitmap width in logical pixels.
  final double? width;

  /// The target bitmap height in logical pixels.
  final double? height;

  /// The source image pixel ratio used by the platform when width and height
  /// are not supplied.
  final double? imagePixelRatio;

  /// Whether [MarkerIcon.toMapBitmap] should use the rendered icon pixel ratio
  /// when width, height, and [imagePixelRatio] are omitted.
  final bool useRenderedPixelRatio;

  @override
  List<Object?> get props => [
    bitmapScaling,
    width,
    height,
    imagePixelRatio,
    useRenderedPixelRatio,
  ];
}

/// Options that control how a widget is rendered off-screen.
///
/// The renderer falls back to [MarkerIconRenderer.defaultLogicalSize] when
/// [logicalSize] is omitted, and to the active [ui.FlutterView]'s device pixel
/// ratio when [pixelRatio] is omitted.
@immutable
class WidgetBitmapRenderOptions extends Equatable {
  /// Creates widget rendering options.
  const WidgetBitmapRenderOptions({
    this.logicalSize,
    this.pixelRatio,
    this.waitForImages = false,
    this.cacheKey,
    this.initialImageDelay,
    this.imageRepaintDelay,
  });

  /// The logical size to render. When null, the renderer's default is used.
  final Size? logicalSize;

  /// The pixel ratio to render at. When null, the current view DPR is used.
  final double? pixelRatio;

  /// Whether to do a second paint pass when image render objects are found.
  final bool waitForImages;

  /// Optional cache key used by [MarkerIconRenderer].
  final Object? cacheKey;

  /// Optional override for [MarkerIconRenderer.initialImageDelay].
  final Duration? initialImageDelay;

  /// Optional override for [MarkerIconRenderer.imageRepaintDelay].
  final Duration? imageRepaintDelay;

  @override
  List<Object?> get props => [
    logicalSize,
    pixelRatio,
    waitForImages,
    cacheKey,
    initialImageDelay,
    imageRepaintDelay,
  ];
}

/// Value object carrying everything about a rendered marker icon.
///
/// This is the cacheable unit. Store instances of this class in your own
/// state management to implement "render once, reuse everywhere" patterns.
@immutable
class MarkerIcon {
  /// Creates an icon from rendered PNG [bytes], [logicalSize], and
  /// [pixelRatio].
  const MarkerIcon({
    required this.bytes,
    required this.logicalSize,
    required this.pixelRatio,
  });

  /// PNG bytes of the rendered widget.
  final Uint8List bytes;

  /// The logical size the widget was rendered at.
  final Size logicalSize;

  /// The pixel ratio used during rendering.
  final double pixelRatio;

  /// The size of the encoded PNG in bytes.
  int get sizeInBytes => bytes.lengthInBytes;

  /// Converts this icon to a [BytesMapBitmap].
  ///
  /// When [options] does not specify [MapBitmapOptions.width],
  /// [MapBitmapOptions.height], or [MapBitmapOptions.imagePixelRatio], the icon
  /// defaults to [logicalSize] for stable on-map sizing.
  ///
  /// When [MapBitmapOptions.bitmapScaling] is [MapBitmapScaling.none], no size
  /// or pixel ratio metadata is attached and the raw encoded bytes are passed
  /// through.
  ///
  /// Throws [StateError] when the icon bytes are empty or the supplied bitmap
  /// options are invalid.
  BytesMapBitmap toMapBitmap({
    MapBitmapOptions options = const MapBitmapOptions(),
  }) {
    _validateBitmapOptions(options);

    final double? resolvedImagePixelRatio = options.useRenderedPixelRatio
        ? pixelRatio
        : options.imagePixelRatio;

    final bool hasExplicitBitmapMetadata =
        options.width != null ||
        options.height != null ||
        resolvedImagePixelRatio != null;

    if (!hasExplicitBitmapMetadata &&
        options.bitmapScaling == MapBitmapScaling.none) {
      return BytesMapBitmap(bytes, bitmapScaling: MapBitmapScaling.none);
    }

    if (!hasExplicitBitmapMetadata) {
      if (logicalSize.width <= 0 || logicalSize.height <= 0) {
        throw StateError(
          'MarkerIcon.logicalSize must be > 0 in both dimensions. '
          'Got $logicalSize.',
        );
      }

      return BytesMapBitmap(
        bytes,
        width: logicalSize.width,
        height: logicalSize.height,
        bitmapScaling: options.bitmapScaling,
      );
    }

    return BytesMapBitmap(
      bytes,
      bitmapScaling: options.bitmapScaling,
      width: options.width,
      height: options.height,
      imagePixelRatio: resolvedImagePixelRatio,
    );
  }

  /// Converts this icon to a [BitmapDescriptor].
  ///
  /// This is a convenience wrapper around [toMapBitmap].
  BitmapDescriptor toBitmapDescriptor({
    MapBitmapOptions options = const MapBitmapOptions(),
  }) => toMapBitmap(options: options);

  /// Converts this icon to a raw [BytesMapBitmap] suitable for a
  /// [GroundOverlay].
  ///
  /// This is equivalent to calling:
  /// `toMapBitmap(options: const MapBitmapOptions(bitmapScaling: MapBitmapScaling.none))`.
  BytesMapBitmap toGroundOverlayBitmap() => toMapBitmap(
    options: const MapBitmapOptions(bitmapScaling: MapBitmapScaling.none),
  );

  /// Wraps this icon as a [BitmapGlyph] for use inside a [PinConfig].
  BitmapGlyph toBitmapGlyph({
    MapBitmapOptions options = const MapBitmapOptions(),
  }) => BitmapGlyph(bitmap: toMapBitmap(options: options));

  /// Converts this icon to a [PinConfig] with a rendered glyph.
  ///
  /// Warning: upstream documents an iOS issue where a [PinConfig] may fail to
  /// render. See https://issuetracker.google.com/issues/370536110.
  PinConfig toPinConfig({
    Color? backgroundColor,
    Color? borderColor,
    MapBitmapOptions options = const MapBitmapOptions(),
  }) {
    return PinConfig(
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      glyph: toBitmapGlyph(options: options),
    );
  }

  /// Builds a classic [Marker] using this icon.
  Marker toMarker({
    required Marker base,
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) => base.copyWith(iconParam: toBitmapDescriptor(options: bitmapOptions));

  /// Builds an [AdvancedMarker] using this icon.
  ///
  /// Advanced markers require `GoogleMap.markerType` to be
  /// `GoogleMapMarkerType.advancedMarker`. They also require a `mapId`, and on
  /// web the Google Maps JavaScript `marker` library must be loaded.
  AdvancedMarker toAdvancedMarker({
    required AdvancedMarker base,
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) => base.copyWith(iconParam: toBitmapDescriptor(options: bitmapOptions));

  /// Builds an [AdvancedMarker] with a [PinConfig] glyph in one call.
  ///
  /// This combines [toPinConfig] and [AdvancedMarker] construction so the
  /// widget-to-pin-marker flow is a single step.
  AdvancedMarker toAdvancedPinMarker({
    required AdvancedMarker base,
    Color? backgroundColor,
    Color? borderColor,
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) => base.copyWith(
    iconParam: toPinConfig(
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      options: bitmapOptions,
    ),
  );

  void _validateBitmapOptions(MapBitmapOptions options) {
    if (bytes.isEmpty) {
      throw StateError('MarkerIcon.bytes must not be empty.');
    }

    if (options.bitmapScaling == MapBitmapScaling.none &&
        (options.width != null ||
            options.height != null ||
            options.imagePixelRatio != null ||
            options.useRenderedPixelRatio)) {
      throw StateError(
        'MapBitmapScaling.none cannot be combined with width, height, or '
        'imagePixelRatio. Remove those values or use MapBitmapScaling.auto.',
      );
    }

    if (options.width != null && options.width! <= 0) {
      throw StateError(
        'MapBitmapOptions.width must be > 0 when provided. '
        'Got ${options.width}.',
      );
    }

    if (options.height != null && options.height! <= 0) {
      throw StateError(
        'MapBitmapOptions.height must be > 0 when provided. '
        'Got ${options.height}.',
      );
    }

    if (options.imagePixelRatio != null && options.imagePixelRatio! <= 0) {
      throw StateError(
        'MapBitmapOptions.imagePixelRatio must be > 0 when provided. '
        'Got ${options.imagePixelRatio}.',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MarkerIcon &&
        listEquals(bytes, other.bytes) &&
        logicalSize == other.logicalSize &&
        pixelRatio == other.pixelRatio;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(bytes), logicalSize, pixelRatio);
}

/// Renders arbitrary widgets into PNG bytes off-screen.
///
/// This is where the RenderView and PipelineOwner work happens, so the public
/// API stays stable if Flutter tweaks internals again.
class MarkerIconRenderer {
  /// Creates a renderer that turns widgets into marker icons.
  MarkerIconRenderer({
    this.defaultLogicalSize = const Size(96, 96),
    this.enableCaching = true,
    this.maxCacheEntries = 64,
    this.maxCacheBytes = 50 * 1024 * 1024,
    this.initialImageDelay = const Duration(milliseconds: 16),
    this.imageRepaintDelay = const Duration(milliseconds: 200),
  }) : assert(maxCacheEntries > 0, 'maxCacheEntries must be > 0');

  /// The default marker size used when [render] is called without a logical
  /// size.
  final Size defaultLogicalSize;

  /// Whether internal LRU caching is enabled.
  final bool enableCaching;

  /// The maximum number of cached entries before LRU eviction.
  final int maxCacheEntries;

  /// The maximum total cache size in bytes.
  ///
  /// Set to null to disable memory-based eviction.
  final int? maxCacheBytes;

  /// Delay before checking whether images might still be loading.
  final Duration initialImageDelay;

  /// Extra delay before repainting after images were detected.
  final Duration imageRepaintDelay;

  /// Current number of cached entries.
  int get cacheSize => _cache.length;

  /// Current cache size in bytes.
  int get cacheSizeInBytes => _currentCacheBytes;

  final LinkedHashMap<Object, MarkerIcon> _cache =
      LinkedHashMap<Object, MarkerIcon>();
  int _currentCacheBytes = 0;
  final Map<Object, _PendingRender> _pending = <Object, _PendingRender>{};
  int _globalCacheGeneration = 0;
  final Map<Object, int> _keyGenerations = <Object, int>{};

  /// Renders [widget] into a [MarkerIcon].
  ///
  /// If [context] is supplied, the render tree inherits that context's
  /// `MediaQuery`, theme, directionality, localizations, and asset bundle.
  Future<MarkerIcon> render(
    Widget widget, {
    BuildContext? context,
    WidgetBitmapRenderOptions options = const WidgetBitmapRenderOptions(),
  }) async {
    final Object? key = enableCaching ? options.cacheKey : null;
    final int? cacheToken = key != null ? _cacheTokenFor(key) : null;

    if (key != null) {
      final MarkerIcon? cached = _cache[key];
      if (cached != null) {
        _bump(key);
        return cached;
      }

      final _PendingRender? pending = _pending[key];
      if (pending != null && pending.cacheToken == cacheToken) {
        return pending.future;
      }
    }

    final ui.FlutterView view = _resolveView(context);
    final Size size = options.logicalSize ?? defaultLogicalSize;

    if (size.width <= 0 || size.height <= 0) {
      throw ArgumentError.value(
        size,
        'options.logicalSize',
        'logicalSize.width and logicalSize.height must both be > 0.',
      );
    }

    if (options.pixelRatio != null && options.pixelRatio! <= 0) {
      throw ArgumentError.value(
        options.pixelRatio,
        'options.pixelRatio',
        'pixelRatio must be > 0 when provided.',
      );
    }

    final double dpr = options.pixelRatio ?? view.devicePixelRatio;

    final Future<MarkerIcon> renderFuture = _doRender(
      widget,
      context: context,
      view: view,
      size: size,
      dpr: dpr,
      waitForImages: options.waitForImages,
      initialImageDelay: options.initialImageDelay ?? initialImageDelay,
      imageRepaintDelay: options.imageRepaintDelay ?? imageRepaintDelay,
    );

    if (key != null && cacheToken != null) {
      _pending[key] = _PendingRender(
        future: renderFuture,
        cacheToken: cacheToken,
      );
    }

    try {
      final MarkerIcon icon = await renderFuture;

      if (key != null &&
          cacheToken != null &&
          cacheToken == _cacheTokenFor(key)) {
        _put(key, icon);
      }

      return icon;
    } finally {
      if (key != null) {
        final _PendingRender? pending = _pending[key];
        if (pending != null &&
            pending.cacheToken == cacheToken &&
            identical(pending.future, renderFuture)) {
          _pending.remove(key);
        }
      }
    }
  }

  /// Clears the internal cache completely.
  void clearCache() {
    _cache.clear();
    _currentCacheBytes = 0;
    _globalCacheGeneration += 1;
  }

  /// Removes one cached entry by [key].
  void removeFromCache(Object key) {
    final MarkerIcon? removed = _cache.remove(key);
    if (removed != null) {
      _currentCacheBytes -= removed.sizeInBytes;
    }
    _keyGenerations[key] = (_keyGenerations[key] ?? 0) + 1;
  }

  /// Returns whether [key] is currently cached.
  bool isCached(Object key) => _cache.containsKey(key);

  /// Returns a cached icon without updating LRU order.
  MarkerIcon? peekCache(Object key) => _cache[key];

  Future<MarkerIcon> _doRender(
    Widget widget, {
    required BuildContext? context,
    required ui.FlutterView view,
    required Size size,
    required double dpr,
    required bool waitForImages,
    required Duration initialImageDelay,
    required Duration imageRepaintDelay,
  }) async {
    final Widget wrapped = _wrapWidget(
      widget,
      context: context,
      view: view,
      logicalSize: size,
      devicePixelRatio: dpr,
    );

    final Uint8List bytes = await _renderOffScreen(
      wrapped,
      view: view,
      logicalSize: size,
      pixelRatio: dpr,
      waitForImages: waitForImages,
      initialImageDelay: initialImageDelay,
      imageRepaintDelay: imageRepaintDelay,
    );

    return MarkerIcon(bytes: bytes, logicalSize: size, pixelRatio: dpr);
  }

  ui.FlutterView _resolveView(BuildContext? context) {
    if (context != null) {
      final ui.FlutterView? view = View.maybeOf(context);
      if (view != null) {
        return view;
      }
    }

    final ui.PlatformDispatcher dispatcher =
        WidgetsBinding.instance.platformDispatcher;

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

    final MediaQueryData mediaQuery = baseMediaQuery.copyWith(
      size: logicalSize,
      devicePixelRatio: devicePixelRatio,
    );

    final TextDirection textDirection = context != null
        ? (Directionality.maybeOf(context) ?? TextDirection.ltr)
        : TextDirection.ltr;

    Widget current;
    if (context != null) {
      current = InheritedTheme.captureAll(
        context,
        Material(type: MaterialType.transparency, child: child),
      );
      if (Localizations.maybeLocaleOf(context) != null) {
        current = Localizations.override(context: context, child: current);
      }
      current = DefaultAssetBundle(
        bundle: DefaultAssetBundle.of(context),
        child: current,
      );
    } else {
      current = Material(type: MaterialType.transparency, child: child);
    }

    current = Directionality(textDirection: textDirection, child: current);
    current = MediaQuery(data: mediaQuery, child: current);

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

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> rootElement =
        RenderObjectToWidgetAdapter<RenderBox>(
          container: repaintBoundary,
          child: widget,
        ).attachToRenderTree(buildOwner);

    try {
      buildOwner.buildScope(rootElement);
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      if (waitForImages) {
        await Future<void>.delayed(initialImageDelay);

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

      image.dispose();

      if (byteData == null) {
        throw StateError('Failed to convert widget to marker image bytes.');
      }

      return byteData.buffer.asUint8List();
    } finally {
      buildOwner.finalizeTree();
      pipelineOwner.rootNode = null;
      renderView.dispose();
      pipelineOwner.dispose();
      focusManager.dispose();
    }
  }

  bool _hasImagesBelow(RenderObject root) {
    var found = false;

    void visitor(RenderObject child) {
      if (found) {
        return;
      }

      if (child is RenderImage && child.image == null) {
        found = true;
        return;
      }

      if (child is RenderDecoratedBox) {
        final Decoration decoration = child.decoration;
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
    final MarkerIcon? icon = _cache.remove(key);
    if (icon != null) {
      _cache[key] = icon;
    }
  }

  int _cacheTokenFor(Object key) =>
      Object.hash(_globalCacheGeneration, _keyGenerations[key] ?? 0);

  void _put(Object key, MarkerIcon icon) {
    final MarkerIcon? existing = _cache.remove(key);
    if (existing != null) {
      _currentCacheBytes -= existing.sizeInBytes;
    }

    final int iconBytes = icon.sizeInBytes;

    if (maxCacheBytes != null && iconBytes > maxCacheBytes!) {
      return;
    }

    if (maxCacheBytes != null) {
      while (_currentCacheBytes + iconBytes > maxCacheBytes! &&
          _cache.isNotEmpty) {
        final Object oldestKey = _cache.keys.first;
        final MarkerIcon? evicted = _cache.remove(oldestKey);
        if (evicted != null) {
          _currentCacheBytes -= evicted.sizeInBytes;
        }
      }
    }

    while (_cache.length >= maxCacheEntries && _cache.isNotEmpty) {
      final Object oldestKey = _cache.keys.first;
      final MarkerIcon? evicted = _cache.remove(oldestKey);
      if (evicted != null) {
        _currentCacheBytes -= evicted.sizeInBytes;
      }
    }

    _cache[key] = icon;
    _currentCacheBytes += iconBytes;
  }
}

class _PendingRender {
  const _PendingRender({required this.future, required this.cacheToken});

  final Future<MarkerIcon> future;
  final int cacheToken;
}

/// The shared renderer used by the widget extensions when no explicit
/// [MarkerIconRenderer] is provided.
///
/// Expose this so callers can clear its cache on logout or theme changes,
/// inspect cache size, or pre-render shared assets.
final MarkerIconRenderer defaultMarkerIconRenderer = MarkerIconRenderer();

Future<MarkerIcon> _renderMarkerIcon(
  Widget widget, {
  BuildContext? context,
  MarkerIconRenderer? renderer,
  WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
}) {
  final MarkerIconRenderer effectiveRenderer =
      renderer ?? defaultMarkerIconRenderer;
  return effectiveRenderer.render(
    widget,
    context: context,
    options: renderOptions,
  );
}

/// Extension helpers that render any widget into Google Maps bitmap and marker
/// types.
extension WidgetMarkerExtension on Widget {
  /// Converts this widget to a [BitmapDescriptor].
  Future<BitmapDescriptor> toBitmapDescriptor({
    BuildContext? context,
    MarkerIconRenderer? renderer,
    WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toBitmapDescriptor(options: bitmapOptions);
  }

  /// Converts this widget to a [BytesMapBitmap].
  Future<BytesMapBitmap> toMapBitmap({
    BuildContext? context,
    MarkerIconRenderer? renderer,
    WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toMapBitmap(options: bitmapOptions);
  }

  /// Converts this widget to a raw [BytesMapBitmap] suitable for a
  /// [GroundOverlay].
  Future<BytesMapBitmap> toGroundOverlayBitmap({
    BuildContext? context,
    MarkerIconRenderer? renderer,
    WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
  }) async {
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toGroundOverlayBitmap();
  }

  /// Converts this widget to a [BitmapGlyph].
  Future<BitmapGlyph> toBitmapGlyph({
    BuildContext? context,
    MarkerIconRenderer? renderer,
    WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toBitmapGlyph(options: bitmapOptions);
  }

  /// Converts this widget to a [PinConfig] with a rendered glyph.
  ///
  /// Warning: upstream documents an iOS issue where a [PinConfig] may fail to
  /// render. See https://issuetracker.google.com/issues/370536110.
  Future<PinConfig> toPinConfig({
    BuildContext? context,
    Color? backgroundColor,
    Color? borderColor,
    MarkerIconRenderer? renderer,
    WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toPinConfig(
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      options: bitmapOptions,
    );
  }

  /// Converts this widget to a cacheable [MarkerIcon].
  Future<MarkerIcon> toMarkerIcon({
    BuildContext? context,
    MarkerIconRenderer? renderer,
    WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
  }) {
    return _renderMarkerIcon(
      this,
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
  }

  /// Renders this widget and immediately builds a classic [Marker].
  Future<Marker> toMarker({
    required Marker base,
    BuildContext? context,
    MarkerIconRenderer? renderer,
    WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toMarker(base: base, bitmapOptions: bitmapOptions);
  }

  /// Renders this widget and immediately builds an [AdvancedMarker].
  Future<AdvancedMarker> toAdvancedMarker({
    required AdvancedMarker base,
    BuildContext? context,
    MarkerIconRenderer? renderer,
    WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toAdvancedMarker(base: base, bitmapOptions: bitmapOptions);
  }

  /// Renders this widget and builds an [AdvancedMarker] with a [PinConfig]
  /// glyph in one call.
  ///
  /// Warning: upstream documents an iOS issue where a [PinConfig] may fail to
  /// render. See https://issuetracker.google.com/issues/370536110.
  Future<AdvancedMarker> toAdvancedPinMarker({
    required AdvancedMarker base,
    BuildContext? context,
    Color? backgroundColor,
    Color? borderColor,
    MarkerIconRenderer? renderer,
    WidgetBitmapRenderOptions renderOptions = const WidgetBitmapRenderOptions(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toAdvancedPinMarker(
      base: base,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      bitmapOptions: bitmapOptions,
    );
  }
}

/// Builds a marker cache key that captures the common visual inputs.
///
/// Use [extra] for any additional state that changes the rendered output, such
/// as selection, status, or avatar version.
String buildMarkerCacheKey({
  required Object id,
  required Size logicalSize,
  required double pixelRatio,
  ui.Brightness? brightness,
  Locale? locale,
  Object? extra,
}) {
  final String brightnessPart = brightness?.name ?? 'none';
  final String localePart = locale?.toLanguageTag() ?? 'xx';
  final String extraPart = extra?.toString() ?? 'none';
  return 'id=$id'
      '|size=${logicalSize.width}x${logicalSize.height}'
      '|dpr=$pixelRatio'
      '|brightness=$brightnessPart'
      '|locale=$localePart'
      '|extra=$extraPart';
}

/// Builds a cache key for cluster markers or badges.
String buildClusterCacheKey({
  required int count,
  required Size logicalSize,
  required double pixelRatio,
  ui.Brightness? brightness,
  Locale? locale,
  Object? extra,
}) {
  final String brightnessPart = brightness?.name ?? 'none';
  final String localePart = locale?.toLanguageTag() ?? 'xx';
  final String extraPart = extra?.toString() ?? 'none';
  return 'count=$count'
      '|size=${logicalSize.width}x${logicalSize.height}'
      '|dpr=$pixelRatio'
      '|brightness=$brightnessPart'
      '|locale=$localePart'
      '|extra=$extraPart';
}
