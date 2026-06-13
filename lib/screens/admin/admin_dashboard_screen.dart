import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'admin_app_config_screen.dart';
import 'admin_products_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_resi_screen.dart';
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
            _mgmtCard(Icons.bar_chart, 'Analytics', 'Visualizzazioni e comportamenti', Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()))),
            _mgmtCard(Icons.assignment_return_rounded, 'Gestione Resi', 'Approva o rifiuta resi clienti', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminResiScreen()))),
            _mgmtCard(Icons.campaign_rounded, 'Invia Notifica', 'Messaggio a tutti i clienti', Colors.teal, () => _showBroadcast()),
          ]),
        ),
      ),
    );
  }

  void _showBroadcast() {
    final titoloCtrl = TextEditingController();
    final messaggioCtrl = TextEditingController();
    bool loading = false;
    final templates = [
      {'titolo': '🎉 Nuovi Arrivi!', 'messaggio': 'Scopri i nuovi smartphone appena arrivati in negozio!'},
      {'titolo': '🔥 Offerta Speciale!', 'messaggio': 'Approfitta delle nostre offerte esclusive disponibili solo per oggi!'},
      {'titolo': '📦 Ordine Pronto!', 'messaggio': 'Il tuo ordine è pronto per il ritiro in negozio.'},
      {'titolo': '⚡ Ultimi Pezzi!', 'messaggio': 'Affrettati! Rimangono solo gli ultimi pezzi disponibili.'},
      {'titolo': '🎁 Promozione Esclusiva!', 'messaggio': 'Solo per i nostri clienti speciali: visita il negozio e scopri le nostre promozioni!'},
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(Icons.campaign_rounded, color: AppTheme.primary), SizedBox(width: 8), Text('Invia Notifica', style: TextStyle(fontWeight: FontWeight.w700))]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titoloCtrl, onChanged: (_) => setS((){}), decoration: const InputDecoration(labelText: 'Titolo *', prefixIcon: Icon(Icons.title))),
            const SizedBox(height: 12),
            TextField(controller: messaggioCtrl, onChanged: (_) => setS((){}), maxLines: 3, decoration: const InputDecoration(labelText: 'Messaggio *', prefixIcon: Icon(Icons.message))),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            const Align(alignment: Alignment.centerLeft, child: Text('Messaggi rapidi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: templates.map((t) => GestureDetector(
              onTap: () { titoloCtrl.text = t['titolo']!; messaggioCtrl.text = t['messaggio']!; setS((){}); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3))),
                child: Text(t['titolo']!, style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ),
            )).toList()),
            const SizedBox(height: 8),
            const Text('La notifica verrà inviata a tutti i clienti registrati.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: loading || titoloCtrl.text.isEmpty || messaggioCtrl.text.isEmpty ? null : () async {
                setS(() => loading = true);
                try {
                  final clienti = await Supabase.instance.client.from('profili').select('fcm_token').eq('ruolo', 'cliente').not('fcm_token', 'is', null);
                  int inviati = 0;
                  for (final c in clienti) {
                    if (c['fcm_token'] != null && c['fcm_token'].toString().isNotEmpty) {
                      await http.post(
                        Uri.parse('https://ehjcqxjspwedqihjjkjf.supabase.co/functions/v1/send-notification'),
                        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoamNxeGpzcHdlZHFpaGpqa2pmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1OTAwMjMsImV4cCI6MjA5NjE2NjAyM30.XLebw0DH33-HFhkPOwnBg7v06sBTl_uQ6uistj5Sg6s'},
                        body: jsonEncode({'token': c['fcm_token'], 'title': titoloCtrl.text.trim(), 'body': messaggioCtrl.text.trim()}),
                      );
                      inviati++;
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Notifica inviata a $inviati clienti!'), backgroundColor: Colors.green));
                } catch (e) {
                  setS(() => loading = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: ' + e.toString()), backgroundColor: Colors.red));
                }
              },
              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Invia'),
            ),
          ],
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
