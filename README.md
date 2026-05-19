# VisionSpace / decorator-ai

VisionSpace, mobilya katalog verisini toplayan, zenginleştiren, backend tarafında vektörleyen ve gerçek oda fotoğrafından AI destekli tasarım önerileri üreten uçtan uca bir iç mekan tasarım sistemidir. Proje dört ana parçadan oluşur:

- `data/`: Ürün verisi toplama, görsel indirme ve ürün zenginleştirme hattı.
- `ai-service/`: FastAPI tabanlı backend, AI iş akışı, ürün arama, veritabanı ve arka plan job sistemi.
- `flutter-app/`: Mobil uygulama; oda tarama, tasarım brief'i, ürün hotspot'ları, favoriler, profil ve bildirim arayüzü.
- Firebase / Cloud katmanı: Flutter tarafında Firebase Core, Firestore, Auth, Messaging ve ileride eklenecek Cloud Functions mimarisi.

Bu dosya geliştiriciler ve sistemi kuracak insanlar içindir. Agent talimatı değildir.

## 1. Büyük Resim

Tipik çalışma akışı şöyledir:

1. `data/crawler` kaynak mağazalardan ham ürünleri toplar.
2. Ham kayıtlar `data/output/products.jsonl` dosyasına, görseller `data/output/images/` altına yazılır.
3. `data/preprocessor` ürünleri normalize eder, Vertex AI ile ya da deterministik fallback ile etiketler, semantik açıklamalar üretir.
4. Hazırlanan ürünler `ai-service` içine import edilir; ürün görselleri crawler'ın yazdığı local `data/output/images` yolları ile taşınır.
5. `ai-service` PostgreSQL'i kaynak gerçeklik, Qdrant'ı vektör arama, Redis/RQ'yu arka plan iş kuyruğu olarak kullanır.
6. Flutter uygulaması oda fotoğrafı ve tasarım tercihlerini `ai-service` backend'ine gönderir.
7. Backend iş akışı oda analizini, tasarım stratejisini, ürün aramasını, yerleşim planını ve sonucu kalıcılaştırmayı arka planda yapar.
8. Flutter uygulaması job durumunu poll eder, sonuç hazır olduğunda bildirim üretir ve tasarımı ürün hotspot'ları ile gösterir.

Basitleştirilmiş mimari:

```text
Kaynak mağazalar
  -> data/crawler -> raw JSONL + ürün görselleri
  -> data/preprocessor -> enriched JSONL
  -> ai-service import -> PostgreSQL + Qdrant
  -> Flutter scan -> FastAPI upload/design-job
  -> RQ worker + LangGraph + Vertex AI
  -> Flutter Design Detail + bildirimler
```

## 2. Depo Yapısı

```text
VisionSpace/
  data/
    crawler/             Scrapy crawler projesi
    preprocessor/        Ürün normalizasyonu ve Vertex AI zenginleştirme
    output/              Ham crawler çıktıları
    requirements.txt     Data hattı Python bağımlılıkları

  ai-service/
    app/                 FastAPI uygulaması, DB, schema, vector, workflow, worker modülleri
    migrations/          Alembic migrasyonları
    scripts/             DB import, Qdrant collection, indexleme scriptleri
    data/images/         Backend local image root
    docker-compose.yml   API, worker, PostgreSQL, Redis, Qdrant, Adminer
    Makefile             Kurulum ve operasyon komutları

  flutter-app/
    lib/                 Flutter uygulama kodu
    android/, ios/       Platform projeleri
    firestore.rules      Firestore güvenlik kuralları
    firestore.indexes.json
    firestore_seed/      Örnek Firestore verisi

  TEMP/
    TEMP.md              İlk ürün/backend gereksinim notları
```

## 3. Data Sistemi: Crawler ve Preprocessor

### 3.1 Crawler

Crawler sistemi Scrapy ile yazılmıştır. `data/crawler/` klasörü klasik Scrapy proje davranışı gösterir; `scrapy.cfg`, `settings.py`, `items.py`, `pipelines.py` ve `spiders/` aynı proje içinde bulunur.

Mevcut spider'lar:

- `vivense_spider.py`
- `ikea_spider.py`
- `istikbal_spider.py`

Crawler'ın görevi ham kaynak bilgisini mümkün olduğunca bozmadan kaydetmektir. Taksonomi, stil, malzeme, renk, oda uygunluğu gibi zengin alanların ana sahibi preprocessor katmanıdır.

