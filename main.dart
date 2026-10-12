import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

const gold = Color(0xFFF5C451);
const teal = Color(0xFF14B8A6);
const disclaimer = 'Fal eğlence amaçlıdır; kesin gelecek tahmini değildir.';

// ---------------- Durum ----------------
class Store extends ChangeNotifier {
  late SharedPreferences p;
  String name = '', birth = '', gender = '', status = '', uid = '', day = '';
  int coins = 0, used = 0, premiumUntil = 0;
  List<Map<String, dynamic>> fals = [];

  Future<void> load() async {
    p = await SharedPreferences.getInstance();
    name = p.getString('name') ?? '';
    birth = p.getString('birth') ?? '';
    gender = p.getString('gender') ?? '';
    status = p.getString('status') ?? '';
    day = p.getString('day') ?? '';
    coins = p.getInt('coins') ?? 0;
    used = p.getInt('used') ?? 0;
    premiumUntil = p.getInt('prem') ?? 0;
    uid = p.getString('uid') ?? '';
    if (uid.isEmpty) {
      uid = DateTime.now().microsecondsSinceEpoch.toString();
      await p.setString('uid', uid);
    }
    try {
      fals = (jsonDecode(p.getString('fals') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
  }

  Future<void> save() async {
    await p.setString('name', name);
    await p.setString('birth', birth);
    await p.setString('gender', gender);
    await p.setString('status', status);
    await p.setString('day', day);
    await p.setInt('coins', coins);
    await p.setInt('used', used);
    await p.setInt('prem', premiumUntil);
    await p.setString('fals', jsonEncode(fals));
    notifyListeners();
  }

  void ping() => notifyListeners();
  bool get isPrem => premiumUntil > DateTime.now().millisecondsSinceEpoch;
  String get todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  int get limit => isPrem ? 3 : 1;
  int get usedToday => day == todayKey ? used : 0;
  int get left => (limit - usedToday).clamp(0, limit);
  DateTime? get birthDate => birth.isEmpty ? null : DateTime.tryParse(birth);
  String get burc => zodiac(birthDate);
  int get age {
    final b = birthDate;
    if (b == null) return 0;
    final n = DateTime.now();
    var a = n.year - b.year;
    if (n.isBefore(DateTime(n.year, b.month, b.day))) a--;
    return a;
  }

  String get profile => 'Ad: $name, burç: $burc, yaş: $age, cinsiyet: $gender, ilişki durumu: $status';

  void addFal(String title, String icon, String text) {
    fals.insert(0, {'title': title, 'icon': icon, 'text': text, 'd': todayKey});
    if (fals.length > 30) fals = fals.sublist(0, 30);
    save();
  }

  void grant(String id) {
    if (id == 'premium_30') {
      final now = DateTime.now().millisecondsSinceEpoch;
      premiumUntil = (premiumUntil > now ? premiumUntil : now) + 30 * 24 * 3600 * 1000;
    } else if (id.startsWith('gold_')) {
      coins += int.tryParse(id.substring(5)) ?? 0;
    }
    save();
  }
}

final store = Store();
bool fbOk = false;

String zodiac(DateTime? d) {
  if (d == null) return '';
  const names = ['Oğlak', 'Kova', 'Balık', 'Koç', 'Boğa', 'İkizler', 'Yengeç', 'Aslan', 'Başak', 'Terazi', 'Akrep', 'Yay', 'Oğlak'];
  const cut = [19, 18, 20, 19, 20, 20, 22, 22, 22, 22, 21, 21, 31];
  final i = d.month - 1;
  return d.day <= cut[i] ? names[i] : names[i + 1];
}

Future<String> askAI(String prompt, {List<String> images = const []}) async {
  final r = await http
      .post(Uri.parse(kWorkerUrl),
          headers: {'Content-Type': 'application/json', 'X-App-Key': kAppKey},
          body: jsonEncode({'prompt': prompt, 'images': images}))
      .timeout(const Duration(seconds: 90));
  if (r.statusCode != 200) throw Exception('Sunucu hatası (${r.statusCode})');
  return (jsonDecode(utf8.decode(r.bodyBytes))['text'] as String);
}

String sys() =>
    'Sen sıcak, mistik bir Türk fal yorumcususun. Eğlence amaçlı, olumlu yaz; sağlık, ölüm, yatırım gibi kesin tahminler verme. Türkçe yaz. Kişi: ${store.profile}.';

// ---------------- Satın alma ----------------
final iap = InAppPurchase.instance;
final Map<String, ProductDetails> prods = {};
Future<void> initBilling() async {
  try {
    if (!await iap.isAvailable()) return;
    iap.purchaseStream.listen((list) async {
      for (final pd in list) {
        if (pd.status == PurchaseStatus.purchased) store.grant(pd.productID);
        if (pd.pendingCompletePurchase) await iap.completePurchase(pd);
      }
    });
    final r = await iap.queryProductDetails(kProductIds.toSet());
    for (final d in r.productDetails) {
      prods[d.id] = d;
    }
    store.ping();
  } catch (_) {}
}

// ---------------- Uygulama ----------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  try {
    await Firebase.initializeApp(options: kFirebase);
    fbOk = true;
  } catch (_) {}
  initBilling();
  runApp(const TelveApp());
}

class TelveApp extends StatelessWidget {
  const TelveApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (_, __) => MaterialApp(
          title: 'Telve',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: teal, brightness: Brightness.dark, secondary: gold),
            scaffoldBackgroundColor: const Color(0xFF06161F),
          ),
          home: (store.name.isEmpty || store.gender.isEmpty) ? const Onboarding() : const Shell(),
        ),
      );
}

