import 'dart:async';
import 'package:flutter/foundation.dart';
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
      'tracking': note,
    }).select().single();

    for (final riga in righe) {
      await _client.from('righe_ordine').insert({
        'ordine_id': order['id'],
        'prodotto_id': riga['prodotto_id'],
        'quantita': riga['quantita'],
        'prezzo': riga['prezzo'],
        'variante_id': riga['variante_id'],
        'variante_label': riga['variante_label'],
      });
    }

    // Anti-sollecito: marca gli abbandoni pendenti come recuperati via RPC,
    // cosi il cron di recupero carrello non manda solleciti a chi ha appena ordinato.
    try {
      await _client.rpc('marca_abbandoni_recuperati', params: {'p_user_id': userId});
    } catch (e) {
      debugPrint("marca abbandoni recuperati: $e");
    }

    final nProdotti = righe.length;
    final _vl = righe.isNotEmpty ? ((righe[0]['variante_label'] ?? '') as String) : '';
    String _pn = '$nProdotti prodotto/i';
    try { if (righe.isNotEmpty) { final pd = await _client.from('prodotti').select('nome').eq('id', righe[0]['prodotto_id']).single(); _pn = pd['nome'] ?? '$nProdotti prodotto/i'; } } catch(e) { debugPrint("order nome prodotto: $e"); }
    final _profCliente = await _client.from('profili').select('nome, cognome').eq('id', userId).single();
    final _nc = ((_profCliente['nome'] ?? '') + ' ' + (_profCliente['cognome'] ?? '')).trim();
    await NotificationService.notificaNuovoOrdine(
      totale: totale.toStringAsFixed(2),
      prodotti: _pn,
      variante: _vl,
      cliente: _nc,
      tipoConsegna: tipoConsegna,
    );


    // Invia email admin
    try {
      final profilo = await _client.from('profili').select('nome, cognome, telefono').eq('id', userId).single();
      final nomeCliente = '${profilo["nome"] ?? ""} ${profilo["cognome"] ?? ""}'.trim();
      final telefono = (profilo['telefono'] ?? '').toString();

      final List<String> prodottiList = [];
      for (final riga in righe) {
        String label = (riga['nome_prodotto'] ?? 'Prodotto').toString();
        final vl = (riga['variante_label'] ?? '').toString();
        if (vl.isNotEmpty) label += ' ($vl)';
        label += ' x${riga['quantita']} — €${(riga['prezzo'] as num).toStringAsFixed(2)}';
        prodottiList.add(label);
      }

      await _client.functions.invoke('send-order-email', body: {
        'ordineId': order['id'],
        'totale': totale.toStringAsFixed(2),
        'tipo': tipoConsegna,
        'prodotti': prodottiList,
        'cliente': nomeCliente,
        'telefono': telefono,
        'indirizzo': note ?? '',
      });
    } catch (e) {
      /* errore email silenzioso */
    }
    return order['id'] as String;
  }

  Future<void> updateOrderStatus(String id, String stato, {String? tracking}) async {
    final update = {'stato': stato};
    if (tracking != null) update['tracking'] = tracking;
    await _client.from('ordini').update(update).eq('id', id);
  }
}
