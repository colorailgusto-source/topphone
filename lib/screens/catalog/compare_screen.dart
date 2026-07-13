import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class CompareScreen extends StatefulWidget {
  final String productId1;
  final String? productId2;
  final String? ram1;
  final String? memoria1;
  const CompareScreen(
      {super.key,
      required this.productId1,
      this.productId2,
      this.ram1,
      this.memoria1});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _client = Supabase.instance.client;
  Map<String, dynamic>? _p1;
  Map<String, dynamic>? _p2;
  Map<String, dynamic>? _v1;
  Map<String, dynamic>? _v2;
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p1 = await _client
        .from('prodotti')
        .select()
        .eq('id', widget.productId1)
        .single();
    var q1 = _client
        .from('varianti_prodotto')
        .select()
        .eq('prodotto_id', widget.productId1);
    if (widget.ram1 != null && widget.ram1!.isNotEmpty) {
      q1 = q1.eq('ram', widget.ram1!);
    }
    if (widget.memoria1 != null && widget.memoria1!.isNotEmpty) {
      q1 = q1.eq('memoria', widget.memoria1!);
    }
    final v1 = await q1.order('prezzo_extra').limit(1);
    final all = await _client
        .from('prodotti')
        .select('id, nome, marca, prezzo, immagine')
        .eq('attivo', true)
        .order('marca');

    Map<String, dynamic>? p2;
    Map<String, dynamic>? v2;
    if (widget.productId2 != null) {
      p2 = await _client
          .from('prodotti')
          .select()
          .eq('id', widget.productId2!)
          .single();
      final v2data = await _client
          .from('varianti_prodotto')
          .select()
          .eq('prodotto_id', widget.productId2!)
          .order('prezzo_extra')
          .limit(1);
      v2 = v2data.isNotEmpty ? v2data[0] : null;
    }

    if (mounted) {
      setState(() {
        _p1 = p1;
        _v1 = v1.isNotEmpty ? v1[0] : null;
        _p2 = p2;
        _v2 = v2;
        _allProducts = List<Map<String, dynamic>>.from(all);
        _filteredProducts = _allProducts;
        _loading = false;
      });
    }
  }

  Future<void> _selectProduct2(String id) async {
    final p2 = await _client.from('prodotti').select().eq('id', id).single();
    final v2data = await _client
        .from('varianti_prodotto')
        .select()
        .eq('prodotto_id', id)
        .order('prezzo_extra');
    final uniqueVarianti = <String, Map<String, dynamic>>{};
    for (final v in v2data) {
      final k = (v['ram'] ?? '') + '/' + (v['memoria'] ?? '');
      uniqueVarianti.putIfAbsent(k, () => v);
    }
    if (uniqueVarianti.length > 1) {
      _showVariantSelector(p2, uniqueVarianti.values.toList());
    } else {
      setState(() {
        _p2 = p2;
        _v2 = v2data.isNotEmpty ? v2data[0] : null;
      });
    }
  }

  void _showVariantSelector(Map<String, dynamic> p2, List<dynamic> varianti) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              Text('Scegli variante di ${p2['nome']}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins')),
              const SizedBox(height: 12),
              ...() {
                final seen = <String>{};
                final unique = <Map<String, dynamic>>[];
                for (final v in varianti) {
                  final key = (v["ram"] ?? "") + "/" + (v["memoria"] ?? "");
                  if (!seen.contains(key)) {
                    seen.add(key);
                    unique.add(v);
                  }
                }
                return unique.map((v) {
                  final ram = v['ram'] ?? '';
                  final mem = v['memoria'] ?? '';
                  final extra = (v['prezzo_extra'] as num? ?? 0);
                  final prezzo =
                      ((p2['prezzo'] as num? ?? 0) + extra).toStringAsFixed(0);
                  final label = ram.isNotEmpty ? ram + ' / ' + mem : mem;
                  return ListTile(
                    title: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text('\u20AC$prezzo',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _p2 = p2;
                        _v2 = v;
                      });
                    },
                  );
                }).toList();
              }(),
              const SizedBox(height: 8),
            ]),
      ),
    );
  }

  Color _compareColor(dynamic val1, dynamic val2, bool higherIsBetter) {
    if (val1 == null || val2 == null) return Colors.grey;
    final v1 = (val1 as num).toDouble();
    final v2 = (val2 as num).toDouble();
    if (v1 == v2) return Colors.grey;
    return higherIsBetter
        ? (v1 > v2 ? Colors.green : Colors.red)
        : (v1 < v2 ? Colors.green : Colors.red);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                // Header gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF01579B), Color(0xFF0288D1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => context.pop()),
                        const Text('Confronta Prodotti',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins')),
                      ]),
                    ),
                  ),
                ),
                // Selettori prodotti
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    // Prodotto 1
                    Expanded(
                        child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(children: [
                        _p1?['immagine'] != null &&
                                _p1!['immagine'].toString().isNotEmpty
                            ? Image.network(_p1!['immagine'],
                                height: 70, fit: BoxFit.contain)
                            : const Icon(Icons.phone_android,
                                size: 50, color: AppTheme.primary),
                        const SizedBox(height: 6),
                        Text(_p1?['marca'] ?? '',
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.grey)),
                        Text(_p1?['nome'] ?? '',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins'),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        Text(
                            '\u20AC${((_p1?['prezzo'] as num? ?? 0) + (_v1?['prezzo_extra'] as num? ?? 0)).toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800)),
                      ]),
                    )),
                    // VS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle),
                        child: const Center(
                            child: Text('VS',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800))),
                      ),
                    ),
                    // Prodotto 2
                    Expanded(
                        child: GestureDetector(
                      onTap: _p2 == null ? () => _showSelector() : null,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _p2 != null
                              ? Colors.orange.withValues(alpha: 0.08)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _p2 != null
                                  ? Colors.orange.withValues(alpha: 0.3)
                                  : Colors.grey.shade300),
                        ),
                        child: _p2 == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    const SizedBox(height: 10),
                                    Icon(Icons.add_circle_outline,
                                        size: 40, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text('Seleziona\nprodotto',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12)),
                                    const SizedBox(height: 10),
                                  ])
                            : Column(children: [
                                GestureDetector(
                                  onTap: _showSelector,
                                  child: Align(
                                      alignment: Alignment.topRight,
                                      child: Icon(Icons.swap_horiz_rounded,
                                          color: Colors.orange.shade400,
                                          size: 18)),
                                ),
                                _p2!['immagine'] != null &&
                                        _p2!['immagine'].toString().isNotEmpty
                                    ? Image.network(_p2!['immagine'],
                                        height: 60, fit: BoxFit.contain)
                                    : const Icon(Icons.phone_android,
                                        size: 50, color: Colors.orange),
                                const SizedBox(height: 6),
                                Text(_p2?['marca'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 10, color: AppTheme.grey)),
                                Text(_p2?['nome'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Poppins'),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                    '\u20AC${((_p2?['prezzo'] as num? ?? 0) + (_v2?['prezzo_extra'] as num? ?? 0)).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w800)),
                              ]),
                      ),
                    )),
                  ]),
                ),
                // Tabella confronto
                if (_p2 != null)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 16, 16,
                          MediaQuery.of(context).padding.bottom + 80),
                      child: Column(children: [
                        _buildSpecCard(
                            '💰 Prezzo',
                            '\u20AC${((_p1?['prezzo'] as num? ?? 0) +
                                        (_v1?['prezzo_extra'] as num? ?? 0))
                                    .toStringAsFixed(0)}',
                            '\u20AC${((_p2?['prezzo'] as num? ?? 0) +
                                        (_v2?['prezzo_extra'] as num? ?? 0))
                                    .toStringAsFixed(0)}',
                            (_p1?['prezzo'] as num? ?? 0) +
                                (_v1?['prezzo_extra'] as num? ?? 0),
                            (_p2?['prezzo'] as num? ?? 0) +
                                (_v2?['prezzo_extra'] as num? ?? 0),
                            false),
                        _buildSpecCard(
                            '🔋 Batteria',
                            _p1?['batteria_mah'] != null
                                ? '${_p1!['batteria_mah']} mAh'
                                : 'N/D',
                            _p2?['batteria_mah'] != null
                                ? '${_p2!['batteria_mah']} mAh'
                                : 'N/D',
                            _p1?['batteria_mah'],
                            _p2?['batteria_mah'],
                            true),
                        _buildSpecCard(
                            '📸 Fotocamera',
                            _p1?['fotocamera_mp'] != null
                                ? '${_p1!['fotocamera_mp']} MP'
                                : 'N/D',
                            _p2?['fotocamera_mp'] != null
                                ? '${_p2!['fotocamera_mp']} MP'
                                : 'N/D',
                            _p1?['fotocamera_mp'],
                            _p2?['fotocamera_mp'],
                            true),
                        _buildSpecCard('💾 RAM', _v1?['ram'] ?? 'N/D',
                            _v2?['ram'] ?? 'N/D', null, null, true),
                        _buildSpecCard(
                            '📺 Schermo',
                            _p1?['schermo_pollici'] != null
                                ? '${_p1!['schermo_pollici']}"'
                                : 'N/D',
                            _p2?['schermo_pollici'] != null
                                ? '${_p2!['schermo_pollici']}"'
                                : 'N/D',
                            _p1?['schermo_pollici'],
                            _p2?['schermo_pollici'],
                            true),
                        _buildSpecCard(
                            '⚡ Processore',
                            _p1?['processore'] ?? 'N/D',
                            _p2?['processore'] ?? 'N/D',
                            null,
                            null,
                            true),
                        _buildSpecCard('📱 Memoria', _v1?['memoria'] ?? 'N/D',
                            _v2?['memoria'] ?? 'N/D', null, null, true),
                        const SizedBox(height: 16),
                        // Bottoni acquisto
                        Row(children: [
                          Expanded(
                              child: ElevatedButton(
                            onPressed: () => context
                                .push('/product/' + (_p1?['id'] ?? ''), extra: {
                              'ram': _v1?['ram'] ?? '',
                              'mem': _v1?['memoria'] ?? ''
                            }),
                            style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12)),
                            child: const Text('Acquista'),
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: ElevatedButton(
                            onPressed: () => context
                                .push('/product/' + (_p2?['id'] ?? ''), extra: {
                              'ram': _v2?['ram'] ?? '',
                              'mem': _v2?['memoria'] ?? ''
                            }),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12)),
                            child: const Text('Acquista'),
                          )),
                        ]),
                      ]),
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Icon(Icons.compare_arrows_rounded,
                              size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('Seleziona un prodotto\nda confrontare',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 16,
                                  fontFamily: 'Poppins')),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showSelector,
                            icon: const Icon(Icons.add),
                            label: const Text('Scegli prodotto'),
                          ),
                        ])),
                  ),
              ]),
      ),
    );
  }

  Widget _buildSpecCard(String label, String val1, String val2, dynamic numVal1,
      dynamic numVal2, bool higherIsBetter) {
    final color1 = numVal1 != null && numVal2 != null
        ? _compareColor(numVal1, numVal2, higherIsBetter)
        : Colors.grey;
    final color2 = numVal1 != null && numVal2 != null
        ? _compareColor(numVal2, numVal1, higherIsBetter)
        : Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
          ]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(
              child: Text(val1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color1))),
          Container(
            width: 80,
            alignment: Alignment.center,
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
              child: Text(val2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color2))),
        ]),
      ),
    );
  }

  void _showSelector() {
    _searchCtrl.clear();
    setState(() => _filteredProducts = _allProducts);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (ctx, scroll) => Column(children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('Scegli prodotto da confrontare',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setS(() => _filteredProducts = _allProducts
                    .where((p) =>
                        (p['nome'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(v.toLowerCase()) ||
                        (p['marca'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(v.toLowerCase()))
                    .toList()),
                decoration: InputDecoration(
                  hintText: 'Cerca smartphone...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
                child: ListView.builder(
              controller: scroll,
              itemCount: _filteredProducts.length,
              itemBuilder: (c, i) {
                final p = _filteredProducts[i];
                if (p['id'] == widget.productId1) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: p['immagine'] != null &&
                          p['immagine'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(p['immagine'],
                              width: 40, height: 40, fit: BoxFit.contain))
                      : const Icon(Icons.phone_android,
                          color: AppTheme.primary),
                  title: Text(p['nome'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p['marca'] ?? ''),
                  trailing: Text(
                      '\u20AC${(p['prezzo'] as num? ?? 0).toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _selectProduct2(p['id']);
                  },
                );
              },
            )),
          ]),
        ),
      ),
    );
  }
}
