// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Decorator AI';

  @override
  String get appBrand => 'Decorator AI';

  @override
  String get welcomeHeadline =>
      'Gerçek mekanı tara,\nAI ile tasarla,\nbeğendiğini al.';

  @override
  String get welcomeSubtitle =>
      'Ev, ofis veya iş yerini analiz eden; ürünleri tıklanabilir satın alma noktalarına çeviren akıllı iç mekan uygulaması.';

  @override
  String get welcomeInsight =>
      'AI tasarım önerileri ve alışveriş eşleşmeleri hazır.';

  @override
  String get welcomeStartScan => 'Mekanı Taramaya Başla';

  @override
  String get welcomeExploreExamples => 'Örnek Tasarımları Keşfet';

  @override
  String onboardingStep(int current, int total) {
    return '$current / $total';
  }

  @override
  String get onboardingOptionalSubtitle =>
      'İsteğe bağlı. İstediğini paylaş, kalanları atla.';

  @override
  String get onboardingSkip => 'Atla';

  @override
  String get onboardingNext => 'İleri';

  @override
  String get onboardingYes => 'Evet';

  @override
  String get onboardingNo => 'Hayır';

  @override
  String get onboardingScratchQuestion => 'Evini sıfırdan mı dekore ediyorsun?';

  @override
  String get onboardingLocationQuestion => 'Mekanın nerede?';

  @override
  String get onboardingLocationSubtitle =>
      'Yakınından başlamak için konum izni ver, sonra haritada bölgeni seç.';

  @override
  String get onboardingUseCurrentLocation => 'Konumumu kullan';

  @override
  String get onboardingSelectMapCenter => 'Harita merkezini seç';

  @override
  String get onboardingLocationMapHint => 'Bölgeni seçmek için haritaya dokun.';

  @override
  String onboardingLocationSelected(Object latitude, Object longitude) {
    return 'Seçildi: $latitude, $longitude';
  }

  @override
  String get onboardingLocationServiceDisabled =>
      'Konum servisleri kapalı. Yine de haritaya dokunabilirsin.';

  @override
  String get onboardingLocationPermissionDenied =>
      'Konum izni verilmedi. Yine de haritaya dokunabilirsin.';

  @override
  String get onboardingLocationPermissionDeniedForever =>
      'Konum izni engellenmiş. Yine de haritaya dokunabilirsin.';

  @override
  String get onboardingLocationUnavailable =>
      'Mevcut konum alınamadı. Yine de haritaya dokunabilirsin.';

  @override
  String get onboardingCountryLabel => 'Ülke';

  @override
  String get onboardingCountryHint =>
      'Türkiye, Fransa, Amerika Birleşik Devletleri...';

  @override
  String get onboardingAreaLabel => 'Bölge';

  @override
  String get onboardingAreaHint => 'Gölbaşı, Le Marais, Manhattan...';

  @override
  String get onboardingLocationInvalid => 'Listeden ülke, şehir ve bölge seç.';

  @override
  String get onboardingCityQuestion => 'Hangi şehirde yaşıyorsun?';

  @override
  String get onboardingCitySubtitle =>
      'Yazmaya başla ve listeden bir şehir seç.';

  @override
  String get onboardingCityLabel => 'Şehir';

  @override
  String get onboardingCityHint => 'İstanbul, Londra, New York...';

  @override
  String get onboardingCityInvalid => 'Listeden bir şehir seç.';

  @override
  String get onboardingAgeQuestion => 'Kaç yaşındasın?';

  @override
  String get onboardingAgeLabel => 'Yaş';

  @override
  String get onboardingAgeHint => '32';

  @override
  String get onboardingAgeInvalid => '16 ile 120 arasında bir yaş gir.';

  @override
  String get onboardingLivingQuestion => 'Yalnız mı, ailenle mi yaşıyorsun?';

  @override
  String get onboardingLivingAlone => 'Yalnız yaşıyorum';

  @override
  String get onboardingLivingFamily => 'Ailemle yaşıyorum';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navScan => 'Tara';

  @override
  String get navSaved => 'Favoriler';

  @override
  String get navProfile => 'Profil';

  @override
  String get savedTitle => 'Favoriler';

  @override
  String get savedSubtitle => 'Favorilediğin mobilyalar burada toplanacak.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileSubtitle =>
      'Hesap, adres ve tercih ayarları backend ile bağlanacak.';

  @override
  String get homeSubtitle => 'AI destekli mekan tasarımı';

  @override
  String get homeNewScanBadge => 'Yeni tarama';

  @override
  String get homeHeroTitle => 'Mekanını tarat,\nAI tasarımını üretelim.';

  @override
  String get homeHeroBody =>
      'Oda ölçüsü, ışık, stil ve ürün algılama backend ile bu akışa bağlanacak.';

  @override
  String get homeSuggestionsTitle => 'AI Tasarım Önerileri';

  @override
  String designMatchedProducts(Object spaceType, Object style, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ürün eşleşti',
      one: '1 ürün eşleşti',
      zero: 'ürün eşleşmedi',
    );
    return '$spaceType • $style • $_temp0';
  }

  @override
  String get designClickableProducts => 'Tıklanabilir Ürünler';

  @override
  String productMatchScore(int score) {
    return '%$score benzerlik';
  }

  @override
  String get scanTitle => 'Mekan Taraması';

  @override
  String get scanSubtitle =>
      'AI tasarım oluşturmak için kamerayı açıp mekanı tarat.';

  @override
  String get scanInstruction =>
      'Butona basınca kamera açılır. Fotoğraf çekildikten sonra AI tasarım akışı başlar.';

  @override
  String get scanCreateDesign => 'AI Tasarım Oluştur';

  @override
  String get cameraNotFound => 'Kamera bulunamadı.';

  @override
  String get cameraCouldNotStart => 'Kamera başlatılamadı.';

  @override
  String get cameraCaptureFailed => 'Tarama alınamadı. Tekrar dene.';

  @override
  String get cameraAnalyzing => 'AI mekanı analiz ediyor...';

  @override
  String get cameraCaptureHint =>
      'Odayı kadraja al, sonra tarama butonuna bas.';

  @override
  String get cameraPermissionDenied =>
      'Kamera izni verilmedi. Tarama yapmak için tarayıcıdan kamera izni ver.';

  @override
  String cameraCouldNotOpen(Object details) {
    return 'Kamera açılamadı: $details';
  }

  @override
  String get cameraScanTitle => 'Mekanı Tara';

  @override
  String get cameraOverlayHint =>
      'Duvar, zemin, ışık ve mobilyaları algılamak için alanı görünür tut.';

  @override
  String get productSimilarWithAi => 'Benzer Ürünleri AI ile Bul';

  @override
  String get productPurchaseOptions => 'Satın Alma Seçenekleri';

  @override
  String get productDescriptionSofa => 'Modern kumaş üçlü koltuk';

  @override
  String get productDescriptionGeneric =>
      'AI tarafından tasarımdaki ürüne göre eşleştirilen benzer ürün.';

  @override
  String productRatingSummary(Object rating, int reviewCount) {
    return '$rating ($reviewCount)';
  }

  @override
  String get productDetailTitle => 'Ürün Detayı';

  @override
  String get productGoToProduct => 'Ürünü Gör';

  @override
  String productStoreOpenFailed(Object storeName) {
    return '$storeName linki açılamadı.';
  }

  @override
  String get productSecurityNote =>
      'Güvenli yönlendirme ile mağazanın resmi sayfasına gidersiniz.';

  @override
  String get profileSaved => 'Profil başarıyla kaydedildi.';

  @override
  String profileGoogleSignInFailed(String error) {
    return 'Google ile giriş yapılamadı: $error';
  }

  @override
  String get profileDefaultUser => 'Kullanıcı';

  @override
  String get profileNameLabel => 'Ad';

  @override
  String get profileSurnameLabel => 'Soyad';

  @override
  String get profileNameRequired => 'Ad zorunludur';

  @override
  String get profileSurnameRequired => 'Soyad zorunludur';

  @override
  String get profileEditCancel => 'İptal';

  @override
  String get profileEditConfirm => 'Onayla';

  @override
  String get profileSignInGoogle => 'Google ile Giriş Yap';

  @override
  String get profileSignOut => 'Çıkış Yap';

  @override
  String get profileBirthdayLabel => 'Doğum Tarihi';

  @override
  String get profileBirthdayNotSet => 'Doğum tarihi ayarlanmadı';

  @override
  String get profileSettingsTitle => 'Bildirim Ayarları';

  @override
  String get profileSettingAuthReminders => 'Yerel Bildirimler';

  @override
  String get profileSettingAiUpdates => 'Uzak Bildirimler';

  @override
  String get authReminderTitle => 'İlerlemenizi kaydetmek için giriş yapın!';

  @override
  String get authReminderBody =>
      'AI tasarımlarınızı kaybetmeyin. Hemen Google ile giriş yapın.';

  @override
  String get authReminderRecurringTitle => 'Mekanlarınız sizi bekliyor';

  @override
  String get authReminderRecurringBody =>
      'AI tasarımlarınızı cihazlar arasında senkronize etmek için giriş yapın.';

  @override
  String get profileSettingLanguage => 'Dil';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get notificationsTitle => 'Bildirimler';

  @override
  String get noNotificationsMessage => 'Henüz bildirim yok';

  @override
  String get noFavoritesMessage =>
      'Henüz favori mobilya yok. Eklemek için ana ekrandaki kalp simgesine dokunun.';

  @override
  String homeGreeting(Object name) {
    return 'Merhaba $name 👋';
  }

  @override
  String get homeGreetingFallback => 'Merhaba 👋';

  @override
  String get homeReadySubtitle => 'Odanı yeniden tasarlamaya hazır mısın?';

  @override
  String get categoryChair => 'Sandalye';

  @override
  String get categorySofa => 'Koltuk';

  @override
  String get categoryTable => 'Masa';

  @override
  String get categoryLamp => 'Lamba';

  @override
  String get categoryDecor => 'Dekor';

  @override
  String get recommendedFurniture => 'Önerilen Mobilyalar';

  @override
  String get startScan => 'Taramayı Başlat';

  @override
  String get takePhoto => 'Fotoğraf Çek';

  @override
  String get howItWorks => 'Nasıl Çalışır?';

  @override
  String get takeAPhoto => 'Fotoğraf çek';

  @override
  String get aiAnalysis => 'AI Analizi';

  @override
  String get getIdeas => 'Fikirleri Gör';

  @override
  String get scanYourRoom => 'Odanı Tara';

  @override
  String get scanPremiumSubtitle =>
      'Mekanını yakala, AI sana uygun mobilyaları önersin.';

  @override
  String get scanPhotoDescription => 'Odanı net şekilde kadraja al.';

  @override
  String get scanAnalysisDescription => 'AI stil ve düzeni analiz eder.';

  @override
  String get scanIdeasDescription => 'Mobilya önerilerini gör.';

  @override
  String get aiRoomScan => 'AI ODA TARAMASI';

  @override
  String get aiRoomScanBody =>
      'Odanın fotoğrafını çek ve AI destekli mobilya fikirleri al.';

  @override
  String get aiSuggestions => 'AI Önerileri';

  @override
  String get freshAiIdeas => 'Yeni AI stil fikirleri';

  @override
  String get freshAiIdeasBody =>
      'Kişiselleştirilmiş dekor eşleşmeleri için odanı tara.';

  @override
  String get myFavorites => 'Favorilerim';

  @override
  String get favoritesSubtitle =>
      'Sonraki oda yenilemen için kaydedilen mobilya ve dekor fikirleri.';

  @override
  String get all => 'Tümü';

  @override
  String get unread => 'Okunmamış';

  @override
  String get offers => 'Teklifler';

  @override
  String get updates => 'Güncellemeler';

  @override
  String get editProfile => 'Profili Düzenle';

  @override
  String get personalInformation => 'Kişisel Bilgiler';

  @override
  String get emailNotConnected => 'E-posta bağlı değil';

  @override
  String get guestUser => 'Misafir Kullanıcı';

  @override
  String get notSet => 'Ayarlanmadı';

  @override
  String get support => 'Destek';

  @override
  String get read => 'Oku';

  @override
  String get addedToFavorites => 'Favorilere Eklendi';

  @override
  String get removedFromFavorites => 'Favorilerden Çıkarıldı';

  @override
  String get welcomeToVisionSpace => 'VisionSpace’e Hoş Geldin';

  @override
  String get newAiDesignReady => 'Yeni AI Tasarım Hazır';

  @override
  String get designSaved => 'Tasarım Kaydedildi';

  @override
  String get profileUpdated => 'Profil Güncellendi';

  @override
  String favoriteAddedDescription(Object itemName) {
    return '$itemName favorilerine eklendi.';
  }

  @override
  String favoriteRemovedDescription(Object itemName) {
    return '$itemName favorilerinden çıkarıldı.';
  }

  @override
  String get welcomeNotificationDescription => 'Hesabın başarıyla oluşturuldu.';

  @override
  String get newAiDesignReadyDescription =>
      'AI destekli oda tasarım önerin hazır.';

  @override
  String get designSavedDescription =>
      'Oda tasarım fikrin başarıyla kaydedildi.';

  @override
  String get profileUpdatedDescription => 'Profil bilgilerin güncellendi.';

  @override
  String get justNow => 'Az önce';

  @override
  String get bestResultsNaturalLight => 'En iyi sonuç için doğal ışık';

  @override
  String get tipsForBestResults => 'En iyi sonuçlar için ipuçları';

  @override
  String get scanTipsBody =>
      'Doğru AI önerileri için odanın iyi aydınlatılmış ve düzenli olduğundan emin ol.';

  @override
  String get scanTipNaturalLight => 'Doğal ışık kullan.';

  @override
  String get scanTipTidyRoom => 'Odayı düzenli tut.';

  @override
  String get scanTipWholeRoom => 'Tüm odayı kadraja al.';

  @override
  String get scanTipAvoidBlur => 'Bulanık fotoğraflardan kaçın.';

  @override
  String get scanTipCornerPhoto => 'Mümkünse köşeden fotoğraf çek.';

  @override
  String get scanProcessingTitle => 'Tasarımınız Oluşturuluyor';

  @override
  String get scanStageAnalyzing => 'Odanız analiz ediliyor...';

  @override
  String get scanStageDesigning => 'Tasarım stratejileri oluşturuluyor...';

  @override
  String get scanStageSearching => 'Eşleşen mobilyalar aranıyor...';

  @override
  String get scanStagePlanning => 'Mobilya yerleşimi planlanıyor...';

  @override
  String get scanStageCompleting => 'Tasarımınız tamamlanıyor...';

  @override
  String get scanFailed => 'Tasarım oluşturulamadı. Lütfen tekrar deneyin.';

  @override
  String get scanUploadFailed => 'Oda fotoğrafı yüklenemedi.';

  @override
  String get scanStageRetry => 'Tekrar Dene';

  @override
  String get notificationDesignReady => 'AI tasarımınız hazır!';

  @override
  String get notificationDesignReadyBody =>
      'Kişiselleştirilmiş mobilya önerilerinizi görmek için dokunun.';

  @override
  String get backendUrlLabel => 'Sunucu URL\'si';

  @override
  String get notificationDesignChannelName => 'Tasarım AI Güncellemeleri';

  @override
  String get notificationDesignChannelDescription =>
      'AI tasarımlarınız hazır olduğunda gelen bildirimler.';

  @override
  String get scanPreferencesTitle => 'Tasarım Özeti';

  @override
  String get scanPreferencesSubtitle =>
      'Oda ölçüleri ve isteğe bağlı stil seçimleri fotoğrafınla birlikte AI backend’e gönderilir.';

  @override
  String get scanRoomWidthLabel => 'Duvar';

  @override
  String get scanRoomDepthLabel => 'Derinlik';

  @override
  String get scanCeilingHeightLabel => 'Tavan';

  @override
  String get scanCentimetersSuffix => 'cm';

  @override
  String get scanDesignCountLabel => 'Tasarım';

  @override
  String get scanReplaceFurnitureLabel => 'Mevcut mobilyayı değiştir';

  @override
  String get scanFurnitureTypesLabel => 'Eklenecek mobilyalar';

  @override
  String get scanStyleLabel => 'Stil';

  @override
  String get scanMaterialLabel => 'Malzeme';

  @override
  String get scanColorsLabel => 'Renkler';

  @override
  String get scanTemperatureLabel => 'Atmosfer';

  @override
  String get scanSizeLabel => 'Boyut';

  @override
  String get scanExtraPreferencesLabel => 'Notlar';

  @override
  String get scanExtraPreferencesHint =>
      'Bütçe, kalacak parçalar, renk detayları...';

  @override
  String get scanFurnitureSofa => 'Koltuk';

  @override
  String get scanFurnitureArmchair => 'Berjer';

  @override
  String get scanFurnitureCoffeeTable => 'Sehpa';

  @override
  String get scanFurnitureRug => 'Halı';

  @override
  String get scanFurnitureTvUnit => 'TV ünitesi';

  @override
  String get scanFurnitureStorage => 'Depolama';

  @override
  String get scanFurnitureLighting => 'Aydınlatma';

  @override
  String get scanStyleModern => 'Modern';

  @override
  String get scanStyleScandinavian => 'İskandinav';

  @override
  String get scanStyleMinimal => 'Minimal';

  @override
  String get scanStyleClassic => 'Klasik';

  @override
  String get scanMaterialWood => 'Ahşap';

  @override
  String get scanMaterialFabric => 'Kumaş';

  @override
  String get scanMaterialMetal => 'Metal';

  @override
  String get scanMaterialGlass => 'Cam';

  @override
  String get scanColorBeige => 'Bej';

  @override
  String get scanColorOak => 'Meşe';

  @override
  String get scanColorWhite => 'Beyaz';

  @override
  String get scanColorGray => 'Gri';

  @override
  String get scanColorGreen => 'Yeşil';

  @override
  String get scanTemperatureWarm => 'Sıcak';

  @override
  String get scanTemperatureNeutral => 'Nötr';

  @override
  String get scanTemperatureCool => 'Soğuk';

  @override
  String get scanSizeSmall => 'Küçük';

  @override
  String get scanSizeMedium => 'Orta';

  @override
  String get scanSizeLarge => 'Büyük';

  @override
  String get backendUrlSaveTooltip => 'Sunucu URL’sini kaydet';

  @override
  String get backendUrlSaved => 'Sunucu URL’si kaydedildi.';

  @override
  String get profileFirebaseUnavailable =>
      'Firebase bu platform için henüz yapılandırılmadı.';

  @override
  String get profileSignInCancelled => 'Giriş iptal edildi.';

  @override
  String designProductCount(int count) {
    return '$count ürün önerildi';
  }
}
