import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _client = Supabase.instance.client;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);

    const androidChannel = AndroidNotificationChannel(
      'carrello_scadenza',
      'Carrello e Ordini',
      description: 'Notifiche carrello e ordini TopPhone',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _saveToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('profili')
          .update({'fcm_token': token}).eq('id', userId);
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
      'Il tuo carrello sta per scadere. Completa l\'ordine ora.',
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
    String? variante,
    String? cliente,
    String tipoConsegna = 'spedizione',
  }) async {
    try {
      final admins =
          await _client.from('profili').select('fcm_token').eq('ruolo', 'admin');

      for (final admin in admins) {
        final token = admin['fcm_token'];
        if (token == null || token.isEmpty) continue;
        await _client.functions.invoke('send-notification', body: {
          'token': token,
          'title': tipoConsegna == 'ritiro' ? '🏪 Ordine Ritiro in Sede!' : '🛍️ Nuovo Ordine!',
          'body': (cliente != null && cliente.isNotEmpty ? cliente + ' ha ordinato ' : '') + prodotti + (variante != null && variante.isNotEmpty ? ' (' + variante + ')' : '') + ' — €' + totale + (tipoConsegna == 'ritiro' ? ' • RITIRO IN SEDE' : ''),
        });
      }
    } catch (e) {
      print('Errore notifica: $e');
    }
  }

  static Future<void> notificaRimborso() async {
    const androidDetails = AndroidNotificationDetails(
      'carrello_scadenza',
      'Carrello e Ordini',
      channelDescription: 'Notifiche carrello e ordini TopPhone',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      4,
      'Pagamento Rimborsato',
      'Il prodotto non è più disponibile. Il rimborso arriverà entro 5-10 giorni.',
      details,
    );
  }
}
