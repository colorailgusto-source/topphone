import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../models/variant_model.dart';
import 'notification_service.dart';

class CartService extends ChangeNotifier {
  final _client = Supabase.instance.client;
  List<CartItemModel> _items = [];
  
  List<CartItemModel> get items => _items;
  int get count => _items.fold(0, (s, i) => s + i.quantita);
  double get total => _items.fold(0.0, (s, i) => s + (i.product.prezzo + (i.variant?.prezzoExtra ?? 0)) * i.quantita);
  bool get hasItems => _items.isNotEmpty;

  Future<void> loadFromDb() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final data = await _client
        .from('carrelli')
        .select('*, prodotti(*), varianti_prodotto(*)')
        .eq('utente_id', userId)
        .gt('scadenza', now);
      
      _items = [];
      for (final row in (data as List)) {
        if (row['prodotti'] == null) continue;
        final product = ProductModel.fromJson(row['prodotti']);
        final variant = row['varianti_prodotto'] != null 
          ? VariantModel.fromJson(row['varianti_prodotto']) 
          : null;
        final scadenzaStr = row['scadenza'].toString();
        final scadenza = DateTime.parse(
          scadenzaStr.contains('+') 
            ? scadenzaStr.substring(0, scadenzaStr.lastIndexOf('+')) + 'Z'
            : scadenzaStr
        ).toLocal();
        
        _items.add(CartItemModel(
          id: row['id'],
          product: product,
          variant: variant,
          quantita: row['quantita'],
          scadenza: scadenza,
        ));
      }
      notifyListeners();
    } catch (e) {
      print('Errore loadFromDb: $e');
    }
  }

  Future<bool> addItem(ProductModel product, int qty, {VariantModel? variant}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    // Un solo prodotto alla volta - ricarica dal DB prima di controllare
    await loadFromDb();
    if (_items.isNotEmpty) return false;
    final existingCart = await _client.from('carrelli')
      .select('id')
      .eq('utente_id', userId)
      .gt('scadenza', DateTime.now().toUtc().toIso8601String())
      .maybeSingle();
    if (existingCart != null) {
      await loadFromDb();
      return false;
    }

    try {
      // ✅ Decremento atomico stock - previene race condition
      if (variant != null) {
        final result = await _client.rpc('decrement_stock_variante', params: {'variante_id': variant.id, 'qty': qty});
        print('RPC variante result: \$result');
        if (result == null || result == -1) return false;
      } else {
        final result = await _client.rpc('decrement_stock_prodotto', params: {'prodotto_id': product.id, 'qty': qty});
        print('RPC prodotto result: \$result');
        if (result == null || result == -1) return false;
      }

      final scadenza = DateTime.now().add(const Duration(minutes: 5));
      
      final row = await _client.from('carrelli').insert({
        'utente_id': userId,
        'prodotto_id': product.id,
        'variante_id': variant?.id,
        'quantita': qty,
        'scadenza': scadenza.toUtc().toIso8601String(),
      }).select().single();

      _items.add(CartItemModel(
        id: row['id'],
        product: product,
        variant: variant,
        quantita: qty,
        scadenza: scadenza,
      ));
      notifyListeners();

      // Notifica 2 minuti prima
      Future.delayed(const Duration(minutes: 2), () async {
        if (_items.any((i) => i.id == row['id'])) {
          await NotificationService.notificaCarrelloInScadenza();
        }
      });

      // Rimozione alla scadenza
      Future.delayed(const Duration(minutes: 5), () async {
        await _removeExpiredItem(row['id'], product.id, qty, variantId: variant?.id);
      });

      return true;
    } catch (e) {
      print('Errore addItem: $e');
      return false;
    }
  }

  Future<void> _removeExpiredItem(String cartId, String productId, int qty, {String? variantId}) async {
    // Controlla sia in memoria che nel DB
    final inMemory = _items.any((i) => i.id == cartId);
    final inDb = await _client.from('carrelli').select('id').eq('id', cartId).maybeSingle();
    if (!inMemory && inDb == null) return;
    try {
      if (variantId != null) {
        final data = await _client.from('varianti_prodotto').select('stock').eq('id', variantId).single();
        await _client.from('varianti_prodotto').update({'stock': (data['stock'] as int) + qty}).eq('id', variantId);
      } else {
        final data = await _client.from('prodotti').select('stock').eq('id', productId).single();
        await _client.from('prodotti').update({'stock': (data['stock'] as int) + qty}).eq('id', productId);
      }
      await _client.from('carrelli').delete().eq('id', cartId);
    } catch (e) {
      print('Errore scadenza: $e');
    }
    _items.removeWhere((i) => i.id == cartId);
    notifyListeners();
    await NotificationService.notificaCarrelloScaduto();
  }

  Future<void> removeItem(CartItemModel item) async {
    try {
      if (item.variant != null) {
        final data = await _client.from('varianti_prodotto').select('stock').eq('id', item.variant!.id).single();
        await _client.from('varianti_prodotto').update({'stock': (data['stock'] as int) + item.quantita}).eq('id', item.variant!.id);
      } else {
        final data = await _client.from('prodotti').select('stock').eq('id', item.product.id).single();
        await _client.from('prodotti').update({'stock': (data['stock'] as int) + item.quantita}).eq('id', item.product.id);
      }
      if (item.id != null) await _client.from('carrelli').delete().eq('id', item.id!);
    } catch (e) {
      print('Errore remove: $e');
    }
    _items.removeWhere((i) => i.id == item.id);
    notifyListeners();
  }

  Future<void> clearAfterOrder() async {
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      await _client.from('carrelli').delete().eq('utente_id', userId);
    }
    _items.clear();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
