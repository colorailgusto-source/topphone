import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});
  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _topViews = [];
  List<Map<String, dynamic>> _topCart = [];
  int _totalViews = 0;
  int _totalCart = 0;
  int _totalOrdini = 0;
  Map<int, int> _orePunta = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Top prodotti visti
      final views = await _client.from('analytics').select('prodotto_id, prodotti(nome, marca)').eq('evento', 'view');
      final cart = await _client.from('analytics').select('prodotto_id, prodotti(nome, marca)').eq('evento', 'add_cart');
      final ordini = await _client.from('ordini').select('id');
      final allAnalytics = await _client.from('analytics').select('evento, created_at');

      // Conta per prodotto
      final viewMap = <String, Map<String, dynamic>>{};
      for (final v in views) {
        final pid = v['prodotto_id'];
        if (!viewMap.containsKey(pid)) viewMap[pid] = {'nome': v['prodotti']?['nome'] ?? 'Sconosciuto', 'marca': v['prodotti']?['marca'] ?? '', 'count': 0};
        viewMap[pid]!['count'] = (viewMap[pid]!['count'] as int) + 1;
      }
      final cartMap = <String, Map<String, dynamic>>{};
      for (final v in cart) {
        final pid = v['prodotto_id'];
        if (!cartMap.containsKey(pid)) cartMap[pid] = {'nome': v['prodotti']?['nome'] ?? 'Sconosciuto', 'marca': v['prodotti']?['marca'] ?? '', 'count': 0};
        cartMap[pid]!['count'] = (cartMap[pid]!['count'] as int) + 1;
      }

      // Ore di punta
      final ore = <int, int>{};
      for (final a in allAnalytics) {
        final dt = DateTime.parse(a['created_at']).toLocal();
        ore[dt.hour] = (ore[dt.hour] ?? 0) + 1;
      }

      final sortedViews = viewMap.values.toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      final sortedCart = cartMap.values.toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      if (mounted) setState(() {
        _topViews = sortedViews.take(10).toList();
        _topCart = sortedCart.take(10).toList();
        _totalViews = views.length;
        _totalCart = cart.length;
        _totalOrdini = ordini.length;
        _orePunta = ore;
        _loading = false;
      });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        title: const Text('Analytics'),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stats generali
                Row(children: [
                  _statCard('👁️ Visualizzazioni', '$_totalViews', Colors.blue),
                  const SizedBox(width: 8),
                  _statCard('🛒 Aggiunte', '$_totalCart', Colors.orange),
                  const SizedBox(width: 8),
                  _statCard('📦 Ordini', '$_totalOrdini', Colors.green),
                ]),
                const SizedBox(height: 8),
                // Tasso conversione
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _convRate('View→Cart', _totalViews > 0 ? (_totalCart / _totalViews * 100).toStringAsFixed(1) : '0', Colors.orange),
                    _convRate('Cart→Ordine', _totalCart > 0 ? (_totalOrdini / _totalCart * 100).toStringAsFixed(1) : '0', Colors.green),
                    _convRate('View→Ordine', _totalViews > 0 ? (_totalOrdini / _totalViews * 100).toStringAsFixed(1) : '0', AppTheme.primary),
                  ]),
                ),
                const SizedBox(height: 16),
                // Top prodotti visti
                _sectionTitle('👁️ Prodotti più visti'),
                ..._topViews.asMap().entries.map((e) => _rankTile(e.key + 1, e.value['marca'], e.value['nome'], e.value['count'], Colors.blue)),
                const SizedBox(height: 16),
                // Top aggiunte carrello
                _sectionTitle('🛒 Più aggiunti al carrello'),
                ..._topCart.asMap().entries.map((e) => _rankTile(e.key + 1, e.value['marca'], e.value['nome'], e.value['count'], Colors.orange)),
                const SizedBox(height: 16),
                // Ore di punta
                if (_orePunta.isNotEmpty) ...[
                  _sectionTitle('⏰ Ore di punta'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                    child: Column(children: (_orePunta.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).map((e) {
                        final max = _orePunta.values.reduce((a, b) => a > b ? a : b);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            SizedBox(width: 50, child: Text('${e.key}:00', style: const TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: e.value / max,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                                minHeight: 12,
                              ),
                            )),
                            const SizedBox(width: 8),
                            Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                        );
                      }).toList()),

                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
    );
  }

  Widget _statCard(String label, String value, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.grey), textAlign: TextAlign.center),
    ]),
  ));

  Widget _convRate(String label, String value, Color color) => Column(children: [
    Text('$value%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
  ]);

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
  );

  Widget _rankTile(int rank, String marca, String nome, int count, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
    child: Row(children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('$rank', style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 12)))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(marca, style: const TextStyle(fontSize: 11, color: AppTheme.grey)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text('$count', style: TextStyle(fontWeight: FontWeight.w700, color: color))),
    ]),
  );
}