// ---------------- Açılış soruları ----------------
class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final c = TextEditingController(text: store.name);
  DateTime? bd = store.birthDate;
  String g = store.gender, s = store.status;

  Widget chips(List<String> items, String cur, void Function(String) f) => Wrap(
        spacing: 8,
        children: items.map((e) => ChoiceChip(label: Text(e), selected: cur == e, onSelected: (_) => setState(() => f(e)))).toList(),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('✨ Hoş geldin', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Falını sana özel yorumlayabilmem için seni tanıyayım.'),
            const SizedBox(height: 20),
            TextField(controller: c, decoration: const InputDecoration(labelText: 'Adın', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(
                    context: context, initialDate: bd ?? DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now());
                if (d != null) setState(() => bd = d);
              },
              child: Text(bd == null ? 'Doğum tarihini seç' : '${bd!.day}.${bd!.month}.${bd!.year}  •  ${zodiac(bd)}'),
            ),
            const SizedBox(height: 18),
            const Text('Cinsiyet'),
            chips(['Kadın', 'Erkek', 'Belirtmek istemiyorum'], g, (e) => g = e),
            const SizedBox(height: 14),
            const Text('İlişki durumu'),
            chips(['Bekar', 'İlişkisi var', 'Evli', 'Karışık'], s, (e) => s = e),
            const SizedBox(height: 10),
            const Text(disclaimer, style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                if (c.text.trim().isEmpty || bd == null || g.isEmpty || s.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm alanları doldur')));
                  return;
                }
                store.name = c.text.trim();
                store.birth = bd!.toIso8601String();
                store.gender = g;
                store.status = s;
                store.save();
              },
              child: const Padding(padding: EdgeInsets.all(12), child: Text('Başla 🔮', style: TextStyle(fontSize: 17))),
            ),
          ]),
        ),
      );
}

