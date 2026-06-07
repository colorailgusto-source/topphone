import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

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
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Catalogo'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_rounded), label: 'Carrello'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Ordini'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profilo'),
          ],
        ),
      ),
    );
  }
}
