import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';

class OrderService {
  final _client = Supabase.instance.client;

  Future<List<OrderModel>> getUserOrders(String userId) async {
    final data = await _client.from('ordini').select().eq('utente_id', userId).order('data', ascending: false);
    return (data as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<List<OrderModel>> getAllOrders() async {
    final data = await _client.from('ordini').select().order('data', ascending: false);
    return (data as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<void> createOrder(String userId, double totale, List<Map<String, dynamic>> righe, {String? note}) async {
    final order = await _client.from('ordini').insert({
      'utente_id': userId, 'totale': totale, 'stato': 'ricevuto',
      'tracking': note, 'data': DateTime.now().toIso8601String(),
    }).select().single();
    for (final riga in righe) {
      await _client.from('righe_ordine').insert({...riga, 'ordine_id': order['id']});
    }
  }

  Future<void> updateOrderStatus(String id, String stato, {String? tracking}) async {
    final update = {'stato': stato};
    if (tracking != null) update['tracking'] = tracking;
    await _client.from('ordini').update(update).eq('id', id);
  }
}
