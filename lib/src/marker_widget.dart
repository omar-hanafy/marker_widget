import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show FlutterExceptionHandler, defaultTargetPlatform, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

bool _isPositiveFinite(double value) => value.isFinite && value > 0;

/// Validates [options] before any rendering work happens.
///
/// Shared by [MarkerIcon]'s synchronous converters and the widget extensions,
/// so an invalid combination fails before preparation, image decoding, or
/// rasterization runs.
void _validateMapBitmapOptions(MapBitmapOptions options) {
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

  if (options.useRenderedPixelRatio &&
      (options.width != null ||
          options.height != null ||
          options.imagePixelRatio != null)) {
    throw StateError(
      'MapBitmapOptions.useRenderedPixelRatio cannot be combined with '
      'width, height, or imagePixelRatio.',
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
}

/// Rejects an [AdvancedMarker] flowing through the classic marker pipeline.
void _ensureClassicMarkerBase(Marker base) {
  if (base is AdvancedMarker) {
    throw ArgumentError.value(
      base,
      'base',
      'AdvancedMarker cannot go through toMarker; use toAdvancedMarker or '
          'toAdvancedPinMarker so it is delivered to the map as an '
          'advanced marker.',
    );
  }
}

/// Options that control how a rendered bitmap is interpreted on the map.
///
/// When [width], [height], and [imagePixelRatio] are all omitted,
/// [MarkerIcon.toMapBitmap] defaults to the icon's [MarkerIcon.logicalSize].
///
/// When [bitmapScaling] is [MapBitmapScaling.none], [width], [height], and
/// [imagePixelRatio] must all remain null so the bitmap is passed through
/// without extra scaling metadata.
@immutable
final class MapBitmapOptions {
  /// Creates bitmap conversion options.
  const MapBitmapOptions({
    this.bitmapScaling = MapBitmapScaling.auto,
    this.width,
    this.height,
    this.imagePixelRatio,
    this.useRenderedPixelRatio = false,
  });

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
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MapBitmapOptions &&
        bitmapScaling == other.bitmapScaling &&
        width == other.width &&
        height == other.height &&
        imagePixelRatio == other.imagePixelRatio &&
        useRenderedPixelRatio == other.useRenderedPixelRatio;
  }

  @override
  int get hashCode => Object.hash(
    bitmapScaling,
    width,
    height,
    imagePixelRatio,
    useRenderedPixelRatio,
  );
}

/// An image that must be decoded before a marker widget is captured.
///
/// [configurationSize] must match the size Flutter supplies when the widget
/// resolves [provider]. For an [Image] with both `width` and `height`, use
/// those dimensions. For a [DecorationImage], use the painted box size. It
/// can stay null when the provider's key does not depend on
/// [ImageConfiguration.size].
@immutable
final class MarkerImageDependency {
  /// Creates a declared image dependency.
  const MarkerImageDependency(this.provider, {this.configurationSize});

  /// The provider decoded before capture.
  final ImageProvider<Object> provider;

  /// The exact size used to resolve a size-sensitive provider.
  final Size? configurationSize;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MarkerImageDependency &&
        provider == other.provider &&
        configurationSize == other.configurationSize;
  }

  @override
  int get hashCode => Object.hash(provider, configurationSize);
}

/// Options that control how a widget is rendered off-screen.
///
/// The renderer falls back to [MarkerIconRenderer.defaultLogicalSize] when
/// [logicalSize] is omitted, and to the active [ui.FlutterView]'s device pixel
/// ratio when [pixelRatio] is omitted.
@immutable
final class MarkerRenderOptions {
  /// Creates widget rendering options.
  MarkerRenderOptions({
    this.logicalSize,
    this.pixelRatio,
    this.cacheKey,
    this.prepare,
    Iterable<MarkerImageDependency> imageDependencies =
        const <MarkerImageDependency>[],
  }) : imageDependencies = List<MarkerImageDependency>.unmodifiable(
         imageDependencies,
       );

  /// Creates the immutable default options used by the convenience APIs.
  const MarkerRenderOptions.defaults()
    : logicalSize = null,
      pixelRatio = null,
      cacheKey = null,
      prepare = null,
      imageDependencies = const <MarkerImageDependency>[];

  /// The logical size to render. When null, the renderer's default is used.
  final Size? logicalSize;

  /// The pixel ratio to render at. When null, the current view DPR is used.
  final double? pixelRatio;

  /// Optional cache key used by [MarkerIconRenderer].
  final Object? cacheKey;

  /// Optional asynchronous preparation performed on a real cache miss.
  ///
  /// Use this for runtime font loading or data that must be ready before the
  /// widget is built. The callback runs after cache lookup and in-flight
  /// deduplication, before image decoding and render-slot acquisition. If its
  /// output can change, include a revision in [cacheKey]. Errors propagate to
  /// the caller.
  final Future<void> Function()? prepare;

