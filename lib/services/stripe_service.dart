import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

class StockEsauritoException implements Exception {
  final String message;
  StockEsauritoException(this.message);
}

class NonAutenticatoException implements Exception {
  final String message;
  NonAutenticatoException(this.message);
}

class StripeService {
  static Future<bool> openPaymentSheet(
    double amount, {
    required String userId,
    required String righeJson,
    required String note,
    required String tipo,
    String? couponCode,
    String metodoPagamento = 'carta',
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final accessToken = session?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw NonAutenticatoException('Sessione scaduta. Effettua di nuovo l\'accesso.');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.functionsBaseUrl}/create-checkout-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'amount': amount,
          'righeJson': righeJson,
          'note': note,
          'tipo': tipo,
          'couponCode': couponCode,
          'metodoPagamento': metodoPagamento,
        }),
      );
      final data = jsonDecode(response.body);

      if (data['checkoutUrl'] != null) {
        final url = Uri.parse(data['checkoutUrl']);
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }

      if (data['error'] == 'stock_esaurito') {
        throw StockEsauritoException('Il prodotto non è più disponibile.');
      }
      if (data['error'] == 'non_autenticato' || data['error'] == 'jwt_non_valido') {
        throw NonAutenticatoException('Sessione scaduta. Effettua di nuovo l\'accesso.');
      }
      if (data['error'] != null &&
          data['error'].toString().toLowerCase().contains('troppe richieste')) {
        throw Exception('⏱️ Troppe richieste. Riprova tra un minuto.');
      }
      if (data['error'] != null) throw Exception(data['error']);

      final clientSecret = data['paymentIntentClientSecret'];
      final publishableKey = data['publishableKey'];
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Top Phone Torre',
          style: ThemeMode.light,
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'IT',
            currencyCode: 'EUR',
            testEnv: false,
          ),
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Color(0xFF0288D1)),
          ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return false;
      rethrow;
    } catch (e) {
      debugPrint('Stripe error: $e');
      rethrow;
    }
  }
}