Önemli crawler bileşenleri:

- `FurnitureItem`: Kaynak ürün sözleşmesi. URL, ürün adı, açıklama, fiyat, para birimi, kaynak id, metadata, görsel URL'leri ve opsiyonel breadcrumbs taşır.
- `DuplicatesPipeline`: Geçersiz veya tekrar eden ürünleri ayıklar.
- `FurnitureImagePipeline`: Ürün görsellerini indirir ve local görsel yollarını item üzerine yazar.
- `JsonExportPipeline`: Son ham item'ları `data/output/products.jsonl` dosyasına JSONL formatında yazar.
- `RoundRobinCategorySpider`: Seçili kategoriler arasında dengeli istek dağılımı yapar.

Ham crawler çıktısı JSONL'dir. Bu sınır bilinçli tutulur: crawler ham kaynak gerçeğini yazar, preprocessor bu gerçeği yorumlar.

### 3.2 Preprocessor

`data/preprocessor/` ürün kayıtlarının AI ve arama için kullanılabilir hale getirildiği yerdir.

Ana dosyalar:

- `models.py`: Pydantic şemaları ve desteklenen taksonomiler.
- `enrich_products.py`: Ana batch zenginleştirme CLI'ı.
- `run.py`: İnteraktif zenginleştirme sarmalayıcısı.
- `vertex_ai.py`: Vertex AI REST istemcisi ve service account key tabanlı kimlik doğrulama.
- `labeler.py`: Görsel destekli etiketleme yolu.

Preprocessor iki modda çalışabilir:

- Vertex AI açıkken: Ürünleri model ile yapılandırılmış JSON olarak etiketler.
- Yerel/fallback modda: Deterministik kurallar ile kategori, stil, renk, malzeme ve semantik metin üretir.

Bu fallback önemlidir; yerel geliştirme ve crawler testi için Google Cloud erişimi olmadan da veri hattı çalışabilir.

### 3.3 Data Hattı Çıktıları

Tipik dosyalar:

- `data/output/products.jsonl`: Ham ürünler.
- `data/output/images/`: Crawler tarafından indirilen ürün görselleri.
- `data/preprocessor/enriched_products.jsonl`: Normalize ve zenginleştirilmiş ürünler.
- `data/preprocessor/enrichment_errors.jsonl`: Zenginleştirme hataları.

## 4. AI Service Backend

`ai-service`, tasarım üretme ve ürün önerme sisteminin backend'idir. Backend, Flutter istemcisinden oda fotoğrafı ve kullanıcı tercihlerini alır, tasarım job'ı oluşturur ve ağır AI aşamalarını arka planda çalıştırır.

### 4.1 Teknoloji

- FastAPI
- PostgreSQL 16
- SQLAlchemy 2.x
- Alembic
- Redis 7
- RQ worker
- Qdrant
- LangGraph
- Google Cloud Vertex AI
- Docker Compose
- Local filesystem image storage

### 4.2 Servisler

`ai-service/docker-compose.yml` şu servisleri ayağa kaldırır:

- `api`: FastAPI uygulaması, port `8000`.
- `migrate`: PostgreSQL hazır olduktan sonra `alembic upgrade head` çalıştıran tek seferlik migrasyon servisi.
- `worker`: RQ worker, tasarım job'larını çalıştırır.
- `postgres`: Kalıcı ürün ve tasarım veritabanı, port `5432`.
- `redis`: RQ queue ve state/caching altyapısı, port `6379`.
- `qdrant`: Vektör veritabanı, port `6333` ve `6334`.
- `adminer`: Veritabanı yönetim arayüzü, port `8080`.

### 4.3 API

Ana endpoint'ler:

- `GET /health`: Sağlık kontrolü.
- `POST /uploads/room-image`: Oda fotoğrafı yükleme.
- `POST /design-jobs`: Tasarım job oluşturma.
- `GET /design-jobs/{job_id}`: Job durumunu ve tamamlandıysa sonucu alma.
- `POST /products/search`: Debug/deneme amaçlı ürün arama.
- `GET /images/{relative_path}`: Local image root altındaki oda, ürün ve generated image dosyalarını sunma.

Backend job durumları:

- `queued`
- `running`
- `completed`
- `failed`
- `cancelled`

### 4.4 AI Workflow

