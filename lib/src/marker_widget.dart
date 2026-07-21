import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

bool _isPositiveFinite(double value) => value.isFinite && value > 0;

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

  /// Cached descriptors per icon instance so repeated conversions hand the
  /// map identical objects. Entries are garbage collected with the icon.
  static final Expando<Map<MapBitmapOptions, BytesMapBitmap>> _mapBitmapCache =
      Expando<Map<MapBitmapOptions, BytesMapBitmap>>('MarkerIcon.toMapBitmap');

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
  /// Repeated calls with equal [options] on the same icon instance return the
  /// identical [BytesMapBitmap] object. Google Maps compares descriptors by
  /// identity, so this keeps rebuilt [Marker]s equal to their previous
  /// versions and avoids redundant platform-side icon updates.
  ///
  /// Throws [StateError] when the icon bytes are empty or the supplied bitmap
  /// options are invalid.
  BytesMapBitmap toMapBitmap({
    MapBitmapOptions options = const MapBitmapOptions(),
  }) {
    _validateBitmapOptions(options);

    final Map<MapBitmapOptions, BytesMapBitmap> cache =
        _mapBitmapCache[this] ??= <MapBitmapOptions, BytesMapBitmap>{};
    return cache.putIfAbsent(options, () => _createMapBitmap(options));
  }

  BytesMapBitmap _createMapBitmap(MapBitmapOptions options) {
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
      if (!_isPositiveFinite(logicalSize.width) ||
          !_isPositiveFinite(logicalSize.height)) {
        throw StateError(
          'MarkerIcon.logicalSize must be > 0 and finite in both dimensions. '
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
  ///
  /// Throws [ArgumentError] when [base] is an [AdvancedMarker]. Advanced
  /// markers extend [Marker], so they would otherwise flow through the
  /// classic marker pipeline silently; use [toAdvancedMarker] or
  /// [toAdvancedPinMarker] for them instead.
  Marker toMarker({
    required Marker base,
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) {
    if (base is AdvancedMarker) {
      throw ArgumentError.value(
        base,
        'base',
        'AdvancedMarker cannot go through toMarker; use toAdvancedMarker or '
            'toAdvancedPinMarker so it is delivered to the map as an '
            'advanced marker.',
      );
    }
    return base.copyWith(iconParam: toBitmapDescriptor(options: bitmapOptions));
  }

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

    if (options.width != null && !_isPositiveFinite(options.width!)) {
      throw StateError(
        'MapBitmapOptions.width must be > 0 and finite when provided. '
        'Got ${options.width}.',
      );
    }

    if (options.height != null && !_isPositiveFinite(options.height!)) {
      throw StateError(
        'MapBitmapOptions.height must be > 0 and finite when provided. '
        'Got ${options.height}.',
      );
    }

    if (options.imagePixelRatio != null &&
        !_isPositiveFinite(options.imagePixelRatio!)) {
      throw StateError(
        'MapBitmapOptions.imagePixelRatio must be > 0 and finite when '
        'provided. Got ${options.imagePixelRatio}.',
      );
    }

    if (options.useRenderedPixelRatio && !_isPositiveFinite(pixelRatio)) {
      throw StateError(
        'MarkerIcon.pixelRatio must be > 0 and finite to use '
        'MapBitmapOptions.useRenderedPixelRatio. Got $pixelRatio.',
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
  ///
  /// Throws [ArgumentError] when [defaultLogicalSize] is not positive and
  /// finite, [maxCacheEntries] is not positive, [maxCacheBytes] is provided
  /// but not positive, or either image delay is negative.
  MarkerIconRenderer({
    this.defaultLogicalSize = const Size(96, 96),
    this.enableCaching = true,
    this.maxCacheEntries = 64,
    this.maxCacheBytes = 50 * 1024 * 1024,
    this.maxConcurrentRenders = 3,
    this.maxRasterPixels = 4 * 1024 * 1024,
    this.initialImageDelay = const Duration(milliseconds: 16),
    this.imageRepaintDelay = const Duration(milliseconds: 200),
  }) {
    if (!_isPositiveFinite(defaultLogicalSize.width) ||
        !_isPositiveFinite(defaultLogicalSize.height)) {
      throw ArgumentError.value(
        defaultLogicalSize,
        'defaultLogicalSize',
        'width and height must both be > 0 and finite.',
      );
    }
    if (maxCacheEntries <= 0) {
      throw ArgumentError.value(
        maxCacheEntries,
        'maxCacheEntries',
        'must be > 0.',
      );
    }
    if (maxCacheBytes != null && maxCacheBytes! <= 0) {
      throw ArgumentError.value(
        maxCacheBytes,
        'maxCacheBytes',
        'must be > 0 when provided.',
      );
    }
    if (maxConcurrentRenders != null && maxConcurrentRenders! <= 0) {
      throw ArgumentError.value(
        maxConcurrentRenders,
        'maxConcurrentRenders',
        'must be > 0 when provided.',
      );
    }
    if (maxRasterPixels != null && maxRasterPixels! <= 0) {
      throw ArgumentError.value(
        maxRasterPixels,
        'maxRasterPixels',
        'must be > 0 when provided.',
      );
    }
    if (initialImageDelay < Duration.zero) {
      throw ArgumentError.value(
        initialImageDelay,
        'initialImageDelay',
        'must not be negative.',
      );
    }
    if (imageRepaintDelay < Duration.zero) {
      throw ArgumentError.value(
        imageRepaintDelay,
        'imageRepaintDelay',
        'must not be negative.',
      );
    }
  }

  /// The default marker size used when [render] is called without a logical
  /// size.
  final Size defaultLogicalSize;

  /// Whether internal LRU caching is enabled.
  final bool enableCaching;

  /// The maximum number of cached entries before LRU eviction.
  final int maxCacheEntries;

  /// The maximum total cache size in bytes.
  ///
  /// This measures the encoded PNG bytes held by the cache, not the decoded
  /// bitmap memory the platform map allocates for the icons. Set to null to
  /// disable memory-based eviction. Icons larger than the limit are returned
  /// to the caller but silently skipped by the cache.
  final int? maxCacheBytes;

  /// The maximum number of off-screen render trees allowed to exist at the
  /// same time.
  ///
  /// Additional [render] calls wait for a slot in FIFO order. Every detached
  /// render tree holds a widget tree, layers, and an uncompressed image, so
  /// bounding concurrency bounds the transient memory of batch renders (for
  /// example, prewarming 100 marker icons at once). Set to null to start all
  /// renders immediately.
  final int? maxConcurrentRenders;

  /// The maximum number of physical pixels a single render may rasterize,
  /// computed as logical width times height times the pixel ratio squared.
  ///
  /// Renders above the budget throw [ArgumentError] instead of accidentally
  /// allocating enormous bitmaps. The default of 4194304 equals a 2048 x
  /// 2048 physical bitmap. Set to null to disable the check.
  final int? maxRasterPixels;

  /// Delay before checking whether images might still be loading.
  final Duration initialImageDelay;

  /// Extra delay before repainting after images were detected.
  final Duration imageRepaintDelay;

  /// Current number of cached entries.
  ///
  /// Each cached combination of cache key, logical size, and pixel ratio
  /// counts as one entry.
  int get cacheSize => _cache.length;

  /// Current cache size in bytes.
  int get cacheSizeInBytes => _currentCacheBytes;

  final LinkedHashMap<_ResolvedCacheKey, MarkerIcon> _cache =
      LinkedHashMap<_ResolvedCacheKey, MarkerIcon>();
  int _currentCacheBytes = 0;
  final Map<_ResolvedCacheKey, _PendingRender> _pending =
      <_ResolvedCacheKey, _PendingRender>{};
  int _activeRenders = 0;
  final Queue<Completer<void>> _renderQueue = Queue<Completer<void>>();

  /// Renders [widget] into a [MarkerIcon].
  ///
  /// If [context] is supplied, the render tree inherits that context's
  /// `MediaQuery`, theme, directionality, localizations, and asset bundle.
  ///
  /// Cached entries are looked up by [WidgetBitmapRenderOptions.cacheKey]
  /// combined with the resolved logical size and pixel ratio, so reusing one
  /// cache key at a different size or pixel ratio always renders a fresh
  /// icon. Content inputs that change the rendered output (theme brightness,
  /// locale, selection state, ...) still belong in the cache key itself; see
  /// [buildMarkerCacheKey].
  Future<MarkerIcon> render(
    Widget widget, {
    BuildContext? context,
    WidgetBitmapRenderOptions options = const WidgetBitmapRenderOptions(),
  }) async {
    final ui.FlutterView view = _resolveView(context);
    final Size size = options.logicalSize ?? defaultLogicalSize;

    if (!_isPositiveFinite(size.width) || !_isPositiveFinite(size.height)) {
      throw ArgumentError.value(
        size,
        'options.logicalSize',
        'logicalSize.width and logicalSize.height must both be > 0 and '
            'finite.',
      );
    }

    if (options.pixelRatio != null && !_isPositiveFinite(options.pixelRatio!)) {
      throw ArgumentError.value(
        options.pixelRatio,
        'options.pixelRatio',
        'pixelRatio must be > 0 and finite when provided.',
      );
    }

    final double dpr = options.pixelRatio ?? view.devicePixelRatio;

    final int? rasterBudget = maxRasterPixels;
    if (rasterBudget != null) {
      final double rasterPixels = (size.width * dpr) * (size.height * dpr);
      if (rasterPixels > rasterBudget) {
        throw ArgumentError.value(
          size,
          'options.logicalSize',
          'Rendering ${size.width} x ${size.height} at pixel ratio $dpr '
              'rasterizes ${rasterPixels.ceil()} physical pixels, above '
              'maxRasterPixels ($rasterBudget). Reduce the marker size or '
              'pixel ratio, or raise/disable maxRasterPixels.',
        );
      }
    }

    final Object? cacheKey = enableCaching ? options.cacheKey : null;
    final _ResolvedCacheKey? key = cacheKey == null
        ? null
        : (cacheKey, size, dpr);

    if (key != null) {
      final MarkerIcon? cached = _cache[key];
      if (cached != null) {
        _bump(key);
        return cached;
      }

      final _PendingRender? pending = _pending[key];
      if (pending != null && !pending.stale) {
        return pending.future;
      }
    }

    final Future<MarkerIcon> renderFuture = _withRenderSlot(
      () => _doRender(
        widget,
        context: context,
        view: view,
        size: size,
        dpr: dpr,
        waitForImages: options.waitForImages,
        initialImageDelay: options.initialImageDelay ?? initialImageDelay,
        imageRepaintDelay: options.imageRepaintDelay ?? imageRepaintDelay,
      ),
    );

    _PendingRender? pendingEntry;
    if (key != null) {
      pendingEntry = _PendingRender(renderFuture);
      _pending[key] = pendingEntry;
    }

    try {
      final MarkerIcon icon = await renderFuture;

      if (key != null && !pendingEntry!.stale) {
        _put(key, icon);
      }

      return icon;
    } finally {
      if (key != null && identical(_pending[key], pendingEntry)) {
        _pending.remove(key);
      }
    }
  }

  /// Clears the internal cache completely.
  ///
  /// In-flight renders keep completing and their futures still resolve, but
  /// they no longer repopulate the cache.
  void clearCache() {
    _cache.clear();
    _currentCacheBytes = 0;
    for (final _PendingRender pending in _pending.values) {
      pending.stale = true;
    }
  }

  /// Removes every cached variant of [key], across all sizes and pixel
  /// ratios.
  ///
  /// In-flight renders for [key] keep completing, but they no longer
  /// repopulate the cache.
  void removeFromCache(Object key) {
    _cache.removeWhere((_ResolvedCacheKey resolvedKey, MarkerIcon icon) {
      if (resolvedKey.$1 == key) {
        _currentCacheBytes -= icon.sizeInBytes;
        return true;
      }
      return false;
    });

    for (final MapEntry<_ResolvedCacheKey, _PendingRender> entry
        in _pending.entries) {
      if (entry.key.$1 == key) {
        entry.value.stale = true;
      }
    }
  }

  /// Returns whether any variant of [key] is currently cached.
  bool isCached(Object key) =>
      _cache.keys.any((_ResolvedCacheKey resolvedKey) => resolvedKey.$1 == key);

  /// Returns the most recently used cached variant of [key] without updating
  /// LRU order.
  MarkerIcon? peekCache(Object key) {
    MarkerIcon? match;
    for (final MapEntry<_ResolvedCacheKey, MarkerIcon> entry
        in _cache.entries) {
      if (entry.key.$1 == key) {
        match = entry.value;
      }
    }
    return match;
  }

  /// Runs [startRender] inside the FIFO concurrency gate.
  ///
  /// New arrivals queue whenever a limit is set and either all slots are
  /// taken or earlier callers are already waiting, so waiters are served
  /// strictly in order.
  Future<MarkerIcon> _withRenderSlot(
    Future<MarkerIcon> Function() startRender,
  ) async {
    final int? limit = maxConcurrentRenders;
    if (limit == null) {
      return startRender();
    }

    if (_activeRenders >= limit || _renderQueue.isNotEmpty) {
      final Completer<void> slot = Completer<void>();
      _renderQueue.add(slot);
      await slot.future;
    }

    _activeRenders += 1;
    try {
      return await startRender();
    } finally {
      _activeRenders -= 1;
      if (_renderQueue.isNotEmpty) {
        _renderQueue.removeFirst().complete();
      }
    }
  }

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

    final Iterable<ui.FlutterView> views = dispatcher.views;
    if (views.length == 1) {
      return views.first;
    }

    if (views.isEmpty) {
      throw StateError(
        'No FlutterView is available. Ensure WidgetsFlutterBinding is '
        'initialized before calling MarkerIconRenderer.render.',
      );
    }

    throw StateError(
      'Multiple FlutterViews are available and none is the implicit view. '
      'Pass a BuildContext to render so the renderer can resolve the view '
      'the marker belongs to.',
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

    // Screen obstructions (notches, keyboards, hinges) belong to the source
    // screen, not to an off-screen marker; accessibility data (text scaling,
    // brightness, bold text) is kept.
    final MediaQueryData mediaQuery = baseMediaQuery.copyWith(
      size: logicalSize,
      devicePixelRatio: devicePixelRatio,
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      viewInsets: EdgeInsets.zero,
      systemGestureInsets: EdgeInsets.zero,
      displayFeatures: const <ui.DisplayFeature>[],
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
    final PipelineOwner pipelineOwner = PipelineOwner();
    final FocusManager focusManager = FocusManager();
    final BuildOwner buildOwner = BuildOwner(focusManager: focusManager);

    RenderView? renderView;
    RenderObjectToWidgetElement<RenderBox>? rootElement;

    try {
      final ViewConfiguration configuration = ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(logicalSize),
        physicalConstraints: BoxConstraints.tight(logicalSize * pixelRatio),
        devicePixelRatio: pixelRatio,
      );

      renderView = RenderView(
        view: view,
        configuration: configuration,
        child: repaintBoundary,
      );

      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: widget,
      ).attachToRenderTree(buildOwner);

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

      try {
        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (byteData == null) {
          throw StateError('Failed to convert widget to marker image bytes.');
        }

        return Uint8List.sublistView(byteData);
      } finally {
        image.dispose();
      }
    } finally {
      _tearDownRenderTree(
        buildOwner: buildOwner,
        pipelineOwner: pipelineOwner,
        focusManager: focusManager,
        repaintBoundary: repaintBoundary,
        renderView: renderView,
        rootElement: rootElement,
      );
    }
  }

  void _tearDownRenderTree({
    required BuildOwner buildOwner,
    required PipelineOwner pipelineOwner,
    required FocusManager focusManager,
    required RenderRepaintBoundary repaintBoundary,
    required RenderView? renderView,
    required RenderObjectToWidgetElement<RenderBox>? rootElement,
  }) {
    try {
      if (rootElement != null) {
        // Re-attaching with a null child only schedules the removal; the
        // buildScope call executes it, deactivating every descendant so
        // finalizeTree can unmount them and run State.dispose.
        RenderObjectToWidgetAdapter<RenderBox>(
          container: repaintBoundary,
        ).attachToRenderTree(buildOwner, rootElement);
        buildOwner.buildScope(rootElement);
      }
      buildOwner.finalizeTree();
    } finally {
      pipelineOwner.rootNode = null;
      try {
        renderView?.child = null;
        renderView?.dispose();
      } finally {
        try {
          repaintBoundary.dispose();
        } finally {
          try {
            pipelineOwner.dispose();
          } finally {
            focusManager.dispose();
          }
        }
      }
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

  void _bump(_ResolvedCacheKey key) {
    final MarkerIcon? icon = _cache.remove(key);
    if (icon != null) {
      _cache[key] = icon;
    }
  }

  void _put(_ResolvedCacheKey key, MarkerIcon icon) {
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
        final _ResolvedCacheKey oldestKey = _cache.keys.first;
        final MarkerIcon? evicted = _cache.remove(oldestKey);
        if (evicted != null) {
          _currentCacheBytes -= evicted.sizeInBytes;
        }
      }
    }

    while (_cache.length >= maxCacheEntries && _cache.isNotEmpty) {
      final _ResolvedCacheKey oldestKey = _cache.keys.first;
      final MarkerIcon? evicted = _cache.remove(oldestKey);
      if (evicted != null) {
        _currentCacheBytes -= evicted.sizeInBytes;
      }
    }

    _cache[key] = icon;
    _currentCacheBytes += iconBytes;
  }
}

/// Cache identity: the caller's key combined with the resolved render
/// geometry, so one key can never return an icon rendered at another size or
/// pixel ratio.
typedef _ResolvedCacheKey = (Object cacheKey, Size logicalSize, double dpr);

class _PendingRender {
  _PendingRender(this.future);

  final Future<MarkerIcon> future;

  /// Set when the cache is invalidated while this render is in flight; a
  /// stale render still resolves for its callers but is neither joined by
  /// new calls nor written back into the cache.
  bool stale = false;
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
