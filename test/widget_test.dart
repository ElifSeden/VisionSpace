import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decorator_ai/features/notifications/notifications_page.dart';
import 'package:decorator_ai/features/onboarding/onboarding_flow_page.dart';
import 'package:decorator_ai/features/product/product_detail_page.dart';
import 'package:decorator_ai/features/profile/profile_page.dart';
import 'package:decorator_ai/features/scan/scan_page.dart';
import 'package:decorator_ai/main.dart';
import 'package:decorator_ai/l10n/app_localizations.dart';
import 'package:decorator_ai/models/design_project.dart';
import 'package:decorator_ai/navigation/app_shell.dart';
import 'package:decorator_ai/services/app_notification_service.dart';
import 'package:decorator_ai/services/decorator_ai_api.dart';

void main() {
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

    expect(find.text('Scan Your Room'), findsOneWidget);
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
      expect(find.text('Scan Your Room'), findsOneWidget);
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

    expect(find.text('Start Scan'), findsOneWidget);

    await tester.tap(find.text('Start Scan'));
    await tester.pump();

    expect(find.byType(ScanPage), findsOneWidget);
    expect(find.text('Scan Your Room'), findsOneWidget);
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

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('New AI Design Ready'), findsOneWidget);
    expect(find.text('Added to Favorites'), findsOneWidget);
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
}