Tasarım üretimi LangGraph ile doğrusal bir state machine olarak yürür:

```text
validate_input
  -> analyze_room
  -> create_design_strategies
  -> retrieve_candidates
  -> rerank_products
  -> plan_placements
  -> generate_images
  -> validate_result
  -> persist_result
```

Her aşama ayrı node'dur. Bu yapı iş akışının değiştirilebilir kalmasını sağlar. AI çıktıları Pydantic şemalarıyla doğrulanır; backend modelin serbestçe veritabanını değiştirmesine izin vermez.

Yerleşim koordinatları API sınırında normalize edilir: `x = x_pixel / image_width`,
`y = y_pixel / image_height`. `clickable_regions[].polygon` artık `0.0-1.0`
aralığında döner; Flutter bu değerleri görüntülenen oda görselinin boyutuna çevirir.
Backend sadece debug görseli veya basit composite üretirken koordinatları tekrar orijinal
oda fotoğrafı pikseline çevirir. `DEBUG_PLACEMENT=true` olduğunda backend
`generated/debug/{job_id}_placement.png` altında floor maskesi, kabul edilen noktalar
ve reddedilen adayları gösteren bir debug görseli üretir.

### 4.5 Veritabanı ve Vektör Arama

PostgreSQL kaynak gerçekliktir. Ürünler, ürün görselleri, tasarım job'ları, oluşturulmuş tasarımlar ve seçili ürünler burada tutulur.

Qdrant yalnızca retrieval için kullanılır. Ürün vektörleri ve filtre payload'ları Qdrant'a yazılır, ancak ürünün canonical kaydı PostgreSQL'dedir.

Ürün arama mantığı şu sinyalleri birleştirir:

- Semantik metin benzerliği.
- Oda fotoğrafı ile ürün görseli benzerliği.
- Stil, renk, malzeme, oda tipi, ölçü ve kategori filtreleri.
- Deterministik re-rank skoru.

### 4.6 Görsel Depolama

Backend görselleri local filesystem altında tutar. Varsayılan kök:

```text
ai-service/data/images
```

Container içinde bu dizin `/data/images` olarak mount edilir. API yanıtlarında mutlak path yerine relative path döner. Flutter tarafı bu relative path'i backend URL'sine ekleyerek `/images/...` üzerinden gösterir.

Sprint 1 yerleşim renderer'ı gelişmiş image generation değildir; seçilen ürün görselini
veya placeholder bloğunu normalize placement polygon'una basan basit bir Pillow composite
üretir. Çıktı yolu tipik olarak `generated/{job_id}/design_0_composite.png` formatındadır.

## 5. Flutter Uygulaması

`flutter-app`, kullanıcıya görünen mobil deneyimdir. Aktif ürün yüzeyi Material 3 tabanlı, mobil odaklı ve editorial iç mimari hissi veren bir tasarımdır.

### 5.1 Ana Akışlar

- Welcome ekranı.
- Onboarding: dekorasyon durumu, konum, yaş, yaşam durumu.
- App Shell: Home, Scan, Favorites, Profile sekmeleri.
- Home: örnek tasarım kartları ve mobilya önerileri.
- Scan: oda ölçüleri ve tasarım brief'i girme, kamera ile fotoğraf çekme.
- Processing: backend job oluşturma ve AI aşamalarını poll etme.
- Design Detail: tasarım görseli, ürün hotspot'ları, önerilen ürün kartları.
- Product Detail: ürün ayrıntısı, mağaza linkleri, güvenli yönlendirme notu.
- Notifications: yerel uygulama içi bildirimler.

### 5.2 Backend Bağlantısı

Flutter backend URL çözümü taşınabilir olacak şekilde merkezi `BackendConfig` üzerinden yapılır.

Çözüm sırası:

1. Profile ekranında kaydedilen `backend_base_url` değeri.
2. Derleme zamanı değeri: `--dart-define=BACKEND_BASE_URL=...`.
3. Platform varsayılanı:
   - Android emulator: `http://10.0.2.2:8000`
   - Web, iOS simulator, desktop: `http://localhost:8000`

Bu düzen bugün local geliştirme, yarın uzak sunucu kullanımı için aynı kodu korur.

Örnekler:

```bash
# Web veya desktop local backend
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8000

# Android emulator local host backend
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000

# Daha sonra gerçek sunucu
flutter run --dart-define=BACKEND_BASE_URL=https://api.example.com
```

