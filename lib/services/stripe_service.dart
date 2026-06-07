import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  static final _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoamNxeGpzcHdlZHFpaGpqa2pmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1OTAwMjMsImV4cCI6MjA5NjE2NjAyM30.XLebw0DH33-HFhkPOwnBg7v06sBTl_uQ6uistj5Sg6s';

  static Future<void> openCheckout(double amount, {
    required String userId,
    required String righeJson,
    required String note,
    required String tipo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://ehjcqxjspwedqihjjkjf.supabase.co/functions/v1/create-checkout-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_anonKey',
        },
        body: jsonEncode({
          'amount': amount,
          'userId': userId,
          'righeJson': righeJson,
          'note': note,
          'tipo': tipo,
        }),
      );

      final data = jsonDecode(response.body);
      final url = data['url'];
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Stripe error: $e');
    }
  }
}
