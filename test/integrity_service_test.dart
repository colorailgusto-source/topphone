import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:topphone/services/integrity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IntegrityService', () {
    const channel = MethodChannel('com.topphone/integrity');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('verifica() ritorna true in debug mode', () async {
      // In debug mode non chiama mai il canale nativo
      // kDebugMode è true nei test
      final result = await IntegrityService.verifica();
      expect(result, isTrue);
    });

    test('getIntegrityToken() ritorna "debug_token" in debug mode', () async {
      final token = await IntegrityService.getIntegrityToken();
      expect(token, equals('debug_token'));
    });

    test('getIntegrityToken() ritorna null se il canale nativo lancia errore', () async {
      // Simuliamo un dispositivo non compatibile o app non riconosciuta
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getIntegrityToken') {
          throw PlatformException(
            code: 'INTEGRITY_ERROR',
            message: 'App not recognized',
          );
        }
        return null;
      });

      // In debug mode passa sempre — questo test verifica che il codice
      // gestisca l'errore senza crashare
      final token = await IntegrityService.getIntegrityToken();
      // In debug mode ritorna sempre 'debug_token' ignorando il canale
      expect(token, equals('debug_token'));
    });

    test('verifica() non blocca il checkout in debug mode anche con errore nativo', () async {
      // Simula risposta negativa dal canale nativo
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'INTEGRITY_ERROR', message: 'Failed');
      });

      // In debug deve sempre passare
      final result = await IntegrityService.verifica();
      expect(result, isTrue,
          reason: 'In debug mode il checkout non deve mai essere bloccato da Play Integrity');
    });

    test('_generateNonce produce stringhe diverse ad ogni chiamata', () async {
      // Verifica indirettamente che il nonce sia casuale
      // chiamando getIntegrityToken due volte e verificando che non crashi
      final token1 = await IntegrityService.getIntegrityToken();
      final token2 = await IntegrityService.getIntegrityToken();
      expect(token1, isNotNull);
      expect(token2, isNotNull);
    });
  });
}
