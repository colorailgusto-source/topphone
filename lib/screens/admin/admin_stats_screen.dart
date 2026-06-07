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
  int _ordiniRicevuti = 0;
  int _ordiniSpediti = 0;
  int _ordiniConsegnati = 0;
  List<Map<String, dynamic>> _topProdotti = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ordini = await _client.from('ordini').select('totale, stato').neq('stato', 'annullato').neq('stato', 'rimborsato').neq('stato', 'in_attesa_pagamento');
    double tot = 0;
    for (final o in ordini) { tot += (o['totale'] ?? 0); }
    // Calcola prodotti più venduti dalle righe ordine
    final righe = await _client.from('righe_ordine')
      .select('prodotto_id, quantita, prodotti(nome)')
      .order('quantita', ascending: false);
    
    final Map<String, Map<String, dynamic>> venditeMap = {};
    for (final r in righe) {
      final pid = r['prodotto_id'];
      final nome = r['prodotti']?['nome'] ?? 'Prodotto';
      final qty = r['quantita'] ?? 0;
      if (venditeMap.containsKey(pid)) {
        venditeMap[pid]!['vendite'] += qty;
      } else {
        venditeMap[pid] = {'nome': nome, 'vendite': qty};
      }
    }
    final prodotti = venditeMap.values.toList()
      ..sort((a, b) => (b['vendite'] as int).compareTo(a['vendite'] as int));
    final top5 = prodotti.take(5).toList();
    final ordiniRicevuti = ordini.where((o) => o['stato'] == 'ricevuto').length;
    final ordiniSpediti = ordini.where((o) => o['stato'] == 'spedito').length;
    final ordiniConsegnati = ordini.where((o) => o['stato'] == 'consegnato').length;
    if (mounted) setState(() {
      _topProdotti = top5;
      _totaleVendite = tot; _totaleOrdini = ordini.length;
      _ordiniRicevuti = ordiniRicevuti;
      _ordiniSpediti = ordiniSpediti;
      _ordiniConsegnati = ordiniConsegnati;
      _topProducts = List<Map<String, dynamic>>.from(prodotti);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(iconTheme: const IconThemeData(color: Colors.white), flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))), title: const Text('Statistiche')),
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
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _statCard('Ricevuti', '$_ordiniRicevuti', Icons.inbox, Colors.indigo)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Spediti', '$_ordiniSpediti', Icons.local_shipping, Colors.purple)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Consegnati', '$_ordiniConsegnati', Icons.check_circle, Colors.green)),
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