Uygulama içinden Profile ekranındaki Server URL alanı ile URL geçici veya kalıcı olarak değiştirilebilir. Bu ayar `SharedPreferences` içinde saklanır ve `--dart-define` değerinin önüne geçer.

### 5.3 Flutter Servis Katmanı

- `DecoratorAiApi`: UI'nın kullandığı soyut API sınırı.
- `BackendDecoratorAiApi`: `ai-service` REST API'sini kullanır.
- `FirestoreDecoratorAiApi`: Curated Home verisi için Firestore okur, hata/boş durumda mock'a düşer.
- `GeneratedDesignsRepository`: Kullanıcının Firestore `generatedDesigns` koleksiyonundaki AI tasarım önerilerini Favorites ekranında ve bildirim yönlendirmelerinde okur.
- `MockDecoratorAiApi`: Test ve offline geliştirme için statik veri döner.
- `AiBackendClient`: Upload, job create, job poll ve backend image URL dönüştürme işlemlerini yapar.
- `NotificationService`: Local notification, FCM foreground notification ve tasarım bildiriminden `DesignDetailPage` yönlendirme altyapısı. Tasarım bildirim data payload'ı `designId`, `generatedDesignId`, `design_id` veya `projectId` taşımalıdır.
- `AppNotificationService`: Uygulama içi bildirim listesi ve okunmamış sayaç yönetimi.

### 5.4 Lokalizasyon

Uygulama İngilizce ve Türkçe lokalizasyon kullanır:

- `lib/l10n/app_en.arb`
- `lib/l10n/app_tr.arb`
- `flutter gen-l10n` ile üretilen `app_localizations*.dart`

Kullanıcıya görünen yeni metinler ARB dosyalarına eklenmelidir. Hard-coded UI metni eklenmemelidir.

## 6. Firebase ve Cloud Mimari

Firebase şu anda Flutter uygulamasının istemci tarafı cloud altyapısıdır.

Kullanılan parçalar:

- Firebase Core: Uygulama başlangıcında Firebase init.
- Firestore: Curated tasarım projeleri, ürün hotspot seed verileri ve kullanıcıya ait `generatedDesigns` AI tasarım önerileri.
- Firebase Auth: Google sign-in entegrasyonu.
- Firebase Messaging: Remote notification altyapısı.
- Flutter Local Notifications: Cihaz içi local notification gösterimi.
- Firestore Rules: `flutter-app/firestore.rules`.
- Firestore Indexes: `flutter-app/firestore.indexes.json`.
- Seed verisi: `flutter-app/firestore_seed/`.

Cloud Functions şu anda uygulanmış değildir. İleride eklenirse önerilen sınırlar:

- Firestore trigger'ları, kullanıcı profil senkronizasyonu veya Firebase'e yakın otomasyon için kullanılabilir.
- AI provider credential, prompt, billing ve güvenilir moderasyon kararları Cloud Functions ya da `ai-service` gibi server tarafında kalmalıdır.
- Flutter istemcisi doğrudan Vertex AI ya da gizli credential gerektiren servisleri çağırmamalıdır.
- Cloud Functions HTTP/callable endpoint'leri eklenirse input/output sözleşmesi, yetki modeli ve deploy komutu ayrıca dokümante edilmelidir.

## 7. Sıfırdan Kurulum

Bu bölüm yeni bir makinede sistemi ayağa kaldırmak için gerekli adımları kapsar.

### 7.1 Ön Gereksinimler

Gerekli araçlar:

- Git
- Python 3.11+ önerilir
- Docker ve Docker Compose v2+
- Flutter SDK ve Dart
- Android Studio / Android SDK
- iOS için macOS + Xcode
- Firebase CLI
- FlutterFire CLI
- Google Cloud CLI
- Bir Google Cloud projesi
- Bir Firebase projesi

Google Cloud tarafında açılması gereken API'ler:

- Vertex AI API
- Vertex AI multimodal embedding kullanımınız varsa ilgili Vertex AI yetkileri

Servis hesabı:

- `roles/aiplatform.user` rolüne sahip bir service account oluşturun.
- JSON key dosyasını güvenli saklayın.
- Key dosyasını repoya commit etmeyin.

### 7.2 Depoyu Alın

```bash
git clone <repo-url> VisionSpace
cd VisionSpace
```

