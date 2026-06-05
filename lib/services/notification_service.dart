import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _client = Supabase.instance.client;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    
    // Inizializza notifiche locali
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);

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

  static Future<void> notificaCarrelloInScadenza() async {
    const androidDetails = AndroidNotificationDetails(
      'carrello_scadenza',
      'Carrello in scadenza',
      channelDescription: 'Notifiche scadenza carrello',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      1,
      '⏰ Carrello in scadenza!',
      'Il tuo carrello scade tra 60 secondi! Completa l\'ordine ora.',
      details,
    );
  }

  static Future<void> notificaCarrelloScaduto() async {
    const androidDetails = AndroidNotificationDetails(
      'carrello_scadenza',
      'Carrello in scadenza',
      channelDescription: 'Notifiche scadenza carrello',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      2,
      '🛒 Carrello scaduto',
      'Il tuo carrello è scaduto. I prodotti sono stati rimessi in disponibilità.',
      details,
    );
  }

  static Future<void> notificaNuovoOrdine({
    required String totale,
    required String prodotti,
  }) async {
    try {
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
