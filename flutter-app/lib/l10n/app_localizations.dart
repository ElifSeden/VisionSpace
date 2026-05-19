import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Application title used by the operating system and app shell.
  ///
  /// In en, this message translates to:
  /// **'Decorator AI'**
  String get appTitle;

  /// Visible product brand wordmark.
  ///
  /// In en, this message translates to:
  /// **'Decorator AI'**
  String get appBrand;

  /// Main welcome screen headline.
  ///
  /// In en, this message translates to:
  /// **'Scan your real space,\ndesign with AI,\nbuy what you love.'**
  String get welcomeHeadline;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A smart interior app that analyzes your home, office, or workplace and turns products into tappable shopping points.'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeInsight.
  ///
  /// In en, this message translates to:
  /// **'AI design suggestions and shopping matches are ready.'**
  String get welcomeInsight;

  /// No description provided for @welcomeStartScan.
  ///
  /// In en, this message translates to:
  /// **'Start Scanning the Space'**
  String get welcomeStartScan;

  /// No description provided for @welcomeExploreExamples.
  ///
  /// In en, this message translates to:
  /// **'Explore Example Designs'**
  String get welcomeExploreExamples;

  /// Progress label for onboarding question pages.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String onboardingStep(int current, int total);

  /// No description provided for @onboardingOptionalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional. Share what you want and skip the rest.'**
  String get onboardingOptionalSubtitle;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get onboardingYes;

  /// No description provided for @onboardingNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get onboardingNo;

  /// No description provided for @onboardingScratchQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you decorating your home from scratch?'**
  String get onboardingScratchQuestion;

  /// No description provided for @onboardingLocationQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where is your space located?'**
  String get onboardingLocationQuestion;

  /// No description provided for @onboardingLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow location to start near you, then tap the map to select your area.'**
  String get onboardingLocationSubtitle;

  /// No description provided for @onboardingUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get onboardingUseCurrentLocation;

  /// No description provided for @onboardingSelectMapCenter.
  ///
  /// In en, this message translates to:
  /// **'Select map center'**
  String get onboardingSelectMapCenter;

  /// No description provided for @onboardingLocationMapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to select your area.'**
  String get onboardingLocationMapHint;

  /// Confirmation text after a map coordinate is selected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {latitude}, {longitude}'**
  String onboardingLocationSelected(Object latitude, Object longitude);

  /// No description provided for @onboardingLocationServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are off. You can still tap the map.'**
  String get onboardingLocationServiceDisabled;

  /// No description provided for @onboardingLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied. You can still tap the map.'**
  String get onboardingLocationPermissionDenied;

  /// No description provided for @onboardingLocationPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked. You can still tap the map.'**
  String get onboardingLocationPermissionDeniedForever;

  /// No description provided for @onboardingLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current location is unavailable. You can still tap the map.'**
  String get onboardingLocationUnavailable;

  /// No description provided for @onboardingCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get onboardingCountryLabel;

  /// No description provided for @onboardingCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Türkiye, France, United States...'**
  String get onboardingCountryHint;

  /// No description provided for @onboardingAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get onboardingAreaLabel;

  /// No description provided for @onboardingAreaHint.
  ///
  /// In en, this message translates to:
  /// **'Gölbaşı, Le Marais, Manhattan...'**
  String get onboardingAreaHint;

  /// No description provided for @onboardingLocationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Select country, city, and area from the list.'**
  String get onboardingLocationInvalid;

  /// No description provided for @onboardingCityQuestion.
  ///
  /// In en, this message translates to:
  /// **'Which city are you located in?'**
  String get onboardingCityQuestion;

  /// No description provided for @onboardingCitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start typing and choose a city from the list.'**
  String get onboardingCitySubtitle;

  /// No description provided for @onboardingCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get onboardingCityLabel;

  /// No description provided for @onboardingCityHint.
  ///
  /// In en, this message translates to:
  /// **'Istanbul, London, New York...'**
  String get onboardingCityHint;

  /// No description provided for @onboardingCityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose a city from the list.'**
  String get onboardingCityInvalid;

  /// No description provided for @onboardingAgeQuestion.
  ///
  /// In en, this message translates to:
  /// **'How old are you?'**
  String get onboardingAgeQuestion;

  /// No description provided for @onboardingAgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get onboardingAgeLabel;

  /// No description provided for @onboardingAgeHint.
  ///
  /// In en, this message translates to:
  /// **'32'**
  String get onboardingAgeHint;

  /// No description provided for @onboardingAgeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an age between 16 and 120.'**
  String get onboardingAgeInvalid;

  /// No description provided for @onboardingLivingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you living alone or with your family?'**
  String get onboardingLivingQuestion;

  /// No description provided for @onboardingLivingAlone.
  ///
  /// In en, this message translates to:
  /// **'Living alone'**
  String get onboardingLivingAlone;

  /// No description provided for @onboardingLivingFamily.
  ///
  /// In en, this message translates to:
  /// **'With my family'**
  String get onboardingLivingFamily;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// No description provided for @navSaved.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navSaved;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @savedTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get savedTitle;

  /// No description provided for @savedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Furniture you favorite will be collected here.'**
  String get savedSubtitle;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account, address, and preference settings will connect to the backend.'**
  String get profileSubtitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-powered space design'**
  String get homeSubtitle;

  /// No description provided for @homeNewScanBadge.
  ///
  /// In en, this message translates to:
  /// **'New scan'**
  String get homeNewScanBadge;

  /// No description provided for @homeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan your space,\nwe will create your AI design.'**
  String get homeHeroTitle;

  /// No description provided for @homeHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Room size, light, style, and product detection will connect to this flow through the backend.'**
  String get homeHeroBody;

  /// No description provided for @homeSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Design Suggestions'**
  String get homeSuggestionsTitle;

  /// Design metadata shown under a design title.
  ///
  /// In en, this message translates to:
  /// **'{spaceType} • {style} • {count, plural, =0{no products matched} =1{1 product matched} other{{count} products matched}}'**
  String designMatchedProducts(Object spaceType, Object style, int count);

  /// No description provided for @designClickableProducts.
  ///
  /// In en, this message translates to:
  /// **'Tappable Products'**
  String get designClickableProducts;

  /// Similarity score for a matched product.
  ///
  /// In en, this message translates to:
  /// **'{score}% match'**
  String productMatchScore(int score);

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Space Scan'**
  String get scanTitle;

  /// No description provided for @scanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the camera and scan the space to create an AI design.'**
  String get scanSubtitle;

  /// No description provided for @scanInstruction.
  ///
  /// In en, this message translates to:
  /// **'When you press the button, the camera opens. After the photo is taken, the AI design flow starts.'**
  String get scanInstruction;

  /// No description provided for @scanCreateDesign.
  ///
  /// In en, this message translates to:
  /// **'Create AI Design'**
  String get scanCreateDesign;

  /// No description provided for @cameraNotFound.
  ///
  /// In en, this message translates to:
  /// **'No camera found.'**
  String get cameraNotFound;

  /// No description provided for @cameraCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Camera could not be started.'**
  String get cameraCouldNotStart;

  /// No description provided for @cameraCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan could not be captured. Try again.'**
  String get cameraCaptureFailed;

  /// No description provided for @cameraAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'AI is analyzing the space...'**
  String get cameraAnalyzing;

  /// No description provided for @cameraCaptureHint.
  ///
  /// In en, this message translates to:
  /// **'Frame the room, then press the scan button.'**
  String get cameraCaptureHint;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission was not granted. Allow camera permission from the browser to scan.'**
  String get cameraPermissionDenied;

  /// Camera error message with platform-provided details.
  ///
  /// In en, this message translates to:
  /// **'Camera could not be opened: {details}'**
  String cameraCouldNotOpen(Object details);

  /// No description provided for @cameraScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the Space'**
  String get cameraScanTitle;

  /// No description provided for @cameraOverlayHint.
  ///
  /// In en, this message translates to:
  /// **'Keep the walls, floor, light, and furniture visible so they can be detected.'**
  String get cameraOverlayHint;

  /// No description provided for @productSimilarWithAi.
  ///
  /// In en, this message translates to:
  /// **'Find Similar Products with AI'**
  String get productSimilarWithAi;

  /// No description provided for @productPurchaseOptions.
  ///
  /// In en, this message translates to:
  /// **'Purchase Options'**
  String get productPurchaseOptions;

  /// No description provided for @productDescriptionSofa.
  ///
  /// In en, this message translates to:
  /// **'Modern fabric three-seat sofa'**
  String get productDescriptionSofa;

  /// No description provided for @productDescriptionGeneric.
  ///
  /// In en, this message translates to:
  /// **'A similar product matched by AI according to the item in the design.'**
  String get productDescriptionGeneric;

  /// Compact product rating and review count.
  ///
  /// In en, this message translates to:
  /// **'{rating} ({reviewCount})'**
  String productRatingSummary(Object rating, int reviewCount);

  /// No description provided for @productDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Detail'**
  String get productDetailTitle;

  /// No description provided for @productGoToProduct.
  ///
  /// In en, this message translates to:
  /// **'View Product'**
  String get productGoToProduct;

  /// Shown when an external store URL cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'{storeName} link could not be opened.'**
  String productStoreOpenFailed(Object storeName);

  /// No description provided for @productSecurityNote.
  ///
  /// In en, this message translates to:
  /// **'You will go to the store\'s official page through a secure redirect.'**
  String get productSecurityNote;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved successfully.'**
  String get profileSaved;

  /// Error message when Google Sign-In fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign in with Google: {error}'**
  String profileGoogleSignInFailed(String error);

  /// No description provided for @profileDefaultUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileDefaultUser;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileNameLabel;

  /// No description provided for @profileSurnameLabel.
  ///
  /// In en, this message translates to:
  /// **'Surname'**
  String get profileSurnameLabel;

  /// No description provided for @profileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get profileNameRequired;

  /// No description provided for @profileSurnameRequired.
  ///
  /// In en, this message translates to:
  /// **'Surname is required'**
  String get profileSurnameRequired;

  /// No description provided for @profileEditCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileEditCancel;

  /// No description provided for @profileEditConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get profileEditConfirm;

  /// No description provided for @profileSignInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get profileSignInGoogle;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @profileBirthdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get profileBirthdayLabel;

  /// No description provided for @profileBirthdayNotSet.
  ///
  /// In en, this message translates to:
  /// **'Birthday not set'**
  String get profileBirthdayNotSet;

  /// No description provided for @profileSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get profileSettingsTitle;

  /// No description provided for @profileSettingAuthReminders.
  ///
  /// In en, this message translates to:
  /// **'Local Notifications'**
  String get profileSettingAuthReminders;

  /// No description provided for @profileSettingAiUpdates.
  ///
  /// In en, this message translates to:
  /// **'Remote Notifications'**
  String get profileSettingAiUpdates;

  /// No description provided for @authReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save your progress!'**
  String get authReminderTitle;

  /// No description provided for @authReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Don\'t lose your AI designs. Sign in with Google now.'**
  String get authReminderBody;

  /// No description provided for @authReminderRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Your spaces are waiting'**
  String get authReminderRecurringTitle;

  /// No description provided for @authReminderRecurringBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your AI designs across devices.'**
  String get authReminderRecurringBody;

  /// No description provided for @profileSettingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileSettingLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @noNotificationsMessage.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsMessage;

  /// No description provided for @noFavoritesMessage.
  ///
  /// In en, this message translates to:
  /// **'No favorite furniture yet. Tap a heart on the home screen to add one.'**
  String get noFavoritesMessage;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi {name} 👋'**
  String homeGreeting(Object name);

  /// No description provided for @homeGreetingFallback.
  ///
  /// In en, this message translates to:
  /// **'Hi 👋'**
  String get homeGreetingFallback;

  /// No description provided for @homeReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to redesign your room?'**
  String get homeReadySubtitle;

  /// No description provided for @categoryChair.
  ///
  /// In en, this message translates to:
  /// **'Chair'**
  String get categoryChair;

  /// No description provided for @categorySofa.
  ///
  /// In en, this message translates to:
  /// **'Sofa'**
  String get categorySofa;

  /// No description provided for @categoryTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get categoryTable;

  /// No description provided for @categoryLamp.
  ///
  /// In en, this message translates to:
  /// **'Lamp'**
  String get categoryLamp;

  /// No description provided for @categoryDecor.
  ///
  /// In en, this message translates to:
  /// **'Decor'**
  String get categoryDecor;

  /// No description provided for @recommendedFurniture.
  ///
  /// In en, this message translates to:
  /// **'Recommended Furniture'**
  String get recommendedFurniture;

  /// No description provided for @startScan.
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get startScan;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorks;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takeAPhoto;

  /// No description provided for @aiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis'**
  String get aiAnalysis;

  /// No description provided for @getIdeas.
  ///
  /// In en, this message translates to:
  /// **'Get Ideas'**
  String get getIdeas;

  /// No description provided for @scanYourRoom.
  ///
  /// In en, this message translates to:
  /// **'Scan Your Room'**
  String get scanYourRoom;

  /// No description provided for @scanPremiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capture your space and let AI suggest furniture that fits.'**
  String get scanPremiumSubtitle;

  /// No description provided for @scanPhotoDescription.
  ///
  /// In en, this message translates to:
  /// **'Frame your room clearly.'**
  String get scanPhotoDescription;

  /// No description provided for @scanAnalysisDescription.
  ///
  /// In en, this message translates to:
  /// **'AI analyzes style and layout.'**
  String get scanAnalysisDescription;

  /// No description provided for @scanIdeasDescription.
  ///
  /// In en, this message translates to:
  /// **'See furniture suggestions.'**
  String get scanIdeasDescription;

  /// No description provided for @aiRoomScan.
  ///
  /// In en, this message translates to:
  /// **'AI ROOM SCAN'**
  String get aiRoomScan;

  /// No description provided for @aiRoomScanBody.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of your room and get AI-powered furniture ideas.'**
  String get aiRoomScanBody;

  /// No description provided for @aiSuggestions.
  ///
  /// In en, this message translates to:
  /// **'AI Suggestions'**
  String get aiSuggestions;

  /// No description provided for @freshAiIdeas.
  ///
  /// In en, this message translates to:
  /// **'Fresh AI styling ideas'**
  String get freshAiIdeas;

  /// No description provided for @freshAiIdeasBody.
  ///
  /// In en, this message translates to:
  /// **'Scan your room to unlock personalized decor matches.'**
  String get freshAiIdeasBody;

  /// No description provided for @myFavorites.
  ///
  /// In en, this message translates to:
  /// **'My Favorites'**
  String get myFavorites;

  /// No description provided for @favoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved furniture and decor ideas for your next room refresh.'**
  String get favoritesSubtitle;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offers;

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @emailNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Email not connected'**
  String get emailNotConnected;

  /// No description provided for @guestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get guestUser;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @addedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added to Favorites'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from Favorites'**
  String get removedFromFavorites;

  /// No description provided for @welcomeToVisionSpace.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VisionSpace'**
  String get welcomeToVisionSpace;

  /// No description provided for @newAiDesignReady.
  ///
  /// In en, this message translates to:
  /// **'New AI Design Ready'**
  String get newAiDesignReady;

  /// No description provided for @designSaved.
  ///
  /// In en, this message translates to:
  /// **'Design Saved'**
  String get designSaved;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile Updated'**
  String get profileUpdated;

  /// No description provided for @favoriteAddedDescription.
  ///
  /// In en, this message translates to:
  /// **'{itemName} was added to your favorites.'**
  String favoriteAddedDescription(Object itemName);

  /// No description provided for @favoriteRemovedDescription.
  ///
  /// In en, this message translates to:
  /// **'{itemName} was removed from your favorites.'**
  String favoriteRemovedDescription(Object itemName);

  /// No description provided for @welcomeNotificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created successfully.'**
  String get welcomeNotificationDescription;

  /// No description provided for @newAiDesignReadyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your AI-powered room design suggestion is ready.'**
  String get newAiDesignReadyDescription;

  /// No description provided for @designSavedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your room design idea was saved successfully.'**
  String get designSavedDescription;

  /// No description provided for @profileUpdatedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your profile information was updated.'**
  String get profileUpdatedDescription;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @bestResultsNaturalLight.
  ///
  /// In en, this message translates to:
  /// **'Best results in natural light'**
  String get bestResultsNaturalLight;

  /// No description provided for @tipsForBestResults.
  ///
  /// In en, this message translates to:
  /// **'Tips for best results'**
  String get tipsForBestResults;

  /// No description provided for @scanTipsBody.
  ///
  /// In en, this message translates to:
  /// **'Make sure the room is well-lit and tidy for accurate AI suggestions.'**
  String get scanTipsBody;

  /// No description provided for @scanTipNaturalLight.
  ///
  /// In en, this message translates to:
  /// **'Use natural light.'**
  String get scanTipNaturalLight;

  /// No description provided for @scanTipTidyRoom.
  ///
  /// In en, this message translates to:
  /// **'Keep the room tidy.'**
  String get scanTipTidyRoom;

  /// No description provided for @scanTipWholeRoom.
  ///
  /// In en, this message translates to:
  /// **'Capture the whole room.'**
  String get scanTipWholeRoom;

  /// No description provided for @scanTipAvoidBlur.
  ///
  /// In en, this message translates to:
  /// **'Avoid blurry photos.'**
  String get scanTipAvoidBlur;

  /// No description provided for @scanTipCornerPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take the photo from a corner if possible.'**
  String get scanTipCornerPhoto;

  /// No description provided for @scanProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Creating Your Design'**
  String get scanProcessingTitle;

  /// No description provided for @scanStageAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing your room...'**
  String get scanStageAnalyzing;

  /// No description provided for @scanStageDesigning.
  ///
  /// In en, this message translates to:
  /// **'Creating design strategies...'**
  String get scanStageDesigning;

  /// No description provided for @scanStageSearching.
  ///
  /// In en, this message translates to:
  /// **'Finding matching furniture...'**
  String get scanStageSearching;

  /// No description provided for @scanStagePlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning furniture layout...'**
  String get scanStagePlanning;

  /// No description provided for @scanStageCompleting.
  ///
  /// In en, this message translates to:
  /// **'Finalizing your design...'**
  String get scanStageCompleting;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Design could not be created. Please try again.'**
  String get scanFailed;

  /// No description provided for @scanUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Room image could not be uploaded.'**
  String get scanUploadFailed;

  /// No description provided for @scanStageRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get scanStageRetry;

  /// No description provided for @notificationDesignReady.
  ///
  /// In en, this message translates to:
  /// **'Your AI design is ready!'**
  String get notificationDesignReady;

  /// No description provided for @notificationDesignReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to view your personalized furniture suggestions.'**
  String get notificationDesignReadyBody;

  /// No description provided for @backendUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get backendUrlLabel;

  /// Android notification channel name for completed AI design notifications.
  ///
  /// In en, this message translates to:
  /// **'Design AI Updates'**
  String get notificationDesignChannelName;

  /// Android notification channel description for completed AI design notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications for when your AI designs are ready.'**
  String get notificationDesignChannelDescription;

  /// No description provided for @scanPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Design Brief'**
  String get scanPreferencesTitle;

  /// No description provided for @scanPreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Room dimensions and optional style choices are sent to the AI backend with your photo.'**
  String get scanPreferencesSubtitle;

  /// No description provided for @scanRoomWidthLabel.
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get scanRoomWidthLabel;

  /// No description provided for @scanRoomDepthLabel.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get scanRoomDepthLabel;

  /// No description provided for @scanCeilingHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get scanCeilingHeightLabel;

  /// No description provided for @scanCentimetersSuffix.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get scanCentimetersSuffix;

  /// No description provided for @scanDesignCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Designs'**
  String get scanDesignCountLabel;

  /// No description provided for @scanReplaceFurnitureLabel.
  ///
  /// In en, this message translates to:
  /// **'Replace existing furniture'**
  String get scanReplaceFurnitureLabel;

  /// No description provided for @scanFurnitureTypesLabel.
  ///
  /// In en, this message translates to:
  /// **'Furniture to include'**
  String get scanFurnitureTypesLabel;

  /// No description provided for @scanStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get scanStyleLabel;

  /// No description provided for @scanMaterialLabel.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get scanMaterialLabel;

  /// No description provided for @scanColorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get scanColorsLabel;

  /// No description provided for @scanTemperatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get scanTemperatureLabel;

  /// No description provided for @scanSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get scanSizeLabel;

  /// No description provided for @scanExtraPreferencesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get scanExtraPreferencesLabel;

  /// No description provided for @scanExtraPreferencesHint.
  ///
  /// In en, this message translates to:
  /// **'Budget, must-keep pieces, color details...'**
  String get scanExtraPreferencesHint;

  /// No description provided for @scanFurnitureSofa.
  ///
  /// In en, this message translates to:
  /// **'Sofa'**
  String get scanFurnitureSofa;

  /// No description provided for @scanFurnitureArmchair.
  ///
  /// In en, this message translates to:
  /// **'Armchair'**
  String get scanFurnitureArmchair;

  /// No description provided for @scanFurnitureCoffeeTable.
  ///
  /// In en, this message translates to:
  /// **'Coffee table'**
  String get scanFurnitureCoffeeTable;

  /// No description provided for @scanFurnitureRug.
  ///
  /// In en, this message translates to:
  /// **'Rug'**
  String get scanFurnitureRug;

  /// No description provided for @scanFurnitureTvUnit.
  ///
  /// In en, this message translates to:
  /// **'TV unit'**
  String get scanFurnitureTvUnit;

  /// No description provided for @scanFurnitureStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get scanFurnitureStorage;

  /// No description provided for @scanFurnitureLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get scanFurnitureLighting;

  /// No description provided for @scanStyleModern.
  ///
  /// In en, this message translates to:
  /// **'Modern'**
  String get scanStyleModern;

  /// No description provided for @scanStyleScandinavian.
  ///
  /// In en, this message translates to:
  /// **'Scandinavian'**
  String get scanStyleScandinavian;

  /// No description provided for @scanStyleMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get scanStyleMinimal;

  /// No description provided for @scanStyleClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get scanStyleClassic;

  /// No description provided for @scanMaterialWood.
  ///
  /// In en, this message translates to:
  /// **'Wood'**
  String get scanMaterialWood;

  /// No description provided for @scanMaterialFabric.
  ///
  /// In en, this message translates to:
  /// **'Fabric'**
  String get scanMaterialFabric;

  /// No description provided for @scanMaterialMetal.
  ///
  /// In en, this message translates to:
  /// **'Metal'**
  String get scanMaterialMetal;

  /// No description provided for @scanMaterialGlass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get scanMaterialGlass;

  /// No description provided for @scanColorBeige.
  ///
  /// In en, this message translates to:
  /// **'Beige'**
  String get scanColorBeige;

  /// No description provided for @scanColorOak.
  ///
  /// In en, this message translates to:
  /// **'Oak'**
  String get scanColorOak;

  /// No description provided for @scanColorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get scanColorWhite;

  /// No description provided for @scanColorGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get scanColorGray;

  /// No description provided for @scanColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get scanColorGreen;

  /// No description provided for @scanTemperatureWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get scanTemperatureWarm;

  /// No description provided for @scanTemperatureNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get scanTemperatureNeutral;

  /// No description provided for @scanTemperatureCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get scanTemperatureCool;

  /// No description provided for @scanSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get scanSizeSmall;

  /// No description provided for @scanSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get scanSizeMedium;

  /// No description provided for @scanSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get scanSizeLarge;

  /// No description provided for @backendUrlSaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save server URL'**
  String get backendUrlSaveTooltip;

  /// No description provided for @backendUrlSaved.
  ///
  /// In en, this message translates to:
  /// **'Server URL saved.'**
  String get backendUrlSaved;

  /// No description provided for @profileFirebaseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Firebase is not configured for this platform yet.'**
  String get profileFirebaseUnavailable;

  /// No description provided for @profileSignInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled.'**
  String get profileSignInCancelled;

  /// Number of products suggested in a design.
  ///
  /// In en, this message translates to:
  /// **'{count} products suggested'**
  String designProductCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