  /// Image providers that must be fully decoded before the widget is
  /// captured.
  ///
  /// Declare every [ImageProvider] the widget displays through a standard
  /// [Image], [DecorationImage], or equivalent direct provider lookup. The
  /// renderer resolves each provider against the render environment, waits
  /// for the decode to complete, and keeps the decoded image alive until the
  /// capture finishes. A provider that fails to load fails the render with
  /// [MarkerImageLoadException]. Wrappers with their own placeholder,
  /// animation, or later-frame state are outside this readiness contract;
  /// capture reflects whatever they paint during the renderer's single
  /// build-and-paint pass.
  ///
  /// Use the same provider instances (or providers with equal cache keys)
  /// as the widget itself, otherwise the widget's own lookup misses the
  /// warmed image and captures blank.
  ///
  /// The constructor stores an unmodifiable copy of the supplied iterable.
  final List<MarkerImageDependency> imageDependencies;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MarkerRenderOptions &&
        logicalSize == other.logicalSize &&
        pixelRatio == other.pixelRatio &&
        cacheKey == other.cacheKey &&
        prepare == other.prepare &&
        listEquals(imageDependencies, other.imageDependencies);
  }

  @override
  int get hashCode => Object.hash(
    logicalSize,
    pixelRatio,
    cacheKey,
    prepare,
    Object.hashAll(imageDependencies),
  );
}

/// Thrown when an image declared in
/// [MarkerRenderOptions.imageDependencies] fails to load or decode.
///
/// The render fails loudly instead of capturing a marker with a missing
/// image. Catch this to fall back to a placeholder icon.
final class MarkerImageLoadException implements Exception {
  /// Creates an exception describing why [provider] failed.
  MarkerImageLoadException(this.provider, this.cause, this.stackTrace);

  /// The image provider that failed to load.
  final ImageProvider<Object> provider;

  /// The underlying error reported by the image stream.
  final Object cause;

  /// The stack trace of the underlying error, when available.
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'MarkerImageLoadException: image dependency $provider failed to '
      'load: $cause';
}

/// The pipeline phase in which a framework error failed a marker render.
enum MarkerRenderPhase {
  /// Building the detached widget tree (attaching, `build` methods).
  build,

  /// Laying out the detached render tree (`performLayout`, `performResize`).
  layout,

  /// Compositing and painting the detached render tree (`paint`).
  paint,
}

/// Thrown when the Flutter framework reports an error while building, laying
/// out, or painting the off-screen marker widget tree.
///
/// Flutter catches most build, layout, and paint exceptions internally and
/// substitutes an [ErrorWidget] instead of rethrowing, so without this
/// exception a broken marker widget would be captured (and cached) as an
/// error bitmap. The renderer converts the first reported framework error
/// into a failed render before anything is captured or cached.
final class MarkerRenderException implements Exception {
  /// Creates an exception for a framework error reported during [phase].
  MarkerRenderException({required this.phase, required this.details});

  /// The pipeline phase in which the first error was reported.
  final MarkerRenderPhase phase;

  /// The full framework error report, including the stack trace.
  final FlutterErrorDetails details;

  /// The underlying exception reported by the framework.
  Object get cause => details.exception;

  @override
  String toString() =>
      'MarkerRenderException: marker widget failed during ${phase.name}: '
      '${details.exception}';
}

/// A structured, collision-safe cache key for rendered marker icons.
///
/// Combines the stable identity of a marker with the visual inputs that
/// change its rendered pixels. The renderer already appends the resolved
/// logical size and pixel ratio to every cache entry, so they are not part
/// of this key.
///
/// [extra] carries any additional state that changes the rendered output
/// (selection, status, avatar revision, ...). It is compared with `==`, so
/// use an immutable value with structural equality - a record such as
/// `(selected: true, badge: 3)` works well. Fresh identity-based collections
/// cause cache misses, while mutating and reusing the same collection can
/// return stale output.
///
/// Any object with value semantics works as a
/// [MarkerRenderOptions.cacheKey]; this class is the package-blessed
/// convenience, not a requirement.
@immutable
final class MarkerCacheKey {
  /// Creates a cache key for a marker identified by [id].
  const MarkerCacheKey(this.id, {this.brightness, this.locale, this.extra})
    : _kind = 'marker';

  /// Creates a cache key for a cluster badge showing [count] items.
  ///
  /// Cluster keys never collide with plain keys built from the same value:
  /// `MarkerCacheKey.cluster(count: 5)` and `MarkerCacheKey(5)` are
  /// distinct.
  const MarkerCacheKey.cluster({
    required int count,
    this.brightness,
    this.locale,
    this.extra,
  }) : id = count,
       _kind = 'cluster';

