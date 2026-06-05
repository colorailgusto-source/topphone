import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class StripePaymentScreen extends StatefulWidget {
  final double amount;
  const StripePaymentScreen({super.key, required this.amount});
  @override
  State<StripePaymentScreen> createState() => _StripePaymentScreenState();
}

class _StripePaymentScreenState extends State<StripePaymentScreen> {
  bool _loading = false;
  String? _error;
  String? _sessionId;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _listenDeepLinks();
  }

  void _listenDeepLinks() {
    _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'topphone') {
        if (uri.host == 'payment-success') {
          _verifyAndConfirm();
        } else if (uri.host == 'payment-cancel') {
          if (mounted) Navigator.pop(context, false);
        }
      }
    });
  }

  Future<void> _verifyAndConfirm() async {
    if (_sessionId == null) return;
    setState(() => _loading = true);
    try {
      final verifyResponse = await http.post(
        Uri.parse('https://ehjcqxjspwedqihjjkjf.supabase.co/functions/v1/verify-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoamNxeGpzcHdlZHFpaGpqa2pmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1OTAwMjMsImV4cCI6MjA5NjE2NjAyM30.XLebw0DH33-HFhkPOwnBg7v06sBTl_uQ6uistj5Sg6s',
        },
        body: jsonEncode({'sessionId': _sessionId}),
      );
      final verifyData = jsonDecode(verifyResponse.body);
      if (verifyData['paid'] == true) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) setState(() { _error = 'Pagamento non completato.'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pay() async {
    setState(() { _loading = true; _error = null; });
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
          'line_items[0][price_data][unit_amount]': (widget.amount * 100).round().toString(),
          'line_items[0][quantity]': '1',
          'success_url': 'topphone://payment-success',
          'cancel_url': 'topphone://payment-cancel',
        },
      );

      final data = jsonDecode(response.body);
      final url = data['url'];
      _sessionId = data['id'];
      if (url == null) throw Exception('Errore creazione pagamento');

      setState(() => _loading = false);
      
      // Estendi scadenza carrello di 10 minuti durante il pagamento
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('carrelli').update({
          'scadenza': DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
        }).eq('utente_id', userId);
      }
      
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamento'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            // Ripristina scadenza originale
            final userId = Supabase.instance.client.auth.currentUser?.id;
            if (userId != null) {
              await Supabase.instance.client.from('carrelli').update({
                'scadenza': DateTime.now().add(const Duration(minutes: 5)).toUtc().toIso8601String(),
              }).eq('utente_id', userId);
            }
            if (mounted) Navigator.pop(context, false);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.payment, size: 80, color: AppTheme.primary),
          const SizedBox(height: 24),
          const Text('Pagamento Sicuro', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('€${widget.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Column(children: [
              Text('Carta di test:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('4242 4242 4242 4242', style: TextStyle(fontSize: 18, fontFamily: 'monospace')),
              Text('Scadenza: 12/34 | CVV: 123'),
            ]),
          ),
          const SizedBox(height: 32),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _loading ? null : _pay,
            icon: _loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Icon(Icons.open_in_browser),
            label: Text(_loading ? 'Caricamento...' : 'Paga con Stripe'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          )),
          const SizedBox(height: 16),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock, size: 14, color: AppTheme.grey),
            SizedBox(width: 4),
            Text('Pagamento sicuro con Stripe', style: TextStyle(color: AppTheme.grey, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}
