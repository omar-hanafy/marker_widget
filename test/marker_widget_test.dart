import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_widget/marker_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarkerIcon', () {
    late Uint8List validPngBytes;

    setUp(() {
      // Minimal valid PNG bytes (1x1 transparent pixel)
      validPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);
    });

    test('creates with valid parameters', () {
      final icon = MarkerIcon(
        bytes: validPngBytes,
        logicalSize: const Size(100, 100),
        pixelRatio: 2.0,
      );

      expect(icon.bytes, validPngBytes);
      expect(icon.logicalSize, const Size(100, 100));
      expect(icon.pixelRatio, 2.0);
    });

    test('sizeInBytes returns correct byte count', () {
      final icon = MarkerIcon(
        bytes: validPngBytes,
        logicalSize: const Size(100, 100),
        pixelRatio: 2.0,
      );

      expect(icon.sizeInBytes, validPngBytes.lengthInBytes);
    });

    group('toMapBitmap', () {
      test('returns BytesMapBitmap with logicalSize mode', () {
        final icon = MarkerIcon(
          bytes: validPngBytes,
          logicalSize: const Size(80, 60),
          pixelRatio: 2.0,
        );

        final bitmap = icon.toMapBitmap(
          scalingMode: MarkerIconScalingMode.logicalSize,
        );

        expect(bitmap, isA<BytesMapBitmap>());
        expect(bitmap.width, 80);
        expect(bitmap.height, 60);
      });

      test('returns BytesMapBitmap with imagePixelRatio mode', () {
        final icon = MarkerIcon(
          bytes: validPngBytes,
          logicalSize: const Size(80, 60),
          pixelRatio: 3.0,
        );

        final bitmap = icon.toMapBitmap(
          scalingMode: MarkerIconScalingMode.imagePixelRatio,
        );

        expect(bitmap, isA<BytesMapBitmap>());
        expect(bitmap.imagePixelRatio, 3.0);
      });

      test('throws StateError for empty bytes', () {
        final icon = MarkerIcon(
          bytes: Uint8List(0),
          logicalSize: const Size(100, 100),
          pixelRatio: 2.0,
        );

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

      test('throws StateError for MapBitmapScaling.none', () {
        final icon = MarkerIcon(
          bytes: validPngBytes,
          logicalSize: const Size(100, 100),
          pixelRatio: 2.0,
        );

        expect(
          () => icon.toMapBitmap(bitmapScaling: MapBitmapScaling.none),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('does not support MapBitmapScaling.none'),
            ),
          ),
        );
      });

      test('throws StateError for non-positive logicalSize width', () {
        final icon = MarkerIcon(
          bytes: validPngBytes,
          logicalSize: const Size(0, 100),
          pixelRatio: 2.0,
        );

        expect(
          () => icon.toMapBitmap(
            scalingMode: MarkerIconScalingMode.logicalSize,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('must be > 0 in both dimensions'),
            ),
          ),
        );
      });

      test('throws StateError for non-positive logicalSize height', () {
        final icon = MarkerIcon(
          bytes: validPngBytes,
          logicalSize: const Size(100, -5),
          pixelRatio: 2.0,
        );

        expect(
          () => icon.toMapBitmap(
            scalingMode: MarkerIconScalingMode.logicalSize,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('must be > 0 in both dimensions'),
            ),
          ),
        );
      });

      test('throws StateError for non-positive pixelRatio in imagePixelRatio mode', () {
        final icon = MarkerIcon(
          bytes: validPngBytes,
          logicalSize: const Size(100, 100),
          pixelRatio: 0,
        );

        expect(
          () => icon.toMapBitmap(
            scalingMode: MarkerIconScalingMode.imagePixelRatio,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('pixelRatio must be > 0'),
            ),
          ),
        );
      });
    });

    group('toBitmapDescriptor', () {
      test('returns BitmapDescriptor (delegates to toMapBitmap)', () {
        final icon = MarkerIcon(
          bytes: validPngBytes,
          logicalSize: const Size(100, 100),
          pixelRatio: 2.0,
        );

        final descriptor = icon.toBitmapDescriptor();

        expect(descriptor, isA<BitmapDescriptor>());
        expect(descriptor, isA<BytesMapBitmap>());
      });
    });
  });

  group('MarkerIconRenderer', () {
    test('creates with default parameters', () {
      final renderer = MarkerIconRenderer();

      expect(renderer.defaultLogicalSize, const Size(96, 96));
      expect(renderer.enableCaching, true);
      expect(renderer.maxCacheEntries, 64);
      expect(renderer.maxCacheBytes, 50 * 1024 * 1024);
      expect(renderer.cacheSize, 0);
      expect(renderer.cacheSizeInBytes, 0);
    });

    test('creates with custom parameters', () {
      final renderer = MarkerIconRenderer(
        defaultLogicalSize: const Size(64, 64),
        enableCaching: false,
        maxCacheEntries: 32,
        maxCacheBytes: 10 * 1024 * 1024,
        initialImageDelay: const Duration(milliseconds: 50),
        imageRepaintDelay: const Duration(milliseconds: 300),
      );

      expect(renderer.defaultLogicalSize, const Size(64, 64));
      expect(renderer.enableCaching, false);
      expect(renderer.maxCacheEntries, 32);
      expect(renderer.maxCacheBytes, 10 * 1024 * 1024);
    });

    test('asserts on non-positive maxCacheEntries', () {
      expect(
        () => MarkerIconRenderer(maxCacheEntries: 0),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => MarkerIconRenderer(maxCacheEntries: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    group('render', () {
      test('throws ArgumentError for non-positive logicalSize', () async {
        final renderer = MarkerIconRenderer();

        await expectLater(
          renderer.render(
            const SizedBox(),
            logicalSize: const Size(0, 100),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('must both be > 0'),
            ),
          ),
        );

        await expectLater(
          renderer.render(
            const SizedBox(),
            logicalSize: const Size(100, -10),
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

      test('throws ArgumentError for non-positive pixelRatio', () async {
        final renderer = MarkerIconRenderer();

        await expectLater(
          renderer.render(
            const SizedBox(),
            logicalSize: const Size(100, 100),
            pixelRatio: 0,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('pixelRatio must be > 0'),
            ),
          ),
        );

        await expectLater(
          renderer.render(
            const SizedBox(),
            logicalSize: const Size(100, 100),
            pixelRatio: -1,
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
    });

    group('cache operations', () {
      test('clearCache resets cache state', () async {
        final renderer = MarkerIconRenderer();

        // Can't easily populate cache without rendering, but we can test
        // that clearCache doesn't throw and resets counters
        renderer.clearCache();

        expect(renderer.cacheSize, 0);
        expect(renderer.cacheSizeInBytes, 0);
      });

      test('isCached returns false for non-existent key', () {
        final renderer = MarkerIconRenderer();

        expect(renderer.isCached('non-existent-key'), false);
      });

      test('peekCache returns null for non-existent key', () {
        final renderer = MarkerIconRenderer();

        expect(renderer.peekCache('non-existent-key'), null);
      });

      test('removeFromCache handles non-existent key gracefully', () {
        final renderer = MarkerIconRenderer();

        // Should not throw
        renderer.removeFromCache('non-existent-key');

        expect(renderer.cacheSize, 0);
      });
    });
  });

  group('buildMarkerCacheKey', () {
    test('generates consistent key with all parameters', () {
      final key1 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
        brightness: Brightness.light,
        locale: const Locale('en', 'US'),
      );

      final key2 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
        brightness: Brightness.light,
        locale: const Locale('en', 'US'),
      );

      expect(key1, key2);
    });

    test('generates different keys for different ids', () {
      final key1 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
      );

      final key2 = buildMarkerCacheKey(
        id: 'user-456',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
      );

      expect(key1, isNot(key2));
    });

    test('generates different keys for different sizes', () {
      final key1 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
      );

      final key2 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(100, 100),
        pixelRatio: 2.0,
      );

      expect(key1, isNot(key2));
    });

    test('generates different keys for different pixel ratios', () {
      final key1 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
      );

      final key2 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 3.0,
      );

      expect(key1, isNot(key2));
    });

    test('generates different keys for different brightness', () {
      final key1 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
        brightness: Brightness.light,
      );

      final key2 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
        brightness: Brightness.dark,
      );

      expect(key1, isNot(key2));
    });

    test('generates different keys for different locales', () {
      final key1 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
        locale: const Locale('en', 'US'),
      );

      final key2 = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
        locale: const Locale('ar', 'EG'),
      );

      expect(key1, isNot(key2));
    });

    test('handles null brightness and locale', () {
      final key = buildMarkerCacheKey(
        id: 'user-123',
        logicalSize: const Size(80, 80),
        pixelRatio: 2.0,
      );

      expect(key, contains('brightness=none'));
      expect(key, contains('locale=xx'));
    });

    test('key contains all expected components', () {
      final key = buildMarkerCacheKey(
        id: 'test-id',
        logicalSize: const Size(64, 48),
        pixelRatio: 2.5,
        brightness: Brightness.dark,
        locale: const Locale('fr', 'CA'),
      );

      expect(key, contains('id=test-id'));
      expect(key, contains('size=64.0x48.0'));
      expect(key, contains('dpr=2.5'));
      expect(key, contains('brightness=dark'));
      expect(key, contains('locale=fr-CA'));
    });
  });

  group('MarkerIconScalingMode', () {
    test('has expected values', () {
      expect(MarkerIconScalingMode.values, hasLength(2));
      expect(
        MarkerIconScalingMode.values,
        contains(MarkerIconScalingMode.logicalSize),
      );
      expect(
        MarkerIconScalingMode.values,
        contains(MarkerIconScalingMode.imagePixelRatio),
      );
    });
  });

  // Integration tests that perform actual off-screen rendering.
  // These use tester.runAsync because toImage() requires real async execution.
  group('Widget rendering integration', () {
    testWidgets('renders simple widget to MarkerIcon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      final renderer = MarkerIconRenderer();

      final icon = await tester.runAsync(() => renderer.render(
        Container(width: 50, height: 50, color: Colors.red),
        context: context,
        logicalSize: const Size(50, 50),
        pixelRatio: 1.0,
      ));

      expect(icon, isA<MarkerIcon>());
      expect(icon!.bytes, isNotEmpty);
      expect(icon.logicalSize, const Size(50, 50));
      expect(icon.pixelRatio, 1.0);
    });

    testWidgets('toMarkerBitmap extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );

      final context = tester.element(find.byType(Scaffold));

      final descriptor = await tester.runAsync(
        () => Container(width: 40, height: 40, color: Colors.blue).toMarkerBitmap(
          context,
          logicalSize: const Size(40, 40),
        ),
      );

      expect(descriptor, isA<BitmapDescriptor>());
      expect(descriptor, isA<BytesMapBitmap>());
    });

    testWidgets('toMapBitmap extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );

      final context = tester.element(find.byType(Scaffold));

      final bitmap = await tester.runAsync(
        () => Container(width: 40, height: 40, color: Colors.green).toMapBitmap(
          context,
          logicalSize: const Size(40, 40),
        ),
      );

      expect(bitmap, isA<BytesMapBitmap>());
      expect(bitmap!.width, 40);
      expect(bitmap.height, 40);
    });

    testWidgets('toMarkerIcon extension works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );

      final context = tester.element(find.byType(Scaffold));

      final icon = await tester.runAsync(
        () => Container(width: 40, height: 40, color: Colors.yellow).toMarkerIcon(
          context,
          logicalSize: const Size(40, 40),
        ),
      );

      expect(icon, isA<MarkerIcon>());
      expect(icon!.bytes, isNotEmpty);
    });

    testWidgets('caching returns same icon for same key', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      final renderer = MarkerIconRenderer();
      const cacheKey = 'test-cache-key';

      final icon1 = await tester.runAsync(() => renderer.render(
        Container(width: 30, height: 30, color: Colors.red),
        context: context,
        logicalSize: const Size(30, 30),
        cacheKey: cacheKey,
      ));

      expect(renderer.isCached(cacheKey), true);
      expect(renderer.cacheSize, 1);

      final icon2 = await tester.runAsync(() => renderer.render(
        Container(width: 30, height: 30, color: Colors.blue), // Different widget!
        context: context,
        logicalSize: const Size(30, 30),
        cacheKey: cacheKey, // Same cache key
      ));

      // Should return cached version (icon1), not render the blue one
      expect(identical(icon1, icon2), true);
      expect(renderer.cacheSize, 1); // Still only 1 entry
    });

    testWidgets('renders themed widget correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: Brightness.light,
            ),
          ),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      final renderer = MarkerIconRenderer();

      // Widget that uses theme
      final icon = await tester.runAsync(() => renderer.render(
        Builder(
          builder: (ctx) => Container(
            width: 50,
            height: 50,
            color: Theme.of(ctx).colorScheme.primary,
          ),
        ),
        context: context,
        logicalSize: const Size(50, 50),
      ));

      expect(icon!.bytes, isNotEmpty);
    });

    testWidgets('render does not cache when enableCaching is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final renderer = MarkerIconRenderer(enableCaching: false);
      final context = tester.element(find.byType(Scaffold));
      const cacheKey = 'no-cache';

      final icon1 = await tester.runAsync(() => renderer.render(
        const SizedBox(),
        context: context,
        logicalSize: const Size(20, 20),
        cacheKey: cacheKey,
      ));

      final icon2 = await tester.runAsync(() => renderer.render(
        const SizedBox(),
        context: context,
        logicalSize: const Size(20, 20),
        cacheKey: cacheKey,
      ));

      // Should not be cached → different instances
      expect(identical(icon1, icon2), isFalse);
      expect(renderer.cacheSize, 0);
    });

    testWidgets('cache evicts least recently used by maxCacheEntries', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));
      final renderer = MarkerIconRenderer(
        maxCacheEntries: 2,
        maxCacheBytes: null, // disable memory-based eviction
      );

      Future<void> renderWithKey(String key) => tester.runAsync(
        () => renderer.render(
          const SizedBox(),
          context: context,
          logicalSize: const Size(20, 20),
          cacheKey: key,
        ),
      );

      await renderWithKey('a'); // cache: [a]
      await renderWithKey('b'); // cache: [a, b]
      expect(renderer.isCached('a'), isTrue);
      expect(renderer.isCached('b'), isTrue);

      await renderWithKey('c'); // should evict 'a', keep [b, c]
      expect(renderer.isCached('a'), isFalse);
      expect(renderer.isCached('b'), isTrue);
      expect(renderer.isCached('c'), isTrue);
    });

    testWidgets('concurrent renders with same cacheKey share the same result', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));
      final renderer = MarkerIconRenderer();
      const cacheKey = 'concurrent-key';

      final results = await tester.runAsync(
        () => Future.wait<MarkerIcon>([
          renderer.render(
            const SizedBox(),
            context: context,
            logicalSize: const Size(24, 24),
            cacheKey: cacheKey,
          ),
          renderer.render(
            const SizedBox(),
            context: context,
            logicalSize: const Size(24, 24),
            cacheKey: cacheKey,
          ),
        ]),
      );

      final icon1 = results![0];
      final icon2 = results[1];

      expect(identical(icon1, icon2), isTrue);
      expect(renderer.cacheSize, 1);
    });

    testWidgets('oversized items are not cached when exceeding maxCacheBytes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));
      final renderer = MarkerIconRenderer(
        maxCacheEntries: 10,
        maxCacheBytes: 1, // absurdly small - any icon will exceed this
      );

      await tester.runAsync(() => renderer.render(
        const SizedBox(),
        context: context,
        logicalSize: const Size(10, 10),
        cacheKey: 'oversized',
      ));

      // Icon exceeds maxCacheBytes, so it should NOT be cached
      expect(renderer.cacheSize, 0);
      expect(renderer.cacheSizeInBytes, 0);
      expect(renderer.isCached('oversized'), isFalse);
    });

    testWidgets('maxCacheBytes evicts older items to make room', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));

      // First, render one icon to measure its size
      final measureRenderer = MarkerIconRenderer(maxCacheBytes: null);
      final sampleIcon = await tester.runAsync(() => measureRenderer.render(
        const SizedBox(),
        context: context,
        logicalSize: const Size(10, 10),
        cacheKey: 'measure',
      ));
      final iconSize = sampleIcon!.sizeInBytes;

      // Now create renderer with maxCacheBytes that fits exactly 1 icon
      final renderer = MarkerIconRenderer(
        maxCacheEntries: 10,
        maxCacheBytes: iconSize, // fits exactly 1 icon
      );

      await tester.runAsync(() => renderer.render(
        const SizedBox(),
        context: context,
        logicalSize: const Size(10, 10),
        cacheKey: 'first',
      ));

      expect(renderer.cacheSize, 1);
      expect(renderer.isCached('first'), isTrue);

      await tester.runAsync(() => renderer.render(
        const SizedBox(),
        context: context,
        logicalSize: const Size(10, 10),
        cacheKey: 'second',
      ));

      // Second icon should evict first to stay within memory limit
      expect(renderer.cacheSize, 1);
      expect(renderer.isCached('first'), isFalse);
      expect(renderer.isCached('second'), isTrue);
    });

    testWidgets('clearCache after rendering resets state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      final context = tester.element(find.byType(Scaffold));
      final renderer = MarkerIconRenderer();

      await tester.runAsync(() => renderer.render(
        const SizedBox(),
        context: context,
        logicalSize: const Size(10, 10),
        cacheKey: 'clear-test',
      ));

      expect(renderer.cacheSize, 1);
      expect(renderer.cacheSizeInBytes, greaterThan(0));

      renderer.clearCache();

      expect(renderer.cacheSize, 0);
      expect(renderer.cacheSizeInBytes, 0);
    });
  });

  // Tests for top-level helper functions (no BuildContext required)
  group('Top-level helper functions', () {
    testWidgets('widgetToMarkerBitmap works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final descriptor = await tester.runAsync(
        () => widgetToMarkerBitmap(
          Container(width: 30, height: 30, color: Colors.red),
          logicalSize: const Size(30, 30),
          pixelRatio: 1.0,
        ),
      );

      expect(descriptor, isA<BitmapDescriptor>());
      expect(descriptor, isA<BytesMapBitmap>());
    });

    testWidgets('widgetToMapBitmap works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final bitmap = await tester.runAsync(
        () => widgetToMapBitmap(
          Container(width: 30, height: 30, color: Colors.blue),
          logicalSize: const Size(30, 30),
          pixelRatio: 1.0,
        ),
      );

      expect(bitmap, isA<BytesMapBitmap>());
      expect(bitmap!.width, 30);
      expect(bitmap.height, 30);
    });

    testWidgets('widgetToMarkerIcon works without context', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      final icon = await tester.runAsync(
        () => widgetToMarkerIcon(
          Container(width: 30, height: 30, color: Colors.green),
          logicalSize: const Size(30, 30),
          pixelRatio: 1.0,
        ),
      );

      expect(icon, isA<MarkerIcon>());
      expect(icon!.bytes, isNotEmpty);
      expect(icon.logicalSize, const Size(30, 30));
      expect(icon.pixelRatio, 1.0);
    });
  });
}

