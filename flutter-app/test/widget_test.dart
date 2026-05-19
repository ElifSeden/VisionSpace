import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:decorator_ai/core/config/backend_config.dart';
import 'package:decorator_ai/features/design/design_detail_page.dart';
import 'package:decorator_ai/features/favorites/favorites_page.dart';
import 'package:decorator_ai/features/notifications/notifications_page.dart';
import 'package:decorator_ai/features/onboarding/onboarding_flow_page.dart';
import 'package:decorator_ai/features/product/product_detail_page.dart';
import 'package:decorator_ai/features/profile/profile_page.dart';
import 'package:decorator_ai/features/scan/scan_page.dart';
import 'package:decorator_ai/main.dart';
import 'package:decorator_ai/l10n/app_localizations.dart';
import 'package:decorator_ai/models/design_project.dart';
import 'package:decorator_ai/models/product_spot.dart';
import 'package:decorator_ai/navigation/app_shell.dart';
import 'package:decorator_ai/services/app_notification_service.dart';
import 'package:decorator_ai/services/ai_backend_client.dart';
import 'package:decorator_ai/services/decorator_ai_api.dart';
import 'package:decorator_ai/services/product_favorite_service.dart';

void main() {
  test('scan design options serialize backend request fields', () {
    const options = ScanDesignOptions(
      currentWallLengthCm: 420,
      roomDepthCm: 360,
      ceilingHeightCm: 275,
      replaceExistingFurniture: true,
      requestedFurnitureTypes: ['sofa', 'coffee_table'],
      designStyle: 'scandinavian',
      material: 'wood',
      colors: ['beige', 'oak'],
      temperature: 'warm',
      designCount: 3,
    );

    expect(options.roomDimensions['current_wall_length_cm'], 420);
    expect(options.roomDimensions['room_depth_cm'], 360);
    expect(options.preferences['mode'], 'guided_design');
    expect(options.preferences['replace_existing_furniture'], isTrue);
    expect(options.preferences['requested_furniture_types'], [
      'sofa',
      'coffee_table',
    ]);
    expect(options.preferences['design_style'], 'scandinavian');
    expect(options.preferences['material'], 'wood');
    expect(options.preferences['colors'], ['beige', 'oak']);
    expect(options.designCount, 3);
  });

  test('backend config normalizes and persists server URLs', () async {
    SharedPreferences.setMockInitialValues({});

    await BackendConfig.instance.load();
    expect(BackendConfig.instance.baseUrl, startsWith('http://'));
    expect(BackendConfig.instance.baseUrl, endsWith(':8000'));

    await BackendConfig.instance.setBaseUrl('api.example.com/');
    expect(BackendConfig.instance.baseUrl, 'http://api.example.com');

    await BackendConfig.instance.setBaseUrl('https://api.example.com/v1/');
    expect(BackendConfig.instance.baseUrl, 'https://api.example.com/v1');
  });

  test('backend product mapping normalizes score and image paths', () {
    final product = ProductSpot.fromBackendJson(
      const {
        'product_id': 'p1',
        'name': 'Oak Coffee Table',
        'role': 'coffee_table',
        'category': 'floor_lamp',
        'store_name': 'IKEA',
        'score': 0.91,
        'image_path': 'products/oak/main.jpg',
        'source_url': 'https://store.example/item',
        'price': {'amount': 1250, 'currency': 'TL'},
      },
      polygon: const [
        [100, 100],
        [300, 100],
        [300, 300],
        [100, 300],
      ],
      imageWidth: 400,
      imageHeight: 400,
      imageUrlBuilder: (path) => 'http://localhost:8000/images/$path',
    );

    expect(product.matchScore, 91);
    expect(product.left, 0.5);
    expect(product.top, 0.5);
    expect(
      product.imageUrl,
      'http://localhost:8000/images/products/oak/main.jpg',
    );
    expect(product.buyUrl, 'https://store.example/item');
    expect(product.storeName, 'IKEA');
    expect(product.brand, 'IKEA');
    expect(product.brand, isNot('coffee_table'));
    expect(product.brand, isNot('floor_lamp'));
  });

  test('backend normalized placement polygons map directly to hotspots', () {
    final product = ProductSpot.fromBackendJson(
      const {
        'product_id': 'p2',
        'name': 'Small Side Table',
        'store_name': 'Vivense',
        'score': 87,
      },
      polygon: const [
        [0.40, 0.60],
        [0.60, 0.60],
        [0.60, 0.80],
        [0.40, 0.80],
      ],
      imageWidth: 1200,
      imageHeight: 800,
    );

    expect(product.left, closeTo(0.5, 0.001));
    expect(product.top, closeTo(0.7, 0.001));
  });

  test('backend design mapping uses final render instead of debug mask', () {
    final project = DesignProject.fromBackendJson(
      const {
        'design_id': 'd1',
        'title': 'Rendered Room',
        'style': 'modern',
        'final_rendered_image_url': 'generated/job/design_1_composite.png',
        'debug_mask_url': 'generated/job/design_1_mask_0.png',
        'products': <Map<String, dynamic>>[],
      },
      roomImageUrl: 'http://localhost:8000/images/rooms/original.png',
      imageUrlBuilder: (path) => 'http://localhost:8000/images/$path',
    );

    expect(
      project.imageUrl,
      'http://localhost:8000/images/generated/job/design_1_composite.png',
    );
    expect(project.imageUrl, isNot(contains('mask')));
  });

  testWidgets('product detail normalizes technical backend store names', (
    WidgetTester tester,
  ) async {
    const product = ProductSpot(
      id: 'p-technical-store',
      name: 'Floor Lamp',
      brand: 'floor_lamp',
      price: '1250 TL',
      matchScore: 91,
      left: 0.5,
      top: 0.5,
      imageUrl: 'https://example.com/lamp.jpg',
      buyUrl: 'https://www.ikea.com.tr/urun/lamp',
      storeName: 'floor_lamp',
    );

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProductDetailPage(product: product),
      ),
    );
    await tester.pump();

    expect(find.text('IKEA'), findsWidgets);
    expect(find.text('floor_lamp'), findsNothing);
  });

  testWidgets(
    'product detail heart favorite button persists without parent callback',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      const product = ProductSpot(
        id: 'ai-product-1',
        name: 'AI Matched Chair',
        brand: 'Matched product',
        price: '900 TL',
        matchScore: 87,
        left: 0.5,
        top: 0.5,
        imageUrl: 'https://example.com/chair.jpg',
        buyUrl: 'https://example.com/chair',
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProductDetailPage(product: product),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump();
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(ProductFavoriteService.storageKey),
        contains('ai-product-1'),
      );
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    },
  );

  testWidgets('decorator_ai welcome screen loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DecoratorAiApp());
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.appBrand), findsOneWidget);
    expect(find.text(l10n.welcomeStartScan), findsOneWidget);
  });

  testWidgets('startup restores the persisted scan tab', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppShell.enteredAppKey: true,
      AppShell.selectedTabKey: 1,
    });

    await tester.pumpWidget(const DecoratorAiApp(homeApi: _ImmediateApi()));
    await tester.pump();
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.scanYourRoom), findsOneWidget);
    expect(find.text(l10n.welcomeStartScan), findsNothing);
  });

  testWidgets(
    'welcome scan CTA opens onboarding and preserves the scan target',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const DecoratorAiApp(homeApi: _ImmediateApi()));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.welcomeStartScan));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l10n.onboardingScratchQuestion), findsOneWidget);

      for (var i = 0; i < 4; i += 1) {
        await tester.tap(find.text(l10n.onboardingSkip));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));

      final prefs = await SharedPreferences.getInstance();
      expect(find.text(l10n.scanYourRoom), findsOneWidget);
      expect(prefs.getBool(AppShell.enteredAppKey), isTrue);
      expect(prefs.getInt(AppShell.selectedTabKey), 1);
    },
  );

  testWidgets(
    'onboarding map location stage selects coordinates and text inputs validate',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingFlowPage(targetIndex: 0, homeApi: _ImmediateApi()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(l10n.onboardingSkip));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.onboardingLocationQuestion), findsOneWidget);
      expect(
        find.byKey(const ValueKey('onboarding-location-map')),
        findsOneWidget,
      );
      expect(find.text(l10n.onboardingSkip), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      expect(find.text(l10n.onboardingScratchQuestion), findsOneWidget);

      await tester.tap(find.text(l10n.onboardingSkip));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.onboardingLocationQuestion), findsOneWidget);
      expect(find.text(l10n.onboardingSkip), findsOneWidget);

      final mapCenterBtn = find.byKey(
        const ValueKey('onboarding-select-map-center'),
      );
      await tester.ensureVisible(mapCenterBtn);
      await tester.tap(mapCenterBtn);
      await tester.pump();
      expect(find.text(l10n.onboardingNext), findsOneWidget);

      await tester.tap(find.text(l10n.onboardingNext));
      await tester.pump();
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(find.text(l10n.onboardingAgeQuestion), findsOneWidget);
      expect(editable.focusNode.hasFocus, isTrue);

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-age-field')),
        '9',
      );
      await tester.pump();
      await tester.tap(find.text(l10n.onboardingNext));
      await tester.pump();
      expect(find.text(l10n.onboardingAgeInvalid), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-age-field')),
        '35',
      );
      await tester.pump();
      await tester.tap(find.text(l10n.onboardingNext));
      await tester.pump();

      await tester.ensureVisible(find.text(l10n.onboardingLivingFamily));
      await tester.tap(find.text(l10n.onboardingLivingFamily));
      await tester.pump();
      await tester.tap(find.text(l10n.onboardingNext));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getDouble(OnboardingFlowPage.locationLatitudeKey),
        isNotNull,
      );
      expect(
        prefs.getDouble(OnboardingFlowPage.locationLongitudeKey),
        isNotNull,
      );
      expect(prefs.getInt(OnboardingFlowPage.ageKey), 35);
      expect(prefs.getString(OnboardingFlowPage.livingSituationKey), 'family');
      expect(prefs.getInt(AppShell.selectedTabKey), 0);
    },
  );

  testWidgets('new scan card opens the scan tab', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppShell(homeApi: _ImmediateApi()),
      ),
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.startScan), findsOneWidget);

    await tester.tap(find.text(l10n.startScan));
    await tester.pump();

    expect(find.byType(ScanPage), findsOneWidget);
    expect(find.text(l10n.scanYourRoom), findsOneWidget);
  });

  testWidgets('scan page exposes backend design brief controls', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ScanPage()),
      ),
    );
    await tester.pump();

    expect(find.text(l10n.scanPreferencesTitle), findsOneWidget);

    // Expand the preferences card to make inner options visible
    await tester.tap(find.text(l10n.scanPreferencesTitle));
    await tester.pumpAndSettle();

    expect(find.text(l10n.scanRoomWidthLabel), findsOneWidget);
    expect(find.text(l10n.scanReplaceFurnitureLabel), findsOneWidget);

    final sofaFinder = find.widgetWithText(
      CheckboxListTile,
      l10n.scanFurnitureSofa,
    );
    await tester.ensureVisible(sofaFinder);
    await tester.pumpAndSettle();
    await tester.tap(sofaFinder);
    await tester.pump();

    final styleFinder = find.widgetWithText(
      ChoiceChip,
      l10n.scanStyleScandinavian,
    );
    await tester.ensureVisible(styleFinder);
    await tester.pumpAndSettle();
    await tester.tap(styleFinder);
    await tester.pump();

    final sofaTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, l10n.scanFurnitureSofa),
    );
    final styleChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, l10n.scanStyleScandinavian),
    );
    expect(sofaTile.value, isTrue);
    expect(styleChip.selected, isTrue);
  });

  testWidgets('tapping example furniture card opens product detail', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppShell(homeApi: _ImmediateApi()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final sofaFinder = find.text('Modern Sofa').first;

    // Scroll down to make it visible (from ~910 to ~410 on a 600 height screen)
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pump();
    await tester.pump();

    // Tap the first example furniture
    await tester.tap(sofaFinder);
    await tester.pump();
    await tester.pump();

    expect(find.byType(ProductDetailPage), findsOneWidget);
    expect(find.text(l10n.productDetailTitle), findsOneWidget);
    expect(find.text('Find Similar Products with AI'), findsNothing);
  });

  testWidgets(
    'profile settings panel contains notification toggles and language selector',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileSettingsTitle), findsOneWidget);
      expect(find.text(l10n.profileSettingAuthReminders), findsOneWidget);
      expect(find.text(l10n.profileSettingAiUpdates), findsOneWidget);
      expect(find.text(l10n.profileSettingLanguage), findsOneWidget);
      expect(find.text('🇺🇸'), findsOneWidget);
    },
  );

  testWidgets('favorites page item opens product detail', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppShell.enteredAppKey: true,
      AppShell.selectedTabKey: 2, // Go to favorites tab directly
      'favorite_furniture_ids': [
        'modern-sofa',
        'wooden-chair',
      ], // Mock some favorite IDs
    });

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppShell(initialIndex: 2, homeApi: _ImmediateApi()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.savedTitle), findsWidgets);

    // Tap the favorite item (e.g. Modern Sofa which is usually id 1)
    final sofaFinder = find.text('Modern Sofa').first;
    await tester.ensureVisible(sofaFinder);
    await tester.tap(sofaFinder);
    await tester.pump();
    await tester.pump();

    expect(find.byType(ProductDetailPage), findsOneWidget);
    expect(find.text(l10n.productDetailTitle), findsOneWidget);
    expect(find.text('Find Similar Products with AI'), findsNothing);
  });

  testWidgets('favorites page separates generated AI designs from categories', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FavoritesPage(
            favoriteIds: const <String>{},
            onToggleFavorite: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(l10n.favoritesFurnitureTab), findsOneWidget);
    expect(find.text(l10n.favoritesDesignsTab), findsOneWidget);
    expect(find.text(l10n.categoryChair), findsOneWidget);

    await tester.tap(find.text(l10n.favoritesDesignsTab));
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.noGeneratedDesignsMessage), findsOneWidget);
    expect(find.text(l10n.categoryChair), findsNothing);
  });

  testWidgets('notifications page shows cards and correct title', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppNotificationService.instance.addAiDesignReady();
    await AppNotificationService.instance.addFavoriteAdded('Modern Sofa');

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NotificationsPage(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.notificationsTitle), findsOneWidget);
    expect(find.text(l10n.newAiDesignReady), findsOneWidget);
    expect(find.text(l10n.addedToFavorites), findsOneWidget);
  });

  testWidgets('DesignDetailPage does not contain the save/bookmark button', (WidgetTester tester) async {
    const project = DesignProject(
      id: 'd-test-1',
      title: 'Test Design Room',
      spaceType: 'living_room',
      style: 'modern',
      imageUrl: 'https://example.com/room.jpg',
      products: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DesignDetailPage(project: project),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
  });

  testWidgets('ScanPage does not contain the question mark help button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ScanPage()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
  });

  testWidgets('FavoritesPage contains a RefreshIndicator', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FavoritesPage(
            favoriteIds: const <String>{},
            onToggleFavorite: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  test('Image orientation normalization processes a valid image file', () async {
    final tempDir = Directory.systemTemp.createTempSync();
    final tempFile = File('${tempDir.path}/test_image.jpg');

    // Create a 1x1 image and encode to Jpg
    final testImg = img.Image(width: 1, height: 1);
    final jpegBytes = img.encodeJpg(testImg);
    await tempFile.writeAsBytes(jpegBytes);

    // Run the normalization logic
    final file = File(tempFile.path);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    expect(decoded, isNotNull);

    final oriented = img.bakeOrientation(decoded!);
    final orientedBytes = img.encodeJpg(oriented);
    await file.writeAsBytes(orientedBytes);

    // Verify it is still valid and readable
    final newBytes = await file.readAsBytes();
    final newDecoded = img.decodeImage(newBytes);
    expect(newDecoded, isNotNull);
    expect(newDecoded!.width, 1);
    expect(newDecoded.height, 1);

    tempDir.deleteSync(recursive: true);
  });
}

class _ImmediateApi implements DecoratorAiApi {
  const _ImmediateApi();

  @override
  Future<List<DesignProject>> fetchProjects() async {
    return const <DesignProject>[];
  }

  @override
  Future<DesignProject> analyzeSpace({required String scanId}) {
    throw UnimplementedError();
  }

  @override
  Future<DesignProject> submitAndPollScan({
    required File imageFile,
    ScanDesignOptions options = const ScanDesignOptions(),
    void Function(DesignJobResult)? onProgress,
  }) {
    throw UnimplementedError();
  }
}
