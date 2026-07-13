import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../router/app_router.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _client = Supabase.instance.client;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
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

    // Deep link: app in foreground
    FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          notification.title ?? 'Top Phone Torre',
          notification.body ?? '',
          const NotificationDetails(
              android: AndroidNotificationDetails(
            'chat_ordine',
            'Chat Ordine',
            channelDescription: 'Notifiche chat ordine',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            icon: '@mipmap/ic_launcher',
          )),
          payload: data['ordineId'] ?? data['ordine_id'] ?? '',
        );
      }
    });

    // Deep link: app in background, utente tocca notifica
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Deep link: app terminata, utente tocca notifica
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);

    // Quando utente tocca notifica locale
    _localNotifications.initialize(initSettings,
        onDidReceiveNotificationResponse: (response) {
      final ordineId = response.payload;
      if (ordineId != null && ordineId.isNotEmpty) {
        AppRouter.router.go('/order-chat/$ordineId');
      }
    });
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final ordineId = message.data['ordineId'] ?? message.data['ordine_id'];
    if (ordineId != null && ordineId.toString().isNotEmpty) {
      final profilo = _client.auth.currentUser;
      // Se admin, vai alla chat admin
      AppRouter.router.go('/order-chat/$ordineId');
    }
  }

  static Future<void> refreshToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint("refreshToken FCM: $e");
    }
  }

  static Future<void> _saveToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('profili')
          .update({'fcm_token': token}).eq('id', userId);
    } catch (e) {
      debugPrint("saveToken FCM: $e");
    }
  }

  static Future<void> notificaCarrelloInScadenza() async {
    const androidDetails = AndroidNotificationDetails(
      'carrello_scadenza',
      'Carrello e Ordini',
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
      'Carrello e Ordini',
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
      final title = tipoConsegna == 'ritiro'
          ? '🏪 Ordine Ritiro in Sede!'
          : '🛍️ Nuovo Ordine!';
      final body = '${cliente != null ? '$cliente ha ordinato ' : ''}$prodotti${variante != null && variante.isNotEmpty
              ? ' ($variante)'
              : ''} - \u20AC$totale${tipoConsegna == 'ritiro' ? ' • RITIRO IN SEDE' : ''}';
      final userId = _client.auth.currentUser?.id;
      await _client.functions.invoke('notifica-admin-ordine', body: {
        'title': title,
        'body': body,
        'escludiUserId': userId,
      });
    } catch (e) {
      debugPrint("invio notifica push: $e");
    }
  }

  static Future<void> notificaRimborso() async {
    const androidDetails = AndroidNotificationDetails(
      'carrello_scadenza',
      'Carrello e Ordini',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      3,
      '💸 Pagamento Rimborsato',
      'Il tuo ordine è stato rimborsato. Il rimborso arriverà entro 5-10 giorni.',
      details,
    );
  }
}
