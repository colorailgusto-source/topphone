import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../theme/app_theme.dart';
import '../services/cart_service.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const MainScaffold({super.key, required this.child, required this.currentPath});

  int get _currentIndex {
    if (currentPath.startsWith('/home')) return 0;
    if (currentPath.startsWith('/catalog')) return 1;
    if (currentPath.startsWith('/cart')) return 2;
    if (currentPath.startsWith('/orders')) return 3;
    if (currentPath.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartService>().count;
    return Scaffold(
      body: child,
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
            switch (i) {
              case 0: context.go('/home'); break;
              case 1: context.go('/catalog'); break;
              case 2: context.go('/cart'); break;
              case 3: context.go('/orders'); break;
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
            const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Ordini'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profilo'),
          ],
        ),
      ),
    );
  }
}