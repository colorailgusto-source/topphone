import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});
  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _topProducts = [];
  double _totaleVendite = 0;
  int _totaleOrdini = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ordini = await _client.from('ordini').select('totale');
    double tot = 0;
    for (final o in ordini) { tot += (o['totale'] ?? 0); }
    final prodotti = await _client.from('prodotti').select('nome,vendite').order('vendite', ascending: false).limit(5);
    if (mounted) setState(() {
      _totaleVendite = tot; _totaleOrdini = ordini.length;
      _topProducts = List<Map<String, dynamic>>.from(prodotti);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiche')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Expanded(child: _statCard('Fatturato Totale', '€${_totaleVendite.toStringAsFixed(2)}', Icons.euro, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Ordini Totali', '$_totaleOrdini', Icons.receipt_long, Colors.blue)),
              ]),
              const SizedBox(height: 24),
              const Align(alignment: Alignment.centerLeft, child: Text('Prodotti Più Venduti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              ..._topProducts.map((p) => Card(child: ListTile(
                leading: const Icon(Icons.phone_android, color: AppTheme.primary),
                title: Text(p['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('${p['vendite'] ?? 0} vendite', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ))),
            ]),
          ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Icon(icon, color: color, size: 32), const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(color: AppTheme.grey, fontSize: 12), textAlign: TextAlign.center),
    ])));
  }
}
