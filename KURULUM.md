# Telve – Telefondan kurulum (bilgisayarsız)

Tüm dosyalar tek klasörde (alt klasör yok), telefondan yüklemesi kolay.

## Adım 1 – GitHub'a yükle
1. github.com'da ücretsiz hesap aç, "New repository" ile `telve` adlı (Private) bir depo oluştur.
2. "Add file > Upload files" ile bu klasördeki TÜM dosyaları yükle (main.dart, config.dart, pubspec.yaml, codemagic.yaml, worker.js, firestore.rules). Commit et.

## Adım 2 – Yapay zekâ köprüsü (Cloudflare Worker)
1. dash.cloudflare.com'da ücretsiz hesap aç > Workers & Pages > Create > Worker.
2. Açılan editöre `worker.js` içeriğini yapıştır, Deploy et.
3. Worker > Settings > Variables and Secrets: `ANTHROPIC_API_KEY` (console.anthropic.com'dan aldığın API anahtarı) ve `APP_KEY` (kendi uydurduğun uzun bir şifre) ekle (ikisi de Secret).
4. Worker adresini (https://....workers.dev) kopyala.
5. GitHub'da config.dart'ı düzenle: `kWorkerUrl` = bu adres, `kAppKey` = az önceki APP_KEY.

## Adım 3 – Sohbet (Firebase)
1. console.firebase.google.com > proje oluştur > Build > Firestore Database > Create (production mode).
2. Rules sekmesine `firestore.rules` içeriğini yapıştırıp Publish et.
3. Project settings > Add app > Android (paket adı: com.telve.telve). Ayarlardaki apiKey, appId, messagingSenderId, projectId değerlerini config.dart'taki `kFirebase` alanlarına yaz.

## Adım 4 – APK derle
1. codemagic.io'ya GitHub ile giriş yap > Add application > `telve` deposunu seç > Flutter App (codemagic.yaml otomatik bulunur).
2. Start new build > workflow: telve-apk. 10-15 dk sonra Artifacts bölümünden APK'yı indir, telefona kur.

## Adım 5 – Play Store (sonraki aşama)
APK sadece kendi telefonunda denemek içindir. Play Store için imzalı AAB, Play Developer hesabı (25 $), ödeme profilinde IBAN'ın ve Play Console'da şu ürünler gerekir: gold_50, gold_100, gold_250, gold_500, premium_30 (hepsi "yönetilen ürün"; fiyatlar 50/95/225/420/499 TL). Gizlilik politikası linki de şart.

Not: Fal yorumları eğlence amaçlıdır. Altın ve premium bilgisi şu an cihazda tutuluyor; ciddi gelir için ileride sunucu doğrulaması eklenmeli.
