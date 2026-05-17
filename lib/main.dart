import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/welcome/welcome_page.dart';
import 'l10n/app_localizations.dart';
import 'navigation/app_shell.dart';
import 'services/decorator_ai_api.dart';
import 'services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    firebaseInitialized = true;
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  await NotificationService.instance.initialize(
    enableRemoteNotifications: firebaseInitialized,
  );
  await GoogleSignIn.instance.initialize();

  runApp(const DecoratorAiApp());
}

class DecoratorAiApp extends StatefulWidget {
  const DecoratorAiApp({this.homeApi, super.key});

  final DecoratorAiApi? homeApi;

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_DecoratorAiAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<DecoratorAiApp> createState() => _DecoratorAiAppState();
}

class _DecoratorAiAppState extends State<DecoratorAiApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('pref_language');
    if (langCode != null) {
      setState(() {
        _locale = Locale(langCode);
      });
    }
  }

  void setLocale(Locale locale) async {
    setState(() {
      _locale = locale;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_language', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _locale,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _StartupPage(homeApi: widget.homeApi),
    );
  }
}

class _StartupPage extends StatefulWidget {
  const _StartupPage({this.homeApi});

  final DecoratorAiApi? homeApi;

  @override
  State<_StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<_StartupPage> {
  late final Future<Widget> _home = _loadHome();

  Future<Widget> _loadHome() async {
    final prefs = await SharedPreferences.getInstance();
    final hasEnteredApp = prefs.getBool(AppShell.enteredAppKey) ?? false;
    if (!hasEnteredApp) return WelcomePage(homeApi: widget.homeApi);

    final index = prefs.getInt(AppShell.selectedTabKey) ?? 0;
    return AppShell(initialIndex: index, homeApi: widget.homeApi);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _home,
      builder: (context, snapshot) {
        return snapshot.data ??
            const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
