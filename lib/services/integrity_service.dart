import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class IntegrityService {
  static const _channel = MethodChannel('com.topphone/integrity');

  /// Genera un nonce casuale sicuro
  static String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Richiede un token di integrità a Google Play.
  static Future<String?> getIntegrityToken() async {
    if (kDebugMode) return 'debug_token';
    try {
      final nonce = _generateNonce();
      final token = await _channel.invokeMethod<String>('getIntegrityToken', {
        'nonce': nonce,
      });
      return token;
    } on PlatformException catch (e) {
      debugPrint('IntegrityService error: ${e.message}');
      return null;
    }
  }

  /// Verifica l'integrità.
  /// Per distribuzione via APK sideload, ritorna sempre true.
  /// Se in futuro pubblichi su Play Store, rimuovi il return true.
  static Future<bool> verifica() async {
    // APK distribuito direttamente - Play Integrity non funziona senza Play Store
    return true;
    // Decommentare quando/se si pubblica su Play Store:
    // if (kDebugMode) return true;
    // final token = await getIntegrityToken();
    // return token != null;
  }
}
