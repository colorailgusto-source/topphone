import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class StripeService {
  static const _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoamNxeGpzcHdlZHFpaGpqa2pmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1OTAwMjMsImV4cCI6MjA5NjE2NjAyM30.XLebw0DH33-HFhkPOwnBg7v06sBTl_uQ6uistj5Sg6s';

  static Future<bool> openPaymentSheet(double amount, {
    required String userId,
    required String righeJson,
    required String note,
    required String tipo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://ehjcqxjspwedqihjjkjf.supabase.co/functions/v1/create-checkout-session'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_anonKey'},
        body: jsonEncode({'amount': amount, 'userId': userId, 'righeJson': righeJson, 'note': note, 'tipo': tipo}),
      );
      final data = jsonDecode(response.body);
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
            testEnv: true,
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
      print('Stripe error: $e');
      return false;
    }
  }
}