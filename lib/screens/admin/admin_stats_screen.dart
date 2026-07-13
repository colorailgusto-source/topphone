import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});
  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;

  // Stats generali (tutto)
  double _totaleVendite = 0;
  int _totaleOrdini = 0;
  int _ordiniRicevuti = 0;
  int _ordiniSpediti = 0;
  int _ordiniConsegnati = 0;
  List<Map<String, dynamic>> _topProducts = [];

  // Stats per periodo
  double _venditeOggi = 0;
  double _venditeSettimana = 0;
  double _venditeMese = 0;
  int _ordiniOggi = 0;
  int _ordiniSettimana = 0;
  int _ordiniMese = 0;

  // Grafico ultimi 7 giorni
  List<Map<String, dynamic>> _ultimi7Giorni = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final inizioOggi = DateTime(now.year, now.month, now.day);
      final inizioSettimana =
          inizioOggi.subtract(Duration(days: inizioOggi.weekday - 1));
      final inizioMese = DateTime(now.year, now.month, 1);

      final ordini = await _client
          .from('ordini')
          .select('totale, stato, data')
          .neq('stato', 'annullato')
          .neq('stato', 'rimborsato')
          .neq('stato', 'in_attesa_pagamento');

      double tot = 0;
      double oggi = 0, settimana = 0, mese = 0;
      int nOggi = 0, nSettimana = 0, nMese = 0;
      int ricevuti = 0, spediti = 0, consegnati = 0;

      // Mappa per ultimi 7 giorni
      final Map<String, double> giorniMap = {};
      for (int i = 6; i >= 0; i--) {
        final d = inizioOggi.subtract(Duration(days: i));
        giorniMap[DateFormat('yyyy-MM-dd').format(d)] = 0;
      }

      for (final o in ordini) {
        final totale = (o['totale'] ?? 0).toDouble();
        tot += totale;

        final data = DateTime.parse(o['data']).toLocal();
        final dataStr = DateFormat('yyyy-MM-dd').format(data);

        if (data.isAfter(inizioOggi) || data.isAtSameMomentAs(inizioOggi)) {
          oggi += totale;
          nOggi++;
        }
        if (data.isAfter(inizioSettimana) ||
            data.isAtSameMomentAs(inizioSettimana)) {
          settimana += totale;
          nSettimana++;
        }
        if (data.isAfter(inizioMese) || data.isAtSameMomentAs(inizioMese)) {
          mese += totale;
          nMese++;
        }

        if (giorniMap.containsKey(dataStr)) {
          giorniMap[dataStr] = giorniMap[dataStr]! + totale;
        }

        switch (o['stato']) {
          case 'ricevuto':
            ricevuti++;
            break;
          case 'spedito':
            spediti++;
            break;
          case 'consegnato':
            consegnati++;
            break;
        }
      }

      // Prodotti piu venduti
      final righe = await _client
          .from('righe_ordine')
          .select('prodotto_id, quantita, prodotti(nome)');

      final Map<String, Map<String, dynamic>> venditeMap = {};
      for (final r in righe) {
        final pid = r['prodotto_id'];
        final nome = r['prodotti']?['nome'] ?? 'Prodotto';
        final qty = (r['quantita'] ?? 0) as int;
        if (venditeMap.containsKey(pid)) {
          venditeMap[pid]!['vendite'] =
              (venditeMap[pid]!['vendite'] as int) + qty;
        } else {
          venditeMap[pid] = {'nome': nome, 'vendite': qty};
        }
      }
      final prodotti = venditeMap.values.toList()
        ..sort((a, b) => (b['vendite'] as int).compareTo(a['vendite'] as int));

      // Costruisci lista 7 giorni
      final giorni = giorniMap.entries
          .map((e) => {
                'data': e.key,
                'label': [
                  'Lun',
                  'Mar',
                  'Mer',
                  'Gio',
                  'Ven',
                  'Sab',
                  'Dom'
                ][DateTime.parse(e.key).weekday - 1],
                'totale': e.value,
              })
          .toList();

      if (mounted) {
        setState(() {
          _totaleVendite = tot;
          _totaleOrdini = ordini.length;
          _ordiniRicevuti = ricevuti;
          _ordiniSpediti = spediti;
          _ordiniConsegnati = consegnati;
          _topProducts = List<Map<String, dynamic>>.from(prodotti);
          _venditeOggi = oggi;
          _venditeSettimana = settimana;
          _venditeMese = mese;
          _ordiniOggi = nOggi;
          _ordiniSettimana = nSettimana;
          _ordiniMese = nMese;
          _ultimi7Giorni = giorni;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Stats error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF01579B), Color(0xFF0288D1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight))),
        title: const Text('Statistiche'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _load)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // VENDITE PER PERIODO
                      const Text('Vendite',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins')),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _periodCard('Oggi', _venditeOggi,
                                _ordiniOggi, Colors.green)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _periodCard('Settimana', _venditeSettimana,
                                _ordiniSettimana, Colors.blue)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _periodCard('Mese', _venditeMese,
                                _ordiniMese, Colors.purple)),
                      ]),

                      const SizedBox(height: 20),

                      // GRAFICO ULTIMI 7 GIORNI
                      const Text('Ultimi 7 giorni',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins')),
                      const SizedBox(height: 12),
                      _buildChart(),

                      const SizedBox(height: 20),

                      // STATS GENERALI
                      const Text('Riepilogo Totale',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins')),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _statCard(
                                'Fatturato',
                                '\u20AC${_totaleVendite.toStringAsFixed(0)}',
                                Icons.euro,
                                Colors.green)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _statCard('Ordini', '$_totaleOrdini',
                                Icons.receipt_long, Colors.blue)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _statCard('Ricevuti', '$_ordiniRicevuti',
                                Icons.inbox, Colors.indigo)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _statCard('Spediti', '$_ordiniSpediti',
                                Icons.local_shipping, Colors.purple)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _statCard('Consegnati', '$_ordiniConsegnati',
                                Icons.check_circle, Colors.green)),
                      ]),

                      const SizedBox(height: 24),

                      // PRODOTTI PIU VENDUTI
                      const Text('Prodotti Piu Venduti',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins')),
                      const SizedBox(height: 12),
                      ..._topProducts.take(10).map((p) => Card(
                              child: ListTile(
                            leading: const Icon(Icons.phone_android,
                                color: AppTheme.primary),
                            title: Text(p['nome'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            trailing: Text('${p['vendite'] ?? 0} vendite',
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ))),
                    ]),
              ),
            ),
    );
  }

  Widget _periodCard(String label, double vendite, int ordini, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 6),
        Text('\u20AC${vendite.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text('$ordini ordini',
            style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
      ]),
    );
  }

  Widget _buildChart() {
    if (_ultimi7Giorni.isEmpty) return const SizedBox();
    final maxVal = _ultimi7Giorni.fold<double>(
        0,
        (prev, e) =>
            (e['totale'] as double) > prev ? (e['totale'] as double) : prev);
    final chartMax = maxVal > 0 ? maxVal : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: Column(children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _ultimi7Giorni.map((day) {
              final val = day['totale'] as double;
              final height = (val / chartMax) * 100;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (val > 0)
                          Text('\u20AC${val.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary)),
                        const SizedBox(height: 4),
                        Container(
                          height: height < 4 && val > 0 ? 4 : height,
                          decoration: BoxDecoration(
                            color: val > 0
                                ? AppTheme.primary
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ]),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _ultimi7Giorni
              .map((day) => Expanded(
                    child: Text(
                      (day['label'] as String).substring(0, 3),
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 10, color: AppTheme.grey),
                    ),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style: const TextStyle(color: AppTheme.grey, fontSize: 12),
                  textAlign: TextAlign.center),
            ])));
  }
}