// ---------------- Ana iskelet ----------------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [const HomeTab(), const FalsTab(), const ChatTab(), const BurcTab(), const PremiumTab()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telve ☕', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 14), child: Chip(label: Text('🪙 ${store.coins}'))),
        ],
      ),
      body: pages[i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Ana'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Fallarım'),
          NavigationDestination(icon: Icon(Icons.chat_bubble), label: 'Sohbet'),
          NavigationDestination(icon: Icon(Icons.nightlight_round), label: 'Burçlar'),
          NavigationDestination(icon: Icon(Icons.workspace_premium), label: 'Premium'),
        ],
      ),
    );
  }
}

// ---------------- Ana sayfa ----------------
class FalType {
  final String icon, title, prompt;
  final int cost;
  final String? extra;
  const FalType(this.icon, this.title, this.cost, this.prompt, {this.extra});
}

const falTypes = [
  FalType('🃏', 'Tarot Falı', 5, '3 kartlı (geçmiş-şimdi-gelecek) tarot açılımı yap; kartları seç ve anlamlarını anlat. 150-200 kelime.'),
  FalType('🖐️', 'El Falı', 5, 'Hayat, kalp ve akıl çizgilerine dair genel, eğlenceli bir el falı yorumu yap. 150 kelime.'),
  FalType('🙂', 'Yüz Falı', 5, 'Geleneksel fizyonomi temelli genel, eğlenceli bir yüz falı yorumu yap. 150 kelime.'),
  FalType('👼', 'Melek Kartı', 3, 'Bir melek kartı çek; adını ve günün mesajını ver. 100 kelime.'),
  FalType('💞', 'Aşk Uyumu', 3, 'Şu kişiyle aşk uyumunu yorumla ve yüzde uyum skoru ver. 150 kelime. Kişi:', extra: 'Partnerin adı ve burcu'),
  FalType('🔮', 'Sihirli Küre', 1, 'Sihirli küre gibi 3-4 cümlelik gizemli bir cevap ver.', extra: 'Sorunu yaz (isteğe bağlı)'),
];

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Merhaba ${store.name} 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        Text('${store.burc} burcu', style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 14),
        Card(
          color: const Color(0xFF0E3A3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: gold)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('☕ Günlük kahve falın', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              Text('Bugünkü ücretsiz hakkın: ${store.left}/${store.limit}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoffeePage())),
                child: const Text('Kahve Falı Baktır'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        const Text('🔮 Diğer Fallar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final t in falTypes)
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FalPage(t: t))),
                child: Ink(
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(18)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(t.icon, style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 4),
                    Text(t.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    Text('${t.cost} altın', style: const TextStyle(fontSize: 10, color: gold)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(disclaimer, style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]);
}

Future<void> sharePost(BuildContext ctx, String icon, String title, String text) async {
  try {
    await FirebaseFirestore.instance.collection('posts').add(
        {'name': store.name, 'icon': icon, 'title': title, 'text': text, 'ts': DateTime.now().millisecondsSinceEpoch});
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Toplulukta paylaşıldı!')));
  } catch (_) {
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Paylaşılamadı')));
  }
}

class FalPage extends StatefulWidget {
  final FalType t;
  const FalPage({super.key, required this.t});
  @override
  State<FalPage> createState() => _FalPageState();
}

class _FalPageState extends State<FalPage> {
  final c = TextEditingController();
  String? out, err;
  bool busy = false;

  Future<void> run() async {
    if (!store.isPrem && store.coins < widget.t.cost) {
      setState(() => err = 'Yeterli altının yok. Premium sekmesinden altın alabilirsin.');
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final x = await askAI('${sys()} İstek: ${widget.t.prompt} ${c.text}');
      if (!store.isPrem) store.coins -= widget.t.cost;
      store.addFal(widget.t.title, widget.t.icon, x);
      setState(() => out = x);
    } catch (e) {
      setState(() => err = 'Yorum alınamadı: $e');
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.t.icon} ${widget.t.title}')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (widget.t.extra != null)
            TextField(controller: c, decoration: InputDecoration(labelText: widget.t.extra, border: const OutlineInputBorder())),
          const SizedBox(height: 10),
          FilledButton(onPressed: busy ? null : run, child: Text(busy ? 'Yorumlanıyor…' : 'Falıma Bak (${store.isPrem ? 'ücretsiz' : '${widget.t.cost} altın'})')),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: Colors.redAccent))),
          if (out != null) ...[
            const SizedBox(height: 14),
            Text(out!, style: const TextStyle(fontSize: 16, height: 1.6)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => sharePost(context, widget.t.icon, widget.t.title, out!), child: const Text('📣 Toplulukta Paylaş')),
            const Text(disclaimer, style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ]),
      );
}

// ---------------- Kahve falı ----------------
class CoffeePage extends StatefulWidget {
  const CoffeePage({super.key});
  @override
  State<CoffeePage> createState() => _CoffeePageState();
}

class _CoffeePageState extends State<CoffeePage> {
  final List<Uint8List?> imgs = [null, null, null];
  final labels = ['Fincanın içi', 'Fincanın dışı', 'Tabak'];
  String? out, err;
  bool busy = false;

  Future<void> pick(int i) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Kamera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo), title: const Text('Galeri'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;
    try {
      final f = await ImagePicker().pickImage(source: src, maxWidth: 900, imageQuality: 70);
      if (f != null) {
        final b = await f.readAsBytes();
        setState(() => imgs[i] = b);
      }
    } catch (_) {
      setState(() => err = 'Kamera izni verilmedi veya açılamadı.');
    }
  }

  Future<void> run() async {
    final list = imgs.whereType<Uint8List>().toList();
    final free = store.left > 0;
    if (!free && store.coins < 50) {
      setState(() => err = 'Bugünkü hakkın bitti. Ekstra kahve falı 50 altın (50 TL). Premium sekmesinden altın alabilirsin.');
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final x = await askAI(
          'Sen deneyimli bir Türk kahve falı yorumcususun. Ekteki fotoğraflardaki telve şekillerini (yol, kuş, kalp, göz, balık, harf, dağ vb.) GERÇEKTEN gözlemle; gördüğün şekilleri ve konumlarını (kenar=yakın gelecek, dip=uzak) belirterek yorumla. Fotoğraf kahve fincanı değilse veya net değilse bunu nazikçe söyle, uydurma. Kişi: ${store.profile}. Başlıklar: Gördüklerim, Genel Durum, Aşk, İş ve Para, Yakın Gelecek. Türkçe, sıcak ve olumlu, 250-350 kelime. Eğlence amaçlıdır; sağlık/ölüm/kesin finans tahmini verme.',
          images: list.map(base64Encode).toList());
      if (free) {
        store.day = store.todayKey;
        store.used = store.usedToday + 1;
      } else {
        store.coins -= 50;
      }
      store.addFal('Kahve Falı', '☕', x);
      setState(() => out = x);
    } catch (e) {
      setState(() => err = 'Yorum alınamadı: $e');
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = imgs.whereType<Uint8List>().length;
    return Scaffold(
      appBar: AppBar(title: const Text('☕ Kahve Falı')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Kahveyi içtikten sonra fincanı ters çevirip soğumasını bekle. Işık iyi olsun, yakından çek.\nBugünkü ücretsiz hakkın: ${store.left}/${store.limit}. Hak bitince her fal 50 altın.',
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: InkWell(
                  onTap: () => pick(i),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
                      clipBehavior: Clip.antiAlias,
                      child: imgs[i] == null
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt), Text(labels[i], style: const TextStyle(fontSize: 11))])
                          : Image.memory(imgs[i]!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        FilledButton(onPressed: (busy || n == 0) ? null : run, child: Text(busy ? 'Telve inceleniyor…' : 'Falıma Bak 🔮')),
        const Text('En az 1, en iyisi 3 fotoğraf.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: Colors.redAccent))),
        if (out != null) ...[
          const SizedBox(height: 14),
          Text(out!, style: const TextStyle(fontSize: 16, height: 1.6)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => sharePost(context, '☕', 'Kahve Falı', out!), child: const Text('📣 Toplulukta Paylaş')),
          const Text(disclaimer, style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ]),
    );
  }
}

// ---------------- Fallarım ----------------
class FalsTab extends StatelessWidget {
  const FalsTab({super.key});
  @override
  Widget build(BuildContext context) => store.fals.isEmpty
      ? const Center(child: Text('Henüz falın yok.'))
      : ListView(children: [
          for (final f in store.fals)
            ListTile(
              leading: Text('${f['icon']}', style: const TextStyle(fontSize: 28)),
              title: Text('${f['title']}'),
              subtitle: Text('${f['text']}'.replaceAll('\n', ' '), maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Text('${f['d']}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => Scaffold(
                            appBar: AppBar(title: Text('${f['icon']} ${f['title']}')),
                            body: ListView(padding: const EdgeInsets.all(16), children: [
                              Text('${f['text']}', style: const TextStyle(fontSize: 16, height: 1.6)),
                              const SizedBox(height: 10),
                              OutlinedButton(onPressed: () => sharePost(context, '${f['icon']}', '${f['title']}', '${f['text']}'), child: const Text('📣 Toplulukta Paylaş')),
                            ]),
                          ))),
            ),
        ]);
}

// ---------------- Sohbet ----------------
class ChatTab extends StatelessWidget {
  const ChatTab({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(children: [
          const TabBar(tabs: [Tab(text: 'Sohbet'), Tab(text: 'Paylaşılan Fallar')]),
          const Expanded(child: TabBarView(children: [ChatRoom(), PostsList()])),
        ]),
      );
}

class ChatRoom extends StatefulWidget {
  const ChatRoom({super.key});
  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> {
  final c = TextEditingController();
  Future<void> send() async {
    final t = c.text.trim();
    if (t.isEmpty) return;
    c.clear();
    try {
      await FirebaseFirestore.instance.collection('msgs').add(
          {'name': store.name, 'burc': store.burc, 'uid': store.uid, 'text': t.length > 280 ? t.substring(0, 280) : t, 'ts': DateTime.now().millisecondsSinceEpoch});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderilemedi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!fbOk) return const Center(child: Text('Sohbet için Firebase ayarı gerekli.'));
    return Column(children: [
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('msgs').orderBy('ts', descending: true).limit(60).snapshots(),
          builder: (_, s) {
            if (s.hasError) return const Center(child: Text('Sohbete bağlanılamadı.'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final d = s.data!.docs;
            if (d.isEmpty) return const Center(child: Text('İlk mesajı sen yaz!'));
            return ListView.builder(
              reverse: true,
              itemCount: d.length,
              itemBuilder: (_, i) {
                final m = d[i].data() as Map<String, dynamic>;
                final mine = m['uid'] == store.uid;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(color: mine ? const Color(0xFF0F766E) : Colors.white12, borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${m['name'] ?? '?'} · ${m['burc'] ?? ''}', style: const TextStyle(fontSize: 11, color: gold)),
                      Text('${m['text'] ?? ''}'),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(child: TextField(controller: c, onSubmitted: (_) => send(), decoration: const InputDecoration(hintText: 'Mesaj yaz…', border: OutlineInputBorder()))),
          IconButton(onPressed: send, icon: const Icon(Icons.send)),
        ]),
      ),
    ]);
  }
}

class PostsList extends StatelessWidget {
  const PostsList({super.key});
  @override
  Widget build(BuildContext context) {
    if (!fbOk) return const Center(child: Text('Firebase ayarı gerekli.'));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').orderBy('ts', descending: true).limit(30).snapshots(),
      builder: (_, s) {
        if (s.hasError) return const Center(child: Text('Bağlanılamadı.'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final d = s.data!.docs;
        if (d.isEmpty) return const Center(child: Text('Henüz paylaşım yok.'));
        return ListView(children: [
          for (final x in d)
            Builder(builder: (_) {
              final m = x.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m['icon'] ?? ''} ${m['title'] ?? ''} · ${m['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('${m['text'] ?? ''}', maxLines: 8, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            }),
        ]);
      },
    );
  }
}

// ---------------- Burç ----------------
class BurcTab extends StatefulWidget {
  const BurcTab({super.key});
  @override
  State<BurcTab> createState() => _BurcTabState();
}

class _BurcTabState extends State<BurcTab> {
  late Future<Map<String, dynamic>> f = load();
  Future<Map<String, dynamic>> load() async {
    final key = 'bh_${store.todayKey}_${store.burc}';
    final c = store.p.getString(key);
    if (c != null) return jsonDecode(c) as Map<String, dynamic>;
    final r = await askAI(
        '${store.burc} burcu için bugünün yorumunu yaz. Kişi: ${store.profile}. SADECE JSON döndür: {"s":[aşk,para,kariyer 1-10 tam sayı],"t":"90-130 kelime Türkçe olumlu yorum"}');
    final j = jsonDecode(r.replaceAll(RegExp(r'```json|```'), '').trim()) as Map<String, dynamic>;
    await store.p.setString(key, jsonEncode(j));
    return j;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: f,
        builder: (_, s) {
          if (s.hasError) return Center(child: TextButton(onPressed: () => setState(() => f = load()), child: const Text('Yüklenemedi, tekrar dene')));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final sc = (s.data!['s'] as List).map((e) => (e as num).toInt()).toList();
          const names = ['Aşk', 'Para', 'Kariyer'];
          const cols = [Colors.redAccent, Colors.greenAccent, Colors.lightBlueAccent];
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('${store.burc} · Bugün', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            for (var i = 0; i < 3; i++) ...[
              const SizedBox(height: 10),
              Text('${names[i]}: ${sc[i]}/10'),
              LinearProgressIndicator(value: sc[i] / 10, color: cols[i], minHeight: 8),
            ],
            const SizedBox(height: 16),
            Text('${s.data!['t']}', style: const TextStyle(fontSize: 16, height: 1.6)),
          ]);
        },
      );
}

// ---------------- Premium / Altın ----------------
class PremiumTab extends StatelessWidget {
  const PremiumTab({super.key});
  String price(String id, String fb) => prods[id]?.price ?? fb;
  void buy(BuildContext c, String id) {
    final d = prods[id];
    if (d == null) {
      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Ürün Play Store\'dan yüklenemedi. Uygulama Play Store üzerinden kurulmalı.')));
      return;
    }
    iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: d));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: const Color(0xFF0E3A3F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: gold)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('👑 Aylık Premium', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('✓ 30 gün boyunca günde 3 kahve falı\n✓ Diğer fallar ücretsiz\n✓ Detaylı yorumlar'),
              if (store.isPrem)
                Text('Aktif: ${DateTime.fromMillisecondsSinceEpoch(store.premiumUntil).toLocal().toString().substring(0, 10)} tarihine kadar', style: const TextStyle(color: gold))
              else
                FilledButton(onPressed: () => buy(context, 'premium_30'), child: Text('Premium Ol · ${price('premium_30', '499 TL')}')),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        const Text('🪙 Altın Satın Al', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('1 altın = 1 TL · ekstra kahve falı = 50 altın', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 8),
        for (final e in {'gold_50': '50 TL', 'gold_100': '95 TL', 'gold_250': '225 TL', 'gold_500': '420 TL'}.entries)
          Card(
            child: ListTile(
              leading: const Text('🪙', style: TextStyle(fontSize: 26)),
              title: Text('${e.key.substring(5)} altın'),
              trailing: FilledButton(onPressed: () => buy(context, e.key), child: Text(price(e.key, e.value))),
            ),
          ),
        const SizedBox(height: 10),
        const Text(disclaimer, style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]);
}
