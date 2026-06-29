import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/cart_service.dart';

class MainScaffold extends StatefulWidget {
  final Widget child;
  final String currentPath;
  const MainScaffold({super.key, required this.child, required this.currentPath});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _ordiniAttivi = 0;
  Timer? _timer;
  int _sogliaRecensione = 3;

  @override
  void initState() {
    super.initState();
    _loadOrdini();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _loadOrdini());
    _sogliaRecensione = 3 + Random().nextInt(4);
  }

  Future<void> _controllaRecensione() async {
    final prefs = await SharedPreferences.getInstance();
    final giaRichiesta = prefs.getBool("recensione_richiesta") ?? false;
    if (giaRichiesta) return;
    final contatore = (prefs.getInt("nav_count") ?? 0) + 1;
    await prefs.setInt("nav_count", contatore);
    if (contatore < _sogliaRecensione) return;
    await prefs.setBool("recensione_richiesta", true);
    final inAppReview = InAppReview.instance;
    final disponibile = await inAppReview.isAvailable();
    if (disponibile) {
      inAppReview.requestReview();
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _loadOrdini() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('ordini').select('id').eq('utente_id', userId)
          .inFilter('stato', ['ricevuto', 'confermato', 'spedito']);
      if (mounted) setState(() => _ordiniAttivi = data.length);
    } catch (e) { debugPrint("count ordini attivi: $e"); }
  }

  int get _currentIndex {
    if (widget.currentPath.startsWith('/home')) return 0;
    if (widget.currentPath.startsWith('/catalog')) return 1;
    if (widget.currentPath.startsWith('/cart')) return 2;
    if (widget.currentPath.startsWith('/orders')) return 3;
    if (widget.currentPath.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartService>().count;
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.grey,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 11),
          onTap: (i) {
            _controllaRecensione();
            switch (i) {
              case 0: context.go('/home'); break;
              case 1: context.go('/catalog'); break;
              case 2: context.go('/cart'); break;
              case 3: context.go('/orders'); _loadOrdini(); break;
              case 4: context.go('/profile'); break;
            }
          },
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Catalogo'),
            BottomNavigationBarItem(
              icon: badges.Badge(
                badgeContent: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 9)),
                showBadge: cartCount > 0,
                badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red, padding: EdgeInsets.all(4)),
                position: badges.BadgePosition.topEnd(top: -6, end: -6),
                child: const Icon(Icons.shopping_cart_rounded),
              ),
              label: 'Carrello',
            ),
            BottomNavigationBarItem(
              icon: badges.Badge(
                badgeContent: Text('$_ordiniAttivi', style: const TextStyle(color: Colors.white, fontSize: 9)),
                showBadge: _ordiniAttivi > 0,
                badgeStyle: const badges.BadgeStyle(badgeColor: Colors.orange, padding: EdgeInsets.all(4)),
                position: badges.BadgePosition.topEnd(top: -6, end: -6),
                child: const Icon(Icons.receipt_long_rounded),
              ),
              label: 'Ordini',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profilo'),
          ],
        ),
      ),
    );
  }
}
