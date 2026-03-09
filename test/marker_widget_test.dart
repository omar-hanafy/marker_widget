import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_widget/marker_widget.dart';

Uint8List _onePixelPng() => Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _DummyLocalizations {
  const _DummyLocalizations();
}

class _DummyLocalizationsDelegate
    extends LocalizationsDelegate<_DummyLocalizations> {
  const _DummyLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<_DummyLocalizations> load(Locale locale) {
    return SynchronousFuture<_DummyLocalizations>(const _DummyLocalizations());
  }

  @override
  bool shouldReload(_DummyLocalizationsDelegate old) => false;
}

class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle(this.name);

  final String name;

  @override
  Future<ByteData> load(String key) async => ByteData(0);
}

Widget _slowColorBox(Color color, Uint8List pngBytes) {
  return DecoratedBox(
    decoration: BoxDecoration(
      image: DecorationImage(image: MemoryImage(pngBytes)),
    ),
    child: ColoredBox(color: color),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarkerIcon', () {
    late Uint8List validPngBytes;

    setUp(() {
      validPngBytes = _onePixelPng();
    });

    MarkerIcon buildIcon({
      Size logicalSize = const Size(100, 100),
      double pixelRatio = 2.0,
      Uint8List? bytes,
    }) {
      return MarkerIcon(
        bytes: bytes ?? validPngBytes,
        logicalSize: logicalSize,
        pixelRatio: pixelRatio,
      );
    }

    test('stores bytes metadata and size', () {
      final icon = buildIcon();

      expect(icon.bytes, validPngBytes);
      expect(icon.logicalSize, const Size(100, 100));
      expect(icon.pixelRatio, 2.0);
      expect(icon.sizeInBytes, validPngBytes.lengthInBytes);
    });

    test('compares bytes structurally', () {
      final icon1 = buildIcon(bytes: Uint8List.fromList(validPngBytes));
      final icon2 = buildIcon(bytes: Uint8List.fromList(validPngBytes));

      expect(icon1, icon2);
      expect(icon1.hashCode, icon2.hashCode);
    });

    group('toMapBitmap', () {
      test('defaults to logical-size dimensions', () {
        final bitmap = buildIcon(logicalSize: const Size(80, 60)).toMapBitmap();

        expect(bitmap, isA<BytesMapBitmap>());
        expect(bitmap.width, 80);
        expect(bitmap.height, 60);
        expect(bitmap.bitmapScaling, MapBitmapScaling.auto);
      });

      test('supports width-only scaling', () {
        final bitmap = buildIcon().toMapBitmap(
          options: const MapBitmapOptions(width: 48),
        );

        expect(bitmap.width, 48);
        expect(bitmap.height, isNull);
      });

      test('supports imagePixelRatio metadata', () {
        final bitmap = buildIcon().toMapBitmap(
          options: const MapBitmapOptions(imagePixelRatio: 3.0),
        );

        expect(bitmap.width, isNull);
        expect(bitmap.height, isNull);
        expect(bitmap.imagePixelRatio, 3.0);
      });

      test('supports pixel-perfect rendered DPR metadata', () {
        final bitmap = buildIcon(
          pixelRatio: 3.5,
        ).toMapBitmap(options: const MapBitmapOptions.pixelPerfect());

        expect(bitmap.width, isNull);
        expect(bitmap.height, isNull);
        expect(bitmap.imagePixelRatio, 3.5);
      });

      test('supports raw scaling none path', () {
        final bitmap = buildIcon().toMapBitmap(
          options: const MapBitmapOptions(bitmapScaling: MapBitmapScaling.none),
        );

        expect(bitmap.bitmapScaling, MapBitmapScaling.none);
        expect(bitmap.width, isNull);
        expect(bitmap.height, isNull);
      });

      test('throws for empty bytes', () {
        final icon = buildIcon(bytes: Uint8List(0));

        expect(
          () => icon.toMapBitmap(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('bytes must not be empty'),
            ),
          ),
        );
      });

      test('throws for scaling none combined with width', () {
        final icon = buildIcon();

        expect(
          () => icon.toMapBitmap(
            options: const MapBitmapOptions(
              bitmapScaling: MapBitmapScaling.none,
              width: 24,
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('cannot be combined with width'),
            ),
          ),
        );
      });

      test('throws for scaling none combined with rendered DPR', () {
        final icon = buildIcon();

        expect(
          () => icon.toMapBitmap(
            options: const MapBitmapOptions(
              bitmapScaling: MapBitmapScaling.none,
              useRenderedPixelRatio: true,
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('cannot be combined with width'),
            ),
          ),
        );
      });

      test('throws for non-positive width', () {
        final icon = buildIcon();

        expect(
          () => icon.toMapBitmap(options: const MapBitmapOptions(width: 0)),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('MapBitmapOptions.width must be > 0'),
            ),
          ),
        );
      });

      test('throws for non-positive height', () {
        final icon = buildIcon();

        expect(
          () => icon.toMapBitmap(options: const MapBitmapOptions(height: -1)),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('MapBitmapOptions.height must be > 0'),
            ),
          ),
        );
      });

      test('throws for non-positive imagePixelRatio', () {
        final icon = buildIcon();

        expect(
          () => icon.toMapBitmap(
            options: const MapBitmapOptions(imagePixelRatio: 0),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('MapBitmapOptions.imagePixelRatio must be > 0'),
            ),
          ),
        );
      });
    });

    test('toBitmapDescriptor delegates to map bitmap conversion', () {
      final descriptor = buildIcon().toBitmapDescriptor();

      expect(descriptor, isA<BitmapDescriptor>());
      expect(descriptor, isA<BytesMapBitmap>());
    });

    test('toBitmapDescriptor forwards bitmap options', () {
      final descriptor = buildIcon().toBitmapDescriptor(
        options: const MapBitmapOptions(imagePixelRatio: 3.5),
      );

      expect(descriptor, isA<BytesMapBitmap>());
      expect((descriptor as BytesMapBitmap).imagePixelRatio, 3.5);
    });

    test('toGroundOverlayBitmap produces raw bitmap', () {
      final bitmap = buildIcon().toGroundOverlayBitmap();

      expect(bitmap.bitmapScaling, MapBitmapScaling.none);
      expect(bitmap.width, isNull);
      expect(bitmap.height, isNull);
    });

    test('toBitmapGlyph wraps the map bitmap', () {
      final glyph = buildIcon().toBitmapGlyph();

      expect(glyph, isA<BitmapGlyph>());
      expect(glyph.bitmap, isA<BytesMapBitmap>());
    });

    test('toBitmapGlyph forwards bitmap options', () {
      final glyph = buildIcon().toBitmapGlyph(
        options: const MapBitmapOptions(width: 18),
      );

      expect(glyph.bitmap, isA<BytesMapBitmap>());
      expect((glyph.bitmap as BytesMapBitmap).width, 18);
    });

    test('toPinConfig builds glyph-backed pin', () {
      final pinConfig = buildIcon().toPinConfig(
        backgroundColor: Colors.blue,
        borderColor: Colors.white,
      );

      expect(pinConfig.backgroundColor, Colors.blue);
      expect(pinConfig.borderColor, Colors.white);
      expect(pinConfig.glyph, isA<BitmapGlyph>());
    });

    test('toPinConfig forwards bitmap options to the glyph bitmap', () {
      final pinConfig = buildIcon().toPinConfig(
        options: const MapBitmapOptions(imagePixelRatio: 4.0),
      );

      expect(pinConfig.glyph, isA<BitmapGlyph>());
      expect(
        ((pinConfig.glyph! as BitmapGlyph).bitmap as BytesMapBitmap)
            .imagePixelRatio,
        4.0,
      );
    });

    test('toMarker forwards the base marker configuration', () {
      final marker = buildIcon().toMarker(
        base: const Marker(
          markerId: MarkerId('marker-id'),
          position: LatLng(10, 20),
          zIndexInt: 7,
          flat: true,
        ),
      );

      expect(marker.markerId, const MarkerId('marker-id'));
      expect(marker.position, const LatLng(10, 20));
      expect(marker.zIndexInt, 7);
      expect(marker.flat, isTrue);
      expect(marker.icon, isA<BytesMapBitmap>());
    });

    test(
      'toAdvancedMarker forwards the base advanced marker configuration',
      () {
        final marker = buildIcon().toAdvancedMarker(
          base: AdvancedMarker(
            markerId: const MarkerId('advanced-id'),
            position: const LatLng(30, 40),
            zIndex: 9,
            collisionBehavior: MarkerCollisionBehavior.requiredAndHidesOptional,
          ),
        );

        expect(marker.markerId, const MarkerId('advanced-id'));
        expect(marker.position, const LatLng(30, 40));
        expect(marker.zIndexInt, 9);
        expect(
          marker.collisionBehavior,
          MarkerCollisionBehavior.requiredAndHidesOptional,
        );
        expect(marker.icon, isA<BytesMapBitmap>());
      },
    );

    test('toAdvancedPinMarker builds pin-based advanced marker', () {
      final marker = buildIcon().toAdvancedPinMarker(
        base: AdvancedMarker(
          markerId: const MarkerId('pin-id'),
          position: const LatLng(50, 60),
          collisionBehavior: MarkerCollisionBehavior.requiredAndHidesOptional,
        ),
        backgroundColor: Colors.white,
        borderColor: Colors.blue,
      );

      expect(marker.markerId, const MarkerId('pin-id'));
      expect(marker.position, const LatLng(50, 60));
      expect(
        marker.collisionBehavior,
        MarkerCollisionBehavior.requiredAndHidesOptional,
      );
      expect(marker.icon, isA<PinConfig>());
      final pinConfig = marker.icon as PinConfig;
      expect(pinConfig.backgroundColor, Colors.white);
      expect(pinConfig.borderColor, Colors.blue);
      expect(pinConfig.glyph, isA<BitmapGlyph>());
    });

    test(
      'MapBitmapOptions.pixelPerfect uses rendered pixel ratio at conversion time',
      () {
        const options = MapBitmapOptions.pixelPerfect();

        expect(options.useRenderedPixelRatio, isTrue);
        expect(options.bitmapScaling, MapBitmapScaling.auto);
        expect(options.width, isNull);
        expect(options.height, isNull);
        expect(options.imagePixelRatio, isNull);
      },
    );
  });

  group('MarkerIconRenderer', () {
    test('creates with default parameters', () {
      final renderer = MarkerIconRenderer();

      expect(renderer.defaultLogicalSize, const Size(96, 96));
      expect(renderer.enableCaching, isTrue);
      expect(renderer.maxCacheEntries, 64);
      expect(renderer.maxCacheBytes, 50 * 1024 * 1024);
      expect(renderer.cacheSize, 0);
      expect(renderer.cacheSizeInBytes, 0);
    });

    test('asserts on non-positive maxCacheEntries', () {
      expect(
        () => MarkerIconRenderer(maxCacheEntries: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('throws for non-positive logical size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer();
      final context = tester.element(find.byType(Scaffold));

      await expectLater(
        renderer.render(
          const SizedBox(),
          context: context,
          options: const WidgetBitmapRenderOptions(logicalSize: Size(0, 100)),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must both be > 0'),
          ),
        ),
      );
    });

    testWidgets('throws for non-positive pixel ratio', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer();
      final context = tester.element(find.byType(Scaffold));

      await expectLater(
        renderer.render(
          const SizedBox(),
          context: context,
          options: const WidgetBitmapRenderOptions(pixelRatio: 0),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('pixelRatio must be > 0'),
          ),
        ),
      );
    });

    testWidgets('caches by cache key', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer();
      final context = tester.element(find.byType(Scaffold));

      final icon1 = await tester.runAsync(
        () => renderer.render(
          Container(width: 30, height: 30, color: Colors.red),
          context: context,
          options: const WidgetBitmapRenderOptions(
            logicalSize: Size(30, 30),
            cacheKey: 'cache-key',
          ),
        ),
      );

      final icon2 = await tester.runAsync(
        () => renderer.render(
          Container(width: 30, height: 30, color: Colors.blue),
          context: context,
          options: const WidgetBitmapRenderOptions(
            logicalSize: Size(30, 30),
            cacheKey: 'cache-key',
          ),
        ),
      );

      expect(renderer.isCached('cache-key'), isTrue);
      expect(identical(icon1, icon2), isTrue);
      expect(renderer.cacheSize, 1);
    });

    testWidgets('does not cache when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer(enableCaching: false);
      final context = tester.element(find.byType(Scaffold));

      final icon1 = await tester.runAsync(
        () => renderer.render(
          const SizedBox(),
          context: context,
          options: const WidgetBitmapRenderOptions(
            logicalSize: Size(20, 20),
            cacheKey: 'no-cache',
          ),
        ),
      );

      final icon2 = await tester.runAsync(
        () => renderer.render(
          const SizedBox(),
          context: context,
          options: const WidgetBitmapRenderOptions(
            logicalSize: Size(20, 20),
            cacheKey: 'no-cache',
          ),
        ),
      );

      expect(identical(icon1, icon2), isFalse);
      expect(renderer.cacheSize, 0);
    });

    testWidgets('removeFromCache removes a cached entry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer();
      final context = tester.element(find.byType(Scaffold));

      await tester.runAsync(
        () => renderer.render(
          const SizedBox(),
          context: context,
          options: const WidgetBitmapRenderOptions(
            logicalSize: Size(20, 20),
            cacheKey: 'remove-me',
          ),
        ),
      );

      expect(renderer.isCached('remove-me'), isTrue);

      renderer.removeFromCache('remove-me');

      expect(renderer.isCached('remove-me'), isFalse);
      expect(renderer.cacheSize, 0);
      expect(renderer.cacheSizeInBytes, 0);
    });

    testWidgets('clearCache resets cache state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer();
      final context = tester.element(find.byType(Scaffold));

      await tester.runAsync(
        () => renderer.render(
          const SizedBox(),
          context: context,
          options: const WidgetBitmapRenderOptions(
            logicalSize: Size(20, 20),
            cacheKey: 'clear-me',
          ),
        ),
      );

      expect(renderer.cacheSize, 1);
      expect(renderer.cacheSizeInBytes, greaterThan(0));

      renderer.clearCache();

      expect(renderer.cacheSize, 0);
      expect(renderer.cacheSizeInBytes, 0);
    });

    testWidgets('clearCache invalidates stale pending renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer(
        initialImageDelay: const Duration(milliseconds: 50),
        imageRepaintDelay: const Duration(milliseconds: 50),
      );
      final context = tester.element(find.byType(Scaffold));

      final (MarkerIcon slowIcon, MarkerIcon fastIcon) = (await tester.runAsync(
        () async {
          final Future<MarkerIcon> slowFuture = renderer.render(
            _slowColorBox(Colors.red, _onePixelPng()),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(24, 24),
              cacheKey: 'stale-clear',
              waitForImages: true,
            ),
          );

          renderer.clearCache();

          final Future<MarkerIcon> fastFuture = renderer.render(
            Container(width: 24, height: 24, color: Colors.blue),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(24, 24),
              cacheKey: 'stale-clear',
            ),
          );

          final MarkerIcon fastIcon = await fastFuture;
          final MarkerIcon slowIcon = await slowFuture;
          return (slowIcon, fastIcon);
        },
      ))!;

      expect(identical(slowIcon, fastIcon), isFalse);
      expect(renderer.isCached('stale-clear'), isTrue);
      expect(identical(renderer.peekCache('stale-clear'), fastIcon), isTrue);
    });

    testWidgets('removeFromCache invalidates stale pending renders', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer(
        initialImageDelay: const Duration(milliseconds: 50),
        imageRepaintDelay: const Duration(milliseconds: 50),
      );
      final context = tester.element(find.byType(Scaffold));

      final (MarkerIcon slowIcon, MarkerIcon fastIcon) = (await tester.runAsync(
        () async {
          final Future<MarkerIcon> slowFuture = renderer.render(
            _slowColorBox(Colors.red, _onePixelPng()),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(24, 24),
              cacheKey: 'stale-remove',
              waitForImages: true,
            ),
          );

          renderer.removeFromCache('stale-remove');

          final Future<MarkerIcon> fastFuture = renderer.render(
            Container(width: 24, height: 24, color: Colors.blue),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(24, 24),
              cacheKey: 'stale-remove',
            ),
          );

          final MarkerIcon fastIcon = await fastFuture;
          final MarkerIcon slowIcon = await slowFuture;
          return (slowIcon, fastIcon);
        },
      ))!;

      expect(identical(slowIcon, fastIcon), isFalse);
      expect(renderer.isCached('stale-remove'), isTrue);
      expect(identical(renderer.peekCache('stale-remove'), fastIcon), isTrue);
    });

    testWidgets('evicts least recently used entries by maxCacheEntries', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer(
        maxCacheEntries: 2,
        maxCacheBytes: null,
      );
      final context = tester.element(find.byType(Scaffold));

      Future<void> renderWithKey(String key) => tester.runAsync(
        () => renderer.render(
          const SizedBox(),
          context: context,
          options: WidgetBitmapRenderOptions(
            logicalSize: const Size(20, 20),
            cacheKey: key,
          ),
        ),
      );

      await renderWithKey('a');
      await renderWithKey('b');

      expect(renderer.isCached('a'), isTrue);
      expect(renderer.isCached('b'), isTrue);

      await renderWithKey('c');

      expect(renderer.isCached('a'), isFalse);
      expect(renderer.isCached('b'), isTrue);
      expect(renderer.isCached('c'), isTrue);
    });

    testWidgets('shares pending renders for the same cache key', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer();
      final context = tester.element(find.byType(Scaffold));

      final results = await tester.runAsync(
        () => Future.wait<MarkerIcon>([
          renderer.render(
            const SizedBox(),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(24, 24),
              cacheKey: 'pending-key',
            ),
          ),
          renderer.render(
            const SizedBox(),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(24, 24),
              cacheKey: 'pending-key',
            ),
          ),
        ]),
      );

      expect(identical(results![0], results[1]), isTrue);
      expect(renderer.cacheSize, 1);
    });

    testWidgets(
      'does not cache oversized items when maxCacheBytes is exceeded',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );

        final renderer = MarkerIconRenderer(
          maxCacheEntries: 10,
          maxCacheBytes: 1,
        );
        final context = tester.element(find.byType(Scaffold));

        await tester.runAsync(
          () => renderer.render(
            const SizedBox(),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(10, 10),
              cacheKey: 'oversized',
            ),
          ),
        );

        expect(renderer.cacheSize, 0);
        expect(renderer.cacheSizeInBytes, 0);
        expect(renderer.isCached('oversized'), isFalse);
      },
    );

    testWidgets('evicts older entries to stay under maxCacheBytes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));
      final measureRenderer = MarkerIconRenderer(maxCacheBytes: null);

      final sampleIcon = await tester.runAsync(
        () => measureRenderer.render(
          const SizedBox(),
          context: context,
          options: const WidgetBitmapRenderOptions(
            logicalSize: Size(10, 10),
            cacheKey: 'measure',
          ),
        ),
      );

      final renderer = MarkerIconRenderer(
        maxCacheEntries: 10,
        maxCacheBytes: sampleIcon!.sizeInBytes,
      );

      await tester.runAsync(
        () => renderer.render(
          const SizedBox(),
          context: context,
          options: const WidgetBitmapRenderOptions(
            logicalSize: Size(10, 10),
            cacheKey: 'first',
          ),
        ),
      );

      expect(renderer.cacheSize, 1);
      expect(renderer.isCached('first'), isTrue);

      await tester.runAsync(
        () => renderer.render(
          const SizedBox(),
          context: context,
          options: const WidgetBitmapRenderOptions(
            logicalSize: Size(10, 10),
            cacheKey: 'second',
          ),
        ),
      );

      expect(renderer.cacheSize, 1);
      expect(renderer.isCached('first'), isFalse);
      expect(renderer.isCached('second'), isTrue);
    });

    testWidgets('captures theme from the source context', (tester) async {
      Future<MarkerIcon?> renderForTheme(Color seedColor) async {
        final marker = Container(key: UniqueKey());
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Theme(
              data: ThemeData(primaryColor: seedColor),
              child: marker,
            ),
          ),
        );

        final context = tester.element(find.byWidget(marker));
        final renderer = MarkerIconRenderer(enableCaching: false);

        return tester.runAsync(
          () => renderer.render(
            Builder(
              builder: (ctx) => Container(
                width: 48,
                height: 48,
                color: Theme.of(ctx).primaryColor,
              ),
            ),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(48, 48),
              pixelRatio: 1.0,
            ),
          ),
        );
      }

      final purpleIcon = await renderForTheme(Colors.purple);
      final tealIcon = await renderForTheme(Colors.teal);

      expect(purpleIcon, isNotNull);
      expect(tealIcon, isNotNull);
      expect(purpleIcon!.bytes, isNot(equals(tealIcon!.bytes)));
    });

    testWidgets('captures directionality from the source context', (
      tester,
    ) async {
      Future<MarkerIcon?> renderForDirection(TextDirection direction) async {
        final marker = Container(key: UniqueKey());
        await tester.pumpWidget(
          Directionality(textDirection: direction, child: marker),
        );

        final context = tester.element(find.byWidget(marker));
        final renderer = MarkerIconRenderer(enableCaching: false);

        return tester.runAsync(
          () => renderer.render(
            ColoredBox(
              color: Colors.white,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(width: 20, height: 20, color: Colors.red),
              ),
            ),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(60, 40),
              pixelRatio: 1.0,
            ),
          ),
        );
      }

      final ltrIcon = await renderForDirection(TextDirection.ltr);
      final rtlIcon = await renderForDirection(TextDirection.rtl);

      expect(ltrIcon, isNotNull);
      expect(rtlIcon, isNotNull);
      expect(ltrIcon!.bytes, isNot(equals(rtlIcon!.bytes)));
    });

    testWidgets('captures localizations from the source context', (
      tester,
    ) async {
      Future<MarkerIcon?> renderForLocale({
        required Locale locale,
        required String expectedLanguageCode,
      }) async {
        final marker = Container(key: UniqueKey());
        await tester.pumpWidget(
          Localizations(
            locale: locale,
            delegates: const <LocalizationsDelegate<dynamic>>[
              DefaultWidgetsLocalizations.delegate,
              _DummyLocalizationsDelegate(),
            ],
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: marker,
            ),
          ),
        );

        final context = tester.element(find.byWidget(marker));
        final renderer = MarkerIconRenderer(enableCaching: false);

        return tester.runAsync(
          () => renderer.render(
            Builder(
              builder: (ctx) => ColoredBox(
                color:
                    Localizations.localeOf(ctx).languageCode ==
                        expectedLanguageCode
                    ? Colors.red
                    : Colors.blue,
              ),
            ),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(40, 40),
              pixelRatio: 1.0,
            ),
          ),
        );
      }

      final matchIcon = await renderForLocale(
        locale: const Locale('ar'),
        expectedLanguageCode: 'ar',
      );
      final mismatchIcon = await renderForLocale(
        locale: const Locale('ar'),
        expectedLanguageCode: 'en',
      );

      expect(matchIcon, isNotNull);
      expect(mismatchIcon, isNotNull);
      expect(matchIcon!.bytes, isNot(equals(mismatchIcon!.bytes)));
    });

    testWidgets('captures DefaultAssetBundle from the source context', (
      tester,
    ) async {
      Future<MarkerIcon?> renderForBundle({
        required AssetBundle sourceBundle,
        required AssetBundle expectedBundle,
      }) async {
        final marker = Container(key: UniqueKey());
        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: sourceBundle,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: marker,
            ),
          ),
        );

        final context = tester.element(find.byWidget(marker));
        final renderer = MarkerIconRenderer(enableCaching: false);

        return tester.runAsync(
          () => renderer.render(
            Builder(
              builder: (ctx) => ColoredBox(
                color: identical(DefaultAssetBundle.of(ctx), expectedBundle)
                    ? Colors.red
                    : Colors.blue,
              ),
            ),
            context: context,
            options: const WidgetBitmapRenderOptions(
              logicalSize: Size(40, 40),
              pixelRatio: 1.0,
            ),
          ),
        );
      }

      final bundleA = _TestAssetBundle('a');
      final bundleB = _TestAssetBundle('b');
      final matchIcon = await renderForBundle(
        sourceBundle: bundleA,
        expectedBundle: bundleA,
      );
      final mismatchIcon = await renderForBundle(
        sourceBundle: bundleA,
        expectedBundle: bundleB,
      );

      expect(matchIcon, isNotNull);
      expect(mismatchIcon, isNotNull);
      expect(matchIcon!.bytes, isNot(equals(mismatchIcon!.bytes)));
    });
  });

  group('Cache key helpers', () {
    test('buildMarkerCacheKey stays stable for equal inputs', () {
      final key1 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
        brightness: Brightness.light,
        locale: const Locale('en', 'US'),
        extra: 'selected',
      );

      final key2 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
        brightness: Brightness.light,
        locale: const Locale('en', 'US'),
        extra: 'selected',
      );

      expect(key1, key2);
      expect(key1, contains('extra=selected'));
    });

    test('buildClusterCacheKey differentiates key inputs', () {
      final key1 = buildClusterCacheKey(
        count: 12,
        logicalSize: const Size(48, 48),
        pixelRatio: 2.0,
        brightness: Brightness.dark,
        locale: const Locale('en'),
        extra: 'a',
      );

      final key2 = buildClusterCacheKey(
        count: 15,
        logicalSize: const Size(48, 48),
        pixelRatio: 2.0,
        brightness: Brightness.dark,
        locale: const Locale('en'),
        extra: 'a',
      );

      expect(key1, isNot(key2));
      expect(key1, contains('count=12'));
      expect(key1, contains('extra=a'));
    });
  });

  group('Widget rendering integration', () {
    testWidgets('renders simple widget to MarkerIcon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));
      final renderer = MarkerIconRenderer();

      final icon = await tester.runAsync(
        () => renderer.render(
          Container(width: 50, height: 50, color: Colors.red),
          context: context,
          options: const WidgetBitmapRenderOptions(
            logicalSize: Size(50, 50),
            pixelRatio: 1.0,
          ),
        ),
      );

      expect(icon, isA<MarkerIcon>());
      expect(icon!.bytes, isNotEmpty);
      expect(icon.logicalSize, const Size(50, 50));
      expect(icon.pixelRatio, 1.0);
    });

    testWidgets('toBitmapDescriptor extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));

      final descriptor = await tester.runAsync(
        () => Container(width: 40, height: 40, color: Colors.blue)
            .toBitmapDescriptor(
              context: context,
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(40, 40),
              ),
            ),
      );

      expect(descriptor, isA<BytesMapBitmap>());
    });

    testWidgets('toMapBitmap extension accepts bitmap options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));

      final bitmap = await tester.runAsync(
        () => Container(width: 40, height: 40, color: Colors.green).toMapBitmap(
          context: context,
          renderOptions: const WidgetBitmapRenderOptions(
            logicalSize: Size(40, 40),
          ),
          bitmapOptions: const MapBitmapOptions(imagePixelRatio: 2.5),
        ),
      );

      expect(bitmap, isA<BytesMapBitmap>());
      expect(bitmap!.imagePixelRatio, 2.5);
    });

    testWidgets('toGroundOverlayBitmap extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));

      final bitmap = await tester.runAsync(
        () => Container(width: 40, height: 40, color: Colors.orange)
            .toGroundOverlayBitmap(
              context: context,
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(40, 40),
              ),
            ),
      );

      expect(bitmap, isA<BytesMapBitmap>());
      expect(bitmap!.bitmapScaling, MapBitmapScaling.none);
    });

    testWidgets('toMarkerIcon extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));

      final icon = await tester.runAsync(
        () =>
            Container(width: 40, height: 40, color: Colors.yellow).toMarkerIcon(
              context: context,
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(40, 40),
              ),
            ),
      );

      expect(icon, isA<MarkerIcon>());
      expect(icon!.bytes, isNotEmpty);
      expect(icon.logicalSize, const Size(40, 40));
    });

    testWidgets('toBitmapGlyph extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));

      final glyph = await tester.runAsync(
        () => Container(width: 24, height: 24, color: Colors.purple)
            .toBitmapGlyph(
              context: context,
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(24, 24),
              ),
            ),
      );

      expect(glyph, isA<BitmapGlyph>());
      expect(glyph!.bitmap, isA<BytesMapBitmap>());
    });

    testWidgets('toPinConfig extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));

      final pinConfig = await tester.runAsync(
        () => Container(width: 24, height: 24, color: Colors.black).toPinConfig(
          context: context,
          backgroundColor: Colors.blue,
          borderColor: Colors.white,
          renderOptions: const WidgetBitmapRenderOptions(
            logicalSize: Size(24, 24),
          ),
        ),
      );

      expect(pinConfig, isA<PinConfig>());
      expect(pinConfig!.glyph, isA<BitmapGlyph>());
    });

    testWidgets('toMarker extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));

      final marker = await tester.runAsync(
        () => Container(width: 32, height: 32, color: Colors.teal).toMarker(
          context: context,
          base: const Marker(
            markerId: MarkerId('widget-marker'),
            position: LatLng(1, 2),
            zIndexInt: 3,
          ),
          renderOptions: const WidgetBitmapRenderOptions(
            logicalSize: Size(32, 32),
          ),
        ),
      );

      expect(marker, isA<Marker>());
      expect(marker!.markerId, const MarkerId('widget-marker'));
      expect(marker.position, const LatLng(1, 2));
      expect(marker.zIndexInt, 3);
    });

    testWidgets('toAdvancedMarker extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));

      final marker = await tester.runAsync(
        () => Container(width: 32, height: 32, color: Colors.indigo)
            .toAdvancedMarker(
              context: context,
              base: AdvancedMarker(
                markerId: const MarkerId('widget-advanced'),
                position: const LatLng(3, 4),
                collisionBehavior:
                    MarkerCollisionBehavior.optionalAndHidesLowerPriority,
              ),
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(32, 32),
              ),
            ),
      );

      expect(marker, isA<AdvancedMarker>());
      expect(marker!.markerId, const MarkerId('widget-advanced'));
      expect(
        marker.collisionBehavior,
        MarkerCollisionBehavior.optionalAndHidesLowerPriority,
      );
    });

    testWidgets('toAdvancedPinMarker extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));

      final marker = await tester.runAsync(
        () => Container(width: 24, height: 24, color: Colors.red)
            .toAdvancedPinMarker(
              context: context,
              base: AdvancedMarker(
                markerId: const MarkerId('ext-pin'),
                position: const LatLng(7, 8),
              ),
              backgroundColor: Colors.white,
              borderColor: Colors.red,
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(24, 24),
              ),
            ),
      );

      expect(marker, isA<AdvancedMarker>());
      expect(marker!.markerId, const MarkerId('ext-pin'));
      expect(marker.icon, isA<PinConfig>());
    });
  });

  group('Contextless widget extensions', () {
    testWidgets('toBitmapDescriptor works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final descriptor = await tester.runAsync(
        () => Container(width: 30, height: 30, color: Colors.red)
            .toBitmapDescriptor(
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(30, 30),
                pixelRatio: 1.0,
              ),
            ),
      );

      expect(descriptor, isA<BytesMapBitmap>());
    });

    testWidgets('toPinConfig works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final pinConfig = await tester.runAsync(
        () => Container(width: 24, height: 24, color: Colors.blue).toPinConfig(
          backgroundColor: Colors.black,
          renderOptions: const WidgetBitmapRenderOptions(
            logicalSize: Size(24, 24),
            pixelRatio: 1.0,
          ),
        ),
      );

      expect(pinConfig, isA<PinConfig>());
      expect(pinConfig!.glyph, isA<BitmapGlyph>());
    });

    testWidgets('toMapBitmap works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final bitmap = await tester.runAsync(
        () =>
            Container(width: 30, height: 30, color: Colors.orange).toMapBitmap(
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(30, 30),
                pixelRatio: 1.0,
              ),
              bitmapOptions: const MapBitmapOptions(width: 22),
            ),
      );

      expect(bitmap, isA<BytesMapBitmap>());
      expect(bitmap!.width, 22);
    });

    testWidgets('toGroundOverlayBitmap works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final bitmap = await tester.runAsync(
        () => Container(width: 32, height: 20, color: Colors.cyan)
            .toGroundOverlayBitmap(
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(32, 20),
                pixelRatio: 1.0,
              ),
            ),
      );

      expect(bitmap, isA<BytesMapBitmap>());
      expect(bitmap!.bitmapScaling, MapBitmapScaling.none);
    });

    testWidgets('toBitmapGlyph works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final glyph = await tester.runAsync(
        () =>
            Container(width: 20, height: 20, color: Colors.pink).toBitmapGlyph(
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(20, 20),
                pixelRatio: 1.0,
              ),
              bitmapOptions: const MapBitmapOptions(imagePixelRatio: 2.0),
            ),
      );

      expect(glyph, isA<BitmapGlyph>());
      expect(((glyph!.bitmap as BytesMapBitmap).imagePixelRatio), 2.0);
    });

    testWidgets('toMarkerIcon works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final icon = await tester.runAsync(
        () =>
            Container(width: 30, height: 30, color: Colors.green).toMarkerIcon(
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(30, 30),
                pixelRatio: 1.0,
              ),
            ),
      );

      expect(icon, isA<MarkerIcon>());
      expect(icon!.logicalSize, const Size(30, 30));
      expect(icon.pixelRatio, 1.0);
    });

    testWidgets('toMarker works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final marker = await tester.runAsync(
        () => Container(width: 28, height: 28, color: Colors.brown).toMarker(
          base: const Marker(
            markerId: MarkerId('top-level-marker'),
            position: LatLng(5, 6),
            zIndexInt: 4,
          ),
          renderOptions: const WidgetBitmapRenderOptions(
            logicalSize: Size(28, 28),
            pixelRatio: 1.0,
          ),
        ),
      );

      expect(marker, isA<Marker>());
      expect(marker!.markerId, const MarkerId('top-level-marker'));
      expect(marker.position, const LatLng(5, 6));
      expect(marker.zIndexInt, 4);
    });

    testWidgets('toAdvancedMarker works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final marker = await tester.runAsync(
        () => Container(width: 28, height: 28, color: Colors.deepOrange)
            .toAdvancedMarker(
              base: AdvancedMarker(
                markerId: const MarkerId('top-level-advanced'),
                position: const LatLng(8, 9),
              ),
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(28, 28),
                pixelRatio: 1.0,
              ),
            ),
      );

      expect(marker, isA<AdvancedMarker>());
      expect(marker!.markerId, const MarkerId('top-level-advanced'));
    });

    testWidgets('toAdvancedPinMarker works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final marker = await tester.runAsync(
        () => Container(width: 24, height: 24, color: Colors.teal)
            .toAdvancedPinMarker(
              base: AdvancedMarker(
                markerId: const MarkerId('top-level-pin'),
                position: const LatLng(10, 11),
              ),
              backgroundColor: Colors.black,
              borderColor: Colors.teal,
              renderOptions: const WidgetBitmapRenderOptions(
                logicalSize: Size(24, 24),
                pixelRatio: 1.0,
              ),
            ),
      );

      expect(marker, isA<AdvancedMarker>());
      expect(marker!.markerId, const MarkerId('top-level-pin'));
      expect(marker.icon, isA<PinConfig>());
    });
  });
}
