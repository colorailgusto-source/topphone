import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:badges/badges.dart' as badges;
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/product_service.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _productService = ProductService();
  final _client = Supabase.instance.client;
  List<ProductModel> _products = [];
  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> _categorie = [];
  bool _loading = true;
  int _currentBanner = 0;
  final PageController _pageController = PageController();

  @override
  void initState() { super.initState(); _load(); _autoScroll(); }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final products = await _productService.getProducts();
      final banners = await _client.from('banner').select().eq('attivo', true).order('ordine');
      final categorie = await _client.from('categorie').select().eq('attiva', true).order('ordine');
      if (mounted) setState(() {
        _products = products;
        _banners = List<Map<String, dynamic>>.from(banners);
        _categorie = List<Map<String, dynamic>>.from(categorie);
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  void _autoScroll() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted || !_pageController.hasClients || _banners.isEmpty) return;
      final next = (_currentBanner + 1) % _banners.length;
      _pageController.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      _autoScroll();
    });
  }

  Color _hexToColor(String hex) {
    try { return Color(int.parse(hex.replaceAll('#', '0xFF'))); }
    catch (e) { return AppTheme.primary; }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartService>().count;
    final isAdmin = context.watch<AuthService>().isAdmin;
    final user = context.watch<AuthService>().currentUser;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Column(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: Color(0x660288D1), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  const SizedBox(width: 8),
                  Image.asset('assets/images/logo.png', width: 36, height: 36, fit: BoxFit.contain),
                  const SizedBox(width: 8),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Top Phone Torre', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white, fontFamily: 'Poppins')),
                    Text('Via Nazionale 68', style: TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'Poppins')),
                  ])),
                  if (isAdmin) IconButton(icon: const Icon(Icons.admin_panel_settings, color: Colors.white), onPressed: () => context.go('/admin')),
                  badges.Badge(
                    badgeContent: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    showBadge: cartCount > 0,
                    child: IconButton(icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white), onPressed: () => context.push('/cart')),
                  ),
                  IconButton(icon: const Icon(Icons.person_outlined, color: Colors.white), onPressed: () => context.push('/profile')),
                ]),
              ),
            ),
          ),
          Expanded(child: RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (user != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: RichText(text: TextSpan(children: [
                      const TextSpan(text: 'Ciao, ', style: TextStyle(fontFamily: 'Poppins', color: AppTheme.textMedium, fontSize: 14)),
                      TextSpan(text: '${user.nome}! 👋', style: const TextStyle(fontFamily: 'Poppins', color: AppTheme.textDark, fontSize: 14, fontWeight: FontWeight.w600)),
                    ])),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GestureDetector(
                    onTap: () => context.push('/catalog'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(children: [
                        Icon(Icons.search, color: AppTheme.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 10),
                        const Text('Cerca smartphone...', style: TextStyle(color: AppTheme.grey, fontSize: 14, fontFamily: 'Poppins')),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.tune, size: 16, color: AppTheme.primary),
                        ),
                      ]),
                    ),
                  ),
                ),

                // Banner dal DB
                if (_banners.isNotEmpty) ...[
                  SizedBox(
                    height: 155,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentBanner = i),
                      itemCount: _banners.length,
                      itemBuilder: (c, i) {
                        final b = _banners[i];
                        final c1 = _hexToColor(b['colore1'] ?? '#0288D1');
                        final c2 = _hexToColor(b['colore2'] ?? '#01579B');
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: c1.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            child: Stack(children: [
                              Positioned(right: -10, bottom: -10, child: Icon(Icons.local_offer, size: 90, color: Colors.white.withValues(alpha: 0.1))),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                    child: const Text('Top Phone Torre', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(b['titolo'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                                  const SizedBox(height: 2),
                                  Text(b['sottotitolo'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Poppins')),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                    child: const Text('Scopri', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 11, fontFamily: 'Poppins')),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_banners.length, (i) =>
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentBanner == i ? 20 : 6, height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _currentBanner == i ? AppTheme.primary : AppTheme.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  )),
                ],

                const SizedBox(height: 16),

                // Categorie dal DB con logo
                if (_categorie.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Categorie', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textDark, fontFamily: 'Poppins')),
                      GestureDetector(onTap: () => context.push('/catalog'), child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Vedi tutte', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 85,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categorie.length,
                      itemBuilder: (c, i) {
                        final cat = _categorie[i];
                        final logoUrl = cat['immagine_url'] ?? '';
                        return GestureDetector(
                          onTap: () => context.push('/catalog'),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(
                                width: 54, height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
                                ),
                                child: logoUrl.isNotEmpty
                                  ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(logoUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.phone_android, color: AppTheme.primary, size: 28)))
                                  : const Icon(Icons.phone_android, color: AppTheme.primary, size: 28),
                              ),
                              const SizedBox(height: 4),
                              Text(cat['nome'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textMedium, fontFamily: 'Poppins')),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                else if (_products.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Nessun prodotto disponibile')))
                else ...[
                  _sectionHeader('Ultimi Arrivi 🆕', () => context.push('/catalog')),
                  SizedBox(
                    height: 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _products.length > 6 ? 6 : _products.length,
                      itemBuilder: (c, i) => SizedBox(width: 165, child: Padding(padding: const EdgeInsets.only(right: 12), child: ProductCard(product: _products[i]))),
                    ),
                  ),
                  _sectionHeader('Più Venduti 🔥', () => context.push('/catalog')),
                  SizedBox(
                    height: 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _products.length,
                      itemBuilder: (c, i) => SizedBox(width: 165, child: Padding(padding: const EdgeInsets.only(right: 12), child: ProductCard(product: _products[_products.length - 1 - i]))),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Column(children: [
                        const Row(children: [
                          Icon(Icons.store, color: Colors.white, size: 20), SizedBox(width: 8),
                          Text('Top Phone Torre', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'Poppins')),
                        ]),
                        const SizedBox(height: 12),
                        _infoRow(Icons.location_on, 'Via Nazionale 68, Torre del Greco'),
                        _infoRow(Icons.phone, '081 341 7717'),
                        _infoRow(Icons.access_time, 'Lun-Sab: 09:30-13:30 / 16:30-20:00'),
                        _infoRow(Icons.build, 'Riparazioni Immediate'),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ]),
            ),
          )),
        ]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BottomNavigationBar(
              currentIndex: 0,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: AppTheme.grey,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 11),
              onTap: (i) {
                if (i == 1) context.push('/catalog');
                if (i == 2) context.push('/cart');
                if (i == 3) context.push('/orders');
                if (i == 4) context.push('/profile');
              },
              items: [
                const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Catalogo'),
                BottomNavigationBarItem(
                  icon: badges.Badge(
                    badgeContent: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 9)),
                    showBadge: cartCount > 0,
                    child: const Icon(Icons.shopping_cart_rounded),
                  ),
                  label: 'Carrello',
                ),
                const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Ordini'),
                const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profilo'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, color: Colors.white70, size: 14), const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Poppins')),
      ]),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textDark, fontFamily: 'Poppins')),
        GestureDetector(onTap: onTap, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: const Text('Vedi tutti', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
        )),
      ]),
    );
  }
}