  /// The stable identity of the marker, or the cluster count.
  final Object id;

  /// The theme brightness the icon is rendered for.
  final Brightness? brightness;

  /// The locale the icon is rendered for.
  final Locale? locale;

  /// Additional visual state, compared with `==`.
  final Object? extra;

  final String _kind;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MarkerCacheKey &&
        _kind == other._kind &&
        id == other.id &&
        brightness == other.brightness &&
        locale == other.locale &&
        extra == other.extra;
  }

  @override
  int get hashCode => Object.hash(_kind, id, brightness, locale, extra);

  @override
  String toString() {
    final String name = _kind == 'cluster'
        ? 'MarkerCacheKey.cluster'
        : 'MarkerCacheKey';
    return '$name($id, brightness: $brightness, locale: $locale, '
        'extra: $extra)';
  }
}

/// Value object carrying everything about a rendered marker icon.
///
/// This is the cacheable unit. Store instances of this class in your own
/// state management to implement "render once, reuse everywhere" patterns.
@immutable
final class MarkerIcon {
  /// Creates an icon from rendered PNG [bytes], [logicalSize], and
  /// [pixelRatio].
  ///
  /// The byte list is copied, so later mutations of the source list never
  /// affect the icon, its equality, or its cached conversions.
  ///
  /// Throws [ArgumentError] when [bytes] is empty, [logicalSize] is not
  /// positive and finite in both dimensions, or [pixelRatio] is not positive
  /// and finite.
  MarkerIcon({
    required Uint8List bytes,
    required this.logicalSize,
    required this.pixelRatio,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    if (this.bytes.isEmpty) {
      throw ArgumentError('MarkerIcon.bytes must not be empty.');
    }
    if (!_isPositiveFinite(logicalSize.width) ||
        !_isPositiveFinite(logicalSize.height)) {
      throw ArgumentError.value(
        logicalSize,
        'logicalSize',
        'width and height must both be > 0 and finite.',
      );
    }
    if (!_isPositiveFinite(pixelRatio)) {
      throw ArgumentError.value(
        pixelRatio,
        'pixelRatio',
        'must be > 0 and finite.',
      );
    }
  }

  /// PNG bytes of the rendered widget.
  ///
  /// This is an unmodifiable view of a private copy; writing to it throws
  /// [UnsupportedError].
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

  /// Cached glyph wrappers per icon instance. [BitmapGlyph] has no value
  /// equality upstream, so identity is the only way rebuilt advanced markers
  /// stay equal to their previous versions.
  static final Expando<Map<MapBitmapOptions, BitmapGlyph>> _bitmapGlyphCache =
      Expando<Map<MapBitmapOptions, BitmapGlyph>>('MarkerIcon.toBitmapGlyph');

  /// Cached pin configs per icon instance, keyed by colors and options.
  /// [PinConfig] has no value equality upstream either.
  static final Expando<Map<_PinConfigCacheKey, PinConfig>> _pinConfigCache =
      Expando<Map<_PinConfigCacheKey, PinConfig>>('MarkerIcon.toPinConfig');

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
  /// Throws [StateError] when the supplied bitmap options are invalid.
  BytesMapBitmap toMapBitmap({
    MapBitmapOptions options = const MapBitmapOptions(),
  }) {
    _validateMapBitmapOptions(options);

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
  ///
  /// Repeated calls with equal [options] on the same icon instance return the
  /// identical [BitmapGlyph] object, so advanced markers rebuilt from a
  /// reused icon stay equal to their previous versions.
  ///
  /// Throws [StateError] when the supplied bitmap options are invalid.
  BitmapGlyph toBitmapGlyph({
    MapBitmapOptions options = const MapBitmapOptions(),
  }) {
    _validateMapBitmapOptions(options);

    final Map<MapBitmapOptions, BitmapGlyph> cache = _bitmapGlyphCache[this] ??=
        <MapBitmapOptions, BitmapGlyph>{};
    return cache.putIfAbsent(
      options,
      () => BitmapGlyph(bitmap: toMapBitmap(options: options)),
    );
  }

  /// Converts this icon to a [PinConfig] with a rendered glyph.
  ///
  /// Repeated calls with equal colors and [options] on the same icon
  /// instance return the identical [PinConfig] object, so advanced pin
  /// markers rebuilt from a reused icon stay equal to their previous
  /// versions.
  ///
  /// Throws [StateError] when the supplied bitmap options are invalid.
  ///
  /// Warning: upstream documents an iOS issue where a [PinConfig] may fail to
  /// render. See https://issuetracker.google.com/issues/370536110.
  PinConfig toPinConfig({
    Color? backgroundColor,
    Color? borderColor,
    MapBitmapOptions options = const MapBitmapOptions(),
  }) {
    _validateMapBitmapOptions(options);

    final Map<_PinConfigCacheKey, PinConfig> cache = _pinConfigCache[this] ??=
        <_PinConfigCacheKey, PinConfig>{};
    return cache.putIfAbsent(
      (
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        options: options,
      ),
      () => PinConfig(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        glyph: toBitmapGlyph(options: options),
      ),
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
    _ensureClassicMarkerBase(base);
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MarkerIcon &&
        logicalSize == other.logicalSize &&
        pixelRatio == other.pixelRatio &&
        bytes.lengthInBytes == other.bytes.lengthInBytes &&
        hashCode == other.hashCode &&
        listEquals(bytes, other.bytes);
  }

  /// Computed once per icon: the bytes are immutable, so the content hash
  /// can never change.
  @override
  late final int hashCode = Object.hash(
    logicalSize,
    pixelRatio,
    Object.hashAll(bytes),
  );

  @override
  String toString() =>
      'MarkerIcon(${logicalSize.width}x${logicalSize.height} '
      '@${pixelRatio}x, ${bytes.lengthInBytes} bytes)';
}

/// Renders self-contained, rasterizable snapshot widgets into PNG bytes
/// off-screen.
///
/// This is where the RenderView and PipelineOwner work happens, so the public
/// API stays stable if Flutter tweaks internals again.
class MarkerIconRenderer {
  /// The shared renderer used by the widget extensions when no explicit
  /// renderer is passed.
  ///
  /// Exposed so callers can clear its cache on logout or theme changes,
  /// inspect cache size, or pre-render shared assets. Construct a dedicated
  /// [MarkerIconRenderer] instead when different defaults or an isolated
  /// cache are needed.
  static final MarkerIconRenderer shared = MarkerIconRenderer();

  /// Creates a renderer that turns widgets into marker icons.
  ///
  /// Throws [ArgumentError] when [defaultLogicalSize] is not positive and
  /// finite, [maxCacheEntries] is not positive, or [maxCacheBytes],
  /// [maxConcurrentRenders], [maxConcurrentImageLoads], [maxRasterPixels],
  /// or [imageLoadTimeout] is provided but not positive.
  MarkerIconRenderer({
    this.defaultLogicalSize = const Size(96, 96),
    this.enableCaching = true,
    this.maxCacheEntries = 64,
    this.maxCacheBytes = 50 * 1024 * 1024,
    this.maxConcurrentRenders = 1,
    this.maxConcurrentImageLoads = 1,
    this.maxRasterPixels = 4 * 1024 * 1024,
    this.imageLoadTimeout = const Duration(seconds: 30),
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
    if (maxConcurrentImageLoads != null && maxConcurrentImageLoads! <= 0) {
      throw ArgumentError.value(
        maxConcurrentImageLoads,
        'maxConcurrentImageLoads',
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
    if (imageLoadTimeout != null && imageLoadTimeout! <= Duration.zero) {
      throw ArgumentError.value(
        imageLoadTimeout,
        'imageLoadTimeout',
        'must be > 0 when provided.',
      );
    }
    _renderGate = _FifoConcurrencyGate(maxConcurrentRenders);
    _imageLoadGate = _FifoConcurrencyGate(maxConcurrentImageLoads);
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

  /// The maximum number of render jobs whose declared image dependencies may
  /// be resolving or retained at the same time.
  ///
  /// Each permitted job resolves all of its dependencies concurrently and
  /// keeps the permit until its marker capture finishes. This bounds decoded
  /// native-image retention while allowing image-free renders to bypass a
  /// stalled image source. Set to null to disable this FIFO gate.
  final int? maxConcurrentImageLoads;

  /// The maximum time each declared image dependency may take to deliver its
  /// first decoded frame.
  ///
  /// A dependency that neither decodes nor fails within this window fails the
  /// render with a [MarkerImageLoadException] whose cause is a
  /// [TimeoutException]. Without a finite timeout, one stalled provider would
  /// hold its [maxConcurrentImageLoads] permit forever and block every later
  /// image-backed render. Set to null to wait indefinitely.
  final Duration? imageLoadTimeout;

  /// The maximum number of physical pixels a single render may rasterize,
  /// computed from the independently rounded-up physical width and height.
  ///
  /// Renders above the budget throw [ArgumentError] instead of accidentally
  /// allocating enormous bitmaps. The default of 4194304 equals a 2048 x
  /// 2048 physical bitmap. Set to null to disable the check.
  final int? maxRasterPixels;

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
  late final _FifoConcurrencyGate _renderGate;
  late final _FifoConcurrencyGate _imageLoadGate;

  /// Renders [widget] into a [MarkerIcon].
  ///
  /// If [context] is supplied, the render tree inherits that context's
  /// `MediaQuery`, theme, directionality, and asset bundle, and the context
  /// locale configures image-provider resolution. The detached tree contains
  /// no `Localizations` scope (mounting one would report the captured locale
  /// engine-wide through `setApplicationLocale`), so `Localizations.of`
  /// lookups inside [widget] resolve to nothing; pass resolved localized
  /// values into [widget] and set an explicit `Text.locale` where glyph
  /// selection depends on it.
  /// These values are captured synchronously when [render] is called. Other
  /// inherited scopes are not captured; wrap [widget] with any required
  /// application-specific scope.
  ///
  /// [MarkerRenderOptions.prepare] runs on a real cache miss before declared
  /// images are resolved and before a render slot is acquired. Include a
  /// revision in [MarkerRenderOptions.cacheKey] for prepared data that changes
  /// the output pixels.
  ///
  /// Cached entries are looked up by [MarkerRenderOptions.cacheKey]
  /// combined with the resolved logical size and pixel ratio, so reusing one
  /// cache key at a different size or pixel ratio always renders a fresh
  /// icon. Content inputs that change the rendered output (theme brightness,
  /// locale, selection state, ...) still belong in the cache key itself; see
  /// [MarkerCacheKey].
  Future<MarkerIcon> render(
    Widget widget, {
    BuildContext? context,
    MarkerRenderOptions options = const MarkerRenderOptions.defaults(),
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

    final double dpr = options.pixelRatio ?? view.devicePixelRatio;
    if (!_isPositiveFinite(dpr)) {
      throw ArgumentError.value(
        dpr,
        'options.pixelRatio',
        'the resolved pixelRatio must be > 0 and finite.',
      );
    }

    final double physicalWidth = size.width * dpr;
    final double physicalHeight = size.height * dpr;
    final double unroundedRasterPixels = physicalWidth * physicalHeight;
    if (!_isPositiveFinite(physicalWidth) ||
        !_isPositiveFinite(physicalHeight) ||
        !_isPositiveFinite(unroundedRasterPixels)) {
      throw ArgumentError.value(
        size,
        'options.logicalSize',
        'the resolved physical dimensions and pixel count must be finite.',
      );
    }

    final int? rasterBudget = maxRasterPixels;
    if (rasterBudget != null) {
      // OffsetLayer.toImage rounds each physical output dimension up. Reject
      // obviously oversized dimensions before converting them to integers,
      // then enforce the budget against the exact rounded output area.
      if (physicalWidth > rasterBudget ||
          physicalHeight > rasterBudget ||
          unroundedRasterPixels > rasterBudget) {
        throw ArgumentError.value(
          size,
          'options.logicalSize',
          'Rendering ${size.width} x ${size.height} at pixel ratio $dpr '
              'is above '
              'maxRasterPixels ($rasterBudget). Reduce the marker size or '
              'pixel ratio, or raise/disable maxRasterPixels.',
        );
      }

      final int outputWidth = physicalWidth.ceil();
      final int outputHeight = physicalHeight.ceil();
      final int outputPixels = outputWidth * outputHeight;
      if (outputPixels > rasterBudget) {
        throw ArgumentError.value(
          size,
          'options.logicalSize',
          'Rendering ${size.width} x ${size.height} at pixel ratio $dpr '
              'produces $outputWidth x $outputHeight ($outputPixels physical '
              'pixels), above maxRasterPixels ($rasterBudget). Reduce the '
              'marker size or pixel ratio, or raise/disable maxRasterPixels.',
        );
      }
    }

    final List<MarkerImageDependency> imageDependencies =
        List<MarkerImageDependency>.unmodifiable(options.imageDependencies);
    for (final MarkerImageDependency dependency in imageDependencies) {
      final Size? configurationSize = dependency.configurationSize;
      if (configurationSize != null &&
          (!configurationSize.width.isFinite ||
              !configurationSize.height.isFinite ||
              configurationSize.width < 0 ||
              configurationSize.height < 0)) {
        throw ArgumentError.value(
          configurationSize,
          'options.imageDependencies',
          'configurationSize dimensions must be finite and non-negative.',
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

    // Capture inherited rendering state synchronously. No BuildContext is
    // retained or read after preparation, image decoding, or queue waits.
    final Widget wrapped = _wrapWidget(
      widget,
      context: context,
      view: view,
      logicalSize: size,
      devicePixelRatio: dpr,
    );
    final ImageConfiguration imageConfiguration = _imageConfigurationFor(
      context: context,
      dpr: dpr,
    );

    final Future<MarkerIcon> renderFuture = _renderWithImageDependencies(
      wrapped,
      view: view,
      size: size,
      dpr: dpr,
      prepare: options.prepare,
      imageConfiguration: imageConfiguration,
      imageDependencies: imageDependencies,
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
  ) => _renderGate.run(startRender);

  /// Prepares asynchronous content, then resolves declared image dependencies
  /// and renders inside the FIFO concurrency gate.
  ///
  /// Image-backed jobs use their own bounded gate and retain that permit until
  /// capture completes. This bounds decoded native-image retention without
  /// letting a stalled image block image-free renders. The widget's own lookup
  /// receives the decoded frame synchronously during the single paint pass.
  Future<MarkerIcon> _renderWithImageDependencies(
    Widget wrapped, {
    required ui.FlutterView view,
    required Size size,
    required double dpr,
    required Future<void> Function()? prepare,
    required ImageConfiguration imageConfiguration,
    required List<MarkerImageDependency> imageDependencies,
  }) async {
    await prepare?.call();

    Future<MarkerIcon> resolveAndRender() async {
      final List<(ImageStream, ImageStreamListener)> retained =
          <(ImageStream, ImageStreamListener)>[];
      try {
        if (imageDependencies.isNotEmpty) {
          await _resolveImageDependencies(
            imageDependencies,
            imageConfiguration,
            retained,
          );
        }
        return await _withRenderSlot(
          () => _doRender(wrapped, view: view, size: size, dpr: dpr),
        );
      } finally {
        for (final (ImageStream stream, ImageStreamListener listener)
            in retained) {
          stream.removeListener(listener);
        }
      }
    }

    if (imageDependencies.isEmpty) {
      return _withRenderSlot(
        () => _doRender(wrapped, view: view, size: size, dpr: dpr),
      );
    }
    return _imageLoadGate.run(resolveAndRender);
  }

  /// Mirrors the environment [_wrapWidget] builds, so dependency resolution
  /// and the widget's own image lookups produce the same cache keys.
  ImageConfiguration _imageConfigurationFor({
    required BuildContext? context,
    required double dpr,
  }) {
    return ImageConfiguration(
      bundle: context != null ? DefaultAssetBundle.of(context) : null,
      devicePixelRatio: dpr,
      locale: context != null ? Localizations.maybeLocaleOf(context) : null,
      textDirection: context != null
          ? (Directionality.maybeOf(context) ?? TextDirection.ltr)
          : TextDirection.ltr,
      platform: defaultTargetPlatform,
    );
  }

  /// Starts a decode for every provider and completes when all of them have
  /// delivered a first frame. Streams and listeners are appended to
  /// [retained]; the caller removes the listeners after capture.
  ///
  /// Each decode is bounded by [imageLoadTimeout] so a provider that never
  /// reports success or failure cannot hold the image permit forever.
  Future<void> _resolveImageDependencies(
    List<MarkerImageDependency> dependencies,
    ImageConfiguration configuration,
    List<(ImageStream, ImageStreamListener)> retained,
  ) {
    final Duration? timeout = imageLoadTimeout;
    final List<Future<void>> decodes = <Future<void>>[];
    for (final MarkerImageDependency dependency in dependencies) {
      final ImageProvider<Object> provider = dependency.provider;
      final Completer<void> decode = Completer<void>();
      Future<void> decodeFuture = decode.future;
      if (timeout != null) {
        decodeFuture = decodeFuture.timeout(
          timeout,
          onTimeout: () => throw MarkerImageLoadException(
            provider,
            TimeoutException(
              'Image dependency did not decode within $timeout.',
              timeout,
            ),
            StackTrace.current,
          ),
        );
      }
      decodes.add(decodeFuture);

      final ImageStream stream = provider.resolve(
        configuration.copyWith(size: dependency.configurationSize),
      );
      final ImageStreamListener listener = ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          image.dispose();
          if (!decode.isCompleted) {
            decode.complete();
          }
        },
        onError: (Object error, StackTrace? stackTrace) {
          if (!decode.isCompleted) {
            decode.completeError(
              MarkerImageLoadException(provider, error, stackTrace),
              stackTrace,
            );
          }
        },
      );
      stream.addListener(listener);
      retained.add((stream, listener));
    }
    return Future.wait(decodes, eagerError: true);
  }

  Future<MarkerIcon> _doRender(
    Widget wrapped, {
    required ui.FlutterView view,
    required Size size,
    required double dpr,
  }) async {
    final Uint8List bytes = await _renderOffScreen(
      wrapped,
      view: view,
      logicalSize: size,
      pixelRatio: dpr,
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

    final ui.PlatformDispatcher dispatcher = ui.PlatformDispatcher.instance;

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
      current = DefaultAssetBundle(
        bundle: DefaultAssetBundle.of(context),
        child: current,
      );
    } else {
      current = Material(type: MaterialType.transparency, child: child);
    }

    // No Localizations widget is installed in the detached tree. Mounting one
    // has an engine-wide side effect: every Localizations state reports its
    // locale through PlatformDispatcher.setApplicationLocale, so a detached
    // (possibly queued and stale) marker render would overwrite the
    // application locale the running app last reported. The captured locale
    // still configures image-provider resolution, and the captured
    // Directionality preserves the exact layout direction.
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
  }) async {
    final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();
    final PipelineOwner pipelineOwner = PipelineOwner();
    final FocusManager focusManager = FocusManager();
    final BuildOwner buildOwner = BuildOwner(focusManager: focusManager);

    RenderView? renderView;
    RenderObjectToWidgetElement<RenderBox>? rootElement;

    final ui.Image image;
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

      // Flutter reports build, layout, and paint exceptions through
      // FlutterError.onError and substitutes an ErrorWidget instead of
      // rethrowing. Intercept those reports for the synchronous pipeline
      // below (nothing else can run on the isolate meanwhile) and convert
      // the first one into a failed render before anything is captured.
      // The previous handler is restored before the first await.
      final FlutterExceptionHandler? previousOnError = FlutterError.onError;
      MarkerRenderPhase phase = MarkerRenderPhase.build;
      MarkerRenderPhase? failedPhase;
      FlutterErrorDetails? firstError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (firstError == null) {
          firstError = details;
          failedPhase = phase;
        }
      };
      try {
        rootElement = RenderObjectToWidgetAdapter<RenderBox>(
          container: repaintBoundary,
          child: widget,
        ).attachToRenderTree(buildOwner);

        buildOwner.buildScope(rootElement);
        phase = MarkerRenderPhase.layout;
        pipelineOwner.flushLayout();
        phase = MarkerRenderPhase.paint;
        pipelineOwner.flushCompositingBits();
        pipelineOwner.flushPaint();
      } finally {
        FlutterError.onError = previousOnError;
      }

      if (firstError != null) {
        throw MarkerRenderException(phase: failedPhase!, details: firstError!);
      }

      image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    } finally {
      // The captured image is independent of the tree, so the tree is
      // unmounted (running State.dispose and releasing render objects)
      // before PNG encoding starts.
      _tearDownRenderTree(
        buildOwner: buildOwner,
        pipelineOwner: pipelineOwner,
        focusManager: focusManager,
        repaintBoundary: repaintBoundary,
        renderView: renderView,
        rootElement: rootElement,
      );
    }

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
  }

  /// Unmounts and disposes the detached render tree.
  ///
  /// Never throws: a teardown failure is reported through
  /// [FlutterError.reportError] instead, so it cannot mask the primary
  /// render error (or fail an otherwise successful capture).
  void _tearDownRenderTree({
    required BuildOwner buildOwner,
    required PipelineOwner pipelineOwner,
    required FocusManager focusManager,
    required RenderRepaintBoundary repaintBoundary,
    required RenderView? renderView,
    required RenderObjectToWidgetElement<RenderBox>? rootElement,
  }) {
    try {
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
    } catch (exception, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'marker_widget',
          context: ErrorDescription(
            'while tearing down the off-screen marker render tree',
          ),
        ),
      );
    }
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

/// A fair asynchronous semaphore that transfers occupied permits directly to
/// queued waiters, preventing late arrivals from oversubscribing the limit.
final class _FifoConcurrencyGate {
  _FifoConcurrencyGate(this.limit);

  final int? limit;
  int _active = 0;
  final Queue<Completer<void>> _queue = Queue<Completer<void>>();

  Future<T> run<T>(Future<T> Function() action) async {
    final int? effectiveLimit = limit;
    if (effectiveLimit == null) {
      return action();
    }

    if (_active < effectiveLimit && _queue.isEmpty) {
      _active += 1;
    } else {
      final Completer<void> permit = Completer<void>();
      _queue.add(permit);
      await permit.future;
    }

    try {
      return await action();
    } finally {
      if (_queue.isNotEmpty) {
        // The permit stays counted while ownership moves to the oldest waiter.
        // A new arrival therefore cannot take it during the resume microtask.
        _queue.removeFirst().complete();
      } else {
        _active -= 1;
      }
    }
  }
}

/// Cache identity: the caller's key combined with the resolved render
/// geometry, so one key can never return an icon rendered at another size or
/// pixel ratio.
typedef _ResolvedCacheKey = (Object cacheKey, Size logicalSize, double dpr);

/// Identity of a memoized [PinConfig]: its colors plus the glyph's bitmap
/// options, compared structurally via the record.
typedef _PinConfigCacheKey = ({
  Color? backgroundColor,
  Color? borderColor,
  MapBitmapOptions options,
});

class _PendingRender {
  _PendingRender(this.future);

  final Future<MarkerIcon> future;

  /// Set when the cache is invalidated while this render is in flight; a
  /// stale render still resolves for its callers but is neither joined by
  /// new calls nor written back into the cache.
  bool stale = false;
}

Future<MarkerIcon> _renderMarkerIcon(
  Widget widget, {
  BuildContext? context,
  MarkerIconRenderer? renderer,
  MarkerRenderOptions renderOptions = const MarkerRenderOptions.defaults(),
}) {
  final MarkerIconRenderer effectiveRenderer =
      renderer ?? MarkerIconRenderer.shared;
  return effectiveRenderer.render(
    widget,
    context: context,
    options: renderOptions,
  );
}

/// Extension helpers that render a self-contained, rasterizable snapshot
/// widget into Google Maps bitmap and marker types.
extension WidgetMarkerExtension on Widget {
  /// Converts this widget to a [BitmapDescriptor].
  ///
  /// Invalid [bitmapOptions] fail with [StateError] before any preparation,
  /// image decoding, or rendering work starts.
  Future<BitmapDescriptor> toBitmapDescriptor({
    BuildContext? context,
    MarkerIconRenderer? renderer,
    MarkerRenderOptions renderOptions = const MarkerRenderOptions.defaults(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    _validateMapBitmapOptions(bitmapOptions);
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toBitmapDescriptor(options: bitmapOptions);
  }

  /// Converts this widget to a [BytesMapBitmap].
  ///
  /// Invalid [bitmapOptions] fail with [StateError] before any preparation,
  /// image decoding, or rendering work starts.
  Future<BytesMapBitmap> toMapBitmap({
    BuildContext? context,
    MarkerIconRenderer? renderer,
    MarkerRenderOptions renderOptions = const MarkerRenderOptions.defaults(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    _validateMapBitmapOptions(bitmapOptions);
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
    MarkerRenderOptions renderOptions = const MarkerRenderOptions.defaults(),
  }) async {
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toGroundOverlayBitmap();
  }

  /// Converts this widget to a [BitmapGlyph].
  ///
  /// Invalid [bitmapOptions] fail with [StateError] before any preparation,
  /// image decoding, or rendering work starts.
  Future<BitmapGlyph> toBitmapGlyph({
    BuildContext? context,
    MarkerIconRenderer? renderer,
    MarkerRenderOptions renderOptions = const MarkerRenderOptions.defaults(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    _validateMapBitmapOptions(bitmapOptions);
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
    MarkerRenderOptions renderOptions = const MarkerRenderOptions.defaults(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    _validateMapBitmapOptions(bitmapOptions);
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
    MarkerRenderOptions renderOptions = const MarkerRenderOptions.defaults(),
  }) {
    return _renderMarkerIcon(
      this,
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
  }

  /// Renders this widget and immediately builds a classic [Marker].
  ///
  /// An [AdvancedMarker] base fails with [ArgumentError] and invalid
  /// [bitmapOptions] fail with [StateError] before any preparation, image
  /// decoding, or rendering work starts.
  Future<Marker> toMarker({
    required Marker base,
    BuildContext? context,
    MarkerIconRenderer? renderer,
    MarkerRenderOptions renderOptions = const MarkerRenderOptions.defaults(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    _ensureClassicMarkerBase(base);
    _validateMapBitmapOptions(bitmapOptions);
    final MarkerIcon icon = await toMarkerIcon(
      context: context,
      renderer: renderer,
      renderOptions: renderOptions,
    );
    return icon.toMarker(base: base, bitmapOptions: bitmapOptions);
  }

  /// Renders this widget and immediately builds an [AdvancedMarker].
  ///
  /// Invalid [bitmapOptions] fail with [StateError] before any preparation,
  /// image decoding, or rendering work starts.
  Future<AdvancedMarker> toAdvancedMarker({
    required AdvancedMarker base,
    BuildContext? context,
    MarkerIconRenderer? renderer,
    MarkerRenderOptions renderOptions = const MarkerRenderOptions.defaults(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    _validateMapBitmapOptions(bitmapOptions);
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
    MarkerRenderOptions renderOptions = const MarkerRenderOptions.defaults(),
    MapBitmapOptions bitmapOptions = const MapBitmapOptions(),
  }) async {
    _validateMapBitmapOptions(bitmapOptions);
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
