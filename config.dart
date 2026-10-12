import 'package:firebase_core/firebase_core.dart';

// 1) Cloudflare Worker adresin (KURULUM.md Adim 2)
const kWorkerUrl = 'BURAYA_WORKER_URL';
// Worker'a koydugun APP_KEY ile ayni olmali
const kAppKey = 'BURAYA_GIZLI_ANAHTAR';

// 2) Firebase proje ayarlari (KURULUM.md Adim 3)
const kFirebase = FirebaseOptions(
  apiKey: 'BURAYA_API_KEY',
  appId: 'BURAYA_APP_ID',
  messagingSenderId: 'BURAYA_SENDER_ID',
  projectId: 'BURAYA_PROJECT_ID',
);

// 3) Play Console'da olusturacagin urun kimlikleri
const kProductIds = ['gold_50', 'gold_100', 'gold_250', 'gold_500', 'premium_30'];
