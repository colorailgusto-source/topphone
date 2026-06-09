import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'admin_app_config_screen.dart';
import 'admin_products_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_banners_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _index = 0;
  int _prodotti = 0, _ordini = 0, _clienti = 0;
  double _fatturato = 0;

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    final client = Supabase.instance.client;
    final prodotti = await client.from('prodotti').select('id');
    final ordini = await client.from('ordini').select('id,totale');
    final clienti = await client.from('profili').select('id');
    double tot = 0;
    for (final o in ordini) { tot += (o['totale'] ?? 0); }
    if (mounted) setState(() {
      _prodotti = prodotti.length; _ordini = ordini.length;
      _clienti = clienti.length; _fatturato = tot;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [_buildHome(), const AdminProductsScreen(), const AdminOrdersScreen(), const AdminCustomersScreen(), const AdminStatsScreen()];
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Prodotti'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Ordini'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clienti'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: "Poppins")),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.storefront), tooltip: 'Vai al negozio', onPressed: () => context.go('/home')),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await context.read<AuthService>().logout();
            if (mounted) context.go('/login');
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Riepilogo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true, crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: 1.2, physics: const NeverScrollableScrollPhysics(),
              children: [
                _statCard('Prodotti', '$_prodotti', Icons.inventory, Colors.blue),
                _statCard('Ordini', '$_ordini', Icons.receipt_long, Colors.orange),
                _statCard('Clienti', '$_clienti', Icons.people, Colors.green),
                _statCard('Fatturato', '€${_fatturato.toStringAsFixed(0)}', Icons.euro, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Gestione Negozio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 12),
            _mgmtCard(Icons.view_carousel, 'Gestione Banner', 'Modifica i banner della home', Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBannersScreen()))),
            const SizedBox(height: 8),
            _mgmtCard(Icons.category, 'Gestione Categorie', 'Aggiungi marche con logo', Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCategoriesScreen()))),
            const SizedBox(height: 8),
            _mgmtCard(Icons.settings, 'Configurazione App', 'Versione e manutenzione', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAppConfigScreen()))),
          ]),
        ),
      ),
    );
  }

  Widget _mgmtCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(child: ListTile(
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.grey)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ));
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 32), const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color, fontFamily: 'Poppins')),
      Text(label, style: const TextStyle(color: AppTheme.grey, fontFamily: 'Poppins')),
    ])));
  }
}