### 7.3 Data Hattını Kurun

```bash
cd data
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

Data hattı Vertex AI çağrıları için kişisel `gcloud auth application-default login` kullanılmaz. Backend ile aynı model izlenir: service account JSON key dosyasını localde tutun ve path değerini env üzerinden verin. Önerilen konum:

```bash
mkdir -p secrets
# gcp-service-account.json dosyasını data/secrets/ altına koyun. Bu klasör gitignore içindedir.
```

`data/.env` dosyasını hazırlayın. Örnek:

```env
PROJECT_ID=your-gcp-project-id
MODEL_ID=gemini-3-flash-preview
VERTEX_LOCATION=global
GOOGLE_APPLICATION_CREDENTIALS=secrets/gcp-service-account.json
```

Ham ürün toplamak için:

```bash
# Tek spider, kategori başına hedef ürün sayısı
python scraping.py --spider vivense --target-per-category 50

# Diğer spider örnekleri
python scraping.py --spider ikea --target-per-category 50
python scraping.py --spider istikbal --target-per-category 50

# Seçili kategoriler bitene kadar devam etmek için
python scraping.py --spider vivense --until-finished
```

İnteraktif çoklu crawler için:

```bash
python crawler/run.py
```

Tüm spider'ları non-interactive çalıştırmak için:

```bash
python crawler/run_all.py
```

Çıktıyı kontrol edin:

```bash
ls output/products.jsonl
ls output/images
```

### 7.4 Ürünleri Zenginleştirin

İnteraktif yol:

```bash
cd data
source .venv/bin/activate
python preprocessor/run.py
```

Doğrudan CLI:

```bash
python preprocessor/enrich_products.py \
  --input output/products.jsonl \
  --output preprocessor/enriched_products.jsonl \
  --parallel-requests 4
```

Not: Ürün embedding üretimi data hattında yapılmaz. Backend Qdrant indexleme scripti `enriched_products.jsonl` kayıtlarını import ettikten sonra Vertex text/image embedding sürecini kendisi çalıştırır.

### 7.5 AI Service Backend'i Kurun

```bash
cd ../ai-service
cp .env.example .env
```

`.env` dosyasını düzenleyin:

```env
APP_ENV=development
APP_NAME=ai-service
API_HOST=0.0.0.0
API_PORT=8000
MOCK_AI=false
CORS_ALLOW_ORIGINS=["*"]

DATABASE_URL=postgresql+psycopg://postgres:postgres@postgres:5432/furniture_ai
POSTGRES_DB=furniture_ai
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

REDIS_URL=redis://redis:6379/0
QDRANT_URL=http://qdrant:6333
QDRANT_COLLECTION_PRODUCTS=furniture_products

VERTEX_PROJECT_ID=your-gcp-project-id
VERTEX_MODEL_ID=gemini-3-flash-preview
VERTEX_PRO_MODEL_ID=gemini-3.1-pro-preview
VERTEX_LOCATION=global
VERTEX_EMBEDDING_MODEL=text-embedding-005
VERTEX_MULTIMODAL_MODEL=multimodalembedding@001
VERTEX_MULTIMODAL_LOCATION=us-central1

LOCAL_IMAGE_ROOT=/data/images
PRODUCT_IMAGE_DIR=/data/images/products
ROOM_UPLOAD_DIR=/data/images/rooms
GENERATED_IMAGE_DIR=/data/images/generated

GOOGLE_APPLICATION_CREDENTIALS=/secrets/gcp-service-account.json
```

Varsayılan Docker kurulumunda `/data/images`, host tarafındaki `ai-service/data/images` dizinine bağlanır. Sunucuya taşırken bu dizinleri container başlamadan önce oluşturun ve container'ın yazabildiğinden emin olun:

```bash
mkdir -p ai-service/data/images/products ai-service/data/images/rooms ai-service/data/images/generated
```

Eğer projeyi farklı bir host dizinine koyduysanız sorun değildir; önemli olan compose bind mount'unun gerçek host yolunu göstermesi ve `.env` içindeki dört image path değerinin aynı container kökü (`/data/images`) altında kalmasıdır.

Service account key dosyasını yerleştirin:

```bash
mkdir -p secrets
cp /absolute/path/to/service-account.json secrets/gcp-service-account.json
```

Container'ları, migrasyonları ve Qdrant collection'ı hazırlayın:

```bash
make setup
```

Bu komut şunları yapar:

1. Docker container'larını build eder ve başlatır.
2. Compose `migrate` servisiyle Alembic migrasyonlarını çalıştırır.
3. Qdrant collection oluşturur.

`docker compose up -d --build` artık PostgreSQL healthcheck'ini bekler, `migrate` servisiyle Alembic migrasyonlarını çalıştırır ve ardından API/worker container'larını başlatır. Mevcut bir sunucuda tablo eksikliği görürseniz tek seferlik düzeltme için şunu çalıştırabilirsiniz:

```bash
cd ai-service
docker compose run --rm migrate
```

Backend'i kontrol edin:

```bash
curl http://localhost:8000/health
```

Beklenen cevap:

```json
{"status":"ok"}
```

Dokümantasyon arayüzleri:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`
- Adminer: `http://localhost:8080`

