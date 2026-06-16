import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../models/product_model.dart';
import '../../models/variant_model.dart';
import '../../theme/app_theme.dart';
import 'package:badges/badges.dart' as badges;
import 'package:go_router/go_router.dart';
import '../../widgets/gradient_app_bar.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final String? selectedRam;
  final String? selectedMemoria;
  const ProductDetailScreen({super.key, required this.productId, this.selectedRam, this.selectedMemoria});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _productService = ProductService();
  final _client = Supabase.instance.client;
  ProductModel? _product;
  List<VariantModel> _variants = [];
  List<Map<String, dynamic>> _suggeriti = [];
  Map<String, List<Map<String, dynamic>>> _suggeritiVariants = {};
  final _suggeritiScrollCtrl = ScrollController();
  Timer? _autoScrollTimer;
  bool _loading = true;
  bool _addingToCart = false;
  Timer? _refreshTimer;
  bool _showCartAnimation = false;
  String _selectedRam = '';
  String _selectedMemoria = '';
  String _selectedColore = '';

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshStock());
  }

  @override
  void dispose() { _refreshTimer?.cancel(); _autoScrollTimer?.cancel(); _suggeritiScrollCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final p = await _productService.getProduct(widget.productId);
    final v = await _client.from('varianti_prodotto').select().eq('prodotto_id', widget.productId);
    if (mounted) setState(() {
      _product = p;
      _variants = (v as List).map((e) => VariantModel.fromJson(e)).toList();
      _loading = false;
    });
    await _loadSuggeriti();
    await _trackView();
    if (mounted) setState(() {
      if (widget.selectedRam != null && widget.selectedRam!.isNotEmpty) {
        _selectedRam = widget.selectedRam!;
      }
      if (widget.selectedMemoria != null && widget.selectedMemoria!.isNotEmpty) {
        _selectedMemoria = widget.selectedMemoria!;
      }
      // Auto-seleziona se c'è una sola variante
      if (_selectedRam.isEmpty && _selectedMemoria.isEmpty) {
        final tutteRam = _variants.map((v) => v.ram).where((r) => r.isNotEmpty).toSet().toList();
        final tutteMemorie = _variants.map((v) => v.memoria).where((m) => m.isNotEmpty).toSet().toList();
        if (tutteRam.length == 1) _selectedRam = tutteRam.first;
        if (tutteMemorie.length == 1) _selectedMemoria = tutteMemorie.first;
      }
    });
  }

  Future<void> _loadSuggeriti() async {
    if (_product == null) return;
    final marca = _product!.marca;
    final prezzo = _product!.prezzo;
    final id = _product!.id;
    // Prima: stessa marca, prezzo simile ±150€
    final data = await Supabase.instance.client
        .from('prodotti')
        .select()
        .eq('marca', marca)
        .eq('attivo', true)
        .neq('id', id)
        .gte('prezzo', prezzo - 150)
        .lte('prezzo', prezzo + 150)
        .limit(6);
    List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(data);
    // Se meno di 3, aggiungi altre marche
    if (results.length < 3) {
      final altri = await Supabase.instance.client
          .from('prodotti')
          .select()
          .eq('attivo', true)
          .neq('id', id)
          .neq('marca', marca)
          .gte('prezzo', prezzo - 150)
          .lte('prezzo', prezzo + 150)
          .limit(6 - results.length);
      results.addAll(List<Map<String, dynamic>>.from(altri));
    }
    // Carica varianti per ogni prodotto
    final Map<String, List<Map<String, dynamic>>> varMap = {};
    for (final p in results) {
      final v = await Supabase.instance.client
          .from('varianti_prodotto')
          .select('prodotto_id, ram, memoria, prezzo_extra, stock')
          .eq('prodotto_id', p['id'])
          .order('prezzo_extra');
      varMap[p['id']] = List<Map<String, dynamic>>.from(v);
    }
    if (mounted) setState(() { _suggeriti = results; _suggeritiVariants = varMap; });
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (_suggeriti.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_suggeritiScrollCtrl.hasClients) return;
      final max = _suggeritiScrollCtrl.position.maxScrollExtent;
      final current = _suggeritiScrollCtrl.offset;
      if (current >= max) {
        _suggeritiScrollCtrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else {
        _suggeritiScrollCtrl.animateTo(current + 160, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
    });
  }

  Future<void> _trackAddCart() async {
    if (_product == null) return;
    try {
      final isAdmin = await _isAdmin();
      if (isAdmin) return;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('analytics').insert({
        'prodotto_id': _product!.id,
        'evento': 'add_cart',
        'utente_id': userId,
      });
    } catch (e) { /* silenzioso */ }
  }

  Future<void> _trackView() async {
    if (_product == null) return;
    try {
      final isAdmin = await _isAdmin();
      if (isAdmin) return;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('analytics').insert({
        'prodotto_id': _product!.id,
        'evento': 'view',
        'utente_id': userId,
      });
    } catch (e) { /* silenzioso */ }
  }

  Future<bool> _isAdmin() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final data = await Supabase.instance.client.from('profili').select('ruolo').eq('id', userId).single();
      return data['ruolo'] == 'admin';
    } catch (e) { return false; }
  }

  Future<void> _refreshStock() async {
    if (_hasVariants) {
      final v = await _client.from('varianti_prodotto').select().eq('prodotto_id', widget.productId);
      if (mounted) setState(() => _variants = (v as List).map((e) => VariantModel.fromJson(e)).toList());
    } else {
      final p = await _productService.getProduct(widget.productId);
      if (mounted) setState(() => _product = p);
    }
  }

  bool get _hasVariants => _variants.isNotEmpty;

  VariantModel? get _selectedVariant {
    if (!_selectionComplete) return null;
    return _variants.where((v) {
      final matchRam = _tutteRam.isEmpty || v.ram == _selectedRam;
      final matchMemoria = _tutteMemorie.isEmpty || v.memoria == _selectedMemoria;
      final matchColore = _tuttiColori.isEmpty || v.colore == _selectedColore;
      return matchRam && matchMemoria && matchColore;
    }).firstOrNull;
  }

  List<String> get _tutteRam => _variants.map((v) => v.ram).where((r) => r.isNotEmpty).toSet().toList()..sort();
  List<String> get _tutteMemorie {
    var f = _variants.toList();
    if (_selectedRam.isNotEmpty) f = f.where((v) => v.ram == _selectedRam).toList();
    return f.map((v) => v.memoria).where((m) => m.isNotEmpty).toSet().toList()..sort();
  }
  List<String> get _tuttiColori {
    var f = _variants.toList();
    if (_selectedRam.isNotEmpty) f = f.where((v) => v.ram == _selectedRam).toList();
    if (_selectedMemoria.isNotEmpty) f = f.where((v) => v.memoria == _selectedMemoria).toList();
    return f.map((v) => v.colore).where((c) => c.isNotEmpty).toSet().toList()..sort();
  }

  bool _isAvailable(String type, String value) {
    var f = _variants.where((v) => v.stock > 0).toList();
    if (type == 'ram') return f.any((v) => v.ram == value);
    if (type == 'memoria') {
      if (_selectedRam.isNotEmpty) f = f.where((v) => v.ram == _selectedRam).toList();
      return f.any((v) => v.memoria == value);
    }
    if (type == 'colore') {
      if (_selectedRam.isNotEmpty) f = f.where((v) => v.ram == _selectedRam).toList();
      if (_selectedMemoria.isNotEmpty) f = f.where((v) => v.memoria == _selectedMemoria).toList();
      return f.any((v) => v.colore == value);
    }
    return false;
  }

  int get _stockMostrato {
    if (_hasVariants) return _selectedVariant?.stock ?? 0;
    return _product?.stock ?? 0;
  }

  double get _prezzoFinale {
    if (_selectedVariant != null) return (_product?.prezzo ?? 0) + _selectedVariant!.prezzoExtra;
    if (_selectedRam.isNotEmpty) {
      final ramVariants = _variants.where((v) => v.ram == _selectedRam).toList();
      if (ramVariants.isNotEmpty) {
        final minExtra = ramVariants.map((v) => v.prezzoExtra).reduce((a, b) => a < b ? a : b);
        return (_product?.prezzo ?? 0) + minExtra;
      }
    }
    if (_selectedMemoria.isNotEmpty) {
      final memVariants = _variants.where((v) => v.memoria == _selectedMemoria).toList();
      if (memVariants.isNotEmpty) {
        final minExtra = memVariants.map((v) => v.prezzoExtra).reduce((a, b) => a < b ? a : b);
        return (_product?.prezzo ?? 0) + minExtra;
      }
    }
    return _product?.prezzo ?? 0;
  }

  bool get _selectionComplete {
    if (!_hasVariants) return true;
    return (_tutteRam.isEmpty || _selectedRam.isNotEmpty) &&
           (_tutteMemorie.isEmpty || _selectedMemoria.isNotEmpty) &&
           (_tuttiColori.isEmpty || _selectedColore.isNotEmpty);
  }

  Widget _chip(String value, bool selected, bool available, VoidCallback onTap) {
    return GestureDetector(
      onTap: available && !_addingToCart ? onTap : null,
      child: Opacity(
        opacity: available ? 1.0 : 0.35,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? AppTheme.primary : AppTheme.grey.withValues(alpha: 0.4), width: selected ? 2 : 1),
          ),
          child: Text(value, style: TextStyle(color: selected ? Colors.white : AppTheme.textDark, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _selectionComplete && _stockMostrato > 0 && !_addingToCart;
    return Scaffold(
      appBar: GradientAppBar(
        title: _product?.nome ?? 'Prodotto',
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/compare/' + widget.productId, extra: {'ram': _selectedRam, 'memoria': _selectedMemoria, 'colore': _selectedColore}),
            icon: const Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 18),
            label: const Text('Confronta', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              final nome = _product?.nome ?? '';
              final prezzo = _product?.prezzo.toStringAsFixed(0) ?? '';
              final marca = _product?.marca ?? '';
              SharePlus.instance.share(ShareParams(
                text: '📱 $marca $nome\n💰 €$prezzo\n\nScopri questo prodotto su Top Phone Torre!\nVia Nazionale 68, Torre del Greco',
              ));
            },
          ),
          Consumer<CartService>(
            builder: (ctx, cart, _) => AnimatedScale(
              scale: _showCartAnimation ? 1.4 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              child: badges.Badge(
                position: badges.BadgePosition.topEnd(top: -8, end: -8),
                badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red, padding: EdgeInsets.all(5)),
                badgeContent: Text(cart.count.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                showBadge: cart.count > 0,
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                  onPressed: () => context.push('/cart'),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _product == null ? const Center(child: Text('Prodotto non trovato'))
        : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _product!.immagine.isNotEmpty
              ? Image.network(_product!.immagine, height: 280, width: double.infinity, fit: BoxFit.contain,
                  errorBuilder: (c,e,s) => Container(height: 280, color: AppTheme.background, child: const Icon(Icons.phone_android, size: 100, color: AppTheme.primary)))
              : Container(height: 280, color: AppTheme.background, child: const Icon(Icons.phone_android, size: 100, color: AppTheme.primary)),
            Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_product!.marca, style: const TextStyle(color: AppTheme.grey, fontSize: 14)),
              const SizedBox(height: 4),
              Text(_product!.nome, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('€${_prezzoFinale.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, color: AppTheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_tutteRam.isNotEmpty) ...[
                Row(children: [
                  const Text('RAM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (_selectedRam.isNotEmpty) ...[const Spacer(), TextButton(onPressed: () => setState(() { _selectedRam=''; _selectedMemoria=''; _selectedColore=''; }), child: const Text('Reset'))],
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _tutteRam.map((r) => _chip(r, _selectedRam==r, _isAvailable('ram', r), () => setState(() { _selectedRam=_selectedRam==r?'':r; _selectedMemoria=''; _selectedColore=''; }))).toList()),
                const SizedBox(height: 16),
              ],
              if (_tutteMemorie.isNotEmpty && (_selectedRam.isNotEmpty || _tutteRam.isEmpty)) ...[
                Row(children: [
                  const Text('Memoria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (_selectedMemoria.isNotEmpty) ...[const Spacer(), TextButton(onPressed: () => setState(() { _selectedMemoria=''; _selectedColore=''; }), child: const Text('Reset'))],
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _tutteMemorie.map((m) => _chip(m, _selectedMemoria==m, _isAvailable('memoria', m), () => setState(() { _selectedMemoria=_selectedMemoria==m?'':m; _selectedColore=''; }))).toList()),
                const SizedBox(height: 16),
              ],
              if (_tuttiColori.isNotEmpty && (_selectedMemoria.isNotEmpty || _tutteMemorie.isEmpty)) ...[
                Row(children: [
                  const Text('Colore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (_selectedColore.isNotEmpty) ...[const Spacer(), TextButton(onPressed: () => setState(() { _selectedColore=''; }), child: const Text('Reset'))],
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _tuttiColori.map((c) => _chip(c, _selectedColore==c, _isAvailable('colore', c), () => setState(() { _selectedColore=_selectedColore==c?'':c; }))).toList()),
                const SizedBox(height: 16),
              ],
              if (_hasVariants && !_selectionComplete)
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [Icon(Icons.info_outline, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('Seleziona tutte le opzioni per continuare', style: TextStyle(color: Colors.orange)))]))
              else if (_selectionComplete)
                Row(children: [
                  Icon(_stockMostrato > 0 ? Icons.check_circle : Icons.cancel, color: _stockMostrato > 0 ? Colors.green : Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Text(_stockMostrato > 0 ? 'Disponibile' : '⚠️ Esaurito',
                    style: TextStyle(color: _stockMostrato > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                ]),
              const SizedBox(height: 16),
              const Text('Descrizione', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(_product!.descrizione, style: const TextStyle(color: AppTheme.grey, height: 1.5)),
              const SizedBox(height: 24),
              SafeArea(top: false, child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: canAdd ? () async {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user == null) {
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Accedi per acquistare', style: TextStyle(fontWeight: FontWeight.w700)),
                      content: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Registrati o accedi per acquistare e ricevere a casa!'),
                        const SizedBox(height: 16),
                        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.pop(ctx); context.go('/register'); }, child: const Text('Registrati — è gratis!'))),
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () { Navigator.pop(ctx); context.go('/login'); }, child: const Text('Accedi'))),
                      ]),
                    ));
                    return;
                  }
                  HapticFeedback.mediumImpact();
                  setState(() => _addingToCart = true);
                  _trackAddCart();
                  final success = await context.read<CartService>().addItem(_product!, 1, variant: _selectedVariant);
                  if (success && mounted) {
                    setState(() => _showCartAnimation = true);
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (mounted) setState(() => _showCartAnimation = false);
                  }
                  if (mounted) {
                    await _refreshStock();
                    setState(() => _addingToCart = false);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Aggiunto al carrello!')]),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(12),
                        duration: const Duration(seconds: 2),
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.read<CartService>().hasItems ? '🛒 Hai già un prodotto nel carrello. Rimuovilo prima.' : '⚠️ Stock esaurito.'),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(12),
                      ));
                    }
                  }
                } : null,
                icon: _addingToCart ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.shopping_cart),
                label: Text(_addingToCart ? 'Aggiunta in corso...' : !_selectionComplete ? 'Seleziona le opzioni' : _stockMostrato > 0 ? 'Aggiungi al Carrello' : 'Non disponibile', style: const TextStyle(fontSize: 16)),
              ))),
            ])),
            // Sezione Potrebbe Piacerti
            if (_suggeriti.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Container(width: 4, height: 20, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  const Text('Potrebbe Piacerti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                  const SizedBox(width: 6),
                  const Text('👀', style: TextStyle(fontSize: 16)),
                ]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 235,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  controller: _suggeritiScrollCtrl,
                  itemCount: _suggeriti.length,
                  itemBuilder: (ctx, i) {
                    final p = _suggeriti[i];
                    final variants = _suggeritiVariants[p['id']] ?? [];
                    return GestureDetector(
                      onTap: () { final pid = p['id'].toString(); context.push('/product/' + pid); },
                      child: Container(
                        width: 155,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Container(
                              height: 110,
                              width: double.infinity,
                              color: Colors.grey.shade50,
                              child: p['immagine'] != null && p['immagine'].toString().isNotEmpty
                                ? Image.network(p['immagine'], height: 110, width: double.infinity, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.phone_android, size: 40, color: AppTheme.primary))
                                : const Icon(Icons.phone_android, size: 40, color: AppTheme.primary),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p['marca'] ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.grey, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(p['nome'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Poppins'), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Text('€${(p['prezzo'] as num? ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w800)),
                              if (variants.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  variants.isNotEmpty ? ((variants.first['ram'] ?? '').toString().isNotEmpty ? '${variants.first['ram']} / ${variants.first['memoria']}' : variants.first['memoria']?.toString() ?? '') : '',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 100),
            ],
          ])),
    );
  }
}