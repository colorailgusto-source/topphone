import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  static Future<void> openCheckout(double amount) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/checkout/sessions'),
        headers: {
          'Authorization': 'Bearer sk_test_51S3PnZ2HVMlh4j789pZF8xeiEsqe4SqsJnVbjxUCuSz1NoFTQXm76NzSYnz7xC8M1V1x90e3ddDVYjMirVWjpGuH00DJcryX1T',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'mode': 'payment',
          'currency': 'eur',
          'line_items[0][price_data][currency]': 'eur',
          'line_items[0][price_data][product_data][name]': 'Ordine Top Phone Torre',
          'line_items[0][price_data][unit_amount]': (amount * 100).round().toString(),
          'line_items[0][quantity]': '1',
          'success_url': 'topphone://payment-success',
          'cancel_url': 'topphone://payment-cancel',
        },
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