### 7.6 Ürünleri Backend'e Import Edin

Varsayılan import, Docker container içinden `../data` mount'unu `/data/pipeline` olarak görür:

```bash
make import-enriched
```

Bu komut varsayılan olarak şunu okur:

```text
/data/pipeline/preprocessor/enriched_products.jsonl
```

Özel dosya kullanmak için:

```bash
make import-enriched file=/data/pipeline/preprocessor/enriched_products.jsonl
```

Ham ürün JSON dosyası import etmek gerekiyorsa:

```bash
make import-products file=/path/inside/container/products.json
```

### 7.7 Qdrant Indexleme

```bash
make index-products
```

Bu işlem ürünleri PostgreSQL'den okur, text/image embedding üretir ve Qdrant'a yazar. Ürün görsel embedding aşaması kaynak görsellere erişmek için internet gerektirebilir.

### 7.8 Worker'ın Çalıştığını Doğrulayın

Docker Compose içinde `worker` servisi normalde çalışır. Log kontrolü:

```bash
make logs
```

Ayrı bir worker denemesi için:

```bash
make worker
```

Tasarım job'ları tamamlanmıyorsa önce worker loglarına, sonra Redis ve Vertex credential ayarlarına bakın.

### 7.9 Firebase'i Hazırlayın

Firebase CLI kurulumu:

```bash
npm install -g firebase-tools
firebase login
```

FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

Firebase projesinde şunları açın:

- Firestore Database
- Authentication > Google provider
- Cloud Messaging

Flutter yapılandırması için:

```bash
cd ../flutter-app
flutterfire configure
```

Bu işlem `lib/firebase_options.dart` dosyasını üretir veya günceller.

Firestore rules ve indexes deploy etmek için:

```bash
firebase deploy --only firestore
```

Seed verileri yüklemek için `flutter-app/firestore_seed/README.md` içeriğini takip edin veya Firebase Console üzerinden `designProjects` ve alt `products` koleksiyonlarını elle oluşturun. Kullanıcıya özel AI tasarım sonuçları `generatedDesigns/{designId}` altında `ownerUid`, `title`, `spaceType`, `style`, `imageUrl`, `createdAt` ve alt `products` koleksiyonu ile saklanır.

### 7.10 Flutter Uygulamasını Kurun ve Çalıştırın

```bash
cd flutter-app
flutter pub get
flutter gen-l10n
```

Backend local çalışıyorsa platforma göre çalıştırın:

```bash
# Android emulator: host makinenin localhost'u için 10.0.2.2 gerekir
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000

# Web, desktop veya iOS simulator
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

Uygulama içinden değiştirmek için:

1. Profile sekmesine gidin.
2. Server URL alanına backend adresini yazın.
3. Onay ikonuna basın.

Örnek server adresleri:

```text
http://localhost:8000
http://10.0.2.2:8000
http://192.168.1.50:8000
https://api.example.com
```

Fiziksel Android cihazda `localhost` telefonun kendisidir. Backend bilgisayarınızda çalışıyorsa aynı ağdaki makine IP'sini veya gerçek bir sunucu URL'sini kullanın.

## 8. Localhost ve Sunucuya Geçiş

Geliştirme ortamı:

- Backend host makinede: `http://localhost:8000`
- Android emulator'dan host makine: `http://10.0.2.2:8000`
- Fiziksel cihazdan host makine: `http://<host-lan-ip>:8000`

Sunucu ortamı:

