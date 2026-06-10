import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/product_service.dart';
import '../../models/product_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/product_card.dart';

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
  List<Map<String, dynamic>> _categorie = [];
  String _search = '';
  String _selectedCategoria = 'Tutti';
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }



  Future<void> _load() async {
    final p = await _productService.getProducts();
    final c = await _client.from('categorie').select().eq('attiva', true).order('ordine');
    if (mounted) setState(() {
      _all = p;
      if (widget.categoriaIniziale != null) {
        _selectedCategoria = widget.categoriaIniziale!;
      }
      _filtered = _selectedCategoria == 'Tutti' ? p : p.where((prod) => prod.marca.toLowerCase() == _selectedCategoria.toLowerCase()).toList();
      _categorie = List<Map<String, dynamic>>.from(c);
      _loading = false;
    });
  }

  void _filter() {
    setState(() {
      _filtered = _all.where((p) {
        final matchSearch = p.nome.toLowerCase().contains(_search.toLowerCase()) || p.marca.toLowerCase().contains(_search.toLowerCase());
        final matchCat = _selectedCategoria == 'Tutti' || p.marca.toLowerCase() == _selectedCategoria.toLowerCase();
        return matchSearch && matchCat;
      }).toList();
    });
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
        const SizedBox(height: 8),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
              ? const Center(child: Text('Nessun prodotto trovato'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.of(context).size.shortestSide > 500 ? 4 : 2, childAspectRatio: MediaQuery.of(context).size.shortestSide > 500 ? 1.1 : 0.62, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: _filtered.length,
                  itemBuilder: (c, i) => ProductCard(product: _filtered[i], badge: '', badgeColor: Colors.transparent),
                ),
        ),
      ]),
    );
  }
}
