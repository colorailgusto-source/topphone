import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../models/variant_model.dart';

class CartService extends ChangeNotifier {
  final _client = Supabase.instance.client;
  final List<CartItemModel> _items = [];
  bool _isProcessing = false;

  List<CartItemModel> get items => _items.where((i) => !i.isExpired).toList();
  int get count => items.length;
  double get total => items.fold(0, (sum, i) => sum + i.prezzoTotale);

  Future<bool> addItem(ProductModel product, int qty, {VariantModel? variant}) async {
    if (_isProcessing) return false;
    _isProcessing = true;
    notifyListeners();
    try {
      int stockReale;
      if (variant != null) {
        final data = await _client.from('varianti_prodotto').select('stock').eq('id', variant.id).single();
        stockReale = data['stock'] as int;
      } else {
        final data = await _client.from('prodotti').select('stock').eq('id', product.id).single();
        stockReale = data['stock'] as int;
      }
      if (stockReale <= 0 || qty > stockReale) { _isProcessing = false; notifyListeners(); return false; }

      if (variant != null) {
        await _client.from('varianti_prodotto').update({'stock': stockReale - qty}).eq('id', variant.id);
      } else {
        await _client.from('prodotti').update({'stock': stockReale - qty}).eq('id', product.id);
      }

      final existing = _items.where((i) => i.product.id == product.id && i.variant?.id == variant?.id && !i.isExpired).firstOrNull;
      if (existing != null) {
        existing.quantita += qty;
        existing.resetTimer();
      } else {
        _items.add(CartItemModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          product: product, variant: variant, quantita: qty,
          scadenza: DateTime.now().add(const Duration(minutes: 5)),
        ));
      }
      notifyListeners();
      _scheduleExpiry(product.id, qty, variantId: variant?.id);
      return true;
    } catch (e) { return false; }
    finally { _isProcessing = false; notifyListeners(); }
  }

  Future<void> removeItem(String id) async {
    final item = _items.where((i) => i.id == id).firstOrNull;
    if (item == null) return;
    final qty = item.quantita;
    final productId = item.product.id;
    final variantId = item.variant?.id;
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    if (variantId != null) {
      final data = await _client.from('varianti_prodotto').select('stock').eq('id', variantId).single();
      await _client.from('varianti_prodotto').update({'stock': (data['stock'] as int) + qty}).eq('id', variantId);
    } else {
      final data = await _client.from('prodotti').select('stock').eq('id', productId).single();
      await _client.from('prodotti').update({'stock': (data['stock'] as int) + qty}).eq('id', productId);
    }
  }

  void clear() { _items.clear(); notifyListeners(); }

  void _scheduleExpiry(String productId, int qty, {String? variantId}) {
    Future.delayed(const Duration(minutes: 5), () async {
      final expired = _items.where((i) => i.product.id == productId && i.variant?.id == variantId && i.isExpired).toList();
      if (expired.isNotEmpty) {
        final qtyDaRipristinare = expired.fold(0, (s, i) => s + i.quantita);
        _items.removeWhere((i) => i.product.id == productId && i.variant?.id == variantId && i.isExpired);
        notifyListeners();
        if (variantId != null) {
          final data = await _client.from('varianti_prodotto').select('stock').eq('id', variantId).single();
          await _client.from('varianti_prodotto').update({'stock': (data['stock'] as int) + qtyDaRipristinare}).eq('id', variantId);
        } else {
          final data = await _client.from('prodotti').select('stock').eq('id', productId).single();
          await _client.from('prodotti').update({'stock': (data['stock'] as int) + qtyDaRipristinare}).eq('id', productId);
        }
      }
    });
  }
}