1. `ai-service` klasörünü sunucuya taşıyın.
2. `.env` değerlerini production'a göre düzenleyin.
3. `POSTGRES_PASSWORD` ve diğer secret'ları değiştirin.
4. `secrets/gcp-service-account.json` dosyasını güvenli şekilde yerleştirin.
5. Reverse proxy kullanın: Nginx veya Caddy önerilir.
6. TLS sertifikası bağlayın.
7. Flutter build ederken backend URL verin:

```bash
flutter build apk --dart-define=BACKEND_BASE_URL=https://api.example.com
flutter build appbundle --dart-define=BACKEND_BASE_URL=https://api.example.com
flutter build ios --dart-define=BACKEND_BASE_URL=https://api.example.com
```

Backend CORS ayarı için `.env` içinde production origin'lerini sınırlayın:

```env
CORS_ALLOW_ORIGINS=["https://app.example.com"]
```

Mobil native uygulamalarda CORS genellikle web kadar belirleyici değildir, ancak web build veya browser tabanlı debug için gereklidir.

## 9. Test ve Doğrulama

### 9.1 Flutter

```bash
cd flutter-app
flutter analyze
flutter test
```

Sadece widget testleri:

```bash
flutter test test/widget_test.dart
```

### 9.2 AI Service

```bash
cd ai-service
pytest
```

Docker içinde çalıştırmak isterseniz:

```bash
docker compose run --rm api pytest
```

Lint:

```bash
make lint
```

Not: Backend testlerinin tamamı için Python ortamında `pyproject.toml` içindeki bağımlılıkların kurulu olması gerekir. Qdrant testleri `qdrant-client` paketini import eder.

### 9.3 Data Hattı

```bash
cd data
source .venv/bin/activate
python scraping.py --spider vivense --target-per-category 5
python preprocessor/enrich_products.py --input output/products.jsonl --output preprocessor/enriched_products.jsonl --parallel-requests 1
```

## 10. Operasyon Komutları

Backend için sık kullanılan komutlar:

```bash
cd ai-service
make setup           # up + migrate + create-qdrant
make up              # container'ları başlat/build et
make down            # container'ları durdur
make logs            # logları takip et
make migrate         # Alembic upgrade head
make create-qdrant   # Qdrant collection oluştur
make import-enriched # enriched_products.jsonl import et
make index-products  # ürünleri Qdrant'a indexle
make worker          # manuel worker çalıştır
```

Flutter için:

```bash
cd flutter-app
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

Firebase için:

```bash
cd flutter-app
firebase deploy --only firestore
```

## 11. Önemli Tasarım Kararları

- Flutter istemcisi AI provider credential tutmaz.
- Backend AI çıktıları Pydantic şemalarıyla doğrular.
- PostgreSQL canonical ürün kaynağıdır.
- Qdrant retrieval içindir; ürün gerçeği Qdrant'a emanet edilmez.
- Crawler ham veri toplar; zenginleştirme crawler pipeline'ında yapılmaz.
- Preprocessor deterministik fallback içerir; cloud erişimi yokken sistem tamamen durmaz.
- Backend iş akışı arka plan worker'ında çalışır; API request'i uzun AI aşamalarını senkron bekletmez.
- Flutter backend URL'si merkezi ve taşınabilirdir: Profile override, `--dart-define`, platform varsayılanı.
- Kullanıcıya görünen Flutter metinleri lokalizasyon kaynaklarından gelmelidir.

## 12. Bilinen Üretim Hazırlıkları

Production'a geçmeden önce önerilenler:

- Backend'i reverse proxy ve HTTPS arkasına alın.
- `.env` secret değerlerini production secret manager ya da güvenli deployment sistemi ile yönetin.
- `CORS_ALLOW_ORIGINS` değerini `*` yerine gerçek origin'lere sınırlayın.
- PostgreSQL, Redis ve Qdrant volume backup stratejisi oluşturun.
- Firebase Auth SHA-1/SHA-256 Android fingerprint ayarlarını release imza anahtarına göre tamamlayın.
- Firestore rules ve indexes'i deploy edin.
- Vertex AI kota, maliyet ve timeout gözlemi kurun.
- RQ worker health ve retry stratejisini izleyin.
- Ürün görselleri için kalıcı object storage veya yedekleme stratejisi düşünün.
- Flutter release build'lerini `--dart-define=BACKEND_BASE_URL=https://...` ile üretin.
