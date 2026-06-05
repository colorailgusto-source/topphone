import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class StripeService {
  static Future<String?> processPayment(BuildContext context, double amount) async {
    try {
      final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoamNxeGpzcHdlZHFpaGpqa2pmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1OTAwMjMsImV4cCI6MjA5NjE2NjAyM30.XLebw0DH33-HFhkPOwnBg7v06sBTl_uQ6uistj5Sg6s';
      
      print('Step 1: Chiamata Edge Function');
      final response = await http.post(
        Uri.parse('https://ehjcqxjspwedqihjjkjf.supabase.co/functions/v1/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $anonKey',
        },
        body: jsonEncode({'amount': amount, 'currency': 'eur'}),
      ).timeout(const Duration(seconds: 15));

      print('Step 2: Response ${response.statusCode}: ${response.body}');
      final data = jsonDecode(response.body);
      final clientSecret = data['clientSecret'];
      if (clientSecret == null) {
        print('Step 2b: clientSecret null!');
        return null;
      }

      print('Step 3: initPaymentSheet');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Top Phone Torre',
        ),
      );

      print('Step 4: presentPaymentSheet');
      await Stripe.instance.presentPaymentSheet();
      print('Step 5: Pagamento completato!');
      return clientSecret;
    } on StripeException catch (e) {
      print('StripeException: ${e.error.code} - ${e.error.message}');
      if (e.error.code == FailureCode.Canceled) return 'canceled';
      return null;
    } catch (e, stack) {
      print('Exception tipo: ${e.runtimeType}');
      print('Exception: $e');
      print('Stack: $stack');
      return null;
    }
  }
}
