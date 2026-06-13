import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/product_service.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_card_shimmer.dart';

class CatalogScreen extends StatefulWidget {
  final String? categoriaIniziale;
  const CatalogScreen({super.key, this.categoriaIniziale});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _productService = ProductService();
  final _client = Supabase.instance.client;
  List<ProductModel> _all = [];
  List<ProductModel> _filtered = [];
  Map<String, List<Map<String, dynamic>>> _variantsMap = {};
  List<Map<String, dynamic>> _categorie = [];
  String _search = '';
  String _selectedCategoria = 'Tutti';
  bool _loading = true;
  double _maxPrezzo = 1500;
  String _selectedMemoria = '';
  String _selectedRam = '';

  @override
  void initState() { super.initState(); _load(); }



  Future<void> _load() async {
    final p = await _productService.getProducts();
    final variantsData = await _client.from('varianti_prodotto').select('prodotto_id, ram, memoria, prezzo_extra, stock').order('prezzo_extra');
    final varMap = <String, List<Map<String, dynamic>>>{};
    for (final v in variantsData) { final pid = v['prodotto_id'] as String; varMap.putIfAbsent(pid, () => []).add(v); }
    final c = await _client.from('categorie').select().eq('attiva', true).order('ordine');
    if (mounted) setState(() {
      _all = p;
      if (widget.categoriaIniziale != null) {
        _selectedCategoria = widget.categoriaIniziale!;
      }
      _filtered = _selectedCategoria == 'Tutti' ? p : p.where((prod) => prod.marca.toLowerCase() == _selectedCategoria.toLowerCase()).toList();
      _categorie = List<Map<String, dynamic>>.from(c);
      _variantsMap = varMap;
      _loading = false;
    });
  }

  void _filter() {
    setState(() {
      _filtered = _all.where((p) {
        final matchSearch = p.nome.toLowerCase().contains(_search.toLowerCase()) || p.marca.toLowerCase().contains(_search.toLowerCase());
        final matchCat = _selectedCategoria == 'Tutti' || p.marca.toLowerCase() == _selectedCategoria.toLowerCase();
        final matchPrezzo = p.prezzo <= _maxPrezzo;
        final variants = _variantsMap[p.id] ?? [];
        final matchMemoria = _selectedMemoria.isEmpty || variants.any((v) => v['memoria']?.toString() == _selectedMemoria);
        final matchRam = _selectedRam.isEmpty || variants.any((v) => v['ram']?.toString() == _selectedRam);
        return matchSearch && matchCat && matchPrezzo && matchMemoria && matchRam;
      }).toList();
    });
  }

  void _showFiltri() {
    double tempPrezzo = _maxPrezzo;
    String tempMemoria = _selectedMemoria;
    String tempRam = _selectedRam;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Filtri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(onPressed: () { setS(() { tempPrezzo = 1500; tempMemoria = ''; tempRam = ''; }); }, child: const Text('Reset')),
            ]),
            const SizedBox(height: 16),
            Text('Prezzo massimo: €${tempPrezzo.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: tempPrezzo,
              min: 50,
              max: 1500,
              divisions: 29,
              activeColor: AppTheme.primary,
              onChanged: (v) => setS(() => tempPrezzo = v),
            ),
            const SizedBox(height: 12),
            const Text('Memoria', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: ['', '128GB', '256GB', '512GB'].map((m) => ChoiceChip(
              label: Text(m.isEmpty ? 'Tutte' : m),
              selected: tempMemoria == m,
              selectedColor: AppTheme.primary,
              labelStyle: TextStyle(color: tempMemoria == m ? Colors.white : AppTheme.textDark),
              onSelected: (_) => setS(() => tempMemoria = m),
            )).toList()),
            const SizedBox(height: 12),
            const Text('RAM', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: ['', '4GB', '6GB', '8GB', '12GB'].map((r) => ChoiceChip(
              label: Text(r.isEmpty ? 'Tutte' : r),
              selected: tempRam == r,
              selectedColor: AppTheme.primary,
              labelStyle: TextStyle(color: tempRam == r ? Colors.white : AppTheme.textDark),
              onSelected: (_) => setS(() => tempRam = r),
            )).toList()),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                setState(() { _maxPrezzo = tempPrezzo; _selectedMemoria = tempMemoria; _selectedRam = tempRam; });
                _filter();
                Navigator.pop(ctx);
              },
              child: const Text('Applica Filtri'),
            )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: 'Catalogo'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) { _search = v; _filter(); },
            decoration: const InputDecoration(hintText: 'Cerca smartphone...', prefixIcon: Icon(Icons.search)),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Tutti'),
                  selected: _selectedCategoria == 'Tutti',
                  onSelected: (_) { setState(() => _selectedCategoria = 'Tutti'); _filter(); },
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(color: _selectedCategoria == 'Tutti' ? Colors.white : AppTheme.textDark),
                )),
              ..._categorie.map((cat) => Padding(padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat['nome']),
                  selected: _selectedCategoria == cat['nome'],
                  onSelected: (_) { setState(() => _selectedCategoria = cat['nome']); _filter(); },
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(color: _selectedCategoria == cat['nome'] ? Colors.white : AppTheme.textDark),
                ))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Expanded(child: _selectedMemoria.isNotEmpty || _selectedRam.isNotEmpty || _maxPrezzo < 1500
              ? Wrap(spacing: 6, children: [
                  if (_maxPrezzo < 1500) Chip(label: Text('Max €${_maxPrezzo.toStringAsFixed(0)}'), onDeleted: () { setState(() => _maxPrezzo = 1500); _filter(); }, deleteIconColor: Colors.red),
                  if (_selectedMemoria.isNotEmpty) Chip(label: Text(_selectedMemoria), onDeleted: () { setState(() => _selectedMemoria = ''); _filter(); }, deleteIconColor: Colors.red),
                  if (_selectedRam.isNotEmpty) Chip(label: Text(_selectedRam), onDeleted: () { setState(() => _selectedRam = ''); _filter(); }, deleteIconColor: Colors.red),
                ])
              : const SizedBox.shrink()),
            IconButton(
              onPressed: _showFiltri,
              icon: Stack(children: [
                const Icon(Icons.tune, color: AppTheme.primary),
                if (_selectedMemoria.isNotEmpty || _selectedRam.isNotEmpty || _maxPrezzo < 1500)
                  Positioned(right: 0, top: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _loading
            ? GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: 6,
                itemBuilder: (c, i) => const ProductCardShimmer(),
              )
            : _filtered.isEmpty
              ? const Center(child: Text('Nessun prodotto trovato'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.of(context).size.shortestSide > 500 ? 4 : 2, childAspectRatio: MediaQuery.of(context).size.shortestSide > 500 ? 1.1 : 0.57, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: _filtered.length,
                  itemBuilder: (c, i) => ProductCard(product: _filtered[i], badge: '', badgeColor: Colors.transparent, variants: _variantsMap[_filtered[i].id], showDisponibile: false),
                ),
        ),
      ]),
    );
  }
}
