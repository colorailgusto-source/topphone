import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _client = Supabase.instance.client;

  static Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _saveToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('profili').update({'fcm_token': token}).eq('id', userId);
    } catch (e) {
      print('Errore salvataggio token: $e');
    }
  }

  static Future<void> notificaNuovoOrdine({
    required String totale,
    required String prodotti,
  }) async {
    try {
      // Prendi tutti gli admin
      final admins = await _client.from('profili')
        .select('fcm_token')
        .eq('ruolo', 'admin');

      for (final admin in admins) {
        final token = admin['fcm_token'];
        if (token == null || token.isEmpty) continue;

        await _client.functions.invoke('send-notification', body: {
          'token': token,
          'title': '🛍️ Nuovo Ordine!',
          'body': '$prodotti • Totale: €$totale',
        });
      }
    } catch (e) {
      print('Errore notifica: $e');
    }
  }
}
