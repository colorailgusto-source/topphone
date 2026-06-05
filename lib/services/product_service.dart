import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class ProductService {
  final _client = Supabase.instance.client;

  Future<List<ProductModel>> getProducts({String? marca}) async {
    final data = await _client.from('prodotti').select('*, varianti_prodotto(stock)');
    
    final filtered = (data as List).where((e) {
      final varianti = e['varianti_prodotto'] as List? ?? [];
      // Mostra solo se ha varianti con almeno 1 stock > 0
      return varianti.isNotEmpty && varianti.any((v) => (v['stock'] ?? 0) > 0);
    }).toList();

    return filtered.where((e) {
      if (marca != null) return e['marca'] == marca;
      return true;
    }).map((e) => ProductModel.fromJson(e)).toList();
  }

  Future<ProductModel?> getProduct(String id) async {
    final data = await _client.from('prodotti').select().eq('id', id).single();
    return ProductModel.fromJson(data);
  }

  Future<void> addProduct(Map<String, dynamic> product) async {
    await _client.from('prodotti').insert(product);
  }

  Future<void> updateProduct(String id, Map<String, dynamic> product) async {
    await _client.from('prodotti').update(product).eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('prodotti').delete().eq('id', id);
  }
}
