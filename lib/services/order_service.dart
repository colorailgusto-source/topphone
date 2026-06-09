import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import 'notification_service.dart';

class OrderService {
  final _client = Supabase.instance.client;

  Future<List<OrderModel>> getUserOrders(String userId) async {
    final data = await _client.from('ordini').select().eq('utente_id', userId).order('data', ascending: false);
    return (data as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<List<OrderModel>> getUserOrdersDetailed(String userId) async {
    final data = await _client.from('ordini')
      .select('*, righe_ordine(*, prodotti(nome, immagine))')
      .eq('utente_id', userId)
      .order('data', ascending: false);
    
    return (data as List).map((e) {
      final order = OrderModel.fromJson(e);
      final righe = (e['righe_ordine'] as List?)?.map((r) => {
        'nome_prodotto': r['prodotti']?['nome'] ?? 'Prodotto',
        'immagine': r['prodotti']?['immagine'] ?? '',
        'quantita': r['quantita'],
        'prezzo': r['prezzo'],
        'variante_label': r['variante_label'] ?? '',
      }).toList();
      order.righe = righe;
      return order;
    }).toList();
  }

  Future<List<OrderModel>> getAllOrders() async {
    final data = await _client.from('ordini').select().order('data', ascending: false);
    return (data as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<String> createOrder(String userId, double totale, List<Map<String, dynamic>> righe, {String? note, String tipoConsegna = "ritiro", String stato = "ricevuto"}) async {
    final order = await _client.from('ordini').insert({
      'utente_id': userId, 'totale': totale, 'stato': stato, 'tipo_consegna': tipoConsegna,
      'tracking': note, 'data': DateTime.now().toIso8601String(),
    }).select().single();

    for (final riga in righe) {
      await _client.from('righe_ordine').insert({...riga, 'ordine_id': order['id']});
    }

    final nProdotti = righe.length;
    await NotificationService.notificaNuovoOrdine(
      totale: totale.toStringAsFixed(2),
      prodotti: '$nProdotti prodotto/i',
    );
    // Invia email admin
    try {
      final profilo = await _client.from('profili').select('nome, cognome').eq('id', userId).single();
      final nomeCliente = '${profilo["nome"] ?? ""} ${profilo["cognome"] ?? ""}'.trim();
      final profilo2 = await _client.from('profili').select('telefono').eq('id', userId).single();
      final telefono = profilo2['telefono'] ?? '';
      final varianteLabel = righe.isNotEmpty ? (righe[0]['variante_label'] ?? '') : '';
      final prodottoNome = righe.isNotEmpty ? (righe[0]['nome_prodotto'] ?? '$nProdotti prodotto/i') : '$nProdotti prodotto/i';
      await _client.functions.invoke('send-order-email', body: {
        'ordineId': order['id'],
        'totale': totale.toStringAsFixed(2),
        'tipo': tipoConsegna,
        'prodotti': prodottoNome,
        'cliente': nomeCliente,
        'telefono': telefono,
        'variante': varianteLabel,
        'indirizzo': note ?? '',
      });
    } catch (e) {
      print('Errore email: $e');
    }
    return order['id'] as String;
  }

  Future<void> updateOrderStatus(String id, String stato, {String? tracking}) async {
    final update = {'stato': stato};
    if (tracking != null) update['tracking'] = tracking;
    await _client.from('ordini').update(update).eq('id', id);
  }
}